local _, GF = ...

local QuickSearch = {}
GF.QuickSearch = QuickSearch

local RESULT_LIMIT = 40
local SEARCH_ROOT_KINDS = {
	season_dungeon = true,
	season_raid = true,
	dungeon = true,
	raid = true,
}
local UTF8_PUNCTUATION = {
	"：", "（", "）", "【", "】", "「", "」", "『", "』",
	"《", "》", "〈", "〉", "、", "，", "。", "；",
	"！", "？", "—", "–", "·", "…", "“", "”", "‘", "’", "　",
}

local function cleanText(value)
	return type(value) == "string" and value ~= "" and value or nil
end

local function normalizeText(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	value = value:gsub("|[cC]%x%x%x%x%x%x%x%x", "")
		:gsub("|[cC][nN][%w_]+:", "")
		:gsub("|[rR]", "")
		:gsub("|[tT].-|[tT]", "")
		:gsub("|[aA].-|[aA]", "")
		:gsub("[%s%p%c]+", "")
	-- Lua patterns operate on bytes. A character class containing UTF-8
	-- punctuation also matches individual bytes inside ordinary Han characters.
	-- Remove multibyte punctuation as complete literal strings instead.
	for _, punctuation in ipairs(UTF8_PUNCTUATION) do
		value = value:gsub(punctuation, "")
	end
	if value == "" then
		return nil
	end
	return string.lower(value)
end

QuickSearch.NormalizeText = normalizeText

local function addSearchToken(entry, value)
	local token = normalizeText(value)
	if not token or entry._searchTokenSet[token] then
		return
	end
	entry._searchTokenSet[token] = true
	entry.searchTokens[#entry.searchTokens + 1] = token
end

local function ensureChildren(node)
	local ensure = GF.NavData and GF.NavData.EnsureChildren
	if node and node.lazyKind and node.childrenLoaded ~= true and ensure then
		ensure(node)
	end
	return node and node.children or {}
end

local function activityBaseName(info)
	local resolver = GF.ActivityInfo and GF.ActivityInfo.GetActivityBaseName
	return type(resolver) == "function" and resolver(info) or nil
end

local function sourceLabel(source)
	local info = source and source.activityInfo
	return cleanText(activityBaseName(info))
		or cleanText(source and source.label)
		or "?"
end

local function sourceIdentity(source, label, breadcrumb)
	local archiveIdentity = source.archiveIdentity
		or source.archiveShell and source.archiveShell.identity
	if archiveIdentity then
		return table.concat({
			"archive",
			tostring(source.navKind or source.catalogKind or "?"),
			tostring(source.expansionIndex or "?"),
			tostring(archiveIdentity),
		}, ":")
	end
	if source.journalInstanceID then
		return "journal:" .. tostring(source.journalInstanceID)
	end
	if source.instanceMapID then
		return "instance-map:" .. tostring(source.instanceMapID)
	end
	if source.mapID then
		return "map:" .. tostring(source.mapID)
	end
	local normalized = normalizeText(label) or tostring(source.key or "unknown")
	local structuralGroupID = source.groupID
		or source.archiveShell and source.archiveShell.groupID
	local structuralActivityID = source.activityID
		or source.archiveShell and source.archiveShell.activityID
	if structuralGroupID then
		return table.concat({
			"group",
			tostring(source.categoryID or 0),
			tostring(structuralGroupID),
			normalized,
			normalizeText(breadcrumb) or "",
		}, ":")
	end
	if structuralActivityID then
		return "activity:" .. tostring(structuralActivityID)
	end
	return "node:" .. tostring(source.key or normalized)
end

local function sourceIdentityAliases(source, canonical)
	local aliases, seen = {}, {}
	local function add(value)
		if value and not seen[value] then
			seen[value] = true
			aliases[#aliases + 1] = value
		end
	end
	add(canonical)
	if source.journalInstanceID then
		add("journal:" .. tostring(source.journalInstanceID))
	end
	if source.instanceMapID then
		add("instance-map:" .. tostring(source.instanceMapID))
	end
	if source.mapID then
		add("map:" .. tostring(source.mapID))
	end
	return aliases
end

local function addSourceSearchTokens(entry, source)
	-- The result row represents this instance. Hidden difficulty descendants must
	-- not make an unrelated parent match through their activity names.
	addSearchToken(entry, source and source.label)
	addSearchToken(entry, source and source.activityInfo
		and activityBaseName(source.activityInfo))
	for _, alias in ipairs(source and source.searchAliases or {}) do
		addSearchToken(entry, alias)
	end
end

local function addSource(index, byIdentity, bySource, source, breadcrumb, rootKind, order)
	if not source then
		return
	end
	local label = sourceLabel(source)
	local identity = sourceIdentity(source, label, breadcrumb)
	local aliases = sourceIdentityAliases(source, identity)
	local entry
	for _, alias in ipairs(aliases) do
		entry = entry or byIdentity[alias]
	end
	if not entry then
		entry = {
			identity = identity,
			label = label,
			breadcrumb = breadcrumb,
			rootKind = rootKind,
			order = order,
			currentSeason = rootKind == "season_dungeon"
				or rootKind == "season_raid",
			canonicalToken = normalizeText(label),
			sources = {},
			searchTokens = {},
			_searchTokenSet = {},
		}
		byIdentity[identity] = entry
		index[#index + 1] = entry
	else
		entry.currentSeason = entry.currentSeason
			or rootKind == "season_dungeon"
			or rootKind == "season_raid"
	end
	for _, alias in ipairs(aliases) do
		byIdentity[alias] = entry
	end
	entry.sources[#entry.sources + 1] = source
	bySource[source] = entry
	addSearchToken(entry, label)
	addSourceSearchTokens(entry, source)
end

local function buildIndex()
	local index, byIdentity, bySource = {}, {}, {}
	local getTree = GF.NavData and GF.NavData.GetTree
	local tree = type(getTree) == "function" and getTree() or GF.navTree or {}
	local order = 0
	for _, root in ipairs(tree) do
		local rootKind = root and root.navKind
		if SEARCH_ROOT_KINDS[rootKind] then
			local rootChildren = ensureChildren(root)
			if rootKind == "dungeon" or rootKind == "raid" then
				for _, expansion in ipairs(rootChildren) do
					local breadcrumb = cleanText(expansion.label)
					for _, source in ipairs(ensureChildren(expansion)) do
						order = order + 1
						addSource(index, byIdentity, bySource, source, breadcrumb, rootKind, order)
					end
				end
			else
				for _, source in ipairs(rootChildren) do
					order = order + 1
					addSource(index, byIdentity, bySource, source, cleanText(root.label), rootKind, order)
				end
			end
		end
	end
	for _, entry in ipairs(index) do
		entry._searchTokenSet = nil
	end
	return index, byIdentity, bySource
end

local function ensureIndex(owner)
	if owner.index == nil then
		owner.index, owner.entriesByIdentity, owner.entriesBySource = buildIndex()
	end
	return owner.index
end

local function nodeAllowedForTab(node, tabID)
	if not node or node.disabled then
		return false
	end
	local workspace = GF.LFGWorkspaceView
	if workspace and workspace.IsNodeAllowed and not workspace:IsNodeAllowed(node) then
		return false
	end
	if tabID == GF.TAB_CREATE then
		if node.browseOnly then
			return false
		end
		if workspace and workspace.CanCreateSelection then
			return workspace:CanCreateSelection(node) == true
		end
		local canCreate = GF.NavData and GF.NavData.CanCreateFromNode
		return type(canCreate) == "function" and canCreate(node) == true
	end
	local accepts = GF.NavData and GF.NavData.AcceptsBrowseSelection
	return type(accepts) == "function" and accepts(node) == true
end

local function collectLeafTargets(source, out)
	if not source then
		return
	end
	if source.isLeaf then
		out[#out + 1] = source
		return
	end
	for _, child in ipairs(ensureChildren(source)) do
		collectLeafTargets(child, out)
	end
end

local function difficultyIdentity(target)
	local info = target and target.activityInfo
	local merge = GF.ActivityInfo and GF.ActivityInfo.GetActivityDifficultyMergeKey
	local difficultyKey = type(merge) == "function" and merge(info) or nil
	if difficultyKey then
		return table.concat({
			"difficulty",
			tostring(target.categoryID or 0),
			tostring(target.groupID or 0),
			difficultyKey,
		}, ":")
	end
	return "activity:" .. tostring(target.activityID or target.key)
end

local function difficultyLabel(target)
	local info = target and target.activityInfo
	local resolver = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyLabel
	local label = type(resolver) == "function"
		and resolver(info, { includeMplus = true }) or nil
	return cleanText(info and info.fullName)
		or cleanText(target and target.label)
		or cleanText(label)
		or "?"
end

local function difficultyOrder(target, ordinal)
	local info = target and target.activityInfo
	local resolver = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyIndex
	local difficultyIndex = type(resolver) == "function"
		and resolver(info, { includeMplus = true }) or nil
	local playerCountResolver = GF.ActivityInfo and GF.ActivityInfo.GetDifficultyPlayerCount
	local playerCount = type(playerCountResolver) == "function"
		and playerCountResolver(info) or nil
	if difficultyIndex then
		return (difficultyIndex * 1000) + (tonumber(playerCount) or 0)
	end
	return tonumber(target and target.sortIndex)
		or tonumber(target and target.orderIndex)
		or (10000 + ordinal)
end

local function buildDifficultyNodes(entry, tabID, generation)
	local targets, seen, nodes = {}, {}, {}
	local unresolvedArchive = {}
	local function collectSource(source)
		local leaves = {}
		collectLeafTargets(source, leaves)
		for _, target in ipairs(leaves) do
			if nodeAllowedForTab(target, tabID) then
				local identity = difficultyIdentity(target)
				if not seen[identity] then
					seen[identity] = true
					targets[#targets + 1] = target
				end
			end
		end
	end
	for _, source in ipairs(entry.sources) do
		if source.archiveInstanceShell == true
			and source.childrenLoaded ~= true
		then
			unresolvedArchive[#unresolvedArchive + 1] = source
		else
			collectSource(source)
		end
	end
	-- A Journal/map alias can join a current-season source and one or more
	-- archive shells. Loaded sources are sufficient; only when none yields an
	-- allowed difficulty may this interaction authorize one archive shell.
	if #targets == 0 and unresolvedArchive[1] then
		collectSource(unresolvedArchive[1])
	end
	for ordinal, target in ipairs(targets) do
		local semanticIdentity = difficultyIdentity(target)
		nodes[#nodes + 1] = {
			key = table.concat({
				"quick_search::difficulty", entry.identity,
				tostring(tabID), semanticIdentity,
			}, "::"),
			level = 2,
			label = difficultyLabel(target),
			isLeaf = true,
			navKind = "quick_search",
			quickSearchIdentity = entry.identity,
			quickSearchTarget = target,
			quickSearchTargetKey = target.key,
			quickSearchDifficulty = true,
			_gfQuickSearchProxy = true,
			_gfQuickSearchGeneration = generation,
			_quickSearchOrder = difficultyOrder(target, ordinal),
		}
	end
	table.sort(nodes, function(left, right)
		if left._quickSearchOrder == right._quickSearchOrder then
			return tostring(left.label) < tostring(right.label)
		end
		return left._quickSearchOrder < right._quickSearchOrder
	end)
	local labelCounts = {}
	for _, node in ipairs(nodes) do
		local key = normalizeText(node.label) or node.label
		labelCounts[key] = (labelCounts[key] or 0) + 1
	end
	for _, node in ipairs(nodes) do
		local key = normalizeText(node.label) or node.label
		if labelCounts[key] and labelCounts[key] > 1 then
			node.label = cleanText(node.quickSearchTarget and node.quickSearchTarget.label)
				or node.label
		end
		node._quickSearchOrder = nil
	end
	return nodes
end

local function tokenMatchKind(token, query)
	if token == query then
		return 1
	end
	if token:sub(1, #query) == query then
		return 2
	end
	if token:find(query, 1, true) then
		return 3
	end
end

local function matchScore(entry, query)
	local best
	for _, token in ipairs(entry.searchTokens) do
		local kind = tokenMatchKind(token, query)
		-- Preserve exact > prefix > contains, while making the visible canonical
		-- name win over an alias inside each matching tier.
		local score = kind and ((kind * 2)
			- (token == entry.canonicalToken and 1 or 0)) or nil
		if score and (not best or score < best) then
			best = score
		end
	end
	return best
end

local function placeholderNode(noResults)
	local L = GF.L or {}
	return {
		key = noResults and "quick_search::state::none" or "quick_search::state::empty",
		level = 1,
		label = noResults
			and (L.QUICK_SEARCH_NO_RESULTS or "No matching instances")
			or (L.QUICK_SEARCH_EMPTY or "Enter an instance name to search"),
		isLeaf = false,
		disabled = true,
		navKind = "quick_search",
		_gfQuickSearchProxy = true,
	}
end

function QuickSearch:CreatePlaceholderNode(noResults)
	return placeholderNode(noResults == true)
end

function QuickSearch:GetQuery(tabID)
	self.queryByTab = self.queryByTab or {}
	return self.queryByTab[tabID or GF.TAB_BROWSE] or ""
end

function QuickSearch:SetQuery(tabID, value)
	self.queryByTab = self.queryByTab or {}
	tabID = tabID or GF.TAB_BROWSE
	value = type(value) == "string" and value or ""
	if self.queryByTab[tabID] ~= value then
		self.queryByTab[tabID] = value
		self.generation = (self.generation or 0) + 1
	end
	return value
end

function QuickSearch:GetGeneration()
	return self.generation or 0
end

function QuickSearch:Invalidate()
	self.index = nil
	self.entriesByIdentity = nil
	self.entriesBySource = nil
	self.generation = (self.generation or 0) + 1
end

function QuickSearch:GetIndex()
	return ensureIndex(self)
end

function QuickSearch:GetEntryByIdentity(identity)
	if type(identity) ~= "string" or identity == "" then
		return nil
	end
	ensureIndex(self)
	return self.entriesByIdentity and self.entriesByIdentity[identity] or nil
end

function QuickSearch:PeekEntryByIdentity(identity)
	return self.entriesByIdentity and self.entriesByIdentity[identity] or nil
end

function QuickSearch:IsIndexBuilt()
	return self.index ~= nil
end

function QuickSearch:GetEntryForNode(node)
	if not node then
		return nil
	end
	local identity = node.favoriteIdentity or node.quickSearchIdentity
	if identity then
		return self:GetEntryByIdentity(identity)
	end
	ensureIndex(self)
	local direct = self.entriesBySource and self.entriesBySource[node]
	if direct then
		return direct
	end
	local findPath = GF.NavTree and GF.NavTree.FindNodePathByKey
	local path
	if type(findPath) == "function" then
		local _, resolvedPath = GF.NavTree:FindNodePathByKey(node.key)
		path = resolvedPath
	end
	for index = #(path or {}), 1, -1 do
		local entry = self.entriesBySource and self.entriesBySource[path[index]]
		if entry then
			return entry
		end
	end
	return nil
end

function QuickSearch:BuildDifficultyNodes(entry, tabID)
	if not entry then
		return {}
	end
	return buildDifficultyNodes(entry, tabID or GF.TAB_BROWSE, self:GetGeneration())
end

function QuickSearch:ResolveEntrySource(entry, tabID)
	for _, source in ipairs(entry and entry.sources or {}) do
		if nodeAllowedForTab(source, tabID or GF.TAB_BROWSE) then
			return source
		end
	end
	return nil
end

local function buildResultNodes(entries, tabID, generation)
	local labelCounts = {}
	for _, entry in ipairs(entries) do
		local key = normalizeText(entry.label) or entry.label
		labelCounts[key] = (labelCounts[key] or 0) + 1
	end
	local results = {}
	for index = 1, math.min(#entries, RESULT_LIMIT) do
		local entry = entries[index]
		local label = entry.label
		local labelKey = normalizeText(label) or label
		if labelCounts[labelKey] and labelCounts[labelKey] > 1 and entry.breadcrumb then
			label = string.format("%s |cff888888· %s|r", label, entry.breadcrumb)
		end
		results[#results + 1] = {
			key = "quick_search::result::" .. entry.identity,
			level = 1,
			label = label,
			isLeaf = false,
			navKind = "quick_search",
			quickSearchIdentity = entry.identity,
			quickSearchTabID = tabID,
			lazyKind = "quick_search_result",
			childrenLoaded = false,
			quickSearchResult = true,
			_gfQuickSearchProxy = true,
			_gfQuickSearchGeneration = generation,
		}
	end
	return results
end

local function recentStorage(create)
	local schema = GF.SettingsSchema
	local database = GF.GetDB and GF.GetDB()
	local characterKey = GF.GetCurrentCharacterKey and GF.GetCurrentCharacterKey()
	local list = schema and schema.GetCharacterRecentInstances
		and schema:GetCharacterRecentInstances(database, characterKey, create)
	return list, schema, database, characterKey
end

local function findLoadedRecentTarget(record)
	local nav = GF.NavData
	local children = nav and nav.GetLoadedTree and nav.GetLoadedTree() or {}
	local target
	for index, key in ipairs(record.path) do
		target = nil
		for _, node in ipairs(children) do
			if node.key == key then target = node; break end
		end
		if not target or index == 1 and target.navKind ~= record.rootKind then return nil end
		children = target.children or {}
	end
	return target
end

local function matchesRecentTarget(record, target)
	if not target or target.key ~= record.nodeKey then return false end
	if record.kind == "activity" then
		return target.isLeaf == true and target.activityID == record.activityID
	end
	return target.isLeaf ~= true
end

function QuickSearch:CaptureRecentInstance(target)
	if type(target) ~= "table" and type(target) ~= "number" then return nil end
	if type(target) == "table" and type(target.key) ~= "string" then return nil end
	local nav = GF.NavData
	local tree = nav and nav.GetLoadedTree and nav.GetLoadedTree()
	local path = {}
	local function visit(node, rootKind)
		path[#path + 1] = node.key
		local matches = type(target) == "table" and node.key == target.key
			or type(target) == "number" and node.isLeaf == true and node.activityID == target
		if matches then
			local activityID = node.isLeaf == true and node.activityID or nil
			if node.isLeaf and not activityID then
				path[#path] = nil
				return nil
			end
			local keys = {}
			for i, key in ipairs(path) do keys[i] = key end
			local label = activityID and difficultyLabel(node) or node.label
			return {
				kind = activityID and "activity" or "scope", activityID = activityID,
				nodeKey = node.key, path = keys, rootKind = rootKind, label = label,
			}
		end
		for _, child in ipairs(node.children or {}) do
			local record = visit(child, rootKind)
			if record then return record end
		end
		path[#path] = nil
	end
	-- A successful action already has a canonical selection. Capture that exact
	-- leaf or aggregate, never its parent instance or another map/journal alias.
	-- History covers all supported activity roots independently of name search.
	local schema = GF.SettingsSchema
	local recentRootKinds = schema and schema.RECENT_INSTANCE_ROOT_KINDS or {}
	for _, root in ipairs(tree or {}) do
		if recentRootKinds[root.navKind] then
			local record = visit(root, root.navKind)
			if record then return record end
		end
	end
end

function QuickSearch:RecordRecentInstance(record)
	if type(record) ~= "table" then return false end
	local _, schema, database, characterKey = recentStorage(false)
	return schema and schema.RecordRecentInstance
		and schema:RecordRecentInstance(database, characterKey, record) or false
end

function QuickSearch:RecordSearch(selection)
	return self:RecordRecentInstance(self:CaptureRecentInstance(selection))
end

function QuickSearch:GetRecentInstanceCount()
	local list = recentStorage(false)
	return list and #list or 0
end

function QuickSearch:ClearRecentInstances()
	local _, schema, database, characterKey = recentStorage(false)
	local cleared = schema and schema.ClearCharacterRecentInstances
		and schema:ClearCharacterRecentInstances(database, characterKey) or false
	if cleared then self.generation = (self.generation or 0) + 1 end
	return cleared
end

function QuickSearch:GetRecentResultNodes(tabID)
	local list = recentStorage(false)
	local results = {}
	for _, record in ipairs(list or {}) do
		if type(record) == "table" then
			local target = findLoadedRecentTarget(record)
			local label = record.label
			if matchesRecentTarget(record, target) then
				label = record.kind == "activity" and difficultyLabel(target) or target.label
			end
			results[#results + 1] = {
				key = "quick_search::recent::" .. record.identity,
				level = 1, label = label, isLeaf = true, navKind = "quick_search",
				quickSearchRecent = true, quickSearchRecord = record,
				disabled = tabID == GF.TAB_CREATE and record.kind == "scope" or nil,
				_gfQuickSearchProxy = true, _gfQuickSearchGeneration = self:GetGeneration(),
			}
		end
	end
	if #results == 0 then return { placeholderNode(false) } end
	return results
end

function QuickSearch:ResolveRecentTarget(proxy, tabID)
	local record = proxy.quickSearchRecord
	if not record or tabID == GF.TAB_CREATE and record.kind ~= "activity" then return nil end
	local nav = GF.NavData
	local children = nav and nav.GetTree and nav.GetTree() or {}
	local target
	for index, key in ipairs(record.path) do
		target = nil
		for _, candidate in ipairs(children) do
			if candidate.key == key then target = candidate; break end
		end
		if not target or target.disabled
			or index == 1 and target.navKind ~= record.rootKind then return nil end
		-- Only an explicit click may realize the saved path, one branch at a
		-- time. Never traverse the full catalog or substitute a similar dungeon.
		if (index < #record.path or target.archiveInstanceShell)
			and target.lazyKind and target.childrenLoaded ~= true then
			if not (nav and nav.EnsureChildren) then return nil end
			nav.EnsureChildren(target)
			if target.disabled then return nil end
		end
		children = target.children or {}
	end
	if matchesRecentTarget(record, target) and nodeAllowedForTab(target, tabID) then
		return target
	end
end

function QuickSearch:GetResultNodes(value, tabID)
	value = self:SetQuery(tabID, value)
	local query = normalizeText(value)
	if not query then
		return self:GetRecentResultNodes(tabID)
	end
	ensureIndex(self)
	local matches = {}
	for _, entry in ipairs(self.index) do
		local score = matchScore(entry, query)
		if score then
			matches[#matches + 1] = { entry = entry, score = score }
		end
	end
	table.sort(matches, function(left, right)
		if left.score ~= right.score then return left.score < right.score end
		if left.entry.currentSeason ~= right.entry.currentSeason then
			return left.entry.currentSeason == true
		end
		if left.entry.order ~= right.entry.order then return left.entry.order < right.entry.order end
		return tostring(left.entry.label) < tostring(right.entry.label)
	end)
	if #matches == 0 then return { placeholderNode(true) } end
	local entries = {}
	for _, match in ipairs(matches) do entries[#entries + 1] = match.entry end
	return buildResultNodes(entries, tabID, self:GetGeneration())
end

function QuickSearch:ResolveTarget(proxy, tabID)
	if not proxy or proxy._gfQuickSearchGeneration ~= self:GetGeneration() then
		return nil
	end
	if proxy.quickSearchRecent then
		return self:ResolveRecentTarget(proxy, tabID or GF.TAB_BROWSE)
	end
	local finder = GF.NavData and GF.NavData.FindNodeByKey
	local target = type(finder) == "function"
		and finder(proxy.quickSearchTargetKey) or nil
	if not target or target.disabled
		or not nodeAllowedForTab(target, tabID or GF.TAB_BROWSE)
	then
		return nil
	end
	return target
end
