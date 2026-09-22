local _, GF = ...

-- Filter is the persistence and integration boundary for the GF filter model.
-- All value normalization and predicate decisions belong to FilterEngine;
-- this facade retains the established public API used by the UI and search.
local Filter = {}
GF.Filter = Filter

local Engine = assert(GF.FilterEngine, "GroupFinder: FilterEngine must load before Filter")

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

local DUNGEON_DIFFICULTY_FIELDS = {
	"dungeonDifficultyNormal",
	"dungeonDifficultyHeroic",
	"dungeonDifficultyMythic",
	"dungeonDifficultyMythicPlus",
}

local function getDB()
	local db = GF.GetDB and GF.GetDB() or nil
	return type(db) == "table" and db or {}
end

local function clone(value)
	return Engine:Copy(value)
end

local function safeValue(callback, ...)
	if type(callback) ~= "function" then
		return nil
	end
	local ok, value = pcall(callback, ...)
	return ok and value or nil
end

local function safeList(callback, ...)
	local value = safeValue(callback, ...)
	return type(value) == "table" and value or {}
end

local function categories()
	return {
		dungeon = GF.CAT_DUNGEON,
		raid = GF.CAT_RAID,
	}
end

local function replaceContents(target, source)
	for key in pairs(target) do
		target[key] = nil
	end
	for key, value in pairs(source or {}) do
		target[key] = clone(value)
	end
end

local function ensureClientStorage(db)
	db.filterClientByCategory = type(db.filterClientByCategory) == "table"
		and db.filterClientByCategory or {}
	db.filterClientBucketMigrated = type(db.filterClientBucketMigrated) == "table"
		and db.filterClientBucketMigrated or {}
	return db.filterClientByCategory, db.filterClientBucketMigrated
end

local function migrateClientBucket(db, key)
	local buckets, migration = ensureClientStorage(db)
	if migration[key] then
		return buckets
	end
	if buckets[key] == nil then
		buckets[key] = Engine:RecoverClientBucket(
			key, buckets, GF.clientFilterDefaults)
	end
	migration[key] = true
	return buckets
end

function Filter:GetClientFilters(key)
	key = key or "other"
	local db = getDB()
	local buckets = migrateClientBucket(db, key)
	return Engine:NormalizeClient(GF.clientFilterDefaults, buckets[key])
end

function Filter:SaveCategoryClientFilters(key, values)
	if not key or type(values) ~= "table" then
		return
	end
	local buckets = ensureClientStorage(getDB())
	buckets[key] = Engine:CompactClient(GF.clientFilterDefaults, values)
end

