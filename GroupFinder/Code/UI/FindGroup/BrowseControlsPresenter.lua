local _, GF = ...

-- BrowseControlsPresenter owns the decisions shared by SubtitleBar and the
-- advanced FilterPanel.  It deliberately knows nothing about Frame objects:
-- SubtitleBar remains the adapter that holds the borrowed Blizzard edit box,
-- snapshots widget layout, and renders the projection returned here.
local Presenter = {}
GF.BrowseControlsPresenter = Presenter

Presenter.LEASE_IDLE = "idle"
Presenter.LEASE_ACQUIRE = "acquire"
Presenter.LEASE_KEEP = "keep"
Presenter.LEASE_RELEASE = "release"
Presenter.LEASE_WAIT = "wait"

local CONTROL_STATE_KEYS = {
	_browseMode = true,
	_mythicPlusSidebarMode = true,
	_mythicPlusFilterInteractionEnabled = true,
	_browseInteractionEnabled = true,
}

local viewStates = setmetatable({}, { __mode = "k" })

local function stateFor(view)
	local state = viewStates[view]
	if state == nil then
		state = {}
		viewStates[view] = state
	end
	return state
end

local function invoke(owner, methodName, ...)
	local callback = owner and owner[methodName]
	if type(callback) ~= "function" then
		return nil, false
	end
	local ok, value, extra = pcall(callback, owner, ...)
	if not ok then
		return nil, false
	end
	return value, true, extra
end

local function trim(value)
	if type(value) ~= "string" then
		return ""
	end
	if type(strtrim) == "function" then
		local ok, result = pcall(strtrim, value)
		if ok and type(result) == "string" then
			return result
		end
	end
	return value:match("^%s*(.-)%s*$") or ""
end

local function shallowCopy(source)
	local copy = {}
	for key, value in pairs(type(source) == "table" and source or {}) do
		copy[key] = value
	end
	return copy
end

function Presenter:BindView(view)
	if type(view) ~= "table" then
		return nil
	end
	local existing = getmetatable(view)
	if existing and existing._gfBrowseControlsPresenter == self then
		return stateFor(view)
	end
	local state = stateFor(view)
	for key in pairs(CONTROL_STATE_KEYS) do
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
	meta._gfBrowseControlsPresenter = self
	meta.__index = function(target, key)
		if CONTROL_STATE_KEYS[key] then
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
		if CONTROL_STATE_KEYS[key] then
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

function Presenter:IsBrowseMode(view)
	return type(view) == "table" and stateFor(view)._browseMode == true
end

function Presenter:SetBrowseMode(view, visible)
	if type(view) ~= "table" then
		return false
	end
	local state = stateFor(view)
	local nextValue = visible == true
	local changed = state._browseMode ~= nextValue
	state._browseMode = nextValue
	return changed
end

function Presenter:PlanBrowseVisibility(view, visible, options)
	options = type(options) == "table" and options or {}
	local show = visible == true
	local changed = self:SetBrowseMode(view, show)
	local passive = options.passiveWarmup == true
	return {
		show = show,
		changed = changed,
		passiveWarmup = passive,
		borrowSearchField = show and not passive,
		stopOwnershipWatch = passive or not show,
		releaseSearchField = not show,
		clearNotice = not show,
		dismissAutoComplete = not show,
	}
end

function Presenter:IsMythicPlusSidebarMode(view)
	return type(view) == "table"
		and stateFor(view)._mythicPlusSidebarMode == true
end

function Presenter:PlanSidebarTransition(view, requested, hostsAvailable)
	if type(view) ~= "table" then
		return { changed = false, active = false }
	end
	local state = stateFor(view)
	local current = state._mythicPlusSidebarMode == true
	requested = requested == true
	if current == requested then
		return {
			changed = false,
			active = current,
			attachToSidebar = false,
			restoreStandardLayout = false,
		}
	end
	local active = requested and hostsAvailable == true
	if current == active then
		-- The public request still differs from the active state.  The legacy
		-- adapter used this path to restore standard anchors and notify the M+
		-- host that no external controls were attached, even though the stored
		-- boolean remained false.
		state._mythicPlusSidebarMode = active
		return {
			changed = true,
			active = current,
			attachToSidebar = false,
			restoreStandardLayout = not active,
			reason = requested and "sidebar-hosts-unavailable" or nil,
		}
	end
	state._mythicPlusSidebarMode = active
	return {
		changed = true,
		active = active,
		attachToSidebar = active,
		restoreStandardLayout = current and not active,
	}
