local _, GF = ...

GF.UsageGuideDialog = {}
local UGD = GF.UsageGuideDialog

local LAYOUT = {
	DIALOG_W = 760,
	DIALOG_H = 688,
	BODY_LEFT = 28,
	BODY_RIGHT = 28,
	BODY_TOP = -52,
	BODY_BOTTOM = 26,
	BODY_BG_ALPHA = 0.92,
	BODY_BG_INSET_LEFT = GF.FRAME_BG_INSET_LEFT or 7,
	BODY_BG_INSET_TOP = GF.FRAME_BG_INSET_TOP or -18,
	BODY_BG_INSET_RIGHT = GF.FRAME_BG_INSET_RIGHT or -2,
	BODY_BG_INSET_BOTTOM = GF.FRAME_BG_INSET_BOTTOM or 3,
	LOGO_TEXTURE = GF.ADDON_MENU_LOGO_TEXTURE,
	INFO_ATLAS_TEXTURE = GF.INFO_ATLAS_TEXTURE,
	INFO_ATLAS_W = GF.INFO_ATLAS_WIDTH,
	INFO_ATLAS_H = GF.INFO_ATLAS_HEIGHT,
	TITLE_ATLAS_REGION = GF.INFO_ATLAS_REGIONS.title,
	INFO_BOX_REGION = GF.INFO_ATLAS_REGIONS.notice,
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
	NOTICE_VERSION_TEXT_INSET = 12,
	NOTICE_VERSION_GAP = 12,
	NOTICE_ENTRY_GAP = 20,
	NOTICE_LINE_GAP = 4,
	NOTICE_ITEM_GAP = 6,
	NOTICE_BODY_LINE_SPACING = 2,
	NOTICE_BULLET_ATLAS = "housing-dashboard-fillbar-pip-complete",
	NOTICE_BULLET_SIZE = 16,
	NOTICE_BULLET_GAP = 4,
	NOTICE_SECTION_GAP = 6,
	LETTER_SIGNATURE_INSET_R = 16,
	COMMAND_TOP_GAP = 18,
	INFO_LEFT_X = 64,
	INFO_RIGHT_X = 388,
	INFO_TOP_GAP = 12,
	AUTHOR_STATUS_FRAME_SIZE = 24,
	AUTHOR_STATUS_ICON_SIZE = 14,
	AUTHOR_STATUS_FRAME_Y = -1.25, -- Align with visible glyphs below the font field center.
	AUTHOR_STATUS_GAP = 6,
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
		"COPYRIGHT (C) 2026 GAICAS.COM ALL RIGHTS RESERVED.",
	MAIN_GOLD = { 1, 0.82, 0, 1 },
	BODY_TEXT = { 238 / 255, 228 / 255, 205 / 255, 1 },
	LINK_BLUE = { 130 / 255, 204 / 255, 1, 1 },
	FOOTER_GRAY = { 0.5, 0.5, 0.5, 1 },
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

local AUTHOR_STATUS_VALUE_COLORS = {
	online = { 0.2, 1, 0.35 },
	offline = { 0.65, 0.65, 0.65 },
	unknown = { 0.65, 0.65, 0.65 },
}
local AUTHOR_STATUS_ATLASES = {
	online = "voicechat-icon-headphone-on",
	offline = "voicechat-icon-headphone-off",
	unknown = "voicechat-icon-headphone-pending",
}
local AUTHOR_STATUS_FRAME_ATLAS = "common-button-tertiary-square-normal"
local AUTHOR_STATUS_PRESSED_ATLAS = "common-button-tertiary-square-pressed"

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
	return "3.0.0"
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
		paint(fill, 5 / 255, 4 / 255, 2 / 255, LAYOUT.BODY_BG_ALPHA)
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

local function formatNoticeBodyLine(text)
	local categoryID, prefix, body = parseNoticeBodyLine(text)
	if not (categoryID and prefix and body) then
		return text
	end
	local separator = prefix:sub(-1) == ":" and " " or ""
	return NOTICE_CATEGORY_PREFIX_COLOR_CODE
		.. prefix
		.. NOTICE_COLOR_RESET_CODE
		.. separator
		.. body
end

local function setTexCoordByPixels(texture, region, left, right, top, bottom)
	local regionX, regionY = region[1], region[2]
	texture:SetTexCoord(
		(regionX + left) / LAYOUT.INFO_ATLAS_W,
		(regionX + right) / LAYOUT.INFO_ATLAS_W,
		(regionY + top) / LAYOUT.INFO_ATLAS_H,
		(regionY + bottom) / LAYOUT.INFO_ATLAS_H)
end

local function createSlicedAtlas(parent, region, caps, layer, subLevel)
	local frame = CreateFrame("Frame", nil, parent)
	frame.parts = {}
	local names = {
		"topLeft", "top", "topRight",
		"left", "center", "right",
		"bottomLeft", "bottom", "bottomRight",
	}
	for _, name in ipairs(names) do
		local tex = frame:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 0)
		tex:SetTexture(LAYOUT.INFO_ATLAS_TEXTURE)
		frame.parts[name] = tex
	end

	local sourceW, sourceH = region[3], region[4]
	local sourceLeft = caps.left or 0
	local sourceRight = caps.right or 0
	local sourceTop = caps.top or 0
	local sourceBottom = caps.bottom or 0
	local scale = caps.scale or 1
	local left = sourceLeft * scale
	local right = sourceRight * scale
	local top = sourceTop * scale
	local bottom = sourceBottom * scale
	local srcLeft = sourceLeft
	local srcRight = sourceW - sourceRight
	local srcTop = sourceTop
	local srcBottom = sourceH - sourceBottom
	local p = frame.parts

	p.topLeft:SetSize(left, top)
	p.topLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	setTexCoordByPixels(p.topLeft, region, 0, srcLeft, 0, srcTop)

	p.top:SetHeight(top)
	p.top:SetPoint("TOPLEFT", p.topLeft, "TOPRIGHT", 0, 0)
	p.top:SetPoint("TOPRIGHT", p.topRight, "TOPLEFT", 0, 0)
	setTexCoordByPixels(p.top, region, srcLeft, srcRight, 0, srcTop)

	p.topRight:SetSize(right, top)
	p.topRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	setTexCoordByPixels(p.topRight, region, srcRight, sourceW, 0, srcTop)

	p.left:SetWidth(left)
	p.left:SetPoint("TOPLEFT", p.topLeft, "BOTTOMLEFT", 0, 0)
	p.left:SetPoint("BOTTOMLEFT", p.bottomLeft, "TOPLEFT", 0, 0)
	setTexCoordByPixels(p.left, region, 0, srcLeft, srcTop, srcBottom)

	p.center:SetPoint("TOPLEFT", p.topLeft, "BOTTOMRIGHT", 0, 0)
	p.center:SetPoint("BOTTOMRIGHT", p.bottomRight, "TOPLEFT", 0, 0)
	setTexCoordByPixels(p.center, region, srcLeft, srcRight, srcTop, srcBottom)

	p.right:SetWidth(right)
	p.right:SetPoint("TOPRIGHT", p.topRight, "BOTTOMRIGHT", 0, 0)
	p.right:SetPoint("BOTTOMRIGHT", p.bottomRight, "TOPRIGHT", 0, 0)
	setTexCoordByPixels(p.right, region, srcRight, sourceW, srcTop, srcBottom)

	p.bottomLeft:SetSize(left, bottom)
	p.bottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	setTexCoordByPixels(p.bottomLeft, region, 0, srcLeft, srcBottom, sourceH)

	p.bottom:SetHeight(bottom)
	p.bottom:SetPoint("BOTTOMLEFT", p.bottomLeft, "BOTTOMRIGHT", 0, 0)
	p.bottom:SetPoint("BOTTOMRIGHT", p.bottomRight, "BOTTOMLEFT", 0, 0)
	setTexCoordByPixels(p.bottom, region, srcLeft, srcRight, srcBottom, sourceH)

	p.bottomRight:SetSize(right, bottom)
	p.bottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	setTexCoordByPixels(p.bottomRight, region, srcRight, sourceW, srcBottom, sourceH)

	return frame
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

