local _, GF = ...

GF.MythicPlusCharacterPage = GF.MythicPlusCharacterPage or {}
local CharacterPage = GF.MythicPlusCharacterPage
local UI = GF.MythicPlusUI
local ServiceUtil = GF.MythicPlusServiceUtil

local FRAME_TEXTURE_WIDTH = UI.FRAME_TEXTURE_WIDTH
local FRAME_SOURCE_CAP_WIDTH = UI.FRAME_CAP_SOURCE_WIDTH
local FRAME_DISPLAY_CAP_WIDTH = UI.FRAME_CAP_DISPLAY_WIDTH
local FRAME_TEXTURES = UI.FRAME_TEXTURES
local FRAME_ATLAS_TEXTURE = UI.FRAME_ATLAS_TEXTURE
local FRAME_ATLAS_WIDTH = UI.FRAME_ATLAS_WIDTH
local FRAME_ATLAS_HEIGHT = UI.FRAME_ATLAS_HEIGHT

local TITLE_HEIGHT = 40
local TITLE_TEXT_INSET_X = 14
local TITLE_TEXT_SIZE = 14
local TITLE_LEFT_FADE_WIDTH = 74
local TITLE_TOP_OFFSET = -20
local TITLE_TO_CARD_GAP = 14
local CURRENT_AREA_TO_WARBAND_TITLE_GAP = 16

local CARD_MIN_WIDTH = 320
local CARD_HEIGHT = 114
local CARD_GAP_X = 12
local CARD_GAP_Y = 14
local CARD_BOTTOM_GAP = 20
local CURRENT_TO_WARBAND_TITLE_DISTANCE = TITLE_HEIGHT
	+ TITLE_TO_CARD_GAP
	+ CARD_HEIGHT
	+ CURRENT_AREA_TO_WARBAND_TITLE_GAP

local CONTENT_INSET_X = 18
local CONTENT_INSET_TOP = 8
local TOP_SECTION_HEIGHT = 65
local CONTROL_INSET_X = 14
local CONTROL_RIGHT_INSET = 20
local TOP_LABEL_Y = -8
local INFO_ROW_Y = 10

local MODEL_LEGACY_LEFT_INSET = 6
local MODEL_LEFT_BLEED = 2
local MODEL_LEFT_INSET = MODEL_LEGACY_LEFT_INSET - MODEL_LEFT_BLEED
local MODEL_BOTTOM_INSET = 4
-- Keep the text layout on the original footprint while the 3D viewport bleeds
-- to the title atlas bottom edge and the keystone backdrop's left edge.
local MODEL_LAYOUT_WIDTH = 122
local MODEL_TEXT_GAP = 12
local MODEL_RIGHT_BLEED = MODEL_TEXT_GAP
local MODEL_WIDTH = MODEL_LAYOUT_WIDTH + MODEL_RIGHT_BLEED + MODEL_LEFT_BLEED
local MODEL_TOP_BLEED = TITLE_TO_CARD_GAP
local MODEL_HEIGHT = CARD_HEIGHT - MODEL_BOTTOM_INSET + MODEL_TOP_BLEED
local MODEL_FRAME_LEVEL_OFFSET = 120
local MODEL_TEXT_INSET_X = MODEL_LEGACY_LEFT_INSET
	+ MODEL_LAYOUT_WIDTH
	+ MODEL_TEXT_GAP

local ROLE_SECTION_HEIGHT = 40
local ROLE_SECTION_OFFSET_Y = 0
local ROLE_ATLAS_SCALE = 1.10
local ROLE_ATLAS_HEIGHT = 44
local ROLE_ATLAS_OFFSET_Y = -3
-- Source rows 48–51 sit below the main gold rule: transition, gap, fine rule.
-- Keep the original 52-to-44 scale and clip those rows instead of stretching
-- the retained source rows back to 44px.
local ROLE_ATLAS_SOURCE_HEIGHT = GF.ROW_BACKGROUND_SOURCE_HEIGHT or 52
local ROLE_ATLAS_BOTTOM_CROP = 4
local ROLE_ATLAS_VISIBLE_HEIGHT = ROLE_ATLAS_HEIGHT
	* (ROLE_ATLAS_SOURCE_HEIGHT - ROLE_ATLAS_BOTTOM_CROP)
	/ ROLE_ATLAS_SOURCE_HEIGHT
local ROLE_MASK_SKIP_TOP = 8
local ROLE_BAR_ATLAS = GF.ROW_BACKGROUND_ATLAS
local ROLE_LABEL_WIDTH = 112
local ROLE_TOGGLE_WIDTH = 36
local ROLE_TOGGLE_HEIGHT = 20
local ROLE_TOGGLE_GAP = 7
local ROLE_CHECK_SIZE = 18
local ROLE_ICON_SIZE = 20
local ROLE_ICON_LEFT_INSET = 21
local ROLE_ICON_OVERFLOW = 5
local ROLE_RIGHT_INSET = 20
local ROLE_CONTENT_OFFSET_Y = (ROLE_ATLAS_HEIGHT - ROLE_SECTION_HEIGHT) / 2 - 1
local ROLE_CARPOOL_CHECK_OFFSET_Y = -0.5
local ROLE_TOGGLE_GROUP_OFFSET_Y = -0.5
local TalentLoadoutUI = {
	DROPDOWN_WIDTH = 156,
	DROPDOWN_HEIGHT = 26,
	DROPDOWN_TEXT_WIDTH = 120,
	SPEC_ICON_SIZE = 20,
	SPEC_BUTTON_SIZE = 22,
	SPEC_BUTTON_GAP = 5,
	SPEC_GROUP_DROPDOWN_GAP = 24,
	-- WowStyle1DropdownTemplate 的背景区域向左外扩 8px，但 atlas 可见边框
	-- 位于逻辑左边界右侧约 2px。最右侧 22px 专精外环位于 -24px，
	-- 因此两端可见边缘的中点为 -11px。
	SPEC_DIVIDER_DROPDOWN_OFFSET = 11,
	SPEC_DIVIDER_HEIGHT = 20,
	SPEC_DIVIDER_ALPHA = 0.82,
	MAX_SPECIALIZATIONS = 4,
	-- The native background extends 7px above and 9px below the button.
	VISIBLE_CENTER_OFFSET_Y = -1,
	-- The native arrow extends 1px past the button's logical right edge.
	RIGHT_EDGE_OFFSET_X = 1,
}

local WEEKLY_CONTENT_INSET_X = 20
local WEEKLY_COUNT_WIDTH = 170
local WEEKLY_TITLE_Y = -15
local WEEKLY_COUNT_Y = -17
local WEEKLY_DIVIDER_Y = -40
local WEEKLY_DIVIDER_HEIGHT = 1.5
local WEEKLY_VAULT_Y = -50
local WEEKLY_RUNS_Y = -79
local WEEKLY_BODY_HEIGHT = 18
local WEEKLY_REWARD_COLORS = {
	muted = "ff8a8a8a",
	accent = "ffffb80d",
	champion = "ff1eff00",
	hero = "ffa335ee",
	myth = "ffffd100",
}

local BEST_RUNS_PANEL_WIDTH = 760
local BEST_RUNS_PANEL_HEADER_HEIGHT = 62
local BEST_RUNS_PANEL_FOOTER_GAP = 24
local BEST_RUNS_PANEL_BACKGROUND_INSET = 5
local BEST_RUNS_PANEL_BACKGROUND_BOTTOM_INSET = 8
local BEST_RUNS_PANEL_BORDER_INSET_X = 8
local BEST_RUNS_ROW_HEIGHT = 60
local BEST_RUNS_ROW_GAP = 5
local BEST_RUNS_ROW_IMAGE_WIDTH = 274
local BEST_RUNS_ROW_IMAGE_INSET = 4
local BEST_RUNS_ROW_INSET_X = 16
local BEST_RUNS_TIME_COLUMN_X = 388
local BEST_RUNS_LEVEL_COLUMN_X = 525
local BEST_RUNS_SCORE_COLUMN_RIGHT = 28
local BEST_RUNS_MAIN_WINDOW_ALPHA = 0

local ROLE_ORDER = ServiceUtil.ROLE_ORDER
local ROLE_TITLE = {
	TANK = "坦克",
	HEAL = "治疗",
	DPS = "输出",
}
local ROLE_DESCRIPTION = {
	TANK = "表示你愿意通过使敌人攻击自己，保护队友不受攻击。",
	HEAL = "表示你愿意在队友受到伤害时为他们提供治疗。",
	DPS = "表示你愿意担当对敌人输出伤害的职责。",
}
local CLASS_ROLE_AVAILABILITY = {
	DEATHKNIGHT = { TANK = true, DPS = true },
	DEMONHUNTER = { TANK = true, DPS = true },
	DRUID = { TANK = true, HEAL = true, DPS = true },
	EVOKER = { HEAL = true, DPS = true },
	HUNTER = { DPS = true },
	MAGE = { DPS = true },
	MONK = { TANK = true, HEAL = true, DPS = true },
	PALADIN = { TANK = true, HEAL = true, DPS = true },
	PRIEST = { HEAL = true, DPS = true },
	ROGUE = { DPS = true },
	SHAMAN = { HEAL = true, DPS = true },
	WARLOCK = { DPS = true },
	WARRIOR = { TANK = true, DPS = true },
}
local function createText(parent, template, size, flags)
	template = template or "GameFontHighlight"
	local text = GF.UI.CreateFontString(parent, "OVERLAY", template)
	text._gfFontSizeOverride = tonumber(size) or 12
	text._gfFontFlagsOverride = flags or ""
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(text, template)
	end
	return text
end

local function applyHorizontalGradient(texture, r1, g1, b1, a1, r2, g2, b2, a2)
	texture:SetTexture(GF.WHITE_TEXTURE)
	if texture.SetGradient and CreateColor then
		local ok = pcall(texture.SetGradient, texture, "HORIZONTAL",
			CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		local ok = pcall(texture.SetGradientAlpha, texture, "HORIZONTAL",
			r1, g1, b1, a1, r2, g2, b2, a2)
		if ok then
			return
		end
	end
	texture:SetVertexColor(r2, g2, b2, math.max(a1, a2))
end

local function applyVerticalGradient(texture, r1, g1, b1, a1, r2, g2, b2, a2)
	texture:SetTexture(GF.WHITE_TEXTURE)
	if texture.SetGradient and CreateColor then
		local ok = pcall(texture.SetGradient, texture, "VERTICAL",
			CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		local ok = pcall(texture.SetGradientAlpha, texture, "VERTICAL",
			r1, g1, b1, a1, r2, g2, b2, a2)
		if ok then
			return
		end
	end
	texture:SetVertexColor(r2, g2, b2, math.max(a1, a2))
end

local function applyVerticalBlackMask(texture, topAlpha, bottomAlpha)
	if not texture then
		return
	end
	applyVerticalGradient(
		texture,
		0,
		0,
		0,
		topAlpha,
		0,
		0,
		0,
		bottomAlpha
	)
end

local function createSolidTexture(parent, layer, subLevel)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 0)
	texture:SetTexture(GF.WHITE_TEXTURE)
	return texture
end

local function createStretchLayer(parent, region, layer, subLevel)
	local rightStart = FRAME_TEXTURE_WIDTH - FRAME_SOURCE_CAP_WIDTH
	local function createPiece(left, right)
		local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 0)
		GF.UI.SetPixelTextureRegion(
			texture,
			FRAME_ATLAS_TEXTURE,
			{
				region[1] + left,
				region[2],
				right - left,
				region[4],
			},
			FRAME_ATLAS_WIDTH,
			FRAME_ATLAS_HEIGHT)
		return texture
	end
	local pieces = {
		left = createPiece(0, FRAME_SOURCE_CAP_WIDTH),
		center = createPiece(FRAME_SOURCE_CAP_WIDTH, rightStart),
		right = createPiece(rightStart, FRAME_TEXTURE_WIDTH),
	}
	pieces.left:SetPoint("TOPLEFT", parent, "TOPLEFT")
	pieces.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT")
	pieces.left:SetWidth(FRAME_DISPLAY_CAP_WIDTH)
	pieces.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
	pieces.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
	pieces.right:SetWidth(FRAME_DISPLAY_CAP_WIDTH)
	pieces.center:SetPoint("TOPLEFT", pieces.left, "TOPRIGHT")
	pieces.center:SetPoint("BOTTOMRIGHT", pieces.right, "BOTTOMLEFT")
	return pieces
end

local function setLayerAlpha(layer, alpha)
	for _, texture in pairs(layer or {}) do
		texture:SetAlpha(alpha)
	end
end

local function setLayerColor(layer, r, g, b, a)
	for _, texture in pairs(layer or {}) do
		texture:SetVertexColor(r, g, b, a or 1)
	end
end

local function createCardChrome(card)
	card._gfMythicCharacterChrome = {
		dark = createStretchLayer(card, FRAME_TEXTURES.dark, "BACKGROUND", -6),
		brown = createStretchLayer(card, FRAME_TEXTURES.brown, "BACKGROUND", -5),
		class = createStretchLayer(card, FRAME_TEXTURES.class, "BACKGROUND", -4),
		border = createStretchLayer(card, FRAME_TEXTURES.border, "BORDER", 1),
	}
end

