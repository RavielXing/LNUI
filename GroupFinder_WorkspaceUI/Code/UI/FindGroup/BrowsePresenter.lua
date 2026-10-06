local _, GF = ...
GF = GF.GF or GF

-- BrowsePresenter is the boundary between the GroupFinder search/result
-- services and the browse widgets.  Frames render the projection produced
-- here; they do not own the lifetime of result IDs or native search state.
local Presenter = {}
GF.BrowsePresenter = Presenter

local ID_SEPARATOR = "\31"
local viewState = setmetatable({}, { __mode = "k" })

-- These names remain readable on BrowsePanel for addon compatibility.  Their
-- storage lives in the presenter so old callers cannot create a second view
-- model beside the one used by the runtime.
local PRESENTATION_STATE_KEYS = {
	selection = true,
	workspaceContext = true,
	selectedResult = true,
	selectedResultID = true,
	_selectedRow = true,
	committedSearchQuery = true,
	activeSearchKey = true,
	gfOwnsSearch = true,
	awaitingGFSearch = true,
	_searchFailed = true,
	_searchToken = true,
	_resultToken = true,
	_resolvedResultToken = true,
	_activeSearchContext = true,
	totalResultCount = true,
	_displayedResultCount = true,
	_hasCurrentGroupProjection = true,
	_emptyAction = true,
	_listOrderSig = true,
	_browseElementCache = true,
	_censoredDebugPreview = true,
	_censoredDebugEntry = true,
	_teamListDebugPreview = true,
	_teamListDebugEntries = true,
}

local function stateFor(view)
	local state = viewState[view]
	if not state then
		state = {}
		viewState[view] = state
	end
	return state
end

function Presenter:BindView(view)
	if type(view) ~= "table" then
		return nil
	end
	local existing = getmetatable(view)
	if existing and existing._gfBrowsePresenter == self then
		return stateFor(view)
	end
	local state = stateFor(view)
	for key in pairs(PRESENTATION_STATE_KEYS) do
		local value = rawget(view, key)
		if value ~= nil then
			state[key] = value
			rawset(view, key, nil)
		end
	end
	local previousIndex = existing and existing.__index
	local previousNewIndex = existing and existing.__newindex
	local meta = {}
	if existing then
		for key, value in pairs(existing) do
			meta[key] = value
		end
	end
	meta._gfBrowsePresenter = self
	meta.__index = function(target, key)
		if PRESENTATION_STATE_KEYS[key] then
			return stateFor(target)[key]
		end
		if type(previousIndex) == "function" then
			return previousIndex(target, key)
		elseif type(previousIndex) == "table" then
			return previousIndex[key]
		end
		return nil
	end
	meta.__newindex = function(target, key, value)
		if PRESENTATION_STATE_KEYS[key] then
			stateFor(target)[key] = value
		elseif type(previousNewIndex) == "function" then
			previousNewIndex(target, key, value)
		elseif type(previousNewIndex) == "table" then
			previousNewIndex[key] = value
		else
			rawset(target, key, value)
		end
	end
	setmetatable(view, meta)
	return state
end

function Presenter:GetViewState(view)
	return type(view) == "table" and stateFor(view) or nil
end

local function resultRepository()
	local repository = GF.ResultRepository
	if repository then
		return repository
	end
	local facade = GF.Result
	if facade and type(facade.GetRepository) == "function" then
		local ok, resolved = pcall(facade.GetRepository, facade)
		if ok and resolved then
			return resolved
		end
	end
	return facade or {}
end

local function resultService()
	return GF.Result or resultRepository()
end

function Presenter:GetResultRepository()
	return resultRepository()
end

function Presenter:ClearResultCaches(includeSummaries)
	local repository = resultRepository()
	repository.entryCache = {}
	if includeSummaries == true then
		repository.sortInfoCache = {}
	end
end

function Presenter:GetResultCount()
	return #(resultRepository().resultIDs or {})
end

function Presenter:GetCachedEntry(resultID)
	local repository = resultRepository()
	return repository.entryCache and repository.entryCache[resultID] or nil
end

local function workspaceFor(view)
	if view and view.workspaceContext then
		return view.workspaceContext
	end
	local workspace = GF.LFGWorkspaceView
	if workspace and type(workspace.GetContext) == "function" then
		return workspace:GetContext() or {}
	end
	return {}
end

function Presenter:GetSelection(view)
	return view and view.selection or nil
end

function Presenter:GetSelectionKey(view, selection)
	local chosen = selection or self:GetSelection(view)
	local finder = GF.FindGroup
	if finder and type(finder.GetSelectionKey) == "function" then
		local key = finder:GetSelectionKey(chosen)
		if key ~= nil then
			return key
		end
	end
	return chosen and chosen.key or nil
