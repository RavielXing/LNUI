local _, GF = ...

-- WindowShellPresenter is the single lifecycle owner for the main-window
-- projection.  MainFrame owns the SettingsFrameTemplate shell and layout
-- hosts; WorkspaceRouter owns the canonical workspace/tab pair; this owner
-- coordinates when page views are created, projected, warmed, or suspended.
GF.WindowShellPresenter = {}
local Presenter = GF.WindowShellPresenter
local CREATE_PRESENTATION_MAX_ATTEMPTS = 3
local CREATE_PRESENTATION_RETRY_DELAY = 0.1

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if method then
		return method(owner, ...)
	end
end

local function workspaceRouter()
	local router = GF.WorkspaceRouter
	if not router then
		error("GroupFinder WorkspaceRouter must load before WindowShellPresenter", 2)
	end
	return router
end

local function getBrowseSurface()
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.GetBrowseSurface then
		return GF.LFGWorkspaceView:GetBrowseSurface()
	end
	return GF.FindGroupTab
end

local function viewOf(self)
	local view = self._view or GF.MainFrame
	if not view then
		error("GroupFinder MainFrame must bind WindowShellPresenter", 2)
	end
	return view
end

local function isFrameShown(frame)
	return frame ~= nil and type(frame.IsShown) == "function"
		and frame:IsShown() == true
end

local function isFrameVisible(frame)
	if frame ~= nil and type(frame.IsVisible) == "function" then
		return frame:IsVisible() == true
	end
	return isFrameShown(frame)
end

local function frameAlpha(frame)
	if frame and frame._gfWindowMotion then
		return frame._gfWindowMotion.baseAlpha
	end
	if frame ~= nil and type(frame.GetAlpha) == "function" then
		return frame:GetAlpha()
	end
	return 1
end

local function reportLifecycleError(message)
	local getHandler = geterrorhandler
	local handler = type(getHandler) == "function" and getHandler() or nil
	if type(handler) == "function" then
		pcall(handler, message)
	end
end

function Presenter:BindView(view)
	assert(view, "WindowShellPresenter requires a MainFrame view")
	self._view = view
	if GF.StarredLeaders and not self._starredListenerInstalled then
		self._starredListenerInstalled = true
		GF.StarredLeaders:AddListener(function()
			invoke(GF.StarredLeadersPanel, "Refresh")
			if GF.StarredLeaders:IsRaidWorkspace() then
				invoke(getBrowseSurface(), "RequestRefreshResults", {
					preserveScroll = true,
					forceResort = true,
				})
			end
		end)
	end
	return self
end

function Presenter:GetView()
	return viewOf(self)
end

function Presenter:GetSelection()
	return self._selection
end

function Presenter:ResetSelection()
	self._selection = nil
end

function Presenter:GetShowGeneration()
	return self._showGeneration or 0
end

function Presenter:IsSurfacePreloadActive()
	return self._surfacePreloadPreparing == true
		or self._surfacePreloadState ~= nil
end

function Presenter:IsUserVisible()
	local frame = viewOf(self).frame
	return frame ~= nil and frame:IsShown()
		and not self:IsSurfacePreloadActive()
		and not (frame._gfWindowMotion and frame._gfWindowMotion:IsClosing())
end

function Presenter:CanApplyPresentationAlpha()
	return self:IsUserVisible() and self._firstPresentationGate == nil
end

function Presenter:IsShowActive(generation)
	return (generation or 0) == self:GetShowGeneration()
		and self:IsUserVisible()
end

function Presenter:ScheduleWhenShown(delay, callback)
	local generation = self:GetShowGeneration()
	local function runIfCurrent()
		if callback and Presenter:IsShowActive(generation) then
			callback()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(delay, runIfCurrent)
	else
		runIfCurrent()
	end
end

function Presenter:CancelShowDeferredWork()
	self._showGeneration = self:GetShowGeneration() + 1
	self._createPresentationRefresh = nil
	if self._navDebounce or self._navPermissionDebounce then
		-- A close invalidates callbacks, but not the native change they carried.
		self._navDirty = true
	end
	invoke(self._navDebounce, "Cancel")
	self._navDebounce = nil
	invoke(self._navPermissionDebounce, "Cancel")
	self._navPermissionDebounce = nil
	invoke(GF.NavTree, "CancelLayoutDebounce")
	invoke(getBrowseSurface(), "CancelDeferredWork")
	invoke(GF.ApplicantsPanel, "CancelRelayoutDebounce")
end

function Presenter:ScheduleCreatePresentationRefresh()
	local view = viewOf(self)
	if not self:IsUserVisible()
		or view:GetCurrentTabID() ~= GF.TAB_CREATE
		or view:GetCurrentWorkspaceID() ~= GF.WORKSPACE_MYTHIC_PLUS
	then
		return false
	end
	local state = {
		generation = self:GetShowGeneration(),
		workspaceID = view:GetCurrentWorkspaceID(),
		attempts = 0,
	}
	self._createPresentationRefresh = state
	local function refresh()
		if Presenter._createPresentationRefresh ~= state then
			return
		end
		if not Presenter:IsShowActive(state.generation)
			or view:GetCurrentTabID() ~= GF.TAB_CREATE
			or view:GetCurrentWorkspaceID() ~= state.workspaceID
		then
			Presenter._createPresentationRefresh = nil
			return
		end
		state.attempts = state.attempts + 1
		local manager = GF.MythicPlusCreateManagerPanel
		local ready = invoke(manager, "IsPresentationReady") == true
		if not ready and Presenter:EnsureCreateTabPanels() then
			-- Recover only the shared form. Replaying UpdateCreateTab would
			-- also Show the applicant list and reload its provider.
			invoke(manager, "Open")
			ready = invoke(manager, "IsPresentationReady") == true
		end
		if Presenter._createPresentationRefresh ~= state then
			return
		end
		if ready or state.attempts >= CREATE_PRESENTATION_MAX_ATTEMPTS
			or not (C_Timer and type(C_Timer.After) == "function")
		then
			Presenter._createPresentationRefresh = nil
		else
			Presenter:ScheduleWhenShown(CREATE_PRESENTATION_RETRY_DELAY, refresh)
		end
	end
	self:ScheduleWhenShown(0, refresh)
	return true
end

function Presenter:ScheduleDeferredShowLayout()
	self:ScheduleCreatePresentationRefresh()
	self:ScheduleWhenShown(0, function()
		local view = viewOf(Presenter)
		local activeTab = view:GetCurrentTabID()
		local plainNavigation = view:NavVisibleForTab(activeTab)
			and not view:IsMythicPlusBrowseFilterVisible(activeTab)
			and not view:IsMythicPlusCreateManagerVisible(activeTab)
			and not (GF.RaidBrowsePanel and GF.RaidBrowsePanel:ShouldUse(
				activeTab, view:GetCurrentWorkspaceID()))
		if plainNavigation then
			invoke(GF.NavTree, "DeferredRefresh")
		end
		if activeTab == GF.TAB_BROWSE then
			invoke(getBrowseSurface(), "OnBrowseShown")
		elseif activeTab == GF.TAB_CREATE then
			invoke(GF.ApplicantsPanel, "RefreshLayoutIfReady")
		end
	end)
end

local function surfaceState(self)
	self._surfaceReady = self._surfaceReady or {}
	self._surfaceInitializing = self._surfaceInitializing or {}
	return self._surfaceReady, self._surfaceInitializing
end

function Presenter:IsSurfaceReady(surfaceKey)
	local ready = surfaceState(self)
	return ready[surfaceKey] == true
end

function Presenter:EnsureSurface(surfaceKey, initializer, readiness)
	local ready, initializing = surfaceState(self)
	if ready[surfaceKey] == true then
		return true
	end
	if initializing[surfaceKey] == true then
		return false
	end
	initializing[surfaceKey] = true
	local ok, readyOrError = pcall(function()
		initializer()
		return readiness() == true
	end)
	initializing[surfaceKey] = nil
	if not ok then
		ready[surfaceKey] = nil
		error(readyOrError, 0)
	end
	if readyOrError then
		ready[surfaceKey] = true
		return true
	end
	ready[surfaceKey] = nil
	return false
end

function Presenter:EnsureBrowseSurface()
	local view = viewOf(self)
	return self:EnsureSurface("browse", function()
		if not (view.contentBody and view.content) then
			return
		end
		local host = view:EnsurePanelHost("browseHost")
		invoke(GF.FindGroupTab, "Init", host)
		if not (GF.BrowsePanel and GF.BrowsePanel.scrollList) then
			return
		end
		local workspaceView = GF.LFGWorkspaceView
		if workspaceView and workspaceView.GetContext then
			invoke(GF.FindGroupTab, "SetWorkspaceContext", workspaceView:GetContext())
		end
		invoke(GF.FindGroupTab, "SetSelection", self._selection)
	end, function()
		return view.browseHost ~= nil
			and GF.BrowsePanel ~= nil
			and GF.BrowsePanel.scrollList ~= nil
	end)
end

function Presenter:EnsureCreateDrawer()
	local view = viewOf(self)
	return self:EnsureSurface("createDrawer", function()
		invoke(GF.CreateDrawer, "Init", view.content, view.contentBody)
	end, function()
		return GF.CreateDrawer ~= nil and GF.CreateDrawer.frame ~= nil
			and GF.CreateDrawer.panelHost ~= nil
	end)
end

function Presenter:EnsureCreatePanel(opts)
	opts = opts or {}
	return self:EnsureSurface("create", function()
		if not self:EnsureCreateDrawer() then
			return
		end
		invoke(GF.CreatePanel, "Init", GF.CreateDrawer.panelHost)
		if not (GF.CreatePanel and GF.CreatePanel.scroll) then
			return
		end
		local workspaceView = GF.LFGWorkspaceView
		if workspaceView and workspaceView.GetContext then
			invoke(GF.CreatePanel, "SetWorkspaceContext", workspaceView:GetContext())
		end
		if self._selection and opts.skipSelection ~= true then
			invoke(GF.CreatePanel, "SetSelection", self._selection)
		end
	end, function()
		return GF.CreatePanel ~= nil and GF.CreatePanel.scroll ~= nil
	end)
end

function Presenter:EnsureApplicantsPanel()
	local view = viewOf(self)
	return self:EnsureSurface("applicants", function()
		invoke(GF.ApplicantsPanel, "Init", view:EnsurePanelHost("applicantsHost"))
	end, function()
		return GF.ApplicantsPanel ~= nil
			and GF.ApplicantsPanel.scrollList ~= nil
	end)
end

function Presenter:EnsureMythicPlusWorkspace()
	local view = viewOf(self)
	return self:EnsureSurface("mythicPlusWorkspace", function()
		invoke(GF.MythicPlusWorkspace, "Init", view.auxContentBody)
	end, function()
		return GF.MythicPlusWorkspace ~= nil
			and GF.MythicPlusWorkspace.host ~= nil
	end)