local function applyCardChrome(card, variant, classFile)
	local chrome = card._gfMythicCharacterChrome
	if not chrome then
		createCardChrome(card)
		chrome = card._gfMythicCharacterChrome
	end
	local r, g, b = UI.GetClassColor(classFile)
	setLayerColor(chrome.class, r, g, b, 1)
	setLayerAlpha(chrome.dark, variant == "dark" and 1 or 0)
	setLayerAlpha(chrome.brown, variant == "brown" and 1 or 0)
	setLayerAlpha(chrome.class, variant == "class" and 1 or 0)
	setLayerAlpha(chrome.border, 1)
end

local function createRaisedHover(card, raised)
	local hoverFrame = CreateFrame("Frame", nil, card)
	hoverFrame:SetAllPoints(card)
	hoverFrame:SetFrameLevel((card:GetFrameLevel() or 0) + (raised and 80 or 30))
	hoverFrame:EnableMouse(false)
	hoverFrame.owner = card
	local base = createStretchLayer(hoverFrame, FRAME_TEXTURES.border, "OVERLAY", 6)
	local glow = createStretchLayer(hoverFrame, FRAME_TEXTURES.hover, "OVERLAY", 7)
	for _, texture in pairs(glow) do
		texture:SetBlendMode("ADD")
	end
	setLayerAlpha(base, 1)
	setLayerAlpha(glow, 0.74)
	hoverFrame:Hide()
	hoverFrame:SetScript("OnUpdate", function(self)
		if not (self.owner and self.owner.IsMouseOver and self.owner:IsMouseOver()) then
			self:Hide()
		end
	end)
	card:HookScript("OnEnter", function()
		hoverFrame:Show()
	end)
	card:HookScript("OnLeave", function()
		if not (card.IsMouseOver and card:IsMouseOver()) then
			hoverFrame:Hide()
		end
	end)
	card._gfMythicCharacterHover = {
		frame = hoverFrame,
		base = base,
		glow = glow,
	}
end

local function tintRaisedHover(card, classFile)
	local hover = card._gfMythicCharacterHover
	if not hover then
		return
	end
	local r, g, b = UI.GetClassColor(classFile)
	setLayerColor(hover.base, 1, 1, 1, 1)
	setLayerColor(hover.glow, r, g, b, 1)
end

local function createRoundedInsetBackdrop(parent)
	local frameParent = parent:GetParent() or parent
	local backdrop = CreateFrame("Frame", nil, frameParent, "BackdropTemplate")
	backdrop:SetPoint("TOPLEFT", parent, "TOPLEFT")
	backdrop:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
	backdrop:SetFrameLevel(math.max((parent:GetFrameLevel() or 1) - 1, 0))
	backdrop:EnableMouse(false)
	backdrop:SetBackdrop({
		bgFile = GF.WHITE_TEXTURE,
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	backdrop:SetBackdropColor(0, 0, 0, 0.78)
	backdrop:SetBackdropBorderColor(1, 0.82, 0, 0.82)
	parent:HookScript("OnShow", function()
		backdrop:Show()
	end)
	parent:HookScript("OnHide", function()
		backdrop:Hide()
	end)
	return backdrop
end

local function createSectionTitle(parent, text)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(TITLE_HEIGHT)
	local background = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetAllPoints(frame)
	if not GF.UI.TrySetAtlas(
		background,
		GF.BROWSE_HEADER_BACKGROUND_ATLAS,
		false)
	then
		background:SetColorTexture(0, 0, 0, 0.45)
	end
	local fade = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	fade:SetPoint("TOPLEFT", frame, "TOPLEFT")
	fade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
	fade:SetWidth(TITLE_LEFT_FADE_WIDTH)
	applyHorizontalGradient(fade, 0, 0, 0, 0.96, 0, 0, 0, 0)
	local label = createText(frame, "GameFontNormal", TITLE_TEXT_SIZE, "OUTLINE")
	label:SetPoint("TOPLEFT", frame, "TOPLEFT", TITLE_TEXT_INSET_X, 0)
	label:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -TITLE_TEXT_INSET_X, 0)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	label:SetTextColor(1, 0.82, 0, 1)
	label:SetText(text or "")
	frame.Background = background
	frame.LeftFade = fade
	frame.Label = label
	return frame
end

local function alignTitleBackgroundPixelPhase(title, referenceDistance)
	local background = title and title.Background
	if not background then
		return
	end
	local offsetY = 0
	local effectiveScale = background.GetEffectiveScale
		and background:GetEffectiveScale()
	if PixelUtil
		and PixelUtil.GetNearestPixelSize
		and type(effectiveScale) == "number"
		and effectiveScale > 0
	then
		offsetY = PixelUtil.GetNearestPixelSize(
			referenceDistance,
			effectiveScale) - referenceDistance
	end
	if background._gfPixelPhaseOffsetY == offsetY then
		return
	end
	background._gfPixelPhaseOffsetY = offsetY
	background:ClearAllPoints()
	background:SetPoint("TOPLEFT", title, "TOPLEFT", 0, offsetY)
	background:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 0, offsetY)
end

local function createScrollContainer(parent, onSizeChanged)
	local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
	scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT")
	scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
	scrollFrame:EnableMouseWheel(true)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT")
	content:SetSize(math.max(scrollFrame:GetWidth() or 0, 1), 1)
	scrollFrame:SetScrollChild(content)

	local scrollBar = GF.UI.CreateFrameWithTemplateOptions("EventFrame", nil, parent, {
		"MinimalScrollBar",
	})
	if not scrollBar or (not scrollBar.SetValue and not scrollBar.SetScrollPercentage) then
		scrollBar = CreateFrame("Slider", nil, parent)
		scrollBar:SetOrientation("VERTICAL")
		scrollBar:SetValueStep(1)
	end
	scrollBar:SetWidth(GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_WIDTH)
	scrollBar:Hide()

	local useNative = scrollBar.Init and ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar
	if useNative then
		ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollBar)
		if GF.UI.ApplyCommonScrollBarSkin then
			GF.UI.ApplyCommonScrollBarSkin(scrollBar)
		end
	end

	local maxValue = 0
	local syncing
	local function getValue()
		if useNative and scrollBar.GetScrollPercentage then
			return (scrollBar:GetScrollPercentage() or 0) * maxValue
		end
		return scrollBar.GetValue and (scrollBar:GetValue() or 0) or 0
	end
	local function setValue(value)
		value = math.min(math.max(tonumber(value) or 0, 0), maxValue)
		if useNative and scrollBar.SetScrollPercentage then
			scrollBar:SetScrollPercentage(maxValue > 0 and value / maxValue or 0,
				ScrollBoxConstants and ScrollBoxConstants.NoScrollInterpolation)
		elseif scrollBar.SetValue then
			scrollBar:SetValue(value)
		end
	end
	local function applyValue(value)
		value = math.min(math.max(tonumber(value) or 0, 0), maxValue)
		syncing = true
		scrollFrame:SetVerticalScroll(value)
		setValue(value)
		syncing = nil
	end
	local function updateRange()
		if scrollFrame.UpdateScrollChildRect then
			scrollFrame:UpdateScrollChildRect()
		end
		local viewHeight = scrollFrame:GetHeight() or 0
		local contentHeight = content:GetHeight() or 0
		maxValue = math.max(contentHeight - viewHeight, 0)
		if scrollBar.SetMinMaxValues then
			scrollBar:SetMinMaxValues(0, maxValue)
		end
		if scrollBar.SetVisibleExtentPercentage and viewHeight > 0 then
			scrollBar:SetVisibleExtentPercentage(math.min(viewHeight / (viewHeight + maxValue), 1))
		end
		if scrollBar.SetPanExtentPercentage then
			scrollBar:SetPanExtentPercentage(maxValue > 0 and math.min(36 / maxValue, 1) or 0)
		end
		if scrollBar.SetScrollAllowed then
			scrollBar:SetScrollAllowed(maxValue > 1)
		end
		scrollBar:SetShown(maxValue > 1)
		applyValue(math.min(getValue(), maxValue))
	end
	scrollFrame._gfUpdateRange = updateRange

	if not useNative and scrollBar.SetScript and scrollBar.SetValue then
		scrollBar:SetScript("OnValueChanged", function(_, value)
			if not syncing then
				applyValue(value)
			end
		end)
		scrollFrame:SetScript("OnMouseWheel", function(_, delta)
			applyValue(getValue() - delta * 36)
		end)
	end
	scrollFrame:SetScript("OnSizeChanged", function()
		content:SetWidth(math.max(scrollFrame:GetWidth() or 0, 1))
		if onSizeChanged then
			onSizeChanged()
		end
		updateRange()
	end)
	content:HookScript("OnSizeChanged", updateRange)
	return scrollFrame, content, scrollBar
end

local function configurePlayerModel(model)
	if not model or model._gfConfigured then
		return
	end
	local parent = model:GetParent()
	model:SetFrameLevel((parent and parent:GetFrameLevel() or 0) + MODEL_FRAME_LEVEL_OFFSET)
	model:SetUnit("player")
	model:SetCamera(0)
	model:SetPortraitZoom(0.46)
	model:SetPosition(0, 0, -0.20)
	model:SetFacing(0.40)
	if model.RefreshCamera then
		model:RefreshCamera()
	end
	model._gfConfigured = true
end

local function hideNativeCheckButtonTexture(texture)
	if not texture then
		return
	end
	if texture.SetTexture then
		texture:SetTexture(nil)
	end
	if texture.Hide then
		texture:Hide()
	end
	if texture.SetAlpha then
		texture:SetAlpha(0)
	end
end

local function syncCharacterCheckVisual(button, hovered)
	local indicator = button and button._gfCharacterCheckIndicator
	if not indicator then
		return
	end
	local enabled = (not button.IsEnabled or button:IsEnabled())
		and button._available ~= false
	indicator:SetEnabled(enabled)
	indicator:SetChecked(button:GetChecked() == true)
	if GF.UI.SetFilterCheckButtonHovered then
		if hovered == nil then
			hovered = button._gfCharacterCheckHovered == true
				or (button.IsMouseMotionFocus
					and button:IsMouseMotionFocus() == true)
		end
		GF.UI.SetFilterCheckButtonHovered(
			indicator,
			enabled and hovered == true
		)
	end
end

local function setCharacterCheckHovered(button, hovered)
	if not button then
		return
	end
	button._gfCharacterCheckHovered = hovered == true
	syncCharacterCheckVisual(button, hovered)
end

local function installCharacterCheckVisual(button, size, offsetY)
	offsetY = tonumber(offsetY) or 0
	for _, texture in ipairs({
		button:GetNormalTexture(),
		button:GetPushedTexture(),
		button:GetHighlightTexture(),
		button:GetCheckedTexture(),
		button:GetDisabledTexture(),
		button:GetDisabledCheckedTexture(),
	}) do
		hideNativeCheckButtonTexture(texture)
	end
	local indicator = GF.UI.CreateFilterCheckButton(button, {
		size = size,
		markSize = math.max(1, size - 4),
	})
	indicator:SetPoint("LEFT", button, "LEFT", 0, offsetY)
	indicator:EnableMouse(false)
	button._gfCharacterCheckIndicator = indicator

	button._gfCharacterCheckOriginalSetChecked = button.SetChecked
	button.SetChecked = function(self, checked, ...)
		self:_gfCharacterCheckOriginalSetChecked(checked, ...)
		syncCharacterCheckVisual(self)
	end
	button:HookScript("OnClick", function(self)
		syncCharacterCheckVisual(self)
	end)
	button:HookScript("OnShow", syncCharacterCheckVisual)
	button:HookScript("OnEnable", syncCharacterCheckVisual)
	button:HookScript("OnDisable", function(self)
		setCharacterCheckHovered(self, false)
	end)
	button:HookScript("OnHide", function(self)
		setCharacterCheckHovered(self, false)
	end)
	button:HookScript("OnEnter", function(self)
		setCharacterCheckHovered(self, true)
	end)
	button:HookScript("OnLeave", function(self)
		setCharacterCheckHovered(self, false)
	end)
	syncCharacterCheckVisual(button)
end

local function createCharacterCheckButton(parent, labelText, width, checkOffsetY)
	local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	button:SetSize(width, 22)
	installCharacterCheckVisual(button, ROLE_CHECK_SIZE, checkOffsetY)
	local label = createText(button, "GameFontHighlight", 12, "")
	label:SetPoint("LEFT", button, "LEFT", 25, 0)
	label:SetPoint("RIGHT", button, "RIGHT")
	label:SetJustifyH("LEFT")
	label:SetText(labelText or "")
	label:SetTextColor(1, 1, 1, 0.92)
	button.Label = label
	button:SetScript("OnClick", function(self)
		self:SetChecked(self._cachedChecked == true)
	end)
	return button
end

