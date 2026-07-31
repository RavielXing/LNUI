local _, GF = ...

GF.Listing = {}

local function activeCrossFaction(info)
	if not info then
		return false
	end
	if info.isCrossFactionListing ~= nil then
		return info.isCrossFactionListing
	end
	return info.isCrossFaction == true
end

function GF.Listing:CanManageEntry()
	if not self:HasActive() then
		return false
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if LFGListUtil_IsEntryEmpowered and LFGListUtil_IsEntryEmpowered() then
		return true
	end
	-- Solo list owner: not in a home party but has an active listing.
	if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
		return true
	end
	return UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME)
		or UnitIsGroupAssistant("player", LE_PARTY_CATEGORY_HOME)
end

local function notifyUiError(msg)
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(msg)
	end
end

local MAX_APPLICANT_API_ID = 4294967295
local AUTO_INVITE_GUARD_OPTS = { useInviteCap = true }

local function isApplicantTestID(applicantID)
	return GF.ApplicantTestData
		and GF.ApplicantTestData.IsTestApplicantID
		and GF.ApplicantTestData:IsTestApplicantID(applicantID)
end

local function normalizeApplicantAPIID(applicantID)
	applicantID = tonumber(applicantID)
	if not applicantID or applicantID < 0 or applicantID > MAX_APPLICANT_API_ID then
		return nil
	end
	return applicantID
end

local function blizzardMsg(msg)
	if type(msg) == "string" and msg ~= "" then
		return msg
	end
	return nil
end

local function applicantActionMessage(reason)
	if reason == "unempowered" then
		return (GF.L and GF.L.ERR_MANAGE_ENTRY_ONLY) or nil
	elseif reason == "full" then
		return blizzardMsg(LFG_LIST_GROUP_TOO_FULL)
	elseif reason == "pending_invite" then
		return blizzardMsg(LFG_LIST_INVITED_APP_FILLS_GROUP)
	elseif reason == "raid_conversion_in_combat" then
		return (GF.L and GF.L.ERR_RAID_CONVERSION_IN_COMBAT) or "Cannot convert to raid while in combat. Try again after combat."
	elseif reason == "loading" or reason == "no_api" or reason == "missing" then
		return nil
	end
	if GF.Listing and GF.Listing.GetApplicantStatusMessage then
		return GF.Listing:GetApplicantStatusMessage(reason)
	end
	return nil
end

function GF.Listing:GetApplicantStatusMessage(status)
	if not status then
		return nil
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if status == "invited" then
		return blizzardMsg(LFG_LIST_APP_INVITED)
	elseif status == "failed" or status == "cancelled" then
		return blizzardMsg(LFG_LIST_APP_CANCELLED)
	elseif status == "declined" or status == "declined_full" or status == "declined_delisted" then
		return blizzardMsg(LFG_LIST_APP_DECLINED)
	elseif status == "timedout" then
		return blizzardMsg(LFG_LIST_APP_TIMED_OUT)
	elseif status == "inviteaccepted" then
		return blizzardMsg(LFG_LIST_APP_INVITE_ACCEPTED)
	elseif status == "invitedeclined" then
		return blizzardMsg(LFG_LIST_APP_INVITE_DECLINED)
	end
	return nil
end

function GF.Listing:GetApplicantActionMessage(reason)
	return applicantActionMessage(reason)
end

function GF.Listing:NotifyApplicantActionBlocked(reason)
	notifyUiError(applicantActionMessage(reason))
end

local function applicantInviteRequiresRaidConversion(numMembers, numInvited)
	if IsInRaid(LE_PARTY_CATEGORY_HOME) then
		return false
	end
	numMembers = tonumber(numMembers) or 1
	numInvited = tonumber(numInvited) or 0
	return GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) + numMembers + numInvited > MAX_PARTY_MEMBERS + 1
end

