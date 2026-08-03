local _, GF = ...

GF.NavData = {}
GF.navTree = nil

local PVE = Enum.LFGListFilter.PvE
local PVP = Enum.LFGListFilter.PvP
local NOT_RECOMMENDED = Enum.LFGListFilter.NotRecommended
local CURRENT_EXPANSION = Enum.LFGListFilter.CurrentExpansion
local NOT_CURRENT_SEASON = Enum.LFGListFilter.NotCurrentSeason
local RECOMMENDED_SEARCH_MASK = GF.RECOMMENDED_SEARCH_MASK

local DIFFICULTY_LABEL_KEY = {
	normal = "DIFF_NORMAL",
	heroic = "DIFF_HEROIC",
	mythic = "DIFF_MYTHIC",
	mplus = "DIFF_MYTHIC_PLUS",
}

local DIFFICULTY_LABEL_FALLBACK = {
	normal = "Normal",
	heroic = "Heroic",
	mythic = "Mythic",
	mplus = "Mythic Keystone",
}

local function isPvPCategory(categoryID)
	for _, pvp in ipairs(GF.PVP_CATEGORIES or {}) do
		if categoryID == pvp.id then
			return true
		end
	end
	return false
end

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

local function catalogSoloBaseName(info, labelOverride)
	local label = labelOverride or catalogSoloActivityName(info)
	label = stripKnownDifficultySuffix(label)
	return label or catalogSoloActivityName(info) or "?"
end

local function activityDifficultyDisplayLabel(info)
	local tier = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyTier
		and GF.ActivityInfo.GetDifficultyTier(info, { includeMplus = true })
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

local function sortConcreteActivityLeaves(leaves, sortMeta)
	local function comesBefore(left, right)
		local leftMeta, rightMeta = sortMeta[left], sortMeta[right]
		if leftMeta == nil or rightMeta == nil then
			if leftMeta ~= rightMeta then
				return leftMeta ~= nil
			end
			return (tonumber(left and left.activityID) or 0) < (tonumber(right and right.activityID) or 0)
		end
		local fields = { "baseOrder", "difficultyOrder", "sourceOrder" }
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
}

local function emptyTable(target)
	for key in pairs(target) do
		target[key] = nil
	end
end

local function clearNavBuildCaches()
	emptyTable(buildCache.groupInfo)
	emptyTable(buildCache.activityLists)
	local clearCatalog = GF.NavCatalog and GF.NavCatalog.ClearRuntimeCache
	if type(clearCatalog) == "function" then
		clearCatalog()
	end
end

function GF.NavData.ClearBuildCaches()
	return clearNavBuildCaches()
end

function GF.NavData.InvalidateScopeCache(n)
	if n then
		n._gfGroupActivityIDs, n._gfScopeActivityIDs = nil, nil
	end
end

local function activityGroupInfoForID(groupID)
	if groupID == nil then
		return nil
	end
	local known = buildCache.groupInfo[groupID]
	if known ~= nil then
		return known ~= false and known or nil
	end
	local getter = C_LFGList and C_LFGList.GetActivityGroupInfo
	local ok, name, orderIndex = false, nil, nil
	if type(getter) == "function" then
		ok, name, orderIndex = pcall(getter, groupID)
	end
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
	local getter = C_LFGList and C_LFGList.GetAvailableActivities
	local ok, values = false, nil
	if type(getter) == "function" then
		ok, values = pcall(getter, categoryID, groupID, filterFlags or 0)
	end
	known = ok and type(values) == "table" and values or {}
	buildCache.activityLists[cacheKey] = known
	return known
end

local function activityInfoForID(activityID)
	local getter = C_LFGList and C_LFGList.GetActivityInfoTable
	if activityID == nil or type(getter) ~= "function" then
		return nil
	end
	local ok, info = pcall(getter, activityID)
	return ok and type(info) == "table" and info or nil
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

local function getAvailableActivityGroups(categoryID, filterFlags)
	local getter = C_LFGList and C_LFGList.GetAvailableActivityGroups
	if type(getter) ~= "function" then
		return {}
	end
	local ok, groups = pcall(getter, categoryID, filterFlags or 0)
	return ok and type(groups) == "table" and groups or {}
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

local function addActivityLeaves(parentKey, level, categoryID, groupID, listFilters, preferred, out, opts)
	opts = opts or {}
	local preserveActivityIdentity = opts.preserveActivityIdentity == true
	local sortByBaseActivity = preserveActivityIdentity and opts.sortByBaseActivity == true
	local useActivityFilters = opts.useActivityFilters == true
	local activities = type(opts.activityIDs) == "table" and opts.activityIDs
		or getCatalogGroupActivityIDs(categoryID, groupID, listFilters, preferred, opts)
	local activityInfoPredicate = opts.activityInfoPredicate
	local filters = listFilters or 0
	local seenActivityIDs = {}
	local leavesByDifficulty = {}
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
		if not seenActivityIDs[actID] then
			seenActivityIDs[actID] = true
			local info = activityInfoForID(actID)
			if info and (not activityInfoPredicate or activityInfoPredicate(info)) then
				local activityFilters = useActivityFilters and tonumber(info.filters) or nil
				local childFilters = activityFilters ~= nil and activityFilters or filters
				local label = preserveActivityIdentity and concreteActivityLabel(info) or activityLabel(info)
				local mergeKey = not preserveActivityIdentity and activityDifficultyMergeKey(info)
				local existing = mergeKey and leavesByDifficulty[mergeKey]
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
						leavesByDifficulty[mergeKey] = child
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
	local branchKey = ("%s_g%s"):format(parentKey, tostring(groupID))
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

