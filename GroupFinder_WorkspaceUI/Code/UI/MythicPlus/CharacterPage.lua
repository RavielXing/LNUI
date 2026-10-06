local _, GF = ...
GF = GF.GF or GF

GF.MythicPlusCharacterPage = GF.MythicPlusCharacterPage or {}
local CharacterPage = GF.MythicPlusCharacterPage
local UI = GF.MythicPlusUI
local ServiceUtil = GF.MythicPlusServiceUtil

local FRAME_ATLASES = UI.FRAME_ATLASES
local CARD_HOVER_STYLE = GF.MYTHIC_PLUS_CHARACTER_CARD_HOVER_STYLE
local FRAME_SOURCE_CAP_RATIO = UI.FRAME_CAP_SOURCE_RATIO
local FRAME_DISPLAY_CAP_WIDTH = UI.FRAME_CAP_DISPLAY_WIDTH
local LABEL_SOURCE_CAP_RATIO = UI.LABEL_CAP_SOURCE_RATIO
local FRAME_BACKGROUND_INSETS = {
	left = 5,
	top = 4,
	right = 5,
	bottom = 4,
}

local TITLE_HEIGHT = 40
local TITLE_BACKGROUND_BLEED_LEFT = GF.MYTHIC_PLUS_CHARACTER_CONTENT_INSET_X
	- GF.MYTHIC_PLUS_CHARACTER_TITLE_INSET_LEFT
local TITLE_TEXT_INSET_X = 14
local TITLE_TEXT_SIZE = 14
local TITLE_TOP_OFFSET = -20
local TITLE_TO_CARD_GAP = 14
local CURRENT_AREA_TO_WARBAND_TITLE_GAP = 16

local CARD_MIN_WIDTH = 320
local CARD_HEIGHT = 114
local CARD_GAP_X = 12
local CARD_GAP_Y = 14
local CARD_BOTTOM_GAP = 20
CharacterPage.DRAG = {
	groupGap = 16,
	emptyHeight = 48,
	carpoolEmptyHeight = CARD_HEIGHT,
	carpool = "carpool",
	other = "other",
	edgeScrollSpeed = 360,
	edgeScrollRange = 42,
	startDistance = 6,
	insertAtlas = "glues-characterSelect-divider",
	insertHitWidth = 18,
	insertLineWidth = 10,
	swapAlpha = 0.4,
	fadeOutDuration = 0.14,
	fadeInDuration = 0.18,
}
local CURRENT_TO_WARBAND_TITLE_DISTANCE = TITLE_HEIGHT
	+ TITLE_TO_CARD_GAP
	+ CARD_HEIGHT
	+ CURRENT_AREA_TO_WARBAND_TITLE_GAP

CharacterPage.EMPTY_SQUAD_ICON_ATLASES = {
	"plunderstorm-glues-queue-pending-spinner-front-solo",
	"plunderstorm-glues-queue-pending-spinner-front-duo",
	"plunderstorm-glues-queue-pending-spinner-front-trio",
}

function CharacterPage:CreateEmptySquadFadeAnimation(texture, phaseIndex)
	if not (texture and texture.CreateAnimationGroup) then
		return nil
	end
	local group = texture:CreateAnimationGroup()
	if not (group and group.CreateAnimation) then
		return nil
	end
	group:SetLooping("REPEAT")
	local order = 0
	local function addAlpha(fromAlpha, toAlpha, duration, smoothing)
		if duration <= 0 then
			return
		end
		order = order + 1
		local alpha = group:CreateAnimation("Alpha")
		alpha:SetOrder(order)
		alpha:SetFromAlpha(fromAlpha)
		alpha:SetToAlpha(toAlpha)
		alpha:SetDuration(duration)
		if smoothing and alpha.SetSmoothing then
			alpha:SetSmoothing(smoothing)
		end
	end
	local leadingDelay = (phaseIndex - 1) * 1.5
	local trailingDelay = (#self.EMPTY_SQUAD_ICON_ATLASES - phaseIndex) * 1.5
	addAlpha(0, 0, leadingDelay)
	addAlpha(0, 1, 0.35, "OUT")
	addAlpha(1, 1, 0.8)
	addAlpha(1, 0, 0.35, "IN")
	addAlpha(0, 0, trailingDelay)
	return group
end

local CONTENT_INSET_X = 18
local CONTENT_INSET_TOP = 8
local TOP_SECTION_HEIGHT = 65
local CONTROL_INSET_X = 14
local CONTROL_RIGHT_INSET = 20
local TOP_LABEL_Y = -8
local INFO_ROW_Y = 10

CharacterPage.WARBAND_CLASS_PORTRAIT_SIZE = 48
CharacterPage.WARBAND_CLASS_PORTRAIT_GAP = 10
CharacterPage.WARBAND_CLASS_PORTRAIT_MASK =
	"Interface\\FrameGeneral\\UIFrameIconMask"

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
local ROLE_ATLAS_HEIGHT = 44
local ROLE_ATLAS_OFFSET_Y = -3
local ROLE_ATLAS_VISIBLE_HEIGHT = ROLE_ATLAS_HEIGHT + ROLE_ATLAS_OFFSET_Y
local ROLE_BAR_ATLAS = FRAME_ATLASES.label
local ROLE_LABEL_WIDTH = 112
local ROLE_TOGGLE_WIDTH = GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE.roleSize
local ROLE_TOGGLE_HEIGHT = ROLE_TOGGLE_WIDTH
local ROLE_TOGGLE_GAP = GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE.roleGap
local ROLE_CHECK_SIZE = GF.MYTHIC_PLUS_CHARACTER_CHECK_STYLE.size
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
	MAX_SPECIALIZATIONS = 4,
	-- The native background extends 7px above and 9px below the button.
	VISIBLE_CENTER_OFFSET_Y = -1,
	-- The native arrow extends 1px past the button's logical right edge.
	RIGHT_EDGE_OFFSET_X = 1,
}

local WEEKLY_CONTENT_INSET_X = 20
local WEEKLY_COUNT_WIDTH = 158
local WEEKLY_TITLE_Y = -15.5
local WEEKLY_COUNT_TAG_Y = -9
local WEEKLY_COUNT_TAG_HEIGHT = 24
local WEEKLY_COUNT_TAG_RIGHT_OFFSET_X = -4
local WEEKLY_COUNT_GROUP_OFFSET_X = 6
local WEEKLY_COUNT_CLOCK_SIZE = 14
local WEEKLY_COUNT_ICON_TEXT_GAP = 8
local WEEKLY_DIVIDER_Y = -40
local WEEKLY_DIVIDER_HEIGHT = 1.5
local WEEKLY_REWARD_BLOCK_Y = -45
local WEEKLY_REWARD_BLOCK_HEIGHT = 64
local WEEKLY_REWARD_BLOCK_INSET_X = 10
local WEEKLY_REWARD_BLOCK_GAP = 6
local WEEKLY_REWARD_ICON_SIZE = 42
local WEEKLY_REWARD_ICON_INSET_X = 11
local WEEKLY_REWARD_FLAG_WIDTH = 30
local WEEKLY_REWARD_FLAG_HEIGHT = 30
local WEEKLY_TIMER_BACKGROUND_ATLAS = "housing-dashboard-timertag-bg"
local WEEKLY_TIMER_CLOCK_ATLAS = "housing-dashboard-timertag-clock-icon"
local WEEKLY_REWARD_BLOCK_ATLAS = GF.MYTHIC_PLUS_WEEKLY_REWARD_BLOCK_ATLAS
local WEEKLY_REWARD_ICON_BACKGROUND_ATLAS =
	"house-upgrade-reward-icon-background"
local WEEKLY_REWARD_ICON_OVERLAY_ATLAS =
	"house-upgrade-reward-icon-frame-overlay"
local WEEKLY_REWARD_DIVIDER_ATLAS = "house-upgrade-header-divider-horz"
local WEEKLY_REWARD_ARROW_ATLAS = "house-reward-increase-arrows"
local WEEKLY_REWARD_FLAG_ATLAS = GF.HOUSING_TASK_FLAG_ATLAS
local WEEKLY_REWARD_COMPLETE_ATLAS = GF.HOUSING_TASK_CHECKMARK_ATLAS
local WEEKLY_REWARD_EFFECT_ATLAS =
	"evergreen-weeklyrewards-reward-unlocked-fx-swirl"
local WEEKLY_REWARD_DISABLED_CENTER_ATLAS = "greatVault-centerPlate-dis"
local WEEKLY_REWARD_EFFECT_ID = 179
local WEEKLY_REWARD_EFFECT_SCALE = 0.5
local WEEKLY_REWARD_EFFECT_OFFSET_X = 2.5
local WEEKLY_REWARD_EFFECT_OFFSET_Y = 0.5
local WEEKLY_REWARD_CONTENT_LEFT = 61
local WEEKLY_REWARD_CONTENT_RIGHT = 8
local WEEKLY_REWARD_DETAIL_GAP = 2
local WEEKLY_REWARD_LABEL_WIDTH = 30
local WEEKLY_BEST_BUTTON_SIZE = 24
local WEEKLY_BEST_BUTTON_GAP = 3
local WEEKLY_BEST_BUTTON_ACTIVE_ATLAS = "category-icons_all_active"
local WEEKLY_BEST_BUTTON_INACTIVE_ATLAS = "category-icons_all_inactive"
local WEEKLY_BEST_BUTTON_PRESSED_ATLAS = "category-icons_all_pressed"
local WEEKLY_REWARD_THRESHOLDS = { 1, 4, 8 }
local WEEKLY_REWARD_COLORS = {
	muted = "ff8a8a8a",
	accent = "ffffb80d",
	random = "ffffffff",
	veteran = "ff1eff00",
	champion = "ff0070dd",
	hero = "ffa335ee",
	myth = "ffffd100",
	ascended = "ffff8000",
}

local BEST_RUNS_CARD_WIDTH = 132
-- Blizzard's CypherChoice card is 292 x 573, including its transparent edges.
local BEST_RUNS_CARD_HEIGHT = BEST_RUNS_CARD_WIDTH * 573 / 292
local BEST_RUNS_CARD_GAP = 12
local BEST_RUNS_PANEL_INSET_X = 18
local BEST_RUNS_METRIC_WIDTH = 108
-- The native PowerChoice frame is 240px wide. Scale spatial effects with
-- the card; retain every native layer, blend mode and alpha. Portrait rotation
-- is deliberately slower for these compact record cards.
local BEST_RUNS_FX_SCALE = BEST_RUNS_CARD_WIDTH / 240
local BEST_RUNS_STYLE = {
	-- Circular geometry is independent of rectangular dungeon cards.
	portalPresentation = {
		width = 215,
		height = 173,
		fallbackWidth = 86,
		fallbackHeight = 92,
		offsetX = 0,
		offsetY = 0,
		anchorX = 5,
		anchorY = 0,
		interruptedAnchorX = 4,
		effectScale = 1,
		hoverOffsetX = 0,
		hoverOffsetY = 0,
		interruptedOffsetX = 0,
		interruptedOffsetY = 0,
	},
	cardAtlases = {
		"UI-Frame-CypherChoice-CardParchment-Style1",
		"UI-Frame-CypherChoice-CardParchment-Style2",
		"UI-Frame-CypherChoice-CardParchment-Style3",
	},
	titleAtlas = "UI-Frame-CypherChoice-PendingButton",
	titleGlowAtlas = "UI-Frame-CypherChoice-PendingButtonFXGlow",
	titleMaskTexture = "Interface\\PlayerChoice\\CypherTalentPlayerChoiceFXButtonMask",
	sectionGap = 16,
	titleWidth = 267,
	titleHeight = 54,
	titleSweepPeriod = 3.5,
	titleSweepSeconds = 0.75,
	summaryWidth = 224,
	summaryHeight = 26,
	summaryGap = 12,
	summaryTitleFontSize = 12,
	summaryScoreFontSize = 24,
	ratingLabelColor = { 0.78, 0.73, 0.60, 1 },
	closeAtlas = "UI-Frame-CypherChoice-HideButton",
	closeHighlightAtlas = "UI-Frame-cypherchoice-HideButtonHighlight",
	closeWidth = 168,
	closeHeight = 168 * 54 / 203,
	closeBottomInset = 8,
	closeHoverInSeconds = 0.18,
	closeHoverOutSeconds = 0.22,
	portraitBorderAtlas = "SpecDial_Outer_TitanLineRing",
	portraitGlowAtlas = "UI-Frame-CypherChoice-Portrait-FX-GoldGlow",
	portraitBackAtlas = "ui-frame-cypherchoice-portrait-fx-back-common",
	portraitSparklesAtlas = "ui-frame-cypherchoice-portrait-fx-sparkles",
	bottomGlowAtlas = "UI-Frame-CypherChoice-FX-BottomGlow",
	pixels1Atlas = "UI-Frame-CypherChoice-FX-Pixels01",
	pixels2Atlas = "UI-Frame-CypherChoice-FX-Pixels02",
	wispsAtlas = "UI-Frame-CypherChoice-FX-Wisps",
	lineGlowAtlas = "UI-Frame-CypherChoice-FX-LineGlow",
	lineMaskTexture = "Interface\\PlayerChoice\\CypherTalentPlayerChoiceFXLineMask",
	bottomMaskTexture = "Interface\\PlayerChoice\\CypherTalentPlayerChoiceFXGlowMask",
	scoreTitleFontSize = 9,
	scoreTitleTop = 164,
	scoreTitleHeight = 12,
	scoreFontSize = 18,
	scoreTop = 178,
	scoreHeight = 20,
	noRecordFontSize = 11,
	nameFontSize = 12,
	nameTop = 36,
	nameWidth = 96,
	nameLineWidth = 68,
	nameHeight = 34,
	nameLineSpacing = 1,
	nameSuffixes = { "新生法池", "生命之池", "竞技场", "競技場", "的洞穴", "神庙", "神廟" },
	-- Name, map and lower statistics follow the user-approved design.
	dungeonIconCenterY = -120,
	dungeonIconSize = 54,
	portraitRingSize = 62,
	backdropAlpha = 0.30,
	panelTravel = 24,
	panelFadeInSeconds = 0.26,
	panelFadeOutSeconds = 0.20,
	cardRevealSeconds = 0.20,
	cardRevealStagger = 0.035,
	cardRevealTravel = 10,
	-- Label, score and time centers follow one 18px baseline rhythm.
	timeCenterY = -206,
	timeHeight = 16,
	timeFontSize = 11,
	timeTextPadding = 2,
	timeIconSize = 14,
	timeIconGap = 0,
	-- An unlocked empty map stays colored inside the silver card and halo.
	mapEffectFields = { "PortraitBack", "DungeonIcon" },
	metricIcons = {
		time = { atlas = "unitframeicon-chromietime" },
	},
}
local BEST_RUNS_PANEL_HEADER_HEIGHT = BEST_RUNS_STYLE.titleHeight + BEST_RUNS_STYLE.sectionGap
local BEST_RUNS_PANEL_FOOTER_HEIGHT = BEST_RUNS_STYLE.sectionGap
	+ BEST_RUNS_STYLE.closeHeight + BEST_RUNS_STYLE.closeBottomInset
-- The portrait effects were sized for the original 48px map. Keep their
-- outer halo and orbit proportional when the map grows; bottom FX stay put.
BEST_RUNS_STYLE.portraitEffectScale = BEST_RUNS_STYLE.dungeonIconSize / 48

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

local function keepCardFontSize(text, template)
	if not text then
		return text
	end
	text._gfIgnoreFontScale = true
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(
			text,
			template or text._gfFontTemplate or "GameFontHighlight"
		)
	end
	return text
end

local function createCardText(parent, template, size, flags, damageNumber)
	if damageNumber then
		-- Numeric art is owned by this view, so a global typography refresh must
		-- not replace the native damage face or multiply its authored size.
		local text = parent:CreateFontString(nil, "OVERLAY", template)
		local path = DAMAGE_TEXT_FONT or text:GetFont()
		text:SetFont(path, size, flags or "")
		text._gfIgnoreFontScale = true
		return text
	end
	return keepCardFontSize(
		createText(parent, template, size, flags),
		template
	)
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

local function createSolidTexture(parent, layer, subLevel)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 0)
	texture:SetTexture(GF.WHITE_TEXTURE)
	return texture
end

local STRETCH_LAYER_KEYS = { "left", "center", "right" }

local function resolveStretchInsets(pieces)
	local configured = pieces and pieces.insets
	local function resolve(key, index)
		local value = type(configured) == "table"
			and (configured[key] or configured[index])
			or configured
		return math.max(0, tonumber(value) or 0)
	end
	return {
		left = resolve("left", 1),
		top = resolve("top", 2),
		right = resolve("right", 3),
		bottom = resolve("bottom", 4),
	}
end

local function layoutStretchLayer(pieces)
	if not (pieces and pieces.parent) then
		return
	end
	local parent = pieces.parent
	local insets = resolveStretchInsets(pieces)
	if not pieces.atlasInfo then
		pieces.left:Hide()
		pieces.right:Hide()
		pieces.center:ClearAllPoints()
		pieces.center:SetPoint(
			"TOPLEFT",
			parent,
			"TOPLEFT",
			insets.left,
			-insets.top
		)
		pieces.center:SetPoint(
			"BOTTOMRIGHT",
			parent,
			"BOTTOMRIGHT",
			-insets.right,
			insets.bottom
		)
		pieces.center:Show()
		return
	end
	local displayCapWidth = tonumber(pieces.displayCapWidth)
	if not displayCapWidth then
		local targetHeight = tonumber(parent:GetHeight()) or 0
		local sourceHeight = tonumber(pieces.atlasInfo.logicalHeight) or 0
		if targetHeight > 0 and sourceHeight > 0 then
			displayCapWidth = pieces.sourceCapWidth
				* targetHeight / sourceHeight
		end
	end
	displayCapWidth = math.max(1, displayCapWidth or FRAME_DISPLAY_CAP_WIDTH)
	local targetWidth = tonumber(parent:GetWidth()) or 0
	if targetWidth > 0 then
		local availableWidth = math.max(
			0,
			targetWidth - insets.left - insets.right
		)
		displayCapWidth = math.min(displayCapWidth, availableWidth / 2)
	end

	pieces.left:ClearAllPoints()
	pieces.left:SetPoint(
		"TOPLEFT",
		parent,
		"TOPLEFT",
		insets.left,
		-insets.top
	)
	pieces.left:SetPoint(
		"BOTTOMLEFT",
		parent,
		"BOTTOMLEFT",
		insets.left,
		insets.bottom
	)
	pieces.left:SetWidth(displayCapWidth)
	pieces.left:Show()
	pieces.right:ClearAllPoints()
	pieces.right:SetPoint(
		"TOPRIGHT",
		parent,
		"TOPRIGHT",
		-insets.right,
		-insets.top
	)
	pieces.right:SetPoint(
		"BOTTOMRIGHT",
		parent,
		"BOTTOMRIGHT",
		-insets.right,
		insets.bottom
	)
	pieces.right:SetWidth(displayCapWidth)
	pieces.right:Show()
	pieces.center:ClearAllPoints()
	pieces.center:SetPoint("TOPLEFT", pieces.left, "TOPRIGHT")
	pieces.center:SetPoint("BOTTOMRIGHT", pieces.right, "BOTTOMLEFT")
	pieces.center:Show()
end

local function createStretchLayer(parent, atlas, layer, subLevel, options)
	options = type(options) == "table" and options or {}
	local function createPiece()
		local texture = parent:CreateTexture(
			nil,
			layer or "ARTWORK",
			nil,
			subLevel or 0
		)
		if GF.UI.SetNativeAtlasSampling then
			GF.UI.SetNativeAtlasSampling(texture, true)
		end
		return texture
	end
	local pieces = {
		left = createPiece(),
		center = createPiece(),
		right = createPiece(),
		parent = parent,
		atlas = atlas,
		displayCapWidth = options.displayCapWidth,
		insets = options.insets,
	}
	local atlasInfo = GF.UI.GetNativeAtlasInfo
		and GF.UI.GetNativeAtlasInfo(atlas)
	local sourceCapRatio = tonumber(options.sourceCapRatio)
		or FRAME_SOURCE_CAP_RATIO
	if atlasInfo and GF.UI.SetNativeAtlasPieceRegion then
		local sourceWidth = tonumber(atlasInfo.logicalWidth) or 0
		local sourceCapWidth = sourceWidth * sourceCapRatio
		local capRatio = sourceWidth > 0 and sourceCapWidth / sourceWidth or 0
		if capRatio > 0 and capRatio < 0.5 then
			pieces.atlasInfo = atlasInfo
			pieces.sourceCapWidth = sourceCapWidth
			local ranges = {
				left = { 0, capRatio },
				center = { capRatio, 1 - capRatio },
				right = { 1 - capRatio, 1 },
			}
			local applied = true
			for _, key in ipairs(STRETCH_LAYER_KEYS) do
				local range = ranges[key]
				applied = GF.UI.SetNativeAtlasPieceRegion(
					pieces[key],
					atlasInfo,
					range[1],
					range[2],
					0,
					1,
					true
				) and applied
			end
			if not applied then
				pieces.atlasInfo = nil
			end
		end
	end
	if not pieces.atlasInfo then
		pieces.left:SetTexture(nil)
		pieces.right:SetTexture(nil)
		GF.UI.TrySetAtlas(pieces.center, atlas, false)
	end
	layoutStretchLayer(pieces)
	return pieces
end

local function setLayerAlpha(layer, alpha)
	for _, key in ipairs(STRETCH_LAYER_KEYS) do
		local texture = layer and layer[key]
		if texture then
			texture:SetAlpha(alpha)
		end
	end
end

local function setLayerColor(layer, r, g, b, a)
	for _, key in ipairs(STRETCH_LAYER_KEYS) do
		local texture = layer and layer[key]
		if texture then
			texture:SetVertexColor(r, g, b, a or 1)
		end
	end
end

local function setLayerDesaturated(layer, desaturated)
	for _, key in ipairs(STRETCH_LAYER_KEYS) do
		local texture = layer and layer[key]
		if texture and texture.SetDesaturated then
			texture:SetDesaturated(desaturated == true)
		end
	end
end

local function createCardChrome(card)
	card._gfMythicCharacterChrome = {
		dark = createStretchLayer(card, FRAME_ATLASES.dark, "BACKGROUND", -6, {
			displayCapWidth = FRAME_DISPLAY_CAP_WIDTH,
		}),
		brown = createStretchLayer(card, FRAME_ATLASES.brown, "BACKGROUND", -5, {
			displayCapWidth = FRAME_DISPLAY_CAP_WIDTH,
			insets = FRAME_BACKGROUND_INSETS,
		}),
		class = createStretchLayer(card, FRAME_ATLASES.class, "BACKGROUND", -4, {
			displayCapWidth = FRAME_DISPLAY_CAP_WIDTH,
			insets = FRAME_BACKGROUND_INSETS,
		}),
		border = createStretchLayer(card, FRAME_ATLASES.border, "BORDER", 1, {
			displayCapWidth = FRAME_DISPLAY_CAP_WIDTH,
		}),
	}
	setLayerDesaturated(card._gfMythicCharacterChrome.class, true)
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
	local base = createStretchLayer(hoverFrame, FRAME_ATLASES.border, "OVERLAY", 6, {
		displayCapWidth = FRAME_DISPLAY_CAP_WIDTH,
	})
	local glow = createStretchLayer(hoverFrame, FRAME_ATLASES.hover, "OVERLAY", 7, {
		displayCapWidth = FRAME_DISPLAY_CAP_WIDTH,
	})
	for _, key in ipairs(STRETCH_LAYER_KEYS) do
		glow[key]:SetBlendMode("ADD")
	end
	setLayerAlpha(base, 1)
	setLayerAlpha(glow, CARD_HOVER_STYLE.glowAlpha)
	hoverFrame:SetAlpha(0)
	hoverFrame:Hide()
	local targetAlpha, fromAlpha, elapsed, duration = 0, 0, 0, 0
	local function setHovered(hovered)
		local target = hovered and 1 or 0
		if targetAlpha == target then
			return
		end
		targetAlpha = target
		fromAlpha = hoverFrame:GetAlpha()
		elapsed = 0
		local fullDuration = hovered and CARD_HOVER_STYLE.fadeInDuration
			or CARD_HOVER_STYLE.fadeOutDuration
		duration = fullDuration * math.abs(target - fromAlpha)
		if hovered then
			hoverFrame:Show()
		end
	end
	local function updateHover(self, delta)
		-- Child controls can consume OnLeave; keep the existing visible-only
		-- pointer check so moving between a card and its controls never flickers.
		setHovered(card.IsMouseOver and card:IsMouseOver())
		elapsed = elapsed + delta
		local progress = duration > 0 and math.min(elapsed / duration, 1) or 1
		local eased = progress * progress * (3 - 2 * progress)
		self:SetAlpha(fromAlpha + (targetAlpha - fromAlpha) * eased)
		if progress == 1 and targetAlpha == 0 then
			self:Hide()
		end
	end
	hoverFrame:SetScript("OnShow", function(self)
		setHovered(true)
		self:SetScript("OnUpdate", updateHover)
	end)
	hoverFrame:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
		targetAlpha, fromAlpha, elapsed, duration = 0, 0, 0, 0
		self:SetAlpha(0)
	end)
	card:HookScript("OnEnter", function()
		setHovered(true)
	end)
	card:HookScript("OnLeave", function()
		if not (card.IsMouseOver and card:IsMouseOver()) then
			setHovered(false)
		end
	end)
	card:HookScript("OnHide", function()
		hoverFrame:Hide()
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

local function createCharacterControlBackdrop(parent)
	local frameParent = parent:GetParent() or parent
	local backdrop = CreateFrame("Frame", nil, frameParent)
	backdrop:SetPoint("TOPLEFT", parent, "TOPLEFT")
	backdrop:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
	backdrop:SetFrameLevel(math.max((parent:GetFrameLevel() or 1) - 1, 0))
	backdrop:EnableMouse(false)
	local style = GF.MYTHIC_PLUS_CHARACTER_CONTROL_STYLE
	local function layout(self)
		local width, height = self:GetWidth(), self:GetHeight()
		if width <= 0 or height <= 0 then
			return
		end
		local state = self.controlState or "normal"
		local atlas = self.hovered and state ~= "disabled" and style.hoverAtlas or style.atlas
		local info = GF.UI.GetNativeAtlasInfo(atlas)
		if info and self.chromeInfo == info and self.chromeWidth == width
			and self.chromeHeight == height and self.chromeState == state
		then
			return
		end
		-- The long key and square actions share isotropic corners. Only edge
		-- middles and the center stretch; resizing cannot flatten the chamfers.
		local corner = math.max(1, math.min(style.cornerSize * height
			/ style.referenceHeight, width * 0.45, height * 0.45))
		local chrome = info and GF.UI.ApplyControlCardChrome(self, {
			atlas = atlas, atlasInfo = info,
			sliceRatios = style.sliceRatios,
			displayMargins = { left = corner, right = corner,
				top = corner, bottom = corner },
			layer = "BORDER", subLevel = 0,
			centerLayer = "BACKGROUND", centerSubLevel = -1,
			color = style[state],
			continuousInternalUV = true, halfTexelInset = true,
		})
		if chrome then
			for _, texture in ipairs({ chrome.border.topLeft, chrome.border.top,
				chrome.border.topRight, chrome.border.left, chrome.center,
				chrome.border.right, chrome.border.bottomLeft, chrome.border.bottom,
				chrome.border.bottomRight }) do
				-- Remove the original purple before applying the shared gold tint.
				texture:SetDesaturated(true)
			end
			self.chromeInfo = info
			self.chromeWidth, self.chromeHeight, self.chromeState = width, height, state
		else
			self.chromeInfo = nil
			GF.UI.SetControlCardChromeShown(self, false)
		end
	end
	function backdrop:SetControlState(pressed, enabled)
		self.controlState = enabled == false and "disabled"
			or (pressed and "pressed" or "normal")
		layout(self)
	end
	function backdrop:BindHover()
		-- Install after the button's tooltip/action scripts are assigned.
		parent:HookScript("OnEnter", function()
			self.hovered = true
			layout(self)
		end)
		parent:HookScript("OnLeave", function()
			self.hovered = false
			layout(self)
		end)
	end
	backdrop:SetScript("OnSizeChanged", layout)
	backdrop:SetScript("OnShow", layout)
	parent:HookScript("OnShow", function()
		backdrop:Show()
	end)
	parent:HookScript("OnHide", function()
		backdrop.hovered = false
		backdrop:Hide()
	end)
	backdrop:SetControlState(false, true)
	return backdrop
end

local function createSectionTitle(parent, text)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(TITLE_HEIGHT)
	if frame.SetClipsChildren then
		frame:SetClipsChildren(true)
	end
	local background = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	background:SetAllPoints(frame)
	if background.SetSnapToPixelGrid then
		background:SetSnapToPixelGrid(true)
	end
	if background.SetTexelSnappingBias then
		background:SetTexelSnappingBias(0)
	end
	if not GF.UI.TrySetAtlas(
		background,
		GF.BROWSE_HEADER_BACKGROUND_ATLAS,
		false)
	then
		background:SetColorTexture(0, 0, 0, 0.45)
	end
	local label = createText(frame, "GameFontNormal", TITLE_TEXT_SIZE, "OUTLINE")
	label:SetPoint("TOPLEFT", frame, "TOPLEFT",
		TITLE_BACKGROUND_BLEED_LEFT + TITLE_TEXT_INSET_X, 0)
	label:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -TITLE_TEXT_INSET_X, 0)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	label:SetTextColor(1, 0.82, 0, 1)
	label:SetText(text or "")
	frame.Background = background
	frame.Label = label
	return frame
