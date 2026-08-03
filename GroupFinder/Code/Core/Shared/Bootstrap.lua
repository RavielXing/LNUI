local addonName, GF = ...

GF.addonName = addonName
GF.searching = false

local function call(owner, methodName, ...)
	local method = owner and owner[methodName]
	if method then
		return method(owner, ...)
	end
end

function GF.EnsureBlizzardAddons()
	if GF._blizzardAddonsReady then
		return true
	end

	local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
	if loader then
		local dependencies = {
			"Blizzard_SharedXML",
			"Blizzard_Menu",
			"Blizzard_GroupFinder",
			"Blizzard_UIPanelTemplates",
			"Blizzard_Settings_Shared",
		}
		for index = 1, #dependencies do
			loader(dependencies[index])
		end
	end

	GF._blizzardAddonsReady = true
	return true
end

local dispatcher = CreateFrame("Frame")
local receivesIncrementalSearchUpdates = false

local incrementalSearchEvents = {
	"LFG_LIST_SEARCH_RESULT_UPDATED",
	"LFG_LIST_UPDATE_SEARCH_RESULTS",
}

function GF.SetLfgUpdateListening(shouldListen)
	shouldListen = shouldListen == true
	if receivesIncrementalSearchUpdates == shouldListen then
		return
	end

	receivesIncrementalSearchUpdates = shouldListen
	for index = 1, #incrementalSearchEvents do
		local eventName = incrementalSearchEvents[index]
		if shouldListen then
			dispatcher:RegisterEvent(eventName)
		else
			dispatcher:UnregisterEvent(eventName)
		end
	end
end

local function lfgDispatchIsSuspended()
	local availability = GF.Availability
	return availability and availability.ShouldProcessLfgEvent
		and availability:ShouldProcessLfgEvent() ~= true
end

local directoryListenersInstalled = false

local function updateFindGroupForDirectory()
	call(GF.FindGroupTab, "RefreshList", {
		preserveScroll = true,
		skipSnapshot = true,
	})
end

local function updateApplicantsForDirectory(status)
	call(GF.ApplicantsPanel, "OnLaonongFanSourceChanged", status and status.revision or 0)
end

local function updateDiagnosticsForDirectory()
	call(GF.DebugPanel, "Refresh")
end

local function requestDirectoryRefresh(reason)
	local directory = GF.LaonongFanDirectory
	if not (directory and directory.Refresh) then
		return
	end

	if not directoryListenersInstalled and directory.AddListener then
		directory:AddListener(updateFindGroupForDirectory)
		directory:AddListener(updateApplicantsForDirectory)
		directory:AddListener(updateDiagnosticsForDirectory)
		directoryListenersInstalled = true
	end
	directory:Refresh(reason)
end

local handlers = {}

function handlers.ADDON_LOADED(loadedName)
	if loadedName ~= addonName then
		if loadedName == "!!!163UI!!!" then
			requestDirectoryRefresh("163-addon-loaded")
		end
		if GF._addonLoaded and GF.Hook and GF.Hook.Refresh then
			GF.Hook.Refresh()
		end
		return
	end

	call(GF.Availability, "Init")
	GF.InitDB()
	call(GF.MythicPlusServices, "Init")
	call(GF.Blocklist, "Init")
	call(GF.BlacklistMenu, "Init")
	if GF.Hook and GF.Hook.Refresh then
		GF.Hook.Refresh()
	end
	call(GF.MinimapButton, "Init")
	call(GF.FloatButton, "Init")
	GF.NavData.RequestRefresh()
	GF._addonLoaded = true
	requestDirectoryRefresh("groupfinder-addon-loaded")
end

function handlers.PLAYER_LOGIN()
	requestDirectoryRefresh("player-login")
	call(GF.BlacklistMenu, "Init")
	if GF.Hook and GF.Hook.Refresh then
		GF.Hook.Refresh()
	end
	if GF.ValidateLSMFontKeyAfterLogin then
		GF.ValidateLSMFontKeyAfterLogin()
	end
	call(GF.Blocklist, "ClearReadableTitleTokens")
	call(GF.Filter, "ApplyPersistedAdvancedFilter")
	call(GF.Apply, "OnGroupRosterChanged")
	GF.NavData.Rebuild()
	call(GF.NavTree, "Refresh")
	call(GF.FloatButton, "RefreshAlert")
	call(GF.JoinAnnounce, "Init")