function GF.Listing:GetApplicantInviteBlockReason(applicantID, opts)
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
	local info = C_LFGList.GetApplicantInfo(applicantID)
	if not info then
		return "missing"
	end
	if info.applicantInfo then
		return "loading"
	end
	if info.applicationStatus ~= "applied" then
		return info.applicationStatus
	end
	local numMembers = info.numMembers or 1
	local db = GF.GetDB and GF.GetDB()
	local useUserCap = opts and opts.useInviteCap == true and db and db.inviteCapEnabled == true
	local numAllowed = useUserCap and self:GetEffectiveInviteCap() or self:GetInviteMemberCapacity()
	local numInvited = C_LFGList.GetNumInvitedApplicantMembers() or 0
	local currentCount = self:GetHomeGroupHeadcount()

	if numMembers + currentCount > numAllowed then
		return "full"
	end
	if numMembers + currentCount + numInvited > numAllowed then
		return useUserCap and "full" or "pending_invite"
	end
	if applicantInviteRequiresRaidConversion(numMembers, numInvited)
		and InCombatLockdown and InCombatLockdown() then
		return "raid_conversion_in_combat"
	end
	return nil
end

function GF.Listing:GetHomeGroupHeadcount()
	-- Blizzard LFG invite-cap checks use GetNumGroupMembers directly; party counts
	-- already include the player on Retail.
	local n = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
	n = tonumber(n) or 0
	return math.max(n, 1)
end

function GF.Listing:OnGroupRosterChanged()
	local now = self:GetHomeGroupHeadcount()
	local prev = self._autoInviteLastHeadcount
	self._autoInviteLastHeadcount = now
	if prev == nil or now == prev then
		return
	end
	if self:IsAutoInviteEnabled() and self:HasActive() then
		self:QueueAutoInvite()
	end
end

function GF.Listing:CanDeclineApplicant(applicantID)
	if not self:CanManageEntry() or not applicantID then
		return false
	end
	if isApplicantTestID(applicantID) then
		return false
	end
	applicantID = normalizeApplicantAPIID(applicantID)
	if not applicantID then
		return false
	end
	local info = C_LFGList.GetApplicantInfo(applicantID)
	if not info or info.applicantInfo then
		return false
	end
	return info.applicationStatus ~= "invited"
end

-- List / edit / remove / bump: party leader only (Blizzard LFGListUtil_CanListGroup / ApplicationViewer).
function GF.Listing:CanLeadListing()
	if LFGListUtil_CanListGroup then
		return LFGListUtil_CanListGroup()
	end
	return not IsInGroup(LE_PARTY_CATEGORY_HOME)
		or UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME)
end

function GF.Listing:GetLeaderOnlyMessage()
	return (GF.L and GF.L.ERR_LEADER_ONLY) or "You are not authorized."
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
	if hasActive then
		if self._pendingGroupFinderActiveEntry then
			self._activeEntryOwnedByGroupFinder = true
			self._pendingGroupFinderActiveEntry = nil
		elseif self._activeEntryOwnedByGroupFinder == nil then
			self._activeEntryOwnedByGroupFinder = false
		end
		return
	end
	if self._activeEntryOwnedByGroupFinder ~= nil then
		self._lastActiveEntryOwnedByGroupFinder = self._activeEntryOwnedByGroupFinder
	end
	self._activeEntryOwnedByGroupFinder = nil
	self._pendingGroupFinderActiveEntry = nil
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
	return C_LFGList.HasActiveEntryInfo()
end

function GF.Listing:GetActive()
	if not self:HasActive() then
		return nil
	end
	return C_LFGList.GetActiveEntryInfo()
end

function GF.Listing:GetActiveActivityID()
	local info = self:GetActive()
	if not info then
		return nil
	end
	if info.activityIDs and info.activityIDs[1] then
		return info.activityIDs[1]
	end
	return info.activityID
end

function GF.Listing:GetActiveEntryName()
	local info = self:GetActive()
	if not info then
		return ""
	end
	return info.name
end

local USER_REMOVE_RESET_TIMEOUT_SEC = 8

