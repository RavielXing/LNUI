local _, GF = ...

GF.ColumnHeaderBar = {}
local CHB = GF.ColumnHeaderBar

local LC = GF.ListColumns
local WHITE = "Interface\\Buttons\\WHITE8X8"

local HEADER_STATE_COLORS = {
	normal = { 0.08, 0.04, 0.01, 0.22 },
	hover = { 0.92, 0.58, 0.08, 0.18 },
	pushed = { 0.48, 0.14, 0.02, 0.42 },
	line = { 1, 0.82, 0, 0.45 },
	linePushed = { 1, 0.95, 0.35, 0.72 },
}

local function getLocaleString(key, fallback)
	local L = GF.L or {}
	return L[key] or fallback or key
end

local function isBrowseBar(bar)
	return bar and bar._mode ~= "applicant"
end

local function isApplicantBar(bar)
	return bar and bar._mode == "applicant"
end

local function getColor(key, fallback)
	local color = GF[key]
	if type(color) == "table" then
		return color
	end
	return fallback
end

local function applyHeaderFont(fs, scale)
	if not fs then
		return
	end
	local size = GF.SECTION_HEADER_TEXT_SIZE or GF.BROWSE_HEADER_TEXT_SIZE or 14
	fs._gfFontSizeOverride = size
	fs._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.Track then
		GF.Font.Track(fs, "GameFontNormal")
	elseif fs.SetFont then
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
	end
end

local function setTextureColor(texture, color)
	if not texture or not color then
		return
	end
	texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function createHeaderStateTexture(header, layer, subLevel)
	local texture = header:CreateTexture(nil, layer, nil, subLevel)
	texture:SetTexture(WHITE)
	texture:SetAllPoints(header)
	texture:Hide()
	return texture
end

local function ensureHeaderStateChrome(header)
	if not header then
		return nil
	end
	if header._gfHeaderStateChrome then
		return header._gfHeaderStateChrome
	end
	header._gfHeaderStateChrome = true
	return header._gfHeaderStateChrome
end

local function setHeaderChromeState(header)
	ensureHeaderStateChrome(header)
end

local function setHeaderTextState(header)
	local fs = header and header.GetFontString and header:GetFontString()
	if not fs then
		return
	end
	setHeaderChromeState(header)
	local pressed = header._gfHeaderTextPressed == true
	local hovered = header._gfHeaderTextHovered == true
	local offsetX = pressed and (GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_X or 1) or 0
	local offsetY = pressed and (GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_Y or -1) or 0
	local inset = GF.BROWSE_HEADER_TEXT_INSET_X or 3
	local normal = getColor("BROWSE_HEADER_TEXT_COLOR", { 1, 0.82, 0, 1 })
	local hover = getColor("BROWSE_HEADER_HOVER_TEXT_COLOR", { 1, 0.96, 0.58, 1 })
	local pushed = getColor("BROWSE_HEADER_PRESSED_TEXT_COLOR", { 0.95, 0.68, 0.18, 1 })
	local color = pressed and pushed or (hovered and hover or normal)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", header, "TOPLEFT", inset + offsetX, offsetY)
	fs:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -inset + offsetX, offsetY)
	fs:SetAlpha(pressed and (GF.BROWSE_HEADER_TEXT_PRESSED_ALPHA or 1) or 1)
	fs:SetJustifyH("CENTER")
	fs:SetTextColor(color[1], color[2], color[3], color[4])
end

local function setHeaderPressed(header, pressed)
	if not header then
		return
	end
	header._gfHeaderTextPressed = pressed == true
	setHeaderTextState(header)
end

local function setHeaderHovered(header, hovered)
	if not header then
		return
	end
	header._gfHeaderTextHovered = hovered == true
	setHeaderTextState(header)
end

local function hideTexture(texture)
	if texture and texture.Hide then
		texture:Hide()
	elseif texture and texture.SetAlpha then
		texture:SetAlpha(0)
	end
end

local function stripHeaderChrome(header)
	if not header or header._gfHeaderChromeStripped then
		return
	end
	header._gfHeaderChromeStripped = true
	if header.SetPushedTextOffset then
		header:SetPushedTextOffset(0, 0)
	end
	for _, key in ipairs({
		"Background",
		"BG",
		"Bg",
		"Left",
		"Middle",
		"Right",
		"LeftHighlight",
		"MiddleHighlight",
		"RightHighlight",
	}) do
		hideTexture(header[key])
	end
	if header.GetNormalTexture then
		hideTexture(header:GetNormalTexture())
	end
	if header.GetPushedTexture then
		hideTexture(header:GetPushedTexture())
	end
	if header.GetHighlightTexture then
		hideTexture(header:GetHighlightTexture())
	end
