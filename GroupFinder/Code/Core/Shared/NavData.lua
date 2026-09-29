local _, GF = ...

-- NavigationProjection is GroupFinder's only owner of projected navigation
-- nodes, the published tree, and lazy branch materialization.  NavData remains
-- an identity alias because UI and extension code used that name before this
-- boundary was made explicit.
local Projection = GF.NavigationProjection or GF.NavData or {}
GF.NavigationProjection = Projection
GF.NavData = Projection

-- Keep the historical global tree as a read-only compatibility mirror.  All
-- code in this module reads the private state, so an unrelated writer cannot
-- silently replace the projection's authoritative tree.
local projectionState = {
	tree = type(GF.navTree) == "table" and GF.navTree or nil,
	paths = {},
}
GF.navTree = projectionState.tree

local preparation = { generation = 0, jobs = {}, isolated = false }
local activePreparation
local function preparationCheckpoint()
	if activePreparation and GetTimePreciseSec() - activePreparation.sliceStart >= 0.0003 then
		coroutine.yield()
	end
end

local function publishTree(tree)
	projectionState.tree = tree
	projectionState.paths = {}
	GF.navTree = tree
	return tree
end

local function currentTree()
	return projectionState.tree
end

local PVE = Enum.LFGListFilter.PvE
local PVP = Enum.LFGListFilter.PvP
local NOT_RECOMMENDED = Enum.LFGListFilter.NotRecommended
local CURRENT_EXPANSION = Enum.LFGListFilter.CurrentExpansion
local NOT_CURRENT_SEASON = Enum.LFGListFilter.NotCurrentSeason

-- RuntimeDirectory is an input port, not another catalog.  It reads Blizzard's
-- current availability through one protected-call boundary; NavCatalog remains
-- the owner of stable directory facts.  In particular, every activity-list
-- read below passes through the projection cache before it can shape nodes.
local RuntimeDirectory = {}

function RuntimeDirectory.HasMethod(methodName)
	return type(C_LFGList and C_LFGList[methodName]) == "function"
end

function RuntimeDirectory.Call(methodName, ...)
	local api = C_LFGList
	local method = api and api[methodName]
	if type(method) ~= "function" then
		return false
	end
	return pcall(method, ...)
end

local DIFFICULTY_LABEL_KEY = {
	world = "DIFF_WORLD",
	normal = "DIFF_NORMAL",
	heroic = "DIFF_HEROIC",
	mythic = "DIFF_MYTHIC",
	mplus = "DIFF_MYTHIC_PLUS",
}

local DIFFICULTY_LABEL_FALLBACK = {
	world = "World",
	normal = "Normal",
	heroic = "Heroic",
	mythic = "Mythic",
	mplus = "Mythic Keystone",
}

local function makeNavNode(key, level, label, extra, isLeaf)
	local result = {
		key = key,
		level = level,
		label = label,
		children = nil,
		isLeaf = isLeaf == true,
	}
	for field, value in pairs(extra or {}) do
		result[field] = value
	end
	if isLeaf then
		result.isLeaf = true
	end
	return result
end

local function node(key, level, label, extra)
	return makeNavNode(key, level, label, extra, false)
end

local function leaf(key, level, label, extra)
	return makeNavNode(key, level, label, extra, true)
end

local function expansionLabel(expansionIndex)
	local resolved = type(GetExpansionName) == "function" and GetExpansionName(expansionIndex)
	if type(resolved) == "string" and resolved ~= "" then
		return resolved
	end
	return ("Expansion %d"):format(expansionIndex)
end

local function currentExpansionIndex()
	return type(GetServerExpansionLevel) == "function" and GetServerExpansionLevel() or 11
end

local function activityLabel(info)
	local provider = GF.ActivityInfo and GF.ActivityInfo.GetActivityLeafLabel
	return type(provider) == "function" and provider(info) or "?"
end

local function concreteActivityLabel(info)
	if type(info) == "table" then
		if type(info.shortName) == "string" and info.shortName ~= "" then
			return info.shortName
		end
		if type(info.fullName) == "string" and info.fullName ~= "" then
			return info.fullName
		end
	end
	return activityLabel(info)
end

local function fullActivityLabel(info)
	if type(info) == "table" then
		if type(info.fullName) == "string" and info.fullName ~= "" then
			return info.fullName
		end
		if type(info.shortName) == "string" and info.shortName ~= "" then
			return info.shortName
		end
	end
	return activityLabel(info)
end

local function fullActivityMergeKey(info)
	if type(info) == "table" and type(info.fullName) == "string" and info.fullName ~= "" then
		return "full:" .. info.fullName
	end
	return nil
end

local function delveFullActivityLabel(info)
	local fullName = fullActivityLabel(info)
	local activityInfo = GF.ActivityInfo
	local getTierNumber = activityInfo and activityInfo.GetDelveTierNumber
	local getTierLabel = activityInfo and activityInfo.GetDelveTierLabel
	if type(getTierNumber) ~= "function" or type(getTierLabel) ~= "function" then
		return fullName
	end
	local tier = getTierNumber(info)
	if not tier then
		return fullName
	end
	local fullNameTier = getTierNumber({
		categoryID = info and info.categoryID,
		fullName = info and info.fullName,
	})
	if fullNameTier == tier then
		return fullName
	end
	local baseName = type(info.fullName) == "string"
		and (info.fullName:match("^(.+)%s*%([^()]+%)$")
			or info.fullName:match("^(.+)%s*（.+）$"))
	if type(baseName) == "string" then
		baseName = baseName:gsub("^%s+", ""):gsub("%s+$", "")
	end
	local tierLabel = getTierLabel(info)
	if not (baseName and tierLabel) then
		return fullName
	end
	local fullNameUsesWideParentheses = type(info.fullName) == "string"
		and info.fullName:find("（", 1, true) ~= nil
	local formatString = fullNameUsesWideParentheses and "%s（%s）"
		or ((GF.L or {}).NAV_ACTIVITY_DIFFICULTY_FMT or "%s (%s)")
	return string.format(formatString, baseName, tierLabel)
end

local function delveActivityMergeKey(info)
	local activityInfo = GF.ActivityInfo
	local getTierNumber = activityInfo and activityInfo.GetDelveTierNumber
	local tier = type(getTierNumber) == "function" and getTierNumber(info)
	if not tier then
		return fullActivityMergeKey(info)
	end
	return string.format("delve:%s:tier:%s:label:%s",
		tostring(info and info.groupFinderActivityGroupID or 0),
		tostring(tier), delveFullActivityLabel(info))
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

local function catalogSoloActivityName(info)
	if type(info) == "table" then
		if type(info.fullName) == "string" and info.fullName ~= "" then
			return info.fullName
		end
		if type(info.shortName) == "string" and info.shortName ~= "" then
			return info.shortName
		end
	end
	return catalogDungeonName(info)
end

