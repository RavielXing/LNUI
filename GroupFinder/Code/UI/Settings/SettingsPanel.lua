local _, GF = ...



GF.SettingsPanel = {}

local SP = GF.SettingsPanel

local settingsRefreshers = {}

local function registerSettingsRefresher(fn)
	settingsRefreshers[#settingsRefreshers + 1] = fn
end

local RESET_POPUP = "GF_RESET_ALL_SETTINGS"



local COL_W = GF.SETTINGS_COL_W or 280
local SCROLL_INSET_L = GF.SETTINGS_LAYOUT_INSET_L or 0
local SETTINGS_SCROLLBAR_WIDTH = 17
local SETTINGS_SCROLLBAR_GAP = 2
local SETTINGS_SCROLLBAR_RIGHT_INSET = 10
local SETTINGS_SCROLLBAR_TOP_INSET = 8
local SETTINGS_SCROLLBAR_BOTTOM_INSET = 8
local SCROLL_INSET_R = SETTINGS_SCROLLBAR_WIDTH + SETTINGS_SCROLLBAR_GAP + SETTINGS_SCROLLBAR_RIGHT_INSET

local function getSettingsLayoutWidth(self)
	if self.container then
		local cw = self.container:GetWidth()
		if cw and cw > 0 then
			return cw
		end
	end
	if self.parent then
		local pw = self.parent:GetWidth()
		if pw and pw > 0 then
			return pw
		end
	end
	return self.scroll and self.scroll:GetWidth() or 0
end



local DD_W = GF.SETTINGS_DROPDOWN_W or 260
local DD_H = GF.SETTINGS_DROPDOWN_H or 26
local APPLY_DROPDOWN_W = DD_W
local SLIDER_H = GF.SETTINGS_SLIDER_H or 19
local SETTINGS_INPUT_ATLAS_TEXTURE = GF.FILTER_CHECK_ATLAS_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\FilterCheckAtlas.png"
local SETTINGS_INPUT_ATLAS_INSET_X = GF.FILTER_CHECK_ATLAS_INSET_X or (0.5 / 128)
local SETTINGS_INPUT_ATLAS_INSET_Y = GF.FILTER_CHECK_ATLAS_INSET_Y or (0.5 / 64)
local SETTINGS_INPUT_ATLAS_COORDS = {
	checked = { SETTINGS_INPUT_ATLAS_INSET_X, 0.5 - SETTINGS_INPUT_ATLAS_INSET_X, SETTINGS_INPUT_ATLAS_INSET_Y, 1 - SETTINGS_INPUT_ATLAS_INSET_Y },
	normal = { 0.5 + SETTINGS_INPUT_ATLAS_INSET_X, 1 - SETTINGS_INPUT_ATLAS_INSET_X, SETTINGS_INPUT_ATLAS_INSET_Y, 1 - SETTINGS_INPUT_ATLAS_INSET_Y },
}
SETTINGS_INPUT_ATLAS_COORDS.hover = SETTINGS_INPUT_ATLAS_COORDS.checked
local SETTINGS_INPUT_COORDS = {
	hover = SETTINGS_INPUT_ATLAS_COORDS.checked,
	normal = SETTINGS_INPUT_ATLAS_COORDS.normal,
}
local SETTINGS_INPUT_CAP_W = 9
local SETTINGS_INPUT_LEFT_RATIO = 0.45
local SETTINGS_INPUT_RIGHT_RATIO = 0.55
local NUMBER_BOX_W = 44
local NUMBER_BOX_H = 20
local OPTIONS_CONTENT_TOP_OFFSET = 20
local OPTIONS_CONTENT_BOTTOM_PADDING = 20
local OPTIONS_TITLE_H = 40
local OPTIONS_TITLE_TO_CONTROLS_GAP = 14
local OPTIONS_SECTION_GAP = 16
local OPTIONS_SECTION_BODY_INSET_X = 24
local OPTIONS_SECTION_TITLE_TEXT_INSET_X = 24
local OPTIONS_LABEL_TEXT_SIZE = GF.SECTION_HEADER_TEXT_SIZE or 14
local OPTIONS_ROW_HEIGHT = 28
local OPTIONS_CHECK_BUTTON_SIZE = 20
local OPTIONS_CONTROL_COLUMN_X = 270
local OPTIONS_PANEL_ROW_H = 40
local OPTIONS_PANEL_LABEL_INSET_X = 28
local OPTIONS_PANEL_CONTROL_INSET_X = 34
local OPTIONS_ACTION_BUTTON_RIGHT_INSET = 16
local OPTIONS_SECTION_BODY_INSET_R = OPTIONS_SECTION_BODY_INSET_X + OPTIONS_ACTION_BUTTON_RIGHT_INSET
local OPTIONS_PANEL_EDGE_INSET = 3
local OPTIONS_TITLE_LEFT_FADE_W = 36
local OPTIONS_TITLE_LEFT_FADE_ALPHA = 0.35
local OPTIONS_VISUAL_SLIDER_W = 520
local OPTIONS_VISUAL_GROUP_GAP = 10
local OPTIONS_VISUAL_GROUP_INSET_X = 0
local OPTIONS_VISUAL_GROUP_HEADER_H = 30
local OPTIONS_VISUAL_GROUP_BODY_INSET_X = 8
local OPTIONS_VISUAL_GROUP_PADDING_BOTTOM = 6
local SECTION_GAP = OPTIONS_SECTION_GAP
local SECTION_TITLE_H = OPTIONS_TITLE_H
local SECTION_ROW_H = OPTIONS_PANEL_ROW_H
local SECTION_LABEL_X = OPTIONS_PANEL_LABEL_INSET_X
local SECTION_LABEL_W = OPTIONS_CONTROL_COLUMN_X - OPTIONS_PANEL_LABEL_INSET_X - 16
local SECTION_CONTROL_X = OPTIONS_CONTROL_COLUMN_X + OPTIONS_PANEL_CONTROL_INSET_X
local SECTION_CONTROL_INSET_R = OPTIONS_ACTION_BUTTON_RIGHT_INSET

local function createSettingsDropdown(parent)
	return GF.UI.CreateDropdownButton(parent)
end

local function setTextureColor(texture, r, g, b, a)
	if not texture then
		return
	end
	if texture.SetColorTexture then
		texture:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
	else
		texture:SetTexture("Interface\\Buttons\\WHITE8X8")
		texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
end

local function hideSettingsInputRegion(region)
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

local function hideSettingsInputBoxChrome(editBox)
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
			hideSettingsInputRegion(region)
		end
	end
	hideSettingsInputRegion(editBox.Left)
	hideSettingsInputRegion(editBox.Middle)
	hideSettingsInputRegion(editBox.Right)
	hideSettingsInputRegion(editBox.LeftTexture)
	hideSettingsInputRegion(editBox.MiddleTexture)
	hideSettingsInputRegion(editBox.RightTexture)
end

local function snapSettingsInputTexture(texture)
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

local function updateSettingsNumberBox(box)
	if not box or not box._gfSettingsInputStyled then
		return
	end
	local active = box:HasFocus() or box._gfSettingsInputHovered
	local coords = active and SETTINGS_INPUT_COORDS.hover or SETTINGS_INPUT_COORDS.normal
	local pieces = box._gfSettingsInputAtlas
	if pieces then
		local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
		local width = right - left
		local leftU = left + width * SETTINGS_INPUT_LEFT_RATIO
		local rightU = left + width * SETTINGS_INPUT_RIGHT_RATIO
		pieces.left:SetTexCoord(left, leftU, top, bottom)
		pieces.middle:SetTexCoord(leftU, rightU, top, bottom)
		pieces.right:SetTexCoord(rightU, right, top, bottom)
		pieces.left:SetVertexColor(1, 1, 1, 1)
		pieces.middle:SetVertexColor(1, 1, 1, 1)
		pieces.right:SetVertexColor(1, 1, 1, 1)
	end
end

local activeSettingsNumberBox
local settingsNumberBoxes = setmetatable({}, { __mode = "k" })

local function clearSettingsNumberSelection(box)
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

local function selectAllSettingsNumberText(box)
	if box and box.HighlightText then
		box:HighlightText()
	end
end

local function clearOtherSettingsNumberFocus(box)
	for other in pairs(settingsNumberBoxes) do
		if other ~= box then
			if other.ClearFocus and (not other.HasFocus or other:HasFocus()) then
				other:ClearFocus()
			end
			clearSettingsNumberSelection(other)
			updateSettingsNumberBox(other)
		end
	end
end

local function scheduleSettingsNumberSelectAll(box)
	if not C_Timer or not C_Timer.After then
		selectAllSettingsNumberText(box)
		return
	end
	C_Timer.After(0, function()
		if box and box.HasFocus and box:HasFocus() then
			selectAllSettingsNumberText(box)
			updateSettingsNumberBox(box)
		end
	end)
end

local function activateSettingsNumberBox(box)
	if not box then
		return
	end
	clearOtherSettingsNumberFocus(box)
	activeSettingsNumberBox = box
	selectAllSettingsNumberText(box)
	updateSettingsNumberBox(box)
	scheduleSettingsNumberSelectAll(box)
end

local function deactivateSettingsNumberBox(box)
	if activeSettingsNumberBox == box then
		activeSettingsNumberBox = nil
	end
	clearSettingsNumberSelection(box)
	updateSettingsNumberBox(box)
end

local function setSettingsNumberHovered(box, hovered)
	if not box then
		return
	end
	box._gfSettingsInputHovered = hovered
	updateSettingsNumberBox(box)
end

local function styleSettingsNumberBox(box, width, height)
	if not box then
		return box
	end
	box:SetSize(width or NUMBER_BOX_W, height or NUMBER_BOX_H)
	box:SetJustifyH("CENTER")
	if box.SetTextInsets then
		box:SetTextInsets(2, 2, 0, 0)
	end
	box:SetTextColor(1, 0.92, 0.64, 1)
	box:SetShadowColor(0, 0, 0, 0.85)
	box:SetShadowOffset(1, -1)
	hideSettingsInputBoxChrome(box)

	if not box._gfSettingsInputStyled then
		settingsNumberBoxes[box] = true

		local left = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		left:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
		left:SetWidth(SETTINGS_INPUT_CAP_W)
		left:SetTexture(SETTINGS_INPUT_ATLAS_TEXTURE)
		snapSettingsInputTexture(left)

		local right = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
		right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
		right:SetWidth(SETTINGS_INPUT_CAP_W)
		right:SetTexture(SETTINGS_INPUT_ATLAS_TEXTURE)
		snapSettingsInputTexture(right)

		local middle = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
		middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
		middle:SetTexture(SETTINGS_INPUT_ATLAS_TEXTURE)
		snapSettingsInputTexture(middle)

		box._gfSettingsInputAtlas = {
			left = left,
			middle = middle,
			right = right,
		}

		box:HookScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				activateSettingsNumberBox(self)
			end
		end)
		box:HookScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then
				selectAllSettingsNumberText(self)
				updateSettingsNumberBox(self)
				scheduleSettingsNumberSelectAll(self)
			end
		end)
		box:HookScript("OnEditFocusGained", activateSettingsNumberBox)
		box:HookScript("OnEditFocusLost", deactivateSettingsNumberBox)
		box:HookScript("OnShow", updateSettingsNumberBox)
		box:HookScript("OnHide", deactivateSettingsNumberBox)
		box:HookScript("OnEnter", function(self)
			setSettingsNumberHovered(self, true)
		end)
		box:HookScript("OnLeave", function(self)
			setSettingsNumberHovered(self, false)
		end)
		box._gfSettingsInputStyled = true
	end

	updateSettingsNumberBox(box)
	return box
