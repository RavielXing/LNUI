local _, GF = ...

local SP = {}
GF.SettingsPanel = SP

local Presenter = assert(
	GF.SettingsPresenter,
	"SettingsPresenter must load before SettingsPanel"
)
Presenter:BindView(SP)

local function registerSettingsRefresher(fn, options)
	return Presenter:RegisterRefresher(fn, options)
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
local SETTINGS_SCROLLBAR_GUTTER = GF.SETTINGS_SCROLLBAR_GUTTER or 12

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
	-- Pages already inset their left edge; match it on the right at rest.
	scrollInsetR = SCROLL_INSET_L,
	scrollBarWidth = SETTINGS_SCROLLBAR_WIDTH,
	scrollBarGap = SETTINGS_SCROLLBAR_GAP,
	scrollBarRightInset = SETTINGS_SCROLLBAR_RIGHT_INSET,
	scrollBarGutter = SETTINGS_SCROLLBAR_GUTTER,
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
local OPTIONS_INLINE_LAYOUT = { gap = 12, labelWidth = 220, dropdownWidth = 180, dropdownOutset = 8 }
local OPTIONS_CONTROL_COLUMN_X = 290
local OPTIONS_PANEL_ROW_H = 40
local OPTIONS_PANEL_LABEL_INSET_X = 28
local OPTIONS_PANEL_CONTROL_INSET_X = 24
local OPTIONS_ACTION_BUTTON_RIGHT_INSET = 16
local OPTIONS_SECTION_BODY_INSET_R = OPTIONS_SECTION_BODY_INSET_X
local OPTIONS_TITLE_LEFT_FADE_W = 36
local OPTIONS_TITLE_LEFT_FADE_ALPHA = 0.35
local OPTIONS_VISUAL_SLIDER_W = 520
local OPTIONS_LIST_STYLE_ROW_H = 48
local OPTIONS_LIST_STYLE_SWATCH_SIZE = 22
local OPTIONS_LIST_STYLE_RESET_SIZE = 22
local OPTIONS_LIST_STYLE_RESET_ICON_SIZE = 14
-- Center the Soulbinds arrow optically; its bright upper arc sits above the canvas center.
local OPTIONS_LIST_STYLE_RESET_ICON_OFFSET_X = 0
local OPTIONS_LIST_STYLE_RESET_ICON_OFFSET_Y = -0.5
local OPTIONS_LIST_STYLE_PREVIEW_W = 156
local OPTIONS_LIST_STYLE_PREVIEW_H = 30
local OPTIONS_VISUAL_GROUP_GAP = 10
local OPTIONS_VISUAL_GROUP_INSET_X = 0
local OPTIONS_VISUAL_GROUP_HEADER_H = GF.CARD_HEADER_STYLE.height
local OPTIONS_VISUAL_GROUP_BODY_INSET_X = 8
local OPTIONS_VISUAL_GROUP_PADDING_BOTTOM = 6
local SECTION_GAP = OPTIONS_SECTION_GAP
local SECTION_ROW_H = OPTIONS_PANEL_ROW_H
local SECTION_LABEL_X = OPTIONS_PANEL_LABEL_INSET_X
local SECTION_LABEL_W = OPTIONS_CONTROL_COLUMN_X - OPTIONS_PANEL_LABEL_INSET_X - 16
local SECTION_CONTROL_X = OPTIONS_CONTROL_COLUMN_X + OPTIONS_PANEL_CONTROL_INSET_X
local SECTION_CONTROL_INSET_R = OPTIONS_ACTION_BUTTON_RIGHT_INSET
local SETTINGS_ACTIVITY_BADGE_LABEL_RESERVE = 62

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
		local x = (button._gfPressContentOffsetX or 0) + (button._gfInputPressed and 1 or 0)
		local y = (button._gfPressContentOffsetY or 0) + (button._gfInputPressed and -1 or 0)
		button._gfPressContent:ClearAllPoints()
		button._gfPressContent:SetPoint("CENTER", button, "CENTER", x, y)
	end
end

local function bindSettingsInputButtonClickVisual(button, content, offsetX, offsetY)
	if not button then
		return
	end
	button._gfPressContent = content
	button._gfPressContentOffsetX = offsetX or 0
	button._gfPressContentOffsetY = offsetY or 0
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

local createOptionsTitleDivider = GF.UI.CreateOptionsTitleDivider
local SETTINGS_HEADER_DIVIDER_COLOR = GF.SETTINGS_HEADER_DIVIDER_COLOR
	or { 205 / 255, 180 / 255, 119 / 255, 1 }

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

local function installSettingsNewFeatureBadge(row, spec)
	if type(spec) ~= "table"
		or type(Presenter.ShouldShowNewFeature) ~= "function"
	then
		return
	end
	local declaredSpec = {
		featureID = spec.featureID,
		revision = spec.revision,
		introducedInVersion = spec.introducedInVersion,
		hideAtVersion = spec.hideAtVersion,
	}
	if not Presenter:ShouldShowNewFeature(declaredSpec) then
		return
	end
	local badge = CreateFrame(
		"Frame", nil, row, "NewFeatureLabelTemplate")
	badge:SetSize(1, 1)
	badge:SetScale(0.8)
	badge:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	badge:SetFrameLevel((row:GetFrameLevel() or 0) + 8)
	badge:Show()
end

local function installSettingsActivityBadge(row, label, spec)
	if type(spec) ~= "table" or not row or not label then
		return
	end
	local frameLevel = (row:GetFrameLevel() or 0) + 8
	local activeBadge = CreateFrame(
		"Frame", nil, row, "NewFeatureLabelTemplate")
	activeBadge:SetSize(1, 1)
	activeBadge:SetScale(0.8)
	activeBadge:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	activeBadge:SetFrameLevel(frameLevel)

	-- Use the template's own BGLabel + Label layers. Glow, typography,
	-- resize layout and breathing animation therefore stay byte-for-byte
	-- native; only the displayed word changes from "新" to "限时".
	local function setActiveText(text)
		activeBadge.label = text
		for _, target in ipairs({ activeBadge.BGLabel, activeBadge.Label }) do
			if target and type(target.SetTextToFit) == "function" then
				target:SetTextToFit(text)
			elseif target and type(target.SetText) == "function" then
				target:SetText(text)
			end
		end
		if type(activeBadge.MarkDirty) == "function" then
			activeBadge:MarkDirty()
		end
	end

	local endedBadge = CreateFrame("Frame", nil, row)
	endedBadge:SetHeight(16)
	endedBadge:SetScale(0.8)
	endedBadge:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	endedBadge:SetFrameLevel(frameLevel)
	local endedBackground = endedBadge:CreateTexture(nil, "BACKGROUND")
	endedBackground:SetAllPoints()
	endedBackground:SetTexture(WHITE)
	endedBackground:SetVertexColor(0.25, 0.25, 0.25, 0.9)
	local endedText = GF.UI.CreateFontString(
		endedBadge, "OVERLAY", "GameFontNormalSmall")
	endedText:SetPoint("CENTER", endedBadge, "CENTER", 0, 0)
	endedText:SetJustifyH("CENTER")
	endedText:SetJustifyV("MIDDLE")
	endedText._gfFontSizeOverride = 11
	styleSettingsLabel(endedText, "GameFontNormalSmall")
	endedText:SetTextColor(0.68, 0.68, 0.68, 1)

	local badge = {}
	function badge:ApplyActivitySpec(activitySpec)
		local phase = activitySpec and activitySpec.phase or "ended"
		local locale = GF.L or {}
		local activeLabel = locale.NETEASE_ACTIVITY_BADGE_ACTIVE or "限时"
		setActiveText(activeLabel)
		endedText:SetText(locale.NETEASE_ACTIVITY_BADGE_ENDED or "活动结束")
		endedBadge:SetWidth(math.max(
			34, (endedText:GetStringWidth() or 0) + 12))
		activeBadge:SetShown(phase == "active")
		endedBadge:SetShown(phase == "ended")
	end
	badge:ApplyActivitySpec(spec)
	badge.activeFrame = activeBadge
	badge.endedFrame = endedBadge
	row._gfActivityBadge = badge

	-- Reserve the right edge so the category text does not overlap the
	-- corner badge at narrow menu widths. Preserve
	-- the shared nav label's original left edge so this title stays aligned
	-- with every other settings category.
	local labelWidth = label:GetWidth() or 0
	local labelLeftInset = math.max(
		0,
		(SETTINGS_MENU_W - labelWidth) * 0.5)
	label:ClearAllPoints()
	label:SetPoint("LEFT", row, "LEFT", labelLeftInset, 0)
	label:SetPoint(
		"RIGHT",
		row,
		"RIGHT",
		-SETTINGS_ACTIVITY_BADGE_LABEL_RESERVE,
		0)
	label:SetHeight(SETTINGS_MENU_ROW_H)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
end

local function addSettingsRow(section, labelText, tooltip, opts)
	opts = opts or {}
	local controlH = opts.height or SECTION_ROW_H
	local rowH = controlH
	local offset = section._gfRowOffset or 0
	local panel = section.panel or section
	local row = CreateFrame("Frame", nil, panel)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
	row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
	row:SetHeight(rowH)

	local labelIndent = opts.labelIndent or 0
	local labelWidth = math.max(20, opts.labelWidth or (SECTION_LABEL_W - labelIndent))
	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", row, "TOPLEFT", SECTION_LABEL_X + labelIndent, -controlH / 2)
	label:SetSize(labelWidth, OPTIONS_ROW_HEIGHT)
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
		labelWidth,
		10)
	SP.LocaleBinding:BindText(
		label,
		labelText or "",
		nil,
		function(target)
			fitSettingsText(
				target,
				labelWidth,
				10
			)
		end
	)

	local control = CreateFrame("Frame", nil, row)
	control:SetPoint("LEFT", row, "TOPLEFT", opts.controlX or SECTION_CONTROL_X, -controlH / 2)
	control:SetPoint("RIGHT", row, "TOPRIGHT", -SECTION_CONTROL_INSET_R, -controlH / 2)
	control:SetHeight(controlH)

	row.label = label
	row.control = control
	control._gfSettingsTooltipLabel = label
	installSettingsNewFeatureBadge(row, opts.newFeature)
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

	local header = GF.UI.CreateCardHeader(group, labelText, SETTINGS_HEADER_DIVIDER_COLOR)
	group.header, group.accent = header, header.accent
	local title = header.title
	SP.LocaleBinding:BindText(
		title,
		labelText or "",
		nil,
		function() header:RefreshTitleFit() end
	)
	group.title, group.headerRule = title, header.rule

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

local function showSettingsTooltip(owner, text)
	if not owner or not text or text == "" or not GameTooltip then
		return
	end
	local source = owner
	local title
	while source do
		local label = source._gfSettingsTooltipLabel
		if label and label.GetText then
			title = label:GetText()
			if title and title ~= "" then break end
		end
		source = source.GetParent and source:GetParent()
	end
	GF.UI.BeginGameTooltip(owner, "ANCHOR_RIGHT")
	GF.UI.SetTooltipText(title and title ~= "" and title or text)
	if title and title ~= "" then
		GameTooltip:AddLine(text, 1, 1, 1, true)
	end
	GF.UI.ShowGameTooltip()
end

local function bindSettingsControlTooltip(control, tooltip)
	if not control or not tooltip or tooltip == "" then
		return
	end
	local tooltipValue =
		SP.LocaleBinding:CreateValue(tooltip)
	if control.HookScript then
		control:HookScript("OnEnter", function(owner)
			showSettingsTooltip(
				owner,
				SP.LocaleBinding:Resolve(tooltipValue)
			)
		end)
		control:HookScript("OnLeave", GameTooltip_Hide)
	elseif control.SetScript then
		control:SetScript("OnEnter", function(owner)
			showSettingsTooltip(
				owner,
				SP.LocaleBinding:Resolve(tooltipValue)
			)
		end)
		control:SetScript("OnLeave", GameTooltip_Hide)
	end
end

