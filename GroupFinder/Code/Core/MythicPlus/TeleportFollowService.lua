local _, GF = ...

GF.MythicPlusTeleportFollowService =
	GF.MythicPlusTeleportFollowService or {}
local Service = GF.MythicPlusTeleportFollowService
local Util = GF.MythicPlusServiceUtil
local Transport = GF.AddonMessageTransport

local PREFIX = "GFTP1"
local VERSION = "1"
local MAX_MESSAGE_BYTES = 220
local OUTGOING_DEDUPE_SECONDS = 8
local INCOMING_SUPPRESS_SECONDS = 60
local PROMPT_ACTIVE_SECONDS = 45
local LOCAL_CAST_ACTIVE_SECONDS = 20
local PEER_FALLBACK_DELAY_SECONDS = 1.25
local PEER_COMM_SUPPRESS_SECONDS = 4

local PEER_SPELLCAST_EVENTS = {
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_FAILED_QUIET",
}

local CANCEL_EVENTS = {
	UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_FAILED_QUIET = true,
}

Service.PREFIX = PREFIX
Service.VERSION = VERSION

local Unpack = unpack or table.unpack

local function getTime()
	return GetTime and GetTime() or 0
end

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return not ok or secret == true
end

local function safeString(value, maxBytes)
	if value == nil or isSecret(value)
		or (type(value) ~= "string" and type(value) ~= "number")
	then
		return nil
	end
	local ok, text = pcall(tostring, value)
	if not ok or type(text) ~= "string" or text == ""
		or isSecret(text) or #text > (maxBytes or 120)
	then
		return nil
	end
	return text
end

