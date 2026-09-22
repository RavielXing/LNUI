local _, GF = ...

local FavoriteInstances = {}
GF.FavoriteInstances = FavoriteInstances

local ROOT_KEY = "favorite_instances"
local ACTIVITY_IDENTITY_PREFIX = "activity:"
local PRESET_IDENTITY_PREFIX = "favorite:"
local SCOPE_CHARACTER = "character"
local SCOPE_WARBAND = "warband"
local WARBAND_STORAGE_KEY = "warband"
local EMPTY_RECORDS = {}

local function currentTabID()
	local mainFrame = GF.MainFrame
	return mainFrame and mainFrame.GetCurrentTabID
		and mainFrame:GetCurrentTabID() or GF.TAB_BROWSE
end

local function currentCharacterKey()
	local reader = GF.GetCurrentCharacterKey
	if type(reader) ~= "function" then
		return nil
	end
	local ok, key = pcall(reader)
	return ok and type(key) == "string" and key ~= "" and key or nil
end

local function favoriteRootStorage(create)
	local db = GF.GetDB and GF.GetDB() or nil
	if not db then
		return nil, nil
	end
	local root = db.favoriteInstances
	local needsNormalization = type(root) ~= "table"
	if not needsNormalization then
		for key, value in pairs(root) do
			if (type(key) == "number" and key > 0 and key % 1 == 0)
				or (type(key) == "string" and type(value) ~= "table")
			then
				needsNormalization = true
				break
			end
		end
	end
	local schema = GF.SettingsSchema
	if needsNormalization
		and schema and type(schema.NormalizeFavoriteInstances) == "function"
	then
		root = schema:NormalizeFavoriteInstances(db, currentCharacterKey())
		return type(root) == "table" and root or nil, db
	end
	-- Narrow fallback for isolated tests/partial loads. Production always uses
	-- SettingsSchema so legacy account-list normalization remains centralized.
	if type(db.favoriteInstances) ~= "table" then
		if create ~= true then
			return nil, db
		end
		db.favoriteInstances = {}
	end
	root = db.favoriteInstances
	local characterKey = currentCharacterKey()
	if characterKey and #root > 0 then
		local legacy = {}
		for index, record in ipairs(root) do
			legacy[index] = record
		end
		for key in pairs(root) do
			root[key] = nil
		end
		root[characterKey] = legacy
	end
	return root, db
end

local function scopeRecords(scope, create)
	local root = favoriteRootStorage(create)
	if not root then
		return create == true and nil or EMPTY_RECORDS
	end
	local storageKey
	if scope == SCOPE_WARBAND then
		storageKey = WARBAND_STORAGE_KEY
	else
		storageKey = currentCharacterKey()
		if not storageKey then
			-- Never collapse character favorites into an account fallback bucket
			-- while the stable character identity is warming up.
			return create == true and nil or EMPTY_RECORDS
		end
	end
	local list = root[storageKey]
	if type(list) ~= "table" and create == true then
		list = {}
		root[storageKey] = list
	end
	return type(list) == "table" and list or EMPTY_RECORDS
end

local function makeHandle(scope, identity)
	if (scope ~= SCOPE_CHARACTER and scope ~= SCOPE_WARBAND)
		or type(identity) ~= "string" or identity == ""
	then
		return nil
	end
	return scope .. "::" .. identity
end

local function parseHandle(handle)
	if type(handle) ~= "string" then
		return nil, nil
	end
	local scope, identity = handle:match("^(character)::(.+)$")
	if not scope then
		scope, identity = handle:match("^(warband)::(.+)$")
	end
	return scope, identity
end

local function findInList(list, identity)
	for index, entry in ipairs(list or EMPTY_RECORDS) do
		if entry.identity == identity then
			return entry, index
		end
	end
	return nil, nil
end

local function findRecord(handle)
	local scope, identity = parseHandle(handle)
	if scope then
		local list = scopeRecords(scope)
		local record, index = findInList(list, identity)
		return record, index, scope, list
	end
	-- Compatibility for pre-scope runtime identities and external callers.
	identity = type(handle) == "string" and handle or nil
	if not identity then
		return nil, nil, nil, nil
	end
	for _, fallbackScope in ipairs({ SCOPE_CHARACTER, SCOPE_WARBAND }) do
		local list = scopeRecords(fallbackScope)
		local record, index = findInList(list, identity)
		if record then
			return record, index, fallbackScope, list
		end
	end
	return nil, nil, nil, nil
