local _, GF = ...

GF.BrowsePanel = {}
local BP = GF.BrowsePanel
local BSL = GF.BrowseScrollList

-- [BrowsePanel] kstring 探测

local KSTRING_BAD_TOKEN = "|Kr0|k"
local badLfgNameDisplay
local badLfgNameProbeFrame

local function getLoadingCycleSeconds()
	return ((GF.BROWSE_LOADING_STEP_SECONDS or 0.28) * (GF.BROWSE_LOADING_ICON_COUNT or 3))
		+ (GF.BROWSE_LOADING_HOLD_SECONDS or 0.4)
		+ (GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45)
end

local function getLoadingIconAlpha(elapsed, iconIndex)
	local stepSeconds = GF.BROWSE_LOADING_STEP_SECONDS or 0.28
	local fadeInSeconds = GF.BROWSE_LOADING_FADE_IN_SECONDS or 0.16
	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local holdSeconds = GF.BROWSE_LOADING_HOLD_SECONDS or 0.4
	local fadeOutSeconds = GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45
	local appearAt = (iconIndex - 1) * stepSeconds
	if elapsed < appearAt then
		return 0
	end
	local fadeInEnd = appearAt + fadeInSeconds
	if elapsed < fadeInEnd then
		return math.max(0, math.min(1, (elapsed - appearAt) / fadeInSeconds))
	end
	local fadeOutStart = (stepSeconds * iconCount) + holdSeconds
	if elapsed < fadeOutStart then
		return 1
	end
	local fadeOutEnd = fadeOutStart + fadeOutSeconds
	if elapsed < fadeOutEnd then
		return math.max(0, math.min(1, 1 - ((elapsed - fadeOutStart) / fadeOutSeconds)))
	end
	return 0
end

local function refreshLoadingAnimation(animation)
	if not (animation and animation.icons) then
		return
	end
	local elapsed = animation.elapsed or 0
	for index, icon in ipairs(animation.icons) do
		local alpha = getLoadingIconAlpha(elapsed, index)
		icon:SetAlpha(alpha)
		if alpha > 0.02 then
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local function getBadLfgNameDisplay()
	if badLfgNameDisplay ~= nil then
		return badLfgNameDisplay
	end
	if not badLfgNameProbeFrame then
		badLfgNameProbeFrame = CreateFrame("Frame")
		badLfgNameProbeFrame:Hide()
		badLfgNameProbeFrame.text = GF.UI.CreateFontString(badLfgNameProbeFrame, "ARTWORK", "GameFontNormal")
	end
	badLfgNameProbeFrame.text:SetText(KSTRING_BAD_TOKEN)
	local painted = badLfgNameProbeFrame.text:GetText()
	if type(painted) == "string" and painted ~= "" and painted ~= KSTRING_BAD_TOKEN then
		badLfgNameDisplay = painted
	else
		badLfgNameDisplay = false
	end
	return badLfgNameDisplay
end

local function isBadLfgName(text)
	if text == nil then
		return false
	end
	if GF.Result and GF.Result.IsUnreadableLfgText then
		if not GF.Result:IsUnreadableLfgText(text) then
			return false
		end
		if issecretvalue and issecretvalue(text) then
			return true
		end
		text = tostring(text)
		if strtrim then
			text = strtrim(text)
		end
		return text ~= ""
	end
	if issecretvalue and issecretvalue(text) then
		return true
	end
	if text == "" then
		return false
	end
	local bad = getBadLfgNameDisplay()
	return bad and text == bad
end

local function paintedLfgName(text)
	if not text or text == "" then
		return nil
	end
	getBadLfgNameDisplay()
	if not badLfgNameProbeFrame or not badLfgNameProbeFrame.text then
		return nil
	end
	badLfgNameProbeFrame.text:SetText(text)
	return badLfgNameProbeFrame.text:GetText()
end

function BP:CancelRefreshTimer()
	if self._refreshDebounce and self._refreshDebounce.Cancel then
		self._refreshDebounce:Cancel()
	end
	self._refreshDebounce = nil
	if self._rowUpdateTimer and self._rowUpdateTimer.Cancel then
		self._rowUpdateTimer:Cancel()
	end
	self._rowUpdateTimer = nil
	self._pendingRowUpdates = nil
	self._pendingFullRefresh = nil
	self._refreshToken = (self._refreshToken or 0) + 1
end

function BP:CancelRowUpdateTimer()
	if self._rowUpdateTimer and self._rowUpdateTimer.Cancel then
		self._rowUpdateTimer:Cancel()
	end
	self._rowUpdateTimer = nil
end

function BP:ForEachVisibleRow(fn)
	if self.scrollList and fn then
		self.scrollList:ForEachFrame(fn)
	end
end

local LIST_ORDER_SIG_SEP = "\31"

local function buildListOrderSig(ids)
	if not ids or #ids == 0 then
		return ""
	end
	return table.concat(ids, LIST_ORDER_SIG_SEP)
end

function BP:RepaintVisibleRows()
	self:ForEachVisibleRow(function(row)
		if not row or not row.resultID or not GF.ListRow or not GF.ListRow.RepaintRowState then
			return
		end
		local index = GF.Result:GetIndexForResultID(row.resultID)
		if not index then
			return
		end
		row.resultIndex = index
		local entry = GF.Result:GetEntry(index)
		if entry then
			GF.ListRow:RepaintRowState(row, entry, row.categoryID)
		end
	end)
end

function BP:FindRowByResultID(resultID)
	if not resultID or not self.scrollList then
		return nil, nil
	end
	local row = self.scrollList:FindFrameByKey(resultID)
	if not row then
		return nil, nil
	end
	return row, row.resultIndex
end

function BP:OnSearchResultUpdated(resultID)
	if not resultID or not self.gfOwnsSearch or not self.activeSearchKey then
		return
	end
	if self.activeSearchKey ~= self:GetSelectionKey() then
		return
	end
	if not GF.Result:IsFrozenResult(resultID) then
		return
	end
	self._pendingRowUpdates = self._pendingRowUpdates or {}
	self._pendingRowUpdates[resultID] = true
	if not self:ShouldProcessSearchUpdates() then
		self._resultsDirty = true
		return
	end
	self:ScheduleRowUpdates()
