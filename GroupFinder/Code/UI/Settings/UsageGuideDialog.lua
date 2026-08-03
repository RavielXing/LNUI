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
	TITLE_DESC_GAP = 12,
	INTRO_W = 548,
	INFO_BOX_H = 200,
	INFO_BOX_INSET_X = 24,
	INFO_BOX_OFFSET_X = 3,
	INFO_BOX_BOTTOM_Y = 38,
	NOTICE_SCROLL_INSET_L = 24,
	NOTICE_SCROLL_INSET_R = 32,
	NOTICE_SCROLL_INSET_T = 22,
	NOTICE_SCROLL_INSET_B = 18,
	NOTICE_SCROLLBAR_GAP = 2,
	NOTICE_SCROLLBAR_W = 8,
	NOTICE_TITLE_GAP = 12,
	NOTICE_VERSION_GAP = 8,
	NOTICE_LINE_GAP = 6,
	NOTICE_SECTION_GAP = 12,
	NOTICE_RULE_GAP = 8,
	NOTICE_RULE_ATLAS = "Options_HorizontalDivider",
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
		"COPYRIGHT (C) 2026 GAICAS.COM ALL RIGHTS RESERVED.",
	MAIN_GOLD = { 1, 0.82, 0, 1 },
	BODY_TEXT = { 238 / 255, 228 / 255, 205 / 255, 1 },
	LINK_BLUE = { 130 / 255, 204 / 255, 1, 1 },
	COMMAND_ORANGE = { 1, 0.45, 0.16, 1 },
	FOOTER_GRAY = { 0.5, 0.5, 0.5, 1 },
	NOTICE_GRAY = { 0.42, 0.42, 0.42, 1 },
	FONT_BRAND_TITLE = 30,
	FONT_VERSION_INLINE = 12,
	FONT_DESCRIPTION_TEXT = 14,
	FONT_COMMAND_TEXT = 20,
	FONT_COMMAND_TITLE = 18,
	FONT_INFO_TEXT = 15,
	FONT_NOTICE_TEXT = 13,
	FONT_NOTICE_TITLE = 18,
	FONT_NOTICE_VERSION = 16,
	FONT_FOOTER_TEXT = 12,
}

local NOTICE_HANGING_PREFIXES = {
	"新增：",
	"优化：",
	"重构：",
	"修复：",
	"适配：",
	"调整：",
	"致谢：",
	"致謝：",
	"優化：",
	"最佳化：",
	"重構：",
	"修復：",
	"修正：",
	"適配：",
	"相容性：",
	"調整：",
	"New:",
	"Improved:",
	"Refactored:",
	"Fixed:",
	"Compatibility:",
	"Thanks:",
	"Adjusted:",
}

local function getAddonVersion()
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
	return "2.0.1"
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