end

function CharacterPage:CreateCharacterGroupDropZone(parent)
	local zone = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	zone:EnableMouse(false)
	zone:SetBackdrop({
		bgFile = GF.WHITE_TEXTURE,
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	zone:SetBackdropColor(0.04, 0.03, 0.01, 0)
	zone:SetBackdropBorderColor(1, 0.82, 0, 0)

	local emptyLabel = createText(zone, "GameFontDisable", 12, "")
	emptyLabel:SetPoint("CENTER", zone, "CENTER")
	emptyLabel:SetSize(420, 24)
	emptyLabel:SetJustifyH("CENTER")
	emptyLabel:SetJustifyV("MIDDLE")
	emptyLabel:SetTextColor(0.55, 0.52, 0.45, 1)
	zone.EmptyLabel = emptyLabel

	return zone
end

function CharacterPage:SetResolvedClassIcon(texture, classFile)
	local iconInfo = GF.UI.ResolveClassIcon
		and GF.UI.ResolveClassIcon(classFile)
	local applied = iconInfo
		and iconInfo.atlas
		and GF.UI.TrySetAtlas(texture, iconInfo.atlas, false)
	if applied then
		texture:SetTexCoord(0, 1, 0, 1)
	elseif iconInfo and iconInfo.texture then
		texture:SetTexture(iconInfo.texture)
		local coords = iconInfo.texCoords
		if type(coords) == "table" then
			texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		else
			texture:SetTexCoord(0, 1, 0, 1)
		end
	else
		texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
end

local function alignTitleBackgroundPixelPhase(title, referenceDistance)
	local background = title and title.Background
	if not background then
		return
	end
	local offsetY = 0
	local snappedHeight = TITLE_HEIGHT
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
		snappedHeight = PixelUtil.GetNearestPixelSize(
			TITLE_HEIGHT,
			effectiveScale)
	end
	if background._gfPixelPhaseOffsetY == offsetY
		and background._gfPixelSnappedHeight == snappedHeight
	then
		return
	end
	background._gfPixelPhaseOffsetY = offsetY
	background._gfPixelSnappedHeight = snappedHeight
	background:ClearAllPoints()
	background:SetPoint("TOPLEFT", title, "TOPLEFT", 0, offsetY)
	background:SetPoint("TOPRIGHT", title, "TOPRIGHT", 0, offsetY)
	background:SetHeight(snappedHeight)
end

function CharacterPage:EnsureCharacterCardFade(card, direction)
	if not (card and card.CreateAnimationGroup) then
		return nil
	end
	card._gfCarpoolFades = card._gfCarpoolFades or {}
	if card._gfCarpoolFades[direction] then
		return card._gfCarpoolFades[direction]
	end
	local group = card:CreateAnimationGroup()
	local alpha = group and group:CreateAnimation("Alpha")
	if not alpha then
		return nil
	end
	group._gfAlpha = alpha
	group:SetScript("OnFinished", function(self)
		local callback = self._gfCallback
		self._gfCallback = nil
		if self._gfCardToken ~= card._gfCarpoolFadeToken then
			return
		end
		card:SetAlpha(self._gfFinalAlpha or 1)
		if callback then
			callback()
		end
	end)
	card._gfCarpoolFades[direction] = group
	return group
end

function CharacterPage:StopCharacterCardFades(card)
	if not card then
		return
	end
	card._gfCarpoolFadeToken = (card._gfCarpoolFadeToken or 0) + 1
	for _, group in pairs(card._gfCarpoolFades or {}) do
		group._gfCallback = nil
		if group.IsPlaying and group:IsPlaying() then
			group:Stop()
		end
	end
	card:SetAlpha(1)
end

function CharacterPage:PlayCharacterCardFade(
	card,
	direction,
	fromAlpha,
	toAlpha,
	duration,
	callback
)
	local group = self:EnsureCharacterCardFade(card, direction)
	local alpha = group and group._gfAlpha
	if not (group and alpha) then
		card:SetAlpha(toAlpha)
		return false
	end
	self:StopCharacterCardFades(card)
	card._gfCarpoolFadeToken = (card._gfCarpoolFadeToken or 0) + 1
	local token = card._gfCarpoolFadeToken
	card:SetAlpha(fromAlpha)
	alpha:SetFromAlpha(fromAlpha)
	alpha:SetToAlpha(toAlpha)
	alpha:SetDuration(duration)
	if alpha.SetSmoothing then
		alpha:SetSmoothing(direction == "out" and "IN" or "OUT")
	end
	group._gfCardToken = token
	group._gfFinalAlpha = toAlpha
	group._gfCallback = callback
	group:Play()
	return true
end

local function createScrollContainer(parent, onSizeChanged)
	local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
	scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT")
	scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
	-- The workspace permits its external scrollbar to overflow; keep only
	-- scrolling content clipped inside this page's inset viewport.
	scrollFrame:SetClipsChildren(true)
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
		return scrollFrame:GetVerticalScroll() or 0
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
		GF.UI.CancelSmoothWheelScrolling(scrollFrame)
		-- Preserve the actual pixel offset before native range callbacks adjust
		-- percentages; an old percentage against a new range shifts the viewport.
		local current = getValue()
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
		applyValue(math.min(current, maxValue))
	end
	scrollFrame._gfUpdateRange = updateRange
	scrollFrame._gfGetScrollValue = getValue
	scrollFrame._gfSetScrollValue = function(value)
		GF.UI.CancelSmoothWheelScrolling(scrollFrame)
		applyValue(value)
	end
	scrollFrame._gfGetScrollRange = function()
		return maxValue
	end

	if not useNative and scrollBar.SetScript and scrollBar.SetValue then
		scrollBar:SetScript("OnValueChanged", function(_, value)
			if not syncing then
				applyValue(value)
			end
		end)
		scrollFrame:SetScript("OnVerticalScroll", function(_, value)
			if not syncing then
				syncing = true
				setValue(value)
				syncing = nil
			end
		end)
	end
	scrollFrame._gfWheelRowH = UI.ROSTER_ROW_HEIGHT
	GF.UI.BindSmoothWheelScrolling(scrollFrame)
	GF.UI.BindSmoothWheelScrollBar(scrollFrame, scrollBar)
	scrollFrame:SetScript("OnSizeChanged", function()
		content:SetWidth(math.max(scrollFrame:GetWidth() or 0, 1))
		if onSizeChanged then
			onSizeChanged()
		end
		updateRange()
	end)
	if GF.UI.BindScrollFrameEdgeFade then
		GF.UI.BindScrollFrameEdgeFade(scrollFrame, content, GF.MYTHIC_PLUS_SCROLL_EDGE_FADE)
	end
	content:HookScript("OnSizeChanged", updateRange)
	return scrollFrame, content, scrollBar
end

local function configurePlayerModelCamera(model)
	if not model:IsVisible() then
		model._gfCameraDirty = true
		model:SetPaused(true)
		return
	end
	local style = GF.MYTHIC_PLUS_CHARACTER_PLAYER_MODEL
	model:SetCamera(0)
	model:SetPortraitZoom(style.portraitZoom)
	model:SetPosition(0, 0, style.positionZ)
	model:SetFacing(style.facing)
	model:SetAnimation(0)
	model:RefreshCamera()
	model._gfCameraDirty = nil
end

-- Keep model lifecycle helpers scoped; this page is near Lua's chunk-local limit.
do
	local function refreshPlayerModel(model)
		-- Coalesce appearance events into one visible-frame update, never a poll.
		model:SetScript("OnUpdate", nil)
		if not model:IsVisible() then return end
		model._gfAppearanceDirty = nil
		-- Preserve the character page's live shapeshift form, including druid forms.
		local ok, success = pcall(model.SetUnit, model, "player", false, false)
		if not ok or not success then
			model:ClearModel()
			model:SetAlpha(0)
			model:SetPaused(true)
			model._gfAppearanceDirty = true
			return
		end
		configurePlayerModelCamera(model)
		model:SetAlpha(1)
		model:SetPaused(false)
	end

	local function queuePlayerModelRefresh(model)
		model._gfAppearanceDirty = true
		if model:IsVisible() then model:SetScript("OnUpdate", refreshPlayerModel) end
	end

	function CharacterPage:CreatePlayerModel(card)
		local model = CreateFrame("PlayerModel", nil, card)
		model:Hide()
		model:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", MODEL_LEFT_INSET, MODEL_BOTTOM_INSET)
		model:SetSize(MODEL_WIDTH, MODEL_HEIGHT)
		model:SetFrameLevel(card:GetFrameLevel() + MODEL_FRAME_LEVEL_OFFSET)
		model:EnableMouse(false)
		model:SetKeepModelOnHide(true)
		model:SetPaused(true)
		model:SetAlpha(0)
		model._gfAppearanceDirty = true
		model:SetScript("OnShow", function(frame)
			if frame._gfAppearanceDirty then
				queuePlayerModelRefresh(frame)
			else
				if frame._gfCameraDirty then configurePlayerModelCamera(frame) end
				frame:SetPaused(false)
			end
		end)
		model:SetScript("OnHide", function(frame)
			frame:SetScript("OnUpdate", nil)
			frame:SetPaused(true)
		end)
		model:SetScript("OnModelLoaded", configurePlayerModelCamera)
		model:SetScript("OnSizeChanged", configurePlayerModelCamera)
		model:SetScript("OnEvent", queuePlayerModelRefresh)
		model:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
		model:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		model:RegisterEvent("TRANSMOGRIFY_SUCCESS")
		model:RegisterEvent("PLAYER_ENTERING_WORLD")
		model:Show()
		return model
	end
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
	local checked = button:GetChecked() == true
	if hovered == nil then
		hovered = button._gfCharacterCheckHovered == true
			or (button.IsMouseMotionFocus
				and button:IsMouseMotionFocus() == true)
	end
	local state = checked and "checked"
		or (enabled and hovered == true and "hover")
		or "normal"
	indicator:SetEnabled(enabled)
	indicator:SetChecked(checked)
	indicator:SetAlpha(GF.MYTHIC_PLUS_CHARACTER_CHECK_STYLE.alpha[state])
	if GF.UI.SetFilterCheckButtonHovered then
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

local function syncCharacterCheckVisualAfterClick(button)
	-- Update immediately, then once more after the native CheckButton finishes
	-- the current input dispatch. Without the final pass, the hover visual can
	-- remain on top of the new checked state until OnLeave refreshes it.
	syncCharacterCheckVisual(button)
	if not (C_Timer and C_Timer.After) then
		return
	end
	C_Timer.After(0, function()
		if button and button._gfCharacterCheckIndicator then
			syncCharacterCheckVisual(button)
		end
	end)
end

local function installCharacterCheckVisual(button, size, offsetY, visualOptions)
	offsetY = tonumber(offsetY) or 0
	visualOptions = type(visualOptions) == "table" and visualOptions or {}
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
		markSize = GF.MYTHIC_PLUS_CHARACTER_CHECK_STYLE.markSize,
		atlasStates = GF.MYTHIC_PLUS_CHARACTER_CHECK_STYLE.atlasStates,
		atlasChrome = GF.MYTHIC_PLUS_CHARACTER_CHECK_STYLE.chrome,
		disabledTint = visualOptions.disabledTint,
		disabledAlpha = visualOptions.disabledAlpha,
	})
	indicator:SetPoint("LEFT", button, "LEFT", 0, offsetY)
	indicator:EnableMouse(false)
	button._gfCharacterCheckIndicator = indicator

	-- Keep the inset fill on the parent so state alpha affects only
	-- the gold chrome and check mark. The existing mask also renders as RGBA.
	local backgroundStyle = GF.MYTHIC_PLUS_CHARACTER_CHECK_STYLE.background
	local inset = backgroundStyle.inset
	local background = button:CreateTexture(nil, "BACKGROUND", nil, -8)
	background:SetTexture(backgroundStyle.texture)
	background:SetVertexColor(unpack(backgroundStyle.color))
	background:SetPoint("TOPLEFT", indicator, "TOPLEFT", inset, -inset)
	background:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", -inset, inset)
	GF.UI.SetNativeAtlasSampling(background, false)
	button._gfCharacterCheckBackground = background

	button._gfCharacterCheckOriginalSetChecked = button.SetChecked
	button.SetChecked = function(self, checked, ...)
		self:_gfCharacterCheckOriginalSetChecked(checked, ...)
		syncCharacterCheckVisual(self)
	end
	button:HookScript("OnClick", syncCharacterCheckVisualAfterClick)
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

local function createCharacterCheckButton(
	parent,
	labelText,
	width,
	checkOffsetY,
	visualOptions
)
	local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	button:SetSize(width, 22)
	installCharacterCheckVisual(
		button,
		ROLE_CHECK_SIZE,
		checkOffsetY,
		visualOptions
	)
	local label = createCardText(button, "GameFontHighlight", 12, "")
	label:SetPoint("LEFT", button, "LEFT", 25, 0)
	label:SetPoint("RIGHT", button, "RIGHT")
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	label:SetText(labelText or "")
	label:SetTextColor(1, 1, 1, 0.92)
	button.Label = label
	button:SetScript("OnClick", function(self)
		self:SetChecked(self._cachedChecked == true)
	end)
	return button
end

local function createRoleIconButton(parent, roleKey)
	return GF.MythicPlusCharacterRoleButton:Create(parent, roleKey,
		ROLE_TITLE[roleKey], ROLE_DESCRIPTION[roleKey])
end

local function layoutCharacterFooter(card)
	if not card.CrestBar then return end
	local width = card.RoleSection:GetWidth()
	if width <= 0 then return end
	local style = GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE
	local compact = width < style.compactWidth and card.CrestBar.count ~= 0
	local inset = compact and style.inset or CONTENT_INSET_X
	local rolesWidth = ROLE_TOGGLE_WIDTH * 3 + ROLE_TOGGLE_GAP * 2
	local textWidth = card.CarpoolCheck.Label:GetStringWidth()
	local checkWidth = math.min(style.maxCarpoolWidth, math.max(style.carpoolWidth, 25 + textWidth))
	if compact then
		checkWidth = math.min(checkWidth, math.max(style.minCarpoolWidth, width - rolesWidth - 20))
	end
	card.CarpoolCheck:SetWidth(checkWidth)
	card.CarpoolCheck.Label:SetScale(math.min(1, (checkWidth - 25) / math.max(1, textWidth)))
	card.CarpoolCheck:ClearAllPoints()
	card.CarpoolCheck:SetPoint("LEFT", card.RoleSection, "LEFT", inset,
		compact and style.compactControlY or ROLE_CONTENT_OFFSET_Y)
	card.RolesAnchor:ClearAllPoints()
	card.RolesAnchor:SetPoint("RIGHT", card.RoleSection, "RIGHT", compact and -style.inset or -ROLE_RIGHT_INSET,
		compact and style.compactControlY or ROLE_CONTENT_OFFSET_Y + ROLE_TOGGLE_GROUP_OFFSET_Y)
	card.RolesAnchor:SetScale(compact and math.max(0.1, math.min(1, (width - checkWidth - 20) / rolesWidth)) or 1)
	card.CrestBar:ClearAllPoints()
	card.CrestBar.compactRow = compact
	card.CrestRoleDivider:ClearAllPoints()
	card.CrestRoleDivider:SetPoint("CENTER", card.RolesAnchor, "LEFT", -style.dividerGap, 0)
	card.CrestRoleDivider:SetShown(not compact and (card.CrestBar.count or 0) > 0)
	if compact then
		card.CrestBar:SetPoint("LEFT", card.RoleSection, "LEFT", style.inset, style.compactCurrencyY)
		card.CrestBar:SetPoint("RIGHT", card.RoleSection, "RIGHT", -style.inset, style.compactCurrencyY)
	else
		card.CrestBar:SetPoint("LEFT", card.CarpoolCheck, "RIGHT", style.inset, 0)
		card.CrestBar:SetPoint("RIGHT", card.CrestRoleDivider, "CENTER", -style.dividerGap, 0)
	end
	GF.MythicPlusCharacterCurrencyBar:Layout(card.CrestBar)
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
	local fallback = option and type(option.name) == "string"
		and option.name ~= "" and option.name or nil
	local locale = GF.Locale
	if locale and type(locale.ResolveSpecializationName) == "function" then
		local name = locale:ResolveSpecializationName(
			option and option.specID,
			fallback
		)
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	if fallback then
		return fallback
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
				or "专精切换失败"
		else
			message = locale.MPLUS_SPECIALIZATION_SWITCH_UNAVAILABLE
				or "当前无法切换专精"
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
							or "当前无法切换专精"
					)
			end
			GameTooltip:AddLine(message, 1, 0.2, 0.2, true)
		end
	end
	GameTooltip:Show()
end

function TalentLoadoutUI.UpdateSpecializationHover(button, hovered)
	if not (button and GF.UI and GF.UI.SetSpecializationIconHovered) then
		return
	end
	local options = button._gfSpecializationVisualOptions
	local style = options and options.ringStyle
	local canHover = style and button._gfSpecializationActive ~= true
		and button.IsVisible and button:IsVisible()
		and button.IsEnabled and button:IsEnabled()
		and button.Icon._gfSpecTransitionActive ~= true
	if not canHover then
		button:SetScript("OnUpdate", nil)
		button._gfSpecializationHoverFade = nil
		GF.UI.SetSpecializationIconHovered(button.Icon, false, options)
		return
	end
	if hovered == nil then
		hovered = button.IsMouseOver and button:IsMouseOver()
	end
	local target = hovered == true and 1 or 0
	local fade = button._gfSpecializationHoverFade
	if not fade then
		fade = { value = 0, target = 0 }
		button._gfSpecializationHoverFade = fade
	end
	if fade.target ~= target then
		fade.from, fade.target, fade.elapsed = fade.value, target, 0
		local duration = target == 1 and style.hoverFadeInDuration
			or style.hoverFadeOutDuration
		fade.duration = duration * math.abs(target - fade.value)
	end
	-- Rebinding resets the ring, so restore the displayed blend without
	-- restarting its clock when the cursor remains over the same button.
	GF.UI.SetSpecializationIconHovered(
		button.Icon, target == 1, options, fade.value)
	button:SetScript("OnUpdate", fade.value ~= target
		and TalentLoadoutUI.AdvanceSpecializationHover or nil)
end

function TalentLoadoutUI.AdvanceSpecializationHover(button, elapsed)
	TalentLoadoutUI.UpdateSpecializationHover(button)
	local fade = button._gfSpecializationHoverFade
	if not fade or fade.value == fade.target then
		return
	end
	fade.elapsed = fade.elapsed + elapsed
	local progress = fade.duration > 0
		and math.min(fade.elapsed / fade.duration, 1) or 1
	local eased = progress * progress * (3 - 2 * progress)
	fade.value = progress == 1 and fade.target
		or fade.from + (fade.target - fade.from) * eased
	GF.UI.SetSpecializationIconHovered(button.Icon, fade.target == 1,
		button._gfSpecializationVisualOptions, fade.value)
	if progress == 1 then
		button:SetScript("OnUpdate", nil)
	end
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

	local divider = GF.ColumnHeaderBar:CreateDivider(
		parent, TalentLoadoutUI.SPEC_DIVIDER_HEIGHT)
	divider:EnableMouse(false)
	GF.ColumnHeaderBar:TintDivider(divider, GF.HEADER_ACCENT_COLOR)
	divider:SetPoint(
		"CENTER",
		dropdown,
		"LEFT",
		-TalentLoadoutUI.SPEC_DIVIDER_DROPDOWN_OFFSET,
		0
	)
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
			TalentLoadoutUI.UpdateSpecializationHover(self, true)
			TalentLoadoutUI.ShowSpecializationTooltip(self)
		end)
		button:SetScript("OnLeave", function(self)
			TalentLoadoutUI.UpdateSpecializationHover(self, false)
			GameTooltip_Hide()
		end)
		button:SetScript("OnShow", function(self)
			TalentLoadoutUI.UpdateSpecializationHover(self)
		end)
		button:SetScript("OnHide", function(self)
			TalentLoadoutUI.UpdateSpecializationHover(self, false)
		end)
		button:SetScript("OnDisable", function(self)
			TalentLoadoutUI.UpdateSpecializationHover(self, false)
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
					ringStyle = GF.TALENT_SPECIALIZATION_RING_STYLE,
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
	-- Binding resets border colors. Restore hover after layout and eligibility
	-- updates even when the stationary cursor produces no new OnEnter event.
	for _, button in ipairs(buttons) do
		TalentLoadoutUI.UpdateSpecializationHover(button)
	end
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
	button.Backdrop = createCharacterControlBackdrop(button)
	local text = createCardText(button, "GameFontHighlight", 11, "")
	text:SetPoint("LEFT", button, "LEFT", 8, 0)
	text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
	text:SetJustifyH("CENTER")
	button.Text = text
	UI.BindKeystoneLinkButton(button)
	button.Backdrop:BindHover()
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

local function createTeleportButton(parent, actionKind)
	actionKind = actionKind == "announce" and "announce" or "teleport"
	local button
	if actionKind == "announce" then
		button = CreateFrame("Button", nil, parent)
	else
		button = CreateFrame(
			"Button",
			nil,
			parent,
			"InsecureActionButtonTemplate"
		)
	end
	button:SetSize(24, 24)
	if actionKind == "announce" then
		button:RegisterForClicks("LeftButtonUp")
	else
		button:RegisterForClicks("AnyUp", "AnyDown")
	end
	button.Backdrop = createCharacterControlBackdrop(button)
	local icon = button:CreateTexture(nil, "OVERLAY")
	GF.UI.SetNativeAtlasSampling(icon, false)
	button.Icon = icon
	button._gfCharacterAction = actionKind
	if actionKind == "announce" then
		-- The 2x event atlas has visible bounds [9,47) x [16,39) in 58x58.
		local iconSize = 18
		local iconOffsetX = (0.5 - 28 / 58) * iconSize
		local iconOffsetY = (27.5 / 58 - 0.5) * iconSize
		button.ApplyAnnouncePressed = function(self, pressed)
			local active = pressed == true
				and self._announceEnabled == true
			self.Icon:ClearAllPoints()
			self.Icon:SetPoint(
				"CENTER",
				self,
				"CENTER",
				iconOffsetX + (active and 1 or 0),
				iconOffsetY + (active and -1 or 0)
			)
			self.Backdrop:SetControlState(active, self._announceEnabled == true)
		end
		if not GF.UI.TrySetAtlas(
			icon,
			GF.MYTHIC_PLUS_KEYSTONE_ANNOUNCE_ATLAS,
			false
		) then
			icon:SetTexture("Interface\\Icons\\INV_Misc_Horn_01")
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			iconOffsetX, iconOffsetY = 0, 0
		end
		icon:SetPoint("CENTER", button, "CENTER", iconOffsetX, iconOffsetY)
		icon:SetSize(iconSize, iconSize)
		button:SetScript("OnMouseDown", function(self, mouseButton)
			if mouseButton == "LeftButton" and self._announceEnabled then
				self:ApplyAnnouncePressed(true)
			end
		end)
		button:SetScript("OnMouseUp", function(self)
			self:ApplyAnnouncePressed(false)
		end)
		button:SetScript("OnClick", function(self)
			if not self._announceEnabled then
				return
			end
			local service = GF.MythicPlusAnnouncementService
			if service and service.BroadcastWarbandKeystone then
				service:BroadcastWarbandKeystone(self._announceData)
			end
		end)
		button:SetScript("OnEnter", function(self)
			local locale = GF.L or {}
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(
				locale.MPLUS_WARBAND_KEYSTONE_ANNOUNCE
					or "通报钥石",
				1,
				0.82,
				0
			)
			GameTooltip:AddLine(
				self._announceEnabled
					and (locale.MPLUS_WARBAND_KEYSTONE_ANNOUNCE_HINT
						or "点击在队伍频道通报该角色的钥石。")
					or (locale.MPLUS_WARBAND_KEYSTONE_ANNOUNCE_EMPTY
						or "该战团角色没有钥石。"),
				1,
				1,
				1,
				true
			)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function(self)
			self:ApplyAnnouncePressed(false)
			GameTooltip_Hide()
		end)
		button.Backdrop:BindHover()
		return button
	end
	GF.UI.TrySetAtlas(icon, GF.MYTHIC_PLUS_TELEPORT_ICON_ATLAS, false)
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
	button.Backdrop:BindHover()
	return button
end

local function setTeleportVisual(button, data)
	if button._gfCharacterAction == "announce" then
		local hasKeystone = type(data and data.keystoneLink) == "string"
			and data.keystoneLink ~= ""
		button._announceData = data
		button._announceEnabled = hasKeystone == true
		button:SetEnabled(hasKeystone == true)
		button:SetAlpha(1)
		button:ApplyAnnouncePressed(false)
		if button.Icon.SetDesaturated then
			button.Icon:SetDesaturated(not hasKeystone)
		end
		if hasKeystone then
			button.Icon:SetVertexColor(1, 1, 1, 1)
		else
			button.Icon:SetVertexColor(0.52, 0.52, 0.52, 1)
		end
		return
	end
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

local function getCardTopLeftInset(card)
	if card.isCurrent then
		return math.max(CONTROL_INSET_X, MODEL_TEXT_INSET_X - CONTENT_INSET_X)
	end
	return CharacterPage.WARBAND_CLASS_PORTRAIT_SIZE
		+ CharacterPage.WARBAND_CLASS_PORTRAIT_GAP
end

local function layoutRoleAtlas(card)
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
		-(card.VaultRightInset or 0),
		ROLE_ATLAS_HEIGHT + ROLE_ATLAS_OFFSET_Y
	)
	card.RoleBackgroundClip:SetHeight(ROLE_ATLAS_VISIBLE_HEIGHT)

	card.RoleBackgroundArt:ClearAllPoints()
	card.RoleBackgroundArt:SetPoint(
		"TOPLEFT",
		card.RoleBackgroundClip,
		"TOPLEFT",
		0,
		0
	)
	card.RoleBackgroundArt:SetPoint(
		"TOPRIGHT",
		card.RoleBackgroundClip,
		"TOPRIGHT",
		0,
		0
	)
	card.RoleBackgroundArt:SetHeight(ROLE_ATLAS_HEIGHT)
	layoutStretchLayer(card.RoleBackground)