function Filter:GetMythicPlusBrowseFilters()
	return self:GetClientFilters(GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus")
end

function Filter:SaveMythicPlusBrowseFilters(values)
	self:SaveCategoryClientFilters(
		GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus", values)
end

function Filter:GetGlobalFilterKey(specOrSelection)
	return Engine:GetGlobalBucketKey(specOrSelection, categories())
end

local function legacyGlobalSnapshot(db)
	local legacy = Engine:GetGlobalDefaults()
	for key in pairs(legacy) do
		if db[key] ~= nil then
			legacy[key] = clone(db[key])
		end
	end
	return legacy
end

function Filter:GetGlobalFilters(specOrSelection)
	local db = getDB()
	db.filterGlobalByBucket = type(db.filterGlobalByBucket) == "table"
		and db.filterGlobalByBucket or {}
	local key = self:GetGlobalFilterKey(specOrSelection)
	if db.filterGlobalLegacyMigrated ~= true then
		db.filterGlobalByBucket[key] = Engine:NormalizeGlobalBucket(
			nil, legacyGlobalSnapshot(db))
		db.filterGlobalLegacyMigrated = true
		return db.filterGlobalByBucket[key]
	end
	local current = db.filterGlobalByBucket[key]
	local normalized = Engine:NormalizeGlobalBucket(current)
	if type(current) == "table" then
		for field, value in pairs(normalized) do
			if current[field] == nil then
				current[field] = clone(value)
			end
		end
		return current
	end
	db.filterGlobalByBucket[key] = normalized
	return normalized
end

local function nativeActivityGroups(categoryID, filters)
	return safeList(
		C_LFGList and C_LFGList.GetAvailableActivityGroups,
		categoryID, filters or 0)
end

local function nativeActivities(categoryID, groupID, filters)
	return safeList(
		C_LFGList and C_LFGList.GetAvailableActivities,
		categoryID, groupID, filters or 0)
end

local function activityResolver(categoryID, filters)
	return function(groupID)
		local output, seen = {}, {}
		local function append(values)
			for index = 1, #values do
				local id = tonumber(values[index])
				if id and id > 0 and not seen[id] then
					seen[id] = true
					output[#output + 1] = id
				end
			end
		end
		append(nativeActivities(categoryID, groupID, filters))
		local pve = Enum and Enum.LFGListFilter
			and Enum.LFGListFilter.PvE or 0
		append(nativeActivities(categoryID, groupID, pve))
		return output
	end
end

local function labelResolver(groupID)
	return safeValue(
		C_LFGList and C_LFGList.GetActivityGroupInfo, groupID)
end

local function catalogFromNavigation(kind, categoryID, filters)
	local provider = GF.NavData and GF.NavData.GetFilterActivityItems
	if type(provider) ~= "function" then
		return nil
	end
	local items = safeValue(provider, kind)
	if type(items) ~= "table" or #items == 0 then
		return nil
	end
	return Engine:NormalizeActivityCatalog(
		items, categoryID, activityResolver(categoryID, filters), labelResolver)
end

local function fallbackCatalog(categoryID, filters)
	return Engine:NormalizeActivityCatalog(
		nativeActivityGroups(categoryID, filters),
		categoryID,
		activityResolver(categoryID, filters),
		labelResolver)
end

function Filter:GetDungeonActivityItems()
	local flags = Enum and Enum.LFGListFilter or {}
	local filters = Engine:CombineFlags(flags.CurrentSeason, flags.PvE)
	return catalogFromNavigation(
		"season_dungeon", GF.CAT_DUNGEON, filters)
		or fallbackCatalog(GF.CAT_DUNGEON, filters)
end

function Filter:GetRaidActivityItems()
	local flags = Enum and Enum.LFGListFilter or {}
	local filters = Engine:CombineFlags(flags.Recommended, flags.PvE)
	return catalogFromNavigation(
		"season_raid", GF.CAT_RAID, filters)
		or fallbackCatalog(GF.CAT_RAID, filters)
end

local function setStoredList(field, values)
	getDB()[field] = values == nil and nil or clone(values)
end

function Filter:SetPersistedActivities(values)
	setStoredList("filterDungeonActivities", values)
end

function Filter:SetPersistedActivityKeys(values)
	setStoredList("filterDungeonActivityKeys", values)
end

function Filter:SetPersistedRaidActivities(values)
	setStoredList("filterRaidActivities", values)
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

local function activityState(kind, db)
	local storage = ACTIVITY_STORAGE[kind]
	db = type(db) == "table" and db or getDB()
	if db[storage.none] == true then
		return { none = true }
	end
	return {
		none = false,
		hasKeys = db[storage.keys] ~= nil,
		keys = db[storage.keys],
		hasLegacy = db[storage.legacy] ~= nil,
		legacy = db[storage.legacy],
	}
end

function Filter:GetActivityFilterSnapshot(kind)
	local storage = ACTIVITY_STORAGE[kind]
	if not storage then
		return {}
	end
	local db = getDB()
	return {
		[storage.none] = db[storage.none] == true and true or nil,
		[storage.keys] = db[storage.keys] == nil
			and nil or clone(db[storage.keys]),
		[storage.legacy] = db[storage.legacy] == nil
			and nil or clone(db[storage.legacy]),
	}
end

local function applyPlanPersistence(kind, plan, db)
	local storage = ACTIVITY_STORAGE[kind]
	local update = plan and plan.persistence or nil
	if not storage or type(update) ~= "table" then
		return
	end
	if update.writeKeys then
		db[storage.keys] = update.keys == nil and nil or clone(update.keys)
	end
	if update.clearLegacy then
		db[storage.legacy] = nil
	end
end

local function activityPlan(kind, items, db)
	db = type(db) == "table" and db or getDB()
	local plan = Engine:BuildActivityPlan(items, activityState(kind, db))
	applyPlanPersistence(kind, plan, db)
	return plan
end

local function activityOptions(kind, items, db)
	local plan = activityPlan(kind, items, db)
	return { activities = clone(plan.optionKeys) }
end

function Filter:GetDungeonActivityOptions(items)
	items = items or self:GetDungeonActivityItems()
	return activityOptions("dungeon", items)
end

function Filter:GetRaidActivityOptions(items)
	items = items or self:GetRaidActivityItems()
	return activityOptions("raid", items)
end

function Filter:ActivitiesAllChecked(options, items)
	items = items or self:GetDungeonActivityItems()
	return Engine:ActivitiesAllChecked(options, items)
end

function Filter:IsGroupEnabled(options, groupID, items)
	items = items or self:GetDungeonActivityItems()
	return Engine:IsActivityEnabled(options, groupID, items)
end

local function setStoredSelection(kind, options, groupID, enabled, items)
	local storage = ACTIVITY_STORAGE[kind]
	local db = getDB()
	local state = {
		none = db[storage.none] == true,
		hasKeys = true,
		keys = type(options) == "table" and options.activities or nil,
	}
	local updated = Engine:ToggleActivity(items, state, groupID, enabled)
	if not updated then
		return
	end
	db[storage.none] = updated.none and true or nil
	db[storage.keys] = clone(updated.keys)
	db[storage.legacy] = nil
	options.activities = clone(updated.options.activities)
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

function Filter:HasActiveDungeonActivityFilter(db, items)
	items = items or self:GetDungeonActivityItems()
	return Engine:HasRestrictedActivities(activityPlan("dungeon", items, db))
end

function Filter:HasActiveRaidActivityFilter(db, items)
	items = items or self:GetRaidActivityItems()
	return Engine:HasRestrictedActivities(activityPlan("raid", items, db))
end

function Filter:MatchesDungeonActivityFilter(db, activityIDs, items)
	items = items or self:GetDungeonActivityItems()
	return Engine:MatchesActivityPlan(
		activityPlan("dungeon", items, db), activityIDs)
end

function Filter:MatchesRaidActivityFilter(db, activityIDs, items)
	items = items or self:GetRaidActivityItems()
	return Engine:MatchesActivityPlan(
		activityPlan("raid", items, db), activityIDs)
end

function Filter:ResetAdvancedOptions()
	local native = safeValue(C_LFGList and C_LFGList.GetAdvancedFilter)
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
	if C_LFGList and type(C_LFGList.SaveAdvancedFilter) == "function" then
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
	for key, default in pairs(Engine:GetGlobalDefaults()) do
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
	local preservedDifficulty
	if spec.clientKey == "dungeon" and spec.showDungeonDifficulty ~= true then
		local current = self:GetClientFilters(spec.clientKey)
		preservedDifficulty = { dungeonDiffEn = current.dungeonDiffEn }
		for _, key in ipairs(DUNGEON_DIFFICULTY_FIELDS) do
			preservedDifficulty[key] = current[key]
		end
	end
	self:ResetCategoryClient(spec.clientKey)
	if preservedDifficulty then
		local reset = self:GetClientFilters(spec.clientKey)
		for key, value in pairs(preservedDifficulty) do
			reset[key] = value
		end
		self:SaveCategoryClientFilters(spec.clientKey, reset)
	end
	if spec.layoutTier == "api_max" then
		self:ResetAdvancedOptions()
	end
	self:ResetVisibleGlobalFilters(spec)
end

function Filter:HasActivePlaystyleFilter(db)
	return Engine:HasActivePlaystyleFilter(db)
end

function Filter:MatchesPlaystyleFilter(db, generalPlaystyle)
	local styles = Enum and Enum.LFGEntryGeneralPlaystyle or {}
	return Engine:MatchesPlaystyle(db, generalPlaystyle, styles)
end

function Filter:GetPlaystyleFilterLabel(index)
	if not index or index == 0 then
		local L = GF.L or {}
		return L.PLAYSTYLE_ANY or ALL or "All"
	end
	return _G["GROUP_FINDER_GENERAL_PLAYSTYLE" .. index]
		or ("Style " .. index)
end

function Filter:ApplyDifficultyToClient(client, selectedIndex, includeMplus)
	if type(client) ~= "table" then
		return
	end
	replaceContents(
		client,
		Engine:SelectDungeonDifficulty(client, selectedIndex, includeMplus))
end

function Filter:ApplyRaidDifficultyToClient(client, selectedIndex)
	if type(client) ~= "table" then
		return
	end
	replaceContents(client, Engine:SelectRaidDifficulty(client, selectedIndex))
end

function Filter:GetClientDifficultyIndex(client, includeMplus)
	return Engine:GetDungeonDifficultyIndex(client, includeMplus)
end

function Filter:GetSelectionDungeonDifficultyIndex(selection)
	return Engine:GetSelectionDifficultyIndex("dungeon", selection)
end

function Filter:SyncSelectionDungeonDifficulty(selection)
	local selectedIndex = self:GetSelectionDungeonDifficultyIndex(selection)
	if selectedIndex == nil
		or not (GF.FilterSpec and GF.FilterSpec.GetClientFilterKey)
	then
		return false
	end
	local clientKey = GF.FilterSpec:GetClientFilterKey(selection)
	local client = self:GetClientFilters(clientKey)
	if self:GetClientDifficultyIndex(client, true) ~= selectedIndex then
		self:ApplyDifficultyToClient(client, selectedIndex, true)
		self:SaveCategoryClientFilters(clientKey, client)
	end
	return true
end

function Filter:GetRaidDifficultyIndex(client)
	return Engine:GetRaidDifficultyIndex(client)
end

function Filter:GetSelectionRaidDifficultyIndex(selection)
	return Engine:GetSelectionDifficultyIndex("raid", selection)
end

function Filter:SyncSelectionRaidDifficulty(selection)
	local selectedIndex = self:GetSelectionRaidDifficultyIndex(selection)
	if selectedIndex == nil
		or not (GF.FilterSpec and GF.FilterSpec.GetClientFilterKey)
	then
		return false
	end
	local clientKey = GF.FilterSpec:GetClientFilterKey(selection)
	local client = self:GetClientFilters(clientKey)
	if self:GetRaidDifficultyIndex(client) ~= selectedIndex then
		self:ApplyRaidDifficultyToClient(client, selectedIndex)
		self:SaveCategoryClientFilters(clientKey, client)
	end
	return true
end

local function searchPolicy()
	local flags = Enum and Enum.LFGListFilter or {}
	return {
		customCategory = GF.CAT_CUSTOM,
		delveCategory = GF.CAT_DELVE,
		dungeonCategory = GF.CAT_DUNGEON,
		raidCategory = GF.CAT_RAID,
		pvpCategories = GF.PVP_CATEGORIES,
		recommendedMask = GF.RECOMMENDED_SEARCH_MASK or 0,
		recommendedFlag = flags.Recommended,
		pvpFlag = flags.PvP,
		pveFlag = flags.PvE,
		band = bit and bit.band,
	}
end

function Filter:ResolveCategoryFilters(categoryID, filters)
	return Engine:ResolveCategoryFilters(categoryID, filters, searchPolicy())
end

function Filter:ResolvePreferredFilters(categoryID, preferredFilters)
	return Engine:ResolvePreferredFilters(
		categoryID, preferredFilters, searchPolicy())
end

function Filter:ApplyClientFilterRefresh()
	if GF.FindGroupTab and GF.FindGroupTab.ApplyClientFilters then
		GF.FindGroupTab:ApplyClientFilters()
	end
end
