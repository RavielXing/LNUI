local _, GF = ...

local NavCatalog = GF.NavCatalog or {}
GF.NavCatalog = NavCatalog

local EMPTY = {}
local PVE = Enum.LFGListFilter.PvE
local RECOMMENDED = Enum.LFGListFilter.Recommended
local NOT_RECOMMENDED = Enum.LFGListFilter.NotRecommended
local CURRENT_SEASON = Enum.LFGListFilter.CurrentSeason
local CURRENT_EXPANSION = Enum.LFGListFilter.CurrentExpansion
local NOT_CURRENT_SEASON = Enum.LFGListFilter.NotCurrentSeason
local TIMERUNNING = Enum.LFGListFilter.Timerunning or 0
local RECOMMENDED_MASK = bit.bor(RECOMMENDED, NOT_RECOMMENDED)
local STATIC_RAID_SOLO_ORDER_BASE = 100000

local runtimeCatalogCache = {}
local journalCatalogCache = {}
local staticCatalogLookupCache = {}

local function clearTable(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function currentExpansionIndex()
	if GetServerExpansionLevel then
		return GetServerExpansionLevel()
	end
	return 11
end

local function expansionLabel(expansionIndex)
	if GetExpansionName then
		local name = GetExpansionName(expansionIndex)
		if name and name ~= "" then
			return name
		end
	end
	return tostring(expansionIndex)
end

local function bor(...)
	local value = 0
	for i = 1, select("#", ...) do
		local flag = select(i, ...)
		if flag and flag ~= 0 then
			value = bit.bor(value, flag)
		end
	end
	return value
end

local function addUnique(out, seen, value)
	value = value or 0
	if seen[value] then
		return
	end
	seen[value] = true
	out[#out + 1] = value
end

local function pcallList(fn, ...)
	if type(fn) ~= "function" then
		return EMPTY
	end
	local ok, result = pcall(fn, ...)
	if ok and type(result) == "table" then
		return result
	end
	return EMPTY
end

local function getAvailableActivityGroups(categoryID, filterFlags)
	return pcallList(C_LFGList and C_LFGList.GetAvailableActivityGroups, categoryID, filterFlags or 0)
end

local function getAvailableActivities(categoryID, groupID, filterFlags)
	return pcallList(C_LFGList and C_LFGList.GetAvailableActivities, categoryID, groupID, filterFlags or 0)
end

local function getActivityInfo(activityID)
	if not (C_LFGList and C_LFGList.GetActivityInfoTable and activityID) then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
	if ok and type(info) == "table" then
		return info
	end
	return nil
end

local function getActivityGroupInfo(groupID)
	if not (C_LFGList and C_LFGList.GetActivityGroupInfo and groupID) then
		return nil, nil
	end
	local ok, name, orderIndex = pcall(C_LFGList.GetActivityGroupInfo, groupID)
	if ok then
		return name, orderIndex
	end
	return nil, nil
end

local function cleanText(value)
	if type(value) ~= "string" then
		return nil
	end
	if value == "" then
		return nil
	end
	return value
end

local function normalizedName(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("[%s%p%c]+", "")
	value = value:gsub("[：:（）()%[%]【】「」『』《》〈〉、，。；;！!？?%-_—–·]+", "")
	if value == "" then
		return nil
	end
	return string.lower(value)
end

local function catalogMeta(kind)
	if kind == "dungeon" then
		return {
			categoryID = GF.CAT_DUNGEON,
			baseFilters = bor(CURRENT_EXPANSION, NOT_CURRENT_SEASON, PVE),
			preferredFilters = PVE,
		}
	elseif kind == "raid" then
		return {
			categoryID = GF.CAT_RAID,
			baseFilters = bor(RECOMMENDED, PVE),
			preferredFilters = PVE,
		}
	end
	return nil
end

local function buildFilterSets(kind)
	local filters = {}
	local seen = {}
	if kind == "dungeon" then
		addUnique(filters, seen, bor(CURRENT_SEASON, PVE))
		if PlayerIsTimerunning and PlayerIsTimerunning() and TIMERUNNING ~= 0 then
			addUnique(filters, seen, bor(TIMERUNNING, PVE))
		end
		addUnique(filters, seen, bor(CURRENT_EXPANSION, NOT_CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(CURRENT_EXPANSION, PVE))
		addUnique(filters, seen, bor(RECOMMENDED, PVE))
		addUnique(filters, seen, bor(NOT_RECOMMENDED, PVE))
		addUnique(filters, seen, PVE)
	elseif kind == "raid" then
		addUnique(filters, seen, bor(RECOMMENDED, PVE))
		addUnique(filters, seen, bor(NOT_RECOMMENDED, PVE))
		addUnique(filters, seen, bor(CURRENT_EXPANSION, PVE))
		addUnique(filters, seen, bor(CURRENT_EXPANSION, NOT_CURRENT_SEASON, PVE))
		addUnique(filters, seen, PVE)
	end
	return filters
end

local function activityGroupID(info)
	local groupID = tonumber(info and info.groupFinderActivityGroupID)
	if groupID and groupID > 0 then
		return groupID
	end
	return nil
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

local function journalExpansionIndexForTier(tier)
	local serverTier = currentExpansionIndex() + 1
	if tier <= serverTier then
		return tier - 1, false
	end
	return currentExpansionIndex(), true
end

local function addJournalLookup(list, key, instance)
	if key == nil then
		return
	end
	local bucket = list[key]
	if not bucket then
		bucket = {}
		list[key] = bucket
	end
	bucket[#bucket + 1] = instance
end

local function buildJournalCatalog(kind)
	if kind ~= "dungeon" and kind ~= "raid" then
		return nil
	end
	if type(EJ_GetNumTiers) ~= "function"
		or type(EJ_GetTierInfo) ~= "function"
		or type(EJ_SelectTier) ~= "function"
		or type(EJ_GetInstanceByIndex) ~= "function" then
		if C_AddOns and C_AddOns.LoadAddOn then
			pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
		end
	end
	if type(EJ_GetNumTiers) ~= "function"
		or type(EJ_GetTierInfo) ~= "function"
		or type(EJ_SelectTier) ~= "function"
		or type(EJ_GetInstanceByIndex) ~= "function" then
		return nil
	end

	local numTiers = tonumber(pcallFirst(EJ_GetNumTiers)) or 0
	if numTiers <= 0 then
		return nil
	end

	local showRaid = kind == "raid"
	local previousTier = pcallFirst(EJ_GetCurrentTier)
	local catalog = {
		expansions = {},
		seasonInstances = {},
		byJournalInstanceID = {},
		byMapID = {},
		byName = {},
	}

	for tier = 1, numTiers do
		local tierName = pcallFirst(EJ_GetTierInfo, tier)
		local expansionIndex, isSeason = journalExpansionIndexForTier(tier)
		local okSelect = pcall(EJ_SelectTier, tier)
		if okSelect then
			local expansion = {
				expansionIndex = expansionIndex,
				label = tierName,
				tier = tier,
				instances = {},
			}
			local dataIndex = 1
			while dataIndex <= 300 do
				local ok, instanceID, name, unused1, unused2, unused3, unused4, unused5, unused6, unused7, unused8, mapID =
					pcall(EJ_GetInstanceByIndex, dataIndex, showRaid)
				if not ok or not instanceID then
					break
				end
				local instance = {
					journalInstanceID = instanceID,
					label = name,
					mapID = tonumber(mapID),
					orderIndex = dataIndex,
					tier = tier,
					expansionIndex = expansionIndex,
					expansionLabel = tierName,
					isSeason = isSeason,
				}
				if isSeason then
					catalog.seasonInstances[#catalog.seasonInstances + 1] = instance
				else
					expansion.instances[#expansion.instances + 1] = instance
				end
				addJournalLookup(catalog.byJournalInstanceID, instanceID, instance)
				addJournalLookup(catalog.byMapID, instance.mapID, instance)
				addJournalLookup(catalog.byName, normalizedName(name), instance)
				dataIndex = dataIndex + 1
			end
			if not isSeason and #expansion.instances > 0 then
				catalog.expansions[#catalog.expansions + 1] = expansion
			end
		end
	end

	if previousTier then
		pcall(EJ_SelectTier, previousTier)
	end

	table.sort(catalog.expansions, function(a, b)
		if a.expansionIndex ~= b.expansionIndex then
			return a.expansionIndex > b.expansionIndex
		end
		return (tonumber(a.tier) or 0) > (tonumber(b.tier) or 0)
	end)
	return catalog
end

local function journalCatalog(kind)
	local cached = journalCatalogCache[kind]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local catalog = buildJournalCatalog(kind)
	journalCatalogCache[kind] = catalog or false
	return catalog
end

local function journalInstanceIDForMapID(mapID)
	mapID = tonumber(mapID)
	if not mapID or mapID <= 0 then
		return nil
	end
	if not (C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap) then
		return nil
	end
	local ok, journalInstanceID = pcall(C_EncounterJournal.GetInstanceForGameMap, mapID)
	if ok and journalInstanceID then
		return journalInstanceID
	end
	return nil
end

local function addNameKey(keys, seen, value)
	local key = normalizedName(value)
	if key and not seen[key] then
		seen[key] = true
		keys[#keys + 1] = key
	end
end

local function activityBaseName(info)
	if GF.ActivityInfo and GF.ActivityInfo.GetActivityBaseName then
		return GF.ActivityInfo.GetActivityBaseName(info)
	end
	return cleanText(info and info.fullName) or cleanText(info and info.shortName)
end

local function makeEntryNameKeys(groupName, info)
	local keys = {}
	local seen = {}
	addNameKey(keys, seen, groupName)
	if type(info) == "table" then
		addNameKey(keys, seen, activityBaseName(info))
		addNameKey(keys, seen, info.fullName)
		addNameKey(keys, seen, info.shortName)
	end
	return keys
end

local function activityRecommendedBits(info)
	local filters = tonumber(info and info.filters) or 0
	return bit.band(filters, RECOMMENDED_MASK)
end

local function deriveListFilters(categoryID, filterFlags, activityIDs)
	local listFilters = filterFlags or 0
	if bit.band(listFilters, PVE) == 0 then
		listFilters = bit.bor(listFilters, PVE)
	end
	if categoryID ~= GF.CAT_DUNGEON and categoryID ~= GF.CAT_RAID then
		return listFilters
	end
	if bit.band(listFilters, RECOMMENDED_MASK) ~= 0 then
		return listFilters
	end

	local foundRecommended = false
	local foundNotRecommended = false
	for _, activityID in ipairs(activityIDs or EMPTY) do
		local info = getActivityInfo(activityID)
		local recBits = activityRecommendedBits(info)
		foundRecommended = foundRecommended or bit.band(recBits, RECOMMENDED) ~= 0
		foundNotRecommended = foundNotRecommended or bit.band(recBits, NOT_RECOMMENDED) ~= 0
	end

	if foundNotRecommended and not foundRecommended then
		return bit.bor(listFilters, NOT_RECOMMENDED)
	end
	if foundRecommended and not foundNotRecommended then
		return bit.bor(listFilters, RECOMMENDED)
	end
	return listFilters
end

local function addExpansion(catalog, expansionIndex, label)
	local expansionsByIndex = catalog._expansionsByIndex
	local expansion = expansionsByIndex[expansionIndex]
	if expansion then
		if label and label ~= "" then
			expansion.label = label
		end
		return expansion
	end
	expansion = {
		expansionIndex = expansionIndex,
		label = label or tostring(expansionIndex),
		instances = {},
	}
	expansionsByIndex[expansionIndex] = expansion
	catalog.expansions[#catalog.expansions + 1] = expansion
	return expansion
end

local function instanceOrder(a)
	return tonumber(a and a.orderIndex) or tonumber(a and a.groupID) or tonumber(a and a.activityID) or 0
end

local function finalizeCatalog(catalog, kind)
	for _, expansion in ipairs(catalog.expansions) do
		table.sort(expansion.instances, function(a, b)
			local oa = instanceOrder(a)
			local ob = instanceOrder(b)
			if oa ~= ob then
				return oa < ob
			end
			return (tonumber(a.groupID or a.activityID) or 0) < (tonumber(b.groupID or b.activityID) or 0)
		end)
	end
	table.sort(catalog.expansions, function(a, b)
		if a.expansionIndex ~= b.expansionIndex then
			return a.expansionIndex > b.expansionIndex
		end
		return (a.label or "") < (b.label or "")
	end)
	catalog._expansionsByIndex = nil
	return catalog
end

local function addEntryLookup(lookup, key, entry)
	if key == nil then
		return
	end
	local bucket = lookup[key]
	if not bucket then
		bucket = {}
		lookup[key] = bucket
	end
	bucket[#bucket + 1] = entry
end

local function addEntryLookups(lookup, entry)
	addEntryLookup(lookup.byJournalInstanceID, entry.journalInstanceID, entry)
	addEntryLookup(lookup.byMapID, entry.mapID, entry)
	for _, key in ipairs(entry.nameKeys or EMPTY) do
		addEntryLookup(lookup.byName, key, entry)
	end
end

local function mergeActivityList(out, seen, activities)
	for _, activityID in ipairs(activities or EMPTY) do
		if not seen[activityID] then
			seen[activityID] = true
			out[#out + 1] = activityID
		end
	end
end

local function buildRuntimeEntries(kind, filterSets)
	local meta = catalogMeta(kind)
	if not meta or not meta.categoryID then
		return nil, nil
	end

	local seenGroups = {}
	local seenActivities = {}
	local entries = {}
	local lookup = { byJournalInstanceID = {}, byMapID = {}, byName = {} }
	local addGroup

	local function addEntry(entry)
		entries[#entries + 1] = entry
		addEntryLookups(lookup, entry)
	end

	local function addSoloActivity(activityID, filterFlags, info)
		if seenActivities[activityID] then
			return
		end
		seenActivities[activityID] = true
		info = info or getActivityInfo(activityID)
		if not info then
			return
		end
		local groupID = activityGroupID(info)
		if groupID then
			addGroup(groupID, filterFlags, info)
			return
		end
		local listFilters = deriveListFilters(meta.categoryID, filterFlags, { activityID })
		local entry = {
			activityID = activityID,
			listFilters = listFilters,
			orderIndex = tonumber(info.orderIndex) or activityID,
			activityIDs = { activityID },
			filterFlags = filterFlags,
			info = info,
			mapID = tonumber(info.mapID),
			journalInstanceID = journalInstanceIDForMapID(info.mapID),
			nameKeys = makeEntryNameKeys(nil, info),
		}
		addEntry(entry)
	end

	addGroup = function(groupID, filterFlags, seedInfo)
		if seenGroups[groupID] then
			return
		end
		local groupName, groupOrder = getActivityGroupInfo(groupID)
		if not groupName or groupName == "" then
			return
		end
		local activities = getAvailableActivities(meta.categoryID, groupID, filterFlags)
		if #activities == 0 and filterFlags ~= PVE then
			activities = getAvailableActivities(meta.categoryID, groupID, PVE)
		end
		if #activities == 0 then
			return
		end
		seenGroups[groupID] = true

		local allActivities = {}
		local allSeen = {}
		mergeActivityList(allActivities, allSeen, activities)
		mergeActivityList(allActivities, allSeen, getAvailableActivities(meta.categoryID, groupID, PVE))
		local firstInfo = seedInfo or getActivityInfo(activities[1])
		local listFilters = deriveListFilters(meta.categoryID, filterFlags, activities)
		local mapID = tonumber(firstInfo and firstInfo.mapID)
		local journalInstanceID = journalInstanceIDForMapID(mapID)
		if not journalInstanceID then
			for _, activityID in ipairs(allActivities) do
				local info = getActivityInfo(activityID)
				journalInstanceID = journalInstanceIDForMapID(info and info.mapID)
				if journalInstanceID then
					mapID = tonumber(info and info.mapID)
					break
				end
			end
		end
		local entry = {
			groupID = groupID,
			listFilters = listFilters,
			orderIndex = tonumber(groupOrder) or tonumber(firstInfo and firstInfo.orderIndex) or groupID,
			activityIDs = allActivities,
			filterFlags = filterFlags,
			info = firstInfo,
			groupName = groupName,
			mapID = mapID,
			journalInstanceID = journalInstanceID,
			nameKeys = makeEntryNameKeys(groupName, firstInfo),
		}
		addEntry(entry)
	end

	for _, filterFlags in ipairs(filterSets or buildFilterSets(kind)) do
		for _, groupID in ipairs(getAvailableActivityGroups(meta.categoryID, filterFlags)) do
			addGroup(groupID, filterFlags)
		end
		for _, activityID in ipairs(getAvailableActivities(meta.categoryID, 0, filterFlags)) do
			addSoloActivity(activityID, filterFlags)
		end
		for _, activityID in ipairs(getAvailableActivities(meta.categoryID, nil, filterFlags)) do
			addSoloActivity(activityID, filterFlags)
		end
	end

	return entries, lookup, meta
end

local function copyEntryForCatalog(entry, journalInstance)
	local out = {
		groupID = entry.groupID,
		activityID = entry.activityID,
		listFilters = entry.listFilters,
		orderIndex = journalInstance and journalInstance.orderIndex or entry.orderIndex,
		activityIDs = entry.activityIDs,
		journalInstanceID = journalInstance and journalInstance.journalInstanceID or entry.journalInstanceID,
		mapID = journalInstance and journalInstance.mapID or entry.mapID,
	}
	return out
end

local function staticCatalogLookup(kind)
	local cached = staticCatalogLookupCache[kind]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local source = GF.NAV_CATALOG and GF.NAV_CATALOG[kind]
	if not source or type(source.expansions) ~= "table" then
		staticCatalogLookupCache[kind] = false
		return nil
	end

	local lookup = {
		byActivityID = {},
		byGroupID = {},
	}
	for _, expansion in ipairs(source.expansions) do
		local expansionIndex = expansion.expansionIndex
		for orderIndex, instance in ipairs(expansion.instances or EMPTY) do
			local record = {
				expansionIndex = expansionIndex,
				orderIndex = orderIndex,
			}
			if instance.activityID then
				lookup.byActivityID[instance.activityID] = record
			end
			if instance.groupID then
				lookup.byGroupID[instance.groupID] = record
			end
		end
	end

	staticCatalogLookupCache[kind] = lookup
	return lookup
end

local function takeEntryFromBucket(bucket, used)
	for _, entry in ipairs(bucket or EMPTY) do
		if not used[entry] then
			used[entry] = true
			return entry
		end
	end
	return nil
end

local function takeEntryForJournalInstance(lookup, journalInstance, used)
	local entry = takeEntryFromBucket(lookup.byJournalInstanceID[journalInstance.journalInstanceID], used)
	if entry then
		return entry
	end
	entry = takeEntryFromBucket(lookup.byMapID[journalInstance.mapID], used)
	if entry then
		return entry
	end
	return takeEntryFromBucket(lookup.byName[normalizedName(journalInstance.label)], used)
end

local function entryHasMythicPlus(entry)
	for _, activityID in ipairs(entry and entry.activityIDs or EMPTY) do
		local info = getActivityInfo(activityID)
		if info and info.isMythicPlusActivity then
			return true
		end
	end
	local info = entry and (entry.info or getActivityInfo(entry.activityID))
	return info and info.isMythicPlusActivity == true
end

local function appendStaticMappedRaidActivities(catalog, entries, used)
	local lookup = staticCatalogLookup("raid")
	if not lookup then
		return
	end

	for _, entry in ipairs(entries or EMPTY) do
		if not used[entry] and entry.activityID and not entry.groupID then
			local record = lookup.byActivityID[entry.activityID]
			if record and record.expansionIndex ~= nil then
				used[entry] = true
				local expansion = addExpansion(catalog, record.expansionIndex, expansionLabel(record.expansionIndex))
				local out = copyEntryForCatalog(entry)
				if record.orderIndex then
					out.orderIndex = STATIC_RAID_SOLO_ORDER_BASE + record.orderIndex
				end
				expansion.instances[#expansion.instances + 1] = out
			end
		end
	end
end

local function buildRuntimeCatalog(kind)
	local entries, lookup, meta = buildRuntimeEntries(kind)
	if not meta then
		return nil
	end

	local catalog = {
		categoryID = meta.categoryID,
		baseFilters = meta.baseFilters or 0,
		preferredFilters = meta.preferredFilters or PVE,
		expansions = {},
		_expansionsByIndex = {},
	}
	local used = {}
	local journal = journalCatalog(kind)
	if journal then
		for _, journalExpansion in ipairs(journal.expansions or EMPTY) do
			for _, journalInstance in ipairs(journalExpansion.instances or EMPTY) do
				local entry = takeEntryForJournalInstance(lookup, journalInstance, used)
				if entry then
					local expansion = addExpansion(catalog, journalExpansion.expansionIndex, journalExpansion.label)
					expansion.instances[#expansion.instances + 1] = copyEntryForCatalog(entry, journalInstance)
				end
			end
		end
	end
	if kind == "raid" then
		appendStaticMappedRaidActivities(catalog, entries, used)
	end
	return finalizeCatalog(catalog, kind)
end

local function sortSeasonInstances(kind, instances)
	table.sort(instances, function(a, b)
		local oa = instanceOrder(a)
		local ob = instanceOrder(b)
		if oa ~= ob then
			return oa < ob
		end
		return (tonumber(a.groupID or a.activityID) or 0) < (tonumber(b.groupID or b.activityID) or 0)
	end)
end

local function buildSeasonInstances(kind)
	local filterFlags
	if kind == "dungeon" then
		filterFlags = bor(CURRENT_SEASON, PVE)
	elseif kind == "raid" then
		filterFlags = bor(RECOMMENDED, PVE)
	else
		return EMPTY
	end

	local entries, lookup = buildRuntimeEntries(kind, { filterFlags })
	if kind == "dungeon" then
		local filtered = {}
		for _, entry in ipairs(entries or EMPTY) do
			if entryHasMythicPlus(entry) then
				filtered[#filtered + 1] = entry
			end
		end
		entries = filtered
		lookup = { byJournalInstanceID = {}, byMapID = {}, byName = {} }
		for _, entry in ipairs(entries) do
			addEntryLookups(lookup, entry)
		end
	end

	local used = {}
	local instances = {}
	local journal = journalCatalog(kind)
	if journal then
		for _, journalInstance in ipairs(journal.seasonInstances or EMPTY) do
			local entry = takeEntryForJournalInstance(lookup, journalInstance, used)
			if entry then
				instances[#instances + 1] = copyEntryForCatalog(entry, journalInstance)
			end
		end
	end
	sortSeasonInstances(kind, instances)
	return instances
end

local function runtimeCatalog(kind)
	if kind == nil then
		return nil
	end
	local cached = runtimeCatalogCache[kind]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local catalog = buildRuntimeCatalog(kind)
	runtimeCatalogCache[kind] = catalog or false
	return catalog
end

function NavCatalog.ClearRuntimeCache()
	clearTable(runtimeCatalogCache)
	clearTable(journalCatalogCache)
	clearTable(staticCatalogLookupCache)
end

function NavCatalog.GetMeta(kind)
	return runtimeCatalog(kind)
end

function NavCatalog.GetExpansions(kind)
	local meta = NavCatalog.GetMeta(kind)
	return (meta and meta.expansions) or EMPTY
end

function NavCatalog.GetInstances(kind, expansionIndex)
	if expansionIndex == nil then
		return EMPTY
	end
	for _, expansion in ipairs(NavCatalog.GetExpansions(kind)) do
		if expansion.expansionIndex == expansionIndex then
			return expansion.instances or EMPTY
		end
	end
	return EMPTY
end

function NavCatalog.GetSeasonInstances(kind)
	local cacheKey = "season:" .. tostring(kind)
	local cached = runtimeCatalogCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or EMPTY
	end
	local instances = buildSeasonInstances(kind)
	runtimeCatalogCache[cacheKey] = instances or false
	return instances or EMPTY
end

function NavCatalog.CollectGroupIDs(kind)
	local seen = {}
	local groupIDs = {}
	for _, expansion in ipairs(NavCatalog.GetExpansions(kind)) do
		for _, instance in ipairs(expansion.instances or EMPTY) do
			local groupID = instance.groupID
			if groupID and not seen[groupID] then
				seen[groupID] = true
				groupIDs[#groupIDs + 1] = groupID
			end
		end
	end
	table.sort(groupIDs)
	return groupIDs
end
