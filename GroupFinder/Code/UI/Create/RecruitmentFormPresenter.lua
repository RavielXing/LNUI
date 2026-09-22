local _, GF = ...

-- RecruitmentFormPresenter owns the state projected by every recruitment
-- surface.  It deliberately has no frame construction or protected-action
-- dispatch: CreatePanel remains the only adapter for Blizzard EntryCreation
-- controls and the only synchronous publisher of a user click.
local Presenter = {}
GF.RecruitmentFormPresenter = Presenter
local NativeCreation = assert(
	GF.NativeCreationGateway,
	"NativeCreationGateway must load before RecruitmentFormPresenter"
)

Presenter.SURFACE_DRAWER = "meeting_stone_drawer"
Presenter.SURFACE_MYTHIC_PLUS = "mythic_plus_manager"
Presenter.SURFACE_MEETING_STONE_READ_ONLY =
	"meeting_stone_read_only_manager"

Presenter.MODE_CREATE = "create"
Presenter.MODE_EDIT = "edit"
Presenter.MODE_DEBUG_CENSORED = "debug-censored"

local function isTrue(value)
	return value == true
end

local function shallowCopy(source)
	if type(source) ~= "table" then
		return nil
	end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return nil
	end
	return method(owner, ...)
end

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

local function safeWidgetText(widget)
	local reader = widget and widget.GetText
	if type(reader) ~= "function" then
		return nil, false
	end
	local ok, value = pcall(reader, widget)
	return ok and value or nil, ok
end

local function numberFromWidget(widget)
	local value, readable = safeWidgetText(widget)
	if not readable or isSecret(value) then
		return 0
	end
	return tonumber(value) or 0
end

local function checked(widget)
	return widget ~= nil and type(widget.GetChecked) == "function"
		and widget:GetChecked() == true
end

local function workspaceOptionText(widget)
	local value, readable = safeWidgetText(widget)
	if not readable or isSecret(value) then
		return nil
	end
	if type(value) ~= "string" and type(value) ~= "number" then
		return nil
	end
	return tostring(value)
end

local function canReadWorkspaceOptions(panel)
	return panel ~= nil
		and panel.generalPlaystyle ~= nil
		and panel.ilvlEdit ~= nil
		and panel.mplusEdit ~= nil
		and panel.privateCheck ~= nil
		and panel.crossFactionCheck ~= nil
end

local function canProjectWorkspaceOptions(panel)
	if not canReadWorkspaceOptions(panel)
		or panel.editMode == true
		or panel.debugCensoredPreviewMode == true
	then
		return false
	end
	return invoke(GF.RecruitmentSession, "HasActive") ~= true
end

local function captureWorkspaceOptions(panel)
	if not canProjectWorkspaceOptions(panel) then
		return nil
	end
	local itemLevelText = workspaceOptionText(panel.ilvlEdit)
	local dungeonScoreText = workspaceOptionText(panel.mplusEdit)
	if itemLevelText == nil or dungeonScoreText == nil then
		return nil
	end
	return {
		generalPlaystyle = panel.generalPlaystyle,
		requiredItemLevelText = itemLevelText,
		requiredDungeonScoreText = dungeonScoreText,
		privateGroup = checked(panel.privateCheck),
		factionRestricted = checked(panel.crossFactionCheck),
	}
end

local function setWidgetText(widget, value)
	local writer = widget and widget.SetText
	if type(writer) ~= "function" or value == nil then
		return false
	end
	return pcall(writer, widget, tostring(value))
end

local function setWidgetChecked(widget, value)
	local writer = widget and widget.SetChecked
	if type(writer) ~= "function" then
		return false
	end
	return pcall(writer, widget, value == true)
end

