local _, GF = ...

GF.UsageGuideDialog = {}
local UGD = GF.UsageGuideDialog

local LAYOUT = {
	DIALOG_W = 760,
	DIALOG_H = 688,
	ABOUT_LETTER_SPACE = 56,
	BODY_LEFT = 28,
	BODY_RIGHT = 28,
	BODY_TOP = -52,
	BODY_BOTTOM = 26,
	BODY_BG_INSET_LEFT = GF.FRAME_BG_INSET_LEFT or 7,
	BODY_BG_INSET_TOP = GF.FRAME_BG_INSET_TOP or -18,
	BODY_BG_INSET_RIGHT = GF.FRAME_BG_INSET_RIGHT or -2,
	BODY_BG_INSET_BOTTOM = GF.FRAME_BG_INSET_BOTTOM or 3,
	LOGO_TEXTURE = GF.ADDON_MENU_LOGO_TEXTURE,
	WHITE = GF.WHITE_TEXTURE,
	TITLE_BAND_H = 180,
	TITLE_BAND_INSET_X = -16,
	TITLE_BAND_TOP_Y = -28,
	LOGO_SIZE = 72,
	BRAND_TOP = -50,
	VERSION_BADGE_SCALE = 0.8,
	VERSION_BADGE_GAP = 4,
	TITLE_DESC_GAP = 12,
	INTRO_W = 548,
	INFO_BOX_H = 200,
	INFO_BOX_INSET_X = 24,
	INFO_BOX_OFFSET_X = 3,
	INFO_BOX_BOTTOM_Y = 38,
	NOTICE_SCROLL_INSET_L = 24,
	NOTICE_SCROLL_INSET_R = 32,
	NOTICE_SCROLL_INSET_T = 3,
	NOTICE_SCROLL_INSET_B = 3,
	NOTICE_SCROLLBAR_GAP = 8,
	NOTICE_SCROLLBAR_W = 8,
	NOTICE_SECTION_TITLE_H = 36,
	NOTICE_SECTION_TITLE_TEXT_INSET = 12,
	NOTICE_SECTION_TITLE_GAP = 12,
	NOTICE_SECTION_TITLE_ATLAS = "housing-basic-panel-gradient-header-bg",
	NOTICE_VERSION_ROW_H = 26,
	NOTICE_VERSION_GAP = 12,
	NOTICE_ENTRY_GAP = 20,
	NOTICE_LINE_GAP = 4,
	NOTICE_ITEM_GAP = 6,
	NOTICE_BODY_LINE_SPACING = 4,
	NOTICE_BULLET_ATLAS = "housing-dashboard-fillbar-pip-complete",
	NOTICE_BULLET_SIZE = 16,
	NOTICE_BULLET_GAP = 4,
	NOTICE_LABEL_GAP = 8,
	NOTICE_SECTION_GAP = 6,
	LETTER_SIGNATURE_INSET_R = 16,
	COMMAND_TOP_GAP = 18,
	INFO_LEFT_X = 64,
	INFO_RIGHT_X = 388,
	INFO_TOP_GAP = 12,
}
LAYOUT.CONTENT_W =
	LAYOUT.DIALOG_W - LAYOUT.BODY_LEFT - LAYOUT.BODY_RIGHT
LAYOUT.CONTENT_H =
	LAYOUT.DIALOG_H + LAYOUT.BODY_TOP - LAYOUT.BODY_BOTTOM
LAYOUT.NOTICE_TEXT_W =
	LAYOUT.CONTENT_W
		- LAYOUT.INFO_BOX_INSET_X * 2
		- LAYOUT.NOTICE_SCROLL_INSET_L
		- LAYOUT.NOTICE_SCROLL_INSET_R
LAYOUT.NOTICE_SCROLL_H =
	LAYOUT.INFO_BOX_H
		- LAYOUT.NOTICE_SCROLL_INSET_T
		- LAYOUT.NOTICE_SCROLL_INSET_B

local STYLE = {
	FOOTER_COPYRIGHT_TEXT =
		"COPYRIGHT 2026 GAICAS.COM ALL RIGHTS RESERVED.",
	MAIN_GOLD = { 1, 0.82, 0, 1 },
	BODY_TEXT = { 238 / 255, 228 / 255, 205 / 255, 1 },
	FOOTER_GRAY = { 138 / 255, 135 / 255, 127 / 255, 1 },
	NOTICE_GRAY = { 0.42, 0.42, 0.42, 1 },
	FONT_BRAND_TITLE = 30,
	FONT_DESCRIPTION_TEXT = 14,
	FONT_COMMAND_TEXT = 20,
	FONT_COMMAND_TITLE = 18,
	FONT_INFO_TEXT = 15,
	FONT_NOTICE_TEXT = 13,
	FONT_NOTICE_TITLE = 18,
	FONT_NOTICE_VERSION = 17,
	FONT_FOOTER_TEXT = 12,
}

UGD.AUTHOR_CHARACTER = "草东"
UGD.AUTHOR_REALM = "白银之手"
UGD.AUTHOR_WHISPER_TARGET = UGD.AUTHOR_CHARACTER
	.. "-" .. UGD.AUTHOR_REALM

local NOTICE_CATEGORY_ORDER = {
	"renamed",
	"new",
	"fixed",
	"improved",
	"compatibility",
	"refactored",
}

local NOTICE_CATEGORY_PREFIXES = {
	renamed = {
		"更名：",
		"Renamed:",
		"Переименовано:",
	},
	new = {
		"新增：",
		"New:",
		"Добавлено:",
		"Added:",
	},
	fixed = {
		"修复：",
		"修復：",
		"修正：",
		"Fixed:",
		"Исправлено:",
	},
	improved = {
		"优化：",
		"優化：",
		"最佳化：",
		"调整：",
		"調整：",
		"Improved:",
		"Улучшено:",
		"Adjusted:",
	},
	compatibility = {
		"适配：",
		"適配：",
		"相容：",
		"相容性：",
		"Compatibility:",
		"Совместимость:",
		"Adapted:",
	},
	refactored = {
		"维护：",
		"維護：",
		"Maintenance:",
		"Обслуживание:",
		"重构：",
		"重構：",
		"Refactored:",
		"Переработано:",
	},
}
local NOTICE_CATEGORY_PREFIX_COLOR_CODE = "|cffffd100"
local NOTICE_COLOR_RESET_CODE = "|r"

local NOTICE_PREFIX_CATEGORY = {}
local NOTICE_PREFIXES = {}
for _, categoryID in ipairs(NOTICE_CATEGORY_ORDER) do
	for _, prefix in ipairs(NOTICE_CATEGORY_PREFIXES[categoryID]) do
		NOTICE_PREFIX_CATEGORY[prefix] = categoryID
		NOTICE_PREFIXES[#NOTICE_PREFIXES + 1] = prefix
	end
end

local function getAddonVersion()
	if type(GF.GetAddonVersion) == "function" then
		return GF.GetAddonVersion()
	end
	local version
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		local ok, value = pcall(C_AddOns.GetAddOnMetadata, "GroupFinder", "Version")
		if ok then
			version = value
		end
	elseif GetAddOnMetadata then
		local ok, value = pcall(GetAddOnMetadata, "GroupFinder", "Version")
		if ok then
			version = value
		end
	end
	if type(version) == "string" and version ~= "" then
		return version
	end
	return "3.0.5-r1"
end

local function setFont(fs, template, size, flags)
	if not fs then
		return
	end
	fs._gfFontSizeOverride = size
	fs._gfFontFlagsOverride = flags
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fs, template or "GameFontHighlight")
	end
end

local function colorText(fs, color)
	if fs and color then
		fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	end
end

local function paint(texture, r, g, b, a)
	if not texture then
		return
	end
	if texture.SetColorTexture then
		texture:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
	else
		texture:SetTexture(LAYOUT.WHITE)
		texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
end

local function applyDialogBackground(f)
	if not f then
		return
	end
	if f.Bg then
		f.Bg:Hide()
	end
	local fill = f.gfBodyBg and f.gfBodyBg.fill
	if fill then
		fill:ClearAllPoints()
		fill:SetPoint(
			"TOPLEFT",
			f,
			"TOPLEFT",
			LAYOUT.BODY_BG_INSET_LEFT,
			LAYOUT.BODY_BG_INSET_TOP)
		fill:SetPoint(
			"BOTTOMRIGHT",
			f,
			"BOTTOMRIGHT",
			LAYOUT.BODY_BG_INSET_RIGHT,
			LAYOUT.BODY_BG_INSET_BOTTOM)
		fill:SetAtlas(nil)
		fill:SetTexture(nil)
		local style = GF.ABOUT_STYLE
		local color = style.backgroundColor
		paint(fill, color[1], color[2], color[3], style.backgroundAlpha)
		fill:Show()
	end
end

local function showSystemTitle(f)
	local fs = f and f.systemTitleText
	if fs and fs.Show then
		fs:Show()
	end
end

local function createText(parent, template, size, color, flags)
	local fs = GF.UI.CreateFontString(parent, "ARTWORK", template or "GameFontHighlight")
	setFont(fs, template or "GameFontHighlight", size or 12, flags or "")
	colorText(fs, color or STYLE.BODY_TEXT)
	return fs
end

