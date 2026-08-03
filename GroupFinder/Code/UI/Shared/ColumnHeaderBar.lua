local _, GF = ...

GF.ColumnHeaderBar = {}
local HeaderBar = GF.ColumnHeaderBar
local Columns = GF.ListColumns

local function localeText(key, fallback)
	local locale = GF.L or {}
	return locale[key] or fallback or key
end

local function configuredColor(key, fallback)
	local value = GF[key]
	if type(value) == "table" then
		return value
	end
	return fallback
end

local function headerFont(fontString)
	if not fontString then
		return
	end
	fontString._gfFontSizeOverride = GF.BROWSE_HEADER_TEXT_SIZE or 14
	fontString._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.Track then
		GF.Font.Track(fontString, "GameFontNormal")
	elseif fontString.SetFont then
		fontString:SetFont(
			STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
			GF.BROWSE_HEADER_TEXT_SIZE or 14,
			""
		)
	end
end

local function hideRegion(region)
	if region and region.Hide then
		region:Hide()
	elseif region and region.SetAlpha then
		region:SetAlpha(0)
	end
end

local function removeTemplateArt(header)
	if not header or header._gfPlainColumnHeader then
		return
	end
	header._gfPlainColumnHeader = true
	if header.SetPushedTextOffset then
		header:SetPushedTextOffset(0, 0)
	end
	for _, field in ipairs({
		"Background", "BG", "Bg", "Left", "Middle", "Right",
		"LeftHighlight", "MiddleHighlight", "RightHighlight",
	}) do
		hideRegion(header[field])
	end
	if header.GetNormalTexture then
		hideRegion(header:GetNormalTexture())
	end
	if header.GetPushedTexture then
		hideRegion(header:GetPushedTexture())
	end
	if header.GetHighlightTexture then
		hideRegion(header:GetHighlightTexture())
	end
end

local function refreshHeaderText(header)
	local text = header and header.GetFontString and header:GetFontString()
	if not text then
		return
	end
	local pressed = header._gfPressed == true
	local hovered = header._gfHovered == true
	local inset = GF.BROWSE_HEADER_TEXT_INSET_X or 3
	local dx = pressed and (GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_X or 1) or 0
	local dy = pressed and (GF.BROWSE_HEADER_TEXT_PRESSED_OFFSET_Y or -1) or 0
	local normal = configuredColor("BROWSE_HEADER_TEXT_COLOR", { 1, 0.82, 0, 1 })
	local hover = configuredColor("BROWSE_HEADER_HOVER_TEXT_COLOR", { 1, 0.96, 0.58, 1 })
	local pushed = configuredColor("BROWSE_HEADER_PRESSED_TEXT_COLOR", { 0.95, 0.68, 0.18, 1 })
	local color = pressed and pushed or (hovered and hover or normal)

	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", header, "TOPLEFT", inset + dx, dy)
	text:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -inset + dx, dy)
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
	text:SetAlpha(pressed and (GF.BROWSE_HEADER_TEXT_PRESSED_ALPHA or 1) or 1)
	text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function setHovered(header, value)
	header._gfHovered = value == true
	refreshHeaderText(header)
end

local function setPressed(header, value)
	header._gfPressed = value == true
	refreshHeaderText(header)
end

local function setVerticalGradient(texture, topAlpha, bottomAlpha)
	local rgb = configuredColor(
		"BROWSE_HEADER_ACCENT_COLOR",
		{ 126 / 255, 112 / 255, 82 / 255 }
	)
	if texture.SetGradient and CreateColor then
		local ok = pcall(
			texture.SetGradient,
			texture,
			"VERTICAL",
			CreateColor(rgb[1], rgb[2], rgb[3], topAlpha),
			CreateColor(rgb[1], rgb[2], rgb[3], bottomAlpha)
		)
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha(
			"VERTICAL",
			rgb[1], rgb[2], rgb[3], topAlpha,
			rgb[1], rgb[2], rgb[3], bottomAlpha
		)
	else
		texture:SetVertexColor(rgb[1], rgb[2], rgb[3], math.max(topAlpha, bottomAlpha))
	end
end

