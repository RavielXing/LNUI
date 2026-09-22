local _, GF = ...

-- NativeEntryRouter owns the narrow PvE handoff policy. Hook.lua only adds
-- secure post-hooks and never replaces a Blizzard global entry point.
GF.NativeEntryRouter = GF.NativeEntryRouter or {}
local Router = GF.NativeEntryRouter

local questEyeProxies = setmetatable({}, { __mode = "k" })

local function dismissPanel(panel)
	local visible = panel and type(panel.IsShown) == "function"
		and panel:IsShown()
	if visible and type(HideUIPanel) == "function" then
		pcall(HideUIPanel, panel)
	end
end

function Router:DismissNativePVEFrame()
	-- PVEFrame is shared by PvE and PvP. This is called only after an exact
	-- GroupFinderFrame/LFGListPVEStub handoff has been accepted.
	dismissPanel(_G.PVEFrame)
end

function Router:ShouldPreferOpen()
	local db = GF.GetDB and GF.GetDB()
	return db and db.preferOpen == true
end

function Router:HasActiveOutgoingApplication()
	local applications = GF.Apply
	local query = applications and applications.HasActiveApplication
	return type(query) == "function" and query(applications) == true
end

local function selectGFTab(tabID)
	if not GF.TabBar then
		return
	end
	if GF.TabBar.Select then
		GF.TabBar:Select(tabID)
	elseif GF.TabBar.SelectTab then
		GF.TabBar:SelectTab(tabID)
	end
end

function Router:OpenGroupFinderFromPremadeEntry(toggle)
	if not GF.MainFrame then
		return false
	end
	local targetTab = self:HasActiveOutgoingApplication()
		and GF.TAB_BROWSE or GF.TAB_CREATE
	local frame = GF.MainFrame.frame
	local currentTab = GF.TabBar and GF.TabBar.GetCurrent
		and GF.TabBar:GetCurrent()
	local userVisible = GF.MainFrame.IsUserVisible
		and GF.MainFrame:IsUserVisible()
		or (not GF.MainFrame.IsUserVisible
			and frame and frame:IsShown())
	if toggle and userVisible and currentTab == targetTab then
		self:DismissNativePVEFrame()
		GF.MainFrame:HideFrame()
		return true
	end
	if GF.MainFrame.OpenRoute then
		local ok, opened = pcall(GF.MainFrame.OpenRoute, GF.MainFrame, {
			tabID = targetTab,
		})
		if not ok or opened ~= true then
			-- The native PvE panel has already opened. Leave it available when
			-- GroupFinder cannot take ownership instead of hiding both surfaces.
			return false
		end
	elseif targetTab == GF.TAB_BROWSE and GF.MainFrame.OpenBrowseTab then
		GF.MainFrame:OpenBrowseTab()
	elseif GF.MainFrame.OpenCreateTab then
		GF.MainFrame:OpenCreateTab()
	else
		GF.MainFrame:OpenFrame()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if GF.MainFrame
				and ((GF.MainFrame.IsUserVisible
					and GF.MainFrame:IsUserVisible())
					or (not GF.MainFrame.IsUserVisible
						and GF.MainFrame.frame
						and GF.MainFrame.frame:IsShown()))
				and GF.TabBar
			then
				selectGFTab(targetTab)
			end
		end)
	end
	self:DismissNativePVEFrame()
	return true
end

function Router:ShouldUseNativeOpenBestWindow()
	-- The unresolved 12.1 censored edit handoff must stay in Blizzard's
	-- creation container. The existing popup flow normally intercepts it first.
	local listing = GF.RecruitmentSession
	if listing and listing.GetActiveCensoredState then
		local state = listing:GetActiveCensoredState()
		return state
			and state.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
	end
	return false
end

local function isAccessibleExactValue(value, expected)
	local compat = GF.Compat
	if compat and type(compat.IsAccessibleValue) == "function" then
		if compat.IsAccessibleValue(value) ~= true then
			return false
		end
	else
		if type(canaccessvalue) == "function" then
			local ok, accessible = pcall(canaccessvalue, value)
			if not ok or accessible ~= true then
				return false
			end
		end
		if type(issecretvalue) == "function" then
			local ok, secret = pcall(issecretvalue, value)
			if not ok or secret == true then
				return false
			end
		end
	end
	local ok, matches = pcall(function()
		return value == expected
	end)
	return ok and matches == true