local function projectWorkspaceOptions(panel, options)
	if not canProjectWorkspaceOptions(panel) or type(options) ~= "table" then
		return false
	end
	-- These are GF-owned controls. Blizzard's protected Name, Description and
	-- VoiceChat fields deliberately remain untouched, so their one native draft
	-- continues across a workspace switch.
	panel.generalPlaystyle = options.generalPlaystyle
	setWidgetText(panel.ilvlEdit, options.requiredItemLevelText)
	setWidgetText(panel.mplusEdit, options.requiredDungeonScoreText)
	setWidgetChecked(panel.privateCheck, options.privateGroup)
	setWidgetChecked(panel.crossFactionCheck, options.factionRestricted)
	invoke(panel, "UpdatePlaystyleDropdown")
	invoke(panel, "UpdateCrossFactionOption")
	invoke(panel, "UpdateRequirementLayout")
	return true
end

local function listingSession()
	return GF.RecruitmentSession
end

local function activeState(session, presentation)
	local methodName = presentation
		and "GetActiveCensoredPresentationState"
		or "GetActiveCensoredState"
	return invoke(session, methodName)
end

local function stateEquals(session, state, constantName)
	return type(state) == "table" and session ~= nil
		and state.state == session[constantName]
end

function Presenter:Bind(panel)
	if panel ~= nil then
		self.panel = panel
	end
	return self
end

function Presenter:SetWorkspaceContext(panel, context)
	panel = panel or self.panel
	local snapshot = shallowCopy(context)
	local previousContext = panel and panel.workspaceContext
		or self.workspaceContext
	local previousWorkspaceID = previousContext
		and previousContext.workspaceID
	local workspaceID = snapshot and snapshot.workspaceID
	local optionsByWorkspace = self._workspaceOptionsByID
	if type(optionsByWorkspace) ~= "table" then
		optionsByWorkspace = {}
		self._workspaceOptionsByID = optionsByWorkspace
	end
	if workspaceID ~= nil and canProjectWorkspaceOptions(panel) then
		if previousWorkspaceID ~= nil
			and previousWorkspaceID ~= workspaceID
		then
			local outgoing = captureWorkspaceOptions(panel)
			if outgoing ~= nil then
				optionsByWorkspace[previousWorkspaceID] = outgoing
				if self._workspaceOptionDefaults == nil then
					self._workspaceOptionDefaults = shallowCopy(outgoing)
				end
			end
		elseif optionsByWorkspace[workspaceID] == nil then
			local initial = captureWorkspaceOptions(panel)
			if initial ~= nil then
				optionsByWorkspace[workspaceID] = initial
				if self._workspaceOptionDefaults == nil then
					self._workspaceOptionDefaults = shallowCopy(initial)
				end
			end
		end
	end
	self.workspaceContext = snapshot
	if panel ~= nil then
		panel.workspaceContext = snapshot
	end
	if workspaceID ~= nil and previousWorkspaceID ~= nil
		and previousWorkspaceID ~= workspaceID
		and canProjectWorkspaceOptions(panel)
	then
		local target = optionsByWorkspace[workspaceID]
			or self._workspaceOptionDefaults
		if target ~= nil and projectWorkspaceOptions(panel, target) then
			optionsByWorkspace[workspaceID] = shallowCopy(target)
		end
	end
	if workspaceID ~= previousWorkspaceID then
		invoke(panel, "UpdateRequirementLayout")
	end
	return snapshot
end

function Presenter:GetWorkspaceContext(panel)
	panel = panel or self.panel
	return panel and panel.workspaceContext or self.workspaceContext
end

function Presenter:Transition(panel, mode, options)
	panel = panel or self.panel
	if panel == nil then
		return false
	end
	options = options or {}
	if mode == self.MODE_CREATE then
		panel.editMode = false
		panel.censoredResolutionMode = nil
		panel.debugCensoredPreviewMode = nil
	elseif mode == self.MODE_EDIT then
		panel.editMode = true
		panel.censoredResolutionMode = options.censoredResolution == true
		panel.debugCensoredPreviewMode = nil
	elseif mode == self.MODE_DEBUG_CENSORED then
		panel.editMode = true
		panel.censoredResolutionMode = options.censoredResolution == true
		panel.debugCensoredPreviewMode = true
	else
		return false
	end
	self.mode = mode
	return true
