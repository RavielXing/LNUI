local _, GF = ...

GF.WorkspaceBar = GF.WorkspaceBar or {}
local WB = GF.WorkspaceBar

local WORKSPACE_ORDER = {
	GF.WORKSPACE_MEETING_STONE,
	GF.WORKSPACE_MYTHIC_PLUS,
	GF.WORKSPACE_RAID,
}

local function getWorkspaceLabel(workspaceID)
	local L = GF.L or {}
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS then
		return L.WORKSPACE_MYTHIC_PLUS or "Mythic+"
	end
	if workspaceID == GF.WORKSPACE_RAID then
		return L.WORKSPACE_RAID or "Raids"
	end
	return L.WORKSPACE_MEETING_STONE or L.WORKSPACE_STANDARD or "Meeting Stone"
end

local function getSharedTabFontObject(constantKey, fallbackName)
	local fontObjectName = GF[constantKey] or fallbackName
	return _G[fontObjectName] or _G[fallbackName]
end

local function applyWorkspaceTabFont(button, state)
	if not button then
		return
	end
	local normalFont = getSharedTabFontObject(
		"MAIN_PANEL_TAB_UNSELECTED_FONT_OBJECT", "GameFontNormal")
	local selectedFont = getSharedTabFontObject(
		"MAIN_PANEL_TAB_SELECTED_FONT_OBJECT", "GameFontHighlight")
	local disabledFont = getSharedTabFontObject(
		"MAIN_PANEL_TAB_DISABLED_FONT_OBJECT", "GameFontDisable")
	if normalFont then
		button:SetNormalFontObject(normalFont)
	end
	if selectedFont then
		button:SetHighlightFontObject(selectedFont)
	end
	local activeFont = normalFont
	if state == "selected" then
		activeFont = selectedFont or normalFont
		if activeFont then
			button:SetDisabledFontObject(activeFont)
		end
	elseif state == "disabled" then
		activeFont = disabledFont or normalFont
		if activeFont then
			button:SetDisabledFontObject(activeFont)
		end
	elseif selectedFont then
		button:SetDisabledFontObject(selectedFont)
	end
	if button.Text and activeFont then
		button.Text:SetFontObject(activeFont)
	end
	if button.Text then
		if state == "selected" then
			button.Text:SetTextColor(1, 1, 1, 1)
		elseif state == "disabled" then
			button.Text:SetTextColor(0.42, 0.42, 0.42, 1)
		else
			button.Text:SetTextColor(1, 0.82, 0, 1)
		end
	end
end

local function setButtonSelected(button, selected)
	if not button then
		return
	end
	if selected then
		if PanelTemplates_SelectTab then
			PanelTemplates_SelectTab(button)
		else
			button:Disable()
		end
	else
		if PanelTemplates_DeselectTab then
			PanelTemplates_DeselectTab(button)
		else
			button:Enable()
		end
	end
end