local function createRoleCheckButton(parent, roleKey)
	local button = createCharacterCheckButton(parent, "", ROLE_TOGGLE_WIDTH)
	button:SetHeight(ROLE_TOGGLE_HEIGHT)
	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("LEFT", button, "LEFT", ROLE_ICON_LEFT_INSET, 0)
	icon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
	GF.UI.TrySetAtlas(icon, UI.GetRoleAtlas(roleKey), false)
	button.RoleIcon = icon
	button.RoleKey = roleKey
	function button:SetAvailable(available)
		self._available = available ~= false
		if not self._available then
			self:SetChecked(false)
		end
		self.RoleIcon:SetAlpha(self._available and 1 or 0.32)
		syncCharacterCheckVisual(self)
	end
	button:SetScript("OnClick", function(self)
		if self._available == false then
			self:SetChecked(false)
			return
		end
		local card = self.OwnerCard
		local data = card and card._gfData
		local enabled = self:GetChecked() == true
		local changed
		if card and card.isCurrent and GF.MythicPlusCurrentRoleService then
			changed = GF.MythicPlusCurrentRoleService:SetRole(self.RoleKey, enabled)
		elseif data and data.isDebugTest and GF.MythicPlusDebugService
			and GF.MythicPlusDebugService.SetLocalRole then
			changed = GF.MythicPlusDebugService:SetLocalRole(data.key, self.RoleKey, enabled)
		elseif data and data.key and GF.MythicPlusCharacterStore
			and GF.MythicPlusCharacterStore.SetStoredRole then
			changed = GF.MythicPlusCharacterStore:SetStoredRole(data.key, self.RoleKey, enabled)
		end
		if changed then
			self._cachedChecked = enabled
		else
			self:SetChecked(self._cachedChecked == true)
		end
	end)
	button:SetScript("OnEnter", function(self)
		setCharacterCheckHovered(self, true)
		local locale = GF.L or {}
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(locale["MPLUS_ROLE_" .. roleKey .. "_TITLE"]
			or ROLE_TITLE[roleKey], 1, 0.82, 0)
		GameTooltip:AddLine(locale["MPLUS_ROLE_" .. roleKey .. "_DESC"]
			or ROLE_DESCRIPTION[roleKey], 1, 1, 1, true)
		if self._available == false then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(locale.MPLUS_ROLE_UNAVAILABLE
				or "你的职业无法担任该职责。", 1, 0.1, 0.1, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function(self)
		setCharacterCheckHovered(self, false)
		GameTooltip_Hide()
	end)
	return button
end

function TalentLoadoutUI.GetOptionText(option, index)
	local locale = GF.L or {}
	if option and type(option.name) == "string" and option.name ~= "" then
		return option.name
	end
	return string.format(
		locale.MPLUS_TALENT_LOADOUT_UNNAMED or "天赋配置 %d",
		tonumber(index) or 0
	)
end

function TalentLoadoutUI.GetSelectionText(snapshot)
	local locale = GF.L or {}
	if snapshot
		and snapshot.state == "ready"
		and snapshot.selectedIndex
	then
		local option = snapshot.options
			and snapshot.options[snapshot.selectedIndex]
		if option then
			return TalentLoadoutUI.GetOptionText(
				option,
				snapshot.selectedIndex
			)
		end
	end
	if snapshot
		and snapshot.state == "ready"
		and snapshot.selectionKnown ~= false
	then
		return locale.MPLUS_TALENT_LOADOUT_DEFAULT
			or TALENT_FRAME_DROP_DOWN_DEFAULT
			or "默认天赋配置"
	end
	return locale.MPLUS_TALENT_LOADOUT_UNAVAILABLE
		or "天赋配置暂不可用"
end

function TalentLoadoutUI.FitDropdownText(dropdown)
	if dropdown
		and dropdown.Text
		and GF.Font
		and GF.Font.SetFitWidth
	then
		GF.Font.SetFitWidth(
			dropdown.Text,
			TalentLoadoutUI.DROPDOWN_TEXT_WIDTH,
			8
		)
	end
end

function TalentLoadoutUI.GetSpecializationIcon(option)
	if option and option.icon then
		return option.icon
	end
	if GF.UI and GF.UI.ResolveSpecializationIcon then
		return GF.UI.ResolveSpecializationIcon({
			specID = option and option.specID,
			specName = option and option.name,
		})
	end
	return nil
end

function TalentLoadoutUI.GetSpecializationName(option, index)
	if option and type(option.name) == "string" and option.name ~= "" then
		return option.name
	end
	return string.format(
		(GF.L and GF.L.MPLUS_SPECIALIZATION_UNNAMED)
			or "专精 %d",
		tonumber(index) or 0
	)
end

function TalentLoadoutUI.ShowSpecializationSwitchFailure(status, reason)
	if status == "selected" then
		return
	end
	local locale = GF.L or {}
	local message = reason
	if type(message) ~= "string" or message == "" then
		if status == "switching" then
			message = locale.MPLUS_SPECIALIZATION_SWITCHING
				or "正在切换专精……"
		elseif status == "failed" then
			message = locale.MPLUS_SPECIALIZATION_SWITCH_FAILED
				or "专精切换失败。"
		else
			message = locale.MPLUS_SPECIALIZATION_SWITCH_UNAVAILABLE
				or "当前无法切换专精。"
		end
	end
	if type(GF.ShowWarningMessage) == "function" then
		GF.ShowWarningMessage(message)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(message, 1, 0.82, 0, 1)
	end
end

function TalentLoadoutUI.ShowSpecializationTooltip(button)
	if not (button and button._gfSpecialization) then
		return
	end
	local locale = GF.L or {}
	local option = button._gfSpecialization
	local service = GF.MythicPlusTalentLoadoutService
	local snapshot = service and service:GetSnapshot()
	local isCurrent = snapshot
		and tonumber(snapshot.selectedSpecID) == tonumber(option.specID)
	local isSwitchTarget = snapshot
		and snapshot.specializationSwitchPending == true
		and tonumber(snapshot.switchingSpecID) == tonumber(option.specID)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(
		TalentLoadoutUI.GetSpecializationName(
			option,
			button._gfSpecializationIndex
		),
		1,
		0.82,
		0
	)
	if isCurrent then
		GameTooltip:AddLine(
			locale.MPLUS_SPECIALIZATION_CURRENT
				or "当前专精",
			0.35,
			1,
			0.35
		)
	elseif isSwitchTarget then
		GameTooltip:AddLine(
			locale.MPLUS_SPECIALIZATION_SWITCHING
				or "正在切换专精……",
			1,
			0.82,
			0
		)
	else
		local canSwitch, status, failureReason =
			service and service:GetSpecializationSwitchStatus()
		if canSwitch then
			GameTooltip:AddLine(
				locale.MPLUS_SPECIALIZATION_SWITCH_CLICK
					or "点击切换到此专精。",
				1,
				1,
				1,
				true
			)
		else
			local message = failureReason
			if type(message) ~= "string" or message == "" then
				message = status == "switching"
					and (
						locale.MPLUS_SPECIALIZATION_SWITCHING
							or "正在切换专精……"
					)
					or (
						locale.MPLUS_SPECIALIZATION_SWITCH_UNAVAILABLE
							or "当前无法切换专精。"
					)
			end
			GameTooltip:AddLine(message, 1, 0.2, 0.2, true)
		end
	end
	GameTooltip:Show()
end

function TalentLoadoutUI.CreateSpecializationButtons(
	card,
	parent,
	dropdown
)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint(
		"RIGHT",
		dropdown,
		"LEFT",
		-TalentLoadoutUI.SPEC_GROUP_DROPDOWN_GAP,
		0
	)
	row:SetSize(
		TalentLoadoutUI.MAX_SPECIALIZATIONS
			* TalentLoadoutUI.SPEC_BUTTON_SIZE
			+ (TalentLoadoutUI.MAX_SPECIALIZATIONS - 1)
				* TalentLoadoutUI.SPEC_BUTTON_GAP,
		TalentLoadoutUI.SPEC_BUTTON_SIZE
	)
	card.SpecializationRow = row

	local divider = CreateFrame("Frame", nil, parent)
	divider:SetPoint(
		"CENTER",
		dropdown,
		"LEFT",
		-TalentLoadoutUI.SPEC_DIVIDER_DROPDOWN_OFFSET,
		0
	)
	divider:SetSize(1, TalentLoadoutUI.SPEC_DIVIDER_HEIGHT)
	local dividerTop = divider:CreateTexture(nil, "ARTWORK")
	dividerTop:SetPoint("TOPLEFT", divider, "TOPLEFT")
	dividerTop:SetPoint("BOTTOMRIGHT", divider, "RIGHT")
	applyVerticalGradient(
		dividerTop,
		1,
		0.82,
		0,
		TalentLoadoutUI.SPEC_DIVIDER_ALPHA,
		1,
		0.82,
		0,
		0
	)
	local dividerBottom = divider:CreateTexture(nil, "ARTWORK")
	dividerBottom:SetPoint("TOPLEFT", divider, "LEFT")
	dividerBottom:SetPoint("BOTTOMRIGHT", divider, "BOTTOMRIGHT")
	applyVerticalGradient(
		dividerBottom,
		1,
		0.82,
		0,
		0,
		1,
		0.82,
		0,
		TalentLoadoutUI.SPEC_DIVIDER_ALPHA
	)
	divider.Top = dividerTop
	divider.Bottom = dividerBottom
	card.SpecializationDivider = divider
	card.SpecializationButtons = {}
	local previous
	for index = 1, TalentLoadoutUI.MAX_SPECIALIZATIONS do
		local button = CreateFrame("Button", nil, row)
		button:SetSize(
			TalentLoadoutUI.SPEC_BUTTON_SIZE,
			TalentLoadoutUI.SPEC_BUTTON_SIZE
		)
		button:RegisterForClicks("LeftButtonUp")
		if previous then
			button:SetPoint(
				"LEFT",
				previous,
				"RIGHT",
				TalentLoadoutUI.SPEC_BUTTON_GAP,
				0
			)
		else
			button:SetPoint("LEFT", row, "LEFT")
		end
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("CENTER")
		icon:SetSize(
			TalentLoadoutUI.SPEC_ICON_SIZE,
			TalentLoadoutUI.SPEC_ICON_SIZE
		)
		button.Icon = icon
		button:SetScript("OnClick", function(self)
			local option = self._gfSpecialization
			local service = GF.MythicPlusTalentLoadoutService
			if not (
				option
				and service
				and service.SwitchToSpecialization
			) then
				return
			end
			local switched, status, reason =
				service:SwitchToSpecialization(option.specID)
			if not switched then
				TalentLoadoutUI.ShowSpecializationSwitchFailure(
					status,
					reason
				)
			end
		end)
		button:SetScript("OnEnter", function(self)
			if self._gfSpecializationActive ~= true
				and self.IsEnabled
				and self:IsEnabled()
				and GF.UI
				and GF.UI.SetSpecializationIconHovered then
				GF.UI.SetSpecializationIconHovered(
					self.Icon,
					true,
					self._gfSpecializationVisualOptions
				)
			end
			TalentLoadoutUI.ShowSpecializationTooltip(self)
		end)
		button:SetScript("OnLeave", function(self)
			if GF.UI and GF.UI.SetSpecializationIconHovered then
				GF.UI.SetSpecializationIconHovered(
					self.Icon,
					false,
					self._gfSpecializationVisualOptions
				)
			end
			GameTooltip_Hide()
		end)
		button:Hide()
		card.SpecializationButtons[index] = button
		previous = button
	end
end

function TalentLoadoutUI.StopSpecializationTransition(card)
	if card and card.SpecializationRow then
		card.SpecializationRow:SetScript("OnUpdate", nil)
	end
	if card then
		card._gfSpecializationTransition = nil
	end
end

function TalentLoadoutUI.GetSpecializationTransitionProgress(
	transition
)
	local startTime = transition
		and tonumber(transition.startTime)
	local endTime = transition
		and tonumber(transition.endTime)
	if not (
		startTime
		and endTime
		and endTime > startTime
	) then
		return nil
	end
	local now = GetTime and GetTime() or startTime
	local progress = (now - startTime) / (endTime - startTime)
	if progress <= 0 then
		return 0
	end
	if progress >= 1 then
		return 1
	end
	return progress
end

function TalentLoadoutUI.ApplySpecializationTransition(card)
	local transition = card
		and card._gfSpecializationTransition
	local progress =
		TalentLoadoutUI.GetSpecializationTransitionProgress(
			transition
		)
	if progress == nil then
		return
	end
	for _, button in ipairs(card.SpecializationButtons or {}) do
		local option = button._gfSpecialization
		local specID = option and tonumber(option.specID)
		local activeAmount
		if specID
			and specID == transition.sourceSpecID
		then
			activeAmount = 1 - progress
		elseif specID
			and specID == transition.targetSpecID
		then
			activeAmount = progress
		end
		if activeAmount ~= nil then
			if GF.UI
				and GF.UI.SetSpecializationIconTransition
			then
				GF.UI.SetSpecializationIconTransition(
					button.Icon,
					activeAmount,
					button._gfSpecializationVisualOptions
				)
			else
				local tint = 0.58 + 0.42 * activeAmount
				if button.Icon.SetDesaturation then
					button.Icon:SetDesaturation(
						1 - activeAmount
					)
				else
					button.Icon:SetDesaturated(
						activeAmount < 0.5
					)
				end
				button.Icon:SetVertexColor(
					tint,
					tint,
					tint,
					1
				)
				button.Icon:SetAlpha(
					0.48 + 0.52 * activeAmount
				)
			end
		end
	end
end

function TalentLoadoutUI.UpdateSpecializationTransition(
	card,
	snapshot
)
	TalentLoadoutUI.StopSpecializationTransition(card)
	if not (
		card
		and card.SpecializationRow
		and snapshot
		and snapshot.specializationSwitchPending == true
	) then
		return
	end
	local sourceSpecID = tonumber(
		snapshot.switchingSourceSpecID
			or snapshot.selectedSpecID
	)
	local targetSpecID = tonumber(snapshot.switchingSpecID)
	local startTime =
		tonumber(snapshot.specializationSwitchCastStartTime)
	local endTime =
		tonumber(snapshot.specializationSwitchCastEndTime)
	if not (
		sourceSpecID
		and targetSpecID
		and sourceSpecID ~= targetSpecID
		and startTime
		and endTime
		and endTime > startTime
	) then
		return
	end
	card._gfSpecializationTransition = {
		sourceSpecID = sourceSpecID,
		targetSpecID = targetSpecID,
		startTime = startTime,
		endTime = endTime,
	}
	card.SpecializationRow:SetScript("OnUpdate", function()
		TalentLoadoutUI.ApplySpecializationTransition(card)
	end)
	TalentLoadoutUI.ApplySpecializationTransition(card)
end

function TalentLoadoutUI.UpdateSpecializations(card)
	local row = card and card.SpecializationRow
	local divider = card and card.SpecializationDivider
	local buttons = card and card.SpecializationButtons
	if not (row and divider and buttons) then
		return
	end
	local service = GF.MythicPlusTalentLoadoutService
	local snapshot = service and service:GetSnapshot()
	local options = snapshot and snapshot.specializations or {}
	local count = math.min(
		#options,
		TalentLoadoutUI.MAX_SPECIALIZATIONS
	)
	local canSwitch = service
		and service.GetSpecializationSwitchStatus
		and service:GetSpecializationSwitchStatus()
		or false
	local _, classFile = UnitClass and UnitClass("player")
	for index, button in ipairs(buttons) do
		local option = options[index]
		if option and index <= count then
			local active = snapshot
				and tonumber(snapshot.selectedSpecID)
					== tonumber(option.specID)
			button._gfSpecialization = option
			button._gfSpecializationIndex = index
			button._gfSpecializationActive = active
			local icon = TalentLoadoutUI.GetSpecializationIcon(option)
			if icon and GF.UI and GF.UI.SetSpecializationIcon then
				local visualOptions = {
					size = TalentLoadoutUI.SPEC_ICON_SIZE,
					outerSize = TalentLoadoutUI.SPEC_BUTTON_SIZE,
					separator = true,
					separatorSize = TalentLoadoutUI.SPEC_ICON_SIZE,
					classFile = classFile,
					disabled = not active,
				}
				button._gfSpecializationVisualOptions = visualOptions
				GF.UI.SetSpecializationIcon(
					button.Icon,
					icon,
					visualOptions
				)
			else
				button._gfSpecializationVisualOptions = nil
				button.Icon:SetTexture(icon)
				button.Icon:SetDesaturated(not active)
				button.Icon:SetAlpha(active and 1 or 0.48)
			end
			button:SetEnabled(canSwitch == true and not active)
			button:Show()
		else
			button._gfSpecialization = nil
			button._gfSpecializationIndex = nil
			button._gfSpecializationActive = nil
			button._gfSpecializationVisualOptions = nil
			if GF.UI and GF.UI.ClearSpecializationIcon then
				GF.UI.ClearSpecializationIcon(button.Icon)
			else
				button.Icon:Hide()
			end
			button:Hide()
		end
	end
	if count > 0 then
		local rowWidth =
			count * TalentLoadoutUI.SPEC_BUTTON_SIZE
				+ math.max(0, count - 1)
					* TalentLoadoutUI.SPEC_BUTTON_GAP
		row:SetWidth(rowWidth)
		row:Show()
		divider:Show()
	else
		row:SetWidth(0)
		row:Hide()
		divider:Hide()
	end
	TalentLoadoutUI.UpdateSpecializationTransition(card, snapshot)
end

function TalentLoadoutUI.SetupMenu(card)
	local dropdown = card and card.TalentDropdown
	if not (dropdown and dropdown.SetupMenu) then
		return
	end
	if dropdown.SetSelectionText then
		dropdown:SetSelectionText(function()
			local service = GF.MythicPlusTalentLoadoutService
			return TalentLoadoutUI.GetSelectionText(
				service and service:GetSnapshot()
			)
		end)
	end
	dropdown:SetupMenu(function(_, root)
		local locale = GF.L or {}
		local service = GF.MythicPlusTalentLoadoutService
		local snapshot = service and service:GetSnapshot()
		if root.SetTag then
			root:SetTag("MENU_GF_MYTHIC_PLUS_TALENT_LOADOUT")
		end
		if root.CreateTitle then
			root:CreateTitle(
				locale.MPLUS_TALENT_LOADOUT_MENU_TITLE
					or "选择天赋配置"
			)
		end
		local options = snapshot and snapshot.options or {}
		if #options == 0 then
			if root.CreateTitle then
				root:CreateTitle(
					snapshot and snapshot.state == "ready"
						and (
							locale.MPLUS_TALENT_LOADOUT_EMPTY
								or "暂无已保存的天赋配置"
						)
						or (
							locale.MPLUS_TALENT_LOADOUT_UNAVAILABLE
								or "天赋配置暂不可用"
						)
				)
			end
			return
		end
		for index, option in ipairs(options) do
			local configID = option.configID
			root:CreateRadio(
				TalentLoadoutUI.GetOptionText(option, index),
				function(candidate)
					local current = service and service:GetSnapshot()
					return current
						and current.starterBuildActive ~= true
						and current.selectedConfigID == candidate
						or false
				end,
				function(candidate)
					if service and service.SwitchToConfigID then
						service:SwitchToConfigID(candidate)
					end
				end,
				configID
			)
		end
	end)
end

function TalentLoadoutUI.UpdateDropdown(card)
	local dropdown = card and card.TalentDropdown
	if not dropdown then
		return
	end
	local service = GF.MythicPlusTalentLoadoutService
	local snapshot = service and service:GetSnapshot()
	if dropdown.SetEnabled then
		dropdown:SetEnabled(
			snapshot
				and snapshot.state == "ready"
				and snapshot.canSwitch == true
				or false
		)
	end
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(
			TalentLoadoutUI.GetSelectionText(snapshot)
		)
	end
	if dropdown.GenerateMenu then
		dropdown:GenerateMenu()
	end
	TalentLoadoutUI.FitDropdownText(dropdown)
end

local function createKeyButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(24)
	button.Backdrop = createRoundedInsetBackdrop(button)
	local text = createText(button, "GameFontHighlight", 11, "")
	text:SetPoint("LEFT", button, "LEFT", 8, 0)
	text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
	text:SetJustifyH("CENTER")
	button.Text = text
	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
	highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
	highlight:SetColorTexture(1, 1, 1, 0.06)
	UI.BindKeystoneLinkButton(button)
	return button
end

local function applyTeleportIconVisual(button, pressed)
	UI.ApplyTeleportIconVisual(
		button.Icon,
		button._teleportVisualState,
		{
			profile = "character",
			pressed = pressed == true,
			anchor = button.Backdrop or button,
		})
end

local function createTeleportButton(parent)
	local button = CreateFrame("Button", nil, parent, "InsecureActionButtonTemplate")
	button:SetSize(24, 24)
	button:RegisterForClicks("AnyUp", "AnyDown")
	button.Backdrop = createRoundedInsetBackdrop(button)
	local pushed = button:CreateTexture(nil, "HIGHLIGHT")
	pushed:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
	pushed:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
	pushed:SetColorTexture(1, 1, 1, 0.06)
	button:SetPushedTexture(pushed)
	local icon = button:CreateTexture(nil, "OVERLAY")
	GF.UI.TrySetAtlas(icon, GF.MYTHIC_PLUS_TELEPORT_ICON_ATLAS, false)
	button.Icon = icon
	button._teleportVisualState = "unavailable"
	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton"
			and self._visualReady
			and not UI.IsTeleportCombatLocked()
		then
			applyTeleportIconVisual(self, true)
		end
	end)
	button:SetScript("OnMouseUp", function(self)
		applyTeleportIconVisual(self, false)
	end)
	button:SetScript("OnLeave", function(self)
		applyTeleportIconVisual(self, false)
		GameTooltip_Hide()
	end)
	button:SetScript("OnEnter", function(self)
		if not self._teleportDungeon then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
			if GF.MythicPlusTeleportService then
				GF.MythicPlusTeleportService:AddTooltipLines(GameTooltip, self._teleportDungeon, {
					secureReady = self.gfTeleportSecureReady == true
						and self.gfTeleportSecurePending ~= true,
				})
			end
		GameTooltip:Show()
	end)
	UI.InstallTeleportCombatFeedback(button, function(teleportButton)
		teleportButton._visualReady =
			teleportButton.gfTeleportSecureReady == true
			and teleportButton.gfTeleportSecurePending ~= true
		applyTeleportIconVisual(teleportButton, false)
	end)
	applyTeleportIconVisual(button, false)
	return button