end

function Presenter:IsSearchableSelection(view, selection)
	local finder = GF.FindGroup
	return finder ~= nil
		and type(finder.IsSearchableSelection) == "function"
		and finder:IsSearchableSelection(selection or self:GetSelection(view)) == true
end

function Presenter:ProjectSelectionLabel(selection)
	if type(selection) ~= "table" then
		return nil
	end
	if selection.activityID ~= nil and selection.customBucket ~= true then
		local activity = selection.activityInfo
		local snapshot = GF.SearchResultSnapshot
		local reader = snapshot and snapshot.GetActivityInfo
		if activity == nil and type(reader) == "function" then
			local ok, value = pcall(reader, nil, selection.activityID)
			if ok then
				activity = value
			end
		end
		local ui = GF.UI
		if ui and type(ui.GetCategoryTitle) == "function" then
			return ui.GetCategoryTitle(selection.categoryID, activity)
		end
	end
	return selection.label or ""
end

function Presenter:GetDisplayedResultCount(view)
	return tonumber(view and view._displayedResultCount) or 0
end

function Presenter:GetSelectedResult(view)
	return view and view.selectedResult or nil,
		view and view.selectedResultID or nil
end

function Presenter:IsSearchPending(view)
	local search = GF.Search
	local sessionPending = search and (search.inFlight == true
		or (search.session and search.session.state == "searching"))
	return sessionPending == true
		or (view and view.awaitingGFSearch == true)
		or GF.searching == true
end

function Presenter:GetResultIntroContext(view)
	return tostring(view and view._searchToken or "")
		.. ID_SEPARATOR
		.. tostring(view and view.activeSearchKey or "")
end

local function repaintSelection(row)
	local renderer = GF.ListRow
	if row and renderer and type(renderer.UpdateRowBackgrounds) == "function" then
		renderer:UpdateRowBackgrounds(row)
	end
end

local function notifySelectionChanged()
	local subtitle = GF.SubtitleBar
	if subtitle and type(subtitle.UpdateSignUpButtonState) == "function" then
		subtitle:UpdateSignUpButtonState()
	end
end

function Presenter:SetSelectedRow(view, row)
	if not view then
		return false
	end
	if row == view._selectedRow then
		view.selectedResult = row and row.resultIndex or nil
		view.selectedResultID = row and row.resultID or nil
		notifySelectionChanged()
		return false
	end
	if type(view.ForEachVisibleRow) == "function" then
		view:ForEachVisibleRow(function(candidate)
			if candidate._isSelected then
				candidate._isSelected = nil
				repaintSelection(candidate)
			end
		end)
	end
	view._selectedRow = row
	view.selectedResult = row and row.resultIndex or nil
	view.selectedResultID = row and row.resultID or nil
	if row then
		row._isSelected = true
		repaintSelection(row)
	end
	notifySelectionChanged()
	return true
end

function Presenter:ClearSelection(view, resultID)
	if not view then
		return false
	end
	local row = view._selectedRow
	if resultID ~= nil and (row == nil or row.resultID ~= resultID) then
		return false
	end
	if row then
		row._isSelected = nil
		repaintSelection(row)
	end
	view._selectedRow = nil
	view.selectedResult = nil
	view.selectedResultID = nil
	notifySelectionChanged()
	return row ~= nil
end

local function sequenceHasValue(sequence)
	return type(sequence) == "table" and next(sequence) ~= nil
end

function Presenter:HasBrowseList(view)
	if self:GetDisplayedResultCount(view) > 0
		or (view and view._hasCurrentGroupProjection == true)
	then
		return true
	end
	return view ~= nil
		and view.activeSearchKey ~= nil
		and view.activeSearchKey == self:GetSelectionKey(view)
		and (tonumber(view.totalResultCount) or 0) > 0
end

function Presenter:HasRefreshableBrowseSource(view)
	if not view or view.activeSearchKey == nil
		or view.activeSearchKey ~= self:GetSelectionKey(view)
	then
		return false
	end
	local repository = resultRepository()
	return sequenceHasValue(repository.apiResultIDs)
		or sequenceHasValue(repository.resultIDs)
		or sequenceHasValue(repository.frozenOrder)
end

