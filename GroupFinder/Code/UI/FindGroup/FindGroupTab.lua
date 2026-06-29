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
	callPanel("Hide")
end

function FGT:SetSelection(node, opts)
	callPanel("SetSelection", node, opts)
end

function FGT:IsSearchableSelection(node)
	if GF.FindGroup and GF.FindGroup.IsSearchableSelection then
		return GF.FindGroup:IsSearchableSelection(node)
	end
	return callPanel("IsSearchableSelection", node)
end

function FGT:DoSearch(opts)
	callPanel("DoSearch", opts)
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

function FGT:ApplyClientFilters()
	callPanel("ApplyClientFilters")
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

function FGT:RelayoutWhenReady(attempt)
	callPanel("RelayoutWhenReady", attempt)
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

function FGT:UpdateRowByResultID(resultID)
	callPanel("UpdateRowByResultID", resultID)
end

function FGT:DropFrozenResult(resultID)
	return callPanel("DropFrozenResult", resultID)
end

function FGT:RefreshList(opts)
	callPanel("RefreshList", opts)
end

function FGT:HasBrowseList()
	return callPanel("HasBrowseList")
end

function FGT:GetDisplayedResultCount()
	return callPanel("GetDisplayedResultCount") or 0
end

function FGT:GetSearchCooldownRemaining()
	return callPanel("GetSearchCooldownRemaining") or 0
end

function FGT:OnSearchResultUpdated(resultID)
	callPanel("OnSearchResultUpdated", resultID)
end

function FGT:OnSearchResultsUpdated()
	callPanel("OnSearchResultsUpdated")
end

function FGT:OnApplicationStatusUpdated(searchResultID, newStatus)
	callPanel("OnApplicationStatusUpdated", searchResultID, newStatus)
end

function FGT:RemoveHiddenByBlocklist()
	callPanel("RemoveHiddenByBlocklist")
end

function FGT:SignUp()
	callPanel("SignUp")
end

function FGT:OnSearchResults()
	local bp = panel()
	local searchState
	if GF.Search and GF.Search.OnSearchResults then
		searchState = GF.Search:OnSearchResults()
	end
	if searchState == "continue" then
		GF.searching = true
		if bp then
			bp.awaitingGFSearch = true
			if bp.ScheduleSearchTimeout then
				bp:ScheduleSearchTimeout(bp._resultToken or bp._searchToken)
			end
		end
		return
	elseif searchState == "failed" then
		self:OnSearchFailed()
		return
	end
	GF.searching = false
	if not bp then
		return
	end
	if bp.awaitingGFSearch then
		if bp._resultToken and bp._searchToken ~= bp._resultToken then
			return
		end
		bp.awaitingGFSearch = false
		bp.gfOwnsSearch = true
		bp._searchFailed = false
		if bp.CancelSearchTimeout then
			bp:CancelSearchTimeout()
		end
		if GF.SetLfgUpdateListening then
			GF.SetLfgUpdateListening(true)
		end
		if bp.OnSearchCommitted then
			bp:OnSearchCommitted()
		end
		if bp.RefreshResults then
			bp:RefreshResults()
		end
	elseif bp.gfOwnsSearch and bp.activeSearchKey then
		if GF.SetLfgUpdateListening then
			GF.SetLfgUpdateListening(true)
		end
		if bp.RequestRefreshResults then
			bp:RequestRefreshResults()
		elseif bp.RefreshResults then
			bp:RefreshResults()
		end
	else
		bp.gfOwnsSearch = false
		if GF.SetLfgUpdateListening then
			GF.SetLfgUpdateListening(false)
		end
	end
end

function FGT:OnSearchFailed()
	if GF.Search and GF.Search.OnSearchFailed then
		GF.Search:OnSearchFailed()
	end
	GF.searching = false
	local bp = panel()
	if not bp then
		return
	end
	if bp.awaitingGFSearch and bp._resultToken and bp._searchToken ~= bp._resultToken then
		return
	end
	local ours = bp.awaitingGFSearch
	bp.awaitingGFSearch = false
	if not ours then
		bp.gfOwnsSearch = false
		if GF.SetLfgUpdateListening then
			GF.SetLfgUpdateListening(false)
		end
		return
	end
	bp.gfOwnsSearch = false
	if bp.CancelSearchTimeout then
		bp:CancelSearchTimeout()
	end
	if bp.EndSearchUI then
		bp:EndSearchUI()
	end
	if GF.SetLfgUpdateListening then
		GF.SetLfgUpdateListening(false)
	end
	bp._searchFailed = true
	if bp.ScheduleSearchCooldownUI then
		bp:ScheduleSearchCooldownUI()
	end
end
