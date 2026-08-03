local _, GF = ...

local Pipeline = {}
GF.ListFilter = Pipeline

local FilterSpec = GF.FilterSpec

local function snapshotService()
	-- The TOC loads the snapshot module after this file. Resolve it at call
	-- time so the pipeline does not capture the pre-load nil value.
	return GF.SearchResultSnapshot
end

local BLOODLUST_CLASSES = {
	EVOKER = true,
	HUNTER = true,
	MAGE = true,
	SHAMAN = true,
}

local SAME_CLASS_CATEGORIES = {}
for _, categoryID in ipairs({ GF.CAT_DUNGEON, GF.CAT_DELVE, GF.CAT_RAID }) do
	SAME_CLASS_CATEGORIES[categoryID] = true
end

local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local ROLE_COUNTS = {
	TANK = "TANK",
	HEALER = "HEALER",
	DAMAGER = "DAMAGER",
}
local ROLE_VACANCIES = {
	TANK = "TANK_REMAINING",
	HEALER = "HEALER_REMAINING",
	DAMAGER = "DAMAGER_REMAINING",
}

function GF.HasBloodlustClass(classFile)
	if type(classFile) ~= "string" then
		return false
	end
	local ok, normalized = pcall(string.upper, classFile)
	return ok and BLOODLUST_CLASSES[normalized] == true
end

local function secret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, result = pcall(issecretvalue, value)
	return ok and result == true
end

local function read(owner, key)
	local snapshot = snapshotService()
	if snapshot and type(snapshot.ReadField) == "function" then
		return snapshot.ReadField(owner, key)
	end
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	if type(issecretvaluekey) == "function" then
		local ok, protected = pcall(issecretvaluekey, owner, key)
		if ok and protected == true then
			return nil, "secret"
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	elseif secret(value) then
		return nil, "secret"
	elseif value == nil then
		return nil, "missing"
	end
	return value, "value"
end

local function number(value)
	local snapshot = snapshotService()
	if snapshot and type(snapshot.ToNumber) == "function" then
		return snapshot.ToNumber(value)
	end
	if value == nil or secret(value) then
		return nil
	end
	local ok, converted = pcall(tonumber, value)
	return ok and converted or nil
end

local function invoke(fn, ...)
	if type(fn) ~= "function" then
		return nil, false
	end
	local ok, value = pcall(fn, ...)
	return ok and value or nil, ok
end

local function enabled(value)
	return value == true or value == 1
end

local function normalizeRole(role)
	if type(role) ~= "string" or secret(role) then
		return nil
	end
	role = role:upper()
	if role == "HEAL" then
		return "HEALER"
	elseif role == "DPS" then
		return "DAMAGER"
	elseif role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		return role
	end
	return nil
end

local function playerRole(player)
	return normalizeRole(read(player, "assignedRole"))
		or normalizeRole(read(player, "role"))
end

local function playerClass(player)
	local value = read(player, "classFilename")
		or read(player, "classFileName")
		or read(player, "classFile")
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return value:upper()
end

local ResultContext = {}
ResultContext.__index = ResultContext

function ResultContext:New(resultID, entry, info)
	if type(info) ~= "table" and type(entry) == "table" then
		info = read(entry, "info")
	end
	local snapshot = snapshotService()
	if type(info) ~= "table" and snapshot
		and type(snapshot.GetSearchResultInfo) == "function"
	then
		info = snapshot.GetSearchResultInfo(resultID)
	end
	return setmetatable({
		resultID = resultID,
		entry = type(entry) == "table" and entry or nil,
		info = type(info) == "table" and info or nil,
	}, self)
end

function ResultContext:ActivityIDs()
	if not self.activityIDs then
		local snapshot = snapshotService()
		if snapshot and type(snapshot.GetActivityIDs) == "function" then
			self.activityIDs = snapshot.GetActivityIDs(self.info, self.entry)
		else
			self.activityIDs = {}
		end
	end
	return self.activityIDs
end

function ResultContext:Activity()
	if self.activityResolved then
		return self.activity
	end
	self.activityResolved = true
	local activity = read(self.entry, "activity")
	local snapshot = snapshotService()
	if type(activity) ~= "table" and snapshot
		and type(snapshot.GetActivityInfo) == "function"
	then
		activity = snapshot.GetActivityInfo(self.info, self:ActivityIDs()[1])
	end
	self.activity = type(activity) == "table" and activity or nil
	return self.activity
end