local function canOfferRecruitmentEntry()
	local listing = GF.RecruitmentSession
	if listing == nil or type(listing.HasActive) ~= "function"
		or type(listing.CanPublish) ~= "function"
		or listing:HasActive() == true or listing:CanPublish() ~= true
	then
		return false
	end
	if type(listing.IsBusy) == "function" and listing:IsBusy() == true then
		return false
	end
	local availability = GF.Availability
	local readBlock = availability and availability.GetPremadeBlockMessage
	if type(readBlock) == "function" then
		local ok, message = pcall(readBlock, availability)
		if not ok or (message ~= nil and message ~= false) then
			return false
		end
	end
	if type(LFGListUtil_GetActiveQueueMessage) == "function" then
		local ok, message = pcall(LFGListUtil_GetActiveQueueMessage, false)
		if not ok or (message ~= nil and message ~= false) then
			return false
		end
	end
	return true
end

local function canCreateSelection(selection, workspaceID)
	if type(selection) ~= "table" or selection.browseOnly == true then
		return false
	end
	local workspace = GF.LFGWorkspaceView
	if workspace and type(workspace.CanCreateSelection) == "function" then
		return workspace:CanCreateSelection(selection, workspaceID) == true
	end
	local checker = GF.NavData and GF.NavData.CanCreateFromNode
	return type(checker) == "function" and checker(selection) == true
end

local function createActivityID(selection)
	local resolver = GF.NavData and GF.NavData.ResolveCreateActivityID
	if type(resolver) == "function" then
		return resolver(selection)
	end
	return selection and selection.categoryBrowse ~= true
		and selection.activityID or nil
end

local function isAggregateSelection(selection, workspaceID)
	if type(selection) ~= "table"
		or canCreateSelection(selection, workspaceID)
	then
		return false
	end
	if selection.categoryBrowse == true
		or (selection.groupID ~= nil and selection.activityID == nil)
	then
		return true
	end
	if #(selection.activityIDsFilter or {}) > 1
		or #(selection.resultActivityIDsFilter or {}) > 1
	then
		return true
	end
	return #(selection.children or {}) > 0
end

function Presenter:IsCompletedSearchProjectionCurrent(view)
	if not view or view.awaitingGFSearch == true
		or view._searchFailed == true or view.gfOwnsSearch ~= true
		or view.activeSearchKey == nil
		or view.activeSearchKey ~= self:GetSelectionKey(view)
		or view._resolvedResultToken ~= view._searchToken
	then
		return false
	end
	local context = view._activeSearchContext
	local search = GF.Search
	if type(context) ~= "table" or not search
		or type(search.MatchesContext) ~= "function"
		or search:MatchesContext(context) ~= true
	then
		return false
	end
	local workspace = workspaceFor(view)
	if context.key ~= nil and context.key ~= workspace.key then
		return false
	end
	if context.workspaceID ~= nil
		and context.workspaceID ~= workspace.workspaceID
	then
		return false
	end
	return context.generation == nil
		or context.generation == workspace.generation
end

function Presenter:BuildQuickCreateAction(view, kind, label, placement, activityID)
	local workspace = workspaceFor(view)
	local selection = self:GetSelection(view) or {}
	return {
		kind = kind,
		label = label,
		placement = placement,
		searchKey = view and view.activeSearchKey or nil,
		searchToken = view and view._searchToken or nil,
		workspaceKey = workspace.key,
		workspaceID = workspace.workspaceID,
		workspaceGeneration = workspace.generation,
		questID = selection.questID,
		activityID = activityID or selection.questActivityID,
		categoryID = selection.categoryID,
	}
end

function Presenter:BuildEmptyAction(view, kind, label, activityID)
	return self:BuildQuickCreateAction(
		view, kind, label, "empty", activityID)
end

local function isNewbieSearchActive(view)
	local service = GF.NetEaseIdentityService
	local filter = GF.MythicPlusBrowseFilter
	local finder = GF.FindGroup
	local selection = view and Presenter:GetSelection(view) or nil
	if not (service and service:IsEnabled() == true
		and finder
		and type(finder.IsNetEaseIdentityBrowseEnabled) == "function"
		and finder:IsNetEaseIdentityBrowseEnabled() == true
		and filter and filter:IsNewbieOnly() == true
		and type(selection) == "table"
		and selection.navKind == "season_dungeon")
	then
		return false
	end
	return true
end

local function newbieSearchProgressText(locale)
	locale = locale or {}
	return "|cffffd100"
		.. (locale.SEARCH_NETEASE_NEWBIE_PROGRESS_PREFIX or "正在筛选")
		.. "|r|cff00ff00"
		.. (locale.SEARCH_NETEASE_NEWBIE_PROGRESS_HIGHLIGHT or "包含新兵")
		.. "|r|cffffd100"
		.. (locale.SEARCH_NETEASE_NEWBIE_PROGRESS_SUFFIX or "的队伍")
		.. "|r"
end

