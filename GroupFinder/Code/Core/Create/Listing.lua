local addonName, GF = ...

GF.Listing = {}

local function isCrossFactionEntry(entry)
	if type(entry) ~= "table" then
		return false
	end
	local value = entry.isCrossFactionListing
	if value == nil then
		value = entry.isCrossFaction
	end
	return value == true
end

function GF.Listing:CanManageEntry()
	if self:HasActive() ~= true then
		return false
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local empowered = type(LFGListUtil_IsEntryEmpowered) == "function"
		and LFGListUtil_IsEntryEmpowered() == true
	if empowered then
		return true
	end
	local home = LE_PARTY_CATEGORY_HOME
	local soloOwner = not IsInGroup(home)
	local partyOfficer = UnitIsGroupLeader("player", home)
		or UnitIsGroupAssistant("player", home)
	return soloOwner or partyOfficer
end

local function notifyUiError(message)
	if type(GF.ShowWarningMessage) ~= "function" then
		return
	end
	GF.ShowWarningMessage(message)
end

local MAX_APPLICANT_API_ID = 4294967295
local AUTO_INVITE_CONSTRAINTS = { respectMemberLimit = true }

local function isApplicantTestID(applicantID)
	local tests = GF.ApplicantTestData
	return tests ~= nil
		and type(tests.IsTestApplicantID) == "function"
		and tests:IsTestApplicantID(applicantID) == true
end

local function normalizeApplicantAPIID(applicantID)
	local numericID = tonumber(applicantID)
	if numericID == nil then
		return nil
	end
	if numericID < 0 or numericID > MAX_APPLICANT_API_ID then
		return nil
	end
	return numericID
end

local function usableGlobalMessage(value)
	return type(value) == "string" and value ~= "" and value or nil
end

local SILENT_APPLICANT_REASONS = {
	loading = true,
	missing = true,
	no_api = true,
}

local function applicantActionMessage(reason)
	if SILENT_APPLICANT_REASONS[reason] then
		return nil
	end
	local locale = GF.L or {}
	local direct = {
		unempowered = locale.ERR_MANAGE_ENTRY_ONLY,
		full = usableGlobalMessage(LFG_LIST_GROUP_TOO_FULL),
		pending_invite = usableGlobalMessage(LFG_LIST_INVITED_APP_FILLS_GROUP),
		raid_conversion_in_combat = locale.ERR_RAID_CONVERSION_IN_COMBAT
			or "Cannot convert to raid while in combat. Try again after combat.",
	}
	if direct[reason] ~= nil then
		return direct[reason]
	end
	return GF.Listing:GetApplicantStatusMessage(reason)
end

function GF.Listing:GetApplicantStatusMessage(status)
	if status == nil then
		return nil
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local messages = {
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
	return usableGlobalMessage(messages[status])
end

function GF.Listing:GetApplicantActionMessage(reason)
	local message = applicantActionMessage(reason)
	return message
end

function GF.Listing:NotifyApplicantActionBlocked(reason)
	local message = self:GetApplicantActionMessage(reason)
	if message ~= nil then
		notifyUiError(message)
	end
end

local function applicantInviteRequiresRaidConversion(numMembers, numInvited)
	local home = LE_PARTY_CATEGORY_HOME
	if IsInRaid(home) then
		return false
	end
	local partyCount = tonumber(GetNumGroupMembers(home)) or 0
	local incomingCount = tonumber(numMembers) or 1
	local reservedCount = tonumber(numInvited) or 0
	return partyCount + incomingCount + reservedCount > (MAX_PARTY_MEMBERS + 1)
end

function GF.Listing:GetApplicantInviteConstraint(applicantID, opts)
	if not self:CanManageEntry() then
		return "unempowered"
	end
	if not applicantID then
		return "missing"
	end
	if isApplicantTestID(applicantID) then
		return "test_data"
	end
	applicantID = normalizeApplicantAPIID(applicantID)
	if not applicantID then
		return "missing"
	end
	local application = C_LFGList.GetApplicantInfo(applicantID)
	if not application then
		return "missing"
	end
	if application.applicantInfo or application.pendingApplicationStatus ~= nil then
		return "loading"
	end
	if application.applicationStatus ~= "applied" then
		return application.applicationStatus
	end

	local db = GF.GetDB and GF.GetDB()
	local hasManualLimit = opts
		and opts.respectMemberLimit == true
		and db
		and db.autoInviteMemberLimitEnabled == true
	local memberLimit = hasManualLimit
		and self:GetConfiguredAutoInviteMemberLimit()
		or self:GetActivityMemberCapacity()
	local applicantSize = tonumber(application.numMembers) or 1
	local groupSize = self:GetHomeGroupHeadcount()
	local outstandingInvites = C_LFGList.GetNumInvitedApplicantMembers() or 0

	if groupSize + applicantSize > memberLimit then
		return "full"
	end
	if groupSize + outstandingInvites + applicantSize > memberLimit then
		return hasManualLimit and "full" or "pending_invite"
	end
	if applicantInviteRequiresRaidConversion(applicantSize, outstandingInvites)
		and InCombatLockdown and InCombatLockdown() then
		return "raid_conversion_in_combat"
	end
	return nil
end

function GF.Listing:GetHomeGroupHeadcount()
	-- Blizzard LFG invite-cap checks use GetNumGroupMembers directly; party counts
	-- already include the player on Retail.
	local reported = tonumber(GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)) or 0
	return reported > 0 and reported or 1
