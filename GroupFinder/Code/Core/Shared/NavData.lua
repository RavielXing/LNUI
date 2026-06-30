local _, GF = ...

GF.NavData = {}
GF.navTree = nil

local PVE = Enum.LFGListFilter.PvE
local PVP = Enum.LFGListFilter.PvP
local RECOMMENDED = Enum.LFGListFilter.Recommended
local NOT_RECOMMENDED = Enum.LFGListFilter.NotRecommended
local CURRENT_SEASON = Enum.LFGListFilter.CurrentSeason
local CURRENT_EXPANSION = Enum.LFGListFilter.CurrentExpansion
local NOT_CURRENT_SEASON = Enum.LFGListFilter.NotCurrentSeason
local RECOMMENDED_SEARCH_MASK = bit.bor(Enum.LFGListFilter.Recommended, Enum.LFGListFilter.NotRecommended)

local function isPvPCategory(categoryID)
	for _, pvp in ipairs(GF.PVP_CATEGORIES or {}) do
		if categoryID == pvp.id then
			return true
		end
	end
	return false
end

local function node(key, level, label, extra)
	local n = { key = key, level = level, label = label, children = nil, isLeaf = false }
	if extra then
		for k, v in pairs(extra) do
			n[k] = v
		end
	end
	return n
end

local function leaf(key, level, label, extra)
	local n = node(key, level, label, extra)
	n.isLeaf = true
	return n
end

local function expansionLabel(expansionIndex)
	if GetExpansionName then
		local name = GetExpansionName(expansionIndex)
		if name and name ~= "" then
			return name
		end
	end
	return string.format("Expansion %d", expansionIndex)
end

local function currentExpansionIndex()
	if GetServerExpansionLevel then
		return GetServerExpansionLevel()
	end
	return 11
end

local function activityLabel(info)
	return (GF.ActivityInfo and GF.ActivityInfo.GetActivityLeafLabel(info)) or "?"
end

local function activityHasDifficultyTier(info)
	return GF.ActivityInfo and GF.ActivityInfo.HasDifficultyTier(info) or false
end

local function activitySortIndex(info)
	if GF.ActivityInfo and GF.ActivityInfo.GetActivitySortIndex then
		return GF.ActivityInfo.GetActivitySortIndex(info)
	end
	return tonumber(info and info.orderIndex) or 0
end

local function activityDifficultyMergeKey(info)
	if not GF.ActivityInfo then
		return nil
	end
	if GF.ActivityInfo.GetActivityDifficultyMergeKey then
		return GF.ActivityInfo.GetActivityDifficultyMergeKey(info)
	end
	local delveTier = GF.ActivityInfo.GetDelveTierNumber and GF.ActivityInfo.GetDelveTierNumber(info)
	if delveTier then
		return "delve:" .. tostring(delveTier)
	end
	local difficultyIndex = GF.ActivityInfo.GetDifficultyIndex and GF.ActivityInfo.GetDifficultyIndex(info, { includeMplus = true })
	if difficultyIndex and difficultyIndex > 0 then
		return "difficulty:" .. tostring(difficultyIndex)
	end
	return nil
end

local function catalogDungeonName(info)
	return (GF.ActivityInfo and GF.ActivityInfo.GetActivityBaseName(info)) or "?"
end

local function sortByLabel(children)
	table.sort(children, function(a, b)
		return (a.label or "") < (b.label or "")
	end)
end

local function sortByOrderThenLabel(children, descending)
	table.sort(children, function(a, b)
		local oa = tonumber(a and a.orderIndex) or 0
		local ob = tonumber(b and b.orderIndex) or 0
		if oa ~= ob then
			if descending then
				return oa > ob
			end
			return oa < ob
		end
		return (a.label or "") < (b.label or "")
	end)
end

local function leafSortIndex(n)
	if not n then
		return 0
	end
	if n.sortIndex ~= nil then
		return tonumber(n.sortIndex) or 0
	end
	if n.activityInfo then
		return activitySortIndex(n.activityInfo)
	end
	return tonumber(n.orderIndex) or 0
end

local function sortLeaves(leaves)
	table.sort(leaves, function(a, b)
		local oa = leafSortIndex(a)
		local ob = leafSortIndex(b)
		if oa == ob then
			return (a.label or "") < (b.label or "")
		end
		return oa < ob
	end)
end

local groupNameCache = {}
local activityListCache = {}

local function clearNavBuildCaches()
	wipe(groupNameCache)
	wipe(activityListCache)
	if GF.NavCatalog and GF.NavCatalog.ClearRuntimeCache then
		GF.NavCatalog.ClearRuntimeCache()
	end
end

function GF.NavData.ClearBuildCaches()
	clearNavBuildCaches()
end

function GF.NavData.InvalidateScopeCache(n)
	if not n then
		return
	end
	n._gfScopeActivityIDs = nil
	n._gfGroupActivityIDs = nil
end

local function groupDisplayName(groupID)
	if not groupID then
		return nil
	end
	local cached = groupNameCache[groupID]
	if cached == false then
		return nil
	end
	if type(cached) == "string" then
		return cached
	end
	local gName = select(1, C_LFGList.GetActivityGroupInfo(groupID))
	if gName and gName ~= "" then
		groupNameCache[groupID] = gName
		return gName
	end
	groupNameCache[groupID] = false
	return nil
end

local function getAvailableActivitiesCached(categoryID, groupID, filterFlags)
	local cacheKey = string.format("%d:%s:%d", categoryID, tostring(groupID), filterFlags or 0)
	local cached = activityListCache[cacheKey]
	if cached then
		return cached
	end
	local activities = C_LFGList.GetAvailableActivities(categoryID, groupID, filterFlags) or {}
	activityListCache[cacheKey] = activities
	return activities
end

local function getAvailableCategories(filterFlags)
	if not (C_LFGList and C_LFGList.GetAvailableCategories) then
		return nil
	end
	local ok, categories = pcall(C_LFGList.GetAvailableCategories, filterFlags or 0)
	if ok and type(categories) == "table" then
		return categories
	end
	return nil
end

local function getLfgCategoryLabel(categoryID)
	if C_LFGList and C_LFGList.GetLfgCategoryInfo then
		local ok, info = pcall(C_LFGList.GetLfgCategoryInfo, categoryID)
		if ok and type(info) == "table" and info.name and info.name ~= "" then
			return info.name
		end
	end
	return string.format("Category %d", categoryID or 0)
end

local function getCatalogGroupActivityIDs(categoryID, groupID, listFilters, preferred)
	local enumFilters = preferred or PVE
	local listFilterBits = listFilters and listFilters ~= 0 and bit.bor(listFilters, enumFilters) or nil
	local activities
	if listFilterBits then
		activities = getAvailableActivitiesCached(categoryID, groupID, listFilterBits)
		if #activities == 0 and groupID == nil then
			activities = getAvailableActivitiesCached(categoryID, 0, listFilterBits)
		end
	end
	if not activities or #activities == 0 then
		activities = getAvailableActivitiesCached(categoryID, groupID, enumFilters)
		if #activities == 0 and groupID == nil then
			activities = getAvailableActivitiesCached(categoryID, 0, enumFilters)
		end
	end
	return activities