local function cleanText(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return value
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

local function addLabelCandidate(out, seen, value)
	value = trimText(value)
	if not value or seen[value] then
		return
	end
	seen[value] = true
	out[#out + 1] = value
end

local function difficultyLabelCandidates()
	local labels = {}
	local seen = {}
	local L = GF.L or {}
	for _, labelKey in pairs(DIFFICULTY_LABEL_KEY) do
		addLabelCandidate(labels, seen, L[labelKey])
	end
	for _, fallback in pairs(DIFFICULTY_LABEL_FALLBACK) do
		addLabelCandidate(labels, seen, fallback)
	end
	addLabelCandidate(labels, seen, "M+")
	addLabelCandidate(labels, seen, "Mythic+")
	addLabelCandidate(labels, seen, "Mythic Keystone")
	addLabelCandidate(labels, seen, "Mythic Keystone Dungeon")
	addLabelCandidate(labels, seen, "World")
	addLabelCandidate(labels, seen, "世界")
	addLabelCandidate(labels, seen, "普通")
	addLabelCandidate(labels, seen, "英雄")
	addLabelCandidate(labels, seen, "史诗")
	addLabelCandidate(labels, seen, "傳奇")
	addLabelCandidate(labels, seen, "史诗钥石")
	addLabelCandidate(labels, seen, "傳奇鑰石")
	addLabelCandidate(labels, seen, "史诗钥石地下城")
	addLabelCandidate(labels, seen, "傳奇鑰石地城")
	return labels
end

local function stripKnownDifficultySuffix(value)
	value = trimText(value)
	if not value then
		return nil
	end
	for _, label in ipairs(difficultyLabelCandidates()) do
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

local function normalizedNodeKey(value)
	value = trimText(value)
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

local function isWorldDifficultyLabel(value)
	value = trimText(value)
	if not value then
		return false
	end
	local suffix = value:match("（([^（）]+)）%s*$")
		or value:match("%(([^()]+)%)%s*$")
	local candidate = trimText(suffix) or value
	local normalized = normalizedNodeKey(candidate)
	if not normalized then
		return false
	end
	local L = GF.L or {}
	for _, label in ipairs({ L.DIFF_WORLD, "World", "世界" }) do
		if normalized == normalizedNodeKey(label) then
			return true
		end
	end
	return false
end

local function isWorldDifficultyActivity(info)
	return type(info) == "table"
		and (isWorldDifficultyLabel(info.shortName)
			or isWorldDifficultyLabel(info.fullName))
end

local function catalogSoloBaseName(info, labelOverride)
	local label = labelOverride or catalogSoloActivityName(info)
	label = stripKnownDifficultySuffix(label)
	return label or catalogSoloActivityName(info) or "?"
end

local function activityDifficultyDisplayLabel(info)
	local tier = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyTier
		and GF.ActivityInfo.GetDifficultyTier(info, { includeMplus = true })
	if not tier and isWorldDifficultyActivity(info) then
		tier = "world"
	end
	local L = GF.L or {}
	if tier then
		local labelKey = DIFFICULTY_LABEL_KEY[tier]
		return (labelKey and L[labelKey]) or DIFFICULTY_LABEL_FALLBACK[tier] or activityLabel(info)
	end
	local delveLabel = GF.ActivityInfo and GF.ActivityInfo.GetDelveTierLabel and GF.ActivityInfo.GetDelveTierLabel(info)
	if delveLabel then
		return delveLabel
	end
	if info and (info.categoryID == GF.CAT_DUNGEON or info.categoryID == GF.CAT_RAID) then
		return L.DIFF_NORMAL or DIFFICULTY_LABEL_FALLBACK.normal
	end
	return activityLabel(info)
end

local function activityDifficultySortIndex(info)
	local difficultyIndex = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyIndex
		and GF.ActivityInfo.GetDifficultyIndex(info, { includeMplus = true }) or 0
	if difficultyIndex and difficultyIndex > 0 then
		local playerCount = GF.ActivityInfo.GetDifficultyPlayerCount and GF.ActivityInfo.GetDifficultyPlayerCount(info)
		if playerCount and playerCount > 0 then
			return (playerCount * 100) + difficultyIndex
		end
		return difficultyIndex * 100
	end
	local delveTier = GF.ActivityInfo and GF.ActivityInfo.GetDelveTierNumber and GF.ActivityInfo.GetDelveTierNumber(info)
	if delveTier then
		return delveTier
	end
	return 100
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
	local function leafComesBefore(left, right)
		local leftOrder, rightOrder = leafSortIndex(left), leafSortIndex(right)
		if leftOrder ~= rightOrder then
			return leftOrder < rightOrder
		end
		return tostring(left and left.label or "") < tostring(right and right.label or "")
	end
	table.sort(leaves, leafComesBefore)
end

local function concreteActivityBaseKey(info, activityID)
	local baseName = GF.ActivityInfo and GF.ActivityInfo.GetActivityBaseName
		and GF.ActivityInfo.GetActivityBaseName(info)
	baseName = trimText(baseName)
	if type(baseName) == "string" and baseName ~= "" then
		return string.lower(baseName)
	end
	local label = trimText(concreteActivityLabel(info))
	if label and label ~= "?" then
		return string.lower(label)
	end
	return "activity:" .. tostring(activityID or 0)
end

local function concreteActivityDifficultyOrder(info)
	local difficultyIndex = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyIndex
		and GF.ActivityInfo.GetDifficultyIndex(info, { includeMplus = true }) or 0
	difficultyIndex = tonumber(difficultyIndex) or 0
	if difficultyIndex <= 1 then
		return 1
	end
	if difficultyIndex == 2 then
		return 2
	end
	if difficultyIndex == 3 then
		return 3
	end
	return 4
end

local CONCRETE_SORT_FIELDS = { "baseOrder", "difficultyOrder", "sourceOrder" }
local function sortConcreteActivityLeaves(leaves, sortMeta)
	local function comesBefore(left, right)
		local leftMeta, rightMeta = sortMeta[left], sortMeta[right]
		if leftMeta == nil or rightMeta == nil then
			if leftMeta ~= rightMeta then
				return leftMeta ~= nil
			end
			return (tonumber(left and left.activityID) or 0) < (tonumber(right and right.activityID) or 0)
		end
		local fields = CONCRETE_SORT_FIELDS
		for index = 1, #fields do
			local field = fields[index]
			if leftMeta[field] ~= rightMeta[field] then
				return leftMeta[field] < rightMeta[field]
			end
		end
		return (tonumber(left and left.activityID) or 0) < (tonumber(right and right.activityID) or 0)
	end
	table.sort(leaves, comesBefore)
end

local buildCache = {
	groupInfo = {},
	activityLists = {},
	activityInfo = {},
}

local function emptyTable(target)
	for key in pairs(target) do
		target[key] = nil
	end
end

local function clearNavBuildCaches()
	preparation.generation = preparation.generation + 1
	local requested = preparation.jobs
	preparation.jobs = {}
	if preparation.frame then preparation.frame:Hide() end
	emptyTable(buildCache.groupInfo)
	emptyTable(buildCache.activityLists)
	emptyTable(buildCache.activityInfo)
	local clearCatalog = GF.NavCatalog and GF.NavCatalog.ClearRuntimeCache
	if type(clearCatalog) == "function" then
		clearCatalog()
	end
	-- Release the obsolete projection even when the main window is hidden.
	-- Invalidation alone is not demand to construct another complete quest tree.
	for _, root in ipairs(currentTree() or {}) do
		if root.lazyKind == "quest_l0" then
			root.children, root.childrenLoaded, root._questBuildGeneration = nil, false, nil
			Projection.InvalidateScopeCache(root)
			if requested[root] then Projection.RequestChildren(root) end
		end
	end
end

function Projection.ClearBuildCaches()
	return clearNavBuildCaches()
end

function Projection.InvalidateScopeCache(n)
	projectionState.paths = {}
	local compiler = GF.SearchScopeCompiler
	local invalidate = compiler and compiler.InvalidateNode
	return type(invalidate) == "function" and invalidate(n) or false
end

local function activityGroupInfoForID(groupID)
	if groupID == nil then
		return nil
	end
	local known = buildCache.groupInfo[groupID]
	if known ~= nil then
		return known ~= false and known or nil
	end
	local ok, name, orderIndex = RuntimeDirectory.Call(
		"GetActivityGroupInfo", groupID)
	local resolved = ok and type(name) == "string" and name ~= ""
		and { name = name, orderIndex = orderIndex } or false
	buildCache.groupInfo[groupID] = resolved
	return resolved ~= false and resolved or nil
end

local function groupDisplayName(groupID)
	local info = activityGroupInfoForID(groupID)
	return info and info.name or nil
end

local function activityCacheKey(categoryID, groupID, filterFlags)
	local groupPart = groupID == nil and "*" or tostring(groupID)
	return table.concat({ tostring(categoryID or 0), groupPart, tostring(filterFlags or 0) }, ":")
end

local function getAvailableActivitiesCached(categoryID, groupID, filterFlags)
	local cacheKey = activityCacheKey(categoryID, groupID, filterFlags)
	local known = buildCache.activityLists[cacheKey]
	if known then
		return known
	end
	local ok, values = RuntimeDirectory.Call(
		"GetAvailableActivities", categoryID, groupID, filterFlags or 0)
	if not ok or type(values) ~= "table" then return {} end
	known = values
	buildCache.activityLists[cacheKey] = known
	return known
end

local function activityInfoForID(activityID)
	if activityID == nil then
		return nil
	end
	local known = buildCache.activityInfo[activityID]
	if known then return known end
	local ok, info = RuntimeDirectory.Call("GetActivityInfoTable", activityID)
	if not ok or type(info) ~= "table" then return nil end
	-- Failed/incomplete reads remain retryable. Snapshot mutable API tables;
	-- this cache supplies metadata only, never availability authorization.
	if type(info.categoryID) ~= "number" or tonumber(info.groupFinderActivityGroupID) == nil
		or type(info.fullName) ~= "string"
		or info.fullName == "" then return info end
	local snapshot = {}
	for key, value in pairs(info) do snapshot[key] = value end
	buildCache.activityInfo[activityID] = snapshot
	return snapshot
end

local function getAvailableCategories(filterFlags)
	local ok, categories = RuntimeDirectory.Call(
		"GetAvailableCategories", filterFlags or 0)
	if ok and type(categories) == "table" then
		return categories
	end
	return nil
end

local function getAvailableActivityGroups(categoryID, filterFlags)
	local ok, groups = RuntimeDirectory.Call(
		"GetAvailableActivityGroups", categoryID, filterFlags or 0)
	return ok and type(groups) == "table" and groups or {}
end

local function getLfgCategoryLabel(categoryID)
	local ok, info = RuntimeDirectory.Call("GetLfgCategoryInfo", categoryID)
	if ok and type(info) == "table" and info.name and info.name ~= "" then
		return info.name
	end
	return string.format("Category %d", categoryID or 0)
end

local function getCatalogGroupActivityIDs(categoryID, groupID, listFilters, preferred, options)
	options = options or {}
	local enumFilters = preferred or PVE
	local listFilterBits = listFilters and listFilters ~= 0 and bit.bor(listFilters, enumFilters) or nil
	local activities
	if listFilterBits then
		activities = getAvailableActivitiesCached(categoryID, groupID, listFilterBits)
		if #activities == 0 and groupID == nil then
			activities = getAvailableActivitiesCached(categoryID, 0, listFilterBits)
		end
	end
	if options.exactFilters == true then
		return activities or {}
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
	return GF.SearchScopeCompiler.NormalizeFilters(categoryID, filters)
end

local function addActivityLeaves(parentKey, level, categoryID, groupID, listFilters, preferred, out, opts)
	opts = opts or {}
	local preserveActivityIdentity = opts.preserveActivityIdentity == true
	local useFullActivityLabel = opts.useFullActivityLabel == true
	local useDelveTierIdentity = opts.useDelveTierIdentity == true
	local sortByBaseActivity = preserveActivityIdentity and opts.sortByBaseActivity == true
	local useActivityFilters = opts.useActivityFilters == true
	local activities = type(opts.activityIDs) == "table" and opts.activityIDs
		or getCatalogGroupActivityIDs(categoryID, groupID, listFilters, preferred, opts)
	local activityInfoByID = type(opts.activityInfoByID) == "table"
		and opts.activityInfoByID or nil
	local activityInfoPredicate = opts.activityInfoPredicate
	local filters = listFilters or 0
	local seenActivityIDs = {}
	local leavesByMergeKey = {}
	local concreteActivitySortMeta = sortByBaseActivity and {} or nil
	local concreteActivityBaseOrder = sortByBaseActivity and {} or nil

	local function addMergedActivityID(n, activityID, activityFilters)
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
		if useActivityFilters and activityFilters ~= nil then
			n.activitySearchFiltersByID = n.activitySearchFiltersByID or {}
			n.activitySearchFiltersByID[activityID] = activityFilters
		end
	end

	for sourceOrder, actID in ipairs(activities) do
		preparationCheckpoint()
		if not seenActivityIDs[actID] then
			seenActivityIDs[actID] = true
			-- NavCatalog already validated verified-snapshot activities against the
			-- current native availability generation. Reuse those shallow snapshots:
			-- GetActivityInfoTable is MayReturnNothing and a second transient nil must
			-- not erase an already-authorized difficulty leaf.
			local info = activityInfoByID and activityInfoByID[actID]
				or activityInfoForID(actID)
			if info and (not activityInfoPredicate or activityInfoPredicate(info)) then
				local activityFilters = useActivityFilters and tonumber(info.filters) or nil
				local childFilters = activityFilters ~= nil and activityFilters or filters
				local label = useDelveTierIdentity and delveFullActivityLabel(info)
					or preserveActivityIdentity and concreteActivityLabel(info)
					or useFullActivityLabel and fullActivityLabel(info)
					or activityLabel(info)
				local mergeKey
				if not preserveActivityIdentity then
					-- A full activity label identifies both the activity and its variant.
					-- Merging these leaves by difficulty alone can collapse unrelated PvP
					-- activities, so only identical Blizzard fullName values may merge.
					if useDelveTierIdentity then
						mergeKey = delveActivityMergeKey(info)
					elseif useFullActivityLabel then
						mergeKey = fullActivityMergeKey(info)
					else
						mergeKey = activityDifficultyMergeKey(info)
					end
				end
				local existing = mergeKey and leavesByMergeKey[mergeKey]
				if existing then
					addMergedActivityID(existing, actID, activityFilters)
				else
					local fields = {
						orderIndex = info.orderIndex,
						sortIndex = activitySortIndex(info),
						categoryID = categoryID,
						filters = childFilters,
						searchFilters = normalizeSearchFilters(categoryID, childFilters),
						preferredFilters = preferred,
						groupID = groupID or info.groupFinderActivityGroupID,
						activityID = actID,
						activityInfo = info,
					}
					if useActivityFilters and activityFilters ~= nil then
						fields.activitySearchFiltersByID = { [actID] = activityFilters }
					end
					local child = leaf(
						string.format("%s_a%d", parentKey, actID),
						level,
						label,
						fields
					)
					if mergeKey then
						leavesByMergeKey[mergeKey] = child
					end
					if concreteActivitySortMeta then
						-- Keep each base activity at its first native source position; only reorder its variants.
						local baseKey = concreteActivityBaseKey(info, actID)
						local baseOrder = concreteActivityBaseOrder[baseKey]
						if not baseOrder then
							baseOrder = sourceOrder
							concreteActivityBaseOrder[baseKey] = baseOrder
						end
						concreteActivitySortMeta[child] = {
							baseOrder = baseOrder,
							difficultyOrder = concreteActivityDifficultyOrder(info),
							sourceOrder = sourceOrder,
						}
					end
					out[#out + 1] = child
				end
			end
		end
	end
	for _, child in ipairs(out) do
		child._gfMergedActivityIDSeen = nil
	end
	if concreteActivitySortMeta then
		sortConcreteActivityLeaves(out, concreteActivitySortMeta)
	else
		sortLeaves(out)
	end
end

local function buildGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred, opts)
	local branchLabel = cleanText(opts and opts.branchLabel) or groupDisplayName(groupID)
	if branchLabel == nil then
		return nil
	end
	local filters = listFilters or 0
	local branchIdentity = opts and opts.branchIdentity or groupID
	local branchKey = ("%s_g%s"):format(parentKey, tostring(branchIdentity))
	local children = {}
	addActivityLeaves(branchKey, level + 1, categoryID, groupID, filters, preferred, children, opts)
	if #children == 0 then
		return nil
	end
	local onlyChild = children[1]
	local mayCollapse = #children == 1 and not (opts and opts.forceBranch)
	if mayCollapse and onlyChild.activityInfo and not activityHasDifficultyTier(onlyChild.activityInfo) then
		onlyChild.level = level
		onlyChild.label = branchLabel
		onlyChild.expandPrefixPlaceholder = true
		return onlyChild
	end
	local fields = {
		categoryID = categoryID,
		filters = filters,
		searchFilters = normalizeSearchFilters(categoryID, filters),
		preferredFilters = preferred,
		groupID = groupID,
		children = children,
	}
	return node(branchKey, level, branchLabel, fields)
end

local FORCE_GROUP_BRANCH = { forceBranch = true }

local function catalogGroupActivity(info, categoryID)
	return info and info.categoryID == categoryID and activityHasDifficultyTier(info)
end

local function catalogGroupActivityIDs(source, categoryID)
	local activityIDs, activityFiltersByID = {}, {}
	for _, activityID in ipairs(source or {}) do
		local info = activityInfoForID(activityID)
		if catalogGroupActivity(info, categoryID) then
			activityIDs[#activityIDs + 1] = activityID
			activityFiltersByID[activityID] = tonumber(info.filters)
		end
	end
	return activityIDs, activityFiltersByID
end

local function buildForcedGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred, instance)
	if (categoryID == GF.CAT_DUNGEON or categoryID == GF.CAT_RAID)
		and type(instance) == "table"
	then
		local activityIDs, activityFiltersByID = catalogGroupActivityIDs(instance.activityIDs, categoryID)
		local function activityPredicate(info)
			return catalogGroupActivity(info, categoryID)
		end
		local branch = buildGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred, {
			forceBranch = true,
			branchLabel = instance.label,
			activityIDs = activityIDs,
			activityInfoPredicate = activityPredicate,
			useActivityFilters = true,
			useFullActivityLabel = true,
		})
		if branch then
			-- Parent searches and difficulty leaves must consume the same complete
			-- unioned runtime set instead of re-enumerating a narrow filter.
			branch.activityIDsFilter = activityIDs
			branch.activitySearchFiltersByID = activityFiltersByID
		end
		return branch
	end
	return buildGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred, FORCE_GROUP_BRANCH)
end

