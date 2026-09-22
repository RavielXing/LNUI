local _, GF = ...

-- SearchScopeCompiler is the boundary between the navigation projection and
-- the operations that consume it.  NavData owns discovery and tree building;
-- this module only compiles already-authorized nodes into detached snapshots.
-- It deliberately does not enumerate activities on its own, so searching,
-- filtering, and creation cannot acquire a second eligibility source.
GF.SearchScopeCompiler = {}
local Compiler = GF.SearchScopeCompiler

local function lfgFilter(name, fallback)
	local filters = Enum and Enum.LFGListFilter
	local value = filters and filters[name]
	return value ~= nil and value or fallback
end

local PVE = lfgFilter("PvE", 0)
local PVP = lfgFilter("PvP", 0)
local RECOMMENDED = lfgFilter("Recommended", 0)
local RECOMMENDED_SEARCH_MASK = GF.RECOMMENDED_SEARCH_MASK or RECOMMENDED

local function isPvPCategory(categoryID)
	for _, category in ipairs(GF.PVP_CATEGORIES or {}) do
		if categoryID == category.id then
			return true
		end
	end
	return false
end

local function band(left, right)
	if bit and type(bit.band) == "function" then
		return bit.band(left or 0, right or 0)
	end
	return 0
end

local function commonFilters(left, right)
	left = tonumber(left) or 0
	right = tonumber(right) or 0
	if bit and type(bit.band) == "function" then
		return bit.band(left, right)
	end
	if left == right then
		return left
	end
	return 0
end

function Compiler.NormalizeFilters(categoryID, filters)
	filters = filters or 0
	if categoryID == GF.CAT_CUSTOM
		or categoryID == GF.CAT_DELVE
		or isPvPCategory(categoryID)
	then
		return 0
	end
	if categoryID == GF.CAT_DUNGEON or categoryID == GF.CAT_RAID then
		local recommended = band(filters, RECOMMENDED_SEARCH_MASK)
		return recommended ~= 0 and recommended or RECOMMENDED
	end
	return filters
end

function Compiler.NormalizePreferredFilters(categoryID, preferredFilters)
	if categoryID == GF.CAT_CUSTOM then
		return 0
	end
	if preferredFilters ~= nil then
		return preferredFilters
	end
	return isPvPCategory(categoryID) and PVP or PVE
end

local function ensureChildren(node)
	if not node or not node.lazyKind or node.childrenLoaded then
		return
	end
	local navData = GF.NavData
	local ensure = navData and navData.EnsureChildren
	if type(ensure) == "function" then
		ensure(node)
	end
end

local function getTree()
	local navData = GF.NavData
	local getter = navData and navData.GetTree
	if type(getter) ~= "function" then
		return {}
	end
	local tree = getter()
	return type(tree) == "table" and tree or {}
end

local function rootByNavKind(navKind)
	if navKind == nil then
		return nil
	end
	for _, root in ipairs(getTree()) do
		if root and root.navKind == navKind then
			return root
		end
	end
	return nil
end

local function isSeasonProjection(node)
	local kind = node and node.navKind
	return kind == "season_dungeon" or kind == "season_raid"
end

local function copyArray(source)
	local copy = {}
	for index, value in ipairs(source or {}) do
		copy[index] = value
	end
	return copy
end

