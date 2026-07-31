local _, GF = ...

GF.TabBar = {}
local TB = GF.TabBar

local MEETING_STONE_TAB_ORDER = {
	GF.TAB_BROWSE,
	GF.TAB_CREATE,
	GF.TAB_BLOCKLIST,
	GF.TAB_SETTINGS,
	GF.TAB_DEBUG,
}

local MYTHIC_PLUS_TAB_ORDER = {
	GF.TAB_MPLUS_CHARACTER,
	GF.TAB_MPLUS_GROUP,
	GF.TAB_MPLUS_CARPOOL,
	GF.TAB_BROWSE,
	GF.TAB_CREATE,
	GF.TAB_MPLUS_DUNGEON,
	GF.TAB_BLOCKLIST,
	GF.TAB_SETTINGS,
	GF.TAB_DEBUG,
}

local ALL_TAB_IDS = {
	GF.TAB_BROWSE,
	GF.TAB_CREATE,
	GF.TAB_BLOCKLIST,
	GF.TAB_SETTINGS,
	GF.TAB_DEBUG,
	GF.TAB_MPLUS_CHARACTER,
	GF.TAB_MPLUS_GROUP,
	GF.TAB_MPLUS_CARPOOL,
	GF.TAB_MPLUS_DUNGEON,
}

local function getTabNames()
	local L = GF.L or {}
	return {
		[GF.TAB_BROWSE] = L.TAB_BROWSE,
		[GF.TAB_CREATE] = L.TAB_CREATE,
		[GF.TAB_BLOCKLIST] = L.TAB_BLOCKLIST,
		[GF.TAB_SETTINGS] = L.TAB_SETTINGS,
		[GF.TAB_DEBUG] = L.TAB_DEBUG,
		[GF.TAB_MPLUS_CHARACTER] = L.TAB_MPLUS_CHARACTER,
		[GF.TAB_MPLUS_GROUP] = L.TAB_MPLUS_GROUP,
		[GF.TAB_MPLUS_CARPOOL] = L.TAB_MPLUS_CARPOOL,
		[GF.TAB_MPLUS_DUNGEON] = L.TAB_MPLUS_DUNGEON,
	}
end

local function isDebugTab(tabID)
	return tabID == GF.TAB_DEBUG
end

local function getWorkspaceOrder(workspaceID)
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS then
		return MYTHIC_PLUS_TAB_ORDER
	end
	return MEETING_STONE_TAB_ORDER
end

function TB:Init(mainFrame)
	self.mainFrame = mainFrame
	self.tabs = {}
	self.tabsBar = CreateFrame("Frame", "GroupFinderAddonTabsBar", mainFrame)
	self.tabsBar.useSystemTabs = true
	self.tabsBar:SetFrameLevel((mainFrame.panelBackplate and mainFrame.panelBackplate:GetFrameLevel() or mainFrame:GetFrameLevel()) - 2)
	self.tabsBar.selectedHighlightFrameLevel = (mainFrame.panelBackplate and mainFrame.panelBackplate:GetFrameLevel() or mainFrame:GetFrameLevel()) + 20
	self.tabsBar:SetPoint(
		"TOPLEFT",
		mainFrame,
		"TOPLEFT",
		(GF.MAIN_PANEL_INSET_LEFT or 26) + 32,
		-((GF.MAIN_PANEL_INSET_TOP or 64) - 35 + 12)
	)
	self.tabsBar:SetSize(760, GF.MAIN_PANEL_TAB_HEIGHT or 32)
	local names = getTabNames()
	for _, tabID in ipairs(ALL_TAB_IDS) do
		local tab = GF.UI.CreateNativeTabButton(self.tabsBar, names[tabID] or tostring(tabID), tabID)
		tab:SetID(tabID)
		tab:SetScript("OnClick", function(btn)
			TB:Select(btn:GetID())
		end)
		tab:Hide()
		self.tabs[tabID] = tab
	end
	self.workspace = GF.WORKSPACE_MEETING_STONE
	self.currentByWorkspace = {
		[GF.WORKSPACE_MEETING_STONE] = GF.TAB_BROWSE,
		[GF.WORKSPACE_MYTHIC_PLUS] = GF.TAB_MPLUS_CHARACTER,
	}
	self.current = GF.TAB_BROWSE
	self:SetWorkspace(self.workspace, { silent = true, keepCurrent = true })
end

function TB:GetWorkspace()
	return self.workspace or GF.WORKSPACE_MEETING_STONE
end

function TB:GetVisibleTabOrder()
	return getWorkspaceOrder(self:GetWorkspace())
end

