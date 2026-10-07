local _, GF = ...

GF.FRAME_W_LEGACY_DEFAULT = 1024
GF.FRAME_PREVIOUS_DEFAULT_W = 1120
GF.FRAME_PREVIOUS_NAV_DEFAULT_H = 550
-- 840px browse columns + 4px ColumnDisplay compensation + current panel/nav/scroll insets.
GF.FRAME_W = 1220
GF.FRAME_H = 597
GF.FRAME_MIN_W = GF.FRAME_W
GF.FRAME_MIN_H = GF.FRAME_H
-- Blizzard_DamageMeter/DamageMeterSourceWindow.xml (right-side detail window).
GF.FRAME_RESIZE_HANDLE_STYLE = {
	normalAtlas = "damagemeters-scalehandle",
	highlightAtlas = "damagemeters-scalehandle-hover",
	pushedAtlas = "damagemeters-scalehandle-pressed",
	size = 60,
	-- Compensate the atlas padding so its visible corner meets our metal border.
	offsetX = 9,
	offsetY = -8,
	fadeDuration = 0.25,
}
GF.FRAME_FOOTER_LAYOUT_VERSION = 3
GF.FRAME_NAV_LAYOUT_VERSION = 2
GF.FRAME_PREVIOUS_DEFAULT_H = 552
GF.FRAME_LEGACY_PANEL_BOTTOM = 24
GF.FRAME_INTERIM_PANEL_BOTTOM = 44
-- Footer versions 1/2 used this inset; later visual changes must not rewrite migration.
GF.FRAME_PREVIOUS_PANEL_BOTTOM = 36
GF.FRAME_INTERIM_DEFAULT_H = 560
GF.PANEL_SCALE_MIN_PCT = 100
GF.PANEL_SCALE_MAX_PCT = 150
GF.PANEL_SCALE_DEFAULT_PCT = 100
GF.FLOAT_SCALE_MIN_PCT = 50
GF.FLOAT_SCALE_MAX_PCT = 150
GF.FLOAT_SCALE_DEFAULT_PCT = 100
GF.FLOAT_DEFAULT_TOP_OFFSET_FRACTION = 0.02
GF.FLOAT_DEFAULT_TOP_OFFSET_FALLBACK = -32
GF.FLOAT_BUTTON_HEIGHT = 40
GF.FLOAT_BUTTON_VISUAL_HEIGHT = 43
GF.INSTANCE_GATEWAY_DEFAULT_GAP = 12
GF.FONT_SCALE_MIN_PCT = 100
GF.FONT_SCALE_MAX_PCT = 150
GF.FONT_SCALE_DEFAULT_PCT = 100
GF.LIST_BACKGROUND_ALPHA_MIN_PCT = 30
GF.LIST_BACKGROUND_ALPHA_MAX_PCT = 100
GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT = 100
GF.LIST_BACKGROUND_NORMAL_ALPHA_DEFAULT_PCT = 30
GF.DEFAULT_REQUIRED_ITEM_LEVEL_MIN = 0
GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT = 0
GF.FRAME_PAD = 4
GF.FRAME_TITLE_TOP = 24
GF.MAIN_WINDOW_BACKGROUND_INSET = 2
GF.MAIN_WINDOW_BACKGROUND_COLOR = { 0, 0, 0, 0.82 }
GF.MAIN_PANEL_INSET_LEFT = 26
GF.MAIN_PANEL_INSET_RIGHT = 26
GF.MAIN_PANEL_INSET_TOP = 64
GF.MAIN_PANEL_INSET_BOTTOM = 26
GF.MAIN_PANEL_BORDER_BOTTOM_OFFSET = -6
-- transmog-tabs-frame keeps a 15px transparent tail below its visible metal edge.
GF.MAIN_PANEL_BORDER_BOTTOM_VISIBLE_INSET = 15
GF.FRAME_FOOTER_BOTTOM_INSET = GF.MAIN_WINDOW_BACKGROUND_INSET
-- Center the footer between the visible atlas edge and the window's inner bottom.
-- Its children may overflow this logical band; the native loop still fits the window.
GF.FRAME_BODY_BOTTOM = GF.MAIN_PANEL_INSET_BOTTOM
	+ GF.MAIN_PANEL_BORDER_BOTTOM_OFFSET
	+ GF.MAIN_PANEL_BORDER_BOTTOM_VISIBLE_INSET
	- GF.FRAME_FOOTER_BOTTOM_INSET
GF.FRAME_CONTENT_BOTTOM = GF.FRAME_BODY_BOTTOM + GF.FRAME_PAD
GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT = 5
GF.MAIN_PANEL_BACKPLATE_BG_INSET_RIGHT = 5
GF.MAIN_PANEL_BACKPLATE_BG_INSET_TOP = 2
GF.MAIN_PANEL_BACKPLATE_BG_INSET_BOTTOM = 10
GF.MAIN_PANEL_BACKPLATE_BG_COLOR = { 0, 0, 0, 1 }
GF.PLAYER_CONTEXT_DIALOG_BACKGROUND_COLOR = GF.MAIN_WINDOW_BACKGROUND_COLOR
GF.MAIN_PANEL_DECORATIVE_BORDER_ATLAS = "transmog-tabs-frame"
GF.MAIN_PANEL_DECORATIVE_BACKGROUND_ATLAS = "transmog-tabs-frame-bg"
GF.PANEL_SKIN_DEFAULT = "default"
GF.PANEL_SKIN_OPTIONS = {
	-- Default adds no full-window atlas and preserves the shipped black shell
	-- plus the fixed, muted transmog content backplate.
	{
		value = "default",
		labelKey = "SET_PANEL_SKIN_DEFAULT",
		label = "Default style",
	},
	{
		value = "housing_stone",
		atlas = "housing-basic-panel--stone-background",
		alpha = 1,
		labelKey = "SET_PANEL_SKIN_HOUSING_STONE",
		label = "Gray stone style (Housing stone)",
	},
	{
		value = "system_settings",
		colorKey = "PANEL_BACKGROUND_COLOR",
		color = { 31 / 255, 30 / 255, 33 / 255, 0.8 },
		usesSystemPanelCompositing = true,
		alpha = 1,
		labelKey = "SET_PANEL_SKIN_SYSTEM_SETTINGS",
		label = "Gray translucent style (System settings)",
	},
	{
		value = "quest_log",
		atlas = "QuestLog-main-background",
		alpha = 1,
		labelKey = "SET_PANEL_SKIN_QUEST_LOG",
		label = "Black-gray gradient style (Quest log)",
	},
	{
		value = "transmog",
		atlas = "transmog-tabs-frame-bg",
		alpha = 1,
		labelKey = "SET_PANEL_SKIN_TRANSMOG",
		label = "Deep black and reddish-brown style (Transmog)",
	},
	{
		value = "journeys",
		atlas = "ui-journeys-bg",
		alpha = 1,
		labelKey = "SET_PANEL_SKIN_JOURNEYS",
		label = "Black stone style (Journeys)",
	},
	{
		value = "weekly_rewards",
		atlas = "evergreen-weeklyrewards-frame-back",
		alpha = 1,
		labelKey = "SET_PANEL_SKIN_WEEKLY_REWARDS",
		label = "Gray-brown stone style (Great Vault)",
	},
	{
		value = "professions",
		atlas = "Professions-QualityWindow-Background",
		alpha = 1,
		labelKey = "SET_PANEL_SKIN_PROFESSIONS",
		label = "Dark brown style (Profession quality)",
	},
	{
		value = "auction_house",
		atlas = "auctionhouse-background-index",
		alpha = 1,
		labelKey = "SET_PANEL_SKIN_AUCTION_HOUSE",
		label = "Black-gray gradient style (Auction House)",
	},
}
GF.MAIN_PANEL_DECORATIVE_BACKGROUND_INSET_LEFT = 15
GF.MAIN_PANEL_DECORATIVE_BACKGROUND_INSET_RIGHT = 15
GF.MAIN_PANEL_DECORATIVE_BACKGROUND_INSET_TOP = 16
GF.MAIN_PANEL_DECORATIVE_BACKGROUND_INSET_BOTTOM = 14
GF.MAIN_PANEL_DECORATIVE_BACKGROUND_ALPHA = 0.30
GF.MAIN_PANEL_CONTENT_PADDING_X = GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT
GF.MAIN_PANEL_CONTENT_PADDING_TOP = GF.MAIN_PANEL_BACKPLATE_BG_INSET_TOP
GF.MAIN_PANEL_CONTENT_PADDING_BOTTOM = GF.MAIN_PANEL_BACKPLATE_BG_INSET_BOTTOM
GF.MAIN_PANEL_TAB_MIN_WIDTH = 95
GF.MAIN_PANEL_TAB_MAX_WIDTH = 170
GF.MAIN_PANEL_TAB_HEIGHT = 32
GF.MAIN_PANEL_TAB_UNREAD_STYLE = {
	texture = "Interface\\ChatFrame\\ChatFrameTab-NewMessage",
	color = { 1, 0.72, 0.12 },
	peakAlpha = 0.75,
	insetX = 2, bottomInset = 5, offsetY = 0, fadeSeconds = 1,
	transitionSeconds = 0.2,
}
GF.MAIN_PANEL_TAB_GAP = 1
GF.MAIN_PANEL_TAB_SELECTED_FONT_OBJECT = "GameFontHighlight"
GF.MAIN_PANEL_TAB_UNSELECTED_FONT_OBJECT = "GameFontNormal"
GF.MAIN_PANEL_TAB_DISABLED_FONT_OBJECT = "GameFontDisable"
GF.MAIN_WINDOW_TITLE_OFFSET_Y = -6
GF.MAIN_WINDOW_DRAG_HANDLE_LEFT_INSET = 18
GF.MAIN_WINDOW_DRAG_HANDLE_RIGHT_INSET = 46
GF.MAIN_WINDOW_DRAG_HANDLE_TOP_OFFSET = 0
GF.MAIN_WINDOW_DRAG_HANDLE_BOTTOM_OFFSET = -40
GF.MAIN_WINDOW_ROLE_BUTTON_SIZE = 32
GF.MAIN_WINDOW_ROLE_BUTTON_GAP = 9
GF.MAIN_WINDOW_ROLE_BUTTON_RIGHT_INSET = 48
GF.MAIN_WINDOW_ROLE_BUTTON_CENTER_OFFSET = 46
GF.MAIN_WINDOW_ROLE_BUTTON_TOP_OFFSET = GF.MAIN_WINDOW_ROLE_BUTTON_CENTER_OFFSET - (GF.MAIN_WINDOW_ROLE_BUTTON_SIZE / 2)
GF.MAIN_WINDOW_ACTION_ROLE_GAP = 16
GF.MAIN_WINDOW_EYE_SIZE = 44
GF.MAIN_WINDOW_EYE_SCALE = 1.378 -- 1.3 * 1.06
GF.MAIN_WINDOW_EYE_HOST_SIZE = 68
GF.MAIN_WINDOW_EYE_BACKGROUND_SIZE = 54
GF.MAIN_WINDOW_EYE_BACKGROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
GF.ADDON_LOGO_TEXTURE = "Interface\\AddOns\\GroupFinder\\Art\\Logo\\GroupFinderIcon.png"
GF.ADDON_MENU_LOGO_TEXTURE = "Interface\\AddOns\\GroupFinder\\Art\\Logo\\GroupFinder.png"
-- Chat badge: Art/Icon/GroupFinder.tga, referenced without an extension.
-- A .png suffix can be mistaken for a domain by another addon's URL parser.
GF.ADDON_CHAT_LOGO_TEXTURE = "Interface\\AddOns\\GroupFinder\\Art\\Icon\\GroupFinder"
GF.ADDON_CHAT_LOGO_SCALE = 1.25
GF.BROWSE_RAID_PROGRESS_COLORS = {
	killed = "|cffff0000", clear = "|cff00ff00",
	total = "|cff00ff00", separator = "|cffffffff", unknown = "|cff888888",
	name = "|cffffffff", defeatedName = "|cff9e9e9e",
}
GF.ADDON_ART_PATH = "Interface\\AddOns\\GroupFinder\\Art\\"
GF.ADDON_ART_UI_PATH = GF.ADDON_ART_PATH .. "UI\\"
GF.ADDON_ART_ICON_PATH = GF.ADDON_ART_PATH .. "Icon\\"
GF.ADDON_SOUNDS_PATH = "Interface\\AddOns\\GroupFinder\\Sounds\\"
-- Packed by Tools/build_gf_atlas.py; all regions retain their source pixels.
GF.GF_ATLAS_TEXTURE = GF.ADDON_ART_UI_PATH .. "GFatlas.png"
GF.GF_ATLAS_WIDTH = 396
GF.GF_ATLAS_HEIGHT = 330
GF.COMMON_ATLAS_TEXTURE = GF.GF_ATLAS_TEXTURE
GF.COMMON_ATLAS_WIDTH = GF.GF_ATLAS_WIDTH
GF.COMMON_ATLAS_HEIGHT = GF.GF_ATLAS_HEIGHT
GF.COMMON_ATLAS_REGIONS = {
	-- 用户参考红金方形文字按钮三态；方形小按钮继续使用标题底框。
	redButtonNormal = { 262, 2, 41, 41 },
	redButtonHighlighted = { 307, 2, 41, 41 },
	redButtonPressed = { 352, 2, 41, 41 },
	-- 筛选／输入框双态。
	filterCheck = { 262, 266, 124, 62 },
	-- 标题按钮四态及关闭／关于图标。
	closeButtonNormal = { 262, 47, 41, 41 },
	closeButtonHighlighted = { 307, 47, 41, 41 },
	closeButtonPressed = { 262, 92, 41, 41 },
	closeButtonDisabled = { 307, 92, 41, 41 },
	closeButtonGlyph = { 352, 47, 26, 26 },
	titleAboutGlyph = { 352, 77, 29, 13 },
	-- 横向滑杆：菱形四态、左右箭头四态及轨道。
	sliderThumbNormal = { 2, 262, 36, 36 },
	sliderThumbHighlighted = { 42, 262, 36, 36 },
	sliderThumbPressed = { 82, 262, 36, 36 },
	sliderThumbDisabled = { 122, 262, 36, 36 },
	sliderBackNormal = { 2, 302, 25, 25 },
	sliderBackHighlighted = { 31, 302, 25, 25 },
	sliderBackPressed = { 60, 302, 25, 25 },
	sliderBackDisabled = { 89, 302, 25, 25 },
	sliderForwardNormal = { 118, 302, 25, 25 },
	sliderForwardHighlighted = { 147, 302, 25, 25 },
	sliderForwardPressed = { 176, 302, 25, 25 },
	sliderForwardDisabled = { 205, 302, 25, 25 },
	sliderTrack = { 162, 262, 54, 25 },
	-- 竖向滚动条：三态滑块与细轨道，保留完整透明边缘。
	scrollBarThumbNormal = { 262, 137, 24, 125 },
	scrollBarThumbHighlighted = { 290, 137, 24, 125 },
	scrollBarThumbPressed = { 318, 137, 24, 125 },
	scrollBarTrack = { 346, 137, 12, 121 },
}
GF.GF_ATLAS_REGIONS = {
	chakram = { 2, 2, 256, 256 },
}
for name, region in pairs(GF.COMMON_ATLAS_REGIONS) do
	GF.GF_ATLAS_REGIONS[name] = region
end
local function commonAtlasTexCoord(region, inset)
	region = region or { 0, 0, 1, 1 }
	inset = tonumber(inset) or 0
	return {
		(region[1] + inset) / GF.COMMON_ATLAS_WIDTH,
		(region[1] + region[3] - inset) / GF.COMMON_ATLAS_WIDTH,
		(region[2] + inset) / GF.COMMON_ATLAS_HEIGHT,
		(region[2] + region[4] - inset) / GF.COMMON_ATLAS_HEIGHT,
	}
end
GF.MYTHIC_PLUS_BEST_BADGE_TEXTURE = GF.GF_ATLAS_TEXTURE
GF.MYTHIC_PLUS_BEST_BADGE_TEXCOORD = commonAtlasTexCoord(GF.GF_ATLAS_REGIONS.chakram)
GF.MYTHIC_PLUS_BEST_LEVEL_STYLE = {
	fontTemplate = "GameFontHighlightLarge",
	fontSize = 20,
	fontFlags = "OUTLINE",
	timed = { 1, 0.82, 0 },
	overtime = { 0.5, 0.5, 0.5 },
	unknown = { 1, 1, 1 },
}
GF.FOOTER_ACTION_BUTTON_SIZE = 35
GF.FOOTER_ACTION_BUTTON_GAP = 0
GF.FOOTER_ACTION_BUTTON_VISUAL_SIZE = 26
GF.FOOTER_ACTION_BUTTON_ICON_SIZE = 18
GF.FOOTER_ACTION_ICON_HOVER_STYLE = {
	normalColor = { 0.88, 0.82, 0.68 },
	hoverColor = { 1, 1, 1 },
	disabledColor = { 1, 1, 1 },
}
GF.GREAT_VAULT_BUTTON_SIZE = GF.FOOTER_ACTION_BUTTON_SIZE
GF.GREAT_VAULT_BUTTON_VISUAL_SIZE = GF.FOOTER_ACTION_BUTTON_VISUAL_SIZE
-- Display the complete vault artwork; notification-specific cropping does not apply.
GF.GREAT_VAULT_BUTTON_ICON_SIZE = 16
GF.GREAT_VAULT_BUTTON_ICON_OFFSET_X = 0
GF.GREAT_VAULT_BUTTON_ICON_OFFSET_Y = 0
GF.GREAT_VAULT_BUTTON_ICON_ATLAS = "greatVault-whole-normal"
GF.KEYSTONE_LOOT_ADDON_NAME = "KeystoneLoot"
GF.KEYSTONE_LOOT_BUTTON_SIZE = GF.GREAT_VAULT_BUTTON_SIZE
GF.KEYSTONE_LOOT_BUTTON_GAP = GF.FOOTER_ACTION_BUTTON_GAP
GF.KEYSTONE_LOOT_BUTTON_ICON_TEXTURE =
	GF.ADDON_ART_ICON_PATH .. "Gear.png"
