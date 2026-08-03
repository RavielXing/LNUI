local _, GF = ...

local SP = {}
GF.SettingsPanel = SP

local settingsRefreshers = {}

local function registerSettingsRefresher(fn)
	settingsRefreshers[#settingsRefreshers + 1] = fn
end

SP.LocaleBinding = SP.LocaleBinding or {}

function SP.LocaleBinding:Reset()
	self.bindings = {}
	self.keyByValue = {}
	local keys = {}
	for key, value in pairs(GF.L or {}) do
		if type(key) == "string"
			and type(value) == "string"
			and value ~= ""
		then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local value = GF.L[key]
		if self.keyByValue[value] == nil then
			self.keyByValue[value] = key
		end
	end
end

function SP.LocaleBinding:CreateValue(value)
	value = type(value) == "string" and value or ""
	return {
		key = self.keyByValue and self.keyByValue[value],
		fallback = value,
	}
end

function SP.LocaleBinding:Resolve(value)
	if type(value) ~= "table" then
		return type(value) == "string" and value or ""
	end
	local localized = value.key
		and GF.L
		and GF.L[value.key]
	if type(localized) == "string" then
		return localized
	end
	return value.fallback or ""
end

function SP.LocaleBinding:Apply(binding)
	if not binding or not binding.target then
		return
	end
	local text = self:Resolve(binding.value)
	if binding.setter then
		binding.setter(binding.target, text)
	elseif binding.target.SetText then
		binding.target:SetText(text)
	end
	if binding.after then
		binding.after(binding.target, text)
	end
end

function SP.LocaleBinding:BindText(target, value, setter, after)
	if not target then
		return
	end
	local binding = {
		target = target,
		value = self:CreateValue(value),
		setter = setter,
		after = after,
	}
	self.bindings[#self.bindings + 1] = binding
	self:Apply(binding)
	return binding
end

function SP.LocaleBinding:Refresh()
	for _, binding in ipairs(self.bindings or {}) do
		self:Apply(binding)
	end
end

local RESET_POPUP = "GF_RESET_SETTINGS_CATEGORY"
local WHITE = GF.WHITE_TEXTURE



local SETTINGS_MENU_W = GF.NAV_WIDTH or 180
local SETTINGS_MENU_ROW_H = GF.NAV_L0_ROW_H or 45
local SETTINGS_MENU_ROW_SPACING = GF.NAV_L0_ROW_SPACING or 2
local SETTINGS_MENU_TOP_INSET = GF.NAV_LIST_PADDING_TOP or 8
local SETTINGS_PAGE_HEADER_H = 74
local SETTINGS_PAGE_HEADER_INSET_X = 24
local SETTINGS_PAGE_HEADER_TITLE_H = 32
local SETTINGS_PAGE_HEADER_DESC_H = 22
local SETTINGS_PAGE_HEADER_RULE_INSET_X = 16
local SCROLL_INSET_L = GF.SETTINGS_LAYOUT_INSET_L or 0
local SETTINGS_SCROLLBAR_WIDTH = GF.SETTINGS_SCROLLBAR_WIDTH or 17
local SETTINGS_SCROLLBAR_GAP = GF.SETTINGS_SCROLLBAR_GAP or 2
local SETTINGS_SCROLLBAR_RIGHT_INSET = GF.SETTINGS_SCROLLBAR_RIGHT_INSET or 10
local SETTINGS_SCROLLBAR_TOP_INSET = GF.SETTINGS_SCROLLBAR_TOP_INSET or 8
local SETTINGS_SCROLLBAR_BOTTOM_INSET = GF.SETTINGS_SCROLLBAR_BOTTOM_INSET or 8
local SCROLL_INSET_R = GF.SETTINGS_VISIBLE_CONTENT_INSET_R
	or (SETTINGS_SCROLLBAR_WIDTH + SETTINGS_SCROLLBAR_GAP + SETTINGS_SCROLLBAR_RIGHT_INSET)

-- Retail warns when a Lua function captures more than 60 upvalues. Keep the
-- large settings initializer comfortably below that boundary by grouping its
-- shell-only geometry behind one upvalue.
local SETTINGS_INIT_LAYOUT = {
	menuW = SETTINGS_MENU_W,
	pageHeaderH = SETTINGS_PAGE_HEADER_H,
	pageHeaderInsetX =
		SETTINGS_PAGE_HEADER_INSET_X + SCROLL_INSET_L,
	pageHeaderTitleH = SETTINGS_PAGE_HEADER_TITLE_H,
	pageHeaderDescH = SETTINGS_PAGE_HEADER_DESC_H,
	pageHeaderRuleInsetX = SETTINGS_PAGE_HEADER_RULE_INSET_X,
	pageHeaderBackgroundInsetL = SCROLL_INSET_L + 2,
	pageHeaderRuleInsetL = 1,
	scrollInsetL = 0,
	scrollInsetR = SCROLL_INSET_R,
	scrollBarWidth = SETTINGS_SCROLLBAR_WIDTH,
	scrollBarGap = SETTINGS_SCROLLBAR_GAP,
	scrollBarTopInset = SETTINGS_SCROLLBAR_TOP_INSET,
	scrollBarBottomInset = SETTINGS_SCROLLBAR_BOTTOM_INSET,
	pageTitleTextSize = 18,
	pageDescriptionTextSize = 12,
}

local function getSettingsLayoutWidth(self)
	if self.scroll then
		local sw = self.scroll:GetWidth()
		if sw and sw > 0 then
			return sw
		end
	end
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
	return 0
end



local DD_W = GF.SETTINGS_DROPDOWN_W or 260
local DD_H = GF.SETTINGS_DROPDOWN_H or 26
local APPLY_DROPDOWN_W = DD_W
local SLIDER_H = GF.SETTINGS_SLIDER_H or 19
local SETTINGS_INPUT_ATLAS_STATES = GF.FILTER_CHECK_ATLAS_STATES
local NUMBER_BOX_W = 44
local NUMBER_BOX_H = 20
local OPTIONS_CONTENT_TOP_OFFSET = 16
local OPTIONS_CONTENT_BOTTOM_PADDING = 20
local OPTIONS_TITLE_H = 36
local OPTIONS_TITLE_TO_CONTROLS_GAP = 10
local OPTIONS_SECTION_GAP = 14
local OPTIONS_SECTION_BODY_INSET_X = 24
local OPTIONS_SECTION_TITLE_TEXT_INSET_X = 24
local OPTIONS_SECTION_TITLE_BG_LEFT_COMPENSATION = 1
local OPTIONS_LABEL_TEXT_SIZE = 16
local OPTIONS_ROW_TEXT_SIZE = 14
local OPTIONS_ROW_HEIGHT = 28
local OPTIONS_CHECK_BUTTON_SIZE = 20
local OPTIONS_CONTROL_COLUMN_X = 290
local OPTIONS_PANEL_ROW_H = 40
local OPTIONS_PANEL_LABEL_INSET_X = 28
local OPTIONS_PANEL_CONTROL_INSET_X = 24
local OPTIONS_ACTION_BUTTON_RIGHT_INSET = 16
local OPTIONS_SECTION_BODY_INSET_R = OPTIONS_SECTION_BODY_INSET_X
local OPTIONS_TITLE_LEFT_FADE_W = 36
local OPTIONS_TITLE_LEFT_FADE_ALPHA = 0.35
local OPTIONS_VISUAL_SLIDER_W = 520
local OPTIONS_LIST_STYLE_ROW_H = 64
local OPTIONS_LIST_STYLE_SWATCH_SIZE = 22
local OPTIONS_LIST_STYLE_RESET_SIZE = 22
local OPTIONS_LIST_STYLE_RESET_ICON_SIZE = 14
local OPTIONS_LIST_STYLE_PREVIEW_W = 156
local OPTIONS_LIST_STYLE_PREVIEW_H = 30
local OPTIONS_VISUAL_GROUP_GAP = 10
local OPTIONS_VISUAL_GROUP_INSET_X = 0
local OPTIONS_VISUAL_GROUP_HEADER_H = 34
local OPTIONS_VISUAL_GROUP_BODY_INSET_X = 8
local OPTIONS_VISUAL_GROUP_PADDING_BOTTOM = 6
local SECTION_GAP = OPTIONS_SECTION_GAP
local SECTION_ROW_H = OPTIONS_PANEL_ROW_H
local SECTION_LABEL_X = OPTIONS_PANEL_LABEL_INSET_X
local SECTION_LABEL_W = OPTIONS_CONTROL_COLUMN_X - OPTIONS_PANEL_LABEL_INSET_X - 16
local SECTION_CONTROL_X = OPTIONS_CONTROL_COLUMN_X + OPTIONS_PANEL_CONTROL_INSET_X
local SECTION_CONTROL_INSET_R = OPTIONS_ACTION_BUTTON_RIGHT_INSET

local function createSettingsDropdown(parent)
	return GF.UI.CreateDropdownButton(parent)
end

local function setSettingsInputAtlasState(frame, state, value)
	return GF.UI
		and GF.UI.ApplyFilterSquareControlChrome
		and GF.UI.ApplyFilterSquareControlChrome(frame, state, {
			atlasStates = SETTINGS_INPUT_ATLAS_STATES,
			layer = "BACKGROUND",
			subLevel = -6,
			color = { value or 1, value or 1, value or 1, 1 },
		})
end

local function updateSettingsInputButtonVisual(button)
	if not button then
		return
	end
	local active = button._gfInputHovered or button._gfInputPressed
	local value = button._gfInputPressed and 0.82 or 1
	setSettingsInputAtlasState(
		button,
		active and "hover" or "normal",
		value
	)
	if button._gfPressContent then
		local x = button._gfInputPressed and 1 or 0
		local y = button._gfInputPressed and -1 or 0
		button._gfPressContent:ClearAllPoints()
		button._gfPressContent:SetPoint("CENTER", button, "CENTER", x, y)
	end
end

local function bindSettingsInputButtonClickVisual(button, content)
	if not button then
		return
	end
	button._gfPressContent = content
	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			self._gfInputPressed = true
			updateSettingsInputButtonVisual(self)
		end
	end)
	button:SetScript("OnMouseUp", function(self)
		self._gfInputPressed = nil
		updateSettingsInputButtonVisual(self)
	end)
end

local function setTextureColor(texture, r, g, b, a)
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

local function updateSettingsNumberBox(box)
	if not box or not box._gfSettingsInputStyled then
		return
	end
	local active = box:HasFocus() or box._gfSettingsInputHovered
	GF.UI.ApplyFilterInputChrome(box, active and "hover" or "normal")
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

local function styleSettingsNumberBox(box, width, height, selectAllOnFocus)
	if not box then
		return box
	end
	if selectAllOnFocus == nil then
		selectAllOnFocus = true
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

		if selectAllOnFocus then
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
		else
			box:HookScript("OnEditFocusGained", function(self)
				clearOtherSettingsNumberFocus(self)
				activeSettingsNumberBox = self
				updateSettingsNumberBox(self)
			end)
		end
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

local function applyHorizontalBlackMask(texture, leftA, rightA)
	if not texture then
		return
	end
	texture:SetTexture(WHITE)
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

local function fitSettingsText(label, width, minimumSize)
	if label and GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(
			label,
			math.max(1, tonumber(width) or 1),
			minimumSize or 8)
	end
end

local function bindSettingsTextFit(frame, label, horizontalInsets, minimumSize)
	if not (frame and label) then
		return
	end
	local function updateFit(owner)
		local width = (owner:GetWidth() or 0)
			- (horizontalInsets or 0)
		if width > 20 then
			fitSettingsText(label, width, minimumSize or 10)
		end
	end
	frame:HookScript("OnSizeChanged", updateFit)
	updateFit(frame)
end

local function createOptionsTitleDivider(parent, layer)
	local divider = parent:CreateTexture(nil, layer or "ARTWORK")
	local dividerColor =
		GF.BROWSE_HEADER_TEXT_COLOR or { 1, 0.82, 0, 1 }
	local hasAtlas = GF.UI
		and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(
			divider,
			"Options_HorizontalDivider",
			true)
	if hasAtlas then
		divider:SetVertexColor(
			dividerColor[1] or 1,
			dividerColor[2] or 0.82,
			dividerColor[3] or 0,
			dividerColor[4] or 1)
	else
		setTextureColor(
			divider,
			dividerColor[1] or 1,
			dividerColor[2] or 0.82,
			dividerColor[3] or 0,
			dividerColor[4] or 1)
		divider:SetHeight(1)
	end
	return divider
end

local function setSettingsControlFramePanelShown(frame, shown)
	if not frame then
		return
	end
	if GF.UI and GF.UI.SetControlCardChromeShown then
		GF.UI.SetControlCardChromeShown(frame, shown == true)
	elseif GF.UI and GF.UI.SetControlFrameBorderShown then
		GF.UI.SetControlFrameBorderShown(frame, shown == true)
	end
end

local function applySettingsControlFramePanelStyle(frame)
	if not (
		frame
		and GF.UI
		and GF.UI.ApplyControlCardChrome
	) then
		return false
	end
	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end

	local chrome = GF.UI.ApplyControlCardChrome(frame, {
		state = "normal",
		displayMargin = GF.CONTROL_FRAME_DISPLAY_MARGIN or 8,
	})
	if not chrome then
		return false
	end
	setSettingsControlFramePanelShown(frame, true)
	return true
end

local function applyOptionsFeaturePanelStyle(frame)
	if not frame then
		return
	end
	applySettingsControlFramePanelStyle(frame)
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
	applySettingsControlFramePanelStyle(frame)
end

local function createSettingsSection(parent, label, y)
	local section = CreateFrame("Frame", nil, parent)
	section._gfSettingsSection = true
	section._gfRowOffset = 0
	section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	section:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)

	local title = CreateFrame("Frame", nil, section)
	title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
	title:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
	title:SetHeight(OPTIONS_TITLE_H)

	local titleBgHost = CreateFrame("Frame", nil, title)
	local chromeLevels = parent._gfSettingsChromeLevels
	if chromeLevels then
		titleBgHost:SetFrameLevel(
			chromeLevels.sectionBackground)
		title:SetFrameLevel(chromeLevels.sectionContent)
	end
	titleBgHost:SetPoint(
		"TOPLEFT",
		title,
		"TOPLEFT",
		-(SCROLL_INSET_L
			+ OPTIONS_SECTION_TITLE_BG_LEFT_COMPENSATION),
		0)
	titleBgHost:SetPoint(
		"BOTTOMRIGHT",
		title,
		"BOTTOMRIGHT",
		0,
		0)

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
	bindSettingsTextFit(
		title,
		titleText,
		OPTIONS_SECTION_TITLE_TEXT_INSET_X * 2,
		11)
	SP.LocaleBinding:BindText(
		titleText,
		label or "",
		nil,
		function(target)
			fitSettingsText(
				target,
				math.max(
					20,
					(target:GetWidth() or 0)
				),
				11
			)
		end
	)

	local panel = CreateFrame("Frame", nil, section, "BackdropTemplate")
	panel:SetPoint("TOPLEFT", section, "TOPLEFT", OPTIONS_SECTION_BODY_INSET_X, -(OPTIONS_TITLE_H + OPTIONS_TITLE_TO_CONTROLS_GAP))
	panel:SetPoint("TOPRIGHT", section, "TOPRIGHT", -OPTIONS_SECTION_BODY_INSET_R, -(OPTIONS_TITLE_H + OPTIONS_TITLE_TO_CONTROLS_GAP))
	panel:SetHeight(1)
	applyOptionsFeaturePanelStyle(panel)

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
	local panel = section.panel or section
	local row = CreateFrame("Frame", nil, panel)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
	row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
	row:SetHeight(rowH)

	local labelIndent = opts.labelIndent or 0
	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", row, "LEFT", SECTION_LABEL_X + labelIndent, 0)
	label:SetSize(math.max(20, SECTION_LABEL_W - labelIndent), OPTIONS_ROW_HEIGHT)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	label:SetWordWrap(false)
	label:SetText(labelText or "")
	label._gfFontSizeOverride = OPTIONS_ROW_TEXT_SIZE
	if label.SetTextColor then
		label:SetTextColor(0.92, 0.90, 0.84, 1)
	end
	styleSettingsLabel(label, "GameFontHighlight")
	fitSettingsText(
		label,
		math.max(20, SECTION_LABEL_W - labelIndent),
		10)
	SP.LocaleBinding:BindText(
		label,
		labelText or "",
		nil,
		function(target)
			fitSettingsText(
				target,
				math.max(20, SECTION_LABEL_W - labelIndent),
				10
			)
		end
	)

	local control = CreateFrame("Frame", nil, row)
	control:SetPoint("LEFT", row, "LEFT", SECTION_CONTROL_X, 0)
	control:SetPoint("RIGHT", row, "RIGHT", -SECTION_CONTROL_INSET_R, 0)
	control:SetHeight(rowH)

	row.label = label
	row.control = control
	section._gfRowOffset = offset + rowH
	updateSettingsSectionHeights(section)
	return row, control, label
