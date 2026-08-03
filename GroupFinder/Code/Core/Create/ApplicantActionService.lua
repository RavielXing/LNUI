local _, GF = ...

local Actions = {}
GF.ApplicantActionService = Actions

local MAX_APPLICANT_API_ID = 4294967295

local SILENT_REASONS = {
	api_error = true,
	api_unreadable = true,
	loading = true,
	missing = true,
	no_api = true,
}

local ACKNOWLEDGEABLE_TERMINAL_STATUSES = {
	failed = true,
	cancelled = true,
	declined = true,
	declined_full = true,
	declined_delisted = true,
	timedout = true,
	inviteaccepted = true,
	invitedeclined = true,
}

local function getRecruitmentSession()
	return GF.RecruitmentSession
end

local function isTestApplicant(applicantID)
	local testData = GF.ApplicantTestData
	return testData ~= nil
		and type(testData.IsTestApplicantID) == "function"
		and testData:IsTestApplicantID(applicantID) == true
end

local function normalizeApplicantID(applicantID)
	local numericID = tonumber(applicantID)
	if numericID == nil
		or numericID < 0
		or numericID > MAX_APPLICANT_API_ID
	then
		return nil
	end
	return numericID
end

local function isAccessibleValue(value)
	-- Both helpers document a non-nil argument.  Nil is also the valid native
	-- representation for optional applicant fields.
	if type(value) == "nil" then
		return true
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return true
end

local function readApplicantActionSnapshot(numericID)
	local reader = C_LFGList and C_LFGList.GetApplicantInfo
	if type(reader) ~= "function" then
		return nil, "no_api"
	end
	local readOK, application = pcall(reader, numericID)
	if not readOK then
		return nil, "api_error"
	end
	local applicationType = type(application)
	if applicationType == "nil" then
		return nil, "missing"
	end
	if applicationType ~= "table" then
		return nil, "missing"
	end
	if not isAccessibleValue(application) then
		return nil, "api_unreadable"
	end
	if type(canaccesstable) == "function" then
		local ok, accessible = pcall(canaccesstable, application)
		if not ok or accessible ~= true then
			return nil, "api_unreadable"
		end
	end
	if type(issecretvaluekey) == "function" then
		for _, key in ipairs({
			"applicationStatus",
			"pendingApplicationStatus",
			"numMembers",
		}) do
			local ok, secret = pcall(issecretvaluekey, application, key)
			if not ok or secret == true then
				return nil, "api_unreadable"
			end
		end
	end
	local fieldsOK, status, pendingStatus, numMembers, applicantInfo =
		pcall(function()
			return application.applicationStatus,
				application.pendingApplicationStatus,
				application.numMembers,
				application.applicantInfo
		end)
	if not fieldsOK
		or not isAccessibleValue(status)
		or not isAccessibleValue(pendingStatus)
		or not isAccessibleValue(numMembers)
		or not isAccessibleValue(applicantInfo)
	then
		return nil, "api_unreadable"
	end
	if type(status) ~= "string" or status == ""
		or (pendingStatus ~= nil and type(pendingStatus) ~= "string")
	then
		return nil, "api_unreadable"
	end
	local countOK, numericCount = pcall(tonumber, numMembers)
	if not countOK or numericCount == nil or numericCount < 1 then
		return nil, "api_unreadable"
	end
	-- Return only an ordinary GF-owned projection.  The raw provider table may be
	-- callable here yet unsafe for a later caller to index during chat lockdown.
	return {
		applicationStatus = status,
		pendingApplicationStatus = pendingStatus,
		numMembers = numericCount,
		applicantInfo = applicantInfo and true or false,
	}, nil
end

local function readableGlobalText(value)
	return type(value) == "string" and value ~= "" and value or nil
end

local function notify(message)
	if message ~= nil and type(GF.ShowWarningMessage) == "function" then
		GF.ShowWarningMessage(message)
	end
end