function ResultContext:CategoryID()
	if self.categoryResolved then
		return self.categoryID
	end
	self.categoryResolved = true
	local categoryID = number(read(self.entry, "categoryID"))
	if not categoryID then
		categoryID = number(read(self:Activity(), "categoryID"))
	end
	local snapshot = snapshotService()
	if not categoryID and snapshot
		and type(snapshot.ResolveActivityCategory) == "function"
	then
		categoryID = snapshot.ResolveActivityCategory(self:ActivityIDs()[1])
	end
	self.categoryID = categoryID
	return categoryID
end

function ResultContext:Counts()
	if self.countsResolved then
		return self.counts
	end
	self.countsResolved = true
	local cached = read(self.entry, "_displayCounts")
	local loaded = read(self.entry, "_displayCountsLoaded")
	if loaded == true and type(cached) == "table" then
		self.counts = cached
	else
		local snapshot = snapshotService()
		if snapshot and type(snapshot.GetMemberCounts) == "function" then
		-- Filtering is read-only. Display hydration, when needed, belongs to
		-- the result renderer rather than to this predicate pipeline.
			self.counts = snapshot.GetMemberCounts(self.resultID)
		end
	end
	return self.counts
end

function ResultContext:Players()
	if self.playersResolved then
		return self.players, self.playersComplete
	end
	self.playersResolved = true
	local snapshot = snapshotService()
	if snapshot and type(snapshot.GetPlayers) == "function" then
		self.players, self.playersComplete = snapshot.GetPlayers(
			self.resultID, self.info, self.entry)
	end
	return self.players, self.playersComplete == true
end

function ResultContext:OpenSlots()
	if not self.openSlotsResolved then
		self.openSlotsResolved = true
		local snapshot = snapshotService()
		if snapshot and type(snapshot.GetOpenSlots) == "function" then
			self.openSlots = snapshot.GetOpenSlots(self.info, self:Activity())
		end
	end
	return self.openSlots
end

function ResultContext:CompletedEncounters()
	if not self.encountersResolved then
		self.encountersResolved = true
		local snapshot = snapshotService()
		if snapshot and type(snapshot.GetCompletedEncounterCount) == "function" then
			self.completedEncounters = snapshot.GetCompletedEncounterCount(self.resultID)
		end
	end
	return self.completedEncounters
end

local function numericField(owner, key, missingValue)
	local raw, state = read(owner, key)
	if state == "value" then
		return number(raw), "value"
	elseif state == "missing" and missingValue ~= nil then
		return missingValue, "missing"
	end
	return nil, state
end

local function inclusiveRange(value, minimum, maximum)
	if value == nil then
		return true
	end
	minimum = number(minimum) or 0
	maximum = number(maximum) or 0
	return (minimum <= 0 or value >= minimum)
		and (maximum <= 0 or value <= maximum)
end

local function exactZeroOrRange(value, minimum, maximum)
	if value == nil then
		return true
	end
	minimum = math.max(0, math.floor((number(minimum) or 0) + 0.0001))
	maximum = math.max(0, math.floor((number(maximum) or 0) + 0.0001))
	if minimum == 0 and maximum == 0 then
		return value == 0
	end
	return (minimum <= 0 or value >= minimum)
		and (maximum <= 0 or value <= maximum)
end

local function selectedDifficultyMatches(activity, choices)
	local any = false
	for _, selected in pairs(choices) do
		any = any or selected == true
	end
	if not any then
		return true
	end
	if not (GF.ActivityInfo and type(GF.ActivityInfo.GetDifficultyTier) == "function") then
		return true
	end
	local ok, tier = pcall(
		GF.ActivityInfo.GetDifficultyTier, activity, { includeMplus = true })
	if not ok then
		return true
	end
	return tier ~= nil and choices[tier] == true
end

local function normalizedRealm(value)
	if type(value) ~= "string" or value == "" or secret(value) then
		return nil
	end
	local ok, normalized = pcall(function()
		return value:gsub("%s+", ""):lower()
	end)
	return ok and normalized ~= "" and normalized or nil
end

local function currentRealm()
	local value = invoke(GetNormalizedRealmName)
	return normalizedRealm(value)
		or normalizedRealm(invoke(GetRealmName))
end

local function currentFactionTag()
	local value, ok = invoke(UnitFactionGroup, "player")
	if not ok or secret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function factionTagForIndex(value)
	local index = number(value)
	if index == nil or type(PLAYER_FACTION_GROUP) ~= "table" then
		return nil
	end
	local ok, tag = pcall(function()
		return PLAYER_FACTION_GROUP[index]
	end)
	if not ok or secret(tag) or type(tag) ~= "string" or tag == "" then
		return nil
	end
	return tag
end

local function listingRealm(context)
	local leader = read(context.info, "leaderName")
	if type(leader) ~= "string" or leader == "" then
		local leaderInfo = read(context.entry, "leader")
		leader = read(leaderInfo, "name")
	end
	if type(leader) ~= "string" then
		return nil
	end
	return normalizedRealm(leader:match("^[^-]+%-(.+)$"))