local function clearPendingUserRemoveReset(self, generation)
	if generation ~= nil and self._pendingUserRemoveReset ~= generation then
		return
	end
	if self._userRemoveResetTimer and self._userRemoveResetTimer.Cancel then
		self._userRemoveResetTimer:Cancel()
	end
	self._userRemoveResetTimer = nil
	self._pendingUserRemoveReset = nil
end

local function markPendingUserRemoveReset(self)
	clearPendingUserRemoveReset(self)
	self._userRemoveResetGeneration = (self._userRemoveResetGeneration or 0) + 1
	local generation = self._userRemoveResetGeneration
	self._pendingUserRemoveReset = generation
	local function expire()
		clearPendingUserRemoveReset(self, generation)
	end
	if C_Timer and C_Timer.NewTimer then
		self._userRemoveResetTimer = C_Timer.NewTimer(USER_REMOVE_RESET_TIMEOUT_SEC, expire)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(USER_REMOVE_RESET_TIMEOUT_SEC, expire)
	end
end

function GF.Listing:ConsumePendingUserRemoveReset()
	if self._pendingUserRemoveReset == nil then
		return false
	end
	clearPendingUserRemoveReset(self)
	return true
end

function GF.Listing:Remove()
	if self.IsBumpBusy and self:IsBumpBusy() then
		return false
	end
	markPendingUserRemoveReset(self)
	self:ClearAutoInviteForSession()
	C_LFGList.RemoveListing()
	return true
end

function GF.Listing:BuildCreateDataFromActive(overrides)
	local info = self:GetActive()
	if not info then
		return nil
	end
	overrides = overrides or {}
	local activityID = info.activityIDs and info.activityIDs[1] or info.activityID
	if not activityID then
		return nil
	end
	return {
		activityIDs = { activityID },
		questID = info.questID,
		isAutoAccept = overrides.isAutoAccept ~= nil and overrides.isAutoAccept or info.autoAccept,
		isCrossFactionListing = activeCrossFaction(info),
		isPrivateGroup = info.privateGroup,
		newPlayerFriendly = info.newPlayerFriendly == true,
		playstyle = info.playstyle or Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = info.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = info.requiredDungeonScore or 0,
		requiredItemLevel = info.requiredItemLevel or 0,
		requiredPvpRating = info.requiredPvpRating or 0,
	}
end

function GF.Listing:BuildCreateDataFromParams(params)
	local active = self:GetActive()
	if not params or not params.activityID then
		return nil
	end
	local newPlayerFriendly = params.newPlayerFriendly == true
	if active then
		newPlayerFriendly = active.newPlayerFriendly == true
	end
	return {
		activityIDs = { params.activityID },
		questID = active and active.questID or params.questID,
		isAutoAccept = active and active.autoAccept or false,
		isCrossFactionListing = params.isCrossFactionListing or false,
		isPrivateGroup = params.isPrivateGroup or false,
		newPlayerFriendly = newPlayerFriendly,
		playstyle = Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = params.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = params.requiredDungeonScore or 0,
		requiredItemLevel = params.requiredItemLevel or 0,
		requiredPvpRating = params.requiredPvpRating or 0,
	}
end

function GF.Listing:UpdateActive(overrides)
	if (self.IsBumpBusy and self:IsBumpBusy())
		or not self:CanLeadListing()
	then
		return false
	end
	local createData = overrides and self:BuildCreateDataFromActive(overrides) or self:BuildCreateDataFromActive()
	if not createData then
		return false
	end
	if C_LFGList.CopyActiveEntryInfoToCreationFields then
		C_LFGList.CopyActiveEntryInfoToCreationFields()
	end
	local previousOwner = self._activeEntryOwnedByGroupFinder
	local previousLastOwner = self._lastActiveEntryOwnedByGroupFinder
	self:MarkNextActiveEntryAsGroupFinder()
	local ok = C_LFGList.UpdateListing(createData)
	if not ok then
		self:ClearPendingActiveEntryOwnership()
		self._activeEntryOwnedByGroupFinder = previousOwner
		self._lastActiveEntryOwnedByGroupFinder = previousLastOwner
	end
	return ok