end

function Presenter:IsMythicPlusFilterInteractionEnabled(view)
	if type(view) ~= "table" then
		return true
	end
	return stateFor(view)._mythicPlusFilterInteractionEnabled ~= false
end

function Presenter:SetMythicPlusFilterInteractionEnabled(view, enabled)
	if type(view) ~= "table" then
		return false
	end
	local state = stateFor(view)
	local nextValue = enabled == true
	local changed = state._mythicPlusFilterInteractionEnabled ~= nextValue
	state._mythicPlusFilterInteractionEnabled = nextValue
	return changed
end

function Presenter:SetBrowseInteractionEnabled(view, enabled)
	if type(view) ~= "table" then
		return false
	end
	local state = stateFor(view)
	local nextValue = enabled == true
	local changed = state._browseInteractionEnabled ~= nextValue
	state._browseInteractionEnabled = nextValue
	return changed
end

function Presenter:IsBrowseInteractionEnabled(view)
	if type(view) ~= "table" then
		return true
	end
	local state = stateFor(view)
	if state._browseInteractionEnabled == false then
		return false
	end
	return state._mythicPlusSidebarMode ~= true
		or state._mythicPlusFilterInteractionEnabled ~= false
end

function Presenter:ProjectInteraction(view)
	local sidebar = self:IsMythicPlusSidebarMode(view)
	local leaderLookup = GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget() ~= nil
	local enabled = self:IsBrowseInteractionEnabled(view)
	local sidebarFilterEnabled =
		self:IsMythicPlusFilterInteractionEnabled(view)
	return {
		enabled = enabled,
		leaderLookup = leaderLookup,
		searchFieldEnabled = enabled and not leaderLookup,
		sidebar = sidebar,
		sidebarFilterEnabled = sidebarFilterEnabled,
		preserveDisabledAlpha = sidebar and not sidebarFilterEnabled,
		dismissAutoComplete = leaderLookup or sidebar and not enabled,
		hideAdvancedFilter = leaderLookup or sidebar and not enabled,
	}
end

-- This plan is intentionally expressed only in ownership facts.  The view
-- adapter may inspect parents and borrowed marks, but it cannot invent a
-- second search owner or decide to steal an externally owned field.
function Presenter:PlanSearchFieldLease(view, facts)
	facts = type(facts) == "table" and facts or {}
	local ownsLease = facts.attached == true or facts.borrowing == true
	if not self:IsBrowseMode(view) or facts.browseTabSelected ~= true then
		return {
			action = ownsLease and self.LEASE_RELEASE or self.LEASE_IDLE,
			reason = "browse-inactive",
		}
	end
	if facts.nativeSearchActive == true then
		return {
			action = ownsLease and self.LEASE_RELEASE or self.LEASE_WAIT,
			reason = "native-search-active",
		}
	end
	if facts.searchFieldPresent ~= true or facts.hostPresent ~= true then
		return {
			action = ownsLease and self.LEASE_RELEASE or self.LEASE_WAIT,
			reason = "search-field-unavailable",
		}
	end
	-- A matching parent alone is not ownership.  Another consumer may have
	-- claimed the widget between ownership polls while leaving it under the GF
	-- host.  Release only our local session in that case; the release plan will
	-- deliberately avoid restoring externally owned scripts or layout.
	if facts.ownerCompatible == false or facts.externallyOwned == true then
		return {
			action = ownsLease and self.LEASE_RELEASE or self.LEASE_WAIT,
			reason = "search-owner-conflict",
		}
	end
	if facts.borrowing == true then
		return { action = self.LEASE_KEEP, reason = "lease-current" }
	end
	if facts.attached == true then
		return {
			action = self.LEASE_RELEASE,
			reason = "lease-parent-lost",
		}
	end
	if facts.searchParentAllowed ~= true then
		return { action = self.LEASE_WAIT, reason = "search-parent-owned" }
	end
	local autoCompleteAcquireAllowed = facts.autoCompleteAcquireAllowed
	if autoCompleteAcquireAllowed == nil then
		autoCompleteAcquireAllowed = facts.autoCompleteParentAllowed
	end
	if autoCompleteAcquireAllowed == false
		or facts.autoCompleteOwnerCompatible == false
		or facts.autoCompleteExternallyOwned == true
	then
		return {
			action = self.LEASE_WAIT,
			reason = "autocomplete-parent-owned",
		}
	end
	return { action = self.LEASE_ACQUIRE, reason = "browse-ready" }
