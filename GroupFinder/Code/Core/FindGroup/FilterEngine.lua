local _, GF = ...

-- FilterEngine owns GF's value semantics for saved filters. It never reads or
-- writes SavedVariables and never calls the native LFG API. Callers provide
-- snapshots and receive detached projections that can be tested in isolation.
local Engine = {}
GF.FilterEngine = Engine

local CLIENT_BUCKET_ALIASES = {
	dungeon = { "2" },
	raid = { "3" },
	other = { "121", "1", "6_pve", "6_pvp", "6", "8", "4", "9", "7", "0" },
}

local GLOBAL_BOOLEAN_DEFAULTS = {
	"sameClass", "zeroScore", "rangeAgeEn", "rangeIlvlEn",
	"rangeHonorEn", "hideVoice", "hideCrossRealm", "sameFactionOnly",
	"rangeMplusScoreEn", "groupMinimumItemLevelAdmission",
}

local GLOBAL_NUMBER_DEFAULTS = {
	"maxAgeMin", "minIlvl", "rangeAgeMin", "rangeAgeMax",
	"rangeIlvlMin", "rangeIlvlMax", "rangeHonorMin", "rangeHonorMax",
	"rangeMplusScoreMin", "rangeMplusScoreMax",
}

local DUNGEON_DIFFICULTY_FIELDS = {
	"dungeonDifficultyNormal",
	"dungeonDifficultyHeroic",
	"dungeonDifficultyMythic",
	"dungeonDifficultyMythicPlus",
}

local RAID_DIFFICULTY_FIELDS = {
	"raidDifficultyNormal",
	"raidDifficultyHeroic",
	"raidDifficultyMythic",
}

local function copy(value, visited)
	if type(value) ~= "table" then
		return value
	end
	visited = visited or {}
	if visited[value] then
		return visited[value]
	end
	local result = {}
	visited[value] = result
	for key, child in pairs(value) do
		result[copy(key, visited)] = copy(child, visited)
	end
	return result
end
local function number(value)
	local ok, converted = pcall(tonumber, value)
	if not ok or not converted then
		return nil
	end
	return converted
end

local function positiveID(value)
	local converted = number(value)
	return converted and converted > 0 and converted or nil
end

