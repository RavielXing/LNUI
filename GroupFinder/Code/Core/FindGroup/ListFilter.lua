local _, GF = ...

-- Result post-filtering is stateless. A pass context snapshots inputs that are
-- expensive or must stay consistent across asynchronous batches; every result
-- is then evaluated by the same GF predicates without retaining row state in
-- this module.
local ListFilter = {}
GF.ListFilter = ListFilter

local BLOODLUST_CLASS = {
	EVOKER = true,
	HUNTER = true,
	MAGE = true,
	SHAMAN = true,
}

local ROLE_ALIASES = {
	TANK = "TANK",
	HEAL = "HEALER",
	HEALER = "HEALER",
	DAMAGE = "DAMAGER",
	DAMAGER = "DAMAGER",
	DPS = "DAMAGER",
}

local REMAINING_FIELD = {
	TANK = "TANK_REMAINING",
	HEALER = "HEALER_REMAINING",
	DAMAGER = "DAMAGER_REMAINING",
}

local PRESENT_FIELD = {
	TANK = "TANK",
	HEALER = "HEALER",
	DAMAGER = "DAMAGER",
}

local PLAYER_CLASS_FIELDS = { "classFilename", "classFile", "class" }
local PLAYER_ROLE_FIELDS = {
	"assignedRole",
	"primaryRole",
	"role",
	"specRole",
}
local RAID_ROLE_DEFINITIONS = {
	{ role = "TANK", enabled = "raidTankEn", min = "raidTankMin", max = "raidTankMax" },
	{ role = "HEALER", enabled = "raidHealEn", min = "raidHealMin", max = "raidHealMax" },
	{ role = "DAMAGER", enabled = "raidDpsEn", min = "raidDpsMin", max = "raidDpsMax" },
}
local MYTHIC_ROLE_DEFINITIONS = {
	{ key = "tankPresence", role = "TANK" },
	{ key = "healerPresence", role = "HEALER" },
	{ key = "damagerPresence", role = "DAMAGER" },
}

local function clearReusableTable(values)
	values = type(values) == "table" and values or {}
	for key in pairs(values) do
		values[key] = nil
	end
	return values
end

local function accessible(value)
	if value == nil then
		return true
	end
	if type(canaccessvalue) == "function" then
		local ok, canAccess = pcall(canaccessvalue, value)
		if ok and canAccess == false then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if ok and secret == true then
			return false
		end
	end
	return true
end

local function read(owner, key)
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ReadField) == "function" then
		return snapshot.ReadField(owner, key)
	end
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
	elseif not accessible(value) then
		return nil, "secret"
	elseif value == nil then
		return nil, "missing"
	end
	return value, "value"
end

local function numeric(value)
	if value == nil or not accessible(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	return ok and number or nil
end

local function text(value)
	if type(value) ~= "string" or not accessible(value) then
		return nil
	end
	local ok, trimmed = pcall(string.match, value, "^%s*(.-)%s*$")
	return ok and trimmed or nil
end

local function normalizeRole(value)
	value = text(value)
	if not value then
		return nil
	end
	local ok, upper = pcall(string.upper, value)
	return ok and ROLE_ALIASES[upper] or nil
end

local function normalizeClass(value)
	value = text(value)
	if not value then
		return nil
	end
	local ok, upper = pcall(string.upper, value)
	return ok and upper or nil
end

local function copyTable(source, target)
	if type(source) ~= "table" then
		return clearReusableTable(target)
	end
	local copy = type(target) == "table" and target or {}
	for key in pairs(copy) do
		if source[key] == nil then
			copy[key] = nil
		end
	end
	for key, value in pairs(source) do
		if type(value) == "table" then
			local child = type(copy[key]) == "table" and copy[key] or {}
			for childKey in pairs(child) do
				child[childKey] = nil
			end
			for childKey, childValue in pairs(value) do
				child[childKey] = childValue
			end
			copy[key] = child
		else
			copy[key] = value
		end
	end
	return copy
end

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return nil, false
	end
	local ok, value, extra = pcall(method, owner, ...)
	return ok and value or nil, ok, extra
end

local function resultInfo(resultID, entry, supplied)
	if type(supplied) == "table" then
		return supplied
	end
	local fromEntry = read(entry, "info")
	if type(fromEntry) == "table" then
		return fromEntry
	end
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.GetSearchResultInfo) == "function" then
		local ok, info = pcall(snapshot.GetSearchResultInfo, resultID)
		if ok and type(info) == "table" then
			return info
		end
	end
	local reader = C_LFGList and C_LFGList.GetSearchResultInfo
	if type(reader) == "function" then
		local ok, info = pcall(reader, resultID)
		return ok and type(info) == "table" and info or nil
	end
	return nil
end

