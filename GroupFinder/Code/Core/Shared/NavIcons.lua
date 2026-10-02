local _, GF = ...

-- 导航节点与展开按钮图标；保留 GF.Icons 公共命名空间。
GF.Icons = {}

local NAV_CARD_NORMAL_ATLAS = "transmog-outfit-card"
local NAV_CARD_SELECTED_ATLAS = "transmog-outfit-card-selected"
local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE
local COMMON_BUTTON_VISUALS = GF.COMMON_BUTTON_VISUALS
local NAV_EXPANDER_SIZE = GF.COMMON_BUTTON_STYLE.iconButtonSize
local NAV_EXPANDER_PLUS_W = GF.COMMON_BUTTON_STYLE.iconSize
local NAV_EXPANDER_PLUS_H = GF.COMMON_BUTTON_STYLE.iconSize
local NAV_EXPANDER_MINUS_W = GF.COMMON_BUTTON_STYLE.iconSize
local NAV_EXPANDER_LEFT = 4
local NAV_EXPANDER_TEXT_GAP = 4
local NAV_EXPANDER_GLYPH_TEXTURE = "Interface\\QuestFrame\\QuestTracker2x"
local NAV_EXPANDER_GLYPH_ATLAS_W = 1024
local NAV_EXPANDER_GLYPH_ATLAS_H = 512
local NAV_EXPANDER_PLUS_TEXCOORD = { 985 / 1024, 1011 / 1024, 165 / 512, 191 / 512 }
local NAV_EXPANDER_MINUS_TEXCOORD = { 993 / 1024, 1019 / 1024, 71 / 512, 81 / 512 }

local function navLevel(level)
	level = tonumber(level) or 0
	if level < 0 then
		return 0
	end
	if level > 3 then
		return 3
	end
	return level
end

local function levelValue(value, level, fallback)
	if type(value) == "table" then
		local resolved = value[level]
		if resolved == nil then
			resolved = value[0]
		end
		if resolved == nil then
			resolved = fallback
		end
		return resolved
	end
	if value == nil then
		return fallback
	end
	return value
end

local function navButtonMetrics(rowW, level)
	rowW = math.max(tonumber(rowW) or 1, 1)
	level = navLevel(level)
	local widthPad = levelValue(GF.NAV_TRANSMOG_BUTTON_WIDTH_PAD, level, 0)
	local buttonW = math.max(rowW - widthPad, 1)
	buttonW = math.min(buttonW, rowW)
	local buttonH = level == 0 and (GF.NAV_L0_BUTTON_H or 43) or levelValue(GF.NAV_TRANSMOG_BUTTON_H, level, 43)
	local offsetX = tonumber(GF.NAV_TRANSMOG_BUTTON_OFFSET_X) or 0
	local buttonX = math.floor(((rowW - buttonW) * 0.5) + offsetX + 0.5)
	return buttonX, buttonW, buttonH
end

local function setAtlas(texture, atlas)
	if not texture or not texture.SetAtlas then
		return false
	end
	local ok = pcall(texture.SetAtlas, texture, atlas, false)
	if not ok then
		ok = pcall(texture.SetAtlas, texture, atlas)
	end
	return ok
end

local function setupCardTexture(texture, atlas, blendMode)
	if not texture then
		return
	end
	setAtlas(texture, atlas)
	if texture.SetBlendMode then
		texture:SetBlendMode(blendMode or "BLEND")
	end
	texture:SetVertexColor(1, 1, 1, 1)
end

local function layoutCardTexture(texture, row, x, width, height)
	if not texture or not row then
		return
	end
	texture:ClearAllPoints()
	texture:SetPoint("LEFT", row, "LEFT", x or 0, 0)
	texture:SetSize(math.max(width or 1, 1), math.max(height or 1, 1))
end

local function setDesaturated(texture, desaturated)
	if texture and texture.SetDesaturated then
		texture:SetDesaturated(desaturated == true)
	end
end

local function ensureNavLeadingIcon(row)
	if not row then
		return nil
	end
	if not row.navLeadingIcon then
		row.navLeadingIcon = row:CreateTexture(nil, "OVERLAY", nil, 6)
		row.navLeadingIcon:Hide()
	end
	return row.navLeadingIcon
end