local function safeNumber(value, minimum, maximum)
	if value == nil or isSecret(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or type(number) ~= "number" or isSecret(number)
		or number ~= math.floor(number)
	then
		return nil
	end
	if minimum and number < minimum then
		return nil
	end
	if maximum and number > maximum then
		return nil
	end
	return number
end

local function normalizeCastGUID(value)
	local text = safeString(value, 96)
	if not text or text:find("[%c|]")
		or not text:match("^[%w%-%._:]+$")
	then
		return nil
	end
	return text
end

local function canonical(value)
	value = safeString(value, 160)
	if not value then
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

local function senderMatchesUnit(sender, fullName, shortName)
	local senderKey = canonical(sender)
	if not senderKey then
		return false
	end
	if senderKey:find("-", 1, true) then
		return senderKey == canonical(fullName)
	end
	return senderKey == shortCanonical(fullName)
		or senderKey == canonical(shortName)
end

local function collectGroupUnits(includePlayer)
	local units = {}
	if IsInRaid and IsInRaid() then
		local count = GetNumGroupMembers and GetNumGroupMembers() or 0
		for index = 1, math.min(40, tonumber(count) or 0) do
			local unit = "raid" .. index
			if UnitExists and UnitExists(unit) then
				local isPlayer = false
				if UnitIsUnit then
					local ok, result = pcall(UnitIsUnit, unit, "player")
					isPlayer = ok and result == true
				end
				if includePlayer or not isPlayer then
					units[#units + 1] = unit
				end
			end
		end
		return units
	end

	if includePlayer and UnitExists and UnitExists("player") then
		units[#units + 1] = "player"
	end
	if IsInGroup and IsInGroup() then
		local count = GetNumSubgroupMembers
			and GetNumSubgroupMembers() or 4
		for index = 1, math.min(4, tonumber(count) or 0) do
			local unit = "party" .. index
			if UnitExists and UnitExists(unit) then
				units[#units + 1] = unit
			end
		end
	end
	return units
end

local function getUnitClass(unit)
	if not (unit and UnitClass) then
		return nil
	end
	local ok, _, classFile = pcall(UnitClass, unit)
	return ok and safeString(classFile, 24) or nil
end

local function resolveGroupSender(sender)
	if not canonical(sender) then
		return nil
	end
	for _, unit in ipairs(collectGroupUnits(true)) do
		local fullName, name
		if Util and Util.GetUnitFullName then
			fullName, name = Util.GetUnitFullName(unit)
		end
		if senderMatchesUnit(sender, fullName, name) then
			return {
				unit = unit,
				fullName = fullName or name,
				name = name or fullName,
				classFile = getUnitClass(unit),
			}
		end
	end
	return nil
end

local function isSelfSender(sender)
	local fullName, name
	if Util and Util.GetUnitFullName then
		fullName, name = Util.GetUnitFullName("player")
	end
	return senderMatchesUnit(sender, fullName, name)
end

local function encodeField(value)
	value = safeString(value, 96) or ""
	return value
		:gsub("%%", "%%25")
		:gsub("|", "%%7C")
		:gsub("\r", "%%0D")
		:gsub("\n", "%%0A")
		:gsub("%z", "")
end

local function decodeField(value)
	value = safeString(value, 288)
	if not value then
		return nil
	end
	local decoded = value:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
	return safeString(decoded, 96)
end

local function splitMessage(value)
	local parts = {}
	for part in (tostring(value or "") .. "|"):gmatch("(.-)|") do
		parts[#parts + 1] = part
	end
	return parts
end

local function makeCastKey(castGUID, spellID)
	castGUID = normalizeCastGUID(castGUID)
	return castGUID and ("cast:" .. castGUID)
		or ("spell:" .. tostring(spellID or "unknown"))
end

local function makeFallbackKeys(senderName, challengeModeID, castGUID)
	local keys = {}
	castGUID = normalizeCastGUID(castGUID)
	if castGUID then
		keys[#keys + 1] = "cast:" .. castGUID
	end
	local senderKey = canonical(senderName)
	if senderKey and challengeModeID then
		keys[#keys + 1] = "sender:" .. senderKey
			.. ":" .. tostring(challengeModeID)
	end
	return keys
end

local function storeRecord(records, record)
	if type(records) ~= "table" or type(record) ~= "table" then
		return
	end
	for _, key in ipairs(record.keys or {}) do
		records[key] = record
	end
end

local function clearRecord(records, record)
	if type(records) ~= "table" or type(record) ~= "table" then
		return
	end
	for _, key in ipairs(record.keys or {}) do
		if records[key] == record then
			records[key] = nil
		end
	end
end

local function findRecord(records, keys)
	if type(records) ~= "table" then
		return nil
	end
	local currentTime = getTime()
	for _, key in ipairs(keys or {}) do
		local record = records[key]
		if record then
			if not record.expiresAt or record.expiresAt > currentTime then
				return record
			end
			clearRecord(records, record)
		end
	end
	return nil
end

local function resolveEventSpellID(unit, spellID)
	local teleport = GF.MythicPlusTeleportService
	if teleport and teleport.NormalizeSpellID then
		local normalized = teleport:NormalizeSpellID(spellID)
		if normalized then
			return normalized
		end
	end
	if not (unit and UnitCastingInfo) then
		return nil
	end
	local ok, castingSpellID = pcall(function()
		local _, _, _, _, _, _, _, _, currentSpellID =
			UnitCastingInfo(unit)
		return currentSpellID
	end)
	if not ok then
		return nil
	end
	if teleport and teleport.NormalizeSpellID then
		return teleport:NormalizeSpellID(castingSpellID)
	end
	return safeNumber(castingSpellID, 1, 10000000)
end

local function getTeleportEntryBySpellID(spellID)
	local teleport = GF.MythicPlusTeleportService
	return teleport and teleport.GetBySpellID
		and teleport:GetBySpellID(spellID) or nil
end

local function buildFollowSnapshot(
	senderInfo, challengeModeID, castGUID, source, timeoutSeconds)
	local teleportService = GF.MythicPlusTeleportService
	local entry = teleportService
		and teleportService.GetByChallengeModeID
		and teleportService:GetByChallengeModeID(challengeModeID)
	if not (entry and entry.status == "ready"
		and type(entry.macroText) == "string"
		and entry.macroText ~= "")
	then
		return nil
	end
	local dungeon = GF.MythicPlusSeason
		and GF.MythicPlusSeason.GetByChallengeModeID
		and GF.MythicPlusSeason:GetByChallengeModeID(challengeModeID)
	if not dungeon then
		return nil
	end
	timeoutSeconds = math.max(1, math.min(
		PROMPT_ACTIVE_SECONDS,
		tonumber(timeoutSeconds) or PROMPT_ACTIVE_SECONDS))
	return {
		sender = senderInfo and senderInfo.fullName,
		senderName = senderInfo and senderInfo.fullName,
		senderClass = senderInfo and senderInfo.classFile,
		classFile = senderInfo and senderInfo.classFile,
		senderUnit = senderInfo and senderInfo.unit,
		challengeModeID = challengeModeID,
		mapID = dungeon.mapID,
		dungeon = dungeon,
		dungeonName = dungeon.name,
		spellID = entry.spellID,
		spellName = entry.spellName,
		spellLink = entry.spellLink,
		macroText = entry.macroText,
		status = entry.status,
		castGUID = normalizeCastGUID(castGUID),
		source = source,
		timeoutSeconds = timeoutSeconds,
		suppressSeconds = INCOMING_SUPPRESS_SECONDS,
		requestedAt = time and time() or 0,
	}
end

local function isInCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

function Service:ClearGroupBoundOutboundState()
	self.pendingLocalCasts = {}
	self.activeLocalByChallenge = {}
	self.recentIncomingComm = {}
end

function Service:ApplyGroupContext(
	channel, memberSignature, generation)
	local initialized = self.groupContextInitialized == true
	local changed = initialized
		and generation ~= self.groupGeneration
	if changed then
		self:ClearGroupBoundOutboundState()
	end
	self.groupContextInitialized = true
	self.groupChannel = channel
	self.groupMemberSignature = memberSignature
	self.groupGeneration = tonumber(generation) or 0
	return channel, memberSignature, self.groupGeneration, changed
end

function Service:RefreshGroupContext(reason)
	local channel, memberSignature, generation
	if self.transport and self.transport.GetGroupContext then
		channel, memberSignature, generation =
			self.transport:GetGroupContext(reason or "gftp-context")
	end
	return self:ApplyGroupContext(
		channel, memberSignature, generation)
end

function Service:IsEnabled()
	local announcements = GF.MythicPlusAnnouncementService
	return announcements
		and announcements.IsTeleportFollowEnabled
		and announcements:IsTeleportFollowEnabled() == true
end

function Service:IsLocalCastActive(challengeModeID)
	challengeModeID = safeNumber(challengeModeID, 1, 100000)
	local record = challengeModeID and self.activeLocalByChallenge
		and self.activeLocalByChallenge[challengeModeID]
	if record and record.expiresAt > getTime() then
		return true
	end
	if record and self.activeLocalByChallenge then
		self.activeLocalByChallenge[challengeModeID] = nil
	end
	return false
end

function Service:IsPromptSuppressed(challengeModeID)
	challengeModeID = safeNumber(challengeModeID, 1, 100000)
	local expiresAt = challengeModeID and self.suppressedDestinations
		and self.suppressedDestinations[challengeModeID]
	if expiresAt and expiresAt > getTime() then
		return true
	end
	if expiresAt and self.suppressedDestinations then
		self.suppressedDestinations[challengeModeID] = nil
	end
	return false
end

function Service:OnDialogDeclined(challengeModeID)
	challengeModeID = safeNumber(challengeModeID, 1, 100000)
	if not challengeModeID then
		return false
	end
	self.suppressedDestinations =
		self.suppressedDestinations or {}
	self.suppressedDestinations[challengeModeID] =
		getTime() + INCOMING_SUPPRESS_SECONDS
	return true
end

Service.OnDialogAccepted = Service.OnDialogDeclined
Service.OnDialogDismissed = Service.OnDialogDeclined

function Service:ApplySecureButton(button, snapshot)
	local challengeModeID = type(snapshot) == "table"
		and snapshot.challengeModeID or snapshot
	local teleport = GF.MythicPlusTeleportService
	if not (teleport and teleport.ApplySecureButton) then
		return false, false, nil
	end
	return teleport:ApplySecureButton(button, challengeModeID)
end

function Service:ShowFollow(snapshot)
	if type(snapshot) ~= "table" or not self:IsEnabled()
		or isInCombat()
		or self:IsLocalCastActive(snapshot.challengeModeID)
		or self:IsPromptSuppressed(snapshot.challengeModeID)
	then
		return false
	end
	local dialog = GF.MythicPlusTeleportDialog
	if not (dialog and type(dialog.ShowFollow) == "function") then
		return false
	end
	local ok, shown = pcall(dialog.ShowFollow, dialog, snapshot)
	return ok and shown ~= false
end

function Service:CancelFollow(sender, challengeModeID, castGUID)
	local dialog = GF.MythicPlusTeleportDialog
	if not (dialog and type(dialog.CancelFollow) == "function") then
		return false
	end
	local ok, cancelled = pcall(
		dialog.CancelFollow,
		dialog,
		sender,
		challengeModeID,
		normalizeCastGUID(castGUID))
	return ok and cancelled ~= false
end

function Service:QueueProtocolMessage(state, challengeModeID, spellID, castGUID)
	if state ~= "S" and state ~= "C" then
		return false
	end
	challengeModeID = safeNumber(challengeModeID, 1, 100000)
	spellID = safeNumber(spellID, 1, 10000000)
	local channel, memberSignature =
		self:RefreshGroupContext("queue")
	if not (challengeModeID and spellID and channel and memberSignature
		and self.prefixRegistered and self.transport
		and self.transport.QueueMessages)
	then
		return false
	end
	local timeout = state == "S" and PROMPT_ACTIVE_SECONDS or 0
	local message = table.concat({
		state,
		VERSION,
		tostring(challengeModeID),
		tostring(spellID),
		encodeField(castGUID),
		tostring(timeout),
	}, "|")
	if #message > MAX_MESSAGE_BYTES then
		return false
	end
	return self.transport:QueueMessages({ message }, {
		maxBytes = MAX_MESSAGE_BYTES,
		priority = "urgent",
	})
end

local function clearLocalRecord(owner, record)
	if not record then
		return
	end
	if owner.pendingLocalCasts
		and owner.pendingLocalCasts[record.castKey] == record
	then
		owner.pendingLocalCasts[record.castKey] = nil
	end
	if owner.activeLocalByChallenge
		and owner.activeLocalByChallenge[record.challengeModeID] == record
	then
		owner.activeLocalByChallenge[record.challengeModeID] = nil
	end
end

function Service:HandlePlayerSpellcast(event, unit, castGUID, spellID)
	unit = safeString(unit, 32)
	if unit ~= "player" then
		return false
	end
	self:RefreshGroupContext("player-cast")
	castGUID = normalizeCastGUID(castGUID)
	spellID = resolveEventSpellID(unit, spellID)
	local entry = spellID and getTeleportEntryBySpellID(spellID) or nil
	local challengeModeID = entry and safeNumber(
		entry.challengeModeID, 1, 100000) or nil
	local castKey = makeCastKey(castGUID, spellID)
	local currentTime = getTime()
	self.pendingLocalCasts = self.pendingLocalCasts or {}
	self.activeLocalByChallenge = self.activeLocalByChallenge or {}

	if event == "UNIT_SPELLCAST_START" then
		if not (challengeModeID and entry and entry.spellID) then
			return false
		end
		local previous = self.pendingLocalCasts[castKey]
		if previous
			and currentTime - previous.startedAt
				< OUTGOING_DEDUPE_SECONDS
		then
			return false
		end
		local record = {
			castKey = castKey,
			castGUID = castGUID,
			spellID = entry.spellID,
			challengeModeID = challengeModeID,
			groupGeneration = self.groupGeneration,
			startedAt = currentTime,
			expiresAt = currentTime + LOCAL_CAST_ACTIVE_SECONDS,
			promptSent = false,
		}
		self.pendingLocalCasts[castKey] = record
		self.activeLocalByChallenge[challengeModeID] = record
		if C_Timer and C_Timer.After then
			C_Timer.After(LOCAL_CAST_ACTIVE_SECONDS, function()
				if Service.pendingLocalCasts
					and Service.pendingLocalCasts[record.castKey] == record
					and record.expiresAt <= getTime()
				then
					clearLocalRecord(Service, record)
				end
			end)
		end
		local announcement = GF.MythicPlusAnnouncementService
		if announcement and announcement.BroadcastTeleport then
			announcement:BroadcastTeleport(challengeModeID)
		end
		if self:IsEnabled() then
			record.promptSent = self:QueueProtocolMessage(
				"S",
				challengeModeID,
				entry.spellID,
				castGUID)
		end
		return true
	end

	local record = self.pendingLocalCasts[castKey]
	if not record and challengeModeID then
		record = self.activeLocalByChallenge[challengeModeID]
	end
	if not record then
		return false
	end
	if CANCEL_EVENTS[event] and record.promptSent then
		self:QueueProtocolMessage(
			"C",
			record.challengeModeID,
			record.spellID,
			record.castGUID)
	end
	if CANCEL_EVENTS[event] or event == "UNIT_SPELLCAST_SUCCEEDED" then
		clearLocalRecord(self, record)
		return true
	end
	return false
end

function Service:NoteIncomingComm(senderName, challengeModeID, castGUID)
	local keys = makeFallbackKeys(
		senderName, challengeModeID, castGUID)
	if #keys == 0 then
		return
	end
	local currentTime = getTime()
	self.recentIncomingComm = self.recentIncomingComm or {}
	for _, key in ipairs(keys) do
		self.recentIncomingComm[key] = currentTime
		local pending = self.pendingPeerFallbacks
			and self.pendingPeerFallbacks[key]
		if pending then
			pending.cancelled = true
			clearRecord(self.pendingPeerFallbacks, pending)
		end
	end
end

function Service:HasRecentIncomingComm(
	senderName, challengeModeID, castGUID)
	local records = self.recentIncomingComm
	if type(records) ~= "table" then
		return false
	end
	local currentTime = getTime()
	for _, key in ipairs(makeFallbackKeys(
		senderName, challengeModeID, castGUID))
	do
		local seenAt = records[key]
		if seenAt
			and currentTime - seenAt < PEER_COMM_SUPPRESS_SECONDS
		then
			return true
		end
		if seenAt then
			records[key] = nil
		end
	end
	return false
end

function Service:HandleAddonMessage(prefix, text, channel, sender)
	if prefix ~= PREFIX
		or type(text) ~= "string"
		or #text == 0
		or #text > MAX_MESSAGE_BYTES
		or (channel ~= "PARTY"
			and channel ~= "RAID"
			and channel ~= "INSTANCE_CHAT")
		or isSelfSender(sender)
	then
		return false
	end
	local currentChannel = self:RefreshGroupContext("receive")
	if not currentChannel or channel ~= currentChannel then
		return false
	end
	local senderInfo = resolveGroupSender(sender)
	if not senderInfo then
		return false
	end
	local parts = splitMessage(text)
	if #parts ~= 6 then
		return false
	end
	local state = parts[1]
	if (state ~= "S" and state ~= "C") or parts[2] ~= VERSION then
		return false
	end
	local challengeModeID = safeNumber(parts[3], 1, 100000)
	local spellID = safeNumber(parts[4], 1, 10000000)
	local castGUID = normalizeCastGUID(decodeField(parts[5]))
	if parts[5] ~= "" and not castGUID then
		return false
	end
	local timeoutSeconds = safeNumber(
		parts[6], 0, PROMPT_ACTIVE_SECONDS)
	if state == "S" and (not timeoutSeconds or timeoutSeconds < 1)
		or state == "C" and timeoutSeconds ~= 0
	then
		return false
	end
	local teleport = challengeModeID
		and GF.MythicPlusTeleportService
		and GF.MythicPlusTeleportService.GetByChallengeModeID
		and GF.MythicPlusTeleportService:GetByChallengeModeID(
			challengeModeID)
	if not (teleport and spellID
		and tonumber(teleport.spellID) == spellID)
	then
		return false
	end

	self:NoteIncomingComm(
		senderInfo.fullName, challengeModeID, castGUID)
	if state == "C" then
		return self:CancelFollow(
			senderInfo.fullName, challengeModeID, castGUID)
	end
	if not self:IsEnabled()
		or self:IsLocalCastActive(challengeModeID)
	then
		return false
	end
	local snapshot = buildFollowSnapshot(
		senderInfo,
		challengeModeID,
		castGUID,
		"addon",
		timeoutSeconds)
	return snapshot and self:ShowFollow(snapshot) or false
end

function Service:HandlePeerSpellcast(event, unit, castGUID, spellID)
	unit = safeString(unit, 32)
	if not unit or unit == "player" or not self:IsEnabled() then
		return false
	end
	if UnitIsUnit then
		local ok, isPlayer = pcall(UnitIsUnit, unit, "player")
		if ok and isPlayer then
			return false
		end
	end
	castGUID = normalizeCastGUID(castGUID)
	spellID = resolveEventSpellID(unit, spellID)
	local entry = spellID and getTeleportEntryBySpellID(spellID) or nil
	local challengeModeID = entry and safeNumber(
		entry.challengeModeID, 1, 100000) or nil
	local fullName, name
	if Util and Util.GetUnitFullName then
		fullName, name = Util.GetUnitFullName(unit)
	end
	local senderName = fullName or name

	if event == "UNIT_SPELLCAST_START" then
		if not (senderName and challengeModeID and C_Timer
			and C_Timer.After)
			or self:HasRecentIncomingComm(
				senderName, challengeModeID, castGUID)
		then
			return false
		end
		local keys = makeFallbackKeys(
			senderName, challengeModeID, castGUID)
		if #keys == 0 then
			return false
		end
		self.pendingPeerFallbacks =
			self.pendingPeerFallbacks or {}
		if findRecord(self.pendingPeerFallbacks, keys) then
			return false
		end
		local record = {
			keys = keys,
			unit = unit,
			senderName = senderName,
			senderClass = getUnitClass(unit),
			challengeModeID = challengeModeID,
			castGUID = castGUID,
			expiresAt = getTime() + PEER_FALLBACK_DELAY_SECONDS
				+ PROMPT_ACTIVE_SECONDS,
		}
		storeRecord(self.pendingPeerFallbacks, record)
		C_Timer.After(PEER_FALLBACK_DELAY_SECONDS, function()
			if record.cancelled
				or not Service.pendingPeerFallbacks
				or findRecord(
					Service.pendingPeerFallbacks,
					record.keys) ~= record
			then
				return
			end
			clearRecord(Service.pendingPeerFallbacks, record)
			if not Service:IsEnabled()
				or Service:HasRecentIncomingComm(
					record.senderName,
					record.challengeModeID,
					record.castGUID)
				or not resolveGroupSender(record.senderName)
			then
				return
			end
			local senderInfo = {
				unit = record.unit,
				fullName = record.senderName,
				name = record.senderName,
				classFile = record.senderClass,
			}
			local snapshot = buildFollowSnapshot(
				senderInfo,
				record.challengeModeID,
				record.castGUID,
				"unit-fallback",
				PROMPT_ACTIVE_SECONDS)
			if snapshot and Service:ShowFollow(snapshot) then
				Service.activePeerFallbacks =
					Service.activePeerFallbacks or {}
				record.expiresAt = getTime()
					+ PROMPT_ACTIVE_SECONDS
				storeRecord(
					Service.activePeerFallbacks, record)
				C_Timer.After(PROMPT_ACTIVE_SECONDS, function()
					clearRecord(
						Service.activePeerFallbacks, record)
				end)
			end
		end)
		return true
	end

	if not CANCEL_EVENTS[event] or not senderName then
		return false
	end
	local keys = makeFallbackKeys(
		senderName, challengeModeID, castGUID)
	local pending = findRecord(self.pendingPeerFallbacks, keys)
	if pending then
		pending.cancelled = true
		clearRecord(self.pendingPeerFallbacks, pending)
		return true
	end
	local active = findRecord(self.activePeerFallbacks, keys)
	if not active then
		return false
	end
	clearRecord(self.activePeerFallbacks, active)
	return self:CancelFollow(
		active.senderName,
		challengeModeID or active.challengeModeID,
		castGUID or active.castGUID)
end

function Service:RefreshPeerWatcher(reason)
	if not self.peerWatcher then
		self.peerWatcher = CreateFrame("Frame")
		self.peerWatcher:SetScript("OnEvent", function(_, event, ...)
			Service:HandlePeerSpellcast(event, ...)
		end)
	end
	for _, event in ipairs(PEER_SPELLCAST_EVENTS) do
		self.peerWatcher:UnregisterEvent(event)
	end
	if not self:IsEnabled() then
		return false
	end
	local units = collectGroupUnits(false)
	if #units == 0
		or type(self.peerWatcher.RegisterUnitEvent) ~= "function"
		or type(Unpack) ~= "function"
	then
		return false
	end
	local registeredAny = false
	for _, event in ipairs(PEER_SPELLCAST_EVENTS) do
		local ok, registered = pcall(
			self.peerWatcher.RegisterUnitEvent,
			self.peerWatcher,
			event,
			Unpack(units))
		if ok and registered ~= false then
			registeredAny = true
		end
	end
	return registeredAny
end

function Service:OnRosterChanged(reason)
	self:RefreshGroupContext(reason or "roster")
	self.rosterRefreshTicket =
		(tonumber(self.rosterRefreshTicket) or 0) + 1
	local ticket = self.rosterRefreshTicket
	local function refresh()
		if Service.rosterRefreshTicket ~= ticket then
			return
		end
		Service:RefreshPeerWatcher(reason or "roster")
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, refresh)
	else
		refresh()
	end

	local dialog = GF.MythicPlusTeleportDialog
	if dialog and type(dialog.PruneFollowParticipants) == "function" then
		pcall(
			dialog.PruneFollowParticipants,
			dialog,
			function(senderName)
				return resolveGroupSender(senderName) ~= nil
			end)
	end

	local seen = {}
	for _, records in ipairs({
		self.pendingPeerFallbacks or {},
		self.activePeerFallbacks or {},
	}) do
		for _, record in pairs(records) do
			if not seen[record] then
				seen[record] = true
				if not resolveGroupSender(record.senderName) then
					record.cancelled = true
					clearRecord(records, record)
					self:CancelFollow(
						record.senderName,
						record.challengeModeID,
						record.castGUID)
				end
			end
		end
	end
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.pendingLocalCasts = self.pendingLocalCasts or {}
	self.activeLocalByChallenge =
		self.activeLocalByChallenge or {}
	self.pendingPeerFallbacks =
		self.pendingPeerFallbacks or {}
	self.activePeerFallbacks =
		self.activePeerFallbacks or {}
	self.recentIncomingComm =
		self.recentIncomingComm or {}
	self.suppressedDestinations =
		self.suppressedDestinations or {}
	if Transport and Transport.RegisterProtocol then
		self.transport = Transport:RegisterProtocol(PREFIX,
			function(prefix, text, channel, sender)
				Service:HandleAddonMessage(
					prefix, text, channel, sender)
			end, {
				channelPolicy = Transport.CHANNEL_POLICY
					and Transport.CHANNEL_POLICY.RAID_FIRST,
				onContextChanged = function(
					channel, signature, generation)
					Service:ApplyGroupContext(
						channel, signature, generation)
				end,
			})
		self.prefixRegistered = self.transport
			and self.transport:IsRegistered() == true
	end
	self:RefreshGroupContext("init")
	self:RefreshPeerWatcher("init")
end
