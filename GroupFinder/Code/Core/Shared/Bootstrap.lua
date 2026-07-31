local addonName, GF = ...

GF.addonName = addonName
GF.searching = false

function GF.EnsureBlizzardAddons()
	if GF._blizzardAddonsReady then
		return true
	end
	if C_AddOns and C_AddOns.LoadAddOn then
		C_AddOns.LoadAddOn("Blizzard_SharedXML")
		C_AddOns.LoadAddOn("Blizzard_Menu")
		C_AddOns.LoadAddOn("Blizzard_GroupFinder")
		C_AddOns.LoadAddOn("Blizzard_UIPanelTemplates")
		C_AddOns.LoadAddOn("Blizzard_Settings_Shared")
	elseif LoadAddOn then
		LoadAddOn("Blizzard_SharedXML")
		LoadAddOn("Blizzard_Menu")
		LoadAddOn("Blizzard_UIPanelTemplates")
		LoadAddOn("Blizzard_GroupFinder")
		LoadAddOn("Blizzard_Settings_Shared")
	end
	GF._blizzardAddonsReady = true
	return true
end

local eventFrame = CreateFrame("Frame")
local lfgUpdateListening = false

function GF.SetLfgUpdateListening(enable)
	if enable == lfgUpdateListening then
		return
	end
	lfgUpdateListening = enable
	if enable then
		eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
		eventFrame:RegisterEvent("LFG_LIST_UPDATE_SEARCH_RESULTS")
	else
		eventFrame:UnregisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
		eventFrame:UnregisterEvent("LFG_LIST_UPDATE_SEARCH_RESULTS")
	end
end

local function lfgEventsPaused()
	return GF.Availability and GF.Availability.ShouldProcessLfgEvent
		and not GF.Availability:ShouldProcessLfgEvent()
end

local laonongDirectoryListenerRegistered = false

local function refreshLaonongFindGroup()
	if GF.FindGroupTab and GF.FindGroupTab.RefreshList then
		GF.FindGroupTab:RefreshList({
			preserveScroll = true,
			skipSnapshot = true,
		})
	end
end

local function refreshLaonongApplicants(status)
	if GF.ApplicantsPanel and GF.ApplicantsPanel.OnLaonongFanSourceChanged then
		GF.ApplicantsPanel:OnLaonongFanSourceChanged(status and status.revision or 0)
	end
end

local function refreshLaonongDiagnostics()
	if GF.DebugPanel and GF.DebugPanel.Refresh then
		GF.DebugPanel:Refresh()
	end
end

local function refreshLaonongFanDirectory(reason)
	local directory = GF.LaonongFanDirectory
	if not (directory and directory.Refresh) then
		return
	end
	if not laonongDirectoryListenerRegistered and directory.AddListener then
		directory:AddListener(refreshLaonongFindGroup)
		directory:AddListener(refreshLaonongApplicants)
		directory:AddListener(refreshLaonongDiagnostics)
		laonongDirectoryListenerRegistered = true
	end
	directory:Refresh(reason)
end

