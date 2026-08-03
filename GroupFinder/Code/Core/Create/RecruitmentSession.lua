local _, GF = ...

local Session = {}
GF.RecruitmentSession = Session

Session.AUTO_ACCEPT_CONTROL_MODE_NATIVE_QUEST = "native_quest_auto_accept"

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

function Session:CanManageApplicants()
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

-- List / edit / remove / bump: party leader only (Blizzard LFGListUtil_CanListGroup / ApplicationViewer).
function Session:CanPublish()
	if type(LFGListUtil_CanListGroup) == "function" then
		return LFGListUtil_CanListGroup() == true
	end
	local home = LE_PARTY_CATEGORY_HOME
	if not IsInGroup(home) then
		return true
	end
	return UnitIsGroupLeader("player", home) == true
end

function Session:GetLeaderOnlyMessage()
	local locale = GF.L or {}
	return locale.ERR_LEADER_ONLY or "You are not authorized."
end

function Session:NotifyLeaderOnly()
	notifyUiError(self:GetLeaderOnlyMessage())
end

function Session:BeginOwnedEntryRequest()
	self._pendingGroupFinderActiveEntry = true
end

function Session:CancelOwnedEntryRequest()
	self._pendingGroupFinderActiveEntry = nil
end

function Session:SyncEntryOwnership(hasActive)
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

function Session:IsActiveEntryOwned()
	return self._activeEntryOwnedByGroupFinder == true
end

function Session:WasLastEntryOwned()
	return self._lastActiveEntryOwnedByGroupFinder == true
end

function Session:WasLastEntryExternal()
	return self._lastActiveEntryOwnedByGroupFinder == false
end

function Session:HasActive()
	return C_LFGList.HasActiveEntryInfo() == true
end

function Session:GetActive()
	if self:HasActive() then
		return C_LFGList.GetActiveEntryInfo()
	end
	return nil
end

function Session:GetActiveActivityID()
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

function Session:GetActiveEntryName()
	local entry = self:GetActive()
	return entry and entry.name or ""
end

function Session:UsesNativeQuestAutoAccept()
	local entry = self:GetActive()
	if type(entry) ~= "table" then
		return false
	end
	local questID = tonumber(entry.questID)
	return questID ~= nil and questID > 0
end

local function canActiveEntryUseAutoAccept()
	local checker = C_LFGList and C_LFGList.CanActiveEntryUseAutoAccept
	if type(checker) ~= "function" then
		return false
	end
	local ok, allowed = pcall(checker)
	return ok and allowed == true
end

function Session:GetActiveAutoAcceptControlState()
	if self:UsesNativeQuestAutoAccept() ~= true then
		return nil
	end
	local entry = self:GetActive()
	if type(entry) ~= "table" then
		return nil
	end
	local canPublish = self:CanPublish() == true
	local busy = type(self.IsBusy) == "function" and self:IsBusy() == true
	local supported = canActiveEntryUseAutoAccept()
	local disabledReason
	if not canPublish then
		disabledReason = "unempowered"
	elseif busy then
		disabledReason = "busy"
	elseif not supported then
		disabledReason = "unsupported"
	end
	return {
		mode = self.AUTO_ACCEPT_CONTROL_MODE_NATIVE_QUEST,
		checked = entry.autoAccept == true,
		canToggle = disabledReason == nil,
		disabledReason = disabledReason,
	}
end

function Session:SetActiveAutoAccept(enabled)
	local state = self:GetActiveAutoAcceptControlState()
	if not state or state.canToggle ~= true then
		return false
	end
	return self:UpdateFromActive({ isAutoAccept = enabled == true })
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

function Session:ConsumeConfirmedUserRemoval()
	return clearPendingUserRemoveReset(self)
end

function Session:Remove()
	local bumpBusy = type(self.IsBusy) == "function" and self:IsBusy()
	if bumpBusy or self:HasActive() ~= true or self:CanPublish() ~= true then
		return false
	end
	markPendingUserRemoveReset(self)
	if GF.InvitationScheduler and GF.InvitationScheduler.ClearSession then
		GF.InvitationScheduler:ClearSession()
	end
	C_LFGList.RemoveListing()
	return true
end

function Session:BuildSubmissionFromActive(overrides)
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

function Session:BuildSubmissionFromDraft(params)
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
	listing:BeginOwnedEntryRequest()
	local accepted = C_LFGList.UpdateListing(createData) == true
	if accepted then
		return true
	end
	listing:CancelOwnedEntryRequest()
	listing._activeEntryOwnedByGroupFinder = ownership.current
	listing._lastActiveEntryOwnedByGroupFinder = ownership.last
	return false
end

local function canUpdateListing(listing)
	local bumpBusy = type(listing.IsBusy) == "function"
		and listing:IsBusy()
	return not bumpBusy and listing:CanPublish()