end

local function applyHorizontalGradient(texture, topA, bottomA)
	if not texture then
		return
	end
	texture:SetTexture("Interface\\Buttons\\WHITE8X8")
	if texture.SetGradientAlpha then
		local ok = pcall(texture.SetGradientAlpha, texture, "VERTICAL", 0.22, 0.08, 0.02, topA or 0.82, 0.03, 0.012, 0.004, bottomA or 0.9)
		if ok then
			return
		end
	end
	texture:SetVertexColor(0.15, 0.055, 0.015, bottomA or 0.9)
end

local function applyHorizontalBlackMask(texture, leftA, rightA)
	if not texture then
		return
	end
	texture:SetTexture("Interface\\Buttons\\WHITE8X8")
	if texture.SetGradientAlpha then
		local ok = pcall(texture.SetGradientAlpha, texture, "HORIZONTAL", 0, 0, 0, leftA or 0.96, 0, 0, 0, rightA or 0)
		if ok then
			return
		end
	end
	texture:SetVertexColor(0, 0, 0, leftA or 0.45)
end

local function styleSettingsLabel(label, template)
	if not label then
		return
	end
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(label, template or "GameFontNormal")
	end
end

local function createOptionsPanelRule(parent, layer)
	local rule = parent:CreateTexture(nil, layer or "ARTWORK")
	setTextureColor(rule, 0.72, 0.52, 0.22, 0.16)
	return rule
end

local function applyOptionsFeaturePanelStyle(frame)
	if not frame then
		return
	end
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			edgeSize = 12,
			insets = {
				left = OPTIONS_PANEL_EDGE_INSET,
				right = OPTIONS_PANEL_EDGE_INSET,
				top = OPTIONS_PANEL_EDGE_INSET,
				bottom = OPTIONS_PANEL_EDGE_INSET,
			},
		})
		frame:SetBackdropColor(0.03, 0.02, 0.01, 0.30)
		frame:SetBackdropBorderColor(0.55, 0.43, 0.18, 0.75)
		return
	end

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	setTextureColor(bg, 0.03, 0.02, 0.01, 0.30)
end

local function updateSettingsSectionHeights(section)
	if not section then
		return
	end
	local rowOffset = section._gfRowOffset or 0
	if section.panel then
		section.panel:SetHeight(math.max(rowOffset, 1))
	end
	local baseH = section._gfHeightBase
	if baseH == nil then
		baseH = OPTIONS_TITLE_H + OPTIONS_TITLE_TO_CONTROLS_GAP
	end
	section:SetHeight(baseH + rowOffset + (section._gfHeightPaddingBottom or 0))
end

local function applyVisualGroupPanelStyle(frame)
	if not frame then
		return
	end
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			edgeSize = 10,
			insets = {
				left = 2,
				right = 2,
				top = 2,
				bottom = 2,
			},
		})
		frame:SetBackdropColor(0.015, 0.012, 0.008, 0.46)
		frame:SetBackdropBorderColor(0.55, 0.43, 0.18, 0.75)
	end
end

local function createSettingsSection(parent, label, y)
	local section = CreateFrame("Frame", nil, parent)
	section._gfSettingsSection = true
	section._gfRowOffset = 0
	section._gfRowCount = 0
	section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	section:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)

	local title = CreateFrame("Frame", nil, section)
	title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
	title:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
	title:SetHeight(OPTIONS_TITLE_H)

	local titleBgHost = CreateFrame("Frame", nil, title)
	titleBgHost:SetAllPoints(title)

	local titleBg = titleBgHost:CreateTexture(nil, "BACKGROUND", nil, 1)
	titleBg:SetAllPoints(titleBgHost)
	local hasTitleAtlas = GF.UI and GF.UI.TrySetAtlas and GF.UI.TrySetAtlas(titleBg, GF.BROWSE_HEADER_BACKGROUND_ATLAS or "housefinder_header-bg-gradient", false)
	if hasTitleAtlas then
		titleBg:SetVertexColor(1, 1, 1, 1)
	else
		setTextureColor(titleBg, 0, 0, 0, 0.45)
	end

	local leftFade = title:CreateTexture(nil, "ARTWORK", nil, 1)
	leftFade:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 0)
	leftFade:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", 0, 0)
	leftFade:SetWidth(OPTIONS_TITLE_LEFT_FADE_W)
	applyHorizontalBlackMask(leftFade, OPTIONS_TITLE_LEFT_FADE_ALPHA, 0)
	leftFade:Hide()

	local titleText = GF.UI.CreateFontString(title, "OVERLAY", "GameFontNormal")
	titleText._gfFontSizeOverride = OPTIONS_LABEL_TEXT_SIZE
	titleText._gfFontFlagsOverride = "OUTLINE"
	styleSettingsLabel(titleText, "GameFontNormal")
	titleText:SetTextColor(1, 0.82, 0, 1)
	titleText:SetPoint("TOPLEFT", title, "TOPLEFT", OPTIONS_SECTION_TITLE_TEXT_INSET_X, 0)
	titleText:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", -OPTIONS_SECTION_TITLE_TEXT_INSET_X, 0)
	titleText:SetJustifyH("LEFT")
	titleText:SetJustifyV("MIDDLE")
	titleText:SetText(label or "")

	local panel = CreateFrame("Frame", nil, section, "BackdropTemplate")
	panel:SetPoint("TOPLEFT", section, "TOPLEFT", OPTIONS_SECTION_BODY_INSET_X, -(OPTIONS_TITLE_H + OPTIONS_TITLE_TO_CONTROLS_GAP))
	panel:SetPoint("TOPRIGHT", section, "TOPRIGHT", -OPTIONS_SECTION_BODY_INSET_R, -(OPTIONS_TITLE_H + OPTIONS_TITLE_TO_CONTROLS_GAP))
	panel:SetHeight(1)
	applyOptionsFeaturePanelStyle(panel)

	local columnDivider = createOptionsPanelRule(panel)
	columnDivider:SetPoint("TOPLEFT", panel, "TOPLEFT", OPTIONS_CONTROL_COLUMN_X, -1)
	columnDivider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", OPTIONS_CONTROL_COLUMN_X, 1)
	columnDivider:SetWidth(1)
	panel.columnDivider = columnDivider

	section.title = title
	section.titleBgHost = titleBgHost
	section.titleBg = titleBg
	section.titleLeftFade = leftFade
	section.titleText = titleText
	section.panel = panel
	return section
end

local function finishSettingsSection(section, y)
	local rowsHeight = section and section._gfRowOffset or 0
	local baseH = section and section._gfHeightBase
	if baseH == nil then
		baseH = OPTIONS_TITLE_H + OPTIONS_TITLE_TO_CONTROLS_GAP
	end
	local h = baseH + math.max(rowsHeight, 0) + ((section and section._gfHeightPaddingBottom) or 0)
	if section then
		section:SetHeight(h)
		if section.panel then
			section.panel:SetHeight(math.max(rowsHeight, 1))
		end
	end
	return y - h - SECTION_GAP
end

local function addSettingsRow(section, labelText, tooltip, opts)
	opts = opts or {}
	local rowH = opts.height or SECTION_ROW_H
	local offset = section._gfRowOffset or 0
	local rowIndex = (section._gfRowCount or 0) + 1
	local panel = section.panel or section
	local row = CreateFrame("Frame", nil, panel)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
	row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
	row:SetHeight(rowH)

	local rowBackground = row:CreateTexture(nil, "BACKGROUND", nil, -1)
	rowBackground:SetAllPoints(row)
	setTextureColor(rowBackground, 1, 0.82, 0, rowIndex % 2 == 1 and 0.018 or 0.008)

	if rowIndex > 1 then
		local rule = createOptionsPanelRule(row)
		rule:SetPoint("TOPLEFT", row, "TOPLEFT", 16, 0)
		rule:SetPoint("TOPRIGHT", row, "TOPRIGHT", -16, 0)
		rule:SetHeight(1)
		row.topRule = rule
	end

	local labelIndent = opts.labelIndent or 0
	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", row, "LEFT", SECTION_LABEL_X + labelIndent, 0)
	label:SetSize(math.max(20, SECTION_LABEL_W - labelIndent), OPTIONS_ROW_HEIGHT)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	label:SetWordWrap(false)
	label:SetText(labelText or "")
	label._gfFontSizeOverride = GF.SECTION_HEADER_TEXT_SIZE or 14
	if label.SetTextColor then
		label:SetTextColor(0.92, 0.90, 0.84, 1)
	end
	styleSettingsLabel(label, "GameFontHighlight")

	local control = CreateFrame("Frame", nil, row)
	control:SetPoint("LEFT", row, "LEFT", SECTION_CONTROL_X, 0)
	control:SetPoint("RIGHT", row, "RIGHT", -SECTION_CONTROL_INSET_R, 0)
	control:SetHeight(rowH)

	row.label = label
	row.control = control
	section._gfRowOffset = offset + rowH
	section._gfRowCount = rowIndex
	updateSettingsSectionHeights(section)
	return row, control, label
