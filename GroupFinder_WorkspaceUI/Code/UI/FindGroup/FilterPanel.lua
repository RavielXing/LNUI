local _, GF = ...
GF = GF.GF or GF

GF.FilterPanel = {}

local FP = GF.FilterPanel
local ControlsPresenter = assert(GF.BrowseControlsPresenter,
	"BrowseControlsPresenter must load before FilterPanel")
local PANEL_W = GF.FILTER_PANEL_W or GF.SIDE_PANEL_W or 260
local CHECKBOX_ROW_H = 30
local FILTER_CHECK_SIZE = GF.FILTER_CHECK_SIZE or 20
local FILTER_CHECK_LABEL_GAP = GF.FILTER_CHECK_LABEL_GAP or 6
local FILTER_PAIR_GAP = 8
local FILTER_ROW_INSET_X = 8
local FILTER_CHECK_OFFSET_X = 4
local FILTER_CHECK_OFFSET_Y = math.floor((CHECKBOX_ROW_H - FILTER_CHECK_SIZE) / 2)
local RANGE_BOX_W = 44
local RANGE_BOX_H = GF.FILTER_NUMBER_INPUT_H or 20
local RANGE_INPUT_OFFSET_X = 86
local RANGE_DASH_INSET_X = 4
local RANGE_DASH_W = 8
local RANGE_PAIR_W = RANGE_BOX_W * 2 + RANGE_DASH_W + RANGE_DASH_INSET_X * 2
local ROLE_THRESHOLD_BUTTON_SIZE = GF.FILTER_STEP_BUTTON_SIZE or RANGE_BOX_H
local ROLE_THRESHOLD_BUTTON_GAP = GF.FILTER_STEP_BUTTON_GAP or 2
local ROLE_THRESHOLD_ARROW_W = GF.FILTER_STEP_ARROW_W or 88 / 13
local ROLE_THRESHOLD_ARROW_H = GF.FILTER_STEP_ARROW_H or 11
local ROLE_THRESHOLD_ARROW_CENTER_OFFSET_X =
	GF.FILTER_STEP_ARROW_CENTER_OFFSET_X or 1
local FILTER_ROW_W = PANEL_W - 32
local SECTION_TOP_GAP = 6
local SECTION_TITLE_H = 16
local SECTION_BOTTOM_GAP = 3
local FILTER_SCROLL_STYLE = GF.FILTER_SCROLL_STYLE or {
	contentEdgePadding = 8, contentTopPadding = 15,
	edgeFade = 24, insetX = 4, headerBottomEdge = 76 / 150,
}
local FILTER_CONTENT_EDGE_PADDING = FILTER_SCROLL_STYLE.contentEdgePadding
local FILTER_CONTENT_TOP_PADDING = FILTER_SCROLL_STYLE.contentTopPadding
local FILTER_TOOLTIP_MIN_W = 240
local FILTER_OPTION_TEXT_SIZE = GF.FILTER_OPTION_TEXT_SIZE or 12
local FILTER_SECTION_TITLE_TEXT_SIZE = 13
local FILTER_SECTION_ACTION_BUTTON_W = GF.PANEL_BUTTON_STANDARD_W or 72
local FILTER_SECTION_ACTION_BUTTON_H = GF.PANEL_BUTTON_H or 22
local FILTER_SECTION_ACTION_BUTTON_OFFSET_Y = (FILTER_SECTION_ACTION_BUTTON_H - SECTION_TITLE_H) / 2
local FILTER_COMPACT_HEADER_DROPDOWN_H = 24
local attachTip

local function emptyFilterMenu() end
local function emptyFilterSelection() return "" end

-- Native regions survive Hide(). Reuse fixed parent/child slots by control
-- type, rather than leaving a new frame tree behind on every forced rebuild.
local function acquireFilterControl(parent, kind, create)
	local root = parent._gfFilterPoolRoot or parent
	if not root._gfFilterPoolActive then return create() end
	local pools = parent._gfFilterPools
	if not pools then
		pools = {}
		parent._gfFilterPools = pools
		root._gfFilterPoolParents = root._gfFilterPoolParents or {}
		table.insert(root._gfFilterPoolParents, parent)
	end
	local pool = pools[kind]
	if not pool then
		pool = { used = 0 }
		pools[kind] = pool
	end
	pool.used = pool.used + 1
	local widget = pool[pool.used]
	if not widget then
		widget = create()
		widget._gfFilterPoolRoot = root
		pool[pool.used] = widget
		root._gfFilterPoolWidgets = root._gfFilterPoolWidgets or {}
		table.insert(root._gfFilterPoolWidgets, widget)
	end
	if widget.ClearAllPoints then widget:ClearAllPoints() end
	if widget.SetEnabled then widget:SetEnabled(true) end
	if widget.Show then widget:Show() end
	return widget
end

local function acquireFilterFontString(parent, template)
	local fs = acquireFilterControl(parent, "font:" .. template, function()
		return GF.UI.CreateFontString(parent, "OVERLAY", template)
	end)
	if fs.SetWidth then fs:SetWidth(0) end
	if fs.SetHeight then fs:SetHeight(0) end
	if GF.Font and GF.Font.Track then GF.Font.Track(fs, template) end
	return fs
end

local function resetFilterControls(content)
	for _, parent in ipairs(content._gfFilterPoolParents or {}) do
		for _, pool in pairs(parent._gfFilterPools) do pool.used = 0 end
	end
	for _, widget in ipairs(content._gfFilterPoolWidgets or {}) do
		if widget.SetScript then
			if widget._gfFilterClickable then widget:SetScript("OnClick", nil) end
			if widget._gfFilterInputStyled then
				widget:SetScript("OnEnterPressed", nil)
				widget:SetScript("OnEditFocusLost", nil)
				widget:ClearFocus()
			end
		end
		widget._gfFilterTip = nil
		widget._gfRefreshDynamicTip = nil
		widget._gfDynamicTipActive = nil
		if widget.Hide then widget:Hide() end
		if widget._gfFilterDropdown then
			if widget._gfFilterMultiDropdown and widget.SetSelectionText then
				widget:SetSelectionText(emptyFilterSelection)
			end
			if widget.ClearMenuState then
				widget:ClearMenuState()
			else
				if widget.CloseMenu then widget:CloseMenu() end
				if widget.SetupMenu then widget:SetupMenu(emptyFilterMenu) end
				-- Hidden SetupMenu defers replacing the old description.
				if widget.GenerateMenu then widget:GenerateMenu() end
			end
		end
	end
end

local function acquireFilterDropdown(parent, kind, create)
	local dropdown = acquireFilterControl(parent, kind, create)
	dropdown._gfFilterDropdown = true
	if GF.Font and GF.Font.ApplyToDropdownButton then
		GF.Font.ApplyToDropdownButton(dropdown)
	end
	return dropdown
end

local function hideRegion(region)
	if not region then
		return
	end
	if region.Hide then
		region:Hide()
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
end

local function isFilterEnabled(v)
	return v == true or v == 1
end

local function replaceTableContents(target, source)
	target = target or {}
	for key in pairs(target) do
		target[key] = nil
	end
	for key, value in pairs(source or {}) do
		target[key] = value
	end
	return target
end

local function toFilterBool(checked)
	return isFilterEnabled(checked) and true or false
end

local function getRightColumnControlOffsetX()
	local cellW = math.floor((FILTER_ROW_W - FILTER_PAIR_GAP) / 2)
	return cellW + FILTER_PAIR_GAP + FILTER_CHECK_OFFSET_X
end

local function getSingleValueLabelWidth()
	return math.max(1, getRightColumnControlOffsetX() - FILTER_CHECK_OFFSET_X - FILTER_CHECK_SIZE - FILTER_CHECK_LABEL_GAP - 4)
end

local function applyFilterTextStyle(fs)
	if not fs then
		return
	end
	local c = GF.FILTER_TEXT_COLOR or GF.SUBTITLE_OPTION_TEXT_COLOR
	if c then
		fs:SetTextColor(c[1] or 1, c[2] or 0.82, c[3] or 0, c[4] or 1)
	end
end

local function applyFilterTextSize(fs, size, template)
	if not fs or not size then
		return
	end
	fs._gfFontSizeOverride = size
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fs, template or fs._gfFontTemplate or "GameFontNormal")
	end
end

local function applyFilterOptionTextStyle(fs, checked, enabled)
	if not fs then
		return
	end
	if enabled == false then
		fs:SetTextColor(0.48, 0.42, 0.28, 1)
	elseif checked then
		applyFilterTextStyle(fs)
	else
		fs:SetTextColor(1, 1, 1, 1)
	end
end

local function styleFilterOptionRow(row, cb, tipKey, title)
	attachTip(row, tipKey, title)
	if not row or row._gfFilterRowStyled then
		return
	end
	local hoverRevision = 0
	local function hasMouseMotionFocus(frame)
		return frame
			and frame.IsMouseMotionFocus
			and frame:IsMouseMotionFocus() == true
	end
	local function refreshCheckHover()
		local enabled = cb
			and (not cb.IsEnabled or cb:IsEnabled())
		local hovered = enabled
			and (hasMouseMotionFocus(row) or hasMouseMotionFocus(cb))
		GF.UI.SetFilterCheckButtonHovered(cb, hovered)
	end
	local function refreshCheckHoverNow()
		hoverRevision = hoverRevision + 1
		refreshCheckHover()
	end
	local function refreshCheckHoverDeferred()
		-- Parent/child focus transitions emit paired leave/enter callbacks.
		-- Recheck after the transition so the last frame keeps ownership.
		hoverRevision = hoverRevision + 1
		local revision = hoverRevision
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if revision == hoverRevision then
					refreshCheckHover()
				end
			end)
		else
			refreshCheckHover()
		end
	end
	local function clearCheckHover()
		hoverRevision = hoverRevision + 1
		GF.UI.SetFilterCheckButtonHovered(cb, false)
	end
	row:EnableMouse(true)
	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and cb and cb.Click and (not cb.IsEnabled or cb:IsEnabled()) then
			cb:Click()
		end
	end)
	row:HookScript("OnEnter", refreshCheckHoverNow)
	row:HookScript("OnLeave", refreshCheckHoverDeferred)
	row:HookScript("OnShow", refreshCheckHoverDeferred)
	row:HookScript("OnHide", clearCheckHover)
	if cb then
		cb:HookScript("OnEnter", refreshCheckHoverNow)
		cb:HookScript("OnLeave", refreshCheckHoverDeferred)
		cb:HookScript("OnShow", refreshCheckHoverDeferred)
		cb:HookScript("OnEnable", refreshCheckHoverNow)
		cb:HookScript("OnDisable", clearCheckHover)
	end
	row._gfFilterRowStyled = true
end

local function hideInputBoxChrome(editBox)
	if not editBox then
		return
	end
	local name = editBox.GetName and editBox:GetName()
	if name then
		for _, region in ipairs({
			_G[name .. "Left"],
			_G[name .. "Middle"],
			_G[name .. "Right"],
			_G[name .. "LeftTexture"],
			_G[name .. "MiddleTexture"],
			_G[name .. "RightTexture"],
		}) do
			hideRegion(region)
		end
	end
	hideRegion(editBox.Left)
	hideRegion(editBox.Middle)
	hideRegion(editBox.Right)
	hideRegion(editBox.LeftTexture)
	hideRegion(editBox.MiddleTexture)
	hideRegion(editBox.RightTexture)
