local _, GF = ...
GF = GF.GF or GF

GF.TabBar = {}
local TB = GF.TabBar

local function workspaceRouter()
	local router = GF.WorkspaceRouter
	if not router then
		error("GroupFinder WorkspaceRouter must load before TabBar", 2)
	end
	return router
end

local function getTabNames(workspaceID)
	local L = GF.L or {}
	return {
		[GF.TAB_BROWSE] = workspaceID == GF.WORKSPACE_RAID and L.TAB_RAID_BROWSE or L.TAB_BROWSE,
		[GF.TAB_RAID_SEEK] = workspaceRouter():IsSeekingHistory() and L.SEEK_CHAT_HISTORY or L.TAB_RAID_SEEK,
		[GF.TAB_RAID_SQUARE] = L.TAB_RAID_SQUARE,
		[GF.TAB_STARRED_LEADERS] = L.TAB_STARRED_LEADERS,
		[GF.TAB_CREATE] = L.TAB_CREATE,
		[GF.TAB_BLOCKLIST] = L.TAB_BLOCKLIST,
		[GF.TAB_SETTINGS] = L.TAB_SETTINGS,
		[GF.TAB_MPLUS_CHARACTER] = L.TAB_MPLUS_CHARACTER,
		[GF.TAB_MPLUS_GROUP] = L.TAB_MPLUS_GROUP,
		[GF.TAB_MPLUS_CARPOOL] = L.TAB_MPLUS_CARPOOL,
		[GF.TAB_MPLUS_DUNGEON] = L.TAB_MPLUS_DUNGEON,
	}
end

local function refreshUnreadGlows(self)
	local chat = GF.RaidSeekingChatService
	if not (chat and chat.HasUnread and GF.UI.SetNativeTabUnread) then return end
	local seek = self.tabs and self.tabs[GF.TAB_RAID_SEEK]
	local square = self.tabs and self.tabs[GF.TAB_RAID_SQUARE]
	if seek then GF.UI.SetNativeTabUnread(seek, chat:HasUnread("seeking")) end
	if square then GF.UI.SetNativeTabUnread(square, chat:HasUnread("board")) end
end

function TB:Init(mainFrame, opts)
	opts = opts or {}
	self.mainFrame = mainFrame
	self.tabs = {}
	self.tabsBar = CreateFrame("Frame", "GroupFinderAddonTabsBar", mainFrame)
	self.tabsBar.useSystemTabs = true
	local backplateLevel = mainFrame.panelBackplate
		and mainFrame.panelBackplate:GetFrameLevel()
		or mainFrame:GetFrameLevel()
	self.tabsBar:SetFrameLevel(backplateLevel - 2)
	self.tabsBar.selectedHighlightFrameLevel = backplateLevel + 20
	local borderFrame = mainFrame.panelBackplate and mainFrame.panelBackplate._gfPanelBorderFrame
	local unreadGlowFrameLevel = borderFrame and (borderFrame:GetFrameLevel() - 1) or (backplateLevel + 1)
	self.tabsBar:SetPoint(
		"TOPLEFT",
		mainFrame,
		"TOPLEFT",
		(GF.MAIN_PANEL_INSET_LEFT or 26) + 32,
		-((GF.MAIN_PANEL_INSET_TOP or 64) - 35 + 12)
	)
	self.tabsBar:SetSize(760, GF.MAIN_PANEL_TAB_HEIGHT or 32)
	local names = getTabNames()
	local router = workspaceRouter()
	for _, tabID in ipairs(router:GetAllTabIDs()) do
		local tab = GF.UI.CreateNativeTabButton(self.tabsBar, names[tabID] or tostring(tabID), tabID)
		tab._gfUnreadGlowFrameLevel = unreadGlowFrameLevel
		tab:SetID(tabID)
		if (tabID == GF.TAB_MPLUS_CHARACTER
			or tabID == GF.TAB_MPLUS_DUNGEON)
			and GF.UI.InstallVersionedNewFeatureBadge
		then
			GF.UI.InstallVersionedNewFeatureBadge(tab, tab.Text, {
				introducedInVersion = "2.1.6",
				hideAtVersion = "2.1.7",
			})
		end
		tab:SetScript("OnClick", function(btn)
			TB:Select(btn:GetID())
		end)
		tab:Hide()
		self.tabs[tabID] = tab
	end
	router:Init({ workspaceID = opts.workspaceID })
	self:SetWorkspace(router:GetWorkspaceID(), {
		silent = true,
		keepCurrent = true,
	})
	local chat = GF.RaidSeekingChatService
	if chat and chat.AddUnreadListener and not self.unreadListener then
		self.unreadListener = function() refreshUnreadGlows(TB) end
		chat:AddUnreadListener(self.unreadListener)
	end
	self.tabsBar:HookScript("OnShow", function() refreshUnreadGlows(TB) end)
	refreshUnreadGlows(self)