end

function Presenter:Reset(panel)
	panel = panel or self.panel
	if panel ~= nil then
		self:Transition(panel, self.MODE_CREATE)
		panel.selection = nil
		panel._favoriteSourceIdentity = nil
		panel._pendingFavoritePresetIdentity = nil
		panel.raidRequiredSpecIDs = nil
		invoke(panel.raidNeedsUI, "RefreshSelection")
	end
	self.selection = nil
	self.favoriteRecordIdentity = nil
	self.mode = self.MODE_CREATE
	return true
end

function Presenter:ResolveActivityID(node)
	if type(node) ~= "table" then
		return nil
	end
	-- Aggregate browse nodes may carry an activity union for search.  That
	-- union is never promoted into a recruitment choice; only a concrete leaf
	-- can cross the form boundary.
	if node.activityID == nil then
		local aggregate = node.activityIDsFilter or node.activityIDs
		if type(aggregate) == "table" and #aggregate > 0 then
			return nil
		end
	end
	local resolver = GF.NavData and GF.NavData.ResolveCreateActivityID
	if type(resolver) == "function" then
		return resolver(node)
	end
	if node.disabled or node.categoryBrowse then
		return nil
	end
	return tonumber(node.activityID)
end

function Presenter:IsSelectionCreateable(panel, node)
	panel = panel or self.panel
	node = node or (panel and panel.selection) or self.selection
	local activityID = self:ResolveActivityID(node)
	if activityID == nil then
		return false
	end
	local context = self:GetWorkspaceContext(panel)
	local workspaceID = context and context.workspaceID
	local view = GF.LFGWorkspaceView
	if view ~= nil and type(view.CanCreateSelection) == "function" then
		return view:CanCreateSelection(node, workspaceID) == true
	end
	local nav = GF.NavData
	if nav ~= nil and type(nav.CanCreateFromNode) == "function" then
		return nav.CanCreateFromNode(node) == true
	end
	return true
end

function Presenter:ActivityInfo(node, activityID)
	if node == nil and activityID == nil then
		node = self.selection
	end
	if type(node) == "table" and type(node.activityInfo) == "table"
		and (activityID == nil
			or tonumber(node.activityID) == tonumber(activityID))
	then
		return node.activityInfo
	end
	activityID = activityID or self:ResolveActivityID(node)
	if activityID == nil then
		return nil
	end
	local ok, info = pcall(
		NativeCreation.GetActivityInfoTable,
		NativeCreation,
		activityID
	)
	return ok and type(info) == "table" and info or nil
end

function Presenter:BuildActiveListingSelection(value)
	local activityID = tonumber(value)
	local activity = self:ActivityInfo(nil, activityID)
	if activityID == nil or activity == nil or activity.categoryID == nil then
		return nil
	end
	local title = activity.shortName
	if type(title) ~= "string" or title == "" then
		title = activity.fullName
	end
	return {
		key = ("active_listing_edit:%d"):format(activityID),
		label = title,
		categoryID = activity.categoryID,
		groupID = activity.groupFinderActivityGroupID,
		activityID = activityID,
		activityInfo = activity,
		filters = activity.filters,
		_editOnlyActiveListing = true,
	}
end

function Presenter:ResolveActiveListingSelection(activityID)
	local node = activityID and GF.NavData
		and GF.NavData.FindNodeByActivityID
		and GF.NavData.FindNodeByActivityID(activityID)
	if node and node.activityID == activityID and node.categoryID ~= nil then
		return node
	end
	return self:BuildActiveListingSelection(activityID)
end