end

local function setTeleportVisual(button, data)
	local destination = data and (data.challengeModeID or data.mapID)
	local status = data and data.teleportStatus
	if GF.MythicPlusTeleportService then
		status = GF.MythicPlusTeleportService:GetStatus(destination)
		local secureReady, pending = GF.MythicPlusTeleportService:ApplySecureButton(button, destination)
		button._visualReady = secureReady == true
			and pending ~= true
			and status == "ready"
	else
		button._visualReady = status == "ready"
	end
	button._teleportDungeon = destination
	local visualState
	if not destination then
		visualState = "unavailable"
	elseif status == "ready"
		and (button._visualReady or UI.IsTeleportCombatLocked())
	then
		visualState = "ready"
	elseif status == "cooldown" then
		visualState = "cooldown"
	elseif status == "not_learned" then
		visualState = "not_learned"
	else
		visualState = "fallback"
	end
	button._teleportVisualState = visualState
	applyTeleportIconVisual(button, false)
end

local function getCardLeftInset(card)
	if card.isCurrent then
		return math.max(CONTROL_INSET_X, MODEL_TEXT_INSET_X - CONTENT_INSET_X)
	end
	return CONTROL_INSET_X
end

local function layoutRoleAtlas(card)
	local width = card:GetWidth() or CARD_MIN_WIDTH
	local extraWidth = math.floor((width * (ROLE_ATLAS_SCALE - 1)) / 2 + 0.5)
	card.RoleBackgroundClip:ClearAllPoints()
	card.RoleBackgroundClip:SetPoint(
		"TOPLEFT",
		card,
		"BOTTOMLEFT",
		0,
		ROLE_ATLAS_HEIGHT + ROLE_ATLAS_OFFSET_Y
	)
	card.RoleBackgroundClip:SetPoint(
		"TOPRIGHT",
		card,
		"BOTTOMRIGHT",
		0,
		ROLE_ATLAS_HEIGHT + ROLE_ATLAS_OFFSET_Y
	)
	card.RoleBackgroundClip:SetHeight(ROLE_ATLAS_VISIBLE_HEIGHT)

	card.RoleBackgroundArt:ClearAllPoints()
	card.RoleBackgroundArt:SetPoint(
		"TOPLEFT",
		card.RoleBackgroundClip,
		"TOPLEFT",
		-extraWidth,
		0
	)
	card.RoleBackgroundArt:SetPoint(
		"TOPRIGHT",
		card.RoleBackgroundClip,
		"TOPRIGHT",
		extraWidth,
		0
	)
	card.RoleBackgroundArt:SetHeight(ROLE_ATLAS_HEIGHT)

	if not GF.UI.TrySetAtlas(
			card.RoleBackground,
			ROLE_BAR_ATLAS,
			false
		)
	then
		local region = FRAME_TEXTURES.roleMask
		GF.UI.SetPixelTextureRegion(
			card.RoleBackground,
			FRAME_ATLAS_TEXTURE,
			{
				region[1],
				region[2] + ROLE_MASK_SKIP_TOP,
				region[3],
				region[4] - ROLE_MASK_SKIP_TOP,
			},
			FRAME_ATLAS_WIDTH,
			FRAME_ATLAS_HEIGHT
		)
	end
end