local function onEvent(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= addonName then
			if name == "!!!163UI!!!" then
				refreshLaonongFanDirectory("163-addon-loaded")
			end
			if GF._addonLoaded and GF.Hook and GF.Hook.Refresh then
				GF.Hook.Refresh()
			end
			return
		end
		if GF.Availability and GF.Availability.Init then
			GF.Availability:Init()
		end
		GF.InitDB()
		if GF.MythicPlusServices and GF.MythicPlusServices.Init then
			GF.MythicPlusServices:Init()
		end
		if GF.Blocklist then
			GF.Blocklist:Init()
		end
		GF.Hook.Refresh()
		GF.MinimapButton:Init()
		if GF.FloatButton then
			GF.FloatButton:Init()
		end
		GF.NavData.RequestRefresh()
		GF._addonLoaded = true
		refreshLaonongFanDirectory("groupfinder-addon-loaded")
	elseif event == "PLAYER_LOGIN" then
		refreshLaonongFanDirectory("player-login")
		if GF.Hook and GF.Hook.Refresh then
			GF.Hook.Refresh()
		end
		if GF.ValidateLSMFontKeyAfterLogin then
			GF.ValidateLSMFontKeyAfterLogin()
		end
		if GF.Blocklist and GF.Blocklist.ClearReadableTitleTokens then
			GF.Blocklist:ClearReadableTitleTokens()
		end
		if GF.Filter and GF.Filter.ApplyPersistedAdvancedFilter then
			GF.Filter:ApplyPersistedAdvancedFilter()
		end
		GF.NavData.Rebuild()
		if GF.NavTree and GF.NavTree.Refresh then
			GF.NavTree:Refresh()
		end
		if GF.FloatButton and GF.FloatButton.RefreshAlert then
			GF.FloatButton:RefreshAlert()
		end
		if GF.JoinAnnounce and GF.JoinAnnounce.Init then
			GF.JoinAnnounce:Init()
		end
	elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
		if lfgEventsPaused() then
			return
		end
		if GF.MainFrame then
			GF.MainFrame:OnSearchResults()
		end
	elseif event == "LFG_LIST_SEARCH_FAILED" then
		if lfgEventsPaused() then
			return
		end
		if GF.MainFrame then
			GF.MainFrame:OnSearchFailed()
		end
	elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
		if lfgEventsPaused() then
			return
		end
		local resultID = ...
		if GF.FindGroupTab and GF.FindGroupTab.OnSearchResultUpdated then
			GF.FindGroupTab:OnSearchResultUpdated(resultID)
		end
	elseif event == "LFG_LIST_UPDATE_SEARCH_RESULTS" then
		if lfgEventsPaused() then
			return
		end
		if GF.FindGroupTab and GF.FindGroupTab.OnSearchResultsUpdated then
			GF.FindGroupTab:OnSearchResultsUpdated()
		end
	elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
		if lfgEventsPaused() then
			return
		end
		local searchResultID, newStatus = ...
		if GF.FindGroupTab and GF.FindGroupTab.OnApplicationStatusUpdated then
			GF.FindGroupTab:OnApplicationStatusUpdated(searchResultID, newStatus)
		end
		if GF.JoinAnnounce and GF.JoinAnnounce.OnApplicationStatusUpdated then
			GF.JoinAnnounce:OnApplicationStatusUpdated(searchResultID, newStatus)
		end
		if GF.FloatButton and GF.FloatButton.RefreshAlert then
			GF.FloatButton:RefreshAlert()
		end
	elseif event == "LFG_LIST_AVAILABILITY_UPDATE" then
		-- Available-activity data is the source for both navigation and the
		-- shared current-season Mythic+ scope. Invalidate it before scheduling
		-- the season refresh so the refresh cannot consume an empty/stale
		-- login-time snapshot.
		if GF.NavData and GF.NavData.ClearBuildCaches then
			GF.NavData.ClearBuildCaches()
		end
		if GF.MythicPlusSeason and GF.MythicPlusSeason.RequestRefresh then
			GF.MythicPlusSeason:RequestRefresh(event)
		end
		if GF.Availability and GF.Availability.UpdateRestrictedState then
			if not GF.Availability:UpdateRestrictedState() and GF.MainFrame then
				GF.MainFrame:OnAvailabilityUpdate()
			end
		elseif GF.MainFrame then
			GF.MainFrame:OnAvailabilityUpdate()
		end
	elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
		local createdNew = ... == true
		local hasActive = GF.Listing and GF.Listing.HasActive
			and GF.Listing:HasActive() == true
		local bumpOutcome
		if GF.Listing and GF.Listing.SyncActiveEntryOwnership then
			GF.Listing:SyncActiveEntryOwnership(hasActive)
		end
		if GF.Listing and GF.Listing.ResolveBumpRelistEvent then
			bumpOutcome = GF.Listing:ResolveBumpRelistEvent(hasActive, createdNew)
		end
		if lfgEventsPaused() then
			return
		end
		if GF.Listing and GF.Listing.SyncApplicantAlertBaseline then
			GF.Listing:SyncApplicantAlertBaseline()
		end
		if GF.MainFrame then
			GF.MainFrame:OnActiveEntryUpdate({
				hasActive = hasActive,
				createdNew = createdNew,
				bumpOutcome = bumpOutcome,
				bumpResolved = true,
				fromActiveEntryEvent = true,
			})
		end
	elseif event == "LFG_LIST_ENTRY_CREATION_FAILED" then
		local bumpOutcome
		if GF.Listing and GF.Listing.OnCreationFailed then
			bumpOutcome = GF.Listing:OnCreationFailed()
		end
		if lfgEventsPaused() then
			return
		end
		if GF.MainFrame then
			GF.MainFrame:OnActiveEntryUpdate({
				creationFailed = true,
				bumpOutcome = bumpOutcome,
				bumpResolved = true,
			})
		end
	elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
		if lfgEventsPaused() then
			return
		end
		if GF.Listing and GF.Listing.MaybePlayApplicantAlert then
			GF.Listing:MaybePlayApplicantAlert()
		end
		if GF.MainFrame then
			GF.MainFrame:OnApplicantsUpdate()
		end
		if GF.MythicPlusCarpoolView
			and GF.MythicPlusCarpoolView.OnApplicantRolesChanged
		then
			GF.MythicPlusCarpoolView:OnApplicantRolesChanged(event)
		end
	elseif event == "LFG_LIST_APPLICANT_UPDATED" then
		if lfgEventsPaused() then
			return
		end
		local applicantID = ...
		if GF.Listing and GF.Listing.QueueAutoInvite then
			GF.Listing:QueueAutoInvite()
		end
		if GF.Listing and GF.Listing.MaybePlayApplicantAlert then
			GF.Listing:MaybePlayApplicantAlert()
		end
		if GF.ApplicantsPanel and GF.ApplicantsPanel.OnApplicantUpdated then
			GF.ApplicantsPanel:OnApplicantUpdated(applicantID)
		elseif GF.MainFrame then
			GF.MainFrame:OnApplicantsUpdate()
		end
		if GF.MythicPlusCarpoolView
			and GF.MythicPlusCarpoolView.OnApplicantRolesChanged
		then
			GF.MythicPlusCarpoolView:OnApplicantRolesChanged(event)
		end
		if GF.FloatButton and GF.FloatButton.RefreshAlert then
			GF.FloatButton:RefreshAlert()
		end
	elseif event == "PARTY_LEADER_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
		if lfgEventsPaused() then
			return
		end
		if GF.Apply and GF.Apply.OnGroupRosterChanged then
			GF.Apply:OnGroupRosterChanged()
		end
		if GF.MainFrame and GF.MainFrame.OnGroupRosterChanged then
			GF.MainFrame:OnGroupRosterChanged()
		end
		if GF.JoinAnnounce and GF.JoinAnnounce.OnGroupRosterChanged then
			GF.JoinAnnounce:OnGroupRosterChanged()
		end
	elseif event == "LFG_ROLE_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
		if GF.MainFrame and GF.MainFrame.RefreshRoleSelectionButtons then
			GF.MainFrame:RefreshRoleSelectionButtons()
		end
		if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateActiveRoleSummary then
			GF.ApplicantsPanel:UpdateActiveRoleSummary()
		end
	elseif event == "LFG_ROLE_CHECK_SHOW" or event == "LFG_ROLE_CHECK_UPDATE" then
		if lfgEventsPaused() then
			return
		end
		if GF.Apply and GF.Apply.QueueAutoConfirmLfgListRoleCheck then
			GF.Apply:QueueAutoConfirmLfgListRoleCheck()
		end
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		local unit = ...
		if unit == "player" and GF.MainFrame and GF.MainFrame.RefreshRoleSelectionButtons then
			GF.MainFrame:RefreshRoleSelectionButtons()
		end
		if unit == "player" and GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateActiveRoleSummary then
			GF.ApplicantsPanel:UpdateActiveRoleSummary()
		end
	end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
eventFrame:RegisterEvent("LFG_LIST_SEARCH_FAILED")
eventFrame:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
eventFrame:RegisterEvent("LFG_LIST_ENTRY_CREATION_FAILED")
eventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
eventFrame:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
eventFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("LFG_ROLE_UPDATE")
eventFrame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
eventFrame:RegisterEvent("LFG_ROLE_CHECK_UPDATE")
eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", onEvent)

local function handleSlashCommand(msg)
	if GF.Debug and GF.Debug.HandleSlashCommand then
		return GF.Debug:HandleSlashCommand(msg)
	end
	return false
end

SLASH_GROUPFINDER1 = "/gf"
SLASH_GROUPFINDER2 = "/groupfinder"
SLASH_GROUPFINDER3 = "/队伍查找器"
SlashCmdList["GROUPFINDER"] = function(msg)
	if handleSlashCommand(msg) then
		return
	end
	if GF.MainFrame then
		GF.MainFrame:Toggle()
	end
end

function GROUPFINDER_TOGGLE()
	if GF.MainFrame then
		GF.MainFrame:Toggle()
	end
end

_G.GroupFinder = GF