end

local function methodTrue(owner, name, ...)
	local method = owner and owner[name]
	if type(method) ~= "function" then
		return false
	end
	local ok, value = pcall(method, owner, ...)
	return ok and value == true
end

local function passesGlobal(context, spec, settings)
	if type(settings) ~= "table" then
		return true
	end

	local score, scoreState = numericField(
		context.info, "leaderOverallDungeonScore", 0)
	if settings.zeroScore and scoreState ~= "secret" and scoreState ~= "error"
		and score ~= nil and score < 1
	then
		return false
	end

	local age = numericField(context.info, "age", 0)
	if enabled(settings.rangeAgeEn) then
		if not inclusiveRange(
			age and age / 60, settings.rangeAgeMin, settings.rangeAgeMax)
		then
			return false
		end
	elseif (number(settings.maxAgeMin) or 0) > 0
		and age ~= nil and age > number(settings.maxAgeMin) * 60
	then
		return false
	end

	local itemLevel = numericField(context.info, "requiredItemLevel", 0)
	if enabled(settings.rangeIlvlEn) then
		if not inclusiveRange(
			itemLevel, settings.rangeIlvlMin, settings.rangeIlvlMax)
		then
			return false
		end
	elseif (number(settings.minIlvl) or 0) > 0
		and itemLevel ~= nil and itemLevel > number(settings.minIlvl)
	then
		return false
	end

	if spec.showMinHonor and enabled(settings.rangeHonorEn) then
		local honor = numericField(context.info, "requiredHonorLevel", 0)
		if not inclusiveRange(
			honor, settings.rangeHonorMin, settings.rangeHonorMax)
		then
			return false
		end
	end

	if enabled(settings.rangeMplusScoreEn)
		and not inclusiveRange(
			score, settings.rangeMplusScoreMin, settings.rangeMplusScoreMax)
	then
		return false
	end

	if settings.hideVoice then
		local voice, state = read(context.info, "voiceChat")
		if state == "value" and type(voice) == "string" and voice ~= "" then
			return false
		end
	end

	if settings.hideCrossRealm then
		local remote, localRealm = listingRealm(context), currentRealm()
		if remote and localRealm and remote ~= localRealm then
			return false
		end
	end

	if settings.sameFactionOnly then
		local crossFaction, state = read(context.info, "crossFactionListing")
		if state == "value" and crossFaction == true then
			return false
		end
		local leaderFaction, leaderState = read(context.info, "leaderFactionGroup")
		if leaderState == "value" then
			local playerTag = currentFactionTag()
			local leaderTag = factionTagForIndex(leaderFaction)
			if playerTag and leaderTag and playerTag ~= leaderTag then
				return false
			end
		end
	end

	if settings.showFriendGroups == false
		and methodTrue(GF.FindGroup, "IsFriendListing", context.info, context.resultID)
	then
		return false
	end
	if settings.showGuildGroups == false
		and methodTrue(GF.FindGroup, "IsGuildListing", context.info, context.resultID)
	then
		return false
	end

	if settings.showHousewarmingGroups == false and GF.ACTIVITY_HOUSEWARMING then
		for _, activityID in ipairs(context:ActivityIDs()) do
			if activityID == GF.ACTIVITY_HOUSEWARMING then
				return false
			end
		end
	end
	return true
end

local function localClass()
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, classFile = pcall(UnitClass, "player")
	if not ok or type(classFile) ~= "string" or secret(classFile) then
		return nil
	end
	local normalizedOK, normalized = pcall(string.upper, classFile)
	return normalizedOK and normalized or nil
end

local function localRole()
	if type(GetSpecialization) ~= "function" then
		return nil
	end
	local specIndex = invoke(GetSpecialization)
	if not specIndex then
		return nil
	end
	if type(GetSpecializationRole) == "function" then
		local role = normalizeRole(invoke(GetSpecializationRole, specIndex))
		if role then
			return role
		end
	end
	if C_SpecializationInfo
		and type(C_SpecializationInfo.GetSpecializationRole) == "function"
	then
		return normalizeRole(invoke(
			C_SpecializationInfo.GetSpecializationRole, specIndex))
	end
	return nil
end

local function availableRole(role)
	if not (C_LFGList and type(C_LFGList.GetAvailableRoles) == "function") then
		return nil
	end
	local ok, tank, healer, damager = pcall(C_LFGList.GetAvailableRoles)
	if not ok or secret(tank) or secret(healer) or secret(damager) then
		return nil
	end
	local values = { TANK = tank, HEALER = healer, DAMAGER = damager }
	return values[role] == true