end

function Session:UpdateFromActive(overrides)
	if not canUpdateListing(self) then
		return false
	end
	return updateListingWithOwnership(
		self,
		self:BuildSubmissionFromActive(overrides),
		true)
end

function Session:UpdateFromDraft(params)
	if not canUpdateListing(self) then
		return false
	end
	-- Name/comment come from EntryCreation fields; do not CopyActiveEntryInfoToCreationFields here.
	return updateListingWithOwnership(
		self,
		self:BuildSubmissionFromDraft(params),
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
	if not self._lastBumpAt or self:GetRelistCooldownRemaining() <= 0 or not C_Timer then
		return
	end
	local generation = self._bumpCooldownRefreshGeneration
	local function refreshCooldown()
		if generation ~= self._bumpCooldownRefreshGeneration then
			return
		end
		refreshBumpButtonState()
		if self:GetRelistCooldownRemaining() <= 0 then
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
				and self:GetRelistCooldownRemaining() > 0 then
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
		if GF.InvitationScheduler and GF.InvitationScheduler.ClearSession then
			GF.InvitationScheduler:ClearSession()
		end
	else
		self:CancelOwnedEntryRequest()
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

function Session:IsRelisting()
	return self._bumpRelistState ~= nil
end

function Session:IsBusy()
	return self:IsRelisting()
		or self._pendingGroupFinderActiveEntry == true
		or (self._bumpBusyUntil and GetTime() < self._bumpBusyUntil)
end

function Session:GetRelistCooldownRemaining()
	if not self._lastBumpAt then
		return 0
	end
	return math.max(0, BUMP_COOLDOWN_SEC - (GetTime() - self._lastBumpAt))
end

function Session:IsRelistOnCooldown()
	return self:GetRelistCooldownRemaining() > 0
end

function Session:GetLastRelistFailure()
	return self._lastBumpRelistFailureStage,
		self._lastBumpRelistFenceRestoreFailed == true
end

function Session:SetRelistFieldBridge(bridge)
	self._bumpFieldBridge = bridge
end

function Session:HandleRelistEntryChanged(hasActive, createdNew)
	if self:IsRelisting() ~= true then
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

function Session:Relist()
	local blocked = self:CanPublish() ~= true
		or self:HasActive() ~= true
		or self:IsRelistOnCooldown()
		or self._pendingUserRemoveReset ~= nil
		or self:IsBusy()
		or self._bumpRelistTimer ~= nil
	if blocked then
		return false
	end
	local createData = self:BuildSubmissionFromActive()
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
	if GF.InvitationScheduler and GF.InvitationScheduler.ClearSession then
		GF.InvitationScheduler:ClearSession()
	end
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
	self:BeginOwnedEntryRequest()
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

function Session:Create(params)
	if type(params) ~= "table" or params.activityID == nil then
		return false
	end
	local busy = type(self.IsBusy) == "function" and self:IsBusy()
	if busy or self:HasActive() == true or self:CanPublish() ~= true then
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
	self:BeginOwnedEntryRequest()
	local callOK, accepted = pcall(C_LFGList.CreateListing, createData)
	accepted = callOK and accepted == true
	local confirmedDuringCall = self._pendingGroupFinderActiveEntry ~= true
		and self._activeEntryOwnedByGroupFinder == true
		and self:HasActive() == true
	if accepted or confirmedDuringCall then
		return true
	end
	self:CancelOwnedEntryRequest()
	self._activeEntryOwnedByGroupFinder = ownership.current
	self._lastActiveEntryOwnedByGroupFinder = ownership.last
	return false
end

function Session:HandleCreationFailed()
	local bumpState = self._bumpRelistState
	local duringBump = bumpState == "creating"
		or bumpState == "awaiting_confirmation"
	if not duringBump then
		-- The failure event is synchronous, so release the ownership request here
		-- instead of depending on a later UI refresh to observe an inactive entry.
		self:CancelOwnedEntryRequest()
		local locale = GF.L or {}
		notifyUiError(locale.CREATE_FAILED or "Listing failed. Please try again.")
		return nil
	end
	local generation = self._bumpRelistGeneration
	self._bumpRelistCreationFailed = generation
	self._bumpRelistStage = "creation_failed_event"
	self:CancelOwnedEntryRequest()
	finishBumpRelist(self, generation, false, { skipUiRefresh = true })
	return "failed"
end

function Session:GetActiveActivityTitle()
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

function Session:HasCrossFactionSettingChanged(newIsCrossFaction)
	local entry = self:GetActive()
	if type(entry) ~= "table" then
		return false
	end
	local currentValue = isCrossFactionEntry(entry)
	local requestedValue = newIsCrossFaction == true
	return currentValue ~= requestedValue
end