end

function Presenter:PlanSearchFieldRelease(view, facts)
	facts = type(facts) == "table" and facts or {}
	local borrowing = facts.borrowing == true
	local attached = facts.attached == true
	local ownsLease = borrowing or attached
	if not ownsLease then
		return {
			action = self.LEASE_IDLE,
			clearLocalLease = true,
			clearBorrowMarker = facts.searchFieldPresent == true,
			clearAutoCompleteBorrowMarker =
				facts.autoCompletePresent == true,
			stopOwnershipWatch = facts.browseTabSelected ~= true,
		}
	end
	local searchOwnershipSafe = facts.ownerCompatible ~= false
		and facts.externallyOwned ~= true
	local autoCompleteOwnershipSafe =
		facts.autoCompleteOwnerCompatible ~= false
		and facts.autoCompleteExternallyOwned ~= true
	local restoreSearch = searchOwnershipSafe
		and facts.searchFieldPresent == true
		and (borrowing or facts.searchAtReturnParent == true)
	local restoreAutoComplete = autoCompleteOwnershipSafe
		and facts.autoCompletePresent == true
		and (facts.autoCompleteAtBorrowParent == true
			or facts.autoCompleteAtReturnParent == true)
	return {
		action = self.LEASE_RELEASE,
		restoreSearchField = restoreSearch,
		restoreSearchScripts = restoreSearch,
		restoreSearchInstructions = restoreSearch,
		restoreSearchEnabled = restoreSearch,
		restoreAutoComplete = restoreAutoComplete,
		restoreAutoCompleteScripts = restoreAutoComplete,
		clearBorrowMarker = facts.searchFieldPresent == true,
		clearAutoCompleteBorrowMarker = facts.autoCompletePresent == true,
		clearLocalLease = true,
		stopOwnershipWatch = facts.browseTabSelected ~= true,
		refreshNativeAutoComplete = facts.nativeSearchActive == true
			and restoreSearch and restoreAutoComplete,
	}
end

function Presenter:CanUseBorrowedAutoComplete(view, facts)
	facts = type(facts) == "table" and facts or {}
	return self:IsBrowseMode(view)
		and facts.browseTabSelected == true
		and facts.nativeSearchActive ~= true
		and facts.attached == true
		and facts.borrowing == true
		and facts.ownerCompatible ~= false
		and facts.externallyOwned ~= true
		and facts.frameVisible == true
		and facts.hostVisible == true
		and facts.searchFieldVisible == true
		and facts.autoCompleteParentAllowed ~= false
		and facts.autoCompleteOwnerCompatible ~= false
		and facts.autoCompleteExternallyOwned ~= true
end

local function browsePanel()
	local tab = GF.FindGroupTab
	local panel = invoke(tab, "GetPanel")
	return panel
end

function Presenter:GetSelection(panel)
	panel = panel or browsePanel()
	local browse = GF.BrowsePresenter
	local selection, called = invoke(browse, "GetSelection", panel)
	if called and selection ~= nil then
		return selection
	end
	local tab = GF.FindGroupTab
	selection, called = invoke(tab, "GetSelection")
	if called and selection ~= nil then
		return selection
	end
	local main = GF.MainFrame
	return main and main.selection or nil
end

function Presenter:IsSearchableSelection(panel, selection)
	panel = panel or browsePanel()
	selection = selection or self:GetSelection(panel)
	local browse = GF.BrowsePresenter
	local searchable, called = invoke(
		browse, "IsSearchableSelection", panel, selection)
	if called then
		return searchable == true
	end
	local tab = GF.FindGroupTab
	searchable, called = invoke(tab, "IsSearchableSelection", selection)
	if called then
		return searchable ~= false
	end
	return selection ~= nil
end