local function addUniqueID(out, seen, activityID)
	activityID = tonumber(activityID)
	if activityID and activityID > 0 and not seen[activityID] then
		seen[activityID] = true
		out[#out + 1] = activityID
	end
end

local function activityInfoForID(activityID)
	local getter = C_LFGList and C_LFGList.GetActivityInfoTable
	if activityID == nil or type(getter) ~= "function" then
		return nil
	end
	local ok, info = pcall(getter, activityID)
	return ok and type(info) == "table" and info or nil
end

local function sourceCategoryID(source, activityID)
	if source and source.categoryID then
		return source.categoryID
	end
	local info = activityInfoForID(activityID)
	return info and info.categoryID or nil
end

local function sourceSearchFilters(source, activityID)
	local byActivity = source and source.activitySearchFiltersByID
	local filters = byActivity and byActivity[activityID]
	if filters == nil and source then
		filters = source.searchFilters
	end
	if filters == nil and source then
		filters = source.filters
	end
	return filters or 0
end

local function sourcePreferredFilters(source, categoryID)
	local preferred = source and source.searchPreferredFilters
	if preferred == nil and source then
		preferred = source.preferredFilters
	end
	return Compiler.NormalizePreferredFilters(categoryID, preferred)
end

local function newScopeAccumulator(source, categoryID, filters, preferredFilters)
	return {
		categoryID = categoryID,
		filters = filters,
		preferredFilters = preferredFilters,
		navKind = source and source.navKind or nil,
		activityIDsFilter = {},
		_seenActivityIDs = {},
	}
end

local function addActivityToScope(scopesByKey, order, source, activityID)
	local categoryID = sourceCategoryID(source, activityID)
	if not categoryID then
		return
	end
	local filters = Compiler.NormalizeFilters(
		categoryID, sourceSearchFilters(source, activityID))
	local preferredFilters = sourcePreferredFilters(source, categoryID)
	local key = table.concat({
		tostring(categoryID),
		tostring(preferredFilters),
		tostring(filters),
	}, ":")
	local scope = scopesByKey[key]
	if not scope then
		scope = newScopeAccumulator(source, categoryID, filters, preferredFilters)
		scopesByKey[key] = scope
		order[#order + 1] = key
	end
	addUniqueID(scope.activityIDsFilter, scope._seenActivityIDs, activityID)
end

local function directActivityIDs(node)
	if node.resultActivityIDsFilter
		and #node.resultActivityIDsFilter > 0
	then
		return node.resultActivityIDsFilter
	end
	if node.activityIDsFilter and #node.activityIDsFilter > 0 then
		return node.activityIDsFilter
	end
	if node.activityID then
		return { node.activityID }
	end
	return nil
end

local function collectExactScopes(node, scopesByKey, order, visited)
	if not node or node.disabled or node.categoryBrowse
		or node.archiveDirectoryOnly == true
	then
		return
	end
	visited = visited or {}
	if visited[node] then
		return
	end
	visited[node] = true
	local activityIDs = directActivityIDs(node)
	if activityIDs then
		for _, activityID in ipairs(activityIDs) do
			addActivityToScope(scopesByKey, order, node, activityID)
		end
		return
	end
	ensureChildren(node)
	for _, child in ipairs(node.children or {}) do
		collectExactScopes(child, scopesByKey, order, visited)
	end
	-- A directory may explicitly include another already-authorized root in its
	-- search meaning without duplicating that root in the visible navigation.
	-- The ordinary Dungeon root uses this to include the separate seasonal
	-- directory, matching the product meaning that seasonal dungeons are still
	-- dungeons. IDs remain deduplicated by the shared scope accumulator.
	for _, navKind in ipairs(node.searchIncludeNavKinds or {}) do
		local includedRoot = rootByNavKind(navKind)
		if includedRoot and includedRoot ~= node then
			collectExactScopes(includedRoot, scopesByKey, order, visited)
		end
	end
end

local function finishExactScopes(scopesByKey, order)
	local scopes = {}
	for _, key in ipairs(order) do
		local source = scopesByKey[key]
		local nativeIDs = source.activityIDsFilter
		local resultIDs = source.resultActivityIDsFilter
		if (nativeIDs and #nativeIDs > 0) or (resultIDs and #resultIDs > 0) then
			local scope = {
				categoryID = source.categoryID,
				filters = source.filters,
				preferredFilters = source.preferredFilters,
				navKind = source.navKind,
			}
			if nativeIDs and #nativeIDs > 0 then
				scope.activityIDsFilter = copyArray(nativeIDs)
			end
			if resultIDs and #resultIDs > 0 then
				scope.resultActivityIDsFilter = copyArray(resultIDs)
			end
			scopes[#scopes + 1] = scope
		end
	end
	return scopes
end

local function compileBroadScope(node)
	local categoryID = node and node.categoryID
	if not categoryID then
		return nil
	end
	local rawFilters = node.searchFilters
	if rawFilters == nil then
		rawFilters = node.filters or 0
	end
	local filters = Compiler.NormalizeFilters(categoryID, rawFilters)
	local resolver = GF.Filter and GF.Filter.ResolveCategoryFilters
	if type(resolver) == "function" then
		filters = GF.Filter:ResolveCategoryFilters(categoryID, filters)
	end
	return {
		categoryID = categoryID,
		filters = filters,
		preferredFilters = sourcePreferredFilters(node, categoryID),
		groupID = node.groupID,
		categoryBrowse = node.categoryBrowse,
		navKind = node.navKind,
	}
end

local function archiveAggregateActivityIDs(node)
	if not (node and node.archiveAggregateDirectory == true) then
		return nil
	end
	local catalog = GF.NavCatalog
	local getter = catalog and catalog.GetAggregateActivityIDs
	if type(getter) ~= "function" then
		return nil
	end
	local ids = getter(node.catalogKind or node.navKind, node.expansionIndex)
	if type(ids) ~= "table" or #ids == 0 then
		return nil
	end
	return copyArray(ids)
end

local function compileArchiveAggregateScope(node)
	local categoryID = node and node.categoryID
	if not categoryID then
		return nil
	end
	local scope = {
		categoryID = categoryID,
		-- Archive aggregation is a Browse operation, not an authorization pass.
		-- Search the complete native category once; Recommended would silently
		-- omit valid historical listings.
		filters = 0,
		archiveAggregateSearch = true,
		preferredFilters = sourcePreferredFilters(node, categoryID),
		navKind = node.navKind,
	}
	local activityIDs = archiveAggregateActivityIDs(node)
	if node.archiveAggregateDirectory == true then
		if not activityIDs then
			return nil
		end
		-- Packaged IDs only describe which search results belong to this expansion.
		-- They never become creation authority on the directory node.
		scope.resultActivityIDsFilter = activityIDs
	end
	return scope
end

local function compileNodeScopes(node)
	if not node or node.disabled then
		return {}
	end
	if node.archiveAggregateRoot == true
		or node.archiveAggregateDirectory == true
	then
		local scope = compileArchiveAggregateScope(node)
		return scope and { scope } or {}
	end
	if node.archiveDirectoryOnly == true then
		return {}
	end
	local scopesByKey, order = {}, {}
	collectExactScopes(node, scopesByKey, order, {})
	local scopes = finishExactScopes(scopesByKey, order)
	if #scopes > 0 then
		return scopes
	end
	-- Seasonal directories are exact projections.  An empty projection must
	-- never degrade into a broad dungeon or raid search.
	if isSeasonProjection(node) then
		return {}
	end
	local broad = compileBroadScope(node)
	return broad and { broad } or {}
end

function Compiler.ResolveSearchScopes(node, options)
	if node ~= nil then
		return compileNodeScopes(node, options)
	end
	local scopes = {}
	for _, root in ipairs(getTree()) do
		if not root.quickSearchRoot and not root.disabled then
			for _, scope in ipairs(compileNodeScopes(root, options)) do
				scopes[#scopes + 1] = scope
			end
		end
	end
	return scopes
end

local function mergeCompatibleScopes(scopes)
	if #scopes == 0 then
		return nil
	end
	if #scopes == 1 then
		return scopes[1]
	end
	local first = scopes[1]
	local categoryID = first.categoryID
	local preferredFilters = first.preferredFilters
	local filters = first.filters or 0
	local nativeIDs, resultIDs = {}, {}
	local seenNative, seenResult = {}, {}
	for _, scope in ipairs(scopes) do
		if scope.categoryID ~= categoryID
			or scope.preferredFilters ~= preferredFilters
		then
			return nil
		end
		-- A merged exact projection keeps only the native filter bits shared
		-- by every child. Recommended and NotRecommended are disjoint search
		-- partitions, so OR-ing them can produce an impossible request.
		filters = commonFilters(filters, scope.filters)
		for _, activityID in ipairs(scope.activityIDsFilter or {}) do
			addUniqueID(nativeIDs, seenNative, activityID)
		end
		for _, activityID in ipairs(scope.resultActivityIDsFilter or {}) do
			addUniqueID(resultIDs, seenResult, activityID)
		end
	end
	if #nativeIDs == 0 and #resultIDs == 0 then
		return nil
	end
	local merged = {
		categoryID = categoryID,
		filters = filters,
		preferredFilters = preferredFilters,
		navKind = first.navKind,
	}
	if #nativeIDs > 0 then
		merged.activityIDsFilter = nativeIDs
	end
	if #resultIDs > 0 then
		merged.resultActivityIDsFilter = resultIDs
	end
	return merged
end

function Compiler.ResolveSearchScope(node, options)
	if node == nil then
		return nil
	end
	return mergeCompatibleScopes(Compiler.ResolveSearchScopes(node, options))
end

local function collectActivityIDs(node, out, seen)
	if not node or node.disabled or node.categoryBrowse then
		return
	end
	local direct = directActivityIDs(node)
	if direct then
		for _, activityID in ipairs(direct) do
			addUniqueID(out, seen, activityID)
		end
		return
	end
	ensureChildren(node)
	for _, child in ipairs(node.children or {}) do
		collectActivityIDs(child, out, seen)
	end
end

local function uniqueActivityIDs(node)
	local activityIDs, seen = {}, {}
	collectActivityIDs(node, activityIDs, seen)
	return activityIDs
end

local function activityGroupIDs(activityIDs)
	local groupIDs, seen = {}, {}
	for _, activityID in ipairs(activityIDs or {}) do
		local info = activityInfoForID(activityID)
		local groupID = tonumber(info and info.groupFinderActivityGroupID)
		if groupID and groupID > 0 and not seen[groupID] then
			seen[groupID] = true
			groupIDs[#groupIDs + 1] = groupID
		end
	end
	table.sort(groupIDs)
	return groupIDs
end

local function joinedIDs(ids)
	local sorted = copyArray(ids)
	table.sort(sorted, function(left, right)
		return (tonumber(left) or 0) < (tonumber(right) or 0)
	end)
	for index, value in ipairs(sorted) do
		sorted[index] = tostring(value)
	end
	return table.concat(sorted, ",")
end

local function filterItemKey(node, activityIDs, groupIDs)
	if node.groupID then
		return "g:" .. tostring(node.groupID)
	end
	if #groupIDs > 0 then
		return "g:" .. joinedIDs(groupIDs)
	end
	if #activityIDs > 0 then
		return "a:" .. joinedIDs(activityIDs)
	end
	return node.key
end

local function addFilterItem(out, seen, node, ordinal)
	if not node or node.disabled or node.categoryBrowse then
		return
	end
	ensureChildren(node)
	local activityIDs = uniqueActivityIDs(node)
	if #activityIDs == 0 then
		return
	end
	local groupIDs = activityGroupIDs(activityIDs)
	local key = filterItemKey(node, activityIDs, groupIDs)
	if not key or seen[key] then
		return
	end
	seen[key] = true
	out[#out + 1] = {
		key = key,
		label = node.label or "?",
		activityIDs = copyArray(activityIDs),
		groupIDs = copyArray(groupIDs),
		groupID = node.groupID,
		activityID = node.activityID,
		navKind = node.navKind,
		categoryID = node.categoryID,
		orderIndex = ordinal or tonumber(node.orderIndex) or #out + 1,
		nodeKey = node.key,
	}
end

local function collectFilterItems(node, out, seen)
	if not node or node.disabled or node.categoryBrowse
		or node.archiveDirectoryOnly == true
	then
		return
	end
	ensureChildren(node)
	for index, child in ipairs(node.children or {}) do
		if child.lazyKind == "archive_expansion" then
			collectFilterItems(child, out, seen)
		elseif child.categoryID and not child.categoryBrowse then
			addFilterItem(out, seen, child, index)
		else
			collectFilterItems(child, out, seen)
		end
	end
end

function Compiler.GetFilterActivityItems(navKind)
	local root = rootByNavKind(navKind)
	if not root then
		return {}
	end
	local items, seen = {}, {}
	collectFilterItems(root, items, seen)
	table.sort(items, function(left, right)
		local leftOrder = tonumber(left and left.orderIndex) or 0
		local rightOrder = tonumber(right and right.orderIndex) or 0
		if leftOrder == rightOrder then
			return tostring(left and left.label or "")
				< tostring(right and right.label or "")
		end
		return leftOrder < rightOrder
	end)
	return items
end

function Compiler.GetSearchBlockHint(node)
	if not (node and node.navKind == "pvp" and (node.level or 0) == 0) then
		return nil
	end
	ensureChildren(node)
	local categories, count = {}, 0
	for _, child in ipairs(node.children or {}) do
		local categoryID = child and child.categoryID
		if categoryID and not categories[categoryID] then
			categories[categoryID] = true
			count = count + 1
		end
	end
	if count <= 1 then
		return nil
	end
	local L = GF.L or {}
	return L.BROWSE_SELECT_PVP_SUBCATEGORY
		or "Select a subcategory to load group listings automatically."
end

function Compiler.IsSearchable(node)
	if not node or node.disabled or Compiler.GetSearchBlockHint(node)
	then
		return false
	end
	if node.archiveAggregateRoot == true
		or node.archiveAggregateDirectory == true
	then
		return #compileNodeScopes(node) > 0
	end
	if node.archiveDirectoryOnly == true then
		return false
	end
	if isSeasonProjection(node) then
		return #compileNodeScopes(node) > 0
	end
	return node.categoryBrowse == true
		or node.activityID ~= nil
		or node.categoryID ~= nil
end

function Compiler.AcceptsBrowseSelection(node)
	if not node or node.disabled then
		return false
	end
	if node.archiveAggregateRoot == true
		or node.archiveAggregateDirectory == true
	then
		return Compiler.IsSearchable(node)
	end
	if node.archiveDirectoryOnly == true then
		return false
	end
	if Compiler.GetSearchBlockHint(node) then
		return true
	end
	return Compiler.IsSearchable(node)
end

function Compiler.ResolveCreateActivityID(node)
	if not node or node.disabled or node.categoryBrowse or not node.categoryID then
		return nil
	end
	return node.activityID
end

function Compiler.CanCreateFromNode(node)
	return Compiler.ResolveCreateActivityID(node) ~= nil
end

-- Compilation is intentionally stateless.  The hook remains so NavData can
-- keep its compatibility API while callers that rebuild nodes need no special
-- knowledge of the compiler implementation.
function Compiler.InvalidateNode()
	return false
end
