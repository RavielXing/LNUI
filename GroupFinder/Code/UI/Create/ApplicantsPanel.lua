local _, GF = ...

local ApplicantsPanel = {}
GF.ApplicantsPanel = ApplicantsPanel
local AP = ApplicantsPanel
local ASL = GF.ApplicantsScrollList

local HEADER_H = GF.SUBTITLE_HEADER_H or 22
local FOOTER_H = GF.SUBTITLE_H or 42
local GAP = GF.SUBTITLE_CONTROL_GAP or 7
local LEFT_PAD = GF.SUBTITLE_CONTROL_LEFT_PAD or 15
local RIGHT_PAD = GF.SUBTITLE_CONTROL_RIGHT_PAD or 10
local MANAGE_BUTTON_W = GF.APPLICANT_MANAGE_BUTTON_W or GF.PANEL_BUTTON_TWO_CHAR_W or 72
local ROLE_SUMMARY_W = GF.APPLICANT_ACTIVE_ROLE_SUMMARY_W or 168
local ROLE_SUMMARY_X = GF.APPLICANT_ACTIVE_ROLE_SUMMARY_X or 0
local ROLE_SUMMARY_H = GF.FRAME_BODY_BOTTOM or 41
local HEADER_REFRESH_TEXTURE = GF.BROWSE_HEADER_REFRESH_TEXTURE or GF.REFRESH_TEXTURE
local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE
local TERMINAL_MIN_VISIBLE_SECONDS = GF.APPLICANT_DECLINED_MIN_VISIBLE_SECONDS or 0.8
local TERMINAL_FADE_SECONDS = GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS or 0.16
local TERMINAL_TIMER_EPSILON_SECONDS = 0.001
local ACTION_PENDING_TIMEOUT_SECONDS = GF.APPLICANT_ACTION_PENDING_TIMEOUT_SECONDS or 3
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

function AP:ResetApplicantRemovalFades(applicantID)
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

function AP:GetApplicantActionPending(applicantID)
	local key = applicantIDKey(applicantID)
	return self._pendingApplicantActions and self._pendingApplicantActions[key] or nil
end

function AP:IsApplicantActionPending(applicantID)
	return self:GetApplicantActionPending(applicantID) ~= nil
end

function AP:GetApplicantActionIntent(applicantID)
	local key = applicantIDKey(applicantID)
	return self._applicantActionIntents
		and self._applicantActionIntents[key] or nil
end

function AP:ClearApplicantActionIntent(applicantID)
	local key = applicantIDKey(applicantID)
	local intents = self._applicantActionIntents
	if not (intents and intents[key]) then
		return false
	end
	intents[key] = nil
	return true
end

function AP:ClearApplicantAction(applicantID, refresh)
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

function AP:BeginApplicantAction(applicantID, action)
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
	pending.timer = scheduleTimer(ACTION_PENDING_TIMEOUT_SECONDS, function()
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

function AP:MarkApplicantActionSubmitted(applicantID, action)
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

function AP:CancelTerminalApplicantLifecycle(applicantID, resetVisual)
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

function AP:RemoveTerminalApplicant(applicantID, lifecycle)
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

function AP:StartTerminalApplicantRemoval(applicantID, lifecycle)
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

function AP:ScheduleTerminalApplicantAcknowledgementRetry(
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

function AP:NoteTerminalApplicant(applicantID, data, nativeMissing)
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

function AP:ResetApplicantTransientState()
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

function AP:RunDeferredApplicantFullRefreshIfReady()
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

function AP:NoteObservedTerminalApplicant(applicantID, status)
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

function AP:CancelProviderMissingApplicantCleanup(applicantID)
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

function AP:RemoveProviderMissingApplicant(applicantID, cleanup)
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

function AP:ScheduleProviderMissingApplicantCleanup(
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

function AP:ScheduleSubmittedDeclineProviderCheck(applicantID, providerReadable)
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
		0, PROVIDER_MISSING_GRACE_SECONDS - math.max(0, now() - submittedAt))
	cleanup.timer = scheduleTimer(remaining, function()
		self:RemoveProviderMissingApplicant(applicantID, cleanup)
	end)
	return cleanup
end

function AP:ConfirmLocalDeclineAfterProviderRemoval(applicantID, providerReadable)
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

function AP:EnsureApplicantRosterSession()
	if not self._applicantRosterSessionToken then
		self._applicantRosterSessionToken = {}
	end
	self._applicantRosterCandidates = self._applicantRosterCandidates or {}
	return self._applicantRosterSessionToken, self._applicantRosterCandidates
end

function AP:GetApplicantRosterCandidate(applicantID)
	local key = applicantIDKey(applicantID)
	local candidate = self._applicantRosterCandidates
		and self._applicantRosterCandidates[key]
	if candidate and candidate.sessionToken == self._applicantRosterSessionToken then
		return candidate
	end
	return nil
end

function AP:ForgetApplicantRosterCandidate(applicantID, releaseTerminal)
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

function AP:ResetApplicantRosterSession()
	cancelTimer(self._applicantRosterRecheckTimer)
	self._applicantRosterRecheckTimer = nil
	for _, candidate in pairs(self._applicantRosterCandidates or {}) do
		cancelRosterCandidateTimers(candidate)
	end
	self._applicantRosterSessionToken = {}
	self._applicantRosterCandidates = {}
end

function AP:PruneUnresolvedApplicantRosterCandidates()
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

function AP:ResetForNewApplicantSession()
	self:CancelListingLossCleanup()
	self:ResetApplicantTransientState()
	self:ResetApplicantRosterSession()
	self._retainedInvitedApplicants = nil
	self._dismissedTerminalApplicants = nil
	self.applicantIDs = {}
	self.applicantDataCache = {}
	self.applicantElementCounts = {}
	self.totalCount = 0
	if self.scrollList then
		self:RebuildApplicantElements({ preserveScroll = true })
	end
end

function AP:CaptureApplicantRosterCandidate(applicantID, data, allowApplied)
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

function AP:GetRosterFeedbackApplicantData(applicantID)
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

function AP:EnsureRosterCandidateApplicantID(candidate)
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

function AP:RemoveRosterCandidateApplicantRow(candidate)
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

function AP:HideUnresolvedRosterCandidate(candidate)
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

function AP:ScheduleRosterCandidateResolution(candidate)
	if not candidate or candidate.resolveTimer
		or candidate.phase == "joined"
	then
		return
	end
	local sessionToken = candidate.sessionToken
	candidate.resolveTimer = scheduleTimer(ROSTER_RESOLUTION_SECONDS, function()
		candidate.resolveTimer = nil
		if sessionToken ~= AP._applicantRosterSessionToken
			or AP:GetApplicantRosterCandidate(candidate.applicantID) ~= candidate
		then
			return
		end
		AP:ReconcileApplicantRosterState()
		if candidate.phase == "joined" then
			return
		end
		local data = buildApplicantSafely(candidate.applicantID)
		if data then
			if data.status == "applied" then
				-- The native applicant survived the ordinary-member event pass, so
				-- there is no disappearance for roster compensation to explain.
				-- Drop only the speculative candidate and leave the live row intact.
				AP:ForgetApplicantRosterCandidate(candidate.applicantID, false)
				return
			end
			if data.status == "invited" then
				-- Native applicant events and roster events will wake this candidate.
				-- A readable, unchanged invitation is not a reason to poll forever.
				return
			end
			AP:OnApplicantUpdated(candidate.applicantID)
			return
		end
		AP:HideUnresolvedRosterCandidate(candidate)
		AP:ForgetApplicantRosterCandidate(candidate.applicantID, false)
	end)
end

function AP:ScheduleApplicantPostEventRecheck(candidate)
	if not candidate or candidate.phase == "joined" then
		return
	end
	cancelTimer(candidate.postEventTimer)
	local sessionToken = candidate.sessionToken
	candidate.postEventTimer = scheduleTimer(0, function()
		candidate.postEventTimer = nil
		if sessionToken ~= AP._applicantRosterSessionToken
			or AP:GetApplicantRosterCandidate(candidate.applicantID) ~= candidate
		then
			return
		end
		AP:ReconcileApplicantRosterState()
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
				AP:ScheduleRosterCandidateResolution(candidate)
				return
			end
			if data.status ~= "invited" then
				AP:OnApplicantUpdated(candidate.applicantID)
				return
			end
			local refreshed = AP:CaptureApplicantRosterCandidate(
				candidate.applicantID, data, false)
			AP:ScheduleRosterCandidateResolution(refreshed or candidate)
			return
		end
		AP:ScheduleRosterCandidateResolution(candidate)
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

function AP:ProjectRosterApplicantJoined(candidate)
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
		self:RebuildApplicantElements({ preserveScroll = true })
	end
	return true
end

function AP:ReconcileApplicantRosterState()
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

function AP:OnGroupRosterChanged()
	self:ReconcileApplicantRosterState()
	cancelTimer(self._applicantRosterRecheckTimer)
	local sessionToken = self._applicantRosterSessionToken
	self._applicantRosterRecheckTimer = scheduleTimer(0, function()
		AP._applicantRosterRecheckTimer = nil
		if sessionToken == AP._applicantRosterSessionToken then
			AP:ReconcileApplicantRosterState()
		end
	end)
end

function AP:OnGroupLeft(category)
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

local function controlCenterY()
	return GF.SUBTITLE_CONTROL_CENTER_OFFSET_Y or 0
end

local function normalizeAssignedRole(role)
	if type(role) ~= "string" then
		return nil
	end
	role = role:upper()
	if role == "DPS" then
		return "DAMAGER"
	end
	if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
		return role
	end
	return nil
end

local function getPlayerSpecializationRole()
	if not (GetSpecialization and GetSpecializationRole) then
		return nil
	end
	local specIndex = GetSpecialization()
	if not specIndex then
		return nil
	end
	return normalizeAssignedRole(GetSpecializationRole(specIndex))
end

local function normalizeRoleCounts(data)
	if type(data) ~= "table" then
		return nil
	end
	local counts = {
		TANK = tonumber(data.TANK) or 0,
		HEALER = tonumber(data.HEALER) or 0,
		DAMAGER = tonumber(data.DAMAGER) or 0,
	}
	local total = counts.TANK + counts.HEALER + counts.DAMAGER
	if total <= 0 then
		return nil
	end
	return counts, total
end

local function addUnitRoleCount(counts, unit)
	if not unit or (UnitExists and not UnitExists(unit)) then
		return false
	end
	local role = UnitGroupRolesAssigned and normalizeAssignedRole(UnitGroupRolesAssigned(unit))
	if not role and UnitIsUnit and UnitIsUnit(unit, "player") then
		role = getPlayerSpecializationRole()
	end
	role = role or "DAMAGER"
	counts[role] = (counts[role] or 0) + 1
	return true
end

local function readGroupMemberCountsFromUnits()
	local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
	local total = 0
	if IsInRaid and IsInRaid(LE_PARTY_CATEGORY_HOME) then
		local n = tonumber(GetNumGroupMembers and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)) or 0
		for index = 1, n do
			if addUnitRoleCount(counts, "raid" .. index) then
				total = total + 1
			end
		end
	elseif IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME) then
		if addUnitRoleCount(counts, "player") then
			total = total + 1
		end
		local n = tonumber(GetNumGroupMembers and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)) or 1
		for index = 1, math.max(0, n - 1) do
			if addUnitRoleCount(counts, "party" .. index) then
				total = total + 1
			end
		end
	else
		if addUnitRoleCount(counts, "player") then
			total = total + 1
		end
	end
	if total <= 0 then
		return nil
	end
	return counts, total
