local addonName, GF = ...

-- RuntimeLifecycle is the sole owner of startup ordering and of the addon's
-- LFG event routing. Bootstrap owns the one WoW event frame and forwards each
-- event here; feature modules continue to own their own domain state.
GF.RuntimeLifecycle = GF.RuntimeLifecycle or {}
local Lifecycle = GF.RuntimeLifecycle
local Compat = GF.Compat

local function call(owner, methodName, ...)
	local method = owner and owner[methodName]
	if method then
		return method(owner, ...)
	end
end

local blizzardDependencies = {
	"Blizzard_SharedXML",
	"Blizzard_Menu",
	"Blizzard_GroupFinder",
	"Blizzard_UIPanelTemplates",
	"Blizzard_Settings_Shared",
}

function Lifecycle:EnsureBlizzardAddons()
	if GF._blizzardAddonsReady == true then
		return true
	end
	local loader = Compat and Compat.LoadAddOn
	if type(loader) ~= "function" then
		GF._blizzardAddonsFailure = {
			reason = "compat-loader-unavailable",
		}
		return false, nil, "compat-loader-unavailable"
	end
	for index = 1, #blizzardDependencies do
		local dependency = blizzardDependencies[index]
		local loaded, reason = loader(dependency)
		if loaded ~= true then
			GF._blizzardAddonsReady = nil
			GF._blizzardAddonsFailure = {
				addon = dependency,
				reason = reason or "load-failed",
			}
			return false, dependency, reason or "load-failed"
		end
	end
	GF._blizzardAddonsReady = true
	GF._blizzardAddonsFailure = nil
	return true
end

-- Preserve the public bootstrap API used by Core and UI modules.
function GF.EnsureBlizzardAddons()
	return Lifecycle:EnsureBlizzardAddons()
end

local dispatcher
local receivesIncrementalSearchUpdates = false
local availabilityRecoveryInstalled = false
local handlingLfgAvailabilityUpdate = false
local seasonCatalogReadinessTicket = 0
local seasonCatalogRetryDelays = { 0, 0.75, 2, 5 }
local runtimeInitialized = false
local restrictedLauncherInitialized = false
local runtimeEventsActive = false
local playerLoginHandled = false
local activateRuntimeEvents

local function hasNavigationProjection()
	local getter = GF.NavData and GF.NavData.GetLoadedTree
	-- Legacy adapters do not expose the passive projection query.
	return type(getter) ~= "function" or getter() ~= nil
end

local incrementalSearchEvents = {
	"LFG_LIST_UPDATE_SEARCH_RESULTS",
}

function Lifecycle:SetLfgUpdateListening(shouldListen)
	shouldListen = shouldListen == true
	if receivesIncrementalSearchUpdates == shouldListen then
		return
	end

	receivesIncrementalSearchUpdates = shouldListen
	if not dispatcher or not runtimeEventsActive then
		return
	end
	for index = 1, #incrementalSearchEvents do
		local eventName = incrementalSearchEvents[index]
		if shouldListen then
			dispatcher:RegisterEvent(eventName)
		else
			dispatcher:UnregisterEvent(eventName)
		end
	end
end

function GF.SetLfgUpdateListening(shouldListen)
	return Lifecycle:SetLfgUpdateListening(shouldListen)
end

local function lfgDispatchIsSuspended()
	local availability = GF.Availability
	return availability and availability.ShouldProcessLfgEvent
		and availability:ShouldProcessLfgEvent() ~= true
end

local function refreshAvailabilityProjection(snapshot)
	-- Availability owns the chat-lockdown state and native-control release.
	-- RuntimeLifecycle owns the recovery edge so leaving a restricted scene
	-- cannot leave hidden UI projections stale while no LFG event is emitted.
	call(GF.MainFrame, "OnAvailabilityUpdate")
	call(GF.FloatButton, "RefreshAlert", snapshot)
end

local function installAvailabilityRecovery()
	if availabilityRecoveryInstalled then
		return
	end
	local availability = GF.Availability
	if not (availability and availability.AddListener) then
		return
	end
	availabilityRecoveryInstalled = true
	availability:AddListener(function(snapshot, reason)
		if reason == "restricted" or reason == "available" then
			call(GF.ApplicantAlertService, "HandleLifecycleChanged", "availability-" .. reason)
			call(GF.RaidRecruitmentPolicy, "OnAvailabilityChanged", snapshot)
			call(GF.InvitationScheduler, "OnInviteAvailabilityChanged", reason == "available")
			-- LFG_LIST_AVAILABILITY_UPDATE completes the same projection in its
			-- authoritative handler. Only zone/world-driven chat transitions need
			-- the listener to supply the otherwise-missing recovery edge.
			if handlingLfgAvailabilityUpdate then
				call(GF.FloatButton, "RefreshAlert", snapshot)
			else
				refreshAvailabilityProjection(snapshot)
			end
		end
	end)
end

local handlers = {}

local function refreshCreateQueueHint()
	local panel = GF.ApplicantsPanel
	if not lfgDispatchIsSuspended() and panel
		and panel.IsPresentationVisible and panel:IsPresentationVisible()
	then
		call(panel, "UpdateEmptyHint")
	end
