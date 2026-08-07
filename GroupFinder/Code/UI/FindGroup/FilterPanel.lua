local _, GF = ...

GF.FilterPanel = {}

local FP = GF.FilterPanel
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
local ROLE_THRESHOLD_BUTTON_SIZE = GF.FILTER_STEP_BUTTON_SIZE or RANGE_BOX_H
local ROLE_THRESHOLD_BUTTON_GAP = GF.FILTER_STEP_BUTTON_GAP or 2
local ROLE_THRESHOLD_ARROW_CENTER_OFFSET_X =
	GF.FILTER_STEP_ARROW_CENTER_OFFSET_X or 1
local FILTER_ROW_W = PANEL_W - 32
local SECTION_TOP_GAP = 6
local SECTION_TITLE_H = 16
local SECTION_BOTTOM_GAP = 3
local FILTER_SCROLL_INSET_EXTRA = 2
local FILTER_TOOLTIP_MIN_W = 240
local FILTER_OPTION_TEXT_SIZE = GF.FILTER_OPTION_TEXT_SIZE or 12
local FILTER_SECTION_TITLE_TEXT_SIZE = 13
local FILTER_SECTION_ACTION_BUTTON_W = 52
local FILTER_SECTION_ACTION_BUTTON_H = 20
local FILTER_SECTION_ACTION_BUTTON_OFFSET_Y = 2
local attachTip

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

local function filterScrollInsetR()
	return (GF.CONTENT_SCROLL_INSET_R or 18) + FILTER_SCROLL_INSET_EXTRA
end

local function filterScrollBarOffsetX(scrollInsetR)
	return math.max(
		0,
		(scrollInsetR or filterScrollInsetR())
			- (GF.FILTER_SCROLLBAR_RIGHT_INSET or 4)
			- (GF.FILTER_SCROLLBAR_WIDTH or 8)
	)
end

local function filterFooterAtlasTopOffset()
	local offset = GF.FILTER_FOOTER_ATLAS_TOP_OFFSET
	if offset == nil then
		offset = GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0
	end
	return offset or 0
end

local function anchorFilterScrollBar(scroll, bar, offsetX)
	if not scroll or not bar then
		return
	end
	if bar.SetWidth then
		bar:SetWidth(GF.FILTER_SCROLLBAR_WIDTH or 8)
	end
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", offsetX, -(GF.FILTER_SCROLLBAR_TOP_INSET or 4))
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", offsetX, GF.FILTER_SCROLLBAR_BOTTOM_INSET or 4)
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
	attachTip(row, tipKey, title)
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
	local fs = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontNormal")
	local titleY = y - SECTION_TOP_GAP
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
		local button = GF.UI.CreatePanelButton(parent, action.text, FILTER_SECTION_ACTION_BUTTON_W)
		button:SetSize(FILTER_SECTION_ACTION_BUTTON_W, FILTER_SECTION_ACTION_BUTTON_H)
		button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, titleY + FILTER_SECTION_ACTION_BUTTON_OFFSET_Y)
		button:SetScript("OnClick", action.onClick)
		fs:SetPoint("RIGHT", button, "LEFT", -6, 0)
		if action.tipKey then
			attachTip(button, action.tipKey, action.text, "aboveRight")
		end
	end
	return titleY - SECTION_TITLE_H - SECTION_BOTTOM_GAP
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
	if not (widget and tipKey and GameTooltip) then
		return
	end
	local tipText = (GF.L or {})[tipKey]
	if type(tipText) ~= "string" or tipText == "" then
		return
	end
	widget:HookScript("OnEnter", function(self)
		showFilterTip(self, title, tipText, placement)
	end)
	widget:HookScript("OnLeave", hideFilterTip)
end

local function attachDynamicTip(widget, titleFn, tipFn, placement)
	if not widget or not tipFn or not GameTooltip then
		return
	end
	widget._gfRefreshDynamicTip = function(self)
		local title = (type(titleFn) == "function") and titleFn() or titleFn
		local tip = (type(tipFn) == "function") and tipFn() or tipFn
		if tip and tip ~= "" then
			showFilterTip(self, title, tip, placement)
		end
	end
	widget:HookScript("OnEnter", function(self)
		self._gfDynamicTipActive = true
		self:_gfRefreshDynamicTip()
	end)
	widget:HookScript("OnLeave", function()
		widget._gfDynamicTipActive = nil
		hideFilterTip()
	end)