local function createDivider(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame.upper = frame:CreateTexture(nil, "OVERLAY")
	frame.lower = frame:CreateTexture(nil, "OVERLAY")
	local texture = GF.BROWSE_HEADER_ACCENT_TEXTURE or GF.WHITE_TEXTURE
	frame.upper:SetTexture(texture)
	frame.lower:SetTexture(texture)
	local alpha = GF.BROWSE_HEADER_ACCENT_ALPHA or 0.6
	setVerticalGradient(frame.upper, alpha, 0)
	setVerticalGradient(frame.lower, 0, alpha)
	return frame
end

local function sizeDivider(divider)
	local height = GF.BROWSE_HEADER_ACCENT_HEIGHT or 22
	local topHeight = height / 2
	divider:SetSize(GF.BROWSE_HEADER_ACCENT_WIDTH or 1.5, height)
	divider.upper:ClearAllPoints()
	divider.upper:SetPoint("TOPLEFT", divider, "TOPLEFT")
	divider.upper:SetPoint("TOPRIGHT", divider, "TOPRIGHT")
	divider.upper:SetHeight(topHeight)
	divider.lower:ClearAllPoints()
	divider.lower:SetPoint("TOPLEFT", divider.upper, "BOTTOMLEFT")
	divider.lower:SetPoint("BOTTOMRIGHT", divider, "BOTTOMRIGHT")
end

local function hideDividers(bar)
	for _, divider in ipairs(bar._columnDividers or {}) do
		divider:Hide()
	end
end

local function updateDividers(bar, layout)
	if not (layout and layout.active and layout.byId) then
		hideDividers(bar)
		return
	end
	bar._columnDividers = bar._columnDividers or {}
	local wanted = math.max(0, #layout.active - 1)
	for index = #bar._columnDividers + 1, wanted do
		bar._columnDividers[index] = createDivider(bar.headers)
	end
	for index, divider in ipairs(bar._columnDividers) do
		local leftID = layout.active[index]
		local left = leftID and layout.byId[leftID]
		if index <= wanted and left then
			divider:ClearAllPoints()
			sizeDivider(divider)
			divider:SetPoint(
				"CENTER",
				bar.headers,
				"LEFT",
				math.floor(left.x + left.width + 0.5),
				0
			)
			divider:Show()
		else
			divider:Hide()
		end
	end
end

local function isBrowse(bar)
	return bar and bar._mode == "browse"
end

local function isApplicant(bar)
	return bar and bar._mode == "applicant"
end

local function columnSortable(bar, columnID)
	if bar._isSortable then
		return bar._isSortable(columnID, bar) == true
	end
	if isBrowse(bar) or isApplicant(bar) then
		return Columns:IsSortable(columnID, bar._profile)
	end
	return false
end

local function columnLabel(bar, columnID)
	if bar._getHeaderLabel then
		return bar._getHeaderLabel(columnID, bar)
	end
	return Columns:GetHeaderLabel(columnID, bar._profile)
end

local function runSort(bar, columnID)
	if not columnSortable(bar, columnID) then
		return
	end
	if bar._onColumnClick then
		bar._onColumnClick(columnID, bar)
	elseif isApplicant(bar) then
		Columns:ToggleApplicantSort(columnID)
	else
		Columns:ToggleBrowseSort(columnID)
	end
	if bar._onSort then
		bar._onSort()
	end
end

local function configureHeaderInput(bar, header, columnID, sortable)
	setHovered(header, false)
	setPressed(header, false)
	if not sortable then
		header:EnableMouse(false)
		header:SetScript("OnEnter", nil)
		header:SetScript("OnLeave", nil)
		header:SetScript("OnMouseDown", nil)
		header:SetScript("OnMouseUp", nil)
		header:SetScript("OnClick", nil)
		return
	end

	header:EnableMouse(true)
	header:RegisterForClicks("LeftButtonUp")
	header:SetScript("OnEnter", function(button)
		setHovered(button, true)
	end)
	header:SetScript("OnLeave", function(button)
		setHovered(button, false)
		setPressed(button, false)
	end)
	header:SetScript("OnMouseDown", function(button, mouseButton)
		if mouseButton == "LeftButton" then
			setPressed(button, true)
		end
	end)
	header:SetScript("OnMouseUp", function(button)
		setPressed(button, false)
	end)
	header:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			runSort(bar, columnID)
		end
	end)
end

local function hideNativeSortArrows(headers)
	local pool = headers and headers.columnHeaders
	if not pool then
		return
	end
	for header in pool:EnumerateActive() do
		if header.Arrow then
			header.Arrow:Hide()
		end
	end
end

local function resolveRequestedWidth(bar, measuredWidth)
	if isApplicant(bar) and GF.GetApplicantListLayoutWidth then
		return GF.GetApplicantListLayoutWidth()
	end
	if isBrowse(bar) then
		if GF.FindGroupTab and GF.FindGroupTab.UpdateScrollWidth then
			GF.FindGroupTab:UpdateScrollWidth()
		end
		if GF.GetBrowseListLayoutWidth then
			return GF.GetBrowseListLayoutWidth()
		end
	end
	return measuredWidth
end

function HeaderBar:HideOverflowHeaders(bar)
	local pool = bar and bar.headers and bar.headers.columnHeaders
	local rightEdge = bar and bar.GetRight and bar:GetRight()
	if not pool or not rightEdge then
		return
	end
	for header in pool:EnumerateActive() do
		local headerRight = header:GetRight()
		header:SetShown(not headerRight or headerRight <= rightEdge + 0.5)
	end
end

function HeaderBar:Create(parent, options)
	options = options or {}
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(22)
	bar._owner = options.owner
	bar._mode = options.mode or "browse"
	bar._profile = options.profile or "browse_pve"
	bar._onSort = options.onSort
	bar._onLayoutChange = options.onLayoutChange
	bar._onLayoutResolved = options.onLayoutResolved
	bar._resolveLayout = options.resolveLayout
	bar._getHeaderLabel = options.getHeaderLabel
	bar._isSortable = options.isSortable
	bar._onColumnClick = options.onColumnClick
	bar._updateHeader = options.updateHeader

	local headers = CreateFrame("Frame", nil, bar, "ColumnDisplayTemplate")
	local fixedHeight = tonumber(options.contentHeight)
	if fixedHeight and fixedHeight > 0 then
		headers:SetPoint("LEFT", bar, "LEFT")
		headers:SetPoint("RIGHT", bar, "RIGHT")
		headers:SetHeight(fixedHeight)
	else
		headers:SetAllPoints(bar)
	end
	hideRegion(headers.Background)
	hideRegion(headers.TopTileStreaks)
	bar.headers = headers
	headers.UpdateSortArrows = hideNativeSortArrows

	bar:SetScript("OnSizeChanged", function(self, width)
		if GF._frameResizing then
			HeaderBar:HideOverflowHeaders(self)
			return
		end
		if self._layoutWidth == width then
			return
		end
		self._layoutWidth = width
		if not self._suppressLayout then
			HeaderBar:Layout(self, resolveRequestedWidth(self, width))
		end
	end)
	return bar
end

function HeaderBar:GetBrowseNode()
	if GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		local selected = GF.FindGroupTab:GetSelection()
		if selected then
			return selected
		end
	end
	return GF.MainFrame and GF.MainFrame.selection or nil
end

function HeaderBar:RefreshProfile(bar)
	if not bar then
		return
	end
	if isApplicant(bar) then
		bar._profile = "applicant"
	elseif isBrowse(bar) then
		bar._profile = Columns:GetBrowseProfile(self:GetBrowseNode())
	end
end

function HeaderBar:Layout(bar, width)
	if not (bar and bar.headers) then
		return nil
	end
	width = tonumber(width) or tonumber(bar:GetWidth()) or 0
	if width <= 4 then
		return nil
	end

	self:RefreshProfile(bar)
	local layout
	if bar._resolveLayout then
		layout = bar._resolveLayout(width, bar)
	else
		layout = Columns:ResolveLayout(width, bar._profile)
	end
	if type(layout) ~= "table" then
		return nil
	end

	bar._activeIds = layout.active or {}
	bar._layout = layout
	bar._suppressLayout = true
	bar.headers:LayoutColumns(layout.headerLayout or {})
	bar._suppressLayout = nil

	local pool = bar.headers.columnHeaders
	if not pool then
		return layout
	end
	for header in pool:EnumerateActive() do
		local columnID = bar._activeIds[header:GetID()]
		local sortable = columnID and columnSortable(bar, columnID) or false
		removeTemplateArt(header)
		header:SetText(columnID and columnLabel(bar, columnID) or "")
		headerFont(header:GetFontString())
		configureHeaderInput(bar, header, columnID, sortable)
		if bar._updateHeader then
			bar._updateHeader(header, columnID, sortable, layout, bar)
		end
	end

	updateDividers(bar, layout)
	hideNativeSortArrows(bar.headers)
	if bar._onLayoutResolved then
		bar._onLayoutResolved(layout, bar)
	end
	return layout
end

function HeaderBar:LayoutHost(host, bar, layoutWidth)
	if not host or not bar or not host:IsShown() then
		return nil
	end
	return self:Layout(bar, layoutWidth or host:GetWidth())
end

local function notifyLayoutChanged(bar)
	if bar and bar._onLayoutChange then
		bar._onLayoutChange()
	end
end

local function orderIndex(order, columnID)
	for index, current in ipairs(order or {}) do
		if current == columnID then
			return index
		end
	end
	return nil
end

local function relayoutAfterMenu(bar)
	HeaderBar:Layout(bar)
	notifyLayoutChanged(bar)
end

local function buildColumnMenu(bar, profile, anchorColumnID)
	local order = Columns:GetColumnOrder(profile)
	local position = orderIndex(order, anchorColumnID)
	local menu = {
		{
			text = localeText("COL_MENU_MOVE_LEFT", "Move left"),
			disabled = not position or position <= 1,
			action = function()
				if Columns:MoveColumn(profile, anchorColumnID, -1) then
					relayoutAfterMenu(bar)
				end
			end,
		},
		{
			text = localeText("COL_MENU_MOVE_RIGHT", "Move right"),
			disabled = not position or position >= #order,
			action = function()
				if Columns:MoveColumn(profile, anchorColumnID, 1) then
					relayoutAfterMenu(bar)
				end
			end,
		},
		{
			text = localeText("COL_MENU_LAYOUT", "Column width & weight…"),
			action = function()
				if GF.ColumnLayoutDialog and GF.ColumnLayoutDialog.Open then
					GF.ColumnLayoutDialog:Open(profile, anchorColumnID, bar)
				end
			end,
		},
		{ separator = true },
	}
	for _, columnID in ipairs(order) do
		if not Columns:IsColumnNoHide(profile, columnID) then
			menu[#menu + 1] = {
				text = Columns:GetHeaderLabel(columnID, profile),
				checked = function()
					return Columns:GetColumnVisible(profile)[columnID] ~= false
				end,
				action = function()
					local visible = Columns:GetColumnVisible(profile)[columnID] ~= false
					Columns:SetColumnVisible(profile, columnID, not visible)
					relayoutAfterMenu(bar)
				end,
			}
		end
	end
	return menu
end

local function openModernMenu(entries)
	MenuUtil.CreateContextMenu(UIParent, function(_, root)
		local fontService = GF.Font
		if fontService and type(fontService.WrapMenuRoot) == "function" then
			fontService.WrapMenuRoot(root)
		end
		for _, entry in ipairs(entries) do
			if entry.separator == true then
				root:CreateDivider()
			elseif type(entry.checked) == "function" then
				local function toggleEntry()
					entry.action()
					return MenuResponse and MenuResponse.Refresh or nil
				end
				root:CreateCheckbox(entry.text, entry.checked, toggleEntry)
			else
				local item = root:CreateButton(entry.text, entry.action)
				if entry.disabled then
					item:SetEnabled(false)
				end
			end
		end
	end)
end

local function openLegacyMenu(entries)
	local menu = {}
	for _, entry in ipairs(entries) do
		if entry.separator then
			menu[#menu + 1] = {
				text = "",
				notClickable = true,
				notCheckable = true,
				isTitle = true,
				disabled = true,
			}
		else
			menu[#menu + 1] = {
				text = entry.text,
				notCheckable = entry.checked == nil,
				isNotRadio = entry.checked ~= nil,
				checked = entry.checked,
				disabled = entry.disabled,
				func = entry.action,
			}
		end
	end
	HeaderBar._legacyMenu = HeaderBar._legacyMenu or CreateFrame("Frame")
	EasyMenu(menu, HeaderBar._legacyMenu, "cursor", 0, 0, "MENU")
	if GF.Font and GF.Font.ApplyDropdownMenuFont then
		GF.Font.ApplyDropdownMenuFont()
	end
end

function HeaderBar:ShowContextMenu(bar, anchorColumnID)
	if not bar or not anchorColumnID then
		return
	end
	self:RefreshProfile(bar)
	local entries = buildColumnMenu(bar, bar._profile, anchorColumnID)
	if MenuUtil and MenuUtil.CreateContextMenu then
		openModernMenu(entries)
	elseif EasyMenu then
		openLegacyMenu(entries)
	end
end
