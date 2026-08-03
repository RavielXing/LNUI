local _, GF = ...

local NavTree = {}
GF.NavTree = NavTree

local ROOT_ROW_CAPACITY = 16

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if method then
		return method(owner, ...)
	end
end

local function requestedNavWidth(value)
	return math.max(1, value or GF.GetNavWidth())
end

local function completeTree()
	if GF.NavData.GetTree then
		return GF.NavData.GetTree()
	end
	return GF.navTree or {}
end

local function rootsForWorkspace()
	local roots = completeTree()
	local workspaceView = GF.LFGWorkspaceView
	if workspaceView and workspaceView.GetVisibleRoots then
		return workspaceView:GetVisibleRoots(roots)
	end
	return roots
end

local function hasDescendants(node)
	if not node or node.isLeaf then
		return false
	end
	if node.lazyKind and node.childrenLoaded ~= true then
		return true
	end
	return type(node.children) == "table" and #node.children > 0
end

function NavTree.NodeCanExpand(node)
	return hasDescendants(node)
end

function NavTree.ShouldShowExpandArrow(node)
	local depth = node and (node.level or 0)
	return node ~= nil and node.disabled ~= true and depth >= 1 and depth <= 2
		and hasDescendants(node)
end

function NavTree.ApplyExpandArrow(row, node)
	if row == nil then
		return false
	end

	local arrow = row.arrow
	if arrow == nil then
		arrow = row:CreateTexture(nil, "OVERLAY", nil, 7)
		arrow:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.arrow = arrow
	end

	arrow:SetSize(GF.NAV_FLYOUT_ARROW_W or 10, GF.NAV_FLYOUT_ARROW_H or 16)
	if arrow.SetAtlas then
		arrow:SetAtlas(GF.NAV_FLYOUT_ARROW_ATLAS or "bag-arrow")
	else
		arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
	end
	arrow:SetRotation(math.pi)
	arrow:SetVertexColor(1, 1, 1, 1)

	local visible = NavTree.ShouldShowExpandArrow(node)
	arrow:SetShown(visible)
	return visible
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

local function forgetSiblingRoots(expansion, retainedKey)
	for _, root in ipairs(completeTree()) do
		if root and root.key and root.key ~= retainedKey then
			forgetBranch(expansion, root)
		end
	end
end

