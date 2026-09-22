local _, GF = ...
local P, Transport = GF.RaidSeekingProtocol, GF.RaidSeekingTransport
local Sync = { PREFIX = "GF_RaidParty1" }
local ITEM_LEVEL_TTL, ITEM_LEVEL_POLL, ITEM_LEVEL_RETRY = 90, 30, 3
local ITEM_LEVEL_SEND_INTERVAL = 0.5
Sync.__index = Sync
GF.RaidSeekingPartySync = Sync

-- PARTY carries member equipment to the captain and confirmed publications
-- back to members. It never supplies a public publication echo or chat.
local Native = {}
Sync.Native = Native
local function safe(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	if ok and (not GF.Compat or GF.Compat.IsAccessibleValue(value)) then return value end
end
function Native.Roster()
	local group = GF.RaidSeekingService.Native.Group()
	if not group.grouped or group.raid or group.instance or not group.count or group.count < 1 then return nil end
	local members, guids, identities, leader = {}, {}, {}, nil
	for index = 0, group.count do
		local unit = index == 0 and "player" or "party" .. index
		if type(UnitFullName) ~= "function" then return nil end
		local ok, name, realm = pcall(UnitFullName, unit)
		name, realm = P.Text(name), P.Text(realm)
		if not ok or not name then return nil end
		if not realm or realm == "" then realm = P.Text(safe(GetNormalizedRealmName)) end
		name = realm and P.FullName(name .. "-" .. realm)
		if not name then return nil end
		members[name:lower()] = name
		guids[name:lower()] = P.Text(safe(UnitGUID, unit))
		identities[#identities + 1] = name:lower() .. ":" .. (guids[name:lower()] or "")
		if safe(UnitIsGroupLeader, unit, LE_PARTY_CATEGORY_HOME) == true then leader = name end
	end
	if not leader then return nil end
	table.sort(identities)
	return { members = members, guids = guids, leader = leader, signature = leader:lower() .. ";" .. table.concat(identities, ";") }
end
function Native.Start(self)
	self.handle = GF.AddonMessageTransport:RegisterProtocol(Sync.PREFIX, function(_, message, distribution, sender)
		self:Receive(message, distribution, sender)
	end, { channelPolicy = GF.AddonMessageTransport.CHANNEL_POLICY.PARTY_ONLY })
	if not self.handle or not self.handle:IsRegistered() then return false end
	self.frame = self.frame or CreateFrame("Frame")
	for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_JOINED", "GROUP_LEFT", "PLAYER_ENTERING_WORLD",
		"PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE" }) do
		self.frame:RegisterEvent(event)
	end
	self.frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
			self:ScheduleItemLevel()
		else self:Tick() end
	end)
	return true
end
function Native.Drive(self, active)
	if active and not self.timer then self.timer = C_Timer.NewTicker(0.5, function() self:Tick() end)
	elseif not active and self.timer then self.timer:Cancel(); self.timer = nil end
end
function Native.Stop(self)
	Native.Drive(self, false)
	if self.frame then self.frame:UnregisterAllEvents() end
end
function Native.Clear(self, key)
	if self.handle then self.handle:ClearQueue(key, "party-sync-reset") end
end
function Native.Queue(self, packets, key, priority)
	return self.handle and self.handle:QueueMessages(packets, {
		replaceKey = key, priority = priority or "normal", maxAge = 24,
	})
end

function Sync.New(service, adapter)
	local self = setmetatable({ service = service, adapter = adapter or Native,
		sequence = 0, requests = {}, state = "unavailable" }, Sync)
	self.receiver = Transport.New(service.transport.adapter)
	self.receiver.onMessage = function(...) self:OnMessage(...) end
	return self
end
function Sync:Now() return self.service:Now() end
function Sync:Notify() self.service:Notify("party_sync") end
function Sync:Start()
	if self.started then return end
	self.started = self.adapter.Start(self) == true
	if self.started then self:Tick() end
