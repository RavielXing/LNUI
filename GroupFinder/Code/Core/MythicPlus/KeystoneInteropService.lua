local _, GF = ...

GF.MythicPlusKeystoneInteropService =
	GF.MythicPlusKeystoneInteropService or {}
local Service = GF.MythicPlusKeystoneInteropService
local Util = GF.MythicPlusServiceUtil
local Transport = GF.AddonMessageTransport

local LIBKEYSTONE_PREFIX = "LibKS"
local MAX_RECORD_AGE = 15 * 60
local RENEW_INTERVAL = 5 * 60
local REQUEST_COOLDOWN = 5
local MAX_KEY_LEVEL = 1000
local MAX_CHALLENGE_MODE_ID = 100000
local MAX_RATING = 100000

local SOURCE_DEFS = {
	libkeystone = {
		priority = 1,
		label = "LibKeystone",
		acceptRating = true,
	},
	libopenraid = {
		priority = 2,
		label = "LibOpenRaid",
	},
	libopenkeystone = {
		priority = 3,
		label = "LibOpenKeystone",
	},
}

local function isSecret(value)
	return issecretvalue and issecretvalue(value) == true
end

local function canonical(value)
	if isSecret(value) or type(value) ~= "string" then
		return nil
	end
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("%s+", "")
	return value ~= "" and string.lower(value) or nil
end

local function shortCanonical(value)
	local normalized = canonical(value)
	return normalized and normalized:match("^([^-]+)") or nil
end