end

function GF.Listing:OnGroupRosterChanged()
	local currentSize = self:GetHomeGroupHeadcount()
	local previousSize = self._autoInviteLastHeadcount
	self._autoInviteLastHeadcount = currentSize
	if previousSize == nil or previousSize == currentSize then
		return
	end
	if not self:HasActive() or not self:IsAutoInviteEnabled() then
		return
	end
	self:QueueAutoInvite()
end

function GF.Listing:CanDeclineApplicant(applicantID)
	if applicantID == nil or self:CanManageEntry() ~= true then
		return false
	end
	if isApplicantTestID(applicantID) then
		return false
	end
	applicantID = normalizeApplicantAPIID(applicantID)
	if not applicantID then
		return false
	end
	local applicant = C_LFGList.GetApplicantInfo(applicantID)
	if applicant == nil or applicant.applicantInfo ~= nil
		or applicant.pendingApplicationStatus ~= nil
	then
		return false
	end
	return applicant.applicationStatus ~= "invited"
end

-- List / edit / remove / bump: party leader only (Blizzard LFGListUtil_CanListGroup / ApplicationViewer).
function GF.Listing:CanLeadListing()
	if type(LFGListUtil_CanListGroup) == "function" then
		return LFGListUtil_CanListGroup() == true
	end
	local home = LE_PARTY_CATEGORY_HOME
	if not IsInGroup(home) then
		return true
	end
	return UnitIsGroupLeader("player", home) == true
end

function GF.Listing:GetLeaderOnlyMessage()
	local locale = GF.L or {}
	return locale.ERR_LEADER_ONLY or "You are not authorized."
end

function GF.Listing:NotifyLeaderOnly()
	notifyUiError(self:GetLeaderOnlyMessage())
end

function GF.Listing:MarkNextActiveEntryAsGroupFinder()
	self._pendingGroupFinderActiveEntry = true
end

function GF.Listing:ClearPendingActiveEntryOwnership()
	self._pendingGroupFinderActiveEntry = nil
end

function GF.Listing:SyncActiveEntryOwnership(hasActive)
	if hasActive ~= true then
		local currentOwner = self._activeEntryOwnedByGroupFinder
		if currentOwner ~= nil then
			self._lastActiveEntryOwnedByGroupFinder = currentOwner
		end
		self._activeEntryOwnedByGroupFinder = nil
		self._pendingGroupFinderActiveEntry = nil
		return
	end

	if self._pendingGroupFinderActiveEntry == true then
		self._activeEntryOwnedByGroupFinder = true
		self._pendingGroupFinderActiveEntry = nil
	elseif self._activeEntryOwnedByGroupFinder == nil then
		self._activeEntryOwnedByGroupFinder = false
	end
end

function GF.Listing:IsActiveEntryGroupFinderOwned()
	return self._activeEntryOwnedByGroupFinder == true
end

function GF.Listing:WasLastActiveEntryGroupFinderOwned()
	return self._lastActiveEntryOwnedByGroupFinder == true
end

function GF.Listing:WasLastActiveEntryExternal()
	return self._lastActiveEntryOwnedByGroupFinder == false
end

function GF.Listing:HasActive()
	return C_LFGList.HasActiveEntryInfo() == true
end

function GF.Listing:GetActive()
	if self:HasActive() then
		return C_LFGList.GetActiveEntryInfo()
	end
	return nil
end

function GF.Listing:GetActiveActivityID()
	local entry = self:GetActive()
	if entry == nil then
		return nil
	end
	local activityIDs = entry.activityIDs
	if type(activityIDs) == "table" then
		return activityIDs[1] or entry.activityID
	end
	return entry.activityID
end

function GF.Listing:GetActiveEntryName()
	local entry = self:GetActive()
	return entry and entry.name or ""
end

local USER_REMOVE_RESET_TIMEOUT_SEC = 8

local function clearPendingUserRemoveReset(listing, expectedGeneration)
	local generation = listing._pendingUserRemoveReset
	if expectedGeneration ~= nil and generation ~= expectedGeneration then
		return false
	end
	local timer = listing._userRemoveResetTimer
	listing._userRemoveResetTimer = nil
	listing._pendingUserRemoveReset = nil
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
	return generation ~= nil
end

local function markPendingUserRemoveReset(listing)
	clearPendingUserRemoveReset(listing)
	local generation = (listing._userRemoveResetGeneration or 0) + 1
	listing._userRemoveResetGeneration = generation
	listing._pendingUserRemoveReset = generation
	local function expirePendingReset()
		clearPendingUserRemoveReset(listing, generation)
	end
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		listing._userRemoveResetTimer = C_Timer.NewTimer(
			USER_REMOVE_RESET_TIMEOUT_SEC,
			expirePendingReset)
	elseif C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(USER_REMOVE_RESET_TIMEOUT_SEC, expirePendingReset)
	end
end

function GF.Listing:ConsumePendingUserRemoveReset()
	return clearPendingUserRemoveReset(self)
end

function GF.Listing:Remove()
	local bumpBusy = type(self.IsBumpBusy) == "function" and self:IsBumpBusy()
	if bumpBusy then
		return false
	end
	markPendingUserRemoveReset(self)
	self:ClearAutoInviteForSession()
	C_LFGList.RemoveListing()
	return true