end

local function makeSettingsSectionHeaderless(section)
	local panel = section and section.panel
	if not panel then
		return
	end
	if section.title then
		section.title:Hide()
	end
	panel:ClearAllPoints()
	panel:SetPoint(
		"TOPLEFT",
		section,
		"TOPLEFT",
		OPTIONS_SECTION_BODY_INSET_X,
		0)
	panel:SetPoint(
		"TOPRIGHT",
		section,
		"TOPRIGHT",
		-OPTIONS_SECTION_BODY_INSET_R,
		0)
	section._gfHeightBase = 0
end

local function styleVisualAppearancePanel(section, headerless)
	local panel = section and section.panel
	if not panel then
		return
	end
	if headerless then
		makeSettingsSectionHeaderless(section)
	end
	if panel.SetBackdrop then
		panel:SetBackdrop(nil)
	end
	setSettingsControlFramePanelShown(panel, false)
end

local function createVisualSettingsGroup(section, labelText)
	local offset = section._gfRowOffset or 0
	local panel = section.panel or section
	local group = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	group._gfRowOffset = 0
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

	local accent = header:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("LEFT", header, "LEFT", 12, 0)
	accent:SetSize(3, 16)
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
	title._gfFontSizeOverride = OPTIONS_LABEL_TEXT_SIZE
	title._gfFontFlagsOverride = "OUTLINE"
	title:SetTextColor(1, 0.82, 0, 1)
	styleSettingsLabel(title, "GameFontNormal")
	bindSettingsTextFit(header, title, 36, 11)
	SP.LocaleBinding:BindText(
		title,
		labelText or "",
		nil,
		function(target)
			fitSettingsText(
				target,
				math.max(20, target:GetWidth() or 0),
				11
			)
		end
	)
	group.title = title

	local headerRule = createOptionsTitleDivider(header)
	headerRule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 10, 0)
	headerRule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 0)
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
	updateSettingsSectionHeights(section)
end

local function createSingleCardSettingsSection(parent, labelText, y)
	local section = createSettingsSection(parent, labelText, y)
	styleVisualAppearancePanel(section, true)
	local group = createVisualSettingsGroup(section, labelText)
	return section, group
end

local function finishSingleCardSettingsSection(section, group, y)
	finishVisualSettingsGroup(section, group, 0)
	return finishSettingsSection(section, y)
end

