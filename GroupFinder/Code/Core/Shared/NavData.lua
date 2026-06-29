local _, GF = ...

GF.NavData = {}
GF.navTree = nil

local PVE = Enum.LFGListFilter.PvE

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
	if not info then
		return "?"
	end
	local L = GF.L or {}
	if info.isMythicPlusActivity then
		return L.DIFF_MYTHIC_PLUS or "M+"
	elseif info.isMythicActivity then
		return L.DIFF_MYTHIC or "Mythic"
	elseif info.isHeroicActivity then
		return L.DIFF_HEROIC or "Heroic"
	elseif info.isNormalActivity then
		return L.DIFF_NORMAL or "Normal"
	end
	if info.shortName and info.shortName ~= "" then
		return info.shortName
	end
	return info.fullName or "?"
end

local function activityHasDifficultyTier(info)
	if not info then
		return false
	end
	return info.isMythicPlusActivity or info.isMythicActivity
		or info.isHeroicActivity or info.isNormalActivity
end

local function catalogDungeonName(info)
	if not info then
		return "?"
	end
	if info.fullName and info.fullName ~= "" then
		local base = info.fullName:match("^(.+) %([^)]+%)$")
		if base and base ~= "" then
			return base
		end
	end
	local sn = info.shortName
	if sn and sn ~= "" then
		local L = GF.L or {}
		if sn ~= (L.DIFF_NORMAL or "Normal") and sn ~= (L.DIFF_HEROIC or "Heroic")
			and sn ~= (L.DIFF_MYTHIC or "Mythic") and sn ~= (L.DIFF_MYTHIC_PLUS or "M+")
			and sn ~= "Normal" and sn ~= "Heroic" and sn ~= "Mythic" and sn ~= "Mythic+" then
			return sn
		end
	end
	return info.fullName or info.shortName or "?"
end

local function sortByLabel(children)
	table.sort(children, function(a, b)
		return (a.label or "") < (b.label or "")
	end)
end

local function sortLeaves(leaves)
	table.sort(leaves, function(a, b)
		local oa = a.orderIndex or 0
		local ob = b.orderIndex or 0
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

local function getCatalogGroupActivityIDs(categoryID, groupID, listFilters, preferred)
	local enumFilters = preferred or PVE
	local activities = getAvailableActivitiesCached(categoryID, groupID, enumFilters)
	if #activities == 0 and listFilters and listFilters ~= 0 then
		activities = getAvailableActivitiesCached(categoryID, groupID, bit.bor(listFilters, enumFilters))
	end
	return activities
end

local function addActivityLeaves(parentKey, level, categoryID, groupID, listFilters, preferred, out)
	local activities = getCatalogGroupActivityIDs(categoryID, groupID, listFilters, preferred)
	local searchFilters = listFilters or 0
	for _, actID in ipairs(activities) do
		local info = C_LFGList.GetActivityInfoTable(actID)
		if info then
			out[#out + 1] = leaf(
				string.format("%s_a%d", parentKey, actID),
				level,
				activityLabel(info),
				{
					orderIndex = info.orderIndex,
					categoryID = categoryID,
					filters = searchFilters,
					preferredFilters = preferred,
					groupID = groupID or info.groupFinderActivityGroupID,
					activityID = actID,
					activityInfo = info,
				}
			)
		end
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
		categoryID = categoryID,
		filters = filters,
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
			children[#children + 1] = branch
		end
	end
	sortByLabel(children)
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
	sortByLabel(children)
	return children
end

local function collectMenuActivityIDs(children)
	local out = {}
	local seen = {}
	local function collect(n)
		if not n then
			return
		end
		if n.activityID and not seen[n.activityID] then
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

local function collectActivityIDsFromRange(categoryID, groupIDs, filters, preferred, predicate)
	local out = {}
	local seen = {}
	for _, groupID in ipairs(groupIDs or {}) do
		local activities = getCatalogGroupActivityIDs(categoryID, groupID, filters or 0, preferred)
		for _, actID in ipairs(activities or {}) do
			if not seen[actID] then
				local info = C_LFGList.GetActivityInfoTable(actID)
				if info and (not predicate or predicate(info)) then
					seen[actID] = true
					out[#out + 1] = actID
				end
			end
		end
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
		preferredFilters = preferred,
		activityIDsFilter = activityIDs,
		navKind = navKind,
		browseOnly = true,
	}))