end

function BP:OnSearchResultsUpdated()
	if not self.gfOwnsSearch or not self.activeSearchKey or self.awaitingGFSearch then
		return
	end
	if self.activeSearchKey ~= self:GetSelectionKey() then
		return
	end
	if GF.Search and GF.Search.GetAggregatedResultIDs then
		local aggregateIDs = GF.Search:GetAggregatedResultIDs()
		if aggregateIDs then
			return
		end
	end
	self._resultsDirty = true
	self._pendingFullRefresh = true
end

function BP:ScheduleRowUpdates()
	if self._rowUpdateTimer then
		return
	end
	local delay = GF.ROW_UPDATE_DEBOUNCE or 0.2
	if delay <= 0 or not C_Timer or not C_Timer.After then
		self:FlushPendingRowUpdates()
		return
	end
	self._rowUpdateTimer = C_Timer.After(delay, function()
		self._rowUpdateTimer = nil
		BP:FlushPendingRowUpdates()
	end)
end

function BP:FlushPendingRowUpdates()
	self._resultsDirty = false
	if not self._pendingRowUpdates or not self.scrollList then
		return
	end
	if not self.gfOwnsSearch or not self.activeSearchKey then
		self._pendingRowUpdates = nil
		return
	end
	local pending = self._pendingRowUpdates
	self._pendingRowUpdates = {}
	local needsListRefresh = false
	for resultID in pairs(pending) do
		if self:UpdateRowByResultID(resultID) then
			needsListRefresh = true
		end
	end
	if needsListRefresh then
		if GF.Result and GF.Result.SortResults then
			GF.Result:SortResults(nil, function()
				BP:RefreshList({ preserveScroll = true })
			end)
		else
			self:RefreshList({ preserveScroll = true })
		end
	end
end

function BP:DropFrozenResult(resultID)
	self:ClearSelectionForResultID(resultID)
	return GF.Result:RemoveFromFrozen(resultID)
end

function BP:SoftInvalidateResult(resultID, info)
	if not resultID or not GF.Result or not GF.Result.MarkSoftUnavailable then
		return false
	end
	local entry = GF.Result:MarkSoftUnavailable(resultID, info)
	if not entry then
		return self:DropFrozenResult(resultID)
	end
	self:ClearSelectionForResultID(resultID)
	local row = self:FindRowByResultID(resultID)
	if row and GF.ListRow and GF.ListRow.RepaintRowState then
		GF.ListRow:RepaintRowState(row, entry, row.categoryID)
	end
	return false
end

function BP:ClearSelectionForResultID(resultID)
	if not resultID or not self._selectedRow or self._selectedRow.resultID ~= resultID then
		return
	end
	self._selectedRow._isSelected = nil
	if GF.ListRow and GF.ListRow.UpdateRowBackgrounds then
		GF.ListRow:UpdateRowBackgrounds(self._selectedRow)
	end
	self._selectedRow = nil
	self.selectedResult = nil
	self.selectedResultID = nil
	if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
		GF.SubtitleBar:UpdateSignUpButtonState()
	end
end

function BP:UpdateRowByResultID(resultID)
	if not resultID or not GF.Result:IsFrozenResult(resultID) then
		return false
	end
	local oldEntry = GF.Result.entryCache and GF.Result.entryCache[resultID]
	local oldInfo = oldEntry and oldEntry.info or (GF.Result.sortInfoCache and GF.Result.sortInfoCache[resultID])
	local oldSocialPin = GF.GetSearchResultSocialSortPin
		and GF.GetSearchResultSocialSortPin(oldInfo, resultID)
		or (GF.NORMAL_SORT_PIN or 1)
	local info, infoState = GF.Result:GetLiveSearchResultInfoForUpdate(resultID)
	if not info then
		if infoState == "not_current" then
			return false
		end
		return self:SoftInvalidateResult(resultID)
	end
	local invalidReason = GF.Result:GetSearchResultInvalidReason(resultID, info)
	if invalidReason and invalidReason ~= "dirty" then
		if invalidReason == "unavailable" then
			return self:SoftInvalidateResult(resultID, info)
		end
		return self:DropFrozenResult(resultID)
	end
	if invalidReason == "dirty" and not GF.Result:GetCachedSearchResultInfo(resultID) then
		return self:DropFrozenResult(resultID)
	end
	if invalidReason == "dirty" and not GF.Result:IsLiveSearchResultInfoAuthoritative(resultID) then
		return false
	end
	local entry = GF.Result:RefreshEntryInfo(resultID, info)
	if not entry then
		local reason = GF.Result:GetSearchResultInvalidReason(resultID, info)
		if reason == "unavailable" then
			return self:SoftInvalidateResult(resultID, info)
		end
		return self:DropFrozenResult(resultID)
	end
	local newSocialPin = GF.GetSearchResultSocialSortPin
		and GF.GetSearchResultSocialSortPin(entry.info, resultID)
		or (GF.NORMAL_SORT_PIN or 1)
	local socialPinChanged = oldSocialPin ~= newSocialPin
	local row, index = self:FindRowByResultID(resultID)
	if not row or not index then
		return socialPinChanged
	end
	local spec = self.selection and GF.FilterSpec and GF.FilterSpec:ResolveSpec(self.selection)
	local client = spec and GF.Filter and GF.Filter:GetClientFilters(spec.clientKey)
	local db = (GF.Filter and GF.Filter.GetGlobalFilters and GF.Filter:GetGlobalFilters(spec)) or GF.GetDB()
	local skipFilter = GF.Apply and GF.Apply.IsFreshReject
		and GF.Apply:IsFreshReject(resultID)
	if not skipFilter and GF.ListFilter and not GF.ListFilter:ShouldShowResult(resultID, entry, spec, client, db, info) then
		return self:DropFrozenResult(resultID)
	end
	GF.ListRow:RepaintRowState(row, entry, row.categoryID)
	return socialPinChanged
end