local function appendID(output, seen, value)
	local id = positiveID(value)
	if id and not seen[id] then
		seen[id] = true
		output[#output + 1] = id
	end
end

local function appendArrayIDs(output, seen, values)
	if type(values) ~= "table" then
		return
	end
	pcall(function()
		for index = 1, #values do
			appendID(output, seen, values[index])
		end
	end)
end

local function groupKey(groupID)
	groupID = positiveID(groupID)
	return groupID and ("g:" .. groupID) or nil
end

local function optionKey(item)
	if type(item) == "table" then
		local ok, explicit = pcall(function()
			return item.key
		end)
		if ok and type(explicit) == "string" and explicit ~= "" then
			return explicit
		end
		local groupOK, groupID = pcall(function()
			return item.groupID
		end)
		return groupOK and groupKey(groupID) or nil
	end
	if type(item) == "string" and item ~= "" then
		return item
	end
	return groupKey(item)
end

local function itemGroupIDs(item)
	local ids, seen = {}, {}
	if type(item) == "table" then
		local ok, values, one = pcall(function()
			return item.groupIDs, item.groupID
		end)
		if ok then
			appendArrayIDs(ids, seen, values)
			appendID(ids, seen, one)
		end
	else
		appendID(ids, seen, item)
	end
	return ids
end


local function itemActivityIDs(item)
	local ids, seen = {}, {}
	if type(item) ~= "table" then
		return ids
	end
	local ok, values, one = pcall(function()
		return item.activityIDs, item.activityID
	end)
	if ok then
		appendArrayIDs(ids, seen, values)
		appendID(ids, seen, one)
	end
	return ids
end

local function keySet(items)
	local result = {}
	for index = 1, #(items or {}) do
		local key = optionKey(items[index])
		if key then
			result[tostring(key)] = true
		end
	end
	return result
end

local function sanitizeKeys(savedKeys, items)
	if type(savedKeys) ~= "table" then
		return nil
	end
	if #savedKeys == 0 then
		return {}
	end
	local valid = keySet(items)
	local output, seen = {}, {}
	for index = 1, #savedKeys do
		local key = tostring(savedKeys[index])
		if valid[key] and not seen[key] then
			seen[key] = true
			output[#output + 1] = key
		end
	end
	return #output > 0 and output or nil
end

local function migrateGroupIDs(savedGroups, items)
	if type(savedGroups) ~= "table" or #savedGroups == 0 then
		return nil
	end
	local wanted = {}
	for index = 1, #savedGroups do
		local id = positiveID(savedGroups[index])
		if id then
			wanted[id] = true
		end
	end
	local output, selected = {}, {}
	for index = 1, #(items or {}) do
		local item = items[index]
		local key = optionKey(item)
		for _, id in ipairs(itemGroupIDs(item)) do
			if key and wanted[id] and not selected[key] then
				selected[key] = true
				output[#output + 1] = tostring(key)
			end
		end
	end
	return #output > 0 and output or nil
end

local function selectedSet(keys)
	local result = {}
	for index = 1, #(keys or {}) do
		result[tostring(keys[index])] = true
	end
	return result
end

local function orderedSelection(items, selected)
	local result = {}
	for index = 1, #(items or {}) do
		local key = optionKey(items[index])
		key = key and tostring(key) or nil
		if key and selected[key] then
			result[#result + 1] = key
		end
	end
	return result
end

local function allItemsSelected(keys, items)
	if type(keys) ~= "table" or #keys == 0
		or type(items) ~= "table" or #items == 0
	then
		return false
	end
	local selected = selectedSet(keys)
	for index = 1, #items do
		local key = optionKey(items[index])
		if not key or not selected[tostring(key)] then
			return false
		end
	end
	return true
end

local function merge(defaults, stored)
	local output = copy(type(defaults) == "table" and defaults or {})
	if type(stored) == "table" then
		for key, value in pairs(stored) do
			output[key] = copy(value)
		end
	end
	return output
end

local function migrateSingleRange(values, legacyKey, minimumKey, maximumKey)
	local legacy = number(values[legacyKey]) or 0
	if legacy > 0
		and (number(values[minimumKey]) or 0) <= 0
		and (number(values[maximumKey]) or 0) <= 0
	then
		values[minimumKey] = legacy
		values[maximumKey] = legacy
	end
	values[legacyKey] = 0
end

local function selectExclusive(values, enabledKey, fields, selectedIndex)
	local output = copy(type(values) == "table" and values or {})
	local selectAll = not selectedIndex or selectedIndex == 0
	output[enabledKey] = not selectAll
	for index = 1, #fields do
		output[fields[index]] = selectAll or selectedIndex == index
	end
	return output
end

local function selectedExclusiveIndex(values, enabledKey, fields)
	if type(values) ~= "table" or values[enabledKey] ~= true then
		return 0
	end
	local answer
	for index = 1, #fields do
		if values[fields[index]] == true then
			if answer then
				return 0
			end
			answer = index
		end
	end
	return answer or 0
end

function Engine:Copy(value)
	return copy(value)
end

function Engine:GetGlobalDefaults()
	local defaults = {}
	for _, key in ipairs(GLOBAL_BOOLEAN_DEFAULTS) do
		defaults[key] = false
	end
	for _, key in ipairs(GLOBAL_NUMBER_DEFAULTS) do
		defaults[key] = 0
	end
	for index = 1, 4 do
		defaults["playstyle" .. index] = true
	end
	for _, key in ipairs({
		"showFriendGroups", "showGuildGroups", "showHousewarmingGroups",
	}) do
		defaults[key] = true
	end
	return defaults
end

function Engine:NormalizeClient(defaults, stored)
	local output = merge(defaults, stored)
	migrateSingleRange(
		output, "raidMemberCount", "raidMemberCountMin", "raidMemberCountMax")
	migrateSingleRange(
		output, "raidBossKills", "raidBossKillsMin", "raidBossKillsMax")
	return output
end

function Engine:CompactClient(defaults, values)
	if type(values) ~= "table" then
		return nil
	end
	defaults = type(defaults) == "table" and defaults or {}
	local compact = {}
	for key, value in pairs(values) do
		if defaults[key] == nil or value ~= defaults[key] then
			compact[key] = copy(value)
		end
	end
	return next(compact) and compact or nil
end

function Engine:RecoverClientBucket(bucketKey, allBuckets, defaults)
	if type(allBuckets) ~= "table" then
		return nil
	end
	local recovered = {}
	for _, legacyKey in ipairs(CLIENT_BUCKET_ALIASES[bucketKey] or {}) do
		local oldValues = allBuckets[legacyKey]
		if type(oldValues) == "table" then
			for field, value in pairs(oldValues) do
				if recovered[field] == nil then
					recovered[field] = copy(value)
				end
			end
		end
	end
	return self:CompactClient(defaults, recovered)
end

function Engine:GetGlobalBucketKey(specOrSelection, categories)
	if type(specOrSelection) ~= "table" then
		return "other"
	end
	if specOrSelection.clientKey == "dungeon"
		or specOrSelection.clientKey == "raid"
	then
		return specOrSelection.clientKey
	end
	local categoryID = specOrSelection.categoryID
	if categoryID == nil and type(specOrSelection.selection) == "table" then
		categoryID = specOrSelection.selection.categoryID
	end
	categories = type(categories) == "table" and categories or {}
	if categoryID == categories.dungeon then
		return "dungeon"
	elseif categoryID == categories.raid then
		return "raid"
	end
	return "other"
end

function Engine:NormalizeGlobalBucket(stored, legacy)
	return merge(self:GetGlobalDefaults(), stored or legacy)
end

function Engine:NormalizeActivityCatalog(
	source, categoryID, resolveActivityIDs, resolveLabel)
	local output = {}
	for index = 1, #(source or {}) do
		local original = source[index]
		local item = type(original) == "table" and copy(original)
			or { groupID = positiveID(original) }
		item.groupIDs = itemGroupIDs(item)
		item.groupID = positiveID(item.groupID) or item.groupIDs[1]
		item.key = optionKey(item)
		item.activityIDs = itemActivityIDs(item)
		if #item.activityIDs == 0 and item.groupID
			and type(resolveActivityIDs) == "function"
		then
			local ok, ids = pcall(resolveActivityIDs, item.groupID)
			if ok and type(ids) == "table" then
				local seen = {}
				item.activityIDs = {}
				appendArrayIDs(item.activityIDs, seen, ids)
			end
		end
		item.categoryID = item.categoryID or categoryID
		item.orderIndex = number(item.orderIndex) or index
		if not item.label and item.groupID and type(resolveLabel) == "function" then
			local ok, label = pcall(resolveLabel, item.groupID)
			if ok then
				item.label = label
			end
		end
		item.label = item.label or tostring(item.groupID or item.key or index)
		if item.key then
			output[#output + 1] = item
		end
	end
	return output
end

function Engine:GetOptionKey(item)
	return optionKey(item)
end

function Engine:GetItemGroupIDs(item)
	return itemGroupIDs(item)
end

function Engine:GetItemActivityIDs(item)
	return itemActivityIDs(item)
end

function Engine:BuildActivityPlan(items, state)
	items = type(items) == "table" and items or {}
	state = type(state) == "table" and state or {}
	local keys
	local persistence = {}
	if state.hasKeys then
		keys = sanitizeKeys(state.keys, items)
		persistence.writeKeys = true
		persistence.keys = copy(keys)
	elseif state.hasLegacy then
		keys = migrateGroupIDs(state.legacy, items)
		persistence.writeKeys = true
		persistence.keys = copy(keys)
		persistence.clearLegacy = true
	end

	local disabled = state.none == true
	local optionKeys = disabled and {} or copy(keys)
	local allSelected = allItemsSelected(optionKeys, items)
	local restricted = disabled
		or (type(optionKeys) == "table" and #optionKeys > 0 and not allSelected)
	local activitySet, known = {}, false
	if restricted and not disabled then
		local selected = selectedSet(optionKeys)
		for index = 1, #items do
			local item = items[index]
			local key = optionKey(item)
			if key and selected[tostring(key)] then
				for _, id in ipairs(itemActivityIDs(item)) do
					activitySet[id] = true
					known = true
				end
			end
		end
	end

	return {
		items = items,
		disabled = disabled,
		optionKeys = optionKeys,
		allSelected = allSelected,
		restricted = restricted,
		selectedKeys = selectedSet(optionKeys),
		activitySet = activitySet,
		activitySetKnown = known,
		persistence = persistence,
	}
end

function Engine:ActivitiesAllChecked(options, items)
	return allItemsSelected(options and options.activities, items)
end

function Engine:IsActivityEnabled(options, item, items)
	if type(options) ~= "table" or type(options.activities) ~= "table"
		or #options.activities == 0
	then
		return true
	end
	if allItemsSelected(options.activities, items) then
		return true
	end
	local key = optionKey(item)
	return key and selectedSet(options.activities)[tostring(key)] == true or false
end

function Engine:ToggleActivity(items, state, item, enabled)
	items = type(items) == "table" and items or {}
	local key = optionKey(item)
	if not key or not keySet(items)[tostring(key)] then
		return nil
	end
	local plan = self:BuildActivityPlan(items, state)
	local selected = {}
	if not plan.disabled
		and (type(plan.optionKeys) ~= "table" or #plan.optionKeys == 0
			or plan.allSelected)
	then
		for index = 1, #items do
			local current = optionKey(items[index])
			if current then
				selected[tostring(current)] = true
			end
		end
	else
		selected = selectedSet(plan.optionKeys)
	end
	selected[tostring(key)] = enabled == true or nil
	local keys = orderedSelection(items, selected)
	local count = #keys
	return {
		none = count == 0,
		keys = (count == 0 or count == #items) and {} or keys,
		legacy = nil,
		options = { activities = (count == 0 or count == #items) and {} or copy(keys) },
	}
end

function Engine:HasRestrictedActivities(plan)
	return type(plan) == "table" and plan.restricted == true
end

function Engine:MatchesActivityPlan(plan, resultActivityIDs)
	if type(plan) ~= "table" then
		return true
	end
	if plan.disabled then
		return false
	end
	if not plan.restricted then
		return true
	end
	if not plan.activitySetKnown then
		return false
	end
	local values = type(resultActivityIDs) == "table"
		and resultActivityIDs or { resultActivityIDs }
	local matched = false
	local ok = pcall(function()
		for index = 1, #values do
			local id = positiveID(values[index])
			if id and plan.activitySet[id] then
				matched = true
				return
			end
		end
	end)
	return ok and matched or false
end

function Engine:SelectDungeonDifficulty(values, selectedIndex, includeMplus)
	local fields = includeMplus and DUNGEON_DIFFICULTY_FIELDS or {
		DUNGEON_DIFFICULTY_FIELDS[1],
		DUNGEON_DIFFICULTY_FIELDS[2],
		DUNGEON_DIFFICULTY_FIELDS[3],
	}
	return selectExclusive(values, "dungeonDiffEn", fields, selectedIndex)
end

function Engine:SelectRaidDifficulty(values, selectedIndex)
	return selectExclusive(values, "raidDiffEn", RAID_DIFFICULTY_FIELDS, selectedIndex)
end

function Engine:GetDungeonDifficultyIndex(values, includeMplus)
	local fields = includeMplus and DUNGEON_DIFFICULTY_FIELDS or {
		DUNGEON_DIFFICULTY_FIELDS[1],
		DUNGEON_DIFFICULTY_FIELDS[2],
		DUNGEON_DIFFICULTY_FIELDS[3],
	}
	return selectedExclusiveIndex(values, "dungeonDiffEn", fields)
end

function Engine:GetRaidDifficultyIndex(values)
	return selectedExclusiveIndex(values, "raidDiffEn", RAID_DIFFICULTY_FIELDS)
end

function Engine:GetSelectionDifficultyIndex(kind, selection)
	-- GF navigation owns the exact activity scope. A browse preference therefore
	-- cannot be inferred from a parent or leaf without leaking into later scopes.
	return nil
end

function Engine:HasActivePlaystyleFilter(values)
	if type(values) ~= "table" then
		return false
	end
	for index = 1, 4 do
		if values["playstyle" .. index] == false then
			return true
		end
	end
	return false
end

function Engine:MatchesPlaystyle(values, playstyle, styles)
	if not self:HasActivePlaystyleFilter(values) then
		return true
	end
	styles = type(styles) == "table" and styles or {}
	local byIndex = {
		styles.Learning,
		styles.FunRelaxed,
		styles.FunSerious,
		styles.Expert,
	}
	for index = 1, 4 do
		if values["playstyle" .. index] ~= false
			and playstyle == byIndex[index]
		then
			return true
		end
	end
	return false
end

function Engine:IsPvPCategory(categoryID, categories)
	for _, category in ipairs(categories or {}) do
		if type(category) == "table" and category.id == categoryID then
			return true
		end
	end
	return false
end

function Engine:ResolveCategoryFilters(categoryID, filters, policy)
	policy = type(policy) == "table" and policy or {}
	if categoryID == policy.customCategory
		or categoryID == policy.delveCategory
		or self:IsPvPCategory(categoryID, policy.pvpCategories)
	then
		return 0
	end
	if categoryID == policy.dungeonCategory
		or categoryID == policy.raidCategory
	then
		filters = number(filters) or 0
		local mask = number(policy.recommendedMask) or 0
		local recommended = 0
		if type(policy.band) == "function" then
			local ok, value = pcall(policy.band, filters, mask)
			recommended = ok and (number(value) or 0) or 0
		end
		if recommended ~= 0 then
			return recommended
		end
		return number(policy.recommendedFlag) or filters
	end
	return number(filters) or 0
end

function Engine:ResolvePreferredFilters(categoryID, preferredFilters, policy)
	policy = type(policy) == "table" and policy or {}
	if categoryID == policy.customCategory then
		return 0
	end
	if preferredFilters ~= nil then
		return preferredFilters
	end
	return self:IsPvPCategory(categoryID, policy.pvpCategories)
		and policy.pvpFlag or policy.pveFlag
end

function Engine:CombineFlags(...)
	local result = 0
	for index = 1, select("#", ...) do
		local value = number(select(index, ...)) or 0
		if bit and type(bit.bor) == "function" then
			local ok, combined = pcall(bit.bor, result, value)
			result = ok and combined or result + value
		else
			result = result + value
		end
	end
	return result
end
