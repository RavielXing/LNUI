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
local FILTER_CHECK_ATLAS_TEXTURE = GF.FILTER_CHECK_ATLAS_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\FilterCheckAtlas.png"
local FILTER_CHECK_ATLAS_INSET_X = GF.FILTER_CHECK_ATLAS_INSET_X or (0.5 / 128)
local FILTER_CHECK_ATLAS_INSET_Y = GF.FILTER_CHECK_ATLAS_INSET_Y or (0.5 / 64)
local FILTER_CHECK_ATLAS_COORDS = {
	checked = { FILTER_CHECK_ATLAS_INSET_X, 0.5 - FILTER_CHECK_ATLAS_INSET_X, FILTER_CHECK_ATLAS_INSET_Y, 1 - FILTER_CHECK_ATLAS_INSET_Y },
	normal = { 0.5 + FILTER_CHECK_ATLAS_INSET_X, 1 - FILTER_CHECK_ATLAS_INSET_X, FILTER_CHECK_ATLAS_INSET_Y, 1 - FILTER_CHECK_ATLAS_INSET_Y },
}
FILTER_CHECK_ATLAS_COORDS.hover = FILTER_CHECK_ATLAS_COORDS.checked
local FILTER_INPUT_ATLAS_COORDS = {
	hover = FILTER_CHECK_ATLAS_COORDS.checked,
	normal = FILTER_CHECK_ATLAS_COORDS.normal,
}
local FILTER_INPUT_CAP_W = 9
local FILTER_INPUT_LEFT_RATIO = 0.45
local FILTER_INPUT_RIGHT_RATIO = 0.55
local RANGE_BOX_W = 44
local RANGE_BOX_H = 20
local RANGE_INPUT_OFFSET_X = 86
local ROLE_THRESHOLD_BUTTON_SIZE = RANGE_BOX_H
local ROLE_THRESHOLD_BUTTON_GAP = 2
local ROLE_THRESHOLD_ARROW_CENTER_OFFSET_X = 1
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
local WHITE = "Interface\\Buttons\\WHITE8X8"
local attachTip

local function paint(texture, r, g, b, a)
	if not texture then
		return
	end
	if texture.SetColorTexture then
		texture:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
	else
		texture:SetTexture(WHITE)
		texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
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

local function snapTexture(texture)
	if not texture then
		return
	end
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(true)
	end
	if texture.SetTexelSnappingBias then
		texture:SetTexelSnappingBias(0)
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

local function applyFilterRoundedBorder(texture, fallbackAlpha)
	if not texture then
		return
	end
	local ok = GF.UI and GF.UI.TrySetAtlas and GF.UI.TrySetAtlas(texture, "common-dropdown-textholder", false)
	if ok then
		texture:SetVertexColor(1, 1, 1, 1)
	else
		texture:SetTexture(WHITE)
		texture:SetVertexColor(1, 0.76, 0.24, fallbackAlpha or 0.55)
	end
end

local function styleFilterOptionRow(row, cb, tipKey, title)
	if not row or row._gfFilterRowStyled then
		return
	end
	row:EnableMouse(true)
	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and cb and cb.Click and (not cb.IsEnabled or cb:IsEnabled()) then
			cb:Click()
		end
	end)
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
	local coords = active and FILTER_INPUT_ATLAS_COORDS.hover or FILTER_INPUT_ATLAS_COORDS.normal
	local pieces = box._gfFilterInputAtlas
	if pieces then
		local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
		local width = right - left
		local leftU = left + width * FILTER_INPUT_LEFT_RATIO
		local rightU = left + width * FILTER_INPUT_RIGHT_RATIO
		pieces.left:SetTexCoord(left, leftU, top, bottom)
		pieces.middle:SetTexCoord(leftU, rightU, top, bottom)
		pieces.right:SetTexCoord(rightU, right, top, bottom)
		pieces.left:SetVertexColor(1, 1, 1, 1)
		pieces.middle:SetVertexColor(1, 1, 1, 1)
		pieces.right:SetVertexColor(1, 1, 1, 1)
	end
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

		local left = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		left:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
		left:SetWidth(FILTER_INPUT_CAP_W)
		left:SetTexture(FILTER_CHECK_ATLAS_TEXTURE)
		snapTexture(left)

		local right = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
		right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
		right:SetWidth(FILTER_INPUT_CAP_W)
		right:SetTexture(FILTER_CHECK_ATLAS_TEXTURE)
		snapTexture(right)

		local middle = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
		middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
		middle:SetTexture(FILTER_CHECK_ATLAS_TEXTURE)
		snapTexture(middle)

		box._gfFilterInputAtlas = {
			left = left,
			middle = middle,
			right = right,
		}

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
	y = y - SECTION_TOP_GAP
	local fs = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
	fs:SetText(text)
	fs:SetDrawLayer("OVERLAY", 2)
	fs:SetMaxLines(1)
	fs:SetWordWrap(false)
	fs:SetJustifyH("LEFT")
	applyFilterTextSize(fs, FILTER_SECTION_TITLE_TEXT_SIZE, "GameFontNormal")
	applyFilterTextStyle(fs)
	if action and action.text and action.onClick then
		local button = GF.UI.CreatePanelButton(parent, action.text, FILTER_SECTION_ACTION_BUTTON_W, true)
		button:SetSize(FILTER_SECTION_ACTION_BUTTON_W, FILTER_SECTION_ACTION_BUTTON_H)
		button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y + FILTER_SECTION_ACTION_BUTTON_OFFSET_Y)
		button:SetScript("OnClick", action.onClick)
		fs:SetPoint("RIGHT", button, "LEFT", -6, 0)
		if action.tipKey then
			attachTip(button, action.tipKey, action.text, "aboveRight")
		end
	end
	return y - SECTION_TITLE_H - SECTION_BOTTOM_GAP
end

local function showFilterTip(owner, title, tip, placement)
	if not owner or not tip or tip == "" or not GameTooltip then
		return
	end
	if placement == "aboveRight" and GF.UI.BeginGameTooltipAbove then
		GF.UI.BeginGameTooltipAbove(owner, "RIGHT")
	elseif placement == "aboveLeft" and GF.UI.BeginGameTooltipAbove then
		GF.UI.BeginGameTooltipAbove(owner, "LEFT")
	else
		GF.UI.BeginGameTooltip(owner, "ANCHOR_LEFT")
	end
	if GameTooltip.SetMinimumWidth then
		GameTooltip:SetMinimumWidth(FILTER_TOOLTIP_MIN_W)
	end
	local goldR = GF.UI.TOOLTIP_GOLD_R or 1
	local goldG = GF.UI.TOOLTIP_GOLD_G or 0.82
	local goldB = GF.UI.TOOLTIP_GOLD_B or 0
	if title and title ~= "" then
		GameTooltip:SetText(title, goldR, goldG, goldB, 1, true)
	else
		GameTooltip:SetText(tip, goldR, goldG, goldB, 1, true)
		tip = nil
	end
	if tip then
		for line in string.gmatch(tip .. "\n", "([^\n]*)\n") do
			if line == "" then
				GameTooltip:AddLine(" ", 1, 1, 1, false)
			else
				GameTooltip:AddLine(line, 1, 1, 1, true)
			end
		end
	end
	GF.UI.ShowGameTooltip()