local function parseNoticeBodyLine(text)
	if type(text) ~= "string" or text == "" then
		return nil, nil, nil
	end
	for _, prefix in ipairs(NOTICE_PREFIXES) do
		if text:sub(1, #prefix) == prefix then
			local body = text:sub(#prefix + 1)
			while body:sub(1, 1) == " " do
				body = body:sub(2)
			end
			if body == "" then
				return nil, nil, nil
			end
			return NOTICE_PREFIX_CATEGORY[prefix], prefix, body
		end
	end
	return nil, nil, nil
end

local function getTextWidth(fs, fallback)
	local width = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
	if type(width) ~= "number" or width <= 0 then
		return fallback or 0
	end
	return width
end

local function refreshBrandLayout(f)
	if not f then
		return
	end
	local titleW = math.ceil(getTextWidth(f.brandTitle, 220))
	local versionW = math.ceil(getTextWidth(f.versionBadge.Label, 36))
	f.brandLine:SetSize(LAYOUT.CONTENT_W, 42)
	f.brandTitle:SetWidth(titleW + 8)
	f.brandTitle:ClearAllPoints()
	f.brandTitle:SetPoint("CENTER", f.brandLine, "CENTER", 0, 0)
	-- Align the native Label with the title's vertical center, keeping the
	-- visible text gap independent of the glow frame's padding.
	f.versionBadge:ClearAllPoints()
	f.versionBadge:SetPoint("CENTER", f.brandTitle, "RIGHT",
		versionW / 2 + LAYOUT.VERSION_BADGE_GAP, 0)
end

-- The card owns three distinct regions: native chrome, native interior,
-- and content. No opaque slice ever includes the interior's background.
local AboutCard = {}

function AboutCard.CreateSurface(panel)
	local art = { normal = {} }
	local interior = CreateFrame("Frame", nil, panel)
	interior:EnableMouse(false)
	panel.Interior = interior
	local center = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
	panel.Center = center
	function art:UpdateColor()
		local style = GF.ABOUT_STYLE
		local color = self.pressed and style.pressedBorderColor
			or self.hovered and style.hoverBorderColor or style.borderColor
		for _, key in ipairs({ "topLeft", "top", "topRight", "left", "right", "bottomLeft", "bottom", "bottomRight" }) do
			local edge = self.normal[key]
			if edge then edge:SetVertexColor(unpack(color)); edge:SetAlpha(1) end
		end
	end
	function art:Refresh()
		local spec = GF.ABOUT_STYLE.frame
		local info = GF.UI.GetNativeAtlasInfo(GF.MYTHIC_PLUS_FRAME_ATLASES.border)
		local edges = GF.UI.ApplyControlFrameBorder(panel, {
			atlas = GF.MYTHIC_PLUS_FRAME_ATLASES.border, atlasInfo = info,
			sliceRatios = { left = spec.sourceCap / spec.sourceWidth, right = 1 - spec.sourceCap / spec.sourceWidth,
				top = spec.sourceCap / spec.sourceHeight, bottom = 1 - spec.sourceCap / spec.sourceHeight },
			sourceCrop = info and { left = info.logicalWidth * spec.cropLeft / spec.sourceWidth,
				right = info.logicalWidth * spec.cropRight / spec.sourceWidth,
				top = info.logicalHeight * spec.cropTop / spec.sourceHeight,
				bottom = info.logicalHeight * spec.cropBottom / spec.sourceHeight },
			displayMargins = { left = (spec.sourceCap - spec.cropLeft) * spec.scale,
				right = (spec.sourceCap - spec.cropRight) * spec.scale,
				top = (spec.sourceCap - spec.cropTop) * spec.scale,
				bottom = (spec.sourceCap - spec.cropBottom) * spec.scale },
			layer = "BORDER", color = GF.ABOUT_STYLE.borderColor,
			continuousInternalUV = true, halfTexelInset = false, snapToPixelGrid = false,
		})
		self.ready = type(edges) == "table"
		if not self.ready then center:Hide(); return end
		self.normal, panel.Border = edges, edges
		interior:ClearAllPoints()
		interior:SetPoint("TOPLEFT", panel, "TOPLEFT", spec.interiorLeft, -spec.interiorTop)
		interior:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -spec.interiorRight, spec.interiorBottom)
		center:SetAtlas(GF.MYTHIC_PLUS_FRAME_ATLASES.brown, false)
		center:SetDesaturated(true)
		center:SetAllPoints(interior)
		center:Show()
		self:UpdateColor()
	end
	function art:SetHovered(value) self.hovered = value; self:UpdateColor() end
	function art:SetPressed(value) self.pressed = value; self:UpdateColor() end
	art:Refresh()
	return art
end

local function refreshPanelTheme(f, panelSkin)
	if not (f and f.aboutPanels) then return end
	local style = GF.ABOUT_STYLE
	local key = panelSkin or (GF.GetPanelSkin and GF.GetPanelSkin()) or "default"
	local color = style.themeColors[key] or style.themeColors.default
	local r, g, b, a = unpack(color)
	for _, spec in ipairs(GF.PANEL_SKIN_OPTIONS or {}) do
		if spec.value == key then
			local configured = (spec.colorKey and _G[spec.colorKey]) or spec.color
			if type(configured) == "table" then
				if type(configured.GetRGBA) == "function" then
					r, g, b, a = configured:GetRGBA()
				else
					r, g, b, a = configured.r or configured[1], configured.g or configured[2],
						configured.b or configured[3], configured.a or configured[4] or 0.8
				end
			end
			break
		end
	end
	if key == "default" then r, g, b = 0.82, 0.72, 0.54
	else
		local peak = math.max(r, g, b, 0.001)
		r, g, b = 0.75 + 0.25 * r / peak, 0.75 + 0.25 * g / peak, 0.75 + 0.25 * b / peak
	end
	for _, panel in ipairs(f.aboutPanels) do
		panel.Center:SetVertexColor(r, g, b, 1)
		panel.Center:SetAlpha((a or 0.8) * style.centerAlphaScale)
	end
end

function UGD:RefreshTheme(panelSkin)
	refreshPanelTheme(self.frame, panelSkin)
	refreshPanelTheme(GF.UserLetterDialog and GF.UserLetterDialog.frame, panelSkin)
end

local function createAboutCard(f, x, y, width, height, frameType)
	local panel = CreateFrame(frameType or "Frame", nil, f.aboutBody)
	panel:SetPoint("TOPLEFT", f.aboutBody, "TOPLEFT", x, -y)
	panel:SetSize(width, height)
	panel.FrameArt = AboutCard.CreateSurface(panel)
	f.aboutPanels[#f.aboutPanels + 1] = panel
	return panel
end

local function createAboutHeading(panel)
	local style = GF.ABOUT_STYLE
	local background = panel:CreateTexture(nil, "ARTWORK")
	background:SetAtlas(LAYOUT.NOTICE_SECTION_TITLE_ATLAS, false)
	background:SetPoint("TOPLEFT", panel, "TOPLEFT", style.headingInset, -style.headingTop)
	background:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -style.headingInset, -style.headingTop)
	background:SetHeight(style.headingHeight)
	panel.HeadingBackground = background
	local title = createText(panel, "GameFontNormalLarge", GF.ABOUT_STYLE.titleSize, STYLE.MAIN_GOLD, "OUTLINE")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -GF.ABOUT_STYLE.titleTop)
	title:SetSize(panel:GetWidth() - 32, 32)
	title:SetJustifyH("CENTER")
	title:SetJustifyV("TOP")
	panel.Title = title
end

local function createAboutScroll(panel, left, right, top, bottom)
	local scroll = GF.UI.CreateScrollFrame(panel, { rowHeight = 24 })
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", left, -top)
	-- This card has fixed logical dimensions. Resolve its viewport even while
	-- the dialog is hidden and has not yet been anchored to the main window.
	scroll:SetSize(panel:GetWidth() - left - right, panel:GetHeight() - top - bottom)
	local body = CreateFrame("Frame", nil, scroll)
	body:SetSize(panel:GetWidth() - left - right, 1)
	scroll:SetScrollChild(body)
	local bar = GF.UI.BindMinimalScrollBar(scroll, GF.ABOUT_STYLE.info.scrollBarGap, panel, true)
	bar:SetWidth(8)
	-- Own visibility from measured content, not native subpixel range noise.
	bar._gfHideIfUnscrollable = nil
	bar:SetHideIfUnscrollable(false)
	bar:SetScrollAllowed(false)
	bar:Hide()
	scroll._gfWheelAllow = function() return scroll._gfInfoScrollable == true end
	GF.UI.BindSmoothWheelScrolling(scroll)
	GF.UI.BindSmoothWheelScrollBar(scroll, bar)
	if GF.UI.BindScrollFrameEdgeFade then
		GF.UI.BindScrollFrameEdgeFade(scroll, body, GF.SETTINGS_SCROLL_EDGE_FADE)
	end
	return scroll, body, bar
end

-- The clip host is anchored to visible content edges, independent of the
-- outer border canvas and its transparent padding. The scroll child owns all
-- leading/trailing space; the host must never add fixed vertical padding.
function AboutCard.CreateScroll(panel, horizontalInset, edgeFadeLength, backgroundOutset)
	local outset = edgeFadeLength and (backgroundOutset or 0) or 0
	local view = { inset = 0 }
	local viewport = CreateFrame("Frame", nil, panel)
	viewport:SetClipsChildren(true)
	viewport:SetPoint("TOPLEFT", panel.HeadingBackground, "BOTTOMLEFT",
		horizontalInset - GF.ABOUT_STYLE.headingInset - outset, 0)
	local scroll = GF.UI.CreateScrollFrame(viewport, { rowHeight = GF.SETTINGS_WHEEL_ROW_H })
	-- Extend only the decoration clip; input geometry and text width stay put.
	if outset > 0 then
		scroll:SetPoint("TOPLEFT", viewport, "TOPLEFT", outset, 0)
		scroll:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -outset, 0)
	else
		scroll:SetAllPoints(viewport)
	end
	local body = CreateFrame("Frame", nil, edgeFadeLength and viewport or scroll)
	body:SetSize(panel:GetWidth() - horizontalInset * 2, 1)
	local extent = body
	if edgeFadeLength then
		-- ScrollFrame's child is rendered separately and does not inherit a
		-- Frame edge gradient. Keep its extent for the shared input adapter,
		-- but translate the visible content inside a normal native clip host,
		-- just as ScrollBoxBaseMixin:SetScrollTargetOffset does.
		extent = CreateFrame("Frame", nil, scroll)
		extent:SetSize(body:GetWidth(), 1)
		viewport:SetFlattensRenderLayers(true)
		body:SetUsingParentLevel(true)
		body:SetPoint("TOPLEFT", viewport, "TOPLEFT", outset, 0)
	end
	scroll:SetScrollChild(extent)
	local bar = GF.UI.BindMinimalScrollBar(scroll, GF.SETTINGS_SCROLLBAR_GAP, panel, true)
	bar:SetWidth(GF.SETTINGS_SCROLLBAR_WIDTH)
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", panel.HeadingBackground, "BOTTOMRIGHT",
		GF.ABOUT_STYLE.headingInset - GF.SETTINGS_SCROLLBAR_RIGHT_INSET,
		-GF.SETTINGS_SCROLLBAR_TOP_INSET)
	bar:SetPoint("BOTTOMRIGHT", panel.Interior, "BOTTOMRIGHT",
		GF.ABOUT_STYLE.frame.interiorRight - GF.SETTINGS_SCROLLBAR_RIGHT_INSET,
		GF.SETTINGS_SCROLLBAR_BOTTOM_INSET)
	view.viewport, view.scroll, view.body, view.bar, view.extent = viewport, scroll, body, bar, extent
	function view:RefreshEdgeFade()
		if not edgeFadeLength then return end
		local range = math.max(0, body:GetHeight() - scroll:GetHeight())
		local offset = math.max(0, math.min(range, scroll:GetVerticalScroll()))
		local topLength = math.min(edgeFadeLength, offset)
		local bottomLength = math.min(edgeFadeLength, range - offset)
		if self.fadeTopLength == topLength and self.fadeBottomLength == bottomLength then return end
		self.fadeTopLength, self.fadeBottomLength = topLength, bottomLength
		-- Native gradient indices 0/1 target top/bottom; zero horizontal
		-- lengths leave side edges crisp. Each end releases its final line.
		if topLength > 0 or bottomLength > 0 then
			viewport:SetAlphaGradient(0, CreateVector2D(0, topLength))
			viewport:SetAlphaGradient(1, CreateVector2D(0, bottomLength))
		else viewport:ClearAlphaGradient() end
	end
	if edgeFadeLength then
		scroll:HookScript("OnVerticalScroll", function(_, offset)
			body:SetPoint("TOPLEFT", viewport, "TOPLEFT", outset, offset)
			view:RefreshEdgeFade()
		end)
		scroll:HookScript("OnScrollRangeChanged", function() view:RefreshEdgeFade() end)
	end

	function view:LayoutAtInset(inset)
		self.inset = inset
		viewport:SetPoint("BOTTOMRIGHT", panel.Interior, "BOTTOMRIGHT",
			GF.ABOUT_STYLE.frame.interiorRight - horizontalInset - inset + outset, 0)
		if not self.layout then return end
		local width = panel:GetWidth() - horizontalInset * 2 - inset
		local height = self.layout(width)
		body:SetSize(width, height)
		if extent ~= body then extent:SetSize(width, height) end
		local range = math.max(0, height - scroll:GetHeight())
		if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
		GF.UI.UpdateScrollFrame(scroll)
		self:RefreshEdgeFade()
	end

	function view:Refresh(layout, reset)
		if self.refreshing then return end
		self.layout = layout or self.layout
		if not self.layout then return end
		self.refreshing = true
		self.fullWidth = panel:GetWidth() - horizontalInset * 2
		self.viewportHeight = viewport:GetHeight()
		-- Always decide at full width, so an old gutter cannot sustain itself.
		self.scrollable = self.layout(self.fullWidth) > self.viewportHeight
			+ GF.PLAYER_MANAGEMENT_STYLE.scrollBarOverflowEpsilon
		if reset then
			GF.UI.CancelSmoothWheelScrolling(scroll)
			scroll:SetVerticalScroll(0)
		end
		bar:SetScrollAllowed(self.scrollable)
		self:LayoutAtInset(self.inset)
		self.refreshing = false
		if self.dynamic then self.dynamic.Refresh() end
	end

	view:LayoutAtInset(0)
	view.dynamic = GF.UI.BindDynamicScrollBar(scroll, bar, {
		gutter = math.max(0, GF.SETTINGS_VISIBLE_CONTENT_INSET_R - horizontalInset),
		duration = GF.PLAYER_MANAGEMENT_STYLE.scrollBarDuration,
		isScrollable = function() return view.scrollable == true end,
		isScrollAllowed = function() return view.scrollable == true end,
		onInsetChanged = function(inset)
			view.refreshing = true
			view:LayoutAtInset(inset)
			view.refreshing = false
		end,
	})
	viewport:HookScript("OnSizeChanged", function()
		if view.fullWidth ~= panel:GetWidth() - horizontalInset * 2
			or view.viewportHeight ~= viewport:GetHeight() then view:Refresh() end
	end)
	scroll._gfWheelAllow = function() return view.scrollable == true end
	GF.UI.BindSmoothWheelScrolling(scroll)
	GF.UI.BindSmoothWheelScrollBar(scroll, bar)
	return view
end

local function measureAboutText(text)
	text:SetHeight(0)
	local height = math.ceil(text:GetStringHeight())
	text:SetHeight(height + 2)
	return height
end