end

function Presenter:EnsureSettingsPanel()
	local view = viewOf(self)
	return self:EnsureSurface("settings", function()
		invoke(GF.SettingsPanel, "Init", view:EnsurePanelHost("settingsHost"))
	end, function()
		return GF.SettingsPanel ~= nil and GF.SettingsPanel.scroll ~= nil
	end)
end

function Presenter:EnsureStarredLeadersPanel()
	local view = viewOf(self)
	return self:EnsureSurface("starredLeaders", function()
		invoke(GF.StarredLeadersPanel, "Init", view:EnsurePanelHost("starredHost"))
	end, function()
		return GF.StarredLeadersPanel ~= nil and GF.StarredLeadersPanel.frame ~= nil
	end)
end

function Presenter:EnsureRaidSeekingPanel()
	local view = viewOf(self)
	return self:EnsureSurface("raidSeeking", function()
		invoke(GF.RaidSeekingPanel, "Init", view:EnsurePanelHost("seekingHost"))
	end, function()
		return GF.RaidSeekingPanel ~= nil and GF.RaidSeekingPanel.frame ~= nil
	end)
end

function Presenter:EnsureBlocklistPanel()
	local view = viewOf(self)
	return self:EnsureSurface("blocklist", function()
		view:LayoutBlockContent()
		invoke(GF.BlocklistPanel, "Init", view.blockContent)
	end, function()
		return GF.BlocklistPanel ~= nil
			and GF.BlocklistPanel.blockContent ~= nil
	end)
end

function Presenter:EnsureCreateTabPanels(opts)
	local createReady = self:EnsureCreatePanel(opts)
	local applicantsReady = self:EnsureApplicantsPanel()
	return createReady == true and applicantsReady == true
end

function Presenter:EnsureMythicPlusSidePanels()
	local view = viewOf(self)
	local browseReady = self:EnsureSurface("mythicPlusBrowseFilter", function()
		invoke(GF.MythicPlusBrowseFilterPanel, "Init", view.navHost)
	end, function()
		return GF.MythicPlusBrowseFilterPanel ~= nil
			and GF.MythicPlusBrowseFilterPanel.frame ~= nil
	end)
	local createReady = self:EnsureSurface("mythicPlusCreateManager", function()
		invoke(GF.MythicPlusCreateManagerPanel, "Init", view.navHost)
	end, function()
		return GF.MythicPlusCreateManagerPanel ~= nil
			and GF.MythicPlusCreateManagerPanel.frame ~= nil
	end)
	return browseReady == true and createReady == true
end

function Presenter:IsSurfaceReadyForTab(tabID)
	if tabID == GF.TAB_RAID_SEEK or tabID == GF.TAB_RAID_SQUARE then
		return self:IsSurfaceReady("raidSeeking")
	elseif tabID == GF.TAB_BROWSE then
		return self:IsSurfaceReady("browse")
	elseif tabID == GF.TAB_CREATE then
		return self:IsSurfaceReady("create")
			and self:IsSurfaceReady("applicants")
	elseif tabID == GF.TAB_STARRED_LEADERS then
		return self:IsSurfaceReady("starredLeaders")
	elseif tabID == GF.TAB_SETTINGS then
		return self:IsSurfaceReady("settings")
	elseif tabID == GF.TAB_BLOCKLIST then
		return self:IsSurfaceReady("blocklist")
	elseif GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.IsWorkspaceTab
		and GF.MythicPlusWorkspace:IsWorkspaceTab(tabID)
	then
		return self:IsSurfaceReady("mythicPlusWorkspace")
			and GF.MythicPlusWorkspace.pages ~= nil
			and GF.MythicPlusWorkspace.pages[tabID] ~= nil
	end
	return true
end

function Presenter:EnsureSurfaceForTab(tabID)
	if tabID == GF.TAB_RAID_SEEK or tabID == GF.TAB_RAID_SQUARE then
		return self:EnsureRaidSeekingPanel()
	elseif tabID == GF.TAB_BROWSE then
		return self:EnsureBrowseSurface()
	elseif tabID == GF.TAB_CREATE then
		local ready = self:EnsureCreateTabPanels()
		if ready and self._selection then
			invoke(GF.CreatePanel, "SetSelection", self._selection)
		end
		return ready
	elseif tabID == GF.TAB_STARRED_LEADERS then
		return self:EnsureStarredLeadersPanel()
	elseif tabID == GF.TAB_SETTINGS then
		return self:EnsureSettingsPanel()
	elseif tabID == GF.TAB_BLOCKLIST then
		return self:EnsureBlocklistPanel()
	elseif GF.MythicPlusWorkspace and GF.MythicPlusWorkspace.IsWorkspaceTab
		and GF.MythicPlusWorkspace:IsWorkspaceTab(tabID)
	then
		if not self:EnsureMythicPlusWorkspace() then
			return false
		end
		return invoke(GF.MythicPlusWorkspace, "EnsurePage", tabID) ~= nil
	end
	return true
end

function Presenter:BuildPageSwitchPlan(tabID)
	local view = viewOf(self)
	local showAuxiliary = view:AuxContentVisibleForTab(tabID)
	local showBlocklist = tabID == GF.TAB_BLOCKLIST
	local showNavigation = view:NavVisibleForTab(tabID)
	local mythicWorkspace = GF.MythicPlusWorkspace
	local showMythic = mythicWorkspace and mythicWorkspace.IsWorkspaceTab
		and mythicWorkspace:IsWorkspaceTab(tabID) == true
	return {
		tabID = tabID,
		showAuxiliary = showAuxiliary,
		showBlocklist = showBlocklist,
		showNavigation = showNavigation,
		showContent = not showAuxiliary and not showBlocklist,
		showBrowse = tabID == GF.TAB_BROWSE,
		showCreate = tabID == GF.TAB_CREATE,
		showSettings = tabID == GF.TAB_SETTINGS,
		showStarred = tabID == GF.TAB_STARRED_LEADERS,
		showSeeking = tabID == GF.TAB_RAID_SEEK or tabID == GF.TAB_RAID_SQUARE,
		showMythic = showMythic,
	}
end

local function leaveCreatePanel()
	if GF.CreatePanel and GF.CreatePanel.LeaveTab then
		GF.CreatePanel:LeaveTab()
	else
		invoke(GF.CreatePanel, "Hide")
	end
end

function Presenter:ApplyPageSwitchPlan(plan, opts)
	local view = viewOf(self)
	opts = opts or {}
	self._createPresentationRefresh = nil
	if not plan.showNavigation then
		invoke(GF.NavFlyout, "HideAll")
	end
	if view.navHost then
		view.navHost:SetShown(plan.showNavigation)
	end
	view:UpdateBrowseSidePanel(plan.tabID, plan.showNavigation)
	view:UpdateNavInteractionState(plan.tabID)
	if view.contentClip then
		view.contentClip:SetShown(plan.showContent)
	end
	if view.auxContentClip then
		view.auxContentClip:SetShown(plan.showAuxiliary)
	end
	if view.blockContent then
		view.blockContent:SetShown(plan.showBlocklist)
	end
	if plan.showAuxiliary then
		view:LayoutAuxContent()
	elseif plan.showBlocklist then
		view:LayoutBlockContent()
	else
		view:LayoutContent(false)
	end

	invoke(GF.SubtitleBar, "SetBrowseVisible", plan.showBrowse)
	if not plan.showBrowse then
		invoke(GF.FilterPanel, "Hide")
	end
	invoke(GF.CreateDrawer, "SetTabActive", plan.showCreate)
	if view.browseHost then
		view.browseHost:SetShown(plan.showBrowse)
	end
	if view.settingsHost then
		view.settingsHost:SetShown(plan.showSettings)
	end
	if view.starredHost then view.starredHost:SetShown(plan.showStarred == true) end
	if view.seekingHost then view.seekingHost:SetShown(plan.showSeeking == true) end
	if plan.showSeeking then
		invoke(GF.RaidSeekingPanel, "ShowTab", plan.tabID)
	else
		invoke(GF.RaidSeekingPanel, "Hide")
	end
	if plan.showStarred then
		invoke(GF.StarredLeadersPanel, "Show")
	else
		invoke(GF.StarredLeadersPanel, "Hide")
	end
	if plan.showMythic and self:IsSurfaceReady("mythicPlusWorkspace") then
		invoke(GF.MythicPlusWorkspace, "ShowTab", plan.tabID)
	else
		invoke(GF.MythicPlusWorkspace, "Hide")
	end

	if self:IsSurfaceReady("browse") then
		if plan.showBrowse then
			invoke(getBrowseSurface(), "Show")
		else
			invoke(getBrowseSurface(), "Hide")
		end
	end
	if not plan.showCreate then
		leaveCreatePanel()
		invoke(GF.ApplicantsPanel, "Hide")
	end
	if plan.showSettings then
		invoke(GF.SettingsPanel, "Show")
	else
		invoke(GF.SettingsPanel, "Hide")
	end
	if plan.showBlocklist then
		invoke(GF.BlocklistPanel, "Show")
	else
		invoke(GF.BlocklistPanel, "Hide")
	end

	if plan.showBrowse then
		self:FlushPendingMythicPlusBrowseFilterChange()
		if not opts.skipDeferredLayout then
			self:ScheduleDeferredShowLayout()
		end
	elseif plan.showCreate then
		invoke(view, "UpdateCreateTab", {
			allowOccupiedPrompt = not opts.skipDeferredLayout,
			allowCreateAutoOpen = true,
		})
		if not opts.skipDeferredLayout then
			self:ScheduleDeferredShowLayout()
		end
	end
	if view.activityCount then
		if plan.showBrowse then
			view:UpdateActivityCount(invoke(GF.Result, "GetCount") or 0)
			invoke(getBrowseSurface(), "UpdateSearchHint")
		else
			view.activityCount:Hide()
			view:UpdateBrowseStatusHint(nil)
		end
	end
	if plan.showNavigation and GF.NavFlyout
		and GF.NavFlyout.ReanchorOpenPanels
	then
		GF.NavFlyout:ReanchorOpenPanels()
		self:ScheduleWhenShown(0, function()
			local shell = viewOf(Presenter)
			if shell:NavVisibleForTab(shell:GetCurrentTabID()) then
				invoke(GF.NavFlyout, "ReanchorOpenPanels")
			end
		end)
	end
	return true
end

function Presenter:ProjectSurfaceForTab(tabID, opts)
	opts = opts or {}
	if opts.surfaceReady ~= true and self:EnsureSurfaceForTab(tabID) ~= true then
		return false
	end
	opts.surfaceReady = true
	return viewOf(self):OnTabChanged(tabID, opts)
end