function Presenter:Select(panel, node, options)
	panel = panel or self.panel
	options = options or {}
	self.selection = node
	self.favoriteRecordIdentity = options.favoriteRecordIdentity
	if panel ~= nil then
		panel.selection = node
		panel._favoriteSourceIdentity = options.favoriteRecordIdentity
		panel._pendingFavoritePresetIdentity = options.favoriteRecordIdentity
	end
	local activityID = self:ResolveActivityID(node)
	return {
		selection = node,
		activityID = activityID,
		activityInfo = self:ActivityInfo(node, activityID),
		createable = self:IsSelectionCreateable(panel, node),
	}
end

function Presenter:GetSurface(panel)
	panel = panel or self.panel
	if panel == nil or panel._mythicPlusSidebarMode ~= true then
		return self.SURFACE_DRAWER
	end
	local manager = GF.MythicPlusCreateManagerPanel
	if manager ~= nil and type(manager.IsMeetingStoneReadOnlyMode) == "function"
		and manager:IsMeetingStoneReadOnlyMode() == true
	then
		return self.SURFACE_MEETING_STONE_READ_ONLY
	end
	return self.SURFACE_MYTHIC_PLUS
end

function Presenter:ProjectSurface(panel)
	panel = panel or self.panel
	local session = listingSession()
	local surface = self:GetSurface(panel)
	local hasActive = invoke(session, "HasActive") == true
	local canPublish = invoke(session, "CanPublish") == true
	local canManage = invoke(session, "CanManageApplicants") == true
	local context = self:GetWorkspaceContext(panel)
	local selection = panel and panel.selection or self.selection
	local activityID = self:ResolveActivityID(selection)
	local mode = panel and panel.debugCensoredPreviewMode == true
		and self.MODE_DEBUG_CENSORED
		or (panel and panel.editMode == true
			and self.MODE_EDIT or self.MODE_CREATE)
	local managerSurface = surface ~= self.SURFACE_DRAWER
	return {
		surface = surface,
		mode = mode,
		workspaceID = context and context.workspaceID,
		workspaceKey = context and context.key,
		selection = selection,
		activityID = activityID,
		selectionCreateable = self:IsSelectionCreateable(panel, selection),
		hasActive = hasActive,
		canPublish = canPublish,
		canManage = canManage,
		readOnly = surface == self.SURFACE_MEETING_STONE_READ_ONLY
			or (managerSurface and not canPublish)
			or (mode == self.MODE_EDIT and not canManage),
	}
end

function Presenter:SelectionRequiresProtectedPrebuiltTitle(panel)
	panel = panel or self.panel
	local selected = panel and panel.selection or self.selection
	local activityID = self:ResolveActivityID(selected)
	if activityID == nil then
		return false
	end
	local activity = self:ActivityInfo(selected, activityID)
	local categoryID = selected.categoryID
		or (activity and activity.categoryID)
	local predicate = IsActivityLockedForCustomText
	if categoryID == nil or type(predicate) ~= "function" then
		return false
	end
	local ok, locked = pcall(predicate, categoryID, activityID)
	return ok and not isSecret(locked) and locked == true
end

function Presenter:HasCreationName(panel)
	panel = panel or self.panel
	return NativeCreation:HasSafeCreationName(panel and panel.nameEdit) == true
end

function Presenter:HasRequiredCreateFields(panel)
	local selected = self:GetRaidRequiredSpecs(panel)
	return (selected == nil or next(selected) ~= nil)
		and (self:HasCreationName(panel)
			or self:SelectionRequiresProtectedPrebuiltTitle(panel))
end

function Presenter:CaptureDraft(panel, options)
	panel = panel or self.panel
	options = options or {}
	local context = self:GetWorkspaceContext(panel)
	local prebuiltTitleReady = options.prebuiltTitleReady == true
		and self:SelectionRequiresProtectedPrebuiltTitle(panel)
	return {
		selection = panel and panel.selection or self.selection,
		editMode = panel and panel.editMode == true,
		workspaceID = context and context.workspaceID,
		generalPlaystyle = panel and panel.generalPlaystyle,
		hasCreationName = self:HasCreationName(panel)
			or prebuiltTitleReady,
		privateGroup = checked(panel and panel.privateCheck),
		factionRestricted = checked(panel and panel.crossFactionCheck),
		requiredItemLevel = numberFromWidget(panel and panel.ilvlEdit),
		requiredDungeonScore = numberFromWidget(panel and panel.mplusEdit),
		raidRequiredSpecIDs = self:GetRaidRequiredSpecs(panel),
	}