local function createCharacterCard(parent, isCurrent)
	local frameType = isCurrent and "Button" or "Frame"
	local template = isCurrent
		and "BackdropTemplate,InsecureActionButtonTemplate"
		or "BackdropTemplate"
	local card = CreateFrame(frameType, nil, parent, template)
	card:SetHeight(CARD_HEIGHT)
	card.isCurrent = isCurrent
	if isCurrent then
		card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		card:SetAttribute("useOnKeyDown", false)
		card:SetScript("PreClick", function(self, mouseButton)
			if GF.BlacklistMenu
				and GF.BlacklistMenu.BeginCurrentCharacterUnitMenu
			then
				GF.BlacklistMenu:BeginCurrentCharacterUnitMenu(
					self._gfData,
					self,
					mouseButton)
			end
		end)
		card:SetScript("PostClick", function()
			if GF.BlacklistMenu
				and GF.BlacklistMenu.EndCurrentCharacterUnitMenu
			then
				GF.BlacklistMenu:EndCurrentCharacterUnitMenu()
			end
		end)
		if card.SetClipsChildren then
			card:SetClipsChildren(false)
		end
	end
	card:EnableMouse(true)
	card:SetBackdrop(nil)
	applyCardChrome(card, isCurrent and "brown" or "dark")
	createRaisedHover(card, isCurrent)

	local topSection = CreateFrame("Frame", nil, card)
	topSection:SetPoint("TOPLEFT", card, "TOPLEFT", CONTENT_INSET_X, -CONTENT_INSET_TOP)
	topSection:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CONTENT_INSET_X, -CONTENT_INSET_TOP)
	topSection:SetHeight(TOP_SECTION_HEIGHT)
	card.TopSection = topSection

	local topBg = topSection:CreateTexture(nil, "BACKGROUND", nil, -1)
	topBg:SetAllPoints(topSection)
	topBg:SetColorTexture(0, 0, 0, 0)

	local leftInset = getCardLeftInset(card)
	local rightOffset = CONTENT_INSET_X - CONTROL_RIGHT_INSET
	local name = createText(topSection, "GameFontNormal", 13, "OUTLINE")
	name:SetPoint("TOPLEFT", topSection, "TOPLEFT", leftInset, TOP_LABEL_Y)
	name:SetJustifyH("LEFT")
	card.Name = name

	local armor = createText(topSection, "GameFontHighlight", 11, "")
	armor:SetPoint("TOPRIGHT", topSection, "TOPRIGHT", rightOffset, TOP_LABEL_Y)
	armor:SetWidth(120)
	armor:SetJustifyH("RIGHT")
	armor:SetTextColor(0.86, 0.86, 0.86, 0.92)
	card.Armor = armor

	local rating = createText(topSection, "GameFontHighlight", 13, "OUTLINE")
	rating:SetPoint("LEFT", name, "RIGHT", 6, 0)
	rating:SetPoint("RIGHT", armor, "LEFT", -8, 0)
	rating:SetJustifyH("LEFT")
	card.Rating = rating

	local teleport = createTeleportButton(topSection)
	teleport:SetPoint("BOTTOMRIGHT", topSection, "BOTTOMRIGHT", rightOffset + 2, INFO_ROW_Y)
	card.TeleportButton = teleport

	local keyButton = createKeyButton(topSection)
	keyButton:SetPoint("BOTTOMLEFT", topSection, "BOTTOMLEFT", leftInset, INFO_ROW_Y)
	keyButton:SetPoint("RIGHT", teleport, "LEFT", -10, 0)
	card.KeyButton = keyButton
	card.KeyText = keyButton.Text

	local roleSection = CreateFrame("Frame", nil, card)
	roleSection:SetPoint("LEFT", card, "LEFT")
	roleSection:SetPoint("RIGHT", card, "RIGHT")
	roleSection:SetPoint("BOTTOM", card, "BOTTOM", 0, ROLE_SECTION_OFFSET_Y)
	roleSection:SetHeight(ROLE_SECTION_HEIGHT)
	roleSection:SetFrameLevel((card:GetFrameLevel() or 0) + 3)
	card.RoleSection = roleSection

	local roleBackgroundClip = CreateFrame("Frame", nil, card)
	roleBackgroundClip:SetFrameLevel((card:GetFrameLevel() or 0) + 1)
	roleBackgroundClip:SetClipsChildren(true)
	card.RoleBackgroundClip = roleBackgroundClip

	local roleBackgroundArt = CreateFrame("Frame", nil, roleBackgroundClip)
	roleBackgroundArt:SetFrameLevel((card:GetFrameLevel() or 0) + 2)
	card.RoleBackgroundArt = roleBackgroundArt

	local roleBg = roleBackgroundArt:CreateTexture(nil, "BACKGROUND", nil, -1)
	roleBg:SetAllPoints(roleBackgroundArt)
	card.RoleBackground = roleBg

	local rowOffsetY = ROLE_CONTENT_OFFSET_Y
	local bottomLeftInset = CONTENT_INSET_X + leftInset
	if isCurrent then
		local prompt = createText(roleSection, "GameFontHighlight", 12, "")
		prompt:SetPoint(
			"LEFT",
			roleSection,
			"LEFT",
			bottomLeftInset,
			rowOffsetY + TalentLoadoutUI.VISIBLE_CENTER_OFFSET_Y
		)
		prompt:SetSize(ROLE_LABEL_WIDTH, 20)
		prompt:SetJustifyH("LEFT")
		prompt:SetTextColor(1, 1, 1, 0.96)
		card.RolePrompt = prompt
	else
		local carpool = createCharacterCheckButton(
			roleSection,
			"",
			142,
			ROLE_CARPOOL_CHECK_OFFSET_Y
		)
		carpool:SetPoint("LEFT", roleSection, "LEFT", bottomLeftInset, rowOffsetY)
		carpool:SetScript("OnClick", function(self)
			local data = card._gfData
			if data and data.isDebugTest and GF.MythicPlusDebugService
				and GF.MythicPlusDebugService.SetLocalCarpoolEnabled then
				local enabled = self:GetChecked() == true
				if GF.MythicPlusDebugService:SetLocalCarpoolEnabled(data.key, enabled) then
					self._cachedChecked = enabled
					return
				end
			elseif data and data.key and GF.MythicPlusCharacterStore
				and GF.MythicPlusCharacterStore.SetCarpoolEnabled then
				local enabled = self:GetChecked() == true
				if GF.MythicPlusCharacterStore:SetCarpoolEnabled(data.key, enabled) then
					self._cachedChecked = enabled
					return
				end
			end
			self:SetChecked(self._cachedChecked == true)
		end)
		card.CarpoolCheck = carpool
	end

	if isCurrent then
		local dropdown = GF.UI.CreateDropdownButton(roleSection)
		dropdown:SetPoint(
			"RIGHT",
			roleSection,
			"RIGHT",
			-ROLE_RIGHT_INSET + TalentLoadoutUI.RIGHT_EDGE_OFFSET_X,
			rowOffsetY + TalentLoadoutUI.VISIBLE_CENTER_OFFSET_Y
		)
		dropdown:SetSize(
			TalentLoadoutUI.DROPDOWN_WIDTH,
			TalentLoadoutUI.DROPDOWN_HEIGHT
		)
		card.TalentDropdown = dropdown
		TalentLoadoutUI.SetupMenu(card)
		TalentLoadoutUI.CreateSpecializationButtons(
			card,
			roleSection,
			dropdown
		)
	else
		local rolesAnchor = CreateFrame("Frame", nil, roleSection)
		rolesAnchor:SetPoint(
			"RIGHT",
			roleSection,
			"RIGHT",
			-ROLE_RIGHT_INSET,
			rowOffsetY + ROLE_TOGGLE_GROUP_OFFSET_Y
		)
		rolesAnchor:SetSize((ROLE_TOGGLE_WIDTH * 3) + (ROLE_TOGGLE_GAP * 2) + ROLE_ICON_OVERFLOW,
			ROLE_TOGGLE_HEIGHT)
		card.RoleToggles = {}
		local previous
		for _, roleKey in ipairs(ROLE_ORDER) do
			local toggle = createRoleCheckButton(roleSection, roleKey)
			toggle.OwnerCard = card
			if previous then
				toggle:SetPoint("LEFT", previous, "RIGHT", ROLE_TOGGLE_GAP, 0)
			else
				toggle:SetPoint("LEFT", rolesAnchor, "LEFT")
			end
			card.RoleToggles[roleKey] = toggle
			previous = toggle
		end
	end

	if isCurrent then
		local model = CreateFrame("PlayerModel", nil, card)
		model:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", MODEL_LEFT_INSET, MODEL_BOTTOM_INSET)
		model:SetSize(MODEL_WIDTH, MODEL_HEIGHT)
		model:EnableMouse(false)
		model:SetScript("OnShow", configurePlayerModel)
		card.PlayerModel = model
	end
	card:HookScript("OnSizeChanged", layoutRoleAtlas)
	layoutRoleAtlas(card)
	return card
end

local function getSelectedRoles(data)
	local selected = {}
	if type(data and data.roles) == "table" then
		for _, roleKey in ipairs(ROLE_ORDER) do
			selected[roleKey] = data.roles[roleKey] == true
		end
	else
		local roleKey = ServiceUtil.NormalizeRole(data and data.role)
		if roleKey then
			selected[roleKey] = true
		end
	end
	return selected
end

local function getKeystoneText(data)
	if data.keystoneLink then
		return data.keystoneLink
	end
	local level = tonumber(data.keyLevel)
	if not level or level <= 0 then
		return (GF.L and GF.L.MPLUS_NO_KEYSTONE) or "无钥石"
	end
	return UI.FormatKey(data)
end

local function bindCharacterCard(card, data)
	data = data or {}
	card._gfData = data
	local classFile = data.classFile or data.class
	local r, g, b = UI.GetClassColor(classFile)
	applyCardChrome(card, card.isCurrent and "brown" or "class", classFile)
	if card.isCurrent and card._gfMythicCharacterHover then
		setLayerColor(card._gfMythicCharacterHover.base, 1, 1, 1, 1)
		setLayerColor(card._gfMythicCharacterHover.glow, 1, 1, 1, 1)
	else
		tintRaisedHover(card, classFile)
	end
	card.Name:SetText(UI.GetCharacterFullName(data))
	card.Name:SetTextColor(r, g, b, 1)

	local score = tonumber(data.rating)
	if score and score > 0 then
		score = math.floor(score + 0.5)
		card.Rating:SetText(string.format("（%d）", score))
		local color = data.ratingColor
			or (GF.MythicPlusRatingCache and GF.MythicPlusRatingCache:GetCachedScoreColor(score))
		if not color and GF.Result and GF.Result.GetDungeonScoreColor then
			color = GF.Result:GetDungeonScoreColor(score)
		end
		if color then
			card.Rating:SetTextColor(color.r, color.g, color.b, 1)
		else
			card.Rating:SetTextColor(1, 1, 1, 0.95)
		end
		card.Rating:Show()
	else
		card.Rating:SetText("")
		card.Rating:Hide()
	end
	card.Armor:SetText(UI.GetArmorLabel(classFile))
	card.KeyText:SetText(getKeystoneText(data))
	if tonumber(data.keyLevel) and tonumber(data.keyLevel) > 0 then
		card.KeyText:SetTextColor(r, g, b, 1)
	else
		card.KeyText:SetTextColor(0.52, 0.52, 0.52, 1)
	end
	card.KeyButton.keystoneLink = data.keystoneLink
	setTeleportVisual(card.TeleportButton, data)

	if card.RolePrompt then
		card.RolePrompt:SetText(
			(GF.L and GF.L.MPLUS_SPECIALIZATION_LOADOUT)
				or "专精天赋"
		)
	end
	if card.CarpoolCheck then
		card.CarpoolCheck.Label:SetText((GF.L and GF.L.MPLUS_CARPOOL_ADD) or "加入车队列表")
		card.CarpoolCheck._cachedChecked = data.carpoolEnabled == true
		card.CarpoolCheck:SetChecked(card.CarpoolCheck._cachedChecked)
	end

	if card.TalentDropdown then
		TalentLoadoutUI.UpdateSpecializations(card)
		TalentLoadoutUI.UpdateDropdown(card)
	else
		local selected = getSelectedRoles(data)
		local available = CLASS_ROLE_AVAILABILITY[classFile]
		for _, roleKey in ipairs(ROLE_ORDER) do
			local toggle = card.RoleToggles[roleKey]
			toggle:SetAvailable(not available or available[roleKey] == true)
			toggle._cachedChecked = toggle._available and selected[roleKey] == true
			toggle:SetChecked(toggle._cachedChecked)
		end
	end
end

local function getVaultRewardLabel(level)
	level = math.min(math.max(tonumber(level) or 0, 0), 10)
	if level >= 10 then
		return (GF.L and GF.L.MPLUS_REWARD_MYTH) or "神话"
	end
	if level >= 3 then
		return (GF.L and GF.L.MPLUS_REWARD_HERO) or "英雄"
	end
	if level >= 2 then
		return (GF.L and GF.L.MPLUS_REWARD_CHAMPION) or "勇士"
	end
	return nil
end

local function getVaultRewardColor(level)
	level = math.min(math.max(tonumber(level) or 0, 0), 10)
	if level >= 10 then
		return WEEKLY_REWARD_COLORS.myth
	end
	if level >= 3 then
		return WEEKLY_REWARD_COLORS.hero
	end
	if level >= 2 then
		return WEEKLY_REWARD_COLORS.champion
	end
	return WEEKLY_REWARD_COLORS.accent
end

local function getVaultThresholdLabel(threshold)
	threshold = tonumber(threshold) or 0
	if threshold == 1 then
		return (GF.L and GF.L.MPLUS_VAULT_FIRST) or "初级奖励"
	end
	if threshold == 4 then
		return (GF.L and GF.L.MPLUS_VAULT_FOUR) or "四本奖励"
	end
	if threshold == 8 then
		return (GF.L and GF.L.MPLUS_VAULT_EIGHT) or "八本奖励"
	end
	return string.format((GF.L and GF.L.MPLUS_VAULT_COUNT) or "%d 本奖励", threshold)
end

local function formatWeeklyRunLevel(run)
	if type(run) ~= "table" then
		return UI.ColorText("-", WEEKLY_REWARD_COLORS.muted)
	end
	return UI.ColorText("+" .. tostring(tonumber(run.level) or 0),
		run.timed == true and "ff00ff00" or "ffff4040")
end

local function formatWeeklyTooltipReward(run)
	if type(run) ~= "table" then
		return UI.ColorText((GF.L and GF.L.MPLUS_INCOMPLETE) or "未完成",
			WEEKLY_REWARD_COLORS.muted)
	end
	local rewardLabel = getVaultRewardLabel(run.level)
	if not rewardLabel then
		return string.format("%s  %s",
			formatWeeklyRunLevel(run),
			UI.ColorText((GF.L and GF.L.MPLUS_INCOMPLETE) or "未完成",
				WEEKLY_REWARD_COLORS.muted))
	end
	return string.format("%s  %s",
		formatWeeklyRunLevel(run),
		UI.ColorText(rewardLabel, getVaultRewardColor(run.level)))