end

local function readGroupMemberCountsForDisplay()
	if GetGroupMemberCountsForDisplay then
		local ok, data = pcall(GetGroupMemberCountsForDisplay)
		if ok then
			local counts, total = normalizeRoleCounts(data)
			if counts then
				return counts, total
			end
		end
	end
	return readGroupMemberCountsFromUnits()
end

local function getActiveActivityInfo(activeInfo)
	if not activeInfo then
		return nil, nil
	end
	local snapshot = GF.SearchResultSnapshot
	local activityID = snapshot and snapshot.GetPrimaryActivityID and snapshot.GetPrimaryActivityID(activeInfo)
	if not activityID then
		activityID = activeInfo.activityID or (activeInfo.activityIDs and activeInfo.activityIDs[1])
	end
	if not activityID or not (C_LFGList and C_LFGList.GetActivityInfoTable) then
		return activityID, nil
	end
	local ok, activityInfo = pcall(C_LFGList.GetActivityInfoTable, activityID, activeInfo.questID, activeInfo.isWarMode)
	if ok then
		return activityID, activityInfo
	end
	return activityID, nil
end

local function getActiveRoleDisplayMode(activityInfo)
	local displayType = activityInfo and activityInfo.displayType
	local displayEnum = Enum and Enum.LFGListDisplayType
	if displayEnum then
		if displayType == displayEnum.HideAll then
			return nil
		end
		if displayType == displayEnum.RoleEnumerate or displayType == displayEnum.ClassEnumerate then
			return "enumerate_roles"
		end
		if displayType == displayEnum.RoleCount or displayType == displayEnum.PlayerCount then
			return "count"
		end
	end
	local maxPlayers = tonumber(activityInfo and activityInfo.maxNumPlayers) or 0
	if maxPlayers > 0 and maxPlayers <= 5 then
		return "enumerate_roles"
	end
	return "count"
end

local function buildActiveRoleSummaryEntry()
	if not (GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive()) then
		return nil
	end
	local activeInfo = GF.RecruitmentSession.GetActive and GF.RecruitmentSession:GetActive()
	if not activeInfo then
		return nil
	end
	local activityID, activityInfo = getActiveActivityInfo(activeInfo)
	local mode = getActiveRoleDisplayMode(activityInfo)
	if not mode then
		return nil
	end
	local counts, total = readGroupMemberCountsForDisplay()
	if not counts then
		return nil
	end
	return {
		info = {
			numMembers = total,
			name = activeInfo.name,
			activityIDs = activityID and { activityID } or activeInfo.activityIDs,
		},
		activity = activityInfo,
		categoryID = activityInfo and activityInfo.categoryID,
		tanks = counts.TANK or 0,
		heals = counts.HEALER or 0,
		dps = counts.DAMAGER or 0,
		_displayCounts = counts,
		_displayCountsLoaded = true,
	}, mode
end

local function setHeaderRefreshButtonEnabled(button, enabled)
	if not button then
		return
	end
	enabled = enabled == true
	button:SetEnabled(enabled)
	GF.UI.SetHeaderRefreshIconState(
		button,
		enabled and BUTTON_VISUAL_STATE.NORMAL or BUTTON_VISUAL_STATE.DISABLED
	)
end

local function applyBumpButtonState(panel, canLead)
	local button = panel and panel.bumpBtn
	if not button then
		return
	end
	local listing = GF.RecruitmentSession
	local remaining = listing and listing.GetRelistCooldownRemaining
		and listing:GetRelistCooldownRemaining() or 0
	local onCooldown = remaining > 0
	local busy = listing and listing.IsBusy and listing:IsBusy()
	local text
	if onCooldown and canLead == true then
		text = tostring(math.max(1, math.ceil(remaining)))
	else
		local L = GF.L or {}
		text = L.BUMP_LISTING or "Relist"
	end
	if button._gfBumpButtonText ~= text then
		button._gfBumpButtonText = text
		button:SetText(text)
	end
	button:SetEnabled(canLead == true and not onCooldown and not busy)
end

local function getLoadingCycleSeconds()
	return ((GF.BROWSE_LOADING_STEP_SECONDS or 0.28) * (GF.BROWSE_LOADING_ICON_COUNT or 3))
		+ (GF.BROWSE_LOADING_HOLD_SECONDS or 0.4)
		+ (GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45)
end

