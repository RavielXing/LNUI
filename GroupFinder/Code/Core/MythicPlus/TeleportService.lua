local _, GF = ...

GF.MythicPlusTeleportService = GF.MythicPlusTeleportService or {}
local Service = GF.MythicPlusTeleportService
local Util = GF.MythicPlusServiceUtil

-- This is only the teleport-spell augmentation for the current challenge maps.
-- The season dungeon/activity catalog remains owned by MythicPlusSeason.
local TELEPORT_SPELL_BY_CHALLENGE_MODE_ID = GF.MythicPlusSeasonData
	and GF.MythicPlusSeasonData.GetTeleportSpellMap
	and GF.MythicPlusSeasonData.GetTeleportSpellMap() or {}

local CHALLENGE_MODE_ID_BY_SPELL_ID = {}
for challengeModeID, spellID in pairs(TELEPORT_SPELL_BY_CHALLENGE_MODE_ID) do
	CHALLENGE_MODE_ID_BY_SPELL_ID[spellID] = challengeModeID
end

local SECURE_ATTRIBUTE_NIL = {}
-- Only the current confirmed directory is retained. Public entries and their
-- cooldowns remain independent snapshots on every refresh.
local metadataDungeons, metadataSeason, metadataSeasonID, metadataEntries
local TELEPORT_COOLDOWN_GCD_CEILING_SECONDS = 2
local TELEPORT_COOLDOWN_CLOCK_TOLERANCE_SECONDS = 5
local TELEPORT_COOLDOWN_MAX_WAKE_DELAY_SECONDS = 60 * 60
local TELEPORT_COOLDOWN_UNKNOWN_RETRY_SECONDS = 60
local TELEPORT_COOLDOWN_TIMER_PADDING_SECONDS = 0.1
local SECURE_ATTRIBUTE_ORDER = {
	"type",
	"type1",
	"macrotext",
	"macrotext1",
	"spell",
	"spell1",
}

local function now()
	return Util and Util.Now and Util.Now() or (time and time() or 0)
end

local function notify(owner, reason)
	if Util and Util.Notify then
		Util.Notify(owner, reason)
		return
	end
	for _, callback in ipairs(owner.listeners or {}) do
		pcall(callback, owner, reason)
	end
end

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return not ok or secret == true
end