end

function GF.Listing:BuildCreateDataFromActive(overrides)
	local entry = self:GetActive()
	if entry == nil then
		return nil
	end
	local activityID = self:GetActiveActivityID()
	if activityID == nil then
		return nil
	end
	local requestedAutoAccept = type(overrides) == "table"
		and overrides.isAutoAccept or nil
	if type(overrides) ~= "table" or overrides.isAutoAccept == nil then
		requestedAutoAccept = entry.autoAccept
	end
	return {
		activityIDs = { activityID },
		questID = entry.questID,
		isAutoAccept = requestedAutoAccept == true,
		isCrossFactionListing = isCrossFactionEntry(entry),
		isPrivateGroup = entry.privateGroup == true,
		newPlayerFriendly = entry.newPlayerFriendly == true,
		playstyle = entry.playstyle or Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = entry.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = tonumber(entry.requiredDungeonScore) or 0,
		requiredItemLevel = tonumber(entry.requiredItemLevel) or 0,
		requiredPvpRating = tonumber(entry.requiredPvpRating) or 0,
	}
end

function GF.Listing:BuildCreateDataFromParams(params)
	if type(params) ~= "table" or params.activityID == nil then
		return nil
	end
	local active = self:GetActive()
	local friendly = params.newPlayerFriendly == true
	if active then
		friendly = active.newPlayerFriendly == true
	end
	return {
		activityIDs = { params.activityID },
		questID = active and active.questID or params.questID,
		isAutoAccept = active ~= nil and active.autoAccept == true,
		isCrossFactionListing = params.isCrossFactionListing == true,
		isPrivateGroup = params.isPrivateGroup == true,
		newPlayerFriendly = friendly,
		playstyle = Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = params.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = tonumber(params.requiredDungeonScore) or 0,
		requiredItemLevel = tonumber(params.requiredItemLevel) or 0,
		requiredPvpRating = tonumber(params.requiredPvpRating) or 0,
	}
end

local function updateListingWithOwnership(listing, createData, copyNativeFields)
	if createData == nil then
		return false
	end
	if copyNativeFields and type(C_LFGList.CopyActiveEntryInfoToCreationFields) == "function" then
		C_LFGList.CopyActiveEntryInfoToCreationFields()
	end
	local ownership = {
		current = listing._activeEntryOwnedByGroupFinder,
		last = listing._lastActiveEntryOwnedByGroupFinder,
	}
	listing:MarkNextActiveEntryAsGroupFinder()
	local accepted = C_LFGList.UpdateListing(createData) == true
	if accepted then
		return true
	end
	listing:ClearPendingActiveEntryOwnership()
	listing._activeEntryOwnedByGroupFinder = ownership.current
	listing._lastActiveEntryOwnedByGroupFinder = ownership.last
	return false
end

local function canUpdateListing(listing)
	local bumpBusy = type(listing.IsBumpBusy) == "function"
		and listing:IsBumpBusy()
	return not bumpBusy and listing:CanLeadListing()
end

function GF.Listing:UpdateActive(overrides)
	if not canUpdateListing(self) then
		return false
	end
	return updateListingWithOwnership(
		self,
		self:BuildCreateDataFromActive(overrides),
		true)
end

function GF.Listing:UpdateFromParams(params)
	if not canUpdateListing(self) then
		return false
	end
	-- Name/comment come from EntryCreation fields; do not CopyActiveEntryInfoToCreationFields here.
	return updateListingWithOwnership(
		self,
		self:BuildCreateDataFromParams(params),
		false)
end

local BUMP_COOLDOWN_SEC = 60
local BUMP_COOLDOWN_TICK_SEC = 1
local BUMP_CONFIRM_TIMEOUT_SEC = 8

local function recordBumpFailure(self, stage)
	self._lastBumpRelistFailureStage = stage or "unknown"
	self._lastBumpRelistFailureAt = GetTime()
end

local function notifyBumpFailure(self, stage)
	recordBumpFailure(self, stage)
	local L = GF.L or {}
	notifyUiError(L.BUMP_LISTING_FAILED or "Could not relist.")
end

local function refreshApplicantManageState()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateManageState then
		GF.ApplicantsPanel:UpdateManageState()
	end
end

local function refreshBumpButtonState()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateBumpButtonState then
		GF.ApplicantsPanel:UpdateBumpButtonState()
	else
		refreshApplicantManageState()
	end
end

local function cancelBumpCooldownRefresh(self)
	self._bumpCooldownRefreshGeneration = (self._bumpCooldownRefreshGeneration or 0) + 1
	if self._bumpCooldownTicker and self._bumpCooldownTicker.Cancel then
		self._bumpCooldownTicker:Cancel()
	end
	self._bumpCooldownTicker = nil
end