end

function Presenter:GetRaidRequiredSpecs(panel)
	panel = panel or self.panel
	local context = self:GetWorkspaceContext(panel)
	local needs = GF.RaidRecruitmentNeeds
	if not panel or not context or context.workspaceID ~= GF.WORKSPACE_RAID or not needs then
		return nil
	end
	if panel.raidRequiredSpecIDs == nil and GF.RaidRecruitmentPolicy then
		local published = GF.RaidRecruitmentPolicy:GetPublished()
		if published then panel.raidRequiredSpecIDs = needs:CopySelection(published.specIDs) end
	end
	return needs:ResolveSelection(panel.raidRequiredSpecIDs)
end

function Presenter:SetRaidRequiredSpec(panel, specID, selected)
	panel = panel or self.panel
	local context = self:GetWorkspaceContext(panel)
	local needs = GF.RaidRecruitmentNeeds
	if not panel or not context or context.workspaceID ~= GF.WORKSPACE_RAID
		or not needs or not needs:IsAvailableSpec(specID)
		or panel._protectedFieldsFormEnabled ~= true or panel.censoredResolutionMode
	then
		return false
	end
	panel.raidRequiredSpecIDs = self:GetRaidRequiredSpecs(panel)
	panel.raidRequiredSpecIDs[specID] = selected == true and true or nil
	invoke(panel, "UpdateManageState")
	return true
end

function Presenter:ToggleRaidRequiredRole(panel, role)
	panel = panel or self.panel
	local context = self:GetWorkspaceContext(panel)
	local needs = GF.RaidRecruitmentNeeds
	if not panel or not context or context.workspaceID ~= GF.WORKSPACE_RAID
		or not needs or panel._protectedFieldsFormEnabled ~= true or panel.censoredResolutionMode
	then
		return false
	end
	local selection = self:GetRaidRequiredSpecs(panel)
	local counts = needs:GetRoleCounts(selection)[role]
	if not counts or counts.total == 0 then return false end
	panel.raidRequiredSpecIDs = needs:SetRoleSelected(selection, role, counts.selected == 0)
	invoke(panel, "UpdateManageState")
	return true
end

function Presenter:ValidateDraft(panel, options)
	local policy = GF.RecruitmentDraftPolicy
	if policy == nil or type(policy.Validate) ~= "function" then
		return false, { code = "selection" }
	end
	local draft = self:CaptureDraft(panel, options)
	local valid, problem = policy:Validate(draft)
	if valid == true then
		return true, draft
	end
	return false, problem, draft
end

function Presenter:BuildParameters(panel, draft)
	local policy = GF.RecruitmentDraftPolicy
	if policy == nil or type(policy.BuildParameters) ~= "function" then
		return nil
	end
	return policy:BuildParameters(draft or self:CaptureDraft(panel))
end