-- Reuse the close-button skin at the footer's existing visual size.
GF.KEYSTONE_LOOT_BUTTON_VISUAL_SIZE = GF.FOOTER_ACTION_BUTTON_VISUAL_SIZE
GF.KEYSTONE_LOOT_BUTTON_ICON_SIZE = GF.FOOTER_ACTION_BUTTON_ICON_SIZE
GF.KEYSTONE_LOOT_BUTTON_ICON_OFFSET_X = 0
GF.KEYSTONE_LOOT_BUTTON_ICON_OFFSET_Y = 0
GF.SEASON_RATING_BUTTON_ICON_TEXTURE = GF.ADDON_ART_ICON_PATH .. "SeasonRating.png"
-- The hourglass fills its source height; match the vault and the gear's visible height.
GF.SEASON_RATING_BUTTON_ICON_SIZE = GF.GREAT_VAULT_BUTTON_ICON_SIZE
GF.TITLE_ACTION_BUTTON_GAP = 2
-- Release dates are shared by all locales; keep in sync with Docs/CHANGELOG.md.
-- 1.0.0/1.0.1 predate its release headings; see release commits below.
GF.CHANGELOG_RELEASE_DATES = {
	["3.0.8"] = "2026-10-07",
	["3.0.7"] = "2026-10-06",
	["3.0.6"] = "2026-10-05",
	["3.0.5"] = "2026-10-01",
	["3.0.4"] = "2026-09-29",
	["3.0.3"] = "2026-09-27",
	["3.0.2"] = "2026-09-24",
	["3.0.1"] = "2026-09-22",
	["3.0.0"] = "2026-09-22",
	["3.0.0.beta2"] = "2026-09-21",
	["3.0.0.beta1"] = "2026-09-20",
	["2.2.4"] = "2026-09-14",
	["2.2.3"] = "2026-09-13",
	["2.2.2"] = "2026-09-12",
	["2.2.1"] = "2026-09-09",
	["2.2.0"] = "2026-09-03",
	["2.1.15"] = "2026-09-01",
	["2.1.14"] = "2026-08-31",
	["2.1.13"] = "2026-08-30",
	["2.1.12"] = "2026-08-30",
	["2.1.11"] = "2026-08-28",
	["2.1.10"] = "2026-08-28",
	["2.1.9"] = "2026-08-26",
	["2.1.8"] = "2026-08-26",
	["2.1.7"] = "2026-08-25",
	["2.1.6"] = "2026-08-23",
	["2.1.5"] = "2026-08-21",
	["2.1.4"] = "2026-08-20",
	["2.1.3"] = "2026-08-18",
	["2.1.2"] = "2026-08-17",
	["2.1.1"] = "2026-08-17",
	["2.1.0"] = "2026-08-17",
	["2.0.10"] = "2026-08-16",
	["2.0.9"] = "2026-08-15",
	["2.0.8"] = "2026-08-13",
	["2.0.7"] = "2026-08-13",
	["2.0.6"] = "2026-08-11",
	["2.0.5"] = "2026-08-08",
	["2.0.4"] = "2026-08-08",
	["2.0.3"] = "2026-08-06",
	["2.0.2"] = "2026-08-03",
	["2.0.1"] = "2026-08-02",
	["2.0.0"] = "2026-07-30",
	["1.2.6"] = "2026-07-03",
	["1.2.5"] = "2026-07-02",
	["1.2.4"] = "2026-07-02",
	["1.2.3"] = "2026-07-02",
	["1.2.2"] = "2026-07-01",
	["1.2.1"] = "2026-06-30",
	["1.2.0"] = "2026-06-30",
	["1.1.4"] = "2026-06-29",
	["1.1.3"] = "2026-06-29",
	["1.1.2"] = "2026-06-29",
	["1.1.1"] = "2026-06-28",
	["1.1.0"] = "2026-06-28",
	["1.0.10"] = "2026-06-28",
	["1.0.9"] = "2026-06-27",
	["1.0.8"] = "2026-06-27",
	["1.0.7"] = "2026-06-27",
	["1.0.6"] = "2026-06-26",
	["1.0.5"] = "2026-06-26",
	["1.0.4"] = "2026-06-26",
	["1.0.3"] = "2026-06-25",
	["1.0.2"] = "2026-06-25",
	["1.0.1"] = "2026-06-24", -- 352d549: 版本更新 1.0.1 (+0800)
	["1.0.0"] = "2026-06-24", -- 6421f7d: Release 1.0.0 (+0800)
	["0.3.10"] = "2026-06-17",
	["0.3.9"] = "2026-06-17",
	["0.3.8"] = "2026-06-17",
	["0.3.7"] = "2026-06-17",
	["0.3.6"] = "2026-06-17",
	["0.3.5"] = "2026-06-17",
	["0.3.4"] = "2026-06-17",
	["0.3.3"] = "2026-06-17",
	["0.3.2"] = "2026-06-17",
	["0.3.1"] = "2026-06-16",
	["0.3.0"] = "2026-06-16",
	["0.2.0"] = "2026-06-16",
	["0.1.0"] = "2026-06-16",
}
GF.WINDOW_FLOAT_MOTION_STYLE = { openDuration = 0.26, closeDuration = 0.20, offsetY = -18 }
GF.ABOUT_STYLE = {
	-- Shared by the About window and standalone user letter.
	backgroundColor = { 5 / 255, 4 / 255, 2 / 255 },
	backgroundAlpha = 0.88,
	motion = GF.WINDOW_FLOAT_MOTION_STYLE,
	-- About-only compaction; the standalone letter keeps its reading geometry.
	-- Pair title/gap adjustments so optical centering does not move the intro.
	header = { heightReduction = 22, titleRaise = 2, descriptionGap = 4 },
	top = 224, width = 704, height = 432,
	leftWidth = 176, rightWidth = 520, gap = 8,
	infoHeight = 272, announcementHeight = 152, logHeight = 272,
	titleSize = 16, titleTop = 19,
	headingInset = 8, headingTop = 11, headingHeight = 32,
	contentEdgePad = 6, announcementInset = 10, logInset = 14,
	announcementFirstLineIndent = "　　", scrollEdgeFade = 24,
	announcementParagraphGap = 6,
	brandBand = { backgroundAlpha = 0.52, backgroundFadeWidth = 96 },
	versionHeader = {
		atlas = "UI-QuestTracker-Secondary-Objective-Header",
		sourceWidth = 300, sourceHeight = 30, sourceCap = 18, cropBottom = 4,
		backgroundOutset = 12,
		dateSize = 12, dateGap = 16, dateInsetRight = 8,
		-- Muted warm ivory keeps dates secondary within the gold/cream palette.
		dateColor = { 184 / 255, 176 / 255, 160 / 255, 1 },
		-- Crop the stray lower rule/glow without moving the two primary rules.
		interiorLeft = 0, interiorRight = 0, interiorTop = 2, interiorBottom = 4,
		textPadding = 2,
	},
	info = {
		inset = 22, scrollInset = 14, top = 58, bottom = 18, scrollBarGap = 3,
		rowHeight = 28, rowGap = 12, authorGap = 20,
		valueGap = 6, columnGap = 4,
		labelSize = 13, valueSize = 14, authorSize = 13, commandSize = 14, websiteSize = 13,
		labelColor = { 0.72, 0.72, 0.68, 1 },
		valueColor = { 0.94, 0.94, 0.91, 1 },
		linkColor = { 130 / 255, 204 / 255, 1, 1 },
		contactSize = 26, contactInlineGap = 0, contactGap = 4,
	},
	borderColor = { 0.90, 0.83, 0.68, 1 },
	hoverBorderColor = { 1, 0.95, 0.8, 1 },
	pressedBorderColor = { 0.72, 0.66, 0.54, 1 },
	centerAlphaScale = 0.20,
	-- Same two native atlases as the current Mythic+ character card; names
	-- are read from MYTHIC_PLUS_FRAME_ATLASES by the About surface renderer.
	frame = {
		sourceWidth = 558, sourceHeight = 322, sourceCap = 32,
		cropLeft = 12, cropRight = 12, cropTop = 9, cropBottom = 9,
		scale = 0.4,
		-- Measured inner rim: left x=16, top y=14, bottom y=309.
		interiorLeft = 1.6, interiorRight = 1.6, interiorTop = 2, interiorBottom = 1.6,
	},
	-- Atlas themes have no RGB metadata; these colors tint the native center.
	themeColors = {
		default = { 0.045, 0.039, 0.031, 0.78 },
		housing_stone = { 0.105, 0.108, 0.115, 0.80 },
		quest_log = { 0.055, 0.060, 0.065, 0.80 },
		transmog = { 0.090, 0.043, 0.034, 0.78 },
		journeys = { 0.060, 0.064, 0.067, 0.80 },
		weekly_rewards = { 0.095, 0.083, 0.062, 0.80 },
		professions = { 0.105, 0.071, 0.038, 0.80 },
		auction_house = { 0.061, 0.064, 0.072, 0.80 },
	},
	author = {
		whisperIconSize = 26, addFriendIconSize = 18,
		whisperPressedScale = 0.9, addFriendPressedScale = 0.7,
		tooltip = {
			hintColor = { 0.72, 0.72, 0.68 },
			lineSpacing = 6, padding = 4, backgroundInset = 4,
			backgroundColor = { 0.035, 0.030, 0.025, 1 },
		},
	},
}
GF.USER_LETTER_ENTRY_STYLE = {
	iconAtlas = "Crosshair_mail_128",
	iconSize = 52,
	-- Visible mail bounds in the 128px atlas: (17,34)-(126,112).
	iconOffsetX = -7.5 / 128,
	iconOffsetY = 9 / 128,
	height = 152,
	inset = 12,
	iconGap = 4,
	titleTop = 28,
	titleSize = 15,
	titleSpacing = 4,
	actionSize = 12,
	actionBottom = 34,
	actionInset = 16,
	contentGap = 10,
	compactIconSize = 24,
	compactInset = 10,
	compactGap = 6,
	backgroundTexture = GF.ADDON_ART_UI_PATH .. "UserLetterBackground.png",
	backgroundAlpha = 0.60,
	arrowAtlas = "common-icon-forwardarrow",
	arrowSize = 8,
	arrowGap = 3,
	-- Visible triangle bounds in the 256px atlas: (48,7)-(213,256).
	arrowOffsetY = 3.5 / 256,
	hoverFadeInDuration = 0.18,
	hoverFadeOutDuration = 0.24,
}
GF.USER_LETTER_WAX_SEAL_ATLAS = "Quest-Alliance-WaxSeal"
GF.USER_LETTER_WAX_SEAL_SIZE = 64
GF.USER_LETTER_WAX_SEAL_GAP = 12
GF.VERSION_DISCOVERY_BADGE_ATLAS = "communities-icon-notification"
GF.VERSION_DISCOVERY_BADGE_SIZE = 11
GF.TITLE_ABOUT_BUTTON_ICON_TEXTURE = GF.COMMON_ATLAS_TEXTURE
local TITLE_ABOUT_BUTTON_ICON_REGION = GF.COMMON_ATLAS_REGIONS.titleAboutGlyph
local TITLE_ABOUT_BUTTON_ICON_LEFT =
	TITLE_ABOUT_BUTTON_ICON_REGION[1] / GF.COMMON_ATLAS_WIDTH
local TITLE_ABOUT_BUTTON_ICON_RIGHT =
	(TITLE_ABOUT_BUTTON_ICON_REGION[1] + TITLE_ABOUT_BUTTON_ICON_REGION[3])
	/ GF.COMMON_ATLAS_WIDTH
local TITLE_ABOUT_BUTTON_ICON_TOP =
	TITLE_ABOUT_BUTTON_ICON_REGION[2] / GF.COMMON_ATLAS_HEIGHT
local TITLE_ABOUT_BUTTON_ICON_BOTTOM =
	(TITLE_ABOUT_BUTTON_ICON_REGION[2] + TITLE_ABOUT_BUTTON_ICON_REGION[4])
	/ GF.COMMON_ATLAS_HEIGHT
-- 用户提供的 29×13 横向原图完整存入图集；八点 UV 将其顺时针转为竖向 i，
-- 不改动源像素。显示宽高直接按原图比例计算，不再使用旧透明留白校准。
GF.TITLE_ABOUT_BUTTON_ICON_TEXCOORD = {
	TITLE_ABOUT_BUTTON_ICON_LEFT, TITLE_ABOUT_BUTTON_ICON_BOTTOM,
	TITLE_ABOUT_BUTTON_ICON_RIGHT, TITLE_ABOUT_BUTTON_ICON_BOTTOM,
	TITLE_ABOUT_BUTTON_ICON_LEFT, TITLE_ABOUT_BUTTON_ICON_TOP,
	TITLE_ABOUT_BUTTON_ICON_RIGHT, TITLE_ABOUT_BUTTON_ICON_TOP,
}
-- X 保持 WaypointUI 的 62% 画布；i 在默认 22 外框中显示为 11.5 高。
GF.TITLE_ACTION_BUTTON_GLYPH_SCALE = 0.62
GF.TITLE_ABOUT_BUTTON_ICON_SCALE = 11.5 / 22
GF.TITLE_ABOUT_BUTTON_ICON_ASPECT_RATIO =
	TITLE_ABOUT_BUTTON_ICON_REGION[4] / TITLE_ABOUT_BUTTON_ICON_REGION[3]
GF.TITLE_ABOUT_BUTTON_ICON_SHADOW = {
	alpha = 0.65, offsetX = 0.4, offsetY = -0.65, spread = 0.8,
	referenceHeight = 12,
}
GF.WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
GF.COMMON_TITLE_BUTTON_SLICE_MARGIN = 14
GF.COMMON_TITLE_BUTTON_TEXTURE_SCALE = 0.7
GF.COMMON_BUTTON_STYLE = {
	height = 22, minimumWidth = 72, iconButtonSize = 24, compactSize = 20,
	iconSize = 14, textPadding = 8, minFontSize = 10,
	-- Keep the enlarged curls and matching gold rim inside fixed caps at 22px high.
	gap = 8, sliceMargin = 15, textureScale = 0.7,
}
GF.BUTTON_VISUAL_STATE = {
	NORMAL = "normal",
	HOVER = "hover",
	PRESSED = "pressed",
	DISABLED = "disabled",
}
GF.COMMON_BUTTON_TEXTURE = GF.COMMON_ATLAS_TEXTURE
GF.COMMON_BUTTON_REGIONS = {
	normal = GF.COMMON_ATLAS_REGIONS.redButtonNormal,
	hover = GF.COMMON_ATLAS_REGIONS.redButtonHighlighted,
	pressed = GF.COMMON_ATLAS_REGIONS.redButtonPressed,
	disabled = GF.COMMON_ATLAS_REGIONS.redButtonNormal,
}
GF.COMMON_TITLE_BUTTON_TEXTURE = GF.COMMON_ATLAS_TEXTURE
GF.COMMON_TITLE_BUTTON_BACKGROUND_REGIONS = {
	normal = GF.COMMON_ATLAS_REGIONS.closeButtonNormal,
	hover = GF.COMMON_ATLAS_REGIONS.closeButtonHighlighted,
	pressed = GF.COMMON_ATLAS_REGIONS.closeButtonPressed,
	disabled = GF.COMMON_ATLAS_REGIONS.closeButtonDisabled,
}
GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_REGION =
	GF.COMMON_ATLAS_REGIONS.closeButtonGlyph
GF.COMMON_TITLE_BUTTON_VISUAL_SIZE = 22
GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_SCALE =
	GF.TITLE_ACTION_BUTTON_GLYPH_SCALE
GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_OFFSET_X = 0
GF.COMMON_TITLE_BUTTON_CLOSE_GLYPH_OFFSET_Y = 0
GF.COMMON_TITLE_BUTTON_PRESSED_OFFSET_X = 1
GF.COMMON_TITLE_BUTTON_PRESSED_OFFSET_Y = -1
GF.COMMON_TITLE_BUTTON_DISABLED_GLYPH_ALPHA = 0.5
GF.COMMON_SMALL_BUTTON_FADE_DURATION = 0.16
GF.COMMON_PANEL_BUTTON_FADE_DURATION = 0.16
GF.COMMON_TITLE_BUTTON_HOVER_GLOW_ALPHA = 0
GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_ALPHA =
	GF.COMMON_TITLE_BUTTON_HOVER_GLOW_ALPHA
GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_SCALE = 1
GF.COMMON_TITLE_BUTTON_CLOSE_HOVER_GLOW_DESATURATED = false
GF.COMMON_BUTTON_VISUALS = {
	normal = {
		atlasState = "normal",
		textColor = { 1, 0.82, 0, 1 },
		textureColor = { 1, 1, 1, 1 },
		iconColor = { 1, 1, 1, 1 },
		textOffset = { 0, 0 },
		desaturated = false,
	},
	hover = {
		atlasState = "highlight",
		textColor = { 1, 0.95, 0.45, 1 },
		textureColor = { 1, 1, 1, 1 },
		iconColor = { 1, 0.96, 0.58, 1 },
		textOffset = { 0, 0 },
		desaturated = false,
	},
	pressed = {
		atlasState = "pressed",
		textColor = { 1, 0.68, 0.12, 1 },
		textureColor = { 1, 1, 1, 1 },
		iconColor = { 1, 1, 1, 1 },
		textOffset = { 1, -1 },
		desaturated = false,
	},
	disabled = {
		atlasState = "disabled",
		textColor = { 0.55, 0.55, 0.55, 1 },
		textureColor = { 0.55, 0.55, 0.55, 1 },
		iconColor = { 1, 1, 1, 0.45 },
		textOffset = { 0, 0 },
		desaturated = true,
	},
}
GF.CONTROL_FRAME_ATLAS_STATES = {
	normal = "house-chest-list-Item-pressed",
	hover = "house-chest-list-Item-active",
	focus = "house-chest-list-Item-active",
	checked = "house-chest-list-Item-active",
	highlighted = "house-chest-list-Item-active",
}
-- Small square controls and input fields use the local two-state texture.
-- Each raw 64px state cell contains a weak antialiased fringe around the
-- visible outline. Sampling that fringe while minifying to 16-30px can skip
-- the one-pixel normal-state side border entirely, so every local renderer
-- starts from the same measured visible-content rectangle.
GF.FILTER_CHECK_ATLAS_TEXTURE =
	GF.COMMON_ATLAS_TEXTURE
GF.FILTER_CHECK_ATLAS_WIDTH = GF.COMMON_ATLAS_WIDTH
GF.FILTER_CHECK_ATLAS_HEIGHT = GF.COMMON_ATLAS_HEIGHT
GF.FILTER_CHECK_ATLAS_ORIGIN_X = GF.COMMON_ATLAS_REGIONS.filterCheck[1]
GF.FILTER_CHECK_ATLAS_ORIGIN_Y = GF.COMMON_ATLAS_REGIONS.filterCheck[2]
GF.FILTER_CHECK_ATLAS_CELL_WIDTH = 62
GF.FILTER_CHECK_ATLAS_CELL_HEIGHT = 62
GF.FILTER_CHECK_ATLAS_CONTENT_INSETS = {
	left = 0,
	top = 0,
	right = 1,
	bottom = 0,
}
GF.FILTER_CHECK_ATLAS_CONTENT_WIDTH =
	GF.FILTER_CHECK_ATLAS_CELL_WIDTH
	- GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.left
	- GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.right
GF.FILTER_CHECK_ATLAS_CONTENT_HEIGHT =
	GF.FILTER_CHECK_ATLAS_CELL_HEIGHT
	- GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.top
	- GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.bottom