local function scheduleBumpCooldownRefresh(self)
	cancelBumpCooldownRefresh(self)
	refreshBumpButtonState()
	if not self._lastBumpAt or self:GetBumpCooldownRemaining() <= 0 or not C_Timer then
		return
	end
	local generation = self._bumpCooldownRefreshGeneration
	local function refreshCooldown()
		if generation ~= self._bumpCooldownRefreshGeneration then
			return
		end
		refreshBumpButtonState()
		if self:GetBumpCooldownRemaining() <= 0 then
			cancelBumpCooldownRefresh(self)
		end
	end
	if C_Timer.NewTicker then
		self._bumpCooldownTicker = C_Timer.NewTicker(BUMP_COOLDOWN_TICK_SEC, refreshCooldown)
	elseif C_Timer.After then
		local function refreshWithGeneration()
			if generation ~= self._bumpCooldownRefreshGeneration then
				return
			end
			refreshCooldown()
			if generation == self._bumpCooldownRefreshGeneration
				and self:GetBumpCooldownRemaining() > 0 then
				C_Timer.After(BUMP_COOLDOWN_TICK_SEC, refreshWithGeneration)
			end
		end
		C_Timer.After(BUMP_COOLDOWN_TICK_SEC, refreshWithGeneration)
	end
end

local function cancelBumpRelistTimer(self)
	if self._bumpRelistTimer and self._bumpRelistTimer.Cancel then
		self._bumpRelistTimer:Cancel()
	end
	self._bumpRelistTimer = nil
end

local function beginBumpRelist(self)
	cancelBumpRelistTimer(self)
	self._bumpRelistGeneration = (self._bumpRelistGeneration or 0) + 1
	self._bumpRelistState = "removing"
	self._bumpRelistStage = "removing"
	self._bumpRelistCreationFailed = nil
	self._bumpRelistFenceRestoreFailed = nil
	self._bumpRelistStartedAt = GetTime()
	return self._bumpRelistGeneration
end

local function isCurrentBumpRelist(self, generation)
	return self._bumpRelistState ~= nil and self._bumpRelistGeneration == generation
end

local function endBumpRelist(self, generation)
	if self._bumpRelistGeneration ~= generation then
		return
	end
	cancelBumpRelistTimer(self)
	self._bumpRelistState = nil
	self._bumpRelistStage = nil
	self._bumpRelistCreationFailed = nil
	self._bumpRelistFenceRestoreFailed = nil
	self._bumpRelistStartedAt = nil
end

local function finishBumpRelist(self, generation, ok, opts)
	if not isCurrentBumpRelist(self, generation) then
		return false
	end
	opts = opts or {}
	self._bumpBusyUntil = nil
	if ok then
		self._lastBumpAt = GetTime()
		self._lastBumpRelistFailureStage = nil
		self._lastBumpRelistFailureAt = nil
		self:ClearAutoInviteForSession()
	else
		self:ClearPendingActiveEntryOwnership()
		notifyBumpFailure(self, self._bumpRelistStage)
	end
	self._lastBumpRelistGeneration = generation
	self._lastBumpRelistSucceeded = ok == true
	self._lastBumpRelistFenceRestoreFailed =
		self._bumpRelistFenceRestoreFailed == generation
	endBumpRelist(self, generation)
	if ok then
		scheduleBumpCooldownRefresh(self)
	end
	refreshApplicantManageState()
	if not opts.skipUiRefresh and GF.MainFrame and GF.MainFrame.OnActiveEntryUpdate then
		GF.MainFrame:OnActiveEntryUpdate({
			finalizeBump = true,
			bumpSucceeded = ok == true,
			suppressCreateAutoOpen = not ok,
		})
	end
	return true
end

function GF.Listing:IsBumpRelisting()
	return self._bumpRelistState ~= nil
end

function GF.Listing:IsBumpBusy()
	return self:IsBumpRelisting()
		or (self._bumpBusyUntil and GetTime() < self._bumpBusyUntil)
end

function GF.Listing:GetBumpCooldownRemaining()
	if not self._lastBumpAt then
		return 0
	end
	return math.max(0, BUMP_COOLDOWN_SEC - (GetTime() - self._lastBumpAt))
end

function GF.Listing:IsBumpOnCooldown()
	return self:GetBumpCooldownRemaining() > 0
end

function GF.Listing:GetLastBumpRelistFailureStage()
	return self._lastBumpRelistFailureStage,
		self._lastBumpRelistFenceRestoreFailed == true
end

function GF.Listing:SetBumpFieldBridge(bridge)
	self._bumpFieldBridge = bridge
end

function GF.Listing:ResolveBumpRelistEvent(hasActive, createdNew)
	if self:IsBumpRelisting() ~= true then
		return nil
	end
	local state = self._bumpRelistState
	local waitingForCreate = state == "creating"
		or state == "awaiting_confirmation"
	if not waitingForCreate then
		return "pending"
	end
	local generation = self._bumpRelistGeneration
	if self._bumpRelistCreationFailed == generation then
		finishBumpRelist(self, generation, false, { skipUiRefresh = true })
		return "failed"
	end
	if hasActive ~= true or createdNew ~= true then
		return "pending"
	end
	finishBumpRelist(self, generation, true, { skipUiRefresh = true })
	return "success"
end

function GF.Listing:CanRefreshApplicants()
	local refresh = C_LFGList and C_LFGList.RefreshApplicants
	local bumpBusy = type(self.IsBumpBusy) == "function" and self:IsBumpBusy()
	return type(refresh) == "function"
		and self:HasActive() == true
		and bumpBusy ~= true
end

function GF.Listing:RefreshApplicants()
	if self:CanRefreshApplicants() ~= true then
		return false
	end
	local refresh = C_LFGList.RefreshApplicants
	refresh()
	return true
end