local function refreshInformationLayout(f)
	if not f.infoRows then return end
	local style = GF.ABOUT_STYLE.info
	local rowInset = style.inset - style.scrollInset
	local width = f.infoBody:GetWidth() - rowInset * 2
	local y = 0
	for index, row in ipairs(f.infoRows) do
		row.infoTop = y
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", f.infoBody, "TOPLEFT", rowInset, -y)
		row:SetWidth(width)
		row.label:ClearAllPoints()
		row.value:ClearAllPoints()
		row.label:SetWidth(width)
		row.value:SetWidth(width)
		local height
		if row == f.authorRow then
			row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
			measureAboutText(row.label)
			local valueTop = row.label:GetHeight() + style.valueGap
			local contact = f.authorStatusFrame:IsShown()
			local valueWidth = math.min(width, math.ceil(row.value:GetUnboundedStringWidth()) + 2)
			local contactWidth = contact and (style.contactSize + style.contactInlineGap) or 0
			-- Keep the name on the card's center axis; reserve the same amount
			-- of room on both sides so the right-hand button stays inside the clip.
			local stacked = valueWidth + contactWidth * 2 > f.infoBody:GetWidth()
			row.value:SetWidth(valueWidth)
			local valueTextHeight = measureAboutText(row.value)
			local valueHeight = row.value:GetHeight()
			f.authorStatusFrame:ClearAllPoints()
			if stacked then
				row.value:SetPoint("TOP", row, "TOP", 0, -valueTop)
				f.authorStatusFrame:SetPoint("TOP", row.value, "BOTTOM", 0, -style.contactGap)
				height = valueTop + valueHeight + style.contactGap + style.contactSize
			else
				local lineHeight = math.max(valueHeight, contact and style.contactSize or 0)
				local left = (width - valueWidth) / 2
				row.value:SetPoint("TOPLEFT", row, "TOPLEFT", left,
					-valueTop - (lineHeight - valueHeight) / 2)
				-- The name is top-aligned; exclude its bottom safety padding
				-- when centering the contact artwork beside the visible text.
				local textCenterOffset = (valueHeight - valueTextHeight) / 2
				f.authorStatusFrame:SetPoint("LEFT", row.value, "RIGHT", style.contactInlineGap, textCenterOffset)
				height = valueTop + lineHeight
			end
		else
			-- Compact label/value pairs; long locales and large fonts can stack
			-- without shrinking text or squeezing the contact entry.
			local labelWidth = math.min(width, math.ceil(row.label:GetUnboundedStringWidth()) + 2)
			local valueWidth = math.min(width, math.ceil(row.value:GetUnboundedStringWidth()) + 2)
			local inline = labelWidth + style.columnGap + valueWidth <= width
			row.label:SetWidth(inline and labelWidth or width)
			row.value:SetWidth(inline and valueWidth or width)
			row.value:SetJustifyH(inline and "RIGHT" or "LEFT")
			measureAboutText(row.label)
			measureAboutText(row.value)
			local labelHeight, valueHeight = row.label:GetHeight(), row.value:GetHeight()
			if inline then
				height = math.max(style.rowHeight, labelHeight, valueHeight)
				row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(height - labelHeight) / 2)
				row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -(height - valueHeight) / 2)
			else
				row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
				row.value:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -style.valueGap)
				height = labelHeight + style.valueGap + valueHeight
			end
		end
		row:SetHeight(height)
		y = y + height
		if index < #f.infoRows then
			y = y + (row == f.authorRow and style.authorGap or style.rowGap)
		end
	end
	-- Center the complete information group in the available body. Overflow
	-- starts at the top so enlarged text stays reachable by normal scrolling.
	local viewportHeight = f.infoScroll:GetHeight()
	local topPad = math.max(0, (viewportHeight - y) / 2)
	for _, row in ipairs(f.infoRows) do
		row:SetPoint("TOPLEFT", f.infoBody, "TOPLEFT", rowInset, -topPad - row.infoTop)
	end
	-- The empty bottom half of the centering space is not scroll content.
	-- Ending at the final row also avoids a viewport-sized child rounding up.
	local contentHeight = math.max(1, y + topPad)
	f.infoBody:SetHeight(contentHeight)
	local scrollable = y > viewportHeight + GF.PLAYER_MANAGEMENT_STYLE.scrollBarOverflowEpsilon
	f.infoScroll._gfInfoScrollable = scrollable
	local range = scrollable and math.max(0, contentHeight - viewportHeight) or 0
	if not scrollable then GF.UI.CancelSmoothWheelScrolling(f.infoScroll) end
	if f.infoScroll:GetVerticalScroll() > range then f.infoScroll:SetVerticalScroll(range) end
	f.infoScrollBar:SetScrollAllowed(scrollable)
	GF.UI.UpdateScrollFrame(f.infoScroll)
	f.infoScrollBar:SetShown(scrollable)
end