end

local function updateFilterNumberBox(box)
	if not box or not box._gfFilterInputStyled then
		return
	end
	local active = box:HasFocus() or box._gfFilterInputHovered
	GF.UI.ApplyFilterInputChrome(box, active and "hover" or "normal")
end

local activeFilterNumberBox
local filterNumberBoxes = setmetatable({}, { __mode = "k" })

local function clearFilterNumberSelection(box)
	if not box then
		return
	end
	if box.HighlightText then
		box:HighlightText(0, 0)
	end
	if box.SetCursorPosition then
		local text = box.GetText and box:GetText() or ""
		box:SetCursorPosition(#(text or ""))
	end
end

local function selectAllFilterNumberText(box)
	if not box then
		return
	end
	if box.HighlightText then
		box:HighlightText()
	end
end

local function clearOtherFilterNumberFocus(box)
	for other in pairs(filterNumberBoxes) do
		if other ~= box then
			if other.ClearFocus and (not other.HasFocus or other:HasFocus()) then
				other:ClearFocus()
			end
			clearFilterNumberSelection(other)
			updateFilterNumberBox(other)
		end
	end
end

local function scheduleFilterNumberSelectAll(box)
	if not C_Timer or not C_Timer.After then
		selectAllFilterNumberText(box)
		return
	end
	C_Timer.After(0, function()
		if box and box.HasFocus and box:HasFocus() then
			selectAllFilterNumberText(box)
			updateFilterNumberBox(box)
		end
	end)
end

local function activateFilterNumberBox(box)
	if not box then
		return
	end
	clearOtherFilterNumberFocus(box)
	activeFilterNumberBox = box
	selectAllFilterNumberText(box)
	updateFilterNumberBox(box)
	scheduleFilterNumberSelectAll(box)
end

local function deactivateFilterNumberBox(box)
	if activeFilterNumberBox == box then
		activeFilterNumberBox = nil
	end
	clearFilterNumberSelection(box)
	updateFilterNumberBox(box)
end

local function setFilterNumberHovered(box, hovered)
	if not box then
		return
	end
	box._gfFilterInputHovered = hovered
	updateFilterNumberBox(box)
end

local function setFilterDropdownLabel(dd, label)
	if not dd then
		return
	end
	if dd.SetDefaultText then
		dd:SetDefaultText(label)
	end
	for _, key in ipairs({ "Text", "Label", "SelectionText", "SelectedValueText", "text" }) do
		local fs = dd[key]
		if fs and fs.SetText then
			fs:SetText(label)
		end
	end
end

local function styleFilterNumberBox(box)
	if not box then
		return box
	end
	box:SetSize(RANGE_BOX_W, RANGE_BOX_H)
	box:SetJustifyH("CENTER")
	if box.SetTextInsets then
		box:SetTextInsets(2, 2, 0, 0)
	end
	box:SetTextColor(1, 0.92, 0.64, 1)
	box:SetShadowColor(0, 0, 0, 0.85)
	box:SetShadowOffset(1, -1)
	hideInputBoxChrome(box)
	if not box._gfFilterInputStyled then
		filterNumberBoxes[box] = true

		box:HookScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				activateFilterNumberBox(self)
			end
		end)
		box:HookScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then
				selectAllFilterNumberText(self)
				updateFilterNumberBox(self)
				scheduleFilterNumberSelectAll(self)
			end
		end)
		box:HookScript("OnEditFocusGained", activateFilterNumberBox)
		box:HookScript("OnEditFocusLost", deactivateFilterNumberBox)
		box:HookScript("OnShow", updateFilterNumberBox)
		box:HookScript("OnHide", deactivateFilterNumberBox)
		box:HookScript("OnEnter", function(self)
			setFilterNumberHovered(self, true)
		end)
		box:HookScript("OnLeave", function(self)
			setFilterNumberHovered(self, false)
		end)
		box._gfFilterInputStyled = true
	end
	updateFilterNumberBox(box)
	return box
end

local function addSectionTitle(parent, text, y, action)
	local fs = acquireFilterFontString(parent, "GameFontNormal")
	local titleY = y == -FILTER_CONTENT_TOP_PADDING and y or y - SECTION_TOP_GAP
	fs:SetDrawLayer("OVERLAY", 2)
	fs:SetJustifyH("LEFT")
	fs:SetMaxLines(1)
	fs:SetWordWrap(false)
	fs:SetText(text)
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, titleY)
	applyFilterTextSize(fs, FILTER_SECTION_TITLE_TEXT_SIZE, "GameFontNormal")
	applyFilterTextStyle(fs)
	local hasAction = action and action.text and type(action.onClick) == "function"
	if hasAction then
		local button = acquireFilterControl(parent, "sectionAction", function()
			return GF.UI.CreatePanelButton(parent, action.text, FILTER_SECTION_ACTION_BUTTON_W)
		end)
		button._gfFilterClickable = true
		button:SetText(action.text)
		if GF.Font and GF.Font.TrackButton then GF.Font.TrackButton(button, "GameFontNormal") end
		button:SetSize(FILTER_SECTION_ACTION_BUTTON_W, FILTER_SECTION_ACTION_BUTTON_H)
		button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, titleY + FILTER_SECTION_ACTION_BUTTON_OFFSET_Y)
		button:SetScript("OnClick", action.onClick)
		fs:SetPoint("RIGHT", button, "LEFT", -6, 0)
		if action.tipKey then
			attachTip(button, action.tipKey, action.text, "aboveRight")
		end
	end
	return titleY - SECTION_TITLE_H - SECTION_BOTTOM_GAP
		- (hasAction and FILTER_SECTION_ACTION_BUTTON_OFFSET_Y or 0)
end

local function beginFilterTooltip(owner, placement)
	local above = placement == "aboveRight" or placement == "aboveLeft"
	if above and GF.UI.BeginGameTooltipAbove then
		local side = placement == "aboveRight" and "RIGHT" or "LEFT"
		GF.UI.BeginGameTooltipAbove(owner, side)
	else
		GF.UI.BeginGameTooltip(owner, "ANCHOR_LEFT")
	end
end

local function addFilterTooltipLines(tip)
	for line in string.gmatch(tip .. "\n", "([^\n]*)\n") do
		GameTooltip:AddLine(line == "" and " " or line, 1, 1, 1, line ~= "")
	end
end

local function showFilterTip(owner, title, tip, placement)
	if not (owner and tip and tip ~= "" and GameTooltip) then
		return
	end
	beginFilterTooltip(owner, placement)
	if GameTooltip.SetMinimumWidth then
		GameTooltip:SetMinimumWidth(FILTER_TOOLTIP_MIN_W)
	end
	local goldR = GF.UI.TOOLTIP_GOLD_R or 1
	local goldG = GF.UI.TOOLTIP_GOLD_G or 0.82
	local goldB = GF.UI.TOOLTIP_GOLD_B or 0
	local hasTitle = title and title ~= ""
	if hasTitle then
		GameTooltip:SetText(title, goldR, goldG, goldB, 1, true)
	else
		GameTooltip:SetText(tip, goldR, goldG, goldB, 1, true)
	end
	if hasTitle then
		addFilterTooltipLines(tip)
	end
	GF.UI.ShowGameTooltip()
end

local function hideFilterTip()
	if not GameTooltip then
		return
	end
	if GameTooltip.SetMinimumWidth then
		GameTooltip:SetMinimumWidth(0, false)
	end
	GameTooltip:Hide()
end

function attachTip(widget, tipKey, title, placement)
	if not widget then
		return
	end
	widget._gfFilterTip = tipKey and { key = tipKey, title = title, placement = placement } or nil
	if widget._gfFilterTipHooked or not (tipKey and GameTooltip) then return end
	widget:HookScript("OnEnter", function(self)
		local tip = self._gfFilterTip
		local text = tip and (GF.L or {})[tip.key]
		if type(text) == "string" and text ~= "" then
			showFilterTip(self, tip.title, text, tip.placement)
		end
	end)
	widget:HookScript("OnLeave", hideFilterTip)
	widget._gfFilterTipHooked = true
end

local function refreshDynamicFilterTip(self)
	if self._gfRefreshDynamicTip then self:_gfRefreshDynamicTip() end
end

local function attachDynamicTip(widget, titleFn, tipFn, placement)
	if not widget or not tipFn or not GameTooltip then
		return
	end
	widget._gfFilterTip = nil
	widget._gfRefreshDynamicTip = function(self)
		local title = (type(titleFn) == "function") and titleFn() or titleFn
		local tip = (type(tipFn) == "function") and tipFn() or tipFn
		if tip and tip ~= "" then
			showFilterTip(self, title, tip, placement)
		end
	end
	if widget._gfDynamicTipHooked then return end
	widget:HookScript("OnEnter", function(self)
		if self._gfRefreshDynamicTip then
			self._gfDynamicTipActive = true
			refreshDynamicFilterTip(self)
		end
	end)
	widget:HookScript("OnLeave", function(self)
		self._gfDynamicTipActive = nil
		hideFilterTip()
	end)
	widget._gfDynamicTipHooked = true
end

local function updateFilterCheckButton(cb)
	if GF.UI and GF.UI.UpdateFilterCheckButton then
		GF.UI.UpdateFilterCheckButton(cb)
	end
end

local function createFilterRow(parent, y, width, kind)
	local row = acquireFilterControl(parent, kind or "checkboxRow", function()
		return CreateFrame("Frame", nil, parent)
	end)
	row:SetHeight(CHECKBOX_ROW_H)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	if width then
		row:SetWidth(width)
	else
		row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -FILTER_ROW_INSET_X, y)
	end
	return row
end

local function setOptionLabelText(labelWidget, text, maxWidth)
	if maxWidth and GF.UI and GF.UI.SetEllipsisText then
		GF.UI.SetEllipsisText(labelWidget, text, math.max(1, maxWidth))
	else
		labelWidget:SetText(text)
	end
end

local function createCheckCell(container, labelText, maxLabelWidth)
	local cb = acquireFilterControl(container, "check", function()
		return GF.UI.CreateFilterCheckButton(container)
	end)
	cb._gfFilterClickable = true
	cb:SetPoint("TOPLEFT", container, "TOPLEFT", FILTER_CHECK_OFFSET_X, -FILTER_CHECK_OFFSET_Y)
	local label = acquireFilterFontString(container, "GameFontHighlightSmall")
	label:SetPoint("LEFT", cb, "RIGHT", FILTER_CHECK_LABEL_GAP, 0)
	label:SetJustifyH("LEFT")
	label:SetMaxLines(1)
	label:SetWordWrap(false)
	setOptionLabelText(label, labelText, maxLabelWidth)
	return cb, label
end

local function registerCheckSync(parent, cb, getter)
	local sync = parent and parent._gfSync
	if sync then
		table.insert(sync.checks, { cb = cb, getter = getter })
	end
end

