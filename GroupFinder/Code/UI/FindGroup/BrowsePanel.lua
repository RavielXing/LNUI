local _, GF = ...

local Panel = {}
GF.BrowsePanel = Panel

local Presenter = assert(GF.BrowsePresenter,
	"BrowsePresenter must load before BrowsePanel")
local ControlsPresenter = assert(GF.BrowseControlsPresenter,
	"BrowseControlsPresenter must load before BrowsePanel")
Presenter:BindView(Panel)
local BrowseList = GF.BrowseScrollList
local REDACTED_NAME = "|Kr0|k"
local BLOCKLIST_RETIRE_SECONDS = GF.BROWSE_BLOCKLIST_RETIRE_SECONDS or 0.28
local EXPIRED_RETIRE_GRAY_SECONDS =
	GF.BROWSE_EXPIRED_RETIRE_GRAY_SECONDS or 0.30
local EXPIRED_RETIRE_FADE_SECONDS =
	GF.BROWSE_EXPIRED_RETIRE_FADE_SECONDS or 0.50

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

local function clearReusableTable(values)
	values = type(values) == "table" and values or {}
	for key in pairs(values) do
		values[key] = nil
	end
	return values
end

local function selectionFilterContext(selection)
	local spec = selection
		and ControlsPresenter:ResolveFilterSpec(selection) or nil
	return spec,
		spec and ControlsPresenter:GetFilterClient(spec) or nil,
		ControlsPresenter:GetFilterGlobal(spec)
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
	local iconWidth = GF.BROWSE_LOADING_ICON_WIDTH or 25
	local iconHeight = GF.BROWSE_LOADING_ICON_HEIGHT or 25
	local gap = GF.BROWSE_LOADING_ICON_GAP or 6
	animation:SetSize(iconWidth * count + gap * math.max(0, count - 1), iconHeight)
	animation.icons = {}
	for position = 1, count do
		local icon = animation:CreateTexture(nil, "ARTWORK")
		local atlas = (GF.BROWSE_LOADING_TEAMUP_ATLASES or {})[position]
		if not GF.UI.SetAtlasFit(icon, atlas, iconWidth, iconHeight) then
			icon:SetAtlas(atlas)
			icon:SetSize(iconWidth, iconHeight)
		end
		icon:SetPoint(
			"CENTER",
			animation,
			"LEFT",
			(iconWidth / 2) + (position - 1) * (iconWidth + gap),
			0
		)
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

function Panel:UpdateEmptyPromptLayout(showLoading, showAction)
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
	elseif showAction then
		y = ((GF.PANEL_BUTTON_H or 24) + (GF.BROWSE_EMPTY_ACTION_GAP or 10)) / 2
	end
	self.empty:ClearAllPoints()
	self.empty:SetPoint("CENTER", anchor, "CENTER", 0, y)
	if self.emptyActionButton then
		self.emptyActionButton:ClearAllPoints()
		if showAction then
			self.emptyActionButton:SetPoint(
				"TOP",
				self.empty,
				"BOTTOM",
				0,
				-(GF.BROWSE_EMPTY_ACTION_GAP or 10)
			)
		end
	end
end

function Panel:ConfigureQuickCreateButton(button, action)
	if not button then
		return
	end
	if type(action) ~= "table" then
		button:Hide()
		return
	end
	button:SetText(action.label or "")
	local fontString = button.GetFontString and button:GetFontString()
	local minimumWidth = GF.BROWSE_EMPTY_ACTION_MIN_WIDTH or 120
	local maximumWidth = GF.BROWSE_EMPTY_ACTION_MAX_WIDTH or 160
	local horizontalPadding = GF.BROWSE_EMPTY_ACTION_HORIZONTAL_PADDING or 28
	local naturalWidth
	if fontString then
		fontString._gfFitWidth = nil
		fontString._gfFitMinSize = nil
		if GF.Font and GF.Font.ApplyToFontString then
			GF.Font.ApplyToFontString(
				fontString,
				fontString._gfFontTemplate or "GameFontNormal")
		end
		local measure = fontString.GetUnboundedStringWidth
			or fontString.GetStringWidth
		if type(measure) == "function" then
			local ok, width = pcall(measure, fontString)
			if ok then
				naturalWidth = tonumber(width)
			end
		end
	end
	local desiredWidth = naturalWidth
		and math.ceil(naturalWidth + horizontalPadding) or minimumWidth
	desiredWidth = math.max(minimumWidth, math.min(maximumWidth, desiredWidth))
	button:SetWidth(desiredWidth)
	if fontString and GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(
			fontString,
			desiredWidth - horizontalPadding,
			9
		)
	end
	button:SetEnabled(action.enabled ~= false)
	button:Show()
end

function Panel:SetEmptyAction(action)
	self._emptyAction = type(action) == "table" and action or nil
	self:ConfigureQuickCreateButton(self.emptyActionButton, self._emptyAction)
end

function Panel:SetEmptyPrompt(text, showLoading, action)
	if not self.empty then
		return
	end
	local hasText = type(text) == "string" and text ~= ""
	if not hasText then
		self.empty:Hide()
		self:SetEmptyAction(nil)
		self:SetLoadingAnimationShown(false)
		return
	end
	local animate = showLoading == true
	local showAction = not animate and type(action) == "table"
	self:ApplyEmptyPromptStyle()
	self:SetEmptyAction(showAction and action or nil)
	self:UpdateEmptyPromptLayout(animate, showAction)
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
	if self.scrollList and type(self.scrollList.ForEachFrame) == "function"
		and type(visitor) == "function"
	then
		self.scrollList:ForEachFrame(visitor)
	end
end

function Panel:FindRowByResultID(resultID)
	if not (resultID and self.scrollList) then
		return nil, nil
	end
	local key = BrowseList and BrowseList.GetResultProjectionKey
		and BrowseList.GetResultProjectionKey(resultID) or resultID
	local row = self.scrollList:FindFrameByKey(key)
	return row, row and row.resultIndex or nil
end

function Panel:SetSelectedRow(row)
	return Presenter:SetSelectedRow(self, row)
end

function Panel:ClearSelectionForResultID(resultID)
	return Presenter:ClearSelection(self, resultID)
end

local function rowOwnsBrowseElement(row, elementData)
	if not row then
		return false
	end
	if type(row.GetElementData) ~= "function" then
		-- Test/fallback frames without the native accessor are dedicated to the
		-- supplied element for the duration of the request.
		return true
	end
	local ok, current = pcall(row.GetElementData, row)
	return ok and current == elementData
end

function Panel:ClearFailedResultBinding(resultID, elementData)
	local pending = self._failedResultBindings
	local request = resultID and pending and pending[resultID]
	if request and (elementData == nil or request.elementData == elementData) then
		pending[resultID] = nil
	end
end

function Panel:CancelFailedResultBindings()
	self._failedResultBindings = nil
	self._failedResultBindingScheduled = nil
	self._failedResultBindingDispatch =
		(tonumber(self._failedResultBindingDispatch) or 0) + 1
end

function Panel:IsFailedResultBindingCurrent(request)
	if type(request) ~= "table"
		or self.gfOwnsSearch ~= true
		or self._searchToken ~= request.searchToken
		or self.activeSearchKey ~= request.searchKey
	then
		return false
	end
	if self.GetSelectionKey and self:GetSelectionKey() ~= request.searchKey then
		return false
	end
	local result = GF.Result
	local resultID = request.resultID
	if not (result and result.GetIndexForResultID
		and result:GetIndexForResultID(resultID))
	then
		return false
	end
	local cache = self._browseElementCache
	local elementData = request.elementData
	return type(cache) == "table"
		and type(cache.byResultID) == "table"
		and cache.byResultID[resultID] == elementData
		and elementData._gfBrowseProjection == request.projection
end

function Panel:FlushFailedResultBindings(dispatch)
	if dispatch ~= self._failedResultBindingDispatch then
		return
	end
	self._failedResultBindingScheduled = nil
	local pending = self._failedResultBindings or {}
	self._failedResultBindings = {}
	local resultSetChanged = false
	for _, request in pairs(pending) do
		if self:IsFailedResultBindingCurrent(request) then
			local rebound = false
			if rowOwnsBrowseElement(request.row, request.elementData)
				and BrowseList and BrowseList.BindResultRow
			then
				rebound = BrowseList.BindResultRow(
					request.row,
					request.elementData,
					self,
					{ suppressRecovery = true }
				) == true
			end
			if not rebound then
				local result = GF.Result
				local index = result and result.GetIndexForResultID
					and result:GetIndexForResultID(request.resultID)
				local entry = index and result.GetEntry
					and result:GetEntry(index) or nil
				-- A recycled/offscreen frame no longer represents a visible blank.
				-- Keep a drawable cached element so its next native initialization
				-- can bind normally.  A visible retry failure or a still-unreadable
				-- element cannot satisfy the one-element/one-row invariant and is
				-- removed from both the result sequence and provider projection.
				local frameStillOwnsElement = rowOwnsBrowseElement(
					request.row, request.elementData)
				local shouldDrop = frameStillOwnsElement
					or not (entry and entry.info)
				if shouldDrop and self:DropUnrenderableResult(request.resultID) then
					resultSetChanged = true
				end
			end
		end
	end
	if resultSetChanged then
		self:RefreshList({
			preserveScroll = true,
			forceRebuild = true,
		})
	end
end