function GF.Listing:RelistForBump()
	local blocked = self:CanLeadListing() ~= true
		or self:HasActive() ~= true
		or self:IsBumpOnCooldown()
		or self._pendingUserRemoveReset ~= nil
		or self:IsBumpBusy()
		or self._bumpRelistTimer ~= nil
	if blocked then
		return false
	end
	local createData = self:BuildCreateDataFromActive()
	if createData == nil then
		return false
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local bridge = self._bumpFieldBridge
	local bridgeReady = type(bridge) == "table"
		and type(bridge.Acquire) == "function"
		and type(bridge.ResumeAfterRemove) == "function"
		and type(bridge.Release) == "function"
	if not bridgeReady then
		notifyBumpFailure(self, "bridge_unavailable")
		return false
	end
	local copyActiveFields = C_LFGList.CopyActiveEntryInfoToCreationFields
	if type(copyActiveFields) ~= "function" then
		notifyBumpFailure(self, "copy_active_fields_unavailable")
		return false
	end
	local copied = pcall(copyActiveFields)
	if not copied then
		notifyBumpFailure(self, "copy_active_fields_failed")
		return false
	end
	local leaseOk, bumpLease = pcall(bridge.Acquire)
	if not leaseOk or not bumpLease then
		notifyBumpFailure(self, "inactive_fence_failed")
		return false
	end
	local function releaseBumpLease()
		if not bumpLease then
			return
		end
		pcall(bridge.Release, bumpLease)
		bumpLease = nil
	end
	local generation = beginBumpRelist(self)
	self:ClearAutoInviteForSession()
	-- Keep known external consumers paused only for the synchronous inactive
	-- event; they are restored immediately below, before the created event.
	local removeCallOk = pcall(C_LFGList.RemoveListing)
	if not removeCallOk then
		self._bumpRelistStage = "remove_call_failed"
		releaseBumpLease()
		finishBumpRelist(self, generation, false)
		return false
	end
	local resumeCallOk, resumed = pcall(bridge.ResumeAfterRemove, bumpLease)
	if not resumeCallOk or resumed ~= true then
		-- The old listing has already been removed. Release() retries any
		-- listener restoration, but still attempt CreateListing() so a
		-- compatibility callback cannot turn a bump into a pure delist.
		self._bumpRelistFenceRestoreFailed = generation
	end
	if not isCurrentBumpRelist(self, generation) then
		releaseBumpLease()
		return self._lastBumpRelistGeneration == generation
			and self._lastBumpRelistSucceeded == true
	end
	self._bumpRelistState = "creating"
	self._bumpRelistStage = "creating"
	self:MarkNextActiveEntryAsGroupFinder()
	-- CreateListing is restricted and must stay in this original click stack.
	local createCallOk, createAccepted = pcall(C_LFGList.CreateListing, createData)
	releaseBumpLease()
	if not isCurrentBumpRelist(self, generation) then
		return self._lastBumpRelistGeneration == generation
			and self._lastBumpRelistSucceeded == true
	end
	if not createCallOk
		or createAccepted ~= true
		or self._bumpRelistCreationFailed == generation
	then
		if self._bumpRelistCreationFailed == generation then
			self._bumpRelistStage = "creation_failed_event"
		elseif not createCallOk then
			self._bumpRelistStage = "create_call_error"
		else
			self._bumpRelistStage = "create_return_false"
		end
		finishBumpRelist(self, generation, false)
		return false
	end
	self._bumpRelistState = "awaiting_confirmation"
	self._bumpRelistStage = "awaiting_confirmation"
	local function confirmTimeout()
		if not isCurrentBumpRelist(self, generation) then
			return
		end
		self._bumpRelistTimer = nil
		self._bumpRelistStage = "confirm_timeout"
		finishBumpRelist(self, generation, false)
	end
	if C_Timer and C_Timer.NewTimer then
		self._bumpRelistTimer = C_Timer.NewTimer(
			BUMP_CONFIRM_TIMEOUT_SEC,
			confirmTimeout
		)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(BUMP_CONFIRM_TIMEOUT_SEC, confirmTimeout)
	else
		confirmTimeout()
	end
	return true
end

function GF.Listing:Create(params)
	if type(params) ~= "table" or params.activityID == nil then
		return false
	end
	local bumpBusy = type(self.IsBumpBusy) == "function" and self:IsBumpBusy()
	if bumpBusy or self:CanLeadListing() ~= true then
		return false
	end
	local createData = {
		activityIDs = { params.activityID },
		questID = params.questID,
		isAutoAccept = params.isAutoAccept == true,
		isCrossFactionListing = params.isCrossFactionListing == true,
		isPrivateGroup = params.isPrivateGroup == true,
		newPlayerFriendly = params.newPlayerFriendly == true,
		playstyle = Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = params.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = tonumber(params.requiredDungeonScore) or 0,
		requiredItemLevel = tonumber(params.requiredItemLevel) or 0,
		requiredPvpRating = tonumber(params.requiredPvpRating) or 0,
	}
	local ownership = {
		current = self._activeEntryOwnedByGroupFinder,
		last = self._lastActiveEntryOwnedByGroupFinder,
	}
	self:MarkNextActiveEntryAsGroupFinder()
	local accepted = C_LFGList.CreateListing(createData) == true
	if accepted then
		return true
	end
	self:ClearPendingActiveEntryOwnership()
	self._activeEntryOwnedByGroupFinder = ownership.current
	self._lastActiveEntryOwnedByGroupFinder = ownership.last
	return false
end