end

function handlers.LFG_LIST_SEARCH_RESULTS_RECEIVED()
	if not lfgDispatchIsSuspended() then
		call(GF.MainFrame, "OnSearchResults")
	end
end

function handlers.LFG_LIST_SEARCH_FAILED()
	if not lfgDispatchIsSuspended() then
		call(GF.MainFrame, "OnSearchFailed")
	end
end


function handlers.LFG_LIST_SEARCH_RESULT_UPDATED(resultID)
	if not lfgDispatchIsSuspended() then
		call(GF.FindGroupTab, "OnSearchResultUpdated", resultID)
	end
end

function handlers.LFG_LIST_UPDATE_SEARCH_RESULTS()
	if not lfgDispatchIsSuspended() then
		call(GF.FindGroupTab, "OnSearchResultsUpdated")
	end
end

function handlers.LFG_LIST_APPLICATION_STATUS_UPDATED(resultID, newStatus)
	if lfgDispatchIsSuspended() then
		return
	end
	call(GF.FindGroupTab, "OnApplicationStatusUpdated", resultID, newStatus)
	call(GF.JoinAnnounce, "OnApplicationStatusUpdated", resultID, newStatus)
	call(GF.FloatButton, "RefreshAlert")
end

function handlers.LFG_LIST_JOINED_GROUP(resultID)
	-- groupName 是受保护文本；当前队伍身份只消费 resultID/partyGUID。
	call(GF.Apply, "OnJoinedGroup", resultID)
end

function handlers.LFG_LIST_AVAILABILITY_UPDATE()
	-- Navigation and the seasonal Mythic+ scope share the availability cache.
	-- Clear it first so a scheduled season rebuild cannot consume login-time data.
	if GF.NavData and GF.NavData.ClearBuildCaches then
		GF.NavData.ClearBuildCaches()
	end
	call(GF.MythicPlusSeason, "RequestRefresh", "LFG_LIST_AVAILABILITY_UPDATE")

	local availability = GF.Availability
	if availability and availability.UpdateRestrictedState then
		if availability:UpdateRestrictedState() then
			-- EnterRestricted hides the main frame. Still mark its navigation
			-- dirty so leaving the restricted state cannot restore old branches.
			call(GF.MainFrame, "OnAvailabilityUpdate")
			return
		end
	end
	call(GF.MainFrame, "OnAvailabilityUpdate")
end

local function handlePremadePermissionUpdate()
	-- Blizzard re-evaluates the native Group Finder buttons on these events.
	-- Refresh the global premade gate immediately, then ask LFGList to publish
	-- its authoritative activity update before rebuilding seasonal branches.
	call(GF.NavData, "RequestRefresh")
	call(GF.MainFrame, "OnPremadePermissionUpdate")
end

handlers.PLAYER_LEVEL_CHANGED = handlePremadePermissionUpdate
handlers.TRIAL_STATUS_UPDATE = handlePremadePermissionUpdate

function handlers.LFG_LIST_ACTIVE_ENTRY_UPDATE(createdNew)
	createdNew = createdNew == true
	local listing = GF.Listing
	local hasActive = listing and listing.HasActive and listing:HasActive() == true

	call(listing, "SyncActiveEntryOwnership", hasActive)
	local bumpOutcome = call(listing, "ResolveBumpRelistEvent", hasActive, createdNew)
	if lfgDispatchIsSuspended() then
		return
	end

	call(listing, "SyncApplicantAlertBaseline")
	call(GF.MainFrame, "OnActiveEntryUpdate", {
		hasActive = hasActive,
		createdNew = createdNew,
		bumpOutcome = bumpOutcome,
		bumpResolved = true,
		fromActiveEntryEvent = true,
	})
end

function handlers.LFG_LIST_ENTRY_CREATION_FAILED()
	local bumpOutcome = call(GF.Listing, "OnCreationFailed")
	if not lfgDispatchIsSuspended() then
		call(GF.MainFrame, "OnActiveEntryUpdate", {
			creationFailed = true,
			bumpOutcome = bumpOutcome,
			bumpResolved = true,
		})
	end