local function resolveNewbieFilterEmptyState(view, locale)
	if not isNewbieSearchActive(view) then
		return nil
	end
	local service = GF.NetEaseIdentityService
	local serviceStatus = service:GetServiceStatus()
	if serviceStatus == "offline" or serviceStatus == "fault"
		or serviceStatus == "no_response"
	then
		return {
			text = locale.FILTER_NETEASE_UNCONFIRMED
				or "网易 API 当前不可用，玩家身份无法获取。",
		}
	end
	if service:IsQueryPending() == true then
		return {
			text = newbieSearchProgressText(locale),
			loading = true,
		}
	end
	return {
		text = locale.FILTER_NETEASE_NO_RESULTS
			or "没有查询到已确认包含新兵的队伍。",
	}
end

function Presenter:ResolveCompletedEmptyState(view, displayedCount)
	if tonumber(displayedCount) ~= 0
		or not self:IsCompletedSearchProjectionCurrent(view)
	then
		return nil
	end
	local locale = GF.L or {}
	local newbieState = resolveNewbieFilterEmptyState(view, locale)
	if newbieState then
		return newbieState
	end
	local repository = resultRepository()
	local sourceHasRows = sequenceHasValue(repository.apiResultIDs)
	local keyword = view and view.committedSearchQuery
	if (type(keyword) == "string" and keyword ~= "")
		or (tonumber(repository.rawTotal) or 0) > 0
		or sourceHasRows
	then
		return {
			text = locale.BROWSE_FILTERED_NO_RESULTS
				or locale.NO_RESULTS
				or "No listings match the current filters.",
			filtered = true,
		}
	end
	if tonumber(repository.rawTotal) ~= 0
		or not canOfferRecruitmentEntry()
	then
		return { text = locale.NO_RESULTS or "" }
	end

	local selection = self:GetSelection(view)
	if selection and selection._gfQuestSearch == true then
		local bridge = GF.QuestRecruitmentBridge
		if bridge and type(bridge.CanOffer) == "function"
			and bridge:CanOffer() == true
			and selection.questID ~= nil
			and selection.questActivityID ~= nil
		then
			return {
				text = locale.BROWSE_QUEST_NO_RESULTS_CREATE
					or locale.NO_RESULTS or "",
				action = self:BuildEmptyAction(
					view,
					"quest_direct_create",
					locale.BROWSE_QUICK_CREATE_QUEST
						or "Quick Create Quest Listing"
				),
			}
		end
		return { text = locale.NO_RESULTS or "" }
	end

	local workspace = workspaceFor(view)
	if workspace.workspaceID ~= GF.WORKSPACE_MEETING_STONE then
		return { text = locale.NO_RESULTS or "" }
	end
	if canCreateSelection(selection, workspace.workspaceID) then
		local activityID = createActivityID(selection)
		if activityID ~= nil then
			return {
				text = locale.BROWSE_NO_RESULTS_CREATE
					or locale.NO_RESULTS or "",
				action = self:BuildEmptyAction(
					view,
					"meeting_stone_open_create",
					locale.BROWSE_QUICK_CREATE or "Quick Create Listing",
					activityID
				),
			}
		end
	end
	if isAggregateSelection(selection, workspace.workspaceID) then
		return {
			text = locale.BROWSE_AGGREGATE_NO_RESULTS
				or locale.NO_RESULTS or "",
		}
	end
	return { text = locale.NO_RESULTS or "" }
end

function Presenter:ResolveCompletedResultAction(view, displayedCount)
	if (tonumber(displayedCount) or 0) <= 0
		or not self:IsCompletedSearchProjectionCurrent(view)
		or not canOfferRecruitmentEntry()
	then
		return nil
	end
	local selection = self:GetSelection(view)
	if not selection or selection._gfQuestSearch ~= true then
		return nil
	end
	local bridge = GF.QuestRecruitmentBridge
	if bridge and type(bridge.CanOffer) == "function"
		and bridge:CanOffer() == true
		and selection.questID ~= nil
		and selection.questActivityID ~= nil
	then
		local locale = GF.L or {}
		return self:BuildQuickCreateAction(
			view,
			"quest_direct_create",
			locale.BROWSE_QUICK_CREATE_NEW or "Quick Create New Listing",
			"results"
		)
	end
	return nil
end

local ACTION_IDENTITY_FIELDS = {
	"kind", "placement", "searchKey", "searchToken", "workspaceKey",
	"workspaceID", "workspaceGeneration", "questID", "activityID",
	"categoryID",
}

