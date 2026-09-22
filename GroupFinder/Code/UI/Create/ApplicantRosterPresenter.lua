local _, GF = ...

-- ApplicantRosterPresenter is the sole owner of the applicant roster projection.
-- It translates safe Core snapshots and action outcomes into a stable view model;
-- ApplicantsPanel, ApplicantCard, and ApplicantMemberBlock remain rendering ports.
local Presenter = {}
GF.ApplicantRosterPresenter = Presenter

local presenterHasActiveListing
local presenterHasAuthoritativeListing

local TERMINAL_MIN_VISIBLE_SECONDS = GF.APPLICANT_DECLINED_MIN_VISIBLE_SECONDS or 0.8
local TERMINAL_FADE_SECONDS = GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS or 0.16
local TERMINAL_TIMER_EPSILON_SECONDS = 0.001
local ACTION_PENDING_TIMEOUT_SECONDS = GF.APPLICANT_ACTION_PENDING_TIMEOUT_SECONDS or 3
local DECLINE_PENDING_TIMEOUT_SECONDS =
	GF.APPLICANT_DECLINE_PENDING_TIMEOUT_SECONDS or 1.5
local PROVIDER_MISSING_GRACE_SECONDS = ACTION_PENDING_TIMEOUT_SECONDS
local LISTING_LOSS_INVITE_GRACE_SECONDS =
	GF.APPLICANT_LISTING_LOSS_INVITE_GRACE_SECONDS or 1
local ROSTER_RESOLUTION_SECONDS = LISTING_LOSS_INVITE_GRACE_SECONDS

local DECLINED_STATUSES = {
	declined = true,
	declined_delisted = true,
	declined_full = true,
}

local AUTO_DISMISS_TERMINAL_STATUSES = {
	cancelled = true,
	failed = true,
	inviteaccepted = true,
	invitedeclined = true,
	timedout = true,
}

local function applicantRowKey(applicantID, memberIdx)
	return tostring(applicantID or "") .. ":" .. tostring(memberIdx or 1)
end

local function selectedApplicantIDFromKey(key)
	return key and key:match("^([^:]+):") or nil
end

local function applicantIDInList(applicantIDs, applicantID)
	local target = tostring(applicantID or "")
	if target == "" then
		return false
	end
	for _, id in ipairs(applicantIDs or {}) do
		if tostring(id) == target then
			return true
		end
	end
	return false
end

local function applicantIDKey(applicantID)
	return tostring(applicantID or "")
end

local function applicantIDSet(applicantIDs)
	local set = {}
	for _, applicantID in ipairs(applicantIDs or {}) do
		set[applicantIDKey(applicantID)] = true
	end
	return set
end

local function applicantIDIndex(applicantIDs, applicantID)
	local target = applicantIDKey(applicantID)
	for index, id in ipairs(applicantIDs or {}) do
		if applicantIDKey(id) == target then
			return index
		end
	end
	return nil
end

local function applicantMemberCount(data)
	return math.max(1, tonumber(data and data.numMembers) or 1)
end

local function now()
	return type(GetTime) == "function" and GetTime() or 0
end

local function cancelTimer(timer)
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
end

local function scheduleTimer(delay, callback)
	delay = math.max(0, tonumber(delay) or 0)
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		return C_Timer.NewTimer(delay, callback)
	end
	if C_Timer and type(C_Timer.After) == "function" then
		local handle = { cancelled = false }
		function handle:Cancel()
			self.cancelled = true
		end
		C_Timer.After(delay, function()
			if not handle.cancelled then
				callback()
			end
		end)
		return handle
	end
	callback()
	return nil
end

local function buildApplicantSafely(applicantID)
	local model = GF.ApplicantSnapshotBuilder
	if not model then
		return nil
	end
	if type(model.BuildApplicantSafely) == "function" then
		return model:BuildApplicantSafely(applicantID)
	end
	if type(model.BuildApplicant) ~= "function" then
		return nil
	end
	local ok, data = pcall(model.BuildApplicant, model, applicantID)
	if not ok or type(data) ~= "table" then
		return nil
	end
	return data
end

local cloneApplicantData

local function isDeclinedApplicantData(data)
	return type(data) == "table" and DECLINED_STATUSES[data.status] == true
end

local function isTerminalRemovalApplicantData(data)
	local appInfo = type(data) == "table" and data.appInfo or nil
	return type(data) == "table"
		and not (type(appInfo) == "table" and appInfo.applicantInfo)
		and (DECLINED_STATUSES[data.status] == true
			or AUTO_DISMISS_TERMINAL_STATUSES[data.status] == true)
end

local function isTestApplicantID(applicantID)
	return GF.ApplicantTestData
		and type(GF.ApplicantTestData.IsTestApplicantID) == "function"
		and GF.ApplicantTestData:IsTestApplicantID(applicantID) == true
end

local function hasEnabledApplicantTestData()
	return GF.ApplicantTestData
		and type(GF.ApplicantTestData.IsEnabled) == "function"
		and GF.ApplicantTestData:IsEnabled() == true
end

local function isFixtureApplicantID(applicantID, cachedData)
	local testData = GF.ApplicantTestData
	if testData and type(testData.IsFixtureApplicantID) == "function"
		and testData:IsFixtureApplicantID(applicantID) == true
	then
		return true
	end
	return type(cachedData) == "table"
		and (cachedData.isTest == true or cachedData.isDebugTest == true)
end

local function hasNativePendingStatus(data)
	local appInfo = type(data) == "table" and data.appInfo or nil
	return type(appInfo) == "table"
		and appInfo.pendingApplicationStatus ~= nil
end

local function hasNativeApplicantInfo(data)
	local appInfo = type(data) == "table" and data.appInfo or nil
	return type(appInfo) == "table" and not not appInfo.applicantInfo
end

local function applicantActionHasResolved(data)
	return type(data) == "table"
		and data.status ~= nil
		and data.status ~= "applied"
		and not hasNativePendingStatus(data)
end

local function hasRetainedTerminalStatus(data)
	return type(data) == "table"
		and data.status ~= nil
		and data.status ~= "applied"
		and data.status ~= "unavailable"
end

local function hasApplicantTransientState(panel)
	local hasRosterFeedback = false
	for _, candidate in pairs(panel._applicantRosterCandidates or {}) do
		if candidate.phase == "pending" or candidate.phase == "invited" then
			hasRosterFeedback = true
			break
		end
	end
	local hasNativePending = false
	for _, data in pairs(panel.applicantDataCache or {}) do
		if type(data) == "table" and data._gfNativeAvailable == true
			and hasNativePendingStatus(data)
		then
			hasNativePending = true
			break
		end
	end
	return next(panel._pendingApplicantActions or {}) ~= nil
		or next(panel._applicantActionIntents or {}) ~= nil
		or next(panel._providerMissingApplicantCleanups or {}) ~= nil
		or next(panel._terminalApplicantLifecycles or {}) ~= nil
		or next(panel._retainedInvitedApplicants or {}) ~= nil
		or hasNativePending
		or hasRosterFeedback
end

local function lacksApplicantManagementAccess()
	local listing = GF.RecruitmentSession
	return not (listing and type(listing.CanManageApplicants) == "function"
		and listing:CanManageApplicants() == true)
end

local function markApplicantDataUnavailable(data)
	if not data then
		return nil
	end
	data._gfNativeAvailable = false
	if hasRetainedTerminalStatus(data) then
		-- Blizzard can remove an applicant ID from GetApplicants()/GetApplicantInfo()
		-- immediately after confirming a terminal action.  Preserve that confirmed
		-- projection; a missing native record is not a newer "unavailable" result.
		data._gfSoftUnavailable = nil
		data.loading = false
		data.isNew = false
		data.showInvite = false
		data.showDecline = false
		data.canInvite = false
		data.canDecline = false
		return data
	end
	local L = GF.L or {}
	data._gfSoftUnavailable = true
	data.loading = false
	data.isNew = false
	data.grayed = true
	data.showInvite = false
	data.showDecline = false
	data.canInvite = false
	data.canDecline = false
	data.status = "unavailable"
	data.statusText = L.APPLICANT_STATUS_UNAVAILABLE or "已失效"
	data.statusColor = { r = 0.5, g = 0.5, b = 0.5 }
	for _, memberData in ipairs(data.members or {}) do
		memberData.grayed = true
	end
	return data
end

local function markApplicantDataDeclined(data)
	if not data then
		return nil
	end
	data._gfSoftUnavailable = nil
	data.loading = false
	data.isNew = false
	data.grayed = true
	data.showInvite = false
	data.showDecline = false
	data.canInvite = false
	data.canDecline = false
	data.status = DECLINED_STATUSES[data.status] and data.status or "declined"
	data.statusText = GF.ApplicantActionService and GF.ApplicantActionService.GetStatusText
		and GF.ApplicantActionService:GetStatusText(data.status)
		or LFG_LIST_APP_DECLINED
		or "已拒绝"
	data.statusColor = { r = 0.5, g = 0.5, b = 0.5 }
	for _, memberData in ipairs(data.members or {}) do
		memberData.grayed = true
	end
	return data
end

local function markApplicantDataJoined(data)
	if not data then
		return nil
	end
	data._gfSoftUnavailable = nil
	data.loading = false
	data.isNew = false
	data.grayed = true
	data.showInvite = false
	data.showDecline = false
	data.canInvite = false
	data.canDecline = false
	data.status = "inviteaccepted"
	data.statusText = (GF.L and GF.L.APPLICANT_STATUS_JOINED)
		or (GF.ApplicantActionService and GF.ApplicantActionService.GetStatusText
			and GF.ApplicantActionService:GetStatusText(data.status))
		or LFG_LIST_APP_INVITE_ACCEPTED
		or "已加入"
	local green = GREEN_FONT_COLOR or { r = 0, g = 1, b = 0 }
	data.statusColor = { r = green.r, g = green.g, b = green.b }
	for _, memberData in ipairs(data.members or {}) do
		memberData.grayed = true
	end
	return data
end

local function markApplicantDataClosed(data)
	if not data then
		return nil
	end
	data._gfSoftUnavailable = nil
	data.loading = false
	data.isNew = false
	data.grayed = true
	data.showInvite = false
	data.showDecline = false
	data.canInvite = false
	data.canDecline = false
	data.statusText = (GF.ApplicantActionService and GF.ApplicantActionService.GetStatusText
		and GF.ApplicantActionService:GetStatusText(data.status))
		or data.statusText
		or ((GF.L and GF.L.APPLICANT_STATUS_UNAVAILABLE) or "已失效")
	data.statusColor = { r = 0.5, g = 0.5, b = 0.5 }
	for _, memberData in ipairs(data.members or {}) do
		memberData.grayed = true
	end
	return data
end

function Presenter:ResetApplicantRemovalFades(applicantID)
	if not self.scrollList then
		return
	end
	local target = applicantID and applicantIDKey(applicantID) or nil
	self:ForEachVisibleRow(function(card)
		if card and (not target or applicantIDKey(card.applicantID) == target)
			and GF.ApplicantCard and GF.ApplicantCard.ResetRemovalFade
		then
			GF.ApplicantCard:ResetRemovalFade(card)
		end
	end)
end

function Presenter:GetApplicantActionPending(applicantID)
	local key = applicantIDKey(applicantID)
	return self._pendingApplicantActions and self._pendingApplicantActions[key] or nil
end

function Presenter:IsApplicantActionPending(applicantID)
	return self:GetApplicantActionPending(applicantID) ~= nil
end

function Presenter:GetApplicantActionIntent(applicantID)
	local key = applicantIDKey(applicantID)
	return self._applicantActionIntents
		and self._applicantActionIntents[key] or nil
end

function Presenter:ClearApplicantActionIntent(applicantID)
	local key = applicantIDKey(applicantID)
	local intents = self._applicantActionIntents
	if not (intents and intents[key]) then
		return false
	end
	intents[key] = nil
	return true
end

function Presenter:ClearApplicantAction(applicantID, refresh)
	local key = applicantIDKey(applicantID)
	local actions = self._pendingApplicantActions
	local pending = actions and actions[key] or nil
	local clearedIntent = self:ClearApplicantActionIntent(applicantID)
	if not pending and not clearedIntent then
		return false
	end
	if pending then
		cancelTimer(pending.timer)
		actions[key] = nil
	end
	if refresh == true and self.scrollList then
		if not self:RefreshApplicant(applicantID, true) then
			self:UpdateInviteState()
		end
		if type(self.RunDeferredApplicantFullRefreshIfReady) == "function" then
			self:RunDeferredApplicantFullRefreshIfReady()
		end
	end
	return true
end