end

function handlers.LFG_LIST_APPLICANT_LIST_UPDATED()
	if lfgDispatchIsSuspended() then
		return
	end
	call(GF.Listing, "MaybePlayApplicantAlert")
	call(GF.MainFrame, "OnApplicantsUpdate")
	call(GF.MythicPlusCarpoolView, "OnApplicantRolesChanged", "LFG_LIST_APPLICANT_LIST_UPDATED")
end

function handlers.LFG_LIST_APPLICANT_UPDATED(applicantID)
	if lfgDispatchIsSuspended() then
		return
	end

	call(GF.Listing, "QueueAutoInvite")
	call(GF.Listing, "MaybePlayApplicantAlert")
	if GF.ApplicantsPanel and GF.ApplicantsPanel.OnApplicantUpdated then
		GF.ApplicantsPanel:OnApplicantUpdated(applicantID)
	else
		call(GF.MainFrame, "OnApplicantsUpdate")
	end
	call(GF.MythicPlusCarpoolView, "OnApplicantRolesChanged", "LFG_LIST_APPLICANT_UPDATED")
	call(GF.FloatButton, "RefreshAlert")
end

local function handleRosterChange()
	if lfgDispatchIsSuspended() then
		return
	end
	call(GF.Apply, "OnGroupRosterChanged")
	call(GF.MainFrame, "OnGroupRosterChanged")
	call(GF.JoinAnnounce, "OnGroupRosterChanged")
end

handlers.PARTY_LEADER_CHANGED = handleRosterChange
handlers.GROUP_ROSTER_UPDATE = handleRosterChange

function handlers.GROUP_JOINED(category, partyGUID)
	call(GF.Apply, "OnGroupJoined", category, partyGUID)
end

function handlers.GROUP_LEFT(category, partyGUID)
	call(GF.ApplicantsPanel, "OnGroupLeft", category, partyGUID)
	call(GF.Apply, "OnGroupLeft", category, partyGUID)
end

local function refreshRoleSurfaces()
	call(GF.MainFrame, "RefreshRoleSelectionButtons")
	call(GF.ApplicantsPanel, "UpdateActiveRoleSummary")
end

handlers.LFG_ROLE_UPDATE = refreshRoleSurfaces
handlers.PLAYER_ROLES_ASSIGNED = refreshRoleSurfaces

local function handleRoleCheck()
	if not lfgDispatchIsSuspended() then
		call(GF.Apply, "QueueAutoConfirmLfgListRoleCheck")
	end
end

handlers.LFG_ROLE_CHECK_SHOW = handleRoleCheck
handlers.LFG_ROLE_CHECK_UPDATE = handleRoleCheck

function handlers.PLAYER_SPECIALIZATION_CHANGED(unit)
	if unit == "player" then
		refreshRoleSurfaces()
	end
end

local alwaysRegisteredEvents = {
	"ADDON_LOADED",
	"PLAYER_LOGIN",
	"LFG_LIST_SEARCH_RESULTS_RECEIVED",
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
	"LFG_ROLE_UPDATE",
	"LFG_ROLE_CHECK_SHOW",
	"LFG_ROLE_CHECK_UPDATE",
	"PLAYER_ROLES_ASSIGNED",
	"PLAYER_SPECIALIZATION_CHANGED",
	"PLAYER_LEVEL_CHANGED",
	"TRIAL_STATUS_UPDATE",
}

for index = 1, #alwaysRegisteredEvents do
	dispatcher:RegisterEvent(alwaysRegisteredEvents[index])
end

dispatcher:SetScript("OnEvent", function(_, eventName, ...)
	local handler = handlers[eventName]
	if handler then
		handler(...)
	end
end)

local function toggleMainWindow()
	call(GF.MainFrame, "Toggle")
end

SLASH_GROUPFINDER1 = "/gf"
SLASH_GROUPFINDER2 = "/groupfinder"
SLASH_GROUPFINDER3 = "/队伍查找器"
SlashCmdList.GROUPFINDER = function(message)
	if not call(GF.Debug, "HandleSlashCommand", message) then
		toggleMainWindow()
	end
end

function GROUPFINDER_TOGGLE()
	toggleMainWindow()
end

_G.GroupFinder = GF