local function createAboutInformation(f)
	local style = GF.ABOUT_STYLE
	-- Center the card grid inside the frame's asymmetric visible body.
	local centerOffsetX = (LAYOUT.BODY_BG_INSET_LEFT + LAYOUT.BODY_BG_INSET_RIGHT) / 2
	f.aboutBody = CreateFrame("Frame", nil, f.content)
	f.aboutBody:SetPoint("TOPLEFT", f.content, "TOPLEFT", centerOffsetX, -style.top + style.header.heightReduction)
	f.aboutBody:SetSize(style.width, style.height)
	f.aboutBody:SetFrameLevel(f.content:GetFrameLevel() + 4)
	f.aboutPanels = {}
	f.infoBox = createAboutCard(f, 0, 0, style.leftWidth, style.infoHeight)
	createAboutHeading(f.infoBox)
	local infoStyle = style.info
	-- The clip extends into the text padding to fit the author's side button.
	f.infoScroll, f.infoBody, f.infoScrollBar = createAboutScroll(f.infoBox,
		infoStyle.scrollInset, infoStyle.scrollInset, infoStyle.top, infoStyle.bottom)
	f.infoRows = {}
	for _, name in ipairs({ "authorRow", "feedbackRow", "homepageRow", "commandRow" }) do
		local row = CreateFrame("Frame", nil, f.infoBody)
		row:SetSize(style.leftWidth - infoStyle.inset * 2, infoStyle.rowHeight)
		row.label = createText(row, "GameFontHighlight", infoStyle.labelSize, infoStyle.labelColor, "")
		row.value = createText(row, "GameFontHighlight",
			name == "commandRow" and infoStyle.commandSize
				or name == "authorRow" and infoStyle.authorSize
				or name == "homepageRow" and infoStyle.websiteSize or infoStyle.valueSize,
			name == "authorRow" and infoStyle.valueColor or infoStyle.linkColor, "")
		for _, text in ipairs({ row.label, row.value }) do
			text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetWordWrap(true); text:SetSpacing(2)
		end
		if name == "authorRow" then
			row.label:SetJustifyH("CENTER")
			row.value:SetJustifyH("CENTER")
		end
		f[name] = row
		f.infoRows[#f.infoRows + 1] = row
	end
	f.commandTitle, f.command = f.commandRow.label, f.commandRow.value
	f.authorLabel, f.authorText = f.authorRow.label, f.authorRow.value
	f.feedbackLabel, f.feedbackText = f.feedbackRow.label, f.feedbackRow.value
	f.homepageLabel, f.homepageText = f.homepageRow.label, f.homepageRow.value
	f.infoScroll:HookScript("OnShow", function() refreshInformationLayout(f) end)
end

local function createAboutNotices(f)
	local style = GF.ABOUT_STYLE
	f.announcementBox = createAboutCard(f, style.leftWidth + style.gap, 0, style.rightWidth, style.announcementHeight)
	createAboutHeading(f.announcementBox)
	f.announcementView = AboutCard.CreateScroll(f.announcementBox, style.announcementInset, style.scrollEdgeFade)
	f.announcementScroll, f.announcementBody, f.announcementScrollBar =
		f.announcementView.scroll, f.announcementView.body, f.announcementView.bar
	f.announcementRows = {}
	f.noticeBox = createAboutCard(f, style.leftWidth + style.gap, style.announcementHeight + style.gap, style.rightWidth, style.logHeight)
	createAboutHeading(f.noticeBox)
	f.noticeView = AboutCard.CreateScroll(f.noticeBox, style.logInset, style.scrollEdgeFade,
		style.versionHeader.backgroundOutset)
	f.noticeScroll, f.noticeBody, f.noticeScrollBar = f.noticeView.scroll, f.noticeView.body, f.noticeView.bar
end

local function refreshAnnouncement(f)
	local body, rows = f.announcementBody, f.announcementRows
	local function layout(width)
		body:SetWidth(width)
		local style = GF.ABOUT_STYLE
		local edgePad, paragraphGap = style.contentEdgePad, style.announcementParagraphGap
		local y, index = 0, 0
		for _, paragraph in ipairs((GF.L or {}).USAGE_DETAIL_ANNOUNCEMENT_LINES or {}) do
			local parts = {}
			if type(paragraph) == "table" then
				for _, span in ipairs(paragraph) do
					local value = type(span) == "table" and span.text or span
					if type(value) == "string" then
						parts[#parts + 1] = type(span) == "table" and span.emphasis
							and (NOTICE_CATEGORY_PREFIX_COLOR_CODE .. value .. NOTICE_COLOR_RESET_CODE) or value
					end
				end
			else parts[1] = paragraph end
			for text in table.concat(parts):gmatch("[^\n]+") do
				index = index + 1
				local row = rows[index]
				if not row then
					row = createText(body, "GameFontHighlight", STYLE.FONT_NOTICE_TEXT, STYLE.BODY_TEXT, "")
					rows[index] = row
				else
					setFont(row, "GameFontHighlight", STYLE.FONT_NOTICE_TEXT, "")
				end
				row.announcementTop = y
				row:SetWidth(width); row:SetJustifyH("LEFT"); row:SetJustifyV("TOP")
				row:SetWordWrap(true); row:SetSpacing(LAYOUT.NOTICE_BODY_LINE_SPACING)
				row:SetText(GF.ABOUT_STYLE.announcementFirstLineIndent .. text); row:Show()
				y = y + measureAboutText(row) + paragraphGap
			end
		end
		for i = index + 1, #rows do rows[i]:Hide() end
		local height = index > 0 and y - paragraphGap + edgePad * 2 or 1
		-- Keep natural line spacing: center the complete short announcement,
		-- and return to the normal scrolling padding as soon as it overflows.
		local extraPad = index > 0 and math.max(0,
			(f.announcementView.viewport:GetHeight() - height) / 2) or 0
		for i = 1, index do
			local row = rows[i]
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(row.announcementTop + edgePad + extraPad))
		end
		height = height + extraPad * 2
		body:SetHeight(height)
		return height
	end
	f.announcementView:Refresh(layout, true)
end

local function hideNoticeVersionDecor(row)
	if row.versionHeader then
		row.versionHeader:Hide()
	end
	if row.sectionTitleBackground then
		row.sectionTitleBackground:Hide()
	end
end

local function hideNoticeRichParts(row)
	if not row or not row.richParts then
		return
	end
	for _, part in ipairs(row.richParts) do
		part:Hide()
	end
end

local function clearNoticeRows(f)
	if not f.noticeRows then
		f.noticeRows = {}
		return
	end
	for _, row in ipairs(f.noticeRows) do
		if row then
			if row.Hide then
				row:Hide()
			else
				hideNoticeVersionDecor(row)
				hideNoticeRichParts(row)
				if row.text then
					row.text:Hide()
				end
				if row.bullet then
					row.bullet:Hide()
				end
				if row.body then
					row.body:Hide()
				end
				if row.category then
					row.category:Hide()
				end
			end
		end
	end
end

local function ensureNoticeRow(f, index)
	f.noticeRows = f.noticeRows or {}
	local row = f.noticeRows[index]
	if row and row.Hide then
		row = { text = row }
		f.noticeRows[index] = row
	elseif type(row) ~= "table" then
		row = {}
		f.noticeRows[index] = row
	end
	return row
end

local function acquireNoticeText(f, index, template, size, color, flags)
	local row = ensureNoticeRow(f, index)
	hideNoticeVersionDecor(row)
	hideNoticeRichParts(row)
	if row.bullet then
		row.bullet:Hide()
	end
	if row.body then
		row.body:Hide()
	end
	if row.category then
		row.category:Hide()
	end
	local fs = row.text
	if not fs then
		fs = createText(f.noticeBody, template, size, color, flags)
		row.text = fs
	else
		fs:SetParent(f.noticeBody)
		setFont(fs, template or "GameFontHighlight", size or 12, flags or "")
		colorText(fs, color or STYLE.BODY_TEXT)
	end
	fs:ClearAllPoints()
	fs:SetWidth(f.noticeTextWidth or LAYOUT.NOTICE_TEXT_W)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetSpacing(0)
	fs:SetWordWrap(true)
	fs:Show()
	return fs
end

local function acquireNoticeBulletText(f, index, template, size, color, flags)
	local row = ensureNoticeRow(f, index)
	hideNoticeVersionDecor(row)
	hideNoticeRichParts(row)
	if row.category then
		row.category:Hide()
	end
	if row.text then
		row.text:Hide()
	end
	if not row.bullet then
		row.bullet = f.noticeBody:CreateTexture(nil, "ARTWORK")
	else
		row.bullet:SetParent(f.noticeBody)
	end
	row.bullet:SetAtlas(
		LAYOUT.NOTICE_BULLET_ATLAS,
		TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
	row.bullet:SetSize(
		LAYOUT.NOTICE_BULLET_SIZE,
		LAYOUT.NOTICE_BULLET_SIZE)
	if not row.body then
		row.body = createText(f.noticeBody, template, size, color, flags)
	else
		row.body:SetParent(f.noticeBody)
		setFont(row.body, template or "GameFontHighlight", size or 12, flags or "")
		colorText(row.body, color or STYLE.BODY_TEXT)
	end
	row.bullet:ClearAllPoints()
	row.bullet:Show()
	row.body:ClearAllPoints()
	row.body:SetJustifyH("LEFT")
	row.body:SetJustifyV("TOP")
	row.body:SetSpacing(LAYOUT.NOTICE_BODY_LINE_SPACING)
	row.body:SetWordWrap(true)
	row.body:Show()
	return row.bullet, row.body
end

local function addNoticeLine(f, index, y, text, template, size, color, flags, gap, justify)
	local fs = acquireNoticeText(f, index, template, size, color, flags)
	fs:SetText(text or "")
	fs:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", 0, y)
	fs:SetJustifyH(justify or "LEFT")
	local height = fs.GetStringHeight and fs:GetStringHeight() or 0
	if type(height) ~= "number" or height <= 0 then
		height = size or STYLE.FONT_NOTICE_TEXT
	end
	height = math.ceil(height)
	fs:SetHeight(height + 2)
	return index + 1, y - height - (gap or LAYOUT.NOTICE_LINE_GAP)
end

-- The native quest header has fading ends and two gold rules. Keep its end
-- caps proportional to the bar height, stretching only the middle horizontally.
local function createNoticeVersionSurface(header)
	local style = GF.ABOUT_STYLE.versionHeader
	local interior = CreateFrame("Frame", nil, header)
	interior:EnableMouse(false)
	interior:SetPoint("TOPLEFT", header, "TOPLEFT", style.interiorLeft, -style.interiorTop)
	interior:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -style.interiorRight, style.interiorBottom)
	header.Interior = interior
	local info = GF.UI.GetNativeAtlasInfo(style.atlas)
	if not info then return end
	local cap = style.sourceCap / style.sourceWidth
	for _, piece in ipairs({ { "Left", 0, cap }, { "Center", cap, 1 - cap }, { "Right", 1 - cap, 1 } }) do
		local texture = header:CreateTexture(nil, "BACKGROUND", nil, 0)
		GF.UI.SetNativeAtlasPieceRegion(texture, info, piece[2], piece[3],
			0, 1 - style.cropBottom / style.sourceHeight, true, false)
		GF.UI.SetNativeAtlasSampling(texture, false)
		texture:ClearTextureSlice()
		header[piece[1]] = texture
	end
	header.Left:SetPoint("TOPLEFT", header, "TOPLEFT", -style.backgroundOutset, 0)
	header.Left:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", -style.backgroundOutset, 0)
	header.Right:SetPoint("TOPRIGHT", header, "TOPRIGHT", style.backgroundOutset, 0)
	header.Right:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", style.backgroundOutset, 0)
	header.Center:SetPoint("TOPLEFT", header.Left, "TOPRIGHT", 0, 0)
	header.Center:SetPoint("BOTTOMRIGHT", header.Right, "BOTTOMLEFT", 0, 0)
end

local function addNoticeVersionLine(f, index, y, text)
	local fs = acquireNoticeText(
		f,
		index,
		"GameFontNormalLarge",
		STYLE.FONT_NOTICE_VERSION,
		STYLE.MAIN_GOLD,
		"OUTLINE")
	local row = ensureNoticeRow(f, index)
	local style = GF.ABOUT_STYLE.versionHeader
	if not row.versionHeader then
		local header = CreateFrame("Frame", nil, f.noticeBody)
		header:EnableMouse(false)
		header:SetUsingParentLevel(true)
		createNoticeVersionSurface(header)
		row.versionHeader = header
	end
	local header = row.versionHeader
	header:SetParent(f.noticeBody)
	header:ClearAllPoints()
	header:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", 0, y)
	header:SetPoint("TOPRIGHT", f.noticeBody, "TOPRIGHT", 0, y)
	fs:SetParent(header)
	fs:SetText(text or "")
	fs:SetWordWrap(false)
	local releaseDate = GF.CHANGELOG_RELEASE_DATES[text]
	local dateWidth, dateHeight = 0, 0
	if releaseDate then
		if not header.Date then
			header.Date = createText(header, "GameFontHighlight", style.dateSize, style.dateColor, "")
		end
		local date = header.Date
		setFont(date, "GameFontHighlight", style.dateSize, "")
		colorText(date, style.dateColor)
		date:SetText(releaseDate)
		date:SetWordWrap(false)
		date:SetSpacing(0)
		date:SetSize(0, 0)
		dateWidth = math.ceil(date:GetStringWidth())
		date:SetWidth(dateWidth)
		local _, dateFontHeight = date:GetFont()
		dateHeight = math.ceil(math.max(date:GetStringHeight(), dateFontHeight))
		date:SetHeight(dateHeight)
		date:ClearAllPoints()
		date:SetPoint("RIGHT", header.Interior, "RIGHT",
			style.interiorRight - style.dateInsetRight, 0)
		date:SetJustifyH("RIGHT")
		date:SetJustifyV("MIDDLE")
		date:Show()
	elseif header.Date then
		header.Date:SetText("")
		header.Date:Hide()
	end
	fs:SetWidth(
		math.max(1, (f.noticeTextWidth or LAYOUT.NOTICE_TEXT_W)
			- dateWidth - (releaseDate and (style.dateGap + style.dateInsetRight) or 0)))
	fs:SetHeight(0)
	local _, fontHeight = fs:GetFont()
	local textHeight = math.ceil(math.max(fs:GetStringHeight(), fontHeight))
	local rowHeight = math.max(LAYOUT.NOTICE_VERSION_ROW_H,
		math.ceil(math.max(textHeight, dateHeight) + style.textPadding * 2
			+ style.interiorTop + style.interiorBottom))
	header:SetHeight(rowHeight)
	if header.Left then
		local capWidth = style.sourceCap * rowHeight / style.sourceHeight
		header.Left:SetWidth(capWidth)
		header.Right:SetWidth(capWidth)
		-- Match the cropped UV height in geometry; do not stretch the remaining
		-- artwork or move the primary gold rules and centered labels.
		local croppedHeight = style.cropBottom * rowHeight / style.sourceHeight
		header.Left:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", -style.backgroundOutset, croppedHeight)
		header.Right:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", style.backgroundOutset, croppedHeight)
	end
	-- Center measured text on the visible interior, excluding the atlas padding.
	fs:SetPoint("LEFT", header.Interior, "LEFT",
		-style.interiorLeft, 0)
	fs:SetHeight(textHeight)
	fs:SetJustifyV("MIDDLE")
	header:Show()
	return index + 1, y - rowHeight - LAYOUT.NOTICE_VERSION_GAP
end

local function addNoticeBulletLine(f, index, y, line, template, size, color, flags, gap)
	local bullet, bodyText =
		acquireNoticeBulletText(f, index, template, size, color, flags)
	local _, prefix, body = parseNoticeBodyLine(line)
	bodyText:SetText(body or line or "")
	local bodyX = LAYOUT.NOTICE_BULLET_SIZE + LAYOUT.NOTICE_BULLET_GAP
	local _, fontHeight = bodyText:GetFont()
	fontHeight = tonumber(fontHeight) or size or STYLE.FONT_NOTICE_TEXT
	local category, categoryH
	if prefix then
		local row = ensureNoticeRow(f, index)
		if not row.category then
			row.category = createText(f.noticeBody, template, size, STYLE.MAIN_GOLD, flags)
		end
		category = row.category
		category:SetParent(f.noticeBody)
		setFont(category, template or "GameFontHighlight", size or 12, flags or "")
		category:ClearAllPoints()
		category:SetWordWrap(false)
		category:SetJustifyH("LEFT")
		category:SetJustifyV("MIDDLE")
		category:SetSpacing(0)
		category:SetSize(0, 0)
		-- Colons delimit stored entries; spacing separates the visible columns.
		local label = prefix:gsub("：$", ""):gsub(":$", "")
		category:SetText(label)
		local categoryW = math.ceil(category:GetStringWidth())
		category:SetWidth(categoryW)
		categoryH = math.ceil(math.max(fontHeight, category:GetStringHeight()))
		category:SetHeight(categoryH)
		category:Show()
		bodyX = bodyX + categoryW + LAYOUT.NOTICE_LABEL_GAP
	end
	bodyText:SetWidth(math.max((f.noticeTextWidth or LAYOUT.NOTICE_TEXT_W) - bodyX, 1))
	bodyText:SetHeight(0)
	local bodyH = bodyText.GetStringHeight and bodyText:GetStringHeight() or 0
	if type(bodyH) ~= "number" or bodyH <= 0 then
		bodyH = fontHeight
	end
	bodyH = math.ceil(bodyH)
	local height = math.max(LAYOUT.NOTICE_BULLET_SIZE, categoryH or 0, bodyH)
	-- Keep wrapped lines in their own column; center the complete label group
	-- against the measured paragraph rather than its first line.
	bodyText:SetHeight(bodyH)
	bodyText:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", bodyX, y - (height - bodyH) / 2)
	if category then
		category:SetPoint("RIGHT", bodyText, "LEFT", -LAYOUT.NOTICE_LABEL_GAP, 0)
	end
	bullet:SetPoint("RIGHT", category or bodyText, "LEFT", -LAYOUT.NOTICE_BULLET_GAP, 0)
	return index + 1, y - height - (gap or LAYOUT.NOTICE_ITEM_GAP)
end

local function refreshNoticeContent(f)
	local L = GF.L or {}
	local entries = L.USAGE_DETAIL_NOTICE_ENTRIES
	if type(entries) ~= "table" or #entries == 0 then
		clearNoticeRows(f)
		f.noticeView:Refresh(function(width)
			f.noticeBody:SetSize(width, 1)
			return 1
		end, true)
		f.noticeScroll:Hide()
		f.noticeEmpty:SetText(L.USAGE_DETAIL_NOTICE_EMPTY or "No notices")
		f.noticeEmpty:Show()
		return
	end

	f.noticeEmpty:Hide()
	f.noticeScroll:Show()
	f.noticeView:Refresh(function(width)
		f.noticeTextWidth = width
		clearNoticeRows(f)
		local rowIndex = 1
		local y = -GF.ABOUT_STYLE.contentEdgePad
		local trailingGap = 0

		for entryIndex, entry in ipairs(entries) do
			if type(entry) == "table" then
				local version = entry.version or ""
				if version ~= "" then
					rowIndex, y =
						addNoticeVersionLine(f, rowIndex, y, version)
					trailingGap = LAYOUT.NOTICE_VERSION_GAP
				end
				local lines = entry.lines
				if type(lines) == "table" then
					for lineIndex, line in ipairs(lines) do
						local isFinalLine = entryIndex == #entries
							and lineIndex == #lines
						rowIndex, y = addNoticeBulletLine(
							f,
							rowIndex,
							y,
							line,
							"GameFontHighlight",
							STYLE.FONT_NOTICE_TEXT,
							STYLE.BODY_TEXT,
							"",
							isFinalLine and 0 or LAYOUT.NOTICE_ITEM_GAP
						)
						trailingGap = isFinalLine and 0 or LAYOUT.NOTICE_ITEM_GAP
					end
				end
				if entryIndex < #entries then
					y = y - LAYOUT.NOTICE_ENTRY_GAP
					trailingGap = trailingGap + LAYOUT.NOTICE_ENTRY_GAP
				end
			end
		end

		local height = math.max(1, math.ceil(-y - trailingGap + GF.ABOUT_STYLE.contentEdgePad))
		f.noticeBody:SetSize(width, height)
		return height
	end, true)
end

function UGD:IsReadableAuthorValue(value)
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret then
			return false
		end
	end
	return value ~= nil
end

function UGD:IsChinaRegion()
	if type(GetCurrentRegionName) == "function" then
		local ok, regionName = pcall(GetCurrentRegionName)
		if ok and self:IsReadableAuthorValue(regionName)
			and type(regionName) == "string"
			and regionName ~= ""
		then
			return regionName:upper() == "CN"
		end
	end
	if type(GetCurrentRegion) == "function" then
		local ok, regionID = pcall(GetCurrentRegion)
		return ok and regionID == 5
	end
	return false
end

function UGD:NormalizeAuthorRealm(realm)
	if not self:IsReadableAuthorValue(realm) or type(realm) ~= "string" then
		return nil
	end
	return realm:gsub("%s+", "")
end

function UGD:IsAuthorCharacter(characterName, realmName)
	if not self:IsReadableAuthorValue(characterName)
		or type(characterName) ~= "string"
	then
		return false
	end
	local character, embeddedRealm = characterName:match("^(.+)%-(.+)$")
	if character then
		characterName = character
		realmName = embeddedRealm
	end
	if characterName ~= self.AUTHOR_CHARACTER then
		return false
	end
	if realmName == nil then
		local getRealm = GetNormalizedRealmName or GetRealmName
		if type(getRealm) == "function" then
			local ok, currentRealm = pcall(getRealm)
			if ok then
				realmName = currentRealm
			end
		end
	end
	return self:NormalizeAuthorRealm(realmName)
		== self:NormalizeAuthorRealm(self.AUTHOR_REALM)
end

function UGD:IsCurrentCharacterAuthor()
	if type(UnitFullName) == "function" then
		local ok, characterName, realmName = pcall(UnitFullName, "player")
		if ok and self:IsAuthorCharacter(characterName, realmName) then
			return true
		end
	end
	if type(GetUnitName) == "function" then
		local ok, fullName = pcall(GetUnitName, "player", true)
		if ok and self:IsAuthorCharacter(fullName) then
			return true
		end
	end
	return false
end

function UGD:GetAuthorCharacterFriendPresence()
	local friendList = C_FriendList
	if type(friendList) ~= "table" then
		return "unknown"
	end
	local function classify(info)
		if not UGD:IsReadableAuthorValue(info) or type(info) ~= "table"
			or not UGD:IsAuthorCharacter(info.name)
		then
			return nil
		end
		if not UGD:IsReadableAuthorValue(info.connected)
			or type(info.connected) ~= "boolean"
		then
			return "unknown"
		end
		return info.connected == true and "online" or "offline"
	end
	if type(friendList.GetFriendInfo) == "function" then
		local ok, info = pcall(
			friendList.GetFriendInfo, self.AUTHOR_WHISPER_TARGET)
		local status = ok and classify(info) or nil
		if status then
			return status, true
		end
	end
	if type(friendList.GetNumFriends) ~= "function"
		or type(friendList.GetFriendInfoByIndex) ~= "function"
	then
		return "unknown"
	end
	local countOK, count = pcall(friendList.GetNumFriends)
	if not countOK or not self:IsReadableAuthorValue(count)
		or type(count) ~= "number" or count < 0 or count % 1 ~= 0
	then
		return "unknown"
	end
	local complete = count > 0 or self._authorFriendListReady == true
	for index = 1, count do
		local infoOK, info = pcall(friendList.GetFriendInfoByIndex, index)
		local status = infoOK and classify(info) or nil
		if status then
			return status, true
		end
		if not infoOK or not self:IsReadableAuthorValue(info)
			or type(info) ~= "table" or not self:IsReadableAuthorValue(info.name)
			or type(info.name) ~= "string" or info.name == ""
		then
			complete = false
		end
	end
	if complete then
		return "unknown", false
	end
	return "unknown", nil
end

function UGD:GetAuthorBattleNetPresence()
	if type(BNGetNumFriends) ~= "function"
		or type(C_BattleNet) ~= "table"
		or type(C_BattleNet.GetFriendNumGameAccounts) ~= "function"
		or type(C_BattleNet.GetFriendGameAccountInfo) ~= "function"
	then
		return "unknown", false
	end
	local countOK, friendCount = pcall(BNGetNumFriends)
	if not countOK or not self:IsReadableAuthorValue(friendCount)
		or type(friendCount) ~= "number" or friendCount < 0 or friendCount % 1 ~= 0
	then
		return "unknown"
	end
	local matchedFriend, matchedOffline, complete = false, false, true
	for friendIndex = 1, friendCount do
		local accountsOK, accountCount = pcall(
			C_BattleNet.GetFriendNumGameAccounts, friendIndex)
		if accountsOK and self:IsReadableAuthorValue(accountCount)
			and type(accountCount) == "number" and accountCount >= 0
			and accountCount % 1 == 0
		then
			for accountIndex = 1, accountCount do
				local infoOK, info = pcall(
					C_BattleNet.GetFriendGameAccountInfo,
					friendIndex,
					accountIndex)
				if infoOK and self:IsReadableAuthorValue(info) and type(info) == "table" then
					local currentProject = type(info.wowProjectID) == "nil"
						or (self:IsReadableAuthorValue(info.wowProjectID)
							and info.wowProjectID == WOW_PROJECT_MAINLINE)
					local currentRegion = type(info.isInCurrentRegion) == "nil"
						or (self:IsReadableAuthorValue(info.isInCurrentRegion)
							and info.isInCurrentRegion == true)
					for _, field in ipairs({ "wowProjectID", "isInCurrentRegion", "characterName", "realmName" }) do
						if type(info[field]) ~= "nil" and not self:IsReadableAuthorValue(info[field]) then
							complete = false
						end
					end
					if currentProject
						and currentRegion
						and self:IsAuthorCharacter(
							info.characterName, info.realmName)
					then
						matchedFriend = true
						if self:IsReadableAuthorValue(info.isOnline) then
							if info.isOnline == true then
								return "online", true
							end
							matchedOffline = matchedOffline or info.isOnline == false
						end
					end
				else
					complete = false
				end
			end
		else
			complete = false
		end
	end
	if matchedFriend then
		return matchedOffline and "offline" or "unknown", true
	end
	if complete then
		return "unknown", false
	end
	return "unknown", nil
end

function UGD:GetAuthorPresence()
	if not self:IsChinaRegion() then
		return "unknown"
	end
	if self:IsCurrentCharacterAuthor() then
		return "online", true
	end
	local characterStatus, characterFriend = self:GetAuthorCharacterFriendPresence()
	local battleNetStatus, battleNetFriend = self:GetAuthorBattleNetPresence()
	if characterStatus == "online" or battleNetStatus == "online" then
		return "online", true
	end
	if characterStatus == "offline" or battleNetStatus == "offline" then
		return "offline", true
	end
	if characterFriend == true or battleNetFriend == true then
		return "unknown", true
	end
	if characterFriend == false and battleNetFriend == false then
		return "unknown", false
	end
	return "unknown"
end

function UGD:RequestAuthorFriendList()
	if self:IsChinaRegion() and C_FriendList
		and type(C_FriendList.ShowFriends) == "function"
	then
		pcall(C_FriendList.ShowFriends)
	end
end

function UGD:GetAuthorContactHint(isFriend)
	local L = GF.L or {}
	if isFriend == false then
		return L.USAGE_DETAIL_AUTHOR_ADD_FRIEND_HINT
			or "Presence is unavailable for non-friends. Click to add the author as a friend and chat when online."
	elseif isFriend == true then
		return L.USAGE_DETAIL_AUTHOR_WHISPER_HINT or "Click the button to whisper to the author."
	end
	return L.USAGE_DETAIL_AUTHOR_CONTACT_UNAVAILABLE or "Friend information is unavailable. Please try again later."
end

local function resetAuthorTooltipPresentation(tooltip)
	local presentation = tooltip._gfAuthorContactPresentation
	if not (presentation and presentation.active) then return end
	presentation.active = false
	presentation.background:Hide()
	tooltip:SetCustomLineSpacing(0)
	tooltip:ClearPadding()
end

local function applyAuthorTooltipPresentation(tooltip)
	local style = GF.ABOUT_STYLE.author.tooltip
	local presentation = tooltip._gfAuthorContactPresentation
	if not presentation then
		presentation = { background = tooltip:CreateTexture(nil, "BACKGROUND", nil, -8) }
		tooltip._gfAuthorContactPresentation = presentation
		-- GameTooltip is shared. Clear only this contact view's presentation
		-- before another owner fills it, and reuse the backing on later hovers.
		tooltip:HookScript("OnTooltipCleared", resetAuthorTooltipPresentation)
		tooltip:HookScript("OnHide", resetAuthorTooltipPresentation)
	end
	presentation.active = true
	local background = presentation.background
	background:ClearAllPoints()
	background:SetPoint("TOPLEFT", tooltip, "TOPLEFT", style.backgroundInset, -style.backgroundInset)
	background:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -style.backgroundInset, style.backgroundInset)
	background:SetColorTexture(unpack(style.backgroundColor))
	background:Show()
	tooltip:SetCustomLineSpacing(style.lineSpacing)
	tooltip:SetPadding(style.padding, style.padding, style.padding, style.padding)
