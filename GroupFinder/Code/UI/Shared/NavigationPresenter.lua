local _, GF = ...

-- NavigationPresenter owns navigation state and interaction decisions.  The
-- two widget modules are rendering ports; NavigationProjection remains the
-- only owner allowed to publish the canonical tree or realize lazy branches.
local Presenter = GF.NavigationPresenter or {}
GF.NavigationPresenter = Presenter

local PANEL_COUNT = 3
local LAZY_HOVER_DELAY = 0.15

local state = Presenter._state or {
	expanded = {},
	selectedPath = {},
	openKeys = {},
	interactionEnabled = true,
	quickSearch = { children = {} },
	favorites = { children = {}, queryByTab = {} },
	hover = { token = 0 },
}
Presenter._state = state

local NAV_TREE_STATE_KEYS = {
	selectedKey = "selectedKey",
	selectedPath = "selectedPath",
	activeRootKey = "activeRootKey",
	expanded = "expanded",
	interactionEnabled = "interactionEnabled",
}

local NAV_FLYOUT_STATE_KEYS = {
	openKeys = "openKeys",
	favoriteReorderMode = "favorites.reorderMode",
	_favoriteReorderOrder = "favorites.order",
	_favoriteReorderDirty = "favorites.dirty",
	_quickSearchHoverToken = "hover.token",
	_quickSearchHoverTimer = "hover.timer",
}

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if method then
		return method(owner, ...)
	end
end

local function projection()
	-- NavData is the published compatibility identity of this same owner.
	return GF.NavigationProjection or GF.NavData
end

local function currentTabID()
	return invoke(GF.MainFrame, "GetCurrentTabID") or GF.TAB_BROWSE
end

local function copySequence(source)
	local result = {}
	for index = 1, #(source or {}) do
		result[index] = source[index]
	end
	return result
end

local function pathKeys(path)
	local result = {}
	for index, node in ipairs(path or {}) do
		result[index] = node and node.key or nil
	end
	return result
end

local function readStatePath(path)
	if path == "favorites.reorderMode" then
		return state.favorites.reorderMode
	elseif path == "favorites.order" then
		return state.favorites.order
	elseif path == "favorites.dirty" then
		return state.favorites.dirty
	elseif path == "hover.token" then
		return state.hover.token
	elseif path == "hover.timer" then
		return state.hover.timer
	end
	return state[path]
end

local function writeStatePath(path, value)
	if path == "favorites.reorderMode" then
		state.favorites.reorderMode = value
	elseif path == "favorites.order" then
		state.favorites.order = value
	elseif path == "favorites.dirty" then
		state.favorites.dirty = value
	elseif path == "hover.token" then
		state.hover.token = value
	elseif path == "hover.timer" then
		state.hover.timer = value
	else
		state[path] = value
	end
end

local function bindCompatibilityState(owner, keys, marker, presenter)
	if type(owner) ~= "table" then
		return
	end
	local existing = getmetatable(owner)
	if existing and existing[marker] == presenter then
		return
	end
	for key, path in pairs(keys) do
		local value = rawget(owner, key)
		if value ~= nil then
			writeStatePath(path, value)
			rawset(owner, key, nil)
		end
	end
	local previousIndex = existing and existing.__index
	local previousNewIndex = existing and existing.__newindex
	local meta = {}
	for key, value in pairs(existing or {}) do
		meta[key] = value
	end
	meta[marker] = presenter
	meta.__index = function(target, key)
		local path = keys[key]
		if path then
			return readStatePath(path)
		end
		if type(previousIndex) == "function" then
			return previousIndex(target, key)
		elseif type(previousIndex) == "table" then
			return previousIndex[key]
		end
		return nil
	end
	meta.__newindex = function(target, key, value)
		local path = keys[key]
		if path then
			writeStatePath(path, value)
			if key == "selectedKey" then
				presenter:ReconcileSelectedPath(value)
			end
		elseif type(previousNewIndex) == "function" then
			previousNewIndex(target, key, value)
		elseif type(previousNewIndex) == "table" then
			previousNewIndex[key] = value
		else
			rawset(target, key, value)
		end
	end
	setmetatable(owner, meta)
end

function Presenter:BindNavTree(view)
	self.navTreeView = view
	bindCompatibilityState(
		view, NAV_TREE_STATE_KEYS, "_gfNavigationPresenterTree", self)
	return state
end

function Presenter:BindFlyout(view)
	self.flyoutView = view
	bindCompatibilityState(
		view, NAV_FLYOUT_STATE_KEYS, "_gfNavigationPresenterFlyout", self)
	return state
end

function Presenter:GetState()
	return state
end

function Presenter:EnsureState()
	state.expanded = state.expanded or {}
	state.selectedPath = state.selectedPath or {}
	state.selectedPathKeys = state.selectedPathKeys or {}
	state.quickSearch = state.quickSearch or { children = {} }
	state.quickSearch.children = state.quickSearch.children or {}
	state.favorites = state.favorites or { children = {} }
	state.favorites.children = state.favorites.children or {}
	state.favorites.queryByTab = state.favorites.queryByTab or {}
	state.hover = state.hover or { token = 0 }
	return state
end

function Presenter:Reset()
	self:CancelQuickSearchHover()
	state.expanded = {}
	state.selectedKey = nil
	state.selectedPath = {}
	state.selectedPathKeys = {}
	state.activeRootKey = nil
	state.openKeys = {}
	state.interactionEnabled = true
	state.quickSearch = { children = {} }
	state.favorites = { children = {}, queryByTab = {} }
	state.hover = { token = 0 }
	return state
end

function Presenter:GetTree()
	local owner = projection()
	return owner and owner.GetTree and owner.GetTree() or {}
end

function Presenter:GetVisibleRoots()
	local roots = self:GetTree()
	local workspace = GF.LFGWorkspaceView
	if workspace and workspace.GetVisibleRoots then
		return workspace:GetVisibleRoots(roots)
	end
	return roots
