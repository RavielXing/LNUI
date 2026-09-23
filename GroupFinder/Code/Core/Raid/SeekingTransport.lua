local _, GF = ...

local P = GF.RaidSeekingProtocol
local Transport = {}
Transport.__index = Transport
GF.RaidSeekingTransport = Transport
Transport.CHANNEL = "魔兽集合石"
Transport.PREFIX = "GF_RaidSeek1"

local function accessible(value)
	return not GF.Compat or GF.Compat.IsAccessibleValue(value)
end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	if ok and accessible(value) then return value end
end

local Native = {}
Transport.Native = Native
function Native.Now() return GetTime() end
function Native.Locked()
	-- Activating is announced before the raw chat API flips. Reuse the shared
	-- event projection so channel traffic and whisper admission stop together.
	local availability = GF.Availability
	if availability and call(availability.IsRestricted, availability) ~= false then return true end
	local locked = call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)
	return locked ~= false
end
function Native.Context()
	if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return nil end
	local ok, name, realm = pcall(UnitFullName, "player")
	name, realm = P.Text(name), P.Text(realm)
	if not ok or not name then return nil end
	if not realm or realm == "" then realm = P.Text(call(GetNormalizedRealmName)) end
	local fullName = realm and P.FullName(name .. "-" .. realm)
	local region = P.Integer(call(GetCurrentRegion), 1, 20)
	local faction = P.Text(call(UnitFactionGroup, "player"))
	if not fullName or not region or (faction ~= "Alliance" and faction ~= "Horde") then return nil end
	return { project = WOW_PROJECT_ID, region = region, name = fullName, realm = realm, faction = faction }
end
function Native.ChannelID()
	local ok, id, name = pcall(GetChannelName, Transport.CHANNEL)
	if ok and P.Text(name) == Transport.CHANNEL then return P.Integer(id, 1, 1000) end
end
function Native.Join()
	if type(JoinPermanentChannel) ~= "function" then return false end
	-- Match the user's successful empty-password join through Blizzard's dialog.
	return pcall(JoinPermanentChannel, Transport.CHANNEL, "",
		DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME:GetID() or 1, 1)
end
function Native.Leave()
	if type(LeaveChannelByName) == "function" then pcall(LeaveChannelByName, Transport.CHANNEL) end
end
function Native.Send(packet, channelID)
	if Native.Locked() then return false, "locked" end
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false, "unavailable" end
	-- Retail addon CHANNEL messages use their own prefix and event. Ordinary
	-- SendChatMessage CHANNEL requires a hardware event and cannot carry ticks.
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, Transport.PREFIX, packet, "CHANNEL", tostring(channelID))
	if not ok or not accessible(result) then return false, "send_failed" end
	local results = Enum and Enum.SendAddonMessageResult or {}
	if result == true or result == (results.Success or 0) then return true, nil, result end
	if result == (results.AddonMessageThrottle or 3) or result == (results.ChannelThrottle or 8) then
		return false, "throttled", result
	end
	if result == (results.AddOnMessageLockdown or 11) then return false, "locked", result end
	if result == (results.InvalidChatType or 4) then return false, "unsupported_channel", result end
	if result == (results.InvalidChannel or 7) then return false, "channel_lost", result end
	return false, "send_failed", result
end
function Native.Sender(sender, guid)
	sender, guid = P.Text(sender), P.Text(guid)
	if not sender then return nil end
	local full = P.FullName(sender)
	if full then return full end
	-- Short chat names need native GUID evidence for their realm. Never fill
	-- an arbitrary name claimed by a payload with the local realm.
	if not guid or type(GetPlayerInfoByGUID) ~= "function" then return nil end
	local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
	name, realm = P.Text(name), P.Text(realm)
	if not ok or not name or name:lower() ~= sender:lower() then return nil end
	if realm == "" then realm = P.Text(call(GetNormalizedRealmName)) end
	return realm and P.FullName(name .. "-" .. realm) or nil
end