end

function GF.Listing:UpdateFromParams(params)
	if (self.IsBumpBusy and self:IsBumpBusy())
		or not self:CanLeadListing()
	then
		return false
	end
	local createData = self:BuildCreateDataFromParams(params)
	if not createData then
		return false
	end
	-- Name/comment come from EntryCreation fields; do not CopyActiveEntryInfoToCreationFields here.
	local previousOwner = self._activeEntryOwnedByGroupFinder
	local previousLastOwner = self._lastActiveEntryOwnedByGroupFinder
	self:MarkNextActiveEntryAsGroupFinder()
	local ok = C_LFGList.UpdateListing(createData)
	if not ok then
		self:ClearPendingActiveEntryOwnership()
		self._activeEntryOwnedByGroupFinder = previousOwner
		self._lastActiveEntryOwnedByGroupFinder = previousLastOwner
	end
	return ok
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
	if not self:IsBumpRelisting() then
		return nil
	end
	local state = self._bumpRelistState
	if state ~= "creating" and state ~= "awaiting_confirmation" then
		return "pending"
	end
	local generation = self._bumpRelistGeneration
	if self._bumpRelistCreationFailed == generation then
		finishBumpRelist(self, generation, false, { skipUiRefresh = true })
		return "failed"
	end
	if hasActive == true and createdNew == true then
		finishBumpRelist(self, generation, true, { skipUiRefresh = true })
		return "success"
	end
	return "pending"
end

function GF.Listing:RefreshApplicants()
	if not self:CanManageEntry() or not C_LFGList.RefreshApplicants then
		return false
	end
	C_LFGList.RefreshApplicants()
	return true
end

function GF.Listing:RelistForBump()
	if not self:CanLeadListing() or not self:HasActive() or self:IsBumpOnCooldown() then
		return false
	end
	if self._pendingUserRemoveReset ~= nil then
		return false
	end
	if self:IsBumpBusy() or self._bumpRelistTimer then
		return false
	end
	local createData = self:BuildCreateDataFromActive()
	if not createData then
		return false
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	local bridge = self._bumpFieldBridge
	if not (bridge and bridge.Acquire and bridge.ResumeAfterRemove and bridge.Release) then
		notifyBumpFailure(self, "bridge_unavailable")
		return false
	end
	if not C_LFGList.CopyActiveEntryInfoToCreationFields then
		notifyBumpFailure(self, "copy_active_fields_unavailable")
		return false
	end
	local copied = pcall(C_LFGList.CopyActiveEntryInfoToCreationFields)
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
	if (self.IsBumpBusy and self:IsBumpBusy())
		or not self:CanLeadListing()
	then
		return false
	end
	if not params or not params.activityID then
		return false
	end
	local createData = {
		activityIDs = { params.activityID },
		questID = params.questID,
		isAutoAccept = params.isAutoAccept or false,
		isCrossFactionListing = params.isCrossFactionListing or false,
		isPrivateGroup = params.isPrivateGroup or false,
		newPlayerFriendly = params.newPlayerFriendly == true,
		playstyle = Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = params.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = params.requiredDungeonScore or 0,
		requiredItemLevel = params.requiredItemLevel or 0,
		requiredPvpRating = params.requiredPvpRating or 0,
	}
	local previousOwner = self._activeEntryOwnedByGroupFinder
	local previousLastOwner = self._lastActiveEntryOwnedByGroupFinder
	self:MarkNextActiveEntryAsGroupFinder()
	local ok = C_LFGList.CreateListing(createData)
	if not ok then
		self:ClearPendingActiveEntryOwnership()
		self._activeEntryOwnedByGroupFinder = previousOwner
		self._lastActiveEntryOwnedByGroupFinder = previousLastOwner
	end
	return ok
end