end

local function styleVisualAppearancePanel(section)
	local panel = section and section.panel
	if not panel then
		return
	end
	if panel.SetBackdrop then
		panel:SetBackdrop(nil)
	end
	if panel.columnDivider then
		panel.columnDivider:Hide()
	end
end

local function createVisualSettingsGroup(section, labelText)
	local offset = section._gfRowOffset or 0
	local panel = section.panel or section
	local group = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	group._gfRowOffset = 0
	group._gfRowCount = 0
	group._gfHeightBase = OPTIONS_VISUAL_GROUP_HEADER_H
	group._gfHeightPaddingBottom = OPTIONS_VISUAL_GROUP_PADDING_BOTTOM
	group:SetPoint("TOPLEFT", panel, "TOPLEFT", OPTIONS_VISUAL_GROUP_INSET_X, -offset)
	group:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -OPTIONS_VISUAL_GROUP_INSET_X, -offset)
	group:SetHeight(1)
	applyVisualGroupPanelStyle(group)

	local header = CreateFrame("Frame", nil, group)
	header:SetPoint("TOPLEFT", group, "TOPLEFT", 2, -2)
	header:SetPoint("TOPRIGHT", group, "TOPRIGHT", -2, -2)
	header:SetHeight(OPTIONS_VISUAL_GROUP_HEADER_H - 2)
	group.header = header

	local headerBg = header:CreateTexture(nil, "BACKGROUND", nil, -1)
	headerBg:SetAllPoints(header)
	setTextureColor(headerBg, 1, 0.82, 0, 0.035)
	group.headerBg = headerBg

	local accent = header:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("LEFT", header, "LEFT", 12, 0)
	accent:SetSize(2, 14)
	setTextureColor(accent, 1, 0.82, 0, 0.78)
	group.accent = accent

	local title = GF.UI.CreateFontString(header, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", accent, "RIGHT", 8, 0)
	title:SetPoint("RIGHT", header, "RIGHT", -12, 0)
	title:SetHeight(OPTIONS_ROW_HEIGHT)
	title:SetJustifyH("LEFT")
	title:SetJustifyV("MIDDLE")
	title:SetWordWrap(false)
	title:SetText(labelText or "")
	title._gfFontSizeOverride = GF.SECTION_HEADER_TEXT_SIZE or 14
	title._gfFontFlagsOverride = "OUTLINE"
	title:SetTextColor(1, 0.82, 0, 1)
	styleSettingsLabel(title, "GameFontNormal")
	group.title = title

	local headerRule = createOptionsPanelRule(header)
	headerRule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 10, 0)
	headerRule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 0)
	headerRule:SetHeight(1)
	group.headerRule = headerRule

	local body = CreateFrame("Frame", nil, group)
	body:SetPoint("TOPLEFT", group, "TOPLEFT", OPTIONS_VISUAL_GROUP_BODY_INSET_X, -OPTIONS_VISUAL_GROUP_HEADER_H)
	body:SetPoint("TOPRIGHT", group, "TOPRIGHT", -OPTIONS_VISUAL_GROUP_BODY_INSET_X, -OPTIONS_VISUAL_GROUP_HEADER_H)
	body:SetHeight(1)
	group.panel = body
	return group
end

local function finishVisualSettingsGroup(section, group, trailingGap)
	if not section or not group then
		return
	end
	updateSettingsSectionHeights(group)
	local groupH = (group._gfHeightBase or 0) + (group._gfRowOffset or 0) + (group._gfHeightPaddingBottom or 0)
	section._gfRowOffset = (section._gfRowOffset or 0) + groupH + (trailingGap or 0)
	section._gfRowCount = (section._gfRowCount or 0) + 1
	updateSettingsSectionHeights(section)
end

local function bindSettingsControlTooltip(control, tooltip)
	if not control or not tooltip or tooltip == "" then
		return
	end
	if control.HookScript then
		control:HookScript("OnEnter", function(owner)
			GF.UI.ShowSimpleTooltip(owner, tooltip, "ANCHOR_RIGHT")
		end)
		control:HookScript("OnLeave", GameTooltip_Hide)
	elseif control.SetScript then
		control:SetScript("OnEnter", function(owner)
			GF.UI.ShowSimpleTooltip(owner, tooltip, "ANCHOR_RIGHT")
		end)
		control:SetScript("OnLeave", GameTooltip_Hide)
	end
end

local function skinSettingsCheckButton(button)
	if not button then
		return
	end
	if GF.UI and GF.UI.StyleFilterCheckButton then
		GF.UI.StyleFilterCheckButton(button, { size = OPTIONS_CHECK_BUTTON_SIZE })
	else
		button:SetSize(OPTIONS_CHECK_BUTTON_SIZE, OPTIONS_CHECK_BUTTON_SIZE)
	end
end

local function createSettingsCheckButton(parent)
	if GF.UI and GF.UI.CreateFilterCheckButton then
		return GF.UI.CreateFilterCheckButton(parent, { size = OPTIONS_CHECK_BUTTON_SIZE })
	end
	local cb = CreateFrame("CheckButton", nil, parent)
	skinSettingsCheckButton(cb)
	return cb
end

local function getCheckButtonBool(button)
	return button and button:GetChecked() and true or false
end

local function updateSettingsCheckButton(button)
	if GF.UI and GF.UI.UpdateFilterCheckButton then
		GF.UI.UpdateFilterCheckButton(button)
	end
end

local function setSettingsCheckButtonHovered(button, hovered)
	if GF.UI and GF.UI.SetFilterCheckButtonHovered then
		GF.UI.SetFilterCheckButtonHovered(button, hovered)
	else
		updateSettingsCheckButton(button)
	end
end

local function bindSettingsCheckButtonTooltip(button, enabledTip, disabledTip)
	button:SetScript("OnEnter", function(owner)
		setSettingsCheckButtonHovered(owner, true)
		local tipText = enabledTip
		if owner.IsEnabled and not owner:IsEnabled() then
			tipText = disabledTip or enabledTip
		end
		if tipText and tipText ~= "" then
			GF.UI.ShowSimpleTooltip(owner, tipText, "ANCHOR_RIGHT")
		end
	end)
	button:SetScript("OnLeave", function(owner)
		setSettingsCheckButtonHovered(owner, false)
		GameTooltip_Hide()
	end)
end

local function anchorSettingsControl(control, widget, opts)
	if not control or not widget then
		return
	end
	opts = opts or {}
	widget:ClearAllPoints()
	if opts.controlAnchor == "right" then
		widget:SetPoint("RIGHT", control, "RIGHT", -(opts.controlRightOffset or 0), 0)
	else
		widget:SetPoint("LEFT", control, "LEFT", opts.controlIndent or 0, 0)
	end
end

local function addCheckRow(section, label, tooltip, getter, setter, opts)
	opts = opts or {}
	local row, control, labelFs = addSettingsRow(section, label, tooltip, opts)
	local cb = createSettingsCheckButton(control)
	anchorSettingsControl(control, cb, opts)
	cb:SetChecked(getter())
	cb:SetMotionScriptsWhileDisabled(true)
	cb:SetScript("OnClick", function(self)
		if not self:IsEnabled() then
			return
		end
		setter(getCheckButtonBool(self))
		updateSettingsCheckButton(self)
	end)
	bindSettingsCheckButtonTooltip(cb, tooltip)
	registerSettingsRefresher(function()
		cb:SetChecked(getter())
	end)
	return row, cb, labelFs
end

local function updateSectionMainDividerStart(section, topOffset)
	local panel = section and section.panel
	local divider = panel and panel.columnDivider
	if not divider then
		return
	end
	divider:ClearAllPoints()
	divider:SetPoint("TOPLEFT", panel, "TOPLEFT", OPTIONS_CONTROL_COLUMN_X, -(topOffset or 0) - 1)
	divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", OPTIONS_CONTROL_COLUMN_X, 1)
	divider:SetWidth(1)
end