end

local function evaluateRuntimePolicy()
	local policy = GF.RuntimePolicy
	if not (policy and type(policy.EvaluateCurrentPlayer) == "function") then
		return "invalid", "missing-runtime-policy"
	end
	local ok, status, reason = pcall(
		policy.EvaluateCurrentPlayer, policy)
	if not ok or (status ~= "allowed" and status ~= "denied"
		and status ~= "invalid" and status ~= "pending")
	then
		return "invalid", ok and "invalid-policy-status"
			or "runtime-policy-error"
	end
	return status, reason
end

local function showRuntimePolicyDialog(status, reason)
	return call(GF.RuntimePolicyDialog, "Show", status, reason)
end

local function initializeAllowedRuntime()
	if runtimeInitialized then
		return true
	end

	-- The order is intentional. In particular, service/prefix initialization
	-- precedes Blizzard entry takeover, while the 12.1 censored handoff is
	-- installed before Hook.Refresh loads Blizzard_GroupFinder.
	call(GF.Availability, "Init")
	GF.InitDB()
	call(GF.RaidSeekingChannelNoticeFilter, "Init")
	call(GF.RaidSeekingChannelListFilter, "Init")
	call(GF.RaidSeekingChatService, "Start")
	call(GF.MythicPlusBrowseFilter, "Init")
	call(GF.NetEaseIdentityService, "Init")
	call(GF.LaonongModule, "AddListener", function()
		call(GF.FindGroupTab, "RefreshList", { preserveScroll = true, skipSnapshot = true })
		call(GF.ApplicantsPanel, "OnLaonongFanSourceChanged")
	end)
	call(GF.LaonongModule, "Init")
	call(GF.NavCatalogOverlay, "Initialize")
	call(GF.VersionDiscoveryService, "Init")
	call(GF.MythicPlusServices, "Init")
	call(GF.MythicPlusAnnouncementChatFilter, "Init")
	call(GF.InstanceGatewayService, "Init")
	-- Views must restore anchors only after the client has loaded account data
	-- and InitDB has rebound the repository; file-scope UI runs too early.
	call(GF.InstanceGatewayOverlay, "Init")
	call(GF.InstanceGatewayEditMode, "Init")
	call(GF.Blocklist, "Init")
	call(GF.BlacklistMenu, "Init")
	call(GF.CensoredActiveEntryDialog, "Init")
	if GF.Hook and GF.Hook.Refresh then
		GF.Hook.Refresh()
	end
	call(GF.MinimapButton, "Init")
	call(GF.FloatButton, "Init")
	call(GF.TitanPanel, "Init")
	GF.NavData.RequestRefresh()
	runtimeInitialized = true
	GF._addonLoaded = true
	installAvailabilityRecovery()
	if activateRuntimeEvents then
		activateRuntimeEvents()
	end
	return true
end

local function initializeRestrictedLauncher()
	if restrictedLauncherInitialized then
		return true
	end

	-- A denied character keeps one inert launcher so the refusal is presented
	-- only after an explicit user action. The saved-variable repository is the
	-- minimum dependency needed to restore the launcher's scale and position;
	-- no Group Finder business service or business event is activated here.
	GF.InitDB()
	call(GF.FloatButton, "SetRuntimePolicyRestricted", true)
	call(GF.FloatButton, "Init")
	restrictedLauncherInitialized = true
	return true
end