local function appendActivityID(out, seen, value)
	local id = numeric(value)
	if id and id > 0 and not seen[id] then
		seen[id] = true
		out[#out + 1] = id
	end
end

local function activityIDs(info, entry, context)
	local ids = context and clearReusableTable(context._activityIDs)
		or {}
	local seen = context and clearReusableTable(context._activityIDSet)
		or {}
	if context then
		context._activityIDs = ids
		context._activityIDSet = seen
	end
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.GetActivityIDs) == "function" then
		local ok, resolved = pcall(
			snapshot.GetActivityIDs, info, entry, ids, seen)
		if ok and type(resolved) == "table" then
			if context then
				context._activityIDs = resolved
			end
			return resolved
		end
	end
	appendActivityID(ids, seen, read(info, "activityID"))
	local multiple = read(info, "activityIDs")
	if type(multiple) == "table" then
		for _, id in ipairs(multiple) do
			appendActivityID(ids, seen, id)
		end
	end
	appendActivityID(ids, seen, read(entry, "activityID"))
	return ids
end

local function activityInfo(context)
	if context.activityResolved then
		return context.activity
	end
	context.activityResolved = true
	local fromEntry = read(context.entry, "activity")
	if type(fromEntry) == "table" then
		context.activity = fromEntry
		return fromEntry
	end
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ResolveActivityInfo) == "function" then
		local ok, activity = pcall(snapshot.ResolveActivityInfo, context.info)
		if ok and type(activity) == "table" then
			context.activity = activity
			return activity
		end
	end
	local id = context.activityIDs[1]
	local reader = C_LFGList and C_LFGList.GetActivityInfoTable
	if id and type(reader) == "function" then
		local questID = read(context.info, "questID")
		local isWarMode = read(context.info, "isWarMode")
		local ok, activity = pcall(reader, id, questID, isWarMode)
		if ok and type(activity) == "table" then
			context.activity = activity
		end
	end
	return context.activity
end

local function memberCounts(context)
	if context.countsResolved then
		return context.counts
	end
	context.countsResolved = true
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.GetMemberCounts) == "function" then
		local ok, counts = pcall(
			snapshot.GetMemberCounts, context.resultID, context.entry)
		if ok and type(counts) == "table" then
			context.counts = counts
			return counts
		end
	end
	local cached = read(context.entry, "_displayCounts")
	if type(cached) == "table" then
		context.counts = cached
		return cached
	end
	local reader = C_LFGList and C_LFGList.GetSearchResultMemberCounts
	if context.resultID and type(reader) == "function" then
		local ok, counts = pcall(reader, context.resultID)
		if ok and type(counts) == "table" then
			context.counts = counts
		end
	end
	return context.counts
end

local function count(context, field)
	local counts = memberCounts(context)
	local value, state = read(counts, field)
	return numeric(value), state
end

local function resultPlayers(context)
	if context.playersResolved then
		return context.players, context.playersComplete
	end
	context.playersResolved = true
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.GetPlayers) == "function" then
		local ok, players, complete = pcall(
			snapshot.GetPlayers,
			context.resultID,
			context.info,
			context.entry,
			context._playerBuffer)
		if ok and type(players) == "table" then
			if players ~= read(context.entry, "players") then
				context._playerBuffer = players
			end
			context.players = players
			context.playersComplete = complete == true
			return players, context.playersComplete
		end
	end
	local players = read(context.entry, "players")
	if type(players) == "table" then
		context.players = players
		local expected = numeric(read(context.info, "numMembers"))
		context.playersComplete = expected ~= nil and #players >= expected
	end
	return context.players, context.playersComplete
end

local function currentSpecialization(pass)
	if pass.currentSpecResolved then
		return pass.currentSpec
	end
	pass.currentSpecResolved = true
	local service = GF.SpecializationInfo
	local snapshot = invoke(service, "GetCurrentSnapshot")
	pass.currentSpec = type(snapshot) == "table" and snapshot or {}
	return pass.currentSpec
end

local function currentClass(pass)
	if pass.currentClassResolved then
		return pass.currentClass
	end
	pass.currentClassResolved = true
	if type(UnitClass) == "function" then
		local ok, _, classFile = pcall(UnitClass, "player")
		if ok then
			pass.currentClass = normalizeClass(classFile)
		end
	end
	return pass.currentClass
end

local function currentRole(pass)
	local specialization = currentSpecialization(pass)
	return normalizeRole(specialization and specialization.specRole)
end

local function currentGroup(info, resultID)
	if type(info) ~= "table"
		or type(GF.IsCurrentGroupSearchResult) ~= "function"
	then
		return false
	end
	local ok, current = pcall(GF.IsCurrentGroupSearchResult, info, resultID)
	return ok and current == true
end

local function valueInsideRange(value, minimum, maximum, zeroIsExact)
	if value == nil then
		return true
	end
	minimum = numeric(minimum) or 0
	maximum = numeric(maximum) or 0
	if minimum == 0 and maximum == 0 then
		return not zeroIsExact or value == 0
	end
	if minimum > 0 and value < minimum then
		return false
	end
	if maximum > 0 and value > maximum then
		return false
	end
	return true
end

local function readableNumber(owner, key)
	local value, state = read(owner, key)
	return numeric(value), state
end

