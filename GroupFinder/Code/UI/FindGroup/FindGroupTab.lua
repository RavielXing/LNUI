local _, GF = ...

GF.FindGroupTab = {}
local FGT = GF.FindGroupTab

local function panel()
	return GF.BrowsePanel
end

local function callPanel(method, ...)
	local bp = panel()
	if bp and bp[method] then
		return bp[method](bp, ...)
	end
	return nil
end

function FGT:Init(parent)
	callPanel("Init", parent)
	callPanel("WireRowClicks")
end

function FGT:GetPanel()
	return panel()
end

function FGT:GetSelection()
	local bp = panel()
	return bp and bp.selection
end

function FGT:GetBrowseSearchState()
	local bp = panel()
	if not bp then
		return false, false
	end
	local hasKeyword = bp.committedSearchQuery and bp.committedSearchQuery ~= ""
	local ownsSearch = bp.gfOwnsSearch or bp.activeSearchKey
	return hasKeyword, ownsSearch
end

function FGT:CancelDeferredWork()
	callPanel("CancelRelayoutDebounce")
	callPanel("CancelRowUpdateTimer")
end

function FGT:CancelRelayoutDebounce()
	callPanel("CancelRelayoutDebounce")
end

function FGT:CancelRowUpdateTimer()
	callPanel("CancelRowUpdateTimer")
end

function FGT:SetFrameResizing(active)
	local bp = panel()
	if bp then
		bp._frameResizing = active == true
	end
end

function FGT:OnBrowseShown()
	callPanel("OnBrowseShown")
end

function FGT:OnFrameHidden()
	callPanel("OnFrameHidden")
end

function FGT:Show()
	callPanel("Show")
end

function FGT:Hide()
	callPanel("OnBrowseHidden")
	callPanel("Hide")
end

function FGT:SetSelection(node, opts)
	callPanel("SetSelection", node, opts)
end

function FGT:SetWorkspaceContext(context)
	return callPanel("SetWorkspaceContext", context)
end

function FGT:GetWorkspaceContext()
	return callPanel("GetWorkspaceContext")
end

function FGT:IsSearchableSelection(node)
	if GF.FindGroup and GF.FindGroup.IsSearchableSelection then
		return GF.FindGroup:IsSearchableSelection(node)
	end
	return callPanel("IsSearchableSelection", node)
end

function FGT:DoSearch(opts)
	return callPanel("DoSearch", opts)
end

function FGT:FindQuestGroup(questID, requestState)
	local bridge = GF.QuestSearch
	if not (bridge and bridge.Resolve) then
		return false
	end
	local resolved = bridge:Resolve(questID)
	if not resolved then
		return false
	end
	local mainFrame = GF.MainFrame
	if not (mainFrame and mainFrame.OpenRoute) then
		return false
	end
	if GF.Availability and GF.Availability.GetBlockMessage
		and GF.Availability:GetBlockMessage()
	then
		return false
	end
	local module = GF.WorkspaceUIModule
	if module and module:EnsureLoaded() ~= true then return false end
	if type(requestState) == "table" then
		requestState.tookOwnership = true
	end
	local opened, routeReady = mainFrame:OpenRoute({
		workspaceID = GF.WORKSPACE_MEETING_STONE,
		tabID = GF.TAB_BROWSE,
	}, {
		flushDeferredNavigation = true,
	})
	if opened ~= true or routeReady ~= true
		or not (mainFrame.frame and mainFrame.frame:IsShown())
	then
		return true, false
	end
	if mainFrame.GetCurrentWorkspaceID
		and mainFrame:GetCurrentWorkspaceID() ~= GF.WORKSPACE_MEETING_STONE
	then
		return true, false
	end
	if mainFrame.GetCurrentTabID and mainFrame:GetCurrentTabID() ~= GF.TAB_BROWSE then
		return true, false
	end
	resolved = bridge:Resolve(questID)
	if not resolved then
		return true, false
	end

	local selectedNode = resolved.baseNode
	local path
	if selectedNode and GF.NavTree and GF.NavTree.FindNodePathByKey then
		local foundNode, foundPath = GF.NavTree:FindNodePathByKey(selectedNode.key)
		if foundNode then
			selectedNode, path = foundNode, foundPath
		end
	end
	if selectedNode and GF.NavTree and GF.NavTree.SetSelectedSilently then
		GF.NavTree:SetSelectedSilently(selectedNode, path)
	end
	if not (mainFrame.OnSelectionChanged
		and mainFrame:OnSelectionChanged(resolved.selection, {
			suppressCreateDrawer = true,
			externalQuestSearch = true,
		}))
	then
		return true, false
	end
	callPanel("ClearCommittedSearchQuery")
	if GF.SubtitleBar and GF.SubtitleBar.ClearSearchText then
		GF.SubtitleBar:ClearSearchText()
	end
	local started = callPanel("DoSearch", {
		source = "questTrackerGreenEye",
	}) == true
	return true, started