local function requiresRaidConversion(memberCount, invitedCount)
	local homeCategory = LE_PARTY_CATEGORY_HOME
	if IsInRaid(homeCategory) then
		return false
	end
	local currentCount = tonumber(GetNumGroupMembers(homeCategory)) or 0
	return currentCount
		+ (tonumber(memberCount) or 1)
		+ (tonumber(invitedCount) or 0)
		> (MAX_PARTY_MEMBERS + 1)
end

local function playActionSound()
	local soundID = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
	if soundID and type(PlaySound) == "function" then
		PlaySound(soundID)
	end
end

function Actions:GetStatusText(status)
	if status == nil then
		return nil
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local statusText = {
		invited = LFG_LIST_APP_INVITED,
		failed = LFG_LIST_APP_CANCELLED,
		cancelled = LFG_LIST_APP_CANCELLED,
		declined = LFG_LIST_APP_DECLINED,
		declined_full = LFG_LIST_APP_DECLINED,
		declined_delisted = LFG_LIST_APP_DECLINED,
		timedout = LFG_LIST_APP_TIMED_OUT,
		inviteaccepted = LFG_LIST_APP_INVITE_ACCEPTED,
		invitedeclined = LFG_LIST_APP_INVITE_DECLINED,
	}
	return readableGlobalText(statusText[status])
end

function Actions:GetBlockReasonText(reason)
	if SILENT_REASONS[reason] then
		return nil
	end
	local locale = GF.L or {}
	local direct = {
		unempowered = locale.ERR_MANAGE_ENTRY_ONLY,
		full = readableGlobalText(LFG_LIST_GROUP_TOO_FULL),
		pending_invite = readableGlobalText(LFG_LIST_INVITED_APP_FILLS_GROUP),
		raid_conversion_in_combat = locale.ERR_RAID_CONVERSION_IN_COMBAT
			or "Cannot convert to raid while in combat. Try again after combat.",
	}
	return direct[reason] or self:GetStatusText(reason)
end

function Actions:NotifyBlocked(reason)
	notify(self:GetBlockReasonText(reason))
end

function Actions:GetGroupSize()
	-- Retail HOME party counts include the player. Solo is normalized to one.
	local count = tonumber(GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)) or 0
	return count > 0 and count or 1
end

function Actions:GetActivityMemberCapacity()
	local session = getRecruitmentSession()
	local activityID = session and session.GetActiveActivityID
		and session:GetActiveActivityID()
	if activityID == nil then
		return MAX_RAID_MEMBERS
	end
	local entry = session and session.GetActive and session:GetActive()
	local questID = type(entry) == "table" and entry.questID or nil
	local reader = C_LFGList and C_LFGList.GetActivityInfoTable
	local activity = type(reader) == "function"
		and reader(activityID, questID) or nil
	local capacity = activity and tonumber(activity.maxNumPlayers) or nil
	return capacity and capacity > 0 and capacity or MAX_RAID_MEMBERS
end

function Actions:GetConfiguredMemberLimit()
	local activityLimit = self:GetActivityMemberCapacity()
	local database = GF.GetDB and GF.GetDB()
	if not database or database.autoInviteMemberLimitEnabled ~= true then
		return activityLimit
	end
	local minimum = GF.AUTO_INVITE_MEMBER_LIMIT_MIN or 1
	local maximum = GF.AUTO_INVITE_MEMBER_LIMIT_MAX or 40
	local fallback = GF.AUTO_INVITE_MEMBER_LIMIT_DEFAULT or 40
	local configured = math.floor(tonumber(database.autoInviteMemberLimit) or fallback)
	configured = math.min(maximum, math.max(minimum, configured))
	return math.min(activityLimit, configured)
end

