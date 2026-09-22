local _, GF = ...

-- Only contact/lifetime metadata travels over the discovery channel. Message
-- bodies remain native character whispers. Restored records are never send authority.
local P, S = GF.RaidSeekingProtocol, GF.RAID_SEEKING_CHAT_STYLE
local Chat = {}
Chat.__index = Chat
local CONTACT_TIMEOUT, SEND_TIMEOUT, STATUS_INTERVAL = 35, 15, 45
local RECOVERY_TIMEOUT = 180
local RECOVERY_REQUEST_INTERVAL = 5
-- End controls carry bounded reason codes, never peer-supplied display text.
-- A peer cannot claim a local action (for example, "you cancelled").
local peerEndReasons = {
	board = { chat_recruitment_stopped = true, chat_permission_lost = true,
		chat_activity_changed = true, chat_recreated = true, chat_role_changed = true, chat_mismatch = true },
	seeking = { chat_republished = true, chat_role_changed = true, chat_mismatch = true,
		chat_connect_failed = true, chat_seeking_stopped = true },
}
local function peerEndReason(reason, context)
	if reason == "chat_capacity" then return "chat_peer_capacity" end
	if context == "seeking" and (reason == "chat_cancelled" or reason == "chat_joined" or reason == "chat_party_changed") then
		return "chat_seeking_stopped"
	end
	return peerEndReasons[context] and peerEndReasons[context][reason] and reason or "chat_contact_lost"
end
local function contains(ids, id)
	for _, value in ipairs(ids or {}) do if value == id then return true end end
	return false