end

function TB:GetWorkspace()
	return workspaceRouter():GetWorkspaceID()
end

function TB:GetVisibleTabOrder()
	return workspaceRouter():GetVisibleTabOrder(self:GetWorkspace())
end

function TB:IsTabAvailable(tabID)
	return workspaceRouter():IsTabAvailable(tabID, self:GetWorkspace())
end

function TB:SetWorkspace(workspaceID, opts)
	opts = opts or {}
	local router = workspaceRouter()
	local transition = opts._routerTransition
	local target
	if type(transition) == "table"
		and transition.workspaceID == router:NormalizeWorkspaceID(workspaceID)
	then
		target = transition.tabID
	else
		target, transition = router:SetWorkspace(workspaceID, {
			targetTabID = opts.targetTabID,
			keepCurrent = opts.keepCurrent == true,
		})
	end
	for _, tab in pairs(self.tabs or {}) do
		tab:Hide()
	end
	for _, tabID in ipairs(self:GetVisibleTabOrder()) do
		local tab = self.tabs[tabID]
		if tab and router:IsTabVisible(tabID, self:GetWorkspace()) then
			tab:Show()
		end
	end
	self:RefreshLocale()
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
	local names = getTabNames(self:GetWorkspace())
	for tabID, tab in pairs(self.tabs) do
		if tab and GF.UI and GF.UI.SetNativeTabText then
			GF.UI.SetNativeTabText(tab, names[tabID] or tostring(tabID))
		end
	end
	self:RelayoutTabs()
end

function TB:RefreshVisibility()
	local router, workspaceID = workspaceRouter(), self:GetWorkspace()
	for tabID, tab in pairs(self.tabs or {}) do
		tab:SetShown(router:IsTabVisible(tabID, workspaceID))
	end
	self:RefreshLocale()
end

function TB:RefreshTabStates()
	local current = self:GetCurrent()
	for tabID, tab in pairs(self.tabs or {}) do
		if tab and GF.UI.SetNativeTabSelected then
			GF.UI.SetNativeTabSelected(tab, tabID == current)
			local enabled = self:IsTabAvailable(tabID)
			if tab.SetEnabled then tab:SetEnabled(enabled and tabID ~= current) end
			if not enabled and tab.Text then tab.Text:SetTextColor(0.5, 0.5, 0.5) end
		end
	end
	refreshUnreadGlows(self)
end

function TB:Select(tabID, opts)
	opts = opts or {}
	local router = workspaceRouter()
	local transition = opts._routerTransition
	if type(transition) ~= "table" or transition.tabID ~= tabID then
		transition = router:SelectTab(tabID)
	end
	if transition == nil or transition.tabChanged ~= true then
		return
	end
	tabID = transition.tabID
	self:RefreshVisibility()
	self:RefreshTabStates()
	if transition.previousTabID and transition.previousTabID ~= tabID
		and self.mainFrame and self.mainFrame.frame
		and ((self.mainFrame.IsUserVisible
			and self.mainFrame:IsUserVisible())
			or (not self.mainFrame.IsUserVisible
				and self.mainFrame.frame.IsShown
				and self.mainFrame.frame:IsShown()))
		and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("tab")
	end
	if self.mainFrame and self.mainFrame.OnTabChanged then
		self.mainFrame:OnTabChanged(tabID, opts)
	end
end

function TB:SelectTab(tabID, opts)
	local tab = self.tabs and self.tabs[tabID]
	if not tab or not tab:IsShown() or not self:IsTabAvailable(tabID) then
		return
	end
	self:Select(tabID, opts)
end

function TB:GetCurrent()
	return workspaceRouter():GetCurrentTabID()
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
	local transition = workspaceRouter():SetBlocklistTabAvailable(visible)
	if transition and transition.tabChanged then
		self:Select(transition.tabID, { _routerTransition = transition })
	end
	local tab = self.tabs and self.tabs[GF.TAB_BLOCKLIST]
	if tab then
		tab:SetShown(self:IsTabAvailable(GF.TAB_BLOCKLIST))
	end
	self:RelayoutTabs()
end