end

local function setAccentGradient(texture, startAlpha, endAlpha)
	if not texture then
		return
	end
	local color = getColor("BROWSE_HEADER_ACCENT_COLOR", { 126 / 255, 112 / 255, 82 / 255 })
	if texture.SetGradient and CreateColor then
		local ok = pcall(
			texture.SetGradient,
			texture,
			"VERTICAL",
			CreateColor(color[1], color[2], color[3], startAlpha),
			CreateColor(color[1], color[2], color[3], endAlpha)
		)
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha(
			"VERTICAL",
			color[1], color[2], color[3], startAlpha,
			color[1], color[2], color[3], endAlpha
		)
	else
		texture:SetVertexColor(color[1], color[2], color[3], math.max(startAlpha or 0, endAlpha or 0))
	end
end

local function layoutHeaderAccent(accent)
	if not accent then
		return
	end
	local height = GF.BROWSE_HEADER_ACCENT_HEIGHT or 22
	local halfHeight = height / 2
	accent:SetSize(GF.BROWSE_HEADER_ACCENT_WIDTH or 1.5, height)
	if accent.top then
		accent.top:ClearAllPoints()
		accent.top:SetPoint("TOPLEFT", accent, "TOPLEFT", 0, 0)
		accent.top:SetPoint("TOPRIGHT", accent, "TOPRIGHT", 0, 0)
		accent.top:SetHeight(halfHeight)
	end
	if accent.bottom then
		accent.bottom:ClearAllPoints()
		accent.bottom:SetPoint("TOPLEFT", accent.top, "BOTTOMLEFT", 0, 0)
		accent.bottom:SetPoint("BOTTOMRIGHT", accent, "BOTTOMRIGHT", 0, 0)
	end
end

local function createHeaderAccent(parent)
	local accent = CreateFrame("Frame", nil, parent)
	local top = accent:CreateTexture(nil, "OVERLAY")
	top:SetTexture(GF.BROWSE_HEADER_ACCENT_TEXTURE or WHITE)
	setAccentGradient(top, GF.BROWSE_HEADER_ACCENT_ALPHA or 0.6, 0)
	local bottom = accent:CreateTexture(nil, "OVERLAY")
	bottom:SetTexture(GF.BROWSE_HEADER_ACCENT_TEXTURE or WHITE)
	setAccentGradient(bottom, 0, GF.BROWSE_HEADER_ACCENT_ALPHA or 0.6)
	accent.top = top
	accent.bottom = bottom
	layoutHeaderAccent(accent)
	return accent
end

local function ensureHeaderAccents(bar, count)
	if not bar or not bar.headers then
		return nil
	end
	bar._headerAccents = bar._headerAccents or {}
	for i = #bar._headerAccents + 1, count do
		bar._headerAccents[i] = createHeaderAccent(bar.headers)
	end
	return bar._headerAccents
end

local function hideHeaderAccents(bar)
	if not bar or not bar._headerAccents then
		return
	end
	for _, accent in ipairs(bar._headerAccents) do
		accent:Hide()
	end
end