local function styleCheckCell(parent, hitTarget, cb, label, labelText, tipKey, getter)
	local checked = isFilterEnabled(getter())
	cb:SetChecked(checked)
	applyFilterOptionTextStyle(label, checked, not cb.IsEnabled or cb:IsEnabled())
	styleFilterOptionRow(hitTarget, cb, tipKey, labelText)
	GF.UI.StyleFilterCheckButton(cb, { label = label, updateLabel = applyFilterOptionTextStyle })
	attachTip(cb, tipKey, labelText)
	registerCheckSync(parent, cb, getter)
end

local function addCheckbox(parent, label, y, getter, setter, tipKey)
	local row = createFilterRow(parent, y)
	local cb, fs = createCheckCell(row, label)
	fs:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	cb:SetScript("OnClick", function(self)
		local enabled = toFilterBool(self:GetChecked())
		setter(enabled)
		updateFilterCheckButton(self)
	end)
	styleCheckCell(parent, row, cb, fs, label, tipKey, getter)
	return y - CHECKBOX_ROW_H
end

local function addCheckboxPair(parent, y, leftLabel, leftGetter, leftSetter, leftTipKey, rightLabel, rightGetter, rightSetter, rightTipKey)
	local row = createFilterRow(parent, y, nil, "checkboxPairRow")
	local cellW = math.floor((FILTER_ROW_W - FILTER_PAIR_GAP) / 2)
	local definitions = {
		{ leftLabel, leftGetter, leftSetter, leftTipKey },
		{ rightLabel, rightGetter, rightSetter, rightTipKey },
	}
	for index, definition in ipairs(definitions) do
		local label = definition[1]
		local getter, setter, tipKey = definition[2], definition[3], definition[4]
		local cell = acquireFilterControl(row, "cell", function()
			return CreateFrame("Frame", nil, row)
		end)
		cell:SetHeight(CHECKBOX_ROW_H)
		if index == 1 then
			cell:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
			cell:SetPoint("RIGHT", row, "CENTER", -FILTER_PAIR_GAP / 2, 0)
		else
			cell:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
			cell:SetPoint("LEFT", row, "CENTER", FILTER_PAIR_GAP / 2, 0)
		end
		local maxTextWidth = cellW - FILTER_CHECK_OFFSET_X - FILTER_CHECK_SIZE - FILTER_CHECK_LABEL_GAP
		local cb, fs = createCheckCell(cell, label, maxTextWidth)
		fs:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
		cb:SetScript("OnClick", function(self)
			setter(toFilterBool(self:GetChecked()))
			updateFilterCheckButton(self)
		end)
		styleCheckCell(parent, cell, cb, fs, label, tipKey, getter)
	end
	return y - CHECKBOX_ROW_H
end

local function addExclusiveClientCheckboxPair(parent, y, client, leftKey, rightKey, leftLabel, rightLabel, leftTipKey, rightTipKey, onSave)
	if client[leftKey] and client[rightKey] then
		client[rightKey] = false
	end
	local row = createFilterRow(parent, y, nil, "exclusivePairRow")
	local cellW = math.floor((FILTER_ROW_W - FILTER_PAIR_GAP) / 2)
	local entries = {}
	local definitions = {
		{ key = leftKey, peer = rightKey, label = leftLabel, tip = leftTipKey },
		{ key = rightKey, peer = leftKey, label = rightLabel, tip = rightTipKey },
	}
	for index, definition in ipairs(definitions) do
		local cell = acquireFilterControl(row, "cell", function()
			return CreateFrame("Frame", nil, row)
		end)
		cell:SetHeight(CHECKBOX_ROW_H)
		if index == 1 then
			cell:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
			cell:SetPoint("RIGHT", row, "CENTER", -FILTER_PAIR_GAP / 2, 0)
		else
			cell:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
			cell:SetPoint("LEFT", row, "CENTER", FILTER_PAIR_GAP / 2, 0)
		end
		local maxTextWidth = cellW - FILTER_CHECK_OFFSET_X - FILTER_CHECK_SIZE - FILTER_CHECK_LABEL_GAP
		local cb, fs = createCheckCell(cell, definition.label, maxTextWidth)
		fs:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
		local key, peerKey = definition.key, definition.peer
		local function getter()
			return client[key]
		end
		entries[index] = cb
		cb:SetScript("OnClick", function(self)
			local checked = toFilterBool(self:GetChecked())
			client[key] = checked
			if checked then
				client[peerKey] = false
				local otherButton = entries[index == 1 and 2 or 1]
				if otherButton then
					otherButton:SetChecked(false)
				end
			end
			if onSave then
				onSave()
			end
			updateFilterCheckButton(self)
		end)
		styleCheckCell(parent, cell, cb, fs, definition.label, definition.tip, getter)
	end
	return y - CHECKBOX_ROW_H
end

local function createNumberInput(parent, value, maxLetters)
	local box = acquireFilterControl(parent, "numberInput", function()
		return CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	end)
	box:SetSize(RANGE_BOX_W, RANGE_BOX_H)
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(maxLetters or 4)
	box:SetText(tostring(value or 0))
	GF.UI.TrackEditBox(box, "GameFontHighlightSmall")
	styleFilterNumberBox(box)
	return box
end