function Panel:QueueFailedResultBinding(row, elementData)
	local resultID = type(elementData) == "table"
		and elementData.resultID or nil
	if resultID == nil or not self.activeSearchKey then
		return false
	end
	local pending = self._failedResultBindings or {}
	self._failedResultBindings = pending
	pending[resultID] = {
		resultID = resultID,
		row = row,
		elementData = elementData,
		projection = elementData._gfBrowseProjection,
		searchToken = self._searchToken,
		searchKey = self.activeSearchKey,
	}
	if self._failedResultBindingScheduled == true then
		return true
	end
	if not (C_Timer and type(C_Timer.After) == "function") then
		pending[resultID] = nil
		return false
	end
	self._failedResultBindingScheduled = true
	self._failedResultBindingDispatch =
		(tonumber(self._failedResultBindingDispatch) or 0) + 1
	local dispatch = self._failedResultBindingDispatch
	C_Timer.After(0, function()
		Panel:FlushFailedResultBindings(dispatch)
	end)
	return true
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
		if clickedRow._gfDebugResultPreview == true
			or clickedRow._gfCensoredDebugPreview == true
		then
			return
		end
		if clickedRow._gfBlocklistRetiring == true then
			return
		end
		if clickedRow._gfExpiredRetiring == true then
			return
		end
		if clickedRow._gfCurrentGroupProjection == true then
			if mouseButton == "RightButton" and GF.RowContextMenu then
				GF.RowContextMenu:ShowForRow(clickedRow)
			end
			return
		end
		if Panel:DismissSoftUnavailableRow(clickedRow) then
			return
		end
		if mouseButton == "LeftButton"
			and Panel:IsRevealApplySuppressed(clickedRow.resultID)
		then
			return
		end
		if mouseButton == "LeftButton"
			and Panel:IsCensoredTitleClick(clickedRow)
		then
			Panel:RevealCensoredResultFromRow(clickedRow)
			return
		end
		if mouseButton == "LeftButton"
			and Panel:IsCensoredCommentPlaceholderClick(clickedRow)
		then
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

function Panel:IsRevealApplySuppressed(resultID)
	return resultID ~= nil
		and self._revealApplySuppressResultID == resultID
		and (self._revealApplySuppressUntil or 0) > GetTime()
end

local function isCursorInsideColumn(row, columnID)
	if not (row and row._columnLayout) then
		return false
	end
	local column = row._columnLayout.byId and row._columnLayout.byId[columnID]
	if not (column and type(GetCursorPosition) == "function"
		and row.GetLeft and row.GetEffectiveScale)
	then
		return false
	end
	local cursorX = GetCursorPosition()
	local scale = row:GetEffectiveScale() or 1
	local left = row:GetLeft()
	if not (cursorX and left and scale > 0) then
		return false
	end
	cursorX = cursorX / scale
	local columnLeft = left + (column.x or 0)
	return cursorX >= columnLeft
		and cursorX <= columnLeft + (column.width or 0)
end

function Panel:IsCensoredTitleClick(row)
	return row and row._isCensored == true
		and isCursorInsideColumn(row, "title") or false
end

function Panel:IsCensoredCommentPlaceholderClick(row)
	return row and row._isCensored == true
		and isCursorInsideColumn(row, "comment") or false
end

function Panel:WireRowClicks()
	self:ForEachVisibleRow(function(row)
		self:WireOneRow(row)
	end)
end

-- Native update coalescing -------------------------------------------------

function Panel:CancelRaidProgressRefresh()
	stopTimer(self, "_raidProgressRefreshTimer")
	self._raidProgressRefreshRequest = nil
end

local function canRefreshRaidProgress(panel)
	local parent = panel.parent
	if not parent then return false end
	if parent.IsVisible then
		if not parent:IsVisible() then return false end
	elseif not parent:IsShown() then return false end
	local snapshot = GF.SearchResultSnapshot
	return panel.scrollList
		and snapshot and snapshot.IsSeasonRaidContext(panel.selection)
		and not panel.awaitingGFSearch and panel.activeSearchKey
		and panel.activeSearchKey == panel:GetSelectionKey()
end

function Panel:RefreshRaidProgressRows()
	local renderer = GF.ListRow
	if not (renderer and renderer.RepaintRowState) then return end
	self:ForEachVisibleRow(function(row)
		if row._gfBrowseActionRow or row._gfExpiredRetiring then return end
		local entry
		if row._gfCurrentGroupProjection and row._gfCurrentGroupElement then
			entry = row._gfCurrentGroupElement.entry
		elseif row.resultID and GF.Result then
			local index = GF.Result:GetIndexForResultID(row.resultID)
			entry = index and GF.Result:GetEntry(index)
			if entry then row.resultIndex = index end
		end
		if not entry then return end
		renderer:RepaintRowState(row, entry, row.categoryID)
		local tooltip, tips = GameTooltip, GF.ListTooltip
		if tooltip and tips and tooltip:IsShown() and tooltip:IsOwned(row) then
			if row._gfCurrentGroupProjection and tips.ShowCurrentGroupProjection then
				tips:ShowCurrentGroupProjection(tooltip, row._gfCurrentGroupElement, row)
			elseif tips.Show then
				tips:Show(tooltip, row.resultID, row)
			end
		end
	end)
end

function Panel:RequestRaidProgressRefresh(delay)
	if not canRefreshRaidProgress(self) or not (C_Timer and C_Timer.NewTimer) then return end
	local repository = GF.ResultRepository
	local revision = repository and repository:GetSourceRevision()
	local due = currentTime() + math.max(0, delay or 0)
	local pending = self._raidProgressRefreshRequest
	if pending and pending.revision == revision and pending.token == self._searchToken
		and pending.key == self.activeSearchKey and pending.due <= due then return end
	self:CancelRaidProgressRefresh()
	local request = { revision = revision, token = self._searchToken,
		key = self.activeSearchKey, due = due }
	self._raidProgressRefreshRequest = request
	self._raidProgressRefreshTimer = C_Timer.NewTimer(math.max(0, due - currentTime()), function()
		if self._raidProgressRefreshRequest ~= request then return end
		self._raidProgressRefreshTimer = nil
		self._raidProgressRefreshRequest = nil
		if not canRefreshRaidProgress(self) or request.token ~= self._searchToken
			or request.key ~= self.activeSearchKey
			or repository and request.revision ~= repository:GetSourceRevision() then return end
		-- Rebuild display projections only; never search, sort or invalidate the
		-- remote kill snapshots. Include retained current-group projections.
		self:RefreshRaidProgressRows()
	end)
end

function Panel:CancelRowUpdateTimer()
	stopTimer(self, "_rowUpdateTimer")
end

function Panel:CancelRefreshTimer()
	stopTimer(self, "_refreshDebounce")
	self:CancelRaidProgressRefresh()
	self:CancelRowUpdateTimer()
	if type(self._pendingRowUpdates) == "table" then
		clearReusableTable(self._pendingRowUpdates)
	end
	if type(self._rowUpdateScratch) == "table"
		and self._rowUpdateScratch ~= self._pendingRowUpdates
	then
		clearReusableTable(self._rowUpdateScratch)
	end
	self._pendingRowUpdates = nil
	self._rowUpdateScratch = nil
	local listFilter = GF.ListFilter
	if self._rowUpdateFilterPass and listFilter
		and type(listFilter.ReleasePassContext) == "function"
	then
		listFilter:ReleasePassContext(self._rowUpdateFilterPass)
	end
	self._rowUpdateFilterPass = nil
	if type(self._rowUpdateFilterContext) == "table" then
		clearReusableTable(self._rowUpdateFilterContext)
	end
	self._pendingFullRefresh = nil
	self._refreshToken = (self._refreshToken or 0) + 1
end

function Panel:LockAutomaticResultOrder(resultID, reason)
	if resultID == nil then
		return
	end
	reason = reason or "retained_row"
	self._automaticResultOrderLocks = self._automaticResultOrderLocks or {}
	local resultLocks = self._automaticResultOrderLocks[resultID] or {}
	resultLocks[reason] = true
	self._automaticResultOrderLocks[resultID] = resultLocks
end

function Panel:ReleaseAutomaticResultOrder(resultID, reason)
	local locks = self._automaticResultOrderLocks
	if locks and resultID ~= nil then
		local resultLocks = locks[resultID]
		if resultLocks and reason ~= nil then
			resultLocks[reason] = nil
			if next(resultLocks) == nil then
				locks[resultID] = nil
			end
		else
			locks[resultID] = nil
		end
	end
end

function Panel:ClearAutomaticResultOrderLocks()
	if self.CancelExpiredResultRetirements then
		self:CancelExpiredResultRetirements(false)
	end
	self._automaticResultOrderLocks = nil
end

function Panel:HasAutomaticResultOrderLock()
	local locks = self._automaticResultOrderLocks
	if not locks then
		return false
	end
	for resultID in pairs(locks) do
		if GF.Result and GF.Result.IsFrozenResult
			and GF.Result:IsFrozenResult(resultID)
		then
			return true
		end
		locks[resultID] = nil
	end
	return false
end

function Panel:HasAutomaticResultOrderLockFor(resultID, reason)
	local locks = self._automaticResultOrderLocks
	local resultLocks = locks and locks[resultID]
	if not resultLocks then
		return false
	end
	return reason == nil or resultLocks[reason] == true
end

function Panel:ShouldProcessSearchUpdates()
	if not self.scrollList then
		return false
	end
	local mainController = GF.MainFrame
	if mainController and mainController.IsUserVisible then
		if not mainController:IsUserVisible() then
			return false
		end
	else
		local mainFrame = mainController and mainController.frame
		if not (mainFrame and mainFrame:IsShown()) then
			return false
		end
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
	if self.activeSearchKey ~= self:GetSelectionKey() then
		return
	end
	if GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget(self.selection) then
		-- A filtered-out result can acquire its leaderName after RESULTS_RECEIVED.
		-- Reconcile native membership, not only the currently visible/frozen rows.
		if self:ShouldProcessSearchUpdates() then
			self:RequestRefreshResults({ preserveScroll = true, automaticResultUpdate = true })
		else self._resultsDirty, self._pendingFullRefresh = true, true end
		return
	end
	local membership = GF.Search and GF.Search.RevalidateAggregatedResult
		and GF.Search:RevalidateAggregatedResult(resultID) or nil
	if membership == "removed" then
		self._resolvedResultToken = nil
		self:UpdateSearchHint()
		if self:ShouldProcessSearchUpdates() then
			self:RequestRefreshResults({
				preserveScroll = true,
				automaticResultUpdate = true,
			})
		else
			self._resultsDirty = true
			self._pendingFullRefresh = true
		end
		return
	end
	local resultState = GF.Result
	local belongsToSnapshot = resultState and resultState:IsFrozenResult(resultID)
	if not belongsToSnapshot then
		return
	end
	local pending = self._pendingRowUpdates
	if type(pending) ~= "table" then
		pending = clearReusableTable(self._rowUpdateScratch)
		self._rowUpdateScratch = nil
	end
	pending[resultID] = true
	self._pendingRowUpdates = pending
	if self:ShouldProcessSearchUpdates() then
		self:ScheduleRowUpdates()
	else
		self._resultsDirty = true
	end