local function hideNoticeVersionDecor(row)
	if row.versionBackground then
		row.versionBackground:Hide()
	end
	if row.versionAccent then
		row.versionAccent:Hide()
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
	fs:SetWidth(LAYOUT.NOTICE_TEXT_W)
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

local function utf8ByteOffsets(text)
	local offsets = {}
	local index = 1
	local byteLength = #text
	while index <= byteLength do
		offsets[#offsets + 1] = index
		local first = text:byte(index) or 0
		local charLength = first < 0x80 and 1
			or first < 0xE0 and 2
			or first < 0xF0 and 3
			or first < 0xF8 and 4
			or 1
		if index + charLength - 1 > byteLength then
			charLength = 1
		end
		index = index + charLength
	end
	offsets[#offsets + 1] = byteLength + 1
	return offsets
end

local function measureRichTextWidth(fs, text)
	fs:SetText(text or "")
	local width = fs.GetUnboundedStringWidth
		and fs:GetUnboundedStringWidth()
		or fs:GetStringWidth()
	return math.max(0, tonumber(width) or 0)
end

local function fitRichTextChunk(fs, text, maxWidth)
	if text == "" then
		return "", ""
	end
	if measureRichTextWidth(fs, text) <= maxWidth then
		return text, ""
	end
	local offsets = utf8ByteOffsets(text)
	local characterCount = #offsets - 1
	local low, high = 1, characterCount
	local fittedCount = 0
	while low <= high do
		local middle = math.floor((low + high) / 2)
		local candidate = text:sub(1, offsets[middle + 1] - 1)
		if measureRichTextWidth(fs, candidate) <= maxWidth then
			fittedCount = middle
			low = middle + 1
		else
			high = middle - 1
		end
	end
	if fittedCount <= 0 then
		return "", text
	end
	local splitByte = offsets[fittedCount + 1]
	local chunk = text:sub(1, splitByte - 1)
	local remainder = text:sub(splitByte)
	if remainder ~= "" then
		local lastWhitespace = chunk:match("^.*()%s")
		if lastWhitespace and lastWhitespace > 1 then
			remainder = text:sub(lastWhitespace + 1):gsub("^%s+", "")
			chunk = text:sub(1, lastWhitespace - 1):gsub("%s+$", "")
		end
	end
	return chunk, remainder
end

local function acquireNoticeRichMeasure(f, row, emphasis)
	local key = emphasis and "richMeasureEmphasis" or "richMeasureBody"
	local fs = row[key]
	local template = emphasis and "GameFontNormal" or "GameFontHighlight"
	local color = emphasis and STYLE.MAIN_GOLD or STYLE.BODY_TEXT
	local flags = emphasis and "OUTLINE" or ""
	if not fs then
		fs = createText(
			f.noticeBody,
			template,
			STYLE.FONT_NOTICE_TEXT,
			color,
			flags)
		row[key] = fs
	else
		setFont(fs, template, STYLE.FONT_NOTICE_TEXT, flags)
		colorText(fs, color)
	end
	fs:Hide()
	return fs
end

local function acquireNoticeRichPart(f, row, partIndex, emphasis)
	row.richParts = row.richParts or {}
	local part = row.richParts[partIndex]
	local template = emphasis and "GameFontNormal" or "GameFontHighlight"
	local color = emphasis and STYLE.MAIN_GOLD or STYLE.BODY_TEXT
	local flags = emphasis and "OUTLINE" or ""
	if not part then
		part = createText(
			f.noticeBody,
			template,
			STYLE.FONT_NOTICE_TEXT,
			color,
			flags)
		row.richParts[partIndex] = part
	else
		part:SetParent(f.noticeBody)
		setFont(part, template, STYLE.FONT_NOTICE_TEXT, flags)
		colorText(part, color)
	end
	part:ClearAllPoints()
	part:SetJustifyH("LEFT")
	part:SetJustifyV("TOP")
	part:SetWordWrap(false)
	part:Show()
	return part
end

local function addNoticeRichLine(f, index, y, spans, gap)
	local row = ensureNoticeRow(f, index)
	hideNoticeVersionDecor(row)
	if row.text then
		row.text:Hide()
	end
	if row.bullet then
		row.bullet:Hide()
	end
	if row.body then
		row.body:Hide()
	end
	hideNoticeRichParts(row)

	local bodyMeasure = acquireNoticeRichMeasure(f, row, false)
	local emphasisMeasure = acquireNoticeRichMeasure(f, row, true)
	local _, bodyFontHeight = bodyMeasure:GetFont()
	local _, emphasisFontHeight = emphasisMeasure:GetFont()
	local lineHeight = math.ceil(math.max(
		tonumber(bodyFontHeight) or STYLE.FONT_NOTICE_TEXT,
		tonumber(emphasisFontHeight) or STYLE.FONT_NOTICE_TEXT))
	local lineAdvance = lineHeight + LAYOUT.NOTICE_BODY_LINE_SPACING
	local firstLineIndent = math.max(
		measureRichTextWidth(bodyMeasure, "　　"),
		lineHeight * 2)
	local lineIndex = 0
	local x = firstLineIndent
	local partIndex = 1

	for _, span in ipairs(spans or {}) do
		local text = type(span) == "table" and span.text or span
		local emphasis = type(span) == "table" and span.emphasis == true
		text = type(text) == "string" and text or ""
		while text ~= "" do
			if x == 0 then
				text = text:gsub("^%s+", "")
			end
			local measure = emphasis and emphasisMeasure or bodyMeasure
			local availableWidth = LAYOUT.NOTICE_TEXT_W - x
			local chunk, remainder =
				fitRichTextChunk(measure, text, availableWidth)
			if chunk == "" and x > 0 then
				lineIndex = lineIndex + 1
				x = 0
			else
				if chunk == "" then
					local offsets = utf8ByteOffsets(text)
					chunk = text:sub(1, offsets[2] - 1)
					remainder = text:sub(offsets[2])
				end
				local part = acquireNoticeRichPart(
					f, row, partIndex, emphasis)
				local width = math.ceil(measureRichTextWidth(measure, chunk))
				part:SetText(chunk)
				part:SetSize(math.max(width + 1, 1), lineHeight + 2)
				part:SetPoint(
					"TOPLEFT",
					f.noticeBody,
					"TOPLEFT",
					x,
					y - lineIndex * lineAdvance)
				x = x + width
				partIndex = partIndex + 1
				text = remainder
				if text ~= "" then
					lineIndex = lineIndex + 1
					x = 0
				end
			end
		end
	end

	for unusedIndex = partIndex, #(row.richParts or {}) do
		row.richParts[unusedIndex]:Hide()
	end
	local height = (lineIndex + 1) * lineAdvance
		- LAYOUT.NOTICE_BODY_LINE_SPACING
	return index + 1, y - height - (gap or LAYOUT.NOTICE_LINE_GAP)
end

local function addNoticeSectionTitle(f, index, y, text)
	local fs = acquireNoticeText(
		f,
		index,
		"GameFontNormalLarge",
		STYLE.FONT_NOTICE_TITLE,
		STYLE.MAIN_GOLD,
		"OUTLINE")
	local row = ensureNoticeRow(f, index)
	if not row.sectionTitleBackground then
		row.sectionTitleBackground =
			f.noticeBody:CreateTexture(nil, "BACKGROUND", nil, -6)
	end
	local background = row.sectionTitleBackground
	background:SetParent(f.noticeBody)
	background:ClearAllPoints()
	background:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", 0, y)
	background:SetPoint("TOPRIGHT", f.noticeBody, "TOPRIGHT", 0, y)
	background:SetHeight(LAYOUT.NOTICE_SECTION_TITLE_H)
	local hasAtlas = GF.UI
		and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(
			background,
			LAYOUT.NOTICE_SECTION_TITLE_ATLAS,
			false)
	if not hasAtlas then
		background:SetColorTexture(0.04, 0.035, 0.025, 0.92)
	else
		background:SetVertexColor(1, 1, 1, 1)
	end
	background:Show()

	fs:SetText(text or "")
	fs:SetPoint(
		"TOPLEFT",
		f.noticeBody,
		"TOPLEFT",
		LAYOUT.NOTICE_SECTION_TITLE_TEXT_INSET,
		y)
	fs:SetWidth(
		LAYOUT.NOTICE_TEXT_W
			- LAYOUT.NOTICE_SECTION_TITLE_TEXT_INSET * 2)
	fs:SetHeight(LAYOUT.NOTICE_SECTION_TITLE_H)
	fs:SetJustifyH("CENTER")
	fs:SetJustifyV("MIDDLE")
	return index + 1,
		y
			- LAYOUT.NOTICE_SECTION_TITLE_H
			- LAYOUT.NOTICE_SECTION_TITLE_GAP
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
	if not row.versionBackground then
		row.versionBackground =
			f.noticeBody:CreateTexture(nil, "ARTWORK")
	end
	if not row.versionAccent then
		row.versionAccent = f.noticeBody:CreateTexture(nil, "ARTWORK")
	end
	row.versionBackground:SetParent(f.noticeBody)
	row.versionBackground:ClearAllPoints()
	row.versionBackground:SetPoint(
		"TOPLEFT", f.noticeBody, "TOPLEFT", 0, y)
	row.versionBackground:SetPoint(
		"TOPRIGHT", f.noticeBody, "TOPRIGHT", 0, y)
	row.versionBackground:SetHeight(LAYOUT.NOTICE_VERSION_ROW_H)
	row.versionBackground:SetColorTexture(1, 1, 1, 1)
	row.versionBackground:SetGradient(
		"HORIZONTAL",
		CreateColor(1, 0.82, 0, 0.16),
		CreateColor(1, 0.82, 0, 0))
	row.versionBackground:Show()
	row.versionAccent:SetParent(f.noticeBody)
	row.versionAccent:ClearAllPoints()
	row.versionAccent:SetPoint(
		"TOPLEFT", f.noticeBody, "TOPLEFT", 0, y)
	row.versionAccent:SetSize(3, LAYOUT.NOTICE_VERSION_ROW_H)
	row.versionAccent:SetColorTexture(1, 0.82, 0, 0.85)
	row.versionAccent:Show()
	fs:SetText(text or "")
	fs:SetPoint(
		"TOPLEFT",
		f.noticeBody,
		"TOPLEFT",
		LAYOUT.NOTICE_VERSION_TEXT_INSET,
		y)
	fs:SetWidth(
		LAYOUT.NOTICE_TEXT_W - LAYOUT.NOTICE_VERSION_TEXT_INSET * 2)
	fs:SetHeight(LAYOUT.NOTICE_VERSION_ROW_H)
	fs:SetJustifyV("MIDDLE")
	return index + 1,
		y - LAYOUT.NOTICE_VERSION_ROW_H - LAYOUT.NOTICE_VERSION_GAP
end

local function addNoticeBulletLine(f, index, y, body, template, size, color, flags, gap)
	local bullet, bodyText =
		acquireNoticeBulletText(f, index, template, size, color, flags)
	bodyText:SetText(body or "")
	local bodyX = LAYOUT.NOTICE_BULLET_SIZE + LAYOUT.NOTICE_BULLET_GAP
	local bodyW = math.max(LAYOUT.NOTICE_TEXT_W - bodyX, 80)
	local _, fontHeight = bodyText:GetFont()
	fontHeight = tonumber(fontHeight) or size or STYLE.FONT_NOTICE_TEXT
	local bulletTopOffset =
		-math.max(0, (fontHeight - LAYOUT.NOTICE_BULLET_SIZE) / 2)
	local textFromBulletY =
		(fontHeight - LAYOUT.NOTICE_BULLET_SIZE) / 2
	bullet:SetPoint(
		"TOPLEFT",
		f.noticeBody,
		"TOPLEFT",
		0,
		y + bulletTopOffset)
	bodyText:SetPoint(
		"TOPLEFT",
		bullet,
		"TOPRIGHT",
		LAYOUT.NOTICE_BULLET_GAP,
		textFromBulletY)
	bodyText:SetWidth(bodyW)
	bodyText:SetHeight(0)
	local bodyH = bodyText.GetStringHeight and bodyText:GetStringHeight() or 0
	if type(bodyH) ~= "number" or bodyH <= 0 then
		bodyH = fontHeight
	end
	local textTopOffset = bulletTopOffset + textFromBulletY
	local height = math.max(
		LAYOUT.NOTICE_BULLET_SIZE - bulletTopOffset,
		bodyH - textTopOffset)
	height = math.ceil(height)
	bodyText:SetHeight(math.ceil(bodyH))
	return index + 1, y - height - (gap or LAYOUT.NOTICE_ITEM_GAP)
end

local function refreshNoticeContent(f)
	local L = GF.L or {}
	local entries = L.USAGE_DETAIL_NOTICE_ENTRIES
	if type(entries) ~= "table" or #entries == 0 then
		clearNoticeRows(f)
		f.noticeScroll:Hide()
		if f.noticeScrollBar then
			f.noticeScrollBar:Hide()
		end
		f.noticeEmpty:SetText(L.USAGE_DETAIL_NOTICE_EMPTY or "No notices")
		f.noticeEmpty:Show()
		return
	end

	f.noticeEmpty:Hide()
	f.noticeScroll:Show()
	clearNoticeRows(f)
	local rowIndex = 1
	local y = 0
	local announcementTitle = L.USAGE_DETAIL_ANNOUNCEMENT_TITLE
	local announcementLines = L.USAGE_DETAIL_ANNOUNCEMENT_LINES
	if type(announcementTitle) == "string"
		and announcementTitle ~= ""
		and type(announcementLines) == "table"
		and #announcementLines > 0
	then
		rowIndex, y = addNoticeSectionTitle(
			f,
			rowIndex,
			y,
			announcementTitle
		)
		for _, announcementLine in ipairs(announcementLines) do
			if type(announcementLine) == "table" then
				rowIndex, y = addNoticeRichLine(
					f,
					rowIndex,
					y,
					announcementLine,
					LAYOUT.NOTICE_LINE_GAP)
			else
				rowIndex, y = addNoticeLine(
					f,
					rowIndex,
					y,
					announcementLine,
					"GameFontHighlight",
					STYLE.FONT_NOTICE_TEXT,
					STYLE.BODY_TEXT,
					"",
					LAYOUT.NOTICE_LINE_GAP)
			end
		end
		y = y - LAYOUT.NOTICE_SECTION_GAP
	end
	rowIndex, y = addNoticeSectionTitle(
		f,
		rowIndex,
		y,
		L.USAGE_DETAIL_NOTICE_TITLE or "Changelog:"
	)

	for entryIndex, entry in ipairs(entries) do
		if type(entry) == "table" then
			local version = entry.version or ""
			if version ~= "" then
				rowIndex, y =
					addNoticeVersionLine(f, rowIndex, y, version)
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
						formatNoticeBodyLine(line),
						"GameFontHighlight",
						STYLE.FONT_NOTICE_TEXT,
						STYLE.BODY_TEXT,
						"",
						isFinalLine and 0 or LAYOUT.NOTICE_ITEM_GAP
					)
				end
			end
			if entryIndex < #entries then
				y = y - LAYOUT.NOTICE_ENTRY_GAP
			end
		end
	end

	local contentH =
		math.max(
			LAYOUT.NOTICE_SCROLL_H,
			math.ceil(-y + LAYOUT.NOTICE_SCROLL_INSET_B))
	f.noticeBody:SetSize(LAYOUT.NOTICE_TEXT_W, contentH)
	if f.noticeScroll.SetVerticalScroll then
		if GF.UI.CancelSmoothWheelScrolling then
			GF.UI.CancelSmoothWheelScrolling(f.noticeScroll)
		end
		f.noticeScroll:SetVerticalScroll(0)
	end
	GF.UI.UpdateScrollFrame(f.noticeScroll)
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
		and f.authorStatusFrame and f.authorStatusIcon and f.authorStatusDots)
	then
		return
	end
	local L = GF.L or {}
	local isChina = self:IsChinaRegion()
	f.authorText:SetText(isChina and self.AUTHOR_WHISPER_TARGET
		or L.USAGE_DETAIL_AUTHOR_TEXT or self.AUTHOR_WHISPER_TARGET)
	f.authorText:ClearAllPoints()
	if not isChina then
		f.authorStatus = "unknown"
		f.authorIsFriend = nil
		f.authorStatusDots:Hide()
		f.authorStatusFrame:Hide()
		f.authorContactButton:Hide()
		f.authorText:SetPoint("LEFT", f.authorRow.label, "RIGHT", 0, 0)
		f.authorText:SetWidth(190)
		colorText(f.authorText, STYLE.LINK_BLUE)
		return
	end

	local status, isFriend = self:GetAuthorPresence()
	f.authorStatus = status
	f.authorIsFriend = isFriend
	f.authorText:SetPoint("LEFT", f.authorRow.label, "RIGHT", 0, 0)
	f.authorText:SetWidth(
		190 - LAYOUT.AUTHOR_STATUS_FRAME_SIZE - LAYOUT.AUTHOR_STATUS_GAP)
	colorText(f.authorText, STYLE.LINK_BLUE)
	local authorNameWidth = math.min(
		190 - LAYOUT.AUTHOR_STATUS_FRAME_SIZE - LAYOUT.AUTHOR_STATUS_GAP,
		math.ceil(getTextWidth(f.authorText, 130)))
	f.authorStatusFrame:ClearAllPoints()
	f.authorStatusFrame:SetPoint(
		"LEFT", f.authorText, "LEFT",
		authorNameWidth + LAYOUT.AUTHOR_STATUS_GAP, LAYOUT.AUTHOR_STATUS_FRAME_Y)
	f.authorStatusIcon:SetAtlas(
		AUTHOR_STATUS_ATLASES[status] or AUTHOR_STATUS_ATLASES.unknown,
		false)
	f.authorStatusDots:SetShown(status == "unknown")
	f.authorStatusFrame:Show()
	f.authorContactButton:Show()
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