function Presenter:DescribeProblem(problem, labels)
	labels = labels or GF.L or {}
	if type(problem) == "table" and problem.detail then
		return problem.detail
	end
	local messages = {
		selection = labels.NO_SELECTION or "Select an activity",
		active_listing = labels.CREATE_ALREADY_LISTED
			or LFG_LIST_CLEAR_ORPHANED_GROUP
			or "You already have an active listing",
		activity = labels.CREATE_NEED_ACTIVITY
			or "Select a specific activity difficulty",
		playstyle = labels.PLAYSTYLE_REQUIRED
			or GROUP_FINDER_PLAYSTYLE_REQUIRED
			or "Select playstyle",
		workspace = labels.MPLUS_CREATE_SCOPE_ERROR
			or "Select a current-season Mythic+ dungeon",
		keystone = LFG_AUTHENTICATOR_BUTTON_MYTHIC_PLUS_TOOLTIP
			or labels.CREATE_NEED_KEYSTONE
			or "M+ keystone required.",
		name = LFG_LIST_MUST_HAVE_NAME
			or labels.CREATE_NEED_NAME
			or "Name required.",
		raid_specs = labels.RAID_REQUIRED_SPECS_EMPTY
			or "Select at least one specialization.",
		cross_faction = labels.EDIT_CROSS_FACTION_BLOCKED
			or "Remove listing before changing cross-faction",
	}
	return messages[problem and problem.code]
		or labels.CREATE_FAILED
		or "Listing failed. Please try again"
end

function Presenter:GetListButtonText(panel, labels)
	panel = panel or self.panel
	labels = labels or GF.L or {}
	local session = listingSession()
	local active = invoke(session, "HasActive") == true
	local censorState = activeState(session, true)
	local pending = stateEquals(
		session,
		censorState,
		"ACTIVE_CENSOR_STATE_UNRESOLVED"
	)
	if panel and panel.censoredResolutionMode == true then
		return labels.CENSORED_ACTIVE_ENTRY_SUBMIT or "Submit changes"
	end
	if panel and panel.debugCensoredPreviewMode == true or active and pending then
		return labels.CENSORED_ACTIVE_ENTRY_HANDLE or "Resolve"
	end
	if panel and panel.editMode == true or active then
		return labels.SAVE_LISTING or "Save"
	end
	return labels.CREATE_LISTING or "List Group"
end

function Presenter:ProjectManageState(panel, facts)
	panel = panel or self.panel
	facts = facts or {}
	local surface = self:ProjectSurface(panel)
	local session = listingSession()
	local blocked = facts.channelBlocked == true
	local requiredComplete = facts.requiredComplete == true
	if panel and panel.debugCensoredPreviewMode == true then
		local resolving = panel.censoredResolutionMode == true
		return {
			surface = surface.surface,
			readOnly = not resolving,
			formEnabled = resolving,
			submitEnabled = not resolving or requiredComplete,
			submitMouseEnabled = true,
			removeEnabled = false,
			debugNameEnabled = resolving,
			debugDescriptionEnabled = resolving,
			preserveDisabledButtonAlpha = false,
			listButtonText = self:GetListButtonText(panel),
		}
	end

	local busy = invoke(session, "IsBusy") == true
	local canLead = surface.canPublish
	local canManage = surface.canManage
	local hasActive = surface.hasActive
	local censorState = activeState(session, false)
	local resolving = panel and panel.censoredResolutionMode == true
	local unresolved = stateEquals(
		session,
		censorState,
		"ACTIVE_CENSOR_STATE_UNRESOLVED"
	)
	local unknown = stateEquals(
		session,
		censorState,
		"ACTIVE_CENSOR_STATE_UNKNOWN"
	)
	local ordinaryCensorBlocked = not resolving and (unresolved or unknown)
	local resolutionValid = not resolving or unresolved
	local editMode = panel and panel.editMode == true
	local pendingDialogSubmission = editMode and not resolving and unresolved
	local availabilityProblem = surface.surface == self.SURFACE_MYTHIC_PLUS
		and not hasActive
		and GF.Availability ~= nil
		and type(GF.Availability.GetPremadeBlockMessage) == "function"
		and GF.Availability:GetPremadeBlockMessage() or nil
	local availabilityBlocked = availabilityProblem and true or false
	local selectionCreateable = editMode
		and self:ResolveActivityID(panel and panel.selection) ~= nil
		or self:IsSelectionCreateable(panel)
	local formCanEdit = (not editMode or canManage)
		and not busy and not ordinaryCensorBlocked
	if surface.surface ~= self.SURFACE_DRAWER then
		formCanEdit = canLead and formCanEdit
	end
	local submitCanManage = (not editMode or canManage)
		and not busy and not ordinaryCensorBlocked
	local formEnabled = selectionCreateable and not blocked
		and not availabilityBlocked and formCanEdit
	return {
		surface = surface.surface,
		readOnly = surface.readOnly or not formEnabled,
		formEnabled = formEnabled,
		submitEnabled = pendingDialogSubmission
			and canLead and not busy and not blocked
			or (canLead and submitCanManage and not blocked
				and not availabilityBlocked and selectionCreateable
				and requiredComplete and resolutionValid),
		submitMouseEnabled = true,
		removeEnabled = canLead and hasActive and not blocked and not busy,
		mythicPlusReadOnly = surface.surface ~= self.SURFACE_DRAWER
			and not canLead,
		showCompleteDisabledForm = not formEnabled and not blocked,
		preserveDisabledButtonAlpha = surface.surface ~= self.SURFACE_DRAWER,
		selectionCreateable = selectionCreateable,
		listButtonText = self:GetListButtonText(panel),
	}
