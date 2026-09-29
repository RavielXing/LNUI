local _, GF = ...

-- Shared compatibility only: loading this module does not create frames or hooks.
local ElvUICompat = {}
GF.ElvUICompat = ElvUICompat

-- Native template offsets from GameFontNormal, before ElvUI rewrites the
-- shared Font objects. Columns: roman/russian, Chinese, Korean. See Blizzard
-- Fonts_Shared/{Shared,Mainline}/{Fonts,GameFonts,FontStyles}.xml.
local NATIVE_TEMPLATE_OFFSETS = {
	GameFontNormal = { 0, 0, 0 },
	GameFontHighlight = { 0, 0, 0 },
	GameFontDisable = { 0, 0, 0 },
	GameFontNormalSmall = { -2, 0, -1 },
	GameFontHighlightSmall = { -2, 0, -1 },
	GameFontDisableSmall = { -2, 0, -1 },
	GameFontNormalLarge = { 4, 2, 2 },
	GameFontHighlightLarge = { 4, 2, 2 },
	GameFontNormalHuge = { 8, 5, 8 },
	Fancy30Font = { 18, 15, 18 },
	QuestFont_Huge = { 6, 2, 5 },
	ChatFontNormal = { 2, -1, 1 },
	NumberFontNormal = { 2, -3, 1 },
	NumberFontNormalLarge = { 4, -1, 3 },
}

local function nativeFontColumn()
	local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
	return (locale == "zhCN" or locale == "zhTW") and 2
		or (locale == "koKR" and 3) or 1
end

function ElvUICompat.GetNativeTemplateOffset(template)
	if type(_G.ElvUI) ~= "table" then
		return nil
	end
	local offsets = NATIVE_TEMPLATE_OFFSETS[template or "GameFontNormal"]
	if not offsets then
		return nil
	end
	return offsets[nativeFontColumn()]
end

-- The native window shell did not use GF's 12px body baseline or font scaling.
-- Keep its original language-specific sizes and inherit all other font traits.
local NATIVE_NORMAL_HEIGHTS = { 12, 15, 12 }
local shellFonts = {}

local function shellFont(template)
	local offset = ElvUICompat.GetNativeTemplateOffset(template)
	local source = _G[template]
	if offset == nil or not source or type(CreateFont) ~= "function" then
		return nil
	end
	local height = NATIVE_NORMAL_HEIGHTS[nativeFontColumn()] + offset
	local record = shellFonts[template]
	if not record then
		local font = CreateFont("GroupFinderElvUI_" .. template)
		if not (font and font.SetFontObject and font.SetFontHeight) then
			return nil
		end
		record = { font = font }
		shellFonts[template] = record
	end
	if record.source ~= source or record.height ~= height then
		record.font:SetFontObject(source)
		record.font:SetFontHeight(height)
		record.source, record.height = source, height
	end
	return record.font
end

function ElvUICompat.ApplyMainWindowTitle(frame, fontString)
	if not (GF.MainFrame and frame == GF.MainFrame.frame and fontString) then
		return
	end
	local font = shellFont("GameFontNormal")
	if font and fontString.SetFontObject then
		fontString:SetFontObject(font)
	end
end

function ElvUICompat.ApplyMainTabFonts(button)
	if not (button and button._gfTopTabStyle
		and button.SetNormalFontObject and button.SetHighlightFontObject) then
		return
	end
	local normal = shellFont(GF.MAIN_PANEL_TAB_UNSELECTED_FONT_OBJECT or "GameFontNormal")
	local selected = shellFont(GF.MAIN_PANEL_TAB_SELECTED_FONT_OBJECT or "GameFontHighlight")
	local hover = shellFont("GameFontHighlightSmall")
	if not (normal and selected and hover) then
		return
	end
	button.unselectedFontObject, button.selectedFontObject = normal, selected
	button:SetNormalFontObject(button._gfSelected and selected or normal)
	button:SetHighlightFontObject(hover)
end

-- ElvUI's HandleEditBox adds a child Frame named backdrop. Keep its state
-- separate from GF's atlas and from input content/interactive children.
function ElvUICompat.SuppressInputBackdrop(widget)
	if not widget or type(_G.ElvUI) ~= "table"
		or (widget._gfElvUIBorrowOnly and not widget._gfElvUIInputBorrowed)
	then
		return
	end
	local backdrop = widget.backdrop
	if not backdrop then
		return
	end
	local state = widget._gfElvUIBackdropState or {}
	widget._gfElvUIBackdropState = state
	if not state[backdrop] then
		state[backdrop] = {
			shown = not backdrop.IsShown or backdrop:IsShown(),
			alpha = backdrop.GetAlpha and backdrop:GetAlpha() or nil,
		}
	end
	for region in pairs(state) do
		if region.Hide then region:Hide() end
		if region.SetAlpha then region:SetAlpha(0) end
	end
end

-- Skin handoffs must not rebind fonts; tab switches use these same entry points.
function ElvUICompat.BeginInputBorrow(widget)
	if not widget or type(_G.ElvUI) ~= "table" then
		return
	end
	if not widget._gfElvUIInputBorrowed then
		widget._gfElvUIBorrowOnly = true
		widget._gfElvUIInputBorrowed = true
	end
	ElvUICompat.SuppressInputBackdrop(widget)
end

function ElvUICompat.EndInputBorrow(widget, restore)
	if not widget or not widget._gfElvUIInputBorrowed then
		return
	end
	-- Stop persistent GF visual callbacks from hiding a returned native skin.
	widget._gfElvUIInputBorrowed = nil
	for region, info in pairs(widget._gfElvUIBackdropState or {}) do
		if restore ~= false then
			if info.alpha ~= nil and region.SetAlpha then region:SetAlpha(info.alpha) end
			if info.shown and region.Show then
				region:Show()
			elseif region.Hide then
				region:Hide()
			end
		end
	end
	widget._gfElvUIBackdropState = nil
end