local function activityTier(activity)
	local service = GF.ActivityInfo
	local reader = service and service.GetDifficultyTier
	if type(reader) == "function" then
		local ok, tier = pcall(reader, activity, { includeMplus = true })
		if ok and type(tier) == "string" then
			return tier:lower()
		end
	end
	if type(activity) ~= "table" then
		return nil
	elseif activity.isMythicPlusActivity == true then
		return "mplus"
	elseif activity.isMythicActivity == true then
		return "mythic"
	elseif activity.isHeroicActivity == true then
		return "heroic"
	elseif activity.isNormalActivity == true then
		return "normal"
	end
	return nil
end

local function matchesDifficulty(context)
	local plan, client = context.plan, context.client
	local enabled, normal, heroic, mythic, mplus
	if plan.showDungeonDifficulty and client.dungeonDiffEn == true then
		enabled = true
		normal = client.dungeonDifficultyNormal == true
		heroic = client.dungeonDifficultyHeroic == true
		mythic = client.dungeonDifficultyMythic == true
		mplus = client.dungeonDifficultyMythicPlus == true
	elseif plan.showRaidDifficulty and client.raidDiffEn == true then
		enabled = true
		normal = client.raidDifficultyNormal == true
		heroic = client.raidDifficultyHeroic == true
		mythic = client.raidDifficultyMythic == true
	end
	if not enabled then
		return true
	end
	if not (normal or heroic or mythic or mplus) then
		return true
	end
	local tier = activityTier(activityInfo(context))
	if tier == nil then
		return true
	elseif tier == "normal" then
		return normal == true
	elseif tier == "heroic" then
		return heroic == true
	elseif tier == "mythic" then
		return mythic == true
	elseif tier == "mplus" then
		return mplus == true
	end
	return false
end

local function matchesActivitySelection(context)
	local pass = context.pass
	if context.plan.isMythicPlusBrowse and pass.mythicActivitySetKnown then
		if next(pass.mythicActivitySet) == nil then
			return false
		end
		local readable = false
		for _, id in ipairs(context.activityIDs) do
			readable = true
			if pass.mythicActivitySet[id] then
				return true
			end
		end
		if readable then
			return false
		end
	end

	local filter = GF.Filter
	if context.plan.showDungeonActivities
		and filter and type(filter.MatchesDungeonActivityFilter) == "function"
	then
		local ok, matches = pcall(
			filter.MatchesDungeonActivityFilter,
			filter,
			pass.activityDatabase,
			context.activityIDs,
			pass.dungeonActivityItems)
		if ok and matches == false then
			return false
		end
	end
	if context.plan.showRaidActivities
		and filter and type(filter.MatchesRaidActivityFilter) == "function"
	then
		local ok, matches = pcall(
			filter.MatchesRaidActivityFilter,
			filter,
			pass.activityDatabase,
			context.activityIDs,
			pass.raidActivityItems)
		if ok and matches == false then
			return false
		end
	end
	return true
end

local function roleRemaining(context, role)
	return count(context, REMAINING_FIELD[role])
end

local function rolePresent(context, role)
	local amount, state = count(context, PRESENT_FIELD[role])
	if amount == nil then
		return nil, state
	end
	return amount > 0, state
end

local function playerClass(player)
	for _, field in ipairs(PLAYER_CLASS_FIELDS) do
		local class = normalizeClass(read(player, field))
		if class then
			return class
		end
	end
	return nil
end

local function playerRole(player)
	for _, field in ipairs(PLAYER_ROLE_FIELDS) do
		local role = normalizeRole(read(player, field))
		if role then
			return role
		end
	end
	return nil
end

local function hasSameDamageClass(context)
	local ownClass = currentClass(context.pass)
	if not ownClass then
		return nil
	end
	local players, complete = resultPlayers(context)
	if not complete then
		return nil
	end
	for _, player in ipairs(players or {}) do
		local class, role = playerClass(player), playerRole(player)
		if not class or not role then
			return nil
		end
		if role == "DAMAGER" and class == ownClass then
			return true
		end
	end
	return false
end

local function matchCurrentRole(context, avoidSameClass)
	local role = currentRole(context.pass)
	if not role then
		return true
	end
	local remaining = roleRemaining(context, role)
	if remaining ~= nil and remaining <= 0 then
		return false
	end
	if avoidSameClass and role == "DAMAGER" then
		local duplicate = hasSameDamageClass(context)
		if duplicate == true then
			return false
		end
	end
	return true
end

local function mergeRoleCheck(
	anyEnabled, anyPassed, allPassed, enabled, result)
	if not enabled then
		return anyEnabled, anyPassed, allPassed
	end
	local passed = result ~= false
	return true, anyPassed or passed, allPassed and passed
end

local function rangeRoleCheck(context, enabled, role, minimum)
	if not enabled then
		return nil
	end
	local remaining = roleRemaining(context, role)
	return remaining == nil or remaining >= math.max(1, numeric(minimum) or 1)
end

local partyFits