local function bindNumberCommit(box, commit)
	box:SetScript("OnEnterPressed", function(self)
		commit()
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", commit)
end

local function registerRangeSync(parent, definition)
	local sync = parent and parent._gfSync
	if sync then
		table.insert(sync.ranges, definition)
	end
end

local function addRangeRow(parent, label, y, client, enKey, minKey, maxKey, tipKey, onSave)
	local row = createFilterRow(parent, y, nil, "rangeRow")
	local labelWidth = RANGE_INPUT_OFFSET_X - FILTER_CHECK_LABEL_GAP - 4
	local cb, fs = createCheckCell(row, label, labelWidth)
	fs:SetWidth(labelWidth)
	local function enabledGetter()
		return client[enKey]
	end
	local minBox = createNumberInput(row, client[minKey], 4)
	minBox:SetPoint("RIGHT", row, "RIGHT", -4 - RANGE_BOX_W - RANGE_DASH_W - 2 * RANGE_DASH_INSET_X, 0)
	attachTip(minBox, tipKey, label)
	local dash = acquireFilterFontString(row, "GameFontHighlightSmall")
	dash:SetPoint("LEFT", minBox, "RIGHT", RANGE_DASH_INSET_X, 0)
	dash:SetWidth(RANGE_DASH_W)
	dash:SetJustifyH("CENTER")
	dash:SetText("-")
	applyFilterTextStyle(dash)
	local maxBox = createNumberInput(row, client[maxKey], 4)
	maxBox:SetPoint("LEFT", dash, "RIGHT", RANGE_DASH_INSET_X, 0)
	attachTip(maxBox, tipKey, label)
	local function commit()
		local enabled = toFilterBool(cb:GetChecked())
		local minimum = tonumber(minBox:GetText()) or 0
		local maximum = tonumber(maxBox:GetText()) or 0
		client[enKey], client[minKey], client[maxKey] = enabled, minimum, maximum
		if onSave then
			onSave()
		end
		updateFilterCheckButton(cb)
	end
	cb:SetScript("OnClick", commit)
	bindNumberCommit(minBox, commit)
	bindNumberCommit(maxBox, commit)
	styleCheckCell(parent, row, cb, fs, label, tipKey, enabledGetter)
	local rangeSync = {}
	rangeSync.cb, rangeSync.client = cb, client
	rangeSync.minBox, rangeSync.maxBox = minBox, maxBox
	rangeSync.enKey, rangeSync.minKey, rangeSync.maxKey = enKey, minKey, maxKey
	registerRangeSync(parent, rangeSync)
	return y - CHECKBOX_ROW_H
end

local function normalizeRoleThreshold(value)
	local minValue = GF.ROLE_VACANCY_THRESHOLD_MIN or 1
	local maxValue = GF.ROLE_VACANCY_THRESHOLD_MAX or 4
	value = math.floor((tonumber(value) or minValue) + 0.0001)
	if value < minValue then
		value = minValue
	elseif value > maxValue then
		value = maxValue
	end
	return value
end

local function updateRoleThresholdStepButtons(decrementBtn, incrementBtn, threshold)
	local minValue = GF.ROLE_VACANCY_THRESHOLD_MIN or 1
	local maxValue = GF.ROLE_VACANCY_THRESHOLD_MAX or 4
	local value = normalizeRoleThreshold(threshold)
	local states = {
		{ decrementBtn, value > minValue },
		{ incrementBtn, value < maxValue },
	}
	for _, state in ipairs(states) do
		if state[1] then
			state[1]:SetEnabled(state[2])
		end
	end
end

local function createRoleThresholdStepButton(parent, direction)
	local button = acquireFilterControl(parent, "step:" .. direction, function()
		return GF.UI.CreateFilterStepButton(parent, direction, {
			size = ROLE_THRESHOLD_BUTTON_SIZE or RANGE_BOX_H,
			arrowWidth = ROLE_THRESHOLD_ARROW_W,
			arrowHeight = ROLE_THRESHOLD_ARROW_H,
			arrowCenterOffsetX = ROLE_THRESHOLD_ARROW_CENTER_OFFSET_X,
		})
	end)
	button._gfFilterClickable = true
	return button
end

local function addRoleThresholdRow(parent, label, y, client, enKey, minKey, maxKey, tipKey, onSave)
	local row = createFilterRow(parent, y, nil, "roleThresholdRow")
	local rangeLabelW = getSingleValueLabelWidth()
	local cb, fs = createCheckCell(row, label, rangeLabelW)
	fs:SetWidth(rangeLabelW)
	local function enabledGetter()
		return client[enKey]
	end
	local decrementBtn = createRoleThresholdStepButton(row, "left")
	local thresholdBox = createNumberInput(row, normalizeRoleThreshold(client[minKey]), 1)
	-- Center the whole stepper on the range inputs used by the team conditions.
	thresholdBox:SetPoint("CENTER", row, "RIGHT", -4 - RANGE_PAIR_W / 2, 0)
	decrementBtn:SetPoint("RIGHT", thresholdBox, "LEFT", -ROLE_THRESHOLD_BUTTON_GAP, 0)
	local incrementBtn = createRoleThresholdStepButton(row, "right")
	incrementBtn:SetPoint("LEFT", thresholdBox, "RIGHT", ROLE_THRESHOLD_BUTTON_GAP, 0)
	local tipWidgets = {}
	local function roleTip()
		local L = GF.L or {}
		local template = L[tipKey]
		if not template or template == "" then
			return nil
		end
		local value = normalizeRoleThreshold(thresholdBox:GetText())
		local coloredValue = string.format("|cff00ff00%d|r", value)
		local ok, text = pcall(string.format, template, coloredValue)
		return ok and text or template
	end
	local function refreshActiveRoleTips()
		for _, widget in ipairs(tipWidgets) do
			if widget and widget._gfDynamicTipActive and widget._gfRefreshDynamicTip then
				widget:_gfRefreshDynamicTip()
			end
		end
	end
	local function setThreshold(value, save)
		local threshold = normalizeRoleThreshold(value)
		thresholdBox:SetText(tostring(threshold))
		client[enKey] = toFilterBool(cb:GetChecked())
		client[minKey] = threshold
		if maxKey then
			client[maxKey] = 0
		end
		if save and onSave then
			onSave()
		end
		updateFilterCheckButton(cb)
		updateRoleThresholdStepButtons(decrementBtn, incrementBtn, threshold)
		refreshActiveRoleTips()
	end
	local function commit()
		setThreshold(thresholdBox:GetText(), true)
	end
	cb:SetScript("OnClick", commit)
	decrementBtn:SetScript("OnClick", function()
		local current = tonumber(thresholdBox:GetText()) or normalizeRoleThreshold(client[minKey])
		setThreshold(current - 1, true)
	end)
	incrementBtn:SetScript("OnClick", function()
		local current = tonumber(thresholdBox:GetText()) or normalizeRoleThreshold(client[minKey])
		setThreshold(current + 1, true)
	end)
	bindNumberCommit(thresholdBox, commit)
	styleCheckCell(parent, row, cb, fs, label, nil, enabledGetter)
	attachDynamicTip(row, label, roleTip)
	attachDynamicTip(thresholdBox, label, roleTip)
	attachDynamicTip(cb, label, roleTip)
	attachDynamicTip(decrementBtn, label, roleTip)
	attachDynamicTip(incrementBtn, label, roleTip)
	tipWidgets = { row, thresholdBox, cb, decrementBtn, incrementBtn }
	if not thresholdBox._gfDynamicTipTextHooked then
		thresholdBox:HookScript("OnTextChanged", function(self)
			if self._gfDynamicTipActive then refreshDynamicFilterTip(self) end
		end)
		thresholdBox._gfDynamicTipTextHooked = true
	end
	updateRoleThresholdStepButtons(decrementBtn, incrementBtn, normalizeRoleThreshold(client[minKey]))
	local rangeSync = {
		cb = cb, minBox = thresholdBox, client = client,
		enKey = enKey, minKey = minKey, maxKey = maxKey,
		decrementBtn = decrementBtn, incrementBtn = incrementBtn, roleThreshold = true,
	}
	registerRangeSync(parent, rangeSync)
	return y - CHECKBOX_ROW_H
end

local DIFF_LABELS, RAID_DIFF_LABELS =
	{ "FILTER_DIFF_NORMAL", "FILTER_DIFF_HEROIC", "FILTER_DIFF_MYTHIC", "FILTER_DIFF_MPLUS" },
	{ "FILTER_DIFF_NORMAL", "FILTER_DIFF_HEROIC", "FILTER_DIFF_MYTHIC" }
local ROLE_FILTER_MODES = { "all", "any" }
local BLOODLUST_LABELS = {
	[0] = "FILTER_BLOODLUST_NONE",
	[1] = "FILTER_BLOODLUST_BLFIT",
	[2] = "FILTER_BLOODLUST_NEEDSBL",
}
local ROLE_FILTER_MODE_LABELS = {
	all = "FILTER_ROLE_MODE_ALL",
	any = "FILTER_ROLE_MODE_ANY",
}

local function normalizeRoleFilterMode(mode)
	return mode == "any" and "any" or "all"
end

local function roleFilterModeLabel(mode)
	local L = GF.L or {}
	mode = normalizeRoleFilterMode(mode)
	local key = ROLE_FILTER_MODE_LABELS[mode]
	return L[key] or key or mode
end

local function createRoleFilterModeDropdown(parent, client, onSave, tipTitle)
	local L = GF.L or {}
	local dd = acquireFilterDropdown(parent, "roleDropdown", function()
		return GF.UI.CreateDropdownButton(parent)
	end)
	dd:SetSize(104, 24)
	local function currentMode()
		return normalizeRoleFilterMode(client and client.roleFilterMode)
	end
	setFilterDropdownLabel(dd, roleFilterModeLabel(currentMode()))
	if dd.SetupMenu then
		dd:SetupMenu(function(_, root)
			for _, mode in ipairs(ROLE_FILTER_MODES) do
				local value = mode
				root:CreateRadio(roleFilterModeLabel(value), function()
					return currentMode() == value
				end, function()
					client.roleFilterMode = value
					if onSave then
						onSave()
					end
					setFilterDropdownLabel(dd, roleFilterModeLabel(value))
					FP:RebuildIfNeeded(true)
				end)
			end
		end)
	end
	attachTip(dd, "FILTER_TIP_ROLE_MODE", tipTitle or L.FILTER_ROLE_MODE or "Filter Mode")
	local sync = parent._gfSync
	if sync then
		sync.dropdowns[#sync.dropdowns + 1] = {
			dd = dd,
			labelFn = function()
				return roleFilterModeLabel(FP.client and FP.client.roleFilterMode)
			end,
		}
	end
	return dd
end

local function addCompactSectionDropdownHeader(parent, title, y, dropdown, tipKey)
	local fs = acquireFilterFontString(parent, "GameFontNormal")
	local titleY = y == -FILTER_CONTENT_TOP_PADDING and y or y - SECTION_TOP_GAP
	local dropdownTopY = titleY + (FILTER_COMPACT_HEADER_DROPDOWN_H - SECTION_TITLE_H) / 2
	if y == -FILTER_CONTENT_TOP_PADDING then dropdownTopY = y end
	fs:SetDrawLayer("OVERLAY", 2)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("MIDDLE")
	fs:SetMaxLines(1)
	fs:SetWordWrap(false)
	fs:SetText(title)
	fs:SetHeight(FILTER_COMPACT_HEADER_DROPDOWN_H)
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, dropdownTopY)
	applyFilterTextSize(fs, FILTER_SECTION_TITLE_TEXT_SIZE, "GameFontNormal")
	applyFilterTextStyle(fs)

	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, dropdownTopY)
	fs:SetPoint("TOPRIGHT", dropdown, "TOPLEFT", -6, 0)
	attachTip(fs, tipKey, title)

	-- Reserve the independent 24px dropdown height.
	-- Reserve its full height so the first option cannot overlap its lower edge.
	return dropdownTopY - FILTER_COMPACT_HEADER_DROPDOWN_H - SECTION_BOTTOM_GAP
end

local function addRoleFilterModeHeader(parent, title, y, client, onSave)
	local dropdown = createRoleFilterModeDropdown(parent, client, onSave, title)
	return addCompactSectionDropdownHeader(
		parent, title, y, dropdown, "FILTER_TIP_ROLE_MODE")
end