function Actions:EvaluateInvite(applicantID, options)
	local session = getRecruitmentSession()
	if not (session and session.CanManageApplicants
		and session:CanManageApplicants())
	then
		return "unempowered"
	end
	if applicantID == nil or isTestApplicant(applicantID) then
		return applicantID == nil and "missing" or "test_data"
	end
	local numericID = normalizeApplicantID(applicantID)
	if numericID == nil then
		return "missing"
	end
	local application, readReason = readApplicantActionSnapshot(numericID)
	if application == nil then
		return readReason or "missing"
	end
	if application.applicantInfo
		or application.pendingApplicationStatus ~= nil
	then
		return "loading"
	end
	if application.applicationStatus ~= "applied" then
		return application.applicationStatus
	end

	local database = GF.GetDB and GF.GetDB()
	local useConfiguredLimit = options
		and options.respectMemberLimit == true
		and database
		and database.autoInviteMemberLimitEnabled == true
	local limitMethod = useConfiguredLimit and "GetConfiguredMemberLimit"
		or "GetActivityMemberCapacity"
	local memberLimit = self[limitMethod](self)
	local applicantSize = tonumber(application.numMembers) or 1
	local invitedCount = C_LFGList.GetNumInvitedApplicantMembers
		and C_LFGList.GetNumInvitedApplicantMembers() or 0
	local groupSize = self:GetGroupSize()

	if groupSize + applicantSize > memberLimit then
		return "full"
	end
	if groupSize + invitedCount + applicantSize > memberLimit then
		return useConfiguredLimit and "full" or "pending_invite"
	end
	if requiresRaidConversion(applicantSize, invitedCount)
		and InCombatLockdown and InCombatLockdown()
	then
		return "raid_conversion_in_combat"
	end
	return nil
end

function Actions:CanInvite(applicantID, options)
	local reason = self:EvaluateInvite(applicantID, options)
	return reason == nil, reason
end

function Actions:CanDecline(applicantID)
	local session = getRecruitmentSession()
	if applicantID == nil
		or not (session and session.CanManageApplicants
			and session:CanManageApplicants())
		or isTestApplicant(applicantID)
	then
		return false
	end
	local numericID = normalizeApplicantID(applicantID)
	if numericID == nil then
		return false
	end
	local application = readApplicantActionSnapshot(numericID)
	return application ~= nil
		and not application.applicantInfo
		and application.pendingApplicationStatus == nil
		and application.applicationStatus ~= "invited"
end

function Actions:CanRefresh()
	local session = getRecruitmentSession()
	local refresh = C_LFGList and C_LFGList.RefreshApplicants
	return type(refresh) == "function"
		and session ~= nil
		and session.HasActive ~= nil
		and session:HasActive() == true
		and not (session.IsBusy and session:IsBusy())
end

function Actions:Refresh()
	if self:CanRefresh() ~= true then
		return false
	end
	C_LFGList.RefreshApplicants()
	return true
end

function Actions:GetApplicantIDs()
	local reader = C_LFGList and C_LFGList.GetApplicants
	local ok, applicantIDs = false, nil
	if type(reader) == "function" then
		ok, applicantIDs = pcall(reader)
	end
	if not ok then
		return {}
	end
	return type(applicantIDs) == "table" and applicantIDs or {}
end

function Actions:GetApplicantCount()
	local reader = C_LFGList and C_LFGList.GetNumApplicants
	if type(reader) ~= "function" then
		return 0
	end
	local ok, _, activeCount = pcall(reader)
	if not ok then
		return 0
	end
	return tonumber(activeCount) or 0
end

function Actions:GetApplicantInfo(applicantID)
	if isTestApplicant(applicantID) then
		return nil
	end
	local numericID = normalizeApplicantID(applicantID)
	if numericID == nil then
		return nil, "missing"
	end
	return readApplicantActionSnapshot(numericID)
end