local function currentRaidActivity(info)
	return info and info.isCurrentRaidActivity == true
end

local function buildSeasonRaidGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred, instance)
	local activityIDs = {}
	for _, activityID in ipairs(instance and instance.activityIDs or {}) do
		local info = activityInfoForID(activityID)
		if currentRaidActivity(info) then
			activityIDs[#activityIDs + 1] = activityID
		end
	end
	if #activityIDs == 0 then
		return nil
	end
	local branch = buildGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred, {
		forceBranch = true,
		exactFilters = true,
		activityIDs = activityIDs,
		activityInfoPredicate = currentRaidActivity,
	})
	if branch then
		-- Parent/root searches must consume the same exact current-raid set as
		-- the difficulty leaves instead of re-enumerating the whole group.
		branch.activityIDsFilter = activityIDs
	end
	return branch
end

local function findMythicPlusActivities(categoryID, groupID, listFilters, preferred)
	local matchingIDs, primaryID, primaryInfo = {}, nil, nil
	for _, candidateID in ipairs(getCatalogGroupActivityIDs(
		categoryID, groupID, listFilters, preferred, { exactFilters = true })) do
		local candidateInfo = activityInfoForID(candidateID)
		if candidateInfo and candidateInfo.isMythicPlusActivity == true then
			if primaryID == nil then
				primaryID, primaryInfo = candidateID, candidateInfo
			end
			matchingIDs[#matchingIDs + 1] = candidateID
		end
	end
	return primaryID, primaryInfo, matchingIDs
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

local function buildSeasonDungeonGroupBranch(parentKey, level, categoryID, groupID, listFilters, preferred, instance)
	local gName = groupDisplayName(groupID)
	local filters = listFilters or 0
	local scopedDungeon = GF.MythicPlusLFGScope
		and GF.MythicPlusLFGScope.GetDungeonForInstance
		and GF.MythicPlusLFGScope:GetDungeonForInstance(instance)
	local actID = scopedDungeon and scopedDungeon.activityID
	local activityIDs = scopedDungeon and scopedDungeon.activityIDs
	local info = activityInfoForID(actID)
	if not (actID and info and activityIDs and #activityIDs > 0) then
		actID, info, activityIDs = findMythicPlusActivities(
			categoryID, groupID, filters, preferred)
	end
	local label = gName or (instance and instance.label) or (info and concreteActivityLabel(info))
	if actID ~= nil and info ~= nil then
		local fields = {
			orderIndex = info.orderIndex,
			categoryID = categoryID,
			filters = filters,
			searchFilters = normalizeSearchFilters(categoryID, filters),
			preferredFilters = preferred,
			groupID = groupID,
			activityID = actID,
			activityIDsFilter = activityIDs,
			activityInfo = info,
			navKind = "season_dungeon",
			expandPrefixPlaceholder = true,
		}
		local key = table.concat({ parentKey, "_g", tostring(groupID), "_a", tostring(actID) })
		return leaf(key, level, label, fields)
	end
	return nil
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
	local leavesByDifficulty = {}
	local seenActivityIDs = {}

	for _, entry in ipairs(entries) do
		local activityID = entry.activityID
		if activityID and not seenActivityIDs[activityID] then
			seenActivityIDs[activityID] = true
			local info = entry.info or activityInfoForID(activityID)
			if info then
				local filters = entry.listFilters or 0
				local mergeKey = activityDifficultyMergeKey(info)
				local existing = mergeKey and leavesByDifficulty[mergeKey]
				if existing then
					addMergedActivityID(existing, activityID)
				else
					local child = leaf(parentKey .. "_a" .. activityID, level + 1, activityDifficultyDisplayLabel(info), {
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
						leavesByDifficulty[mergeKey] = child
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

local function addSoloCatalogEntry(soloGroups, soloOrder, inst, activityID, listFilters, ordinal)
	local info = activityInfoForID(activityID)
	if not info then
		return
	end
	local baseLabel = catalogSoloBaseName(info, inst and inst.label)
	local groupKey = normalizedNodeKey(baseLabel) or tostring(activityID)
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

local function buildCatalogBranches(parentKey, level, catalogKind, instances, buildBranch)
	local getMeta = GF.NavCatalog and GF.NavCatalog.GetMeta
	local meta = type(getMeta) == "function" and getMeta(catalogKind) or nil
	if not meta then
		return {}
	end
	local categoryID, preferred = meta.categoryID, meta.preferredFilters or PVE
	local children, soloGroups, soloOrder = {}, {}, {}
	local groupBuilder = buildBranch or buildForcedGroupBranch
	for index, inst in ipairs(instances or {}) do
		local branch
		if inst.groupID then
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
				inst,
				inst.activityID,
				inst.listFilters or meta.baseFilters or 0,
				index
			)
		end
		if branch then
			branch.orderIndex = inst.orderIndex ~= nil and inst.orderIndex or branch.orderIndex
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

local function buildCatalogExpansionBranches(parentKey, level, catalogKind, expansionIndex)
	local instances = GF.NavCatalog and GF.NavCatalog.GetInstances(catalogKind, expansionIndex) or {}
	return buildCatalogBranches(parentKey, level, catalogKind, instances)
end

local function buildCatalogInstanceBranches(parentKey, level, catalogKind, instances, buildBranch)
	return buildCatalogBranches(parentKey, level, catalogKind, instances, buildBranch)
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
	local scopedDungeons = GF.MythicPlusLFGScope
		and GF.MythicPlusLFGScope.GetDungeons
		and GF.MythicPlusLFGScope:GetDungeons() or {}
	local meta = GF.NavCatalog and GF.NavCatalog.GetMeta
		and GF.NavCatalog.GetMeta("dungeon")
	local preferred = meta and meta.preferredFilters or PVE
	local children = {}
	for index, scopedDungeon in ipairs(scopedDungeons) do
		local instance = scopedDungeon.source or scopedDungeon
		local filters = instance.listFilters
			or (meta and meta.baseFilters)
			or bit.bor(Enum.LFGListFilter.CurrentSeason, PVE)
		local branch
		if scopedDungeon.groupID then
			branch = buildSeasonDungeonGroupBranch(
				string.format("%s_i%d", parentKey, index),
				1,
				GF.CAT_DUNGEON,
				scopedDungeon.groupID,
				filters,
				preferred,
				instance
			)
		else
			local activityID = scopedDungeon.activityID
			local info = activityInfoForID(activityID)
			if info then
				branch = leaf(
					string.format("%s_s%d_a%d", parentKey, index, activityID),
					1,
					instance.label or concreteActivityLabel(info),
					{
						orderIndex = scopedDungeon.orderIndex or info.orderIndex,
						categoryID = GF.CAT_DUNGEON,
						filters = filters,
						searchFilters = normalizeSearchFilters(GF.CAT_DUNGEON, filters),
						preferredFilters = preferred,
						activityID = activityID,
						activityIDsFilter = scopedDungeon.activityIDs,
						activityInfo = info,
						navKind = "season_dungeon",
					}
				)
			end
		end
		if branch then
			branch.orderIndex = scopedDungeon.orderIndex or branch.orderIndex
			children[#children + 1] = branch
		end
	end
	sortCatalogBranches(children, "dungeon")
	return children
end

local function buildSeasonRaidChildren(parentKey)
	local catalogInstances = GF.NavCatalog and GF.NavCatalog.GetSeasonInstances and GF.NavCatalog.GetSeasonInstances("raid")
	if catalogInstances and #catalogInstances > 0 then
		local children = buildCatalogInstanceBranches(
			parentKey, 1, "raid", catalogInstances, buildSeasonRaidGroupBranch)
		if #children > 0 then
			for _, child in ipairs(children) do
				stampNavKind(child, "season_raid")
			end
			return children
		end
	end
	return {}
end

local function buildDelveBranchesForFilter(parentKey, level, filterFlags)
	local groups = getAvailableActivityGroups(GF.CAT_DELVE, filterFlags)
	local children = buildGroupsUnder(parentKey, level, GF.CAT_DELVE, filterFlags, PVE, groups, buildForcedGroupBranch)
	if #children == 0 then
		local flat = {}
		addActivityLeaves(parentKey, level + 1, GF.CAT_DELVE, nil, filterFlags, PVE, flat)
		for index = 1, #flat do
			flat[index].level = level
			children[index] = flat[index]
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
	local meta = GF.NavCatalog.GetMeta(catalogKind)
	if not meta then
		return {}
	end
	local children = {}
	for index, expansion in ipairs(GF.NavCatalog.GetExpansions(catalogKind)) do
		local expansionIndex = expansion.expansionIndex
		local fields = {
			navKind = catalogKind,
			lazyKind = "archive_expansion",
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
		for _, groupID in ipairs(getAvailableActivityGroups(GF.CAT_QUEST, filterFlags)) do
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
		local groupInfo = activityGroupInfoForID(groupID)
		local gName = groupInfo and groupInfo.name
		local orderIndex = groupInfo and groupInfo.orderIndex
		local acts = {}
		addActivityLeaves(
			parentKey .. "_q" .. groupID,
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
		resultActivityIDsFilter = { activityID },
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

function GF.NavData.IsSeasonHotL0(n)
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
			return buildCatalogExpansionBranches(n.key, 2, n.catalogKind, n.expansionIndex)
		end
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
	if not (GF.NavData.IsSeasonHotL0(n)
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

GF.NavData.ApplyLfgRestrictions = applyLfgRestrictions

local function rebuildLazyChildren(n)
	local builder = n and LAZY_CHILD_BUILDERS[n.lazyKind]
	if type(builder) ~= "function" then
		return false
	end
	local children = builder(n)
	if children == nil then
		return false
	end
	n.children = children
	n.childrenLoaded = true
	GF.NavData.InvalidateScopeCache(n)
	applyLfgRestrictions({ n })
	return true
end

function GF.NavData.EnsureChildren(n)
	if not n or n.childrenLoaded then
		return
	end
	rebuildLazyChildren(n)
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
	quest_l0 = true,
	custom_l0 = true,
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
			if current.childrenLoaded and (isExpanded or isRetained or isEagerRoot) then
				changed = rebuildLazyChildren(current) or changed
			elseif current.childrenLoaded then
				current.children = nil
				current.childrenLoaded = false
				GF.NavData.InvalidateScopeCache(current)
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

function GF.NavData.refreshExpandedCatalogBranches(expanded, retained)
	return GF.navTree ~= nil
		and refreshExpandedCatalog(GF.navTree, expanded or {}, retained or {}) or false
end

function GF.NavData.OnAvailabilityChanged(expanded, retained)
	GF.NavData.ClearBuildCaches()
	local changed = GF.NavData.refreshExpandedCatalogBranches(expanded, retained)
	return applyLfgRestrictions(GF.navTree) or changed
end

local function rootLabels()
	local L = GF.L or {}
	return {
		history = L.NAV_HISTORY or "History",
		season_dungeon = L.NAV_SEASON_DUNGEON or L.NAV_SEASON or "Season Dungeons",
		season_raid = L.NAV_SEASON_RAID or "Season Raids",
		delve = L.NAV_DELVE or "Delves",
		dungeon = L.NAV_DUNGEON or "Dungeons",
		raid = L.NAV_RAID or "Raids",
		pvp = L.NAV_PVP or "PvP",
		quest = L.NAV_QUEST or "Quests",
		custom = L.NAV_CUSTOM or "Custom",
	}
end

local function rootDefinition(key, fields)
	return { key = key, fields = fields }
end

function GF.NavData.Rebuild()
	local labels = rootLabels()
	local historyChildren = GF.History and GF.History.BuildNodes() or {}
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
		rootDefinition("history", { navKind = "history", noExpandPrefix = true, children = historyChildren, childrenLoaded = true }),
		rootDefinition("season_dungeon", seasonDungeonFields),
		rootDefinition("season_raid", { navKind = "season_raid", lazyKind = "season_raid", categoryID = GF.CAT_RAID, filters = recommendedRaid, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("delve", { navKind = "delve", lazyKind = "delve_l0", categoryID = GF.CAT_DELVE, filters = PVE, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("dungeon", { navKind = "dungeon", lazyKind = "catalog_l0", catalogKind = "dungeon", categoryID = GF.CAT_DUNGEON, filters = expansionDungeon, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("raid", { navKind = "raid", lazyKind = "catalog_l0", catalogKind = "raid", categoryID = GF.CAT_RAID, filters = recommendedRaid, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("pvp", { navKind = "pvp", lazyKind = "pvp_l0", categoryID = firstPvp and firstPvp.id or 8, filters = 0, preferredFilters = PVP, childrenLoaded = false }),
		rootDefinition("quest", { navKind = "quest", lazyKind = "quest_l0", categoryID = GF.CAT_QUEST, filters = PVE, preferredFilters = PVE, childrenLoaded = false }),
		rootDefinition("custom", { navKind = "custom", lazyKind = "custom_l0", categoryID = GF.CAT_CUSTOM, searchFilters = 0, searchPreferredFilters = 0, preferredFilters = PVE, childrenLoaded = false }),
	}
	local tree = {}
	for index, definition in ipairs(roots) do
		tree[index] = node(definition.key, 0, labels[definition.key], definition.fields)
	end
	GF.navTree = tree
	-- The two fixed seasonal roots must know their empty/available state before
	-- first paint; otherwise the first click would be needed to discover that
	-- Blizzard currently exposes no matching premade activities.
	for _, root in ipairs(tree) do
		if GF.NavData.IsSeasonHotL0(root) then
			rebuildLazyChildren(root)
		end
	end
	applyLfgRestrictions(tree)
	return GF.navTree
end

function GF.NavData.RefreshLocaleLabels()
	if not GF.navTree then
		return
	end
	local labels = rootLabels()
	local rebuildLocalizedChildren = {
		pvp = buildPvpChildren,
		custom = buildCustomChildren,
	}
	for _, root in ipairs(GF.navTree) do
		local localized = labels[root.key]
		if localized then
			root.label = localized
		end
		local childBuilder = rebuildLocalizedChildren[root.navKind]
		if root.childrenLoaded and childBuilder then
			root.children = childBuilder(root.key)
			GF.NavData.InvalidateScopeCache(root)
		end
	end
	applyLfgRestrictions(GF.navTree)
end

function GF.NavData.RefreshHistory()
	for _, root in ipairs(GF.navTree or {}) do
		if root.navKind == "history" then
			local buildHistory = GF.History and GF.History.BuildNodes
			root.children = type(buildHistory) == "function" and buildHistory() or {}
			root.childrenLoaded = true
			applyLfgRestrictions({ root })
			return
		end
	end
end

function GF.NavData.GetTree()
	if GF.navTree == nil then
		GF.NavData.Rebuild()
	end
	return GF.navTree
end

function GF.NavData.FindLoadedNodePathByKey(key)
	if key == nil then
		return nil, nil
	end
	local path = {}
	local function visit(current)
		path[#path + 1] = current
		if current and current.key == key then
			local result = {}
			for index = 1, #path do
				result[index] = path[index]
			end
			return current, result
		end
		for _, child in ipairs(current and current.children or {}) do
			local node, result = visit(child)
			if node then
				return node, result
			end
		end
		path[#path] = nil
		return nil, nil
	end
	for _, root in ipairs(GF.navTree or {}) do
		local node, result = visit(root)
		if node then
			return node, result
		end
	end
	return nil, nil
end

function GF.NavData.FindNodeByKey(key)
	local node = GF.NavData.FindLoadedNodePathByKey(key)
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

function GF.NavData.FindReplacementNode(previous, previousPath)
	if not previous then
		return nil
	end
	local exact = GF.NavData.FindNodeByKey(previous.key)
	local catalogCategory = previous.categoryID == GF.CAT_DUNGEON
		or previous.categoryID == GF.CAT_RAID
	if exact and (not catalogCategory or previous.lazyKind
		or replacementNodeMatches(exact, previous))
	then
		return exact
	end
	local anchor
	for index = 1, math.max(0, #(previousPath or {}) - 1) do
		local pathNode = previousPath[index]
		local loaded = pathNode and GF.NavData.FindNodeByKey(pathNode.key)
		if not loaded then
			break
		end
		anchor = loaded
	end
	local pending = {}
	local roots = anchor and anchor.children or GF.navTree
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

local function collectActivityIDs(n, out)
	if not n then
		return
	end
	local directIDs = n.resultActivityIDsFilter
	if not directIDs or #directIDs == 0 then
		directIDs = not n.categoryBrowse and n.activityIDsFilter or nil
	end
	if directIDs and #directIDs > 0 then
		for index = 1, #directIDs do
			out[#out + 1] = directIDs[index]
		end
		return
	elseif n.activityID and not n.categoryBrowse then
		out[#out + 1] = n.activityID
		return
	end
	for _, child in ipairs(n.children or {}) do
		collectActivityIDs(child, out)
	end
end

local function mergeActivityIDsInto(source, destination, seen)
	for _, activityID in ipairs(source or {}) do
		if not seen[activityID] then
			seen[activityID] = true
			destination[#destination + 1] = activityID
		end
	end
end

local function collectCatalogExpansionActivityIDs(catalogKind, expansionIndex)
	local catalog = GF.NavCatalog
	local getMeta = catalog and catalog.GetMeta
	local meta = type(getMeta) == "function" and getMeta(catalogKind) or nil
	if meta == nil then
		return nil
	end
	local ids, seen = {}, {}
	local preferred = meta.preferredFilters or PVE
	for _, instance in ipairs(catalog.GetInstances(catalogKind, expansionIndex)) do
		local sourceIDs
		if instance.groupID then
			sourceIDs = instance.activityIDs
			if not sourceIDs or #sourceIDs == 0 then
				sourceIDs = getCatalogGroupActivityIDs(
					meta.categoryID,
					instance.groupID,
					instance.listFilters or meta.baseFilters or 0,
					preferred
				)
			end
		elseif instance.activityID then
			sourceIDs = { instance.activityID }
		end
		if instance.groupID
			and (catalogKind == "dungeon" or catalogKind == "raid")
		then
			sourceIDs = catalogGroupActivityIDs(sourceIDs, meta.categoryID)
		end
		mergeActivityIDsInto(sourceIDs, ids, seen)
	end
	return #ids > 0 and ids or nil
end

local function collectCatalogAllActivityIDs(catalogKind)
	local catalog = GF.NavCatalog
	if catalog == nil then
		return nil
	end
	local ids, seen = {}, {}
	for _, expansion in ipairs(catalog.GetExpansions(catalogKind)) do
		local expansionIDs = collectCatalogExpansionActivityIDs(catalogKind, expansion.expansionIndex)
		mergeActivityIDsInto(expansionIDs, ids, seen)
	end
	if #ids > 0 then
		return ids
	end
	return nil
end

local function collectDelveActivityIDsForFilter(filterFlags)
	local ids, seen = {}, {}
	for _, groupID in ipairs(getAvailableActivityGroups(GF.CAT_DELVE, filterFlags)) do
		local groupActivities = getAvailableActivitiesCached(GF.CAT_DELVE, groupID, filterFlags)
		mergeActivityIDsInto(groupActivities, ids, seen)
	end
	if #ids == 0 then
		local flatActivities = getAvailableActivitiesCached(GF.CAT_DELVE, nil, filterFlags)
		mergeActivityIDsInto(flatActivities, ids, seen)
	end
	if #ids > 0 then
		return ids
	end
	return nil
end

local function collectDelveFilterActivityIDs(filterFlags, fallbackFilters)
	local primary = collectDelveActivityIDsForFilter(filterFlags)
	if primary then
		return primary
	end
	local shouldFallback = fallbackFilters ~= nil and fallbackFilters ~= filterFlags
	return shouldFallback and collectDelveActivityIDsForFilter(fallbackFilters) or nil
end

local function collectDelveL0ActivityIDs()
	local ids, seen = {}, {}
	for _, bucket in ipairs(delveBuckets()) do
		local bucketIDs = collectDelveFilterActivityIDs(bucket.filters, bucket.fallbackFilters)
		mergeActivityIDsInto(bucketIDs, ids, seen)
	end
	if #ids > 0 then
		return ids
	end
	return nil
end

local function collectL0ScopeActivityIDs(n)
	local lazyKind = n.lazyKind
	if lazyKind == "catalog_l0" and n.catalogKind then
		return collectCatalogAllActivityIDs(n.catalogKind)
	elseif lazyKind == "delve_l0" then
		return collectDelveL0ActivityIDs()
	end
	local needsLoadedTree = lazyKind == "season_dungeon"
		or lazyKind == "season_raid"
		or lazyKind == "quest_l0"
	if needsLoadedTree then
		if not n.childrenLoaded then
			GF.NavData.EnsureChildren(n)
		end
		local ids = {}
		collectActivityIDs(n, ids)
		if #ids > 0 then
			return ids
		end
		return nil
	end
	return nil
end

local function finishScopeWithActivityIDs(scope, ids)
	scope.activityIDsFilter = ids and #ids > 0 and ids or nil
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

local function addActivityScope(scopesByKey, scopeOrder, source, activityID, activityFilters)
	if not source or not activityID then
		return
	end
	local categoryID = source.categoryID
	local filters = activityFilters
	if filters == nil then
		filters = source.searchFilters
	end
	if filters == nil then
		filters = source.filters or 0
	end
	if not categoryID then
		local info = activityInfoForID(activityID)
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
			addActivityScope(scopesByKey, scopeOrder, n, actID,
				n.activitySearchFiltersByID and n.activitySearchFiltersByID[actID])
		end
		return
	end
	if n.activityIDsFilter and #n.activityIDsFilter > 0 then
		for _, actID in ipairs(n.activityIDsFilter) do
			addActivityScope(scopesByKey, scopeOrder, n, actID,
				n.activitySearchFiltersByID and n.activitySearchFiltersByID[actID])
		end
		return
	end
	if n.activityID then
		addActivityScope(scopesByKey, scopeOrder, n, n.activityID,
			n.activitySearchFiltersByID and n.activitySearchFiltersByID[n.activityID])
		return
	end
	if n.groupID and n.categoryID then
		if GF.NavData.IsSeasonHotL0(n) then
			-- Seasonal branches are fail-closed: only direct exact IDs or
			-- already-built children may define their search scope.
			if n.lazyKind and not n.childrenLoaded then
				GF.NavData.EnsureChildren(n)
			end
			for _, child in ipairs(n.children or {}) do
				collectNodeActivityScopes(child, scopesByKey, scopeOrder)
			end
			return
		end
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
	if GF.NavData.IsSeasonHotL0(n) then
		-- A valid empty season scope is authoritative. Never turn it into a
		-- category-wide raid/dungeon search through the generic fallback.
		return {}
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
	local info = activityInfoForID(activityID)
	if info then
		addFilterActivityGroupID(out, seen, info.groupFinderActivityGroupID)
	end
end

local function addFilterActivityID(out, seen, activityID)
	activityID = tonumber(activityID)
	if activityID and activityID > 0 and not seen[activityID] then
		seen[activityID] = true
		out[#out + 1] = activityID
	end
end

local function collectUniqueActivityIDs(n)
	local raw = {}
	collectActivityIDs(n, raw)
	local ids = {}
	local seen = {}
	for _, activityID in ipairs(raw) do
		addFilterActivityID(ids, seen, activityID)
	end
	return ids
end

local function collectActivityGroupIDsForIDs(activityIDs)
	local groupIDs = {}
	local seen = {}
	for _, activityID in ipairs(activityIDs or {}) do
		addFilterActivityGroupIDForActivity(groupIDs, seen, activityID)
	end
	table.sort(groupIDs)
	return groupIDs
end

local function joinNumericIDs(ids)
	local copy = {}
	for _, id in ipairs(ids or {}) do
		copy[#copy + 1] = tonumber(id) or id
	end
	table.sort(copy, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	local out = {}
	for _, id in ipairs(copy) do
		out[#out + 1] = tostring(id)
	end
	return table.concat(out, ",")
end

local function activityFilterItemKey(n, activityIDs, groupIDs)
	if n and n.groupID then
		return "g:" .. tostring(n.groupID)
	end
	if groupIDs and #groupIDs == 1 then
		return "g:" .. tostring(groupIDs[1])
	end
	if groupIDs and #groupIDs > 1 then
		return "g:" .. joinNumericIDs(groupIDs)
	end
	if activityIDs and #activityIDs > 0 then
		return "a:" .. joinNumericIDs(activityIDs)
	end
	return n and n.key or nil
end

local function addActivityFilterItem(out, seen, n, ordinal)
	if not n or n.disabled or n.categoryBrowse then
		return
	end
	if n.lazyKind and not n.childrenLoaded then
		GF.NavData.EnsureChildren(n)
	end
	local activityIDs = collectUniqueActivityIDs(n)
	if #activityIDs == 0 then
		return
	end
	local groupIDs = collectActivityGroupIDsForIDs(activityIDs)
	local key = activityFilterItemKey(n, activityIDs, groupIDs)
	if not key or seen[key] then
		return
	end
	seen[key] = true
	out[#out + 1] = {
		key = key,
		label = n.label or "?",
		activityIDs = activityIDs,
		groupIDs = groupIDs,
		groupID = n.groupID,
		activityID = n.activityID,
		navKind = n.navKind,
		categoryID = n.categoryID,
		orderIndex = ordinal or tonumber(n.orderIndex) or #out + 1,
		nodeKey = n.key,
	}
end

local function collectActivityFilterItems(n, out, seen)
	if not n or n.disabled or n.categoryBrowse then
		return
	end
	if n.lazyKind and not n.childrenLoaded then
		GF.NavData.EnsureChildren(n)
	end
	for index, child in ipairs(n.children or {}) do
		if child.lazyKind == "archive_expansion" then
			collectActivityFilterItems(child, out, seen)
		elseif child.categoryID and not child.categoryBrowse then
			addActivityFilterItem(out, seen, child, index)
		else
			collectActivityFilterItems(child, out, seen)
		end
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

local function collectVisibleFilterGroupIDs(n, out, seen)
	if not n or n.disabled or n.categoryBrowse then
		return
	end
	if n.lazyKind and not n.childrenLoaded then
		GF.NavData.EnsureChildren(n)
	end
	addFilterActivityGroupID(out, seen, n.groupID)
	if n.activityID then
		addFilterActivityGroupIDForActivity(out, seen, n.activityID)
	end
	for _, activityID in ipairs(n.activityIDsFilter or {}) do
		addFilterActivityGroupIDForActivity(out, seen, activityID)
	end
	for _, child in ipairs(n.children or {}) do
		collectVisibleFilterGroupIDs(child, out, seen)
	end
end

local function resolveCategoryFilterMask(categoryID, rawFilters)
	local normalized = normalizeSearchFilters(categoryID, rawFilters)
	local resolver = GF.Filter and GF.Filter.ResolveCategoryFilters
	if type(resolver) == "function" then
		return GF.Filter:ResolveCategoryFilters(categoryID, normalized)
	end
	return normalized
end

local function baseSearchScope(n)
	local categoryID = n.categoryID
	local rawFilters = n.searchFilters
	if rawFilters == nil then
		rawFilters = n.filters or 0
	end
	local preferred = n.searchPreferredFilters
	if preferred == nil then
		preferred = n.preferredFilters
	end
	return {
		categoryID = categoryID,
		filters = resolveCategoryFilterMask(categoryID, rawFilters),
		preferredFilters = normalizeSearchPreferredFilters(categoryID, preferred),
		groupID = n.groupID,
		activityID = nil,
		activityIDsFilter = nil,
		categoryBrowse = n.categoryBrowse,
		navKind = n.navKind,
	}
end

local function cacheScopeActivityIDs(n, producer)
	if n._gfScopeActivityIDs then
		return n._gfScopeActivityIDs
	end
	local ids = producer()
	if type(ids) == "table" and #ids > 0 then
		n._gfScopeActivityIDs = ids
		return ids
	end
	return nil
end

local function collectLoadedNodeActivityIDs(n, fallback)
	if n.lazyKind and not n.childrenLoaded then
		GF.NavData.EnsureChildren(n)
	end
	local ids = {}
	collectActivityIDs(n, ids)
	if #ids == 0 and type(fallback) == "function" then
		ids = fallback() or {}
	end
	return #ids > 0 and ids or nil
end

local function aggregateSearchActivityIDs(n)
	if n.categoryBrowse then
		return nil
	end
	local isTopLazyRoot = (n.level or 0) == 0 and n.lazyKind
		and not n.activityID and not n.groupID
	if isTopLazyRoot then
		local rootIDs = cacheScopeActivityIDs(n, function()
			return collectL0ScopeActivityIDs(n)
		end)
		if rootIDs then
			return rootIDs
		end
	end
	if n.lazyKind == "delve_filter" then
		return cacheScopeActivityIDs(n, function()
			return collectLoadedNodeActivityIDs(n, function()
				return collectDelveFilterActivityIDs(n.filters or PVE, n.fallbackFilters)
			end)
		end)
	end
	if n.lazyKind == "archive_expansion" and n.catalogKind and n.expansionIndex ~= nil then
		return cacheScopeActivityIDs(n, function()
			return collectLoadedNodeActivityIDs(n, function()
				return collectCatalogExpansionActivityIDs(n.catalogKind, n.expansionIndex)
			end)
		end)
	end
	local aggregatesChildren = n.children and (
		(n.level or 0) > 0
		or n.navKind == "pvp"
		or GF.NavData.IsSeasonHotL0(n)
	)
	if aggregatesChildren then
		return cacheScopeActivityIDs(n, function()
			return collectLoadedNodeActivityIDs(n)
		end)
	end
	return nil
end

function GF.NavData.ResolveSearchScope(n, opts)
	if not n or not n.categoryID then
		return nil
	end
	local scope = baseSearchScope(n)
	if n.activityIDsFilter and #n.activityIDsFilter > 0 then
		return finishScopeWithActivityIDs(scope, n.activityIDsFilter)
	end
	if n.activityID and not n.categoryBrowse then
		scope.activityID = n.activityID
		if n.categoryID == GF.CAT_CUSTOM then
			addResultActivityID(scope, n.activityID)
			scope._seenResultActivityIDs = nil
			return scope
		end
		return finishScopeWithActivityIDs(scope, { n.activityID })
	end
	if n.groupID and not n.categoryBrowse then
		if GF.NavData.IsSeasonHotL0(n) then
			local activityIDs = aggregateSearchActivityIDs(n)
			return activityIDs and finishScopeWithActivityIDs(scope, activityIDs) or nil
		end
		if not n._gfGroupActivityIDs then
			n._gfGroupActivityIDs = getCatalogGroupActivityIDs(
				n.categoryID,
				n.groupID,
				n.filters or 0,
				scope.preferredFilters
			)
		end
		return finishScopeWithActivityIDs(scope, n._gfGroupActivityIDs)
	end
	if GF.NavData.IsSeasonHotL0(n) then
		local activityIDs = aggregateSearchActivityIDs(n)
		if not activityIDs then
			return nil
		end
		return finishScopeWithActivityIDs(scope, activityIDs)
	end
	if opts and opts.forSearch == true then
		finishScopeWithActivityIDs(scope, aggregateSearchActivityIDs(n))
	end
	return scope
end

function GF.NavData.ResolveSearchScopes(n, opts)
	if n ~= nil then
		return collectSearchScopesForNode(n, opts)
	end
	local scopes = {}
	for _, root in ipairs(GF.NavData.GetTree()) do
		if root.navKind ~= "history" and not root.disabled then
			local rootScopes = collectSearchScopesForNode(root, opts)
			appendSearchScopes(scopes, rootScopes)
		end
	end
	return scopes
end

function GF.NavData.GetFilterActivityGroupIDs(navKind)
	local root = rootByNavKind(navKind)
	if root == nil then
		return {}
	end
	local groupIDs, seen = {}, {}
	collectVisibleFilterGroupIDs(root, groupIDs, seen)
	return groupIDs
end

function GF.NavData.GetFilterActivityItems(navKind)
	local root = rootByNavKind(navKind)
	if root == nil then
		return {}
	end
	local items, seen = {}, {}
	collectActivityFilterItems(root, items, seen)
	local function filterItemComesBefore(left, right)
		local leftOrder = tonumber(left and left.orderIndex) or 0
		local rightOrder = tonumber(right and right.orderIndex) or 0
		if leftOrder == rightOrder then
			return tostring(left and left.label or "") < tostring(right and right.label or "")
		end
		return leftOrder < rightOrder
	end
	table.sort(items, filterItemComesBefore)
	return items
end

function GF.NavData.GetSearchBlockHint(n)
	return nil
end

function GF.NavData.IsSearchable(n)
	if n == nil or n.disabled then
		return false
	end
	if GF.NavData.IsSeasonHotL0(n) then
		if n.lazyKind and not n.childrenLoaded then
			GF.NavData.EnsureChildren(n)
		end
		local activityIDs = {}
		collectActivityIDs(n, activityIDs)
		return #activityIDs > 0
	end
	return n.categoryBrowse == true or n.activityID ~= nil or n.categoryID ~= nil
end

function GF.NavData.AcceptsBrowseSelection(n)
	local unavailable = n == nil
	if not unavailable then
		unavailable = n.disabled and true or false
	end
	if unavailable then
		return false
	end
	local blockHint = GF.NavData.GetSearchBlockHint(n)
	if blockHint then
		return true
	end
	local searchable = GF.NavData.IsSearchable(n)
	return searchable
end

function GF.NavData.ResolveCreateActivityID(n)
	local concrete = n and not n.categoryBrowse
	return concrete and n.activityID or nil
end

function GF.NavData.IsCreateable(n)
	return n ~= nil and not n.disabled and not not n.categoryID
		and GF.NavData.ResolveCreateActivityID(n) ~= nil
end

function GF.NavData.FindNodeByActivityID(activityID)
	if not activityID then
		return nil
	end
	local roots, pending = GF.NavData.GetTree(), {}
	for index = #roots, 1, -1 do
		pending[#pending + 1] = roots[index]
	end
	while #pending > 0 do
		local current = table.remove(pending)
		if current.activityID == activityID and not current.categoryBrowse then
			return current
		end
		if current.lazyKind and not current.childrenLoaded then
			GF.NavData.EnsureChildren(current)
		end
		for index = #(current.children or {}), 1, -1 do
			pending[#pending + 1] = current.children[index]
		end
	end
	return nil
end

function GF.NavData.FindSeasonDungeonNodeByActivityID(activityID)
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
	local root = rootByNavKind("season_dungeon")
	if root == nil then
		return nil
	end
	if root.lazyKind and not root.childrenLoaded then
		GF.NavData.EnsureChildren(root)
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

function GF.NavData.RequestRefresh()
	local request = C_LFGList and C_LFGList.RequestAvailableActivities
	if type(request) == "function" then
		request()
	end
end