end

function Router:IsNativePremadeFindRoute(sidePanelName, selection)
	return isAccessibleExactValue(sidePanelName, "GroupFinderFrame")
		and isAccessibleExactValue(selection, "LFGListPVEStub")
end

function Router:IsNativePVEPremadeFrameVisible()
	local container = _G.PVEFrame
	local groupFinder = _G.GroupFinderFrame
	local containerVisible = container and type(container.IsShown) == "function"
		and container:IsShown() == true
	local groupFinderVisible = groupFinder
		and type(groupFinder.IsShown) == "function"
		and groupFinder:IsShown() == true
	return containerVisible and groupFinderVisible
end

function Router:OpenGroupFinderBrowseFromNativeFindEntry()
	local mainFrame = GF.MainFrame
	if not (mainFrame and type(mainFrame.OpenRoute) == "function") then
		return false
	end
	local availability = GF.Availability
	if availability and type(availability.GetBlockMessage) == "function"
		and availability:GetBlockMessage() ~= nil
	then
		return false
	end
	local ok, opened = pcall(mainFrame.OpenRoute, mainFrame, {
		workspaceID = GF.WORKSPACE_MEETING_STONE,
		tabID = GF.TAB_BROWSE,
	})
	if not ok or opened ~= true then
		return false
	end
	self:DismissNativePVEFrame()
	return true
end

function Router:CancelPendingPVEEntryRoute()
	self._pendingPVEEntryRouteTicket = (self._pendingPVEEntryRouteTicket or 0) + 1
	self._pendingPVEEntryRoute = nil
end

function Router:QueuePVEEntryRoute(kind, toggle)
	if self:ShouldPreferOpen() ~= true
		or self:ShouldUseNativeOpenBestWindow()
		or not (C_Timer and type(C_Timer.After) == "function")
	then
		return false
	end
	local ticket = (self._pendingPVEEntryRouteTicket or 0) + 1
	self._pendingPVEEntryRouteTicket = ticket
	self._pendingPVEEntryRoute = {
		kind = kind,
		toggle = toggle == true,
	}
	C_Timer.After(0, function()
		if self._pendingPVEEntryRouteTicket ~= ticket then
			return
		end
		local route = self._pendingPVEEntryRoute
		self._pendingPVEEntryRoute = nil
		if not route or self:ShouldPreferOpen() ~= true
			or self:ShouldUseNativeOpenBestWindow()
		then
			return
		end
		if route.kind == "open_best" then
			self:OpenGroupFinderFromPremadeEntry(route.toggle)
		else
			self:OpenGroupFinderBrowseFromNativeFindEntry()
		end
	end)
	return true
end

function Router:OnNativePVEFrameShowFrame(sidePanelName, selection)
	if self:IsNativePremadeFindRoute(sidePanelName, selection) then
		return self:QueuePVEEntryRoute("native_pve")
	end
	return false
end

function Router:OnNativePVEFrameToggleFrame(sidePanelName, selection)
	if self:IsNativePremadeFindRoute(sidePanelName, selection) then
		return self:QueuePVEEntryRoute("native_pve")
	end
	return false
end

function Router:OnNativeOpenBestWindow(toggle)
	if self:ShouldPreferOpen() ~= true or self:ShouldUseNativeOpenBestWindow() then
		return false
	end
	if self._pendingPVEEntryRoute ~= nil
		or self:IsNativePVEPremadeFrameVisible()
	then
		return self:QueuePVEEntryRoute("open_best", toggle)
	end
	return false
end