end

local function updateFilterCheckButton(cb)
	if GF.UI and GF.UI.UpdateFilterCheckButton then
		GF.UI.UpdateFilterCheckButton(cb)
	end
end

local function createFilterRow(parent, y, width)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(width or FILTER_ROW_W, CHECKBOX_ROW_H)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
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
	local cb = GF.UI.CreateFilterCheckButton(container)
	cb:SetPoint("TOPLEFT", container, "TOPLEFT", FILTER_CHECK_OFFSET_X, -FILTER_CHECK_OFFSET_Y)
	local label = GF.UI.CreateFontString(container, "OVERLAY", "GameFontHighlightSmall")
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
	local row = createFilterRow(parent, y)
	local cellW = math.floor((FILTER_ROW_W - FILTER_PAIR_GAP) / 2)
	local definitions = {
		{ leftLabel, leftGetter, leftSetter, leftTipKey },
		{ rightLabel, rightGetter, rightSetter, rightTipKey },
	}
	for index, definition in ipairs(definitions) do
		local label = definition[1]
		local getter, setter, tipKey = definition[2], definition[3], definition[4]
		local cell = CreateFrame("Frame", nil, row)
		cell:SetPoint("TOPLEFT", row, "TOPLEFT", (index - 1) * (cellW + FILTER_PAIR_GAP), 0)
		cell:SetSize(cellW, CHECKBOX_ROW_H)
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
	local row = createFilterRow(parent, y)
	local cellW = math.floor((FILTER_ROW_W - FILTER_PAIR_GAP) / 2)
	local entries = {}
	local definitions = {
		{ key = leftKey, peer = rightKey, label = leftLabel, tip = leftTipKey },
		{ key = rightKey, peer = leftKey, label = rightLabel, tip = rightTipKey },
	}
	for index, definition in ipairs(definitions) do
		local cell = CreateFrame("Frame", nil, row)
		cell:SetPoint("TOPLEFT", row, "TOPLEFT", (index - 1) * (cellW + FILTER_PAIR_GAP), 0)
		cell:SetSize(cellW, CHECKBOX_ROW_H)
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
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
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
	local row = createFilterRow(parent, y)
	local labelWidth = RANGE_INPUT_OFFSET_X - FILTER_CHECK_LABEL_GAP - 4
	local cb, fs = createCheckCell(row, label, labelWidth)
	fs:SetWidth(labelWidth)
	local function enabledGetter()
		return client[enKey]
	end
	local minBox = createNumberInput(row, client[minKey], 4)
	minBox:SetPoint("LEFT", cb, "RIGHT", RANGE_INPUT_OFFSET_X, 0)
	attachTip(minBox, tipKey, label)
	local dash = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	dash:SetPoint("LEFT", minBox, "RIGHT", 4, 0)
	dash:SetText("-")
	applyFilterTextStyle(dash)
	local maxBox = createNumberInput(row, client[maxKey], 4)
	maxBox:SetPoint("LEFT", dash, "RIGHT", 4, 0)
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
	return GF.UI.CreateFilterStepButton(parent, direction, {
		size = ROLE_THRESHOLD_BUTTON_SIZE or RANGE_BOX_H,
		arrowCenterOffsetX = ROLE_THRESHOLD_ARROW_CENTER_OFFSET_X,
	})
end

local function addRoleThresholdRow(parent, label, y, client, enKey, minKey, maxKey, tipKey, onSave)
	local row = createFilterRow(parent, y)
	local rangeLabelW = getSingleValueLabelWidth()
	local cb, fs = createCheckCell(row, label, rangeLabelW)
	fs:SetWidth(rangeLabelW)
	local function enabledGetter()
		return client[enKey]
	end
	local decrementBtn = createRoleThresholdStepButton(row, "left")
	decrementBtn:SetPoint("LEFT", row, "LEFT", getRightColumnControlOffsetX(), 0)
	local thresholdBox = createNumberInput(row, normalizeRoleThreshold(client[minKey]), 1)
	thresholdBox:SetPoint("LEFT", decrementBtn, "RIGHT", ROLE_THRESHOLD_BUTTON_GAP, 0)
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
	thresholdBox:HookScript("OnTextChanged", function(self)
		if self._gfDynamicTipActive and self._gfRefreshDynamicTip then
			self:_gfRefreshDynamicTip()
		end
	end)
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