GF.FILTER_CHECK_ATLAS_REGIONS = {
	highlighted = {
		GF.FILTER_CHECK_ATLAS_ORIGIN_X
			+ GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.left,
		GF.FILTER_CHECK_ATLAS_ORIGIN_Y
			+ GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.top,
		GF.FILTER_CHECK_ATLAS_CONTENT_WIDTH,
		GF.FILTER_CHECK_ATLAS_CONTENT_HEIGHT,
	},
	normal = {
		GF.FILTER_CHECK_ATLAS_ORIGIN_X
			+ GF.FILTER_CHECK_ATLAS_CELL_WIDTH
			+ GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.left,
		GF.FILTER_CHECK_ATLAS_ORIGIN_Y
			+ GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.top,
		GF.FILTER_CHECK_ATLAS_CONTENT_WIDTH,
		GF.FILTER_CHECK_ATLAS_CONTENT_HEIGHT,
	},
}
GF.FILTER_CHECK_ATLAS_STATES = {
	normal = "normal",
	hover = "highlighted",
	focus = "highlighted",
	checked = "highlighted",
	highlighted = "highlighted",
}
GF.FILTER_INPUT_ATLAS_STATES = GF.FILTER_CHECK_ATLAS_STATES
GF.COMPACT_CONTROL_ATLAS_STATES = GF.FILTER_CHECK_ATLAS_STATES
GF.FILTER_CHECK_ATLAS_COORDS = {
	highlighted = {
		(GF.FILTER_CHECK_ATLAS_ORIGIN_X
			+ GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.left)
			/ GF.FILTER_CHECK_ATLAS_WIDTH,
		(GF.FILTER_CHECK_ATLAS_ORIGIN_X
			+ GF.FILTER_CHECK_ATLAS_CELL_WIDTH
			- GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.right)
			/ GF.FILTER_CHECK_ATLAS_WIDTH,
		(GF.FILTER_CHECK_ATLAS_ORIGIN_Y
			+ GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.top)
			/ GF.FILTER_CHECK_ATLAS_HEIGHT,
		(GF.FILTER_CHECK_ATLAS_ORIGIN_Y
			+ GF.FILTER_CHECK_ATLAS_CELL_HEIGHT
			- GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.bottom)
			/ GF.FILTER_CHECK_ATLAS_HEIGHT,
	},
	normal = {
		(GF.FILTER_CHECK_ATLAS_ORIGIN_X
			+ GF.FILTER_CHECK_ATLAS_CELL_WIDTH
			+ GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.left)
			/ GF.FILTER_CHECK_ATLAS_WIDTH,
		(GF.FILTER_CHECK_ATLAS_ORIGIN_X
			+ (GF.FILTER_CHECK_ATLAS_CELL_WIDTH * 2)
			- GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.right)
			/ GF.FILTER_CHECK_ATLAS_WIDTH,
		(GF.FILTER_CHECK_ATLAS_ORIGIN_Y
			+ GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.top)
			/ GF.FILTER_CHECK_ATLAS_HEIGHT,
		(GF.FILTER_CHECK_ATLAS_ORIGIN_Y
			+ GF.FILTER_CHECK_ATLAS_CELL_HEIGHT
			- GF.FILTER_CHECK_ATLAS_CONTENT_INSETS.bottom)
			/ GF.FILTER_CHECK_ATLAS_HEIGHT,
	},
}
GF.FILTER_INPUT_SLICE_RATIOS = { 0.45, 0.55 }
-- Fallback for frames whose height is not yet resolved; sized inputs derive
-- their cap width from the source aspect ratio and current display height.
GF.FILTER_INPUT_CAP_W = 9
GF.FILTER_NUMBER_INPUT_CAP_W = GF.FILTER_INPUT_CAP_W
-- Source ratios preserve the current effective 16px cap proportions without
-- depending on a particular atlas file size or resolution scale.
GF.CONTROL_FRAME_SLICE_RATIOS = {
	normal = {
		left = 16 / 104,
		right = 1 - (16 / 104),
		top = 16 / 108,
		bottom = 1 - (16 / 108),
	},
	highlighted = {
		left = 16 / 108,
		right = 1 - (16 / 108),
		top = 16 / 108,
		bottom = 1 - (16 / 108),
	},
}
GF.CONTROL_FRAME_DISPLAY_MARGIN = 8
GF.FILTER_MULTILINE_INPUT_SOURCE_MARGIN = 16
GF.FILTER_MULTILINE_INPUT_DISPLAY_MARGIN = 8
GF.FILTER_MULTILINE_INPUT_CONTENT_INSET = 5
GF.FILTER_MULTILINE_INPUT_SLICE_RATIOS = {
	-- 合图前的 64px 单元从 16px 分割；打包时已物理删除左/上 1px 外圈。
	left = 15 / 61,
	right = 47 / 61,
	top = 15 / 62,
	bottom = 47 / 62,
}
GF.FILTER_CHECK_ATLAS_DISPLAY_MARGIN =
	GF.FILTER_MULTILINE_INPUT_DISPLAY_MARGIN
GF.FILTER_CHECK_ATLAS_SLICE_RATIOS =
	GF.FILTER_MULTILINE_INPUT_SLICE_RATIOS
GF.COMPACT_CONTROL_SLICE_RATIOS =
	GF.FILTER_MULTILINE_INPUT_SLICE_RATIOS
GF.MYTHIC_PLUS_FRAME_ATLASES = {
	dark = "shop-list-bg",
	brown = "shop-card-wide-bg",
	class = "shop-card-wide-bg",
	border = "shop-card-wide-frame-default",
	hover = "shop-card-wide-frame-selected",
	label = "shop-card-label-bg",
}
GF.MYTHIC_PLUS_CHARACTER_CARD_HOVER_STYLE = {
	fadeInDuration = 0.16,
	fadeOutDuration = 0.22,
	glowAlpha = 0.74,
}
GF.MYTHIC_PLUS_WEEKLY_REWARD_BLOCK_ATLAS = "house-upgrade-reward-large-tile-bg"
GF.MYTHIC_PLUS_VAULT_GRID_LAYOUT = {
	rightInset = 14,
	categoryWidth = 28,
	categoryGap = 6,
	cellWidth = 34,
	columnStep = 36,
	rowStep = 32,
	dividerGap = 8,
	dividerHeight = 96,
}
GF.MYTHIC_PLUS_VAULT_CATEGORY_STYLE = {
	size = 20,
	atlases = {
		raid = "Lairs",
		dungeons = "Lairs",
		world = "Lairs",
	},
	-- Tinted categories remove the source gold first; world keeps its native color.
	tints = {
		raid = { 0.25, 1, 0.35, 1 },
		dungeons = { 0.25, 0.65, 1, 1 },
	},
}
-- Opt-in border for the current character's specialization switcher.
-- White vertex color preserves the yellow atlas's native #FFD800 rim.
local TALENT_SPECIALIZATION_RING_COLOR = { 1, 1, 1, 1 }
GF.TALENT_SPECIALIZATION_RING_STYLE = {
	atlas = "ui-journeys-delve-rewardicon-ring-frame-yellow-2x",
	fallbackAtlas = "UI-Journeys-Delve-rewardicon-ring-frame-yellow",
	color = TALENT_SPECIALIZATION_RING_COLOR,
	disabledColor = { 0.48, 0.48, 0.48, 0.7 },
	hoverColor = TALENT_SPECIALIZATION_RING_COLOR,
	hoverFadeInDuration = GF.MYTHIC_PLUS_CHARACTER_CARD_HOVER_STYLE.fadeInDuration,
	hoverFadeOutDuration = GF.MYTHIC_PLUS_CHARACTER_CARD_HOVER_STYLE.fadeOutDuration,
	-- The 108px atlas has an 84px colored ring centered at (53, 53).
	scale = 108 / 84,
	offsetRatio = 1 / 84,
}
-- Lists and quick filters share the native Incentive ring, tinted by class.
-- Roster/result artwork fits inside the reinforced ring; slot geometry stays fixed.
GF.LIST_SPECIALIZATION_ICON_SCALE = 0.8
GF.CLASS_SPECIALIZATION_RING_STYLE = {
	atlas = "UI-LFG-RoleIcon-Incentive",
	classColored = true,
	desaturated = true,
	-- Reinforce the inner edge without changing the outer diameter.
	innerInset = 0.4,
	-- The 256px source has 244px alpha bounds centered at (123, 123).
	scale = 256 / 244,
	offsetRatio = 5 / 244,
}
GF.MYTHIC_PLUS_VAULT_ORB_STYLE = {
	ring = "ui-journeys-delve-rewardicon-ring-frame-2x",
	-- The native catalog can publish the 1x/2x sheets under this base name.
	ringFallback = "UI-Journeys-Delve-rewardicon-ring-frame",
	-- Warm gold sampled from the Titan ring; remove the new material's tint first.
	ringColor = { 1, 0.898, 0.608, 1 },
	-- The 108px atlas has an 84px colored ring centered at (53, 53).
	ringScale = 108 / 84,
	ringOffsetRatio = 1 / 84,
	glow = "PowerSwirlAnimation-YellowRing",
	flow = "talents-animations-clouds",
	glass = "CovenantSanctum-Reservoir-Idle-NightFae-Glass",
	mask = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	-- Comparison 10: add one UI unit to the total width and height.
	maskPadding = 1,
	-- The isolated glass has no covenant emblem or baked metal rim.
	glassCrop = { 36 / 256, 220 / 256, 36 / 256, 220 / 256 },
	-- Magnify smooth 240px cloud windows to avoid mottled small-orb detail.
	flowCrop = { 750 / 1612, 990 / 1612, 330 / 774, 570 / 774 },
	driftCrop = { 220 / 1612, 460 / 1612, 230 / 774, 470 / 774 },
	innerRatio = 256 / 281,
	phaseSpeed = 0.42,
	driftSpeed = 0.2646,
	waveCapTexture = GF.ADDON_ART_UI_PATH .. "VaultLiquidEmptyCap.blp",
	waveSurfaceTexture = GF.ADDON_ART_UI_PATH .. "VaultLiquidSurface.blp",
	waveSpeed = 1.15,
	waveTravel = 0.20,
	wavePaddingRatio = 24 / 256,
	waveSurfaceColor = { 1, 0.82, 0.42, 0.28 },
	flowAlpha = 0.66,
	flowPulse = 0.06,
	driftAlpha = 0.30,
	driftPulse = 0.04,
	glassAlpha = 0.60,
	emptyGlassAlpha = 0.20,
	emptyBrightness = 0.75,
	diameter = 28,
	tick = 1 / 30,
	flashDuration = 0.6,
	flashPeakAlpha = 0.18,
	backgroundColor = { 33 / 255, 26 / 255, 14 / 255, 1 }, -- #211A0E
	-- Smooth liquid replaces the duplicate glass texture beneath the clouds.
	fillBottomColor = { 55 / 255, 36 / 255, 14 / 255, 1 }, -- #37240E
	fillTopColor = { 110 / 255, 76 / 255, 28 / 255, 1 }, -- #6E4C1C
	effectColor = { 1, 0.74, 0.30, 1 },
	shellColor = { 1, 0.80, 0.45, 1 },
	glassColor = { 1, 0.88, 0.65, 1 },
	textColors = {
		complete = { 1, 242 / 255, 210 / 255, 1 }, -- #FFF2D2
		progress = { 1, 242 / 255, 210 / 255, 1 }, -- #FFF2D2
		unknown = { 133 / 255, 133 / 255, 128 / 255, 1 }, -- #858580
	},
}
-- Midnight Season 2 (Mythic+ season 18): Hero, Myth, then Nebulous Voidcore.
GF.MYTHIC_PLUS_CREST_CURRENCIES = {
	-- The native currency list exposes 3418; 3513 shares its name but has a different balance.
	[18] = { 3445, 3446, 3418 },
}
GF.MYTHIC_PLUS_SEASON_CAPPED_CURRENCIES = { [3445] = true, [3446] = true }
GF.MYTHIC_PLUS_CHARACTER_FOOTER_STYLE = {
	carpoolWidth = 80, roleSize = 20, roleGap = 7,
	currencyIconSize = 16, currencyFontSize = 10, currencyGap = 10,
	currencyTextGap = 3, currencyIconCrop = 0.08, inset = 8,
	currencyIconInset = 2,
	currencyIconMask = GF.ADDON_ART_PATH .. "Masks\\SpecChoiceCutCorners.tga",
	dividerHeight = 24, dividerGap = 8,
	compactWidth = 320, compactControlY = 7, compactCurrencyY = -11,
	compactCurrencyIconSize = 14, compactCurrencyGap = 8,
	maxCarpoolWidth = 110, minCarpoolWidth = 65,
	capColors = { below = "ff00ff00", reached = "ffff0000", unknown = "ff808080", owned = "ffffffff" },
}
GF.MYTHIC_PLUS_CHARACTER_CHECK_STYLE = {
	size = 20,
	markSize = 16,
	background = {
		texture = GF.ADDON_ART_PATH .. "Masks\\SpecChoiceCutCorners.tga",
		inset = 3.5,
		color = { 0, 0, 0, 1 },
	},
	atlasStates = {
		normal = "common-button-tertiary-depressed-normal-purple",
		hover = "common-button-tertiary-depressed-normal-purple",
		checked = "common-button-tertiary-depressed-normal-glow-purple",
	},
	alpha = { normal = 0.45, hover = 1, checked = 1 },
	unavailableRoleAlpha = 0.55,
	chrome = {
		-- Keep 16px source corners isotropic in a 20x20 checkbox.
		sliceRatios = { left = 16 / 51, right = 1 - 16 / 51,
			top = 16 / 39, bottom = 1 - 16 / 39 },
		displayMargin = 20 / 3,
		continuousInternalUV = true,
		-- The atlas has transparent padding; retain exact square source corners.
		halfTexelInset = false,
		desaturated = true,
		color = { 1, 0.82, 0, 1 },
	},
}
GF.MYTHIC_PLUS_CHARACTER_CONTROL_STYLE = {
	atlas = "common-button-tertiary-depressed-normal-purple",
	hoverAtlas = "common-button-tertiary-depressed-normal-glow-purple",
	-- Both 51x39 atlases share the same chamfer and glow footprint.
	sliceRatios = { left = 16 / 51, right = 1 - 16 / 51,
		top = 16 / 39, bottom = 1 - 16 / 39 },
	cornerSize = 8,
	referenceHeight = 24,
	normal = { 1, 0.82, 0, 1 },
	pressed = { 1, 0.7, 0, 1 },
	disabled = { 0.5, 0.41, 0, 0.65 },
}
-- Dominant opaque metal color in shop-card-wide-frame-default. The atlas
-- supplies the outer border's color directly; use its same warm gray on the
-- desaturated shared header divider, rather than the header's gold tint.
GF.MYTHIC_PLUS_CHARACTER_BORDER_COLOR = { 91 / 255, 89 / 255, 84 / 255, 1 }
GF.REFRESH_ICON_ATLAS = "Soulbinds_Tree_Undo"
GF.TEAMUP_ATLASES = {
	"plunderstorm-glues-queueselector-solo-selected",
	"plunderstorm-glues-queueselector-duo-selected",
	"plunderstorm-glues-queueselector-trio-selected",
}
GF.TEAMUP_INLINE_ATLASES = {
	applicant = GF.TEAMUP_ATLASES[1],
	group = GF.TEAMUP_ATLASES[3],
}
GF.SETTINGS_SLIDER_TEXTURE = GF.COMMON_ATLAS_TEXTURE
GF.SETTINGS_SLIDER_TRACK_REGION =
	GF.COMMON_ATLAS_REGIONS.sliderTrack