end

local function recordKind(record)
	if record and record.kind == "preset" then
		return "preset"
	end
	if record and record.kind == "activity" then
		return "activity"
	end
	local identity = record and record.identity
	if type(identity) == "string"
		and identity:match("^" .. ACTIVITY_IDENTITY_PREFIX .. "%d+:%d+$")
	then
		return "activity"
	end
	return "instance"
end

local function cleanText(value)
	if type(value) ~= "string" then
		return nil
	end
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	return value ~= "" and value or nil
end

local function normalizeSearchText(value)
	local normalizer = GF.QuickSearch and GF.QuickSearch.NormalizeText
	if type(normalizer) == "function" then
		return normalizer(value)
	end
	value = cleanText(value)
	if not value then
		return nil
	end
	value = value:gsub("|[cC]%x%x%x%x%x%x%x%x", "")
		:gsub("|[rR]", "")
		:gsub("[%s%p%c]+", "")
	return value ~= "" and string.lower(value) or nil
end

local function activityIDsForRecord(record)
	local categoryID = tonumber(record and record.categoryID)
	local activityID = tonumber(record and record.activityID)
	if not (categoryID and activityID) and record and type(record.identity) == "string" then
		local categoryText, activityText = record.identity:match(
			"^" .. ACTIVITY_IDENTITY_PREFIX .. "(%d+):(%d+)$")
		categoryID = categoryID or tonumber(categoryText)
		activityID = activityID or tonumber(activityText)
	end
	return categoryID, activityID
end

local function nodeLabel(node)
	local label = node and node.label
	if type(label) == "string" and label ~= "" then
		return label
	end
	local info = node and node.activityInfo
	local fullName = info and info.fullName
	if type(fullName) == "string" and fullName ~= "" then
		return fullName
	end
	local shortName = info and info.shortName
	if type(shortName) == "string" and shortName ~= "" then
		return shortName
	end
	return nil
end

local function activityFullName(node, activityID)
	local info = node and node.activityInfo
	local reader = C_LFGList and C_LFGList.GetActivityInfoTable
	if info == nil and activityID ~= nil and type(reader) == "function" then
		local ok, value = pcall(reader, activityID)
		info = ok and value or nil
	end
	return cleanText(info and info.fullName)
		or cleanText(info and info.shortName)
		or cleanText(nodeLabel(node)), info
end