end
function Sync:Stop()
	self.started = false
	self.adapter.Clear(self)
	self.adapter.Stop(self)
	self.signature, self.roster, self.record, self.token, self.requests = nil, nil, nil, nil, {}
	self.recordToken, self.recordBody = nil, nil
	self:ResetItemLevels()
	self.state, self.authoritative = "unavailable", nil
end
function Sync:RefreshRoster()
	local roster, ctx = self.adapter.Roster(), self.service:Context()
	if not ctx or not roster or not roster.members[ctx.name:lower()] then roster = nil end
	local signature = roster and roster.signature
	local group = self.service.adapter.Group()
	-- Unit names/leader flags can arrive after the group event. Keep the party
	-- driver alive through incomplete roster reads, without starting a channel.
	self.adapter.Drive(self, group.grouped and not group.raid and not group.instance)
	if signature == self.signature then return false end
	self.signature, self.roster, self.context = signature, roster, ctx
	self.adapter.Clear(self)
	self.receiver.assemblies, self.receiver.seen = {}, {}
	self.receiver.state, self.receiver.context = "ready", ctx
	self.record, self.token, self.deadline, self.nextAttempt = nil, nil, nil, nil
	self.recordToken, self.recordBody = nil, nil
	self.authoritative, self.requests, self.lastNotice, self.stamp = nil, {}, nil, nil
	self.state = roster and "loading" or "unavailable"
	self.nextPoll = roster and self:Now() or nil
	self:ResetItemLevels()
	self:Notify()
	return true
end
function Sync:IsLeader()
	return self.roster and self.context and self.roster.leader:lower() == self.context.name:lower()
end
function Sync:MatchesRoster(record)
	if not record or record.mode ~= "party" or not self.roster
		or record.owner:lower() ~= self.roster.leader:lower() then return false end
	local count = 0
	for _ in pairs(self.roster.members) do count = count + 1 end
	if #record.members ~= count then return false end
	for _, member in ipairs(record.members) do if not self.roster.members[member.name:lower()] then return false end end
	return true
end
function Sync:Publication()
	local record = self.service:GetMyActivity()
	if self:IsLeader() and not self.service:HasRecruitment() and self:MatchesRoster(record) then return record end
end
function Sync:Send(fields, session, sequence, key, priority)
	local packets = P.Packets(session, sequence, fields)
	return packets and self.adapter.Queue(self, packets, key, priority)
end
function Sync:NewToken()
	self.sequence = self.sequence + 1
	return string.format("%06x%08x%06x", math.random(1, 16777215),
		math.floor(self:Now() * 1000) % 4294967296, self.sequence % 16777216)
end

function Sync:ResetItemLevels()
	self.itemLevels, self.itemLevelSequence = {}, 0
	self.itemLevelChallenges = {}
	self.itemLevelToken, self.itemLevelRequestAt, self.itemLevelRequestSequence = nil, nil, 0
	self.itemLevelNextPoll, self.itemLevelAttempts = nil, 0
	self.localItemLevel, self.itemLevelReplyPending = nil, nil
	self.itemLevelDue, self.itemLevelReadAttempts = self:Now() + ITEM_LEVEL_SEND_INTERVAL, 0
	if self.roster and self:IsLeader() then self.itemLevelNextPoll = self:Now() end
end

function Sync:ScheduleItemLevel()
	self.itemLevelDue = self.itemLevelDue or (self:Now() + ITEM_LEVEL_SEND_INTERVAL)
	self.itemLevelReadAttempts = 0
end

function Sync:GetItemLevel(guid)
	if not self.started then return nil end
	self:RefreshRoster()
	local entry = self:IsLeader() and self.itemLevels and self.itemLevels[guid]
	if entry and entry.expiresAt > self:Now() and self.roster.guids[entry.sender] == guid then return entry.value end
end