local function bindSettingsControlTooltip(control, tooltip)
	if not control or not tooltip or tooltip == "" then
		return
	end
	local tooltipValue =
		SP.LocaleBinding:CreateValue(tooltip)
	if control.HookScript then
		control:HookScript("OnEnter", function(owner)
			GF.UI.ShowSimpleTooltip(
				owner,
				SP.LocaleBinding:Resolve(tooltipValue),
				"ANCHOR_RIGHT"
			)
		end)
		control:HookScript("OnLeave", GameTooltip_Hide)
	elseif control.SetScript then
		control:SetScript("OnEnter", function(owner)
			GF.UI.ShowSimpleTooltip(
				owner,
				SP.LocaleBinding:Resolve(tooltipValue),
				"ANCHOR_RIGHT"
			)
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
	local enabledValue =
		SP.LocaleBinding:CreateValue(enabledTip)
	local disabledValue =
		SP.LocaleBinding:CreateValue(disabledTip)
	button:SetScript("OnEnter", function(owner)
		setSettingsCheckButtonHovered(owner, true)
		local tipText =
			SP.LocaleBinding:Resolve(enabledValue)
		if owner.IsEnabled and not owner:IsEnabled() then
			tipText =
				SP.LocaleBinding:Resolve(disabledValue)
			if tipText == "" then
				tipText =
					SP.LocaleBinding:Resolve(enabledValue)
			end
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

local function addTwoColumnCheckRow(section, leftCfg, rightCfg)
	local rowH = SECTION_ROW_H
	local offset = section._gfRowOffset or 0
	local panel = section.panel or section
	local row = CreateFrame("Frame", nil, panel)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
	row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
	row:SetHeight(rowH)

	local function addCell(cfg, side)
		if not cfg then
			return nil
		end
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

		local cellControl = CreateFrame("Frame", nil, cell)
		cellControl:SetPoint(
			"TOPLEFT",
			cell,
			"TOPLEFT",
			OPTIONS_CONTROL_COLUMN_X,
			0)
		cellControl:SetPoint(
			"BOTTOMRIGHT",
			cell,
			"BOTTOMRIGHT",
			-OPTIONS_ACTION_BUTTON_RIGHT_INSET,
			0)
		cell.control = cellControl

		local cb = createSettingsCheckButton(cellControl)
		cb:SetPoint("CENTER", cellControl, "CENTER", 0, 0)
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
		label:SetPoint(
			"RIGHT",
			cell,
			"LEFT",
			OPTIONS_CONTROL_COLUMN_X - 16,
			0)
		label:SetHeight(OPTIONS_ROW_HEIGHT)
		label:SetJustifyH("LEFT")
		label:SetJustifyV("MIDDLE")
		label:SetWordWrap(false)
		label:SetText(cfg.label or "")
		label._gfFontSizeOverride = OPTIONS_ROW_TEXT_SIZE
		if label.SetTextColor then
			label:SetTextColor(0.92, 0.90, 0.84, 1)
		end
		styleSettingsLabel(label, "GameFontHighlight")
		fitSettingsText(
			label,
			math.max(
				20,
				OPTIONS_CONTROL_COLUMN_X
					- SECTION_LABEL_X
					- 16),
			10)
		SP.LocaleBinding:BindText(
			label,
			cfg.label or "",
			nil,
			function(target)
				fitSettingsText(
					target,
					math.max(
						20,
						OPTIONS_CONTROL_COLUMN_X
							- SECTION_LABEL_X
							- 16
					),
					10
				)
			end
		)

		registerSettingsRefresher(function()
			cb:SetChecked(cfg.getter())
		end)

		return cell, cb, label
	end

	row.leftCell, row.leftCheck, row.leftLabel = addCell(leftCfg, "left")
	row.rightCell, row.rightCheck, row.rightLabel = addCell(rightCfg, "right")

	section._gfRowOffset = offset + rowH
	updateSettingsSectionHeights(section)
	return row
end

local function addDropdownSettingRow(section, label, tooltip)
	local _, control, labelFs = addSettingsRow(section, label)
	local dd = createSettingsDropdown(control)
	dd:SetSize(DD_W, DD_H)
	anchorSettingsControl(control, dd)
	bindSettingsControlTooltip(dd, tooltip)
	return dd, labelFs
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
	local toggleCfg = cfg.toggle
	local toggleButton
	local sliderIndent = cfg.indentX or 0
	local toggleGap = cfg.toggleGap or 12

	if toggleCfg then
		toggleButton = createSettingsCheckButton(control)
		toggleButton:SetPoint(
			"LEFT",
			control,
			"LEFT",
			sliderIndent,
			0)
		toggleButton:SetChecked(
			toggleCfg.getter
				and toggleCfg.getter() == true)
		toggleButton:SetMotionScriptsWhileDisabled(true)
		toggleButton:SetScript("OnClick", function(self)
			if not self:IsEnabled() then
				return
			end
			if toggleCfg.setter then
				toggleCfg.setter(getCheckButtonBool(self))
			end
			updateSettingsCheckButton(self)
		end)
		bindSettingsCheckButtonTooltip(
			toggleButton,
			toggleCfg.tooltip or cfg.tooltip)
	end

	local slider = CreateFrame("Slider", nil, control, "MinimalSliderTemplate")
	slider:SetHeight(SLIDER_H)
	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)

	if toggleButton then
		slider:SetPoint(
			"LEFT",
			toggleButton,
			"RIGHT",
			toggleGap,
			0)
	else
		slider:SetPoint("LEFT", control, "LEFT", sliderIndent, 0)
	end
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
		valueFs:SetTextColor(1, 0.82, 0, 1)
		valueFs._gfFontSizeOverride = 12
		styleSettingsLabel(valueFs, "GameFontHighlight")
		if cfg.sliderWidth then
			valueFs:SetPoint("LEFT", slider, "RIGHT", 10, 0)
		else
			valueFs:SetPoint("RIGHT", control, "RIGHT", -(cfg.controlRightOffset or 0), 0)
			slider:SetPoint("RIGHT", valueFs, "LEFT", -10, 0)
		end
	end
	if cfg.sliderWidth then
		local function updateFixedSliderWidth()
			local toggleWidth = toggleButton
				and (OPTIONS_CHECK_BUTTON_SIZE + toggleGap)
				or 0
			local available = (control:GetWidth() or 0)
				- sliderIndent
				- toggleWidth
				- (valueFs and 68 or 0)
				- (cfg.controlRightOffset or 0)
			local width = math.min(cfg.sliderWidth, math.max(120, available))
			slider:SetWidth(width)
		end
		updateFixedSliderWidth()
		control:HookScript("OnSizeChanged", updateFixedSliderWidth)
	end

	local function syncSlider(raw, write)
		local normalize = cfg.clamp
		local value = normalize and normalize(raw) or raw
		local persist = write and cfg.set
		if persist then
			persist(value)
		end
		slider:SetValue(value)
		if valueFs then
			local format = cfg.formatValue or tostring
			valueFs:SetText(format(value))
			fitSettingsText(valueFs, 58, 9)
		end
	end

	syncSlider(cfg.get and cfg.get() or def, false)
	local initialEnabled = resolveSliderEnabled(cfg)
	if initialEnabled ~= nil then
		slider:SetEnabled(initialEnabled)
	end
	local function handleSliderChanged(_, value)
		syncSlider(value, true)
		local notify = cfg.onChanged
		if notify then
			notify(value)
		end
	end
	slider:SetScript("OnValueChanged", handleSliderChanged)
	if cfg.onMouseUp then
		slider:SetScript("OnMouseUp", cfg.onMouseUp)
	end
	bindSettingsControlTooltip(slider, cfg.tooltip)

	registerSettingsRefresher(function()
		if toggleButton and toggleCfg.getter then
			toggleButton:SetChecked(
				toggleCfg.getter() == true)
		end
		syncSlider(cfg.get and cfg.get() or def, false)
		local refreshedEnabled = resolveSliderEnabled(cfg)
		if refreshedEnabled ~= nil then
			slider:SetEnabled(refreshedEnabled)
		end
	end)

	return slider, valueFs, label, toggleButton
end

local function getListBackgroundStyle(styleKey)
	if GF.GetListBackgroundStyle then
		return GF.GetListBackgroundStyle(styleKey)
	end
	return { r = 1, g = 1, b = 1, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 }
end

local function getListBackgroundStyleState(styleKey)
	if styleKey == "friend" then
		return "blue"
	end
	if styleKey == "warning" then
		return "red"
	end
	if styleKey == "disabled" then
		return "grey"
	end
	return "normal"
end

local function createSettingsColorButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(OPTIONS_LIST_STYLE_SWATCH_SIZE, OPTIONS_LIST_STYLE_SWATCH_SIZE)
	setSettingsInputAtlasState(button, "normal")
	local swatch = button:CreateTexture(nil, "ARTWORK")
	swatch:SetSize(OPTIONS_LIST_STYLE_SWATCH_SIZE - 8, OPTIONS_LIST_STYLE_SWATCH_SIZE - 8)
	swatch:SetPoint("CENTER", button, "CENTER", 0, 0)
	setTextureColor(swatch, 1, 1, 1, 1)
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(swatch)
	setTextureColor(highlight, 1, 0.82, 0, 0.18)
	button:SetScript("OnEnter", function(self)
		self._gfInputHovered = true
		updateSettingsInputButtonVisual(self)
	end)
	button:SetScript("OnLeave", function(self)
		self._gfInputHovered = nil
		self._gfInputPressed = nil
		updateSettingsInputButtonVisual(self)
	end)
	button.swatch = swatch
	bindSettingsInputButtonClickVisual(button, swatch)
	return button
end

local function createSettingsIconButton(parent, texture, tooltip)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(OPTIONS_LIST_STYLE_RESET_SIZE, OPTIONS_LIST_STYLE_RESET_SIZE)
	setSettingsInputAtlasState(button, "normal")
	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetTexture(texture or GF.REFRESH_TEXTURE)
	icon:SetSize(OPTIONS_LIST_STYLE_RESET_ICON_SIZE, OPTIONS_LIST_STYLE_RESET_ICON_SIZE)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.Icon = icon
	button._gfTooltip =
		SP.LocaleBinding:CreateValue(tooltip)
	button:SetScript("OnEnter", function(self)
		self._gfInputHovered = true
		updateSettingsInputButtonVisual(self)
		local tooltipText =
			SP.LocaleBinding:Resolve(self._gfTooltip)
		if tooltipText ~= ""
			and GF.UI
			and GF.UI.ShowSimpleTooltip
		then
			GF.UI.ShowSimpleTooltip(
				self,
				tooltipText,
				"ANCHOR_RIGHT"
			)
		end
	end)
	button:SetScript("OnLeave", function(self)
		self._gfInputHovered = nil
		self._gfInputPressed = nil
		updateSettingsInputButtonVisual(self)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	bindSettingsInputButtonClickVisual(button, icon)
	return button
end

local function extractPickerColor(previous, fallback)
	fallback = fallback or {}
	if type(previous) ~= "table" then
		return fallback.r or 1, fallback.g or 1, fallback.b or 1
	end
	return previous.r or previous[1] or fallback.r or 1,
		previous.g or previous[2] or fallback.g or 1,
		previous.b or previous[3] or fallback.b or 1
end

local function openSettingsColorPicker(style, onChanged)
	if not ColorPickerFrame or not onChanged then
		return
	end
	local previous = { r = style.r or 1, g = style.g or 1, b = style.b or 1 }
	local function applyColor()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		onChanged(r, g, b)
	end
	local function cancelColor(cancelled)
		local r, g, b = extractPickerColor(cancelled, previous)
		onChanged(r, g, b)
	end
	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({
			r = previous.r,
			g = previous.g,
			b = previous.b,
			hasOpacity = false,
			swatchFunc = applyColor,
			cancelFunc = cancelColor,
		})
		return
	end
	ColorPickerFrame.func = applyColor
	ColorPickerFrame.cancelFunc = cancelColor
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.opacityFunc = nil
	ColorPickerFrame.previousValues = previous
	ColorPickerFrame:SetColorRGB(previous.r, previous.g, previous.b)
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
end

local function applyListBackgroundStyleUpdate(styleKey, style)
	if GF.SetListBackgroundStyle then
		GF.SetListBackgroundStyle(styleKey, style)
	end
	if GF.ApplyListBackgroundStyles then
		GF.ApplyListBackgroundStyles()
	elseif GF.ApplyListBackgroundAlpha then
		GF.ApplyListBackgroundAlpha()
	end
end

local function addListBackgroundStyleRow(section, cfg)
	cfg = cfg or {}
	local row, control = addSettingsRow(section, cfg.label or "", cfg.tooltip or "", { height = OPTIONS_LIST_STYLE_ROW_H })
	local styleKey = cfg.styleKey or "normal"
	local state = cfg.state or getListBackgroundStyleState(styleKey)

	local colorButton = createSettingsColorButton(control)
	colorButton:SetPoint("LEFT", control, "LEFT", 0, 0)
	bindSettingsControlTooltip(colorButton, cfg.tooltip or "")

	local resetColorButton = createSettingsIconButton(control, GF.REFRESH_TEXTURE, (GF.L and GF.L.SET_LIST_BACKGROUND_RESET_COLOR) or "恢复默认颜色")
	resetColorButton:SetPoint("LEFT", colorButton, "RIGHT", 6, 0)

	local alphaLabel = GF.UI.CreateFontString(control, "OVERLAY", "GameFontHighlight")
	alphaLabel:SetPoint("LEFT", resetColorButton, "RIGHT", 12, 0)
	alphaLabel:SetWidth(48)
	alphaLabel:SetJustifyH("LEFT")
	alphaLabel:SetJustifyV("MIDDLE")
	alphaLabel:SetText((GF.L and GF.L.SET_LIST_BACKGROUND_ALPHA_LABEL) or "透明度")
	alphaLabel._gfFontSizeOverride = 12
	styleSettingsLabel(alphaLabel, "GameFontHighlight")
	fitSettingsText(alphaLabel, 48, 8)
	SP.LocaleBinding:BindText(
		alphaLabel,
		(GF.L and GF.L.SET_LIST_BACKGROUND_ALPHA_LABEL)
			or "透明度",
		nil,
		function(target)
			fitSettingsText(target, 48, 8)
		end
	)

	local alphaSlider = CreateFrame("Slider", nil, control, "MinimalSliderTemplate")
	alphaSlider:SetHeight(SLIDER_H)
	alphaSlider:SetMinMaxValues(GF.LIST_BACKGROUND_ALPHA_MIN_PCT or 30, GF.LIST_BACKGROUND_ALPHA_MAX_PCT or 100)
	alphaSlider:SetValueStep(1)
	alphaSlider:SetObeyStepOnDrag(true)
	alphaSlider:SetPoint("LEFT", alphaLabel, "RIGHT", 8, 0)
	bindSettingsControlTooltip(alphaSlider, cfg.tooltip or "")

	local valueFs = GF.UI.CreateFontString(control, "OVERLAY", "GameFontHighlight")
	valueFs:SetWidth(48)
	valueFs:SetJustifyH("RIGHT")
	valueFs:SetTextColor(1, 0.82, 0, 1)
	valueFs._gfFontSizeOverride = 12
	styleSettingsLabel(valueFs, "GameFontHighlight")

	local preview = CreateFrame("Button", nil, control)
	preview:SetSize(
		OPTIONS_LIST_STYLE_PREVIEW_W,
		OPTIONS_LIST_STYLE_PREVIEW_H)
	preview:SetPoint("RIGHT", control, "RIGHT", -2, 0)
	valueFs:SetPoint("RIGHT", preview, "LEFT", -10, 0)
	alphaSlider:SetPoint("RIGHT", valueFs, "LEFT", -10, 0)
	preview:RegisterForClicks("LeftButtonUp")
	preview.backgroundPieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(preview, "BACKGROUND", -2)
		or nil
	preview.hoverPieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(preview, "BORDER", -1)
		or nil
	preview.selectedPieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(preview, "BORDER", 1)
		or nil
	for _, pieces in ipairs({ preview.hoverPieces, preview.selectedPieces }) do
		for _, piece in pairs(pieces or {}) do
			if piece.SetBlendMode then
				piece:SetBlendMode("ADD")
			end
		end
	end
	local previewText = GF.UI.CreateFontString(preview, "OVERLAY", "GameFontHighlight")
	previewText:SetPoint("LEFT", preview, "LEFT", 12, 0)
	previewText:SetPoint("RIGHT", preview, "RIGHT", -12, 0)
	previewText:SetJustifyH("CENTER")
	previewText:SetJustifyV("MIDDLE")
	previewText:SetWordWrap(false)
	previewText:SetText(cfg.previewText or cfg.label or "")
	previewText._gfFontSizeOverride = 12
	styleSettingsLabel(previewText, "GameFontHighlight")
	fitSettingsText(
		previewText,
		math.max(1, preview:GetWidth() - 24),
		8)
	SP.LocaleBinding:BindText(
		previewText,
		cfg.previewText or cfg.label or "",
		nil,
		function(target)
			fitSettingsText(
				target,
				math.max(1, preview:GetWidth() - 24),
				8
			)
		end
	)

	local function setPreviewPiecesShown(pieces, shown)
		if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
			GF.UI.SetRowBackgroundPiecesShown(pieces, shown == true)
			return
		end
		for _, piece in pairs(pieces or {}) do
			if piece.SetShown then
				piece:SetShown(shown == true)
			end
		end
	end

	local function applyPreviewOverlay(pieces, usage)
		if not (pieces and GF.UI and GF.UI.ApplyRowBackgroundPieces) then
			return
		end
		local color = GF.GetListBackgroundOverlayColor
			and GF.GetListBackgroundOverlayColor(state, usage)
			or { 1, 0.82, 0, usage == "hover" and 0.13 or 0.82 }
		GF.UI.ApplyRowBackgroundPieces(preview, pieces, {
			state = "normal",
			mode = "full",
			alpha = GF.BROWSE_ROW_SELECTED_ALPHA or 1,
			vertexColor = color,
			desaturated = true,
			fallbackTexture = WHITE,
			defaultHeight = OPTIONS_LIST_STYLE_PREVIEW_H,
		})
	end

	local function updatePreviewInteraction()
		applyPreviewOverlay(preview.hoverPieces, "hover")
		applyPreviewOverlay(preview.selectedPieces, "selected")
		setPreviewPiecesShown(preview.selectedPieces, preview._gfListPreviewSelected == true)
		setPreviewPiecesShown(preview.hoverPieces, preview._gfListPreviewHovered == true and preview._gfListPreviewSelected ~= true)
	end

	local syncing = false
	local function updatePreview()
		local style = getListBackgroundStyle(styleKey)
		setTextureColor(colorButton.swatch, style.r or 1, style.g or 1, style.b or 1, 1)
		valueFs:SetText(string.format("%d%%", style.alphaPct or 100))
		if preview.backgroundPieces and GF.UI and GF.UI.ApplyRowBackgroundPieces then
			GF.UI.ApplyRowBackgroundPieces(preview, preview.backgroundPieces, {
				state = state,
				mode = "full",
				alpha = GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha(state) or 0.92,
				fallbackTexture = WHITE,
				defaultHeight = OPTIONS_LIST_STYLE_PREVIEW_H,
			})
		end
		updatePreviewInteraction()
	end

	local function syncControls()
		local style = getListBackgroundStyle(styleKey)
		syncing = true
		alphaSlider:SetValue(style.alphaPct or 100)
		syncing = false
		updatePreview()
	end

	colorButton:SetScript("OnClick", function()
		local style = getListBackgroundStyle(styleKey)
		openSettingsColorPicker(style, function(r, g, b)
			applyListBackgroundStyleUpdate(styleKey, { r = r, g = g, b = b })
			updatePreview()
		end)
	end)

	resetColorButton:SetScript("OnClick", function()
		local defaults = GF.LIST_BACKGROUND_STYLE_DEFAULTS and GF.LIST_BACKGROUND_STYLE_DEFAULTS[styleKey]
		if not defaults then
			return
		end
		applyListBackgroundStyleUpdate(styleKey, { r = defaults.r, g = defaults.g, b = defaults.b })
		updatePreview()
	end)

	alphaSlider:SetScript("OnValueChanged", function(_, value)
		local pct = GF.ClampListBackgroundAlphaPct and GF.ClampListBackgroundAlphaPct(value) or math.floor((tonumber(value) or 100) + 0.5)
		if not syncing then
			applyListBackgroundStyleUpdate(styleKey, { alphaPct = pct })
		end
		valueFs:SetText(string.format("%d%%", pct))
		updatePreview()
	end)

	preview:SetScript("OnEnter", function(self)
		self._gfListPreviewHovered = true
		updatePreviewInteraction()
	end)
	preview:SetScript("OnLeave", function(self)
		self._gfListPreviewHovered = false
		updatePreviewInteraction()
	end)
	preview:SetScript("OnClick", function(self)
		self._gfListPreviewSelected = self._gfListPreviewSelected ~= true
		updatePreviewInteraction()
	end)

	registerSettingsRefresher(syncControls)
	syncControls()
	return row
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

local function setSettingsWidgetEnabled(widget, enabled)
	if not widget then
		return
	end
	enabled = enabled == true
	if widget.SetEnabled then
		widget:SetEnabled(enabled)
	elseif enabled and widget.Enable then
		widget:Enable()
	elseif not enabled and widget.Disable then
		widget:Disable()
	end
	if widget.SetAlpha then
		widget:SetAlpha(enabled and 1 or 0.45)
	end
end

local function setSettingsLabelEnabled(label, enabled)
	if not label or not label.SetTextColor then
		return
	end
	if enabled then
		label:SetTextColor(0.92, 0.90, 0.84, 1)
	else
		label:SetTextColor(0.46, 0.45, 0.42, 1)
	end
end

local function getMythicPlusAnnouncementService(...)
	local service = GF.MythicPlusAnnouncementService
	if type(service) ~= "table" then
		return nil
	end
	for index = 1, select("#", ...) do
		if type(service[select(index, ...)]) ~= "function" then
			return nil
		end
	end
	return service
end

local function getMythicPlusAnnouncementValue(methodName, fallback, ...)
	local service = getMythicPlusAnnouncementService(methodName)
	if not service then
		return fallback
	end
	local ok, value = pcall(service[methodName], service, ...)
	if not ok or value == nil then
		return fallback
	end
	return value
end

local function setMythicPlusAnnouncementValue(methodName, ...)
	local service = getMythicPlusAnnouncementService(methodName)
	if not service then
		return false
	end
	return pcall(service[methodName], service, ...)
end

local function addMythicPlusAnnouncementCheckRow(section, label, tooltip, getMethod, setMethod)
	local row, check, labelFs = addCheckRow(section, label, tooltip, function()
		return getMythicPlusAnnouncementValue(getMethod, false) == true
	end, function(value)
		setMythicPlusAnnouncementValue(setMethod, value == true)
	end)

	local function refreshAvailability()
		local enabled = getMythicPlusAnnouncementService(getMethod, setMethod) ~= nil
		setSettingsWidgetEnabled(check, enabled)
		setSettingsLabelEnabled(labelFs, enabled)
	end
	registerSettingsRefresher(refreshAvailability)
	refreshAvailability()
	return row, check, labelFs
end

local function addSettingsTextActionRow(section, cfg)
	cfg = cfg or {}
	local row, control, label = addSettingsRow(section, cfg.label or "", cfg.tooltip)
	local buttonWidth = GF.PANEL_BUTTON_STANDARD_W or 72
	local buttonGap = 8

	local clearButton
	if cfg.allowClear == true then
		clearButton = GF.UI.CreatePanelButton(control, cfg.clearText or "", buttonWidth)
		clearButton:SetPoint("RIGHT", control, "RIGHT", 0, 0)
		fitSettingsText(
			clearButton:GetFontString(),
			math.max(1, clearButton:GetWidth() - 12),
			8)
		SP.LocaleBinding:BindText(
			clearButton,
			cfg.clearText or "",
			nil,
			function(target)
				fitSettingsText(
					target:GetFontString(),
					math.max(
						1,
						target:GetWidth() - 12
					),
					8
				)
			end
		)
	end

	local confirmButton = GF.UI.CreatePanelButton(control, cfg.confirmText or "", buttonWidth)
	fitSettingsText(
		confirmButton:GetFontString(),
		math.max(1, confirmButton:GetWidth() - 12),
		8)
	SP.LocaleBinding:BindText(
		confirmButton,
		cfg.confirmText or "",
		nil,
		function(target)
			fitSettingsText(
				target:GetFontString(),
				math.max(1, target:GetWidth() - 12),
				8
			)
		end
	)
	if clearButton then
		confirmButton:SetPoint("RIGHT", clearButton, "LEFT", -buttonGap, 0)
	else
		confirmButton:SetPoint("RIGHT", control, "RIGHT", 0, 0)
	end

	local box = CreateFrame("EditBox", nil, control, "InputBoxTemplate")
	box:SetAutoFocus(false)
	box:SetMultiLine(false)
	box:SetText("")
	GF.UI.TrackEditBox(box, "GameFontHighlightSmall")
	styleSettingsNumberBox(box, DD_W, DD_H, false)
	box:SetJustifyH("LEFT")
	if box.SetTextInsets then
		box:SetTextInsets(8, 8, 0, 0)
	end
	box:ClearAllPoints()
	box:SetPoint("LEFT", control, "LEFT", 0, 0)
	box:SetPoint("RIGHT", confirmButton, "LEFT", -buttonGap, 0)
	box:SetHeight(DD_H)

	local placeholder = GF.UI.CreateFontString(box, "OVERLAY", "GameFontDisableSmall")
	placeholder:SetPoint("LEFT", box, "LEFT", 8, 0)
	placeholder:SetPoint("RIGHT", box, "RIGHT", -8, 0)
	placeholder:SetHeight(DD_H)
	placeholder:SetJustifyH("LEFT")
	placeholder:SetJustifyV("MIDDLE")
	placeholder:SetWordWrap(false)
	placeholder:SetTextColor(0.48, 0.46, 0.42, 1)
	placeholder:SetText(cfg.placeholder or "")
	styleSettingsLabel(placeholder, "GameFontDisableSmall")
	SP.LocaleBinding:BindText(
		placeholder,
		cfg.placeholder or ""
	)

	local syncing

	local function isAvailable()
		if type(cfg.enabled) == "function" then
			return cfg.enabled() == true
		end
		return cfg.enabled ~= false
	end

	local function getSavedText()
		if not isAvailable() or type(cfg.get) ~= "function" then
			return ""
		end
		local ok, value = pcall(cfg.get)
		return ok and tostring(value or "") or ""
	end

	local function updateState()
		local enabled = isAvailable()
		local currentText = box:GetText() or ""
		local savedText = getSavedText()
		setSettingsWidgetEnabled(box, enabled)
		setSettingsWidgetEnabled(confirmButton, enabled and currentText ~= savedText)
		setSettingsWidgetEnabled(clearButton, enabled and currentText ~= "")
		setSettingsLabelEnabled(label, enabled)
		placeholder:SetShown(enabled and currentText == "" and not box:HasFocus())
	end

	local function syncFromService(force)
		local enabled = isAvailable()
		if force or not box:HasFocus() then
			syncing = true
			box:SetText(enabled and getSavedText() or "")
			syncing = nil
		end
		updateState()
	end

	local function commitText(value)
		if not isAvailable() or type(cfg.set) ~= "function" then
			updateState()
			return
		end
		pcall(cfg.set, value)
		syncFromService(true)
	end

	confirmButton:SetScript("OnClick", function()
		if confirmButton:IsEnabled() then
			commitText(box:GetText() or "")
			box:ClearFocus()
		end
	end)
	if clearButton then
		clearButton:SetScript("OnClick", function()
			if clearButton:IsEnabled() then
				commitText("")
				box:ClearFocus()
			end
		end)
	end
	box:SetScript("OnEnterPressed", function(self)
		commitText(self:GetText() or "")
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		syncFromService(true)
		self:ClearFocus()
	end)
	box:HookScript("OnEditFocusGained", updateState)
	box:HookScript("OnEditFocusLost", updateState)
	box:HookScript("OnTextChanged", function()
		if not syncing then
			updateState()
		end
	end)
	bindSettingsControlTooltip(box, cfg.tooltip)

	registerSettingsRefresher(function()
		syncFromService(false)
	end)
	syncFromService(true)

	row.editBox = box
	row.confirmButton = confirmButton
	row.clearButton = clearButton
	return row, box, confirmButton, clearButton, label
end

local function invokeSettingsTarget(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) == "function" then
		return method(owner, ...)
	end
end

local function refreshApplicantInviteButtons()
	invokeSettingsTarget(GF.ApplicantsPanel, "UpdateInviteState")
end

local function refreshFindGroupMemberDisplay()
	invokeSettingsTarget(GF.FindGroupTab, "RefreshResults",
		{ preserveScroll = true })
end

local function refreshCreateDefaultRequiredItemLevel()
	invokeSettingsTarget(GF.CreatePanel,
		"ApplyDefaultRequiredItemLevel", false)
end

local function refreshLeaderRealmConsumers()
	invokeSettingsTarget(GF.FindGroupTab, "RefreshResults")
	invokeSettingsTarget(GF.ApplicantsPanel, "Refresh",
		{ preserveScroll = true })
	invokeSettingsTarget(GF.MythicPlusWorkspace,
		"QueueRefreshCurrent", "showLeaderRealm")
end

local function refreshBlacklistSettingConsumers()
	local blocklist = GF.Blocklist
	if blocklist then
		blocklist:RebuildMaps()
	end
	local blocklistPanel = GF.BlocklistPanel
	if blocklistPanel then
		blocklistPanel:ApplyModuleVisibility()
	end
	local findGroupTab = GF.FindGroupTab
	if findGroupTab then
		findGroupTab:RefreshResults()
	end
end

local function clampListWheelRows(value)
	local minimum = GF.LIST_WHEEL_ROWS_MIN or 1
	local maximum = GF.LIST_WHEEL_ROWS_MAX or 10
	local fallback = GF.LIST_WHEEL_ROWS_DEFAULT or 3
	local rounded = math.floor((tonumber(value) or fallback) + 0.5)
	return math.min(maximum, math.max(minimum, rounded))
end

local function listWheelSliderOptions(db, L)
	local options = {}
	options.label = L.SET_LIST_WHEEL_ROWS or "Mouse wheel scroll (rows)"
	options.tooltip = L.SET_LIST_WHEEL_ROWS_HINT or ""
	options.min = GF.LIST_WHEEL_ROWS_MIN or 1
	options.max = GF.LIST_WHEEL_ROWS_MAX or 10
	options.default = GF.LIST_WHEEL_ROWS_DEFAULT or 3
	options.get = function() return db.listWheelScrollRows end
	options.set = function(value) db.listWheelScrollRows = value end
	options.clamp = clampListWheelRows
	return options
end

local function setAutoInviteLimitControlEnabled(enabled)
	enabled = enabled == true
	if SP.autoInviteLimitSlider then
		SP.autoInviteLimitSlider:SetEnabled(enabled)
		if SP.autoInviteLimitSlider.EnableMouse then
			SP.autoInviteLimitSlider:EnableMouse(enabled)
		end
	end
	if SP.autoInviteLimitValue and SP.autoInviteLimitValue.SetTextColor then
		if enabled then
			SP.autoInviteLimitValue:SetTextColor(1, 0.92, 0.64, 1)
		else
			SP.autoInviteLimitValue:SetTextColor(0.48, 0.42, 0.28, 1)
		end
	end
end

local function addAutoInviteLimitRow(section, db)
	local L = GF.L or {}
	local minV = GF.AUTO_INVITE_MEMBER_LIMIT_MIN or 1
	local maxV = GF.AUTO_INVITE_MEMBER_LIMIT_MAX or 40
	local def = GF.AUTO_INVITE_MEMBER_LIMIT_DEFAULT or 40

	SP.autoInviteLimitSlider,
	SP.autoInviteLimitValue,
	SP.autoInviteLimitLabel,
	SP.autoInviteLimitCheck = addIntSliderRow(section, {
		label = L.SET_AUTO_INVITE_LIMIT or "Auto Invite member limit",
		tooltip = L.SET_AUTO_INVITE_LIMIT_HINT or "",
		toggle = {
			tooltip = L.SET_AUTO_INVITE_LIMIT_HINT or "",
			getter = function()
				return db.autoInviteMemberLimitEnabled == true
			end,
			setter = function(v)
				db.autoInviteMemberLimitEnabled = v == true
				setAutoInviteLimitControlEnabled(v)
				refreshApplicantInviteButtons()
			end,
		},
		min = minV,
		max = maxV,
		default = def,
		get = function()
			return db.autoInviteMemberLimit
		end,
		set = function(v)
			db.autoInviteMemberLimit = v
		end,
		clamp = function(v)
			local rounded = math.floor((tonumber(v) or def) + 0.5)
			return math.min(maxV, math.max(minV, rounded))
		end,
		enabled = function()
			return db.autoInviteMemberLimitEnabled == true
		end,
		onChanged = refreshApplicantInviteButtons,
	})

	registerSettingsRefresher(function()
		setAutoInviteLimitControlEnabled(db.autoInviteMemberLimitEnabled == true)
	end)
	setAutoInviteLimitControlEnabled(db.autoInviteMemberLimitEnabled == true)
end

local function applyFontAppearance()
	invokeSettingsTarget(GF.Font, "RefreshAll")
	invokeSettingsTarget(GF.ListColumns, "InvalidateCache")
	invokeSettingsTarget(GF.NavTree, "ScheduleLayoutRows")
	local layoutRequest = { force = true }
	invokeSettingsTarget(GF.FindGroupTab, "Relayout", layoutRequest)
	invokeSettingsTarget(GF.ApplicantsPanel, "Relayout", layoutRequest)
end

local function refreshFontAppearance()
	applyFontAppearance()
	local refreshers = {
		SP.UpdateFontDropdown,
		SP.UpdateFontOutlineDropdown,
	}
	for index = 1, #refreshers do
		refreshers[index](SP)
	end
end

local function setDropdownCaption(dropdown, caption)
	if not dropdown then
		return
	end
	dropdown:SetDefaultText(caption or "")
	local regenerate = dropdown.GenerateMenu
	if regenerate then
		regenerate(dropdown)
	end
end

local function optionLabel(options, selected, fallback)
	for index = 1, #options do
		local option = options[index]
		if option.value == selected then
			return option.label
		end
	end
	return fallback
end

local function installRadioOptions(dropdown, optionsFactory, currentValue, choose)
	local setup = dropdown and dropdown.SetupMenu
	if not setup then
		return false
	end
	setup(dropdown, function(_, rootDescription)
		local options = optionsFactory()
		for index = 1, #options do
			local option = options[index]
			local value = option.value
			rootDescription:CreateRadio(option.label, function()
				return currentValue() == value
			end, function()
				choose(value, option)
			end)
		end
	end)
	return true
end

local function applyModeOptions()
	local L = GF.L or {}
	return {
		{ value = GF.APPLY_MANUAL or "manual", label = L.SET_APPLY_MANUAL or "Manual" },
		{ value = GF.APPLY_CLICK_CONFIRM or "click_confirm", label = L.SET_APPLY_CLICK_CONFIRM or "Click row" },
		{ value = GF.APPLY_DBLCLICK_AUTO or "dblclick_auto", label = L.SET_APPLY_DBLCLICK_AUTO or "Double-click row" },
	}
end

local function currentApplyMode()
	local apply = GF.Apply
	return apply and apply.GetMode and apply:GetMode() or "manual"
end

function SP:SetupApplyDropdown()
	if installRadioOptions(self.applyDropdown, applyModeOptions,
		currentApplyMode, function(value)
			GF.GetDB().applyMode = value
			SP:UpdateApplyDropdown()
			local subtitle = GF.SubtitleBar
			if subtitle and subtitle.RefreshBrowseOptionToggles then
				subtitle:RefreshBrowseOptionToggles()
			end
		end)
	then
		self:UpdateApplyDropdown()
	end
end

function SP:UpdateApplyDropdown()
	local options = applyModeOptions()
	setDropdownCaption(self.applyDropdown,
		optionLabel(options, currentApplyMode(), options[1].label))
end

local function memberDisplayOptions()
	local L = GF.L or {}
	return {
		{ value = GF.MEMBER_DISPLAY_MODE_ROLE or "role", label = L.SET_MEMBER_DISPLAY_ROLE or "Role mode" },
		{ value = GF.MEMBER_DISPLAY_MODE_SPEC or "spec", label = L.SET_MEMBER_DISPLAY_SPEC or "Specialization mode" },
		{ value = GF.MEMBER_DISPLAY_MODE_SPEC_LARGE or "spec_large", label = L.SET_MEMBER_DISPLAY_SPEC_LARGE or "Specialization mode (large)" },
	}
end

local function currentMemberDisplayMode()
	return GF.GetMemberDisplayMode and GF.GetMemberDisplayMode()
		or GF.MEMBER_DISPLAY_MODE_ROLE or "role"
end

function SP:SetupMemberDisplayModeDropdown()
	if installRadioOptions(self.memberDisplayModeDropdown, memberDisplayOptions,
		currentMemberDisplayMode, function(value)
			if GF.SetMemberDisplayMode then
				GF.SetMemberDisplayMode(value)
			else
				GF.GetDB().memberDisplayMode = value
			end
			SP:UpdateMemberDisplayModeDropdown()
			refreshFindGroupMemberDisplay()
		end)
	then
		self:UpdateMemberDisplayModeDropdown()
	end
end

function SP:UpdateMemberDisplayModeDropdown()
	local options = memberDisplayOptions()
	setDropdownCaption(self.memberDisplayModeDropdown,
		optionLabel(options, currentMemberDisplayMode(), options[1].label))
end

local function memberTooltipOptions()
	local L = GF.L or {}
	return {
		{ value = GF.MEMBER_TOOLTIP_MODE_DETAILS or "details", label = L.SET_MEMBER_TOOLTIP_DETAILS or "Member detail mode" },
		{ value = GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT or "spec_count", label = L.SET_MEMBER_TOOLTIP_SPEC_COUNT or "Specialization count mode" },
	}
end

local function currentMemberTooltipMode()
	return GF.GetMemberTooltipMode and GF.GetMemberTooltipMode()
		or GF.MEMBER_TOOLTIP_MODE_DEFAULT
		or GF.MEMBER_TOOLTIP_MODE_DETAILS or "details"
end

function SP:SetupMemberTooltipModeDropdown()
	if installRadioOptions(self.memberTooltipModeDropdown, memberTooltipOptions,
		currentMemberTooltipMode, function(value)
			if GF.SetMemberTooltipMode then
				GF.SetMemberTooltipMode(value)
			else
				GF.GetDB().memberTooltipMode = value
			end
			SP:UpdateMemberTooltipModeDropdown()
		end)
	then
		self:UpdateMemberTooltipModeDropdown()
	end
end

function SP:UpdateMemberTooltipModeDropdown()
	local options = memberTooltipOptions()
	setDropdownCaption(self.memberTooltipModeDropdown,
		optionLabel(options, currentMemberTooltipMode(), options[1].label))
end

local function soundOptions()
	local L = GF.L or {}
	local options = {}
	local source = GF.GetApplicantAlertSoundOptions
		and GF.GetApplicantAlertSoundOptions() or {}
	for index = 1, #source do
		local sound = source[index]
		options[index] = {
			value = sound.file,
			label = (sound.labelKey and L[sound.labelKey])
				or sound.label or sound.file or "",
		}
	end
	return options
end

local function currentApplicantAlertSound()
	return GF.GetApplicantAlertSoundFile and GF.GetApplicantAlertSoundFile()
end

function SP:SetupApplicantAlertSoundDropdown()
	if installRadioOptions(self.applicantAlertSoundDropdown, soundOptions,
		currentApplicantAlertSound, function(value)
			if GF.SetApplicantAlertSoundFile then
				GF.SetApplicantAlertSoundFile(value)
			else
				GF.GetDB().applicantAlertSoundFile = value
			end
			SP:UpdateApplicantAlertSoundDropdown()
			local alerts = GF.ApplicantAlertService
			if alerts and alerts.Preview then
				alerts:Preview(value)
			end
		end)
	then
		self:UpdateApplicantAlertSoundDropdown()
	end
end

function SP:UpdateApplicantAlertSoundDropdown()
	local current = currentApplicantAlertSound()
	setDropdownCaption(self.applicantAlertSoundDropdown,
		optionLabel(soundOptions(), current, current or ""))
end

local function frameStrataOptions()
	local L = GF.L or {}
	return {
		{ value = "LOW", label = L.SET_FRAME_STRATA_LOW or "Low" },
		{ value = "MEDIUM", label = L.SET_FRAME_STRATA_MEDIUM or "Medium" },
		{ value = "HIGH", label = L.SET_FRAME_STRATA_HIGH or "High" },
		{ value = "DIALOG", label = L.SET_FRAME_STRATA_DIALOG or "Dialog" },
	}
end

function SP:SetupFrameStrataDropdown()
	if installRadioOptions(self.frameStrataDropdown, frameStrataOptions,
		GF.GetFrameStrata, function(value)
			GF.GetDB().frameStrata = value
			GF.ApplyFrameStrata(value)
			SP:UpdateFrameStrataDropdown()
		end)
	then
		self:UpdateFrameStrataDropdown()
	end
end

function SP:UpdateFrameStrataDropdown()
	local options = frameStrataOptions()
	setDropdownCaption(self.frameStrataDropdown,
		optionLabel(options, GF.GetFrameStrata(), options[2].label))
end

local function currentFontKey()
	return GF.Font.ResolveFontObjectKey(GF.GetDB().fontKey or "ChatFontNormal")
end

local function currentFontOutline()
	local outline = GF.GetDB().fontOutline or "NONE"
	return outline ~= "" and outline or "NONE"
end

function SP:SetupFontDropdown()
	if not GF.Font then
		return
	end
	if installRadioOptions(self.fontDropdown, GF.Font.GetFontOptions,
		currentFontKey, function(value)
			GF.GetDB().fontKey = value
			refreshFontAppearance()
		end)
	then
		self:UpdateFontDropdown()
	end
end

function SP:SetupFontOutlineDropdown()
	if not GF.Font then
		return
	end
	if installRadioOptions(self.fontOutlineDropdown, GF.Font.GetOutlineOptions,
		currentFontOutline, function(value)
			GF.GetDB().fontOutline = value
			refreshFontAppearance()
		end)
	then
		self:UpdateFontOutlineDropdown()
	end
end

function SP:UpdateFontOutlineDropdown()
	if not GF.Font then
		return
	end
	local key = currentFontOutline()
	setDropdownCaption(self.fontOutlineDropdown,
		optionLabel(GF.Font.GetOutlineOptions(), key, key))
end

function SP:UpdateFontDropdown()
	if not GF.Font then
		return
	end
	local db = GF.GetDB()
	local key = currentFontKey()
	local savedKey = db.fontKey or ""
	local label = key
	local options = GF.Font.GetFontOptions()
	for index = 1, #options do
		local option = options[index]
		if option.value == key or option.value == savedKey then
			label = option.label
			break
		end
	end
	if label == key and GF.GetLSMFontNameFromKey then
		label = GF.GetLSMFontNameFromKey(savedKey) or label
	end
	setDropdownCaption(self.fontDropdown, label)
end

function SP:CancelUpdateScrollDebounce()
	local pending = self._updateScrollDebounce
	self._updateScrollDebounce = nil
	local cancel = pending and pending.Cancel
	if cancel then
		cancel(pending)
	end
end

local function settingsPanelCanLayout(panel)
	local parent = panel.parent
	return not parent or parent:IsShown()
end

function SP:ScheduleUpdateScroll()
	if not settingsPanelCanLayout(self) then
		return
	end
	self:CancelUpdateScrollDebounce()
	local newTimer = C_Timer and C_Timer.NewTimer
	if type(newTimer) ~= "function" then
		self:UpdateScroll()
		return
	end
	local function updateAfterDelay()
		self._updateScrollDebounce = nil
		self:UpdateScroll()
	end
	self._updateScrollDebounce = newTimer(
		GF.LAYOUT_RESIZE_DEBOUNCE or 0.1, updateAfterDelay)
end

function SP:UpdateScroll()
	local scroll = self.scroll
	local body = self.body
	if not scroll or not body or self._updatingScroll
		or not settingsPanelCanLayout(self)
	then
		return
	end

	local scrollW = scroll:GetWidth()
	local scrollH = scroll:GetHeight()
	local layoutW = getSettingsLayoutWidth(self)
	if not scrollW
		or scrollW <= 0
		or not scrollH
		or scrollH <= 0
		or not layoutW
		or layoutW <= 0
	then
		return
	end

	local activePage = self.pages
		and self.pages[self._selectedCategoryID]
	local bodyH = activePage and activePage._gfBodyH
		or self.bodyH
		or 1
	local categoryID = self._selectedCategoryID or ""
	if self._lastScrollW == scrollW
		and self._lastScrollH == scrollH
		and self._lastLayoutW == layoutW
		and self._lastBodyH == bodyH
		and self._lastLayoutCategoryID == categoryID
	then
		return
	end

	self._updatingScroll = true
	self._lastScrollW = scrollW
	self._lastScrollH = scrollH
	self._lastLayoutW = layoutW
	self._lastBodyH = bodyH
	self._lastLayoutCategoryID = categoryID

	self.body:SetWidth(layoutW)
	self.body:SetHeight(bodyH)
	if activePage then
		activePage:SetHeight(bodyH)
	end
	GF.UI.UpdateScrollFrame(self.scroll)
	self._updatingScroll = false
end

local SETTINGS_CATEGORY_IDS = {
	"appearance",
	"party_list",
	"notifications",
	"tactical",
	"find_group",
}

local function getSettingsCategoryDefinitions()
	local L = GF.L or {}
	return {
		{
			id = "appearance",
			title = L.SET_CATEGORY_APPEARANCE
				or L.SET_SECTION_VISUAL_FONT
				or "Interface and appearance",
			description = L.SET_SECTION_VISUAL_FONT_DESC
				or "Customize the floating window, minimap button, Premade Groups entry, panel size, and text size.",
		},
		{
			id = "party_list",
			title = L.SET_CATEGORY_PARTY_LIST
				or L.SET_SECTION_LISTING
				or "List styles",
			description = L.SET_SECTION_LISTING_DESC
				or "Customize group and applicant list styles, and show party members by specialization or role.",
		},
		{
			id = "notifications",
			title = L.SET_CATEGORY_ALERTS
				or L.SET_SECTION_ALERTS
				or "Alerts and announcements",
			description = L.SET_SECTION_ALERTS_DESC
				or "Customize applicant sounds, group-formed popups, Mythic+ teleport announcements, and keystone announcements.",
		},
		{
			id = "tactical",
			title = L.SET_CATEGORY_TACTICAL
				or L.SET_SECTION_MPLUS_TACTICAL
				or "Tactical announcements",
			description = L.SET_SECTION_MPLUS_TACTICAL_DESC
				or "Customize tactical announcements for current-season Mythic+ dungeons.",
		},
		{
			id = "find_group",
			title = L.SET_CATEGORY_FIND_GROUP
				or L.SET_SECTION_FIND_GROUP
				or "Advanced settings",
			description = L.SET_SECTION_FIND_GROUP_DESC
				or "Advanced filters, auto-join, auto-invite, default item level, blocklist, and more.",
		},
	}
end

local function createSettingsPage(self, categoryID)
	local page = CreateFrame("Frame", nil, self.body)
	page._gfSettingsChromeLevels =
		self._settingsChromeLevels
	page:SetPoint(
		"TOPLEFT",
		self.body,
		"TOPLEFT",
		SCROLL_INSET_L,
		0)
	page:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", 0, 0)
	page:SetHeight(1)
	page:Hide()
	self.pages[categoryID] = page
	return page, -OPTIONS_CONTENT_TOP_OFFSET
end

local function finishSettingsPage(page, y)
	local height = math.max(
		1,
		-y - SECTION_GAP + OPTIONS_CONTENT_BOTTOM_PADDING)
	page._gfBodyH = height
	page:SetHeight(height)
	return height
end

GF.SettingsTacticalPage:Install(SP, {
	registerSettingsRefresher = registerSettingsRefresher,
	styleSettingsLabel = styleSettingsLabel,
	fitSettingsText = fitSettingsText,
	bindSettingsTextFit = bindSettingsTextFit,
	bindSettingsLocaleText = function(...)
		return SP.LocaleBinding:BindText(...)
	end,
	applyOptionsFeaturePanelStyle =
		applyOptionsFeaturePanelStyle,
	styleSettingsNumberBox = styleSettingsNumberBox,
	bindSettingsControlTooltip =
		bindSettingsControlTooltip,
	setSettingsWidgetEnabled = setSettingsWidgetEnabled,
	getMythicPlusAnnouncementService =
		getMythicPlusAnnouncementService,
	getMythicPlusAnnouncementValue =
		getMythicPlusAnnouncementValue,
	setMythicPlusAnnouncementValue =
		setMythicPlusAnnouncementValue,
	createSettingsSection = createSettingsSection,
	styleVisualAppearancePanel =
		styleVisualAppearancePanel,
	updateSettingsSectionHeights =
		updateSettingsSectionHeights,
	finishSettingsSection = finishSettingsSection,
})

local function updateSettingsCategoryButton(button, selected)
	if not button then
		return
	end
	button._navSelected = selected == true
	GF.Icons.ApplyNavButtonState(button)
end

local function createSettingsCategoryButton(self, definition, index)
	local button =
		GF.NavTree.CreateNavRowFrame(self.menuHost)
	local y = SETTINGS_MENU_TOP_INSET
		+ ((index - 1)
			* (SETTINGS_MENU_ROW_H + SETTINGS_MENU_ROW_SPACING))
	button:SetPoint(
		"TOPLEFT",
		self.menuHost,
		"TOPLEFT",
		0,
		-y)
	button:SetPoint("TOPRIGHT", self.menuHost, "TOPRIGHT", 0,
		-y)
	button:SetHeight(SETTINGS_MENU_ROW_H)

	button.categoryID = definition.id
	button._navHover = false
	button._navPressed = false
	GF.Icons.ApplyNavButton(
		button,
		0,
		definition.title or "",
		SETTINGS_MENU_W,
		SETTINGS_MENU_ROW_H,
		{ selected = false })
	if button.label then
		button.label:SetJustifyH("LEFT")
		fitSettingsText(button.label, button.label:GetWidth(), 8)
		SP.LocaleBinding:BindText(
			button.label,
			definition.title or "",
			nil,
			function(target)
				fitSettingsText(
					target,
					math.max(1, target:GetWidth() or 0),
					8
				)
			end
		)
	end
	button.hit:RegisterForClicks("LeftButtonUp")
	button.hit:SetFrameLevel(button:GetFrameLevel() + 8)
	button.hit:SetScript("OnClick", function()
		SP:SelectCategory(definition.id)
	end)
	button.hit:SetScript("OnEnter", function()
		button._navHover = true
		updateSettingsCategoryButton(button, button._navSelected)
	end)
	button.hit:SetScript("OnLeave", function()
		button._navHover = false
		button._navPressed = false
		updateSettingsCategoryButton(button, button._navSelected)
	end)
	button.hit:SetScript("OnMouseDown", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			button._navPressed = true
			updateSettingsCategoryButton(button, button._navSelected)
		end
	end)
	button.hit:SetScript("OnMouseUp", function()
		button._navPressed = false
		updateSettingsCategoryButton(button, button._navSelected)
	end)
	updateSettingsCategoryButton(button, false)
	return button
end

function SP:UpdateCategoryButtons()
	for categoryID, button in pairs(self.categoryButtons or {}) do
		updateSettingsCategoryButton(
			button,
			categoryID == self._selectedCategoryID)
	end
end

function SP:RefreshCategoryLocale()
	self.categoryDefinitions =
		getSettingsCategoryDefinitions()
	self.categoryInfoByID = {}
	for _, definition in ipairs(
		self.categoryDefinitions
	) do
		self.categoryInfoByID[definition.id] =
			definition
		local button = self.categoryButtons
			and self.categoryButtons[definition.id]
		if button and button.label then
			button.label:SetText(definition.title or "")
			fitSettingsText(
				button.label,
				math.max(
					1,
					button.label:GetWidth() or 0
				),
				8
			)
		end
	end
	local definition = self.categoryInfoByID[
		self._selectedCategoryID
			or SETTINGS_CATEGORY_IDS[1]
	]
	if self.pageTitle then
		self.pageTitle:SetText(
			definition and definition.title or ""
		)
	end
	if self.pageDescription then
		self.pageDescription:SetText(
			definition and definition.description or ""
		)
	end
	self:FitCategoryHeader()
	self:UpdateCategoryButtons()
end

function SP:FitCategoryHeader()
	for _, fontString in ipairs({
		self.pageTitle,
		self.pageDescription,
	}) do
		local width = fontString and fontString:GetWidth() or 0
		if width and width > 20 then
			fitSettingsText(
				fontString,
				width,
				fontString._gfFitMinimumSize or 10)
		end
	end
end

function SP:SelectCategory(categoryID)
	if not self.pages or not self.pages[categoryID] then
		categoryID = SETTINGS_CATEGORY_IDS[1]
	end
	if not categoryID or not self.pages or not self.pages[categoryID] then
		return
	end

	self._categoryScrollOffsets = self._categoryScrollOffsets or {}
	local previousID = self._selectedCategoryID
	if previousID
		and not self._preserveCategoryScrollOnInit
		and self.scroll
		and self.scroll.GetVerticalScroll
	then
		self._categoryScrollOffsets[previousID] =
			self.scroll:GetVerticalScroll() or 0
	end

	for id, page in pairs(self.pages) do
		page:SetShown(id == categoryID)
	end
	self._selectedCategoryID = categoryID

	local definition = self.categoryInfoByID
		and self.categoryInfoByID[categoryID]
	if self.pageTitle then
		self.pageTitle:SetText(
			definition and definition.title or "")
	end
	if self.pageDescription then
		self.pageDescription:SetText(
			definition and definition.description or "")
	end
	self:FitCategoryHeader()
	self:UpdateCategoryButtons()

	self._lastBodyH = nil
	self._lastLayoutCategoryID = nil
	self:UpdateScroll()
	if self.scroll and self.scroll.SetVerticalScroll then
		self.scroll:SetVerticalScroll(
			self._categoryScrollOffsets[categoryID] or 0)
	end
end

local RESET_POPUP_WIDTH = 520
local RESET_POPUP_TEXT_WIDTH = 480

local function restoreResetPopupLayout(dialog)
	local state = dialog and dialog._gfResetPopupLayoutState
	if not state then
		return
	end
	local text = dialog.GetTextFontString
		and dialog:GetTextFontString() or dialog.Text
	if text then
		if state.wordWrap ~= nil and text.SetWordWrap then
			text:SetWordWrap(state.wordWrap)
		end
		if state.maxLines ~= nil and text.SetMaxLines then
			text:SetMaxLines(state.maxLines)
		end
		if state.justifyH and text.SetJustifyH then
			text:SetJustifyH(state.justifyH)
		end
	end
	if state.resize then
		dialog.Resize = state.resize
	end
	dialog._gfResetPopupLayoutState = nil
end

local function applyResetPopupLayout(dialog)
	local text = dialog and dialog.GetTextFontString
		and dialog:GetTextFontString() or dialog and dialog.Text
	if not (dialog and text) then
		return
	end
	if text.SetWordWrap then
		text:SetWordWrap(false)
	end
	if text.SetMaxLines then
		text:SetMaxLines(1)
	end
	if text.SetJustifyH then
		text:SetJustifyH("CENTER")
	end
	if text.SetDesiredWidth then
		text:SetDesiredWidth(RESET_POPUP_TEXT_WIDTH)
	elseif text.SetWidth then
		text:SetWidth(RESET_POPUP_TEXT_WIDTH)
	end
	if dialog.SetMinimumWidth then
		dialog:SetMinimumWidth(RESET_POPUP_WIDTH)
	elseif dialog.SetWidth then
		dialog:SetWidth(RESET_POPUP_WIDTH)
	end
	if dialog.SetWidthPadding then
		dialog:SetWidthPadding(0)
	end
	if dialog.Layout then
		dialog:Layout()
		dialog:Layout()
	end
end

local function installResetPopupLayout(dialog)
	restoreResetPopupLayout(dialog)
	local text = dialog and dialog.GetTextFontString
		and dialog:GetTextFontString() or dialog and dialog.Text
	if not (dialog and text and type(dialog.Resize) == "function") then
		return
	end
	local originalResize = dialog.Resize
	dialog._gfResetPopupLayoutState = {
		resize = originalResize,
		wordWrap = text.GetWordWrap and text:GetWordWrap() or nil,
		maxLines = text.GetMaxLines and text:GetMaxLines() or nil,
		justifyH = text.GetJustifyH and text:GetJustifyH() or nil,
	}
	dialog.Resize = function(self, ...)
		originalResize(self, ...)
		applyResetPopupLayout(self)
	end
end

local function ensureResetPopup()
	local registry = StaticPopupDialogs
	if type(registry) ~= "table" or registry[RESET_POPUP] then
		return
	end
	local L = GF.L or {}
	local confirmLabel = L.SET_MPLUS_SETTING_CONFIRM
		or YES or OKAY or "Confirm"
	registry[RESET_POPUP] = {
		text = "%s",
		button1 = confirmLabel,
		button2 = L.CANCEL or CANCEL or "Cancel",
		OnShow = installResetPopupLayout,
		OnHide = restoreResetPopupLayout,
		OnAccept = function(_, categoryID)
			SP:ResetCategoryDefaults(categoryID)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		fullScreenCover = true,
	}
end

local function formatResetConfirmation(categoryID)
	local L = GF.L or {}
	local definition = SP.categoryInfoByID
		and SP.categoryInfoByID[categoryID]
	local title = definition and definition.title
		or tostring(categoryID or "")
	local template
	if categoryID == "tactical" then
		template = L.SET_RESET_TACTICAL_CONFIRM
			or "Reset seasonal notices and draft? Other settings unchanged."
	else
		template = L.SET_RESET_CATEGORY_CONFIRM
			or "Reset \"%s\" to defaults? Other categories unchanged."
	end
	local ok, text = pcall(string.format, template, title)
	return ok and text or template
end

local function applyNotificationDefaults(owner)
	if owner.mythicPlusTeleportMessageBox
		and owner.mythicPlusTeleportMessageBox.ClearFocus
	then
		owner.mythicPlusTeleportMessageBox:ClearFocus()
	end
	local defaults = GF.defaults
		and GF.defaults.mythicPlus
		and GF.defaults.mythicPlus.settings
		or {}
	setMythicPlusAnnouncementValue(
		"SetTeleportFollowEnabled",
		defaults.teleportFollowEnabled ~= false
	)
	setMythicPlusAnnouncementValue(
		"SetTeleportAnnouncementEnabled",
		defaults.teleportAnnouncementEnabled ~= false
	)
	setMythicPlusAnnouncementValue(
		"SetKeystoneAnnouncementEnabled",
		defaults.keystoneAnnouncementEnabled == true
	)
	setMythicPlusAnnouncementValue(
		"SetTeleportMessage",
		""
	)
end

function SP:ResetCategoryDefaults(categoryID)
	if not self.pages or not self.pages[categoryID] then
		return false
	end
	if categoryID ~= "tactical"
		and not GF.ResetSettingsCategory
	then
		return false
	end
	if activeSettingsNumberBox
		and activeSettingsNumberBox.ClearFocus
	then
		activeSettingsNumberBox:ClearFocus()
	end
	if categoryID == "notifications" then
		applyNotificationDefaults(self)
	end

	local reset
	if categoryID == "tactical" then
		reset = self.ResetCurrentTacticalAnnouncements
			and self:ResetCurrentTacticalAnnouncements() ~= nil
	else
		local _, restored =
			GF.ResetSettingsCategory(categoryID)
		reset = restored == true
	end
	if not reset then
		return false
	end

	if categoryID == "party_list" then
		if GF.ApplicantsPanel
			and GF.ApplicantsPanel.Refresh
		then
			GF.ApplicantsPanel:Refresh({
				preserveScroll = true,
			})
		end
	elseif categoryID == "find_group" then
		if GF.Apply and GF.Apply.ClearApplyNoteState then
			GF.Apply:ClearApplyNoteState()
		end
		local db = GF.GetDB and GF.GetDB()
		if db
			and db.autoAcceptInvite == true
			and GF.Apply
		then
			if GF.Apply.TryAutoAcceptInvite then
				GF.Apply:TryAutoAcceptInvite()
			end
			if GF.Apply.QueueAutoConfirmLfgListRoleCheck then
				GF.Apply:QueueAutoConfirmLfgListRoleCheck()
			end
		end
		if GF.Blocklist and GF.Blocklist.RebuildMaps then
			GF.Blocklist:RebuildMaps()
		end
		if GF.SubtitleBar
			and GF.SubtitleBar.RefreshBrowseOptionToggles
		then
			GF.SubtitleBar:RefreshBrowseOptionToggles()
		end
	end

	if GF.ApplyAllSettings then
		GF.ApplyAllSettings()
	end
	if self.RefreshFromDB then
		self:RefreshFromDB()
	end
	return true
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
	self:UpdateApplicantAlertSoundDropdown()
	self:UpdateScroll()
end

function SP:RefreshLocale()
	if not self.parent or not self.scroll then
		return
	end
	self:CaptureTacticalDraft()
	self._categoryScrollOffsets =
		self._categoryScrollOffsets or {}
	local selectedCategoryID =
		self._selectedCategoryID
			or SETTINGS_CATEGORY_IDS[1]
	self._selectedCategoryID = selectedCategoryID
	local scrollOffset = 0
	if self._selectedCategoryID
		and self.scroll.GetVerticalScroll
	then
		scrollOffset =
			self.scroll:GetVerticalScroll() or 0
		self._categoryScrollOffsets[
			self._selectedCategoryID] = scrollOffset
	end
	self:CancelUpdateScrollDebounce()
	if StaticPopup_Hide then
		StaticPopup_Hide(RESET_POPUP)
	end
	if StaticPopupDialogs then
		StaticPopupDialogs[RESET_POPUP] = nil
	end
	if GameTooltip_Hide then
		GameTooltip_Hide()
	end
	if GF.SettingsTacticalPage then
		GF.SettingsTacticalPage.HideUnsavedPopup()
		GF.SettingsTacticalPage.ResetPopupDefinition()
	end

	local originalContainer = self.container
	local originalBindingCount =
		#(SP.LocaleBinding.bindings or {})
	SP.LocaleBinding:Refresh()
	self:RefreshCategoryLocale()
	if GF.SettingsTacticalPage
		and GF.SettingsTacticalPage.RefreshLocale
	then
		GF.SettingsTacticalPage.RefreshLocale(self)
	end

	self._lastScrollW = nil
	self._lastScrollH = nil
	self._lastLayoutW = nil
	self._lastBodyH = nil
	self._lastLayoutCategoryID = nil
	self:RefreshFromDB()
	self:UpdateScroll()
	if self.scroll and self.scroll.SetVerticalScroll then
		self.scroll:SetVerticalScroll(
			scrollOffset
		)
	end
	self._localeRefreshFrameStable =
		self.container == originalContainer
	self._localeRefreshBindingCount =
		#(SP.LocaleBinding.bindings or {})
	self._localeRefreshBindingCountStable =
		self._localeRefreshBindingCount
			== originalBindingCount
end





local function handleSettingsScrollSizeChanged(scroll)
	if SP._frameResizing or SP._updatingScroll
		or (SP.parent and not SP.parent:IsShown())
	then
		return
	end
	local width = tonumber(scroll:GetWidth()) or 0
	local height = tonumber(scroll:GetHeight()) or 0
	local layoutWidth = tonumber(getSettingsLayoutWidth(SP)) or 0
	if width < 10 or height < 10 or layoutWidth < 10 then
		return
	end
	if layoutWidth ~= SP._lastLayoutW or height ~= SP._lastScrollH then
		SP:ScheduleUpdateScroll()
	end
end

function SP:Init(parent)
	if self.scroll then
		return
	end

	self.parent = parent
	SP.LocaleBinding:Reset()

	local L = GF.L or {}
	local db = GF.GetDB()

	self.container = CreateFrame("Frame", nil, parent)
	self.container:SetAllPoints(parent)
	self.container:SetFrameLevel(parent:GetFrameLevel() + 1)

	self.menuHost = CreateFrame("Frame", nil, self.container)
	self.menuHost:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, 0)
	self.menuHost:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", 0, 0)
	self.menuHost:SetWidth(SETTINGS_INIT_LAYOUT.menuW)
	self.menuHost:SetClipsChildren(true)
	self.menuHost:SetFrameLevel(self.container:GetFrameLevel() + 2)

	local menuBackground =
		self.menuHost:CreateTexture(nil, "BACKGROUND")
	menuBackground:SetAllPoints(self.menuHost)
	setTextureColor(menuBackground, 0.015, 0.012, 0.008, 0.72)
	self.menuHost.background = menuBackground

	self.contentHost = CreateFrame("Frame", nil, self.container)
	self.contentHost:SetPoint(
		"TOPLEFT",
		self.menuHost,
		"TOPRIGHT",
		GF.NAV_DIVIDER_OFFSET_X or -3,
		0)
	self.contentHost:SetPoint(
		"BOTTOMRIGHT",
		self.container,
		"BOTTOMRIGHT",
		0,
		0)
	self.contentHost:SetFrameLevel(self.container:GetFrameLevel() + 2)

	local contentFrameLevel = self.contentHost:GetFrameLevel()
	self._settingsChromeLevels = {
		dividerBase = contentFrameLevel + 1,
		scroll = contentFrameLevel + 2,
		sectionBackground = contentFrameLevel + 3,
		sectionContent = contentFrameLevel + 4,
		dividerAccent = contentFrameLevel + 5,
	}

	-- The right content host owns the complete settings-column junction.
	-- Keep the divider base below scroll content, section title art above
	-- the base, and the center accent above both so page Show/Hide cannot
	-- change which region wins the overlap.
	self.menuDivider =
		CreateFrame("Frame", nil, self.contentHost)
	if GF.UI and GF.UI.InstallNavColumnDivider then
		GF.UI.InstallNavColumnDivider(self.menuDivider)
	end
	self.menuDivider:SetPoint(
		"TOP",
		self.contentHost,
		"TOPLEFT",
		0,
		-(GF.NAV_DIVIDER_TOP_OFFSET or 4))
	self.menuDivider:SetPoint(
		"BOTTOM",
		self.contentHost,
		"BOTTOMLEFT",
		0,
		GF.NAV_DIVIDER_BOTTOM_OFFSET or 2)
	self.menuDivider:SetWidth(GF.NAV_DIVIDER_W or 3)
	self.menuDivider:SetFrameLevel(
		self._settingsChromeLevels.dividerBase)
	local dividerParts =
		self.menuDivider._gfMeetingStoneDivider
	if dividerParts and dividerParts.centerAccent then
		dividerParts.centerAccent:SetFrameLevel(
			self._settingsChromeLevels.dividerAccent)
	end

	self.pageHeader = CreateFrame("Frame", nil, self.contentHost)
	self.pageHeader:SetPoint(
		"TOPLEFT",
		self.contentHost,
		"TOPLEFT",
		0,
		0)
	self.pageHeader:SetPoint(
		"TOPRIGHT",
		self.contentHost,
		"TOPRIGHT",
		0,
		0)
	self.pageHeader:SetHeight(SETTINGS_INIT_LAYOUT.pageHeaderH)
	self.pageHeader:SetFrameLevel(
		self._settingsChromeLevels.sectionBackground)

	local headerBackground =
		self.pageHeader:CreateTexture(nil, "BACKGROUND")
	headerBackground:SetPoint(
		"TOPLEFT",
		self.pageHeader,
		"TOPLEFT",
		SETTINGS_INIT_LAYOUT.pageHeaderBackgroundInsetL,
		0)
	headerBackground:SetPoint(
		"BOTTOMRIGHT",
		self.pageHeader,
		"BOTTOMRIGHT",
		0,
		0)
	setTextureColor(headerBackground, 0.02, 0.015, 0.01, 0.72)

	local headerRule =
		self.pageHeader:CreateTexture(nil, "ARTWORK")
	local hasHeaderRuleAtlas = GF.UI
		and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(
			headerRule,
			"Options_HorizontalDivider",
			true)
	local headerRuleColor =
		GF.BROWSE_HEADER_TEXT_COLOR or { 1, 0.82, 0, 1 }
	if hasHeaderRuleAtlas then
		headerRule:SetVertexColor(
			headerRuleColor[1] or 1,
			headerRuleColor[2] or 0.82,
			headerRuleColor[3] or 0,
			headerRuleColor[4] or 1)
	else
		setTextureColor(
			headerRule,
			headerRuleColor[1] or 1,
			headerRuleColor[2] or 0.82,
			headerRuleColor[3] or 0,
			headerRuleColor[4] or 1)
		headerRule:SetHeight(1)
	end
	headerRule:SetPoint(
		"BOTTOMLEFT",
		self.pageHeader,
		"BOTTOMLEFT",
		SETTINGS_INIT_LAYOUT.pageHeaderRuleInsetL,
		0)
	headerRule:SetPoint(
		"BOTTOMRIGHT",
		self.pageHeader,
		"BOTTOMRIGHT",
		-SETTINGS_INIT_LAYOUT.pageHeaderRuleInsetX,
		0)

	self.resetDefaultsBtn = GF.UI.CreatePanelButton(
		self.pageHeader,
		L.SET_RESET_ALL or "Reset defaults",
		GF.PANEL_BUTTON_STANDARD_W or 72)
	self.resetDefaultsBtn:SetPoint(
		"RIGHT",
		self.pageHeader,
		"RIGHT",
		-20,
		0)
	fitSettingsText(
		self.resetDefaultsBtn:GetFontString(),
		math.max(1, self.resetDefaultsBtn:GetWidth() - 12),
		8)
	SP.LocaleBinding:BindText(
		self.resetDefaultsBtn,
		L.SET_RESET_ALL or "Reset defaults",
		nil,
		function(target)
			fitSettingsText(
				target:GetFontString(),
				math.max(1, target:GetWidth() - 12),
				8
			)
		end
	)
	self.resetDefaultsBtn:SetScript("OnClick", function()
		local categoryID = self._selectedCategoryID
		ensureResetPopup()
		if StaticPopup_Show and categoryID then
			StaticPopup_Show(
				RESET_POPUP,
				formatResetConfirmation(categoryID),
				nil,
				categoryID
			)
		end
	end)

	self.usageGuideIcon = GF.UI.CreateHelpIcon(
		self.pageHeader,
		L.USAGE_GUIDE_BTN or L.USAGE_GUIDE_TITLE or "Guide",
		40)
	self.usageGuideIcon:SetPoint(
		"RIGHT",
		self.resetDefaultsBtn,
		"LEFT",
		-8,
		0)
	SP.LocaleBinding:BindText(
		self.usageGuideIcon,
		L.USAGE_GUIDE_BTN
			or L.USAGE_GUIDE_TITLE
			or "Guide",
		function(target, text)
			target._gfTooltip = text
		end
	)
	self.usageGuideIcon:SetScript("OnClick", function()
		local dialog = GF.UsageGuideDialog
		local show = dialog and dialog.Show
		if show then
			show(dialog)
		end
	end)

	self.pageTitle = GF.UI.CreateFontString(
		self.pageHeader,
		"OVERLAY",
		"GameFontNormalLarge")
	self.pageTitle:SetPoint(
		"TOPLEFT",
		self.pageHeader,
		"TOPLEFT",
		SETTINGS_INIT_LAYOUT.pageHeaderInsetX,
		-8)
	self.pageTitle:SetHeight(SETTINGS_INIT_LAYOUT.pageHeaderTitleH)
	self.pageTitle:SetJustifyH("LEFT")
	self.pageTitle:SetJustifyV("MIDDLE")
	self.pageTitle:SetWordWrap(false)
	self.pageTitle:SetTextColor(1, 0.82, 0, 1)
	self.pageTitle._gfFontSizeOverride =
		SETTINGS_INIT_LAYOUT.pageTitleTextSize
	self.pageTitle._gfFontFlagsOverride = "OUTLINE"
	self.pageTitle._gfFitMinimumSize = 12
	styleSettingsLabel(self.pageTitle, "GameFontNormalLarge")

	self.pageDescription = GF.UI.CreateFontString(
		self.pageHeader,
		"OVERLAY",
		"GameFontHighlightSmall")
	self.pageDescription:SetPoint(
		"TOPLEFT",
		self.pageTitle,
		"BOTTOMLEFT",
		0,
		0)
	self.pageDescription:SetHeight(SETTINGS_INIT_LAYOUT.pageHeaderDescH)
	self.pageDescription:SetJustifyH("LEFT")
	self.pageDescription:SetJustifyV("MIDDLE")
	self.pageDescription:SetWordWrap(false)
	self.pageDescription:SetTextColor(0.72, 0.70, 0.66, 1)
	self.pageDescription._gfFontSizeOverride =
		SETTINGS_INIT_LAYOUT.pageDescriptionTextSize
	self.pageDescription._gfFitMinimumSize = 10
	styleSettingsLabel(self.pageDescription, "GameFontHighlightSmall")
	local function updatePageHeaderTextLayout()
		local availableWidth = math.max(
			20,
			(self.pageHeader:GetWidth() or 0)
				- SETTINGS_INIT_LAYOUT.pageHeaderInsetX
				- 20
				- self.resetDefaultsBtn:GetWidth()
				- 8
				- self.usageGuideIcon:GetWidth()
				- 12)
		self.pageTitle:SetWidth(availableWidth)
		self.pageDescription:SetWidth(availableWidth)
		SP:FitCategoryHeader()
	end
	self.pageHeader:HookScript(
		"OnSizeChanged",
		updatePageHeaderTextLayout)
	updatePageHeaderTextLayout()

	self.scroll = GF.UI.CreateScrollFrame(
		self.contentHost,
		{ rowHeight = GF.SETTINGS_WHEEL_ROW_H or 24 })
	self.scroll:SetPoint(
		"TOPLEFT",
		self.contentHost,
		"TOPLEFT",
		SETTINGS_INIT_LAYOUT.scrollInsetL,
		-SETTINGS_INIT_LAYOUT.pageHeaderH)
	self.scroll:SetPoint(
		"BOTTOMRIGHT",
		self.contentHost,
		"BOTTOMRIGHT",
		-SETTINGS_INIT_LAYOUT.scrollInsetR,
		GF.CONTENT_SCROLL_INSET_B or 0)
	self.scroll:SetFrameLevel(
		self._settingsChromeLevels.scroll)
	local scrollBody = CreateFrame("Frame", nil, self.scroll)
	self.body = scrollBody
	self.scroll:SetScrollChild(scrollBody)
	scrollBody:SetSize(1, 1)
	self.scrollBar = GF.UI.BindMinimalScrollBar(
		self.scroll,
		SETTINGS_INIT_LAYOUT.scrollBarGap,
		self.contentHost,
		true)
	if self.scrollBar then
		self.scrollBar:SetWidth(SETTINGS_INIT_LAYOUT.scrollBarWidth)
		self.scrollBar:ClearAllPoints()
		self.scrollBar:SetPoint(
			"TOPLEFT",
			self.scroll,
			"TOPRIGHT",
			SETTINGS_INIT_LAYOUT.scrollBarGap,
			-SETTINGS_INIT_LAYOUT.scrollBarTopInset)
		self.scrollBar:SetPoint(
			"BOTTOMLEFT",
			self.scroll,
			"BOTTOMRIGHT",
			SETTINGS_INIT_LAYOUT.scrollBarGap,
			SETTINGS_INIT_LAYOUT.scrollBarBottomInset)
	end

	self.categoryDefinitions = getSettingsCategoryDefinitions()
	self.categoryInfoByID = {}
	self.categoryButtons = {}
	for index, definition in ipairs(self.categoryDefinitions) do
		self.categoryInfoByID[definition.id] = definition
		self.categoryButtons[definition.id] =
			createSettingsCategoryButton(self, definition, index)
	end

	self.pages = {}
	local appearancePage, y =
		createSettingsPage(self, "appearance")
	local partyListPage, partyY =
		createSettingsPage(self, "party_list")
	local findGroupPage, findY =
		createSettingsPage(self, "find_group")
	local notificationsPage, notificationsY =
		createSettingsPage(self, "notifications")
	local tacticalPage, tacticalY =
		createSettingsPage(self, "tactical")
	local section
	local sectionGroup

	section = createSettingsSection(
		appearancePage,
		L.SET_SECTION_VISUAL_FONT or L.SET_SECTION_VISUAL or "Visual",
		y)

	styleVisualAppearancePanel(section, true)
	local visualGroup = createVisualSettingsGroup(section, L.SET_SECTION_INTERFACE or "Floating window and entry")
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
	addTwoColumnCheckRow(visualGroup, {
		label = L.SET_PREF_OPEN or "Take over Premade Groups entry",
		tooltip = L.SET_PREF_OPEN_HINT or "",
		getter = function()
			return db.preferOpen
		end,
		setter = function(v)
			db.preferOpen = v
			if GF.Hook and GF.Hook.Refresh then
				GF.Hook.Refresh()
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
	finishVisualSettingsGroup(section, visualGroup, 0)
	y = finishSettingsSection(section, y)

	section, sectionGroup = createSingleCardSettingsSection(
		findGroupPage,
		L.SET_SECTION_ENTRY_FILTER or "Custom settings",
		findY)
	addCheckRow(sectionGroup, L.SET_AUTO_EXPAND_FILTER or "Auto-expand filter", L.SET_AUTO_EXPAND_FILTER_HINT or "", function()
		return db.autoExpandFilter == true
	end, function(v)
		db.autoExpandFilter = v
	end)
	self.defaultRequiredItemLevelBox = addIntInputRow(sectionGroup, {
		label = L.SET_DEFAULT_REQUIRED_ITEM_LEVEL or "Default item level",
		tooltip = L.SET_DEFAULT_REQUIRED_ITEM_LEVEL_HINT or "",
		default = GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0,
		maxLetters = 4,
		get = function()
			return GF.GetDefaultRequiredItemLevel
				and GF.GetDefaultRequiredItemLevel()
				or (GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0)
		end,
		set = function(v)
			if GF.SetDefaultRequiredItemLevel then
				GF.SetDefaultRequiredItemLevel(v)
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
	addAutoInviteLimitRow(sectionGroup, db)
	findY = finishSingleCardSettingsSection(section, sectionGroup, findY)

	section, sectionGroup = createSingleCardSettingsSection(
		notificationsPage,
		L.SET_SECTION_ALERTS or "Sounds and announcements",
		notificationsY)
	self.applicantAlertSoundDropdown = addDropdownSettingRow(sectionGroup, L.SET_APPLICANT_ALERT_SOUND or "Applicant alert sound", L.SET_APPLICANT_ALERT_SOUND_HINT or "")
	self:SetupApplicantAlertSoundDropdown()
	local joinAnnouncePreviewW = GF.PANEL_BUTTON_STANDARD_W or 72
	local joinAnnounceRow = addCheckRow(sectionGroup, L.SET_JOIN_ANNOUNCE or "Join announce", L.SET_JOIN_ANNOUNCE_HINT or "", function()
		return db.joinAnnounceEnabled == true
	end, function(v)
		db.joinAnnounceEnabled = v and true or false
	end)
	self.joinAnnouncePreviewBtn = GF.UI.CreatePanelButton(joinAnnounceRow.control, L.SET_JOIN_ANNOUNCE_PREVIEW or "Preview popup", joinAnnouncePreviewW)
	self.joinAnnouncePreviewBtn:SetPoint("RIGHT", joinAnnounceRow.control, "RIGHT", 0, 0)
	fitSettingsText(
		self.joinAnnouncePreviewBtn:GetFontString(),
		math.max(1, self.joinAnnouncePreviewBtn:GetWidth() - 12),
		8)
	SP.LocaleBinding:BindText(
		self.joinAnnouncePreviewBtn,
		L.SET_JOIN_ANNOUNCE_PREVIEW or "Preview popup",
		nil,
		function(target)
			fitSettingsText(
				target:GetFontString(),
				math.max(1, target:GetWidth() - 12),
				8
			)
		end
	)
	self.joinAnnouncePreviewBtn:SetScript("OnClick", function()
		if GF.JoinAnnounce and GF.JoinAnnounce.PreviewToast then
			GF.JoinAnnounce:PreviewToast()
		end
	end)
	notificationsY = finishSingleCardSettingsSection(section, sectionGroup, notificationsY)

	section, sectionGroup = createSingleCardSettingsSection(
		notificationsPage,
		L.SET_SECTION_MPLUS_TELEPORT or "Teleport and announcements",
		notificationsY)
	local followRow, followCheck = addMythicPlusAnnouncementCheckRow(
		sectionGroup,
		L.SET_MPLUS_TELEPORT_FOLLOW or "Follow teleport",
		L.SET_MPLUS_TELEPORT_FOLLOW_HINT or "",
		"IsTeleportFollowEnabled",
		"SetTeleportFollowEnabled"
	)
	self.mythicPlusTeleportFollowCheck = followCheck
	self.mythicPlusTeleportPreviewButton = GF.UI.CreatePanelButton(
		followRow.control,
		L.SET_MPLUS_TELEPORT_PREVIEW or "Preview popup",
		GF.PANEL_BUTTON_STANDARD_W or 72
	)
	self.mythicPlusTeleportPreviewButton:SetPoint("RIGHT", followRow.control, "RIGHT", 0, 0)
	fitSettingsText(
		self.mythicPlusTeleportPreviewButton:GetFontString(),
		math.max(
			1,
			self.mythicPlusTeleportPreviewButton:GetWidth() - 12),
		8)
	SP.LocaleBinding:BindText(
		self.mythicPlusTeleportPreviewButton,
		L.SET_MPLUS_TELEPORT_PREVIEW
			or "Preview popup",
		nil,
		function(target)
			fitSettingsText(
				target:GetFontString(),
				math.max(1, target:GetWidth() - 12),
				8
			)
		end
	)
	self.mythicPlusTeleportPreviewButton:SetScript("OnClick", function()
		local debugService = GF.MythicPlusDebugService
		if debugService and type(debugService.ShowTeleportDialogPreview) == "function" then
			pcall(debugService.ShowTeleportDialogPreview, debugService)
		end
	end)
	bindSettingsControlTooltip(
		self.mythicPlusTeleportPreviewButton,
		L.SET_MPLUS_TELEPORT_PREVIEW_HINT or L.SET_MPLUS_TELEPORT_FOLLOW_HINT or ""
	)
	local function refreshTeleportPreviewAvailability()
		local debugService = GF.MythicPlusDebugService
		local enabled = getMythicPlusAnnouncementService(
			"IsTeleportFollowEnabled",
			"SetTeleportFollowEnabled"
		) ~= nil
			and debugService
			and type(debugService.ShowTeleportDialogPreview) == "function"
		setSettingsWidgetEnabled(self.mythicPlusTeleportPreviewButton, enabled == true)
	end
	registerSettingsRefresher(refreshTeleportPreviewAvailability)
	refreshTeleportPreviewAvailability()

	self.mythicPlusTeleportAnnouncementCheck = select(2, addMythicPlusAnnouncementCheckRow(
		sectionGroup,
		L.SET_MPLUS_TELEPORT_ANNOUNCEMENT or "Teleport announcement",
		L.SET_MPLUS_TELEPORT_ANNOUNCEMENT_HINT or "",
		"IsTeleportAnnouncementEnabled",
		"SetTeleportAnnouncementEnabled"
	))

	local _, teleportMessageBox = addSettingsTextActionRow(sectionGroup, {
		label = L.SET_MPLUS_TELEPORT_MESSAGE or "Custom announcement text",
		tooltip = L.SET_MPLUS_TELEPORT_MESSAGE_HINT or "",
		placeholder = L.SET_MPLUS_TELEPORT_MESSAGE_PLACEHOLDER or "",
		confirmText = L.SET_MPLUS_SETTING_CONFIRM or "Confirm",
		enabled = function()
			return getMythicPlusAnnouncementService("GetTeleportMessage", "SetTeleportMessage") ~= nil
		end,
		get = function()
			return getMythicPlusAnnouncementValue("GetTeleportMessage", "")
		end,
		set = function(value)
			setMythicPlusAnnouncementValue("SetTeleportMessage", value)
		end,
	})
	self.mythicPlusTeleportMessageBox = teleportMessageBox

	self.mythicPlusKeystoneAnnouncementCheck = select(2, addMythicPlusAnnouncementCheckRow(
		sectionGroup,
		L.SET_MPLUS_KEYSTONE_ANNOUNCEMENT or "Keystone announcement",
		L.SET_MPLUS_KEYSTONE_ANNOUNCEMENT_HINT or "",
		"IsKeystoneAnnouncementEnabled",
		"SetKeystoneAnnouncementEnabled"
	))
	notificationsY = finishSingleCardSettingsSection(section, sectionGroup, notificationsY)

	tacticalY = GF.SettingsTacticalPage.Build(
		self,
		tacticalPage,
		tacticalY
	)
	section, sectionGroup = createSingleCardSettingsSection(
		partyListPage,
		L.SET_SECTION_LISTING or L.SET_SECTION_LIST or "List mode",
		partyY)
	addCheckRow(sectionGroup, L.SET_SHOW_LEADER_REALM or "Show realm name", L.SET_SHOW_LEADER_REALM_HINT or "", function()
			return db.showLeaderRealm == true
		end, function(v)
			db.showLeaderRealm = v == true
			refreshLeaderRealmConsumers()
	end)
	self.memberDisplayModeDropdown = addDropdownSettingRow(sectionGroup, L.SET_MEMBER_DISPLAY_MODE or "Group member mode", L.SET_MEMBER_DISPLAY_MODE_HINT or "")
	self:SetupMemberDisplayModeDropdown()
	self.memberTooltipModeDropdown = addDropdownSettingRow(sectionGroup, L.SET_MEMBER_TOOLTIP_MODE or "Mouseover tooltip", L.SET_MEMBER_TOOLTIP_MODE_HINT or "")
	self:SetupMemberTooltipModeDropdown()
	addIntSliderRow(sectionGroup, listWheelSliderOptions(db, L))
	partyY = finishSingleCardSettingsSection(section, sectionGroup, partyY)

	section, sectionGroup = createSingleCardSettingsSection(
		partyListPage,
		L.SET_VISUAL_GROUP_LIST or "List appearance",
		partyY)
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "normal",
		state = "normal",
		label = L.SET_LIST_BACKGROUND_NORMAL or "Default background color",
		tooltip = L.SET_LIST_BACKGROUND_NORMAL_HINT or "",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_NORMAL or "Default listing preview",
	})
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "friend",
		state = "blue",
		label = L.SET_LIST_BACKGROUND_FRIEND or "Friend background color",
		tooltip = L.SET_LIST_BACKGROUND_FRIEND_HINT or "",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_FRIEND or "Friend listing preview",
	})
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "warning",
		state = "red",
		label = L.SET_LIST_BACKGROUND_WARNING or "Warning background color",
		tooltip = L.SET_LIST_BACKGROUND_WARNING_HINT or "",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_WARNING or "Warning listing preview",
	})
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "disabled",
		state = "grey",
		label = L.SET_LIST_BACKGROUND_DISABLED or "Disabled background color",
		tooltip = L.SET_LIST_BACKGROUND_DISABLED_HINT or "",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_DISABLED or "Unavailable listing preview",
	})
	partyY = finishSingleCardSettingsSection(section, sectionGroup, partyY)

	section, sectionGroup = createSingleCardSettingsSection(
		findGroupPage,
		L.SET_SECTION_APPLICATION or "Application",
		findY)
	self.applyDropdown = addDropdownSettingRow(sectionGroup, L.SET_APPLY_MODE or "Apply shortcut")
	self.applyDropdown:SetSize(APPLY_DROPDOWN_W, DD_H)
	self:SetupApplyDropdown()
	addCheckRow(sectionGroup, L.SET_AUTO_ACCEPT_INVITE or "Auto-accept invites", L.SET_AUTO_ACCEPT_INVITE_HINT or "", function()
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
	addCheckRow(sectionGroup, L.SET_REMEMBER_APPLICATION_NOTE or "Keep application note", L.SET_REMEMBER_APPLICATION_NOTE_HINT or "", function()
		return db.rememberApplicationNote == true
	end, function(v)
		db.rememberApplicationNote = v == true
		if db.rememberApplicationNote ~= true and GF.Apply and GF.Apply.ClearApplyNoteState then
			GF.Apply:ClearApplyNoteState()
		end
	end)
	addCheckRow(sectionGroup, L.SET_REPLACE_OLDEST_APPLICATION or "Replace oldest application", L.SET_REPLACE_OLDEST_APPLICATION_HINT or "", function()
		return db.replaceOldestApplication == true
	end, function(v)
		db.replaceOldestApplication = v == true
	end)
	findY = finishSingleCardSettingsSection(section, sectionGroup, findY)

	section, sectionGroup = createSingleCardSettingsSection(
		findGroupPage,
		L.SET_MODULES or "Modules",
		findY)
	addCheckRow(sectionGroup, L.SET_BLACKLIST_ENABLED or "Enable blacklist", L.SET_BLACKLIST_ENABLED_HINT or "", function()
		return db.blacklistEnabled ~= false
	end, function(v)
		db.blacklistEnabled = v == true
		refreshBlacklistSettingConsumers()
	end)
	addCheckRow(sectionGroup, L.SET_BLACKLIST_CHAT_NOTICE or "Show blacklist notices in chat", L.SET_BLACKLIST_CHAT_NOTICE_HINT or "", function()
		return db.showBlacklistChatNotice ~= false
	end, function(v)
		db.showBlacklistChatNotice = v == true
	end)
	findY = finishSingleCardSettingsSection(section, sectionGroup, findY)

	local completedPages = {
		{ appearancePage, y },
		{ partyListPage, partyY },
		{ findGroupPage, findY },
		{ notificationsPage, notificationsY },
		{ tacticalPage, tacticalY },
	}
	for index = 1, #completedPages do
		finishSettingsPage(completedPages[index][1], completedPages[index][2])
	end
	self.bodyH = 1
	self._lastLayoutW = 0

	self.scroll:SetScript("OnSizeChanged", handleSettingsScrollSizeChanged)

	if GF.BlocklistPanel then
		GF.BlocklistPanel:ApplyModuleVisibility()
	end
	self:EnsureMythicPlusSeasonListener()
	self:SelectCategory(
		self._selectedCategoryID or SETTINGS_CATEGORY_IDS[1])
	self:UpdateScroll()
end



local function restoreSelectedCategoryOffset(panel)
	local scroll = panel.scroll
	local categoryID = panel._selectedCategoryID
	local setOffset = scroll and scroll.SetVerticalScroll
	if not setOffset or not categoryID then
		return
	end
	local offsets = panel._categoryScrollOffsets or {}
	setOffset(scroll, offsets[categoryID] or 0)
end

local function finishShowingSettings()
	local parent = SP.parent
	if parent and parent:IsShown() then
		SP:UpdateScroll()
		restoreSelectedCategoryOffset(SP)
	end
end

function SP:Show()
	local parent = self.parent
	if parent then
		parent:Show()
	end
	self:UpdateScroll()
	restoreSelectedCategoryOffset(self)
	local after = C_Timer and C_Timer.After
	if type(after) == "function" then
		after(0, finishShowingSettings)
	end
end

function SP:Hide()
	self:CancelUpdateScrollDebounce()
	local parent = self.parent
	if parent then
		parent:Hide()
	end
end