local function roleChecksPass(context)
	local plan, client = context.plan, context.client
	local anyEnabled, anyPassed, allPassed = false, false, true
	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showMatchRole and client.matchMyRole == true,
		partyFits(context, false))
	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showNeedsMyClass and client.needsMyClass == true,
		matchCurrentRole(context, true))

	local tankPresent = rolePresent(context, "TANK")
	local healerPresent = rolePresent(context, "HEALER")
	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showHasTankHeal and client.hasTank == true,
		tankPresent == nil or tankPresent == false)
	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showHasTankHeal and client.alreadyHasTank == true,
		tankPresent == nil or tankPresent == true)
	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showHasTankHeal and client.hasHeal == true,
		healerPresent == nil or healerPresent == false)
	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showHasTankHeal and client.alreadyHasHeal == true,
		healerPresent == nil or healerPresent == true)

	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showTankRange and client.rangeTankEn == true,
		rangeRoleCheck(context, true, "TANK", client.rangeTankMin))
	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showHealRange and client.rangeHealEn == true,
		rangeRoleCheck(context, true, "HEALER", client.rangeHealMin))
	anyEnabled, anyPassed, allPassed = mergeRoleCheck(
		anyEnabled, anyPassed, allPassed,
		plan.showDpsRange and client.rangeDpsEn == true,
		rangeRoleCheck(context, true, "DAMAGER", client.rangeDpsMin))

	for _, definition in ipairs(RAID_ROLE_DEFINITIONS) do
		if plan.showRaidRoleCounts and client[definition.enabled] == true then
			local amount = count(context, PRESENT_FIELD[definition.role])
			anyEnabled, anyPassed, allPassed = mergeRoleCheck(
				anyEnabled, anyPassed, allPassed, true,
				valueInsideRange(amount,
					client[definition.min], client[definition.max], true))
		end
	end

	if not anyEnabled then
		return true
	end
	if client.roleFilterMode == "any" then
		return anyPassed
	end
	return allPassed
end

local function specializationRole(member)
	local role = normalizeRole(read(member, "specRole"))
	if role then
		return role
	end
	local specID = numeric(read(member, "specID"))
	local cache = GF.MythicPlusSpecializationCache
	if specID and cache and type(cache.GetInfo) == "function" then
		local info = invoke(cache, "GetInfo", specID)
		role = normalizeRole(info and info.specRole)
		if role then
			return role
		end
	end
	return playerRole(member)
end