function Presenter:BeginApplicantAction(applicantID, action)
	local key = applicantIDKey(applicantID)
	if key == "" or (action ~= "invite" and action ~= "decline") then
		return false
	end
	local cached = self.applicantDataCache and self.applicantDataCache[key]
	if (action == "decline" and (isDeclinedApplicantData(cached)
			or (self._terminalApplicantLifecycles
				and self._terminalApplicantLifecycles[key])))
		or (cached and cached.status ~= nil and cached.status ~= "applied")
	then
		self:ClearApplicantAction(applicantID, false)
		self:RefreshApplicant(applicantID, false)
		return true
	end
	self:ClearApplicantAction(applicantID, false)
	self._pendingApplicantActions = self._pendingApplicantActions or {}
	self._applicantActionIntents = self._applicantActionIntents or {}
	local sessionToken = self._applicantRosterSessionToken
	if sessionToken == nil and type(self.EnsureApplicantRosterSession) == "function" then
		sessionToken = self:EnsureApplicantRosterSession()
	end
	local pending = {
		action = action,
		applicantID = applicantID,
		sessionToken = sessionToken,
		submitted = false,
	}
	self._pendingApplicantActions[key] = pending
	self._applicantActionIntents[key] = pending
	local pendingTimeoutSeconds = action == "decline"
		and DECLINE_PENDING_TIMEOUT_SECONDS
		or ACTION_PENDING_TIMEOUT_SECONDS
	pending.timer = scheduleTimer(pendingTimeoutSeconds, function()
		if self._pendingApplicantActions
			and self._pendingApplicantActions[key] == pending
		then
			self._pendingApplicantActions[key] = nil
			pending.timer = nil
			if pending.submitted ~= true then
				self:ClearApplicantActionIntent(applicantID)
			end
			if self.scrollList then
				if pending.action == "decline" and pending.submitted == true then
					local builder = GF.ApplicantSnapshotBuilder
					local currentIDs, providerReadable
					if builder and type(builder.GetSortedApplicantIDs) == "function" then
						currentIDs, providerReadable = builder:GetSortedApplicantIDs()
					end
					if providerReadable == true
						and not applicantIDInList(currentIDs, applicantID)
					then
						-- The list event is not guaranteed to arrive after the interaction
						-- timeout.  Reconcile provider membership here as well so a removed
						-- submitted decline cannot retain a stale per-ID spinner forever.
						local cleanup = self:ScheduleProviderMissingApplicantCleanup(
							applicantID, true)
						if cleanup then
							self:RemoveProviderMissingApplicant(applicantID, cleanup)
							return
						end
					elseif providerReadable ~= true then
						-- This ticket owns only a future provider re-read; unreadability is
						-- never itself evidence that the applicant disappeared.
						self:ScheduleProviderMissingApplicantCleanup(
							applicantID, false, true)
					end
				end
				local data = self:GetApplicantDisplayData(applicantID, true)
				if pending.submitted == true and data
					and data.status == "applied"
					and not hasNativePendingStatus(data)
				then
					self:ClearApplicantActionIntent(applicantID)
				end
				if not self:ApplyApplicantDisplayData(applicantID, data) then
					self:UpdateInviteState()
				end
				self:RunDeferredApplicantFullRefreshIfReady()
			end
		end
	end)
	if self.scrollList and not self:RefreshApplicant(applicantID, true) then
		self:UpdateInviteState()
	end
	return true
end

function Presenter:MarkApplicantActionSubmitted(applicantID, action)
	local intent = self:GetApplicantActionIntent(applicantID)
	if not (intent and intent.action == action
		and intent.sessionToken == self._applicantRosterSessionToken)
	then
		return false
	end
	intent.submitted = true
	intent.submittedAt = now()
	local builder = GF.ApplicantSnapshotBuilder
	local applicantIDs, providerReadable
	if builder and type(builder.GetSortedApplicantIDs) == "function" then
		applicantIDs, providerReadable = builder:GetSortedApplicantIDs()
	end
	if providerReadable == true
		and not applicantIDInList(applicantIDs, applicantID)
		and self.scrollList
	then
		-- DeclineApplicant may emit the list event synchronously before its Lua call
		-- returns.  Reconcile once after the caller records successful submission so
		-- that event ordering cannot discard the local provenance.
		self:OnApplicantListUpdated()
	end
	return true
end

function Presenter:CancelTerminalApplicantLifecycle(applicantID, resetVisual)
	local key = applicantIDKey(applicantID)
	local lifecycles = self._terminalApplicantLifecycles
	local lifecycle = lifecycles and lifecycles[key] or nil
	if not lifecycle then
		return false
	end
	cancelTimer(lifecycle.removalTimer)
	cancelTimer(lifecycle.fadeTimer)
	cancelTimer(lifecycle.ackRetryTimer)
	lifecycles[key] = nil
	local cached = self.applicantDataCache and self.applicantDataCache[key]
	if cached then
		cached._gfTerminalFadeToken = nil
		cached._gfTerminalFadeSeconds = nil
	end
	if resetVisual == true then
		self:ResetApplicantRemovalFades(applicantID)
	end
	return true
end