end

local function stageMissingFrozenResults(panel, previousIDs, currentIDs)
	local currentSet = {}
	for _, resultID in ipairs(currentIDs or {}) do
		currentSet[resultID] = true
	end
	for _, resultID in ipairs(previousIDs or {}) do
		if not currentSet[resultID]
			and GF.Result and GF.Result.IsFrozenResult
			and GF.Result:IsFrozenResult(resultID)
		then
			local entry = GF.Result.entryCache
				and GF.Result.entryCache[resultID]
			local info = entry and entry.info
				or (GF.Result.sortInfoCache
					and GF.Result.sortInfoCache[resultID])
			local protected = GF.Result.ShouldPreserveExpiredResult
				and GF.Result:ShouldPreserveExpiredResult(
					resultID, info) == true
			if not protected then
				panel:SoftInvalidateResult(resultID, info)
			end
		end
	end
end

function Panel:OnSearchResultsUpdated()
	if self.awaitingGFSearch then
		-- UPDATE can arrive before RESULTS_RECEIVED has committed the aggregate.
		-- Keep the restricted request single-shot and remember that its native
		-- store must be read once more before the transaction is completed.
		if GF.Search and GF.Search.MarkNativeResultsDirty then
			GF.Search:MarkNativeResultsDirty()
		end
		return
	end
	if not self.gfOwnsSearch or not self.activeSearchKey then
		return
	end
	if self.activeSearchKey ~= self:GetSelectionKey() then
		return
	end
	local hasAggregate = false
	if GF.Search and GF.Search.GetAggregatedResultIDs then
		local aggregate = GF.Search:GetAggregatedResultIDs()
		if aggregate then
			hasAggregate = true
			local previousIDs = {}
			for index, resultID in ipairs(aggregate) do
				previousIDs[index] = resultID
			end
			-- Aggregate results are a projection of the one native result store.
			-- A full update can add, remove, or reorder IDs after the first receive
			-- event, so reconcile the complete store rather than only hydrating IDs
			-- that happened to be unreadable in the first snapshot.
			local changed = GF.Search.ReconcileAggregatedResults
				and GF.Search:ReconcileAggregatedResults() or false
			if not changed then
				return
			end
			-- A native full update can omit an expired listing without first
			-- emitting a usable per-result payload. Stage those previously visible
			-- identities before RefreshCache snapshots the reconciled aggregate, so
			-- the order lock can carry the gray/fade transition across that refresh.
			local gateway = GF.NativeSearchGateway
			local useFiltered = self.committedSearchQuery ~= nil
				and self.committedSearchQuery ~= ""
			local nativeIDs, readOK
			if gateway and gateway.ReadResults then
				local _, resultIDs, succeeded = gateway:ReadResults(useFiltered)
				nativeIDs, readOK = resultIDs, succeeded
			end
			if readOK == true then
				-- Reconcile can also remove a formerly unreadable result once its
				-- activity proves out of scope. Only an identity absent from the
				-- native store is expired; an in-store out-of-scope identity leaves
				-- immediately without being misrepresented as a gray retirement.
				stageMissingFrozenResults(self, previousIDs, nativeIDs)
			end
		end
	end
	if not hasAggregate then
		local gateway = GF.NativeSearchGateway
		local previousIDs = GF.Result
			and (GF.Result.frozenOrder or GF.Result.resultIDs) or nil
		local useFiltered = self.committedSearchQuery ~= nil
			and self.committedSearchQuery ~= ""
		local currentIDs, readOK
		if gateway and gateway.ReadResults then
			local _, resultIDs, succeeded = gateway:ReadResults(useFiltered)
			currentIDs, readOK = resultIDs, succeeded
		end
		if readOK == true then
			stageMissingFrozenResults(self, previousIDs, currentIDs)
		end
	end
	self._resolvedResultToken = nil
	self:UpdateSearchHint()
	if self:ShouldProcessSearchUpdates() then
		self._resultsDirty = false
		self._pendingFullRefresh = nil
		self:RequestRefreshResults({
			preserveScroll = true,
			automaticResultUpdate = true,
		})
	else
		self._resultsDirty = true
		self._pendingFullRefresh = true
	end
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
	if self.CancelExpiredResultRetirement then
		self:CancelExpiredResultRetirement(resultID, false, true)
	end
	self:ClearSelectionForResultID(resultID)
	self:ReleaseAutomaticResultOrder(resultID)
	return GF.Result:RemoveFromFrozen(resultID)
end

function Panel:DropUnrenderableResult(resultID)
	if self.CancelExpiredResultRetirement then
		self:CancelExpiredResultRetirement(resultID, false, true)
	end
	self:ClearSelectionForResultID(resultID)
	self:ReleaseAutomaticResultOrder(resultID)
	local result = GF.Result
	if result and result.RemoveProjectedResult then
		return result:RemoveProjectedResult(resultID)
	end
	return result and result.RemoveFromFrozen
		and result:RemoveFromFrozen(resultID) or false
end

local function dropExpiredResult(panel, resultID)
	local result = GF.Result
	if result and result.IsFrozenResult
		and result:IsFrozenResult(resultID) == true
	then
		return panel:DropFrozenResult(resultID)
	end
	return panel:DropUnrenderableResult(resultID)
end

function Panel:GetExpiredResultRetirement(resultID)
	return resultID ~= nil and self._expiredResultRetirements
		and self._expiredResultRetirements[resultID] or nil
end

function Panel:IsExpiredResultRetiring(resultID)
	return self:GetExpiredResultRetirement(resultID) ~= nil
end

local function repaintExpiredRetiringRows(panel)
	local retirements = panel._expiredResultRetirements or {}
	panel:ForEachVisibleRow(function(row)
		local retirement = row and row.resultID
			and retirements[row.resultID] or nil
		if retirement and row._gfCurrentGroupProjection ~= true
			and row._gfBlocklistRetiring ~= true
		then
			local entry = GF.Result and GF.Result.entryCache
				and GF.Result.entryCache[row.resultID]
			if entry and GF.ListRow and GF.ListRow.RepaintRowState then
				GF.ListRow:RepaintRowState(row, entry, row.categoryID)
			end
			if GF.ListRow and GF.ListRow.PlayExpiredRemovalFade then
				GF.ListRow:PlayExpiredRemovalFade(row, retirement)
			end
		elseif row and row._gfExpiredRetiring
			and GF.ListRow and GF.ListRow.ResetExpiredRemovalFade
		then
			GF.ListRow:ResetExpiredRemovalFade(row)
		end
	end)
end

local function nextExpiredRetirementDeadline(panel)
	local deadline
	for _, retirement in pairs(panel._expiredResultRetirements or {}) do
		if retirement.finishAt ~= nil
			and (deadline == nil or retirement.finishAt < deadline)
		then
			deadline = retirement.finishAt
		end
	end
	return deadline
end

local scheduleExpiredRetirementTimer

local function removeExpiredRetirementRecord(panel, resultID, retainGray)
	local retirements = panel._expiredResultRetirements
	local retirement = retirements and retirements[resultID]
	if not retirement then
		return nil
	end
	retirements[resultID] = nil
	if next(retirements) == nil then
		panel._expiredResultRetirements = nil
	end
	panel:ReleaseAutomaticResultOrder(resultID, "expired_retirement")
	if retainGray == true and GF.Result and GF.Result.IsFrozenResult
		and GF.Result:IsFrozenResult(resultID)
	then
		panel:LockAutomaticResultOrder(resultID, "soft_unavailable")
	end
	return retirement
end

