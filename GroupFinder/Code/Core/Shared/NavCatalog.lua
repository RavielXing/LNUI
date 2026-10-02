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
-- Legacy archive shells are build/locale structure, while the verified
-- workbook path is projected through the current character's native Activity
-- Finder directory before publication. Track only those availability-scoped
-- cache keys so an availability event can discard them without rebuilding
-- older structural-only compatibility shells.
local instanceShellCache = {}
local availabilityScopedInstanceShellKeys = {}
-- Encounter Journal structure is independent from the character's current
-- LFG availability generation. Keep its tier directory and instance snapshots
-- separate so an LFG_LIST_AVAILABILITY_UPDATE cannot force the next archive
-- click to rescan every Journal instance on the main thread.
local journalCatalogCache = {}
local journalTierCatalogCache = {}
local journalExpansionCatalogCache = {}
local journalSeasonCatalogCache = {}
local staticCatalogLookupCache = {}
local manualCatalogLookupCache = {}
local expansionHintLookupCache = {}
local archiveGroupOwnershipCache = {}
-- The verified workbook is structural data. Its candidate lookup is stable for
-- the loaded build, while the native intersection is scoped to one LFG
-- availability generation and is discarded by ClearRuntimeCache().
local verifiedSnapshotCandidateLookupCache = {}
local verifiedSnapshotAvailabilityCache = {}
-- These APIs describe one LFG availability generation. Successful snapshots
-- remain valid until ClearRuntimeCache handles LFG_LIST_AVAILABILITY_UPDATE.
-- Failed or incomplete reads are deliberately not retained so login warm-up
-- can retry them later in the same generation.
local activityInfoCache = {}
local availableActivityGroupsCache = {}
local availableActivitiesCache = {}
local activityGroupInfoCache = {}
local journalInstanceIDByMapCache = {}
local NIL_CACHE_KEY = {}
-- A failed/missing availability API read is not the same as an authoritative
-- empty list. Callers that would otherwise cache a grey archive result compare
-- this serial before and after their bounded lookup.
local availabilityReadFailureSerial = 0

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

local function clientDisplayExpansionIndex()
	-- PTR realm progression may trail the client data set. Use the larger
	-- display/server value only for classifying normal Encounter Journal tiers.
	local serverExpansion = tonumber(currentExpansionIndex()) or 0
	if type(GetClientDisplayExpansionLevel) ~= "function" then
		return serverExpansion
	end
	local ok, clientExpansion = pcall(GetClientDisplayExpansionLevel)
	clientExpansion = ok and tonumber(clientExpansion) or nil
	if clientExpansion == nil then
		return serverExpansion
	end
	return math.max(serverExpansion, clientExpansion)
end

local function interfaceExpansionIndex()
	if type(GetBuildInfo) ~= "function" then
		return nil
	end
	local ok, _, _, _, interfaceVersion = pcall(GetBuildInfo)
	interfaceVersion = ok and tonumber(interfaceVersion) or nil
	if not interfaceVersion or interfaceVersion <= 0 then
		return nil
	end
	local expansionIndex = math.floor(interfaceVersion / 10000) - 1
	return expansionIndex >= 0 and expansionIndex or nil
end

-- PLAYER_LOGIN can run before the expansion APIs have reached their final
-- retail value. Treating that transient 0/older value as authoritative makes
-- every later Encounter Journal tier look like a dedicated season tier. The
-- interface number is immutable for the loaded client and therefore supplies
-- a safe lower bound without loading another Blizzard addon.
local function trustedJournalExpansionIndex()
	local displayExpansion = tonumber(clientDisplayExpansionIndex())
	if not displayExpansion or displayExpansion <= 0
		or displayExpansion % 1 ~= 0
	then
		return nil
	end
	local expectedExpansion = interfaceExpansionIndex()
	if expectedExpansion and displayExpansion < expectedExpansion then
		return nil
	end
	return displayExpansion
end

local function expansionLabel(index)
	local fallback = tostring(index)
	if type(GetExpansionName) ~= "function" then
		return fallback
	end
	local ok, label = pcall(GetExpansionName, index)
	if not ok or type(label) ~= "string" or label == "" then
		return fallback
	end
	return label
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

local function getAvailableActivityGroups(categoryID, filterFlags)
	local getter = C_LFGList and C_LFGList.GetAvailableActivityGroups
	if type(getter) ~= "function" then
		availabilityReadFailureSerial = availabilityReadFailureSerial + 1
		return EMPTY
	end
	local categoryKey = categoryID == nil and NIL_CACHE_KEY or categoryID
	local normalizedFilters = filterFlags or 0
	local categoryCache = availableActivityGroupsCache[categoryKey]
	local cached = categoryCache and categoryCache[normalizedFilters]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(getter, categoryID, normalizedFilters)
	if not ok or type(result) ~= "table" then
		availabilityReadFailureSerial = availabilityReadFailureSerial + 1
		return EMPTY
	end
	if not categoryCache then
		categoryCache = {}
		availableActivityGroupsCache[categoryKey] = categoryCache
	end
	categoryCache[normalizedFilters] = result
	return result
end

local function getAvailableActivities(categoryID, groupID, filterFlags, searchText)
	local getter = C_LFGList and C_LFGList.GetAvailableActivities
	if type(getter) ~= "function" then
		availabilityReadFailureSerial = availabilityReadFailureSerial + 1
		return EMPTY
	end
	local categoryKey = categoryID == nil and NIL_CACHE_KEY or categoryID
	local groupKey = groupID == nil and NIL_CACHE_KEY or groupID
	local normalizedFilters = filterFlags or 0
	local searchKey = searchText == nil and NIL_CACHE_KEY or searchText
	local categoryCache = availableActivitiesCache[categoryKey]
	local groupCache = categoryCache and categoryCache[groupKey]
	local filterCache = groupCache and groupCache[normalizedFilters]
	local cached = filterCache and filterCache[searchKey]
	if cached ~= nil then
		return cached
	end
	local ok, result
	if searchText ~= nil then
		ok, result = pcall(
			getter,
			categoryID, groupID, normalizedFilters, searchText)
	else
		ok, result = pcall(
			getter,
			categoryID, groupID, normalizedFilters)
	end
	if not ok or type(result) ~= "table" then
		availabilityReadFailureSerial = availabilityReadFailureSerial + 1
		return EMPTY
	end
	if not categoryCache then
		categoryCache = {}
		availableActivitiesCache[categoryKey] = categoryCache
	end
	if not groupCache then
		groupCache = {}
		categoryCache[groupKey] = groupCache
	end
	if not filterCache then
		filterCache = {}
		groupCache[normalizedFilters] = filterCache
	end
	filterCache[searchKey] = result
	return result
end

local function copyActivityInfoSnapshot(info)
	if type(info) ~= "table" then return nil end
	local accessible = GF.Compat and GF.Compat.IsAccessibleTable
	if type(accessible) == "function" and not accessible(info) then return nil end
	local snapshot = {}
	for key, value in pairs(info) do snapshot[key] = value end
	return snapshot
end

local function completeActivityInfo(info)
	local read = GF.Compat and GF.Compat.ReadAccessibleField
	local categoryID, groupID, fullName
	if type(read) == "function" then
		categoryID = read(info, "categoryID")
		groupID = read(info, "groupFinderActivityGroupID")
		fullName = read(info, "fullName")
	else
		categoryID, groupID, fullName = info.categoryID,
			info.groupFinderActivityGroupID, info.fullName
	end
	return type(categoryID) == "number" and tonumber(groupID) ~= nil
		and type(fullName) == "string" and fullName ~= ""
end

local function getActivityInfo(activityID)
	if not (C_LFGList and C_LFGList.GetActivityInfoTable and activityID) then
		return nil
	end
	local cached = activityInfoCache[activityID]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
	if ok and type(info) == "table" then
		local snapshot
		ok, snapshot = pcall(copyActivityInfoSnapshot, info)
		if not ok or type(snapshot) ~= "table" then return nil end
		local complete
		ok, complete = pcall(completeActivityInfo, info)
		-- One isolated, read-only snapshot per availability generation. Partial
		-- metadata remains retryable and never freezes login-time empty names.
		if ok and complete then activityInfoCache[activityID] = snapshot end
		return snapshot
	end
	return nil
end

-- Metadata only: reading this snapshot never grants activity availability.
function NavCatalog.GetActivityInfoSnapshot(activityID)
	return getActivityInfo(activityID)
end

local function activityListReadiness()
	local getter = C_LFGList and C_LFGList.HasActivityList
	if type(getter) ~= "function" then
		-- Older supported clients do not expose this readiness helper. Their
		-- successful directory calls remain the best available evidence.
		return true
	end
	local ok, ready = pcall(getter)
	if not ok or type(ready) ~= "boolean" then
		return nil
	end
	return ready
end

local function getActivityGroupInfo(groupID)
	if not (C_LFGList and C_LFGList.GetActivityGroupInfo and groupID) then
		return nil, nil
	end
	local cached = activityGroupInfoCache[groupID]
	if cached ~= nil then
		return cached.name, cached.orderIndex
	end
	local ok, name, orderIndex = pcall(C_LFGList.GetActivityGroupInfo, groupID)
	if ok then
		if name ~= nil or orderIndex ~= nil then
			activityGroupInfoCache[groupID] = {
				name = name,
				orderIndex = orderIndex,
			}
		end
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
	source = GF.NAV_CATALOG_SUPPLEMENT and GF.NAV_CATALOG_SUPPLEMENT[kind]
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

local function resolveEntryCreationFilter(kind, filterFlags)
	filterFlags = tonumber(filterFlags) or 0
	if kind == "dungeon" then
		-- Blizzard LFGList.lua ResolveCategoryFilters(): dungeon Activity Finder
		-- forces Recommended and removes NotRecommended before enumeration.
		return bit.band(
			bit.bnot(NOT_RECOMMENDED),
			bit.bor(filterFlags, RECOMMENDED)
		)
	end
	return filterFlags
end