function Presenter:ProjectNativeCategory(selection)
	selection = selection or self:GetSelection()
	if type(selection) ~= "table" or selection.categoryID == nil then
		return nil
	end
	local scope = selection
	local nav = GF.NavData
	-- Synchronizing Blizzard's native category controls is presentation work.
	-- Resolving the exact scope of an archive root recursively realizes every
	-- lazy expansion, loading all Journal/LFG catalogs before the root flyout
	-- can be drawn. Root metadata is already sufficient for this projection;
	-- the exact compiler remains authoritative when a search is actually run.
	local lightweightArchiveDirectory = selection.archiveDirectoryOnly == true
		or ((selection.level or 0) == 0
			and selection.lazyKind == "catalog_l0")
	if not lightweightArchiveDirectory
		and nav and type(nav.ResolveSearchScope) == "function"
	then
		local ok, resolved = pcall(nav.ResolveSearchScope, selection)
		if ok and type(resolved) == "table" then
			scope = resolved
		end
	end
	local categoryID = scope.categoryID or selection.categoryID
	local filters = scope.filters
	if lightweightArchiveDirectory then
		filters = nil
	end
	if filters == nil then
		local filter = GF.Filter
		if filter and type(filter.ResolveCategoryFilters) == "function" then
			local ok, resolved = pcall(
				filter.ResolveCategoryFilters,
				filter,
				categoryID,
				selection.filters or 0
			)
			if ok then
				filters = resolved
			end
		end
	end
	filters = filters or selection.filters or 0
	local flags = Enum and Enum.LFGListFilter or {}
	local preferred = scope.preferredFilters
		or selection.preferredFilters or flags.PvE or 0
	local signatureValues = {
		categoryID or 0,
		filters or 0,
		preferred,
		scope.groupID or selection.groupID or "",
		scope.activityID or selection.activityID or "",
	}
	for index = 1, #signatureValues do
		signatureValues[index] = tostring(signatureValues[index])
	end
	return {
		selection = selection,
		scope = scope,
		categoryID = categoryID,
		filters = filters,
		preferredFilters = preferred,
		signature = table.concat(signatureValues, "|"),
	}
end

function Presenter:ProjectSearchPlaceholder(view, hostWidth)
	local locale = GF.L or {}
	local sidebar = self:IsMythicPlusSidebarMode(view)
	local placeholder = sidebar
		and (locale.MPLUS_BROWSE_FILTER_SEARCH_PLACEHOLDER
			or "Name, level, note")
		or (locale.SEARCH_PLACEHOLDER or "Search groups...")
	if not sidebar then
		return { text = placeholder }
	end
	hostWidth = tonumber(hostWidth) or 0
	if hostWidth <= 0 then
		hostWidth = GF.MPLUS_LFG_SIDEBAR_CONTROL_W
			or ((GF.NAV_WIDTH or 180) - 16)
	end
	return {
		text = placeholder,
		fitWidth = math.max(
			1,
			hostWidth
				- (GF.SUBTITLE_SEARCH_TEXT_INSET_LEFT or 27)
				- (GF.SUBTITLE_SEARCH_TEXT_INSET_RIGHT or 24)
				- (GF.MPLUS_BROWSE_SEARCH_FIT_PADDING or 2)
		),
		minimumSize = GF.MPLUS_BROWSE_SEARCH_MIN_TEXT_SIZE or 9,
	}
end

function Presenter:GetEffectiveSearchText(searchText, selectionLabel)
	local keyword = trim(searchText)
	if keyword == "" then
		return nil
	end
	local label = trim(selectionLabel)
	if label ~= "" and label == keyword then
		return nil
	end
	return keyword
end

function Presenter:HasResettableBrowseState(panel, searchText)
	local browse = GF.BrowsePresenter
	local hasState, called = invoke(
		browse, "HasResettableBrowseState", panel, searchText)
	if called then
		return hasState == true
	end
	return trim(searchText) ~= ""
		or (panel ~= nil and (GF.searching == true
			or panel.awaitingGFSearch == true
			or panel.activeSearchKey ~= nil
			or (tonumber(panel.totalResultCount) or 0) > 0))
end

function Presenter:IsQuickJoinEnabled()
	local apply = GF.Apply
	local mode, called = invoke(apply, "GetMode")
	return called
		and mode == (GF.APPLY_DBLCLICK_AUTO or "dblclick_auto")
end

function Presenter:IsAutoJoinEnabled()
	local enabled, called = invoke(
		GF.Apply, "IsAutoAcceptInviteEnabled")
	return called and enabled == true
end

local function refreshSettingsApplyProjection()
	local settings = GF.SettingsPanel
	if not settings then
		return
	end
	if settings.scroll and type(settings.RefreshFromDB) == "function" then
		settings:RefreshFromDB()
	elseif type(settings.UpdateApplyDropdown) == "function" then
		settings:UpdateApplyDropdown()
	end
end