end

local function normalizeSearchFilters(categoryID, filters)
	filters = filters or 0
	if categoryID == GF.CAT_CUSTOM or categoryID == GF.CAT_DELVE or isPvPCategory(categoryID) then
		return 0
	end
	if categoryID == GF.CAT_DUNGEON then
		local recommended = bit.band(filters, RECOMMENDED_SEARCH_MASK)
		if recommended ~= 0 then
			return recommended
		end
		return Enum.LFGListFilter.Recommended
	end
	if categoryID ~= GF.CAT_RAID then
		return filters
	end
	local recommended = bit.band(filters, RECOMMENDED_SEARCH_MASK)
	if recommended ~= 0 then
		return recommended
	end
	return Enum.LFGListFilter.Recommended
end

local function normalizeSearchPreferredFilters(categoryID, preferredFilters)
	if categoryID == GF.CAT_CUSTOM then
		return 0
	end
	if preferredFilters ~= nil then
		return preferredFilters
	end
	if isPvPCategory(categoryID) then
		return Enum.LFGListFilter.PvP
	end
	return PVE
end

local function addActivityLeaves(parentKey, level, categoryID, groupID, listFilters, preferred, out)
	local activities = getCatalogGroupActivityIDs(categoryID, groupID, listFilters, preferred)
	local filters = listFilters or 0
	local searchFilters = normalizeSearchFilters(categoryID, filters)
	local seenActivityIDs = {}
	local leavesByDifficulty = {}

	local function addMergedActivityID(n, activityID)
		if not n.activityIDsFilter then
			n.activityIDsFilter = {}
			n._gfMergedActivityIDSeen = {}
			if n.activityID then
				n.activityIDsFilter[#n.activityIDsFilter + 1] = n.activityID
				n._gfMergedActivityIDSeen[n.activityID] = true
			end
		end
		if not n._gfMergedActivityIDSeen[activityID] then
			n._gfMergedActivityIDSeen[activityID] = true
			n.activityIDsFilter[#n.activityIDsFilter + 1] = activityID
		end
	end

	for _, actID in ipairs(activities) do
		if not seenActivityIDs[actID] then
			seenActivityIDs[actID] = true
			local info = C_LFGList.GetActivityInfoTable(actID)
			if info then
				local label = activityLabel(info)
				local mergeKey = activityDifficultyMergeKey(info)
				local existing = mergeKey and leavesByDifficulty[mergeKey]
				if existing then
					addMergedActivityID(existing, actID)
				else
					local child = leaf(
						string.format("%s_a%d", parentKey, actID),
						level,
						label,
						{
							orderIndex = info.orderIndex,
							sortIndex = activitySortIndex(info),
							categoryID = categoryID,
							filters = filters,
							searchFilters = searchFilters,
							preferredFilters = preferred,
							groupID = groupID or info.groupFinderActivityGroupID,
							activityID = actID,
							activityInfo = info,
						}
					)
					if mergeKey then
						leavesByDifficulty[mergeKey] = child
					end
					out[#out + 1] = child
				end
			end
		end
	end
	for _, child in ipairs(out) do
		child._gfMergedActivityIDSeen = nil
	end
	sortLeaves(out)
end

local function buildGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred)
	local gName = groupDisplayName(groupID)
	if not gName then
		return nil
	end
	local filters = listFilters or 0
	local children = {}
	addActivityLeaves(parentKey .. "_g" .. groupID, level + 1, categoryID, groupID, filters, preferred, children)
	if #children == 0 then
		return nil
	end
	if #children == 1 then
		local child = children[1]
		local info = child.activityInfo
		if info and not activityHasDifficultyTier(info) then
			child.level = level
			child.label = gName
			child.expandPrefixPlaceholder = true
			return child
		end
	end
	return node(parentKey .. "_g" .. groupID, level, gName, {
		categoryID = categoryID,
		filters = filters,
		searchFilters = normalizeSearchFilters(categoryID, filters),
		preferredFilters = preferred,
		groupID = groupID,
		children = children,
	})
end

local function findMythicPlusActivity(categoryID, groupID, listFilters, preferred)
	local activities = getCatalogGroupActivityIDs(categoryID, groupID, listFilters, preferred)
	for _, actID in ipairs(activities) do
		local info = C_LFGList.GetActivityInfoTable(actID)
		if info and info.isMythicPlusActivity then
			return actID, info
		end
	end
	return nil, nil
end

local function stampNavKind(n, navKind)
	if not n then
		return
	end
	n.navKind = navKind
	if n.children then
		for _, c in ipairs(n.children) do
			stampNavKind(c, navKind)
		end
	end
end

local function buildSeasonDungeonGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred)
	local gName = groupDisplayName(groupID)
	if not gName then
		return nil
	end
	local filters = listFilters or 0
	local actID, info = findMythicPlusActivity(categoryID, groupID, filters, preferred)
	if actID and info then
		return leaf(parentKey .. "_g" .. groupID .. "_a" .. actID, level, gName, {
			orderIndex = info.orderIndex,
			categoryID = categoryID,
			filters = filters,
			preferredFilters = preferred,
			groupID = groupID,
			activityID = actID,
			activityInfo = info,
			navKind = "season_dungeon",
			expandPrefixPlaceholder = true,
		})
	end
	local branch = buildGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred)
	stampNavKind(branch, "season_dungeon")
	return branch
end

local function buildSoloActivityLeaf(parentKey, level, categoryID, activityID, listFilters, preferred)
	local info = C_LFGList.GetActivityInfoTable(activityID)
	if not info then
		return nil
	end
	local filters = listFilters or 0
	return leaf(parentKey .. "_a" .. activityID, level, catalogDungeonName(info), {
		orderIndex = info.orderIndex,
		sortIndex = activitySortIndex(info),
		categoryID = categoryID,
		filters = filters,
		searchFilters = normalizeSearchFilters(categoryID, filters),
		preferredFilters = preferred,
		groupID = info.groupFinderActivityGroupID,
		activityID = activityID,
		activityInfo = info,
		expandPrefixPlaceholder = true,
	})
end