end

local function buildSeasonDungeonChildren(parentKey)
	local seasonF = bit.bor(Enum.LFGListFilter.CurrentSeason, PVE)
	local groups = C_LFGList.GetAvailableActivityGroups(GF.CAT_DUNGEON, seasonF) or {}
	local children = buildGroupsUnder(parentKey, 1, GF.CAT_DUNGEON, seasonF, PVE, groups, buildSeasonDungeonGroupBranch)
	if PlayerIsTimerunning and PlayerIsTimerunning() then
		local trF = bit.bor(Enum.LFGListFilter.Timerunning, PVE)
		local trGroups = C_LFGList.GetAvailableActivityGroups(GF.CAT_DUNGEON, trF) or {}
		local trChildren = buildGroupsUnder(parentKey .. "_tr", 1, GF.CAT_DUNGEON, trF, PVE, trGroups, buildSeasonDungeonGroupBranch)
		for _, c in ipairs(trChildren) do
			children[#children + 1] = c
		end
	end
	local allActivityIDs = collectMenuActivityIDs(children)
	if #allActivityIDs == 0 then
		allActivityIDs = collectActivityIDsFromRange(GF.CAT_DUNGEON, groups, seasonF, PVE, function(info)
			return info.isMythicPlusActivity == true
		end)
	end
	addAllActivitiesNode(children, parentKey, GF.CAT_DUNGEON, seasonF, PVE, allActivityIDs, "season_dungeon")
	return children
end

local function buildSeasonRaidChildren(parentKey)
	local recF = bit.bor(Enum.LFGListFilter.Recommended, PVE)
	local groups = C_LFGList.GetAvailableActivityGroups(GF.CAT_RAID, recF) or {}
	local children = buildGroupsUnder(parentKey, 1, GF.CAT_RAID, recF, PVE, groups)
	local allActivityIDs = collectMenuActivityIDs(children)
	if #allActivityIDs == 0 then
		allActivityIDs = collectActivityIDsFromRange(GF.CAT_RAID, groups, recF, PVE)
	end
	addAllActivitiesNode(children, parentKey, GF.CAT_RAID, recF, PVE, allActivityIDs, "season_raid")
	for _, child in ipairs(children) do
		stampNavKind(child, "season_raid")
	end
	return children
end

local function buildDelveOpenBranches(parentKey, level)
	local openF = bit.bor(Enum.LFGListFilter.CurrentExpansion, PVE)
	local groups = C_LFGList.GetAvailableActivityGroups(GF.CAT_DELVE, openF) or {}
	local children = buildGroupsUnder(parentKey, level, GF.CAT_DELVE, openF, PVE, groups)
	if #children == 0 then
		local flat = {}
		addActivityLeaves(parentKey, level + 1, GF.CAT_DELVE, nil, openF, PVE, flat)
		for _, c in ipairs(flat) do
			c.level = level
			children[#children + 1] = c
		end
	end
	return children
end

local function buildDelveL0Children(parentKey)
	local curExp = currentExpansionIndex()
	local openF = bit.bor(Enum.LFGListFilter.CurrentExpansion, PVE)
	local children = {}
	children[#children + 1] = node(parentKey .. "_open_" .. curExp, 1, expansionLabel(curExp), {
		navKind = "delve_open",
		lazyKind = "delve_open",
		categoryID = GF.CAT_DELVE,
		filters = openF,
		preferredFilters = PVE,
		expansionIndex = curExp,
		childrenLoaded = false,
	})
	if GF.NavCatalog then
		for _, exp in ipairs(GF.NavCatalog.GetExpansions("delve")) do
			local expIdx = exp.expansionIndex
			children[#children + 1] = node(parentKey .. "_legacy_" .. expIdx, 1, expansionLabel(expIdx), {
				navKind = "delve",
				lazyKind = "delve_legacy",
				catalogKind = "delve",
				expansionIndex = expIdx,
				categoryID = GF.CAT_DELVE,
				filters = PVE,
				preferredFilters = PVE,
				childrenLoaded = false,
			})
		end
	end
	return children