local function addTwoColumnCheckRow(section, leftCfg, rightCfg)
	local rowH = SECTION_ROW_H
	local offset = section._gfRowOffset or 0
	local rowIndex = (section._gfRowCount or 0) + 1
	local panel = section.panel or section
	local row = CreateFrame("Frame", nil, panel)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
	row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
	row:SetHeight(rowH)

	local rowBackground = row:CreateTexture(nil, "BACKGROUND", nil, -1)
	rowBackground:SetAllPoints(row)
	setTextureColor(rowBackground, 1, 0.82, 0, rowIndex % 2 == 1 and 0.018 or 0.008)

	if rowIndex > 1 then
		local rule = createOptionsPanelRule(row)
		rule:SetPoint("TOPLEFT", row, "TOPLEFT", 16, 0)
		rule:SetPoint("TOPRIGHT", row, "TOPRIGHT", -16, 0)
		rule:SetHeight(1)
		row.topRule = rule
	end

	local centerRule = createOptionsPanelRule(row)
	centerRule:SetPoint("TOP", row, "TOP", 0, 0)
	centerRule:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
	centerRule:SetWidth(1)
	row.centerRule = centerRule

	local function addCell(cfg, side)
		local cell = CreateFrame("Frame", nil, row)
		cell:SetPoint("TOP", row, "TOP", 0, 0)
		cell:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
		if side == "left" then
			cell:SetPoint("LEFT", row, "LEFT", 0, 0)
			cell:SetPoint("RIGHT", row, "CENTER", 0, 0)
		else
			cell:SetPoint("LEFT", row, "CENTER", 0, 0)
			cell:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		end

		local cellDivider = createOptionsPanelRule(cell)
		cellDivider:SetPoint("TOPLEFT", cell, "TOPLEFT", OPTIONS_CONTROL_COLUMN_X, -1)
		cellDivider:SetPoint("BOTTOMLEFT", cell, "BOTTOMLEFT", OPTIONS_CONTROL_COLUMN_X, 1)
		cellDivider:SetWidth(1)
		cell.columnDivider = cellDivider

		local cb = createSettingsCheckButton(cell)
		cb:SetPoint("LEFT", cell, "LEFT", OPTIONS_CONTROL_COLUMN_X + OPTIONS_PANEL_CONTROL_INSET_X, 0)
		cb:SetChecked(cfg.getter())
		cb:SetMotionScriptsWhileDisabled(true)
		cb:SetScript("OnClick", function(self)
			if not self:IsEnabled() then
				return
			end
			cfg.setter(getCheckButtonBool(self))
			updateSettingsCheckButton(self)
		end)
		bindSettingsCheckButtonTooltip(cb, cfg.tooltip or "")

		local label = GF.UI.CreateFontString(cell, "OVERLAY", "GameFontHighlight")
		label:SetPoint("LEFT", cell, "LEFT", SECTION_LABEL_X, 0)
		label:SetPoint("RIGHT", cellDivider, "LEFT", -16, 0)
		label:SetHeight(OPTIONS_ROW_HEIGHT)
		label:SetJustifyH("LEFT")
		label:SetJustifyV("MIDDLE")
		label:SetWordWrap(false)
		label:SetText(cfg.label or "")
		label._gfFontSizeOverride = GF.SECTION_HEADER_TEXT_SIZE or 14
		if label.SetTextColor then
			label:SetTextColor(0.92, 0.90, 0.84, 1)
		end
		styleSettingsLabel(label, "GameFontHighlight")

		registerSettingsRefresher(function()
			cb:SetChecked(cfg.getter())
		end)

		return cell, cb, label
	end

	row.leftCell, row.leftCheck, row.leftLabel = addCell(leftCfg or {}, "left")
	row.rightCell, row.rightCheck, row.rightLabel = addCell(rightCfg or {}, "right")

	section._gfRowOffset = offset + rowH
	section._gfRowCount = rowIndex
	section._gfTwoColumnRowsHeight = math.max(section._gfTwoColumnRowsHeight or 0, section._gfRowOffset)
	updateSectionMainDividerStart(section, section._gfTwoColumnRowsHeight)
	updateSettingsSectionHeights(section)
	return row
end

local function addDependentCheckRow(section, label, tooltip, disabledTip, getter, setter, store, opts)
	opts = opts or {}
	local row, control, labelFs = addSettingsRow(section, label, tooltip, opts)
	local cb = createSettingsCheckButton(control)
	anchorSettingsControl(control, cb, opts)
	cb:SetChecked(getter())
	cb:SetMotionScriptsWhileDisabled(true)
	cb._enabledTip = tooltip
	cb._disabledTip = disabledTip
	cb:SetScript("OnClick", function(self)
		if not self:IsEnabled() then
			return
		end
		setter(getCheckButtonBool(self))
		updateSettingsCheckButton(self)
	end)
	bindSettingsCheckButtonTooltip(cb, tooltip, disabledTip)
	if store then
		store.cb = cb
		store.label = labelFs
		store.row = row
	end
	registerSettingsRefresher(function()
		cb:SetChecked(getter())
	end)
	return row, cb, labelFs
end

local function addDropdownSettingRow(section, label, tooltip)
	local _, control = addSettingsRow(section, label)
	local dd = createSettingsDropdown(control)
	dd:SetSize(DD_W, DD_H)
	anchorSettingsControl(control, dd)
	bindSettingsControlTooltip(dd, tooltip)
	return dd
end

local function resolveSliderEnabled(cfg)
	if cfg.enabled == nil then
		return nil
	end
	if type(cfg.enabled) == "function" then
		return cfg.enabled()
	end
	return cfg.enabled
end

local function addIntSliderRow(section, cfg)
	local _, control, label = addSettingsRow(section, cfg.label or "", cfg.tooltip)
	local minV = cfg.min
	local maxV = cfg.max
	local def = cfg.default
	local step = cfg.step or 1

	local slider = CreateFrame("Slider", nil, control, "MinimalSliderTemplate")
	slider:SetHeight(SLIDER_H)
	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)

	local sliderIndent = cfg.indentX or 0
	slider:SetPoint("LEFT", control, "LEFT", sliderIndent, 0)
	local valueFs
	if cfg.hideValue == true then
		if cfg.sliderWidth then
			slider:SetWidth(cfg.sliderWidth)
		else
			slider:SetPoint("RIGHT", control, "RIGHT", -(cfg.controlRightOffset or 0), 0)
		end
	else
		valueFs = GF.UI.CreateFontString(control, "OVERLAY", "GameFontHighlight")
		valueFs:SetWidth(58)
		valueFs:SetJustifyH("LEFT")
		if cfg.sliderWidth then
			valueFs:SetPoint("LEFT", slider, "RIGHT", 10, 0)
		else
			valueFs:SetPoint("RIGHT", control, "RIGHT", -(cfg.controlRightOffset or 0), 0)
			slider:SetPoint("RIGHT", valueFs, "LEFT", -10, 0)
		end
	end
	if cfg.sliderWidth then
		local function updateFixedSliderWidth()
			local available = (control:GetWidth() or 0) - sliderIndent - (valueFs and 68 or 0) - (cfg.controlRightOffset or 0)
			local width = math.min(cfg.sliderWidth, math.max(120, available))
			slider:SetWidth(width)
		end
		updateFixedSliderWidth()
		control:HookScript("OnSizeChanged", updateFixedSliderWidth)
	end

	local function syncSlider(raw, write)
		local v = raw
		if cfg.clamp then
			v = cfg.clamp(raw)
		end
		if write and cfg.set then
			cfg.set(v)
		end
		slider:SetValue(v)
		if valueFs then
			local fmt = cfg.formatValue or tostring
			valueFs:SetText(fmt(v))
		end
	end

	syncSlider(cfg.get and cfg.get() or def, false)
	local enabled = resolveSliderEnabled(cfg)
	if enabled ~= nil then
		slider:SetEnabled(enabled)
	end
	slider:SetScript("OnValueChanged", function(_, value)
		syncSlider(value, true)
		if cfg.onChanged then
			cfg.onChanged(value)
		end
	end)
	if cfg.onMouseUp then
		slider:SetScript("OnMouseUp", cfg.onMouseUp)
	end
	bindSettingsControlTooltip(slider, cfg.tooltip)

	registerSettingsRefresher(function()
		syncSlider(cfg.get and cfg.get() or def, false)
		local refreshedEnabled = resolveSliderEnabled(cfg)
		if refreshedEnabled ~= nil then
			slider:SetEnabled(refreshedEnabled)
		end
	end)

	return slider, valueFs, label
end

local function addIntInputRow(section, cfg)
	cfg = cfg or {}
	local _, control, label = addSettingsRow(section, cfg.label or "", cfg.tooltip)
	local def = cfg.default or 0
	local box = CreateFrame("EditBox", nil, control, "InputBoxTemplate")
	box:SetSize(cfg.width or NUMBER_BOX_W, cfg.height or NUMBER_BOX_H)
	anchorSettingsControl(control, box, cfg)
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(cfg.maxLetters or 4)
	box:SetJustifyH("CENTER")
	if box.SetTextInsets then
		box:SetTextInsets(4, 4, 0, 0)
	end
	box:SetTextColor(1, 0.92, 0.64, 1)
	box:SetShadowColor(0, 0, 0, 0.85)
	box:SetShadowOffset(1, -1)
	GF.UI.TrackEditBox(box, "GameFontHighlightSmall")

	local function normalize(raw)
		if cfg.clamp then
			return cfg.clamp(raw)
		end
		return math.floor((tonumber(raw) or def) + 0.5)
	end

	local function syncInput(raw, write)
		local v = normalize(raw)
		if write and cfg.set then
			cfg.set(v)
		end
		box:SetText(tostring(v))
		return v
	end

	syncInput(cfg.get and cfg.get() or def, false)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", function(self)
		local v = syncInput(self:GetText(), true)
		if cfg.onChanged then
			cfg.onChanged(v)
		end
	end)
	box:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	styleSettingsNumberBox(box, cfg.width or NUMBER_BOX_W, cfg.height or NUMBER_BOX_H)
	bindSettingsControlTooltip(box, cfg.tooltip)

	registerSettingsRefresher(function()
		if not box:HasFocus() then
			syncInput(cfg.get and cfg.get() or def, false)
		end
	end)

	return box, label
end

local function refreshApplicantInviteButtons()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateInviteState then
		GF.ApplicantsPanel:UpdateInviteState()
	end
end

local function refreshFindGroupMemberDisplay()
	if GF.FindGroupTab and GF.FindGroupTab.RefreshResults then
		GF.FindGroupTab:RefreshResults({ preserveScroll = true })
	end
end

local function refreshCreateDefaultRequiredItemLevel()
	if GF.CreatePanel and GF.CreatePanel.ApplyDefaultRequiredItemLevel then
		GF.CreatePanel:ApplyDefaultRequiredItemLevel(false)
	end
end

