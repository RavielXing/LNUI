local _, GF = ...

GF.ListFilter = {}

local LF = GF.ListFilter
local FS = GF.FilterSpec

local BLOODLUST_CLASS = {
	MAGE = true,
	SHAMAN = true,
	EVOKER = true,
	HUNTER = true,
}

local SAME_CLASS_CATS = {
	[GF.CAT_DUNGEON] = true,
	[GF.CAT_DELVE] = true,
	[GF.CAT_RAID] = true,
}

function GF.HasBloodlustClass(classFile)
	return classFile and BLOODLUST_CLASS[classFile] == true
end

local function isSecretValue(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

local function readField(owner, key)
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, owner, key)
		if ok and secret == true then
			return nil, "secret"
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	end
	if isSecretValue(value) then
		return nil, "secret"
	end
	if value == nil then
		return nil, "missing"
	end
	return value, "value"
end

local function safeField(owner, key)
	local value = readField(owner, key)
	return value
end

local function toCountNumber(v)
	if v == nil then
		return nil
	end
	if isSecretValue(v) then
		return nil
	end
	local ok, numeric = pcall(tonumber, v)
	return ok and numeric or nil
end

local function pcallFirst(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

local function getSearchResultInfo(resultID)
	return pcallFirst(C_LFGList and C_LFGList.GetSearchResultInfo, resultID)
end

local function getActivityInfoForResult(info, activityID)
	return pcallFirst(
		C_LFGList and C_LFGList.GetActivityInfoTable,
		activityID,
		safeField(info, "questID"),
		safeField(info, "isWarMode"))
end

local function getPlayerRole(playerInfo)
	local role = safeField(playerInfo, "assignedRole")
		or safeField(playerInfo, "role")
	if role == "HEAL" then
		return "HEALER"
	end
	if role == "DPS" then
		return "DAMAGER"
	end
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		return role
	end
	return nil
end

local function getPlayerClass(playerInfo)
	local classFile = safeField(playerInfo, "classFilename")
		or safeField(playerInfo, "classFileName")
		or safeField(playerInfo, "classFile")
	if type(classFile) == "string" and classFile ~= "" then
		return classFile:upper()
	end
	return nil
end

local function fetchSearchResultPlayers(resultID, info, entry)
	local players = entry and entry.players
	local expectedRaw = toCountNumber(safeField(info, "numMembers"))
	local expected = math.max(0, math.floor((expectedRaw or 0) + 0.0001))
	local expectedKnown = expectedRaw ~= nil
	if type(players) == "table" then
		return players, #players > 0, expectedKnown and (expected <= 0 or #players >= expected)
	end
	if not expectedKnown or not resultID or not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then
		return nil, false, false
	end
	players = {}
	for i = 1, expected do
		local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
		if ok and playerInfo then
			players[#players + 1] = playerInfo
		end
	end
	return players, #players > 0, expected <= 0 or #players == expected
end

local function resultHasBloodlust(resultID, info, entry)
	local players, loaded, complete = fetchSearchResultPlayers(resultID, info, entry)
	if not loaded then
		return nil
	end
	for _, playerInfo in ipairs(players) do
		if GF.HasBloodlustClass(getPlayerClass(playerInfo)) then
			return true
		end
	end
	if complete then
		return false
	end
	return nil
end

local ROLE_RANGE_DEFS = {
	{ show = "showTankRange", min = "rangeTankMin", en = "rangeTankEn", remaining = "TANK_REMAINING" },
	{ show = "showHealRange", min = "rangeHealMin", en = "rangeHealEn", remaining = "HEALER_REMAINING" },
	{ show = "showDpsRange", min = "rangeDpsMin", en = "rangeDpsEn", remaining = "DAMAGER_REMAINING" },
}
local RAID_ROLE_COUNT_DEFS = {
	{ en = "raidTankEn", min = "raidTankMin", max = "raidTankMax", count = "TANK" },
	{ en = "raidHealEn", min = "raidHealMin", max = "raidHealMax", count = "HEALER" },
	{ en = "raidDpsEn", min = "raidDpsMin", max = "raidDpsMax", count = "DAMAGER" },
}

local function inRange(val, minV, maxV)
	val = toCountNumber(val)
	minV = toCountNumber(minV) or 0
	maxV = toCountNumber(maxV) or 0
	if val == nil then
		return true
	end
	if minV > 0 and val < minV then
		return false
	end
	if maxV > 0 and val > maxV then
		return false
	end
	return true
end

local function roleVacancyMeetsThreshold(val, threshold)
	val = toCountNumber(val)
	local minThreshold = GF.ROLE_VACANCY_THRESHOLD_MIN or 1
	local maxThreshold = GF.ROLE_VACANCY_THRESHOLD_MAX or 4
	threshold = math.floor((toCountNumber(threshold) or minThreshold) + 0.0001)
	if threshold < minThreshold then
		threshold = minThreshold
	elseif threshold > maxThreshold then
		threshold = maxThreshold
	end
	if val == nil then
		return true
	end
	if val < threshold then
		return false
	end
	return true
end

local function roleCountInRange(val, minV, maxV)
	val = toCountNumber(val)
	if val == nil then
		return true
	end
	minV = math.max(0, math.floor((toCountNumber(minV) or 0) + 0.0001))
	maxV = math.max(0, math.floor((toCountNumber(maxV) or 0) + 0.0001))
	if minV == 0 and maxV == 0 then
		return val == 0
	end
	if minV > 0 and val < minV then
		return false
	end
	if maxV > 0 and val > maxV then
		return false
	end
	return true
end

local function isClientFilterEnabled(client, key)
	return client and (client[key] == true or client[key] == 1)
end

local function getCompletedEncounterCount(resultID)
	if not C_LFGList or not C_LFGList.GetSearchResultEncounterInfo then
		return nil
	end
	local ok, encounters = pcall(C_LFGList.GetSearchResultEncounterInfo, resultID)
	if not ok then
		return nil
	end
	if encounters == nil then
		return 0
	end
	if type(encounters) ~= "table" then
		return nil
	end
	return #encounters
end

local function fetchMemberCounts(resultID, info, entry)
	if entry and entry._displayCountsLoaded and type(entry._displayCounts) == "table" then
		return entry._displayCounts
	end
	if not C_LFGList or not C_LFGList.GetSearchResultMemberCounts then
		return nil
	end
	local hasInfo = pcallFirst(C_LFGList.HasSearchResultInfo, resultID)
	if hasInfo == false then
		if not info and C_LFGList.GetSearchResultInfo then
			info = getSearchResultInfo(resultID)
		end
		if not info then
			return nil
		end
	end
	local counts = pcallFirst(C_LFGList.GetSearchResultMemberCounts, resultID)
	if type(counts) ~= "table" then
		return nil
	end
	if entry then
		entry._displayCounts = counts
		entry._displayCountsLoaded = true
		entry.tanks = toCountNumber(safeField(counts, "TANK"))
			or entry.tanks or 0
		entry.heals = toCountNumber(safeField(counts, "HEALER"))
			or entry.heals or 0
		entry.dps = toCountNumber(safeField(counts, "DAMAGER"))
			or entry.dps or 0
	end
	return counts
end

local function getRolePresenceFromPlayers(resultID, info, entry)
	local out = {
		TANK = false,
		HEALER = false,
		loaded = false,
		complete = false,
	}
	local players, loaded, complete = fetchSearchResultPlayers(resultID, info, entry)
	if not loaded then
		return out
	end
	out.loaded = loaded
	out.complete = complete
	for _, playerInfo in ipairs(players) do
		local role = getPlayerRole(playerInfo)
		if role == "TANK" then
			out.TANK = true
		elseif role == "HEALER" then
			out.HEALER = true
		end
	end
	return out
end

local function hasRole(counts, rolePresence, role)
	if rolePresence and rolePresence.loaded then
		if rolePresence[role] == true then
			return true
		end
		if rolePresence.complete then
			return false
		end
	end
	local count = toCountNumber(safeField(counts, role))
	if count == nil then
		return nil
	end
	return count > 0
end

local function roleRangeEnabled(client, enKey)
	if FS and FS.IsRoleRangeEnabled then
		return FS:IsRoleRangeEnabled(client, enKey)
	end
	return client and (client[enKey] == true or client[enKey] == 1)
end

local function normalizeRealmName(realm)
	if type(realm) ~= "string" or realm == "" then
		return nil
	end
	realm = realm:gsub("%s+", "")
	if realm ~= "" then
		return realm
	end
	return nil
end

local function getCurrentRealmName()
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	realm = normalizeRealmName(realm)
	if realm then
		return realm
	end
	return normalizeRealmName(GetRealmName and GetRealmName())
end

local function getNameRealm(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local _, realm = name:match("^([^-]+)%-(.+)$")
	return normalizeRealmName(realm)
end

local function isCrossRealmListing(info, entry)
	local leaderName = info and info.leaderName
	if (not leaderName or leaderName == "") and entry and entry.leader then
		leaderName = entry.leader.name
	end
	local leaderRealm = getNameRealm(leaderName)
	if not leaderRealm then
		return false
	end
	local playerRealm = getCurrentRealmName()
	if not playerRealm then
		return false
	end
	return leaderRealm ~= playerRealm
end

local function needsMemberCounts(client, spec)
	if not client or not spec then
		return false
	end
	if spec.isMythicPlusBrowse then
		return true
	end
	if client.matchMyRole and spec.showMatchRole then
		return true
	end
	if spec.hasTankHealClient and (client.hasTank or client.hasHeal or client.alreadyHasTank or client.alreadyHasHeal) then
		return true
	end
	for _, def in ipairs(ROLE_RANGE_DEFS) do
		if spec[def.show] and roleRangeEnabled(client, def.en) then
			return true
		end
	end
	if spec.showRaidRoleCounts then
		for _, def in ipairs(RAID_ROLE_COUNT_DEFS) do
			if isClientFilterEnabled(client, def.en) then
				return true
			end
		end
	end
	return false
end

local function checkRemainingRanges(counts, client, spec)
	if not counts or not client then
		return true
	end
	for _, def in ipairs(ROLE_RANGE_DEFS) do
		if spec[def.show] and roleRangeEnabled(client, def.en) then
			if not roleVacancyMeetsThreshold(
				safeField(counts, def.remaining), client[def.min])
			then
				return false
			end
		end
	end
	return true
end

local function resolveLocalSpecRole()
	local specIndex = GetSpecialization and GetSpecialization()
	if not specIndex then
		return nil
	end
	if GetSpecializationRole then
		return GetSpecializationRole(specIndex)
	end
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole then
		return C_SpecializationInfo.GetSpecializationRole(specIndex)
	end
	return nil
end

local ROLE_REMAINING_KEY = {
	TANK = "TANK_REMAINING",
	HEALER = "HEALER_REMAINING",
	DAMAGER = "DAMAGER_REMAINING",
}

local function isRoleAvailable(role)
	if not C_LFGList or not C_LFGList.GetAvailableRoles then
		return true
	end
	local ok, wantTank, wantHeal, wantDps = pcall(C_LFGList.GetAvailableRoles)
	if not ok then
		return true
	end
	if role == "TANK" then
		return wantTank == true
	end
	if role == "HEALER" then
		return wantHeal == true
	end
	if role == "DAMAGER" then
		return wantDps == true
	end
	return true
end

local function checkMatchMyRole(counts)
	if not counts then
		return true
	end
	local role = resolveLocalSpecRole()
	if not role then
		return true
	end
	if not isRoleAvailable(role) then
		return false
	end
	local key = ROLE_REMAINING_KEY[role]
	if not key then
		return true
	end
	local remaining = toCountNumber(safeField(counts, key))
	if remaining == nil then
		return true
	end
	return remaining > 0
end

local function checkNeedsMyClass(resultID, info, entry, counts)
	local role = resolveLocalSpecRole()
	local _, myClass = UnitClass("player")
	if not role or not myClass then
		return true
	end
	myClass = myClass:upper()
	if not isRoleAvailable(role) then
		return false
	end
	counts = counts or fetchMemberCounts(resultID, info, entry)
	if not counts then
		return true
	end
	local key = ROLE_REMAINING_KEY[role]
	if not key then
		return true
	end
	local remaining = toCountNumber(safeField(counts, key))
	if remaining == nil then
		return true
	end
	if remaining <= 0 then
		return false
	end
	if role ~= "DAMAGER" then
		return true
	end

	local players, loaded = fetchSearchResultPlayers(resultID, info, entry)
	if not loaded then
		return true
	end
	for _, playerInfo in ipairs(players) do
		if getPlayerRole(playerInfo) == "DAMAGER" and getPlayerClass(playerInfo) == myClass then
			return false
		end
	end
	return true
end

local function evaluateRoleFilterGroup(resultID, info, entry, counts, client, spec)
	if not client or not spec then
		return true
	end
	local mode = client.roleFilterMode == "any" and "any" or "all"
	local active = 0
	local passed = 0
	local rolePresence
	local tankPresent
	local healerPresent

	local function apply(activeCondition, passFn)
		if not activeCondition then
			return true
		end
		active = active + 1
		local pass = passFn and passFn() or false
		if pass then
			passed = passed + 1
			return true
		end
		return false
	end

	local function ensureRolePresence()
		if not rolePresence then
			rolePresence = getRolePresenceFromPlayers(resultID, info, entry)
			tankPresent = hasRole(counts, rolePresence, "TANK")
			healerPresent = hasRole(counts, rolePresence, "HEALER")
		end
	end

	if not apply(client.matchMyRole and spec.showMatchRole, function()
		return checkMatchMyRole(counts)
	end) and mode ~= "any" then
		return false
	end
	if not apply(client.needsMyClass and spec.showNeedsMyClass, function()
		return checkNeedsMyClass(resultID, info, entry, counts)
	end) and mode ~= "any" then
		return false
	end

	if spec.hasTankHealClient then
		if client.hasTank or client.hasHeal or client.alreadyHasTank or client.alreadyHasHeal then
			ensureRolePresence()
		end
		if not apply(client.hasTank, function()
			return tankPresent ~= true
		end) and mode ~= "any" then
			return false
		end
		if not apply(client.hasHeal, function()
			return healerPresent ~= true
		end) and mode ~= "any" then
			return false
		end
		if not apply(client.alreadyHasTank, function()
			return tankPresent ~= false
		end) and mode ~= "any" then
			return false
		end
		if not apply(client.alreadyHasHeal, function()
			return healerPresent ~= false
		end) and mode ~= "any" then
			return false
		end
	end

	if active == 0 then
		return true
	end
	if mode == "any" then
		return passed > 0
	end
	return passed == active
end

local function evaluateRaidRoleCountGroup(counts, client, spec)
	if not (client and spec and spec.showRaidRoleCounts) then
		return true
	end
	local mode = client.roleFilterMode == "any" and "any" or "all"
	local active = 0
	local passed = 0
	for _, def in ipairs(RAID_ROLE_COUNT_DEFS) do
		if isClientFilterEnabled(client, def.en) then
			active = active + 1
			local pass = roleCountInRange(
				safeField(counts, def.count), client[def.min], client[def.max])
			if pass then
				passed = passed + 1
			elseif mode ~= "any" then
				return false
			end
		end
	end
	if active == 0 then
		return true
	end
	if mode == "any" then
		return passed > 0
	end
	return passed == active
end

local function isDeclinedStatus(status)
	return status == "declined" or status == "declined_full" or status == "declined_delisted"
end

local function resolveActivityDifficultyTier(activity)
	return GF.ActivityInfo and GF.ActivityInfo.GetDifficultyTier(activity, { includeMplus = true }) or nil
end

local function activityMatchesDifficulty(activity, normal, heroic, mythic, mplus)
	if not normal and not heroic and not mythic and not mplus then
		return true
	end
	local tier = resolveActivityDifficultyTier(activity)
	if not tier then
		return false
	end
	if tier == "normal" then
		return normal
	end
	if tier == "heroic" then
		return heroic
	end
	if tier == "mythic" then
		return mythic
	end
	if tier == "mplus" then
		return mplus
	end
	return false
end

local function addResultActivityID(out, seen, activityID)
	activityID = toCountNumber(activityID)
	if activityID and activityID > 0 and not seen[activityID] then
		seen[activityID] = true
		out[#out + 1] = activityID
	end
end

local function collectResultActivityIDs(info, entry)
	local out = {}
	local seen = {}
	if info then
		addResultActivityID(out, seen, safeField(info, "activityID"))
		local activityIDs = safeField(info, "activityIDs")
		if type(activityIDs) == "table" then
			for _, activityID in ipairs(activityIDs) do
				addResultActivityID(out, seen, activityID)
			end
		end
	end
	if entry then
		addResultActivityID(out, seen, safeField(entry, "activityID"))
	end
	return out
end

local MYTHIC_ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local MYTHIC_ROLE_REMAINING = {
	TANK = "TANK_REMAINING",
	HEALER = "HEALER_REMAINING",
	DAMAGER = "DAMAGER_REMAINING",
}
local MYTHIC_ROLE_COUNT = {
	TANK = "TANK",
	HEALER = "HEALER",
	DAMAGER = "DAMAGER",
}
local MYTHIC_PRESENCE_FILTERS = {
	{ field = "tankPresence", role = "TANK" },
	{ field = "healerPresence", role = "HEALER" },
	{ field = "damagerPresence", role = "DAMAGER" },
}

local function normalizeMythicRole(role)
	if type(role) ~= "string" or isSecretValue(role) then
		return nil
	end
	if role == "TANK" then
		return "TANK"
	end
	if role == "HEALER" or role == "HEAL" then
		return "HEALER"
	end
	if role == "DAMAGER" or role == "DPS" then
		return "DAMAGER"
	end
	return nil
end

local function safeTrue(value)
	if isSecretValue(value) then
		return false
	end
	local ok, result = pcall(function()
		return value == true
	end)
	return ok and result or false
end

local function collectApplyingUnits()
	local units = {}
	local inRaid = safeTrue(pcallFirst(IsInRaid))
	if inRaid then
		local memberCount = math.max(
			0, math.floor((toCountNumber(
				pcallFirst(GetNumGroupMembers)) or 0) + 0.0001))
		for index = 1, memberCount do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		local subgroupCount = math.max(
			0, math.floor((toCountNumber(
				pcallFirst(GetNumSubgroupMembers)) or 0) + 0.0001))
		for index = 1, subgroupCount do
			units[#units + 1] = "party" .. index
		end
	end
	if #units == 0 then
		units[1] = "player"
	end
	return units
end

local function getUnitClassFile(unit)
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, classFile = pcall(UnitClass, unit)
	if not ok or isSecretValue(classFile)
		or type(classFile) ~= "string" or classFile == ""
	then
		return nil
	end
	return classFile:upper()
end

local function getUnitAssignedRole(unit)
	local role = pcallFirst(UnitGroupRolesAssigned, unit)
	return normalizeMythicRole(role)
end

local function copyRoleOptions(source)
	local out = {}
	if type(source) ~= "table" then
		return out
	end
	for key, value in pairs(source) do
		local enabled = type(key) == "number" or value == true
		local role = normalizeMythicRole(
			type(key) == "number" and value or key)
		if enabled and role then
			out[role] = true
		end
	end
	return out
end

local function countRoleOptions(options)
	local count = 0
	for _, role in ipairs(MYTHIC_ROLE_ORDER) do
		if options and options[role] == true then
			count = count + 1
		end
	end
	return count
end

local function getLocalSelectedRoles()
	if type(GetLFGRoles) ~= "function" then
		return nil, false
	end
	local ok, _, tank, healer, damager = pcall(GetLFGRoles)
	if not ok then
		return nil, false
	end
	return {
		TANK = safeTrue(tank),
		HEALER = safeTrue(healer),
		DAMAGER = safeTrue(damager),
	}, true
end

local function constrainLocalRolesToAvailable(roles)
	if type(roles) ~= "table"
		or not (C_LFGList and C_LFGList.GetAvailableRoles)
	then
		return roles
	end
	local ok, tank, healer, damager = pcall(C_LFGList.GetAvailableRoles)
	if not ok then
		return roles
	end
	if not safeTrue(tank) then
		roles.TANK = nil
	end
	if not safeTrue(healer) then
		roles.HEALER = nil
	end
	if not safeTrue(damager) then
		roles.DAMAGER = nil
	end
	return roles
end

local function getRosterMembersByUnit()
	local byUnit = {}
	local cache = GF.MythicPlusRosterCache
	if not (cache and type(cache.GetMembers) == "function") then
		return byUnit
	end
	local ok, members = pcall(cache.GetMembers, cache)
	if not ok or type(members) ~= "table" then
		return byUnit
	end
	for _, member in ipairs(members) do
		if type(member) == "table"
			and member.isDebugTest ~= true
			and type(member.unit) == "string"
		then
			byUnit[member.unit] = member
		end
	end
	return byUnit
end

local function getRoleForSpecialization(specID, classFile)
	specID = toCountNumber(specID)
	if not specID or specID <= 0 then
		return nil
	end
	local specializationCache = GF.MythicPlusSpecializationCache
	if specializationCache and type(specializationCache.GetInfo) == "function" then
		local ok, cached = pcall(
			specializationCache.GetInfo, specializationCache, specID)
		if ok and type(cached) == "table"
			and toCountNumber(safeField(cached, "specID")) == specID
		then
			local cachedClass = safeField(cached, "classFile")
			if not classFile or not cachedClass
				or classFile == tostring(cachedClass):upper()
			then
				local role = normalizeMythicRole(
					safeField(cached, "specRole"))
				if role then
					return role
				end
			end
		end
	end
	if type(GetSpecializationInfoByID) ~= "function" then
		return nil
	end
	local ok, resolvedSpecID, _, _, _, specRole, apiClass =
		pcall(GetSpecializationInfoByID, specID)
	if not ok or toCountNumber(resolvedSpecID) ~= specID then
		return nil
	end
	if classFile and type(apiClass) == "string"
		and classFile ~= apiClass:upper()
	then
		return nil
	end
	return normalizeMythicRole(specRole)
end

local function getUnitSpecializationRole(unit, rosterMember, classFile)
	local specID = rosterMember and safeField(rosterMember, "specID")
	if unit == "player" and type(GetSpecialization) == "function" then
		local specIndex = pcallFirst(GetSpecialization)
		if specIndex and type(GetSpecializationInfo) == "function" then
			local ok, currentSpecID = pcall(GetSpecializationInfo, specIndex)
			if ok and toCountNumber(currentSpecID) then
				specID = currentSpecID
			end
		end
		if specIndex and type(GetSpecializationRole) == "function" then
			local role = normalizeMythicRole(
				pcallFirst(GetSpecializationRole, specIndex))
			if role then
				return role
			end
		end
	elseif type(GetInspectSpecialization) == "function" then
		local inspectedSpecID = pcallFirst(GetInspectSpecialization, unit)
		if toCountNumber(inspectedSpecID)
			and toCountNumber(inspectedSpecID) > 0
		then
			specID = inspectedSpecID
		end
	end
	return getRoleForSpecialization(specID, classFile)
end

local function buildApplyingParty()
	local members = {}
	local rosterByUnit = getRosterMembersByUnit()
	for _, unit in ipairs(collectApplyingUnits()) do
		local rosterMember = rosterByUnit[unit]
		local classFile = getUnitClassFile(unit)
			or (rosterMember and safeField(rosterMember, "classFile"))
		if type(classFile) == "string" then
			classFile = classFile:upper()
		else
			classFile = nil
		end
		local assignedRole = getUnitAssignedRole(unit)
		local roleOptions = {}
		local roleOptionsKnown = false
		if assignedRole then
			roleOptions[assignedRole] = true
			roleOptionsKnown = true
		elseif unit == "player" then
			local selectedRoles, loaded = getLocalSelectedRoles()
			if loaded then
				roleOptions = constrainLocalRolesToAvailable(selectedRoles)
				roleOptionsKnown = true
			end
		elseif rosterMember then
			local roleSource = safeField(rosterMember, "roleSource")
			if roleSource == "peer-selection"
				or roleSource == "local-selection"
			then
				roleOptions = copyRoleOptions(
					safeField(rosterMember, "roles"))
				roleOptionsKnown = true
			end
		end

		local specRole = getUnitSpecializationRole(
			unit, rosterMember, classFile)
		if not specRole then
			specRole = assignedRole
			if not specRole and countRoleOptions(roleOptions) == 1 then
				for _, role in ipairs(MYTHIC_ROLE_ORDER) do
					if roleOptions[role] then
						specRole = role
						break
					end
				end
			end
		end
		-- A solo character normally has no group-assigned role, and
		-- GetLFGRoles can legitimately return all false. In that case the
		-- current specialization role is the usable application role.
		if countRoleOptions(roleOptions) == 0 then
			if specRole then
				roleOptions[specRole] = true
				roleOptionsKnown = true
			else
				roleOptionsKnown = false
			end
		end
		members[#members + 1] = {
			unit = unit,
			classFile = classFile,
			assignedRole = assignedRole,
			roleOptions = roleOptions,
			roleOptionsKnown = roleOptionsKnown,
			specRole = specRole,
		}
	end
	return {
		members = members,
		size = #members,
	}
end

local function getApplyingParty()
	local filter = GF.MythicPlusBrowseFilter
	local revision = filter and filter.GetRevision
		and filter:GetRevision() or -1
	if LF._mythicPlusParty
		and LF._mythicPlusPartyRevision == revision
	then
		return LF._mythicPlusParty
	end
	LF._mythicPlusParty = buildApplyingParty()
	LF._mythicPlusPartyRevision = revision
	return LF._mythicPlusParty
end

local function roleOptionsAsArray(options)
	local out = {}
	for _, role in ipairs(MYTHIC_ROLE_ORDER) do
		if options and options[role] == true then
			out[#out + 1] = role
		end
	end
	return out
end

local function canAssignPartyRoles(counts, party, mode)
	local requirements = {}
	for _, member in ipairs(party and party.members or {}) do
		local options
		local known
		if mode == "spec" then
			known = member.specRole ~= nil
			options = known and { member.specRole } or {}
		else
			known = member.roleOptionsKnown == true
			options = roleOptionsAsArray(member.roleOptions)
		end
		if known then
			if #options == 0 then
				return false
			end
			requirements[#requirements + 1] = options
		end
	end
	if #requirements == 0 then
		return true
	end
	table.sort(requirements, function(left, right)
		return #left < #right
	end)

	local capacities = {}
	for _, role in ipairs(MYTHIC_ROLE_ORDER) do
		local remaining = toCountNumber(
			safeField(counts, MYTHIC_ROLE_REMAINING[role]))
		if remaining == nil then
			-- Unknown capacity is intentionally unbounded for this small
			-- assignment. Known zero/full roles can still reject a result.
			capacities[role] = #requirements
		else
			capacities[role] = math.max(
				0, math.floor(remaining + 0.0001))
		end
	end

	local function assign(index)
		if index > #requirements then
			return true
		end
		for _, role in ipairs(requirements[index]) do
			if (capacities[role] or 0) > 0 then
				capacities[role] = capacities[role] - 1
				if assign(index + 1) then
					return true
				end
				capacities[role] = capacities[role] + 1
			end
		end
		return false
	end
	return assign(1)
end

local function getResultOpenSlots(info, entry, activity)
	local maxPlayers = toCountNumber(safeField(activity, "maxNumPlayers"))
	if not maxPlayers then
		for _, activityID in ipairs(collectResultActivityIDs(info, entry)) do
			local activityInfo = getActivityInfoForResult(info, activityID)
			maxPlayers = toCountNumber(
				safeField(activityInfo, "maxNumPlayers"))
			if maxPlayers and maxPlayers > 0 then
				break
			end
		end
	end
	local memberCount = toCountNumber(safeField(info, "numMembers"))
	if maxPlayers and maxPlayers > 0 and memberCount then
		return math.max(
			0, math.floor(maxPlayers - memberCount + 0.0001))
	end
	return nil
end

local function matchesMythicDungeonSelection(info, entry)
	local filter = GF.MythicPlusBrowseFilter
	if not (filter and type(filter.GetSelectedActivityIDs) == "function") then
		return true
	end
	local ok, selectedActivityIDs = pcall(
		filter.GetSelectedActivityIDs, filter)
	if not ok or type(selectedActivityIDs) ~= "table" then
		return true
	end
	if #selectedActivityIDs == 0 then
		return false
	end
	local selected = {}
	for _, activityID in ipairs(selectedActivityIDs) do
		activityID = toCountNumber(activityID)
		if activityID then
			selected[activityID] = true
		end
	end
	local resultActivityIDs = collectResultActivityIDs(info, entry)
	if #resultActivityIDs == 0 then
		return true
	end
	for _, activityID in ipairs(resultActivityIDs) do
		if selected[activityID] then
			return true
		end
	end
	return false
end

local function matchesMythicRolePresence(counts, client)
	for _, definition in ipairs(MYTHIC_PRESENCE_FILTERS) do
		local mode = client and client[definition.field]
		if mode == "missing" or mode == "existing" then
			local key = mode == "missing"
				and MYTHIC_ROLE_REMAINING[definition.role]
				or MYTHIC_ROLE_COUNT[definition.role]
			local count = toCountNumber(safeField(counts, key))
			if count ~= nil and count <= 0 then
				return false
			end
		end
	end
	return true
end

local function evaluateMythicPlusBrowse(
	resultID, info, entry, activity, counts, client)
	if not matchesMythicDungeonSelection(info, entry) then
		return false
	end

	local leaderScoreMin = math.max(
		0, math.floor((toCountNumber(client.leaderScoreMin) or 0) + 0.5))
	if leaderScoreMin > 0 then
		local rawLeaderScore, scoreState = readField(
			info, "leaderOverallDungeonScore")
		local leaderScore = toCountNumber(rawLeaderScore)
		if scoreState == "missing" then
			leaderScore = 0
		end
		-- The requested threshold is exclusive: equal scores do not pass.
		if leaderScore ~= nil and leaderScore <= leaderScoreMin then
			return false
		end
	end

	if not matchesMythicRolePresence(counts, client) then
		return false
	end

	local openSlots = getResultOpenSlots(info, entry, activity)
	local minOpenSlots = math.max(1, math.min(
		4, math.floor((toCountNumber(client.minOpenSlots) or 1) + 0.5)))
	if openSlots ~= nil and openSlots < minOpenSlots then
		return false
	end

	if client.matchPartyRoles == true or client.matchPartySpecs == true then
		local party = getApplyingParty()
		if party.size > 5 then
			return false
		end
		if openSlots ~= nil and openSlots < party.size then
			return false
		end
		if client.matchPartyRoles == true
			and not canAssignPartyRoles(counts, party, "roles")
		then
			return false
		end
		if client.matchPartySpecs == true
			and not canAssignPartyRoles(counts, party, "spec")
		then
			return false
		end
	end
	return true
end

function LF:IsEnabled()
	-- Advanced filter rules are part of the shared result pipeline and no
	-- longer expose a user-facing master switch.
	return true
end

function LF:ShouldShowResult(resultID, entry, spec, client, db, info)
	info = info or (entry and entry.info) or getSearchResultInfo(resultID)
	if not info then
		return false
	end

	if not self:IsEnabled() then
		return true
	end

	if not spec and GF.FilterSpec and GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		spec = GF.FilterSpec:ResolveSpec(GF.FindGroupTab:GetSelection())
	end
	db = db or (GF.Filter and GF.Filter.GetGlobalFilters and GF.Filter:GetGlobalFilters(spec)) or GF.GetDB()

	if GF.Filter and not GF.Filter:MatchesPlaystyleFilter(db, info.generalPlaystyle) then
		return false
	end

	if spec and spec.showDungeonActivities and GF.Filter then
		local dungeonItems = GF.Filter.GetDungeonActivityItems and GF.Filter:GetDungeonActivityItems()
		if not GF.Filter:HasActiveDungeonActivityFilter(nil, dungeonItems) then
			dungeonItems = nil
		end
		if dungeonItems then
			if not GF.Filter:MatchesDungeonActivityFilter(nil, collectResultActivityIDs(info, entry), dungeonItems) then
				return false
			end
		end
	end

	if spec and spec.showRaidActivities and GF.Filter then
		local raidItems = GF.Filter.GetRaidActivityItems and GF.Filter:GetRaidActivityItems()
		if not GF.Filter:HasActiveRaidActivityFilter(nil, raidItems) then
			raidItems = nil
		end
		if raidItems then
			if not GF.Filter:MatchesRaidActivityFilter(nil, collectResultActivityIDs(info, entry), raidItems) then
				return false
			end
		end
	end

	if not spec then
		return true
	end

	local categoryID = safeField(entry, "categoryID")
	local activity = safeField(entry, "activity")
	local resultActivityIDs = collectResultActivityIDs(info, entry)
	if not categoryID and resultActivityIDs[1] then
		activity = activity
			or getActivityInfoForResult(info, resultActivityIDs[1])
		categoryID = safeField(activity, "categoryID")
	end

	-- 全局
	if spec.runGlobalClient then
		if db.zeroScore then
			local score = info.leaderOverallDungeonScore or 0
			if score < 1 then
				return false
			end
		end
		if db.rangeAgeEn then
			local ageMin = (info.age or 0) / 60
			if not inRange(ageMin, db.rangeAgeMin, db.rangeAgeMax) then
				return false
			end
		elseif db.maxAgeMin and db.maxAgeMin > 0 then
			if (info.age or 0) > db.maxAgeMin * 60 then
				return false
			end
		end
		if db.rangeIlvlEn then
			if not inRange(info.requiredItemLevel or 0, db.rangeIlvlMin, db.rangeIlvlMax) then
				return false
			end
		elseif db.minIlvl and db.minIlvl > 0 then
			if (info.requiredItemLevel or 0) > db.minIlvl then
				return false
			end
		end
		if db.rangeHonorEn and spec.showMinHonor then
			if not inRange(info.requiredHonorLevel or 0, db.rangeHonorMin, db.rangeHonorMax) then
				return false
			end
		end
		if db.hideVoice and (info.voiceChat or "") ~= "" then
			return false
		end
		if db.hideCrossRealm and isCrossRealmListing(info, entry) then
			return false
		end
		if db.sameFactionOnly and info.crossFactionListing == true then
			return false
		end
		if db.showFriendGroups == false and GF.FindGroup and GF.FindGroup:IsFriendListing(info, resultID) then
			return false
		end
		if db.showGuildGroups == false and GF.FindGroup and GF.FindGroup:IsGuildListing(info, resultID) then
			return false
		end
		if db.showHousewarmingGroups == false and GF.ACTIVITY_HOUSEWARMING then
			local actID = info.activityIDs and info.activityIDs[1]
			if actID == GF.ACTIVITY_HOUSEWARMING then
				return false
			end
		end
		if db.rangeMplusScoreEn then
			local score = info.leaderOverallDungeonScore or 0
			if not inRange(score, db.rangeMplusScoreMin, db.rangeMplusScoreMax) then
				return false
			end
		end
	end

	if not spec.runCategoryClient then
		if spec.runGlobalClient and db.sameClass and SAME_CLASS_CATS[categoryID] then
			return self:CheckSameClass(resultID, categoryID)
		end
		return true
	end

	if not client and spec.isMythicPlusBrowse
		and GF.MythicPlusBrowseFilter
		and GF.MythicPlusBrowseFilter.GetClientFilters
	then
		client = GF.MythicPlusBrowseFilter:GetClientFilters()
	end
	client = client or GF.Filter:GetClientFilters(spec.clientKey)

	local counts
	if needsMemberCounts(client, spec) then
		counts = fetchMemberCounts(resultID, info, entry)
	end

	if spec.isMythicPlusBrowse
		and not evaluateMythicPlusBrowse(
			resultID, info, entry, activity, counts, client)
	then
		return false
	end

	if counts and not checkRemainingRanges(counts, client, spec) then
		return false
	end

	if not evaluateRoleFilterGroup(resultID, info, entry, counts, client, spec) then
		return false
	end

	if not evaluateRaidRoleCountGroup(counts, client, spec) then
		return false
	end

	if spec.showRaidMemberCount and isClientFilterEnabled(client, "raidMemberCountEn") then
		if not inRange(info.numMembers, client.raidMemberCountMin, client.raidMemberCountMax) then
			return false
		end
	end

	if spec.showRaidBossKills and isClientFilterEnabled(client, "raidBossKillsEn") then
		local completedEncounters = getCompletedEncounterCount(resultID)
		if not inRange(completedEncounters, client.raidBossKillsMin, client.raidBossKillsMax) then
			return false
		end
	end

	if client.notDeclined and spec.showNotDeclined and C_LFGList and C_LFGList.GetApplicationInfo then
		local skipDeclinedCheck = GF.Apply and GF.Apply.IsFreshReject
			and GF.Apply:IsFreshReject(resultID)
		if not skipDeclinedCheck then
			local ok, _, appStatus = pcall(C_LFGList.GetApplicationInfo, resultID)
			if not ok then
				appStatus = nil
			end
			if isDeclinedStatus(appStatus) then
				return false
			end
		end
	end

	local blMode = client.bloodlustMode or 0
	if blMode > 0 and spec.showBloodlust then
		local targetBL = resultHasBloodlust(resultID, info, entry)
		if blMode == 1 and targetBL == false then
			return false
		elseif blMode == 2 and targetBL == true then
			return false
		end
	end

	if spec.showDungeonDifficulty and client.dungeonDiffEn then
		if not activityMatchesDifficulty(activity,
			client.dungeonDifficultyNormal,
			client.dungeonDifficultyHeroic,
			client.dungeonDifficultyMythic,
			client.dungeonDifficultyMythicPlus) then
			return false
		end
	end

	if spec.showRaidDifficulty and client.raidDiffEn then
		if not activityMatchesDifficulty(activity,
			client.raidDifficultyNormal,
			client.raidDifficultyHeroic,
			client.raidDifficultyMythic,
			false) then
			return false
		end
	end

	if client.warmodeOnly and spec.showWarmode then
		if info.isWarMode ~= true then
			return false
		end
	end

	if db.sameClass and spec.showSameClass and SAME_CLASS_CATS[categoryID] then
		if not self:CheckSameClass(resultID, categoryID) then
			return false
		end
	end

	return true
end

function LF:CheckSameClass(resultID, categoryID)
	if not SAME_CLASS_CATS[categoryID] then
		return true
	end
	local _, myClass = UnitClass("player")
	if not myClass then
		return true
	end
	myClass = myClass:upper()
	local info = getSearchResultInfo(resultID)
	if not info then
		return true
	end
	local players, loaded = fetchSearchResultPlayers(resultID, info)
	if not loaded then
		return true
	end
	for _, playerInfo in ipairs(players) do
		if getPlayerRole(playerInfo) == "DAMAGER" and getPlayerClass(playerInfo) == myClass then
			return false
		end
	end
	return true
end

function LF:NeedsPostFilters(spec, client, db)
	if GF.FilterSpec then
		return GF.FilterSpec:NeedsPostFilter(spec, client, db)
	end
	return false
end