end

local function formatVaultReward(reward)
	local level = reward and reward.run and tonumber(reward.run.level)
	local rewardLabel
	local rewardColor
	rewardLabel = getVaultRewardLabel(level)
	rewardColor = rewardLabel and getVaultRewardColor(level) or nil
	local icon = rewardLabel and "|A:UI-LFG-ReadyMark:12:12|a"
		or "|A:UI-LFG-DeclineMark:12:12|a"
	local threshold = tonumber(reward and reward.threshold) or 0
	local label = getVaultThresholdLabel(threshold)
	local stateText = rewardLabel
		or ((GF.L and GF.L.MPLUS_INCOMPLETE) or "未完成")
	local stateColor = rewardColor or WEEKLY_REWARD_COLORS.muted
	return string.format("%s |c%s%s：|r|c%s%s|r",
		icon, WEEKLY_REWARD_COLORS.accent, label, stateColor, stateText)
end

local function formatWeeklyRuns(snapshot)
	local parts = {}
	for index, run in ipairs(snapshot and snapshot.runs or {}) do
		if index > 8 then
			break
		end
		parts[#parts + 1] = string.format("|c%s+%d|r",
			run.timed and "ff00ff00" or "ffff4040", tonumber(run.level) or 0)
	end
	if #parts == 0 then
		return "|cff8a8a8a" .. ((GF.L and GF.L.MPLUS_WEEKLY_NONE) or "本周暂无大秘境记录。") .. "|r"
	end
	return table.concat(parts, "  ")
end

local function createWeeklyCard(parent)
	local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
	card:SetHeight(CARD_HEIGHT)
	card:EnableMouse(true)
	card:SetBackdrop(nil)
	applyCardChrome(card, "brown")

	local title = createText(card, "GameFontNormal", 13, "OUTLINE")
	title:SetPoint("TOPLEFT", card, "TOPLEFT", WEEKLY_CONTENT_INSET_X, WEEKLY_TITLE_Y)
	title:SetPoint("TOPRIGHT", card, "TOPRIGHT",
		-(WEEKLY_CONTENT_INSET_X + WEEKLY_COUNT_WIDTH + 12), WEEKLY_TITLE_Y)
	title:SetJustifyH("LEFT")
	title:SetTextColor(1, 0.82, 0, 1)
	card.Title = title

	local count = createText(card, "GameFontHighlight", 11, "")
	count:SetPoint("TOPRIGHT", card, "TOPRIGHT", -WEEKLY_CONTENT_INSET_X, WEEKLY_COUNT_Y)
	count:SetSize(WEEKLY_COUNT_WIDTH, 18)
	count:SetJustifyH("RIGHT")
	count:SetJustifyV("TOP")
	count:SetTextColor(1, 1, 1, 0.92)
	card.Count = count

	local divider = CreateFrame("Frame", nil, card)
	divider:SetPoint("LEFT", card, "TOPLEFT", WEEKLY_CONTENT_INSET_X, WEEKLY_DIVIDER_Y)
	divider:SetPoint("RIGHT", card, "TOPRIGHT", -WEEKLY_CONTENT_INSET_X, WEEKLY_DIVIDER_Y)
	divider:SetHeight(WEEKLY_DIVIDER_HEIGHT)
	divider:SetFrameLevel((card:GetFrameLevel() or 0) + 1)
	local left = divider:CreateTexture(nil, "ARTWORK", nil, 1)
	left:SetPoint("LEFT", divider, "LEFT")
	left:SetPoint("RIGHT", divider, "CENTER")
	left:SetHeight(WEEKLY_DIVIDER_HEIGHT)
	applyHorizontalGradient(left, 1, 0.82, 0, 0, 1, 0.82, 0, 0.78)
	local right = divider:CreateTexture(nil, "ARTWORK", nil, 1)
	right:SetPoint("LEFT", divider, "CENTER")
	right:SetPoint("RIGHT", divider, "RIGHT")
	right:SetHeight(WEEKLY_DIVIDER_HEIGHT)
	applyHorizontalGradient(right, 1, 0.82, 0, 0.78, 1, 0.82, 0, 0)

	local vault = createText(card, "GameFontHighlightSmall", 12, "")
	vault:SetPoint("TOPLEFT", card, "TOPLEFT", WEEKLY_CONTENT_INSET_X, WEEKLY_VAULT_Y)
	vault:SetPoint("TOPRIGHT", card, "TOPRIGHT", -WEEKLY_CONTENT_INSET_X, WEEKLY_VAULT_Y)
	vault:SetHeight(WEEKLY_BODY_HEIGHT)
	vault:SetJustifyH("LEFT")
	vault:SetJustifyV("MIDDLE")
	vault:SetWordWrap(false)
	vault:SetTextColor(1, 1, 1, 0.95)
	card.Vault = vault

	local runs = createText(card, "GameFontHighlightSmall", 12, "")
	runs:SetPoint("TOPLEFT", card, "TOPLEFT", WEEKLY_CONTENT_INSET_X, WEEKLY_RUNS_Y)
	runs:SetPoint("TOPRIGHT", card, "TOPRIGHT", -WEEKLY_CONTENT_INSET_X, WEEKLY_RUNS_Y)
	runs:SetHeight(WEEKLY_BODY_HEIGHT)
	runs:SetJustifyH("LEFT")
	runs:SetJustifyV("MIDDLE")
	runs:SetWordWrap(false)
	runs:SetTextColor(1, 1, 1, 0.95)
	card.Runs = runs
	card:SetScript("OnEnter", function(self)
		local snapshot = self.Snapshot
		if GameTooltip.SetMinimumWidth then
			GameTooltip:SetMinimumWidth(0, false)
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine((GF.L and GF.L.MPLUS_WEEKLY_REPORT) or "大秘境周报", 1, 0.82, 0)
		if not snapshot or snapshot.state ~= "ready" then
			GameTooltip:AddLine((GF.L and GF.L.MPLUS_WEEKLY_UNAVAILABLE)
				or "无法读取本周大秘境记录。", 0.70, 0.70, 0.70, true)
			GameTooltip:Show()
			return
		end
		local completedRuns = tonumber(snapshot.completedRuns) or #(snapshot.runs or {})
		if completedRuns <= 0 then
			GameTooltip:AddLine((GF.L and GF.L.MPLUS_WEEKLY_NONE)
				or "本周暂无大秘境记录。", 0.70, 0.70, 0.70, true)
			GameTooltip:Show()
			return
		end
		GameTooltip:AddDoubleLine(
			(GF.L and GF.L.MPLUS_WEEKLY_TOTAL) or "本周大秘境次数",
			tostring(completedRuns),
			0.82, 0.82, 0.82, 1, 1, 1)

		GameTooltip:AddLine(" ")
		GameTooltip:AddLine((GF.L and GF.L.MPLUS_GREAT_VAULT) or "宏伟宝库", 1, 0.82, 0)
		for _, reward in ipairs(snapshot.rewards or {}) do
			local threshold = tonumber(reward.threshold) or 0
			local progress = math.min(completedRuns, threshold)
			GameTooltip:AddDoubleLine(
				string.format("%s (%d/%d)",
					getVaultThresholdLabel(threshold), progress, threshold),
				formatWeeklyTooltipReward(reward.run),
				0.82, 0.82, 0.82,
				1, 1, 1)
		end
		if #(snapshot.runs or {}) > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine((GF.L and GF.L.MPLUS_COMPLETED_DUNGEONS)
				or "通关地下城", 1, 0.82, 0)
			local grouped = {}
			for _, run in ipairs(snapshot.runs) do
				local mapID = tonumber(run.mapID)
				if mapID and not grouped[mapID] then
					local dungeon = GF.MythicPlusSeason
						and GF.MythicPlusSeason:GetByChallengeModeID(mapID)
					grouped[mapID] = {
						name = dungeon and dungeon.name or tostring(mapID),
						runs = {},
					}
				end
				if mapID then
					grouped[mapID].runs[#grouped[mapID].runs + 1] = run
				end
			end
			local dungeonGroups = {}
			for _, group in pairs(grouped) do
				table.sort(group.runs, function(leftRun, rightRun)
					local leftLevel = tonumber(leftRun and leftRun.level) or 0
					local rightLevel = tonumber(rightRun and rightRun.level) or 0
					if leftLevel ~= rightLevel then
						return leftLevel > rightLevel
					end
					return leftRun.timed == true and rightRun.timed ~= true
				end)
				dungeonGroups[#dungeonGroups + 1] = group
			end
			table.sort(dungeonGroups, function(leftGroup, rightGroup)
				return (leftGroup.name or "") < (rightGroup.name or "")
			end)
			for _, group in ipairs(dungeonGroups) do
				local levels = {}
				for _, run in ipairs(group.runs) do
					levels[#levels + 1] = formatWeeklyRunLevel(run)
				end
				GameTooltip:AddDoubleLine(
					string.format("%s (%d)", group.name, #group.runs),
					table.concat(levels, " "),
					0.92, 0.92, 0.92,
					1, 1, 1)
			end
		end
		GameTooltip:Show()
	end)
	card:SetScript("OnLeave", GameTooltip_Hide)
	createRaisedHover(card, false)
	return card
end

local function bindWeeklyCard(card)
	local snapshot = GF.MythicPlusWeeklyCache and GF.MythicPlusWeeklyCache:GetSnapshot()
	card.Snapshot = snapshot
	card.Title:SetText((GF.L and GF.L.MPLUS_WEEKLY_REPORT) or "大秘境周报")
	if not snapshot or snapshot.state ~= "ready" then
		card.Count:SetText((GF.L and GF.L.MPLUS_WEEKLY_UNAVAILABLE_SHORT) or "数据不可用")
		card.Vault:SetText(string.format("%s  -",
			(GF.L and GF.L.MPLUS_GREAT_VAULT) or "宏伟宝库"))
		card.Runs:SetText(string.format("%s  %s",
			(GF.L and GF.L.MPLUS_RUN_HISTORY) or "通关记录",
			(GF.L and GF.L.MPLUS_WEEKLY_UNAVAILABLE_SHORT) or "数据不可用"))
		return
	else
		card.Count:SetText(string.format((GF.L and GF.L.MPLUS_WEEKLY_COMPLETED) or "本周通关 %d 次",
			tonumber(snapshot.completedRuns) or 0))
	end
	local rewards = {}
	for _, reward in ipairs(snapshot and snapshot.rewards or {}) do
		rewards[#rewards + 1] = formatVaultReward(reward)
	end
	card.Vault:SetText(string.format("%s  %s",
		(GF.L and GF.L.MPLUS_GREAT_VAULT) or "宏伟宝库",
		#rewards > 0 and table.concat(rewards, "  ") or "-"))
	card.Runs:SetText(string.format("%s  %s",
		(GF.L and GF.L.MPLUS_RUN_HISTORY) or "通关记录",
		formatWeeklyRuns(snapshot)))
end

local function getWarbandCharacters()
	local result = {}
	local currentKey = GF.MythicPlusCharacterStore and GF.MythicPlusCharacterStore:GetCurrentKey()
	for _, character in ipairs(GF.MythicPlusCharacterStore and GF.MythicPlusCharacterStore:GetCharacters() or {}) do
		if character.key ~= currentKey then
			result[#result + 1] = character
		end
	end
	return result
end

local function formatRunDuration(milliseconds)
	local totalSeconds = math.floor(((tonumber(milliseconds) or 0) / 1000) + 0.5)
	if totalSeconds <= 0 then
		return "-"
	end
	return string.format("%d:%02d", math.floor(totalSeconds / 60), totalSeconds % 60)
end

local function applyBestRunsImageTexCoords(image, texCoords)
	if not image then
		return
	end
	if type(texCoords) == "table" and #texCoords == 4 then
		image:SetTexCoord(texCoords[1], texCoords[2], texCoords[3], texCoords[4])
	else
		image:SetTexCoord(0, 1, 0, 1)
	end
end

local function playBestRunsPanelSound(soundType)
	if not (PlaySound and SOUNDKIT) then
		return
	end
	local soundID = soundType == "open"
		and SOUNDKIT.IG_SPELLBOOK_OPEN
		or SOUNDKIT.IG_ABILITY_CLOSE
	if soundID then
		PlaySound(soundID)
	end
end

local function applyBestRunsPanelBackplate(panel)
	panel:SetBackdrop(nil)
	if not panel.Background then
		panel.Background = panel:CreateTexture(nil, "BACKGROUND", nil, -4)
		panel.DarkOverlay = panel:CreateTexture(nil, "BACKGROUND", nil, -3)
		panel.TopGradient = panel:CreateTexture(nil, "BACKGROUND", nil, -2)
		panel.TopGradient:SetHeight(92)
		panel.BottomGradient = panel:CreateTexture(nil, "BACKGROUND", nil, -2)
		panel.BottomGradient:SetHeight(92)

		local borderFrame = CreateFrame("Frame", nil, panel)
		borderFrame:SetPoint("TOPLEFT", panel, "TOPLEFT",
			-BEST_RUNS_PANEL_BORDER_INSET_X, 12)
		borderFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT",
			BEST_RUNS_PANEL_BORDER_INSET_X, -6)
		borderFrame:EnableMouse(false)
		panel.BorderFrame = borderFrame
		panel.Border = borderFrame:CreateTexture(nil, "ARTWORK")
		panel.Border:SetAllPoints(borderFrame)
	end

	panel.Background:ClearAllPoints()
	panel.Background:SetPoint("TOPLEFT", panel, "TOPLEFT",
		BEST_RUNS_PANEL_BACKGROUND_INSET, -BEST_RUNS_PANEL_BACKGROUND_INSET)
	panel.Background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT",
		-BEST_RUNS_PANEL_BACKGROUND_INSET, BEST_RUNS_PANEL_BACKGROUND_BOTTOM_INSET)
	panel.Background:SetDrawLayer("BACKGROUND", -4)
	panel.DarkOverlay:ClearAllPoints()
	panel.DarkOverlay:SetAllPoints(panel.Background)
	panel.DarkOverlay:SetDrawLayer("BACKGROUND", -1)
	panel.TopGradient:ClearAllPoints()
	panel.TopGradient:SetPoint("TOPLEFT", panel, "TOPLEFT",
		BEST_RUNS_PANEL_BACKGROUND_INSET, -BEST_RUNS_PANEL_BACKGROUND_INSET)
	panel.TopGradient:SetPoint("TOPRIGHT", panel, "TOPRIGHT",
		-BEST_RUNS_PANEL_BACKGROUND_INSET, -BEST_RUNS_PANEL_BACKGROUND_INSET)
	panel.TopGradient:SetDrawLayer("BACKGROUND", -2)
	panel.BottomGradient:ClearAllPoints()
	panel.BottomGradient:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT",
		BEST_RUNS_PANEL_BACKGROUND_INSET, BEST_RUNS_PANEL_BACKGROUND_BOTTOM_INSET)
	panel.BottomGradient:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT",
		-BEST_RUNS_PANEL_BACKGROUND_INSET, BEST_RUNS_PANEL_BACKGROUND_BOTTOM_INSET)
	panel.BottomGradient:SetDrawLayer("BACKGROUND", -2)
	panel.BorderFrame:SetFrameLevel((panel:GetFrameLevel() or 0) + 12)

	if not GF.UI.TrySetAtlas(panel.Background, "transmog-outfit-darkbg", false) then
		panel.Background:SetTexture(GF.WHITE_TEXTURE)
		panel.Background:SetVertexColor(0.02, 0.018, 0.014, 0.96)
	else
		panel.Background:SetVertexColor(1, 1, 1, 1)
	end
	applyVerticalBlackMask(panel.DarkOverlay, 0.20, 0.74)
	GF.UI.TrySetAtlas(panel.TopGradient, "transmog-outfit-toptexture", false)
	panel.TopGradient:SetVertexColor(1, 1, 1, 1)
	GF.UI.TrySetAtlas(panel.BottomGradient, "transmog-outfit-bottomtexture", false)
	panel.BottomGradient:SetVertexColor(1, 1, 1, 1)
	GF.UI.TrySetAtlas(panel.Border, "transmog-tabs-frame", false)
	panel.Border:SetVertexColor(1, 1, 1, 1)
end

local function createBestRunRow(parent)
	local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	row:SetHeight(BEST_RUNS_ROW_HEIGHT)
	row:SetBackdrop({
		bgFile = GF.WHITE_TEXTURE,
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	row:SetBackdropColor(0.015, 0.015, 0.015, 0.88)
	row:SetBackdropBorderColor(1, 1, 1, 0.18)

	local image = row:CreateTexture(nil, "ARTWORK", nil, -1)
	image:SetPoint("TOPLEFT", row, "TOPLEFT",
		BEST_RUNS_ROW_IMAGE_INSET, -BEST_RUNS_ROW_IMAGE_INSET)
	image:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT",
		BEST_RUNS_ROW_IMAGE_INSET, BEST_RUNS_ROW_IMAGE_INSET)
	image:SetWidth(BEST_RUNS_ROW_IMAGE_WIDTH - BEST_RUNS_ROW_IMAGE_INSET)
	image:SetVertexColor(1, 1, 1, 0.70)
	row.Image = image

	local imageShade = createSolidTexture(row, "ARTWORK", 0)
	imageShade:SetAllPoints(image)
	imageShade:SetVertexColor(0, 0, 0, 0.28)
	local imageFade = createSolidTexture(row, "ARTWORK", 1)
	imageFade:SetAllPoints(image)
	applyHorizontalGradient(imageFade, 0, 0, 0, 0.10, 0, 0, 0, 0.86)

	local topLine = createSolidTexture(row, "OVERLAY", 1)
	topLine:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -1)
	topLine:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -1)
	topLine:SetHeight(1)
	topLine:SetVertexColor(1, 1, 1, 0.12)
	local bottomLine = createSolidTexture(row, "OVERLAY", 1)
	bottomLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 1)
	bottomLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 1)
	bottomLine:SetHeight(1)
	bottomLine:SetVertexColor(1, 1, 1, 0.12)

	local dungeonName = createText(row, "GameFontHighlight", 15, "OUTLINE")
	dungeonName:SetPoint("LEFT", row, "LEFT", BEST_RUNS_ROW_INSET_X, 0)
	dungeonName:SetWidth(BEST_RUNS_ROW_IMAGE_WIDTH - (BEST_RUNS_ROW_INSET_X * 2))
	dungeonName:SetJustifyH("LEFT")
	dungeonName:SetTextColor(1, 1, 1, 0.98)
	row.DungeonName = dungeonName

	local timeLabel = createText(row, "GameFontHighlightLarge", 18, "")
	timeLabel:SetPoint("LEFT", row, "LEFT", BEST_RUNS_TIME_COLUMN_X, 0)
	timeLabel:SetWidth(88)
	timeLabel:SetJustifyH("CENTER")
	timeLabel:SetTextColor(1, 1, 1, 0.96)
	row.Time = timeLabel

	local levelLabel = createText(row, "GameFontHighlightLarge", 28, "")
	levelLabel:SetPoint("LEFT", row, "LEFT", BEST_RUNS_LEVEL_COLUMN_X, 0)
	levelLabel:SetWidth(92)
	levelLabel:SetJustifyH("CENTER")
	levelLabel:SetTextColor(1, 1, 1, 0.98)
	row.Level = levelLabel

	local scoreLabel = createText(row, "GameFontHighlightLarge", 26, "")
	scoreLabel:SetPoint("RIGHT", row, "RIGHT", -BEST_RUNS_SCORE_COLUMN_RIGHT, 0)
	scoreLabel:SetWidth(120)
	scoreLabel:SetJustifyH("RIGHT")
	scoreLabel:SetTextColor(0.98, 0.82, 0.38, 1)
	row.Score = scoreLabel
	return row