function BP:RemoveHiddenByBlocklist()
	if not self.scrollList or not self.activeSearchKey then
		return
	end
	local BL = GF.Blocklist
	if not BL or not BL.IsEnabled or not BL:IsEnabled() then
		return
	end
	local order = GF.Result.frozenOrder or GF.Result.resultIDs
	if not order or #order == 0 then
		return
	end
	local removed = false
	for i = #order, 1, -1 do
		local resultID = order[i]
		if BL:ShouldHide(resultID) then
			if self:DropFrozenResult(resultID) then
				removed = true
			end
		end
	end
	if removed then
		self:RefreshList({ preserveScroll = true })
	end
end

function BP:ShouldProcessSearchUpdates()
	if not self.scrollList then
		return false
	end
	local mf = GF.MainFrame and GF.MainFrame.frame
	if not mf or not mf:IsShown() then
		return false
	end
	if GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent() ~= GF.TAB_BROWSE then
		return false
	end
	return true
end

function BP:HasFrozenBrowseResults()
	if not self.activeSearchKey then
		return false
	end
	if GF.Result and GF.Result:GetCount() > 0 then
		return true
	end
	return GF.Result and GF.Result.frozenSet and next(GF.Result.frozenSet) ~= nil
end

function BP:PauseSearchListening()
	self.gfOwnsSearch = false
	if GF.SetLfgUpdateListening then
		GF.SetLfgUpdateListening(false)
	end
end

function BP:ResumeSearchListening()
	if not self.activeSearchKey or self.activeSearchKey ~= self:GetSelectionKey() then
		return false
	end
	if not self:HasFrozenBrowseResults() then
		return false
	end
	self.gfOwnsSearch = true
	if GF.SetLfgUpdateListening then
		GF.SetLfgUpdateListening(true)
	end
	return true
end

function BP:CancelListenHoldTimer()
	if self._listenHoldTimer and self._listenHoldTimer.Cancel then
		self._listenHoldTimer:Cancel()
	end
	self._listenHoldTimer = nil
end

function BP:ReleaseHeldSearchListening()
	if not self.gfOwnsSearch then
		return
	end
	self._listenHoldExpired = true
	self:PauseSearchListening()
end

function BP:ScheduleListenHoldRelease()
	self:CancelListenHoldTimer()
	local holdSec = GF.BROWSE_LISTEN_HOLD_SEC or 60
	if not C_Timer or not C_Timer.After then
		self:ReleaseHeldSearchListening()
		return
	end
	self._listenHoldTimer = C_Timer.After(holdSec, function()
		self._listenHoldTimer = nil
		BP:ReleaseHeldSearchListening()
	end)
end

function BP:BrowseListHasBadNames()
	if not self.scrollList then
		return false
	end
	local checked = 0
	local bad = false
	self.scrollList:ForEachFrame(function(row)
		if bad or checked >= 2 then
			return
		end
		checked = checked + 1
		if not row or not row.resultID then
			return
		end
		if not isBadLfgName(row.title and row.title:GetText()) then
			local info = GF.Result and GF.Result.GetAuthoritativeSearchResultInfo
				and GF.Result:GetAuthoritativeSearchResultInfo(row.resultID)
			if not info or not info.name then
				return
			end
			if not isBadLfgName(info.name) and not isBadLfgName(paintedLfgName(info.name)) then
				return
			end
		end
		bad = true
	end)
	return bad
end

function BP:OnBrowseShown()
	self:CancelListenHoldTimer()
	local holdExpired = self._listenHoldExpired
	self:ResumeSearchListening()
	if self._resultsDirty then
		self._resultsDirty = false
		if self._pendingFullRefresh then
			self._pendingFullRefresh = nil
			self:RequestRefreshResults({ preserveScroll = true })
		else
			self:FlushPendingRowUpdates()
		end
	end
	local repaired = false
	if holdExpired then
		self._listenHoldExpired = false
		if self:BrowseListHasBadNames() then
			if GF.Result then
				GF.Result.entryCache = {}
				GF.Result.sortInfoCache = {}
			end
			self:RefreshResults({ preserveScroll = true })
			repaired = true
		end
	end
	if GF.SubtitleBar and GF.SubtitleBar.TryAttachSearchBox then
		GF.SubtitleBar:TryAttachSearchBox()
	end
	if not repaired then
		self:RelayoutWhenReady()
	end
end

function BP:OnFrameHidden()
	self.awaitingGFSearch = false
	if self:HasFrozenBrowseResults() then
		self:ScheduleListenHoldRelease()
	else
		self:CancelListenHoldTimer()
		self._listenHoldExpired = false
		self:PauseSearchListening()
	end
	self:CancelSearchTimeout()
	self:CancelRefreshTimer()
	self:CancelSearchCooldownTimer()
	self:CancelQueuedCooldownSearch()
	self:EndSearchUI()
end

function BP:RequestRefreshResults(opts)
	self:FlushPendingRowUpdates()
	if opts then
		self._pendingRefreshOpts = opts
	end
	if self._refreshDebounce then
		return
	end
	if not C_Timer or not C_Timer.After then
		self:FlushRefreshResults()
		return
	end
	self._refreshDebounce = C_Timer.After(GF.LIST_REFRESH_DEBOUNCE or 0.2, function()
		self._refreshDebounce = nil
		BP:FlushRefreshResults()
	end)
end

function BP:FlushRefreshResults()
	if self._refreshDebounce and self._refreshDebounce.Cancel then
		self._refreshDebounce:Cancel()
	end
	self._refreshDebounce = nil
	local opts = self._pendingRefreshOpts
	self._pendingRefreshOpts = nil
	self:RefreshResults(opts or {})
end

function BP:CancelSearchCooldownTimer()
	if self._searchCooldownTimer and self._searchCooldownTimer.Cancel then
		self._searchCooldownTimer:Cancel()
	end
	self._searchCooldownTimer = nil
end

function BP:GetSearchCooldownRemaining()
	return GF.FindGroup and GF.FindGroup:GetSearchCooldownRemaining(self._lastSearchAt) or 0
end

function BP:CancelQueuedCooldownSearch()
	if self._queuedCooldownSearchTimer and self._queuedCooldownSearchTimer.Cancel then
		self._queuedCooldownSearchTimer:Cancel()
	end
	self._queuedCooldownSearchTimer = nil
	self._queuedCooldownSearchKey = nil
	self._queuedCooldownSearchOpts = nil
	self.awaitingCooldownSearch = false
	self._queuedCooldownSearchToken = (self._queuedCooldownSearchToken or 0) + 1