local function readableQuestID(value)
	if not isAccessibleExactValue(value, value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or type(number) ~= "number" or number <= 0
		or number ~= math.floor(number)
	then
		return nil
	end
	return number
end

function Router:CanRouteQuestEye(questID)
	questID = readableQuestID(questID)
	if self:ShouldPreferOpen() ~= true or not questID then
		return false
	end
	if GF.Availability and type(GF.Availability.GetBlockMessage) == "function"
		and GF.Availability:GetBlockMessage() ~= nil
	then
		return false
	end
	if not (GF.FindGroupTab and type(GF.FindGroupTab.FindQuestGroup) == "function") then
		return false
	end
	local bridge = GF.QuestSearch
	if not (bridge and type(bridge.Resolve) == "function") then
		return false
	end
	local ok, resolved = pcall(bridge.Resolve, bridge, questID)
	return ok and type(resolved) == "table"
end

function Router:RouteQuestEyeProxy(questID)
	questID = readableQuestID(questID)
	if not questID or not self:CanRouteQuestEye(questID) then
		return false
	end
	local requestState = {}
	local ok, tookOwnership = pcall(
		GF.FindGroupTab.FindQuestGroup,
		GF.FindGroupTab,
		questID,
		requestState
	)
	return ok and (tookOwnership == true or requestState.tookOwnership == true)
end

local function sourceIsUsable(source)
	if not source or type(source.IsShown) ~= "function" then
		return false
	end
	if source:IsShown() ~= true then
		return false
	end
	return type(source.IsEnabled) ~= "function" or source:IsEnabled() == true
end

local function syncQuestEyeProxy(router, record)
	local source = record.source
	local proxy = record.proxy
	if not (source and proxy) then
		return
	end
	local enabled = sourceIsUsable(source)
		and router:CanRouteQuestEye(proxy._gfQuestID)
	proxy:SetEnabled(enabled)
	proxy:SetShown(enabled)
end

local function forwardSourceScript(proxy, eventName, ...)
	local source = proxy._gfQuestEyeSource
	local callback = source and type(source.GetScript) == "function"
		and source:GetScript(eventName)
	if type(callback) == "function" then
		pcall(callback, source, ...)
	end
end

function Router:InstallQuestEyeProxy(source, questID)
	if not source or type(CreateFrame) ~= "function" then
		return false
	end
	local record = questEyeProxies[source]
	if not record then
		local ok, proxy = pcall(CreateFrame, "Button", nil, source)
		if not ok or not proxy then
			return false
		end
		proxy:SetAllPoints(source)
		if type(source.GetFrameLevel) == "function"
			and type(proxy.SetFrameLevel) == "function"
		then
			proxy:SetFrameLevel(source:GetFrameLevel() + 1)
		end
		proxy:RegisterForClicks("LeftButtonUp")
		proxy:SetScript("OnEnter", function(self)
			forwardSourceScript(self, "OnEnter")
		end)
		proxy:SetScript("OnLeave", function(self)
			forwardSourceScript(self, "OnLeave")
		end)
		proxy:SetScript("OnMouseDown", function(self, ...)
			forwardSourceScript(self, "OnMouseDown", ...)
		end)
		proxy:SetScript("OnMouseUp", function(self, ...)
			forwardSourceScript(self, "OnMouseUp", ...)
		end)
		proxy:SetScript("OnClick", function(self)
			local router = GF.NativeEntryRouter
			if not (router and router:RouteQuestEyeProxy(self._gfQuestID))
				and router and router.RefreshQuestEyeProxies
			then
				router:RefreshQuestEyeProxies()
			end
		end)
		proxy._gfQuestEyeSource = source
		proxy:Hide()
		record = {
			source = source,
			proxy = proxy,
		}
		questEyeProxies[source] = record
		if type(source.HookScript) == "function" then
			local function sync()
				syncQuestEyeProxy(Router, record)
			end
			source:HookScript("OnShow", sync)
			source:HookScript("OnHide", sync)
			source:HookScript("OnEnable", sync)
			source:HookScript("OnDisable", sync)
		end
	end
	record.proxy._gfQuestID = questID
	syncQuestEyeProxy(self, record)
	return record.proxy:IsShown() == true
end

function Router:RefreshQuestEyeProxies()
	for _, record in pairs(questEyeProxies) do
		syncQuestEyeProxy(self, record)
	end
end