GF.SETTINGS_SLIDER_THUMB_REGIONS = {
	normal = GF.COMMON_ATLAS_REGIONS.sliderThumbNormal,
	highlighted = GF.COMMON_ATLAS_REGIONS.sliderThumbHighlighted,
	pressed = GF.COMMON_ATLAS_REGIONS.sliderThumbPressed,
	disabled = GF.COMMON_ATLAS_REGIONS.sliderThumbDisabled,
}
GF.SETTINGS_SLIDER_BACK_REGIONS = {
	normal = GF.COMMON_ATLAS_REGIONS.sliderBackNormal,
	highlighted = GF.COMMON_ATLAS_REGIONS.sliderBackHighlighted,
	pressed = GF.COMMON_ATLAS_REGIONS.sliderBackPressed,
	disabled = GF.COMMON_ATLAS_REGIONS.sliderBackDisabled,
}
GF.SETTINGS_SLIDER_FORWARD_REGIONS = {
	normal = GF.COMMON_ATLAS_REGIONS.sliderForwardNormal,
	highlighted = GF.COMMON_ATLAS_REGIONS.sliderForwardHighlighted,
	pressed = GF.COMMON_ATLAS_REGIONS.sliderForwardPressed,
	disabled = GF.COMMON_ATLAS_REGIONS.sliderForwardDisabled,
}
GF.SETTINGS_SLIDER_TRACK_SOURCE_CAP_W = 15
GF.SETTINGS_SLIDER_TRACK_DISPLAY_CAP_W = 10
GF.SETTINGS_SLIDER_TRACK_DISPLAY_H = 16
GF.SETTINGS_SLIDER_THUMB_SIZE = 16
GF.SETTINGS_SLIDER_STEPPER_SIZE = 16
GF.SETTINGS_SLIDER_STEPPER_GAP = 4
GF.COMMON_SCROLLBAR_STEPPER_TEXTURE = GF.COMMON_ATLAS_TEXTURE
GF.COMMON_SCROLLBAR_BACK_REGIONS = GF.SETTINGS_SLIDER_BACK_REGIONS
GF.COMMON_SCROLLBAR_FORWARD_REGIONS = GF.SETTINGS_SLIDER_FORWARD_REGIONS
GF.COMMON_SCROLLBAR_STEPPER_SIZE = 16
GF.COMMON_SCROLLBAR_STEPPER_ROTATION = math.pi * 1.5
GF.COMMON_SCROLLBAR_STEPPER_FADE_DURATION = 0.18
GF.COMMON_SCROLLBAR_TRACK_REGION = GF.COMMON_ATLAS_REGIONS.scrollBarTrack
GF.COMMON_SCROLLBAR_THUMB_REGIONS = {
	normal = GF.COMMON_ATLAS_REGIONS.scrollBarThumbNormal,
	highlighted = GF.COMMON_ATLAS_REGIONS.scrollBarThumbHighlighted,
	pressed = GF.COMMON_ATLAS_REGIONS.scrollBarThumbPressed,
}
GF.COMMON_SCROLLBAR_TRACK_WIDTH = 6
GF.COMMON_SCROLLBAR_THUMB_WIDTH = 12
GF.COMMON_SCROLLBAR_TRACK_CAP = 6
GF.COMMON_SCROLLBAR_THUMB_CAP = 12
-- User-approved PNGs, retained in Tools/ArtSources/GFloating/Approved.
-- Atlas geometry keeps the original 2px edge padding and frame ordering.
GF.FLOATING_ART = {
	panel = GF.ADDON_ART_PATH .. "GFloating/FloatPanel.png",
	ring = GF.ADDON_ART_PATH .. "GFloating/Ring.png",
	eyeMask = GF.MAIN_WINDOW_EYE_BACKGROUND_MASK,
	breathe = {
		texture = GF.ADDON_ART_PATH .. "GFloating/Breathe.png",
		width = 592, height = 912, columns = 4, frames = 32,
		cellWidth = 144, cellHeight = 110, padding = 2, duration = 3,
	},
	border = {
		texture = GF.ADDON_ART_PATH .. "GFloating/BorderGlow.png",
		width = 972, height = 840, columns = 3, frames = 30,
		cellWidth = 320, cellHeight = 80, padding = 2, duration = 1.5,
	},
}
GF.FLOATING_STYLE = {
	width = 160, artWidth = 172, artHeight = 43,
	-- Match the source border's 292x44 rail; its round end is scaled uniformly,
	-- while only the straight section is stretched to the final half width.
	panelWidth = 146 * 172 / 320, panelHeight = 44 * 172 / 320,
	panelBodyU = (160 - 47 / 2) / 160,
	-- Fit the light core to the actual gold outline, independently of its canvas.
	borderWidth = 170, borderHeight = 41, borderOffsetX = -0.7, borderOffsetY = 0.05,
	ringWidth = 73 * 172 / 320, ringHeight = 74 * 172 / 320,
	logoSize = 60 * 172 / 320, eyeSize = 60 * 172 / 320,
	-- Native 44px flipbook cells contain a 34px eye, centered one pixel up.
	-- Fit and mask that content; the 45px template also includes its grey rim.
	eyeContentSize = 34, eyeContentOffsetY = -1,
	statusIconSize = 20, statusIconInset = 14,
	applicantOffset = -67.5 * 172 / 320, groupOffset = 66 * 172 / 320,
	expandDuration = 0.5, collapseDuration = 0.2,
	statusDelay = 0.25, statusDuration = 0.18,
	effectFadeIn = 0.2, effectFadeOut = 0.2,
}
GF.FLOAT_MESSAGE_ALERT_STYLE = {
	fps = 30, canvasSize = 130, scale = 172 / 320,
	introDuration = 23 / 30, fadeIn = 0.08, fadeOut = 13 / 30,
	stateTransition = 0.2,
	breathPeriod = 2, breathFloor = 0.10, breathPower = 0.86,
	-- The middle light alone breathes at the eye; the soft outer halo is arrival-only.
	-- Tuck the soft inner transition under the gold rim's dark outer fringe.
	middleGlowCanvas = 92, middleGlowAlpha = 0.40,
	middleGlowDelay = 0.10, middleGlowEnterDuration = 0.30,
	exitBlend = 3 / 30, crescentDelay = 3 / 30,
	-- Read clears the marker first; the outer stroke follows from its frozen pose.
	exitMarkerDuration = 4 / 30, exitGlowDuration = 6 / 30, exitCrescentDelay = 3 / 30,
	-- 520 px masters remain lossless; their visible radii differ by design.
	masterCanvas = 520, ringCanvasPerRadius = 520 / 185, glowCanvasPerRadius = 520 / 184.4,
	-- The supplied 24x17 icon uses its full canvas, centered without the old margin.
	iconAnchorY = 0.5,
	-- Clear the base rim early; the stroke dissolves before its soft afterglow.
	pulseStartRadius = 32, pulseEndRadius = 62, pulseGlowAlpha = 0.85,
	pulseFadeStart = 0.28, pulseFadeEnd = 0.80, pulseStrokePower = 1.5,
	pulseGlowFadeStart = 0.34,
	-- The stroke leads; the delayed soft wave spreads wider before a shallow return.
	pulseGlowDelay = 0.06, pulseGlowFadeIn = 0.18,
	pulseGlowStartRadius = 32, pulseGlowPeakRadius = 66,
	pulseGlowReturnStart = 0.64, pulseGlowReturnRadius = 61,
	crescentStartScale = 0.65, crescentExitShrink = 0.3, crescentDim = 0.28,
	particleMinSize = 3, particleGrowth = 6, particleAspect = 18 / 17,
	sparkWidth = 60, sparkHeight = 44, sparkMinScale = 0.22, sparkGrowth = 0.7, sparkAlpha = 0.7,
	-- Two readable accents with a short anticipation and a quiet hold afterward.
	-- Time is in seconds; values scale each marker's independent amplitude.
	markerPulse = {
		{ 0, 0 }, { 0.075, -0.22 }, { 0.19, 1 }, { 0.33, -0.16 },
		{ 0.51, 0.62 }, { 0.67, -0.08 }, { 0.88, 0 },
	},
	bursts = {
		{ slot = "ReceiveLeftA", delay = 0 }, { slot = "ReceiveRightA", delay = 21, mirror = true },
		{ slot = "ReceiveLeftB", delay = 38 }, { slot = "ReceiveRightB", delay = 45, mirror = true },
	},
	variants = {
		-- Keep existing marker/orbit geometry, fit each new master's own radius.
		-- The collapsed marker scales about the bottom of its ring without drifting.
		Collapsed = { cycleFrames = 98, receiptDelay = 22, buttonDelay = 8, buttonEnterFrames = 8,
			marker = "Point", markerWidth = 12, markerHeight = 12.706,
			markerY = 37.4, particleRadius = 37.4, pulseScale = 0.36,
			crescent = "ThinCrescent", crescentSourceRadius = 152.2,
			crescentEnterDuration = 12 / 30, crescentEnterOffset = 0,
		},
		Expanded = { cycleFrames = 90, receiptDelay = 13, buttonDelay = 2, buttonEnterFrames = 13,
			marker = "Icon", markerWidth = 24 * 0.76, markerHeight = 17 * 0.76,
			markerY = 42, particleRadius = 40.3, pulseScale = 0.26,
			crescent = "ThickCrescent", crescentSourceRadius = 158.5,
			crescentEnterDuration = 13 / 30, crescentEnterOffset = 11,
		},
	},
}
GF.BLACKLIST_ICON_TEXTURE = GF.ADDON_ART_ICON_PATH .. "Blacklist.png"
GF.LEAVER_ICON_TEXTURE = GF.ADDON_ART_ICON_PATH .. "isLeaver.png"
GF.CENSORED_RESULT_ICON_TEXTURE = GF.ADDON_ART_ICON_PATH .. "Censored.png"
GF.CENSORED_RESULT_REVEAL_COLOR = {
	r = 233 / 255,
	g = 213 / 255,
	b = 255 / 255,
}
GF.CENSORED_RESULT_TEXT_COLOR = {
	r = 216 / 255,
	g = 180 / 255,
	b = 254 / 255,
}
GF.CENSORED_RESULT_COMMENT_COLOR = {
	r = 167 / 255,
	g = 139 / 255,
	b = 189 / 255,
}
GF.MYTHIC_PLUS_TELEPORT_ICON_ATLAS = "MagePortalAlliance"
GF.MYTHIC_PLUS_ACTION_BUTTON_HEIGHT = GF.COMMON_BUTTON_STYLE.height
GF.MYTHIC_PLUS_KEYSTONE_ANNOUNCE_ATLAS = "questlog-tab-icon-event"
GF.MYTHIC_PLUS_TACTICAL_MAX_MESSAGES = 5
-- Each tactical body line is sent as its own chat message between the
-- localized start/end separators, so it can use the full chat byte ceiling.
GF.MYTHIC_PLUS_TACTICAL_INPUT_MAX_BYTES = 255
GF.MYTHIC_PLUS_SCORE_COLOR_RULE = {
	OVERALL = "overall",
	SINGLE_DUNGEON = "single_dungeon",
}
GF.MYTHIC_PLUS_SEASON_DUNGEON_SORT_RULE = {
	scoreDirection = "DESC",
	missingScore = 0,
	orderDirection = "ASC",
	orderFields = {
		"seasonMapOrder",
		"orderIndex",
		"sourceOrder",
	},
	preserveInputOrder = true,
}
GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_WIDTH = 17
GF.MYTHIC_PLUS_ROSTER_ROW_TRANSITION_STYLE = {
	fadeInDuration = 0.20, fadeOutDuration = 0.18,
}
GF.MYTHIC_PLUS_CARPOOL_SPLIT_STYLE = {
	gap = 0, rowInsetRight = 0, transitionDuration = 0.28,
	divider = {
		atlas = GF.MAIN_PANEL_DECORATIVE_BORDER_ATLAS,
		-- Relative crops in the authored 171 x 171 transmog frame. Atlas file
		-- and packed UV coordinates are resolved by the shared native helper.
		-- Sample the two metal texel centers, excluding both shadow columns.
		lineRegion = { 156.5 / 171, 157.5 / 171, 60 / 171, 90 / 171 },
		lineWidth = 2,
		-- Top metal occupies source rows 15..16; bottom metal starts at 155.
		-- Project these inner edges through the outer atlas's actual slice data.
		topInnerEdge = 17 / 171, bottomInnerEdge = 16 / 171,
		fallbackTopInset = 5, fallbackBottomInset = 10,
		ornament = {
			atlas = "questlog-frame-filigree",
			-- This darker source needs a lighter tint to match transmog corner metal.
			color = { 0.90, 0.80, 0.64, 1 },
			centerFromBottom = 15 / 171,
			fallbackOffsetY = -1,
			offsetX = 0.5,
			-- The filigree's horizontal join is 3px above its texture center.
			offsetY = -3,
		},
	},
	compactWidth = 640, compactBlendWidth = 160,
	columnWidths = { name = 112, armor = 40, key = 120, rating = 50, roles = 68, teleport = 36, last = 80 },
}
GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_OFFSET_X = 17
GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_TOP_OFFSET = -4
GF.MYTHIC_PLUS_WORKSPACE_SCROLLBAR_BOTTOM_OFFSET = 4
GF.MYTHIC_PLUS_CHARACTER_SCROLL_TOP_INSET = 4
GF.MYTHIC_PLUS_CHARACTER_CONTENT_INSET_X = 24
GF.MYTHIC_PLUS_CHARACTER_TITLE_INSET_LEFT = GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT
GF.MYTHIC_PLUS_CHARACTER_PLAYER_MODEL = {
	portraitZoom = 0.46, positionZ = -0.20, facing = 0.40,
}
GF.TOP_NOTICE_TOAST_ATLAS = "evergreen-scenario-TitleBG"
GF.TOP_NOTICE_TOAST_SOUND = GF.ADDON_SOUNDS_PATH .. "Glass.aiff"
-- 兼容现有进组通报入口；共享视觉与声音由 TopNoticeToast 所有。
GF.JOIN_ANNOUNCE_TOAST_ATLAS = GF.TOP_NOTICE_TOAST_ATLAS
GF.JOIN_ANNOUNCE_TOAST_SOUND = GF.TOP_NOTICE_TOAST_SOUND
GF.APPLICANT_ALERT_SOUND_COOLDOWN_SECONDS = 10
GF.APPLICANT_ALERT_SOUND_LEGACY_DEFAULT = "Glass.aiff"
GF.APPLICANT_ALERT_SOUND_DEFAULT = "xalatath.mp3"
GF.APPLICANT_ALERT_SOUND_NATIVE = "native"
-- FileDataID, not SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION (47615).
GF.NATIVE_APPLICANT_ALERT_SOUND_FILE_ID = 1067667
GF.APPLICANT_ALERT_SOUND_OPTIONS = {
	{ file = "xalatath.mp3", labelKey = "SET_APPLICANT_ALERT_SOUND_XALATATH", label = "萨拉塔斯" },
	{ file = "malacrass.mp3", labelKey = "SET_APPLICANT_ALERT_SOUND_MALACRASS", label = "玛拉卡斯" },
	{ file = "millhouse.mp3", labelKey = "SET_APPLICANT_ALERT_SOUND_MILLHOUSE", label = "米尔豪斯" },
	{ file = "murloc.ogg", labelKey = "SET_APPLICANT_ALERT_SOUND_AIYURAS", label = "艾鱼拉斯" },
	{ file = "sylvanas.mp3", labelKey = "SET_APPLICANT_ALERT_SOUND_SYLVANAS", label = "希尔瓦娜斯" },
	{ file = "Glass.aiff", labelKey = "SET_APPLICANT_ALERT_SOUND_GLASS", label = "清脆提示音" },
	{ file = GF.APPLICANT_ALERT_SOUND_NATIVE, labelKey = "SET_APPLICANT_ALERT_SOUND_NATIVE", label = "原生提示音" },
	{ file = "", labelKey = "SET_APPLICANT_ALERT_SOUND_OFF", label = "关闭" },
}
GF.ROLE_VACANCY_THRESHOLD_MIN = 1
GF.ROLE_VACANCY_THRESHOLD_MAX = 4
-- 聊天消息格式与输出逻辑见 ChatMessages.lua。
GF.MAIN_WINDOW_LOGO_TEXTURE = GF.ADDON_LOGO_TEXTURE
GF.MAIN_WINDOW_LOGO_SIZE = 54
GF.MINIMAP_ICON_TEXTURE = GF.ADDON_LOGO_TEXTURE
GF.MINIMAP_BUTTON_STYLE = {
	buttonSize = 31,
	iconSize = 23,
	pressedIconSize = 22,
	pressedTint = 0.86,
	-- Reuse the floating launcher's complete ring, preserving its 73:74 canvas.
	ringTexture = GF.FLOATING_ART.ring,
	ringWidth = 28,
	ringHeight = 28 * 74 / 73,
	highlightColor = { 1, 0.86, 0.55, 0.32 },
}
GF.ROLE_ICON_ATLAS = {
	LEADER = "UI-LFG-RoleIcon-Leader",
	GUIDE = "UI-LFG-RoleIcon-Leader",
	TANK = "UI-LFG-RoleIcon-Tank",
	HEALER = "UI-LFG-RoleIcon-Healer",
	DAMAGER = "UI-LFG-RoleIcon-DPS",
	DPS = "UI-LFG-RoleIcon-DPS",
	NONE = "groupfinder-icon-emptyslot",
	DEFAULT = "groupfinder-icon-emptyslot",
}
GF.SEASON_DUNGEON_ROLE_ATLAS = GF.ROLE_ICON_ATLAS
GF.LEADER_ICON_ATLAS = GF.ROLE_ICON_ATLAS.LEADER
GF.TOOLTIP_LEADER_ICON_ATLAS = GF.LEADER_ICON_ATLAS
GF.ROLE_ICON_SIZE = 18
GF.TOOLTIP_ROLE_ICON_SIZE = GF.ROLE_ICON_SIZE
GF.NON_ROLE_ICON_SIZE = 18
GF.MPLUS_BROWSE_PROJECTION_SLOT_SIZE = 20
-- Blizzard role atlases include about 1px of transparent edge padding. A
-- 20px draw box yields a visible 18px disc, matching the specialization icon
-- together with its full class-colored outer ring.
GF.MPLUS_BROWSE_ROLE_PROJECTION_ICON_SIZE = 20
GF.MPLUS_BROWSE_SPEC_PROJECTION_ICON_SIZE = 18
GF.MPLUS_BROWSE_SPEC_PROJECTION_ICON_INSET = 2.25
GF.MPLUS_BROWSE_PROJECTION_START_GAP = 5
GF.MPLUS_BROWSE_PROJECTION_ICON_GAP = 1
GF.MPLUS_BROWSE_MATCH_LABEL_W = 24
GF.MPLUS_BROWSE_MATCH_LABEL_FIT_W = 23
GF.MPLUS_BROWSE_FILTER_LABEL_TEXT_SIZE = 12
GF.MPLUS_BROWSE_MATCH_LABEL_MIN_FONT_SIZE = 8
GF.MPLUS_BROWSE_MATCH_CHECK_W = 16
GF.MPLUS_BROWSE_MATCH_CHECK_H = 16
GF.MPLUS_BROWSE_MATCH_CHECK_LABEL_GAP = 4
-- The keybind atlas is optically shifted 1.5px right inside its logical slot.
-- Half of that shift recenters the full visible checkbox-to-icons group.
GF.MPLUS_BROWSE_MATCH_ROW_VISUAL_OFFSET_X = -0.75
GF.MPLUS_BROWSE_MATCH_CHECK_ATLAS_OFFSET_X = 1.5
GF.MPLUS_BROWSE_MATCH_CHECK_ATLAS_OFFSET_Y = 0
GF.MPLUS_BROWSE_MATCH_CHECK_MARK_OFFSET_X = 1.5
GF.MPLUS_BROWSE_MATCH_CHECK_MARK_OFFSET_Y = 0
GF.MPLUS_BROWSE_MATCH_CHECK_ATLAS = {
	normal = "keybind-bg",
	hover = "keybind-bg_active",
	checked = "keybind-bg_active",
}
GF.MPLUS_BROWSE_PROJECTION_MAX_MEMBERS = 5
GF.MPLUS_BROWSE_PROJECTION_EMPTY_ALPHA = 0.72
GF.MPLUS_BROWSE_PROJECTION_EMPTY_DISABLED_TINT = 0.72
GF.FILTER_DISABLED_ICON_TINT = 0.58
GF.MPLUS_BROWSE_FILTER_DISABLED_ICON_TINT = GF.FILTER_DISABLED_ICON_TINT
GF.MPLUS_BROWSE_FILTER_DISABLED_TEXT_COLOR = { 0.48, 0.47, 0.44, 1 }
GF.MPLUS_BROWSE_CHECK_DISABLED_TINT = 0.72
GF.MPLUS_BROWSE_CHECK_DISABLED_ALPHA = 1
-- Shared spacing for Mythic+ Browse and Create sidebars.
-- Distances are logical UI units; see Docs/AIContext/MPLUS_BROWSE_SIDEBAR_LAYOUT.md.
GF.MPLUS_LFG_SIDEBAR_SPACING = {
	contentTopGap = 12,
	contentBottomInset = 8,
	sectionTitleHeight = 16,
	titleControlGap = 4,
	sectionGap = 12,
	cardInsetY = 8,
	rowHeight = 28,
	thresholdTopInset = 8,
	thresholdBottomInset = 4,
	searchGap = 8,
	-- Minimum clearance required at the supported window height; checked by layout contracts.
	actionMinGap = 8,
}
-- Compatibility name; both surfaces consume the same table, never a copy.
GF.MPLUS_BROWSE_SIDEBAR_SPACING = GF.MPLUS_LFG_SIDEBAR_SPACING
-- Native description height; the existing chrome adds 4 units per edge.
GF.MPLUS_CREATE_SIDEBAR_DESC_H = 64
GF.MPLUS_BROWSE_SIDEBAR_STYLE = {
	roleCardInsetX = 8,
	roleIconSize = 22,
	roleIconLabelGap = 3,
	roleNameWidth = 32,
	roleNameHeight = 14,
	roleChoiceHeight = 24,
	roleChoiceGap = 4,
	roleChoiceLabelGap = 3,
	thresholdDividerInset = 0,
	thresholdDividerCoreHeight = 1,
	bodyColor = { 232 / 255, 224 / 255, 208 / 255, 1 },
	mutedColor = { 165 / 255, 161 / 255, 154 / 255, 1 },
}
GF.MPLUS_BROWSE_THRESHOLD_OPEN_INPUT_W = 24
GF.MPLUS_BROWSE_THRESHOLD_SCORE_INPUT_W = 68
GF.MPLUS_BROWSE_THRESHOLD_STEP_BUTTON_OFFSET_Y = -0.5
-- A plain warm-gold rule fades out without native atlas end caps.
GF.MPLUS_BROWSE_THRESHOLD_DIVIDER_COLOR = { 0.78, 0.70, 0.56, 1 }
GF.MPLUS_BROWSE_THRESHOLD_DIVIDER_CORE_ALPHA = 0.65
GF.CREATE_SIDEBAR_DESC_H = 72
GF.FACTION_ICON_TEXTURES = {
	Alliance = "Interface\\FriendsFrame\\PlusManz-Alliance",
	Horde = "Interface\\FriendsFrame\\PlusManz-Horde",
}
GF.RECOMMENDED_SEARCH_MASK = bit.bor(
	Enum.LFGListFilter.Recommended,
	Enum.LFGListFilter.NotRecommended)