end

function BP:IsSearchPending()
	return GF.searching
		or self.awaitingGFSearch == true
		or self.awaitingCooldownSearch == true
		or self:GetSearchCooldownRemaining() > 0
end

function BP:ScheduleQueuedCooldownSearch()
	if not self._queuedCooldownSearchKey then
		return
	end
	if self._queuedCooldownSearchTimer and self._queuedCooldownSearchTimer.Cancel then
		self._queuedCooldownSearchTimer:Cancel()
	end
	local token = (self._queuedCooldownSearchToken or 0) + 1
	self._queuedCooldownSearchToken = token
	local delay = GF.SEARCH_COOLDOWN_QUEUE_DELAY or 0.15
	local function runQueuedSearch()
		if BP._queuedCooldownSearchToken ~= token then
			return
		end
		BP._queuedCooldownSearchTimer = nil
		BP:RunQueuedCooldownSearch()
	end
	if C_Timer and C_Timer.After then
		self._queuedCooldownSearchTimer = C_Timer.After(delay, runQueuedSearch)
	else
		runQueuedSearch()
	end
end

function BP:QueueSearchAfterCooldown(opts)
	local key = self:GetSelectionKey()
	if not key then
		return
	end
	self._queuedCooldownSearchKey = key
	self._queuedCooldownSearchOpts = opts or {}
	self.awaitingCooldownSearch = true
	self.awaitingGFSearch = false
	self._searchToken = (self._searchToken or 0) + 1
	self._resultToken = nil
	self:CancelSearchTimeout()
	if GF.Search and GF.Search.Reset then
		GF.Search:Reset()
	end
	GF.searching = false
	if GF.SubtitleBar and GF.SubtitleBar.UpdateRefreshButtonState then
		GF.SubtitleBar:UpdateRefreshButtonState()
	end
	if GF.FilterPanel and GF.FilterPanel.UpdateSearchButtonState then
		GF.FilterPanel:UpdateSearchButtonState()
	end
	self:UpdateSearchHint()
end

function BP:RunQueuedCooldownSearch()
	local key = self._queuedCooldownSearchKey
	local opts = self._queuedCooldownSearchOpts
	self._queuedCooldownSearchKey = nil
	self._queuedCooldownSearchOpts = nil
	self.awaitingCooldownSearch = false
	if not key or key ~= self:GetSelectionKey() or not self:IsSearchableSelection(self.selection) then
		self:UpdateSearchHint()
		return
	end
	if self:GetSearchCooldownRemaining() > 0 then
		self._queuedCooldownSearchKey = key
		self._queuedCooldownSearchOpts = opts
		self.awaitingCooldownSearch = true
		self:ScheduleSearchCooldownUI()
		self:UpdateSearchHint()
		return
	end
	self:DoSearch(opts or {})
end

function BP:ScheduleSearchCooldownUI()
	self:CancelSearchCooldownTimer()
	local function tick()
		local remain = BP:GetSearchCooldownRemaining()
		if GF.SubtitleBar and GF.SubtitleBar.UpdateRefreshButtonState then
			GF.SubtitleBar:UpdateRefreshButtonState()
		end
		if GF.FilterPanel and GF.FilterPanel.UpdateSearchButtonState then
			GF.FilterPanel:UpdateSearchButtonState()
		end
		if BP.UpdateSearchHint then
			BP:UpdateSearchHint()
		end
		if remain <= 0 then
			BP._searchCooldownTimer = nil
			if BP._searchFailed and BP.status then
				BP.status:Hide()
			end
			if BP._queuedCooldownSearchKey then
				BP:ScheduleQueuedCooldownSearch()
			end
			return
		end
		if C_Timer and C_Timer.After then
			BP._searchCooldownTimer = C_Timer.After(0.5, tick)
		end
	end
	if C_Timer and C_Timer.After then
		self._searchCooldownTimer = C_Timer.After(0, tick)
	else
		tick()
	end
end

function BP:RefreshScrollViewport()
	local sl = self.scrollList
	if not sl or not sl.dataProvider then
		return
	end
	if sl.RetainScrollPosition then
		sl:RetainScrollPosition()
	end
end

function BP:UpdateScrollWidth()
	self:RefreshScrollViewport()
end

function BP:GetRelayoutSig()
	local layoutW = GF.GetBrowseListLayoutWidth and GF.GetBrowseListLayoutWidth() or 0
	local profile = "browse_pve"
	if GF.ListColumns and GF.ListColumns.GetBrowseProfile then
		profile = GF.ListColumns:GetBrowseProfile(self.selection)
	end
	if GF.ListColumns and GF.ListColumns.GetRelayoutSig then
		return GF.ListColumns:GetRelayoutSig(layoutW, profile)
	end
	return string.format("%s:%s", profile, layoutW)
end

function BP:CancelRelayoutDebounce()
	if self._relayoutDebounce and self._relayoutDebounce.Cancel then
		self._relayoutDebounce:Cancel()
	end
	self._relayoutDebounce = nil
end

function BP:ScheduleRelayout()
	if self._relayoutDebounce then
		return
	end
	if not C_Timer or not C_Timer.After then
		self:Relayout()
		return
	end
	self._relayoutDebounce = C_Timer.After(0.1, function()
		self._relayoutDebounce = nil
		BP:Relayout()
	end)
end

function BP:RelayoutWhenReady(attempt)
	GF.UI.RelayoutWhenReady(self, attempt)
end

function BP:RelayoutRows()
	if self._frameResizing or GF._frameResizing then
		return
	end
	if self.parent and not self.parent:IsShown() then
		return
	end
	self:CancelRelayoutDebounce()
	if BSL then
		BSL.RelayoutVisible(self)
	end
	self:RefreshScrollViewport()
	GF.UI.CommitRelayoutSig(self)
end