local function addRoleFilterModeDropdown(parent, y, client, onSave)
	local L = GF.L or {}
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	row:SetSize(PANEL_W - 32, CHECKBOX_ROW_H)
	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", row, "LEFT", FILTER_CHECK_OFFSET_X, 0)
	label:SetWidth(getRightColumnControlOffsetX() - FILTER_CHECK_OFFSET_X - 8)
	label:SetJustifyH("LEFT")
	label:SetMaxLines(1)
	label:SetWordWrap(false)
	label:SetText(L.FILTER_ROLE_MODE or "Filter Mode")
	applyFilterTextSize(label, FILTER_OPTION_TEXT_SIZE, "GameFontHighlightSmall")
	applyFilterOptionTextStyle(label, true, true)
	local dd = GF.UI.CreateDropdownButton(row)
	dd:SetSize(104, 24)
	dd:SetPoint("LEFT", row, "LEFT", getRightColumnControlOffsetX(), 0)
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
	attachTip(row, "FILTER_TIP_ROLE_MODE", L.FILTER_ROLE_MODE or "Filter Mode")
	attachTip(label, "FILTER_TIP_ROLE_MODE", L.FILTER_ROLE_MODE or "Filter Mode")
	attachTip(dd, "FILTER_TIP_ROLE_MODE", L.FILTER_ROLE_MODE or "Filter Mode")
	local sync = parent._gfSync
	if sync then
		sync.dropdowns[#sync.dropdowns + 1] = {
			dd = dd,
			labelFn = function()
				return roleFilterModeLabel(FP.client and FP.client.roleFilterMode)
			end,
		}
	end
	return y - CHECKBOX_ROW_H
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

local function getActivityInfoForSelection(selection)
	if not selection or not selection.activityID then
		return nil
	end
	return selection.activityInfo or pcallFirst(C_LFGList and C_LFGList.GetActivityInfoTable, selection.activityID)
end

local function getActivityDifficultyIndex(info, includeMplus)
	return GF.ActivityInfo and GF.ActivityInfo.GetDifficultyIndex(info, { includeMplus = includeMplus }) or 0
end

local function getSeasonRaidSelectionDifficultyIndex(selection)
	if not selection or selection.categoryID ~= GF.CAT_RAID then
		return nil
	end
	local isSeasonRaid = selection.navKind == "season_raid"
		or (type(selection.key) == "string" and selection.key:match("^season_raid"))
	if not isSeasonRaid then
		return nil
	end
	if not selection.activityID then
		return 0
	end
	return getActivityDifficultyIndex(getActivityInfoForSelection(selection), false)
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
	if self.content and self.content.SetFrameLevel then
		self.content:SetFrameLevel(contentLevel + 1)
	end
	if self._contentCache then
		for _, content in pairs(self._contentCache) do
			if content and content.SetFrameLevel then
				content:SetFrameLevel(contentLevel + 1)
			end
		end
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

