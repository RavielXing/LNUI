local _, GF = ...



GF.SubtitleBar = {}

local SB = GF.SubtitleBar



local BB = GF.BlizzardBorrow
local SEARCH_FIELD_OWNER = "groupfinder"
local SEARCH_FIELD_CHANNEL = "search"



local RIGHT_PAD = GF.SUBTITLE_CONTROL_RIGHT_PAD or 10

local LEFT_PAD = GF.SUBTITLE_CONTROL_LEFT_PAD or 15

local GAP = GF.SUBTITLE_CONTROL_GAP or 7

local HEADER_REFRESH_TEXTURE = GF.BROWSE_HEADER_REFRESH_TEXTURE or GF.REFRESH_TEXTURE

local SEARCH_BOX_SCRIPT_NAMES = {
	"OnEnterPressed",
	"OnTextChanged",
	"OnEditFocusGained",
	"OnEditFocusLost",
	"OnArrowPressed",
	"OnTabPressed",
}

local AUTO_COMPLETE_POPUP_STRATA = {
	BACKGROUND = "LOW",
	LOW = "MEDIUM",
	MEDIUM = "HIGH",
	HIGH = "DIALOG",
	DIALOG = "FULLSCREEN_DIALOG",
	FULLSCREEN = "FULLSCREEN_DIALOG",
	FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
	TOOLTIP = "TOOLTIP",
}

local AUTO_COMPLETE_OCCLUDER_INSET_L = 10
local AUTO_COMPLETE_OCCLUDER_INSET_R = 10
local AUTO_COMPLETE_OCCLUDER_INSET_T = 4
local AUTO_COMPLETE_OCCLUDER_INSET_B = 12

local function resolveAutoCompleteStrata(parent)
	local strata = parent and parent.GetFrameStrata and parent:GetFrameStrata()
	return AUTO_COMPLETE_POPUP_STRATA[strata] or "DIALOG"
end

local function snapshotFrameLayer(widget)
	if not widget then
		return nil
	end
	return {
		frameLevel = widget.GetFrameLevel and widget:GetFrameLevel() or nil,
		frameStrata = widget.GetFrameStrata and widget:GetFrameStrata() or nil,
		toplevel = widget.IsToplevel and widget:IsToplevel() or nil,
	}
end

local function restoreFrameLayer(widget, layer)
	if not widget or not layer then
		return
	end
	if layer.frameStrata and widget.SetFrameStrata then
		widget:SetFrameStrata(layer.frameStrata)
	end
	if layer.toplevel ~= nil and widget.SetToplevel then
		widget:SetToplevel(layer.toplevel)
	end
	if layer.frameLevel and widget.SetFrameLevel then
		widget:SetFrameLevel(layer.frameLevel)
	end
end

local function setAutoCompleteOccluderShown(ac, shown)
	if not ac then
		return
	end
	local tex = ac._gfAutoCompleteOccluder
	if not tex then
		tex = ac:CreateTexture(nil, "BACKGROUND", nil, -8)
		if tex.SetColorTexture then
			tex:SetColorTexture(0, 0, 0, 1)
		else
			tex:SetTexture(GF.WHITE_TEXTURE or "Interface\\Buttons\\WHITE8X8")
			tex:SetVertexColor(0, 0, 0, 1)
		end
		ac._gfAutoCompleteOccluder = tex
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", ac, "TOPLEFT", AUTO_COMPLETE_OCCLUDER_INSET_L, -AUTO_COMPLETE_OCCLUDER_INSET_T)
	tex:SetPoint("BOTTOMRIGHT", ac, "BOTTOMRIGHT", -AUTO_COMPLETE_OCCLUDER_INSET_R, AUTO_COMPLETE_OCCLUDER_INSET_B)
	if shown then
		tex:Show()
	else
		tex:Hide()
	end
end

local function setHeaderRefreshIconPressed(button, pressed)
	local icon = button and button.Icon
	if not icon then
		return
	end
	local normalSize = GF.BROWSE_HEADER_REFRESH_ICON_SIZE or 21
	local pressedSize = GF.BROWSE_HEADER_REFRESH_ICON_PRESSED_SIZE or 19
	icon:ClearAllPoints()
	if pressed then
		icon:SetSize(pressedSize, pressedSize)
		icon:SetPoint("CENTER", button, "CENTER", 1, -1)
		icon:SetAlpha(0.86)
	else
		icon:SetSize(normalSize, normalSize)
		icon:SetPoint("CENTER", button, "CENTER", 0, 0)
		icon:SetAlpha(1)
	end
end

local function setHeaderRefreshButtonPending(button, pending)
	if not button then
		return
	end
	pending = pending == true
	button._gfHeaderRefreshPending = pending or nil
	if GF.UI and GF.UI.SetButtonPendingSpinner then
		GF.UI.SetButtonPendingSpinner(button, pending, GF.BROWSE_HEADER_REFRESH_PENDING_SPINNER_SIZE or GF.SEARCH_BUTTON_PENDING_SPINNER_SIZE or 18)
	end
	if button.Icon then
		button.Icon:SetShown(not pending)
		if not pending then
			setHeaderRefreshIconPressed(button, false)
		end
	end
	if pending and button.SetAlpha then
		button:SetAlpha(1)
	end
end

local function setHeaderRefreshButtonEnabled(button, enabled)
	if not button then
		return
	end
	if button._gfHeaderRefreshPending then
		button:Disable()
		setHeaderRefreshIconPressed(button, false)
		if button.SetAlpha then
			button:SetAlpha(1)
		end
		return
	end
	if enabled then
		button:Enable()
	else
		button:Disable()
		setHeaderRefreshIconPressed(button, false)
	end
	if button.SetAlpha then
		button:SetAlpha(enabled and 1 or 0.45)
	end
end

local function setFontStringColor(fontString, color)
	if not fontString then
		return
	end
	color = color or GF.SUBTITLE_OPTION_TEXT_COLOR or { 1, 0.82, 0, 1 }
	fontString:SetTextColor(color[1] or 1, color[2] or 0.82, color[3] or 0, color[4] or 1)
end

local function snapshotWidgetLayout(widget)
	if not widget then
		return nil
	end
	local points = {}
	for i = 1, widget:GetNumPoints() do
		points[i] = { widget:GetPoint(i) }
	end
	local w, h = widget:GetSize()
	local layer = snapshotFrameLayer(widget) or {}
	return {
		parent = widget:GetParent(),
		points = points,
		width = w,
		height = h,
		frameLevel = layer.frameLevel,
		frameStrata = layer.frameStrata,
		toplevel = layer.toplevel,
		shown = widget.IsShown and widget:IsShown() or true,
	}
end

local function restoreWidgetLayout(widget, layout)
	if not widget or not layout then
		return false
	end
	widget:SetParent(layout.parent or UIParent)
	widget:ClearAllPoints()
	for _, pt in ipairs(layout.points or {}) do
		widget:SetPoint(unpack(pt))
	end
	if layout.width and layout.height and layout.width > 0 and layout.height > 0 then
		widget:SetSize(layout.width, layout.height)
	end
	restoreFrameLayer(widget, layout)
	if widget.SetShown then
		widget:SetShown(layout.shown ~= false)
	elseif layout.shown == false and widget.Hide then
		widget:Hide()
	elseif widget.Show then
		widget:Show()
	end
	return true