local function buildCatalogExpansionBranches(parentKey, level, catalogKind, expansionIndex)
	local meta = GF.NavCatalog and GF.NavCatalog.GetMeta(catalogKind)
	if not meta then
		return {}
	end
	local categoryID = meta.categoryID
	local preferred = meta.preferredFilters or PVE
	local instances = GF.NavCatalog.GetInstances(catalogKind, expansionIndex)
	local children = {}
	for i, inst in ipairs(instances) do
		local branch
		if inst.groupID then
			branch = buildGroupBranch(
				string.format("%s_i%d", parentKey, i),
				level,
				categoryID,
				inst.groupID,
				inst.listFilters or meta.baseFilters or 0,
				preferred
			)
		elseif inst.activityID then
			branch = buildSoloActivityLeaf(
				string.format("%s_i%d", parentKey, i),
				level,
				categoryID,
				inst.activityID,
				inst.listFilters or meta.baseFilters or 0,
				preferred
			)
		end
		if branch then
			if inst.orderIndex ~= nil then
				branch.orderIndex = inst.orderIndex
			end
			children[#children + 1] = branch
		end
	end
	sortByOrderThenLabel(children)
	return children
end

local function buildCatalogInstanceBranches(parentKey, level, catalogKind, instances, buildBranch)
	local meta = GF.NavCatalog and GF.NavCatalog.GetMeta(catalogKind)
	if not meta then
		return {}
	end
	local categoryID = meta.categoryID
	local preferred = meta.preferredFilters or PVE
	local children = {}
	buildBranch = buildBranch or buildGroupBranch
	for i, inst in ipairs(instances or {}) do
		local branch
		if inst.groupID then
			branch = buildBranch(
				string.format("%s_i%d", parentKey, i),
				level,
				categoryID,
				inst.groupID,
				inst.listFilters or meta.baseFilters or 0,
				preferred
			)
		elseif inst.activityID then
			branch = buildSoloActivityLeaf(
				string.format("%s_i%d", parentKey, i),
				level,
				categoryID,
				inst.activityID,
				inst.listFilters or meta.baseFilters or 0,
				preferred
			)
		end
		if branch then
			if inst.orderIndex ~= nil then
				branch.orderIndex = inst.orderIndex
			end
			children[#children + 1] = branch
		end
	end
	sortByOrderThenLabel(children)
	return children
end

local function buildGroupsUnder(parentKey, level, categoryID, filters, preferred, groupIDs, buildBranch)
	buildBranch = buildBranch or buildGroupBranch
	local children = {}
	for _, groupID in ipairs(groupIDs or {}) do
		local branch = buildBranch(parentKey, level, categoryID, groupID, filters, preferred)
		if branch then
			children[#children + 1] = branch
		end
	end
	return children
end

local function collectMenuActivityIDs(children)
	local out = {}
	local seen = {}
	local function collect(n)
		if not n then
			return
		end
		if n.activityIDsFilter and #n.activityIDsFilter > 0 then
			for _, activityID in ipairs(n.activityIDsFilter) do
				if not seen[activityID] then
					seen[activityID] = true
					out[#out + 1] = activityID
				end
			end
		elseif n.activityID and not seen[n.activityID] then
			seen[n.activityID] = true
			out[#out + 1] = n.activityID
		end
		for _, child in ipairs(n.children or {}) do
			collect(child)
		end
	end
	for _, child in ipairs(children or {}) do
		collect(child)
	end
	return out
end

local function addAllActivitiesNode(children, parentKey, categoryID, filters, preferred, activityIDs, navKind)
	if not children or not activityIDs or #activityIDs == 0 then
		return
	end
	local L = GF.L or {}
	table.insert(children, 1, leaf(parentKey .. "_all", 1, L.NAV_ALL_INSTANCES or "All Instances", {
		categoryID = categoryID,
		filters = filters or 0,
		searchFilters = normalizeSearchFilters(categoryID, filters),
		preferredFilters = preferred,
		activityIDsFilter = activityIDs,
		navKind = navKind,
		browseOnly = true,
	}))
end

local function buildSeasonDungeonChildren(parentKey)
	local seasonF = bit.bor(CURRENT_SEASON, PVE)
	local catalogInstances = GF.NavCatalog and GF.NavCatalog.GetSeasonInstances and GF.NavCatalog.GetSeasonInstances("dungeon")
	if catalogInstances and #catalogInstances > 0 then
		local children = buildCatalogInstanceBranches(parentKey, 1, "dungeon", catalogInstances, buildSeasonDungeonGroupBranch)
		if #children > 0 then
			local allActivityIDs = collectMenuActivityIDs(children)
			addAllActivitiesNode(children, parentKey, GF.CAT_DUNGEON, seasonF, PVE, allActivityIDs, "season_dungeon")
			return children
		end
	end
	return {}
end

local function buildSeasonRaidChildren(parentKey)
	local recF = bit.bor(RECOMMENDED, PVE)
	local catalogInstances = GF.NavCatalog and GF.NavCatalog.GetSeasonInstances and GF.NavCatalog.GetSeasonInstances("raid")
	if catalogInstances and #catalogInstances > 0 then
		local children = buildCatalogInstanceBranches(parentKey, 1, "raid", catalogInstances)
		if #children > 0 then
			local allActivityIDs = collectMenuActivityIDs(children)
			addAllActivitiesNode(children, parentKey, GF.CAT_RAID, recF, PVE, allActivityIDs, "season_raid")
			for _, child in ipairs(children) do
				stampNavKind(child, "season_raid")
			end
			return children
		end
	end
	return {}
end

local function buildDelveBranchesForFilter(parentKey, level, filterFlags)
	local groups = C_LFGList.GetAvailableActivityGroups(GF.CAT_DELVE, filterFlags) or {}
	local children = buildGroupsUnder(parentKey, level, GF.CAT_DELVE, filterFlags, PVE, groups)
	if #children == 0 then
		local flat = {}
		addActivityLeaves(parentKey, level + 1, GF.CAT_DELVE, nil, filterFlags, PVE, flat)
		for _, c in ipairs(flat) do
			c.level = level
			children[#children + 1] = c
		end
	end
	for _, child in ipairs(children) do
		stampNavKind(child, "delve")
	end
	return children
end

local function buildDelveFilterBranches(parentKey, level, filterFlags, fallbackFilters)
	local children = buildDelveBranchesForFilter(parentKey, level, filterFlags)
	if #children == 0 and fallbackFilters and fallbackFilters ~= filterFlags then
		children = buildDelveBranchesForFilter(parentKey, level, fallbackFilters)
	end
	return children
end

local function delveBuckets()
	local curExp = currentExpansionIndex()
	local buckets = {}
	local prevExp = curExp - 1
	if prevExp >= 0 then
		buckets[#buckets + 1] = {
			keySuffix = "legacy_" .. prevExp,
			label = expansionLabel(prevExp),
			filters = bit.bor(NOT_RECOMMENDED, NOT_CURRENT_SEASON, PVE),
			fallbackFilters = bit.bor(NOT_RECOMMENDED, PVE),
			expansionIndex = prevExp,
		}
	end
	buckets[#buckets + 1] = {
		keySuffix = "current_" .. curExp,
		label = expansionLabel(curExp),
		filters = bit.bor(CURRENT_EXPANSION, NOT_CURRENT_SEASON, PVE),
		fallbackFilters = bit.bor(CURRENT_EXPANSION, PVE),
		expansionIndex = curExp,
	}
	table.sort(buckets, function(a, b)
		return (a.expansionIndex or 0) > (b.expansionIndex or 0)
	end)
	return buckets
end

local function buildDelveL0Children(parentKey)
	local children = {}
	for _, bucket in ipairs(delveBuckets()) do
		children[#children + 1] = node(parentKey .. "_" .. bucket.keySuffix, 1, bucket.label, {
			navKind = "delve",
			lazyKind = "delve_filter",
			categoryID = GF.CAT_DELVE,
			filters = bucket.filters,
			fallbackFilters = bucket.fallbackFilters,
			preferredFilters = PVE,
			expansionIndex = bucket.expansionIndex,
			childrenLoaded = false,
		})
	end
	return children
end

local function buildCatalogL1Expansions(parentKey, catalogKind, level)
	local children = {}
	local meta = GF.NavCatalog.GetMeta(catalogKind)
	if not meta then
		return children
	end
	for _, exp in ipairs(GF.NavCatalog.GetExpansions(catalogKind)) do
		local expIdx = exp.expansionIndex
		children[#children + 1] = node(parentKey .. "_e" .. expIdx, level, exp.label or expansionLabel(expIdx), {
			navKind = catalogKind,
			lazyKind = "archive_expansion",
			catalogKind = catalogKind,
			expansionIndex = expIdx,
			categoryID = meta.categoryID,
			filters = meta.baseFilters or 0,
			preferredFilters = meta.preferredFilters or PVE,
			childrenLoaded = false,
		})
	end
	return children
end

local function buildPvpChildren(parentKey)
	local L = GF.L or {}
	local out = {}
	local known = {}
	for _, pvp in ipairs(GF.PVP_CATEGORIES or {}) do
		known[pvp.id] = L[pvp.key] or pvp.key
	end
	local availableCategories = getAvailableCategories(PVP)
	local categoryIDs = {}
	if availableCategories then
		local seen = {}
		for _, categoryID in ipairs(availableCategories) do
			if categoryID ~= GF.CAT_CUSTOM and not seen[categoryID] then
				seen[categoryID] = true
				categoryIDs[#categoryIDs + 1] = categoryID
			end
		end
	else
		for _, pvp in ipairs(GF.PVP_CATEGORIES or {}) do
			categoryIDs[#categoryIDs + 1] = pvp.id
		end
	end
	for _, categoryID in ipairs(categoryIDs) do
		local subKey = parentKey .. "_c" .. categoryID
		local acts = {}
		addActivityLeaves(subKey, 2, categoryID, nil, 0, PVP, acts)
		if #acts > 0 then
			out[#out + 1] = node(subKey, 1, known[categoryID] or getLfgCategoryLabel(categoryID), {
				categoryID = categoryID,
				filters = 0,
				preferredFilters = PVP,
				children = acts,
			})
		end
	end
	return out
end

local function sortQuestGroupBranches(children)
	table.sort(children, function(a, b)
		local oa = tonumber(a and a.orderIndex) or 0
		local ob = tonumber(b and b.orderIndex) or 0
		if oa ~= ob then
			return oa > ob
		end
		local ga = tonumber(a and a.groupID) or 0
		local gb = tonumber(b and b.groupID) or 0
		if ga ~= gb then
			return ga > gb
		end
		return (a.label or "") < (b.label or "")
	end)
end

local function collectQuestGroups()
	local groups = {}
	local seen = {}
	local filterSets = {
		PVE,
		bit.bor(Enum.LFGListFilter.Recommended, PVE),
		bit.bor(Enum.LFGListFilter.NotRecommended, PVE),
		0,
	}
	for _, filterFlags in ipairs(filterSets) do
		for _, groupID in ipairs(C_LFGList.GetAvailableActivityGroups(GF.CAT_QUEST, filterFlags) or {}) do
			if not seen[groupID] then
				seen[groupID] = true
				groups[#groups + 1] = {
					groupID = groupID,
					listFilters = filterFlags,
				}
			end
		end
	end
	return groups
end

local function buildQuestChildren(parentKey)
	local children = {}
	for _, entry in ipairs(collectQuestGroups()) do
		local groupID = entry.groupID
		local listFilters = entry.listFilters or PVE
		local gName, orderIndex = C_LFGList.GetActivityGroupInfo(groupID)
		local acts = {}
		addActivityLeaves(parentKey .. "_q" .. groupID, 2, GF.CAT_QUEST, groupID, listFilters, PVE, acts)
		if #acts > 0 then
			for _, act in ipairs(acts) do
				act.searchFilters = 0
			end
			children[#children + 1] = node(parentKey .. "_q" .. groupID, 1, gName or ("Group " .. groupID), {
				navKind = "quest",
				categoryID = GF.CAT_QUEST,
				filters = listFilters,
				searchFilters = 0,
				preferredFilters = PVE,
				groupID = groupID,
				orderIndex = orderIndex,
				children = acts,
			})
		end
	end
	sortQuestGroupBranches(children)
	return children
end

local function customPreferredFilters(info, discoveredFilter)
	local filters = tonumber(info and info.filters) or 0
	if (info and info.isPvpActivity) or bit.band(filters, PVP) ~= 0 or bit.band(discoveredFilter or 0, PVP) ~= 0 then
		return PVP
	end
	return PVE
end

local function findActivityIDInList(activityIDs, preferredActivityID)
	if not activityIDs or #activityIDs == 0 then
		return nil
	end
	if preferredActivityID then
		for _, activityID in ipairs(activityIDs) do
			if activityID == preferredActivityID then
				return activityID
			end
		end
	end
	return activityIDs[1]
end

local function buildCustomBucketLeaf(parentKey, suffix, label, preferred, activityIDs, preferredCreateActivityID)
	if not activityIDs or #activityIDs == 0 then
		return nil
	end
	local activityID = findActivityIDInList(activityIDs, preferredCreateActivityID)
	local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID)
	return leaf(parentKey .. "_" .. suffix, 1, label, {
		navKind = "custom",
		customBucket = true,
		categoryID = GF.CAT_CUSTOM,
		filters = 0,
		searchFilters = 0,
		preferredFilters = preferred,
		searchPreferredFilters = 0,
		groupID = activityInfo and activityInfo.groupFinderActivityGroupID,
		activityID = activityID,
		activityInfo = activityInfo,
		resultActivityIDsFilter = activityIDs,
	})
end

local function addCustomActivitiesForFilter(discoveredFilter, buckets, seen)
	local function addFromGroup(groupID)
		local activities = getAvailableActivitiesCached(GF.CAT_CUSTOM, groupID, discoveredFilter) or {}
		for _, actID in ipairs(activities) do
			if not seen[actID] then
				local info = C_LFGList.GetActivityInfoTable(actID)
				if info then
					seen[actID] = true
					local preferred = customPreferredFilters(info, discoveredFilter)
					local bucket = preferred == PVP and buckets.pvp or buckets.pve
					if GF.ACTIVITY_HOUSEWARMING and actID == GF.ACTIVITY_HOUSEWARMING then
						bucket = buckets.housewarming
					end
					bucket[#bucket + 1] = actID
				end
			end
		end
	end
	addFromGroup(nil)
	addFromGroup(0)
end

local function buildCustomChildren(parentKey)
	local L = GF.L or {}
	local buckets = {
		pve = {},
		pvp = {},
		housewarming = {},
	}
	local seen = {}
	addCustomActivitiesForFilter(PVE, buckets, seen)
	addCustomActivitiesForFilter(PVP, buckets, seen)
	addCustomActivitiesForFilter(0, buckets, seen)

	local children = {}
	local pveNode = buildCustomBucketLeaf(parentKey, "pve", L.NAV_CUSTOM_PVE or "Custom PvE", PVE, buckets.pve, GF.ACTIVITY_CUSTOM_PVE)
	local pvpNode = buildCustomBucketLeaf(parentKey, "pvp", L.NAV_CUSTOM_PVP or "Custom PvP", PVP, buckets.pvp)
	local housewarmingNode = buildCustomBucketLeaf(parentKey, "housewarming", L.NAV_HOUSEWARMING or "Housewarming", PVE, buckets.housewarming, GF.ACTIVITY_HOUSEWARMING)
	if pveNode then
		children[#children + 1] = pveNode
	end
	if pvpNode then
		children[#children + 1] = pvpNode
	end
	if housewarmingNode then
		children[#children + 1] = housewarmingNode
	end
	return children
end

function GF.NavData.IsSeasonHotL0(n)
	return n and (n.navKind == "season_dungeon" or n.navKind == "season_raid")
end

local function finishEnsureChildren(n)
	if n then
		GF.NavData.InvalidateScopeCache(n)
	end
end

function GF.NavData.EnsureChildren(n)
	if not n or n.childrenLoaded then
		return
	end
	if n.lazyKind == "catalog_l0" and n.catalogKind and GF.NavCatalog then
		n.children = buildCatalogL1Expansions(n.key, n.catalogKind, 1)
		n.childrenLoaded = true
	elseif n.lazyKind == "season_dungeon" then
		n.children = buildSeasonDungeonChildren(n.key)
		n.childrenLoaded = true
	elseif n.lazyKind == "season_raid" then
		n.children = buildSeasonRaidChildren(n.key)
		n.childrenLoaded = true
	elseif n.lazyKind == "delve_l0" then
		n.children = buildDelveL0Children(n.key)
		n.childrenLoaded = true
	elseif n.lazyKind == "delve_filter" then
		n.children = buildDelveFilterBranches(n.key, 2, n.filters or PVE, n.fallbackFilters)
		n.childrenLoaded = true
	elseif n.lazyKind == "archive_expansion" and n.catalogKind and n.expansionIndex then
		n.children = buildCatalogExpansionBranches(n.key, 2, n.catalogKind, n.expansionIndex)
		n.childrenLoaded = true
	elseif n.lazyKind == "pvp_l0" then
		n.children = buildPvpChildren(n.key)
		n.childrenLoaded = true
	elseif n.lazyKind == "quest_l0" then
		n.children = buildQuestChildren(n.key)
		n.childrenLoaded = true
	elseif n.lazyKind == "custom_l0" then
		n.children = buildCustomChildren(n.key)
		n.childrenLoaded = true
	end
	finishEnsureChildren(n)
end

function GF.NavData.refreshOpenEagerRoots()
	local tree = GF.navTree
	if not tree then
		return false
	end
	local rebuilt = false
	for _, root in ipairs(tree) do
		if root.navKind == "season_dungeon" and root.childrenLoaded then
			GF.NavData.InvalidateScopeCache(root)
			root.children = buildSeasonDungeonChildren("season_dungeon")
			rebuilt = true
		elseif root.navKind == "season_raid" and root.childrenLoaded then
			GF.NavData.InvalidateScopeCache(root)
			root.children = buildSeasonRaidChildren("season_raid")
			rebuilt = true
		elseif root.navKind == "delve" and root.childrenLoaded then
			GF.NavData.InvalidateScopeCache(root)
			root.children = buildDelveL0Children(root.key)
			rebuilt = true
		end
	end
	return rebuilt
end

-- 活动可用性变化时重建已展开的 API 驱动分支；未展开节点仍按 EnsureChildren 懒加载。
local AVAIL_REFRESH_LAZY = {
	catalog_l0 = true,
	season_dungeon = true,
	season_raid = true,
	delve_l0 = true,
	delve_filter = true,
	archive_expansion = true,
	quest_l0 = true,
	custom_l0 = true,
}

local function refreshExpandedCatalog(nodes, expanded)
	local rebuilt = false
	for _, n in ipairs(nodes or {}) do
		if expanded[n.key] and n.childrenLoaded and n.lazyKind and AVAIL_REFRESH_LAZY[n.lazyKind] then
			GF.NavData.InvalidateScopeCache(n)
			if n.lazyKind == "catalog_l0" and n.catalogKind then
				n.children = buildCatalogL1Expansions(n.key, n.catalogKind, 1)
			elseif n.lazyKind == "delve_l0" then
				n.children = buildDelveL0Children(n.key)
			elseif n.lazyKind == "delve_filter" then
				n.children = buildDelveFilterBranches(n.key, 2, n.filters or PVE, n.fallbackFilters)
			elseif n.lazyKind == "archive_expansion" and n.catalogKind and n.expansionIndex then
				n.children = buildCatalogExpansionBranches(n.key, 2, n.catalogKind, n.expansionIndex)
			elseif n.lazyKind == "season_dungeon" then
				n.children = buildSeasonDungeonChildren(n.key)
			elseif n.lazyKind == "season_raid" then
				n.children = buildSeasonRaidChildren(n.key)
			elseif n.lazyKind == "quest_l0" then
				n.children = buildQuestChildren(n.key)
			elseif n.lazyKind == "custom_l0" then
				n.children = buildCustomChildren(n.key)
			end
			rebuilt = true
		end
		if n.children then
			if refreshExpandedCatalog(n.children, expanded) then
				rebuilt = true
			end
		end
	end
	return rebuilt
end

function GF.NavData.refreshExpandedCatalogBranches(expanded)
	if not GF.navTree then
		return false
	end
	return refreshExpandedCatalog(GF.navTree, expanded or {})
end

function GF.NavData.OnAvailabilityChanged(expanded)
	GF.NavData.ClearBuildCaches()
	local rebuilt = GF.NavData.refreshOpenEagerRoots()
	if GF.NavData.refreshExpandedCatalogBranches(expanded) then
		rebuilt = true
	end
	return rebuilt
end

function GF.NavData.Rebuild()
	local L = GF.L or {}
	local tree = {}
	local expDungeonF = bit.bor(Enum.LFGListFilter.CurrentExpansion, Enum.LFGListFilter.NotCurrentSeason, PVE)
	local recRaidF = bit.bor(Enum.LFGListFilter.Recommended, PVE)

	local histChildren = GF.History and GF.History.BuildNodes() or {}
	tree[#tree + 1] = node("history", 0, L.NAV_HISTORY or "History", {
		navKind = "history",
		noExpandPrefix = true,
		children = histChildren,
		childrenLoaded = true,
	})

	tree[#tree + 1] = node("season_dungeon", 0, L.NAV_SEASON_DUNGEON or L.NAV_SEASON or "Season Dungeons", {
		navKind = "season_dungeon",
		lazyKind = "season_dungeon",
		categoryID = GF.CAT_DUNGEON,
		filters = bit.bor(Enum.LFGListFilter.CurrentSeason, PVE),
		preferredFilters = PVE,
		childrenLoaded = false,
	})

	tree[#tree + 1] = node("season_raid", 0, L.NAV_SEASON_RAID or "Season Raids", {
		navKind = "season_raid",
		lazyKind = "season_raid",
		categoryID = GF.CAT_RAID,
		filters = recRaidF,
		preferredFilters = PVE,
		childrenLoaded = false,
	})

	tree[#tree + 1] = node("dungeon", 0, L.NAV_DUNGEON or "Dungeons", {
		navKind = "dungeon",
		lazyKind = "catalog_l0",
		catalogKind = "dungeon",
		categoryID = GF.CAT_DUNGEON,
		filters = expDungeonF,
		preferredFilters = PVE,
		childrenLoaded = false,
	})

	tree[#tree + 1] = node("delve", 0, L.NAV_DELVE or "Delves", {
		navKind = "delve",
		lazyKind = "delve_l0",
		categoryID = GF.CAT_DELVE,
		filters = PVE,
		preferredFilters = PVE,
		childrenLoaded = false,
	})

	tree[#tree + 1] = node("raid", 0, L.NAV_RAID or "Raids", {
		navKind = "raid",
		lazyKind = "catalog_l0",
		catalogKind = "raid",
		categoryID = GF.CAT_RAID,
		filters = recRaidF,
		preferredFilters = PVE,
		childrenLoaded = false,
	})

	local pvpRootCat = GF.PVP_CATEGORIES and GF.PVP_CATEGORIES[1] and GF.PVP_CATEGORIES[1].id or 8
	tree[#tree + 1] = node("pvp", 0, L.NAV_PVP or "PvP", {
		navKind = "pvp",
		lazyKind = "pvp_l0",
		categoryID = pvpRootCat,
		filters = 0,
		preferredFilters = PVP,
		childrenLoaded = false,
	})

	tree[#tree + 1] = node("quest", 0, L.NAV_QUEST or "Quests", {
		navKind = "quest",
		lazyKind = "quest_l0",
		categoryID = GF.CAT_QUEST,
		filters = PVE,
		preferredFilters = PVE,
		childrenLoaded = false,
	})

	tree[#tree + 1] = node("custom", 0, L.NAV_CUSTOM or "Custom", {
		navKind = "custom",
		lazyKind = "custom_l0",
		categoryID = GF.CAT_CUSTOM,
		searchFilters = 0,
		searchPreferredFilters = 0,
		preferredFilters = PVE,
		childrenLoaded = false,
	})

	GF.navTree = tree
	return tree