local function splitNoticeBodyLine(text)
	if type(text) ~= "string" or text == "" then
		return nil, nil
	end
	for _, prefix in ipairs(NOTICE_HANGING_PREFIXES) do
		if text:sub(1, #prefix) == prefix then
			local body = text:sub(#prefix + 1)
			while body:sub(1, 1) == " " do
				body = body:sub(2)
			end
			if body == "" then
				return nil, nil
			end
			return prefix, body
		end
	end
	return nil, nil
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
	local versionW = math.ceil(getTextWidth(f.versionInline, 36))
	f.brandLine:SetSize(LAYOUT.CONTENT_W, 42)
	f.brandTitle:SetWidth(titleW + 8)
	f.brandTitle:ClearAllPoints()
	f.brandTitle:SetPoint("CENTER", f.brandLine, "CENTER", 0, 0)
	f.versionInline:SetWidth(versionW + 8)
	f.versionInline:ClearAllPoints()
	f.versionInline:SetPoint("BOTTOMLEFT", f.brandTitle, "BOTTOMRIGHT", 4, 6)
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
				if row.text then
					row.text:Hide()
				end
				if row.prefix then
					row.prefix:Hide()
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
	if row.prefix then
		row.prefix:Hide()
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
	fs:SetWordWrap(true)
	fs:Show()
	return fs
end

local function acquireNoticeHangingText(f, index, template, size, color, flags)
	local row = ensureNoticeRow(f, index)
	if row.text then
		row.text:Hide()
	end
	if not row.prefix then
		row.prefix = createText(f.noticeBody, template, size, color, flags)
	else
		row.prefix:SetParent(f.noticeBody)
		setFont(row.prefix, template or "GameFontHighlight", size or 12, flags or "")
		colorText(row.prefix, color or STYLE.BODY_TEXT)
	end
	if not row.body then
		row.body = createText(f.noticeBody, template, size, color, flags)
	else
		row.body:SetParent(f.noticeBody)
		setFont(row.body, template or "GameFontHighlight", size or 12, flags or "")
		colorText(row.body, color or STYLE.BODY_TEXT)
	end
	row.prefix:ClearAllPoints()
	row.prefix:SetJustifyH("LEFT")
	row.prefix:SetWordWrap(false)
	row.prefix:Show()
	row.body:ClearAllPoints()
	row.body:SetJustifyH("LEFT")
	row.body:SetWordWrap(true)
	row.body:Show()
	return row.prefix, row.body
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

local function addNoticeHangingLine(f, index, y, prefix, body, template, size, color, flags, gap)
	local prefixText, bodyText = acquireNoticeHangingText(f, index, template, size, color, flags)
	prefixText:SetText(prefix or "")
	bodyText:SetText(body or "")
	local prefixGap = GF.USAGE_NOTICE_PREFIX_GAP or 8
	local prefixW =
		math.ceil(
			getTextWidth(
				prefixText,
				(size or STYLE.FONT_NOTICE_TEXT) * 3))
			+ prefixGap
	prefixW =
		math.min(prefixW, math.floor(LAYOUT.NOTICE_TEXT_W * 0.45))
	local bodyW = math.max(LAYOUT.NOTICE_TEXT_W - prefixW, 80)
	prefixText:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", 0, y)
	prefixText:SetWidth(prefixW)
	bodyText:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", prefixW, y)
	bodyText:SetWidth(bodyW)
	local prefixH = prefixText.GetStringHeight and prefixText:GetStringHeight() or 0
	local bodyH = bodyText.GetStringHeight and bodyText:GetStringHeight() or 0
	local height = math.max(prefixH or 0, bodyH or 0)
	if type(height) ~= "number" or height <= 0 then
		height = size or STYLE.FONT_NOTICE_TEXT
	end
	height = math.ceil(height)
	prefixText:SetHeight(height + 2)
	bodyText:SetHeight(height + 2)
	return index + 1, y - height - (gap or LAYOUT.NOTICE_LINE_GAP)
end

local function addNoticeRule(f, index, y)
	local rule = f.noticeRules and f.noticeRules[index]
	if not rule then
		f.noticeRules = f.noticeRules or {}
		rule = f.noticeBody:CreateTexture(nil, "ARTWORK")
		f.noticeRules[index] = rule
	end
	rule:ClearAllPoints()
	local atlasOK =
		rule.SetAtlas
		and pcall(rule.SetAtlas, rule, LAYOUT.NOTICE_RULE_ATLAS)
	if not atlasOK then
		rule:SetColorTexture(1, 0.82, 0, 0.35)
	end
	rule:SetVertexColor(1, 0.82, 0, 0.62)
	rule:SetPoint("TOPLEFT", f.noticeBody, "TOPLEFT", 0, y)
	rule:SetPoint("TOPRIGHT", f.noticeBody, "TOPRIGHT", 0, y)
	rule:SetHeight(2)
	rule:Show()
	return index + 1, y - LAYOUT.NOTICE_RULE_GAP
end

local function hideUnusedNoticeRules(f, startIndex)
	if not f.noticeRules then
		return
	end
	for i = startIndex, #f.noticeRules do
		f.noticeRules[i]:Hide()
	end
end

local function refreshNoticeContent(f)
	local L = GF.L or {}
	local entries = L.USAGE_DETAIL_NOTICE_ENTRIES
	if type(entries) ~= "table" or #entries == 0 then
		clearNoticeRows(f)
		hideUnusedNoticeRules(f, 1)
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
	local ruleIndex = 1
	local y = 0
	rowIndex, y = addNoticeLine(
		f,
		rowIndex,
		y,
		L.USAGE_DETAIL_NOTICE_TITLE or "Changelog:",
		"GameFontNormalLarge",
		STYLE.FONT_NOTICE_TITLE,
		STYLE.MAIN_GOLD,
		"OUTLINE",
		LAYOUT.NOTICE_TITLE_GAP,
		"CENTER"
	)
	ruleIndex, y = addNoticeRule(f, ruleIndex, y)
	y = y - LAYOUT.NOTICE_SECTION_GAP

	for entryIndex, entry in ipairs(entries) do
		if type(entry) == "table" then
			local version = entry.version or ""
			if version ~= "" then
				rowIndex, y = addNoticeLine(
					f,
					rowIndex,
					y,
					version,
					"GameFontNormalLarge",
					STYLE.FONT_NOTICE_VERSION,
					STYLE.MAIN_GOLD,
					"OUTLINE",
					LAYOUT.NOTICE_VERSION_GAP)
			end
			local lines = entry.lines
			if type(lines) == "table" then
				for _, line in ipairs(lines) do
					local prefix, body = splitNoticeBodyLine(line)
					if prefix and body then
						rowIndex, y = addNoticeHangingLine(
							f,
							rowIndex,
							y,
							prefix,
							body,
							"GameFontHighlight",
							STYLE.FONT_NOTICE_TEXT,
							STYLE.BODY_TEXT,
							"",
							LAYOUT.NOTICE_LINE_GAP
						)
					else
						rowIndex, y = addNoticeLine(
							f,
							rowIndex,
							y,
							line,
							"GameFontHighlight",
							STYLE.FONT_NOTICE_TEXT,
							STYLE.BODY_TEXT,
							"",
							LAYOUT.NOTICE_LINE_GAP)
					end
				end
			end
			if entryIndex < #entries then
				y = y - LAYOUT.NOTICE_SECTION_GAP
				ruleIndex, y = addNoticeRule(f, ruleIndex, y)
				y = y - LAYOUT.NOTICE_SECTION_GAP
			end
		end
	end

	hideUnusedNoticeRules(f, ruleIndex)
	local contentH =
		math.max(
			LAYOUT.NOTICE_SCROLL_H,
			math.ceil(-y + LAYOUT.NOTICE_SCROLL_INSET_B))
	f.noticeBody:SetSize(LAYOUT.NOTICE_TEXT_W, contentH)
	if f.noticeScroll.SetVerticalScroll then
		f.noticeScroll:SetVerticalScroll(0)
	end
	GF.UI.UpdateScrollFrame(f.noticeScroll)
end

local function refreshContent(f)
	local L = GF.L or {}
	local addonVersion = getAddonVersion()
	local addonName = L.ADDON_NAME or "GroupFinder"

	if f.titleText then
		f.titleText:SetText(L.USAGE_GUIDE_TITLE or "Addon details")
	end
	f.brandTitle:SetText(addonName)
	f.versionInline:SetText(addonVersion)
	f.introText:SetText(L.USAGE_DETAIL_INTRO_TEXT or "")
	f.command:SetText(L.USAGE_DETAIL_SHORTCUT_TEXT or "/gf")
	f.commandTitle:SetText(L.USAGE_DETAIL_SHORTCUT_TITLE or "Slash Commands")
	f.versionLabel:SetText((L.USAGE_DETAIL_LATEST_VERSION_TITLE or L.USAGE_DETAIL_VERSION_TITLE or "Version") .. ":")
	f.versionText:SetText(addonVersion)
	f.authorLabel:SetText((L.USAGE_DETAIL_AUTHOR_TITLE or "Author") .. ":")
	f.authorText:SetText(L.USAGE_DETAIL_AUTHOR_TEXT or "")
	f.feedbackLabel:SetText((L.USAGE_DETAIL_FEEDBACK_TITLE or "Beta Co-creation") .. ":")
	f.feedbackText:SetText(L.USAGE_DETAIL_FEEDBACK_TEXT or "")
	f.homepageLabel:SetText((L.USAGE_DETAIL_HOMEPAGE_TITLE or "Homepage") .. ":")
	f.homepageText:SetText(L.USAGE_DETAIL_HOMEPAGE_TEXT or "")
	refreshNoticeContent(f)
	f.footer:SetText(STYLE.FOOTER_COPYRIGHT_TEXT)
	refreshBrandLayout(f)
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
	UGD._restoreMainFrame = frame and frame:IsShown() and true or false
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
	f.versionInline =
		createText(
			f.brandLine,
			"GameFontHighlight",
			STYLE.FONT_VERSION_INLINE,
			STYLE.MAIN_GOLD,
			"")
	f.versionInline:SetPoint("BOTTOMLEFT", f.brandTitle, "BOTTOMRIGHT", 4, 6)
	f.versionInline:SetSize(60, 18)
	f.versionInline:SetJustifyH("LEFT")

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
			STYLE.COMMAND_ORANGE,
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
	colorText(f.feedbackText, STYLE.LINK_BLUE)
	colorText(f.homepageText, STYLE.LINK_BLUE)

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

	refreshContent(f)

	UGD.frame = f
	return f
end

function UGD:Hide()
	local frame = self.frame
	if frame and frame.Hide then
		frame:Hide()
	end
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