end

local function buildCatalogL1Expansions(parentKey, catalogKind, level)
	local children = {}
	for _, exp in ipairs(GF.NavCatalog.GetExpansions(catalogKind)) do
		local expIdx = exp.expansionIndex
		children[#children + 1] = node(parentKey .. "_e" .. expIdx, level, expansionLabel(expIdx), {
			navKind = catalogKind,
			lazyKind = "archive_expansion",
			catalogKind = catalogKind,
			expansionIndex = expIdx,
			categoryID = GF.NavCatalog.GetMeta(catalogKind).categoryID,
			filters = GF.NavCatalog.GetMeta(catalogKind).baseFilters or 0,
			preferredFilters = GF.NavCatalog.GetMeta(catalogKind).preferredFilters or PVE,
			childrenLoaded = false,
		})
	end
	return children
end

local function buildPvpChildren(parentKey)
	local L = GF.L or {}
	local out = {}
	for _, pvp in ipairs(GF.PVP_CATEGORIES) do
		local preferred = Enum.LFGListFilter.PvP
		local subKey = parentKey .. "_c" .. pvp.id
		local label = L[pvp.key] or pvp.key
		local acts = {}
		addActivityLeaves(subKey, 2, pvp.id, nil, 0, preferred, acts)
		if #acts > 0 then
			out[#out + 1] = node(subKey, 1, label, {
				categoryID = pvp.id,
				filters = 0,
				preferredFilters = preferred,
				children = acts,
			})
		end
	end
	return out
end

local function buildQuestChildren(parentKey)
	local groupIDs = C_LFGList.GetAvailableActivityGroups(GF.CAT_QUEST, PVE) or {}
	local children = {}
	for _, groupID in ipairs(groupIDs) do
		local gName = select(1, C_LFGList.GetActivityGroupInfo(groupID))
		local acts = {}
		addActivityLeaves(parentKey .. "_q" .. groupID, 2, GF.CAT_QUEST, groupID, 0, PVE, acts)
		if #acts > 0 then
			children[#children + 1] = node(parentKey .. "_q" .. groupID, 1, gName or ("Group " .. groupID), {
				categoryID = GF.CAT_QUEST,
				filters = 0,
				preferredFilters = PVE,
				groupID = groupID,
				children = acts,
			})
		end
	end
	return children
end

local function buildCustomChildren(parentKey)
	local function customActivityNavLabel(info)
		if not info then
			return "?"
		end
		local name = info.fullName or info.shortName
		if name and name ~= "" then
			return name
		end
		return activityLabel(info)
	end

	local function customPreferredFilters(info)
		local filters = info and info.filters or 0
		if info and (info.isPvpActivity or bit.band(filters, Enum.LFGListFilter.PvP) ~= 0) then
			return Enum.LFGListFilter.PvP
		end
		return PVE
	end

	local children = {}
	local seen = {}
	local filterSets = { PVE, Enum.LFGListFilter.PvP, 0 }
	for _, preferred in ipairs(filterSets) do
		local activities = getAvailableActivitiesCached(GF.CAT_CUSTOM, nil, preferred) or {}
		for _, actID in ipairs(activities) do
			if not seen[actID] then
				seen[actID] = true
				local info = C_LFGList.GetActivityInfoTable(actID)
				if info then
					children[#children + 1] = leaf(parentKey .. "_a" .. actID, 1, customActivityNavLabel(info), {
						orderIndex = info.orderIndex,
						categoryID = GF.CAT_CUSTOM,
						filters = info.filters or 0,
						preferredFilters = customPreferredFilters(info),
						searchFilters = 0,
						searchPreferredFilters = 0,
						activityID = actID,
						activityInfo = info,
					})
				end
			end
		end
	end
	sortLeaves(children)
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
	elseif n.lazyKind == "delve_open" then
		n.children = buildDelveOpenBranches(n.key, 2)
		n.childrenLoaded = true
	elseif (n.lazyKind == "archive_expansion" or n.lazyKind == "delve_legacy") and n.catalogKind and n.expansionIndex then
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

