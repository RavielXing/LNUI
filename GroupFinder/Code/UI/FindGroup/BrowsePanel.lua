local _, GF = ...

local Panel = {}
GF.BrowsePanel = Panel

local BrowseList = GF.BrowseScrollList
local ORDER_SEPARATOR = "\31"
local REDACTED_NAME = "|Kr0|k"

-- Small UI notifications are centralized to keep state transitions readable.
local function refreshSignUpState()
	if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
		GF.SubtitleBar:UpdateSignUpButtonState()
	end
end

local function refreshSearchButtons()
	if GF.SubtitleBar and GF.SubtitleBar.UpdateRefreshButtonState then
		GF.SubtitleBar:UpdateRefreshButtonState()
	end
	if GF.FilterPanel and GF.FilterPanel.UpdateSearchButtonState then
		GF.FilterPanel:UpdateSearchButtonState()
	end
end

local function refreshFloatingStatus()
	if GF.FloatButton and GF.FloatButton.Refresh then
		GF.FloatButton:Refresh()
	end
end

local function stopTimer(owner, field)
	local timer = owner[field]
	owner[field] = nil
	if timer and timer.Cancel then
		timer:Cancel()
	end
end

local function currentTime()
	return type(GetTime) == "function" and GetTime() or 0
end

local function selectionFilterContext(selection)
	local spec
	if selection and GF.FilterSpec then
		spec = GF.FilterSpec:ResolveSpec(selection)
	end
	local client
	if spec and GF.Filter then
		client = GF.Filter:GetClientFilters(spec.clientKey)
	end
	local database
	if GF.Filter and GF.Filter.GetGlobalFilters then
		database = GF.Filter:GetGlobalFilters(spec)
	elseif GF.GetDB then
		database = GF.GetDB()
	end
	return spec, client, database
end

-- Loading illustration -----------------------------------------------------

local function loadingDurations()
	return GF.BROWSE_LOADING_STEP_SECONDS or 0.28,
		GF.BROWSE_LOADING_FADE_IN_SECONDS or 0.16,
		GF.BROWSE_LOADING_HOLD_SECONDS or 0.4,
		GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45,
		GF.BROWSE_LOADING_ICON_COUNT or 3
end

local function loadingCycleLength()
	local step, _, hold, fadeOut, iconCount = loadingDurations()
	return step * iconCount + hold + fadeOut
end

local function clampUnit(value)
	return math.max(0, math.min(1, value))
end

local function iconOpacity(elapsed, position)
	local step, fadeIn, hold, fadeOut, iconCount = loadingDurations()
	local startAt = (position - 1) * step
	if elapsed < startAt then
		return 0
	end
	if elapsed < startAt + fadeIn then
		return fadeIn > 0 and clampUnit((elapsed - startAt) / fadeIn) or 1
	end
	local disappearAt = step * iconCount + hold
	if elapsed < disappearAt then
		return 1
	end
	if elapsed < disappearAt + fadeOut then
		return fadeOut > 0 and clampUnit((disappearAt + fadeOut - elapsed) / fadeOut) or 0
	end
	return 0
end

local function paintLoadingFrame(frame)
	if not (frame and frame.icons) then
		return
	end
	for position, texture in ipairs(frame.icons) do
		local alpha = iconOpacity(frame.elapsed or 0, position)
		texture:SetAlpha(alpha)
		texture:SetShown(alpha > 0.02)
	end
end

function Panel:EnsureLoadingAnimation()
	if self.loadingAnimation then
		return self.loadingAnimation
	end
	local host = self.emptyAnchor
	if not host and self.scrollList and self.scrollList.GetScrollBox then
		host = self.scrollList:GetScrollBox()
	end
	if not host then
		return nil
	end

	local animation = CreateFrame("Frame", nil, host)
	local hostLevel = host.GetFrameLevel and host:GetFrameLevel() or 0
	animation:SetFrameLevel(hostLevel + 5)
	local _, _, _, _, count = loadingDurations()
	local iconWidth = GF.BROWSE_LOADING_ICON_WIDTH or 27
	local iconHeight = GF.BROWSE_LOADING_ICON_HEIGHT or 25
	local gap = GF.BROWSE_LOADING_ICON_GAP or 6
	animation:SetSize(iconWidth * count + gap * math.max(0, count - 1), iconHeight)
	animation.icons = {}
	for position = 1, count do
		local icon = animation:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(GF.BROWSE_LOADING_TEAMUP_TEXTURE or GF.TEAMUP_TEXTURE)
		icon:SetTexCoord((position - 1) / count, position / count, 0, 1)
		icon:SetSize(iconWidth, iconHeight)
		icon:SetPoint("LEFT", animation, "LEFT", (position - 1) * (iconWidth + gap), 0)
		icon:SetAlpha(0)
		icon:Hide()
		animation.icons[position] = icon
	end
	animation:SetScript("OnShow", function(frame)
		frame.elapsed = 0
		paintLoadingFrame(frame)
	end)
	animation:SetScript("OnUpdate", function(frame, delta)
		frame.elapsed = ((frame.elapsed or 0) + (delta or 0)) % loadingCycleLength()
		paintLoadingFrame(frame)
	end)
	animation:Hide()
	self.loadingAnimation = animation
	return animation
end

function Panel:SetLoadingAnimationShown(shown)
	local animation = shown and self:EnsureLoadingAnimation() or self.loadingAnimation
	if not animation then
		return
	end
	animation:ClearAllPoints()
	if shown and self.empty then
		animation:SetPoint("TOP", self.empty, "BOTTOM", 0, -(GF.BROWSE_LOADING_TEXT_GAP or 7))
	end
	animation:SetShown(shown == true)
end

function Panel:ApplyEmptyPromptStyle()
	if not self.empty then
		return
	end
	self.empty:SetTextColor(1, 0.82, 0, 1)
	if GF.UI and GF.UI.ApplyEmptyPromptFont then
		GF.UI.ApplyEmptyPromptFont(self.empty, "GameFontHighlight")
	end
end

function Panel:UpdateEmptyPromptLayout(showLoading)
	if not self.empty then
		return
	end
	local anchor = self.emptyAnchor
	if not anchor and self.scrollList and self.scrollList.GetScrollBox then
		anchor = self.scrollList:GetScrollBox()
	end
	if not anchor then
		return
	end
	local y = 0
	if showLoading then
		y = ((GF.BROWSE_LOADING_ICON_HEIGHT or 25) + (GF.BROWSE_LOADING_TEXT_GAP or 7)) / 2
	end
	self.empty:ClearAllPoints()
	self.empty:SetPoint("CENTER", anchor, "CENTER", 0, y)
end

function Panel:SetEmptyPrompt(text, showLoading)
	if not self.empty then
		return
	end
	local hasText = type(text) == "string" and text ~= ""
	if not hasText then
		self.empty:Hide()
		self:SetLoadingAnimationShown(false)
		return
	end
	local animate = showLoading == true
	self:ApplyEmptyPromptStyle()
	self:UpdateEmptyPromptLayout(animate)
	self.empty:SetText(text)
	self.empty:Show()
	self:SetLoadingAnimationShown(animate)
end

-- Secret/kstring recovery --------------------------------------------------

local NameProbe = {
	resolvedBadDisplay = nil,
	frame = nil,
}

