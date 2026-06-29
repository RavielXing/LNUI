local _, GF = ...

GF.NavTree = {}
local NT = GF.NavTree

local L0_POOL = 16

local function getNavContentWidth(navW)
	return math.max(1, navW or GF.GetNavWidth())
end

local function nodeCanExpand(n)
	if not n or n.isLeaf then
		return false
	end
	if n.lazyKind and not n.childrenLoaded then
		return true
	end
	return n.children and #n.children > 0
end

function NT.NodeCanExpand(n)
	return nodeCanExpand(n)
end

function NT.ShouldShowExpandArrow(node)
	if not node or node.disabled then
		return false
	end
	local level = node.level or 0
	return nodeCanExpand(node) and level >= 1 and level <= 2
end

function NT.ApplyExpandArrow(row, node)
	if not row then
		return false
	end
	if not row.arrow then
		local arrow = row:CreateTexture(nil, "OVERLAY", nil, 7)
		arrow:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.arrow = arrow
	end
	local arrow = row.arrow
	arrow:SetSize(GF.NAV_FLYOUT_ARROW_W or 10, GF.NAV_FLYOUT_ARROW_H or 16)
	if arrow.SetAtlas then
		arrow:SetAtlas(GF.NAV_FLYOUT_ARROW_ATLAS or "bag-arrow")
	else
		arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
	end
	arrow:SetRotation(math.pi)
	arrow:SetVertexColor(1, 1, 1, 1)
	local show = NT.ShouldShowExpandArrow(node)
	arrow:SetShown(show)
	return show
end

local function collapseNodeBranch(expanded, n)
	if not n or not n.key then
		return
	end
	expanded[n.key] = nil
	if n.children then
		for _, child in ipairs(n.children) do
			collapseNodeBranch(expanded, child)
		end
	end
end

local function collapseOtherL0Roots(expanded, exceptKey)
	local tree = GF.NavData.GetTree and GF.NavData.GetTree() or GF.navTree
	for _, root in ipairs(tree or {}) do
		local rootKey = root and root.key
		if rootKey and rootKey ~= exceptKey then
			collapseNodeBranch(expanded, root)
		end
	end
end

local function findRootKeyForNodeKey(key)
	if not key then
		return nil
	end
	local foundRootKey
	local function walk(n, rootKey)
		if foundRootKey or not n then
			return
		end
		local level = n.level or 0
		rootKey = rootKey or (level == 0 and n.key)
		if n.key == key then
			foundRootKey = rootKey
			return
		end
		if n.children then
			for _, child in ipairs(n.children) do
				walk(child, rootKey)
			end
		end
	end
	for _, root in ipairs((GF.NavData.GetTree and GF.NavData.GetTree()) or GF.navTree or {}) do
		walk(root)
	end
	return foundRootKey
end

local function copyPath(path)
	local nextPath = {}
	for k, v in pairs(path or {}) do
		nextPath[k] = v
	end
	return nextPath
end

local function rootKeyForNode(node, path)
	if path and path[1] and path[1].key then
		return path[1].key
	end
	if node and (node.level or 0) == 0 then
		return node.key
	end
	return findRootKeyForNodeKey(node and node.key)
end

local function selectedNodeIsActiveRoot(navTree)
	if not navTree or not navTree.selectedKey or not navTree.activeRootKey then
		return false
	end
	local selected = GF.NavData.FindNodeByKey and GF.NavData.FindNodeByKey(navTree.selectedKey)
	return selected and (selected.level or 0) == 0 and selected.key == navTree.activeRootKey
end

local function selectedNodeIsInActiveRoot(navTree)
	if not navTree or not navTree.selectedKey or not navTree.activeRootKey then
		return false
	end
	local selected = GF.NavData.FindNodeByKey and GF.NavData.FindNodeByKey(navTree.selectedKey)
	return selected and rootKeyForNode(selected) == navTree.activeRootKey
end