function Native.Start(owner)
	local result = call(C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix, Transport.PREFIX)
	local results = Enum and Enum.RegisterAddonMessagePrefixResult or {}
	if result ~= true and result ~= (results.Success or 0) and result ~= (results.DuplicatePrefix or 1) then
		return false, "prefix_failed"
	end
	local frame = owner.frame or CreateFrame("Frame")
	owner.frame = frame
	for _, event in ipairs({ "CHAT_MSG_ADDON", "CHAT_MSG_CHANNEL_NOTICE",
		"GROUP_ROSTER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
		"UPDATE_INSTANCE_INFO", "INSPECT_READY",
		"ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do frame:RegisterEvent(event) end
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then
			if Native.Locked() then return end
			local prefix, message, distribution, sender, _, _, localID = ...
			if P.Text(prefix) ~= Transport.PREFIX or P.Text(distribution) ~= "CHANNEL" then return end
			local channelID = P.Integer(localID, 1, 1000)
			if not channelID or channelID ~= Native.ChannelID() then return end
			sender = Native.Sender(sender)
			if sender then owner:Receive(message, sender) end
		elseif event == "CHAT_MSG_CHANNEL_NOTICE" then
			if Native.Locked() then return end
			local notice, _, _, _, _, _, _, _, channelName = ...
			if P.Text(channelName) == Transport.CHANNEL then
				owner.notice = P.Text(notice)
				if owner.notice == "WRONG_PASSWORD" or owner.notice == "BANNED" then owner:Fail("channel_denied") end
			end
		elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
			local addon = ...
			if P.Text(addon) == (GF.addonName or "GroupFinder") then owner:Fail("restricted") end
		elseif owner.onRosterChanged then owner.onRosterChanged(event, ...) end
	end)
	owner.timer = C_Timer.NewTicker(0.5, function() owner:Tick() end)
	return true
end
function Native.Stop(owner)
	if owner.timer then owner.timer:Cancel(); owner.timer = nil end
	if owner.frame then owner.frame:UnregisterAllEvents() end
end

function Transport.New(adapter)
	return setmetatable({ adapter = adapter or Native, state = "disconnected", sequence = 0,
		queue = {}, assemblies = {}, seen = {}, counters = { tx = 0, rx = 0, invalid = 0, echoes = 0 } }, Transport)
end
function Transport:Changed(event, kind)
	if self.onChanged then self.onChanged(event, kind) end
end
function Transport:Fail(reason)
	self.state, self.reason, self.queue = "error", reason, {}
	self.awaitEchoSince = nil
	self.adapter.Stop(self)
	self:Changed()
end
function Transport:Connect(continuity)
	if self.adapter.Locked() then return false, "locked" end
	local context = self.adapter.Context()
	if not context then return false, "identity" end
	-- A retry replaces our session, not native channel membership. Leaving here
	-- can acknowledge after the new session has already sent to the old local ID.
	local ownedChannel = self.joinedByUs == true
	if self.state ~= "disconnected" then self:Disconnect(true) end
	self.context, self.queue, self.assemblies, self.seen = context, {}, {}, {}
	-- A bounded, local chat checkpoint can continue the original lifetime. Keep
	-- sequence numbers monotonic; never replay an old packet or saved send queue.
	local resume = type(continuity) == "table" and P.Text(continuity.session)
		and continuity.session:match("^[%w]+$") and #continuity.session <= 24
		and P.Integer(continuity.sequence, 0, 2147483000)
	self.sequence = resume and continuity.sequence or 0
	self.session = resume and continuity.session or string.format("%x%x", math.floor(self.adapter.Now() * 1000), math.random(1, 16777215))
	self.counters = { tx = 0, rx = 0, invalid = 0, echoes = 0 }
	self.state, self.reason, self.echoAt, self.lastSendResult = "joining", nil, nil, nil
	self.lastSendChannelID = nil
	self.awaitEchoSince = nil
	self.joinDeadline, self.nextSend = self.adapter.Now() + 12, 0
	local needsJoin = not self.adapter.ChannelID()
	self.joinedByUs = ownedChannel or needsJoin
	local started, reason = self.adapter.Start(self)
	if started == false then self:Fail(reason or "unavailable"); return false, self.reason end
	if needsJoin and not self.adapter.Join() then self:Fail("join_failed"); return false, self.reason end
	self:Tick()
	if self.state == "error" then return false, self.reason end
	self:Changed()
	return true
end
function Transport:Disconnect(logout)
	self.adapter.Stop(self)
	if not logout and self.joinedByUs and not self.adapter.Locked() then self.adapter.Leave() end
	self.state, self.queue, self.assemblies, self.seen = "disconnected", {}, {}, {}
	self.echoAt, self.channelID, self.joinedByUs = nil, nil, nil
	self.awaitEchoSince = nil
	self:Changed()
end
function Transport:HasQueued(replaceKey)
	for _, packet in ipairs(self.queue) do
		if packet.replaceKey == replaceKey then return true end
	end
	return false
end

function Transport:CancelQueued(replaceKey)
	for index = #self.queue, 1, -1 do
		if self.queue[index].replaceKey == replaceKey then table.remove(self.queue, index) end
	end
end
function Transport:Send(fields, replaceKey)
	if self.state ~= "ready" then return nil, "not_connected" end
	if self.adapter.Locked() then return nil, "locked" end
	local body = P.Encode(fields)
	if not body then return nil, "payload" end
	if replaceKey then
		for _, packet in ipairs(self.queue) do
			if packet.replaceKey == replaceKey and packet.message.body == body then
				-- Preserve a partially sent message and its original timeout.
				return packet.message.sequence
			end
		end
	end
	self.sequence = self.sequence + 1
	local packets = P.Packets(self.session, self.sequence, fields)
	if not packets then return nil, "payload" end
	local queuedCount = #self.queue
	if replaceKey then
		for _, packet in ipairs(self.queue) do
			if packet.replaceKey == replaceKey then queuedCount = queuedCount - 1 end
		end
	end
	if queuedCount + #packets > 48 then return nil, "busy" end
	if replaceKey then
		self:CancelQueued(replaceKey)
	end
	-- All contact controls share one FIFO priority, including presence updates:
	-- reordering those controls would violate the receiver's sequence checks.
	local kind = fields[1]
	local priority = (kind == "C" or kind == "X" or kind == "Q") and 2
		or (kind == "B" or kind == "H") and 0 or 1
	local message = { body = body, sequence = self.sequence, priority = priority }
	for index, packet in ipairs(packets) do
		self.queue[#self.queue + 1] = { packet = packet, at = self.adapter.Now(), replaceKey = replaceKey,
			message = message, last = index == #packets }
	end
	local sequence = self.sequence
	self:Flush()
	if self.state ~= "ready" then return nil, self.reason end
	return sequence
end
function Transport:Prioritize()
	local first = self.queue[1]
	if not first or first.message.started then return end
	local chosen, now = first, self.adapter.Now()
	-- Finish fragments together. Promote aged work after eight seconds so a
	-- stream of contacts cannot starve publications or boss details indefinitely.
	for _, packet in ipairs(self.queue) do
		local aged, chosenAged = now - packet.at >= 8, now - chosen.at >= 8
		if (aged and not chosenAged) or (aged and chosenAged and packet.at < chosen.at)
			or (not aged and not chosenAged and packet.message.priority > chosen.message.priority) then
			chosen = packet
		end
	end
	if chosen.message == first.message then return end
	local promoted, remaining = {}, {}
	for _, packet in ipairs(self.queue) do
		local target = packet.message == chosen.message and promoted or remaining
		target[#target + 1] = packet
	end
	for _, packet in ipairs(remaining) do promoted[#promoted + 1] = packet end
	self.queue = promoted
end
function Transport:Flush()
	if self.state ~= "ready" or #self.queue == 0 or self.adapter.Now() < self.nextSend then return end
	self:Prioritize()
	-- Recheck gameplay eligibility before draining a delayed or throttled packet.
	if self.onBeforeFlush and self.onBeforeFlush(self.queue[1].replaceKey) == false then return end
	if self.adapter.Locked() then self:Fail("locked"); return end
	local channelID = self.adapter.ChannelID()
	if not channelID then self:Fail("channel_lost"); return end
	local packet = self.queue[1]
	if self.adapter.Now() - packet.at > 25 then self:Fail("send_timeout"); return end
	self.nextSend = self.adapter.Now() + 0.8
	local previousAwait = self.awaitEchoSince
	self.awaitEchoSince = self.awaitEchoSince or self.adapter.Now()
	self.lastSendChannelID = channelID
	local sent, reason, result = self.adapter.Send(packet.packet, channelID)
	self.lastSendResult = result
	-- A synchronous rejection event may already have stopped the transport.
	if self.state ~= "ready" then return end
	if not sent then
		if reason == "throttled" then
			self.awaitEchoSince = previousAwait
			self.nextSend = self.adapter.Now() + 2
			self.counters.throttled = (self.counters.throttled or 0) + 1
		else self:Fail(reason or "send_failed") end
		return
	end
	if self.queue[1] == packet then table.remove(self.queue, 1) end
	packet.message.started = true
	self.counters.tx = self.counters.tx + 1
	if packet.last and self.onSent then self.onSent(packet.replaceKey, packet.message.sequence) end
end
function Transport:Tick()
	if self.state == "error" or self.state == "disconnected" then return end
	local now = self.adapter.Now()
	if self.state == "joining" then
		self.channelID = self.adapter.ChannelID()
		if self.channelID then
			self.state = "ready"
			self:Changed()
		elseif now >= self.joinDeadline then self:Fail("join_timeout") end
	end
	if self.state == "ready" and not self.adapter.ChannelID() then self:Fail("channel_lost") end
	if self.state == "ready" and self.awaitEchoSince and now - self.awaitEchoSince > 30 then self:Fail("echo_timeout") end
	self:PruneReceived(now)
	self:Flush()
	if self.state == "error" or self.state == "disconnected" then return end
	if self.onTick then self.onTick(now) end
end
function Transport:PruneReceived(now)
	for key, assembly in pairs(self.assemblies) do
		if now - assembly.at > P.ASSEMBLY_TTL then self.assemblies[key] = nil end
	end
	for key, seenAt in pairs(self.seen) do
		if now - seenAt > P.TTL * 2 then self.seen[key] = nil end
	end
end
function Transport:Receive(message, sender)
	if self.state ~= "ready" or self.adapter.Locked() then return end
	sender = P.FullName(sender)
	local packet = P.ParsePacket(message)
	if not sender or not packet then self.counters.invalid = self.counters.invalid + 1; return end
	self.counters.rx = self.counters.rx + 1
	local now = self.adapter.Now()
	local key = sender:lower() .. ":" .. packet.session .. ":" .. packet.sequence
	if self.seen[key] then return end
	local assembly = self.assemblies[key]
	if not assembly then
		local total = 0
		for _ in pairs(self.assemblies) do total = total + 1 end
		if total >= 64 then return end
		assembly = { at = now, total = packet.total, parts = {}, count = 0, bytes = 0 }
		self.assemblies[key] = assembly
	end
	if assembly.total ~= packet.total then self.assemblies[key] = nil; return end
	if assembly.parts[packet.index] then
		if assembly.parts[packet.index] ~= packet.chunk then self.assemblies[key] = nil end
		return
	end
	assembly.parts[packet.index] = packet.chunk
	assembly.count, assembly.bytes = assembly.count + 1, assembly.bytes + #packet.chunk
	if assembly.bytes > P.MAX_BODY_BYTES then self.assemblies[key] = nil; return end
	if assembly.count ~= assembly.total then return end
	self.assemblies[key] = nil
	local fields = P.Decode(table.concat(assembly.parts))
	local context = self.context
	if not fields or P.Integer(fields[2], 1, 100) ~= context.project
		or P.Integer(fields[3], 1, 20) ~= context.region then return end
	local seenCount = 0
	for _ in pairs(self.seen) do seenCount = seenCount + 1 end
	if seenCount >= 1024 then return end
	self.seen[key] = now
	local isSelf = sender:lower() == context.name:lower()
	if isSelf and packet.session ~= self.session then return end
	if isSelf then self.echoAt, self.awaitEchoSince = now, nil; self.counters.echoes = self.counters.echoes + 1 end
	if self.onMessage then self.onMessage(fields, sender, packet.session, isSelf, packet.sequence) end
	self:Changed("message", fields[1])
end