function Lifecycle:EnsureSeasonRatingDefaultBinding()
	if type(InCombatLockdown) == "function" and InCombatLockdown() then
		self.seasonRatingBindingPending = true
		return false
	end
	if not (type(GetCurrentBindingSet) == "function" and type(GetBindingKey) == "function"
		and type(GetBindingAction) == "function" and type(SetBinding) == "function"
		and type(SaveBindings) == "function") then return false end
	local bindingSet = GetCurrentBindingSet()
	local profile = bindingSet == 1 and "account"
		or (bindingSet == 2 and type(UnitGUID) == "function" and UnitGUID("player"))
	local db = GF.GetDB and GF.GetDB()
	if type(profile) ~= "string" or profile == "" or type(db) ~= "table" then
		self.seasonRatingBindingPending = true
		return false
	end
	local initialized = db.seasonRatingBindingDefaults
	local revision = type(initialized) == "table" and initialized[profile] or nil
	if revision == 3 then
		self.seasonRatingBindingPending = nil
		return true
	end
	local action = "GROUPFINDER_MPLUS_TELEPORT" -- Keep existing user bindings by ID.
	local oldKeys = { GetBindingKey(action) }
	local changes = {}
	local function assign(key, command)
		local previous = GetBindingAction(key)
		if previous == "" then previous = nil end
		if previous == command then return true end
		if not SetBinding(key, command) then
			-- Restore every successful mutation before retrying the same profile.
			for index = #changes, 1, -1 do
				SetBinding(changes[index].key, changes[index].previous)
			end
			self.seasonRatingBindingPending = true
			return false
		end
		changes[#changes + 1] = { key = key, previous = previous }
		return true
	end
	-- The requested revision forces Shift+Z for every existing profile, even
	-- customized/unbound ones, and replaces any other action on that chord.
	if not assign("SHIFT-Z", action) then return false end
	for _, key in ipairs(oldKeys) do
		if key ~= "SHIFT-Z" and not assign(key, nil) then return false end
	end
	if #changes > 0 then
		SaveBindings(bindingSet)
	end
	-- Only an initialization marker is saved here; native settings own the keys.
	-- After this forced revision, later manual changes stay player-owned.
	if type(initialized) ~= "table" then
		initialized = {}
		db.seasonRatingBindingDefaults = initialized
	end
	initialized[profile] = 3
	self.seasonRatingBindingPending = nil
	return true
end

local function handleAllowedPlayerLogin()
	if playerLoginHandled then
		return true
	end
	playerLoginHandled = true
	Lifecycle:EnsureSeasonRatingDefaultBinding()
	call(GF.UserLetter, "OnLogin")
	call(GF.NetEaseIdentityService, "OnPlayerLogin")
	call(GF.LaonongModule, "RefreshWithRetry")
	call(GF.BlacklistMenu, "Init")
	if GF.Hook and GF.Hook.Refresh then
		GF.Hook.Refresh()
	end
	if GF.ValidateLSMFontKeyAfterLogin then
		GF.ValidateLSMFontKeyAfterLogin()
	end
	call(GF.Blocklist, "ClearReadableTitleTokens")
	call(GF.Apply, "OnGroupRosterChanged")
	call(GF.Apply, "InitInviteDialogHooks")
	call(GF.Apply, "QueueAutoAcceptInvite")
	-- Navigation is a presentation projection. Its first consumer builds it;
	-- logging in alone must not scan every activity for an unopened workspace.
	if hasNavigationProjection() then GF.NavData.Rebuild() end
	call(GF.NavTree, "Refresh")
	call(GF.FloatButton, "RefreshAlert")
	call(GF.JoinAnnounce, "Init")
	call(GF.CensoredActiveEntryDialog, "Refresh", "PLAYER_LOGIN", {
		showPopup = true,
	})
	if GF.ShowLoginMessage then
		-- GF.ShowLoginMessage()--lnui
	end
	return true
end

local function scheduleSeasonCatalogReadiness()
	seasonCatalogReadinessTicket = seasonCatalogReadinessTicket + 1
	if not hasNavigationProjection() then return false end
	local ticket = seasonCatalogReadinessTicket
	local function run(attempt)
		if ticket ~= seasonCatalogReadinessTicket then
			return
		end
		if attempt > 1 then
			-- A pending read may have captured a structurally valid but incomplete
			-- Journal snapshot. Re-read it instead of repeatedly testing that same
			-- pre-world catalog.
			call(GF.NavCatalog, "ClearJournalCache")
		end
		call(GF.NavData, "ClearBuildCaches")
		local getter = GF.NavCatalog and GF.NavCatalog.GetSeasonInstances
		local dungeonState, raidState = "pending", "pending"
		if type(getter) == "function" then
			local _, resolvedDungeonState = getter("dungeon")
			local _, resolvedRaidState = getter("raid")
			dungeonState = resolvedDungeonState or "ready"
			raidState = resolvedRaidState or "ready"
		end
		call(GF.MainFrame, "OnAvailabilityUpdate", { navigationReadiness = true })
		if dungeonState == "ready" and raidState == "ready" then
			return
		end
		local delay = seasonCatalogRetryDelays[attempt + 1]
		if delay and C_Timer and type(C_Timer.After) == "function" then
			C_Timer.After(delay, function()
				run(attempt + 1)
			end)
		end
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(seasonCatalogRetryDelays[1], function()
			run(1)
		end)
	else
		run(1)
	end
	return true
end

function Lifecycle:RequestNavigationReadiness()
	if not runtimeInitialized then return false end
	return scheduleSeasonCatalogReadiness()
end

function handlers.ADDON_LOADED(loadedName)
	if loadedName ~= addonName then
		if not runtimeInitialized then
			return
		end
		call(GF.NavCatalogOverlay, "OnAddonLoaded", loadedName)
		call(GF.LaonongModule, "OnAddonLoaded", loadedName)
		call(GF.RaidSeekingChatWhisperPopBridge, "OnAddonLoaded", loadedName)
		call(GF.RaidSeekingChannelListFilter, "OnAddonLoaded", loadedName)
		if GF._addonLoaded and GF.Hook and GF.Hook.Refresh then
			GF.Hook.Refresh()
		end
		if loadedName == "Blizzard_EncounterJournal" then
			call(GF.NavCatalog, "ClearJournalCache")
			scheduleSeasonCatalogReadiness()
		end
		return
	end
	local status = evaluateRuntimePolicy()
	if status == "allowed" then
		initializeAllowedRuntime()
	elseif status == "denied" then
		initializeRestrictedLauncher()
	end
end

function handlers.PLAYER_LOGIN()
	local status, reason = evaluateRuntimePolicy()
	if status ~= "allowed" then
		if status == "denied" then
			initializeRestrictedLauncher()
		else
			showRuntimePolicyDialog(status, reason)
		end
		return false
	end
	initializeAllowedRuntime()
	return handleAllowedPlayerLogin()
end

function handlers.PLAYER_REGEN_ENABLED()
	if runtimeInitialized and Lifecycle.seasonRatingBindingPending then
		Lifecycle:EnsureSeasonRatingDefaultBinding()
	end
	call(GF.UserLetter, "TryShow")
	call(GF.MainFrame, "ResumePreload")
	call(GF.NavCatalogOverlay, "Resume")
end

function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
	if runtimeInitialized and Lifecycle.seasonRatingBindingPending then
		Lifecycle:EnsureSeasonRatingDefaultBinding()
	end
	if runtimeInitialized then call(GF.UserLetter, "OnEnteringWorld") end
	if runtimeInitialized then call(GF.RaidRecruitmentPolicy, "OnEnteringWorld", isInitialLogin, isReloadingUi) end
	if isInitialLogin == true or isReloadingUi == true then
		-- PLAYER_LOGIN can precede the final expansion/Encounter Journal
		-- snapshot. Rebuild the two eager season roots from a post-world
		-- generation so a cold placeholder is replaced before normal use.
		call(GF.NavCatalog, "ClearJournalCache")
		call(GF.NavData, "ClearBuildCaches")
		call(GF.NavData, "RequestRefresh")
		call(GF.MainFrame, "OnAvailabilityUpdate")
		scheduleSeasonCatalogReadiness()
	end
	if runtimeInitialized then call(GF.RaidSeekingService, "OnEnteringWorld", isInitialLogin, isReloadingUi) end
	-- Reconcile reload/login/world-transition recovery without making the raw
	-- API the owner of the opening/closing animation interval.
	call(GF.FloatButton, "SyncPetBattleVisibility")
	call(GF.InvitationScheduler, "OnInviteAvailabilityChanged", true)
end

function handlers.PLAYER_LOGOUT()
	if runtimeInitialized then call(GF.RaidRecruitmentPolicy, "OnLogout") end
	if runtimeInitialized then call(GF.RaidSeekingService, "OnLogout") end
end

function handlers.PET_BATTLE_OPENING_START()
	-- Opening is the earliest authoritative edge. Keep the launcher hidden
	-- through PET_BATTLE_OVER while Blizzard is still playing the exit scene.
	call(GF.FloatButton, "SetPetBattleSuppressed", true)
	call(GF.InvitationScheduler, "OnInviteAvailabilityChanged")
end

function handlers.PET_BATTLE_CLOSE()
	-- Reprojection, rather than a direct Show(), preserves the user's launcher
	-- preference and any later runtime visibility constraints.
	call(GF.FloatButton, "SetPetBattleSuppressed", false)
	call(GF.InvitationScheduler, "OnInviteAvailabilityChanged", true)
end

function handlers.LFG_LIST_SEARCH_RESULTS_RECEIVED()
	call(GF.LaonongModule, "Refresh")
	if not lfgDispatchIsSuspended() then
		call(GF.ApplicationService, "ReconcileApplications", false)
		call(GF.Apply, "QueueAutoAcceptInvite")
		call(GF.MainFrame, "OnSearchResults")
	end
end

function handlers.LFG_LIST_SEARCH_FAILED()
	if not lfgDispatchIsSuspended() then
		call(GF.MainFrame, "OnSearchFailed")
	end
end

function handlers.LFG_LIST_SEARCH_RESULT_UPDATED(resultID)
	call(GF.MythicPlusGroupReadyTeleportService,
		"OnSearchResultUpdated", resultID)
	if not lfgDispatchIsSuspended() then
		call(GF.ApplicationService, "ReconcileApplications", false)
		-- Blizzard's native invite dialog also waits for this event before
		-- re-reading the stable invited/pendingStatus state.
		call(GF.Apply, "QueueAutoAcceptInvite")
		if receivesIncrementalSearchUpdates then
			call(GF.FindGroupTab, "OnSearchResultUpdated", resultID)
		end
		refreshCreateQueueHint()
	end
end

function handlers.LFG_LIST_UPDATE_SEARCH_RESULTS()
	if not lfgDispatchIsSuspended() then
		call(GF.ApplicationService, "ReconcileApplications", false)
		call(GF.FindGroupTab, "OnSearchResultsUpdated")
	end
end

function handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(resultID, newStatus, oldStatus)
	call(GF.MythicPlusGroupReadyTeleportService,
		"OnApplicationStatusUpdated", resultID, newStatus)
	if lfgDispatchIsSuspended() then
		return
	end
	local outcome = call(GF.ApplicationService, "OnApplicationStatusUpdated", resultID, newStatus, oldStatus)
	call(GF.Apply, "OnApplicationStatusObserved", resultID, newStatus, outcome)
	if newStatus == "invited" then
		call(GF.Apply, "QueueAutoAcceptInvite")
	end
	call(GF.FindGroupTab, "OnApplicationStatusUpdated", resultID, newStatus)
	call(GF.JoinAnnounce, "OnApplicationStatusUpdated", resultID, newStatus)
	call(GF.FloatButton, "RefreshAlert")
	refreshCreateQueueHint()
end

function handlers.LFG_LIST_JOINED_GROUP(resultID)
	-- groupName is protected text; current-group identity consumes only the
	-- result ID and the separate GROUP_JOINED party GUID.
	call(GF.Apply, "OnJoinedGroup", resultID)
	call(GF.MythicPlusGroupReadyTeleportService, "OnJoinedGroup", resultID)
end

function handlers.LFG_LIST_AVAILABILITY_UPDATE()
	-- Navigation and the seasonal Mythic+ scope share the availability cache.
	-- Clear it first so a scheduled season rebuild cannot consume login data.
	if GF.NavData and GF.NavData.ClearBuildCaches then
		GF.NavData.ClearBuildCaches()
	end
	call(GF.MythicPlusSeason, "RequestRefresh", "LFG_LIST_AVAILABILITY_UPDATE")

	local availability = GF.Availability
	if availability and availability.UpdateRestrictedState then
		handlingLfgAvailabilityUpdate = true
		local ok, restricted = pcall(
			availability.UpdateRestrictedState,
			availability)
		handlingLfgAvailabilityUpdate = false
		if not ok then
			error(restricted, 0)
		end
		if restricted then
			-- EnterRestricted hides the main frame. Still mark its navigation
			-- dirty so leaving the restriction cannot restore old branches.
			call(GF.MainFrame, "OnAvailabilityUpdate")
			return
		end
	end
	-- Search-result data can be protected for the exact instant at which a
	-- premade joins. Once Blizzard reports LFG availability again, let the
	-- full-party service retry only the result ID supplied by the official
	-- accepted/joined event.
	call(GF.MythicPlusGroupReadyTeleportService,
		"OnLfgListAvailabilityUpdated")
	call(GF.MainFrame, "OnAvailabilityUpdate")
end

local function handlePremadePermissionUpdate()
	-- Blizzard re-evaluates native Group Finder buttons on these events. Ask
	-- LFGList to publish its authoritative activity update before rebuilding.
	call(GF.NavData, "RequestRefresh")
	call(GF.MainFrame, "OnPremadePermissionUpdate")
end

function handlers.PLAYER_LEVEL_CHANGED()
	-- Level gates share the archive authorization generation. Clear them here;
	-- this event does not guarantee a second availability update before redraw.
	call(GF.NavData, "ClearBuildCaches")
	call(GF.NavData, "RequestRefresh")
	call(GF.MainFrame, "OnAvailabilityUpdate")
end
handlers.TRIAL_STATUS_UPDATE = handlePremadePermissionUpdate

function handlers.LFG_LIST_ACTIVE_ENTRY_UPDATE(createdNew)
	-- The 12.1 payload is nullable. Relist consumes the original value; legacy
	-- projections continue to consume a strict boolean.
	local createdEventValue = createdNew
	createdNew = createdEventValue == true
	local listing = GF.RecruitmentSession
	local hasActive = listing and listing.HasActive
		and listing:HasActive() == true
	-- Release ended recruitment's custom handle and native applicant glow
	-- before optional feature refreshes or the suspended-dispatch boundary.
	if not hasActive then
		call(GF.ApplicantAlertService, "SyncBaseline", hasActive, createdNew)
	end
	call(GF.LaonongModule, "Refresh")
	call(GF.RaidSeekingService, "OnRecruitmentChanged", hasActive, createdEventValue)
	call(GF.MythicPlusGroupReadyTeleportService,
		"OnActiveEntryUpdated", hasActive)
	call(GF.CurrentGroupProjection, "OnActiveEntryUpdated")

	call(listing, "SyncEntryOwnership", hasActive)
	call(GF.RaidRecruitmentPolicy, "OnActiveEntryChanged", hasActive, createdEventValue)
	local questCreateOutcome = call(
		GF.QuestRecruitmentBridge,
		"HandleActiveEntryChanged",
		hasActive,
		createdNew
	)
	local bumpOutcome = call(
		listing,
		"HandleRelistEntryChanged",
		hasActive,
		createdEventValue)
	call(GF.InvitationScheduler, "HandleActiveEntryChanged", hasActive, createdNew)
	call(GF.RaidRecruitmentPolicy, "Queue")
	call(GF.CensoredActiveEntryDialog, "Refresh", "LFG_LIST_ACTIVE_ENTRY_UPDATE")
	if hasActive then
		call(GF.ApplicantAlertService, "SyncBaseline", hasActive, createdNew)
	end
	if lfgDispatchIsSuspended() then
		return
	end

	call(GF.MainFrame, "OnActiveEntryUpdate", {
		hasActive = hasActive,
		createdNew = createdNew,
		questCreateOutcome = questCreateOutcome,
		bumpOutcome = bumpOutcome,
		bumpResolved = true,
		fromActiveEntryEvent = true,
	})
end

function handlers.LFG_LIST_CENSORED_ACTIVE_ENTRY_UPDATE(isCensored)
	-- Censorship changes the safe presentation boundary of the synthetic
	-- current-group row. Invalidate its generation before repainting so an
	-- opaque voice token can never survive into a censored row.
	call(GF.CurrentGroupProjection, "OnActiveEntryUpdated")
	if not lfgDispatchIsSuspended() then
		call(GF.FindGroupTab, "RefreshList", {
			preserveScroll = true,
		})
	end
	call(GF.CensoredActiveEntryDialog, "Refresh",
		"LFG_LIST_CENSORED_ACTIVE_ENTRY_UPDATE", {
			showPopup = isCensored == true,
		})
end

function handlers.LFG_LIST_REVEALED_CENSORED_ACTIVE_ENTRY()
	-- Revealing changes presentation only; the unresolved query remains the
	-- authority for whether updates and relists are blocked.
	call(GF.CurrentGroupProjection, "OnActiveEntryUpdated")
	if not lfgDispatchIsSuspended() then
		call(GF.FindGroupTab, "RefreshList", {
			preserveScroll = true,
		})
	end
	call(GF.CensoredActiveEntryDialog, "Refresh",
		"LFG_LIST_REVEALED_CENSORED_ACTIVE_ENTRY")
end

function handlers.LFG_LIST_ENTRY_CREATION_FAILED()
	local bumpOutcome = call(GF.RecruitmentSession, "HandleCreationFailed")
	local questCreateOutcome = call(GF.QuestRecruitmentBridge, "HandleCreationFailed")
	if not lfgDispatchIsSuspended() then
		call(GF.MainFrame, "OnActiveEntryUpdate", {
			creationFailed = true,
			questCreateOutcome = questCreateOutcome,
			bumpOutcome = bumpOutcome,
			bumpResolved = true,
		})
	end
end

function handlers.LFG_LIST_APPLICANT_LIST_UPDATED()
	if lfgDispatchIsSuspended() then
		return
	end
	-- The list-wide event is a wake edge only. The per-applicant event remains
	-- authoritative for releasing the scheduler's duplicate ledger.
	call(GF.RaidRecruitmentPolicy, "Queue")
	call(GF.InvitationScheduler, "Queue",
		nil, "LFG_LIST_APPLICANT_LIST_UPDATED")
	call(GF.MainFrame, "OnApplicantsUpdate",
		"LFG_LIST_APPLICANT_LIST_UPDATED")
	call(GF.MythicPlusCarpoolView, "OnApplicantRolesChanged",
		"LFG_LIST_APPLICANT_LIST_UPDATED")
	call(GF.RaidSeekingChatService, "OnApplicantsChanged")
end

function handlers.LFG_LIST_APPLICANT_UPDATED(applicantID)
	if lfgDispatchIsSuspended() then
		return
	end

	call(GF.RaidRecruitmentPolicy, "Queue", applicantID)
	call(GF.InvitationScheduler, "Queue",
		applicantID, "LFG_LIST_APPLICANT_UPDATED")
	call(GF.ApplicantAlertService, "HandleApplicantChanged", applicantID)
	if GF.ApplicantsPanel and GF.ApplicantsPanel.OnApplicantUpdated then
		GF.ApplicantsPanel:OnApplicantUpdated(applicantID, true)
	else
		call(GF.MainFrame, "OnApplicantsUpdate")
	end
	call(GF.MythicPlusCarpoolView, "OnApplicantRolesChanged",
		"LFG_LIST_APPLICANT_UPDATED")
	call(GF.FloatButton, "RefreshAlert")
	call(GF.RaidSeekingChatService, "OnApplicantsChanged")
end

local function refreshGroupMinimumItemLevelAdmission()
	local changed = call(
		GF.GroupItemLevelAdmission, "OnSourceChanged") == true
	if changed then
		call(GF.FilterPanel, "OnGroupMinimumItemLevelChanged")
	end
end

local function refreshRosterSurfaces(_, event)
	if lfgDispatchIsSuspended() then return end
	call(GF.Apply, "OnGroupRosterChanged")
	call(GF.MainFrame, "OnGroupRosterChanged", event)
	call(GF.JoinAnnounce, "OnGroupRosterChanged")
end

local function handleRosterChange(event)
	call(GF.ApplicantAlertService, "HandleLifecycleChanged", event)
	call(GF.RaidRecruitmentPolicy, "OnRosterChanged")
	call(GF.CensoredActiveEntryDialog, "HandlePublishPermissionChanged")
	call(GF.MythicPlusGroupReadyTeleportService, "OnRosterChanged", event)
	refreshGroupMinimumItemLevelAdmission()
	if lfgDispatchIsSuspended() then
		return
	end
	-- Permissions, alert cleanup and group handoff above remain immediate.
	-- The application/list projection reads the latest roster at its deadline.
	if GF.EventCoalescer then
		GF.EventCoalescer:Request(
			Lifecycle, "rosterSurfaceSchedule", 0.2, refreshRosterSurfaces, event)
	else
		refreshRosterSurfaces(Lifecycle, event)
	end
end

function handlers.PARTY_LEADER_CHANGED()
	handleRosterChange("PARTY_LEADER_CHANGED")
end

function handlers.GROUP_ROSTER_UPDATE()
	handleRosterChange("GROUP_ROSTER_UPDATE")
end

function handlers.GROUP_JOINED(category, partyGUID)
	refreshGroupMinimumItemLevelAdmission()
	call(GF.Apply, "OnGroupJoined", category, partyGUID)
	call(GF.MythicPlusGroupReadyTeleportService,
		"OnGroupJoined", category, partyGUID)
end

function handlers.GROUP_LEFT(category, partyGUID)
	-- Reconcile actual listing/management state; leaving an INSTANCE party must
	-- not unconditionally reset a still-valid HOME recruitment.
	call(GF.ApplicantAlertService, "HandleLifecycleChanged", "GROUP_LEFT")
	refreshGroupMinimumItemLevelAdmission()
	call(GF.ApplicantsPanel, "OnGroupLeft", category, partyGUID)
	call(GF.Apply, "OnGroupLeft", category, partyGUID)
	call(GF.MythicPlusGroupReadyTeleportService,
		"OnGroupLeft", category, partyGUID)
end

local function refreshRequestedRoleSurfaces()
	call(GF.MainFrame, "RefreshRoleSelectionButtons")
	call(GF.ApplicantsPanel, "UpdateFromActiveRoleSummary")
	if lfgDispatchIsSuspended() then
		return
	end
	local currentGroupChanged = call(
		GF.CurrentGroupProjection, "OnRolesChanged") == true
	if currentGroupChanged then
		call(GF.Apply, "QueueCurrentGroupRefresh")
	end
end

local function refreshRoleSurfaces()
	if GF.EventCoalescer then
		GF.EventCoalescer:Request(
			Lifecycle, "roleSurfaceSchedule", 0.2, refreshRequestedRoleSurfaces)
	else
		refreshRequestedRoleSurfaces()
	end
end

handlers.LFG_ROLE_UPDATE = refreshRoleSurfaces
handlers.PLAYER_ROLES_ASSIGNED = refreshRoleSurfaces
handlers.PLAYER_AVG_ITEM_LEVEL_UPDATE = refreshGroupMinimumItemLevelAdmission
handlers.UNIT_INVENTORY_CHANGED = refreshGroupMinimumItemLevelAdmission

local function handleRoleCheck()
	if not lfgDispatchIsSuspended() then
		call(GF.Apply, "QueueAutoConfirmLfgListRoleCheck")
	end
	refreshCreateQueueHint()
end

handlers.LFG_ROLE_CHECK_SHOW = handleRoleCheck
handlers.LFG_ROLE_CHECK_UPDATE = handleRoleCheck

function handlers.LFG_ROLE_CHECK_HIDE()
	-- Cleanup must also run while LFG dispatch is suspended.
	call(GF.Apply, "OnRoleCheckHidden")
	refreshCreateQueueHint()
end

-- These are the remaining native LFG_LIST_ACTIVE_QUEUE_MESSAGE_EVENTS.
-- Only re-read the visible empty hint; do not refresh applicant providers.
local createQueueEvents = {
	"UPDATE_BATTLEFIELD_STATUS",
	"LFG_UPDATE",
	"LFG_PROPOSAL_UPDATE",
	"LFG_PROPOSAL_FAILED",
	"LFG_PROPOSAL_SUCCEEDED",
	"LFG_PROPOSAL_SHOW",
	"LFG_QUEUE_STATUS_UPDATE",
}
for _, eventName in ipairs(createQueueEvents) do
	handlers[eventName] = refreshCreateQueueHint
end

function handlers.PLAYER_SPECIALIZATION_CHANGED(unit)
	if unit == "player" then
		refreshRoleSurfaces()
		call(GF.FindGroupTab, "OnPlayerSpecializationChanged")
	end
end

local alwaysRegisteredEvents = {
	"ADDON_LOADED",
	"PLAYER_LOGIN",
	"PLAYER_ENTERING_WORLD",
	"PLAYER_LOGOUT",
	"PLAYER_REGEN_ENABLED",
	"PET_BATTLE_OPENING_START",
	"PET_BATTLE_CLOSE",
	"LFG_LIST_SEARCH_RESULTS_RECEIVED",
	"LFG_LIST_SEARCH_RESULT_UPDATED",
	"LFG_LIST_SEARCH_FAILED",
	"LFG_LIST_AVAILABILITY_UPDATE",
	"LFG_LIST_ACTIVE_ENTRY_UPDATE",
	"LFG_LIST_ENTRY_CREATION_FAILED",
	"LFG_LIST_APPLICANT_LIST_UPDATED",
	"LFG_LIST_APPLICANT_UPDATED",
	"LFG_LIST_APPLICATION_STATUS_UPDATED",
	"LFG_LIST_JOINED_GROUP",
	"PARTY_LEADER_CHANGED",
	"GROUP_ROSTER_UPDATE",
	"GROUP_JOINED",
	"GROUP_LEFT",
	"PLAYER_AVG_ITEM_LEVEL_UPDATE",
	"UNIT_INVENTORY_CHANGED",
	"LFG_ROLE_UPDATE",
	"LFG_ROLE_CHECK_SHOW",
	"LFG_ROLE_CHECK_UPDATE",
	"LFG_ROLE_CHECK_HIDE",
	"PLAYER_ROLES_ASSIGNED",
	"PLAYER_SPECIALIZATION_CHANGED",
	"PLAYER_LEVEL_CHANGED",
	"TRIAL_STATUS_UPDATE",
}

local capabilityRegisteredEvents = {
	"LFG_LIST_CENSORED_ACTIVE_ENTRY_UPDATE",
	"LFG_LIST_REVEALED_CENSORED_ACTIVE_ENTRY",
}

local startupEvents = {
	ADDON_LOADED = true,
	PLAYER_LOGIN = true,
}

activateRuntimeEvents = function()
	if runtimeEventsActive or not dispatcher then
		return
	end
	runtimeEventsActive = true
	for index = 1, #alwaysRegisteredEvents do
		local eventName = alwaysRegisteredEvents[index]
		if not startupEvents[eventName] then
			dispatcher:RegisterEvent(eventName)
		end
	end
	for _, eventName in ipairs(createQueueEvents) do
		dispatcher:RegisterEvent(eventName)
	end

	local isEventValid = C_EventUtils and C_EventUtils.IsEventValid
	if type(isEventValid) == "function" then
		for index = 1, #capabilityRegisteredEvents do
			local eventName = capabilityRegisteredEvents[index]
			local ok, valid = pcall(isEventValid, eventName)
			if ok and valid == true then
				dispatcher:RegisterEvent(eventName)
			end
		end
	end

	if receivesIncrementalSearchUpdates then
		for index = 1, #incrementalSearchEvents do
			dispatcher:RegisterEvent(incrementalSearchEvents[index])
		end
	end
end

function Lifecycle:AttachDispatcher(eventFrame)
	assert(eventFrame, "RuntimeLifecycle requires the Bootstrap dispatcher")
	if dispatcher == eventFrame then
		return
	end
	dispatcher = eventFrame
	dispatcher:RegisterEvent("ADDON_LOADED")
	dispatcher:RegisterEvent("PLAYER_LOGIN")
	if runtimeInitialized then
		activateRuntimeEvents()
	end
end

function Lifecycle:HandleEvent(eventName, ...)
	local handler = handlers[eventName]
	if handler then
		return handler(...)
	end
end

local function toggleMainWindow()
	local policy = GF.RuntimePolicy
	if not (policy and policy.IsAllowed and policy:IsAllowed()) then
		local status, reason = evaluateRuntimePolicy()
		if status ~= "allowed" then
			showRuntimePolicyDialog(status, reason)
			return false
		end
	end
	return call(GF.MainFrame, "Toggle")
end

local function guardRuntimeAccess()
	local policy = GF.RuntimePolicy
	if policy and policy.IsAllowed and policy:IsAllowed() then
		return true
	end
	local status, reason = evaluateRuntimePolicy()
	if status == "allowed" then
		return runtimeInitialized
	end
	showRuntimePolicyDialog(status, reason)
	return false
end

function Lifecycle:RequestAccess()
	return guardRuntimeAccess()
end

function Lifecycle:InstallGlobalFacade()
	_G.SLASH_GROUPFINDER1 = "/gf"
	_G.SLASH_GROUPFINDER2 = "/groupfinder"
	_G.SLASH_GROUPFINDER3 = "/魔兽集合石"
	SlashCmdList.GROUPFINDER = function(message)
		if not guardRuntimeAccess() then
			return
		end
		toggleMainWindow()
	end

	-- Keep all three pre-2.0.10 command IDs so existing assignments survive.
	function GROUPFINDER_TOGGLE()
		return guardRuntimeAccess() and call(GF.MainFrame, "ToggleRoute", {
			tabID = GF.TAB_BROWSE,
		})
	end

	function GROUPFINDER_CREATE()
		return guardRuntimeAccess() and call(GF.MainFrame, "ToggleRoute", {
			tabID = GF.TAB_CREATE,
		})
	end

	function GROUPFINDER_MPLUS_CHARACTER()
		return guardRuntimeAccess() and call(GF.MainFrame, "ToggleRoute", {
			workspaceID = GF.WORKSPACE_MYTHIC_PLUS,
			tabID = GF.TAB_MPLUS_CHARACTER,
		})
	end

	function GROUPFINDER_MPLUS_CARPOOL()
		return guardRuntimeAccess() and call(GF.MainFrame, "ToggleRoute", {
			workspaceID = GF.WORKSPACE_MYTHIC_PLUS,
			tabID = GF.TAB_MPLUS_CARPOOL,
		})
	end

	function GROUPFINDER_MPLUS_TELEPORT()
		return guardRuntimeAccess() and call(GF.MainFrame, "ToggleSeasonRating")
	end

	function GROUPFINDER_RAID_SEEK()
		return guardRuntimeAccess() and call(GF.MainFrame, "ToggleRoute", {
			workspaceID = GF.WORKSPACE_RAID,
			tabID = GF.TAB_RAID_SEEK,
		})
	end

	function GROUPFINDER_RAID_SQUARE()
		return guardRuntimeAccess() and call(GF.MainFrame, "ToggleRoute", {
			workspaceID = GF.WORKSPACE_RAID,
			tabID = GF.TAB_RAID_SQUARE,
		})
	end

	_G.GroupFinder = GF
end