end

local function snapshotSearchBoxScripts(searchBox)
	if not searchBox or not searchBox.GetScript then
		return nil
	end
	local scripts = {}
	for _, name in ipairs(SEARCH_BOX_SCRIPT_NAMES) do
		scripts[name] = searchBox:GetScript(name)
	end
	if searchBox.clearButton and searchBox.clearButton.GetScript then
		scripts.clearButtonOnClick = searchBox.clearButton:GetScript("OnClick")
	end
	return scripts
end

local function restoreSearchBoxScripts(searchBox, scripts)
	if not searchBox or not scripts or not searchBox.SetScript then
		return
	end
	for _, name in ipairs(SEARCH_BOX_SCRIPT_NAMES) do
		searchBox:SetScript(name, scripts[name])
	end
	if searchBox.clearButton and searchBox.clearButton.SetScript then
		searchBox.clearButton:SetScript("OnClick", scripts.clearButtonOnClick)
	end
end

local function createBrowseOptionCheck(parent, label, tooltip, onClick)
	local btn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	local size = GF.SUBTITLE_OPTION_CHECK_SIZE or 22
	local textGap = GF.SUBTITLE_OPTION_TEXT_GAP or 1
	btn:SetSize(size, size)
	btn.Label = GF.UI.CreateFontString(btn, "OVERLAY", "GameFontNormal")
	btn.Label._gfFontSizeOverride = GF.SUBTITLE_OPTION_TEXT_SIZE or 13
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(btn.Label, "GameFontNormal")
	end
	btn.Label:SetPoint("LEFT", btn, "RIGHT", textGap, 0)
	btn.Label:SetText(label or "")
	setFontStringColor(btn.Label)
	btn:SetHitRectInsets(0, -math.ceil((btn.Label:GetStringWidth() or 0) + textGap + 4), 0, 0)
	btn._gfTextGap = textGap
	btn._gfTooltip = tooltip
	btn:SetScript("OnClick", function(self)
		if onClick then
			onClick(self, self:GetChecked() == true)
		end
	end)
	if tooltip and tooltip ~= "" then
		btn:SetScript("OnEnter", function(self)
			GF.UI.ShowSimpleTooltipAbove(self, self._gfTooltip or "", "LEFT")
		end)
		btn:SetScript("OnLeave", GameTooltip_Hide)
	end
	return btn
end

local function updateBrowseOptionCheckText(btn, label, tooltip)
	if not btn then
		return
	end
	if btn.Label then
		btn.Label:SetText(label or "")
	end
	btn._gfTooltip = tooltip
	local textGap = btn._gfTextGap or GF.SUBTITLE_OPTION_TEXT_GAP or 1
	local width = btn.Label and btn.Label:GetStringWidth() or 0
	btn:SetHitRectInsets(0, -math.ceil(width + textGap + 4), 0, 0)
end

local function setCategoryAccentGradient(texture, startAlpha, endAlpha)
	if not texture then
		return
	end
	local color = GF.BROWSE_HEADER_ACCENT_COLOR or { 126 / 255, 112 / 255, 82 / 255 }
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

local function layoutCategoryAccent(accent)
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

local function createCategoryAccent(parent)
	local accent = CreateFrame("Frame", nil, parent)
	local top = accent:CreateTexture(nil, "OVERLAY")
	top:SetTexture(GF.BROWSE_HEADER_ACCENT_TEXTURE or GF.WHITE_TEXTURE)
	setCategoryAccentGradient(top, GF.BROWSE_HEADER_ACCENT_ALPHA or 0.6, 0)
	local bottom = accent:CreateTexture(nil, "OVERLAY")
	bottom:SetTexture(GF.BROWSE_HEADER_ACCENT_TEXTURE or GF.WHITE_TEXTURE)
	setCategoryAccentGradient(bottom, 0, GF.BROWSE_HEADER_ACCENT_ALPHA or 0.6)
	accent.top = top
	accent.bottom = bottom
	layoutCategoryAccent(accent)
	return accent
end



local function getLfgSearchPanel()

	return LFGListFrame and LFGListFrame.SearchPanel

end



local function isBrowseTabSelected()

	if not GF.TabBar or not GF.TabBar.GetCurrent then

		return false

	end

	if GF.TabBar:GetCurrent() ~= GF.TAB_BROWSE then

		return false

	end

	local mf = GF.MainFrame and GF.MainFrame.frame

	return mf and mf:IsShown()

end



local function isBlizzardSearchPanelActive()

	local lfg = LFGListFrame

	if not lfg or not lfg.IsVisible or not lfg:IsVisible() then

		return false

	end

	return lfg.SearchPanel and lfg.activePanel == lfg.SearchPanel

end

local function getFindGroupSelection()
	if GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		return GF.FindGroupTab:GetSelection()
	end
	return GF.MainFrame and GF.MainFrame.selection
end

local function isFindGroupSelectionSearchable()
	local selection = getFindGroupSelection()
	if GF.FindGroupTab and GF.FindGroupTab.IsSearchableSelection then
		return GF.FindGroupTab:IsSearchableSelection(selection) ~= false
	end
	return selection ~= nil
end

local function isBrowseSearchPending()
	local bp = GF.FindGroupTab and GF.FindGroupTab.GetPanel and GF.FindGroupTab:GetPanel()
	if bp and bp.IsSearchPending then
		return bp:IsSearchPending()
	end
	return GF.searching == true
end



local function resolveScope(node)

	node = node or (GF.MainFrame and GF.MainFrame.selection)

	if not node or not node.categoryID then

		return nil

	end

	return GF.NavData and GF.NavData.ResolveSearchScope(node) or node

end



local function categorySyncKey(scope, node)
	local categoryID = scope.categoryID or node.categoryID
	local filters = scope.filters
	if filters == nil and GF.Filter and GF.Filter.ResolveCategoryFilters then
		filters = GF.Filter:ResolveCategoryFilters(categoryID, node.filters or 0)
	end
	return string.format(
		"%s|%s|%s|%s|%s",
		tostring(categoryID or 0),
		tostring(filters or 0),
		tostring(scope.preferredFilters or node.preferredFilters or Enum.LFGListFilter.PvE),
		tostring(scope.groupID or node.groupID or ""),
		tostring(scope.activityID or node.activityID or "")
	)
end

function SB:SyncSearchPanelCategory(node)

	local panel = getLfgSearchPanel()

	node = node or (GF.MainFrame and GF.MainFrame.selection)

	if not panel or not node or not node.categoryID then

		return

	end

	local scope = resolveScope(node) or node

	local syncKey = categorySyncKey(scope, node)
	if syncKey == self._gfCategorySyncKey then
		return
	end
	self._gfCategorySyncKey = syncKey

	local categoryID = scope.categoryID or node.categoryID

	local filters = scope.filters

	if not filters and GF.Filter and GF.Filter.ResolveCategoryFilters then

		filters = GF.Filter:ResolveCategoryFilters(categoryID, node.filters or 0)

	end

	filters = filters or 0

	local preferred = scope.preferredFilters or node.preferredFilters or Enum.LFGListFilter.PvE

	if LFGListSearchPanel_SetCategory then

		pcall(LFGListSearchPanel_SetCategory, panel, categoryID, filters, preferred)

	end