-- PvP 评分分级逻辑见 PvpRating.lua。
-- 社交关系与玩家名规范化逻辑见 PlayerIdentity.lua。
-- GF 卫星面板内边距：与当前使用的 Blizzard 平面板外观对齐。
GF.FRAME_BG_INSET_LEFT = 7
GF.FRAME_BG_INSET_TOP = -18
GF.FRAME_BG_INSET_RIGHT = -2
GF.FRAME_BG_INSET_BOTTOM = 3
GF.NAV_WIDTH = 180
GF.NAV_WIDTH_MIN = 180
GF.NAV_WIDTH_MAX = 180
-- 两页表单／卡片的名义宽度；原生下拉与搜索框在其中居中内缩。
GF.MPLUS_LFG_SIDEBAR_CONTROL_W = GF.NAV_WIDTH - 16
GF.MPLUS_LFG_SIDEBAR_NATIVE_CONTROL_W = GF.MPLUS_LFG_SIDEBAR_CONTROL_W - 2
-- 标题参数沿用共享规范；旧 10 间距仅供集合石／团本只读表单。
GF.MPLUS_LFG_SIDEBAR_SECTION_TITLE_H = GF.MPLUS_LFG_SIDEBAR_SPACING.sectionTitleHeight
GF.MPLUS_LFG_SIDEBAR_SECTION_TITLE_INSET_X = 2
GF.MPLUS_LFG_SIDEBAR_TITLE_CONTROL_GAP = GF.MPLUS_LFG_SIDEBAR_SPACING.titleControlGap
GF.MPLUS_LFG_SIDEBAR_BLOCK_GAP = 10
GF.MPLUS_LFG_SIDEBAR_FORM_TOP_INSET = 8
-- 寻找队伍三组筛选卡与创建招募使用同一 164px 名义宽度基准。
GF.MPLUS_BROWSE_FILTER_OUTER_W = GF.MPLUS_LFG_SIDEBAR_CONTROL_W
GF.NAV_DIVIDER_GRIP_W = 6
-- 导航竖线（§3.4，改一处即联动）
GF.NAV_DIVIDER_W = 3
GF.NAV_DIVIDER_OFFSET_X = -3
GF.NAV_DIVIDER_TOP_OFFSET = 0
GF.NAV_DIVIDER_BOTTOM_OFFSET = 0
-- End the continuous base inside the transmog frame's horizontal metal strokes.
GF.NAV_DIVIDER_BORDER_TOP_EDGE = 16 / 171
GF.NAV_DIVIDER_BORDER_BOTTOM_EDGE = 15 / 171
GF.NAV_DIVIDER_BACKING_COLOR = { 0, 0, 0, 1 }
GF.NAV_DIVIDER_COLOR = { 0.38, 0.34, 0.24, 0.9 }
GF.NAV_DIVIDER_HIGHLIGHT_COLOR = { 0.62, 0.55, 0.38, 0.3 }
GF.NAV_DIVIDER_SHADOW_COLOR = { 0.08, 0.07, 0.05, 0.9 }
GF.NAV_DIVIDER_CENTER_ACCENT_W = 1
GF.NAV_DIVIDER_CENTER_ACCENT_COLOR = { 0.62, 0.55, 0.38 }
GF.NAV_LIST_PADDING_TOP = 8
-- Shared base font size for main navigation roots and settings categories.
GF.NAV_ROOT_TEXT_SIZE = 13
-- Browse, applicants, blacklist, starred leaders and seeking-board member rows.
GF.LIST_ROW_STYLE = {
	height = 34,
	textSize = 13,
	memberIconSize = 20,
	contentOffsetY = -2,
	background = {
		cropTopPixels = 0, cropBottomPixels = 7,
		maxDisplayHeight = false,
		insetTop = 0, insetBottom = 0,
	},
}
GF.LIST_ROW_STYLE.contentHeight = GF.LIST_ROW_STYLE.height - 2 * math.abs(GF.LIST_ROW_STYLE.contentOffsetY)
GF.BROWSE_ROW_TEXT_SIZE = GF.LIST_ROW_STYLE.textSize
-- 队伍、车队、黑名单、星标共用；所有表头视觉参数只在此定义。
GF.SECTION_HEADER_TEXT_SIZE = 14
-- Keep native gold headings; list content uses a separate brightness hierarchy.
GF.NAV_NORMAL_TEXT_COLOR = { 1, 0.82, 0, 1 }
GF.HEADER_ACCENT_COLOR = { 1, 0.82, 0, 1 }
-- Match the settings category rule without coupling it to yellow text.
GF.SETTINGS_HEADER_DIVIDER_COLOR = { 205 / 255, 180 / 255, 119 / 255, 1 }
GF.TEAM_LIST_COLOR_SCHEME_DEFAULT = "default"
GF.TEAM_LIST_COLOR_SCHEME_LOW_SATURATION = "low_saturation"
GF.BROWSE_ROW_TEXT_STYLES = {
	default = { -- 3.0.2
		title = { r = 1, g = 0.82, b = 0 },
		activity = { r = 1, g = 0.82, b = 0 },
		comment = { r = 1, g = 1, b = 1 },
		itemLevel = { r = 0.1, g = 1, b = 0.1 },
	},
	low_saturation = { -- 3.0.3
		title = { r = 232 / 255, g = 224 / 255, b = 208 / 255 }, -- #E8E0D0
		activity = { r = 199 / 255, g = 199 / 255, b = 194 / 255 }, -- #C7C7C2
		comment = { r = 165 / 255, g = 161 / 255, b = 154 / 255 }, -- #A5A19A
		itemLevel = { r = 0.1, g = 1, b = 0.1 },
	},
}
GF.BROWSE_ROW_TEXT_STYLE = GF.BROWSE_ROW_TEXT_STYLES.default
GF.TABLE_HEADER_STYLE = {
	topOffset = -20,
	height = 26,
	listGap = 4,
	panelInsetLeft = GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT,
	panelInsetRight = GF.MAIN_PANEL_BACKPLATE_BG_INSET_RIGHT,
	panelInsetTop = GF.MAIN_PANEL_BACKPLATE_BG_INSET_TOP + 20,
	contentInsetX = 4,
	contentOffsetY = 4,
	textSize = GF.SECTION_HEADER_TEXT_SIZE,
	textInsetX = 3,
	pressedOffsetX = 1,
	pressedOffsetY = -1,
	pressedAlpha = 1,
	textColor = GF.NAV_NORMAL_TEXT_COLOR,
	hoverTextColor = { 1, 0.96, 0.58, 1 },
	pressedTextColor = { 0.95, 0.68, 0.18, 1 },
	backgroundAtlas = "housefinder_header-bg-gradient",
	backgroundInsetLeft = -8,
	backgroundFrameLevelOffset = 1,
	dividerAtlas = "GM-bgOpen-divider-vertical",
	dividerWidth = 1.5,
	dividerHeight = 22,
	dividerColor = { 198 / 255, 168 / 255, 96 / 255 },
	dividerAlpha = 1,
	dividerTexture = GF.WHITE_TEXTURE,
	-- 沿用大秘境车队的原生箭头及右侧 7px 内缩。
	sortArrowAtlas = "auctionhouse-ui-sortarrow",
	sortArrowInset = 7, sortArrowOffsetY = 0,
}
-- 兼容旧入口，现有调用者仍由同一配置派生。
GF.BROWSE_HEADER_TOP_OFFSET = GF.TABLE_HEADER_STYLE.topOffset
GF.SHARED_TABLE_HEADER_HEIGHT = GF.TABLE_HEADER_STYLE.height
GF.SHARED_TABLE_HEADER_LIST_GAP = GF.TABLE_HEADER_STYLE.listGap
GF.SHARED_TABLE_HEADER_PANEL_INSET_LEFT = GF.TABLE_HEADER_STYLE.panelInsetLeft
GF.SHARED_TABLE_HEADER_PANEL_INSET_RIGHT = GF.TABLE_HEADER_STYLE.panelInsetRight
GF.SHARED_TABLE_HEADER_PANEL_INSET_TOP = GF.TABLE_HEADER_STYLE.panelInsetTop
GF.BROWSE_HEADER_CONTENT_INSET_X = GF.TABLE_HEADER_STYLE.contentInsetX
GF.BROWSE_HEADER_CONTENT_OFFSET_Y = GF.TABLE_HEADER_STYLE.contentOffsetY
GF.BROWSE_HEADER_TEXT_SIZE = GF.TABLE_HEADER_STYLE.textSize
GF.BROWSE_HEADER_TEXT_INSET_X = GF.TABLE_HEADER_STYLE.textInsetX
GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_X = GF.TABLE_HEADER_STYLE.pressedOffsetX
GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_Y = GF.TABLE_HEADER_STYLE.pressedOffsetY
GF.BROWSE_HEADER_TEXT_PRESSED_ALPHA = GF.TABLE_HEADER_STYLE.pressedAlpha
GF.BROWSE_HEADER_TEXT_COLOR = GF.TABLE_HEADER_STYLE.textColor
GF.BROWSE_HEADER_HOVER_TEXT_COLOR = GF.TABLE_HEADER_STYLE.hoverTextColor
GF.BROWSE_HEADER_PRESSED_TEXT_COLOR = GF.TABLE_HEADER_STYLE.pressedTextColor
GF.BROWSE_HEADER_BOTTOM_OFFSET = GF.TABLE_HEADER_STYLE.topOffset - GF.TABLE_HEADER_STYLE.height
GF.BROWSE_HEADER_LIST_GAP = 0
-- Browse/applicant edge space belongs to the scrolling content, not the viewport.
GF.LFG_LIST_EDGE_PADDING = 2
GF.LFG_LIST_EDGE_FADE = 24
-- Above list rows and applicant action children; below header/footer controls.
GF.LFG_LIST_CHROME_FRAME_LEVEL_OFFSET = 30
GF.BROWSE_HEADER_TEXT_CENTER_OFFSET_Y = GF.TABLE_HEADER_STYLE.contentOffsetY
GF.QUEUE_STATUS_EYE_NATIVE_SIZE = 45
GF.HOUSING_TASK_FLAG_ATLAS = "housing-dashboard-tasks-listitem-flag"
GF.HOUSING_TASK_CHECKMARK_ATLAS = "housing-dashboard-small-checkmark"
-- Shared by settings cards and the raid seeking sections.
GF.CARD_HEADER_STYLE = {
	height = 34, inset = 2,
	accentLeft = 12, accentWidth = 3, accentHeight = 16, accentAlpha = 0.78,
	accentColor = GF.HEADER_ACCENT_COLOR,
	titleGap = 8, titleRight = 12, titleHeight = 28,
	textSize = 16, textFlags = "OUTLINE", textColor = GF.BROWSE_HEADER_TEXT_COLOR,
	fitInsets = 36, minTextSize = 11,
	dividerInset = 10, dividerAtlas = "Options_HorizontalDivider",
	dividerColor = GF.SETTINGS_HEADER_DIVIDER_COLOR,
}
-- Wide shop frames share a 558x322 authored canvas. A 48px corner contains
-- the complete bevel/glow in all three states; 16px cuts through that artwork.
GF.SHOP_CARD_BANNER_STYLE = {
	normalAtlas = "shop-card-wide-frame-default",
	highlightAtlas = "shop-card-wide-frame-hover",
	selectedAtlas = "shop-card-wide-frame-selected",
	frameSlice = { width = 558, height = 322, corner = 48, scale = 0.5 },
	-- Image aperture in frame source coordinates; corners share its XY scale.
	imageClip = { left = 14, right = 14, top = 12, bottom = 11, corner = 10 },
	-- Journal cards contain their own transparent rim/rounded corners.
	imageContentInset = 0.05,
	textColor = GF.BROWSE_HEADER_TEXT_COLOR,
	textSize = 14, textFlags = "OUTLINE",
	textInset = 14, textInsetY = 8,
	backgroundColor = { 0.03, 0.02, 0.01, 1 },
	imageTint = 0.85, disabledImageTint = 0.35,
	imageNormalAlpha = 0.45, imageActiveAlpha = 1, imageFadeDuration = 0.18,
}
GF.RAID_BROWSE_PANEL_STYLE = {
	-- EncounterInstanceButtonTemplate's Midnight card, not the full Journal background.
	allRaidsTexture = "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-Midnight",
	allRaidsTexCoords = { 0, 0.68359375, 0, 0.7421875 },
	playerModel = {
		bottomInset = 0, gap = 8, minWidth = 80, minHeight = 120,
		bottomOverflowRatio = 0.20, maxBottomOverflow = 48,
		-- Browse and Create use this one zoom value and the same model canvas.
		portraitZoom = 0.20, positionZ = -0.20, facing = 0.35, alpha = 0.9,
	},
	-- The frame artwork already contributes breathing room between cards.
	height = 63, gap = 2, inset = 8, topGap = 5, emptyTop = 145,
}
GF.CREATE_MANAGER_TITLE_TEXT_SIZE = GF.SECTION_HEADER_TEXT_SIZE
GF.CREATE_MANAGER_TITLE_TEXT_COLOR = GF.BROWSE_HEADER_TEXT_COLOR
-- 集合石只读与大秘境组队管理只共享正文禁用视觉；顶部标题条不读取此表。
GF.CREATE_MANAGER_DISABLED_VISUAL = {
	labelTextColor = { 0.72, 0.70, 0.64, 1 },
	inputTextColor = { 0.78, 0.77, 0.72, 1 },
	atlasTint = GF.FILTER_DISABLED_ICON_TINT,
	desaturated = true,
	alpha = 1,
	preserveButtonAlpha = true,
}
GF.CREATE_MANAGER_DROPDOWN_ARROW_ATLAS = "common-dropdown-a-button"
GF.BROWSE_HEADER_BACKGROUND_ATLAS = GF.TABLE_HEADER_STYLE.backgroundAtlas
GF.BROWSE_HEADER_BACKGROUND_INSET_L = GF.TABLE_HEADER_STYLE.backgroundInsetLeft
GF.BROWSE_HEADER_BACKGROUND_FRAME_LEVEL_OFFSET = GF.TABLE_HEADER_STYLE.backgroundFrameLevelOffset
GF.BROWSE_CONTROL_BACKGROUND_ATLAS = GF.BROWSE_HEADER_BACKGROUND_ATLAS
GF.BROWSE_CONTROL_BACKGROUND_ALPHA = 1
GF.BROWSE_HEADER_DIVIDER_ATLAS = GF.TABLE_HEADER_STYLE.dividerAtlas
GF.BROWSE_HEADER_ACCENT_WIDTH = GF.TABLE_HEADER_STYLE.dividerWidth
GF.BROWSE_HEADER_ACCENT_HEIGHT = GF.TABLE_HEADER_STYLE.dividerHeight
GF.BROWSE_HEADER_ACCENT_COLOR = GF.TABLE_HEADER_STYLE.dividerColor
GF.BROWSE_HEADER_ACCENT_ALPHA = GF.TABLE_HEADER_STYLE.dividerAlpha
GF.BROWSE_HEADER_ACCENT_TEXTURE = GF.TABLE_HEADER_STYLE.dividerTexture
GF.EMPTY_PROMPT_TEXT_SIZE = 14
GF.BROWSE_EMPTY_TEXT_SIZE = GF.EMPTY_PROMPT_TEXT_SIZE
GF.BROWSE_EMPTY_ACTION_MIN_WIDTH = 120
GF.BROWSE_EMPTY_ACTION_MAX_WIDTH = 160
GF.BROWSE_EMPTY_ACTION_HORIZONTAL_PADDING = 28
GF.BROWSE_EMPTY_ACTION_GAP = 10
GF.BROWSE_RESULT_ACTION_ROW_MIN_HEIGHT = 36
GF.BROWSE_RESULT_ACTION_SHORT_OFFSET_Y = 10
GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE = 35
GF.BROWSE_HEADER_REFRESH_CLICK_SOUND = "check"
GF.BROWSE_HEADER_REFRESH_ICON_SIZE = 18
-- 悬停只用 ADD 提亮，保持与常态相同的可见尺寸和中心位置。
GF.BROWSE_HEADER_REFRESH_ICON_HOVER_SIZE =
	GF.BROWSE_HEADER_REFRESH_ICON_SIZE
GF.BROWSE_HEADER_REFRESH_ICON_HOVER_GLOW_ALPHA = 0.4
GF.BROWSE_HEADER_REFRESH_ICON_HOVER_GLOW_DESATURATED = true
GF.BROWSE_HEADER_REFRESH_ICON_PRESSED_SIZE =
	GF.BROWSE_HEADER_REFRESH_ICON_SIZE - 2
