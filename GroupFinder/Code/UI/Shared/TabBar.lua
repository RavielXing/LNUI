local _, GF = ...

GF.TabBar = {}
local TB = GF.TabBar

local function getTabNames()
	local L = GF.L or {}
	return {
		[GF.TAB_BROWSE] = L.TAB_BROWSE,
		[GF.TAB_CREATE] = L.TAB_CREATE,
		[GF.TAB_BLOCKLIST] = L.TAB_BLOCKLIST,
		[GF.TAB_SETTINGS] = L.TAB_SETTINGS,
		[GF.TAB_DEBUG] = L.TAB_DEBUG,
	}
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
	self.tabsBar:SetSize(520, GF.MAIN_PANEL_TAB_HEIGHT or 32)
	local names = getTabNames()
	local previous
	for i = 1, GF.TAB_DEBUG do
		local tab = GF.UI.CreateNativeTabButton(self.tabsBar, names[i] or tostring(i), i)
		tab:SetID(i)
		if previous then
			tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", GF.MAIN_PANEL_TAB_GAP or 1, 0)
		else
			tab:SetPoint("TOPLEFT", self.tabsBar, "TOPLEFT", 0, 0)
		end
		tab:SetScript("OnClick", function(btn)
			TB:Select(btn:GetID())
		end)
		self.tabs[i] = tab
		previous = tab
	end
	if self.tabs[GF.TAB_DEBUG] then
		local showDebug = GF.Debug and GF.Debug.IsDebugModeEnabled and GF.Debug:IsDebugModeEnabled()
		self.tabs[GF.TAB_DEBUG]:SetShown(showDebug == true)
	end
	self.current = GF.TAB_BROWSE
	self:RelayoutTabs()
	self:RefreshTabStates()
end

function TB:RefreshLocale()
	if not self.tabs then
		return
	end
	local names = getTabNames()
	for i, tab in ipairs(self.tabs) do
		if tab and GF.UI and GF.UI.SetNativeTabText then
			GF.UI.SetNativeTabText(tab, names[i] or tostring(i))
		end
	end
	self:RelayoutTabs()
end

function TB:RefreshTabStates()
	for i, tab in ipairs(self.tabs or {}) do
		if tab and GF.UI.SetNativeTabSelected then
			GF.UI.SetNativeTabSelected(tab, i == self.current)
		end
	end
end

function TB:Select(tabID)
	local previous = self.current
	self.current = tabID
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
	if not self.tabs[tabID] or not self.tabs[tabID]:IsShown() then
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
	local prev = self.tabs[1]
	if not prev or not prev:IsShown() then
		return
	end
	for i = 2, #self.tabs do
		local tab = self.tabs[i]
		if tab and tab:IsShown() then
			tab:ClearAllPoints()
			tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", GF.MAIN_PANEL_TAB_GAP or 1, 0)
			prev = tab
		end
	end
	self:RefreshTabStates()
end

function TB:RefreshFonts()
	if not self.tabs then
		return
	end
	for _, tab in ipairs(self.tabs) do
		if tab and GF.UI and GF.UI.SetNativeTabSelected then
			GF.UI.SetNativeTabSelected(tab, tab:GetID() == self.current)
		end
	end
end

function TB:SetBlocklistTabVisible(visible)
	local tab = self.tabs and self.tabs[GF.TAB_BLOCKLIST]
	if tab then
		tab:SetShown(visible ~= false)
	end
	self:RelayoutTabs()
end

function TB:SetDebugTabVisible(visible)
	local tab = self.tabs and self.tabs[GF.TAB_DEBUG]
	if tab and visible == false and self.current == GF.TAB_DEBUG then
		self:SelectTab(GF.TAB_SETTINGS)
	end
	if tab then
		tab:SetShown(visible == true)
	end
	self:RelayoutTabs()
end
