local _, GF = ...

GF.AddonMessageTransport = GF.AddonMessageTransport or {}
local Transport = GF.AddonMessageTransport

local DEFAULT_SEND_INTERVAL = 0.12
local DEFAULT_RETRY_DELAY = 0.5
local DEFAULT_MAX_SEND_AGE = 30
local MAX_NATIVE_MESSAGE_BYTES = 255
local PRIORITY_RANK = {
	urgent = 1,
	normal = 2,
	bulk = 3,
}
local CHANNEL_POLICY = {
	NATIVE = "native",
	INSTANCE_FIRST = "instance-first",
	RAID_FIRST = "raid-first",
	PARTY_ONLY = "party-only",
}

Transport.CHANNEL_POLICY = CHANNEL_POLICY

local Handle = {}
Handle.__index = Handle

local function now()
	return GetTime and GetTime() or 0
end

local function canonical(value)
	if type(value) ~= "string" then
		return nil
	end
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("%s+", "")
	return value ~= "" and string.lower(value) or nil
end

local function getUnitIdentity(unit)
	if UnitGUID then
		local ok, guid = pcall(UnitGUID, unit)
		if ok and type(guid) == "string" and guid ~= "" then
			return "guid:" .. string.lower(guid)
		end
	end
	local fullName
	if UnitFullName then
		local ok, name, realm = pcall(UnitFullName, unit)
		if ok and type(name) == "string" and name ~= "" then
			if type(realm) ~= "string" or realm == "" then
				realm = GetRealmName and GetRealmName() or ""
			end
			fullName = type(realm) == "string" and realm ~= ""
				and (name .. "-" .. realm) or name
		end
	end
	if not fullName and GetUnitName then
		local ok, value = pcall(GetUnitName, unit, true)
		if ok and type(value) == "string" and value ~= "" then
			fullName = value
		end
	end
	if not fullName and UnitName then
		local ok, value = pcall(UnitName, unit)
		if ok and type(value) == "string" and value ~= "" then
			fullName = value
		end
	end
	local identity = canonical(fullName)
	if identity then
		return identity
	end
	return "unit:" .. tostring(unit)
end