local function pcallFirst(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

local function activityItemKey(item)
	if type(item) == "table" then
		return item.key
	end
	if type(item) == "string" then
		return item
	end
	return item and ("g:" .. tostring(item)) or nil
end

local function activityItemLabel(item)
	if type(item) == "table" then
		return item.label or item.key or "?"
	end
	return pcallFirst(C_LFGList and C_LFGList.GetActivityGroupInfo, item) or tostring(item)
end

local function addActivityGroupCheckboxes(parent, y, title, items, isEnabled, onToggle, tipKey, titleAction)
	y = y - 6
	y = addSectionTitle(parent, title, y, titleAction)
	for _, item in ipairs(items or {}) do
		local key = activityItemKey(item)
		local name = activityItemLabel(item)
		y = addCheckbox(parent, name, y, function()
			return isEnabled(key)
		end, function(v)
			onToggle(key, v)
		end, tipKey)
	end
	return y
end

function FP:SyncFrameLevels()
	if not self.frame then
		return
	end
	local contentLevel = self.frame:GetFrameLevel() + 5
	if self.footer and self.footer.SetFrameLevel then
		self.footer:SetFrameLevel(contentLevel)
	end
	if self.scroll and self.scroll.SetFrameLevel then
		self.scroll:SetFrameLevel(contentLevel)
	end
	if self.scrollBar and self.scrollBar.SetFrameLevel then
		self.scrollBar:SetFrameLevel(contentLevel + 4)
	end
	if self.scrollBody then
		self.scroll._gfEdgeFade.viewport:SetFrameLevel(contentLevel + 1)
	end
	if self.content and self.content.SetFrameLevel then
		self.content:SetFrameLevel(contentLevel + 1)
	end
	if self.refreshBtn and self.refreshBtn.SetFrameLevel then
		self.refreshBtn:SetFrameLevel(contentLevel + 8)
	end
	if self.resetBtn and self.resetBtn.SetFrameLevel then
		self.resetBtn:SetFrameLevel(contentLevel + 8)
	end
end

function FP:IsFocusMouseDown()
	if not IsMouseButtonDown then
		return false
	end
	return IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
end

local function focusBelongsTo(root, focus)
	while root and focus do
		if focus == root then
			return true
		end
		focus = focus.GetParent and focus:GetParent()
	end
	return false
end

function FP:IsMouseOverFocusGroup()
	if GetMouseFoci then
		for _, focus in ipairs(GetMouseFoci()) do
			if focusBelongsTo(self.mainFrame, focus) or focusBelongsTo(self.frame, focus) then
				return true
			end
		end
		return false
	end
	local overMain = self.mainFrame and self.mainFrame.IsMouseOver and self.mainFrame:IsMouseOver()
	local overFilter = self.frame and self.frame.IsMouseOver and self.frame:IsMouseOver()
	return overMain or overFilter
end

function FP:OnFocusSyncUpdate()
	local mouseDown = self:IsFocusMouseDown()
	if not mouseDown then
		self._focusMouseDownActive = nil
		return
	end
	if self._focusMouseDownActive or not self:IsMouseOverFocusGroup() then
		return
	end
	self._focusMouseDownActive = true
	if GF.UI and GF.UI.RaiseMainFrameSatelliteGroup then
		GF.UI.RaiseMainFrameSatelliteGroup()
	end
end

local function createFilterPanelFrame(mainFrame, title)
	local frame = CreateFrame("Frame", "GroupFinderAddonFilterFrame", UIParent, "SettingsFrameTemplate")
	frame:SetSize(PANEL_W, mainFrame:GetHeight())
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()
	GF.UI.InstallSatelliteFrame(frame, {
		levelOffset = 0, raise = false, toplevel = true, followMainRaise = true,
	})
	GF.UI.ApplySettingsFrameChrome(frame, title)
	GF.UI.InstallBodyBackground(frame, { layout = "filter", style = "panelBackplate" })
	return frame
end

local function installFilterFooter(owner, contentLevel, footerHeight, bottomInset)
	local footer = CreateFrame("Frame", nil, owner.frame)
	local leftInset = GF.FILTER_FOOTER_INSET_L or GF.FRAME_BG_INSET_LEFT or 7
	local rightInset = GF.FILTER_FOOTER_INSET_R or GF.FRAME_BG_INSET_RIGHT or -2
	footer:SetPoint("BOTTOMLEFT", owner.frame, "BOTTOMLEFT", leftInset, bottomInset)
	footer:SetPoint("BOTTOMRIGHT", owner.frame, "BOTTOMRIGHT", rightInset, bottomInset)
	footer:SetHeight(footerHeight)
	footer:SetFrameLevel(contentLevel)
	if GF.UI.InstallBrowseControlBarChrome then
		local chromeOptions = {
			backgroundParent = footer,
			leftInset = 0,
			rightInset = 0,
			height = GF.BROWSE_CONTROL_BACKGROUND_H or GF.SUBTITLE_HEADER_H or 26,
			topOffset = GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0,
		}
		GF.UI.InstallBrowseControlBarChrome(footer, chromeOptions)
	end
	owner.footer = footer
end

local function updateFilterScrollLayout(self)
	if self._updatingScrollLayout or not self.scrollBody then return end
	self._updatingScrollLayout = true
	local scroll, body, content = self.scroll, self.scrollBody, self.content
	local width = math.max(1, scroll:GetWidth())
	body:SetSize(width, content and content:GetHeight() or 1)
	if content then content:SetWidth(width) end
	GF.UI.UpdateScrollFrame(scroll)
	if self._filterScrollBar then self._filterScrollBar.Refresh() end
	self._updatingScrollLayout = nil
end

local function installFilterScroll(owner, contentLevel)
	-- Use the visible inner stroke, not the atlas rectangle's transparent tail.
	local bounds = CreateFrame("Frame", nil, owner.frame)
	local topEdge = owner.frame.NineSlice.TopEdge
	local footerEdge = owner.footer._gfBrowseControlBackgroundFrame
	local function anchorHeaderEdge()
		bounds:SetPoint("TOP", topEdge, "TOP", 0,
			-topEdge:GetHeight() * FILTER_SCROLL_STYLE.headerBottomEdge)
	end
	anchorHeaderEdge()
	owner.frame:HookScript("OnShow", anchorHeaderEdge)
	owner.frame:HookScript("OnSizeChanged", anchorHeaderEdge)
	bounds:SetPoint("BOTTOM", footerEdge, "TOP", 0, 0)
	bounds:SetPoint("LEFT", owner.frame, "LEFT", FILTER_SCROLL_STYLE.insetX, 0)
	bounds:SetPoint("RIGHT", owner.frame, "RIGHT", -FILTER_SCROLL_STYLE.insetX, 0)
	owner.scrollBounds = bounds

	local scroll = GF.UI.CreateScrollFrame(owner.frame, { rowHeight = GF.SETTINGS_WHEEL_ROW_H })
	scroll:SetFrameLevel(contentLevel)
	scroll:SetPoint("TOPLEFT", bounds, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", 0, 0)
	-- The permanent body owns the fade; its one content child reuses controls.
	local body = CreateFrame("Frame", nil, scroll)
	body:SetSize(math.max(1, scroll:GetWidth()), 1)
	body:SetFrameLevel(contentLevel + 1)
	scroll:SetScrollChild(body)
	local bar = GF.UI.BindMinimalScrollBar(scroll, 0, owner.frame, true)
	bar:SetWidth(GF.FILTER_SCROLLBAR_WIDTH)
	bar:ClearAllPoints()
	bar:SetPoint("TOP", bounds, "TOP", 0, -GF.FILTER_SCROLLBAR_TOP_INSET)
	bar:SetPoint("BOTTOM", bounds, "BOTTOM", 0, GF.FILTER_SCROLLBAR_BOTTOM_INSET)
	bar:SetPoint("RIGHT", owner.frame, "RIGHT", -GF.FILTER_SCROLLBAR_RIGHT_INSET, 0)
	owner.scroll, owner.scrollBody, owner.scrollBar = scroll, body, bar
	local function scrollable()
		return scroll:GetHeight() > 0 and body:GetHeight() > scroll:GetHeight()
	end
	scroll._gfWheelAllow = scrollable
	GF.UI.BindSmoothWheelScrolling(scroll)
	GF.UI.BindSmoothWheelScrollBar(scroll, bar)
	GF.UI.BindScrollFrameEdgeFade(scroll, body, FILTER_SCROLL_STYLE.edgeFade)
	owner._filterScrollBar = GF.UI.BindDynamicScrollBar(scroll, bar, {
		gutter = GF.SETTINGS_SCROLLBAR_GUTTER,
		duration = GF.PLAYER_MANAGEMENT_STYLE.scrollBarDuration,
		isScrollable = scrollable,
		isScrollAllowed = scrollable,
		onInsetChanged = function(inset)
			scroll:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -inset, 0)
			updateFilterScrollLayout(owner)
		end,
	})
	scroll:HookScript("OnSizeChanged", function() updateFilterScrollLayout(owner) end)
	scroll:HookScript("OnShow", function() updateFilterScrollLayout(owner) end)
end

local function createFooterCommand(owner, definition, contentLevel, buttonWidth, centerOffset, bottomOffset)
	local button = GF.UI.CreatePanelButton(owner.footer, definition.text, buttonWidth)
	button:SetFrameLevel(contentLevel + 8)
	button:SetPoint("BOTTOM", owner.footer, "BOTTOM", definition.side * centerOffset, bottomOffset)
	button:SetScript("OnClick", function()
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		definition.callback()
	end)
	attachTip(button, definition.tipKey, definition.text, "aboveLeft")
	return button
end

function FP:Init(mainFrame)
	if self.frame ~= nil then
		return
	end
	mainFrame = mainFrame or self.mainFrame
		or (GF.MainFrame and GF.MainFrame.frame)
	if not mainFrame then
		return
	end
	self.mainFrame = mainFrame
	local L = GF.L or {}
	local frame = createFilterPanelFrame(mainFrame, L.FILTER_ADVANCED or "Filter")
	self.frame = frame
	frame._gfOnSatelliteFrameLayersApplied = function()
		FP:SyncFrameLevels()
		if GF.WorkspaceBar and GF.WorkspaceBar.RefreshAnchor then
			GF.WorkspaceBar:RefreshAnchor()
		end
	end
	frame:HookScript("OnShow", function(shownFrame)
		if GF.WorkspaceBar and GF.WorkspaceBar.AnchorToHost then
			GF.WorkspaceBar:AnchorToHost(shownFrame)
		end
	end)
	frame:HookScript("OnHide", function()
		if GF.WorkspaceBar and GF.WorkspaceBar.AnchorToHost then
			GF.WorkspaceBar:AnchorToHost(mainFrame)
		end
	end)
	frame:SetScript("OnUpdate", function()
		FP:OnFocusSyncUpdate()
	end)
	frame.ClosePanelButton:SetScript("OnClick", function()
		FP:Hide()
	end)

	local contentLevel = frame:GetFrameLevel() + 5
	local footerH = GF.FILTER_FOOTER_H or GF.SUBTITLE_H or 42
	local footerInsetB = GF.FILTER_FOOTER_INSET_B or GF.FRAME_BG_INSET_BOTTOM or 3
	installFilterFooter(self, contentLevel, footerH, footerInsetB)
	installFilterScroll(self, contentLevel)

	local buttonWidth = GF.PANEL_BUTTON_TWO_CHAR_W or 72
	local buttonGap = GF.FILTER_FOOTER_BUTTON_GAP or 10
	local centerOffset = math.floor((buttonWidth + buttonGap) * 0.5)
	local buttonY = GF.FILTER_FOOTER_BUTTON_OFFSET_Y or 13
	self.refreshBtn = createFooterCommand(self, {
		text = L.FILTER_REFRESH or "Search", tipKey = "FILTER_TIP_REFRESH", side = 1,
		callback = function() FP:OnRefresh() end,
	}, contentLevel, buttonWidth, centerOffset, buttonY)
	self.resetBtn = createFooterCommand(self, {
		text = L.FILTER_RESET or "Reset", tipKey = "FILTER_TIP_RESET", side = -1,
		callback = function() FP:OnReset() end,
	}, contentLevel, buttonWidth, centerOffset, buttonY)
	self:UpdateSearchButtonState()
	if UISpecialFrames then
		tinsert(UISpecialFrames, self.frame:GetName())
	end
	self:SyncFrameLevels()
end

function FP:GetSelection()
	return ControlsPresenter:GetFilterSelection()
end

function FP:GetSpec()
	return ControlsPresenter:ResolveFilterSpec(self:GetSelection())
end

function FP:SaveClient()
	local activeSpec = self:GetSpec()
	if not activeSpec then
		return
	end
	ControlsPresenter:SaveFilterClient(activeSpec, self.client)
end

function FP:SaveGlobal()
	ControlsPresenter:ApplyFilterRefresh()
end

local function syncRangeControl(entry)
	local client = entry.client
	if not client then
		return
	end
	if entry.cb then
		entry.cb:SetChecked(isFilterEnabled(client[entry.enKey]))
	end
	if entry.minBox then
		local minimum = client[entry.minKey]
		if entry.roleThreshold then
			minimum = normalizeRoleThreshold(minimum)
			updateRoleThresholdStepButtons(entry.decrementBtn, entry.incrementBtn, minimum)
		end
		entry.minBox:SetText(tostring(minimum or 0))
	end
	if entry.maxBox then
		entry.maxBox:SetText(tostring(client[entry.maxKey] or 0))
	end
end

function FP:SyncContentValues()
	local sync = self.content and self.content._gfSync
	if not sync then
		return
	end
	local checks = sync.checks or {}
	for index = 1, #checks do
		local entry = checks[index]
		if entry.getter and entry.cb then
			entry.cb:SetChecked(entry.getter())
		end
	end
	local ranges = sync.ranges or {}
	for index = 1, #ranges do
		syncRangeControl(ranges[index])
	end
	local dropdowns = sync.dropdowns or {}
	for index = 1, #dropdowns do
		local entry = dropdowns[index]
		if entry.syncFn then
			entry.syncFn()
		elseif entry.labelFn and entry.dd then
			local label = entry.labelFn()
			setFilterDropdownLabel(entry.dd, label)
		end
	end
	for index = 1, #(sync.statuses or {}) do
		sync.statuses[index]()
	end
end

function FP:ActivateContent(content, spec, key)
	local previous = self.content
	if previous and previous ~= content then
		previous:Hide()
	end
	local latest = ControlsPresenter:GetFilterClient(spec)
	self.client = replaceTableContents(content._gfClient, latest)
	content._gfClient = self.client
	self.content, self._specKey = content, key
	GF.UI.CancelSmoothWheelScrolling(self.scroll)
	content:Show()
	self:SyncContentValues()
	updateFilterScrollLayout(self)
end

local function registerDropdownSync(parent, dropdown, labelProvider, syncFn)
	table.insert(parent._gfSync.dropdowns, {
		dd = dropdown,
		labelFn = labelProvider,
		syncFn = syncFn,
	})
end

local function createChoiceDropdown(parent, definition, width, height)
	local dropdown = acquireFilterDropdown(parent, "choiceDropdown", function()
		return GF.UI.CreateDropdownButton(parent)
	end)
	dropdown:SetSize(width or PANEL_W - 40, height or 26)
	local function refreshLabel()
		return definition.label(definition.current())
	end
	setFilterDropdownLabel(dropdown, refreshLabel())
	registerDropdownSync(parent, dropdown, refreshLabel)
	if dropdown.SetupMenu then
		dropdown:SetupMenu(function(_, root)
			for index = 1, #definition.values do
				local value = definition.values[index]
				root:CreateRadio(definition.label(value), function()
					return definition.current() == value
				end, function()
					definition.select(value)
				end)
			end
		end)
	end
	attachTip(dropdown, definition.tipKey, definition.title)
	return dropdown
end

local function addChoiceDropdown(parent, y, definition)
	local dropdown = createChoiceDropdown(parent, definition, PANEL_W - 40, 26)
	dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -FILTER_ROW_INSET_X, y)
	return y - 32