GF.APPLICANT_HEADER_REFRESH_BUTTON_OFFSET_Y = 0
GF.HEADER_REFRESH_ICON_VISUALS = {
	[GF.BUTTON_VISUAL_STATE.NORMAL] = {
		size = GF.BROWSE_HEADER_REFRESH_ICON_SIZE,
		offset = { 0, 0 },
		alpha = 1,
		desaturated = false,
		blendMode = "BLEND",
	},
	[GF.BUTTON_VISUAL_STATE.HOVER] = {
		size = GF.BROWSE_HEADER_REFRESH_ICON_HOVER_SIZE,
		offset = { 0, 0 },
		alpha = 1,
		desaturated = false,
		blendMode = "ADD",
	},
	[GF.BUTTON_VISUAL_STATE.PRESSED] = {
		size = GF.BROWSE_HEADER_REFRESH_ICON_PRESSED_SIZE,
		offset = { 1, -1 },
		alpha = 0.86,
		desaturated = false,
		blendMode = "BLEND",
	},
	[GF.BUTTON_VISUAL_STATE.DISABLED] = {
		size = GF.BROWSE_HEADER_REFRESH_ICON_SIZE,
		offset = { 0, 0 },
		alpha = 0.45,
		desaturated = true,
		blendMode = "BLEND",
	},
}
GF.BROWSE_LOADING_TEAMUP_ATLASES = GF.TEAMUP_ATLASES
GF.BROWSE_LOADING_ICON_COUNT = 3
GF.BROWSE_LOADING_ICON_SIZE = 25
GF.BROWSE_LOADING_ICON_WIDTH = GF.BROWSE_LOADING_ICON_SIZE
GF.BROWSE_LOADING_ICON_HEIGHT = GF.BROWSE_LOADING_ICON_SIZE
GF.BROWSE_LOADING_ICON_GAP = 6
GF.BROWSE_LOADING_TEXT_GAP = 7
GF.BROWSE_LOADING_STEP_SECONDS = 0.28
GF.BROWSE_LOADING_FADE_IN_SECONDS = 0.16
GF.BROWSE_LOADING_HOLD_SECONDS = 0.4
GF.BROWSE_LOADING_FADE_OUT_SECONDS = 0.45
GF.ROW_BACKGROUND_ATLAS = "UI-QuestTracker-Secondary-Objective-Header"
GF.ROW_BACKGROUND_FALLBACK_TEXTURE = GF.WHITE_TEXTURE
GF.ROW_BACKGROUND_SOURCE_WIDTH = 564
GF.ROW_BACKGROUND_SOURCE_HEIGHT = 52
GF.ROW_BACKGROUND_SOURCE_CAP_WIDTH = 18
GF.ROW_BACKGROUND_TOP_SOURCE_HEIGHT = 8
-- The native atlas ends with a faint bottom rule. Standard list surfaces crop
-- that rule and share one pixel-aligned geometry for base/hover/selected art.
GF.ROW_BACKGROUND_PROFILE = {
	sourceWidth = GF.ROW_BACKGROUND_SOURCE_WIDTH,
	sourceHeight = GF.ROW_BACKGROUND_SOURCE_HEIGHT,
	sourceCapWidth = GF.ROW_BACKGROUND_SOURCE_CAP_WIDTH,
	topSourceHeight = GF.ROW_BACKGROUND_TOP_SOURCE_HEIGHT,
	cropTopPixels = 0,
	cropBottomPixels = 2,
	maxDisplayHeight = 32,
	pixelAligned = true,
	verticalAlign = "CENTER",
	oddPixelBias = "UP",
}
setmetatable(GF.LIST_ROW_STYLE.background, { __index = GF.ROW_BACKGROUND_PROFILE })
-- The cropped menu art has one final height; caps scale with it while only the
-- middle section stretches horizontally. Hit rows keep their own heights.
GF.NAV_FLYOUT_ROW_BACKGROUND_PROFILE = setmetatable({
	maxDisplayHeight = 26,
	insetTop = 2, insetBottom = 2,
}, { __index = GF.LIST_ROW_STYLE.background })
GF.TACTICAL_ROW_BACKGROUND_PROFILE = setmetatable({
	maxDisplayHeight = 32,
	cropReferenceSourceHeight = GF.ROW_BACKGROUND_SOURCE_HEIGHT - 2,
}, { __index = GF.LIST_ROW_STYLE.background })
GF.ROW_BACKGROUND_STATE_COLORS = {
	red = { 1, 0.16, 0.12, 1 },
	blue = { 0.36, 0.68, 1, 1 },
	green = { 0.14, 0.95, 0.24, 1 },
	newbie = { 0.14, 0.95, 0.24, 1 },
	starred = { 72 / 255, 201 / 255, 160 / 255, 1 },
	censored = { 0.62, 0.42, 0.78, 1 },
	grey = { 0.52, 0.52, 0.52, 1 },
}
GF.BROWSE_ROW_NORMAL_COLOR = { 1, 1, 1, 1 }
GF.LIST_BACKGROUND_STYLE_DEFAULTS = {
	normal = {
		-- Match the native header's gold hue on the desaturated list texture.
		r = 1,
		g = 209 / 255,
		b = 0,
		alphaPct = GF.LIST_BACKGROUND_NORMAL_ALPHA_DEFAULT_PCT or 30,
	},
	friend = { r = 0.36, g = 0.68, b = 1, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 },
	starred = { r = 72 / 255, g = 201 / 255, b = 160 / 255, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 },
	application = { r = 0.14, g = 0.95, b = 0.24, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 },
	newbie = { r = 0.14, g = 0.95, b = 0.24, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 },
	censored = { r = 0.62, g = 0.42, b = 0.78, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 },
	warning = { r = 1, g = 0.16, b = 0.12, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 },
	disabled = { r = 0.52, g = 0.52, b = 0.52, alphaPct = GF.LIST_BACKGROUND_ALPHA_DEFAULT_PCT or 100 },
}
GF.LIST_BACKGROUND_STYLE_ORDER = { "normal", "friend", "starred", "application", "newbie", "censored", "warning", "disabled" }
GF.LIST_BACKGROUND_STATE_TO_STYLE = {
	normal = "normal",
	green = "application",
	newbie = "newbie",
	blue = "friend",
	starred = "starred",
	censored = "censored",
	red = "warning",
	grey = "disabled",
}
GF.BROWSE_ROW_BACKGROUND_ALPHA = 0.92
-- In the existing 52-unit source model, trim beyond the native atlas's
-- secondary bottom rule while retaining its main gold edge and gradient.
GF.BROWSE_ROW_BACKGROUND_CROP_BOTTOM_PIXELS = GF.LIST_ROW_STYLE.background.cropBottomPixels
-- Align row content with the cropped native background's visual center.
GF.BROWSE_ROW_CONTENT_OFFSET_Y = GF.LIST_ROW_STYLE.contentOffsetY
GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS = 0.24
GF.BROWSE_ROW_TEXT_FADE_SECONDS = 0.18
GF.BROWSE_BLOCKLIST_RETIRE_SECONDS = 0.28
GF.BROWSE_EXPIRED_RETIRE_GRAY_SECONDS = 0.30
GF.BROWSE_EXPIRED_RETIRE_FADE_SECONDS = 0.50
GF.BROWSE_DECLINED_FILTER_FEEDBACK_SECONDS = 0.8
GF.APPLICANT_DECLINED_MIN_VISIBLE_SECONDS = 0.8
GF.APPLICANT_ACTION_PENDING_TIMEOUT_SECONDS = 3
GF.APPLICANT_DECLINE_PENDING_TIMEOUT_SECONDS = 1.5
GF.APPLICANT_LISTING_LOSS_INVITE_GRACE_SECONDS = 1
GF.BROWSE_ROW_HOVER_COLOR = { 1, 0.74, 0.18, 0.13 }
GF.BROWSE_ROW_HOVER_RED_COLOR = { 1, 0.12, 0.08, 0.18 }
GF.BROWSE_ROW_HOVER_BLUE_COLOR = { 0.35, 0.75, 1, 0.16 }
GF.BROWSE_ROW_HOVER_NEWBIE_COLOR = { 0.2, 1, 0.32, 0.18 }
GF.BROWSE_ROW_HOVER_GREY_COLOR = { 0.65, 0.65, 0.65, 0.18 }
GF.BROWSE_ROW_SELECTED_COLOR = { 1, 0.9, 0.08, 0.82 }
GF.BROWSE_ROW_SELECTED_NEWBIE_COLOR = { 0.18, 1, 0.3, 0.82 }
GF.BROWSE_ROW_SELECTED_ALPHA = 1
GF.BROWSE_ROW_MEMBER_ICON_SIZE = GF.LIST_ROW_STYLE.memberIconSize
GF.BROWSE_ROW_MEMBER_ICON_GAP = 2
GF.BROWSE_ROW_MEMBER_MAX_ICONS = 5
GF.BROWSE_ROW_MEMBER_EMPTY_SLOT_ATLAS = GF.ROLE_ICON_ATLAS.DEFAULT
GF.BROWSE_ROW_MEMBER_ROLE_BADGE_ATLAS = {
	TANK = "UI-LFG-RoleIcon-Tank-Micro",
	HEALER = "UI-LFG-RoleIcon-Healer-Micro",
	DAMAGER = "UI-LFG-RoleIcon-DPS-Micro",
}
-- Keep the original badge-to-member proportions; ListMetrics applies font scale.
GF.BROWSE_ROW_MEMBER_ROLE_BADGE_SIZE = GF.BROWSE_ROW_MEMBER_ICON_SIZE * (12 / 18)
GF.BROWSE_ROW_MEMBER_ROLE_BADGE_LARGE_SIZE = GF.BROWSE_ROW_MEMBER_ICON_SIZE * (14 / 18)
GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_X = 2
GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_Y = 2
GF.BROWSE_ROW_MEMBER_LEADER_BADGE_SIZE = GF.BROWSE_ROW_MEMBER_ROLE_BADGE_SIZE
GF.BROWSE_ROW_MEMBER_LEADER_BADGE_OFFSET_X = GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_X
GF.BROWSE_ROW_MEMBER_LEADER_BADGE_OFFSET_Y = GF.BROWSE_ROW_MEMBER_ROLE_BADGE_OFFSET_Y
GF.MEMBER_DISPLAY_MODE_ROLE = "role"
GF.MEMBER_DISPLAY_MODE_SPEC = "spec"
GF.MEMBER_DISPLAY_MODE_SPEC_LARGE = "spec_large"
GF.MEMBER_DISPLAY_MODE_DEFAULT = GF.MEMBER_DISPLAY_MODE_ROLE
GF.EXPIRED_GROUP_MODE_RETAIN_GRAY = "retain_gray"
GF.EXPIRED_GROUP_MODE_AUTO_REMOVE = "auto_remove"
GF.EXPIRED_GROUP_MODE_DEFAULT = GF.EXPIRED_GROUP_MODE_RETAIN_GRAY
GF.MEMBER_TOOLTIP_MODE_DETAILS = "details"
GF.MEMBER_TOOLTIP_MODE_SPEC_COUNT = "spec_count"
GF.MEMBER_TOOLTIP_MODE_DEFAULT = GF.MEMBER_TOOLTIP_MODE_DETAILS
GF.BROWSE_COLUMN_PRESET_VERSION = 5
GF.APPLICANT_COLUMN_PRESET_VERSION = 7
GF.APPLICANT_ROW_H = GF.LIST_ROW_STYLE.height
GF.APPLICANT_ROW_BACKGROUND_INSET_TOP = GF.LIST_ROW_STYLE.background.insetTop
GF.APPLICANT_ROW_BACKGROUND_INSET_BOTTOM = GF.LIST_ROW_STYLE.background.insetBottom
GF.APPLICANT_ROW_CONTENT_OFFSET_Y = GF.LIST_ROW_STYLE.contentOffsetY
GF.APPLICANT_ACTION_BUTTON_SIZE = GF.COMMON_BUTTON_STYLE.iconButtonSize
GF.APPLICANT_ACTION_BUTTON_GAP = 4
GF.APPLICANT_ACTION_ICON_SIZE = GF.COMMON_BUTTON_STYLE.iconSize
GF.APPLICANT_ACTION_STANDALONE_ICON_SIZE = 26
GF.APPLICANT_ACTION_ICON_COLOR = { 1, 0.82, 0, 1 }
GF.APPLICANT_INVITE_ICON_ATLAS = "common-icon-checkmark-yellow"
GF.APPLICANT_DECLINE_ICON_ATLAS = "common-icon-yellowx"
GF.APPLICANT_VIEW_ICON_ATLAS = "common-icon-visual"
GF.APPLICANT_VIEW_ICON_PRESSED_ATLAS = "common-icon-visual-pressed"
GF.APPLICANT_WHISPER_ICON_TEXTURE = "Interface\\ChatFrame\\UI-ChatWhisperIcon"
GF.SUBTITLE_H = 42
GF.SUBTITLE_HEADER_H = 26
GF.BROWSE_CONTROL_BACKGROUND_H = GF.SUBTITLE_HEADER_H
GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y = 4
-- Default footer chrome fills from the raised top to the host's bottom.
GF.SUBTITLE_CONTROL_CENTER_OFFSET_Y =
	GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y / 2
GF.SUBTITLE_CATEGORY_ACCENT_GAP = 10
GF.SUBTITLE_CATEGORY_MIN_W = 140
GF.SUBTITLE_CONTROL_LEFT_PAD = 15
GF.SUBTITLE_CONTROL_RIGHT_PAD = 10
GF.SUBTITLE_CONTROL_GAP = 7
GF.SUBTITLE_CONTROL_TOP_OFFSET = -8
GF.SUBTITLE_SEARCH_W = 220
GF.SUBTITLE_SEARCH_H = 26
GF.SUBTITLE_SEARCH_CENTER_OFFSET_Y = 0
GF.SUBTITLE_SEARCH_TEXT_SIZE = 12
GF.SUBTITLE_SEARCH_ICON_INSET = 8
GF.SUBTITLE_SEARCH_ICON_SIZE = 14
GF.SUBTITLE_SEARCH_TEXT_INSET_LEFT = 27
GF.SUBTITLE_SEARCH_TEXT_INSET_RIGHT = 24
GF.SUBTITLE_SEARCH_CLEAR_INSET = 6
GF.MPLUS_BROWSE_SEARCH_FIT_PADDING = 2
GF.MPLUS_BROWSE_SEARCH_MIN_TEXT_SIZE = 9
GF.SUBTITLE_SEARCH_TEXT_COLOR = { 1, 0.96, 0.86, 1 }
GF.SUBTITLE_SEARCH_PLACEHOLDER_COLOR = { 0.55, 0.55, 0.55, 1 }
GF.SUBTITLE_SEARCH_OWNERSHIP_POLL_SEC = 0.5
GF.SUBTITLE_OPTION_CHECK_SIZE = 20
GF.SUBTITLE_OPTION_TEXT_SIZE = 13
GF.SUBTITLE_CATEGORY_TEXT_SIZE = 13
-- Shared by the browse footer options and the applicant auto-invite control.
GF.SUBTITLE_OPTION_TEXT_GAP = 4
GF.SUBTITLE_OPTION_GROUP_GAP = 12
GF.SUBTITLE_OPTION_TEXT_COLOR = { 1, 0.82, 0, 1 }
GF.FILTER_FOOTER_H = GF.SUBTITLE_H
GF.FILTER_FOOTER_INSET_L = GF.FRAME_BG_INSET_LEFT
GF.FILTER_FOOTER_INSET_R = GF.FRAME_BG_INSET_RIGHT
GF.FILTER_FOOTER_INSET_B = GF.FRAME_BG_INSET_BOTTOM
-- Preserve the footer action center when the standard height decreases by 2px.
GF.FILTER_FOOTER_BUTTON_OFFSET_Y = 13
GF.FILTER_FOOTER_BUTTON_GAP = 10
GF.FILTER_SCROLL_STYLE = {
	contentEdgePadding = 8, contentTopPadding = 15, edgeFade = 24, insetX = 4,
	-- Match the existing footer gap: 8px padding + 6px trailing dropdown
	-- row space, with ~1px compensation for the native atlas's visible edges.
	-- _UI-Frame-Metal-EdgeTop: the inner metal stroke ends at 76/150
	-- of the atlas rectangle; the remaining shadow/transparent tail is not chrome.
	headerBottomEdge = 76 / 150,
}
GF.FILTER_SCROLLBAR_WIDTH = 8
GF.FILTER_SCROLLBAR_RIGHT_INSET = 8
GF.FILTER_SCROLLBAR_TOP_INSET = 8
GF.FILTER_SCROLLBAR_BOTTOM_INSET = 8
GF.FILTER_TEXT_COLOR = GF.SUBTITLE_OPTION_TEXT_COLOR
GF.SIDE_PANEL_W = 260
GF.FILTER_PANEL_W = GF.SIDE_PANEL_W
GF.FILTER_CHECK_SIZE = 20
GF.FILTER_CHECK_LABEL_GAP = 6
GF.FILTER_NUMBER_INPUT_H = 20
GF.FILTER_STEP_BUTTON_SIZE = GF.COMMON_BUTTON_STYLE.compactSize
GF.FILTER_STEP_BUTTON_GAP = 2
-- Every numeric filter stepper uses this compact arrow geometry.  Keeping it
-- here (rather than falling back to the larger navigation arrow) makes the
-- regular advanced filter and Mythic+ "Min. Open Slots" controls identical.
GF.FILTER_STEP_ARROW_W = 88 / 13
GF.FILTER_STEP_ARROW_H = 11
GF.FILTER_STEP_ARROW_CENTER_OFFSET_X = 1
GF.PANEL_BUTTON_H = GF.COMMON_BUTTON_STYLE.height
GF.PANEL_BUTTON_STANDARD_W = GF.COMMON_BUTTON_STYLE.minimumWidth
GF.PANEL_BUTTON_TWO_CHAR_W = GF.PANEL_BUTTON_STANDARD_W
GF.NETEASE_API_STATUS_BUTTON_W = GF.PANEL_BUTTON_STANDARD_W
-- Shared by Mythic+ Browse and Create; use the standard text-button width.
GF.MPLUS_LFG_SIDEBAR_ACTION_STYLE = {
	buttonWidth = GF.PANEL_BUTTON_STANDARD_W,
	buttonHeight = GF.PANEL_BUTTON_H,
	gap = 8,
	-- Keep the background and form boundary fixed when adjusting button insets.
	footerHeight = 36,
	buttonBottomInset = (36 + GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y - GF.PANEL_BUTTON_H) / 2,
}
GF.PANEL_CONFIRM_BUTTON_W = GF.PANEL_BUTTON_STANDARD_W
GF.PANEL_CONFIRM_BUTTON_FONT_SIZE = 14
GF.INSTANCE_GATEWAY_DIFFICULTY_FONT_SIZE = 14
GF.INSTANCE_GATEWAY_TITLE_FONT_SIZE = 18
GF.APPLICANT_MANAGE_BUTTON_W = GF.PANEL_BUTTON_STANDARD_W
GF.PLAYER_CONTEXT_DIALOG_STYLE = {
	WIDTH = 420,
	HEIGHT = 176,
	LEVEL_OFFSET = 18,
	BACKGROUND_COLOR = GF.PLAYER_CONTEXT_DIALOG_BACKGROUND_COLOR,
	CONTENT_INSET_X = 36,
	CONTENT_TOP_INSET = 38,
	CONTENT_BOTTOM_INSET = 18,
	CONTENT_ACTION_GAP = 12,
	PRIMARY_TEXT_FONT_SIZE = 15,
	SECONDARY_TEXT_FONT_SIZE = 12,
	ACCENT_TEXT_FONT_SIZE = 15,
	PRIMARY_TEXT_COLOR = { 1, 1, 1, 1 },
	SECONDARY_TEXT_COLOR = { 0.78, 0.76, 0.70, 1 },
	ACCENT_TEXT_COLOR = { 1, 0.82, 0, 1 },
	TEXT_LINE_GAP = 5,
	TEXT_TO_INPUT_GAP = 8,
	COPY_HINT_TO_INPUT_GAP = 10,
	COPY_INPUT_CENTER_OFFSET_Y = -12,
	TELEPORT_MESSAGE_CENTER_OFFSET_Y = 4,
	TELEPORT_TEXT_LINE_GAP = 7,
	INPUT_WIDTH = 330,
	INPUT_HEIGHT = 30,
	INPUT_VALUE_FONT_SIZE = 15,
	INPUT_EDIT_FONT_SIZE = 14,
	INPUT_PLACEHOLDER_FONT_SIZE = 12,
	MIN_FITTED_TEXT_SIZE = 10,
	BUTTON_WIDTH = GF.PANEL_BUTTON_STANDARD_W,
	BUTTON_HEIGHT = GF.PANEL_BUTTON_H,
	BUTTON_GAP = 12,
	BUTTON_FONT_SIZE = 15,
	SCREEN_OFFSET_Y = 20,
}
GF.APPLICANT_ACTIVE_ROLE_SUMMARY_W = 168
GF.APPLICANT_ACTIVE_ROLE_SUMMARY_X = 6
GF.NAV_L0_ROW_H = 45
GF.NAV_L0_BUTTON_H = 43
GF.NAV_ROW_H = { [0] = GF.NAV_L0_ROW_H, [1] = 38, [2] = 34, [3] = 30 }
GF.NAV_TRANSMOG_BUTTON_H = { [0] = GF.NAV_L0_BUTTON_H, [1] = 34, [2] = 30, [3] = 26 }
GF.NAV_TRANSMOG_BUTTON_OFFSET_X = 0
GF.NAV_TRANSMOG_BUTTON_WIDTH_PAD = { [0] = 20, [1] = 32, [2] = 44, [3] = 56 }
GF.NAV_TRANSMOG_BUTTON_TEXT_LEFT = { [0] = 12, [1] = 14, [2] = 16, [3] = 18 }
GF.NAV_TRANSMOG_BUTTON_TEXT_RIGHT = 8
GF.NAV_QUICK_SEARCH_ICON_ATLAS = "common-search-magnifyingglass"
GF.NAV_QUICK_SEARCH_ICON_TEXTURE = "Interface\\Common\\UI-Searchbox-Icon"
GF.NAV_QUICK_SEARCH_ICON_SIZE = 14
GF.NAV_QUICK_SEARCH_ICON_GAP = 3
GF.NAV_SEARCH_RESIZE_DURATION = 0.20
GF.NAV_QUICK_SEARCH_CLEAR_ATLAS = "common-icon-delete"
GF.NAV_QUICK_SEARCH_CLEAR_SIZE = 22
GF.NAV_QUICK_SEARCH_CLEAR_ICON_SIZE = 16
GF.NAV_QUICK_SEARCH_CLEAR_GAP = 4
GF.NAV_QUICK_SEARCH_CLEAR_PRESSED_SCALE = 0.82
GF.NAV_QUICK_SEARCH_CLEAR_RELEASE_DURATION = 0.12
GF.NAV_QUICK_SEARCH_CLEAR_FADE_DURATION = 0.18
GF.FAVORITE_INSTANCE_ICON_ATLAS = "campcollection-icon-star"
GF.FAVORITE_INSTANCE_ICON_SIZE = 14
GF.FAVORITE_INSTANCE_ICON_GAP = 3
GF.NAV_L0_ROW_SPACING = 2
GF.NAV_ROW_H_DEFAULT = 28
GF.NAV_FLYOUT_PANEL_MIN_W = 120
GF.NAV_FLYOUT_PANEL_MAX_W = 260
GF.NAV_FLYOUT_ROOT_GAP = 2
GF.NAV_FLYOUT_ROOT_ANCHOR_GAP_X = 4
GF.NAV_FLYOUT_ROOT_ANCHOR_GAP_Y = 2
GF.NAV_FLYOUT_PANEL_GAP = 6
GF.NAV_FLYOUT_STAIR_STEP_Y = 9
GF.NAV_FLYOUT_SCREEN_MARGIN_TOP = 12
GF.NAV_FLYOUT_SCREEN_MARGIN_BOTTOM = 12
GF.NAV_FLYOUT_WINDOW_BOTTOM_GAP = 0
GF.NAV_FLYOUT_ROW_H = { [1] = 32, [2] = 32, [3] = 30 }
GF.NAV_FLYOUT_ROW_H_DEFAULT = 30
GF.NAV_FLYOUT_ROW_TEXT_L = 12
GF.NAV_FLYOUT_ROW_TEXT_R = 10
GF.NAV_FLYOUT_ROW_TEXT_INSET_Y = 2
-- Optical correction relative to the drawn background, not the click row.
GF.NAV_FLYOUT_CONTENT_OPTICAL_OFFSET_Y = -1
GF.NAV_FLYOUT_FAVORITE_ICON_OFFSET_Y = -1 -- Additional star artwork correction.
GF.NAV_FLYOUT_ARROW_ATLAS = "bag-arrow"
GF.NAV_FLYOUT_ARROW_W = 10
GF.NAV_FLYOUT_ARROW_H = 16
GF.NAV_FLYOUT_ARROW_R = 8
GF.NAV_FLYOUT_ARROW_RESERVE_W = 28
GF.NAV_FLYOUT_LABEL_EXTRA_W = 8
GF.NAV_FLYOUT_HIGHLIGHT_INSET_X = 3
GF.NAV_FLYOUT_ROW_TEXTURE_EXTEND_X = 16
GF.NAV_FLYOUT_HIGHLIGHT_ATLAS = GF.ROW_BACKGROUND_ATLAS
GF.NAV_FLYOUT_BG_ATLAS = "common-dropdown-bg"
GF.NAV_FLYOUT_BG_EXTEND_X = 10
GF.NAV_FLYOUT_BG_EXTEND_TOP = 3
GF.NAV_FLYOUT_BG_EXTEND_BOTTOM = 3
GF.NAV_FLYOUT_BG_ALPHA = 0.925
GF.NAV_FLYOUT_CONTENT_INSET_L = 8
GF.NAV_FLYOUT_CONTENT_INSET_R = 8
GF.NAV_FLYOUT_CONTENT_INSET_T = 8
GF.NAV_FLYOUT_CONTENT_INSET_B = 15
GF.LIST_ROW_H = 32
GF.LIST_ROW_H_DEFAULT = 32
GF.BROWSE_ROW_H = GF.LIST_ROW_STYLE.height
GF.BROWSE_TEXT_CELL_INSET_X = 2
GF.ROLE_COUNT_ICON_DEFAULT = GF.BROWSE_ROW_MEMBER_ICON_SIZE
GF.ROLE_COUNT_NUM_ICON_GAP = 5
local function publishConstants(values)
	for name, value in pairs(values) do
		GF[name] = value
	end