end

local function createCharacterCard(parent, isCurrent)
	local frameType = isCurrent and "Button" or "Frame"
	local template = isCurrent
		and "BackdropTemplate,InsecureActionButtonTemplate"
		or "BackdropTemplate"
	local card = CreateFrame(frameType, nil, parent, template)
	card:SetHeight(CARD_HEIGHT)
	card.isCurrent = isCurrent
	card.VaultRightInset = not isCurrent
		and GF.MythicPlusCharacterVaultGrid.RIGHT_INSET or 0
	if isCurrent then
		card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		card:SetAttribute("useOnKeyDown", false)
		card:SetScript("PreClick", function(self, mouseButton)
			if GF.BlacklistMenu
				and GF.BlacklistMenu.HandleCurrentCharacterContextMenuClick
			then
				GF.BlacklistMenu:HandleCurrentCharacterContextMenuClick(
					self._gfData,
					self,
					mouseButton)
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
	topSection:SetPoint("TOPRIGHT", card, "TOPRIGHT",
		-CONTENT_INSET_X - card.VaultRightInset, -CONTENT_INSET_TOP)
	topSection:SetHeight(TOP_SECTION_HEIGHT)
	card.TopSection = topSection

	local topBg = topSection:CreateTexture(nil, "BACKGROUND", nil, -1)
	topBg:SetAllPoints(topSection)
	topBg:SetColorTexture(0, 0, 0, 0)
	if not isCurrent then
		local portrait = CreateFrame("Frame", nil, topSection)
		portrait:SetSize(
			CharacterPage.WARBAND_CLASS_PORTRAIT_SIZE,
			CharacterPage.WARBAND_CLASS_PORTRAIT_SIZE
		)
		portrait:SetPoint("LEFT", topSection, "LEFT", 0, 0)
		portrait:SetFrameLevel((topSection:GetFrameLevel() or 0) + 4)

		-- Native spellbook art: 52x48 border around a 36x36 icon. The
		-- left/bottom ornament shifts the icon center by (+5, +3).
		local portraitScale = CharacterPage.WARBAND_CLASS_PORTRAIT_SIZE / 48
		local icon = portrait:CreateTexture(nil, "ARTWORK")
		icon:SetSize(36 * portraitScale, 36 * portraitScale)
		icon:SetPoint("CENTER", portrait, "CENTER", 5 * portraitScale, 3 * portraitScale)
		portrait.Icon = icon

		local mask = portrait:CreateMaskTexture()
		mask:SetTexture(
			CharacterPage.WARBAND_CLASS_PORTRAIT_MASK,
			"CLAMPTOBLACKADDITIVE",
			"CLAMPTOBLACKADDITIVE"
		)
		mask:SetAllPoints(icon)
		icon:AddMaskTexture(mask)
		portrait.Mask = mask

		local border = portrait:CreateTexture(nil, "OVERLAY")
		if GF.UI.TrySetAtlas(border, "spellbook-item-iconframe", false) then
			border:SetSize(52 * portraitScale, 48 * portraitScale)
			border:SetPoint("CENTER", portrait, "CENTER", 0, 0)
		else
			border:SetTexture("Interface\\Common\\WhiteIconFrame")
			border:SetAllPoints(icon)
		end
		if border.SetDesaturated then
			border:SetDesaturated(false)
		end
		border:SetBlendMode("BLEND")
		border:SetVertexColor(1, 1, 1, 1)
		portrait.Border = border
		function portrait:SetClass(classFile)
			local iconInfo = GF.UI.ResolveClassIcon
				and GF.UI.ResolveClassIcon(classFile)
			local applied = iconInfo
				and iconInfo.atlas
				and GF.UI.TrySetAtlas(self.Icon, iconInfo.atlas, false)
			if applied then
				self.Icon:SetTexCoord(0, 1, 0, 1)
			elseif iconInfo and iconInfo.texture then
				self.Icon:SetTexture(iconInfo.texture)
				local coords = iconInfo.texCoords
				if type(coords) == "table" then
					self.Icon:SetTexCoord(
						coords[1], coords[2], coords[3], coords[4]
					)
				else
					self.Icon:SetTexCoord(0, 1, 0, 1)
				end
			else
				self.Icon:SetTexture(
					"Interface\\Icons\\INV_Misc_QuestionMark"
				)
				self.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			end
		end
		card.ClassPortrait = portrait
	end

	local leftInset = getCardTopLeftInset(card)
	local rightOffset = CONTENT_INSET_X - CONTROL_RIGHT_INSET
	local name = createCardText(topSection, "GameFontNormal", 13, "OUTLINE")
	name:SetPoint("TOPLEFT", topSection, "TOPLEFT", leftInset, TOP_LABEL_Y)
	name:SetJustifyH("LEFT")
	if not isCurrent then name:SetWordWrap(false) end
	card.Name = name

	local armor = createCardText(topSection, "GameFontHighlight", 11, "")
	armor:SetPoint("TOPRIGHT", topSection, "TOPRIGHT", rightOffset, TOP_LABEL_Y)
	armor:SetWidth(isCurrent and 120 or 44)
	if not isCurrent then armor:SetWordWrap(false) end
	armor:SetJustifyH("RIGHT")
	armor:SetTextColor(0.86, 0.86, 0.86, 0.92)
	card.Armor = armor

	local rating = createCardText(topSection, "GameFontHighlight", 13, "OUTLINE")
	rating:SetPoint("LEFT", name, "RIGHT", 6, 0)
	rating:SetPoint("RIGHT", armor, "LEFT", -8, 0)
	rating:SetJustifyH("LEFT")
	card.Rating = rating

	local teleport = createTeleportButton(
		topSection,
		isCurrent and "teleport" or "announce"
	)
	teleport:SetPoint("BOTTOMRIGHT", topSection, "BOTTOMRIGHT", rightOffset + 2, INFO_ROW_Y)
	card.TeleportButton = teleport

	local keyButton = createKeyButton(topSection)
	keyButton:SetPoint("BOTTOMLEFT", topSection, "BOTTOMLEFT", leftInset, INFO_ROW_Y)
	keyButton:SetPoint("RIGHT", teleport, "LEFT", -10, 0)
	card.KeyButton = keyButton
	card.KeyText = keyButton.Text

	local roleSection = CreateFrame("Frame", nil, card)
	roleSection:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, ROLE_SECTION_OFFSET_Y)
	roleSection:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT",
		-card.VaultRightInset, ROLE_SECTION_OFFSET_Y)
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

	card.RoleBackground = createStretchLayer(
		roleBackgroundArt,
		ROLE_BAR_ATLAS,
		"BACKGROUND",
		-1,
		{ sourceCapRatio = LABEL_SOURCE_CAP_RATIO }
	)

	local rowOffsetY = ROLE_CONTENT_OFFSET_Y
	local bottomLeftInset = CONTENT_INSET_X
		+ (isCurrent and getCardTopLeftInset(card) or 0)
	if isCurrent then
		local prompt = createCardText(roleSection, "GameFontHighlight", 12, "")
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
			GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE.carpoolWidth,
			ROLE_CARPOOL_CHECK_OFFSET_Y
		)
		carpool:SetPoint("LEFT", roleSection, "LEFT", bottomLeftInset, rowOffsetY)
		carpool:SetScript("OnClick", function(self)
			local data = card._gfData
			local function applyChanged(enabled)
				self._cachedChecked = enabled
				self:SetChecked(enabled)
				syncCharacterCheckVisual(self, true)
				if card._gfOnCarpoolChanged then
					card._gfOnCarpoolChanged(card, data, enabled)
				end
			end
			if data and (data.isDebugTest or data.isTest)
				and GF.MythicPlusDebugService
				and GF.MythicPlusDebugService.SetLocalCarpoolEnabled
			then
				local enabled = self:GetChecked() == true
				if GF.MythicPlusDebugService:SetLocalCarpoolEnabled(data.key, enabled) then
					applyChanged(enabled)
					return
				end
			elseif data and data.key and GF.MythicPlusCharacterStore
				and GF.MythicPlusCharacterStore.SetCarpoolEnabled
			then
				local enabled = self:GetChecked() == true
				if GF.MythicPlusCharacterStore:SetCarpoolEnabled(data.key, enabled) then
					applyChanged(enabled)
					return
				end
			end
			self:SetChecked(self._cachedChecked == true)
		end)
		card.CarpoolCheck = carpool
	end

	if isCurrent then
		local dropdown = GF.UI.CreateDropdownButton(roleSection)
		keepCardFontSize(
			dropdown and dropdown.Text,
			dropdown and dropdown.Text and dropdown.Text._gfFontTemplate
				or "GameFontHighlightSmall"
		)
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
		rolesAnchor:SetSize((ROLE_TOGGLE_WIDTH * 3) + (ROLE_TOGGLE_GAP * 2),
			ROLE_TOGGLE_HEIGHT)
		card.RolesAnchor = rolesAnchor
		card.CrestBar = GF.MythicPlusCharacterCurrencyBar:Create(roleSection, createCardText)
		local divider = GF.ColumnHeaderBar:CreateDivider(roleSection,
			GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE.dividerHeight)
		divider:EnableMouse(false)
		GF.ColumnHeaderBar:TintDivider(divider, GF.MYTHIC_PLUS_CHARACTER_BORDER_COLOR)
		divider:Hide()
		card.CrestRoleDivider = divider
		local currencyInset = GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE.inset
		card.CrestBar:SetPoint("LEFT", card.CarpoolCheck, "RIGHT", currencyInset, 0)
		card.CrestBar:SetPoint("RIGHT", rolesAnchor, "LEFT", -currencyInset, 0)
		card.RoleToggles = {}
		local previous
		for _, roleKey in ipairs(ROLE_ORDER) do
			local toggle = createRoleIconButton(rolesAnchor, roleKey)
			toggle.OwnerCard = card
			if previous then
				toggle:SetPoint("LEFT", previous, "RIGHT", ROLE_TOGGLE_GAP, 0)
			else
				toggle:SetPoint("LEFT", rolesAnchor, "LEFT")
			end
			card.RoleToggles[roleKey] = toggle
			previous = toggle
		end
		roleSection:HookScript("OnSizeChanged", function() layoutCharacterFooter(card) end)
	end

	if isCurrent then
		card.PlayerModel = CharacterPage:CreatePlayerModel(card)
	else
		card.VaultGrid = GF.MythicPlusCharacterVaultGrid:Create(card, createCardText)
		topSection:HookScript("OnSizeChanged", function()
			GF.MythicPlusCharacterVaultGrid:LayoutCard(card)
		end)
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
	if card.ClassPortrait then
		card.ClassPortrait:SetClass(classFile)
	end
	if card.isCurrent and card._gfMythicCharacterHover then
		setLayerColor(card._gfMythicCharacterHover.base, 1, 1, 1, 1)
		setLayerColor(card._gfMythicCharacterHover.glow, 1, 1, 1, 1)
	else
		tintRaisedHover(card, classFile)
	end
	card.Name:SetText(UI.GetCharacterFullName(data))
	card.Name:SetTextColor(r, g, b, 1)
	if card.VaultGrid then
		GF.MythicPlusCharacterVaultGrid:Bind(card.VaultGrid, data)
		GF.MythicPlusCharacterVaultGrid:LayoutCard(card)
	end

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
		card.CarpoolCheck.Label:SetText((GF.L and GF.L.MPLUS_CARPOOL_ADD) or "加入车队")
		card.CarpoolCheck._cachedChecked = data.carpoolEnabled == true
		card.CarpoolCheck:SetChecked(card.CarpoolCheck._cachedChecked)
	end

	if card.CrestBar then
		GF.MythicPlusCharacterCurrencyBar:Bind(card.CrestBar, data)
		layoutCharacterFooter(card)
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

function UI.GetVaultRewardTier(itemLevel)
	itemLevel = tonumber(itemLevel)
	if itemLevel and itemLevel > 0 then
		if itemLevel >= 337 and itemLevel <= 344 then
			return "ascended"
		end
		if itemLevel >= 318 and itemLevel <= 334 then
			return "myth"
		end
		if itemLevel >= 305 and itemLevel <= 315 then
			return "hero"
		end
		if itemLevel >= 292 and itemLevel <= 302 then
			return "champion"
		end
		if itemLevel >= 272 and itemLevel <= 289 then
			return "veteran"
		end
		return "random"
	end
	return "random"
end

local function getVaultRewardLabel(itemLevel)
	local tier = UI.GetVaultRewardTier(itemLevel)
	if tier == "ascended" then
		return (GF.L and GF.L.MPLUS_REWARD_ASCENDED) or "晋升"
	end
	if tier == "myth" then
		return (GF.L and GF.L.MPLUS_REWARD_MYTH) or "神话"
	end
	if tier == "hero" then
		return (GF.L and GF.L.MPLUS_REWARD_HERO) or "英雄"
	end
	if tier == "champion" then
		return (GF.L and GF.L.MPLUS_REWARD_CHAMPION) or "勇士"
	end
	if tier == "veteran" then
		return (GF.L and GF.L.MPLUS_REWARD_VETERAN) or "老兵"
	end
	return (GF.L and GF.L.MPLUS_REWARD_RANDOM) or "随机"
end

local function getVaultRewardColor(itemLevel)
	local tier = UI.GetVaultRewardTier(itemLevel)
	if tier == "ascended" then
		return WEEKLY_REWARD_COLORS.ascended
	end
	if tier == "myth" then
		return WEEKLY_REWARD_COLORS.myth
	end
	if tier == "hero" then
		return WEEKLY_REWARD_COLORS.hero
	end
	if tier == "champion" then
		return WEEKLY_REWARD_COLORS.champion
	end
	if tier == "veteran" then
		return WEEKLY_REWARD_COLORS.veteran
	end
	return WEEKLY_REWARD_COLORS.random
end

local function getVaultRewardRGB(itemLevel)
	local tier = UI.GetVaultRewardTier(itemLevel)
	if tier == "ascended" then
		return 1.00, 0.50, 0.00
	end
	if tier == "myth" then
		return 1.00, 0.82, 0.00
	end
	if tier == "hero" then
		return 0.72, 0.32, 1.00
	end
	if tier == "champion" then
		return 0.00, 0.44, 0.87
	end
	if tier == "veteran" then
		return 0.12, 1.00, 0.12
	end
	return 1.00, 1.00, 1.00
end

local function getVaultThresholdLabel(threshold)
	threshold = tonumber(threshold) or 0
	if threshold == 1 then
		return (GF.L and GF.L.MPLUS_VAULT_FIRST) or "单本奖励"
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
	return UI.ColorText(tostring(tonumber(run.level) or 0),
		run.timed == true and "ff00ff00" or "ffff4040")
end

local function formatWeeklyRewardItemLevel(itemLevel)
	local label = getVaultRewardLabel(itemLevel)
	itemLevel = tonumber(itemLevel)
	local value = itemLevel and itemLevel > 0
		and tostring(math.floor(itemLevel + 0.5))
		or "-"
	return string.format(
		(GF.L and GF.L.MPLUS_REWARD_TIER_FORMAT) or "%s：%s",
		label,
		value)
end

local function formatWeeklyTooltipReward(reward)
	if type(reward) ~= "table" then
		return UI.ColorText((GF.L and GF.L.MPLUS_INCOMPLETE) or "未完成",
			WEEKLY_REWARD_COLORS.muted)
	end
	local threshold = tonumber(reward.threshold) or 0
	local progress = tonumber(reward.progress) or 0
	if threshold <= 0 or progress < threshold then
		return UI.ColorText((GF.L and GF.L.MPLUS_INCOMPLETE) or "未完成",
			WEEKLY_REWARD_COLORS.muted)
	end
	return UI.ColorText(
		formatWeeklyRewardItemLevel(reward.itemLevel),
		getVaultRewardColor(reward.itemLevel))
end

local function setWeeklyTextureDesaturated(texture, desaturated)
	if texture and texture.SetDesaturated then
		texture:SetDesaturated(desaturated == true)
	end
end

local function createWeeklyVaultEffectAnimation(texture)
	if not (texture and texture.CreateAnimationGroup) then
		return nil
	end
	local animation = texture:CreateAnimationGroup()
	if not (animation and animation.CreateAnimation) then
		return nil
	end
	animation:SetLooping("REPEAT")
	local rotation = animation:CreateAnimation("Rotation")
	if not rotation then
		return nil
	end
	rotation:SetDegrees(-360)
	rotation:SetDuration(10)
	rotation:SetOrder(1)
	animation:Play()
	return animation
end

local function initializeWeeklyRewardEffect(block)
	local function initialize()
		local modelScene = block and block.ModelScene
		if not (modelScene
			and modelScene.RefreshModelScene
			and modelScene.ClearEffects
			and modelScene.AddDynamicEffect) then
			return
		end
		local ok, effect = pcall(function()
			modelScene:RefreshModelScene()
			modelScene:ClearEffects()
			return modelScene:AddDynamicEffect({
				effectID = WEEKLY_REWARD_EFFECT_ID,
			}, block.EffectAnchor, nil, nil, nil,
				WEEKLY_REWARD_EFFECT_SCALE)
		end)
		if ok and effect then
			block.Effect = effect
			block.ModelEffectReady = true
			modelScene:SetShown(block._rewardCompleted == true)
			block.FallbackEffect:Hide()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, initialize)
	else
		initialize()
	end
end

local function getNativeWeeklyRewardActivity(threshold)
	local activityType = Enum and Enum.WeeklyRewardChestThresholdType
		and Enum.WeeklyRewardChestThresholdType.Activities
	local reader = C_WeeklyRewards and C_WeeklyRewards.GetActivities
	if activityType == nil or type(reader) ~= "function" then
		return nil
	end
	local ok, activities = pcall(reader, activityType)
	if not (ok and type(activities) == "table") then
		return nil
	end
	for _, activityInfo in ipairs(activities) do
		local numberOK, activityThreshold = pcall(
			tonumber,
			activityInfo and activityInfo.threshold)
		if numberOK and activityThreshold == threshold then
			return activityInfo
		end
	end
	return nil
end

local function loadNativeWeeklyRewardTooltipMixin()
	if type(WeeklyRewardsActivityMixin) == "table" then
		return WeeklyRewardsActivityMixin
	end
	if type(WeeklyRewards_LoadUI) == "function" then
		pcall(WeeklyRewards_LoadUI)
	elseif C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
		pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
	end
	return type(WeeklyRewardsActivityMixin) == "table"
		and WeeklyRewardsActivityMixin or nil
end

local function showWeeklyRewardFallbackTooltip(block)
	if not (block and GameTooltip) then
		return
	end
	GameTooltip:SetOwner(block, "ANCHOR_RIGHT", -7, -11)
	GameTooltip:ClearLines()
	GameTooltip:AddLine(WEEKLY_REWARDS_CURRENT_REWARD or "当前奖励", 1, 1, 1)
	local reward = block.Reward
	if block._rewardCompleted then
		local itemLevel = reward and reward.itemLevel
		local r, g, b = getVaultRewardRGB(itemLevel)
		GameTooltip:AddLine(
			formatWeeklyRewardItemLevel(itemLevel),
			r, g, b)
	else
		GameTooltip:AddLine(
			(GF.L and GF.L.MPLUS_INCOMPLETE) or "未完成",
			0.52, 0.52, 0.52)
	end
	GameTooltip:Show()
end

local function showNativeWeeklyRewardTooltip(block)
	local nativeMixin = loadNativeWeeklyRewardTooltipMixin()
	local activityInfo = getNativeWeeklyRewardActivity(
		block and block.Threshold)
	if not (block and nativeMixin and activityInfo
		and type(nativeMixin.OnEnter) == "function"
		and type(Mixin) == "function") then
		showWeeklyRewardFallbackTooltip(block)
		return
	end
	if block._nativeWeeklyRewardMixin ~= nativeMixin then
		Mixin(block, nativeMixin)
		block._nativeWeeklyRewardMixin = nativeMixin
	end
	block.info = activityInfo
	local threshold = tonumber(activityInfo.threshold) or 0
	local progress = tonumber(activityInfo.progress) or 0
	block.unlocked = threshold > 0 and progress >= threshold
	block.hasRewards = type(activityInfo.rewards) == "table"
		and #activityInfo.rewards > 0
	local ok = pcall(nativeMixin.OnEnter, block)
	if not ok then
		showWeeklyRewardFallbackTooltip(block)
	end
end

local function hideWeeklyRewardTooltip(block)
	if block then
		block.UpdateTooltip = nil
	end
	if GameTooltip and GameTooltip.GetOwner
		and GameTooltip:GetOwner() == block
	then
		GameTooltip:Hide()
	end
end