end

function UGD:ShowAuthorTooltip(button, status, isFriend)
	local tooltip = GameTooltip
	if not (tooltip and button) then return end
	local L = GF.L or {}
	local style = GF.ABOUT_STYLE.author.tooltip
	local statusKey = status == "online" and "USAGE_DETAIL_AUTHOR_STATUS_ONLINE"
		or status == "offline" and "USAGE_DETAIL_AUTHOR_STATUS_OFFLINE"
		or "USAGE_DETAIL_AUTHOR_STATUS_UNKNOWN"
	local statusColor = status == "online" and GREEN_FONT_COLOR or GRAY_FONT_COLOR
	local statusR, statusG, statusB = statusColor:GetRGB()
	local nameColor = GF.ABOUT_STYLE.info.valueColor
	GF.UI.BeginGameTooltip(button, "ANCHOR_RIGHT")
	tooltip:SetText(L.USAGE_DETAIL_AUTHOR_CONTACT_TITLE or "Contact author", 1, 0.82, 0)
	tooltip:AddDoubleLine(self.AUTHOR_WHISPER_TARGET, L[statusKey] or status or "unknown",
		nameColor[1], nameColor[2], nameColor[3], statusR, statusG, statusB)
	tooltip:AddLine(self:GetAuthorContactHint(isFriend),
		style.hintColor[1], style.hintColor[2], style.hintColor[3], true)
	-- Three real rows; spacing and padding own the gaps, not empty text rows.
	applyAuthorTooltipPresentation(tooltip)
	GF.UI.ShowGameTooltip(tooltip)
end

function UGD:ContactAuthor()
	if not self:IsChinaRegion() then
		return false
	end
	-- Recheck at click time; an unknown presence alone never authorizes adding a friend.
	local _, isFriend = self:GetAuthorPresence()
	if isFriend == true then
		return self:OpenAuthorWhisper()
	end
	local friendList = C_FriendList
	local available = isFriend == false and type(friendList) == "table"
		and type(friendList.AddFriend) == "function"
	if available and type(friendList.IsLegacyFriendSystemEnabled) == "function" then
		local ok, enabled = pcall(friendList.IsLegacyFriendSystemEnabled)
		available = ok and self:IsReadableAuthorValue(enabled) and enabled == true
	end
	if available then
		local now = GetTime()
		if self._authorAddFriendRequestedAt and now - self._authorAddFriendRequestedAt < 3 then
			return false
		end
		self._authorAddFriendRequestedAt = now
		-- No success return: the server owns realm/faction eligibility and native feedback.
		if pcall(friendList.AddFriend, self.AUTHOR_WHISPER_TARGET) then
			return true
		end
	end
	local message = (GF.L or {}).USAGE_DETAIL_AUTHOR_CONTACT_UNAVAILABLE
		or "Friend information is unavailable. Please try again later."
	if UIErrorsFrame and type(UIErrorsFrame.AddExternalErrorMessage) == "function" then
		UIErrorsFrame:AddExternalErrorMessage(message)
	end
	if isFriend == nil then
		self:RequestAuthorFriendList()
	end
	return false
