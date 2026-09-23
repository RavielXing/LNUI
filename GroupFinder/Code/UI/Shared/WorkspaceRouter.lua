local _, GF = ...

GF.WorkspaceRouter = {}
local Router = GF.WorkspaceRouter

local MEETING_STONE_TAB_ORDER = {
	GF.TAB_BROWSE,
	GF.TAB_CREATE,
	GF.TAB_BLOCKLIST,
	GF.TAB_SETTINGS,
}

local MYTHIC_PLUS_TAB_ORDER = {
	GF.TAB_BROWSE,
	GF.TAB_CREATE,
	GF.TAB_MPLUS_CHARACTER,
	GF.TAB_MPLUS_CARPOOL,
	GF.TAB_MPLUS_DUNGEON,
	GF.TAB_BLOCKLIST,
	GF.TAB_SETTINGS,
}

local RAID_TAB_ORDER = {
	GF.TAB_BROWSE, GF.TAB_CREATE, GF.TAB_RAID_SEEK, GF.TAB_RAID_SQUARE,
	GF.TAB_STARRED_LEADERS, GF.TAB_BLOCKLIST, GF.TAB_SETTINGS,
}

local ALL_TAB_IDS = {
	GF.TAB_BROWSE,
	GF.TAB_CREATE,
	GF.TAB_BLOCKLIST,
	GF.TAB_SETTINGS,
	GF.TAB_MPLUS_CHARACTER,
	GF.TAB_MPLUS_CARPOOL,
	GF.TAB_MPLUS_DUNGEON,
	GF.TAB_RAID_SEEK, GF.TAB_RAID_SQUARE, GF.TAB_STARRED_LEADERS,
}

local WORKSPACE_IDS = {
	GF.WORKSPACE_RAID,
	GF.WORKSPACE_MEETING_STONE,
	GF.WORKSPACE_MYTHIC_PLUS,
}

local function copySequence(source)
	local copy = {}
	for index, value in ipairs(source) do
		copy[index] = value
	end
	return copy
end

local function makeTransition(previousWorkspaceID, previousTabID, workspaceID, tabID)
	local workspaceChanged = previousWorkspaceID ~= workspaceID
	local tabChanged = previousTabID ~= tabID
	return {
		previousWorkspaceID = previousWorkspaceID,
		previousTabID = previousTabID,
		workspaceID = workspaceID,
		tabID = tabID,
		workspaceChanged = workspaceChanged,
		tabChanged = tabChanged,
		changed = workspaceChanged or tabChanged,
	}
end

function Router:NormalizeWorkspaceID(workspaceID)
	local policy = GF.LFGWorkspacePolicy
	if policy and policy.NormalizeWorkspaceID then
		return policy:NormalizeWorkspaceID(workspaceID)
	end
	if workspaceID == GF.WORKSPACE_RAID then
		return GF.WORKSPACE_RAID
	end
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS then
		return GF.WORKSPACE_MYTHIC_PLUS
	end
	return GF.WORKSPACE_MEETING_STONE
end

function Router:GetAllTabIDs()
	return copySequence(ALL_TAB_IDS)
end

function Router:NormalizeTabID(workspaceID, tabID)
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS and tabID == GF.TAB_MPLUS_GROUP then
		return GF.TAB_MPLUS_CARPOOL
	end
	return tabID
end

function Router:GetSeekingNavigationState()
	local service = GF.RaidSeekingService
	if service and service.GetSeekingNavigationState then
		local visible, recruiting = service:GetSeekingNavigationState()
		return visible or self:IsSeekingHistory(), recruiting
	end
	return true, false
end

function Router:IsSeekingHistory()
	local service, chat = GF.RaidSeekingService, GF.RaidSeekingChatService
	if not (self._seekingHistoryKey and service and service.GetSeekingNavigationState and chat and chat.Get) then return false end
	if service:GetSeekingNavigationState() then return false end
	local c = chat:Get(self._seekingHistoryKey)
	return c ~= nil and c.context == "seeking" and not c.closed and not c.hidden
