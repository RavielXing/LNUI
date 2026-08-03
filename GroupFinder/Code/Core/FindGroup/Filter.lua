local _, GF = ...

local Filter = {}
GF.Filter = Filter

local RECOMMENDED_SEARCH_MASK = GF.RECOMMENDED_SEARCH_MASK or 0
local CLIENT_KEY_ALIASES = {
	dungeon = { "2" },
	raid = { "3" },
	other = { "121", "1", "6_pve", "6_pvp", "6", "8", "4", "9", "7", "0" },
}
local GLOBAL_DEFAULTS = {}
for _, key in ipairs({
	"sameClass", "zeroScore", "rangeAgeEn", "rangeIlvlEn",
	"rangeHonorEn", "hideVoice", "hideCrossRealm", "sameFactionOnly",
	"rangeMplusScoreEn",
}) do
	GLOBAL_DEFAULTS[key] = false
end
for _, key in ipairs({
	"maxAgeMin", "minIlvl", "rangeAgeMin", "rangeAgeMax",
	"rangeIlvlMin", "rangeIlvlMax", "rangeHonorMin", "rangeHonorMax",
	"rangeMplusScoreMin", "rangeMplusScoreMax",
}) do
	GLOBAL_DEFAULTS[key] = 0
end
for index = 1, 4 do
	GLOBAL_DEFAULTS["playstyle" .. index] = true
end
for _, key in ipairs({
	"showFriendGroups", "showGuildGroups", "showHousewarmingGroups",
}) do
	GLOBAL_DEFAULTS[key] = true
end

local ACTIVITY_STORAGE = {
	dungeon = {
		keys = "filterDungeonActivityKeys",
		legacy = "filterDungeonActivities",
		none = "filterDungeonNone",
	},
	raid = {
		keys = "filterRaidActivityKeys",
		legacy = "filterRaidActivities",
		none = "filterRaidNone",
	},
}

local function clone(value, visited)
	if type(value) ~= "table" then
		return value
	end
	visited = visited or {}
	if visited[value] then
		return visited[value]
	end
	local copy = {}
	visited[value] = copy
	for key, child in pairs(value) do
		copy[clone(key, visited)] = clone(child, visited)
	end
	return copy
end

local function getDB()
	local db = GF.GetDB and GF.GetDB() or nil
	return type(db) == "table" and db or {}
end