function Actions:Invite(applicantID, options)
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	if isTestApplicant(applicantID) then
		return false, "test_data"
	end
	local numericID = normalizeApplicantID(applicantID)
	if numericID == nil then
		return false, "missing"
	end
	local reason = self:EvaluateInvite(numericID, options)
	if reason ~= nil then
		return false, reason
	end
	if not (C_LFGList and type(C_LFGList.InviteApplicant) == "function") then
		return false, "no_api"
	end
	local application, readReason = readApplicantActionSnapshot(numericID)
	if application == nil then
		return false, readReason or "missing"
	end
	if application.applicantInfo
		or application.pendingApplicationStatus ~= nil
	then
		return false, "loading"
	end
	if application.applicationStatus ~= "applied" then
		return false, application.applicationStatus
	end
	local applicantSize = application.numMembers
	local invitedCount = C_LFGList.GetNumInvitedApplicantMembers
		and C_LFGList.GetNumInvitedApplicantMembers() or 0
	if requiresRaidConversion(applicantSize, invitedCount) then
		if type(InCombatLockdown) == "function" and InCombatLockdown() then
			return false, "raid_conversion_in_combat"
		end
		if type(StaticPopup_Show) == "function" then
			StaticPopup_Show(
				"LFG_LIST_INVITING_CONVERT_TO_RAID", nil, nil, numericID)
			return true, "raid_conversion_popup"
		end
	end
	playActionSound()
	C_LFGList.InviteApplicant(numericID)
	return true
end

function Actions:Accept(applicantID)
	local accepted, outcome = self:Invite(applicantID)
	if accepted ~= true then
		self:NotifyBlocked(outcome)
	end
	return accepted == true, outcome
end

function Actions:AcknowledgeTerminalApplicant(applicantID, expectedStatus)
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	if isTestApplicant(applicantID) then
		return false, "test_data", false
	end
	local session = getRecruitmentSession()
	if not (session and session.CanManageApplicants
		and session:CanManageApplicants())
	then
		return false, "unempowered", false
	end
	local numericID = normalizeApplicantID(applicantID)
	if numericID == nil then
		return false, "missing", false
	end
	local remove = C_LFGList and C_LFGList.RemoveApplicant
	if type(remove) ~= "function" then
		return false, "no_api", false
	end

	-- Terminal acknowledgement is destructive for the current provider record.
	-- Re-read immediately before submitting so a delayed callback cannot remove a
	-- same-ID application that has already returned to applied/pending.
	local application, readReason = readApplicantActionSnapshot(numericID)
	if application == nil then
		return false, readReason or "missing", false
	end
	local status = application.applicationStatus
	if expectedStatus ~= nil and status ~= expectedStatus then
		return false, "status_changed", false
	end
	if application.applicantInfo
	then
		return false, "loading", false
	end
	if ACKNOWLEDGEABLE_TERMINAL_STATUSES[status] ~= true then
		return false, status or "missing", false
	end

	local submitted = pcall(remove, numericID)
	if not submitted then
		return false, "api_error", true
	end
	return true, nil, true
end

function Actions:Decline(applicantID)
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	if isTestApplicant(applicantID)
		or not (C_LFGList and type(C_LFGList.DeclineApplicant) == "function")
	then
		return false
	end
	local session = getRecruitmentSession()
	if not (session and session.CanManageApplicants
		and session:CanManageApplicants())
	then
		self:NotifyBlocked("unempowered")
		return false
	end
	local numericID = normalizeApplicantID(applicantID)
	if numericID == nil then
		return false
	end
	local application, readReason = readApplicantActionSnapshot(numericID)
	if application == nil then
		return false, readReason or "missing"
	end
	if application.applicantInfo then
		return false, "loading"
	end
	if application.applicationStatus == "invited" then
		return false, "invited"
	end
	if application.applicationStatus ~= "applied" then
		-- A stale applied card can race a terminal provider snapshot.  Let the panel
		-- cache that terminal and establish its re-entry guard before the single
		-- destructive acknowledgement is submitted.
		return true, "terminal_observed", application.applicationStatus
	end
	if application.pendingApplicationStatus ~= nil then
		return false, "loading"
	end
	playActionSound()
	C_LFGList.DeclineApplicant(numericID)
	return true, "decline_submitted"
end