function Presenter:OnTabChanged(tabID, opts)
	local view = viewOf(self)
	if view._windowSurfacesReady ~= true then
		return
	end
	opts = opts or {}
	if opts.surfaceReady ~= true and self:EnsureSurfaceForTab(tabID) ~= true then
		return false
	end
	return self:ApplyPageSwitchPlan(self:BuildPageSwitchPlan(tabID), opts)
end

function Presenter:OnWorkspaceChanged(workspaceID, previousWorkspaceID, opts)
	opts = opts or {}
	local router = workspaceRouter()
	local targetWorkspaceID = router:NormalizeWorkspaceID(workspaceID)
	local transition = opts._routerTransition
	if type(transition) ~= "table"
		or transition.workspaceID ~= targetWorkspaceID
	then
		local _, committed = router:SetWorkspace(targetWorkspaceID, {
			targetTabID = opts.targetTabID,
		})
		transition = committed
	end
	targetWorkspaceID = transition.workspaceID
	opts.targetTabID = transition.tabID
	if previousWorkspaceID == nil and transition.workspaceChanged then
		previousWorkspaceID = transition.previousWorkspaceID
	end
	local normalizedPreviousWorkspaceID = previousWorkspaceID
	if normalizedPreviousWorkspaceID == nil and GF.LFGWorkspaceView
		and GF.LFGWorkspaceView.activeWorkspaceID
	then
		normalizedPreviousWorkspaceID = GF.LFGWorkspaceView.activeWorkspaceID
	elseif previousWorkspaceID ~= nil then
		normalizedPreviousWorkspaceID = router:NormalizeWorkspaceID(
			previousWorkspaceID)
	end
	if normalizedPreviousWorkspaceID ~= nil
		and normalizedPreviousWorkspaceID ~= targetWorkspaceID
	then
		if GF.MythicPlusCreateManagerPanel
			and GF.MythicPlusCreateManagerPanel.IsSurfaceActive
			and GF.MythicPlusCreateManagerPanel:IsSurfaceActive()
		then
			GF.MythicPlusCreateManagerPanel:SetVisible(false)
		end
		if GF.CreateDrawer and GF.CreateDrawer.IsOpen
			and GF.CreateDrawer:IsOpen()
		then
			GF.CreateDrawer:Close(true)
		end
	end

	local context, node, path
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.Activate then
		context, node, path = GF.LFGWorkspaceView:Activate(
			targetWorkspaceID,
			previousWorkspaceID,
			self._selection)
		workspaceID = context.workspaceID
	else
		workspaceID = targetWorkspaceID
	end
	invoke(GF.CreateDrawer, "SetWorkspaceContext", context)
	if self:IsSurfaceReady("browse") then
		invoke(getBrowseSurface(), "SetWorkspaceContext", context or {
			workspaceID = workspaceID,
			generation = 1,
			key = tostring(workspaceID) .. ":1",
		})
	end
	if self:IsSurfaceReady("create") then
		invoke(GF.CreatePanel, "SetWorkspaceContext", context)
	end
	if GF.NavTree then
		if GF.LFGWorkspaceView and GF.LFGWorkspaceView.ApplyNavState then
			GF.LFGWorkspaceView:ApplyNavState(workspaceID, node, path)
		elseif node and GF.NavTree.SetSelectedSilently then
			GF.NavTree:SetSelectedSilently(node, path)
		else
			GF.NavTree.selectedKey = nil
			GF.NavTree.activeRootKey = nil
			invoke(GF.NavTree, "Refresh")
		end
	end
	local tabID
	if GF.TabBar and GF.TabBar.SetWorkspace then
		tabID = GF.TabBar:SetWorkspace(workspaceID, {
			silent = true,
			targetTabID = transition.tabID,
			_routerTransition = transition,
		})
	end
	self:OnSelectionChanged(node, {
		workspaceSwitch = true,
		suppressCreateDrawer = true,
	})
	invoke(GF.NavFlyout, "HideAll")
	if tabID ~= nil and opts.deferSurface ~= true then
		self:ProjectSurfaceForTab(tabID, {
			skipDeferredLayout = opts.silent == true,
		})
	end
	return transition
end

local function getPremadeCreateBlockMessage()
	if GF.Availability and GF.Availability.GetPremadeBlockMessage then
		return GF.Availability:GetPremadeBlockMessage()
	end
end

function Presenter:OnSelectionChanged(node, opts)
	opts = opts or {}
	if node and node.disabled then
		return false
	end
	local workspaceID = viewOf(self):GetCurrentWorkspaceID()
	if node and GF.LFGWorkspaceView and GF.LFGWorkspaceView.IsNodeAllowed
		and not GF.LFGWorkspaceView:IsNodeAllowed(node, workspaceID)
	then
		return false
	end
	self._selection = node
	invoke(GF.RaidBrowsePanel, "SetSelection", node)
	invoke(GF.MythicPlusBrowseFilterPanel, "SetSelection", node)
	invoke(GF.MythicPlusCreateManagerPanel, "SetSelection", node)
	invoke(GF.LFGWorkspaceView, "RememberSelection", workspaceID, node)
	local browse = getBrowseSurface()
	if self:IsSurfaceReady("browse") then
		invoke(browse, "SetSelection", node, opts)
	end
	if viewOf(self):GetCurrentTabID() == GF.TAB_CREATE
		and self:IsSurfaceReady("create") and GF.CreatePanel
	then
		if GF.LFGWorkspaceView and GF.LFGWorkspaceView.GetContext then
			invoke(GF.CreatePanel, "SetWorkspaceContext",
				GF.LFGWorkspaceView:GetContext())
		end
		invoke(GF.CreatePanel, "SetSelection", node, opts)
		if self:IsUserVisible() then
			local manager = GF.MythicPlusCreateManagerPanel
			if manager and manager.ShouldUse and manager:ShouldUse() then
				manager:Open()
			else
				local listing = GF.RecruitmentSession
				local hasActive = listing and listing.HasActive
					and listing:HasActive()
				local canLead = listing and listing.CanPublish
					and listing:CanPublish()
				local canCreate
				if GF.LFGWorkspaceView
					and GF.LFGWorkspaceView.CanCreateSelection
				then
					canCreate = GF.LFGWorkspaceView:CanCreateSelection(
						node, workspaceID)
				else
					canCreate = GF.NavData and GF.NavData.CanCreateFromNode
						and GF.NavData.CanCreateFromNode(node)
				end
				local blocked = getPremadeCreateBlockMessage() ~= nil
				local drawer = GF.CreateDrawer
				local relisting = listing and listing.IsRelisting
					and listing:IsRelisting()
				if not hasActive and drawer and drawer.IsOpen
					and drawer:IsOpen()
					and (not canLead or not canCreate or blocked)
				then
					drawer:Close(true)
				end
				if not opts.suppressCreateDrawer and not hasActive
					and not relisting and canLead and canCreate
					and not blocked and drawer
				then
					local wasOpen = drawer.IsOpen and drawer:IsOpen()
					invoke(drawer, "Open", {
						mode = "create",
						silent = wasOpen == true,
						allowOccupiedPrompt = true,
					})
				end
			end
		end
	end
	invoke(GF.SubtitleBar, "SyncFromSelection", node)
	invoke(GF.SubtitleBar, "UpdateFilterState")
	invoke(GF.SubtitleBar, "UpdateRefreshButtonState")
	local filterPanel = GF.FilterPanel
	if filterPanel then
		local database = GF.GetDB and GF.GetDB()
		local shouldOpen = database and database.autoExpandFilter
			and self:IsUserVisible()
			and viewOf(self):GetCurrentTabID() == GF.TAB_BROWSE
			and node and browse
			and invoke(browse, "IsSearchableSelection", node)
		if shouldOpen then
			invoke(filterPanel, "Show")
		elseif self:IsUserVisible() and invoke(filterPanel, "IsShown") then
			invoke(filterPanel, "AnchorToMain")
			invoke(filterPanel, "RebuildIfNeeded", false)
		end
	end
	return true
end

function Presenter:OnMythicPlusBrowseFilterChanged(reason)
	invoke(GF.MythicPlusBrowseFilterPanel, "Refresh")
	local view = viewOf(self)
	if not view:IsMythicPlusBrowseFilterVisible() then
		if reason == "dungeons" or reason == "season" or reason == "reset" then
			self._mythicPlusBrowseScopeDirty = true
		else
			self._mythicPlusBrowseClientFilterDirty = true
		end
		return
	end
	if reason == "dungeons" or reason == "season" then
		invoke(GF.FindGroupTab, "ResetBrowsePage")
	elseif reason ~= "reset" then
		invoke(GF.FindGroupTab, "ApplyClientFilters")
	end
	invoke(GF.SubtitleBar, "UpdateRefreshButtonState")
end

function Presenter:FlushPendingMythicPlusBrowseFilterChange()
	if not viewOf(self):IsMythicPlusBrowseFilterVisible() then
		return
	end
	local scopeDirty = self._mythicPlusBrowseScopeDirty == true
	local clientDirty = self._mythicPlusBrowseClientFilterDirty == true
	self._mythicPlusBrowseScopeDirty = nil
	self._mythicPlusBrowseClientFilterDirty = nil
	if scopeDirty then
		invoke(GF.FindGroupTab, "ResetBrowsePage")
	elseif clientDirty then
		invoke(GF.FindGroupTab, "ApplyClientFilters")
	end
	if scopeDirty or clientDirty then
		invoke(GF.SubtitleBar, "UpdateRefreshButtonState")
	end
end

function Presenter:CancelRecruitmentEventBatch()
	local batch = self._recruitmentEventBatch
	self._recruitmentEventBatch = nil
	self._recruitmentEventGeneration =
		(self._recruitmentEventGeneration or 0) + 1
	invoke(batch and batch.timer, "Cancel")
end

function Presenter:FlushRecruitmentEventBatch(batch)
	if type(batch) ~= "table"
		or self._recruitmentEventBatch ~= batch
		or batch.generation ~= (self._recruitmentEventGeneration or 0)
	then
		return false
	end
	self._recruitmentEventBatch = nil
	batch.timer = nil
	local rosterChanged = batch.rosterChanged == true
	local applicantListChanged = batch.applicantListChanged == true
	local view = viewOf(self)
	if rosterChanged then
		invoke(GF.ApplicantsPanel, "OnGroupRosterChanged")
		invoke(view, "RefreshRoleSelectionButtons")
		invoke(view, "RefreshListingPanels")
	end
	if applicantListChanged then
		local applicants = GF.ApplicantsPanel
		if self:IsSurfacePreloadActive() then
			invoke(applicants, "DeferProviderRefresh")
		elseif applicants and applicants.OnApplicantListUpdated then
			local session = GF.RecruitmentSession
			local canManage = session and session.CanManageApplicants
				and session:CanManageApplicants() == true
			applicants:OnApplicantListUpdated({
				preserveMissing = rosterChanged or canManage ~= true,
			})
		else
			invoke(applicants, "Refresh", { preserveScroll = true })
		end
		local alerts = GF.ApplicantAlertService
		if not (alerts and alerts.GetGeneration)
			or batch.alertGeneration == alerts:GetGeneration() then
			invoke(alerts, "HandleApplicantListChanged")
		end
	end
	if rosterChanged then
		invoke(GF.InvitationScheduler, "HandleRosterChanged")
		if self:IsSurfaceReady("browse") then
			invoke(getBrowseSurface(), "UpdateBlocked")
		end
	end
	if rosterChanged or applicantListChanged then
		invoke(GF.FloatButton, "RefreshAlert")
	end
	return true