local function formatSettingsSliderStepAmount(slider, unit)
	local step = slider and (slider._gfSettingsSliderDisplayStep
		or (slider.GetValueStep and tonumber(slider:GetValueStep()))) or 1
	if not step or step <= 0 then
		step = 1
	end
	local amount = string.format("%g", step)
	if unit == "percent" then
		return amount .. "%"
	end
	local L = GF.L or {}
	if unit == "row" then
		local format = step == 1
			and L.SET_SLIDER_STEP_ROW_ONE_FMT
			or L.SET_SLIDER_STEP_ROW_OTHER_FMT
		return string.format(format or "%s 行", amount)
	end
	if unit == "person" then
		local format = step == 1
			and L.SET_SLIDER_STEP_PERSON_ONE_FMT
			or L.SET_SLIDER_STEP_PERSON_OTHER_FMT
		return string.format(format or "%s 人", amount)
	end
	return amount
end

local function bindSettingsSliderStepperTooltip(
	control,
	direction,
	slider,
	unit
)
	if not control then
		return
	end
	local function show(owner)
		local L = GF.L or {}
		local format = direction == "decrease"
			and L.SET_SLIDER_STEP_DECREASE_FMT
			or L.SET_SLIDER_STEP_INCREASE_FMT
		format = format or (direction == "decrease"
			and "减少 %s" or "增加 %s")
		showSettingsTooltip(
			owner,
			string.format(
				format,
				formatSettingsSliderStepAmount(slider, unit)
			)
		)
	end
	if control.HookScript then
		control:HookScript("OnEnter", show)
		control:HookScript("OnLeave", GameTooltip_Hide)
	elseif control.SetScript then
		control:SetScript("OnEnter", show)
		control:SetScript("OnLeave", GameTooltip_Hide)
	end
end

local function setSettingsSliderTextureRegion(texture, region)
	if not (texture and region) then
		return
	end
	local atlasWidth = GF.COMMON_ATLAS_WIDTH or 512
	local atlasHeight = GF.COMMON_ATLAS_HEIGHT or 256
	local path = GF.SETTINGS_SLIDER_TEXTURE or GF.COMMON_ATLAS_TEXTURE
	if texture._gfSliderRegion == region and texture._gfSliderTexture == path
		and texture._gfSliderAtlasWidth == atlasWidth and texture._gfSliderAtlasHeight == atlasHeight
	then
		return
	end
	texture._gfSliderRegion, texture._gfSliderTexture = region, path
	texture._gfSliderAtlasWidth, texture._gfSliderAtlasHeight = atlasWidth, atlasHeight
	texture:SetTexture(path)
	texture:SetAlpha(1)
	texture:SetTexCoord(
		region[1] / atlasWidth,
		(region[1] + region[3]) / atlasWidth,
		region[2] / atlasHeight,
		(region[2] + region[4]) / atlasHeight)
end

local function getSettingsSliderVisualState(widget)
	if widget.IsEnabled and not widget:IsEnabled() then
		return "disabled"
	end
	if widget._gfSettingsSliderPressed then
		return "pressed"
	end
	if widget._gfSettingsSliderHovered then
		return "highlighted"
	end
	if widget.IsMouseMotionFocus and widget:IsMouseMotionFocus() then
		return "highlighted"
	end
	return "normal"
end

local function updateSettingsSliderVisuals(sliderControl)
	if not sliderControl then
		return
	end
	local slider = sliderControl.Slider
	if slider and slider.Thumb then
		local state = getSettingsSliderVisualState(slider)
		setSettingsSliderTextureRegion(
			slider.Thumb,
			(GF.SETTINGS_SLIDER_THUMB_REGIONS or {})[state])
	end
	for _, spec in ipairs({
		{ sliderControl.Back, GF.SETTINGS_SLIDER_BACK_REGIONS },
		{ sliderControl.Forward, GF.SETTINGS_SLIDER_FORWARD_REGIONS },
	}) do
		local button, regions = spec[1], spec[2] or {}
		if button and button._gfSettingsSliderTexture then
			setSettingsSliderTextureRegion(
				button._gfSettingsSliderTexture,
				regions[getSettingsSliderVisualState(button)])
		end
	end
end

local function updateSettingsSliderStepperEnabled(sliderControl)
	local slider = sliderControl and sliderControl.Slider
	local back = sliderControl and sliderControl.Back
	local forward = sliderControl and sliderControl.Forward
	if not (slider and back and forward
		and type(back.SetEnabled) == "function"
		and type(forward.SetEnabled) == "function")
	then
		return
	end

	local enabled = sliderControl._gfSettingsSliderEnabled ~= false
	local value = slider.GetValue and tonumber(slider:GetValue())
	local minimum, maximum
	if slider.GetMinMaxValues then
		minimum, maximum = slider:GetMinMaxValues()
		minimum = tonumber(minimum)
		maximum = tonumber(maximum)
	end
	local step = slider.GetValueStep and tonumber(slider:GetValueStep()) or 0
	local tolerance = step and step > 0 and step * 0.5 or 0
	local hasRange = value ~= nil and minimum ~= nil and maximum ~= nil

	back:SetEnabled(enabled and (not hasRange or value > minimum + tolerance))
	forward:SetEnabled(enabled and (not hasRange or value < maximum - tolerance))
	updateSettingsSliderVisuals(sliderControl)
end

local function hookSettingsSliderVisualState(widget, sliderControl)
	if not (widget and widget.HookScript) then
		return
	end
	widget:HookScript("OnEnter", function()
		updateSettingsSliderVisuals(sliderControl)
	end)
	widget:HookScript("OnLeave", function(self)
		self._gfSettingsSliderPressed = nil
		updateSettingsSliderVisuals(sliderControl)
	end)
	widget:HookScript("OnMouseDown", function(self)
		if not self.IsEnabled or self:IsEnabled() then
			self._gfSettingsSliderPressed = true
		end
		updateSettingsSliderVisuals(sliderControl)
	end)
	widget:HookScript("OnMouseUp", function(self)
		self._gfSettingsSliderPressed = nil
		updateSettingsSliderVisuals(sliderControl)
	end)
	widget:HookScript("OnHide", function(self)
		self._gfSettingsSliderPressed = nil
	end)
end

local function hideSettingsSliderNativeTexture(texture)
	if not texture then
		return
	end
	if texture.SetTexture then
		texture:SetTexture(nil)
	end
	if texture.Hide then
		texture:Hide()
	end
end

local function createSettingsSliderTrack(slider)
	local region = GF.SETTINGS_SLIDER_TRACK_REGION
	if not (slider and region) then
		return
	end
	local sourceCap = GF.SETTINGS_SLIDER_TRACK_SOURCE_CAP_W or 15
	local displayCap = GF.SETTINGS_SLIDER_TRACK_DISPLAY_CAP_W or 15
	local displayHeight = GF.SETTINGS_SLIDER_TRACK_DISPLAY_H or 16
	local sourceMiddleWidth = math.max(1, region[3] - (sourceCap * 2))
	local pieces = {
		{ key = "left", region = { region[1], region[2], sourceCap, region[4] } },
		{ key = "middle", region = { region[1] + sourceCap, region[2], sourceMiddleWidth, region[4] } },
		{ key = "right", region = { region[1] + region[3] - sourceCap, region[2], sourceCap, region[4] } },
	}
	for _, spec in ipairs(pieces) do
		local texture = slider:CreateTexture(nil, "BACKGROUND", nil, 0)
		texture:SetHeight(displayHeight)
		setSettingsSliderTextureRegion(texture, spec.region)
		if spec.key == "left" then
			texture:SetPoint("LEFT", slider, "LEFT", 0, 0)
			texture:SetWidth(displayCap)
		elseif spec.key == "right" then
			texture:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
			texture:SetWidth(displayCap)
		else
			texture:SetPoint("LEFT", slider, "LEFT", displayCap, 0)
			texture:SetPoint("RIGHT", slider, "RIGHT", -displayCap, 0)
		end
	end
end

local function createSettingsSliderStepperTexture(button)
	if not button then
		return nil
	end
	for index = 1, select("#", button:GetRegions()) do
		local region = select(index, button:GetRegions())
		if region and region.IsObjectType and region:IsObjectType("Texture") then
			hideSettingsSliderNativeTexture(region)
		end
	end
	local texture = button:CreateTexture(nil, "ARTWORK", nil, 0)
	texture:SetAllPoints(button)
	button._gfSettingsSliderTexture = texture
	return texture
end

local function createSettingsSlider(parent)
	local sliderControl = CreateFrame(
		"Frame",
		nil,
		parent,
		"MinimalSliderWithSteppersTemplate"
	)
	sliderControl:SetHeight(SLIDER_H)
	local slider = sliderControl.Slider
	local stepperSize = GF.SETTINGS_SLIDER_STEPPER_SIZE or 16
	local stepperGap = GF.SETTINGS_SLIDER_STEPPER_GAP or 4
	slider:ClearAllPoints()
	slider:SetPoint("TOPLEFT", sliderControl, "TOPLEFT", stepperSize + stepperGap, 0)
	slider:SetPoint("BOTTOMRIGHT", sliderControl, "BOTTOMRIGHT", -(stepperSize + stepperGap), 0)
	sliderControl.Back:ClearAllPoints()
	sliderControl.Back:SetSize(stepperSize, stepperSize)
	sliderControl.Back:SetPoint("RIGHT", slider, "LEFT", -stepperGap, 0)
	sliderControl.Forward:ClearAllPoints()
	sliderControl.Forward:SetSize(stepperSize, stepperSize)
	sliderControl.Forward:SetPoint("LEFT", slider, "RIGHT", stepperGap, 0)
	hideSettingsSliderNativeTexture(slider.Left)
	hideSettingsSliderNativeTexture(slider.Middle)
	hideSettingsSliderNativeTexture(slider.Right)
	createSettingsSliderTrack(slider)
	if slider.Thumb then
		slider.Thumb:SetSize(
			GF.SETTINGS_SLIDER_THUMB_SIZE or 16,
			GF.SETTINGS_SLIDER_THUMB_SIZE or 16)
	end
	createSettingsSliderStepperTexture(sliderControl.Back)
	createSettingsSliderStepperTexture(sliderControl.Forward)
	hookSettingsSliderVisualState(slider, sliderControl)
	hookSettingsSliderVisualState(sliderControl.Back, sliderControl)
	hookSettingsSliderVisualState(sliderControl.Forward, sliderControl)
	-- Retail's template does not consistently expose a callable boundary-state
	-- refresh after GF installs its own value callback. Derive the two button
	-- states from the public slider values instead, while retaining the native
	-- buttons as the click/step owner. Keep one GF-owned script dispatcher so a
	-- later business SetScript cannot discard the boundary refresh.
	sliderControl._gfSettingsSliderEnabled = true
	function sliderControl:SyncGFStepperEnabled()
		updateSettingsSliderStepperEnabled(self)
	end
	function sliderControl:SetGFValueChangedHandler(handler)
		slider:SetScript("OnValueChanged", function(...)
			if handler then
				handler(...)
			end
			self:SyncGFStepperEnabled()
		end)
		self:SyncGFStepperEnabled()
	end
	local nativeSetEnabled = sliderControl.SetEnabled
	function sliderControl:SetEnabled(enabled)
		self._gfSettingsSliderEnabled = enabled ~= false
		nativeSetEnabled(self, enabled)
		self:SyncGFStepperEnabled()
	end
	sliderControl:HookScript("OnShow", function(self)
		self:SyncGFStepperEnabled()
	end)
	updateSettingsSliderVisuals(sliderControl)
	sliderControl._gfSettingsSlider = sliderControl.Slider
	return sliderControl, sliderControl.Slider
end

local function bindSettingsSliderTooltip(sliderControl, tooltip, stepUnit)
	if not sliderControl then
		return
	end
	bindSettingsControlTooltip(sliderControl.Slider, tooltip)
	bindSettingsSliderStepperTooltip(
		sliderControl.Back,
		"decrease",
		sliderControl.Slider,
		stepUnit)
	bindSettingsSliderStepperTooltip(
		sliderControl.Forward,
		"increase",
		sliderControl.Slider,
		stepUnit)
	bindSettingsControlTooltip(sliderControl._gfStableThumbDragCapture, tooltip)
end