local function createWeeklyRewardBlock(parent, threshold)
	local block = CreateFrame("Frame", nil, parent)
	block:SetHeight(WEEKLY_REWARD_BLOCK_HEIGHT)
	block:SetFrameLevel((parent:GetFrameLevel() or 0) + 2)
	block:EnableMouse(true)
	block.Threshold = threshold
	block:SetScript("OnEnter", showNativeWeeklyRewardTooltip)
	block:SetScript("OnLeave", hideWeeklyRewardTooltip)

	local background = block:CreateTexture(nil, "BACKGROUND", nil, 0)
	background:SetAllPoints(block)
	if not GF.UI.TrySetAtlas(background, WEEKLY_REWARD_BLOCK_ATLAS, false) then
		background:SetColorTexture(0.055, 0.045, 0.028, 0.96)
	end
	block.Background = background

	local iconFrame = CreateFrame("Frame", nil, block)
	iconFrame:SetPoint("LEFT", block, "LEFT", WEEKLY_REWARD_ICON_INSET_X, 0)
	iconFrame:SetSize(WEEKLY_REWARD_ICON_SIZE, WEEKLY_REWARD_ICON_SIZE)
	iconFrame:SetFrameLevel(block:GetFrameLevel() + 1)
	block.IconFrame = iconFrame
	local effectAnchor = CreateFrame("Frame", nil, iconFrame)
	effectAnchor:SetPoint("CENTER", iconFrame, "CENTER",
		WEEKLY_REWARD_EFFECT_OFFSET_X,
		WEEKLY_REWARD_EFFECT_OFFSET_Y)
	effectAnchor:SetSize(1, 1)
	effectAnchor:EnableMouse(false)
	block.EffectAnchor = effectAnchor

	local iconBackground = iconFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
	iconBackground:SetAllPoints(iconFrame)
	if not GF.UI.TrySetAtlas(
		iconBackground,
		WEEKLY_REWARD_ICON_BACKGROUND_ATLAS,
		false
	) then
		iconBackground:SetColorTexture(0.08, 0.07, 0.06, 1)
	end
	block.IconBackground = iconBackground

	local disabledCenter = iconFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	disabledCenter:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
	disabledCenter:SetSize(30, 30)
	if not GF.UI.TrySetAtlas(
		disabledCenter,
		WEEKLY_REWARD_DISABLED_CENTER_ATLAS,
		false
	) then
		disabledCenter:SetTexture(GF.WHITE_TEXTURE)
		disabledCenter:SetVertexColor(0.34, 0.34, 0.34, 1)
	end
	block.DisabledCenter = disabledCenter

	local fallbackEffect = iconFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	fallbackEffect:SetPoint("CENTER", iconFrame, "CENTER", 0, 1)
	fallbackEffect:SetSize(34, 34)
	fallbackEffect:SetBlendMode("ADD")
	if not GF.UI.TrySetAtlas(
		fallbackEffect,
		WEEKLY_REWARD_EFFECT_ATLAS,
		false
	) then
		fallbackEffect:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
		fallbackEffect:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	block.FallbackEffect = fallbackEffect
	block.FallbackEffectAnimation = createWeeklyVaultEffectAnimation(fallbackEffect)
	fallbackEffect:Hide()

	local modelScene
	local modelSceneCreated, createdModelScene = pcall(
		CreateFrame,
		"ModelScene",
		nil,
		iconFrame,
		"ScriptAnimatedModelSceneTemplate")
	if modelSceneCreated then
		modelScene = createdModelScene
		modelScene:SetAllPoints(iconFrame)
		modelScene:SetFrameLevel(iconFrame:GetFrameLevel() + 1)
		modelScene:EnableMouse(false)
		modelScene:Hide()
		block.ModelScene = modelScene
	end

	local iconOverlay = iconFrame:CreateTexture(nil, "OVERLAY", nil, 2)
	iconOverlay:SetAllPoints(iconFrame)
	if not GF.UI.TrySetAtlas(
		iconOverlay,
		WEEKLY_REWARD_ICON_OVERLAY_ATLAS,
		false
	) then
		iconOverlay:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	end
	block.IconOverlay = iconOverlay

	local title = createCardText(block, "GameFontNormalSmall", 12, "OUTLINE")
	title:SetPoint("TOPLEFT", block, "TOPLEFT",
		WEEKLY_REWARD_CONTENT_LEFT, -7)
	title:SetPoint("TOPRIGHT", block, "TOPRIGHT", -42, -7)
	title:SetHeight(16)
	title:SetJustifyH("LEFT")
	title:SetJustifyV("MIDDLE")
	title:SetWordWrap(false)
	title:SetTextColor(1, 0.82, 0, 1)
	block.Title = title

	local divider = block:CreateTexture(nil, "ARTWORK", nil, 0)
	divider:SetPoint("TOPLEFT", block, "TOPLEFT",
		WEEKLY_REWARD_CONTENT_LEFT, -24)
	divider:SetPoint("TOPRIGHT", block, "TOPRIGHT",
		-WEEKLY_REWARD_CONTENT_RIGHT, -24)
	divider:SetHeight(1)
	if not GF.UI.TrySetAtlas(divider, WEEKLY_REWARD_DIVIDER_ATLAS, false) then
		divider:SetColorTexture(0.85, 0.60, 0.08, 0.34)
	end
	block.Divider = divider

	local rewardRow = CreateFrame("Frame", nil, block)
	rewardRow:SetPoint("BOTTOMLEFT", block, "BOTTOMLEFT",
		WEEKLY_REWARD_CONTENT_LEFT, 14)
	rewardRow:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT",
		-WEEKLY_REWARD_CONTENT_RIGHT, 14)
	rewardRow:SetHeight(16)
	rewardRow:EnableMouse(false)
	block.RewardRow = rewardRow

	local arrow = block:CreateTexture(nil, "ARTWORK", nil, 1)
	arrow:SetPoint("LEFT", rewardRow, "LEFT",
		WEEKLY_REWARD_LABEL_WIDTH + WEEKLY_REWARD_DETAIL_GAP, 0)
	arrow:SetSize(10, 8)
	if not GF.UI.TrySetAtlas(arrow, WEEKLY_REWARD_ARROW_ATLAS, false) then
		arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
		arrow:SetTexCoord(0.18, 0.82, 0.18, 0.82)
	end
	block.Arrow = arrow

	local tier = createCardText(block, "GameFontHighlightSmall", 12, "OUTLINE")
	tier:SetPoint("LEFT", rewardRow, "LEFT", 0, 0)
	tier:SetWidth(WEEKLY_REWARD_LABEL_WIDTH)
	tier:SetHeight(16)
	tier:SetJustifyH("LEFT")
	tier:SetJustifyV("MIDDLE")
	tier:SetWordWrap(false)
	block.Tier = tier

	local rewardValue = createCardText(block, "GameFontHighlightSmall", 12, "OUTLINE")
	rewardValue:SetPoint("LEFT", arrow, "RIGHT",
		WEEKLY_REWARD_DETAIL_GAP, 0)
	rewardValue:SetPoint("RIGHT", rewardRow, "RIGHT", 0, 0)
	rewardValue:SetHeight(16)
	rewardValue:SetJustifyH("LEFT")
	rewardValue:SetJustifyV("MIDDLE")
	rewardValue:SetWordWrap(false)
	block.RewardValue = rewardValue

	local flag = block:CreateTexture(nil, "OVERLAY", nil, 3)
	flag:SetPoint("TOPRIGHT", block, "TOPRIGHT", -4, 1)
	flag:SetSize(WEEKLY_REWARD_FLAG_WIDTH, WEEKLY_REWARD_FLAG_HEIGHT)
	if not GF.UI.TrySetAtlas(flag, WEEKLY_REWARD_FLAG_ATLAS, false) then
		flag:SetTexture(GF.WHITE_TEXTURE)
		flag:SetVertexColor(0.10, 0.42, 0.06, 0.96)
	end
	flag:Hide()
	block.Flag = flag

	local checkmark = block:CreateTexture(nil, "OVERLAY", nil, 4)
	checkmark:SetPoint("CENTER", flag, "CENTER", -1, 4)
	checkmark:SetSize(14, 14)
	if not GF.UI.TrySetAtlas(
		checkmark,
		WEEKLY_REWARD_COMPLETE_ATLAS,
		false
	) then
		checkmark:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
		checkmark:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	checkmark:Hide()
	block.Checkmark = checkmark

	local flagProgress = createCardText(block, "GameFontHighlightSmall", 8, "OUTLINE")
	flagProgress:SetPoint("CENTER", flag, "CENTER", -1, 4)
	flagProgress:SetSize(24, 11)
	flagProgress:SetJustifyH("CENTER")
	flagProgress:SetJustifyV("MIDDLE")
	flagProgress:SetTextColor(1, 1, 1, 1)
	flagProgress:Hide()
	block.FlagProgress = flagProgress

	initializeWeeklyRewardEffect(block)
	return block
end

local function fitWeeklyRewardLine(block, blockWidth)
	if not (block and GF.Font and GF.Font.SetFitWidth) then
		return
	end
	local contentWidth = math.max(1,
		(tonumber(blockWidth) or block:GetWidth() or 0)
			- WEEKLY_REWARD_CONTENT_LEFT
			- WEEKLY_REWARD_CONTENT_RIGHT)
	local valueWidth = math.max(1,
		contentWidth
			- WEEKLY_REWARD_LABEL_WIDTH
			- 10
			- (WEEKLY_REWARD_DETAIL_GAP * 2))
	GF.Font.SetFitWidth(block.Tier, WEEKLY_REWARD_LABEL_WIDTH, 9)
	GF.Font.SetFitWidth(block.RewardValue, valueWidth, 9)
end

