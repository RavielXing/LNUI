local _, GF = ...

GF.Filter = {}

local RECOMMENDED_SEARCH_MASK = bit.bor(Enum.LFGListFilter.Recommended, Enum.LFGListFilter.NotRecommended)
local LEGACY_CLIENT_FILTER_KEYS = {
	dungeon = { "2" },
	raid = { "3" },
	other = { "121", "1", "6_pve", "6_pvp", "6", "8", "4", "9", "7", "0" },
}
local GLOBAL_FILTER_DEFAULTS = {
	sameClass = false,
	zeroScore = false,
	playstyle1 = true,
	playstyle2 = true,
	playstyle3 = true,
	playstyle4 = true,
	maxAgeMin = 0,
	minIlvl = 0,
	rangeAgeEn = false,
	rangeAgeMin = 0,
	rangeAgeMax = 0,
	rangeIlvlEn = false,
	rangeIlvlMin = 0,
	rangeIlvlMax = 0,
	rangeHonorEn = false,
	rangeHonorMin = 0,
	rangeHonorMax = 0,
	hideVoice = false,
	hideCrossRealm = false,
	sameFactionOnly = false,
	showFriendGroups = true,
	showGuildGroups = true,
	showHousewarmingGroups = true,
	rangeMplusScoreEn = false,
	rangeMplusScoreMin = 0,
	rangeMplusScoreMax = 0,
}

local function isPvPCategory(categoryID)
	for _, pvp in ipairs(GF.PVP_CATEGORIES or {}) do
		if categoryID == pvp.id then
			return true
		end
	end
	return false
end

local function copyTable(src)
	if not src then
		return {}
	end
	local dst = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = copyTable(v)
		else
			dst[k] = v
		end
	end
	return dst
end

local function compactClientFilter(client)
	if not client then
		return nil
	end
	local out = {}
	for k, v in pairs(client) do
		local def = GF.clientFilterDefaults[k]
		if def == nil or v ~= def then
			out[k] = v
		end
	end
	if not next(out) then
		return nil
	end
	return out
end

local function defaultGlobalFilters()
	return copyTable(GLOBAL_FILTER_DEFAULTS)
end

local function legacyGlobalFilters(db)
	local out = defaultGlobalFilters()
	for k in pairs(GLOBAL_FILTER_DEFAULTS) do
		if db and db[k] ~= nil then
			out[k] = db[k]
		end
	end
	return out
end

local function migrateLegacyClientFilterBucket(db, key)
	local byCategory = db and db.filterClientByCategory
	if not byCategory then
		return
	end
	db.filterClientBucketMigrated = db.filterClientBucketMigrated or {}
	if db.filterClientBucketMigrated[key] then
		return
	end
	if byCategory[key] ~= nil then
		db.filterClientBucketMigrated[key] = true
		return
	end
	local aliases = LEGACY_CLIENT_FILTER_KEYS[key]
	if not aliases then
		return
	end
	local merged
	for _, legacyKey in ipairs(aliases) do
		local stored = byCategory[legacyKey]
		if type(stored) == "table" then
			if not merged then
				merged = {}
			end
			for k, v in pairs(stored) do
				if merged[k] == nil then
					merged[k] = v
				end
			end
		end
	end
	if merged then
		byCategory[key] = compactClientFilter(merged)
	end
	db.filterClientBucketMigrated[key] = true
end

local function globalFilterBucketKey(specOrSelection)
	if not specOrSelection then
		return "other"
	end
	local clientKey = specOrSelection.clientKey
	if clientKey == "dungeon" or clientKey == "raid" then
		return clientKey
	end
	local categoryID = specOrSelection.categoryID
	if not categoryID and specOrSelection.selection then
		categoryID = specOrSelection.selection.categoryID
	end
	if categoryID == GF.CAT_DUNGEON then
		return "dungeon"
	end
	if categoryID == GF.CAT_RAID then
		return "raid"
	end
	return "other"
end

local function migrateLegacyRange(client, legacyKey, minKey, maxKey)
	if not client then
		return
	end
	local legacy = tonumber(client[legacyKey]) or 0
	local minV = tonumber(client[minKey]) or 0
	local maxV = tonumber(client[maxKey]) or 0
	if legacy > 0 and minV <= 0 and maxV <= 0 then
		client[minKey] = legacy
		client[maxKey] = legacy
	end
	client[legacyKey] = 0
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

local function pcallList(fn, ...)
	local result = pcallFirst(fn, ...)
	if type(result) == "table" then
		return result
	end
	return {}
end

local function getAvailableActivityGroups(categoryID, filterFlags)
	return pcallList(C_LFGList and C_LFGList.GetAvailableActivityGroups, categoryID, filterFlags or 0)