local function sameAction(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for _, field in ipairs(ACTION_IDENTITY_FIELDS) do
		if left[field] ~= right[field] then
			return false
		end
	end
	return true
end

function Presenter:IsEmptyActionCurrent(view, action)
	if type(action) ~= "table" or self:GetDisplayedResultCount(view) ~= 0 then
		return false
	end
	local emptyState = self:ResolveCompletedEmptyState(view, 0)
	return sameAction(emptyState and emptyState.action, action)
end

function Presenter:IsResultActionCurrent(view, action)
	local count = self:GetDisplayedResultCount(view)
	return type(action) == "table" and count > 0
		and sameAction(self:ResolveCompletedResultAction(view, count), action)
end

function Presenter:ExecuteQuickCreateAction(view, action)
	if type(action) ~= "table" then
		return false
	end
	if action.kind == "quest_direct_create" then
		local bridge = GF.QuestRecruitmentBridge
		return bridge ~= nil and type(bridge.Create) == "function"
			and bridge:Create(action) == true or false
	end
	if action.kind ~= "meeting_stone_open_create" then
		return false
	end
	local selection = self:GetSelection(view)
	local workspace = workspaceFor(view)
	local activityID = createActivityID(selection)
	local main = GF.MainFrame
	if canOfferRecruitmentEntry()
		and canCreateSelection(selection, workspace.workspaceID)
		and activityID ~= nil and activityID == action.activityID
		and main and type(main.OpenCreateTab) == "function"
	then
		main:OpenCreateTab()
		return true
	end
	return false
end

function Presenter:ExecuteEmptyAction(view)
	local action = view and view._emptyAction
	if not self:IsEmptyActionCurrent(view, action) then
		self:UpdateSearchHint(view)
		return false
	end
	if view.emptyActionButton then
		view.emptyActionButton:SetEnabled(false)
	end
	local handled = self:ExecuteQuickCreateAction(view, action)
	if not handled and view.parent and view.parent:IsShown() then
		self:UpdateSearchHint(view)
	end
	return handled
end

function Presenter:ExecuteResultAction(view, action)
	if not self:IsResultActionCurrent(view, action) then
		view:RefreshList({ preserveScroll = true, forceRebuild = true })
		return false
	end
	local handled = self:ExecuteQuickCreateAction(view, action)
	if view.parent and view.parent:IsShown() then
		view:RefreshList({ preserveScroll = true })
	end
	return handled
end

local function premadeFindBlockMessage()
	local availability = GF.Availability
	local reader = availability and availability.GetPremadeFindBlockMessage
	if type(reader) ~= "function" then
		return nil
	end
	local ok, message = pcall(reader, availability)
	return ok and type(message) == "string" and message ~= ""
		and message or nil
end

function Presenter:ResolveStatus(view)
	local locale = GF.L or {}
	local blocked = premadeFindBlockMessage()
	if blocked then
		return { text = blocked }
	end
	local target = GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget(self:GetSelection(view))
	if target and GF.RaidLeaderLookupView then
		if self:HasBrowseList(view) and GF.RaidLeaderLookup:IsCurrent(target) then return { hidden = true } end
		return GF.RaidLeaderLookupView.EmptyStatus(view, target)
	end
	if self:HasBrowseList(view) then
		return { hidden = true }
	end
	local selection = self:GetSelection(view)
	local searchable = self:IsSearchableSelection(view, selection)
	if searchable and self:IsSearchPending(view) then
		return {
			text = isNewbieSearchActive(view)
				and newbieSearchProgressText(locale)
				or locale.LOADING_GROUP_LIST or "Loading group listings",
			loading = true,
		}
	end
	if not searchable then
		local workspace = GF.LFGWorkspaceView
		local policy = GF.LFGWorkspacePolicy
		local noSeason = selection ~= nil and workspace
			and type(workspace.IsMythicPlusActive) == "function"
			and workspace:IsMythicPlusActive() == true
			and policy and type(policy.GetSeasonActivityIDs) == "function"
			and #policy:GetSeasonActivityIDs() == 0
		if noSeason then
			local text = type(policy.GetSeasonUnavailableMessage) == "function"
				and policy:GetSeasonUnavailableMessage(locale) or nil
			return {
				text = text or locale.MPLUS_LFG_SCOPE_UNAVAILABLE
					or "Level restricted: Seasonal Mythic+ mode has not been unlocked.",
			}
		end
		local hint = GF.NavData and GF.NavData.GetSearchBlockHint
			and GF.NavData.GetSearchBlockHint(selection)
		return {
			text = hint or locale.BROWSE_SELECT_ACTIVITY_TO_SEARCH
				or locale.NO_SELECTION or "",
		}
	end
	local selectionKey = self:GetSelectionKey(view)
	if not view.activeSearchKey or view.activeSearchKey ~= selectionKey then
		return { text = locale.CLICK_SEARCH or "", uncommitted = true }
	end
	if view._searchFailed == true then
		return { text = _G.LFG_LIST_SEARCH_FAILED or locale.NO_RESULTS or "" }
	end
	if view.gfOwnsSearch == true
		and view._resolvedResultToken ~= view._searchToken
	then
		return {
			text = locale.LOADING_GROUP_LIST or "Loading group listings",
			loading = true,
		}
	end
	local emptyState = self:ResolveCompletedEmptyState(
		view, self:GetDisplayedResultCount(view))
	return {
		text = emptyState and emptyState.text or locale.NO_RESULTS or "",
		loading = emptyState and emptyState.loading == true or nil,
		action = emptyState and emptyState.action or nil,
	}
end

function Presenter:UpdateSearchHint(view)
	if not view or type(view.SetEmptyPrompt) ~= "function" then
		return nil
	end
	local status = self:ResolveStatus(view)
	if status.hidden == true then
		view:SetEmptyPrompt(nil)
	elseif status.text and status.text ~= "" then
		view:SetEmptyPrompt(
			status.text,
			status.loading == true and true or nil,
			status.action
		)
	elseif status.uncommitted == true then
		view:SetEmptyPrompt(nil)
	end
	local main = GF.MainFrame
	if main and type(main.UpdateBrowseStatusHint) == "function" then
		main:UpdateBrowseStatusHint(nil)
	end
	local subtitle = GF.SubtitleBar
	if subtitle and type(subtitle.UpdateRefreshButtonState) == "function" then
		subtitle:UpdateRefreshButtonState()
	end
	return status
end

function Presenter:UpdateResultsChrome(view, count)
	local main = GF.MainFrame
	if main and type(main.UpdateActivityCount) == "function" then
		main:UpdateActivityCount(count)
	end
	local subtitle = GF.SubtitleBar
	if subtitle and type(subtitle.UpdateRefreshButtonState) == "function" then
		subtitle:UpdateRefreshButtonState()
	end
	return self:UpdateSearchHint(view)
end

local function currentGroupElement(repository, ids)
	local projector = GF.CurrentGroupProjection
	if projector and type(projector.BuildListElement) == "function" then
		return projector:BuildListElement(repository, ids)
	end
	return nil
end

local function projectedCount(ids, currentGroup)
	local hidden = currentGroup and currentGroup.hiddenResultIDs
	local count = 0
	for _, resultID in ipairs(ids or {}) do
		if not (hidden and hidden[resultID]) then
			count = count + 1
		end
	end
	return count
end

local function resultOrderSignature(ids)
	return type(ids) == "table" and #ids > 0
		and table.concat(ids, ID_SEPARATOR) or ""
end

local function currentGroupIdentity(element)
	local projector = GF.CurrentGroupProjection
	return projector and type(projector.GetSignature) == "function"
		and projector:GetSignature(element) or ""
end

local function actionIdentity(action)
	if type(action) ~= "table" then
		return ""
	end
	local values = {}
	for index, field in ipairs(ACTION_IDENTITY_FIELDS) do
		values[index] = tostring(action[field] or "")
	end
	values[#values + 1] = tostring(action.label or "")
	return table.concat(values, ID_SEPARATOR)
end

local function recordProjectionCompletion(count)
	local diagnostics = GF.SearchMemoryDiagnostics
	if diagnostics and type(diagnostics.RecordListProjection) == "function" then
		diagnostics:RecordListProjection()
	end
	if diagnostics and type(diagnostics.ScheduleCompleteSearch) == "function" then
		diagnostics:ScheduleCompleteSearch(count)
	end
end

local function refreshFloatingStatus()
	local floating = GF.FloatButton
	if floating and type(floating.Refresh) == "function" then
		floating:Refresh()
	end
end

local function resolveIndex(repository, resultID)
	if repository and type(repository.GetIndexForResultID) == "function" then
		return repository:GetIndexForResultID(resultID)
	end
	local facade = resultService()
	return facade and type(facade.GetIndexForResultID) == "function"
		and facade:GetIndexForResultID(resultID) or nil
end

function Presenter:BuildResultProjection(view)
	local repository = resultRepository()
	local ids = repository.resultIDs or {}
	local target = GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget(self:GetSelection(view))
	local currentGroup
	if not target then currentGroup = currentGroupElement(resultService(), ids) end
	local count = projectedCount(ids, currentGroup)
	local action = self:ResolveCompletedResultAction(view, count)
	local list = GF.BrowseScrollList
	local fixedApplications = list and list.BuildFixedApplicationSet
		and list.BuildFixedApplicationSet(ids) or {}
	local fixedIDs = {}
	local hidden = currentGroup and currentGroup.hiddenResultIDs
	for _, resultID in ipairs(ids) do
		if fixedApplications[resultID] and not (hidden and hidden[resultID]) then
			fixedIDs[#fixedIDs + 1] = resultID
		end
	end
	return {
		ids = ids,
		fixedApplications = fixedApplications,
		currentGroup = currentGroup,
		count = count,
		action = action,
		signature = resultOrderSignature(ids)
			.. ID_SEPARATOR .. resultOrderSignature(fixedIDs)
			.. ID_SEPARATOR .. currentGroupIdentity(currentGroup)
			.. ID_SEPARATOR .. actionIdentity(action),
	}
end

function Presenter:ReconcileSelection(view, projection)
	local selectedID = view.selectedResultID
	if selectedID == nil then
		return false
	end
	local hidden = projection.currentGroup
		and projection.currentGroup.hiddenResultIDs
	local index = not (hidden and hidden[selectedID])
		and resolveIndex(resultRepository(), selectedID) or nil
	if index then
		view.selectedResult = index
		return true
	end
	self:ClearSelection(view)
	return false
end

function Presenter:RefreshList(view, options)
	options = options or {}
	if not view or view._censoredDebugPreview == true
		or view._teamListDebugPreview == true
	then
		return false
	end
	if not view.scrollList or not view.activeSearchKey
		or view.activeSearchKey ~= self:GetSelectionKey(view)
	then
		return false
	end
	local result = resultService()
	if result and type(result.ReconcileCurrentGroupOrder) == "function" then
		result:ReconcileCurrentGroupOrder()
	end
	local projection = self:BuildResultProjection(view)
	view.totalResultCount = projection.count
	view._displayedResultCount = projection.count
	view._hasCurrentGroupProjection = projection.currentGroup ~= nil or nil
	self:UpdateResultsChrome(view, projection.count)

	if projection.count == 0 and projection.currentGroup == nil then
		self:ClearSelection(view)
		view._listOrderSig = ""
		view.scrollList:SetElements({})
		refreshFloatingStatus()
		self:UpdateSearchHint(view)
		recordProjectionCompletion(0)
		return true
	end

	self:ReconcileSelection(view, projection)
	local repaintOnly = options.preserveScroll == true
		and options.forceRebuild ~= true
		and projection.signature ~= ""
		and projection.signature == view._listOrderSig
		and view.scrollList.dataProvider ~= nil
	if repaintOnly then
		if type(view.SetEmptyPrompt) == "function" then
			view:SetEmptyPrompt(nil)
		end
		if type(view.RepaintVisibleRows) == "function" then
			view:RepaintVisibleRows()
		end
		local list = GF.BrowseScrollList
		if list and type(list.RelayoutVisible) == "function" then
			list.RelayoutVisible(view)
		end
		local facade = resultService()
		if options.skipSnapshot ~= true
			and facade and type(facade.CommitSnapshot) == "function"
		then
			facade:CommitSnapshot()
		end
		refreshFloatingStatus()
		recordProjectionCompletion(projection.count)
		return true
	end

	if options.preserveScroll ~= true then
		self:ClearSelection(view)
	end
	view._listOrderSig = projection.signature
	local list = GF.BrowseScrollList
	local elements
	if list and type(list.BuildElements) == "function" then
		elements, view._browseElementCache = list.BuildElements(
			projection.ids,
			projection.action,
			view._browseElementCache,
			projection.currentGroup,
			projection.fixedApplications
		)
	else
		elements = {}
	end
	view.scrollList:SetElements(elements, {
		retainScroll = options.preserveScroll,
		retainIdentity = options.preserveScroll,
	})
	if type(view.SetEmptyPrompt) == "function" then
		view:SetEmptyPrompt(nil)
	end
	-- SetElements initializes every acquired row at the current viewport width.
	-- A second layout here repaints the same cells during the first result frame.
	-- Real geometry changes still use the panel's explicit relayout path.
	local facade = resultService()
	if options.skipSnapshot ~= true
		and facade and type(facade.CommitSnapshot) == "function"
	then
		facade:CommitSnapshot()
	end
	refreshFloatingStatus()
	if view.leaderLookupView then view.leaderLookupView:Refresh() end
	recordProjectionCompletion(projection.count)
	return true
end

local function cancelTimer(owner, field)
	local timer = owner and owner[field]
	if owner then
		owner[field] = nil
	end
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
end

function Presenter:RefreshResults(view, options)
	options = options or {}
	if not view then
		return false
	end
	if view.awaitingGFSearch == true
		and options.commitManualDeclineRefresh ~= true
	then
		view._resultsDirty = true
		return false
	end
	cancelTimer(view, "_refreshDebounce")
	view._pendingRefreshOpts = nil
	if not view.scrollList then
		if type(view.DiscardManualDeclineRefresh) == "function" then
			view:DiscardManualDeclineRefresh()
		end
		return false
	end
	view._resultsDirty = false
	local selectionKey = self:GetSelectionKey(view)
	if view.activeSearchKey == nil or view.activeSearchKey ~= selectionKey then
		if type(view.DiscardManualDeclineRefresh) == "function" then
			view:DiscardManualDeclineRefresh()
		end
		if self:IsSearchPending(view) and type(view.EndSearchUI) == "function" then
			view:EndSearchUI()
		end
		if type(view.ClearRowDisplay) == "function" then
			view:ClearRowDisplay()
		end
		self:UpdateSearchHint(view)
		local main = GF.MainFrame
		if main and type(main.UpdateActivityCount) == "function" then
			main:UpdateActivityCount(0)
		end
		return false
	end
	if options.automaticResultUpdate == true
		and type(view.HasAutomaticResultOrderLock) == "function"
		and view:HasAutomaticResultOrderLock() ~= true
		and type(view.PreserveAutomaticOrderForFrozenGrayRows) == "function"
	then
		view:PreserveAutomaticOrderForFrozenGrayRows()
	end
	if type(view.EndSearchUI) == "function" then
		view:EndSearchUI()
	end
	view._refreshToken = (view._refreshToken or 0) + 1
	local refreshToken = view._refreshToken
	local searchToken = view._searchToken
	local manual = view._manualDeclineRefresh
	local beforeFilters
	if manual then
		local valid = manual.token == searchToken
			and manual.selectionKey == selectionKey
		if options.commitManualDeclineRefresh == true and valid
			and GF.Apply
			and type(GF.Apply.ApplyManualRefreshUnlocks) == "function"
		then
			beforeFilters = function(resultIDs)
				if view._manualDeclineRefresh ~= manual then
					return
				end
				view:DiscardManualDeclineRefresh()
				GF.Apply:ApplyManualRefreshUnlocks(manual.captured, resultIDs)
			end
		elseif options.commitManualDeclineRefresh == true or not valid then
			view:DiscardManualDeclineRefresh()
		end
	end
	local facade = resultService()
	if not facade or type(facade.RefreshCache) ~= "function" then
		return false
	end
	facade:RefreshCache(function()
		if view._refreshToken == refreshToken
			and view._searchToken == searchToken
			and view.activeSearchKey == selectionKey
			and selectionKey == Presenter:GetSelectionKey(view)
		then
			view._resolvedResultToken = searchToken
			if type(view.RefreshList) == "function" then
				view:RefreshList(options)
			else
				Presenter:RefreshList(view, options)
			end
		end
	end, beforeFilters, {
		stableOrder = options.automaticResultUpdate == true and options.forceResort ~= true,
	})
	return true
end

function Presenter:HasResettableBrowseState(view, searchText)
	if type(searchText) == "string" and searchText:match("%S") then
		return true
	end
	return view ~= nil and (
		self:IsSearchPending(view)
		or view.activeSearchKey ~= nil
		or (tonumber(view.totalResultCount) or 0) > 0
	) or false
end

function Presenter:QueueFailedResultBinding(view, row, elementData)
	return view and type(view.QueueFailedResultBinding) == "function"
		and view:QueueFailedResultBinding(row, elementData) or false
end

function Presenter:ClearFailedResultBinding(view, resultID, elementData)
	if view and type(view.ClearFailedResultBinding) == "function" then
		view:ClearFailedResultBinding(resultID, elementData)
	end
end

function Presenter:ConfigureActionButton(view, button, action)
	if view and type(view.ConfigureQuickCreateButton) == "function" then
		view:ConfigureQuickCreateButton(button, action)
	end
end

-- Peer specialization snapshots can arrive after GROUP_ROSTER_UPDATE. The
-- loaded, visible workspace alone repaints that change; hidden workspaces
-- pick up the latest roster when they next build their current-group element.
local rosterCache = GF.MythicPlusRosterCache
if rosterCache and type(rosterCache.AddListener) == "function" then
	rosterCache:AddListener(function()
		local panel = GF.BrowsePanel
		local parent = panel and panel.parent
		if not (panel and panel._hasCurrentGroupProjection == true and parent) then
			return
		end
		if parent.IsVisible then
			if not parent:IsVisible() then return end
		elseif not (parent.IsShown and parent:IsShown()) then
			return
		end
		local projection = GF.CurrentGroupProjection
		if projection and projection:RefreshRosterFromGroup() then
			local apply = GF.Apply
			if apply and type(apply.QueueCurrentGroupRefresh) == "function" then
				apply:QueueCurrentGroupRefresh({ requireVisibleBrowse = true })
			end
		end
	end)
end