local function callValue(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	return ok and value or nil
end

local function callList(fn, ...)
	local value = callValue(fn, ...)
	return type(value) == "table" and value or {}
end

local function numericID(value)
	local ok, number = pcall(tonumber, value)
	if not ok or not number or number <= 0 then
		return nil
	end
	return number
end

local function insertUnique(list, seen, value)
	local id = numericID(value)
	if id and not seen[id] then
		seen[id] = true
		list[#list + 1] = id
	end
end

local function isPvPCategory(categoryID)
	for _, category in ipairs(GF.PVP_CATEGORIES or {}) do
		if categoryID == category.id then
			return true
		end
	end
	return false
end

local function mergeDefaults(defaults, stored)
	local values = clone(defaults or {})
	if type(stored) == "table" then
		for key, value in pairs(stored) do
			values[key] = clone(value)
		end
	end
	return values
end

local function compactClient(values)
	if type(values) ~= "table" then
		return nil
	end
	local defaults = GF.clientFilterDefaults or {}
	local stored = {}
	for key, value in pairs(values) do
		if defaults[key] == nil or value ~= defaults[key] then
			stored[key] = clone(value)
		end
	end
	return next(stored) and stored or nil
end

local function migrateSingleValueRange(values, oldKey, minimumKey, maximumKey)
	local legacy = tonumber(values and values[oldKey]) or 0
	if legacy > 0
		and (tonumber(values[minimumKey]) or 0) <= 0
		and (tonumber(values[maximumKey]) or 0) <= 0
	then
		values[minimumKey] = legacy
		values[maximumKey] = legacy
	end
	values[oldKey] = 0
end

local function migrateClientBucket(db, key)
	db.filterClientByCategory = type(db.filterClientByCategory) == "table"
		and db.filterClientByCategory or {}
	db.filterClientBucketMigrated = type(db.filterClientBucketMigrated) == "table"
		and db.filterClientBucketMigrated or {}
	if db.filterClientBucketMigrated[key] then
		return
	end
	if db.filterClientByCategory[key] == nil then
		local recovered = {}
		for _, oldKey in ipairs(CLIENT_KEY_ALIASES[key] or {}) do
			local oldValues = db.filterClientByCategory[oldKey]
			if type(oldValues) == "table" then
				for field, value in pairs(oldValues) do
					if recovered[field] == nil then
						recovered[field] = clone(value)
					end
				end
			end
		end
		db.filterClientByCategory[key] = compactClient(recovered)
	end
	db.filterClientBucketMigrated[key] = true
end

local function globalBucketName(specOrSelection)
	if type(specOrSelection) ~= "table" then
		return "other"
	end
	if specOrSelection.clientKey == "dungeon" or specOrSelection.clientKey == "raid" then
		return specOrSelection.clientKey
	end
	local categoryID = specOrSelection.categoryID
	if categoryID == nil and type(specOrSelection.selection) == "table" then
		categoryID = specOrSelection.selection.categoryID
	end
	if categoryID == GF.CAT_DUNGEON then
		return "dungeon"
	elseif categoryID == GF.CAT_RAID then
		return "raid"
	end
	return "other"
end

local function legacyGlobalValues(db)
	local values = clone(GLOBAL_DEFAULTS)
	for key in pairs(GLOBAL_DEFAULTS) do
		if db[key] ~= nil then
			values[key] = clone(db[key])
		end
	end
	return values
end

function Filter:GetClientFilters(key)
	key = key or "other"
	local db = getDB()
	migrateClientBucket(db, key)
	local values = mergeDefaults(
		GF.clientFilterDefaults, db.filterClientByCategory[key])
	migrateSingleValueRange(
		values, "raidMemberCount", "raidMemberCountMin", "raidMemberCountMax")
	migrateSingleValueRange(
		values, "raidBossKills", "raidBossKillsMin", "raidBossKillsMax")
	return values
end

function Filter:SaveCategoryClientFilters(key, values)
	if not key or type(values) ~= "table" then
		return
	end
	local db = getDB()
	db.filterClientByCategory = type(db.filterClientByCategory) == "table"
		and db.filterClientByCategory or {}
	db.filterClientByCategory[key] = compactClient(values)
end

function Filter:GetMythicPlusBrowseFilters()
	return self:GetClientFilters(GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus")
end

function Filter:SaveMythicPlusBrowseFilters(values)
	self:SaveCategoryClientFilters(
		GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus", values)
end

function Filter:GetGlobalFilterKey(specOrSelection)
	return globalBucketName(specOrSelection)
end

function Filter:GetGlobalFilters(specOrSelection)
	local db = getDB()
	db.filterGlobalByBucket = type(db.filterGlobalByBucket) == "table"
		and db.filterGlobalByBucket or {}
	local key = self:GetGlobalFilterKey(specOrSelection)
	if db.filterGlobalLegacyMigrated ~= true then
		db.filterGlobalByBucket[key] = legacyGlobalValues(db)
		db.filterGlobalLegacyMigrated = true
	end
	local bucket = db.filterGlobalByBucket[key]
	if type(bucket) ~= "table" then
		bucket = clone(GLOBAL_DEFAULTS)
		db.filterGlobalByBucket[key] = bucket
	else
		for field, default in pairs(GLOBAL_DEFAULTS) do
			if bucket[field] == nil then
				bucket[field] = clone(default)
			end
		end
	end
	return bucket
end

local function activityKeyForGroup(groupID)
	groupID = numericID(groupID)
	return groupID and ("g:" .. groupID) or nil
end

local function itemKey(item)
	if type(item) == "table" then
		return item.key or activityKeyForGroup(item.groupID)
	end
	if type(item) == "string" then
		return item
	end
	return activityKeyForGroup(item)
end

local function itemGroupIDs(item)
	local ids, seen = {}, {}
	if type(item) == "table" then
		for _, groupID in ipairs(item.groupIDs or {}) do
			insertUnique(ids, seen, groupID)
		end
		insertUnique(ids, seen, item.groupID)
	else
		insertUnique(ids, seen, item)
	end
	return ids
end

local function itemActivityIDs(item)
	local ids, seen = {}, {}
	if type(item) == "table" then
		for _, activityID in ipairs(item.activityIDs or {}) do
			insertUnique(ids, seen, activityID)
		end
		insertUnique(ids, seen, item.activityID)
	end
	return ids
end

local function availableGroups(categoryID, filters)
	return callList(
		C_LFGList and C_LFGList.GetAvailableActivityGroups,
		categoryID, filters or 0)
end

local function availableActivities(categoryID, groupID, filters)
	return callList(
		C_LFGList and C_LFGList.GetAvailableActivities,
		categoryID, groupID, filters or 0)
end

local function collectGroupActivities(categoryID, groupID, filters)
	local ids, seen = {}, {}
	for _, activityID in ipairs(availableActivities(categoryID, groupID, filters)) do
		insertUnique(ids, seen, activityID)
	end
	local pve = Enum and Enum.LFGListFilter and Enum.LFGListFilter.PvE or 0
	for _, activityID in ipairs(availableActivities(categoryID, groupID, pve)) do
		insertUnique(ids, seen, activityID)
	end
	return ids
end

local function normalizeCatalogItems(source, categoryID, filters)
	local items = {}
	for index, sourceItem in ipairs(source or {}) do
		local item
		if type(sourceItem) == "table" then
			item = clone(sourceItem)
		else
			item = { groupID = numericID(sourceItem) }
		end
		item.groupIDs = itemGroupIDs(item)
		item.groupID = numericID(item.groupID) or item.groupIDs[1]
		item.key = itemKey(item)
		item.activityIDs = itemActivityIDs(item)
		if #item.activityIDs == 0 and item.groupID then
			item.activityIDs = collectGroupActivities(
				categoryID, item.groupID, filters)
		end
		item.categoryID = item.categoryID or categoryID
		item.orderIndex = tonumber(item.orderIndex) or index
		if not item.label and item.groupID then
			item.label = callValue(
				C_LFGList and C_LFGList.GetActivityGroupInfo, item.groupID)
		end
		item.label = item.label or tostring(item.groupID or item.key or index)
		if item.key then
			items[#items + 1] = item
		end
	end
	return items
end

local function catalogFromNavigation(kind, categoryID, filters)
	local provider = GF.NavData and GF.NavData.GetFilterActivityItems
	if type(provider) ~= "function" then
		return nil
	end
	local ok, items = pcall(provider, kind)
	if not ok or type(items) ~= "table" or #items == 0 then
		return nil
	end
	return normalizeCatalogItems(items, categoryID, filters)
end

local function fallbackCatalog(categoryID, filters)
	return normalizeCatalogItems(
		availableGroups(categoryID, filters), categoryID, filters)
end

local function combineFilters(...)
	local result = 0
	for index = 1, select("#", ...) do
		local selected = select(index, ...)
		local value = tonumber(selected) or 0
		if bit and bit.bor then
			result = bit.bor(result, value)
		else
			result = result + value
		end
	end
	return result
end

function Filter:GetDungeonActivityItems()
	local flags = Enum and Enum.LFGListFilter or {}
	local filters = combineFilters(flags.CurrentSeason, flags.PvE)
	return catalogFromNavigation(
		"season_dungeon", GF.CAT_DUNGEON, filters)
		or fallbackCatalog(GF.CAT_DUNGEON, filters)
end

function Filter:GetRaidActivityItems()
	local flags = Enum and Enum.LFGListFilter or {}
	local filters = combineFilters(flags.Recommended, flags.PvE)
	return catalogFromNavigation(
		"season_raid", GF.CAT_RAID, filters)
		or fallbackCatalog(GF.CAT_RAID, filters)
end

local function collectGroupIDs(items)
	local ids, seen = {}, {}
	for _, item in ipairs(items or {}) do
		for _, groupID in ipairs(itemGroupIDs(item)) do
			insertUnique(ids, seen, groupID)
		end
	end
	return ids
end

local function navGroupIDs(kind)
	local provider = GF.NavData and GF.NavData.GetFilterActivityGroupIDs
	if type(provider) ~= "function" then
		return {}
	end
	local ok, ids = pcall(provider, kind)
	return ok and type(ids) == "table" and ids or {}
end

function Filter:GetDungeonGroupIDs()
	local ids = collectGroupIDs(self:GetDungeonActivityItems())
	return #ids > 0 and ids or navGroupIDs("season_dungeon")
end

function Filter:GetDelveGroupIDs()
	local flags = Enum and Enum.LFGListFilter or {}
	return availableGroups(
		GF.CAT_DELVE, combineFilters(flags.CurrentExpansion, flags.PvE))
end

function Filter:GetRaidGroupIDs()
	local ids = collectGroupIDs(self:GetRaidActivityItems())
	return #ids > 0 and ids or navGroupIDs("season_raid")
end

local function validKeySet(items)
	local set = {}
	for _, item in ipairs(items or {}) do
		local key = itemKey(item)
		if key then
			set[tostring(key)] = true
		end
	end
	return set
end

local function sanitizeKeys(saved, items)
	if type(saved) ~= "table" then
		return nil
	end
	if #saved == 0 then
		return {}
	end
	local valid = validKeySet(items)
	local keys, seen = {}, {}
	for _, savedKey in ipairs(saved) do
		local key = tostring(savedKey)
		if valid[key] and not seen[key] then
			seen[key] = true
			keys[#keys + 1] = key
		end
	end
	return #keys > 0 and keys or nil
end

local function migrateGroupIDs(groupIDs, items)
	if type(groupIDs) ~= "table" or #groupIDs == 0 then
		return nil
	end
	local wanted = {}
	for _, groupID in ipairs(groupIDs) do
		groupID = numericID(groupID)
		if groupID then
			wanted[groupID] = true
		end
	end
	local keys, seen = {}, {}
	for _, item in ipairs(items or {}) do
		local key = itemKey(item)
		for _, groupID in ipairs(itemGroupIDs(item)) do
			if key and wanted[groupID] and not seen[key] then
				seen[key] = true
				keys[#keys + 1] = key
			end
		end
	end
	return #keys > 0 and keys or nil
end

local function setStoredList(field, values)
	local db = getDB()
	db[field] = values == nil and nil or clone(values)
end

function Filter:GetPersistedActivities()
	return getDB().filterDungeonActivities
end

function Filter:SetPersistedActivities(values)
	setStoredList("filterDungeonActivities", values)
end

function Filter:GetPersistedActivityKeys()
	return getDB().filterDungeonActivityKeys
end

function Filter:SetPersistedActivityKeys(values)
	setStoredList("filterDungeonActivityKeys", values)
end

function Filter:GetPersistedDelveActivities()
	return getDB().filterDelveActivities
end

function Filter:SetPersistedDelveActivities(values)
	setStoredList("filterDelveActivities", values)
end

function Filter:GetPersistedRaidActivities()
	return getDB().filterRaidActivities
end

function Filter:SetPersistedRaidActivities(values)
	setStoredList("filterRaidActivities", values)
end

function Filter:GetPersistedRaidActivityKeys()
	return getDB().filterRaidActivityKeys
end

function Filter:SetPersistedRaidActivityKeys(values)
	setStoredList("filterRaidActivityKeys", values)
end

local function allDisabled(kind, db)
	local storage = ACTIVITY_STORAGE[kind]
	db = type(db) == "table" and db or getDB()
	return storage and db[storage.none] == true or false
end

local function setAllDisabled(kind, disabled)
	local storage = ACTIVITY_STORAGE[kind]
	if storage then
		getDB()[storage.none] = disabled and true or nil
	end
end

function Filter:IsAllDungeonGroupsDisabled()
	return allDisabled("dungeon")
end

function Filter:SetAllDungeonGroupsDisabled(disabled)
	setAllDisabled("dungeon", disabled)
end

function Filter:IsAllRaidGroupsDisabled()
	return allDisabled("raid")
end

function Filter:SetAllRaidGroupsDisabled(disabled)
	setAllDisabled("raid", disabled)
end

local function activityOptions(kind, items, db)
	local storage = ACTIVITY_STORAGE[kind]
	db = type(db) == "table" and db or getDB()
	if db[storage.none] == true then
		return { activities = {} }
	end
	local keys = db[storage.keys]
	if keys ~= nil then
		local cleaned = sanitizeKeys(keys, items)
		db[storage.keys] = cleaned == nil and nil or clone(cleaned)
		return { activities = cleaned and clone(cleaned) or nil }
	end
	if db[storage.legacy] ~= nil then
		local migrated = migrateGroupIDs(db[storage.legacy], items)
		db[storage.legacy] = nil
		db[storage.keys] = migrated and clone(migrated) or nil
		return { activities = migrated and clone(migrated) or nil }
	end
	return { activities = nil }
end

function Filter:GetDungeonActivityOptions(items)
	return activityOptions("dungeon", items or self:GetDungeonActivityItems())
end

function Filter:GetRaidActivityOptions(items)
	return activityOptions("raid", items or self:GetRaidActivityItems())
end

function Filter:SanitizeActivityGroupList(saved, allGroups)
	if type(saved) ~= "table" then
		return nil
	end
	if #saved == 0 then
		return {}
	end
	local valid = {}
	for _, groupID in ipairs(allGroups or {}) do
		valid[groupID] = true
	end
	local cleaned = {}
	for _, groupID in ipairs(saved) do
		if valid[groupID] then
			cleaned[#cleaned + 1] = groupID
		end
	end
	return #cleaned > 0 and cleaned or nil
end

local function normalizedOptionKey(value)
	if type(value) == "table" then
		return itemKey(value)
	end
	if type(value) == "string" then
		return value
	end
	return activityKeyForGroup(value)
end

local function selectedKeySet(options)
	local set = {}
	for _, key in ipairs(options and options.activities or {}) do
		set[tostring(key)] = true
	end
	return set
end

function Filter:ActivitiesAllChecked(options, items)
	items = items or self:GetDungeonActivityItems()
	if type(options) ~= "table" or type(options.activities) ~= "table"
		or #options.activities == 0 or type(items) ~= "table" or #items == 0
	then
		return false
	end
	local selected = selectedKeySet(options)
	for _, item in ipairs(items) do
		local key = itemKey(item)
		if not key or not selected[tostring(key)] then
			return false
		end
	end
	return true
end

function Filter:IsGroupEnabled(options, groupID, items)
	if type(options) ~= "table" or type(options.activities) ~= "table"
		or #options.activities == 0
	then
		return true
	end
	items = items or self:GetDungeonActivityItems()
	if self:ActivitiesAllChecked(options, items) then
		return true
	end
	local key = normalizedOptionKey(groupID)
	return key and selectedKeySet(options)[tostring(key)] == true or false
end

local function orderedSelection(items, selected)
	local keys = {}
	for _, item in ipairs(items or {}) do
		local key = itemKey(item)
		if key and selected[tostring(key)] then
			keys[#keys + 1] = tostring(key)
		end
	end
	return keys
end

local function selectionMap(options, items, startEmpty)
	local selected = {}
	if not startEmpty
		and (type(options.activities) ~= "table" or #options.activities == 0
			or Filter:ActivitiesAllChecked(options, items))
	then
		for _, item in ipairs(items or {}) do
			local key = itemKey(item)
			if key then
				selected[tostring(key)] = true
			end
		end
	else
		for _, key in ipairs(options.activities or {}) do
			selected[tostring(key)] = true
		end
	end
	return selected
end

function Filter:SetGroupEnabled(options, groupID, enabled, items, persist)
	if type(options) ~= "table" then
		return
	end
	items = items or self:GetDungeonActivityItems()
	local selected = selectionMap(options, items, false)
	local key = normalizedOptionKey(groupID)
	if key then
		selected[tostring(key)] = enabled == true or nil
	end
	local keys = orderedSelection(items, selected)
	options.activities = (#keys == #items) and {} or keys
	if persist then
		persist(clone(options.activities))
	end
end

local function setStoredSelection(kind, options, groupID, enabled, items)
	local storage = ACTIVITY_STORAGE[kind]
	local db = getDB()
	local selected = selectionMap(
		options, items, db[storage.none] == true)
	local key = normalizedOptionKey(groupID)
	if key then
		selected[tostring(key)] = enabled == true or nil
	end
	local keys = orderedSelection(items, selected)
	local count = #keys
	if count == 0 then
		db[storage.none] = true
		db[storage.keys] = {}
		options.activities = {}
	elseif count == #items then
		db[storage.none] = nil
		db[storage.keys] = {}
		options.activities = {}
	else
		db[storage.none] = nil
		db[storage.keys] = clone(keys)
		options.activities = keys
	end
	db[storage.legacy] = nil
end

function Filter:SetDungeonGroupEnabled(options, groupID, enabled, items)
	if type(options) == "table" then
		setStoredSelection(
			"dungeon", options, groupID, enabled,
			items or self:GetDungeonActivityItems())
	end
end

function Filter:SetRaidGroupEnabled(options, groupID, enabled, items)
	if type(options) == "table" then
		setStoredSelection(
			"raid", options, groupID, enabled,
			items or self:GetRaidActivityItems())
	end
end

local function hasRestrictedActivitySelection(kind, items, db)
	if allDisabled(kind, db) then
		return true
	end
	local options = activityOptions(kind, items, db)
	if type(options.activities) ~= "table" or #options.activities == 0 then
		return false
	end
	return not Filter:ActivitiesAllChecked(options, items)
end

function Filter:HasActiveDungeonActivityFilter(db, items)
	items = items or self:GetDungeonActivityItems()
	return #items > 0 and hasRestrictedActivitySelection("dungeon", items, db)
		or allDisabled("dungeon", db)
end

function Filter:HasActiveRaidActivityFilter(db, items)
	items = items or self:GetRaidActivityItems()
	return #items > 0 and hasRestrictedActivitySelection("raid", items, db)
		or allDisabled("raid", db)
end

local function selectedActivityIDs(kind, items, db)
	local options = activityOptions(kind, items, db)
	if type(options.activities) ~= "table" or #options.activities == 0
		or Filter:ActivitiesAllChecked(options, items)
	then
		return nil, false
	end
	local selectedKeys = selectedKeySet(options)
	local activitySet = {}
	local known = false
	for _, item in ipairs(items or {}) do
		local key = itemKey(item)
		if key and selectedKeys[tostring(key)] then
			for _, activityID in ipairs(itemActivityIDs(item)) do
				activitySet[activityID] = true
				known = true
			end
		end
	end
	return activitySet, known
end

local function matchesActivitySelection(kind, resultActivityIDs, items, db)
	if allDisabled(kind, db) then
		return false
	end
	if not hasRestrictedActivitySelection(kind, items, db) then
		return true
	end
	local selected, known = selectedActivityIDs(kind, items, db)
	if not known then
		return true
	end
	local readable = false
	for _, value in ipairs(type(resultActivityIDs) == "table"
		and resultActivityIDs or { resultActivityIDs })
	do
		local activityID = numericID(value)
		if activityID then
			readable = true
			if selected[activityID] then
				return true
			end
		end
	end
	return not readable
end

function Filter:MatchesDungeonActivityFilter(db, activityIDs, items)
	items = items or self:GetDungeonActivityItems()
	return matchesActivitySelection("dungeon", activityIDs, items, db)
end

function Filter:MatchesRaidActivityFilter(db, activityIDs, items)
	items = items or self:GetRaidActivityItems()
	return matchesActivitySelection("raid", activityIDs, items, db)
end

function Filter:GetAdvancedOptions()
	local options = callValue(C_LFGList and C_LFGList.GetAdvancedFilter)
	if type(options) ~= "table" then
		return nil
	end
	options = clone(options)
	options.activities = {}
	options.needsMyClass = false
	options.hasTank = false
	options.hasHealer = false
	if options.difficultyNormal ~= nil then
		options.difficultyNormal = true
		options.difficultyHeroic = true
		options.difficultyMythic = true
		options.difficultyMythicPlus = true
	end
	return options
end

function Filter:SaveAdvancedOptions(options)
	if type(options) ~= "table"
		or not (C_LFGList and C_LFGList.SaveAdvancedFilter)
	then
		return
	end
	local native = clone(options)
	native.activities = {}
	native.needsMyClass = false
	native.hasTank = false
	native.hasHealer = false
	pcall(C_LFGList.SaveAdvancedFilter, native)
end

function Filter:ApplyPersistedAdvancedFilter()
	-- Activity choices and GroupFinder-only conditions are evaluated locally.
end

function Filter:ResetAdvancedOptions()
	local native = callValue(C_LFGList and C_LFGList.GetAdvancedFilter)
	if type(native) ~= "table" then
		return
	end
	native = clone(native)
	for _, key in ipairs({
		"needsTank", "needsHealer", "needsDamage", "needsMyClass",
		"hasTank", "hasHealer",
	}) do
		native[key] = false
	end
	native.minimumRating = 0
	native.activities = {}
	if native.difficultyNormal ~= nil then
		native.difficultyNormal = true
		native.difficultyHeroic = true
		native.difficultyMythic = true
		native.difficultyMythicPlus = true
	end
	self:SetAllDungeonGroupsDisabled(false)
	self:SetPersistedActivities(nil)
	self:SetPersistedActivityKeys(nil)
	self:SetAllRaidGroupsDisabled(false)
	self:SetPersistedRaidActivities(nil)
	self:SetPersistedRaidActivityKeys(nil)
	if C_LFGList and C_LFGList.SaveAdvancedFilter then
		pcall(C_LFGList.SaveAdvancedFilter, native)
	end
end

function Filter:ResetCategoryClient(key)
	local db = getDB()
	if key and type(db.filterClientByCategory) == "table" then
		db.filterClientByCategory[key] = nil
	end
end

function Filter:ResetMythicPlusBrowseFilters()
	self:ResetCategoryClient(GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus")
end

function Filter:ResetVisibleGlobalFilters(spec)
	local values = self:GetGlobalFilters(spec)
	for key, default in pairs(GLOBAL_DEFAULTS) do
		values[key] = clone(default)
	end
	values.filterRoleMatchAll = false
	if spec and spec.showDungeonActivities then
		self:SetAllDungeonGroupsDisabled(false)
		self:SetPersistedActivities(nil)
		self:SetPersistedActivityKeys(nil)
	end
	if spec and spec.showRaidActivities then
		self:SetAllRaidGroupsDisabled(false)
		self:SetPersistedRaidActivities(nil)
		self:SetPersistedRaidActivityKeys(nil)
	end
end

function Filter:ResetCategory(selection)
	local spec = selection and GF.FilterSpec
		and GF.FilterSpec:ResolveSpec(selection) or nil
	if not spec then
		return
	end
	self:ResetCategoryClient(spec.clientKey)
	if spec.layoutTier == "api_max" then
		self:ResetAdvancedOptions()
	end
	self:ResetVisibleGlobalFilters(spec)
end

local function selectedPlaystyle(index)
	local styles = Enum and Enum.LFGEntryGeneralPlaystyle or {}
	if index == 1 then
		return styles.Learning
	elseif index == 2 then
		return styles.FunRelaxed
	elseif index == 3 then
		return styles.FunSerious
	elseif index == 4 then
		return styles.Expert
	end
	return nil
end

function Filter:HasActivePlaystyleFilter(db)
	if type(db) ~= "table" then
		return false
	end
	for index = 1, 4 do
		if db["playstyle" .. index] == false then
			return true
		end
	end
	return false
end

function Filter:MatchesPlaystyleFilter(db, generalPlaystyle)
	if not self:HasActivePlaystyleFilter(db) then
		return true
	end
	for index = 1, 4 do
		if db["playstyle" .. index] ~= false then
			if generalPlaystyle == selectedPlaystyle(index) then
				return true
			end
		end
	end
	return false
end

function Filter:GetPlaystyleFilterLabel(index)
	if not index or index == 0 then
		local L = GF.L or {}
		return L.PLAYSTYLE_ANY or ALL or "All"
	end
	return _G["GROUP_FINDER_GENERAL_PLAYSTYLE" .. index]
		or ("Style " .. index)
end

local function applyExclusive(values, enabledKey, keys, selectedIndex)
	local any = not selectedIndex or selectedIndex == 0
	values[enabledKey] = not any
	for index, key in ipairs(keys) do
		values[key] = any or selectedIndex == index
	end
end

local function exclusiveIndex(values, enabledKey, keys)
	if type(values) ~= "table" or not values[enabledKey] then
		return 0
	end
	local found
	for index, key in ipairs(keys) do
		if values[key] then
			if found then
				return 0
			end
			found = index
		end
	end
	return found or 0
end

local DUNGEON_DIFFICULTIES = {
	"dungeonDifficultyNormal",
	"dungeonDifficultyHeroic",
	"dungeonDifficultyMythic",
	"dungeonDifficultyMythicPlus",
}
local RAID_DIFFICULTIES = {
	"raidDifficultyNormal",
	"raidDifficultyHeroic",
	"raidDifficultyMythic",
}
local NATIVE_DIFFICULTIES = {
	"difficultyNormal",
	"difficultyHeroic",
	"difficultyMythic",
	"difficultyMythicPlus",
}

function Filter:ApplyDifficultyToClient(client, selectedIndex, includeMplus)
	if type(client) ~= "table" then
		return
	end
	local keys = includeMplus and DUNGEON_DIFFICULTIES or {
		DUNGEON_DIFFICULTIES[1], DUNGEON_DIFFICULTIES[2], DUNGEON_DIFFICULTIES[3],
	}
	applyExclusive(client, "dungeonDiffEn", keys, selectedIndex)
end

function Filter:ApplyRaidDifficultyToClient(client, selectedIndex)
	if type(client) == "table" then
		applyExclusive(client, "raidDiffEn", RAID_DIFFICULTIES, selectedIndex)
	end
end

function Filter:GetClientDifficultyIndex(client, includeMplus)
	local keys = includeMplus and DUNGEON_DIFFICULTIES or {
		DUNGEON_DIFFICULTIES[1], DUNGEON_DIFFICULTIES[2], DUNGEON_DIFFICULTIES[3],
	}
	return exclusiveIndex(client, "dungeonDiffEn", keys)
end

function Filter:GetRaidDifficultyIndex(client)
	return exclusiveIndex(client, "raidDiffEn", RAID_DIFFICULTIES)
end

function Filter:ApplyDifficultyToAdvanced(options, selectedIndex)
	if type(options) ~= "table" then
		return
	end
	local anyDifficulty = not selectedIndex or selectedIndex == 0
	for index, key in ipairs(NATIVE_DIFFICULTIES) do
		options[key] = anyDifficulty or selectedIndex == index
	end
end

function Filter:GetDifficultyIndex(options)
	if type(options) ~= "table" or options.difficultyNormal == nil then
		return 0
	end
	local found
	for index, key in ipairs(NATIVE_DIFFICULTIES) do
		if options[key] then
			if found then
				return 0
			end
			found = index
		end
	end
	return found or 0
end

function Filter:ResolveCategoryFilters(categoryID, filters)
	if categoryID == GF.CAT_CUSTOM or categoryID == GF.CAT_DELVE
		or isPvPCategory(categoryID)
	then
		return 0
	end
	if categoryID == GF.CAT_DUNGEON or categoryID == GF.CAT_RAID then
		filters = tonumber(filters) or 0
		local recommended = bit and bit.band
			and bit.band(filters, RECOMMENDED_SEARCH_MASK) or 0
		if recommended ~= 0 then
			return recommended
		end
		return Enum and Enum.LFGListFilter
			and Enum.LFGListFilter.Recommended or filters
	end
	return tonumber(filters) or 0
end

function Filter:ResolvePreferredFilters(categoryID, preferredFilters)
	if categoryID == GF.CAT_CUSTOM then
		return 0
	end
	if preferredFilters ~= nil then
		return preferredFilters
	end
	local flags = Enum and Enum.LFGListFilter or {}
	return isPvPCategory(categoryID) and flags.PvP or flags.PvE
end

function Filter:ApplyClientFilterRefresh()
	if GF.FindGroupTab and GF.FindGroupTab.ApplyClientFilters then
		GF.FindGroupTab:ApplyClientFilters()
	end
end