end

function UGD:RefreshAuthorContact(f)
	if not (f and f.authorText and f.authorContactButton
		and f.authorStatusFrame and f.authorStatusTransition) then return end
	local L = GF.L or {}
	local isChina = self:IsChinaRegion()
	f.authorText:SetText(isChina and self.AUTHOR_WHISPER_TARGET
		or L.USAGE_DETAIL_AUTHOR_TEXT or self.AUTHOR_WHISPER_TARGET)
	f.authorText:SetWidth(GF.ABOUT_STYLE.leftWidth - GF.ABOUT_STYLE.info.inset * 2)
	colorText(f.authorText, GF.ABOUT_STYLE.info.valueColor)
	f.authorStatusFrame:SetShown(isChina)
	f.authorContactButton:SetShown(isChina)
	if not isChina then
		f.authorStatus, f.authorIsFriend = "unknown", nil
		refreshInformationLayout(f)
		return
	end
	local status, isFriend = self:GetAuthorPresence()
	f.authorStatus, f.authorIsFriend = status, isFriend
	local style = GF.STARRED_LEADERS_STYLE
	local atlas = status == "online" and style.whisperAtlas
		or status == "offline" and style.whisperDisabledAtlas or style.statusAtlases.unknown
	local authorStyle = GF.ABOUT_STYLE.author
	local isAddFriend = atlas == style.statusAtlases.unknown
	local iconSize = isAddFriend and authorStyle.addFriendIconSize or authorStyle.whisperIconSize
	f.authorPressOptions.pressedScale = isAddFriend
		and authorStyle.addFriendPressedScale or authorStyle.whisperPressedScale
	f.authorPressFeedback:SetBaseSize(iconSize, iconSize)
	f.authorStatusTransition:Set(atlas, 1)
	f.authorVisualState = status
	refreshInformationLayout(f)
end

local function createAuthorContactVisual(f)
	local style = GF.STARRED_LEADERS_STYLE
	f.authorStatusFrame = CreateFrame("Frame", nil, f.authorRow)
	f.authorStatusFrame:SetSize(GF.ABOUT_STYLE.info.contactSize, GF.ABOUT_STYLE.info.contactSize)
	f.authorStatusFrame:EnableMouse(false)
	f.authorContactButton = CreateFrame("Button", nil, f.authorStatusFrame)
	f.authorContactButton:SetAllPoints(f.authorStatusFrame)
	f.authorStatusIcon = f.authorContactButton:CreateTexture(nil, "OVERLAY", nil, 2)
	f.authorStatusIcon:SetPoint("CENTER", f.authorStatusFrame, "CENTER", 0, 0)
	f.authorStatusIcon:SetSize(GF.ABOUT_STYLE.author.whisperIconSize, GF.ABOUT_STYLE.author.whisperIconSize)
	f.authorStatusIcon:SetDesaturated(false)
	f.authorStatusIcon:SetVertexColor(1, 1, 1, 1)
	-- Reuse the starred cross-fade and rebound timing with author-specific compression.
	-- Visual offline state remains clickable so every contact attempt responds.
	f.authorStatusTransition = GF.UI.CreateAtlasTransition(f.authorStatusIcon,
		style.whisperTransitionDuration, style.whisperAtlas, style.whisperBlendOverlap)
	f.authorPressOptions = {
		pressedScale = GF.ABOUT_STYLE.author.whisperPressedScale,
		releaseDuration = style.actionPressMotion.releaseDuration,
	}
	f.authorPressFeedback = GF.UI.BindIconPressFeedback(f.authorContactButton,
		f.authorStatusIcon, f.authorPressOptions)
	f.authorContactButton:HookScript("OnHide", function() f.authorStatusTransition:Reset() end)
	f.authorStatusFrame:Hide()
end

function UGD:OpenAuthorWhisper()
	if not self:IsChinaRegion() then
		return false
	end
	if ChatFrameUtil and type(ChatFrameUtil.SendTell) == "function" then
		local ok = pcall(ChatFrameUtil.SendTell, self.AUTHOR_WHISPER_TARGET)
		if ok then
			return true
		end
	end
	if type(ChatFrame_SendTell) == "function" then
		return pcall(ChatFrame_SendTell, self.AUTHOR_WHISPER_TARGET)
	end
	return false
end

local function refreshBrandHeader(f)
	local addonVersion = getAddonVersion()
	local addonName = (GF.L or {}).ADDON_NAME or "GroupFinder"
	f.brandTitle:SetText(addonName)
	f.versionBadge.label = addonVersion
	if type(DAMAGE_TEXT_FONT) == "string" and DAMAGE_TEXT_FONT ~= "" then
		-- Match combat damage digits on both layers without changing the glow.
		for _, label in ipairs({ f.versionBadge.BGLabel, f.versionBadge.Label }) do
			local _, size, flags = label:GetFont()
			label:SetFont(DAMAGE_TEXT_FONT, size, flags)
		end
	end
	f.versionBadge.BGLabel:SetTextToFit(addonVersion)
	f.versionBadge.Label:SetTextToFit(addonVersion)
	f.versionBadge:MarkDirty()
	f.versionBadge:Show()
	refreshBrandLayout(f)
end

local function refreshUserLetterLayout(button)
	local style = GF.USER_LETTER_ENTRY_STYLE
	local width, height = button:GetWidth(), button:GetHeight()
	local _, actionFontSize = button.Action:GetFont()
	local actionScale = actionFontSize / style.actionSize
	local arrowSize, arrowGap = style.arrowSize * actionScale, style.arrowGap * actionScale
	GF.UI.SetAtlasFit(button.Arrow, style.arrowAtlas, arrowSize, arrowSize)
	local actionWidth = width - style.actionInset * 2 - arrowSize - arrowGap
	button.Action:SetWidth(actionWidth)
	button.Action:SetWidth(math.min(actionWidth, math.ceil(getTextWidth(button.Action, actionWidth))))
	measureAboutText(button.Action)
	local actionHeight = button.Action:GetHeight()
	local actionBottom = style.actionBottom
	local titleLeft = style.inset + style.iconSize + style.iconGap
	button.Title:SetWidth(width - titleLeft - style.inset)
	measureAboutText(button.Title)
	local headerHeight = math.max(style.iconSize, button.Title:GetHeight())
	local headerTop = style.titleTop
	local compact = headerTop + headerHeight + style.contentGap > height - actionBottom - actionHeight
	button.Icon:ClearAllPoints()
	button.Title:ClearAllPoints()
	button.Icon:Show()
	if compact then
		-- Give larger fonts the full card width before sacrificing decorative art.
		actionBottom = style.compactInset
		button.Title:SetWidth(width - style.inset * 2)
		measureAboutText(button.Title)
		local titleTop = style.compactInset + style.compactIconSize + style.compactGap
		if titleTop + button.Title:GetHeight() + style.compactGap > height - actionBottom - actionHeight then
			button.Icon:Hide()
			titleTop = style.compactInset
		end
		GF.UI.SetAtlasFit(button.Icon, style.iconAtlas, style.compactIconSize, style.compactIconSize)
		button.Icon:SetPoint("TOP", button, "TOP", style.iconOffsetX * style.compactIconSize,
			-style.compactInset + style.iconOffsetY * style.compactIconSize)
		button.Title:SetPoint("TOPLEFT", button, "TOPLEFT", style.inset, -titleTop)
		button.Title:SetJustifyH("CENTER")
	else
		GF.UI.SetAtlasFit(button.Icon, style.iconAtlas, style.iconSize, style.iconSize)
		button.Icon:SetPoint("LEFT", button, "TOPLEFT", style.inset + style.iconOffsetX * style.iconSize,
			-headerTop - headerHeight / 2 + style.iconOffsetY * style.iconSize)
		button.Title:SetPoint("TOPLEFT", button, "TOPLEFT", titleLeft,
			-headerTop - (headerHeight - button.Title:GetHeight()) / 2)
		button.Title:SetJustifyH("LEFT")
	end
	button.Action:ClearAllPoints()
	button.Arrow:ClearAllPoints()
	button.Action:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT",
		-style.actionInset - arrowSize - arrowGap, actionBottom)
	button.Arrow:SetPoint("LEFT", button.Action, "RIGHT", arrowGap, style.arrowOffsetY * arrowSize)
end

local function applyUserLetterTitleBlend(button)
	local blend = button.TitleFade.value
	local normal, hover = STYLE.BODY_TEXT, STYLE.MAIN_GOLD
	button.Title:SetTextColor(
		normal[1] + (hover[1] - normal[1]) * blend,
		normal[2] + (hover[2] - normal[2]) * blend,
		normal[3] + (hover[3] - normal[3]) * blend, 1)
end

local function advanceUserLetterTitleFade(button, elapsed)
	local fade = button.TitleFade
	if not fade then button:SetScript("OnUpdate", nil); return end
	fade.elapsed = fade.elapsed + elapsed
	local progress = math.min(fade.elapsed / fade.duration, 1)
	local eased = progress * progress * (3 - 2 * progress)
	fade.value = progress == 1 and fade.target or fade.from + (fade.target - fade.from) * eased
	applyUserLetterTitleBlend(button)
	if progress == 1 then button:SetScript("OnUpdate", nil) end
end

local function setUserLetterTitleHovered(button, hovered, immediate)
	local fade = button.TitleFade
	local target = hovered and 1 or 0
	if immediate then
		button:SetScript("OnUpdate", nil)
		fade.value, fade.target = target, target
		applyUserLetterTitleBlend(button)
	elseif fade.target ~= target then
		fade.from, fade.target, fade.elapsed = fade.value, target, 0
		local style = GF.USER_LETTER_ENTRY_STYLE
		local duration = hovered and style.hoverFadeInDuration or style.hoverFadeOutDuration
		fade.duration = duration * math.abs(target - fade.value)
		-- A fast reversal can return to the original color before the first tick.
		if fade.duration == 0 then
			button:SetScript("OnUpdate", nil)
		else
			button:SetScript("OnUpdate", advanceUserLetterTitleFade)
		end
	end
end

local function refreshContent(f)
	local L = GF.L or {}
	if f.titleText then f.titleText:SetText(L.USAGE_GUIDE_TITLE or "Addon details") end
	refreshBrandHeader(f)
	f.introText:SetText(L.USAGE_DETAIL_INTRO_TEXT or "")
	f.infoBox.Title:SetText(L.USAGE_DETAIL_INFO_TITLE or "Addon info")
	f.announcementBox.Title:SetText(L.USAGE_DETAIL_ANNOUNCEMENT_TITLE or "Addon Notice")
	f.noticeBox.Title:SetText(L.USAGE_DETAIL_NOTICE_TITLE or "Changelog")
	f.command:SetText(L.USAGE_DETAIL_SHORTCUT_TEXT or "/gf")
	f.commandTitle:SetText(L.USAGE_DETAIL_SHORTCUT_TITLE or "Quick access")
	f.authorLabel:SetText(L.USAGE_DETAIL_AUTHOR_TITLE or "Author info")
	f.feedbackLabel:SetText(L.USAGE_DETAIL_FEEDBACK_TITLE or "Official community")
	f.feedbackText:SetText(L.USAGE_DETAIL_FEEDBACK_TEXT or "")
	f.homepageLabel:SetText(L.USAGE_DETAIL_HOMEPAGE_TITLE or "Author blog")
	f.homepageText:SetText((L.USAGE_DETAIL_HOMEPAGE_TEXT or ""):gsub("^https?://", ""):gsub("^www%.", ""))
	UGD:RefreshAuthorContact(f)
	f.LetterButton.Title:SetText(L.USAGE_DETAIL_LETTER_CARD_TITLE or GF.UserLetter.TITLE)
	f.LetterButton.Action:SetText(L.USAGE_DETAIL_LETTER_READ or "Read letter")
	refreshUserLetterLayout(f.LetterButton)
	refreshAnnouncement(f)
	refreshNoticeContent(f)
	UGD:RefreshTheme()
	f.footer:SetText(STYLE.FOOTER_COPYRIGHT_TEXT)
end