end

function Presenter:QueueRecruitmentEvent(event)
	local generation = self._recruitmentEventGeneration or 0
	local batch = self._recruitmentEventBatch
	if type(batch) ~= "table" or batch.generation ~= generation then
		batch = { generation = generation,
			alertGeneration = invoke(GF.ApplicantAlertService, "GetGeneration") }
		self._recruitmentEventBatch = batch
	end
	if event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
		batch.applicantListChanged = true
	else
		batch.rosterChanged = true
		if event == "PARTY_LEADER_CHANGED" then
			batch.leaderChanged = true
		end
	end
	if batch.scheduled == true then
		return false
	end
	batch.scheduled = true
	local function flush()
		Presenter:FlushRecruitmentEventBatch(batch)
	end
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		local timer = C_Timer.NewTimer(0, flush)
		if self._recruitmentEventBatch == batch then
			batch.timer = timer
		end
	elseif C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, flush)
	else
		flush()
	end
	return true
end

function Presenter:RefreshSeekingNavigation()
	local transition, changed = workspaceRouter():RefreshSeekingAvailability()
	if changed then invoke(GF.TabBar, "RefreshVisibility") end
	if transition and transition.tabChanged then
		invoke(GF.TabBar, "RefreshTabStates")
		-- Hidden windows only update their route. Opening projects the fallback;
		-- background roster/listing changes never open the window or a page.
		if self:IsUserVisible() then self:OnTabChanged(transition.tabID) end
	end
	return transition
end

function Presenter:OnGroupRosterChanged(event)
	self:RefreshSeekingNavigation()
	return self:QueueRecruitmentEvent(event or "GROUP_ROSTER_UPDATE")
end

function Presenter:OnApplicantsUpdate(event)
	return self:QueueRecruitmentEvent(
		event or "LFG_LIST_APPLICANT_LIST_UPDATED")
end

function Presenter:RebuildNavigationForAvailability(refreshCreateManager,
	permissionsOnly)
	local navigation = GF.NavTree
	local expansionState = navigation and navigation.expanded
	local previousSelection = self._selection
	local isQuestSelection = previousSelection
		and previousSelection._gfQuestSearch == true
	local selectionKey = previousSelection and previousSelection.key
	local visualSelectionKey = navigation and navigation.selectedKey
	local retainedPathKeys = {}
	local previousSelectionPath
	if selectionKey and not isQuestSelection and GF.NavData
		and GF.NavData.FindLoadedNodePathByKey
	then
		local _, path = GF.NavData.FindLoadedNodePathByKey(selectionKey)
		previousSelectionPath = path
		for _, pathNode in ipairs(path or {}) do
			if pathNode and pathNode.key then
				retainedPathKeys[pathNode.key] = true
			end
		end
	end
	local rebuild = permissionsOnly
		and GF.NavData and GF.NavData.ApplyLfgRestrictions
		or GF.NavData and GF.NavData.OnAvailabilityChanged
	local changed
	if rebuild then
		changed = permissionsOnly
			and rebuild(GF.navTree)
			or rebuild(expansionState, retainedPathKeys)
	end
	invoke(GF.QuickSearch, "Invalidate")
	local reboundSelection = false
	if previousSelection then
		invoke(getBrowseSurface(), "ResetBrowsePage")
		local node
		if isQuestSelection and GF.QuestSearch and GF.QuestSearch.Resolve then
			local resolved = GF.QuestSearch:Resolve(previousSelection.questID)
			if resolved then
				local baseNode = resolved.baseNode
				if not (baseNode and baseNode.disabled) then
					node = resolved.selection
				end
				if navigation and baseNode and not baseNode.disabled then
					local oldNavKey = navigation.selectedKey
					navigation.selectedKey = baseNode.key
					if oldNavKey ~= baseNode.key then
						navigation.activeRootKey = nil
					end
				end
			end
		end
		if not node and not isQuestSelection then
			local findReplacement = GF.NavData
				and GF.NavData.FindReplacementNode
			node = findReplacement
				and findReplacement(previousSelection, previousSelectionPath)
				or nil
		end
		if node and node.disabled then
			node = nil
		end
		if navigation and visualSelectionKey == selectionKey then
			navigation.selectedKey = node and node.key or nil
			if not node then
				navigation.activeRootKey = nil
			end
		end
		self:OnSelectionChanged(node, {
			suppressCreateDrawer = true,
			availabilityRefresh = true,
		})
		reboundSelection = true
	elseif GF.LFGWorkspaceView and GF.LFGWorkspaceView.ResolveSelection then
		local workspaceID = viewOf(self):GetCurrentWorkspaceID()
		local node, path = GF.LFGWorkspaceView:ResolveSelection(workspaceID)
		if node and not node.disabled then
			invoke(GF.LFGWorkspaceView, "ApplyNavState",
				workspaceID, node, path)
			self:OnSelectionChanged(node, {
				suppressCreateDrawer = true,
				availabilityRefresh = true,
			})
			reboundSelection = true
		end
	end
	if navigation and visualSelectionKey then
		local findLoaded = GF.NavData and GF.NavData.FindNodeByKey
		local selectedNode = findLoaded and findLoaded(navigation.selectedKey)
		if not selectedNode or selectedNode.disabled then
			navigation.selectedKey = nil
			navigation.activeRootKey = nil
		end
	end
	if (changed or reboundSelection) and navigation then
		invoke(GF.NavFlyout, "HideAll")
		invoke(navigation, "Refresh")
	end
	invoke(GF.RaidBrowsePanel, "Refresh")
	if refreshCreateManager then
		invoke(GF.MythicPlusCreateManagerPanel, "Refresh")
	end
	if self:IsSurfaceReady("browse") then
		invoke(getBrowseSurface(), "UpdateSearchHint")
	end
	return changed or reboundSelection
end

function Presenter:BuildNavigationRefreshPlan(kind)
	local permissionsOnly = kind == "permission"
	return {
		kind = permissionsOnly and "permission" or "availability",
		delay = permissionsOnly and 0.1 or 0.3,
		permissionsOnly = permissionsOnly,
		refreshCreateManager = true,
	}
end

function Presenter:QueueNavigationRefresh(kind)
	local plan = self:BuildNavigationRefreshPlan(kind)
	if not self:IsUserVisible() or self._firstPresentationGate ~= nil then
		self._navDirty = true
		return false, "deferred"
	end
	invoke(viewOf(self), "RefreshRoleSelectionButtons")
	local timerKey = plan.permissionsOnly
		and "_navPermissionDebounce" or "_navDebounce"
	invoke(self[timerKey], "Cancel")
	if not (C_Timer and C_Timer.NewTimer) then
		self:RebuildNavigationForAvailability(
			plan.refreshCreateManager, plan.permissionsOnly)
		return true
	end
	self[timerKey] = C_Timer.NewTimer(plan.delay, function()
		Presenter[timerKey] = nil
		Presenter:RebuildNavigationForAvailability(
			plan.refreshCreateManager, plan.permissionsOnly)
	end)
	return true
end

function Presenter:OnAvailabilityUpdate()
	self:RefreshSeekingNavigation()
	return self:QueueNavigationRefresh("availability")
end

function Presenter:OnPremadePermissionUpdate()
	return self:QueueNavigationRefresh("permission")
end

function Presenter:FlushDeferredNavigationBeforeShow()
	if self._navDirty ~= true then
		return true
	end
	invoke(self._navDebounce, "Cancel")
	self._navDebounce = nil
	invoke(self._navPermissionDebounce, "Cancel")
	self._navPermissionDebounce = nil
	self._navDirty = false
	local ok, rebuildError = pcall(
		self.RebuildNavigationForAvailability, self, false, false)
	if not ok then
		self._navDirty = true
		reportLifecycleError(rebuildError)
		return false
	end
	return true
end

function Presenter:ResetCreateAfterManualRemove()
	if GF.CreateDrawer and GF.CreateDrawer.ResetAfterListingRemoved then
		GF.CreateDrawer:ResetAfterListingRemoved()
	else
		invoke(GF.CreateDrawer, "Close", true)
	end
	invoke(GF.CreatePanel, "ResetAfterListingRemoved")
	local workspaceID = viewOf(self):GetCurrentWorkspaceID()
	local node, path
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.ResetSelectionToDefault then
		node, path = GF.LFGWorkspaceView:ResetSelectionToDefault(workspaceID)
	end
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.ApplyNavState then
		GF.LFGWorkspaceView:ApplyNavState(workspaceID, node, path)
	elseif GF.NavTree then
		GF.NavTree.selectedKey = node and node.key or nil
		GF.NavTree.activeRootKey = path and path[1] and path[1].key or nil
		invoke(GF.NavTree, "Refresh")
	end
	invoke(GF.NavFlyout, "HideAll")
	self:OnSelectionChanged(node, {
		suppressCreateDrawer = true,
		listingRemoved = true,
	})
end