local function installSettingsSliderStableThumbDrag(sliderControl)
	local slider = sliderControl and sliderControl.Slider
	local thumb = slider and slider.Thumb
	if not (slider and thumb) then
		return
	end

	local capture = CreateFrame("Button", nil, sliderControl)
	capture:SetAllPoints(thumb)
	capture:SetFrameLevel((slider:GetFrameLevel() or 0) + 5)
	capture:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
	sliderControl._gfStableThumbDragCapture = capture

	local dragState
	local scroll = SP.scroll
	local function restoreDragScrollOffset(scaleChanged)
		if not dragState or dragState.scrollOffset == nil
			or not scroll:IsShown()
		then
			return
		end
		-- Finish the scaled child's geometry before restoring its offset.
		-- Never write from OnVerticalScroll/OnScrollRangeChanged: ScrollUtil
		-- already synchronizes the bar there, and reentry can invalidate the
		-- ScrollFrame's in-progress render update.
		local range = math.max(0, scroll:GetVerticalScrollRange() or 0)
		local offset = math.min(dragState.scrollOffset, range)
		if scaleChanged or dragState.scrollDirty
			or math.abs(scroll:GetVerticalScroll() - offset) > 0.01
		then
			scroll:UpdateScrollChildRect()
			range = math.max(0, scroll:GetVerticalScrollRange() or 0)
			offset = math.min(dragState.scrollOffset, range)
		end
		if math.abs(scroll:GetVerticalScroll() - offset) > 0.01 then
			scroll:SetVerticalScroll(offset)
		end
		dragState.scrollDirty = nil
	end
	if scroll then
		local wheelAllow = scroll._gfWheelAllow
		scroll._gfWheelAllow = function()
			return not dragState
				and (type(wheelAllow) ~= "function" or wheelAllow())
		end
		local function invalidateDragScroll()
			if dragState then dragState.scrollDirty = true end
		end
		scroll:HookScript("OnVerticalScroll", invalidateDragScroll)
		scroll:HookScript("OnScrollRangeChanged", invalidateDragScroll)
	end
	local function alignDragThumb(value)
		local anchor = dragState and dragState.cursorAnchor
		if not anchor then return end
		local frame = anchor.frame
		if frame.IsProtected and frame:IsProtected() then return end
		local thumbX, thumbY = thumb:GetCenter()
		local thumbScale = thumb.GetEffectiveScale and thumb:GetEffectiveScale()
			or slider:GetEffectiveScale()
		local frameScale = frame:GetEffectiveScale()
		if not (thumbX and thumbY and thumbScale > 0 and frameScale > 0) then return end
		-- Preserve the grabbed point on the diamond, in physical screen pixels.
		-- The frozen value axis prevents feedback; moving the window compensates
		-- for the slider's own scale and translation without moving the cursor.
		-- Use the stepped/clamped value so dragging past an endpoint cannot pan.
		local targetX = dragState.startCursorX
			+ (value - dragState.startValue) / dragState.valuePerPixel
		local deltaX = targetX - (thumbX + anchor.grabX) * thumbScale
		local deltaY = anchor.cursorY - (thumbY + anchor.grabY) * thumbScale
		if math.abs(deltaX) <= 0.01 and math.abs(deltaY) <= 0.01 then return end
		if anchor.wasClamped == nil then
			anchor.wasClamped = frame:IsClampedToScreen()
			frame:SetClampedToScreen(false)
			-- Unclamping may itself resolve an old off-screen anchor.
			thumbX, thumbY = thumb:GetCenter()
			if not (thumbX and thumbY) then return end
			deltaX = targetX - (thumbX + anchor.grabX) * thumbScale
			deltaY = anchor.cursorY - (thumbY + anchor.grabY) * thumbScale
		end
		frame:AdjustPointsOffset(deltaX / frameScale, deltaY / frameScale)
		anchor.moved = true
	end
	local pendingAnchorRelease
	local function releaseDragAnchor(anchor)
		if not anchor or anchor.wasClamped == nil then return end
		local frame = anchor.frame
		if frame.IsProtected and frame:IsProtected()
			and InCombatLockdown and InCombatLockdown()
		then
			pendingAnchorRelease = anchor
			capture:RegisterEvent("PLAYER_REGEN_ENABLED")
			return
		end
		frame:SetClampedToScreen(anchor.wasClamped)
		if anchor.moved and GF.SaveFrameLayout then GF.SaveFrameLayout(frame) end
	end
	capture:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			capture:UnregisterEvent(event)
			local anchor = pendingAnchorRelease
			pendingAnchorRelease = nil
			releaseDragAnchor(anchor)
		end
	end)
	local function finishDrag()
		local finalValue
		if dragState and sliderControl.ApplyScaleDragPreview then
			local value = slider:GetValue()
			if dragState.step > 0 then
				value = dragState.minValue + math.floor(
					(value - dragState.minValue) / dragState.step + 0.5) * dragState.step
			end
			if math.abs(value - slider:GetValue()) > 0.00001 then
				sliderControl:ApplyScaleDragPreview(value)
				finalValue = value
			end
			slider:SetValueStep(dragState.step)
			slider._gfSettingsSliderDisplayStep = nil
		end
		restoreDragScrollOffset(true)
		if finalValue then alignDragThumb(finalValue) end
		local anchor = dragState and dragState.cursorAnchor
		dragState = nil
		capture:SetScript("OnUpdate", nil)
		releaseDragAnchor(anchor)
		slider._gfSettingsSliderPressed = nil
		slider._gfSettingsSliderHovered = capture.IsMouseMotionFocus
			and capture:IsMouseMotionFocus()
			or nil
		updateSettingsSliderVisuals(sliderControl)
	end

	local function updateDrag()
		if not dragState then
			return
		end
		if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
			finishDrag()
			return
		end
		local cursorX = GetCursorPosition and GetCursorPosition()
		cursorX = tonumber(cursorX)
		if not cursorX then
			return
		end
		local value = dragState.startValue
			+ ((cursorX - dragState.startCursorX) * dragState.valuePerPixel)
		if sliderControl.ApplyScaleDragPreview then
			-- Keep the native thumb continuous; only the displayed/saved setting
			-- uses integer percentages. No easing delay between pointer and thumb.
			value = math.floor(value * 1000 + 0.5) / 1000
		elseif dragState.step > 0 then
			value = dragState.minValue + math.floor(
				((value - dragState.minValue) / dragState.step) + 0.5)
				* dragState.step
		end
		value = math.max(dragState.minValue, math.min(dragState.maxValue, value))
		local scaleChanged = math.abs(value - slider:GetValue()) > 0.00001
		if scaleChanged then
			if sliderControl.ApplyScaleDragPreview then
				sliderControl:ApplyScaleDragPreview(value)
			else
				slider:SetValue(value)
			end
		end
		restoreDragScrollOffset(scaleChanged)
		if scaleChanged then alignDragThumb(value) end
	end

	capture:SetScript("OnEnter", function()
		slider._gfSettingsSliderHovered = true
		updateSettingsSliderVisuals(sliderControl)
	end)
	capture:SetScript("OnLeave", function()
		slider._gfSettingsSliderHovered = nil
		if not dragState then
			slider._gfSettingsSliderPressed = nil
		end
		updateSettingsSliderVisuals(sliderControl)
	end)
	capture:SetScript("OnMouseDown", function(_, mouseButton)
		if mouseButton ~= "LeftButton" or not slider:IsEnabled() then
			return
		end
		local cursorX, cursorY
		if GetCursorPosition then cursorX, cursorY = GetCursorPosition() end
		local effectiveScale = slider.GetEffectiveScale and slider:GetEffectiveScale()
		local trackWidth = slider.GetWidth and slider:GetWidth()
		local thumbWidth = thumb.GetWidth and thumb:GetWidth()
		local minValue, maxValue = slider:GetMinMaxValues()
		cursorX = tonumber(cursorX)
		effectiveScale = tonumber(effectiveScale)
		trackWidth = tonumber(trackWidth)
		thumbWidth = tonumber(thumbWidth) or 0
		minValue = tonumber(minValue)
		maxValue = tonumber(maxValue)
		if not (cursorX and effectiveScale and effectiveScale > 0
			and trackWidth and trackWidth > 0 and minValue and maxValue
			and maxValue > minValue)
		then
			return
		end
		local travelWidth = math.max(1, (trackWidth - thumbWidth) * effectiveScale)
		dragState = {
			startCursorX = cursorX,
			startValue = tonumber(slider:GetValue()) or minValue,
			valuePerPixel = (maxValue - minValue) / travelWidth,
			minValue = minValue,
			maxValue = maxValue,
			step = tonumber(slider:GetValueStep()) or 0,
			scrollOffset = scroll and scroll:GetVerticalScroll(),
		}
		if sliderControl.ApplyScaleDragPreview then
			slider._gfSettingsSliderDisplayStep = dragState.step
			slider:SetValueStep(0.001)
		end
		local frame = GF.MainFrame and GF.MainFrame.frame
		if not pendingAnchorRelease and frame and frame.AdjustPointsOffset
			and frame.GetEffectiveScale and frame.IsClampedToScreen and frame.SetClampedToScreen
			and not (frame.IsProtected and frame:IsProtected())
			and thumb.GetCenter and tonumber(cursorY)
		then
			local thumbX, thumbY = thumb:GetCenter()
			local thumbScale = thumb.GetEffectiveScale and thumb:GetEffectiveScale() or effectiveScale
			if thumbX and thumbY and thumbScale > 0 then
				dragState.cursorAnchor = {
					frame = frame,
					cursorY = cursorY,
					grabX = cursorX / thumbScale - thumbX,
					grabY = cursorY / thumbScale - thumbY,
				}
			end
		end
		if scroll and GF.UI.CancelSmoothWheelScrolling then
			GF.UI.CancelSmoothWheelScrolling(scroll)
		end
		slider._gfSettingsSliderPressed = true
		updateSettingsSliderVisuals(sliderControl)
		capture:SetScript("OnUpdate", updateDrag)
	end)
	capture:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			finishDrag()
		end
	end)
	capture:SetScript("OnHide", finishDrag)
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
			showSettingsTooltip(owner, tipText)
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

local setSettingsWidgetEnabled
local setSettingsLabelEnabled

local function addSettingsTrailingText(row, widget, opts)
	local control = row.control
	opts = opts or {}
	if type(opts.trailingText) == "string" and opts.trailingText ~= "" then
		local gap = opts.trailingTextGap or 12
		local rightInset = opts.trailingTextRightInset or 0
		local textInsets = (widget:GetWidth() or 0) + gap + rightInset
			+ (opts.controlIndent or 0)
		local trailingText = GF.UI.CreateFontString(
			control,
			"OVERLAY",
			"GameFontDisableSmall"
		)
		trailingText:SetPoint("LEFT", widget, "RIGHT", gap, 0)
		trailingText:SetPoint("RIGHT", control, "RIGHT", -rightInset, 0)
		trailingText:SetHeight(OPTIONS_ROW_HEIGHT)
		trailingText:SetJustifyH("LEFT")
		trailingText:SetJustifyV("MIDDLE")
		trailingText:SetWordWrap(false)
		trailingText:SetTextColor(0.48, 0.46, 0.42, 1)
		trailingText._gfFontSizeOverride = 12
		styleSettingsLabel(trailingText, "GameFontDisableSmall")
		SP.LocaleBinding:BindText(
			trailingText,
			opts.trailingText,
			nil,
			function(target)
				local width = (control:GetWidth() or 0)
					- textInsets
				if width > 20 then
					fitSettingsText(target, width, 8)
				end
			end
		)
		bindSettingsTextFit(
			control,
			trailingText,
			textInsets,
			8
		)
		row.trailingText = trailingText
	end
end

local function addCheckRow(section, label, tooltip, fieldID, opts)
	opts = opts or {}
	local row, control, labelFs = addSettingsRow(section, label, tooltip, opts)
	local cb = createSettingsCheckButton(control)
	anchorSettingsControl(control, cb, opts)
	addSettingsTrailingText(row, cb, opts)
	local context = opts.fieldContext
	local function refreshProjection()
		local projection = Presenter:ProjectField(fieldID, context)
		cb:SetChecked(projection.value == true)
		setSettingsWidgetEnabled(cb, projection.enabled)
		setSettingsLabelEnabled(labelFs, projection.enabled)
	end
	refreshProjection()
	cb:SetMotionScriptsWhileDisabled(true)
	cb:SetScript("OnClick", function(self)
		if not self:IsEnabled() then
			return
		end
		Presenter:SetValue(fieldID, getCheckButtonBool(self), context)
		updateSettingsCheckButton(self)
		refreshProjection()
	end)
	bindSettingsCheckButtonTooltip(cb, tooltip)
	registerSettingsRefresher(refreshProjection, { fieldID = fieldID })
	return row, cb, labelFs
end