local function navTextColor(row, disabled, selected, hover, dimmed)
	if disabled then
		return unpack(COMMON_BUTTON_VISUALS[BUTTON_VISUAL_STATE.DISABLED].textColor)
	end
	if (row and row._navPressed) or selected then
		return 1, 1, 1, 1
	end
	if hover then
		return unpack(COMMON_BUTTON_VISUALS[BUTTON_VISUAL_STATE.HOVER].textColor)
	end
	if dimmed then
		return 0.48, 0.48, 0.48, 1
	end
	return unpack(COMMON_BUTTON_VISUALS[BUTTON_VISUAL_STATE.NORMAL].textColor)
end

local function setNavExpanderBackgroundState(texture, visualState)
	GF.UI.SetCommonSmallButtonVisualState(texture, visualState)
end

local function setNavExpanderGlyphTexCoord(texture, coords)
	if not texture or not coords then
		return
	end
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

local function getNavExpanderGlyphHeight(width, coords)
	local coordW = coords and ((coords[2] - coords[1]) * NAV_EXPANDER_GLYPH_ATLAS_W) or 0
	local coordH = coords and ((coords[4] - coords[3]) * NAV_EXPANDER_GLYPH_ATLAS_H) or 0
	if coordW <= 0 or coordH <= 0 then
		return width
	end
	return width * (coordH / coordW)
end

local function setupNavExpander(row)
	if not row or not row.expander then
		return
	end
	if not row.expanderGlyph then
		row.expanderGlyph = row:CreateTexture(nil, "OVERLAY", nil, 5)
	end
	if not row._gfSmallExpander then
		row.expander:Hide()
		row.expander = CreateFrame("Button", nil, row)
		row.expander:SetFrameLevel(row:GetFrameLevel())
		row.expander:SetSize(NAV_EXPANDER_SIZE, NAV_EXPANDER_SIZE)
		local skin = GF.UI.ApplyCommonSmallButtonSkin(row.expander, row.expanderGlyph, { transitionDuration = 0 })
		skin.background:SetDrawLayer("OVERLAY", 3)
		row.expander:EnableMouse(false)
		row.expander:SetMotionScriptsWhileDisabled(false)
		row._gfSmallExpander = true
	end
	setNavExpanderBackgroundState(row.expander, BUTTON_VISUAL_STATE.NORMAL)
	row.expander:SetShown(false)
	row.expanderGlyph:SetTexture(NAV_EXPANDER_GLYPH_TEXTURE)
	setNavExpanderGlyphTexCoord(row.expanderGlyph, NAV_EXPANDER_PLUS_TEXCOORD)
	if row.expanderGlyph.SetBlendMode then
		row.expanderGlyph:SetBlendMode("BLEND")
	end
	row.expanderGlyph:SetVertexColor(1, 1, 1, 1)
	row.expanderGlyph:SetShown(false)
	if row.expanderSign then
		row.expanderSign:Hide()
	end
end