local function layoutWeeklyRewardBlocks(card)
	local blocks = card and card.RewardBlocks
	if not blocks then
		return
	end
	local innerWidth = math.max(3,
		(card:GetWidth() or 0) - (WEEKLY_REWARD_BLOCK_INSET_X * 2))
	local availableWidth = math.max(3,
		innerWidth - (WEEKLY_REWARD_BLOCK_GAP * (#blocks - 1)))
	local blockWidth = math.floor(availableWidth / #blocks)
	local xOffset = WEEKLY_REWARD_BLOCK_INSET_X
	for index, block in ipairs(blocks) do
		local width = index == #blocks
			and (availableWidth - (blockWidth * (#blocks - 1)))
			or blockWidth
		block:ClearAllPoints()
		block:SetPoint("TOPLEFT", card, "TOPLEFT", xOffset, WEEKLY_REWARD_BLOCK_Y)
		block:SetSize(math.max(1, width), WEEKLY_REWARD_BLOCK_HEIGHT)
		xOffset = xOffset + width + WEEKLY_REWARD_BLOCK_GAP
		fitWeeklyRewardLine(block, width)
	end
end

local function bindWeeklyRewardBlock(block, reward, vaultProgress, available)
	local threshold = tonumber(block and block.Threshold) or 0
	local nativeProgress = tonumber(reward and reward.progress)
	local progress = available
		and math.min(nativeProgress or vaultProgress, threshold)
		or 0
	local completed = available and threshold > 0 and progress >= threshold
	local itemLevel = reward and reward.itemLevel
	local r, g, b = getVaultRewardRGB(itemLevel)

	block.Title:SetText(getVaultThresholdLabel(threshold))
	block.Title:SetTextColor(
		available and 1 or 0.52,
		available and 0.82 or 0.52,
		available and 0 or 0.52,
		available and 1 or 0.55)
	block.Tier:SetText((GF.L and GF.L.MPLUS_REWARD_VAULT_REWARD) or "奖励")
	block.Tier:SetTextColor(
		available and 1 or 0.52,
		available and 0.82 or 0.52,
		available and 0 or 0.52,
		available and 1 or 0.45)
	block.RewardValue:SetText(completed
		and formatWeeklyRewardItemLevel(itemLevel)
		or ((GF.L and GF.L.MPLUS_INCOMPLETE) or "未完成"))
	if completed then
		block.RewardValue:SetTextColor(r, g, b, 1)
	else
		block.RewardValue:SetTextColor(0.52, 0.52, 0.52, 1)
	end
	fitWeeklyRewardLine(block)
	block.Arrow:Show()
	block.Arrow:SetAlpha(completed and 1 or 0.55)
	block.Background:SetAlpha(available and 0.96 or 0.40)
	block.Divider:SetAlpha(available and 0.64 or 0.24)

	setWeeklyTextureDesaturated(block.IconBackground, false)
	setWeeklyTextureDesaturated(block.IconOverlay, false)
	setWeeklyTextureDesaturated(block.FallbackEffect, false)
	block._rewardCompleted = completed
	block.Reward = reward
	block.DisabledCenter:SetShown(not completed)
	local showModelEffect = completed and block.ModelEffectReady == true
	block.FallbackEffect:SetShown(completed and not showModelEffect)
	block.FallbackEffect:SetAlpha(0.94)
	if block.ModelScene then
		if block.ModelScene.SetDesaturation then
			block.ModelScene:SetDesaturation(0)
		end
		block.ModelScene:SetAlpha(1)
		block.ModelScene:SetShown(showModelEffect)
	end

	local showFlag = available and progress > 0
	block.Flag:SetShown(showFlag)
	block.Checkmark:SetShown(showFlag and completed)
	block.FlagProgress:SetShown(showFlag and not completed)
	if showFlag and not completed then
		block.FlagProgress:SetText(string.format("%d/%d", progress, threshold))
	end
end

local function bindWeeklyRewardBlocks(card, snapshot, vaultProgress, available)
	local rewardsByThreshold = {}
	for _, reward in ipairs(available and snapshot.rewards or {}) do
		local threshold = tonumber(reward and reward.threshold)
		if threshold then
			rewardsByThreshold[threshold] = reward
		end
	end
	for _, block in ipairs(card.RewardBlocks or {}) do
		bindWeeklyRewardBlock(
			block,
			rewardsByThreshold[block.Threshold],
			vaultProgress,
			available)
	end
end

local function measureWeeklyCountTextWidth(fontString)
	local measure = fontString
		and (fontString.GetUnboundedStringWidth or fontString.GetStringWidth)
	if type(measure) ~= "function" then
		return nil
	end
	local ok, rawWidth = pcall(measure, fontString)
	if not ok then
		return nil
	end
	local numberOK, width = pcall(tonumber, rawWidth)
	return numberOK and width or nil
end

local function layoutWeeklyCountGroup(card)
	if not (card and card.CountGroup and card.Count) then
		return
	end
	local maximumTextWidth = math.max(1,
		WEEKLY_COUNT_WIDTH
			- WEEKLY_COUNT_CLOCK_SIZE
			- WEEKLY_COUNT_ICON_TEXT_GAP
			- 16)
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(card.Count, maximumTextWidth, 8)
	end
	local measuredWidth = measureWeeklyCountTextWidth(card.Count)
	local textWidth = math.max(1, math.min(maximumTextWidth,
		math.ceil(measuredWidth or maximumTextWidth)))
	card.Count:SetWidth(textWidth)
	card.CountGroup:SetWidth(
		WEEKLY_COUNT_CLOCK_SIZE + WEEKLY_COUNT_ICON_TEXT_GAP + textWidth)
end

local function createWeeklyCard(parent)
	local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
	card:SetHeight(CARD_HEIGHT)
	card:EnableMouse(true)
	card:SetBackdrop(nil)
	applyCardChrome(card, "brown")

	local title = createCardText(card, "GameFontNormal", 13, "OUTLINE")
	title:SetPoint("TOPLEFT", card, "TOPLEFT", WEEKLY_CONTENT_INSET_X, WEEKLY_TITLE_Y)
	title:SetJustifyH("LEFT")
	title:SetTextColor(1, 0.82, 0, 1)
	card.Title = title

	local countTag = CreateFrame("Frame", nil, card)
	countTag:SetPoint("TOPRIGHT", card, "TOPRIGHT",
		WEEKLY_COUNT_TAG_RIGHT_OFFSET_X,
		WEEKLY_COUNT_TAG_Y)
	countTag:SetSize(WEEKLY_COUNT_WIDTH, WEEKLY_COUNT_TAG_HEIGHT)
	countTag:SetFrameLevel((card:GetFrameLevel() or 0) + 2)
	local countBackground = countTag:CreateTexture(nil, "BACKGROUND", nil, 0)
	countBackground:SetAllPoints(countTag)
	if not GF.UI.TrySetAtlas(
		countBackground,
		WEEKLY_TIMER_BACKGROUND_ATLAS,
		false
	) then
		countBackground:SetColorTexture(0.10, 0.08, 0.03, 0.82)
	end
	countBackground:SetAlpha(0.78)
	countTag.Background = countBackground

	local countGroup = CreateFrame("Frame", nil, countTag)
	countGroup:SetPoint("CENTER", countTag, "CENTER",
		WEEKLY_COUNT_GROUP_OFFSET_X, 0)
	countGroup:SetSize(110, 16)
	countGroup:EnableMouse(false)
	card.CountGroup = countGroup

	local countClock = countTag:CreateTexture(nil, "ARTWORK", nil, 1)
	countClock:SetPoint("LEFT", countGroup, "LEFT", 0, -1)
	countClock:SetSize(WEEKLY_COUNT_CLOCK_SIZE, WEEKLY_COUNT_CLOCK_SIZE)
	if not GF.UI.TrySetAtlas(countClock, WEEKLY_TIMER_CLOCK_ATLAS, false) then
		countClock:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_02")
		countClock:SetTexCoord(0.10, 0.90, 0.10, 0.90)
	end
	countTag.Clock = countClock

	local count = createCardText(countTag, "GameFontHighlightSmall", 10, "")
	count:SetPoint("LEFT", countClock, "RIGHT", WEEKLY_COUNT_ICON_TEXT_GAP, 0)
	count:SetSize(88, 16)
	count:SetJustifyH("LEFT")
	count:SetJustifyV("MIDDLE")
	count:SetWordWrap(false)
	count:SetTextColor(1, 1, 1, 0.94)
	card.CountTag = countTag
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
	applyHorizontalGradient(left, 1, 0.82, 0, 0, 1, 0.82, 0, 0.54)
	local right = divider:CreateTexture(nil, "ARTWORK", nil, 1)
	right:SetPoint("LEFT", divider, "CENTER")
	right:SetPoint("RIGHT", divider, "RIGHT")
	right:SetHeight(WEEKLY_DIVIDER_HEIGHT)
	applyHorizontalGradient(right, 1, 0.82, 0, 0.54, 1, 0.82, 0, 0)

	card.RewardBlocks = {}
	for _, threshold in ipairs(WEEKLY_REWARD_THRESHOLDS) do
		card.RewardBlocks[#card.RewardBlocks + 1] =
			createWeeklyRewardBlock(card, threshold)
	end
	card:SetScript("OnSizeChanged", function()
		layoutWeeklyRewardBlocks(card)
	end)
	layoutWeeklyRewardBlocks(card)
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
		local mythicPlusRunCount = tonumber(snapshot.mythicPlusRunCount)
		if mythicPlusRunCount ~= nil then
			GameTooltip:AddDoubleLine(
				(GF.L and GF.L.MPLUS_WEEKLY_TOTAL) or "本周大秘境次数",
				tostring(mythicPlusRunCount),
				0.82, 0.82, 0.82, 1, 1, 1)
		else
			GameTooltip:AddLine((GF.L and GF.L.MPLUS_WEEKLY_UNAVAILABLE)
				or "无法读取本周大秘境记录。", 0.70, 0.70, 0.70, true)
		end

		GameTooltip:AddLine(" ")
		GameTooltip:AddLine((GF.L and GF.L.MPLUS_GREAT_VAULT) or "宏伟宝库", 1, 0.82, 0)
		for _, reward in ipairs(snapshot.rewards or {}) do
			local threshold = tonumber(reward.threshold) or 0
			local progress = math.min(
				tonumber(reward.progress) or tonumber(snapshot.vaultProgress) or 0,
				threshold)
			GameTooltip:AddDoubleLine(
				string.format("%s (%d/%d)",
					getVaultThresholdLabel(threshold), progress, threshold),
				formatWeeklyTooltipReward(reward),
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

local function refreshWeeklyCardTooltip(card)
	if not (GameTooltip and GameTooltip.GetOwner and GameTooltip:IsShown()) then
		return
	end
	local owner = GameTooltip:GetOwner()
	if owner == card then
		local onEnter = card:GetScript("OnEnter")
		if onEnter then
			onEnter(card)
		end
		return
	end
	for _, block in ipairs(card.RewardBlocks or {}) do
		if owner == block then
			showNativeWeeklyRewardTooltip(block)
			return
		end
	end
end

local function bindWeeklyCard(card)
	local snapshot = GF.MythicPlusWeeklyCache and GF.MythicPlusWeeklyCache:GetSnapshot()
	local previousSnapshot = card.Snapshot
	card.Snapshot = snapshot
	card.Title:SetText((GF.L and GF.L.MPLUS_WEEKLY_REPORT) or "大秘境周报")
	local available = snapshot and snapshot.state == "ready"
	local vaultProgress = available
		and (tonumber(snapshot.vaultProgress) or 0)
		or 0
	local mythicPlusRunCount = available
		and tonumber(snapshot.mythicPlusRunCount)
		or nil
	local countAvailable = available and mythicPlusRunCount ~= nil
	bindWeeklyRewardBlocks(
		card,
		snapshot,
		vaultProgress,
		available)
	setWeeklyTextureDesaturated(card.CountTag.Background, not countAvailable)
	setWeeklyTextureDesaturated(card.CountTag.Clock, not countAvailable)
	card.CountTag:SetAlpha(countAvailable and 1 or 0.52)
	if not countAvailable then
		card.Count:SetText((GF.L and GF.L.MPLUS_WEEKLY_UNAVAILABLE_SHORT) or "数据不可用")
	else
		card.Count:SetText(string.format((GF.L and GF.L.MPLUS_WEEKLY_COMPLETED)
			or "本周大秘境 %d 次", mythicPlusRunCount))
	end
	layoutWeeklyCountGroup(card)
	if snapshot ~= previousSnapshot then
		refreshWeeklyCardTooltip(card)
	end
end

function CharacterPage:GetWarbandCharacterGroups()
	local store = GF.MythicPlusCharacterStore
	if store and store.GetCharacterGroups then
		return store:GetCharacterGroups()
	end
	local groups = {
		[self.DRAG.carpool] = {},
		[self.DRAG.other] = {},
	}
	local currentKey = store and store.GetCurrentKey and store:GetCurrentKey()
	for _, character in ipairs(store and store.GetCharacters
		and store:GetCharacters() or {})
	do
		if character.key ~= currentKey then
			local groupKey = character.carpoolEnabled == true
				and self.DRAG.carpool or self.DRAG.other
			groups[groupKey][#groups[groupKey] + 1] = character
		end
	end
	return groups
end

local function formatRunDuration(milliseconds)
	local value = tonumber(milliseconds)
	if not value or value ~= value or value == math.huge or value <= 0 then return "--:--" end
	local totalSeconds = math.floor(value / 1000 + 0.5)
	if totalSeconds <= 0 then
		return "--:--"
	end
	return string.format("%02d:%02d", math.floor(totalSeconds / 60), totalSeconds % 60)
end

local function playBestRunsPanelSound(soundType)
	if not (PlaySound and SOUNDKIT) then
		return
	end
	local soundID = soundType == "open"
		and SOUNDKIT.UI_PLAYER_CHOICE_CYPHER_SHOW_POWERS
		or SOUNDKIT.UI_PLAYER_CHOICE_CYPHER_HIDE_POWERS
	if soundID then PlaySound(soundID) end
end

local function setBestRunsAtlas(texture, atlas, width, height)
	texture:SetSize(width, height)
	local applied = GF.UI.SetAtlasFit(texture, atlas, width, height)
	texture:SetShown(applied == true)
	return applied
end

-- Native animation groups keep transitions bounded: no idle OnUpdate ticker.
local function createBestRunsFade(region)
	local group = region:CreateAnimationGroup()
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetOrder(1)
	alpha:SetDuration(0.18)
	alpha:SetSmoothing("OUT")
	group.Alpha = alpha
	group:SetScript("OnFinished", function()
		region:SetAlpha(group.ToAlpha)
	end)
	return group
end

local function setBestRunsFade(region, group, target, immediate)
	if group.ToAlpha == target and group:IsPlaying() and not immediate then
		return
	end
	local current = region:GetAlpha()
	if group:IsPlaying() then
		current = group.FromAlpha + (group.ToAlpha - group.FromAlpha)
			* group.Alpha:GetSmoothProgress()
	end
	group:Stop()
	group.FromAlpha, group.ToAlpha = current, target
	if immediate or math.abs(current - target) < 0.001 then
		region:SetAlpha(target)
		return
	end
	region:SetAlpha(current)
	group.Alpha:SetFromAlpha(current)
	group.Alpha:SetToAlpha(target)
	group:Play()
end

-- Color feedback uses the original regions, without glow copies or ring masks.
-- This finite native clock only runs during a state transition.
local function applyBestRunsCardStyle(row, mute, highlight, mapMute)
	mapMute = mapMute or mute
	row.MuteAmount, row.HighlightAmount, row.MapMuteAmount = mute, highlight, mapMute
	for _, texture in ipairs(row.ColorTextures) do
		local amount = texture.BestRunsMapColor and mapMute or mute
		local brightness = 1 - amount * 0.28
		texture:SetDesaturation(amount)
		local tone = texture == row.PortraitBorder and (0.72 + 0.28 * highlight) or 1
		texture:SetVertexColor(tone * brightness, tone * brightness, tone * brightness, 1)
	end
	local scene = row.DungeonIconHost.PortalEffectModelScene
	if scene then scene:SetDesaturation(mapMute) end
	for _, text in ipairs(row.ColorText) do
		local r, g, b = text.BaseR or 1, text.BaseG or 1, text.BaseB or 1
		local gray = (r * 0.2126 + g * 0.7152 + b * 0.0722) * 0.72
		text:SetTextColor(r + (gray - r) * mute, g + (gray - g) * mute,
			b + (gray - b) * mute, text.BaseAlpha or 1)
	end
end

local function installBestRunsCardStyle(row)
	row.ColorTextures = { row.CardArt, row.PortraitBack, row.PortraitGlow,
		row.DungeonIcon, row.PortraitBorder, row.PortraitSparkles, row.BottomGlow,
		row.BottomGlowAdditive, row.Pixels1, row.Pixels2, row.Wisps, row.Wisps2, row.LineGlow,
		row.DungeonIconHost.PortalEffectFallback, row.TimeIcon }
	for _, field in ipairs(BEST_RUNS_STYLE.mapEffectFields) do
		row[field].BestRunsMapColor = true
	end
	row.DungeonIconHost.PortalEffectFallback.BestRunsMapColor = true
	row.ColorText = { row.ScoreTitle, row.Score, row.NoRecord, row.DungeonName, row.Level, row.Time.Text }
	local group = row:CreateAnimationGroup()
	local progress = group:CreateAnimation("Animation")
	progress:SetOrder(1)
	progress:SetDuration(0.24)
	progress:SetSmoothing("OUT")
	group.Progress = progress
	group:SetScript("OnUpdate", function()
		local t = progress:GetSmoothProgress()
		applyBestRunsCardStyle(row, group.FromMute + (group.ToMute - group.FromMute) * t,
			group.FromHighlight + (group.ToHighlight - group.FromHighlight) * t,
			group.FromMapMute + (group.ToMapMute - group.FromMapMute) * t)
	end)
	group:SetScript("OnFinished", function()
		applyBestRunsCardStyle(row, group.ToMute, group.ToHighlight, group.ToMapMute)
	end)
	row.VisualTransition = group

	function row:RefreshTextColors()
		for _, text in ipairs(self.ColorText) do
			text.BaseR, text.BaseG, text.BaseB, text.BaseAlpha = text:GetTextColor()
		end
		applyBestRunsCardStyle(self, self.MuteAmount or 0, self.HighlightAmount or 0, self.MapMuteAmount or 0)
	end
end

local function updateBestRunsRing(tile, immediate)
	local row = tile.RecordRow
	if not (row and row.VisualTransition) then return end
	local highlighted = not row.IsCastingMuted and (tile.Hovered == true or tile.TeleportCastActive == true
		or (tile.Pressed == true and tile.TeleportSecureReady == true
			and not UI.IsTeleportCombatLocked()))
	local mute = (row.IsCastingMuted or not row.HasRecord) and 1 or 0
	local mapMute = (row.IsCastingMuted or (not row.HasRecord and not tile.TeleportLearned)) and 1 or 0
	local highlight = highlighted and 1 or 0
	local group = row.VisualTransition
	if not immediate and group.ToMute == mute and group.ToHighlight == highlight
		and group.ToMapMute == mapMute then return end
	local fromMute, fromHighlight = row.MuteAmount or 0, row.HighlightAmount or 0
	local fromMapMute = row.MapMuteAmount or 0
	if group:IsPlaying() then
		local t = group.Progress:GetSmoothProgress()
		fromMute = group.FromMute + (group.ToMute - group.FromMute) * t
		fromHighlight = group.FromHighlight + (group.ToHighlight - group.FromHighlight) * t
		fromMapMute = group.FromMapMute + (group.ToMapMute - group.FromMapMute) * t
	end
	group:Stop()
	group.FromMute, group.ToMute = fromMute, mute
	group.FromHighlight, group.ToHighlight = fromHighlight, highlight
	group.FromMapMute, group.ToMapMute = fromMapMute, mapMute
	if immediate or (fromMute == mute and fromHighlight == highlight and fromMapMute == mapMute) then
		applyBestRunsCardStyle(row, mute, highlight, mapMute)
	else
		applyBestRunsCardStyle(row, fromMute, fromHighlight, fromMapMute)
		group:Play()
	end
end

local function refreshBestRunTeleport(tile, activeID, interruptedID, interruptSerial)
	local service = GF.MythicPlusTeleportService
	if not (tile.Data and service) then
		return
	end
	local status, _, entry = service:GetStatus(tile.Data)
	tile.TeleportStatus = status
	tile.TeleportLearned = (entry and entry.learned == true)
		or (not entry and (status == "ready" or status == "cooldown"))
	service:ApplySecureButton(tile, tile.Data)
	tile.TeleportSecureReady = tile.gfTeleportSecureReady == true
		and tile.gfTeleportSecurePending ~= true
	tile.TeleportCastActive = activeID == tonumber(tile.Data.challengeModeID)
	tile.PortalInteractionBlocked = tile.RecordRow.IsCastingMuted == true
	local presentation = GF.MythicPlusDungeonPage
	if not tile.PortalInteractionBlocked
		and interruptSerial and interruptedID == tonumber(tile.Data.challengeModeID) then
		presentation.PlayPortalInterruptedEffect(tile, interruptSerial)
	else
		presentation.SetPortalHover(tile, tile.Hovered == true)
	end
	updateBestRunsRing(tile)
end

local function applyBestRunsPanelBackplate(panel)
	if panel.Title then
		return
	end

	-- Reuse the CypherChoice art on our own frames. The native choice mixins
	-- own C_PlayerChoice actions and must never be attached to a record viewer.
	local titleArt = panel:CreateTexture(nil, "BACKGROUND")
	titleArt:SetPoint("TOP", panel, "TOP", 0, 0)
	setBestRunsAtlas(titleArt, BEST_RUNS_STYLE.titleAtlas,
		BEST_RUNS_STYLE.titleWidth, BEST_RUNS_STYLE.titleHeight)
	panel.TitleArt = titleArt
	local titleGlow = panel:CreateTexture(nil, "ARTWORK")
	setBestRunsAtlas(titleGlow, BEST_RUNS_STYLE.titleGlowAtlas, 112, 38)
	titleGlow:SetPoint("CENTER", titleArt, "CENTER", -200, 0)
	titleGlow:SetAlpha(0.75)
	titleGlow:SetBlendMode("BLEND")
	-- Standalone virtual MaskTexture nodes are not registered by the client.
	-- Use the PendingButtonFXMask source and atlas crop with the normal Lua API.
	local titleMask = panel:CreateMaskTexture(nil, "OVERLAY")
	titleMask:SetTexture(BEST_RUNS_STYLE.titleMaskTexture,
		"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	titleMask:SetTexCoord(1 / 256, 254 / 256, 1 / 64, 40 / 64)
	titleMask:SetPoint("TOPLEFT", titleArt, "TOPLEFT", 6, -7)
	titleMask:SetPoint("BOTTOMRIGHT", titleArt, "BOTTOMRIGHT", -6, -14)
	titleGlow:AddMaskTexture(titleMask)
	panel.TitleGlow, panel.TitleMask = titleGlow, titleMask

	local summary = CreateFrame("Frame", nil, panel)
	-- The sweep mask overlaps the metal trim; it is not a text-safe rectangle.
	-- The native dark inset is centered on the plaque; share that center axis.
	summary:SetPoint("CENTER", titleArt, "CENTER", 0, 0)
	summary:SetSize(BEST_RUNS_STYLE.summaryWidth, BEST_RUNS_STYLE.summaryHeight)
	panel.Summary = summary
	local title = createCardText(summary, "GameFontNormalLarge", BEST_RUNS_STYLE.summaryTitleFontSize, "")
	title:SetJustifyH("CENTER")
	title:SetJustifyV("MIDDLE")
	title:SetWordWrap(false)
	title:SetTextColor(unpack(BEST_RUNS_STYLE.ratingLabelColor))
	title:SetShadowColor(0, 0, 0, 0.8)
	title:SetShadowOffset(0, -1)
	panel.Title = title
	local score = createCardText(summary, "NumberFontNormal", BEST_RUNS_STYLE.summaryScoreFontSize, "OUTLINE", true)
	score:SetJustifyH("CENTER")
	score:SetJustifyV("MIDDLE")
	score:SetWordWrap(false)
	panel.SeasonScore = score

end

local function setBestRunsDungeonName(text, name)
	local fontPath, _, fontFlags = text:GetFont()
	text._gfFontSizeOverride = BEST_RUNS_STYLE.nameFontSize
	text:SetFont(fontPath, BEST_RUNS_STYLE.nameFontSize, fontFlags)
	text:SetText(name)
	local fullWidth = text:GetUnboundedStringWidth()

	local firstLine, secondLine, lineWidth, bestBalance
	local availableWidth = BEST_RUNS_STYLE.nameWidth - 4
	local function considerBreak(position)
		local first = name:sub(1, position - 1):gsub("%s+$", "")
		local second = name:sub(position):gsub("^%s+", "")
		if first == "" or second == "" then return end
		text:SetText(first)
		local firstWidth = text:GetUnboundedStringWidth()
		text:SetText(second)
		local secondWidth = text:GetUnboundedStringWidth()
		local width = math.max(firstWidth, secondWidth)
		local balance = width + math.abs(firstWidth - secondWidth) * 0.1
			+ (firstWidth < secondWidth and 0.1 or 0)
		if not bestBalance or balance < bestBalance then
			firstLine, secondLine, lineWidth, bestBalance = first, second, width, balance
		end
	end
	-- Native glyph advances can differ even within CJK. Preserve recognizable
	-- location words before balancing: e.g. 红玉/新生法池, 虚空之痕/竞技场.
	local preferredBreak
	for _, suffix in ipairs(BEST_RUNS_STYLE.nameSuffixes) do
		if name:sub(-#suffix) == suffix then
			local prefix = name:sub(1, #name - #suffix)
			local prefixLength = 0
			for _ in prefix:gmatch("[^\128-\191][\128-\191]*") do
				prefixLength = prefixLength + 1
			end
			-- Two-glyph locations may lead a complete longer word, but only
			-- when wrapping is needed; short names keep their single line.
			if prefixLength >= 3 or (prefixLength == 2 and fullWidth > BEST_RUNS_STYLE.nameLineWidth) then
				considerBreak(#prefix + 1)
				if lineWidth <= availableWidth then
					preferredBreak = true
					break
				end
			end
		end
	end
	if not preferredBreak then
		if fullWidth <= BEST_RUNS_STYLE.nameLineWidth then
			text:SetText(name)
			return
		end
		firstLine, secondLine, lineWidth, bestBalance = nil, nil, nil, nil
		-- Other CJK names wrap between complete UTF-8 glyphs; Latin/Cyrillic
		-- names only wrap at word boundaries, avoiding split words.
		local previousGlyph
		for position, glyph in name:gmatch("()([^\128-\191][\128-\191]*)") do
			if previousGlyph and (glyph:match("%s")
				or glyph:byte() >= 227 or previousGlyph:byte() >= 227) then
				considerBreak(position)
			end
			previousGlyph = glyph
		end
	end
	local width = lineWidth or fullWidth
	if width > availableWidth then
		local size = BEST_RUNS_STYLE.nameFontSize * availableWidth / width
		text._gfFontSizeOverride = size
		text:SetFont(fontPath, size, fontFlags)
	end
	text:SetText(firstLine and (firstLine .. "\n" .. secondLine) or name)
end

local function createBestRunRow(parent, panel)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(BEST_RUNS_CARD_WIDTH, BEST_RUNS_CARD_HEIGHT)
	row:Hide()
	local cardArt = row:CreateTexture(nil, "BACKGROUND")
	cardArt:SetPoint("CENTER", row, "CENTER", 0, 0)
	row.CardArt = cardArt

	local scoreTitle = createCardText(row, "GameFontHighlight", BEST_RUNS_STYLE.scoreTitleFontSize)
	scoreTitle:SetPoint("TOP", row, "TOP", 0, -BEST_RUNS_STYLE.scoreTitleTop)
	scoreTitle:SetSize(BEST_RUNS_METRIC_WIDTH, BEST_RUNS_STYLE.scoreTitleHeight)
	scoreTitle:SetJustifyH("CENTER")
	scoreTitle:SetJustifyV("MIDDLE")
	scoreTitle:SetShadowColor(0, 0, 0, 0.9)
	scoreTitle:SetShadowOffset(0, -1)
	row.ScoreTitle = scoreTitle

	local scoreLabel = createCardText(row, "NumberFontNormal", BEST_RUNS_STYLE.scoreFontSize, "OUTLINE", true)
	scoreLabel:SetPoint("TOP", row, "TOP", 0, -BEST_RUNS_STYLE.scoreTop)
	scoreLabel:SetSize(BEST_RUNS_METRIC_WIDTH, BEST_RUNS_STYLE.scoreHeight)
	scoreLabel:SetJustifyH("CENTER")
	scoreLabel:SetJustifyV("MIDDLE")
	scoreLabel:SetShadowColor(0, 0, 0, 1)
	scoreLabel:SetShadowOffset(0, -1)
	row.Score = scoreLabel
	local noRecord = createCardText(row, "GameFontHighlight", BEST_RUNS_STYLE.noRecordFontSize)
	noRecord:SetAllPoints(scoreLabel)
	noRecord:SetJustifyH("CENTER")
	noRecord:SetJustifyV("MIDDLE")
	noRecord:SetShadowColor(0, 0, 0, 0.9)
	noRecord:SetShadowOffset(0, -1)
	noRecord:Hide()
	row.NoRecord = noRecord

	local dungeonName = createCardText(row, "GameFontHighlight", BEST_RUNS_STYLE.nameFontSize)
	dungeonName:SetPoint("TOP", row, "TOP", 0, -BEST_RUNS_STYLE.nameTop)
	dungeonName:SetSize(BEST_RUNS_STYLE.nameWidth, BEST_RUNS_STYLE.nameHeight)
	dungeonName:SetJustifyH("CENTER")
	dungeonName:SetJustifyV("MIDDLE")
	dungeonName:SetWordWrap(true)
	dungeonName:SetMaxLines(2)
	dungeonName:SetSpacing(BEST_RUNS_STYLE.nameLineSpacing)
	dungeonName:SetTextColor(1, 0.96, 0.88, 0.98)
	dungeonName:SetShadowColor(0, 0, 0, 0.9)
	dungeonName:SetShadowOffset(0, -1)
	row.DungeonName = dungeonName

	local portraitBack = row:CreateTexture(nil, "BORDER", nil, 1)
	setBestRunsAtlas(portraitBack, BEST_RUNS_STYLE.portraitBackAtlas,
		94 * BEST_RUNS_STYLE.portraitEffectScale, 94 * BEST_RUNS_STYLE.portraitEffectScale)
	row.PortraitBack = portraitBack

	local dungeonIconHost = CreateFrame("Button", nil, row, "InsecureActionButtonTemplate")
	dungeonIconHost:RegisterForClicks("AnyUp", "AnyDown")
	panel:EnableRightButtonPassthrough(dungeonIconHost)
	dungeonIconHost:SetHitRectInsets(-3, -3, -3, -3)
	dungeonIconHost:SetPoint("CENTER", row, "TOP", 0, BEST_RUNS_STYLE.dungeonIconCenterY)
	dungeonIconHost:SetSize(BEST_RUNS_STYLE.dungeonIconSize, BEST_RUNS_STYLE.dungeonIconSize)
	row.DungeonIconHost = dungeonIconHost
	dungeonIconHost.RecordRow = row
	portraitBack:SetPoint("CENTER", dungeonIconHost, "CENTER", 0, 0)

	local portraitGlow = dungeonIconHost:CreateTexture(nil, "BACKGROUND")
	portraitGlow:SetPoint("CENTER", dungeonIconHost, "CENTER", 0, 0)
	setBestRunsAtlas(portraitGlow, BEST_RUNS_STYLE.portraitGlowAtlas,
		88 * BEST_RUNS_STYLE.portraitEffectScale, 94 * BEST_RUNS_STYLE.portraitEffectScale)
	row.PortraitGlow = portraitGlow

	local dungeonIcon = dungeonIconHost:CreateTexture(nil, "BORDER")
	dungeonIcon:SetAllPoints(dungeonIconHost)
	GF.UI.SetNativeAtlasSampling(dungeonIcon, true)
	row.DungeonIcon = dungeonIcon

	local dungeonIconMask = dungeonIconHost:CreateMaskTexture(nil, "ARTWORK")
	dungeonIconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
		"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	dungeonIconMask:SetAllPoints(dungeonIconHost)
	dungeonIcon:AddMaskTexture(dungeonIconMask)
	row.DungeonIconMask = dungeonIconMask

	-- The 54px map stays inside the 62px Titan ring, including its mask edge.
	local portraitBorder = dungeonIconHost:CreateTexture(nil, "OVERLAY", nil, 2)
	portraitBorder:SetPoint("CENTER", dungeonIconHost, "CENTER", 0, 0)
	setBestRunsAtlas(portraitBorder, BEST_RUNS_STYLE.portraitBorderAtlas,
		BEST_RUNS_STYLE.portraitRingSize, BEST_RUNS_STYLE.portraitRingSize)
	row.PortraitBorder = portraitBorder

	local portraitSparkles = dungeonIconHost:CreateTexture(nil, "OVERLAY", nil, 1)
	portraitSparkles:SetPoint("CENTER", dungeonIconHost, "CENTER", 0, 0)
	setBestRunsAtlas(portraitSparkles, BEST_RUNS_STYLE.portraitSparklesAtlas,
		70 * BEST_RUNS_STYLE.portraitEffectScale, 62 * BEST_RUNS_STYLE.portraitEffectScale)
	row.PortraitSparkles = portraitSparkles


	local bestLevelFrame = CreateFrame("Frame", nil, dungeonIconHost)
	bestLevelFrame:SetFrameLevel(dungeonIconHost:GetFrameLevel() + 6)
	bestLevelFrame:SetAllPoints(dungeonIconHost)
	bestLevelFrame:EnableMouse(false)
	bestLevelFrame:SetAlpha(1)
	GF.MythicPlusDungeonPage.AttachPortalPresentation(dungeonIconHost,
		dungeonIcon, bestLevelFrame, BEST_RUNS_STYLE.dungeonIconSize / 86,
		dungeonIconMask, BEST_RUNS_STYLE.portalPresentation)
	dungeonIconHost:SetScript("OnEnter", function(tile)
		tile.Hovered = true
		GF.MythicPlusDungeonPage.SetPortalHover(tile, true)
		updateBestRunsRing(tile)
		if tile.Data and GameTooltip then
			GameTooltip:SetOwner(tile, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()
			GF.MythicPlusDungeonPage.AddTooltipLines(GameTooltip,
				tile.TooltipData or tile.Data, tile.TeleportSecureReady)
			GameTooltip:Show()
		end
	end)
	dungeonIconHost:SetScript("OnLeave", function(tile)
		tile.Hovered, tile.Pressed = nil, nil
		GF.MythicPlusDungeonPage.SetPortalHover(tile, false)
		updateBestRunsRing(tile)
		if GameTooltip then GameTooltip:Hide() end
	end)
	dungeonIconHost:SetScript("OnMouseDown", function(tile, button)
		if button == "LeftButton" then
			tile.Pressed = true
			updateBestRunsRing(tile)
		end
	end)
	dungeonIconHost:SetScript("OnMouseUp", function(tile, button)
		if button == "LeftButton" then
			tile.Pressed = nil
			updateBestRunsRing(tile)
		end
	end)
	dungeonIconHost:SetScript("OnHide", function(tile)
		tile.Hovered, tile.Pressed = nil, nil
		GF.MythicPlusDungeonPage.ClearPortalPresentation(tile)
		updateBestRunsRing(tile, true)
		if GameTooltip and GameTooltip:GetOwner() == tile then GameTooltip:Hide() end
	end)
	UI.InstallTeleportCombatFeedback(dungeonIconHost, function(tile)
		tile.TeleportSecureReady = tile.gfTeleportSecureReady == true
			and tile.gfTeleportSecurePending ~= true
		tile.Pressed = nil
		GF.MythicPlusDungeonPage.SetPortalHover(tile, tile.Hovered == true, true)
		updateBestRunsRing(tile)
	end)

	local levelStyle = GF.MYTHIC_PLUS_BEST_LEVEL_STYLE
	local levelLabel = createCardText(bestLevelFrame, levelStyle.fontTemplate,
		levelStyle.fontSize, levelStyle.fontFlags, true)
	levelLabel:SetDrawLayer("OVERLAY", 7)
	levelLabel:SetPoint("CENTER", bestLevelFrame, "CENTER", 0, 0)
	levelLabel:SetSize(BEST_RUNS_STYLE.dungeonIconSize, 30)
	levelLabel:SetJustifyH("CENTER")
	levelLabel:SetJustifyV("MIDDLE")
	levelLabel:SetShadowColor(0, 0, 0, 1)
	levelLabel:SetShadowOffset(0, -1)
	row.Level = levelLabel

	local time = CreateFrame("Frame", nil, row)
	time:SetPoint("CENTER", row, "TOP", 0, BEST_RUNS_STYLE.timeCenterY)
	time:EnableMouse(false)
	local timeText = createCardText(time, "NumberFontNormal", BEST_RUNS_STYLE.timeFontSize, "OUTLINE", true)
	timeText:SetPoint("LEFT", time, "LEFT", BEST_RUNS_STYLE.timeIconSize + BEST_RUNS_STYLE.timeIconGap, 0)
	timeText:SetHeight(BEST_RUNS_STYLE.timeHeight)
	timeText:SetJustifyH("CENTER")
	timeText:SetJustifyV("MIDDLE")
	timeText:SetWordWrap(false)
	time.Text = timeText
	time:SetSize(BEST_RUNS_STYLE.timeIconSize, BEST_RUNS_STYLE.timeHeight)
	function time:SetDuration(milliseconds)
		local value = formatRunDuration(milliseconds)
		local hasDuration = value ~= "--:--"
		self.Text:SetText(hasDuration and value or "")
		-- Damage glyph widths vary by locale. Measure the entire unbounded line
		-- before sizing it; narrow per-character boxes can render as ellipses.
		local textWidth = hasDuration and math.ceil(self.Text:GetUnboundedStringWidth())
			+ BEST_RUNS_STYLE.timeTextPadding or 0
		self.Text:SetWidth(math.max(1, textWidth))
		self.Text:SetTextColor(1, 1, 1, 0.96)
		self.Text:SetShown(hasDuration)
		self:SetShown(hasDuration)
		self:SetWidth(BEST_RUNS_STYLE.timeIconSize
			+ (hasDuration and BEST_RUNS_STYLE.timeIconGap + textWidth or 0))
	end
	row.Time = time
	local timeIcon = time:CreateTexture(nil, "ARTWORK")
	setBestRunsAtlas(timeIcon, BEST_RUNS_STYLE.metricIcons.time.atlas,
		BEST_RUNS_STYLE.timeIconSize, BEST_RUNS_STYLE.timeIconSize)
	timeIcon:SetPoint("CENTER", time, "LEFT", BEST_RUNS_STYLE.timeIconSize / 2, 0)
	row.TimeIcon = timeIcon

	-- Full passive CypherChoice effects, from the native XML and mixin.
	-- Our own frames keep the record viewer independent of player-choice actions.
	local function createEffect(atlas, width, height, alpha, blendMode)
		local texture = row:CreateTexture(nil, "ARTWORK")
		setBestRunsAtlas(texture, atlas,
			width * BEST_RUNS_FX_SCALE, height * BEST_RUNS_FX_SCALE)
		texture:SetAlpha(alpha)
		texture:SetBlendMode(blendMode)
		return texture
	end
	row.BottomGlow = createEffect(BEST_RUNS_STYLE.bottomGlowAtlas, 205, 197, 0.5, "BLEND")
	row.BottomGlow:SetPoint("BOTTOM", row, "BOTTOM", 0, 22 * BEST_RUNS_FX_SCALE)
	row.BottomGlowAdditive = createEffect(BEST_RUNS_STYLE.bottomGlowAtlas, 205, 197, 0.3, "ADD")
	row.BottomGlowAdditive:SetPoint("CENTER", row.BottomGlow, "CENTER", 0, 0)
	row.Pixels1 = createEffect(BEST_RUNS_STYLE.pixels1Atlas, 117, 135, 1, "ADD")
	row.Pixels2 = createEffect(BEST_RUNS_STYLE.pixels2Atlas, 126, 113, 0.5, "BLEND")
	row.Wisps = createEffect(BEST_RUNS_STYLE.wispsAtlas, 232, 384, 0.3, "ADD")
	row.Wisps2 = createEffect(BEST_RUNS_STYLE.wispsAtlas, 232, 384, 0.3, "ADD")
	local bottomMask = row:CreateMaskTexture(nil, "OVERLAY")
	bottomMask:SetTexture(BEST_RUNS_STYLE.bottomMaskTexture,
		"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	bottomMask:SetSize(256 * BEST_RUNS_FX_SCALE, 256 * BEST_RUNS_FX_SCALE)
	bottomMask:SetPoint("BOTTOM", row, "BOTTOM", 0, -8 * BEST_RUNS_FX_SCALE)
	row.BottomMask = bottomMask
	for _, texture in ipairs({ row.Pixels1, row.Pixels2, row.Wisps, row.Wisps2 }) do
		local offset = (texture == row.Wisps or texture == row.Wisps2) and -350 or -100
		texture:SetPoint("BOTTOM", row, "BOTTOM", 0, offset * BEST_RUNS_FX_SCALE)
		texture:AddMaskTexture(bottomMask)
	end
	local lineGlow = row:CreateTexture(nil, "OVERLAY")
	setBestRunsAtlas(lineGlow, BEST_RUNS_STYLE.lineGlowAtlas, BEST_RUNS_CARD_WIDTH, BEST_RUNS_CARD_HEIGHT)
	lineGlow:SetBlendMode("ADD")
	lineGlow:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	lineGlow:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -400 * BEST_RUNS_FX_SCALE)
	row.LineGlow = lineGlow
	local lineMask = row:CreateMaskTexture(nil, "OVERLAY")
	lineMask:SetTexture(BEST_RUNS_STYLE.lineMaskTexture,
		"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	lineMask:SetPoint("TOPLEFT", row, "TOPLEFT", -124 * BEST_RUNS_FX_SCALE, 7 * BEST_RUNS_FX_SCALE)
	lineMask:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 124 * BEST_RUNS_FX_SCALE, -7 * BEST_RUNS_FX_SCALE)
	lineGlow:AddMaskTexture(lineMask)
	row.LineGlowMask = lineMask

	row.PassiveAnimations = {}
	local function loop(target, template)
		local group = target:CreateAnimationGroup(nil, template)
		row.PassiveAnimations[#row.PassiveAnimations + 1] = group
	end
	loop(lineGlow, "GroupFinderAddonBestRunsLineGlowAnimationTemplate")
	loop(portraitGlow, "GroupFinderAddonBestRunsGlowPulseTemplate")
	installBestRunsCardStyle(row)
	row:SetScript("OnShow", function(self)
		for _, animation in ipairs(self.PassiveAnimations) do
			animation:Play()
		end
	end)
	row:SetScript("OnHide", function(self)
		self.VisualTransition:Stop()
		self.VisualTransition.ToMute, self.VisualTransition.ToHighlight, self.VisualTransition.ToMapMute = nil, nil, nil
		self.IsCastingMuted = nil
		applyBestRunsCardStyle(self, 0, 0)
		for _, animation in ipairs(self.PassiveAnimations) do
			animation:Stop()
		end
	end)
	return row
end

local function setBestRunsPanelMainWindowHidden(panel, hidden)
	local mainController = GF.MainFrame
	local mainFrame = GF.UI and GF.UI.GetMainFrame and GF.UI.GetMainFrame()
	if not mainFrame then
		return
	end
	if hidden then
		if panel.MainFrameWasShown == nil then
			panel.MainFrameWasShown = mainFrame.IsShown
				and mainFrame:IsShown() or false
		end
		if panel.MainFrameWasShown ~= true
			or not (mainFrame.IsShown and mainFrame:IsShown())
		then
			return
		end
		if mainController and mainController.HideFrame then
			mainController:HideFrame(true)
		elseif mainFrame.Hide then
			mainFrame:Hide()
		end
		return
	end

	local restoreMainFrame = panel.MainFrameWasShown == true
	panel.MainFrameWasShown = nil
	if restoreMainFrame
		and not (mainFrame.IsShown and mainFrame:IsShown())
	then
		if mainController and mainController.ShowFrame then
			mainController:ShowFrame()
		elseif mainFrame.Show then
			mainFrame:Show()
		end
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
	local keyHolders = GF.MythicPlusDungeonPage.GetTooltipKeyHolders()
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
			challengeModeID = mapID,
			name = dungeon.name,
			dungeon = dungeon,
			run = run,
			bestRun = run,
			keyHolders = mapID and keyHolders[mapID] or nil,
			sourceOrder = sourceOrder,
		}
	end
	local sorter = GF.MythicPlusSeasonDungeonSort
	if sorter and sorter.Sort then
		rows = sorter:Sort(rows)
	end
	return rows, ratingEntry, #dungeons > 0
end

local function installBestRunsPanelMotion(panel)
	-- One visible-panel clock owns the card transforms and title sweep. Absolute phases
	-- avoid accumulated angles/offsets, frame-rate dependence and one-shot groups.
	-- Native atlases, blend modes, alpha and stationary masks remain unchanged.
	local function updateBestRunsPassiveEffects(panel)
		local now = GetTime()
		local elapsed = math.max(0, now - panel.PassiveStartedAt)
		-- Keep the native 0.75s sweep; the requested 3.5s cycle leaves 2.75s rest.
		-- Reset the actual anchor each cycle instead of accumulating translations.
		local titlePhase = elapsed % BEST_RUNS_STYLE.titleSweepPeriod
		panel.TitleGlow:SetPoint("CENTER", panel.TitleArt, "CENTER",
			-200 + 360 * math.min(titlePhase / BEST_RUNS_STYLE.titleSweepSeconds, 1), 0)
		panel.TitleGlow:SetAlpha(titlePhase < BEST_RUNS_STYLE.titleSweepSeconds and 0.75 or 0)
		local revealElapsed = panel.RevealStartedAt and (panel.RevealElapsed
			or math.max(0, now - panel.RevealStartedAt))
		local glowAngle = (elapsed % 30) / 30 * (2 * math.pi)
		local sparkleAngle = -(elapsed % 40) / 40 * (2 * math.pi)
		local pixels1Y = (-100 + (elapsed % 13) / 13 * 250) * BEST_RUNS_FX_SCALE
		local pixels2Y = (-100 + (elapsed % 8) / 8 * 250) * BEST_RUNS_FX_SCALE
		local wisps1Y = (-350 + (elapsed % 13) / 13 * 500) * BEST_RUNS_FX_SCALE
		local wisps2Y = (-350 + (elapsed % 20) / 20 * 500) * BEST_RUNS_FX_SCALE
		for index, row in ipairs(panel.Rows) do
			if row:IsShown() then
				if revealElapsed then
					local progress = math.min(1, math.max(0,
						(revealElapsed - (index - 1) * BEST_RUNS_STYLE.cardRevealStagger)
							/ BEST_RUNS_STYLE.cardRevealSeconds))
					row:SetAlpha(1 - (1 - progress) * (1 - progress))
					row:SetPoint("TOPLEFT", panel.RowsContainer, "TOPLEFT", row.RevealX,
						-BEST_RUNS_STYLE.cardRevealTravel * (1 - progress) * (1 - progress))
				end
				row.PortraitGlow:SetRotation(glowAngle)
				row.PortraitSparkles:SetRotation(sparkleAngle)
				row.Pixels1:SetPoint("BOTTOM", row, "BOTTOM", 0, pixels1Y)
				row.Pixels2:SetPoint("BOTTOM", row, "BOTTOM", 0, pixels2Y)
				row.Wisps:SetPoint("BOTTOM", row, "BOTTOM", 0, wisps1Y)
				row.Wisps2:SetPoint("BOTTOM", row, "BOTTOM", 0, wisps2Y)
			end
		end
		if revealElapsed and revealElapsed >= BEST_RUNS_STYLE.cardRevealSeconds
			+ math.max(0, (panel.VisibleRowCount or 0) - 1) * BEST_RUNS_STYLE.cardRevealStagger
		then
			panel.RevealStartedAt, panel.RevealElapsed = nil, nil
		end
	end

	function panel:RefreshPassiveClock(showing)
		-- OnShow is authoritative even before IsVisible settles on the first frame.
		if showing or self:IsVisible() then
			self.PassiveStartedAt = self.PassiveStartedAt or GetTime()
			self:SetScript("OnUpdate", updateBestRunsPassiveEffects)
			updateBestRunsPassiveEffects(self)
		else
			self:SetScript("OnUpdate", nil)
			self.PassiveStartedAt = nil
		end
	end

	local dimmer = CreateFrame("Frame", nil, UIParent)
	dimmer:SetFrameStrata("DIALOG")
	dimmer:SetFrameLevel(199)
	dimmer:SetAllPoints(UIParent)
	dimmer:EnableMouse(false)
	local shade = dimmer:CreateTexture(nil, "BACKGROUND")
	shade:SetAllPoints(dimmer)
	shade:SetColorTexture(0, 0, 0, BEST_RUNS_STYLE.backdropAlpha)
	dimmer:SetAlpha(0)
	dimmer:Hide()
	panel.Dimmer = dimmer
	panel.DimmerFade = createBestRunsFade(dimmer)

	local motion = panel:CreateAnimationGroup()
	local progress = motion:CreateAnimation("Animation")
	progress:SetOrder(1)
	progress:SetSmoothing("OUT")
	motion.Progress = progress
	panel.Motion = motion
	-- Move the actual layout anchor, not the renderer's Translation transform.
	-- Nested time/map frames and their font strings must follow one geometry.
	motion:SetScript("OnUpdate", function()
		if not motion:IsPlaying() then return end
		local t = progress:GetSmoothProgress()
		panel:SetAlpha(motion.FromAlpha + (motion.ToAlpha - motion.FromAlpha) * t)
		panel:SetPoint("CENTER", UIParent, "CENTER",
			motion.FromX + (motion.ToX - motion.FromX) * t,
			motion.FromY + (motion.ToY - motion.FromY) * t)
	end)
	local nativeHide = panel.Hide
	local function stopMotion()
		local scale = panel:GetEffectiveScale()
		local screenScale = UIParent:GetEffectiveScale()
		local x, y = panel:GetCenter()
		local screenX, screenY = UIParent:GetCenter()
		local currentAlpha = panel:GetAlpha()
		local currentX = x - screenX * screenScale / scale
		local currentY = y - screenY * screenScale / scale
		if motion:IsPlaying() then
			local t = progress:GetSmoothProgress()
			currentAlpha = motion.FromAlpha + (motion.ToAlpha - motion.FromAlpha)
				* t
			currentX = motion.FromX + (motion.ToX - motion.FromX) * t
			currentY = motion.FromY + (motion.ToY - motion.FromY) * t
		end
		motion:Stop()
		return currentAlpha, currentX, currentY
	end
	function panel:PlayEntrance()
		local currentAlpha, currentX, currentY = stopMotion()
		if not self.Closing then
			currentAlpha, currentX, currentY = 0, 0, -BEST_RUNS_STYLE.panelTravel
			self.RevealStartedAt = GetTime()
		elseif self.RevealElapsed then
			-- Resume a partially revealed row without flashing the later cards.
			self.RevealStartedAt = GetTime() - self.RevealElapsed
		end
		self.RevealElapsed = nil
		self.Closing = nil
		self:PlayMotion(currentAlpha, currentX, currentY, 1, 0, 0, BEST_RUNS_STYLE.panelFadeInSeconds)
		dimmer:Show()
		panel.DimmerFade.Alpha:SetDuration(BEST_RUNS_STYLE.panelFadeInSeconds)
		setBestRunsFade(dimmer, panel.DimmerFade, 1)
	end
	function panel:PlayMotion(fromAlpha, fromX, fromY, toAlpha, toX, toY, duration)
		motion.FromAlpha, motion.ToAlpha = fromAlpha, toAlpha
		motion.FromX, motion.ToX, motion.FromY, motion.ToY = fromX, toX, fromY, toY
		self:SetAlpha(fromAlpha)
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "CENTER", fromX, fromY)
		progress:SetDuration(duration)
		progress:SetSmoothing(self.Closing and "IN" or "OUT")
		motion:Play()
	end
	-- UISpecialFrames calls Hide directly. The button and Esc share the exit.
	function panel:Hide()
		if not self:IsShown() or self.Closing then return end
		self:StopMovingOrSizing()
		local currentAlpha, currentX, currentY = stopMotion()
		if self.RevealStartedAt then
			self.RevealElapsed = math.max(0, GetTime() - self.RevealStartedAt)
		end
		self.Closing = true
		self:PlayMotion(currentAlpha, currentX, currentY, 0, currentX, currentY - BEST_RUNS_STYLE.panelTravel,
			BEST_RUNS_STYLE.panelFadeOutSeconds)
		panel.DimmerFade.Alpha:SetDuration(BEST_RUNS_STYLE.panelFadeOutSeconds)
		setBestRunsFade(dimmer, panel.DimmerFade, 0)
	end
	motion:SetScript("OnFinished", function()
		if panel.Closing then
			nativeHide(panel)
		else
			panel:SetAlpha(1)
			motion:Stop()
			panel:ClearAllPoints()
			panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
	end)
	panel:SetScript("OnShow", function(self)
		self:PlayEntrance()
		self:RefreshPassiveClock(true)
		if GF.MythicPlusWorkspace then
			GF.MythicPlusWorkspace:QueueRefreshAfterShow()
		end
		if not self.SoundOpen then
			self.SoundOpen = true
			playBestRunsPanelSound("open")
		end
	end)
	panel:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
		self.PassiveStartedAt = nil
		self.RevealStartedAt, self.RevealElapsed = nil, nil
		motion:Stop()
		panel.DimmerFade:Stop()
		dimmer:SetAlpha(0)
		dimmer:Hide()
		-- Alt-Z hides ancestors without closing this viewer. Preserve its
		-- handoff and fallback data until the actual panel is dismissed.
		if self:IsShown() and not self.Closing then return end
		if self:IsShown() then nativeHide(self) end
		self.Closing = nil
		self.CharacterData = nil
		self:SetAlpha(1)
		setBestRunsPanelMainWindowHidden(self, false)
		if self.SoundOpen then
			self.SoundOpen = nil
			playBestRunsPanelSound("close")
		end
	end)
end

local function createBestRunsPanel(ownerCard)
	local panel = CreateFrame("Frame", "GroupFinderAddonCurrentCharacterBestRunsPanel",
		UIParent)
	function panel:EnableRightButtonPassthrough(target)
		if not (InCombatLockdown and InCombatLockdown()) then
			target:SetPassThroughButtons("RightButton")
			return
		end
		-- This setter is restricted even on our own ordinary frames. Keep
		-- the viewer usable and finish only this configuration after combat.
		if not self.PendingMousePassthrough then
			self.PendingMousePassthrough = {}
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
			self:SetScript("OnEvent", function(self, event)
				if event ~= "PLAYER_REGEN_ENABLED" or not self.PendingMousePassthrough
					or (InCombatLockdown and InCombatLockdown()) then return end
				for frame in pairs(self.PendingMousePassthrough) do
					frame:SetPassThroughButtons("RightButton")
				end
				self.PendingMousePassthrough = nil
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
				self:SetScript("OnEvent", nil)
			end)
		end
		self.PendingMousePassthrough[target] = true
	end
	panel:SetSize(1176, BEST_RUNS_PANEL_HEADER_HEIGHT
		+ BEST_RUNS_CARD_HEIGHT + BEST_RUNS_PANEL_FOOTER_HEIGHT)
	panel:SetFrameStrata("DIALOG")
	panel:SetFrameLevel(200)
	if panel.SetToplevel then
		panel:SetToplevel(true)
	end
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:EnableRightButtonPassthrough(panel)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self)
		if not self.Motion:IsPlaying() then self:StartMoving() end
	end)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	panel.OwnerCard = ownerCard
	panel:Hide()
	installBestRunsPanelMotion(panel)
	if GF.GetPanelScale and panel.SetScale then
		panel:SetScale(GF.GetPanelScale())
	end
	applyBestRunsPanelBackplate(panel)

	local rowsContainer = CreateFrame("Frame", nil, panel)
	rowsContainer:SetPoint("TOP", panel, "TOP", 0, -BEST_RUNS_PANEL_HEADER_HEIGHT)
	panel.RowsContainer = rowsContainer

	local close = CreateFrame("Button", nil, panel)
	panel:EnableRightButtonPassthrough(close)
	close:SetPoint("TOP", rowsContainer, "BOTTOM", 0, -BEST_RUNS_STYLE.sectionGap)
	close:SetSize(BEST_RUNS_STYLE.closeWidth, BEST_RUNS_STYLE.closeHeight)
	close:SetFrameLevel((panel:GetFrameLevel() or 0) + 20)
	local closeArt = close:CreateTexture(nil, "BACKGROUND")
	closeArt:SetPoint("CENTER", close, "CENTER", 0, 0)
	setBestRunsAtlas(closeArt, BEST_RUNS_STYLE.closeAtlas,
		BEST_RUNS_STYLE.closeWidth, BEST_RUNS_STYLE.closeHeight)
	-- Native HIGHLIGHT visibility switches instantly. Keep the same artwork
	-- visible and animate its opacity alongside the label's warm-gold color.
	local closeHighlight = close:CreateTexture(nil, "ARTWORK")
	closeHighlight:SetPoint("CENTER", close, "CENTER", 0, 0)
	setBestRunsAtlas(closeHighlight, BEST_RUNS_STYLE.closeHighlightAtlas,
		BEST_RUNS_STYLE.closeWidth, BEST_RUNS_STYLE.closeHeight)
	local closeText = createCardText(close, "GameFontNormal", 14, "OUTLINE")
	closeText:SetPoint("CENTER", close, "CENTER", 0, 0)
	closeText:SetText((GF.L and GF.L.MPLUS_BEST_RUNS_CLOSE) or CLOSE or "关闭")
	close.Art, close.Highlight, close.Text = closeArt, closeHighlight, closeText
	local hover = close:CreateAnimationGroup()
	local progress = hover:CreateAnimation("Animation")
	progress:SetOrder(1)
	progress:SetSmoothing("OUT")
	hover.Progress = progress
	close.HoverTransition = hover
	local function applyHover(amount)
		close.HoverAmount = amount
		closeHighlight:SetAlpha(amount)
		closeText:SetTextColor(1, 0.82 + 0.12 * amount, 0.64 * amount, 1)
	end
	local function setHover(target, immediate)
		local current = close.HoverAmount or 0
		if hover:IsPlaying() then
			current = hover.From + (hover.To - hover.From) * progress:GetSmoothProgress()
		end
		hover:Stop()
		hover.From, hover.To = current, target
		applyHover(current)
		if immediate or math.abs(current - target) < 0.001 then
			applyHover(target)
		else
			progress:SetDuration(target == 1 and BEST_RUNS_STYLE.closeHoverInSeconds
				or BEST_RUNS_STYLE.closeHoverOutSeconds)
			hover:Play()
		end
	end
	hover:SetScript("OnUpdate", function()
		applyHover(hover.From + (hover.To - hover.From) * progress:GetSmoothProgress())
	end)
	hover:SetScript("OnFinished", function() applyHover(hover.To) end)
	setHover(0, true)
	close:SetScript("OnEnter", function() setHover(1) end)
	close:SetScript("OnLeave", function() setHover(0) end)
	close:SetScript("OnMouseDown", function()
		closeText:SetPoint("CENTER", close, "CENTER", 1, -1)
	end)
	close:SetScript("OnMouseUp", function()
		closeText:SetPoint("CENTER", close, "CENTER", 0, 0)
	end)
	close:SetScript("OnHide", function()
		setHover(0, true)
		closeText:SetPoint("CENTER", close, "CENTER", 0, 0)
	end)
	close:SetScript("OnClick", function()
		panel:Hide()
	end)
	panel.Close = close

	panel.Rows = {}

	local empty = createCardText(rowsContainer, "GameFontHighlight", 14, "")
	empty:SetPoint("TOP", rowsContainer, "TOP", 0, -18)
	empty:SetJustifyH("CENTER")
	empty:SetTextColor(0.65, 0.65, 0.65, 0.95)
	empty:Hide()
	panel.Empty = empty

	function panel:RefreshRecords(data)
		data = data or {}
		local rowData, ratingEntry, seasonReady = buildBestRunsRows(data)
		self.VisibleRowCount = #rowData
		local rowsHeight = #rowData > 0 and BEST_RUNS_CARD_HEIGHT or 80
		local contentWidth = #rowData * BEST_RUNS_CARD_WIDTH
			+ math.max(0, #rowData - 1) * BEST_RUNS_CARD_GAP
		contentWidth = math.max(380, contentWidth)
		local panelWidth = contentWidth + BEST_RUNS_PANEL_INSET_X * 2
		local panelHeight = BEST_RUNS_PANEL_HEADER_HEIGHT
			+ rowsHeight + BEST_RUNS_PANEL_FOOTER_HEIGHT
		self:SetSize(panelWidth, panelHeight)
		applyBestRunsPanelBackplate(self)
		self.RowsContainer:SetSize(contentWidth, rowsHeight)
		self.Empty:SetWidth(contentWidth)

		local score = tonumber(ratingEntry and ratingEntry.score)
			or tonumber(data.rating) or 0
		local scoreColor = ratingEntry and ratingEntry.scoreColor
			or data.ratingColor
			or (GF.MythicPlusRatingCache
				and GF.MythicPlusRatingCache:GetCachedScoreColor(score))
		self.Title:SetText((GF.L and GF.L.MPLUS_TOOLTIP_SEASON_RATING) or "赛季评分")
		self.SeasonScore:SetText(UI.ColorText(math.floor(score + 0.5),
			UI.ColorToARGBHex(scoreColor)))
		self.SeasonScore:SetTextColor(1, 1, 1, 1)
		local labelWidth = math.ceil(self.Title:GetUnboundedStringWidth())
		local scoreWidth = math.ceil(self.SeasonScore:GetUnboundedStringWidth()) + 2
		-- Measure the complete phrase so a single digit and a full score both
		-- have balanced outer space. Only oversized localized content scales.
		local summaryWidth = labelWidth + BEST_RUNS_STYLE.summaryGap + scoreWidth
		self.Summary:SetSize(summaryWidth, BEST_RUNS_STYLE.summaryHeight)
		self.Summary:SetScale(math.min(1, BEST_RUNS_STYLE.summaryWidth / math.max(1, summaryWidth)))
		self.Title:SetPoint("LEFT", self.Summary, "LEFT", 0, 0)
		self.Title:SetSize(labelWidth, BEST_RUNS_STYLE.summaryHeight)
		self.SeasonScore:SetPoint("RIGHT", self.Summary, "RIGHT", 0, 0)
		self.SeasonScore:SetSize(scoreWidth, BEST_RUNS_STYLE.summaryHeight)

		while #self.Rows < #rowData do
			self.Rows[#self.Rows + 1] = createBestRunRow(self.RowsContainer, self)
		end
		for index, row in ipairs(self.Rows) do
			local rowInfo = rowData[index]
			row:ClearAllPoints()
			if rowInfo then
				if not self.RevealStartedAt then row:SetAlpha(1) end
				local cardsWidth = #rowData * BEST_RUNS_CARD_WIDTH
					+ math.max(0, #rowData - 1) * BEST_RUNS_CARD_GAP
				row.RevealX = (contentWidth - cardsWidth) / 2
					+ (index - 1) * (BEST_RUNS_CARD_WIDTH + BEST_RUNS_CARD_GAP)
				row:SetPoint("TOPLEFT", self.RowsContainer, "TOPLEFT", row.RevealX, 0)
				local cardAtlas = BEST_RUNS_STYLE.cardAtlases[(index - 1) % 3 + 1]
				setBestRunsAtlas(row.CardArt, cardAtlas, BEST_RUNS_CARD_WIDTH, BEST_RUNS_CARD_HEIGHT)
				local dungeon = rowInfo.dungeon or {}
				local tile = row.DungeonIconHost
				if tonumber(tile.Data and tile.Data.challengeModeID) ~= tonumber(dungeon.challengeModeID) then
					GF.MythicPlusDungeonPage.ClearPortalPresentation(tile)
				end
				tile.Data = dungeon
				tile.TooltipData = rowInfo
				row.DungeonIcon:SetTexture(dungeon.texture
					or dungeon.fallbackTexture
					or "Interface\\Icons\\INV_Misc_QuestionMark")
				row.DungeonIcon:SetTexCoord(0, 1, 0, 1)
				row.DungeonIcon:SetVertexColor(1, 1, 1, 1)
				row.DungeonName:SetTextColor(1, 0.96, 0.88, 0.98)
				setBestRunsDungeonName(row.DungeonName, dungeon.name
					or ((GF.L and GF.L.MPLUS_UNKNOWN_DUNGEON)
						or "未知地下城"))
				local run = rowInfo.run
				local level = tonumber(run and run.level) or 0
				row.HasRecord = level > 0
				GF.MythicPlusDungeonPage.UpdateBestLevelText(tile, row.Level,
					level, run and run.timed)
				local runScore = tonumber(run and run.score) or 0
				row.Time:SetDuration(row.HasRecord and run.durationMS or nil)
				row.Score:SetShown(row.HasRecord)
				row.ScoreTitle:SetShown(row.HasRecord)
				row.ScoreTitle:SetText((GF.L and GF.L.MPLUS_BEST_RUN_SCORE_LABEL) or "最佳评分")
				row.ScoreTitle:SetTextColor(unpack(BEST_RUNS_STYLE.ratingLabelColor))
				row.NoRecord:SetShown(not row.HasRecord)
				row.NoRecord:SetText((GF.L and GF.L.MPLUS_TOOLTIP_NO_RECORD) or "无记录")
				row.NoRecord:SetTextColor(0.95, 0.95, 0.95, 1)
				if level > 0 then
					local rules = GF.MYTHIC_PLUS_SCORE_COLOR_RULE or {}
					local runScoreColor = (GF.MythicPlusRatingCache
						and GF.MythicPlusRatingCache:GetScoreColor(
							runScore, rules.SINGLE_DUNGEON))
						or run.scoreColor
					local scoreR = tonumber(runScoreColor and runScoreColor.r) or 1
					local scoreG = tonumber(runScoreColor and runScoreColor.g) or 0.52
					local scoreB = tonumber(runScoreColor and runScoreColor.b) or 0
					row.Score:SetText(tostring(math.floor(runScore + 0.5)))
					row.Score:SetTextColor(scoreR, scoreG, scoreB, 1)
				else
					row.Score:SetText("")
					row.Score:SetTextColor(0.55, 0.55, 0.55, 0.92)
				end
				row:RefreshTextColors()
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
		local scale = (GF.GetPanelScale and GF.GetPanelScale()) or 1
		local screenWidth = UIParent:GetWidth()
		local screenHeight = UIParent:GetHeight()
		if screenWidth and screenWidth > 40 and screenHeight and screenHeight > 40 then
			scale = math.min(scale, (screenWidth - 40) / panelWidth,
				(screenHeight - 40) / panelHeight)
		end
		self:SetScale(scale)
		self:RefreshPassiveClock()
	end

	function panel:ShowFor(data)
		self.CharacterData = data
		self.RecordsDirty = nil
		self:RefreshRecords(data)
		if not self.Motion:IsPlaying() then
			self:ClearAllPoints()
			self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
		setBestRunsPanelMainWindowHidden(self, true)
		local reopen = self.Closing
		self:Show()
		if reopen then self:PlayEntrance() end
		self:RefreshTeleports()
		if self.Raise then
			self:Raise()
		end
	end

	function panel:RefreshTeleports()
		if not self:IsShown() or self.Closing then return end
		local service = GF.MythicPlusTeleportService
		if not service then return end
		local activeID = service:GetActiveChallengeModeID()
		local interruptedID, serial = service:GetInterruptedCastPulse()
		local newSerial = serial and serial ~= self.LastInterruptSerial and serial or nil
		for _, row in ipairs(self.Rows) do
			if row:IsShown() then
				row.IsCastingMuted = activeID ~= nil
					and activeID ~= tonumber(row.DungeonIconHost.Data and row.DungeonIconHost.Data.challengeModeID)
				refreshBestRunTeleport(row.DungeonIconHost, activeID, interruptedID, newSerial)
			end
		end
		self.LastInterruptSerial = serial or self.LastInterruptSerial
	end
	-- The workspace already subscribes to the authoritative services. Reuse
	-- its coalesced refresh even while this overlay hides the main window.
	function panel:Invalidate(service)
		if not service or service == GF.MythicPlusRatingCache
			or service == GF.MythicPlusSeason
			or service == GF.MythicPlusCharacterStore
		then
			self.RecordsDirty = true
		end
	end
	function panel:RefreshView()
		if not self:IsVisible() or self.Closing then return end
		if self.RecordsDirty then
			self.RecordsDirty = nil
			self:RefreshRecords(self.CharacterData)
		end
		self:RefreshTeleports()
	end
	if GF.MythicPlusWorkspace then
		GF.MythicPlusWorkspace.bestRunsPanel = panel
	end

	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, panel:GetName())
	end
	return panel
end

local function createWeeklyBestRunsButton(parent, panel, getCharacterData)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(WEEKLY_BEST_BUTTON_SIZE, WEEKLY_BEST_BUTTON_SIZE)
	button:SetFrameLevel((parent:GetFrameLevel() or 0) + 3)
	button:RegisterForClicks("LeftButtonUp")
	button._bestRunsPanel = panel

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	button.Icon = icon

	function button:UpdateVisual()
		local atlas
		if self._pressed then
			atlas = WEEKLY_BEST_BUTTON_PRESSED_ATLAS
		elseif self._hovered then
			atlas = WEEKLY_BEST_BUTTON_ACTIVE_ATLAS
		else
			atlas = WEEKLY_BEST_BUTTON_INACTIVE_ATLAS
		end
		self.Icon:SetVertexColor(1, 1, 1, 1)
		if not GF.UI.TrySetAtlas(self.Icon, atlas, false) then
			self.Icon:SetTexture(GF.WHITE_TEXTURE)
			if atlas == WEEKLY_BEST_BUTTON_ACTIVE_ATLAS then
				self.Icon:SetVertexColor(1, 0.82, 0, 1)
			elseif atlas == WEEKLY_BEST_BUTTON_PRESSED_ATLAS then
				self.Icon:SetVertexColor(0.92, 0.92, 0.92, 1)
			else
				self.Icon:SetVertexColor(0.46, 0.46, 0.46, 1)
			end
		end
	end

	button:SetScript("OnEnter", function(self)
		self._hovered = true
		self:UpdateVisual()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine((GF.L and GF.L.MPLUS_BEST_RUNS_TITLE)
			or "赛季地下城最佳记录", 1, 0.82, 0)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function(self)
		self._hovered = false
		self._pressed = false
		self:UpdateVisual()
		GameTooltip_Hide()
	end)
	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			self._pressed = true
			self:UpdateVisual()
		end
	end)
	button:SetScript("OnMouseUp", function(self)
		self._pressed = false
		self:UpdateVisual()
	end)
	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton ~= "LeftButton" or not self._bestRunsPanel then
			return
		end
		GameTooltip_Hide()
		local data = getCharacterData and getCharacterData() or nil
		self._bestRunsPanel:ShowFor(data or {})
		self:UpdateVisual()
	end)

	button:UpdateVisual()
	return button
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
	-- Extend the viewport to the title background's left edge; content below
	-- each title retains the original card inset within this wider viewport.
	page.playerInfo:SetPoint("TOPLEFT", page.frame, "TOPLEFT",
		GF.MYTHIC_PLUS_CHARACTER_TITLE_INSET_LEFT,
		-GF.MYTHIC_PLUS_CHARACTER_SCROLL_TOP_INSET)
	page.playerInfo:SetPoint("BOTTOMRIGHT", page.frame, "BOTTOMRIGHT",
		-GF.MYTHIC_PLUS_CHARACTER_CONTENT_INSET_X, 10)

	local layout
	page.scroll, page.content, page.scrollBar = createScrollContainer(page.playerInfo, function()
		if layout then
			layout()
		end
	end)
	UI.AnchorWorkspaceScrollBar(page.scrollBar, page.frame)
	page.scroll._gfWheelAllow = function()
		return page.characterDrag == nil
	end

	page.currentTitle = createSectionTitle(page.content, "")
	page.currentTitle:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, TITLE_TOP_OFFSET)
	page.currentTitle:SetPoint("TOPRIGHT", page.content, "TOPRIGHT", 0, TITLE_TOP_OFFSET)

	page.currentArea = CreateFrame("Frame", nil, page.content)
	page.currentArea:SetPoint("TOPLEFT", page.currentTitle, "BOTTOMLEFT",
		TITLE_BACKGROUND_BLEED_LEFT, -TITLE_TO_CARD_GAP)
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
	page.bestRunsButton = createWeeklyBestRunsButton(
		page.weeklyCard,
		page.bestRunsPanel,
		function()
			return page.currentCard and page.currentCard._gfData
		end)
	page.bestRunsButton:SetPoint("LEFT", page.weeklyCard.Title, "RIGHT",
		WEEKLY_BEST_BUTTON_GAP, 0)

	page.warbandTitle = createSectionTitle(page.content, "")
	page.warbandTitle:SetPoint("TOPLEFT", page.currentArea, "BOTTOMLEFT",
		-TITLE_BACKGROUND_BLEED_LEFT, -CURRENT_AREA_TO_WARBAND_TITLE_GAP)
	page.warbandTitle:SetPoint("TOPRIGHT", page.currentArea, "BOTTOMRIGHT", 0, -CURRENT_AREA_TO_WARBAND_TITLE_GAP)
	page.carpoolTitle = page.warbandTitle
	page.otherTitle = createSectionTitle(page.content, "")
	page.dragHint = createText(page.carpoolTitle, "GameFontDisable", 11, "")
	page.dragHint:SetPoint("RIGHT", page.carpoolTitle, "RIGHT", -TITLE_TEXT_INSET_X, 0)
	page.dragHint:SetWidth(360)
	page.dragHint:SetJustifyH("RIGHT")
	page.dragHint:SetTextColor(0.62, 0.59, 0.52, 1)

	page.groupZones = {
		[CharacterPage.DRAG.carpool] = self:CreateCharacterGroupDropZone(page.content),
		[CharacterPage.DRAG.other] = self:CreateCharacterGroupDropZone(page.content),
	}
	for _, zone in pairs(page.groupZones) do
		zone:SetFrameLevel((page.content:GetFrameLevel() or 0) + 1)
	end
	page.dragCursorAnchor = CreateFrame("Frame", nil, UIParent)
	page.dragCursorAnchor:SetSize(1, 1)
	page.dragCursorAnchor:EnableMouse(false)
	page.dragCursorAnchor:Hide()
	page.dragGhostHost = CreateFrame("Frame", nil, page.dragCursorAnchor)
	page.dragGhostHost:SetFrameStrata("TOOLTIP")
	page.dragGhostHost:SetFrameLevel(1999)
	page.dragGhostHost:EnableMouse(false)
	page.dragGhostHost:Hide()
	page.dragGhost = createCharacterCard(page.dragGhostHost, false)
	page.dragGhost:SetPoint("TOPLEFT", page.dragGhostHost, "TOPLEFT")
	page.dragGhost:SetFrameStrata("TOOLTIP")
	page.dragGhost:SetFrameLevel(2000)
	page.dragGhost:SetAlpha(0.94)
	page.dragGhost:EnableMouse(false)
	for _, input in ipairs({
		page.dragGhost.KeyButton,
		page.dragGhost.TeleportButton,
		page.dragGhost.CarpoolCheck,
	}) do
		if input and input.EnableMouse then
			input:EnableMouse(false)
		end
	end
	for _, roleToggle in pairs(page.dragGhost.RoleToggles or {}) do
		roleToggle:EnableMouse(false)
	end
	GF.MythicPlusCharacterVaultGrid:SetMouseEnabled(page.dragGhost.VaultGrid, false)
	GF.MythicPlusCharacterCurrencyBar:SetMouseEnabled(page.dragGhost.CrestBar, false)
	if page.dragGhost._gfMythicCharacterHover then
		page.dragGhost._gfMythicCharacterHover.frame:Hide()
	end
	page.dropLine = page.content:CreateTexture(nil, "OVERLAY", nil, 7)
	if GF.UI.TrySetAtlas(
		page.dropLine,
		CharacterPage.DRAG.insertAtlas,
		false)
	then
		page.dropLine:SetRotation(math.pi * 0.5)
	else
		page.dropLine:SetColorTexture(1, 0.82, 0, 1)
	end
	page.dropLine:Hide()
	page.swapHighlight = CreateFrame("Frame", nil, page.content)
	page.swapHighlight:SetFrameLevel((page.content:GetFrameLevel() or 0) + 90)
	page.swapHighlight:EnableMouse(false)
	page.swapHighlight.Base = createStretchLayer(
		page.swapHighlight,
		FRAME_ATLASES.border,
		"OVERLAY",
		6,
		{ displayCapWidth = FRAME_DISPLAY_CAP_WIDTH })
	page.swapHighlight.Glow = createStretchLayer(
		page.swapHighlight,
		FRAME_ATLASES.hover,
		"OVERLAY",
		7,
		{ displayCapWidth = FRAME_DISPLAY_CAP_WIDTH })
	for _, key in ipairs(STRETCH_LAYER_KEYS) do
		page.swapHighlight.Glow[key]:SetBlendMode("ADD")
	end
	setLayerAlpha(page.swapHighlight.Base, 1)
	setLayerAlpha(page.swapHighlight.Glow, 0.74)
	page.swapHighlight:Hide()
	page.dragInputDriver = CreateFrame("Frame", nil, page.frame)
	page.dragInputDriver:SetPoint("TOPLEFT", page.frame, "TOPLEFT")
	page.dragInputDriver:SetSize(1, 1)
	page.dragInputDriver:EnableMouse(false)
	page.dragInputDriver:Hide()

	page.emptyContainer = CreateFrame("Frame", nil, page.content)
	page.emptySpinner = CreateFrame("Frame", nil, page.emptyContainer)
	page.emptySpinner:SetPoint("CENTER", page.emptyContainer, "CENTER", 0, 17)
	page.emptySpinner:SetSize(40, 40)
	page.emptySpinner.Ring = page.emptySpinner:CreateTexture(nil, "ARTWORK")
	if not GF.UI.TrySetAtlas(
		page.emptySpinner.Ring,
		"plunderstorm-glues-queue-pending-spinner-back",
		false
	) then
		page.emptySpinner.Ring:SetTexture(GF.WHITE_TEXTURE)
		page.emptySpinner.Ring:SetVertexColor(0.82, 0.75, 0.54, 0.4)
	end
	page.emptySpinner.Ring:SetAllPoints(page.emptySpinner)
	page.emptySpinner.Icons = {}
	page.emptySpinner.IconAnimations = {}
	for phaseIndex, atlas in ipairs(CharacterPage.EMPTY_SQUAD_ICON_ATLASES) do
		local icon = page.emptySpinner:CreateTexture(nil, "OVERLAY")
		if not GF.UI.TrySetAtlas(icon, atlas, false) then
			icon:SetTexture(
				"Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon"
			)
		end
		icon:SetAllPoints(page.emptySpinner)
		icon:SetVertexColor(1, 0.82, 0, 1)
		icon:SetAlpha(0)
		page.emptySpinner.Icons[phaseIndex] = icon
		page.emptySpinner.IconAnimations[phaseIndex] =
			self:CreateEmptySquadFadeAnimation(icon, phaseIndex)
	end
	page.emptySpinner.Anim = page.emptySpinner.Ring:CreateAnimationGroup()
	page.emptySpinner.Anim:SetLooping("REPEAT")
	page.emptySpinner.Rotation =
		page.emptySpinner.Anim:CreateAnimation("Rotation")
	page.emptySpinner.Rotation:SetDuration(1.2)
	page.emptySpinner.Rotation:SetDegrees(-360)
	function page.emptySpinner:Play()
		if not self.Anim.IsPlaying or not self.Anim:IsPlaying() then
			self.Anim:Play()
		end
		for index in ipairs(self.Icons) do
			local animation = self.IconAnimations[index]
			if animation
				and (not animation.IsPlaying or not animation:IsPlaying())
			then
				animation:Play()
			end
		end
	end
	function page.emptySpinner:Stop()
		if self.Anim.IsPlaying and self.Anim:IsPlaying() then
			self.Anim:Stop()
		end
		for index in ipairs(self.Icons) do
			local animation = self.IconAnimations[index]
			if animation and animation.IsPlaying and animation:IsPlaying() then
				animation:Stop()
			end
			self.Icons[index]:SetAlpha(0)
		end
	end
	page.emptyContainer:SetScript("OnShow", function()
		page.emptySpinner:Play()
	end)
	page.emptyContainer:SetScript("OnHide", function()
		page.emptySpinner:Stop()
	end)

	page.emptyTitle = createCardText(
		page.emptyContainer,
		"GameFontHighlight",
		14,
		""
	)
	page.emptyTitle:SetPoint("TOPLEFT", page.emptySpinner, "BOTTOMLEFT", -260, -4)
	page.emptyTitle:SetPoint("TOPRIGHT", page.emptySpinner, "BOTTOMRIGHT", 260, -4)
	page.emptyTitle:SetHeight(14)
	page.emptyTitle:SetJustifyH("CENTER")
	page.emptyTitle:SetJustifyV("MIDDLE")
	page.emptyTitle:SetTextColor(0.86, 0.84, 0.78, 1)

	page.emptyDescription = createCardText(
		page.emptyContainer,
		"GameFontDisable",
		12,
		""
	)
	page.emptyDescription:SetPoint(
		"TOPLEFT",
		page.emptyTitle,
		"BOTTOMLEFT",
		0,
		-4
	)
	page.emptyDescription:SetPoint(
		"TOPRIGHT",
		page.emptyTitle,
		"BOTTOMRIGHT",
		0,
		-4
	)
	page.emptyDescription:SetHeight(12)
	page.emptyDescription:SetJustifyH("CENTER")
	page.emptyDescription:SetJustifyV("MIDDLE")
	page.emptyDescription:SetTextColor(0.5, 0.5, 0.5, 1)
	page.cards = {}
	page.visibleCardCount = 0
	page.groupCounts = {
		[CharacterPage.DRAG.carpool] = 0,
		[CharacterPage.DRAG.other] = 0,
	}
	page.totalWarbandCount = 0

	layout = function()
		local viewportWidth = math.max(1, math.floor(page.scroll:GetWidth() or 900))
		page.content:SetWidth(viewportWidth)
		local width = math.max(1, viewportWidth - TITLE_BACKGROUND_BLEED_LEFT)
		-- Keep the current title as the sampling reference. At some effective
		-- scales the middle title lands on a fractional physical pixel while the
		-- first and third titles are already aligned; offset only each atlas
		-- texture, never its frame or label.
		alignTitleBackgroundPixelPhase(page.currentTitle, 0)
		alignTitleBackgroundPixelPhase(
			page.warbandTitle,
			-CURRENT_TO_WARBAND_TITLE_DISTANCE)
		local topCardWidth = math.max(1, math.floor((width - CARD_GAP_X) / 2))
		page.currentCard:SetSize(topCardWidth, CARD_HEIGHT)
		page.weeklyCard:SetSize(topCardWidth, CARD_HEIGHT)

		local cardWidth = math.max(CARD_MIN_WIDTH, math.floor((width - CARD_GAP_X) / 2))
		page._cardWidth = cardWidth
		for index = 1, page.visibleCardCount do
			local card = page.cards[index]
			card:ClearAllPoints()
			card:SetSize(cardWidth, CARD_HEIGHT)
			card:SetFrameLevel((page.content:GetFrameLevel() or 0) + 5)
			local groupIndex = card._gfGroupIndex or 1
			local column = (groupIndex - 1) % 2
			local row = math.floor((groupIndex - 1) / 2)
			local zone = page.groupZones[card._gfManagedGroup]
			card:SetPoint("TOPLEFT", zone, "TOPLEFT",
				column * (cardWidth + CARD_GAP_X),
				-row * (CARD_HEIGHT + CARD_GAP_Y))
		end

		local function getGroupHeight(groupKey)
			local rows = math.ceil((page.groupCounts[groupKey] or 0) / 2)
			if rows <= 0 then
				if groupKey == CharacterPage.DRAG.carpool
					and page.totalWarbandCount > 0
				then
					return CharacterPage.DRAG.carpoolEmptyHeight
				end
				return CharacterPage.DRAG.emptyHeight
			end
			return rows * CARD_HEIGHT + math.max(0, rows - 1) * CARD_GAP_Y
		end
		local fixedTop = 20 + TITLE_HEIGHT + TITLE_TO_CARD_GAP + CARD_HEIGHT
			+ CURRENT_AREA_TO_WARBAND_TITLE_GAP + TITLE_HEIGHT
		local viewHeight = page.scroll:GetHeight() or 1
		if page.totalWarbandCount > 0 then
			local carpoolZone = page.groupZones[CharacterPage.DRAG.carpool]
			local otherZone = page.groupZones[CharacterPage.DRAG.other]
			local showOtherGroup =
				(page.groupCounts[CharacterPage.DRAG.other] or 0) > 0
			local carpoolHeight = getGroupHeight(CharacterPage.DRAG.carpool)
			carpoolZone:ClearAllPoints()
			carpoolZone:SetPoint(
				"TOPLEFT", page.carpoolTitle, "BOTTOMLEFT",
				TITLE_BACKGROUND_BLEED_LEFT, -TITLE_TO_CARD_GAP)
			carpoolZone:SetPoint(
				"TOPRIGHT", page.carpoolTitle, "BOTTOMRIGHT", 0, -TITLE_TO_CARD_GAP)
			carpoolZone:SetHeight(carpoolHeight)
			carpoolZone.EmptyLabel:ClearAllPoints()
			carpoolZone.EmptyLabel:SetPoint(
				"CENTER",
				page.carpoolTitle,
				"BOTTOM",
				TITLE_BACKGROUND_BLEED_LEFT / 2,
				-(TITLE_TO_CARD_GAP + carpoolHeight
					+ CharacterPage.DRAG.groupGap + TITLE_HEIGHT) * 0.5)

			carpoolZone:Show()
			page.dragHint:Show()
			carpoolZone.EmptyLabel:SetShown(
				(page.groupCounts[CharacterPage.DRAG.carpool] or 0) == 0)
			local managedHeight = TITLE_TO_CARD_GAP + carpoolHeight
				+ CARD_BOTTOM_GAP
			if showOtherGroup then
				local otherHeight = getGroupHeight(CharacterPage.DRAG.other)
				local otherTitleDistance = CURRENT_TO_WARBAND_TITLE_DISTANCE
					+ TITLE_HEIGHT + TITLE_TO_CARD_GAP + carpoolHeight
					+ CharacterPage.DRAG.groupGap
				alignTitleBackgroundPixelPhase(
					page.otherTitle,
					-otherTitleDistance)
				page.otherTitle:ClearAllPoints()
				page.otherTitle:SetPoint(
					"TOPLEFT",
					carpoolZone,
					"BOTTOMLEFT",
					-TITLE_BACKGROUND_BLEED_LEFT,
					-CharacterPage.DRAG.groupGap)
				page.otherTitle:SetPoint(
					"TOPRIGHT",
					carpoolZone,
					"BOTTOMRIGHT",
					0,
					-CharacterPage.DRAG.groupGap)
				otherZone:ClearAllPoints()
				otherZone:SetPoint(
					"TOPLEFT",
					page.otherTitle,
					"BOTTOMLEFT",
					TITLE_BACKGROUND_BLEED_LEFT,
					-TITLE_TO_CARD_GAP)
				otherZone:SetPoint(
					"TOPRIGHT",
					page.otherTitle,
					"BOTTOMRIGHT",
					0,
					-TITLE_TO_CARD_GAP)
				otherZone:SetHeight(otherHeight)
				otherZone.EmptyLabel:Hide()
				page.otherTitle:Show()
				otherZone:Show()
				managedHeight = managedHeight
					+ CharacterPage.DRAG.groupGap + TITLE_HEIGHT
					+ TITLE_TO_CARD_GAP + otherHeight
			else
				page.otherTitle:Hide()
				otherZone.EmptyLabel:Hide()
				otherZone:Hide()
			end
			page.content:SetHeight(math.max(viewHeight, fixedTop + managedHeight))
		else
			page.otherTitle:Hide()
			page.groupZones[CharacterPage.DRAG.carpool]:Hide()
			page.groupZones[CharacterPage.DRAG.other]:Hide()
			page.dragHint:Hide()
			page.content:SetHeight(math.max(
				viewHeight,
				fixedTop + TITLE_TO_CARD_GAP + CARD_BOTTOM_GAP))
		end

		page.emptyContainer:ClearAllPoints()
		page.emptyContainer:SetPoint(
			"TOPLEFT",
			page.warbandTitle,
			"BOTTOMLEFT",
			TITLE_BACKGROUND_BLEED_LEFT,
			0
		)
		page.emptyContainer:SetPoint(
			"BOTTOMRIGHT",
			page.content,
			"BOTTOMRIGHT",
			-8,
			0
		)
		if page.scroll._gfUpdateRange then
			page.scroll:_gfUpdateRange()
		end
	end

	local function getScaledFrameRect(frame)
		if frame and frame.GetScaledRect then
			local left, bottom, width, height = frame:GetScaledRect()
			if left and bottom and width and height then
				return left, bottom, width, height
			end
		end
		if not frame then
			return nil
		end
		local left = frame.GetLeft and frame:GetLeft()
		local bottom = frame.GetBottom and frame:GetBottom()
		local width = frame.GetWidth and frame:GetWidth()
		local height = frame.GetHeight and frame:GetHeight()
		local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
		if left and bottom and width and height then
			return left * scale, bottom * scale, width * scale, height * scale
		end
		return nil
	end

	local function pointInsideFrame(frame, cursorX, cursorY)
		if not frame or (frame.IsShown and not frame:IsShown()) then
			return false
		end
		local left, bottom, width, height = getScaledFrameRect(frame)
		return left ~= nil
			and cursorX >= left
			and cursorX <= left + width
			and cursorY >= bottom
			and cursorY <= bottom + height
	end

	local function getFrameGrabPoint(frame, cursorX, cursorY)
		local left, bottom, width, height = getScaledFrameRect(frame)
		if not left or width <= 0 or height <= 0 then
			return nil, nil, nil, nil
		end
		local grabPhysicalX = math.max(0, math.min(
			width,
			cursorX - left))
		local grabPhysicalY = math.max(0, math.min(
			height,
			bottom + height - cursorY))
		return grabPhysicalX, grabPhysicalY, width, height
	end

	local function isDebugCharacter(data)
		return data and (
			data.isDebugTest == true
			or data.isTest == true
		)
	end

	local function canMoveCharacter(data)
		if isDebugCharacter(data) then
			local debugService = GF.MythicPlusDebugService
			return debugService
				and debugService.IsEnabled
				and debugService:IsEnabled()
				and debugService.SetLocalCarpoolEnabled
		end
		local store = GF.MythicPlusCharacterStore
		return store and store.MoveCharacter
	end

	function page:ClearCharacterDropVisuals()
		self.dropLine:Hide()
		self.swapHighlight:Hide()
		local targetCard = self.dropSwapCard
		self.dropSwapCard = nil
		if targetCard then
			targetCard:SetAlpha(1)
			local hover = targetCard._gfMythicCharacterHover
			if hover then
				hover.frame:SetShown(
					not self.characterDrag
						and targetCard.IsMouseOver
						and targetCard:IsMouseOver())
			end
		end
	end

	function page:SetCharacterCardInputMouseEnabled(enabled)
		for index = 1, self.visibleCardCount do
			local card = self.cards[index]
			for _, input in ipairs({
				card,
				card and card.KeyButton,
				card and card.TeleportButton,
				card and card.CarpoolCheck,
			}) do
				if input and input.EnableMouse then
					input:EnableMouse(enabled)
				end
			end
			for _, roleToggle in pairs(
				card and card.RoleToggles or {})
			do
				roleToggle:EnableMouse(enabled)
			end
			GF.MythicPlusCharacterVaultGrid:SetMouseEnabled(card and card.VaultGrid, enabled)
			GF.MythicPlusCharacterCurrencyBar:SetMouseEnabled(card and card.CrestBar, enabled)
		end
	end

	function page:CancelCharacterDrag(forceTooltipHide)
		local state = self.characterDrag
		local pending = self.characterDragPending
		local hadGesture = state ~= nil or pending ~= nil
		self.characterDrag = nil
		self.characterDragPending = nil
		self:ClearCharacterDropVisuals()
		self:SetCharacterCardInputMouseEnabled(true)
		if state and state.sourceCard then
			state.sourceCard:SetAlpha(1)
		end
		if state and state.restoreInputSourceEnabled
			and state.inputSource
			and state.inputSource.SetEnabled
		then
			state.inputSource:SetEnabled(true)
		end
		if self.dragInputDriver then
			self.dragInputDriver:SetScript("OnUpdate", nil)
			self.dragInputDriver:Hide()
		end
		if self.dragGhost then
			self.dragGhost:SetScript("OnUpdate", nil)
			self.dragGhost:Hide()
		end
		if self.dragGhostHost then
			self.dragGhostHost:Hide()
		end
		if self.dragCursorAnchor then
			self.dragCursorAnchor:Hide()
		end
		if forceTooltipHide or hadGesture then
			GameTooltip_Hide()
		end
	end

	function page:GetCharacterDropCards(groupKey)
		local state = self.characterDrag
		local targetCards = {}
		for index = 1, self.visibleCardCount do
			local card = self.cards[index]
			if card ~= (state and state.sourceCard)
				and card._gfManagedGroup == groupKey
				and card:IsShown()
			then
				targetCards[#targetCards + 1] = card
			end
		end
		table.sort(targetCards, function(left, right)
			return (left._gfGroupIndex or 0) < (right._gfGroupIndex or 0)
		end)
		return targetCards
	end

	function page:GetCharacterInsertionRect(targetGroup, targetIndex, targetCards)
		targetCards = targetCards or self:GetCharacterDropCards(targetGroup)
		local targetCard = targetCards[targetIndex]
		if targetCard then
			local left, bottom, _, height = getScaledFrameRect(targetCard)
			if not left then
				return nil
			end
			local scale = targetCard.GetEffectiveScale
				and targetCard:GetEffectiveScale() or 1
			local column = ((targetCard._gfGroupIndex or 1) - 1) % 2
			local offsetX = column == 1 and -CARD_GAP_X * scale * 0.5 or 0
			return left + offsetX, bottom, height
		end
		local previousCard = targetCards[#targetCards]
		if previousCard then
			local left, bottom, width, height = getScaledFrameRect(previousCard)
			if not left then
				return nil
			end
			local scale = previousCard.GetEffectiveScale
				and previousCard:GetEffectiveScale() or 1
			local column = ((previousCard._gfGroupIndex or 1) - 1) % 2
			local offsetX = column == 0 and CARD_GAP_X * scale * 0.5 or 0
			return left + width + offsetX, bottom, height
		end
		local zone = self.groupZones[targetGroup]
		local left, bottom, _, height = getScaledFrameRect(zone)
		if not left then
			return nil
		end
		local scale = zone.GetEffectiveScale and zone:GetEffectiveScale() or 1
		local lineHeight = math.min(height, CARD_HEIGHT * scale)
		return left, bottom + height - lineHeight, lineHeight
	end

	local function canSwapCharacterCards(state, targetCard)
		local targetData = targetCard and targetCard._gfData
		if not state or not targetData
			or not targetData.key
			or targetData.key == state.sourceKey
			or not canMoveCharacter(targetData)
		then
			return false
		end
		local targetIsDebug = isDebugCharacter(targetData)
		if state.sourceGroup ~= targetCard._gfManagedGroup
			and state.isDebugCharacter ~= targetIsDebug
		then
			return false
		end
		return true
	end

	function page:GetCharacterDragTarget(cursorX, cursorY)
		local state = self.characterDrag
		if not state then
			return nil
		end
		local targetGroup
		for _, groupKey in ipairs({
			CharacterPage.DRAG.carpool,
			CharacterPage.DRAG.other,
		}) do
			if pointInsideFrame(self.groupZones[groupKey], cursorX, cursorY) then
				targetGroup = groupKey
				break
			end
		end
		if not targetGroup then
			return nil
		end

		local targetCards = self:GetCharacterDropCards(targetGroup)
		local zone = self.groupZones[targetGroup]
		local scale = zone.GetEffectiveScale and zone:GetEffectiveScale() or 1
		local insertHitWidth = CharacterPage.DRAG.insertHitWidth * scale
		for targetIndex = 1, #targetCards + 1 do
			local lineX, lineBottom, lineHeight =
				self:GetCharacterInsertionRect(
					targetGroup,
					targetIndex,
					targetCards)
			if lineX
				and math.abs(cursorX - lineX) <= insertHitWidth
				and cursorY >= lineBottom
				and cursorY <= lineBottom + lineHeight
			then
				return {
					mode = "insert",
					group = targetGroup,
					index = targetIndex,
				}
			end
		end
		for _, targetCard in ipairs(targetCards) do
			if pointInsideFrame(targetCard, cursorX, cursorY)
				and canSwapCharacterCards(state, targetCard)
			then
				local targetData = targetCard._gfData
				return {
					mode = "swap",
					group = targetCard._gfManagedGroup,
					card = targetCard,
					key = targetData.key,
					isDebugCharacter = isDebugCharacter(targetData),
				}
			end
		end
		return nil
	end

	function page:ShowCharacterInsertionIndicator(targetGroup, targetIndex)
		self:ClearCharacterDropVisuals()
		local zone = self.groupZones[targetGroup]
		if not zone then
			return
		end
		local targetCards = self:GetCharacterDropCards(targetGroup)
		local line = self.dropLine
		line:ClearAllPoints()
		local targetCard = targetCards[targetIndex]
		if targetCard then
			local column = ((targetCard._gfGroupIndex or 1) - 1) % 2
			local offsetX = column == 1 and -CARD_GAP_X * 0.5 or 0
			line:SetPoint("TOP", targetCard, "TOPLEFT", offsetX, 0)
			line:SetSize(CharacterPage.DRAG.insertLineWidth, CARD_HEIGHT)
		elseif #targetCards > 0 then
			local previousCard = targetCards[#targetCards]
			local column = ((previousCard._gfGroupIndex or 1) - 1) % 2
			local offsetX = column == 0 and CARD_GAP_X * 0.5 or 0
			line:SetPoint("TOP", previousCard, "TOPRIGHT", offsetX, 0)
			line:SetSize(CharacterPage.DRAG.insertLineWidth, CARD_HEIGHT)
		else
			line:SetPoint("TOP", zone, "TOPLEFT", 0, 0)
			line:SetSize(CharacterPage.DRAG.insertLineWidth, CARD_HEIGHT)
		end
		line:Show()
	end

	function page:ShowCharacterSwapIndicator(targetCard)
		self:ClearCharacterDropVisuals()
		if not targetCard then
			return
		end
		self.dropSwapCard = targetCard
		targetCard:SetAlpha(CharacterPage.DRAG.swapAlpha)
		if targetCard._gfMythicCharacterHover then
			targetCard._gfMythicCharacterHover.frame:Hide()
		end
		local highlight = self.swapHighlight
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", targetCard, "TOPLEFT")
		highlight:SetPoint("BOTTOMRIGHT", targetCard, "BOTTOMRIGHT")
		local r, g, b = UI.GetClassColor(
			targetCard._gfData and targetCard._gfData.classFile)
		setLayerColor(highlight.Base, 1, 1, 1, 1)
		setLayerColor(highlight.Glow, r, g, b, 1)
		highlight:Show()
	end

	function page:UpdateCharacterDrag(elapsed)
		local state = self.characterDrag
		if not state or not GetCursorPosition then
			return
		end
		GameTooltip_Hide()
		local cursorX, cursorY = GetCursorPosition()
		-- Keep the floating card on a dedicated cursor anchor. The card's
		-- pickup offset is frozen once in physical pixels when the button is
		-- pressed, so frame-size rounding and panel scale cannot feed back into
		-- its position while the cursor moves. Blizzard's helper also accounts
		-- for the horizontal UI origin shift used by letterboxed displays.
		if InputUtil and InputUtil.AnchorRegionToCursor then
			InputUtil.AnchorRegionToCursor(
				self.dragCursorAnchor,
				"BOTTOMLEFT")
		else
			local uiScale = UIParent.GetEffectiveScale
				and UIParent:GetEffectiveScale() or 1
			local rootX = cursorX / uiScale
			local rootY = cursorY / uiScale
			if UIParent.GetPointByName then
				local originX = select(4,
					UIParent:GetPointByName("TOPLEFT"))
				if type(originX) == "number" then
					rootX = rootX - originX
				end
			end
			self.dragCursorAnchor:ClearAllPoints()
			self.dragCursorAnchor:SetPoint(
				"BOTTOMLEFT",
				UIParent,
				"BOTTOMLEFT",
				rootX,
				rootY)
		end

		local scrollLeft, scrollBottom, scrollWidth, scrollHeight =
			getScaledFrameRect(self.scroll)
		if scrollLeft and cursorX >= scrollLeft
			and cursorX <= scrollLeft + scrollWidth
		then
			local distanceToTop = scrollBottom + scrollHeight - cursorY
			local distanceToBottom = cursorY - scrollBottom
			local delta = 0
			if distanceToTop >= 0
				and distanceToTop < CharacterPage.DRAG.edgeScrollRange
			then
				delta = -CharacterPage.DRAG.edgeScrollSpeed
					* (1 - distanceToTop / CharacterPage.DRAG.edgeScrollRange)
			elseif distanceToBottom >= 0
				and distanceToBottom < CharacterPage.DRAG.edgeScrollRange
			then
				delta = CharacterPage.DRAG.edgeScrollSpeed
					* (1 - distanceToBottom / CharacterPage.DRAG.edgeScrollRange)
			end
			if delta ~= 0 and self.scroll._gfSetScrollValue then
				self.scroll._gfSetScrollValue(
					(self.scroll._gfGetScrollValue() or 0)
						+ delta * (elapsed or 0))
			end
		end

		local target = self:GetCharacterDragTarget(cursorX, cursorY)
		state.dropMode = target and target.mode or nil
		state.targetGroup = target and target.group or nil
		state.targetIndex = target and target.index or nil
		state.targetKey = target and target.key or nil
		state.targetIsDebugCharacter =
			target and target.isDebugCharacter or false
		if target and target.mode == "swap" then
			self:ShowCharacterSwapIndicator(target.card)
		elseif target and target.mode == "insert" then
			self:ShowCharacterInsertionIndicator(
				target.group,
				target.index)
		else
			self:ClearCharacterDropVisuals()
		end
	end

	function page:BeginCharacterDrag(card, inputSource)
		local data = card and card._gfData
		local pending = self.characterDragPending
		self.characterDragPending = nil
		inputSource = inputSource or (pending and pending.inputSource)
		if self.characterDrag
			or not data
			or not data.key
		then
			return
		end
		if not canMoveCharacter(data) then
			return
		end
		GF.UI.CancelSmoothWheelScrolling(self.scroll)
		local grabPhysicalX = pending and pending.grabPhysicalX
		local grabPhysicalY = pending and pending.grabPhysicalY
		local sourcePhysicalWidth = pending and pending.sourcePhysicalWidth
		local sourcePhysicalHeight = pending and pending.sourcePhysicalHeight
		if grabPhysicalX == nil or grabPhysicalY == nil
			or sourcePhysicalWidth == nil or sourcePhysicalHeight == nil
		then
			local cursorX, cursorY = GetCursorPosition()
			grabPhysicalX, grabPhysicalY,
				sourcePhysicalWidth, sourcePhysicalHeight =
				getFrameGrabPoint(card, cursorX, cursorY)
		end
		GameTooltip_Hide()
		self.characterDrag = {
			sourceCard = card,
			sourceKey = data.key,
			sourceGroup = card._gfManagedGroup,
			sourceGroupIndex = card._gfGroupIndex or 1,
			inputSource = inputSource,
			grabPhysicalX = grabPhysicalX,
			grabPhysicalY = grabPhysicalY,
			isDebugCharacter = isDebugCharacter(data),
		}
		self:SetCharacterCardInputMouseEnabled(false)
		if inputSource
			and inputSource.IsEnabled
			and inputSource.SetEnabled
			and inputSource:IsEnabled()
		then
			inputSource:SetEnabled(false)
			self.characterDrag.restoreInputSourceEnabled = true
		end
		card:SetAlpha(0.35)
		if card._gfMythicCharacterHover then
			card._gfMythicCharacterHover.frame:Hide()
		end
		local uiScale = UIParent.GetEffectiveScale
			and UIParent:GetEffectiveScale() or 1
		local sourceScale = card.GetEffectiveScale
			and card:GetEffectiveScale() or uiScale
		local anchorScale = self.dragCursorAnchor.GetEffectiveScale
			and self.dragCursorAnchor:GetEffectiveScale() or uiScale
		local ghostPhysicalWidth = sourcePhysicalWidth
			or card:GetWidth() * sourceScale
		local ghostPhysicalHeight = sourcePhysicalHeight
			or card:GetHeight() * sourceScale
		self.dragGhostHost:ClearAllPoints()
		self.dragGhostHost:SetPoint(
			"TOPLEFT",
			self.dragCursorAnchor,
			"BOTTOMLEFT",
			-(grabPhysicalX or ghostPhysicalWidth * 0.5) / anchorScale,
			(grabPhysicalY or ghostPhysicalHeight * 0.5) / anchorScale)
		self.dragGhostHost:SetSize(
			ghostPhysicalWidth / anchorScale,
			ghostPhysicalHeight / anchorScale)
		self.dragGhost:SetScale(sourceScale / anchorScale)
		self.dragGhost:SetSize(card:GetWidth(), card:GetHeight())
		bindCharacterCard(self.dragGhost, data)
		self.dragGhost:Show()
		self.dragCursorAnchor:Show()
		self.dragGhostHost:Show()
		self.dragInputDriver:SetScript("OnUpdate", function(_, updateElapsed)
			self:UpdateCharacterDragInput(updateElapsed)
		end)
		self.dragInputDriver:Show()
		self:UpdateCharacterDrag(0)
	end

	function page:ArmCharacterDrag(card, inputSource, mouseButton)
		local data = card and card._gfData
		if mouseButton ~= "LeftButton"
			or self.characterDrag
			or not data
			or not data.key
			or not canMoveCharacter(data)
			or not GetCursorPosition
		then
			return
		end
		local cursorX, cursorY = GetCursorPosition()
		local grabPhysicalX, grabPhysicalY,
			sourcePhysicalWidth, sourcePhysicalHeight =
			getFrameGrabPoint(card, cursorX, cursorY)
		self.characterDragPending = {
			card = card,
			inputSource = inputSource,
			startX = cursorX,
			startY = cursorY,
			grabPhysicalX = grabPhysicalX,
			grabPhysicalY = grabPhysicalY,
			sourcePhysicalWidth = sourcePhysicalWidth,
			sourcePhysicalHeight = sourcePhysicalHeight,
		}
		self.dragInputDriver:SetScript("OnUpdate", function(_, elapsed)
			self:UpdateCharacterDragInput(elapsed)
		end)
		self.dragInputDriver:Show()
	end

	function page:UpdateCharacterDragInput(elapsed)
		local leftButtonDown = IsMouseButtonDown
			and IsMouseButtonDown("LeftButton") == true
		local pending = self.characterDragPending
		if pending then
			if not leftButtonDown or not GetCursorPosition then
				self.characterDragPending = nil
				self.dragInputDriver:SetScript("OnUpdate", nil)
				self.dragInputDriver:Hide()
				return
			end
			local cursorX, cursorY = GetCursorPosition()
			local deltaX = cursorX - pending.startX
			local deltaY = cursorY - pending.startY
			local threshold = CharacterPage.DRAG.startDistance
			if deltaX * deltaX + deltaY * deltaY
				>= threshold * threshold
			then
				self:BeginCharacterDrag(
					pending.card,
					pending.inputSource)
			end
		end
		if self.characterDrag then
			if not leftButtonDown then
				self:FinishCharacterDrag(true)
				return
			end
			self:UpdateCharacterDrag(elapsed)
		elseif not self.characterDragPending then
			self.dragInputDriver:SetScript("OnUpdate", nil)
			self.dragInputDriver:Hide()
		end
	end

	function page:ApplyDebugCharacterOrder(groups)
		local debugService = GF.MythicPlusDebugService
		if not (debugService
			and debugService.IsEnabled
			and debugService:IsEnabled())
		then
			self.debugCharacterOrder = nil
			return groups
		end
		local previousOrder = self.debugCharacterOrder or {
			[CharacterPage.DRAG.carpool] = {},
			[CharacterPage.DRAG.other] = {},
		}
		local nextOrder = {
			[CharacterPage.DRAG.carpool] = {},
			[CharacterPage.DRAG.other] = {},
		}
		for _, groupKey in ipairs({
			CharacterPage.DRAG.carpool,
			CharacterPage.DRAG.other,
		}) do
			local entries = groups[groupKey] or {}
			local orderIndex = {}
			for index, key in ipairs(previousOrder[groupKey] or {}) do
				orderIndex[key] = index
			end
			local fallbackIndex = {}
			for index, entry in ipairs(entries) do
				fallbackIndex[entry.key] = index
			end
			table.sort(entries, function(left, right)
				local leftIndex = orderIndex[left.key]
				local rightIndex = orderIndex[right.key]
				if leftIndex ~= rightIndex then
					if leftIndex == nil then
						return false
					end
					if rightIndex == nil then
						return true
					end
					return leftIndex < rightIndex
				end
				return (fallbackIndex[left.key] or 0)
					< (fallbackIndex[right.key] or 0)
			end)
			for _, entry in ipairs(entries) do
				nextOrder[groupKey][#nextOrder[groupKey] + 1] = entry.key
			end
		end
		self.debugCharacterOrder = nextOrder
		return groups
	end

	function page:MoveDebugCharacter(key, targetGroup, targetIndex)
		local debugService = GF.MythicPlusDebugService
		if not (debugService
			and debugService.IsEnabled
			and debugService:IsEnabled()
			and debugService.SetLocalCarpoolEnabled)
		then
			return false
		end
		local groups = self:ApplyDebugCharacterOrder(
			CharacterPage:GetWarbandCharacterGroups())
		local movingEntry
		for _, groupKey in ipairs({
			CharacterPage.DRAG.carpool,
			CharacterPage.DRAG.other,
		}) do
			for index = #(groups[groupKey] or {}), 1, -1 do
				if groups[groupKey][index].key == key then
					movingEntry = table.remove(groups[groupKey], index)
				end
			end
		end
		if not movingEntry then
			return false
		end
		local targetEntries = groups[targetGroup]
		if not targetEntries then
			return false
		end
		targetIndex = math.floor(tonumber(targetIndex)
			or (#targetEntries + 1))
		targetIndex = math.max(1, math.min(targetIndex, #targetEntries + 1))
		table.insert(targetEntries, targetIndex, movingEntry)
		self:SetDebugCharacterOrderFromGroups(groups)
		debugService:SetLocalCarpoolEnabled(
			key,
			targetGroup == CharacterPage.DRAG.carpool)
		self:RefreshView()
		return true
	end

	function page:SetDebugCharacterOrderFromGroups(groups)
		self.debugCharacterOrder = {
			[CharacterPage.DRAG.carpool] = {},
			[CharacterPage.DRAG.other] = {},
		}
		for _, groupKey in ipairs({
			CharacterPage.DRAG.carpool,
			CharacterPage.DRAG.other,
		}) do
			for _, entry in ipairs(groups[groupKey]) do
				local order = self.debugCharacterOrder[groupKey]
				order[#order + 1] = entry.key
			end
		end
	end

	function page:SwapDebugCharacters(sourceKey, targetKey)
		local debugService = GF.MythicPlusDebugService
		if not (debugService
			and debugService.IsEnabled
			and debugService:IsEnabled()
			and debugService.SetLocalCarpoolEnabled)
		then
			return false
		end
		local groups = self:ApplyDebugCharacterOrder(
			CharacterPage:GetWarbandCharacterGroups())
		local sourceEntry
		local targetEntry
		local sourceGroup
		local targetGroup
		local sourceIndex
		local targetIndex
		for _, groupKey in ipairs({
			CharacterPage.DRAG.carpool,
			CharacterPage.DRAG.other,
		}) do
			for index, entry in ipairs(groups[groupKey] or {}) do
				if entry.key == sourceKey then
					sourceEntry = entry
					sourceGroup = groupKey
					sourceIndex = index
				elseif entry.key == targetKey then
					targetEntry = entry
					targetGroup = groupKey
					targetIndex = index
				end
			end
		end
		if not sourceEntry or not targetEntry then
			return false
		end
		local sourceIsDebug = isDebugCharacter(sourceEntry)
		local targetIsDebug = isDebugCharacter(targetEntry)
		if sourceGroup ~= targetGroup and sourceIsDebug ~= targetIsDebug then
			return false
		end
		groups[sourceGroup][sourceIndex], groups[targetGroup][targetIndex] =
			targetEntry, sourceEntry
		self:SetDebugCharacterOrderFromGroups(groups)
		if sourceGroup ~= targetGroup then
			debugService:SetLocalCarpoolEnabled(
				sourceKey,
				targetGroup == CharacterPage.DRAG.carpool)
			debugService:SetLocalCarpoolEnabled(
				targetKey,
				sourceGroup == CharacterPage.DRAG.carpool)
		end
		self:RefreshView()
		return true
	end

	function page:FinishCharacterDrag(commit)
		local state = self.characterDrag
		local refreshQueued = state and state.refreshQueued == true
		local dropMode = state and state.dropMode
		local targetGroup = state and state.targetGroup
		local targetIndex = state and state.targetIndex
		local targetKey = state and state.targetKey
		local sourceKey = state and state.sourceKey
		local debugCharacter = state and state.isDebugCharacter == true
		local targetDebugCharacter =
			state and state.targetIsDebugCharacter == true
		self:CancelCharacterDrag()
		if not commit or not sourceKey then
			if refreshQueued then
				self:RefreshView()
			end
			return
		end
		if dropMode == "swap" and targetKey then
			if debugCharacter or targetDebugCharacter then
				self:SwapDebugCharacters(sourceKey, targetKey)
			else
				self.debugCharacterOrder = nil
				GF.MythicPlusCharacterStore:SwapCharacters(
					sourceKey,
					targetKey,
					"character-swap")
			end
		elseif dropMode == "insert" and targetGroup and targetIndex then
			if debugCharacter then
				self:MoveDebugCharacter(
					sourceKey,
					targetGroup,
					targetIndex)
			else
				self.debugCharacterOrder = nil
				GF.MythicPlusCharacterStore:MoveCharacter(
					sourceKey,
					targetGroup,
					targetIndex,
					"character-order")
			end
		end
		if refreshQueued then
			self:RefreshView()
		end
	end

	function page:RefreshCharacterGroupLocale()
		local locale = GF.L or {}
		if self.totalWarbandCount > 0 then
			self.carpoolTitle.Label:SetText(
				locale.MPLUS_CARPOOL_CHARACTERS or "车队角色")
		else
			self.carpoolTitle.Label:SetText(
				locale.MPLUS_WARBAND_CHARACTERS or "战团角色")
		end
		self.otherTitle.Label:SetText(
			locale.MPLUS_OTHER_WARBAND_CHARACTERS or "战团角色")
		self.dragHint:SetText(
			locale.MPLUS_CHARACTER_DRAG_HINT
				or "拖动角色卡片可排序")
		self.groupZones[CharacterPage.DRAG.carpool].EmptyLabel:SetText(
			locale.MPLUS_CARPOOL_GROUP_EMPTY
				or "暂无战团角色加入车队列表")
	end

	function page:RefreshLocale()
		self.currentTitle.Label:SetText((GF.L and GF.L.MPLUS_CURRENT_CHARACTER) or "当前角色")
		self:RefreshCharacterGroupLocale()
		self.emptyTitle:SetText((GF.L and GF.L.MPLUS_CHARACTER_EMPTY)
			or "暂无可同步的战团角色")
		self.emptyDescription:SetText(
			(GF.L and GF.L.MPLUS_CHARACTER_EMPTY_DESC)
				or "登录或切换至其他满级战团角色后，将自动同步更新战团角色数据。"
		)
		if self.currentCard and self.currentCard.RolePrompt then
			self.currentCard.RolePrompt:SetText(
				(GF.L and GF.L.MPLUS_SPECIALIZATION_LOADOUT)
					or "专精天赋"
			)
		end
		TalentLoadoutUI.UpdateSpecializations(self.currentCard)
		TalentLoadoutUI.UpdateDropdown(self.currentCard)
	end

	function page:CancelCarpoolTransition()
		self.carpoolTransition = nil
		for _, card in ipairs(self.cards or {}) do
			CharacterPage:StopCharacterCardFades(card)
		end
	end

	function page:BeginCarpoolTransition(card, data, enabled)
		local key = data and data.key
		if not (card and key) then
			self:RefreshView()
			return
		end
		self:CancelCharacterDrag()
		self:CancelCarpoolTransition()
		local transition = {
			key = key,
			enabled = enabled == true,
			phase = "fadeOut",
			sourceCard = card,
		}
		self.carpoolTransition = transition
		local started = CharacterPage:PlayCharacterCardFade(
			card,
			"out",
			1,
			0,
			CharacterPage.DRAG.fadeOutDuration,
			function()
				if self.carpoolTransition ~= transition then
					return
				end
				transition.phase = "refresh"
				self:RefreshView()
			end)
		if not started then
			transition.phase = "refresh"
			self:RefreshView()
		end
	end

	function page:PlayCarpoolTransitionFadeIn(card, transition)
		if not (card and transition
			and self.carpoolTransition == transition)
		then
			self.carpoolTransition = nil
			return
		end
		transition.phase = "fadeIn"
		local started = CharacterPage:PlayCharacterCardFade(
			card,
			"in",
			0,
			1,
			CharacterPage.DRAG.fadeInDuration,
			function()
				if self.carpoolTransition ~= transition then
					return
				end
				local refreshQueued = transition.refreshQueued == true
				self.carpoolTransition = nil
				if refreshQueued then
					self:RefreshView()
				end
			end)
		if not started then
			self.carpoolTransition = nil
			card:SetAlpha(1)
		end
	end

	function page:RefreshView()
		local transition = self.carpoolTransition
		if transition and transition.phase == "fadeOut" then
			-- The store/debug notification is queued in the same click. The
			-- fade-out completion performs the authoritative regrouping.
			return
		elseif transition and transition.phase == "fadeIn" then
			transition.refreshQueued = true
			return
		end
		if self.characterDrag then
			-- Service notifications may arrive while the physical mouse button is
			-- still held. Rebuilding the card pool here would cancel the active
			-- drag and make the floating card appear to snap back.
			self.characterDrag.refreshQueued = true
			return
		end
		self:CancelCharacterDrag()
		GF.UI.CancelSmoothWheelScrolling(self.scroll)
		local current = GF.MythicPlusCharacterStore and GF.MythicPlusCharacterStore:GetCurrent()
		bindCharacterCard(self.currentCard, current or {})
		bindWeeklyCard(self.weeklyCard)
		local groups = self:ApplyDebugCharacterOrder(
			CharacterPage:GetWarbandCharacterGroups())
		local characters = {}
		for _, groupKey in ipairs({
			CharacterPage.DRAG.carpool,
			CharacterPage.DRAG.other,
		}) do
			self.groupCounts[groupKey] = #(groups[groupKey] or {})
			for groupIndex, character in ipairs(groups[groupKey] or {}) do
				characters[#characters + 1] = {
					data = character,
					groupKey = groupKey,
					groupIndex = groupIndex,
				}
			end
		end
		self.totalWarbandCount = #characters
		self.visibleCardCount = #characters
		while #self.cards < #characters do
			local card = createCharacterCard(self.content, false)
			card.VaultGrid.viewport = self.scroll
			card._gfOnCarpoolChanged = function(changedCard, data, enabled)
				self:BeginCarpoolTransition(changedCard, data, enabled)
			end
			local dragSources = {
				card,
				card.KeyButton,
				card.TeleportButton,
				card.CarpoolCheck,
			}
			for _, roleToggle in pairs(card.RoleToggles or {}) do
				dragSources[#dragSources + 1] = roleToggle
			end
			for _, currency in ipairs(card.CrestBar.Cells) do
				dragSources[#dragSources + 1] = currency
			end
			for _, cell in ipairs(card.VaultGrid.Cells) do
				dragSources[#dragSources + 1] = cell
			end
			for _, category in ipairs(card.VaultGrid.Categories) do
				dragSources[#dragSources + 1] = category
			end
			for _, dragSource in ipairs(dragSources) do
				if dragSource and dragSource.RegisterForDrag then
					dragSource:RegisterForDrag("LeftButton")
					dragSource:SetScript("OnDragStart", function()
						self:BeginCharacterDrag(card, dragSource)
					end)
					dragSource:HookScript("OnMouseDown", function(_, mouseButton)
						self:ArmCharacterDrag(card, dragSource, mouseButton)
					end)
				end
			end
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
			CharacterPage:StopCharacterCardFades(card)
			local entry = characters[index]
			if entry then
				card._gfManagedGroup = entry.groupKey
				card._gfGroupIndex = entry.groupIndex
				bindCharacterCard(card, entry.data)
				card:Show()
			else
				card._gfManagedGroup = nil
				card._gfGroupIndex = nil
				card:Hide()
			end
		end
		self.emptyContainer:SetShown(#characters == 0)
		self:RefreshCharacterGroupLocale()
		layout()
		transition = self.carpoolTransition
		if transition and transition.phase == "refresh" then
			local destinationCard
			for index = 1, self.visibleCardCount do
				local card = self.cards[index]
				if card and card._gfData
					and card._gfData.key == transition.key
				then
					destinationCard = card
					break
				end
			end
			self:PlayCarpoolTransitionFadeIn(
				destinationCard,
				transition)
		end
	end

	function page:Show()
		self:RefreshLocale()
		self:RefreshView()
		self.frame:Show()
	end

	function page:Hide()
		self:CancelCharacterDrag(true)
		self:CancelCarpoolTransition()
		self.frame:Hide()
	end
	page.frame:HookScript("OnHide", function()
		page:CancelCharacterDrag(true)
		page:CancelCarpoolTransition()
	end)

	page:RefreshLocale()
	self.page = page
	return page
end