function Presenter:RemoveTerminalApplicant(applicantID, lifecycle)
	local key = applicantIDKey(applicantID)
	local lifecycles = self._terminalApplicantLifecycles
	if not (lifecycles and lifecycles[key] == lifecycle
		and lifecycle.nativeMissing == true)
	then
		return false
	end
	local reopenAuthorizedGeneration = lifecycle.deferredApplied == true
	if type(self.CancelProviderMissingApplicantCleanup) == "function" then
		self:CancelProviderMissingApplicantCleanup(applicantID)
	end
	cancelTimer(lifecycle.removalTimer)
	cancelTimer(lifecycle.fadeTimer)
	cancelTimer(lifecycle.ackRetryTimer)
	lifecycles[key] = nil
	self:ClearApplicantAction(applicantID, false)

	local nextIDs = {}
	local removed = false
	for _, id in ipairs(self.applicantIDs or {}) do
		if applicantIDKey(id) == key then
			removed = true
		else
			nextIDs[#nextIDs + 1] = id
		end
	end
	if self.applicantDataCache then
		self.applicantDataCache[key] = nil
	end
	if self.applicantElementCounts then
		self.applicantElementCounts[key] = nil
	end
	-- Every completed terminal row owns a session tombstone.  Provider/list events
	-- can arrive out of order and may briefly re-emit either the same terminal or
	-- an older invited snapshot; only a later authoritative applied state starts a
	-- new generation for this applicant ID.
	self._dismissedTerminalApplicants =
		self._dismissedTerminalApplicants or {}
	if reopenAuthorizedGeneration then
		-- An explicit applied observation already proved a newer generation for
		-- this ID.  The old terminal tombstone must stop owning the ID once its full
		-- acknowledgement finishes, even if the newer generation has advanced to
		-- invited or another terminal status in the meantime.
		self._dismissedTerminalApplicants[key] = nil
	else
		self._dismissedTerminalApplicants[key] = lifecycle.status
	end
	if lifecycle.status == "inviteaccepted" then
		-- The applicant workflow ends with the joined acknowledgement.  Roster
		-- identity is only a short-lived evidence source for ordinary members; it
		-- must not survive the fade and later turn a departure into a new row.
		self:ForgetApplicantRosterCandidate(applicantID, false)
	end
	if self.selectedApplicantRowKey
		and selectedApplicantIDFromKey(self.selectedApplicantRowKey) == key
	then
		self.selectedApplicantRowKey = nil
	end
	local function restoreDeferredGeneration()
		if not reopenAuthorizedGeneration then
			return
		end
		local freshData = buildApplicantSafely(applicantID)
			or cloneApplicantData(lifecycle.deferredApplicantData)
		if freshData and type(freshData.status) == "string"
			and freshData.status ~= ""
		then
			-- Preserve the complete terminal acknowledgement first, then consume the
			-- currently readable status from the already-authorized generation without
			-- waiting for another provider event or re-reading a different snapshot.
			self:OnApplicantUpdated(applicantID, false, freshData)
		end
	end
	if not removed then
		restoreDeferredGeneration()
		self:RunDeferredApplicantFullRefreshIfReady()
		return false
	end
	self.applicantIDs = nextIDs
	self:RebuildApplicantElements({ preserveScroll = true })
	restoreDeferredGeneration()
	self:RunDeferredApplicantFullRefreshIfReady()
	return true
end

function Presenter:StartTerminalApplicantRemoval(applicantID, lifecycle)
	local key = applicantIDKey(applicantID)
	if not (self._terminalApplicantLifecycles
		and self._terminalApplicantLifecycles[key] == lifecycle
		and lifecycle.nativeMissing == true)
	then
		return
	end
	lifecycle.removalTimer = nil
	local remaining = TERMINAL_MIN_VISIBLE_SECONDS
		- math.max(0, now() - (lifecycle.shownAt or now()))
	if remaining > TERMINAL_TIMER_EPSILON_SECONDS then
		lifecycle.removalTimer = scheduleTimer(remaining, function()
			self:StartTerminalApplicantRemoval(applicantID, lifecycle)
		end)
		return
	end

	local token = {}
	local fadedVisibleRow = false
	lifecycle.fadeToken = token
	lifecycle.fadeEndsAt = now() + TERMINAL_FADE_SECONDS
	self:ForEachVisibleRow(function(card)
		if card and applicantIDKey(card.applicantID) == key
			and GF.ApplicantCard and GF.ApplicantCard.PlayRemovalFade
		then
			fadedVisibleRow = GF.ApplicantCard:PlayRemovalFade(
				card, token, TERMINAL_FADE_SECONDS) or fadedVisibleRow
		end
	end)
	if not fadedVisibleRow then
		self:RemoveTerminalApplicant(applicantID, lifecycle)
		return
	end
	lifecycle.fadeTimer = scheduleTimer(TERMINAL_FADE_SECONDS, function()
		self:RemoveTerminalApplicant(applicantID, lifecycle)
	end)
end

function Presenter:ScheduleTerminalApplicantAcknowledgementRetry(
	applicantID, lifecycle)
	local key = applicantIDKey(applicantID)
	if key == ""
		or not (self._terminalApplicantLifecycles
			and self._terminalApplicantLifecycles[key] == lifecycle)
		or lifecycle.nativeMissing == true
		or lifecycle.ackAttempted == true
		or lifecycle.ackRetryTimer ~= nil
	then
		return false
	end
	lifecycle.ackRetryTimer = scheduleTimer(
		PROVIDER_MISSING_GRACE_SECONDS, function()
			if not (self._terminalApplicantLifecycles
				and self._terminalApplicantLifecycles[key] == lifecycle)
			then
				return
			end
			lifecycle.ackRetryTimer = nil
			local builder = GF.ApplicantSnapshotBuilder
			local currentIDs, providerReadable
			if builder and type(builder.GetSortedApplicantIDs) == "function" then
				currentIDs, providerReadable = builder:GetSortedApplicantIDs()
			end
			local cached = self.applicantDataCache
				and self.applicantDataCache[key]
			if providerReadable == true
				and not applicantIDInList(currentIDs, applicantID)
			then
				-- A readable provider omission is sufficient to finish the already
				-- cached terminal feedback; no destructive acknowledgement remains.
				self:NoteTerminalApplicant(applicantID, cached, true)
				return
			end
			-- Re-enter the single lifecycle owner.  ApplicantActionService performs
			-- a fresh exact-status/applicantInfo/permission read on every attempt.
			self:NoteTerminalApplicant(applicantID, cached, false)
		end)
	return lifecycle.ackRetryTimer ~= nil
end

function Presenter:NoteTerminalApplicant(applicantID, data, nativeMissing)
	local key = applicantIDKey(applicantID)
	if key == "" or isTestApplicantID(applicantID)
		or not isTerminalRemovalApplicantData(data)
	then
		return nil
	end
	local status = data.status
	local listingKnownMissing = false
	local listing = GF.RecruitmentSession
	local hasActive = listing and listing.HasActive
	if type(hasActive) == "function" then
		local ok, active = pcall(hasActive, listing)
		listingKnownMissing = ok and active == false
	end
	if self._listingLossCleanupTimer and not listingKnownMissing then
		cancelTimer(self._listingLossCleanupTimer)
		self._listingLossCleanupTimer = nil
	end
	if status == "inviteaccepted" then
		data = markApplicantDataJoined(data)
	elseif DECLINED_STATUSES[status] == true then
		data = markApplicantDataDeclined(data)
	else
		data = markApplicantDataClosed(data)
	end
	self.applicantDataCache = self.applicantDataCache or {}
	self.applicantDataCache[key] = data
	if type(self.CancelProviderMissingApplicantCleanup) == "function" then
		self:CancelProviderMissingApplicantCleanup(applicantID)
	end
	self:ClearApplicantAction(applicantID, false)
	self._terminalApplicantLifecycles = self._terminalApplicantLifecycles or {}
	local lifecycle = self._terminalApplicantLifecycles[key]
	if not lifecycle then
		lifecycle = {
			applicantID = applicantID,
			shownAt = now(),
			status = status,
		}
		self._terminalApplicantLifecycles[key] = lifecycle
	elseif lifecycle.status ~= status then
		cancelTimer(lifecycle.removalTimer)
		cancelTimer(lifecycle.fadeTimer)
		cancelTimer(lifecycle.ackRetryTimer)
		lifecycle.removalTimer = nil
		lifecycle.fadeTimer = nil
		lifecycle.ackRetryTimer = nil
		lifecycle.fadeToken = nil
		lifecycle.fadeEndsAt = nil
		lifecycle.shownAt = now()
		lifecycle.status = status
		self:ResetApplicantRemovalFades(applicantID)
	end
	if AUTO_DISMISS_TERMINAL_STATUSES[status] == true then
		local rosterCandidate = self:GetApplicantRosterCandidate(applicantID)
		if status == "inviteaccepted" and rosterCandidate then
			rosterCandidate.nativeTerminalPending = nil
		end
		-- These statuses close the applicant workflow and should disappear after a
		-- short acknowledgement.  Keep nativeMissing separate, however: if the
		-- guarded RemoveApplicant fresh-read is temporarily unavailable, the retry
		-- owner must survive the minimum-visible interval and acknowledge later.
		lifecycle.dismissAfterRemoval = true
		if nativeMissing == true then
			lifecycle.nativeMissing = true
		end
	elseif listingKnownMissing then
		-- Once the active entry is authoritatively gone, no later provider omission
		-- is required to release a readable declined row.  The shared lifecycle still
		-- enforces its full minimum-visible interval and fade.
		lifecycle.nativeMissing = true
		lifecycle.dismissAfterRemoval = true
	elseif nativeMissing ~= nil and lifecycle.nativeMissing ~= true then
		lifecycle.nativeMissing = nativeMissing == true
	end
	local actions = GF.ApplicantActionService
	local canAcknowledge = lifecycle.nativeMissing ~= true
		and nativeMissing ~= true
		and not listingKnownMissing
		and actions
		and type(actions.AcknowledgeTerminalApplicant) == "function"
	if canAcknowledge and lifecycle.ackAttempted ~= true
		and lifecycle.ackInFlight ~= true
	then
		-- GF intentionally does not expose Blizzard's second terminal X button.
		-- Submit that native acknowledgement once, after caching the terminal row.
		-- The in-flight flag protects against RemoveApplicant emitting synchronous
		-- applicant/list events before this call returns.
		lifecycle.ackInFlight = true
		local callOK, submitted, _, attempted = pcall(
			actions.AcknowledgeTerminalApplicant,
			actions,
			applicantID,
			status)
		if callOK ~= true then
			submitted = false
			attempted = true
		end
		if self._terminalApplicantLifecycles
			and self._terminalApplicantLifecycles[key] == lifecycle
		then
			lifecycle.ackInFlight = nil
			if attempted == true or submitted == true then
				lifecycle.ackAttempted = true
				lifecycle.ackSubmitted = submitted == true
				if submitted == true then
					-- RemoveApplicant has no documented return value.  A protected,
					-- exception-free submission is the local acknowledgement boundary;
					-- provider events may arrive later and are suppressed by the tombstone.
					lifecycle.nativeMissing = true
					lifecycle.dismissAfterRemoval = true
				elseif attempted == true then
					-- A protected call failure has no safe native retry contract.  Keep the
					-- terminal feedback bounded so the invisible acknowledgement button
					-- cannot strand this applicant generation forever.
					lifecycle.nativeMissing = true
					lifecycle.dismissAfterRemoval = true
				end
			end
		end
	end
	if lifecycle.nativeMissing then
		cancelTimer(lifecycle.ackRetryTimer)
		lifecycle.ackRetryTimer = nil
		if not lifecycle.removalTimer and not lifecycle.fadeTimer then
			lifecycle.removalTimer = scheduleTimer(0, function()
				self:StartTerminalApplicantRemoval(applicantID, lifecycle)
			end)
		end
	elseif lifecycle.removalTimer or lifecycle.fadeTimer then
		cancelTimer(lifecycle.removalTimer)
		cancelTimer(lifecycle.fadeTimer)
		lifecycle.removalTimer = nil
		lifecycle.fadeTimer = nil
		lifecycle.fadeToken = nil
		lifecycle.fadeEndsAt = nil
		self:ResetApplicantRemovalFades(applicantID)
	end
	if lifecycle.nativeMissing ~= true
		and lifecycle.ackAttempted ~= true
		and lifecycle.ackInFlight ~= true
	then
		-- GetApplicantInfo() can be temporarily unavailable/secret without a later
		-- LFG event.  Retry the fresh guarded acknowledgement on a cancellable ticket
		-- so a terminal row cannot become permanent after lockdown clears.
		self:ScheduleTerminalApplicantAcknowledgementRetry(
			applicantID, lifecycle)
	end
	if listingKnownMissing
		and type(self.ScheduleListingLossCleanup) == "function"
	then
		-- Keep one session cleanup owner alive while this terminal row finishes.
		-- It waits for the lifecycle, then prunes other unresolved candidates and
		-- transient retention.
		self:ScheduleListingLossCleanup()
	end
	return data, lifecycle
end

function Presenter:ResetApplicantTransientState()
	cancelTimer(self._listingLossCleanupTimer)
	self._listingLossCleanupTimer = nil
	-- Deferred full refreshes belong to the current applicant projection.
	-- Explicit lifecycle resets must not replay an old sort in a later session.
	self._deferredApplicantFullRefresh = nil
	for _, pending in pairs(self._pendingApplicantActions or {}) do
		cancelTimer(pending.timer)
	end
	for _, cleanup in pairs(self._providerMissingApplicantCleanups or {}) do
		cancelTimer(cleanup.timer)
	end
	local joinedCandidates = {}
	for key, lifecycle in pairs(self._terminalApplicantLifecycles or {}) do
		cancelTimer(lifecycle.removalTimer)
		cancelTimer(lifecycle.fadeTimer)
		cancelTimer(lifecycle.ackRetryTimer)
		if AUTO_DISMISS_TERMINAL_STATUSES[lifecycle.status] == true
			or lifecycle.dismissAfterRemoval == true
			or lifecycle.nativeMissing == true
		then
			self._dismissedTerminalApplicants =
				self._dismissedTerminalApplicants or {}
			self._dismissedTerminalApplicants[key] = lifecycle.status
		end
		if lifecycle.status == "inviteaccepted" then
			joinedCandidates[#joinedCandidates + 1] = lifecycle.applicantID
		end
	end
	self._pendingApplicantActions = nil
	self._applicantActionIntents = nil
	self._providerMissingApplicantCleanups = nil
	self._terminalApplicantLifecycles = nil
	for _, applicantID in ipairs(joinedCandidates) do
		self:ForgetApplicantRosterCandidate(applicantID, false)
	end
	for _, data in pairs(self.applicantDataCache or {}) do
		if type(data) == "table" then
			data._gfTerminalFadeToken = nil
			data._gfTerminalFadeSeconds = nil
		end
	end
	self:ResetApplicantRemovalFades()
end

cloneApplicantData = function(data)
	local model = GF.ApplicantSnapshotBuilder
	if model and type(model.CloneApplicantData) == "function" then
		return model:CloneApplicantData(data)
	end
	return data
end

function Presenter:RunDeferredApplicantFullRefreshIfReady()
	if self._deferredApplicantFullRefresh ~= true
		or hasApplicantTransientState(self)
		or not self.scrollList
	then
		return false
	end
	self._deferredApplicantFullRefresh = nil
	self:RefreshList({ forceFull = true, preserveScroll = true })
	return true
end

function Presenter:NoteObservedTerminalApplicant(applicantID, status)
	local key = applicantIDKey(applicantID)
	if key == "" or type(status) ~= "string" or status == "" then
		return false
	end
	local cached = self.applicantDataCache and self.applicantDataCache[key]
	local data = cloneApplicantData(cached)
	if type(data) ~= "table" then
		return false
	end
	data.applicantID = applicantID
	data.appInfo = type(data.appInfo) == "table" and data.appInfo or {}
	data.appInfo.applicationStatus = status
	data.status = status
	data.loading = false
	data._gfNativeAvailable = false
	local terminalData = self:NoteTerminalApplicant(applicantID, data, false)
	if not terminalData then
		return false
	end
	self:ApplyApplicantDisplayData(applicantID, terminalData)
	return true
end

function Presenter:CancelProviderMissingApplicantCleanup(applicantID)
	local key = applicantIDKey(applicantID)
	local cleanups = self._providerMissingApplicantCleanups
	local cleanup = cleanups and cleanups[key] or nil
	if not cleanup then
		return false
	end
	cancelTimer(cleanup.timer)
	cleanups[key] = nil
	return true
end

function Presenter:RemoveProviderMissingApplicant(applicantID, cleanup)
	local key = applicantIDKey(applicantID)
	local cleanups = self._providerMissingApplicantCleanups
	if key == "" or not (cleanups and cleanups[key] == cleanup)
		or cleanup.sessionToken ~= self._applicantRosterSessionToken
	then
		return false
	end
	local builder = GF.ApplicantSnapshotBuilder
	local currentIDs, providerReadable
	if builder and type(builder.GetSortedApplicantIDs) == "function" then
		currentIDs, providerReadable = builder:GetSortedApplicantIDs()
	end
	if providerReadable ~= true then
		cleanup.timer = scheduleTimer(
			PROVIDER_MISSING_GRACE_SECONDS, function()
				self:RemoveProviderMissingApplicant(applicantID, cleanup)
			end)
		return false
	end
	if applicantIDInList(currentIDs, applicantID) then
		if self.scrollList then
			self:OnApplicantListUpdated()
		end
		return false
	end
	local localDeclineData = self:ConfirmLocalDeclineAfterProviderRemoval(
		applicantID, true)
	if localDeclineData then
		self:ApplyApplicantDisplayData(applicantID, localDeclineData)
		return true
	end
	local lifecycle = self._terminalApplicantLifecycles
		and self._terminalApplicantLifecycles[key]
	local rosterCandidate = self:GetApplicantRosterCandidate(applicantID)
	local cached = self.applicantDataCache and self.applicantDataCache[key]
	if lifecycle or rosterCandidate
		or (self._retainedInvitedApplicants
			and self._retainedInvitedApplicants[key])
		or (cached and cached.status == "invited")
	then
		self:CancelProviderMissingApplicantCleanup(applicantID)
		return false
	end

	cleanups[key] = nil
	self:ClearApplicantAction(applicantID, false)
	local nextIDs = {}
	local removed = false
	for _, id in ipairs(self.applicantIDs or {}) do
		if applicantIDKey(id) == key then
			removed = true
		else
			nextIDs[#nextIDs + 1] = id
		end
	end
	if self.applicantDataCache then
		self.applicantDataCache[key] = nil
	end
	if self.applicantElementCounts then
		self.applicantElementCounts[key] = nil
	end
	if self.selectedApplicantRowKey
		and selectedApplicantIDFromKey(self.selectedApplicantRowKey) == key
	then
		self.selectedApplicantRowKey = nil
	end
	if removed then
		self.applicantIDs = nextIDs
		self:RebuildApplicantElements({ preserveScroll = true })
	end
	self:RunDeferredApplicantFullRefreshIfReady()
	return removed
end

function Presenter:ScheduleProviderMissingApplicantCleanup(
	applicantID, providerReadable, allowUnreadable)
	local key = applicantIDKey(applicantID)
	if key == "" or (providerReadable ~= true and allowUnreadable ~= true) then
		return nil
	end
	self._providerMissingApplicantCleanups =
		self._providerMissingApplicantCleanups or {}
	local existing = self._providerMissingApplicantCleanups[key]
	if existing then
		if not existing.timer then
			existing.timer = scheduleTimer(
				PROVIDER_MISSING_GRACE_SECONDS, function()
					self:RemoveProviderMissingApplicant(applicantID, existing)
				end)
		end
		return existing
	end
	local cleanup = {
		applicantID = applicantID,
		sessionToken = self._applicantRosterSessionToken,
	}
	self._providerMissingApplicantCleanups[key] = cleanup
	cleanup.timer = scheduleTimer(PROVIDER_MISSING_GRACE_SECONDS, function()
		self:RemoveProviderMissingApplicant(applicantID, cleanup)
	end)
	return cleanup
end

function Presenter:ScheduleSubmittedDeclineProviderCheck(applicantID, providerReadable)
	local intent = self:GetApplicantActionIntent(applicantID)
	if providerReadable ~= true
		or not (intent and intent.action == "decline"
			and intent.submitted == true
			and intent.sessionToken == self._applicantRosterSessionToken)
	then
		return nil
	end
	local cleanup = self:ScheduleProviderMissingApplicantCleanup(
		applicantID, providerReadable)
	if not cleanup then
		return cleanup
	end
	if cleanup.submittedDecline == true then
		return cleanup
	end
	cleanup.submittedDecline = true
	cancelTimer(cleanup.timer)
	local submittedAt = tonumber(intent.submittedAt) or now()
	local remaining = math.max(
		0, DECLINE_PENDING_TIMEOUT_SECONDS - math.max(0, now() - submittedAt))
	cleanup.timer = scheduleTimer(remaining, function()
		self:RemoveProviderMissingApplicant(applicantID, cleanup)
	end)
	return cleanup
end

function Presenter:ConfirmLocalDeclineAfterProviderRemoval(applicantID, providerReadable)
	local key = applicantIDKey(applicantID)
	local intent = self:GetApplicantActionIntent(applicantID)
	local cached = self.applicantDataCache and self.applicantDataCache[key]
	if key == "" or providerReadable ~= true
		or not (intent and intent.action == "decline"
			and intent.submitted == true
			and intent.sessionToken == self._applicantRosterSessionToken)
		or type(cached) ~= "table"
	then
		return nil
	end
	-- A local, successfully-started decline plus the current provider dropping
	-- that exact ID closes the old provider record.  Per-ID reads can still return
	-- the stale applied/pending snapshot in the same event stack, so do not let it
	-- keep the old row spinning or compete with a new ID from the same player.
	local data = cloneApplicantData(cached)
	data.applicantID = applicantID
	data._gfNativeAvailable = false
	data = markApplicantDataDeclined(data)
	self.applicantDataCache[key] = data
	return self:NoteTerminalApplicant(applicantID, data, true)
end

local function cancelRosterCandidateResolutionTimers(candidate)
	if not candidate then
		return
	end
	cancelTimer(candidate.postEventTimer)
	cancelTimer(candidate.resolveTimer)
	candidate.postEventTimer = nil
	candidate.resolveTimer = nil
end

local function cancelRosterCandidateTimers(candidate)
	cancelRosterCandidateResolutionTimers(candidate)
end

function Presenter:EnsureApplicantRosterSession()
	if not self._applicantRosterSessionToken then
		self._applicantRosterSessionToken = {}
	end
	self._applicantRosterCandidates = self._applicantRosterCandidates or {}
	return self._applicantRosterSessionToken, self._applicantRosterCandidates
end

function Presenter:GetApplicantRosterCandidate(applicantID)
	local key = applicantIDKey(applicantID)
	local candidate = self._applicantRosterCandidates
		and self._applicantRosterCandidates[key]
	if candidate and candidate.sessionToken == self._applicantRosterSessionToken then
		return candidate
	end
	return nil
end

function Presenter:ForgetApplicantRosterCandidate(applicantID, releaseTerminal)
	local key = applicantIDKey(applicantID)
	local candidates = self._applicantRosterCandidates
	local candidate = candidates and candidates[key]
	if not candidate then
		return false
	end
	cancelRosterCandidateTimers(candidate)
	candidates[key] = nil
	if releaseTerminal == true then
		self:CancelTerminalApplicantLifecycle(applicantID, true)
		if self._dismissedTerminalApplicants then
			self._dismissedTerminalApplicants[key] = nil
		end
	end
	return true
end

function Presenter:ResetApplicantRosterSession()
	cancelTimer(self._applicantRosterRecheckTimer)
	self._applicantRosterRecheckTimer = nil
	for _, candidate in pairs(self._applicantRosterCandidates or {}) do
		cancelRosterCandidateTimers(candidate)
	end
	self._applicantRosterSessionToken = {}
	self._applicantRosterCandidates = {}
end

function Presenter:PruneUnresolvedApplicantRosterCandidates()
	local unresolved = {}
	for _, candidate in pairs(self._applicantRosterCandidates or {}) do
		if candidate.phase == "pending" or candidate.phase == "invited" then
			unresolved[#unresolved + 1] = candidate
		end
	end
	for _, candidate in ipairs(unresolved) do
		self:HideUnresolvedRosterCandidate(candidate)
		self:ForgetApplicantRosterCandidate(candidate.applicantID, false)
	end
	return #unresolved > 0
end

function Presenter:ResetForNewApplicantSession()
	self:CancelListingLossCleanup()
	self:ResetApplicantTransientState()
	self:ResetApplicantRosterSession()
	self._retainedInvitedApplicants = nil
	self._dismissedTerminalApplicants = nil
	self.applicantIDs = {}
	self.applicantDataCache = {}
	self.applicantElementCounts = {}
	self.selectedApplicantRowKey = nil
	self.totalCount = 0
	self._requiresInitialProviderRefresh = true
	self._applicantElementsDirty = nil
	if self.scrollList then
		if self:IsPresentationVisible() then
			self:RebuildApplicantElements({ preserveScroll = true })
		else
			self._applicantElementsDirty = true
		end
	end
end

local function retainsInactiveApplicantFeedback(panel, applicantID, cachedData)
	local key = applicantIDKey(applicantID)
	if key == "" then
		return false
	end
	if isFixtureApplicantID(applicantID, cachedData) then
		return true
	end
	if panel._terminalApplicantLifecycles
		and panel._terminalApplicantLifecycles[key]
	then
		return true
	end
	if panel._retainedInvitedApplicants
		and panel._retainedInvitedApplicants[key]
	then
		return true
	end
	return panel:GetApplicantRosterCandidate(applicantID) ~= nil
end

function Presenter:RetireInactiveApplicantSnapshot()
	-- GetApplicants() can keep returning the previous entry's IDs after Blizzard
	-- has authoritatively removed that entry.  They are not a readable snapshot of
	-- a draft that has not been published.  Retire ordinary rows without waiting
	-- for the provider to converge, while leaving the short terminal/invited
	-- feedback owners intact so their existing acknowledgement and fade contracts
	-- can finish.
	if presenterHasAuthoritativeListing
		and presenterHasAuthoritativeListing()
	then
		return false
	end

	local previousIDs = self.applicantIDs or {}
	local previousCache = self.applicantDataCache or {}
	local previousCounts = self.applicantElementCounts or {}
	local retainedIDs = {}
	local retainedKeys = {}
	local changed = false

	for _, applicantID in ipairs(previousIDs) do
		local key = applicantIDKey(applicantID)
		local cachedData = previousCache[key]
		if retainsInactiveApplicantFeedback(self, applicantID, cachedData) then
			retainedIDs[#retainedIDs + 1] = applicantID
			retainedKeys[key] = true
		else
			changed = true
			self:CancelProviderMissingApplicantCleanup(applicantID)
			self:ClearApplicantAction(applicantID, false)
		end
	end

	local retainedCache = {}
	local retainedCounts = {}
	for key in pairs(retainedKeys) do
		retainedCache[key] = previousCache[key]
		retainedCounts[key] = previousCounts[key]
	end
	for key, cachedData in pairs(previousCache) do
		if retainedCache[key] == nil then
			local applicantID = type(cachedData) == "table"
				and cachedData.applicantID or key
			if retainsInactiveApplicantFeedback(self, applicantID, cachedData) then
				retainedCache[key] = cachedData
				retainedCounts[key] = previousCounts[key]
			else
				changed = true
			end
		end
	end

	self.applicantIDs = retainedIDs
	self.applicantDataCache = retainedCache
	self.applicantElementCounts = retainedCounts
	self.totalCount = #retainedIDs
	self._deferredApplicantFullRefresh = nil
	if self.selectedApplicantRowKey then
		local selectedID = selectedApplicantIDFromKey(
			self.selectedApplicantRowKey)
		if not retainedKeys[applicantIDKey(selectedID)] then
			self.selectedApplicantRowKey = nil
			changed = true
		end
	end

	if (changed or self._applicantElementsDirty) and self.scrollList then
		if self:IsPresentationVisible() then
			self:RebuildApplicantElements({ preserveScroll = true })
		else
			self._applicantElementsDirty = true
		end
	end
	return changed
end

function Presenter:CaptureApplicantRosterCandidate(applicantID, data, allowApplied)
	if isTestApplicantID(applicantID) or type(data) ~= "table" then
		return nil
	end
	local status = data.status
	local key = applicantIDKey(applicantID)
	local existing = self:GetApplicantRosterCandidate(applicantID)
	if existing and status == "applied" and allowApplied == true then
		-- A readable applied state is a new application generation for this ID,
		-- stronger than the joined acknowledgement from its previous use.
		self:ForgetApplicantRosterCandidate(applicantID, true)
		existing = nil
	end
	local wasJoined = existing and existing.phase == "joined"
	if status == "applied" and allowApplied ~= true then
		if existing then
			self:ForgetApplicantRosterCandidate(applicantID, true)
		end
		return nil
	end
	local trackable = status == "invited"
		or status == "inviteaccepted"
		or (status == "applied" and allowApplied == true)
	if not trackable then
		if status ~= nil and existing then
			self:ForgetApplicantRosterCandidate(applicantID, false)
		end
		return nil
	end
	if existing and existing.phase == "joined"
		and status ~= "inviteaccepted"
	then
		-- A late ordinary-member "invited" snapshot is weaker than a roster- or
		-- native-confirmed joined transition from the same listing session.
		return existing
	end
	local model = GF.ApplicantSnapshotBuilder
	local identity = model and model.GetApplicantRosterIdentity
		and model:GetApplicantRosterIdentity(data)
	if not identity and not (existing and status == "inviteaccepted") then
		return existing
	end
	local sessionToken, candidates = self:EnsureApplicantRosterSession()
	local candidate = existing
	if not candidate then
		candidate = {
			applicantID = applicantID,
			boundGUIDs = {},
			phase = status == "inviteaccepted" and "joined"
				or (status == "invited" and "invited" or "pending"),
			sessionToken = sessionToken,
		}
		candidates[key] = candidate
	end
	local previousSnapshot = candidate.snapshot
	if identity then
		candidate.expectedCount = identity.expectedCount
		candidate.memberKeys = identity.keys
		candidate.snapshot = cloneApplicantData(data)
	elseif not candidate.snapshot then
		candidate.snapshot = cloneApplicantData(data)
	end
	local currentIndex = applicantIDIndex(self.applicantIDs, applicantID)
	if currentIndex then
		candidate.rowIndexHint = currentIndex
		candidate.previousApplicantID = self.applicantIDs[currentIndex - 1]
		candidate.nextApplicantID = self.applicantIDs[currentIndex + 1]
		if not candidate.orderSnapshot then
			candidate.orderSnapshot = {}
			for index, orderedApplicantID in ipairs(self.applicantIDs or {}) do
				candidate.orderSnapshot[index] = orderedApplicantID
			end
			candidate.orderSnapshotIndex = currentIndex
		end
	else
		candidate.rowIndexHint = candidate.rowIndexHint
			or math.max(1, #(self.applicantIDs or {}) + 1)
	end
	candidate.visualHidden = false
	if status == "inviteaccepted" then
		candidate.appliedRemovalProbe = nil
		if not wasJoined then
			candidate.nativeTerminalPending = true
		end
		candidate.phase = "joined"
		candidate.nativeConfirmed = true
		candidate.joinedData = markApplicantDataJoined(cloneApplicantData(
			identity and data or previousSnapshot or data))
		cancelRosterCandidateResolutionTimers(candidate)
	elseif status == "invited" then
		candidate.appliedRemovalProbe = nil
		candidate.phase = "invited"
	elseif status == "applied" and allowApplied == true then
		candidate.appliedRemovalProbe = true
		candidate.phase = "pending"
	end
	return candidate
end

function Presenter:GetRosterFeedbackApplicantData(applicantID)
	local candidate = self:GetApplicantRosterCandidate(applicantID)
	if not candidate then
		return nil
	end
	local key = applicantIDKey(applicantID)
	if candidate.phase == "joined" and candidate.joinedData
		and self._terminalApplicantLifecycles
		and self._terminalApplicantLifecycles[key]
	then
		return candidate.joinedData
	end
	return nil
end

local function resolveRosterCandidateInsertIndex(candidate, applicantIDs)
	local orderSnapshot = candidate.orderSnapshot
	local snapshotIndex = tonumber(candidate.orderSnapshotIndex)
	if type(orderSnapshot) == "table" and snapshotIndex then
		for index = snapshotIndex + 1, #orderSnapshot do
			local laterIndex = applicantIDIndex(applicantIDs, orderSnapshot[index])
			if laterIndex then
				return laterIndex
			end
		end
		for index = snapshotIndex - 1, 1, -1 do
			local earlierIndex = applicantIDIndex(applicantIDs, orderSnapshot[index])
			if earlierIndex then
				return earlierIndex + 1
			end
		end
	end
	local previousIndex = candidate.previousApplicantID
		and applicantIDIndex(applicantIDs, candidate.previousApplicantID)
	if previousIndex then
		return previousIndex + 1
	end
	local nextIndex = candidate.nextApplicantID
		and applicantIDIndex(applicantIDs, candidate.nextApplicantID)
	if nextIndex then
		return nextIndex
	end
	return math.max(1, math.min(
		#applicantIDs + 1,
		tonumber(candidate.rowIndexHint) or (#applicantIDs + 1)
	))
end

function Presenter:EnsureRosterCandidateApplicantID(candidate)
	if not candidate then
		return false
	end
	self.applicantIDs = self.applicantIDs or {}
	local currentIndex = applicantIDIndex(self.applicantIDs, candidate.applicantID)
	if currentIndex then
		candidate.rowIndexHint = currentIndex
		return false
	end
	local insertAt = resolveRosterCandidateInsertIndex(
		candidate, self.applicantIDs)
	table.insert(self.applicantIDs, insertAt, candidate.applicantID)
	candidate.rowIndexHint = insertAt
	return true
end

function Presenter:RemoveRosterCandidateApplicantRow(candidate)
	if not candidate then
		return false
	end
	local key = applicantIDKey(candidate.applicantID)
	self:CancelProviderMissingApplicantCleanup(candidate.applicantID)
	local nextIDs = {}
	local removed = false
	for _, applicantID in ipairs(self.applicantIDs or {}) do
		if applicantIDKey(applicantID) == key then
			removed = true
		else
			nextIDs[#nextIDs + 1] = applicantID
		end
	end
	if not removed then
		return false
	end
	self.applicantIDs = nextIDs
	if self.applicantDataCache then
		self.applicantDataCache[key] = nil
	end
	if self.applicantElementCounts then
		self.applicantElementCounts[key] = nil
	end
	if self.selectedApplicantRowKey
		and selectedApplicantIDFromKey(self.selectedApplicantRowKey) == key
	then
		self.selectedApplicantRowKey = nil
	end
	return true
end

function Presenter:HideUnresolvedRosterCandidate(candidate)
	if not candidate or candidate.phase == "joined" then
		return false
	end
	candidate.visualHidden = true
	local key = applicantIDKey(candidate.applicantID)
	if self._retainedInvitedApplicants then
		self._retainedInvitedApplicants[key] = nil
	end
	local removed = self:RemoveRosterCandidateApplicantRow(candidate)
	if removed and self.scrollList then
		self:RebuildApplicantElements({ preserveScroll = true })
	end
	return removed
end

function Presenter:ScheduleRosterCandidateResolution(candidate)
	if not candidate or candidate.resolveTimer
		or candidate.phase == "joined"
	then
		return
	end
	local sessionToken = candidate.sessionToken
	candidate.resolveTimer = scheduleTimer(ROSTER_RESOLUTION_SECONDS, function()
		candidate.resolveTimer = nil
		if sessionToken ~= self._applicantRosterSessionToken
			or self:GetApplicantRosterCandidate(candidate.applicantID) ~= candidate
		then
			return
		end
		self:ReconcileApplicantRosterState()
		if candidate.phase == "joined" then
			return
		end
		local data = buildApplicantSafely(candidate.applicantID)
		if data then
			if data.status == "applied" then
				-- The native applicant survived the ordinary-member event pass, so
				-- there is no disappearance for roster compensation to explain.
				-- Drop only the speculative candidate and leave the live row intact.
				self:ForgetApplicantRosterCandidate(candidate.applicantID, false)
				return
			end
			if data.status == "invited" then
				-- Native applicant events and roster events will wake this candidate.
				-- A readable, unchanged invitation is not a reason to poll forever.
				return
			end
			self:OnApplicantUpdated(candidate.applicantID)
			return
		end
		self:HideUnresolvedRosterCandidate(candidate)
		self:ForgetApplicantRosterCandidate(candidate.applicantID, false)
	end)
end

function Presenter:ScheduleApplicantPostEventRecheck(candidate)
	if not candidate or candidate.phase == "joined" then
		return
	end
	cancelTimer(candidate.postEventTimer)
	local sessionToken = candidate.sessionToken
	candidate.postEventTimer = scheduleTimer(0, function()
		candidate.postEventTimer = nil
		if sessionToken ~= self._applicantRosterSessionToken
			or self:GetApplicantRosterCandidate(candidate.applicantID) ~= candidate
		then
			return
		end
		self:ReconcileApplicantRosterState()
		if candidate.phase == "joined" then
			return
		end
		local data = buildApplicantSafely(candidate.applicantID)
		if data then
			if data.status == "applied" then
				-- GroupFinder can receive LFG_LIST_APPLICANT_UPDATED before the
				-- unempowered Blizzard viewer removes this ID.  Give the native
				-- handler one bounded grace period instead of recursively rearming
				-- a zero-delay applied-state recheck.
				self:ScheduleRosterCandidateResolution(candidate)
				return
			end
			if data.status ~= "invited" then
				self:OnApplicantUpdated(candidate.applicantID)
				return
			end
			local refreshed = self:CaptureApplicantRosterCandidate(
				candidate.applicantID, data, false)
			self:ScheduleRosterCandidateResolution(refreshed or candidate)
			return
		end
		self:ScheduleRosterCandidateResolution(candidate)
	end)
end

local function isRosterCandidateFullyPresent(candidate, roster)
	if type(roster) ~= "table" or roster.complete ~= true then
		return false
	end
	local keys = candidate and candidate.memberKeys or nil
	if type(keys) ~= "table" or #keys ~= candidate.expectedCount then
		return false
	end
	local allPresent = true
	for _, nameKey in ipairs(keys) do
		local identity = roster.byName and roster.byName[nameKey]
		local guidKey = candidate.boundGUIDs and candidate.boundGUIDs[nameKey]
		if not identity and guidKey and roster.byGUID then
			identity = roster.byGUID[guidKey]
		end
		if identity then
			if identity.guidKey then
				candidate.boundGUIDs[nameKey] = identity.guidKey
			end
		else
			allPresent = false
		end
	end
	return allPresent
end

function Presenter:ProjectRosterApplicantJoined(candidate)
	if not candidate then
		return false
	end
	cancelRosterCandidateTimers(candidate)
	candidate.phase = "joined"
	candidate.visualHidden = false
	local data = markApplicantDataJoined(cloneApplicantData(
		candidate.joinedData or candidate.snapshot))
	if not data then
		return false
	end
	data._gfRosterDerived = candidate.nativeConfirmed ~= true
	data._gfRosterState = "joined"
	if candidate.nativeConfirmed ~= true then
		data._gfNativeAvailable = false
	end
	candidate.joinedData = data
	local key = applicantIDKey(candidate.applicantID)
	if self._dismissedTerminalApplicants then
		self._dismissedTerminalApplicants[key] = nil
	end
	if self._retainedInvitedApplicants then
		self._retainedInvitedApplicants[key] = nil
	end
	self:EnsureRosterCandidateApplicantID(candidate)
	self.applicantDataCache = self.applicantDataCache or {}
	self.applicantDataCache[key] = data
	self:NoteTerminalApplicant(candidate.applicantID, data)
	if self.scrollList then
		if self:IsPresentationVisible() then
			self:RebuildApplicantElements({ preserveScroll = true })
		else
			self._applicantElementsDirty = true
		end
	end
	return true
end

function Presenter:ReconcileApplicantRosterState()
	local model = GF.ApplicantSnapshotBuilder
	local roster = model and model.GetHomeRosterIdentitySnapshot
		and model:GetHomeRosterIdentitySnapshot()
	if type(roster) ~= "table" then
		return false
	end
	local changes = {}
	for _, candidate in pairs(self._applicantRosterCandidates or {}) do
		if candidate.sessionToken == self._applicantRosterSessionToken
			and (candidate.phase == "pending" or candidate.phase == "invited")
		then
			local allPresent = isRosterCandidateFullyPresent(candidate, roster)
			if allPresent then
				changes[#changes + 1] = candidate
			end
		end
	end
	local changed = false
	for _, candidate in ipairs(changes) do
		changed = self:ProjectRosterApplicantJoined(candidate) or changed
	end
	return changed
end

function Presenter:OnGroupRosterChanged()
	self:ReconcileApplicantRosterState()
	cancelTimer(self._applicantRosterRecheckTimer)
	local sessionToken = self._applicantRosterSessionToken
	self._applicantRosterRecheckTimer = scheduleTimer(0, function()
		self._applicantRosterRecheckTimer = nil
		if sessionToken == self._applicantRosterSessionToken then
			self:ReconcileApplicantRosterState()
		end
	end)
end

function Presenter:OnGroupLeft(category)
	local ok, hasExplicitCategory, isHome = pcall(function()
		return category ~= nil,
			category ~= nil and category == LE_PARTY_CATEGORY_HOME
	end)
	local leftHome = ok and hasExplicitCategory == true and isHome == true
	if (not ok or hasExplicitCategory ~= true)
		and type(IsInGroup) == "function"
	then
		local okGroup, stillInHome = pcall(IsInGroup, LE_PARTY_CATEGORY_HOME)
		leftHome = okGroup and stillInHome == false
	end
	if leftHome then
		-- Leaving the local HOME group ends the roster generation itself; it is
		-- not evidence that every previously joined applicant independently left.
		self:ResetForNewApplicantSession()
		return true
	end
	return false
end

function Presenter:ForEachVisibleRow(fn)
	if self.scrollList and fn then
		self.scrollList:ForEachFrame(fn)
	end
end

function Presenter:GetSelectedApplicantRowKey()
	return self.selectedApplicantRowKey
end

function Presenter:RefreshSelectedApplicantRows()
	if not self.scrollList then
		return
	end
	self:ForEachVisibleRow(function(card)
		if card and card.members and GF.ApplicantMemberBlock and GF.ApplicantMemberBlock.UpdateSelectedState then
			for _, member in ipairs(card.members) do
				GF.ApplicantMemberBlock:UpdateSelectedState(member)
			end
		end
	end)
end

function Presenter:SetSelectedApplicantRow(row)
	local key = row and row.applicantID and applicantRowKey(row.applicantID, row.memberIdx) or nil
	if self.selectedApplicantRowKey == key then
		self:RefreshSelectedApplicantRows()
		return
	end
	self.selectedApplicantRowKey = key
	self:RefreshSelectedApplicantRows()
end

local function refreshVisibleApplicantAction(card)
	local applicantID = card and card.applicantID
	if not (applicantID and card:IsShown()) then
		return
	end
	local panel = GF.ApplicantsPanel
	local applicant = panel and panel.GetProtectedTerminalApplicantData
		and panel:GetProtectedTerminalApplicantData(applicantID, true)
		or buildApplicantSafely(applicantID)
	if not applicant then
		return
	end
	GF.ApplicantCard:ApplyActionState(card, applicant, card:GetWidth(), card._elementData)
	local acceptButton = card.accept
	local reason = acceptButton and acceptButton._inviteBlockReason
	if reason and acceptButton:IsMouseOver() then
		GF.UI.ShowApplicantBlockTooltip(acceptButton, reason)
	end
end

function Presenter:UpdateInviteState()
	if self.scrollList then
		self:ForEachVisibleRow(refreshVisibleApplicantAction)
	end
end

function Presenter:IsTerminalApplicantDismissed(applicantID, data, authoritativeAppliedEvent)
	local key = applicantIDKey(applicantID)
	local candidate = self:GetApplicantRosterCandidate(applicantID)
	local dismissed = self._dismissedTerminalApplicants
		and self._dismissedTerminalApplicants[key]
	if data == nil and (dismissed or candidate) then
		data = buildApplicantSafely(applicantID)
	end
	if candidate and candidate.phase == "joined"
		and data and data.status == "inviteaccepted"
		and candidate.nativeTerminalPending == true
	then
		-- Capture runs while GetApplicantDisplayData is still assembling this first
		-- authoritative terminal event.  Let it create the lifecycle exactly once;
		-- later duplicate accepted events remain suppressed after NoteTerminal clears
		-- the flag.
		if self._dismissedTerminalApplicants then
			self._dismissedTerminalApplicants[key] = nil
		end
		return false
	end
	if candidate and candidate.phase == "joined" then
		return true
	end
	if data and data.status == "applied" then
		if dismissed ~= nil and authoritativeAppliedEvent ~= true then
			-- GetApplicants()/full refresh can briefly retain the applied snapshot
			-- from any consumed terminal generation.  Only the applicant-specific
			-- event path may authorize reusing this ID after its tombstone.
			return true
		end
		if candidate and candidate.appliedRemovalProbe == true then
			-- A same-ID reapplication can arrive while an old joined tombstone is
			-- still present.  Clear only that obsolete terminal presentation; the
			-- ordinary-member probe must survive until Blizzard's RemoveApplicant
			-- handler and our bounded post-event check have both run.
			self:CancelTerminalApplicantLifecycle(applicantID, true)
		elseif candidate then
			self:ForgetApplicantRosterCandidate(applicantID, true)
		end
		if self._dismissedTerminalApplicants then
			self._dismissedTerminalApplicants[key] = nil
		end
		return false
	end
	if not dismissed then
		return false
	end
	-- Only a new authoritative applied state starts another applicant lifecycle.
	-- Different invited/terminal snapshots can be late events from the consumed ID.
	return true
end

function Presenter:FilterDismissedTerminalApplicantIDs(applicantIDs)
	if not self._dismissedTerminalApplicants
		and not self._applicantRosterCandidates
	then
		return applicantIDs or {}
	end
	local visible = {}
	for _, applicantID in ipairs(applicantIDs or {}) do
		if not self:IsTerminalApplicantDismissed(applicantID) then
			visible[#visible + 1] = applicantID
		end
	end
	return visible
end

function Presenter:RememberInvitedApplicant(applicantID, data)
	local key = applicantIDKey(applicantID)
	if key == "" or isTestApplicantID(applicantID) then
		return
	end
	local dismissed = self._dismissedTerminalApplicants
		and self._dismissedTerminalApplicants[key]
	local rosterCandidate = self:GetApplicantRosterCandidate(applicantID)
	local preserveAppliedRemovalProbe = data and data.status == "applied"
		and lacksApplicantManagementAccess()
		and rosterCandidate and rosterCandidate.appliedRemovalProbe == true
	local strongerRosterTerminal = rosterCandidate
		and rosterCandidate.phase == "joined"
	if data and not preserveAppliedRemovalProbe
		and dismissed == nil
		and (data._gfNativeAvailable ~= false
		or data.status == "invited" or data.status == "inviteaccepted")
	then
		self:CaptureApplicantRosterCandidate(applicantID, data, false)
	end
	if data and data.status == "invited"
		and dismissed == nil and not strongerRosterTerminal
	then
		self._retainedInvitedApplicants =
			self._retainedInvitedApplicants or {}
		self._retainedInvitedApplicants[key] = applicantID
	elseif data and data.status ~= nil and self._retainedInvitedApplicants then
		self._retainedInvitedApplicants[key] = nil
	end
end

function Presenter:MergeRetainedInvitedApplicantIDs(currentIDs, previousIDs)
	local retained = self._retainedInvitedApplicants
	if not retained or next(retained) == nil then
		return currentIDs or {}
	end
	local promotedTerminals = {}
	for key, applicantID in pairs(retained) do
		if self._dismissedTerminalApplicants
			and self._dismissedTerminalApplicants[key] ~= nil
		then
			retained[key] = nil
		else
			local data = buildApplicantSafely(applicantID)
			if data and data.status ~= "invited" then
				retained[key] = nil
				if isTerminalRemovalApplicantData(data) then
					-- GetApplicants() can omit an applicant before the per-applicant
					-- inviteaccepted event is rendered.  Promote the retained invited
					-- row to its readable terminal state instead of dropping it during
					-- this full-refresh merge.
					self.applicantDataCache[key] = data
					promotedTerminals[key] = applicantID
				end
			end
		end
	end
	local currentSet = applicantIDSet(currentIDs)
	local seen = {}
	local merged = {}
	local function append(applicantID)
		local key = applicantIDKey(applicantID)
		if key ~= "" and not seen[key] then
			seen[key] = true
			merged[#merged + 1] = applicantID
		end
	end
	for _, applicantID in ipairs(previousIDs or {}) do
		local key = applicantIDKey(applicantID)
		if currentSet[key] or retained[key] or promotedTerminals[key] then
			append(applicantID)
		end
	end
	for _, applicantID in ipairs(currentIDs or {}) do
		append(applicantID)
	end
	for _, applicantID in pairs(retained) do
		append(applicantID)
	end
	for _, applicantID in pairs(promotedTerminals) do
		append(applicantID)
	end
	return merged
end

function Presenter:StartVisibleTerminalApplicantLifecycles()
	for _, applicantID in ipairs(self.applicantIDs or {}) do
		local key = applicantIDKey(applicantID)
		local data = self.applicantDataCache and self.applicantDataCache[key]
		if data then
			self:RememberInvitedApplicant(applicantID, data)
			if isTerminalRemovalApplicantData(data) then
				self:NoteTerminalApplicant(applicantID, data, false)
			end
		end
	end
end

function Presenter:ClearApplicantTestProjection()
	local nextIDs = {}
	local removedKeys = {}
	local removed = 0
	for _, applicantID in ipairs(self.applicantIDs or {}) do
		local key = applicantIDKey(applicantID)
		local cached = self.applicantDataCache
			and self.applicantDataCache[key]
		if isFixtureApplicantID(applicantID, cached) then
			removed = removed + 1
			removedKeys[key] = true
			self:CancelProviderMissingApplicantCleanup(applicantID)
			self:ClearApplicantAction(applicantID, false)
			self:CancelTerminalApplicantLifecycle(applicantID, true)
			self:ForgetApplicantRosterCandidate(applicantID, false)
			if self._retainedInvitedApplicants then
				self._retainedInvitedApplicants[key] = nil
			end
			if self._dismissedTerminalApplicants then
				self._dismissedTerminalApplicants[key] = nil
			end
			if self.applicantDataCache then
				self.applicantDataCache[key] = nil
			end
			if self.applicantElementCounts then
				self.applicantElementCounts[key] = nil
			end
		else
			nextIDs[#nextIDs + 1] = applicantID
		end
	end
	if removed == 0 then
		return 0
	end
	self.applicantIDs = nextIDs
	self.totalCount = #nextIDs
	if self.selectedApplicantRowKey
		and removedKeys[applicantIDKey(
			selectedApplicantIDFromKey(self.selectedApplicantRowKey))]
	then
		self.selectedApplicantRowKey = nil
	end
	if self.scrollList then
		self:RebuildApplicantElements({ preserveScroll = true })
	end
	return removed
end

function Presenter:RefreshList(opts)
	opts = opts or {}
	if not self.scrollList then
		return
	end
	if presenterHasAuthoritativeListing
		and not presenterHasAuthoritativeListing()
		and not hasEnabledApplicantTestData()
	then
		self:RetireInactiveApplicantSnapshot()
		self:UpdateEmptyHint()
		self:UpdateInviteState()
		return
	end
	local hasTerminalAcknowledgement =
		next(self._terminalApplicantLifecycles or {}) ~= nil
	if hasTerminalAcknowledgement or hasApplicantTransientState(self)
	then
		if opts.forceFull == true then
			self._deferredApplicantFullRefresh = true
		end
		-- Applicant actions can emit synchronous intermediate events.  Do not let
		-- an unrelated full refresh discard their pending/lifecycle state or reset
		-- the viewport while Blizzard is still resolving the affected row.
		self:OnApplicantListUpdated()
		return
	end
	local sortedApplicantIDs, providerReadable =
		GF.ApplicantSnapshotBuilder:GetSortedApplicantIDs()
	if providerReadable ~= true then
		-- A force-full refresh is still only a provider read.  Preserve the current
		-- projection and its ownership state when GetApplicants() fails instead of
		-- normalizing that failure into an authoritative empty list.  A failed
		-- force-full attempt has not consumed the caller's sorting request; retain it
		-- so the next readable applicant/list event can replay the latest order.
		if opts.forceFull == true then
			self._deferredApplicantFullRefresh = true
		end
		self:UpdateInviteState()
		return
	end
	self:ResetApplicantTransientState()
	local previousIDs = self.applicantIDs
	local previousCache = self.applicantDataCache or {}
	self.applicantDataCache = {}
	self.applicantElementCounts = {}
	for key in pairs(self._retainedInvitedApplicants or {}) do
		if previousCache[key] then
			self.applicantDataCache[key] = previousCache[key]
		end
	end
	local currentIDs = self:FilterDismissedTerminalApplicantIDs(
		sortedApplicantIDs)
	self.applicantIDs = self:MergeRetainedInvitedApplicantIDs(
		currentIDs, previousIDs)
	if self.selectedApplicantRowKey
		and not applicantIDInList(self.applicantIDs, selectedApplicantIDFromKey(self.selectedApplicantRowKey))
	then
		self.selectedApplicantRowKey = nil
	end
	self.totalCount = #self.applicantIDs
	self:UpdateEmptyHint()

	if self.totalCount == 0 then
		self.scrollList:SetElements({})
		self._applicantElementsDirty = nil
		if not opts.preserveScroll and self.scrollList.ScrollToBegin then
			self.scrollList:ScrollToBegin()
		end
		self:UpdateInviteState()
		return
	end

	local elements = self:BuildApplicantElements()
	local retainScroll = opts.preserveScroll == true
	self.scrollList:SetElements(elements, { retainScroll = retainScroll })
	self._applicantElementsDirty = nil
	self:StartVisibleTerminalApplicantLifecycles()
	if not retainScroll and self.scrollList.ScrollToBegin then
		self.scrollList:ScrollToBegin()
	end
	self:UpdateInviteState()
end

function Presenter:Refresh(opts)
	opts = opts or {}
	self:UpdateManageState()
	self:RefreshList(opts)
end

function Presenter:ProjectTerminalApplicantFade(data)
	if type(data) ~= "table" then
		return data
	end
	local key = applicantIDKey(data.applicantID)
	local lifecycle = self._terminalApplicantLifecycles
		and self._terminalApplicantLifecycles[key]
	if lifecycle and lifecycle.fadeToken and lifecycle.fadeEndsAt then
		data._gfTerminalFadeToken = lifecycle.fadeToken
		data._gfTerminalFadeSeconds = math.max(
			0.01, lifecycle.fadeEndsAt - now())
	else
		data._gfTerminalFadeToken = nil
		data._gfTerminalFadeSeconds = nil
	end
	return data
end

function Presenter:GetProtectedTerminalApplicantData(applicantID, _forceFresh)
	local key = applicantIDKey(applicantID)
	local cached = self.applicantDataCache and self.applicantDataCache[key]
	local lifecycle = self._terminalApplicantLifecycles
		and self._terminalApplicantLifecycles[key]
	if not (lifecycle and cached and cached.status == lifecycle.status
		and (AUTO_DISMISS_TERMINAL_STATUSES[lifecycle.status] == true
			or lifecycle.nativeMissing == true
			or lifecycle.ackInFlight == true
			or lifecycle.ackSubmitted == true))
	then
		return nil
	end
	-- A confirmed terminal acknowledgement owns its complete visible interval.
	-- Provider-wide and internal forceFresh reads may still expose an older applied
	-- snapshot, but they never authorize a new generation.  Only the precise native
	-- applicant event path records deferredApplied in OnApplicantUpdated().
	return self:ProjectTerminalApplicantFade(cached), lifecycle
end

function Presenter:GetApplicantDisplayData(applicantID, forceFresh)
	local key = applicantIDKey(applicantID)
	if key == "" then
		return nil
	end
	self.applicantDataCache = self.applicantDataCache or {}
	local protectedTerminal = self:GetProtectedTerminalApplicantData(
		applicantID, forceFresh)
	if protectedTerminal then
		return protectedTerminal, false
	end
	local cached = self.applicantDataCache[key]
	local rosterFeedback = self:GetRosterFeedbackApplicantData(applicantID)
	if rosterFeedback then
		-- Roster confirmation can beat Blizzard's applicant removal/update.  Once
		-- the joined acknowledgement has started, a briefly stale applied snapshot
		-- is weaker evidence and must not rotate the lifecycle into a new application.
		self.applicantDataCache[key] = rosterFeedback
		return self:ProjectTerminalApplicantFade(rosterFeedback), false
	end
	if cached and not forceFresh then
		-- Element rebuilds are presentation work. Exact applicant events and explicit
		-- full refreshes own provider reads; rebuilding unchanged rows reuses the
		-- current recruitment-generation snapshot.
		return self:ProjectTerminalApplicantFade(cached), false
	end
	local data = forceFresh and buildApplicantSafely(applicantID) or nil
	if data and data.status == "applied" then
		-- No joined acknowledgement remains for this ID, so a readable applied state
		-- is the authoritative start of a new application generation.
		data._gfNativeAvailable = true
		self:RememberInvitedApplicant(applicantID, data)
		self.applicantDataCache[key] = data
		return self:ProjectTerminalApplicantFade(data), true
	end
	data = data or buildApplicantSafely(applicantID)
	if data then
		data._gfNativeAvailable = true
		self:RememberInvitedApplicant(applicantID, data)
		self.applicantDataCache[key] = data
		return self:ProjectTerminalApplicantFade(data), true
	end
	if cached then
		-- GetApplicantInfo() is documented as MayReturnNothing.  A single unreadable
		-- per-ID snapshot cannot invalidate a row whose provider membership has not
		-- been authoritatively removed; provider-difference cleanup owns that state.
		return self:ProjectTerminalApplicantFade(cached), false
	end
	return nil, false
end

function Presenter:BuildApplicantElements()
	self.applicantElementCounts = self.applicantElementCounts or {}
	return GF.ApplicantsScrollList.BuildElements(self.applicantIDs, function(applicantID)
		local data = self:GetApplicantDisplayData(applicantID)
		self.applicantElementCounts[applicantIDKey(applicantID)] = applicantMemberCount(data)
		return data
	end)
end

function Presenter:IsPresentationVisible()
	local main = GF.MainFrame
	if main and main.IsSurfacePreloadActive
		and main:IsSurfacePreloadActive()
	then
		return false
	end
	local host = self.parent
	if not host then
		return false
	end
	if type(host.IsVisible) == "function" then
		return host:IsVisible() == true
	end
	return type(host.IsShown) == "function" and host:IsShown() == true
end

function Presenter:RebuildApplicantElements(opts)
	opts = opts or {}
	if not self.scrollList then
		return
	end
	self.totalCount = #(self.applicantIDs or {})
	self:UpdateEmptyHint()
	if self.totalCount == 0 then
		self.scrollList:SetElements({})
		self._applicantElementsDirty = nil
		self:UpdateInviteState()
		return
	end
	self.scrollList:SetElements(self:BuildApplicantElements(), {
		retainScroll = opts.preserveScroll == true,
	})
	self._applicantElementsDirty = nil
	self:UpdateInviteState()
end

function Presenter:ApplyApplicantDisplayData(applicantID, data)
	if not self.scrollList or not applicantID or not data then
		return
	end
	local key = applicantIDKey(applicantID)
	data = self:ProjectTerminalApplicantFade(data)
	local previousCount = self.applicantElementCounts and self.applicantElementCounts[key]
	if previousCount and previousCount ~= applicantMemberCount(data) then
		return false
	end
	local width = self.scrollList:GetLayoutWidth()
	local updated = false
	self:ForEachVisibleRow(function(card)
		if card and applicantIDKey(card.applicantID) == key and card:IsShown() then
			GF.ApplicantCard:SetData(card, data, width, card._elementData)
			updated = true
		end
	end)
	if not updated then
		return false
	end
	self.applicantElementCounts = self.applicantElementCounts or {}
	self.applicantElementCounts[key] = applicantMemberCount(data)
	self:UpdateInviteState()
	return true
end

function Presenter:RefreshApplicant(applicantID, forceFresh)
	if not self.scrollList or not applicantID then
		return
	end
	local data = self:GetApplicantDisplayData(applicantID, forceFresh)
	return self:ApplyApplicantDisplayData(applicantID, data)
end

function Presenter:DismissSoftUnavailableApplicant(applicantID)
	local key = applicantIDKey(applicantID)
	local cached = self.applicantDataCache and self.applicantDataCache[key]
	if not (cached and cached._gfSoftUnavailable) then
		return false
	end
	self:CancelProviderMissingApplicantCleanup(applicantID)
	local nextIDs = {}
	for _, id in ipairs(self.applicantIDs or {}) do
		if applicantIDKey(id) ~= key then
			nextIDs[#nextIDs + 1] = id
		end
	end
	self.applicantIDs = nextIDs
	if self.selectedApplicantRowKey and selectedApplicantIDFromKey(self.selectedApplicantRowKey) == key then
		self.selectedApplicantRowKey = nil
	end
	if self.applicantDataCache then
		self.applicantDataCache[key] = nil
	end
	if self.applicantElementCounts then
		self.applicantElementCounts[key] = nil
	end
	self:RebuildApplicantElements({ preserveScroll = true })
	return true
end

function Presenter:DismissSoftUnavailableApplicantRow(row)
	return row and row.applicantID and self:DismissSoftUnavailableApplicant(row.applicantID) or false
end

function Presenter:OnApplicantUpdated(
	applicantID, isAuthoritativeApplicantEvent, prefetchedAuthoritativeData)
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	self:UpdateManageState()
	if not applicantID then
		return
	end
	local key = applicantIDKey(applicantID)
	local cachedBeforeInactiveGuard = self.applicantDataCache
		and self.applicantDataCache[key]
	if presenterHasAuthoritativeListing
		and not presenterHasAuthoritativeListing()
		and not retainsInactiveApplicantFeedback(
			self, applicantID, cachedBeforeInactiveGuard)
	then
		-- Late events from the removed native entry must not reopen an ordinary
		-- applicant row in the unpublished draft.  Existing invited/terminal
		-- continuations remain eligible for their bounded roster/fade resolution.
		return
	end
	local previousData = cloneApplicantData(
		self.applicantDataCache and self.applicantDataCache[key])
	local lifecycle = self._terminalApplicantLifecycles
		and self._terminalApplicantLifecycles[key]
	local dismissedStatus = self._dismissedTerminalApplicants
		and self._dismissedTerminalApplicants[key]
	local authoritativeAppliedEvent = false
	local authoritativeAppliedFallback
	if isAuthoritativeApplicantEvent == true
		and ((lifecycle
			and previousData and previousData.status == lifecycle.status)
			or dismissedStatus ~= nil)
	then
		-- Bootstrap originates this authority only from the explicit
		-- LFG_LIST_APPLICANT_UPDATED(applicantID) path; deferred restoration merely
		-- forwards that recorded evidence.  A readable applied status there is the
		-- next generation for a reused applicant ID.  Preserve the old terminal
		-- acknowledgement through its full visible lifetime, then reopen exactly once.
		local authoritativeData = buildApplicantSafely(applicantID)
		if authoritativeData and authoritativeData.status == "applied" then
			authoritativeAppliedEvent = true
			if lifecycle then
				lifecycle.deferredApplied = true
				lifecycle.deferredApplicantData =
					cloneApplicantData(authoritativeData)
				if lifecycle.nativeMissing ~= true then
					lifecycle.nativeMissing = true
					lifecycle.dismissAfterRemoval = true
					if not lifecycle.removalTimer and not lifecycle.fadeTimer then
						lifecycle.removalTimer = scheduleTimer(0, function()
							self:StartTerminalApplicantRemoval(
								applicantID, lifecycle)
						end)
					end
				end
			elseif self._dismissedTerminalApplicants then
				-- The old feedback already finished.  Consume its tombstone as soon as
				-- this event proves a new applied generation, so the normal projection
				-- read may carry a status that advanced later in the same event stack.
				-- Keep this exact-event snapshot as a fallback because both later reads
				-- may legally return nothing; a newer readable status still wins below.
				authoritativeAppliedFallback =
					cloneApplicantData(authoritativeData)
				self._dismissedTerminalApplicants[key] = nil
			end
		elseif lifecycle and lifecycle.deferredApplied == true
			and authoritativeData
			and type(authoritativeData.status) == "string"
			and authoritativeData.status ~= ""
		then
			-- Once applied has authorized the new generation, later precise events may
			-- advance it before the old feedback ends.  Retain the latest readable
			-- snapshot as a one-read fallback for terminal removal time.
			lifecycle.deferredApplicantData =
				cloneApplicantData(authoritativeData)
		end
	end
	local pending = self:GetApplicantActionPending(applicantID)
	local hasAuthorizedApplicantData = isAuthoritativeApplicantEvent == true
		or type(prefetchedAuthoritativeData) == "table"
	local data, perIDReadable
	if type(prefetchedAuthoritativeData) == "table" then
		data = cloneApplicantData(prefetchedAuthoritativeData)
		perIDReadable = true
		data._gfNativeAvailable = true
		self.applicantDataCache = self.applicantDataCache or {}
		self.applicantDataCache[key] = data
	else
		data, perIDReadable = self:GetApplicantDisplayData(applicantID, true)
		if perIDReadable ~= true and not data
			and type(authoritativeAppliedFallback) == "table"
		then
			data = authoritativeAppliedFallback
			data._gfNativeAvailable = true
			perIDReadable = true
			self.applicantDataCache = self.applicantDataCache or {}
			self.applicantDataCache[key] = data
		end
	end
	if isAuthoritativeApplicantEvent == true
		and perIDReadable ~= true
		and data and data.status == "applied"
	then
		local builder = GF.ApplicantSnapshotBuilder
		local currentIDs, providerReadable
		if builder and type(builder.GetSortedApplicantIDs) == "function" then
			currentIDs, providerReadable = builder:GetSortedApplicantIDs()
		end
		if providerReadable == true
			and not applicantIDInList(currentIDs, applicantID)
		then
			local intent = self:GetApplicantActionIntent(applicantID)
			if intent and intent.action == "decline"
				and intent.submitted == true
			then
				self:ScheduleSubmittedDeclineProviderCheck(
					applicantID, true)
			else
				self:ScheduleProviderMissingApplicantCleanup(
					applicantID, true)
			end
		elseif providerReadable ~= true then
			-- The precise event did not yield a per-ID snapshot and provider membership
			-- is also unreadable.  Keep the cached row and schedule evidence re-reading.
			self:ScheduleProviderMissingApplicantCleanup(
				applicantID, false, true)
		end
	end
	local providerGapCleanup = self._providerMissingApplicantCleanups
		and self._providerMissingApplicantCleanups[key]
	if isAuthoritativeApplicantEvent == true
		and perIDReadable == true
		and providerGapCleanup ~= nil
		and data and data.status == "applied"
		and not hasNativePendingStatus(data)
		and not hasNativeApplicantInfo(data)
	then
		-- A precise, clean applied event after an observed provider gap resolves the
		-- old submitted action.  It may be a failed old decline or a reused-ID new
		-- generation; either way the old spinner/provenance cannot own this row.
		self:CancelProviderMissingApplicantCleanup(applicantID)
		self:ClearApplicantAction(applicantID, false)
		pending = nil
	end
	local rosterCandidate = self:GetApplicantRosterCandidate(applicantID)
	local ordinaryAppliedEvent = hasAuthorizedApplicantData
		and lacksApplicantManagementAccess()
		and ((data and data._gfNativeAvailable == true
				and data.status == "applied")
			or (previousData and previousData.status == "applied"))
	if ordinaryAppliedEvent then
		local appliedData = data and data._gfNativeAvailable == true
			and data.status == "applied" and data or previousData
		rosterCandidate = self:CaptureApplicantRosterCandidate(
			applicantID, appliedData, true) or rosterCandidate
	end
	if (not data or data._gfNativeAvailable ~= true) and previousData
		and (previousData.status == "applied" or previousData.status == "invited")
		and (previousData.status ~= "applied"
			or (hasAuthorizedApplicantData and lacksApplicantManagementAccess()))
	then
		rosterCandidate = self:CaptureApplicantRosterCandidate(
			applicantID,
			previousData,
			previousData.status == "applied"
		)
	end
	if rosterCandidate and (ordinaryAppliedEvent
		or not data or data._gfNativeAvailable ~= true
		or data.status == "invited")
	then
		self:ScheduleApplicantPostEventRecheck(rosterCandidate)
	end
	self:RememberInvitedApplicant(applicantID, data)
	if self:IsTerminalApplicantDismissed(
		applicantID, data, authoritativeAppliedEvent)
	then
		self:RunDeferredApplicantFullRefreshIfReady()
		return
	end
	if isTerminalRemovalApplicantData(data) then
		self:NoteTerminalApplicant(applicantID, data)
	elseif applicantActionHasResolved(data) then
		self:CancelTerminalApplicantLifecycle(applicantID, true)
		self:ClearApplicantAction(applicantID, false)
	elseif not pending and data and data._gfSoftUnavailable then
		self:CancelTerminalApplicantLifecycle(applicantID, true)
		self:ClearApplicantAction(applicantID, false)
	elseif not pending and data and data.status == "applied"
		and not hasNativePendingStatus(data)
	then
		self:ClearApplicantActionIntent(applicantID)
	end
	if not applicantIDInList(self.applicantIDs, applicantID) then
		if not data then
			self:RunDeferredApplicantFullRefreshIfReady()
			return
		end
		self.applicantIDs = self.applicantIDs or {}
		self.applicantIDs[#self.applicantIDs + 1] = applicantID
		if self:IsPresentationVisible() then
			self:RebuildApplicantElements({ preserveScroll = true })
		else
			self._applicantElementsDirty = true
			self:UpdateInviteState()
		end
		self:RunDeferredApplicantFullRefreshIfReady()
		return
	end
	if not self:IsPresentationVisible() then
		self._applicantElementsDirty = true
		self:UpdateInviteState()
		self:RunDeferredApplicantFullRefreshIfReady()
		return
	end
	if not self:RefreshApplicant(applicantID, false) then
		local previousCount = self.applicantElementCounts and self.applicantElementCounts[key]
		if data and previousCount and previousCount ~= applicantMemberCount(data) then
			self:RebuildApplicantElements({ preserveScroll = true })
		else
			self:UpdateInviteState()
		end
	end
	self:RunDeferredApplicantFullRefreshIfReady()
end

function Presenter:OnApplicantListUpdated(opts)
	opts = opts or {}
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	self:UpdateManageState()
	if not self.scrollList then
		return
	end
	if presenterHasAuthoritativeListing
		and not presenterHasAuthoritativeListing()
		and not hasEnabledApplicantTestData()
	then
		self:RetireInactiveApplicantSnapshot()
		self:UpdateEmptyHint()
		self:UpdateInviteState()
		return
	end
	self.applicantIDs = self.applicantIDs or {}
	self.applicantDataCache = self.applicantDataCache or {}
	local model = GF.ApplicantSnapshotBuilder
	local currentApplicantIDs, providerReadable
	if model and type(model.GetApplicantIDs) == "function" then
		currentApplicantIDs, providerReadable = model:GetApplicantIDs()
	else
		currentApplicantIDs, providerReadable = model:GetSortedApplicantIDs()
	end
	if providerReadable ~= true then
		-- A failed provider read is not an empty provider snapshot.  Preserve the
		-- current projection until a later readable applicant/list event.
		self:UpdateInviteState()
		return
	end
	local currentIDs = self:FilterDismissedTerminalApplicantIDs(
		currentApplicantIDs)
	local currentSet = applicantIDSet(currentIDs)
	local previousSet = applicantIDSet(self.applicantIDs)
	local nextIDs = {}
	local needsRebuild = false
	for _, applicantID in ipairs(self.applicantIDs) do
		local key = applicantIDKey(applicantID)
		if currentSet[key] then
			self:CancelProviderMissingApplicantCleanup(applicantID)
			nextIDs[#nextIDs + 1] = applicantID
			-- List-wide events own membership only. Exact applicant events own
			-- status/member refreshes, so surviving rows keep their cache, lifecycle,
			-- order and viewport without another applicant/member API scan.
		elseif self.applicantDataCache[key] then
			nextIDs[#nextIDs + 1] = applicantID
			if opts.preserveMissing ~= true then
				local intent = self:GetApplicantActionIntent(applicantID)
				if intent and intent.action == "decline"
					and intent.submitted == true
				then
					self:ScheduleSubmittedDeclineProviderCheck(
						applicantID, providerReadable)
				else
					self:ScheduleProviderMissingApplicantCleanup(
						applicantID, providerReadable)
				end
				local data = self.applicantDataCache[key]
				local protectedTerminal = self:GetProtectedTerminalApplicantData(
					applicantID, true)
				local rosterFeedback = not protectedTerminal
					and self:GetRosterFeedbackApplicantData(applicantID) or nil
				local freshData = not protectedTerminal
					and (rosterFeedback or buildApplicantSafely(applicantID)) or nil
				if protectedTerminal then
					data = protectedTerminal
				elseif freshData then
					if not rosterFeedback then
						freshData._gfNativeAvailable = true
					end
					data = freshData
					self.applicantDataCache[key] = freshData
					self:RememberInvitedApplicant(applicantID, freshData)
				elseif data and data.status == "invited" then
					local candidate = self:CaptureApplicantRosterCandidate(
						applicantID, data, false)
					self:ScheduleApplicantPostEventRecheck(candidate)
					self:ScheduleRosterCandidateResolution(candidate)
				end
				local pending = self:GetApplicantActionPending(applicantID)
				local lifecycle = self._terminalApplicantLifecycles
					and self._terminalApplicantLifecycles[key]
				local skipRefresh = false
				if isTerminalRemovalApplicantData(data) then
					local _, terminalLifecycle = self:NoteTerminalApplicant(
						applicantID, data, true)
					skipRefresh = terminalLifecycle
						and terminalLifecycle.fadeTimer ~= nil
				elseif freshData then
					self:CancelTerminalApplicantLifecycle(applicantID, true)
					if applicantActionHasResolved(freshData) then
						self:ClearApplicantAction(applicantID, false)
					end
				elseif lifecycle then
					self:CancelTerminalApplicantLifecycle(applicantID, true)
					self:ClearApplicantAction(applicantID, false)
					markApplicantDataUnavailable(data)
				elseif pending or hasNativePendingStatus(data) then
					-- GetApplicants() may temporarily omit the row while either native
					-- action is pending. A local token is only an interaction gate, while
					-- pendingApplicationStatus remains native unresolved evidence. Neither
					-- can prove invited/declined; keep the cached row until a per-applicant
					-- event re-reads applicationStatus (or the local-only gate expires).
					data._gfSoftUnavailable = nil
				else
					self:ClearApplicantAction(applicantID, false)
					markApplicantDataUnavailable(data)
				end
				if not skipRefresh then
					self:ApplyApplicantDisplayData(applicantID, data)
				end
			end
		else
			needsRebuild = true
		end
	end
	for _, applicantID in ipairs(currentIDs) do
		if not previousSet[applicantIDKey(applicantID)] then
			self:CancelProviderMissingApplicantCleanup(applicantID)
			self:CancelTerminalApplicantLifecycle(applicantID, true)
			nextIDs[#nextIDs + 1] = applicantID
			local data = self:GetApplicantDisplayData(applicantID, true)
			self:RememberInvitedApplicant(applicantID, data)
			needsRebuild = true
		end
	end
	local previousVisibleCount = #(self.applicantIDs or {})
	self.applicantIDs = nextIDs
	self.totalCount = #nextIDs
	if self.selectedApplicantRowKey
		and not applicantIDInList(self.applicantIDs, selectedApplicantIDFromKey(self.selectedApplicantRowKey))
	then
		self.selectedApplicantRowKey = nil
	end
	self:UpdateEmptyHint()
	if needsRebuild or previousVisibleCount ~= #nextIDs then
		if self:IsPresentationVisible() then
			self:RebuildApplicantElements({ preserveScroll = true })
		else
			self._applicantElementsDirty = true
			self:UpdateInviteState()
		end
	else
		self:UpdateInviteState()
	end
	self:RunDeferredApplicantFullRefreshIfReady()
end

function Presenter:CancelListingLossCleanup()
	local timer = self._listingLossCleanupTimer
	self._listingLossCleanupTimer = nil
	cancelTimer(timer)
end

function Presenter:ScheduleListingLossCleanup()
	if self._listingLossCleanupTimer then
		return
	end
	self._listingLossCleanupTimer = scheduleTimer(
		LISTING_LOSS_INVITE_GRACE_SECONDS,
			function()
				self._listingLossCleanupTimer = nil
				local hasListing = presenterHasActiveListing()
				if hasListing then
					return
				end
				-- Both this grace and the ordinary-member fallback use one second.
				-- Resolve the latest roster snapshot before pruning unresolved entries so
				-- timer registration order cannot discard a just-joined applicant.
				self:ReconcileApplicantRosterState()
				local terminals = self._terminalApplicantLifecycles or {}
				if next(terminals) ~= nil then
					for _, lifecycle in pairs(terminals) do
						lifecycle.dismissAfterRemoval = true
						if lifecycle.nativeMissing ~= true then
							lifecycle.nativeMissing = true
							if not lifecycle.removalTimer and not lifecycle.fadeTimer then
								local pendingLifecycle = lifecycle
								lifecycle.removalTimer = scheduleTimer(0, function()
									self:StartTerminalApplicantRemoval(
										pendingLifecycle.applicantID, pendingLifecycle)
								end)
							end
						end
					end
					-- Let the existing 0.8s acknowledgement and 0.16s fade finish;
					-- the next pass performs non-terminal cleanup after the acknowledgement.
					self:ScheduleListingLossCleanup()
					return
				end
				-- The one-second grace only owns unresolved applicant event ordering.
				-- Completed joined acknowledgements release their roster candidates;
				-- later departures cannot re-enter the applicant workflow.
				self:ResetApplicantTransientState()
				self:PruneUnresolvedApplicantRosterCandidates()
				self._retainedInvitedApplicants = nil
				if self.scrollList then
					self:RefreshList({ forceFull = true, preserveScroll = true })
				end
			end
	)
end


presenterHasAuthoritativeListing = function()
	local listing = GF.RecruitmentSession
	return listing and type(listing.HasActive) == "function"
		and listing:HasActive() == true or false
end

presenterHasActiveListing = function()
	local listing = GF.RecruitmentSession
	local presentation = listing and listing.GetActiveCensoredPresentationState
		and listing:GetActiveCensoredPresentationState()
	if presentation and presentation.preview == true then
		return true
	end
	if listing and type(listing.IsRelisting) == "function"
		and listing:IsRelisting() == true
	then
		return true
	end
	return presenterHasAuthoritativeListing()
end

local function actionElementMetrics(elementData)
	local size = math.max(1, tonumber(elementData and elementData.groupSize) or 1)
	local index = math.max(1, tonumber(elementData and elementData.groupIndex)
		or tonumber(elementData and elementData.memberIdx) or 1)
	local actionIndex = math.max(1,
		tonumber(elementData and elementData.groupActionIndex)
		or math.ceil(size / 2))
	return size, index, actionIndex
end

local function isTestSnapshot(data)
	if type(data) ~= "table" then
		return false
	end
	if data.isTest == true or data.isDebugTest == true then
		return true
	end
	return isTestApplicantID(data.applicantID)
end

-- Returns an ordinary GF-owned value object. Card rendering never has to infer
-- action permission, status visibility, or group-button placement on its own.
function Presenter.ProjectActionState(view, data, elementData)
	if type(data) ~= "table" then
		return nil
	end
	local size, index, actionIndex = actionElementMetrics(elementData)
	local showControls = size == 1 or index == actionIndex
	local pending = view and type(view.IsApplicantActionPending) == "function"
		and view:IsApplicantActionPending(data.applicantID) == true
	local loading = data.loading == true or pending
	local listing = GF.RecruitmentSession
	local canManage = listing and type(listing.CanManageApplicants) == "function"
		and listing:CanManageApplicants() == true
	local actions = GF.ApplicantActionService
	local inviteBlockReason
	if not isTestSnapshot(data)
		and actions and type(actions.EvaluateInvite) == "function"
	then
		inviteBlockReason = actions:EvaluateInvite(data.applicantID)
	end
	local permissionBlocked = showControls and canManage ~= true
	local locale = GF.L or {}
	local isGroup = size > 1
	local showInvite = showControls and data.showInvite == true and not loading
	local showDecline = showControls and data.showDecline == true and not loading
	local showView = not loading and data.statusText == nil
		and (data.showInvite == true or data.showDecline == true)
	return {
		showControls = showControls,
		loading = loading,
		showSpinner = showControls and loading,
		showInvite = showInvite,
		showDecline = showDecline,
		showView = showView,
		showStatus = showControls and data.statusText ~= nil and not loading,
		statusText = data.statusText,
		statusColor = data.statusColor,
		inviteEnabled = showControls and canManage
			and data.canInvite == true and not loading,
		declineEnabled = showControls and canManage
			and data.canDecline == true and not loading,
		inviteBlockReason = permissionBlocked and "unempowered"
			or inviteBlockReason,
		declineBlockReason = permissionBlocked and "unempowered" or nil,
		inviteTooltip = not permissionBlocked and (isGroup
			and (locale.APPLICANT_GROUP_INVITE or "整队邀请")
			or (locale.APPLICANT_INVITE or locale.ACCEPT or "邀请")) or nil,
		declineTooltip = not permissionBlocked and (isGroup
			and (locale.APPLICANT_GROUP_DECLINE or "整队拒绝")
			or (locale.APPLICANT_DECLINE or locale.DECLINE or "拒绝")) or nil,
	}
end

-- Owns the click transaction and preserves local submitted provenance across a
-- synchronous Blizzard list event. The card only emits an intent.
function Presenter.SubmitApplicantAction(view, data, action, options)
	if type(view) ~= "table" or type(data) ~= "table" then
		return false, "missing"
	end
	if isTestSnapshot(data) then
		if type(view.Refresh) == "function" then
			view:Refresh({ preserveScroll = true })
		end
		return false, "test_data"
	end
	local service = GF.ApplicantActionService
	if not service then
		return false, "no_service"
	end
	if action == "invite" then
		view:BeginApplicantAction(data.applicantID, "invite")
		local accepted, outcome = service:Accept(data.applicantID)
		if not accepted or outcome == "raid_conversion_popup" then
			view:ClearApplicantAction(data.applicantID, true)
		end
		return accepted == true, outcome
	end
	if action ~= "decline" then
		return false, "invalid_action"
	end
	view:BeginApplicantAction(data.applicantID, "decline")
	local declined, outcome, terminalStatus = service:Decline(data.applicantID, options)
	if declined and outcome == "decline_submitted" then
		view:MarkApplicantActionSubmitted(data.applicantID, "decline")
	elseif declined and outcome == "terminal_observed" then
		local projected = view:NoteObservedTerminalApplicant(
			data.applicantID, terminalStatus)
		if not projected then
			view:ClearApplicantAction(data.applicantID, false)
			view:OnApplicantListUpdated()
		end
	end
	local listing = GF.RecruitmentSession
	local canManage = listing and type(listing.CanManageApplicants) == "function"
		and listing:CanManageApplicants() == true
	if not declined and not canManage
		and type(service.NotifyBlocked) == "function"
	then
		service:NotifyBlocked("unempowered")
	end
	if not declined then
		view:ClearApplicantAction(data.applicantID, true)
	end
	return declined == true, outcome
end

function Presenter.GetMemberMenuName(row)
	local memberData = row and row._layoutMemberData
	if memberData and type(memberData.name) == "string"
		and memberData.name ~= ""
	then
		return memberData.name
	end
	local actions = GF.ApplicantActionService
	local snapshots = GF.ApplicantSnapshotBuilder
	if not (row and row.applicantID and row.memberIdx
		and actions and type(actions.GetApplicantInfo) == "function"
		and snapshots and type(snapshots.BuildMember) == "function")
	then
		return nil
	end
	local application = actions:GetApplicantInfo(row.applicantID)
	if not application then
		return nil
	end
	local ok, snapshot = pcall(
		snapshots.BuildMember,
		snapshots,
		row.applicantID,
		row.memberIdx,
		application,
		nil)
	return ok and snapshot and snapshot.name ~= "" and snapshot.name or nil
end

local function resolveMemberCharacterInfo(row)
	local name = Presenter.GetMemberMenuName(row)
	local characterInfo = GF.ApplicantCharacterInfo
	if type(name) ~= "string" or name == ""
		or type(characterInfo) ~= "table"
		or type(characterInfo.BuildLinks) ~= "function"
		or type(characterInfo.Open) ~= "function"
	then
		return nil
	end
	local ok, links = pcall(characterInfo.BuildLinks, characterInfo, name)
	if not ok or type(links) ~= "table" then
		return nil
	end
	return characterInfo, name, links, row and row._layoutMemberData or nil
end

function Presenter.CanOpenMemberCharacterInfo(row)
	return resolveMemberCharacterInfo(row) ~= nil
end

function Presenter.OpenMemberCharacterInfo(row)
	local characterInfo, name, links, memberData =
		resolveMemberCharacterInfo(row)
	if not characterInfo then
		return false
	end
	local ok = pcall(
		characterInfo.Open,
		characterInfo,
		name,
		links,
		memberData)
	return ok == true
end

function Presenter.AssignMemberRole(applicantID, memberIndex, role)
	if applicantID == nil or tonumber(memberIndex) == nil
		or type(role) ~= "string" or role == ""
	then
		return false
	end
	local actions = GF.ApplicantActionService
	if not (actions and type(actions.AssignMemberRole) == "function") then
		return false
	end
	return actions:AssignMemberRole(applicantID, memberIndex, role) == true
end

function Presenter.GetActiveActivityInfo(activeInfo, activityID)
	local snapshot = GF.SearchResultSnapshot
	if not (snapshot and type(snapshot.GetActivityInfo) == "function") then
		return nil
	end
	return snapshot.GetActivityInfo(activeInfo, activityID)
end

function Presenter.IsRowSelected(view, row)
	if not (view and row and row.applicantID and row.memberIdx
		and type(view.GetSelectedApplicantRowKey) == "function")
	then
		return false
	end
	return view:GetSelectedApplicantRowKey()
		== applicantRowKey(row.applicantID, row.memberIdx)
end

function Presenter.HandleRowMouseDown(view, row)
	if not (view and row) then
		return false
	end
	if type(view.DismissSoftUnavailableApplicantRow) == "function"
		and view:DismissSoftUnavailableApplicantRow(row)
	then
		return true
	end
	if type(view.SetSelectedApplicantRow) == "function" then
		view:SetSelectedApplicantRow(row)
	end
	return false
end

local COMPATIBILITY_METHODS = {
	"ResetApplicantRemovalFades",
	"GetApplicantActionPending",
	"IsApplicantActionPending",
	"GetApplicantActionIntent",
	"ClearApplicantActionIntent",
	"ClearApplicantAction",
	"BeginApplicantAction",
	"MarkApplicantActionSubmitted",
	"CancelTerminalApplicantLifecycle",
	"RemoveTerminalApplicant",
	"StartTerminalApplicantRemoval",
	"ScheduleTerminalApplicantAcknowledgementRetry",
	"NoteTerminalApplicant",
	"ResetApplicantTransientState",
	"RunDeferredApplicantFullRefreshIfReady",
	"NoteObservedTerminalApplicant",
	"CancelProviderMissingApplicantCleanup",
	"RemoveProviderMissingApplicant",
	"ScheduleProviderMissingApplicantCleanup",
	"ScheduleSubmittedDeclineProviderCheck",
	"ConfirmLocalDeclineAfterProviderRemoval",
	"EnsureApplicantRosterSession",
	"GetApplicantRosterCandidate",
	"ForgetApplicantRosterCandidate",
	"ResetApplicantRosterSession",
	"PruneUnresolvedApplicantRosterCandidates",
	"ResetForNewApplicantSession",
	"RetireInactiveApplicantSnapshot",
	"CaptureApplicantRosterCandidate",
	"GetRosterFeedbackApplicantData",
	"EnsureRosterCandidateApplicantID",
	"RemoveRosterCandidateApplicantRow",
	"HideUnresolvedRosterCandidate",
	"ScheduleRosterCandidateResolution",
	"ScheduleApplicantPostEventRecheck",
	"ProjectRosterApplicantJoined",
	"ReconcileApplicantRosterState",
	"OnGroupRosterChanged",
	"OnGroupLeft",
	"ForEachVisibleRow",
	"GetSelectedApplicantRowKey",
	"RefreshSelectedApplicantRows",
	"SetSelectedApplicantRow",
	"UpdateInviteState",
	"IsTerminalApplicantDismissed",
	"FilterDismissedTerminalApplicantIDs",
	"RememberInvitedApplicant",
	"MergeRetainedInvitedApplicantIDs",
	"StartVisibleTerminalApplicantLifecycles",
	"ClearApplicantTestProjection",
	"RefreshList",
	"Refresh",
	"ProjectTerminalApplicantFade",
	"GetProtectedTerminalApplicantData",
	"GetApplicantDisplayData",
	"BuildApplicantElements",
	"IsPresentationVisible",
	"RebuildApplicantElements",
	"ApplyApplicantDisplayData",
	"RefreshApplicant",
	"DismissSoftUnavailableApplicant",
	"DismissSoftUnavailableApplicantRow",
	"OnApplicantUpdated",
	"OnApplicantListUpdated",
	"CancelListingLossCleanup",
	"ScheduleListingLossCleanup",
}

function Presenter.Attach(view)
	if type(view) ~= "table" then
		return nil
	end
	for _, methodName in ipairs(COMPATIBILITY_METHODS) do
		view[methodName] = Presenter[methodName]
	end
	view._applicantRosterPresenter = Presenter
	return view
end
