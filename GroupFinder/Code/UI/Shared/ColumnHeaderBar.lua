local _, GF = ...

-- Shared, stateless view for every GF column header. Column definitions,
-- ordering, visibility, widths, and sort state remain owned by
-- ColumnLayoutModel; this module only projects a resolved layout into frames.
GF.ColumnHeaderBar = {}
local HeaderBar = GF.ColumnHeaderBar
local Model = GF.ColumnLayoutModel
local STYLE = GF.TABLE_HEADER_STYLE or {}

-- Locale changes must not depend on a later size/layout event. Keep only weak
-- references to live header bars so every already-created surface can repaint
-- its labels in place without extending the lifetime of a hidden frame.
HeaderBar._liveBars = setmetatable({}, { __mode = "k" })

local DEFAULT_HEADER_COLOR = { 1, 0.82, 0, 1 }
local DEFAULT_HOVER_COLOR = { 1, 0.96, 0.58, 1 }
local DEFAULT_PRESSED_COLOR = { 0.95, 0.68, 0.18, 1 }
local DEFAULT_ACCENT_COLOR = { 198 / 255, 168 / 255, 96 / 255 }

local function localeText(key, fallback)
	local locale = GF.L or {}
	return locale[key] or fallback or key
end

local function configuredColor(key, fallback)
	local color = STYLE[key]
	return type(color) == "table" and color or fallback
end

local function hideRegion(region)
	if not region then
		return
	end
	if region.Hide then
		region:Hide()
	elseif region.SetAlpha then
		region:SetAlpha(0)
	end
end

local function removeTemplateArtwork(header)
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
	for _, getterName in ipairs({
		"GetNormalTexture", "GetPushedTexture", "GetHighlightTexture",
	}) do
		local getter = header[getterName]
		if getter then
			hideRegion(getter(header))
		end
	end
end

local function applyHeaderFont(fontString)
	if not fontString then
		return
	end
	fontString._gfFontSizeOverride = STYLE.textSize or 14
	fontString._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.Track then
		GF.Font.Track(fontString, "GameFontNormal")
	elseif fontString.SetFont then
		fontString:SetFont(
			STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
			STYLE.textSize or 14,
			"")
	end
end

local function paintHeaderText(header)
	local text = header and header.GetFontString and header:GetFontString()
	if not text then
		return
	end
	local pressed = header._gfPressed == true
	local hovered = header._gfHovered == true
	local inset = STYLE.textInsetX or 3
	local offsetX = pressed
		and (STYLE.pressedOffsetX or 1) or 0
	local offsetY = pressed
		and (STYLE.pressedOffsetY or -1) or 0
	local color = configuredColor("textColor", DEFAULT_HEADER_COLOR)
	if pressed then
		color = configuredColor(
			"pressedTextColor", DEFAULT_PRESSED_COLOR)
	elseif hovered then
		color = configuredColor(
			"hoverTextColor", DEFAULT_HOVER_COLOR)
	end
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", header, "TOPLEFT", inset + offsetX, offsetY)
	text:SetPoint(
		"BOTTOMRIGHT", header, "BOTTOMRIGHT", -inset + offsetX, offsetY)
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
	text:SetAlpha(pressed and (STYLE.pressedAlpha or 1) or 1)
	text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function setHeaderHover(header, hovered)
	header._gfHovered = hovered == true
	paintHeaderText(header)
end

local function setHeaderPressed(header, pressed)
	header._gfPressed = pressed == true
	paintHeaderText(header)
end

local function setVerticalGradient(texture, topAlpha, bottomAlpha, color)
	color = color or configuredColor("dividerColor", DEFAULT_ACCENT_COLOR)
	if texture.SetGradient and CreateColor then
		local ok = pcall(
			texture.SetGradient,
			texture,
			"VERTICAL",
			CreateColor(color[1], color[2], color[3], topAlpha),
			CreateColor(color[1], color[2], color[3], bottomAlpha))
		if ok then
			return
		end
	end
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha(
			"VERTICAL",
			color[1], color[2], color[3], topAlpha,
			color[1], color[2], color[3], bottomAlpha)
	else
		texture:SetVertexColor(
			color[1], color[2], color[3], math.max(topAlpha, bottomAlpha))
	end