local function refreshDelveOpenBranch(root)
	if not root or not root.children then
		return
	end
	local curExp = currentExpansionIndex()
	for _, child in ipairs(root.children) do
		if child.navKind == "delve_open" or child.expansionIndex == curExp then
			child.label = expansionLabel(curExp)
			child.expansionIndex = curExp
			if child.childrenLoaded then
				child.children = buildDelveOpenBranches(child.key, 2)
			end
		end
	end
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
			refreshDelveOpenBranch(root)
			rebuilt = true
		end
	end
	return rebuilt
end

-- 活动可用性变化时仅重建 API 驱动的分支；归档 catalog 分支等用户展开时再懒加载（见 EnsureChildren）。
local AVAIL_REFRESH_LAZY = {
	season_dungeon = true,
	season_raid = true,
	delve_open = true,
	custom_l0 = true,
}

local function refreshExpandedCatalog(nodes, expanded)
	local rebuilt = false
	for _, n in ipairs(nodes or {}) do
		if expanded[n.key] and n.childrenLoaded and n.lazyKind and AVAIL_REFRESH_LAZY[n.lazyKind] then
			GF.NavData.InvalidateScopeCache(n)
			if n.lazyKind == "delve_open" then
				n.children = buildDelveOpenBranches(n.key, 2)
			elseif n.lazyKind == "season_dungeon" then
				n.children = buildSeasonDungeonChildren(n.key)
			elseif n.lazyKind == "season_raid" then
				n.children = buildSeasonRaidChildren(n.key)
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
		filters = Enum.LFGListFilter.PvP,
		preferredFilters = Enum.LFGListFilter.PvP,
		childrenLoaded = false,
	})

	tree[#tree + 1] = node("quest", 0, L.NAV_QUEST or "Quests", {
		navKind = "quest",
		lazyKind = "quest_l0",
		categoryID = GF.CAT_QUEST,
		preferredFilters = PVE,
		childrenLoaded = false,
	})

	tree[#tree + 1] = node("custom", 0, L.NAV_CUSTOM or "Custom", {
		navKind = "custom",
		lazyKind = "custom_l0",
		categoryID = GF.CAT_CUSTOM,
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
			local listFilters = inst.listFilters or meta.baseFilters or 0
			local acts = getCatalogGroupActivityIDs(categoryID, inst.groupID, listFilters, preferred)
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

local function collectDelveOpenActivityIDs()
	local openF = bit.bor(Enum.LFGListFilter.CurrentExpansion, PVE)
	local categoryID = GF.CAT_DELVE
	local seen = {}
	local ids = {}
	local groups = C_LFGList.GetAvailableActivityGroups(categoryID, openF) or {}
	for _, groupID in ipairs(groups) do
		mergeActivityIDsInto(getAvailableActivitiesCached(categoryID, groupID, openF), ids, seen)
	end
	if #ids == 0 then
		mergeActivityIDsInto(getAvailableActivitiesCached(categoryID, nil, openF), ids, seen)
	end
	if #ids > 0 then
		return ids
	end
	return nil
end

local function collectDelveL0ActivityIDs()
	local seen = {}
	local ids = {}
	mergeActivityIDsInto(collectDelveOpenActivityIDs(), ids, seen)
	if GF.NavCatalog then
		for _, exp in ipairs(GF.NavCatalog.GetExpansions("delve")) do
			mergeActivityIDsInto(collectCatalogExpansionActivityIDs("delve", exp.expansionIndex), ids, seen)
		end
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
	local preferredFilters = source.searchPreferredFilters
	if preferredFilters == nil then
		preferredFilters = source.preferredFilters or PVE
	end
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
	local filters = GF.Filter and GF.Filter:ResolveCategoryFilters(categoryID, rawFilters) or rawFilters
	local preferredFilters = n.searchPreferredFilters
	if preferredFilters == nil then
		preferredFilters = n.preferredFilters or PVE
	end
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

	if forSearch and (n.lazyKind == "archive_expansion" or n.lazyKind == "delve_legacy")
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