local function addTwoColumnSettingsRow(section, leftCfg, rightCfg)
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

		local isDropdown = cfg.kind == "dropdown"
		local labelX = SECTION_LABEL_X
		local controlX = labelX + OPTIONS_INLINE_LAYOUT.labelWidth + OPTIONS_INLINE_LAYOUT.gap

		local cellControl = CreateFrame("Frame", nil, cell)
		cellControl:SetPoint(
			"TOPLEFT",
			cell,
			"TOPLEFT",
			controlX,
			0)
		cellControl:SetPoint(
			"BOTTOMRIGHT",
			cell,
			"BOTTOMRIGHT",
			-OPTIONS_ACTION_BUTTON_RIGHT_INSET,
			0)
		cell.control = cellControl

		local widget
		if isDropdown then
			widget = createSettingsDropdown(cellControl)
			widget:SetSize(OPTIONS_INLINE_LAYOUT.dropdownWidth, DD_H)
			-- 与复选框共用左侧锚点；纹理外扩不作为额外位置补偿。
			widget:SetPoint("LEFT", cellControl, "LEFT", 0, 0)
			bindSettingsControlTooltip(widget, cfg.tooltip or "")
		else
			widget = createSettingsCheckButton(cellControl)
			widget:SetPoint("LEFT", cellControl, "LEFT", 0, 0)
		end
		local function refreshProjection()
			local projection = Presenter:ProjectField(
				cfg.fieldID, cfg.fieldContext)
			if not isDropdown then
				widget:SetChecked(projection.value == true)
			end
			setSettingsWidgetEnabled(widget, projection.enabled)
			setSettingsLabelEnabled(cell._fieldLabel, projection.enabled)
		end
		refreshProjection()
		if not isDropdown then
			widget:SetMotionScriptsWhileDisabled(true)
			widget:SetScript("OnClick", function(self)
				if not self:IsEnabled() then
					return
				end
				Presenter:SetValue(
					cfg.fieldID,
					getCheckButtonBool(self),
					cfg.fieldContext)
				updateSettingsCheckButton(self)
				refreshProjection()
			end)
			bindSettingsCheckButtonTooltip(widget, cfg.tooltip or "")
		end

		local label = GF.UI.CreateFontString(cell, "OVERLAY", "GameFontHighlight")
		label:SetPoint("LEFT", cell, "LEFT", labelX, 0)
		label:SetWidth(OPTIONS_INLINE_LAYOUT.labelWidth)
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
		cell._fieldLabel = label
		cellControl._gfSettingsTooltipLabel = label
		local function refreshCellLayout()
			local cellWidth = cell:GetWidth() or 0
			if cellWidth <= 0 then
				return
			end
			fitSettingsText(label, OPTIONS_INLINE_LAYOUT.labelWidth, 10)
			if isDropdown then
				widget:SetWidth(math.min(OPTIONS_INLINE_LAYOUT.dropdownWidth,
					math.max(20, cellWidth - controlX - OPTIONS_ACTION_BUTTON_RIGHT_INSET
						- OPTIONS_INLINE_LAYOUT.dropdownOutset * 2)))
			end
		end
		cell:HookScript("OnSizeChanged", refreshCellLayout)
		SP.LocaleBinding:BindText(label, cfg.label or "", nil, refreshCellLayout)
		refreshCellLayout()
		refreshProjection()

		registerSettingsRefresher(
			refreshProjection,
			{ fieldID = cfg.fieldID })

		return cell, widget, label
	end

	row.leftCell, row.leftControl, row.leftLabel = addCell(leftCfg, "left")
	row.rightCell, row.rightControl, row.rightLabel = addCell(rightCfg, "right")

	section._gfRowOffset = offset + rowH
	updateSettingsSectionHeights(section)
	return row
end

local function addDropdownSettingRow(section, label, tooltip, opts)
	local row, control, labelFs = addSettingsRow(
		section, label, tooltip, opts)
	local dd = createSettingsDropdown(control)
	dd:SetSize(DD_W, DD_H)
	anchorSettingsControl(control, dd)
	bindSettingsControlTooltip(dd, tooltip)
	addSettingsTrailingText(row, dd, opts)
	return dd, labelFs
end

local function resolveSliderEnabled(cfg)
	if cfg.fieldID then
		return Presenter:ProjectField(
			cfg.fieldID, cfg.fieldContext).enabled
	end
	if cfg.enabled == nil then
		return nil
	end
	if type(cfg.enabled) == "function" then
		return cfg.enabled()
	end
	return cfg.enabled
end

local function addIntSliderRow(section, cfg)
	local rowOptions = cfg.rowOptions or (cfg.compactLayout and {
		labelWidth = OPTIONS_INLINE_LAYOUT.labelWidth,
		controlX = SECTION_LABEL_X + OPTIONS_INLINE_LAYOUT.labelWidth + OPTIONS_INLINE_LAYOUT.gap,
	} or nil)
	local _, control, label = addSettingsRow(section, cfg.label or "", cfg.tooltip, rowOptions)
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
			Presenter:ProjectField(
				toggleCfg.fieldID,
				toggleCfg.fieldContext).value == true)
		toggleButton:SetMotionScriptsWhileDisabled(true)
		toggleButton:SetScript("OnClick", function(self)
			if not self:IsEnabled() then
				return
			end
			Presenter:SetValue(
				toggleCfg.fieldID,
				getCheckButtonBool(self),
				toggleCfg.fieldContext)
			updateSettingsCheckButton(self)
			Presenter:RefreshView({ reason = "dependency-change" })
		end)
		bindSettingsCheckButtonTooltip(
			toggleButton,
			toggleCfg.tooltip or cfg.tooltip)
	end

	local sliderControl, slider = createSettingsSlider(control)
	slider:SetMinMaxValues(minV, maxV)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	if cfg.stableThumbDrag == true then
		installSettingsSliderStableThumbDrag(sliderControl)
	end

	if toggleButton then
		sliderControl:SetPoint(
			"LEFT",
			toggleButton,
			"RIGHT",
			toggleGap,
			0)
	else
		sliderControl:SetPoint("LEFT", control, "LEFT", sliderIndent, 0)
	end
	local valueFs
	if cfg.hideValue == true then
		if cfg.sliderWidth then
			sliderControl:SetWidth(cfg.sliderWidth)
		else
			sliderControl:SetPoint("RIGHT", control, "RIGHT", -(cfg.controlRightOffset or 0), 0)
		end
	else
		valueFs = GF.UI.CreateFontString(control, "OVERLAY", "GameFontHighlight")
		valueFs:SetWidth(58)
		valueFs:SetJustifyH("LEFT")
		valueFs:SetTextColor(1, 0.82, 0, 1)
		valueFs._gfFontSizeOverride = 12
		styleSettingsLabel(valueFs, "GameFontHighlight")
		if cfg.sliderWidth then
			valueFs:SetPoint("LEFT", sliderControl, "RIGHT", 10, 0)
		else
			valueFs:SetPoint("RIGHT", control, "RIGHT", -(cfg.controlRightOffset or 0), 0)
			sliderControl:SetPoint("RIGHT", valueFs, "LEFT", -10, 0)
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
			sliderControl:SetWidth(width)
		end
		updateFixedSliderWidth()
		control:HookScript("OnSizeChanged", updateFixedSliderWidth)
	end

	local syncing
	local function syncSlider(raw, previewValue)
		local normalize = cfg.clamp
		local value = normalize and normalize(raw) or raw
		if value == nil then
			value = def or minV
		end
		syncing = true
		slider:SetValue(previewValue or value)
		syncing = nil
		sliderControl:SyncGFStepperEnabled()
		if valueFs then
			local format = cfg.formatValue or tostring
			local text = format(value)
			if valueFs:GetText() ~= text then
				valueFs:SetText(text)
				fitSettingsText(valueFs, 58, 9)
			end
		end
	end

	syncSlider(Presenter:ReadValue(cfg.fieldID, cfg.fieldContext))
	local initialEnabled = resolveSliderEnabled(cfg)
	if initialEnabled ~= nil then
		sliderControl:SetEnabled(initialEnabled)
	end
	local function handleSliderChanged(_, value)
		if syncing then
			return
		end
		local _, projection = Presenter:SetValue(
			cfg.fieldID, value, cfg.fieldContext)
		syncSlider(projection.value)
	end
	sliderControl:SetGFValueChangedHandler(handleSliderChanged)
	if cfg.stableThumbDrag == true then
		function sliderControl:ApplyScaleDragPreview(value)
			local rounded = math.floor(value + 0.5)
			if Presenter:ReadValue(cfg.fieldID, cfg.fieldContext) ~= rounded then
				local _, projection = Presenter:SetValue(
					cfg.fieldID, rounded, cfg.fieldContext, { skipRefresh = true })
				rounded = projection.value
			end
			syncSlider(rounded, value)
			-- One continuous scale application per frame, without first applying
			-- the rounded value through the ordinary presenter refresh chain.
			if GF.ApplyPanelScale then GF.ApplyPanelScale(value / 100) end
		end
	end
	if cfg.onMouseUp then
		slider:HookScript("OnMouseUp", cfg.onMouseUp)
	end
	bindSettingsSliderTooltip(sliderControl, cfg.tooltip, cfg.stepUnit)

	registerSettingsRefresher(function()
		if toggleButton and toggleCfg.fieldID then
			toggleButton:SetChecked(
				Presenter:ProjectField(
					toggleCfg.fieldID,
					toggleCfg.fieldContext).value == true)
		end
		syncSlider(Presenter:ReadValue(cfg.fieldID, cfg.fieldContext))
		local refreshedEnabled = resolveSliderEnabled(cfg)
		if refreshedEnabled ~= nil then
			sliderControl:SetEnabled(refreshedEnabled)
		end
	end)

	return sliderControl, valueFs, label, toggleButton
end

local function getListBackgroundStyle(styleKey)
	return Presenter:GetListBackgroundStyle(styleKey)
end

local function getListBackgroundStyleState(styleKey)
	if styleKey == "friend" then
		return "blue"
	end
	if styleKey == "censored" then
		return "censored"
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

local function createSettingsResetButton(parent, tooltip)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(OPTIONS_LIST_STYLE_RESET_SIZE, OPTIONS_LIST_STYLE_RESET_SIZE)
	setSettingsInputAtlasState(button, "normal")
	local icon = button:CreateTexture(nil, "OVERLAY")
	GF.UI.SetRefreshIconAtlas(icon, OPTIONS_LIST_STYLE_RESET_ICON_SIZE)
	icon:SetPoint("CENTER", button, "CENTER",
		OPTIONS_LIST_STYLE_RESET_ICON_OFFSET_X, OPTIONS_LIST_STYLE_RESET_ICON_OFFSET_Y)
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
			and GF.UI.ShowGameTooltip
		then
			showSettingsTooltip(
				self,
				tooltipText
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
	bindSettingsInputButtonClickVisual(button, icon,
		OPTIONS_LIST_STYLE_RESET_ICON_OFFSET_X, OPTIONS_LIST_STYLE_RESET_ICON_OFFSET_Y)
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
	return Presenter:SetListBackgroundStyle(styleKey, style)
end

local function addListBackgroundStyleRow(section, cfg)
	cfg = cfg or {}
	local row, control = addSettingsRow(section, cfg.label or "", "", { height = OPTIONS_LIST_STYLE_ROW_H })
	local styleKey = cfg.styleKey or "normal"
	local state = cfg.state or getListBackgroundStyleState(styleKey)

	local colorButton = createSettingsColorButton(control)
	colorButton:SetPoint("LEFT", control, "LEFT", 0, 0)

	local resetColorButton = createSettingsResetButton(control, (GF.L and GF.L.SET_LIST_BACKGROUND_RESET_COLOR) or "恢复默认颜色")
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

	local alphaSliderControl, alphaSlider = createSettingsSlider(control)
	alphaSlider:SetMinMaxValues(GF.LIST_BACKGROUND_ALPHA_MIN_PCT or 30, GF.LIST_BACKGROUND_ALPHA_MAX_PCT or 100)
	alphaSlider:SetValueStep(1)
	alphaSlider:SetObeyStepOnDrag(true)
	alphaSliderControl:SetPoint("LEFT", alphaLabel, "RIGHT", 8, 0)
	alphaSliderControl._gfSettingsTooltipLabel = alphaLabel
	bindSettingsSliderTooltip(alphaSliderControl, "", "percent")

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
	alphaSliderControl:SetPoint("RIGHT", valueFs, "LEFT", -10, 0)
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
	previewText:SetPoint("LEFT", preview, "LEFT", 12, GF.LIST_ROW_STYLE.contentOffsetY)
	previewText:SetPoint("RIGHT", preview, "RIGHT", -12, GF.LIST_ROW_STYLE.contentOffsetY)
	previewText:SetHeight(math.max(1, preview:GetHeight() - 2 * math.abs(GF.LIST_ROW_STYLE.contentOffsetY)))
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
			profile = GF.LIST_ROW_STYLE.background,
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
				profile = GF.LIST_ROW_STYLE.background,
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
		alphaSliderControl:SyncGFStepperEnabled()
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
		Presenter:ResetListBackgroundColor(styleKey)
		updatePreview()
	end)

	alphaSliderControl:SetGFValueChangedHandler(function(_, value)
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
	local row, control, label = addSettingsRow(section, cfg.label or "", cfg.tooltip)
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
		if write and cfg.fieldID then
			local _, projection = Presenter:SetValue(
				cfg.fieldID, v, cfg.fieldContext)
			v = projection.value or v
		end
		box:SetText(tostring(v))
		return v
	end

	syncInput(Presenter:ReadValue(cfg.fieldID, cfg.fieldContext), false)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", function(self)
		local v = syncInput(self:GetText(), true)
	end)
	box:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	styleSettingsNumberBox(box, cfg.width or NUMBER_BOX_W, cfg.height or NUMBER_BOX_H)
	addSettingsTrailingText(row, box, cfg)
	bindSettingsControlTooltip(box, cfg.tooltip)

	registerSettingsRefresher(function()
		if not box:HasFocus() then
			syncInput(
				Presenter:ReadValue(cfg.fieldID, cfg.fieldContext),
				false)
		end
	end, { fieldID = cfg.fieldID })

	return box, label