end

function FGT:FindRaidLeader(contactKey)
	local lookup = GF.RaidLeaderLookup
	local selection, reason = lookup:Resolve(contactKey)
	if not selection then return false, reason end
	local main = GF.MainFrame
	local opened, ready = main:OpenRoute({ workspaceID = GF.WORKSPACE_RAID, tabID = GF.TAB_BROWSE },
		{ flushDeferredNavigation = true })
	if opened ~= true or ready ~= true or not main.frame:IsShown()
		or main:GetCurrentWorkspaceID() ~= GF.WORKSPACE_RAID or main:GetCurrentTabID() ~= GF.TAB_BROWSE then
		return false, "search_busy"
	end
	selection, reason = lookup:Resolve(contactKey)
	if not selection then return false, reason end
	local base = selection._gfRaidLeaderLookup.baseNode
	if GF.NavTree and GF.NavTree.SetSelectedSilently then GF.NavTree:SetSelectedSilently(base) end
	-- Only the browse surface owns the temporary search key. Navigation memory,
	-- saved filters and the create surface keep the ordinary catalog node.
	if not main:OnSelectionChanged(base, { suppressCreateDrawer = true }) then return false, "search_busy" end
	self:ResetBrowsePage()
	self:SetSelection(selection)
	self:ClearCommittedSearchQuery()
	if GF.SubtitleBar then GF.SubtitleBar:ClearSearchText() end
	if GF.FilterPanel then GF.FilterPanel:Hide() end
	self:DoSearch({ source = "raidLeaderLookup" })
	-- A cooldown leaves the lookup open with its explicit retry action.
	return true
end

function FGT:EndRaidLeaderLookup(searchAll)
	if not callPanel("EndRaidLeaderLookup") then return false end
	if searchAll then self:DoSearch({ source = "raidLeaderShowAll" }) end
	return true
end

function FGT:ReturnToRaidLeaderChat()
	local target = GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget(self:GetSelection())
	if not target then return false end
	self:EndRaidLeaderLookup(false)
	local opened, ready = GF.MainFrame:OpenRoute({ workspaceID = GF.WORKSPACE_RAID, tabID = GF.TAB_RAID_SEEK },
		{ flushDeferredNavigation = true })
	if opened ~= true or ready ~= true then return false end
	local chat = GF.RaidSeekingPanel and GF.RaidSeekingPanel.chat
	if chat then chat:Select(target.contactKey); chat:Refresh(true) end
	return true
end

function FGT:DoManualRefresh()
	local bp = panel()
	if not (bp and bp.DoSearch) then
		return
	end
	if bp.CanManualRefresh and bp:CanManualRefresh() then
		bp:DoSearch({
			manualRefresh = true,
			source = "manualRefreshButton",
		})
	else
		bp:DoSearch()
	end
end

function FGT:ResetBrowsePage()
	callPanel("ResetBrowsePage")
end

function FGT:ClearCommittedSearchQuery()
	callPanel("ClearCommittedSearchQuery")
end

function FGT:RefreshResults(opts)
	callPanel("RefreshResults", opts)