end

local function createDividerFrame(parent)
	local divider = CreateFrame("Frame", nil, parent)
	local atlas = divider:CreateTexture(nil, "OVERLAY")
	if GF.UI and GF.UI.TrySetAtlas
		and GF.UI.TrySetAtlas(
			atlas,
			STYLE.dividerAtlas or "GM-bgOpen-divider-vertical",
			true)
	then
		local color = configuredColor(
			"dividerColor", DEFAULT_ACCENT_COLOR)
		atlas:SetPoint("CENTER", divider, "CENTER")
		atlas:SetVertexColor(color[1], color[2], color[3])
		atlas:SetAlpha(STYLE.dividerAlpha or 1)
		divider.atlas = atlas
		return divider
	end

	atlas:Hide()
	divider.upper = divider:CreateTexture(nil, "OVERLAY")
	divider.lower = divider:CreateTexture(nil, "OVERLAY")
	local texturePath = STYLE.dividerTexture or GF.WHITE_TEXTURE
	divider.upper:SetTexture(texturePath)
	divider.lower:SetTexture(texturePath)
	local alpha = STYLE.dividerAlpha or 1
	setVerticalGradient(divider.upper, alpha, 0)
	setVerticalGradient(divider.lower, 0, alpha)
	return divider
end

local function sizeDivider(divider, requestedHeight)
	local height = requestedHeight or STYLE.dividerHeight or 22
	divider:SetSize(STYLE.dividerWidth or 1.5, height)
	if divider.atlas then
		if requestedHeight then divider.atlas:SetHeight(height) end
		return
	end
	divider.upper:ClearAllPoints()
	divider.upper:SetPoint("TOPLEFT", divider, "TOPLEFT")
	divider.upper:SetPoint("TOPRIGHT", divider, "TOPRIGHT")
	divider.upper:SetHeight(height / 2)
	divider.lower:ClearAllPoints()
	divider.lower:SetPoint("TOPLEFT", divider.upper, "BOTTOMLEFT")
	divider.lower:SetPoint("BOTTOMRIGHT", divider, "BOTTOMRIGHT")
end

function HeaderBar:CreateDivider(parent, height)
	local divider = createDividerFrame(parent)
	sizeDivider(divider, height)
	return divider
end

function HeaderBar:TintDivider(divider, color)
	local alpha = color[4] or 1
	if divider.atlas then
		divider.atlas:SetDesaturated(true)
		divider.atlas:SetVertexColor(color[1], color[2], color[3])
		divider.atlas:SetAlpha(alpha)
	else
		setVerticalGradient(divider.upper, alpha, 0, color)
		setVerticalGradient(divider.lower, 0, alpha, color)
	end
end

local function hideDividers(bar)
	for _, divider in ipairs(bar._columnDividers or {}) do
		divider:Hide()
	end
end