function BP:Relayout(opts)
	opts = opts or {}
	if not self.scrollList then
		return
	end
	if self.parent and not self.parent:IsShown() then
		return
	end
	self:CancelRelayoutDebounce()
	local sig = self:GetRelayoutSig()
	if not opts.force and sig and sig == self._relayoutSig then
		self:RefreshScrollViewport()
		return
	end
	if GF.ListColumns then
		GF.ListColumns:InvalidateCache()
	end
	local layoutW = GF.GetBrowseListLayoutWidth and GF.GetBrowseListLayoutWidth() or 1
	if GF.SubtitleBar and GF.SubtitleBar.LayoutColumnHeaders then
		GF.SubtitleBar:LayoutColumnHeaders(layoutW)
	end
	self:RelayoutRows()
end

function BP:IsSoftUnavailableRow(row)
	if not row or not row.resultID then
		return false
	end
	if row._isDelisted == true then
		return true
	end
	local entry = GF.Result and GF.Result.entryCache and GF.Result.entryCache[row.resultID]
	local info = entry and entry.info
	if not info and GF.Result and GF.Result.sortInfoCache then
		info = GF.Result.sortInfoCache[row.resultID]
	end
	return GF.Result
		and GF.Result.IsSoftUnavailable
		and GF.Result:IsSoftUnavailable(info) == true
end

function BP:DismissSoftUnavailableRow(row)
	if not self:IsSoftUnavailableRow(row) then
		return false
	end
	local resultID = row.resultID
	if not resultID then
		return false
	end
	if self:DropFrozenResult(resultID) then
		self:RefreshList({ preserveScroll = true })
		return true
	end
	return false
end

function BP:WireOneRow(row)
	if not row or row._gfClickWired then
		return
	end
	row._gfClickWired = true
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(r, button)
		if BP:DismissSoftUnavailableRow(r) then
			return
		end
		if button == "RightButton" then
			BP:SetSelectedRow(r)
			if GF.RowContextMenu then
				GF.RowContextMenu:ShowForRow(r)
			end
			return
		end
		if GF.Apply and GF.Apply.OnRowLeftClick then
			GF.Apply:OnRowLeftClick(r)
		else
			BP:SetSelectedRow(r)
		end
	end)
end

function BP:UpdateResultsChrome(count)
	if GF.MainFrame then
		GF.MainFrame:UpdateActivityCount(count)
	end
	if self.empty then
		local showEmpty = count == 0 and self:IsSearchableSelection(self.selection)
		local L = GF.L or {}
		self:SetEmptyPrompt(showEmpty and (L.NO_RESULTS or "") or nil)
	end
	if GF.SubtitleBar and GF.SubtitleBar.UpdateRefreshButtonState then
		GF.SubtitleBar:UpdateRefreshButtonState()
	end
	self:UpdateSearchHint()
end

function BP:ApplyClientFilters()
	if not self.scrollList then
		return
	end
	if not self.activeSearchKey or self.activeSearchKey ~= self:GetSelectionKey() then
		return
	end
	GF.Result:ReapplyClientFilters(function()
		BP:RefreshList({ preserveScroll = true })
	end)
end

function BP:Init(parent)
	if self.scrollList then
		return
	end
	if not GF.UI.ScrollList or not GF.UI.ScrollList.IsAvailable() then
		return
	end

	self.parent = parent
	self.selection = nil
	self.selectedResult = nil
	self.selectedResultID = nil
	self.committedSearchQuery = nil
	self._searchToken = 0
	self.totalResultCount = 0
	local L = GF.L or {}

	self.scrollList = BSL.Create(self, parent, { barParent = parent })
	local scrollBox = self.scrollList:GetScrollBox()
	scrollBox:SetPoint("TOPLEFT", parent, "TOPLEFT", GF.CONTENT_SCROLL_INSET_L or 0, 0)
	GF.UI.AnchorContentScrollBottomRight(scrollBox, parent)

	self._scrollLastW = 0
	self._scrollLastH = 0
	scrollBox:SetScript("OnSizeChanged", function(box, width, height)
		width = width or box:GetWidth() or 0
		height = height or box:GetHeight() or 0
		if width <= 0 or height <= 0 then
			return
		end
		if BP._frameResizing or GF._frameResizing then
			return
		end
		if BP._relayoutSuppressUntil and GetTime() < BP._relayoutSuppressUntil then
			return
		end
		local wChanged = width ~= BP._scrollLastW
		local hChanged = height ~= BP._scrollLastH
		BP._scrollLastW = width
		BP._scrollLastH = height
		if wChanged or hChanged then
			BP:ScheduleRelayout()
		end
	end)

	self.empty = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontHighlight")
	self.empty:SetPoint("CENTER", scrollBox, "CENTER", 0, 0)
	self.empty:SetText(L.NO_RESULTS or "")
	self:ApplyEmptyPromptStyle()
	self.empty:Hide()
	self.emptyAnchor = scrollBox
end

function BP:SetSelectedRow(row)
	if self._selectedRow == row then
		self.selectedResult = row and row.resultIndex or nil
		self.selectedResultID = row and row.resultID or nil
		if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
			GF.SubtitleBar:UpdateSignUpButtonState()
		end
		return
	end
	self:ForEachVisibleRow(function(r)
		if r._isSelected then
			r._isSelected = nil
			if GF.ListRow and GF.ListRow.UpdateRowBackgrounds then
				GF.ListRow:UpdateRowBackgrounds(r)
			end
		end
	end)
	self._selectedRow = row
	self.selectedResult = row and row.resultIndex or nil
	self.selectedResultID = row and row.resultID or nil
	if row then
		row._isSelected = true
		if GF.ListRow and GF.ListRow.UpdateRowBackgrounds then
			GF.ListRow:UpdateRowBackgrounds(row)
		end
	end
	if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
		GF.SubtitleBar:UpdateSignUpButtonState()
	end
end

function BP:RepinForApplication(resultID)
	if not resultID or not GF.Result or not GF.Apply then
		return false
	end
	local prev = GF.Result.resultIDs or {}
	local pinned = GF.Apply:PinApplicationsToTop(prev, resultID)
	if table.concat(pinned, "\31") == table.concat(prev, "\31") then
		return false
	end
	GF.Result.resultIDs = pinned
	GF.Result.total = #pinned
	if GF.Result.frozenOrder then
		GF.Result.frozenOrder = pinned
		local set = {}
		for _, id in ipairs(pinned) do
			set[id] = true
		end
		GF.Result.frozenSet = set
	end
	self:CancelRefreshTimer()
	self.totalResultCount = #pinned
	self:RefreshList({ preserveScroll = true })
	return true