local function buildFilterSets(kind)
	local filters = {}
	local seen = {}
	if kind == "dungeon" then
		addUnique(filters, seen, bor(CURRENT_SEASON, PVE))
		if PlayerIsTimerunning and PlayerIsTimerunning() and TIMERUNNING ~= 0 then
			addUnique(filters, seen, bor(TIMERUNNING, PVE))
		end
		addUnique(filters, seen, bor(NOT_CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(CURRENT_EXPANSION, NOT_CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(CURRENT_EXPANSION, PVE))
		addUnique(filters, seen, bor(RECOMMENDED, PVE))
		addUnique(filters, seen, bor(NOT_RECOMMENDED, PVE))
		addUnique(filters, seen, PVE)
		-- EntryCreation may enumerate an activity with no base filter, or with
		-- only its Recommended partition. These are native authorization paths
		-- too and must not be mistaken for an unavailable Journal entry.
		addUnique(filters, seen, 0)
		addUnique(filters, seen, RECOMMENDED)
		addUnique(filters, seen, NOT_RECOMMENDED)
	elseif kind == "raid" then
		addUnique(filters, seen, bor(RECOMMENDED, PVE))
		addUnique(filters, seen, bor(NOT_RECOMMENDED, PVE))
		addUnique(filters, seen, bor(NOT_CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(CURRENT_EXPANSION, PVE))
		addUnique(filters, seen, bor(CURRENT_EXPANSION, NOT_CURRENT_SEASON, PVE))
		addUnique(filters, seen, PVE)
		addUnique(filters, seen, 0)
		addUnique(filters, seen, RECOMMENDED)
		addUnique(filters, seen, NOT_RECOMMENDED)
	end
	local nativeSourceCount = #filters
	for index = 1, nativeSourceCount do
		addUnique(filters, seen, resolveEntryCreationFilter(kind, filters[index]))
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

local function journalExpansionIndexForTier(tier, displayExpansion)
	displayExpansion = tonumber(displayExpansion)
		or trustedJournalExpansionIndex()
	if not displayExpansion then
		return nil, nil
	end
	local clientTier = displayExpansion + 1
	if tier <= clientTier then
		return tier - 1, false
	end
	return displayExpansion, true
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

local function ensureJournalAPI(kind)
	if kind ~= "dungeon" and kind ~= "raid" then
		return false
	end
	-- Never synchronously load Blizzard_EncounterJournal. That addon owns a
	-- large UI/data initialization and moving its cost to login or a navigation
	-- click is still a user-visible stall. Journal enrichment becomes available
	-- after Blizzard/the player naturally loads the Adventure Guide.
	if type(EJ_GetNumTiers) ~= "function"
		or type(EJ_GetTierInfo) ~= "function"
		or type(EJ_SelectTier) ~= "function"
		or type(EJ_GetInstanceByIndex) ~= "function" then
		return false
	end
	return true
end

local function newJournalCatalog()
	return {
		expansions = {},
		seasonInstances = {},
		byJournalInstanceID = {},
		byMapID = {},
		byName = {},
		_expansionsByIndex = {},
	}
end

local function journalInstanceAt(kind, tierDescriptor, dataIndex)
	local ok, instanceID, name, description, backgroundImage, buttonImage,
		loreImage, secondaryButtonImage, dungeonAreaMapID, unused1, unused2, gameMapID =
		pcall(EJ_GetInstanceByIndex, dataIndex, kind == "raid")
	if not ok then
		return nil, "pending"
	elseif instanceID == nil then
		return nil, "end"
	elseif not tonumber(instanceID) or tonumber(instanceID) <= 0
		or type(name) ~= "string" or name == "" then
		return nil, "pending"
	end
	local visualTexture = loreImage or backgroundImage
		or secondaryButtonImage or buttonImage
	return {
		journalInstanceID = instanceID,
		label = name,
		description = description,
		mapID = tonumber(dungeonAreaMapID),
		instanceMapID = tonumber(gameMapID),
		visualTexture = visualTexture,
		visualTexCoords = loreImage and JOURNAL_LORE_IMAGE_TEX_COORDS or nil,
		visualSource = loreImage and "loreImage"
			or (backgroundImage and "backgroundImage")
			or (secondaryButtonImage and "buttonImage2")
			or (buttonImage and "buttonImage1")
			or nil,
		orderIndex = dataIndex,
		tier = tierDescriptor.tier,
		expansionIndex = tierDescriptor.expansionIndex,
		expansionLabel = tierDescriptor.label,
		isSeason = tierDescriptor.isSeason,
	}
end

local function addJournalInstance(catalog, tierDescriptor, instance)
	if tierDescriptor.isSeason then
		catalog.seasonInstances[#catalog.seasonInstances + 1] = instance
	else
		local expansionIndex = tierDescriptor.expansionIndex
		local expansion = catalog._expansionsByIndex[expansionIndex]
		if not expansion then
			expansion = {
				expansionIndex = expansionIndex,
				label = tierDescriptor.label,
				tier = tierDescriptor.tier,
				instances = {},
			}
			catalog._expansionsByIndex[expansionIndex] = expansion
			catalog.expansions[#catalog.expansions + 1] = expansion
		end
		expansion.instances[#expansion.instances + 1] = instance
	end
	addJournalLookup(
		catalog.byJournalInstanceID, instance.journalInstanceID, instance)
	addJournalLookup(catalog.byMapID, instance.mapID, instance)
	addJournalLookup(catalog.byMapID, instance.instanceMapID, instance)
	addJournalLookup(catalog.byName, normalizedName(instance.label), instance)
end

local function finalizeJournalCatalog(catalog)
	table.sort(catalog.expansions, function(a, b)
		if a.expansionIndex ~= b.expansionIndex then
			return a.expansionIndex > b.expansionIndex
		end
		return (tonumber(a.tier) or 0) > (tonumber(b.tier) or 0)
	end)
	catalog._expansionsByIndex = nil
	return catalog
end

local function buildJournalTierCatalog(kind)
	if not ensureJournalAPI(kind) then
		return nil
	end

	local numTiers = tonumber(pcallFirst(EJ_GetNumTiers)) or 0
	local displayExpansion = trustedJournalExpansionIndex()
	if not displayExpansion or numTiers <= 0 then
		return nil
	end

	local catalog = {
		expansions = {},
		tiers = {},
		tiersByExpansion = {},
		seasonTiers = {},
		numTiers = numTiers,
	}
	local seenExpansions = {}

	for tier = 1, numTiers do
		local tierName = pcallFirst(EJ_GetTierInfo, tier)
		local expansionIndex, isSeason = journalExpansionIndexForTier(
			tier, displayExpansion)
		if expansionIndex == nil then
			return nil
		end
		-- EJ_SelectTier mutates Blizzard's Encounter Journal and can perform
		-- substantial synchronous UI/data work. A root-category click must only
		-- read tier headers; whether this kind has instances in the tier is
		-- resolved when the user expands that one tier.
		local descriptor = {
			expansionIndex = expansionIndex,
			label = tierName,
			tier = tier,
			isSeason = isSeason,
		}
		catalog.tiers[#catalog.tiers + 1] = descriptor
		if isSeason then
			catalog.seasonTiers[#catalog.seasonTiers + 1] = descriptor
		else
			local bucket = catalog.tiersByExpansion[expansionIndex]
			if not bucket then
				bucket = {}
				catalog.tiersByExpansion[expansionIndex] = bucket
			end
			bucket[#bucket + 1] = descriptor
			if not seenExpansions[expansionIndex] then
				seenExpansions[expansionIndex] = true
				catalog.expansions[#catalog.expansions + 1] = {
					expansionIndex = expansionIndex,
					label = tierName,
				}
			end
		end
	end

	table.sort(catalog.expansions, function(a, b)
		return (tonumber(a and a.expansionIndex) or 0)
			> (tonumber(b and b.expansionIndex) or 0)
	end)
	return catalog
end

local function journalTierCatalog(kind)
	local cached = journalTierCatalogCache[kind]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local catalog = buildJournalTierCatalog(kind)
	-- Journal APIs can be temporarily unavailable while Blizzard's addon is
	-- loading. Do not turn that transient state into a session-long empty root.
	if catalog then
		journalTierCatalogCache[kind] = catalog
	end
	return catalog
end

local function buildJournalCatalogForTiers(kind, tiers)
	if not ensureJournalAPI(kind) then
		return nil
	end
	local previousTier = pcallFirst(EJ_GetCurrentTier)
	local catalog = newJournalCatalog()
	local complete = true
	for _, tierDescriptor in ipairs(tiers or EMPTY) do
		local selected = pcall(EJ_SelectTier, tierDescriptor.tier)
		if selected and type(EJ_GetCurrentTier) == "function" then
			selected = pcallFirst(EJ_GetCurrentTier) == tierDescriptor.tier
		end
		if selected then
			local dataIndex = 1
			local seen = {}
			while dataIndex <= 300 do
				local instance, state = journalInstanceAt(
					kind, tierDescriptor, dataIndex)
				if not instance then
					complete = state == "end"
					break
				end
				if seen[instance.journalInstanceID] then
					complete = false
					break
				end
				seen[instance.journalInstanceID] = true
				addJournalInstance(catalog, tierDescriptor, instance)
				dataIndex = dataIndex + 1
			end
			complete = complete and dataIndex <= 300
		else
			complete = false
		end
		if not complete then
			break
		end
	end
	if previousTier then
		pcall(EJ_SelectTier, previousTier)
	end
	return complete and finalizeJournalCatalog(catalog) or nil
end

local function journalExpansionCatalog(kind, expansionIndex)
	expansionIndex = tonumber(expansionIndex)
	if expansionIndex == nil then
		return nil
	end
	local kindCache = journalExpansionCatalogCache[kind]
	if not kindCache then
		kindCache = {}
		journalExpansionCatalogCache[kind] = kindCache
	end
	local cached = kindCache[expansionIndex]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local directory = journalTierCatalog(kind)
	if not directory then
		return nil
	end
	local tiers = directory and directory.tiersByExpansion[expansionIndex]
	local catalog = tiers and buildJournalCatalogForTiers(kind, tiers) or nil
	-- A present directory with no matching tier is a stable negative. A failed
	-- tier scan is not and remains retryable.
	if catalog then
		kindCache[expansionIndex] = catalog
	elseif not tiers then
		kindCache[expansionIndex] = false
	end
	return catalog
end

local function journalSeasonCatalog(kind, fresh)
	local cached = not fresh and journalSeasonCatalogCache[kind] or nil
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local directory
	if fresh then
		directory = buildJournalTierCatalog(kind)
	else
		directory = journalTierCatalog(kind)
	end
	if not directory then
		return nil
	end
	local expansionIndex = trustedJournalExpansionIndex()
	local baseTierCount = expansionIndex and expansionIndex + 1 or nil
	local tierCount = tonumber(directory.numTiers)
	if not baseTierCount or not tierCount
		or tierCount ~= baseTierCount + 1
		or #directory.seasonTiers ~= 1
	then
		-- A partial or multiply-extended tier directory is still useful to
		-- archive navigation, but it cannot define one precise current-season
		-- boundary yet. Keep the season read retryable so a later native update
		-- can replace this transient directory without requiring /reload.
		if not fresh then
			journalTierCatalogCache[kind] = nil
			journalSeasonCatalogCache[kind] = nil
		end
		return nil
	end
	-- Blizzard's GetEJTierData fallback is background-art metadata, not an
	-- alternate instance roster. Only the actual Current Season tier owns this
	-- catalog; never substitute current-expansion or Challenge Mode instances.
	local catalog = buildJournalCatalogForTiers(kind, directory.seasonTiers)
	if not catalog or #catalog.seasonInstances == 0 then
		return nil
	end
	if not fresh then
		journalSeasonCatalogCache[kind] = catalog
	end
	return catalog
end

local function journalCatalog(kind)
	local cached = journalCatalogCache[kind]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local directory = journalTierCatalog(kind)
	local catalog = directory
		and buildJournalCatalogForTiers(kind, directory.tiers) or nil
	if catalog then
		journalCatalogCache[kind] = catalog
	end
	return catalog
end

local function journalInstanceIDForMapID(mapID)
	mapID = tonumber(mapID)
	if not mapID or mapID <= 0 then
		return nil
	end
	local cached = journalInstanceIDByMapCache[mapID]
	if cached then
		return cached
	end
	if not (C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap) then
		return nil
	end
	local ok, journalInstanceID = pcall(C_EncounterJournal.GetInstanceForGameMap, mapID)
	if ok and journalInstanceID then
		journalInstanceIDByMapCache[mapID] = journalInstanceID
		return journalInstanceID
	end
	return nil
end

local function journalInstanceInfoByID(
	kind,
	journalInstanceID,
	mapID,
	instanceMapID,
	fallbackName
)
	journalInstanceID = tonumber(journalInstanceID)
	if not journalInstanceID or not ensureJournalAPI(kind)
		or type(EJ_GetInstanceInfo) ~= "function"
	then
		return nil
	end
	local ok, name, description, backgroundImage, buttonImage, loreImage,
		secondaryButtonImage, dungeonAreaMapID =
		pcall(EJ_GetInstanceInfo, journalInstanceID)
	if not ok then
		return nil
	end
	name = cleanText(name) or cleanText(fallbackName)
	if not name then
		return nil
	end
	local visualTexture = loreImage or backgroundImage
		or secondaryButtonImage or buttonImage
	return {
		journalInstanceID = journalInstanceID,
		label = name,
		description = description,
		mapID = tonumber(dungeonAreaMapID) or tonumber(mapID),
		instanceMapID = tonumber(instanceMapID),
		visualTexture = visualTexture,
		visualTexCoords = loreImage and JOURNAL_LORE_IMAGE_TEX_COORDS or nil,
		visualSource = loreImage and "loreImage"
			or (backgroundImage and "backgroundImage")
			or (secondaryButtonImage and "buttonImage2")
			or (buttonImage and "buttonImage1")
			or nil,
	}
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

local function isWorldBossLabel(value)
	value = cleanText(value)
	if not value then
		return false
	end
	local lower = string.lower(value)
	return value:find("世界首领", 1, true) ~= nil
		or value:find("世界首領", 1, true) ~= nil
		or lower:find("world boss", 1, true) ~= nil
end

local function worldBossLabelForInfo(info)
	if type(info) ~= "table" then
		return nil
	end
	local candidates = {
		activityBaseName(info),
		cleanText(info.fullName),
		cleanText(info.shortName),
	}
	for index = 1, 3 do
		local candidate = candidates[index]
		if isWorldBossLabel(candidate) then
			return stripKnownDifficultySuffix(candidate, info) or candidate
		end
	end
	return nil
end

local function worldBossContainerLabel(info, sourceLabel, journalLabel)
	journalLabel = trimText(journalLabel)
	if not journalLabel then
		return trimText(sourceLabel)
	end

	local fullName = cleanText(info and info.fullName) or trimText(sourceLabel)
	local shortName = cleanText(info and info.shortName)
	local base = stripKnownDifficultySuffix(shortName, info)
		or removeParentheticalHints(stripKnownDifficultySuffix(fullName, info))
		or removeParentheticalHints(sourceLabel)
		or cleanText(_G and _G.RAID_INFO_WORLD_BOSS)
		or "World Boss"
	base = trimText(base)
	if fullName and fullName:find("（", 1, true) then
		return base .. "（" .. journalLabel .. "）"
	end
	return base .. " (" .. journalLabel .. ")"
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

local function addCatalogCandidateFilter(candidate, filterFlags)
	filterFlags = tonumber(filterFlags)
	if filterFlags == nil or candidate._filterSeen[filterFlags] then
		return
	end
	candidate._filterSeen[filterFlags] = true
	candidate.filterSets[#candidate.filterSets + 1] = filterFlags
	if candidate.listFilters == nil then
		candidate.listFilters = filterFlags
	end
end

local function ensureCatalogGroupCandidate(groups, groupsByID, groupID)
	groupID = tonumber(groupID)
	if groupID == nil or groupID <= 0 then
		return nil
	end
	local candidate = groupsByID[groupID]
	if not candidate then
		candidate = {
			groupID = groupID,
			filterSets = {},
			_filterSeen = {},
		}
		groupsByID[groupID] = candidate
		groups[#groups + 1] = candidate
	end
	return candidate
end

local function addCatalogCandidates(
	groups,
	groupsByID,
	solos,
	solosByID,
	source,
	expansionIndex
)
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		if expansionIndex == nil
			or tonumber(expansion.expansionIndex) == tonumber(expansionIndex)
		then
			for _, instance in ipairs(expansion.instances or EMPTY) do
				local groupID = tonumber(instance and instance.groupID)
				local activityID = tonumber(instance and instance.activityID)
				if groupID and groupID > 0 then
					local candidate = ensureCatalogGroupCandidate(
						groups, groupsByID, groupID)
					addCatalogCandidateFilter(candidate, instance.listFilters)
				elseif activityID and activityID > 0 then
					local candidate = solosByID[activityID]
					if not candidate then
						candidate = {
							activityID = activityID,
							filterSets = {},
							_filterSeen = {},
						}
						solosByID[activityID] = candidate
						solos[#solos + 1] = candidate
					end
					addCatalogCandidateFilter(candidate, instance.listFilters)
				end
			end
		end
	end
end

local function addCatalogActivitySeedCandidates(groups, groupsByID, source)
	-- The 12.1 DB2 snapshot supplies candidate group keys only. Its activity IDs
	-- must never bypass the same GetAvailableActivities calls used by Blizzard's
	-- EntryCreation dropdown; current LFG availability is the display authority.
	local groupIDs = {}
	for groupID, activityIDs in pairs(source or EMPTY) do
		local normalizedGroupID = tonumber(groupID)
		if normalizedGroupID and normalizedGroupID > 0
			and type(activityIDs) == "table" and #activityIDs > 0 then
			groupIDs[#groupIDs + 1] = normalizedGroupID
		end
	end
	table.sort(groupIDs)
	for _, groupID in ipairs(groupIDs) do
		ensureCatalogGroupCandidate(groups, groupsByID, groupID)
	end
end

local function addReusableCatalogCandidates(
	kind,
	groups,
	groupsByID,
	solos,
	solosByID,
	source
)
	local reusableGroups = GF.NAV_CATALOG_REUSABLE_JOURNAL_GROUPS
		and GF.NAV_CATALOG_REUSABLE_JOURNAL_GROUPS[kind]
	local reusableActivities = GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES
		and GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES[kind]
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		for _, instance in ipairs(expansion.instances or EMPTY) do
			local groupID = tonumber(instance and instance.groupID)
			local activityID = tonumber(instance and instance.activityID)
			if groupID and type(reusableGroups) == "table"
				and reusableGroups[groupID] == true
			then
				local candidate = ensureCatalogGroupCandidate(
					groups, groupsByID, groupID)
				addCatalogCandidateFilter(candidate, instance.listFilters)
			elseif activityID and type(reusableActivities) == "table"
				and reusableActivities[activityID] == true
			then
				local candidate = solosByID[activityID]
				if not candidate then
					candidate = {
						activityID = activityID,
						filterSets = {},
						_filterSeen = {},
					}
					solosByID[activityID] = candidate
					solos[#solos + 1] = candidate
				end
				addCatalogCandidateFilter(candidate, instance.listFilters)
			end
		end
	end
end

local function catalogCandidates(kind, expansionIndex)
	local groups, solos = {}, {}
	local groupsByID, solosByID = {}, {}
	addCatalogCandidates(groups, groupsByID, solos, solosByID,
		GF.NAV_CATALOG and GF.NAV_CATALOG[kind], expansionIndex)
	addCatalogCandidates(groups, groupsByID, solos, solosByID,
		GF.NAV_CATALOG_SUPPLEMENT and GF.NAV_CATALOG_SUPPLEMENT[kind],
		expansionIndex)
	addCatalogCandidates(groups, groupsByID, solos, solosByID,
		GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind], expansionIndex)
	if expansionIndex ~= nil then
		-- Some Journal tiers intentionally reuse one live activity group or
		-- standalone activity (for example a revamped Classic entrance). Retain
		-- only those explicitly allow-listed cross-tier candidates.
		addReusableCatalogCandidates(kind, groups, groupsByID, solos, solosByID,
			GF.NAV_CATALOG and GF.NAV_CATALOG[kind])
		addReusableCatalogCandidates(kind, groups, groupsByID, solos, solosByID,
			GF.NAV_CATALOG_SUPPLEMENT and GF.NAV_CATALOG_SUPPLEMENT[kind])
		addReusableCatalogCandidates(kind, groups, groupsByID, solos, solosByID,
			GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind])
	end
	-- Activity seed snapshots do not carry an expansion identity. They remain a
	-- full-catalog fallback but cannot safely broaden a single expansion build.
	if expansionIndex == nil then
		addCatalogActivitySeedCandidates(groups, groupsByID,
			GF.NAV_CATALOG_ACTIVITY_SEEDS and GF.NAV_CATALOG_ACTIVITY_SEEDS[kind])
	end
	for _, candidate in ipairs(groups) do
		candidate._filterSeen = nil
	end
	for _, candidate in ipairs(solos) do
		candidate._filterSeen = nil
	end
	return groups, solos
end

local function archiveGroupExcluded(kind, groupID)
	local excluded = GF.NAV_CATALOG_ARCHIVE_EXCLUDED_GROUPS
		and GF.NAV_CATALOG_ARCHIVE_EXCLUDED_GROUPS[kind]
	return type(excluded) == "table" and excluded[tonumber(groupID)] == true
end

local function buildArchiveFilterSets(kind, candidate)
	local filters, seen = {}, {}
	for _, filterFlags in ipairs(buildFilterSets(kind)) do
		addUnique(filters, seen, filterFlags)
	end
	if kind == "dungeon" or kind == "raid" then
		-- Cover the rotation/current-expansion endpoints even when a PTR build
		-- requires the complete record mask instead of accepting a broad subset.
		addUnique(filters, seen, bor(RECOMMENDED, CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(NOT_RECOMMENDED, CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(RECOMMENDED, CURRENT_EXPANSION, CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(NOT_RECOMMENDED, NOT_CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(RECOMMENDED, CURRENT_EXPANSION, NOT_CURRENT_SEASON, PVE))
		addUnique(filters, seen, bor(NOT_RECOMMENDED, CURRENT_EXPANSION, NOT_CURRENT_SEASON, PVE))
	end
	for _, filterFlags in ipairs(candidate and candidate.filterSets or EMPTY) do
		addUnique(filters, seen, filterFlags)
	end
	local nativeSourceCount = #filters
	for index = 1, nativeSourceCount do
		addUnique(filters, seen, resolveEntryCreationFilter(kind, filters[index]))
	end
	return filters
end

local function journalExpansionBoundary(journal, expansionIndex)
	expansionIndex = tonumber(expansionIndex)
	if expansionIndex == nil or type(journal) ~= "table" then
		return nil
	end
	local boundary = {
		journalInstanceIDs = {},
		mapIDs = {},
		nameKeys = {},
	}
	for _, expansion in ipairs(journal.expansions or EMPTY) do
		if tonumber(expansion and expansion.expansionIndex) == expansionIndex then
			for _, instance in ipairs(expansion.instances or EMPTY) do
				local journalInstanceID = tonumber(instance and instance.journalInstanceID)
				if journalInstanceID then
					boundary.journalInstanceIDs[journalInstanceID] = true
				end
				local function addMapID(mapID)
					mapID = tonumber(mapID)
					if mapID and mapID > 0 then
						boundary.mapIDs[mapID] = true
					end
				end
				addMapID(instance and instance.mapID)
				addMapID(instance and instance.instanceMapID)
				local nameKey = normalizedName(instance and instance.label)
				if nameKey then
					boundary.nameKeys[nameKey] = true
				end
			end
		end
	end
	return boundary
end

local function activityMatchesExpansionBoundary(info, boundary)
	if type(info) ~= "table" or type(boundary) ~= "table" then
		return false
	end
	local mapID = tonumber(info.mapID)
	if mapID and boundary.mapIDs[mapID] then
		return true
	end
	local journalInstanceID = journalInstanceIDForMapID(mapID)
	if journalInstanceID and boundary.journalInstanceIDs[journalInstanceID] then
		return true
	end
	local function nameMatches(value)
		local nameKey = normalizedName(value)
		if nameKey and boundary.nameKeys[nameKey] then
			return true
		end
		return false
	end
	return nameMatches(activityBaseName(info))
		or nameMatches(info.fullName)
		or nameMatches(info.shortName)
end

local function buildRuntimeEntries(kind, filterSets, options)
	local meta = catalogMeta(kind)
	if not meta or not meta.categoryID then
		return nil, nil
	end
	options = options or EMPTY
	local exactFilters = options.exactFilters == true
	local probeOnly = options.probeOnly == true
	local allowStaticIdentityFallbacks =
		options.allowStaticIdentityFallbacks ~= false
	local expansionIndex = tonumber(options.expansionIndex)
	local expansionBoundary = options.expansionBoundary
	filterSets = filterSets or buildFilterSets(kind)
	local groupCandidates, soloCandidates = EMPTY, EMPTY
	if not exactFilters then
		if options.groupCandidates ~= nil or options.soloCandidates ~= nil then
			groupCandidates = options.groupCandidates or EMPTY
			soloCandidates = options.soloCandidates or EMPTY
		else
			groupCandidates, soloCandidates = catalogCandidates(kind, expansionIndex)
		end
	end
	local allowedGroupIDs
	if expansionIndex ~= nil then
		allowedGroupIDs = {}
		for _, candidate in ipairs(groupCandidates) do
			allowedGroupIDs[candidate.groupID] = true
		end
	end

	local groupStates = {}
	local availableGroupsByFilter = {}
	local seenActivities = {}
	local topLevelActivitiesByFilter = {}
	local catalogActivitiesScannedByFilter = {}
	local boundaryMatchesByActivity = {}
	local entries = {}
	local lookup = {
		byJournalInstanceID = {},
		byMapID = {},
		byName = {},
		reusableJournalEntries = {},
		enumeratedGroupIDs = {},
	}
	local addGroup
	local reusableActivityIDs = GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES
		and GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES[kind]

	local function reusableJournalEntry(entry)
		return type(reusableActivityIDs) == "table"
			and entry and entry.activityID
			and reusableActivityIDs[tonumber(entry.activityID)] == true
	end

	local function infoMatchesCategory(info)
		return type(info) == "table" and tonumber(info.categoryID) == meta.categoryID
	end

	local function addEntry(entry)
		entries[#entries + 1] = entry
		addEntryLookups(lookup, entry)
		if reusableJournalEntry(entry) then
			lookup.reusableJournalEntries[#lookup.reusableJournalEntries + 1] = entry
		end
	end

	local function getTopLevelActivities(filterFlags)
		filterFlags = tonumber(filterFlags) or 0
		local cached = topLevelActivitiesByFilter[filterFlags]
		if cached then
			return cached
		end
		local activities, seen = {}, {}
		mergeActivityList(activities, seen,
			getAvailableActivities(meta.categoryID, 0, filterFlags))
		mergeActivityList(activities, seen,
			getAvailableActivities(meta.categoryID, nil, filterFlags))
		-- EntryCreation's Activity Finder always supplies its text argument,
		-- starting with an empty string when the dialog first opens. Retail can
		-- return legacy standalone activities through that four-argument path
		-- even when both three-argument category-level calls omit them.
		mergeActivityList(activities, seen,
			getAvailableActivities(meta.categoryID, nil, filterFlags, ""))
		topLevelActivitiesByFilter[filterFlags] = activities
		return activities
	end

	local function addSoloActivity(activityID, filterFlags, info)
		activityID = tonumber(activityID)
		if not activityID or seenActivities[activityID] then
			return
		end
		info = info or getActivityInfo(activityID)
		if not infoMatchesCategory(info) then
			return
		end
		-- Availability can expose an activity ID one call before its info table is
		-- readable during login/native Group Finder warm-up. Only memoize a
		-- successfully validated record; otherwise later filter/query passes must
		-- be allowed to retry the same ID instead of permanently greying its
		-- Encounter Journal row.
		seenActivities[activityID] = true
		local groupID = activityGroupID(info)
		if groupID then
			addGroup(groupID, filterFlags, info, activityID, "finder")
			return
		end
		local worldBossLabel
		if kind == "raid" then
			worldBossLabel = worldBossLabelForInfo(info)
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
			worldBoss = worldBossLabel ~= nil,
			worldBossLabel = worldBossLabel,
		}
		addEntry(entry)
	end

	local function addCatalogActivity(activityID, filterFlags)
		local info = getActivityInfo(activityID)
		local groupID = activityGroupID(info)
		local matchesBoundary = boundaryMatchesByActivity[activityID]
		if matchesBoundary == nil then
			matchesBoundary = activityMatchesExpansionBoundary(
				info, expansionBoundary)
			-- Activity info may warm up one query later. Cache only a validated
			-- table result so a transient nil cannot become a false boundary for
			-- the rest of this build.
			if type(info) == "table" then
				boundaryMatchesByActivity[activityID] = matchesBoundary
			end
		end
		if groupID and matchesBoundary and allowedGroupIDs then
			allowedGroupIDs[groupID] = true
		end
		if expansionIndex == nil
			or (groupID and allowedGroupIDs[groupID])
			or matchesBoundary
		then
			addSoloActivity(activityID, filterFlags, info)
		end
	end

	local function scanCatalogActivities(filterFlags)
		filterFlags = tonumber(filterFlags) or 0
		if catalogActivitiesScannedByFilter[filterFlags] then
			return
		end
		catalogActivitiesScannedByFilter[filterFlags] = true
		for _, activityID in ipairs(getTopLevelActivities(filterFlags)) do
			addCatalogActivity(activityID, filterFlags)
		end
	end

	local function soloActivityMatchesCandidate(candidate, candidateInfo, activityID, info)
		local candidateActivityID = tonumber(candidate and candidate.activityID)
		activityID = tonumber(activityID)
		if not candidateActivityID or not activityID
			or not infoMatchesCategory(info) or activityGroupID(info)
		then
			return false
		end
		if activityID == candidateActivityID then
			return true
		end
		if not infoMatchesCategory(candidateInfo) or activityGroupID(candidateInfo) then
			return false
		end

		local candidateName = normalizedName(activityBaseName(candidateInfo))
		local activityName = normalizedName(activityBaseName(info))
		if not candidateName or candidateName ~= activityName then
			return false
		end
		local candidateMapID = tonumber(candidateInfo.mapID)
		local activityMapID = tonumber(info.mapID)
		if candidateMapID and candidateMapID > 0 and activityMapID and activityMapID > 0
			and candidateMapID ~= activityMapID
		then
			return false
		end
		local difficultyGetter = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyIndex
		if difficultyGetter then
			local candidateDifficulty = tonumber(difficultyGetter(candidateInfo, { includeMplus = true }))
			local activityDifficulty = tonumber(difficultyGetter(info, { includeMplus = true }))
			if candidateDifficulty and candidateDifficulty > 0
				and activityDifficulty and activityDifficulty > 0
				and candidateDifficulty ~= activityDifficulty
			then
				return false
			end
		end
		return true
	end

	local function legacySoloFallbackForCandidate(candidate)
		local fallbacks = GF.NAV_CATALOG_LEGACY_SOLO_ACTIVITY_FALLBACKS
			and GF.NAV_CATALOG_LEGACY_SOLO_ACTIVITY_FALLBACKS[kind]
		local activityID = tonumber(candidate and candidate.activityID)
		return type(fallbacks) == "table" and activityID and fallbacks[activityID] or nil
	end

	local function legacySoloFallbackJournalNames(fallback)
		local names, seen = {}, {}
		local mapID = tonumber(fallback and fallback.mapID)
		local function add(label)
			label = cleanText(label)
			local key = normalizedName(label)
			if label and key and not seen[key] then
				seen[key] = true
				names[#names + 1] = label
			end
		end
		-- buildRuntimeCatalog creates the requested expansion snapshot before it
		-- authorizes LFG candidates. Reuse that narrow Journal boundary instead
		-- of scanning every expansion for one legacy fallback name.
		for _, catalog in pairs(journalExpansionCatalogCache[kind] or EMPTY) do
			for _, journalInstance in ipairs(
				catalog and catalog.byMapID and catalog.byMapID[mapID] or EMPTY
			) do
				add(journalInstance and journalInstance.label)
			end
		end
		if #names == 0 then
			local journalInstanceID = mapID and journalInstanceIDForMapID(mapID)
			local journalInstance = journalInstanceInfoByID(
				kind, journalInstanceID, mapID, nil)
			add(journalInstance and journalInstance.label)
		end
		return names
	end

	local function activityMatchesLegacySoloFallback(info, fallback)
		if not fallback or not infoMatchesCategory(info) or activityGroupID(info) then
			return false
		end
		local expectedMapID = tonumber(fallback.mapID)
		local activityMapID = tonumber(info.mapID)
		if not expectedMapID or expectedMapID <= 0 or activityMapID ~= expectedMapID then
			return false
		end
		local activityName = normalizedName(activityBaseName(info))
		if not activityName then
			return false
		end
		for _, journalName in ipairs(legacySoloFallbackJournalNames(fallback)) do
			if normalizedName(journalName) == activityName then
				return true
			end
		end
		return false
	end

	local function authorizeSoloCandidateBySearch(candidate, filterFlags, candidateInfo)
		local searchTexts, searchTextSeen = {}, {}
		local function addSearchText(value)
			value = cleanText(value)
			local key = normalizedName(value)
			if value and key and not searchTextSeen[key] then
				searchTextSeen[key] = true
				searchTexts[#searchTexts + 1] = value
			end
		end
		addSearchText(activityBaseName(candidateInfo))
		addSearchText(candidateInfo and candidateInfo.fullName)
		addSearchText(candidateInfo and candidateInfo.shortName)
		local fallback = legacySoloFallbackForCandidate(candidate)
		for _, journalName in ipairs(legacySoloFallbackJournalNames(fallback)) do
			addSearchText(journalName)
		end
		if #searchTexts == 0 then
			return false
		end

		-- Blizzard's EntryCreation Activity Finder passes its text box as the
		-- fourth GetAvailableActivities argument. Some group-less legacy records
		-- (for example Blackwing Lair) are discoverable through that native path
		-- even when the unfiltered category-level enumeration omits them. Static
		-- data remains identity evidence only: the returned current activity must
		-- still match its category, group-less state, base name, map, and difficulty.
		for _, searchText in ipairs(searchTexts) do
			for _, activityID in ipairs(getAvailableActivities(
				meta.categoryID,
				nil,
				filterFlags,
				searchText
			)) do
				local info = getActivityInfo(activityID)
				if soloActivityMatchesCandidate(candidate, candidateInfo, activityID, info)
					or activityMatchesLegacySoloFallback(info, fallback)
				then
					addSoloActivity(tonumber(activityID), filterFlags, info)
					return true
				end
			end
		end
		return false
	end

	local function authorizeLegacySoloFallback(candidate, filterFlags, candidateInfo)
		local fallback = legacySoloFallbackForCandidate(candidate)
		if not activityMatchesLegacySoloFallback(candidateInfo, fallback) then
			return false
		end
		addSoloActivity(tonumber(candidate.activityID), filterFlags, candidateInfo)
		return true
	end

	local function getGroupState(groupID)
		groupID = tonumber(groupID)
		if not groupID or groupID <= 0 then
			return nil
		end
		local state = groupStates[groupID]
		if not state then
			state = {
				groupID = groupID,
				activityIDs = {},
				activitySeen = {},
				queriedFilters = {},
				availableFilters = {},
				finderFilters = {},
			}
			groupStates[groupID] = state
		end
		return state
	end

	local function observeAvailableGroups(filterFlags)
		filterFlags = tonumber(filterFlags) or 0
		local groups = availableGroupsByFilter[filterFlags]
		if groups then
			return groups
		end
		groups = getAvailableActivityGroups(meta.categoryID, filterFlags)
		availableGroupsByFilter[filterFlags] = groups
		for _, groupID in ipairs(groups) do
			groupID = tonumber(groupID)
			local state = getGroupState(groupID)
			if state then
				state.availableFilters[filterFlags] = true
				lookup.enumeratedGroupIDs[groupID] = true
			end
		end
		return groups
	end

	local function authorizeGroupActivity(state, activityID, filterFlags, info)
		activityID = tonumber(activityID)
		if not activityID then
			return false
		end
		info = info or getActivityInfo(activityID)
		if not infoMatchesCategory(info) or activityGroupID(info) ~= state.groupID then
			return false
		end
		if not state.activitySeen[activityID] then
			state.activitySeen[activityID] = true
			state.activityIDs[#state.activityIDs + 1] = activityID
		end
		if not state.firstInfo then
			state.firstInfo = info
		end
		if state.firstFilter == nil then
			state.firstFilter = tonumber(filterFlags) or 0
		end
		return true
	end

	local function queryGroupFilter(state, filterFlags)
		filterFlags = tonumber(filterFlags) or 0
		-- A static archive group is only an identity probe. Retail can continue
		-- returning retired activities for a direct group query after the native
		-- Activity Finder has stopped enumerating that group/filter pair. Only a
		-- group observed from GetAvailableActivityGroups(), or one discovered by a
		-- category-level Activity Finder result, may authorize ordinary leaves.
		if not exactFilters
			and state.availableFilters[filterFlags] ~= true
			and state.finderFilters[filterFlags] ~= true
		then
			return
		end
		if state.queriedFilters[filterFlags] then
			return
		end
		state.queriedFilters[filterFlags] = true
		for _, activityID in ipairs(getAvailableActivities(meta.categoryID, state.groupID, filterFlags)) do
			authorizeGroupActivity(state, activityID, filterFlags)
		end
	end

	local function queryGroupFilters(state, filterFlags)
		queryGroupFilter(state, filterFlags)
		if exactFilters then
			return
		end
		-- Retail/PTR can partition a category by its Recommended bit even when
		-- bare PvE yields no activities. Union the native PvE partitions while
		-- retaining the record-specific season/expansion filter above.
		queryGroupFilter(state, PVE)
		queryGroupFilter(state, bor(RECOMMENDED, PVE))
		queryGroupFilter(state, bor(NOT_RECOMMENDED, PVE))
	end

	local function legacyGroupSearchFallback(groupID)
		local fallbacks = GF.NAV_CATALOG_LEGACY_GROUP_SEARCH_FALLBACKS
			and GF.NAV_CATALOG_LEGACY_GROUP_SEARCH_FALLBACKS[kind]
		return type(fallbacks) == "table" and fallbacks[tonumber(groupID)] or nil
	end

	local function legacyGroupSearchTexts(groupID, fallback)
		local texts, seen = {}, {}
		local function add(value)
			value = cleanText(value)
			local key = normalizedName(value)
			if value and key and not seen[key] then
				seen[key] = true
				texts[#texts + 1] = value
			end
		end

		local groupName = getActivityGroupInfo(groupID)
		add(groupName)

		-- GetInstanceForGameMap is a system API, while EJ_GetInstanceInfo is
		-- supplied by Blizzard_EncounterJournal. Use the latter only when Blizzard
		-- has already loaded it; a legacy name fallback cannot justify a forced
		-- synchronous UI-addon load.
		ensureJournalAPI(kind)
		local journalInstanceID = journalInstanceIDForMapID(fallback and fallback.mapID)
		if journalInstanceID and type(EJ_GetInstanceInfo) == "function" then
			add(pcallFirst(EJ_GetInstanceInfo, journalInstanceID))
		end
		return texts
	end

	local function authorizeLegacyGroupBySearch(candidate, state)
		local fallback = legacyGroupSearchFallback(candidate and candidate.groupID)
		local expectedMapID = tonumber(fallback and fallback.mapID)
		if not state or #state.activityIDs > 0 or not expectedMapID or expectedMapID <= 0 then
			return false
		end
		local searchTexts = legacyGroupSearchTexts(state.groupID, fallback)
		if #searchTexts == 0 then
			return false
		end
		local searchNameKeys = {}
		for _, searchText in ipairs(searchTexts) do
			searchNameKeys[normalizedName(searchText)] = true
		end

		local filterSets, filterSeen = {}, {}
		local queriedFilters = {}
		for filterFlags in pairs(state.queriedFilters) do
			queriedFilters[#queriedFilters + 1] = filterFlags
		end
		table.sort(queriedFilters)
		for _, filterFlags in ipairs(queriedFilters) do
			addUnique(filterSets, filterSeen, filterFlags)
		end
		for _, filterFlags in ipairs(candidate.filterSets or EMPTY) do
			addUnique(filterSets, filterSeen, filterFlags)
		end
		addUnique(filterSets, filterSeen, meta.baseFilters)
		addUnique(filterSets, filterSeen, meta.preferredFilters)
		addUnique(filterSets, filterSeen, 0)

		local function authorizeResults(activityIDs, filterFlags)
			for _, activityID in ipairs(activityIDs or EMPTY) do
				local info = getActivityInfo(activityID)
				local activityNameKey = normalizedName(activityBaseName(info))
				if infoMatchesCategory(info)
					and tonumber(info.mapID) == expectedMapID
					and activityNameKey and searchNameKeys[activityNameKey]
				then
					-- Native Activity Finder can return a currently creatable legacy
					-- dungeon as the old group, a replacement group, or a top-level
					-- activity. Preserve that current structure instead of requiring the
					-- 12.0.7 group identity to remain unchanged.
					local replacementGroupID = activityGroupID(info)
					if replacementGroupID and allowedGroupIDs then
						-- The exact map/name match above is the authorization boundary for
						-- a live replacement group in this expansion.
						allowedGroupIDs[replacementGroupID] = true
					end
					addSoloActivity(tonumber(activityID), filterFlags, info)
					for _, entry in ipairs(entries) do
						if tonumber(entry.activityID) == tonumber(activityID) then
							return true
						end
						for _, entryActivityID in ipairs(entry.activityIDs or EMPTY) do
							if tonumber(entryActivityID) == tonumber(activityID) then
								return true
							end
						end
					end
				end
			end
			return false
		end

		for _, filterFlags in ipairs(filterSets) do
			for _, searchText in ipairs(searchTexts) do
				-- The group-scoped form mirrors EntryCreation's Activity Finder;
				-- the category-scoped form mirrors Blizzard's autocomplete path.
				if authorizeResults(getAvailableActivities(
					meta.categoryID, state.groupID, filterFlags, searchText
				), filterFlags) or authorizeResults(getAvailableActivities(
					meta.categoryID, nil, filterFlags, searchText
				), filterFlags) then
					return true
				end
			end
		end
		return false
	end

	addGroup = function(groupID, filterFlags, seedInfo, seedActivityID, authority)
		if expansionIndex ~= nil and not allowedGroupIDs[tonumber(groupID)] then
			return
		end
		if not exactFilters and archiveGroupExcluded(kind, groupID) then
			return
		end
		local state = getGroupState(groupID)
		if not state then
			return
		end
		filterFlags = tonumber(filterFlags) or 0
		if authority == "finder" then
			state.finderFilters[filterFlags] = true
		elseif authority == "legacy" then
			state.legacyAuthorized = true
		end
		-- The category-level GetAvailableActivities query is exactly what
		-- Blizzard's Activity Finder consumes. Keep that returned activity even
		-- when a second group-scoped query does not echo the same ID.
		if seedActivityID then
			authorizeGroupActivity(state, seedActivityID, filterFlags, seedInfo)
		end
		queryGroupFilters(state, filterFlags)
		if state.entry or #state.activityIDs == 0 then
			return
		end
		if not exactFilters
			and state.legacyAuthorized ~= true
			and next(state.availableFilters) == nil
			and next(state.finderFilters) == nil
		then
			return
		end

		local firstInfo = infoMatchesCategory(seedInfo) and seedInfo or state.firstInfo
		if not firstInfo then
			return
		end
		local groupName, groupOrder = getActivityGroupInfo(groupID)
		groupName = cleanText(groupName) or activityBaseName(firstInfo)
		if not groupName then
			return
		end
		local listFilters = deriveListFilters(
			meta.categoryID, state.firstFilter or filterFlags, state.activityIDs)
		local mapID = tonumber(firstInfo and firstInfo.mapID)
		local journalInstanceID = journalInstanceIDForMapID(mapID)
		if not journalInstanceID then
			for _, activityID in ipairs(state.activityIDs) do
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
			activityIDs = state.activityIDs,
			filterFlags = state.firstFilter or filterFlags,
			info = firstInfo,
			groupName = groupName,
			label = kind == "dungeon" and groupName or nil,
			mapID = mapID,
			journalInstanceID = journalInstanceID,
			nameKeys = makeEntryNameKeys(groupName, firstInfo),
		}
		state.entry = entry
		addEntry(entry)
	end

	if not probeOnly then
		for _, filterFlags in ipairs(filterSets) do
			for _, groupID in ipairs(observeAvailableGroups(filterFlags)) do
				addGroup(groupID, filterFlags)
			end
			scanCatalogActivities(filterFlags)
		end
	end
	-- Exact catalogs deliberately ignore the ordinary archive candidate graph,
	-- but a current group may still be omitted from GetAvailableActivityGroups
	-- while its group-scoped GetAvailableActivities call is valid. Allow callers
	-- to supply read-only probe keys. A key never authorizes itself: addGroup still
	-- requires a currently returned activity with strict category/group identity.
	if exactFilters then
		for _, groupID in ipairs(options.probeGroupIDs or EMPTY) do
			for _, filterFlags in ipairs(filterSets) do
				addGroup(groupID, filterFlags)
			end
		end
	end
	if not exactFilters then
		-- Ordinary dungeon/raid archives are Encounter Journal/catalog projections,
		-- not merely copies of GetAvailableActivityGroups. Probe every known group
		-- across its generated/manual and Blizzard season/expansion filter family,
		-- while requiring that the native group selector actually exposes the same
		-- group/filter pair before its direct activity response becomes authority.
		for _, candidate in ipairs(groupCandidates) do
			for _, filterFlags in ipairs(buildArchiveFilterSets(kind, candidate)) do
				observeAvailableGroups(filterFlags)
				addGroup(candidate.groupID, filterFlags)
				-- Activity Finder resolves the same candidate filter and queries at
				-- category level. Those returned IDs are independent of whether the
				-- candidate's group-scoped query echoes them.
				scanCatalogActivities(filterFlags)
			end
			local state = getGroupState(candidate.groupID)
			local fallbackByGroup = GF.NAV_CATALOG_LEGACY_GROUP_ACTIVITY_FALLBACKS
				and GF.NAV_CATALOG_LEGACY_GROUP_ACTIVITY_FALLBACKS[kind]
			local fallbackActivityIDs = fallbackByGroup
				and fallbackByGroup[candidate.groupID]
			if allowStaticIdentityFallbacks
				and state and #state.activityIDs == 0
				and type(fallbackActivityIDs) == "table"
			then
				for _, activityID in ipairs(fallbackActivityIDs) do
					local info = getActivityInfo(activityID)
					local searchFallback = legacyGroupSearchFallback(candidate.groupID)
					local expectedMapID = tonumber(searchFallback and searchFallback.mapID)
					if infoMatchesCategory(info)
						and activityGroupID(info) == candidate.groupID
						and (not expectedMapID or tonumber(info.mapID) == expectedMapID)
					then
						addGroup(
							candidate.groupID,
							tonumber(info.filters) or candidate.filterSets[1] or meta.baseFilters or 0,
							info,
							activityID,
							"legacy"
						)
					end
				end
			end
			if state and #state.activityIDs == 0 then
				authorizeLegacyGroupBySearch(candidate, state)
			end
		end
		-- Group-less records (notably world bosses and legacy standalone dungeon
		-- activities) remain API-authorized: the ID must be returned by a current
		-- category-level availability query before its runtime info may form a node.
		for _, candidate in ipairs(soloCandidates) do
			local added = false
			local info = getActivityInfo(candidate.activityID)
			local archiveFilterSets = buildArchiveFilterSets(kind, candidate)
			for _, filterFlags in ipairs(archiveFilterSets) do
				for _, activityID in ipairs(getTopLevelActivities(filterFlags)) do
					local activityInfo = getActivityInfo(activityID)
					local matchesCandidate = soloActivityMatchesCandidate(
						candidate, info, activityID, activityInfo)
					-- Every category-level Activity Finder result is live authorization.
					-- Add it before consulting the static candidate so a replaced legacy
					-- ID can still match its current Journal row by runtime map/name.
					if expansionIndex == nil or matchesCandidate then
						addSoloActivity(tonumber(activityID), filterFlags, activityInfo)
					end
					if matchesCandidate then
						added = true
						break
					end
				end
				if added then
					break
				end
			end
			if not added then
				local searchFilterSets, searchFilterSeen = {}, {}
				addUnique(searchFilterSets, searchFilterSeen, tonumber(info and info.filters))
				for _, filterFlags in ipairs(candidate.filterSets or EMPTY) do
					addUnique(searchFilterSets, searchFilterSeen, filterFlags)
				end
				local nativeSourceCount = #searchFilterSets
				for index = 1, nativeSourceCount do
					addUnique(searchFilterSets, searchFilterSeen,
						resolveEntryCreationFilter(kind, searchFilterSets[index]))
				end
				addUnique(searchFilterSets, searchFilterSeen, meta.baseFilters)
				addUnique(searchFilterSets, searchFilterSeen, meta.preferredFilters)
				addUnique(searchFilterSets, searchFilterSeen, 0)
				for _, filterFlags in ipairs(searchFilterSets) do
					if authorizeSoloCandidateBySearch(candidate, filterFlags, info)
						or (allowStaticIdentityFallbacks
							and authorizeLegacySoloFallback(candidate, filterFlags, info))
					then
						break
					end
				end
			end
		end
	end

	return entries, lookup, meta
end

local function copyEntryForCatalog(entry, journalInstance, kind)
	local out = {
		challengeModeID = entry.challengeModeID,
		groupID = entry.groupID,
		activityID = entry.activityID,
		-- Runtime entry construction already required this exact API snapshot to
		-- pass category/group identity checks. Carry it across the catalog boundary
		-- so a later transient GetActivityInfoTable() miss cannot erase an otherwise
		-- authorized group-less activity while NavData builds the visible branch.
		activityInfo = entry.info,
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
	if kind == "dungeon" then
		local info = entry.info or getActivityInfo(entry.activityID)
		out.activityInfo = out.activityInfo or info
		out.label = cleanText(activityBaseName(info)) or out.label
	end
	return out
end

local function copyWorldBossEntryForCatalog(entry, journalInstance, label)
	local out = copyEntryForCatalog(entry, journalInstance)
	out.label = cleanText(label) or out.label
	out.worldBossContainer = true
	return out
end

local function copyUnavailableJournalInstance(journalInstance, label, worldBossContainer)
	return {
		challengeModeID = journalInstance and journalInstance.challengeModeID,
		journalInstanceID = journalInstance and journalInstance.journalInstanceID,
		mapID = journalInstance and journalInstance.mapID,
		instanceMapID = journalInstance and journalInstance.instanceMapID,
		orderIndex = journalInstance and journalInstance.orderIndex,
		label = cleanText(label) or (journalInstance and journalInstance.label),
		visualTexture = journalInstance and journalInstance.visualTexture,
		visualTexCoords = journalInstance and journalInstance.visualTexCoords,
		visualSource = journalInstance and journalInstance.visualSource,
		catalogUnavailable = true,
		worldBossContainer = worldBossContainer == true and true or nil,
	}
end

local function currentPlayerLevel()
	if type(UnitLevel) ~= "function" then
		return nil
	end
	local ok, level = pcall(UnitLevel, "player")
	level = ok and tonumber(level) or nil
	return level and level > 0 and level or nil
end

local function currentClientBuild()
	local build = GF.Compat and tonumber(GF.Compat.build)
	if build then
		return build
	end
	if type(GetBuildInfo) == "function" then
		local ok, _, value = pcall(GetBuildInfo)
		if ok then
			return tonumber(value)
		end
	end
	return nil
end

local function precomputedRequiredLevel(shell, playerLevel)
	if type(shell and shell.availableActivityIDs) == "table" then
		-- The current native Activity Finder directory is the publication
		-- authority. A build snapshot must not override an activity which the
		-- client has already declared available to this character.
		return nil
	end
	playerLevel = tonumber(playerLevel) or currentPlayerLevel()
	if not playerLevel
		or tonumber(shell and shell.fallbackMinLevelBuild)
			~= currentClientBuild()
		or type(shell and shell.fallbackMinLevels) ~= "table"
	then
		return nil
	end
	local requiredLevel
	local sawCandidate = false
	for _, activityID in ipairs(shell and shell.fallbackActivityIDs or EMPTY) do
		local minLevel = tonumber(shell.fallbackMinLevels[tonumber(activityID)])
		if minLevel == nil then
			return nil
		end
		sawCandidate = true
		if minLevel <= 0 or playerLevel >= minLevel then
			-- One candidate already meets the hard level floor. Its native absence
			-- cannot truthfully be explained as a level restriction.
			return nil
		end
		requiredLevel = requiredLevel and math.min(requiredLevel, minLevel)
			or minLevel
	end
	return sawCandidate and requiredLevel or nil
end

local function activityListContainsID(activities, targetActivityID)
	targetActivityID = tonumber(targetActivityID)
	for _, activityID in ipairs(activities or EMPTY) do
		if tonumber(activityID) == targetActivityID then
			return true
		end
	end
	return false
end

local function strictLegacySoloEntryForJournalBoundary(kind, meta, journalInstance)
	local fallbacks = GF.NAV_CATALOG_LEGACY_SOLO_ACTIVITY_FALLBACKS
		and GF.NAV_CATALOG_LEGACY_SOLO_ACTIVITY_FALLBACKS[kind]
	if type(fallbacks) ~= "table" or type(meta) ~= "table"
		or type(journalInstance) ~= "table"
	then
		return nil
	end

	for configuredActivityID, fallback in pairs(fallbacks) do
		local activityID = tonumber(configuredActivityID)
		local expectedMapID = tonumber(fallback and fallback.mapID)
		local journalUsesMap = expectedMapID and expectedMapID > 0
			and (tonumber(journalInstance.mapID) == expectedMapID
				or tonumber(journalInstance.instanceMapID) == expectedMapID)
		if activityID and journalUsesMap then
			local info = getActivityInfo(activityID)
			local infoName = normalizedName(activityBaseName(info))
			local journalName = normalizedName(journalInstance.label)
			local exactIdentity = type(info) == "table"
				and tonumber(info.categoryID) == tonumber(meta.categoryID)
				and activityGroupID(info) == nil
				and tonumber(info.mapID) == expectedMapID
				and infoName ~= nil
				and journalName ~= nil
				and infoName == journalName
			if exactIdentity then
				local filterSets, filterSeen = {}, {}
				addUnique(filterSets, filterSeen, tonumber(info.filters))
				addUnique(filterSets, filterSeen, tonumber(meta.baseFilters))
				addUnique(filterSets, filterSeen, tonumber(meta.preferredFilters))
				addUnique(filterSets, filterSeen, 0)
				local searchTexts, searchSeen = {}, {}
				local function addSearchText(value)
					value = cleanText(value)
					local key = normalizedName(value)
					if value and key and not searchSeen[key] then
						searchSeen[key] = true
						searchTexts[#searchTexts + 1] = value
					end
				end
				addSearchText(journalInstance.label)
				addSearchText(activityBaseName(info))
				addSearchText(info.fullName)
				addSearchText(info.shortName)

				local liveAvailable = false
				for _, filterFlags in ipairs(filterSets) do
					liveAvailable = activityListContainsID(
						getAvailableActivities(meta.categoryID, 0, filterFlags), activityID)
						or activityListContainsID(
							getAvailableActivities(meta.categoryID, nil, filterFlags), activityID)
						or activityListContainsID(
							getAvailableActivities(meta.categoryID, nil, filterFlags, ""), activityID)
					if not liveAvailable then
						for _, searchText in ipairs(searchTexts) do
							if activityListContainsID(getAvailableActivities(
								meta.categoryID,
								nil,
								filterFlags,
								searchText
							), activityID) then
								liveAvailable = true
								break
							end
						end
					end
					if liveAvailable then
						local listFilters = deriveListFilters(
							meta.categoryID, filterFlags, { activityID })
						return {
							activityID = activityID,
							listFilters = listFilters,
							orderIndex = tonumber(info.orderIndex) or activityID,
							activityIDs = { activityID },
							filterFlags = filterFlags,
							info = info,
							mapID = tonumber(info.mapID),
							journalInstanceID = journalInstance.journalInstanceID,
							nameKeys = makeEntryNameKeys(nil, info),
						}, activityID
					end
				end
			end
		end
	end
	return nil
end

local function addStaticCatalogRecords(
	lookup,
	source,
	sourceName,
	targetExpansionIndex
)
	local added = false
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		local expansionIndex = tonumber(expansion.expansionIndex)
		if expansionIndex ~= nil
			and (targetExpansionIndex == nil
				or expansionIndex == tonumber(targetExpansionIndex))
		then
			for orderIndex, instance in ipairs(expansion.instances or EMPTY) do
				if type(instance) == "table" then
					local record = {
						expansionIndex = tonumber(instance.expansionIndex) or expansionIndex,
						orderIndex = tonumber(instance.orderIndex) or orderIndex,
						label = cleanText(instance.label),
						listFilters = tonumber(instance.listFilters),
						mapID = tonumber(instance.mapID),
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
					if record.mapID and record.mapID > 0 then
						lookup.byMapID[record.mapID] = record
						added = true
					end
				end
			end
		end
	end
	return added
end

local function catalogLookupCacheKey(kind, expansionIndex)
	if expansionIndex == nil then
		return tostring(kind)
	end
	return tostring(kind) .. ":" .. tostring(expansionIndex)
end

local function manualCatalogLookup(kind, expansionIndex)
	local cacheKey = catalogLookupCacheKey(kind, expansionIndex)
	local cached = manualCatalogLookupCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local source = GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind]
	if not source or type(source.expansions) ~= "table" then
		manualCatalogLookupCache[cacheKey] = false
		return nil
	end

	local lookup = {
		byActivityID = {},
		byGroupID = {},
		byMapID = {},
	}
	if not addStaticCatalogRecords(
		lookup, source, "manual", expansionIndex)
	then
		manualCatalogLookupCache[cacheKey] = false
		return nil
	end
	manualCatalogLookupCache[cacheKey] = lookup
	return lookup
end

local function staticCatalogLookup(kind, expansionIndex)
	local cacheKey = catalogLookupCacheKey(kind, expansionIndex)
	local cached = staticCatalogLookupCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local source = GF.NAV_CATALOG and GF.NAV_CATALOG[kind]
	local supplementSource = GF.NAV_CATALOG_SUPPLEMENT and GF.NAV_CATALOG_SUPPLEMENT[kind]
	local manualSource = GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind]
	if (not source or type(source.expansions) ~= "table")
		and (not supplementSource or type(supplementSource.expansions) ~= "table")
		and (not manualSource or type(manualSource.expansions) ~= "table") then
		staticCatalogLookupCache[cacheKey] = false
		return nil
	end

	local lookup = {
		byActivityID = {},
		byGroupID = {},
		byMapID = {},
	}
	addStaticCatalogRecords(lookup, source, "static", expansionIndex)
	addStaticCatalogRecords(lookup, supplementSource, "supplement", expansionIndex)
	addStaticCatalogRecords(lookup, manualSource, "manual", expansionIndex)

	staticCatalogLookupCache[cacheKey] = lookup
	return lookup
end

local function applyCatalogRecordOverrides(out, record)
	if not out or not record then
		return out
	end
	if record.label then
		out.label = record.label
	end
	if out.listFilters == nil and record.listFilters ~= nil then
		out.listFilters = record.listFilters
	end
	if record.orderIndex then
		out.orderIndex = record.orderIndex
	end
	return out
end

local function journalEntryCanBeReused(kind, entry)
	local reusableGroups = GF.NAV_CATALOG_REUSABLE_JOURNAL_GROUPS
		and GF.NAV_CATALOG_REUSABLE_JOURNAL_GROUPS[kind]
	local groupID = tonumber(entry and entry.groupID)
	if type(reusableGroups) == "table"
		and groupID and reusableGroups[groupID] == true
	then
		return true
	end
	local reusable = GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES
		and GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES[kind]
	return type(reusable) == "table"
		and entry and entry.activityID
		and reusable[tonumber(entry.activityID)] == true
end

local function reusableJournalActivityID(kind, entry)
	local reusable = GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES
		and GF.NAV_CATALOG_REUSABLE_JOURNAL_ACTIVITIES[kind]
	local activityID = tonumber(entry and entry.activityID)
	if type(reusable) == "table" and activityID and reusable[activityID] == true then
		return activityID
	end
	return nil
end

local function takeEntryFromBucket(kind, bucket, used, predicate)
	for _, entry in ipairs(bucket or EMPTY) do
		if (not used[entry] or journalEntryCanBeReused(kind, entry))
			and (not predicate or predicate(entry)) then
			used[entry] = true
			return entry
		end
	end
	return nil
end

local function canMatchJournalInstance(kind, entry)
	-- World-boss activities have their own typed Journal-container path. Keep
	-- them out of ordinary raid matching, but allow other group-less legacy raid
	-- activities to match their real Journal instance.
	if kind == "raid" and entry and entry.worldBoss == true then
		return false
	end
	return true
end

local function takeEntryForJournalInstance(kind, lookup, journalInstance, used, extraPredicate)
	local function predicate(entry)
		return canMatchJournalInstance(kind, entry)
			and (not extraPredicate or extraPredicate(entry))
	end
	local entry = takeEntryFromBucket(
		kind,
		lookup.byJournalInstanceID[journalInstance.journalInstanceID],
		used,
		predicate
	)
	if entry then
		return entry
	end
	entry = takeEntryFromBucket(kind, lookup.byMapID[journalInstance.mapID], used, predicate)
	if entry then
		return entry
	end
	entry = takeEntryFromBucket(kind, lookup.byMapID[journalInstance.instanceMapID], used, predicate)
	if entry then
		return entry
	end
	entry = takeEntryFromBucket(
		kind,
		lookup.byName[normalizedName(journalInstance.label)],
		used,
		predicate
	)
	if entry then
		return entry
	end

	-- Generic legacy activities do not always share a usable map ID with each
	-- entrance-specific Journal row. Restrict localized prefix matching to the
	-- small manually maintained reuse allow-list.
	local journalNameKey = normalizedName(journalInstance.label)
	if journalNameKey then
		for _, reusableEntry in ipairs(lookup.reusableJournalEntries or EMPTY) do
			if predicate(reusableEntry) then
				for _, entryNameKey in ipairs(reusableEntry.nameKeys or EMPTY) do
					if entryNameKey ~= ""
						and journalNameKey:sub(1, #entryNameKey) == entryNameKey
					then
						used[reusableEntry] = true
						return reusableEntry
					end
				end
			end
		end
	end
	return nil
end

local function staticRecordForEntry(lookup, entry)
	if not lookup or not entry then
		return nil
	end
	local mapID = tonumber(entry.mapID or (entry.info and entry.info.mapID))
	if mapID and lookup.byMapID then
		local record = lookup.byMapID[mapID]
		if record then
			return record
		end
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

local function buildWorldBossJournalDescriptors(kind, entries, targetExpansionIndex)
	local byJournalInstanceID = {}
	if kind ~= "raid" then
		return byJournalInstanceID
	end

	local staticLookup = staticCatalogLookup(kind, targetExpansionIndex)
	local configured = GF.NAV_CATALOG_WORLD_BOSS_CONTAINERS
		and GF.NAV_CATALOG_WORLD_BOSS_CONTAINERS.raid or EMPTY
	local byActivityID = {}
	local byExpansion = {}
	for _, record in ipairs(configured) do
		local journalInstanceID = tonumber(record and record.journalInstanceID)
		local expansionIndex = tonumber(record and record.expansionIndex)
		if journalInstanceID and expansionIndex ~= nil
			and (targetExpansionIndex == nil
				or expansionIndex == tonumber(targetExpansionIndex))
		then
			local descriptor = {
				journalInstanceID = journalInstanceID,
				expansionIndex = expansionIndex,
				entries = {},
				entrySeen = {},
			}
			byJournalInstanceID[journalInstanceID] = descriptor
			byExpansion[expansionIndex] = descriptor
			for _, activityID in ipairs(record.activityIDs or EMPTY) do
				activityID = tonumber(activityID)
				if activityID then
					byActivityID[activityID] = descriptor
					local info = getActivityInfo(activityID)
					local label = worldBossLabelForInfo(info)
					if label and not descriptor.label then
						descriptor.label = label
						descriptor.info = info
					end
				end
			end
		end
	end

	for _, entry in ipairs(entries or EMPTY) do
		if entry.activityID and not entry.groupID and entry.worldBoss == true then
			local descriptor = byActivityID[tonumber(entry.activityID)]
			if not descriptor then
				local record = staticRecordForEntry(staticLookup, entry)
				local expansionIndex = entryExpansionIndexFromRuntimeName(kind, entry)
					or (record and record.expansionIndex)
				descriptor = byExpansion[tonumber(expansionIndex)]
			end
			if descriptor and not descriptor.entrySeen[entry] then
				descriptor.entrySeen[entry] = true
				descriptor.entries[#descriptor.entries + 1] = entry
				if not descriptor.label then
					descriptor.label = entry.worldBossLabel
					descriptor.info = entry.info or getActivityInfo(entry.activityID)
				end
			end
		end
	end

	for _, descriptor in pairs(byJournalInstanceID) do
		descriptor.entrySeen = nil
	end
	return byJournalInstanceID
end

local function worldBossDescriptorForJournal(byJournalInstanceID, journalInstance)
	local journalInstanceID = tonumber(journalInstance and journalInstance.journalInstanceID)
	return journalInstanceID and byJournalInstanceID and byJournalInstanceID[journalInstanceID] or nil
end

local function isWorldBossJournalContainer(kind, journalInstance)
	if kind ~= "raid" or type(journalInstance) ~= "table" then
		return false
	end
	local journalInstanceID = tonumber(journalInstance.journalInstanceID)
	local configured = GF.NAV_CATALOG_WORLD_BOSS_CONTAINERS
		and GF.NAV_CATALOG_WORLD_BOSS_CONTAINERS.raid or EMPTY
	for _, record in ipairs(configured) do
		if journalInstanceID
			and tonumber(record and record.journalInstanceID) == journalInstanceID
		then
			return true
		end
	end
	-- The stable Journal identity above is authoritative for known containers.
	-- Keep the localized label check only as a forward-compatible guard for a
	-- newly added container that has not yet reached NavManualData.
	return isWorldBossLabel(journalInstance.label)
end

local function isSeasonJournalContainer(kind, journalInstance)
	if isWorldBossJournalContainer(kind, journalInstance) then
		return true
	end
	local label = trimText(journalInstance and journalInstance.label)
	local configured = GF.NAV_SEASON_JOURNAL_CONTAINER_LABELS
		and GF.NAV_SEASON_JOURNAL_CONTAINER_LABELS[kind] or EMPTY
	for _, containerLabel in ipairs(configured) do
		if label and string.lower(label) == string.lower(containerLabel) then
			return true
		end
	end
	return false
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

local function appendManualMappedEntries(
	kind,
	catalog,
	entries,
	used,
	expansionIndex
)
	local lookup = manualCatalogLookup(kind, expansionIndex)
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
				local out = copyEntryForCatalog(entry, nil, kind)
				applyCatalogRecordOverrides(out, record)
				expansion.instances[#expansion.instances + 1] = out
			end
		end
	end
end

local function appendStaticMappedEntries(
	kind,
	catalog,
	entries,
	used,
	expansionIndex
)
	local lookup = staticCatalogLookup(kind, expansionIndex)
	if not lookup then
		return
	end
	local pairLookup = buildRuntimeSoloExpansionPairs(kind, entries)

	for _, entry in ipairs(entries or EMPTY) do
		if not used[entry] then
			local record = staticRecordForEntry(lookup, entry)
			local runtimeExpansionIndex = entryExpansionIndexFromRuntimeName(kind, entry)
				or pairedRuntimeExpansionIndex(pairLookup, entry, record)
			local resolvedExpansionIndex = runtimeExpansionIndex ~= nil
				and runtimeExpansionIndex or (record and record.expansionIndex)
			if resolvedExpansionIndex ~= nil
				and (expansionIndex == nil
					or tonumber(resolvedExpansionIndex) == tonumber(expansionIndex))
			then
				used[entry] = true
				local expansion = addExpansion(
					catalog,
					resolvedExpansionIndex,
					expansionLabel(resolvedExpansionIndex))
				local out = copyEntryForCatalog(entry, nil, kind)
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

local function buildRuntimeCatalog(kind, expansionIndex)
	local journal = expansionIndex == nil
		and journalCatalog(kind)
		or journalExpansionCatalog(kind, expansionIndex)
	local entries, lookup, meta = buildRuntimeEntries(
		kind,
		nil,
		{
			expansionIndex = expansionIndex,
			expansionBoundary = journalExpansionBoundary(
				journal, expansionIndex),
		})
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
	local worldBossDescriptors = buildWorldBossJournalDescriptors(
		kind, entries, expansionIndex)
	appendManualMappedEntries(kind, catalog, entries, used, expansionIndex)
	if journal then
		for _, journalExpansion in ipairs(journal.expansions or EMPTY) do
			if expansionIndex == nil
				or tonumber(journalExpansion.expansionIndex) == tonumber(expansionIndex)
			then
			local expansion = addExpansion(
				catalog,
				journalExpansion.expansionIndex,
				journalExpansion.label
			)
			local collapsedJournalActivities = {}
			for _, journalInstance in ipairs(journalExpansion.instances or EMPTY) do
				local worldBoss = worldBossDescriptorForJournal(worldBossDescriptors, journalInstance)
				if worldBoss then
					local worldBossLabel = worldBossContainerLabel(
						worldBoss.info,
						worldBoss.label,
						journalInstance.label
					)
					local found = false
					for _, entry in ipairs(worldBoss.entries or EMPTY) do
						if not used[entry] then
							used[entry] = true
							found = true
							expansion.instances[#expansion.instances + 1] = copyWorldBossEntryForCatalog(
								entry,
								journalInstance,
								worldBossLabel
							)
						end
					end
					if not found then
						expansion.instances[#expansion.instances + 1] = copyUnavailableJournalInstance(
							journalInstance,
							worldBossLabel,
							true
						)
					end
				else
					local entry = takeEntryForJournalInstance(kind, lookup, journalInstance, used)
					if not entry then
						entry = strictLegacySoloEntryForJournalBoundary(kind, meta, journalInstance)
					end
					if entry then
						local collapsedActivityID = reusableJournalActivityID(kind, entry)
						if not collapsedActivityID or not collapsedJournalActivities[collapsedActivityID] then
							if collapsedActivityID then
								collapsedJournalActivities[collapsedActivityID] = true
							end
							expansion.instances[#expansion.instances + 1] = copyEntryForCatalog(
								entry,
								journalInstance,
								kind
							)
						end
					else
						expansion.instances[#expansion.instances + 1] = copyUnavailableJournalInstance(journalInstance)
					end
				end
			end
			end
		end
	end
	appendStaticMappedEntries(kind, catalog, entries, used, expansionIndex)
	return finalizeCatalog(catalog, kind)
end

-- Archive expansion rows use structural shells. Building these descriptors is
-- intentionally free of GetAvailableActivities, EJ_SelectTier, and addon loads;
-- the live authorization cost is paid only for the one instance the user opens.
local function worldBossShellDescriptor(expansionIndex, activityID)
	for _, record in ipairs(
		GF.NAV_CATALOG_WORLD_BOSS_CONTAINERS
			and GF.NAV_CATALOG_WORLD_BOSS_CONTAINERS.raid or EMPTY
	) do
		if tonumber(record and record.expansionIndex) == tonumber(expansionIndex) then
			for _, configuredID in ipairs(record.activityIDs or EMPTY) do
				if tonumber(configuredID) == tonumber(activityID) then
					return record
				end
			end
		end
	end
	return nil
end

local function addShellFilter(candidate, filterFlags)
	filterFlags = tonumber(filterFlags)
	if filterFlags == nil then
		return
	end
	candidate.filterSets = candidate.filterSets or {}
	candidate._filterSeen = candidate._filterSeen or {}
	if not candidate._filterSeen[filterFlags] then
		candidate._filterSeen[filterFlags] = true
		candidate.filterSets[#candidate.filterSets + 1] = filterFlags
	end
	if candidate.listFilters == nil then
		candidate.listFilters = filterFlags
	end
end

local function verifiedSnapshotActivityIDs(record)
	local activityIDs, seen = {}, {}
	for _, value in ipairs(record and record.activityIDs or EMPTY) do
		local activityID = tonumber(value)
		if activityID and activityID > 0 and not seen[activityID] then
			seen[activityID] = true
			activityIDs[#activityIDs + 1] = activityID
		end
	end
	return activityIDs
end

local function verifiedSnapshotLabel(record)
	local locale
	if type(GetLocale) == "function" then
		local ok, value = pcall(GetLocale)
		locale = ok and value or nil
	end
	-- The verified workbook is zhCN. Tests and stripped diagnostic runtimes do
	-- not always expose GetLocale, so treat a missing reader as the source locale.
	if locale == nil or locale == "zhCN" then
		return cleanText(record and record.labelZhCN)
	end
	return nil
end

local function verifiedSnapshotWorldBoss(expansionIndex, activityIDs)
	for _, activityID in ipairs(activityIDs or EMPTY) do
		local descriptor = worldBossShellDescriptor(expansionIndex, activityID)
		if descriptor then
			return descriptor
		end
	end
	return nil
end

local function addInstanceShellRecord(
	shells,
	byIdentity,
	kind,
	expansionIndex,
	record,
	sourceOrder
)
	if type(record) ~= "table" then
		return
	end
	local fallbackActivityIDs = verifiedSnapshotActivityIDs(record)
	local fallbackSnapshot = #fallbackActivityIDs > 0
	local groupID = tonumber(record.groupID)
	local activityID = tonumber(record.activityID)
	if not fallbackSnapshot and not groupID and not activityID then
		return
	end
	local labelActivityID = tonumber(record.labelActivityID)
		or fallbackActivityIDs[1]
	local fallbackMinLevels, fallbackMinLevelBuild
	if fallbackSnapshot then
		local build = currentClientBuild()
		local provider = GF.NavCatalogMinLevelData
		local source = provider and provider.GetLevelsForBuild
			and provider.GetLevelsForBuild(build) or nil
		if type(source) == "table" then
			local complete = true
			fallbackMinLevels = {}
			for _, fallbackActivityID in ipairs(fallbackActivityIDs) do
				local minLevel = tonumber(source[fallbackActivityID])
				if minLevel == nil then
					complete = false
					break
				end
				fallbackMinLevels[fallbackActivityID] = minLevel
			end
			if complete then
				fallbackMinLevelBuild = build
			else
				fallbackMinLevels = nil
			end
		end
	end
	local worldBoss = kind == "raid" and not groupID
		and (fallbackSnapshot
			and verifiedSnapshotWorldBoss(expansionIndex, fallbackActivityIDs)
			or worldBossShellDescriptor(expansionIndex, activityID)) or nil
	local identity = fallbackSnapshot and table.concat({
		"f", tostring(kind), tostring(expansionIndex), tostring(labelActivityID),
	}, ":")
		or worldBoss and ("j:" .. tostring(worldBoss.journalInstanceID))
		or groupID and ("g:" .. tostring(groupID))
		or ("a:" .. tostring(activityID))
	local shell = byIdentity[identity]
	if not shell then
		shell = {
			identity = identity,
			expansionIndex = tonumber(expansionIndex),
			groupID = not fallbackSnapshot and groupID or nil,
			activityID = not fallbackSnapshot and not groupID and activityID or nil,
			seedActivityID = not fallbackSnapshot and groupID and activityID or nil,
			fallbackSnapshot = fallbackSnapshot or nil,
			fallbackActivityIDs = fallbackSnapshot and fallbackActivityIDs or nil,
			fallbackMinLevels = fallbackMinLevels,
			fallbackMinLevelBuild = fallbackMinLevelBuild,
			labelActivityID = fallbackSnapshot and labelActivityID or nil,
			labelZhCN = fallbackSnapshot and cleanText(record.labelZhCN) or nil,
			listFilters = tonumber(record.listFilters),
			orderIndex = tonumber(record.orderIndex) or sourceOrder,
			mapID = tonumber(record.mapID),
			journalInstanceID = tonumber(record.journalInstanceID)
				or tonumber(worldBoss and worldBoss.journalInstanceID),
			label = fallbackSnapshot and verifiedSnapshotLabel(record)
				or cleanText(record.label),
			worldBossContainer = worldBoss ~= nil,
			groupCandidates = {},
			soloCandidates = {},
		}
		byIdentity[identity] = shell
		shells[#shells + 1] = shell
	end
	if fallbackSnapshot then
		-- The workbook supplies exact activity identities, but not current-player
		-- authority. Candidate groups are derived only when this one shell is
		-- explicitly authorized; expansion painting remains a pure local read.
	elseif groupID then
		local candidate = shell.groupCandidates[1]
		if not candidate then
			candidate = { groupID = groupID, filterSets = {}, _filterSeen = {} }
			shell.groupCandidates[1] = candidate
		end
		addShellFilter(candidate, record.listFilters)
	elseif activityID then
		local candidate
		for _, existing in ipairs(shell.soloCandidates) do
			if tonumber(existing.activityID) == activityID then
				candidate = existing
				break
			end
		end
		if not candidate then
			candidate = {
				activityID = activityID,
				filterSets = {},
				_filterSeen = {},
			}
			shell.soloCandidates[#shell.soloCandidates + 1] = candidate
		end
		addShellFilter(candidate, record.listFilters)
	end
	if shell.label == nil then
		shell.label = cleanText(record.label)
	end
	if shell.mapID == nil then
		shell.mapID = tonumber(record.mapID)
	end
	if shell.orderIndex == nil and record.orderIndex ~= nil then
		shell.orderIndex = tonumber(record.orderIndex)
	end
end

local function collectInstanceShellSource(
	shells,
	byIdentity,
	kind,
	expansionIndex,
	source
)
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		if tonumber(expansion and expansion.expansionIndex) == tonumber(expansionIndex) then
			for sourceOrder, record in ipairs(expansion.instances or EMPTY) do
				addInstanceShellRecord(
					shells, byIdentity, kind, expansionIndex, record, sourceOrder)
			end
		end
	end
end

local function hydrateInstanceShell(shell)
	local retainedLabel
	if not shell._metadataPending then
		retainedLabel = cleanText(shell.label)
	end
	local info
	if shell.fallbackSnapshot then
		shell.label = retainedLabel
		-- On the source locale the packaged label keeps expansion painting at
		-- zero C_LFGList calls. Other locales resolve one stable anchor activity
		-- for display only; its ID still grants no availability authority.
		if shell.label == nil and shell.labelActivityID then
			info = getActivityInfo(shell.labelActivityID)
		end
	elseif shell.groupID then
		local groupName, groupOrder = getActivityGroupInfo(shell.groupID)
		shell.label = retainedLabel or cleanText(groupName)
		shell.orderIndex = tonumber(shell.orderIndex) or tonumber(groupOrder)
		if shell.seedActivityID then
			info = getActivityInfo(shell.seedActivityID)
		end
	elseif shell.activityID then
		shell.label = retainedLabel
		info = getActivityInfo(shell.activityID)
	end
	if info then
		shell.label = shell.label or cleanText(activityBaseName(info))
		shell.mapID = tonumber(shell.mapID) or tonumber(info.mapID)
		shell.orderIndex = tonumber(shell.orderIndex)
			or tonumber(info.orderIndex)
	end
	-- Do not resolve Journal identity while painting an expansion directory.
	-- mapID is already enough to authorize the one clicked shell; the packaged
	-- or SavedVariables structural layer supplies journalInstanceID when known.
	if shell.label == nil then
		shell.label = shell.groupID and ("Group " .. tostring(shell.groupID))
			or ("Activity " .. tostring(
				shell.activityID or shell.labelActivityID or "?"))
		shell._metadataPending = true
	else
		shell._metadataPending = nil
	end
	shell.orderIndex = tonumber(shell.orderIndex)
		or tonumber(shell.groupID) or tonumber(shell.activityID) or math.huge
	for _, candidate in ipairs(shell.groupCandidates or EMPTY) do
		candidate._filterSeen = nil
	end
	for _, candidate in ipairs(shell.soloCandidates or EMPTY) do
		candidate._filterSeen = nil
	end
	return shell
end

local function verifiedSnapshotCandidateLookup(kind)
	local cached = verifiedSnapshotCandidateLookupCache[kind]
	if cached then
		return cached
	end
	local candidates = {}
	local source = GF.NAV_CATALOG_ACTIVITY_FALLBACK
		and GF.NAV_CATALOG_ACTIVITY_FALLBACK[kind]
	local function collectSource(candidateSource)
		for _, expansion in ipairs((candidateSource and candidateSource.expansions) or EMPTY) do
			for _, record in ipairs(expansion.instances or EMPTY) do
				for _, activityID in ipairs(record.activityIDs or EMPTY) do
					activityID = tonumber(activityID)
					if activityID then
						candidates[activityID] = true
					end
				end
			end
		end
	end
	collectSource(source)
	collectSource(GF.NAV_CATALOG_ACTIVITY_ADDITIONS
		and GF.NAV_CATALOG_ACTIVITY_ADDITIONS[kind])
	verifiedSnapshotCandidateLookupCache[kind] = candidates
	return candidates
end

local function verifiedSnapshotAvailableActivityIDs(kind)
	local cached = verifiedSnapshotAvailabilityCache[kind]
	if cached ~= nil then
		return cached, "authorized"
	end
	if activityListReadiness() ~= true then
		return nil, "indeterminate"
	end
	local meta = catalogMeta(kind)
	local categoryID = tonumber(meta and meta.categoryID)
	if not categoryID then
		return nil, "indeterminate"
	end

	-- Match Blizzard EntryCreation and MeetingStone's menu boundary once per
	-- category/availability generation: discover the current character's groups,
	-- then enumerate each currently available group. This single whitelist is
	-- reused both to hide empty expansions and to publish their instance rows.
	local readFailureStart = availabilityReadFailureSerial
	local availableGroups = getAvailableActivityGroups(categoryID, 0)
	if availabilityReadFailureSerial ~= readFailureStart then
		return nil, "indeterminate"
	end
	local candidates = verifiedSnapshotCandidateLookup(kind)
	local availableActivityIDs = {}
	local function collectMatching(list, expectedGroupID)
		for _, activityID in ipairs(list or EMPTY) do
			activityID = tonumber(activityID)
			if activityID and candidates[activityID] then
				local info = getActivityInfo(activityID)
				if type(info) ~= "table"
					or tonumber(info.categoryID) ~= categoryID
				then
					-- A native-visible workbook ID without readable metadata is a
					-- warm-up state, not authority for a partial directory.
					return false
				end
				local actualGroupID = activityGroupID(info)
				if expectedGroupID == nil then
					-- Category-level calls can also echo grouped activities. Only
					-- consume truly group-less candidates from this path.
					if actualGroupID == nil then
						availableActivityIDs[activityID] = true
					end
				elseif actualGroupID == expectedGroupID then
					availableActivityIDs[activityID] = true
				end
			end
		end
		return true
	end
	-- MeetingStone uses the omitted group argument; Blizzard EntryCreation uses
	-- group 0 for standalone activities. Consume both native forms.
	if not collectMatching(getAvailableActivities(categoryID, nil, 0), nil)
		or not collectMatching(getAvailableActivities(categoryID, 0, 0), nil)
	then
		return nil, "indeterminate"
	end
	for _, value in ipairs(availableGroups) do
		local groupID = tonumber(value)
		if groupID and groupID > 0 then
			if not collectMatching(
				getAvailableActivities(categoryID, groupID, 0), groupID)
			then
				return nil, "indeterminate"
			end
		end
	end
	if availabilityReadFailureSerial ~= readFailureStart then
		return nil, "indeterminate"
	end
	verifiedSnapshotAvailabilityCache[kind] = availableActivityIDs
	return availableActivityIDs, "authorized"
end

local function filterVerifiedSnapshotShellsByAvailability(kind, shells)
	local availableActivityIDs, state =
		verifiedSnapshotAvailableActivityIDs(kind)
	if not availableActivityIDs then
		return nil, state
	end

	local filtered = {}
	for _, shell in ipairs(shells or EMPTY) do
		local intersection = {}
		for _, activityID in ipairs(shell.fallbackActivityIDs or EMPTY) do
			activityID = tonumber(activityID)
			if activityID and availableActivityIDs[activityID] then
				intersection[#intersection + 1] = activityID
			end
		end
		if #intersection > 0 then
			shell.availableActivityIDs = intersection
			filtered[#filtered + 1] = shell
		end
	end
	return filtered, "authorized"
end

local function buildInstanceShells(kind, expansionIndex)
	local shells, byIdentity = {}, {}
	local verifiedSource = GF.NAV_CATALOG_ACTIVITY_FALLBACK
		and GF.NAV_CATALOG_ACTIVITY_FALLBACK[kind]
	local usesVerifiedSnapshot = type(verifiedSource) == "table"
	if usesVerifiedSnapshot then
		-- Extend the verified workbook only with separately verified, version-
		-- gated activity increments. Older structural sources would reintroduce
		-- removed parents and split multi-group instances again.
		collectInstanceShellSource(
			shells, byIdentity, kind, expansionIndex, verifiedSource)
		collectInstanceShellSource(
			shells, byIdentity, kind, expansionIndex,
			GF.NAV_CATALOG_ACTIVITY_ADDITIONS and GF.NAV_CATALOG_ACTIVITY_ADDITIONS[kind])
	else
		collectInstanceShellSource(
			shells, byIdentity, kind, expansionIndex,
			GF.NAV_CATALOG and GF.NAV_CATALOG[kind])
		collectInstanceShellSource(
			shells, byIdentity, kind, expansionIndex,
			GF.NAV_CATALOG_SUPPLEMENT and GF.NAV_CATALOG_SUPPLEMENT[kind])
		collectInstanceShellSource(
			shells, byIdentity, kind, expansionIndex,
			GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind])
	end
	if usesVerifiedSnapshot then
		local filtered, state = filterVerifiedSnapshotShellsByAvailability(
			kind, shells)
		if not filtered then
			return nil, state, true
		end
		shells = filtered
	end
	-- On the verified path, filter before localization/overlay enrichment so the
	-- root can hide empty expansions without hydrating every unavailable row.
	for _, shell in ipairs(shells) do
		hydrateInstanceShell(shell)
	end
	local overlay = GF.NavCatalogOverlay
	if overlay and type(overlay.MergeDescriptors) == "function" then
		shells = overlay:MergeDescriptors(
			kind,
			expansionIndex,
			shells,
			nil,
			usesVerifiedSnapshot and { allowAdditions = false } or nil
		)
	end
	table.sort(shells, function(left, right)
		local leftOrder = tonumber(left and left.orderIndex) or math.huge
		local rightOrder = tonumber(right and right.orderIndex) or math.huge
		if leftOrder ~= rightOrder then
			return leftOrder < rightOrder
		end
		return tostring(left and left.label or "")
			< tostring(right and right.label or "")
	end)
	return shells, "authorized", usesVerifiedSnapshot
end

local function getInstanceShells(kind, expansionIndex)
	expansionIndex = tonumber(expansionIndex)
	if expansionIndex == nil then
		return EMPTY, "invalid"
	end
	local cacheKey = table.concat({
		"shells", tostring(kind), tostring(expansionIndex),
	}, ":")
	local cached = instanceShellCache[cacheKey]
	if cached ~= nil then
		if cached ~= false then
			local resort = false
			for _, shell in ipairs(cached) do
				if shell._metadataPending then
					hydrateInstanceShell(shell)
					resort = true
				end
			end
			if resort then
				table.sort(cached, function(left, right)
					local leftOrder = tonumber(left and left.orderIndex) or math.huge
					local rightOrder = tonumber(right and right.orderIndex) or math.huge
					if leftOrder ~= rightOrder then
						return leftOrder < rightOrder
					end
					return tostring(left and left.label or "")
						< tostring(right and right.label or "")
				end)
			end
			return cached, "cached"
		end
		return EMPTY, "cached"
	end
	local shells, state, availabilityScoped = buildInstanceShells(
		kind, expansionIndex)
	if state == "indeterminate" or shells == nil then
		-- Directory warm-up and protected-read failures are retryable. Publishing
		-- no parents is safer than exposing non-creatable entries, but do not cache
		-- that temporary absence as an authoritative empty expansion.
		return EMPTY, "indeterminate"
	end
	instanceShellCache[cacheKey] = shells
	if availabilityScoped then
		availabilityScopedInstanceShellKeys[cacheKey] = true
	end
	return shells, state
end

local function instanceBoundary(shell)
	local boundary = {
		journalInstanceIDs = {},
		mapIDs = {},
		nameKeys = {},
	}
	local journalInstanceID = tonumber(shell and shell.journalInstanceID)
	if journalInstanceID then
		boundary.journalInstanceIDs[journalInstanceID] = true
	end
	local function addBoundaryMap(mapID)
		mapID = tonumber(mapID)
		if mapID then
			boundary.mapIDs[mapID] = true
		end
	end
	addBoundaryMap(shell and shell.mapID)
	addBoundaryMap(shell and shell.instanceMapID)
	local nameKey = normalizedName(shell and shell.label)
	if nameKey then
		boundary.nameKeys[nameKey] = true
	end
	return boundary
end

local function collectArchiveGroupOwnershipSource(ownership, source)
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		local expansionIndex = tonumber(expansion and expansion.expansionIndex)
		if expansionIndex ~= nil then
			for _, record in ipairs(expansion.instances or EMPTY) do
				if tonumber(record and record.groupID) == ownership.groupID then
					if not ownership.expansions[expansionIndex] then
						ownership.expansions[expansionIndex] = true
						ownership.expansionCount = ownership.expansionCount + 1
						if ownership.fallbackExpansion == nil
							or expansionIndex > ownership.fallbackExpansion
						then
							ownership.fallbackExpansion = expansionIndex
						end
					end
					local records = ownership.recordsByExpansion[expansionIndex]
					if not records then
						records = {}
						ownership.recordsByExpansion[expansionIndex] = records
					end
					records[#records + 1] = record
				end
			end
		end
	end
end

local function archiveGroupOwnership(kind, groupID)
	groupID = tonumber(groupID)
	if not groupID then
		return nil
	end
	local cacheKey = tostring(kind) .. ":" .. tostring(groupID)
	local cached = archiveGroupOwnershipCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local ownership = {
		groupID = groupID,
		expansions = {},
		recordsByExpansion = {},
		expansionCount = 0,
	}
	collectArchiveGroupOwnershipSource(
		ownership, GF.NAV_CATALOG and GF.NAV_CATALOG[kind])
	collectArchiveGroupOwnershipSource(
		ownership, GF.NAV_CATALOG_SUPPLEMENT and GF.NAV_CATALOG_SUPPLEMENT[kind])
	collectArchiveGroupOwnershipSource(
		ownership, GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind])
	if ownership.expansionCount <= 1 then
		archiveGroupOwnershipCache[cacheKey] = false
		return nil
	end
	archiveGroupOwnershipCache[cacheKey] = ownership
	return ownership
end

local function addStableEntryIdentity(identities, mapID, journalInstanceID)
	mapID = tonumber(mapID)
	if mapID and mapID > 0 then
		identities.mapIDs[mapID] = true
		journalInstanceID = tonumber(journalInstanceID)
			or journalInstanceIDForMapID(mapID)
	end
	journalInstanceID = tonumber(journalInstanceID)
	if journalInstanceID and journalInstanceID > 0 then
		identities.journalInstanceIDs[journalInstanceID] = true
	end
end

local function stableEntryIdentities(entry)
	local identities = {
		journalInstanceIDs = {},
		mapIDs = {},
	}
	addStableEntryIdentity(
		identities, entry and entry.mapID, entry and entry.journalInstanceID)
	local seenActivityIDs = {}
	local function addActivity(activityID)
		activityID = tonumber(activityID)
		if not activityID or seenActivityIDs[activityID] then
			return
		end
		seenActivityIDs[activityID] = true
		local info = getActivityInfo(activityID)
		addStableEntryIdentity(identities, info and info.mapID)
	end
	addActivity(entry and entry.activityID)
	for _, activityID in ipairs(entry and entry.activityIDs or EMPTY) do
		addActivity(activityID)
	end
	return identities
end

local function boundaryHasStableIdentity(boundary)
	return boundary and (next(boundary.journalInstanceIDs) ~= nil
		or next(boundary.mapIDs) ~= nil)
end

local function entryMatchesStableBoundary(identities, boundary)
	for journalInstanceID in pairs(identities.journalInstanceIDs) do
		if boundary.journalInstanceIDs[journalInstanceID] then
			return true
		end
	end
	for mapID in pairs(identities.mapIDs) do
		if boundary.mapIDs[mapID] then
			return true
		end
	end
	return false
end

local function recordMatchesStableEntry(record, identities)
	local journalInstanceID = tonumber(record and record.journalInstanceID)
	if journalInstanceID
		and identities.journalInstanceIDs[journalInstanceID]
	then
		return true
	end
	local function matchesMap(mapID)
		mapID = tonumber(mapID)
		if mapID and identities.mapIDs[mapID] then
			return true
		end
		return false
	end
	return matchesMap(record and record.mapID)
		or matchesMap(record and record.instanceMapID)
end

local function addUniqueExpansionOwner(state, expansionIndex)
	expansionIndex = tonumber(expansionIndex)
	if expansionIndex == nil or not state.allowed[expansionIndex] then
		return
	end
	if state.owner ~= nil and state.owner ~= expansionIndex then
		state.conflict = true
	else
		state.owner = expansionIndex
	end
end

local function overlayExpansionOwner(kind, ownership, identities)
	local overlay = GF.NavCatalogOverlay
	if not (overlay and type(overlay.FindExpansionForIdentity) == "function") then
		return nil, false
	end
	local state = { allowed = ownership.expansions }
	for journalInstanceID in pairs(identities.journalInstanceIDs) do
		addUniqueExpansionOwner(state, overlay:FindExpansionForIdentity(
			kind, journalInstanceID, nil, nil))
	end
	for mapID in pairs(identities.mapIDs) do
		addUniqueExpansionOwner(state, overlay:FindExpansionForIdentity(
			kind, nil, mapID, nil))
	end
	return state.owner, state.conflict == true
end

local function packagedExpansionOwner(ownership, identities)
	local state = { allowed = ownership.expansions }
	for expansionIndex, records in pairs(ownership.recordsByExpansion) do
		for _, record in ipairs(records) do
			if recordMatchesStableEntry(record, identities) then
				addUniqueExpansionOwner(state, expansionIndex)
				break
			end
		end
	end
	return state.owner, state.conflict == true
end

local function duplicateArchiveGroupMatches(kind, entry, shell, boundary)
	if journalEntryCanBeReused(kind, entry) then
		return true
	end
	local ownership = archiveGroupOwnership(kind, entry and entry.groupID)
	if not ownership then
		return true
	end
	local identities = stableEntryIdentities(entry)
	local owner, conflict = overlayExpansionOwner(kind, ownership, identities)
	if conflict then
		owner = nil
	elseif owner == nil then
		owner, conflict = packagedExpansionOwner(ownership, identities)
		if conflict then
			owner = nil
		end
	end
	-- When current structural evidence cannot identify the historical owner,
	-- prefer one deterministic packaged location. This is a cold-start
	-- compatibility policy, not a claim that the highest expansion index is the
	-- canonical Blizzard-era owner; a later exact overlay boundary overrides it.
	owner = owner or ownership.fallbackExpansion
	if tonumber(shell and shell.expansionIndex) ~= tonumber(owner) then
		return false
	end
	if boundaryHasStableIdentity(boundary) then
		return entryMatchesStableBoundary(identities, boundary)
	end
	return true
end

local function activityIDInEntry(entry, activityID)
	activityID = tonumber(activityID)
	if not activityID then
		return false
	end
	if tonumber(entry and entry.activityID) == activityID then
		return true
	end
	for _, entryActivityID in ipairs(entry and entry.activityIDs or EMPTY) do
		if tonumber(entryActivityID) == activityID then
			return true
		end
	end
	return false
end

local function verifiedSnapshotCandidates(kind, shell)
	local meta = catalogMeta(kind)
	local groups, groupsByID = {}, {}
	local solos, solosByID = {}, {}
	local metadataComplete = true
	for _, activityID in ipairs(shell and shell.fallbackActivityIDs or EMPTY) do
		activityID = tonumber(activityID)
		local info = activityID and getActivityInfo(activityID) or nil
		if type(info) ~= "table" then
			metadataComplete = false
		end
		if type(info) == "table"
			and tonumber(info.categoryID) == tonumber(meta and meta.categoryID)
		then
			local groupID = activityGroupID(info)
			if groupID then
				local candidate = ensureCatalogGroupCandidate(
					groups, groupsByID, groupID)
				addShellFilter(candidate, info.filters)
			else
				local candidate = solosByID[activityID]
				if not candidate then
					candidate = {
						activityID = activityID,
						filterSets = {},
						_filterSeen = {},
					}
					solosByID[activityID] = candidate
					solos[#solos + 1] = candidate
				end
				addShellFilter(candidate, info.filters)
			end
		end
	end
	for _, candidate in ipairs(groups) do
		candidate._filterSeen = nil
	end
	for _, candidate in ipairs(solos) do
		candidate._filterSeen = nil
	end
	return groups, solos, metadataComplete
end

local function verifiedSnapshotInstance(
	kind,
	shell,
	entries,
	preauthorizedActivityIDs
)
	local expected, authorized = {}, {}
	for _, activityID in ipairs(shell.fallbackActivityIDs or EMPTY) do
		activityID = tonumber(activityID)
		if activityID then
			expected[activityID] = true
		end
	end
	local function authorize(activityID)
		activityID = tonumber(activityID)
		if activityID and expected[activityID] then
			authorized[activityID] = true
		end
	end
	if type(preauthorizedActivityIDs) == "table" then
		for _, activityID in ipairs(preauthorizedActivityIDs) do
			authorize(activityID)
		end
	else
		for _, entry in ipairs(entries or EMPTY) do
			authorize(entry and entry.activityID)
			for _, activityID in ipairs(entry and entry.activityIDs or EMPTY) do
				authorize(activityID)
			end
		end
	end

	local activityIDs = {}
	for _, activityID in ipairs(shell.fallbackActivityIDs or EMPTY) do
		activityID = tonumber(activityID)
		if activityID and authorized[activityID] then
			activityIDs[#activityIDs + 1] = activityID
		end
	end
	if #activityIDs == 0 then
		return nil
	end
	local firstInfo = getActivityInfo(activityIDs[1])
	local activityInfoByID = {}
	for _, activityID in ipairs(activityIDs) do
		local info = getActivityInfo(activityID)
		if type(info) ~= "table" then
			-- The authorization pass already required complete metadata. If the
			-- protected reader becomes transiently unavailable before publication,
			-- keep the structural shell neutral instead of publishing a partial
			-- parent which NavData could later mistake for definitive unavailability.
			return nil, "indeterminate"
		end
		activityInfoByID[activityID] = info
	end
	return {
		fallbackSnapshot = true,
		activityIDs = activityIDs,
		activityID = activityIDs[1],
		activityInfo = activityInfoByID[activityIDs[1]],
		activityInfoByID = activityInfoByID,
		listFilters = tonumber(shell.listFilters)
			or tonumber(firstInfo and firstInfo.filters),
		orderIndex = shell.orderIndex,
		journalInstanceID = shell.journalInstanceID,
		mapID = shell.mapID or tonumber(firstInfo and firstInfo.mapID),
		instanceMapID = shell.instanceMapID,
		label = shell.label,
		visualTexture = shell.visualTexture,
		visualTexCoords = shell.visualTexCoords,
		visualSource = shell.visualSource,
		worldBossContainer = shell.worldBossContainer == true and true or nil,
	}
end

local function resolveVerifiedSnapshotShell(kind, shell)
	if type(shell and shell.availableActivityIDs) == "table" then
		local instance, instanceState = verifiedSnapshotInstance(
			kind, shell, nil, shell.availableActivityIDs)
		if instance then
			return { instance }, "authorized"
		end
		-- A published shell always has a non-empty native intersection. If its
		-- metadata becomes unreadable before hover, retain a neutral retryable row
		-- rather than mutating a visible parent into a late grey state.
		return nil, instanceState or "indeterminate"
	end
	local readFailureStart = availabilityReadFailureSerial
	local groups, solos, metadataComplete =
		verifiedSnapshotCandidates(kind, shell)
	if not metadataComplete then
		return nil, "indeterminate"
	end
	local entries = buildRuntimeEntries(kind, {}, {
		expansionIndex = tonumber(shell.expansionIndex),
		groupCandidates = groups,
		soloCandidates = solos,
		allowStaticIdentityFallbacks = false,
	}) or EMPTY
	if availabilityReadFailureSerial ~= readFailureStart then
		return nil, "indeterminate"
	end
	local instance, instanceState = verifiedSnapshotInstance(kind, shell, entries)
	if instance then
		return { instance }, "authorized"
	end
	if instanceState == "indeterminate" then
		return nil, instanceState
	end
	local unavailable = copyUnavailableJournalInstance(
		shell, shell.label, shell.worldBossContainer)
	return { unavailable }, "unavailable"
end

local function entryMatchesShell(kind, entry, shell, boundary)
	if shell.groupID then
		if tonumber(entry and entry.groupID) == tonumber(shell.groupID) then
			return duplicateArchiveGroupMatches(kind, entry, shell, boundary)
		end
		-- A packaged group shell is an exact native group identity. A shared
		-- map/Journal container must not allow sibling groups (notably the three
		-- Karazhan parents) to leak into this branch.
		return false
	end
	for _, candidate in ipairs(shell.soloCandidates or EMPTY) do
		if activityIDInEntry(entry, candidate.activityID) then
			return true
		end
	end
	if shell.overlayOnly == true then
		-- Overlay-only Journal rows have no packaged group/activity candidate.
		-- Map and Journal IDs can legitimately cover several native groups, so
		-- require the current activity's localized instance name as well.
		return activityMatchesExpansionBoundary(entry and entry.info, {
			journalInstanceIDs = {},
			mapIDs = {},
			nameKeys = boundary.nameKeys,
		})
	end
	if tonumber(entry and entry.journalInstanceID)
		and boundary.journalInstanceIDs[tonumber(entry.journalInstanceID)]
	then
		return true
	end
	if tonumber(entry and entry.mapID)
		and boundary.mapIDs[tonumber(entry.mapID)]
	then
		return true
	end
	return activityMatchesExpansionBoundary(entry and entry.info, boundary)
end

local function resolveInstanceShell(kind, shell)
	if type(shell) ~= "table" then
		return EMPTY
	end
	if shell.fallbackSnapshot then
		return resolveVerifiedSnapshotShell(kind, shell)
	end
	local boundary = instanceBoundary(shell)
	local hasCandidates = #(shell.groupCandidates or EMPTY) > 0
		or #(shell.soloCandidates or EMPTY) > 0
	local entries = buildRuntimeEntries(kind, hasCandidates and {} or buildFilterSets(kind), {
		expansionIndex = tonumber(shell.expansionIndex),
		expansionBoundary = boundary,
		groupCandidates = shell.groupCandidates or EMPTY,
		soloCandidates = shell.soloCandidates or EMPTY,
	}) or EMPTY
	local instances = {}
	for _, entry in ipairs(entries) do
		if entryMatchesShell(kind, entry, shell, boundary) then
			local instance
			if shell.worldBossContainer then
				instance = copyWorldBossEntryForCatalog(entry, shell, shell.label)
			else
				instance = copyEntryForCatalog(entry, shell, kind)
			end
			instances[#instances + 1] = instance
		end
	end
	if #instances == 0 then
		instances[1] = copyUnavailableJournalInstance(
			shell, shell.label, shell.worldBossContainer)
	end
	table.sort(instances, function(left, right)
		local leftOrder = tonumber(left and left.orderIndex)
			or tonumber(left and (left.groupID or left.activityID)) or 0
		local rightOrder = tonumber(right and right.orderIndex)
			or tonumber(right and (right.groupID or right.activityID)) or 0
		if leftOrder ~= rightOrder then
			return leftOrder < rightOrder
		end
		return (tonumber(left and (left.groupID or left.activityID)) or 0)
			< (tonumber(right and (right.groupID or right.activityID)) or 0)
	end)
	return instances
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

local function seasonJournalInstances(journal)
	return type(journal) == "table" and journal.seasonInstances or EMPTY
end

local function seasonActivityFilterSets()
	local filters, seen = {}, {}
	-- A seasonal activity can require the complete record mask rather than
	-- answering a broad subset query. Include both CurrentSeason and ordinary
	-- difficulty masks; neither filter family defines Journal membership.
	-- Retail 12.1 exposes Tidebound Grotto / The Venomous Abyss with filter 165:
	-- Recommended | PvE | CurrentExpansion | NotCurrentSeason. Keep the native
	-- Activity Finder family here, but consume its results only while matching
	-- the already selected current Journal instances below; these queries expand
	-- difficulties, never the seasonal instance roster.
	local scopes = {
		0,
		CURRENT_EXPANSION,
		CURRENT_SEASON,
		bor(CURRENT_EXPANSION, CURRENT_SEASON),
		NOT_CURRENT_SEASON,
		bor(CURRENT_EXPANSION, NOT_CURRENT_SEASON),
	}
	local recommendations = { 0, RECOMMENDED, NOT_RECOMMENDED }
	for _, scope in ipairs(scopes) do
		for _, recommendation in ipairs(recommendations) do
			addUnique(filters, seen, bor(PVE, scope, recommendation))
		end
	end
	addUnique(filters, seen, 0)
	addUnique(filters, seen, RECOMMENDED)
	addUnique(filters, seen, NOT_RECOMMENDED)
	return filters
end

local function seasonRaidProbeGroupIDs()
	local groups, seen = {}, {}
	local currentExpansion = clientDisplayExpansionIndex()
	local source = GF.NAV_CATALOG_SUPPLEMENT and GF.NAV_CATALOG_SUPPLEMENT.raid
	local hasExplicitSeasonRoster = false
	for _, expansion in ipairs(source and source.expansions or EMPTY) do
		if tonumber(expansion and expansion.expansionIndex) == currentExpansion then
			for _, instance in ipairs(expansion.instances or EMPTY) do
				hasExplicitSeasonRoster = hasExplicitSeasonRoster
					or instance.season == true
			end
		end
	end
	for _, expansion in ipairs(source and source.expansions or EMPTY) do
		if tonumber(expansion and expansion.expansionIndex) == currentExpansion then
			for _, instance in ipairs(expansion.instances or EMPTY) do
				local groupID = tonumber(instance and instance.groupID)
				if groupID and groupID > 0 and not seen[groupID]
					and (not hasExplicitSeasonRoster or instance.season == true)
				then
					seen[groupID] = true
					groups[#groups + 1] = groupID
				end
			end
		end
	end
	return groups
end

-- Challenge Mode remains useful identity metadata for portals and existing
-- consumers. It never adds/removes a Journal row or authorizes an activity.
local function attachSeasonDungeonIdentity(instance, journalInstance, dungeons)
	instance.label = journalInstance.label
	instance.journalOrderIndex = journalInstance.orderIndex
	for _, dungeon in ipairs(dungeons or EMPTY) do
		local journalID = tonumber(dungeon.journalInstanceID)
		local gameMapID = tonumber(dungeon.instanceMapID or dungeon.mapID)
		if (journalID and journalID == tonumber(journalInstance.journalInstanceID))
			or (gameMapID and (gameMapID == tonumber(journalInstance.instanceMapID)
				or gameMapID == tonumber(journalInstance.mapID))) then
			instance.challengeModeID = tonumber(dungeon.challengeModeID)
			break
		end
	end
end

local function buildSeasonInstances(kind)
	if kind ~= "dungeon" and kind ~= "raid" then
		return EMPTY, "ready"
	end
	-- Resolve structure first. Empty LFG publications and old cached rosters
	-- cannot define which instances belong to the current Adventure Guide.
	local journal = journalSeasonCatalog(kind)
	if not journal then
		return nil, "pending"
	end
	local filterSets = seasonActivityFilterSets()
	local _, lookup = buildRuntimeEntries(kind, filterSets, {
		exactFilters = true,
		probeGroupIDs = kind == "raid" and seasonRaidProbeGroupIDs() or nil,
	})
	local dungeons
	local season = kind == "dungeon" and GF.MythicPlusSeason
	if season and type(season.GetDungeons) == "function" then
		local ok, values = pcall(season.GetDungeons, season)
		dungeons = ok and type(values) == "table" and values or nil
	end
	local used, instances = {}, {}
	for _, journalInstance in ipairs(seasonJournalInstances(journal)) do
		if not isSeasonJournalContainer(kind, journalInstance) then
			local entry = takeEntryForJournalInstance(kind, lookup, journalInstance, used)
			local instance = entry and copyEntryForCatalog(entry, journalInstance, kind)
				or copyUnavailableJournalInstance(journalInstance)
			if kind == "dungeon" then
				attachSeasonDungeonIdentity(instance, journalInstance, dungeons)
			end
			instances[#instances + 1] = instance
		end
	end
	if #instances == 0 then
		journalSeasonCatalogCache[kind] = nil
		return nil, "pending"
	end
	sortSeasonInstances(kind, instances)
	return instances, "ready"
end

local function runtimeCatalog(kind, expansionIndex)
	if kind == nil then
		return nil
	end
	local cacheKey = expansionIndex == nil
		and tostring(kind)
		or (tostring(kind) .. ":" .. tostring(expansionIndex))
	local cached = runtimeCatalogCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	local catalog = buildRuntimeCatalog(kind, expansionIndex)
	runtimeCatalogCache[cacheKey] = catalog or false
	return catalog
end

local function addExpansionDescriptor(out, seen, expansionIndex, label)
	expansionIndex = tonumber(expansionIndex)
	if expansionIndex == nil or seen[expansionIndex] then
		return
	end
	seen[expansionIndex] = true
	out[#out + 1] = {
		expansionIndex = expansionIndex,
		label = cleanText(label) or expansionLabel(expansionIndex),
	}
end

local function collectExpansionDescriptors(out, seen, source)
	for _, expansion in ipairs((source and source.expansions) or EMPTY) do
		addExpansionDescriptor(
			out, seen, expansion.expansionIndex, expansion.label)
	end
end

local function expansionDescriptors(kind)
	local cacheKey = "expansions:" .. tostring(kind)
	local cached = runtimeCatalogCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or EMPTY
	end

	local descriptors, seen = {}, {}
	local verifiedSource = GF.NAV_CATALOG_ACTIVITY_FALLBACK
		and GF.NAV_CATALOG_ACTIVITY_FALLBACK[kind]
	-- Loading Blizzard_EncounterJournal is a large synchronous UI/addon load even
	-- when the subsequent tier API call count is tiny, so root construction never
	-- touches Journal. Legacy builds keep root expansion boundaries purely local.
	-- The verified-workbook path performs one category-wide native Activity Finder
	-- pass here so expansions with no current rows can be omitted; that same
	-- generation snapshot is reused by every visible expansion and instance.
	collectExpansionDescriptors(
		descriptors,
		seen,
		verifiedSource)
	if type(verifiedSource) == "table" then
		collectExpansionDescriptors(descriptors, seen,
			GF.NAV_CATALOG_ACTIVITY_ADDITIONS and GF.NAV_CATALOG_ACTIVITY_ADDITIONS[kind])
	end
	collectExpansionDescriptors(
		descriptors, seen, GF.NAV_CATALOG and GF.NAV_CATALOG[kind])
	collectExpansionDescriptors(
		descriptors,
		seen,
		GF.NAV_CATALOG_SUPPLEMENT and GF.NAV_CATALOG_SUPPLEMENT[kind])
	collectExpansionDescriptors(
		descriptors,
		seen,
		GF.NAV_MANUAL_CATALOG and GF.NAV_MANUAL_CATALOG[kind])
	if type(verifiedSource) == "table" then
		-- The exact-workbook path must not expose an expansion whose current
		-- native whitelist produces no instance rows. getInstanceShells() reuses
		-- the category-wide whitelist and caches every surviving expansion, so
		-- opening a visible expansion performs no second availability pass.
		local filtered = {}
		for _, descriptor in ipairs(descriptors) do
			local shells, state = getInstanceShells(
				kind, descriptor.expansionIndex)
			if state == "indeterminate" then
				-- The root itself is retryable; never cache a temporarily empty
				-- expansion directory as an authoritative result.
				return EMPTY
			end
			if #shells > 0 then
				filtered[#filtered + 1] = descriptor
			end
		end
		descriptors = filtered
	end
	table.sort(descriptors, function(left, right)
		return (tonumber(left and left.expansionIndex) or 0)
			> (tonumber(right and right.expansionIndex) or 0)
	end)
	runtimeCatalogCache[cacheKey] = descriptors
	return descriptors
end

function NavCatalog.ClearRuntimeCache()
	clearTable(runtimeCatalogCache)
	-- Re-read only the small Current Season lists on a new availability
	-- generation. Keep the full archive tier/instance caches independent.
	clearTable(journalSeasonCatalogCache)
	for cacheKey in pairs(availabilityScopedInstanceShellKeys) do
		instanceShellCache[cacheKey] = nil
	end
	clearTable(availabilityScopedInstanceShellKeys)
	clearTable(staticCatalogLookupCache)
	clearTable(manualCatalogLookupCache)
	clearTable(expansionHintLookupCache)
	clearTable(activityInfoCache)
	clearTable(availableActivityGroupsCache)
	clearTable(availableActivitiesCache)
	clearTable(activityGroupInfoCache)
	clearTable(verifiedSnapshotAvailabilityCache)
	if GF.MythicPlusLFGScope and GF.MythicPlusLFGScope.Invalidate then
		GF.MythicPlusLFGScope:Invalidate()
	end
end

-- Full archive metadata is invalidated on client-data/locale boundaries or
-- delayed Journal addon loading. Normal availability updates only refresh the
-- two small season lists and never force a complete archive rescan.
function NavCatalog.ClearJournalCache()
	clearTable(journalCatalogCache)
	clearTable(journalTierCatalogCache)
	clearTable(journalExpansionCatalogCache)
	clearTable(journalSeasonCatalogCache)
	clearTable(journalInstanceIDByMapCache)
	clearTable(instanceShellCache)
	clearTable(availabilityScopedInstanceShellKeys)
	-- Runtime projections embed Journal labels, maps, and visuals.
	NavCatalog.ClearRuntimeCache()
end

function NavCatalog.GetMeta(kind)
	return catalogMeta(kind)
end

-- Hot seasonal roots only need category and filter metadata. This accessor is
-- intentionally independent from Encounter Journal and archive enumeration.
function NavCatalog.GetBaseMeta(kind)
	return catalogMeta(kind)
end

function NavCatalog.GetExpansions(kind)
	return expansionDescriptors(kind)
end

function NavCatalog.GetInstanceShells(kind, expansionIndex)
	return getInstanceShells(kind, expansionIndex)
end

-- Kept for legacy/future compatibility. Verified-workbook shells already carry
-- a current native whitelist, so static level floors cannot decide their
-- visibility or authorize an Activity ID for search or creation.
function NavCatalog.GetPrecomputedRequiredLevel(shell, playerLevel)
	return precomputedRequiredLevel(shell, playerLevel)
end

function NavCatalog.GetAggregateActivityIDs(kind, expansionIndex)
	local activityIDs, seen = {}, {}
	local function add(activityID)
		activityID = tonumber(activityID)
		if activityID and activityID > 0 and not seen[activityID] then
			seen[activityID] = true
			activityIDs[#activityIDs + 1] = activityID
		end
	end
	for _, shell in ipairs(NavCatalog.GetInstanceShells(kind, expansionIndex)) do
		local scopedActivityIDs = shell.availableActivityIDs
			or shell.fallbackActivityIDs or EMPTY
		for _, activityID in ipairs(scopedActivityIDs) do
			add(activityID)
		end
		add(shell.activityID)
		for _, candidate in ipairs(shell.soloCandidates or EMPTY) do
			add(candidate and candidate.activityID)
		end
	end
	return activityIDs
end

function NavCatalog.AuthorizeInstance(kind, expansionIndex, shell)
	if type(shell) ~= "table" then
		return EMPTY
	end
	local identity = shell.identity
		or shell.journalInstanceID and ("j:" .. tostring(shell.journalInstanceID))
		or shell.groupID and ("g:" .. tostring(shell.groupID))
		or shell.activityID and ("a:" .. tostring(shell.activityID))
		or tostring(shell.label or "?")
	local cacheKey = table.concat({
		"instance", tostring(kind), tostring(expansionIndex), tostring(identity),
	}, ":")
	local cached = runtimeCatalogCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or EMPTY, "cached"
	end
	local instances, state = resolveInstanceShell(kind, shell)
	if state == "indeterminate" then
		-- Missing/throwing APIs and login-time metadata warm-up are not proof that
		-- the current character cannot use this instance. Leave the shell neutral
		-- and retry on the next explicit interaction instead of caching grey.
		return nil, state
	end
	runtimeCatalogCache[cacheKey] = instances or false
	return instances or EMPTY, state
end

function NavCatalog.RequestInstanceShellReconcile(kind, expansionIndex)
	local overlay = GF.NavCatalogOverlay
	return overlay and type(overlay.RequestReconcile) == "function"
		and overlay:RequestReconcile(kind, expansionIndex) == true or false
end

function NavCatalog.InvalidateInstanceShells(kind, expansionIndex)
	local shellKey = table.concat({
		"shells", tostring(kind), tostring(expansionIndex),
	}, ":")
	local instancePrefix = table.concat({ "instance", tostring(kind), "" }, ":")
	instanceShellCache[shellKey] = nil
	availabilityScopedInstanceShellKeys[shellKey] = nil
	-- A newly learned map/Journal boundary can move a non-reusable duplicate
	-- group away from another expansion's deterministic cold-start owner. Drop
	-- every concrete authorization for this kind so an older sibling cannot
	-- retain a stale live scope; structural shell caches remain expansion-local.
	for key in pairs(runtimeCatalogCache) do
		if type(key) == "string"
			and key:sub(1, #instancePrefix) == instancePrefix
		then
			runtimeCatalogCache[key] = nil
		end
	end
end

function NavCatalog.InvalidateAllInstanceShells()
	clearTable(instanceShellCache)
	clearTable(availabilityScopedInstanceShellKeys)
	for key in pairs(runtimeCatalogCache) do
		if type(key) == "string" and key:sub(1, 9) == "instance:" then
			runtimeCatalogCache[key] = nil
		end
	end
end

function NavCatalog.GetInstances(kind, expansionIndex)
	if expansionIndex == nil then
		return EMPTY
	end
	local fullCatalog = runtimeCatalogCache[tostring(kind)]
	local catalog
	if fullCatalog ~= nil then
		catalog = fullCatalog ~= false and fullCatalog or nil
	else
		catalog = runtimeCatalog(kind, expansionIndex)
	end
	for _, expansion in ipairs((catalog and catalog.expansions) or EMPTY) do
		if expansion.expansionIndex == expansionIndex then
			return expansion.instances or EMPTY
		end
	end
	return EMPTY
end

-- Independent structural evidence for diagnostics. Bypass menu/runtime and
-- Journal caches, preserve the selected tier, and never query LFG availability.
function NavCatalog.ReadSeasonJournalInstances(kind)
	if kind ~= "raid" and kind ~= "dungeon" then
		return EMPTY, "pending"
	end
	local journal = journalSeasonCatalog(kind, true)
	local instances = {}
	for _, instance in ipairs(seasonJournalInstances(journal)) do
		if not isSeasonJournalContainer(kind, instance) then
			instances[#instances + 1] = instance
		end
	end
	return instances, #instances > 0 and "ready" or "pending"
end

function NavCatalog.GetSeasonInstances(kind)
	local cacheKey = "season:" .. tostring(kind)
	local cached = runtimeCatalogCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or EMPTY, "ready"
	end
	local instances, state = buildSeasonInstances(kind)
	if state == "ready" then
		runtimeCatalogCache[cacheKey] = instances or false
	end
	return instances or EMPTY, state or "pending"
end

-- Return only an Adventure Guide rank that has already been materialized by
-- seasonal/archive navigation. This accessor never loads Encounter Journal,
-- switches tiers, or scans the complete guide; callers must fall back to their
-- native source order when the cached structural match is incomplete.
function NavCatalog.GetCachedJournalOrder(kind, mapID, instanceMapID, name)
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
	local function chooseFromCatalog(catalog)
		if type(catalog) ~= "table" then
			return nil
		end
		local byMapID = catalog.byMapID or EMPTY
		local byName = catalog.byName or EMPTY
		return choose(byMapID[tonumber(mapID)])
			or choose(byMapID[tonumber(instanceMapID)])
			or (nameKey and choose(byName[nameKey]) or nil)
	end

	local instance = chooseFromCatalog(journalSeasonCatalogCache[kind])
	if instance and tonumber(instance.orderIndex) then
		return tonumber(instance.orderIndex)
	end
	for _, catalog in pairs(journalExpansionCatalogCache[kind] or EMPTY) do
		instance = chooseFromCatalog(catalog)
		if instance and tonumber(instance.orderIndex) then
			return tonumber(instance.orderIndex)
		end
	end
	return nil
end

function NavCatalog.GetJournalInstance(kind, mapID, instanceMapID, name)
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
	local function chooseFromCatalog(catalog)
		if type(catalog) ~= "table" then
			return nil
		end
		return choose(catalog.byMapID[tonumber(mapID)])
			or choose(catalog.byMapID[tonumber(instanceMapID)])
			or choose(catalog.byName[nameKey])
	end

	-- Reuse the narrow catalogs already built by seasonal/archive navigation.
	-- This is the common path for Mythic+ visual association.
	local instance = chooseFromCatalog(journalSeasonCatalogCache[kind])
	if instance then
		return instance
	end
	for _, catalog in pairs(journalExpansionCatalogCache[kind] or EMPTY) do
		instance = chooseFromCatalog(catalog)
		if instance then
			return instance
		end
	end

	-- Blizzard can resolve a game map directly to its Encounter Journal entry.
	-- Prefer that O(1) lookup over enumerating every archive tier.
	local journalInstanceID = journalInstanceIDForMapID(mapID)
		or journalInstanceIDForMapID(instanceMapID)
	instance = journalInstanceInfoByID(
		kind, journalInstanceID, mapID, instanceMapID, name)
	if instance then
		return instance
	end

	-- Name-only callers have no stable tier boundary. Preserve the complete
	-- fallback for correctness, but keep it off the root-navigation hot path.
	return chooseFromCatalog(journalCatalog(kind))
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