local function refreshContent(f)
	local L = GF.L or {}
	local addonVersion = getAddonVersion()
	if f.titleText then
		f.titleText:SetText(L.USAGE_GUIDE_TITLE or "Addon details")
	end
	refreshBrandHeader(f)
	f.introText:SetText(L.USAGE_DETAIL_INTRO_TEXT or "")
	f.command:SetText(L.USAGE_DETAIL_SHORTCUT_TEXT or "/gf")
	f.commandTitle:SetText(L.USAGE_DETAIL_SHORTCUT_TITLE or "Slash Commands")
	f.versionLabel:SetText((L.USAGE_DETAIL_LATEST_VERSION_TITLE or L.USAGE_DETAIL_VERSION_TITLE or "Version") .. ":")
	f.versionText:SetText(addonVersion)
	colorText(f.versionText, STYLE.LINK_BLUE)
	f.authorLabel:SetText((L.USAGE_DETAIL_AUTHOR_TITLE or "Addon author") .. ":")
	f.feedbackLabel:SetText((L.USAGE_DETAIL_FEEDBACK_TITLE or "Community") .. ":")
	f.feedbackText:SetText(L.USAGE_DETAIL_FEEDBACK_TEXT or "")
	f.homepageLabel:SetText((L.USAGE_DETAIL_HOMEPAGE_TITLE or "Homepage") .. ":")
	f.homepageText:SetText(L.USAGE_DETAIL_HOMEPAGE_TEXT or "")
	UGD:RefreshAuthorContact(f)
	refreshNoticeContent(f)
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
		main:HideFrame()
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