function Presenter:OnActiveEntryUpdate(opts)
	opts = opts or {}
	self:RefreshSeekingNavigation()
	local listing = GF.RecruitmentSession
	local hasActive = opts.hasActive
	if hasActive == nil then
		hasActive = listing and listing.HasActive and listing:HasActive()
	else
		hasActive = hasActive == true
	end
	local entryStateKnown = self._applicantEntryStateKnown == true
	local hadActive = self._applicantEntryWasActive == true
	self._applicantEntryStateKnown = true
	self._applicantEntryWasActive = hasActive == true
	local beganApplicantSession = entryStateKnown
		and hasActive == true and not hadActive
	local resetAfterManualRemove = not hasActive and listing
		and listing.ConsumeConfirmedUserRemoval
		and listing:ConsumeConfirmedUserRemoval()
	local bumpFailed = (opts.finalizeBump == true
		and opts.bumpSucceeded == false) or opts.bumpOutcome == "failed"
	local failedBumpStage = bumpFailed and listing
		and listing.GetLastRelistFailure and listing:GetLastRelistFailure()
	local failedBumpSession = bumpFailed
		and failedBumpStage ~= "remove_call_failed"
	if (hasActive and (opts.createdNew == true or beganApplicantSession))
		or resetAfterManualRemove or failedBumpSession
	then
		self:CancelRecruitmentEventBatch()
		invoke(GF.ApplicantsPanel, "ResetForNewApplicantSession")
	end
	local view = viewOf(self)
	if view._windowSurfacesReady ~= true then
		return
	end
	local bumpOutcome = opts.bumpOutcome
	if opts.bumpResolved ~= true and listing
		and listing.HandleRelistEntryChanged
	then
		bumpOutcome = listing:HandleRelistEntryChanged(
			hasActive == true, opts.createdNew == true)
	end
	local relisting = listing and listing.IsRelisting
		and listing:IsRelisting()
	if relisting and not hasActive and not opts.finalizeBump then
		return
	end
	invoke(listing, "SyncEntryOwnership", hasActive == true)
	if not hasActive and opts.fromActiveEntryEvent ~= true then
		invoke(GF.InvitationScheduler, "ClearSession")
	end
	if resetAfterManualRemove then
		self:ResetCreateAfterManualRemove()
	end
	local bumpSucceeded = bumpOutcome == "success"
		or opts.bumpSucceeded == true
	local forceEdit = hasActive == true and (not bumpSucceeded
		or view:GetCurrentWorkspaceID() == GF.WORKSPACE_MYTHIC_PLUS)
	if bumpSucceeded then
		invoke(GF.CreateDrawer, "Close", true)
	end
	invoke(view, "RefreshListingPanels")
	invoke(view, "RefreshRecruitEyeLogo", hasActive == true)
	self._activeEntryCreateProjectionGeneration =
		(tonumber(self._activeEntryCreateProjectionGeneration) or 0) + 1
	local createProjectionGeneration =
		self._activeEntryCreateProjectionGeneration
	if self:IsUserVisible()
		and view:GetCurrentTabID() == GF.TAB_CREATE
	then
		local function projectCreateTab()
			if self._activeEntryCreateProjectionGeneration
				~= createProjectionGeneration
			then
				return
			end
			invoke(view, "UpdateCreateTab", {
				forceEdit = forceEdit,
				suppressCreateAutoOpen = opts.suppressCreateAutoOpen == true
					or opts.fromActiveEntryEvent == true
					or resetAfterManualRemove == true
					or bumpOutcome == "failed",
			})
			self:ScheduleWhenShown(0, function()
				invoke(GF.ApplicantsPanel, "RefreshLayoutIfReady")
			end)
		end
		local deferMythicPlusCreatedProjection =
			opts.fromActiveEntryEvent == true
			and hasActive == true
			and (opts.createdNew == true or beganApplicantSession)
			and view:GetCurrentWorkspaceID() == GF.WORKSPACE_MYTHIC_PLUS
		if deferMythicPlusCreatedProjection then
			-- CreateListing may dispatch LFG_LIST_ACTIVE_ENTRY_UPDATE inside the
			-- protected button call. Rebuilding the persistent Mythic+ manager into
			-- its full edit projection here keeps that hardware stack blocked for
			-- seconds. The active-entry state is already committed above; move only
			-- the heavy visual re-projection to the next frame.
			self:ScheduleWhenShown(0, projectCreateTab)
		else
			projectCreateTab()
		end
	end
	if self:IsSurfaceReady("browse") then
		invoke(getBrowseSurface(), "RefreshList", {
			preserveScroll = true,
		})
		invoke(getBrowseSurface(), "UpdateBlocked")
	end
	invoke(GF.FloatButton, "RefreshAlert")
	if opts.questCreateOutcome == "success" then
		self:ScheduleWhenShown(0, function()
			local current = GF.RecruitmentSession
			if current and current.HasActive and current:HasActive() == true then
				Presenter:OpenCreateTab()
			end
		end)
	end
end

local function captureAndDisableMouseTree(frame, snapshot, visited)
	if frame == nil then
		return
	end
	local function frameFlag(methodName)
		local method = frame[methodName]
		if type(method) ~= "function" then
			return false
		end
		local ok, enabled = pcall(function()
			return method(frame) == true
		end)
		return ok and enabled == true
	end
	if frameFlag("IsForbidden") or frameFlag("IsProtected") then
		return
	end
	local firstVisit = visited[frame] ~= true
	visited[frame] = true
	if type(frame.EnableMouse) == "function" then
		if firstVisit then
			snapshot[#snapshot + 1] = {
				frame = frame,
				enabled = type(frame.IsMouseEnabled) == "function"
					and frame:IsMouseEnabled() == true or false,
			}
		end
		pcall(frame.EnableMouse, frame, false)
	end
	if type(frame.GetChildren) == "function" then
		local ok, children = pcall(function()
			return { frame:GetChildren() }
		end)
		if ok then
			for index = 1, #children do
				captureAndDisableMouseTree(children[index], snapshot, visited)
			end
		end
	end
end

local function restoreMouseTree(snapshot)
	for index = #snapshot, 1, -1 do
		local item = snapshot[index]
		if item.frame and type(item.frame.EnableMouse) == "function" then
			pcall(item.frame.EnableMouse, item.frame, item.enabled == true)
		end
	end
end

local function restoreShownState(frame, wasShown)
	if frame == nil then
		return
	end
	if wasShown then
		invoke(frame, "Show")
	else
		invoke(frame, "Hide")
	end
end

local function listLayoutReady(panel)
	local list = panel and panel.scrollList
	if list == nil then
		return false
	end
	if type(list.GetLayoutWidth) ~= "function" then
		return true
	end
	return (tonumber(list:GetLayoutWidth()) or 0) > 1
end

local function frameLayoutReady(frame)
	if frame == nil then
		return false
	end
	local function dimension(methodName)
		local method = frame[methodName]
		if type(method) ~= "function" then
			return 0
		end
		local ok, value = pcall(method, frame)
		return ok and (tonumber(value) or 0) or 0
	end
	return dimension("GetWidth") > 1 and dimension("GetHeight") > 1
end

local function frameParentIs(frame, expectedParent)
	if frame == nil or type(frame.GetParent) ~= "function" then
		return false
	end
	local ok, parent = pcall(frame.GetParent, frame)
	return ok and parent == expectedParent
end

local function allFramesLayoutReady(...)
	for index = 1, select("#", ...) do
		if not frameLayoutReady(select(index, ...)) then
			return false
		end
	end
	return true
end

local function setPassiveBrowsePresentation(visible)
	if GF.SubtitleBar and GF.SubtitleBar.SetBrowseVisible then
		GF.SubtitleBar:SetBrowseVisible(visible == true, {
			passiveWarmup = true,
		})
	end
end

local function setPassiveMythicPlusSidebarPresentation(visible)
	if GF.SubtitleBar and GF.SubtitleBar.SetMythicPlusSidebarMode then
		GF.SubtitleBar:SetMythicPlusSidebarMode(visible == true, {
			passiveWarmup = true,
		})
	end
end

function Presenter:WarmPreloadedSurfaceLayouts(phase)
	local view = viewOf(self)
	view:LayoutContent(false)
	if phase == "browse" then
		invoke(GF.NavTree, "DeferredRefresh")
		invoke(GF.MythicPlusBrowseFilterPanel, "Layout")
		local browse = getBrowseSurface()
		invoke(browse, "UpdateTitle")
		invoke(browse, "UpdateSearchHint")
		invoke(browse, "Relayout", { force = true })
		local browsePanel = invoke(browse, "GetPanel") or GF.BrowsePanel
		local filter = GF.MythicPlusBrowseFilterPanel
		local blocks = filter and filter.layoutBlocks or {}
		return listLayoutReady(browsePanel) and filter ~= nil
			and allFramesLayoutReady(
				filter.frame, filter.header, filter.searchBoxHost,
				filter.searchButtonHost, filter.resetButtonHost)
			and allFramesLayoutReady(
				blocks[1] and blocks[1].frame,
				blocks[2] and blocks[2].frame,
				blocks[3] and blocks[3].frame,
				blocks[4] and blocks[4].frame,
				blocks[5] and blocks[5].frame,
				blocks[6] and blocks[6].frame)
	end
	if phase == "create" then
		invoke(GF.ApplicantsPanel, "UpdateEmptyHint")
		invoke(GF.ApplicantsPanel, "Relayout", { force = true })
		invoke(GF.CreateDrawer, "Layout")
		invoke(GF.MythicPlusCreateManagerPanel, "Layout")
		invoke(GF.CreatePanel, "UpdateRequirementLayout")
		local createReady = invoke(GF.CreatePanel, "UpdateScrollLayout") == true
			and invoke(GF.CreatePanel, "IsPresentationReady", {
				requireActiveFields = false,
			}) == true
		local manager = GF.MythicPlusCreateManagerPanel
		local drawer = GF.CreateDrawer
		local managerReady = manager ~= nil
			and manager._passiveWarmupMounted == true
			and manager.mounted == true
			and allFramesLayoutReady(
				manager.frame, manager.header, manager.dungeonBlock,
				drawer and drawer.panelHost, drawer and drawer.footer)
			and frameParentIs(drawer and drawer.panelHost, manager.frame)
			and frameParentIs(drawer and drawer.footer, manager.frame)
		return listLayoutReady(GF.ApplicantsPanel)
			and createReady and managerReady
	end
	return false
end

function Presenter:FinishSurfacePreload(ticket, completed)
	local state = self._surfacePreloadState
	if state == nil or (ticket ~= nil and state.ticket ~= ticket) then
		return false
	end
	local firstError
	local function restore(action, ...)
		local ok, restoreError = pcall(action, ...)
		if not ok and firstError == nil then
			firstError = restoreError
		end
	end
	restore(restoreMouseTree, state.mouseSnapshot)
	restore(function()
		invoke(GF.MythicPlusCreateManagerPanel, "EndPassiveWarmup")
	end)
	restore(setPassiveBrowsePresentation, false)
	restore(setPassiveMythicPlusSidebarPresentation,
		state.subtitleMythicPlusMode)
	restore(setPassiveBrowsePresentation, state.subtitleBrowseMode)
	restore(restoreShownState, state.mythicCreateHeader,
		state.mythicCreateHeaderWasShown)
	restore(restoreShownState, state.mythicCreateFrame,
		state.mythicCreateWasShown)
	restore(restoreShownState, state.mythicBrowseHeader,
		state.mythicBrowseHeaderWasShown)
	restore(restoreShownState, state.mythicBrowseFrame,
		state.mythicBrowseWasShown)
	restore(restoreShownState, state.applicantsHost,
		state.applicantsWasShown)
	restore(restoreShownState, state.browseHost, state.browseWasShown)
	restore(restoreShownState, state.frame, state.frameWasShown)
	if state.frame and type(state.frame.SetAlpha) == "function" then
		restore(state.frame.SetAlpha, state.frame, state.frameAlpha)
	end
	self._surfacePreloadState = nil
	if completed == true and firstError == nil then
		self._surfacesPrewarmed = true
	end
	if firstError ~= nil then
		reportLifecycleError(firstError)
		return false
	end
	return true
end

