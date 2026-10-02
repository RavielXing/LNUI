local _, GF = ...
GF = GF.GF or GF

GF.MythicPlusWorkspace = GF.MythicPlusWorkspace or {}
local MW = GF.MythicPlusWorkspace

local PAGE_CONFIG = {
	[GF.TAB_MPLUS_CHARACTER] = {
		module = "MythicPlusCharacterPage",
	},
	[GF.TAB_MPLUS_CARPOOL] = {
		module = "MythicPlusCarpoolPage",
	},
	[GF.TAB_MPLUS_DUNGEON] = {
		module = "MythicPlusDungeonPage",
	},
}

local function getVisiblePage(workspace)
	if not (workspace.host and workspace.host:IsVisible()) then
		return nil
	end
	local page = workspace.current and workspace.pages and workspace.pages[workspace.current]
	if page and page.frame and page.frame:IsVisible() and page.RefreshView then
		return page
	end
end

local function queueRefresh(workspace)
	if workspace.refreshQueued then
		return
	end
	workspace.refreshQueued = true
	local function run()
		workspace.refreshQueued = nil
		if workspace.refreshDirty then
			workspace:RefreshCurrent()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		run()
	end
end

function MW:IsWorkspaceTab(tabID)
	return PAGE_CONFIG[tabID] ~= nil
end

function MW:Init(parent)
	if self.host then
		return
	end
	self.host = CreateFrame("Frame", "GroupFinderAddonMythicPlusWorkspace", parent)
	self.clip = parent and parent:GetParent() and parent:GetParent():GetParent() or nil
	-- The shared auxiliary host is clipped to GroupFinder's inner background.
	-- MyKeyStone lays its page adapter out against the full panel backplate, so
	-- restore that coordinate space here. Each page owns its content insets;
	-- the character page clips its viewport independently of its scrollbar.
	local insetLeft = GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT or 5
	local insetRight = GF.MAIN_PANEL_BACKPLATE_BG_INSET_RIGHT or 5
	local insetTop = GF.MAIN_PANEL_BACKPLATE_BG_INSET_TOP or 2
	local insetBottom = GF.MAIN_PANEL_BACKPLATE_BG_INSET_BOTTOM or 10
	self.host:SetPoint("TOPLEFT", parent, "TOPLEFT", -insetLeft, insetTop)
	self.host:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", insetRight, -insetBottom)
	self.host:SetFrameLevel(parent:GetFrameLevel() + 2)
	self.pages = {}
	self.host:SetScript("OnShow", function()
		-- IsVisible can settle after OnShow. Reconcile on the next frame when
		-- an ancestor restores visibility, including UIParent after Alt-Z.
		if MW.refreshDirty then
			queueRefresh(MW)
		end
	end)
	self.host:SetScript("OnHide", function()
		MW.refreshDirty = true
	end)
	local function refresh(_, reason)
		MW:QueueRefreshCurrent(reason)
	end
	for _, service in ipairs({
		GF.MythicPlusSeason,
		GF.MythicPlusKeystoneCache,
		GF.MythicPlusRatingCache,
		GF.MythicPlusWeeklyCache,
		GF.MythicPlusCharacterStore,
		GF.MythicPlusRosterCache,
		GF.MythicPlusCurrentRoleService,
		GF.MythicPlusTalentLoadoutService,
		GF.MythicPlusTeleportService,
		GF.MythicPlusGroupSnapshotService,
		GF.MythicPlusCarpoolView,
		GF.MythicPlusRosterSort,
	}) do
		if service and service.AddListener then
			service:AddListener(refresh)
		end
	end
	self.host:Hide()
end

function MW:EnsurePage(tabID)
	if self.pages and self.pages[tabID] then
		return self.pages[tabID]
	end
	local config = PAGE_CONFIG[tabID]
	local module = config and GF[config.module]
	if not (module and module.Create and self.host) then
		return nil
	end
	local page = module:Create(self.host)
	self.pages[tabID] = page
	return page
end

function MW:ShowTab(tabID)
	if not self.host or not PAGE_CONFIG[tabID] then
		return
	end
	local page = self:EnsurePage(tabID)
	if not page then
		return
	end
	self.current = tabID
	-- page:Show() refreshes synchronously, even before the main window is
	-- shown. Consume old work first so notifications during that refresh
	-- remain pending, and leave any already scheduled callback in place.
	self.refreshDirty = nil
	self.refreshReason = nil
	if self.clip and self.clip.SetClipsChildren then
		-- MyKeyStone's character scrollbar intentionally occupies the panel's
		-- external scrollbar slot at +17px.
		self.clip:SetClipsChildren(false)
	end
	for pageID, currentPage in pairs(self.pages or {}) do
		if pageID == tabID then
			currentPage:Show()
		else
			currentPage:Hide()
		end
	end
	self.host:Show()
	if self.refreshDirty then
		queueRefresh(self)
	end
end

function MW:Hide()
	if self.host then
		self.host:Hide()
	end
	if self.clip and self.clip.SetClipsChildren then
		self.clip:SetClipsChildren(true)
	end
end

function MW:RefreshLocale()
	for _, page in pairs(self.pages or {}) do
		if page.RefreshLocale then
			page:RefreshLocale()
		end
	end
end

function MW:RefreshCurrent()
	local page = getVisiblePage(self)
	if not page then
		self.refreshDirty = true
		return
	end
	self.refreshDirty = nil
	self.refreshReason = nil
	page:RefreshView()
end

function MW:QueueRefreshCurrent(reason)
	self.refreshDirty = true
	self.refreshReason = reason or self.refreshReason
	if not getVisiblePage(self) then
		return
	end
	queueRefresh(self)
end