end

function FGT:ApplyClientFilters(options)
	callPanel("ApplyClientFilters", options)
end

function FGT:ApplyExpiredGroupMode(mode)
	return callPanel("ApplyExpiredGroupMode", mode)
end

function FGT:RetireExpiredResult(resultID)
	return callPanel("RetireExpiredResult", resultID)
end

function FGT:BeginExpiredResultRetirement(resultID, info, options)
	return callPanel("BeginExpiredResultRetirement", resultID, info, options)
end

function FGT:SoftInvalidateResult(resultID, info)
	return callPanel("SoftInvalidateResult", resultID, info)
end

function FGT:ClearAutomaticResultOrderLocks()
	callPanel("ClearAutomaticResultOrderLocks")
end

function FGT:RefreshLoadedMemberIcons()
	callPanel("RefreshLoadedMemberIcons")
end

function FGT:RequestRefreshResults(opts)
	callPanel("RequestRefreshResults", opts)
end

function FGT:Relayout(opts)
	callPanel("Relayout", opts)
end

function FGT:RelayoutRows()
	callPanel("RelayoutRows")
end

function FGT:RelayoutVisibleRows()
	return callPanel("RelayoutVisibleRows")
end

function FGT:UpdateScrollWidth()
	callPanel("UpdateScrollWidth")
end

function FGT:GetLayoutWidth()
	local bp = panel()
	if bp and bp.scrollList then
		return bp.scrollList:GetLayoutWidth()
	end
	return 1
end

function FGT:RefreshLayoutIfReady(attempt)
	callPanel("RefreshLayoutIfReady", attempt)
end

function FGT:SuppressRelayout(seconds)
	local bp = panel()
	if bp then
		bp._relayoutSuppressUntil = GetTime() + (seconds or 0.25)
	end
end

function FGT:UpdateTitle()
	callPanel("UpdateTitle")
end

function FGT:UpdateSearchHint()
	callPanel("UpdateSearchHint")
end

function FGT:UpdateBlocked()
	callPanel("UpdateBlocked")
end

function FGT:SetSelectedRow(row)
	callPanel("SetSelectedRow", row)
end

function FGT:ForEachVisibleRow(fn)
	callPanel("ForEachVisibleRow", fn)
end

function FGT:UpdateRowByResultID(resultID, suppliedInfo)
	return callPanel("UpdateRowByResultID", resultID, suppliedInfo)
end

function FGT:RevealCensoredResultFromRow(row)
	return callPanel("RevealCensoredResultFromRow", row)
end

function FGT:DropFrozenResult(resultID)
	return callPanel("DropFrozenResult", resultID)
end

function FGT:RefreshList(opts)
	callPanel("RefreshList", opts)
end

function FGT:RequestRaidProgressRefresh(delay)
	callPanel("RequestRaidProgressRefresh", delay)
end

function FGT:RequestCurrentGroupDepartureRefresh(delay)
	callPanel("RequestCurrentGroupDepartureRefresh", delay)
end

function FGT:HasBrowseList()
	return callPanel("HasBrowseList")
end

function FGT:HasRefreshableBrowseSource()
	return callPanel("HasRefreshableBrowseSource")
end

function FGT:GetDisplayedResultCount()
	return callPanel("GetDisplayedResultCount") or 0
end

function FGT:GetSearchCooldownRemaining()
	return callPanel("GetSearchCooldownRemaining") or 0
end

function FGT:CanStartSelectionSearch(selection, options)
	return callPanel("CanStartSelectionSearch", selection, options)
end

function FGT:NotifySelectionSearchBlocked(reason)
	callPanel("NotifySelectionSearchBlocked", reason)
end

function FGT:OnSearchResultUpdated(resultID)
	callPanel("OnSearchResultUpdated", resultID)
end

function FGT:OnSearchResultsUpdated()
	callPanel("OnSearchResultsUpdated")
end

function FGT:OnPlayerSpecializationChanged()
	callPanel("OnPlayerSpecializationChanged")