end
local function recordProfile(record, name)
	local profile = { name = name, specIDs = {} }
	for _, member in ipairs(record and record.members or {}) do
		if name and member.name:lower() == name:lower() then
			profile.classID, profile.itemLevel = member.classID, member.itemLevel
			for _, id in ipairs(P.GetSpecIDs(member)) do profile.specIDs[#profile.specIDs + 1] = id end
			break
		end
	end
	return profile
end
function Chat.New(seeking)
	local self = setmetatable({ seeking = seeking, conversations = {}, order = {}, listeners = {}, unreadListeners = {}, incomingListeners = {}, revision = 0,
		routeRevision = 0, pendingSends = {}, serial = 0, statusSerial = 0, peerStatus = {} }, Chat)
	seeking.chat = self
	return self
end
function Chat:NormalizeName(value)
	value = P.Text(value)
	if not value or value == "" then return nil end
	if not value:find("-", 1, true) then
		local ctx = self.seeking:Context()
		local realm = ctx and P.Text(ctx.realm)
		if not realm or realm == "" then return nil end
		value = value .. "-" .. realm
	end
	return P.FullName(value)
end
function Chat:Notify()
	self.revision = self.revision + 1
	for _, listener in ipairs(self.listeners) do listener() end
	self:NotifyUnread()
end
function Chat:AddListener(listener) self.listeners[#self.listeners + 1] = listener end
function Chat:AddUnreadListener(listener) self.unreadListeners[#self.unreadListeners + 1] = listener end
function Chat:AddIncomingListener(listener) self.incomingListeners[#self.incomingListeners + 1] = listener end
function Chat:NotifyIncoming(contact, message)
	for _, listener in ipairs(self.incomingListeners) do listener(contact, message) end
end
function Chat:NotifyUnread()
	for _, listener in ipairs(self.unreadListeners) do listener() end
end
function Chat:HasUnread(context, excludedKey)
	for _, key in ipairs(self.order) do
		local c = self:Get(key)
		if key ~= excludedKey and c and not c.closed and not c.hidden and c.context == context and c.unread > 0 then return true end
	end
	return false
end
function Chat:AddUnread(c)
	-- Arrival order survives reloads and cannot be changed by outgoing replies,
	-- view refreshes or two senders arriving during the same clock tick.
	self.incomingSerial = (self.incomingSerial or 0) + 1
	c.lastIncomingSerial = self.incomingSerial
	c.hidden, c.closed, c.unread = nil, nil, c.unread + 1
end
function Chat:GetLatestUnread(excludedKey)
	local latest, rank = nil, -1
	for _, key in ipairs(self.order) do
		local c = self:Get(key)
		if key ~= excludedKey and c and not c.closed and not c.hidden and c.unread > 0
			and (c.context == "seeking" or c.context == "board") then
			local serial = c.lastIncomingSerial or 0
			-- Old archives have no arrival order; use their stable stored order.
			if serial >= rank then latest, rank = c, serial end
		end
	end
	return latest
end
function Chat:SetDraft(key, value)
	local c = self:Get(key)
	if c then c.draft = P.Truncate(value, S.sendMaxBytes) end
end
function Chat:MarkRead(key)
	local c = self:Get(key)
	if c and c.unread > 0 then
		c.unread = 0
		-- Navigation attention changes without recursively repainting the chat.
		self:NotifyUnread()
	end
end
function Chat:Get(key)
	local c = key and self.conversations[key]
	if c and not self.seeking.adapter.Blocked(c.name) then return c end
end
function Chat:Close(key)
	local c = self:Get(key)
	if not c or c.closed then return false end
	c.closed, c.unread = true, 0
	self:Notify(); return true
end
function Chat:Open(key)
	local c = self:Get(key)
	if c and c.closed then c.closed = nil; self:Notify() end
	return c
end
function Chat:List(context)
	local result = {}
	for _, key in ipairs(self.order) do
		local c = self:Get(key)
		if c and not c.closed and not c.hidden and (not context or c.context == context) then result[#result + 1] = c end
	end
	return result
end
function Chat:Control(op, ...)
	local seeking = self.seeking
	if seeking.transport.state ~= "ready" then return nil end
	local fields = seeking:Fields("C", op, ...)
	-- Retries of the same contact carry no new intent. Coalesce only identical
	-- controls; new application tokens and termination messages remain distinct.
	local body = P.Encode(fields)
	if not body then return nil, "payload" end
	return seeking.transport:Send(fields, "contact:" .. body)
end
function Chat:End(c, reason, remote)
	reason = reason or "chat_contact_lost"
	if c.ended then
		-- A status/withdrawal can arrive before its precise termination control.
		-- Refine an unknown cause only; never reopen or overwrite a known cause.
		if (c.endReason == "chat_contact_lost" or c.endReason == "chat_ended") and reason ~= "chat_contact_lost" then
			c.endReason, c.revision = reason, c.revision + 1
		end
		return
	end
	c.ended, c.endReason, c.connecting = true, reason, nil
	c.recovering, c.recoveryUntil, c.peerConfirmed = nil, nil, nil
	c.revision = c.revision + 1
	if not remote and c.token and c.peerSession then
		self:Control("E", c.name, c.token, c.peerSession, c.endReason, c.context)
	end
end
function Chat:Recover(c)
	if c.ended or c.recovering then return end
	if not c.ready then self:End(c, "chat_connect_failed"); return end
	c.recovering, c.recoveryUntil, c.peerConfirmed = true, self.seeking:Now() + RECOVERY_TIMEOUT, nil
	c.revision = c.revision + 1
	self.statusSignature = nil
end
function Chat:HasRecoverableContacts()
	for _, c in pairs(self.conversations) do
		if c.ready and not c.ended and not self.seeking.adapter.Blocked(c.name) then return true end
	end
	return false
end
function Chat:ConfirmPeer(c, sequence)
	if c.recovering and self.seeking:Now() >= c.recoveryUntil then self:End(c); return false end
	c.peerAt, c.peerConfirmed = self.seeking:Now(), true
	c.peerSequence = sequence or c.peerSequence
	return true
end
function Chat:Ensure(name, context)
	context = context or "seeking"
	name = self:NormalizeName(name)
	if not name or self.seeking.adapter.Blocked(name) then return nil end
	local ctx = self.seeking:Context()
	if ctx and ctx.name and name:lower() == ctx.name:lower() then return nil end
	local base = (context == "board" and "board:" or "") .. name:lower()
	for index = #self.order, 1, -1 do
		local c = self:Get(self.order[index])
		if c and c.name:lower() == name:lower() and c.context == context and not c.ended then return c end
	end
	if #self.order >= S.maxConversations then
		-- Never discard unread messages, a draft or an unconfirmed send.
		for index, key in ipairs(self.order) do
			local c = self.conversations[key]
			if (c.closed or c.hidden) and c.unread == 0 and c.draft == "" and not c.pendingSend then
				self:End(c, "chat_capacity")
				self.conversations[key] = nil; table.remove(self.order, index)
				local retained = false
				for _, other in pairs(self.conversations) do if other.name == c.name then retained = true end end
				if not retained then self.peerStatus[c.name:lower()] = nil end
				break
			end
		end
	end
	if #self.order >= S.maxConversations then return nil end
	self.serial = self.serial + 1
	local key = self.conversations[base] and base .. ":" .. self.serial or base
	local c = { key = key, name = name, context = context, messages = {}, draft = "", unread = 0, revision = 0 }
	self.conversations[key] = c; self.order[#self.order + 1] = key
	return c
end
function Chat:RouteTo(c)
	-- Retained for the isolated debug preview. Production routing uses contact
	-- lifetimes and never changes when the user switches pages or tabs.
	self.routeRevision = self.routeRevision + 1; c.routeRevision = self.routeRevision
end
function Chat:LocalState()
	local service = self.seeking
	if service.transport.state ~= "ready" then return "0", 0, {} end
	if service.ReadRecruitmentState and service:ReadRecruitmentState() == nil then return "0", 0, {} end
	local has = service:HasRecruitment()
	if has then
		local activity = service.adapter.ActiveActivity()
		local permission = service.adapter.HasInvitePermission or service.adapter.CanInvite
		if activity and service:ActivitySet()[activity] and permission() then
			return "R", service.recruitmentGeneration or 1, { activity }
		end
	elseif service.current then
		local record = service:GetMyActivity()
		if record then return "S", service.publicationGeneration or record.revision, record.activityIDs, record.revision end
	end
	return "0", 0, {}
end
function Chat:LocalEndReason(c, role, generation, ids)
	local service = self.seeking
	if service.ReadRecruitmentState and service:ReadRecruitmentState() == nil then return "chat_contact_lost" end
	if c.context == "seeking" then
		if service:HasRecruitment() then return "chat_role_changed" end
		if not service.current then
			if c.publicationGeneration == service.chatEndedPublicationGeneration then return service.chatPublicationEndReason or "chat_contact_lost" end
			return "chat_contact_lost"
		end
		if service.publicationGeneration and service.publicationGeneration ~= c.publicationGeneration then return "chat_republished" end
		if role ~= "S" then return "chat_contact_lost" end
		if not contains(ids, c.activityID) then return "chat_mismatch" end
	else
		if not service:HasRecruitment() then return role == "S" and "chat_role_changed" or "chat_recruitment_stopped" end
		local permission = service.adapter.HasInvitePermission or service.adapter.CanInvite
		local allowed = permission()
		if allowed ~= true then return allowed == false and "chat_permission_lost" or "chat_contact_lost" end
		local activity = service.adapter.ActiveActivity()
		local activities = service:ActivitySet()
		if not activity or not next(activities) then return "chat_contact_lost" end
		if not activities[activity] then return "chat_activity_changed" end
		if (service.recruitmentGeneration or 1) ~= c.recruitmentGeneration then return "chat_recreated" end
		if service.transport.state ~= "ready" then return "chat_contact_lost" end
		local live = service:GetLive(c.name:lower())
		if not live then
			local owner = service.owners and service.owners[c.name:lower()]
			return owner and owner.session == c.peerSession and owner.closed and "chat_seeking_stopped" or "chat_contact_lost"
		end
		if live.session ~= c.peerSession then return "chat_contact_lost" end
		if not contains(live.activityIDs, ids[1]) then return "chat_mismatch" end
	end
end
function Chat:CanOpenRecord(record)
	return self.seeking:CanContact(record)
end
function Chat:Request(c)
	c.lastRequest = self.seeking:Now()
	if c.applicationRequest then
		return self:Control("O", c.name, c.token, c.peerSession, c.requestRevision,
			c.recruitmentGeneration, c.activityID, c.applicationRequest)
	end
	return self:Control("R", c.name, c.token, c.peerSession, c.requestRevision, c.recruitmentGeneration, c.activityID)
end
function Chat:ContactRecord(key, revision, session, requestApplication)
	self:SyncContacts()
	local record = self.seeking:GetLive(key)
	if not record or record.revision ~= revision or record.session ~= session then return nil, "expired" end
	if requestApplication and record.mode ~= "party" then return nil, "expired" end
	local ok, reason = self:CanOpenRecord(record)
	if not ok then return nil, reason end
	local c = self:Ensure(record.owner, "board")
	if not c then return nil, "chat_capacity" end
	if c.peerSession and c.peerSession ~= session then
		self:End(c, "chat_contact_lost")
		c = self:Ensure(record.owner, "board")
		if not c then return nil, "chat_capacity" end
	end
	if c.recovering then return c, "chat_recovering" end
	local needsRequest = not c.token or requestApplication
	if not c.token then
		local _, generation, ids = self:LocalState()
		self.serial = self.serial + 1
		c.token, c.peerSession = tostring(self.serial), session
		c.recruitmentGeneration, c.activityID, c.requestRevision = generation, ids[1], revision
	end
	if requestApplication then
		self.serial = self.serial + 1
		c.applicationRequest, c.applicationConfirmed = self.serial, nil
		c.requestRevision = revision
	end
	if needsRequest then
		c.connecting, c.requestAt, c.peerAt = true, self.seeking:Now(), self.seeking:Now()
		-- Set all local state before Send: the transport may synchronously echo.
		if not self:Request(c) then self:End(c, "chat_connect_failed", true) end
	end
	c.profile, c.recordMode, c.closed = recordProfile(record, record.owner), record.mode, nil
	c.revision = c.revision + 1
	self:Notify(); return c
end
function Chat:OpenRecord(key, revision, session)
	return self:ContactRecord(key, revision, session, false)
end
function Chat:RequestApplication(key, revision, session)
	local c, reason = self:ContactRecord(key, revision, session, true)
	if c and c.ended then return nil, c.endReason end
	if c and c.recovering then return nil, "chat_recovering" end
	return c, reason
end
function Chat:GetContact(key)
	local c = self:Get(key)
	if not c or c.context ~= "seeking" or c.closed or c.hidden or c.ended or c.recovering or not c.established or not self.seeking.current then return nil end
	if self.seeking.transport.state ~= "ready" then return nil end
	if not c.peerAt or self.seeking:Now() - c.peerAt >= P.TTL then return nil end
	return { name = c.name, activityID = c.activityID, at = c.peerAt,
		token = c.token, session = c.peerSession, generation = c.recruitmentGeneration }
end
function Chat:GetBoardRecord(key)
	local c = self:Get(key)
	if not c or c.context ~= "board" or c.closed or c.hidden or c.ended or c.recovering or not c.token then return nil end
	if not c.peerAt or self.seeking:Now() - c.peerAt >= P.TTL then return nil end
	local role, generation, ids = self:LocalState()
	if role ~= "R" or generation ~= c.recruitmentGeneration then return nil end
	local record = self.seeking:GetLive(c.name:lower())
	if not record or record.session ~= c.peerSession or record.owner:lower() ~= c.name:lower()
		or not contains(record.activityIDs, ids[1]) then return nil end
	return record
end
function Chat:GetRequestedApplicant(key)
	local c = self:Get(key)
	if not c or not c.applicationRequest or not c.applicationConfirmed then return nil end
	local record = self:GetBoardRecord(key)
	local actions = GF.ApplicantActionService
	if not record or record.mode ~= "party" or not actions then return nil end
	-- Match only current native applicants, never IDs supplied by a peer or a
	-- retained card. A short native name belongs to our realm, not the peer's.
	local ok, match = pcall(function()
		local ids, readable = actions:GetApplicantIDs()
		if not readable then return nil end
		local found
		for _, rawID in ipairs(ids) do
			local id = P.Integer(rawID, 1, 4294967295)
			local info = id and actions:GetApplicantInfo(id)
			local names = info and actions:GetApplicantMemberNames(id)
			if names then
				local memberKeys, matches = {}, false
				for _, rawName in ipairs(names) do
					local name = self:NormalizeName(rawName)
					if not name then return nil end
					memberKeys[#memberKeys + 1] = name:lower()
					if name:lower() == c.name:lower() then matches = true end
				end
				if matches then
					if found then return nil end -- Ambiguous identity is never actionable.
					table.sort(memberKeys)
					found = { applicantID = id, status = info.applicationStatus,
						loading = info.applicantInfo or info.pendingApplicationStatus ~= nil,
						key = c.key, request = c.applicationRequest, token = c.token,
						members = table.concat(memberKeys, "\031") }
				end
			end
		end
		return found
	end)
	return ok and match or nil
end
function Chat:OnApplicantsChanged()
	for _, c in pairs(self.conversations) do
		if c.context == "board" and c.applicationRequest and not c.ended then self:Notify(); return end
	end
end
local function controlIDs(text)
	if not P.Text(text) or #text > 600 then return nil end
	local ids, seen = {}, {}
	for value in text:gmatch("[^,]+") do
		local id = P.Integer(value, 1, 10000000)
		if not id or seen[id] or #ids >= 32 then return nil end
		ids[#ids + 1], seen[id] = id, true
	end
	if table.concat(ids, ",") ~= text then return nil end
	return ids
end
function Chat:OnControl(f, sender, session, sequence)
	sender = self:NormalizeName(sender)
	sequence = P.Integer(sequence, 1, 2147483647)
	local ctx = self.seeking:Context()
	if not sender or not ctx or sender:lower() == ctx.name:lower() or self.seeking.adapter.Blocked(sender) then return end
	if f[4] == "S" and #f == 9 then
		local role, generation, ids, revision, serial = f[5], P.Integer(f[6], 0, 2147483647), controlIDs(f[7]),
			P.Integer(f[8], 0, 2147483647), P.Integer(f[9], 1, 2147483647)
		if (role ~= "R" and role ~= "S" and role ~= "0") or not generation or not ids or not revision or not serial then return end
		local relevant = false
		for _, c in pairs(self.conversations) do
			if c.name:lower() == sender:lower() and c.peerSession == session and not c.ended
				and (not sequence or not c.peerSequence or sequence > c.peerSequence) then relevant = true end
		end
		if not relevant then return end
		local old = self.peerStatus[sender:lower()]
		if old and old.session == session and serial <= old.serial then return end
		self.peerStatus[sender:lower()] = { session = session, serial = serial }
		for _, c in pairs(self.conversations) do
			if c.name:lower() == sender:lower() and c.peerSession == session and not c.ended and not c.connecting
				and (not sequence or not c.peerSequence or sequence > c.peerSequence) then
				local localRole, localGeneration, localIDs = self:LocalState()
				local matched = c.context == "board" and role == "S" and localRole == "R" and contains(ids, localIDs[1])
					or c.context == "seeking" and role == "R" and localRole == "S" and contains(localIDs, ids[1])
				local gen = c.context == "board" and c.publicationGeneration or c.recruitmentGeneration
				c.peerSequence = sequence or c.peerSequence
				if generation ~= gen or not matched then
					local reason = self:LocalEndReason(c, localRole, localGeneration, localIDs)
					local remote = reason == nil
					if not reason or reason == "chat_contact_lost" then
						local expected = c.context == "board" and "S" or "R"
						local peerReason = role == "0" and "chat_contact_lost" or role ~= expected and "chat_role_changed"
							or generation ~= gen and (c.context == "board" and "chat_republished" or "chat_recreated")
						if peerReason then reason, remote = peerReason, true
						elseif not reason then reason, remote = "chat_mismatch", true end
					end
					if reason == "chat_contact_lost" then self:Recover(c); c.peerConfirmed = nil
					else self:End(c, reason, remote) end
				else
					self:ConfirmPeer(c, sequence)
					c.activityID = c.context == "board" and localIDs[1] or ids[1]
				end
			end
		end
		self:SyncContacts(); self:Notify(); return
	end
	local target, token = P.FullName(f[5]), P.Text(f[6])
	if not target or target:lower() ~= ctx.name:lower() or not token or not token:match("^%d+$") or #token > 12
		or f[7] ~= self.seeking.transport.session then return end
	local applicationRequest = f[4] == "O" and #f == 11 and P.Integer(f[11], 1, 2147483647)
	if f[4] == "V" and #f == 10 then
		-- A restored seeker asks the original recruiter to repeat R/A validation.
		-- The request alone grants no authority, creates no contact, and cannot
		-- replay an application. Old peers ignore V and retain status fallback.
		local publication, recruitment, activity = P.Integer(f[8], 1, 2147483647),
			P.Integer(f[9], 1, 2147483647), P.Integer(f[10], 1, 10000000)
		if not publication or not recruitment or not activity or not sequence then return end
		for _, c in pairs(self.conversations) do
			if c.context == "board" and c.ready and not c.ended and c.name:lower() == sender:lower()
				and c.token == token and c.peerSession == session and c.publicationGeneration == publication
				and c.recruitmentGeneration == recruitment and c.activityID == activity
				and (not c.peerSequence or sequence > c.peerSequence) then
				if c.recovering and self.seeking:Now() >= c.recoveryUntil then self:End(c); self:Notify(); return end
				local role, generation, ids = self:LocalState()
				if self:LocalEndReason(c, role, generation, ids) then return end
				c.peerSequence = sequence
				-- A prior R may have arrived before the seeker restored its post.
				-- Limit replies separately so the first now-ready V is not delayed.
				if self.seeking:Now() - (c.lastRecoveryReply or -RECOVERY_REQUEST_INTERVAL) < RECOVERY_REQUEST_INTERVAL then return end
				c.lastRecoveryReply, c.lastRecoveryRequest = self.seeking:Now(), self.seeking:Now()
				self:Control("R", c.name, c.token, c.peerSession, c.requestRevision, c.recruitmentGeneration, c.activityID)
				break
			end
		end
	elseif (f[4] == "R" and #f == 10) or applicationRequest then
		local revision, generation, activity = P.Integer(f[8], 1, 2147483647), P.Integer(f[9], 1, 2147483647), P.Integer(f[10], 1, 10000000)
		if not revision or not generation or not activity then return end
		local role, publication, ids, currentRevision = self:LocalState()
		local record = self.seeking:GetMyActivity()
		if applicationRequest and (not record or record.mode ~= "party") then
			self:Control("E", sender, token, session, "chat_connect_failed", "seeking"); return
		end
		-- A repeated request acknowledges the same contact without reopening its tab.
		local c
		for _, item in pairs(self.conversations) do
			if item.name:lower() == sender:lower() and item.peerSession == session and item.token == token and item.context == "seeking" then c = item; break end
		end
		if c and sequence and c.peerSequence and sequence <= c.peerSequence then return end
		if role ~= "S" or not contains(ids, activity) or (c and c.publicationGeneration ~= publication)
			or (c and c.recruitmentGeneration ~= generation)
			or (not c and currentRevision ~= revision)
			or (applicationRequest and (not c or c.applicationRequest ~= applicationRequest) and currentRevision ~= revision) then
			local reason = role == "R" and "chat_role_changed" or role ~= "S" and "chat_contact_lost"
				or (c and c.publicationGeneration ~= publication) and "chat_republished"
				or (c and c.recruitmentGeneration ~= generation) and "chat_recreated"
				or not contains(ids, activity) and "chat_mismatch" or "chat_connect_failed"
			if c and not c.ended and c.ready and reason == "chat_contact_lost" then self:Recover(c); self:Notify(); return end
			self:Control("E", sender, token, session, reason, "seeking"); return
		end
		if c and c.ended then self:Control("E", sender, token, session, c.endReason, "seeking"); return end
		if c and c.recovering and self.seeking:Now() >= c.recoveryUntil then self:End(c); self:Notify(); return end
		if c and applicationRequest and c.applicationRequest and applicationRequest < c.applicationRequest then return end
		if not c then
			for _, item in pairs(self.conversations) do
				if item.name:lower() == sender:lower() and not item.ended then
					local reason = item.context ~= "seeking" and "chat_role_changed"
						or item.peerSession ~= session and "chat_contact_lost"
						or item.publicationGeneration ~= publication and "chat_republished"
						or item.recruitmentGeneration ~= generation and "chat_recreated" or "chat_contact_lost"
					self:End(item, reason)
				end
			end
			c = self:Ensure(sender, "seeking")
			if not c then self:Control("E", sender, token, session, "chat_capacity", "seeking"); return end
			c.hidden, c.token, c.peerSession = true, token, session
			c.publicationGeneration, c.recruitmentGeneration = publication, generation
		end
		c.activityID, c.peerAt, c.ready = activity, self.seeking:Now(), true
		self:ConfirmPeer(c, sequence)
		c.peerSequence = sequence and math.max(sequence, c.peerSequence or 0) or c.peerSequence
		if applicationRequest then
			if c.applicationRequest ~= applicationRequest then
				-- A real application request is visible without inventing a whisper.
				-- Transport retries acknowledge it without reopening a closed tab.
				c.applicationRequest, c.established = applicationRequest, true
				self:AddUnread(c)
				c.revision = c.revision + 1
			end
			self:Control("A", sender, token, session, publication, generation, activity, applicationRequest)
		else self:Control("A", sender, token, session, publication, generation, activity, c.applicationRequest) end
	elseif f[4] == "A" and (#f == 10 or #f == 11) then
		local publication, generation, activity = P.Integer(f[8], 1, 2147483647), P.Integer(f[9], 1, 2147483647), P.Integer(f[10], 1, 10000000)
		local acknowledgedRequest = #f == 11 and P.Integer(f[11], 1, 2147483647) or nil
		if not publication or not generation or not activity or (#f == 11 and not acknowledgedRequest) then return end
		for _, c in pairs(self.conversations) do
			if c.context == "board" and c.name:lower() == sender:lower() and c.token == token and c.peerSession == session
				and not c.ended and c.recruitmentGeneration == generation and c.activityID == activity
				and (not sequence or not c.peerSequence or sequence > c.peerSequence)
				and c.applicationRequest == acknowledgedRequest then
				if c.publicationGeneration and c.publicationGeneration ~= publication then
					self:End(c, "chat_republished", true); self:Notify(); return
				end
				c.connecting, c.ready, c.publicationGeneration, c.peerAt = nil, true, publication, self.seeking:Now()
				self:ConfirmPeer(c, sequence)
				c.peerSequence = sequence and math.max(sequence, c.peerSequence or 0) or c.peerSequence
				if acknowledgedRequest then c.applicationConfirmed, c.established = true, true end
			end
		end
	elseif f[4] == "E" and #f == 9 and (f[9] == "board" or f[9] == "seeking") then
		for _, c in pairs(self.conversations) do
			if c.name:lower() == sender:lower() and c.token == token and c.peerSession == session and c.context ~= f[9]
				and (not sequence or not c.peerSequence or sequence > c.peerSequence) then
				self:End(c, peerEndReason(f[8], f[9]), true)
			end
		end
	else return end
	self:SyncContacts(); self:Notify()
end
function Chat:SyncContacts()
	if self.syncing or self.seeking.loggingOut then return end
	self.syncing = true
	local service, now, changed = self.seeking, self.seeking:Now(), false
	local role, generation, ids, revision = self:LocalState()
	if service:GetMyActivity() then self.lastPlayerProfile = self:PlayerProfile() end
	local signature = role .. ":" .. generation .. ":" .. table.concat(ids, ",") .. ":" .. (revision or 0)
	for _, c in pairs(self.conversations) do
		if not c.ended and c.token then
			local reason = self:LocalEndReason(c, role, generation, ids)
			if not reason and c.context == "board" then c.activityID = ids[1] end
			if reason and reason ~= "chat_contact_lost" then self:End(c, reason); changed = true
			elseif c.connecting and now - c.requestAt >= CONTACT_TIMEOUT then self:End(c, "chat_connect_failed"); changed = true
			elseif c.recovering and now >= c.recoveryUntil then self:End(c); changed = true
			elseif reason or (not c.connecting and now - (c.peerAt or 0) >= P.TTL) then
				if not c.recovering then self:Recover(c); changed = true end
			elseif c.recovering and c.peerConfirmed then
				c.recovering, c.recoveryUntil, c.peerConfirmed = nil, nil, nil
				c.revision, changed = c.revision + 1, true
			elseif c.connecting and now - c.lastRequest >= 5 then self:Request(c) end
			-- Both sides can request fresh proof once local prerequisites are ready.
			-- Reuse the original contact; never replay O or a user's whisper.
			if c.recovering and not reason and now - (c.lastRecoveryRequest or -RECOVERY_REQUEST_INTERVAL) >= RECOVERY_REQUEST_INTERVAL then
				c.lastRecoveryRequest = now
				if c.context == "board" then
					self:Control("R", c.name, c.token, c.peerSession, c.requestRevision, c.recruitmentGeneration, c.activityID)
				else
					self:Control("V", c.name, c.token, c.peerSession, c.publicationGeneration, c.recruitmentGeneration, c.activityID)
				end
			end
		end
	end
	if service.RecoverCommunication then service:RecoverCommunication(now) end
	for index = #self.pendingSends, 1, -1 do
		local pending = self.pendingSends[index]
		local c = self.conversations[pending.key]
		if not pending.failed and now - pending.at >= SEND_TIMEOUT then
			pending.failed = true
			if c and c.pendingSend == pending then c.pendingSend, c.sendFailed = nil, true; changed = true end
		end
		-- Keep late confirmations bound to their origin, even after a role change.
		if now - pending.at >= P.TTL then table.remove(self.pendingSends, index) end
	end
	if service.transport.state == "ready" and (signature ~= self.statusSignature or now - (self.statusAt or -STATUS_INTERVAL) >= STATUS_INTERVAL) then
		self.statusSerial = self.statusSerial + 1
		-- Commit before Send because Send may synchronously notify the service.
		self.statusSignature, self.statusAt = signature, now
		local sent = service.transport:Send(service:Fields("C", "S", role, generation, table.concat(ids, ","), revision or 0, self.statusSerial), "chat-status")
		if not sent then self.statusSignature = nil end
	end
	self.syncing = nil
	if changed then self:Notify() end
end
function Chat:PlayerProfile()
	local ctx = self.seeking:Context()
	local record = self.seeking:GetMyActivity() or self.seeking.current
	if not record and self.lastPlayerProfile then return self.lastPlayerProfile end
	return recordProfile(record, ctx and ctx.name)
end
-- The sound bridge uses the same incoming admission without collecting text or
-- changing unread state. Chat-frame filters may see transformed message bodies.
function Chat:FindWhisperContact(sender, received)
	for _, c in pairs(self.conversations) do
		if not c.previewOnly and c.name:lower() == sender:lower() and c.ready and not c.ended
			and (c.established or received and c.context == "seeking" or not received and c.context == "board") then
			return c
		end
	end
end
function Chat:GetIncomingAlertContact(message, sender, lineID)
	if self.seeking.transport.adapter.Locked() then return nil end
	message, sender = P.Text(message), self:NormalizeName(sender)
	local id = P.Integer(lineID, 1, 9007199254740991)
	if not id or not message or message == "" or not sender or self.seeking.adapter.Blocked(sender) then return nil end
	if not self:FindWhisperContact(sender, true) then return nil end
	self:SyncContacts()
	local c = self:FindWhisperContact(sender, true)
	if c and not c.recovering then return c, id end
end
function Chat:OnWhisper(event, message, sender, lineID, guid)
	if event ~= "CHAT_MSG_WHISPER" and event ~= "CHAT_MSG_WHISPER_INFORM" then return end
	if self.seeking.transport.adapter.Locked() then return end
	message, sender, guid = P.Text(message), self:NormalizeName(sender), P.Text(guid)
	if not message or message == "" or not sender or self.seeking.adapter.Blocked(sender) then return end
	self:SyncContacts()
	local received, id = event == "CHAT_MSG_WHISPER", P.Integer(lineID, 1, 9007199254740991)
	for _, c in pairs(self.conversations) do
		for _, m in ipairs(c.messages) do if id and m.lineID == id and m.incoming == received then return end end
	end
	local c, pending
	if not received then
		for index, item in ipairs(self.pendingSends) do
			if item.name == sender:lower() and item.text == message then
				pending = table.remove(self.pendingSends, index); c = self:Get(item.key); break
			end
		end
	end
	if not c then c = self:FindWhisperContact(sender, received) end
	if not c then return end
	if received and guid and GetPlayerInfoByGUID then
		local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
		class = ok and P.Text(class)
		if class then c.classFile = class end
	end
	local m = { text = P.Truncate(message, S.maxMessageBytes), incoming = received, lineID = id, at = self.seeking:Now(), activityID = c.activityID }
	if received and c.context == "board" then
		local live = self.seeking:GetLive(sender:lower())
		if live then c.profile = recordProfile(live, c.name) end
		m.profile = c.profile
	elseif not received then
		m.profile, m.activityID = pending and pending.profile or self:PlayerProfile(), pending and pending.activityID or c.activityID
	end
	self:AppendMessage(c, m, pending)
end
-- The admitted native event and local debug transport share one presentation
-- commit: history, unread, arrival feedback, then the views' read acknowledgement.
function Chat:AppendMessage(c, m, pending)
	local received = m.incoming
	if received and self.alerts and not c.recovering then self.alerts:Receive(c, m) end
	c.messages[#c.messages + 1] = m
	if #c.messages > S.maxMessages then table.remove(c.messages, 1) end
	c.established = true
	if received then self:AddUnread(c) end
	if pending then
		if c.pendingSend == pending or not c.pendingSend then
			c.pendingSend, c.sendFailed = nil, nil
			if c.draft == pending.text then c.draft = "" end
		end
	end
	c.revision = c.revision + 1
	-- Only the canonical, deduplicated live event owns arrival feedback. Notify
	-- before views can mark the freshly inserted message read during repaint.
	if received and not c.recovering then self:NotifyIncoming(c, m) end
	self:Notify()
end
function Chat:CanSend(key)
	self:SyncContacts()
	local c = self:Get(key)
	if not c or c.closed or c.hidden then return false, "expired" end
	if c.ended then return false, c.endReason end
	if c.recovering then return false, "chat_recovering" end
	if self.seeking.transport.adapter.Locked() then return false, "locked" end
	if not c.ready then return false, "chat_connecting" end
	if c.pendingSend then return false, "chat_pending" end
	if c.context == "board" and not self.seeking.adapter.CanInvite() then return false, "cannot_invite" end
	return true
end
function Chat:Send(key, message)
	local contact = self:Get(key)
	if contact and contact.previewOnly then return false, "unavailable" end
	local ok, reason = self:CanSend(key)
	if not ok then return false, reason end
	message = P.Text(message)
	if not message or not message:find("%S") then return false, "chat_empty" end
	if #message > S.sendMaxBytes then return false, "chat_long" end
	local send = C_ChatInfo and C_ChatInfo.SendChatMessage
	if not send then return false, "unavailable" end
	local c = self:Get(key)
	local pending = { key = key, name = c.name:lower(), text = message, at = self.seeking:Now(), profile = self:PlayerProfile(), activityID = c.activityID }
	c.pendingSend, c.sendFailed, c.draft = pending, nil, message
	self.pendingSends[#self.pendingSends + 1] = pending
	-- Synchronous hardware event only. A queued handshake never sends user text.
	if not pcall(send, message, "WHISPER", nil, c.name) then
		for index, item in ipairs(self.pendingSends) do if item == pending then table.remove(self.pendingSends, index); break end end
		c.pendingSend, c.sendFailed = nil, true
		self:Notify(); return false, "chat_send"
	end
	self:Notify(); return true
end
-- History is local to the exact character/project/region. Only explicit scalar
-- fields cross the save boundary: never restore queues, live caches or API IDs.
local function historyKey(service)
	local ctx = service:Context()
	return ctx and ctx.project .. ":" .. ctx.region .. ":" .. ctx.name:lower()
end
local function savedProfile(value)
	if type(value) ~= "table" then return nil end
	return { name = P.FullName(value.name), classID = P.Integer(value.classID, 1, 30),
		itemLevel = P.Integer(value.itemLevel, 0, 10000), specIDs = P.CopySpecIDs(value.specIDs) or {} }
end
local function savedMessages(value)
	local messages = {}
	if type(value) ~= "table" then return messages end
	for index = 1, S.maxMessages do
		local m = value[index]
		if type(m) == "table" and P.Text(m.text) and type(m.incoming) == "boolean" then
			messages[#messages + 1] = { text = P.Truncate(m.text, S.maxMessageBytes), incoming = m.incoming,
				activityID = P.Integer(m.activityID, 1, 10000000), profile = savedProfile(m.profile) }
		end
	end
	return messages
end
local function savedSession(value)
	value = P.Text(value)
	return value and #value <= 24 and value:match("^[%w]+$") and value or nil
end
local savedEndReasons = { chat_cancelled = true, chat_joined = true, chat_party_changed = true,
	chat_seeking_stopped = true, chat_recruitment_stopped = true, chat_permission_lost = true,
	chat_activity_changed = true, chat_mismatch = true, chat_republished = true, chat_recreated = true,
	chat_role_changed = true, chat_contact_lost = true, chat_connect_failed = true,
	chat_peer_capacity = true, chat_capacity = true, chat_login_ended = true }
function Chat:SaveHistory()
	local service = self.seeking
	local store = service.adapter.ChatStore and service.adapter.ChatStore()
	local key, epoch = historyKey(service), service.adapter.Epoch and service.adapter.Epoch()
	if type(store) ~= "table" or not key or not epoch then return end
	local items = {}
	for _, id in ipairs(self.order) do
		local c = self:Get(id)
		-- A deliberately closed, completed conversation needs no archive entry.
		if c and not c.previewOnly and not (c.ended and c.closed and c.unread == 0 and c.draft == "" and not c.pendingSend) then
			items[#items + 1] = {
				name = c.name, context = c.context, messages = savedMessages(c.messages), draft = c.draft, unread = c.unread,
				closed = c.closed, hidden = c.hidden, ended = c.ended, endReason = c.endReason,
				lastIncomingSerial = c.lastIncomingSerial,
				profile = savedProfile(c.profile), classFile = c.classFile, recordMode = c.recordMode,
				token = c.token, peerSession = c.peerSession, publicationGeneration = c.publicationGeneration,
				recruitmentGeneration = c.recruitmentGeneration, requestRevision = c.requestRevision, activityID = c.activityID,
				ready = c.ready, established = c.established, peerSequence = c.peerSequence,
				applicationRequest = c.applicationRequest, applicationConfirmed = c.applicationConfirmed,
				sendFailed = c.sendFailed or c.pendingSend ~= nil,
				recoveryDeadline = epoch + math.max(0, c.recoveryUntil and c.recoveryUntil - service:Now() or RECOVERY_TIMEOUT),
			}
			if #items >= S.maxConversations then break end
		end
	end
	local recovery = service.communicationRecovery
	store[key] = { version = 1, at = epoch, conversations = items, serial = self.serial, statusSerial = self.statusSerial,
		continuity = { session = service.transport.session, sequence = service.transport.sequence, revision = service.revision,
			publicationGeneration = service.publicationGeneration or recovery and recovery.publicationGeneration,
			recruitmentGeneration = service.recruitmentGeneration, recruitmentActive = service.recruitmentActive,
			untilEpoch = recovery and epoch + math.max(0, recovery.untilAt - service:Now()) or epoch + RECOVERY_TIMEOUT } }
end
function Chat:RestoreHistory(initial, reloading)
	if self.historyLoaded then return end
	self.historyLoaded = true
	local service = self.seeking
	local store = service.adapter.ChatStore and service.adapter.ChatStore()
	local key, epoch = historyKey(service), service.adapter.Epoch and service.adapter.Epoch()
	local saved = type(store) == "table" and key and store[key]
	if type(saved) ~= "table" or saved.version ~= 1 or type(saved.conversations) ~= "table" then return end
	local continuity = type(saved.continuity) == "table" and saved.continuity or {}
	saved.continuity = nil -- One-shot authority; history remains available on future logins.
	local at, untilEpoch = P.Integer(saved.at, 1, 100000000000), tonumber(continuity.untilEpoch)
	local resume = not initial and reloading == true and epoch and at and epoch >= at and epoch - at < RECOVERY_TIMEOUT
		and untilEpoch and untilEpoch > epoch and untilEpoch <= at + RECOVERY_TIMEOUT
		and savedSession(continuity.session) and P.Integer(continuity.sequence, 0, 2147483000)
		and P.Integer(continuity.revision, 0, 2147483000)
	self.serial = P.Integer(saved.serial, 0, 2147483000) or 0
	self.statusSerial = P.Integer(saved.statusSerial, 0, 2147483000) or 0
	for index = 1, S.maxConversations do
		local item = saved.conversations[index]
		local name = type(item) == "table" and P.FullName(item.name)
		if name and (item.context == "board" or item.context == "seeking") and not service.adapter.Blocked(name) then
			-- Historical records (including their profile) are immutable after
			-- validation. Share them with the stored history, but keep both arrays
			-- separate so appending/evicting live messages cannot edit the snapshot.
			local messages, storedMessages = savedMessages(item.messages), {}
			for messageIndex, message in ipairs(messages) do storedMessages[messageIndex] = message end
			item.messages = storedMessages
			self.serial = self.serial + 1
			local c = { key = "saved:" .. self.serial, name = name, context = item.context, messages = messages,
				draft = P.Truncate(item.draft, S.sendMaxBytes), unread = P.Integer(item.unread, 0, 1000000) or 0, revision = 0,
				closed = item.closed == true or nil, hidden = item.hidden == true or nil,
				lastIncomingSerial = P.Integer(item.lastIncomingSerial, 1, 1000000000000),
				profile = savedProfile(item.profile), recordMode = item.recordMode == "party" and "party" or "solo",
				publicationGeneration = P.Integer(item.publicationGeneration, 1, 2147483647),
				recruitmentGeneration = P.Integer(item.recruitmentGeneration, 1, 2147483647),
				requestRevision = P.Integer(item.requestRevision, 1, 2147483647),
				activityID = P.Integer(item.activityID, 1, 10000000), peerSession = savedSession(item.peerSession),
				peerSequence = P.Integer(item.peerSequence, 1, 2147483647),
				applicationRequest = P.Integer(item.applicationRequest, 1, 2147483647),
				applicationConfirmed = item.applicationConfirmed == true or nil,
					established = item.established == true or nil, sendFailed = item.sendFailed == true or nil }
			self.incomingSerial = math.max(self.incomingSerial or 0, c.lastIncomingSerial or 0)
			local token = P.Text(item.token)
			c.token = token and #token <= 12 and token:match("^%d+$") and token or nil
			local class = P.Text(item.classFile)
			c.classFile = class and #class <= 20 and class:match("^[A-Z]+$") and class or nil
			local deadline = tonumber(item.recoveryDeadline)
			local valid = resume and item.ready == true and not item.ended and c.token and c.peerSession
				and c.publicationGeneration and c.recruitmentGeneration and c.activityID
				and deadline and deadline > epoch and deadline <= at + RECOVERY_TIMEOUT
			if service.recruitmentChangedBeforeHistory then valid = false end
			if valid then
				c.ready, c.recovering, c.peerAt = true, true, service:Now()
				c.recoveryUntil = service:Now() + math.min(deadline, untilEpoch) - epoch
			else
				c.ended = true
				c.endReason = item.ended and savedEndReasons[item.endReason] and item.endReason
					or service.recruitmentChangedBeforeHistory and "chat_recreated"
					or initial and "chat_login_ended" or item.ready ~= true and "chat_connect_failed" or "chat_contact_lost"
			end
			self.conversations[c.key], self.order[#self.order + 1] = c, c.key
		end
	end
	if resume and self:HasRecoverableContacts() then
		continuity.publicationGeneration = P.Integer(continuity.publicationGeneration, 1, 2147483647)
		service.chatContinuity = continuity
		service.publicationGeneration = continuity.publicationGeneration
		service.recruitmentGeneration = P.Integer(continuity.recruitmentGeneration, 1, 2147483647)
		service.recruitmentActive = continuity.recruitmentActive == true
		if service.recruitmentActive then
			service.communicationRecovery = { untilAt = service:Now() + untilEpoch - epoch, session = continuity.session,
				sequence = continuity.sequence, revision = continuity.revision }
		end
	end
	self:Notify()
end
function Chat:Start()
	if self.frame then return end
	if GF.RaidSeekingChatSoundBridge then GF.RaidSeekingChatSoundBridge:Init(self) end
	local frame = CreateFrame("Frame")
	self.frame = frame
	frame:RegisterEvent("CHAT_MSG_WHISPER"); frame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
	frame:SetScript("OnEvent", function(_, event, message, sender, _, _, _, _, _, _, _, _, lineID, guid)
		self:OnWhisper(event, message, sender, lineID, guid)
	end)
	local elapsedTime = 0
	frame:SetScript("OnUpdate", function(_, elapsed)
		elapsedTime = elapsedTime + elapsed
		if elapsedTime >= 0.5 then elapsedTime = 0; self:SyncContacts() end
	end)
	self.seeking:AddListener(function() self:SyncContacts() end)
	self:SyncContacts()
end
GF.RaidSeekingChatService = Chat.New(GF.RaidSeekingService)
GF.RaidSeekingChatService.New = Chat.New