local function applyNavExpander(row)
	if not row or not row.expander then
		return
	end
	if not row._navCanExpand then
		row.expander:Hide()
		if row.expanderGlyph then
			row.expanderGlyph:Hide()
		end
		if row.expanderHighlight then
			row.expanderHighlight:Hide()
		end
		if row.expanderSign then
			row.expanderSign:Hide()
		end
		return
	end
	local disabled = row.nodeData and row.nodeData.disabled
	local selected = row._navSelected and not disabled
	local pressed = row._navPressed and not disabled
	local hover = row._navHover and not disabled
	local dimmed = row._navDimmed and not selected and not pressed and not disabled
	local bgState = disabled and BUTTON_VISUAL_STATE.DISABLED
		or (pressed and BUTTON_VISUAL_STATE.PRESSED)
		or (hover and BUTTON_VISUAL_STATE.HOVER)
		or BUTTON_VISUAL_STATE.NORMAL
	local glyphTexCoord
	local glyphW
	local glyphH
	if row._navExpanded then
		glyphTexCoord = NAV_EXPANDER_MINUS_TEXCOORD
		glyphW = NAV_EXPANDER_MINUS_W
		glyphH = getNavExpanderGlyphHeight(glyphW, glyphTexCoord)
	else
		glyphTexCoord = NAV_EXPANDER_PLUS_TEXCOORD
		glyphW = NAV_EXPANDER_PLUS_W
		glyphH = NAV_EXPANDER_PLUS_H
	end
	local background = row.expander._gfCommonTitleButtonSkin.background
	setDesaturated(background, dimmed and not hover)
	if dimmed and not hover then
		background:SetVertexColor(0.58, 0.58, 0.58, 1)
	else
		background:SetVertexColor(1, 1, 1, 1)
	end
	if row.expanderGlyph then
		local r, g, b, a = navTextColor(row, disabled, selected, hover, dimmed)
		row.expanderGlyph:SetTexture(NAV_EXPANDER_GLYPH_TEXTURE)
		setNavExpanderGlyphTexCoord(row.expanderGlyph, glyphTexCoord)
		row.expanderGlyph:ClearAllPoints()
		row.expanderGlyph:SetPoint("CENTER", row.expander, "CENTER", 0, 0)
		row.expanderGlyph:SetSize(glyphW, glyphH)
		setDesaturated(row.expanderGlyph, dimmed and not hover)
		row.expanderGlyph:SetVertexColor(r, g, b, a)
		row.expanderGlyph:SetShown(true)
	end
	if row.expanderHighlight then
		row.expanderHighlight:ClearAllPoints()
		row.expanderHighlight:SetPoint("CENTER", row.expander, "CENTER", 0, 0)
		row.expanderHighlight:SetSize(NAV_EXPANDER_SIZE, NAV_EXPANDER_SIZE)
		row.expanderHighlight:SetShown(row._navHover and not disabled)
	end
	if row.expanderSign then
		row.expanderSign:Hide()
	end
	local skin = row.expander._gfCommonTitleButtonSkin
	skin.iconWidth, skin.iconHeight = glyphW, glyphH
	row.expander:Show()
	setNavExpanderBackgroundState(row.expander, bgState)
end

local function ensureNavTextureSetup(row)
	if not row then
		return
	end
	if not row._gfTransmogNavTextures then
		setupCardTexture(row.bg, NAV_CARD_NORMAL_ATLAS)
		setupCardTexture(row.hover, NAV_CARD_NORMAL_ATLAS, "ADD")
		setupCardTexture(row.sel, NAV_CARD_SELECTED_ATLAS)
		if row.cover then
			row.cover:Hide()
		end
		if row.expander then
			row.expander:Hide()
			setupNavExpander(row)
		end
		row._gfTransmogNavTextures = true
	end
	local w = row._navWidth or row:GetWidth() or 1
	local buttonX, buttonW, buttonH = navButtonMetrics(w, row._navLevel or 0)
	row._navButtonX = buttonX
	row._navButtonW = buttonW
	row._navButtonH = buttonH
	layoutCardTexture(row.bg, row, buttonX, buttonW, buttonH)
	layoutCardTexture(row.hover, row, buttonX, buttonW, buttonH)
	layoutCardTexture(row.sel, row, buttonX, buttonW, buttonH)
	if row.bg then
		row.bg:Show()
	end
	if row.cover then
		row.cover:Hide()
	end
	if row.expander then
		row.expander:Hide()
		if row.expanderGlyph then
			row.expanderGlyph:Hide()
		end
		if row.expanderHighlight then
			row.expanderHighlight:Hide()
		end
		if row.expanderSign then
			row.expanderSign:Hide()
		end
	end
end

function GF.Icons.ApplyNavButtonState(row)
	if not row or not row.bg then
		return
	end
	ensureNavTextureSetup(row)
	local disabled = row.nodeData and row.nodeData.disabled
	local selected = row._navSelected and not disabled
	local pressed = row._navPressed and not disabled
	local hover = row._navHover and not disabled
	local dimmed = row._navDimmed and not selected and not disabled
	if row.bg then
		setDesaturated(row.bg, false)
		row.bg:SetVertexColor(1, 1, 1, 1)
		row.bg:SetAlpha((disabled and 0.35) or 1)
		row.bg:Show()
	end
	if row.hover then
		setDesaturated(row.hover, false)
		row.hover:SetVertexColor(1, 1, 1, 1)
		row.hover:SetAlpha(hover and not pressed and 0.8 or 0)
		row.hover:SetShown(hover and not pressed)
	end
	if row.sel then
		setDesaturated(row.sel, false)
		row.sel:SetVertexColor(1, 1, 1, 1)
		row.sel:SetAlpha((selected and 1) or (pressed and 0.82) or 0)
		row.sel:SetShown(selected or pressed)
	end
	if row.cover then
		row.cover:SetAlpha(0)
		row.cover:Hide()
	end
	applyNavExpander(row)
	local textR, textG, textB, textA = navTextColor(
		row, disabled, selected, hover, dimmed)
	if row.label then
		row.label:SetTextColor(textR, textG, textB, textA)
	end
	if row.navLeadingIcon and row.navLeadingIcon:IsShown() then
		setDesaturated(row.navLeadingIcon, disabled)
		row.navLeadingIcon:SetVertexColor(textR, textG, textB, textA)
	end