end

setSettingsWidgetEnabled = function(widget, enabled)
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

setSettingsLabelEnabled = function(label, enabled)
	if not label or not label.SetTextColor then
		return
	end
	if enabled then
		label:SetTextColor(0.92, 0.90, 0.84, 1)
	else
		label:SetTextColor(0.46, 0.45, 0.42, 1)
	end
end

local function addSettingsActionRow(section, cfg)
	cfg = cfg or {}
	local row, control, label = addSettingsRow(
		section, cfg.label or "", cfg.tooltip)
	local button = GF.UI.CreatePanelButton(
		control,
		cfg.buttonText or "",
		GF.PANEL_BUTTON_STANDARD_W or 72)
	anchorSettingsControl(control, button, cfg)
	fitSettingsText(
		button:GetFontString(),
		math.max(1, button:GetWidth() - 12),
		8)
	SP.LocaleBinding:BindText(
		button,
		cfg.buttonText or "",
		nil,
		function(target)
			fitSettingsText(
				target:GetFontString(),
				math.max(1, target:GetWidth() - 12),
				8)
		end)
	local function refreshProjection()
		local projection = Presenter:ProjectAction(cfg.actionID)
		setSettingsWidgetEnabled(button, projection.enabled)
		setSettingsLabelEnabled(label, projection.enabled)
	end
	button:SetScript("OnClick", function()
		if button:IsEnabled() and type(cfg.onClick) == "function" then
			cfg.onClick()
		end
	end)
	bindSettingsControlTooltip(button, cfg.tooltip)
	registerSettingsRefresher(refreshProjection)
	refreshProjection()
	return row, button, label
end

local function addMythicPlusAnnouncementCheckRow(
	section, label, tooltip, fieldID, opts)
	return addCheckRow(section, label, tooltip, fieldID, opts)
end

local function addKeystoneRotationReminderCheckRow(section, label, tooltip)
	return addCheckRow(
		section,
		label,
		tooltip,
		"keystoneRotationReminderEnabled")
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
	local fieldID = cfg.fieldID
	local fieldContext = cfg.fieldContext

	local function isAvailable()
		return Presenter:ProjectField(
			fieldID, fieldContext).enabled == true
	end

	local function getSavedText()
		if not isAvailable() then
			return ""
		end
		return tostring(
			Presenter:ProjectField(fieldID, fieldContext).savedValue or "")
	end

	local function updateState()
		local enabled = isAvailable()
		local currentText = box:GetText() or ""
		Presenter:StageValue(fieldID, currentText, fieldContext)
		local projection = Presenter:ProjectField(fieldID, fieldContext)
		setSettingsWidgetEnabled(box, enabled)
		setSettingsWidgetEnabled(
			confirmButton,
			enabled and projection.dirty)
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
		if not isAvailable() then
			updateState()
			return
		end
		Presenter:StageValue(fieldID, value, fieldContext)
		Presenter:ApplyField(fieldID, fieldContext)
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
		Presenter:DiscardDraft(fieldID, fieldContext)
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
	end, { fieldID = fieldID })
	syncFromService(true)

	row.editBox = box
	row.confirmButton = confirmButton
	row.clearButton = clearButton
	return row, box, confirmButton, clearButton, label
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

local function addAutoInviteLimitRow(section)
	local L = GF.L or {}
	local minV = GF.AUTO_INVITE_MEMBER_LIMIT_MIN or 1
	local maxV = GF.AUTO_INVITE_MEMBER_LIMIT_MAX or 40

	SP.autoInviteLimitSlider,
	SP.autoInviteLimitValue,
	SP.autoInviteLimitLabel,
	SP.autoInviteLimitCheck = addIntSliderRow(section, {
		label = L.SET_AUTO_INVITE_LIMIT or "Auto-invite limit",
		tooltip = L.SET_AUTO_INVITE_LIMIT_HINT or "",
		toggle = {
			tooltip = L.SET_AUTO_INVITE_LIMIT_HINT or "",
			fieldID = "autoInviteMemberLimitEnabled",
		},
		fieldID = "autoInviteMemberLimit",
		min = minV,
		max = maxV,
		stepUnit = "person",
	})

	registerSettingsRefresher(function()
		setAutoInviteLimitControlEnabled(
			Presenter:ProjectField("autoInviteMemberLimit").enabled)
	end, { fieldID = "autoInviteMemberLimit" })
	setAutoInviteLimitControlEnabled(
		Presenter:ProjectField("autoInviteMemberLimit").enabled)
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

local function updatePresenterDropdown(dropdown, fieldID)
	local projection = Presenter:ProjectOptionField(fieldID, GF.L)
	setDropdownCaption(dropdown, projection.label)
	setSettingsWidgetEnabled(dropdown, projection.enabled)
end

local function setupPresenterDropdown(owner, dropdown, fieldID, updateMethod)
	if installRadioOptions(
		dropdown,
		function()
			return Presenter:GetOptions(fieldID, GF.L)
		end,
		function()
			return Presenter:ReadValue(fieldID)
		end,
		function(value)
			Presenter:SetValue(fieldID, value)
			updateMethod(owner)
		end)
	then
		updateMethod(owner)
		registerSettingsRefresher(
			function()
				updateMethod(owner)
			end,
			{ fieldID = fieldID })
	end
end

function SP:SetupApplyDropdown()
	setupPresenterDropdown(
		self, self.applyDropdown, "applyMode", SP.UpdateApplyDropdown)
end

function SP:UpdateApplyDropdown()
	updatePresenterDropdown(self.applyDropdown, "applyMode")
end

function SP:SetupTeamListColorSchemeDropdown()
	setupPresenterDropdown(
		self, self.teamListColorSchemeDropdown, "teamListColorScheme",
		SP.UpdateTeamListColorSchemeDropdown)
end

function SP:UpdateTeamListColorSchemeDropdown()
	updatePresenterDropdown(self.teamListColorSchemeDropdown, "teamListColorScheme")
end

function SP:SetupMemberDisplayModeDropdown()
	setupPresenterDropdown(
		self,
		self.memberDisplayModeDropdown,
		"memberDisplayMode",
		SP.UpdateMemberDisplayModeDropdown)
end

function SP:UpdateMemberDisplayModeDropdown()
	updatePresenterDropdown(
		self.memberDisplayModeDropdown, "memberDisplayMode")
end

function SP:SetupExpiredGroupModeDropdown()
	setupPresenterDropdown(
		self,
		self.expiredGroupModeDropdown,
		"expiredGroupMode",
		SP.UpdateExpiredGroupModeDropdown)
end

function SP:UpdateExpiredGroupModeDropdown()
	updatePresenterDropdown(
		self.expiredGroupModeDropdown, "expiredGroupMode")
end

function SP:SetupMemberTooltipModeDropdown()
	setupPresenterDropdown(
		self,
		self.memberTooltipModeDropdown,
		"memberTooltipMode",
		SP.UpdateMemberTooltipModeDropdown)
end

function SP:UpdateMemberTooltipModeDropdown()
	updatePresenterDropdown(
		self.memberTooltipModeDropdown, "memberTooltipMode")
end

function SP:SetupApplicantAlertSoundDropdown()
	setupPresenterDropdown(
		self,
		self.applicantAlertSoundDropdown,
		"applicantAlertSoundFile",
		SP.UpdateApplicantAlertSoundDropdown)
end

function SP:UpdateApplicantAlertSoundDropdown()
	updatePresenterDropdown(
		self.applicantAlertSoundDropdown, "applicantAlertSoundFile")
end

function SP:SetupFrameStrataDropdown()
	setupPresenterDropdown(
		self,
		self.frameStrataDropdown,
		"frameStrata",
		SP.UpdateFrameStrataDropdown)
end

local function restoreInterfaceLocalePopupLayout(dialog)
	local state = dialog and dialog._gfLocaleReloadLayoutState
	if not state then return end
	local text = dialog.GetTextFontString
		and dialog:GetTextFontString() or dialog.Text
	if text then
		if state.wordWrap ~= nil and text.SetWordWrap then
			text:SetWordWrap(state.wordWrap)
		end
		if state.maxLines ~= nil and text.SetMaxLines then
			text:SetMaxLines(state.maxLines)
		end
	end
	dialog._gfLocaleReloadLayoutState = nil
end

local function installInterfaceLocalePopupLayout(dialog)
	restoreInterfaceLocalePopupLayout(dialog)
	local text = dialog and dialog.GetTextFontString
		and dialog:GetTextFontString() or dialog and dialog.Text
	if not text then return end
	local state = {}
	if text.CanWordWrap then state.wordWrap = text:CanWordWrap() end
	if text.GetMaxLines then state.maxLines = text:GetMaxLines() end
	dialog._gfLocaleReloadLayoutState = state
	-- StaticPopup_Show calls native Resize after OnShow, so its height follows
	-- the complete wrapped text, even when another dialog left this pool slot
	-- with single-line settings.
	if text.SetWordWrap then text:SetWordWrap(true) end
	if text.SetMaxLines then text:SetMaxLines(0) end
end

