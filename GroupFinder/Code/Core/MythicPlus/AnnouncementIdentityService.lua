local _, GF = ...

GF.MythicPlusAnnouncementIdentity = GF.MythicPlusAnnouncementIdentity or {}
local Service = GF.MythicPlusAnnouncementIdentity
local PREFIX = "GFTA1"
local RECORD_TTL = 8
local MAX_RECORDS = 96
local MARKER_WAIT = 0.25

local function readable(value)
	if issecretvalue and issecretvalue(value) then return false end
	if canaccessvalue and not canaccessvalue(value) then return false end
	return value ~= nil
end

local function chatReadable()
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
		return ok and readable(locked) and locked == false
	end
	return true
end

local function now()
	return GetTime and GetTime() or 0
end

local function read(callback, ...)
	if type(callback) ~= "function" then return nil end
	local ok, value = pcall(callback, ...)
	return ok and readable(value) and value or nil
end

local function canonical(value)
	if not readable(value) or type(value) ~= "string" or #value > 160 then return nil end
	value = value:gsub("%s+", "")
	return value ~= "" and string.lower(value) or nil
end

local function unitName(unit)
	if not UnitFullName then return nil end
	local ok, name, realm = pcall(UnitFullName, unit)
	if not ok or not canonical(name) then return nil end
	if not readable(realm) or realm == "" then realm = read(GetRealmName) end
	if not canonical(realm) then return nil end
	return canonical(name .. "-" .. realm)
end