local function memberRoleChoices(member, useSpecialization)
	if useSpecialization then
		local role = specializationRole(member)
		return role and { role } or nil
	end
	local assigned = normalizeRole(read(member, "assignedRole"))
	if assigned then
		return { assigned }
	end
	local choices, seen = {}, {}
	local roles = read(member, "roles")
	if type(roles) == "table" then
		for rawRole, enabled in pairs(roles) do
			local role = normalizeRole(rawRole)
			if role and enabled == true and not seen[role] then
				seen[role] = true
				choices[#choices + 1] = role
			end
		end
	end
	if #choices == 0 then
		local fallback = playerRole(member)
		if fallback then
			choices[1] = fallback
		end
	end
	return #choices > 0 and choices or nil
end

local function assignRoles(requirements, capacities, index)
	if index > #requirements then
		return true
	end
	for _, role in ipairs(requirements[index]) do
		if capacities[role] and capacities[role] > 0 then
			capacities[role] = capacities[role] - 1
			if assignRoles(requirements, capacities, index + 1) then
				capacities[role] = capacities[role] + 1
				return true
			end
			capacities[role] = capacities[role] + 1
		end
	end
	return false
end

local function buildPartyRequirements(members, useSpecialization)
	if type(members) ~= "table" or #members == 0 then
		return nil, nil
	end
	local requirements, rolesNeeded = {}, {}
	for _, member in ipairs(members) do
		local choices = memberRoleChoices(member, useSpecialization)
		if choices then
			requirements[#requirements + 1] = choices
			for _, role in ipairs(choices) do
				rolesNeeded[role] = true
			end
		end
	end
	if #requirements == 0 then
		return nil, nil
	end
	table.sort(requirements, function(left, right)
		return #left < #right
	end)
	return requirements, rolesNeeded
end

partyFits = function(context, useSpecialization)
	local pass = context.pass
	local requirements = useSpecialization
		and pass.partySpecRequirements or pass.partyRoleRequirements
	local rolesNeeded = useSpecialization
		and pass.partySpecRolesNeeded or pass.partyRoleRolesNeeded
	if type(requirements) ~= "table" or #requirements == 0 then
		return true
	end
	local capacities = clearReusableTable(context._partyCapacities)
	context._partyCapacities = capacities
	for role in pairs(rolesNeeded) do
		local amount = roleRemaining(context, role)
		if amount == nil then
			return true
		end
		capacities[role] = math.max(0, math.floor(amount + 0.0001))
	end
	return assignRoles(requirements, capacities, 1)
end

local function mythicConditionsPass(context)
	if not context.plan.isMythicPlusBrowse then
		return true
	end
	local client = context.client
	if client.matchPartyRoles == true and not partyFits(context, false) then
		return false
	end
	if client.matchPartySpecs == true and not partyFits(context, true) then
		return false
	end
	for _, definition in ipairs(MYTHIC_ROLE_DEFINITIONS) do
		local mode = client[definition.key]
		if mode == "missing" then
			local remaining = roleRemaining(context, definition.role)
			if remaining ~= nil and remaining <= 0 then
				return false
			end
		elseif mode == "existing" then
			local present = rolePresent(context, definition.role)
			if present == false then
				return false
			end
		end
	end

	local minimumSlots = math.max(1, math.min(4,
		math.floor((numeric(client.minOpenSlots) or 1) + 0.5)))
	local snapshot = GF.SearchResultSnapshot
	local openSlots
	if snapshot and type(snapshot.GetOpenSlots) == "function" then
		local ok, amount = pcall(
			snapshot.GetOpenSlots, context.info, activityInfo(context))
		openSlots = ok and numeric(amount) or nil
	else
		local capacity = numeric(read(activityInfo(context), "maxNumPlayers"))
		local members = numeric(read(context.info, "numMembers"))
		openSlots = capacity and members and math.max(0, capacity - members) or nil
	end
	if openSlots ~= nil and openSlots < minimumSlots then
		return false
	end

	local minimumScore = math.max(0, numeric(client.leaderScoreMin) or 0)
	if minimumScore > 0 then
		local score, state = readableNumber(context.info, "leaderOverallDungeonScore")
		if state == "missing" then
			score = 0
		end
		if score ~= nil and score <= minimumScore then
			return false
		end
	end
	return true
end

local function bloodlustState(context)
	local players, complete = resultPlayers(context)
	if not complete then
		return nil
	end
	for _, player in ipairs(players or {}) do
		local class = playerClass(player)
		if not class then
			return nil
		elseif BLOODLUST_CLASS[class] then
			return true
		end
	end
	return false
end

local function declinedIsHidden(context)
	if not (context.plan.showNotDeclined
		and context.client.notDeclined == true)
	then
		return false
	end
	local apply = GF.Apply
	if apply and type(apply.HasRejectionFeedback) == "function" then
		local feedback = invoke(apply, "HasRejectionFeedback", context.resultID)
		if feedback == true then
			return false
		end
	end
	if apply and type(apply.GetApplicationState) == "function" then
		local state = invoke(
			apply, "GetApplicationState", context.resultID, context.info)
		return type(state) == "table" and state.isDeclined == true
	end
	local reader = C_LFGList and C_LFGList.GetApplicationInfo
	if type(reader) == "function" then
		local ok, _, status = pcall(reader, context.resultID)
		return ok and type(status) == "string"
			and status:find("declined", 1, true) == 1
	end
	return false
end

local function categoryConditionsPass(context)
	if context.plan.runCategoryClient ~= true then
		return true
	end
	if not matchesDifficulty(context) or not roleChecksPass(context)
		or not mythicConditionsPass(context) or declinedIsHidden(context)
	then
		return false
	end
	local plan, client = context.plan, context.client
	if plan.showRaidMemberCount and client.raidMemberCountEn == true then
		local members = numeric(read(context.info, "numMembers"))
		if not valueInsideRange(
			members,
			client.raidMemberCountMin,
			client.raidMemberCountMax,
			true)
		then
			return false
		end
	end
	if plan.showRaidBossKills and client.raidBossKillsEn == true then
		local kills
		local snapshot = GF.SearchResultSnapshot
		if snapshot and type(snapshot.GetCompletedEncounterCount) == "function" then
			local ok, value = pcall(
				snapshot.GetCompletedEncounterCount, context.resultID)
			kills = ok and numeric(value) or nil
		end
		if not valueInsideRange(
			kills,
			client.raidBossKillsMin,
			client.raidBossKillsMax,
			true)
		then
			return false
		end
	end
	if plan.showBloodlust then
		local mode = numeric(client.bloodlustMode) or 0
		if mode > 0 then
			local state = bloodlustState(context)
			if (mode == 1 and state == false) or (mode == 2 and state == true) then
				return false
			end
		end
	end
	if plan.showWarmode and client.warmodeOnly == true then
		local warMode, state = read(context.info, "isWarMode")
		if state == "value" and warMode ~= true then
			return false
		end
	end
	return true
end

local function normalizedRealm(value)
	value = text(value)
	if not value then
		return nil
	end
	local ok, normalized = pcall(function()
		return value:gsub("[%s%-']", ""):lower()
	end)
	return ok and normalized ~= "" and normalized or nil
end

local function leaderRealm(info)
	local leader = text(read(info, "leaderName"))
	if not leader then
		return nil
	end
	local ok, realm = pcall(string.match, leader, "^[^%-]+%-(.+)$")
	return ok and normalizedRealm(realm) or nil
end

local function currentRealm()
	for _, reader in ipairs({ GetNormalizedRealmName, GetRealmName }) do
		if type(reader) == "function" then
			local ok, realm = pcall(reader)
			if ok then
				realm = normalizedRealm(realm)
				if realm then
					return realm
				end
			end
		end
	end
	return nil
end

local function normalizeFaction(value)
	if type(value) == "string" and accessible(value) then
		local ok, upper = pcall(string.upper, value)
		if ok and (upper == "ALLIANCE" or upper == "HORDE") then
			return upper
		end
	end
	local numericFaction = numeric(value)
	local factions = Enum and (Enum.PvPFaction or Enum.PlayerFaction)
	if numericFaction ~= nil and type(factions) == "table" then
		if numericFaction == factions.Alliance then
			return "ALLIANCE"
		elseif numericFaction == factions.Horde then
			return "HORDE"
		end
	end
	return nil
end

local function socialCounts(context)
	local info = context.info
	local bnet = numeric(read(info, "numBNetFriends")) or 0
	local character = numeric(read(info, "numCharFriends")) or 0
	local guild = numeric(read(info, "numGuildMates")) or 0
	if bnet > 0 or character > 0 or guild > 0 then
		return bnet, character, guild
	end
	local reader = C_LFGList and C_LFGList.GetSearchResultFriends
	if context.resultID and type(reader) == "function" then
		local ok, bnetList, characterList, guildList = pcall(reader, context.resultID)
		if ok then
			bnet = type(bnetList) == "table" and #bnetList or bnet
			character = type(characterList) == "table" and #characterList or character
			guild = type(guildList) == "table" and #guildList or guild
		end
	end
	return bnet, character, guild
end

local function globalRangePass(info, enabled, field, minimum, maximum, transform)
	if not enabled then
		return true
	end
	local value = numeric(read(info, field))
	if value ~= nil and transform then
		value = transform(value)
	end
	return valueInsideRange(value, minimum, maximum, false)
end

local function playstylePass(context)
	local filter = GF.Filter
	if not (filter and type(filter.HasActivePlaystyleFilter) == "function"
		and type(filter.MatchesPlaystyleFilter) == "function")
	then
		return true
	end
	local ok, active = pcall(
		filter.HasActivePlaystyleFilter, filter, context.database)
	if not ok or active ~= true then
		return true
	end
	local style, state = read(context.info, "generalPlaystyle")
	if state ~= "value" then
		return true
	end
	local matchedOK, matched = pcall(
		filter.MatchesPlaystyleFilter, filter, context.database, style)
	return not matchedOK or matched ~= false
end

local function globalConditionsPass(context)
	if context.plan.runGlobalClient ~= true then
		return true
	end
	local db, info = context.database, context.info
	if db.zeroScore == true then
		local score, state = readableNumber(info, "leaderOverallDungeonScore")
		if state == "missing" then
			score = 0
		end
		if score ~= nil and score < 1 then
			return false
		end
	end
	if not globalRangePass(info, db.rangeAgeEn == true, "age",
		db.rangeAgeMin, db.rangeAgeMax, function(seconds)
			return seconds / 60
		end)
	then
		return false
	end
	if (numeric(db.maxAgeMin) or 0) > 0 then
		local age = numeric(read(info, "age"))
		if age and age / 60 > numeric(db.maxAgeMin) then
			return false
		end
	end
	if not globalRangePass(info, db.rangeIlvlEn == true, "requiredItemLevel",
		db.rangeIlvlMin, db.rangeIlvlMax)
	then
		return false
	end
	if db.groupMinimumItemLevelAdmission == true then
		local admission = GF.GroupItemLevelAdmission
		local requiredItemLevel = numeric(read(info, "requiredItemLevel"))
		local minimumItemLevel = context.pass
			and context.pass.groupMinimumItemLevel
		if admission and type(admission.AllowsRequiredItemLevel) == "function"
			and admission:AllowsRequiredItemLevel(
				requiredItemLevel, minimumItemLevel) ~= true
		then
			return false
		end
	end
	if (numeric(db.minIlvl) or 0) > 0 then
		local itemLevel = numeric(read(info, "requiredItemLevel"))
		if itemLevel and itemLevel < numeric(db.minIlvl) then
			return false
		end
	end
	if not globalRangePass(info, db.rangeHonorEn == true, "requiredHonorLevel",
		db.rangeHonorMin, db.rangeHonorMax)
		or not globalRangePass(info, db.rangeMplusScoreEn == true,
			"leaderOverallDungeonScore",
			db.rangeMplusScoreMin, db.rangeMplusScoreMax)
	then
		return false
	end
	if db.hideVoice == true then
		local voice, state = read(info, "voiceChat")
		if state == "value" and text(voice) ~= "" then
			return false
		end
	end
	if db.hideCrossRealm == true then
		local leader, player = leaderRealm(info), currentRealm()
		if leader and player and leader ~= player then
			return false
		end
	end
	if db.sameFactionOnly == true then
		local crossFaction, state = read(info, "crossFactionListing")
		if state == "value" and crossFaction == true then
			return false
		end
		local leaderFaction = normalizeFaction(read(info, "leaderFactionGroup"))
		local playerFaction
		if type(UnitFactionGroup) == "function" then
			local ok, faction = pcall(UnitFactionGroup, "player")
			playerFaction = ok and normalizeFaction(faction) or nil
		end
		if leaderFaction and playerFaction and leaderFaction ~= playerFaction then
			return false
		end
	end
	if db.showFriendGroups == false or db.showGuildGroups == false then
		local bnet, character, guild = socialCounts(context)
		if db.showFriendGroups == false and (bnet > 0 or character > 0
			or read(info, "isFriendListing") == true)
		then
			return false
		end
		if db.showGuildGroups == false and (guild > 0
			or read(info, "isGuildListing") == true)
		then
			return false
		end
	end
	if db.showHousewarmingGroups == false then
		if read(info, "isHousewarming") == true
			or read(info, "isHousewarmingListing") == true
		then
			return false
		end
	end
	if db.sameClass == true and currentRole(context.pass) == "DAMAGER"
		and hasSameDamageClass(context) == true
	then
		return false
	end
	return playstylePass(context)
end

local function neteaseNewbiePass(context)
	if not (context.plan.isMythicPlusBrowse == true
		and GF.NetEaseIdentityService
		and GF.NetEaseIdentityService:IsEnabled() == true
		and GF.MythicPlusBrowseFilter
		and GF.MythicPlusBrowseFilter:IsNewbieOnly() == true)
	then
		return true
	end
	local projection = GF.NetEaseIdentityService:GetGroupProjection(
		context.resultID,
		context.info,
		context.entry,
		{ queue = true })
	return projection ~= nil and projection.hasNewbie == true
end

local RESULT_PREDICATES = {
	matchesActivitySelection,
	categoryConditionsPass,
	globalConditionsPass,
	neteaseNewbiePass,
}

local function collectApplicantMembers(client)
	if not (client.matchMyRole == true or client.matchPartyRoles == true
		or client.matchPartySpecs == true)
	then
		return nil
	end
	local cache = GF.MythicPlusRosterCache
	local members = invoke(cache, "GetMembers")
	if type(members) == "table" and #members > 0 then
		return members
	end
	return nil
end

local function captureSelectedMythicActivities(pass)
	if not pass.plan.isMythicPlusBrowse then
		return
	end
	local ids, ok = invoke(GF.MythicPlusBrowseFilter, "GetSelectedActivityIDs")
	if not ok or type(ids) ~= "table" then
		return
	end
	pass.mythicActivitySetKnown = true
	for _, value in ipairs(ids) do
		local id = numeric(value)
		if id and id > 0 then
			pass.mythicActivitySet[id] = true
		end
	end
end

local function captureActivityItems(pass, methodName, targetKey)
	local filter = GF.Filter
	local items = invoke(filter, methodName)
	if type(items) == "table" then
		pass[targetKey] = items
	end
end

local function captureActivityStorage(pass, kind)
	local filter = GF.Filter
	local snapshot = invoke(filter, "GetActivityFilterSnapshot", kind)
	if type(snapshot) ~= "table" then
		return
	end
	pass.activityDatabase = pass.activityDatabase or {}
	for key, value in pairs(snapshot) do
		pass.activityDatabase[key] = type(value) == "table"
			and copyTable(value, pass.activityDatabase[key]) or value
	end
end

local function resetResultContext(context, releaseBuffers)
	context = type(context) == "table" and context or {}
	context.resultID = nil
	context.entry = nil
	context.info = nil
	context.plan = nil
	context.client = nil
	context.database = nil
	context.pass = nil
	context.activityIDs = nil
	context.activityResolved = nil
	context.activity = nil
	context.countsResolved = nil
	context.counts = nil
	context.playersResolved = nil
	context.players = nil
	context.playersComplete = nil
	if releaseBuffers == true then
		context._activityIDs = clearReusableTable(context._activityIDs)
		context._activityIDSet = clearReusableTable(context._activityIDSet)
		context._playerBuffer = clearReusableTable(context._playerBuffer)
		context._partyCapacities = clearReusableTable(context._partyCapacities)
	end
	return context
end

function ListFilter:ReleasePassContext(pass)
	if type(pass) ~= "table" then
		return nil
	end
	pass.plan = nil
	pass.client = clearReusableTable(pass.client)
	pass.database = clearReusableTable(pass.database)
	pass.mythicActivitySet = clearReusableTable(pass.mythicActivitySet)
	pass.mythicActivitySetKnown = nil
	pass.applicantMembers = nil
	pass.dungeonActivityItems = nil
	pass.raidActivityItems = nil
	pass.activityDatabase = clearReusableTable(pass.activityDatabase)
	pass.currentSpecResolved = nil
	pass.currentSpec = nil
	pass.currentClassResolved = nil
	pass.currentClass = nil
	pass.partyRoleRequirements = nil
	pass.partyRoleRolesNeeded = nil
	pass.partySpecRequirements = nil
	pass.partySpecRolesNeeded = nil
	pass.groupMinimumItemLevel = nil
	pass._resultContext = resetResultContext(pass._resultContext, true)
	return pass
end

function ListFilter:CreatePassContext(spec, client, database, reusable)
	local pass = self:ReleasePassContext(reusable) or {}
	pass.plan = type(spec) == "table" and spec or {}
	pass.client = copyTable(client, pass.client)
	pass.database = copyTable(database, pass.database)
	pass.mythicActivitySet = clearReusableTable(pass.mythicActivitySet)
	captureSelectedMythicActivities(pass)
	if pass.database.groupMinimumItemLevelAdmission == true then
		local admission = GF.GroupItemLevelAdmission
		if admission and type(admission.GetMinimumEquippedItemLevel) == "function" then
			pass.groupMinimumItemLevel =
				admission:GetMinimumEquippedItemLevel()
		end
	end
	pass.applicantMembers = collectApplicantMembers(pass.client)
	if pass.client.matchMyRole == true or pass.client.matchPartyRoles == true then
		pass.partyRoleRequirements, pass.partyRoleRolesNeeded =
			buildPartyRequirements(pass.applicantMembers, false)
	end
	if pass.client.matchPartySpecs == true then
		pass.partySpecRequirements, pass.partySpecRolesNeeded =
			buildPartyRequirements(pass.applicantMembers, true)
	end
	if pass.plan.showDungeonActivities then
		captureActivityItems(pass, "GetDungeonActivityItems", "dungeonActivityItems")
		captureActivityStorage(pass, "dungeon")
	end
	if pass.plan.showRaidActivities then
		captureActivityItems(pass, "GetRaidActivityItems", "raidActivityItems")
		captureActivityStorage(pass, "raid")
	end
	return pass
end

function ListFilter:IsEnabled()
	-- Advanced filtering is a fixed GF result-pipeline capability. Individual
	-- neutral conditions determine whether a pass is actually needed.
	return true
end

function ListFilter:NeedsPostFilters(spec, client, database)
	local planner = GF.FilterSpec
	if planner and type(planner.NeedsListFilter) == "function" then
		local ok, needed = pcall(
			planner.NeedsListFilter, planner, spec, client, database)
		return ok and needed == true
	end
	return type(spec) == "table"
		and spec.isQuestSearch ~= true
		and (next(client or {}) ~= nil or next(database or {}) ~= nil)
end

local function resolvePlan(spec)
	if type(spec) ~= "table" then
		return nil
	end
	if spec.runGlobalClient ~= nil or spec.runCategoryClient ~= nil then
		return spec
	end
	local planner = GF.FilterSpec
	if planner and type(planner.ResolveSpec) == "function" then
		local ok, plan = pcall(planner.ResolveSpec, planner, spec)
		return ok and type(plan) == "table" and plan or nil
	end
	return nil
end

function ListFilter:ShouldShowResult(
	resultID, entry, spec, client, database, suppliedInfo, passContext)
	local plan = resolvePlan(spec)
	if not plan or plan.isQuestSearch == true then
		return true
	end
	local info = resultInfo(resultID, entry, suppliedInfo)
	if type(info) ~= "table" then
		return true
	end
	if currentGroup(info, resultID) then
		return true
	end

	local pass = type(passContext) == "table" and passContext
		or self:CreatePassContext(plan, client, database)
	-- A caller may supply a pass built by a compatibility implementation. Fill
	-- only absent value inputs; never persist them on the module singleton.
	pass.plan = pass.plan or plan
	pass.client = pass.client or copyTable(client)
	pass.database = pass.database or copyTable(database)
	pass.mythicActivitySet = pass.mythicActivitySet or {}

	local context = resetResultContext(pass._resultContext)
	pass._resultContext = context
	context.resultID = resultID
	context.entry = entry
	context.info = info
	context.plan = pass.plan
	context.client = pass.client
	context.database = pass.database
	context.pass = pass
	context.activityIDs = activityIDs(info, entry, context)
	for _, predicate in ipairs(RESULT_PREDICATES) do
		local ok, accepted = pcall(predicate, context)
		if ok and accepted == false then
			return false
		end
		-- Protected or temporarily unavailable data is fail-open by contract.
	end
	return true
end

local function refreshGenericRoleMatchAfterRosterChange()
	local workspace = invoke(GF.LFGWorkspaceView, "GetWorkspaceID")
	if workspace == GF.WORKSPACE_MYTHIC_PLUS then
		return
	end
	workspace = workspace or GF.WORKSPACE_MEETING_STONE or "standard"
	local filters = invoke(GF.Filter, "GetClientFilters", workspace)
	if type(filters) == "table" and filters.matchMyRole == true then
		invoke(GF.Filter, "ApplyClientFilterRefresh")
	end
end

local rosterCache = GF.MythicPlusRosterCache
if rosterCache and type(rosterCache.AddListener) == "function" then
	rosterCache:AddListener(refreshGenericRoleMatchAfterRosterChange)
end