end



function SB:IsBorrowingSearchBox()

	local panel = getLfgSearchPanel()

	local box = panel and panel.SearchBox

	return box and self.searchHost and box:GetParent() == self.searchHost

end

function SB:PositionAutoCompleteFrame(panel)
	panel = panel or getLfgSearchPanel()
	local ac = panel and panel.AutoCompleteFrame
	local searchBox = panel and panel.SearchBox
	if not ac or not searchBox or not self.frame then
		return
	end

	local parent = GF.MainFrame and GF.MainFrame.frame or self.frame
	ac:SetParent(parent)
	ac:ClearAllPoints()
	-- Keep Blizzard's native downward autocomplete placement, but parent it to the
	-- main frame and raise it as a popup so panel overlay lines cannot cross it.
	ac:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -2, 0)
	ac:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", -4, 0)
	local popupStrata = resolveAutoCompleteStrata(parent)
	if ac.SetFrameStrata then
		ac:SetFrameStrata(popupStrata)
	end
	if ac.SetToplevel then
		ac:SetToplevel(true)
	end
	if ac.SetFrameLevel and self.frame.GetFrameLevel and parent.GetFrameLevel then
		local level = math.max(self.frame:GetFrameLevel() + 120, parent:GetFrameLevel() + 200)
		ac:SetFrameLevel(level)
		local results = ac.Results
		if results then
			for i, button in ipairs(results) do
				if button and not button._gfAutoCompleteLayerSaved then
					button._gfOriginalAutoCompleteLayer = snapshotFrameLayer(button)
					button._gfAutoCompleteLayerSaved = true
				end
				if button and button.SetFrameStrata then
					button:SetFrameStrata(popupStrata)
				end
				if button and button.SetFrameLevel then
					button:SetFrameLevel(level + i)
				end
			end
		end
	end
	setAutoCompleteOccluderShown(ac, true)
	if ac.Raise then
		ac:Raise()
	end
end

function SB:RestoreAutoCompleteButtonScripts(panel)
	local ac = panel and panel.AutoCompleteFrame
	local results = ac and ac.Results
	if not results then
		return
	end
	for _, button in ipairs(results) do
		if button then
			if button._gfAutoCompleteScriptSaved and button.SetScript then
				button:SetScript("OnClick", button._gfOriginalAutoCompleteOnClick)
				button._gfOriginalAutoCompleteOnClick = nil
				button._gfAutoCompleteScriptSaved = nil
				button._gfAutoCompleteOwner = nil
			end
			if button._gfAutoCompleteLayerSaved then
				restoreFrameLayer(button, button._gfOriginalAutoCompleteLayer)
				button._gfOriginalAutoCompleteLayer = nil
				button._gfAutoCompleteLayerSaved = nil
			end
		end
	end
end

function SB:AcceptAutoCompleteActivity(activityID)
	activityID = tonumber(activityID)
	if not activityID or activityID <= 0 then
		return false
	end

	local node = GF.NavData and GF.NavData.FindNodeByActivityID and GF.NavData.FindNodeByActivityID(activityID)
	if not node then
		return false
	end

	if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	elseif GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("check")
	end

	if GF.NavTree and GF.NavTree.SetSelected then
		GF.NavTree:SetSelected(node)
	elseif GF.MainFrame and GF.MainFrame.OnSelectionChanged then
		GF.MainFrame:OnSelectionChanged(node)
	end

	local panel = getLfgSearchPanel()
	if panel and panel.AutoCompleteFrame then
		panel.AutoCompleteFrame.selected = nil
		panel.AutoCompleteFrame:Hide()
	end

	self:ClearSearchText()
	self:SyncSearchPanelCategory(node)

	if GF.FindGroupTab and GF.FindGroupTab.DoSearch then
		GF.FindGroupTab:DoSearch()
	end
	return true
end

function SB:InstallAutoCompleteButtonScripts(panel)
	if not self:IsBorrowingSearchBox() then
		return
	end
	local ac = panel and panel.AutoCompleteFrame
	local results = ac and ac.Results
	if not results then
		return
	end
	for _, button in ipairs(results) do
		if button and button.SetScript then
			if not button._gfAutoCompleteScriptSaved then
				button._gfOriginalAutoCompleteOnClick = button.GetScript and button:GetScript("OnClick") or nil
				button._gfAutoCompleteScriptSaved = true
			end
			if button._gfAutoCompleteOwner ~= self then
				button:SetScript("OnClick", function(btn)
					SB:AcceptAutoCompleteActivity(btn.activityID)
				end)
				button._gfAutoCompleteOwner = self
			end
		end
	end
end



function SB:InstallSearchBoxScripts(searchBox, panel)

	if not searchBox then

		return

	end

	searchBox._gfLfgSearchPanel = panel



	local function resolvePanel()

		local p = searchBox._gfLfgSearchPanel

		if p and p.SearchBox == searchBox then

			return p

		end

		return getLfgSearchPanel()

	end



	local function updateAutoComplete()

		local p = resolvePanel()

		if p and LFGListSearchPanel_UpdateAutoComplete then

			local ok = pcall(LFGListSearchPanel_UpdateAutoComplete, p)
			if ok then
				SB:PositionAutoCompleteFrame(p)
				SB:InstallAutoCompleteButtonScripts(p)
			end

		end

	end



	searchBox:SetScript("OnEnterPressed", function(edit)
		local p = resolvePanel()
		local ac = p and p.AutoCompleteFrame
		if ac and ac:IsShown() and ac.selected and SB:AcceptAutoCompleteActivity(ac.selected) then
			return
		end
		if GF.FindGroupTab then
			GF.FindGroupTab:DoSearch()
		end

		edit:ClearFocus()

	end)



	searchBox:SetScript("OnTextChanged", function(edit)

		if SearchBoxTemplate_OnTextChanged then

			SearchBoxTemplate_OnTextChanged(edit)

		end

		updateAutoComplete()
		SB:UpdateResetButtonState()

	end)



	searchBox:SetScript("OnEditFocusGained", function(edit)

		updateAutoComplete()

		if SearchBoxTemplate_OnEditFocusGained then

			SearchBoxTemplate_OnEditFocusGained(edit)

		end

	end)



	searchBox:SetScript("OnEditFocusLost", function(edit)

		updateAutoComplete()

		if SearchBoxTemplate_OnEditFocusLost then

			SearchBoxTemplate_OnEditFocusLost(edit)

		end

	end)



	searchBox:SetScript("OnArrowPressed", function(edit, key)

		local p = resolvePanel()

		if not p or not LFGListSearchPanel_AutoCompleteAdvance then

			return

		end

		if key == "UP" then

			pcall(LFGListSearchPanel_AutoCompleteAdvance, p, -1)

		elseif key == "DOWN" then

			pcall(LFGListSearchPanel_AutoCompleteAdvance, p, 1)

		end

	end)



	searchBox:SetScript("OnTabPressed", function()

		local p = resolvePanel()

		if not p or not LFGListSearchPanel_AutoCompleteAdvance then

			return

		end

		local offset = IsShiftKeyDown() and -1 or 1

		pcall(LFGListSearchPanel_AutoCompleteAdvance, p, offset)

	end)



	if searchBox.clearButton then

		searchBox.clearButton:SetScript("OnClick", function()

			-- Secure LFGListSearchBox: use Blizzard API, not addon SetText/ClearText.

			if C_LFGList and C_LFGList.ClearSearchTextFields then

				pcall(C_LFGList.ClearSearchTextFields)

			end

			updateAutoComplete()
			SB:UpdateResetButtonState()

			if searchBox.ClearFocus then

				searchBox:ClearFocus()

			end

		end)

	end