end

function GF.NavData.RefreshLocaleLabels()
	if not GF.navTree then
		return
	end
	local L = GF.L or {}
	local labels = {
		history = L.NAV_HISTORY or "History",
		season_dungeon = L.NAV_SEASON_DUNGEON or L.NAV_SEASON or "Season Dungeons",
		season_raid = L.NAV_SEASON_RAID or "Season Raids",
		dungeon = L.NAV_DUNGEON or "Dungeons",
		delve = L.NAV_DELVE or "Delves",
		raid = L.NAV_RAID or "Raids",
		pvp = L.NAV_PVP or "PvP",
		quest = L.NAV_QUEST or "Quests",
		custom = L.NAV_CUSTOM or "Custom",
	}
	for _, root in ipairs(GF.navTree) do
		if root and labels[root.key] then
			root.label = labels[root.key]
		end
		if root and root.navKind == "pvp" and root.childrenLoaded then
			root.children = buildPvpChildren(root.key)
		elseif root and root.navKind == "custom" and root.childrenLoaded then
			root.children = buildCustomChildren(root.key)
		end
	end
end

function GF.NavData.RefreshHistory()
	if not GF.navTree then
		return
	end
	for _, root in ipairs(GF.navTree) do
		if root.navKind == "history" then
			root.children = GF.History and GF.History.BuildNodes() or {}
			root.childrenLoaded = true
			break
		end
	end