function Sync:ReceiveItemLevel(fields, sender, token, sequence)
	if not self:IsLeader() or #fields ~= 5 or token ~= self.itemLevelChallenges[sender:lower()] then return end
	local guid, value = P.Text(fields[4]), P.Integer(fields[5], 1, 10000)
	sequence = P.Integer(sequence, 1, 2147483647)
	local key = sender:lower()
	if not guid or self.roster.guids[key] ~= guid or not value or not sequence then return end
	local previous = self.itemLevels[guid]
	if previous and previous.token == token and sequence <= previous.sequence then return end
	self.itemLevels[guid] = { sender = key, value = value, token = token, sequence = sequence,
		expiresAt = self:Now() + ITEM_LEVEL_TTL }
	if not previous or previous.value ~= value or previous.expiresAt <= self:Now() then
		self.service:OnItemLevelChanged()
	end
	for name in pairs(self.roster.members) do
		local memberGUID = self.roster.guids[name]
		if name ~= self.context.name:lower() and (not memberGUID or not self:GetItemLevel(memberGUID)) then return end
	end
	self.itemLevelRequestAt = nil
end

function Sync:RequestItemLevel(sender)
	local guid = self.roster.guids and self.roster.guids[sender:lower()]
	if not guid or not self.itemLevelToken then return end
	-- Per-member challenges also allow a reloaded sender's sequence to restart
	-- without accepting delayed reports from its previous addon session.
	local token = self:NewToken()
	self.itemLevelChallenges[sender:lower()] = token
	self.itemLevelRequestSequence = self.itemLevelRequestSequence + 1
	self:Send({ "G", self.context.project, self.context.region, guid }, token,
		self.itemLevelRequestSequence, "item-level-query:" .. sender:lower())
end

function Sync:TickItemLevels(now)
	if type(self.service.adapter.EquippedItemLevel) ~= "function" then return end
	local ctx = self.context
	if self:IsLeader() then
		for guid, entry in pairs(self.itemLevels) do
			if now >= entry.expiresAt then self.itemLevels[guid] = nil; self.service:OnItemLevelChanged() end
		end
		if now >= (self.itemLevelNextPoll or 0) then
			self.itemLevelToken, self.itemLevelAttempts = self:NewToken(), 0
			self.itemLevelRequestAt, self.itemLevelNextPoll = now, now + ITEM_LEVEL_POLL
		end
		if self.itemLevelRequestAt and now >= self.itemLevelRequestAt then
			for name in pairs(self.roster.members) do self.itemLevelChallenges[name] = self.itemLevelToken end
			self.itemLevelRequestSequence = self.itemLevelRequestSequence + 1
			self:Send({ "G", ctx.project, ctx.region }, self.itemLevelToken,
				self.itemLevelRequestSequence, "item-level-query")
			self.itemLevelAttempts = self.itemLevelAttempts + 1
			self.itemLevelRequestAt = self.itemLevelAttempts < 3 and now + ITEM_LEVEL_RETRY or nil
		end
	end
	if not self.itemLevelDue or now < self.itemLevelDue then return end
	self.itemLevelDue = nil
	local value = P.Integer(self.service.adapter.EquippedItemLevel(), 1, 10000)
	if not value then
		self.itemLevelReadAttempts = self.itemLevelReadAttempts + 1
		if self.itemLevelReadAttempts < 3 then self.itemLevelDue = now + 1 end
		return
	end
	local changed = value ~= self.localItemLevel
	self.localItemLevel = value
	if self:IsLeader() then
		if changed then self.service:OnItemLevelChanged() end
		return
	end
	if not self.itemLevelToken or (not changed and not self.itemLevelReplyPending) then return end
	local guid = self.roster.guids[ctx.name:lower()]
	if not guid then return end
	self.itemLevelSequence = self.itemLevelSequence + 1
	if self:Send({ "E", ctx.project, ctx.region, guid, value }, self.itemLevelToken,
		self.itemLevelSequence, "item-level-reply") then
		self.itemLevelReplyPending = nil
	else self.itemLevelDue = now + ITEM_LEVEL_RETRY; self.itemLevelReplyPending = true end
end
function Sync:Request()
	local now = self:Now()
	self.token, self.attempts, self.deadline = self:NewToken(), 0, now + 24
	self.nextAttempt, self.nextPoll = now, now + 30