function Presenter:SetQuickJoinEnabled(enabled)
	local mode = enabled == true
		and (GF.APPLY_DBLCLICK_AUTO or "dblclick_auto")
		or (GF.APPLY_MANUAL or "manual")
	local stored, called = invoke(GF.Apply, "SetMode", mode)
	if not called or stored == nil then
		return false
	end
	refreshSettingsApplyProjection()
	return true
end

function Presenter:SetAutoJoinEnabled(enabled)
	enabled = enabled == true
	local stored, called = invoke(
		GF.Apply, "SetAutoAcceptInviteEnabled", enabled)
	if not called or stored == nil then
		return false
	end
	local apply = GF.Apply
	if stored == true and apply then
		invoke(apply, "QueueAutoAcceptInvite")
		invoke(apply, "QueueAutoConfirmLfgListRoleCheck")
	end
	refreshSettingsApplyProjection()
	return true
end

local function selectedResult(panel)
	local browse = GF.BrowsePresenter
	local index, called, resultID = invoke(
		browse, "GetSelectedResult", panel)
	if called then
		return index, resultID
	end
	return panel and panel.selectedResult or nil,
		panel and panel.selectedResultID or nil
end

local function searchPending(panel)
	local browse = GF.BrowsePresenter
	local pending, called = invoke(browse, "IsSearchPending", panel)
	if called then
		return pending == true
	end
	return GF.searching == true
		or (panel and panel.awaitingGFSearch == true)
end

local function refreshable(panel)
	local browse = GF.BrowsePresenter
	local value, called = invoke(
		browse, "HasRefreshableBrowseSource", panel)
	if called then
		return value == true
	end
	local tab = GF.FindGroupTab
	value, called = invoke(tab, "HasRefreshableBrowseSource")
	return called and value == true or false
end

function Presenter:ProjectSearchCapability(view, arguments)
	arguments = type(arguments) == "table" and arguments or {}
	local panel = arguments.panel or browsePanel()
	local interaction = self:ProjectInteraction(view)
	local selection = arguments.selection or self:GetSelection(panel)
	local searchable = self:IsSearchableSelection(panel, selection)
	local pending = arguments.searching == true or searchPending(panel)
	local cooldown, hasPanelCooldown = invoke(
		panel, "GetSearchCooldownRemaining")
	if not hasPanelCooldown then
		local tab = GF.FindGroupTab
		cooldown = invoke(tab, "GetSearchCooldownRemaining")
	end
	cooldown = tonumber(cooldown) or 0
	local busy = pending or cooldown > 0
	local allowed = interaction.enabled and not busy and searchable
	local reason
	if not interaction.enabled then
		reason = "interaction-disabled"
	elseif pending then
		reason = "search-pending"
	elseif cooldown > 0 then
		reason = "search-cooldown"
	elseif not searchable then
		reason = "selection-unsearchable"
	end
	return {
		allowed = allowed,
		reason = reason,
		selection = selection,
		interaction = interaction,
		interactionEnabled = interaction.enabled,
		searchable = searchable,
		pending = pending,
		cooldown = cooldown,
		busy = busy,
	}
end

function Presenter:CanStartSelectionSearch(view, selection, arguments)
	arguments = type(arguments) == "table"
		and shallowCopy(arguments) or {}
	arguments.selection = selection
	local capability = self:ProjectSearchCapability(view, arguments)
	return capability.allowed, capability.reason, capability
end

function Presenter:ProjectControlState(view, arguments)
	arguments = type(arguments) == "table" and arguments or {}
	local panel = arguments.panel or browsePanel()
	local capability = self:ProjectSearchCapability(view, arguments)
	local interaction = capability.interaction
	local searchable = capability.searchable
	local pending = capability.pending
	local cooldown = capability.cooldown
	local busy = capability.busy
	local locale = GF.L or {}
	local hasRefreshableSource = refreshable(panel)
	local index, resultID = selectedResult(panel)
	local signUpEnabled = self:IsBrowseMode(view) and index ~= nil
	local apply = GF.Apply
	if signUpEnabled and apply and type(apply.CanSelectRow) == "function" then
		local ok, canSelect = pcall(
			apply.CanSelectRow, apply, index, resultID)
		signUpEnabled = ok and canSelect == true
	end
	local refreshEnabled = capability.allowed
	return {
		browseMode = self:IsBrowseMode(view),
		interactionEnabled = interaction.enabled,
		preserveDisabledAlpha = interaction.preserveDisabledAlpha,
		dismissAutoComplete = interaction.dismissAutoComplete,
		hideAdvancedFilter = interaction.hideAdvancedFilter,
		searchFieldEnabled = interaction.searchFieldEnabled,
		searchable = searchable,
		searchPending = pending,
		cooldown = cooldown,
		refreshPending = interaction.enabled and busy,
		refreshEnabled = refreshEnabled,
		headerRefreshEnabled = refreshEnabled,
		refreshLabel = hasRefreshableSource
			and (locale.REFRESH or "Refresh")
			or (locale.SEARCH or "Search"),
		resetEnabled = self:IsBrowseMode(view) and not interaction.leaderLookup,
		filterEnabled = interaction.enabled and searchable and not interaction.leaderLookup,
		signUpEnabled = signUpEnabled,
		quickJoinEnabled = self:IsQuickJoinEnabled(),
		autoJoinEnabled = self:IsAutoJoinEnabled(),
	}