end

function FGT:OnApplicationStatusUpdated(searchResultID, newStatus)
	callPanel("OnApplicationStatusUpdated", searchResultID, newStatus)
end

function FGT:RemoveHiddenByBlocklist()
	callPanel("RemoveHiddenByBlocklist")
end

function FGT:RetireHiddenByBlocklist(preferredResultID)
	return callPanel("RetireHiddenByBlocklist", preferredResultID)
end

function FGT:SignUp()
	callPanel("SignUp")
end

local function activeSearchContextMatches(bp)
	local context = bp and bp.GetActiveSearchContext and bp:GetActiveSearchContext()
	if not context then
		return true
	end
	return GF.Search and GF.Search.MatchesContext
		and GF.Search:MatchesContext(context) or false
end

local function callPanel(bp, methodName, ...)
	local method = bp and bp[methodName]
	if type(method) == "function" then
		return method(bp, ...)
	end
end

local function updateAfterAbandonedSearch(bp)
	local search = GF.Search
	local consume = search and search.ConsumeAbandonedEvent
	if type(consume) ~= "function" or consume(search) ~= true then
		return false
	end
	callPanel(bp, "ScheduleSearchCooldownUI")
	callPanel(bp, "UpdateSearchHint")
	return true
end

local function setResultListening(enabled)
	if type(GF.SetLfgUpdateListening) == "function" then
		GF.SetLfgUpdateListening(enabled == true)
	end
end

local function hasStaleResultToken(bp)
	return bp and bp._resultToken ~= nil
		and bp._searchToken ~= bp._resultToken
end

function FGT:OnSearchResults()
	local bp = panel()
	if updateAfterAbandonedSearch(bp) then
		return
	end
	if not activeSearchContextMatches(bp) then
		return
	end
	local search = GF.Search
	local receive = search and search.OnSearchResults
	local searchState = receive and receive(search)
	if searchState == "failed" then
		self:OnSearchFailed()
		return
	end
	local diagnostics = GF.SearchMemoryDiagnostics
	if diagnostics and diagnostics.RecordStage then
		diagnostics:RecordStage("event")
	end
	GF.searching = false
	if not bp then
		return
	end
	if bp.awaitingGFSearch then
		if hasStaleResultToken(bp) then
			return
		end
		bp.awaitingGFSearch = false
		bp.gfOwnsSearch = true
		bp._searchFailed = false
		callPanel(bp, "CancelSearchTimeout")
		setResultListening(true)
		callPanel(bp, "OnSearchCommitted")
		callPanel(bp, "RefreshResults", {
			commitManualDeclineRefresh = true,
		})
	elseif bp.gfOwnsSearch and bp.activeSearchKey then
		setResultListening(true)
		local refresh = bp.RequestRefreshResults or bp.RefreshResults
		if refresh then
			refresh(bp)
		end
	else
		bp.gfOwnsSearch = false
		setResultListening(false)
	end
end

function FGT:OnSearchFailed()
	local bp = panel()
	if updateAfterAbandonedSearch(bp) then
		return
	end
	if not activeSearchContextMatches(bp) then
		return
	end
	local search = GF.Search
	if search and search.OnSearchFailed then
		search.OnSearchFailed(search)
	end
	GF.searching = false
	if not bp then
		return
	end
	if bp.awaitingGFSearch and hasStaleResultToken(bp) then
		return
	end
	local ours = bp.awaitingGFSearch
	bp.awaitingGFSearch = false
	callPanel(bp, "DiscardManualDeclineRefresh")
	if not ours then
		bp.gfOwnsSearch = false
		setResultListening(false)
		return
	end
	bp.gfOwnsSearch = false
	callPanel(bp, "CancelSearchTimeout")
	callPanel(bp, "EndSearchUI")
	setResultListening(false)
	bp._searchFailed = true
	bp._resolvedResultToken = nil
	callPanel(bp, "UpdateSearchHint")
	callPanel(bp, "ScheduleSearchCooldownUI")
end