local function setInviteCapParameterEnabled(enabled)
	enabled = enabled == true
	if SP.inviteCapSlider then
		SP.inviteCapSlider:SetEnabled(enabled)
		if SP.inviteCapSlider.EnableMouse then
			SP.inviteCapSlider:EnableMouse(enabled)
		end
	end
	if SP.inviteCapLabel and SP.inviteCapLabel.SetTextColor then
		if enabled then
			SP.inviteCapLabel:SetTextColor(0.92, 0.90, 0.84, 1)
		else
			SP.inviteCapLabel:SetTextColor(0.48, 0.42, 0.28, 1)
		end
	end
	if SP.inviteCapValue and SP.inviteCapValue.SetTextColor then
		if enabled then
			SP.inviteCapValue:SetTextColor(1, 0.92, 0.64, 1)
		else
			SP.inviteCapValue:SetTextColor(0.48, 0.42, 0.28, 1)
		end
	end
end

local function addInviteCapRows(section, db)
	local L = GF.L or {}
	local minV = GF.INVITE_CAP_MIN or 1
	local maxV = GF.INVITE_CAP_MAX or 40
	local def = GF.INVITE_CAP_DEFAULT or 40

	addCheckRow(
		section,
		L.SET_INVITE_CAP or "Limit invite headcount",
		L.SET_INVITE_CAP_HINT or "",
		function()
			return db.inviteCapEnabled == true
		end,
		function(v)
			db.inviteCapEnabled = v
			setInviteCapParameterEnabled(v)
			refreshApplicantInviteButtons()
		end
	)

	SP.inviteCapSlider, SP.inviteCapValue, SP.inviteCapLabel = addIntSliderRow(section, {
		label = L.SET_INVITE_CAP_SLIDER or "Headcount cap",
		tooltip = L.SET_INVITE_CAP_HINT or "",
		min = minV,
		max = maxV,
		default = def,
		get = function()
			return db.inviteCap
		end,
		set = function(v)
			db.inviteCap = v
		end,
		clamp = function(v)
			v = math.floor((tonumber(v) or def) + 0.5)
			return math.max(minV, math.min(maxV, v))
		end,
		enabled = function()
			return db.inviteCapEnabled == true
		end,
		onChanged = refreshApplicantInviteButtons,
	})

	registerSettingsRefresher(function()
		setInviteCapParameterEnabled(db.inviteCapEnabled == true)
	end)
	setInviteCapParameterEnabled(db.inviteCapEnabled == true)
end

local function applyFontAppearance()
	if GF.Font and GF.Font.RefreshAll then
		GF.Font.RefreshAll()
	end
	if GF.ListColumns and GF.ListColumns.InvalidateCache then
		GF.ListColumns:InvalidateCache()
	end
	if GF.NavTree and GF.NavTree.ScheduleLayoutRows then
		GF.NavTree:ScheduleLayoutRows()
	end
	if GF.FindGroupTab and GF.FindGroupTab.Relayout then
		GF.FindGroupTab:Relayout({ force = true })
	end
	if GF.ApplicantsPanel and GF.ApplicantsPanel.Relayout then
		GF.ApplicantsPanel:Relayout({ force = true })
	end
end

local function refreshFontAppearance()
	applyFontAppearance()
	if SP.UpdateFontDropdown then
		SP:UpdateFontDropdown()
	end
	if SP.UpdateFontOutlineDropdown then
		SP:UpdateFontOutlineDropdown()
	end
end

function SP:SetupApplyDropdown()
	if not self.applyDropdown or not self.applyDropdown.SetupMenu then
		return
	end
	local L = GF.L or {}
	local modes = {
		{ GF.APPLY_MANUAL or "manual", L.SET_APPLY_MANUAL or "Manual" },
		{ GF.APPLY_CLICK_CONFIRM or "click_confirm", L.SET_APPLY_CLICK_CONFIRM or "Click row" },
		{ GF.APPLY_DBLCLICK_AUTO or "dblclick_auto", L.SET_APPLY_DBLCLICK_AUTO or "Double-click row" },
	}
	self.applyDropdown:SetupMenu(function(_, rootDescription)
		for _, entry in ipairs(modes) do
			local mode, label = entry[1], entry[2]
			rootDescription:CreateRadio(label, function()
				return GF.Apply and GF.Apply:GetMode() == mode
			end, function()
				GF.GetDB().applyMode = mode
				SP:UpdateApplyDropdown()
				if GF.SubtitleBar and GF.SubtitleBar.RefreshBrowseOptionToggles then
					GF.SubtitleBar:RefreshBrowseOptionToggles()
				end
			end)
		end
	end)
	self:UpdateApplyDropdown()
end

function SP:UpdateApplyDropdown()
	if not self.applyDropdown then
		return
	end
	local L = GF.L or {}
	local mode = GF.Apply and GF.Apply:GetMode() or "manual"
	local labels = {
		[GF.APPLY_MANUAL or "manual"] = L.SET_APPLY_MANUAL or "Manual",
		[GF.APPLY_CLICK_CONFIRM or "click_confirm"] = L.SET_APPLY_CLICK_CONFIRM or "Click row",
		[GF.APPLY_DBLCLICK_AUTO or "dblclick_auto"] = L.SET_APPLY_DBLCLICK_AUTO or "Double-click row",
	}
	self.applyDropdown:SetDefaultText(labels[mode] or labels.manual)
	if self.applyDropdown.GenerateMenu then
		self.applyDropdown:GenerateMenu()
	end
end

function SP:SetupMemberDisplayModeDropdown()
	if not self.memberDisplayModeDropdown or not self.memberDisplayModeDropdown.SetupMenu then
		return
	end
	local L = GF.L or {}
	local modes = {
		{ GF.MEMBER_DISPLAY_MODE_ROLE or "role", L.SET_MEMBER_DISPLAY_ROLE or "Role mode" },
		{ GF.MEMBER_DISPLAY_MODE_SPEC or "spec", L.SET_MEMBER_DISPLAY_SPEC or "Specialization mode" },
	}
	self.memberDisplayModeDropdown:SetupMenu(function(_, rootDescription)
		for _, entry in ipairs(modes) do
			local mode, label = entry[1], entry[2]
			rootDescription:CreateRadio(label, function()
				return GF.GetMemberDisplayMode and GF.GetMemberDisplayMode() == mode
			end, function()
				if GF.SetMemberDisplayMode then
					GF.SetMemberDisplayMode(mode)
				else
					GF.GetDB().memberDisplayMode = mode
				end
				SP:UpdateMemberDisplayModeDropdown()
				refreshFindGroupMemberDisplay()
			end)
		end
	end)
	self:UpdateMemberDisplayModeDropdown()
end

function SP:UpdateMemberDisplayModeDropdown()
	if not self.memberDisplayModeDropdown then
		return
	end
	local L = GF.L or {}
	local mode = (GF.GetMemberDisplayMode and GF.GetMemberDisplayMode()) or (GF.MEMBER_DISPLAY_MODE_ROLE or "role")
	local labels = {
		[GF.MEMBER_DISPLAY_MODE_ROLE or "role"] = L.SET_MEMBER_DISPLAY_ROLE or "Role mode",
		[GF.MEMBER_DISPLAY_MODE_SPEC or "spec"] = L.SET_MEMBER_DISPLAY_SPEC or "Specialization mode",
	}
	self.memberDisplayModeDropdown:SetDefaultText(labels[mode] or labels[GF.MEMBER_DISPLAY_MODE_ROLE or "role"])
	if self.memberDisplayModeDropdown.GenerateMenu then
		self.memberDisplayModeDropdown:GenerateMenu()
	end
end