end

function GF.NavData.GetTree()
	return GF.navTree or GF.NavData.Rebuild()
end

function GF.NavData.FindNodeByKey(key)
	if not key then
		return nil
	end
	local found
	local function walk(n)
		if found or not n then
			return
		end
		if n.key == key then
			found = n
			return
		end
		if n.children then
			for _, child in ipairs(n.children) do
				walk(child)
			end
		end
	end
	for _, root in ipairs(GF.navTree or {}) do
		walk(root)
	end
	return found
end

local function collectActivityIDs(n, out)
	if n.resultActivityIDsFilter and #n.resultActivityIDsFilter > 0 then
		for _, activityID in ipairs(n.resultActivityIDsFilter) do
			out[#out + 1] = activityID
		end
		return
	end
	if n.activityIDsFilter and #n.activityIDsFilter > 0 and not n.categoryBrowse then
		for _, activityID in ipairs(n.activityIDsFilter) do
			out[#out + 1] = activityID
		end
		return
	end
	if n.activityID and not n.categoryBrowse then
		out[#out + 1] = n.activityID
		return
	end
	if n.children then
		for _, child in ipairs(n.children) do
			collectActivityIDs(child, out)
		end
	end
end

local function collectCatalogExpansionActivityIDs(catalogKind, expansionIndex)
	local meta = GF.NavCatalog and GF.NavCatalog.GetMeta(catalogKind)
	if not meta then
		return nil
	end
	local categoryID = meta.categoryID
	local preferred = meta.preferredFilters or PVE
	local seen = {}
	local ids = {}
	for _, inst in ipairs(GF.NavCatalog.GetInstances(catalogKind, expansionIndex)) do
		if inst.groupID then
			local acts = inst.activityIDs
			if not acts or #acts == 0 then
				local listFilters = inst.listFilters or meta.baseFilters or 0
				acts = getCatalogGroupActivityIDs(categoryID, inst.groupID, listFilters, preferred)
			end
			for _, actID in ipairs(acts) do
				if not seen[actID] then
					seen[actID] = true
					ids[#ids + 1] = actID
				end
			end
		elseif inst.activityID then
			local actID = inst.activityID
			if not seen[actID] then
				seen[actID] = true
				ids[#ids + 1] = actID
			end
		end
	end
	if #ids > 0 then
		return ids
	end
	return nil
end

local function mergeActivityIDsInto(src, out, seen)
	if not src then
		return
	end
	for _, actID in ipairs(src) do
		if not seen[actID] then
			seen[actID] = true
			out[#out + 1] = actID
		end
	end
end

local function collectCatalogAllActivityIDs(catalogKind)
	if not GF.NavCatalog then
		return nil
	end
	local seen = {}
	local ids = {}
	for _, exp in ipairs(GF.NavCatalog.GetExpansions(catalogKind)) do
		mergeActivityIDsInto(collectCatalogExpansionActivityIDs(catalogKind, exp.expansionIndex), ids, seen)
	end
	if #ids > 0 then
		return ids
	end
	return nil
end

local function collectDelveActivityIDsForFilter(filterFlags)
	local categoryID = GF.CAT_DELVE
	local seen = {}
	local ids = {}
	local groups = C_LFGList.GetAvailableActivityGroups(categoryID, filterFlags) or {}
	for _, groupID in ipairs(groups) do
		mergeActivityIDsInto(getAvailableActivitiesCached(categoryID, groupID, filterFlags), ids, seen)
	end
	if #ids == 0 then
		mergeActivityIDsInto(getAvailableActivitiesCached(categoryID, nil, filterFlags), ids, seen)
	end
	if #ids > 0 then
		return ids
	end
	return nil
end

local function collectDelveFilterActivityIDs(filterFlags, fallbackFilters)
	local ids = collectDelveActivityIDsForFilter(filterFlags)
	if ids and #ids > 0 then
		return ids
	end
	if fallbackFilters and fallbackFilters ~= filterFlags then
		return collectDelveActivityIDsForFilter(fallbackFilters)
	end
	return nil
end

local function collectDelveL0ActivityIDs()
	local seen = {}
	local ids = {}
	for _, bucket in ipairs(delveBuckets()) do
		mergeActivityIDsInto(collectDelveFilterActivityIDs(bucket.filters, bucket.fallbackFilters), ids, seen)
	end
	if #ids > 0 then
		return ids
	end
	return nil
end

local function collectL0ScopeActivityIDs(n)
	local lk = n.lazyKind
	if lk == "catalog_l0" and n.catalogKind then
		return collectCatalogAllActivityIDs(n.catalogKind)
	end
	if lk == "delve_l0" then
		return collectDelveL0ActivityIDs()
	end
	if lk == "season_dungeon" or lk == "season_raid" or lk == "quest_l0" then
		if not n.childrenLoaded then
			GF.NavData.EnsureChildren(n)
		end
		local ids = {}
		collectActivityIDs(n, ids)
		if #ids > 0 then
			return ids
		end
	end
	return nil
end

local function finishScopeWithActivityIDs(scope, ids)
	if ids and #ids > 0 then
		scope.activityIDsFilter = ids
	end
	return scope
end

local function addResultActivityID(scope, activityID)
	if not scope or not activityID then
		return
	end
	if not scope.resultActivityIDsFilter then
		scope.resultActivityIDsFilter = {}
		scope._seenResultActivityIDs = {}
	end
	if not scope._seenResultActivityIDs[activityID] then
		scope._seenResultActivityIDs[activityID] = true
		scope.resultActivityIDsFilter[#scope.resultActivityIDsFilter + 1] = activityID
	end
end

local function addActivityScope(scopesByKey, scopeOrder, source, activityID)
	if not source or not activityID then
		return
	end
	local categoryID = source.categoryID
	local filters = source.searchFilters
	if filters == nil then
		filters = source.filters or 0
	end
	if not categoryID then
		local info = C_LFGList.GetActivityInfoTable(activityID)
		categoryID = info and info.categoryID
	end
	if not categoryID then
		return
	end
	local preferredFilters = source.searchPreferredFilters
	if preferredFilters == nil then
		preferredFilters = source.preferredFilters
	end
	preferredFilters = normalizeSearchPreferredFilters(categoryID, preferredFilters)
	filters = normalizeSearchFilters(categoryID, filters)
	local scopeKey = tostring(categoryID) .. ":" .. tostring(preferredFilters) .. ":" .. tostring(filters)
	local scope = scopesByKey[scopeKey]
	if not scope then
		scope = {
			categoryID = categoryID,
			filters = filters,
			preferredFilters = preferredFilters,
			navKind = source.navKind,
		}
		if categoryID == GF.CAT_CUSTOM then
			scope.resultActivityIDsFilter = {}
			scope._seenResultActivityIDs = {}
		else
			scope.activityIDsFilter = {}
			scope._seenActivityIDs = {}
		end
		scopesByKey[scopeKey] = scope
		scopeOrder[#scopeOrder + 1] = scopeKey
	end
	if categoryID == GF.CAT_CUSTOM then
		addResultActivityID(scope, activityID)
	elseif not scope._seenActivityIDs[activityID] then
		scope._seenActivityIDs[activityID] = true
		scope.activityIDsFilter[#scope.activityIDsFilter + 1] = activityID
	end
end

local function collectNodeActivityScopes(n, scopesByKey, scopeOrder)
	if not n or n.disabled or n.categoryBrowse then
		return
	end
	if n.resultActivityIDsFilter and #n.resultActivityIDsFilter > 0 then
		for _, actID in ipairs(n.resultActivityIDsFilter) do
			addActivityScope(scopesByKey, scopeOrder, n, actID)
		end
		return
	end
	if n.activityIDsFilter and #n.activityIDsFilter > 0 then
		for _, actID in ipairs(n.activityIDsFilter) do
			addActivityScope(scopesByKey, scopeOrder, n, actID)
		end
		return
	end
	if n.activityID then
		addActivityScope(scopesByKey, scopeOrder, n, n.activityID)
		return
	end
	if n.groupID and n.categoryID then
		local acts = n._gfGroupActivityIDs
		if not acts then
			acts = getCatalogGroupActivityIDs(n.categoryID, n.groupID, n.filters or 0, n.preferredFilters or PVE)
			n._gfGroupActivityIDs = acts
		end
		for _, actID in ipairs(acts or {}) do
			addActivityScope(scopesByKey, scopeOrder, n, actID)
		end
		return
	end
	if n.lazyKind and not n.childrenLoaded then
		GF.NavData.EnsureChildren(n)
	end
	for _, child in ipairs(n.children or {}) do
		collectNodeActivityScopes(child, scopesByKey, scopeOrder)
	end
end

local function finalizeActivityScopes(scopesByKey, scopeOrder)
	local scopes = {}
	for _, key in ipairs(scopeOrder or {}) do
		local scope = scopesByKey[key]
		local hasActivityIDs = scope and scope.activityIDsFilter and #scope.activityIDsFilter > 0
		local hasResultActivityIDs = scope and scope.resultActivityIDsFilter and #scope.resultActivityIDsFilter > 0
		if scope and (hasActivityIDs or hasResultActivityIDs) then
			if scope._seenActivityIDs then
				scope._seenActivityIDs = nil
			end
			if scope._seenResultActivityIDs then
				scope._seenResultActivityIDs = nil
			end
			scopes[#scopes + 1] = scope
		end
	end
	return scopes
end

local function collectSearchScopesForNode(n, opts)
	if not n or n.disabled then
		return {}
	end
	local scopesByKey = {}
	local scopeOrder = {}
	collectNodeActivityScopes(n, scopesByKey, scopeOrder)
	local scopes = finalizeActivityScopes(scopesByKey, scopeOrder)
	if #scopes > 0 then
		return scopes
	end
	local scope = GF.NavData.ResolveSearchScope(n, opts)
	if scope and scope.categoryID then
		return { scope }
	end
	return {}
end

local function appendSearchScopes(out, scopes)
	for _, scope in ipairs(scopes or {}) do
		if scope and scope.categoryID then
			out[#out + 1] = scope
		end
	end
end

local function addFilterActivityGroupID(out, seen, groupID)
	groupID = tonumber(groupID)
	if groupID and groupID > 0 and not seen[groupID] then
		seen[groupID] = true
		out[#out + 1] = groupID
	end
end

local function addFilterActivityGroupIDForActivity(out, seen, activityID)
	if not activityID or not C_LFGList or not C_LFGList.GetActivityInfoTable then
		return
	end
	local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
	if ok and info then
		addFilterActivityGroupID(out, seen, info.groupFinderActivityGroupID)
	end
end

local function rootByNavKind(navKind)
	if not navKind then
		return nil
	end
	for _, root in ipairs(GF.NavData.GetTree() or {}) do
		if root and root.navKind == navKind then
			return root
		end
	end
	return nil
end

function GF.NavData.ResolveSearchScope(n, opts)
	opts = opts or {}
	local forSearch = opts.forSearch == true
	if not n or not n.categoryID then
		return nil
	end
	local categoryID = n.categoryID
	local rawFilters = n.searchFilters
	if rawFilters == nil then
		rawFilters = n.filters or 0
	end
	rawFilters = normalizeSearchFilters(categoryID, rawFilters)
	local filters = GF.Filter and GF.Filter:ResolveCategoryFilters(categoryID, rawFilters) or rawFilters
	local preferredFilters = n.searchPreferredFilters
	if preferredFilters == nil then
		preferredFilters = n.preferredFilters
	end
	preferredFilters = normalizeSearchPreferredFilters(categoryID, preferredFilters)
	local scope = {
		categoryID = categoryID,
		filters = filters,
		preferredFilters = preferredFilters,
		groupID = n.groupID,
		activityID = nil,
		activityIDsFilter = nil,
		categoryBrowse = n.categoryBrowse,
		navKind = n.navKind,
	}

	if n.activityIDsFilter and #n.activityIDsFilter > 0 then
		return finishScopeWithActivityIDs(scope, n.activityIDsFilter)
	end

	if n.activityID and not n.categoryBrowse then
		scope.activityID = n.activityID
		if categoryID == GF.CAT_CUSTOM then
			addResultActivityID(scope, n.activityID)
			scope._seenResultActivityIDs = nil
			return scope
		end
		return finishScopeWithActivityIDs(scope, { n.activityID })
	end

	if n.groupID and not n.categoryBrowse then
		local listFilters = n.filters or 0
		local acts = n._gfGroupActivityIDs
		if not acts then
			acts = getCatalogGroupActivityIDs(categoryID, n.groupID, listFilters, preferredFilters)
			n._gfGroupActivityIDs = acts
		end
		return finishScopeWithActivityIDs(scope, acts)
	end

	if forSearch and (n.level or 0) == 0 and n.lazyKind and not n.categoryBrowse
		and not n.activityID and not n.groupID then
		local ids = n._gfScopeActivityIDs
		if not ids then
			ids = collectL0ScopeActivityIDs(n)
			if ids then
				n._gfScopeActivityIDs = ids
			end
		end
		if ids and #ids > 0 then
			return finishScopeWithActivityIDs(scope, ids)
		end
	end

	if forSearch and n.lazyKind == "delve_filter" and not n.categoryBrowse then
		if not n.childrenLoaded then
			GF.NavData.EnsureChildren(n)
		end
		local ids = n._gfScopeActivityIDs
		if not ids then
			ids = {}
			collectActivityIDs(n, ids)
			if #ids == 0 then
				ids = collectDelveFilterActivityIDs(n.filters or PVE, n.fallbackFilters) or {}
			end
			if #ids > 0 then
				n._gfScopeActivityIDs = ids
			else
				ids = nil
			end
		end
		if ids and #ids > 0 then
			return finishScopeWithActivityIDs(scope, ids)
		end
	end

	if forSearch and n.lazyKind == "archive_expansion"
		and n.catalogKind and n.expansionIndex and not n.categoryBrowse then
		if not n.childrenLoaded then
			GF.NavData.EnsureChildren(n)
		end
		local ids = n._gfScopeActivityIDs
		if not ids then
			ids = {}
			collectActivityIDs(n, ids)
			if #ids == 0 then
				ids = collectCatalogExpansionActivityIDs(n.catalogKind, n.expansionIndex) or {}
			end
			if #ids > 0 then
				n._gfScopeActivityIDs = ids
			else
				ids = nil
			end
		end
		if ids and #ids > 0 then
			return finishScopeWithActivityIDs(scope, ids)
		end
	end

	if forSearch and n.children and not n.categoryBrowse
		and ((n.level or 0) > 0 or n.navKind == "pvp" or GF.NavData.IsSeasonHotL0(n)) then
		if n._gfScopeActivityIDs then
			finishScopeWithActivityIDs(scope, n._gfScopeActivityIDs)
		else
			local ids = {}
			collectActivityIDs(n, ids)
			if #ids > 0 then
				n._gfScopeActivityIDs = ids
				finishScopeWithActivityIDs(scope, ids)
			end
		end
	end

	return scope
end

function GF.NavData.ResolveSearchScopes(n, opts)
	opts = opts or {}
	if n then
		return collectSearchScopesForNode(n, opts)
	end

	local scopes = {}
	for _, root in ipairs(GF.NavData.GetTree() or {}) do
		if root and root.navKind ~= "history" and not root.disabled then
			appendSearchScopes(scopes, collectSearchScopesForNode(root, opts))
		end
	end
	return scopes
end

function GF.NavData.GetFilterActivityGroupIDs(navKind)
	local root = rootByNavKind(navKind)
	if not root then
		return {}
	end
	local seen = {}
	local groupIDs = {}
	for _, scope in ipairs(GF.NavData.ResolveSearchScopes(root, { forSearch = true }) or {}) do
		addFilterActivityGroupID(groupIDs, seen, scope.groupID)
		for _, activityID in ipairs(scope.activityIDsFilter or {}) do
			addFilterActivityGroupIDForActivity(groupIDs, seen, activityID)
		end
	end
	return groupIDs
end

function GF.NavData.GetSearchBlockHint(n)
	return nil
end

function GF.NavData.IsSearchable(n)
	if not n or n.disabled then
		return false
	end
	if n.categoryBrowse then
		return true
	end
	if n.activityID then
		return true
	end
	if n.categoryID then
		return true
	end
	return false
end

function GF.NavData.AcceptsBrowseSelection(n)
	if not n or n.disabled then
		return false
	end
	if GF.NavData.GetSearchBlockHint(n) then
		return true
	end
	return GF.NavData.IsSearchable(n)
end

function GF.NavData.ResolveCreateActivityID(n)
	if not n then
		return nil
	end
	if n.activityID and not n.categoryBrowse then
		return n.activityID
	end
	return nil
end

function GF.NavData.IsCreateable(n)
	if not n or n.disabled or not n.categoryID then
		return false
	end
	return GF.NavData.ResolveCreateActivityID(n) ~= nil
end

function GF.NavData.FindNodeByActivityID(activityID)
	if not activityID then
		return nil
	end
	local tree = GF.NavData.GetTree()
	local found
	local function walk(n)
		if found or not n then
			return
		end
		if n.activityID == activityID and not n.categoryBrowse then
			found = n
			return
		end
		if n.children then
			for _, child in ipairs(n.children) do
				walk(child)
			end
		end
	end
	for _, root in ipairs(tree) do
		walk(root)
	end
	return found
end

function GF.NavData.RequestRefresh()
	if C_LFGList.RequestAvailableActivities then
		C_LFGList.RequestAvailableActivities()
	end
end