end

function BP:OnApplicationStatusUpdated(resultID, newStatus)
	if GF.Apply and GF.Apply.OnApplicationStatusUpdated then
		GF.Apply:OnApplicationStatusUpdated(resultID, newStatus)
	end
	if not resultID or not self.scrollList then
		return
	end
	if self:RepinForApplication(resultID) then
		return
	end
	local row = self:FindRowByResultID(resultID)
	if row and GF.ListRow then
		GF.ListRow:ApplyApplicationState(row, resultID)
		GF.ListRow:UpdateRowBackgrounds(row)
	end
end

function BP:WireRowClicks()
	self:ForEachVisibleRow(function(row)
		self:WireOneRow(row)
	end)
end

function BP:IsSearchableSelection(node)
	return GF.FindGroup and GF.FindGroup:IsSearchableSelection(node) or false
end

function BP:GetSelectionKey(node)
	node = node or self.selection
	return GF.FindGroup and GF.FindGroup:GetSelectionKey(node) or (node and node.key)
end

function BP:GetDisplayedResultCount()
	local count = tonumber(self._displayedResultCount) or 0
	local provider = self.scrollList and self.scrollList.dataProvider
	if provider then
		if provider.GetSize then
			local ok, size = pcall(provider.GetSize, provider)
			if ok and tonumber(size) then
				count = tonumber(size)
			end
		elseif provider.GetCount then
			local ok, size = pcall(provider.GetCount, provider)
			if ok and tonumber(size) then
				count = tonumber(size)
			end
		end
	end
	return count
end

local function refreshFloatButtonStatus()
	if GF.FloatButton and GF.FloatButton.Refresh then
		GF.FloatButton:Refresh()
	end
end

function BP:HasBrowseList()
	if self:GetDisplayedResultCount() > 0 then
		return true
	end
	return self.activeSearchKey
		and self.activeSearchKey == self:GetSelectionKey()
		and (tonumber(self.totalResultCount) or 0) > 0
end

function BP:ApplyEmptyPromptStyle()
	if not self.empty then
		return
	end
	self.empty:SetTextColor(1, 0.82, 0, 1)
	self.empty._gfFontSizeOverride = GF.BROWSE_EMPTY_TEXT_SIZE or 14
	self.empty._gfFontFlagsOverride = ""
	if GF.Font and GF.Font.Track then
		GF.Font.Track(self.empty, "GameFontHighlight")
	end
end

function BP:UpdateEmptyPromptLayout(showLoading)
	if not self.empty then
		return
	end
	local anchor = self.emptyAnchor or (self.scrollList and self.scrollList.GetScrollBox and self.scrollList:GetScrollBox())
	if not anchor then
		return
	end
	local offsetY = showLoading and (((GF.BROWSE_LOADING_ICON_HEIGHT or 25) + (GF.BROWSE_LOADING_TEXT_GAP or 7)) / 2) or 0
	self.empty:ClearAllPoints()
	self.empty:SetPoint("CENTER", anchor, "CENTER", 0, offsetY)
end