local function getLoadingIconAlpha(elapsed, iconIndex)
	local stepSeconds = GF.BROWSE_LOADING_STEP_SECONDS or 0.28
	local fadeInSeconds = GF.BROWSE_LOADING_FADE_IN_SECONDS or 0.16
	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local holdSeconds = GF.BROWSE_LOADING_HOLD_SECONDS or 0.4
	local fadeOutSeconds = GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45
	local appearAt = (iconIndex - 1) * stepSeconds
	if elapsed < appearAt then
		return 0
	end
	local fadeInEnd = appearAt + fadeInSeconds
	if elapsed < fadeInEnd then
		return math.max(0, math.min(1, (elapsed - appearAt) / fadeInSeconds))
	end
	local fadeOutStart = (stepSeconds * iconCount) + holdSeconds
	if elapsed < fadeOutStart then
		return 1
	end
	local fadeOutEnd = fadeOutStart + fadeOutSeconds
	if elapsed < fadeOutEnd then
		return math.max(0, math.min(1, 1 - ((elapsed - fadeOutStart) / fadeOutSeconds)))
	end
	return 0
end

local function refreshLoadingAnimation(animation)
	if not (animation and animation.icons) then
		return
	end
	local elapsed = animation.elapsed or 0
	for index, icon in ipairs(animation.icons) do
		local alpha = getLoadingIconAlpha(elapsed, index)
		icon:SetAlpha(alpha)
		if alpha > 0.02 then
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local AUTO_INVITE_CONTROL_MODE_PLUGIN = "plugin_auto_invite"

local function resolveAutoInviteControlState()
	local listing = GF.RecruitmentSession
	if listing and type(listing.GetActiveAutoAcceptControlState) == "function" then
		local nativeState = listing:GetActiveAutoAcceptControlState()
		if type(nativeState) == "table" then
			return nativeState
		end
	end
	local scheduler = GF.InvitationScheduler
	return {
		mode = AUTO_INVITE_CONTROL_MODE_PLUGIN,
		checked = scheduler ~= nil
			and type(scheduler.IsEnabled) == "function"
			and scheduler:IsEnabled() == true,
		canToggle = scheduler ~= nil
			and type(scheduler.CanToggle) == "function"
			and scheduler:CanToggle() == true,
	}
end

local function applyAutoInviteState(panel)
	local check = panel.autoCheck
	if not check then
		return
	end
	local state = resolveAutoInviteControlState()
	local canToggle = state.canToggle == true
	check:SetEnabled(true)
	if GF.UI and GF.UI.SetFilterCheckButtonVisualEnabled then
		GF.UI.SetFilterCheckButtonVisualEnabled(check, canToggle)
	elseif check.SetDesaturated then
		check:SetDesaturated(not canToggle)
	end
	local label = panel.autoLabel
	if label then
		local r, g, b = 0.5, 0.5, 0.5
		if canToggle then
			r, g, b = 1, 0.82, 0
		end
		label:SetTextColor(r, g, b)
	end
	check:SetChecked(state.checked == true)
end

local function applyManageState(panel, canLead, canManage)
	local listing = GF.RecruitmentSession
	local bumpBusy = listing and listing.IsBusy
		and listing:IsBusy()
	if panel.editBtn then
		panel.editBtn:SetEnabled(canLead and not bumpBusy)
	end
	if panel.refreshBtn then
		local actions = GF.ApplicantActionService
		local canRefresh = actions and actions.CanRefresh
			and actions:CanRefresh() == true
		setHeaderRefreshButtonEnabled(panel.refreshBtn, canRefresh and not bumpBusy)
	end
	applyBumpButtonState(panel, canLead)
	if panel.removeBtn then
		panel.removeBtn:SetEnabled(canLead and not bumpBusy)
	end
	applyAutoInviteState(panel)
end

function AP:UpdateBumpButtonState()
	local listing = GF.RecruitmentSession
	local canLead = listing and listing.CanPublish and listing:CanPublish()
	applyBumpButtonState(self, canLead)
end

function AP:ForEachVisibleRow(fn)
	if self.scrollList and fn then
		self.scrollList:ForEachFrame(fn)
	end
end

function AP:GetSelectedApplicantRowKey()
	return self.selectedApplicantRowKey
end

function AP:RefreshSelectedApplicantRows()
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

function AP:SetSelectedApplicantRow(row)
	local key = row and row.applicantID and applicantRowKey(row.applicantID, row.memberIdx) or nil
	if self.selectedApplicantRowKey == key then
		self:RefreshSelectedApplicantRows()
		return
	end
	self.selectedApplicantRowKey = key
	self:RefreshSelectedApplicantRows()
end

local function requestListingBump()
	local listing = GF.RecruitmentSession
	if not (listing and listing.Relist) then
		return
	end
	listing:Relist()
	AP:UpdateManageState()
	local createPanel = GF.CreatePanel
	if createPanel and createPanel.UpdateManageState then
		createPanel:UpdateManageState()
	end
	local inlinePanel = GF.MythicPlusCreateManagerPanel
	local isInlineActive = inlinePanel
		and inlinePanel.IsSurfaceActive
		and inlinePanel:IsSurfaceActive()
	if isInlineActive and inlinePanel.RefreshDungeonControlState then
		inlinePanel:RefreshDungeonControlState()
	end
end

local function showListingBumpTooltip(button)
	GF.UI.BeginGameTooltipAbove(button, "LEFT")
	GF.UI.SetTooltipText((GF.L and GF.L.BUMP_LISTING_TIP) or "")
	GF.UI.ShowGameTooltip()
end

local function toggleAutoInvite(button)
	local state = resolveAutoInviteControlState()
	local listing = GF.RecruitmentSession
	local scheduler = GF.InvitationScheduler
	if state.canToggle then
		local accepted
		if state.mode == (listing and listing.AUTO_ACCEPT_CONTROL_MODE_NATIVE_QUEST) then
			accepted = listing.SetActiveAutoAccept
				and listing:SetActiveAutoAccept(button:GetChecked())
		else
			accepted = scheduler and scheduler.SetEnabled
				and scheduler:SetEnabled(button:GetChecked())
		end
		if accepted ~= true then
			button:SetChecked(state.checked == true)
		end
		return
	end
	button:SetChecked(state.checked == true)
	if state.disabledReason == "unempowered"
		and listing and listing.NotifyLeaderOnly
	then
		listing:NotifyLeaderOnly()
	elseif state.mode == AUTO_INVITE_CONTROL_MODE_PLUGIN
		and listing and listing.NotifyLeaderOnly
	then
		listing:NotifyLeaderOnly()
	end
end

local function hideGameTooltip()
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local function onApplicantListSizeChanged(box, width, height)
	if AP._frameResizing or (AP.parent and not AP.parent:IsShown()) then
		return
	end
	width = width or box:GetWidth()
	height = height or box:GetHeight()
	if not (width and height and width > 0 and height > 0) then
		return
	end
	if AP._scrollLastW == width and AP._scrollLastH == height then
		return
	end
	AP._scrollLastW, AP._scrollLastH = width, height
	AP:ScheduleRelayout()
end