local function safeNumber(value)
	if value == nil or isSecret(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or number == nil or isSecret(number) or type(number) ~= "number" then
		return nil
	end
	if number ~= number or number == math.huge or number == -math.huge then
		return nil
	end
	return number
end

local function getTime()
	if type(GetTime) ~= "function" then
		return 0
	end
	local ok, value = pcall(GetTime)
	return ok and safeNumber(value) or 0
end

local function getServerTime()
	if type(GetServerTime) ~= "function" then
		return nil
	end
	local ok, value = pcall(GetServerTime)
	return ok and safeNumber(value) or nil
end

local function normalizeRemaining(remaining, totalDuration)
	remaining = safeNumber(remaining)
	totalDuration = safeNumber(totalDuration)
	if not remaining or not totalDuration or totalDuration <= 0 then
		return nil
	end
	if remaining < -TELEPORT_COOLDOWN_CLOCK_TOLERANCE_SECONDS
		or remaining > totalDuration + TELEPORT_COOLDOWN_CLOCK_TOLERANCE_SECONDS
	then
		return nil
	end
	return math.max(0, math.min(remaining, totalDuration))
end

local function getDurationObjectRemaining(spellID, fallbackDuration)
	if not (C_Spell and C_Spell.GetSpellCooldownDuration) then
		return nil
	end
	local ok, durationObject = pcall(
		C_Spell.GetSpellCooldownDuration,
		spellID,
		true)
	if not ok or not durationObject
		or type(durationObject.GetRemainingDuration) ~= "function"
	then
		return nil
	end

	local remainingOK, remaining = pcall(
		durationObject.GetRemainingDuration,
		durationObject)
	if not remainingOK then
		return nil
	end

	local totalDuration = safeNumber(fallbackDuration)
	if type(durationObject.GetTotalDuration) == "function" then
		local totalOK, durationObjectTotal = pcall(
			durationObject.GetTotalDuration,
			durationObject)
		if totalOK and safeNumber(durationObjectTotal) then
			totalDuration = safeNumber(durationObjectTotal)
		end
	end
	return normalizeRemaining(remaining, totalDuration)
end

local function getClockRemaining(startTime, duration, clockTime)
	startTime = safeNumber(startTime)
	duration = safeNumber(duration)
	clockTime = safeNumber(clockTime)
	if not startTime or startTime <= 0
		or not duration or duration <= 0
		or not clockTime
	then
		return nil
	end
	return normalizeRemaining(startTime + duration - clockTime, duration)
end

local function resolveCooldownRemaining(spellID, startTime, duration)
	local remaining = getDurationObjectRemaining(spellID, duration)
	if remaining ~= nil then
		return remaining, true, "duration-object"
	end

	remaining = getClockRemaining(startTime, duration, getTime())
	if remaining ~= nil then
		return remaining, true, "frame-time"
	end

	remaining = getClockRemaining(startTime, duration, getServerTime())
	if remaining ~= nil then
		return remaining, true, "server-time-fallback"
	end
	return 0, false, "unreadable"
end

local function getCooldownWakeDelay(cooldown)
	if not cooldown or cooldown.onCooldown ~= true then
		return nil
	end
	local remaining = safeNumber(cooldown.remaining)
	if cooldown.timingValid == true and remaining and remaining > 0 then
		return math.min(
			remaining + TELEPORT_COOLDOWN_TIMER_PADDING_SECONDS,
			TELEPORT_COOLDOWN_MAX_WAKE_DELAY_SECONDS)
	end
	return TELEPORT_COOLDOWN_UNKNOWN_RETRY_SECONDS
end

local function isInCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

local function getSpellInfo(spellID)
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
		if ok and type(info) == "table" then
			return info.name, info.iconID, info.castTime
		end
	end
	if type(GetSpellInfo) == "function" then
		local ok, name, _, iconID, castTime = pcall(GetSpellInfo, spellID)
		if ok then
			return name, iconID, castTime
		end
	end
	return nil, nil, nil
end

local function getSpellLink(spellID)
	if C_Spell and C_Spell.GetSpellLink then
		local ok, link = pcall(C_Spell.GetSpellLink, spellID)
		if ok and type(link) == "string" and link ~= "" then
			return link
		end
	end
	if type(GetSpellLink) == "function" then
		local ok, link = pcall(GetSpellLink, spellID)
		if ok and type(link) == "string" and link ~= "" then
			return link
		end
	end
	return nil
end

local function isSpellKnown(spellID)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
		if ok then
			return known == true, type(known) == "boolean" and not isSecret(known)
		end
	end
	if type(IsSpellKnownOrOverridesKnown) == "function" then
		local ok, known = pcall(IsSpellKnownOrOverridesKnown, spellID)
		if ok then
			return known == true, type(known) == "boolean" and not isSecret(known)
		end
	end
	if type(IsSpellKnown) == "function" then
		local ok, known = pcall(IsSpellKnown, spellID)
		if ok then
			return known == true, type(known) == "boolean" and not isSecret(known)
		end
	end
	return false, false
end

local function getCooldown(spellID)
	local startTime
	local duration
	local durationReadable
	local isEnabled
	local isActive
	local modRate

	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		if ok and type(info) == "table" then
			startTime = safeNumber(info.startTime)
			duration = safeNumber(info.duration)
			durationReadable = duration ~= nil
			isEnabled = info.isEnabled
			if type(info.isActive) == "boolean" then
				isActive = info.isActive
			end
			modRate = safeNumber(info.modRate)
		end
	end

	if startTime == nil and type(GetSpellCooldown) == "function" then
		local ok, legacyStart, legacyDuration, legacyEnabled, legacyModRate =
			pcall(GetSpellCooldown, spellID)
		if ok then
			startTime = safeNumber(legacyStart)
			duration = safeNumber(legacyDuration)
			durationReadable = duration ~= nil
			isEnabled = legacyEnabled
			modRate = safeNumber(legacyModRate)
		end
	end

	startTime = startTime or 0
	duration = duration or 0
	modRate = modRate or 1
	local enabled = isEnabled ~= false and isEnabled ~= 0
	local endTime = startTime + duration
	local remaining = 0
	local timingValid = true
	local timingSource = "inactive"
	if enabled and duration > 0 then
		remaining, timingValid, timingSource = resolveCooldownRemaining(
			spellID,
			startTime,
			duration)
	end
	if isActive == nil then
		isActive = enabled and startTime > 0 and duration > 0
			and (timingValid ~= true or remaining > 0)
	end
	local isShortGlobalCooldown = durationReadable == true
		and duration > 0
		and duration <= TELEPORT_COOLDOWN_GCD_CEILING_SECONDS

	return {
		startTime = startTime,
		duration = duration,
		isEnabled = enabled,
		modRate = modRate,
		endTime = endTime,
		remaining = remaining,
		timingValid = timingValid,
		timingSource = timingSource,
		isActive = isActive,
		onCooldown = isActive == true and not isShortGlobalCooldown,
	}
end

local function getChallengeModeID(dungeon)
	if type(dungeon) == "table" then
		local challengeModeID = safeNumber(dungeon.challengeModeID)
		if challengeModeID then
			return challengeModeID
		end
		local mapID = safeNumber(dungeon.mapID)
		if mapID and TELEPORT_SPELL_BY_CHALLENGE_MODE_ID[mapID] then
			return mapID
		end
		return nil
	end
	local value = safeNumber(dungeon)
	if value and TELEPORT_SPELL_BY_CHALLENGE_MODE_ID[value] then
		return value
	end
	return value
end

local function buildEntry(dungeon, metadata)
	local challengeModeID = getChallengeModeID(dungeon)
	local mapID = type(dungeon) == "table" and safeNumber(dungeon.mapID) or nil
	local spellID = challengeModeID and TELEPORT_SPELL_BY_CHALLENGE_MODE_ID[challengeModeID] or nil
	local updatedAt = now()

	if not spellID then
		return {
			dungeon = dungeon,
			challengeModeID = challengeModeID,
			mapID = mapID,
			status = "unmapped",
			updatedAt = updatedAt,
		}, true
	end

	local spellName, iconID, castTime, spellLink, learned, macroText, knownReadable
	if metadata then
		spellName, iconID, castTime = metadata.spellName,
			metadata.iconID, metadata.castTime
		spellLink, learned, macroText = metadata.spellLink,
			metadata.learned, metadata.macroText
	else
		spellName, iconID, castTime = getSpellInfo(spellID)
		spellLink = getSpellLink(spellID)
		learned, knownReadable = isSpellKnown(spellID)
	end
	local cooldown = getCooldown(spellID)
	local status
	if not learned then
		status = "not_learned"
	elseif cooldown.onCooldown then
		status = "cooldown"
	else
		status = "ready"
	end
	if not metadata and type(spellName) == "string" and spellName ~= "" then
		macroText = "/cast " .. spellName
	end
	local confirmed = metadata ~= nil or (knownReadable == true
		and type(spellName) == "string" and not isSecret(spellName)
		and spellName ~= "" and safeNumber(iconID) ~= nil
		and safeNumber(castTime) ~= nil
		and type(spellLink) == "string" and not isSecret(spellLink)
		and spellLink ~= "")
	-- Size the complete public record once instead of growing a smaller table
	-- when its spell fields are appended. Its ownership and values are unchanged.
	return {
		dungeon = dungeon,
		challengeModeID = challengeModeID,
		mapID = mapID,
		spellID = spellID,
		status = status,
		updatedAt = updatedAt,
		spellName = spellName,
		iconID = iconID,
		castTime = castTime,
		spellLink = spellLink,
		learned = learned,
		cooldown = cooldown,
		macroText = macroText,
	}, confirmed
end

local function cooldownOnlyReason(reason)
	return reason == "SPELL_UPDATE_COOLDOWN" or reason == "cooldown-finished"
end

local function matchesMetadataDirectory(dungeons, season)
	if not metadataEntries or metadataDungeons ~= dungeons
		or metadataSeason ~= season
		or metadataSeasonID ~= (season and season.seasonID)
		or #metadataEntries ~= #dungeons or #dungeons == 0
		or (season and season.status ~= nil and season.status ~= "ready")
	then
		return false
	end
	for index, dungeon in ipairs(dungeons) do
		local metadata = metadataEntries[index]
		local challengeModeID = getChallengeModeID(dungeon)
		local mapID = type(dungeon) == "table" and safeNumber(dungeon.mapID) or nil
		local spellID = challengeModeID and TELEPORT_SPELL_BY_CHALLENGE_MODE_ID[challengeModeID] or nil
		if metadata.dungeon ~= dungeon or metadata.challengeModeID ~= challengeModeID
			or metadata.mapID ~= mapID or metadata.spellID ~= spellID
		then
			return false
		end
	end
	return true
end

local function copyMetadata(entry)
	return {
		dungeon = entry.dungeon,
		challengeModeID = entry.challengeModeID,
		mapID = entry.mapID,
		spellID = entry.spellID,
		spellName = entry.spellName,
		iconID = entry.iconID,
		castTime = entry.castTime,
		spellLink = entry.spellLink,
		learned = entry.learned,
		macroText = entry.macroText,
	}
end

local function resolveEntry(owner, dungeon)
	if type(dungeon) == "table" then
		local challengeModeID = safeNumber(dungeon.challengeModeID)
		if challengeModeID and owner.byChallengeModeID then
			local entry = owner.byChallengeModeID[challengeModeID]
			if entry then
				return entry
			end
		end
		local mapID = safeNumber(dungeon.mapID)
		if mapID and owner.byMapID then
			return owner.byMapID[mapID] or (owner.byChallengeModeID and owner.byChallengeModeID[mapID])
		end
		return nil
	end

	local id = safeNumber(dungeon)
	if not id then
		return nil
	end
	return (owner.byChallengeModeID and owner.byChallengeModeID[id])
		or (owner.byMapID and owner.byMapID[id])
end

local function makeSecureAttributes(ready, macroText)
	return {
		type = ready and "macro" or SECURE_ATTRIBUTE_NIL,
		type1 = ready and "macro" or SECURE_ATTRIBUTE_NIL,
		macrotext = ready and macroText or SECURE_ATTRIBUTE_NIL,
		macrotext1 = ready and macroText or SECURE_ATTRIBUTE_NIL,
		spell = SECURE_ATTRIBUTE_NIL,
		spell1 = SECURE_ATTRIBUTE_NIL,
	}
end

local function applySecureAttributes(button, attributes)
	if not (button and button.SetAttribute and type(attributes) == "table") then
		return false
	end
	for _, key in ipairs(SECURE_ATTRIBUTE_ORDER) do
		local value = attributes[key]
		if value == SECURE_ATTRIBUTE_NIL then
			value = nil
		end
		local ok = pcall(button.SetAttribute, button, key, value)
		if not ok then
			return false
		end
	end
	return true
end

function Service:AddListener(callback)
	if type(callback) ~= "function" then
		return
	end
	if Util and Util.AddListener then
		Util.AddListener(self, callback)
		return
	end
	self.listeners = self.listeners or {}
	self.listeners[#self.listeners + 1] = callback
end

function Service:GetByChallengeModeID(challengeModeID)
	challengeModeID = safeNumber(challengeModeID)
	return challengeModeID and self.byChallengeModeID and self.byChallengeModeID[challengeModeID] or nil
end

function Service:GetByMapID(mapID)
	mapID = safeNumber(mapID)
	if not mapID then
		return nil
	end
	return (self.byMapID and self.byMapID[mapID])
		or (self.byChallengeModeID and self.byChallengeModeID[mapID])
end

function Service:GetBySpellID(spellID)
	spellID = self:NormalizeSpellID(spellID)
	return spellID and self.bySpellID and self.bySpellID[spellID] or nil
end

function Service:GetStatus(dungeon)
	local entry = resolveEntry(self, dungeon)
	return entry and entry.status or "unmapped", entry and entry.spellID or nil, entry
end

function Service:IsCombatLocked()
	return isInCombat()
end

function Service:GetMacroText(dungeon)
	local entry = resolveEntry(self, dungeon)
	return entry and entry.macroText or nil
end

function Service:GetDiagnosticSnapshot()
	local entries = {}
	local dungeons = GF.MythicPlusSeason and GF.MythicPlusSeason.GetDungeons
		and GF.MythicPlusSeason:GetDungeons() or {}
	for _, dungeon in ipairs(dungeons) do
		local entry = resolveEntry(self, dungeon)
		entries[#entries + 1] = {
			name = dungeon.name,
			challengeModeID = tonumber(dungeon.challengeModeID),
			mapID = tonumber(dungeon.mapID),
			spellID = entry and tonumber(entry.spellID) or nil,
			spellName = entry and entry.spellName or nil,
			status = entry and entry.status or "unmapped",
			learned = entry and entry.learned == true or false,
			onCooldown = entry and entry.cooldown and entry.cooldown.onCooldown == true or false,
			cooldownRemaining = entry and entry.cooldown
				and safeNumber(entry.cooldown.remaining) or nil,
			cooldownTimingValid = entry and entry.cooldown
				and entry.cooldown.timingValid == true or false,
			cooldownTimingSource = entry and entry.cooldown
				and entry.cooldown.timingSource or nil,
			macroReady = entry and type(entry.macroText) == "string"
				and entry.macroText ~= "" or false,
		}
	end
	return {
		entries = entries,
		updatedAt = self.updatedAt,
		reason = self.reason,
		cooldownTimerWakeDelay = self.cooldownTimerWakeDelay,
		cooldownTimerError = self.cooldownTimerError,
	}
end

function Service:NormalizeSpellID(spellID)
	return safeNumber(spellID)
end

function Service:GetChallengeModeIDBySpellID(spellID)
	spellID = self:NormalizeSpellID(spellID)
	return spellID and CHALLENGE_MODE_ID_BY_SPELL_ID[spellID] or nil
end

function Service:GetMapIDBySpellID(spellID)
	local entry = self:GetBySpellID(spellID)
	return entry and entry.mapID or nil
end

function Service:GetActiveChallengeModeID()
	if self.activeCastExpiresAt and getTime() >= self.activeCastExpiresAt then
		self.activeCastChallengeModeID = nil
		self.activeCastGUID = nil
		self.activeCastExpiresAt = nil
	end
	return self.activeCastChallengeModeID
end

function Service:GetInterruptedCastPulse()
	if not self.interruptedCastExpiresAt
		or getTime() >= self.interruptedCastExpiresAt
	then
		return nil, nil
	end
	return self.interruptedCastChallengeModeID, self.interruptedCastSerial
end

function Service:HandleUnitSpellcast(event, unit, castGUID, spellID)
	if unit ~= "player" then
		return false
	end
	spellID = self:NormalizeSpellID(spellID)
	local challengeModeID = spellID and self:GetChallengeModeIDBySpellID(spellID)
	if not challengeModeID then
		return false
	end

	if event == "UNIT_SPELLCAST_START" then
		self.interruptedCastChallengeModeID = nil
		self.interruptedCastExpiresAt = nil
		self.activeCastChallengeModeID = challengeModeID
		self.activeCastGUID = castGUID
		self.activeCastExpiresAt = getTime() + 16
		if self.activeCastTimer and self.activeCastTimer.Cancel then
			self.activeCastTimer:Cancel()
		end
		if C_Timer and C_Timer.NewTimer then
			self.activeCastTimer = C_Timer.NewTimer(16, function()
				self.activeCastTimer = nil
				if Service.activeCastChallengeModeID == challengeModeID then
					Service.activeCastChallengeModeID = nil
					Service.activeCastGUID = nil
					Service.activeCastExpiresAt = nil
					notify(Service, "teleport_cast_timeout")
				end
			end)
		end
	else
		if self.activeCastChallengeModeID ~= challengeModeID then
			return false
		end
		if self.activeCastGUID and castGUID
			and self.activeCastGUID ~= castGUID
		then
			return false
		end
		if event == "UNIT_SPELLCAST_INTERRUPTED" then
			self.interruptedCastChallengeModeID = challengeModeID
			self.interruptedCastSerial =
				(tonumber(self.interruptedCastSerial) or 0) + 1
			self.interruptedCastExpiresAt = getTime() + 2
		end
		self.activeCastChallengeModeID = nil
		self.activeCastGUID = nil
		self.activeCastExpiresAt = nil
		if self.activeCastTimer and self.activeCastTimer.Cancel then
			self.activeCastTimer:Cancel()
		end
		self.activeCastTimer = nil
	end
	notify(self, event)
	return true
end

function Service:RequestRefresh(reason, delay)
	-- The last reason remains diagnostic copy, but a later cooldown event must
	-- not erase an earlier SPELLS_CHANGED, season or world invalidation.
	if not cooldownOnlyReason(reason) then
		self.metadataRefreshQueued = true
	end
	if self.refreshQueued then
		self.queuedReason = reason or self.queuedReason
		return
	end
	self.refreshQueued = true
	self.queuedReason = reason

	local function run()
		self.refreshQueued = nil
		local queuedReason = self.queuedReason
		local refreshMetadata = self.metadataRefreshQueued
		self.queuedReason = nil
		self.metadataRefreshQueued = nil
		self:Refresh(queuedReason or "requested", refreshMetadata)
	end

	delay = tonumber(delay) or 0
	if C_Timer and C_Timer.After then
		C_Timer.After(math.max(0, delay), run)
	else
		run()
	end
end

function Service:Refresh(reason, refreshMetadata)
	local season = GF.MythicPlusSeason
	local dungeons = season and season.GetDungeons and season:GetDungeons() or {}
	local cooldownOnly = cooldownOnlyReason(reason) and refreshMetadata ~= true
		and self.metadataRefreshQueued ~= true
		and matchesMetadataDirectory(dungeons, season)
	local nextMetadata = not cooldownOnly and #dungeons > 0
		and (not season or season.status == nil or season.status == "ready")
		and {} or nil
	local entries = {}
	local byChallengeModeID = {}
	local byMapID = {}
	local bySpellID = {}
	local nextCooldownWakeDelay

	for index, dungeon in ipairs(dungeons) do
		local entry, confirmed = buildEntry(dungeon,
			cooldownOnly and metadataEntries[index] or nil)
		entries[#entries + 1] = entry
		if nextMetadata then
			if confirmed then nextMetadata[index] = copyMetadata(entry)
			else nextMetadata = nil end
		end
		if entry.challengeModeID then
			byChallengeModeID[entry.challengeModeID] = entry
		end
		if entry.mapID then
			byMapID[entry.mapID] = entry
		end
		if entry.spellID then
			bySpellID[entry.spellID] = entry
		end
		local wakeDelay = entry.status == "cooldown"
			and getCooldownWakeDelay(entry.cooldown) or nil
		if wakeDelay
			and (not nextCooldownWakeDelay or wakeDelay < nextCooldownWakeDelay)
		then
			nextCooldownWakeDelay = wakeDelay
		end
	end
	if not cooldownOnly then
		metadataEntries = nextMetadata
		metadataDungeons = nextMetadata and dungeons or nil
		metadataSeason = nextMetadata and season or nil
		metadataSeasonID = nextMetadata and season and season.seasonID or nil
	end

	self.entries = entries
	self.byChallengeModeID = byChallengeModeID
	self.byMapID = byMapID
	self.bySpellID = bySpellID
	self.updatedAt = now()
	self.reason = reason
	if self.cooldownTimer and self.cooldownTimer.Cancel then
		self.cooldownTimer:Cancel()
	end
	self.cooldownTimer = nil
	self.cooldownTimerWakeDelay = nextCooldownWakeDelay
	self.cooldownTimerError = nil
	if nextCooldownWakeDelay and C_Timer and C_Timer.NewTimer then
		local ok, timerOrError = pcall(C_Timer.NewTimer, nextCooldownWakeDelay, function()
			Service.cooldownTimer = nil
			Service:RequestRefresh("cooldown-finished")
		end)
		if ok then
			self.cooldownTimer = timerOrError
		else
			self.cooldownTimerError = tostring(timerOrError)
		end
	end
	notify(self, reason or "refresh")
	return entries
end

function Service:ApplySecureButton(button, dungeon)
	if not (button and button.SetAttribute) then
		return false, false, nil
	end

	local entry = resolveEntry(self, dungeon)
	local ready = entry ~= nil and entry.status == "ready"
		and type(entry.macroText) == "string" and entry.macroText ~= ""
	local attributes = makeSecureAttributes(ready, entry and entry.macroText or nil)
	local challengeModeID = entry and entry.challengeModeID or getChallengeModeID(dungeon)

	button.gfTeleportDesiredChallengeModeID = challengeModeID
	button.gfTeleportDesiredReady = ready
	button.gfTeleportDesiredMacroText = entry and entry.macroText or nil

	if isInCombat() then
		local currentReady = button.gfTeleportSecureReady == true
		local currentMatchesDesired = currentReady == ready
			and (not ready or button.gfTeleportSecureMacroText == entry.macroText)
		if currentMatchesDesired then
			if self.pendingSecureButtons then
				self.pendingSecureButtons[button] = nil
			end
			button.gfTeleportSecurePending = nil
		else
			self.pendingSecureButtons = self.pendingSecureButtons
				or setmetatable({}, { __mode = "k" })
			self.pendingSecureButtons[button] = {
				attributes = attributes,
				challengeModeID = challengeModeID,
				ready = ready,
				macroText = entry and entry.macroText or nil,
			}
			button.gfTeleportSecurePending = true
		end
		if currentReady then
			return true, not currentMatchesDesired, entry
		end
		button.gfTeleportEffectiveChallengeModeID = challengeModeID
		return false, not currentMatchesDesired, entry
	end

	local applied = applySecureAttributes(button, attributes)
	if applied then
		if self.pendingSecureButtons then
			self.pendingSecureButtons[button] = nil
		end
		button.gfTeleportSecurePending = nil
		button.gfTeleportSecureReady = ready
		button.gfTeleportSecureMacroText = entry and entry.macroText or nil
		button.gfTeleportEffectiveChallengeModeID = challengeModeID
	end
	return applied and ready, false, entry
end

function Service:FlushPending()
	if isInCombat() then
		return false
	end
	for button, pending in pairs(self.pendingSecureButtons or {}) do
		self.pendingSecureButtons[button] = nil
		local stillDesired = button and pending
			and button.gfTeleportDesiredChallengeModeID == pending.challengeModeID
			and button.gfTeleportDesiredReady == (pending.ready == true)
			and button.gfTeleportDesiredMacroText == pending.macroText
		if stillDesired and applySecureAttributes(button, pending.attributes) then
			button.gfTeleportSecurePending = nil
			button.gfTeleportSecureReady = pending.ready == true
			button.gfTeleportSecureMacroText = pending.macroText
			button.gfTeleportEffectiveChallengeModeID = pending.challengeModeID
		elseif button then
			button.gfTeleportSecurePending = nil
		end
	end
	return true
end

function Service:AddTooltipLines(tooltip, dungeon, options)
	if not (tooltip and tooltip.AddLine) then
		return false
	end

	local entry = resolveEntry(self, dungeon)
	local status = entry and entry.status or "unmapped"
	local includeDestination = type(options) ~= "table" or options.includeDestinationTitle ~= false
	local secureReady = type(options) ~= "table" or options.secureReady ~= false
	local combatLocked = status == "ready" and isInCombat()
	if includeDestination and tooltip.AddDoubleLine then
		local dungeonName = type(dungeon) == "table" and dungeon.name
			or (entry and entry.dungeon and entry.dungeon.name)
			or ((GF.L and GF.L.MPLUS_UNKNOWN_DUNGEON) or "未知地下城")
		tooltip:AddDoubleLine(
			(GF.L and GF.L.MPLUS_TELEPORT_TO) or "传送至",
			dungeonName,
			1, 0.82, 0,
			1, 1, 1
		)
	end

	if combatLocked then
		tooltip:AddLine((GF.L and GF.L.MPLUS_TELEPORT_COMBAT_LOCKED)
			or "Cannot teleport while in combat",
			1, 0.15, 0.15, true)
	elseif status == "ready" and not secureReady then
		tooltip:AddLine((GF.L and GF.L.MPLUS_TELEPORT_PENDING)
			or "The teleport button will be ready after combat",
			0.58, 0.58, 0.58, true)
	elseif status == "ready" then
		tooltip:AddLine((GF.L and GF.L.MPLUS_TELEPORT_READY) or "英雄之路已就绪",
			0.1, 1, 0.1, true)
	elseif status == "cooldown" then
		tooltip:AddLine((GF.L and GF.L.MPLUS_TELEPORT_COOLDOWN) or "英雄之路冷却中",
			1, 0.15, 0.15, true)
	else
		tooltip:AddLine((GF.L and GF.L.MPLUS_TELEPORT_NOT_LEARNED) or "未获得英雄之路",
			0.58, 0.58, 0.58, true)
	end
	return status == "ready" and secureReady and not combatLocked
end