function GF.Listing:OnCreationFailed()
	local bumpState = self._bumpRelistState
	if bumpState == "creating" or bumpState == "awaiting_confirmation" then
		local generation = self._bumpRelistGeneration
		self._bumpRelistCreationFailed = generation
		self._bumpRelistStage = "creation_failed_event"
		self:ClearPendingActiveEntryOwnership()
		finishBumpRelist(self, generation, false, { skipUiRefresh = true })
		return "failed"
	end
	local L = GF.L or {}
	notifyUiError(L.CREATE_FAILED or "Listing failed. Please try again.")
end

function GF.Listing:GetApplicantIDs()
	return C_LFGList.GetApplicants() or {}
end

function GF.Listing:GetApplicantCount()
	if not C_LFGList.GetNumApplicants then
		return 0
	end
	local _, numActive = C_LFGList.GetNumApplicants()
	return numActive or 0
end

local function collectAppliedApplicantIDs()
	local set = {}
	if not C_LFGList.GetApplicants then
		return set
	end
	local ids = C_LFGList.GetApplicants() or {}
	for _, applicantID in ipairs(ids) do
		local include = true
		if C_LFGList.GetApplicantInfo then
			local info = C_LFGList.GetApplicantInfo(applicantID)
			if info and info.applicationStatus and info.applicationStatus ~= "applied" then
				include = false
			end
		end
		if include then
			set[tostring(applicantID)] = true
		end
	end
	return set
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

function GF.Listing:InviteApplicant(applicantID, opts)
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if isApplicantTestID(applicantID) then
		return false, "test_data"
	end
	applicantID = normalizeApplicantAPIID(applicantID)
	if not applicantID then
		return false, "missing"
	end
	local blockReason = self:GetApplicantInviteBlockReason(applicantID, opts)
	if blockReason then
		return false, blockReason
	end
	if not C_LFGList.InviteApplicant then
		return false, "no_api"
	end
	local info = C_LFGList.GetApplicantInfo(applicantID)
	local numMembers = info and info.numMembers or 1
	if applicantInviteRequiresRaidConversion(numMembers, C_LFGList.GetNumInvitedApplicantMembers() or 0) then
		if InCombatLockdown and InCombatLockdown() then
			return false, "raid_conversion_in_combat"
		end
		if StaticPopup_Show then
			StaticPopup_Show("LFG_LIST_INVITING_CONVERT_TO_RAID", nil, nil, applicantID)
			return true, "raid_conversion_popup"
		end
	end
	if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON and PlaySound then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
	C_LFGList.InviteApplicant(applicantID)
	return true
end

function GF.Listing:Accept(applicantID)
	local ok, reason = self:InviteApplicant(applicantID)
	if not ok then
		self:NotifyApplicantActionBlocked(reason)
	end
	return ok
end

function GF.Listing:Decline(applicantID)
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if isApplicantTestID(applicantID) then
		return false
	end
	if not self:CanManageEntry() then
		self:NotifyApplicantActionBlocked("unempowered")
		return false
	end
	if not applicantID or not C_LFGList.DeclineApplicant then
		return false
	end
	applicantID = normalizeApplicantAPIID(applicantID)
	if not applicantID then
		return false
	end
	local info = C_LFGList.GetApplicantInfo(applicantID)
	if not info or info.applicantInfo then
		return false
	end
	if info.applicationStatus == "invited" then
		return false
	end
	if info.applicationStatus ~= "applied" and info.applicationStatus ~= "invited" then
		C_LFGList.RemoveApplicant(applicantID)
	else
		if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON and PlaySound then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
		C_LFGList.DeclineApplicant(applicantID)
	end
	return true
end

local AUTO_INVITE_COOLDOWN_SEC = 1
local AUTO_INVITE_CAP_COOLDOWN_SEC = 3

local function getAutoInviteDelaySec()
	if GF.GetDB and GF.GetDB().inviteCapEnabled then
		return AUTO_INVITE_CAP_COOLDOWN_SEC
	end
	return AUTO_INVITE_COOLDOWN_SEC
end

local function cancelAutoInviteChain(listing)
	if listing._autoInviteChainTimer then
		listing._autoInviteChainTimer:Cancel()
		listing._autoInviteChainTimer = nil
	end