function GF.Listing:OnCreationFailed()
	local bumpState = self._bumpRelistState
	local duringBump = bumpState == "creating"
		or bumpState == "awaiting_confirmation"
	if not duringBump then
		local locale = GF.L or {}
		notifyUiError(locale.CREATE_FAILED or "Listing failed. Please try again.")
		return nil
	end
	local generation = self._bumpRelistGeneration
	self._bumpRelistCreationFailed = generation
	self._bumpRelistStage = "creation_failed_event"
	self:ClearPendingActiveEntryOwnership()
	finishBumpRelist(self, generation, false, { skipUiRefresh = true })
	return "failed"
end

function GF.Listing:GetApplicantIDs()
	local ids = C_LFGList.GetApplicants()
	return type(ids) == "table" and ids or {}
end

function GF.Listing:GetApplicantCount()
	if type(C_LFGList.GetNumApplicants) ~= "function" then
		return 0
	end
	local _, activeCount = C_LFGList.GetNumApplicants()
	return tonumber(activeCount) or 0
end

local function collectAppliedApplicantIDs()
	local applied = {}
	if type(C_LFGList.GetApplicants) ~= "function" then
		return applied
	end
	for _, applicantID in ipairs(C_LFGList.GetApplicants() or {}) do
		local applicant = type(C_LFGList.GetApplicantInfo) == "function"
			and C_LFGList.GetApplicantInfo(applicantID) or nil
		local status = applicant and applicant.applicationStatus or nil
		if status == nil or status == "applied" then
			applied[tostring(applicantID)] = true
		end
	end
	return applied
end

function GF.Listing:ResetApplicantAlertState()
	self._applicantAlertIDs = nil
	self._applicantAlertCooldownUntil = nil
end

function GF.Listing:SyncApplicantAlertBaseline()
	if not self:HasActive() or not self:CanManageEntry() then
		self:ResetApplicantAlertState()
		return
	end
	self._applicantAlertIDs = collectAppliedApplicantIDs()
end

function GF.Listing:StopApplicantAlertSound()
	local handle = self._applicantAlertSoundHandle
	self._applicantAlertSoundHandle = nil
	if handle and StopSound then
		pcall(StopSound, handle)
	end
end