local function projectDividers(bar, layout)
	if not (layout and type(layout.active) == "table"
		and type(layout.byId) == "table")
	then
		hideDividers(bar)
		return
	end
	bar._columnDividers = bar._columnDividers or {}
	local wanted = math.max(0, #layout.active - 1)
	for index = #bar._columnDividers + 1, wanted do
		bar._columnDividers[index] = createDividerFrame(bar.headers)
	end
	for index, divider in ipairs(bar._columnDividers) do
		local columnID = layout.active[index]
		local column = columnID and layout.byId[columnID]
		if index <= wanted and column then
			sizeDivider(divider)
			divider:ClearAllPoints()
			divider:SetPoint(
				"CENTER",
				bar.headers,
				"LEFT",
				math.floor(column.x + column.width + 0.5),
				0)
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
	if not columnID then
		return false
	end
	if type(bar._isSortable) == "function" then
		return bar._isSortable(columnID, bar) == true
	end
	if (isBrowse(bar) or isApplicant(bar))
		and Model and type(Model.IsSortable) == "function"
	then
		return Model:IsSortable(columnID, bar._profile) == true
	end
	return false
end

local function columnLabel(bar, columnID)
	if type(bar._getHeaderLabel) == "function" then
		return bar._getHeaderLabel(columnID, bar)
	end
	if Model and type(Model.GetHeaderLabel) == "function" then
		return Model:GetHeaderLabel(columnID, bar._profile)
	end
	return columnID or ""
end

local function paintSortArrow(bar, header, columnID, sortable)
	local state = bar._getSortState and bar._getSortState(bar)
	local active = sortable and state and state.column == columnID
	local arrow = header.sortArrow
	if not arrow and sortable and bar._getSortState then
		arrow = header:CreateTexture(nil, "OVERLAY")
		GF.UI.TrySetAtlas(arrow, STYLE.sortArrowAtlas, true)
		header.sortArrow = arrow
	end
	if arrow then
		arrow:ClearAllPoints()
		arrow:SetPoint("RIGHT", header, "RIGHT", -STYLE.sortArrowInset, STYLE.sortArrowOffsetY)
		arrow:SetShown(active == true)
		if active then
			arrow:SetTexCoord(0, 1, state.asc ~= false and 1 or 0, state.asc ~= false and 0 or 1)
		end
	end
end

local function runSort(bar, columnID)
	if not columnSortable(bar, columnID) then
		return false
	end
	if type(bar._onColumnClick) == "function" then
		bar._onColumnClick(columnID, bar)
	elseif isApplicant(bar) and Model and Model.ToggleApplicantSort then
		Model:ToggleApplicantSort(columnID)
	elseif Model and Model.ToggleBrowseSort then
		Model:ToggleBrowseSort(columnID)
	end
	if type(bar._onSort) == "function" then
		bar._onSort()
	end
	return true
end

local function clearHeaderInput(header)
	for _, scriptName in ipairs({
		"OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnClick",
	}) do
		header:SetScript(scriptName, nil)
	end
end

local function bindHeaderInput(bar, header, columnID, sortable)
	setHeaderHover(header, false)
	setHeaderPressed(header, false)
	clearHeaderInput(header)
	local menuEnabled = bar._enableContextMenu == true
		and bar._mode ~= "custom" and columnID ~= nil
	if not sortable and not menuEnabled then
		header:EnableMouse(false)
		return
	end

	header:EnableMouse(true)
	if menuEnabled then
		header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	else
		header:RegisterForClicks("LeftButtonUp")
	end
	header:SetScript("OnEnter", function(button)
		setHeaderHover(button, true)
	end)
	header:SetScript("OnLeave", function(button)
		setHeaderHover(button, false)
		setHeaderPressed(button, false)
	end)
	header:SetScript("OnMouseDown", function(button, mouseButton)
		if sortable and mouseButton == "LeftButton" then
			setHeaderPressed(button, true)
		end
	end)
	header:SetScript("OnMouseUp", function(button)
		setHeaderPressed(button, false)
	end)
	header:SetScript("OnClick", function(button, mouseButton)
		if mouseButton == "LeftButton" then
			runSort(bar, columnID)
		elseif mouseButton == "RightButton" and menuEnabled then
			HeaderBar:ShowContextMenu(bar, columnID, button)
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
		if not GF._frameResizing
			and GF.FindGroupTab and GF.FindGroupTab.UpdateScrollWidth
		then
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
		local headerRight = header.GetRight and header:GetRight()
		header:SetShown(not headerRight or headerRight <= rightEdge + 0.5)
	end
	for _, divider in ipairs(bar._columnDividers or {}) do
		local dividerRight = divider.GetRight and divider:GetRight()
		if dividerRight and dividerRight > rightEdge + 0.5 then
			divider:Hide()
		end
	end
end

function HeaderBar:Create(parent, options)
	options = type(options) == "table" and options or {}
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(STYLE.height or 26)
	bar._owner = options.owner
	bar._mode = options.mode or "browse"
	bar._profile = options.profile
		or (Model and Model.PROFILE_BROWSE_PVE) or "browse_pve"
	bar._onSort = options.onSort
	bar._onLayoutChange = options.onLayoutChange
	bar._onLayoutResolved = options.onLayoutResolved
	bar._onSizeChanged = options.onSizeChanged
	bar._resolveLayout = options.resolveLayout
	bar._getHeaderLabel = options.getHeaderLabel
	bar._isSortable = options.isSortable
	bar._onColumnClick = options.onColumnClick
	bar._updateHeader = options.updateHeader
	bar._getSortState = options.getSortState
	bar._alignColumns = options.alignColumns == true
	bar._enableContextMenu = options.enableContextMenu == true

	local headers = CreateFrame("Frame", nil, bar, "ColumnDisplayTemplate")
	local contentHeight = tonumber(options.contentHeight)
	if contentHeight and contentHeight > 0 then
		headers:SetPoint("LEFT", bar, "LEFT")
		headers:SetPoint("RIGHT", bar, "RIGHT")
		headers:SetHeight(contentHeight)
	else
		headers:SetAllPoints(bar)
	end
	hideRegion(headers.Background)
	hideRegion(headers.TopTileStreaks)
	bar.headers = headers
	headers.UpdateSortArrows = hideNativeSortArrows

	bar:SetScript("OnSizeChanged", function(self, width)
		if self._layoutWidth == width then
			if GF._frameResizing then
				HeaderBar:HideOverflowHeaders(self)
			end
			return
		end
		self._layoutWidth = width
		if not self._suppressLayout then
			HeaderBar:Layout(self, resolveRequestedWidth(self, width))
			if GF._frameResizing then
				HeaderBar:HideOverflowHeaders(self)
			end
			if self._onSizeChanged then
				self._onSizeChanged(self, width)
			end
		end
	end)
	self._liveBars[bar] = true
	return bar
end

function HeaderBar:GetBrowseNode()
	local controller = GF.FindGroupTab
	if controller and controller.GetSelection then
		local selected = controller:GetSelection()
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
		bar._profile = (Model and Model.PROFILE_APPLICANT) or "applicant"
	elseif isBrowse(bar) and Model and Model.GetBrowseProfile then
		bar._profile = Model:GetBrowseProfile(self:GetBrowseNode())
	end
end

local function resolveLayout(bar, width)
	if type(bar._resolveLayout) == "function" then
		return bar._resolveLayout(width, bar)
	end
	return Model and Model.ResolveLayout
		and Model:ResolveLayout(width, bar._profile) or nil
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
	local layout = resolveLayout(bar, width)
	if type(layout) ~= "table" then
		return nil
	end
	bar._activeIds = type(layout.active) == "table" and layout.active or {}
	bar._layout = layout
	bar._suppressLayout = true
	bar.headers:LayoutColumns(layout.headerLayout or {})
	bar._suppressLayout = nil

	local pool = bar.headers.columnHeaders
	if not pool then
		projectDividers(bar, layout)
		return layout
	end
	for header in pool:EnumerateActive() do
		local columnID = bar._activeIds[header:GetID()]
		local sortable = columnSortable(bar, columnID)
		removeTemplateArtwork(header)
		if bar._alignColumns and layout.byId[columnID] then
			local column = layout.byId[columnID]
			header:ClearAllPoints()
			header:SetPoint("LEFT", bar.headers, "LEFT", column.x, 0)
			header:SetSize(column.width, STYLE.height)
		end
		header._gfColumnID = columnID
		header:SetText(columnID and columnLabel(bar, columnID) or "")
		applyHeaderFont(header:GetFontString())
		bindHeaderInput(bar, header, columnID, sortable)
		paintSortArrow(bar, header, columnID, sortable)
		header:Show()
		if type(bar._updateHeader) == "function" then
			bar._updateHeader(header, columnID, sortable, layout, bar)
		end
	end

	projectDividers(bar, layout)
	hideNativeSortArrows(bar.headers)
	if type(bar._onLayoutResolved) == "function" then
		bar._onLayoutResolved(layout, bar)
	end
	return layout
end

function HeaderBar:LayoutHost(host, bar, layoutWidth)
	if not host or not bar or host:IsShown() ~= true then
		return nil
	end
	return self:Layout(bar, layoutWidth or host:GetWidth())
end

local function refreshHeaderLabels(bar)
	local pool = bar and bar.headers and bar.headers.columnHeaders
	if not pool then
		return false
	end
	for header in pool:EnumerateActive() do
		local columnID = header._gfColumnID
			or (bar._activeIds and bar._activeIds[header:GetID()])
		header:SetText(columnID and columnLabel(bar, columnID) or "")
		applyHeaderFont(header:GetFontString())
		paintHeaderText(header)
	end
	return true
end

function HeaderBar:RefreshLocale(bar)
	if bar then
		return refreshHeaderLabels(bar)
	end
	local refreshed = 0
	for liveBar in pairs(self._liveBars) do
		if refreshHeaderLabels(liveBar) then
			refreshed = refreshed + 1
		end
	end
	return refreshed
end

local function notifyLayoutChanged(bar)
	if bar and type(bar._onLayoutChange) == "function" then
		bar._onLayoutChange()
	end
end

local function relayoutAfterMenu(bar)
	HeaderBar:Layout(bar)
	notifyLayoutChanged(bar)
end

local function orderIndex(order, columnID)
	for index, currentID in ipairs(order or {}) do
		if currentID == columnID then
			return index
		end
	end
	return nil
end

local function buildColumnMenu(bar, profile, anchorColumnID)
	if not (Model and Model.GetColumnOrder) then
		return {}
	end
	local order = Model:GetColumnOrder(profile)
	local position = orderIndex(order, anchorColumnID)
	local menu = {
		{
			text = localeText("COL_MENU_MOVE_LEFT", "Move left"),
			disabled = not position or position <= 1,
			action = function()
				if Model:MoveColumn(profile, anchorColumnID, -1) then
					relayoutAfterMenu(bar)
				end
			end,
		},
		{
			text = localeText("COL_MENU_MOVE_RIGHT", "Move right"),
			disabled = not position or position >= #order,
			action = function()
				if Model:MoveColumn(profile, anchorColumnID, 1) then
					relayoutAfterMenu(bar)
				end
			end,
		},
		{ separator = true },
	}
	for _, id in ipairs(order) do
		local columnID = id
		if not Model:IsColumnNoHide(profile, columnID) then
			menu[#menu + 1] = {
				text = Model:GetHeaderLabel(columnID, profile),
				checked = function()
					return Model:GetColumnVisible(profile)[columnID] ~= false
				end,
				action = function()
					local visible =
						Model:GetColumnVisible(profile)[columnID] ~= false
					if Model:SetColumnVisible(profile, columnID, not visible) then
						relayoutAfterMenu(bar)
					end
				end,
			}
		end
	end
	return menu
end

local function openModernMenu(owner, entries)
	local motionRegistered = false
	local menu = MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
		if GF.UI and GF.UI.InstallMenuOpenAnimation then
			motionRegistered = GF.UI.InstallMenuOpenAnimation(
				root, { preset = "menu", groupFinderOwned = true })
		end
		for _, descriptor in ipairs(entries) do
			local entry = descriptor
			if entry.separator == true then
				root:CreateDivider()
			elseif type(entry.checked) == "function" then
				root:CreateCheckbox(entry.text, entry.checked, function()
					entry.action()
					return MenuResponse and MenuResponse.Refresh or nil
				end)
			else
				local item = root:CreateButton(entry.text, entry.action)
				if entry.disabled and item and item.SetEnabled then
					item:SetEnabled(false)
				end
			end
		end
	end)
	if menu and not motionRegistered
		and GF.UI and GF.UI.PlayPopupOpenAnimation
	then
		GF.UI.PlayPopupOpenAnimation(
			menu, { preset = "menu", groupFinderOwned = true })
	end
	return menu
end

function HeaderBar:ShowContextMenu(bar, anchorColumnID, owner)
	if not bar or not anchorColumnID then
		return nil
	end
	self:RefreshProfile(bar)
	local entries = buildColumnMenu(bar, bar._profile, anchorColumnID)
	if MenuUtil and MenuUtil.CreateContextMenu then
		return openModernMenu(owner or bar, entries)
	end
	return nil
end