end

-- 内容区 scroll 右缘留白 + 滚动条贴窗右（各内容页共用，仅改此处）
publishConstants({
	CONTENT_SCROLL_INSET_L = 5,
	CONTENT_SCROLL_INSET_R = 18,
	CONTENT_SCROLL_INSET_B = 0,
	CONTENT_SCROLLBAR_OFFSET_X = 9,
	LIST_CONTENT_EDGE_PAD = 18,
	LIST_CONTENT_EDGE_PAD_MAX = 30,
	LIST_COL_REF_W = 930,
	ACTIVITY_COUNT_RIGHT = 28,
	LIST_WHEEL_ROWS_DEFAULT = 3,
	AUTO_INVITE_MEMBER_LIMIT_MIN = 1,
	AUTO_INVITE_MEMBER_LIMIT_MAX = 40,
	AUTO_INVITE_MEMBER_LIMIT_DEFAULT = 40,
	NAV_WHEEL_ROW_H = 28,
	SETTINGS_WHEEL_ROW_H = 24,
	SETTINGS_SCROLL_EDGE_FADE = 24,
	MYTHIC_PLUS_SCROLL_EDGE_FADE = 24,
	SETTINGS_COL_W = 280,
	SETTINGS_GUTTER_MIN = 50,
	SETTINGS_GUTTER_WEIGHT = 1,
})
-- 内容区相对 nav 右缘水平偏移（负=向左靠分割线）
GF.CONTENT_NAV_OFFSET_X = 0
-- Raised list atlas backgrounds must stop at the navigation divider's right
-- edge. Their old -3px overhang covered half of the lower-level 3px divider.
GF.LFG_LIST_CHROME_LEFT_INSET = GF.NAV_DIVIDER_OFFSET_X
	+ GF.NAV_DIVIDER_W / 2 - GF.CONTENT_NAV_OFFSET_X
GF.LFG_LIST_HEADER_BACKGROUND_INSET_L = GF.LFG_LIST_CHROME_LEFT_INSET
	- GF.CONTENT_SCROLL_INSET_L
-- 列表行四列左边界（在 LIST_COL_REF_W 参考行宽下的 px）
-- host 左缘到石纹内缘；右缘 CONTENT_SCROLL_INSET_R 为滚动条走廊
GF.SETTINGS_LAYOUT_INSET_L = (GF.FRAME_BG_INSET_LEFT or 7) - (GF.FRAME_PAD or 4)
-- 设置页最外层分区标题与滚动条走廊。
publishConstants({
	SETTINGS_SCROLLBAR_WIDTH = 17,
	SETTINGS_SCROLLBAR_GAP = 2,
	SETTINGS_SCROLLBAR_RIGHT_INSET = 10,
	SETTINGS_SCROLLBAR_TOP_INSET = 8,
	SETTINGS_SCROLLBAR_BOTTOM_INSET = 8,
	-- 设置卡片自带 24 内缩，只需较小的动态避让量。
	SETTINGS_SCROLLBAR_GUTTER = 12,
})
GF.SETTINGS_VISIBLE_CONTENT_INSET_R =
	GF.SETTINGS_SCROLLBAR_WIDTH
	+ GF.SETTINGS_SCROLLBAR_GAP
	+ GF.SETTINGS_SCROLLBAR_RIGHT_INSET
-- WowStyle1Dropdown 等控件相对列 Frame 左缘的视觉外溢
-- 设置页控件行距：下拉/滑块底留白 8 + 分区表头前 12 + 表头内锚 8 = 表头上方 28px
publishConstants({
	SETTINGS_CONTENT_TOP_OFFSET = 20,
	SETTINGS_SECTION_TITLE_H = 40,
	SETTINGS_COL_EDGE_INSET_L = 10,
	SETTINGS_ROW_BOTTOM_PAD = 8,
	SETTINGS_SECTION_TOP_PAD = 12,
	SETTINGS_DROPDOWN_W = 260,
	SETTINGS_DROPDOWN_H = 26,
	SETTINGS_SLIDER_W = 220,
	SETTINGS_SLIDER_H = 19,
	FILTER_WHEEL_ROW_H = 28,
	BLOCKLIST_WHEEL_ROW_H = 28,
})
GF.CREATE_DRAWER_W = 600
GF.CREATE_DRAWER_H = 390
GF.CREATE_DRAWER_HORIZONTAL_MIN_W = 560
GF.CREATE_FORM_COLUMN_GAP = 16
GF.RAID_RECRUITMENT_NEEDS_STYLE = {
	titleSize = 14, textSize = 14, headerHeight = 24, titleGap = 5, bottomGap = 6,
	roleIconSize = 24, roleButtonGap = 8, roleRightInset = 2,
	roleFadeDuration = 0.2, roleInactiveTint = 0.72, roleInactiveAlpha = 0.6,
	listInset = 8, rowHeight = 24, rowGap = 2, rowInset = 0,
	optionHeight = 22, optionGap = 6,
	optionBodyInset = 6, optionTextGap = 6, optionTextRightInset = 6,
	optionAtlases = {
		normal = "common-button-tertiary-normal",
		hover = "common-button-tertiary-hover",
		pressed = "common-button-tertiary-pressed",
		-- Used only if the native pending-effect template is unavailable.
		selected = "common-button-tertiary-selected",
	},
	pendingFX = {
		addon = "Blizzard_Transmog", template = "DisplayTypeButtonTemplate",
		borderAtlas = "common-button-tertiary-depressed-normal-glow-purple",
		color = { 1, 0.82, 0, 1 },
		width = 188, height = 36,
		parts = {
			{ "StateTexture", 192, 40, 0, 1 },
			{ "FlipbookTop", 160, 14, 0, 14 },
			{ "FlipbookBottom", 170, 14, 5, -13 },
			{ "PendingFX", 192, 40, 0, 1 },
		},
	},
	specIconSlotSize = 24, specIconSize = 18, specIconOffsetY = 1, iconSize = 18, iconGap = 4,
	classMinWidth = 84, columnGap = 8,
	disabledAlpha = 0.48,
	textNormalColor = { 0.78, 0.77, 0.72, 1 },
}
-- Use the action bar's native proc loop and its normal 1.4x visual padding.
GF.GREAT_VAULT_READY_FX_STYLE = {
	template = "ActionButtonSpellAlertTemplate",
	scale = 1.4,
}
GF.RAID_CREATE_DRAWER_STYLE = {
	width = 648, height = 500, columnGap = 20, leftWidth = 240, descriptionHeight = 100,
}
GF.CREATE_DRAWER_AVOID_ALPHA = 0.64
GF.CREATE_DRAWER_MAIN_ALPHA = GF.CREATE_DRAWER_AVOID_ALPHA
publishConstants({
	CREATE_WHEEL_ROW_H = 24,
	LIST_REFRESH_DEBOUNCE = 0.2,
	BROWSE_LISTEN_HOLD_SEC = 60,
	BROWSE_SORT_KEY_BATCH = 25,
	FILTER_BATCH = 25,
	ROW_UPDATE_DEBOUNCE = 0.2,
	LAYOUT_RESIZE_DEBOUNCE = 0.1,
	SEARCH_COOLDOWN = 3,
	SEARCH_TIMEOUT_SECONDS = 8,
})

GF.TAB_BROWSE = 1
GF.TAB_CREATE = 2
GF.TAB_BLOCKLIST = 3
GF.TAB_SETTINGS = 4
GF.TAB_MPLUS_CHARACTER = 101
GF.TAB_MPLUS_GROUP = 102
GF.TAB_MPLUS_CARPOOL = 103
GF.TAB_MPLUS_DUNGEON = 104
GF.TAB_RAID_SEEK = 201
GF.TAB_RAID_SQUARE = 202
GF.TAB_STARRED_LEADERS = 203
GF.STARRED_LEADER_ICON_SIZE = 14
GF.STARRED_LEADER_ICON_ATLAS = "campcollection-icon-star"
GF.STARRED_LEADER_ICON_GAP = 4
GF.BROWSE_STARRED_TITLE_GAP = 2
GF.BROWSE_STARRED_LEADER_NAME_GAP = 2
GF.STARRED_LEADER_DISABLED_ALPHA = 0.5
GF.STARRED_LEADER_DISPLAY_TYPE = "starred_leader"
GF.STARRED_LEADER_TYPE_ICON_TEXTURE = GF.ADDON_ART_ICON_PATH .. "Star.png"
GF.STARRED_LEADER_BADGE = "|A:campcollection-icon-star:14:14|a "
-- Shared note and empty text roles for the blacklist and starred-leader lists.
-- Name colors are defined separately in each list's style.
GF.PLAYER_MANAGEMENT_TEXT_STYLE = {
	body = { 1, 0.94, 0.82, 1 },
	empty = { 0.72, 0.66, 0.5, 1 },
}
-- Player tooltips share the starred-leader palette, independently of list text.
GF.PLAYER_MANAGEMENT_TOOLTIP_STYLE = {
	heading = GF.NAV_NORMAL_TEXT_COLOR,
	value = { 1, 1, 1, 1 },
	empty = { 0.6, 0.6, 0.6, 1 },
	note = { 24 / 255, 1, 27 / 255, 1 },
}
GF.BLACKLIST_ROW_TEXT_STYLE = {
	name = GF.NAV_NORMAL_TEXT_COLOR,
	note = GF.PLAYER_MANAGEMENT_TEXT_STYLE.body,
	empty = GF.PLAYER_MANAGEMENT_TEXT_STYLE.empty,
	updated = GF.PLAYER_MANAGEMENT_TEXT_STYLE.empty,
	reason = {
		-- Visual emphasis: title parent > linked title > ad = manual.
		ad = { 199 / 255, 183 / 255, 138 / 255, 1 }, -- #C7B78A soft champagne gold
		title_parent = { 1, 120 / 255, 96 / 255, 1 }, -- #FF7860 vermilion
		same_title_ad = { 190 / 255, 128 / 255, 105 / 255, 1 }, -- #BE8069 red brown
		manual = { 199 / 255, 183 / 255, 138 / 255, 1 }, -- #C7B78A same gold as ad
	},
}
-- Native metal label artwork; keep text and sizing independent of the atlas.
GF.BLACKLIST_REASON_BADGE_STYLE = {
	atlas = "common-button-tertiary-normal-small",
	height = 22, minWidth = 76, maxWidth = 112, fontSize = GF.LIST_ROW_STYLE.textSize, minFontSize = 10,
	textPadding = 12,
	fallbackColor = { 23 / 255, 20 / 255, 15 / 255, 1 }, -- #17140F
}
GF.PLAYER_MANAGEMENT_STYLE = {
	rowHeight = GF.LIST_ROW_STYLE.height, textInset = 10,
	listEdgePadding = 2,
	scrollEdgeFade = 24,
	buttonWidth = GF.PANEL_BUTTON_STANDARD_W, buttonHeight = GF.PANEL_BUTTON_H, buttonGap = GF.COMMON_BUTTON_STYLE.gap, buttonFontSize = 12, buttonMinFontSize = 10,
	categoryMinWidth = 112, categoryMaxWidth = 150, categoryRatio = 0.11,
	actionRatio = 0.10, actionExtraWidth = 16, layoutWidthInset = 12,
	scrollBarGutter = GF.SETTINGS_VISIBLE_CONTENT_INSET_R,
	scrollBarWidth = GF.SETTINGS_SCROLLBAR_WIDTH,
	scrollBarRightInset = GF.SETTINGS_SCROLLBAR_RIGHT_INSET,
	scrollBarDuration = 0.2, scrollBarOverflowEpsilon = 1,
}
-- Shared by starred/blacklist clear and single-player removal.
GF.PLAYER_MANAGEMENT_CONFIRM_STYLE = {
	width = 420, minHeight = 132, padding = 24,
	iconSize = 36, iconGap = 12,
	messageFontSize = 18, messageMinHeight = 24, messageHeightPadding = 2,
	messageColor = { 1, 1, 1, 1 }, messageButtonGap = 20,
	buttonWidth = GF.PANEL_CONFIRM_BUTTON_W, buttonHeight = GF.PANEL_BUTTON_H,
	buttonFontSize = GF.PANEL_CONFIRM_BUTTON_FONT_SIZE, buttonGap = 16,
	mainAlpha = 0.64, frameStrata = "DIALOG", frameLevel = 1000,
	animationPreset = "dialog",
}
GF.PLAYER_MANAGEMENT_DIALOG_STYLE = {
	width = 420, contentInset = 24, titleInset = 40, inputHeight = 28, inputTextInset = 8,
	labelGap = 6, noteHeight = 56,
	noteTextInset = GF.FILTER_MULTILINE_INPUT_CONTENT_INSET,
	rowGap = 12, noticeToFormGap = 16,
	-- Match the first field label's inset below the native title bar.
	actionGap = GF.PLAYER_CONTEXT_DIALOG_STYLE.CONTENT_TOP_INSET
		+ GF.PLAYER_CONTEXT_DIALOG_STYLE.TEXT_LINE_GAP + GF.FRAME_BG_INSET_TOP,
	actionBarHeight = 42, actionBarBottomInset = GF.FRAME_BG_INSET_BOTTOM,
	titleFontSize = 15, labelFontSize = 12, inputFontSize = 12, placeholderFontSize = 12,
	labelColor = GF.PLAYER_CONTEXT_DIALOG_STYLE.SECONDARY_TEXT_COLOR,
	buttonFontSize = 12, buttonGap = 12,
	buttonWidth = GF.PLAYER_CONTEXT_DIALOG_STYLE.BUTTON_WIDTH,
	buttonHeight = GF.PLAYER_CONTEXT_DIALOG_STYLE.BUTTON_HEIGHT,
	minFontSize = GF.PLAYER_CONTEXT_DIALOG_STYLE.MIN_FITTED_TEXT_SIZE,
	backgroundColor = { 0.025, 0.022, 0.018, 1 },
	mainAlpha = GF.CREATE_DRAWER_AVOID_ALPHA,
}
-- Only the blacklist identity notice has its own scale and spacing. All other
-- fields continue to follow the shared player-management dialog profile.
GF.BLACKLIST_NOTE_DIALOG_STYLE = setmetatable({
	noticeFontSize = 13, noticeMinFontSize = 12, noticeToFormGap = 10,
	noticeColor = GF.PLAYER_CONTEXT_DIALOG_STYLE.SECONDARY_TEXT_COLOR,
}, { __index = GF.PLAYER_MANAGEMENT_DIALOG_STYLE })
-- Compatibility alias: both editors read the same table, never a copied profile.
GF.STARRED_LEADER_DIALOG_STYLE = GF.PLAYER_MANAGEMENT_DIALOG_STYLE
GF.PLAYER_MANAGEMENT_FOOTER_STYLE = {
	searchWidth = 200, sectionGap = 12,
	minHeight = GF.SUBTITLE_H, paddingY = 8, minFontSize = 10,
	titleWidthRatio = 0.3,
	hintColor = GF.PLAYER_CONTEXT_DIALOG_STYLE.SECONDARY_TEXT_COLOR,
}
GF.STARRED_LEADERS_STYLE = {
	rowHeight = GF.PLAYER_MANAGEMENT_STYLE.rowHeight,
	textInset = GF.PLAYER_MANAGEMENT_STYLE.textInset,
	statusWidth = 64, whisperWidth = 64,
	statusIconSize = 20, statusHitSize = 24,
	classIconSize = GF.LIST_ROW_STYLE.memberIconSize, classIconInset = 2,
	unknownClassIconSize = 16,
	unknownClassTexture = "Interface\\TutorialFrame\\UI-TutorialFrame-TheDude",
	-- Alpha bounds of the native 128px texture: x [0, 81), y [50, 128).
	unknownClassTexCoords = { 0, 81 / 128, 50 / 128, 1 },
	nameColor = GF.NAV_NORMAL_TEXT_COLOR,
	noteColor = GF.PLAYER_MANAGEMENT_TEXT_STYLE.body,
	contactColor = { 0.35, 0.75, 1, 1 },
	updatedColor = GF.PLAYER_MANAGEMENT_TEXT_STYLE.empty,
	updatedTooltipColor = GF.PLAYER_MANAGEMENT_TOOLTIP_STYLE.value,
	emptyTextColor = GF.PLAYER_MANAGEMENT_TEXT_STYLE.empty,
	noteTooltipColor = GF.PLAYER_MANAGEMENT_TOOLTIP_STYLE.note,
	stateTransitionDuration = 0.2,
	whisperTransitionDuration = 0.35,
	whisperBlendOverlap = 0.75,
	whisperAtlas = "charactercreate-icon-customize-speechbubble-selected",
	whisperDisabledAtlas = "charactercreate-icon-customize-speechbubble",
	actionPressMotion = { pressedScale = 0.7, releaseDuration = 0.16 },
	statusAtlases = {
		online = "friends-status-online", offline = "friends-status-offline",
		away = "friends-status-away", busy = "friends-status-busy",
		unknown = "friends-icon-addFriend",
	},
	playerRatio = 0.32, contactRatio = 0.32,
	onlineColor = { 24 / 255, 1, 27 / 255, 1 },
	awayColor = { 1, 0.82, 0, 1 }, busyColor = { 1, 0.25, 0.25, 1 },
	offlineColor = GF.PLAYER_MANAGEMENT_TOOLTIP_STYLE.empty,
	unknownColor = GF.PLAYER_CONTEXT_DIALOG_STYLE.SECONDARY_TEXT_COLOR,
}