local function playDialogSound(kind)
	if not PlaySound or not SOUNDKIT then
		return
	end
	local sound
	if kind == "open" then
		sound = SOUNDKIT.IG_QUEST_LOG_OPEN or SOUNDKIT.IG_CHARACTER_INFO_OPEN
	else
		sound = SOUNDKIT.IG_QUEST_LOG_CLOSE or SOUNDKIT.IG_CHARACTER_INFO_CLOSE
	end
	if sound then
		pcall(PlaySound, sound)
	end
end

local function hideMainFrameForDialog()
	local main = GF.MainFrame
	local frame = main and main.frame
	UGD._restoreMainFrame = main and main.IsUserVisible
		and main:IsUserVisible()
		or (main and not main.IsUserVisible
			and frame and frame:IsShown() and true or false)
	if not UGD._restoreMainFrame then
		return
	end
	main._suppressNextHideSound = true
	if main.HideFrame then
		main:HideFrame(true)
	else
		frame:Hide()
	end
end

local function restoreMainFrameAfterDialog()
	if not UGD._restoreMainFrame then
		return
	end
	UGD._restoreMainFrame = nil
	local main = GF.MainFrame
	if not main then
		return
	end
	main._suppressNextShowSound = true
	if main.ShowFrame then
		main:ShowFrame()
	elseif main.frame then
		main.frame:Show()
	end
end

local function createHorizontalGradient(parent, layer, color, startAlpha, endAlpha)
	local texture = parent:CreateTexture(nil, layer)
	if texture.SetGradient and CreateColor then
		texture:SetColorTexture(1, 1, 1, 1)
		texture:SetGradient("HORIZONTAL",
			CreateColor(color[1], color[2], color[3], startAlpha),
			CreateColor(color[1], color[2], color[3], endAlpha))
	else
		paint(texture, color[1], color[2], color[3], (startAlpha + endAlpha) / 2)
	end
	return texture
end