local function installFilterScroll(owner, contentLevel, rightInset, footerHeight, footerBottom)
	local scroll = GF.UI.CreateScrollFrame(owner.frame, { rowHeight = GF.FILTER_WHEEL_ROW_H or 28 })
	scroll:SetFrameLevel(contentLevel)
	scroll:SetPoint("TOPLEFT", owner.frame, "TOPLEFT", 4, -28)
	local bottom = footerHeight + footerBottom + filterFooterAtlasTopOffset()
	scroll:SetPoint("BOTTOMRIGHT", owner.frame, "BOTTOMRIGHT", -rightInset, bottom)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(PANEL_W - 4 - rightInset)
	scroll:SetScrollChild(content)
	local barOffset = filterScrollBarOffsetX(rightInset)
	local bar = GF.UI.BindMinimalScrollBar(scroll, barOffset, owner.frame, true)
	anchorFilterScrollBar(scroll, bar, barOffset)
	if GF.UI.BindSmoothWheelScrolling then
		GF.UI.BindSmoothWheelScrolling(scroll)
	end
	owner.scroll, owner.content, owner.scrollBar = scroll, content, bar
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
	self.mainFrame = mainFrame
	local L = GF.L or {}
	local frame = createFilterPanelFrame(mainFrame, L.FILTER_ADVANCED or "Filter")
	self.frame = frame
	frame._gfOnSatelliteFrameLayersApplied = function()
		FP:SyncFrameLevels()
	end
	frame:SetScript("OnUpdate", function()
		FP:OnFocusSyncUpdate()
	end)
	frame.ClosePanelButton:SetScript("OnClick", function()
		FP:Hide()
	end)

	local contentLevel = frame:GetFrameLevel() + 5
	local scrollInsetR = filterScrollInsetR()
	local footerH = GF.FILTER_FOOTER_H or GF.SUBTITLE_H or 42
	local footerInsetB = GF.FILTER_FOOTER_INSET_B or GF.FRAME_BG_INSET_BOTTOM or 3
	installFilterFooter(self, contentLevel, footerH, footerInsetB)
	installFilterScroll(self, contentLevel, scrollInsetR, footerH, footerInsetB)

	local buttonWidth = GF.PANEL_BUTTON_TWO_CHAR_W or 72
	local buttonGap = GF.FILTER_FOOTER_BUTTON_GAP or 10
	local centerOffset = math.floor((buttonWidth + buttonGap) * 0.5)
	local buttonY = GF.FILTER_FOOTER_BUTTON_OFFSET_Y or 12
	self.refreshBtn = createFooterCommand(self, {
		text = L.FILTER_REFRESH or "Search", tipKey = "FILTER_TIP_REFRESH", side = -1,
		callback = function() FP:OnRefresh() end,
	}, contentLevel, buttonWidth, centerOffset, buttonY)
	self.resetBtn = createFooterCommand(self, {
		text = L.FILTER_RESET or "Reset", tipKey = "FILTER_TIP_RESET", side = 1,
		callback = function() FP:OnReset() end,
	}, contentLevel, buttonWidth, centerOffset, buttonY)
	self:UpdateSearchButtonState()
	if UISpecialFrames then
		tinsert(UISpecialFrames, self.frame:GetName())
	end
	self:SyncFrameLevels()
end

function FP:GetSelection()
	local browseOwner = GF.FindGroupTab
	if browseOwner and type(browseOwner.GetSelection) == "function" then
		local selection = browseOwner:GetSelection()
		if selection then
			return selection
		end
	end
	local main = GF.MainFrame
	return main and main.selection or nil
end

function FP:GetSpec()
	local selection = self:GetSelection()
	local resolver = GF.FilterSpec
	if resolver then
		local spec = resolver:ResolveSpec(selection)
		-- A catalog availability refresh can temporarily leave both selection
		-- owners empty.  The Mythic+ workspace still has a fixed season-dungeon
		-- filter contract and must remain buildable in that interval.
		if selection or (spec and spec.isMythicPlusBrowse) then
			return spec
		end
	end
	return nil
end

function FP:SaveClient()
	local activeSpec = self:GetSpec()
	if not activeSpec then
		return
	end
	GF.Filter:SaveCategoryClientFilters(activeSpec.clientKey, self.client)
	GF.Filter:ApplyClientFilterRefresh()
end

function FP:SaveGlobal()
	GF.Filter:ApplyClientFilterRefresh()
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
		if entry.labelFn and entry.dd then
			local label = entry.labelFn()
			setFilterDropdownLabel(entry.dd, label)
		end
	end
end

function FP:ActivateContent(content, spec, key)
	local previous = self.content
	if previous and previous ~= content then
		previous:Hide()
	end
	local latest = spec and GF.Filter:GetClientFilters(spec.clientKey) or {}
	self.client = replaceTableContents(content._gfClient, latest)
	content._gfClient = self.client
	self.content, self._specKey = content, key
	self.scroll:SetScrollChild(content)
	content:Show()
	self:SyncContentValues()
	GF.UI.UpdateScrollFrame(self.scroll)
end

local function registerDropdownSync(parent, dropdown, labelProvider)
	table.insert(parent._gfSync.dropdowns, { dd = dropdown, labelFn = labelProvider })
end

local function addChoiceDropdown(parent, y, definition)
	local dropdown = GF.UI.CreateDropdownButton(parent)
	dropdown:SetSize(PANEL_W - 40, 26)
	dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
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
		return GF.Filter:IsGroupEnabled(options, key, pool)
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