function SP:SetupMemberTooltipModeDropdown()
	if not self.memberTooltipModeDropdown or not self.memberTooltipModeDropdown.SetupMenu then
		return
	end
	local L = GF.L or {}
	local modes = {
		{ GF.MEMBER_TOOLTIP_MODE_DETAILS or "details", L.SET_MEMBER_TOOLTIP_DETAILS or "Member detail mode" },
		{ GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count", L.SET_MEMBER_TOOLTIP_SPEC_COUNT or "Specialization count mode" },
	}
	self.memberTooltipModeDropdown:SetupMenu(function(_, rootDescription)
		for _, entry in ipairs(modes) do
			local mode, label = entry[1], entry[2]
			rootDescription:CreateRadio(label, function()
				return GF.GetMemberTooltipMode and GF.GetMemberTooltipMode() == mode
			end, function()
				if GF.SetMemberTooltipMode then
					GF.SetMemberTooltipMode(mode)
				else
					GF.GetDB().memberTooltipMode = mode
				end
				SP:UpdateMemberTooltipModeDropdown()
			end)
		end
	end)
	self:UpdateMemberTooltipModeDropdown()
end

function SP:UpdateMemberTooltipModeDropdown()
	if not self.memberTooltipModeDropdown then
		return
	end
	local L = GF.L or {}
	local defaultMode = GF.MEMBER_TOOLTIP_MODE_DEFAULT or GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
	local mode = (GF.GetMemberTooltipMode and GF.GetMemberTooltipMode()) or defaultMode
	local labels = {
		[GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"] = L.SET_MEMBER_TOOLTIP_DETAILS or "Member detail mode",
		[GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count"] = L.SET_MEMBER_TOOLTIP_SPEC_COUNT or "Specialization count mode",
	}
	self.memberTooltipModeDropdown:SetDefaultText(labels[mode] or labels[defaultMode] or labels[GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"])
	if self.memberTooltipModeDropdown.GenerateMenu then
		self.memberTooltipModeDropdown:GenerateMenu()
	end
end

function SP:SetupFrameStrataDropdown()
	if not self.frameStrataDropdown or not self.frameStrataDropdown.SetupMenu then
		return
	end
	local L = GF.L or {}
	local choices = {
		{ "LOW", L.SET_FRAME_STRATA_LOW or "Low" },
		{ "MEDIUM", L.SET_FRAME_STRATA_MEDIUM or "Medium" },
		{ "HIGH", L.SET_FRAME_STRATA_HIGH or "High" },
		{ "DIALOG", L.SET_FRAME_STRATA_DIALOG or "Dialog" },
	}
	self.frameStrataDropdown:SetupMenu(function(_, rootDescription)
		for _, entry in ipairs(choices) do
			local strata, label = entry[1], entry[2]
			rootDescription:CreateRadio(label, function()
				return GF.GetFrameStrata() == strata
			end, function()
				GF.GetDB().frameStrata = strata
				if GF.ApplyFrameStrata then
					GF.ApplyFrameStrata(strata)
				end
				SP:UpdateFrameStrataDropdown()
			end)
		end
	end)
	self:UpdateFrameStrataDropdown()
end

function SP:UpdateFrameStrataDropdown()
	if not self.frameStrataDropdown then
		return
	end
	local L = GF.L or {}
	local strata = GF.GetFrameStrata()
	local labels = {
		LOW = L.SET_FRAME_STRATA_LOW or "Low",
		MEDIUM = L.SET_FRAME_STRATA_MEDIUM or "Medium",
		HIGH = L.SET_FRAME_STRATA_HIGH or "High",
		DIALOG = L.SET_FRAME_STRATA_DIALOG or "Dialog",
	}
	self.frameStrataDropdown:SetDefaultText(labels[strata] or labels.MEDIUM)
	if self.frameStrataDropdown.GenerateMenu then
		self.frameStrataDropdown:GenerateMenu()
	end
end

function SP:SetupFontDropdown()
	if not self.fontDropdown or not self.fontDropdown.SetupMenu or not GF.Font then
		return
	end
	self.fontDropdown:SetupMenu(function(_, rootDescription)
		for _, row in ipairs(GF.Font.GetFontOptions()) do
			local value, label = row.value, row.label
			rootDescription:CreateRadio(label, function()
				return GF.Font.ResolveFontObjectKey(GF.GetDB().fontKey or "ChatFontNormal") == value
			end, function()
				GF.GetDB().fontKey = value
				refreshFontAppearance()
			end)
		end
	end)
	self:UpdateFontDropdown()
end

function SP:SetupFontOutlineDropdown()
	if not self.fontOutlineDropdown or not self.fontOutlineDropdown.SetupMenu or not GF.Font then
		return
	end
	self.fontOutlineDropdown:SetupMenu(function(_, rootDescription)
		for _, row in ipairs(GF.Font.GetOutlineOptions()) do
			local value, label = row.value, row.label
			rootDescription:CreateRadio(label, function()
				local fo = GF.GetDB().fontOutline or "NONE"
				if fo == "" then
					fo = "NONE"
				end
				return fo == value
			end, function()
				GF.GetDB().fontOutline = value
				refreshFontAppearance()
			end)
		end
	end)
	self:UpdateFontOutlineDropdown()
end

function SP:UpdateFontOutlineDropdown()
	if not self.fontOutlineDropdown or not GF.Font then
		return
	end
	local key = GF.GetDB().fontOutline or "NONE"
	if key == "" then
		key = "NONE"
	end
	local label = key
	for _, row in ipairs(GF.Font.GetOutlineOptions()) do
		if row.value == key then
			label = row.label
			break
		end
	end
	self.fontOutlineDropdown:SetDefaultText(label)
	if self.fontOutlineDropdown.GenerateMenu then
		self.fontOutlineDropdown:GenerateMenu()
	end
end

function SP:UpdateFontDropdown()
	if not self.fontDropdown or not GF.Font then
		return
	end
	local key = GF.Font.ResolveFontObjectKey(GF.GetDB().fontKey or "ChatFontNormal")
	local label = key
	for _, row in ipairs(GF.Font.GetFontOptions()) do
		if row.value == key or row.value == (GF.GetDB().fontKey or "") then
			label = row.label
			break
		end
	end
	if label == key and GF.GetLSMFontNameFromKey then
		local lsmName = GF.GetLSMFontNameFromKey(GF.GetDB().fontKey)
		if lsmName then
			label = lsmName
		end
	end
	self.fontDropdown:SetDefaultText(label)
	if self.fontDropdown.GenerateMenu then
		self.fontDropdown:GenerateMenu()
	end
end

function SP:CancelUpdateScrollDebounce()
	if self._updateScrollDebounce and self._updateScrollDebounce.Cancel then
		self._updateScrollDebounce:Cancel()
	end
	self._updateScrollDebounce = nil
end

function SP:ScheduleUpdateScroll()
	if self.parent and not self.parent:IsShown() then
		return
	end
	self:CancelUpdateScrollDebounce()
	if not C_Timer or not C_Timer.After then
		self:UpdateScroll()
		return
	end
	self._updateScrollDebounce = C_Timer.After(GF.LAYOUT_RESIZE_DEBOUNCE or 0.1, function()
		self._updateScrollDebounce = nil
		SP:UpdateScroll()
	end)
end

function SP:UpdateScroll()
	if not self.scroll or not self.body then
		return
	end
	if self.parent and not self.parent:IsShown() then
		return
	end
	if self._updatingScroll then
		return
	end

	local scrollW = self.scroll:GetWidth()
	local layoutW = getSettingsLayoutWidth(self)
	if not scrollW or scrollW <= 0 or not layoutW or layoutW <= 0 then
		return
	end

	if self.fullLayout then
		local bodyH = self.bodyH or 1
		if self._lastScrollW == scrollW and self._lastLayoutW == layoutW and self._lastBodyH == bodyH then
			return
		end
		self._updatingScroll = true
		self._lastScrollW = scrollW
		self._lastLayoutW = layoutW
		self._lastBodyH = bodyH
		self.body:SetWidth(layoutW)
		self.body:SetHeight(bodyH)
		GF.UI.UpdateScrollFrame(self.scroll)
		self._updatingScroll = false
		return
	end

	if not self.leftCol or not self.rightCol then
		return
	end

	local bodyH = math.max(self.leftH or 0, self.rightH or 0)
	local leftX, rightX = GF.ResolveSettingsColumnLayout(layoutW)
	if self._lastScrollW == scrollW and self._lastLayoutW == layoutW and self._lastLeftX == leftX and self._lastRightX == rightX and self._lastBodyH == bodyH then
		return
	end

	self._updatingScroll = true
	self._lastScrollW = scrollW
	self._lastLayoutW = layoutW
	self._lastLeftX = leftX
	self._lastRightX = rightX
	self._lastBodyH = bodyH

	self.body:SetWidth(layoutW)
	self.body:SetHeight(bodyH)
	self.leftCol:ClearAllPoints()
	self.leftCol:SetPoint("TOPLEFT", self.body, "TOPLEFT", leftX, 0)
	self.leftCol:SetSize(COL_W, self.leftH)
	self.rightCol:ClearAllPoints()
	self.rightCol:SetPoint("TOPLEFT", self.body, "TOPLEFT", rightX, 0)
	self.rightCol:SetSize(COL_W, self.rightH)
	GF.UI.UpdateScrollFrame(self.scroll)
	self._updatingScroll = false
end

local function ensureResetPopup()
	if not StaticPopupDialogs or StaticPopupDialogs[RESET_POPUP] then
		return
	end
	local L = GF.L or {}
	StaticPopupDialogs[RESET_POPUP] = {
		text = L.SET_RESET_ALL_CONFIRM or "Reset all addon settings to defaults?",
		button1 = YES or OKAY or "OK",
		button2 = L.CANCEL or CANCEL or "Cancel",
		OnAccept = function()
			if GF.ResetAllSettings then
				GF.ResetAllSettings()
			end
			if GF.ApplyAllSettings then
				GF.ApplyAllSettings()
			end
			if SP.RefreshFromDB then
				SP:RefreshFromDB()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
end

function SP:RefreshFromDB()
	for i = 1, #settingsRefreshers do
		settingsRefreshers[i]()
	end
	self:UpdateApplyDropdown()
	self:UpdateMemberDisplayModeDropdown()
	self:UpdateMemberTooltipModeDropdown()
	self:UpdateFrameStrataDropdown()
	self:UpdateFontDropdown()
	self:UpdateFontOutlineDropdown()
	self:UpdateScroll()
end

function SP:RefreshLocale()
	local parent = self.parent
	if not parent or not self.scroll then
		return
	end
	local wasShown = parent:IsShown()
	self:CancelUpdateScrollDebounce()
	if self.container then
		self.container:Hide()
	end
	settingsRefreshers = {}
	if StaticPopupDialogs then
		StaticPopupDialogs[RESET_POPUP] = nil
	end
	self.container = nil
	self.scroll = nil
	self.body = nil
	self.scrollBar = nil
	self.fullLayout = nil
	self.bodyH = nil
	self.resetDefaultsBtn = nil
	self.usageGuideIcon = nil
	self.applyDropdown = nil
	self.memberDisplayModeDropdown = nil
	self.memberTooltipModeDropdown = nil
	self.frameStrataDropdown = nil
	self.fontDropdown = nil
	self.fontOutlineDropdown = nil
	self.fontScaleSlider = nil
	self.fontScaleValue = nil
	self.defaultRequiredItemLevelBox = nil
	self.inviteCapCheck = nil
	self.inviteCapSlider = nil
	self.inviteCapValue = nil
	self.inviteCapLabel = nil
	self._lastScrollW = nil
	self._lastLayoutW = nil
	self._lastBodyH = nil
	self:Init(parent)
	parent:SetShown(wasShown == true)
end





function SP:Init(parent)
	if self.scroll then
		return
	end

	self.parent = parent

	local L = GF.L or {}
	local db = GF.GetDB()

	self.container = CreateFrame("Frame", nil, parent)
	self.container:SetAllPoints(parent)
	self.container:SetFrameLevel(parent:GetFrameLevel() + 1)

	self.scroll = GF.UI.CreateScrollFrame(self.container, { rowHeight = GF.SETTINGS_WHEEL_ROW_H or 24 })
	self.scroll:SetPoint("TOPLEFT", self.container, "TOPLEFT", SCROLL_INSET_L, 0)
	self.scroll:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", -SCROLL_INSET_R, GF.CONTENT_SCROLL_INSET_B or 0)
	self.scroll:SetFrameLevel(self.container:GetFrameLevel() + 2)
	self.body = CreateFrame("Frame", nil, self.scroll)
	self.body:SetSize(1, 1)
	self.scroll:SetScrollChild(self.body)
	self.scrollBar = GF.UI.AttachMinimalScrollBar(self.scroll, SETTINGS_SCROLLBAR_GAP, self.container, true)
	if self.scrollBar then
		self.scrollBar:SetWidth(SETTINGS_SCROLLBAR_WIDTH)
		self.scrollBar:ClearAllPoints()
		self.scrollBar:SetPoint("TOPLEFT", self.scroll, "TOPRIGHT", SETTINGS_SCROLLBAR_GAP, -SETTINGS_SCROLLBAR_TOP_INSET)
		self.scrollBar:SetPoint("BOTTOMLEFT", self.scroll, "BOTTOMRIGHT", SETTINGS_SCROLLBAR_GAP, SETTINGS_SCROLLBAR_BOTTOM_INSET)
	end
	self.fullLayout = true

	local y = -OPTIONS_CONTENT_TOP_OFFSET
	local section

	section = createSettingsSection(self.body, L.SET_SECTION_VISUAL_FONT or L.SET_SECTION_VISUAL or "Visual", y)
	if section.panel and section.panel.columnDivider then
		section.panel.columnDivider:Hide()
	end
	self.resetDefaultsBtn = GF.UI.CreatePanelButton(section.title, L.SET_RESET_ALL or "Reset defaults", GF.PANEL_BUTTON_ACTION_W, true)
	self.resetDefaultsBtn:SetPoint("RIGHT", section.title, "RIGHT", -(OPTIONS_SECTION_BODY_INSET_X + OPTIONS_ACTION_BUTTON_RIGHT_INSET), 0)
	self.resetDefaultsBtn:SetFrameLevel((section.title:GetFrameLevel() or parent:GetFrameLevel()) + 4)
	self.resetDefaultsBtn:SetScript("OnClick", function()
		ensureResetPopup()
		if StaticPopup_Show then
			StaticPopup_Show(RESET_POPUP)
		end
	end)

	self.usageGuideIcon = GF.UI.CreateHelpIcon(section.title, L.USAGE_GUIDE_BTN or L.USAGE_GUIDE_TITLE or "Guide", 40)
	self.usageGuideIcon:SetPoint("RIGHT", self.resetDefaultsBtn, "LEFT", -8, 0)
	self.usageGuideIcon:SetFrameLevel((section.title:GetFrameLevel() or parent:GetFrameLevel()) + 4)
	self.usageGuideIcon:SetScript("OnClick", function()
		if GF.UsageGuideDialog and GF.UsageGuideDialog.Show then
			GF.UsageGuideDialog:Show()
		end
	end)

	styleVisualAppearancePanel(section)
	local visualGroup = createVisualSettingsGroup(section, L.SET_SECTION_INTERFACE or "Interface entry")
	addTwoColumnCheckRow(visualGroup, {
		label = L.SET_SHOW_FLOAT or "Show floating button",
		tooltip = L.SET_SHOW_FLOAT_HINT or "",
		getter = function()
			return db.showFloatButton ~= false
		end,
		setter = function(v)
			db.showFloatButton = v
			if GF.FloatButton then
				GF.FloatButton:Apply()
			end
		end,
	}, {
		label = L.SET_LOCK_FLOAT_BUTTON or "Lock floating window",
		tooltip = L.SET_LOCK_FLOAT_BUTTON_HINT or "",
		getter = function()
			return db.lockFloatButton == true
		end,
		setter = function(v)
			db.lockFloatButton = v
			if GF.FloatButton then
				if GF.FloatButton.ApplyDragLock then
					GF.FloatButton:ApplyDragLock()
				else
					GF.FloatButton:Apply()
				end
			end
		end,
	})
	addTwoColumnCheckRow(visualGroup, {
		label = L.SET_SHOW_MINIMAP or "Minimap",
		tooltip = L.SET_SHOW_MINIMAP_HINT or "",
		getter = function()
			return db.showMinimap ~= false
		end,
		setter = function(v)
			db.showMinimap = v
			if GF.MinimapButton then
				GF.MinimapButton:Apply()
			end
		end,
	}, {
		label = L.SET_MINIMAP_SQUARE_ORBIT or "Square minimap orbit",
		tooltip = L.SET_MINIMAP_SQUARE_ORBIT_HINT or "",
		getter = function()
			return db.minimapSquareOrbit == true
		end,
		setter = function(v)
			db.minimapSquareOrbit = v
			if GF.MinimapButton then
				GF.MinimapButton:Apply()
			end
		end,
	})
	finishVisualSettingsGroup(section, visualGroup, OPTIONS_VISUAL_GROUP_GAP)

	visualGroup = createVisualSettingsGroup(section, L.SET_VISUAL_GROUP_TEXT or "Text")
	self.fontDropdown = addDropdownSettingRow(visualGroup, L.SET_FONT or "Font style")
	self:SetupFontDropdown()
	self.fontOutlineDropdown = addDropdownSettingRow(visualGroup, L.SET_FONT_OUTLINE or "Outline")
	self:SetupFontOutlineDropdown()
	self.fontScaleSlider, self.fontScaleValue = addIntSliderRow(visualGroup, {
		label = L.SET_FONT_SCALE or "Font scale",
		tooltip = L.SET_FONT_SCALE_HINT or "",
		min = GF.FONT_SCALE_MIN_PCT or 100,
		max = GF.FONT_SCALE_MAX_PCT or 150,
		default = GF.FONT_SCALE_DEFAULT_PCT or 100,
		step = 1,
		get = function()
			return GF.GetFontScalePct and GF.GetFontScalePct() or db.fontScalePct
		end,
		set = function(v)
			if GF.SetFontScalePct then
				GF.SetFontScalePct(v)
			else
				db.fontScalePct = v
			end
		end,
		clamp = function(v)
			if GF.ClampFontScalePct then
				return GF.ClampFontScalePct(v)
			end
			v = math.floor((tonumber(v) or 100) + 0.5)
			return math.max(100, math.min(150, v))
		end,
		formatValue = function(v)
			return string.format("%d%%", v)
		end,
		sliderWidth = OPTIONS_VISUAL_SLIDER_W,
		onChanged = refreshFontAppearance,
	})
	finishVisualSettingsGroup(section, visualGroup, OPTIONS_VISUAL_GROUP_GAP)

	visualGroup = createVisualSettingsGroup(section, L.SET_VISUAL_GROUP_PANEL or "Panel")
	self.frameStrataDropdown = addDropdownSettingRow(visualGroup, L.SET_FRAME_STRATA or "Frame strata", L.SET_FRAME_STRATA_HINT or "")
	self:SetupFrameStrataDropdown()
	addIntSliderRow(visualGroup, {
		label = L.SET_PANEL_SCALE or "Panel scale",
		tooltip = L.SET_PANEL_SCALE_HINT or "",
		min = GF.PANEL_SCALE_MIN_PCT or 100,
		max = GF.PANEL_SCALE_MAX_PCT or 150,
		default = GF.PANEL_SCALE_DEFAULT_PCT or 100,
		step = 1,
		get = function()
			return GF.GetPanelScalePct and GF.GetPanelScalePct() or db.panelScalePct
		end,
		set = function(v)
			if GF.SetPanelScalePct then
				GF.SetPanelScalePct(v)
			else
				db.panelScalePct = v
			end
		end,
		clamp = function(v)
			if GF.ClampPanelScalePct then
				return GF.ClampPanelScalePct(v)
			end
			v = math.floor((tonumber(v) or 100) + 0.5)
			return math.max(100, math.min(150, v))
		end,
		formatValue = function(v)
			return string.format("%d%%", v)
		end,
		sliderWidth = OPTIONS_VISUAL_SLIDER_W,
		onChanged = function()
			if GF.ApplyPanelScale then
				GF.ApplyPanelScale()
			end
		end,
	})
	addIntSliderRow(visualGroup, {
		label = L.SET_LIST_BACKGROUND_ALPHA or "List background",
		tooltip = L.SET_LIST_BACKGROUND_ALPHA_HINT or "",
		min = GF.LIST_BACKGROUND_ALPHA_MIN_PCT or 30,
		max = GF.LIST_BACKGROUND_ALPHA_MAX_PCT or 100,
		default = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100,
		step = 1,
		get = function()
			return GF.GetListBackgroundAlphaPct and GF.GetListBackgroundAlphaPct() or db.listBackgroundAlphaPct
		end,
		set = function(v)
			if GF.SetListBackgroundAlphaPct then
				GF.SetListBackgroundAlphaPct(v)
			else
				db.listBackgroundAlphaPct = v
			end
		end,
		clamp = function(v)
			if GF.ClampListBackgroundAlphaPct then
				return GF.ClampListBackgroundAlphaPct(v)
			end
			v = math.floor((tonumber(v) or 100) + 0.5)
			return math.max(30, math.min(100, v))
		end,
		onChanged = function()
			if GF.ApplyListBackgroundAlpha then
				GF.ApplyListBackgroundAlpha()
			end
		end,
		formatValue = function(v)
			return string.format("%d%%", v)
		end,
		sliderWidth = OPTIONS_VISUAL_SLIDER_W,
	})
	finishVisualSettingsGroup(section, visualGroup, 0)
	y = finishSettingsSection(section, y)

	section = createSettingsSection(self.body, L.SET_SECTION_STARTUP or "Startup", y)
	addCheckRow(section, L.SET_PREF_OPEN or "Replace premade entry", L.SET_PREF_OPEN_HINT or "", function()
		return db.preferOpen
	end, function(v)
		db.preferOpen = v
		if GF.Hook and GF.Hook.Refresh then
			GF.Hook.Refresh()
		end
	end)
	addCheckRow(section, L.SET_AUTO_EXPAND_FILTER or "Auto-expand filter", L.SET_AUTO_EXPAND_FILTER_HINT or "", function()
		return db.autoExpandFilter == true
	end, function(v)
		db.autoExpandFilter = v
	end)
	y = finishSettingsSection(section, y)

	section = createSettingsSection(self.body, L.SET_SECTION_LISTING or L.SET_SECTION_LIST or "List", y)
	addCheckRow(section, L.SET_SHOW_LEADER_REALM or "Show realm name", L.SET_SHOW_LEADER_REALM_HINT or "", function()
		return db.showLeaderRealm == true
	end, function(v)
		db.showLeaderRealm = v
		if GF.FindGroupTab then
			GF.FindGroupTab:RefreshResults()
		end
		if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
			GF.ApplicantsPanel:Refresh({ preserveScroll = true })
		end
	end)
	self.memberDisplayModeDropdown = addDropdownSettingRow(section, L.SET_MEMBER_DISPLAY_MODE or "Group member mode", L.SET_MEMBER_DISPLAY_MODE_HINT or "")
	self:SetupMemberDisplayModeDropdown()
	self.memberTooltipModeDropdown = addDropdownSettingRow(section, L.SET_MEMBER_TOOLTIP_MODE or "Mouseover tooltip", L.SET_MEMBER_TOOLTIP_MODE_HINT or "")
	self:SetupMemberTooltipModeDropdown()
	addIntSliderRow(section, {
		label = L.SET_LIST_WHEEL_ROWS or "Mouse wheel scroll (rows)",
		tooltip = L.SET_LIST_WHEEL_ROWS_HINT or "",
		min = GF.LIST_WHEEL_ROWS_MIN or 1,
		max = GF.LIST_WHEEL_ROWS_MAX or 10,
		default = GF.LIST_WHEEL_ROWS_DEFAULT or 3,
		get = function()
			return db.listWheelScrollRows
		end,
		set = function(v)
			db.listWheelScrollRows = v
		end,
		clamp = function(v)
			local minV = GF.LIST_WHEEL_ROWS_MIN or 1
			local maxV = GF.LIST_WHEEL_ROWS_MAX or 10
			local def = GF.LIST_WHEEL_ROWS_DEFAULT or 3
			v = math.floor((tonumber(v) or def) + 0.5)
			return math.max(minV, math.min(maxV, v))
		end,
	})
	y = finishSettingsSection(section, y)

	section = createSettingsSection(self.body, L.SET_SECTION_APPLICATION or "Application", y)
	self.applyDropdown = addDropdownSettingRow(section, L.SET_APPLY_MODE or "Apply shortcut")
	self.applyDropdown:SetSize(APPLY_DROPDOWN_W, DD_H)
	self:SetupApplyDropdown()
	addCheckRow(section, L.SET_AUTO_ACCEPT_INVITE or "Auto-accept invites", L.SET_AUTO_ACCEPT_INVITE_HINT or "", function()
		return db.autoAcceptInvite == true
	end, function(v)
		db.autoAcceptInvite = v and true or false
		if db.autoAcceptInvite and GF.Apply then
			if GF.Apply.TryAutoAcceptInvite then
				GF.Apply:TryAutoAcceptInvite()
			end
			if GF.Apply.QueueAutoConfirmLfgListRoleCheck then
				GF.Apply:QueueAutoConfirmLfgListRoleCheck()
			end
		end
		if GF.SubtitleBar and GF.SubtitleBar.RefreshBrowseOptionToggles then
			GF.SubtitleBar:RefreshBrowseOptionToggles()
		end
	end)
	local joinAnnouncePreviewW = GF.PANEL_BUTTON_STANDARD_W or 72
	local joinAnnounceRow = addCheckRow(section, L.SET_JOIN_ANNOUNCE or "Join announce", L.SET_JOIN_ANNOUNCE_HINT or "", function()
		return db.joinAnnounceEnabled == true
	end, function(v)
		db.joinAnnounceEnabled = v and true or false
	end)
	self.joinAnnouncePreviewBtn = GF.UI.CreatePanelButton(joinAnnounceRow.control, L.SET_JOIN_ANNOUNCE_PREVIEW or "Preview popup", joinAnnouncePreviewW, true)
	self.joinAnnouncePreviewBtn:SetPoint("RIGHT", joinAnnounceRow.control, "RIGHT", 0, 0)
	self.joinAnnouncePreviewBtn:SetScript("OnClick", function()
		if GF.JoinAnnounce and GF.JoinAnnounce.PreviewToast then
			GF.JoinAnnounce:PreviewToast()
		end
	end)
	self.defaultRequiredItemLevelBox = addIntInputRow(section, {
		label = L.SET_DEFAULT_REQUIRED_ITEM_LEVEL or "Default item level",
		tooltip = L.SET_DEFAULT_REQUIRED_ITEM_LEVEL_HINT or "",
		default = GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0,
		maxLetters = 4,
		get = function()
			return GF.GetDefaultRequiredItemLevel and GF.GetDefaultRequiredItemLevel() or db.defaultRequiredItemLevel
		end,
		set = function(v)
			if GF.SetDefaultRequiredItemLevel then
				GF.SetDefaultRequiredItemLevel(v)
			else
				db.defaultRequiredItemLevel = v
			end
		end,
		clamp = function(v)
			if GF.ClampDefaultRequiredItemLevel then
				return GF.ClampDefaultRequiredItemLevel(v)
			end
			local minV = GF.DEFAULT_REQUIRED_ITEM_LEVEL_MIN or 0
			local def = GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0
			v = math.floor(tonumber(v) or def)
			v = math.max(minV, v)
			local maxV = GF.GetCurrentAverageItemLevelFloor and GF.GetCurrentAverageItemLevelFloor()
			if maxV and maxV >= minV then
				v = math.min(v, maxV)
			end
			return v
		end,
		onChanged = refreshCreateDefaultRequiredItemLevel,
	})
	addCheckRow(section, L.SET_PERSIST_APPLY_NOTE or "Keep application note", L.SET_PERSIST_APPLY_NOTE_HINT or "", function()
		return db.persistApplyNote == true
	end, function(v)
		db.persistApplyNote = v and true or false
		if db.persistApplyNote ~= true and GF.Apply and GF.Apply.ClearApplyNoteState then
			GF.Apply:ClearApplyNoteState()
		end
	end)
	addCheckRow(section, L.SET_CANCEL_OLDEST_APPLY or "Cancel oldest application", L.SET_CANCEL_OLDEST_APPLY_HINT or "", function()
		return db.cancelOldestApply == true
	end, function(v)
		db.cancelOldestApply = v and true or false
	end)
	addInviteCapRows(section, db)
	y = finishSettingsSection(section, y)

	section = createSettingsSection(self.body, L.SET_MODULES or "Modules", y)
	addCheckRow(section, L.SET_MODULE_LIST_FILTER or "Enable plugin filter", L.SET_MODULE_LIST_FILTER_HINT or "", function()
		return db.moduleListFilter ~= false
	end, function(v)
		db.moduleListFilter = v
		if GF.FindGroupTab then
			if GF.FindGroupTab.ApplyClientFilters then
				GF.FindGroupTab:ApplyClientFilters()
			elseif GF.FindGroupTab.RefreshResults then
				GF.FindGroupTab:RefreshResults()
			end
		end
	end)
	addCheckRow(section, L.SET_MODULE_BLOCKLIST or "Block list module", L.SET_MODULE_BLOCKLIST_HINT or "", function()
		return db.moduleBlocklist ~= false
	end, function(v)
		db.moduleBlocklist = v
		if GF.Blocklist then
			GF.Blocklist:RebuildMaps()
		end
		if GF.BlocklistPanel then
			GF.BlocklistPanel:ApplyModuleVisibility()
		end
		if GF.FindGroupTab then
			GF.FindGroupTab:RefreshResults()
		end
	end)
	addCheckRow(section, L.SET_TITLE_CONTAGION or "Title contagion block", L.SET_TITLE_CONTAGION_HINT or "", function()
		return db.titleContagionEnabled ~= false
	end, function(v)
		db.titleContagionEnabled = v
		if GF.Blocklist then
			GF.Blocklist:RebuildMaps()
		end
		if GF.FindGroupTab then
			if GF.FindGroupTab.RemoveHiddenByBlocklist then
				GF.FindGroupTab:RemoveHiddenByBlocklist()
			end
			GF.FindGroupTab:RefreshResults()
		end
	end)
	addCheckRow(section, L.SET_BLOCK_TIPS or "Show block tips in chat", L.SET_BLOCK_TIPS_HINT or "", function()
		return db.blockTipsEnabled ~= false
	end, function(v)
		db.blockTipsEnabled = v
	end)
	y = finishSettingsSection(section, y)

	self.bodyH = -y - SECTION_GAP + OPTIONS_CONTENT_BOTTOM_PADDING
	self._lastLayoutW = 0

	self.scroll:SetScript("OnSizeChanged", function(scroll)
		if SP._frameResizing or SP._updatingScroll then
			return
		end
		if SP.parent and not SP.parent:IsShown() then
			return
		end
		local sw = scroll:GetWidth()
		if not sw or sw < 10 then
			return
		end
		local layoutW = getSettingsLayoutWidth(SP)
		if not layoutW or layoutW < 10 then
			return
		end
		if layoutW == SP._lastLayoutW then
			return
		end
		SP:ScheduleUpdateScroll()
	end)

	if GF.BlocklistPanel then
		GF.BlocklistPanel:ApplyModuleVisibility()
	end
	self:UpdateScroll()
end



function SP:Show()

	if self.parent then

		self.parent:Show()

	end

	self:UpdateScroll()

	if C_Timer and C_Timer.After then

		C_Timer.After(0, function()

			if SP.parent and SP.parent:IsShown() then

				SP:UpdateScroll()

			end

		end)

	end

end



function SP:Hide()
	self:CancelUpdateScrollDebounce()
	if self.parent then
		self.parent:Hide()
	end
end