end
function Sync:EnterFeature()
	self:Start()
	self:RefreshRoster()
	-- Tab changes cannot continually restart a pending request or its timeout.
	if self.roster and not self:IsLeader() and not self.deadline
		and (not self.lastRequest or self:Now() - self.lastRequest >= 3) then
		self:Request()
	end
	-- A background poll stays quiet after a timeout. Explicit entry/retry must
	-- show that same in-flight request, without resetting its challenge/deadline.
	if self.deadline and self.state == "unavailable" then
		self.state = "loading"; self:Notify()
	end
	self:Tick()
end
function Sync:GetView()
	if self.started then self:RefreshRoster() end
	local record = self.record
	if record and record.expiresAt > self:Now() and self:MatchesRoster(record) then return record, "live", true end
	if record then return nil, "unavailable", self.authoritative end
	return nil, self.state, self.authoritative
end
function Sync:Reply(sender, token)
	local ctx, record = self.context, self:Publication()
	self.adapter.Clear(self, "boss:" .. sender)
	local fields = record and P.RecordFields(record, ctx.project, ctx.region) or { "X", ctx.project, ctx.region }
	self:Send(fields, token, 1, "reply:" .. sender)
	if not record then return end
	local packets = {}
	-- Boss detail belongs to the same confirmed revision. Pending edits cannot
	-- add data from a future publication to the member's snapshot.
	local detail = self.service.current
	if not detail or detail.revision ~= record.revision then detail = record end
	for index, entry in ipairs(detail.progress or {}) do
		local data = P.BossData(entry)
		if data then
			local parts = P.Packets(token, index + 1, { "B", ctx.project, ctx.region, record.revision, entry.activityID, data })
			for _, packet in ipairs(parts or {}) do packets[#packets + 1] = packet end
		end
	end
	if #packets > 0 then self.adapter.Queue(self, packets, "boss:" .. sender, "bulk") end
end
function Sync:ResolveSender(sender)
	sender = P.Text(sender)
	if not sender or not self.roster then return nil end
	local name = P.FullName(sender)
	if name then return self.roster.members[name:lower()] end
	-- Native events may omit the realm for a local character only. Never guess
	-- a remote realm or merge two same-named party members.
	local realm = self.context and self.context.realm
	name = realm and P.FullName(sender .. "-" .. realm)
	return name and self.roster.members[name:lower()]
end
function Sync:Receive(message, distribution, sender)
	if not self.started or P.Text(distribution) ~= "PARTY" then return end
	self:RefreshRoster()
	sender = self:ResolveSender(sender)
	if not sender or sender:lower() == self.context.name:lower() then return end
	local packet = P.ParsePacket(message)
	if not packet then return end
	if not self:IsLeader() then
		if sender:lower() ~= self.roster.leader:lower() then return end
		if packet.session ~= self.token then
			local fields = packet.total == 1 and P.Decode(packet.chunk)
			if not fields or not ((fields[1] == "R" and #fields == 3)
				or (fields[1] == "G" and (#fields == 3 or #fields == 4))) then return end
		end
	end
	self.receiver:Receive(message, sender)
end
function Sync:OnMessage(fields, sender, session, _, sequence)
	local kind, now = fields[1], self:Now()
	if kind == "E" then self:ReceiveItemLevel(fields, sender, session, sequence); return end
	if kind == "G" and (#fields == 3 or #fields == 4) and not self:IsLeader() then
		if fields[4] and fields[4] ~= self.roster.guids[self.context.name:lower()] then return end
		self.itemLevelToken, self.itemLevelReplyPending = session, true
		self:ScheduleItemLevel()
		return
	end
	if self:IsLeader() then
		if kind == "Q" and #fields == 3 then
			local previous = self.requests[sender:lower()]
			if previous and now - previous.at < 2 then return end
			self.requests[sender:lower()] = { token = session, at = now }
			self:Reply(sender:lower(), session)
			-- A reloaded peer may have no challenge even while its old cached
			-- gear is fresh. Ask that peer without making everyone else reply.
			self:RequestItemLevel(sender)
		end
		return
	end
	if kind == "R" and #fields == 3 then
		self.nextPoll = math.min(self.nextPoll or now, math.max(now, (self.lastRequest or 0) + 2))
		return
	end
	if session ~= self.token then return end
	if kind == "U" then
		local record = P.ReadRecord(fields, sender, session, now)
		if not self:MatchesRoster(record) then return end
		local previous = self.record
		if previous and previous.expiresAt <= now then previous = nil end
		local body = P.Encode(P.RecordFields(record, self.context.project, self.context.region))
		local unchanged = previous and body == self.recordBody
		-- The reply challenge authorizes supplements, not the visible activity's
		-- lifetime. Keep a stable display session until withdrawal/expiry/roster
		-- reset, so both renewals and real edits preserve existing row fades.
		self.recordToken, self.recordBody = session, body
		if unchanged then
			previous.expiresAt = record.expiresAt
			record = previous
		elseif previous then
			record.session = previous.session
			if previous.revision == record.revision then
				for _, entry in ipairs(record.progress) do
					for _, old in ipairs(previous.progress) do
						if entry.activityID == old.activityID and entry.done == old.done and entry.total == old.total then
							entry.bosses = old.bosses; break
						end
					end
				end
			end
		end
		local changed = not unchanged or self.state ~= "live"
		self.record, self.state, self.authoritative = record, "live", true
		self.deadline, self.nextAttempt = nil, nil
		if changed then self:Notify() end
	elseif kind == "X" and #fields == 3 then
		local changed = self.record ~= nil or self.state ~= "empty"
		self.record, self.state, self.authoritative = nil, "empty", true
		self.recordToken, self.recordBody = nil, nil
		self.deadline, self.nextAttempt = nil, nil
		if changed then self:Notify() end
	elseif kind == "B" and #fields == 6 then
		local record = self.record
		if not record or self.recordToken ~= session or record.revision ~= P.Integer(fields[4], 1, 2147483647) then return end
		for _, entry in ipairs(record.progress) do
			if entry.activityID == P.Integer(fields[5], 1, 10000000) then
				local bosses = P.ReadBossData(fields[6], entry.done, entry.total)
				if bosses and P.BossData(entry) ~= fields[6] then entry.bosses = bosses; self:Notify() end
				return
			end
		end
	end
end
function Sync:Tick()
	if not self.started then return end
	self:RefreshRoster()
	if not self.roster then return end
	local now, ctx = self:Now(), self.context
	self.receiver:PruneReceived(now)
	self:TickItemLevels(now)
	if self:IsLeader() then
		local record = self:Publication()
		local stamp = record and (record.session .. ":" .. record.revision) or "empty"
		self.state = record and "live" or "empty"
		if stamp ~= self.stamp and (not self.lastNotice or now - self.lastNotice >= 1) then
			self.stamp, self.lastNotice = stamp, now
			self:Send({ "R", ctx.project, ctx.region }, self:NewToken(), 1, "notice", "urgent")
		end
		return
	end
	if self.record and self.record.expiresAt <= now then
		self.record, self.recordToken, self.recordBody, self.state = nil, nil, nil, "unavailable"; self:Notify()
	end
	if self.nextPoll and now >= self.nextPoll then self:Request() end
	if self.deadline and now >= self.deadline then
		self.deadline, self.nextAttempt, self.token = nil, nil, nil
		if not self.record and self.state ~= "unavailable" then self.state = "unavailable"; self:Notify() end
	elseif self.nextAttempt and now >= self.nextAttempt then
		self.attempts = self.attempts + 1
		-- New challenge on each attempt rejects delayed snapshots from previous
		-- rosters, leaders, reloads and responses that overtook a cancellation.
		self.token = self:NewToken()
		self.lastRequest, self.nextAttempt = now, now + 8
		self:Send({ "Q", ctx.project, ctx.region }, self.token, 1, "query", "urgent")
	end
end
function Sync:Diagnostics()
	return "partySync=" .. self.state .. " prefix=" .. Sync.PREFIX .. " rx=" .. self.receiver.counters.rx
		.. " leader=" .. (self.roster and self.roster.leader or "-")
end

GF.RaidSeekingService.partySync = Sync.New(GF.RaidSeekingService)