end

local function countValue(counts, key)
	return number(read(counts, key))
end

local function resultRolePresence(context, role)
	local count = countValue(context:Counts(), ROLE_COUNTS[role])
	if count ~= nil then
		return count > 0
	end
	local players, complete = context:Players()
	local unreadable = false
	if type(players) == "table" then
		for _, player in ipairs(players) do
			local observed = playerRole(player)
			if observed == role then
				return true
			elseif not observed then
				unreadable = true
			end
		end
		if complete and not unreadable then
			return false
		end
	end
	return nil
end

local function matchesOwnRole(context)
	local role = localRole()
	if not role then
		return true
	end
	if availableRole(role) == false then
		return false
	end
	local vacancy = countValue(context:Counts(), ROLE_VACANCIES[role])
	return vacancy == nil or vacancy > 0
end

local function needsOwnClass(context)
	local role, classFile = localRole(), localClass()
	if not role or not classFile then
		return true
	end
	if availableRole(role) == false then
		return false
	end
	local vacancy = countValue(context:Counts(), ROLE_VACANCIES[role])
	if vacancy ~= nil and vacancy <= 0 then
		return false
	end
	if role ~= "DAMAGER" then
		return true
	end
	local players, complete = context:Players()
	if type(players) ~= "table" or not complete then
		return true
	end
	for _, player in ipairs(players) do
		if playerRole(player) == "DAMAGER" and playerClass(player) == classFile then
			return false
		end
	end
	return true
end

local function evaluateChoices(mode, choices)
	local active, passed = 0, 0
	for _, choice in ipairs(choices) do
		if choice.active then
			active = active + 1
			if choice.test() then
				passed = passed + 1
			elseif mode ~= "any" then
				return false
			end
		end
	end
	return active == 0 or (mode == "any" and passed > 0) or passed == active
end

local function passesRoleChoices(context, client, spec)
	local mode = client.roleFilterMode == "any" and "any" or "all"
	local choices = {
		{
			active = client.matchMyRole and spec.showMatchRole,
			test = function() return matchesOwnRole(context) end,
		},
		{
			active = client.needsMyClass and spec.showNeedsMyClass,
			test = function() return needsOwnClass(context) end,
		},
	}
	if spec.hasTankHealClient then
		choices[#choices + 1] = {
			active = client.hasTank,
			test = function() return resultRolePresence(context, "TANK") ~= true end,
		}
		choices[#choices + 1] = {
			active = client.hasHeal,
			test = function() return resultRolePresence(context, "HEALER") ~= true end,
		}
		choices[#choices + 1] = {
			active = client.alreadyHasTank,
			test = function() return resultRolePresence(context, "TANK") ~= false end,
		}
		choices[#choices + 1] = {
			active = client.alreadyHasHeal,
			test = function() return resultRolePresence(context, "HEALER") ~= false end,
		}
	end
	return evaluateChoices(mode, choices)
end

local VACANCY_RANGES = {
	{ visible = "showTankRange", enabled = "rangeTankEn", minimum = "rangeTankMin", role = "TANK" },
	{ visible = "showHealRange", enabled = "rangeHealEn", minimum = "rangeHealMin", role = "HEALER" },
	{ visible = "showDpsRange", enabled = "rangeDpsEn", minimum = "rangeDpsMin", role = "DAMAGER" },
}

local RAID_ROLE_RANGES = {
	{ enabled = "raidTankEn", minimum = "raidTankMin", maximum = "raidTankMax", role = "TANK" },
	{ enabled = "raidHealEn", minimum = "raidHealMin", maximum = "raidHealMax", role = "HEALER" },
	{ enabled = "raidDpsEn", minimum = "raidDpsMin", maximum = "raidDpsMax", role = "DAMAGER" },
}

local function passesVacancyRanges(context, client, spec)
	for _, range in ipairs(VACANCY_RANGES) do
		if spec[range.visible] and enabled(client[range.enabled]) then
			local minimum = math.floor((number(client[range.minimum])
				or GF.ROLE_VACANCY_THRESHOLD_MIN or 1) + 0.0001)
			minimum = math.max(GF.ROLE_VACANCY_THRESHOLD_MIN or 1,
				math.min(GF.ROLE_VACANCY_THRESHOLD_MAX or 4, minimum))
			local vacancy = countValue(context:Counts(), ROLE_VACANCIES[range.role])
			if vacancy ~= nil and vacancy < minimum then
				return false
			end
		end
	end
	return true
end