function SP:ShowInterfaceLocaleReloadPrompt()
	if not (GF.Locale and GF.Locale:IsReloadRequired()) then return false end
	if not (type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function") then
		return false
	end
	local L = GF.L or {}
	StaticPopupDialogs.GROUPFINDER_LOCALE_RELOAD = {
		text = L.SET_INTERFACE_LANGUAGE_RELOAD_CONFIRM or "Reload the UI to apply the selected addon language?",
		button1 = L.SET_INTERFACE_LANGUAGE_RELOAD_NOW or "Reload now",
		button2 = L.SET_INTERFACE_LANGUAGE_RELOAD_LATER or "Later",
		-- Pair the 360-wide text with the native 420-wide dialog so the body
		-- keeps 30 units of horizontal inset on each side, including text scaling.
		wide = true,
		wideText = true,
		OnShow = installInterfaceLocalePopupLayout,
		OnHide = restoreInterfaceLocalePopupLayout,
		OnAccept = function()
			if GF.Locale:IsReloadRequired() and type(ReloadUI) == "function" then ReloadUI() end
		end,
		timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
	}
	StaticPopup_Show("GROUPFINDER_LOCALE_RELOAD")
	return true
end

function SP:SetupInterfaceLocaleDropdown()
	local dropdown = self.interfaceLocaleDropdown
	if installRadioOptions(dropdown,
		function() return Presenter:GetOptions("interfaceLocale", GF.L) end,
		function() return Presenter:ReadValue("interfaceLocale") end,
		function(value)
			local changed, _, committed = Presenter:SetValue("interfaceLocale", value)
			self:UpdateInterfaceLocaleDropdown()
			if changed and committed then self:ShowInterfaceLocaleReloadPrompt() end
		end)
	then
		self:UpdateInterfaceLocaleDropdown()
		registerSettingsRefresher(function() self:UpdateInterfaceLocaleDropdown() end,
			{ fieldID = "interfaceLocale" })
	end
end

function SP:UpdateInterfaceLocaleDropdown()
	updatePresenterDropdown(self.interfaceLocaleDropdown, "interfaceLocale")
	if GF.Locale and GF.Locale:IsReloadRequired() then
		local projection = Presenter:ProjectOptionField("interfaceLocale", GF.L)
		setDropdownCaption(self.interfaceLocaleDropdown, (projection.label or "")
			.. ((GF.L or {}).SET_INTERFACE_LANGUAGE_PENDING or " (reload pending)"))
	elseif type(StaticPopup_Hide) == "function" then
		StaticPopup_Hide("GROUPFINDER_LOCALE_RELOAD")
	end
end

function SP:UpdateFrameStrataDropdown()
	updatePresenterDropdown(self.frameStrataDropdown, "frameStrata")
end

function SP:SetupWorkspaceTabPositionDropdown()
	setupPresenterDropdown(
		self,
		self.workspaceTabPositionDropdown,
		"workspaceTabPosition",
		SP.UpdateWorkspaceTabPositionDropdown)
end

function SP:UpdateWorkspaceTabPositionDropdown()
	updatePresenterDropdown(self.workspaceTabPositionDropdown, "workspaceTabPosition")
end

function SP:SetupPanelSkinDropdown()
	setupPresenterDropdown(
		self,
		self.panelSkinDropdown,
		"panelSkin",
		SP.UpdatePanelSkinDropdown)
end

function SP:UpdatePanelSkinDropdown()
	updatePresenterDropdown(self.panelSkinDropdown, "panelSkin")
end

function SP:SetupFontDropdown()
	setupPresenterDropdown(
		self, self.fontDropdown, "fontKey", SP.UpdateFontDropdown)
end

function SP:SetupFontOutlineDropdown()
	setupPresenterDropdown(
		self,
		self.fontOutlineDropdown,
		"fontOutline",
		SP.UpdateFontOutlineDropdown)
end

function SP:UpdateFontOutlineDropdown()
	updatePresenterDropdown(self.fontOutlineDropdown, "fontOutline")
end

function SP:UpdateFontDropdown()
	updatePresenterDropdown(self.fontDropdown, "fontKey")
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

local function updateSettingsScrollBar(panel, contentHeight, viewportHeight)
	-- ScrollFrame ranges can lag behind a category/size change. Own visibility
	-- from the page geometry, with the same one-unit tolerance as the dungeon list.
	local scrollable = viewportHeight > 0 and contentHeight > viewportHeight + 1
	panel._settingsScrollable = scrollable
	local bar = panel.scrollBar or (panel.scroll and panel.scroll.ScrollBar)
	if not bar then
		return
	end
	if bar._gfHideIfUnscrollable then
		bar._gfHideIfUnscrollable = nil
		if bar.SetHideIfUnscrollable then
			bar:SetHideIfUnscrollable(false)
		end
	end
	if bar.SetScrollAllowed then
		bar:SetScrollAllowed(scrollable)
	end
	if panel._settingsScrollBar then
		panel._settingsScrollBar.Refresh()
	else
		bar:SetShown(scrollable)
	end
end

local function bindSettingsScrollBar(panel)
	updateSettingsScrollBar(panel, 0, 0)
	local scroll, bar, host = panel.scroll, panel.scrollBar, panel.contentHost
	if not scroll or not bar or not host then return end
	local layout = SETTINGS_INIT_LAYOUT
	local bottomInset = GF.CONTENT_SCROLL_INSET_B or 0
	bar:SetWidth(layout.scrollBarWidth)
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", host, "TOPRIGHT", -layout.scrollBarRightInset,
		-layout.pageHeaderH - layout.scrollBarTopInset)
	bar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -layout.scrollBarRightInset,
		bottomInset + layout.scrollBarBottomInset)
	panel._settingsScrollBar = GF.UI.BindDynamicScrollBar(scroll, bar, {
		gutter = layout.scrollBarGutter,
		duration = GF.PLAYER_MANAGEMENT_STYLE.scrollBarDuration,
		isScrollable = function() return panel._settingsScrollable == true end,
		isScrollAllowed = function() return panel._settingsScrollable == true end,
		onInsetChanged = function(inset)
			panel._settingsScrollInset = inset
			scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT",
				-layout.scrollInsetR - inset, bottomInset)
			panel:UpdateScroll()
		end,
	})
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

	local selectedCategoryID = Presenter:GetSelectedCategory()
	local activePage = self.pages
		and self.pages[selectedCategoryID]
	local bodyH = activePage and activePage._gfBodyH
		or self.bodyH
		or 1
	if activePage and activePage._gfFillViewport then
		bodyH = math.max(bodyH, scrollH)
	end
	local categoryID = selectedCategoryID or ""
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
	updateSettingsScrollBar(self, bodyH, scrollH)
	GF.UI.UpdateScrollFrame(self.scroll)
	self._updatingScroll = false
end

local SETTINGS_CATEGORY_IDS = Presenter:GetCategoryIDs()

local function getSettingsCategoryDefinitions()
	return Presenter:GetCategoryDefinitions(GF.L)
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
	createSettingsSection = createSettingsSection,
	styleVisualAppearancePanel =
		styleVisualAppearancePanel,
	updateSettingsSectionHeights =
		updateSettingsSectionHeights,
	finishSettingsSection = finishSettingsSection,
})


function SP:GetNetEasePageContext()
	return {
		addSettingsRow = addSettingsRow,
		styleSettingsLabel = styleSettingsLabel,
		fitSettingsText = fitSettingsText,
		setSettingsWidgetEnabled = setSettingsWidgetEnabled,
		registerSettingsRefresher = registerSettingsRefresher,
		updateSettingsSectionHeights = updateSettingsSectionHeights,
		createSettingsPage = createSettingsPage,
		finishSettingsPage = finishSettingsPage,
		createSingleCardSettingsSection = createSingleCardSettingsSection,
		finishSingleCardSettingsSection = finishSingleCardSettingsSection,
		addCheckRow = addCheckRow,
		OPTIONS_CHECK_BUTTON_SIZE = OPTIONS_CHECK_BUTTON_SIZE,
		OPTIONS_ROW_HEIGHT = OPTIONS_ROW_HEIGHT,
		OPTIONS_CONTENT_TOP_OFFSET = OPTIONS_CONTENT_TOP_OFFSET,
		OPTIONS_CONTENT_BOTTOM_PADDING = OPTIONS_CONTENT_BOTTOM_PADDING,
		SECTION_GAP = SECTION_GAP,
		OPTIONS_VISUAL_GROUP_BODY_INSET_X = OPTIONS_VISUAL_GROUP_BODY_INSET_X,
	}
end

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
		button.label._gfFontSizeOverride = GF.NAV_ROOT_TEXT_SIZE
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
	installSettingsNewFeatureBadge(
		button,
		definition.newFeature)
	installSettingsActivityBadge(
		button,
		button.label,
		definition.activityBadge)
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
	local selectedCategoryID = Presenter:GetSelectedCategory()
	for categoryID, button in pairs(self.categoryButtons or {}) do
		updateSettingsCategoryButton(
			button,
			categoryID == selectedCategoryID)
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
		if button and button._gfActivityBadge then
			button._gfActivityBadge:ApplyActivitySpec(
				definition.activityBadge)
		end
	end
	local selectedCategoryID = Presenter:GetSelectedCategory()
	local definition = self.categoryInfoByID[
		selectedCategoryID or SETTINGS_CATEGORY_IDS[1]]
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
	categoryID = Presenter:ResolveCategory(categoryID)
	if categoryID == "netease_newbie" and not self.pages[categoryID] then
		local loaded = GF.NetEaseModule:EnsureLoaded()
		if loaded and GF.NetEaseSettingsPage then
			GF.NetEaseSettingsPage:Build(self, self:GetNetEasePageContext())
		else
			local message = (GF.L and GF.L.SET_NETEASE_MODULE_UNAVAILABLE)
				or "网易活动组件不可用，请检查是否已安装并启用。"
			if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(message) end
			return
		end
	end
	local route = Presenter:SelectCategory(categoryID, self.pages, GF.L)
	if not route then
		return
	end
	categoryID = route.id
	if GF.UI.CancelSmoothWheelScrolling then
		GF.UI.CancelSmoothWheelScrolling(self.scroll)
	end

	local previousID = route.previousID
	if previousID
		and not self._preserveCategoryScrollOnInit
		and self.scroll
		and self.scroll.GetVerticalScroll
	then
		Presenter:RememberCategoryScroll(
			previousID,
			self.scroll:GetVerticalScroll() or 0
		)
	end

	for id, page in pairs(self.pages) do
		page:SetShown(id == categoryID)
	end
	local definition = route.category
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
		self.scroll:SetVerticalScroll(route.scrollOffset or 0)
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
		maxLines = text.GetMaxLines and text:GetMaxLines() or nil,
		justifyH = text.GetJustifyH and text:GetJustifyH() or nil,
	}
	if text.CanWordWrap then
		dialog._gfResetPopupLayoutState.wordWrap = text:CanWordWrap()
	end
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
	return Presenter:FormatResetConfirmation(categoryID, GF.L)
end