function Panel:FinishExpiredResultRetirements(effectiveNow)
	self._expiredRetireTimer = nil
	self._expiredRetireDeadline = nil
	local retirements = self._expiredResultRetirements
	if not retirements then
		return false
	end
	local now = math.max(currentTime(), tonumber(effectiveNow) or 0)
	local due = {}
	local stale = {}
	for resultID, retirement in pairs(retirements) do
		if retirement.searchToken ~= self._searchToken
			or retirement.searchKey ~= self.activeSearchKey
		then
			stale[#stale + 1] = resultID
		elseif (retirement.finishAt or 0) <= now + 0.001 then
			due[#due + 1] = resultID
		end
	end
	for _, resultID in ipairs(stale) do
		removeExpiredRetirementRecord(self, resultID, false)
	end
	local changed = false
	if #due > 0 and GF.Result and GF.Result.InvalidateAsyncJobs then
		GF.Result:InvalidateAsyncJobs()
	end
	for _, resultID in ipairs(due) do
		local entry = GF.Result and GF.Result.entryCache
			and GF.Result.entryCache[resultID]
		local info = entry and entry.info
			or (GF.Result and GF.Result.sortInfoCache
				and GF.Result.sortInfoCache[resultID])
		local protected = GF.Result and GF.Result.ShouldRetainExpiredResult
			and GF.Result:ShouldRetainExpiredResult(resultID, info) == true
		if protected then
			removeExpiredRetirementRecord(self, resultID, true)
		else
			removeExpiredRetirementRecord(self, resultID, false)
			changed = dropExpiredResult(self, resultID) or changed
		end
	end
	if changed and self.scrollList then
		self:RefreshList({ preserveScroll = true })
	else
		repaintExpiredRetiringRows(self)
	end
	if self._expiredResultRetirements then
		scheduleExpiredRetirementTimer(self)
	end
	return changed
end

scheduleExpiredRetirementTimer = function(panel)
	stopTimer(panel, "_expiredRetireTimer")
	local deadline = nextExpiredRetirementDeadline(panel)
	panel._expiredRetireDeadline = deadline
	if deadline == nil then
		return
	end
	panel._expiredRetireToken = (panel._expiredRetireToken or 0) + 1
	local token = panel._expiredRetireToken
	local delay = math.max(0, deadline - currentTime())
	local function finish()
		if Panel._expiredRetireToken ~= token then
			return
		end
		Panel:FinishExpiredResultRetirements(deadline)
	end
	if delay > 0 and C_Timer and type(C_Timer.NewTimer) == "function" then
		panel._expiredRetireTimer = C_Timer.NewTimer(delay, finish)
	else
		finish()
	end
end

function Panel:CancelExpiredResultRetirement(
	resultID, retainGray, skipReschedule)
	if not removeExpiredRetirementRecord(self, resultID, retainGray) then
		return false
	end
	local row = self:FindRowByResultID(resultID)
	if row and GF.ListRow and GF.ListRow.ResetExpiredRemovalFade then
		GF.ListRow:ResetExpiredRemovalFade(row)
		local entry = GF.Result and GF.Result.entryCache
			and GF.Result.entryCache[resultID]
		if entry and GF.ListRow.RepaintRowState then
			GF.ListRow:RepaintRowState(row, entry, row.categoryID)
		end
	end
	if skipReschedule ~= true then
		scheduleExpiredRetirementTimer(self)
	end
	return true
end

function Panel:CancelExpiredResultRetirements(retainGray)
	stopTimer(self, "_expiredRetireTimer")
	self._expiredRetireToken = (self._expiredRetireToken or 0) + 1
	self._expiredRetireDeadline = nil
	local retirements = self._expiredResultRetirements
	if not retirements then
		return false
	end
	local resultIDs = {}
	for resultID in pairs(retirements) do
		resultIDs[#resultIDs + 1] = resultID
	end
	for _, resultID in ipairs(resultIDs) do
		removeExpiredRetirementRecord(self, resultID, retainGray)
	end
	repaintExpiredRetiringRows(self)
	return #resultIDs > 0
end

function Panel:RetireExpiredResult(resultID)
	local result = GF.Result
	if result and result.InvalidateAsyncJobs then
		result:InvalidateAsyncJobs()
	end
	return dropExpiredResult(self, resultID)
end

function Panel:BeginExpiredResultRetirement(resultID, info, options)
	options = options or {}
	local result = GF.Result
	if not (resultID and result and result.MarkSoftUnavailable) then
		return false
	end
	local existing = self:GetExpiredResultRetirement(resultID)
	if existing then
		result:MarkSoftUnavailable(resultID, info, {
			confirmedUnavailable = true,
			transientRetirement = true,
		})
		if options.deferVisual ~= true then
			repaintExpiredRetiringRows(self)
		end
		return true
	end
	if result.InvalidateAsyncJobs and options.skipInvalidation ~= true then
		result:InvalidateAsyncJobs()
	end
	self:LockAutomaticResultOrder(resultID, "expired_retirement")
	self:ReleaseAutomaticResultOrder(resultID, "soft_unavailable")
	local entry = result:MarkSoftUnavailable(resultID, info, {
		confirmedUnavailable = true,
		transientRetirement = true,
	})
	if not entry then
		self:ReleaseAutomaticResultOrder(resultID, "expired_retirement")
		return self:RetireExpiredResult(resultID)
	end
	local startedAt = currentTime()
	local graySeconds = options.alreadyGray == true
		and 0 or EXPIRED_RETIRE_GRAY_SECONDS
	local retirement = {
		resultID = resultID,
		startedAt = startedAt,
		graySeconds = graySeconds,
		fadeSeconds = EXPIRED_RETIRE_FADE_SECONDS,
		finishAt = startedAt + graySeconds + EXPIRED_RETIRE_FADE_SECONDS,
		searchToken = self._searchToken,
		searchKey = self.activeSearchKey,
	}
	self._expiredResultRetirements = self._expiredResultRetirements or {}
	self._expiredResultRetirements[resultID] = retirement
	self:ClearSelectionForResultID(resultID)
	if GF.RowContextMenu and GF.RowContextMenu.CloseForResult then
		GF.RowContextMenu:CloseForResult(resultID)
	end
	if options.deferVisual ~= true then
		repaintExpiredRetiringRows(self)
	end
	if options.deferSchedule ~= true then
		scheduleExpiredRetirementTimer(self)
	end
	return true
end

function Panel:SoftInvalidateResult(resultID, info)
	if not (resultID and GF.Result and GF.Result.MarkSoftUnavailable) then
		return false
	end
	if GF.Result.ShouldPreserveExpiredResult
		and GF.Result:ShouldPreserveExpiredResult(resultID, info) == true
	then
		return false
	end
	local retainResult = GF.Result.ShouldRetainExpiredResult
		and GF.Result:ShouldRetainExpiredResult(resultID, info)
	if retainResult == nil and GF.Result.ShouldRetainExpiredGroups then
		retainResult = GF.Result:ShouldRetainExpiredGroups()
	end
	if retainResult == false then
		local handled = self:BeginExpiredResultRetirement(resultID, info)
		return self:IsExpiredResultRetiring(resultID)
			and false or handled
	end
	local entry = GF.Result:MarkSoftUnavailable(resultID, info, {
		confirmedUnavailable = true,
	})
	if not entry then
		return self:DropFrozenResult(resultID)
	end
	self:LockAutomaticResultOrder(resultID, "soft_unavailable")
	self:ClearSelectionForResultID(resultID)
	local row = self:FindRowByResultID(resultID)
	if row and GF.ListRow and GF.ListRow.RepaintRowState then
		GF.ListRow:RepaintRowState(row, entry, row.categoryID)
	end
	return false
end

function Panel:ApplyExpiredGroupMode()
	local resultState = GF.Result
	if not (resultState and resultState.ShouldRetainExpiredGroups) then
		return false
	end
	if resultState:ShouldRetainExpiredGroups() == true then
		return self:CancelExpiredResultRetirements(true)
	end
	local order = resultState.frozenOrder or resultState.resultIDs
	if type(order) ~= "table" then
		return false
	end
	local expired = {}
	for _, resultID in ipairs(order) do
		local entry = resultState.entryCache and resultState.entryCache[resultID]
		local info = entry and entry.info
			or (resultState.sortInfoCache and resultState.sortInfoCache[resultID])
		local currentGroup = info and GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(info, resultID) == true
		local protectedResult = resultState.ShouldRetainExpiredResult
			and resultState:ShouldRetainExpiredResult(resultID, info) == true
		local softUnavailable = not currentGroup
			and not protectedResult
			and ((resultState.ShouldSoftUnavailableResult
				and resultState:ShouldSoftUnavailableResult(resultID, info) == true)
				or (not resultState.ShouldSoftUnavailableResult
					and resultState.IsSoftUnavailable
					and resultState:IsSoftUnavailable(info) == true))
		local retainedSoftUnavailable = self.HasAutomaticResultOrderLockFor
			and not currentGroup
			and not protectedResult
			and self:HasAutomaticResultOrderLockFor(
				resultID, "soft_unavailable") == true
		if (softUnavailable or retainedSoftUnavailable)
			and not self:IsExpiredResultRetiring(resultID)
		then
			expired[#expired + 1] = resultID
		end
	end
	if #expired == 0 then
		return false
	end
	if resultState.InvalidateAsyncJobs then
		resultState:InvalidateAsyncJobs()
	end
	local staged = false
	for _, resultID in ipairs(expired) do
		local entry = resultState.entryCache
			and resultState.entryCache[resultID]
		local info = entry and entry.info
			or (resultState.sortInfoCache
				and resultState.sortInfoCache[resultID])
		staged = self:BeginExpiredResultRetirement(resultID, info, {
			alreadyGray = true,
			deferVisual = true,
			deferSchedule = true,
			skipInvalidation = true,
		}) or staged
	end
	if staged then
		repaintExpiredRetiringRows(self)
		scheduleExpiredRetirementTimer(self)
	end
	return staged
end

function Panel:PreserveAutomaticOrderForFrozenGrayRows()
	local resultState = GF.Result
	local order = resultState and (resultState.frozenOrder or resultState.resultIDs)
	if type(order) ~= "table" then
		return false
	end
	for _, resultID in ipairs(order) do
		local entry = resultState.entryCache and resultState.entryCache[resultID]
		local info = entry and entry.info
			or (resultState.sortInfoCache and resultState.sortInfoCache[resultID])
		if resultState.IsSoftUnavailable
			and resultState:IsSoftUnavailable(info)
			and (not resultState.ShouldRetainExpiredGroups
				or resultState:ShouldRetainExpiredGroups() == true)
		then
			self:LockAutomaticResultOrder(resultID, "soft_unavailable")
			return true
		end
		local applicationState = GF.Apply and GF.Apply.GetApplicationState
			and GF.Apply:GetApplicationState(resultID, info)
		if applicationState and applicationState.isApplication == true
			and applicationState.isActiveApp ~= true
		then
			self:LockAutomaticResultOrder(resultID, "terminal_application")
			return true
		end
	end
	return false
end

function Panel:UpdateRowByResultID(resultID, suppliedInfo, updateContext)
	if not (resultID and GF.Result:IsFrozenResult(resultID)) then
		return false, "stale"
	end
	local previousEntry = GF.Result.entryCache and GF.Result.entryCache[resultID]
	local previousInfo = previousEntry and previousEntry.info
		or (GF.Result.sortInfoCache and GF.Result.sortInfoCache[resultID])
	local row, index = self:FindRowByResultID(resultID)
	local filterSpec = GF.FilterSpec
	local blocklistActive = filterSpec and filterSpec.HasActiveBlocklist
		and filterSpec:HasActiveBlocklist() == true

	local info, state = suppliedInfo, suppliedInfo and "supplied" or nil
	if not info then
		info, state = GF.Result:GetLiveSearchResultInfoForUpdate(resultID)
	end
	if not info then
		if previousInfo and GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(previousInfo, resultID)
		then
			return false, "kept"
		end
		if state == "not_current" then
			return false, "stale"
		end
		return self:SoftInvalidateResult(resultID), "soft_unavailable"
	end

	local invalid = GF.Result:GetSearchResultInvalidReason(resultID, info)
	if invalid and invalid ~= "dirty" then
		if invalid == "unavailable" then
			return self:SoftInvalidateResult(resultID, info), "soft_unavailable"
		end
		return self:DropFrozenResult(resultID), "invalid"
	end
	if invalid == "dirty" then
		if not GF.Result:GetCachedSearchResultInfo(resultID) then
			return self:DropFrozenResult(resultID), "invalid"
		end
		if not GF.Result:IsLiveSearchResultInfoAuthoritative(resultID) then
			return false, "stale"
		end
	end
	if self:IsExpiredResultRetiring(resultID) then
		self:CancelExpiredResultRetirement(resultID, false)
		if type(info) == "table" then
			pcall(rawset, info, "_gfSoftUnavailable", nil)
		end
	end

	local currentGroup = GF.CurrentGroupProjection
	local updatesCurrentGroup = currentGroup ~= nil
		and type(currentGroup.MatchesResult) == "function"
		and currentGroup:MatchesResult(resultID, info) == true
	local entry, refreshState = GF.Result:RefreshEntryInfo(resultID, info, {
		availabilityChecked = true,
		hydrateMissing = row ~= nil or previousEntry ~= nil
			or blocklistActive or updatesCurrentGroup,
	})
	if not entry and refreshState ~= "summary" then
		local reason = GF.Result:GetSearchResultInvalidReason(resultID, info)
		if reason == "unavailable" then
			return self:SoftInvalidateResult(resultID, info), "soft_unavailable"
		end
		return self:DropFrozenResult(resultID), "invalid"
	end
	local blocklist = GF.Blocklist
	if blocklistActive and blocklist
		and blocklist:ShouldHide(resultID, info, entry)
	then
		return self:DropFrozenResult(resultID), "filtered"
	end

	if not (row and index) then
		if entry ~= nil and updatesCurrentGroup then
			-- The native duplicate is hidden behind the current-group virtual row.
			-- Hydrate its invalidated counts before asking the provider to republish
			-- that projection; ordinary offscreen updates remain repaint-free.
			if type(GF.Result.EnsureMemberCounts) == "function" then
				GF.Result:EnsureMemberCounts(entry)
			end
			return true, "current_group"
		end
		return false, "kept"
	end
	local spec, client, database, listFilterPass
	if type(updateContext) == "table" then
		spec = updateContext.spec
		client = updateContext.client
		database = updateContext.database
		listFilterPass = updateContext.listFilterPass
	else
		spec, client, database = selectionFilterContext(self.selection)
	end
	local rejectionFeedback = GF.Apply and GF.Apply.HasRejectionFeedback
		and GF.Apply:HasRejectionFeedback(resultID)
	if not rejectionFeedback and GF.ListFilter
		and not GF.ListFilter:ShouldShowResult(
			resultID,
			entry,
			spec,
			client,
			database,
			info,
			listFilterPass)
	then
		return self:DropFrozenResult(resultID), "filtered"
	end
	if GF.ListRow and GF.ListRow.RepaintRowState then
		GF.ListRow:RepaintRowState(row, entry, row.categoryID)
	end
	-- Automatic result metadata updates preserve the established baseline order.
	-- The target row was repainted above, so a list-wide repaint would only repeat
	-- visible-row hydration and member enumeration. Return true only from branches
	-- that actually removed an element and therefore changed the projection.
	return false, "kept"
end

function Panel:RevealCensoredResultFromRow(row)
	local resultID = row and row.resultID
	if not (resultID and row._isCensored == true
		and self.gfOwnsSearch and self.activeSearchKey
		and self.activeSearchKey == self:GetSelectionKey()
		and GF.Result and GF.Result:IsFrozenResult(resultID))
	then
		return false
	end
	local searchToken = self._searchToken
	local searchKey = self.activeSearchKey
	self._revealApplySuppressResultID = resultID
	self._revealApplySuppressUntil = GetTime() + 0.4

	local info, state = GF.Result:RevealCensoredSearchResult(resultID)
	if self._searchToken ~= searchToken
		or self.activeSearchKey ~= searchKey
		or searchKey ~= self:GetSelectionKey()
		or not GF.Result:IsFrozenResult(resultID)
	then
		return false
	end
	if state ~= "revealed" and state ~= "not_censored" then
		if state == "missing" and self:DropFrozenResult(resultID) then
			self:RefreshList({ preserveScroll = true })
		end
		return state == "censored" or state == "unsupported"
	end

	local blocklist = GF.Blocklist
	if state == "revealed" and blocklist
		and blocklist.IndexRevealedSearchResult
	then
		blocklist:IndexRevealedSearchResult(resultID, info)
	end
	local _, outcome = self:UpdateRowByResultID(resultID, info)
	if outcome == "filtered" then
		self:RefreshList({ preserveScroll = true })
		if GF.ShowWarningMessage then
			local locale = GF.L or {}
			GF.ShowWarningMessage(locale.CENSORED_RESULT_FILTERED_OUT
				or "该队伍在显示内容后不符合当前筛选条件")
		end
	elseif outcome == "invalid" then
		self:RefreshList({ preserveScroll = true })
	end
	return true
end

function Panel:ResortBrowseResults()
	if not (self.gfOwnsSearch and self.activeSearchKey and GF.Result)
	then
		return false
	end
	-- Specialization and other live metadata changes repaint the established
	-- baseline.  Only an explicit user search/refresh/filter/header sort may
	-- rebuild the whole order.
	if self:ShouldProcessSearchUpdates() then
		self:RefreshList({ preserveScroll = true })
	else
		self._resultsDirty = true
		self._pendingRoleResort = true
	end
	return true
end

function Panel:OnPlayerSpecializationChanged()
	if GF.Result and GF.Result.InvalidateRoleSortCache then
		GF.Result:InvalidateRoleSortCache()
	end
	if not (self.gfOwnsSearch and self.activeSearchKey) then
		return
	end
	if not self:ShouldProcessSearchUpdates() then
		self._resultsDirty = true
		self._pendingRoleResort = true
		return
	end
	self:ResortBrowseResults()
end

function Panel:FlushPendingRowUpdates()
	self._resultsDirty = false
	if not (self._pendingRowUpdates and next(self._pendingRowUpdates)
		and self.scrollList)
	then
		return
	end
	if not self.gfOwnsSearch or not self.activeSearchKey then
		clearReusableTable(self._pendingRowUpdates)
		self._pendingRowUpdates = nil
		return
	end
	local updates = self._pendingRowUpdates
	local incoming = self._rowUpdateScratch
	if incoming == updates then
		incoming = nil
	end
	incoming = clearReusableTable(incoming)
	self._pendingRowUpdates = incoming
	self._rowUpdateScratch = nil
	local resultState = GF.Result
	if resultState and resultState.BeginActivityInfoReadPass then
		resultState:BeginActivityInfoReadPass()
	end
	local updateContext = clearReusableTable(self._rowUpdateFilterContext)
	self._rowUpdateFilterContext = updateContext
	updateContext.spec, updateContext.client, updateContext.database =
		selectionFilterContext(self.selection)
	local listFilter = GF.ListFilter
	local needsListFilter = listFilter
		and type(listFilter.NeedsPostFilters) == "function"
		and listFilter:NeedsPostFilters(
			updateContext.spec,
			updateContext.client,
			updateContext.database) == true
	if needsListFilter and type(listFilter.CreatePassContext) == "function" then
		self._rowUpdateFilterPass = listFilter:CreatePassContext(
			updateContext.spec,
			updateContext.client,
			updateContext.database,
			self._rowUpdateFilterPass)
		updateContext.listFilterPass = self._rowUpdateFilterPass
	elseif self._rowUpdateFilterPass and listFilter
		and type(listFilter.ReleasePassContext) == "function"
	then
		self._rowUpdateFilterPass =
			listFilter:ReleasePassContext(self._rowUpdateFilterPass)
	end
	local projectionChanged = false
	for resultID in pairs(updates) do
		projectionChanged = self:UpdateRowByResultID(
			resultID, nil, updateContext)
			or projectionChanged
	end
	if updateContext.listFilterPass and listFilter
		and type(listFilter.ReleasePassContext) == "function"
	then
		self._rowUpdateFilterPass = listFilter:ReleasePassContext(
			updateContext.listFilterPass)
	end
	clearReusableTable(updateContext)
	clearReusableTable(updates)
	self._rowUpdateScratch = updates
	if resultState and resultState.EndActivityInfoReadPass then
		resultState:EndActivityInfoReadPass()
	end
	if not projectionChanged then
		local diagnostics = GF.SearchMemoryDiagnostics
		if diagnostics and diagnostics.RecordDelayedUpdates then
			local count = resultState and resultState.resultIDs
				and #resultState.resultIDs or 0
			diagnostics:RecordDelayedUpdates(count)
		end
		return
	end
	self:RefreshList({ preserveScroll = true })
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
		local entry = resultState.entryCache and resultState.entryCache[resultID]
		local info = entry and entry.info
			or (resultState.GetCachedSearchResultInfo
				and resultState:GetCachedSearchResultInfo(resultID))
		if info and blocklist:ShouldHide(resultID, info, entry) then
			changed = self:DropFrozenResult(resultID) or changed
		end
	end
	if changed then
		self:RefreshList({ preserveScroll = true })
	end
end

function Panel:IsBlocklistResultRetiring(resultID)
	return resultID ~= nil
		and self._blocklistRetiringIDs ~= nil
		and self._blocklistRetiringIDs[resultID] == true
end

local function repaintBlocklistRetiringRows(panel, retiring)
	local hasVisibleMatch = false
	panel:ForEachVisibleRow(function(row)
		local matched = row
			and row._gfCurrentGroupProjection ~= true
			and row.resultID
			and retiring[row.resultID] == true
		if matched then
			hasVisibleMatch = true
		end
		if row and GF.ListRow then
			if matched and GF.ListRow.BeginBlocklistRetirement then
				GF.ListRow:BeginBlocklistRetirement(row)
			elseif not matched and row._gfBlocklistRetiring
				and GF.ListRow.ClearBlocklistRetirement
			then
				GF.ListRow:ClearBlocklistRetirement(row)
			end
		end
	end)
	return hasVisibleMatch
end

function Panel:RetireHiddenByBlocklist(preferredResultID)
	if not (self.scrollList and self.activeSearchKey) then
		return false
	end
	local blocklist = GF.Blocklist
	if not (blocklist and blocklist.IsEnabled and blocklist:IsEnabled()) then
		return false
	end
	local resultState = GF.Result
	local order = resultState and (resultState.frozenOrder or resultState.resultIDs)
	if type(order) ~= "table" or next(order) == nil then
		return false
	end
	local retiring = self._blocklistRetiringIDs or {}
	local found = false
	for _, resultID in ipairs(order) do
		local entry = resultState.entryCache and resultState.entryCache[resultID]
		local info = entry and entry.info
			or (resultState.GetCachedSearchResultInfo
				and resultState:GetCachedSearchResultInfo(resultID))
		local matched = info
			and blocklist:ShouldHide(resultID, info, entry) == true
		if matched or resultID == preferredResultID then
			retiring[resultID] = true
			found = true
		end
	end
	if not found then
		return false
	end

	stopTimer(self, "_blocklistRetireTimer")
	self._blocklistRetiringIDs = retiring
	self._blocklistRetireToken = (self._blocklistRetireToken or 0) + 1
	local token = self._blocklistRetireToken
	local searchToken = self._searchToken
	local searchKey = self.activeSearchKey
	repaintBlocklistRetiringRows(self, retiring)

	local function finishRetirement()
		if Panel._blocklistRetireToken ~= token then
			return
		end
		Panel._blocklistRetireTimer = nil
		local active = Panel._blocklistRetiringIDs or {}
		Panel._blocklistRetiringIDs = nil
		if Panel._searchToken ~= searchToken
			or Panel.activeSearchKey ~= searchKey
		then
			repaintBlocklistRetiringRows(Panel, {})
			return
		end
		local changed = false
		for resultID in pairs(active) do
			changed = Panel:DropFrozenResult(resultID) or changed
		end
		if changed then
			Panel:RefreshList({ preserveScroll = true })
		else
			repaintBlocklistRetiringRows(Panel, {})
		end
	end

	if BLOCKLIST_RETIRE_SECONDS > 0 and C_Timer
		and type(C_Timer.NewTimer) == "function"
	then
		self._blocklistRetireTimer = C_Timer.NewTimer(
			BLOCKLIST_RETIRE_SECONDS, finishRetirement)
	else
		finishRetirement()
	end
	return true
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
	Presenter:ClearResultCaches(true)
	panel:RefreshResults({ preserveScroll = true })
	return true
end

function Panel:OnBrowseShown()
	self:CancelListenHoldTimer()
	self:RequestRaidProgressRefresh(0)
	local expired = self._listenHoldExpired
	local reapplyClientFilters = self._clientFiltersDirty == true
	self._clientFiltersDirty = nil
	local resumedSearch = self:ResumeSearchListening()
	if self._resultsDirty then
		self._resultsDirty = false
		if self._pendingFullRefresh then
			self._pendingFullRefresh = nil
			self:RequestRefreshResults({
				preserveScroll = true,
				automaticResultUpdate = true,
			})
			reapplyClientFilters = false
		elseif self._pendingRoleResort then
			self._pendingRoleResort = nil
			if self._pendingRowUpdates and next(self._pendingRowUpdates) then
				self:FlushPendingRowUpdates()
			else
				self:ResortBrowseResults()
			end
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
	self:EndRaidLeaderLookup()
	self:CancelRaidProgressRefresh()
	if self._censoredDebugPreview == true then
		self:ClearCensoredDebugPreview({ restore = false })
	end
	if self._teamListDebugPreview == true then
		self:ClearTeamListDebugPreview({ restore = false })
	end
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
	if GF.Apply and GF.Apply.ClearRejectionFeedback then
		if GF.Apply:ClearRejectionFeedback() and retainsResults then
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
		local forceResort = self._pendingRefreshOpts
			and self._pendingRefreshOpts.forceResort == true
		local pending = {}
		for key, value in pairs(options) do pending[key] = value end
		-- A later result event must not suppress a user-requested relationship sort.
		if forceResort then pending.forceResort = true end
		self._pendingRefreshOpts = pending
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

function Panel:GetSearchCapability(selection, options)
	options = type(options) == "table" and options or {}
	return ControlsPresenter:ProjectSearchCapability(GF.SubtitleBar, {
		panel = self,
		selection = selection,
		searching = options.searching == true,
	})
end

function Panel:CanStartSelectionSearch(selection, options)
	local capability = self:GetSearchCapability(selection, options)
	return capability.allowed, capability.reason
end

function Panel:NotifySelectionSearchBlocked(_reason)
	self:ScheduleSearchCooldownUI()
	self:UpdateSearchHint()
end

function Panel:IsSearchPending()
	return Presenter:IsSearchPending(self)
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

function Panel:RelayoutVisibleRows()
	local hidden = self.parent and not self.parent:IsShown()
	if hidden or not self.scrollList then
		return false
	end
	if not (BrowseList and BrowseList.RelayoutVisible) then
		return false
	end
	-- Header OnSizeChanged runs continuously while the resize handle is
	-- moving. Keep this path projection-only: rebuilding the viewport or
	-- committing a signature on every mouse step makes virtual rows churn.
	BrowseList.RelayoutVisible(self)
	return true
end

function Panel:RelayoutRows()
	local hidden = self.parent and not self.parent:IsShown()
	if hidden or self._frameResizing == true or GF._frameResizing == true then
		return
	end
	self:CancelRelayoutDebounce()
	self:RelayoutVisibleRows()
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
	box:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, GF.CONTENT_SCROLL_INSET_B or 0)
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
	self._hasCurrentGroupProjection = nil
	self._resolvedResultToken = nil

	local scrollBox
	self.scrollList, scrollBox = createBrowseScroll(self, parent)
	self._scrollLastW, self._scrollLastH = 0, 0
	scrollBox:HookScript("OnSizeChanged", function(box, width, height)
		local dynamic = Panel.scrollList and Panel.scrollList.dynamicScrollBar
		if dynamic and dynamic.applying then return end
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
	self.scrollList:BindDynamicContentScrollBar(parent, function(width)
		local subtitle = GF.SubtitleBar
		if subtitle and subtitle.columnHeaderBar and GF.ColumnHeaderBar then
			-- Initialize columns at the reserved width without rebuilding the viewport.
			GF.ColumnHeaderBar:Layout(subtitle.columnHeaderBar, width)
			subtitle:AnchorHeaderRefreshButton()
		end
		Panel:RelayoutVisibleRows()
	end, { reserveGutter = true })

	self.empty = createEmptyLabel(parent, scrollBox)
	self:ApplyEmptyPromptStyle()
	self.empty:Hide()
	self.emptyActionButton = GF.UI.CreatePanelButton(
		parent,
		"",
		GF.BROWSE_EMPTY_ACTION_MIN_WIDTH or 120
	)
	self.emptyActionButton:SetScript("OnClick", function()
		Panel:ExecuteEmptyAction()
	end)
	self.emptyActionButton:Hide()
	self.emptyAnchor = scrollBox
	if GF.RaidLeaderLookupView then self.leaderLookupView = GF.RaidLeaderLookupView.Create(self, parent) end
end

function Panel:IsSearchableSelection(node)
	return Presenter:IsSearchableSelection(self, node)
end

function Panel:GetSelectionKey(node)
	return Presenter:GetSelectionKey(self, node)
end

function Panel:GetDisplayedResultCount()
	return Presenter:GetDisplayedResultCount(self)
end

function Panel:HasBrowseList()
	return Presenter:HasBrowseList(self)
end

function Panel:HasRefreshableBrowseSource()
	return Presenter:HasRefreshableBrowseSource(self)
end

function Panel:CanManualRefresh()
	return Presenter:HasRefreshableBrowseSource(self)
end

function Panel:IsCompletedSearchProjectionCurrent()
	return Presenter:IsCompletedSearchProjectionCurrent(self)
end

function Panel:BuildQuickCreateAction(kind, label, placement, activityID)
	return Presenter:BuildQuickCreateAction(
		self, kind, label, placement, activityID)
end

function Panel:BuildEmptyAction(kind, label, activityID)
	return Presenter:BuildEmptyAction(self, kind, label, activityID)
end

function Panel:ResolveCompletedEmptyState(displayedCount)
	return Presenter:ResolveCompletedEmptyState(self, displayedCount)
end

function Panel:ResolveCompletedResultAction(displayedCount)
	return Presenter:ResolveCompletedResultAction(self, displayedCount)
end

function Panel:IsEmptyActionCurrent(action)
	return Presenter:IsEmptyActionCurrent(self, action)
end

function Panel:IsResultActionCurrent(action)
	return Presenter:IsResultActionCurrent(self, action)
end

function Panel:ExecuteQuickCreateAction(action)
	return Presenter:ExecuteQuickCreateAction(self, action)
end

function Panel:ExecuteEmptyAction()
	return Presenter:ExecuteEmptyAction(self)
end

function Panel:ExecuteResultAction(action)
	return Presenter:ExecuteResultAction(self, action)
end

function Panel:UpdateResultsChrome(count)
	return Presenter:UpdateResultsChrome(self, count)
end

function Panel:UpdateSearchHint()
	return Presenter:UpdateSearchHint(self)
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
end

function Panel:ResetBrowseScroll()
	if self.scrollList then
		self.scrollList:ScrollToBegin()
	end
end

function Panel:DetachBrowseSearch()
	self:DiscardManualDeclineRefresh()
	self._clientFiltersDirty = nil
	self:ClearAutomaticResultOrderLocks()
	if GF.Apply and GF.Apply.ClearRejectionFeedback then
		GF.Apply:ClearRejectionFeedback()
	end
	if GF.Result and GF.Result.InvalidateAsyncJobs then
		GF.Result:InvalidateAsyncJobs()
	end
	self.activeSearchKey = nil
	self.gfOwnsSearch = false
	self._resolvedResultToken = nil
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

function Panel:ClearRowDisplay(options)
	options = options or {}
	self:CancelRefreshTimer()
	self:CancelFailedResultBindings()
	self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
	self.totalResultCount, self._displayedResultCount = 0, 0
	self._hasCurrentGroupProjection = nil
	self._resolvedResultToken = nil
	self._listOrderSig = nil
	self._censoredDebugPreview = nil
	self._censoredDebugEntry = nil
	self._teamListDebugPreview = nil
	self._teamListDebugEntries = nil
	local list = self.scrollList
	if list then
		list:SetElements({})
	end
	if options.preserveElementCache ~= true then
		self._browseElementCache = nil
	end
	local resultState = GF.Result
	if resultState and resultState.ClearFrozenSnapshot then
		resultState:ClearFrozenSnapshot()
	end
	self:ResetBrowseScroll()
	self:SetEmptyPrompt(nil)
	Presenter:ClearResultCaches(false)
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
	self._resolvedResultToken = nil
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

function Panel:EndRaidLeaderLookup(preserveResults)
	local target = GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget(self.selection)
	if not target then return false end
	local selection = target.baseNode
	if preserveResults then
		-- Keep the completed search identity and native application row, but
		-- release the leader restriction immediately. The next user search uses
		-- ordinary filters; no replacement search or navigation is needed.
		selection = {}
		for key, value in pairs(self.selection) do
			if key ~= "_gfRaidLeaderLookup" then selection[key] = value end
		end
	end
	self:SetSelection(selection, { preserveBrowseResults = preserveResults == true })
	if GF.SubtitleBar then GF.SubtitleBar:ApplyBrowseInteractionState() end
	return true
end

function Panel:SetSelection(node, options)
	options = options or {}
	local previous = self.selection
	local previousKey = self:GetSelectionKey(previous)
	local nextKey = node and self:GetSelectionKey(node) or nil
	if previous and previous._gfRaidLeaderLookup and previousKey ~= nextKey then
		self:ResetBrowsePage()
	end
	if previous and previous._gfQuestSearch == true
		and previousKey ~= nextKey
	then
		local preserved = options.preserveQuestSearchText == true
			and GF.Search
			and GF.Search.ReleaseNativeQuestSearchForKeyword
			and GF.Search:ReleaseNativeQuestSearchForKeyword() == true
		if not preserved and GF.Search and GF.Search.ClearNativeQuestSearch then
			GF.Search:ClearNativeQuestSearch()
		end
	end
	self.selection = node
	local key = self:GetSelectionKey(node)
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
	if self.leaderLookupView then self.leaderLookupView:Refresh() end
end

function Panel:UpdateTitle()
	if not (GF.SubtitleBar and GF.SubtitleBar.SetCategoryLabel) then
		return
	end
	GF.SubtitleBar:SetCategoryLabel(
		Presenter:ProjectSelectionLabel(self.selection))
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
	if self:GetDisplayedResultCount() > 0
		and self.activeSearchKey == self:GetSelectionKey()
	then
		self:RefreshList({ preserveScroll = true })
	else
		self:UpdateSearchHint()
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
		Panel._resolvedResultToken = nil
		Panel._searchFailed = true
		Panel._activeSearchContext = nil
		Panel:DiscardManualDeclineRefresh()
		if GF.Search and GF.Search.AbandonActiveRequest then
			GF.Search:AbandonActiveRequest()
		elseif GF.Search and GF.Search.Reset then
			GF.Search:Reset()
		end
		Panel:PauseSearchListening()
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
	if GF.Apply and GF.Apply.ClearRejectionFeedback then
		GF.Apply:ClearRejectionFeedback()
	end
	panel:ClearRowDisplay({ preserveElementCache = true })
	local subtitle = GF.SubtitleBar
	if panel.selection and panel.selection._gfQuestSearch == true then
		panel.committedSearchQuery = nil
	elseif subtitle and subtitle.GetEffectiveSearchText then
		panel.committedSearchQuery = subtitle:GetEffectiveSearchText()
	end
	if GF.MainFrame then
		GF.MainFrame:UpdateActivityCount(0)
		GF.MainFrame:UpdateBrowseStatusHint(nil)
	end
	panel:SetEmptyPrompt(nil)
end

local function resolveQuestKeywordTransition(panel)
	local selection = panel and panel.selection
	if not (selection and selection._gfQuestSearch == true) then
		return nil
	end
	local subtitle = GF.SubtitleBar
	local keyword = subtitle and subtitle.GetEffectiveSearchText
		and subtitle:GetEffectiveSearchText() or nil
	if type(keyword) ~= "string" or not keyword:match("%S") then
		return nil
	end
	local questSearch = GF.QuestSearch
	local target, visualNode
	if questSearch and questSearch.CreateKeywordSelection then
		target, visualNode = questSearch:CreateKeywordSelection(selection)
	end
	if not target then
		return nil
	end
	return {
		selection = target,
		visualNode = visualNode,
	}
end

local function applyQuestKeywordTransition(panel, transition)
	if not (panel and transition and transition.selection) then
		return false
	end
	local options = {
		suppressCreateDrawer = true,
		preserveQuestSearchText = true,
		questKeywordTransition = true,
	}
	local mainFrame = GF.MainFrame
	local changed
	if mainFrame and mainFrame.OnSelectionChanged then
		changed = mainFrame:OnSelectionChanged(
			transition.selection, options) == true
	else
		panel:SetSelection(transition.selection, options)
		changed = panel.selection == transition.selection
	end
	if not changed then
		return false
	end
	local visualNode = transition.visualNode
	if visualNode and GF.NavTree and GF.NavTree.SetSelectedSilently then
		local path
		if GF.NavTree.FindNodePathByKey then
			local canonical, foundPath = GF.NavTree:FindNodePathByKey(
				visualNode.key)
			if canonical then
				visualNode, path = canonical, foundPath
			end
		end
		GF.NavTree:SetSelectedSilently(visualNode, path)
	end
	return true
end

function Panel:DoSearch(options)
	options = options or {}
	local lookup = GF.RaidLeaderLookup
	local target = lookup and lookup:GetTarget(self.selection)
	if target then
		if not lookup:IsCurrent(target) then self:UpdateSearchHint(); return false end
		-- Clear the real native keyword, including a previous player-name query.
		if not (GF.NativeSearchGateway and GF.NativeSearchGateway:ClearText()) then
			self._searchFailed = true; self:UpdateSearchHint(); return false
		end
		self.committedSearchQuery = nil
	end
	if options.neteaseNewbieSearch ~= true then
		ControlsPresenter:PrepareAllGroupsSearch(self)
	end
	local questKeywordTransition = resolveQuestKeywordTransition(self)
	local candidateSelection = questKeywordTransition
		and questKeywordTransition.selection or self.selection
	local canStart, blockedReason = self:CanStartSelectionSearch(
		candidateSelection, options)
	if not canStart then
		self:NotifySelectionSearchBlocked(blockedReason)
		return false
	end
	if questKeywordTransition
		and not applyQuestKeywordTransition(self, questKeywordTransition)
	then
		self:NotifySelectionSearchBlocked("quest-keyword-transition-failed")
		return false
	end
	if self._censoredDebugPreview == true then
		self:ClearCensoredDebugPreview({ restore = false })
	end
	if self._teamListDebugPreview == true then
		self:ClearTeamListDebugPreview({ restore = false })
	end
	self:ClearAutomaticResultOrderLocks()
	local manualRefresh = questKeywordTransition == nil
		and options.manualRefresh == true
		and (options._gfManualRefreshConfirmed == true or self:CanManualRefresh())
	local capturedDeclines = options._gfCapturedDeclines
	if manualRefresh and options._gfManualRefreshConfirmed ~= true then
		options._gfManualRefreshConfirmed = true
		if GF.Apply
			and type(GF.Apply.SnapshotRejectedParties) == "function"
		then
			capturedDeclines = GF.Apply:SnapshotRejectedParties()
			options._gfCapturedDeclines = capturedDeclines
		end
	end
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
		self._resolvedResultToken = nil
		self._activeSearchContext = nil
		self:DiscardManualDeclineRefresh()
		self:EndSearchUI()
		local barrier = GF.Search and GF.Search.GetRequestBarrierRemaining
			and GF.Search:GetRequestBarrierRemaining() or 0
		local cooldown = GF.Search and GF.Search.GetCooldownRemaining
			and GF.Search:GetCooldownRemaining() or 0
		if math.max(barrier, cooldown) > 0 then
			self:ScheduleSearchCooldownUI()
			self:UpdateSearchHint()
			return false
		else
			self._searchFailed = true
			self:UpdateSearchHint()
		end
		return false
	end

	-- The full-update event can race ahead of RESULTS_RECEIVED.  Listen while
	-- the request is pending; OnSearchResultsUpdated only marks the source dirty
	-- until the initial aggregate has been captured.
	if GF.SetLfgUpdateListening then
		GF.SetLfgUpdateListening(true)
	end

	if type(GetTime) == "function" then
		self._lastSearchAt = GetTime()
	end
	self:ScheduleSearchCooldownUI()
	self:ScheduleSearchTimeout(token)
	return true
end

function Panel:ApplyClientFilters(options)
	options = options or {}
	if options.preserveOrder ~= true then
		self:ClearAutomaticResultOrderLocks()
	end
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
		if options.promoteCurrent == true
			and GF.Result.StablePromoteCurrentGroup
		then
			GF.Result:StablePromoteCurrentGroup()
		end
		self:RefreshList({ preserveScroll = true })
	end, options)
end

-- List rendering -----------------------------------------------------------

local function buildCensoredDebugEntry(panel)
	local L = GF.L or {}
	local categoryID = panel and panel.selection
		and panel.selection.categoryID or GF.CAT_CUSTOM or 6
	local activityID = GF.ACTIVITY_CUSTOM_PVE or 16
	local capacity = categoryID == GF.CAT_DUNGEON and 5 or 20
	return {
		info = {
			activityIDs = { activityID },
			censored = true,
			leaderName = L.DEBUG_CENSORED_BROWSE_LEADER or "Debug Leader",
			numMembers = 3,
			requiredItemLevel = 0,
			isDelisted = false,
		},
		activityID = activityID,
		activity = {
			categoryID = categoryID,
			fullName = L.DEBUG_CENSORED_BROWSE_ACTIVITY or "Debug Activity",
			shortName = L.DEBUG_CENSORED_BROWSE_ACTIVITY or "Debug Activity",
			maxNumPlayers = capacity,
		},
		categoryID = categoryID,
		tanks = 1,
		heals = 1,
		dps = 1,
		_displayCountsLoaded = true,
		_displayCounts = {
			TANK = 1,
			HEALER = 1,
			DAMAGER = 1,
		},
		players = {
			{ classFilename = "WARRIOR", assignedRole = "TANK" },
			{ classFilename = "DRUID", assignedRole = "HEALER" },
			{ classFilename = "PALADIN", assignedRole = "DAMAGER" },
		},
	}
end

function Panel:ShowCensoredDebugPreview()
	if not (GF.Debug and GF.Debug.IsDebugModeEnabled
		and GF.Debug:IsDebugModeEnabled() == true
		and self.scrollList and BrowseList.BuildCensoredDebugElements)
	then
		return false
	end
	if self._teamListDebugPreview == true then
		self:ClearTeamListDebugPreview({ restore = false })
	end
	self:CancelRefreshTimer()
	self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
	self._censoredDebugPreview = true
	self._hasCurrentGroupProjection = nil
	self._censoredDebugEntry = buildCensoredDebugEntry(self)
	self.totalResultCount, self._displayedResultCount = 1, 1
	self._listOrderSig = "censored-debug-preview"
	self:ResetBrowseScroll()
	self.scrollList:SetElements(BrowseList.BuildCensoredDebugElements(
		self._censoredDebugEntry,
		self._censoredDebugEntry.categoryID
	))
	self:SetEmptyPrompt(nil)
	if BrowseList.RelayoutVisible then
		BrowseList.RelayoutVisible(self)
	end
	refreshSignUpState()
	refreshFloatingStatus()
	self:UpdateResultsChrome(1)
	return true
end

function Panel:ShowTeamListDebugPreview()
	local provider = GF.TeamListTestData
	if not (GF.Debug and GF.Debug.IsDebugModeEnabled
		and GF.Debug:IsDebugModeEnabled() == true
		and provider and type(provider.BuildEntries) == "function"
		and self.scrollList and BrowseList.BuildTeamListDebugElements)
	then
		return false
	end
	if self._censoredDebugPreview == true then
		self:ClearCensoredDebugPreview({ restore = false })
	end
	local entries = provider:BuildEntries()
	if type(entries) ~= "table" or #entries == 0 then
		return false
	end
	self:CancelRefreshTimer()
	self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
	self._teamListDebugPreview = true
	self._teamListDebugEntries = entries
	self._hasCurrentGroupProjection = nil
	self.totalResultCount, self._displayedResultCount = #entries, #entries
	self._listOrderSig = "team-list-debug-preview"
	self:ResetBrowseScroll()
	self.scrollList:SetElements(
		BrowseList.BuildTeamListDebugElements(entries))
	self:SetEmptyPrompt(nil)
	if BrowseList.RelayoutVisible then
		BrowseList.RelayoutVisible(self)
	end
	refreshSignUpState()
	refreshFloatingStatus()
	self:UpdateResultsChrome(#entries)
	return true
end

function Panel:ClearTeamListDebugPreview(options)
	if self._teamListDebugPreview ~= true then
		return false
	end
	options = options or {}
	self._teamListDebugPreview = nil
	self._teamListDebugEntries = nil
	self._listOrderSig = nil
	local canRestore = options.restore ~= false
		and self.activeSearchKey ~= nil
		and self.activeSearchKey == self:GetSelectionKey()
	if canRestore then
		self:RefreshList({ forceRebuild = true })
	else
		self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
		self.totalResultCount, self._displayedResultCount = 0, 0
		self._hasCurrentGroupProjection = nil
		self.scrollList:SetElements({})
		self:SetEmptyPrompt(nil)
		refreshSignUpState()
		refreshFloatingStatus()
		self:UpdateResultsChrome(0)
	end
	return true
end

function Panel:ClearCensoredDebugPreview(options)
	if self._censoredDebugPreview ~= true then
		return false
	end
	options = options or {}
	self._censoredDebugPreview = nil
	self._censoredDebugEntry = nil
	self._listOrderSig = nil
	local canRestore = options.restore ~= false
		and self.activeSearchKey ~= nil
		and self.activeSearchKey == self:GetSelectionKey()
	if canRestore then
		self:RefreshList({ forceRebuild = true })
	else
		self._selectedRow, self.selectedResult, self.selectedResultID = nil, nil, nil
		self.totalResultCount, self._displayedResultCount = 0, 0
		self._hasCurrentGroupProjection = nil
		self.scrollList:SetElements({})
		self:SetEmptyPrompt(nil)
		refreshSignUpState()
		refreshFloatingStatus()
		self:UpdateResultsChrome(0)
	end
	return true
end

function Panel:RefreshList(options)
	return Presenter:RefreshList(self, options)
end

function Panel:RefreshResults(options)
	return Presenter:RefreshResults(self, options)
end

function Panel:RepinForApplication(resultID)
	if not (resultID and GF.Result and GF.Apply) then
		return false
	end
	self:CancelRefreshTimer()
	if not (GF.Result.StablePromoteApplication
		and GF.Result:StablePromoteApplication(resultID))
	then
		return false
	end
	if GF.Result.CommitSnapshot then
		GF.Result:CommitSnapshot()
	end
	Panel.totalResultCount = Presenter:GetResultCount()
	Panel:RefreshList({ preserveScroll = true, skipSnapshot = true })
	return true
end

local TERMINAL_APPLICATION_STATUS = {
	cancelled = true,
	failed = true,
	timedout = true,
	invitedeclined = true,
	declined = true,
	declined_full = true,
	declined_delisted = true,
}

local function isTerminalApplicationStatus(status)
	return status ~= nil and TERMINAL_APPLICATION_STATUS[status] == true
end

function Panel:OnApplicationStatusUpdated(resultID, newStatus)
	local apply = GF.Apply
	local cachedEntry = Presenter:GetCachedEntry(resultID)
	local hadJoinedProjection = (cachedEntry ~= nil
		and cachedEntry._gfJoinedApplicationSupplement == true)
		or (apply and type(apply.IsJoinedApplicationTracked) == "function"
			and apply:IsJoinedApplicationTracked(resultID) == true)
	-- RuntimeLifecycle has already delivered this event to ApplicationService.
	local declined = newStatus == "declined"
		or newStatus == "declined_full"
		or newStatus == "declined_delisted"
	if apply and type(apply.IsDeclinedApplication) == "function" then
		declined = apply:IsDeclinedApplication(resultID) == true
	end
	local terminalStatus = isTerminalApplicationStatus(newStatus)
	if terminalStatus then
		self:LockAutomaticResultOrder(resultID, "terminal_application")
		self:CancelExpiredResultRetirement(resultID, true)
	elseif not self:HasAutomaticResultOrderLockFor(
		resultID, "terminal_application")
	then
		self:ReleaseAutomaticResultOrder(resultID, "terminal_application")
	end
	if declined and not self:ShouldProcessSearchUpdates() then
		if self:HasRefreshableBrowseSource() then
			self._clientFiltersDirty = true
		end
		return
	end
	local rejectionFeedback = declined and apply and apply.HasRejectionFeedback
		and apply:HasRejectionFeedback(resultID) == true
	if declined and not rejectionFeedback then
		self:ApplyClientFilters({ preserveOrder = true })
		return
	end
	local stillJoined = newStatus == "invited"
		or newStatus == "inviteaccepted"
	if hadJoinedProjection and not stillJoined and not declined then
		-- Releasing inviteaccepted removes the temporary bypass used by the
		-- departed-row projection.  Re-run every ordinary filter immediately;
		-- repainting alone would leave friend/guild/cross-faction rows visible.
		self:ApplyClientFilters({
			preserveOrder = terminalStatus,
		})
		return
	end
	local canUpdate = resultID ~= nil and self.scrollList ~= nil
	if not canUpdate then
		return
	end
	if isTerminalApplicationStatus(newStatus) then
		-- A terminal application remains at its frozen result position.  Repaint
		-- the row in place and invalidate any already-yielded sort job; only an
		-- explicit search, refresh, or column sort may establish a new order.
		if GF.Result and GF.Result.InvalidateAsyncJobs then
			GF.Result:InvalidateAsyncJobs()
		end
		local row = self:FindRowByResultID(resultID)
		local renderer = GF.ListRow
		if row and renderer then
			renderer:ApplyApplicationState(row, resultID)
			renderer:UpdateRowBackgrounds(row)
		end
		if declined then
			self:ApplyClientFilters({ preserveOrder = true })
		end
		return
	end
	local repinned = self:RepinForApplication(resultID)
	local row = self:FindRowByResultID(resultID)
	local renderer = GF.ListRow
	if not repinned and row and renderer then
		renderer:ApplyApplicationState(row, resultID)
		renderer:UpdateRowBackgrounds(row)
	end
	if rejectionFeedback then
		self:ApplyClientFilters({ preserveOrder = true })
	end
end

function Panel:SignUp()
	if self.selectedResult and GF.Apply and GF.Apply.ShowDialogForIndex then
		GF.Apply:ShowDialogForIndex(self.selectedResult, self.selectedResultID)
	end
end

function Panel:Show()
	if GF.ApplicationService then GF.ApplicationService:ReconcileApplications(true) end
	if self.parent then
		self.parent:Show()
	end
end

function Panel:Hide()
	if self.parent then
		self.parent:Hide()
	end
end