end

local function activeEntryAutoInviteSig()
	if not C_LFGList.HasActiveEntryInfo() then
		return nil
	end
	local info = C_LFGList.GetActiveEntryInfo()
	if not info then
		return nil
	end
	local activityID = info.activityIDs and info.activityIDs[1] or info.activityID or 0
	return string.format("%s:%s:%s", tostring(activityID), tostring(info.questID or 0), info.privateGroup and "1" or "0")
end

function GF.Listing:RestoreAutoInviteSession()
	if not self:HasActive() then
		self._autoInviteEnabled = false
		self._autoInviteCursorID = nil
		return
	end
	local db = GF.GetDB()
	if not db.autoInviteEnabled then
		self._autoInviteEnabled = false
		self._autoInviteCursorID = nil
		return
	end
	local sig = activeEntryAutoInviteSig()
	if sig and db.autoInviteEntrySig == sig then
		self._autoInviteEnabled = true
	else
		db.autoInviteEnabled = false
		db.autoInviteEntrySig = nil
		self._autoInviteEnabled = false
		self._autoInviteCursorID = nil
	end
end

function GF.Listing:IsAutoInviteEnabled()
	if self._autoInviteEnabled == nil then
		self:RestoreAutoInviteSession()
	end
	return self._autoInviteEnabled == true
end

function GF.Listing:SetAutoInviteEnabled(enabled)
	if not self:HasActive() then
		return
	end
	local db = GF.GetDB()
	if enabled then
		self._autoInviteEnabled = true
		db.autoInviteEnabled = true
		db.autoInviteEntrySig = activeEntryAutoInviteSig()
		self._autoInviteCursorID = nil
	else
		self._autoInviteEnabled = false
		self._autoInviteCooldownUntil = nil
		self._autoInviteInFlight = nil
		self._autoInviteLastHeadcount = nil
		self._autoInviteCursorID = nil
		cancelAutoInviteChain(self)
		db.autoInviteEnabled = false
		db.autoInviteEntrySig = nil
	end
end

function GF.Listing:StopAutoInviteIfCapReached()
	local db = GF.GetDB and GF.GetDB()
	if not (db and db.inviteCapEnabled == true) then
		return false
	end
	local occupied = self:GetHomeGroupHeadcount() + (C_LFGList.GetNumInvitedApplicantMembers() or 0)
	if occupied < self:GetEffectiveInviteCap() then
		return false
	end
	self:SetAutoInviteEnabled(false)
	refreshApplicantManageState()
	return true
end

function GF.Listing:ClearAutoInviteForSession()
	self._autoInviteEnabled = false
	self._autoInviteCooldownUntil = nil
	self._autoInviteInFlight = nil
	self._autoInviteLastHeadcount = nil
	self._autoInviteCursorID = nil
	cancelAutoInviteChain(self)
	local db = GF.GetDB()
	db.autoInviteEnabled = false
	db.autoInviteEntrySig = nil
end

function GF.Listing:QueueAutoInvite()
	if not self:IsAutoInviteEnabled() then
		return
	end
	if self._autoInviteQueued then
		return
	end
	self._autoInviteQueued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			self._autoInviteQueued = nil
			self:TryAutoInviteOne()
		end)
	else
		self._autoInviteQueued = nil
		self:TryAutoInviteOne()
	end
end

local function scheduleAutoInviteChain(listing)
	cancelAutoInviteChain(listing)
	if not C_Timer or not C_Timer.NewTimer then
		return
	end
	listing._autoInviteChainTimer = C_Timer.NewTimer(getAutoInviteDelaySec(), function()
		listing._autoInviteChainTimer = nil
		if listing.TryAutoInviteOne then
			listing:TryAutoInviteOne()
		end
	end)
end

function GF.Listing:CanToggleAutoInvite()
	if not UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) then
		return false
	end
	return self:HasActive()
end