local function createBrandBand(parent)
	local band = CreateFrame("Frame", nil, parent)
	band:EnableMouse(false)
	local style = GF.ABOUT_STYLE.brandBand
	local black = { 0, 0, 0 }
	local left = createHorizontalGradient(band, "BACKGROUND", black, 0, style.backgroundAlpha)
	left:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", 0, 0)
	left:SetWidth(style.backgroundFadeWidth)
	local right = createHorizontalGradient(band, "BACKGROUND", black, style.backgroundAlpha, 0)
	right:SetPoint("TOPRIGHT", band, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(style.backgroundFadeWidth)
	local center = band:CreateTexture(nil, "BACKGROUND")
	paint(center, 0, 0, 0, style.backgroundAlpha)
	center:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
	center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

	-- Match the Mythic+ search threshold rule without stretching atlas pixels.
	local color = GF.MPLUS_BROWSE_THRESHOLD_DIVIDER_COLOR
	local alpha = GF.MPLUS_BROWSE_THRESHOLD_DIVIDER_CORE_ALPHA
	local height = GF.MPLUS_BROWSE_SIDEBAR_STYLE.thresholdDividerCoreHeight
	for _, edge in ipairs({ "TOP", "BOTTOM" }) do
		local ruleLeft = createHorizontalGradient(band, "ARTWORK", color, 0, alpha)
		ruleLeft:SetPoint(edge .. "LEFT", band, edge .. "LEFT", 0, 0)
		ruleLeft:SetPoint(edge .. "RIGHT", band, edge, 0, 0)
		ruleLeft:SetHeight(height)
		local ruleRight = createHorizontalGradient(band, "ARTWORK", color, alpha, 0)
		ruleRight:SetPoint(edge .. "LEFT", band, edge, 0, 0)
		ruleRight:SetPoint(edge .. "RIGHT", band, edge .. "RIGHT", 0, 0)
		ruleRight:SetHeight(height)
	end
	return band
end

local function createBrandHeader(f, compactLayout)
	f.content = CreateFrame("Frame", nil, f)
	f.content:SetPoint(
		"TOPLEFT",
		f,
		"TOPLEFT",
		LAYOUT.BODY_LEFT,
		LAYOUT.BODY_TOP)
	f.content:SetSize(LAYOUT.CONTENT_W, f:GetHeight() + LAYOUT.BODY_TOP - LAYOUT.BODY_BOTTOM)
	f.content:SetFrameLevel(f:GetFrameLevel() + 5)

	f.titleText = f.systemTitleText

	f.titleBand = createBrandBand(f.content)
	f.titleBand:SetFrameLevel(f.content:GetFrameLevel() + 1)
	f.titleBand:SetPoint(
		"TOPLEFT",
		f.content,
		"TOPLEFT",
		LAYOUT.TITLE_BAND_INSET_X,
		LAYOUT.TITLE_BAND_TOP_Y)
	f.titleBand:SetPoint(
		"TOPRIGHT",
		f.content,
		"TOPRIGHT",
		-LAYOUT.TITLE_BAND_INSET_X,
		LAYOUT.TITLE_BAND_TOP_Y)
	f.titleBand:SetHeight(LAYOUT.TITLE_BAND_H - (compactLayout and compactLayout.heightReduction or 0))

	f.logoFrame = CreateFrame("Frame", nil, f.content)
	f.logoFrame:SetFrameLevel(f.content:GetFrameLevel() + 20)
	f.logoFrame:SetSize(LAYOUT.LOGO_SIZE, LAYOUT.LOGO_SIZE)
	f.logoFrame:SetPoint("CENTER", f.titleBand, "TOP", 0, -1)
	f.logo = f.logoFrame:CreateTexture(nil, "OVERLAY", nil, 7)
	f.logo:SetTexture(
		GF.ADDON_MENU_LOGO_TEXTURE or LAYOUT.LOGO_TEXTURE)
	f.logo:SetAllPoints(f.logoFrame)

	f.brandLine = CreateFrame("Frame", nil, f.content)
	f.brandLine:SetPoint(
		"TOP",
		f.titleBand,
		"TOP",
		0,
		LAYOUT.BRAND_TOP + (compactLayout and compactLayout.titleRaise or 0))
	f.brandLine:SetSize(340, 42)
	f.brandTitle =
		createText(
			f.brandLine,
			"GameFontNormalHuge",
			STYLE.FONT_BRAND_TITLE,
			STYLE.MAIN_GOLD,
			"OUTLINE")
	f.brandTitle:SetPoint("CENTER", f.brandLine, "CENTER", 0, 0)
	f.brandTitle:SetSize(260, 40)
	f.brandTitle:SetJustifyH("CENTER")
	f.versionBadge = CreateFrame("Frame", nil, f.brandLine, "NewFeatureLabelTemplate")
	f.versionBadge:SetSize(1, 1)
	f.versionBadge:SetScale(LAYOUT.VERSION_BADGE_SCALE)
	f.versionBadge:SetFrameLevel(f.brandLine:GetFrameLevel() + 8)
	f.versionBadge:EnableMouse(false)
	-- Remove the blue text echo while preserving the separate animated Glow.
	f.versionBadge.BGLabel:Hide()
	f.versionBadge.Label:SetShadowColor(0, 0, 0, 0)
	f.versionBadge.Label:SetShadowOffset(0, 0)

end

local function createNoticeBox(f)
	f.noticeBox = CreateFrame("Frame", nil, f.content)
	f.noticeBox.FrameArt = AboutCard.CreateSurface(f.noticeBox)
	f.aboutPanels = { f.noticeBox }
	f.noticeBox:SetPoint(
		"BOTTOMLEFT",
		f.content,
		"BOTTOMLEFT",
		LAYOUT.INFO_BOX_INSET_X + LAYOUT.INFO_BOX_OFFSET_X,
		LAYOUT.INFO_BOX_BOTTOM_Y)
	f.noticeBox:SetPoint(
		"BOTTOMRIGHT",
		f.content,
		"BOTTOMRIGHT",
		-LAYOUT.INFO_BOX_INSET_X + LAYOUT.INFO_BOX_OFFSET_X,
		LAYOUT.INFO_BOX_BOTTOM_Y)
	f.noticeBox:SetHeight(LAYOUT.INFO_BOX_H)
	f.noticeScroll = GF.UI.CreateScrollFrame(f.noticeBox, { rowHeight = 20 })
	f.noticeScroll:SetPoint(
		"TOPLEFT",
		f.noticeBox,
		"TOPLEFT",
		LAYOUT.NOTICE_SCROLL_INSET_L,
		-LAYOUT.NOTICE_SCROLL_INSET_T)
	f.noticeScroll:SetPoint(
		"BOTTOMRIGHT",
		f.noticeBox,
		"BOTTOMRIGHT",
		-LAYOUT.NOTICE_SCROLL_INSET_R,
		LAYOUT.NOTICE_SCROLL_INSET_B)
	f.noticeScroll:SetFrameLevel(f.noticeBox:GetFrameLevel() + 2)
	f.noticeBody = CreateFrame("Frame", nil, f.noticeScroll)
	f.noticeBody:SetSize(
		LAYOUT.NOTICE_TEXT_W,
		LAYOUT.NOTICE_SCROLL_H)
	f.noticeScroll:SetScrollChild(f.noticeBody)
	f.noticeScrollBar =
		GF.UI.BindMinimalScrollBar(
			f.noticeScroll,
			LAYOUT.NOTICE_SCROLLBAR_GAP,
			f.noticeBox,
			true)
	if f.noticeScrollBar then
		f.noticeScrollBar:SetWidth(LAYOUT.NOTICE_SCROLLBAR_W)
	end
	if GF.UI.BindSmoothWheelScrolling then
		GF.UI.BindSmoothWheelScrolling(f.noticeScroll)
	end
	if GF.UI.BindScrollFrameEdgeFade then
		GF.UI.BindScrollFrameEdgeFade(f.noticeScroll, f.noticeBody, GF.ABOUT_STYLE.scrollEdgeFade)
	end
end

local function createUserLetterButton(f)
	local style = GF.USER_LETTER_ENTRY_STYLE
	local layout = GF.ABOUT_STYLE
	local button = createAboutCard(f, 0, layout.infoHeight + layout.gap, layout.leftWidth, style.height, "Button")
	f.LetterButton = button
	button:RegisterForClicks("LeftButtonUp")
	local art = button.FrameArt
	button:SetScript("OnMouseDown", function(_, mouseButton)
		if mouseButton == "LeftButton" then art:SetPressed(true) end
	end)
	button:SetScript("OnMouseUp", function() art:SetPressed(false) end)
	button.Background = button:CreateTexture(nil, "BACKGROUND", nil, 0)
	button.Background:SetTexture(style.backgroundTexture)
	button.Background:SetAllPoints(button.Interior)
	button.Background:SetAlpha(style.backgroundAlpha)
	button.Icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
	button.Title = createText(button, "GameFontHighlight", style.titleSize, STYLE.BODY_TEXT, "")
	button.TitleFade = { value = 0, target = 0 }
	button.Title:SetJustifyH("LEFT"); button.Title:SetJustifyV("TOP")
	button.Title:SetWordWrap(true); button.Title:SetSpacing(style.titleSpacing)
	button.Arrow = button:CreateTexture(nil, "ARTWORK", nil, 1)
	button.Action = createText(button, "GameFontNormal", style.actionSize, STYLE.MAIN_GOLD, "")
	button.Action:SetJustifyH("RIGHT"); button.Action:SetJustifyV("MIDDLE")
	button.Action:SetWordWrap(true)
	refreshUserLetterLayout(button)
	button:SetScript("OnClick", function() UGD:OpenUserLetter() end)
	button:SetScript("OnEnter", function()
		art:SetHovered(true); setUserLetterTitleHovered(button, true)
	end)
	local function clearHover(immediate)
		art:SetHovered(false); art:SetPressed(false); setUserLetterTitleHovered(button, false, immediate)
	end
	button:SetScript("OnLeave", function() clearHover(false) end)
	button:SetScript("OnHide", function() clearHover(true) end)
end

local function refreshAboutScrollBarsAfterOpen(f)
	if not f:IsShown() then return end
	-- Reapply current scrollbar presentation after the parent fade completes;
	-- do not relayout text or reset the reader's position.
	f.announcementView.dynamic.Refresh()
	f.noticeView.dynamic.Refresh()
end

local function installAboutMotion(f)
	f.aboutMotion = GF.UI.InstallWindowFloatMotion(f, {
		style = GF.ABOUT_STYLE.motion,
		onOpened = refreshAboutScrollBarsAfterOpen,
	})
	return f.aboutMotion
end

local function ensureFrame()
	local existing = UGD.frame
	if existing then
		return existing
	end
	local L = GF.L or {}
	local frameOptions = {
		name = "GroupFinderAddonUsageGuideDialog",
		width = LAYOUT.DIALOG_W,
		height = LAYOUT.DIALOG_H + LAYOUT.ABOUT_LETTER_SPACE - GF.ABOUT_STYLE.header.heightReduction,
		title = L.USAGE_GUIDE_TITLE or "Addon details",
		levelOffset = 5,
		onClose = function()
			UGD:Hide()
		end,
	}
	local f = GF.UI.CreateSatelliteSettingsFrame(frameOptions)
	installAboutMotion(f)
	applyDialogBackground(f)
	showSystemTitle(f)
	f:HookScript("OnHide", function()
		GF.UI.StopPopupOpenAnimation(f)
		if UGD._shown then
			UGD._shown = nil
			playDialogSound("close")
			if UGD._skipMainFrameRestore then
				UGD._skipMainFrameRestore = nil
				UGD._restoreMainFrame = nil
			else
				restoreMainFrameAfterDialog()
			end
		end
	end)

	createBrandHeader(f, GF.ABOUT_STYLE.header)

	f.introText =
		createText(
			f.content,
			"GameFontHighlight",
			STYLE.FONT_DESCRIPTION_TEXT,
			STYLE.BODY_TEXT,
			"")
	f.introText:SetPoint(
		"TOP",
		f.brandLine,
		"BOTTOM",
		0,
		-GF.ABOUT_STYLE.header.descriptionGap)
	f.introText:SetSize(LAYOUT.INTRO_W, 44)
	f.introText:SetJustifyH("CENTER")
	f.introText:SetWordWrap(true)
	if f.introText.SetSpacing then
		f.introText:SetSpacing(3)
	end

	createAboutInformation(f)
	createAuthorContactVisual(f)
	f.authorContactButton:RegisterForClicks("LeftButtonUp")
	f.authorContactButton:SetScript("OnClick", function(_, mouseButton)
		if mouseButton ~= "LeftButton" then return end
		GF.UI.PlayUISound("check")
		UGD:ContactAuthor()
	end)
	local function refreshAuthorTooltip(button)
		UGD:RefreshAuthorContact(f)
		UGD:ShowAuthorTooltip(button, f.authorStatus, f.authorIsFriend)
	end
	f.authorContactButton:SetScript("OnEnter", refreshAuthorTooltip)
	f.authorContactButton:SetScript("OnLeave", function()
		if GameTooltip and GameTooltip:IsOwned(f.authorContactButton) then
			GameTooltip:Hide()
		end
	end)
	f.authorContactButton:HookScript("OnHide", function(button)
		if GameTooltip and GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	f.authorStatusEvents = CreateFrame("Frame", nil, f)
	for _, eventName in ipairs({
		"FRIENDLIST_UPDATE",
		"PLAYER_ENTERING_WORLD",
		"BN_CONNECTED",
		"BN_DISCONNECTED",
		"BN_FRIEND_ACCOUNT_ONLINE",
		"BN_FRIEND_ACCOUNT_OFFLINE",
		"BN_FRIEND_INFO_CHANGED",
		"BN_FRIEND_LIST_SIZE_CHANGED",
	}) do
		f.authorStatusEvents:RegisterEvent(eventName)
	end
	f.authorStatusEvents:SetScript("OnEvent", function(_, event)
		if event == "FRIENDLIST_UPDATE" then
			UGD._authorFriendListReady = true
		elseif event == "PLAYER_ENTERING_WORLD" then
			UGD._authorFriendListReady = nil
			if f:IsShown() then
				UGD:RequestAuthorFriendList()
			end
		end
		if f:IsShown() then
			if GameTooltip and GameTooltip:IsOwned(f.authorContactButton) then
				refreshAuthorTooltip(f.authorContactButton)
			else
				UGD:RefreshAuthorContact(f)
			end
		end
	end)
	f:HookScript("OnShow", function()
		UGD:RequestAuthorFriendList()
	end)
	colorText(f.feedbackText, GF.ABOUT_STYLE.info.linkColor)
	colorText(f.homepageText, GF.ABOUT_STYLE.info.linkColor)

	createAboutNotices(f)
	createUserLetterButton(f)

	f.noticeEmpty =
		createText(
			f.noticeBox,
			"GameFontDisable",
			STYLE.FONT_NOTICE_TEXT,
			STYLE.NOTICE_GRAY,
			"")
	f.noticeEmpty:SetPoint("CENTER", f.noticeBox, "CENTER", 0, -2)
	f.noticeEmpty:SetSize(260, 20)
	f.noticeEmpty:SetJustifyH("CENTER")

	f.footer =
		createText(
			f,
			"GameFontDisableSmall",
			STYLE.FONT_FOOTER_TEXT,
			STYLE.FOOTER_GRAY,
			"")
	-- Center within the actual gap between the cards and the inner panel edge.
	f.footer:SetPoint("TOP", f.aboutBody, "BOTTOM", 0, 0)
	f.footer:SetPoint("BOTTOM", f.gfBodyBg.fill, "BOTTOM", 0, 0)
	f.footer:SetWidth(LAYOUT.CONTENT_W)
	f.footer:SetJustifyH("CENTER")
	f.footer:SetJustifyV("MIDDLE")

	UGD.frame = f
	refreshContent(f)
	return f
end

function UGD:Hide(immediate)
	local frame = self.frame
	if frame and frame.Hide then
		if immediate and frame.aboutMotion then frame.aboutMotion:HideImmediately()
		else frame:Hide() end
	end
end

function UGD:OpenUserLetter()
	if not GF.UserLetterDialog:Show() then return false end
	-- This handoff must not restore the main window when About closes.
	self._restoreMainFrame = nil
	self:Hide(true)
	local main = GF.MainFrame
	if main then
		if main.HideFrame then
			main:HideFrame(true)
		elseif main.frame then
			main.frame:Hide()
		end
	end
	return true
end

function UGD:RefreshLocale()
	local frame = self.frame
	if not frame then
		return
	end
	local L = GF.L or {}
	GF.UI.ApplySettingsFrameChrome(frame, L.USAGE_GUIDE_TITLE or "Addon details")
	showSystemTitle(frame)
	refreshContent(frame)
end

function UGD:CloseForMainFrameOpen()
	if self.frame and self.frame:IsShown() then
		self._skipMainFrameRestore = true
		self:Hide(true)
	end
end

function UGD:Show()
	local L = GF.L or {}
	local f = ensureFrame()
	if f:IsShown() then
		if f.aboutMotion and f.aboutMotion:IsClosing() then f.aboutMotion:Open(false) end
		refreshContent(f)
		return
	end
	GF.UI.ApplySettingsFrameChrome(f, L.USAGE_GUIDE_TITLE or "Addon details")
	showSystemTitle(f)
	applyDialogBackground(f)
	GF.UI.CenterOnUIParent(f, 0)
	refreshContent(f)
	hideMainFrameForDialog()
	GF.UI.SuppressNextPopupOpenAnimation(f)
	f:Show()
	self._shown = true
	f.aboutMotion:Open(true)
	playDialogSound("open")
end


-- Reuse About's art, geometry, fonts and scrollbar without creating its
-- author/social controls, introduction, shortcut or changelog rows.
function UGD:CreateUserLetterFrame(onClose)
	local f = GF.UI.CreateSatelliteSettingsFrame({
		name = "GroupFinderAddonUserLetterDialog",
		width = LAYOUT.DIALOG_W,
		height = LAYOUT.DIALOG_H,
		title = GF.UserLetter.TITLE,
		levelOffset = 10,
		onClose = onClose,
	})
	f.letterMotion = GF.UI.InstallWindowFloatMotion(f, { style = GF.ABOUT_STYLE.motion })
	applyDialogBackground(f)
	showSystemTitle(f)
	createBrandHeader(f)
	createNoticeBox(f)
	f.letterWaxSeal = f.noticeBody:CreateTexture(nil, "ARTWORK")
	f.letterWaxSeal:Hide()
	-- Keep the brand and letter inside the same pair of gold rules.
	-- The lower rule sits below the reading area, above the fixed button.
	f.titleBand:SetHeight(LAYOUT.CONTENT_H + LAYOUT.TITLE_BAND_TOP_Y - 32)
	f.noticeBox:SetFrameLevel(f.titleBand:GetFrameLevel() + 1)
	f.noticeBox:ClearAllPoints()
	f.noticeBox:SetPoint("TOPLEFT", f.content, "TOPLEFT",
		LAYOUT.INFO_BOX_INSET_X + LAYOUT.INFO_BOX_OFFSET_X,
		LAYOUT.TITLE_BAND_TOP_Y + LAYOUT.BRAND_TOP - 42 - LAYOUT.TITLE_DESC_GAP)
	f.noticeBox:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT",
		-LAYOUT.INFO_BOX_INSET_X + LAYOUT.INFO_BOX_OFFSET_X, 48)
	f.readButton = GF.UI.CreatePanelButton(f, "", 120)
	f.readButton:SetHeight(GF.PANEL_BUTTON_H)
	f.readButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
	return f
end

function UGD:RefreshUserLetterFrame(f)
	GF.UI.ApplySettingsFrameChrome(f, GF.UserLetter.TITLE)
	showSystemTitle(f)
	applyDialogBackground(f)
	refreshPanelTheme(f)
	refreshBrandHeader(f)
	f.readButton:SetText(GF.UserLetter.READ_LABEL)
	clearNoticeRows(f)
	f.letterWaxSeal:Hide()
	local y = -16
	for index, block in ipairs(GF.UserLetter.BLOCKS) do
		local heading = block.heading == true
		if heading and index > 1 then y = y - 8 end
		local height
		if heading and block.text:sub(1, #"◆") == "◆" then
			local bullet, fs = acquireNoticeBulletText(f, index,
				"GameFontNormalLarge", 16, STYLE.MAIN_GOLD, "OUTLINE")
			local _, fontHeight = fs:GetFont()
			local size = math.max(1, math.floor((fontHeight or LAYOUT.NOTICE_BULLET_SIZE) + 0.5))
			local gap = LAYOUT.NOTICE_BULLET_GAP * size / LAYOUT.NOTICE_BULLET_SIZE
			bullet:SetSize(size, size)
			fs:SetWidth(math.max(1, LAYOUT.NOTICE_TEXT_W - size - gap))
			fs:SetSpacing(4)
			fs:SetHeight(0)
			fs:SetText(block.text:sub(#"◆" + 1))
			local textHeight = math.ceil(fs:GetStringHeight()) + 2
			fs:SetHeight(textHeight)
			fs:SetJustifyV("MIDDLE")
			height = math.max(size, textHeight)
			-- Center the text on the actual diamond, including wrapped headings.
			bullet:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", 0,
				y - (height - size) / 2)
			fs:SetPoint("LEFT", bullet, "RIGHT", gap, 0)
		else
			local fs = acquireNoticeText(f, index,
				heading and "GameFontNormalLarge" or "GameFontHighlight",
				heading and 16 or 14,
				heading and STYLE.MAIN_GOLD or STYLE.BODY_TEXT,
				heading and "OUTLINE" or "")
			fs:SetJustifyH(block.signature and "RIGHT" or "LEFT")
			if block.signature then
				fs:SetWidth(LAYOUT.NOTICE_TEXT_W - LAYOUT.LETTER_SIGNATURE_INSET_R)
			end
			fs:SetSpacing(4)
			fs:SetHeight(0)
			fs:SetText(block.text)
			fs:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", 0, y)
			height = math.ceil(fs:GetStringHeight())
			fs:SetHeight(height + 2)
			if block.signature and GF.UI.SetAtlasFit(f.letterWaxSeal,
				GF.USER_LETTER_WAX_SEAL_ATLAS,
				GF.USER_LETTER_WAX_SEAL_SIZE, GF.USER_LETTER_WAX_SEAL_SIZE)
			then
				f.letterWaxSeal:ClearAllPoints()
				f.letterWaxSeal:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT",
					0, -GF.USER_LETTER_WAX_SEAL_GAP)
				f.letterWaxSeal:Show()
				height = height + 2 + GF.USER_LETTER_WAX_SEAL_GAP
					+ f.letterWaxSeal:GetHeight()
			end
		end
		y = y - height - 16
	end
	f.noticeBody:SetSize(LAYOUT.NOTICE_TEXT_W,
		math.max(f.noticeScroll:GetHeight(), -y))
	GF.UI.UpdateScrollFrame(f.noticeScroll)
end