GF.RAID_SEEKING_CHAT_STYLE = {
	maxConversations = 32, maxMessages = 100, maxMessageBytes = 2048, sendMaxBytes = 255,
	incomingSoundKitID = 316445, -- Bubble Echo when the arriving conversation is not being read.
	viewedIncomingSoundKitID = 353426, -- Water Drop while viewing that conversation at the bottom.
	tabHeight = GF.MAIN_PANEL_TAB_HEIGHT, tabMinWidth = 80, tabMaxWidth = 100, tabGap = 4, tabArrowWidth = 24,
	tabTopOffset = 12, tabScale = 0.8,
	unreadBadgeScale = 0.8,
	unreadArrowGlowWidth = 32, unreadArrowGlowHeight = 32,
	footerHeight = GF.SUBTITLE_H, footerInset = 12, inputHeight = 28, inputTextInset = 10,
	footerEdgeInset = 2, openLeaderWidth = GF.PANEL_BUTTON_STANDARD_W,
	presenceDuration = 0.22, messageFadeDuration = 0.22,
	statusAtlas = "perks-list-active", statusMinHeight = 28, statusTextInsetY = 6, statusDuration = 0.24,
	statusColor = { 0.62, 0.43, 0.24, 1 },
	messageSpacing = 3,
	gap = 8, messageGap = 14, messageEdgeInset = 8, avatarSize = 28, specSize = 14, specGap = 4,
	nameHeight = 18, headerGap = 6, bubbleInset = 10, bubbleMinHeight = 28,
	headerMetaFontExtra = -1, headerDividerWidth = 1, headerDividerHeight = 16,
	headerDividerColor = { 1, 0.82, 0, 1 }, headerMetaColor = { 0.62, 0.62, 0.62, 1 },
	messageTextSize = 12, scrollGutter = 12, scrollEdgeInset = 1,
	scrollEdgeFade = 24,
	scrollRightInset = 12, scrollBarWidth = 8, scrollDuration = 0.2, scrollOverflowEpsilon = 1,
	activityColor = { 1, 0.82, 0, 1 },
	menuTextColor = { 1, 1, 1, 1 },
	menuActivityFontScale = 0.85,
	itemLevelColor = { 0.4, 0.9, 0.55, 1 }, unknownNameColor = { 1, 0.82, 0, 1 },
}

GF.RAID_SEEKING_BOARD_STYLE = {
	offerHintColor = { 0, 1, 0 },
	inset = 12, gap = 8, headerHeight = 26, rowHeight = GF.APPLICANT_ROW_H,
	footerHeight = 44, filterHeight = 26, resetWidth = GF.PANEL_BUTTON_STANDARD_W,
	rowInset = 6, detailInset = 12, detailTopPadding = 6, detailBottomPadding = 12, detailColumnGap = 8,
	detailAnimationDuration = 0.22, detailSlideDistance = 12,
	iconSize = GF.LIST_ROW_STYLE.memberIconSize, roleIconSize = GF.LIST_ROW_STYLE.memberIconSize, iconGap = 4,
	scrollGutter = 16, scrollEdgeInset = 1, contentEdgeInset = 4,
	scrollEdgeFade = 24,
	filterMenuHeight = 360, specMenuWidth = 352,
	columns = {
		{ key = "BOARD_NAME", weight = 0.45 },
		{ key = "BOARD_SPECS", width = 96 },
		{ key = "role", width = 76 },
		{ key = "BOARD_ITEM_LEVEL", width = 48 },
		{ key = "BOARD_NOTE", weight = 0.55 },
		{ key = "BOARD_ACTIONS", width = 96 },
	},
}

GF.RAID_SEEKING_STYLE = {
	inset = 14, gap = 10, feedbackLineHeight = 20,
	sideWidth = 360, fieldWidth = 332, buttonWidth = 106, columnGap = 11,
	-- Preserve the form's width while tighter gaps give both right cards more room.
	formRatio = 0.20, formWidthReserve = 68, sectionHeaderHeight = GF.CARD_HEADER_STYLE.height,
	openLeaderWidth = 140,
	contentInset = 16, contentTop = 12, titleGap = 8, blockGap = 16, lineSpacing = 4, actionGap = 8,
	activityBottomInset = 8,
	activityScrollEdgeInset = 4, activityContentTopInset = 4,
	activityScrollEdgeFade = 24,
	activityScrollGutter = 12, activityScrollRightInset = 12, activityScrollBarWidth = 8,
	activityScrollDuration = 0.2, activityOverflowEpsilon = 1,
	activityRowFadeDuration = 0.22, activityRowStagger = 0.05, activityPresenceDuration = 0.22,
	subheadingTextSize = 14, noteTextSize = 12, noteInset = 8,
	progressRowHeight = 28, progressRowGap = 8, progressInset = 8,
	awaitingMembersWidth = 110, awaitingProgressWidth = 40, awaitingStatusWidth = 54,
	awaitingColumnGap = 5, awaitingRoleIconSize = 16, awaitingRoleTextWidth = 14, awaitingRoleTextGap = 3,
	awaitingSpinnerSize = 14, awaitingCancelWidth = GF.COMMON_BUTTON_STYLE.iconButtonSize, awaitingFadeDuration = 0.2,
	progressMaskTextures = {
		"Interface\\AddOns\\GroupFinder\\Art\\Masks\\Left",
		"Interface\\AddOns\\GroupFinder\\Art\\Masks\\Center",
		"Interface\\AddOns\\GroupFinder\\Art\\Masks\\Right",
	},
	progressTextGap = 6, progressTextSize = 12, progressMinTextSize = 10,
	progressMinNameWidth = 60, progressDividerGap = 6, progressDividerHeight = 16,
	progressValueFormat = "|cffff0000%d|r/|cff00ff00%d|r",
	progressZeroValueFormat = "|cff00ff00%d|r/|cff00ff00%d|r",
	progressBossNameColor = { 1, 1, 1 }, progressBossDeadNameColor = { 0.62, 0.62, 0.62 },
	progressBossAliveColor = { 0.1, 1, 0.1 }, progressBossDeadColor = { 1, 0.125, 0.125 },
	memberRowHeight = 32, memberRowGap = 8, memberInset = 8, memberRightInset = 24,
	memberBackgroundOutset = 16,
	memberIconGap = 6, memberRoleIconSize = 18,
	memberRoleGap = 6, memberDividerGap = 8, memberDividerHeight = 22,
	memberItemLevelValueFormat = "|cff00ff00%s|r",
	memberItemLevelWidth = 62, memberTextSize = 12, memberMinTextSize = 10,
	memberUnknownIcon = "Interface\\Icons\\INV_Misc_QuestionMark",
	targetInset = 12, targetRowHeight = 52, targetRowGap = 8,
	targetTextSize = 13, targetMinTextSize = 10, targetDifficultyRatio = 0.52,
	targetNameShadowColor = { 0, 0, 0, 1 }, targetNameShadowX = 1, targetNameShadowY = -1,
	targetDifficultyColor = { 1, 1, 1, 1 },
	targetImageWidth = 325, targetImageHeight = 114, targetImageAlpha = 0.5,
	targetMaskAtlas = "perks-list-mask", targetMaskOffsetX = -286,
	targetDividerAtlas = "delves-companion-divider", targetDividerHeight = 2, targetDividerAlpha = 0.5,
	targetDividerInsetPixels = 1,
	activityStatusMaxWidth = 180, activityStatusTextSize = 12, activityStatusMinTextSize = 10,
	roleHeight = 36, roleGap = 6, roleIconSize = 28, roleFadeDuration = 0.2,
	roleIconFrameInset = 3, roleIconTexCoordInset = 0.06,
	roleIconMaskTexture = GF.ADDON_ART_PATH .. "Masks\\SpecChoiceCutCorners.tga",
	partySpecMenuHeight = 360,
	emptyMenuTextColor = { 0.5, 0.5, 0.5, 1 },
	emptyMenuTextOffsetYPixels = 2.5,
	emptyMenuBackgroundOutsetX = 10, -- MenuStyle1Mixin common-dropdown-bg extends on both sides.
	modeBackground = { atlas = "common-dropdown-textholder", left = -8, top = 7, right = 8, bottom = -9 },
	modeTextLeftInset = 8, -- WowStyle1DropdownTemplate.Text TOPLEFT offset.
	textColor = GF.PLAYER_CONTEXT_DIALOG_STYLE.PRIMARY_TEXT_COLOR,
	mutedColor = GF.PLAYER_CONTEXT_DIALOG_STYLE.SECONDARY_TEXT_COLOR,
	accentColor = GF.CREATE_MANAGER_TITLE_TEXT_COLOR,
	activityBadgeSize = 44, activityBadgeTop = 3,
	activityBadgeEyeSize = 28, activityBadgeFadeDuration = 0.2, activityBadgeMarkX = -1.5, activityBadgeMarkY = 5,
	activityBadgeSpinnerSize = 18, activityBadgeSpinnerX = -1.5, activityBadgeSpinnerY = 4.5,
	liveColor = GF.ROW_BACKGROUND_STATE_COLORS.green,
	tileColor = { 0, 0, 0, 0.16 },
	form = { noteHeight = 80, noteMinHeight = 24, feedbackFadeDuration = 0.16, feedbackExpandDuration = 0.24 },
}

-- Personal-seeking class/spec slots follow the adjacent role icon size.
GF.RAID_SEEKING_STYLE.memberIconSize = GF.RAID_SEEKING_STYLE.memberRoleIconSize

GF.WORKSPACE_MEETING_STONE = "standard"
GF.WORKSPACE_MYTHIC_PLUS = "mythic_plus"
GF.WORKSPACE_RAID = "raid"
GF.WORKSPACE_DEFAULT = GF.WORKSPACE_MEETING_STONE
GF.WORKSPACE_TAB_WIDTH = 43
GF.WORKSPACE_TAB_HEIGHT = 55
GF.WORKSPACE_TAB_GAP = 3
GF.WORKSPACE_TAB_TOP_OFFSET = -64
GF.WORKSPACE_TAB_BOTTOM_OFFSET_X = 24
GF.WORKSPACE_TAB_POSITION_DEFAULT = "right"
GF.WORKSPACE_TAB_ICON_SIZE = 18
GF.WORKSPACE_TAB_ICON_OFFSET_X = -3
GF.WORKSPACE_TAB_ICON_OFFSET_Y = 0
GF.WORKSPACE_TAB_TOOLTIP_GAP = 4
GF.WORKSPACE_TAB_BETA_BADGE_SCALE = 0.8
GF.WORKSPACE_TAB_BETA_BADGE_OFFSET_X = -6
GF.WORKSPACE_TAB_BETA_BADGE_OFFSET_Y = -4
GF.WORKSPACE_TAB_NORMAL_ATLAS = "common-sidetab"
GF.WORKSPACE_TAB_SELECTED_ATLAS = "common-sidetab-selected"
GF.WORKSPACE_TAB_HOVER_ATLAS = "common-sidetab-hover"
GF.WORKSPACE_TAB_NORMAL_ICON_COLOR = { 0.72, 0.62, 0.22, 0.85 }
GF.WORKSPACE_TAB_DISABLED_ICON_COLOR = { 0.48, 0.42, 0.18, 0.85 }
GF.WORKSPACE_TAB_ICON_TEXTURES = {
	[GF.WORKSPACE_MEETING_STONE] = GF.ADDON_ART_ICON_PATH .. "WorkspaceMeetingStone.png",
	[GF.WORKSPACE_MYTHIC_PLUS] = GF.ADDON_ART_ICON_PATH .. "WorkspaceMythicPlus.png",
	[GF.WORKSPACE_RAID] = GF.ADDON_ART_ICON_PATH .. "WorkspaceRaid.png",
}


GF.APPLY_MANUAL = "manual"
GF.APPLY_CLICK_CONFIRM = "click_confirm"
GF.APPLY_DBLCLICK_AUTO = "dblclick_auto"

GF.LIST_HOVER_TOOLTIP_HIDE_DELAY = 0.1

publishConstants({
	FRAME_STRATA_DEFAULT = "MEDIUM",
	FRAME_STRATA_CHOICES = { "LOW", "MEDIUM", "HIGH", "DIALOG" },
	CAT_QUEST = 1,
	CAT_DUNGEON = 2,
	CAT_RAID = 3,
	CAT_CUSTOM = 6,
	CAT_DELVE = 121,
	ACTIVITY_CUSTOM_PVE = 16,
	ACTIVITY_CUSTOM_PVP = 17,
	ACTIVITY_HOUSEWARMING = 1972,
	BODY_BACKGROUND_COLOR = { 0.05, 0.05, 0.08, 0.75 },
	SEL_TEX = "Interface\\PVPFrame\\PvPMegaQueue",
	SEL_TEX_HOVER = { 0.00195313, 0.63867188, 0.70703125, 0.76757813 },
	SEL_TEX_SELECTED = { 0.00195313, 0.63867188, 0.76953125, 0.83007813 },
})

local pvpCategoryDefinitions = {
	{ 8, "PVP_BG" },
	{ 4, "PVP_ARENA" },
	{ 9, "PVP_RATED" },
	{ 7, "PVP_SKIRMISH" },
}
GF.PVP_CATEGORIES = {}
for index = 1, #pvpCategoryDefinitions do
	local definition = pvpCategoryDefinitions[index]
	GF.PVP_CATEGORIES[index] = { id = definition[1], key = definition[2] }
end

function GF.GetBrowseListLayoutWidth()
	local owner = GF.FindGroupTab
	local measure = owner and owner.GetLayoutWidth
	return measure and measure(owner) or 1
end

function GF.GetApplicantListLayoutWidth()
	local list = GF.ApplicantsPanel and GF.ApplicantsPanel.scrollList
	local measure = list and list.GetLayoutWidth
	return measure and measure(list) or 1
end

-- Temporary raid-leader request strip immediately above the browse controls.
GF.RAID_LEADER_LOOKUP_STYLE = {
	backgroundAtlas = GF.RAID_SEEKING_CHAT_STYLE.statusAtlas,
	backgroundColor = GF.RAID_SEEKING_CHAT_STYLE.statusColor,
	height = 30, footerGap = 2, inset = 8, gap = 8,
	buttonHeight = GF.PANEL_BUTTON_H,
}
