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
local JOURNAL_LORE_IMAGE_TEX_COORDS = {
	0.052734375,
	0.703125,
	0.091796875,
	0.556640625,
}

local runtimeCatalogCache = {}
local journalCatalogCache = {}
local staticCatalogLookupCache = {}
local manualCatalogLookupCache = {}
local expansionHintLookupCache = {}

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

local function trimText(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	return value ~= "" and value or nil
end

local function escapePattern(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	return (value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function extractParentheticalHint(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	local hint = value:match("（([^（）]+)）")
	if cleanText(hint) then
		return hint
	end
	hint = value:match("%(([^()]+)%)")
	if cleanText(hint) then
		return hint
	end
	return nil
end

local function removeParentheticalHints(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	value = value:gsub("%s*（[^（）]+）", "")
	value = value:gsub("%s*%([^()]+%)", "")
	return trimText(value)
end

local function addLabelCandidate(out, seen, value)
	value = trimText(value)
	if not value or seen[value] then
		return
	end
	seen[value] = true
	out[#out + 1] = value
end

local function difficultyLabelCandidates(info)
	local labels = {}
	local seen = {}
	if GF.ActivityInfo and GF.ActivityInfo.GetDifficultyLabel then
		addLabelCandidate(labels, seen, GF.ActivityInfo.GetDifficultyLabel(info, { includeMplus = true }))
	end
	local L = GF.L or {}
	addLabelCandidate(labels, seen, L.DIFF_NORMAL)
	addLabelCandidate(labels, seen, L.DIFF_HEROIC)
	addLabelCandidate(labels, seen, L.DIFF_MYTHIC)
	addLabelCandidate(labels, seen, L.DIFF_MYTHIC_PLUS)
	addLabelCandidate(labels, seen, "Normal")
	addLabelCandidate(labels, seen, "Heroic")
	addLabelCandidate(labels, seen, "Mythic")
	addLabelCandidate(labels, seen, "Mythic Keystone")
	addLabelCandidate(labels, seen, "普通")
	addLabelCandidate(labels, seen, "英雄")
	addLabelCandidate(labels, seen, "史诗")
	addLabelCandidate(labels, seen, "傳奇")
	addLabelCandidate(labels, seen, "传说钥石")
	addLabelCandidate(labels, seen, "傳奇鑰石")
	return labels
end

local function stripKnownDifficultySuffix(value, info)
	value = trimText(value)
	if not value then
		return nil
	end
	for _, label in ipairs(difficultyLabelCandidates(info)) do
		local escaped = escapePattern(label)
		if escaped then
			local stripped = trimText(value:gsub("%s*[-–—]%s*" .. escaped .. "%s*$", ""))
			if stripped and stripped ~= value then
				return stripped
			end
			stripped = trimText(value:gsub("%s+" .. escaped .. "%s*$", ""))
			if stripped and stripped ~= value then
				return stripped
			end
			stripped = trimText(value:gsub("%s*（" .. escaped .. "）%s*$", ""))
			if stripped and stripped ~= value then
				return stripped
			end
			stripped = trimText(value:gsub("%s*%(" .. escaped .. "%)%s*$", ""))
			if stripped and stripped ~= value then
				return stripped
			end
		end
	end
	return value
end

local function soloDisplayName(info)
	if type(info) ~= "table" then
		return nil
	end
	local name = GF.ActivityInfo and GF.ActivityInfo.GetActivityBaseName and GF.ActivityInfo.GetActivityBaseName(info)
		or cleanText(info.fullName)
		or cleanText(info.shortName)
	name = removeParentheticalHints(name) or name
	name = trimText(name and name:gsub("%s*[-–—]%s*", "-"))
	return name
end

local function soloPairBaseKey(info)
	local name = soloDisplayName(info)
	name = stripKnownDifficultySuffix(name, info)
	return normalizedName(name)
end

local function addExpansionCandidate(out, seen, expansionIndex)
	expansionIndex = tonumber(expansionIndex)
	if expansionIndex == nil or seen[expansionIndex] then
		return
	end
	seen[expansionIndex] = true
	out[#out + 1] = expansionIndex
end

local function collectExpansionCandidates(kind)
	local candidates = {}
	local seen = {}
	local source = GF.NAV_CATALOG and GF.NAV_CATALOG[kind]
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		addExpansionCandidate(candidates, seen, expansion.expansionIndex)
	end
	source = GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind]
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		addExpansionCandidate(candidates, seen, expansion.expansionIndex)
	end
	local maxExpansion = (currentExpansionIndex() or 0) + 1
	for expansionIndex = 0, maxExpansion do
		addExpansionCandidate(candidates, seen, expansionIndex)
	end
	return candidates
end

local function expansionIndexFromHint(kind, hint)
	local key = kind .. ":" .. tostring(normalizedName(hint) or "")
	local cached = expansionHintLookupCache[key]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local hintKey = normalizedName(hint)
	if not hintKey then
		expansionHintLookupCache[key] = false
		return nil
	end
	for _, expansionIndex in ipairs(collectExpansionCandidates(kind)) do
		if normalizedName(expansionLabel(expansionIndex)) == hintKey then
			expansionHintLookupCache[key] = expansionIndex
			return expansionIndex
		end
	end
	expansionHintLookupCache[key] = false
	return nil
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
				local ok, instanceID, name, description, backgroundImage, buttonImage1, loreImage, buttonImage2, mapID, unused1, unused2, instanceMapID =
					pcall(EJ_GetInstanceByIndex, dataIndex, showRaid)
				if not ok or not instanceID then
					break
				end
				local visualTexture = loreImage or backgroundImage or buttonImage2 or buttonImage1
				local instance = {
					journalInstanceID = instanceID,
					label = name,
					description = description,
					mapID = tonumber(mapID),
					instanceMapID = tonumber(instanceMapID),
					visualTexture = visualTexture,
					visualTexCoords = loreImage and JOURNAL_LORE_IMAGE_TEX_COORDS or nil,
					visualSource = loreImage and "loreImage"
						or (backgroundImage and "backgroundImage")
						or (buttonImage2 and "buttonImage2")
						or (buttonImage1 and "buttonImage1")
						or nil,
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
				addJournalLookup(catalog.byMapID, instance.instanceMapID, instance)
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
		instanceMapID = journalInstance and journalInstance.instanceMapID or entry.instanceMapID,
		label = journalInstance and journalInstance.label or entry.label,
		visualTexture = journalInstance and journalInstance.visualTexture or entry.visualTexture,
		visualTexCoords = journalInstance and journalInstance.visualTexCoords or entry.visualTexCoords,
		visualSource = journalInstance and journalInstance.visualSource or entry.visualSource,
	}
	return out
end

local function addStaticCatalogRecords(lookup, source, sourceName)
	local added = false
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		local expansionIndex = tonumber(expansion.expansionIndex)
		if expansionIndex ~= nil then
			for orderIndex, instance in ipairs(expansion.instances or EMPTY) do
				if type(instance) == "table" then
					local record = {
						expansionIndex = tonumber(instance.expansionIndex) or expansionIndex,
						orderIndex = tonumber(instance.orderIndex) or orderIndex,
						label = cleanText(instance.label),
						listFilters = tonumber(instance.listFilters),
						source = sourceName,
					}
					local activityID = tonumber(instance.activityID)
					if activityID then
						lookup.byActivityID[activityID] = record
						added = true
					end
					local groupID = tonumber(instance.groupID)
					if groupID then
						lookup.byGroupID[groupID] = record
						added = true
					end
				end
			end
		end
	end
	return added
end

local function manualCatalogLookup(kind)
	local cached = manualCatalogLookupCache[kind]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local source = GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind]
	if not source or type(source.expansions) ~= "table" then
		manualCatalogLookupCache[kind] = false
		return nil
	end

	local lookup = {
		byActivityID = {},
		byGroupID = {},
	}
	if not addStaticCatalogRecords(lookup, source, "manual") then
		manualCatalogLookupCache[kind] = false
		return nil
	end
	manualCatalogLookupCache[kind] = lookup
	return lookup
end

local function staticCatalogLookup(kind)
	local cached = staticCatalogLookupCache[kind]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local source = GF.NAV_CATALOG and GF.NAV_CATALOG[kind]
	local manualSource = GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind]
	if (not source or type(source.expansions) ~= "table")
		and (not manualSource or type(manualSource.expansions) ~= "table") then
		staticCatalogLookupCache[kind] = false
		return nil
	end

	local lookup = {
		byActivityID = {},
		byGroupID = {},
	}
	addStaticCatalogRecords(lookup, source, "static")
	addStaticCatalogRecords(lookup, manualSource, "manual")

	staticCatalogLookupCache[kind] = lookup
	return lookup
end

local function applyCatalogRecordOverrides(out, record)
	if not out or not record then
		return out
	end
	if record.label then
		out.label = record.label
	end
	if record.listFilters then
		out.listFilters = record.listFilters
	end
	if record.orderIndex then
		out.orderIndex = record.orderIndex
	end
	return out
end

local function takeEntryFromBucket(bucket, used, predicate)
	for _, entry in ipairs(bucket or EMPTY) do
		if not used[entry] and (not predicate or predicate(entry)) then
			used[entry] = true
			return entry
		end
	end
	return nil
end

local function canMatchJournalInstance(kind, entry)
	if kind == "raid" and entry and entry.activityID and not entry.groupID then
		return false
	end
	return true
end

local function takeEntryForJournalInstance(kind, lookup, journalInstance, used)
	local function predicate(entry)
		return canMatchJournalInstance(kind, entry)
	end
	local entry = takeEntryFromBucket(lookup.byJournalInstanceID[journalInstance.journalInstanceID], used, predicate)
	if entry then
		return entry
	end
	entry = takeEntryFromBucket(lookup.byMapID[journalInstance.mapID], used, predicate)
	if entry then
		return entry
	end
	entry = takeEntryFromBucket(lookup.byMapID[journalInstance.instanceMapID], used, predicate)
	if entry then
		return entry
	end
	return takeEntryFromBucket(lookup.byName[normalizedName(journalInstance.label)], used, predicate)
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

local function staticRecordForEntry(lookup, entry)
	if not lookup or not entry then
		return nil
	end
	if entry.groupID then
		local record = lookup.byGroupID[entry.groupID]
		if record then
			return record
		end
	end
	if entry.activityID then
		local record = lookup.byActivityID[entry.activityID]
		if record then
			return record
		end
	end
	for _, activityID in ipairs(entry.activityIDs or EMPTY) do
		local record = lookup.byActivityID[activityID]
		if record then
			return record
		end
	end
	return nil
end

local function entryExpansionIndexFromRuntimeName(kind, entry)
	if kind ~= "raid" or not (entry and entry.activityID) or entry.groupID then
		return nil
	end
	local function readInfo(info)
		if type(info) ~= "table" then
			return nil
		end
		local hint = extractParentheticalHint(info.fullName) or extractParentheticalHint(info.shortName)
		return expansionIndexFromHint(kind, hint)
	end
	local expansionIndex = readInfo(entry.info)
	if expansionIndex ~= nil then
		return expansionIndex
	end
	for _, activityID in ipairs(entry.activityIDs or EMPTY) do
		expansionIndex = readInfo(getActivityInfo(activityID))
		if expansionIndex ~= nil then
			return expansionIndex
		end
	end
	return nil
end

local function entrySoloPairBaseKey(entry)
	if not (entry and entry.activityID) or entry.groupID then
		return nil
	end
	local info = entry.info or getActivityInfo(entry.activityID)
	local key = soloPairBaseKey(info)
	if key then
		return key
	end
	for _, activityID in ipairs(entry.activityIDs or EMPTY) do
		key = soloPairBaseKey(getActivityInfo(activityID))
		if key then
			return key
		end
	end
	return nil
end

local function buildRuntimeSoloExpansionPairs(kind, entries)
	local pairs = {}
	if kind ~= "raid" then
		return pairs
	end
	for _, entry in ipairs(entries or EMPTY) do
		if entry.activityID and not entry.groupID then
			local expansionIndex = entryExpansionIndexFromRuntimeName(kind, entry)
			local baseKey = entrySoloPairBaseKey(entry)
			if expansionIndex ~= nil and baseKey then
				local existing = pairs[baseKey]
				if existing == nil or expansionIndex > existing then
					pairs[baseKey] = expansionIndex
				end
			end
		end
	end
	return pairs
end

local function pairedRuntimeExpansionIndex(pairLookup, entry, record)
	if not (pairLookup and record and record.expansionIndex ~= nil) then
		return nil
	end
	local baseKey = entrySoloPairBaseKey(entry)
	local expansionIndex = baseKey and pairLookup[baseKey]
	if expansionIndex == nil then
		return nil
	end
	if math.abs((tonumber(record.expansionIndex) or expansionIndex) - expansionIndex) > 1 then
		return nil
	end
	return expansionIndex
end

local function runtimeSoloOrder(entry)
	local info = entry and (entry.info or getActivityInfo(entry.activityID))
	local difficultyIndex = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyIndex
		and GF.ActivityInfo.GetDifficultyIndex(info, { includeMplus = true }) or 0
	if not difficultyIndex or difficultyIndex <= 0 then
		difficultyIndex = 1
	end
	return STATIC_RAID_SOLO_ORDER_BASE + 9000 + (difficultyIndex * 100) + ((tonumber(entry and entry.activityID) or 0) % 100)
end

local function appendManualMappedEntries(kind, catalog, entries, used)
	local lookup = manualCatalogLookup(kind)
	if not lookup then
		return
	end

	for _, entry in ipairs(entries or EMPTY) do
		if not used[entry] then
			local record = staticRecordForEntry(lookup, entry)
			if record and record.expansionIndex ~= nil then
				used[entry] = true
				local expansionIndex = record.expansionIndex
				local expansion = addExpansion(catalog, expansionIndex, expansionLabel(expansionIndex))
				local out = copyEntryForCatalog(entry)
				applyCatalogRecordOverrides(out, record)
				expansion.instances[#expansion.instances + 1] = out
			end
		end
	end
end

local function appendStaticMappedEntries(kind, catalog, entries, used)
	local lookup = staticCatalogLookup(kind)
	if not lookup then
		return
	end
	local pairLookup = buildRuntimeSoloExpansionPairs(kind, entries)

	for _, entry in ipairs(entries or EMPTY) do
		if not used[entry] then
			local record = staticRecordForEntry(lookup, entry)
			local runtimeExpansionIndex = entryExpansionIndexFromRuntimeName(kind, entry)
				or pairedRuntimeExpansionIndex(pairLookup, entry, record)
			if runtimeExpansionIndex ~= nil or (record and record.expansionIndex ~= nil) then
				used[entry] = true
				local expansionIndex = runtimeExpansionIndex ~= nil and runtimeExpansionIndex or record.expansionIndex
				local expansion = addExpansion(catalog, expansionIndex, expansionLabel(expansionIndex))
				local out = copyEntryForCatalog(entry)
				applyCatalogRecordOverrides(out, record)
				if runtimeExpansionIndex ~= nil then
					out.orderIndex = runtimeSoloOrder(entry)
				elseif record.orderIndex then
					out.orderIndex = record.orderIndex
					if kind == "raid" and entry.activityID and not entry.groupID then
						out.orderIndex = STATIC_RAID_SOLO_ORDER_BASE + record.orderIndex
					end
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
	appendManualMappedEntries(kind, catalog, entries, used)
	if journal then
		for _, journalExpansion in ipairs(journal.expansions or EMPTY) do
			for _, journalInstance in ipairs(journalExpansion.instances or EMPTY) do
				local entry = takeEntryForJournalInstance(kind, lookup, journalInstance, used)
				if entry then
					local expansion = addExpansion(catalog, journalExpansion.expansionIndex, journalExpansion.label)
					expansion.instances[#expansion.instances + 1] = copyEntryForCatalog(entry, journalInstance)
				end
			end
		end
	end
	appendStaticMappedEntries(kind, catalog, entries, used)
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
	elseif kind == "raid" then
		local filtered = {}
		for _, entry in ipairs(entries or EMPTY) do
			if entry.groupID then
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
			local entry = takeEntryForJournalInstance(kind, lookup, journalInstance, used)
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
	clearTable(manualCatalogLookupCache)
	clearTable(expansionHintLookupCache)
	if GF.MythicPlusLFGScope and GF.MythicPlusLFGScope.Invalidate then
		GF.MythicPlusLFGScope:Invalidate()
	end
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

function NavCatalog.GetJournalInstance(kind, mapID, instanceMapID, name)
	local catalog = journalCatalog(kind)
	if not catalog then
		return nil
	end
	local nameKey = normalizedName(name)
	local function choose(bucket)
		if type(bucket) ~= "table" then
			return nil
		end
		if nameKey then
			for _, instance in ipairs(bucket) do
				if normalizedName(instance and instance.label) == nameKey then
					return instance
				end
			end
		end
		return bucket[1]
	end
	local instance = choose(catalog.byMapID[tonumber(mapID)])
		or choose(catalog.byMapID[tonumber(instanceMapID)])
		or choose(catalog.byName[nameKey])
	return instance
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