local function findNodePath(predicate)
	local path = {}
	local foundNode
	local function walk(n)
		if foundNode or not n then
			return false
		end
		path[#path + 1] = n
		if predicate(n) then
			foundNode = n
			return true
		end
		if n.lazyKind and not n.childrenLoaded and GF.NavData and GF.NavData.EnsureChildren then
			GF.NavData.EnsureChildren(n)
		end
		if n.children then
			for _, child in ipairs(n.children) do
				if walk(child) then
					return true
				end
			end
		end
		path[#path] = nil
		return false
	end
	for _, root in ipairs(GF.NavData.GetTree()) do
		if walk(root) then
			break
		end
	end
	if foundNode then
		local out = {}
		for i, n in ipairs(path) do
			out[i] = n
		end
		return foundNode, out
	end
	return nil, nil
end

local function installNavResizeDivider(dividerHost)
	if not dividerHost or dividerHost.gfNavResize then
		return dividerHost and dividerHost.gfNavResize
	end
	if (GF.NAV_WIDTH_MIN or 0) >= (GF.NAV_WIDTH_MAX or 0) then
		return nil
	end
	local gripW = GF.NAV_DIVIDER_GRIP_W or 6
	local grip = CreateFrame("Frame", nil, dividerHost)
	grip:SetPoint("TOP", dividerHost, "TOP", 0, 0)
	grip:SetPoint("BOTTOM", dividerHost, "BOTTOM", 0, 0)
	grip:SetWidth(gripW)
	grip:SetPoint("CENTER", dividerHost, "CENTER", 0, 0)
	grip:EnableMouse(true)
	grip:SetFrameLevel((dividerHost:GetFrameLevel() or 1) + 4)

	local function finishDrag(self, save)
		self:SetScript("OnUpdate", nil)
		local mf = GF.MainFrame
		if mf and mf.NavWidthDragEnd then
			mf:NavWidthDragEnd(save, self._gfPreviewW)
		end
	end

	local function onUpdate(self)
		if not IsMouseButtonDown("LeftButton") then
			finishDrag(self, true)
			return
		end
		local scale = UIParent:GetEffectiveScale()
		local cx = select(1, GetCursorPosition()) / scale
		local w = GF.ClampNavWidth(self._gfDragStartW + (cx - self._gfDragStartX))
		self._gfPreviewW = w
		if w == self._gfLastPreviewW then
			return
		end
		self._gfLastPreviewW = w
		local mf = GF.MainFrame
		if mf and mf.NavWidthDragPreview then
			mf:NavWidthDragPreview(w)
		end
	end

	grip:SetScript("OnMouseDown", function(self, btn)
		if btn ~= "LeftButton" then
			return
		end
		local scale = UIParent:GetEffectiveScale()
		self._gfDragStartX = select(1, GetCursorPosition()) / scale
		self._gfDragStartW = GF.GetNavWidth()
		self._gfPreviewW = self._gfDragStartW
		self._gfLastPreviewW = nil
		local mf = GF.MainFrame
		if mf and mf.NavWidthDragBegin then
			mf:NavWidthDragBegin()
		end
		self:SetScript("OnUpdate", onUpdate)
	end)

	dividerHost.gfNavResize = grip
	return grip
end

function NT:EnsureState()
	if not self.expanded then
		self.expanded = {}
	end
end

function NT.CreateNavRowFrame(parent, name)
	local row = CreateFrame("Frame", name, parent)
	row:SetSize(GF.GetNavWidth() - 8, 20)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.cover = row:CreateTexture(nil, "ARTWORK", nil, 1)
	row.cover:SetAllPoints()
	row.cover:Hide()
	row.hover = row:CreateTexture(nil, "OVERLAY", nil, 1)
	row.hover:SetAllPoints()
	row.hover:Hide()
	row.sel = row:CreateTexture(nil, "OVERLAY", nil, 2)
	row.sel:SetAllPoints()
	row.sel:Hide()
	row.label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontNormal")
	row.label:SetDrawLayer("OVERLAY", 7)
	row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetMaxLines(1)
	row.hit = CreateFrame("Button", nil, row)
	row.hit:SetAllPoints()
	row.hit:RegisterForClicks("LeftButtonUp")
	return row
end

function NT:PrepareBranch(node)
	self:EnsureState()
	if not node or not node.key then
		return
	end
	if not node.childrenLoaded and node.lazyKind and GF.NavData.EnsureChildren then
		GF.NavData.EnsureChildren(node)
	end
	if (node.level or 0) == 0 then
		collapseOtherL0Roots(self.expanded, node.key)
	end
	self.expanded[node.key] = true
end

function NT:FindNodePathByActivityID(activityID)
	if not activityID then
		return nil, nil
	end
	return findNodePath(function(n)
		return n.activityID == activityID and not n.categoryBrowse
	end)
end

function NT:FindNodePathByKey(key)
	if not key then
		return nil, nil
	end
	return findNodePath(function(n)
		return n.key == key
	end)
end

function NT:SetSelectedSilently(node, path)
	if not node or not node.key then
		return
	end
	self:EnsureState()
	if path then
		for i = 1, #path - 1 do
			local n = path[i]
			if n and n.key then
				self.expanded[n.key] = true
			end
		end
	end
	self.selectedKey = node.key
	self.activeRootKey = rootKeyForNode(node, path)
	self:Refresh()
end

function NT:ClearActiveRoot(skipRefresh, opts)
	local hadActiveRoot = self.activeRootKey ~= nil
	local hadFlyout = GF.NavFlyout and GF.NavFlyout.openKeys and next(GF.NavFlyout.openKeys) ~= nil
	local clearSelection = opts and opts.clearSelection
		and ((opts.clearSelectionInActiveRoot and selectedNodeIsInActiveRoot(self)) or selectedNodeIsActiveRoot(self))
	self.activeRootKey = nil
	if GF.NavFlyout then
		GF.NavFlyout:HideAll()
	end
	if clearSelection then
		self.selectedKey = nil
		if GF.MainFrame and GF.MainFrame.OnSelectionChanged then
			GF.MainFrame:OnSelectionChanged(nil, opts)
		end
	end
	if not skipRefresh and (hadActiveRoot or hadFlyout) and self.Refresh then
		self:Refresh()
	end
end

local function playNavClickSound()
	if GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("check")
	elseif PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
end

local function onRowEnter(row)
	if not NT:IsInteractionEnabled() then
		return
	end
	if not row.nodeData or row.nodeData.disabled then
		return
	end
	row._navHover = true
	if GF.Icons.ApplyNavButtonState then
		GF.Icons.ApplyNavButtonState(row)
	end
end

local function onRowLeave(row)
	row._navHover = false
	row._navPressed = false
	if GF.Icons.ApplyNavButtonState then
		GF.Icons.ApplyNavButtonState(row)
	end
end

local function clearBrowseSearchKeywordForRootSwitch(previousRootKey, nextRootKey)
	if not previousRootKey or not nextRootKey or previousRootKey == nextRootKey then
		return
	end
	local mainFrame = GF.MainFrame
	if not (mainFrame and mainFrame.GetCurrentTabID and mainFrame:GetCurrentTabID() == GF.TAB_BROWSE) then
		return
	end
	if GF.SubtitleBar and GF.SubtitleBar.ClearSearchText then
		GF.SubtitleBar:ClearSearchText()
	end
	if GF.FindGroupTab and GF.FindGroupTab.ClearCommittedSearchQuery then
		GF.FindGroupTab:ClearCommittedSearchQuery()
	end
end

local function onRowClick(row)
	if not NT:IsInteractionEnabled() then
		return
	end
	local n = row.nodeData
	if not n or n.disabled then
		return
	end
	playNavClickSound()
	if nodeCanExpand(n) and GF.NavFlyout and GF.NavFlyout.IsNodeOpen and GF.NavFlyout:IsNodeOpen(n) then
		collapseNodeBranch(NT.expanded or {}, n)
		NT:ClearActiveRoot(nil, { clearSelection = true })
		return
	end
	local previousRootKey = NT.activeRootKey or findRootKeyForNodeKey(NT.selectedKey)
	clearBrowseSearchKeywordForRootSwitch(previousRootKey, n.key)
	NT.activeRootKey = n.key
	if GF.NavFlyout and GF.NavFlyout.OnRowClick and GF.NavFlyout:OnRowClick(row) then
		NT:Refresh()
		return
	end
	if nodeCanExpand(n) and GF.NavFlyout then
		GF.NavFlyout:OpenFrom(row, n)
	end
	NT:Refresh()
end

local function createL0Row(parent, index)
	local row = NT.CreateNavRowFrame(parent, "GroupFinderAddonNavRow" .. index)
	row.hit:SetScript("OnEnter", function()
		onRowEnter(row)
	end)
	row.hit:SetScript("OnLeave", function()
		onRowLeave(row)
	end)
	row.hit:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and NT:IsInteractionEnabled() and row.nodeData and not row.nodeData.disabled then
			row._navPressed = true
			GF.Icons.ApplyNavButtonState(row)
		end
	end)
	row.hit:SetScript("OnMouseUp", function()
		row._navPressed = false
		GF.Icons.ApplyNavButtonState(row)
	end)
	row.hit:SetScript("OnClick", function()
		onRowClick(row)
	end)
	return row
end

function NT:CancelLayoutDebounce()
	if self._layoutDebounce and self._layoutDebounce.Cancel then
		self._layoutDebounce:Cancel()
	end
	self._layoutDebounce = nil
end

function NT:ScheduleLayoutRows()
	self:CancelLayoutDebounce()
	if not C_Timer or not C_Timer.After then
		self:LayoutRows()
		return
	end
	self._layoutDebounce = C_Timer.After(GF.LAYOUT_RESIZE_DEBOUNCE or 0.1, function()
		self._layoutDebounce = nil
		NT:LayoutRows()
	end)
end

function NT:SyncAfterHostWidth(navW)
	navW = GF.ClampNavWidth(navW)
	self.contentWidth = getNavContentWidth(navW)
	if self.content then
		self.content:SetWidth(self.contentWidth)
	end
	self._lastLayoutW = self.contentWidth
	self:LayoutRows()
	if self.dividerHost then
		GF.UI.LayoutNavColumnDivider(self.dividerHost)
	end
	if GF.NavFlyout and GF.NavFlyout.SyncPanelWidth then
		GF.NavFlyout:SyncPanelWidth()
		GF.NavFlyout:HideAll()
	end
end

function NT:Init(host)
	self.host = host
	self.expanded = {}
	self.selectedKey = nil
	self.contentWidth = getNavContentWidth(GF.GetNavWidth())
	self.interactionEnabled = true

	self.content = CreateFrame("Frame", nil, host)
	self.content:SetWidth(self.contentWidth)
	self.content:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	self.content:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
	self.content:SetFrameLevel(host:GetFrameLevel() + 2)

	self.dividerHost = CreateFrame("Frame", nil, host)
	GF.UI.InstallNavColumnDivider(self.dividerHost)
	GF.UI.LayoutNavColumnDivider(self.dividerHost)
	self.dividerHost:SetAlpha(1)
	installNavResizeDivider(self.dividerHost)

	self.rows = {}
	for i = 1, L0_POOL do
		self.rows[i] = createL0Row(self.content, i)
		self.rows[i]:Hide()
	end

	if GF.NavFlyout and GF.NavFlyout.Init then
		local anchorParent = GF.MainFrame and GF.MainFrame.frame or host
		GF.NavFlyout:Init(anchorParent, self)
	end

	self._lastLayoutW = self.contentWidth
	host:SetScript("OnSizeChanged", function(_, w)
		if NT._frameResizing or GF._frameResizing then
			return
		end
		w = w or (NT.host and NT.host:GetWidth())
		if not w or w < 10 then
			return
		end
		if w ~= NT._lastLayoutW then
			NT._lastLayoutW = w
			NT:ScheduleLayoutRows()
		end
	end)
	self:Refresh()
end

function NT:IsInteractionEnabled()
	return self.interactionEnabled ~= false
end

function NT:SetInteractionEnabled(enabled)
	enabled = enabled ~= false
	if self.interactionEnabled == enabled then
		return
	end
	self.interactionEnabled = enabled
	if GF.NavFlyout then
		GF.NavFlyout:HideAll()
	end
	if self.content then
		self.content:SetAlpha(enabled and 1 or 0.45)
	end
	if self.dividerHost and self.dividerHost.gfNavResize then
		self.dividerHost.gfNavResize:EnableMouse(enabled)
	end
	if self.rows then
		for _, row in ipairs(self.rows) do
			if row.hit then
				row.hit:EnableMouse(enabled)
			end
			row._navHover = false
			row._navPressed = false
			if row:IsShown() then
				GF.Icons.ApplyNavButtonState(row)
			end
		end
	end
end

function NT:ToggleExpand(key, skipRefresh)
	self:EnsureState()
	local n = GF.NavData.FindNodeByKey and GF.NavData.FindNodeByKey(key)
	if not n then
		return
	end
	local expanding = not self.expanded[key]
	if expanding then
		self:PrepareBranch(n)
	else
		collapseNodeBranch(self.expanded, n)
	end
	if not skipRefresh then
		self:Refresh()
	end
end

function NT:SetSelected(node, skipRefresh, opts)
	if not node or node.disabled or not self:IsInteractionEnabled() then
		return
	end
	if not GF.NavData.AcceptsBrowseSelection(node) then
		return
	end
	self.selectedKey = node.key
	if not (opts and opts.visual == false) then
		self.activeRootKey = rootKeyForNode(node)
	end
	if GF.NavData.IsSearchable(node) and node.isLeaf and (node.activityID or node.categoryBrowse) then
		if GF.History then
			GF.History.Add({
				label = node.label,
				categoryID = node.categoryID,
				filters = node.filters,
				preferredFilters = node.preferredFilters,
				groupID = node.groupID,
				activityID = node.activityID,
			})
		end
	end
	if GF.MainFrame and GF.MainFrame.OnSelectionChanged then
		GF.MainFrame:OnSelectionChanged(node)
	end
	if GF.NavFlyout and not (opts and opts.keepFlyouts) then
		GF.NavFlyout:HideAll()
	end
	if not skipRefresh then
		self:Refresh()
	end
end

function NT:Refresh()
	self:EnsureState()
	if self.content and self.rows then
		self:LayoutRows()
	end
end

function NT:LayoutRows()
	if not self.content or not self.rows then
		return
	end
	local tree = GF.NavData.GetTree and GF.NavData.GetTree() or {}
	local y = GF.NAV_LIST_PADDING_TOP or 0
	local width = self.content:GetWidth()
	if not width or width < 10 then
		width = self.contentWidth or getNavContentWidth(GF.GetNavWidth())
	end
	self.content:SetWidth(width)

	local activeRootKey = self.activeRootKey
	for i, n in ipairs(tree) do
		local row = self.rows[i]
		if not row then
			break
		end
		local h = GF.NAV_L0_ROW_H or (GF.NAV_ROW_H and GF.NAV_ROW_H[0]) or 45
		row:SetHeight(h)
		row:SetWidth(width)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
		row.nodeData = n
		row._gfNavLevel = 0
		row._navHover = false
		row._navPressed = false
		row:Show()

		local isSel = activeRootKey == n.key
		GF.Icons.ApplyNavButton(row, 0, n.label or "", width, h, {
			selected = isSel,
			canExpand = false,
			expanded = self.expanded and self.expanded[n.key] == true,
		})
		if row.label then
			row.label:SetJustifyH("LEFT")
		end
		if row.hit then
			row.hit:EnableMouse(self:IsInteractionEnabled())
			row.hit:SetFrameLevel(row:GetFrameLevel() + 8)
		end

		y = y + h
		if tree[i + 1] then
			y = y + (GF.NAV_L0_ROW_SPACING or 0)
		end
	end
	for j = #tree + 1, L0_POOL do
		local row = self.rows[j]
		if row then
			row:Hide()
			row.nodeData = nil
		end
	end
	self.content:SetHeight(math.max(y + 1, 1))
end

function NT:DeferredRefresh()
	self:Refresh()
end

function NT:Show()
	if self.content then
		self.content:Show()
	end
end

function NT:Hide()
	if GF.NavFlyout then
		GF.NavFlyout:HideAll()
	end
	if self.content then
		self.content:Hide()
	end
end

function NT:SetVisible(visible)
	if visible then
		self:Show()
	else
		self:Hide()
	end
end