function Presenter:CancelSurfacePreload()
	local state = self._surfacePreloadState
	if state == nil then
		return false
	end
	self._surfacePreloadTicket =
		(tonumber(self._surfacePreloadTicket) or 0) + 1
	return self:FinishSurfacePreload(state.ticket, false)
end

local function scheduleSurfacePreloadPhase(state, phase)
	state.after(0, function()
		Presenter:RunSurfacePreloadPass(state.ticket, phase)
	end)
end

local function forceDisableSurfacePreloadMouse(state)
	captureAndDisableMouseTree(
		state.frame, state.mouseSnapshot, state.mouseVisited)
end

local function beginSurfacePreloadInteractionPass(state)
	restoreMouseTree(state.mouseSnapshot)
	state.mouseSnapshot = {}
	state.mouseVisited = {}
end

function Presenter:RunSurfacePreloadPhase(state, phase)
	if not isFrameVisible(state.frame) then
		self:FinishSurfacePreload(state.ticket, false)
		return false
	end
	if InCombatLockdown and InCombatLockdown() then
		self._preloadWaitingForCombat = true
		self:FinishSurfacePreload(state.ticket, false)
		return false
	end
	local availability = GF.Availability
	if availability and availability.GetBlockMessage
		and availability:GetBlockMessage()
	then
		self:FinishSurfacePreload(state.ticket, false)
		return false
	end
	if phase == "finish" and self._navDirty == true then
		phase = "browse"
	end
	if phase == "browse" then
		state.phase = phase
		state.attempts.browse = (state.attempts.browse or 0) + 1
		beginSurfacePreloadInteractionPass(state)
		invoke(GF.MythicPlusCreateManagerPanel, "EndPassiveWarmup")
		state.mythicCreateFrame:Hide()
		state.mythicCreateHeader:Hide()
		state.mythicBrowseFrame:Show()
		state.mythicBrowseHeader:Show()
		setPassiveMythicPlusSidebarPresentation(true)
		setPassiveBrowsePresentation(true)
		state.applicantsHost:Hide()
		state.browseHost:Show()
		local ready = viewOf(self):FlushDeferredNavigationBeforeShow()
			and self:WarmPreloadedSurfaceLayouts("browse") == true
		forceDisableSurfacePreloadMouse(state)
		if not ready then
			if state.attempts.browse >= state.maxAttempts then
				self:FinishSurfacePreload(state.ticket, false)
				return false
			end
			scheduleSurfacePreloadPhase(state, "browse")
			return true
		end
		state.attempts.create = 0
		scheduleSurfacePreloadPhase(state, "create")
		return true
	end
	if phase == "create" then
		if self._navDirty == true then
			scheduleSurfacePreloadPhase(state, "browse")
			return true
		end
		state.phase = phase
		state.attempts.create = (state.attempts.create or 0) + 1
		beginSurfacePreloadInteractionPass(state)
		setPassiveBrowsePresentation(false)
		setPassiveMythicPlusSidebarPresentation(false)
		state.mythicBrowseFrame:Hide()
		state.mythicBrowseHeader:Hide()
		state.mythicCreateFrame:Show()
		state.mythicCreateHeader:Show()
		local managerMounted = invoke(
			GF.MythicPlusCreateManagerPanel, "BeginPassiveWarmup") == true
		state.browseHost:Hide()
		state.applicantsHost:Show()
		local ready = managerMounted
			and self:WarmPreloadedSurfaceLayouts("create") == true
		forceDisableSurfacePreloadMouse(state)
		if not ready then
			if state.attempts.create >= state.maxAttempts then
				self:FinishSurfacePreload(state.ticket, false)
				return false
			end
			scheduleSurfacePreloadPhase(state, "create")
			return true
		end
		scheduleSurfacePreloadPhase(state, "finish")
		return true
	end
	if phase == "finish" and isFrameVisible(state.applicantsHost)
		and isFrameVisible(state.mythicCreateFrame)
	then
		return self:FinishSurfacePreload(state.ticket, true)
	end
	self:FinishSurfacePreload(state.ticket, false)
	return false
end

function Presenter:RunSurfacePreloadPass(ticket, phase)
	local state = self._surfacePreloadState
	if state == nil or state.ticket ~= ticket then
		return false
	end
	local ok, result = pcall(
		self.RunSurfacePreloadPhase, self, state, phase or "browse")
	if not ok then
		self:FinishSurfacePreload(ticket, false)
		reportLifecycleError(result)
		return false
	end
	return result
end

function Presenter:BeginSurfacePreload()
	if self._surfacesPrewarmed == true
		or self._surfacePreloadState ~= nil
	then
		return true
	end
	if self._everShown == true then
		return false, "already-shown"
	end
	local after = C_Timer and C_Timer.After
	if type(after) ~= "function" then
		return false, "scheduler-unavailable"
	end
	local view = viewOf(self)
	local frame = view.frame
	if frame == nil or isFrameShown(frame) then
		return false, "frame-unavailable"
	end
	local browseReady = view:EnsureBrowseSurface()
	local createReady = view:EnsureCreateTabPanels({ skipSelection = true })
	local mythicPlusReady = view:EnsureMythicPlusSidePanels()
	local drawerFrame = GF.CreateDrawer and GF.CreateDrawer.frame or nil
	local mythicBrowse = GF.MythicPlusBrowseFilterPanel
	local mythicCreate = GF.MythicPlusCreateManagerPanel
	if browseReady ~= true or createReady ~= true or mythicPlusReady ~= true
		or view.browseHost == nil or view.applicantsHost == nil
		or drawerFrame == nil or isFrameShown(drawerFrame)
		or mythicBrowse == nil or mythicBrowse.frame == nil
		or mythicBrowse.header == nil or mythicCreate == nil
		or mythicCreate.frame == nil or mythicCreate.header == nil
	then
		return false, "surface-unavailable"
	end
	self._surfacePreloadTicket =
		(tonumber(self._surfacePreloadTicket) or 0) + 1
	local state = {
		ticket = self._surfacePreloadTicket,
		frame = frame,
		frameWasShown = isFrameShown(frame),
		frameAlpha = frameAlpha(frame),
		browseHost = view.browseHost,
		browseWasShown = isFrameShown(view.browseHost),
		applicantsHost = view.applicantsHost,
		applicantsWasShown = isFrameShown(view.applicantsHost),
		mythicBrowseFrame = mythicBrowse.frame,
		mythicBrowseWasShown = isFrameShown(mythicBrowse.frame),
		mythicBrowseHeader = mythicBrowse.header,
		mythicBrowseHeaderWasShown = isFrameShown(mythicBrowse.header),
		mythicCreateFrame = mythicCreate.frame,
		mythicCreateWasShown = isFrameShown(mythicCreate.frame),
		mythicCreateHeader = mythicCreate.header,
		mythicCreateHeaderWasShown = isFrameShown(mythicCreate.header),
		subtitleBrowseMode = GF.SubtitleBar
			and GF.SubtitleBar._browseMode == true or false,
		subtitleMythicPlusMode = GF.SubtitleBar
			and GF.SubtitleBar._mythicPlusSidebarMode == true or false,
		mouseSnapshot = {},
		mouseVisited = {},
		after = after,
		attempts = {},
		maxAttempts = 30,
	}
	self._surfacePreloadState = state
	local ok, beginError = pcall(function()
		if type(frame.SetAlpha) == "function" then
			frame:SetAlpha(0)
		end
		forceDisableSurfacePreloadMouse(state)
		state.mythicCreateFrame:Hide()
		state.mythicCreateHeader:Hide()
		state.mythicBrowseFrame:Show()
		state.mythicBrowseHeader:Show()
		view.applicantsHost:Hide()
		view.browseHost:Show()
		frame:Show()
		scheduleSurfacePreloadPhase(state, "browse")
	end)
	if not ok then
		self:FinishSurfacePreload(state.ticket, false)
		error(beginError, 0)
	end
	return true
end

function Presenter:Preload()
	if self._surfacesPrewarmed == true or self._everShown == true then
		self._preloadWaitingForCombat = nil
		return true
	end
	if InCombatLockdown and InCombatLockdown() then
		self._preloadWaitingForCombat = true
		return false, "combat"
	end
	local availability = GF.Availability
	if availability and availability.GetBlockMessage
		and availability:GetBlockMessage()
	then
		self._preloadWaitingForCombat = nil
		return false, "blocked"
	end
	self._preloadWaitingForCombat = nil
	local view = viewOf(self)
	local initialized = view._windowInited == true
	if not initialized then
		self._surfacePreloadPreparing = true
		local ok, initializedOrError = pcall(
			view.Init, view, workspaceRouter():ResolveInitialOpenRoute(nil),
			{ deferInitialSurface = true })
		self._surfacePreloadPreparing = nil
		if not ok then
			error(initializedOrError, 0)
		end
		initialized = initializedOrError
	end
	if initialized ~= true then
		return false, "window-unavailable"
	end
	return view:BeginSurfacePreload()
end

function Presenter:RequestPreload(delay)
	if self._surfacesPrewarmed == true or self._everShown == true
		or self:IsSurfacePreloadActive()
	then
		self._preloadWaitingForCombat = nil
		return true
	end
	if self._preloadQueued == true then
		return true
	end
	local after = C_Timer and C_Timer.After
	if type(after) ~= "function" then
		return false, "scheduler-unavailable"
	end
	self._preloadQueued = true
	self._preloadTicket = (tonumber(self._preloadTicket) or 0) + 1
	local ticket = self._preloadTicket
	after(math.max(0, tonumber(delay) or 2), function()
		if Presenter._preloadTicket ~= ticket then
			return
		end
		Presenter._preloadQueued = nil
		Presenter:Preload()
	end)
	return true
end

function Presenter:ResumePreload()
	if self._surfacesPrewarmed == true or self._everShown == true then
		self._preloadWaitingForCombat = nil
		return true
	end
	if self._preloadWaitingForCombat ~= true then
		return false
	end
	self._preloadWaitingForCombat = nil
	local queued, reason = self:RequestPreload(0)
	if not queued then
		self._preloadWaitingForCombat = true
	end
	return queued, reason
end

