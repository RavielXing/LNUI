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

local function presenter()
	return GF.NavigationPresenter
end

local Presenter = presenter()
if Presenter and Presenter.BindNavTree then
	Presenter:BindNavTree(NavTree)
end

function NavTree.NodeCanExpand(node)
	local owner = presenter()
	return owner and owner:NodeCanExpand(node) == true or false
end

function NavTree.ShouldShowExpandArrow(node)
	local depth = node and (node.level or 0)
	return node ~= nil and node.disabled ~= true and depth >= 1 and depth <= 2
		and NavTree.NodeCanExpand(node)
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

function NavTree:EnsureState()
	local owner = presenter()
	return owner and owner:EnsureState() or nil
end

function NavTree:PrepareBranch(node)
	local owner = presenter()
	return owner and owner:PrepareBranch(node) or false
end

function NavTree:FindNodePathByActivityID(activityID)
	local owner = presenter()
	if owner then
		return owner:FindNodePathByActivityID(activityID)
	end
	return nil, nil
end

function NavTree:FindNodePathByKey(key)
	local owner = presenter()
	if owner then
		return owner:FindNodePathByKey(key)
	end
	return nil, nil
end

function NavTree:IsNodeInteractionBlocked(node, path)
	local owner = presenter()
	return owner == nil or owner:IsNodeInteractionBlocked(node, path)
end

function NavTree:GetNodeDisabledReason(node, path)
	local owner = presenter()
	return owner and owner:GetNodeDisabledReason(node, path) or nil
end

function NavTree:SetSelectedSilently(node, path)
	local owner = presenter()
	return owner and owner:SetSelectedSilently(node, path) or false
end

function NavTree:ClearActiveRoot(skipRefresh, options)
	local owner = presenter()
	return owner and owner:ClearActiveRoot(skipRefresh, options) or false
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

local function activateRoot(row, button)
	local owner = presenter()
	return owner and owner:ActivateRoot(row, button) or false
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
	local owner = presenter()
	if owner then
		owner:BindNavTree(self)
		owner:Reset()
	end
	self.contentWidth = requestedNavWidth(GF.GetNavWidth())

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
	local owner = presenter()
	return owner and owner:IsInteractionEnabled() or false
end

function NavTree:SetInteractionEnabled(enabled)
	local owner = presenter()
	return owner and owner:SetInteractionEnabled(enabled) or false
end

function NavTree:RenderInteractionEnabled(enabled)
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
	local owner = presenter()
	return owner and owner:ToggleExpand(key, skipRefresh) or false
end

function NavTree:SetSelected(node, skipRefresh, options)
	local owner = presenter()
	return owner and owner:SetSelected(node, skipRefresh, options) or false
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
	local owner = presenter()
	local roots = owner and owner:GetVisibleRoots() or {}
	local expanded = owner and owner:GetExpanded() or {}
	local activeRootKey = owner and owner:GetActiveRootKey() or nil
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
			selected = activeRootKey == node.key
				or (node.quickSearchRoot
					and invoke(GF.NavFlyout, "IsNodeOpen", node) == true),
			canExpand = false,
			expanded = expanded[node.key] == true,
			leadingIconAtlas = node.quickSearchRoot
				and GF.NAV_QUICK_SEARCH_ICON_ATLAS or nil,
			leadingIconTexture = node.quickSearchRoot
				and GF.NAV_QUICK_SEARCH_ICON_TEXTURE or nil,
			leadingIconSize = GF.NAV_QUICK_SEARCH_ICON_SIZE,
			leadingIconGap = GF.NAV_QUICK_SEARCH_ICON_GAP,
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
	local owner = presenter()
	if owner then
		owner:HideAll()
	end
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