end

local function addChoiceDropdownHeader(parent, y, definition)
	local dropdown = createChoiceDropdown(parent, definition, 104,
		FILTER_COMPACT_HEADER_DROPDOWN_H)
	return addCompactSectionDropdownHeader(
		parent, definition.title, y, dropdown, definition.tipKey)
end

local function multiSelectRefreshResponse()
	if MenuResponse then
		return MenuResponse.Refresh
	end
end

local function multiSelectSummary(definition)
	if definition.refreshState then
		definition.refreshState()
	end
	local values = definition.values or {}
	if #values == 0 then
		return definition.emptyLabel or definition.noneLabel or "-"
	end
	local selectedCount = 0
	local selectedValue
	for index = 1, #values do
		local value = values[index]
		if definition.isSelected(value) then
			selectedCount = selectedCount + 1
			selectedValue = value
		end
	end
	if selectedCount == #values then
		return definition.allLabel
	end
	if selectedCount == 0 then
		return definition.noneLabel
	end
	if selectedCount == 1 then
		return definition.label(selectedValue)
	end
	local ok, label = pcall(
		string.format, definition.selectedFormat, selectedCount)
	return ok and label or tostring(selectedCount)
end

local function setMultiSelectDropdownText(dropdown, label)
	if not dropdown then
		return
	end
	if dropdown.SetText then
		dropdown:SetText(label)
	end
	for _, key in ipairs({ "Text", "SelectionText", "SelectedValueText" }) do
		local fs = dropdown[key]
		if fs and fs.SetText then
			fs:SetText(label)
		end
	end
end