local function createInfoPair(parent, point, relTo, relPoint, x, y)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint(point, relTo, relPoint, x, y)
	row:SetSize(280, 24)
	row.label =
		createText(
			row,
			"GameFontNormal",
			STYLE.FONT_INFO_TEXT,
			STYLE.MAIN_GOLD,
			"")
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetSize(82, 20)
	row.label:SetJustifyH("LEFT")
	row.value =
		createText(
			row,
			"GameFontHighlight",
			STYLE.FONT_INFO_TEXT,
			STYLE.BODY_TEXT,
			"")
	row.value:SetPoint("LEFT", row.label, "RIGHT", 0, 0)
	row.value:SetSize(190, 20)
	row.value:SetJustifyH("LEFT")
	return row
end

local function createBrandHeader(f)
	f.content = CreateFrame("Frame", nil, f)
	f.content:SetPoint(
		"TOPLEFT",
		f,
		"TOPLEFT",
		LAYOUT.BODY_LEFT,
		LAYOUT.BODY_TOP)
	f.content:SetSize(LAYOUT.CONTENT_W, LAYOUT.CONTENT_H)
	f.content:SetFrameLevel(f:GetFrameLevel() + 5)

	f.titleText = f.systemTitleText

	f.titleAtlas = createSlicedAtlas(
		f.content,
		LAYOUT.TITLE_ATLAS_REGION,
		{
		left = 30,
		right = 52,
		top = 4,
		bottom = 7,
		scale = 0.5,
		},
		"ARTWORK",
		0)
	f.titleAtlas:SetFrameLevel(f.content:GetFrameLevel() + 1)
	f.titleAtlas:SetPoint(
		"TOPLEFT",
		f.content,
		"TOPLEFT",
		LAYOUT.TITLE_BAND_INSET_X,
		LAYOUT.TITLE_BAND_TOP_Y)
	f.titleAtlas:SetPoint(
		"TOPRIGHT",
		f.content,
		"TOPRIGHT",
		-LAYOUT.TITLE_BAND_INSET_X,
		LAYOUT.TITLE_BAND_TOP_Y)
	f.titleAtlas:SetHeight(LAYOUT.TITLE_BAND_H)

	f.logoFrame = CreateFrame("Frame", nil, f.content)
	f.logoFrame:SetFrameLevel(f.content:GetFrameLevel() + 20)
	f.logoFrame:SetSize(LAYOUT.LOGO_SIZE, LAYOUT.LOGO_SIZE)
	f.logoFrame:SetPoint("CENTER", f.titleAtlas, "TOP", 0, -1)
	f.logo = f.logoFrame:CreateTexture(nil, "OVERLAY", nil, 7)
	f.logo:SetTexture(
		GF.ADDON_MENU_LOGO_TEXTURE or LAYOUT.LOGO_TEXTURE)
	f.logo:SetAllPoints(f.logoFrame)

	f.brandLine = CreateFrame("Frame", nil, f.content)
	f.brandLine:SetPoint(
		"TOP",
		f.titleAtlas,
		"TOP",
		0,
		LAYOUT.BRAND_TOP)
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
	f.noticeBox = createSlicedAtlas(
		f.content,
		LAYOUT.INFO_BOX_REGION,
		{
		left = 18,
		right = 18,
		top = 18,
		bottom = 18,
		scale = 0.3,
		},
		"BACKGROUND",
		0)
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
end

