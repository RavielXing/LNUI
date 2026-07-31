local _, GF = ...

GF.MythicPlusWorkspace = GF.MythicPlusWorkspace or {}
local MW = GF.MythicPlusWorkspace

local PAGE_CONFIG = {
	[GF.TAB_MPLUS_CHARACTER] = {
		module = "MythicPlusCharacterPage",
	},
	[GF.TAB_MPLUS_GROUP] = {
		module = "MythicPlusGroupPage",
	},
	[GF.TAB_MPLUS_CARPOOL] = {
		module = "MythicPlusCarpoolPage",
	},
	[GF.TAB_MPLUS_DUNGEON] = {
		module = "MythicPlusDungeonPage",
	},
}

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
	-- restore that coordinate space here. All four transplanted pages remain
	-- inside the clip after applying their original 18/24/16 or 24/4/10 insets.
	local insetLeft = GF.MAIN_PANEL_BACKPLATE_BG_INSET_LEFT or 5
	local insetRight = GF.MAIN_PANEL_BACKPLATE_BG_INSET_RIGHT or 5
	local insetTop = GF.MAIN_PANEL_BACKPLATE_BG_INSET_TOP or 2
	local insetBottom = GF.MAIN_PANEL_BACKPLATE_BG_INSET_BOTTOM or 10
	self.host:SetPoint("TOPLEFT", parent, "TOPLEFT", -insetLeft, insetTop)
	self.host:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", insetRight, -insetBottom)
	self.host:SetFrameLevel(parent:GetFrameLevel() + 2)
	self.pages = {}
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
		GF.MythicPlusDebugService,
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
	if not (self.host and self.host:IsShown()) then
		return
	end
	local page = self.current and self.pages and self.pages[self.current]
	if page and page.frame and page.frame:IsShown() and page.RefreshView then
		page:RefreshView()
	end
end

function MW:QueueRefreshCurrent(reason)
	if not (self.host and self.host:IsShown()) then
		return
	end
	self.refreshReason = reason or self.refreshReason
	if self.refreshQueued then
		return
	end
	self.refreshQueued = true
	local function run()
		MW.refreshQueued = nil
		MW.refreshReason = nil
		MW:RefreshCurrent()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		run()
	end
end