end

function Router:PrepareConversationRoute(key)
	local chat = GF.RaidSeekingChatService
	local c = chat and chat:Get(key)
	if not c or c.closed or c.hidden or (c.context ~= "seeking" and c.context ~= "board") then return nil end
	-- An explicit click may temporarily expose read-only seeking history while
	-- recruitment/raid membership hides the publication task. Never grants send.
	self._seekingHistoryKey = c.context == "seeking" and key or nil
	return { workspaceID = GF.WORKSPACE_RAID,
		tabID = c.context == "board" and GF.TAB_RAID_SQUARE or GF.TAB_RAID_SEEK }
end

function Router:GetUnavailableSeekingFallback(workspaceID, tabID)
	if workspaceID ~= GF.WORKSPACE_RAID or tabID ~= GF.TAB_RAID_SEEK then return nil end
	local visible, recruiting = self:GetSeekingNavigationState()
	if not visible then return recruiting and GF.TAB_CREATE or GF.TAB_RAID_SQUARE end
end

function Router:GetVisibleTabOrder(workspaceID)
	workspaceID = self:NormalizeWorkspaceID(
		workspaceID or self._workspaceID)
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS then
		return copySequence(MYTHIC_PLUS_TAB_ORDER)
	end
	if workspaceID == GF.WORKSPACE_RAID then
		local order, visible = {}, self:GetSeekingNavigationState()
		for _, tabID in ipairs(RAID_TAB_ORDER) do
			if tabID ~= GF.TAB_RAID_SEEK or visible then order[#order + 1] = tabID end
		end
		return order
	end
	return copySequence(MEETING_STONE_TAB_ORDER)
end

function Router:GetDefaultTabID(workspaceID)
	return GF.TAB_BROWSE
end

function Router:IsTabPlaceholder(tabID, workspaceID)
	return false
end

function Router:IsTabVisible(tabID, workspaceID)
	return self:IsTabPlaceholder(tabID, workspaceID) or self:IsTabAvailable(tabID, workspaceID)
end

function Router:IsTabAvailable(tabID, workspaceID)
	if self:IsTabPlaceholder(tabID, workspaceID) then return false end
	if tabID == nil then
		return false
	end
	local found = false
	for _, candidateID in ipairs(self:GetVisibleTabOrder(workspaceID)) do
		if candidateID == tabID then
			found = true
			break
		end
	end
	if not found then
		return false
	end
	if tabID == GF.TAB_BLOCKLIST then
		return self._blocklistTabAvailable ~= false
	end
	return true
end

function Router:ResolveTabID(workspaceID, requestedTabID, opts)
	opts = opts or {}
	workspaceID = self:NormalizeWorkspaceID(workspaceID)
	local candidates = { requestedTabID }
	if opts.keepCurrent == true then
		candidates[#candidates + 1] = opts.currentTabID or self._tabID
	elseif opts.useMemory ~= false then
		local memory = self._tabByWorkspace
		candidates[#candidates + 1] = memory and memory[workspaceID] or nil
	end
	candidates[#candidates + 1] = self:GetDefaultTabID(workspaceID)
	for _, tabID in ipairs(candidates) do
		tabID = self:NormalizeTabID(workspaceID, tabID)
		tabID = self:GetUnavailableSeekingFallback(workspaceID, tabID) or tabID
		if self:IsTabAvailable(tabID, workspaceID) then
			return tabID
		end
	end
	for _, tabID in ipairs(self:GetVisibleTabOrder(workspaceID)) do
		if self:IsTabAvailable(tabID, workspaceID) then
			return tabID
		end
	end
	return nil
end

function Router:Init(opts)
	opts = opts or {}
	if self._initialized == true then
		return self._workspaceID, self._tabID
	end
	self._tabByWorkspace = {
		[GF.WORKSPACE_RAID] = GF.TAB_BROWSE,
		[GF.WORKSPACE_MEETING_STONE] = GF.TAB_BROWSE,
		[GF.WORKSPACE_MYTHIC_PLUS] = GF.TAB_BROWSE,
	}
	self._blocklistTabAvailable = true
	local workspaceID = self:NormalizeWorkspaceID(
		opts.workspaceID or GF.WORKSPACE_DEFAULT)
	local tabID = self:ResolveTabID(workspaceID, opts.tabID)
	self._workspaceID = workspaceID
	self._tabID = tabID
	self._tabByWorkspace[workspaceID] = tabID
	self._initialized = true
	return workspaceID, tabID
end

function Router:IsInitialized()
	return self._initialized == true
end

function Router:GetWorkspaceID()
	if self._initialized ~= true then
		self:Init()
	end
	return self._workspaceID or GF.WORKSPACE_MEETING_STONE
end

function Router:GetCurrentTabID()
	if self._initialized ~= true then
		self:Init()
	end
	return self._tabID or GF.TAB_BROWSE
end

function Router:GetRememberedTabID(workspaceID)
	if self._initialized ~= true then
		self:Init()
	end
	workspaceID = self:NormalizeWorkspaceID(workspaceID)
	return self._tabByWorkspace[workspaceID]
end

function Router:SetWorkspace(workspaceID, opts)
	opts = opts or {}
	if self._initialized ~= true then
		self:Init({ workspaceID = workspaceID })
	end
	local previousWorkspaceID = self._workspaceID
	local previousTabID = self._tabID
	workspaceID = self:NormalizeWorkspaceID(workspaceID)
	if previousWorkspaceID ~= nil and previousTabID ~= nil then
		self._tabByWorkspace[previousWorkspaceID] = previousTabID
	end
	-- Workspace switches follow the user's current task when the destination
	-- exposes the same semantic tab. Workspace-exclusive Mythic+ pages have no
	-- Meeting Stone counterpart and therefore fall back to Browse. Deliberately
	-- ignore the destination's older session memory so switching back does not
	-- resurrect a page the user already left through an unmatched transition.
	local requestedTabID = opts.targetTabID
	if requestedTabID == nil then
		requestedTabID = previousTabID
	end
	if workspaceID ~= GF.WORKSPACE_RAID or requestedTabID ~= GF.TAB_RAID_SEEK then self._seekingHistoryKey = nil end
	local tabID = self:ResolveTabID(workspaceID, requestedTabID, {
		useMemory = false,
	})
	self._workspaceID = workspaceID
	self._tabID = tabID
	self._tabByWorkspace[workspaceID] = tabID
	return tabID, makeTransition(
		previousWorkspaceID,
		previousTabID,
		workspaceID,
		tabID
	)
end

function Router:SelectTab(tabID)
	if self._initialized ~= true then
		self:Init()
	end
	local workspaceID = self._workspaceID
	tabID = self:NormalizeTabID(workspaceID, tabID)
	tabID = self:GetUnavailableSeekingFallback(workspaceID, tabID) or tabID
	if not self:IsTabAvailable(tabID, workspaceID) then
		return nil
	end
	if tabID ~= GF.TAB_RAID_SEEK then self._seekingHistoryKey = nil end
	local previousTabID = self._tabID
	self._tabID = tabID
	self._tabByWorkspace[workspaceID] = tabID
	return makeTransition(
		workspaceID,
		previousTabID,
		workspaceID,
		tabID
	)
end

local function fallbackForUnavailableTab(self, unavailableTabID, preferredTabID)
	if self._initialized ~= true then
		self:Init()
	end
	for _, workspaceID in ipairs(WORKSPACE_IDS) do
		if self._tabByWorkspace[workspaceID] == unavailableTabID then
			local fallback = preferredTabID
			if not self:IsTabAvailable(fallback, workspaceID) then
				fallback = self:ResolveTabID(workspaceID)
			end
			self._tabByWorkspace[workspaceID] = fallback
		end
	end
	if self._tabID ~= unavailableTabID then
		return nil
	end
	local previousWorkspaceID = self._workspaceID
	local previousTabID = self._tabID
	local tabID = self._tabByWorkspace[previousWorkspaceID]
	if not self:IsTabAvailable(tabID, previousWorkspaceID) then
		tabID = self:ResolveTabID(previousWorkspaceID)
	end
	self._tabID = tabID
	self._tabByWorkspace[previousWorkspaceID] = tabID
	return makeTransition(
		previousWorkspaceID,
		previousTabID,
		previousWorkspaceID,
		tabID
	)
end

function Router:SetBlocklistTabAvailable(available)
	if self._initialized ~= true then
		self:Init()
	end
	self._blocklistTabAvailable = available ~= false
	if self._blocklistTabAvailable then
		return nil
	end
	return fallbackForUnavailableTab(self, GF.TAB_BLOCKLIST)
end

function Router:RefreshSeekingAvailability()
	local visible, recruiting = self:GetSeekingNavigationState()
	local changed = self._seekingTabVisible ~= visible
	self._seekingTabVisible = visible
	local transition
	if not visible and self._initialized == true then
		transition = fallbackForUnavailableTab(self, GF.TAB_RAID_SEEK,
			recruiting and GF.TAB_CREATE or GF.TAB_RAID_SQUARE)
	end
	return transition, changed
end

function Router:ResolveInitialOpenRoute(route)
	local workspaceID = type(route) == "table" and route.workspaceID or nil
	if workspaceID == nil then
		local database = GF.GetDB and GF.GetDB()
		workspaceID = database and database.workspaceMode or GF.WORKSPACE_DEFAULT
	end
	return {
		workspaceID = self:NormalizeWorkspaceID(workspaceID),
		tabID = type(route) == "table" and route.tabID or nil,
	}
end

function Router:CommitInitialOpenRoute(route)
	local resolved = self:ResolveInitialOpenRoute(route)
	if self._initialized ~= true then
		self:Init(resolved)
	else
		-- Startup-only readers may initialize the router before the window exists.
		-- An explicit cold-open route remains authoritative over that default.
		self:SetWorkspace(resolved.workspaceID, {
			targetTabID = resolved.tabID,
		})
	end
	return {
		workspaceID = self._workspaceID,
		tabID = self._tabID,
	}
end

function Router:IsRouteActive(route, workspaceID, tabID)
	route = type(route) == "table" and route or {}
	workspaceID = workspaceID or self:GetWorkspaceID()
	tabID = tabID or self:GetCurrentTabID()
	if route.workspaceID ~= nil
		and self:NormalizeWorkspaceID(workspaceID)
			~= self:NormalizeWorkspaceID(route.workspaceID)
	then
		return false
	end
	if route.tabID ~= nil then
		local target = self:NormalizeTabID(workspaceID, route.tabID)
		-- Match the same fallback used when opening an unavailable seeking page,
		-- so the second key press can close the page reached by the first.
		target = self:GetUnavailableSeekingFallback(workspaceID, target) or target
		if tabID ~= target then return false end
	end
	return true
end

function Router:ApplyOpenRoute(route, opts, workspaceBar, tabBar)
	if type(route) ~= "table" then
		return false, false
	end
	opts = opts or {}
	if self._initialized ~= true then
		self:Init()
	end

	local transition
	if route.workspaceID ~= nil then
		local _, committed = self:SetWorkspace(route.workspaceID, {
			targetTabID = route.tabID,
		})
		transition = committed
	elseif route.tabID ~= nil then
		transition = self:SelectTab(route.tabID)
	else
		return false, false
	end
	if transition == nil then
		return false, false
	end

	local projected = false
	if transition.workspaceChanged then
		if workspaceBar and workspaceBar.Select then
			projected = workspaceBar:Select(transition.workspaceID, {
				silent = opts.silent == true,
				targetTabID = transition.tabID,
				_routerTransition = transition,
			}) == true
		end
	elseif route.tabID ~= nil and transition.tabChanged
		and tabBar and tabBar.Select
	then
		tabBar:Select(transition.tabID, {
			skipDeferredLayout = opts.silent == true,
			_routerTransition = transition,
		})
		projected = true
	end
	return transition.changed, projected
end