function SP:ResetCategoryDefaults(categoryID)
	if not self.pages or not self.pages[categoryID] then
		return false
	end
	if activeSettingsNumberBox
		and activeSettingsNumberBox.ClearFocus
	then
		activeSettingsNumberBox:ClearFocus()
	end
	if self.mythicPlusTeleportMessageBox
		and self.mythicPlusTeleportMessageBox.ClearFocus
	then
		self.mythicPlusTeleportMessageBox:ClearFocus()
	end
	local options = {}
	if categoryID == "tactical" then
		options.challengeModeIDs = {}
		for challengeModeID in pairs(self.tacticalDungeonByID or {}) do
			options.challengeModeIDs[#options.challengeModeIDs + 1] =
				challengeModeID
		end
	end
	if not Presenter:ResetCategory(categoryID, options) then
		return false
	end
	if categoryID == "tactical" and self.LoadTacticalDungeon then
		self:LoadTacticalDungeon(Presenter:GetTacticalSelection())
	end
	self:UpdateScroll()
	return true
end

function SP:RefreshFromDB()
	Presenter:RefreshView({ reason = "database-refresh" })
	self:UpdateScroll()
end

function SP:RefreshLocale()
	if GF.MythicPlusKeystoneRotationReminderDialog
		and GF.MythicPlusKeystoneRotationReminderDialog.RefreshLocale
	then
		GF.MythicPlusKeystoneRotationReminderDialog:RefreshLocale()
	end
	if not self.parent or not self.scroll then
		return
	end
	if GF.UI.CancelSmoothWheelScrolling then
		GF.UI.CancelSmoothWheelScrolling(self.scroll)
	end
	self:CaptureTacticalDraft()
	local selectedCategoryID = Presenter:GetSelectedCategory(GF.L)
	local scrollOffset = 0
	if selectedCategoryID
		and self.scroll.GetVerticalScroll
	then
		scrollOffset =
			self.scroll:GetVerticalScroll() or 0
		Presenter:RememberCategoryScroll(
			selectedCategoryID, scrollOffset)
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
	if SP._updatingScroll
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
		-- The scroll child has an explicit width: update it during the drag so
		-- its anchored cards and controls follow the viewport immediately.
		SP:CancelUpdateScrollDebounce()
		SP:UpdateScroll()
	end
end

function SP:Init(parent)
	if self.scroll then
		return
	end

	self.parent = parent
	SP.LocaleBinding:Reset()

	local L = GF.L or {}

	self.container = CreateFrame("Frame", nil, parent)
	self.container:SetScript("OnHide", function()
		local alerts = GF.ApplicantAlertService
		if alerts and alerts.StopPreview then alerts:StopPreview() end
	end)
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
		-(GF.NAV_DIVIDER_TOP_OFFSET or 0))
	self.menuDivider:SetPoint(
		"BOTTOM",
		self.contentHost,
		"BOTTOMLEFT",
		0,
		GF.NAV_DIVIDER_BOTTOM_OFFSET or 0)
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

	local headerRule = createOptionsTitleDivider(
		self.pageHeader, "ARTWORK", SETTINGS_HEADER_DIVIDER_COLOR)
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
		local categoryID = Presenter:GetSelectedCategory()
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
				- 12)
		-- Parent scaling can report subpixel width noise. Reapplying the font
		-- here remeasures scaled glyphs and makes a fitted description jump.
		-- Locale/font refreshes keep their own explicit fitting paths.
		if self._lastHeaderTextWidth
			and math.abs(availableWidth - self._lastHeaderTextWidth) < 0.5
		then
			return
		end
		self._lastHeaderTextWidth = availableWidth
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
	bindSettingsScrollBar(self)
	self.scroll._gfWheelAllow = function()
		return self._settingsScrollable == true
	end
	if GF.UI.BindSmoothWheelScrolling then
		GF.UI.BindSmoothWheelScrolling(self.scroll, {
			speed = 10,
			epsilon = 0.05,
		})
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

	local visualGroup
	section, visualGroup = createSingleCardSettingsSection(
		appearancePage,
		L.SET_VISUAL_GROUP_PANEL or "Main window",
		y)
	self.panelSkinDropdown = addDropdownSettingRow(
		visualGroup,
		L.SET_PANEL_SKIN or "Window skin",
		L.SET_PANEL_SKIN_HINT or "",
		{
			newFeature = {
				featureID = "panelSkin",
				revision = 1,
				introducedInVersion = "2.1.3",
				hideAtVersion = "2.1.4",
			},
		})
	self:SetupPanelSkinDropdown()
	self.workspaceTabPositionDropdown = addDropdownSettingRow(visualGroup,
		L.SET_WORKSPACE_TAB_POSITION or "Tab position",
		L.SET_WORKSPACE_TAB_POSITION_HINT or "")
	self:SetupWorkspaceTabPositionDropdown()
	self.frameStrataDropdown = addDropdownSettingRow(visualGroup, L.SET_FRAME_STRATA or "Display layer", L.SET_FRAME_STRATA_HINT or "")
	self:SetupFrameStrataDropdown()
	addIntSliderRow(visualGroup, {
		fieldID = "panelScalePct",
		label = L.SET_PANEL_SCALE or "Window scale",
		tooltip = L.SET_PANEL_SCALE_HINT or "",
		min = GF.PANEL_SCALE_MIN_PCT or 100,
		max = GF.PANEL_SCALE_MAX_PCT or 150,
		step = 1,
		stepUnit = "percent",
		formatValue = function(v)
			return string.format("%d%%", v)
		end,
		sliderWidth = OPTIONS_VISUAL_SLIDER_W,
		stableThumbDrag = true,
	})
	y = finishSingleCardSettingsSection(section, visualGroup, y)

	section, visualGroup = createSingleCardSettingsSection(
		appearancePage,
		L.SET_VISUAL_GROUP_TEXT or "Language and fonts",
		y)
	self.interfaceLocaleDropdown = addDropdownSettingRow(
		visualGroup,
		L.SET_INTERFACE_LANGUAGE or "Interface Language",
		L.SET_INTERFACE_LANGUAGE_HINT
			or "Changes addon text only. Game content uses the client language.")
	self:SetupInterfaceLocaleDropdown()
	self.fontDropdown = addDropdownSettingRow(visualGroup, L.SET_FONT or "Font style", L.SET_FONT_HINT or "")
	self:SetupFontDropdown()
	self.fontOutlineDropdown = addDropdownSettingRow(visualGroup, L.SET_FONT_OUTLINE or "Text outline", L.SET_FONT_OUTLINE_HINT or "")
	self:SetupFontOutlineDropdown()
	self.fontScaleSlider, self.fontScaleValue = addIntSliderRow(visualGroup, {
		fieldID = "fontScalePct",
		label = L.SET_FONT_SCALE or "Text size",
		tooltip = L.SET_FONT_SCALE_HINT or "",
		min = GF.FONT_SCALE_MIN_PCT or 100,
		max = GF.FONT_SCALE_MAX_PCT or 150,
		step = 1,
		stepUnit = "percent",
		formatValue = function(v)
			return string.format("%d%%", v)
		end,
		sliderWidth = OPTIONS_VISUAL_SLIDER_W,
	})
	y = finishSingleCardSettingsSection(section, visualGroup, y)

	section, visualGroup = createSingleCardSettingsSection(
		appearancePage,
		L.SET_SECTION_INTERFACE or "Floating window",
		y)
	addCheckRow(visualGroup,
		L.SET_SHOW_FLOAT or "Show floating button",
		L.SET_SHOW_FLOAT_HINT or "", "showFloatButton")
	addCheckRow(visualGroup,
		L.SET_LOCK_FLOAT_BUTTON or "Lock floating window",
		L.SET_LOCK_FLOAT_BUTTON_HINT or "", "lockFloatButton")
	self.floatScaleSlider, self.floatScaleValue = addIntSliderRow(visualGroup, {
		fieldID = "floatScalePct",
		sliderWidth = OPTIONS_VISUAL_SLIDER_W,
		label = L.SET_FLOAT_SCALE or "Floating window scale",
		tooltip = L.SET_FLOAT_SCALE_HINT or "",
		min = GF.FLOAT_SCALE_MIN_PCT or 50,
		max = GF.FLOAT_SCALE_MAX_PCT or 150,
		step = 1,
		stepUnit = "percent",
		formatValue = function(v)
			return string.format("%d%%", v)
		end,
	})
	y = finishSingleCardSettingsSection(section, visualGroup, y)

	section, visualGroup = createSingleCardSettingsSection(
		appearancePage,
		L.SET_SECTION_INSTANCE_GATEWAY or "Instance Difficulty Overlay",
		y)
	installSettingsNewFeatureBadge(
		visualGroup,
		Presenter:GetCategoryInfo("appearance").newFeature)
	addCheckRow(
		visualGroup,
		L.SET_INSTANCE_GATEWAY or "Show difficulty overlay",
		L.SET_INSTANCE_GATEWAY_HINT or "",
		"instanceGatewayEnabled")
	addSettingsActionRow(visualGroup, {
		label = L.SET_INSTANCE_GATEWAY_POSITION or "Adjust overlay position",
		tooltip = L.SET_INSTANCE_GATEWAY_POSITION_HINT or "",
		buttonText = L.SET_INSTANCE_GATEWAY_POSITION_BUTTON or "Adjust position",
		actionID = "instanceGatewayEdit",
		onClick = function()
			Presenter:InvokeAction("instanceGatewayEdit")
		end,
	})
	y = finishSingleCardSettingsSection(section, visualGroup, y)

	section, visualGroup = createSingleCardSettingsSection(
		appearancePage,
		L.SET_VISUAL_GROUP_ENTRY or "Minimap and entry points",
		y)
	addCheckRow(visualGroup,
		L.SET_SHOW_MINIMAP or "Show minimap button",
		L.SET_SHOW_MINIMAP_HINT or "", "showMinimap")
	addCheckRow(visualGroup,
		L.SET_MINIMAP_SQUARE_ORBIT or "Square minimap orbit",
		L.SET_MINIMAP_SQUARE_ORBIT_HINT or "", "minimapSquareOrbit")
	addCheckRow(visualGroup,
		L.SET_PREF_OPEN or "Use GroupFinder for Premade Groups",
		L.SET_PREF_OPEN_HINT or "", "preferOpen")
	y = finishSingleCardSettingsSection(section, visualGroup, y)

	section, sectionGroup = createSingleCardSettingsSection(
		notificationsPage,
		L.SET_SECTION_ALERTS or "Sounds and reminders",
		notificationsY)
	self.applicantAlertSoundDropdown = addDropdownSettingRow(
		sectionGroup,
		L.SET_APPLICANT_ALERT_SOUND or "Alert sound",
		L.SET_APPLICANT_ALERT_SOUND_HINT or "",
		{
			newFeature = {
				featureID = "applicantAlertSound",
				revision = 2,
				introducedInVersion = "2.1.4",
				hideAtVersion = "2.1.5",
			},
		})
	self:SetupApplicantAlertSoundDropdown()
	local joinAnnouncePreviewW = GF.PANEL_BUTTON_STANDARD_W or 72
	local joinAnnounceRow = addCheckRow(
		sectionGroup,
		L.SET_JOIN_ANNOUNCE or "Group joined alert",
		L.SET_JOIN_ANNOUNCE_HINT or "",
		"joinAnnounceEnabled")
	self.joinAnnouncePreviewBtn = GF.UI.CreatePanelButton(joinAnnounceRow.control, L.SET_JOIN_ANNOUNCE_PREVIEW or "Preview", joinAnnouncePreviewW)
	self.joinAnnouncePreviewBtn:SetPoint("RIGHT", joinAnnounceRow.control, "RIGHT", 0, 0)
	fitSettingsText(
		self.joinAnnouncePreviewBtn:GetFontString(),
		math.max(1, self.joinAnnouncePreviewBtn:GetWidth() - 12),
		8)
	SP.LocaleBinding:BindText(
		self.joinAnnouncePreviewBtn,
		L.SET_JOIN_ANNOUNCE_PREVIEW or "Preview",
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
		Presenter:InvokeAction("joinAnnouncePreview")
	end)
	local function addTeleportPreviewButton(
		row, actionID, failureKeys, fallbacks)
		local button = GF.UI.CreatePanelButton(
			row.control,
			L.SET_MPLUS_TELEPORT_PREVIEW or "Preview",
			GF.PANEL_BUTTON_STANDARD_W or 72)
		button:SetPoint("RIGHT", row.control, "RIGHT", 0, 0)
		fitSettingsText(
			button:GetFontString(),
			math.max(1, button:GetWidth() - 12),
			8)
		SP.LocaleBinding:BindText(
			button,
			L.SET_MPLUS_TELEPORT_PREVIEW or "Preview",
			nil,
			function(target)
				fitSettingsText(
					target:GetFontString(),
					math.max(1, target:GetWidth() - 12),
					8)
			end)
		button:SetScript("OnClick", function()
			local opened, reason = Presenter:InvokeAction(actionID)
			if opened == true then
				return
			end
			local locale = GF.L or L or {}
			local key = reason == "combat" and failureKeys.combat
				or reason == "no-data" and failureKeys.noData
				or failureKeys.unavailable
			local fallback = reason == "combat" and fallbacks.combat
				or reason == "no-data" and fallbacks.noData
				or fallbacks.unavailable
			local message = locale[key] or fallback
			if GF.ShowStatusMessage then
				GF.ShowStatusMessage(message, { semantic = true })
			elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
				DEFAULT_CHAT_FRAME:AddMessage(tostring(message or ""))
			end
		end)
		local function refreshAvailability()
			setSettingsWidgetEnabled(
				button,
				Presenter:ProjectAction(actionID).enabled)
		end
		registerSettingsRefresher(refreshAvailability)
		refreshAvailability()
		return button
	end

	local groupReadyRow, groupReadyCheck = addMythicPlusAnnouncementCheckRow(
		sectionGroup,
		L.SET_MPLUS_GROUP_READY_TELEPORT or "Full-party teleport",
		L.SET_MPLUS_GROUP_READY_TELEPORT_HINT or "",
		"groupReadyTeleportEnabled",
		{
			newFeature = {
				featureID = "groupReadyTeleportEnabled",
				revision = 1,
				introducedInVersion = "2.1.10",
				hideAtVersion = "2.1.11",
			},
		})
	self.mythicPlusGroupReadyTeleportCheck = groupReadyCheck
	self.mythicPlusGroupReadyTeleportPreviewButton = addTeleportPreviewButton(
		groupReadyRow,
		"groupReadyTeleportPreview",
		{
			combat = "MPLUS_GROUP_READY_TELEPORT_PREVIEW_COMBAT",
			noData = "MPLUS_GROUP_READY_TELEPORT_PREVIEW_NO_DATA",
			unavailable = "MPLUS_GROUP_READY_TELEPORT_PREVIEW_UNAVAILABLE",
		},
		{
			combat = "The full-party teleport popup cannot be previewed during combat.",
			noData = "No current-season dungeon data is available for preview.",
			unavailable = "The full-party teleport popup preview is temporarily unavailable.",
		})
	local followRow, followCheck = addMythicPlusAnnouncementCheckRow(
		sectionGroup,
		L.SET_MPLUS_TELEPORT_FOLLOW or "Follow teleport",
		L.SET_MPLUS_TELEPORT_FOLLOW_HINT or "",
		"teleportFollowEnabled")
	self.mythicPlusTeleportFollowCheck = followCheck
	self.mythicPlusTeleportPreviewButton = addTeleportPreviewButton(
		followRow,
		"teleportFollowPreview",
		{
			combat = "MPLUS_TELEPORT_PREVIEW_COMBAT",
			noData = "MPLUS_TELEPORT_PREVIEW_NO_DATA",
			unavailable = "MPLUS_TELEPORT_PREVIEW_UNAVAILABLE",
		},
		{
			combat = "The follow-teleport popup cannot be previewed during combat.",
			noData = "No current-season dungeon data is available for preview.",
			unavailable = "The follow-teleport popup preview is temporarily unavailable.",
		})

	local reminderRow, reminderCheck =
		addKeystoneRotationReminderCheckRow(
			sectionGroup,
			L.SET_MPLUS_KEYSTONE_ROTATION_REMINDER
				or "Keystone replacement reminder",
			L.SET_MPLUS_KEYSTONE_ROTATION_REMINDER_HINT or "")
	self.mythicPlusKeystoneRotationReminderCheck = reminderCheck
	self.mythicPlusKeystoneRotationReminderPreviewButton =
		GF.UI.CreatePanelButton(
			reminderRow.control,
			L.SET_MPLUS_KEYSTONE_ROTATION_PREVIEW or "Preview",
			GF.PANEL_BUTTON_STANDARD_W or 72)
	self.mythicPlusKeystoneRotationReminderPreviewButton:SetPoint(
		"RIGHT", reminderRow.control, "RIGHT", 0, 0)
	fitSettingsText(
		self.mythicPlusKeystoneRotationReminderPreviewButton:GetFontString(),
		math.max(
			1,
			self.mythicPlusKeystoneRotationReminderPreviewButton:GetWidth() - 12),
		8)
	SP.LocaleBinding:BindText(
		self.mythicPlusKeystoneRotationReminderPreviewButton,
		L.SET_MPLUS_KEYSTONE_ROTATION_PREVIEW or "Preview",
		nil,
		function(target)
			fitSettingsText(
				target:GetFontString(),
				math.max(1, target:GetWidth() - 12),
				8)
		end)
	self.mythicPlusKeystoneRotationReminderPreviewButton:SetScript(
		"OnClick",
		function()
			Presenter:InvokeAction("keystoneRotationPreview")
		end)
	local function refreshKeystoneRotationPreviewAvailability()
		setSettingsWidgetEnabled(
			self.mythicPlusKeystoneRotationReminderPreviewButton,
			Presenter:ProjectAction(
				"keystoneRotationPreview").enabled)
	end
	registerSettingsRefresher(refreshKeystoneRotationPreviewAvailability)
	refreshKeystoneRotationPreviewAvailability()

	notificationsY = finishSingleCardSettingsSection(section, sectionGroup, notificationsY)

	section, sectionGroup = createSingleCardSettingsSection(
		notificationsPage,
		L.SET_SECTION_CHAT_ANNOUNCEMENTS or "Chat announcements",
		notificationsY)
	self.mythicPlusTeleportAnnouncementCheck = select(2, addMythicPlusAnnouncementCheckRow(
		sectionGroup,
		L.SET_MPLUS_TELEPORT_ANNOUNCEMENT or "Teleport announcement",
		L.SET_MPLUS_TELEPORT_ANNOUNCEMENT_HINT or "",
		"teleportAnnouncementEnabled"
	))

	local _, teleportMessageBox = addSettingsTextActionRow(sectionGroup, {
		label = L.SET_MPLUS_TELEPORT_MESSAGE or "Teleport announcement text",
		tooltip = L.SET_MPLUS_TELEPORT_MESSAGE_HINT or "",
		placeholder = L.SET_MPLUS_TELEPORT_MESSAGE_PLACEHOLDER or "",
		confirmText = L.SET_MPLUS_SETTING_CONFIRM or "Confirm",
		fieldID = "teleportMessage",
	})
	self.mythicPlusTeleportMessageBox = teleportMessageBox

	self.mythicPlusKeystoneAnnouncementCheck = select(
		2,
		addMythicPlusAnnouncementCheckRow(
			sectionGroup,
			L.SET_MPLUS_KEYSTONE_ANNOUNCEMENT
				or "Keystone change announcement",
			L.SET_MPLUS_KEYSTONE_ANNOUNCEMENT_HINT or "",
			"keystoneAnnouncementEnabled"))

	notificationsY = finishSingleCardSettingsSection(section, sectionGroup, notificationsY)

	tacticalY = GF.SettingsTacticalPage.Build(
		self,
		tacticalPage,
		tacticalY
	)
	section, sectionGroup = createSingleCardSettingsSection(
		partyListPage,
		L.SET_SECTION_LISTING or L.SET_SECTION_LIST or "List display",
		partyY)
	addCheckRow(
		sectionGroup,
		L.SET_SHOW_LEADER_REALM or "Show realm name",
		L.SET_SHOW_LEADER_REALM_HINT or "",
		"showLeaderRealm")
	addCheckRow(
		sectionGroup,
		L.SET_SHOW_GAME_TYPE or "Show playstyle",
		L.SET_SHOW_GAME_TYPE_HINT or "",
		"showGameType")
	self.teamListColorSchemeDropdown = addDropdownSettingRow(
		sectionGroup,
		L.SET_TEAM_LIST_COLOR_SCHEME or "Text colors",
		L.SET_TEAM_LIST_COLOR_SCHEME_HINT or "")
	self:SetupTeamListColorSchemeDropdown()
	self.memberDisplayModeDropdown = addDropdownSettingRow(sectionGroup, L.SET_MEMBER_DISPLAY_MODE or "Member mode", L.SET_MEMBER_DISPLAY_MODE_HINT or "")
	self:SetupMemberDisplayModeDropdown()
	self.expiredGroupModeDropdown = addDropdownSettingRow(
		sectionGroup,
		L.SET_EXPIRED_GROUP_MODE or "Expired groups",
		L.SET_EXPIRED_GROUP_MODE_HINT or "",
		{
			newFeature = {
				featureID = "expiredGroupMode",
				revision = 1,
				introducedInVersion = "2.1.3",
				hideAtVersion = "2.1.4",
			},
		})
	self:SetupExpiredGroupModeDropdown()
	self.memberTooltipModeDropdown = addDropdownSettingRow(sectionGroup, L.SET_MEMBER_TOOLTIP_MODE or "Member tooltip", L.SET_MEMBER_TOOLTIP_MODE_HINT or "")
	self:SetupMemberTooltipModeDropdown()
	partyY = finishSingleCardSettingsSection(section, sectionGroup, partyY)

	section, sectionGroup = createSingleCardSettingsSection(
		partyListPage,
		L.SET_VISUAL_GROUP_LIST or "List colors",
		partyY)
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "normal",
		state = "normal",
		label = L.SET_LIST_BACKGROUND_NORMAL or "Default background",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_NORMAL or "Default listing preview",
	})
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "friend",
		state = "blue",
		label = L.SET_LIST_BACKGROUND_FRIEND or "Friend background",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_FRIEND or "Friend listing preview",
	})
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "warning",
		state = "red",
		label = L.SET_LIST_BACKGROUND_WARNING or "Warning background",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_WARNING or "Warning listing preview",
	})
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "disabled",
		state = "grey",
		label = L.SET_LIST_BACKGROUND_DISABLED or "Grayed-out background",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_DISABLED or "Unavailable",
	})
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "starred",
		state = "starred",
		label = L.SET_LIST_BACKGROUND_STARRED or "Starred leader",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_STARRED or "Starred leader",
	})
	addListBackgroundStyleRow(sectionGroup, {
		styleKey = "censored",
		state = "censored",
		label = L.SET_LIST_BACKGROUND_CENSORED or "Hidden listing",
		previewText = L.SET_LIST_BACKGROUND_PREVIEW_CENSORED or "Hidden listing preview",
	})
	partyY = finishSingleCardSettingsSection(section, sectionGroup, partyY)

	section, sectionGroup = createSingleCardSettingsSection(
		findGroupPage,
		L.SET_SECTION_APPLICATION or "Applications",
		findY)
	self.applyDropdown = addDropdownSettingRow(sectionGroup, L.SET_APPLY_MODE or "Application method", L.SET_APPLY_MODE_HINT or "")
	self.applyDropdown:SetSize(APPLY_DROPDOWN_W, DD_H)
	self:SetupApplyDropdown()
	addCheckRow(
		sectionGroup,
		L.SET_AUTO_ACCEPT_INVITE or "Auto Join",
		L.SET_AUTO_ACCEPT_INVITE_HINT or "",
		"autoAcceptInvite")
	addCheckRow(
		sectionGroup,
		L.SET_REMEMBER_APPLICATION_NOTE or "Keep application note",
		L.SET_REMEMBER_APPLICATION_NOTE_HINT or "",
		"rememberApplicationNote")
	addCheckRow(
		sectionGroup,
		L.SET_REPLACE_OLDEST_APPLICATION or "Replace application at limit",
		L.SET_REPLACE_OLDEST_APPLICATION_HINT or "",
		"replaceOldestApplication")
	findY = finishSingleCardSettingsSection(section, sectionGroup, findY)

	section, sectionGroup = createSingleCardSettingsSection(
		findGroupPage,
		L.SET_SECTION_CREATE or "Create listing",
		findY)
	self.defaultRequiredItemLevelBox = addIntInputRow(sectionGroup, {
		fieldID = "defaultRequiredItemLevel",
		label = L.SET_DEFAULT_REQUIRED_ITEM_LEVEL
			or "Default minimum item level",
		tooltip = L.SET_DEFAULT_REQUIRED_ITEM_LEVEL_HINT or "",
		maxLetters = 4,
	})
	addAutoInviteLimitRow(sectionGroup)
	findY = finishSingleCardSettingsSection(section, sectionGroup, findY)

	section, sectionGroup = createSingleCardSettingsSection(
		findGroupPage,
		L.SET_SECTION_FILTER_BLOCK or "Filters and blocking",
		findY)
	addCheckRow(
		sectionGroup,
		L.SET_BLACKLIST_ENABLED or "Enable blacklist",
		L.SET_BLACKLIST_ENABLED_HINT or "",
		"blacklistEnabled")
	addCheckRow(
		sectionGroup,
		L.SET_BLACKLIST_CHAT_NOTICE or "Show blocking messages",
		L.SET_BLACKLIST_CHAT_NOTICE_HINT
			or "Print a system message in chat when a leader or group is blacklisted.",
		"showBlacklistChatNotice")

	addCheckRow(
		sectionGroup,
		L.SET_MENU_ENHANCEMENT or "Enhance player menus",
		L.SET_MENU_ENHANCEMENT_HINT or "",
		"menuEnhancementEnabled",
		{
			newFeature = {
				featureID = "menuEnhancementEnabled",
				revision = 1,
				introducedInVersion = "2.1.3",
				hideAtVersion = "2.1.4",
			},
		})
	addCheckRow(
		sectionGroup,
		L.SET_AUTO_EXPAND_FILTER or "Auto-expand filter",
		L.SET_AUTO_EXPAND_FILTER_HINT or "",
		"autoExpandFilter")
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
	if GF.UI.BindScrollFrameEdgeFade then
		GF.UI.BindScrollFrameEdgeFade(self.scroll, self.body, GF.SETTINGS_SCROLL_EDGE_FADE)
	end

	Presenter:InitializeView()
	self:EnsureMythicPlusSeasonListener()
	self:SelectCategory(
		Presenter:GetSelectedCategory() or SETTINGS_CATEGORY_IDS[1])
	self:UpdateScroll()
end



local function restoreSelectedCategoryOffset(panel)
	local scroll = panel.scroll
	local categoryID = Presenter:GetSelectedCategory()
	local setOffset = scroll and scroll.SetVerticalScroll
	if not setOffset or not categoryID then
		return
	end
	if GF.UI.CancelSmoothWheelScrolling then
		GF.UI.CancelSmoothWheelScrolling(scroll)
	end
	setOffset(scroll, Presenter:GetCategoryScroll(categoryID))
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
