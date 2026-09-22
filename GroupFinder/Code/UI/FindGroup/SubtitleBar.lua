local _, GF = ...



GF.SubtitleBar = {}

local SB = GF.SubtitleBar
local ControlsPresenter = assert(GF.BrowseControlsPresenter,
	"BrowseControlsPresenter must load before SubtitleBar")
local BrowsePresenter = assert(GF.BrowsePresenter,
	"BrowsePresenter must load before SubtitleBar")
ControlsPresenter:BindView(SB)



local BB = GF.BlizzardBorrow
local SEARCH_FIELD_OWNER = "groupfinder"
local SEARCH_FIELD_CHANNEL = "search"



local RIGHT_PAD = GF.SUBTITLE_CONTROL_RIGHT_PAD or 10

local LEFT_PAD = GF.SUBTITLE_CONTROL_LEFT_PAD or 15

local GAP = GF.SUBTITLE_CONTROL_GAP or 7

local HEADER_REFRESH_TEXTURE = GF.BROWSE_HEADER_REFRESH_TEXTURE or GF.REFRESH_TEXTURE
local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE

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
	local toplevel
	if widget.IsToplevel then
		toplevel = widget:IsToplevel() == true
	end
	return {
		frameLevel = widget.GetFrameLevel and widget:GetFrameLevel() or nil,
		frameStrata = widget.GetFrameStrata and widget:GetFrameStrata() or nil,
		toplevel = toplevel,
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

local function dismissAutoCompleteFrame(ac)
	if not ac then
		return
	end
	ac.selected = nil
	if ac.Hide then
		ac:Hide()
	end
	setAutoCompleteOccluderShown(ac, false)
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
		local state = pending and BUTTON_VISUAL_STATE.NORMAL
			or ((button.IsEnabled and button:IsEnabled()) and BUTTON_VISUAL_STATE.NORMAL or BUTTON_VISUAL_STATE.DISABLED)
		GF.UI.SetHeaderRefreshIconState(button, state)
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
		GF.UI.SetHeaderRefreshIconState(button, BUTTON_VISUAL_STATE.NORMAL)
		if button.SetAlpha then
			button:SetAlpha(1)
		end
		return
	end
	if enabled then
		button:Enable()
	else
		button:Disable()
	end
	GF.UI.SetHeaderRefreshIconState(
		button,
		enabled and BUTTON_VISUAL_STATE.NORMAL or BUTTON_VISUAL_STATE.DISABLED
	)
	if button.SetAlpha then
		button:SetAlpha(1)
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
	local anchors = {}
	local anchorCount = widget.GetNumPoints and widget:GetNumPoints() or 0
	for anchorIndex = 1, anchorCount do
		anchors[#anchors + 1] = { widget:GetPoint(anchorIndex) }
	end
	local width, height = widget:GetSize()
	local layerState = snapshotFrameLayer(widget) or {}
	local wasShown = not widget.IsShown or widget:IsShown() == true
	return {
		parent = widget:GetParent(),
		points = anchors,
		width = width,
		height = height,
		frameLevel = layerState.frameLevel,
		frameStrata = layerState.frameStrata,
		toplevel = layerState.toplevel,
		shown = wasShown,
	}
end

local function restoreWidgetLayout(widget, layout, restoreVisibility)
	if not widget or not layout then
		return false
	end
	local destination = layout.parent or UIParent
	widget:SetParent(destination)
	widget:ClearAllPoints()
	for anchorIndex = 1, #(layout.points or {}) do
		widget:SetPoint(unpack(layout.points[anchorIndex]))
	end
	local hasUsableSize = (layout.width or 0) > 0 and (layout.height or 0) > 0
	if hasUsableSize then
		widget:SetSize(layout.width, layout.height)
	end
	restoreFrameLayer(widget, layout)
	if restoreVisibility ~= false then
		local shouldShow = layout.shown ~= false
		if shouldShow and widget.Show then
			widget:Show()
		elseif not shouldShow and widget.Hide then
			widget:Hide()
		elseif widget.SetShown then
			widget:SetShown(shouldShow)
		end
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

local function snapshotSearchInstructions(searchBox)
	local instructions = searchBox and searchBox.Instructions
	if not instructions then
		return nil
	end
	local text
	local hasText = false
	if instructions.GetText then
		local ok, value = pcall(instructions.GetText, instructions)
		if ok then
			text = value
			hasText = true
		end
	end
	return {
		text = text,
		hasText = hasText,
		fitWidth = instructions._gfFitWidth,
		fitMinSize = instructions._gfFitMinSize,
	}
end

local function restoreSearchInstructions(searchBox, state)
	local instructions = searchBox and searchBox.Instructions
	if not instructions then
		return
	end
	if state and state.hasText and instructions.SetText then
		pcall(instructions.SetText, instructions, state.text or "")
	end
	local fitWidth = state and state.fitWidth or nil
	local fitMinSize = state and state.fitMinSize or nil
	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(instructions, fitWidth, fitMinSize)
	else
		instructions._gfFitWidth = fitWidth
		instructions._gfFitMinSize = fitMinSize
	end
end

local function createBrowseOptionCheck(parent, label, tooltip, onClick)
	local btn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	local size = GF.SUBTITLE_OPTION_CHECK_SIZE or 20
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
	btn._gfTextGap = textGap
	btn._gfTooltipTitle = label
	btn._gfTooltip = tooltip
	btn:SetScript("OnClick", function(self)
		if onClick then
			onClick(self, self:GetChecked() == true)
		end
	end)
	if tooltip and tooltip ~= "" then
		btn:SetScript("OnEnter", function(self)
			GF.UI.BeginGameTooltipAbove(self, "LEFT")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(
				self._gfTooltipTitle or "",
				1,
				0.82,
				0,
				true
			)
			GameTooltip:AddLine(self._gfTooltip or "", 1, 1, 1, true)
			GF.UI.ShowGameTooltip()
		end)
		btn:SetScript("OnLeave", GameTooltip_Hide)
	end
	if GF.UI and GF.UI.StyleFilterCheckButton then
		GF.UI.StyleFilterCheckButton(btn, { size = size })
	end
	btn:SetHitRectInsets(
		0,
		-math.ceil((btn.Label:GetStringWidth() or 0) + textGap + 4),
		0,
		0
	)
	return btn
end

local function updateBrowseOptionCheckText(btn, label, tooltip)
	if not btn then
		return
	end
	if btn.Label then
		btn.Label:SetText(label or "")
	end
	btn._gfTooltipTitle = label
	btn._gfTooltip = tooltip
	local textGap = btn._gfTextGap or GF.SUBTITLE_OPTION_TEXT_GAP or 1
	local width = btn.Label and btn.Label:GetStringWidth() or 0
	btn:SetHitRectInsets(0, -math.ceil(width + textGap + 4), 0, 0)
end

local function createCategoryAccent(parent)
	return GF.ColumnHeaderBar:CreateDivider(parent)
end



local function getLfgSearchPanel()
	local finderFrame = LFGListFrame
	return finderFrame and finderFrame.SearchPanel or nil
end



local function isBrowseTabSelected()
	local tabs = GF.TabBar
	local mainController = GF.MainFrame
	if not tabs or not tabs.GetCurrent or not mainController then
		return false
	end
	local visible
	if mainController.IsUserVisible then
		visible = mainController:IsUserVisible()
	else
		local addonFrame = mainController.frame
		visible = addonFrame and addonFrame:IsShown() == true
	end
	return tabs:GetCurrent() == GF.TAB_BROWSE
		and visible == true
end



local function isBlizzardSearchPanelActive()
	local finderFrame = LFGListFrame
	local searchPanel = finderFrame and finderFrame.SearchPanel
	return finderFrame ~= nil
		and searchPanel ~= nil
		and finderFrame.IsVisible ~= nil
		and finderFrame:IsVisible() == true
		and finderFrame.activePanel == searchPanel
end

local function getFindGroupSelection()
	return ControlsPresenter:GetSelection()
end

local function runAfterFrame(callback)
	local after = C_Timer and C_Timer.After
	if after then
		after(0, callback)
	else
		callback()
	end
end

local refreshNewbieSearchButton



function SB:SyncSearchPanelCategory(node)
	local searchPanel = getLfgSearchPanel()
	local chosenNode = node or getFindGroupSelection()
	local projection = ControlsPresenter:ProjectNativeCategory(chosenNode)
	if not searchPanel or not projection then
		return
	end

	local signature = projection.signature
	if signature ~= self._gfCategorySyncKey then
		self._gfCategorySyncKey = signature
		if LFGListSearchPanel_SetCategory then
			pcall(
				LFGListSearchPanel_SetCategory,
				searchPanel,
				projection.categoryID,
				projection.filters,
				projection.preferredFilters
			)
		end
	end

	-- Native category synchronization rewrites the instruction string.
	self:RefreshSearchPlaceholder()
end



function SB:IsBorrowingSearchBox()
	local searchPanel = getLfgSearchPanel()
	local nativeBox = searchPanel and searchPanel.SearchBox
	if not nativeBox or not self.searchHost then
		return false
	end
	return nativeBox:GetParent() == self.searchHost
end

local function isRegionVisible(region)
	if not region then
		return false
	end
	if region.IsVisible then
		return region:IsVisible() == true
	end
	return not region.IsShown or region:IsShown() == true
end

local function searchFieldLeaseFacts(owner, panel)
	panel = panel or getLfgSearchPanel()
	local searchBox = panel and panel.SearchBox
	local autoComplete = panel and panel.AutoCompleteFrame
	local nativeParent = panel
	local hideSink = BB and BB.GetHideSink and BB.GetHideSink() or nil
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	local searchParent = searchBox and searchBox.GetParent
		and searchBox:GetParent() or nil
	local autoCompleteParent = autoComplete and autoComplete.GetParent
		and autoComplete:GetParent() or nil
	local ownerCompatible = true
	if searchBox and BB and BB.IsBorrowedBy
		and searchBox._gfBorrowOwner
	then
		ownerCompatible = BB.IsBorrowedBy(
			searchBox, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
	end
	local externallyOwned = false
	if searchBox and BB and BB.IsExternallyOwned then
		externallyOwned = BB.IsExternallyOwned(
			searchBox,
			nativeParent,
			SEARCH_FIELD_OWNER,
			SEARCH_FIELD_CHANNEL
		) == true
	end
	local autoCompleteBorrowing = false
	if autoComplete and BB and BB.IsBorrowedBy then
		autoCompleteBorrowing = BB.IsBorrowedBy(
			autoComplete, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
			and (autoCompleteParent == mainFrame
				or autoCompleteParent == owner.frame)
	end
	local autoCompleteOwnerCompatible = true
	if autoComplete and BB and BB.IsBorrowedBy
		and autoComplete._gfBorrowOwner
	then
		autoCompleteOwnerCompatible = BB.IsBorrowedBy(
			autoComplete, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
	end
	local autoCompleteAtNativeParent = autoComplete == nil
		or autoCompleteParent == nativeParent
		or (hideSink ~= nil and autoCompleteParent == hideSink)
	local autoCompleteExternallyOwned = autoComplete ~= nil
		and not autoCompleteAtNativeParent
		and not autoCompleteBorrowing
	return {
		browseTabSelected = isBrowseTabSelected(),
		nativeSearchActive = isBlizzardSearchPanelActive(),
		searchFieldPresent = searchBox ~= nil,
		autoCompletePresent = autoComplete ~= nil,
		hostPresent = owner.searchHost ~= nil,
		attached = owner._searchAttached == true,
		borrowing = owner:IsBorrowingSearchBox(),
		searchParentAllowed = searchParent == nativeParent
			or (hideSink ~= nil and searchParent == hideSink),
		autoCompleteAcquireAllowed = autoCompleteAtNativeParent,
		autoCompleteParentAllowed = autoCompleteAtNativeParent
			or autoCompleteBorrowing,
		autoCompleteBorrowing = autoCompleteBorrowing,
		autoCompleteOwnerCompatible = autoCompleteOwnerCompatible,
		autoCompleteExternallyOwned = autoCompleteExternallyOwned,
		ownerCompatible = ownerCompatible,
		externallyOwned = externallyOwned,
		frameVisible = isRegionVisible(owner.frame),
		hostVisible = isRegionVisible(owner.searchHost),
		searchFieldVisible = isRegionVisible(searchBox),
		panel = panel,
		searchBox = searchBox,
		autoComplete = autoComplete,
		hideSink = hideSink,
	}
end

function SB:CanUseBorrowedAutoComplete(panel)
	local facts = searchFieldLeaseFacts(self, panel)
	return ControlsPresenter:CanUseBorrowedAutoComplete(self, facts)
end

function SB:IsBorrowingAutoCompleteFrame(panel)
	panel = panel or getLfgSearchPanel()
	local ac = panel and panel.AutoCompleteFrame
	local parent = ac and ac.GetParent and ac:GetParent()
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	if ac == nil or (parent ~= mainFrame and parent ~= self.frame) then
		return false
	end
	if BB and BB.IsBorrowedBy then
		return BB.IsBorrowedBy(
			ac, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
	end
	return true
end

function SB:DismissAutoCompleteFrame(panel)
	panel = panel or getLfgSearchPanel()
	if self:IsBorrowingAutoCompleteFrame(panel) then
		dismissAutoCompleteFrame(panel.AutoCompleteFrame)
	end
end

function SB:PositionAutoCompleteFrame(panel)
	panel = panel or getLfgSearchPanel()
	local ac = panel and panel.AutoCompleteFrame
	local searchBox = panel and panel.SearchBox
	if not ac or not searchBox or not self.frame then
		return false
	end
	if not self:CanUseBorrowedAutoComplete(panel) then
		self:DismissAutoCompleteFrame(panel)
		return false
	end

	local parent = GF.MainFrame and GF.MainFrame.frame or self.frame
	ac:SetParent(parent)
	if BB and BB.MarkBorrowed then
		BB.MarkBorrowed(ac, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
	end
	ac:ClearAllPoints()
	-- Keep Blizzard's native downward autocomplete placement, but parent it to the
	-- main frame and anchor it to the stable host so later SearchBox handoffs
	-- cannot drag an orphaned popup to Blizzard's native screen position.
	ac:SetPoint("TOPLEFT", self.searchHost, "BOTTOMLEFT", -2, 0)
	ac:SetPoint("TOPRIGHT", self.searchHost, "BOTTOMRIGHT", -4, 0)
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
	return true
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
	if not self:CanUseBorrowedAutoComplete() then
		return false
	end
	activityID = tonumber(activityID)
	if not activityID or activityID <= 0 then
		return false
	end

	local mythicPlusMode = self:IsMythicPlusSidebarMode()
	local node
	if mythicPlusMode then
		local filter = GF.MythicPlusBrowseFilter
		if not (filter and filter.SelectOnlyDungeonByActivityID
			and filter:SelectOnlyDungeonByActivityID(activityID)) then
			return false
		end
	else
		node = GF.NavData and GF.NavData.FindNodeByActivityID
			and GF.NavData.FindNodeByActivityID(activityID)
		if not node then
			return false
		end
	end

	if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	elseif GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("check")
	end

	if not mythicPlusMode then
		if GF.NavTree and GF.NavTree.SetSelected then
			GF.NavTree:SetSelected(node)
		elseif GF.MainFrame and GF.MainFrame.OnSelectionChanged then
			GF.MainFrame:OnSelectionChanged(node)
		end
	end

	local panel = getLfgSearchPanel()
	if panel and panel.AutoCompleteFrame then
		panel.AutoCompleteFrame.selected = nil
		panel.AutoCompleteFrame:Hide()
	end

	self:ClearSearchText()
	self:SyncSearchPanelCategory(node or (GF.MainFrame and GF.MainFrame.selection))

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
					if SB:CanUseBorrowedAutoComplete(panel) then
						SB:AcceptAutoCompleteActivity(btn.activityID)
					end
				end)
				button._gfAutoCompleteOwner = self
			end
		end
	end
end



function SB:InstallSearchBoxScripts(searchBox, panel)
	if not searchBox or not searchBox.SetScript then
		return
	end
	searchBox._gfLfgSearchPanel = panel

	local function borrowedPanel()
		local boundPanel = searchBox._gfLfgSearchPanel
		if not (boundPanel and boundPanel.SearchBox == searchBox) then
			boundPanel = getLfgSearchPanel()
		end
		if SB:CanUseBorrowedAutoComplete(boundPanel) then
			return boundPanel
		end
		return nil
	end

	local function refreshSuggestions()
		local ownerPanel = borrowedPanel()
		if not ownerPanel then
			SB:DismissAutoCompleteFrame(getLfgSearchPanel())
			return nil
		end
		if not LFGListSearchPanel_UpdateAutoComplete then
			return ownerPanel
		end
		local updated = pcall(
			LFGListSearchPanel_UpdateAutoComplete,
			ownerPanel
		)
		if updated and SB:PositionAutoCompleteFrame(ownerPanel) then
			SB:InstallAutoCompleteButtonScripts(ownerPanel)
		end
		return ownerPanel
	end

	local handlers = {}
	handlers.OnEnterPressed = function(editBox)
		local ownerPanel = borrowedPanel()
		if not ownerPanel then
			return
		end
		local popup = ownerPanel.AutoCompleteFrame
		local selectedActivity = popup and popup:IsShown()
			and popup.selected or nil
		if selectedActivity
			and SB:AcceptAutoCompleteActivity(selectedActivity)
		then
			return
		end
		local controller = GF.FindGroupTab
		if controller and controller.DoSearch then
			controller:DoSearch()
		end
		if editBox.ClearFocus then
			editBox:ClearFocus()
		end
	end

	handlers.OnTextChanged = function(editBox)
		if not borrowedPanel() then
			return
		end
		if SearchBoxTemplate_OnTextChanged then
			SearchBoxTemplate_OnTextChanged(editBox)
		end
		refreshSuggestions()
		SB:UpdateResetButtonState()
	end

	local function handleFocus(editBox, nativeHandler)
		if not borrowedPanel() then
			return
		end
		refreshSuggestions()
		if nativeHandler then
			nativeHandler(editBox)
		end
	end
	handlers.OnEditFocusGained = function(editBox)
		handleFocus(editBox, SearchBoxTemplate_OnEditFocusGained)
	end
	handlers.OnEditFocusLost = function(editBox)
		handleFocus(editBox, SearchBoxTemplate_OnEditFocusLost)
	end

	handlers.OnArrowPressed = function(_, direction)
		local ownerPanel = borrowedPanel()
		local delta = direction == "UP" and -1
			or (direction == "DOWN" and 1 or nil)
		if ownerPanel and delta and LFGListSearchPanel_AutoCompleteAdvance then
			pcall(LFGListSearchPanel_AutoCompleteAdvance, ownerPanel, delta)
		end
	end
	handlers.OnTabPressed = function()
		local ownerPanel = borrowedPanel()
		if ownerPanel and LFGListSearchPanel_AutoCompleteAdvance then
			local direction = IsShiftKeyDown() and -1 or 1
			pcall(
				LFGListSearchPanel_AutoCompleteAdvance,
				ownerPanel,
				direction
			)
		end
	end

	for scriptName, handler in pairs(handlers) do
		searchBox:SetScript(scriptName, handler)
	end

	local clearButton = searchBox.clearButton
	if clearButton and clearButton.SetScript then
		clearButton:SetScript("OnClick", function()
			if not borrowedPanel() then
				return
			end
			-- Blizzard's protected edit box must be cleared through the LFG API.
			local searchGateway = GF.NativeSearchGateway
			if searchGateway and searchGateway.ClearText then
				searchGateway:ClearText()
			end
			refreshSuggestions()
			SB:UpdateResetButtonState()
			if searchBox.ClearFocus then
				searchBox:ClearFocus()
			end
		end)
	end
end



function SB:PrecacheSearchWidgets()
	if self._searchPrecached == true then
		return
	end
	local searchPanel = getLfgSearchPanel()
	if not searchPanel then
		return
	end
	local widgets = {
		searchBox = searchPanel.SearchBox,
		autoComplete = searchPanel.AutoCompleteFrame,
	}
	for _, widget in pairs(widgets) do
		BB.CacheLayout(widget)
	end
	self._searchPrecached = true
end



function SB:AttachBlizzardSearchBox()
	local panel = getLfgSearchPanel()
	local searchBox = panel and panel.SearchBox
	local facts = searchFieldLeaseFacts(self, panel)
	local plan = ControlsPresenter:PlanSearchFieldLease(self, facts)
	if plan.action == ControlsPresenter.LEASE_KEEP then
		self:SyncSearchPanelCategory()
		self:ApplyBrowseInteractionState()
		return true
	end
	if plan.action == ControlsPresenter.LEASE_RELEASE then
		self:ReleaseBlizzardSearchBox()
		return false
	end
	if plan.action ~= ControlsPresenter.LEASE_ACQUIRE then
		if searchBox and plan.reason == "search-parent-owned"
			and BB and BB.ClearBorrowed
		then
			BB.ClearBorrowed(
				searchBox, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
		end
		return false
	end
	if not searchBox then
		return false
	end
	local ac = panel.AutoCompleteFrame

	self._searchBorrowReturnLayout = snapshotWidgetLayout(searchBox)
	self._searchBorrowReturnAutoCompleteLayout = snapshotWidgetLayout(ac)
	self._searchBorrowReturnScripts = snapshotSearchBoxScripts(searchBox)
	self._searchBorrowReturnInstructions = snapshotSearchInstructions(searchBox)
	if searchBox.IsEnabled then
		self._searchBorrowReturnEnabled = searchBox:IsEnabled() == true
	else
		self._searchBorrowReturnEnabled = nil
	end
	dismissAutoCompleteFrame(ac)



	self:PrecacheSearchWidgets()

	self:SyncSearchPanelCategory()



	self:InstallSearchBoxScripts(searchBox, panel)



	local w = GF.SUBTITLE_SEARCH_W or 220
	local h = GF.SUBTITLE_SEARCH_H or 26

	if not self:IsMythicPlusSidebarMode() then
		self.searchHost:SetSize(w, h)
	end
	BB.EmbedFill(searchBox, self.searchHost, self.searchHost)
	BB.MarkBorrowed(searchBox, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
	searchBox._gfUsesNativeSearchBox = true
	self.searchBox = searchBox
	self._searchAttached = true
	if GF.UI and GF.UI.StyleBrowseSearchBox then
		local L = GF.L or {}
		GF.UI.StyleBrowseSearchBox(searchBox, L.SEARCH_PLACEHOLDER or "Search groups...")
	end
	self:RefreshSearchPlaceholder()



	if ac then

		if LFGListSearchPanel_UpdateAutoComplete then
			pcall(LFGListSearchPanel_UpdateAutoComplete, panel)
		end
		if self:PositionAutoCompleteFrame(panel) then
			self:InstallAutoCompleteButtonScripts(panel)
		end

	end

	self:ApplyBrowseInteractionState()
	self:UpdateResetButtonState()

	return true

end



local function clearSearchFieldLeaseState(owner)
	owner.searchBox = nil
	owner._searchAttached = false
	owner._searchBorrowReturnLayout = nil
	owner._searchBorrowReturnAutoCompleteLayout = nil
	owner._searchBorrowReturnScripts = nil
	owner._searchBorrowReturnInstructions = nil
	owner._searchBorrowReturnEnabled = nil
end

function SB:ReleaseBlizzardSearchBox()
	local panel = getLfgSearchPanel()
	local searchBox = panel and panel.SearchBox
	local ac = panel and panel.AutoCompleteFrame
	local facts = searchFieldLeaseFacts(self, panel)
	local searchReturnParent = self._searchBorrowReturnLayout
		and self._searchBorrowReturnLayout.parent
	local autoCompleteReturnParent = self._searchBorrowReturnAutoCompleteLayout
		and self._searchBorrowReturnAutoCompleteLayout.parent
	local searchParent = searchBox and searchBox.GetParent
		and searchBox:GetParent() or nil
	local autoCompleteParent = ac and ac.GetParent
		and ac:GetParent() or nil
	facts.searchAtReturnParent = searchReturnParent ~= nil
		and searchParent == searchReturnParent
	facts.autoCompleteAtBorrowParent =
		facts.autoCompleteBorrowing == true
	facts.autoCompleteAtReturnParent =
		autoCompleteReturnParent ~= nil
		and autoCompleteParent == autoCompleteReturnParent
	local plan = ControlsPresenter:PlanSearchFieldRelease(self, facts)
	if plan.stopOwnershipWatch then
		self:StopSearchBoxOwnershipWatch()
	end
	if plan.action == ControlsPresenter.LEASE_IDLE then
		if searchBox and plan.clearBorrowMarker
			and BB and BB.ClearBorrowed
			and BB.ClearBorrowed(
				searchBox, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
		then
			searchBox._gfLfgSearchPanel = nil
			searchBox._gfUsesNativeSearchBox = nil
		end
		if ac and plan.clearAutoCompleteBorrowMarker
			and BB and BB.ClearBorrowed
		then
			BB.ClearBorrowed(
				ac, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
		end
		clearSearchFieldLeaseState(self)
		return
	end

	if panel then
		self:DismissAutoCompleteFrame(panel)

		if searchBox then
			if facts.borrowing and searchBox.ClearFocus then
				pcall(searchBox.ClearFocus, searchBox)
			end

			if plan.restoreSearchField then
				local restored = restoreWidgetLayout(searchBox, self._searchBorrowReturnLayout)
				if not restored then
					BB.RestoreLayout(searchBox)
					searchBox:Show()
				end
			end
			if plan.restoreSearchScripts then
				restoreSearchBoxScripts(searchBox, self._searchBorrowReturnScripts)
			end
			if plan.restoreSearchInstructions then
				restoreSearchInstructions(
					searchBox,
					self._searchBorrowReturnInstructions
				)
			end
			if plan.restoreSearchEnabled
				and self._searchBorrowReturnEnabled ~= nil
				and searchBox.SetEnabled
			then
				pcall(
					searchBox.SetEnabled,
					searchBox,
					self._searchBorrowReturnEnabled
				)
			end
			searchBox._gfLfgSearchPanel = nil
			searchBox._gfUsesNativeSearchBox = nil
			if plan.clearBorrowMarker then
				BB.ClearBorrowed(
					searchBox, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
			end
		end

		if ac and plan.restoreAutoComplete then
			if plan.restoreAutoCompleteScripts then
				self:RestoreAutoCompleteButtonScripts(panel)
			end
			local restored = restoreWidgetLayout(
				ac, self._searchBorrowReturnAutoCompleteLayout, false)
			if not restored then
				BB.RestoreLayout(ac)
			end
			dismissAutoCompleteFrame(ac)
		end
		if ac and plan.clearAutoCompleteBorrowMarker
			and BB and BB.ClearBorrowed
		then
			BB.ClearBorrowed(
				ac, SEARCH_FIELD_OWNER, SEARCH_FIELD_CHANNEL)
		end
	end

	clearSearchFieldLeaseState(self)

	local nativeSearchBox = panel and panel.SearchBox
	local nativeAutoComplete = panel and panel.AutoCompleteFrame
	local nativeWidgetsRestored = nativeSearchBox
		and nativeSearchBox:GetParent() == panel
		and nativeAutoComplete
		and nativeAutoComplete:GetParent() == panel
	if (plan.refreshNativeAutoComplete or isBlizzardSearchPanelActive())
		and nativeWidgetsRestored
		and LFGListSearchPanel_UpdateAutoComplete
	then
		pcall(LFGListSearchPanel_UpdateAutoComplete, panel)
	end

end



function SB:TryAttachSearchBox()

	if isBrowseTabSelected() and not isBlizzardSearchPanelActive() then

		return self:EnsureSearchBoxOwnership()

	end

	return false

end

function SB:EnsureSearchBoxOwnership()
	local facts = searchFieldLeaseFacts(self)
	local plan = ControlsPresenter:PlanSearchFieldLease(self, facts)
	if plan.action == ControlsPresenter.LEASE_RELEASE then
		self:ReleaseBlizzardSearchBox()
		return false
	elseif plan.action == ControlsPresenter.LEASE_KEEP then
		self:SyncSearchPanelCategory()
		self:ApplyBrowseInteractionState()
		return true
	elseif plan.action ~= ControlsPresenter.LEASE_ACQUIRE then
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
			if SB:IsBorrowingSearchBox() or SB._searchAttached then
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
	ControlsPresenter:SetBrowseMode(self, true)
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
	if not LFGListFrame_SetActivePanel then
		return
	end

	local function attachAfterNativeTransition()
		runAfterFrame(function()
			SB:TryAttachSearchBox()
		end)
	end

	hooksecurefunc("LFGListFrame_SetActivePanel", function(_, activePanel)
		local finderFrame = LFGListFrame
		local nativeSearch = finderFrame and finderFrame.SearchPanel
		if not nativeSearch then
			return
		end
		if activePanel == nativeSearch then
			if SB:IsBorrowingSearchBox() or SB._searchAttached then
				if BB and BB.SetActiveOwner then
					BB.SetActiveOwner("blizzard")
				end
				SB:ReleaseBlizzardSearchBox()
			end
		elseif isBrowseTabSelected() then
			attachAfterNativeTransition()
		end
	end)
end



function SB:Init(parent, topY)
	self.parent = parent
	local L = GF.L or {}
	local insetX = topY == 0 and 0 or (GF.FRAME_PAD or 4)
	local controlBar = CreateFrame("Frame", nil, parent)
	self.frame = controlBar
	controlBar:SetHeight(GF.SUBTITLE_H)
	controlBar:SetFrameLevel(parent:GetFrameLevel() + 30)
	local horizontalAnchors = {
		{ "BOTTOMLEFT", insetX },
		{ "BOTTOMRIGHT", -insetX },
	}
	for index = 1, #horizontalAnchors do
		local anchor = horizontalAnchors[index]
		controlBar:SetPoint(anchor[1], parent, anchor[1], anchor[2], 0)
	end
	if GF.UI and GF.UI.InstallBrowseControlBarChrome then
		GF.UI.InstallBrowseControlBarChrome(controlBar)
	end

	local controlCenterY = GF.SUBTITLE_CONTROL_CENTER_OFFSET_Y or 0
	local footerActionButtonWidth = GF.PANEL_BUTTON_STANDARD_W or 72
	local filterButton = GF.UI.CreatePanelButton(
		controlBar,
		L.FILTER or "Filter",
		footerActionButtonWidth
	)
	self.filterBtn = filterButton
	filterButton:SetPoint("RIGHT", controlBar, "RIGHT", -RIGHT_PAD, controlCenterY)
	filterButton:SetScript("OnClick", function()
		local filterPanel = GF.FilterPanel
		if filterPanel and GF.MainFrame and GF.MainFrame.frame then
			filterPanel:Toggle()
		end
	end)

	local signUpButton = GF.UI.CreatePanelButton(
		controlBar,
		L.SIGN_UP or "Sign Up",
		footerActionButtonWidth
	)
	self.signUpBtn = signUpButton
	local newbieSearchButton = GF.UI.CreatePanelButton(
		controlBar,
		L.SEARCH_NETEASE_NEWBIE_BUTTON or "搜索新兵",
		footerActionButtonWidth)
	self.newbieSearchBtn = newbieSearchButton
	newbieSearchButton:SetPoint("RIGHT", filterButton, "LEFT", -GAP, 0)
	newbieSearchButton:SetScript("OnClick", function()
		ControlsPresenter:RequestNewbieSearch(SB)
		refreshNewbieSearchButton(SB, true)
	end)
	newbieSearchButton:HookScript("OnEnter", function(button)
		local locale = GF.L or {}
		local projection = ControlsPresenter:ProjectNewbieSearchControl(SB)
		GF.UI.BeginGameTooltipAbove(button, "LEFT")
		GameTooltip:ClearLines()
		if projection.unavailable == true then
			local offline = projection.status == "offline"
			GameTooltip:AddLine(
				locale.SEARCH_NETEASE_NEWBIE_UNAVAILABLE_TITLE
					or "暂不可用",
				1, 0.2, 0.2, true)
			GameTooltip:AddLine(
				offline
					and (locale.SEARCH_NETEASE_NEWBIE_UNAVAILABLE_OFFLINE
						or "网易 API 离线，搜索新兵暂不可使用")
					or (locale.SEARCH_NETEASE_NEWBIE_UNAVAILABLE_FAULT
						or "网易 API 故障，搜索新兵暂不可使用"),
				1, 1, 1, true)
		else
			GameTooltip:AddLine(
				locale.SEARCH_NETEASE_NEWBIE_BUTTON or "搜索新兵",
				1, 0.82, 0, true)
			local hint = "|cffffffff"
				.. (locale.SEARCH_NETEASE_NEWBIE_HINT_PREFIX or "仅搜索并展示")
				.. "|r|cff00ff00"
				.. (locale.SEARCH_NETEASE_NEWBIE_HINT_HIGHLIGHT or "包含新兵")
				.. "|r|cffffffff"
				.. (locale.SEARCH_NETEASE_NEWBIE_HINT_SUFFIX or "的队伍")
				.. "|r"
			GameTooltip:AddLine(hint, 1, 1, 1, true)
		end
		GF.UI.ShowGameTooltip()
	end)
	newbieSearchButton:HookScript("OnLeave", function()
		GameTooltip_Hide()
	end)
	signUpButton:SetPoint("RIGHT", newbieSearchButton, "LEFT", -GAP, 0)
	signUpButton:SetScript("OnClick", function()
		local controller = GF.FindGroupTab
		if controller and controller.SignUp then
			controller:SignUp()
		end
	end)
	self:UpdateSignUpButtonState()

	local searchW = GF.SUBTITLE_SEARCH_W or 220
	local searchH = GF.SUBTITLE_SEARCH_H or 26
	local searchCenterOffsetY = GF.SUBTITLE_SEARCH_CENTER_OFFSET_Y or 0

	self.searchHost = CreateFrame("Frame", nil, controlBar)
	self.searchHost:SetSize(searchW, searchH)
	self.searchHost:SetPoint(
		"LEFT",
		controlBar,
		"LEFT",
		LEFT_PAD,
		controlCenterY + searchCenterOffsetY
	)
	self.searchHost:HookScript("OnHide", function()
		if SB._searchAttached or SB:IsBorrowingSearchBox() then
			SB:DismissAutoCompleteFrame()
		end
	end)

	self.searchBox = nil

	self.refreshBtn = GF.UI.CreatePanelButton(controlBar, L.SEARCH or "Search", GF.PANEL_BUTTON_TWO_CHAR_W)
	self.refreshBtn:SetPoint(
		"LEFT",
		self.searchHost,
		"RIGHT",
		GAP,
		-searchCenterOffsetY
	)

	self.refreshBtn:SetScript("OnClick", function()
		local ui = GF.UI
		if ui and ui.PlayUISound then
			ui.PlayUISound("check")
		end
		local controller = GF.FindGroupTab
		if controller and controller.DoManualRefresh then
			controller:DoManualRefresh()
		elseif controller and controller.DoSearch then
			controller:DoSearch({ manualRefresh = true })
		end
	end)
	self.refreshBtn:HookScript("OnEnter", function(btn)
		GF.UI.SetCommonPanelButtonHovered(btn, true)
		local LL = GF.L or {}
		local label = SB:GetRefreshButtonLabel()
		local isRefresh = label == (LL.REFRESH or "Refresh")
		GF.UI.BeginGameTooltipAbove(btn, "LEFT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(label, 1, 0.82, 0, true)
		GameTooltip:AddLine(isRefresh and (LL.BROWSE_REFRESH_SEARCH_TIP or "重新检索队伍列表") or (LL.BROWSE_SEARCH_REFRESH_TIP or "检索队伍列表"), 1, 1, 1, true)
		GF.UI.ShowGameTooltip()
	end)
	self.refreshBtn:HookScript("OnLeave", function(btn)
		GF.UI.SetCommonPanelButtonHovered(btn, false)
		if GameTooltip:GetOwner() == btn then
			GameTooltip:Hide()
		end
	end)

	self.resetBtn = GF.UI.CreatePanelButton(self.frame, L.RESET or L.FILTER_RESET or "Reset", GF.PANEL_BUTTON_TWO_CHAR_W)
	self.resetBtn:SetPoint("LEFT", self.refreshBtn, "RIGHT", GAP, 0)
	self.resetBtn:SetScript("OnClick", function()
		SB:ResetBrowse()
	end)
	self.resetBtn:HookScript("OnEnter", function(btn)
		GF.UI.SetCommonPanelButtonHovered(btn, true)
		local LL = GF.L or {}
		local tip = SB:IsMythicPlusSidebarMode()
			and LL.MPLUS_BROWSE_FILTER_RESET_TIP
			or LL.BROWSE_RESET_SEARCH_TIP
		local title = btn:GetText() or LL.RESET
			or LL.FILTER_RESET or "重置"
		GF.UI.BeginGameTooltipAbove(btn, "LEFT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(title, 1, 0.82, 0, true)
		GameTooltip:AddLine(
			tip or "清空并停止当前的搜索状态",
			1,
			1,
			1,
			true
		)
		GF.UI.ShowGameTooltip()
	end)
	self.resetBtn:HookScript("OnLeave", function(btn)
		GF.UI.SetCommonPanelButtonHovered(btn, false)
		if GameTooltip:GetOwner() == btn then
			GameTooltip:Hide()
		end
	end)

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
		local text = SB.categoryDisplayLabel or SB.selectionLabel
		if text and text ~= "" then
			GF.UI.ShowSimpleTooltipAbove(owner, text, "LEFT")
		end
	end)
	self.categoryHost:SetScript("OnLeave", GameTooltip_Hide)
	self.categoryAccentLeft = createCategoryAccent(self.categoryHost)
	self.categoryAccentLeft:SetPoint("CENTER", self.categoryHost, "LEFT", 0, 0)
	self.categoryAccentRight = createCategoryAccent(self.categoryHost)
	self.categoryAccentRight:SetPoint("CENTER", self.categoryHost, "RIGHT", 0, 0)

	local categoryText = GF.UI.CreateFontString(
		self.categoryHost,
		"OVERLAY",
		"GameFontHighlight"
	)
	self.categoryLabel = categoryText
	categoryText._gfFontSizeOverride = GF.SUBTITLE_CATEGORY_TEXT_SIZE or 13
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(categoryText, "GameFontHighlight")
	end
	local accentGap = GF.SUBTITLE_CATEGORY_ACCENT_GAP or 10
	categoryText:SetPoint("LEFT", self.categoryAccentLeft, "RIGHT", accentGap, 0)
	categoryText:SetPoint("RIGHT", self.categoryAccentRight, "LEFT", -accentGap, 0)
	categoryText:SetTextColor(1, 0.82, 0)
	categoryText:SetMaxLines(1)
	categoryText:SetWordWrap(false)
	categoryText:SetJustifyH("CENTER")
	self.categoryHost:Hide()

	local notice = GF.UI.CreateFontString(controlBar, "OVERLAY", "GameFontNormal")
	self.browseNotice = notice
	notice:SetTextColor(1, 0.82, 0)
	notice:SetJustifyH("LEFT")
	notice:SetPoint("LEFT", self.refreshBtn, "RIGHT", GAP + 10, 0)
	notice:Hide()

	self.categoryDisplayLabel = nil
	self.selectionLabel = nil
	self._browseMode = false

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
	local refreshTexCoord = GF.REFRESH_TEXTURE_TEXCOORD
	if refreshTexCoord then
		headerRefreshIcon:SetTexCoord(
			refreshTexCoord[1],
			refreshTexCoord[2],
			refreshTexCoord[3],
			refreshTexCoord[4])
	else
		headerRefreshIcon:SetTexCoord(0, 1, 0, 1)
	end
	self.headerRefreshBtn.Icon = headerRefreshIcon
	GF.UI.InstallHeaderRefreshIconHoverGlow(self.headerRefreshBtn)
	GF.UI.SetHeaderRefreshIconState(self.headerRefreshBtn, BUTTON_VISUAL_STATE.NORMAL, 0)
	self.headerRefreshBtn:SetScript("OnClick", function()
		if GF.FindGroupTab and GF.FindGroupTab.DoManualRefresh then
			GF.FindGroupTab:DoManualRefresh()
		elseif GF.FindGroupTab then
			GF.FindGroupTab:DoSearch()
		end
	end)
	self.headerRefreshBtn:HookScript("OnEnter", function(btn)
		local locale = GF.L or {}
		GF.UI.BeginGameTooltip(btn, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(
			locale.REFRESH_GROUP_LIST or "刷新队伍列表",
			1, 0.82, 0, true)
		GameTooltip:AddLine(
			locale.REFRESH_GROUP_LIST_TIP
				or "重新搜索寻找队伍列表",
			1, 1, 1, true)
		GF.UI.ShowGameTooltip()
	end)
	self.headerRefreshBtn:HookScript("OnLeave", function(btn)
		if GameTooltip:GetOwner() == btn then
			GameTooltip:Hide()
		end
	end)
	self.headerRefreshBtn:SetShown(false)
	local columnCallbacks = {}
	columnCallbacks.onSort = function()
		local columns = GF.ListColumns
		if columns and columns.InvalidateCache then
			columns:InvalidateCache()
		end
		local result = GF.Result
		if result then
			result._sortToken = (result._sortToken or 0) + 1
		end
		local controller = GF.FindGroupTab
		if controller and controller.RefreshResults then
			if controller.ClearAutomaticResultOrderLocks then
				controller:ClearAutomaticResultOrderLocks()
			end
			controller:RefreshResults()
		end
		SB:LayoutColumnHeaders()
	end
	columnCallbacks.onLayoutChange = function()
		local controller = GF.FindGroupTab
		if controller and controller.RelayoutRows then
			controller:RelayoutRows()
		end
	end
	columnCallbacks.onSizeChanged = function()
		SB:AnchorHeaderRefreshButton()
		local controller = GF.FindGroupTab
		if controller and controller.RelayoutVisibleRows then
			controller:RelayoutVisibleRows()
		end
	end
	self.columnHeaderBar = GF.ColumnHeaderBar:Create(
		self.columnHeaderHost,
		columnCallbacks
	)
	local headerTextOffsetY = GF.BROWSE_HEADER_TEXT_CENTER_OFFSET_Y or 4
	self.columnHeaderBar:SetPoint("TOPLEFT", self.columnHeaderHost, "TOPLEFT", GF.BROWSE_HEADER_CONTENT_INSET_X or 4, headerTextOffsetY)
	self.columnHeaderBar:SetPoint("BOTTOMRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", -(GF.BROWSE_HEADER_CONTENT_INSET_X or 4), headerTextOffsetY)
	self.columnHeaderHost:Hide()
	self:AnchorHeaderRefreshButton()

	self:InstallSearchHandoffHooks()
	if GF.NetEaseIdentityService and not self._neteaseIdentityListener then
		self._neteaseIdentityListener =
			GF.NetEaseIdentityService:AddListener(function()
				if SB.newbieSearchBtn then
					refreshNewbieSearchButton(SB, true)
				end
			end)
	end
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
	local host = self.columnHeaderHost
	if not host or host:IsShown() ~= true then
		return
	end
	local controller = GF.FindGroupTab
	if controller and controller.UpdateScrollWidth then
		controller:UpdateScrollWidth()
	end
	local width = layoutWidth
	if width == nil and GF.GetBrowseListLayoutWidth then
		width = GF.GetBrowseListLayoutWidth()
	end
	GF.ColumnHeaderBar:LayoutHost(host, self.columnHeaderBar, width)
	self:AnchorHeaderRefreshButton()
	self:ScheduleHeaderRefreshButtonAnchor()
end

function SB:SetCategoryLabel(text)
	if not self.categoryLabel then
		return
	end
	self.categoryDisplayLabel = text
	if text and text ~= "" then
		self.categoryLabel:SetText(text)
		if GF.Font and GF.Font.SetFitWidth then
			local hostWidth = self.categoryHost
				and tonumber(self.categoryHost:GetWidth()) or 0
			local inset = (GF.SUBTITLE_CATEGORY_ACCENT_GAP or 10) * 2
			if hostWidth > inset then
				GF.Font.SetFitWidth(
					self.categoryLabel,
					hostWidth - inset,
					8
				)
			end
		end
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
	local resolvedLabel = BrowsePresenter:ProjectSelectionLabel(node)

	self.selectionLabel = resolvedLabel
	local displayLabel = resolvedLabel
	local dungeonPanel = GF.MythicPlusBrowseFilterPanel
	if node
		and self:IsMythicPlusSidebarMode()
		and node.navKind == "season_dungeon"
		and dungeonPanel
		and dungeonPanel.GetDungeonFooterText
	then
		displayLabel = dungeonPanel:GetDungeonFooterText()
	end
	self:SetCategoryLabel(displayLabel)
	local columns = GF.ListColumns
	if columns and columns.InvalidateCache then
		columns:InvalidateCache()
	end
	self:LayoutColumnHeaders()
	self:SyncSearchPanelCategory(node)
	local searchBox = self.searchBox
	if searchBox and searchBox.ClearFocus then
		searchBox:ClearFocus()
	end
end



function SB:UpdateFilterState()
	local button = self.filterBtn
	if not button then
		return
	end
	local canFilter =
		ControlsPresenter:ProjectControlState(self).filterEnabled
	button:SetEnabled(canFilter)
end



function SB:RefreshBarVisibility()
	local controlBar = self.frame
	if not controlBar then
		return
	end
	controlBar:SetShown(self._browseMode == true)
	local mainFrame = GF.MainFrame
	if mainFrame and mainFrame.LayoutContentBody then
		mainFrame:LayoutContentBody()
	end
end

function SB:IsMythicPlusSidebarMode()
	return ControlsPresenter:IsMythicPlusSidebarMode(self)
end

function SB:IsMythicPlusFilterInteractionEnabled()
	return ControlsPresenter:IsMythicPlusFilterInteractionEnabled(self)
end

function SB:IsBrowseInteractionEnabled()
	return ControlsPresenter:IsBrowseInteractionEnabled(self)
end

function SB:ApplyMythicPlusDisabledAlphaPolicy(preserve)
	if not (GF.UI and GF.UI.SetCommonPanelButtonPreserveDisabledAlpha) then
		return
	end
	if preserve == nil then
		local projection = ControlsPresenter:ProjectInteraction(self)
		preserve = projection.preserveDisabledAlpha
	end
	if GF.UI.SetBrowseSearchBoxDisabledColors and self.searchBox then
		local disabledColor = preserve
			and (GF.MPLUS_BROWSE_FILTER_DISABLED_TEXT_COLOR
				or { 0.48, 0.47, 0.44, 1 })
			or nil
		GF.UI.SetBrowseSearchBoxDisabledColors(
			self.searchBox,
			disabledColor,
			disabledColor
		)
	end
	for _, button in ipairs({ self.refreshBtn, self.filterBtn, self.newbieSearchBtn }) do
		if button then
			GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
				button,
				preserve
			)
		end
	end
end

function SB:ApplyBrowseInteractionState()
	local projection = ControlsPresenter:ProjectInteraction(self)
	local enabled = projection.searchFieldEnabled
	if self.searchBox and self.searchBox.SetEnabled then
		self.searchBox:SetEnabled(enabled)
	end
	if projection.dismissAutoComplete then
		self:DismissAutoCompleteFrame()
		if projection.hideAdvancedFilter
			and GF.FilterPanel and GF.FilterPanel.IsShown
			and GF.FilterPanel:IsShown()
			and GF.FilterPanel.Hide
		then
			GF.FilterPanel:Hide()
		end
	end
	self:ApplyMythicPlusDisabledAlphaPolicy(
		projection.preserveDisabledAlpha)
	self:UpdateRefreshButtonState()
	self:UpdateFilterState()
	self:UpdateResetButtonState()
end

function SB:SetMythicPlusFilterInteractionEnabled(enabled)
	enabled = enabled == true
	ControlsPresenter:SetMythicPlusFilterInteractionEnabled(
		self, enabled)
	self:ApplyBrowseInteractionState()
end

function SB:RefreshSearchPlaceholder()
	local instructions = self.searchBox and self.searchBox.Instructions
	if not instructions then
		return
	end
	local hostWidth = self.searchHost
		and tonumber(self.searchHost:GetWidth()) or 0
	local projection =
		ControlsPresenter:ProjectSearchPlaceholder(self, hostWidth)
	instructions:SetText(projection.text)

	if GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(
			instructions,
			projection.fitWidth,
			projection.minimumSize
		)
	end
end

function SB:SetMythicPlusSidebarMode(active, opts)
	opts = opts or {}
	local requested = active == true
	local panel = GF.MythicPlusBrowseFilterPanel
	local searchBoxHost
	local searchButtonHost
	local resetButtonHost
	if requested and panel and panel.GetSearchControlHosts then
		searchBoxHost, searchButtonHost, resetButtonHost =
			panel:GetSearchControlHosts()
	end
	local hostsAvailable = searchBoxHost ~= nil
		and searchButtonHost ~= nil and resetButtonHost ~= nil
	local transition = ControlsPresenter:PlanSidebarTransition(
		self, requested, hostsAvailable)
	if transition.changed ~= true then
		return
	end
	active = transition.active == true

	if transition.attachToSidebar then
		self._standardSidebarLayouts = self._standardSidebarLayouts or {
			searchHost = snapshotWidgetLayout(self.searchHost),
			refreshBtn = snapshotWidgetLayout(self.refreshBtn),
			resetBtn = snapshotWidgetLayout(self.resetBtn),
			quickJoinCheck = snapshotWidgetLayout(self.quickJoinCheck),
		}
		if not self._standardBrowseNoticePoints and self.browseNotice then
			self._standardBrowseNoticePoints = {}
			for index = 1, self.browseNotice:GetNumPoints() do
				self._standardBrowseNoticePoints[index] = {
					self.browseNotice:GetPoint(index),
				}
			end
		end

		self.searchHost:SetParent(searchBoxHost)
		self.searchHost:ClearAllPoints()
		self.searchHost:SetAllPoints(searchBoxHost)
		self.searchHost:SetFrameLevel(searchBoxHost:GetFrameLevel() + 2)

		self.refreshBtn:SetParent(searchButtonHost)
		self.refreshBtn:ClearAllPoints()
		self.refreshBtn:SetAllPoints(searchButtonHost)
		self.refreshBtn:SetFrameLevel(searchButtonHost:GetFrameLevel() + 2)

		self.resetBtn:SetParent(resetButtonHost)
		self.resetBtn:ClearAllPoints()
		self.resetBtn:SetAllPoints(resetButtonHost)
		self.resetBtn:SetFrameLevel(resetButtonHost:GetFrameLevel() + 2)

		self.quickJoinCheck:ClearAllPoints()
		self.quickJoinCheck:SetPoint(
			"LEFT",
			self.frame,
			"LEFT",
			LEFT_PAD,
			GF.SUBTITLE_CONTROL_CENTER_OFFSET_Y or 0
		)
		self.browseNotice:ClearAllPoints()
		self.browseNotice:SetPoint(
			"LEFT",
			self.autoJoinCheck and self.autoJoinCheck.Label or self.quickJoinCheck,
			"RIGHT",
			GAP + 8,
			0
		)
	elseif transition.restoreStandardLayout then
		local layouts = self._standardSidebarLayouts
		if layouts then
			restoreWidgetLayout(self.searchHost, layouts.searchHost, false)
			restoreWidgetLayout(self.refreshBtn, layouts.refreshBtn, false)
			restoreWidgetLayout(self.resetBtn, layouts.resetBtn, false)
			restoreWidgetLayout(self.quickJoinCheck, layouts.quickJoinCheck, false)
			if self.browseNotice and self._standardBrowseNoticePoints then
				self.browseNotice:ClearAllPoints()
				for _, point in ipairs(self._standardBrowseNoticePoints) do
					self.browseNotice:SetPoint(unpack(point))
				end
			end
		end
	end

	if GF.UI and GF.UI.RefreshCommonPanelButtonSkin then
		GF.UI.RefreshCommonPanelButtonSkin(self.refreshBtn)
		GF.UI.RefreshCommonPanelButtonSkin(self.resetBtn)
	end
	if panel and panel.SetExternalSearchControlsAttached then
		panel:SetExternalSearchControlsAttached(active)
	end
	if active and panel and panel.UpdateDungeonFooter then
		panel:UpdateDungeonFooter()
	elseif not active and self.selectionLabel then
		self:SetCategoryLabel(self.selectionLabel)
	end
	if self.searchBox and self._searchAttached and BB and BB.EmbedFill then
		BB.EmbedFill(
			self.searchBox,
			self.searchHost,
			self.searchHost
		)
	end
	self:RefreshSearchPlaceholder()
	self:ApplyBrowseInteractionState()
	if self._browseMode then
		self:SetBrowseControlsVisible(true, opts)
	end
	local activeSearchBox = self.searchBox
	if activeSearchBox then
		self:PositionAutoCompleteFrame()
	end
end

function SB:SetBrowseControlsVisible(visible, opts)
	opts = opts or {}
	local show = visible and true or false
	local ordinaryControls = {
		search = self.searchHost,
		refresh = self.refreshBtn,
		reset = self.resetBtn,
		quickJoin = self.quickJoinCheck,
		autoJoin = self.autoJoinCheck,
		filter = self.filterBtn,
		newbieSearch = self.newbieSearchBtn,
	}
	for _, control in pairs(ordinaryControls) do
		control:SetShown(show)
	end
	if show then
		self:UpdateResetButtonState()
		self:RefreshBrowseOptionToggles()
	end

	local hasCategory = self.categoryDisplayLabel ~= nil
		and self.categoryDisplayLabel ~= ""
	local categoryRegion = self.categoryHost or self.categoryLabel
	if categoryRegion then
		categoryRegion:SetShown(show and hasCategory)
	end

	local headerHost = self.columnHeaderHost
	if headerHost then
		headerHost:SetShown(show)
		local controller = GF.FindGroupTab
		if show and opts.passiveWarmup ~= true
			and controller and controller.RefreshLayoutIfReady
		then
			controller:RefreshLayoutIfReady()
		end
	end

	local headerButton = self.headerRefreshBtn
	if headerButton then
		headerButton:SetShown(show)
		if show then
			self:AnchorHeaderRefreshButton()
			if opts.passiveWarmup ~= true then
				self:ScheduleHeaderRefreshButtonAnchor()
			end
		end
	end

	local signUpButton = self.signUpBtn
	if signUpButton then
		signUpButton:SetShown(show)
		self:UpdateSignUpButtonState()
	end
	if not show and self.browseNotice then
		self.browseNotice:Hide()
	end
end

function SB:SetBrowseVisible(visible, opts)
	opts = opts or {}
	local plan = ControlsPresenter:PlanBrowseVisibility(
		self, visible, opts)
	local show = plan.show == true
	if plan.dismissAutoComplete then
		self:DismissAutoCompleteFrame()
	end
	self:SetBrowseControlsVisible(show, opts)
	if opts.passiveWarmup == true then
		-- Background layout needs the real Browse chrome geometry but must not
		-- borrow Blizzard's SearchBox or start its ownership ticker.
		self:StopSearchBoxOwnershipWatch()
	elseif plan.borrowSearchField then
		self:ReclaimSearchBoxForBrowse()
	else
		if plan.stopOwnershipWatch then
			self:StopSearchBoxOwnershipWatch()
		end
		if plan.releaseSearchField then
			self:ReleaseBlizzardSearchBox()
		end
		if plan.clearNotice then
			self:ClearBrowseNotice()
		end
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
	if self.categoryHost and self._browseMode
		and self.categoryDisplayLabel
		and self.categoryDisplayLabel ~= ""
	then
		self.categoryHost:Show()
	elseif self.categoryLabel and self._browseMode
		and self.categoryDisplayLabel
		and self.categoryDisplayLabel ~= ""
	then
		self.categoryLabel:Show()
	end

end

function SB:IsQuickJoinEnabled()
	return ControlsPresenter:IsQuickJoinEnabled()
end

function SB:SetQuickJoinEnabled(enabled)
	if ControlsPresenter:SetQuickJoinEnabled(enabled) then
		self:RefreshBrowseOptionToggles()
	end
end

function SB:SetAutoJoinEnabled(enabled)
	if ControlsPresenter:SetAutoJoinEnabled(enabled) then
		self:RefreshBrowseOptionToggles()
	end
end

function SB:RefreshBrowseOptionToggles()
	local projection = ControlsPresenter:ProjectControlState(self)
	if self.quickJoinCheck then
		self.quickJoinCheck:SetChecked(
			projection.quickJoinEnabled == true)
	end
	if self.autoJoinCheck then
		self.autoJoinCheck:SetChecked(
			projection.autoJoinEnabled == true)
	end
	refreshNewbieSearchButton(self, true)
end

refreshNewbieSearchButton = function(owner, showUnavailableNotice)
	local button = owner.newbieSearchBtn
	if not button then
		return
	end
	local projection = ControlsPresenter:ProjectNewbieSearchControl(owner)
	local visible = projection.visible == true
	button:SetShown(visible)
	if owner.signUpBtn then
		owner.signUpBtn:ClearAllPoints()
		owner.signUpBtn:SetPoint(
			"RIGHT",
			visible and button or owner.filterBtn,
			"LEFT",
			-GAP,
			0)
	end
	if GF.UI and GF.UI.SetButtonPendingSpinner then
		GF.UI.SetButtonPendingSpinner(
			button,
			projection.pending == true,
			projection.pending == true
				and (GF.SEARCH_BUTTON_PENDING_SPINNER_SIZE or 18)
				or nil)
	end
	if not visible then
		return
	end
	local active = projection.active == true
	local interactionEnabled = projection.enabled == true
	if not button.IsEnabled or button:IsEnabled() ~= interactionEnabled then
		button:SetEnabled(interactionEnabled)
	end
	if GF.UI and GF.UI.RefreshCommonPanelButtonSkin then
		GF.UI.RefreshCommonPanelButtonSkin(button)
	end
	if active then
		local status = projection.status
		local unavailable = projection.unavailable == true
		if showUnavailableNotice and unavailable
			and owner._gfNewbieUnavailableNoticeStatus ~= status
			and GF.ShowStatusMessage
		then
			owner._gfNewbieUnavailableNoticeStatus = status
			GF.ShowStatusMessage(
				(GF.L and GF.L.FILTER_NETEASE_UNCONFIRMED)
					or "网易 API 当前不可用，玩家身份无法获取。",
				{ semantic = true })
		end
		if not unavailable then
			owner._gfNewbieUnavailableNoticeStatus = nil
		end
	else
		owner._gfNewbieUnavailableNoticeStatus = nil
	end
end

function SB:RefreshLocale()
	local L = GF.L or {}
	if self.filterBtn then
		self.filterBtn:SetText(L.FILTER or "Filter")
	end
	if self.newbieSearchBtn then
		self.newbieSearchBtn:SetText(
			L.SEARCH_NETEASE_NEWBIE_BUTTON or "搜索新兵")
	end
	if self.signUpBtn then
		self.signUpBtn:SetText(L.SIGN_UP or "Sign Up")
	end
	if self.resetBtn then
		self.resetBtn:SetText(L.RESET or L.FILTER_RESET or "Reset")
	end
	updateBrowseOptionCheckText(self.quickJoinCheck, L.QUICK_JOIN or "Double-click to join", L.QUICK_JOIN_TIP or "")
	updateBrowseOptionCheckText(self.autoJoinCheck, L.AUTO_JOIN or "Auto Join", L.AUTO_JOIN_TIP or "")
	self:RefreshSearchPlaceholder()
	self:UpdateRefreshButtonState()
	self:UpdateResetButtonState()
	self:UpdateSignUpButtonState()
	self:UpdateFilterState()
	if GF.ListColumns then
		GF.ListColumns:InvalidateCache()
	end
	if self.columnHeaderBar and GF.ColumnHeaderBar
		and GF.ColumnHeaderBar.RefreshLocale
	then
		GF.ColumnHeaderBar:RefreshLocale(self.columnHeaderBar)
	end
	self:LayoutColumnHeaders()
end



function SB:SetBrowseEnabled(enabled)
	ControlsPresenter:SetBrowseInteractionEnabled(self, enabled)
	self:ApplyBrowseInteractionState()
	local signUpButton = self.signUpBtn
	if signUpButton then
		self:UpdateSignUpButtonState()
	end
end



function SB:GetSearchText()
	local editBox = self.searchBox
	if not editBox then
		return ""
	end
	local borrowedText = BB and BB.ReadEditText
	if borrowedText then
		return borrowedText(editBox) or ""
	end
	if editBox.GetText then
		return editBox:GetText() or ""
	end
	return ""
end



function SB:GetEffectiveSearchText()
	return ControlsPresenter:GetEffectiveSearchText(
		self:GetSearchText(), self.selectionLabel)
end

function SB:UpdateSignUpButtonState()
	if not self.signUpBtn then
		return
	end
	local projection = ControlsPresenter:ProjectControlState(self)
	self.signUpBtn:SetEnabled(projection.signUpEnabled == true)
end

function SB:ClearSearchText()
	local searchGateway = GF.NativeSearchGateway
	local cleared = searchGateway and searchGateway.ClearText
		and searchGateway:ClearText() or false
	if not cleared and self.searchBox
		and not self.searchBox._gfUsesNativeSearchBox
		and self.searchBox.SetText
	then
		self.searchBox:SetText("")
	end
	if self.searchBox and self.searchBox.ClearFocus then
		self.searchBox:ClearFocus()
	end
	self:UpdateResetButtonState()
end

function SB:HasResettableBrowseState()
	local bp = GF.FindGroupTab and GF.FindGroupTab:GetPanel()
	return ControlsPresenter:HasResettableBrowseState(
		bp, self:GetSearchText())
end

function SB:UpdateResetButtonState()
	if not self.resetBtn then
		return
	end
	local projection = ControlsPresenter:ProjectControlState(self)
	local enabled = projection.resetEnabled == true
	self.resetBtn:SetEnabled(enabled)
end

function SB:ResetBrowse()
	if self:IsMythicPlusSidebarMode() then
		local controller = GF.MythicPlusBrowseFilter
		if controller and controller.Reset then
			controller:Reset()
		end
	end
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
	return ControlsPresenter:ProjectControlState(self).refreshLabel
end

function SB:UpdateRefreshButtonState(searching)
	if not self.refreshBtn then
		return
	end
	local projection = ControlsPresenter:ProjectControlState(self, {
		searching = searching == true,
	})
	self.refreshBtn:SetText(projection.refreshLabel)
	if GF.UI and GF.UI.SetButtonPendingSpinner then
		GF.UI.SetButtonPendingSpinner(
			self.refreshBtn,
			projection.refreshPending == true,
			projection.refreshPending
				and (GF.SEARCH_BUTTON_PENDING_SPINNER_SIZE or 18)
				or nil
		)
	end
	setHeaderRefreshButtonPending(
		self.headerRefreshBtn,
		projection.refreshPending == true
	)
	self.refreshBtn:SetEnabled(projection.refreshEnabled == true)
	setHeaderRefreshButtonEnabled(
		self.headerRefreshBtn,
		projection.headerRefreshEnabled == true
	)
	refreshNewbieSearchButton(self, false)
	self:UpdateResetButtonState()
end