local function collectGroupUnits()
	local units = {}
	if IsInRaid and IsInRaid() then
		local count = GetNumGroupMembers and GetNumGroupMembers() or 0
		for index = 1, math.min(40, tonumber(count) or 0) do
			units[#units + 1] = "raid" .. index
		end
		return units
	end
	if IsInGroup and IsInGroup() then
		units[#units + 1] = "player"
		local count = GetNumSubgroupMembers
			and GetNumSubgroupMembers() or 0
		for index = 1, math.min(4, tonumber(count) or 0) do
			units[#units + 1] = "party" .. index
		end
	end
	return units
end

local function getGroupChannel(policy)
	if policy == CHANNEL_POLICY.PARTY_ONLY then
		return IsInGroup and IsInGroup()
			and not (IsInRaid and IsInRaid())
			and "PARTY"
			or nil
	end
	if policy == CHANNEL_POLICY.INSTANCE_FIRST then
		if IsInGroup and LE_PARTY_CATEGORY_INSTANCE
			and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
		then
			return "INSTANCE_CHAT"
		end
		if IsInRaid and IsInRaid() then
			return "RAID"
		end
		return IsInGroup and IsInGroup() and "PARTY" or nil
	end
	if policy == CHANNEL_POLICY.RAID_FIRST then
		if IsInRaid and IsInRaid() then
			return "RAID"
		end
		if IsInGroup and LE_PARTY_CATEGORY_INSTANCE
			and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
		then
			return "INSTANCE_CHAT"
		end
		return IsInGroup and IsInGroup() and "PARTY" or nil
	end
	local channel = IsInRaid and IsInRaid()
		and "RAID"
		or IsInGroup and IsInGroup() and "PARTY"
		or nil
	if channel and IsInGroup and LE_PARTY_CATEGORY_INSTANCE
		and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
		and not (LE_PARTY_CATEGORY_HOME
			and IsInGroup(LE_PARTY_CATEGORY_HOME))
	then
		channel = "INSTANCE_CHAT"
	end
	return channel
end

local function getGroupSignature(channel)
	if not channel then
		return nil
	end
	local units = collectGroupUnits()
	local members = {}
	for _, unit in ipairs(units) do
		members[#members + 1] = getUnitIdentity(unit)
	end
	table.sort(members)
	return table.concat({
		channel,
		tostring(#units),
		table.concat(members, "\030"),
	}, "\031")
end

local function registrationSucceeded(ok, result)
	if not ok then
		return false
	end
	local results = Enum and Enum.RegisterAddonMessagePrefixResult
	return result == nil
		or result == true
		or results and (
			result == results.Success
			or result == results.DuplicatePrefix)
		or not results and (result == 0 or result == 1)
end

local function classifySendResult(result)
	local results = Enum and Enum.SendAddonMessageResult
	local success = results and results.Success or 0
	if result == nil or result == true or result == success then
		return "success"
	end
	if results and (
		result == results.AddonMessageThrottle
		or result == results.ChannelThrottle
		or result == results.AddOnMessageLockdown)
	then
		return "retry"
	end
	return "failed"
end

local function finishRecord(record, status, reason)
	if type(record) ~= "table" or type(record.onFinish) ~= "function" then
		return
	end
	pcall(record.onFinish, status, reason, record)
end

function Transport:DiscardQueued(predicate, reason)
	local queue = self.queue or {}
	for index = #queue, 1, -1 do
		local record = queue[index]
		if not predicate or predicate(record) then
			table.remove(queue, index)
			finishRecord(record, "discarded", reason or "cleared")
		end
	end
end

local function notifyContextChanged(
	protocol, channel, signature, generation, reason)
	if type(protocol and protocol.onContextChanged) ~= "function" then
		return
	end
	local ok, err = pcall(
		protocol.onContextChanged,
		channel,
		signature,
		generation,
		reason)
	if not ok and geterrorhandler then
		local handler = geterrorhandler()
		if type(handler) == "function" then
			pcall(handler, err)
		end
	end
end

function Transport:RefreshProtocolContext(protocol, reason)
	if type(protocol) ~= "table" then
		return nil, nil, 0, false
	end
	local channel = getGroupChannel(protocol.channelPolicy)
	local signature = getGroupSignature(channel)
	local changed = not protocol.groupContextInitialized
		or channel ~= protocol.groupChannel
		or signature ~= protocol.groupSignature
	protocol.groupContextInitialized = true
	if changed then
		protocol.groupGeneration =
			(tonumber(protocol.groupGeneration) or 0) + 1
		protocol.groupChannel = channel
		protocol.groupSignature = signature
		self:DiscardQueued(function(record)
			return record.protocol == protocol
		end, reason or "group-context-changed")
		notifyContextChanged(
			protocol,
			channel,
			signature,
			protocol.groupGeneration,
			reason or "group-context-changed")
	else
		protocol.groupChannel = channel
		protocol.groupSignature = signature
	end
	return channel, signature, protocol.groupGeneration, changed
end

function Transport:RefreshAllGroupContexts(reason)
	for _, protocol in pairs(self.protocols or {}) do
		self:RefreshProtocolContext(protocol, reason)
	end
end

function Transport:SchedulePump(delay)
	if self.sendTimer then
		return
	end
	local function run()
		self.sendTimer = nil
		self:Pump()
	end
	delay = math.max(0, tonumber(delay) or 0)
	if C_Timer and C_Timer.NewTimer then
		self.sendTimer = C_Timer.NewTimer(delay, run)
	elseif C_Timer and C_Timer.After then
		self.sendTimer = true
		C_Timer.After(delay, run)
	else
		run()
	end
end

function Transport:Pump()
	self:RefreshAllGroupContexts("send")
	local queue = self.queue or {}
	local record = queue[1]
	if not record then
		return
	end
	local protocol = record.protocol
	local channel = protocol and protocol.groupChannel
	local signature = protocol and protocol.groupSignature
	local generation = protocol and protocol.groupGeneration
	if not channel
		or record.groupGeneration ~= generation
		or record.groupChannel ~= channel
		or record.groupSignature ~= signature
	then
		table.remove(queue, 1)
		finishRecord(record, "discarded", "group-context-changed")
		self:SchedulePump(0)
		return
	end
	if now() - (tonumber(record.queuedAt) or 0)
		> (tonumber(record.maxAge) or DEFAULT_MAX_SEND_AGE)
	then
		table.remove(queue, 1)
		finishRecord(record, "discarded", "expired")
		self:SchedulePump(0)
		return
	end
	if not (record.protocol and record.protocol.registered
		and C_ChatInfo and C_ChatInfo.SendAddonMessage)
	then
		table.remove(queue, 1)
		finishRecord(record, "failed", "unavailable")
		self:SchedulePump(0)
		return
	end
	local ok, result = pcall(
		C_ChatInfo.SendAddonMessage,
		record.protocol.prefix,
		record.message,
		record.groupChannel)
	local status = ok and classifySendResult(result) or "failed"
	if status == "retry" then
		self:SchedulePump(record.retryDelay)
		return
	end
	if queue[1] == record then
		table.remove(queue, 1)
	end
	finishRecord(record, status, status)
	self:SchedulePump(record.sendInterval)
end

function Transport:EnsureEventFrame()
	if self.eventFrame or not CreateFrame then
		return
	end
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
	self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.eventFrame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then
			local prefix, text, distribution, sender = ...
			local protocol = self.protocols
				and self.protocols[prefix] or nil
			if protocol and protocol.registered
				and type(protocol.handler) == "function"
			then
				protocol.handler(
					prefix, text, distribution, sender, select(5, ...))
			end
			return
		end
		self:RefreshAllGroupContexts(event)
	end)
end

function Transport:RegisterProtocol(prefix, handler, options)
	if type(prefix) ~= "string" or prefix == "" or #prefix > 16 then
		return nil
	end
	options = type(options) == "table" and options or {}
	self.protocols = self.protocols or {}
	local protocol = self.protocols[prefix]
	if not protocol then
		protocol = {
			prefix = prefix,
		}
		self.protocols[prefix] = protocol
	end
	if type(handler) == "function" then
		protocol.handler = handler
	end
	if type(options.onContextChanged) == "function" then
		protocol.onContextChanged = options.onContextChanged
	end
	if options.channelPolicy == CHANNEL_POLICY.INSTANCE_FIRST
		or options.channelPolicy == CHANNEL_POLICY.RAID_FIRST
		or options.channelPolicy == CHANNEL_POLICY.PARTY_ONLY
		or options.channelPolicy == CHANNEL_POLICY.NATIVE
	then
		protocol.channelPolicy = options.channelPolicy
	else
		protocol.channelPolicy =
			protocol.channelPolicy or CHANNEL_POLICY.NATIVE
	end
	if not protocol.registered
		and C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
	then
		local ok, result = pcall(
			C_ChatInfo.RegisterAddonMessagePrefix, prefix)
		protocol.registered = registrationSucceeded(ok, result)
		protocol.registrationResult = result
	end
	self.queue = self.queue or {}
	self:EnsureEventFrame()
	self:RefreshProtocolContext(protocol, "register")
	return setmetatable({
		transport = self,
		protocol = protocol,
	}, Handle)
end

function Handle:IsRegistered()
	return self.protocol and self.protocol.registered == true
end

function Handle:GetGroupContext(reason)
	if not self.transport then
		return nil, nil, 0, false
	end
	return self.transport:RefreshProtocolContext(
		self.protocol, reason)
end

function Handle:QueueMessages(messages, options)
	options = type(options) == "table" and options or {}
	if not (self.transport and self.protocol
		and self.protocol.registered)
	then
		return false
	end
	if type(messages) == "string" then
		messages = { messages }
	end
	if type(messages) ~= "table" or #messages == 0 then
		return false
	end
	local maxBytes = math.min(
		MAX_NATIVE_MESSAGE_BYTES,
		math.max(1, tonumber(options.maxBytes)
			or MAX_NATIVE_MESSAGE_BYTES))
	for _, message in ipairs(messages) do
		if type(message) ~= "string" or message == ""
			or #message > maxBytes
		then
			return false
		end
	end
	local channel, signature, generation =
		self:GetGroupContext("queue")
	if not (channel and signature) then
		return false
	end
	local replaceKey = options.replaceKey
	if replaceKey ~= nil then
		replaceKey = tostring(replaceKey)
		self.transport:DiscardQueued(function(record)
			return record.protocol == self.protocol
				and record.replaceKey == replaceKey
		end, "replaced")
	end
	local queuedAt = now()
	for _, message in ipairs(messages) do
		self.transport.queueSequence =
			(tonumber(self.transport.queueSequence) or 0) + 1
		local priority = PRIORITY_RANK[options.priority]
			and options.priority or "normal"
		local record = {
			protocol = self.protocol,
			message = message,
			queuedAt = queuedAt,
			groupGeneration = generation,
			groupChannel = channel,
			groupSignature = signature,
			replaceKey = replaceKey,
			sendInterval = math.max(0,
				tonumber(options.sendInterval)
					or DEFAULT_SEND_INTERVAL),
			retryDelay = math.max(0,
				tonumber(options.retryDelay)
					or DEFAULT_RETRY_DELAY),
			maxAge = math.max(0,
				tonumber(options.maxAge)
					or DEFAULT_MAX_SEND_AGE),
			onFinish = options.onFinish,
			priority = priority,
			priorityRank = PRIORITY_RANK[priority],
			queueSequence = self.transport.queueSequence,
		}
		local insertAt = #self.transport.queue + 1
		for index, queued in ipairs(self.transport.queue) do
			if (tonumber(queued.priorityRank)
				or PRIORITY_RANK.normal) > record.priorityRank
			then
				insertAt = index
				break
			end
		end
		table.insert(self.transport.queue, insertAt, record)
	end
	self.transport:SchedulePump(0)
	return true
end

function Handle:ClearQueue(replaceKey, reason)
	if not (self.transport and self.protocol) then
		return
	end
	replaceKey = replaceKey ~= nil and tostring(replaceKey) or nil
	self.transport:DiscardQueued(function(record)
		return record.protocol == self.protocol
			and (replaceKey == nil or record.replaceKey == replaceKey)
	end, reason or "cleared")
end

function Handle:GetQueuedCount()
	if not (self.transport and self.protocol) then
		return 0
	end
	local count = 0
	for _, record in ipairs(self.transport.queue or {}) do
		if record.protocol == self.protocol then
			count = count + 1
		end
	end
	return count
end