function TB:IsTabAvailable(tabID)
	for _, currentID in ipairs(self:GetVisibleTabOrder()) do
		if currentID == tabID then
			if isDebugTab(tabID) then
				return GF.Debug and GF.Debug.IsDebugModeEnabled and GF.Debug:IsDebugModeEnabled()
			end
			if tabID == GF.TAB_BLOCKLIST then
				return self.blocklistVisible ~= false
			end
			return true
		end
	end
	return false
end

function TB:SetWorkspace(workspaceID, opts)
	opts = opts or {}
	if workspaceID ~= GF.WORKSPACE_MYTHIC_PLUS then
		workspaceID = GF.WORKSPACE_MEETING_STONE
	end
	if self.current then
		self.currentByWorkspace[self:GetWorkspace()] = self.current
	end
	self.workspace = workspaceID
	for _, tab in pairs(self.tabs or {}) do
		tab:Hide()
	end
	for _, tabID in ipairs(self:GetVisibleTabOrder()) do
		local tab = self.tabs[tabID]
		if tab and self:IsTabAvailable(tabID) then
			tab:Show()
		end
	end
	local target = opts.keepCurrent and self.current or self.currentByWorkspace[workspaceID]
	if not self:IsTabAvailable(target) then
		target = workspaceID == GF.WORKSPACE_MYTHIC_PLUS and GF.TAB_MPLUS_CHARACTER or GF.TAB_BROWSE
	end
	self.current = target
	self.currentByWorkspace[workspaceID] = target
	self:RelayoutTabs()
	self:RefreshTabStates()
	if not opts.silent and self.mainFrame and self.mainFrame.OnTabChanged then
		self.mainFrame:OnTabChanged(target)
	end
	return target
end

function TB:RefreshLocale()
	if not self.tabs then
		return
	end
	local names = getTabNames()
	for tabID, tab in pairs(self.tabs) do
		if tab and GF.UI and GF.UI.SetNativeTabText then
			GF.UI.SetNativeTabText(tab, names[tabID] or tostring(tabID))
		end
	end
	self:RelayoutTabs()
end

function TB:RefreshTabStates()
	for tabID, tab in pairs(self.tabs or {}) do
		if tab and GF.UI.SetNativeTabSelected then
			GF.UI.SetNativeTabSelected(tab, tabID == self.current)
		end
	end
end

function TB:Select(tabID)
	if not self:IsTabAvailable(tabID) then
		return
	end
	local previous = self.current
	if previous == tabID then
		return
	end
	self.current = tabID
	self.currentByWorkspace[self:GetWorkspace()] = tabID
	self:RefreshTabStates()
	if previous and previous ~= tabID
		and self.mainFrame and self.mainFrame.IsShown and self.mainFrame:IsShown()
		and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("tab")
	end
	if self.mainFrame and self.mainFrame.OnTabChanged then
		self.mainFrame:OnTabChanged(tabID)
	end
end

function TB:SelectTab(tabID)
	local tab = self.tabs and self.tabs[tabID]
	if not tab or not tab:IsShown() or not self:IsTabAvailable(tabID) then
		return
	end
	self:Select(tabID)
end

function TB:GetCurrent()
	return self.current or GF.TAB_BROWSE
end

function TB:RelayoutTabs()
	if not self.tabs then
		return
	end
	local previous
	for _, tabID in ipairs(self:GetVisibleTabOrder()) do
		local tab = self.tabs[tabID]
		if tab and tab:IsShown() then
			tab:ClearAllPoints()
			if previous then
				tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", GF.MAIN_PANEL_TAB_GAP or 1, 0)
			else
				tab:SetPoint("TOPLEFT", self.tabsBar, "TOPLEFT", 0, 0)
			end
			previous = tab
		end
	end
	self:RefreshTabStates()
end

function TB:RefreshFonts()
	self:RefreshTabStates()
end

function TB:SetBlocklistTabVisible(visible)
	self.blocklistVisible = visible ~= false
	local tab = self.tabs and self.tabs[GF.TAB_BLOCKLIST]
	if tab then
		tab:SetShown(self:IsTabAvailable(GF.TAB_BLOCKLIST))
	end
	self:RelayoutTabs()
end

function TB:SetDebugTabVisible(visible)
	local enabled = visible == true
	if not enabled then
		for _, workspaceID in ipairs({
			GF.WORKSPACE_MEETING_STONE,
			GF.WORKSPACE_MYTHIC_PLUS,
		}) do
			if self.currentByWorkspace
				and self.currentByWorkspace[workspaceID] == GF.TAB_DEBUG
			then
				self.currentByWorkspace[workspaceID] = GF.TAB_SETTINGS
			end
		end
		if isDebugTab(self.current) then
			self:Select(GF.TAB_SETTINGS)
		end
	end
	local tab = self.tabs and self.tabs[GF.TAB_DEBUG]
	if tab then
		tab:SetShown(enabled and self:IsTabAvailable(GF.TAB_DEBUG))
	end
	self:RelayoutTabs()
end