end



function SB:PrecacheSearchWidgets()

	if self._searchPrecached then

		return

	end

	local panel = getLfgSearchPanel()

	if not panel then

		return

	end

	if panel.SearchBox then

		BB.CacheLayout(panel.SearchBox)

	end

	if panel.AutoCompleteFrame then

		BB.CacheLayout(panel.AutoCompleteFrame)

	end

	self._searchPrecached = true

end



function SB:AttachBlizzardSearchBox()

	if not isBrowseTabSelected() then

		return false

	end

	if isBlizzardSearchPanelActive() then

		return false

	end

	local panel = getLfgSearchPanel()

	if not panel or not panel.SearchBox or not self.searchHost then

		return false

	end

	if self:IsBorrowingSearchBox() then

		self:SyncSearchPanelCategory()

		return true

	end

	local searchBox = panel.SearchBox
	local ac = panel.AutoCompleteFrame

	self._searchBorrowReturnLayout = snapshotWidgetLayout(searchBox)
	self._searchBorrowReturnAutoCompleteLayout = snapshotWidgetLayout(ac)
	self._searchBorrowReturnScripts = snapshotSearchBoxScripts(searchBox)



	self:PrecacheSearchWidgets()

	self:SyncSearchPanelCategory()



	self:InstallSearchBoxScripts(searchBox, panel)



	local w = GF.SUBTITLE_SEARCH_W or 220
	local h = GF.SUBTITLE_SEARCH_H or 26

	self.searchHost:SetSize(w, h)
	BB.EmbedFill(searchBox, self.searchHost, self.searchHost, w, h)
	BB.MarkBorrowed(searchBox, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
	searchBox._gfUsesNativeSearchBox = true
	if GF.UI and GF.UI.StyleBrowseSearchBox then
		local L = GF.L or {}
		GF.UI.StyleBrowseSearchBox(searchBox, L.SEARCH_PLACEHOLDER or "Search groups...")
	end



	if ac then

		self:PositionAutoCompleteFrame(panel)

	end



	self.searchBox = searchBox

	self._searchAttached = true
	self:UpdateResetButtonState()

	return true

end



function SB:ReleaseBlizzardSearchBox()

	if not isBrowseTabSelected() then
		self:StopSearchBoxOwnershipWatch()
	end

	if not self:IsBorrowingSearchBox() and not self._searchAttached then

		self.searchBox = nil

		return

	end

	local panel = getLfgSearchPanel()

	if not self:IsBorrowingSearchBox() then

		if panel and panel.SearchBox then
			panel.SearchBox._gfUsesNativeSearchBox = nil
			BB.ClearBorrowed(panel.SearchBox, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
		end
		self:RestoreAutoCompleteButtonScripts(panel)
		if panel and panel.AutoCompleteFrame then
			setAutoCompleteOccluderShown(panel.AutoCompleteFrame, false)
		end

		self.searchBox = nil

		self._searchAttached = false

		self._searchBorrowReturnLayout = nil

		self._searchBorrowReturnAutoCompleteLayout = nil

		self._searchBorrowReturnScripts = nil

		return

	end

	if panel then

		if panel.SearchBox then

			local restored = restoreWidgetLayout(panel.SearchBox, self._searchBorrowReturnLayout)

			if not restored then

				BB.RestoreLayout(panel.SearchBox)

				panel.SearchBox:Show()

			end

			panel.SearchBox._gfUsesNativeSearchBox = nil
			BB.ClearBorrowed(panel.SearchBox, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
			restoreSearchBoxScripts(panel.SearchBox, self._searchBorrowReturnScripts)

		end

			if panel.AutoCompleteFrame then

				self:RestoreAutoCompleteButtonScripts(panel)
				setAutoCompleteOccluderShown(panel.AutoCompleteFrame, false)

				local restored = restoreWidgetLayout(panel.AutoCompleteFrame, self._searchBorrowReturnAutoCompleteLayout)

			if not restored then

				BB.RestoreLayout(panel.AutoCompleteFrame)

				panel.AutoCompleteFrame:Hide()

			end

		end

	end

	self.searchBox = nil

	self._searchAttached = false

	self._searchBorrowReturnLayout = nil

	self._searchBorrowReturnAutoCompleteLayout = nil

	self._searchBorrowReturnScripts = nil

end



function SB:TryAttachSearchBox()

	if isBrowseTabSelected() and not isBlizzardSearchPanelActive() then

		return self:EnsureSearchBoxOwnership()

	end

	return false

end

function SB:EnsureSearchBoxOwnership()
	if not self._browseMode or not isBrowseTabSelected() then
		if self:IsBorrowingSearchBox() then
			self:ReleaseBlizzardSearchBox()
		end
		return false
	end
	if isBlizzardSearchPanelActive() then
		if self:IsBorrowingSearchBox() then
			self:ReleaseBlizzardSearchBox()
		end
		return false
	end
	return self:AttachBlizzardSearchBox()
end

function SB:StartSearchBoxOwnershipWatch()
	if self._searchOwnershipTicker or not C_Timer or not C_Timer.NewTicker then
		return
	end
	local interval = GF.SUBTITLE_SEARCH_OWNERSHIP_POLL_SEC or 0.5
	self._searchOwnershipTicker = C_Timer.NewTicker(interval, function()
		if not SB._browseMode or not isBrowseTabSelected() then
			SB:StopSearchBoxOwnershipWatch()
			if SB:IsBorrowingSearchBox() then
				SB:ReleaseBlizzardSearchBox()
			end
			return
		end
		SB:EnsureSearchBoxOwnership()
	end)
end

function SB:StopSearchBoxOwnershipWatch()
	if self._searchOwnershipTicker and self._searchOwnershipTicker.Cancel then
		self._searchOwnershipTicker:Cancel()
	end
	self._searchOwnershipTicker = nil
end

function SB:ReclaimSearchBoxForBrowse()
	if not isBrowseTabSelected() then
		return false
	end
	self._browseMode = true
	self:StartSearchBoxOwnershipWatch()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if SB._browseMode and isBrowseTabSelected() then
				SB:EnsureSearchBoxOwnership()
			end
		end)
		return true
	end
	return self:EnsureSearchBoxOwnership()
end



function SB:InstallSearchHandoffHooks()

	if self._searchHooksInstalled or not hooksecurefunc then

		return

	end

	self._searchHooksInstalled = true

	if LFGListFrame_SetActivePanel then

		hooksecurefunc("LFGListFrame_SetActivePanel", function(_lfg, panel)

			local lfg = LFGListFrame

			if not lfg or not lfg.SearchPanel then

				return

			end

			if panel == lfg.SearchPanel and SB:IsBorrowingSearchBox() then
				if BB and BB.SetActiveOwner then
					BB.SetActiveOwner("blizzard")
				end

				SB:ReleaseBlizzardSearchBox()

			elseif panel ~= lfg.SearchPanel and isBrowseTabSelected() then

				if C_Timer and C_Timer.After then

					C_Timer.After(0, function()

						SB:TryAttachSearchBox()

					end)

				else

					SB:TryAttachSearchBox()

				end

			end

		end)

	end

end



function SB:Init(parent, topY)

	self.parent = parent

	local L = GF.L or {}

	local pad = GF.FRAME_PAD or 4
	local insetX = (topY == 0) and 0 or pad

	self.frame = CreateFrame("Frame", nil, parent)

	self.frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", insetX, 0)

	self.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -insetX, 0)

	self.frame:SetHeight(GF.SUBTITLE_H)

	self.frame:SetFrameLevel(parent:GetFrameLevel() + 30)
	if GF.UI and GF.UI.InstallBrowseControlBarChrome then
		GF.UI.InstallBrowseControlBarChrome(self.frame)
	end

	local controlCenterY = GF.SUBTITLE_CONTROL_CENTER_OFFSET_Y or 0

	self.filterBtn = GF.UI.CreatePanelButton(self.frame, L.FILTER or "Filter", GF.PANEL_BUTTON_TWO_CHAR_W, true)
	self.filterBtn:SetPoint("RIGHT", self.frame, "RIGHT", -RIGHT_PAD, controlCenterY)

	self.filterBtn:SetScript("OnClick", function()

		if GF.FilterPanel and GF.MainFrame and GF.MainFrame.frame then

			GF.FilterPanel:Toggle()

		end

	end)



	self.signUpBtn = GF.UI.CreatePanelButton(self.frame, L.SIGN_UP or "Sign Up", GF.PANEL_BUTTON_TWO_CHAR_W, true)

	self.signUpBtn:SetPoint("RIGHT", self.filterBtn, "LEFT", -GAP, 0)

	self.signUpBtn:SetScript("OnClick", function()
		if GF.FindGroupTab then
			GF.FindGroupTab:SignUp()
		end
	end)
	self:UpdateSignUpButtonState()

	local searchW = GF.SUBTITLE_SEARCH_W or 220
	local searchH = GF.SUBTITLE_SEARCH_H or 26

	self.searchHost = CreateFrame("Frame", nil, self.frame)
	self.searchHost:SetSize(searchW, searchH)
	self.searchHost:SetPoint("LEFT", self.frame, "LEFT", LEFT_PAD, controlCenterY)

	self.searchBox = nil

	self.refreshBtn = GF.UI.CreatePanelButton(self.frame, L.SEARCH or "Search", GF.PANEL_BUTTON_TWO_CHAR_W, true)
	self.refreshBtn:SetPoint("LEFT", self.searchHost, "RIGHT", GAP, 0)

	self.refreshBtn:SetScript("OnClick", function()
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		if GF.FindGroupTab then
			GF.FindGroupTab:DoSearch()
		end
	end)
	self.refreshBtn:SetScript("OnEnter", function(btn)
		local LL = GF.L or {}
		local label = SB:GetRefreshButtonLabel()
		local isRefresh = label == (LL.REFRESH or "Refresh")
		GF.UI.BeginGameTooltipAbove(btn, "LEFT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(label, 1, 0.82, 0, true)
		GameTooltip:AddLine(isRefresh and (LL.BROWSE_REFRESH_SEARCH_TIP or "重新检索队伍列表") or (LL.BROWSE_SEARCH_REFRESH_TIP or "检索队伍列表"), 1, 1, 1, true)
		GF.UI.ShowGameTooltip()
	end)
	self.refreshBtn:SetScript("OnLeave", GameTooltip_Hide)

	self.resetBtn = GF.UI.CreatePanelButton(self.frame, L.RESET or L.FILTER_RESET or "Reset", GF.PANEL_BUTTON_TWO_CHAR_W, true)
	self.resetBtn:SetPoint("LEFT", self.refreshBtn, "RIGHT", GAP, 0)
	self.resetBtn:SetScript("OnClick", function()
		SB:ResetBrowse()
	end)
	self.resetBtn:SetScript("OnEnter", function(btn)
		local LL = GF.L or {}
		GF.UI.ShowSimpleTooltipAbove(btn, LL.BROWSE_RESET_SEARCH_TIP or "清空并停止当前的搜索状态", "LEFT")
	end)
	self.resetBtn:SetScript("OnLeave", GameTooltip_Hide)

	self.quickJoinCheck = createBrowseOptionCheck(self.frame, L.QUICK_JOIN or "双击加入", L.QUICK_JOIN_TIP or "", function(_, checked)
		SB:SetQuickJoinEnabled(checked)
	end)
	self.quickJoinCheck:SetPoint("LEFT", self.resetBtn, "RIGHT", GAP + 8, 0)

	self.autoJoinCheck = createBrowseOptionCheck(self.frame, L.AUTO_JOIN or "自动进组", L.AUTO_JOIN_TIP or "", function(_, checked)
		SB:SetAutoJoinEnabled(checked)
	end)
	self.autoJoinCheck:SetPoint("LEFT", self.quickJoinCheck.Label, "RIGHT", GF.SUBTITLE_OPTION_GROUP_GAP or 12, 0)

	self.categoryHost = CreateFrame("Frame", nil, self.frame)
	self.categoryHost:SetPoint("LEFT", self.autoJoinCheck.Label, "RIGHT", GAP + 8, 0)
	self.categoryHost:SetPoint("RIGHT", self.signUpBtn, "LEFT", -GAP, 0)
	self.categoryHost:SetHeight(GF.BROWSE_CONTROL_BACKGROUND_H or GF.SUBTITLE_HEADER_H or 26)
	self.categoryHost:SetWidth(GF.SUBTITLE_CATEGORY_MIN_W or 140)
	self.categoryHost:EnableMouse(true)
	self.categoryHost:SetScript("OnEnter", function(owner)
		local text = SB.selectionLabel
		if text and text ~= "" then
			GF.UI.ShowSimpleTooltipAbove(owner, text, "LEFT")
		end
	end)
	self.categoryHost:SetScript("OnLeave", GameTooltip_Hide)
	self.categoryAccentLeft = createCategoryAccent(self.categoryHost)
	self.categoryAccentLeft:SetPoint("CENTER", self.categoryHost, "LEFT", 0, 0)
	self.categoryAccentRight = createCategoryAccent(self.categoryHost)
	self.categoryAccentRight:SetPoint("CENTER", self.categoryHost, "RIGHT", 0, 0)

	self.categoryLabel = GF.UI.CreateFontString(self.categoryHost, "OVERLAY", "GameFontHighlight")
	self.categoryLabel._gfFontSizeOverride = GF.SUBTITLE_CATEGORY_TEXT_SIZE or 13
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(self.categoryLabel, "GameFontHighlight")
	end
	self.categoryLabel:SetPoint("LEFT", self.categoryAccentLeft, "RIGHT", GF.SUBTITLE_CATEGORY_ACCENT_GAP or 10, 0)
	self.categoryLabel:SetPoint("RIGHT", self.categoryAccentRight, "LEFT", -(GF.SUBTITLE_CATEGORY_ACCENT_GAP or 10), 0)
	self.categoryLabel:SetJustifyH("CENTER")
	self.categoryLabel:SetWordWrap(false)
	self.categoryLabel:SetMaxLines(1)
	self.categoryLabel:SetTextColor(1, 0.82, 0)
	self.categoryHost:Hide()

	self.browseNotice = GF.UI.CreateFontString(self.frame, "OVERLAY", "GameFontNormal")
	self.browseNotice:SetPoint("LEFT", self.refreshBtn, "RIGHT", GAP + 10, 0)

	self.browseNotice:SetJustifyH("LEFT")

	self.browseNotice:SetTextColor(1, 0.82, 0)

	self.browseNotice:Hide()

	self._browseMode = false

	self.selectionLabel = nil

	self.columnHeaderHost = CreateFrame("Frame", nil, parent)
	self.columnHeaderHost:SetPoint("TOPLEFT", parent, "TOPLEFT", GF.CONTENT_SCROLL_INSET_L or 0, GF.BROWSE_HEADER_TOP_OFFSET or -20)
	self.columnHeaderHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(GF.CONTENT_SCROLL_INSET_R or 18), GF.BROWSE_HEADER_TOP_OFFSET or -20)
	self.columnHeaderHost:SetHeight(GF.SUBTITLE_HEADER_H or 22)
	self.columnHeaderHost:SetFrameLevel(parent:GetFrameLevel() + 25)
	if GF.UI and GF.UI.InstallBrowseHeaderChrome then
		GF.UI.InstallBrowseHeaderChrome(self.columnHeaderHost)
	end
	self.headerRefreshBtn = CreateFrame("Button", nil, parent)
	self.headerRefreshBtn:SetSize(GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE or 35, GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE or 35)
	self.headerRefreshBtn:SetFrameLevel(parent:GetFrameLevel() + 35)
	self.headerRefreshBtn:RegisterForClicks("LeftButtonUp")
	local headerRefreshIcon = self.headerRefreshBtn:CreateTexture(nil, "OVERLAY")
	headerRefreshIcon:SetTexture(GF.BROWSE_HEADER_REFRESH_TEXTURE or HEADER_REFRESH_TEXTURE)
	headerRefreshIcon:SetTexCoord(0, 1, 0, 1)
	self.headerRefreshBtn.Icon = headerRefreshIcon
	setHeaderRefreshIconPressed(self.headerRefreshBtn, false)
	self.headerRefreshBtn:SetScript("OnClick", function()
		if GF.FindGroupTab then
			GF.FindGroupTab:DoSearch()
		end
	end)
	self.headerRefreshBtn:SetScript("OnEnter", function(btn)
		GF.UI.BeginGameTooltip(btn, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L.REFRESH_GROUP_LIST or "刷新队伍列表", 1, 0.82, 0, true)
		GameTooltip:AddLine(L.REFRESH_GROUP_LIST_TIP or "重新搜索寻找队伍列表", 1, 1, 1, true)
		GF.UI.ShowGameTooltip()
	end)
	self.headerRefreshBtn:SetScript("OnMouseDown", function(btn, mouseButton)
		if mouseButton == "LeftButton" then
			setHeaderRefreshIconPressed(btn, true)
		end
	end)
	self.headerRefreshBtn:SetScript("OnMouseUp", function(btn)
		setHeaderRefreshIconPressed(btn, false)
	end)
	self.headerRefreshBtn:SetScript("OnLeave", function(btn)
		setHeaderRefreshIconPressed(btn, false)
		if GameTooltip:GetOwner() == btn then
			GameTooltip:Hide()
		end
	end)
	self.headerRefreshBtn:SetScript("OnDisable", function(btn)
		setHeaderRefreshIconPressed(btn, false)
	end)
	self.headerRefreshBtn:Hide()
	self.columnHeaderBar = GF.ColumnHeaderBar:Create(self.columnHeaderHost, {
		onSort = function()
			if GF.ListColumns then
				GF.ListColumns:InvalidateCache()
			end
			if GF.Result then
				GF.Result._sortToken = (GF.Result._sortToken or 0) + 1
			end
			if GF.FindGroupTab and GF.FindGroupTab.RefreshResults then
				GF.FindGroupTab:RefreshResults()
			end
			SB:LayoutColumnHeaders()
		end,
		onLayoutChange = function()
			if GF.FindGroupTab and GF.FindGroupTab.RelayoutRows then
				GF.FindGroupTab:RelayoutRows()
			end
		end,
	})
	self.columnHeaderBar:SetPoint("TOPLEFT", self.columnHeaderHost, "TOPLEFT", GF.BROWSE_HEADER_CONTENT_INSET_X or 4, GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4)
	self.columnHeaderBar:SetPoint("BOTTOMRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", -(GF.BROWSE_HEADER_CONTENT_INSET_X or 4), GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4)
	self.columnHeaderHost:Hide()
	self:AnchorHeaderRefreshButton()

	self:InstallSearchHandoffHooks()
	self:RefreshBrowseOptionToggles()

end

function SB:AnchorHeaderRefreshButton()
	if not self.headerRefreshBtn then
		return
	end
	self.headerRefreshBtn:ClearAllPoints()
	local bp = GF.FindGroupTab and GF.FindGroupTab.GetPanel and GF.FindGroupTab:GetPanel()
	local scrollBar = bp and bp.scrollList
		and bp.scrollList.GetScrollBar
		and bp.scrollList:GetScrollBar()
	if scrollBar and self.columnHeaderBar then
		local barLeft = self.columnHeaderBar:GetLeft()
		local scrollLeft = scrollBar:GetLeft()
		local scrollW = scrollBar:GetWidth()
		if barLeft and scrollLeft and scrollW and scrollW > 0 then
			local x = (scrollLeft + (scrollW / 2)) - barLeft
			self.headerRefreshBtn:SetPoint("CENTER", self.columnHeaderBar, "LEFT", math.floor(x + 0.5), 0)
			return
		end
	end
	if self.columnHeaderHost then
		self.headerRefreshBtn:SetPoint("CENTER", self.columnHeaderHost, "RIGHT", GF.CONTENT_SCROLLBAR_OFFSET_X or 9, 0)
		return
	end
	if scrollBar then
		self.headerRefreshBtn:SetPoint("CENTER", scrollBar, "CENTER", 0, 0)
	end
end

function SB:ScheduleHeaderRefreshButtonAnchor()
	if not self.headerRefreshBtn then
		return
	end
	if not C_Timer or not C_Timer.After then
		self:AnchorHeaderRefreshButton()
		return
	end
	C_Timer.After(0, function()
		if SB.headerRefreshBtn and SB.columnHeaderHost and SB.columnHeaderHost:IsShown() then
			SB:AnchorHeaderRefreshButton()
		end
	end)
end

function SB:LayoutColumnHeaders(layoutWidth)
	if not self.columnHeaderHost or not self.columnHeaderHost:IsShown() then
		return
	end
	if GF.FindGroupTab and GF.FindGroupTab.UpdateScrollWidth then
		GF.FindGroupTab:UpdateScrollWidth()
	end
	if not layoutWidth and GF.GetBrowseListLayoutWidth then
		layoutWidth = GF.GetBrowseListLayoutWidth()
	end
	GF.ColumnHeaderBar:LayoutHost(self.columnHeaderHost, self.columnHeaderBar, layoutWidth)
	self:AnchorHeaderRefreshButton()
	self:ScheduleHeaderRefreshButtonAnchor()
end

function SB:SetCategoryLabel(text)
	if not self.categoryLabel then
		return
	end
	if text and text ~= "" then
		self.categoryLabel:SetText(text)
		if self.categoryHost then
			self.categoryHost:Show()
		else
			self.categoryLabel:Show()
		end
	else
		self.categoryLabel:SetText("")
		if self.categoryHost then
			self.categoryHost:Hide()
		else
			self.categoryLabel:Hide()
		end
	end
end



function SB:SyncFromSelection(node)

	if not node then
		self.selectionLabel = nil
		self:SetCategoryLabel(nil)
		return
	end

	local label = node.label or ""

	if node.activityID and not node.customBucket then

		local info = node.activityInfo or C_LFGList.GetActivityInfoTable(node.activityID)

		label = GF.UI.GetCategoryTitle(node.categoryID, info)

	end

	self.selectionLabel = label
	self:SetCategoryLabel(label)
	if GF.ListColumns then
		GF.ListColumns:InvalidateCache()
	end
	self:LayoutColumnHeaders()

	self:SyncSearchPanelCategory(node)

	if self.searchBox and self.searchBox.ClearFocus then

		self.searchBox:ClearFocus()

	end

end



function SB:UpdateFilterState()
	if not self.filterBtn then
		return
	end
	if self.filterBtn then
		self.filterBtn:SetEnabled(isFindGroupSelectionSearchable())
	end
end



function SB:RefreshBarVisibility()
	if not self.frame then
		return
	end
	self.frame:SetShown(self._browseMode)
	if GF.MainFrame and GF.MainFrame.LayoutContentBody then
		GF.MainFrame:LayoutContentBody()
	end
end

function SB:SetBrowseControlsVisible(visible)
	if self.searchHost then
		self.searchHost:SetShown(visible)
	end
	if self.refreshBtn then
		self.refreshBtn:SetShown(visible)
	end
	if self.resetBtn then
		self.resetBtn:SetShown(visible)
		if visible then
			self:UpdateResetButtonState()
		end
	end
	if self.quickJoinCheck then
		self.quickJoinCheck:SetShown(visible)
	end
	if self.autoJoinCheck then
		self.autoJoinCheck:SetShown(visible)
	end
	if visible then
		self:RefreshBrowseOptionToggles()
	end
	if self.categoryHost then
		self.categoryHost:SetShown(visible and (self.selectionLabel and self.selectionLabel ~= ""))
	elseif self.categoryLabel then
		self.categoryLabel:SetShown(visible and (self.selectionLabel and self.selectionLabel ~= ""))
	end
	if self.columnHeaderHost then
		self.columnHeaderHost:SetShown(visible)
		if visible and GF.FindGroupTab and GF.FindGroupTab.RelayoutWhenReady then
			GF.FindGroupTab:RelayoutWhenReady()
		end
	end
	if self.headerRefreshBtn then
		self.headerRefreshBtn:SetShown(visible)
		if visible then
			self:AnchorHeaderRefreshButton()
			self:ScheduleHeaderRefreshButtonAnchor()
		end
	end
	if self.filterBtn then
		self.filterBtn:SetShown(visible)
	end
	if self.signUpBtn then
		self.signUpBtn:SetShown(visible)
		self:UpdateSignUpButtonState()
	end
	if self.browseNotice then
		if not visible then
			self.browseNotice:Hide()
		end
	end
end

function SB:SetBrowseVisible(visible)

	self._browseMode = visible and true or false
	self:SetBrowseControlsVisible(visible)

	if visible then

		self:ReclaimSearchBoxForBrowse()

	else

		self:StopSearchBoxOwnershipWatch()
		self:ReleaseBlizzardSearchBox()
		self:ClearBrowseNotice()

	end

	self:RefreshBarVisibility()

end



function SB:ShowBrowseNotice(text)

	if not self.browseNotice then

		return

	end

	if text and text ~= "" then

		if self.categoryHost then
			self.categoryHost:Hide()
		elseif self.categoryLabel then
			self.categoryLabel:Hide()
		end

		self.browseNotice:SetText(text)

		self.browseNotice:SetTextColor(1, 0.82, 0)

		self.browseNotice:Show()

	else

		self:ClearBrowseNotice()

	end

end



function SB:ClearBrowseNotice()

	if self.browseNotice then

		self.browseNotice:Hide()

	end
	if self.categoryHost and self._browseMode and self.selectionLabel and self.selectionLabel ~= "" then
		self.categoryHost:Show()
	elseif self.categoryLabel and self._browseMode and self.selectionLabel and self.selectionLabel ~= "" then
		self.categoryLabel:Show()
	end

end

function SB:IsQuickJoinEnabled()
	local mode
	if GF.Apply and GF.Apply.GetMode then
		mode = GF.Apply:GetMode()
	else
		local db = GF.GetDB and GF.GetDB()
		mode = db and db.applyMode
	end
	return mode == (GF.APPLY_DBLCLICK_AUTO or "dblclick_auto")
end

function SB:SetQuickJoinEnabled(enabled)
	local db = GF.GetDB and GF.GetDB()
	if not db then
		return
	end
	db.applyMode = enabled and (GF.APPLY_DBLCLICK_AUTO or "dblclick_auto") or (GF.APPLY_MANUAL or "manual")
	if GF.SettingsPanel then
		if GF.SettingsPanel.scroll and GF.SettingsPanel.RefreshFromDB then
			GF.SettingsPanel:RefreshFromDB()
		elseif GF.SettingsPanel.UpdateApplyDropdown then
			GF.SettingsPanel:UpdateApplyDropdown()
		end
	end
	self:RefreshBrowseOptionToggles()
end

function SB:SetAutoJoinEnabled(enabled)
	local db = GF.GetDB and GF.GetDB()
	if not db then
		return
	end
	db.autoAcceptInvite = enabled and true or false
	if enabled and GF.Apply then
		if GF.Apply.TryAutoAcceptInvite then
			GF.Apply:TryAutoAcceptInvite()
		end
		if GF.Apply.QueueAutoConfirmLfgListRoleCheck then
			GF.Apply:QueueAutoConfirmLfgListRoleCheck()
		end
	end
	if GF.SettingsPanel and GF.SettingsPanel.scroll and GF.SettingsPanel.RefreshFromDB then
		GF.SettingsPanel:RefreshFromDB()
	end
	self:RefreshBrowseOptionToggles()
end

function SB:RefreshBrowseOptionToggles()
	if self.quickJoinCheck then
		self.quickJoinCheck:SetChecked(self:IsQuickJoinEnabled() == true)
	end
	if self.autoJoinCheck then
		local db = GF.GetDB and GF.GetDB()
		self.autoJoinCheck:SetChecked(db and db.autoAcceptInvite == true)
	end
end

function SB:RefreshLocale()
	local L = GF.L or {}
	if self.filterBtn then
		self.filterBtn:SetText(L.FILTER or "Filter")
	end
	if self.signUpBtn then
		self.signUpBtn:SetText(L.SIGN_UP or "Sign Up")
	end
	if self.resetBtn then
		self.resetBtn:SetText(L.RESET or L.FILTER_RESET or "Reset")
	end
	updateBrowseOptionCheckText(self.quickJoinCheck, L.QUICK_JOIN or "Double-click to sign up", L.QUICK_JOIN_TIP or "")
	updateBrowseOptionCheckText(self.autoJoinCheck, L.AUTO_JOIN or "Auto-accept invites", L.AUTO_JOIN_TIP or "")
	self:UpdateRefreshButtonState()
	self:UpdateResetButtonState()
	self:UpdateSignUpButtonState()
	self:UpdateFilterState()
	if GF.ListColumns then
		GF.ListColumns:InvalidateCache()
	end
	self:LayoutColumnHeaders()
end



function SB:SetBrowseEnabled(enabled)

	if self.searchBox then

		self.searchBox:SetEnabled(enabled)

	end

	if self.refreshBtn then

		if enabled then

			self:UpdateRefreshButtonState()

		else

			if GF.UI and GF.UI.SetButtonPendingSpinner then
				GF.UI.SetButtonPendingSpinner(self.refreshBtn, false)
			end
			setHeaderRefreshButtonPending(self.headerRefreshBtn, false)

			self.refreshBtn:SetText(self:GetRefreshButtonLabel())

			self.refreshBtn:SetEnabled(false)

		end

	end
	if self.resetBtn then
		self:UpdateResetButtonState()
	end
	if self.headerRefreshBtn and not enabled then
		setHeaderRefreshButtonPending(self.headerRefreshBtn, false)
		setHeaderRefreshButtonEnabled(self.headerRefreshBtn, false)
	end

	if self.signUpBtn then

		self:UpdateSignUpButtonState()

	end

	if self.filterBtn and enabled then

		self:UpdateFilterState()

	elseif self.filterBtn then

		self.filterBtn:SetEnabled(false)

	end

end



function SB:GetSearchText()

	if self.searchBox then

		if BB and BB.ReadEditText then
			return BB.ReadEditText(self.searchBox) or ""
		end
		return self.searchBox:GetText() or ""

	end

	return ""

end



function SB:GetEffectiveSearchText()

	local text = strtrim(self:GetSearchText() or "")

	if text == "" then

		return nil

	end

	local label = self.selectionLabel and strtrim(self.selectionLabel) or nil

	if label and text == label then

		return nil

	end

	return text

end

function SB:UpdateSignUpButtonState()
	if not self.signUpBtn then
		return
	end
	local enabled = false
	if self._browseMode == true then
		local bp = GF.FindGroupTab and GF.FindGroupTab.GetPanel and GF.FindGroupTab:GetPanel()
		enabled = bp and bp.selectedResult ~= nil or false
		if enabled and GF.Apply and GF.Apply.CanSelectRow then
			enabled = GF.Apply:CanSelectRow(bp.selectedResult, bp.selectedResultID) == true
		end
	end
	self.signUpBtn:SetEnabled(enabled)
end

function SB:ClearSearchText()
	if C_LFGList and C_LFGList.ClearSearchTextFields then
		pcall(C_LFGList.ClearSearchTextFields)
	elseif self.searchBox and not self.searchBox._gfUsesNativeSearchBox and self.searchBox.SetText then
		self.searchBox:SetText("")
	end
	if self.searchBox and self.searchBox.ClearFocus then
		self.searchBox:ClearFocus()
	end
	self:UpdateResetButtonState()
end

function SB:HasResettableBrowseState()
	if strtrim(self:GetSearchText() or "") ~= "" then
		return true
	end
	local bp = GF.FindGroupTab and GF.FindGroupTab:GetPanel()
	if not bp then
		return false
	end
	return GF.searching
		or bp.awaitingGFSearch == true
		or bp.awaitingCooldownSearch == true
		or bp.activeSearchKey ~= nil
		or (tonumber(bp.totalResultCount) or 0) > 0
end

function SB:UpdateResetButtonState()
	if not self.resetBtn then
		return
	end
	self.resetBtn:SetEnabled(self._browseMode == true)
end

function SB:ResetBrowse()
	self:ClearSearchText()
	if GF.FindGroupTab and GF.FindGroupTab.ResetBrowsePage then
		GF.FindGroupTab:ResetBrowsePage()
	end
	if GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("check")
	end
	self:UpdateRefreshButtonState()
	self:UpdateResetButtonState()
end



function SB:SetSearchingState(searching)
	self:UpdateRefreshButtonState(searching)
end

function SB:GetRefreshButtonLabel()
	local L = GF.L or {}
	local hasList = GF.FindGroupTab and GF.FindGroupTab.HasBrowseList and GF.FindGroupTab:HasBrowseList()
	return hasList and (L.REFRESH or "Refresh") or (L.SEARCH or "Search")
end

function SB:UpdateRefreshButtonState(searching)
	if not self.refreshBtn then
		return
	end
	searching = searching or isBrowseSearchPending()
	local remain = 0
	if GF.FindGroupTab and GF.FindGroupTab.GetSearchCooldownRemaining then
		remain = GF.FindGroupTab:GetSearchCooldownRemaining()
	end
	local label = self:GetRefreshButtonLabel()
	self.refreshBtn:SetText(label)
	if searching or remain > 0 then
		if GF.UI and GF.UI.SetButtonPendingSpinner then
			GF.UI.SetButtonPendingSpinner(self.refreshBtn, true, GF.SEARCH_BUTTON_PENDING_SPINNER_SIZE or 18)
		end
		self.refreshBtn:SetEnabled(false)
		setHeaderRefreshButtonPending(self.headerRefreshBtn, true)
		setHeaderRefreshButtonEnabled(self.headerRefreshBtn, false)
		self:UpdateResetButtonState()
		return
	end
	if GF.UI and GF.UI.SetButtonPendingSpinner then
		GF.UI.SetButtonPendingSpinner(self.refreshBtn, false)
	end
	setHeaderRefreshButtonPending(self.headerRefreshBtn, false)
	local searchable = isFindGroupSelectionSearchable()
	self.refreshBtn:SetEnabled(not searching and searchable)
	setHeaderRefreshButtonEnabled(self.headerRefreshBtn, not searching and searchable)
	self:UpdateResetButtonState()
end