end

function GF.Icons.ApplyNavButton(row, level, label, rowW, rowH, opts)
	if not row then
		return
	end
	opts = opts or {}
	level = navLevel(level)
	row._navLevel = level
	row._navWidth = rowW
	row._navHeight = rowH
	row._navSelected = opts.selected == true
	row._navCanExpand = opts.canExpand == true
	row._navExpanded = opts.expanded == true
	row._navDimmed = opts.dimmed == true
	local leadingIcon = ensureNavLeadingIcon(row)
	local hasLeadingIcon = type(opts.leadingIconAtlas) == "string"
		and opts.leadingIconAtlas ~= ""
	if leadingIcon then
		leadingIcon:ClearAllPoints()
		if hasLeadingIcon then
			leadingIcon:SetTexture(nil)
			if not setAtlas(leadingIcon, opts.leadingIconAtlas) then
				leadingIcon:SetTexture(opts.leadingIconTexture)
			end
			leadingIcon:Show()
		else
			leadingIcon:Hide()
		end
	end

	-- Install the visual child before assigning this first layout's anchors.
	if row.expander and not row._gfSmallExpander then
		setupNavExpander(row)
	end

	if row.label then
		row.label:SetText(label or "")
		row.label:ClearAllPoints()
		local buttonX, buttonW, buttonH = navButtonMetrics(rowW, level)
		local textLeft = levelValue(GF.NAV_TRANSMOG_BUTTON_TEXT_LEFT, level, 12)
		local textRight = levelValue(GF.NAV_TRANSMOG_BUTTON_TEXT_RIGHT, level, 8)
		local hasExpander = row._navCanExpand
		if hasExpander then
			if row.expander then
				row.expander:ClearAllPoints()
				row.expander:SetPoint("CENTER", row, "LEFT", buttonX + NAV_EXPANDER_LEFT + (NAV_EXPANDER_SIZE * 0.5), 0)
				row.expander:SetSize(NAV_EXPANDER_SIZE, NAV_EXPANDER_SIZE)
			end
			textLeft = math.max(textLeft, NAV_EXPANDER_LEFT + NAV_EXPANDER_SIZE + NAV_EXPANDER_TEXT_GAP)
		end
		local textInset = math.max(textLeft, textRight)
		local textRightX = buttonX + buttonW - textInset
		if hasLeadingIcon and leadingIcon then
			local iconSize = math.max(1, tonumber(opts.leadingIconSize) or 14)
			local iconGap = math.max(0, tonumber(opts.leadingIconGap) or 6)
			leadingIcon:SetSize(iconSize, iconSize)
			leadingIcon:SetPoint("LEFT", row, "LEFT", buttonX + textInset, 0)
			row.label:SetPoint("LEFT", leadingIcon, "RIGHT", iconGap, 0)
			row.label:SetPoint("RIGHT", row, "LEFT", textRightX, 0)
			row.label:SetHeight(buttonH)
		else
			local textW = math.max(buttonW - (textInset * 2), 1)
			row.label:SetSize(textW, buttonH)
			row.label:SetPoint("CENTER", row, "LEFT", buttonX + textInset + (textW * 0.5), 0)
		end
		row.label:SetJustifyH("CENTER")
		row.label:SetJustifyV("MIDDLE")
		row.label:SetWordWrap(false)
		row.label:SetShown(true)
	end

	GF.Icons.ApplyNavButtonState(row)
end