local function addMultiSelectDropdown(parent, y, definition)
	local dropdown = acquireFilterDropdown(parent, "multiDropdown", function()
		return GF.UI.CreateDropdownButton(parent)
	end)
	dropdown._gfFilterMultiDropdown = true
	dropdown:SetSize(PANEL_W - 40, 26)
	dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -FILTER_ROW_INSET_X, y)
	local function summary()
		return multiSelectSummary(definition)
	end
	local function refreshText(regenerateMenu)
		setMultiSelectDropdownText(dropdown, summary())
		dropdown:SetEnabled(#(definition.values or {}) > 0)
		if regenerateMenu and dropdown.GenerateMenu then
			dropdown:GenerateMenu()
		end
	end
	if dropdown.SetSelectionText then
		dropdown:SetSelectionText(summary)
	end
	if dropdown.SetupMenu then
		dropdown:SetupMenu(function(_, root)
			if definition.refreshState then
				definition.refreshState()
			end
			if definition.tag and root.SetTag then
				root:SetTag(definition.tag)
			end
			if root.CreateTitle then
				root:CreateTitle(definition.title)
			end
			local values = definition.values or {}
			if #values == 0 then
				return
			end
			root:CreateButton(definition.selectAllLabel, function()
				definition.setAll(true)
				refreshText(false)
				return multiSelectRefreshResponse()
			end)
			root:CreateButton(definition.clearAllLabel, function()
				definition.setAll(false)
				refreshText(false)
				return multiSelectRefreshResponse()
			end)
			for index = 1, #values do
				local value = values[index]
				root:CreateCheckbox(definition.label(value), function()
					return definition.isSelected(value)
				end, function()
					definition.setSelected(
						value, not definition.isSelected(value))
					refreshText(false)
					return multiSelectRefreshResponse()
				end)
			end
		end)
	end
	refreshText(false)
	registerDropdownSync(parent, dropdown, nil, function()
		refreshText(true)
	end)
	attachTip(dropdown, definition.tipKey, definition.title)
	return y - 32
end

local function sequentialValues(first, last)
	local values = {}
	for value = first, last do
		values[#values + 1] = value
	end
	return values
end

local function boundAccessors(target, key, save, invert)
	local function getValue()
		if invert then
			return target[key] == false
		end
		return target[key]
	end
	local function setValue(checked)
		if invert then
			target[key] = not checked
		else
			target[key] = checked
		end
		save()
	end
	return getValue, setValue
end

local function addBoundCheckbox(parent, y, label, target, key, save, tipKey, invert)
	local getter, setter = boundAccessors(target, key, save, invert)
	return addCheckbox(parent, label, y, getter, setter, tipKey)
end

local function groupMinimumItemLevelText()
	local admission = GF.GroupItemLevelAdmission
	local minimum = admission
		and type(admission.GetMinimumEquippedItemLevel) == "function"
		and admission:GetMinimumEquippedItemLevel() or nil
	if type(minimum) == "number" then
		return tostring(minimum)
	end
	return (GF.L or {}).FILTER_GROUP_MIN_ITEM_LEVEL_UNAVAILABLE or "N/A"
end

local function addGroupMinimumItemLevelAdmission(parent, y, target, key, save)
	local L = GF.L or {}
	local labelText = L.FILTER_GROUP_MIN_ITEM_LEVEL_ADMISSION
		or "Minimum admission"
	local tipKey = "FILTER_TIP_GROUP_MIN_ITEM_LEVEL_ADMISSION"
	local row = createFilterRow(parent, y, nil, "admissionRow")
	local labelWidth = RANGE_INPUT_OFFSET_X - FILTER_CHECK_LABEL_GAP - 4
	local cb, label = createCheckCell(row, labelText, labelWidth)
	label:SetWidth(labelWidth)

	-- This is deliberately a passive Frame rather than an EditBox. Its rectangle
	-- exactly spans the two numeric boxes of a range row, while its checked atlas
	-- state mirrors the admission checkbox without accepting input.
	local statusWidth = math.max(1, math.min(
		RANGE_PAIR_W,
		FILTER_ROW_W
			- FILTER_CHECK_OFFSET_X
			- FILTER_CHECK_SIZE
			- RANGE_INPUT_OFFSET_X
			- 4))
	local status = acquireFilterControl(row, "status", function()
		return CreateFrame("Frame", nil, row)
	end)
	status:SetSize(statusWidth, RANGE_BOX_H)
	status:SetPoint("RIGHT", row, "RIGHT", -4, 0)

	local value = acquireFilterFontString(status, "GameFontHighlightSmall")
	value:SetPoint("LEFT", status, "LEFT", 0, 0)
	value:SetPoint("RIGHT", status, "RIGHT", 0, 0)
	value:SetJustifyH("CENTER")
	value:SetMaxLines(1)
	value:SetWordWrap(false)
	applyFilterTextStyle(value)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(value, statusWidth - 8, 8)
	end
	local function getter()
		return target[key]
	end
	local function refreshStatus()
		value:SetText(groupMinimumItemLevelText())
		if GF.UI and GF.UI.ApplyFilterInputChrome then
			GF.UI.ApplyFilterInputChrome(
				status,
				isFilterEnabled(getter()) and "checked" or "normal",
				{
					width = statusWidth,
					height = RANGE_BOX_H,
					layer = "BACKGROUND",
					subLevel = -6,
					shown = true,
				})
		end
	end
	cb:SetScript("OnClick", function(self)
		target[key] = toFilterBool(self:GetChecked())
		save()
		updateFilterCheckButton(self)
		refreshStatus()
	end)
	styleCheckCell(parent, row, cb, label, labelText, tipKey, getter)
	attachTip(value, tipKey, labelText)
	local sync = parent._gfSync
	if sync then
		sync.statuses[#sync.statuses + 1] = refreshStatus
	end
	refreshStatus()
	return y - CHECKBOX_ROW_H
end

local function addBoundCheckboxPair(parent, y, left, right, target, save)
	local leftGet, leftSet = boundAccessors(target, left.key, save, left.invert)
	local rightGet, rightSet = boundAccessors(target, right.key, save, right.invert)
	return addCheckboxPair(
		parent, y,
		left.label, leftGet, leftSet, left.tip,
		right.label, rightGet, rightSet, right.tip
	)
end

local function addConfiguredRanges(parent, y, definitions)
	for index = 1, #definitions do
		local item = definitions[index]
		if item.visible ~= false then
			local builder = item.singleValue and addRoleThresholdRow or addRangeRow
			y = builder(
				parent, item.label, y, item.target,
				item.enabledKey, item.minKey, item.maxKey, item.tipKey, item.save
			)
		end
	end
	return y
end

local function addConfiguredActivityGroup(parent, y, definition)
	local pool = definition.getItems()
	local options = definition.getOptions(pool)
	local function isEnabled(key)
		if definition.allDisabled() then
			return false
		end
		return ControlsPresenter:IsFilterActivityGroupEnabled(
			options, key, pool)
	end
	local function setEnabled(key, enabled)
		definition.setEnabled(options, key, enabled, pool)
		definition.save()
	end
	return addActivityGroupCheckboxes(
		parent, y, definition.title, pool, isEnabled, setEnabled,
		definition.tipKey, definition.titleAction
	)
end

local function addConfiguredActivityDropdown(parent, y, definition)
	local pool = {}
	local options
	local dropdownDefinition
	local function refreshState()
		local latestPool = definition.getItems()
		pool = type(latestPool) == "table" and latestPool or {}
		if dropdownDefinition then
			dropdownDefinition.values = pool
		end
		if #pool == 0 then
			options = { activities = {} }
		else
			options = definition.getOptions(pool)
		end
	end
	local function isEnabled(item)
		if definition.allDisabled() then
			return false
		end
		return ControlsPresenter:IsFilterActivityGroupEnabled(
			options, activityItemKey(item), pool)
	end
	local function setEnabled(item, enabled)
		definition.setEnabled(
			options, activityItemKey(item), enabled, pool)
		definition.save()
	end
	local function setAll(enabled)
		ControlsPresenter:SetAllFilterActivityGroupsEnabled(
			definition.kind, enabled)
		refreshState()
		definition.save()
	end
	refreshState()
	y = y - 6
	y = addSectionTitle(parent, definition.title, y)
	dropdownDefinition = {
		values = pool,
		label = activityItemLabel,
		isSelected = isEnabled,
		setSelected = setEnabled,
		setAll = setAll,
		refreshState = refreshState,
		title = definition.title,
		tipKey = definition.tipKey,
		tag = definition.tag,
		selectAllLabel = definition.selectAllLabel,
		clearAllLabel = definition.clearAllLabel,
		allLabel = definition.allLabel,
		noneLabel = definition.noneLabel,
		emptyLabel = definition.emptyLabel,
		selectedFormat = definition.selectedFormat,
	}
	return addMultiSelectDropdown(parent, y, dropdownDefinition)
end

local function prepareContentBuild(owner)
	local parent = owner.content
	resetFilterControls(parent)
	parent._gfFilterPoolRoot = parent
	parent._gfFilterPoolActive = true
	local spec = owner:GetSpec()
	local globalFilters = ControlsPresenter:GetFilterGlobal(spec)
	local clientFilters = ControlsPresenter:GetFilterClient(spec)
	parent._gfSync = { checks = {}, ranges = {}, dropdowns = {}, statuses = {} }
	parent._gfClient = clientFilters
	owner.client = clientFilters
	return parent, spec, globalFilters
end

local function localizedMappedLabel(locale, labels, value, fallback)
	local key = labels[value]
	if not key then
		return fallback or "?"
	end
	return locale[key] or key
end

local function finishContentBuild(owner, y)
	owner.content._gfFilterPoolActive = nil
	owner.content:SetHeight(FILTER_CONTENT_EDGE_PADDING - y)
	updateFilterScrollLayout(owner)
end

local function ownerMethodCallback(owner, methodName)
	return function()
		owner[methodName](owner)
	end
end

function FP:GetDisplayedDungeonDifficultyIndex()
	return ControlsPresenter:GetDisplayedDungeonDifficultyIndex(
		self.client)
end

function FP:GetDisplayedRaidDifficultyIndex()
	return ControlsPresenter:GetDisplayedRaidDifficultyIndex(
		self.client)
end

function FP:BuildContent()
	local L = GF.L or {}
	local parent, spec, db = prepareContentBuild(self)
	local y = -FILTER_CONTENT_TOP_PADDING
	local listOn = ControlsPresenter:IsListFilterEnabled()
	local saveClient = ownerMethodCallback(self, "SaveClient")
	local saveGlobal = ownerMethodCallback(self, "SaveGlobal")
	local function saveNotDeclined()
		ControlsPresenter:SaveNotDeclinedFilter(
			self:GetSpec(), self.client)
	end

	if spec and spec.showDungeonDifficulty then
		local title = L.FILTER_DIFFICULTY or "Difficulty"
		y = addSectionTitle(parent, title, y)
		local diffAnyLabel = L.FILTER_SELECT_ALL or L.FILTER_DIFF_ANY or L.FILTER_BLOODLUST_NONE or "无"
		local function currentDungeonDiffIndex()
			return self:GetDisplayedDungeonDifficultyIndex()
		end
		local function diffLabel(idx)
			if idx == 0 or not idx then
				return diffAnyLabel
			end
			return L[DIFF_LABELS[idx]] or DIFF_LABELS[idx]
		end
		y = addChoiceDropdown(parent, y, {
			values = sequentialValues(0, 4), current = currentDungeonDiffIndex, label = diffLabel,
			title = title, tipKey = "FILTER_TIP_DUNGEON_DIFFICULTY",
			select = function(value)
				ControlsPresenter:ApplyDungeonDifficulty(
					self.client, value)
				saveClient()
				self:RebuildIfNeeded(true)
			end,
		})
	end

	if spec and spec.showRaidDifficulty then
		local title = L.FILTER_DIFFICULTY or "Difficulty"
		y = addSectionTitle(parent, title, y)
		local raidDiffAnyLabel = L.FILTER_SELECT_ALL or L.FILTER_DIFF_ANY or L.FILTER_BLOODLUST_NONE or "无"
		local function currentRaidDiffIndex()
			return self:GetDisplayedRaidDifficultyIndex()
		end
		local function raidDiffLabel(idx)
			if idx == 0 or not idx then
				return raidDiffAnyLabel
			end
			return L[RAID_DIFF_LABELS[idx]] or RAID_DIFF_LABELS[idx]
		end
		y = addChoiceDropdown(parent, y, {
			values = sequentialValues(0, 3), current = currentRaidDiffIndex, label = raidDiffLabel,
			title = title, tipKey = "FILTER_TIP_RAID_DIFFICULTY",
			select = function(value)
				ControlsPresenter:ApplyRaidDifficulty(
					self.client, value)
				saveClient()
				self:RebuildIfNeeded(true)
			end,
		})
	end

	if spec and spec.showBloodlust then
		local title = L.FILTER_BLOODLUST or "Bloodlust"
		local function blLabel(mode)
			return localizedMappedLabel(L, BLOODLUST_LABELS, mode or 0, "?")
		end
		y = addChoiceDropdownHeader(parent, y, {
			values = sequentialValues(0, 2),
			current = function() return self.client.bloodlustMode or 0 end,
			label = blLabel, title = title, tipKey = "FILTER_TIP_BLOODLUST",
			select = function(value)
				self.client.bloodlustMode = value
				saveClient()
				self:RebuildIfNeeded(true)
			end,
		})
	end

	local showRequirements = spec and (spec.showMatchRole or spec.showNeedsMyClass or spec.showHasTankHeal)
	if showRequirements then
		y = addRoleFilterModeHeader(parent, L.FILTER_REQUIRE or "Require", y,
			self.client, saveClient)
		local showMatchRole = spec.showMatchRole
		local showNeedsMyClass = spec.showNeedsMyClass and spec.needsMyClassClient
		local matchDefinition = {
			label = L.FILTER_MATCH_ROLE or "Match my role",
			key = "matchMyRole", tip = "FILTER_TIP_MATCH_ROLE",
		}
		local classDefinition = {
			label = L.FILTER_NEEDS_CLASS or "Needs my class",
			key = "needsMyClass", tip = "FILTER_TIP_NEEDS_CLASS",
		}
		if showMatchRole and showNeedsMyClass then
			y = addBoundCheckboxPair(parent, y, matchDefinition, classDefinition, self.client, saveClient)
		elseif showMatchRole then
			y = addBoundCheckbox(parent, y, matchDefinition.label, self.client, matchDefinition.key, saveClient, matchDefinition.tip)
		elseif showNeedsMyClass then
			y = addBoundCheckbox(parent, y, classDefinition.label, self.client, classDefinition.key, saveClient, classDefinition.tip)
		end
		if spec.showHasTankHeal and spec.hasTankHealClient then
			local pairs = {
				{ "hasTank", "alreadyHasTank", L.FILTER_HAS_TANK or "No tank", L.FILTER_ALREADY_HAS_TANK or "Has tank", "FILTER_TIP_HAS_TANK", "FILTER_TIP_ALREADY_HAS_TANK" },
				{ "hasHeal", "alreadyHasHeal", L.FILTER_HAS_HEAL or "No healer", L.FILTER_ALREADY_HAS_HEAL or "Has healer", "FILTER_TIP_HAS_HEAL", "FILTER_TIP_ALREADY_HAS_HEAL" },
			}
			for index = 1, #pairs do
				local pair = pairs[index]
				y = addExclusiveClientCheckboxPair(
					parent, y, self.client,
					pair[1], pair[2], pair[3], pair[4], pair[5], pair[6], saveClient
				)
			end
		end
	end

	local showRoleRanges = spec and (spec.showTankRange or spec.showHealRange or spec.showDpsRange)
	if showRoleRanges then
		y = addSectionTitle(parent, L.FILTER_RANGES or "Ranges", y)
		y = addConfiguredRanges(parent, y, {
			{ visible = not not spec.showTankRange, singleValue = true, label = L.FILTER_NEEDS_TANK or "Tank slots", target = self.client, enabledKey = "rangeTankEn", minKey = "rangeTankMin", maxKey = "rangeTankMax", tipKey = "FILTER_TIP_TANK", save = saveClient },
			{ visible = not not spec.showHealRange, singleValue = true, label = L.FILTER_NEEDS_HEAL or "Heal slots", target = self.client, enabledKey = "rangeHealEn", minKey = "rangeHealMin", maxKey = "rangeHealMax", tipKey = "FILTER_TIP_HEAL", save = saveClient },
			{ visible = not not spec.showDpsRange, singleValue = true, label = L.FILTER_NEEDS_DPS or "DPS slots", target = self.client, enabledKey = "rangeDpsEn", minKey = "rangeDpsMin", maxKey = "rangeDpsMax", tipKey = "FILTER_TIP_DPS", save = saveClient },
		})
	end

	if spec and spec.showRaidRoleCounts then
		y = addRoleFilterModeHeader(parent, L.FILTER_RAID_ROLES or L.FILTER_REQUIRE or "Role Filter", y,
			self.client, saveClient)
		y = addConfiguredRanges(parent, y, {
			{ label = L.LIST_TIP_ROLE_TANK or "Tank", target = self.client, enabledKey = "raidTankEn", minKey = "raidTankMin", maxKey = "raidTankMax", tipKey = "FILTER_TIP_RAID_TANK", save = saveClient },
			{ label = L.LIST_TIP_ROLE_HEALER or "Healer", target = self.client, enabledKey = "raidHealEn", minKey = "raidHealMin", maxKey = "raidHealMax", tipKey = "FILTER_TIP_RAID_HEAL", save = saveClient },
			{ label = L.LIST_TIP_ROLE_DPS or "DPS", target = self.client, enabledKey = "raidDpsEn", minKey = "raidDpsMin", maxKey = "raidDpsMax", tipKey = "FILTER_TIP_RAID_DPS", save = saveClient },
		})
	end

	local showRaidNumberFilters = spec and (spec.showRaidMemberCount or spec.showRaidBossKills)
	local showThresholds = (spec and spec.showMplusRange)
		or showRaidNumberFilters or listOn or (spec and spec.layoutTier == "submax")
	if showThresholds then
		y = addSectionTitle(parent, L.FILTER_THRESHOLDS or "Thresholds", y)
		y = addConfiguredRanges(parent, y, {
			{ visible = not not (spec and spec.showMplusRange), label = L.FILTER_MPLUS_SCORE or "Leader score", target = db, enabledKey = "rangeMplusScoreEn", minKey = "rangeMplusScoreMin", maxKey = "rangeMplusScoreMax", tipKey = "FILTER_TIP_MPLUS", save = saveGlobal },
			{ label = L.FILTER_MAX_AGE or "Activity age", target = db, enabledKey = "rangeAgeEn", minKey = "rangeAgeMin", maxKey = "rangeAgeMax", tipKey = "FILTER_TIP_MAX_AGE", save = saveGlobal },
			{ label = L.FILTER_MIN_ILVL or "Req. ilvl", target = db, enabledKey = "rangeIlvlEn", minKey = "rangeIlvlMin", maxKey = "rangeIlvlMax", tipKey = "FILTER_TIP_MIN_ILVL", save = saveGlobal },
			{ visible = not not (spec and spec.showRaidMemberCount), label = L.FILTER_RAID_MEMBER_COUNT or "Group Size", target = self.client, enabledKey = "raidMemberCountEn", minKey = "raidMemberCountMin", maxKey = "raidMemberCountMax", tipKey = "FILTER_TIP_RAID_MEMBER_COUNT", save = saveClient },
			{ visible = not not (spec and spec.showRaidBossKills), label = L.FILTER_RAID_BOSS_KILLS or "Boss Kills", target = self.client, enabledKey = "raidBossKillsEn", minKey = "raidBossKillsMin", maxKey = "raidBossKillsMax", tipKey = "FILTER_TIP_RAID_BOSS_KILLS", save = saveClient },
			{ visible = not not (spec and spec.showMinHonor), label = L.FILTER_MIN_HONOR or "Honor level", target = db, enabledKey = "rangeHonorEn", minKey = "rangeHonorMin", maxKey = "rangeHonorMax", tipKey = "FILTER_TIP_MIN_HONOR", save = saveGlobal },
		})
		y = addGroupMinimumItemLevelAdmission(
			parent, y, db, "groupMinimumItemLevelAdmission", saveGlobal)
	end

	local showLimits = listOn or (spec and spec.layoutTier == "submax")
	local showLimitSection = showLimits or (spec and spec.showNotDeclined)
	if showLimitSection then
		y = addSectionTitle(parent, L.FILTER_LIMITS or "Limits", y)
		if spec and spec.showNotDeclined then
			y = addBoundCheckbox(parent, y, L.FILTER_NOT_DECLINED or "Not declined", self.client, "notDeclined", saveNotDeclined, "FILTER_TIP_NOT_DECLINED")
		end
		if showLimits then
			local limitDefinitions = {
				{ visible = not not ((spec and spec.showSameClass) or (spec and spec.layoutTier == "submax")), label = L.FILTER_SAME_CLASS or "Hide same DPS", key = "sameClass", tip = "FILTER_TIP_SAME_CLASS" },
				{ label = L.FILTER_ZERO_SCORE or "Hide 0 score", key = "zeroScore", tip = "FILTER_TIP_ZERO_SCORE" },
				{ label = L.FILTER_SAME_FACTION or "Same faction", key = "sameFactionOnly", tip = "FILTER_TIP_SAME_FACTION" },
				{ label = L.FILTER_HIDE_CROSS_REALM or "Hide cross-realm groups", key = "hideCrossRealm", tip = "FILTER_TIP_HIDE_CROSS_REALM" },
				{ label = L.FILTER_HIDE_VOICE or "Hide voice", key = "hideVoice", tip = "FILTER_TIP_HIDE_VOICE" },
				{ label = L.FILTER_SHOW_FRIENDS or "Friend groups", key = "showFriendGroups", tip = "FILTER_TIP_SHOW_FRIENDS", invert = true },
				{ label = L.FILTER_SHOW_GUILD or "Guild groups", key = "showGuildGroups", tip = "FILTER_TIP_SHOW_GUILD", invert = true },
			}
			for index = 1, #limitDefinitions do
				local item = limitDefinitions[index]
				if item.visible ~= false then
					y = addBoundCheckbox(parent, y, item.label, db, item.key, saveGlobal, item.tip, item.invert)
				end
			end
		end
	end

	local hasDungeonActivities =
		ControlsPresenter:HasFilterActivityGroup("dungeon")
	if spec and spec.showDungeonActivities and hasDungeonActivities then
		local isSeasonDungeon = spec.selection and spec.selection.navKind == "season_dungeon"
		local dungeonTitle = isSeasonDungeon
			and (L.FILTER_SEASON_DUNGEONS or L.FILTER_DUNGEONS or "Dungeons")
			or (L.FILTER_DUNGEONS or "Dungeons")
		local dungeonDefinition = {
			kind = "dungeon",
			title = dungeonTitle,
			getItems = function()
				return ControlsPresenter:GetFilterActivityItems("dungeon")
			end,
			getOptions = function(pool)
				return ControlsPresenter:GetFilterActivityOptions(
					"dungeon", pool)
			end,
			allDisabled = function()
				return ControlsPresenter:
					IsAllFilterActivityGroupsDisabled("dungeon")
			end,
			setEnabled = function(options, key, enabled, pool)
				ControlsPresenter:SetFilterActivityGroupEnabled(
					"dungeon", options, key, enabled, pool)
			end,
			save = saveGlobal,
		}
		if isSeasonDungeon then
			dungeonDefinition.tag =
				"MENU_GF_ADVANCED_FILTER_SEASON_DUNGEONS"
			dungeonDefinition.tipKey = "FILTER_TIP_SEASON_DUNGEONS"
			dungeonDefinition.selectAllLabel =
				L.FILTER_MULTI_SELECT_ALL or "Select All"
			dungeonDefinition.clearAllLabel =
				L.FILTER_MULTI_CLEAR_ALL or "Clear All"
			dungeonDefinition.allLabel =
				L.FILTER_ALL_SEASON_DUNGEONS or "All Seasonal Dungeons"
			dungeonDefinition.noneLabel =
				L.FILTER_NO_SEASON_DUNGEONS or "No Seasonal Dungeons Selected"
			dungeonDefinition.emptyLabel =
				L.FILTER_NO_SEASON_DUNGEONS_AVAILABLE or "No Seasonal Dungeons"
			dungeonDefinition.selectedFormat =
				L.FILTER_SELECTED_SEASON_DUNGEONS_FMT
				or "%d Seasonal Dungeons Selected"
			y = addConfiguredActivityDropdown(
				parent, y, dungeonDefinition)
		else
			y = addConfiguredActivityGroup(
				parent, y, dungeonDefinition)
		end
	end

	local hasRaidActivities =
		ControlsPresenter:HasFilterActivityGroup("raid")
	if spec and spec.showRaidActivities and hasRaidActivities then
		local raidTitle = (spec.selection and spec.selection.navKind == "season_raid")
			and (L.FILTER_SEASON_RAIDS or L.FILTER_RAIDS or "Raids")
			or (L.FILTER_RAIDS or "Raids")
		y = addConfiguredActivityGroup(parent, y, {
			title = raidTitle,
			getItems = function()
				return ControlsPresenter:GetFilterActivityItems("raid")
			end,
			getOptions = function(pool)
				return ControlsPresenter:GetFilterActivityOptions(
					"raid", pool)
			end,
			allDisabled = function()
				return ControlsPresenter:
					IsAllFilterActivityGroupsDisabled("raid")
			end,
			setEnabled = function(options, key, enabled, pool)
				ControlsPresenter:SetFilterActivityGroupEnabled(
					"raid", options, key, enabled, pool)
			end,
			save = saveGlobal,
		})
	end

	if showLimits then
		y = y - 6
		local playstyleTitle = L.FILTER_PLAYSTYLE or "Playstyle"
		y = addSectionTitle(parent, playstyleTitle, y)
		local playstyleValues = sequentialValues(1, 4)
		local function playstyleKey(index)
			return "playstyle" .. index
		end
		y = addMultiSelectDropdown(parent, y, {
			values = playstyleValues,
			label = function(index)
				return ControlsPresenter:GetPlaystyleFilterLabel(index)
			end,
			isSelected = function(index)
				return db[playstyleKey(index)] ~= false
			end,
			setSelected = function(index, enabled)
				db[playstyleKey(index)] = enabled == true
				saveGlobal()
			end,
			setAll = function(enabled)
				for index = 1, 4 do
					db[playstyleKey(index)] = enabled == true
				end
				saveGlobal()
			end,
			title = playstyleTitle,
			tipKey = "FILTER_TIP_PLAYSTYLE",
			tag = "MENU_GF_ADVANCED_FILTER_PLAYSTYLE",
			selectAllLabel = L.FILTER_MULTI_SELECT_ALL or "Select All",
			clearAllLabel = L.FILTER_MULTI_CLEAR_ALL or "Clear All",
			allLabel = L.FILTER_ALL_PLAYSTYLES or "All Playstyles",
			noneLabel = L.FILTER_NO_PLAYSTYLES or "No Playstyles Selected",
			selectedFormat = L.FILTER_SELECTED_PLAYSTYLES_FMT
				or "%d Playstyles Selected",
		})
	end

	if spec and spec.showWarmode then
		y = addSectionTitle(parent, L.FILTER_CLIENT or "Display filters", y)
		y = addBoundCheckbox(parent, y, L.FILTER_WARMODE or "War Mode only", self.client, "warmodeOnly", saveClient, "FILTER_TIP_WARMODE")
	end

	finishContentBuild(self, y)
end

function FP:SpecKey(spec)
	return ControlsPresenter:GetFilterSpecKey(spec)
end

local function currentClientFilters(spec)
	return ControlsPresenter:GetFilterClient(spec)
end

function FP:RebuildIfNeeded(force)
	if not self.scroll then
		return
	end
	local spec = self:GetSpec()
	local key = self:SpecKey(spec)
	local contentIsCurrent = not force and self.content and self._specKey == key
	if contentIsCurrent then
		self.client = replaceTableContents(self.content._gfClient or self.client, currentClientFilters(spec))
		self.content._gfClient = self.client
		self:SyncContentValues()
		updateFilterScrollLayout(self)
		return
	end
	if self.content then
		self.content:Hide()
	end
	GF.UI.CancelSmoothWheelScrolling(self.scroll)
	local content = self.content or CreateFrame("Frame", nil, self.scrollBody)
	content:SetPoint("TOPLEFT", self.scrollBody, "TOPLEFT", 0, 0)
	content:SetWidth(math.max(1, self.scroll:GetWidth()))
	self.content, self._specKey = content, key
	self:BuildContent()
	content:Show()
end

function FP:OnReset()
	local selection = self:GetSelection()
	ControlsPresenter:ResetFilter(selection, function()
		self:RebuildIfNeeded(true)
	end)
end

function FP:OnRefresh()
	ControlsPresenter:RequestFilterSearch()
	self:UpdateSearchButtonState()
end

function FP:OnGroupMinimumItemLevelChanged()
	self:SyncContentValues()
end

local function setSearchButtonPending(button, pending)
	if GF.UI and GF.UI.SetButtonPendingSpinner then
		GF.UI.SetButtonPendingSpinner(button, pending, pending and (GF.SEARCH_BUTTON_PENDING_SPINNER_SIZE or 18) or nil)
	end
end

function FP:UpdateSearchButtonState(searching)
	local button = self.refreshBtn
	if not button then
		return
	end
	local projection =
		ControlsPresenter:ProjectFilterSearchState(searching)
	button:SetText(projection.label)
	setSearchButtonPending(button, projection.pending == true)
	button:SetEnabled(projection.enabled == true)
end

function FP:AnchorToMain()
	local frame, main = self.frame, self.mainFrame
	if not (frame and main) then
		return
	end
	frame:SetHeight(main:GetHeight())
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", main, "TOPRIGHT", 2, 0)
	frame:SetPoint("BOTTOMLEFT", main, "BOTTOMRIGHT", 2, 0)
	if GF.UI and GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
end

function FP:Toggle()
	self:Init(self.mainFrame or (GF.MainFrame and GF.MainFrame.frame))
	if not self.frame then
		return
	end
	local action = self.frame:IsShown() and self.Hide or self.Show
	action(self)
end

local function prepareFilterPanelForShow(panel, frame)
	local applyBackground = GF.UI and GF.UI.ApplyBodyBackground
	panel:AnchorToMain()
	panel:RebuildIfNeeded(false)
	if type(applyBackground) == "function" then
		applyBackground(frame)
	end
end

function FP:Show()
	self:Init(self.mainFrame or (GF.MainFrame and GF.MainFrame.frame))
	local frame = self.frame
	if not frame then
		return
	end
	local shouldPlaySound = not frame:IsShown()
	prepareFilterPanelForShow(self, frame)
	frame:Show()
	if shouldPlaySound and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("open")
	end
end

function FP:Hide()
	local frame = self.frame
	if not frame then
		return
	end
	local shouldPlaySound = frame:IsShown()
	frame:Hide()
	if shouldPlaySound and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("close")
	end
end

function FP:IsShown()
	local frame = self.frame
	if not frame then
		return nil
	end
	return frame:IsShown()
end