local function nodeBreadcrumb(node)
	local navTree = GF.NavTree
	local finder = navTree and navTree.FindNodePathByKey
	if type(finder) ~= "function" or not (node and node.key) then
		return nil
	end
	local _, path = navTree:FindNodePathByKey(node.key)
	local labels = {}
	for index = 1, math.max(0, #(path or {}) - 1) do
		local label = nodeLabel(path[index])
		if label then
			labels[#labels + 1] = label
		end
	end
	return #labels > 0 and table.concat(labels, " · ") or nil
end

local function nodeAllowedForTab(node, tabID)
	if not node or node.disabled then
		return false
	end
	local workspace = GF.LFGWorkspaceView
	if workspace and workspace.IsNodeAllowed
		and not workspace:IsNodeAllowed(node)
	then
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

local function directActivityNode(record)
	local categoryID, activityID = activityIDsForRecord(record)
	local finder = GF.NavData and GF.NavData.FindNodeByActivityID
	local node = type(finder) == "function" and finder(activityID) or nil
	if not node then
		return nil
	end
	local info = node.activityInfo
	local currentCategoryID = tonumber(node.categoryID)
		or tonumber(info and info.categoryID)
	if currentCategoryID ~= categoryID then
		return nil
	end
	return node
end

local function difficultyMergeKey(node)
	local info = node and node.activityInfo
	local reader = C_LFGList and C_LFGList.GetActivityInfoTable
	if info == nil and node and node.activityID and type(reader) == "function" then
		local ok, value = pcall(reader, node.activityID)
		info = ok and value or nil
	end
	local merge = GF.ActivityInfo
		and GF.ActivityInfo.GetActivityDifficultyMergeKey
	return type(merge) == "function" and merge(info) or nil
end

local function resolvePresetFallback(record, tabID)
	local instanceIdentity = cleanText(record and record.instanceIdentity)
	local expectedDifficulty = cleanText(record and record.difficultyKey)
	if not (instanceIdentity and expectedDifficulty) then
		return nil
	end
	local search = GF.QuickSearch
	local entry = search and search.GetEntryByIdentity
		and search:GetEntryByIdentity(instanceIdentity) or nil
	local children = entry and search.BuildDifficultyNodes
		and search:BuildDifficultyNodes(entry, tabID) or {}
	local expectedCategory = tonumber(record.categoryID)
	for _, proxy in ipairs(children) do
		local target = proxy.quickSearchTarget
		local targetCategory = tonumber(target and target.categoryID)
			or tonumber(target and target.activityInfo
				and target.activityInfo.categoryID)
		if targetCategory == expectedCategory
			and difficultyMergeKey(target) == expectedDifficulty
		then
			return target
		end
	end
	return nil
end

local function resolveDirectRecord(record, tabID)
	local node = directActivityNode(record)
	if not node and recordKind(record) == "preset" then
		node = resolvePresetFallback(record, tabID)
	end
	return node
end

local function favoriteRoot()
	for _, root in ipairs(GF.navTree or {}) do
		if root and root.key == ROOT_KEY then
			return root
		end
	end
	return nil
end

local function refreshOpenFavoritePanel(root)
	local flyout = GF.NavFlyout
	if root and flyout and flyout.IsNodeOpen and flyout:IsNodeOpen(root)
		and flyout.ReanchorOpenPanels
	then
		flyout:ReanchorOpenPanels()
	end
end

local function notifyChanged()
	local root = FavoriteInstances:RefreshRoot(currentTabID())
	if GF.NavTree and GF.NavTree.Refresh then
		GF.NavTree:Refresh()
	end
	refreshOpenFavoritePanel(root)
end

local function nextPresetIdentity(scope)
	local list = scopeRecords(scope)
	local maximum = 0
	for _, record in ipairs(list) do
		local numeric = type(record.identity) == "string"
			and tonumber(record.identity:match(
				"^" .. PRESET_IDENTITY_PREFIX .. "(%d+)$")) or nil
		maximum = math.max(maximum, numeric or 0)
	end
	local identity
	repeat
		maximum = maximum + 1
		identity = PRESET_IDENTITY_PREFIX .. tostring(maximum)
	until findInList(list, identity) == nil
	return identity
end

local function normalizeNumber(value)
	value = tonumber(value)
	return value and value >= 0 and value or 0
end

local function capturePreset(draft)
	return {
		generalPlaystyle = tonumber(draft and draft.generalPlaystyle) or 0,
		requiredItemLevel = normalizeNumber(draft and draft.requiredItemLevel),
		requiredDungeonScore = normalizeNumber(draft and draft.requiredDungeonScore),
		requiredPvpRating = normalizeNumber(draft and draft.requiredPvpRating),
		privateGroup = draft and draft.privateGroup == true or false,
		factionRestricted = draft and draft.factionRestricted == true or false,
	}
end

local function buildPresetRecord(identity, node, draft, customName)
	local resolver = GF.NavData and GF.NavData.ResolveCreateActivityID
	local activityID = type(resolver) == "function"
		and resolver(node) or tonumber(node and node.activityID)
	local label, info = activityFullName(node, activityID)
	local categoryID = tonumber(node and node.categoryID)
		or tonumber(info and info.categoryID)
	if not (activityID and categoryID and label) then
		return nil
	end
	local entry = GF.QuickSearch and GF.QuickSearch.GetEntryForNode
		and GF.QuickSearch:GetEntryForNode(node) or nil
	return {
		identity = identity,
		kind = "preset",
		categoryID = categoryID,
		activityID = activityID,
		groupID = tonumber(node and node.groupID)
			or tonumber(info and info.groupFinderActivityGroupID),
		instanceIdentity = entry and cleanText(entry.identity) or nil,
		difficultyKey = difficultyMergeKey(node),
		label = label,
		breadcrumb = nodeBreadcrumb(node),
		customName = cleanText(customName),
		preset = capturePreset(draft),
	}
end

local function favoriteOrderRoot(create)
	local _, db = favoriteRootStorage(create)
	if not db then
		return nil
	end
	local schema = GF.SettingsSchema
	if type(db.favoriteInstanceOrders) ~= "table"
		and schema and type(schema.NormalizeFavoriteInstanceOrders) == "function"
	then
		return schema:NormalizeFavoriteInstanceOrders(db)
	end
	if type(db.favoriteInstanceOrders) ~= "table" then
		if create ~= true then
			return nil
		end
		db.favoriteInstanceOrders = {}
	end
	return db.favoriteInstanceOrders
end

local function characterOrder(create)
	local characterKey = currentCharacterKey()
	if not characterKey then
		return nil
	end
	local root = favoriteOrderRoot(create)
	if not root then
		return nil
	end
	local order = root[characterKey]
	if type(order) ~= "table" and create == true then
		order = {}
		root[characterKey] = order
	end
	return order
end

local function recordReferences()
	local references = {}
	for _, scope in ipairs({ SCOPE_CHARACTER, SCOPE_WARBAND }) do
		for _, record in ipairs(scopeRecords(scope)) do
			references[#references + 1] = {
				record = record,
				scope = scope,
				handle = makeHandle(scope, record.identity),
			}
		end
	end
	return references
end

local function orderReferences(references, identityOrder, requireComplete)
	local byHandle, ordered, seen = {}, {}, {}
	for _, reference in ipairs(references) do
		if not reference.handle or byHandle[reference.handle] then
			return nil
		end
		byHandle[reference.handle] = reference
	end
	if type(identityOrder) == "table" then
		if requireComplete and #identityOrder ~= #references then
			return nil
		end
		for _, handle in ipairs(identityOrder) do
			local reference = type(handle) == "string" and byHandle[handle] or nil
			if not reference or seen[handle] then
				if requireComplete then
					return nil
				end
			else
				seen[handle] = true
				ordered[#ordered + 1] = reference
			end
		end
	end
	for _, reference in ipairs(references) do
		if not seen[reference.handle] then
			seen[reference.handle] = true
			ordered[#ordered + 1] = reference
		end
	end
	return ordered
end

local function projectedReferences(identityOrder)
	local references = recordReferences()
	if identityOrder ~= nil then
		return orderReferences(references, identityOrder, true) or references
	end
	return orderReferences(references, characterOrder(false), false) or references
end

local function removeHandleFromOrder(order, handle)
	local removed = false
	for index = #(order or {}), 1, -1 do
		if order[index] == handle then
			table.remove(order, index)
			removed = true
		end
	end
	return removed
end

local function migrateOrderHandle(oldHandle, newHandle, sourceScope)
	local root = favoriteOrderRoot(false)
	local currentKey = currentCharacterKey()
	if not root then
		return
	end
	for characterKey, order in pairs(root) do
		if type(order) == "table"
			and (sourceScope == SCOPE_WARBAND or characterKey == currentKey)
		then
			local replace = characterKey == currentKey
			for index = #order, 1, -1 do
				if order[index] == oldHandle then
					if replace then
						order[index] = newHandle
						replace = false
					else
						table.remove(order, index)
					end
				end
			end
		end
	end
end

function FavoriteInstances:GetRecords(scope)
	if scope == SCOPE_CHARACTER or scope == SCOPE_WARBAND then
		return scopeRecords(scope)
	end
	local combined = {}
	for _, reference in ipairs(projectedReferences()) do
		combined[#combined + 1] = reference.record
	end
	return combined
end

function FavoriteInstances:GetCount()
	return #scopeRecords(SCOPE_CHARACTER) + #scopeRecords(SCOPE_WARBAND)
end

function FavoriteInstances:GetRecord(identity)
	return findRecord(identity)
end

function FavoriteInstances:IsFavorite(identity)
	return findRecord(identity) ~= nil
end

function FavoriteInstances:HasPreset(identity)
	local record = findRecord(identity)
	return recordKind(record) == "preset"
		and type(record.preset) == "table"
end

function FavoriteInstances:SavePreset(
	recordIdentity, node, draft, customName, targetScope)
	if type(node) ~= "table" then
		return false, nil, "invalid"
	end
	local existing, index, sourceScope, sourceList = findRecord(recordIdentity)
	if targetScope ~= SCOPE_CHARACTER and targetScope ~= SCOPE_WARBAND then
		targetScope = sourceScope or SCOPE_CHARACTER
	end
	local targetList = scopeRecords(targetScope, true)
	if not targetList then
		return false, nil, targetScope == SCOPE_CHARACTER
			and "character_unavailable" or "database_unavailable"
	end
	local identity = existing and existing.identity
		or nextPresetIdentity(targetScope)
	if sourceScope ~= targetScope and findInList(targetList, identity) then
		identity = nextPresetIdentity(targetScope)
	end
	local replacement = buildPresetRecord(identity, node, draft, customName)
	if not replacement then
		return false, nil, "invalid"
	end
	local oldHandle = existing and makeHandle(sourceScope, existing.identity) or nil
	if index and sourceScope == targetScope then
		targetList[index] = replacement
	else
		if index and sourceList then
			table.remove(sourceList, index)
		end
		targetList[#targetList + 1] = replacement
		if oldHandle then
			migrateOrderHandle(
				oldHandle,
				makeHandle(targetScope, identity),
				sourceScope)
		end
	end
	notifyChanged()
	return true, makeHandle(targetScope, identity),
		existing and "updated" or "added"
end

function FavoriteInstances:Remove(identity)
	local record, index, scope, list = findRecord(identity)
	if not index then
		return false
	end
	local handle = makeHandle(scope, record.identity)
	table.remove(list, index)
	if scope == SCOPE_WARBAND then
		for _, order in pairs(favoriteOrderRoot(false) or {}) do
			removeHandleFromOrder(order, handle)
		end
	else
		removeHandleFromOrder(characterOrder(false), handle)
	end
	notifyChanged()
	return true
end

function FavoriteInstances:GetIdentityOrder()
	local order = {}
	for index, reference in ipairs(projectedReferences()) do
		order[index] = reference.handle
	end
	return order
end

function FavoriteInstances:CommitOrder(identityOrder, suppressRefresh)
	if type(identityOrder) ~= "table" then
		return false
	end
	local references = recordReferences()
	local ordered = orderReferences(references, identityOrder, true)
	if not ordered then
		return false
	end
	local savedOrder = characterOrder(true)
	if not savedOrder then
		return false
	end
	for index = #savedOrder, 1, -1 do
		savedOrder[index] = nil
	end
	for index, reference in ipairs(ordered) do
		savedOrder[index] = reference.handle
	end
	for _, scope in ipairs({ SCOPE_CHARACTER, SCOPE_WARBAND }) do
		local list, scopedIndex = scopeRecords(scope, true), 0
		if not list then
			return false
		end
		for _, reference in ipairs(ordered) do
			if reference.scope == scope then
				scopedIndex = scopedIndex + 1
				list[scopedIndex] = reference.record
			end
		end
	end
	if not suppressRefresh then
		notifyChanged()
	end
	return true
end

function FavoriteInstances:BuildNodes(tabID, identityOrder)
	local references = projectedReferences(identityOrder)
	local L = GF.L or {}
	if #references == 0 then
		return {
			{
				key = ROOT_KEY .. "::empty",
				level = 1,
				label = L.FAVORITE_INSTANCE_EMPTY
					or "Add favorites from the Create Listing form",
				isLeaf = false,
				disabled = true,
				navKind = ROOT_KEY,
				favoriteEmpty = true,
			},
		}
	end

	local search = GF.QuickSearch
	local activeTabID = tabID or currentTabID()
	local searchIndexReady = search and search.IsIndexBuilt
		and search:IsIndexBuilt() == true
	local resolved, labelCounts = {}, {}
	for index, reference in ipairs(references) do
		local record = reference.record
		local kind = recordKind(record)
		local entry = kind == "instance" and search
			and searchIndexReady and search.PeekEntryByIdentity
			and search:PeekEntryByIdentity(record.identity) or nil
		local activityNode = kind ~= "instance"
			and resolveDirectRecord(record, activeTabID) or nil
		if entry then
			record.label = entry.label or record.label
			record.breadcrumb = entry.breadcrumb or record.breadcrumb
		elseif activityNode then
			record.label = activityFullName(activityNode, activityNode.activityID)
				or record.label
			record.breadcrumb = nodeBreadcrumb(activityNode) or record.breadcrumb
		end
		local actualLabel = entry and entry.label
			or activityNode and activityFullName(activityNode, activityNode.activityID)
			or record.label or record.identity
		local displayLabel = cleanText(record.customName) or actualLabel
		resolved[index] = {
			record = record,
			scope = reference.scope,
			handle = reference.handle,
			kind = kind,
			entry = entry,
			activityNode = activityNode,
			actualLabel = actualLabel,
			displayLabel = displayLabel,
		}
		labelCounts[displayLabel] = (labelCounts[displayLabel] or 0) + 1
	end

	local nodes = {}
	for index, item in ipairs(resolved) do
		local record, entry = item.record, item.entry
		local isDirect = item.kind ~= "instance"
		local label = item.displayLabel
		if labelCounts[item.displayLabel] > 1 and record.breadcrumb then
			label = string.format("%s |cff888888· %s|r", label, record.breadcrumb)
		end
		local disabled = isDirect
			and not nodeAllowedForTab(item.activityNode, activeTabID)
			or not isDirect and searchIndexReady and entry == nil
		if disabled then
			label = string.format(
				L.FAVORITE_INSTANCE_UNAVAILABLE_FMT or "%s · Unavailable",
				label)
		end
		nodes[#nodes + 1] = {
			key = ROOT_KEY .. "::result::" .. item.handle,
			level = 1,
			label = label,
			isLeaf = false,
			disabled = disabled,
			disabledTooltip = disabled,
			disabledReason = disabled and (L.NAV_ACTIVITY_UNAVAILABLE
				or "This activity is not currently available.") or nil,
			navKind = ROOT_KEY,
			children = isDirect and {} or nil,
			childrenLoaded = isDirect and true or false,
			lazyKind = not isDirect and "quick_search_result" or nil,
			favoriteResult = true,
			favoriteIdentity = item.handle,
			favoriteScope = item.scope,
			favoriteOrder = index,
			favoriteActivity = isDirect,
			favoriteHasPreset = item.kind == "preset",
			favoriteActualLabel = item.actualLabel,
			favoriteCustomName = cleanText(record.customName),
			favoriteActivityID = isDirect and record.activityID or nil,
			favoriteCategoryID = isDirect and record.categoryID or nil,
			quickSearchIdentity = not isDirect and record.identity or nil,
			quickSearchTabID = activeTabID,
			favoriteSourceIdentity = not isDirect and item.handle or nil,
			quickSearchResult = not isDirect,
			_gfQuickSearchProxy = not isDirect,
			_gfQuickSearchGeneration = not isDirect and search
				and search.GetGeneration and search:GetGeneration() or 0,
		}
	end
	return nodes
end

function FavoriteInstances:FilterNodes(nodes, value)
	nodes = type(nodes) == "table" and nodes or {}
	local query = normalizeSearchText(value)
	if not query then
		return nodes
	end
	local matches, hasFavorite = {}, false
	for _, node in ipairs(nodes) do
		if node and node.favoriteResult == true then
			hasFavorite = true
			local actualToken = normalizeSearchText(node.favoriteActualLabel)
			local aliasToken = normalizeSearchText(node.favoriteCustomName)
			if actualToken and actualToken:find(query, 1, true)
				or aliasToken and aliasToken:find(query, 1, true)
			then
				matches[#matches + 1] = node
			end
		end
	end
	if not hasFavorite or #matches > 0 then
		return hasFavorite and matches or nodes
	end
	local L = GF.L or {}
	return {
		{
			key = ROOT_KEY .. "::search::none",
			level = 1,
			label = L.FAVORITE_SEARCH_NO_RESULTS
				or "No matching favorite activities",
			isLeaf = false,
			disabled = true,
			navKind = ROOT_KEY,
			favoriteSearchEmpty = true,
		},
	}
end

function FavoriteInstances:RefreshRoot(tabID, identityOrder)
	local root = favoriteRoot()
	if not root then
		return nil
	end
	root.children = self:BuildNodes(tabID or currentTabID(), identityOrder)
	root.childrenLoaded = true
	return root
end

function FavoriteInstances:Invalidate()
	local root = favoriteRoot()
	if root then
		root.children = nil
		root.childrenLoaded = false
	end
end

function FavoriteInstances:ResolveTarget(proxy, tabID)
	if not (proxy and proxy.favoriteIdentity) then
		return nil
	end
	local record = findRecord(proxy.favoriteIdentity)
	if recordKind(record) ~= "instance" then
		local node = resolveDirectRecord(record, tabID or currentTabID())
		return nodeAllowedForTab(node, tabID or currentTabID()) and node or nil
	end
	local search = GF.QuickSearch
	local entry = search and search.GetEntryByIdentity
		and record and search:GetEntryByIdentity(record.identity) or nil
	return entry and search.ResolveEntrySource
		and search:ResolveEntrySource(entry, tabID or currentTabID()) or nil
end

function FavoriteInstances:ResolveBrowseSource(proxy)
	return self:ResolveTarget(proxy, GF.TAB_BROWSE)
end