function Presenter:ActivePresentationLayoutReady()
	local view = viewOf(self)
	view:LayoutContent(false)
	local tabID = view:GetCurrentTabID()
	if tabID == GF.TAB_BROWSE then
		local filterReady = true
		if view:IsMythicPlusBrowseFilterVisible(tabID) then
			local filter = GF.MythicPlusBrowseFilterPanel
			invoke(filter, "Layout")
			invoke(filter, "Refresh")
			filterReady = filter ~= nil
				and isFrameVisible(filter.frame)
				and isFrameVisible(filter.header)
				and allFramesLayoutReady(
					filter.frame, filter.header, filter.searchBoxHost,
					filter.searchButtonHost, filter.resetButtonHost)
		end
		local raid = GF.RaidBrowsePanel
		if raid and raid:ShouldUse(tabID, view:GetCurrentWorkspaceID()) then
			invoke(raid, "Refresh")
			filterReady = isFrameVisible(raid.frame) and isFrameVisible(raid.header)
				and allFramesLayoutReady(raid.frame, raid.header,
					raid.list and raid.list:GetScrollBox())
		end
		local browse = getBrowseSurface()
		invoke(browse, "Relayout", { force = true })
		return filterReady
			and listLayoutReady(invoke(browse, "GetPanel") or GF.BrowsePanel)
	end
	if tabID == GF.TAB_CREATE then
		invoke(GF.ApplicantsPanel, "UpdateEmptyHint")
		invoke(GF.ApplicantsPanel, "Relayout", { force = true })
		invoke(GF.CreateDrawer, "Layout")
		local drawerFrame = GF.CreateDrawer and GF.CreateDrawer.frame or nil
		local manager = GF.MythicPlusCreateManagerPanel
		local managerRequired = view:IsMythicPlusCreateManagerVisible(tabID)
		local raid, raidReady = GF.RaidBrowsePanel, true
		if not managerRequired and raid and raid:ShouldUse(tabID, view:GetCurrentWorkspaceID()) then
			invoke(raid, "Refresh")
			raidReady = isFrameVisible(raid.frame) and isFrameVisible(raid.header)
				and allFramesLayoutReady(raid.frame, raid.header,
					raid.list and raid.list:GetScrollBox())
		end
		local managerActive = managerRequired
			and invoke(manager, "IsSurfaceActive") == true
		if managerRequired and not managerActive then
			invoke(manager, "Open", { presentationGate = true })
			managerActive = invoke(manager, "IsSurfaceActive") == true
		end
		if managerActive then
			invoke(manager, "Layout")
			invoke(manager, "LayoutMountedHosts")
		end
		local requireActiveFields = isFrameShown(drawerFrame)
			or managerActive == true
		if requireActiveFields then
			invoke(GF.CreatePanel, "RefreshCreateFieldHandoff")
		end
		invoke(GF.CreatePanel, "UpdateRequirementLayout")
		invoke(GF.CreatePanel, "UpdateScrollLayout")
		local createReady = not requireActiveFields
			or invoke(GF.CreatePanel, "IsPresentationReady", {
				requireActiveFields = true,
			}) == true
		local managerReady = not managerRequired
		local drawer = GF.CreateDrawer
		managerReady = managerReady or (managerActive
			and isFrameVisible(manager.frame)
			and isFrameVisible(manager.header)
			and allFramesLayoutReady(
				manager.frame, manager.header, manager.dungeonBlock,
				drawer and drawer.panelHost, drawer and drawer.footer)
			and frameParentIs(drawer and drawer.panelHost, manager.frame)
			and frameParentIs(drawer and drawer.footer, manager.frame))
		return listLayoutReady(GF.ApplicantsPanel)
			and createReady and managerReady and raidReady
	end
	return true
end

function Presenter:CurrentPresentationSurface()
	local tabID = viewOf(self):GetCurrentTabID()
	if tabID == GF.TAB_BROWSE then
		return "browse"
	elseif tabID == GF.TAB_CREATE then
		return "create"
	end
	return "tab:" .. tostring(tabID or "unknown")
end

function Presenter:PresentationGateKey(surface)
	return table.concat({
		"workspace",
		tostring(viewOf(self):GetCurrentWorkspaceID()),
		tostring(surface),
	}, ":")
end

function Presenter:CurrentPresentationGateKey()
	return self:PresentationGateKey(self:CurrentPresentationSurface())
end

function Presenter:CurrentPresentationSignature()
	return table.concat({
		tostring(viewOf(self):GetCurrentWorkspaceID()),
		tostring(viewOf(self):GetCurrentTabID()),
		isFrameShown(GF.CreateDrawer and GF.CreateDrawer.frame)
			and "drawer" or "main",
	}, "|")
end

function Presenter:BeginFirstPresentationGate(surfaceKey, options)
	local view = viewOf(self)
	if view._windowSurfacesReady ~= true then
		return nil, false
	end
	local key = surfaceKey ~= nil
		and self:PresentationGateKey(surfaceKey)
		or self:CurrentPresentationGateKey()
	local restartDrawerPopup = surfaceKey == "create-drawer"
		and not (type(options) == "table"
			and options.suppressPopupMotion == true)
	self._presentationReadyByKey = self._presentationReadyByKey or {}
	local existing = self._firstPresentationGate
	if existing then
		existing.requestedKeys[key] = true
		if surfaceKey == "create-drawer" then
			existing.drawerGateKeys[key] = true
			existing.restartDrawerPopup = restartDrawerPopup
		end
		existing.readyPasses = 0
		existing.attempts = 0
		existing.signature = nil
		local drawerFrame = GF.CreateDrawer and GF.CreateDrawer.frame or nil
		if existing.drawerFrame == nil and drawerFrame ~= nil then
			existing.drawerFrame = drawerFrame
			existing.targetDrawerAlpha = frameAlpha(drawerFrame)
			if type(drawerFrame.SetAlpha) == "function" then
				drawerFrame:SetAlpha(0)
			end
		end
		return existing.ticket, false
	end
	if self._presentationReadyByKey[key] == true then
		return nil, false
	end
	local after = C_Timer and C_Timer.After
	local frame = view.frame
	if type(after) ~= "function" or frame == nil then
		return nil, false
	end
	self._firstPresentationTicket =
		(tonumber(self._firstPresentationTicket) or 0) + 1
	local drawerFrame = GF.CreateDrawer and GF.CreateDrawer.frame or nil
	local state = {
		ticket = self._firstPresentationTicket,
		frame = frame,
		drawerFrame = drawerFrame,
		targetFrameAlpha = frameAlpha(frame),
		targetDrawerAlpha = frameAlpha(drawerFrame),
		mouseSnapshot = {},
		mouseVisited = {},
		after = after,
		requestedKeys = { [key] = true },
		drawerGateKeys = surfaceKey == "create-drawer"
			and { [key] = true } or {},
		restartDrawerPopup = restartDrawerPopup,
		readyPasses = 0,
		attempts = 0,
		maxAttempts = 30,
		scheduled = false,
	}
	self._firstPresentationGate = state
	local armed, armError = pcall(function()
		if type(frame.SetAlpha) == "function" then
			frame:SetAlpha(0)
		end
		if drawerFrame and type(drawerFrame.SetAlpha) == "function" then
			drawerFrame:SetAlpha(0)
		end
		state.after(0, function()
			Presenter:RunFirstPresentationGate(state.ticket)
		end)
		state.scheduled = true
	end)
	if not armed then
		pcall(self.FinishFirstPresentationGate, self, state.ticket, false)
		reportLifecycleError(armError)
		return nil, false
	end
	return state.ticket, true
end

function Presenter:ReleaseFirstPresentationGateInteraction()
	local state = self._firstPresentationGate
	if state == nil then
		return false
	end
	restoreMouseTree(state.mouseSnapshot)
	state.mouseSnapshot = {}
	state.mouseVisited = {}
	return true
end

function Presenter:HoldFirstPresentationGate(ticket)
	local state = self._firstPresentationGate
	if state == nil or state.ticket ~= ticket then
		return false
	end
	if #state.mouseSnapshot > 0 then
		return true
	end
	local currentMainAlpha = frameAlpha(state.frame)
	if currentMainAlpha > 0 then
		state.targetFrameAlpha = currentMainAlpha
	end
	local currentDrawerAlpha = frameAlpha(state.drawerFrame)
	if currentDrawerAlpha > 0 then
		state.targetDrawerAlpha = currentDrawerAlpha
	end
	if state.frame and type(state.frame.SetAlpha) == "function" then
		state.frame:SetAlpha(0)
	end
	if state.drawerFrame and type(state.drawerFrame.SetAlpha) == "function" then
		state.drawerFrame:SetAlpha(0)
	end
	captureAndDisableMouseTree(
		state.frame, state.mouseSnapshot, state.mouseVisited)
	captureAndDisableMouseTree(
		state.drawerFrame, state.mouseSnapshot, state.mouseVisited)
	return true
end

function Presenter:FinishFirstPresentationGate(ticket, completed)
	local state = self._firstPresentationGate
	if state == nil or (ticket ~= nil and state.ticket ~= ticket) then
		return false
	end
	self:ReleaseFirstPresentationGateInteraction()
	self._firstPresentationGate = nil
	if state.frame and type(state.frame.SetAlpha) == "function" then
		state.frame:SetAlpha(state.targetFrameAlpha)
	end
	if state.drawerFrame and type(state.drawerFrame.SetAlpha) == "function" then
		state.drawerFrame:SetAlpha(state.targetDrawerAlpha)
	end
	if completed == true then
		local ready = self._presentationReadyByKey or {}
		ready[self:CurrentPresentationGateKey()] = true
		if isFrameShown(state.drawerFrame) then
			for drawerKey in pairs(state.drawerGateKeys or {}) do
				ready[drawerKey] = true
			end
		end
		self._presentationReadyByKey = ready
		if state.restartDrawerPopup == true
			and isFrameShown(state.drawerFrame)
			and GF.UI and GF.UI.PlayPopupOpenAnimation
		then
			pcall(GF.UI.PlayPopupOpenAnimation, state.drawerFrame,
				state.drawerFrame._gfPopupOpenMotionOptions)
		end
	end
	return true
end

function Presenter:CancelFirstPresentationGate()
	local state = self._firstPresentationGate
	if state == nil then
		return false
	end
	self._firstPresentationTicket =
		(tonumber(self._firstPresentationTicket) or 0) + 1
	return self:FinishFirstPresentationGate(state.ticket, false)
end

function Presenter:RunFirstPresentationGate(ticket)
	local state = self._firstPresentationGate
	if state == nil or state.ticket ~= ticket then
		return false
	end
	if not isFrameVisible(state.frame) then
		return self:FinishFirstPresentationGate(ticket, false)
	end
	self:ReleaseFirstPresentationGateInteraction()
	local navigationChanged = false
	if self._navDirty == true then
		navigationChanged =
			viewOf(self):FlushDeferredNavigationBeforeShow() == true
		state.readyPasses = 0
	end
	local signature = self:CurrentPresentationSignature()
	if signature ~= state.signature then
		state.signature = signature
		state.readyPasses = 0
		state.attempts = 0
	end
	local ok, readyOrError = pcall(self.ActivePresentationLayoutReady, self)
	if not ok then
		self:FinishFirstPresentationGate(ticket, false)
		reportLifecycleError(readyOrError)
		return false
	end
	self:HoldFirstPresentationGate(ticket)
	state.attempts = state.attempts + 1
	if readyOrError == true and (not self._navDirty or navigationChanged) then
		state.readyPasses = state.readyPasses + 1
	else
		state.readyPasses = 0
	end
	if state.readyPasses >= 2 then
		return self:FinishFirstPresentationGate(ticket, true)
	elseif state.attempts >= state.maxAttempts then
		return self:FinishFirstPresentationGate(ticket, false)
	end
	local scheduled, scheduleError = pcall(state.after, 0, function()
		Presenter:RunFirstPresentationGate(ticket)
	end)
	if not scheduled then
		self:FinishFirstPresentationGate(ticket, false)
		reportLifecycleError(scheduleError)
		return false
	end
	return true