local function collectGroupMembers()
	local members = {}
	if not (IsInGroup and IsInGroup()) then
		return members
	end
	local units = {}
	if IsInRaid and IsInRaid() then
		for index = 1, math.min(
			40, tonumber(GetNumGroupMembers and GetNumGroupMembers()) or 0)
		do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		for index = 1, math.min(
			4, tonumber(GetNumSubgroupMembers
				and GetNumSubgroupMembers()) or 0)
		do
			units[#units + 1] = "party" .. index
		end
	end
	for _, unit in ipairs(units) do
		local fullName, name = Util.GetUnitFullName(unit)
		local fullKey = canonical(fullName)
		local shortKey = shortCanonical(name or fullName)
		if fullKey and shortKey then
			local isCurrent = unit == "player"
			if not isCurrent and UnitIsUnit then
				local ok, matches = pcall(UnitIsUnit, unit, "player")
				isCurrent = ok and matches == true
			end
			members[#members + 1] = {
				unit = unit,
				fullName = fullName,
				fullKey = fullKey,
				shortKey = shortKey,
				isCurrent = isCurrent,
			}
		end
	end
	return members
end

local function resolveCurrentGroupMember(identifier)
	local identifierKey = canonical(identifier)
	if not identifierKey then
		return nil
	end
	local members = collectGroupMembers()
	if identifierKey:find("-", 1, true) then
		for _, member in ipairs(members) do
			if member.fullKey == identifierKey then
				return not member.isCurrent and member or nil
			end
		end
		return nil
	end
	local match
	for _, member in ipairs(members) do
		if member.shortKey == identifierKey then
			if match then
				-- A realm-less sender is unsafe when two current members have
				-- the same short name.
				return nil
			end
			match = member
		end
	end
	return match and not match.isCurrent and match or nil
end

local function normalizeInteger(value, minimum, maximum)
	if isSecret(value) then
		return nil
	end
	value = tonumber(value)
	if not value or value ~= value
		or value == math.huge or value == -math.huge
	then
		return nil
	end
	value = math.floor(value + 0.5)
	if minimum and value < minimum
		or maximum and value > maximum
	then
		return nil
	end
	return value
end

local function getSelectedSource(entry)
	local selectedID
	local selected
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	for sourceID, record in pairs(entry and entry.sources or {}) do
		local definition = SOURCE_DEFS[sourceID]
		if definition
			and Util.Now() - (tonumber(record.receivedAt) or 0)
				<= MAX_RECORD_AGE
			and (resetAt <= 0
				or (tonumber(record.receivedAt) or 0) >= resetAt)
			and (not selected
				or definition.priority
					< SOURCE_DEFS[selectedID].priority)
		then
			selectedID = sourceID
			selected = record
		end
	end
	return selectedID, selected
end

local function effectiveFingerprint(entry)
	local sourceID, record = getSelectedSource(entry)
	if not (sourceID and record) then
		return ""
	end
	return table.concat({
		sourceID,
		tostring(record.challengeModeID or ""),
		tostring(record.keyLevel or ""),
		tostring(record.rating or ""),
	}, "\031")
end

function Service:AddListener(callback)
	Util.AddListener(self, callback)
end

function Service:NotifyChanged(reason)
	Util.Notify(self, reason or "keystone-interop")
	if GF.MythicPlusRosterCache
		and GF.MythicPlusRosterCache.RequestRefresh
	then
		GF.MythicPlusRosterCache:RequestRefresh(
			reason or "keystone-interop")
	end
end

function Service:AcceptRecord(
	sourceID, identifier, challengeModeID, keyLevel, rating, reason)
	local definition = SOURCE_DEFS[sourceID]
	local member = definition and resolveCurrentGroupMember(identifier)
	if not member then
		return false
	end
	challengeModeID = normalizeInteger(
		challengeModeID, 1, MAX_CHALLENGE_MODE_ID)
	keyLevel = normalizeInteger(keyLevel, 1, MAX_KEY_LEVEL)
	if definition.acceptRating then
		rating = normalizeInteger(rating, 0, MAX_RATING)
	else
		rating = nil
	end

	self.records = self.records or {}
	local entry = self.records[member.fullKey]
	if not entry then
		entry = {
			fullName = member.fullName,
			sources = {},
		}
		self.records[member.fullKey] = entry
	end
	local before = effectiveFingerprint(entry)
	if challengeModeID and keyLevel then
		entry.fullName = member.fullName
		entry.sources[sourceID] = {
			challengeModeID = challengeModeID,
			keyLevel = keyLevel,
			rating = rating,
			receivedAt = Util.Now(),
		}
	else
		-- External 0/0 means only that this source withdrew its fallback.
		-- It is not authoritative evidence that the player has no keystone.
		entry.sources[sourceID] = nil
	end
	if not next(entry.sources) then
		self.records[member.fullKey] = nil
	end
	local after = effectiveFingerprint(self.records[member.fullKey])
	if before ~= after then
		self:NotifyChanged(reason or sourceID)
	end
	self:ScheduleExpiry()
	return challengeModeID ~= nil and keyLevel ~= nil
end

function Service:GetForMember(fullName)
	local key = canonical(fullName)
	local entry = key and self.records and self.records[key] or nil
	local sourceID, record = getSelectedSource(entry)
	if not (sourceID and record) then
		return nil
	end
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	if resetAt > 0
		and (tonumber(record.receivedAt) or 0) < resetAt
	then
		return nil
	end
	local dungeon = GF.MythicPlusSeason
		and GF.MythicPlusSeason.GetByChallengeModeID
		and GF.MythicPlusSeason:GetByChallengeModeID(
			record.challengeModeID)
		or nil
	return {
		keyState = "ready",
		challengeModeID = record.challengeModeID,
		mapID = record.challengeModeID,
		keyLevel = record.keyLevel,
		rating = record.rating,
		dungeonName = dungeon and dungeon.name or nil,
		activityID = dungeon and dungeon.activityID or nil,
		groupID = dungeon and dungeon.groupID or nil,
		keyObservedAt = record.receivedAt,
		receivedAt = record.receivedAt,
		keystoneLink = nil,
		keystoneReadOnly = true,
		isInteropFallback = true,
		isRosterOnly = true,
		interopSource = sourceID,
		interopLabel = SOURCE_DEFS[sourceID].label,
		source = sourceID,
	}
end

function Service:Clear(reason)
	if not (self.records and next(self.records)) then
		self.records = {}
		self:ScheduleExpiry()
		return false
	end
	self.records = {}
	self:ScheduleExpiry()
	self:NotifyChanged(reason or "keystone-interop-clear")
	return true
end

function Service:Prune(reason)
	local members = {}
	for _, member in ipairs(collectGroupMembers()) do
		if not member.isCurrent then
			members[member.fullKey] = true
		end
	end
	local changed = false
	local currentTime = Util.Now()
	for memberKey, entry in pairs(self.records or {}) do
		if not members[memberKey] then
			self.records[memberKey] = nil
			changed = true
		else
			local before = effectiveFingerprint(entry)
			local removedSource = false
			for sourceID, record in pairs(entry.sources or {}) do
				if currentTime - (tonumber(record.receivedAt) or 0)
					> MAX_RECORD_AGE
				then
					entry.sources[sourceID] = nil
					removedSource = true
				end
			end
			if not next(entry.sources) then
				self.records[memberKey] = nil
			end
			if removedSource
				or before ~= effectiveFingerprint(self.records[memberKey])
			then
				changed = true
			end
		end
	end
	if changed then
		self:NotifyChanged(reason or "keystone-interop-prune")
	end
	self:ScheduleExpiry()
	return changed
end

function Service:ScheduleExpiry()
	if self.expiryTimer and self.expiryTimer.Cancel then
		self.expiryTimer:Cancel()
	end
	self.expiryTimer = nil
	if not (C_Timer and C_Timer.NewTimer) then
		return
	end
	local nextDelay
	local currentTime = Util.Now()
	for _, entry in pairs(self.records or {}) do
		for _, record in pairs(entry.sources or {}) do
			local delay = MAX_RECORD_AGE
				- (currentTime - (tonumber(record.receivedAt) or 0))
			if delay > 0 and (not nextDelay or delay < nextDelay) then
				nextDelay = delay
			end
		end
	end
	if nextDelay then
		self.expiryTimer = C_Timer.NewTimer(nextDelay + 0.1, function()
			Service.expiryTimer = nil
			Service:Prune("keystone-interop-expired")
		end)
	end
end

local function getLoadedLibrary(name)
	local libStub = _G and _G.LibStub
	if type(libStub) ~= "table"
		or type(libStub.GetLibrary) ~= "function"
	then
		return nil
	end
	local ok, library = pcall(libStub.GetLibrary, libStub, name, true)
	return ok and type(library) == "table" and library or nil
end

local function getOpenRaidChallengeModeID(info)
	return type(info) == "table" and (
		info.challengeMapID
		or info.challengeModeID
		or info.mapChallengeModeID)
		or nil
end

local function getOpenKeystoneChallengeModeID(info)
	return type(info) == "table" and (
		info.challengeMapID
		or info.challengeModeID
		or info.mapChallengeModeID
		or info.mapID)
		or nil
end

function Service.OnLibOpenRaidKeystoneUpdate(unitName, info)
	Service:AcceptRecord(
		"libopenraid",
		unitName,
		getOpenRaidChallengeModeID(info),
		info and info.level,
		nil,
		"libopenraid")
end

local function onLibOpenKeystoneUpdate(_, unitName, info)
	Service:AcceptRecord(
		"libopenkeystone",
		unitName,
		getOpenKeystoneChallengeModeID(info),
		info and info.level,
		nil,
		"libopenkeystone")
end

function Service:TryAttachLibraries()
	local attached = false
	local openRaid = getLoadedLibrary("LibOpenRaid-1.0")
	if openRaid and self.openRaidLibrary ~= openRaid
		and type(openRaid.RegisterCallback) == "function"
	then
		local ok, result = pcall(
			openRaid.RegisterCallback,
			self,
			"KeystoneUpdate",
			"OnLibOpenRaidKeystoneUpdate")
		if ok and result == true then
			self.openRaidLibrary = openRaid
			attached = true
		end
	end

	local openKeystone = getLoadedLibrary("LibOpenKeystone-1.0")
	if openKeystone and self.openKeystoneLibrary ~= openKeystone then
		if type(openKeystone.SetEnabled) == "function" then
			pcall(openKeystone.SetEnabled, true)
		end
		if type(openKeystone.RegisterCallback) == "function" then
			local ok, result = pcall(
				openKeystone.RegisterCallback,
				self,
				"KeystoneUpdate",
				onLibOpenKeystoneUpdate)
			if ok and result == true then
				self.openKeystoneLibrary = openKeystone
				attached = true
			end
		end
	end
	return attached
end

local function isUnsafeToRequest()
	if InCombatLockdown and InCombatLockdown() then
		return true
	end
	if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
		local ok, active = pcall(
			C_ChallengeMode.IsChallengeModeActive)
		if ok and active == true then
			return true
		end
	end
	return false
end

local function getCurrentRating()
	local rating = GF.MythicPlusRatingCache
		and GF.MythicPlusRatingCache.GetCurrent
		and GF.MythicPlusRatingCache:GetCurrent()
	local score = normalizeInteger(
		rating and rating.score, 0, MAX_RATING)
	return score or 0
end

function Service:BuildOwnLibKeystonePayload()
	local snapshot = GF.MythicPlusKeystoneCache
		and GF.MythicPlusKeystoneCache.GetSnapshot
		and GF.MythicPlusKeystoneCache:GetSnapshot()
	if not snapshot or snapshot.state == "pending" then
		return nil
	end
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
	if resetAt > 0
		and (tonumber(snapshot.updatedAt) or 0) < resetAt
	then
		return nil
	end
	local level = snapshot.state == "ready"
		and normalizeInteger(snapshot.level, 1, MAX_KEY_LEVEL)
		or 0
	local challengeModeID = snapshot.state == "ready"
		and normalizeInteger(
			snapshot.challengeModeID, 1, MAX_CHALLENGE_MODE_ID)
		or 0
	if snapshot.state == "ready"
		and not (level and challengeModeID)
	then
		return nil
	end
	return string.format(
		"%d,%d,%d",
		level or 0,
		challengeModeID or 0,
		getCurrentRating())
end

function Service:QueueOwnLibKeystone()
	local payload = self:BuildOwnLibKeystonePayload()
	if not (payload and self.libKeystoneTransport) then
		local shouldRefresh =
			self.pendingOwnLibKeystoneResponse ~= true
		self.pendingOwnLibKeystoneResponse = true
		if shouldRefresh
			and GF.MythicPlusKeystoneCache
			and GF.MythicPlusKeystoneCache.RequestRefresh
		then
			GF.MythicPlusKeystoneCache:RequestRefresh(
				"libkeystone-peer-request")
		end
		return false
	end
	self.pendingOwnLibKeystoneResponse = nil
	if self.pendingOwnLibKeystoneResponseTimer
		and self.pendingOwnLibKeystoneResponseTimer.Cancel
	then
		self.pendingOwnLibKeystoneResponseTimer:Cancel()
	end
	self.pendingOwnLibKeystoneResponseTimer = nil
	return self.libKeystoneTransport:QueueMessages(payload, {
		replaceKey = "libkeystone-response",
		priority = "normal",
		maxAge = 10,
	})
end

function Service:RequestOwnLibKeystoneResponse()
	if self.pendingOwnLibKeystoneResponse == true then
		return false
	end
	self.pendingOwnLibKeystoneResponse = true
	if C_Timer and C_Timer.NewTimer then
		if self.pendingOwnLibKeystoneResponseTimer
			and self.pendingOwnLibKeystoneResponseTimer.Cancel
		then
			self.pendingOwnLibKeystoneResponseTimer:Cancel()
		end
		self.pendingOwnLibKeystoneResponseTimer =
			C_Timer.NewTimer(10, function()
				Service.pendingOwnLibKeystoneResponseTimer = nil
				Service.pendingOwnLibKeystoneResponse = nil
			end)
	end
	if GF.MythicPlusKeystoneCache
		and GF.MythicPlusKeystoneCache.RequestRefresh
	then
		GF.MythicPlusKeystoneCache:RequestRefresh(
			"libkeystone-peer-request")
		return true
	end
	return self:QueueOwnLibKeystone()
end

function Service:ReceiveLibKeystone(
	_, text, distribution, sender)
	if distribution ~= "PARTY"
		or IsInRaid and IsInRaid()
		or isSecret(text)
		or type(text) ~= "string"
		or #text > 64
	then
		return
	end
	local member = resolveCurrentGroupMember(sender)
	if not member then
		return
	end
	if text == "R" then
		self:RequestOwnLibKeystoneResponse()
		return
	end
	local level, challengeModeID, rating =
		text:match("^(%d+),(%d+),(%d+)$")
	if not level then
		return
	end
	self:AcceptRecord(
		"libkeystone",
		member.fullName,
		challengeModeID,
		level,
		rating,
		"libkeystone")
	self:ScheduleExpiry()
end

function Service:ScheduleRenewal()
	if self.renewTimer and self.renewTimer.Cancel then
		self.renewTimer:Cancel()
	end
	self.renewTimer = nil
	if not (IsInGroup and IsInGroup()
		and C_Timer and C_Timer.NewTimer)
	then
		return
	end
	self.renewTimer = C_Timer.NewTimer(RENEW_INTERVAL, function()
		Service.renewTimer = nil
		Service:RequestSync("keystone-interop-renew")
	end)
end

function Service:RequestSync(reason)
	self:TryAttachLibraries()
	self:Prune(reason)
	if not (IsInGroup and IsInGroup()) then
		self.pendingRequest = nil
		self:ScheduleRenewal()
		return false
	end
	if isUnsafeToRequest() then
		self.pendingRequest = reason or true
		self:ScheduleRenewal()
		return false
	end
	local currentTime = GetTime and GetTime() or 0
	if currentTime - (tonumber(self.lastRequestAt)
		or -REQUEST_COOLDOWN) < REQUEST_COOLDOWN
	then
		self:ScheduleRenewal()
		return false
	end
	self.pendingRequest = nil
	self.lastRequestAt = currentTime
	local requested = false
	if self.libKeystoneTransport
		and not (IsInRaid and IsInRaid())
	then
		requested = self.libKeystoneTransport:QueueMessages("R", {
			replaceKey = "libkeystone-request",
			priority = "normal",
			maxAge = 10,
		}) or requested
	end
	local openRaid = self.openRaidLibrary
	if openRaid then
		local method = IsInRaid and IsInRaid()
			and openRaid.RequestKeystoneDataFromRaid
			or openRaid.RequestKeystoneDataFromParty
		if type(method) == "function" then
			local ok, result = pcall(method)
			requested = ok and result ~= false or requested
		end
	end
	local openKeystone = self.openKeystoneLibrary
	if openKeystone
		and type(openKeystone.RequestKeystoneDataFromParty) == "function"
	then
		local ok, result = pcall(
			openKeystone.RequestKeystoneDataFromParty)
		requested = ok and result ~= false or requested
	end
	self:ScheduleRenewal()
	return requested
end

function Service:OnSafeToRequest(reason)
	if self.pendingRequest and not isUnsafeToRequest() then
		self.lastRequestAt = nil
		return self:RequestSync(reason or "keystone-interop-resume")
	end
	return false
end

function Service:OnRosterChanged(reason, _, isConnected)
	-- Protocols do not carry a group generation. Reset on every roster
	-- membership transition so delayed data from the previous party cannot
	-- survive. Role, leader, and connection-only events keep valid leases.
	if reason == "GROUP_ROSTER_UPDATE" then
		self:Clear(reason)
		self.lastRequestAt = nil
		self.pendingRequest = reason
		return self:RequestSync(reason)
	else
		self:Prune(reason)
	end
	if reason == "UNIT_CONNECTION" and isConnected == true then
		self.lastRequestAt = nil
		self.pendingRequest = reason
		return self:RequestSync(reason)
	end
	return false
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.records = {}
	if Transport and Transport.RegisterProtocol then
		self.libKeystoneTransport = Transport:RegisterProtocol(
			LIBKEYSTONE_PREFIX,
			function(...)
				Service:ReceiveLibKeystone(...)
			end,
			{
				channelPolicy = Transport.CHANNEL_POLICY.PARTY_ONLY,
			})
	end
	if GF.MythicPlusKeystoneCache
		and GF.MythicPlusKeystoneCache.AddListener
	then
		GF.MythicPlusKeystoneCache:AddListener(function()
			if Service.pendingOwnLibKeystoneResponse then
				Service:QueueOwnLibKeystone()
			end
		end)
	end
	self:TryAttachLibraries()
end