end

local function setBestRunsPanelMainWindowHidden(panel, hidden)
	local mainFrame = GF.UI and GF.UI.GetMainFrame and GF.UI.GetMainFrame()
	if mainFrame and mainFrame.SetAlpha then
		if hidden then
			if panel.PreviousMainAlpha == nil then
				panel.PreviousMainAlpha = mainFrame.GetAlpha and mainFrame:GetAlpha() or 1
			end
			mainFrame:SetAlpha(BEST_RUNS_MAIN_WINDOW_ALPHA)
		elseif panel.PreviousMainAlpha ~= nil then
			mainFrame:SetAlpha(tonumber(panel.PreviousMainAlpha) or 1)
			panel.PreviousMainAlpha = nil
		end
	end

	local model = panel.OwnerCard and panel.OwnerCard.PlayerModel
	if not (model and model.SetAlpha) then
		return
	end
	if hidden then
		if panel.PreviousModelAlpha == nil then
			panel.PreviousModelAlpha = model.GetAlpha and model:GetAlpha() or 1
			panel.ModelWasShown = model.IsShown and model:IsShown() or false
		end
		model:SetAlpha(0)
		model:Hide()
	elseif panel.PreviousModelAlpha ~= nil then
		model:SetAlpha(tonumber(panel.PreviousModelAlpha) or 1)
		if panel.ModelWasShown then
			model:Show()
		else
			model:Hide()
		end
		panel.PreviousModelAlpha = nil
		panel.ModelWasShown = nil
	end
end

local function getBestRunsSource(data)
	local ratingEntry = GF.MythicPlusRatingCache
		and GF.MythicPlusRatingCache.GetCurrent
		and GF.MythicPlusRatingCache:GetCurrent()
	local bestRuns
	if ratingEntry and ratingEntry.state == "ready"
		and type(ratingEntry.runs) == "table"
	then
		bestRuns = ratingEntry.runs
	else
		bestRuns = data and data.bestRuns or {}
	end
	if type(bestRuns) == "table" and type(bestRuns.runs) == "table" then
		bestRuns = bestRuns.runs
	end
	return type(bestRuns) == "table" and bestRuns or {}, ratingEntry
end

local function buildBestRunsRows(data)
	local bestRuns, ratingEntry = getBestRunsSource(data)
	local runsByMapID = {}
	for _, run in ipairs(bestRuns) do
		local mapID = tonumber(run and (run.mapID
			or run.challengeModeID
			or run.mapChallengeModeID))
		if mapID then
			runsByMapID[mapID] = run
		end
	end

	local rows = {}
	local dungeons = GF.MythicPlusSeason
		and GF.MythicPlusSeason.GetDungeons
		and GF.MythicPlusSeason:GetDungeons() or {}
	for sourceOrder, dungeon in ipairs(dungeons) do
		local mapID = tonumber(dungeon and dungeon.challengeModeID)
		local run = mapID and runsByMapID[mapID] or nil
		rows[#rows + 1] = {
			mapID = mapID,
			dungeon = dungeon,
			run = run,
			bestRun = run,
			sourceOrder = sourceOrder,
		}
	end
	local sorter = GF.MythicPlusSeasonDungeonSort
	if sorter and sorter.Sort then
		rows = sorter:Sort(rows)
	end
	return rows, ratingEntry, #dungeons > 0
end