function AP:Init(parent)
	local scrollAPI = GF.UI and GF.UI.ScrollList
	if self.scrollList or not (scrollAPI and scrollAPI.IsAvailable()) then
		return
	end

	self.parent = parent
	local L = GF.L or {}

	self.columnHeaderHost = CreateFrame("Frame", nil, parent)
	self.columnHeaderHost:SetPoint("TOPLEFT", parent, "TOPLEFT", GF.CONTENT_SCROLL_INSET_L or 0, GF.BROWSE_HEADER_TOP_OFFSET or -20)
	self.columnHeaderHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(GF.CONTENT_SCROLL_INSET_R or 18), GF.BROWSE_HEADER_TOP_OFFSET or -20)
	self.columnHeaderHost:SetHeight(HEADER_H)
	self.columnHeaderHost:SetFrameLevel(parent:GetFrameLevel() + 25)
	if GF.UI and GF.UI.InstallBrowseHeaderChrome then
		GF.UI.InstallBrowseHeaderChrome(self.columnHeaderHost)
	end

	self.refreshBtn = CreateFrame("Button", nil, parent)
	self.refreshBtn:SetSize(GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE or 35, GF.BROWSE_HEADER_REFRESH_BUTTON_SIZE or 35)
	self.refreshBtn:SetFrameLevel(parent:GetFrameLevel() + 35)
	self.refreshBtn:RegisterForClicks("LeftButtonUp")
	local refreshIcon = self.refreshBtn:CreateTexture(nil, "OVERLAY")
	refreshIcon:SetTexture(GF.BROWSE_HEADER_REFRESH_TEXTURE or HEADER_REFRESH_TEXTURE)
	refreshIcon:SetTexCoord(0, 1, 0, 1)
	self.refreshBtn.Icon = refreshIcon
	GF.UI.SetHeaderRefreshIconState(
		self.refreshBtn,
		BUTTON_VISUAL_STATE.NORMAL,
		GF.APPLICANT_HEADER_REFRESH_BUTTON_OFFSET_Y or 0
	)
	self.refreshBtn:SetScript("OnClick", function()
		local actions = GF.ApplicantActionService
		if not (actions and actions.CanRefresh and actions:CanRefresh())
		then
			return
		end
		local refreshed = actions.Refresh and actions:Refresh() == true
		if not refreshed then
			return
		end
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		if AP.Refresh then
			AP:Refresh({ preserveScroll = true })
		end
	end)
	self.refreshBtn:SetScript("OnEnter", function(btn)
		if btn.IsEnabled and not btn:IsEnabled() then
			return
		end
		GF.UI.SetHeaderRefreshIconState(btn, BUTTON_VISUAL_STATE.HOVER)
		GF.UI.BeginGameTooltip(btn, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L.REFRESH_LISTING or "刷新列表", 1, 0.82, 0, true)
		GameTooltip:AddLine(L.REFRESH_LISTING_TIP or "刷新当前招募的申请者列表", 1, 1, 1, true)
		GF.UI.ShowGameTooltip()
	end)
	self.refreshBtn:SetScript("OnMouseDown", function(btn, mouseButton)
		if mouseButton == "LeftButton" and (not btn.IsEnabled or btn:IsEnabled()) then
			GF.UI.SetHeaderRefreshIconState(btn, BUTTON_VISUAL_STATE.PRESSED)
		end
	end)
	self.refreshBtn:SetScript("OnMouseUp", function(btn)
		GF.UI.SetHeaderRefreshIconState(
			btn,
			(not btn.IsEnabled or btn:IsEnabled()) and BUTTON_VISUAL_STATE.HOVER or BUTTON_VISUAL_STATE.DISABLED
		)
	end)
	self.refreshBtn:SetScript("OnLeave", function(btn)
		GF.UI.SetHeaderRefreshIconState(
			btn,
			(not btn.IsEnabled or btn:IsEnabled()) and BUTTON_VISUAL_STATE.NORMAL or BUTTON_VISUAL_STATE.DISABLED
		)
		if GameTooltip and GameTooltip:GetOwner() == btn then
			GameTooltip:Hide()
		end
	end)
	self.refreshBtn:SetScript("OnDisable", function(btn)
		GF.UI.SetHeaderRefreshIconState(btn, BUTTON_VISUAL_STATE.DISABLED)
	end)
	self.refreshBtn:Hide()

	self.footer = CreateFrame("Frame", nil, parent)
	self.footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
	self.footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	self.footer:SetHeight(FOOTER_H)
	self.footer:SetFrameLevel(parent:GetFrameLevel() + 30)
	if GF.UI and GF.UI.InstallBrowseControlBarChrome then
		GF.UI.InstallBrowseControlBarChrome(self.footer)
	end

	self.toolbar = CreateFrame("Frame", nil, self.footer)
	self.toolbar:SetAllPoints(self.footer)

	self.editBtn = GF.UI.CreatePanelButton(self.toolbar, L.EDIT_LISTING or "Edit", MANAGE_BUTTON_W)
	self.editBtn:SetPoint("LEFT", self.toolbar, "LEFT", LEFT_PAD, controlCenterY())
	GF.UI.AttachActionGuard(self.editBtn, {
		capability = "listing_leader",
		tooltipPlacement = "aboveLeft",
		onClick = function()
			if GF.CreateDrawer then
				GF.CreateDrawer:Open({ mode = "edit", allowOccupiedPrompt = true })
			end
		end,
	})

	self.removeBtn = GF.UI.CreatePanelButton(self.toolbar, L.REMOVE_LISTING or "Remove", MANAGE_BUTTON_W)
	self.removeBtn:SetPoint("RIGHT", self.toolbar, "RIGHT", -RIGHT_PAD, controlCenterY())
	GF.UI.AttachActionGuard(self.removeBtn, {
		capability = "listing_leader",
		tooltipPlacement = "aboveLeft",
		onClick = function()
			GF.RecruitmentSession:Remove()
		end,
	})

	local bumpButton = GF.UI.CreatePanelButton(self.toolbar, L.BUMP_LISTING or "Relist", MANAGE_BUTTON_W)
	bumpButton:SetPoint("RIGHT", self.removeBtn, "LEFT", -6, 0)
	self.bumpBtn = bumpButton
	GF.UI.AttachActionGuard(bumpButton, {
		capability = "listing_leader",
		tooltipPlacement = "aboveLeft",
		onClick = requestListingBump,
		onAllowedHover = showListingBumpTooltip,
	})

	local autoCheck = CreateFrame("CheckButton", nil, self.toolbar, "UICheckButtonTemplate")
	autoCheck:SetSize(22, 22)
	autoCheck:SetPoint("LEFT", self.toolbar, "LEFT", LEFT_PAD, controlCenterY())
	self.autoCheck = autoCheck
	local autoLabel = GF.UI.CreateFontString(self.toolbar, "OVERLAY", "GameFontNormal")
	autoLabel:SetText(L.AUTO_ACCEPT or "Auto invite")
	autoLabel:SetPoint("LEFT", autoCheck, "RIGHT", GF.SUBTITLE_OPTION_TEXT_GAP or 1, 0)
	self.autoLabel = autoLabel
	autoCheck:SetScript("OnClick", toggleAutoInvite)
	autoCheck:SetScript("OnEnter", function()
		AP:ShowAutoAcceptTooltip()
	end)
	autoCheck:SetScript("OnLeave", hideGameTooltip)
	if GF.UI and GF.UI.StyleFilterCheckButton then
		GF.UI.StyleFilterCheckButton(autoCheck, { size = 22 })
	end

	local roleSummaryParent = (GF.MainFrame and GF.MainFrame.footerHost)
		or (GF.MainFrame and GF.MainFrame.frame)
		or parent
	self.roleSummaryHost = CreateFrame("Frame", nil, roleSummaryParent)
	self.roleSummaryHost:SetSize(ROLE_SUMMARY_W, ROLE_SUMMARY_H)
	self.roleSummaryHost:SetFrameLevel((roleSummaryParent:GetFrameLevel() or parent:GetFrameLevel() or 1) + 20)
	self.roleSummaryHost:SetPoint(
		"RIGHT",
		roleSummaryParent,
		"RIGHT",
		-(GF.ACTIVITY_COUNT_RIGHT or 28) + ROLE_SUMMARY_X,
		0)
	self.roleSummaryHost:EnableMouse(false)
	if GF.RoleDisplay and GF.RoleDisplay.Create then
		self.activeRoleDisplay = GF.RoleDisplay:Create(self.roleSummaryHost)
		self.activeRoleDisplay:ClearAllPoints()
		self.activeRoleDisplay:SetPoint("CENTER", self.roleSummaryHost, "CENTER", 0, 0)
		self.activeRoleDisplay:Hide()
	end
	self.roleSummaryHost:Hide()

	self.removeBtn:ClearAllPoints()
	self.removeBtn:SetPoint("RIGHT", self.toolbar, "RIGHT", -RIGHT_PAD, controlCenterY())
	self.editBtn:ClearAllPoints()
	self.editBtn:SetPoint("RIGHT", self.removeBtn, "LEFT", -GAP, 0)
	self.bumpBtn:ClearAllPoints()
	self.bumpBtn:SetPoint("RIGHT", self.editBtn, "LEFT", -GAP, 0)

	self.columnHeaderBar = GF.ColumnHeaderBar:Create(self.columnHeaderHost, {
		mode = "applicant",
		profile = "applicant",
		onSort = function()
			if GF.ListColumns then
				GF.ListColumns:InvalidateCache()
			end
			AP:RefreshList({ forceFull = true, preserveScroll = true })
			AP:LayoutColumnHeaders()
		end,
		onLayoutChange = function()
			if AP.RelayoutRows then
				AP:RelayoutRows()
			end
		end,
	})
	self.columnHeaderBar:SetPoint("TOPLEFT", self.columnHeaderHost, "TOPLEFT", 0, GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4)
	self.columnHeaderBar:SetPoint("BOTTOMRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", 0, GF.BROWSE_HEADER_CONTENT_OFFSET_Y or 4)

	self.listBody = CreateFrame("Frame", nil, parent)
	self.listBody:SetPoint("TOPLEFT", self.columnHeaderHost, "BOTTOMLEFT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
	self.listBody:SetPoint("TOPRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
	self.listBody:SetPoint("BOTTOMLEFT", self.footer, "TOPLEFT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
	self.listBody:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
	self.listBody:SetFrameLevel(parent:GetFrameLevel() + 2)

	self.scrollList = ASL.Create(self, self.listBody, { barParent = parent })
	local scrollBox = self.scrollList:GetScrollBox()
	scrollBox:SetPoint("TOPLEFT", self.listBody, "TOPLEFT", 0, 0)
	GF.UI.AnchorContentScrollBottomRight(scrollBox, self.listBody)

	self._scrollLastW = 0
	self._scrollLastH = 0
	scrollBox:SetScript("OnSizeChanged", onApplicantListSizeChanged)

	local emptyPrompt = GF.UI.CreateFontString(self.listBody, "OVERLAY", "GameFontHighlight")
	emptyPrompt:SetPoint("CENTER", scrollBox, "CENTER")
	emptyPrompt:SetText(L.NO_APPLICANTS or "")
	self.empty = emptyPrompt
	self:ApplyEmptyPromptStyle()
	emptyPrompt:Hide()
	self.emptyAnchor = scrollBox

	self.applicantIDs = {}
	self.totalCount = 0
	self:SetBottomControlsShown(false)
	self:SetHeaderRefreshButtonShown(false)
end

function AP:LayoutColumnHeaders(layoutWidth)
	local host = self.columnHeaderHost
	if not (host and host:IsShown()) then
		return
	end
	local resolvedWidth = layoutWidth
	if resolvedWidth == nil and GF.GetApplicantListLayoutWidth then
		resolvedWidth = GF.GetApplicantListLayoutWidth()
	end
	GF.ColumnHeaderBar:LayoutHost(host, self.columnHeaderBar, resolvedWidth)
	self:AnchorHeaderRefreshButton()
	self:ScheduleHeaderRefreshButtonAnchor()
end

function AP:AnchorHeaderRefreshButton()
	if not self.refreshBtn then
		return
	end
	self.refreshBtn:ClearAllPoints()
	local scrollBar = self.scrollList
		and self.scrollList.GetScrollBar
		and self.scrollList:GetScrollBar()
	if scrollBar and self.columnHeaderBar then
		local barLeft = self.columnHeaderBar:GetLeft()
		local scrollLeft = scrollBar:GetLeft()
		local scrollW = scrollBar:GetWidth()
		if barLeft and scrollLeft and scrollW and scrollW > 0 then
			local x = (scrollLeft + (scrollW / 2)) - barLeft
			self.refreshBtn:SetPoint("CENTER", self.columnHeaderBar, "LEFT", math.floor(x + 0.5), 0)
			return
		end
	end
	if self.columnHeaderHost then
		self.refreshBtn:SetPoint("CENTER", self.columnHeaderHost, "RIGHT", GF.CONTENT_SCROLLBAR_OFFSET_X or 9, 0)
		return
	end
	if scrollBar then
		self.refreshBtn:SetPoint("CENTER", scrollBar, "CENTER", 0, 0)
	end
end

function AP:ScheduleHeaderRefreshButtonAnchor()
	if not self.refreshBtn then
		return
	end
	if not C_Timer or not C_Timer.After then
		self:AnchorHeaderRefreshButton()
		return
	end
	C_Timer.After(0, function()
		if AP.refreshBtn and AP.columnHeaderHost and AP.columnHeaderHost:IsShown() then
			AP:AnchorHeaderRefreshButton()
		end
	end)
end

function AP:SetHeaderRefreshButtonShown(shown)
	shown = shown == true
	if self.refreshBtn then
		self.refreshBtn:SetShown(shown)
		if shown then
			self:AnchorHeaderRefreshButton()
			self:ScheduleHeaderRefreshButtonAnchor()
		elseif GameTooltip and GameTooltip:GetOwner() == self.refreshBtn then
			GameTooltip:Hide()
		end
	end
end

function AP:SetManagementControlsShown(shown)
	shown = shown == true
	local inlineManager = GF.MythicPlusCreateManagerPanel
	local manageFromSidebar = inlineManager
		and inlineManager.ShouldUse
		and inlineManager:ShouldUse()
		or false
	for _, frame in ipairs({
		self.editBtn,
		self.removeBtn,
		self.bumpBtn,
		self.autoCheck,
		self.autoLabel,
	}) do
		if frame then
			local sidebarOwned = frame == self.editBtn
				or frame == self.removeBtn
			frame:SetShown(shown and not (
				manageFromSidebar and sidebarOwned
			))
		end
	end
	if self.bumpBtn then
		self.bumpBtn:ClearAllPoints()
		if manageFromSidebar then
			self.bumpBtn:SetPoint(
				"RIGHT",
				self.toolbar,
				"RIGHT",
				-RIGHT_PAD,
				controlCenterY()
			)
		else
			self.bumpBtn:SetPoint("RIGHT", self.editBtn, "LEFT", -GAP, 0)
		end
	end
	if GameTooltip then
		for _, frame in ipairs({ self.editBtn, self.removeBtn, self.bumpBtn, self.autoCheck }) do
			local hiddenForSidebar = manageFromSidebar
				and (frame == self.editBtn or frame == self.removeBtn)
			if frame and (not shown or hiddenForSidebar)
				and GameTooltip:GetOwner() == frame
			then
				GameTooltip:Hide()
				return
			end
		end
	end
end

function AP:UpdateFromActiveRoleSummary()
	if not self.roleSummaryHost then
		return
	end
	local currentTab = GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent()
	if (currentTab and currentTab ~= GF.TAB_CREATE)
		or (self.parent and not self.parent:IsShown())
		or not (GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive())
	then
		self.roleSummaryHost:Hide()
		if self.activeRoleDisplay then
			self.activeRoleDisplay:Hide()
		end
		return
	end
	local entry, mode = buildActiveRoleSummaryEntry()
	if not (entry and mode and self.activeRoleDisplay and GF.RoleDisplay and GF.RoleDisplay.Update) then
		self.roleSummaryHost:Hide()
		if self.activeRoleDisplay then
			self.activeRoleDisplay:Hide()
		end
		return
	end
	self.roleSummaryHost:Show()
	GF.RoleDisplay:Update(self.activeRoleDisplay, entry, entry.categoryID, { mode = mode })
	self.activeRoleDisplay:ClearAllPoints()
	self.activeRoleDisplay:SetPoint("CENTER", self.roleSummaryHost, "CENTER", 0, 0)
end

function AP:RefreshScrollViewport()
	local list = self.scrollList
	local retain = list and list.dataProvider and list.RetainScrollPosition
	if retain then
		retain(list)
	end
end

function AP:UpdateScrollWidth()
	self:RefreshScrollViewport()
end

function AP:CancelRelayoutDebounce()
	local pending = self._relayoutDebounce
	self._relayoutDebounce = nil
	if pending and pending.Cancel then
		pending:Cancel()
	end
end

function AP:ScheduleRelayout()
	if self._relayoutDebounce then
		return
	end
	local newTimer = C_Timer and C_Timer.NewTimer
	if not newTimer then
		self:Relayout()
		return
	end
	self._relayoutDebounce = newTimer(0.1, function()
		self._relayoutDebounce = nil
		self:Relayout()
	end)
end

function AP:RefreshLayoutIfReady(attempt)
	GF.UI.RefreshListLayoutIfReady(self, attempt)
end

function AP:GetRelayoutSig()
	local widthGetter = GF.GetApplicantListLayoutWidth
	local width = widthGetter and widthGetter() or 0
	local columns = GF.ListColumns
	if columns and columns.GetRelayoutSig then
		return columns:GetRelayoutSig(width, "applicant")
	end
	return nil
end

local function panelIsVisible(panel)
	return not panel.parent or panel.parent:IsShown()
end

local function panelCanRelayout(panel)
	return not panel._frameResizing
		and not GF._frameResizing
		and panelIsVisible(panel)
end

local function applyApplicantRelayoutPipeline(panel)
	panel:LayoutColumnHeaders()
	if ASL and ASL.RelayoutVisible then
		ASL.RelayoutVisible(panel)
	end
	panel:RefreshScrollViewport()
	GF.UI.CommitRelayoutSig(panel)
end

function AP:RelayoutRows()
	if not panelCanRelayout(self) then
		return
	end
	self:CancelRelayoutDebounce()
	applyApplicantRelayoutPipeline(self)
end

function AP:Relayout(opts)
	local options = type(opts) == "table" and opts or {}
	if not self.scrollList or not panelIsVisible(self) then
		return
	end
	self:CancelRelayoutDebounce()
	local nextSignature = self:GetRelayoutSig()
	local unchanged = nextSignature ~= nil and nextSignature == self._relayoutSig
	if options.force ~= true and unchanged then
		self:RefreshScrollViewport()
		return
	end
	local columns = GF.ListColumns
	if columns and columns.InvalidateCache then
		columns:InvalidateCache()
	end
	self:RelayoutRows()
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

function AP:UpdateInviteState()
	if self.scrollList then
		self:ForEachVisibleRow(refreshVisibleApplicantAction)
	end
end

local function getActiveRecruitingPrompt(L)
	local title = GF.RecruitmentSession and GF.RecruitmentSession.GetActiveActivityTitle and GF.RecruitmentSession:GetActiveActivityTitle()
	if title and title ~= "" then
		local entryName = GF.RecruitmentSession and GF.RecruitmentSession.GetActiveEntryName and GF.RecruitmentSession:GetActiveEntryName()
		local entryNameIsSecret = issecretvalue
			and issecretvalue(entryName)
		if not entryNameIsSecret
			and entryName
			and entryName ~= ""
		then
			return string.format(L.CREATE_ACTIVE_RECRUITING_PROMPT_FMT or "|cffffd100%s|r |cffffffff%s|r |cffffd100正在招募中|r", title, entryName)
		end
		return string.format(L.CREATE_ACTIVE_RECRUITING_ACTIVITY_PROMPT_FMT or "|cffffd100%s正在招募中|r", title)
	end
	return L.NO_APPLICANTS or "队伍正在招募中"
end

function AP:UpdateEmptyHint()
	if not self.empty then
		return
	end
	local L = GF.L or {}
	local canLead = GF.RecruitmentSession and GF.RecruitmentSession.CanPublish and GF.RecruitmentSession:CanPublish()
	local listed = GF.RecruitmentSession and GF.RecruitmentSession:HasActive()
	local hasTestApplicants = GF.ApplicantTestData
		and GF.ApplicantTestData.IsEnabled
		and GF.ApplicantTestData:IsEnabled()
	if not listed and not hasTestApplicants then
		local premadeBlockMessage = GF.Availability
			and GF.Availability.GetPremadeBlockMessage
			and GF.Availability:GetPremadeBlockMessage()
		local prompt
		if premadeBlockMessage then
			prompt = premadeBlockMessage
		elseif canLead then
			if GF.LFGWorkspaceView and GF.LFGWorkspaceView.IsMythicPlusActive
				and GF.LFGWorkspaceView:IsMythicPlusActive() then
				local activityIDs = GF.LFGWorkspacePolicy
					and GF.LFGWorkspacePolicy.GetSeasonActivityIDs
					and GF.LFGWorkspacePolicy:GetSeasonActivityIDs() or {}
				if #activityIDs == 0 then
					prompt = L.MPLUS_LFG_SCOPE_UNAVAILABLE
						or "Level restricted: Seasonal Mythic+ mode has not been unlocked."
				else
					prompt = L.CREATE_EMPTY_PROMPT
						or L.NO_LISTING
						or "请创建集合石招募"
				end
			else
				prompt = L.CREATE_EMPTY_PROMPT or L.NO_LISTING or "请创建集合石招募"
			end
		else
			prompt = L.CREATE_LEADER_ONLY_PROMPT or "仅队长有权限创建队伍"
		end
		self:SetEmptyPrompt(prompt, true)
	elseif listed and not hasTestApplicants then
		self:SetEmptyPrompt((self.totalCount == 0) and getActiveRecruitingPrompt(L) or nil, self.totalCount == 0)
	elseif listed then
		self:SetEmptyPrompt((self.totalCount == 0) and (L.NO_APPLICANTS or "") or nil, self.totalCount == 0)
	else
		self:SetEmptyPrompt((self.totalCount == 0) and (L.NO_APPLICANTS or "") or nil, self.totalCount == 0)
	end
end

function AP:RefreshDividers()
	self:ForEachVisibleRow(function(card)
		if card then
			GF.ApplicantCard:RefreshDivider(card)
		end
	end)
end

function AP:IsTerminalApplicantDismissed(applicantID, data, authoritativeAppliedEvent)
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

function AP:FilterDismissedTerminalApplicantIDs(applicantIDs)
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

function AP:RememberInvitedApplicant(applicantID, data)
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

function AP:MergeRetainedInvitedApplicantIDs(currentIDs, previousIDs)
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

function AP:StartVisibleTerminalApplicantLifecycles()
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

function AP:RefreshList(opts)
	opts = opts or {}
	if not self.scrollList then
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
		if not opts.preserveScroll and self.scrollList.ScrollToBegin then
			self.scrollList:ScrollToBegin()
		end
		self:UpdateInviteState()
		return
	end

	local elements = self:BuildApplicantElements()
	local retainScroll = opts.preserveScroll == true
	self.scrollList:SetElements(elements, { retainScroll = retainScroll })
	self:StartVisibleTerminalApplicantLifecycles()
	if not retainScroll and self.scrollList.ScrollToBegin then
		self.scrollList:ScrollToBegin()
	end
	self:UpdateInviteState()
end

function AP:Refresh(opts)
	opts = opts or {}
	self:UpdateManageState()
	self:RefreshList(opts)
end

function AP:ProjectTerminalApplicantFade(data)
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

function AP:GetProtectedTerminalApplicantData(applicantID, _forceFresh)
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

function AP:GetApplicantDisplayData(applicantID, forceFresh)
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
	local data = forceFresh and buildApplicantSafely(applicantID) or nil
	if data and data.status == "applied" then
		-- No joined acknowledgement remains for this ID, so a readable applied state
		-- is the authoritative start of a new application generation.
		data._gfNativeAvailable = true
		self:RememberInvitedApplicant(applicantID, data)
		self.applicantDataCache[key] = data
		return self:ProjectTerminalApplicantFade(data), true
	end
	if cached and cached._gfSoftUnavailable and not forceFresh then
		return self:ProjectTerminalApplicantFade(cached), false
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

function AP:BuildApplicantElements()
	self.applicantElementCounts = self.applicantElementCounts or {}
	return ASL.BuildElements(self.applicantIDs, function(applicantID)
		local data = self:GetApplicantDisplayData(applicantID)
		self.applicantElementCounts[applicantIDKey(applicantID)] = applicantMemberCount(data)
		return data
	end)
end

function AP:RebuildApplicantElements(opts)
	opts = opts or {}
	if not self.scrollList then
		return
	end
	self.totalCount = #(self.applicantIDs or {})
	self:UpdateEmptyHint()
	if self.totalCount == 0 then
		self.scrollList:SetElements({})
		self:UpdateInviteState()
		return
	end
	self.scrollList:SetElements(self:BuildApplicantElements(), {
		retainScroll = opts.preserveScroll == true,
	})
	self:UpdateInviteState()
end

function AP:OnLaonongFanSourceChanged(revision)
	if self._laonongFanRevision == revision then
		return
	end
	self._laonongFanRevision = revision
	self.applicantDataCache = {}
	self.applicantElementCounts = {}
	if not self.scrollList or not self.parent then
		return
	end
	if self.parent.IsVisible and not self.parent:IsVisible() then
		return
	end
	if not self.parent.IsVisible and self.parent.IsShown and not self.parent:IsShown() then
		return
	end
	self:RebuildApplicantElements({ preserveScroll = true })
end

function AP:ApplyApplicantDisplayData(applicantID, data)
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

function AP:RefreshApplicant(applicantID, forceFresh)
	if not self.scrollList or not applicantID then
		return
	end
	local data = self:GetApplicantDisplayData(applicantID, forceFresh)
	return self:ApplyApplicantDisplayData(applicantID, data)
end

function AP:DismissSoftUnavailableApplicant(applicantID)
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

function AP:DismissSoftUnavailableApplicantRow(row)
	return row and row.applicantID and self:DismissSoftUnavailableApplicant(row.applicantID) or false
end

function AP:OnApplicantUpdated(
	applicantID, isAuthoritativeApplicantEvent, prefetchedAuthoritativeData)
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	self:UpdateManageState()
	if not applicantID then
		return
	end
	local key = applicantIDKey(applicantID)
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
		self:RebuildApplicantElements({ preserveScroll = true })
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

function AP:OnApplicantListUpdated()
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	self:UpdateManageState()
	if not self.scrollList then
		return
	end
	self.applicantIDs = self.applicantIDs or {}
	self.applicantDataCache = self.applicantDataCache or {}
	local sortedApplicantIDs, providerReadable =
		GF.ApplicantSnapshotBuilder:GetSortedApplicantIDs()
	if providerReadable ~= true then
		-- A failed provider read is not an empty provider snapshot.  Preserve the
		-- current projection until a later readable applicant/list event.
		self:UpdateInviteState()
		return
	end
	local currentIDs = self:FilterDismissedTerminalApplicantIDs(
		sortedApplicantIDs)
	local currentSet = applicantIDSet(currentIDs)
	local previousSet = applicantIDSet(self.applicantIDs)
	local nextIDs = {}
	local needsRebuild = false
	for _, applicantID in ipairs(self.applicantIDs) do
		local key = applicantIDKey(applicantID)
		if currentSet[key] then
			self:CancelProviderMissingApplicantCleanup(applicantID)
			nextIDs[#nextIDs + 1] = applicantID
			local data = self:GetApplicantDisplayData(applicantID, true)
			self:RememberInvitedApplicant(applicantID, data)
			if isTerminalRemovalApplicantData(data) then
				self:NoteTerminalApplicant(applicantID, data, false)
			else
				self:CancelTerminalApplicantLifecycle(applicantID, true)
				if applicantActionHasResolved(data) then
					self:ClearApplicantAction(applicantID, false)
				elseif not self:IsApplicantActionPending(applicantID)
					and data and data.status == "applied"
					and not hasNativePendingStatus(data)
				then
					self:ClearApplicantActionIntent(applicantID)
				end
			end
			local previousCount = self.applicantElementCounts and self.applicantElementCounts[key]
			if data and previousCount and previousCount ~= applicantMemberCount(data) then
				needsRebuild = true
			else
				self:RefreshApplicant(applicantID, true)
			end
		elseif self.applicantDataCache[key] then
			nextIDs[#nextIDs + 1] = applicantID
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
				-- action is pending.  A local token is only an interaction gate, while
				-- pendingApplicationStatus remains native unresolved evidence.  Neither
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
		self:RebuildApplicantElements({ preserveScroll = true })
	else
		self:UpdateInviteState()
	end
	self:RunDeferredApplicantFullRefreshIfReady()
end

function AP:ShowAutoAcceptTooltip()
	local owner = self.autoCheck
	if not (owner and GameTooltip) then
		return
	end
	local locale = GF.L or {}
	local listing = GF.RecruitmentSession
	local state = resolveAutoInviteControlState()
	local nativeMode = state.mode == (listing
		and listing.AUTO_ACCEPT_CONTROL_MODE_NATIVE_QUEST)
	local tooltipText
	if nativeMode and state.disabledReason == "unempowered" then
		local messageGetter = listing and listing.GetLeaderOnlyMessage
		tooltipText = messageGetter and messageGetter(listing)
			or locale.AUTO_ACCEPT_TIP_DISABLED
	elseif nativeMode and state.canToggle ~= true then
		tooltipText = locale.AUTO_ACCEPT_NATIVE_TIP_DISABLED
	elseif nativeMode and state.checked == true then
		tooltipText = locale.AUTO_ACCEPT_NATIVE_TIP_ON
	elseif nativeMode then
		tooltipText = locale.AUTO_ACCEPT_NATIVE_TIP
	elseif state.canToggle ~= true then
		local messageGetter = listing and listing.GetLeaderOnlyMessage
		tooltipText = messageGetter and messageGetter(listing)
			or locale.AUTO_ACCEPT_TIP_DISABLED
	elseif state.checked == true then
		tooltipText = locale.AUTO_ACCEPT_TIP_ON
	else
		tooltipText = locale.AUTO_ACCEPT_TIP
	end
	if not tooltipText or tooltipText == "" then
		return
	end
	GF.UI.BeginGameTooltipAbove(owner, "LEFT")
	GF.UI.SetTooltipText(tooltipText)
	GF.UI.ShowGameTooltip()
end

function AP:ApplyEmptyPromptStyle()
	if not self.empty then
		return
	end
	self.empty:SetTextColor(1, 0.82, 0, 1)
	if GF.UI and GF.UI.ApplyEmptyPromptFont then
		GF.UI.ApplyEmptyPromptFont(self.empty, "GameFontHighlight")
	end
end

function AP:UpdateEmptyPromptLayout(showLoading)
	if not self.empty then
		return
	end
	local anchor = self.emptyAnchor or (self.scrollList and self.scrollList.GetScrollBox and self.scrollList:GetScrollBox())
	if not anchor then
		return
	end
	local offsetY = showLoading and (((GF.BROWSE_LOADING_ICON_HEIGHT or 25) + (GF.BROWSE_LOADING_TEXT_GAP or 7)) / 2) or 0
	self.empty:ClearAllPoints()
	self.empty:SetPoint("CENTER", anchor, "CENTER", 0, offsetY)
end

function AP:EnsureLoadingAnimation()
	if self.loadingAnimation then
		return self.loadingAnimation
	end
	local parent = self.emptyAnchor or (self.scrollList and self.scrollList.GetScrollBox and self.scrollList:GetScrollBox())
	if not parent then
		return nil
	end
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 5)
	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local iconWidth = GF.BROWSE_LOADING_ICON_WIDTH or 27
	local iconHeight = GF.BROWSE_LOADING_ICON_HEIGHT or 25
	local iconGap = GF.BROWSE_LOADING_ICON_GAP or 6
	local width = (iconWidth * iconCount) + (iconGap * math.max(0, iconCount - 1))
	frame:SetSize(width, iconHeight)
	frame.icons = {}
	for index = 1, iconCount do
		local icon = frame:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(GF.BROWSE_LOADING_TEAMUP_TEXTURE or GF.TEAMUP_TEXTURE)
		icon:SetTexCoord((index - 1) / iconCount, index / iconCount, 0, 1)
		icon:SetSize(iconWidth, iconHeight)
		icon:SetPoint("LEFT", frame, "LEFT", (index - 1) * (iconWidth + iconGap), 0)
		icon:SetAlpha(0)
		icon:Hide()
		frame.icons[index] = icon
	end
	frame:SetScript("OnShow", function(animation)
		animation.elapsed = 0
		refreshLoadingAnimation(animation)
	end)
	frame:SetScript("OnUpdate", function(animation, elapsed)
		animation.elapsed = ((animation.elapsed or 0) + (elapsed or 0)) % getLoadingCycleSeconds()
		refreshLoadingAnimation(animation)
	end)
	frame:Hide()
	self.loadingAnimation = frame
	return frame
end

function AP:SetLoadingAnimationShown(shown)
	local animation = shown and self:EnsureLoadingAnimation() or self.loadingAnimation
	if not animation then
		return
	end
	animation:ClearAllPoints()
	if shown and self.empty then
		animation:SetPoint("TOP", self.empty, "BOTTOM", 0, -(GF.BROWSE_LOADING_TEXT_GAP or 7))
	end
	if shown then
		animation:Show()
	else
		animation:Hide()
	end
end

function AP:SetEmptyPrompt(text, showLoading)
	if not self.empty then
		return
	end
	showLoading = showLoading == true
	if text and text ~= "" then
		self:ApplyEmptyPromptStyle()
		self:UpdateEmptyPromptLayout(showLoading)
		self.empty:SetText(text)
		self.empty:Show()
		self:SetLoadingAnimationShown(showLoading)
	else
		self.empty:Hide()
		self:SetLoadingAnimationShown(false)
	end
end

function AP:SetBottomControlsShown(shown)
	shown = shown == true
	if self.footer then
		self.footer:SetShown(shown)
	end
	if self.toolbar then
		self.toolbar:SetShown(shown)
	end
	if self.listBody and self.columnHeaderHost then
		self.listBody:ClearAllPoints()
		self.listBody:SetPoint("TOPLEFT", self.columnHeaderHost, "BOTTOMLEFT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
		self.listBody:SetPoint("TOPRIGHT", self.columnHeaderHost, "BOTTOMRIGHT", 0, -(GF.BROWSE_HEADER_LIST_GAP or 0))
		if shown and self.footer then
			self.listBody:SetPoint("BOTTOMLEFT", self.footer, "TOPLEFT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
			self.listBody:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", 0, GF.BROWSE_CONTROL_BACKGROUND_OFFSET_Y or 0)
		elseif self.parent then
			self.listBody:SetPoint("BOTTOMLEFT", self.parent, "BOTTOMLEFT", 0, 0)
			self.listBody:SetPoint("BOTTOMRIGHT", self.parent, "BOTTOMRIGHT", 0, 0)
		end
	end
	if GF.CreateDrawer and GF.CreateDrawer.Layout then
		GF.CreateDrawer:Layout()
	end
end

local function readToolbarManagementLifecycle()
	local listing = GF.RecruitmentSession
	local relisting = listing and listing.IsRelisting and listing:IsRelisting()
	local listed = (listing and listing.HasActive and listing:HasActive()) or relisting
	local hasManagementAccess = listing and listing.CanManageApplicants and listing:CanManageApplicants()
	if relisting and not hasManagementAccess then
		hasManagementAccess = listing and listing.CanPublish and listing:CanPublish()
	end
	return relisting, listed, hasManagementAccess
end

local function readCurrentManagementLifecycle()
	local listing = GF.RecruitmentSession
	local canLead = listing ~= nil
		and listing.CanPublish ~= nil
		and listing:CanPublish() == true
	local canManage = listing ~= nil
		and listing.CanManageApplicants ~= nil
		and listing:CanManageApplicants() == true
	local relisting = listing ~= nil
		and listing.IsRelisting ~= nil
		and listing:IsRelisting() == true
	local listed = relisting
		or (listing ~= nil and listing.HasActive ~= nil and listing:HasActive() == true)
	return canLead, relisting, listed, canManage or (relisting and canLead)
end

local function refreshColumnHeaderLifecycle(panel)
	if panel.columnHeaderHost then
		panel.columnHeaderHost:Show()
		panel:LayoutColumnHeaders()
	end
end

function AP:CancelListingLossCleanup()
	local timer = self._listingLossCleanupTimer
	self._listingLossCleanupTimer = nil
	cancelTimer(timer)
end

function AP:ScheduleListingLossCleanup()
	if self._listingLossCleanupTimer then
		return
	end
	self._listingLossCleanupTimer = scheduleTimer(
		LISTING_LOSS_INVITE_GRACE_SECONDS,
			function()
				AP._listingLossCleanupTimer = nil
				local _, _, hasListing = readCurrentManagementLifecycle()
				if hasListing then
					return
				end
				-- Both this grace and the ordinary-member fallback use one second.
				-- Resolve the latest roster snapshot before pruning unresolved entries so
				-- timer registration order cannot discard a just-joined applicant.
				AP:ReconcileApplicantRosterState()
				local terminals = AP._terminalApplicantLifecycles or {}
				if next(terminals) ~= nil then
					for _, lifecycle in pairs(terminals) do
						lifecycle.dismissAfterRemoval = true
						if lifecycle.nativeMissing ~= true then
							lifecycle.nativeMissing = true
							if not lifecycle.removalTimer and not lifecycle.fadeTimer then
								local pendingLifecycle = lifecycle
								lifecycle.removalTimer = scheduleTimer(0, function()
									AP:StartTerminalApplicantRemoval(
										pendingLifecycle.applicantID, pendingLifecycle)
								end)
							end
						end
					end
					-- Let the existing 0.8s acknowledgement and 0.16s fade finish;
					-- the next pass performs non-terminal cleanup after the acknowledgement.
					AP:ScheduleListingLossCleanup()
					return
				end
				-- The one-second grace only owns unresolved applicant event ordering.
				-- Completed joined acknowledgements release their roster candidates;
				-- later departures cannot re-enter the applicant workflow.
				AP:ResetApplicantTransientState()
				AP:PruneUnresolvedApplicantRosterCandidates()
				AP._retainedInvitedApplicants = nil
				if AP.scrollList then
					AP:RefreshList({ forceFull = true, preserveScroll = true })
				end
			end
	)
end

function AP:UpdateToolbarForListed()
	local relisting, listed, hasManagementAccess = readToolbarManagementLifecycle()
	self:SetBottomControlsShown(listed == true and hasManagementAccess == true)
	self:SetHeaderRefreshButtonShown(listed == true)
	self:SetManagementControlsShown(hasManagementAccess == true)
	if not relisting then
		self:UpdateFromActiveRoleSummary()
	end
	refreshColumnHeaderLifecycle(self)
	if listed then
		self:UpdateManageState()
	end
end

function AP:UpdateManageState()
	local canLead, isRelisting, hasListing, hasManagementAccess = readCurrentManagementLifecycle()
	local preservingTerminalAcknowledgement =
		next(self._terminalApplicantLifecycles or {}) ~= nil
	local awaitingInvitedTerminal =
		next(self._retainedInvitedApplicants or {}) ~= nil
	local hasRosterCandidates =
		next(self._applicantRosterCandidates or {}) ~= nil
	if hasListing then
		self:CancelListingLossCleanup()
	elseif preservingTerminalAcknowledgement
		or awaitingInvitedTerminal or hasRosterCandidates
	then
		-- A group becoming full can remove the active listing before Blizzard's
		-- inviteaccepted/roster event arrives.  Keep unresolved candidates for one
		-- short ordering window; completed joined acknowledgements do not survive.
		self:ScheduleListingLossCleanup()
	end
	if not hasListing
		and not preservingTerminalAcknowledgement
		and not awaitingInvitedTerminal
		and not hasRosterCandidates
	then
		-- Applicant IDs are scoped to the active recruitment session.  Clear
		-- unresolved retention, but keep consumed terminal tombstones until an
		-- explicit session rotation or a newer authoritative status changes them;
		-- inactive native providers can otherwise re-emit the same stale ID.
		self:ResetApplicantTransientState()
		self._retainedInvitedApplicants = nil
	end
	local showControls = hasListing and hasManagementAccess
	self:SetBottomControlsShown(showControls)
	self:SetHeaderRefreshButtonShown(hasListing)
	self:SetManagementControlsShown(hasManagementAccess)
	applyManageState(self, canLead, hasManagementAccess)
	if isRelisting then
		return
	end
	self:UpdateFromActiveRoleSummary()
	self:UpdateEmptyHint()
	self:UpdateInviteState()
end

function AP:Show()
	local host = self.parent
	if not host then
		return
	end
	if not self.scrollList then
		self:Init(host)
	end
	host:Show()
	self:UpdateToolbarForListed()
	self:LayoutColumnHeaders()
	local listing = GF.RecruitmentSession
	if listing and listing.IsRelisting and listing:IsRelisting() then
		return
	end
	local actions = GF.ApplicantActionService
	if actions and actions.Refresh then
		actions:Refresh()
	end
	self:Refresh({ preserveScroll = true })
end

function AP:Hide()
	self:CancelListingLossCleanup()
	self:ResetApplicantTransientState()
	if self.parent then
		self.parent:Hide()
	end
	if self.roleSummaryHost then
		self.roleSummaryHost:Hide()
	end
	if self.activeRoleDisplay then
		self.activeRoleDisplay:Hide()
	end
end
