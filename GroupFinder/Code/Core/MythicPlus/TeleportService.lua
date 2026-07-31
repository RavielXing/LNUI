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
	return number
end

local function getTime()
	return GetTime and GetTime() or 0
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
			return known == true
		end
	end
	if type(IsSpellKnownOrOverridesKnown) == "function" then
		local ok, known = pcall(IsSpellKnownOrOverridesKnown, spellID)
		if ok then
			return known == true
		end
	end
	if type(IsSpellKnown) == "function" then
		local ok, known = pcall(IsSpellKnown, spellID)
		if ok then
			return known == true
		end
	end
	return false
end

local function getCooldown(spellID)
	local startTime
	local duration
	local isEnabled
	local isActive
	local modRate

	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		if ok and type(info) == "table" then
			startTime = safeNumber(info.startTime)
			duration = safeNumber(info.duration)
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
			isEnabled = legacyEnabled
			modRate = safeNumber(legacyModRate)
		end
	end

	startTime = startTime or 0
	duration = duration or 0
	modRate = modRate or 1
	local enabled = isEnabled ~= false and isEnabled ~= 0
	local endTime = startTime + duration
	local remaining = enabled and duration > 0 and math.max(0, endTime - getTime()) or 0
	if isActive == nil then
		isActive = enabled and startTime > 0 and duration > 0 and remaining > 0
	end

	return {
		startTime = startTime,
		duration = duration,
		isEnabled = enabled,
		modRate = modRate,
		endTime = endTime,
		remaining = remaining,
		isActive = isActive,
		onCooldown = isActive,
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

local function buildEntry(dungeon)
	local challengeModeID = getChallengeModeID(dungeon)
	local mapID = type(dungeon) == "table" and safeNumber(dungeon.mapID) or nil
	local spellID = challengeModeID and TELEPORT_SPELL_BY_CHALLENGE_MODE_ID[challengeModeID] or nil
	local entry = {
		dungeon = dungeon,
		challengeModeID = challengeModeID,
		mapID = mapID,
		spellID = spellID,
		status = spellID and "not_learned" or "unmapped",
		updatedAt = now(),
	}

	if not spellID then
		return entry
	end

	entry.spellName, entry.iconID, entry.castTime = getSpellInfo(spellID)
	entry.spellLink = getSpellLink(spellID)
	entry.learned = isSpellKnown(spellID)
	entry.cooldown = getCooldown(spellID)
	if not entry.learned then
		entry.status = "not_learned"
	elseif entry.cooldown.onCooldown then
		entry.status = "cooldown"
	else
		entry.status = "ready"
	end
	if type(entry.spellName) == "string" and entry.spellName ~= "" then
		entry.macroText = "/cast " .. entry.spellName
	end
	return entry
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
			macroReady = entry and type(entry.macroText) == "string"
				and entry.macroText ~= "" or false,
		}
	end
	return {
		entries = entries,
		updatedAt = self.updatedAt,
		reason = self.reason,
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
	if self.refreshQueued then
		self.queuedReason = reason or self.queuedReason
		return
	end
	self.refreshQueued = true
	self.queuedReason = reason

	local function run()
		self.refreshQueued = nil
		local queuedReason = self.queuedReason
		self.queuedReason = nil
		self:Refresh(queuedReason or "requested")
	end

	delay = tonumber(delay) or 0
	if C_Timer and C_Timer.After then
		C_Timer.After(math.max(0, delay), run)
	else
		run()
	end
end

function Service:Refresh(reason)
	local dungeons = GF.MythicPlusSeason and GF.MythicPlusSeason.GetDungeons
		and GF.MythicPlusSeason:GetDungeons() or {}
	local entries = {}
	local byChallengeModeID = {}
	local byMapID = {}
	local bySpellID = {}
	local nextCooldown

	for _, dungeon in ipairs(dungeons) do
		local entry = buildEntry(dungeon)
		entries[#entries + 1] = entry
		if entry.challengeModeID then
			byChallengeModeID[entry.challengeModeID] = entry
		end
		if entry.mapID then
			byMapID[entry.mapID] = entry
		end
		if entry.spellID then
			bySpellID[entry.spellID] = entry
		end
		local remaining = entry.cooldown and tonumber(entry.cooldown.remaining)
		if entry.status == "cooldown" and remaining and remaining > 0
			and (not nextCooldown or remaining < nextCooldown)
		then
			nextCooldown = remaining
		end
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
	if nextCooldown and C_Timer and C_Timer.NewTimer then
		self.cooldownTimer = C_Timer.NewTimer(nextCooldown + 0.1, function()
			Service.cooldownTimer = nil
			Service:RequestRefresh("cooldown-finished")
		end)
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