function WB:RelayoutTabs()
	if not self.frame or not self.buttons then
		return
	end
	local referenceButton = self.buttons[GF.WORKSPACE_RAID]
	local referenceText = referenceButton and referenceButton.Text
	local referenceWidth = 0
	if referenceText then
		local normalFont = getSharedTabFontObject(
			"MAIN_PANEL_TAB_UNSELECTED_FONT_OBJECT", "GameFontNormal")
		if normalFont then
			referenceText:SetFontObject(normalFont)
		end
		referenceText:SetWidth(0)
		referenceWidth = referenceText:GetStringWidth() or 0
	end
	local tabWidth = math.max(
		GF.MAIN_PANEL_TAB_MIN_WIDTH or 95,
		math.ceil(referenceWidth + (GF.WORKSPACE_TAB_TEXT_PADDING or 40)))
	local tabHeight = GF.WORKSPACE_TAB_HEIGHT or GF.MAIN_PANEL_TAB_HEIGHT or 32
	local gap = GF.WORKSPACE_TAB_GAP or GF.MAIN_PANEL_TAB_GAP or 1
	self.frame.minTabWidth = tabWidth
	self.frame.maxTabWidth = tabWidth
	self.frame.tabPadding = 0
	self.frame:SetSize(
		(tabWidth * #WORKSPACE_ORDER) + (gap * (#WORKSPACE_ORDER - 1)),
		tabHeight)
	local previous
	for _, workspaceID in ipairs(WORKSPACE_ORDER) do
		local button = self.buttons[workspaceID]
		if button then
			button:ClearAllPoints()
			if PanelTemplates_TabResize then
				PanelTemplates_TabResize(button, 0, tabWidth)
			else
				button:SetWidth(tabWidth)
				if button.Text then
					button.Text:SetWidth(math.max(1, tabWidth - 20))
				end
			end
			button:SetHeight(tabHeight)
			if previous then
				button:SetPoint("TOPLEFT", previous, "TOPRIGHT", gap, 0)
			else
				button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
			end
			previous = button
		end
	end
	self.tabWidth = tabWidth
	self:RefreshStates()
end

function WB:Init(mainFrame, controller)
	if self.frame then
		return
	end
	self.mainFrame = mainFrame
	self.controller = controller
	self.frame = CreateFrame("Frame", "GroupFinderAddonWorkspaceBar", mainFrame)
	local tabHeight = GF.WORKSPACE_TAB_HEIGHT or 32
	self.frame:SetSize(1, tabHeight)
	self.frame:SetPoint(
		"TOPLEFT",
		mainFrame,
		"BOTTOMLEFT",
		GF.WORKSPACE_TAB_LEFT_INSET or 32,
		2
	)
	self.frame:SetFrameLevel(mainFrame:GetFrameLevel() + 40)
	self.buttons = {}

	for index, workspaceID in ipairs(WORKSPACE_ORDER) do
		local button = CreateFrame(
			"Button",
			("GroupFinderAddonWorkspaceTab%d"):format(index),
			self.frame,
			"PanelTabButtonTemplate"
		)
		button:SetID(index)
		button.workspaceID = workspaceID
		button:SetSize(GF.MAIN_PANEL_TAB_MIN_WIDTH or 95, tabHeight)
		button:SetText(getWorkspaceLabel(workspaceID))
		button:SetScript("OnClick", function(tab)
			if tab.workspaceID == GF.WORKSPACE_RAID then
				return
			end
			WB:Select(tab.workspaceID)
		end)
		if workspaceID == GF.WORKSPACE_RAID then
			button:SetScript("OnEnter", function(tab)
				local L = GF.L or {}
				GF.UI.BeginGameTooltip(tab, "ANCHOR_RIGHT")
				GameTooltip:SetText(L.WORKSPACE_RAID or "Raids", 1, 0.82, 0)
				GameTooltip:AddLine(L.WORKSPACE_RAID_DISABLED_TIP or "Coming in a future release.", 0.65, 0.65, 0.65, true)
				GF.UI.ShowGameTooltip()
			end)
			button:SetScript("OnLeave", GameTooltip_Hide)
		end
		self.buttons[workspaceID] = button
	end

	local db = GF.GetDB and GF.GetDB()
	local initial = db and db.workspaceMode or GF.WORKSPACE_DEFAULT
	if initial ~= GF.WORKSPACE_MYTHIC_PLUS then
		initial = GF.WORKSPACE_MEETING_STONE
	end
	self.current = initial
	self:RelayoutTabs()
end

function WB:RefreshStates()
	for workspaceID, button in pairs(self.buttons or {}) do
		if workspaceID == GF.WORKSPACE_RAID then
			if PanelTemplates_DeselectTab then
				PanelTemplates_DeselectTab(button)
			end
			button:Disable()
			applyWorkspaceTabFont(button, "disabled")
		else
			local selected = workspaceID == self.current
			setButtonSelected(button, selected)
			applyWorkspaceTabFont(button, selected and "selected" or "normal")
		end
	end
end

function WB:Select(workspaceID, opts)
	opts = opts or {}
	if workspaceID == GF.WORKSPACE_RAID then
		return false
	end
	if workspaceID ~= GF.WORKSPACE_MYTHIC_PLUS then
		workspaceID = GF.WORKSPACE_MEETING_STONE
	end
	local previous = self.current
	self.current = workspaceID
	local db = GF.GetDB and GF.GetDB()
	if db then
		db.workspaceMode = workspaceID
	end
	self:RefreshStates()
	if previous ~= workspaceID and not opts.silent and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("tab")
	end
	if self.controller and self.controller.OnWorkspaceChanged then
		self.controller:OnWorkspaceChanged(workspaceID, previous, opts)
	end
	return true
end

function WB:GetCurrent()
	return self.current or GF.WORKSPACE_DEFAULT or GF.WORKSPACE_MEETING_STONE
end

function WB:RefreshLocale()
	for workspaceID, button in pairs(self.buttons or {}) do
		button:SetText(getWorkspaceLabel(workspaceID))
	end
	self:RelayoutTabs()
end