end

function Presenter:ProjectNewbieSearchControl(view)
	local panel = browsePanel()
	local service = GF.NetEaseIdentityService
	local serviceEnabled, serviceCalled = invoke(service, "IsEnabled")
	local filter = GF.MythicPlusBrowseFilter
	local filterAvailable = filter
		and type(filter.IsNewbieOnly) == "function"
		and type(filter.SetNewbieOnly) == "function"
	local visible = self:IsBrowseMode(view)
		and self:IsMythicPlusSidebarMode(view)
		and serviceCalled and serviceEnabled == true
	local active = false
	if visible and filterAvailable then
		local projected = invoke(filter, "IsNewbieOnly")
		active = projected == true
	end
	local status
	if visible then
		status = invoke(service, "GetServiceStatus")
	end
	local unavailable = status == "offline" or status == "fault"
		or status == "no_response"
	local interactionEnabled = self:IsBrowseInteractionEnabled(view)
	local nativePending = searchPending(panel)
	local identityPending = false
	if active then
		local projected = invoke(service, "IsQueryPending")
		identityPending = projected == true
	end
	local pending = active and (nativePending or identityPending)
	local searchCapability = self:ProjectSearchCapability(view, {
		panel = panel,
	})
	local enabled = visible and filterAvailable
		and interactionEnabled and not nativePending
		and not identityPending
		and not unavailable
		and searchCapability.allowed == true
	local reason
	if not visible then
		reason = "newbie-filter-hidden"
	elseif not filterAvailable then
		reason = "newbie-search-unavailable"
	elseif unavailable then
		reason = status == "offline"
			and "netease-api-offline" or "netease-api-fault"
	elseif not interactionEnabled then
		reason = "interaction-disabled"
	elseif nativePending then
		reason = "search-pending"
	elseif identityPending then
		reason = "identity-query-pending"
	elseif searchCapability.allowed ~= true then
		reason = searchCapability.reason or "search-unavailable"
	end
	return {
		visible = visible,
		active = active,
		enabled = enabled,
		pending = pending,
		status = status,
		unavailable = unavailable,
		reason = reason,
	}
end

function Presenter:RequestNewbieSearch(view)
	local projection = self:ProjectNewbieSearchControl(view)
	if not projection.enabled then
		return false, projection.reason, projection
	end
	local _, called = invoke(
		GF.MythicPlusBrowseFilter,
		"SetNewbieOnly",
		true,
		{ notify = false })
	if not called then
		return false, "newbie-search-unavailable", projection
	end
	local active = invoke(GF.MythicPlusBrowseFilter, "IsNewbieOnly")
	if active ~= true then
		return false, "newbie-search-unavailable",
			self:ProjectNewbieSearchControl(view)
	end
	local started, searchCalled = invoke(GF.FindGroupTab, "DoSearch", {
		neteaseNewbieSearch = true,
		source = "neteaseNewbieSearchButton",
	})
	if searchCalled and started == true then
		return true, "search", self:ProjectNewbieSearchControl(view)
	end
	invoke(
		GF.MythicPlusBrowseFilter,
		"SetNewbieOnly",
		projection.active == true,
		{ notify = false })
	return false, "search-not-started",
		self:ProjectNewbieSearchControl(view)
end

function Presenter:PrepareAllGroupsSearch(panel)
	local changed, called = invoke(
		GF.MythicPlusBrowseFilter, "SetNewbieOnly", false)
	if called and changed == true and refreshable(panel or browsePanel()) then
		self:ApplyFilterRefresh()
	end
	return called and changed == true
end