local function createUserLetterButton(f)
	local close = f.ClosePanelButton or f.CloseButton
	local button = CreateFrame("Button", "GroupFinderAddonAboutLetterButton", f)
	f.LetterButton = button
	button:SetSize(close:GetWidth(), close:GetHeight())
	button:SetPoint("RIGHT", close, "LEFT", -(GF.TITLE_ACTION_BUTTON_GAP or 2), 0)
	button:SetFrameLevel(close:GetFrameLevel())
	button:RegisterForClicks("LeftButtonUp")
	button:SetNormalAtlas(GF.TITLE_LETTER_BUTTON_ICON_ATLAS)
	button:SetHighlightAtlas(GF.TITLE_LETTER_BUTTON_ICON_ATLAS, "ADD")
	button:SetPushedAtlas(GF.TITLE_LETTER_BUTTON_ICON_ATLAS)
	local normal = button:GetNormalTexture()
	local highlight = button:GetHighlightTexture()
	local pushed = button:GetPushedTexture()
	for _, texture in ipairs({ normal, highlight, pushed }) do
		texture:ClearAllPoints()
		GF.UI.SetAtlasFit(texture, GF.TITLE_LETTER_BUTTON_ICON_ATLAS,
			button:GetWidth(), GF.TITLE_LETTER_BUTTON_ICON_SIZE)
		texture:SetPoint("CENTER", button, "CENTER", 0, 0)
	end
	highlight:SetAlpha(0.35)
	pushed:ClearAllPoints()
	pushed:SetPoint("CENTER", button, "CENTER", 1, -1)
	local function hideTooltip()
		if GameTooltip and GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end
	button:SetScript("OnClick", function()
		hideTooltip()
		UGD:OpenUserLetter()
	end)
	button:SetScript("OnEnter", function()
		if not GameTooltip then return end
		GF.UI.BeginGameTooltipAbove(button)
		GameTooltip:SetText(GF.UserLetter.TITLE, 1, 0.82, 0)
		GF.UI.ShowGameTooltip(GameTooltip)
	end)
	button:SetScript("OnLeave", hideTooltip)
	button:SetScript("OnHide", hideTooltip)
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
		height = LAYOUT.DIALOG_H,
		title = L.USAGE_GUIDE_TITLE or "Addon details",
		levelOffset = 5,
		onClose = function()
			UGD:Hide()
		end,
	}
	local f = GF.UI.CreateSatelliteSettingsFrame(frameOptions)
	applyDialogBackground(f)
	showSystemTitle(f)
	createUserLetterButton(f)
	f:HookScript("OnHide", function()
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

	createBrandHeader(f)

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
		-LAYOUT.TITLE_DESC_GAP)
	f.introText:SetSize(LAYOUT.INTRO_W, 44)
	f.introText:SetJustifyH("CENTER")
	f.introText:SetWordWrap(true)
	if f.introText.SetSpacing then
		f.introText:SetSpacing(3)
	end

	f.command =
		createText(
			f.content,
			"GameFontHighlightLarge",
			STYLE.FONT_COMMAND_TEXT,
			STYLE.LINK_BLUE,
			"")
	f.command:SetPoint(
		"TOP",
		f.titleAtlas,
		"BOTTOM",
		0,
		-LAYOUT.COMMAND_TOP_GAP)
	f.command:SetSize(LAYOUT.CONTENT_W, 28)
	f.command:SetJustifyH("CENTER")
	f.commandTitle =
		createText(
			f.content,
			"GameFontNormalLarge",
			STYLE.FONT_COMMAND_TITLE,
			STYLE.MAIN_GOLD,
			"OUTLINE")
	f.commandTitle:SetPoint("TOP", f.command, "BOTTOM", 0, -8)
	f.commandTitle:SetSize(LAYOUT.CONTENT_W, 26)
	f.commandTitle:SetJustifyH("CENTER")

	f.versionRow =
		createInfoPair(
			f.content,
			"TOPLEFT",
			f.commandTitle,
			"BOTTOMLEFT",
			LAYOUT.INFO_LEFT_X,
			-LAYOUT.INFO_TOP_GAP)
	f.authorRow = createInfoPair(f.content, "TOPLEFT", f.versionRow, "BOTTOMLEFT", 0, -10)
	f.feedbackRow =
		createInfoPair(
			f.content,
			"TOPLEFT",
			f.commandTitle,
			"BOTTOMLEFT",
			LAYOUT.INFO_RIGHT_X,
			-LAYOUT.INFO_TOP_GAP)
	f.homepageRow = createInfoPair(f.content, "TOPLEFT", f.feedbackRow, "BOTTOMLEFT", 0, -10)

	f.versionLabel = f.versionRow.label
	f.versionText = f.versionRow.value
	f.authorLabel = f.authorRow.label
	f.authorText = f.authorRow.value
	f.feedbackLabel = f.feedbackRow.label
	f.feedbackText = f.feedbackRow.value
	f.homepageLabel = f.homepageRow.label
	f.homepageText = f.homepageRow.value
	f.authorStatusFrame = CreateFrame("Frame", nil, f.authorRow)
	f.authorStatusFrame:SetSize(
		LAYOUT.AUTHOR_STATUS_FRAME_SIZE, LAYOUT.AUTHOR_STATUS_FRAME_SIZE)
	f.authorStatusFrame:EnableMouse(false)
	f.authorContactButton = CreateFrame("Button", nil, f.authorStatusFrame)
	f.authorContactButton:SetAllPoints(f.authorStatusFrame)
	f.authorContactButton:SetNormalAtlas(AUTHOR_STATUS_FRAME_ATLAS)
	f.authorContactButton:SetPushedAtlas(AUTHOR_STATUS_PRESSED_ATLAS)
	f.authorContactButton:SetHighlightAtlas(AUTHOR_STATUS_FRAME_ATLAS, "ADD")
	f.authorStatusIcon = f.authorContactButton:CreateTexture(nil, "OVERLAY")
	f.authorStatusIcon:SetPoint("CENTER", f.authorStatusFrame, "CENTER", 0, 0)
	f.authorStatusIcon:SetSize(
		LAYOUT.AUTHOR_STATUS_ICON_SIZE, LAYOUT.AUTHOR_STATUS_ICON_SIZE)
	f.authorStatusDots = CreateFrame(
		"Frame", nil, f.authorContactButton, "VoiceChatDotsTemplate")
	f.authorStatusDots:SetAllPoints(f.authorStatusIcon)
	f.authorStatusDots:EnableMouse(false)
	f.authorStatusDots:Hide()
	f.authorStatusDots:HookScript("OnShow", function(dots)
		dots:PlayAnimation()
	end)
	f.authorStatusDots:HookScript("OnHide", function(dots)
		dots:StopAnimation()
	end)
	f.authorStatusFrame:Hide()
	f.authorContactButton:RegisterForClicks("LeftButtonUp")
	f.authorContactButton:SetScript("OnClick", function()
		GF.UI.PlayUISound("check")
		UGD:ContactAuthor()
	end)
	local function refreshAuthorTooltip(button)
		UGD:RefreshAuthorContact(f)
		if not GameTooltip then
			return
		end
		local tooltipLocale = GF.L or {}
		local statusKey = f.authorStatus == "online"
			and "USAGE_DETAIL_AUTHOR_STATUS_ONLINE"
			or f.authorStatus == "offline"
				and "USAGE_DETAIL_AUTHOR_STATUS_OFFLINE"
				or "USAGE_DETAIL_AUTHOR_STATUS_UNKNOWN"
		local statusText = tooltipLocale[statusKey] or f.authorStatus or "unknown"
		local statusColor = AUTHOR_STATUS_VALUE_COLORS[f.authorStatus]
			or AUTHOR_STATUS_VALUE_COLORS.unknown
		GF.UI.BeginGameTooltip(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(
			tooltipLocale.USAGE_DETAIL_AUTHOR_CONTACT_TITLE or "Contact author",
			1, 0.82, 0)
		GameTooltip:AddDoubleLine(
			UGD.AUTHOR_WHISPER_TARGET,
			statusText,
			STYLE.LINK_BLUE[1],
			STYLE.LINK_BLUE[2],
			STYLE.LINK_BLUE[3],
			statusColor[1],
			statusColor[2],
			statusColor[3])
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(
			UGD:GetAuthorContactHint(f.authorIsFriend),
			STYLE.MAIN_GOLD[1], STYLE.MAIN_GOLD[2], STYLE.MAIN_GOLD[3], true)
		GF.UI.ShowGameTooltip(GameTooltip)
	end
	f.authorContactButton:SetScript("OnEnter", refreshAuthorTooltip)
	f.authorContactButton:SetScript("OnLeave", function()
		colorText(f.authorText, STYLE.LINK_BLUE)
		if GameTooltip and GameTooltip:IsOwned(f.authorContactButton) then
			GameTooltip:Hide()
		end
	end)
	-- Use the same icon displacement as Blizzard's social action buttons.
	Mixin(f.authorContactButton, ButtonStateBehaviorMixin)
	f.authorContactButton:SetDisplacedRegions(1, -1, f.authorStatusIcon)
	for _, script in ipairs({ "OnEnter", "OnLeave", "OnShow", "OnEnable", "OnDisable" }) do
		f.authorContactButton:HookScript(script, ButtonStateBehaviorMixin[script])
	end
	f.authorContactButton:HookScript("OnMouseDown", function(button, mouseButton)
		if mouseButton == "LeftButton" and not button:IsDown() then
			ButtonStateBehaviorMixin.OnMouseDown(button)
		end
	end)
	f.authorContactButton:HookScript("OnMouseUp", function(button, mouseButton)
		if mouseButton == "LeftButton" and button:IsDown() then
			ButtonStateBehaviorMixin.OnMouseUp(button)
		end
	end)
	f.authorContactButton:HookScript("OnHide", function(button)
		ButtonStateBehaviorMixin.OnDisable(button)
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
	colorText(f.feedbackText, STYLE.LINK_BLUE)
	colorText(f.homepageText, STYLE.LINK_BLUE)

	createNoticeBox(f)

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
	f.footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
	f.footer:SetSize(LAYOUT.CONTENT_W, 16)
	f.footer:SetJustifyH("CENTER")

	UGD.frame = f
	refreshContent(f)
	return f
end

function UGD:Hide()
	local frame = self.frame
	if frame and frame.Hide then
		frame:Hide()
	end
end

function UGD:OpenUserLetter()
	if not GF.UserLetterDialog:Show() then return false end
	-- This handoff must not restore the main window when About closes.
	self._restoreMainFrame = nil
	self:Hide()
	local main = GF.MainFrame
	if main then
		if main.HideFrame then
			main:HideFrame()
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
		self.frame:Hide()
	end
end

function UGD:Show()
	local L = GF.L or {}
	local f = ensureFrame()
	if f:IsShown() then
		refreshContent(f)
		return
	end
	GF.UI.ApplySettingsFrameChrome(f, L.USAGE_GUIDE_TITLE or "Addon details")
	showSystemTitle(f)
	applyDialogBackground(f)
	refreshContent(f)
	GF.UI.CenterOnMainFrame(f, 0)
	hideMainFrameForDialog()
	f:Show()
	self._shown = true
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
	applyDialogBackground(f)
	showSystemTitle(f)
	createBrandHeader(f)
	createNoticeBox(f)
	f.letterWaxSeal = f.noticeBody:CreateTexture(nil, "ARTWORK")
	f.letterWaxSeal:Hide()
	-- Keep the brand and letter inside the same pair of gold rules.
	-- The lower rule sits below the reading area, above the fixed button.
	f.titleAtlas:SetHeight(LAYOUT.CONTENT_H + LAYOUT.TITLE_BAND_TOP_Y - 32)
	f.noticeBox:SetFrameLevel(f.titleAtlas:GetFrameLevel() + 1)
	f.noticeBox:ClearAllPoints()
	f.noticeBox:SetPoint("TOPLEFT", f.content, "TOPLEFT",
		LAYOUT.INFO_BOX_INSET_X + LAYOUT.INFO_BOX_OFFSET_X,
		LAYOUT.TITLE_BAND_TOP_Y + LAYOUT.BRAND_TOP - 42 - LAYOUT.TITLE_DESC_GAP)
	f.noticeBox:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT",
		-LAYOUT.INFO_BOX_INSET_X + LAYOUT.INFO_BOX_OFFSET_X, 48)
	f.readButton = GF.UI.CreatePanelButton(f, "", 120)
	f.readButton:SetHeight(28)
	f.readButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
	return f
end

function UGD:RefreshUserLetterFrame(f)
	GF.UI.ApplySettingsFrameChrome(f, GF.UserLetter.TITLE)
	showSystemTitle(f)
	applyDialogBackground(f)
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