local function fingerprint(message)
	if not readable(message) or type(message) ~= "string"
		or #message == 0 or #message > 1024 then return nil end
	-- Chat may remove colors or expand a spell link's payload/display name.
	-- Match the spell identity while retaining the rest of the custom text.
	local text = message:gsub("|c%x%x%x%x%x%x%x%x", "")
		:gsub("|cn[%w_]+:", ""):gsub("|r", "")
		:gsub("|Hspell:(%d+)[^|]*|h.-|h", "<spell:%1>")
	local left, right = 5381, 52711
	for index = 1, #text do
		local byte = text:byte(index)
		left = (left * 33 + byte) % 2147483647
		right = (right * 127 + byte) % 2147483647
	end
	return string.format("%d:%08x:%08x", #text, left, right)
end

local function appendBounded(records, record)
	if #records >= MAX_RECORDS then table.remove(records, 1) end
	records[#records + 1] = record
end

function Service:ResetContext(channel, signature, generation)
	self.channel, self.signature, self.generation = channel, signature, generation
	self.markers, self.lines, self.tokens, self.members = {}, {}, {}, {}
	self.player = unitName("player")
	if not channel then return end
	local function add(unit)
		local name = unitName(unit)
		if name then self.members[name] = true end
	end
	if read(IsInRaid) then
		local count = tonumber(read(GetNumGroupMembers)) or 0
		for index = 1, math.min(40, count) do add("raid" .. index) end
	else
		add("player")
		local count = tonumber(read(GetNumSubgroupMembers)) or 0
		for index = 1, math.min(4, count) do add("party" .. index) end
	end
end

function Service:RefreshContext()
	if not self.transport then return nil end
	local ok, channel, signature, generation = pcall(
		self.transport.GetGroupContext, self.transport, "announcement-logo")
	if not ok then return nil end
	return channel, signature, generation
end

function Service:ResolveSender(sender)
	local key = canonical(sender)
	if not key then return nil end
	if not key:find("-", 1, true) then
		local realm = canonical(read(GetRealmName))
		if not realm then return nil end
		key = key .. "-" .. realm
	end
	return self.members and self.members[key] and key or nil
end

function Service:Prune()
	local current = now()
	for _, records in ipairs({ self.markers, self.lines, self.tokens }) do
		for index = #records, 1, -1 do
			if records[index].expiresAt <= current then table.remove(records, index) end
		end
	end
end

function Service:AddMarker(sender, digest, token)
	self:Prune()
	for _, seen in ipairs(self.tokens) do
		if seen.sender == sender and seen.token == token then return false end
	end
	appendBounded(self.tokens, { sender = sender, token = token, expiresAt = now() + RECORD_TTL })
	-- A marker arriving after plain chat must not brand the next identical line.
	for _, line in ipairs(self.lines) do
		if line.sender == sender and line.digest == digest and not line.branded then return false end
	end
	appendBounded(self.markers, {
		sender = sender, digest = digest, token = token, expiresAt = now() + RECORD_TTL,
	})
	return true
end

function Service:Receive(prefix, message, channel, sender)
	if not chatReadable() or not readable(prefix) or prefix ~= PREFIX
		or not readable(channel) or not readable(message)
		or type(message) ~= "string" or #message > 96 then return end
	local currentChannel = self:RefreshContext()
	if not currentChannel or channel ~= currentChannel then return end
	local author = self:ResolveSender(sender)
	if not author or author == self.player then return end
	local cancelled = message:match("^0|([%da-f]+%-[%da-f]+)$")
	if cancelled and #cancelled <= 32 then
		self:CancelMarker(author, cancelled)
		return
	end
	local token, digest = message:match("^1|([%da-f]+%-[%da-f]+)|(%d+:%x%x%x%x%x%x%x%x:%x%x%x%x%x%x%x%x)$")
	if not token or #token > 32 then return end
	self:AddMarker(author, digest, token)
end

function Service:CancelMarker(sender, token)
	self:Prune()
	for index = #self.markers, 1, -1 do
		local marker = self.markers[index]
		if marker.sender == sender and marker.token == token then table.remove(self.markers, index) end
	end
	for _, seen in ipairs(self.tokens) do
		if seen.sender == sender and seen.token == token then return end
	end
	-- A cancellation can precede its marker; keep a bounded replay tombstone.
	appendBounded(self.tokens, { sender = sender, token = token, expiresAt = now() + RECORD_TTL })
end

function Service:MatchMessage(message, sender, channel, lineID)
	if not chatReadable() or not self.channel or channel ~= self.channel
		or not readable(lineID) or type(lineID) ~= "number" or lineID <= 0 then return false end
	local author = self:ResolveSender(sender)
	local digest = author and fingerprint(message)
	if not digest then return false end
	self:Prune()
	for _, line in ipairs(self.lines) do
		if line.sender == author and line.lineID == lineID then
			return line.branded and line.digest == digest
		end
	end
	local branded = false
	for index, marker in ipairs(self.markers) do
		if marker.sender == author and marker.digest == digest then
			table.remove(self.markers, index)
			branded = true
			break
		end
	end
	-- Keep the verdict per Blizzard lineID so all chat windows see the same line
	-- without consuming another marker or decorating a later duplicate message.
	appendBounded(self.lines, {
		sender = author, digest = digest, lineID = lineID,
		branded = branded, expiresAt = now() + RECORD_TTL,
	})
	return branded
end

function Service:CreateDelivery(channel)
	local currentChannel, signature, generation = self:RefreshContext()
	if not currentChannel or currentChannel ~= channel or not signature then return nil end
	return { channel = channel, signature = signature, generation = generation, createdAt = now() }
end

function Service:BeforeSend(delivery, message, wake)
	local channel, signature, generation = self:RefreshContext()
	if channel ~= delivery.channel or signature ~= delivery.signature
		or generation ~= delivery.generation or now() - delivery.createdAt > 30 then return "drop" end
	if delivery.state == "waiting" then return "wait" end
	if delivery.state == "ready" then return "send" end
	delivery.digest = fingerprint(message)
	self.sequence = (self.sequence or 0) + 1
	delivery.token = string.format("%x-%x", math.floor(now() * 1000), self.sequence)
	delivery.state = "ready"
	if not delivery.digest or not self.transport:IsRegistered()
		or not (C_Timer and C_Timer.NewTimer) then return "send" end
	delivery.state = "waiting"
	local function finish(status)
		if delivery.state ~= "waiting" then return end
		delivery.state = "ready"
		delivery.markerSubmitted = status == "success"
		if delivery.timer then delivery.timer:Cancel(); delivery.timer = nil end
		-- A throttled/late marker is optional; never stall or duplicate party chat.
		self.transport:ClearQueue(delivery.token, "announcement-ready")
		wake()
	end
	local ok, timer = pcall(C_Timer.NewTimer, MARKER_WAIT, finish)
	if not ok or not timer then delivery.state = "ready"; return "send" end
	delivery.timer = timer
	local queued = self.transport:QueueMessages({ "1|" .. delivery.token .. "|" .. delivery.digest }, {
		priority = "urgent", maxAge = MARKER_WAIT, replaceKey = delivery.token, onFinish = finish,
	})
	if not queued then finish() end
	return delivery.state == "waiting" and "wait" or "send"
end

function Service:BeforeSubmit(delivery)
	if delivery.digest and self.player then
		self:AddMarker(self.player, delivery.digest, delivery.token)
	end
end

function Service:AfterSubmit(delivery, submitted)
	if submitted then return end
	self:CancelMarker(self.player, delivery.token)
	if delivery.markerSubmitted then
		self.transport:QueueMessages({ "0|" .. delivery.token }, {
			priority = "urgent", maxAge = RECORD_TTL,
		})
	end
end

function Service:Init()
	if self.transport or not GF.AddonMessageTransport then return end
	self:ResetContext(nil, nil, 0)
	self.transport = GF.AddonMessageTransport:RegisterProtocol(PREFIX,
		function(...) self:Receive(...) end, {
			channelPolicy = "raid-first", -- Same selection as AnnouncementService.
			onContextChanged = function(channel, signature, generation)
				self:ResetContext(channel, signature, generation)
			end,
		})
end