local function prepareContentBuild(owner)
	local parent = owner.content
	local spec = owner:GetSpec()
	local globalFilters = spec and GF.Filter and GF.Filter.GetGlobalFilters
		and GF.Filter:GetGlobalFilters(spec) or GF.GetDB()
	local clientFilters = spec and GF.Filter:GetClientFilters(spec.clientKey) or {}
	parent._gfSync = { checks = {}, ranges = {}, dropdowns = {} }
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
	owner.content:SetHeight(math.max(80, 8 - y))
	GF.UI.UpdateScrollFrame(owner.scroll)
end

local function ownerMethodCallback(owner, methodName)
	return function()
		owner[methodName](owner)
	end
end

function FP:GetDisplayedDungeonDifficultyIndex()
	if not (GF.Filter and GF.Filter.GetClientDifficultyIndex) then
		return 0
	end
	return GF.Filter:GetClientDifficultyIndex(self.client, true)
end

function FP:BuildContent()
	local L = GF.L or {}
	local parent, spec, db = prepareContentBuild(self)
	local y = -8
	local listFilter = GF.ListFilter
	local listOn = listFilter and listFilter:IsEnabled()
	local saveClient = ownerMethodCallback(self, "SaveClient")
	local saveGlobal = ownerMethodCallback(self, "SaveGlobal")
	local function saveNotDeclined()
		if self.client.notDeclined and GF.Apply
			and type(GF.Apply.ClearRejectionFeedback) == "function"
		then
			GF.Apply:ClearRejectionFeedback()
		end
		saveClient()
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
				GF.Filter:ApplyDifficultyToClient(self.client, value, true)
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
			return getSeasonRaidSelectionDifficultyIndex(FP:GetSelection())
				or GF.Filter:GetRaidDifficultyIndex(FP.client)
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
				GF.Filter:ApplyRaidDifficultyToClient(self.client, value)
				saveClient()
				self:RebuildIfNeeded(true)
			end,
		})
	end

	if spec and spec.showBloodlust then
		local title = L.FILTER_BLOODLUST or "Bloodlust"
		y = addSectionTitle(parent, title, y)
		local function blLabel(mode)
			return localizedMappedLabel(L, BLOODLUST_LABELS, mode or 0, "?")
		end
		y = addChoiceDropdown(parent, y, {
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
		y = addSectionTitle(parent, L.FILTER_REQUIRE or "Require", y)
		y = addRoleFilterModeDropdown(parent, y, self.client, saveClient)
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
		y = addSectionTitle(parent, L.FILTER_RAID_ROLES or L.FILTER_REQUIRE or "Role Filter", y)
		y = addRoleFilterModeDropdown(parent, y, self.client, saveClient)
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

	if spec and spec.showDungeonActivities and GF.Filter.GetDungeonActivityItems then
		local isSeasonDungeon = spec.selection and spec.selection.navKind == "season_dungeon"
		local dungeonTitle = isSeasonDungeon
			and (L.FILTER_SEASON_DUNGEONS or L.FILTER_DUNGEONS or "Dungeons")
			or (L.FILTER_DUNGEONS or "Dungeons")
		local dungeonTitleAction
		if isSeasonDungeon then
			dungeonTitleAction = {
				text = L.FILTER_CLEAR or "Clear",
				tipKey = "FILTER_TIP_CLEAR_SEASON_DUNGEONS",
				onClick = function()
					if GF.UI and GF.UI.PlayUISound then
						GF.UI.PlayUISound("check")
					end
					GF.Filter:SetAllDungeonGroupsDisabled(true)
					GF.Filter:SetPersistedActivities(nil)
					GF.Filter:SetPersistedActivityKeys({})
					saveGlobal()
					self:SyncContentValues()
				end,
			}
		end
		y = addConfiguredActivityGroup(parent, y, {
			title = dungeonTitle,
			getItems = function() return GF.Filter:GetDungeonActivityItems() end,
			getOptions = function(pool) return GF.Filter:GetDungeonActivityOptions(pool) end,
			allDisabled = function() return GF.Filter:IsAllDungeonGroupsDisabled() end,
			setEnabled = function(options, key, enabled, pool)
				GF.Filter:SetDungeonGroupEnabled(options, key, enabled, pool)
			end,
			save = saveGlobal,
			titleAction = dungeonTitleAction,
		})
	end

	if spec and spec.showRaidActivities and GF.Filter.GetRaidActivityItems then
		local raidTitle = (spec.selection and spec.selection.navKind == "season_raid")
			and (L.FILTER_SEASON_RAIDS or L.FILTER_RAIDS or "Raids")
			or (L.FILTER_RAIDS or "Raids")
		y = addConfiguredActivityGroup(parent, y, {
			title = raidTitle,
			getItems = function() return GF.Filter:GetRaidActivityItems() end,
			getOptions = function(pool) return GF.Filter:GetRaidActivityOptions(pool) end,
			allDisabled = function() return GF.Filter:IsAllRaidGroupsDisabled() end,
			setEnabled = function(options, key, enabled, pool)
				GF.Filter:SetRaidGroupEnabled(options, key, enabled, pool)
			end,
			save = saveGlobal,
		})
	end

	if showLimits then
		y = y - 6
		y = addSectionTitle(parent, L.FILTER_PLAYSTYLE or "Playstyle", y)
		for index = 1, 4 do
			local playstyleIndex = index
			local storageKey = "playstyle" .. playstyleIndex
			local function getPlaystyle()
				return db[storageKey] ~= false
			end
			local function setPlaystyle(enabled)
				db[storageKey] = enabled == true
				saveGlobal()
			end
			y = addCheckbox(parent, GF.Filter:GetPlaystyleFilterLabel(playstyleIndex), y, getPlaystyle, setPlaystyle)
		end
	end

	if spec and spec.showWarmode then
		y = addSectionTitle(parent, L.FILTER_CLIENT or "Display filters", y)
		y = addBoundCheckbox(parent, y, L.FILTER_WARMODE or "War Mode only", self.client, "warmodeOnly", saveClient, "FILTER_TIP_WARMODE")
	end

	finishContentBuild(self, y)
end

function FP:SpecKey(spec)
	if spec == nil then
		return ""
	end
	local parts = {
		tostring(spec.workspaceID or ""),
		tostring(spec.clientKey or ""),
		tostring(spec.layoutTier or ""),
		tostring(spec.navColumn or 0),
		tostring(spec.categoryID or ""),
		tostring(spec.selection and spec.selection.navKind or ""),
	}
	return table.concat(parts, ":")
end

local function currentClientFilters(spec)
	if spec then
		return GF.Filter:GetClientFilters(spec.clientKey)
	end
	return {}
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
		return
	end
	if force then
		self._contentCache = nil
	else
		local cached = self._contentCache and self._contentCache[key]
		if cached then
			self:ActivateContent(cached, spec, key)
			return
		end
	end
	if self.content then
		self.content:Hide()
	end
	local content = CreateFrame("Frame", nil, self.scroll)
	content:SetWidth(PANEL_W - 4 - filterScrollInsetR())
	self.content, self._specKey = content, key
	self.scroll:SetScrollChild(content)
	self:BuildContent()
	self._contentCache = self._contentCache or {}
	self._contentCache[key] = content
end

function FP:OnReset()
	local selection = self:GetSelection()
	if selection then
		GF.Filter:ResetCategory(selection)
	end
	self._contentCache = nil
	self:RebuildIfNeeded(true)
	GF.Filter:ApplyClientFilterRefresh()
end

function FP:OnRefresh()
	local tab = GF.FindGroupTab
	if tab then
		tab:DoSearch()
	end
	self:UpdateSearchButtonState()
end

local function getSearchBusyState(explicitState)
	local tab = GF.FindGroupTab
	local cooldown = tab and tab.GetSearchCooldownRemaining and tab:GetSearchCooldownRemaining() or 0
	local panel = tab and tab.GetPanel and tab:GetPanel() or nil
	local pending = panel and panel.IsSearchPending and panel:IsSearchPending()
	return explicitState or GF.searching or pending, cooldown
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
	local busy, cooldown = getSearchBusyState(searching)
	button:SetText((GF.L or {}).FILTER_REFRESH or "Search")
	if busy or cooldown > 0 then
		setSearchButtonPending(button, true)
		button:SetEnabled(false)
		return
	end
	setSearchButtonPending(button, false)
	local searchable = true
	local tab = GF.FindGroupTab
	if tab and tab.IsSearchableSelection then
		searchable = tab:IsSearchableSelection(self:GetSelection()) ~= false
	end
	button:SetEnabled(searchable)
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
	self:Init(self.mainFrame)
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
	self:Init(self.mainFrame)
	local frame = self.frame
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