end

function Presenter:PlanDrawerOpen(panel, options)
	panel = panel or self.panel
	options = options or {}
	local session = listingSession()
	local debugPreview = options.debugCensoredPreview == true
	local hasActive = invoke(session, "HasActive") == true
	local mode = options.mode
		or (debugPreview and self.MODE_DEBUG_CENSORED)
		or (hasActive and self.MODE_EDIT or self.MODE_CREATE)
	local plan = {
		debugPreview = debugPreview,
		hasActive = hasActive,
		mode = mode,
		selectionCreateable = self:IsSelectionCreateable(panel),
	}
	if debugPreview then
		plan.allowed = true
		return plan
	end
	if mode == self.MODE_EDIT and not hasActive then
		plan.denial = "missing_active"
		return plan
	end
	if mode == self.MODE_EDIT
		and session ~= nil
		and type(session.CanManageApplicants) == "function"
		and session:CanManageApplicants() ~= true
	then
		plan.denial = "cannot_manage"
		return plan
	end
	if mode == self.MODE_EDIT then
		local censorState = activeState(session, false)
		local unresolved = stateEquals(
			session,
			censorState,
			"ACTIVE_CENSOR_STATE_UNRESOLVED"
		)
		if unresolved and options.censoredResolution ~= true then
			plan.denial = "censored_dialog"
			return plan
		end
		if options.censoredResolution == true and not unresolved then
			plan.denial = "censored_changed"
			return plan
		end
	end
	if mode == self.MODE_CREATE then
		local availability = GF.Availability
		local problem = availability
			and type(availability.GetPremadeBlockMessage) == "function"
			and availability:GetPremadeBlockMessage() or nil
		if problem then
			plan.denial = "availability"
			plan.message = problem
			return plan
		end
		if not plan.selectionCreateable then
			plan.denial = "selection"
			return plan
		end
	end
	plan.allowed = true
	return plan
end

function Presenter:GetDrawerTitle(panel, labels)
	panel = panel or self.panel
	labels = labels or GF.L or {}
	local session = listingSession()
	local title = invoke(session, "GetActiveActivityTitle")
	if type(title) ~= "string" or title == "" then
		local selected = panel and panel.selection or self.selection
		if selected and selected.activityID and not selected.customBucket then
			local activity = self:ActivityInfo(selected, selected.activityID)
			if GF.UI and type(GF.UI.GetCategoryTitle) == "function" then
				title = GF.UI.GetCategoryTitle(selected.categoryID, activity)
			end
		else
			title = selected and selected.label
		end
	end
	if (type(title) ~= "string" or title == "")
		and panel and panel.debugCensoredPreviewMode == true
	then
		title = labels.DEBUG_CENSORED_TEST_DRAWER_TITLE
			or "Pending status test"
	end
	if type(title) ~= "string" or title == "" then
		title = labels.TAB_CREATE or "Create Listing"
	end
	return title
end