end

function Presenter:ScheduleFirstPresentationGate(ticket)
	local state = self._firstPresentationGate
	if state == nil or state.ticket ~= ticket then
		return false
	end
	self:HoldFirstPresentationGate(ticket)
	if state.scheduled == true then
		return true
	end
	state.scheduled = true
	local scheduled, scheduleError = pcall(state.after, 0, function()
		Presenter:RunFirstPresentationGate(ticket)
	end)
	if not scheduled then
		self:FinishFirstPresentationGate(ticket, false)
		reportLifecycleError(scheduleError)
		return false
	end
	return true
end

function Presenter:ApplyOpenRoute(route, opts)
	local view = viewOf(self)
	if type(route) ~= "table" or view._windowSurfacesReady ~= true then
		return false, false
	end
	return workspaceRouter():ApplyOpenRoute(
		route, opts, GF.WorkspaceBar, GF.TabBar)
end

function Presenter:ShowFrame(route)
	local availability = GF.Availability
	if availability then
		local blockMessage = availability:GetBlockMessage()
		if blockMessage then
			availability:NotifyBlocked(blockMessage)
			return
		end
	end
	invoke(GF.UsageGuideDialog, "CloseForMainFrameOpen")
	self:CancelSurfacePreload()
	self:ReleaseFirstPresentationGateInteraction()
	self:RefreshSeekingNavigation()
	local view = viewOf(self)
	local wasInitialized = view._windowInited == true
	local wasShown = wasInitialized and view.frame
		and view.frame:IsShown() or false
	local initialRoute
	if not wasInitialized then
		initialRoute = workspaceRouter():CommitInitialOpenRoute(route)
	end
	view:Init(initialRoute)
	local frame = view.frame
	if not frame then
		return
	end
	local routeProjected = false
	if wasInitialized then
		local _, projected = view:ApplyOpenRoute(route, {
			silent = not wasShown,
		})
		routeProjected = projected
	end
	if not wasInitialized then
		routeProjected = true
	elseif not routeProjected then
		local currentTabID = view:GetCurrentTabID()
		local wasSurfaceReady = self:IsSurfaceReadyForTab(currentTabID)
		if self:EnsureSurfaceForTab(currentTabID) == true
			and (not wasShown or not wasSurfaceReady)
		then
			self:ProjectSurfaceForTab(currentTabID, {
				skipDeferredLayout = not wasShown,
				surfaceReady = true,
			})
			routeProjected = true
		end
	end
	local motion = frame._gfWindowMotion
	if not motion and GF.UI.InstallWindowFloatMotion then
		motion = GF.UI.InstallWindowFloatMotion(frame, {
			multiplyAlpha = true,
			isPaused = function() return self._firstPresentationGate ~= nil end,
			hideImmediately = function()
				return self:IsSurfacePreloadActive() or self._firstPresentationGate ~= nil
			end,
		})
	end
	local returning = self._everShown == true
	self._everShown = true
	GF.UI.ApplySettingsFrameChrome(
		frame, (GF.L or {}).ADDON_NAME or "GroupFinder")
	invoke(view, "RefreshRecruitEyeLogo")
	if not GF.navTree and not returning then
		GF.NavData.Rebuild()
	end
	if motion and (not wasShown or motion:IsClosing()) then
		motion:Open(not wasShown)
	end
	frame:Show()
	if self._navDirty then
		-- Availability events can arrive while the shell is hidden. Rebuild after
		-- the first paint so native catalog work never blocks the opening click.
		-- Keep the dirty bit until this callback actually runs; closing the frame
		-- carries the refresh into the next open instead of dropping it.
		self:ScheduleWhenShown(0, function()
			if not Presenter._navDirty then
				return
			end
			invoke(Presenter._navDebounce, "Cancel")
			Presenter._navDebounce = nil
			invoke(Presenter._navPermissionDebounce, "Cancel")
			Presenter._navPermissionDebounce = nil
			local ok, rebuildError = pcall(
				Presenter.RebuildNavigationForAvailability,
				Presenter, false, false)
			if not ok then
				Presenter._navDirty = true
				reportLifecycleError(rebuildError)
				return
			end
			Presenter._navDirty = false
		end)
	end
	invoke(view, "RefreshRoleSelectionButtons")
	invoke(GF.SubtitleBar, "ReclaimSearchBoxForBrowse")
	invoke(GF.FloatButton, "RefreshAlert")
	local currentTab = view:GetCurrentTabID()
	if currentTab == GF.TAB_CREATE and not wasShown then
		invoke(view, "UpdateCreateTab", {
			allowOccupiedPrompt = true,
			allowCreateAutoOpen = true,
		})
	end
	if not wasShown and self._suppressNextShowSound then
		self._suppressNextShowSound = nil
	elseif not wasShown and GF.UI and GF.UI.PlayUISound then
		GF.UI.PlayUISound("open")
	end
	invoke(view, "SetZoneListenerEnabled", true)
	if not wasShown then
		view:ScheduleDeferredShowLayout()
	end
	if currentTab == GF.TAB_BROWSE and self:IsSurfaceReady("browse") then
		invoke(getBrowseSurface(), "UpdateTitle")
		invoke(getBrowseSurface(), "UpdateSearchHint")
	end
	invoke(GF.SubtitleBar, "UpdateFilterState")
	if returning and currentTab == GF.TAB_BROWSE and view.activityCount then
		view:UpdateActivityCount(invoke(GF.Result, "GetCount") or 0)
	end
	return true
end

function Presenter:ApplyHideSideEffects()
	invoke(GF.StarredLeadersPanel, "Hide")
	invoke(GF.RaidSeekingPanel, "Hide")
	self:CancelShowDeferredWork()
	invoke(GF.ApplicantsPanel, "PausePresentation")
	invoke(GF.NavFlyout, "HideAll")
	invoke(GF.FilterPanel, "Hide")
	invoke(GF.MythicPlusCreateManagerPanel, "SetVisible", false)
	invoke(GF.CreateDrawer, "Close", true)
	if self:IsSurfaceReady("browse") then
		invoke(getBrowseSurface(), "OnFrameHidden")
	end
	invoke(GF.SubtitleBar, "ReleaseBlizzardSearchBox")
	invoke(GF.CreatePanel, "ReleaseCreateFields", "addon")
	invoke(GF.NavCatalogOverlay, "Resume")
	if GF.Hook and GF.Hook.OnGFUIClosed then
		GF.Hook.OnGFUIClosed()
	end
end

function Presenter:OnViewHidden()
	local frame = viewOf(self).frame
	if frame and frame._gfWindowMotion then frame._gfWindowMotion:Reset() end
	if self:IsSurfacePreloadActive() then
		return false
	end
	self:CancelFirstPresentationGate()
	local view = viewOf(self)
	local hadOpened = self._everShown == true
	invoke(view, "SetZoneListenerEnabled", false)
	if view.frame then
		GF.SaveFrameLayout(view.frame)
	end
	if hadOpened then
		self:ApplyHideSideEffects()
		if self._suppressNextHideSound then
			self._suppressNextHideSound = nil
		elseif GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("close")
		end
	end
	invoke(GF.FloatButton, "RefreshAlert")
	return true
end

function Presenter:HideFrame(immediate)
	if self:CancelSurfacePreload() then
		return
	end
	local gated = self._firstPresentationGate ~= nil
	self:CancelFirstPresentationGate()
	local frame = viewOf(self).frame
	if frame and frame:IsShown() then
		if frame._gfWindowMotion and (immediate or gated) then
			frame._gfWindowMotion:HideImmediately()
		else
			frame:Hide()
		end
	end
end

function Presenter:HasActiveListing()
	local session = GF.RecruitmentSession
	local hasActive = session and session.HasActive
	if type(hasActive) ~= "function" then
		return false
	end
	local ok, active = pcall(hasActive, session)
	return ok and active == true
end

function Presenter:ApplyOpenTabPolicy()
	if self:HasActiveListing() then
		invoke(GF.TabBar, "SelectTab", GF.TAB_CREATE)
	end
end

function Presenter:OpenFrame()
	local route = self:HasActiveListing() and {
		tabID = GF.TAB_CREATE,
	} or nil
	return viewOf(self):OpenRoute(route)
end

function Presenter:OpenRoute(route, opts)
	viewOf(self):ShowFrame(route)
	local visible = self:IsUserVisible()
	if not visible then
		return false, false
	end
	if type(opts) == "table" and opts.flushDeferredNavigation == true
		and self:FlushDeferredNavigationBeforeShow() ~= true
	then
		return true, false
	end
	return true, true
end

function Presenter:OpenBrowseTab()
	return viewOf(self):OpenRoute({ tabID = GF.TAB_BROWSE })
end

function Presenter:OpenCreateTab()
	return viewOf(self):OpenRoute({ tabID = GF.TAB_CREATE })
end

function Presenter:OpenRaidConversation(key)
	local router, panel = workspaceRouter(), GF.RaidSeekingPanel
	if not panel then return false end
	local previousHistory = router._seekingHistoryKey
	local route = router:PrepareConversationRoute(key)
	if not route then return false end
	panel.pendingConversationKey = key
	local opened = viewOf(self):OpenRoute(route)
	if not opened then
		panel.pendingConversationKey, router._seekingHistoryKey = nil, previousHistory
		self:RefreshSeekingNavigation()
		return false
	end
	-- A visible page may already be active and therefore skip ShowTab.
	panel:RevealPendingConversation()
	return true
end

function Presenter:OpenMythicPlusTab(tabID)
	return viewOf(self):OpenRoute({
		workspaceID = GF.WORKSPACE_MYTHIC_PLUS,
		tabID = tabID,
	})
end

function Presenter:ToggleRoute(route)
	route = type(route) == "table" and route or {}
	local routeIsVisible = self:IsUserVisible()
	if routeIsVisible then
		routeIsVisible = workspaceRouter():IsRouteActive(
			route,
			viewOf(self):GetCurrentWorkspaceID(),
			viewOf(self):GetCurrentTabID())
	end
	if routeIsVisible then
		viewOf(self):HideFrame()
		return false
	end
	return viewOf(self):OpenRoute(route)
end

function Presenter:Toggle()
	if self:IsUserVisible() then
		viewOf(self):HideFrame()
	else
		viewOf(self):OpenFrame()
	end
end

function Presenter:OpenSettingsTab()
	return viewOf(self):OpenRoute({ tabID = GF.TAB_SETTINGS })
end