local function passesRaidRoleRanges(context, client, spec)
	if not spec.showRaidRoleCounts then
		return true
	end
	local mode = client.roleFilterMode == "any" and "any" or "all"
	local choices = {}
	for _, configuredRange in ipairs(RAID_ROLE_RANGES) do
		local range = configuredRange
		choices[#choices + 1] = {
			active = enabled(client[range.enabled]),
			test = function()
				return exactZeroOrRange(
					countValue(context:Counts(), ROLE_COUNTS[range.role]),
					client[range.minimum], client[range.maximum])
			end,
		}
	end
	return evaluateChoices(mode, choices)
end

local function applicationDeclined(resultID)
	if GF.Apply and type(GF.Apply.HasRejectionFeedback) == "function" then
		local ok, fresh = pcall(GF.Apply.HasRejectionFeedback, GF.Apply, resultID)
		if ok and fresh == true then
			return false
		end
	end
	if not (C_LFGList and type(C_LFGList.GetApplicationInfo) == "function") then
		return false
	end
	if GF.Apply and type(GF.Apply.IsDeclinedApplication) == "function" then
		local ok, declined = pcall(GF.Apply.IsDeclinedApplication, GF.Apply, resultID)
		if ok then
			return declined == true
		end
	end
	local ok, _, status = pcall(C_LFGList.GetApplicationInfo, resultID)
	return ok and (status == "declined"
		or status == "declined_full"
		or status == "declined_delisted")
end

local function bloodlustState(context)
	local players, complete = context:Players()
	if type(players) ~= "table" then
		return nil
	end
	local unreadable = false
	for _, player in ipairs(players) do
		local classFile = playerClass(player)
		if GF.HasBloodlustClass(classFile) then
			return true
		elseif not classFile then
			unreadable = true
		end
	end
	if complete and not unreadable then
		return false
	end
	return nil
end

local function selectedMythicActivitiesMatch(context)
	local service = GF.MythicPlusBrowseFilter
	if not (service and type(service.GetSelectedActivityIDs) == "function") then
		return true
	end
	local ok, selected = pcall(service.GetSelectedActivityIDs, service)
	if not ok or type(selected) ~= "table" then
		return true
	elseif #selected == 0 then
		return false
	end
	local accepted = {}
	for _, activityID in ipairs(selected) do
		activityID = number(activityID)
		if activityID then
			accepted[activityID] = true
		end
	end
	local resultIDs = context:ActivityIDs()
	if #resultIDs == 0 then
		return true
	end
	for _, activityID in ipairs(resultIDs) do
		if accepted[activityID] then
			return true
		end
	end
	return false
end

local PRESENCE_FILTERS = {
	{ key = "tankPresence", role = "TANK" },
	{ key = "healerPresence", role = "HEALER" },
	{ key = "damagerPresence", role = "DAMAGER" },
}

local function mythicPresenceMatches(context, client)
	for _, filter in ipairs(PRESENCE_FILTERS) do
		local mode = client[filter.key]
		if mode == "missing" then
			local vacancy = countValue(context:Counts(), ROLE_VACANCIES[filter.role])
			if vacancy ~= nil and vacancy <= 0 then
				return false
			end
		elseif mode == "existing" then
			local present = countValue(context:Counts(), ROLE_COUNTS[filter.role])
			if present ~= nil and present <= 0 then
				return false
			end
		end
	end
	return true
end