end

function Presenter:NodeCanExpand(node)
	if not node or node.isLeaf then
		return false
	end
	if node.quickSearchRoot or node.favoriteInstancesRoot then
		return true
	end
	if node.lazyKind and node.childrenLoaded ~= true then
		return true
	end
	return type(node.children) == "table" and #node.children > 0
end

local function visitTree(test, realizeLazy)
	local owner = projection()
	local workingPath = {}
	local match
	local function visit(node)
		if match or node == nil then
			return match ~= nil
		end
		workingPath[#workingPath + 1] = node
		if test(node) then
			match = node
			return true
		end
		local shouldRealize = realizeLazy == true
			or type(realizeLazy) == "function" and realizeLazy(node) == true
		if shouldRealize and node.lazyKind and node.childrenLoaded ~= true
			and owner and owner.EnsureChildren
		then
			owner.EnsureChildren(node)
		end
		for _, child in ipairs(node.children or {}) do
			if visit(child) then
				return true
			end
		end
		workingPath[#workingPath] = nil
		return false
	end
	for _, root in ipairs(Presenter:GetTree()) do
		if visit(root) then
			break
		end
	end
	return match, match and copySequence(workingPath) or nil
end

function Presenter:FindNodePathByKey(key)
	if key == nil then
		return nil, nil
	end
	local owner = projection()
	if owner and owner.FindLoadedNodePathByKey then
		local node, path = owner.FindLoadedNodePathByKey(key)
		if node then
			return node, path
		end
	end
	local function keyDescendsFrom(node)
		local ancestor = node and node.key
		if type(ancestor) ~= "string" or type(key) ~= "string" then
			return false
		end
		return key:sub(1, #ancestor + 1) == ancestor .. "_"
			or key:sub(1, #ancestor + 2) == ancestor .. "::"
	end
	return visitTree(function(node)
		return node.key == key
	end, keyDescendsFrom)
end

function Presenter:FindNodePathByActivityID(activityID)
	if activityID == nil then
		return nil, nil
	end
	local owner = projection()
	if owner and type(owner.FindNodeByActivityID) == "function" then
		local node = owner.FindNodeByActivityID(activityID)
		if node then
			local path
			if owner.FindLoadedNodePathByKey then
				local _
				_, path = owner.FindLoadedNodePathByKey(node.key)
			end
			return node, path
		end
		-- The projection owns the targeted static-candidate lookup. A nil result
		-- is authoritative; generic fallback traversal would realize every
		-- archive expansion merely to confirm that an unknown activity is absent.
		return nil, nil
	end
	return visitTree(function(node)
		return node.activityID == activityID and node.categoryBrowse ~= true
	end, function(node)
		return node.lazyKind ~= "archive_instance"
	end)
end

function Presenter:ReconcileSelectedPath(key)
	if key == nil then
		state.selectedPath = {}
		state.selectedPathKeys = {}
		return nil
	end
	local _, path = self:FindNodePathByKey(key)
	state.selectedPath = path or {}
	state.selectedPathKeys = pathKeys(path)
	return path
end

function Presenter:GetSelectedPath()
	return copySequence(state.selectedPath)
end

function Presenter:GetSelectedKey()
	return state.selectedKey
end

function Presenter:GetActiveRootKey()
	return state.activeRootKey
end

function Presenter:GetExpanded()
	self:EnsureState()
	return state.expanded
end

function Presenter:GetOpenKeys()
	return state.openKeys
end

local function rootKeyForPath(path)
	return path and path[1] and path[1].key or nil
end

function Presenter:RootKeyContaining(key)
	if key == nil then
		return nil
	end
	if key == state.selectedKey and state.selectedPath[1] then
		return state.selectedPath[1].key
	end
	local _, path = self:FindNodePathByKey(key)
	return rootKeyForPath(path)
end

local function forgetBranch(expansion, node)
	if not (node and node.key) then
		return
	end
	expansion[node.key] = nil
	for _, child in ipairs(node.children or {}) do
		forgetBranch(expansion, child)
	end
end

function Presenter:PrepareBranch(node)
	self:EnsureState()
	if not (node and node.key) or self:IsNodeInteractionBlocked(node) then
		return false
	end
	local owner = projection()
	if node.lazyKind and node.childrenLoaded ~= true
		and owner and owner.EnsureChildren
	then
		if owner.RequestChildren then owner.RequestChildren(node)
		else owner.EnsureChildren(node) end
	end
	if (node.level or 0) == 0 then
		for _, root in ipairs(self:GetTree()) do
			if root and root.key and root.key ~= node.key then
				forgetBranch(state.expanded, root)
			end
		end
	end
	state.expanded[node.key] = true
	return true
end

function Presenter:OnBranchPrepared(node)
	-- Completion only redraws an already open branch. It cannot select a node,
	-- reopen a closed menu, or start a search/recruitment action.
	if state.openKeys and state.openKeys[node.level or 0] == node.key then
		self:ReanchorOpenPanels()
		invoke(self.navTreeView, "Refresh")
	end
end

local function pathHasDisabledNode(path)
	for _, node in ipairs(path or {}) do
		if node and node.disabled then
			return true
		end
	end
	return false
end

function Presenter:ResolveNodePath(node, path)
	if path ~= nil or not (node and node.key) then
		return path
	end
	local owner = projection()
	if owner and owner.FindLoadedNodePathByKey then
		local _, loadedPath = owner.FindLoadedNodePathByKey(node.key)
		if loadedPath then
			return loadedPath
		end
	end
	local _, foundPath = self:FindNodePathByKey(node.key)
	return foundPath
end

function Presenter:IsNodeInteractionBlocked(node, path)
	if node == nil or node.disabled then
		return true
	end
	if node._gfQuickSearchProxy or node.favoriteResult then
		return false
	end
	local resolvedPath = self:ResolveNodePath(node, path)
	if pathHasDisabledNode(resolvedPath) then
		return true
	end
	local rootKey = rootKeyForPath(resolvedPath)
	local owner = projection()
	local currentRoot = rootKey and owner and owner.FindNodeByKey
		and owner.FindNodeByKey(rootKey) or nil
	return currentRoot and currentRoot.disabled == true or false
end

function Presenter:GetNodeDisabledReason(node, path)
	local resolvedPath = self:ResolveNodePath(node, path)
	for index = #(resolvedPath or {}), 1, -1 do
		local ancestor = resolvedPath[index]
		if ancestor and ancestor.disabled then
			local text = ancestor.disabledReason
			if text == nil or text == "" then
				text = ancestor.tooltip
			end
			if text ~= nil and text ~= "" then
				return text
			end
		end
	end
	if node and node.disabled then
		local text = node.disabledReason
		if text == nil or text == "" then
			text = node.tooltip
		end
		return text
	end
	return nil
end

local function publishSelection(node, path)
	state.selectedKey = node and node.key or nil
	state.selectedPath = copySequence(path)
	state.selectedPathKeys = pathKeys(path)
end

function Presenter:SetSelectedSilently(node, path)
	self:EnsureState()
	if not (node and node.key) or self:IsNodeInteractionBlocked(node, path) then
		return false
	end
	path = path or self:ResolveNodePath(node)
	for index = 1, path and (#path - 1) or 0 do
		local ancestor = path[index]
		if ancestor and ancestor.key then
			state.expanded[ancestor.key] = true
		end
	end
	publishSelection(node, path)
	state.activeRootKey = rootKeyForPath(path)
		or ((node.level or 0) == 0 and node.key or nil)
	invoke(self.navTreeView, "Refresh")
	return true
end

local function selectedRoot()
	if not (state.selectedKey and state.activeRootKey) then
		return nil
	end
	local owner = projection()
	local node = owner and owner.FindNodeByKey
		and owner.FindNodeByKey(state.selectedKey) or nil
	if node and (node.level or 0) == 0 and node.key == state.activeRootKey then
		return node
	end
	return nil
end

local function selectionBelongsToOpenRoot()
	return state.selectedKey ~= nil and state.activeRootKey ~= nil
		and Presenter:RootKeyContaining(state.selectedKey) == state.activeRootKey
end

function Presenter:ClearActiveRoot(skipRefresh, options)
	options = options or {}
	local oldRoot = state.activeRootKey
	local flyoutsWereOpen = state.openKeys and next(state.openKeys) ~= nil
	local clearSelection = options.clearSelection
		and ((options.clearSelectionInActiveRoot
			and selectionBelongsToOpenRoot()) or selectedRoot() ~= nil)
	if options.preserveSelectedRoot and not clearSelection and state.selectedKey then
		state.activeRootKey = self:RootKeyContaining(state.selectedKey)
	else
		state.activeRootKey = nil
	end
	self:HideAll({ preserveActiveRoot = true })
	if clearSelection then
		publishSelection(nil, nil)
		invoke(GF.MainFrame, "OnSelectionChanged", nil, options)
	end
	if not skipRefresh
		and (oldRoot ~= state.activeRootKey or oldRoot ~= nil or flyoutsWereOpen)
	then
		invoke(self.navTreeView, "Refresh")
	end
	return clearSelection
end

function Presenter:IsInteractionEnabled()
	return state.interactionEnabled ~= false
end

function Presenter:SetInteractionEnabled(enabled)
	enabled = enabled ~= false
	if enabled == state.interactionEnabled then
		return false
	end
	state.interactionEnabled = enabled
	self:HideAll()
	invoke(self.navTreeView, "RenderInteractionEnabled", enabled)
	return true
end

function Presenter:ToggleExpand(key, skipRefresh)
	self:EnsureState()
	local owner = projection()
	local node = owner and owner.FindNodeByKey and owner.FindNodeByKey(key) or nil
	if node == nil then
		node = self:FindNodePathByKey(key)
	end
	if node == nil or self:IsNodeInteractionBlocked(node) then
		return false
	end
	if state.expanded[key] then
		forgetBranch(state.expanded, node)
	else
		self:PrepareBranch(node)
	end
	if not skipRefresh then
		invoke(self.navTreeView, "Refresh")
	end
	return true
end

function Presenter:SetSelected(node, skipRefresh, options)
	if not node or self:IsNodeInteractionBlocked(node)
		or not self:IsInteractionEnabled()
	then
		return false
	end
	local workspace = GF.LFGWorkspaceView
	if workspace and workspace.IsNodeAllowed
		and not workspace:IsNodeAllowed(node)
	then
		return false
	end
	local owner = projection()
	if not (owner and owner.AcceptsBrowseSelection
		and owner.AcceptsBrowseSelection(node))
	then
		return false
	end
	options = options or {}
	local path = self:ResolveNodePath(node)
	publishSelection(node, path)
	if options.visual ~= false then
		state.activeRootKey = rootKeyForPath(path)
			or ((node.level or 0) == 0 and node.key or nil)
	end
	invoke(GF.MainFrame, "OnSelectionChanged", node, options.selectionOptions)
	if not options.keepFlyouts then
		self:HideAll()
	end
	if not skipRefresh then
		invoke(self.navTreeView, "Refresh")
	end
	return true
end

local function panelIndexForNode(node)
	local depth = node and (node.level or 0)
	return depth and depth < PANEL_COUNT and (depth + 1) or nil
end

function Presenter:HideFromLevel(level)
	level = level or 1
	local nodeDepth = math.max(0, level - 1)
	if state.openKeys then
		while nodeDepth <= PANEL_COUNT do
			state.openKeys[nodeDepth] = nil
			nodeDepth = nodeDepth + 1
		end
	end
	invoke(self.flyoutView, "RenderHideFromLevel", level)
end

function Presenter:IsNodeOpen(node)
	return node ~= nil and state.openKeys ~= nil
		and state.openKeys[node.level or 0] == node.key
end

function Presenter:HideAll(options)
	options = options or {}
	if state.favorites.reorderMode then
		self:ExitFavoriteReorderMode(false)
	end
	local transientRootKey
	local rootKey = state.openKeys and state.openKeys[0]
	if rootKey then
		local owner = projection()
		local root = owner and owner.FindNodeByKey
			and owner.FindNodeByKey(rootKey) or nil
		if root and (root.quickSearchRoot or root.favoriteInstancesRoot) then
			transientRootKey = root.key
		end
	end
	self:CancelQuickSearchHover()
	state.openKeys = nil
	state.quickSearch.root = nil
	state.quickSearch.anchorRow = nil
	invoke(self.flyoutView, "RenderHideAll")
	if not options.preserveActiveRoot and transientRootKey
		and state.activeRootKey == transientRootKey
	then
		state.activeRootKey = nil
	end
	return transientRootKey
end

function Presenter:CloseChildPanelsForRow(row)
	local node = row and row.nodeData
	local firstChildPanel = panelIndexForNode(node)
	local depth = node and (node.level or 0)
	if not firstChildPanel or not state.openKeys
		or state.openKeys[depth] == nil
	then
		return false
	end
	self:HideFromLevel(firstChildPanel)
	invoke(self.flyoutView, "RefreshVisibleRows")
	return true
end

local function nodeVisibleForCurrentTab(node)
	if node == nil then
		return false
	end
	local workspace = GF.LFGWorkspaceView
	if workspace and workspace.IsNodeAllowed
		and not workspace:IsNodeAllowed(node)
	then
		return false
	end
	return not (currentTabID() == GF.TAB_CREATE and node.browseOnly)
end

function Presenter:FilterChildren(children)
	local visible = {}
	for _, child in ipairs(children or {}) do
		if nodeVisibleForCurrentTab(child) then
			visible[#visible + 1] = child
		end
	end
	return visible
end

function Presenter:ProjectQuickSearch(query)
	local search = GF.QuickSearch
	local children = search and search.GetResultNodes
		and search:GetResultNodes(query or "", currentTabID()) or {}
	state.quickSearch.query = query or ""
	state.quickSearch.children = children
	return children
end

function Presenter:ProjectFavorites(identityOrder)
	local favorites = GF.FavoriteInstances
	local children = favorites and favorites.BuildNodes
		and favorites:BuildNodes(currentTabID(), identityOrder) or {}
	state.favorites.allChildren = children
	if not state.favorites.reorderMode
		and favorites and type(favorites.FilterNodes) == "function"
	then
		children = favorites:FilterNodes(
			children, self:GetFavoriteSearchQuery())
	end
	state.favorites.children = children
	return children
end

function Presenter:GetFavoriteSearchQuery(tabID)
	state.favorites.queryByTab = state.favorites.queryByTab or {}
	return state.favorites.queryByTab[tabID or currentTabID()] or ""
end

function Presenter:SetFavoriteSearchQuery(value, tabID)
	state.favorites.queryByTab = state.favorites.queryByTab or {}
	value = type(value) == "string" and value or ""
	state.favorites.queryByTab[tabID or currentTabID()] = value
	return value
end

function Presenter:PrepareNode(node)
	if node then
		self:PrepareBranch(node)
	end
	if node and node.favoriteInstancesRoot then
		return self:ProjectFavorites(
			state.favorites.reorderMode and state.favorites.order or nil)
	end
	return node and node.children or {}
end

function Presenter:RefreshQuickSearchPanel(panel, query)
	local root = state.quickSearch.root
	local anchorRow = state.quickSearch.anchorRow
	if not (root and anchorRow and GF.QuickSearch
		and GF.QuickSearch.GetResultNodes)
	then
		return false
	end
	self:CancelQuickSearchHover()
	local children = self:ProjectQuickSearch(query)
	self:HideFromLevel(2)
	invoke(self.flyoutView, "RenderRefreshQuickSearch", panel, children)
	return true
end

function Presenter:OpenQuickSearch(anchorRow, node)
	local search = GF.QuickSearch
	if not (anchorRow and node and search and search.GetResultNodes
		and invoke(self.flyoutView, "CanRenderPanel", 1) ~= false)
	then
		return false
	end
	self:HideFromLevel(2)
	state.openKeys = state.openKeys or {}
	state.openKeys[0] = node.key
	state.quickSearch.root = node
	state.quickSearch.anchorRow = anchorRow
	local query = search.GetQuery and search:GetQuery(currentTabID()) or ""
	local children = self:ProjectQuickSearch(query)
	invoke(self.flyoutView, "RenderOpenQuickSearch",
		anchorRow, node, children, query)
	return true
end

function Presenter:HasQuickSearchHistory()
	local search = GF.QuickSearch
	return search and search.GetRecentInstanceCount
		and search:GetRecentInstanceCount() > 0 or false
end

function Presenter:ClearQuickSearchHistory(panel)
	local root = state.quickSearch.root
	local search = GF.QuickSearch
	if not (root and self:IsNodeOpen(root) and search and search.ClearRecentInstances) then
		return false
	end
	local cleared = search:ClearRecentInstances()
	self:RefreshQuickSearchPanel(panel, state.quickSearch.query or "")
	return cleared
end

function Presenter:RefreshLocale()
	invoke(self.flyoutView, "RenderLocale")
	if state.quickSearch.root and self:IsNodeOpen(state.quickSearch.root) then
		return self:RefreshQuickSearchPanel(nil, state.quickSearch.query or "")
	end
	local rootKey = state.openKeys and state.openKeys[0]
	local owner = projection()
	local root = rootKey and owner and owner.FindNodeByKey
		and owner.FindNodeByKey(rootKey) or nil
	if root and root.favoriteInstancesRoot then
		self:ProjectFavorites(
			state.favorites.reorderMode and state.favorites.order or nil)
		self:ReanchorOpenPanels()
	end
	return true
end

function Presenter:OpenFrom(anchorRow, node)
	if anchorRow == nil or self:IsNodeInteractionBlocked(node)
		or not self:NodeCanExpand(node)
	then
		return false
	end
	if state.favorites.reorderMode and not node.favoriteInstancesRoot then
		self:ExitFavoriteReorderMode(false)
	end
	if node.quickSearchRoot then
		return self:OpenQuickSearch(anchorRow, node)
	end
	local panelIndex = panelIndexForNode(node)
	if panelIndex == nil
		or invoke(self.flyoutView, "CanRenderOpenFrom", anchorRow, panelIndex) == false
	then
		return false
	end
	local children = self:FilterChildren(self:PrepareNode(node))
	if #children == 0 then
		if node.disabled then
			invoke(self.flyoutView, "RefreshVisibleRows")
		end
		return false
	end
	self:HideFromLevel(panelIndex + 1)
	state.openKeys = state.openKeys or {}
	state.openKeys[node.level or 0] = node.key
	invoke(self.flyoutView, "RenderOpenFrom",
		anchorRow, node, children, panelIndex)
	return true
end

function Presenter:OpenFromHover(row)
	local node = row and row.nodeData
	if self:IsNodeInteractionBlocked(node) then
		self:CloseChildPanelsForRow(row)
		return false
	end
	if not self:IsInteractionEnabled() then
		return false
	end
	-- Archive shells are cheap to display but their children require live LFG
	-- authorization. Raw hover rendering never performs that synchronous work;
	-- HandleRowPointerEnter routes a stable pointer through the cancellable lazy
	-- hover scheduler below so sweeping across siblings still costs nothing.
	if node.archiveInstanceShell == true and node.childrenLoaded ~= true then
		self:CloseChildPanelsForRow(row)
		return false
	end
	if not self:NodeCanExpand(node) then
		self:CloseChildPanelsForRow(row)
		return false
	end
	if self:IsNodeOpen(node) then
		return true
	end
	return self:OpenFrom(row, node) == true
end

local function shouldAutoSearchNode(node)
	if not node or (node.level or 0) == 0
		or currentTabID() ~= GF.TAB_BROWSE
	then
		return false
	end
	if GF.FindGroupTab and GF.FindGroupTab.IsSearchableSelection then
		return GF.FindGroupTab:IsSearchableSelection(node) == true
	end
	local owner = projection()
	return owner and owner.IsSearchable and owner.IsSearchable(node) == true
end

local function canStartSelectionSearch(node, forceSearch)
	if forceSearch ~= true and not shouldAutoSearchNode(node) then
		return true
	end
	local tab = GF.FindGroupTab
	if not (tab and type(tab.CanStartSelectionSearch) == "function") then
		return true
	end
	local allowed, reason = invoke(tab, "CanStartSelectionSearch", node, {
		source = forceSearch == true
			and "navRootRightClick" or "navSelection",
	})
	if allowed == true then
		return true
	end
	invoke(tab, "NotifySelectionSearchBlocked", reason)
	return false
end

local function autoSearchSelectedNode(node)
	if shouldAutoSearchNode(node) then
		invoke(GF.FindGroupTab, "DoSearch", { source = "navFlyoutClick" })
	end
end

local function clearBrowseSearchTerms()
	if currentTabID() == GF.TAB_BROWSE then
		invoke(GF.SubtitleBar, "ClearSearchText")
		invoke(GF.FindGroupTab, "ClearCommittedSearchQuery")
	end
end

function Presenter:ActivateFlyoutRow(row)
	local node = row and row.nodeData
	if self:IsNodeInteractionBlocked(node) or not self:IsInteractionEnabled() then
		return false
	end
	local tabID = currentTabID()
	if node.favoriteResult and (node.favoriteActivity or tabID == GF.TAB_BROWSE) then
		if not node.favoriteActivity and node.lazyKind
			and node.childrenLoaded ~= true
		then
			return self:OpenFrom(row, node)
		end
		local favorites = GF.FavoriteInstances
		local target = favorites and favorites.ResolveTarget
			and favorites:ResolveTarget(node, tabID) or nil
		if target then
			if not canStartSelectionSearch(target) then
				return false
			end
			clearBrowseSearchTerms()
			if not self:SetSelected(target, false, {
				selectionOptions = {
					favoriteRecordIdentity = node.favoriteIdentity,
				},
			}) then
				return false
			end
			autoSearchSelectedNode(target)
			self:HideAll()
			return true
		end
		self:HideAll()
		invoke(self.navTreeView, "Refresh")
		return false
	end
	if node.quickSearchDifficulty or node.quickSearchRecent then
		local search = GF.QuickSearch
		local target = search and search.ResolveTarget
			and search:ResolveTarget(node, tabID) or nil
		if not target then
			self:HideAll()
			invoke(self.navTreeView, "Refresh")
			return false
		end
		local repeatSearch = node.quickSearchRecent == true and tabID == GF.TAB_BROWSE
		if not canStartSelectionSearch(target, repeatSearch) then
			return false
		end
		clearBrowseSearchTerms()
		local selectionOptions = node.favoriteSourceIdentity and {
			favoriteRecordIdentity = node.favoriteSourceIdentity,
		} or nil
		if not self:SetSelected(target, false, {
			selectionOptions = selectionOptions,
		}) then
			return false
		end
		if repeatSearch then
			invoke(GF.FindGroupTab, "DoSearch", { source = "quickSearchHistory" })
		else
			autoSearchSelectedNode(target)
		end
		self:HideAll()
		return true
	end
	local owner = projection()
	if node.archiveInstanceShell == true and node.childrenLoaded ~= true then
		if not (owner and type(owner.EnsureChildren) == "function") then
			return false
		end
		owner.EnsureChildren(node)
		if node.disabled then
			self:CloseChildPanelsForRow(row)
			return true
		end
		local acceptsResolved = owner.AcceptsBrowseSelection
			and owner.AcceptsBrowseSelection(node) == true
		local remainsExpandable = self:NodeCanExpand(node)
		if not acceptsResolved then
			invoke(self.flyoutView, "RefreshVisibleRows")
			return false
		end
		if not canStartSelectionSearch(node) then
			-- Search preflight only guards selection/search. The already-authorized
			-- difficulty directory remains useful navigation and must still open.
			if remainsExpandable then
				self:OpenFrom(row, node)
			else
				invoke(self.flyoutView, "RefreshVisibleRows")
			end
			return remainsExpandable
		end
		clearBrowseSearchTerms()
		if not self:SetSelected(node, remainsExpandable, {
			keepFlyouts = remainsExpandable,
		}) then
			return false
		end
		if remainsExpandable then
			self:OpenFrom(row, node)
		else
			self:HideAll()
		end
		autoSearchSelectedNode(node)
		return true
	end
	local acceptsSelection = owner and owner.AcceptsBrowseSelection
		and owner.AcceptsBrowseSelection(node) == true
	if self:NodeCanExpand(node) then
		-- Background Journal reconciliation is an explicit-click side effect.
		-- Hover uses OpenFrom too; queuing here prevents pointer travel across the
		-- expansion list from accumulating an almost full Journal scan for later.
		if node.lazyKind == "archive_expansion" and GF.NavCatalog
			and type(GF.NavCatalog.RequestInstanceShellReconcile) == "function"
		then
			GF.NavCatalog.RequestInstanceShellReconcile(
				node.catalogKind, node.expansionIndex)
		end
		if acceptsSelection then
			if not canStartSelectionSearch(node) then
				-- Navigation can still expose descendants without replacing the
				-- selected result projection while a restricted search is cooling.
				self:OpenFrom(row, node)
				return true
			end
			if not self:SetSelected(node, true, { keepFlyouts = true }) then
				return false
			end
		end
		self:OpenFrom(row, node)
		autoSearchSelectedNode(node)
		return true
	end
	if acceptsSelection then
		if not canStartSelectionSearch(node) then
			return false
		end
		if not self:SetSelected(node) then
			return false
		end
		autoSearchSelectedNode(node)
		self:HideAll()
		return true
	end
	return false
end

function Presenter:CancelQuickSearchHover()
	state.hover.token = (state.hover.token or 0) + 1
	local timer = state.hover.timer
	if timer and timer.Cancel then
		timer:Cancel()
	end
	state.hover.timer = nil
	return state.hover.token
end

function Presenter:QueueQuickSearchHover(row)
	local node = row and row.nodeData
	local quickSearchResult = node and node.quickSearchResult == true
	local archiveInstanceShell = node
		and node.archiveInstanceShell == true
		and node.childrenLoaded ~= true
	if not (quickSearchResult or archiveInstanceShell) then
		return self:OpenFromHover(row)
	end
	self:CancelQuickSearchHover()
	local token = state.hover.token
	local searchGeneration = quickSearchResult
		and GF.QuickSearch and GF.QuickSearch.GetGeneration
		and GF.QuickSearch:GetGeneration() or 0
	local scheduledTimer
	local function openIfCurrent()
		if scheduledTimer == nil or state.hover.timer == scheduledTimer then
			state.hover.timer = nil
		end
		local currentGeneration = quickSearchResult
			and GF.QuickSearch and GF.QuickSearch.GetGeneration
			and GF.QuickSearch:GetGeneration() or 0
		if token ~= state.hover.token or row.nodeData ~= node
			or quickSearchResult and (
				node._gfQuickSearchGeneration ~= searchGeneration
				or currentGeneration ~= searchGeneration)
		then
			return
		end
		local hit = row.hit
		if hit and hit.IsMouseMotionFocus and not hit:IsMouseMotionFocus() then
			return
		end
		if archiveInstanceShell then
			-- Structural archive rows are intentionally cheap. Resolve only the one
			-- row under a stable pointer, then use the ordinary hover renderer to
			-- expose its difficulty children. This never changes selection or starts
			-- a search; a click keeps the immediate activation behavior.
			if node.archiveInstanceShell ~= true
				or node.childrenLoaded == true
			then
				return Presenter:OpenFromHover(row)
			end
			local owner = projection()
			if not (owner and type(owner.EnsureChildren) == "function") then
				return
			end
			owner.EnsureChildren(node)
			if row.nodeData ~= node then
				return
			end
			if node.disabled or not Presenter:NodeCanExpand(node) then
				Presenter:CloseChildPanelsForRow(row)
				invoke(Presenter.flyoutView, "RefreshVisibleRows")
				return
			end
		end
		Presenter:OpenFromHover(row)
	end
	if C_Timer and C_Timer.NewTimer then
		scheduledTimer = C_Timer.NewTimer(
			(archiveInstanceShell and GF.NAV_ARCHIVE_HOVER_DELAY)
				or GF.QUICK_SEARCH_HOVER_DELAY
				or LAZY_HOVER_DELAY,
			openIfCurrent)
		state.hover.timer = scheduledTimer
	else
		openIfCurrent()
	end
	return true
end

function Presenter:PlanRowPointerEnter(row)
	local node = row and row.nodeData
	if not (node and row.hit) then
		return { actionable = false, reason = "missing" }
	end
	if state.favorites.reorderMode then
		return { actionable = false, reason = "reorder" }
	end
	if self:IsNodeInteractionBlocked(node) then
		return {
			actionable = false,
			reason = "blocked",
			closeChildren = true,
			showDisabledReason = true,
		}
	end
	local delayedArchive = node.archiveInstanceShell == true
		and node.childrenLoaded ~= true
	return {
		actionable = true,
		delayed = node.quickSearchResult == true
			or delayedArchive,
		-- Do not leave a sibling's already-open difficulty panel attached while
		-- the pointer is waiting on this shell's debounce.
		closeChildren = delayedArchive,
	}
end

function Presenter:HandleRowPointerEnter(row)
	self:CancelQuickSearchHover()
	local plan = self:PlanRowPointerEnter(row)
	if plan.closeChildren then
		self:CloseChildPanelsForRow(row)
	end
	if plan.showDisabledReason then
		invoke(self.flyoutView, "RenderDisabledTooltip", row)
	end
	if plan.actionable then
		if plan.delayed then
			self:QueueQuickSearchHover(row)
		else
			self:OpenFromHover(row)
		end
	end
	invoke(self.flyoutView, "RenderRowHover", row, plan.actionable)
	return plan.actionable
end

function Presenter:RefreshFavoritePanel(root)
	if not (root and self:IsNodeOpen(root)) then
		return false
	end
	local children = state.favorites.children
	if children == nil or state.favorites.rootKey ~= root.key then
		children = self:ProjectFavorites(
			state.favorites.reorderMode and state.favorites.order or nil)
	end
	state.favorites.rootKey = root.key
	self:HideFromLevel(2)
	return invoke(self.flyoutView, "RenderFavoritePanel",
		root, self:FilterChildren(children)) == true
end

function Presenter:RefreshFavoriteSearchPanel(panel, query)
	local rootKey = state.openKeys and state.openKeys[0]
	local owner = projection()
	local root = rootKey and owner and owner.FindNodeByKey
		and owner.FindNodeByKey(rootKey) or nil
	if not (root and root.favoriteInstancesRoot
		and self:IsNodeOpen(root) and not state.favorites.reorderMode)
	then
		return false
	end
	self:SetFavoriteSearchQuery(query)
	self:CancelQuickSearchHover()
	local children = self:ProjectFavorites()
	state.favorites.rootKey = root.key
	self:HideFromLevel(2)
	return invoke(self.flyoutView, "RenderFavoritePanel",
		root, self:FilterChildren(children), panel) == true
end

function Presenter:EnterFavoriteReorderMode()
	local favorites = GF.FavoriteInstances
	if not (favorites and favorites.GetCount and favorites:GetCount() > 1) then
		return false
	end
	state.favorites.reorderMode = true
	state.favorites.order = favorites:GetIdentityOrder()
	state.favorites.dirty = nil
	self:CancelQuickSearchHover()
	self:HideFromLevel(2)
	invoke(self.flyoutView, "RenderFavoriteReorderMode", true)
	local children = self:ProjectFavorites(state.favorites.order)
	local rootKey = state.openKeys and state.openKeys[0]
	local owner = projection()
	local root = rootKey and owner and owner.FindNodeByKey
		and owner.FindNodeByKey(rootKey) or nil
	state.favorites.rootKey = root and root.key or nil
	state.favorites.children = children
	self:RefreshFavoritePanel(root)
	return true
end

function Presenter:MoveFavoriteDraft(identity, direction)
	if not state.favorites.reorderMode or type(identity) ~= "string" then
		return false
	end
	direction = direction < 0 and -1 or 1
	local order = state.favorites.order or {}
	local sourceIndex
	for index, currentIdentity in ipairs(order) do
		if currentIdentity == identity then
			sourceIndex = index
			break
		end
	end
	local targetIndex = sourceIndex and (sourceIndex + direction) or nil
	if not (targetIndex and targetIndex >= 1 and targetIndex <= #order) then
		return false
	end
	order[sourceIndex], order[targetIndex] = order[targetIndex], order[sourceIndex]
	state.favorites.dirty = true
	state.favorites.children = self:ProjectFavorites(order)
	local rootKey = state.openKeys and state.openKeys[0]
	local owner = projection()
	local root = rootKey and owner and owner.FindNodeByKey
		and owner.FindNodeByKey(rootKey) or nil
	self:RefreshFavoritePanel(root)
	return true
end

function Presenter:ExitFavoriteReorderMode(commit)
	if not state.favorites.reorderMode then
		return false
	end
	local favorites = GF.FavoriteInstances
	local order = state.favorites.order
	local dirty = state.favorites.dirty == true
	state.favorites.reorderMode = nil
	state.favorites.order = nil
	state.favorites.dirty = nil
	invoke(self.flyoutView, "RenderFavoriteReorderMode", false)
	local saved = commit == true and favorites and favorites.CommitOrder
		and favorites:CommitOrder(order, true) or false
	state.favorites.children = self:ProjectFavorites()
	local rootKey = state.openKeys and state.openKeys[0]
	local owner = projection()
	local root = rootKey and owner and owner.FindNodeByKey
		and owner.FindNodeByKey(rootKey) or nil
	if not self:RefreshFavoritePanel(root) then
		invoke(self.flyoutView, "RefreshVisibleRows")
	end
	if saved and GF.ShowTopNotice then
		GF.ShowTopNotice(
			(GF.L or {}).FAVORITE_INSTANCE_REORDER_SAVED
				or "Favorite activity order saved",
			{ source = "favorite_reorder", playSound = false })
	end
	return commit == true and (saved or not dirty)
end

function Presenter:IsFavoriteReorderMode()
	return state.favorites.reorderMode == true
end

function Presenter:GetFavoriteReorderOrder()
	return state.favorites.order
end

function Presenter:GetFavoriteCount()
	local favorites = GF.FavoriteInstances
	return favorites and favorites.GetCount and favorites:GetCount() or 0
end

function Presenter:RemoveFavorite(identity)
	local favorites = GF.FavoriteInstances
	local removed = favorites and favorites.Remove
		and favorites:Remove(identity) or false
	if removed then
		state.favorites.children = self:ProjectFavorites()
		self:ReanchorOpenPanels()
	end
	return removed
end

function Presenter:CanOpenFavoriteContextMenu(node)
	return not state.favorites.reorderMode and node ~= nil
		and node.favoriteResult == true
end

local function browseIsCurrent()
	return currentTabID() == GF.TAB_BROWSE
end

local function rootSupportsSearch(node)
	if not node or (node.level or 0) ~= 0 then
		return false
	end
	if GF.FindGroupTab and GF.FindGroupTab.IsSearchableSelection then
		return GF.FindGroupTab:IsSearchableSelection(node) == true
	end
	local owner = projection()
	return owner and owner.IsSearchable and owner.IsSearchable(node) == true
end

local function resetSearchTermsWhenChangingRoot(oldKey, newKey)
	if oldKey == nil or newKey == nil or oldKey == newKey
		or not browseIsCurrent()
	then
		return
	end
	invoke(GF.SubtitleBar, "ClearSearchText")
	invoke(GF.FindGroupTab, "ClearCommittedSearchQuery")
end

local function playNavigationSound()
	if GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("check")
	elseif PlaySound and SOUNDKIT
		and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
	then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
end

function Presenter:PlanRootActivation(node, button)
	if not self:IsInteractionEnabled() then
		return { action = "blocked", reason = "interaction" }
	end
	if not node or node.disabled then
		return { action = "blocked", reason = "node" }
	end
	if node.quickSearchRoot or node.favoriteInstancesRoot then
		return { action = "toggle_transient", node = node }
	end
	if button == "RightButton" and currentTabID() ~= GF.TAB_CREATE then
		return { action = "search_root", node = node }
	end
	if self:NodeCanExpand(node) and self:IsNodeOpen(node) then
		return { action = "close_root", node = node }
	end
	return { action = "activate_root", node = node }
end

function Presenter:ToggleTransientRoot(row, node)
	if self:IsNodeOpen(node) then
		self:HideAll()
		state.activeRootKey = nil
	else
		self:ClearActiveRoot(true, {
			clearSelection = true,
			clearSelectionInActiveRoot = true,
		})
		state.activeRootKey = node.key
		self:OpenFrom(row, node)
	end
	invoke(self.navTreeView, "Refresh")
	return true
end

function Presenter:SearchRoot(row)
	local node = row and row.nodeData
	if not self:IsInteractionEnabled() or not browseIsCurrent()
		or not node or node.disabled or not rootSupportsSearch(node)
	then
		return false
	end
	if not canStartSelectionSearch(node, true) then
		return false
	end
	local oldRoot = state.activeRootKey
		or self:RootKeyContaining(state.selectedKey)
	if not self:SetSelected(node) then
		return false
	end
	resetSearchTermsWhenChangingRoot(oldRoot, node.key)
	local started = invoke(GF.FindGroupTab, "DoSearch", {
		source = "navRootRightClick",
	}) == true
	if not started then
		return false
	end
	playNavigationSound()
	return true
end

function Presenter:ActivateRoot(row, button)
	local node = row and row.nodeData
	local plan = self:PlanRootActivation(node, button)
	if plan.action == "blocked" then
		return false
	elseif plan.action == "search_root" then
		return self:SearchRoot(row)
	end
	playNavigationSound()
	if plan.action == "toggle_transient" then
		return self:ToggleTransientRoot(row, node)
	elseif plan.action == "close_root" then
		forgetBranch(state.expanded, node)
		self:ClearActiveRoot(nil, { clearSelection = true })
		return true
	end
	local oldRoot = state.activeRootKey
		or self:RootKeyContaining(state.selectedKey)
	resetSearchTermsWhenChangingRoot(oldRoot, node.key)
	state.activeRootKey = node.key
	if self:ActivateFlyoutRow(row) then
		invoke(self.navTreeView, "Refresh")
		return true
	end
	if self:NodeCanExpand(node) then
		self:OpenFrom(row, node)
	end
	invoke(self.navTreeView, "Refresh")
	return true
end

function Presenter:BuildOpenPanelPlan(descriptors)
	local plan = {}
	local function findProjectedNode(key)
		if key == nil then
			return nil
		end
		local pending = {}
		for _, children in ipairs({
			state.quickSearch.children,
			state.favorites.children,
		}) do
			for index = #(children or {}), 1, -1 do
				pending[#pending + 1] = children[index]
			end
		end
		while #pending > 0 do
			local node = table.remove(pending)
			if node and node.key == key then
				return node
			end
			for index = #(node and node.children or {}), 1, -1 do
				pending[#pending + 1] = node.children[index]
			end
		end
		return nil
	end
	for _, descriptor in ipairs(descriptors or {}) do
		local owner = projection()
		local node = descriptor.openKey and owner and owner.FindNodeByKey
			and owner.FindNodeByKey(descriptor.openKey) or nil
		node = node or findProjectedNode(descriptor.openKey)
		if not node or self:IsNodeInteractionBlocked(node) then
			return plan, descriptor.index
		end
		local children
		if descriptor.quickSearchMode and node.quickSearchRoot then
			children = state.quickSearch.children or {}
		else
			children = self:FilterChildren(self:PrepareNode(node))
		end
		if #children == 0 then
			return plan, descriptor.index
		end
		plan[#plan + 1] = {
			index = descriptor.index,
			panel = descriptor.panel,
			anchorRow = descriptor.anchorRow,
			node = node,
			children = children,
		}
	end
	return plan, nil
end

function Presenter:ReanchorOpenPanels()
	local descriptors = invoke(self.flyoutView, "CollectOpenPanelDescriptors")
	local plan, closeFrom = self:BuildOpenPanelPlan(descriptors)
	invoke(self.flyoutView, "RenderReanchorOpenPanels", plan)
	if closeFrom then
		self:HideFromLevel(closeFrom)
		return false
	end
	return true
end