local function buildVerifiedSnapshotBranch(
	parentKey,
	level,
	categoryID,
	listFilters,
	preferred,
	instance
)
	local activityIDs, activityFiltersByID = {}, {}
	for _, activityID in ipairs(instance and instance.activityIDs or {}) do
		local info = instance.activityInfoByID
			and instance.activityInfoByID[activityID]
			or activityInfoForID(activityID)
		if info and tonumber(info.categoryID) == tonumber(categoryID) then
			activityIDs[#activityIDs + 1] = activityID
			activityFiltersByID[activityID] = tonumber(info.filters)
		end
	end
	if #activityIDs == 0 then
		return nil
	end
	local function activityPredicate(info)
		return info and tonumber(info.categoryID) == tonumber(categoryID)
	end
	local branch = buildGroupBranch(
		parentKey,
		level,
		categoryID,
		nil,
		listFilters,
		preferred,
		{
			forceBranch = true,
			branchLabel = instance.label,
			activityIDs = activityIDs,
			activityInfoByID = instance.activityInfoByID,
			activityInfoPredicate = activityPredicate,
			useActivityFilters = true,
			useFullActivityLabel = true,
		}
	)
	if branch then
		-- A verified parent may span several Blizzard group IDs (notably Eternal
		-- Dawn and Operation: Mechagon). Keep one human-facing parent while each
		-- leaf retains its own native group/activity identity.
		branch.activityIDsFilter = activityIDs
		branch.activitySearchFiltersByID = activityFiltersByID
		branch.fallbackSnapshot = true
	end
	return branch
end

local function stampNavKind(n, navKind)
	local pending = n and { n } or {}
	while #pending > 0 do
		local current = table.remove(pending)
		current.navKind = navKind
		for _, child in ipairs(current.children or {}) do
			pending[#pending + 1] = child
		end
	end
end

local SEASON_DIFFICULTY_ORDER = {
	world = 1,
	normal = 2,
	heroic = 3,
	mythic = 4,
	mplus = 5,
}

local seasonDungeonPresentationState = "loading"

local function playerAtEffectiveMaxLevel()
	if type(IsPlayerAtEffectiveMaxLevel) == "function" then
		local ok, value = pcall(IsPlayerAtEffectiveMaxLevel)
		if ok and type(value) == "boolean" then
			return value
		end
	end
	local getEffectiveMaxLevel = GameRulesUtil
		and GameRulesUtil.GetEffectiveMaxLevelForPlayer
	if type(UnitLevel) ~= "function" or type(getEffectiveMaxLevel) ~= "function" then
		return nil
	end
	local ok, level, maximum = pcall(function()
		return UnitLevel("player"), getEffectiveMaxLevel()
	end)
	if not ok or type(level) ~= "number" or type(maximum) ~= "number"
		or level <= 0 or maximum <= 0
	then
		return nil
	end
	return level >= maximum
end

local function activityDirectoryLoaded()
	if not RuntimeDirectory.HasMethod("HasActivityList") then
		-- The addon still supports a client boundary where this helper may be
		-- absent. Existing availability calls remain the best evidence there.
		return true
	end
	local ok, loaded = RuntimeDirectory.Call("HasActivityList")
	return ok and loaded == true
end

local function activityDifficultyTier(info)
	if isWorldDifficultyActivity(info) then
		return "world"
	end
	local getTier = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyTier
	if type(getTier) == "function" then
		local tier = getTier(info, { includeMplus = true })
		if SEASON_DIFFICULTY_ORDER[tier] then
			return tier
		end
	end
	if info and info.isMythicPlusActivity == true then
		return "mplus"
	elseif info and info.isMythicActivity == true then
		return "mythic"
	elseif info and info.isHeroicActivity == true then
		return "heroic"
	elseif info and info.isNormalActivity == true then
		return "normal"
	end
	return nil
end

local function collectSeasonInstanceActivities(instance, categoryID)
	local activityIDs, seen = {}, {}
	local function add(activityID)
		activityID = tonumber(activityID)
		if not activityID or seen[activityID] then
			return
		end
		local info = activityInfoForID(activityID)
		if not (info and tonumber(info.categoryID) == tonumber(categoryID)) then
			return
		end
		seen[activityID] = true
		activityIDs[#activityIDs + 1] = activityID
	end
	add(instance and instance.activityID)
	for _, activityID in ipairs(instance and instance.activityIDs or {}) do
		add(activityID)
	end
	return activityIDs
end

local function partitionSeasonDungeonActivities(instance)
	local standard, mythicPlus = {}, {}
	for _, activityID in ipairs(collectSeasonInstanceActivities(instance, GF.CAT_DUNGEON)) do
		local info = activityInfoForID(activityID)
		local tier = activityDifficultyTier(info)
		if tier == "mplus" then
			mythicPlus[#mythicPlus + 1] = activityID
		elseif tier == "normal" or tier == "heroic" or tier == "mythic" then
			standard[#standard + 1] = activityID
		end
	end
	return standard, mythicPlus
end

local function resolveSeasonDungeonPresentationState(instances)
	if type(instances) ~= "table" or #instances == 0 then
		return "loading"
	end
	if not activityDirectoryLoaded() then
		return "activity_loading"
	end
	local allHaveMythicPlus, anyAvailable = true, false
	for _, instance in ipairs(instances) do
		local standard, mythicPlus = partitionSeasonDungeonActivities(instance)
		allHaveMythicPlus = allHaveMythicPlus and #mythicPlus > 0
		anyAvailable = anyAvailable or #standard > 0 or #mythicPlus > 0
	end
	if allHaveMythicPlus then
		return "mplus_open"
	elseif playerAtEffectiveMaxLevel() == false then
		return "level_limited"
	elseif anyAvailable then
		return "standard_open"
	end
	-- Ready Journal and empty LFG is a known roster with unavailable activities,
	-- regardless of server phase, character metadata or another dungeon's state.
	return "preseason"
end

local function seasonDifficultyLabel(instanceLabel, tier)
	local L = GF.L or {}
	local labelKey = DIFFICULTY_LABEL_KEY[tier]
	local difficulty = (labelKey and L[labelKey])
		or DIFFICULTY_LABEL_FALLBACK[tier]
		or tostring(tier)
	local formatString = L.NAV_ACTIVITY_DIFFICULTY_FMT or "%s (%s)"
	return string.format(formatString, instanceLabel or "?", difficulty)
end

local function seasonUnavailableReason()
	local L = GF.L or {}
	local atMaximum = playerAtEffectiveMaxLevel()
	if not activityDirectoryLoaded() then
		return L.NAV_ACTIVITY_DIRECTORY_LOADING or "Activity directory is loading."
	end
	if atMaximum == false then
		return L.NAV_ACTIVITY_LEVEL_REQUIRED or "The required level has not been reached."
	end
	return L.NAV_ACTIVITY_UNAVAILABLE or "This instance is not yet available."
end

local function seasonLoadingLeaf(parentKey, navKind)
	local L = GF.L or {}
	local label = L.NAV_LOADING or "Loading"
	return leaf(parentKey .. "_loading", 1, label, {
		navKind = navKind,
		disabled = true,
		navLoading = true,
		seasonUnavailable = true,
	})
end

local function disabledSeasonDifficultyLeaf(parentKey, level, instanceLabel, tier, reason, navKind)
	return leaf(parentKey .. "_" .. tier, level,
		seasonDifficultyLabel(instanceLabel, tier), {
			navKind = navKind,
			sortIndex = (SEASON_DIFFICULTY_ORDER[tier] or 9) * 100,
			disabled = true,
			disabledTooltip = true,
			disabledReason = reason,
			seasonUnavailable = true,
		})
end

local function copyActivityIDs(source)
	local out = {}
	for index, activityID in ipairs(source or {}) do
		out[index] = activityID
	end
	return out
end

local function buildSeasonDifficultyBranch(parentKey, level, categoryID, listFilters,
	preferred, instance, activityIDs, missingTiers, navKind, unavailableReason)
	local filters = listFilters or 0
	local label = (instance and instance.label)
		or groupDisplayName(instance and instance.groupID)
		or "?"
	local children = {}
	addActivityLeaves(parentKey, level + 1, categoryID,
		instance and instance.groupID, filters, preferred, children, {
			activityIDs = activityIDs,
			exactFilters = true,
			useActivityFilters = true,
			useFullActivityLabel = true,
		})
	local presentTiers = {}
	for _, child in ipairs(children) do
		child.navKind = navKind
		local tier = activityDifficultyTier(child.activityInfo)
		if tier then
			child.sortIndex = (SEASON_DIFFICULTY_ORDER[tier] or 9) * 100
			if not presentTiers[tier] then
				child.key = parentKey .. "_" .. tier
			else
				child.key = string.format("%s_%s_a%s", parentKey, tier,
					tostring(child.activityID or 0))
			end
			presentTiers[tier] = true
		end
	end
	local reason = unavailableReason or seasonUnavailableReason()
	for _, tier in ipairs(missingTiers or {}) do
		if not presentTiers[tier] then
			children[#children + 1] = disabledSeasonDifficultyLeaf(
				parentKey, level + 1, label, tier, reason, navKind)
		end
	end
	for _, child in ipairs(children) do
		child.challengeModeID = instance and instance.challengeModeID
		if navKind == "season_dungeon" and child.activityID
			and activityDifficultyTier(child.activityInfo) == "mplus" then
			child.seasonDungeonMythicPlus = true
		end
	end
	sortLeaves(children)
	local activityFiltersByID = {}
	for _, activityID in ipairs(activityIDs or {}) do
		local info = activityInfoForID(activityID)
		activityFiltersByID[activityID] = tonumber(info and info.filters)
	end
	local searchable = #activityIDs > 0
	return node(parentKey, level, label, {
		navKind = navKind,
		challengeModeID = instance and instance.challengeModeID,
		orderIndex = instance and instance.orderIndex,
		categoryID = searchable and categoryID or nil,
		filters = searchable and filters or nil,
		searchFilters = searchable and normalizeSearchFilters(categoryID, filters) or nil,
		preferredFilters = searchable and preferred or nil,
		groupID = searchable and instance and instance.groupID or nil,
		activityIDsFilter = searchable and copyActivityIDs(activityIDs) or nil,
		activitySearchFiltersByID = searchable and activityFiltersByID or nil,
		children = children,
	})
end

local function buildSeasonDungeonMythicPlusLeaf(parentKey, level, listFilters,
	preferred, instance)
	local _, activityIDs = partitionSeasonDungeonActivities(instance)
	local activityID = activityIDs[1]
	local info = activityInfoForID(activityID)
	if not (activityID and info) then
		return nil
	end
	local filters = listFilters or 0
	local activityFiltersByID = {}
	for _, candidateID in ipairs(activityIDs) do
		local candidateInfo = activityInfoForID(candidateID)
		activityFiltersByID[candidateID] = tonumber(candidateInfo and candidateInfo.filters)
	end
	return leaf(parentKey .. "_mplus", level,
		(instance and instance.label) or catalogDungeonName(info), {
			challengeModeID = instance and instance.challengeModeID,
			orderIndex = instance and instance.orderIndex or info.orderIndex,
			categoryID = GF.CAT_DUNGEON,
			filters = filters,
			searchFilters = normalizeSearchFilters(GF.CAT_DUNGEON, filters),
			preferredFilters = preferred,
			groupID = instance and instance.groupID,
			activityID = activityID,
			activityIDsFilter = copyActivityIDs(activityIDs),
			activitySearchFiltersByID = activityFiltersByID,
			activityInfo = info,
			navKind = "season_dungeon",
			seasonDungeonMythicPlus = true,
			expandPrefixPlaceholder = true,
		})
end

local function buildSeasonDungeonStandardBranch(parentKey, level, listFilters,
	preferred, instance, options)
	options = options or {}
	local standard = options.activityIDs
	if standard == nil then
		local mythicPlus
		standard, mythicPlus = partitionSeasonDungeonActivities(instance)
		for _, activityID in ipairs(mythicPlus) do
			standard[#standard + 1] = activityID
		end
	end
	local branch = buildSeasonDifficultyBranch(parentKey, level,
		GF.CAT_DUNGEON, listFilters, preferred, instance, standard,
		{ "normal", "heroic", "mythic", "mplus" }, "season_dungeon",
		options.unavailableReason)
	branch.seasonDungeonStandard = true
	return branch
end

local function buildSeasonRaidGroupBranch(parentKey, level, categoryID, groupID,
	listFilters, preferred, instance, navKind)
	local allAvailable = {}
	local hasWorldDifficulty = false
	local candidates = activityDirectoryLoaded()
		and collectSeasonInstanceActivities(instance, categoryID) or {}
	for _, activityID in ipairs(candidates) do
		local info = activityInfoForID(activityID)
		local tier = activityDifficultyTier(info)
		if tier == "world" or tier == "normal"
			or tier == "heroic" or tier == "mythic"
		then
			allAvailable[#allAvailable + 1] = activityID
			hasWorldDifficulty = hasWorldDifficulty or tier == "world"
		end
	end
	local activityIDs = allAvailable
	local missingTiers = { "normal", "heroic", "mythic" }
	if hasWorldDifficulty then
		table.insert(missingTiers, 1, "world")
	end
	local branch = buildSeasonDifficultyBranch(parentKey, level, categoryID,
		listFilters, preferred, instance, activityIDs,
		missingTiers, navKind or "season_raid")
	branch.groupID = #activityIDs > 0 and groupID or nil
	return branch
end

function Projection.GetSeasonDungeonPresentationState()
	return seasonDungeonPresentationState
end

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

local function buildSoloActivityBranch(parentKey, level, categoryID, entries, preferred)
	if not entries or #entries == 0 then
		return nil
	end
	local branchLabel = entries[1].baseLabel
	local branchOrderIndex = entries[1].orderIndex
	local parentFilters = entries[1].listFilters or 0
	local worldBossNode = false
	local children = {}
	local leavesByMergeKey = {}
	local seenActivityIDs = {}

	for _, entry in ipairs(entries) do
		local activityID = entry.activityID
		if activityID and not seenActivityIDs[activityID] then
			seenActivityIDs[activityID] = true
			local info = entry.info or activityInfoForID(activityID)
			if info then
				local filters = entry.listFilters or 0
				-- A real dungeon/raid activity's fullName identifies both the instance
				-- and its difficulty. Merging group-less activities by difficulty alone
				-- can append an unrelated Normal dungeon to the first Normal leaf in the
				-- bucket. Regional world-boss containers are the deliberate exception:
				-- their shared parent owns the instance identity, so difficulties merge.
				local useFullActivityIdentity = categoryID == GF.CAT_DUNGEON
					or (categoryID == GF.CAT_RAID and entry.worldBoss ~= true)
				local mergeKey = useFullActivityIdentity and fullActivityMergeKey(info)
					or activityDifficultyMergeKey(info)
				local existing = mergeKey and leavesByMergeKey[mergeKey]
				if existing then
					addMergedActivityID(existing, activityID)
				else
					local leafLabel = activityDifficultyDisplayLabel(info)
					-- Grouped dungeon/raid branches already expose Blizzard's full activity
					-- name. Do the same when Retail projects a real instance as a group-less
					-- activity so the terminal flyout keeps both instance and difficulty;
					-- world-boss containers remain the deliberate bare-difficulty exception
					-- because their parent label is rebuilt from the Encounter Journal region
					-- rather than activityInfo.fullName.
					if categoryID == GF.CAT_DUNGEON
						or (categoryID == GF.CAT_RAID and entry.worldBoss ~= true)
					then
						leafLabel = fullActivityLabel(info)
					end
					local child = leaf(parentKey .. "_a" .. activityID, level + 1, leafLabel, {
						orderIndex = info.orderIndex,
						sortIndex = activityDifficultySortIndex(info),
						categoryID = categoryID,
						filters = filters,
						searchFilters = normalizeSearchFilters(categoryID, filters),
						preferredFilters = preferred,
						groupID = info.groupFinderActivityGroupID,
						activityID = activityID,
						activityInfo = info,
					})
					if mergeKey then
						leavesByMergeKey[mergeKey] = child
					end
					children[#children + 1] = child
				end
				if entry.worldBoss then
					worldBossNode = true
				end
				if entry.orderIndex ~= nil and (not branchOrderIndex or entry.orderIndex < branchOrderIndex) then
					branchOrderIndex = entry.orderIndex
				end
			end
		end
	end
	for _, child in ipairs(children) do
		child._gfMergedActivityIDSeen = nil
	end
	if #children == 0 then
		return nil
	end
	sortLeaves(children)
	return node(parentKey, level, branchLabel or "?", {
		categoryID = categoryID,
		filters = parentFilters,
		searchFilters = normalizeSearchFilters(categoryID, parentFilters),
		preferredFilters = preferred,
		orderIndex = branchOrderIndex,
		worldBossNode = worldBossNode,
		children = children,
	})
end

local function addSoloCatalogEntry(
	soloGroups,
	soloOrder,
	categoryID,
	inst,
	activityID,
	listFilters,
	ordinal
)
	-- NavCatalog already validated the activity snapshot it exposes. Prefer that
	-- same snapshot instead of requiring a second API read to succeed in the same
	-- frame; GetActivityInfoTable() is MayReturnNothing during LFG warm-up.
	local info = inst and inst.activityInfo or activityInfoForID(activityID)
	if not info then
		return
	end
	-- Group-less dungeons use the validated activity snapshot as their semantic
	-- identity. A Journal/static label may describe an entrance or an older
	-- projection, while info.fullName/mapID are the exact currently creatable
	-- dungeon selected by Blizzard's Activity Finder.
	local labelOverride
	if categoryID ~= GF.CAT_DUNGEON then
		labelOverride = inst and inst.label
	end
	local baseLabel = catalogSoloBaseName(info, labelOverride)
	local activityMapID = tonumber(info.mapID)
	local groupKey
	if categoryID == GF.CAT_DUNGEON and activityMapID and activityMapID > 0 then
		groupKey = "dungeon:map:" .. tostring(activityMapID)
	else
		groupKey = normalizedNodeKey(baseLabel) or tostring(activityID)
	end
	local itemOrder = tonumber(inst and inst.orderIndex) or tonumber(info.orderIndex) or ordinal or activityID
	local isWorldBoss = isWorldBossLabel(baseLabel)
		or isWorldBossLabel(info.fullName)
		or isWorldBossLabel(info.shortName)
	local bucket = soloGroups[groupKey]
	if bucket == nil then
		bucket = {
			key = groupKey,
			label = baseLabel,
			entries = {},
			orderIndex = itemOrder,
			worldBoss = isWorldBoss,
		}
		soloGroups[groupKey] = bucket
		soloOrder[#soloOrder + 1] = bucket
	else
		bucket.worldBoss = bucket.worldBoss or isWorldBoss
		bucket.orderIndex = math.min(tonumber(bucket.orderIndex) or itemOrder, itemOrder)
	end
	bucket.entries[#bucket.entries + 1] = {
		activityID = activityID,
		info = info,
		listFilters = listFilters,
		baseLabel = bucket.label,
		orderIndex = itemOrder,
		worldBoss = bucket.worldBoss,
	}
end

local function sortCatalogBranches(children, catalogKind)
	local function catalogBranchComesBefore(a, b)
		if catalogKind == "raid" then
			local aIsWorldBoss = a and a.worldBossNode == true
			local bIsWorldBoss = b and b.worldBossNode == true
			if aIsWorldBoss ~= bIsWorldBoss then
				return aIsWorldBoss
			end
		end
		local aOrder = tonumber(a and a.orderIndex) or 0
		local bOrder = tonumber(b and b.orderIndex) or 0
		if aOrder == bOrder then
			return (a and a.label or "") < (b and b.label or "")
		end
		return aOrder < bOrder
	end
	table.sort(children, catalogBranchComesBefore)
end

local function sortGuideRankedBranches(children)
	local completeGuideOrder = #children > 0
	for sourceOrder, child in ipairs(children) do
		child._gfPresentationSourceOrder = sourceOrder
		if tonumber(child and child.journalOrderIndex) == nil then
			completeGuideOrder = false
		end
	end
	local function sourceOrder(child)
		return tonumber(child and child.sourceOrderIndex)
			or tonumber(child and child.orderIndex)
			or tonumber(child and child._gfPresentationSourceOrder)
			or 0
	end
	table.sort(children, function(left, right)
		if completeGuideOrder then
			local leftGuide = tonumber(left and left.journalOrderIndex) or 0
			local rightGuide = tonumber(right and right.journalOrderIndex) or 0
			if leftGuide ~= rightGuide then
				return leftGuide < rightGuide
			end
		end
		local leftSource, rightSource = sourceOrder(left), sourceOrder(right)
		if leftSource ~= rightSource then
			return leftSource < rightSource
		end
		local leftLabel = tostring(left and left.label or "")
		local rightLabel = tostring(right and right.label or "")
		if leftLabel ~= rightLabel then
			return leftLabel < rightLabel
		end
		return (tonumber(left and left._gfPresentationSourceOrder) or 0)
			< (tonumber(right and right._gfPresentationSourceOrder) or 0)
	end)
	for _, child in ipairs(children) do
		child._gfPresentationSourceOrder = nil
	end
end

local function cachedJournalOrderForActivityBranch(branch)
	local resolver = GF.NavCatalog and GF.NavCatalog.GetCachedJournalOrder
	if type(resolver) ~= "function" or type(branch) ~= "table" then
		return nil
	end
	local info = branch.activityInfo
	for _, child in ipairs(branch.children or {}) do
		if type(child.activityInfo) == "table" then
			info = child.activityInfo
			break
		end
	end
	local ok, orderIndex = pcall(
		resolver,
		"dungeon",
		info and info.mapID,
		info and info.instanceMapID,
		branch.label
	)
	return ok and tonumber(orderIndex) or nil
end

local function catalogInstanceIdentityMatches(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	local leftJournal = tonumber(left.journalInstanceID)
	local rightJournal = tonumber(right.journalInstanceID)
	if leftJournal and leftJournal > 0 and leftJournal == rightJournal then
		return true
	end
	local leftMaps = { tonumber(left.mapID), tonumber(left.instanceMapID) }
	local rightMaps = { tonumber(right.mapID), tonumber(right.instanceMapID) }
	for _, leftMap in ipairs(leftMaps) do
		if leftMap and leftMap > 0 then
			for _, rightMap in ipairs(rightMaps) do
				if rightMap and rightMap > 0 and leftMap == rightMap then
					return true
				end
			end
		end
	end
	local leftLabel = normalizedNodeKey(left.label)
	return leftLabel ~= nil and leftLabel == normalizedNodeKey(right.label)
end

local function findMatchingSeasonRaidInstance(instance, seasonInstances)
	for _, seasonInstance in ipairs(seasonInstances or {}) do
		if catalogInstanceIdentityMatches(instance, seasonInstance) then
			return seasonInstance
		end
	end
	return nil
end

local function buildCatalogBranches(
	parentKey,
	level,
	catalogKind,
	instances,
	buildBranch,
	options
)
	options = options or {}
	local getMeta = GF.NavCatalog
		and (GF.NavCatalog.GetBaseMeta or GF.NavCatalog.GetMeta)
	local meta = type(getMeta) == "function" and getMeta(catalogKind) or nil
	if not meta then
		return {}
	end
	local categoryID, preferred = meta.categoryID, meta.preferredFilters or PVE
	local children, soloGroups, soloOrder = {}, {}, {}
	local groupBuilder = buildBranch or buildForcedGroupBranch
	local seasonRaidInstances = catalogKind == "raid"
		and options.skipSeasonRaid ~= true
		and GF.NavCatalog and GF.NavCatalog.GetSeasonInstances
		and GF.NavCatalog.GetSeasonInstances("raid") or nil
	for index, inst in ipairs(instances or {}) do
		local branch
		local seasonRaidInstance = inst.fallbackSnapshot ~= true
			and catalogKind == "raid"
			and findMatchingSeasonRaidInstance(inst, seasonRaidInstances) or nil
		if inst.fallbackSnapshot then
			branch = buildVerifiedSnapshotBranch(
				("%s_i%d"):format(parentKey, index),
				level,
				categoryID,
				inst.listFilters or meta.baseFilters or 0,
				preferred,
				inst
			)
		elseif seasonRaidInstance then
			branch = buildSeasonRaidGroupBranch(
				("%s_i%d"):format(parentKey, index),
				level,
				categoryID,
				seasonRaidInstance.groupID or inst.groupID,
				seasonRaidInstance.listFilters or inst.listFilters
					or meta.baseFilters or 0,
				preferred,
				seasonRaidInstance,
				"raid"
			)
		elseif inst.groupID then
			branch = groupBuilder(
				("%s_i%d"):format(parentKey, index),
				level,
				categoryID,
				inst.groupID,
				inst.listFilters or meta.baseFilters or 0,
				preferred,
				inst
			)
		elseif inst.activityID then
			addSoloCatalogEntry(
				soloGroups,
				soloOrder,
				categoryID,
				inst,
				inst.activityID,
				inst.listFilters or meta.baseFilters or 0,
				index
			)
		elseif inst.catalogUnavailable then
			local L = GF.L or {}
			local disabledReason = L.NAV_ACTIVITY_UNAVAILABLE
				or "This instance is not yet available."
			local requiredLevel = tonumber(inst.requiredLevel)
			if inst.levelLimited == true and requiredLevel then
				local format = L.NAV_ACTIVITY_LEVEL_REQUIRED_FMT
				if type(format) == "string" and format ~= "" then
					disabledReason = format:format(requiredLevel)
				else
					disabledReason = L.NAV_ACTIVITY_LEVEL_REQUIRED
						or "The required level has not been reached."
				end
			end
			branch = leaf(
				("%s_u%s"):format(parentKey, tostring(inst.journalInstanceID or index)),
				level,
				inst.label or "?",
				{
					orderIndex = inst.orderIndex or index,
					journalInstanceID = inst.journalInstanceID,
					mapID = inst.mapID,
					instanceMapID = inst.instanceMapID,
					catalogUnavailable = true,
					levelLimited = inst.levelLimited == true and true or nil,
					requiredLevel = requiredLevel,
					worldBossNode = inst.worldBossContainer == true,
					disabled = true,
					disabledTooltip = true,
					disabledReason = disabledReason,
				}
			)
		end
		if branch then
			branch.orderIndex = inst.orderIndex ~= nil and inst.orderIndex or branch.orderIndex
			branch.journalInstanceID = inst.journalInstanceID
			branch.mapID = inst.mapID
			branch.instanceMapID = inst.instanceMapID
			children[#children + 1] = branch
		end
	end
	for index, group in ipairs(soloOrder) do
		local branch = buildSoloActivityBranch(
			("%s_s%d"):format(parentKey, index),
			level,
			categoryID,
			group.entries,
			preferred
		)
		if branch then
			branch.orderIndex = group.orderIndex
			branch.worldBossNode = group.worldBoss
			children[#children + 1] = branch
		end
	end
	sortCatalogBranches(children, catalogKind)
	return children
end

local function archiveShellKey(parentKey, shell, ordinal)
	local identity = shell and (shell.identity
		or shell.journalInstanceID and ("j:" .. tostring(shell.journalInstanceID))
		or shell.groupID and ("g:" .. tostring(shell.groupID))
		or shell.activityID and ("a:" .. tostring(shell.activityID)))
		or ("n:" .. tostring(ordinal))
	identity = tostring(identity):gsub("[^%w_%-]", "_")
	return parentKey .. "_" .. identity
end

local function archiveLevelRequirementReason(requiredLevel)
	local L = GF.L or {}
	local format = L.NAV_ACTIVITY_LEVEL_REQUIRED_FMT
	if type(format) == "string" and format ~= "" then
		return format:format(requiredLevel)
	end
	return L.NAV_ACTIVITY_LEVEL_REQUIRED
		or "The required level has not been reached."
end

local function applyPrecomputedArchiveLevelGate(n)
	local resolver = GF.NavCatalog
		and GF.NavCatalog.GetPrecomputedRequiredLevel
	local requiredLevel = type(resolver) == "function"
		and resolver(n and n.archiveShell) or nil
	if not requiredLevel then
		return false
	end
	n.disabled = true
	n.disabledTooltip = true
	n.disabledReason = archiveLevelRequirementReason(requiredLevel)
	n.catalogUnavailable = true
	n.levelLimited = true
	n.requiredLevel = requiredLevel
	n.isLeaf = true
	return true
end

local function buildCatalogInstanceShells(
	parentKey,
	level,
	catalogKind,
	expansionIndex
)
	local getMeta = GF.NavCatalog
		and (GF.NavCatalog.GetBaseMeta or GF.NavCatalog.GetMeta)
	local meta = type(getMeta) == "function" and getMeta(catalogKind) or nil
	if GF.NavCatalog and not GF.NavCatalog.GetInstanceShells
		and GF.NavCatalog.GetInstances
	then
		return buildCatalogBranches(
			parentKey,
			level,
			catalogKind,
			GF.NavCatalog.GetInstances(catalogKind, expansionIndex) or {})
	end
	local shells
	if GF.NavCatalog and GF.NavCatalog.GetInstanceShells then
		shells = GF.NavCatalog.GetInstanceShells(catalogKind, expansionIndex)
	elseif GF.NavCatalog and GF.NavCatalog.GetInstances then
		-- Compatibility for diagnostics/test providers predating structural
		-- shells. Production NavCatalog always supplies the lazy accessor above.
		shells = GF.NavCatalog.GetInstances(catalogKind, expansionIndex)
	end
	shells = shells or {}
	if not meta then
		return {}
	end
	local children = {}
	for ordinal, shell in ipairs(shells) do
		local child = node(
			archiveShellKey(parentKey, shell, ordinal),
			level,
			shell.label or "?",
			{
				navKind = catalogKind,
				lazyKind = "archive_instance",
				catalogKind = catalogKind,
				expansionIndex = expansionIndex,
				categoryID = meta.categoryID,
				filters = meta.baseFilters or 0,
				preferredFilters = meta.preferredFilters or PVE,
				childrenLoaded = false,
				archiveDirectoryOnly = true,
				archiveInstanceShell = true,
				archiveIdentity = shell.identity,
				archiveShell = shell,
				orderIndex = shell.orderIndex or ordinal,
				journalInstanceID = shell.journalInstanceID,
				mapID = shell.mapID,
				instanceMapID = shell.instanceMapID,
				visualTexture = shell.visualTexture,
				visualTexCoords = shell.visualTexCoords,
				visualSource = shell.visualSource,
				worldBossNode = shell.worldBossContainer == true,
			}
		)
		applyPrecomputedArchiveLevelGate(child)
		children[#children + 1] = child
	end
	sortCatalogBranches(children, catalogKind)
	return children
end

local ARCHIVE_AUTHORIZED_FIELDS = {
	"activityID",
	"activityInfo",
	"activityIDsFilter",
	"activitySearchFiltersByID",
	"categoryID",
	"filters",
	"searchFilters",
	"preferredFilters",
	"groupID",
	"journalInstanceID",
	"mapID",
	"instanceMapID",
	"orderIndex",
	"visualTexture",
	"visualTexCoords",
	"visualSource",
	"worldBossNode",
	"expandPrefixPlaceholder",
	"levelLimited",
	"requiredLevel",
}

local function resetArchiveInstanceAuthorization(n)
	-- A retained shell can be rebuilt after LFG_LIST_AVAILABILITY_UPDATE. Never
	-- let the previous generation's activity scope or disabled state authorize
	-- (or block) the next generation.
	for _, field in ipairs(ARCHIVE_AUTHORIZED_FIELDS) do
		n[field] = nil
	end
	n.disabled = nil
	n.disabledTooltip = nil
	n.disabledReason = nil
	n.catalogUnavailable = nil
	n.isLeaf = false
end

local function restoreArchiveInstanceShell(n)
	if not (n and n.lazyKind == "archive_instance" and n.archiveShell) then
		return false
	end
	resetArchiveInstanceAuthorization(n)
	local getMeta = GF.NavCatalog
		and (GF.NavCatalog.GetBaseMeta or GF.NavCatalog.GetMeta)
	local meta = type(getMeta) == "function" and getMeta(n.catalogKind) or nil
	n.categoryID = meta and meta.categoryID
	n.filters = meta and (meta.baseFilters or 0) or n.filters
	n.preferredFilters = meta and (meta.preferredFilters or PVE)
		or n.preferredFilters
	n.archiveDirectoryOnly = true
	n.archiveInstanceShell = true
	n.archiveInstanceResolved = nil
	n.children = nil
	n.childrenLoaded = false
	applyPrecomputedArchiveLevelGate(n)
	return true
end

local function authorizeArchiveInstanceNode(n)
	local shell = n and n.archiveShell
	local instances, authorizationState
	if shell and GF.NavCatalog and GF.NavCatalog.AuthorizeInstance then
		instances, authorizationState = GF.NavCatalog.AuthorizeInstance(
			n.catalogKind, n.expansionIndex, shell)
	elseif shell then
		instances = { shell }
	end
	if authorizationState == "indeterminate" then
		-- A transient API/readiness failure must not turn a structurally verified
		-- parent into a permanent unavailable leaf. Returning nil tells the lazy
		-- projection to keep the neutral shell unresolved and retryable.
		return nil
	end
	instances = instances or {}
	local branches = buildCatalogBranches(
		n.key,
		n.level or 2,
		n.catalogKind,
		instances,
		nil,
		{ skipSeasonRaid = true }
	)
	local branch = branches[1]
	resetArchiveInstanceAuthorization(n)
	if not branch then
		local L = GF.L or {}
		n.disabled = true
		n.disabledTooltip = true
		n.disabledReason = L.NAV_ACTIVITY_UNAVAILABLE
			or "This instance is not yet available."
		n.catalogUnavailable = true
		n.isLeaf = true
		n.archiveDirectoryOnly = nil
		n.archiveInstanceResolved = true
		return {}
	end
	for _, field in ipairs(ARCHIVE_AUTHORIZED_FIELDS) do
		if branch[field] ~= nil then
			n[field] = branch[field]
		end
	end
	n.label = branch.label or n.label
	n.isLeaf = branch.isLeaf == true
	n.archiveDirectoryOnly = nil
	n.archiveInstanceShell = nil
	n.archiveInstanceResolved = true
	n.catalogUnavailable = branch.catalogUnavailable
	if branch.disabled then
		n.disabled = true
		n.disabledTooltip = branch.disabledTooltip
		n.disabledReason = branch.disabledReason
	end
	return branch.children or {}
end

local function buildGroupsUnder(parentKey, level, categoryID, filters, preferred, groupIDs, buildBranch)
	local children, branchBuilder = {}, buildBranch or buildGroupBranch
	for _, groupID in ipairs(groupIDs or {}) do
		local branch = branchBuilder(parentKey, level, categoryID, groupID, filters, preferred)
		if branch then
			children[#children + 1] = branch
		end
	end
	return children
end

local function buildSeasonDungeonChildren(parentKey)
	local catalogInstances, catalogState = {}, "pending"
	if GF.NavCatalog and GF.NavCatalog.GetSeasonInstances then
		catalogInstances, catalogState =
			GF.NavCatalog.GetSeasonInstances("dungeon")
	end
	catalogInstances = catalogInstances or {}
	if catalogState == nil then
		catalogState = "ready"
	end
	local getMeta = GF.NavCatalog
		and (GF.NavCatalog.GetBaseMeta or GF.NavCatalog.GetMeta)
	local meta = type(getMeta) == "function" and getMeta("dungeon") or nil
	local preferred = meta and meta.preferredFilters or PVE
	seasonDungeonPresentationState = catalogState == "ready"
		and resolveSeasonDungeonPresentationState(catalogInstances) or "loading"
	local children = {}
	if catalogState ~= "ready" then
		children[1] = seasonLoadingLeaf(parentKey, "season_dungeon")
		return children
	end
	if #catalogInstances == 0 then
		children[1] = seasonLoadingLeaf(parentKey, "season_dungeon")
		return children
	end
	local L = GF.L or {}
	local stateUnavailableReason
	local directoryReady = activityDirectoryLoaded()
	if not directoryReady
		or seasonDungeonPresentationState == "activity_loading"
	then
		stateUnavailableReason = L.NAV_ACTIVITY_DIRECTORY_LOADING
			or "Activity directory is loading."
	elseif seasonDungeonPresentationState == "level_limited" then
		stateUnavailableReason = L.NAV_ACTIVITY_LEVEL_REQUIRED
			or "The required level has not been reached."
	else
		stateUnavailableReason = L.NAV_ACTIVITY_UNAVAILABLE
			or "This instance is not yet available."
	end
	for index, instance in ipairs(catalogInstances) do
		local filters = instance.listFilters
			or bit.bor(Enum.LFGListFilter.CurrentSeason, PVE)
		local identity = instance.journalInstanceID or instance.challengeModeID
			or instance.groupID or instance.activityID or index
		local branchKey = string.format("%s_i%s", parentKey, tostring(identity))
		local branch
		if seasonDungeonPresentationState == "mplus_open" then
			branch = buildSeasonDungeonMythicPlusLeaf(
				branchKey, 1, filters, preferred, instance)
		else
			branch = buildSeasonDungeonStandardBranch(
				branchKey, 1, filters, preferred, instance, {
					activityIDs = (not directoryReady
						or seasonDungeonPresentationState == "activity_loading")
						and {} or nil,
					unavailableReason = stateUnavailableReason,
				})
		end
		if branch then
			branch.challengeModeID = instance.challengeModeID
			branch.orderIndex = instance.orderIndex or branch.orderIndex
			branch.sourceOrderIndex = tonumber(instance.seasonMapOrder)
				or tonumber(instance.orderIndex) or index
			branch.journalOrderIndex = tonumber(instance.journalOrderIndex)
			branch.journalInstanceID = instance.journalInstanceID
			branch.mapID = instance.mapID
			branch.instanceMapID = instance.instanceMapID
			children[#children + 1] = branch
		end
	end
	if #children == 0 then
		local reason = seasonUnavailableReason()
		children[1] = leaf(parentKey .. "_unavailable", 1, reason, {
			navKind = "season_dungeon",
			disabled = true,
			disabledTooltip = true,
			disabledReason = reason,
			seasonUnavailable = true,
		})
	end
	-- Apply Adventure Guide order only when the complete visible roster has a
	-- rank. A partially loaded guide keeps every row in its native season order
	-- instead of moving the few hydrated entries ahead of their siblings.
	sortGuideRankedBranches(children)
	return children
end

local function buildSeasonRaidChildren(parentKey)
	local catalogInstances, catalogState = {}, "pending"
	if GF.NavCatalog and GF.NavCatalog.GetSeasonInstances then
		catalogInstances, catalogState =
			GF.NavCatalog.GetSeasonInstances("raid")
	end
	catalogInstances = catalogInstances or {}
	if catalogState == nil then
		catalogState = "ready"
	end
	local getMeta = GF.NavCatalog
		and (GF.NavCatalog.GetBaseMeta or GF.NavCatalog.GetMeta)
	local meta = type(getMeta) == "function" and getMeta("raid") or nil
	local preferred = meta and meta.preferredFilters or PVE
	local children = {}
	if catalogState ~= "ready" then
		children[1] = seasonLoadingLeaf(parentKey, "season_raid")
		return children
	end
	for index, instance in ipairs(catalogInstances) do
		local identity = instance.journalInstanceID
			or instance.groupID or instance.activityID or index
		local filters = instance.listFilters
			or bit.bor(Enum.LFGListFilter.Recommended, PVE)
		local branch = buildSeasonRaidGroupBranch(
			string.format("%s_i%s", parentKey, tostring(identity)),
			1,
			GF.CAT_RAID,
			instance.groupID,
			filters,
			preferred,
			instance
		)
		branch.orderIndex = instance.orderIndex or branch.orderIndex
		branch.journalInstanceID = instance.journalInstanceID
		branch.mapID = instance.mapID
		branch.instanceMapID = instance.instanceMapID
		branch.visualTexture = instance.visualTexture
		branch.visualTexCoords = instance.visualTexCoords
		branch.visualSource = instance.visualSource
		children[#children + 1] = branch
	end
	if #children == 0 then
		local reason = seasonUnavailableReason()
		children[1] = leaf(parentKey .. "_unavailable", 1, reason, {
			navKind = "season_raid",
			disabled = true,
			disabledTooltip = true,
			disabledReason = reason,
			seasonUnavailable = true,
		})
	end
	sortCatalogBranches(children, "raid")
	return children
end

local function buildDelveBranchesForFilter(parentKey, level, filterFlags)
	local groups = getAvailableActivityGroups(GF.CAT_DELVE, filterFlags)
	local function buildDelveGroupBranch(branchParentKey, branchLevel, categoryID, groupID, filters, preferred)
		return buildGroupBranch(branchParentKey, branchLevel, categoryID, groupID, filters, preferred, {
			forceBranch = true,
			useFullActivityLabel = true,
			useDelveTierIdentity = true,
		})
	end
	local children = buildGroupsUnder(
		parentKey, level, GF.CAT_DELVE, filterFlags, PVE, groups, buildDelveGroupBranch)
	local nativeGroupSourceOrder = {}
	for sourceOrder, groupID in ipairs(groups or {}) do
		if nativeGroupSourceOrder[groupID] == nil then
			nativeGroupSourceOrder[groupID] = sourceOrder
		end
	end
	for sourceOrder, branch in ipairs(children) do
		branch.sourceOrderIndex = nativeGroupSourceOrder[branch.groupID]
			or sourceOrder
		branch.journalOrderIndex = cachedJournalOrderForActivityBranch(branch)
	end
	if #children == 0 then
		local activityIDs = getCatalogGroupActivityIDs(
			GF.CAT_DELVE, nil, filterFlags, PVE)
		local buckets, bucketOrder = {}, {}
		local seenActivityIDs = {}
		for sourceOrder, activityID in ipairs(activityIDs or {}) do
			activityID = tonumber(activityID)
			local info = activityID and activityInfoForID(activityID) or nil
			if activityID and not seenActivityIDs[activityID]
				and type(info) == "table"
				and tonumber(info.categoryID) == tonumber(GF.CAT_DELVE)
			then
				seenActivityIDs[activityID] = true
				local groupID = tonumber(info.groupFinderActivityGroupID)
				if groupID and groupID <= 0 then
					groupID = nil
				end
				local groupInfo = groupID and activityGroupInfoForID(groupID) or nil
				local fullName = trimText(delveFullActivityLabel(info))
				local tierProvider = GF.ActivityInfo
					and GF.ActivityInfo.GetDelveTierNumber
				local tier = type(tierProvider) == "function"
					and tierProvider(info) or nil
				local activityBaseName
				if tier and fullName then
					activityBaseName = fullName:match("^(.+)%s*%([^()]+%)$")
						or fullName:match("^(.+)%s*（.+）$")
					activityBaseName = trimText(activityBaseName)
				end
				if activityBaseName == nil then
					local provider = GF.ActivityInfo
						and GF.ActivityInfo.GetActivityBaseName
					activityBaseName = type(provider) == "function"
						and trimText(provider(info)) or fullName
				end
				local label = trimText(groupInfo and groupInfo.name)
					or activityBaseName or fullName or "?"
				local baseIdentity = normalizedNodeKey(activityBaseName or label)
					or tostring(activityID)
				local mapID = tonumber(info.mapID)
				local identity = groupID and ("group:" .. tostring(groupID))
					or table.concat({
						"activity", baseIdentity, tostring(mapID or 0),
					}, ":")
				local bucket = buckets[identity]
				if not bucket then
					bucket = {
						identity = identity,
						groupID = groupID,
						label = label,
						activityIDs = {},
						activityInfoByID = {},
						activityFiltersByID = {},
						sourceOrderIndex = sourceOrder,
						orderIndex = tonumber(groupInfo and groupInfo.orderIndex)
							or tonumber(info.orderIndex) or sourceOrder,
					}
					buckets[identity] = bucket
					bucketOrder[#bucketOrder + 1] = bucket
				end
				bucket.activityIDs[#bucket.activityIDs + 1] = activityID
				bucket.activityInfoByID[activityID] = info
				bucket.activityFiltersByID[activityID] = tonumber(info.filters)
			end
		end
		local function delveActivity(info)
			return type(info) == "table"
				and tonumber(info.categoryID) == tonumber(GF.CAT_DELVE)
		end
		for _, bucket in ipairs(bucketOrder) do
			local branch = buildGroupBranch(
				parentKey,
				level,
				GF.CAT_DELVE,
				bucket.groupID,
				filterFlags,
				PVE,
				{
					forceBranch = true,
					branchIdentity = bucket.groupID or bucket.identity,
					branchLabel = bucket.label,
					activityIDs = bucket.activityIDs,
					activityInfoByID = bucket.activityInfoByID,
					activityInfoPredicate = delveActivity,
					useActivityFilters = true,
					useFullActivityLabel = true,
					useDelveTierIdentity = true,
				}
			)
			if branch then
				-- Native Activity Finder can expose concrete delve activities while
				-- omitting its group directory for this character/filter. Rebuild only
				-- from those already-returned activities: the synthetic parent restores
				-- navigation hierarchy but grants no additional activity authority.
				branch.orderIndex = bucket.orderIndex
				branch.sourceOrderIndex = bucket.sourceOrderIndex
				branch.journalOrderIndex = cachedJournalOrderForActivityBranch(branch)
				branch.activityIDsFilter = bucket.activityIDs
				branch.activitySearchFiltersByID = bucket.activityFiltersByID
				children[#children + 1] = branch
			end
		end
	end
	-- Delves are not guaranteed to have Adventure Guide identities. Reorder only
	-- when every visible parent matched an already-cached Guide row; otherwise
	-- preserve GetAvailableActivityGroups/GetAvailableActivities source order.
	sortGuideRankedBranches(children)
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
		local key = parentKey .. "_" .. bucket.keySuffix
		local fields = {
			navKind = "delve",
			lazyKind = "delve_filter",
			categoryID = GF.CAT_DELVE,
			filters = bucket.filters,
			fallbackFilters = bucket.fallbackFilters,
			preferredFilters = PVE,
			expansionIndex = bucket.expansionIndex,
			childrenLoaded = false,
		}
		-- Resolve the two delve expansion buckets while their parent flyout is
		-- being built.  Otherwise an empty bucket first renders as actionable and
		-- only discovers its level gate after pointer entry realizes the branch.
		-- Keep the old lazy/fail-open shape while Blizzard's directory is not ready;
		-- the availability refresh will rebuild this root once it becomes readable.
		if activityDirectoryLoaded() then
			fields.children = buildDelveFilterBranches(
				key, 2, bucket.filters or PVE, bucket.fallbackFilters)
			fields.childrenLoaded = true
			if #fields.children == 0 then
				local L = GF.L or {}
				fields.disabled = true
				fields.disabledTooltip = true
				fields.disabledReason = L.NAV_ACTIVITY_LEVEL_REQUIRED
					or "The required level has not been reached."
				fields.levelLimited = true
				fields.catalogUnavailable = true
				fields.isLeaf = true
			end
		end
		children[#children + 1] = node(key, 1, bucket.label, fields)
	end
	return children
end

local function buildCatalogL1Expansions(parentKey, catalogKind, level)
	local getMeta = GF.NavCatalog.GetBaseMeta or GF.NavCatalog.GetMeta
	local meta = type(getMeta) == "function" and getMeta(catalogKind) or nil
	if not meta then
		return {}
	end
	local children = {}
	for index, expansion in ipairs(GF.NavCatalog.GetExpansions(catalogKind)) do
		local expansionIndex = expansion.expansionIndex
		local fields = {
			navKind = catalogKind,
			lazyKind = "archive_expansion",
			archiveDirectoryOnly = true,
			archiveAggregateDirectory = true,
			catalogKind = catalogKind,
			expansionIndex = expansionIndex,
			categoryID = meta.categoryID,
			filters = meta.baseFilters or 0,
			preferredFilters = meta.preferredFilters or PVE,
			childrenLoaded = false,
		}
		local key = ("%s_e%s"):format(parentKey, tostring(expansionIndex))
		children[index] = node(key, level, expansion.label or expansionLabel(expansionIndex), fields)
	end
	return children
end

local function buildPvpChildren(parentKey)
	local L = GF.L or {}
	local out, known = {}, {}
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
		addActivityLeaves(subKey, 2, categoryID, nil, 0, PVP, acts, {
			useFullActivityLabel = true,
		})
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

local function questFilterSets()
	return {
		PVE,
		bit.bor(Enum.LFGListFilter.Recommended, PVE),
		bit.bor(Enum.LFGListFilter.NotRecommended, PVE),
		0,
	}
end

local function collectQuestGroups()
	local groups = {}
	local seen = {}
	for _, filterFlags in ipairs(questFilterSets()) do
		for _, groupID in ipairs(getAvailableActivityGroups(GF.CAT_QUEST, filterFlags)) do
			preparationCheckpoint()
			groupID = tonumber(groupID)
			if groupID and groupID > 0 and not seen[groupID] then
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

local function collectUngroupedQuestActivities()
	local activityIDs, activityInfoByID, examined = {}, {}, {}
	local function addFromGroup(groupID, filterFlags)
		for _, activityID in ipairs(getAvailableActivitiesCached(
			GF.CAT_QUEST, groupID, filterFlags))
		do
			preparationCheckpoint()
			activityID = tonumber(activityID)
			if activityID and activityID > 0 and not examined[activityID] then
				local info = activityInfoForID(activityID)
				if info and type(info.categoryID) == "number"
					and tonumber(info.groupFinderActivityGroupID) ~= nil then
					examined[activityID] = true
				end
				if info and info.categoryID == GF.CAT_QUEST
					and tonumber(info.groupFinderActivityGroupID) == 0
				then
					activityIDs[#activityIDs + 1] = activityID
					activityInfoByID[activityID] = info
				end
			end
		end
	end
	-- Blizzard's group dropdown combines groups with group=0 activities.
	-- Query both native category-level shapes even when named groups exist;
	-- metadata alone must never authorize a standalone activity.
	for _, filterFlags in ipairs(questFilterSets()) do
		addFromGroup(0, filterFlags)
		addFromGroup(nil, filterFlags)
	end
	return activityIDs, activityInfoByID
end

local function questFamilyDisplayLabel(family, members)
	local labelLeaf
	local labelActivityID = tonumber(family and family.labelActivityID)
	for _, member in ipairs(members or {}) do
		if labelLeaf == nil then
			labelLeaf = member
		end
		if labelActivityID ~= nil and member.activityID == labelActivityID then
			labelLeaf = member
			break
		end
	end
	local info = labelLeaf and labelLeaf.activityInfo
	local baseName = GF.ActivityInfo and GF.ActivityInfo.GetActivityBaseName
		and GF.ActivityInfo.GetActivityBaseName(info)
	baseName = stripKnownDifficultySuffix(baseName)
	return trimText(baseName) or (labelLeaf and labelLeaf.label) or "?"
end

local function groupManualQuestActivityFamilies(parentKey, groupID, activities, listFilters)
	local byGroup = GF.NAV_QUEST_MANUAL_ACTIVITY_FAMILIES
	local families = type(byGroup) == "table" and byGroup[groupID]
	if type(families) ~= "table" or #families == 0 then
		return activities
	end

	local familyByActivityID = {}
	for familyIndex, family in ipairs(families) do
		for _, activityID in ipairs(family.activityIDs or {}) do
			activityID = tonumber(activityID)
			if activityID ~= nil and familyByActivityID[activityID] == nil then
				familyByActivityID[activityID] = familyIndex
			end
		end
	end

	local membersByFamily = {}
	for _, activity in ipairs(activities or {}) do
		local familyIndex = familyByActivityID[activity.activityID]
		if familyIndex ~= nil then
			membersByFamily[familyIndex] = membersByFamily[familyIndex] or {}
			membersByFamily[familyIndex][#membersByFamily[familyIndex] + 1] = activity
		end
	end

	local grouped = {}
	local emittedFamilies = {}
	for _, activity in ipairs(activities or {}) do
		local familyIndex = familyByActivityID[activity.activityID]
		if familyIndex == nil then
			grouped[#grouped + 1] = activity
		elseif not emittedFamilies[familyIndex] then
			emittedFamilies[familyIndex] = true
			local family = families[familyIndex]
			local members = membersByFamily[familyIndex] or {}
			for _, member in ipairs(members) do
				member.level = 3
			end
			local familyKey = tonumber(family.labelActivityID)
				or (members[1] and members[1].activityID) or familyIndex
			grouped[#grouped + 1] = node(parentKey .. "_f" .. tostring(familyKey), 2,
				questFamilyDisplayLabel(family, members), {
					navKind = "quest",
					categoryID = GF.CAT_QUEST,
					filters = listFilters,
					searchFilters = 0,
					preferredFilters = PVE,
					orderIndex = members[1] and members[1].orderIndex,
					children = members,
				})
		end
	end
	return grouped
end

local function buildQuestChildren(parentKey)
	local children = {}
	for _, entry in ipairs(collectQuestGroups()) do
		local groupID = entry.groupID
		local listFilters = entry.listFilters or PVE
		local groupInfo = activityGroupInfoForID(groupID)
		local gName = groupInfo and groupInfo.name
		local orderIndex = groupInfo and groupInfo.orderIndex
		local questGroupKey = parentKey .. "_q" .. groupID
		local acts = {}
		addActivityLeaves(
			questGroupKey,
			2,
			GF.CAT_QUEST,
			groupID,
			listFilters,
			PVE,
			acts,
			{
				preserveActivityIdentity = true,
				sortByBaseActivity = true,
			}
		)
		if #acts > 0 then
			for _, act in ipairs(acts) do
				act.searchFilters = 0
			end
			acts = groupManualQuestActivityFamilies(questGroupKey, groupID, acts, listFilters)
			children[#children + 1] = node(questGroupKey, 1, gName or ("Group " .. groupID), {
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
	local activityIDs, activityInfoByID = collectUngroupedQuestActivities()
	local standalone = {}
	addActivityLeaves(parentKey, 1, GF.CAT_QUEST, 0, 0, PVE, standalone, {
		activityIDs = activityIDs,
		activityInfoByID = activityInfoByID,
		preserveActivityIdentity = true,
		useActivityFilters = true,
	})
	for _, activity in ipairs(standalone) do
		activity.navKind = "quest"
		activity.searchFilters = 0
		children[#children + 1] = activity
	end
	sortQuestGroupBranches(children)
	return children
end

local function collectAvailableCustomActivities()
	local seen = {}
	local function addFromGroup(groupID, filterFlags)
		for _, actID in ipairs(getAvailableActivitiesCached(GF.CAT_CUSTOM, groupID, filterFlags) or {}) do
			local info = activityInfoForID(actID)
			if info and info.categoryID == GF.CAT_CUSTOM then
				seen[actID] = true
			end
		end
	end
	for _, filterFlags in ipairs({ PVE, PVP, 0 }) do
		addFromGroup(nil, filterFlags)
		addFromGroup(0, filterFlags)
	end
	return seen
end

local function buildCustomActivityLeaf(parentKey, suffix, label, preferred, activityID, availableActivities)
	local activityInfo = activityInfoForID(activityID)
	if not activityInfo or activityInfo.categoryID ~= GF.CAT_CUSTOM then
		return nil
	end
	if availableActivities and next(availableActivities) ~= nil and not availableActivities[activityID] then
		return nil
	end
	return leaf(parentKey .. "_" .. suffix, 1, label, {
		navKind = "custom",
		customBucket = true,
		customFixedActivity = true,
		categoryID = GF.CAT_CUSTOM,
		filters = 0,
		searchFilters = 0,
		preferredFilters = preferred,
		searchPreferredFilters = 0,
		groupID = activityInfo and activityInfo.groupFinderActivityGroupID,
		activityID = activityID,
		activityInfo = activityInfo,
		activityIDsFilter = { activityID },
	})
end

local function buildCustomChildren(parentKey)
	local L = GF.L or {}
	local availableActivities = collectAvailableCustomActivities()
	local children = {}
	local pveNode = buildCustomActivityLeaf(parentKey, "pve", L.NAV_CUSTOM_PVE or "Custom PvE", PVE, GF.ACTIVITY_CUSTOM_PVE, availableActivities)
	local pvpNode = buildCustomActivityLeaf(parentKey, "pvp", L.NAV_CUSTOM_PVP or "Custom PvP", PVP, GF.ACTIVITY_CUSTOM_PVP or 17, availableActivities)
	local housewarmingNode = buildCustomActivityLeaf(parentKey, "housewarming", L.NAV_HOUSEWARMING or "Housewarming", PVE, GF.ACTIVITY_HOUSEWARMING, availableActivities)
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

function Projection.IsSeasonHotL0(n)
	local kind = n and n.navKind
	return kind == "season_dungeon" or kind == "season_raid"
end

local LAZY_CHILD_BUILDERS = {
	catalog_l0 = function(n)
		if n.catalogKind and GF.NavCatalog then
			return buildCatalogL1Expansions(n.key, n.catalogKind, 1)
		end
	end,
	season_dungeon = function(n)
		return buildSeasonDungeonChildren(n.key)
	end,
	season_raid = function(n)
		return buildSeasonRaidChildren(n.key)
	end,
	delve_l0 = function(n)
		return buildDelveL0Children(n.key)
	end,
	delve_filter = function(n)
		return buildDelveFilterBranches(n.key, 2, n.filters or PVE, n.fallbackFilters)
	end,
	archive_expansion = function(n)
		if n.catalogKind and n.expansionIndex ~= nil then
			return buildCatalogInstanceShells(
				n.key, 2, n.catalogKind, n.expansionIndex)
		end
	end,
	archive_instance = function(n)
		if n.catalogKind and n.expansionIndex ~= nil then
			return authorizeArchiveInstanceNode(n)
		end
	end,
	quick_search_result = function(n)
		local search = GF.QuickSearch
		local entry = search and search.GetEntryByIdentity
			and search:GetEntryByIdentity(n.quickSearchIdentity) or nil
		local children = entry and search.BuildDifficultyNodes
			and search:BuildDifficultyNodes(entry, n.quickSearchTabID) or {}
		for _, child in ipairs(children) do
			if n.favoriteSourceIdentity then
				child.favoriteSourceIdentity = n.favoriteSourceIdentity
			end
		end
		if #children == 0 then
			local L = GF.L or {}
			n.disabled = true
			n.disabledTooltip = true
			n.disabledReason = L.NAV_ACTIVITY_UNAVAILABLE
				or "This instance is not yet available."
		end
		return children
	end,
	pvp_l0 = function(n)
		return buildPvpChildren(n.key)
	end,
	quest_l0 = function(n)
		return buildQuestChildren(n.key)
	end,
	custom_l0 = function(n)
		return buildCustomChildren(n.key)
	end,
	favorite_instances_l0 = function()
		local favorites = GF.FavoriteInstances
		return favorites and favorites.BuildNodes
			and favorites:BuildNodes() or {}
	end,
}

local function restoreLfgRestriction(n)
	local state = n and n._gfLfgRestrictionState
	if not state then
		return
	end
	if state.hadDisabled then
		n.disabled = state.disabled
	else
		n.disabled = nil
	end
	if state.hadReason then
		n.disabledReason = state.disabledReason
	else
		n.disabledReason = nil
	end
	n._gfLfgRestrictionState = nil
end

local function setLfgRestriction(n, reason)
	if not (n and type(reason) == "string" and reason ~= "") then
		return
	end
	n._gfLfgRestrictionState = {
		hadDisabled = n.disabled ~= nil,
		disabled = n.disabled,
		hadReason = n.disabledReason ~= nil,
		disabledReason = n.disabledReason,
	}
	n.disabled = true
	n.disabledReason = reason
end

local function emptySeasonReason(n)
	if not (Projection.IsSeasonHotL0(n)
		and n.childrenLoaded == true
		and #(n.children or {}) == 0)
	then
		return nil
	end
	local L = GF.L or {}
	if n.navKind == "season_dungeon" then
		return L.NAV_SEASON_DUNGEON_UNAVAILABLE
			or "Seasonal dungeons are not yet available."
	end
	return L.NAV_SEASON_RAID_UNAVAILABLE
		or "Seasonal raids are not yet available."
end

local function applyLfgRestrictions(nodes)
	local availability = GF.Availability
	local getPremadeReason = availability
		and availability.GetPremadeNavigationRestriction
	local globalReason = type(getPremadeReason) == "function"
		and getPremadeReason(availability) or nil
	local changed = false
	local pending = {}
	for index = #(nodes or {}), 1, -1 do
		pending[#pending + 1] = nodes[index]
	end
	while #pending > 0 do
		local current = table.remove(pending)
		local previousDisabled = current.disabled
		local previousReason = current.disabledReason
		restoreLfgRestriction(current)
		local reason = globalReason
		if reason == nil and (current.level or 0) == 0 then
			reason = emptySeasonReason(current)
		end
		setLfgRestriction(current, reason)
		if current.disabled ~= previousDisabled
			or current.disabledReason ~= previousReason
		then
			changed = true
		end
		for index = #(current.children or {}), 1, -1 do
			pending[#pending + 1] = current.children[index]
		end
	end
	return changed
end

Projection.ApplyLfgRestrictions = applyLfgRestrictions

local function publishChildren(n, children)
	n.children = children
	n.childrenLoaded = true
	if n.lazyKind == "quest_l0" then n._questBuildGeneration = preparation.generation end
	Projection.InvalidateScopeCache(n)
	applyLfgRestrictions({ n })
end

local function prepareBranch(n)
	-- Only the measured large quest projection is scheduled. Archive/Journal
	-- owners retain their existing demand-driven authorization contracts.
	if preparation.isolated or not n or n.lazyKind ~= "quest_l0"
		or type(GetTimePreciseSec) ~= "function" or type(CreateFrame) ~= "function"
	then return false end
	if preparation.jobs[n] then return true end
	if not preparation.frame then
		local frame = CreateFrame("Frame")
		preparation.frame = frame
		frame:Hide()
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		frame:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
		frame:SetScript("OnEvent", function(self)
			if next(preparation.jobs) then self:Show() end
		end)
		frame:SetScript("OnUpdate", function(self)
			if type(InCombatLockdown) == "function" and InCombatLockdown() then
				self:Hide()
				return
			end
			if not activityDirectoryLoaded() then
				-- Wait for the native readiness event, rather than caching an
				-- early empty directory or polling it on every rendering frame.
				self:Hide()
				return
			end
			local target, job = next(preparation.jobs)
			if not job then self:Hide(); return end
			job.sliceStart = GetTimePreciseSec()
			activePreparation = job
			local ok, children = coroutine.resume(job.thread)
			activePreparation = nil
			if not ok then
				preparation.jobs[target] = nil
				if type(geterrorhandler) == "function" then geterrorhandler()(children) end
			elseif coroutine.status(job.thread) == "dead" then
				preparation.jobs[target] = nil
				if job.generation == preparation.generation and job.tree == currentTree()
					and type(children) == "table" then
					-- The current tree is the sole owner of completed children;
					-- no second ready tree waits for a visible-window refresh.
					publishChildren(target, children)
					local presenter = GF.NavigationPresenter
					if presenter and presenter.OnBranchPrepared then
						presenter:OnBranchPrepared(target)
					end
				end
			end
			if not next(preparation.jobs) then self:Hide() end
		end)
	end
	local job = { generation = preparation.generation, tree = currentTree() }
	job.thread = coroutine.create(function()
		return buildQuestChildren(n.key)
	end)
	preparation.jobs[n] = job
	preparation.frame:Show()
	return true
end

function Projection.PrepareNavigation(n)
	-- Preparation requires a specific requested branch, never a login-wide sweep.
	if not n or n.childrenLoaded or n.disabled then return false end
	return prepareBranch(n)
end

local function rebuildLazyChildren(n)
	local builder = n and LAZY_CHILD_BUILDERS[n.lazyKind]
	if type(builder) ~= "function" then
		return false
	end
	-- A synchronous business lookup supersedes any suspended UI preparation.
	preparation.jobs[n] = nil
	if preparation.frame and not next(preparation.jobs) then preparation.frame:Hide() end
	local children = builder(n)
	if children == nil then
		return false
	end
	publishChildren(n, children)
	return true
end

function Projection.EnsureChildren(n)
	if not n or n.childrenLoaded or n.disabled then
		return
	end
	rebuildLazyChildren(n)
end

function Projection.RequestChildren(n)
	if not n or n.childrenLoaded or n.disabled then return end
	if Projection.PrepareNavigation(n) then
		-- The click never finishes a suspended build synchronously. The existing
		-- loading row is replaced atomically, without exposing a partial tree.
		n.children = n.children or { seasonLoadingLeaf(n.key, n.navKind) }
		return
	end
	Projection.EnsureChildren(n)
end

-- 活动可用性变化时重建已展开/热加载的 API 分支。曾加载但当前折叠
-- 的分支必须丢弃旧 children，下一次展开再从新运行时数据懒加载。
local AVAIL_REFRESH_LAZY = {
	catalog_l0 = true,
	season_dungeon = true,
	season_raid = true,
	delve_l0 = true,
	delve_filter = true,
	archive_expansion = true,
	archive_instance = true,
	quest_l0 = true,
	custom_l0 = true,
	favorite_instances_l0 = true,
}

local AVAIL_REFRESH_EAGER_ROOT = {
	season_dungeon = true,
	season_raid = true,
	delve = true,
}

local function refreshExpandedCatalog(nodes, expanded, retained)
	local changed = false
	local pending = {}
	for index = #(nodes or {}), 1, -1 do
		pending[#pending + 1] = nodes[index]
	end
	while #pending > 0 do
		local current = table.remove(pending)
		local refreshable = AVAIL_REFRESH_LAZY[current.lazyKind] == true
		local isExpanded = expanded[current.key] == true
		local isRetained = retained[current.key] == true
		local isEagerRoot = (current.level or 0) == 0
			and AVAIL_REFRESH_EAGER_ROOT[current.navKind] == true
		if refreshable then
			if current.lazyKind == "quest_l0"
				and current._questBuildGeneration == preparation.generation then
				-- A completed warm projection already uses this availability
				-- generation. Debounced publication must not build it a second time.
			elseif current.lazyKind == "archive_instance" then
				-- Availability is an authorization-generation boundary.  A
				-- concrete archive instance must return to its neutral structural
				-- shell here; retained selection/open keys are not permission to
				-- perform live LFG authorization in an event callback.
				if current.childrenLoaded
					or current.archiveInstanceResolved == true
					or current.archiveInstanceShell ~= true
				then
					changed = restoreArchiveInstanceShell(current) or changed
					Projection.InvalidateScopeCache(current)
				end
			elseif current.childrenLoaded and (isExpanded or isRetained or isEagerRoot) then
				changed = rebuildLazyChildren(current) or changed
			elseif current.childrenLoaded then
				current.children = nil
				current.childrenLoaded = false
				Projection.InvalidateScopeCache(current)
				changed = true
			elseif isExpanded or isRetained then
				-- A rebuilt parent creates fresh lazy children. Restore any branch
				-- whose expansion or retained-selection key survived the update.
				changed = rebuildLazyChildren(current) or changed
			end
		end
		for index = #(current.children or {}), 1, -1 do
			pending[#pending + 1] = current.children[index]
		end
	end
	return changed
end

function Projection.refreshExpandedCatalogBranches(expanded, retained)
	local tree = currentTree()
	return tree ~= nil
		and refreshExpandedCatalog(tree, expanded or {}, retained or {}) or false
end

function Projection.OnAvailabilityChanged(expanded, retained)
	-- RuntimeLifecycle/season services invalidate the shared generation before
	-- publishing this refresh. Clearing again here can make a branch opened in
	-- the debounce window pay the same cold catalog cost twice.
	if GF.QuickSearch and GF.QuickSearch.Invalidate then
		GF.QuickSearch:Invalidate()
	end
	local changed = Projection.refreshExpandedCatalogBranches(expanded, retained)
	return applyLfgRestrictions(currentTree()) or changed
end

function Projection.OnArchiveOverlayUpdated(kind, expansionIndex)
	expansionIndex = tonumber(expansionIndex)
	local changed = false
	local pending = {}
	for index = #(currentTree() or {}), 1, -1 do
		pending[#pending + 1] = currentTree()[index]
	end
	while #pending > 0 do
		local current = table.remove(pending)
		if current.lazyKind == "archive_expansion"
			and current.catalogKind == kind
			and tonumber(current.expansionIndex) == expansionIndex
		then
			current.children = nil
			current.childrenLoaded = false
			Projection.InvalidateScopeCache(current)
			changed = true
		else
			for index = #(current.children or {}), 1, -1 do
				pending[#pending + 1] = current.children[index]
			end
		end
	end
	if changed and GF.QuickSearch and GF.QuickSearch.Invalidate then
		GF.QuickSearch:Invalidate()
	end
	return changed
end

function Projection.OnArchiveOverlayPurged()
	local changed = false
	local pending = {}
	for index = #(currentTree() or {}), 1, -1 do
		pending[#pending + 1] = currentTree()[index]
	end
	while #pending > 0 do
		local current = table.remove(pending)
		if current.lazyKind == "archive_expansion" then
			current.children = nil
			current.childrenLoaded = false
			Projection.InvalidateScopeCache(current)
			changed = true
		else
			for index = #(current.children or {}), 1, -1 do
				pending[#pending + 1] = current.children[index]
			end
		end
	end
	if GF.QuickSearch and GF.QuickSearch.Invalidate then
		GF.QuickSearch:Invalidate()
	end
	return changed
end

local function rootLabels()
	local L = GF.L or {}
	return {
		quick_search = L.NAV_QUICK_SEARCH or "Quick Search",
		season_dungeon = L.NAV_SEASON_DUNGEON or L.NAV_SEASON or "Season Dungeons",
		season_raid = L.NAV_SEASON_RAID or "Season Raids",
		delve = L.NAV_DELVE or "Delves",
		dungeon = L.NAV_DUNGEON or "Dungeons",
		raid = L.NAV_RAID or "Raids",
		pvp = L.NAV_PVP or "PvP",
		quest = L.NAV_QUEST or "Quests",
		custom = L.NAV_CUSTOM or "Custom",
		favorite_instances = L.NAV_FAVORITE_INSTANCES or "Activity Favorites",
	}
end

local function rootDefinition(key, fields)
	return { key = key, fields = fields }
end

function Projection.Rebuild()
	if not preparation.isolated then
		preparation.jobs = {}
		if preparation.frame then preparation.frame:Hide() end
	end
	local labels = rootLabels()
	local quickSearchChildren = GF.QuickSearch and GF.QuickSearch.CreatePlaceholderNode
		and { GF.QuickSearch:CreatePlaceholderNode(false) } or {}
	local recommendedRaid = bit.bor(Enum.LFGListFilter.Recommended, PVE)
	local expansionDungeon = bit.bor(
		Enum.LFGListFilter.CurrentExpansion,
		Enum.LFGListFilter.NotCurrentSeason,
		PVE
	)
	local firstPvp = GF.PVP_CATEGORIES and GF.PVP_CATEGORIES[1]
	local seasonDungeonFields = {}
	seasonDungeonFields.categoryID = GF.CAT_DUNGEON
	seasonDungeonFields.navKind = "season_dungeon"
	seasonDungeonFields.filters = bit.bor(Enum.LFGListFilter.CurrentSeason, PVE)
	seasonDungeonFields.childrenLoaded = false
	seasonDungeonFields.preferredFilters = PVE
	seasonDungeonFields.lazyKind = "season_dungeon"
	local roots = {
		rootDefinition("quick_search", {
			navKind = "quick_search",
			quickSearchRoot = true,
			noExpandPrefix = true,
			children = quickSearchChildren,
			childrenLoaded = true,
		}),
		rootDefinition("season_dungeon", seasonDungeonFields),
		rootDefinition("season_raid", { navKind = "season_raid", lazyKind = "season_raid", categoryID = GF.CAT_RAID, filters = recommendedRaid, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("delve", { navKind = "delve", lazyKind = "delve_l0", categoryID = GF.CAT_DELVE, filters = PVE, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("dungeon", { navKind = "dungeon", lazyKind = "catalog_l0", catalogKind = "dungeon", archiveAggregateRoot = true, categoryID = GF.CAT_DUNGEON, filters = expansionDungeon, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("raid", { navKind = "raid", lazyKind = "catalog_l0", catalogKind = "raid", archiveAggregateRoot = true, categoryID = GF.CAT_RAID, filters = recommendedRaid, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("pvp", { navKind = "pvp", lazyKind = "pvp_l0", categoryID = firstPvp and firstPvp.id or 8, filters = 0, preferredFilters = PVP, childrenLoaded = false }),
		rootDefinition("quest", { navKind = "quest", lazyKind = "quest_l0", categoryID = GF.CAT_QUEST, filters = PVE, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("custom", { navKind = "custom", lazyKind = "custom_l0", categoryID = GF.CAT_CUSTOM, searchFilters = 0, searchPreferredFilters = 0, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("favorite_instances", {
			navKind = "favorite_instances",
			lazyKind = "favorite_instances_l0",
			favoriteInstancesRoot = true,
			childrenLoaded = false,
		}),
	}
	local tree = {}
	for index, definition in ipairs(roots) do
		tree[index] = node(definition.key, 0, labels[definition.key], definition.fields)
	end
	publishTree(tree)
	-- The two fixed seasonal roots must know their empty/available state before
	-- first paint; otherwise the first click would be needed to discover that
	-- Blizzard currently exposes no matching premade activities.
	for _, root in ipairs(tree) do
		if Projection.IsSeasonHotL0(root) then
			rebuildLazyChildren(root)
		end
	end
	applyLfgRestrictions(tree)
	return currentTree()
end

function Projection.RefreshLocaleLabels()
	local tree = currentTree()
	if not tree then
		return
	end
	local labels = rootLabels()
	local rebuildLocalizedChildren = {
		pvp = buildPvpChildren,
		custom = buildCustomChildren,
	}
	for _, root in ipairs(tree) do
		local localized = labels[root.key]
		if localized then
			root.label = localized
		end
		local childBuilder = rebuildLocalizedChildren[root.navKind]
		if root.childrenLoaded and childBuilder then
			root.children = childBuilder(root.key)
			Projection.InvalidateScopeCache(root)
		end
	end
	if GF.QuickSearch and GF.QuickSearch.Invalidate then
		GF.QuickSearch:Invalidate()
	end
	if GF.FavoriteInstances and GF.FavoriteInstances.RefreshRoot then
		GF.FavoriteInstances:RefreshRoot()
	end
	applyLfgRestrictions(tree)
end

function Projection.GetLoadedTree()
	return currentTree()
end

function Projection.GetTree()
	if currentTree() == nil then
		Projection.Rebuild()
	end
	return currentTree()
end

-- Diagnostics sometimes need a fully expanded scratch projection.  Keeping
-- the swap here prevents those callers from mutating the compatibility mirror
-- behind the owner's back, and guarantees restoration after callback errors.
function Projection.WithIsolatedTree(callback)
	if type(callback) ~= "function" then
		return false, "callback must be a function"
	end
	local activeTree = currentTree()
	local wasIsolated = preparation.isolated
	preparation.isolated = true
	publishTree(nil)
	local ok, result = pcall(callback)
	publishTree(activeTree)
	preparation.isolated = wasIsolated
	return ok, result
end

local function validCachedPath(key)
	local path = key and projectionState.paths[key]
	if not path then return nil end
	local children = currentTree()
	for index, n in ipairs(path) do
		if not children or children[path._indices[index]] ~= n then
			-- Favorites and compatibility owners may replace a child array
			-- directly. An index hit is valid only along the current parent chain.
			projectionState.paths = {}
			return nil
		end
		children = n.children
	end
	return path
end

function Projection.FindLoadedNodePathByKey(key)
	if key == nil then
		return nil, nil
	end
	local cached = validCachedPath(key)
	if cached then
		local copy = {}
		for index, value in ipairs(cached) do copy[index] = value end
		return cached[#cached], copy
	end
	-- Root lookups must not traverse the hundreds of leaves under preceding
	-- roots when every menu row rechecks its root's interaction permissions.
	for _, root in ipairs(currentTree() or {}) do
		if root.key == key then return root, { root } end
	end
	local path, indices = {}, {}
	local function visit(current, childIndex)
		path[#path + 1] = current
		indices[#path] = childIndex
		if current and current.key == key then
			local result = { _indices = {} }
			for index = 1, #path do
				result[index] = path[index]
				result._indices[index] = indices[index]
			end
			return current, result
		end
		local children = current and current.children
		for index = 1, children and #children or 0 do
			local node, result = visit(children[index], index)
			if node then
				return node, result
			end
		end
		path[#path] = nil
		return nil, nil
	end
	for index, root in ipairs(currentTree() or {}) do
		local node, result = visit(root, index)
		if node then
			projectionState.paths[key] = result
			local copy = {}
			for index, value in ipairs(result) do copy[index] = value end
			return node, copy
		end
	end
	return nil, nil
end

function Projection.FindNodeByKey(key)
	local cached = validCachedPath(key)
	if cached then return cached[#cached] end
	for _, root in ipairs(currentTree() or {}) do
		if root.key == key then return root end
	end
	local node = Projection.FindLoadedNodePathByKey(key)
	return node
end

local function nodeContainsActivityID(n, activityID)
	if not (n and activityID) then
		return false
	end
	if n.activityID == activityID then
		return true
	end
	for _, candidateID in ipairs(n.activityIDsFilter or {}) do
		if candidateID == activityID then
			return true
		end
	end
	return false
end

local function replacementNodeMatches(candidate, previous)
	if not (candidate and previous) then
		return false
	end
	if previous.challengeModeID then
		return candidate.navKind == previous.navKind
			and tonumber(candidate.challengeModeID)
				== tonumber(previous.challengeModeID)
	end
	if previous.categoryID ~= GF.CAT_DUNGEON
		and previous.categoryID ~= GF.CAT_RAID
	then
		return false
	end
	if candidate.categoryID ~= previous.categoryID
		or candidate.isLeaf ~= previous.isLeaf
	then
		return false
	end
	if candidate.navKind and previous.navKind
		and candidate.navKind ~= previous.navKind
	then
		return false
	end
	if previous.groupID and not previous.isLeaf then
		return candidate.groupID == previous.groupID
	end
	if previous.activityID and nodeContainsActivityID(candidate, previous.activityID) then
		return true
	end
	for _, activityID in ipairs(previous.activityIDsFilter or {}) do
		if nodeContainsActivityID(candidate, activityID) then
			return true
		end
	end
	if previous.activityID or #(previous.activityIDsFilter or {}) > 0 then
		return false
	end
	if previous.groupID then
		return candidate.groupID == previous.groupID
	end
	local previousLabel = normalizedNodeKey(previous.label)
	return not previous.lazyKind and previousLabel ~= nil
		and normalizedNodeKey(candidate.label) == previousLabel
end

function Projection.FindReplacementNode(previous, previousPath)
	if not previous then
		return nil
	end
	-- Quest children may have been released before a hidden window processes
	-- availability. Rebinding an actual selection is explicit synchronous demand.
	if previous.categoryID == GF.CAT_QUEST then
		for _, root in ipairs(currentTree() or {}) do
			if root.lazyKind == "quest_l0" then Projection.EnsureChildren(root) end
		end
	end
	local exact = Projection.FindNodeByKey(previous.key)
	local catalogCategory = previous.categoryID == GF.CAT_DUNGEON
		or previous.categoryID == GF.CAT_RAID
	if exact and exact.lazyKind == "archive_instance"
		and exact.archiveInstanceShell == true
		and exact.childrenLoaded ~= true
	then
		-- A live-authorized instance from the previous availability
		-- generation cannot be rebound to a neutral shell as a business
		-- selection.  Let the shell remain visible, but clear the stale
		-- selection/results until the player explicitly authorizes it again.
		exact = nil
	end
	if exact and (not catalogCategory or previous.lazyKind
		or replacementNodeMatches(exact, previous))
	then
		return exact
	end
	local anchor
	for index = 1, math.max(0, #(previousPath or {}) - 1) do
		local pathNode = previousPath[index]
		local loaded = pathNode and Projection.FindNodeByKey(pathNode.key)
		if not loaded then
			break
		end
		anchor = loaded
	end
	local pending = {}
	local roots = anchor and anchor.children or currentTree()
	for index = #(roots or {}), 1, -1 do
		pending[#pending + 1] = roots[index]
	end
	while #pending > 0 do
		local current = table.remove(pending)
		if replacementNodeMatches(current, previous) then
			return current
		end
		for index = #(current.children or {}), 1, -1 do
			pending[#pending + 1] = current.children[index]
		end
	end
	return nil
end

local function callSearchScopeCompiler(methodName, ...)
	local compiler = GF.SearchScopeCompiler
	local method = compiler and compiler[methodName]
	if type(method) ~= "function" then
		return nil
	end
	return method(...)
end

-- Compatibility surface for existing GF consumers.  Search scope policy,
-- filter-item projection, and creation eligibility live in the compiler.
function Projection.ResolveSearchScope(n, opts)
	return callSearchScopeCompiler("ResolveSearchScope", n, opts)
end

function Projection.ResolveSearchScopes(n, opts)
	return callSearchScopeCompiler("ResolveSearchScopes", n, opts) or {}
end

function Projection.GetFilterActivityItems(navKind)
	return callSearchScopeCompiler("GetFilterActivityItems", navKind) or {}
end

function Projection.GetSearchBlockHint(n)
	return callSearchScopeCompiler("GetSearchBlockHint", n)
end

function Projection.IsSearchable(n)
	return callSearchScopeCompiler("IsSearchable", n) == true
end

function Projection.AcceptsBrowseSelection(n)
	return callSearchScopeCompiler("AcceptsBrowseSelection", n) == true
end

function Projection.ResolveCreateActivityID(n)
	return callSearchScopeCompiler("ResolveCreateActivityID", n)
end

function Projection.CanCreateFromNode(n)
	return callSearchScopeCompiler("CanCreateFromNode", n) == true
end

function Projection.FindNodeByActivityID(activityID)
	if not activityID then
		return nil
	end
	activityID = tonumber(activityID)
	local targetInfo = activityInfoForID(activityID)
	local targetGroupID = tonumber(targetInfo and targetInfo.groupFinderActivityGroupID)
	if targetGroupID == 0 then
		targetGroupID = nil
	end
	local function catalogSourceContains(source, current)
		local section = source and source[current.catalogKind]
		for _, expansion in ipairs(section and section.expansions or {}) do
			if tonumber(expansion and expansion.expansionIndex)
				== tonumber(current.expansionIndex)
			then
				for _, record in ipairs(expansion.instances or {}) do
					if targetGroupID
						and tonumber(record and record.groupID) == targetGroupID
						or not targetGroupID
						and tonumber(record and record.activityID) == activityID
					then
						return true
					end
				end
			end
		end
		return false
	end
	local function archiveExpansionMayContain(current)
		return catalogSourceContains(GF.NAV_CATALOG, current)
			or catalogSourceContains(GF.NAV_CATALOG_SUPPLEMENT, current)
			or catalogSourceContains(GF.NAV_MANUAL_CATALOG, current)
	end
	local function shellMayContain(current)
		local shell = current and current.archiveShell
		if type(shell) ~= "table" then
			return false
		end
		if targetGroupID and tonumber(shell.groupID) == targetGroupID then
			return true
		end
		if tonumber(shell.activityID) == activityID
			or tonumber(shell.seedActivityID) == activityID
		then
			return true
		end
		for _, candidate in ipairs(shell.soloCandidates or {}) do
			if tonumber(candidate and candidate.activityID) == activityID then
				return true
			end
		end
		return false
	end
	local roots, pending = Projection.GetTree(), {}
	for index = #roots, 1, -1 do
		pending[#pending + 1] = roots[index]
	end
	while #pending > 0 do
		local current = table.remove(pending)
		-- Activity Favorites is a derived proxy tree. It may call this resolver
		-- while building a saved activity row, so it can never be an authoritative
		-- source for that same lookup. Traversing or realizing it here would make an
		-- unresolved favorite recursively build its own root until stack overflow.
		local derivedFavorite = current.favoriteInstancesRoot == true
			or current.favoriteResult == true
		if not derivedFavorite then
			if current.activityID == activityID and not current.categoryBrowse then
				return current
			end
			if current.lazyKind and not current.childrenLoaded then
				if current.lazyKind == "archive_instance" then
					if shellMayContain(current) then
						Projection.EnsureChildren(current)
					end
				elseif current.lazyKind ~= "archive_expansion"
					or archiveExpansionMayContain(current)
				then
					Projection.EnsureChildren(current)
				end
			end
			if current.activityID == activityID and not current.categoryBrowse then
				return current
			end
			for index = #(current.children or {}), 1, -1 do
				pending[#pending + 1] = current.children[index]
			end
		end
	end
	return nil
end

local function findRootByNavKind(navKind)
	for _, root in ipairs(Projection.GetTree() or {}) do
		if root and root.navKind == navKind then
			return root
		end
	end
	return nil
end

function Projection.FindSeasonDungeonNodeByActivityID(activityID)
	local numericID = tonumber(activityID)
	if numericID == nil then
		return nil
	end
	local scopeService = GF.MythicPlusLFGScope
	local getDungeon = scopeService and scopeService.GetDungeonByActivityID
	local dungeon = type(getDungeon) == "function" and scopeService:GetDungeonByActivityID(numericID) or nil
	if dungeon == nil then
		return nil
	end
	local root = findRootByNavKind("season_dungeon")
	if root == nil then
		return nil
	end
	if root.lazyKind and not root.childrenLoaded then
		Projection.EnsureChildren(root)
	end
	for _, child in ipairs(root.children or {}) do
		local sameGroup = dungeon.groupID ~= nil and child.groupID == dungeon.groupID
		if child.navKind == "season_dungeon"
			and (sameGroup or child.activityID == dungeon.activityID) then
			return child
		end
	end
	return nil
end

function Projection.RequestRefresh()
	RuntimeDirectory.Call("RequestAvailableActivities")
end