end

local function getAvailableActivities(categoryID, groupID, filterFlags)
	return pcallList(C_LFGList and C_LFGList.GetAvailableActivities, categoryID, groupID, filterFlags or 0)
end

local function itemKeyForGroupID(groupID)
	groupID = tonumber(groupID)
	return groupID and ("g:" .. tostring(groupID)) or nil
end

local function activityItemKey(item)
	if type(item) == "table" then
		return item.key
	end
	return itemKeyForGroupID(item)
end

local function activityItemGroupIDs(item)
	if type(item) == "table" then
		return item.groupIDs or (item.groupID and { item.groupID }) or {}
	end
	return { item }
end

local function addUniqueActivityID(out, seen, activityID)
	activityID = tonumber(activityID)
	if activityID and activityID > 0 and not seen[activityID] then
		seen[activityID] = true
		out[#out + 1] = activityID
	end
end

local function addUniqueGroupID(out, seen, groupID)
	groupID = tonumber(groupID)
	if groupID and groupID > 0 and not seen[groupID] then
		seen[groupID] = true
		out[#out + 1] = groupID
	end
end

local function collectActivitiesForGroup(categoryID, groupID, filterFlags)
	local seen = {}
	local ids = {}
	for _, actID in ipairs(getAvailableActivities(categoryID, groupID, filterFlags)) do
		addUniqueActivityID(ids, seen, actID)
	end
	for _, actID in ipairs(getAvailableActivities(categoryID, groupID, Enum.LFGListFilter.PvE)) do
		addUniqueActivityID(ids, seen, actID)
	end
	return ids
end

local function fallbackActivityItems(categoryID, filterFlags)
	local groups = getAvailableActivityGroups(categoryID, filterFlags)
	local items = {}
	for index, groupID in ipairs(groups) do
		local name = pcallFirst(C_LFGList and C_LFGList.GetActivityGroupInfo, groupID) or tostring(groupID)
		local activityIDs = collectActivitiesForGroup(categoryID, groupID, filterFlags)
		items[#items + 1] = {
			key = itemKeyForGroupID(groupID),
			label = name,
			groupID = groupID,
			groupIDs = { groupID },
			activityIDs = activityIDs,
			categoryID = categoryID,
			orderIndex = index,
		}
	end
	return items
end

local function getNavFilterActivityItems(navKind)
	if GF.NavData and GF.NavData.GetFilterActivityItems then
		local items = GF.NavData.GetFilterActivityItems(navKind)
		if type(items) == "table" and #items > 0 then
			return items
		end
	end
	return nil
end

local function getNavFilterActivityGroupIDs(navKind)
	if GF.NavData and GF.NavData.GetFilterActivityGroupIDs then
		local groupIDs = GF.NavData.GetFilterActivityGroupIDs(navKind)
		if type(groupIDs) == "table" and #groupIDs > 0 then
			return groupIDs
		end
	end
	return nil
end

local function itemKeySet(items)
	local set = {}
	for _, item in ipairs(items or {}) do
		local key = activityItemKey(item)
		if key then
			set[key] = true
		end
	end
	return set
end

local function sanitizeActivityItemKeys(persisted, items)
	if not persisted or #persisted == 0 then
		return persisted
	end
	local valid = itemKeySet(items)
	local out = {}
	local seen = {}
	for _, key in ipairs(persisted) do
		key = tostring(key)
		if valid[key] and not seen[key] then
			seen[key] = true
			out[#out + 1] = key
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

local function migrateLegacyGroupIDsToItemKeys(groupIDs, items)
	if not groupIDs or #groupIDs == 0 then
		return nil
	end
	local wanted = {}
	for _, groupID in ipairs(groupIDs) do
		groupID = tonumber(groupID)
		if groupID then
			wanted[groupID] = true
		end
	end
	local out = {}
	local seen = {}
	for _, item in ipairs(items or {}) do
		local key = activityItemKey(item)
		for _, groupID in ipairs(activityItemGroupIDs(item)) do
			groupID = tonumber(groupID)
			if key and groupID and wanted[groupID] and not seen[key] then
				seen[key] = true
				out[#out + 1] = key
			end
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

function GF.Filter:GetClientFilters(key)
	local db = GF.GetDB()
	db.filterClientByCategory = db.filterClientByCategory or {}
	migrateLegacyClientFilterBucket(db, key)
	local stored = db.filterClientByCategory[key]
	if not stored then
		return copyTable(GF.clientFilterDefaults)
	end
	local merged = copyTable(GF.clientFilterDefaults)
	for k, v in pairs(stored) do
		merged[k] = v
	end
	migrateLegacyRange(merged, "raidMemberCount", "raidMemberCountMin", "raidMemberCountMax")
	migrateLegacyRange(merged, "raidBossKills", "raidBossKillsMin", "raidBossKillsMax")
	return merged
end

function GF.Filter:GetGlobalFilterKey(specOrSelection)
	return globalFilterBucketKey(specOrSelection)
end

function GF.Filter:GetGlobalFilters(specOrSelection)
	local db = GF.GetDB()
	db.filterGlobalByBucket = db.filterGlobalByBucket or {}
	local key = self:GetGlobalFilterKey(specOrSelection)
	if db.filterGlobalLegacyMigrated ~= true then
		db.filterGlobalByBucket[key] = legacyGlobalFilters(db)
		db.filterGlobalLegacyMigrated = true
	end
	if type(db.filterGlobalByBucket[key]) ~= "table" then
		db.filterGlobalByBucket[key] = defaultGlobalFilters()
	end
	local bucket = db.filterGlobalByBucket[key]
	for k, v in pairs(GLOBAL_FILTER_DEFAULTS) do
		if bucket[k] == nil then
			bucket[k] = v
		end
	end
	return bucket
end

function GF.Filter:SaveCategoryClientFilters(key, client)
	if not key or not client then
		return
	end
	local db = GF.GetDB()
	db.filterClientByCategory = db.filterClientByCategory or {}
	db.filterClientByCategory[key] = compactClientFilter(client)
end

function GF.Filter:GetPersistedActivities()
	local db = GF.GetDB()
	return db.filterDungeonActivities
end

function GF.Filter:SetPersistedActivities(activities)
	local db = GF.GetDB()
	if activities == nil then
		db.filterDungeonActivities = nil
	else
		db.filterDungeonActivities = copyTable(activities)
	end
end

function GF.Filter:GetPersistedActivityKeys()
	return GF.GetDB().filterDungeonActivityKeys
end

function GF.Filter:SetPersistedActivityKeys(keys)
	local db = GF.GetDB()
	if keys == nil then
		db.filterDungeonActivityKeys = nil
	else
		db.filterDungeonActivityKeys = copyTable(keys)
	end
end

function GF.Filter:GetPersistedDelveActivities()
	return GF.GetDB().filterDelveActivities
end

function GF.Filter:SetPersistedDelveActivities(activities)
	local db = GF.GetDB()
	if activities == nil then
		db.filterDelveActivities = nil
	else
		db.filterDelveActivities = copyTable(activities)
	end
end

function GF.Filter:IsAllDungeonGroupsDisabled()
	return GF.GetDB().filterDungeonNone == true
end

function GF.Filter:SetAllDungeonGroupsDisabled(disabled)
	local db = GF.GetDB()
	db.filterDungeonNone = disabled and true or nil
end

function GF.Filter:GetAdvancedOptions()
	if not C_LFGList or not C_LFGList.GetAdvancedFilter then
		return nil
	end
	local opts = copyTable(pcallFirst(C_LFGList.GetAdvancedFilter))
	-- 以下项均为客户端 post-filter，不限制 API 搜索
	opts.activities = {}
	opts.needsMyClass = false
	opts.hasTank = false
	opts.hasHealer = false
	if opts.difficultyNormal ~= nil then
		opts.difficultyNormal = true
		opts.difficultyHeroic = true
		opts.difficultyMythic = true
		opts.difficultyMythicPlus = true
	end
	return opts
end

function GF.Filter:SanitizeActivityGroupList(persisted, allGroups)
	if not persisted or #persisted == 0 then
		return persisted
	end
	local valid = {}
	for _, id in ipairs(allGroups) do
		valid[id] = true
	end
	local out = {}
	for _, id in ipairs(persisted) do
		if valid[id] then
			out[#out + 1] = id
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

function GF.Filter:GetDungeonActivityOptions(allGroups)
	local db = GF.GetDB()
	local opts = { activities = nil }
	if db.filterDungeonNone then
		opts.activities = {}
	elseif db.filterDungeonActivityKeys ~= nil then
		allGroups = allGroups or self:GetDungeonActivityItems()
		local sanitized = sanitizeActivityItemKeys(db.filterDungeonActivityKeys, allGroups)
		if sanitized ~= db.filterDungeonActivityKeys then
			self:SetPersistedActivityKeys(sanitized)
		end
		if sanitized then
			opts.activities = copyTable(sanitized)
		end
	elseif db.filterDungeonActivities ~= nil then
		allGroups = allGroups or self:GetDungeonActivityItems()
		local migrated = migrateLegacyGroupIDsToItemKeys(db.filterDungeonActivities, allGroups)
		self:SetPersistedActivityKeys(migrated)
		self:SetPersistedActivities(nil)
		if migrated then
			opts.activities = copyTable(migrated)
		end
	end
	return opts
end

function GF.Filter:GetPersistedRaidActivities()
	return GF.GetDB().filterRaidActivities
end

function GF.Filter:SetPersistedRaidActivities(activities)
	local db = GF.GetDB()
	if activities == nil then
		db.filterRaidActivities = nil
	else
		db.filterRaidActivities = copyTable(activities)
	end
end

function GF.Filter:GetPersistedRaidActivityKeys()
	return GF.GetDB().filterRaidActivityKeys
end

function GF.Filter:SetPersistedRaidActivityKeys(keys)
	local db = GF.GetDB()
	if keys == nil then
		db.filterRaidActivityKeys = nil
	else
		db.filterRaidActivityKeys = copyTable(keys)
	end
end

function GF.Filter:IsAllRaidGroupsDisabled()
	return GF.GetDB().filterRaidNone == true
end

function GF.Filter:SetAllRaidGroupsDisabled(disabled)
	local db = GF.GetDB()
	db.filterRaidNone = disabled and true or nil
end

function GF.Filter:GetRaidActivityOptions(allGroups)
	local db = GF.GetDB()
	local opts = { activities = nil }
	if db.filterRaidNone then
		opts.activities = {}
	elseif db.filterRaidActivityKeys ~= nil then
		allGroups = allGroups or self:GetRaidActivityItems()
		local sanitized = sanitizeActivityItemKeys(db.filterRaidActivityKeys, allGroups)
		if sanitized ~= db.filterRaidActivityKeys then
			self:SetPersistedRaidActivityKeys(sanitized)
		end
		if sanitized then
			opts.activities = copyTable(sanitized)
		end
	elseif db.filterRaidActivities ~= nil then
		allGroups = allGroups or self:GetRaidActivityItems()
		local migrated = migrateLegacyGroupIDsToItemKeys(db.filterRaidActivities, allGroups)
		self:SetPersistedRaidActivityKeys(migrated)
		self:SetPersistedRaidActivities(nil)
		if migrated then
			opts.activities = copyTable(migrated)
		end
	end
	return opts
end

function GF.Filter:SaveAdvancedOptions(options)
	if not options then
		return
	end
	local apiOpts = copyTable(options)
	apiOpts.activities = {}
	if C_LFGList and C_LFGList.SaveAdvancedFilter then
		pcall(C_LFGList.SaveAdvancedFilter, apiOpts)
	end
end

function GF.Filter:ApplyPersistedAdvancedFilter()
	-- 活动组勾选已改为客户端过滤，登录时不向 API 写入 activities
end

function GF.Filter:ResetAdvancedOptions()
	if not C_LFGList or not C_LFGList.GetAdvancedFilter then
		return
	end
	local enabled = pcallFirst(C_LFGList.GetAdvancedFilter)
	if type(enabled) ~= "table" then
		return
	end
	enabled.needsTank = false
	enabled.needsHealer = false
	enabled.needsDamage = false
	enabled.needsMyClass = false
	enabled.hasTank = false
	enabled.hasHealer = false
	enabled.minimumRating = 0
	enabled.activities = {}
	self:SetAllDungeonGroupsDisabled(false)
	self:SetPersistedActivities(nil)
	self:SetPersistedActivityKeys(nil)
	self:SetAllRaidGroupsDisabled(false)
	self:SetPersistedRaidActivities(nil)
	self:SetPersistedRaidActivityKeys(nil)
	if enabled.difficultyNormal ~= nil then
		enabled.difficultyNormal = true
		enabled.difficultyHeroic = true
		enabled.difficultyMythic = true
		enabled.difficultyMythicPlus = true
	end
	if C_LFGList.SaveAdvancedFilter then
		pcall(C_LFGList.SaveAdvancedFilter, enabled)
	end
end

function GF.Filter:ResetCategoryClient(key)
	if not key then
		return
	end
	local db = GF.GetDB()
	if db.filterClientByCategory then
		db.filterClientByCategory[key] = nil
	end
end

function GF.Filter:ResetVisibleGlobalFilters(spec)
	local db = self:GetGlobalFilters(spec)
	db.sameClass = false
	db.zeroScore = false
	db.playstyle1 = true
	db.playstyle2 = true
	db.playstyle3 = true
	db.playstyle4 = true
	db.maxAgeMin = 0
	db.minIlvl = 0
	db.rangeAgeEn = false
	db.rangeAgeMin = 0
	db.rangeAgeMax = 0
	db.rangeIlvlEn = false
	db.rangeIlvlMin = 0
	db.rangeIlvlMax = 0
	db.rangeHonorEn = false
	db.rangeHonorMin = 0
	db.rangeHonorMax = 0
	db.hideVoice = false
	db.hideCrossRealm = false
	db.sameFactionOnly = false
	db.showFriendGroups = true
	db.showGuildGroups = true
	db.showHousewarmingGroups = true
	db.filterRoleMatchAll = false
	db.rangeMplusScoreEn = false
	db.rangeMplusScoreMin = 0
	db.rangeMplusScoreMax = 0
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

function GF.Filter:ResetCategory(selection)
	if not selection then
		return
	end
	local spec = GF.FilterSpec and GF.FilterSpec:ResolveSpec(selection)
	if not spec then
		return
	end
	if spec.layoutTier == "api_max" then
		self:ResetAdvancedOptions()
	end
	self:ResetCategoryClient(spec.clientKey)
	self:ResetVisibleGlobalFilters(spec)
end

local PLAYSTYLE_ENUM = {
	Enum.LFGEntryGeneralPlaystyle.Learning,
	Enum.LFGEntryGeneralPlaystyle.FunRelaxed,
	Enum.LFGEntryGeneralPlaystyle.FunSerious,
	Enum.LFGEntryGeneralPlaystyle.Expert,
}

function GF.Filter:HasActivePlaystyleFilter(db)
	if not db then
		return false
	end
	for i = 1, 4 do
		if db["playstyle" .. i] == false then
			return true
		end
	end
	return false
end

function GF.Filter:HasActiveDungeonActivityFilter(db, allGroups)
	db = db or GF.GetDB()
	if db.filterDungeonNone then
		return true
	end
	local options = self:GetDungeonActivityOptions(allGroups)
	local persisted = options and options.activities
	if persisted == nil or #persisted == 0 then
		return false
	end
	allGroups = allGroups or self:GetDungeonActivityItems()
	if not allGroups or #allGroups == 0 then
		return false
	end
	return not self:ActivitiesAllChecked(options, allGroups)
end

local function normalizeActivityIDList(activityIDs)
	local out = {}
	local seen = {}
	if type(activityIDs) == "table" then
		for _, activityID in ipairs(activityIDs) do
			addUniqueActivityID(out, seen, activityID)
		end
	elseif activityIDs then
		addUniqueActivityID(out, seen, activityIDs)
	end
	return out
end

local function selectedActivityIDSet(options, items)
	if not options or not options.activities or #options.activities == 0 then
		return nil
	end
	if GF.Filter:ActivitiesAllChecked(options, items) then
		return nil
	end
	local selected = {}
	for _, key in ipairs(options.activities) do
		selected[tostring(key)] = true
	end
	local ids = {}
	for _, item in ipairs(items or {}) do
		local key = activityItemKey(item)
		if key and selected[key] then
			for _, activityID in ipairs((type(item) == "table" and item.activityIDs) or {}) do
				ids[activityID] = true
			end
		end
	end
	return ids
end

local function matchesActivityItemFilter(options, items, activityIDs)
	local selected = selectedActivityIDSet(options, items)
	if not selected then
		return true
	end
	activityIDs = normalizeActivityIDList(activityIDs)
	if #activityIDs == 0 then
		return false
	end
	for _, activityID in ipairs(activityIDs) do
		if selected[activityID] then
			return true
		end
	end
	return false
end

function GF.Filter:MatchesDungeonActivityFilter(db, activityIDs, allGroups)
	db = db or GF.GetDB()
	if db.filterDungeonNone then
		return false
	end
	allGroups = allGroups or self:GetDungeonActivityItems()
	local options = self:GetDungeonActivityOptions(allGroups)
	local persisted = options and options.activities
	if persisted == nil or #persisted == 0 then
		return true
	end
	if not allGroups or #allGroups == 0 then
		return true
	end
	return matchesActivityItemFilter(options, allGroups, activityIDs)
end

function GF.Filter:HasActiveRaidActivityFilter(db, allGroups)
	db = db or GF.GetDB()
	if db.filterRaidNone then
		return true
	end
	local options = self:GetRaidActivityOptions(allGroups)
	local persisted = options and options.activities
	if persisted == nil or #persisted == 0 then
		return false
	end
	allGroups = allGroups or self:GetRaidActivityItems()
	if not allGroups or #allGroups == 0 then
		return false
	end
	return not self:ActivitiesAllChecked(options, allGroups)
end

function GF.Filter:MatchesRaidActivityFilter(db, activityIDs, allGroups)
	db = db or GF.GetDB()
	if db.filterRaidNone then
		return false
	end
	allGroups = allGroups or self:GetRaidActivityItems()
	local options = self:GetRaidActivityOptions(allGroups)
	local persisted = options and options.activities
	if persisted == nil or #persisted == 0 then
		return true
	end
	if not allGroups or #allGroups == 0 then
		return true
	end
	return matchesActivityItemFilter(options, allGroups, activityIDs)
end

function GF.Filter:MatchesPlaystyleFilter(db, generalPlaystyle)
	if not db then
		return true
	end
	local allOn = true
	local anyOn = false
	for i = 1, 4 do
		if db["playstyle" .. i] == false then
			allOn = false
		else
			anyOn = true
		end
	end
	if allOn then
		return true
	end
	if not anyOn then
		return false
	end
	local gs = generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None
	if gs == Enum.LFGEntryGeneralPlaystyle.None then
		return false
	end
	for i = 1, 4 do
		if PLAYSTYLE_ENUM[i] == gs then
			return db["playstyle" .. i] ~= false
		end
	end
	return false
end

function GF.Filter:GetPlaystyleFilterLabel(index)
	if index == 0 or not index then
		local L = GF.L or {}
		return L.PLAYSTYLE_ANY or ALL or "All"
	end
	local key = "GROUP_FINDER_GENERAL_PLAYSTYLE" .. index
	return _G[key] or ("Style " .. index)
end

local function collectGroupIDsFromItems(items)
	local out = {}
	local seen = {}
	for _, item in ipairs(items or {}) do
		for _, groupID in ipairs(activityItemGroupIDs(item)) do
			addUniqueGroupID(out, seen, groupID)
		end
	end
	return out
end

function GF.Filter:GetDungeonActivityItems()
	local navItems = getNavFilterActivityItems("season_dungeon")
	if navItems then
		return navItems
	end
	local pve = Enum.LFGListFilter.PvE
	local seasonF = bit.bor(Enum.LFGListFilter.CurrentSeason, pve)
	return fallbackActivityItems(GF.CAT_DUNGEON, seasonF)
end

function GF.Filter:GetDungeonGroupIDs()
	local items = self:GetDungeonActivityItems()
	local groups = collectGroupIDsFromItems(items)
	if #groups > 0 then
		return groups
	end
	return getNavFilterActivityGroupIDs("season_dungeon") or {}
end

function GF.Filter:GetDelveGroupIDs()
	local pve = Enum.LFGListFilter.PvE
	local openF = bit.bor(Enum.LFGListFilter.CurrentExpansion, pve)
	return getAvailableActivityGroups(GF.CAT_DELVE, openF)
end

function GF.Filter:GetRaidActivityItems()
	local navItems = getNavFilterActivityItems("season_raid")
	if navItems then
		return navItems
	end
	local pve = Enum.LFGListFilter.PvE
	local recF = bit.bor(Enum.LFGListFilter.Recommended, pve)
	return fallbackActivityItems(GF.CAT_RAID, recF)
end

function GF.Filter:GetRaidGroupIDs()
	local items = self:GetRaidActivityItems()
	local groups = collectGroupIDsFromItems(items)
	if #groups > 0 then
		return groups
	end
	return getNavFilterActivityGroupIDs("season_raid") or {}
end

local function normalizeActivityOptionKey(value)
	if type(value) == "table" then
		return activityItemKey(value)
	end
	if type(value) == "string" then
		if value:match("^[ag]:") then
			return value
		end
		return value
	end
	return itemKeyForGroupID(value)
end

local function optionKeyIsSelected(options, key)
	if not key or not options or not options.activities then
		return false
	end
	for _, savedKey in ipairs(options.activities) do
		if tostring(savedKey) == key then
			return true
		end
	end
	return false
end

function GF.Filter:ActivitiesAllChecked(options, allGroups)
	allGroups = allGroups or self:GetDungeonActivityItems()
	if not options or not options.activities or #options.activities == 0 then
		return false
	end
	if #options.activities ~= #allGroups then
		return false
	end
	for _, item in ipairs(allGroups) do
		if not optionKeyIsSelected(options, activityItemKey(item)) then
			return false
		end
	end
	return true
end

function GF.Filter:IsGroupEnabled(options, groupID, allGroups)
	if not options or not options.activities then
		return true
	end
	if #options.activities == 0 then
		return true
	end
	allGroups = allGroups or self:GetDungeonActivityItems()
	if self:ActivitiesAllChecked(options, allGroups) then
		return true
	end
	return optionKeyIsSelected(options, normalizeActivityOptionKey(groupID))
end

function GF.Filter:SetGroupEnabled(options, groupID, enabled, allGroups, persistFn)
	allGroups = allGroups or self:GetDungeonActivityItems()
	if not options then
		return
	end
	options.activities = options.activities or {}
	local checked = {}
	if #options.activities == 0 or self:ActivitiesAllChecked(options, allGroups) then
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key then
				checked[key] = true
			end
		end
	else
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key then
				checked[key] = false
			end
		end
		for _, key in ipairs(options.activities) do
			checked[tostring(key)] = true
		end
	end
	local targetKey = normalizeActivityOptionKey(groupID)
	if targetKey then
		checked[targetKey] = enabled
	end
	local enabledCount = 0
	for _, item in ipairs(allGroups) do
		if checked[activityItemKey(item)] then
			enabledCount = enabledCount + 1
		end
	end
	if enabledCount == 0 then
		options.activities = {}
	elseif enabledCount == #allGroups then
		options.activities = {}
	else
		options.activities = {}
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key and checked[key] then
				options.activities[#options.activities + 1] = key
			end
		end
	end
	if persistFn then
		persistFn(options.activities)
	end
end

function GF.Filter:SetDungeonGroupEnabled(options, groupID, enabled, allGroups)
	if not options then
		return
	end
	options.activities = options.activities or {}
	allGroups = allGroups or self:GetDungeonActivityItems()
	local checked = {}
	if self:IsAllDungeonGroupsDisabled() then
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key then
				checked[key] = false
			end
		end
	elseif #options.activities == 0 or self:ActivitiesAllChecked(options, allGroups) then
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key then
				checked[key] = true
			end
		end
	else
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key then
				checked[key] = false
			end
		end
		for _, key in ipairs(options.activities) do
			checked[tostring(key)] = true
		end
	end
	local targetKey = normalizeActivityOptionKey(groupID)
	if targetKey then
		checked[targetKey] = enabled
	end
	local enabledCount = 0
	for _, item in ipairs(allGroups) do
		if checked[activityItemKey(item)] then
			enabledCount = enabledCount + 1
		end
	end
	if enabledCount == 0 then
		options.activities = {}
		self:SetAllDungeonGroupsDisabled(true)
		self:SetPersistedActivityKeys({})
	elseif enabledCount == #allGroups then
		options.activities = {}
		self:SetAllDungeonGroupsDisabled(false)
		self:SetPersistedActivityKeys({})
	else
		options.activities = {}
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key and checked[key] then
				options.activities[#options.activities + 1] = key
			end
		end
		self:SetAllDungeonGroupsDisabled(false)
		self:SetPersistedActivityKeys(options.activities)
	end
end

function GF.Filter:SetRaidGroupEnabled(options, groupID, enabled, allGroups)
	if not options then
		return
	end
	options.activities = options.activities or {}
	allGroups = allGroups or self:GetRaidActivityItems()
	local checked = {}
	if self:IsAllRaidGroupsDisabled() then
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key then
				checked[key] = false
			end
		end
	elseif #options.activities == 0 or self:ActivitiesAllChecked(options, allGroups) then
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key then
				checked[key] = true
			end
		end
	else
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key then
				checked[key] = false
			end
		end
		for _, key in ipairs(options.activities) do
			checked[tostring(key)] = true
		end
	end
	local targetKey = normalizeActivityOptionKey(groupID)
	if targetKey then
		checked[targetKey] = enabled
	end
	local enabledCount = 0
	for _, item in ipairs(allGroups) do
		if checked[activityItemKey(item)] then
			enabledCount = enabledCount + 1
		end
	end
	if enabledCount == 0 then
		options.activities = {}
		self:SetAllRaidGroupsDisabled(true)
		self:SetPersistedRaidActivityKeys({})
	elseif enabledCount == #allGroups then
		options.activities = {}
		self:SetAllRaidGroupsDisabled(false)
		self:SetPersistedRaidActivityKeys({})
	else
		options.activities = {}
		for _, item in ipairs(allGroups) do
			local key = activityItemKey(item)
			if key and checked[key] then
				options.activities[#options.activities + 1] = key
			end
		end
		self:SetAllRaidGroupsDisabled(false)
		self:SetPersistedRaidActivityKeys(options.activities)
	end
end

function GF.Filter:ApplyDifficultyToClient(client, diffIndex, includeMplus)
	if not client then
		return
	end
	local allOn = not diffIndex or diffIndex == 0
	client.dungeonDiffEn = not allOn
	client.dungeonDifficultyNormal = allOn or diffIndex == 1
	client.dungeonDifficultyHeroic = allOn or diffIndex == 2
	client.dungeonDifficultyMythic = allOn or diffIndex == 3
	if includeMplus then
		client.dungeonDifficultyMythicPlus = allOn or diffIndex == 4
	end
end

function GF.Filter:ApplyRaidDifficultyToClient(client, diffIndex)
	if not client then
		return
	end
	local allOn = not diffIndex or diffIndex == 0
	client.raidDiffEn = not allOn
	client.raidDifficultyNormal = allOn or diffIndex == 1
	client.raidDifficultyHeroic = allOn or diffIndex == 2
	client.raidDifficultyMythic = allOn or diffIndex == 3
end

function GF.Filter:GetClientDifficultyIndex(client, includeMplus)
	if not client or not client.dungeonDiffEn then
		return 0
	end
	if client.dungeonDifficultyNormal and not client.dungeonDifficultyHeroic
		and not client.dungeonDifficultyMythic and not (includeMplus and client.dungeonDifficultyMythicPlus) then
		return 1
	end
	if client.dungeonDifficultyHeroic and not client.dungeonDifficultyNormal
		and not client.dungeonDifficultyMythic and not (includeMplus and client.dungeonDifficultyMythicPlus) then
		return 2
	end
	if client.dungeonDifficultyMythic and not client.dungeonDifficultyNormal
		and not client.dungeonDifficultyHeroic and not (includeMplus and client.dungeonDifficultyMythicPlus) then
		return 3
	end
	if includeMplus and client.dungeonDifficultyMythicPlus and not client.dungeonDifficultyNormal
		and not client.dungeonDifficultyHeroic and not client.dungeonDifficultyMythic then
		return 4
	end
	return 0
end

function GF.Filter:GetRaidDifficultyIndex(client)
	if not client or not client.raidDiffEn then
		return 0
	end
	if client.raidDifficultyNormal and not client.raidDifficultyHeroic and not client.raidDifficultyMythic then
		return 1
	end
	if client.raidDifficultyHeroic and not client.raidDifficultyNormal and not client.raidDifficultyMythic then
		return 2
	end
	if client.raidDifficultyMythic and not client.raidDifficultyNormal and not client.raidDifficultyHeroic then
		return 3
	end
	return 0
end

function GF.Filter:ApplyDifficultyToAdvanced(opts, diffIndex)
	if not opts then
		return
	end
	local allOn = not diffIndex or diffIndex == 0
	opts.difficultyNormal = allOn or diffIndex == 1
	opts.difficultyHeroic = allOn or diffIndex == 2
	opts.difficultyMythic = allOn or diffIndex == 3
	opts.difficultyMythicPlus = allOn or diffIndex == 4
end

function GF.Filter:GetDifficultyIndex(opts)
	if not opts or opts.difficultyNormal == nil then
		return 0
	end
	if opts.difficultyNormal and opts.difficultyHeroic and opts.difficultyMythic and opts.difficultyMythicPlus then
		return 0
	end
	if opts.difficultyNormal and not opts.difficultyHeroic and not opts.difficultyMythic and not opts.difficultyMythicPlus then
		return 1
	end
	if opts.difficultyHeroic and not opts.difficultyNormal and not opts.difficultyMythic and not opts.difficultyMythicPlus then
		return 2
	end
	if opts.difficultyMythic and not opts.difficultyNormal and not opts.difficultyHeroic and not opts.difficultyMythicPlus then
		return 3
	end
	if opts.difficultyMythicPlus and not opts.difficultyNormal and not opts.difficultyHeroic and not opts.difficultyMythic then
		return 4
	end
	return 0
end

function GF.Filter:ResolveCategoryFilters(categoryID, filters)
	if categoryID == GF.CAT_CUSTOM or categoryID == GF.CAT_DELVE or isPvPCategory(categoryID) then
		return 0
	end
	if categoryID == GF.CAT_DUNGEON or categoryID == GF.CAT_RAID then
		filters = filters or 0
		local recommended = bit.band(filters, RECOMMENDED_SEARCH_MASK)
		if recommended ~= 0 then
			return recommended
		end
		return Enum.LFGListFilter.Recommended
	end
	return filters or 0
end

function GF.Filter:ResolvePreferredFilters(categoryID, preferredFilters)
	if categoryID == GF.CAT_CUSTOM then
		return 0
	end
	if preferredFilters ~= nil then
		return preferredFilters
	end
	if isPvPCategory(categoryID) then
		return Enum.LFGListFilter.PvP
	end
	return Enum.LFGListFilter.PvE
end

function GF.Filter:ApplyClientFilterRefresh()
	if GF.FindGroupTab and GF.FindGroupTab.ApplyClientFilters then
		GF.FindGroupTab:ApplyClientFilters()
	end
end