local function probeFontString()
	if NameProbe.frame then
		return NameProbe.frame.text
	end
	local frame = CreateFrame("Frame")
	frame:Hide()
	frame.text = GF.UI.CreateFontString(frame, "ARTWORK", "GameFontNormal")
	NameProbe.frame = frame
	return frame.text
end

local function knownBadRenderedName()
	if NameProbe.resolvedBadDisplay ~= nil then
		return NameProbe.resolvedBadDisplay
	end
	local probe = probeFontString()
	probe:SetText(REDACTED_NAME)
	local displayed = probe:GetText()
	if type(displayed) == "string" and displayed ~= "" and displayed ~= REDACTED_NAME then
		NameProbe.resolvedBadDisplay = displayed
	else
		NameProbe.resolvedBadDisplay = false
	end
	return NameProbe.resolvedBadDisplay
end

local function secretText(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

local function unusableListingName(value)
	if value == nil then
		return false
	end
	if GF.Result and GF.Result.IsUnreadableLfgText then
		if not GF.Result:IsUnreadableLfgText(value) then
			return false
		end
		if secretText(value) then
			return true
		end
		local plain = tostring(value)
		if type(strtrim) == "function" then
			plain = strtrim(plain)
		end
		return plain ~= ""
	end
	if secretText(value) then
		return true
	end
	if value == "" then
		return false
	end
	return value == knownBadRenderedName()
end

local function paintListingName(value)
	if not value or value == "" then
		return nil
	end
	local probe = probeFontString()
	knownBadRenderedName()
	probe:SetText(value)
	return probe:GetText()
end

function Panel:BrowseListHasBadNames()
	if not self.scrollList then
		return false
	end
	local inspected, found = 0, false
	self.scrollList:ForEachFrame(function(row)
		if found or inspected >= 2 then
			return
		end
		inspected = inspected + 1
		if not (row and row.resultID) then
			return
		end
		local rowText = row.title and row.title:GetText()
		if unusableListingName(rowText) then
			found = true
			return
		end
		local info = GF.Result
			and GF.Result.GetAuthoritativeSearchResultInfo
			and GF.Result:GetAuthoritativeSearchResultInfo(row.resultID)
		if info and info.name then
			found = unusableListingName(info.name)
				or unusableListingName(paintListingName(info.name))
		end
	end)
	return found
end

-- Row access and stable selection -----------------------------------------

function Panel:ForEachVisibleRow(visitor)
	if self.scrollList and type(visitor) == "function" then
		self.scrollList:ForEachFrame(visitor)
	end
end

function Panel:FindRowByResultID(resultID)
	if not (resultID and self.scrollList) then
		return nil, nil
	end
	local row = self.scrollList:FindFrameByKey(resultID)
	return row, row and row.resultIndex or nil
end

local function repaintSelection(row)
	if row and GF.ListRow and GF.ListRow.UpdateRowBackgrounds then
		GF.ListRow:UpdateRowBackgrounds(row)
	end
end

function Panel:SetSelectedRow(row)
	if row == self._selectedRow then
		self.selectedResult = row and row.resultIndex or nil
		self.selectedResultID = row and row.resultID or nil
		refreshSignUpState()
		return
	end
	self:ForEachVisibleRow(function(candidate)
		if candidate._isSelected then
			candidate._isSelected = nil
			repaintSelection(candidate)
		end
	end)
	self._selectedRow = row
	self.selectedResult = row and row.resultIndex or nil
	self.selectedResultID = row and row.resultID or nil
	if row then
		row._isSelected = true
		repaintSelection(row)
	end
	refreshSignUpState()
end

function Panel:ClearSelectionForResultID(resultID)
	local row = self._selectedRow
	if not (resultID and row and row.resultID == resultID) then
		return
	end
	row._isSelected = nil
	repaintSelection(row)
	self._selectedRow = nil
	self.selectedResult = nil
	self.selectedResultID = nil
	refreshSignUpState()
end

function Panel:RepaintVisibleRows()
	self:ForEachVisibleRow(function(row)
		local resultID = row and row.resultID
		local renderer = GF.ListRow
		if not (resultID and renderer and renderer.RepaintRowState) then
			return
		end
		local index = GF.Result:GetIndexForResultID(resultID)
		local entry = index and GF.Result:GetEntry(index)
		if entry then
			row.resultIndex = index
			renderer:RepaintRowState(row, entry, row.categoryID)
		end
	end)
end

function Panel:IsSoftUnavailableRow(row)
	if not (row and row.resultID) then
		return false
	end
	if row._isDelisted == true then
		return true
	end
	local result = GF.Result
	local entry = result and result.entryCache and result.entryCache[row.resultID]
	local info = entry and entry.info
	if not info and result and result.sortInfoCache then
		info = result.sortInfoCache[row.resultID]
	end
	return result ~= nil
		and result.IsSoftUnavailable ~= nil
		and result:IsSoftUnavailable(info) == true
end

function Panel:DismissSoftUnavailableRow(row)
	if not self:IsSoftUnavailableRow(row) then
		return false
	end
	local resultID = row.resultID
	if resultID and self:DropFrozenResult(resultID) then
		self:RefreshList({ preserveScroll = true })
		return true
	end
	return false
end

function Panel:WireOneRow(row)
	local target = row
	if target == nil or target._gfClickWired == true then
		return
	end
	target._gfClickWired = true
	target:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	target:SetScript("OnClick", function(clickedRow, mouseButton)
		if Panel:DismissSoftUnavailableRow(clickedRow) then
			return
		end
		if mouseButton == "RightButton" then
			Panel:SetSelectedRow(clickedRow)
			if GF.RowContextMenu then
				GF.RowContextMenu:ShowForRow(clickedRow)
			end
		elseif GF.Apply and GF.Apply.OnRowLeftClick then
			GF.Apply:OnRowLeftClick(clickedRow)
		else
			Panel:SetSelectedRow(clickedRow)
		end
	end)
end

function Panel:WireRowClicks()
	self:ForEachVisibleRow(function(row)
		self:WireOneRow(row)
	end)
end

-- Native update coalescing -------------------------------------------------

function Panel:CancelRowUpdateTimer()
	stopTimer(self, "_rowUpdateTimer")
end

function Panel:CancelRefreshTimer()
	stopTimer(self, "_refreshDebounce")
	self:CancelRowUpdateTimer()
	self._pendingRowUpdates = nil
	self._pendingFullRefresh = nil
	self._refreshToken = (self._refreshToken or 0) + 1
end

function Panel:ShouldProcessSearchUpdates()
	if not self.scrollList then
		return false
	end
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	if not (mainFrame and mainFrame:IsShown()) then
		return false
	end
	if GF.TabBar and GF.TabBar.GetCurrent then
		return GF.TabBar:GetCurrent() == GF.TAB_BROWSE
	end
	return true
end

function Panel:OnSearchResultUpdated(resultID)
	if not (resultID and self.gfOwnsSearch and self.activeSearchKey) then
		return
	end
	local resultState = GF.Result
	local belongsToSnapshot = resultState and resultState:IsFrozenResult(resultID)
	if self.activeSearchKey ~= self:GetSelectionKey() or not belongsToSnapshot then
		return
	end
	local pending = self._pendingRowUpdates or {}
	pending[resultID] = true
	self._pendingRowUpdates = pending
	if self:ShouldProcessSearchUpdates() then
		self:ScheduleRowUpdates()
	else
		self._resultsDirty = true
	end
end

function Panel:OnSearchResultsUpdated()
	if not self.gfOwnsSearch or not self.activeSearchKey or self.awaitingGFSearch then
		return
	end
	if self.activeSearchKey ~= self:GetSelectionKey() then
		return
	end
	if GF.Search and GF.Search.GetAggregatedResultIDs then
		local aggregate = GF.Search:GetAggregatedResultIDs()
		if aggregate then
			return
		end
	end
	self._resultsDirty = true
	self._pendingFullRefresh = true
end

function Panel:ScheduleRowUpdates()
	if self._rowUpdateTimer then
		return
	end
	local delay = GF.ROW_UPDATE_DEBOUNCE or 0.2
	if delay <= 0 or not (C_Timer and C_Timer.NewTimer) then
		self:FlushPendingRowUpdates()
		return
	end
	self._rowUpdateTimer = C_Timer.NewTimer(delay, function()
		Panel._rowUpdateTimer = nil
		Panel:FlushPendingRowUpdates()
	end)
end

function Panel:DropFrozenResult(resultID)
	self:ClearSelectionForResultID(resultID)
	return GF.Result:RemoveFromFrozen(resultID)
end

function Panel:SoftInvalidateResult(resultID, info)
	if not (resultID and GF.Result and GF.Result.MarkSoftUnavailable) then
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

function Panel:UpdateRowByResultID(resultID)
	if not (resultID and GF.Result:IsFrozenResult(resultID)) then
		return false
	end
	local previousEntry = GF.Result.entryCache and GF.Result.entryCache[resultID]
	local previousInfo = previousEntry and previousEntry.info
		or (GF.Result.sortInfoCache and GF.Result.sortInfoCache[resultID])
	local previousPin = GF.GetSearchResultSortPin
		and GF.GetSearchResultSortPin(previousInfo, resultID)
		or (GF.NORMAL_SORT_PIN or 1)

	local info, state = GF.Result:GetLiveSearchResultInfoForUpdate(resultID)
	if not info then
		if previousInfo and GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(previousInfo, resultID)
		then
			return false
		end
		if state == "not_current" then
			return false
		end
		return self:SoftInvalidateResult(resultID)
	end

	local invalid = GF.Result:GetSearchResultInvalidReason(resultID, info)
	if invalid and invalid ~= "dirty" then
		if invalid == "unavailable" then
			return self:SoftInvalidateResult(resultID, info)
		end
		return self:DropFrozenResult(resultID)
	end
	if invalid == "dirty" then
		if not GF.Result:GetCachedSearchResultInfo(resultID) then
			return self:DropFrozenResult(resultID)
		end
		if not GF.Result:IsLiveSearchResultInfoAuthoritative(resultID) then
			return false
		end
	end

	local entry = GF.Result:RefreshEntryInfo(resultID, info)
	if not entry then
		local reason = GF.Result:GetSearchResultInvalidReason(resultID, info)
		if reason == "unavailable" then
			return self:SoftInvalidateResult(resultID, info)
		end
		return self:DropFrozenResult(resultID)
	end

	local nextPin = GF.GetSearchResultSortPin
		and GF.GetSearchResultSortPin(entry.info, resultID)
		or (GF.NORMAL_SORT_PIN or 1)
	local row, index = self:FindRowByResultID(resultID)
	if not (row and index) then
		return previousPin ~= nextPin
	end
	local spec, client, database = selectionFilterContext(self.selection)
	local freshReject = GF.Apply and GF.Apply.IsFreshReject
		and GF.Apply:IsFreshReject(resultID)
	if not freshReject and GF.ListFilter
		and not GF.ListFilter:ShouldShowResult(resultID, entry, spec, client, database, info)
	then
		return self:DropFrozenResult(resultID)
	end
	if GF.ListRow and GF.ListRow.RepaintRowState then
		GF.ListRow:RepaintRowState(row, entry, row.categoryID)
	end
	return previousPin ~= nextPin
end

function Panel:FlushPendingRowUpdates()
	self._resultsDirty = false
	if not (self._pendingRowUpdates and self.scrollList) then
		return
	end
	if not self.gfOwnsSearch or not self.activeSearchKey then
		self._pendingRowUpdates = nil
		return
	end
	local updates = self._pendingRowUpdates
	self._pendingRowUpdates = {}
	local orderMayChange = false
	for resultID in pairs(updates) do
		orderMayChange = self:UpdateRowByResultID(resultID) or orderMayChange
	end
	if not orderMayChange then
		return
	end
	if GF.Result and GF.Result.SortResults then
		GF.Result:SortResults(nil, function()
			Panel:RefreshList({ preserveScroll = true })
		end)
	else
		self:RefreshList({ preserveScroll = true })
	end
end

function Panel:RemoveHiddenByBlocklist()
	if not (self.scrollList and self.activeSearchKey) then
		return
	end
	local blocklist = GF.Blocklist
	if not (blocklist and blocklist.IsEnabled and blocklist:IsEnabled()) then
		return
	end
	local resultState = GF.Result
	local order = resultState and (resultState.frozenOrder or resultState.resultIDs)
	if type(order) ~= "table" or next(order) == nil then
		return
	end
	local changed = false
	for position = #order, 1, -1 do
		local resultID = order[position]
		if blocklist:ShouldHide(resultID) then
			changed = self:DropFrozenResult(resultID) or changed
		end
	end
	if changed then
		self:RefreshList({ preserveScroll = true })
	end
end

-- Search-listening ownership ----------------------------------------------

function Panel:HasFrozenBrowseResults()
	local resultState = GF.Result
	if self.activeSearchKey and resultState and resultState:GetCount() > 0 then
		return true
	end
	local frozen = self.activeSearchKey and resultState and resultState.frozenSet
	return frozen ~= nil and next(frozen) ~= nil
end

function Panel:PauseSearchListening()
	self.gfOwnsSearch = false
	if GF.SetLfgUpdateListening then
		GF.SetLfgUpdateListening(false)
	end
end

function Panel:ResumeSearchListening()
	local searchKey = self.activeSearchKey
	local ownsCurrentSelection = searchKey ~= nil and searchKey == self:GetSelectionKey()
	if not ownsCurrentSelection or self:HasRefreshableBrowseSource() ~= true then
		return false
	end
	self.gfOwnsSearch = true
	local setListening = GF.SetLfgUpdateListening
	if setListening then
		setListening(true)
	end
	return true
end

function Panel:CancelListenHoldTimer()
	stopTimer(self, "_listenHoldTimer")
end

function Panel:ReleaseHeldSearchListening()
	if self.gfOwnsSearch then
		self._listenHoldExpired = true
		self:PauseSearchListening()
	end
end

function Panel:ScheduleListenHoldRelease()
	self:CancelListenHoldTimer()
	if not (C_Timer and C_Timer.NewTimer) then
		self:ReleaseHeldSearchListening()
		return
	end
	self._listenHoldTimer = C_Timer.NewTimer(GF.BROWSE_LISTEN_HOLD_SEC or 60, function()
		Panel._listenHoldTimer = nil
		Panel:ReleaseHeldSearchListening()
	end)
end

local function repairUnreadableVisibleNames(panel)
	if not panel:BrowseListHasBadNames() then
		return false
	end
	if GF.Result then
		GF.Result.entryCache, GF.Result.sortInfoCache = {}, {}
	end
	panel:RefreshResults({ preserveScroll = true })
	return true
end

function Panel:OnBrowseShown()
	self:CancelListenHoldTimer()
	local expired = self._listenHoldExpired
	local reapplyClientFilters = self._clientFiltersDirty == true
	self._clientFiltersDirty = nil
	local resumedSearch = self:ResumeSearchListening()
	if self._resultsDirty then
		self._resultsDirty = false
		if self._pendingFullRefresh then
			self._pendingFullRefresh = nil
			self:RequestRefreshResults({ preserveScroll = true })
			reapplyClientFilters = false
		else
			self:FlushPendingRowUpdates()
		end
	end
	if reapplyClientFilters and resumedSearch then
		self:ApplyClientFilters()
	end

	local repaired = false
	if expired then
		self._listenHoldExpired = false
		repaired = repairUnreadableVisibleNames(self)
	end
	local subtitle = GF.SubtitleBar
	if subtitle and subtitle.TryAttachSearchBox then
		subtitle:TryAttachSearchBox()
	end
	if not repaired then
		self:RefreshLayoutIfReady()
	end
end

function Panel:OnBrowseHidden()
	if self.selection and self.selection._gfQuestSearch == true
		and GF.Search and GF.Search.SuspendNativeQuestSearch
	then
		GF.Search:SuspendNativeQuestSearch()
	end
	local abandonedPendingSearch = self.awaitingGFSearch == true
	self.awaitingGFSearch = false
	if abandonedPendingSearch then
		-- The pending search already cleared the visible list, so its pre-search
		-- apiResultIDs are not a refreshable snapshot.  End the whole transaction
		-- before deciding whether hidden-page results can be retained; otherwise
		-- returning to this tab can revive the previous search after the abandoned
		-- native result event has been consumed.
		self._searchToken = (self._searchToken or 0) + 1
		self._resultToken = nil
		self._activeSearchContext = nil
		self.activeSearchKey = nil
		self.gfOwnsSearch = false
		self._clientFiltersDirty = nil
		self._resultsDirty = false
		self._pendingFullRefresh = nil
		if GF.Search and GF.Search.AbandonActiveRequest then
			if GF.Search:AbandonActiveRequest() then
				self:ScheduleSearchCooldownUI()
			end
		elseif GF.Search and GF.Search.Reset then
			GF.Search:Reset()
		end
		if GF.Result and GF.Result.DiscardBrowseSource then
			GF.Result:DiscardBrowseSource()
		end
		self:PauseSearchListening()
	end
	self:DiscardManualDeclineRefresh()
	local retainsResults = not abandonedPendingSearch
		and self:HasRefreshableBrowseSource()
	if GF.Result and type(GF.Result.InvalidateAsyncJobs) == "function" then
		GF.Result:InvalidateAsyncJobs()
		if retainsResults then
			self._clientFiltersDirty = true
		end
	end
	if GF.Apply and GF.Apply.ClearFreshRejects then
		if GF.Apply:ClearFreshRejects() and retainsResults then
			self._clientFiltersDirty = true
		end
	end
	if retainsResults then
		self:ScheduleListenHoldRelease()
	else
		self:CancelListenHoldTimer()
		self._listenHoldExpired = false
		self:PauseSearchListening()
	end
	for _, method in ipairs({
		"CancelSearchTimeout",
		"CancelRefreshTimer",
		"CancelSearchCooldownTimer",
		"CancelQueuedCooldownSearch",
	}) do
		self[method](self)
	end
	self:EndSearchUI()
end

function Panel:OnFrameHidden()
	self:OnBrowseHidden()
end

-- Refresh and cooldown timers ---------------------------------------------

function Panel:RequestRefreshResults(options)
	self:FlushPendingRowUpdates()
	if options then
		self._pendingRefreshOpts = options
	end
	if self._refreshDebounce then
		return
	end
	if not (C_Timer and C_Timer.NewTimer) then
		self:FlushRefreshResults()
		return
	end
	self._refreshDebounce = C_Timer.NewTimer(GF.LIST_REFRESH_DEBOUNCE or 0.2, function()
		Panel._refreshDebounce = nil
		Panel:FlushRefreshResults()
	end)
end

function Panel:FlushRefreshResults()
	stopTimer(self, "_refreshDebounce")
	local options = self._pendingRefreshOpts or {}
	self._pendingRefreshOpts = nil
	self:RefreshResults(options)
end

function Panel:CancelSearchCooldownTimer()
	stopTimer(self, "_searchCooldownTimer")
end

function Panel:GetSearchCooldownRemaining()
	local addon = GF.FindGroup and GF.FindGroup:GetSearchCooldownRemaining(self._lastSearchAt) or 0
	local native = GF.Search and GF.Search.GetCooldownRemaining
		and GF.Search:GetCooldownRemaining() or 0
	local barrier = GF.Search and GF.Search.GetRequestBarrierRemaining
		and GF.Search:GetRequestBarrierRemaining() or 0
	return math.max(addon, native, barrier)
end

function Panel:CancelQueuedCooldownSearch()
	stopTimer(self, "_queuedCooldownSearchTimer")
	self._queuedCooldownSearchKey = nil
	self._queuedCooldownSearchOpts = nil
	self.awaitingCooldownSearch = false
	self._queuedCooldownSearchToken = (self._queuedCooldownSearchToken or 0) + 1
end

function Panel:IsSearchPending()
	return GF.searching == true
		or self.awaitingGFSearch == true
		or self.awaitingCooldownSearch == true
end

function Panel:ScheduleQueuedCooldownSearch()
	if not self._queuedCooldownSearchKey then
		return
	end
	stopTimer(self, "_queuedCooldownSearchTimer")
	local token = (self._queuedCooldownSearchToken or 0) + 1
	self._queuedCooldownSearchToken = token
	local function run()
		if Panel._queuedCooldownSearchToken == token then
			Panel._queuedCooldownSearchTimer = nil
			Panel:RunQueuedCooldownSearch()
		end
	end
	if C_Timer and C_Timer.NewTimer then
		self._queuedCooldownSearchTimer = C_Timer.NewTimer(
			GF.SEARCH_COOLDOWN_QUEUE_DELAY or 0.15,
			run
		)
	else
		run()
	end
end

function Panel:QueueSearchAfterCooldown(options)
	local key = self:GetSelectionKey()
	if not key then
		return
	end
	self._queuedCooldownSearchKey = key
	self._queuedCooldownSearchOpts = options or {}
	self.awaitingCooldownSearch = true
	self.awaitingGFSearch = false
	self:DiscardManualDeclineRefresh()
	self._searchToken = (self._searchToken or 0) + 1
	self._resultToken = nil
	self:CancelSearchTimeout()
	local clearedFreshRejects = GF.Apply and GF.Apply.ClearFreshRejects
		and GF.Apply:ClearFreshRejects() == true
	if GF.Search and GF.Search.AbandonActiveRequest then
		GF.Search:AbandonActiveRequest()
	elseif GF.Search and GF.Search.Reset then
		GF.Search:Reset()
	end
	GF.searching = false
	refreshSearchButtons()
	if clearedFreshRejects and self:HasRefreshableBrowseSource() then
		if self.gfOwnsSearch and self:ShouldProcessSearchUpdates() then
			self._clientFiltersDirty = nil
			self:ApplyClientFilters()
		else
			self._clientFiltersDirty = true
		end
	end
	self:UpdateSearchHint()
end

function Panel:RunQueuedCooldownSearch()
	local key, options = self._queuedCooldownSearchKey, self._queuedCooldownSearchOpts
	self._queuedCooldownSearchKey = nil
	self._queuedCooldownSearchOpts = nil
	self.awaitingCooldownSearch = false
	if not key or key ~= self:GetSelectionKey()
		or not self:IsSearchableSelection(self.selection)
	then
		self:UpdateSearchHint()
		return
	end
	if self:GetSearchCooldownRemaining() > 0 then
		self._queuedCooldownSearchKey = key
		self._queuedCooldownSearchOpts = options
		self.awaitingCooldownSearch = true
		self:ScheduleSearchCooldownUI()
		self:UpdateSearchHint()
		return
	end
	self:DoSearch(options or {})
end

function Panel:ScheduleSearchCooldownUI()
	self:CancelSearchCooldownTimer()
	local function tick()
		local remaining = Panel:GetSearchCooldownRemaining()
		refreshSearchButtons()
		Panel:UpdateSearchHint()
		if remaining <= 0 then
			Panel._searchCooldownTimer = nil
			if Panel._searchFailed and Panel.status then
				Panel.status:Hide()
			end
			if Panel._queuedCooldownSearchKey then
				Panel:ScheduleQueuedCooldownSearch()
			end
		elseif C_Timer and C_Timer.NewTimer then
			Panel._searchCooldownTimer = C_Timer.NewTimer(0.5, tick)
		end
	end
	if C_Timer and C_Timer.NewTimer then
		self._searchCooldownTimer = C_Timer.NewTimer(0, tick)
	else
		tick()
	end
end

-- Layout -------------------------------------------------------------------

function Panel:RefreshScrollViewport()
	local list = self.scrollList
	if list and list.dataProvider and list.RetainScrollPosition then
		list:RetainScrollPosition()
	end
end

function Panel:UpdateScrollWidth()
	self:RefreshScrollViewport()
end

function Panel:GetRelayoutSig()
	local width = 0
	if GF.GetBrowseListLayoutWidth then
		width = GF.GetBrowseListLayoutWidth()
	end
	local profile = "browse_pve"
	local columns = GF.ListColumns
	if columns and columns.GetBrowseProfile then
		profile = columns:GetBrowseProfile(self.selection)
	end
	if columns and columns.GetRelayoutSig then
		return columns:GetRelayoutSig(width, profile)
	end
	return table.concat({ profile, tostring(width) }, ":")
end

function Panel:CancelRelayoutDebounce()
	stopTimer(self, "_relayoutDebounce")
end

function Panel:ScheduleRelayout()
	if self._relayoutDebounce then
		return
	end
	if not (C_Timer and C_Timer.NewTimer) then
		self:Relayout()
		return
	end
	self._relayoutDebounce = C_Timer.NewTimer(0.1, function()
		Panel._relayoutDebounce = nil
		Panel:Relayout()
	end)
end

function Panel:RefreshLayoutIfReady(attempt)
	if GF.UI and GF.UI.RefreshListLayoutIfReady then
		GF.UI.RefreshListLayoutIfReady(self, attempt)
	end
end

function Panel:RelayoutRows()
	local hidden = self.parent and not self.parent:IsShown()
	if hidden or self._frameResizing == true or GF._frameResizing == true then
		return
	end
	self:CancelRelayoutDebounce()
	if BrowseList and BrowseList.RelayoutVisible then
		BrowseList.RelayoutVisible(self)
	end
	self:RefreshScrollViewport()
	if GF.UI and GF.UI.CommitRelayoutSig then
		GF.UI.CommitRelayoutSig(self)
	end
end

local function layoutBrowseColumnHeaders()
	local columns = GF.ListColumns
	if columns then
		columns:InvalidateCache()
	end
	local getLayoutWidth = GF.GetBrowseListLayoutWidth
	local layoutWidth = getLayoutWidth and getLayoutWidth() or 1
	local subtitleBar = GF.SubtitleBar
	if subtitleBar and subtitleBar.LayoutColumnHeaders then
		subtitleBar:LayoutColumnHeaders(layoutWidth)
	end
end

function Panel:Relayout(options)
	options = options or {}
	if not self.scrollList or (self.parent and not self.parent:IsShown()) then
		return
	end
	self:CancelRelayoutDebounce()
	local signature = self:GetRelayoutSig()
	if not options.force and signature and signature == self._relayoutSig then
		self:RefreshScrollViewport()
		return
	end
	layoutBrowseColumnHeaders()
	self:RelayoutRows()
end

-- Panel construction -------------------------------------------------------

local function createBrowseScroll(panel, parent)
	local list = BrowseList.Create(panel, parent, { barParent = parent })
	local box = list:GetScrollBox()
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", GF.CONTENT_SCROLL_INSET_L or 0, 0)
	GF.UI.AnchorContentScrollBottomRight(box, parent)
	return list, box
end

local function createEmptyLabel(parent, scrollBox)
	local label = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontHighlight")
	label:SetPoint("CENTER", scrollBox, "CENTER", 0, 0)
	label:SetText((GF.L and GF.L.NO_RESULTS) or "")
	return label
end

function Panel:Init(parent)
	if self.scrollList then
		return
	end
	if not (GF.UI.ScrollList and GF.UI.ScrollList.IsAvailable()) then
		return
	end
	self.parent, self.selection = parent, nil
	self.selectedResult, self.selectedResultID = nil, nil
	self.committedSearchQuery = nil
	self._searchToken, self.totalResultCount = 0, 0

	local scrollBox
	self.scrollList, scrollBox = createBrowseScroll(self, parent)
	self._scrollLastW, self._scrollLastH = 0, 0
	scrollBox:SetScript("OnSizeChanged", function(box, width, height)
		local nextWidth = width or box:GetWidth() or 0
		local nextHeight = height or box:GetHeight() or 0
		if nextWidth <= 0 or nextHeight <= 0 then
			return
		end
		if Panel._frameResizing or GF._frameResizing then
			return
		end
		if Panel._relayoutSuppressUntil
			and currentTime() < Panel._relayoutSuppressUntil
		then
			return
		end
		local changed = nextWidth ~= Panel._scrollLastW
			or nextHeight ~= Panel._scrollLastH
		Panel._scrollLastW, Panel._scrollLastH = nextWidth, nextHeight
		if changed then
			Panel:ScheduleRelayout()
		end
	end)

	self.empty = createEmptyLabel(parent, scrollBox)
	self:ApplyEmptyPromptStyle()
	self.empty:Hide()
	self.emptyAnchor = scrollBox
end

function Panel:IsSearchableSelection(node)
	return GF.FindGroup ~= nil
		and GF.FindGroup:IsSearchableSelection(node) == true
end

function Panel:GetSelectionKey(node)
	local selected = node or self.selection
	local key
	if GF.FindGroup then
		key = GF.FindGroup:GetSelectionKey(selected)
	end
	return key or (selected and selected.key) or nil
end

function Panel:GetDisplayedResultCount()
	local count = tonumber(self._displayedResultCount) or 0
	local provider = self.scrollList and self.scrollList.dataProvider
	if not provider then
		return count
	end
	local reader = provider.GetSize or provider.GetCount
	if not reader then
		return count
	end
	local ok, size = pcall(reader, provider)
	return ok and tonumber(size) or count
end

local function hasResultSequence(source)
	return type(source) == "table" and next(source) ~= nil
end

function Panel:HasBrowseList()
	if self:GetDisplayedResultCount() > 0 then
		return true
	end
	return self.activeSearchKey ~= nil
		and self.activeSearchKey == self:GetSelectionKey()
		and (tonumber(self.totalResultCount) or 0) > 0
end

function Panel:HasRefreshableBrowseSource()
	if self.activeSearchKey == nil
		or self.activeSearchKey ~= self:GetSelectionKey()
	then
		return false
	end
	local resultState = GF.Result
	return resultState ~= nil and (
		hasResultSequence(resultState.apiResultIDs)
		or hasResultSequence(resultState.resultIDs)
		or hasResultSequence(resultState.frozenOrder)
	)
end

function Panel:CanManualRefresh()
	return self:HasRefreshableBrowseSource()
end

function Panel:UpdateResultsChrome(count)
	if GF.MainFrame then
		GF.MainFrame:UpdateActivityCount(count)
	end
	if self.empty then
		local showEmpty = count == 0 and self:IsSearchableSelection(self.selection)
		local locale = GF.L or {}
		self:SetEmptyPrompt(showEmpty and (locale.NO_RESULTS or "") or nil)
	end
	if GF.SubtitleBar and GF.SubtitleBar.UpdateRefreshButtonState then
		GF.SubtitleBar:UpdateRefreshButtonState()
	end
	self:UpdateSearchHint()
end

function Panel:UpdateSearchHint()
	local locale = GF.L or {}
	local message, animate
	local searchable = self:IsSearchableSelection(self.selection)
	if self:HasBrowseList() then
		self:SetEmptyPrompt(nil)
	elseif searchable and self:IsSearchPending() then
		message = locale.LOADING_GROUP_LIST or "Loading group listings"
		animate = true
	elseif not searchable then
		local seasonalScopeMissing = self.selection ~= nil
			and GF.LFGWorkspaceView ~= nil
			and GF.LFGWorkspaceView.IsMythicPlusActive ~= nil
			and GF.LFGWorkspaceView:IsMythicPlusActive()
			and GF.LFGWorkspacePolicy ~= nil
			and GF.LFGWorkspacePolicy.GetSeasonActivityIDs ~= nil
			and #GF.LFGWorkspacePolicy:GetSeasonActivityIDs() == 0
		if seasonalScopeMissing then
			message = locale.MPLUS_LFG_SCOPE_UNAVAILABLE
				or "Level restricted: Seasonal Mythic+ mode has not been unlocked."
		else
			message = locale.BROWSE_SELECT_ACTIVITY_TO_SEARCH or locale.NO_SELECTION or ""
		end
	elseif not self.activeSearchKey or self.activeSearchKey ~= self:GetSelectionKey() then
		message = locale.CLICK_SEARCH or ""
	else
		message = locale.NO_RESULTS or ""
	end

	if message and message ~= "" then
		self:SetEmptyPrompt(message, animate)
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

-- Search ownership and page reset -----------------------------------------

function Panel:OnSearchCommitted()
	self.activeSearchKey = self:GetSelectionKey()
	self:UpdateSearchHint()
end

function Panel:DiscardManualDeclineRefresh()
	self._manualDeclineRefresh = nil
end

function Panel:DiscardPendingManualDeclineIntent()
	self:DiscardManualDeclineRefresh()
	local queued = self._queuedCooldownSearchOpts
	if type(queued) == "table" then
		queued.manualRefresh = false
		queued._gfManualRefreshConfirmed = nil
		queued._gfCapturedDeclines = nil
	end
end

function Panel:ResetBrowseScroll()
	if self.scrollList then
		self.scrollList:ScrollToBegin()
	end
end

function Panel:DetachBrowseSearch()
	self:CancelQueuedCooldownSearch()
	self:DiscardManualDeclineRefresh()
	self._clientFiltersDirty = nil
	if GF.Apply and GF.Apply.ClearFreshRejects then
		GF.Apply:ClearFreshRejects()
	end
	if GF.Result and GF.Result.InvalidateAsyncJobs then
		GF.Result:InvalidateAsyncJobs()
	end
	self.activeSearchKey = nil
	self.gfOwnsSearch = false
	self._activeSearchContext = nil
	local abandoned = false
	if GF.Search and GF.Search.AbandonActiveRequest then
		abandoned = GF.Search:AbandonActiveRequest() == true
	elseif GF.Search and GF.Search.Reset then
		GF.Search:Reset()
	end
	if GF.SetLfgUpdateListening then
		GF.SetLfgUpdateListening(false)
	end
	self:CancelRefreshTimer()
	if abandoned then
		self:ScheduleSearchCooldownUI()
	end
end

function Panel:ClearRowDisplay()
	self:CancelRefreshTimer()
	self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
	self.totalResultCount, self._displayedResultCount = 0, 0
	self._listOrderSig = nil
	local list = self.scrollList
	if list then
		list:SetElements({})
	end
	local resultState = GF.Result
	if resultState and resultState.ClearFrozenSnapshot then
		resultState:ClearFrozenSnapshot()
	end
	self:ResetBrowseScroll()
	self:SetEmptyPrompt(nil)
	if GF.Result and GF.Result.entryCache then
		GF.Result.entryCache = {}
	end
	refreshSignUpState()
	refreshFloatingStatus()
end

function Panel:ResetBrowsePage()
	if self.selection and self.selection._gfQuestSearch == true
		and GF.Search and GF.Search.ClearNativeQuestSearch
	then
		GF.Search:ClearNativeQuestSearch()
	end
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

function Panel:ClearCommittedSearchQuery()
	self.committedSearchQuery = nil
	self:UpdateSearchHint()
end

function Panel:SetWorkspaceContext(context)
	local previous = self.workspaceContext and self.workspaceContext.key
	local nextKey = context and context.key
	self.workspaceContext = context
	if previous == nextKey then
		return false
	end
	self:ResetBrowsePage()
	if GF.SubtitleBar and GF.SubtitleBar.ClearSearchText then
		GF.SubtitleBar:ClearSearchText()
	end
	return true
end

function Panel:GetWorkspaceContext()
	return self.workspaceContext
end

function Panel:GetActiveSearchContext()
	return self._activeSearchContext
end

function Panel:SetSelection(node, options)
	options = options or {}
	local previous = self.selection
	local previousKey = self:GetSelectionKey(previous)
	local nextKey = node and self:GetSelectionKey(node) or nil
	if previous and previous._gfQuestSearch == true
		and previousKey ~= nextKey
		and GF.Search and GF.Search.ClearNativeQuestSearch
	then
		GF.Search:ClearNativeQuestSearch()
	end
	self.selection = node
	local key = self:GetSelectionKey(node)
	if self._queuedCooldownSearchKey and self._queuedCooldownSearchKey ~= key then
		self:CancelQueuedCooldownSearch()
	end
	local preserve = options.preserveBrowseResults == true
		or options.preserveResults == true
	if key ~= self.activeSearchKey and not preserve then
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

function Panel:UpdateTitle()
	if not (GF.SubtitleBar and GF.SubtitleBar.SetCategoryLabel) then
		return
	end
	local selection = self.selection
	if not selection then
		GF.SubtitleBar:SetCategoryLabel(nil)
		return
	end
	if not selection.activityID or selection.customBucket then
		GF.SubtitleBar:SetCategoryLabel(selection.label or "")
		return
	end
	local activityInfo = selection.activityInfo
	if not activityInfo and C_LFGList and C_LFGList.GetActivityInfoTable then
		activityInfo = C_LFGList.GetActivityInfoTable(selection.activityID)
	end
	GF.SubtitleBar:SetCategoryLabel(GF.UI.GetCategoryTitle(selection.categoryID, activityInfo))
end

function Panel:UpdateBlocked()
	if self.scrollList then
		local scrollBox = self.scrollList:GetScrollBox()
		if scrollBox then
			scrollBox:Show()
		end
	end
	if GF.SubtitleBar then
		GF.SubtitleBar:SetBrowseEnabled(true)
	end
end

-- Search execution ---------------------------------------------------------

function Panel:CancelSearchTimeout()
	stopTimer(self, "_searchTimeout")
end

function Panel:ScheduleSearchTimeout(token)
	if not (C_Timer and C_Timer.NewTimer) then
		return
	end
	self:CancelSearchTimeout()
	self._searchTimeout = C_Timer.NewTimer(GF.SEARCH_TIMEOUT_SECONDS or 8, function()
		Panel._searchTimeout = nil
		if Panel._searchToken ~= token or not Panel.awaitingGFSearch then
			return
		end
		Panel.awaitingGFSearch = false
		Panel._resultToken = nil
		Panel._activeSearchContext = nil
		Panel:DiscardManualDeclineRefresh()
		if GF.Search and GF.Search.AbandonActiveRequest then
			GF.Search:AbandonActiveRequest()
		elseif GF.Search and GF.Search.Reset then
			GF.Search:Reset()
		end
		Panel:EndSearchUI()
		Panel:ScheduleSearchCooldownUI()
		Panel:UpdateSearchHint()
	end)
end

function Panel:EndSearchUI()
	self:CancelSearchTimeout()
	GF.searching = false
	if GF.SubtitleBar and GF.SubtitleBar.SetSearchingState then
		GF.SubtitleBar:SetSearchingState(false)
	end
	if GF.FilterPanel and GF.FilterPanel.UpdateSearchButtonState then
		GF.FilterPanel:UpdateSearchButtonState(false)
	end
end

local function activeWorkspaceContext(panel)
	if panel.workspaceContext then
		return panel.workspaceContext
	end
	if GF.LFGWorkspaceView and GF.LFGWorkspaceView.GetContext then
		return GF.LFGWorkspaceView:GetContext() or {}
	end
	return {}
end

local function makeSearchContext(panel, token)
	local workspace = activeWorkspaceContext(panel)
	return {
		workspaceID = workspace.workspaceID,
		generation = workspace.generation,
		key = workspace.key,
		searchToken = token,
	}
end

local function prepareSearchDisplay(panel)
	panel:CancelRefreshTimer()
	panel._clientFiltersDirty = nil
	panel:PauseSearchListening()
	if GF.Result and GF.Result.InvalidateAsyncJobs then
		GF.Result:InvalidateAsyncJobs()
	end
	if GF.Apply and GF.Apply.ClearFreshRejects then
		GF.Apply:ClearFreshRejects()
	end
	panel:ClearRowDisplay()
	local subtitle = GF.SubtitleBar
	if subtitle and subtitle.GetEffectiveSearchText then
		panel.committedSearchQuery = subtitle:GetEffectiveSearchText()
	end
	if GF.MainFrame then
		GF.MainFrame:UpdateActivityCount(0)
		GF.MainFrame:UpdateBrowseStatusHint(nil)
	end
	panel:SetEmptyPrompt(nil)
end

function Panel:DoSearch(options)
	options = options or {}
	if not self:IsSearchableSelection(self.selection) then
		return false
	end
	local manualRefresh = options.manualRefresh == true
		and (options._gfManualRefreshConfirmed == true or self:CanManualRefresh())
	local capturedDeclines = options._gfCapturedDeclines
	if manualRefresh and options._gfManualRefreshConfirmed ~= true then
		options._gfManualRefreshConfirmed = true
		if GF.Apply
			and type(GF.Apply.CaptureDeclinedApplicationsForManualRefresh) == "function"
		then
			capturedDeclines = GF.Apply:CaptureDeclinedApplicationsForManualRefresh()
			options._gfCapturedDeclines = capturedDeclines
		end
	end
	local cooldownRemaining = self:GetSearchCooldownRemaining()
	if cooldownRemaining > 0 then
		self:QueueSearchAfterCooldown(options)
		self:ScheduleSearchCooldownUI()
		return true
	end
	self:CancelQueuedCooldownSearch()
	if GF.NavFlyout and GF.NavFlyout.HideAll then
		GF.NavFlyout:HideAll()
	end

	local token = (self._searchToken or 0) + 1
	self._searchToken = token
	self._resultToken = token
	self._manualDeclineRefresh = capturedDeclines and {
		token = token,
		selectionKey = self:GetSelectionKey(),
		captured = capturedDeclines,
	} or nil
	self._searchFailed = false
	local context = makeSearchContext(self, token)
	self._activeSearchContext = context
	prepareSearchDisplay(self)
	self.awaitingGFSearch = true
	GF.searching = true
	if GF.SubtitleBar and GF.SubtitleBar.SetSearchingState then
		GF.SubtitleBar:SetSearchingState(true)
	end
	local locale = GF.L or {}
	self:SetEmptyPrompt(locale.LOADING_GROUP_LIST or "Loading group listings", true)

	local started = GF.FindGroup and GF.FindGroup:RunSearch(self.selection, context)
	if not started then
		self.awaitingGFSearch = false
		self._resultToken = nil
		self._activeSearchContext = nil
		self:DiscardManualDeclineRefresh()
		self:EndSearchUI()
		local barrier = GF.Search and GF.Search.GetRequestBarrierRemaining
			and GF.Search:GetRequestBarrierRemaining() or 0
		local cooldown = GF.Search and GF.Search.GetCooldownRemaining
			and GF.Search:GetCooldownRemaining() or 0
		if math.max(barrier, cooldown) > 0 then
			self:QueueSearchAfterCooldown(options)
			self:ScheduleSearchCooldownUI()
			return true
		else
			self:UpdateSearchHint()
		end
		return false
	end

	if type(GetTime) == "function" then
		self._lastSearchAt = GetTime()
	end
	self:ScheduleSearchCooldownUI()
	self:ScheduleSearchTimeout(token)
	return true
end

function Panel:ApplyClientFilters()
	if not self.scrollList
		or self.awaitingGFSearch
		or self.gfOwnsSearch ~= true
		or not self.activeSearchKey
		or self.activeSearchKey ~= self:GetSelectionKey()
	then
		return
	end
	local searchToken = self._searchToken
	local activeSearchKey = self.activeSearchKey
	GF.Result:ReapplyClientFilters(function()
		if self._searchToken ~= searchToken
			or self.awaitingGFSearch
			or self.activeSearchKey ~= activeSearchKey
			or activeSearchKey ~= self:GetSelectionKey()
		then
			return
		end
		self:RefreshList({ preserveScroll = true })
	end)
end

-- List rendering -----------------------------------------------------------

local function orderSignature(ids)
	if not ids or #ids == 0 then
		return ""
	end
	return table.concat(ids, ORDER_SEPARATOR)
end

function Panel:RefreshList(options)
	options = options or {}
	local list = self.scrollList
	if not list
		or not self.activeSearchKey
		or self.activeSearchKey ~= self:GetSelectionKey()
	then
		return
	end
	local resultState = GF.Result
	local ids = resultState and resultState.resultIDs or {}
	local count = #ids
	self.totalResultCount = count
	self:UpdateResultsChrome(count)

	if count == 0 then
		self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
		self._displayedResultCount = 0
		self._listOrderSig = ""
		self.scrollList:SetElements({})
		refreshSignUpState()
		refreshFloatingStatus()
		return
	end

	if self.selectedResultID then
		local index = GF.Result:GetIndexForResultID(self.selectedResultID)
		if index then
			self.selectedResult = index
		else
			if self._selectedRow then
				self._selectedRow._isSelected = nil
				repaintSelection(self._selectedRow)
			end
			self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
			refreshSignUpState()
		end
	end

	local signature = orderSignature(ids)
	local repaintOnly = options.preserveScroll
		and not options.forceRebuild
		and signature ~= ""
		and signature == self._listOrderSig
		and self.scrollList.dataProvider ~= nil
	if repaintOnly then
		self._displayedResultCount = count
		self:SetEmptyPrompt(nil)
		self:RepaintVisibleRows()
		if BrowseList.RelayoutVisible then
			BrowseList.RelayoutVisible(self)
		end
		if not options.skipSnapshot then
			GF.Result:CommitSnapshot()
		end
		refreshFloatingStatus()
		return
	end

	if not options.preserveScroll then
		self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
		refreshSignUpState()
	end
	self._listOrderSig = signature
	local elements = BrowseList.BuildElements(ids)
	self._displayedResultCount = #elements
	self.scrollList:SetElements(elements, { retainScroll = options.preserveScroll })
	self:SetEmptyPrompt(nil)
	if BrowseList.RelayoutVisible then
		BrowseList.RelayoutVisible(self)
	end
	if not options.skipSnapshot then
		GF.Result:CommitSnapshot()
	end
	refreshFloatingStatus()
end

function Panel:RefreshResults(options)
	options = options or {}
	if self.awaitingGFSearch == true
		and options.commitManualDeclineRefresh ~= true
	then
		self._resultsDirty = true
		return
	end
	stopTimer(self, "_refreshDebounce")
	self._pendingRefreshOpts = nil
	local hasListSurface = self.scrollList ~= nil
	if not hasListSurface then
		self:DiscardManualDeclineRefresh()
		return
	end
	self._resultsDirty = false
	local currentSelectionKey = self:GetSelectionKey()
	local ownsDisplayedSearch = self.activeSearchKey ~= nil
		and self.activeSearchKey == currentSelectionKey
	if not ownsDisplayedSearch then
		self:DiscardManualDeclineRefresh()
		local wasWaiting = GF.searching or self.awaitingGFSearch
		if wasWaiting then
			self:EndSearchUI()
		end
		self:ClearRowDisplay()
		self:UpdateSearchHint()
		local main = GF.MainFrame
		if main then
			main:UpdateActivityCount(0)
		end
		return
	end
	self:EndSearchUI()
	local token = (self._refreshToken or 0) + 1
	self._refreshToken = token
	local manualRefresh = self._manualDeclineRefresh
	local beforePostFilters
	if manualRefresh then
		local valid = manualRefresh.token == self._searchToken
			and manualRefresh.selectionKey == currentSelectionKey
		if options.commitManualDeclineRefresh == true
			and valid
			and GF.Apply
			and type(GF.Apply.CommitDeclinedApplicationsForManualRefresh) == "function"
		then
			beforePostFilters = function(resultIDs)
				if Panel._manualDeclineRefresh ~= manualRefresh then
					return
				end
				Panel:DiscardManualDeclineRefresh()
				GF.Apply:CommitDeclinedApplicationsForManualRefresh(
					manualRefresh.captured, resultIDs)
			end
		elseif options.commitManualDeclineRefresh == true or not valid then
			self:DiscardManualDeclineRefresh()
		end
	end
	GF.Result:RefreshCache(function()
		if Panel._refreshToken == token then
			Panel:RefreshList(options)
		end
	end, beforePostFilters)
end

function Panel:RepinForApplication(resultID)
	if not (resultID and GF.Result and GF.Apply) then
		return false
	end
	local previous = GF.Result.frozenOrder or GF.Result.resultIDs or {}
	local reordered = GF.Apply:PinApplicationsToTop(previous, resultID)
	if orderSignature(previous) == orderSignature(reordered) then
		return false
	end
	GF.Result.resultIDs = reordered
	GF.Result.total = #reordered
	if GF.Result.frozenOrder then
		GF.Result.frozenOrder = reordered
		local frozen = {}
		for _, id in ipairs(reordered) do
			frozen[id] = true
		end
		GF.Result.frozenSet = frozen
	end
	self:CancelRefreshTimer()
	self.totalResultCount = #reordered
	self:RefreshList({ preserveScroll = true })
	return true
end

function Panel:OnApplicationStatusUpdated(resultID, newStatus)
	local apply = GF.Apply
	local cachedEntry = GF.Result and GF.Result.entryCache
		and GF.Result.entryCache[resultID]
	local hadJoinedProjection = (cachedEntry ~= nil
		and cachedEntry._gfJoinedApplicationSupplement == true)
		or (apply and type(apply.IsJoinedApplicationTracked) == "function"
			and apply:IsJoinedApplicationTracked(resultID) == true)
	local currentGroupChanged = false
	if apply and apply.OnApplicationStatusUpdated then
		currentGroupChanged = apply:OnApplicationStatusUpdated(resultID, newStatus) == true
	end
	if currentGroupChanged then
		return
	end
	local declined = newStatus == "declined"
		or newStatus == "declined_full"
		or newStatus == "declined_delisted"
	if apply and type(apply.IsDeclinedApplication) == "function" then
		declined = apply:IsDeclinedApplication(resultID) == true
	end
	if declined and not self:ShouldProcessSearchUpdates() then
		if self:HasRefreshableBrowseSource() then
			self._clientFiltersDirty = true
		end
		return
	end
	local freshReject = declined and apply and apply.IsFreshReject
		and apply:IsFreshReject(resultID) == true
	if declined and not freshReject then
		self:ApplyClientFilters()
		return
	end
	local stillJoined = newStatus == "invited"
		or newStatus == "inviteaccepted"
	if hadJoinedProjection and not stillJoined and not declined then
		-- Releasing inviteaccepted removes the temporary bypass used by the
		-- departed-row projection.  Re-run every ordinary filter immediately;
		-- repainting alone would leave friend/guild/cross-faction rows visible.
		self:ApplyClientFilters()
		return
	end
	local canUpdate = resultID ~= nil and self.scrollList ~= nil
	if not canUpdate then
		return
	end
	local repinned = self:RepinForApplication(resultID)
	local row = self:FindRowByResultID(resultID)
	local renderer = GF.ListRow
	if not repinned and row and renderer then
		renderer:ApplyApplicationState(row, resultID)
		renderer:UpdateRowBackgrounds(row)
	end
	if freshReject then
		self:ApplyClientFilters()
	end
end

function Panel:SignUp()
	if self.selectedResult and GF.Apply and GF.Apply.ShowDialogForIndex then
		GF.Apply:ShowDialogForIndex(self.selectedResult, self.selectedResultID)
	end
end

function Panel:Show()
	if self.parent then
		self.parent:Show()
	end
end

function Panel:Hide()
	if self.parent then
		self.parent:Hide()
	end
end