local function findPath(test)
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

		if node.lazyKind and node.childrenLoaded ~= true then
			local ensureChildren = GF.NavData and GF.NavData.EnsureChildren
			if ensureChildren then
				ensureChildren(node)
			end
		end
		for _, child in ipairs(node.children or {}) do
			if visit(child) then
				return true
			end
		end
		workingPath[#workingPath] = nil
		return false
	end

	for _, root in ipairs(completeTree()) do
		if visit(root) then
			break
		end
	end

	if match == nil then
		return nil, nil
	end
	local resultPath = {}
	for index = 1, #workingPath do
		resultPath[index] = workingPath[index]
	end
	return match, resultPath
end

local function rootKeyContaining(key)
	if key == nil then
		return nil
	end
	local _, path = findPath(function(node)
		return node.key == key
	end)
	return path and path[1] and path[1].key
end

local function rootKeyFor(node, path)
	if path and path[1] then
		return path[1].key
	end
	if node and (node.level or 0) == 0 then
		return node.key
	end
	return rootKeyContaining(node and node.key)
end

local function selectedRoot(nav)
	if not (nav.selectedKey and nav.activeRootKey) then
		return nil
	end
	local findNode = GF.NavData and GF.NavData.FindNodeByKey
	local node = findNode and findNode(nav.selectedKey)
	if node and (node.level or 0) == 0 and node.key == nav.activeRootKey then
		return node
	end
end

local function selectionBelongsToOpenRoot(nav)
	return nav.selectedKey ~= nil and nav.activeRootKey ~= nil
		and rootKeyContaining(nav.selectedKey) == nav.activeRootKey
end

function NavTree:EnsureState()
	self.expanded = self.expanded or {}
end

function NavTree:PrepareBranch(node)
	self:EnsureState()
	if not (node and node.key)
		or (self.IsNodeInteractionBlocked and self:IsNodeInteractionBlocked(node))
	then
		return
	end
	if node.lazyKind and node.childrenLoaded ~= true then
		local ensureChildren = GF.NavData and GF.NavData.EnsureChildren
		if ensureChildren then
			ensureChildren(node)
		end
	end
	if (node.level or 0) == 0 then
		forgetSiblingRoots(self.expanded, node.key)
	end
	self.expanded[node.key] = true
end

function NavTree:FindNodePathByActivityID(activityID)
	if activityID == nil then
		return nil, nil
	end
	return findPath(function(node)
		return node.activityID == activityID and node.categoryBrowse ~= true
	end)
end

function NavTree:FindNodePathByKey(key)
	if key == nil then
		return nil, nil
	end
	return findPath(function(node)
		return node.key == key
	end)
end

local function pathHasDisabledNode(path)
	for _, node in ipairs(path or {}) do
		if node and node.disabled then
			return true
		end
	end
	return false
end

local function resolvedNodePath(navTree, node, path)
	if path ~= nil or not (node and node.key) then
		return path
	end
	local findLoadedPath = GF.NavData and GF.NavData.FindLoadedNodePathByKey
	if findLoadedPath then
		local _, foundPath = findLoadedPath(node.key)
		return foundPath
	end
	local _, foundPath = navTree:FindNodePathByKey(node.key)
	return foundPath
end

function NavTree:IsNodeInteractionBlocked(node, path)
	if node == nil or node.disabled then
		return true
	end
	local resolvedPath = resolvedNodePath(self, node, path)
	if pathHasDisabledNode(resolvedPath) then
		return true
	end
	local rootKey = resolvedPath and resolvedPath[1] and resolvedPath[1].key
		or (path and path[1] and path[1].key)
	if rootKey and GF.NavData and GF.NavData.FindNodeByKey then
		local currentRoot = GF.NavData.FindNodeByKey(rootKey)
		if currentRoot and currentRoot.disabled then
			return true
		end
	end
	return false
end

function NavTree:GetNodeDisabledReason(node, path)
	local resolvedPath = resolvedNodePath(self, node, path)
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

function NavTree:SetSelectedSilently(node, path)
	if not (node and node.key) or self:IsNodeInteractionBlocked(node, path) then
		return
	end
	self:EnsureState()
	for index = 1, path and (#path - 1) or 0 do
		local ancestor = path[index]
		if ancestor and ancestor.key then
			self.expanded[ancestor.key] = true
		end
	end
	self.selectedKey = node.key
	self.activeRootKey = rootKeyFor(node, path)
	self:Refresh()
end

function NavTree:ClearActiveRoot(skipRefresh, options)
	options = options or {}
	local oldRoot = self.activeRootKey
	local flyoutsWereOpen = GF.NavFlyout and GF.NavFlyout.openKeys
		and next(GF.NavFlyout.openKeys) ~= nil
	local clearSelection = options.clearSelection
		and ((options.clearSelectionInActiveRoot and selectionBelongsToOpenRoot(self))
			or selectedRoot(self) ~= nil)

	if options.preserveSelectedRoot and not clearSelection and self.selectedKey then
		self.activeRootKey = rootKeyContaining(self.selectedKey)
	else
		self.activeRootKey = nil
	end
	invoke(GF.NavFlyout, "HideAll")

	if clearSelection then
		self.selectedKey = nil
		invoke(GF.MainFrame, "OnSelectionChanged", nil, options)
	end
	if not skipRefresh and (oldRoot ~= self.activeRootKey or oldRoot ~= nil or flyoutsWereOpen) then
		self:Refresh()
	end
end

local function makeRootRow(parent, name)
	local rowWidth = GF.GetNavWidth() - 8
	local row = CreateFrame("Frame", name, parent)
	row:SetWidth(rowWidth)
	row:SetHeight(20)

	local layers = {
		{ "bg", "BACKGROUND" },
		{ "cover", "ARTWORK", 1 },
		{ "hover", "OVERLAY", 1 },
		{ "sel", "OVERLAY", 2 },
	}
	for _, layer in ipairs(layers) do
		local texture = row:CreateTexture(nil, layer[2], nil, layer[3])
		texture:SetAllPoints()
		if layer[1] ~= "bg" then
			texture:Hide()
		end
		row[layer[1]] = texture
	end

	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontNormal")
	label:SetDrawLayer("OVERLAY", 7)
	label:SetPoint("LEFT", row, "LEFT", 8, 0)
	label:SetJustifyH("LEFT")
	label:SetMaxLines(1)
	row.label = label

	local hitTarget = CreateFrame("Button", nil, row)
	hitTarget:SetAllPoints()
	hitTarget:RegisterForClicks("LeftButtonUp")
	row.hit = hitTarget
	return row
end

function NavTree.CreateNavRowFrame(parent, name)
	return makeRootRow(parent, name)
end

local function refreshButtonArt(row)
	if row and GF.Icons and GF.Icons.ApplyNavButtonState then
		GF.Icons.ApplyNavButtonState(row)
	end
end

local function setPressed(row, value)
	if row == nil then
		return
	end
	row._navPressToken = (row._navPressToken or 0) + 1
	row._navPressed = value == true
	refreshButtonArt(row)
end

local function pulsePressed(row)
	if row == nil then
		return
	end
	local marker = (row._navPressToken or 0) + 1
	row._navPressToken = marker
	row._navPressed = true
	refreshButtonArt(row)

	if not (C_Timer and C_Timer.After) then
		row._navPressed = false
		refreshButtonArt(row)
		return
	end
	C_Timer.After(0.09, function()
		if row._navPressToken == marker then
			row._navPressed = false
			refreshButtonArt(row)
		end
	end)
end

local function playNavigationSound()
	if GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("check")
	elseif PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
end

local function browseIsCurrent()
	return invoke(GF.MainFrame, "GetCurrentTabID") == GF.TAB_BROWSE
end

local function rootSupportsSearch(node)
	if not node or (node.level or 0) ~= 0 then
		return false
	end
	if GF.FindGroupTab and GF.FindGroupTab.IsSearchableSelection then
		return GF.FindGroupTab:IsSearchableSelection(node) == true
	end
	local test = GF.NavData and GF.NavData.IsSearchable
	return test and test(node) == true
end

local function resetSearchTermsWhenChangingRoot(oldKey, newKey)
	if oldKey == nil or newKey == nil or oldKey == newKey or not browseIsCurrent() then
		return
	end
	invoke(GF.SubtitleBar, "ClearSearchText")
	invoke(GF.FindGroupTab, "ClearCommittedSearchQuery")
end

local function clearHistory(row)
	local node = row and row.nodeData
	if not NavTree:IsInteractionEnabled() or not node or node.disabled or node.navKind ~= "history" then
		return false
	end

	if GF.History and GF.History.Clear then
		GF.History.Clear()
	end
	if GF.SubtitleBar and GF.SubtitleBar.ResetBrowse then
		GF.SubtitleBar:ResetBrowse()
	else
		playNavigationSound()
		invoke(GF.SubtitleBar, "ClearSearchText")
		if GF.FindGroupTab and GF.FindGroupTab.ResetBrowsePage then
			GF.FindGroupTab:ResetBrowsePage()
		else
			invoke(GF.FindGroupTab, "ClearCommittedSearchQuery")
		end
	end

	invoke(GF.NavFlyout, "HideAll")
	if NavTree.activeRootKey == node.key then
		NavTree.activeRootKey = nil
	end
	NavTree:Refresh()
	pulsePressed(row)
	return true
end

local function searchRoot(row)
	local node = row and row.nodeData
	if not NavTree:IsInteractionEnabled() or not browseIsCurrent()
		or not node or node.disabled or not rootSupportsSearch(node) then
		return
	end

	playNavigationSound()
	local oldRoot = NavTree.activeRootKey or rootKeyContaining(NavTree.selectedKey)
	resetSearchTermsWhenChangingRoot(oldRoot, node.key)
	NavTree:SetSelected(node)
	invoke(GF.FindGroupTab, "DoSearch", { source = "navRootRightClick" })
end

local function activateRoot(row, button)
	if button == "RightButton" then
		if not clearHistory(row) then
			searchRoot(row)
		end
		return
	end
	if not NavTree:IsInteractionEnabled() then
		return
	end

	local node = row and row.nodeData
	if not node or node.disabled then
		return
	end
	playNavigationSound()

	if hasDescendants(node) and invoke(GF.NavFlyout, "IsNodeOpen", node) then
		forgetBranch(NavTree.expanded or {}, node)
		NavTree:ClearActiveRoot(nil, { clearSelection = true })
		return
	end

	local oldRoot = NavTree.activeRootKey or rootKeyContaining(NavTree.selectedKey)
	resetSearchTermsWhenChangingRoot(oldRoot, node.key)
	NavTree.activeRootKey = node.key
	if invoke(GF.NavFlyout, "OnRowClick", row) then
		NavTree:Refresh()
		return
	end
	if hasDescendants(node) then
		invoke(GF.NavFlyout, "OpenFrom", row, node)
	end
	NavTree:Refresh()
end

local function wireRootRow(row)
	row.hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row.hit:SetScript("OnEnter", function()
		local node = row.nodeData
		if node == nil then
			return
		end
		if node.disabled then
			row._navHover = false
			row._navPressed = false
			refreshButtonArt(row)
			return
		end
		if not NavTree:IsInteractionEnabled() then
			return
		end
		row._navHover = true
		refreshButtonArt(row)
	end)
	row.hit:SetScript("OnLeave", function()
		row._navHover = false
		row._navPressed = false
		refreshButtonArt(row)
	end)
	row.hit:SetScript("OnMouseDown", function(_, button)
		if (button == "LeftButton" or button == "RightButton")
			and NavTree:IsInteractionEnabled() and row.nodeData and not row.nodeData.disabled then
			setPressed(row, true)
		end
	end)
	row.hit:SetScript("OnMouseUp", function()
		setPressed(row, false)
	end)
	row.hit:SetScript("OnClick", function(_, button)
		activateRoot(row, button)
	end)
end

local function newRootRow(parent, index)
	local row = makeRootRow(parent, "GroupFinderAddonNavRow" .. index)
	wireRootRow(row)
	return row
end

local function createResizeGrip(divider)
	if not divider or divider.gfNavResize then
		return divider and divider.gfNavResize
	end
	if (GF.NAV_WIDTH_MIN or 0) >= (GF.NAV_WIDTH_MAX or 0) then
		return nil
	end

	local grip = CreateFrame("Frame", nil, divider)
	grip:SetPoint("TOP", divider, "TOP")
	grip:SetPoint("BOTTOM", divider, "BOTTOM")
	grip:SetPoint("CENTER", divider, "CENTER")
	grip:SetWidth(GF.NAV_DIVIDER_GRIP_W or 6)
	grip:SetFrameLevel((divider:GetFrameLevel() or 1) + 4)
	grip:EnableMouse(true)

	local function stopDrag(self, shouldSave)
		self:SetScript("OnUpdate", nil)
		invoke(GF.MainFrame, "NavWidthDragEnd", shouldSave, self._gfPreviewW)
	end

	local function updateDrag(self)
		if not IsMouseButtonDown("LeftButton") then
			stopDrag(self, true)
			return
		end
		local cursorX = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
		local width = GF.ClampNavWidth(self._gfDragStartW + cursorX - self._gfDragStartX)
		self._gfPreviewW = width
		if width ~= self._gfLastPreviewW then
			self._gfLastPreviewW = width
			invoke(GF.MainFrame, "NavWidthDragPreview", width)
		end
	end

	grip:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		self._gfDragStartX = select(1, GetCursorPosition()) / UIParent:GetEffectiveScale()
		self._gfDragStartW = GF.GetNavWidth()
		self._gfPreviewW = self._gfDragStartW
		self._gfLastPreviewW = nil
		invoke(GF.MainFrame, "NavWidthDragBegin")
		self:SetScript("OnUpdate", updateDrag)
	end)

	divider.gfNavResize = grip
	return grip
end

function NavTree:CancelLayoutDebounce()
	if self._layoutDebounce then
		invoke(self._layoutDebounce, "Cancel")
		self._layoutDebounce = nil
	end
end

function NavTree:ScheduleLayoutRows()
	self:CancelLayoutDebounce()
	if not (C_Timer and C_Timer.NewTimer) then
		self:LayoutRows()
		return
	end
	self._layoutDebounce = C_Timer.NewTimer(GF.LAYOUT_RESIZE_DEBOUNCE or 0.1, function()
		NavTree._layoutDebounce = nil
		NavTree:LayoutRows()
	end)
end

function NavTree:SyncAfterHostWidth(navWidth)
	local adjustedWidth = requestedNavWidth(GF.ClampNavWidth(navWidth))
	self.contentWidth, self._lastLayoutW = adjustedWidth, adjustedWidth
	local content, divider, flyout = self.content, self.dividerHost, GF.NavFlyout
	if content then
		content:SetWidth(adjustedWidth)
	end
	if divider then
		GF.UI.LayoutNavColumnDivider(divider)
	end
	self:LayoutRows()
	if flyout then
		invoke(flyout, "SyncPanelWidth")
		invoke(flyout, "HideAll")
	end
end

function NavTree:Init(host)
	self.host = host
	self.expanded = {}
	self.selectedKey = nil
	self.contentWidth = requestedNavWidth(GF.GetNavWidth())
	self.interactionEnabled = true

	local content = CreateFrame("Frame", nil, host)
	content:SetWidth(self.contentWidth)
	content:SetPoint("TOPLEFT", host, "TOPLEFT")
	content:SetPoint("TOPRIGHT", host, "TOPRIGHT")
	content:SetFrameLevel(host:GetFrameLevel() + 2)
	self.content = content

	local divider = CreateFrame("Frame", nil, host)
	GF.UI.InstallNavColumnDivider(divider)
	GF.UI.LayoutNavColumnDivider(divider)
	divider:SetAlpha(1)
	createResizeGrip(divider)
	self.dividerHost = divider

	self.rows = {}
	for index = 1, ROOT_ROW_CAPACITY do
		local row = newRootRow(content, index)
		row:Hide()
		self.rows[index] = row
	end

	if GF.NavFlyout and GF.NavFlyout.Init then
		GF.NavFlyout:Init(GF.MainFrame and GF.MainFrame.frame or host, self)
	end

	self._lastLayoutW = self.contentWidth
	host:SetScript("OnSizeChanged", function(_, width)
		if NavTree._frameResizing or GF._frameResizing then
			return
		end
		width = width or (NavTree.host and NavTree.host:GetWidth())
		if width and width >= 10 and width ~= NavTree._lastLayoutW then
			NavTree._lastLayoutW = width
			NavTree:ScheduleLayoutRows()
		end
	end)
	self:Refresh()
end

function NavTree:IsInteractionEnabled()
	return self.interactionEnabled ~= false
end

function NavTree:SetInteractionEnabled(enabled)
	enabled = enabled ~= false
	if enabled == self.interactionEnabled then
		return
	end
	self.interactionEnabled = enabled
	invoke(GF.NavFlyout, "HideAll")
	if self.content then
		self.content:SetAlpha(enabled and 1 or 0.45)
	end
	if self.dividerHost and self.dividerHost.gfNavResize then
		self.dividerHost.gfNavResize:EnableMouse(enabled)
	end
	for _, row in ipairs(self.rows or {}) do
		if row.hit then
			row.hit:EnableMouse(enabled
				and not self:IsNodeInteractionBlocked(row.nodeData))
		end
		row._navHover = false
		row._navPressed = false
		if row:IsShown() then
			refreshButtonArt(row)
		end
	end
end

function NavTree:ToggleExpand(key, skipRefresh)
	self:EnsureState()
	local findNode = GF.NavData and GF.NavData.FindNodeByKey
	local node = findNode and findNode(key)
	if node == nil or self:IsNodeInteractionBlocked(node) then
		return
	end
	if self.expanded[key] then
		forgetBranch(self.expanded, node)
	else
		self:PrepareBranch(node)
	end
	if not skipRefresh then
		self:Refresh()
	end
end

local function rememberHistory(node)
	if not (GF.History and GF.History.Add) then
		return
	end
	GF.History.Add({
		label = node.label,
		categoryID = node.categoryID,
		filters = node.filters,
		searchFilters = node.searchFilters,
		preferredFilters = node.preferredFilters,
		searchPreferredFilters = node.searchPreferredFilters,
		groupID = node.groupID,
		activityID = node.activityID,
	})
end

function NavTree:SetSelected(node, skipRefresh, options)
	if not node or self:IsNodeInteractionBlocked(node) or not self:IsInteractionEnabled() then
		return
	end
	local workspace = GF.LFGWorkspaceView
	if workspace and workspace.IsNodeAllowed and not workspace:IsNodeAllowed(node) then
		return
	end
	if not GF.NavData.AcceptsBrowseSelection(node) then
		return
	end

	options = options or {}
	self.selectedKey = node.key
	if options.visual ~= false then
		self.activeRootKey = rootKeyFor(node)
	end
	if GF.NavData.IsSearchable(node) and node.isLeaf
		and (node.activityID or node.categoryBrowse) and not node.customBucket then
		rememberHistory(node)
	end
	invoke(GF.MainFrame, "OnSelectionChanged", node)
	if not options.keepFlyouts then
		invoke(GF.NavFlyout, "HideAll")
	end
	if not skipRefresh then
		self:Refresh()
	end
end

function NavTree:Refresh()
	self:EnsureState()
	if self.content and self.rows then
		self:LayoutRows()
	end
end

function NavTree:LayoutRows()
	if not (self.content and self.rows) then
		return
	end
	local roots = rootsForWorkspace()
	local offset = GF.NAV_LIST_PADDING_TOP or 0
	local width = self.content:GetWidth()
	if not width or width < 10 then
		width = self.contentWidth or requestedNavWidth(GF.GetNavWidth())
	end
	self.content:SetWidth(width)

	for index, node in ipairs(roots) do
		local row = self.rows[index]
		if row == nil then
			break
		end
		local height = GF.NAV_L0_ROW_H or (GF.NAV_ROW_H and GF.NAV_ROW_H[0]) or 45
		row:SetSize(width, height)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -offset)
		row.nodeData = node
		row._gfNavLevel = 0
		row._navHover = false
		row._navPressed = false
		row:Show()
		if node.disabled and invoke(GF.NavFlyout, "IsNodeOpen", node) then
			invoke(GF.NavFlyout, "HideAll")
		end

		GF.Icons.ApplyNavButton(row, 0, node.label or "", width, height, {
			selected = self.activeRootKey == node.key,
			canExpand = false,
			expanded = self.expanded[node.key] == true,
		})
		if row.label then
			row.label:SetJustifyH("LEFT")
		end
		if row.hit then
			row.hit:EnableMouse(self:IsInteractionEnabled()
				and not self:IsNodeInteractionBlocked(node))
			row.hit:SetFrameLevel(row:GetFrameLevel() + 8)
		end

		offset = offset + height
		if roots[index + 1] then
			offset = offset + (GF.NAV_L0_ROW_SPACING or 0)
		end
	end

	for index = #roots + 1, ROOT_ROW_CAPACITY do
		local row = self.rows[index]
		if row then
			row.nodeData = nil
			row:Hide()
		end
	end
	self.content:SetHeight(math.max(1, offset + 1))
end

function NavTree:DeferredRefresh()
	self:Refresh()
end

function NavTree:Show()
	if self.content then
		self.content:Show()
	end
end

function NavTree:Hide()
	invoke(GF.NavFlyout, "HideAll")
	if self.content then
		self.content:Hide()
	end
end

function NavTree:SetVisible(visible)
	if visible then
		self:Show()
	else
		self:Hide()
	end
end