local function createBestRunsPanel(ownerCard)
	local panel = CreateFrame("Frame", "GroupFinderAddonCurrentCharacterBestRunsPanel",
		UIParent, "BackdropTemplate")
	panel:SetSize(BEST_RUNS_PANEL_WIDTH, 140)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(200)
	if panel.SetToplevel then
		panel:SetToplevel(true)
	end
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	panel.OwnerCard = ownerCard
	panel:Hide()
	panel:SetScript("OnShow", function(self)
		setBestRunsPanelMainWindowHidden(self, true)
		playBestRunsPanelSound("open")
	end)
	panel:SetScript("OnHide", function(self)
		setBestRunsPanelMainWindowHidden(self, false)
		playBestRunsPanelSound("close")
	end)
	if GF.GetPanelScale and panel.SetScale then
		panel:SetScale(GF.GetPanelScale())
	end
	applyBestRunsPanelBackplate(panel)

	local title = createText(panel, "GameFontNormalLarge", 16, "OUTLINE")
	title:SetPoint("TOP", panel, "TOP", 0, -16)
	title:SetJustifyH("CENTER")
	title:SetTextColor(1, 0.82, 0, 1)
	panel.Title = title

	local name = createText(panel, "GameFontHighlight", 13, "OUTLINE")
	name:SetPoint("TOPLEFT", panel, "TOPLEFT", BEST_RUNS_ROW_INSET_X, -39)
	name:SetWidth(360)
	name:SetJustifyH("LEFT")
	panel.Name = name

	local overallScore = createText(panel, "GameFontHighlight", 13, "OUTLINE")
	overallScore:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -BEST_RUNS_ROW_INSET_X, -39)
	overallScore:SetWidth(260)
	overallScore:SetJustifyH("RIGHT")
	panel.OverallScore = overallScore

	local rowsContainer = CreateFrame("Frame", nil, panel)
	rowsContainer:SetPoint("TOPLEFT", panel, "TOPLEFT",
		BEST_RUNS_ROW_INSET_X, -BEST_RUNS_PANEL_HEADER_HEIGHT)
	panel.RowsContainer = rowsContainer

	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
	close:SetFrameLevel((panel:GetFrameLevel() or 0) + 20)
	if GF.UI.ApplyCommonCloseButtonSkin then
		GF.UI.ApplyCommonCloseButtonSkin(close)
	end
	close:SetScript("OnClick", function()
		panel:Hide()
	end)
	panel.Close = close

	panel.Rows = {}

	local empty = createText(panel, "GameFontHighlight", 14, "")
	empty:SetPoint("TOP", rowsContainer, "TOP", 0, -18)
	empty:SetJustifyH("CENTER")
	empty:SetTextColor(0.65, 0.65, 0.65, 0.95)
	empty:Hide()
	panel.Empty = empty

	function panel:ShowFor(data)
		data = data or {}
		local rowData, ratingEntry, seasonReady = buildBestRunsRows(data)
		local rowsHeight = #rowData > 0
			and (#rowData * BEST_RUNS_ROW_HEIGHT
				+ math.max(0, #rowData - 1) * BEST_RUNS_ROW_GAP)
			or 0
		local contentWidth = BEST_RUNS_PANEL_WIDTH - (BEST_RUNS_ROW_INSET_X * 2)
		local panelHeight = BEST_RUNS_PANEL_HEADER_HEIGHT
			+ math.max(rowsHeight, 54) + BEST_RUNS_PANEL_FOOTER_GAP
		self:SetSize(BEST_RUNS_PANEL_WIDTH, panelHeight)
		applyBestRunsPanelBackplate(self)
		self.RowsContainer:SetSize(contentWidth, rowsHeight)
		self.Empty:SetWidth(contentWidth)

		self.Title:SetText((GF.L and GF.L.MPLUS_BEST_RUNS_TITLE)
			or "赛季地下城最佳记录")
		local classFile = data.classFile or data.class
		local classR, classG, classB = UI.GetClassColor(classFile)
		self.Name:SetText(UI.GetCharacterFullName(data))
		self.Name:SetTextColor(classR, classG, classB, 1)
		local score = tonumber(ratingEntry and ratingEntry.score)
			or tonumber(data.rating) or 0
		local scoreColor = ratingEntry and ratingEntry.scoreColor
			or data.ratingColor
			or (GF.MythicPlusRatingCache
				and GF.MythicPlusRatingCache:GetCachedScoreColor(score))
		self.OverallScore:SetText(string.format("%s%s",
				UI.ColorText(((GF.L and GF.L.MPLUS_TOOLTIP_SEASON_RATING)
					or "赛季评分") .. "：", "ffffd100"),
				UI.ColorText(
					math.floor(score + 0.5),
					UI.ColorToARGBHex(scoreColor))))
		self.OverallScore:SetTextColor(1, 1, 1, 1)

		while #self.Rows < #rowData do
			self.Rows[#self.Rows + 1] = createBestRunRow(self.RowsContainer)
		end
		for index, row in ipairs(self.Rows) do
			local rowInfo = rowData[index]
			row:ClearAllPoints()
			if rowInfo then
				row:SetPoint("TOPLEFT", self.RowsContainer, "TOPLEFT", 0,
					-((index - 1) * (BEST_RUNS_ROW_HEIGHT + BEST_RUNS_ROW_GAP)))
				row:SetPoint("TOPRIGHT", self.RowsContainer, "TOPRIGHT", 0,
					-((index - 1) * (BEST_RUNS_ROW_HEIGHT + BEST_RUNS_ROW_GAP)))
				local dungeon = rowInfo.dungeon or {}
				local texture = dungeon.visualTexture
					or dungeon.backgroundTexture
					or dungeon.texture
				if texture then
					row.Image:SetTexture(texture)
					row.Image:SetVertexColor(1, 1, 1, 0.70)
					applyBestRunsImageTexCoords(row.Image, dungeon.visualTexCoords)
				else
						row.Image:SetTexture(GF.WHITE_TEXTURE)
					row.Image:SetVertexColor(0.08, 0.10, 0.12, 1)
					row.Image:SetTexCoord(0, 1, 0, 1)
				end
				row.DungeonName:SetText(dungeon.name
					or ((GF.L and GF.L.MPLUS_UNKNOWN_DUNGEON) or "未知地下城"))
				local run = rowInfo.run
				local level = tonumber(run and run.level) or 0
				if level > 0 then
					row.Time:SetText(formatRunDuration(run.durationMS))
					row.Time:SetTextColor(1, 1, 1, 0.96)
					row.Level:SetText("+" .. tostring(level))
					row.Level:SetTextColor(1, 1, 1, 0.98)
					local runScore = tonumber(run.score) or 0
					local rules = GF.MYTHIC_PLUS_SCORE_COLOR_RULE or {}
					local runScoreColor = (GF.MythicPlusRatingCache
						and GF.MythicPlusRatingCache:GetScoreColor(
							runScore, rules.SINGLE_DUNGEON))
						or run.scoreColor
					row.Score:SetText(tostring(math.floor(runScore + 0.5)))
					row.Score:SetTextColor(
						tonumber(runScoreColor and runScoreColor.r) or 1,
						tonumber(runScoreColor and runScoreColor.g) or 1,
						tonumber(runScoreColor and runScoreColor.b) or 1,
						1)
				else
					row.Time:SetText("-")
					row.Time:SetTextColor(0.55, 0.55, 0.55, 0.92)
					row.Level:SetText("-")
					row.Level:SetTextColor(0.55, 0.55, 0.55, 0.92)
					row.Score:SetText((GF.L and GF.L.MPLUS_TOOLTIP_NO_RECORD)
						or "无记录")
					row.Score:SetTextColor(0.55, 0.55, 0.55, 0.92)
				end
				row:Show()
			else
				row:Hide()
			end
		end
		self.Empty:SetText(seasonReady
			and ((GF.L and GF.L.MPLUS_TOOLTIP_NO_RECORD) or "无记录")
			or ((GF.L and GF.L.MPLUS_TOOLTIP_SEASON_UNAVAILABLE)
				or "无法加载当前赛季。"))
		self.Empty:SetShown(#rowData == 0)
		if GF.GetPanelScale and self.SetScale then
			self:SetScale(GF.GetPanelScale())
		end
		self:ClearAllPoints()
		local mainFrame = GF.UI and GF.UI.GetMainFrame and GF.UI.GetMainFrame()
		if mainFrame and mainFrame:IsShown() then
			self:SetPoint("CENTER", mainFrame, "CENTER", 0, -8)
		else
			self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
		self:Show()
		if self.Raise then
			self:Raise()
		end
	end

	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, panel:GetName())
	end
	local mainFrame = GF.UI and GF.UI.GetMainFrame and GF.UI.GetMainFrame()
	if mainFrame and mainFrame.HookScript then
		mainFrame:HookScript("OnHide", function()
			panel:Hide()
		end)
	end
	return panel
end

function CharacterPage:Create(parent)
	if self.page then
		return self.page
	end
	local page = {}
	page.frame = CreateFrame("Frame", nil, parent)
	page.frame:SetAllPoints()
	page.frame:Hide()

	page.playerInfo = CreateFrame("Frame", nil, page.frame)
	page.playerInfo:SetPoint("TOPLEFT", page.frame, "TOPLEFT", 24, -4)
	page.playerInfo:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT", -24, 10)

	local layout
	page.scroll, page.content, page.scrollBar = createScrollContainer(page.playerInfo, function()
		if layout then
			layout()
		end
	end)
	UI.AnchorWorkspaceScrollBar(page.scrollBar, page.frame)

	page.currentTitle = createSectionTitle(page.content, "")
	page.currentTitle:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, TITLE_TOP_OFFSET)
	page.currentTitle:SetPoint("TOPRIGHT", page.content, "TOPRIGHT", 0, TITLE_TOP_OFFSET)

	page.currentArea = CreateFrame("Frame", nil, page.content)
	page.currentArea:SetPoint("TOPLEFT", page.currentTitle, "BOTTOMLEFT", 0, -TITLE_TO_CARD_GAP)
	page.currentArea:SetPoint("TOPRIGHT", page.currentTitle, "BOTTOMRIGHT", 0, -TITLE_TO_CARD_GAP)
	page.currentArea:SetHeight(CARD_HEIGHT)
	if page.currentArea.SetClipsChildren then
		page.currentArea:SetClipsChildren(false)
	end
	page.currentArea:SetFrameLevel((page.currentTitle:GetFrameLevel() or page.content:GetFrameLevel() or 0) + 2)

	page.currentCard = createCharacterCard(page.currentArea, true)
	page.currentCard:SetPoint("TOPLEFT", page.currentArea, "TOPLEFT")
	page.bestRunsPanel = createBestRunsPanel(page.currentCard)
	page.weeklyCard = createWeeklyCard(page.currentArea)
	page.weeklyCard:SetPoint("TOPRIGHT", page.currentArea, "TOPRIGHT")
	page.weeklyCard:RegisterForClicks("LeftButtonUp")
	page.weeklyCard:SetScript("OnClick", function(_, mouseButton)
		local data = page.currentCard and page.currentCard._gfData
		if mouseButton == "LeftButton" and data then
			GameTooltip_Hide()
			page.bestRunsPanel:ShowFor(data)
		end
	end)

	page.warbandTitle = createSectionTitle(page.content, "")
	page.warbandTitle:SetPoint("TOPLEFT", page.currentArea, "BOTTOMLEFT", 0, -CURRENT_AREA_TO_WARBAND_TITLE_GAP)
	page.warbandTitle:SetPoint("TOPRIGHT", page.currentArea, "BOTTOMRIGHT", 0, -CURRENT_AREA_TO_WARBAND_TITLE_GAP)

	page.emptyContainer = CreateFrame("Frame", nil, page.content)
	page.emptyText = createText(page.emptyContainer, "GameFontDisable",
		GF.EMPTY_PROMPT_TEXT_SIZE or GF.BROWSE_EMPTY_TEXT_SIZE or 14, "")
	page.emptyText:SetAllPoints(page.emptyContainer)
	page.emptyText:SetJustifyH("CENTER")
	page.emptyText:SetJustifyV("MIDDLE")
	page.emptyText:SetTextColor(1, 0.82, 0, 1)
	if GF.UI and GF.UI.ApplyEmptyPromptFont then
		GF.UI.ApplyEmptyPromptFont(page.emptyText, "GameFontDisable")
	end
	page.cards = {}
	page.visibleCardCount = 0

	layout = function()
		local width = math.max(1, math.floor(page.scroll:GetWidth() or 900))
		page.content:SetWidth(width)
		-- The two identical title atlases are separated by a fractional number
		-- of physical pixels at some scales. Match the current title's texture
		-- phase to the visually correct warband title without moving either frame.
		alignTitleBackgroundPixelPhase(
			page.currentTitle,
			CURRENT_TO_WARBAND_TITLE_DISTANCE)
		local topCardWidth = math.max(1, math.floor((width - CARD_GAP_X) / 2))
		page.currentCard:SetSize(topCardWidth, CARD_HEIGHT)
		page.weeklyCard:SetSize(topCardWidth, CARD_HEIGHT)

		local cardWidth = math.max(CARD_MIN_WIDTH, math.floor((width - CARD_GAP_X) / 2))
		for index = 1, page.visibleCardCount do
			local card = page.cards[index]
			card:ClearAllPoints()
			card:SetSize(cardWidth, CARD_HEIGHT)
			local column = (index - 1) % 2
			local row = math.floor((index - 1) / 2)
			card:SetPoint("TOPLEFT", page.warbandTitle, "BOTTOMLEFT",
				column * (cardWidth + CARD_GAP_X),
				-TITLE_TO_CARD_GAP - row * (CARD_HEIGHT + CARD_GAP_Y))
		end

		local rows = math.ceil(page.visibleCardCount / 2)
		local cardsHeight = rows > 0
			and (rows * CARD_HEIGHT + math.max(0, rows - 1) * CARD_GAP_Y + CARD_BOTTOM_GAP)
			or 0
		local fixedTop = 20 + TITLE_HEIGHT + TITLE_TO_CARD_GAP + CARD_HEIGHT
			+ CURRENT_AREA_TO_WARBAND_TITLE_GAP + TITLE_HEIGHT + TITLE_TO_CARD_GAP
		local viewHeight = page.scroll:GetHeight() or 1
		page.content:SetHeight(math.max(viewHeight, fixedTop + cardsHeight))

		page.emptyContainer:ClearAllPoints()
		page.emptyContainer:SetPoint("TOPLEFT", page.warbandTitle, "BOTTOMLEFT", 0, -TITLE_TO_CARD_GAP)
		page.emptyContainer:SetPoint("TOPRIGHT", page.warbandTitle, "BOTTOMRIGHT", -8, -TITLE_TO_CARD_GAP)
		page.emptyContainer:SetHeight(math.max(40, viewHeight - fixedTop))
		if page.scroll._gfUpdateRange then
			page.scroll:_gfUpdateRange()
		end
	end

	function page:RefreshLocale()
		self.currentTitle.Label:SetText((GF.L and GF.L.MPLUS_CURRENT_CHARACTER) or "当前角色")
		self.warbandTitle.Label:SetText((GF.L and GF.L.MPLUS_WARBAND_CHARACTERS) or "战团角色")
		self.emptyText:SetText((GF.L and GF.L.MPLUS_CHARACTER_EMPTY)
			or "暂无可同步的满级战团角色，切换该战团内其他角色可自动补充数据")
		if self.currentCard and self.currentCard.RolePrompt then
			self.currentCard.RolePrompt:SetText(
				(GF.L and GF.L.MPLUS_SPECIALIZATION_LOADOUT)
					or "专精天赋"
			)
		end
		TalentLoadoutUI.UpdateSpecializations(self.currentCard)
		TalentLoadoutUI.UpdateDropdown(self.currentCard)
	end

	function page:RefreshView()
		local current = GF.MythicPlusCharacterStore and GF.MythicPlusCharacterStore:GetCurrent()
		bindCharacterCard(self.currentCard, current or {})
		bindWeeklyCard(self.weeklyCard)
		local characters = getWarbandCharacters()
		self.visibleCardCount = #characters
		while #self.cards < #characters do
			local card = createCharacterCard(self.content, false)
			card:EnableMouseWheel(true)
			card:SetScript("OnMouseWheel", function(_, delta)
				local handler = self.scroll and self.scroll:GetScript("OnMouseWheel")
				if handler then
					handler(self.scroll, delta)
				end
			end)
			self.cards[#self.cards + 1] = card
		end
		for index, card in ipairs(self.cards) do
			local data = characters[index]
			if data then
				bindCharacterCard(card, data)
				card:Show()
			else
				card:Hide()
			end
		end
		self.emptyContainer:SetShown(#characters == 0)
		layout()
	end

	function page:Show()
		self:RefreshLocale()
		self:RefreshView()
		self.frame:Show()
	end

	function page:Hide()
		self.frame:Hide()
	end

	page:RefreshLocale()
	self.page = page
	return page
end