function BP:EnsureLoadingAnimation()
	if self.loadingAnimation then
		return self.loadingAnimation
	end
	local parent = self.emptyAnchor or (self.scrollList and self.scrollList.GetScrollBox and self.scrollList:GetScrollBox())
	if not parent then
		return nil
	end
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 5)
	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local iconWidth = GF.BROWSE_LOADING_ICON_WIDTH or 27
	local iconHeight = GF.BROWSE_LOADING_ICON_HEIGHT or 25
	local iconGap = GF.BROWSE_LOADING_ICON_GAP or 6
	local width = (iconWidth * iconCount) + (iconGap * math.max(0, iconCount - 1))
	frame:SetSize(width, iconHeight)
	frame.icons = {}
	for index = 1, iconCount do
		local icon = frame:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(GF.BROWSE_LOADING_TEAMUP_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\TeamUp.png")
		icon:SetTexCoord((index - 1) / iconCount, index / iconCount, 0, 1)
		icon:SetSize(iconWidth, iconHeight)
		icon:SetPoint("LEFT", frame, "LEFT", (index - 1) * (iconWidth + iconGap), 0)
		icon:SetAlpha(0)
		icon:Hide()
		frame.icons[index] = icon
	end
	frame:SetScript("OnShow", function(animation)
		animation.elapsed = 0
		refreshLoadingAnimation(animation)
	end)
	frame:SetScript("OnUpdate", function(animation, elapsed)
		animation.elapsed = ((animation.elapsed or 0) + (elapsed or 0)) % getLoadingCycleSeconds()
		refreshLoadingAnimation(animation)
	end)
	frame:Hide()
	self.loadingAnimation = frame
	return frame
end

function BP:SetLoadingAnimationShown(shown)
	local animation = shown and self:EnsureLoadingAnimation() or self.loadingAnimation
	if not animation then
		return
	end
	animation:ClearAllPoints()
	if shown and self.empty then
		animation:SetPoint("TOP", self.empty, "BOTTOM", 0, -(GF.BROWSE_LOADING_TEXT_GAP or 7))
	end
	if shown then
		animation:Show()
	else
		animation:Hide()
	end
end

function BP:SetEmptyPrompt(text, showLoading)
	if not self.empty then
		return
	end
	showLoading = showLoading == true
	if text and text ~= "" then
		self:ApplyEmptyPromptStyle()
		self:UpdateEmptyPromptLayout(showLoading)
		self.empty:SetText(text)
		self.empty:Show()
		self:SetLoadingAnimationShown(showLoading)
	else
		self.empty:Hide()
		self:SetLoadingAnimationShown(false)
	end
end

function BP:UpdateSearchHint()
	local L = GF.L or {}
	local text
	local showLoading = false
	local searchable = self:IsSearchableSelection(self.selection)
	local searchPending = searchable and self:IsSearchPending()
	if self:HasBrowseList() then
		self:SetEmptyPrompt(nil)
	elseif searchPending then
		text = L.LOADING_GROUP_LIST or "Loading group listings"
		showLoading = true
	elseif not searchable then
		text = L.BROWSE_SELECT_ACTIVITY_TO_SEARCH or L.NO_SELECTION or ""
	elseif not self.activeSearchKey or self.activeSearchKey ~= self:GetSelectionKey() then
		text = L.CLICK_SEARCH or ""
	else
		text = L.NO_RESULTS or ""
	end
	if text and text ~= "" then
		self:SetEmptyPrompt(text, showLoading)
	elseif not self.activeSearchKey or self.activeSearchKey ~= self:GetSelectionKey() then
		self:SetEmptyPrompt(nil)
	end
	if GF.MainFrame and GF.MainFrame.UpdateBrowseStatusHint then
		GF.MainFrame:UpdateBrowseStatusHint(nil)
	end
	if GF.SubtitleBar and GF.SubtitleBar.UpdateRefreshButtonState then
		GF.SubtitleBar:UpdateRefreshButtonState()
	end
end

function BP:OnSearchCommitted()
	self.activeSearchKey = self:GetSelectionKey()
	self:UpdateSearchHint()
end

function BP:ResetBrowseScroll()
	if self.scrollList then
		self.scrollList:ScrollToBegin()
	end
end

function BP:DetachBrowseSearch()
	self:CancelQueuedCooldownSearch()
	self.activeSearchKey = nil
	self.gfOwnsSearch = false
	if GF.SetLfgUpdateListening then
		GF.SetLfgUpdateListening(false)
	end
	self:CancelRefreshTimer()
end

function BP:ClearRowDisplay()
	self:CancelRefreshTimer()
	self._selectedRow = nil
	self.selectedResult = nil
	self.selectedResultID = nil
	self.totalResultCount = 0
	self._displayedResultCount = 0
	self._listOrderSig = nil
	if self.scrollList then
		self.scrollList:SetElements({})
	end
	if GF.Result and GF.Result.ClearFrozenSnapshot then
		GF.Result:ClearFrozenSnapshot()
	end
	self:ResetBrowseScroll()
	self:SetEmptyPrompt(nil)
	if GF.Result and GF.Result.entryCache then
		GF.Result.entryCache = {}
	end
	if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
		GF.SubtitleBar:UpdateSignUpButtonState()
	end
	refreshFloatButtonStatus()
end

function BP:ResetBrowsePage()
	self.awaitingGFSearch = false
	self._searchToken = (self._searchToken or 0) + 1
	self._resultToken = nil
	self._searchFailed = false
	self._resultsDirty = false
	self._pendingRowUpdates = nil
	self._pendingRefreshOpts = nil
	self._lastSearchAt = nil
	self.committedSearchQuery = nil
	self:CancelListenHoldTimer()
	self:CancelSearchTimeout()
	self:CancelRefreshTimer()
	self:CancelSearchCooldownTimer()
	self:CancelQueuedCooldownSearch()
	self:EndSearchUI()
	self:DetachBrowseSearch()
	if GF.Result and GF.Result.Clear then
		GF.Result:Clear()
	end
	self:ClearRowDisplay()
	if GF.MainFrame then
		GF.MainFrame:UpdateActivityCount(0)
		GF.MainFrame:UpdateBrowseStatusHint(nil)
	end
	self:UpdateSearchHint()
end

function BP:ClearCommittedSearchQuery()
	self.committedSearchQuery = nil
	self:UpdateSearchHint()
end

function BP:SetSelection(node, opts)
	opts = opts or {}
	self.selection = node
	local selKey = self:GetSelectionKey(node)
	if self._queuedCooldownSearchKey and self._queuedCooldownSearchKey ~= selKey then
		self:CancelQueuedCooldownSearch()
	end
	local preserveResults = opts.preserveBrowseResults == true or opts.preserveResults == true
	if selKey ~= self.activeSearchKey and not preserveResults then
		self:DetachBrowseSearch()
		self._selectedRow = nil
		self.selectedResult = nil
		self.selectedResultID = nil
		self:ClearRowDisplay()
	end
	self:UpdateTitle()
	self:UpdateBlocked()
	self:UpdateSearchHint()
end

function BP:UpdateTitle()
	if GF.SubtitleBar and GF.SubtitleBar.SetCategoryLabel then
		if not self.selection then
			GF.SubtitleBar:SetCategoryLabel(nil)
			return
		end
		if not self.selection.activityID or self.selection.customBucket then
			GF.SubtitleBar:SetCategoryLabel(self.selection.label or "")
			return
		end
		local info = self.selection.activityInfo or C_LFGList.GetActivityInfoTable(self.selection.activityID)
		GF.SubtitleBar:SetCategoryLabel(GF.UI.GetCategoryTitle(self.selection.categoryID, info))
	end
end

function BP:UpdateBlocked()
	if self.scrollList then
		local box = self.scrollList:GetScrollBox()
		if box then
			box:Show()
		end
	end
	if GF.SubtitleBar then
		GF.SubtitleBar:SetBrowseEnabled(true)
	end
end

function BP:CancelSearchTimeout()
	if self._searchTimeout and self._searchTimeout.Cancel then
		self._searchTimeout:Cancel()
	end
	self._searchTimeout = nil
end

function BP:ScheduleSearchTimeout(token)
	if not C_Timer or not C_Timer.After then
		return
	end
	self:CancelSearchTimeout()
	self._searchTimeout = C_Timer.After(GF.SEARCH_TIMEOUT_SECONDS or 8, function()
		self._searchTimeout = nil
		if self._searchToken == token and self.awaitingGFSearch then
			self.awaitingGFSearch = false
			self:EndSearchUI()
			self:UpdateSearchHint()
		end
	end)
end

function BP:EndSearchUI()
	self:CancelSearchTimeout()
	GF.searching = false
	if GF.SubtitleBar and GF.SubtitleBar.SetSearchingState then
		GF.SubtitleBar:SetSearchingState(false)
	end
	if GF.FilterPanel and GF.FilterPanel.UpdateSearchButtonState then
		GF.FilterPanel:UpdateSearchButtonState(false)
	end
end

function BP:DoSearch(opts)
	opts = opts or {}
	if not self:IsSearchableSelection(self.selection) then
		return
	end

	local cooldownRemain = self:GetSearchCooldownRemaining()
	if cooldownRemain > 0 then
		self:QueueSearchAfterCooldown(opts)
		self:ScheduleSearchCooldownUI()
		return
	end
	self:CancelQueuedCooldownSearch()

	if GF.NavFlyout and GF.NavFlyout.HideAll then
		GF.NavFlyout:HideAll()
	end

	self._searchToken = (self._searchToken or 0) + 1
	local token = self._searchToken
	self._resultToken = token
	self._searchFailed = false

	self:CancelRefreshTimer()
	if GF.Apply and GF.Apply.ClearFreshRejects then
		GF.Apply:ClearFreshRejects()
	end
	self:ClearRowDisplay()

	if GF.SubtitleBar and GF.SubtitleBar.GetEffectiveSearchText then
		self.committedSearchQuery = GF.SubtitleBar:GetEffectiveSearchText()
	end

	if GF.MainFrame then
		GF.MainFrame:UpdateActivityCount(0)
		GF.MainFrame:UpdateBrowseStatusHint(nil)
	end
	self:SetEmptyPrompt(nil)

	self.awaitingGFSearch = true
	GF.searching = true
	if GF.SubtitleBar and GF.SubtitleBar.SetSearchingState then
		GF.SubtitleBar:SetSearchingState(true)
	end
	do
		local L = GF.L or {}
		self:SetEmptyPrompt(L.LOADING_GROUP_LIST or "Loading group listings", true)
	end

	if GetTime then
		self._lastSearchAt = GetTime()
	end
	self:ScheduleSearchCooldownUI()

	local started = false
	if GF.FindGroup then
		started = GF.FindGroup:RunSearch(self.selection)
	end
	if not started then
		self.awaitingGFSearch = false
		self._resultToken = nil
		self:EndSearchUI()
		self:UpdateSearchHint()
		return
	end

	self:ScheduleSearchTimeout(token)
end

function BP:RefreshList(opts)
	opts = opts or {}
	if not self.scrollList then
		return
	end
	if not self.activeSearchKey or self.activeSearchKey ~= self:GetSelectionKey() then
		return
	end

	local ids = GF.Result.resultIDs or {}
	local count = #ids
	self.totalResultCount = count
	self:UpdateResultsChrome(count)

	if count == 0 then
		self._selectedRow = nil
		self.selectedResult = nil
		self.selectedResultID = nil
		self._displayedResultCount = 0
		self._listOrderSig = ""
		self.scrollList:SetElements({})
		if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
			GF.SubtitleBar:UpdateSignUpButtonState()
		end
		refreshFloatButtonStatus()
		return
	end

	if self.selectedResultID then
		local selectedIndex = GF.Result:GetIndexForResultID(self.selectedResultID)
		if selectedIndex then
			self.selectedResult = selectedIndex
		else
			if self._selectedRow then
				self._selectedRow._isSelected = nil
				if GF.ListRow and GF.ListRow.UpdateRowBackgrounds then
					GF.ListRow:UpdateRowBackgrounds(self._selectedRow)
				end
			end
			self._selectedRow = nil
			self.selectedResult = nil
			self.selectedResultID = nil
			if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
				GF.SubtitleBar:UpdateSignUpButtonState()
			end
		end
	end

	local sig = buildListOrderSig(ids)
	local canRepaintOnly = opts.preserveScroll
		and not opts.forceRebuild
		and self._listOrderSig == sig
		and sig ~= ""
		and self.scrollList.dataProvider

	if canRepaintOnly then
		self._displayedResultCount = count
		self:SetEmptyPrompt(nil)
		self:RepaintVisibleRows()
		if BSL.RelayoutVisible then
			BSL.RelayoutVisible(self)
		end
		if not opts.skipSnapshot then
			GF.Result:CommitSnapshot()
		end
		refreshFloatButtonStatus()
		return
	end

	if not opts.preserveScroll then
		self._selectedRow = nil
		self.selectedResult = nil
		self.selectedResultID = nil
		if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
			GF.SubtitleBar:UpdateSignUpButtonState()
		end
	end

	self._listOrderSig = sig
	local elements = BSL.BuildElements(ids)
	self._displayedResultCount = #elements
	self.scrollList:SetElements(elements, { retainScroll = opts.preserveScroll })
	self:SetEmptyPrompt(nil)
	if BSL.RelayoutVisible then
		BSL.RelayoutVisible(self)
	end

	if not opts.skipSnapshot then
		GF.Result:CommitSnapshot()
	end
	refreshFloatButtonStatus()
end

function BP:RefreshResults(opts)
	opts = opts or {}
	if GF.Apply and GF.Apply.ClearFreshRejects then
		GF.Apply:ClearFreshRejects()
	end
	if self._refreshDebounce and self._refreshDebounce.Cancel then
		self._refreshDebounce:Cancel()
	end
	self._refreshDebounce = nil
	self._pendingRefreshOpts = nil
	if not self.scrollList then
		return
	end
	self._resultsDirty = false
	if not self.activeSearchKey or self.activeSearchKey ~= self:GetSelectionKey() then
		if GF.searching or self.awaitingGFSearch then
			self:EndSearchUI()
		end
		self:ClearRowDisplay()
		self:UpdateSearchHint()
		if GF.MainFrame then
			GF.MainFrame:UpdateActivityCount(0)
		end
		return
	end
	self:EndSearchUI()
	local token = (self._refreshToken or 0) + 1
	self._refreshToken = token
	GF.Result:RefreshCache(function()
		if token ~= self._refreshToken then
			return
		end
		BP:RefreshList(opts)
	end)
end

function BP:SignUp()
	if not self.selectedResult then
		return
	end
	if GF.Apply and GF.Apply.ShowDialogForIndex then
		GF.Apply:ShowDialogForIndex(self.selectedResult, self.selectedResultID)
	end
end

function BP:Show()
	if self.parent then
		self.parent:Show()
	end
end

function BP:Hide()
	if self.parent then
		self.parent:Hide()
	end
end