local function layoutHeaderAccents(bar, layout)
	if not layout or not layout.active then
		hideHeaderAccents(bar)
		return
	end
	local required = math.max(0, #layout.active - 1)
	local accents = ensureHeaderAccents(bar, required)
	if not accents then
		return
	end
	for index, accent in ipairs(accents) do
		local leftKey = layout.active[index]
		local leftColumn = leftKey and layout.byId and layout.byId[leftKey]
		if index <= required and leftColumn then
			accent:ClearAllPoints()
			layoutHeaderAccent(accent)
			accent:SetPoint("CENTER", bar.headers, "LEFT", math.floor(leftColumn.x + leftColumn.width + 0.5), 0)
			accent:Show()
		else
			accent:Hide()
		end
	end
end

function CHB:HideOverflowHeaders(bar)
	if not bar or not bar.headers then
		return
	end
	local pool = bar.headers.columnHeaders
	if not pool then
		return
	end
	local barRight = bar:GetRight()
	if not barRight then
		return
	end
	for header in pool:EnumerateActive() do
		local right = header:GetRight()
		if right and right > barRight + 0.5 then
			header:Hide()
		else
			header:Show()
		end
	end
end

function CHB:Create(parent, opts)
	opts = opts or {}
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(22)
	bar._owner = opts.owner
	bar._onSort = opts.onSort
	bar._onLayoutChange = opts.onLayoutChange
	bar._profile = opts.profile or "browse_pve"
	bar._mode = opts.mode or "browse"

	local headers = CreateFrame("Frame", nil, bar, "ColumnDisplayTemplate")
	headers:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	headers:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	if headers.Background then
		headers.Background:Hide()
	end
	if headers.TopTileStreaks then
		headers.TopTileStreaks:Hide()
	end
	bar.headers = headers

	function headers:UpdateSortArrows()
		local pool = headers.columnHeaders
		if not pool then
			return
		end
		for header in pool:EnumerateActive() do
			local arrow = header.Arrow
			if arrow then
				arrow:Hide()
			end
		end
	end

	function headers:OnHeaderClick(index, button)
		local colID = bar._activeIds and bar._activeIds[index]
		if not colID then
			return
		end
		if button == "LeftButton" then
			if not LC:IsSortable(colID, bar._profile) then
				return
			end
			if isApplicantBar(bar) then
				LC:ToggleApplicantSort(colID)
			else
				LC:ToggleBrowseSort(colID)
			end
			headers:UpdateSortArrows()
			if bar._onSort then
				bar._onSort()
			end
		end
	end

	bar:SetScript("OnSizeChanged", function(self, w)
		if GF._frameResizing then
			CHB:HideOverflowHeaders(self)
			return
		end
		if self._layoutWidth ~= w then
			self._layoutWidth = w
			if not self._suppressLayout then
				local layoutW = w
				if bar._mode == "applicant" and GF.GetApplicantListLayoutWidth then
					layoutW = GF.GetApplicantListLayoutWidth()
				elseif bar._mode ~= "applicant" and GF.FindGroupTab and GF.FindGroupTab.UpdateScrollWidth then
					GF.FindGroupTab:UpdateScrollWidth()
					if GF.GetBrowseListLayoutWidth then
						layoutW = GF.GetBrowseListLayoutWidth()
					end
				end
				CHB:Layout(self, layoutW)
			end
		end
	end)

	return bar
end

function CHB:GetBrowseNode()
	if GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		local node = GF.FindGroupTab:GetSelection()
		if node then
			return node
		end
	end
	return GF.MainFrame and GF.MainFrame.selection
end

function CHB:RefreshProfile(bar)
	if bar._mode == "applicant" then
		bar._profile = "applicant"
		return
	end
	local node = self:GetBrowseNode()
	bar._profile = LC:GetBrowseProfile(node)
end

function CHB:Layout(bar, width)
	if not bar or not bar.headers then
		return
	end
	width = width or bar:GetWidth() or 0
	if width <= 4 then
		return
	end
	self:RefreshProfile(bar)
	local profile = bar._profile
	local layout = LC:ResolveLayout(width, profile)
	bar._activeIds = layout.active
	bar._layout = layout

	bar._suppressLayout = true
	bar.headers:LayoutColumns(layout.headerLayout)
	bar._suppressLayout = nil

	local pool = bar.headers.columnHeaders
	if not pool then
		return
	end
	for header in pool:EnumerateActive() do
		local idx = header:GetID()
		local colID = layout.active[idx]
		local sortable = false
		if colID then
			sortable = (isBrowseBar(bar) or isApplicantBar(bar)) and LC:IsSortable(colID, profile)
			header:SetText(LC:GetHeaderLabel(colID, profile))
			local fs = header.GetFontString and header:GetFontString()
			if fs then
				applyHeaderFont(fs, layout.scale)
				setHeaderHovered(header, false)
				setHeaderPressed(header, false)
			end
			if not header._gfWired then
				header._gfWired = true
				stripHeaderChrome(header)
				header.Arrow = nil
			end
		end
		if sortable then
			header:EnableMouse(true)
			header:RegisterForClicks("LeftButtonUp")
			header:SetScript("OnEnter", function(btn)
				setHeaderHovered(btn, true)
			end)
			header:SetScript("OnLeave", function(btn)
				setHeaderHovered(btn, false)
				setHeaderPressed(btn, false)
			end)
			header:SetScript("OnMouseDown", function(btn, mouseButton)
				if mouseButton == "LeftButton" then
					setHeaderPressed(btn, true)
				end
			end)
			header:SetScript("OnMouseUp", function(btn)
				setHeaderPressed(btn, false)
			end)
			header:SetScript("OnClick", function(btn, button)
				bar.headers:OnHeaderClick(btn:GetID(), button)
			end)
		else
			header:EnableMouse(false)
			header:SetScript("OnEnter", nil)
			header:SetScript("OnLeave", nil)
			header:SetScript("OnMouseDown", nil)
			header:SetScript("OnMouseUp", nil)
			header:SetScript("OnClick", nil)
		end
	end
	layoutHeaderAccents(bar, layout)
	bar.headers:UpdateSortArrows()
end

function CHB:LayoutHost(host, bar, layoutWidth)
	if not host or not bar or not host:IsShown() then
		return
	end
	self:Layout(bar, layoutWidth or host:GetWidth())
end

local function requestRelayout(bar)
	if bar._onLayoutChange then
		bar._onLayoutChange()
	end
end

function CHB:ShowContextMenu(bar, anchorColID)
	if not bar or not anchorColID then
		return
	end
	self:RefreshProfile(bar)
	local profile = bar._profile
	local order = LC:GetColumnOrder(profile)
	local idx = tIndexOf(order, anchorColID)

	local menuArgs = {}

	menuArgs[#menuArgs + 1] = {
		text = getLocaleString("COL_MENU_MOVE_LEFT", "Move left"),
		notCheckable = true,
		disabled = not idx or idx <= 1,
		func = function()
			if LC:MoveColumn(profile, anchorColID, -1) then
				CHB:Layout(bar)
				requestRelayout(bar)
			end
		end,
	}

	menuArgs[#menuArgs + 1] = {
		text = getLocaleString("COL_MENU_MOVE_RIGHT", "Move right"),
		notCheckable = true,
		disabled = not idx or idx >= #order,
		func = function()
			if LC:MoveColumn(profile, anchorColID, 1) then
				CHB:Layout(bar)
				requestRelayout(bar)
			end
		end,
	}

	menuArgs[#menuArgs + 1] = {
		text = getLocaleString("COL_MENU_LAYOUT", "Column width & weight…"),
		notCheckable = true,
		func = function()
			if GF.ColumnLayoutDialog and GF.ColumnLayoutDialog.Open then
				GF.ColumnLayoutDialog:Open(profile, anchorColID, bar)
			end
		end,
	}

	menuArgs[#menuArgs + 1] = { text = "", notClickable = true, notCheckable = true, isTitle = true, disabled = true }

	for _, colID in ipairs(order) do
		if not LC:IsColumnNoHide(profile, colID) then
			local label = LC:GetHeaderLabel(colID, profile)
			menuArgs[#menuArgs + 1] = {
				text = label,
				isNotRadio = true,
				checked = function()
					return LC:GetColumnVisible(profile)[colID] ~= false
				end,
				func = function()
					local cur = LC:GetColumnVisible(profile)[colID] ~= false
					LC:SetColumnVisible(profile, colID, not cur)
					CHB:Layout(bar)
					requestRelayout(bar)
				end,
			}
		end
	end

	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(UIParent, function(_, root)
			if GF.Font and GF.Font.WrapMenuRoot then
				GF.Font.WrapMenuRoot(root)
			end
			for _, entry in ipairs(menuArgs) do
				if entry.isTitle then
					root:CreateTitle(entry.text)
				elseif entry.checked then
					root:CreateCheckbox(entry.text, entry.checked, function()
						entry.func()
						if MenuResponse then
							return MenuResponse.Refresh
						end
					end)
				else
					local item = root:CreateButton(entry.text, entry.func)
					if entry.disabled then
						item:SetEnabled(false)
					end
				end
			end
		end)
	elseif EasyMenu then
		EasyMenu(menuArgs, CreateFrame("Frame"), "cursor", 0, 0, "MENU")
		if GF.Font and GF.Font.ApplyDropdownMenuFont then
			GF.Font.ApplyDropdownMenuFont()
		end
	end
end