function Presenter:GetFilterSelection()
	return self:GetSelection(browsePanel())
end

function Presenter:ResolveFilterSpec(selection)
	selection = selection or self:GetFilterSelection()
	local resolver = GF.FilterSpec
	local spec, called = invoke(resolver, "ResolveSpec", selection)
	if not called then
		return nil
	end
	if selection ~= nil or (type(spec) == "table"
		and spec.isMythicPlusBrowse == true)
	then
		return spec
	end
	return nil
end

function Presenter:GetFilterSpecKey(spec)
	if spec == nil then
		return ""
	end
	local parts = {
		tostring(spec.workspaceID or ""),
		tostring(spec.clientKey or ""),
		tostring(spec.layoutTier or ""),
		tostring(spec.navColumn or 0),
		tostring(spec.categoryID or ""),
		tostring(spec.selection and spec.selection.navKind or ""),
	}
	return table.concat(parts, ":")
end

function Presenter:GetFilterClient(spec)
	local filter = GF.Filter
	if not (spec and filter
		and type(filter.GetClientFilters) == "function")
	then
		return {}
	end
	local ok, values = pcall(
		filter.GetClientFilters, filter, spec.clientKey)
	return ok and type(values) == "table" and values or {}
end

function Presenter:GetFilterGlobal(spec)
	local filter = GF.Filter
	if filter and type(filter.GetGlobalFilters) == "function" then
		local ok, values = pcall(filter.GetGlobalFilters, filter, spec)
		if ok and type(values) == "table" then
			return values
		end
	end
	return {}
end

function Presenter:IsListFilterEnabled()
	local enabled, called = invoke(GF.ListFilter, "IsEnabled")
	return called and enabled == true or false
end

function Presenter:GetDisplayedDungeonDifficultyIndex(client)
	local value, called = invoke(
		GF.Filter, "GetClientDifficultyIndex", client, true)
	return called and tonumber(value) or 0
end

function Presenter:GetDisplayedRaidDifficultyIndex(client)
	local value, called = invoke(
		GF.Filter, "GetRaidDifficultyIndex", client)
	return called and tonumber(value) or 0
end

function Presenter:ApplyDungeonDifficulty(client, value)
	local _, called = invoke(
		GF.Filter, "ApplyDifficultyToClient", client, value, true)
	return called
end

function Presenter:ApplyRaidDifficulty(client, value)
	local _, called = invoke(
		GF.Filter, "ApplyRaidDifficultyToClient", client, value)
	return called
end

local FILTER_ACTIVITY_METHODS = {
	dungeon = {
		items = "GetDungeonActivityItems",
		options = "GetDungeonActivityOptions",
		allDisabled = "IsAllDungeonGroupsDisabled",
		setEnabled = "SetDungeonGroupEnabled",
		setAllDisabled = "SetAllDungeonGroupsDisabled",
		setLegacy = "SetPersistedActivities",
		setKeys = "SetPersistedActivityKeys",
	},
	raid = {
		items = "GetRaidActivityItems",
		options = "GetRaidActivityOptions",
		allDisabled = "IsAllRaidGroupsDisabled",
		setEnabled = "SetRaidGroupEnabled",
		setAllDisabled = "SetAllRaidGroupsDisabled",
		setLegacy = "SetPersistedRaidActivities",
		setKeys = "SetPersistedRaidActivityKeys",
	},
}

local function filterActivityMethods(kind)
	return FILTER_ACTIVITY_METHODS[kind]
end

function Presenter:HasFilterActivityGroup(kind)
	local methods = filterActivityMethods(kind)
	local filter = GF.Filter
	return methods ~= nil and filter ~= nil
		and type(filter[methods.items]) == "function"
		and type(filter[methods.options]) == "function"
		and type(filter[methods.allDisabled]) == "function"
		and type(filter[methods.setEnabled]) == "function"
		and type(filter[methods.setAllDisabled]) == "function"
		and type(filter[methods.setLegacy]) == "function"
		and type(filter[methods.setKeys]) == "function"
		and type(filter.IsGroupEnabled) == "function"
end

function Presenter:GetFilterActivityItems(kind)
	local methods = filterActivityMethods(kind)
	local values, called = invoke(GF.Filter, methods and methods.items)
	return called and type(values) == "table" and values or {}
end

function Presenter:GetFilterActivityOptions(kind, items)
	local methods = filterActivityMethods(kind)
	local values, called = invoke(
		GF.Filter, methods and methods.options, items)
	return called and type(values) == "table" and values or {}