function GF.Listing:GetInviteMemberCapacity()
	local activityID = self:GetActiveActivityID()
	if not activityID then
		return MAX_RAID_MEMBERS
	end
	local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
	local numAllowed = activityInfo and activityInfo.maxNumPlayers or 0
	if numAllowed == 0 then
		return MAX_RAID_MEMBERS
	end
	return numAllowed
end

function GF.Listing:GetEffectiveInviteCap()
	local activityCap = self:GetInviteMemberCapacity()
	local db = GF.GetDB()
	if db.inviteCapEnabled then
		local cap = math.floor(tonumber(db.inviteCap) or (GF.INVITE_CAP_DEFAULT or 40))
		local minCap = GF.INVITE_CAP_MIN or 1
		local maxCap = GF.INVITE_CAP_MAX or 40
		cap = math.max(minCap, math.min(maxCap, cap))
		if cap < activityCap then
			return cap
		end
	end
	return activityCap
end

function GF.Listing:CanInviteApplicant(applicantID, opts)
	return self:GetApplicantInviteBlockReason(applicantID, opts) == nil
end

function GF.Listing:GetNextAutoInviteApplicant(ids)
	ids = ids or {}
	local count = #ids
	if count == 0 then
		self._autoInviteCursorID = nil
		return nil
	end
	local start = 1
	if self._autoInviteCursorID then
		for i = 1, count do
			if ids[i] == self._autoInviteCursorID then
				start = i + 1
				if start > count then
					start = 1
				end
				break
			end
		end
	end
	local lastChecked
	for offset = 0, count - 1 do
		local idx = ((start + offset - 2) % count) + 1
		local applicantID = ids[idx]
		lastChecked = applicantID
		if self:CanInviteApplicant(applicantID, AUTO_INVITE_GUARD_OPTS) then
			self._autoInviteCursorID = applicantID
			return applicantID
		end
	end
	self._autoInviteCursorID = lastChecked
	return nil
end

function GF.Listing:TryAutoInviteOne()
	if self._autoInviteInFlight then
		return
	end
	if not self:IsAutoInviteEnabled() or not self:CanToggleAutoInvite() then
		return
	end
	if self._autoInviteCooldownUntil and GetTime() < self._autoInviteCooldownUntil then
		return
	end
	if not C_LFGList.InviteApplicant then
		return
	end
	if self:StopAutoInviteIfCapReached() then
		return
	end
	local ids
	if GF.ApplicantModel and GF.ApplicantModel.GetSortedApplicantIDs then
		ids = GF.ApplicantModel:GetSortedApplicantIDs()
	else
		ids = C_LFGList.GetApplicants() or {}
	end
	local applicantID = self:GetNextAutoInviteApplicant(ids)
	if applicantID then
		self._autoInviteCooldownUntil = GetTime() + getAutoInviteDelaySec()
		self._autoInviteInFlight = true
		local ok, result = self:InviteApplicant(applicantID, AUTO_INVITE_GUARD_OPTS)
		self._autoInviteInFlight = nil
		if ok then
			if result ~= "raid_conversion_popup" then
				scheduleAutoInviteChain(self)
			end
			return
		end
		self._autoInviteCooldownUntil = nil
	end
end

function GF.Listing:GetActiveActivityTitle()
	local activityID = self:GetActiveActivityID()
	if not activityID then
		return ""
	end
	local info = C_LFGList.GetActivityInfoTable(activityID)
	if not info then
		return ""
	end
	local categoryID = info.categoryID
	if GF.NavData and GF.NavData.FindNodeByActivityID then
		local node = GF.NavData.FindNodeByActivityID(activityID)
		if node and node.categoryID then
			categoryID = node.categoryID
		end
	end
	if GF.UI and GF.UI.GetCategoryTitle then
		return GF.UI.GetCategoryTitle(categoryID, info)
	end
	return info.fullName or info.shortName or ""
end

function GF.Listing:CrossFactionChanged(newIsCrossFaction)
	local info = self:GetActive()
	if not info then
		return false
	end
	return activeCrossFaction(info) ~= (newIsCrossFaction == true)
end