end

function attachTip(widget, tipKey, title, placement)
	if not widget or not tipKey or not GameTooltip then
		return
	end
	local L = GF.L or {}
	local tip = L[tipKey]
	if not tip or tip == "" then
		return
	end
	widget:HookScript("OnEnter", function(self)
		showFilterTip(self, title, tip, placement)
	end)
	widget:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
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
		GameTooltip:Hide()
	end)
end

local function updateFilterCheckButton(cb)
	if GF.UI and GF.UI.UpdateFilterCheckButton then
		GF.UI.UpdateFilterCheckButton(cb)
	end
end

local function addCheckbox(parent, label, y, getter, setter, tipKey)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	row:SetSize(PANEL_W - 32, CHECKBOX_ROW_H)
	local cb = GF.UI.CreateFilterCheckButton(row)
	cb:SetPoint("TOPLEFT", row, "TOPLEFT", FILTER_CHECK_OFFSET_X, -FILTER_CHECK_OFFSET_Y)
	local fs = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", cb, "RIGHT", FILTER_CHECK_LABEL_GAP, 0)
	fs:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	fs:SetJustifyH("LEFT")
	fs:SetMaxLines(1)
	fs:SetWordWrap(false)
	fs:SetText(label)
	cb:SetChecked(isFilterEnabled(getter()))
	applyFilterOptionTextStyle(fs, cb:GetChecked(), not cb.IsEnabled or cb:IsEnabled())
	cb:SetScript("OnClick", function(self)
		setter(toFilterBool(self:GetChecked()))
		updateFilterCheckButton(self)
	end)
	styleFilterOptionRow(row, cb, tipKey, label)
	GF.UI.StyleFilterCheckButton(cb, { label = fs, updateLabel = applyFilterOptionTextStyle })
	attachTip(cb, tipKey, label)
	local sync = parent._gfSync
	if sync then
		sync.checks[#sync.checks + 1] = { cb = cb, getter = getter }
	end
	return y - CHECKBOX_ROW_H
end

local function addCheckboxPair(parent, y, leftLabel, leftGetter, leftSetter, leftTipKey, rightLabel, rightGetter, rightSetter, rightTipKey)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	row:SetSize(PANEL_W - 32, CHECKBOX_ROW_H)
	local cellW = math.floor(((PANEL_W - 32) - FILTER_PAIR_GAP) / 2)

	local function makeCell(index, label, getter, setter, tipKey)
		local cell = CreateFrame("Frame", nil, row)
		cell:SetPoint("TOPLEFT", row, "TOPLEFT", (index - 1) * (cellW + FILTER_PAIR_GAP), 0)
		cell:SetSize(cellW, CHECKBOX_ROW_H)
		local cb = GF.UI.CreateFilterCheckButton(cell)
		cb:SetPoint("TOPLEFT", cell, "TOPLEFT", FILTER_CHECK_OFFSET_X, -FILTER_CHECK_OFFSET_Y)
		local fs = GF.UI.CreateFontString(cell, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", cb, "RIGHT", FILTER_CHECK_LABEL_GAP, 0)
		fs:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
		fs:SetJustifyH("LEFT")
		fs:SetMaxLines(1)
		fs:SetWordWrap(false)
		if GF.UI and GF.UI.SetEllipsisText then
			GF.UI.SetEllipsisText(fs, label, math.max(1, cellW - FILTER_CHECK_OFFSET_X - FILTER_CHECK_SIZE - FILTER_CHECK_LABEL_GAP))
		else
			fs:SetText(label)
		end
		cb:SetChecked(isFilterEnabled(getter()))
		applyFilterOptionTextStyle(fs, cb:GetChecked(), not cb.IsEnabled or cb:IsEnabled())
		cb:SetScript("OnClick", function(self)
			setter(toFilterBool(self:GetChecked()))
			updateFilterCheckButton(self)
		end)
		styleFilterOptionRow(cell, cb, tipKey, label)
		GF.UI.StyleFilterCheckButton(cb, { label = fs, updateLabel = applyFilterOptionTextStyle })
		attachTip(cb, tipKey, label)
		local sync = parent._gfSync
		if sync then
			sync.checks[#sync.checks + 1] = { cb = cb, getter = getter }
		end
	end

	makeCell(1, leftLabel, leftGetter, leftSetter, leftTipKey)
	makeCell(2, rightLabel, rightGetter, rightSetter, rightTipKey)
	return y - CHECKBOX_ROW_H
end

local function addExclusiveClientCheckboxPair(parent, y, client, leftKey, rightKey, leftLabel, rightLabel, leftTipKey, rightTipKey, onSave)
	if client[leftKey] and client[rightKey] then
		client[rightKey] = false
	end
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	row:SetSize(PANEL_W - 32, CHECKBOX_ROW_H)
	local cellW = math.floor(((PANEL_W - 32) - FILTER_PAIR_GAP) / 2)
	local entries = {}

	local function makeCell(index, key, otherKey, label, tipKey)
		local cell = CreateFrame("Frame", nil, row)
		cell:SetPoint("TOPLEFT", row, "TOPLEFT", (index - 1) * (cellW + FILTER_PAIR_GAP), 0)
		cell:SetSize(cellW, CHECKBOX_ROW_H)
		local cb = GF.UI.CreateFilterCheckButton(cell)
		cb:SetPoint("TOPLEFT", cell, "TOPLEFT", FILTER_CHECK_OFFSET_X, -FILTER_CHECK_OFFSET_Y)
		local fs = GF.UI.CreateFontString(cell, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", cb, "RIGHT", FILTER_CHECK_LABEL_GAP, 0)
		fs:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
		fs:SetJustifyH("LEFT")
		fs:SetMaxLines(1)
		fs:SetWordWrap(false)
		if GF.UI and GF.UI.SetEllipsisText then
			GF.UI.SetEllipsisText(fs, label, math.max(1, cellW - FILTER_CHECK_OFFSET_X - FILTER_CHECK_SIZE - FILTER_CHECK_LABEL_GAP))
		else
			fs:SetText(label)
		end
		cb:SetChecked(isFilterEnabled(client[key]))
		applyFilterOptionTextStyle(fs, cb:GetChecked(), not cb.IsEnabled or cb:IsEnabled())
		entries[index] = { cb = cb, key = key }
		cb:SetScript("OnClick", function(self)
			local checked = toFilterBool(self:GetChecked())
			client[key] = checked
			if checked then
				client[otherKey] = false
				local other = entries[index == 1 and 2 or 1]
				if other and other.cb then
					other.cb:SetChecked(false)
				end
			end
			if onSave then
				onSave()
			end
			updateFilterCheckButton(self)
		end)
		styleFilterOptionRow(cell, cb, tipKey, label)
		GF.UI.StyleFilterCheckButton(cb, { label = fs, updateLabel = applyFilterOptionTextStyle })
		attachTip(cb, tipKey, label)
		local sync = parent._gfSync
		if sync then
			sync.checks[#sync.checks + 1] = {
				cb = cb,
				getter = function()
					return client[key]
				end,
			}
		end
	end

	makeCell(1, leftKey, rightKey, leftLabel, leftTipKey)
	makeCell(2, rightKey, leftKey, rightLabel, rightTipKey)
	return y - CHECKBOX_ROW_H
end

local function addRangeRow(parent, label, y, client, enKey, minKey, maxKey, tipKey, onSave)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	row:SetSize(PANEL_W - 32, CHECKBOX_ROW_H)
	local cb = GF.UI.CreateFilterCheckButton(row)
	cb:SetPoint("TOPLEFT", row, "TOPLEFT", FILTER_CHECK_OFFSET_X, -FILTER_CHECK_OFFSET_Y)
	cb:SetChecked(isFilterEnabled(client[enKey]))
	local rangeLabelW = RANGE_INPUT_OFFSET_X - FILTER_CHECK_LABEL_GAP - 4
	local fs = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", cb, "RIGHT", FILTER_CHECK_LABEL_GAP, 0)
	fs:SetWidth(rangeLabelW)
	fs:SetJustifyH("LEFT")
	fs:SetMaxLines(1)
	fs:SetWordWrap(false)
	if GF.UI and GF.UI.SetEllipsisText then
		GF.UI.SetEllipsisText(fs, label, rangeLabelW)
	else
		fs:SetText(label)
	end
	applyFilterOptionTextStyle(fs, cb:GetChecked(), not cb.IsEnabled or cb:IsEnabled())
	local minBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	minBox:SetSize(RANGE_BOX_W, RANGE_BOX_H)
	minBox:SetPoint("LEFT", cb, "RIGHT", RANGE_INPUT_OFFSET_X, 0)
	minBox:SetAutoFocus(false)
	GF.UI.TrackEditBox(minBox, "GameFontHighlightSmall")
	styleFilterNumberBox(minBox)
	minBox:SetNumeric(true)
	minBox:SetMaxLetters(4)
	minBox:SetText(tostring(client[minKey] or 0))
	attachTip(minBox, tipKey, label)
	local dash = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	dash:SetPoint("LEFT", minBox, "RIGHT", 4, 0)
	dash:SetText("-")
	applyFilterTextStyle(dash)
	local maxBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	maxBox:SetSize(RANGE_BOX_W, RANGE_BOX_H)
	maxBox:SetPoint("LEFT", dash, "RIGHT", 4, 0)
	maxBox:SetAutoFocus(false)
	GF.UI.TrackEditBox(maxBox, "GameFontHighlightSmall")
	styleFilterNumberBox(maxBox)
	maxBox:SetNumeric(true)
	maxBox:SetMaxLetters(4)
	maxBox:SetText(tostring(client[maxKey] or 0))
	attachTip(maxBox, tipKey, label)
	local function commit()
		client[enKey] = toFilterBool(cb:GetChecked())
		client[minKey] = tonumber(minBox:GetText()) or 0
		client[maxKey] = tonumber(maxBox:GetText()) or 0
		if onSave then
			onSave()
		end
		updateFilterCheckButton(cb)
	end
	cb:SetScript("OnClick", commit)
	minBox:SetScript("OnEnterPressed", function(b) commit() b:ClearFocus() end)
	minBox:SetScript("OnEditFocusLost", commit)
	maxBox:SetScript("OnEnterPressed", function(b) commit() b:ClearFocus() end)
	maxBox:SetScript("OnEditFocusLost", commit)
	styleFilterOptionRow(row, cb, tipKey, label)
	GF.UI.StyleFilterCheckButton(cb, { label = fs, updateLabel = applyFilterOptionTextStyle })
	attachTip(cb, tipKey, label)
	local sync = parent._gfSync
	if sync then
		sync.ranges[#sync.ranges + 1] = {
			cb = cb,
			minBox = minBox,
			maxBox = maxBox,
			client = client,
			enKey = enKey,
			minKey = minKey,
			maxKey = maxKey,
		}
	end
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
	threshold = normalizeRoleThreshold(threshold)
	if decrementBtn then
		decrementBtn:SetEnabled(threshold > minValue)
	end
	if incrementBtn then
		incrementBtn:SetEnabled(threshold < maxValue)
	end
end

local function refreshRoleThresholdStepButtonIcon(button)
	if not button or not button._gfRoleThresholdIcon then
		return
	end
	local enabled = not button.IsEnabled or button:IsEnabled()
	button._gfRoleThresholdIcon:SetVertexColor(1, 1, 1, enabled and 0.95 or 0.35)
end

local function createRoleThresholdStepButton(parent, direction)
	local size = ROLE_THRESHOLD_BUTTON_SIZE or RANGE_BOX_H
	local button = GF.UI.CreatePanelButton(parent, "", size, true)
	button:SetSize(size, size)
	button:SetText("")
	local fs = button:GetFontString()
	if fs then
		fs:SetText("")
		fs:Hide()
	end
	local icon = button:CreateTexture(nil, "OVERLAY", nil, 2)
	if GF.UI and GF.UI.TrySetAtlas and GF.UI.TrySetAtlas(icon, GF.NAV_FLYOUT_ARROW_ATLAS or "bag-arrow", false) then
		icon:SetSize(GF.NAV_FLYOUT_ARROW_W or 10, GF.NAV_FLYOUT_ARROW_H or 16)
		local offsetX = (ROLE_THRESHOLD_ARROW_CENTER_OFFSET_X or 0) * (direction == "right" and 1 or -1)
		icon:SetPoint("CENTER", button, "CENTER", offsetX, 0)
		icon:SetRotation(direction == "right" and math.pi or 0)
		button._gfRoleThresholdIcon = icon
	else
		icon:Hide()
	end
	button:HookScript("OnEnable", refreshRoleThresholdStepButtonIcon)
	button:HookScript("OnDisable", refreshRoleThresholdStepButtonIcon)
	refreshRoleThresholdStepButtonIcon(button)
	return button
end

local function addRoleThresholdRow(parent, label, y, client, enKey, minKey, maxKey, tipKey, onSave)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", FILTER_ROW_INSET_X, y)
	row:SetSize(PANEL_W - 32, CHECKBOX_ROW_H)
	local cb = GF.UI.CreateFilterCheckButton(row)
	cb:SetPoint("TOPLEFT", row, "TOPLEFT", FILTER_CHECK_OFFSET_X, -FILTER_CHECK_OFFSET_Y)
	cb:SetChecked(isFilterEnabled(client[enKey]))
	local rangeLabelW = getSingleValueLabelWidth()
	local fs = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", cb, "RIGHT", FILTER_CHECK_LABEL_GAP, 0)
	fs:SetWidth(rangeLabelW)
	fs:SetJustifyH("LEFT")
	fs:SetMaxLines(1)
	fs:SetWordWrap(false)
	if GF.UI and GF.UI.SetEllipsisText then
		GF.UI.SetEllipsisText(fs, label, rangeLabelW)
	else
		fs:SetText(label)
	end
	applyFilterOptionTextStyle(fs, cb:GetChecked(), not cb.IsEnabled or cb:IsEnabled())
	local decrementBtn = createRoleThresholdStepButton(row, "left")
	decrementBtn:SetPoint("LEFT", row, "LEFT", getRightColumnControlOffsetX(), 0)
	local thresholdBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	thresholdBox:SetSize(RANGE_BOX_W, RANGE_BOX_H)
	thresholdBox:SetPoint("LEFT", decrementBtn, "RIGHT", ROLE_THRESHOLD_BUTTON_GAP, 0)
	thresholdBox:SetAutoFocus(false)
	GF.UI.TrackEditBox(thresholdBox, "GameFontHighlightSmall")
	styleFilterNumberBox(thresholdBox)
	thresholdBox:SetNumeric(true)
	thresholdBox:SetMaxLetters(1)
	thresholdBox:SetText(tostring(normalizeRoleThreshold(client[minKey])))
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
	local function updateStepButtons(threshold)
		updateRoleThresholdStepButtons(decrementBtn, incrementBtn, threshold)
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
		updateStepButtons(threshold)
		refreshActiveRoleTips()
	end
	local function commit()
		setThreshold(thresholdBox:GetText(), true)
	end
	cb:SetScript("OnClick", commit)
	decrementBtn:SetScript("OnClick", function()
		setThreshold((tonumber(thresholdBox:GetText()) or normalizeRoleThreshold(client[minKey])) - 1, true)
	end)
	incrementBtn:SetScript("OnClick", function()
		setThreshold((tonumber(thresholdBox:GetText()) or normalizeRoleThreshold(client[minKey])) + 1, true)
	end)
	thresholdBox:SetScript("OnEnterPressed", function(b) commit() b:ClearFocus() end)
	thresholdBox:SetScript("OnEditFocusLost", commit)
	styleFilterOptionRow(row, cb, nil, label)
	GF.UI.StyleFilterCheckButton(cb, { label = fs, updateLabel = applyFilterOptionTextStyle })
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
	updateStepButtons(normalizeRoleThreshold(client[minKey]))
	local sync = parent._gfSync
	if sync then
		sync.ranges[#sync.ranges + 1] = {
			cb = cb,
			minBox = thresholdBox,
			client = client,
			enKey = enKey,
			minKey = minKey,
			maxKey = maxKey,
			decrementBtn = decrementBtn,
			incrementBtn = incrementBtn,
			roleThreshold = true,
		}
	end
	return y - CHECKBOX_ROW_H
end

local DIFF_LABELS = { "FILTER_DIFF_NORMAL", "FILTER_DIFF_HEROIC", "FILTER_DIFF_MYTHIC", "FILTER_DIFF_MPLUS" }
local RAID_DIFF_LABELS = { "FILTER_DIFF_NORMAL", "FILTER_DIFF_HEROIC", "FILTER_DIFF_MYTHIC" }
local BLOODLUST_LABELS = {
	[0] = "FILTER_BLOODLUST_NONE",
	[1] = "FILTER_BLOODLUST_BLFIT",
	[2] = "FILTER_BLOODLUST_NEEDSBL",
}
local ROLE_FILTER_MODES = { "all", "any" }
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

local function getDungeonSelectionDifficultyIndex(selection)
	if not selection or selection.categoryID ~= GF.CAT_DUNGEON then
		return nil
	end
	if selection.navKind == "season_dungeon" then
		return nil
	end
	if not selection.activityID then
		return getActivityDifficultyIndex(nil, true)
	end
	return getActivityDifficultyIndex(getActivityInfoForSelection(selection), true)
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

function FP:Init(mainFrame)
	if self.frame then
		return
	end
	self.mainFrame = mainFrame
	local L = GF.L or {}
	self.frame = CreateFrame("Frame", "GroupFinderAddonFilterFrame", UIParent, "SettingsFrameTemplate")
	self.frame:SetSize(PANEL_W, mainFrame:GetHeight())
	self.frame:EnableMouse(true)
	self.frame:SetClampedToScreen(true)
	self.frame:Hide()
	self.frame._gfOnSatelliteFrameLayersApplied = function()
		FP:SyncFrameLevels()
	end
	self.frame:SetScript("OnUpdate", function()
		FP:OnFocusSyncUpdate()
	end)
	GF.UI.InstallSatelliteFrame(self.frame, { levelOffset = 0, raise = false, toplevel = true, followMainRaise = true })
	GF.UI.ApplySettingsFrameChrome(self.frame, L.FILTER_ADVANCED or "Filter")
	self.frame.ClosePanelButton:SetScript("OnClick", function()
		FP:Hide()
	end)
	GF.UI.InstallBodyBackground(self.frame, { layout = "filter", style = "panelBackplate" })
	local contentLevel = self.frame:GetFrameLevel() + 5
	local scrollInsetR = filterScrollInsetR()
	local footerH = GF.FILTER_FOOTER_H or GF.SUBTITLE_H or 42
	local footerInsetL = GF.FILTER_FOOTER_INSET_L or GF.FRAME_BG_INSET_LEFT or 7
	local footerInsetR = GF.FILTER_FOOTER_INSET_R or GF.FRAME_BG_INSET_RIGHT or -2
	local footerInsetB = GF.FILTER_FOOTER_INSET_B or GF.FRAME_BG_INSET_BOTTOM or 3
	self.footer = CreateFrame("Frame", nil, self.frame)
	self.footer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", footerInsetL, footerInsetB)
	self.footer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", footerInsetR, footerInsetB)
	self.footer:SetHeight(footerH)
	self.footer:SetFrameLevel(contentLevel)
	if GF.UI.InstallBrowseControlBarChrome then
		GF.UI.InstallBrowseControlBarChrome(self.footer, {
			backgroundParent = self.footer,
			leftInset = 0,
			rightInset = 0,
			height = GF.BROWSE_CONTROL_BACKGROUND_H or GF.SUBTITLE_HEADER_H or 26,
			topOffset = GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0,
		})
	end
	self.scroll = GF.UI.CreateScrollFrame(self.frame, { rowHeight = GF.FILTER_WHEEL_ROW_H or 28 })
	self.scroll:SetFrameLevel(contentLevel)
	self.scroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, -28)
	self.scroll:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -scrollInsetR, footerH + footerInsetB + filterFooterAtlasTopOffset())
	self.content = CreateFrame("Frame", nil, self.scroll)
	self.content:SetWidth(PANEL_W - 4 - scrollInsetR)
	self.scroll:SetScrollChild(self.content)
	self.scrollBar = GF.UI.AttachMinimalScrollBar(self.scroll, filterScrollBarOffsetX(scrollInsetR), self.frame, true)
	anchorFilterScrollBar(self.scroll, self.scrollBar, filterScrollBarOffsetX(scrollInsetR))
	local buttonOffsetY = GF.FILTER_FOOTER_BUTTON_OFFSET_Y or 12
	local buttonW = GF.PANEL_BUTTON_TWO_CHAR_W or 72
	local buttonGap = GF.FILTER_FOOTER_BUTTON_GAP or 10
	local buttonCenterOffset = math.floor((buttonW + buttonGap) / 2)
	self.refreshBtn = GF.UI.CreatePanelButton(self.footer, L.FILTER_REFRESH or "Search", buttonW, true)
	self.refreshBtn:SetFrameLevel(contentLevel + 8)
	self.refreshBtn:SetPoint("BOTTOM", self.footer, "BOTTOM", -buttonCenterOffset, buttonOffsetY)
	self.refreshBtn:SetScript("OnClick", function()
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		FP:OnRefresh()
	end)
	attachTip(self.refreshBtn, "FILTER_TIP_REFRESH", L.FILTER_REFRESH or "Search", "aboveLeft")
	self:UpdateSearchButtonState()
	self.resetBtn = GF.UI.CreatePanelButton(self.footer, L.FILTER_RESET or "Reset", buttonW, true)
	self.resetBtn:SetFrameLevel(contentLevel + 8)
	self.resetBtn:SetPoint("BOTTOM", self.footer, "BOTTOM", buttonCenterOffset, buttonOffsetY)
	self.resetBtn:SetScript("OnClick", function()
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		FP:OnReset()
	end)
	attachTip(self.resetBtn, "FILTER_TIP_RESET", L.FILTER_RESET or "Reset", "aboveLeft")
	if UISpecialFrames then
		tinsert(UISpecialFrames, self.frame:GetName())
	end
	self:SyncFrameLevels()
end

function FP:GetSelection()
	if GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		return GF.FindGroupTab:GetSelection()
	end
	return GF.MainFrame and GF.MainFrame.selection
end

function FP:GetSpec()
	local sel = self:GetSelection()
	return sel and GF.FilterSpec and GF.FilterSpec:ResolveSpec(sel)
end

function FP:SaveClient()
	local spec = self:GetSpec()
	if not spec then
		return
	end
	GF.Filter:SaveCategoryClientFilters(spec.clientKey, self.client)
	GF.Filter:ApplyClientFilterRefresh()
end

function FP:SaveGlobal()
	GF.Filter:ApplyClientFilterRefresh()
end

function FP:SyncContentValues()
	local parent = self.content
	local sync = parent and parent._gfSync
	if not sync then
		return
	end
	for _, entry in ipairs(sync.checks or {}) do
		if entry.cb and entry.getter then
			entry.cb:SetChecked(entry.getter())
		end
	end
	for _, entry in ipairs(sync.ranges or {}) do
		local client = entry.client
		if entry.cb and client then
			entry.cb:SetChecked(isFilterEnabled(client[entry.enKey]))
		end
		if entry.minBox and client then
			if entry.roleThreshold then
				local threshold = normalizeRoleThreshold(client[entry.minKey])
				entry.minBox:SetText(tostring(threshold))
				updateRoleThresholdStepButtons(entry.decrementBtn, entry.incrementBtn, threshold)
			else
				entry.minBox:SetText(tostring(client[entry.minKey] or 0))
			end
		end
		if entry.maxBox and client then
			entry.maxBox:SetText(tostring(client[entry.maxKey] or 0))
		end
	end
	for _, entry in ipairs(sync.dropdowns or {}) do
		if entry.dd and entry.labelFn then
			setFilterDropdownLabel(entry.dd, entry.labelFn())
		end
	end
end

function FP:ActivateContent(content, spec, key)
	if self.content and self.content ~= content then
		self.content:Hide()
	end
	self.content = content
	self._specKey = key
	self.client = replaceTableContents(content._gfClient, spec and GF.Filter:GetClientFilters(spec.clientKey) or {})
	content._gfClient = self.client
	content:Show()
	self.scroll:SetScrollChild(content)
	self:SyncContentValues()
	GF.UI.UpdateScrollFrame(self.scroll)
end

function FP:BuildContent()
	local L = GF.L or {}
	local parent = self.content
	parent._gfSync = { checks = {}, ranges = {}, dropdowns = {} }
	local y = -8
	local spec = self:GetSpec()
	local db = (spec and GF.Filter and GF.Filter.GetGlobalFilters and GF.Filter:GetGlobalFilters(spec)) or GF.GetDB()
	self.client = spec and GF.Filter:GetClientFilters(spec.clientKey) or {}
	parent._gfClient = self.client
	local listOn = GF.ListFilter and GF.ListFilter:IsEnabled()

	local function saveClient()
		self:SaveClient()
	end

	local function saveGlobal()
		self:SaveGlobal()
	end

	if spec and spec.showDungeonDifficulty then
		y = addSectionTitle(parent, L.FILTER_DIFFICULTY or "Difficulty", y)
		local diffAnyLabel = L.FILTER_SELECT_ALL or L.FILTER_DIFF_ANY or L.FILTER_BLOODLUST_NONE or "无"
		local dd = GF.UI.CreateDropdownButton(parent)
		dd:SetSize(PANEL_W - 40, 26)
		dd:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
		local function currentDungeonDiffIndex()
			return getDungeonSelectionDifficultyIndex(FP:GetSelection())
				or GF.Filter:GetClientDifficultyIndex(FP.client, true)
		end
		local function diffLabel(idx)
			if idx == 0 or not idx then
				return diffAnyLabel
			end
			return L[DIFF_LABELS[idx]] or DIFF_LABELS[idx]
		end
		setFilterDropdownLabel(dd, diffLabel(currentDungeonDiffIndex()))
		parent._gfSync.dropdowns[#parent._gfSync.dropdowns + 1] = {
			dd = dd,
			labelFn = function()
				return diffLabel(currentDungeonDiffIndex())
			end,
		}
		if dd.SetupMenu then
			dd:SetupMenu(function(_, root)
				root:CreateRadio(diffAnyLabel, function() return currentDungeonDiffIndex() == 0 end, function()
					GF.Filter:ApplyDifficultyToClient(self.client, 0, true)
					saveClient()
					FP:RebuildIfNeeded(true)
				end)
				for i = 1, 4 do
					local idx = i
					root:CreateRadio(L[DIFF_LABELS[idx]] or DIFF_LABELS[idx], function() return currentDungeonDiffIndex() == idx end, function()
						GF.Filter:ApplyDifficultyToClient(self.client, idx, true)
						saveClient()
						FP:RebuildIfNeeded(true)
					end)
				end
			end)
		end
		attachTip(dd, "FILTER_TIP_DUNGEON_DIFFICULTY", L.FILTER_DIFFICULTY or "Difficulty")
		y = y - 32
	end

	if spec and spec.showRaidDifficulty then
		y = addSectionTitle(parent, L.FILTER_DIFFICULTY or "Difficulty", y)
		local raidDiffAnyLabel = L.FILTER_SELECT_ALL or L.FILTER_DIFF_ANY or L.FILTER_BLOODLUST_NONE or "无"
		local dd = GF.UI.CreateDropdownButton(parent)
		dd:SetSize(PANEL_W - 40, 26)
		dd:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
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
		setFilterDropdownLabel(dd, raidDiffLabel(currentRaidDiffIndex()))
		parent._gfSync.dropdowns[#parent._gfSync.dropdowns + 1] = {
			dd = dd,
			labelFn = function()
				return raidDiffLabel(currentRaidDiffIndex())
			end,
		}
		if dd.SetupMenu then
			dd:SetupMenu(function(_, root)
				root:CreateRadio(raidDiffAnyLabel, function() return currentRaidDiffIndex() == 0 end, function()
					GF.Filter:ApplyRaidDifficultyToClient(self.client, 0)
					saveClient()
					FP:RebuildIfNeeded(true)
				end)
				for i = 1, 3 do
					local idx = i
					root:CreateRadio(L[RAID_DIFF_LABELS[idx]] or RAID_DIFF_LABELS[idx], function() return currentRaidDiffIndex() == idx end, function()
						GF.Filter:ApplyRaidDifficultyToClient(self.client, idx)
						saveClient()
						FP:RebuildIfNeeded(true)
					end)
				end
			end)
		end
		attachTip(dd, "FILTER_TIP_RAID_DIFFICULTY", L.FILTER_DIFFICULTY or "Difficulty")
		y = y - 32
	end

	if spec and spec.showBloodlust then
		y = addSectionTitle(parent, L.FILTER_BLOODLUST or "Bloodlust", y)
		local blMode = self.client.bloodlustMode or 0
		local dd = GF.UI.CreateDropdownButton(parent)
		dd:SetSize(PANEL_W - 40, 26)
		dd:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
		local function blLabel(m)
			m = m or 0
			local key = BLOODLUST_LABELS[m]
			if not key then
				return "?"
			end
			return L[key] or key
		end
		setFilterDropdownLabel(dd, blLabel(blMode))
		parent._gfSync.dropdowns[#parent._gfSync.dropdowns + 1] = {
			dd = dd,
			labelFn = function()
				return blLabel(FP.client and FP.client.bloodlustMode or 0)
			end,
		}
		if dd.SetupMenu then
			dd:SetupMenu(function(_, root)
				for i = 0, 2 do
					local mode = i
					root:CreateRadio(blLabel(mode), function() return (self.client.bloodlustMode or 0) == mode end, function()
						self.client.bloodlustMode = mode
						saveClient()
						FP:RebuildIfNeeded(true)
					end)
				end
			end)
		end
		attachTip(dd, "FILTER_TIP_BLOODLUST", L.FILTER_BLOODLUST or "Bloodlust")
		y = y - 32
	end

	if spec and (spec.showMatchRole or spec.showNeedsMyClass or spec.showHasTankHeal) then
		y = addSectionTitle(parent, L.FILTER_REQUIRE or "Require", y)
		y = addRoleFilterModeDropdown(parent, y, self.client, saveClient)
		local showMatchRole = spec.showMatchRole
		local showNeedsMyClass = spec.showNeedsMyClass and spec.needsMyClassClient
		if showMatchRole and showNeedsMyClass then
			y = addCheckboxPair(
				parent,
				y,
				L.FILTER_MATCH_ROLE or "Match my role",
				function() return self.client.matchMyRole end,
				function(v)
					self.client.matchMyRole = v
					saveClient()
				end,
				"FILTER_TIP_MATCH_ROLE",
				L.FILTER_NEEDS_CLASS or "Needs my class",
				function() return self.client.needsMyClass end,
				function(v)
					self.client.needsMyClass = v
					saveClient()
				end,
				"FILTER_TIP_NEEDS_CLASS"
			)
		elseif showMatchRole then
			y = addCheckbox(parent, L.FILTER_MATCH_ROLE or "Match my role", y, function() return self.client.matchMyRole end, function(v)
				self.client.matchMyRole = v
				saveClient()
			end, "FILTER_TIP_MATCH_ROLE")
		elseif showNeedsMyClass then
			y = addCheckbox(parent, L.FILTER_NEEDS_CLASS or "Needs my class", y, function() return self.client.needsMyClass end, function(v)
				self.client.needsMyClass = v
				saveClient()
			end, "FILTER_TIP_NEEDS_CLASS")
		end
		if spec.showHasTankHeal and spec.hasTankHealClient then
			y = addExclusiveClientCheckboxPair(
				parent,
				y,
				self.client,
				"hasTank",
				"alreadyHasTank",
				L.FILTER_HAS_TANK or "No tank",
				L.FILTER_ALREADY_HAS_TANK or "Has tank",
				"FILTER_TIP_HAS_TANK",
				"FILTER_TIP_ALREADY_HAS_TANK",
				saveClient
			)
			y = addExclusiveClientCheckboxPair(
				parent,
				y,
				self.client,
				"hasHeal",
				"alreadyHasHeal",
				L.FILTER_HAS_HEAL or "No healer",
				L.FILTER_ALREADY_HAS_HEAL or "Has healer",
				"FILTER_TIP_HAS_HEAL",
				"FILTER_TIP_ALREADY_HAS_HEAL",
				saveClient
			)
		end
	end

	local showRoleRanges = spec and (spec.showTankRange or spec.showHealRange or spec.showDpsRange)
	if showRoleRanges then
		y = addSectionTitle(parent, L.FILTER_RANGES or "Ranges", y)
		if spec.showTankRange then
			y = addRoleThresholdRow(parent, L.FILTER_NEEDS_TANK or "Tank slots", y, self.client, "rangeTankEn", "rangeTankMin", "rangeTankMax", "FILTER_TIP_TANK", saveClient)
		end
		if spec.showHealRange then
			y = addRoleThresholdRow(parent, L.FILTER_NEEDS_HEAL or "Heal slots", y, self.client, "rangeHealEn", "rangeHealMin", "rangeHealMax", "FILTER_TIP_HEAL", saveClient)
		end
		if spec.showDpsRange then
			y = addRoleThresholdRow(parent, L.FILTER_NEEDS_DPS or "DPS slots", y, self.client, "rangeDpsEn", "rangeDpsMin", "rangeDpsMax", "FILTER_TIP_DPS", saveClient)
		end
	end

	if spec and spec.showRaidRoleCounts then
		y = addSectionTitle(parent, L.FILTER_RAID_ROLES or L.FILTER_REQUIRE or "Role Filter", y)
		y = addRoleFilterModeDropdown(parent, y, self.client, saveClient)
		y = addRangeRow(parent, L.LIST_TIP_ROLE_TANK or "Tank", y, self.client, "raidTankEn", "raidTankMin", "raidTankMax", "FILTER_TIP_RAID_TANK", saveClient)
		y = addRangeRow(parent, L.LIST_TIP_ROLE_HEALER or "Healer", y, self.client, "raidHealEn", "raidHealMin", "raidHealMax", "FILTER_TIP_RAID_HEAL", saveClient)
		y = addRangeRow(parent, L.LIST_TIP_ROLE_DPS or "DPS", y, self.client, "raidDpsEn", "raidDpsMin", "raidDpsMax", "FILTER_TIP_RAID_DPS", saveClient)
	end

	local showRaidNumberFilters = spec and (spec.showRaidMemberCount or spec.showRaidBossKills)
	if (spec and spec.showMplusRange) or showRaidNumberFilters or listOn or (spec and spec.layoutTier == "submax") then
		y = addSectionTitle(parent, L.FILTER_THRESHOLDS or "Thresholds", y)
		if spec and spec.showMplusRange then
			y = addRangeRow(parent, L.FILTER_MPLUS_SCORE or "Leader score", y, db, "rangeMplusScoreEn", "rangeMplusScoreMin", "rangeMplusScoreMax", "FILTER_TIP_MPLUS", saveGlobal)
		end
		y = addRangeRow(parent, L.FILTER_MAX_AGE or "Activity age", y, db, "rangeAgeEn", "rangeAgeMin", "rangeAgeMax", "FILTER_TIP_MAX_AGE", saveGlobal)
		y = addRangeRow(parent, L.FILTER_MIN_ILVL or "Req. ilvl", y, db, "rangeIlvlEn", "rangeIlvlMin", "rangeIlvlMax", "FILTER_TIP_MIN_ILVL", saveGlobal)
		if spec and spec.showRaidMemberCount then
			y = addRangeRow(parent, L.FILTER_RAID_MEMBER_COUNT or "Group Size", y, self.client, "raidMemberCountEn", "raidMemberCountMin", "raidMemberCountMax", "FILTER_TIP_RAID_MEMBER_COUNT", saveClient)
		end
		if spec and spec.showRaidBossKills then
			y = addRangeRow(parent, L.FILTER_RAID_BOSS_KILLS or "Boss Kills", y, self.client, "raidBossKillsEn", "raidBossKillsMin", "raidBossKillsMax", "FILTER_TIP_RAID_BOSS_KILLS", saveClient)
		end
		if spec and spec.showMinHonor then
			y = addRangeRow(parent, L.FILTER_MIN_HONOR or "Honor level", y, db, "rangeHonorEn", "rangeHonorMin", "rangeHonorMax", "FILTER_TIP_MIN_HONOR", saveGlobal)
		end
	end

	local showLimits = listOn or (spec and spec.layoutTier == "submax")
	if showLimits or (spec and spec.showNotDeclined) then
		y = addSectionTitle(parent, L.FILTER_LIMITS or "Limits", y)
		if spec and spec.showNotDeclined then
			y = addCheckbox(parent, L.FILTER_NOT_DECLINED or "Not declined", y, function() return self.client.notDeclined end, function(v)
				self.client.notDeclined = v
				saveClient()
			end, "FILTER_TIP_NOT_DECLINED")
		end
		if showLimits then
			if (spec and spec.showSameClass) or (spec and spec.layoutTier == "submax") then
				y = addCheckbox(parent, L.FILTER_SAME_CLASS or "Hide same DPS", y, function() return db.sameClass end, function(v)
					db.sameClass = v
					saveGlobal()
				end, "FILTER_TIP_SAME_CLASS")
			end
			y = addCheckbox(parent, L.FILTER_ZERO_SCORE or "Hide 0 score", y, function() return db.zeroScore end, function(v)
				db.zeroScore = v
				saveGlobal()
			end, "FILTER_TIP_ZERO_SCORE")
			y = addCheckbox(parent, L.FILTER_SAME_FACTION or "Same faction", y, function() return db.sameFactionOnly end, function(v)
				db.sameFactionOnly = v
				saveGlobal()
			end, "FILTER_TIP_SAME_FACTION")
			y = addCheckbox(parent, L.FILTER_HIDE_CROSS_REALM or "Hide cross-realm groups", y, function() return db.hideCrossRealm end, function(v)
				db.hideCrossRealm = v
				saveGlobal()
			end, "FILTER_TIP_HIDE_CROSS_REALM")
			y = addCheckbox(parent, L.FILTER_HIDE_VOICE or "Hide voice", y, function() return db.hideVoice end, function(v)
				db.hideVoice = v
				saveGlobal()
			end, "FILTER_TIP_HIDE_VOICE")
			y = addCheckbox(parent, L.FILTER_SHOW_FRIENDS or "Friend groups", y, function() return db.showFriendGroups == false end, function(v)
				db.showFriendGroups = not v
				saveGlobal()
			end, "FILTER_TIP_SHOW_FRIENDS")
			y = addCheckbox(parent, L.FILTER_SHOW_GUILD or "Guild groups", y, function() return db.showGuildGroups == false end, function(v)
				db.showGuildGroups = not v
				saveGlobal()
			end, "FILTER_TIP_SHOW_GUILD")
		end
	end

	if spec and spec.showDungeonActivities and GF.Filter.GetDungeonActivityItems then
		local isSeasonDungeon = spec.selection and spec.selection.navKind == "season_dungeon"
		local dungeonTitle = isSeasonDungeon
			and (L.FILTER_SEASON_DUNGEONS or L.FILTER_DUNGEONS or "Dungeons")
			or (L.FILTER_DUNGEONS or "Dungeons")
		local dungeonPool = GF.Filter:GetDungeonActivityItems()
		local dungeonOptions = GF.Filter:GetDungeonActivityOptions(dungeonPool)
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
		y = addActivityGroupCheckboxes(parent, y, dungeonTitle, dungeonPool, function(key)
			if GF.Filter:IsAllDungeonGroupsDisabled() then
				return false
			end
			return GF.Filter:IsGroupEnabled(dungeonOptions, key, dungeonPool)
		end, function(key, v)
			GF.Filter:SetDungeonGroupEnabled(dungeonOptions, key, v, dungeonPool)
			saveGlobal()
		end, nil, dungeonTitleAction)
	end

	if spec and spec.showRaidActivities and GF.Filter.GetRaidActivityItems then
		local raidPool = GF.Filter:GetRaidActivityItems()
		local raidOptions = GF.Filter:GetRaidActivityOptions(raidPool)
		local raidTitle = (spec.selection and spec.selection.navKind == "season_raid")
			and (L.FILTER_SEASON_RAIDS or L.FILTER_RAIDS or "Raids")
			or (L.FILTER_RAIDS or "Raids")
		y = addActivityGroupCheckboxes(parent, y, raidTitle, raidPool, function(key)
			if GF.Filter:IsAllRaidGroupsDisabled() then
				return false
			end
			return GF.Filter:IsGroupEnabled(raidOptions, key, raidPool)
		end, function(key, v)
			GF.Filter:SetRaidGroupEnabled(raidOptions, key, v, raidPool)
			saveGlobal()
		end)
	end

	if showLimits then
		y = y - 6
		y = addSectionTitle(parent, L.FILTER_PLAYSTYLE or "Playstyle", y)
		for i = 1, 4 do
			local idx = i
			y = addCheckbox(parent, GF.Filter:GetPlaystyleFilterLabel(idx), y, function()
				return db["playstyle" .. idx] ~= false
			end, function(v)
				db["playstyle" .. idx] = v and true or false
				saveGlobal()
			end)
		end
	end

	if spec and spec.showWarmode then
		y = addSectionTitle(parent, L.FILTER_CLIENT or "Display filters", y)
		y = addCheckbox(parent, L.FILTER_WARMODE or "War Mode only", y, function() return self.client.warmodeOnly end, function(v)
			self.client.warmodeOnly = v
			saveClient()
		end, "FILTER_TIP_WARMODE")
	end

	self.content:SetHeight(math.max(-y + 8, 80))
	GF.UI.UpdateScrollFrame(self.scroll)
end

function FP:SpecKey(spec)
	if not spec then
		return ""
	end
	return string.format(
		"%s:%s:%s:%s",
		spec.clientKey or "",
		spec.layoutTier or "",
		spec.navColumn or 0,
		(spec.selection and spec.selection.navKind) or ""
	)
end

function FP:RebuildIfNeeded(force)
	if not self.scroll then
		return
	end
	local spec = self:GetSpec()
	local key = self:SpecKey(spec)
	if not force and self._specKey == key and self.content then
		self.client = replaceTableContents(self.content._gfClient or self.client, spec and GF.Filter:GetClientFilters(spec.clientKey) or {})
		self.content._gfClient = self.client
		self:SyncContentValues()
		return
	end
	if force then
		self._contentCache = nil
	elseif self._contentCache and self._contentCache[key] then
		self:ActivateContent(self._contentCache[key], spec, key)
		return
	end
	if self.content then
		self.content:Hide()
	end
	self.content = CreateFrame("Frame", nil, self.scroll)
	self.content:SetWidth(PANEL_W - 4 - filterScrollInsetR())
	self.scroll:SetScrollChild(self.content)
	self._specKey = key
	self:BuildContent()
	if not self._contentCache then
		self._contentCache = {}
	end
	self._contentCache[key] = self.content
end

function FP:OnReset()
	local sel = self:GetSelection()
	if sel then
		GF.Filter:ResetCategory(sel)
	end
	self._contentCache = nil
	self:RebuildIfNeeded(true)
	GF.Filter:ApplyClientFilterRefresh()
end

function FP:OnRefresh()
	if GF.FindGroupTab then
		GF.FindGroupTab:DoSearch()
	end
	self:UpdateSearchButtonState()
end

function FP:UpdateSearchButtonState(searching)
	if not self.refreshBtn then
		return
	end
	local L = GF.L or {}
	local remain = 0
	if GF.FindGroupTab and GF.FindGroupTab.GetSearchCooldownRemaining then
		remain = GF.FindGroupTab:GetSearchCooldownRemaining()
	end
	searching = searching or GF.searching
	local bp = GF.FindGroupTab and GF.FindGroupTab.GetPanel and GF.FindGroupTab:GetPanel()
	if bp and bp.IsSearchPending then
		searching = searching or bp:IsSearchPending()
	end
	self.refreshBtn:SetText(L.FILTER_REFRESH or "Search")
	if searching or remain > 0 then
		if GF.UI and GF.UI.SetButtonPendingSpinner then
			GF.UI.SetButtonPendingSpinner(self.refreshBtn, true, GF.SEARCH_BUTTON_PENDING_SPINNER_SIZE or 18)
		end
		self.refreshBtn:SetEnabled(false)
		return
	end
	if GF.UI and GF.UI.SetButtonPendingSpinner then
		GF.UI.SetButtonPendingSpinner(self.refreshBtn, false)
	end
	local searchable = true
	if GF.FindGroupTab and GF.FindGroupTab.IsSearchableSelection then
		searchable = GF.FindGroupTab:IsSearchableSelection(self:GetSelection()) ~= false
	end
	self.refreshBtn:SetEnabled(searchable)
end

function FP:AnchorToMain()
	if not self.frame or not self.mainFrame then
		return
	end
	self.frame:SetHeight(self.mainFrame:GetHeight())
	self.frame:ClearAllPoints()
	self.frame:SetPoint("TOPLEFT", self.mainFrame, "TOPRIGHT", 2, 0)
	self.frame:SetPoint("BOTTOMLEFT", self.mainFrame, "BOTTOMRIGHT", 2, 0)
	if GF.UI and GF.UI.ApplySatelliteFrameLayers then
		GF.UI.ApplySatelliteFrameLayers()
	end
end

function FP:Toggle()
	self:Init(self.mainFrame)
	if self.frame:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

function FP:Show()
	self:Init(self.mainFrame)
	local wasShown = self.frame:IsShown()
	self:AnchorToMain()
	self:RebuildIfNeeded(false)
	if GF.UI and GF.UI.ApplyBodyBackground then
		GF.UI.ApplyBodyBackground(self.frame)
	end
	self.frame:Show()
	if not wasShown and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("open")
	end
end

function FP:Hide()
	if self.frame then
		local wasShown = self.frame:IsShown()
		self.frame:Hide()
		if wasShown and GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("close")
		end
	end
end

function FP:IsShown()
	return self.frame and self.frame:IsShown()
end