end

function Presenter:IsAllFilterActivityGroupsDisabled(kind)
	local methods = filterActivityMethods(kind)
	local disabled, called = invoke(
		GF.Filter, methods and methods.allDisabled)
	return called and disabled == true or false
end

function Presenter:IsFilterActivityGroupEnabled(options, key, items)
	local enabled, called = invoke(
		GF.Filter, "IsGroupEnabled", options, key, items)
	return called and enabled == true or false
end

function Presenter:SetFilterActivityGroupEnabled(
	kind, options, key, enabled, items)
	local methods = filterActivityMethods(kind)
	local _, called = invoke(
		GF.Filter,
		methods and methods.setEnabled,
		options,
		key,
		enabled,
		items
	)
	return called
end

function Presenter:SetAllFilterActivityGroupsEnabled(kind, enabled)
	local methods = filterActivityMethods(kind)
	local filter = GF.Filter
	if not (methods and filter) then
		return false
	end
	local _, disabled = invoke(
		filter, methods.setAllDisabled, enabled ~= true)
	local _, legacy = invoke(filter, methods.setLegacy, nil)
	local persistedKeys
	if enabled ~= true then
		persistedKeys = {}
	end
	local _, keys = invoke(
		filter, methods.setKeys, persistedKeys)
	return disabled and legacy and keys
end

function Presenter:ClearSeasonDungeonActivityFilters()
	return self:SetAllFilterActivityGroupsEnabled("dungeon", false)
end

function Presenter:GetPlaystyleFilterLabel(index)
	local label, called = invoke(GF.Filter, "GetPlaystyleFilterLabel", index)
	return called and label or tostring(index or "")
end

function Presenter:SaveFilterClient(spec, values)
	local filter = GF.Filter
	if not (spec and type(values) == "table" and filter
		and type(filter.SaveCategoryClientFilters) == "function")
	then
		return false
	end
	filter:SaveCategoryClientFilters(spec.clientKey, values)
	if type(filter.ApplyClientFilterRefresh) == "function" then
		filter:ApplyClientFilterRefresh()
	end
	return true
end

function Presenter:SaveNotDeclinedFilter(spec, values)
	if type(values) == "table" and values.notDeclined == true then
		invoke(GF.Apply, "ClearRejectionFeedback")
	end
	return self:SaveFilterClient(spec, values)
end

function Presenter:ApplyFilterRefresh()
	local filter = GF.Filter
	if filter and type(filter.ApplyClientFilterRefresh) == "function" then
		filter:ApplyClientFilterRefresh()
		return true
	end
	return false
end

function Presenter:ResetFilter(selection, renderReset)
	selection = selection or self:GetFilterSelection()
	local filter = GF.Filter
	if selection and filter and type(filter.ResetCategory) == "function" then
		filter:ResetCategory(selection)
	end
	if type(renderReset) == "function" then
		renderReset()
	end
	return self:ApplyFilterRefresh()
end

function Presenter:RequestFilterSearch()
	local tab = GF.FindGroupTab
	if tab and type(tab.DoSearch) == "function" then
		tab:DoSearch()
		return true
	end
	return false
end

function Presenter:ProjectFilterSearchState(explicitState)
	local panel = browsePanel()
	local capability = self:ProjectSearchCapability(GF.SubtitleBar, {
		panel = panel,
		searching = explicitState == true,
	})
	local busy = capability.pending
	local cooldown = capability.cooldown
	local searchable = capability.searchable
	local interaction = capability.interactionEnabled
	return {
		label = (GF.L or {}).FILTER_REFRESH or "Search",
		pending = interaction and (busy or cooldown > 0),
		enabled = capability.allowed,
		busy = busy,
		cooldown = cooldown,
		searchable = searchable,
		interactionEnabled = interaction,
	}
end

function Presenter:SnapshotFilterContext()
	local selection = self:GetFilterSelection()
	local spec = self:ResolveFilterSpec(selection)
	return {
		selection = selection,
		spec = spec,
		key = self:GetFilterSpecKey(spec),
		client = self:GetFilterClient(spec),
		global = self:GetFilterGlobal(spec),
	}
end

-- Exposed for contract diagnostics; callers receive a copy and cannot mutate
-- the presenter-backed key set used by the compatibility metatable.
function Presenter:GetCompatibilityStateKeys()
	return shallowCopy(CONTROL_STATE_KEYS)
end