function GF.Listing:PlayApplicantAlertSound(file, opts)
	if opts and opts.stopPrevious then
		self:StopApplicantAlertSound()
	end
	local db = GF.GetDB and GF.GetDB()
	file = file ~= nil and file or (db and db.applicantAlertSoundFile)
	local soundPath = GF.GetApplicantAlertSoundPath and GF.GetApplicantAlertSoundPath(file)
	if not soundPath or soundPath == "" then
		return false
	end
	if PlaySoundFile then
		local ok, played, handle = pcall(PlaySoundFile, soundPath, "Master")
		if ok and played then
			self._applicantAlertSoundHandle = tonumber(handle) or tonumber(played) or self._applicantAlertSoundHandle
			return true
		end
	end
	if PlaySound and _G.SOUNDKIT and _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
		pcall(PlaySound, _G.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		return true
	end
	return false
end

function GF.Listing:PreviewApplicantAlertSound(file)
	return self:PlayApplicantAlertSound(file, { stopPrevious = true })
end

function GF.Listing:MaybePlayApplicantAlert()
	if not self:HasActive() or not self:CanManageEntry() then
		self:ResetApplicantAlertState()
		return false
	end
	local current = collectAppliedApplicantIDs()
	local previous = self._applicantAlertIDs
	self._applicantAlertIDs = current
	if not previous then
		return false
	end
	local hasNewApplicant = false
	for applicantID in pairs(current) do
		if not previous[applicantID] then
			hasNewApplicant = true
			break
		end
	end
	if not hasNewApplicant then
		return false
	end
	local now = GetTime and GetTime() or 0
	local cooldownUntil = tonumber(self._applicantAlertCooldownUntil) or 0
	if now < cooldownUntil then
		return false
	end
	local played = self:PlayApplicantAlertSound()
	if played then
		self._applicantAlertCooldownUntil = now + (GF.APPLICANT_ALERT_SOUND_COOLDOWN_SECONDS or 10)
	end
	return played
end

function GF.Listing:GetApplicantInfo(applicantID)
	if isApplicantTestID(applicantID) then
		return nil
	end
	applicantID = normalizeApplicantAPIID(applicantID)
	if not applicantID then
		return nil
	end
	return C_LFGList.GetApplicantInfo(applicantID)
end

local function playApplicantActionSound()
	local sound = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
	if sound and type(PlaySound) == "function" then
		PlaySound(sound)
	end
end

function GF.Listing:InviteApplicant(applicantID, opts)
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	if isApplicantTestID(applicantID) then
		return false, "test_data"
	end
	local numericID = normalizeApplicantAPIID(applicantID)
	if numericID == nil then
		return false, "missing"
	end
	local reason = self:GetApplicantInviteConstraint(numericID, opts)
	if reason ~= nil then
		return false, reason
	end
	if type(C_LFGList.InviteApplicant) ~= "function" then
		return false, "no_api"
	end
	local applicant = C_LFGList.GetApplicantInfo(numericID)
	local applicantSize = applicant and applicant.numMembers or 1
	local pendingInvites = C_LFGList.GetNumInvitedApplicantMembers() or 0
	if applicantInviteRequiresRaidConversion(applicantSize, pendingInvites) then
		if type(InCombatLockdown) == "function" and InCombatLockdown() then
			return false, "raid_conversion_in_combat"
		end
		if type(StaticPopup_Show) == "function" then
			StaticPopup_Show("LFG_LIST_INVITING_CONVERT_TO_RAID", nil, nil, numericID)
			return true, "raid_conversion_popup"
		end
	end
	playApplicantActionSound()
	C_LFGList.InviteApplicant(numericID)
	return true
end

function GF.Listing:Accept(applicantID)
	local accepted, outcome = self:InviteApplicant(applicantID)
	if accepted then
		return true, outcome
	end
	self:NotifyApplicantActionBlocked(outcome)
	return false, outcome
end

function GF.Listing:Decline(applicantID)
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	if isApplicantTestID(applicantID)
		or type(C_LFGList.DeclineApplicant) ~= "function"
	then
		return false
	end
	if self:CanManageEntry() ~= true then
		self:NotifyApplicantActionBlocked("unempowered")
		return false
	end
	local numericID = normalizeApplicantAPIID(applicantID)
	if numericID == nil then
		return false
	end
	local applicant = C_LFGList.GetApplicantInfo(numericID)
	if applicant == nil or applicant.applicantInfo ~= nil
		or applicant.pendingApplicationStatus ~= nil
	then
		return false
	end
	local status = applicant.applicationStatus
	if status == "invited" then
		return false
	end
	if status ~= "applied" then
		C_LFGList.RemoveApplicant(numericID)
		return true
	end
	playApplicantActionSound()
	C_LFGList.DeclineApplicant(numericID)
	return true
end

local AUTO_INVITE_COOLDOWN_SEC = 1
local AUTO_INVITE_LIMIT_DELAY_SEC = 3

local function autoInviteStepDelay()
	local db = GF.GetDB and GF.GetDB()
	if db and db.autoInviteMemberLimitEnabled == true then
		return AUTO_INVITE_LIMIT_DELAY_SEC
	end
	return AUTO_INVITE_COOLDOWN_SEC
end

local function cancelAutoInviteChain(listing)
	local timer = listing._autoInviteChainTimer
	listing._autoInviteChainTimer = nil
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
end

local function activeEntryAutoInviteKey()
	if C_LFGList.HasActiveEntryInfo() ~= true then
		return nil
	end
	local entry = C_LFGList.GetActiveEntryInfo()
	if type(entry) ~= "table" then
		return nil
	end
	local activities = entry.activityIDs
	local activityID = type(activities) == "table" and activities[1]
		or entry.activityID or 0
	local privateFlag = entry.privateGroup == true and "1" or "0"
	return table.concat({ tostring(activityID), tostring(entry.questID or 0), privateFlag }, ":")
end

function GF.Listing:RestoreAutoInviteSession()
	local db = GF.GetDB()
	local entryKey = self:HasActive() and activeEntryAutoInviteKey() or nil
	local restore = db.autoInviteEnabled == true
		and entryKey ~= nil
		and db.autoInviteEntrySig == entryKey
	self._autoInviteCursorID = nil
	if restore then
		self._autoInviteEnabled = true
		return
	end
	self._autoInviteEnabled = false
	db.autoInviteEnabled = false
	db.autoInviteEntrySig = nil
end

function GF.Listing:IsAutoInviteEnabled()
	if self._autoInviteEnabled == nil then
		self:RestoreAutoInviteSession()
	end
	local enabled = self._autoInviteEnabled
	return enabled == true
end

function GF.Listing:SetAutoInviteEnabled(enabled)
	if self:HasActive() ~= true then
		return
	end
	local db = GF.GetDB()
	if enabled == true then
		self._autoInviteEnabled = true
		db.autoInviteEnabled = true
		db.autoInviteEntrySig = activeEntryAutoInviteKey()
		self._autoInviteCursorID = nil
		return
	end
	self._autoInviteEnabled = false
	self._autoInviteCooldownUntil = nil
	self._autoInviteInFlight = nil
	self._autoInviteLastHeadcount = nil
	self._autoInviteCursorID = nil
	cancelAutoInviteChain(self)
	db.autoInviteEnabled = false
	db.autoInviteEntrySig = nil
end

function GF.Listing:StopAutoInviteAtMemberLimit()
	local db = GF.GetDB and GF.GetDB()
	if not db or db.autoInviteMemberLimitEnabled ~= true then
		return false
	end
	local occupied = self:GetHomeGroupHeadcount() + (C_LFGList.GetNumInvitedApplicantMembers() or 0)
	if occupied < self:GetConfiguredAutoInviteMemberLimit() then
		return false
	end
	self:SetAutoInviteEnabled(false)
	refreshApplicantManageState()
	return true
end

function GF.Listing:ClearAutoInviteForSession()
	cancelAutoInviteChain(self)
	for _, field in ipairs({
		"_autoInviteCooldownUntil",
		"_autoInviteInFlight",
		"_autoInviteLastHeadcount",
		"_autoInviteCursorID",
	}) do
		self[field] = nil
	end
	self._autoInviteEnabled = false
	local db = GF.GetDB()
	db.autoInviteEnabled = false
	db.autoInviteEntrySig = nil
end

function GF.Listing:QueueAutoInvite()
	if self:IsAutoInviteEnabled() ~= true or self._autoInviteQueued == true then
		return
	end
	self._autoInviteQueued = true
	local function runQueuedInvite()
		self._autoInviteQueued = nil
		self:TryAutoInviteOne()
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, runQueuedInvite)
	else
		runQueuedInvite()
	end