local function applyingUnits()
	local units = {}
	local raid = invoke(IsInRaid) == true
	if raid then
		local count = math.max(0, math.floor((number(invoke(GetNumGroupMembers)) or 0) + 0.0001))
		for index = 1, count do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		local count = math.max(0, math.floor((number(invoke(GetNumSubgroupMembers)) or 0) + 0.0001))
		for index = 1, count do
			units[#units + 1] = "party" .. index
		end
	end
	return units
end

local function rosterByUnit()
	local result = {}
	local cache = GF.MythicPlusRosterCache
	if not (cache and type(cache.GetMembers) == "function") then
		return result
	end
	local ok, members = pcall(cache.GetMembers, cache)
	if not ok or type(members) ~= "table" then
		return result
	end
	for _, member in ipairs(members) do
		local unit = read(member, "unit")
		if type(unit) == "string" and read(member, "isDebugTest") ~= true then
			result[unit] = member
		end
	end
	return result
end

local function unitClass(unit)
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, classFile = pcall(UnitClass, unit)
	if not ok or secret(classFile) or type(classFile) ~= "string" then
		return nil
	end
	return classFile:upper()
end

local function copyRoles(source)
	local roles = {}
	if type(source) ~= "table" then
		return roles
	end
	for key, value in pairs(source) do
		local role = normalizeRole(type(key) == "number" and value or key)
		if role and (type(key) == "number" or value == true) then
			roles[role] = true
		end
	end
	return roles
end

local function selectedLocalRoles()
	if type(GetLFGRoles) ~= "function" then
		return nil
	end
	local ok, _, tank, healer, damager = pcall(GetLFGRoles)
	if not ok or secret(tank) or secret(healer) or secret(damager) then
		return nil
	end
	local roles = {
		TANK = tank == true,
		HEALER = healer == true,
		DAMAGER = damager == true,
	}
	if C_LFGList and type(C_LFGList.GetAvailableRoles) == "function" then
		local roleOK, canTank, canHeal, canDamage = pcall(C_LFGList.GetAvailableRoles)
		if roleOK and not secret(canTank) and not secret(canHeal) and not secret(canDamage) then
			roles.TANK = roles.TANK and canTank == true
			roles.HEALER = roles.HEALER and canHeal == true
			roles.DAMAGER = roles.DAMAGER and canDamage == true
		end
	end
	return roles
end

local function roleCount(options)
	local total = 0
	for _, role in ipairs(ROLE_ORDER) do
		if options and options[role] == true then
			total = total + 1
		end
	end
	return total
end

local function specializationRole(specID, classFile)
	specID = number(specID)
	if not specID or specID <= 0 then
		return nil
	end
	local cache = GF.MythicPlusSpecializationCache
	if cache and type(cache.GetInfo) == "function" then
		local ok, info = pcall(cache.GetInfo, cache, specID)
		if ok and type(info) == "table" and number(read(info, "specID")) == specID then
			local cachedClass = read(info, "classFile")
			if not classFile or not cachedClass
				or classFile == tostring(cachedClass):upper()
			then
				local role = normalizeRole(read(info, "specRole"))
				if role then
					return role
				end
			end
		end
	end
	if type(GetSpecializationInfoByID) ~= "function" then
		return nil
	end
	local ok, resolvedID, _, _, _, role, apiClass = pcall(
		GetSpecializationInfoByID, specID)
	if not ok or number(resolvedID) ~= specID then
		return nil
	end
	if classFile and type(apiClass) == "string" then
		if secret(apiClass) then
			return nil
		end
		local normalizedOK, normalized = pcall(string.upper, apiClass)
		if not normalizedOK or normalized ~= classFile then
			return nil
		end
	end
	return normalizeRole(role)
end

local function unitSpecializationRole(unit, rosterMember, classFile)
	local specID = read(rosterMember, "specID")
	if unit == "player" then
		local index = invoke(GetSpecialization)
		if index and type(GetSpecializationRole) == "function" then
			local role = normalizeRole(invoke(GetSpecializationRole, index))
			if role then
				return role
			end
		end
		if index and type(GetSpecializationInfo) == "function" then
			local ok, currentID = pcall(GetSpecializationInfo, index)
			if ok and number(currentID) then
				specID = currentID
			end
		end
	elseif type(GetInspectSpecialization) == "function" then
		local inspected = number(invoke(GetInspectSpecialization, unit))
		if inspected and inspected > 0 then
			specID = inspected
		end
	end
	return specializationRole(specID, classFile)
end

local function buildApplyingParty()
	local members, cachedMembers = {}, rosterByUnit()
	for _, unit in ipairs(applyingUnits()) do
		local cached = cachedMembers[unit]
		local classFile = unitClass(unit)
		local cachedClass = read(cached, "classFile")
		if not classFile and type(cachedClass) == "string" then
			classFile = cachedClass:upper()
		end
		local assigned = normalizeRole(invoke(UnitGroupRolesAssigned, unit))
		local options, optionsKnown = {}, false
		if assigned then
			options[assigned], optionsKnown = true, true
		elseif unit == "player" then
			options = selectedLocalRoles() or {}
			optionsKnown = roleCount(options) > 0
		elseif cached then
			local source = read(cached, "roleSource")
			if source == "peer-selection" or source == "local-selection" then
				options = copyRoles(read(cached, "roles"))
				optionsKnown = roleCount(options) > 0
			end
		end

		local fixedRole = unitSpecializationRole(unit, cached, classFile) or assigned
		if not fixedRole and roleCount(options) == 1 then
			for _, role in ipairs(ROLE_ORDER) do
				if options[role] then
					fixedRole = role
					break
				end
			end
		end
		if roleCount(options) == 0 and fixedRole then
			options[fixedRole], optionsKnown = true, true
		end
		members[#members + 1] = {
			options = options,
			optionsKnown = optionsKnown,
			specializationRole = fixedRole,
		}
	end
	return { members = members, size = #members }
end

local function applyingParty()
	local service = GF.MythicPlusBrowseFilter
	local revision = service and type(service.GetRevision) == "function"
		and invoke(service.GetRevision, service) or -1
	if Pipeline.partyCache and Pipeline.partyCacheRevision == revision then
		return Pipeline.partyCache
	end
	Pipeline.partyCache = buildApplyingParty()
	Pipeline.partyCacheRevision = revision
	return Pipeline.partyCache
end

local function roleArray(options)
	local list = {}
	for _, role in ipairs(ROLE_ORDER) do
		if options and options[role] then
			list[#list + 1] = role
		end
	end
	return list
end

local function partyFitsVacancies(counts, party, fixedToSpec)
	local requests = {}
	for _, member in ipairs(party.members) do
		local choices
		if fixedToSpec then
			choices = member.specializationRole and { member.specializationRole } or nil
		elseif member.optionsKnown then
			choices = roleArray(member.options)
		end
		if choices then
			if #choices == 0 then
				return false
			end
			requests[#requests + 1] = choices
		end
	end
	if #requests == 0 then
		return true
	end
	table.sort(requests, function(left, right) return #left < #right end)

	local capacity = {}
	for _, role in ipairs(ROLE_ORDER) do
		local available = countValue(counts, ROLE_VACANCIES[role])
		capacity[role] = available == nil and #requests
			or math.max(0, math.floor(available + 0.0001))
	end
	local function place(index)
		if index > #requests then
			return true
		end
		for _, role in ipairs(requests[index]) do
			if (capacity[role] or 0) > 0 then
				capacity[role] = capacity[role] - 1
				if place(index + 1) then
					return true
				end
				capacity[role] = capacity[role] + 1
			end
		end
		return false
	end
	return place(1)
end

local function passesMythicPlus(context, client)
	if not selectedMythicActivitiesMatch(context) then
		return false
	end
	local minimumScore = math.max(0,
		math.floor((number(client.leaderScoreMin) or 0) + 0.5))
	if minimumScore > 0 then
		local score, state = numericField(
			context.info, "leaderOverallDungeonScore", 0)
		if state ~= "secret" and state ~= "error"
			and score ~= nil and score <= minimumScore
		then
			return false
		end
	end
	if not mythicPresenceMatches(context, client) then
		return false
	end
	local slots = context:OpenSlots()
	local minimumSlots = math.max(1, math.min(4,
		math.floor((number(client.minOpenSlots) or 1) + 0.5)))
	if slots ~= nil and slots < minimumSlots then
		return false
	end
	if client.matchPartyRoles == true or client.matchPartySpecs == true then
		local party = applyingParty()
		if party.size > 5 or (slots ~= nil and slots < party.size) then
			return false
		end
		if client.matchPartyRoles == true
			and not partyFitsVacancies(context:Counts(), party, false)
		then
			return false
		end
		if client.matchPartySpecs == true
			and not partyFitsVacancies(context:Counts(), party, true)
		then
			return false
		end
	end
	return true
end

local function passesCategory(context, spec, client)
	if spec.isMythicPlusBrowse and not passesMythicPlus(context, client) then
		return false
	end
	if not passesVacancyRanges(context, client, spec)
		or not passesRoleChoices(context, client, spec)
		or not passesRaidRoleRanges(context, client, spec)
	then
		return false
	end
	if spec.showRaidMemberCount and enabled(client.raidMemberCountEn) then
		local members = numericField(context.info, "numMembers", 0)
		if not inclusiveRange(
			members, client.raidMemberCountMin, client.raidMemberCountMax)
		then
			return false
		end
	end
	if spec.showRaidBossKills and enabled(client.raidBossKillsEn)
		and not inclusiveRange(context:CompletedEncounters(),
			client.raidBossKillsMin, client.raidBossKillsMax)
	then
		return false
	end
	if client.notDeclined and spec.showNotDeclined
		and applicationDeclined(context.resultID)
	then
		return false
	end
	if spec.showBloodlust then
		local mode = number(client.bloodlustMode) or 0
		local state
		if mode > 0 then
			state = bloodlustState(context)
		end
		if (mode == 1 and state == false) or (mode == 2 and state == true) then
			return false
		end
	end
	if spec.showDungeonDifficulty and client.dungeonDiffEn
		and not selectedDifficultyMatches(context:Activity(), {
			normal = client.dungeonDifficultyNormal,
			heroic = client.dungeonDifficultyHeroic,
			mythic = client.dungeonDifficultyMythic,
			mplus = client.dungeonDifficultyMythicPlus,
		})
	then
		return false
	end
	if spec.showRaidDifficulty and client.raidDiffEn
		and not selectedDifficultyMatches(context:Activity(), {
			normal = client.raidDifficultyNormal,
			heroic = client.raidDifficultyHeroic,
			mythic = client.raidDifficultyMythic,
		})
	then
		return false
	end
	if client.warmodeOnly and spec.showWarmode then
		local warmode, state = read(context.info, "isWarMode")
		if state == "value" and warmode ~= true then
			return false
		elseif state == "missing" then
			return false
		end
	end
	return true
end

function Pipeline:IsEnabled()
	return true
end

function Pipeline:ShouldShowResult(resultID, entry, spec, client, db, info)
	local context = ResultContext:New(resultID, entry, info)
	if not context.info then
		return false
	end
	-- 当前队伍是搜索上下文中的定位行，不受任何高级筛选条件影响。
	if GF.IsCurrentGroupSearchResult
		and GF.IsCurrentGroupSearchResult(context.info, resultID)
	then
		return true
	end
	if type(spec) ~= "table" and FilterSpec
		and type(FilterSpec.ResolveSpec) == "function"
	then
		local selection
		if GF.FindGroupTab and type(GF.FindGroupTab.GetSelection) == "function" then
			selection = invoke(GF.FindGroupTab.GetSelection, GF.FindGroupTab)
		end
		spec = FilterSpec:ResolveSpec(selection)
	end

	if GF.Filter and type(GF.Filter.MatchesPlaystyleFilter) == "function" then
		db = db or (type(GF.Filter.GetGlobalFilters) == "function"
			and GF.Filter:GetGlobalFilters(spec))
		local playstyle, state = read(context.info, "generalPlaystyle")
		if state ~= "secret" and state ~= "error" and state ~= "unavailable"
			and not GF.Filter:MatchesPlaystyleFilter(db, playstyle)
		then
			return false
		end
	end

	if spec and spec.showDungeonActivities and GF.Filter then
		local items = type(GF.Filter.GetDungeonActivityItems) == "function"
			and GF.Filter:GetDungeonActivityItems() or nil
		if type(GF.Filter.HasActiveDungeonActivityFilter) == "function"
			and GF.Filter:HasActiveDungeonActivityFilter(nil, items)
			and not GF.Filter:MatchesDungeonActivityFilter(
				nil, context:ActivityIDs(), items)
		then
			return false
		end
	end
	if spec and spec.showRaidActivities and GF.Filter then
		local items = type(GF.Filter.GetRaidActivityItems) == "function"
			and GF.Filter:GetRaidActivityItems() or nil
		if type(GF.Filter.HasActiveRaidActivityFilter) == "function"
			and GF.Filter:HasActiveRaidActivityFilter(nil, items)
			and not GF.Filter:MatchesRaidActivityFilter(
				nil, context:ActivityIDs(), items)
		then
			return false
		end
	end

	if not spec then
		return true
	end
	db = db or (GF.Filter and type(GF.Filter.GetGlobalFilters) == "function"
		and GF.Filter:GetGlobalFilters(spec))
		or (GF.GetDB and GF.GetDB()) or {}
	if spec.runGlobalClient and not passesGlobal(context, spec, db) then
		return false
	end

	if spec.runCategoryClient then
		if type(client) ~= "table" and spec.isMythicPlusBrowse
			and GF.MythicPlusBrowseFilter
			and type(GF.MythicPlusBrowseFilter.GetClientFilters) == "function"
		then
			client = invoke(
				GF.MythicPlusBrowseFilter.GetClientFilters,
				GF.MythicPlusBrowseFilter)
		end
		if type(client) ~= "table" and GF.Filter
			and type(GF.Filter.GetClientFilters) == "function"
		then
			client = GF.Filter:GetClientFilters(spec.clientKey)
		end
		if not passesCategory(context, spec, client or {}) then
			return false
		end
	end

	if db.sameClass and spec.showSameClass
		and SAME_CLASS_CATEGORIES[context:CategoryID()]
		and not self:CheckSameClass(resultID, context:CategoryID())
	then
		return false
	end
	return true
end

function Pipeline:CheckSameClass(resultID, categoryID)
	if not SAME_CLASS_CATEGORIES[categoryID] then
		return true
	end
	local classFile = localClass()
	if not classFile then
		return true
	end
	local context = ResultContext:New(resultID)
	if not context.info then
		return true
	end
	local players, complete = context:Players()
	if type(players) ~= "table" or not complete then
		return true
	end
	for _, player in ipairs(players) do
		if playerRole(player) == "DAMAGER" and playerClass(player) == classFile then
			return false
		end
	end
	return true
end

function Pipeline:NeedsPostFilters(spec, client, db)
	if FilterSpec and type(FilterSpec.NeedsPostFilter) == "function" then
		return FilterSpec:NeedsPostFilter(spec, client, db)
	end
	return false
end