end

local function scheduleAutoInviteChain(listing)
	cancelAutoInviteChain(listing)
	if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
		return
	end
	local function continueAutoInvite()
		listing._autoInviteChainTimer = nil
		if type(listing.TryAutoInviteOne) == "function" then
			listing:TryAutoInviteOne()
		end
	end
	listing._autoInviteChainTimer = C_Timer.NewTimer(
		autoInviteStepDelay(),
		continueAutoInvite)
end

function GF.Listing:CanToggleAutoInvite()
	local isLeader = UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) == true
	return isLeader and self:HasActive()
end

function GF.Listing:GetActivityMemberCapacity()
	local activityID = self:GetActiveActivityID()
	if activityID == nil then
		return MAX_RAID_MEMBERS
	end
	local activity = C_LFGList.GetActivityInfoTable(activityID)
	local capacity = activity and tonumber(activity.maxNumPlayers) or nil
	return capacity and capacity > 0 and capacity or MAX_RAID_MEMBERS
end

function GF.Listing:GetConfiguredAutoInviteMemberLimit()
	local activityLimit = self:GetActivityMemberCapacity()
	local db = GF.GetDB and GF.GetDB()
	if not db or db.autoInviteMemberLimitEnabled ~= true then
		return activityLimit
	end

	local lower = GF.AUTO_INVITE_MEMBER_LIMIT_MIN or 1
	local upper = GF.AUTO_INVITE_MEMBER_LIMIT_MAX or 40
	local fallback = GF.AUTO_INVITE_MEMBER_LIMIT_DEFAULT or 40
	local configured = math.floor(tonumber(db.autoInviteMemberLimit) or fallback)
	configured = math.min(upper, math.max(lower, configured))
	return math.min(activityLimit, configured)
end

function GF.Listing:CanInviteApplicant(applicantID, opts)
	return self:GetApplicantInviteConstraint(applicantID, opts) == nil
end

function GF.Listing:GetNextAutoInviteApplicant(ids)
	local candidates = type(ids) == "table" and ids or {}
	local count = #candidates
	if count == 0 then
		self._autoInviteCursorID = nil
		return nil
	end
	local cursorIndex = 0
	for index, candidateID in ipairs(candidates) do
		if candidateID == self._autoInviteCursorID then
			cursorIndex = index
			break
		end
	end
	local lastCandidate
	for step = 1, count do
		local index = ((cursorIndex + step - 1) % count) + 1
		local candidateID = candidates[index]
		lastCandidate = candidateID
		if self:CanInviteApplicant(candidateID, AUTO_INVITE_CONSTRAINTS) then
			self._autoInviteCursorID = candidateID
			return candidateID
		end
	end
	self._autoInviteCursorID = lastCandidate
	return nil
end

function GF.Listing:TryAutoInviteOne()
	local now = GetTime()
	local coolingDown = self._autoInviteCooldownUntil
		and now < self._autoInviteCooldownUntil
	local unavailable = self._autoInviteInFlight ~= nil
		or self:IsAutoInviteEnabled() ~= true
		or self:CanToggleAutoInvite() ~= true
		or coolingDown
		or type(C_LFGList.InviteApplicant) ~= "function"
	if unavailable then
		return
	end
	if self:StopAutoInviteAtMemberLimit() then
		return
	end
	local model = GF.ApplicantModel
	local candidates = model and type(model.GetSortedApplicantIDs) == "function"
		and model:GetSortedApplicantIDs()
		or C_LFGList.GetApplicants() or {}
	local applicantID = self:GetNextAutoInviteApplicant(candidates)
	if applicantID == nil then
		return
	end
	self._autoInviteCooldownUntil = now + autoInviteStepDelay()
	self._autoInviteInFlight = applicantID
	local accepted, outcome = self:InviteApplicant(applicantID, AUTO_INVITE_CONSTRAINTS)
	self._autoInviteInFlight = nil
	if not accepted then
		self._autoInviteCooldownUntil = nil
		return
	end
	if outcome ~= "raid_conversion_popup" then
		scheduleAutoInviteChain(self)
	end
end

function GF.Listing:GetActiveActivityTitle()
	local activityID = self:GetActiveActivityID()
	if activityID == nil then
		return ""
	end
	local activity = C_LFGList.GetActivityInfoTable(activityID)
	if type(activity) ~= "table" then
		return ""
	end
	local categoryID = activity.categoryID
	if GF.NavData and type(GF.NavData.FindNodeByActivityID) == "function" then
		local node = GF.NavData.FindNodeByActivityID(activityID)
		if type(node) == "table" and node.categoryID ~= nil then
			categoryID = node.categoryID
		end
	end
	if GF.UI and type(GF.UI.GetCategoryTitle) == "function" then
		return GF.UI.GetCategoryTitle(categoryID, activity)
	end
	return activity.fullName or activity.shortName or ""
end

function GF.Listing:CrossFactionChanged(newIsCrossFaction)
	local entry = self:GetActive()
	if type(entry) ~= "table" then
		return false
	end
	local currentValue = isCrossFactionEntry(entry)
	local requestedValue = newIsCrossFaction == true
	return currentValue ~= requestedValue
end
