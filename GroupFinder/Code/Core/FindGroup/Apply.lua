local addonName, GF = ...

GF.Apply = {}
local AP = GF.Apply

AP.DBLCLICK_SEC = 0.3

local VALID_MODES = { "manual", "click_confirm", "dblclick_auto" }

local function isKnownApplyMode(candidate)
	for _, mode in ipairs(VALID_MODES) do
		if candidate == mode then
			return true
		end
	end
	return false
end

local function getAuthoritativeResultInfo(resultID)
	local resultService = GF.Result
	if resultService and type(resultService.GetAuthoritativeSearchResultInfo) == "function" then
		local cachedInfo = resultService:GetAuthoritativeSearchResultInfo(resultID)
		if cachedInfo ~= nil then
			return cachedInfo
		end
	end
	if C_LFGList and type(C_LFGList.GetSearchResultInfo) == "function" then
		local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
		return ok and info or nil
	end
	return nil
end

local function getNativeResultInfo(resultID)
	local getter = C_LFGList and C_LFGList.GetSearchResultInfo
	if resultID == nil or type(getter) ~= "function" then
		return nil
	end
	if type(C_LFGList.HasSearchResultInfo) == "function" then
		local ok, hasInfo = pcall(C_LFGList.HasSearchResultInfo, resultID)
		if ok ~= true or hasInfo ~= true then
			return nil
		end
	end
	local ok, info = pcall(getter, resultID)
	if ok == true then
		return info
	end
	return nil
end

function AP:NormalizeMode(mode)
	if isKnownApplyMode(mode) then
		return mode
	end
	return "manual"
end

function AP:GetMode()
	local db = GF.GetDB()
	return self:NormalizeMode(db.applyMode)
end

function AP:ResolveApplyTarget(index, resultID)
	local resultService = GF.Result
	local numericID = tonumber(resultID)
	if numericID and numericID > 0
		and resultService
		and type(resultService.GetIndexForResultID) == "function"
	then
		local currentIndex = resultService:GetIndexForResultID(numericID)
		if currentIndex ~= nil then
			return currentIndex, numericID
		end
		return nil, numericID, "stale"
	end
	local numericIndex = tonumber(index)
	if numericIndex and resultService
		and type(resultService.GetResultID) == "function"
	then
		local indexedID = resultService:GetResultID(numericIndex)
		if indexedID ~= nil then
			return numericIndex, indexedID
		end
	end
	return nil, nil, "missing"
end

function AP:IsDelisted(index, resultID)
	local _, resolvedID = self:ResolveApplyTarget(index, resultID)
	if resolvedID == nil then
		return true
	end
	local resultService = GF.Result
	local cached = resultService and resultService.entryCache
		and resultService.entryCache[resolvedID] or nil
	if cached and cached.info
		and type(resultService.IsSoftUnavailable) == "function"
		and resultService:IsSoftUnavailable(cached.info)
	then
		return true
	end
	local info = getNativeResultInfo(resolvedID)
	if info == nil then
		return true
	end
	if resultService
		and type(resultService.ShouldHideUnavailableResult) == "function"
		and resultService:ShouldHideUnavailableResult(resolvedID, info)
	then
		return true
	end
	return info.isDelisted == true
end

function AP:CanSelectRow(index, resultID)
	local resolvedIndex, resolvedID = self:ResolveApplyTarget(index, resultID)
	if resolvedIndex == nil
		or self:IsCurrentGroupResult(resolvedID)
		or self:IsDelisted(resolvedIndex, resolvedID)
	then
		return false
	end
	return resolvedID == nil or not self:HasApplication(resolvedID)
end

-- Application projection combines native status with short-lived local UI state.
-- Party-scoped rejection memory survives result-ID churn during a search refresh.

local INACTIVE_APP = { cancelled = true, failed = true, declined = true, timedout = true, invitedeclined = true, inviteaccepted = true }
local LOCAL_CANCELLED_DISPLAY_SECONDS = 2

local function isDeclinedStatus(status)
	return status == "declined" or status == "declined_delisted" or status == "declined_full"
end

local function isInactiveStatus(status)
	if status and INACTIVE_APP[status] then
		return true
	end
	if LFGListUtil_IsStatusInactive then
		return LFGListUtil_IsStatusInactive(status)
	end
	return false
end

local function isApplicationStatus(appStatus, pendingStatus)
	return (appStatus ~= nil and appStatus ~= "none") or pendingStatus ~= nil
end

local function isJoinedStatus(status)
	return status == "invited" or status == "inviteaccepted"
end

local function normalizeResultID(resultID)
	resultID = tonumber(resultID)
	if resultID and resultID > 0 then
		return resultID
	end
	return nil
end

local function isPlayerInHomeGroup()
	if IsInGroup then
		local ok, inGroup
		if LE_PARTY_CATEGORY_HOME ~= nil then
			ok, inGroup = pcall(IsInGroup, LE_PARTY_CATEGORY_HOME)
		else
			ok, inGroup = pcall(IsInGroup)
		end
		if ok then
			return inGroup == true
		end
	end
	if GetNumGroupMembers then
		local ok, count
		if LE_PARTY_CATEGORY_HOME ~= nil then
			ok, count = pcall(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME)
		else
			ok, count = pcall(GetNumGroupMembers)
		end
		return ok and (tonumber(count) or 0) > 0
	end
	return false
end

local function isHomePartyCategory(category)
	return category == (LE_PARTY_CATEGORY_HOME or 1)
end

local function readResultField(owner, key)
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ReadField) == "function" then
		return snapshot.ReadField(owner, key)
	end
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	end
	if type(issecretvalue) == "function" then
		local secretOK, secret = pcall(issecretvalue, value)
		if secretOK and secret == true then
			return nil, "secret"
		end
	end
	return value, value == nil and "missing" or "value"
end

local function usablePartyGUID(value)
	if value == nil then
		return nil
	end
	if type(value) == "string" and value == "" then
		return nil
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if ok and secret == true then
			return nil
		end
	end
	return value
end

local function resultPartyGUID(info)
	local value, state = readResultField(info, "partyGUID")
	return state == "value" and usablePartyGUID(value) or nil
end

local function queryCurrentGroupPartyGUID()
	if not (C_SocialQueue and type(C_SocialQueue.GetGroupForPlayer) == "function")
		or type(UnitGUID) ~= "function"
	then
		return nil
	end
	local guidOK, playerGUID = pcall(UnitGUID, "player")
	playerGUID = guidOK and usablePartyGUID(playerGUID) or nil
	if not playerGUID then
		return nil
	end
	local ok, partyGUID = pcall(C_SocialQueue.GetGroupForPlayer, playerGUID)
	return ok and usablePartyGUID(partyGUID) or nil
end

function AP:GetCurrentGroupPartyGUID()
	if not isPlayerInHomeGroup() then
		return nil
	end
	local partyGUID = usablePartyGUID(self.currentGroupPartyGUID)
	if not partyGUID then
		partyGUID = queryCurrentGroupPartyGUID()
		if partyGUID then
			self.currentGroupPartyGUID = partyGUID
		end
	end
	return partyGUID
end

function AP:SetCurrentGroupResultID(resultID, info)
	resultID = normalizeResultID(resultID)
	if not resultID then
		return false
	end
	local changed = self.currentGroupResultID ~= resultID
	local previousID = self.currentGroupResultID
	if previousID and previousID ~= resultID then
		changed = self:SuppressJoinedApplication(previousID) or changed
	end
	self.currentGroupResultID = resultID
	if self.suppressedJoinedApplications then
		self.suppressedJoinedApplications[resultID] = nil
	end
	self:TrackJoinedApplication(resultID, "inviteaccepted", true, true)
	local tracked = self.joinedApplications and self.joinedApplications[resultID]
	if tracked then
		tracked.currentGroupConfirmed = true
	end
	local partyGUID = resultPartyGUID(info)
	if partyGUID and self.currentGroupPartyGUID ~= partyGUID then
		self.currentGroupPartyGUID = partyGUID
		changed = true
	end
	return changed
end

function AP:IsCurrentGroupResult(resultID, info)
	resultID = normalizeResultID(resultID)
	if not resultID or not isPlayerInHomeGroup() then
		return false
	end
	if self.suppressedJoinedApplications
		and self.suppressedJoinedApplications[resultID]
	then
		return false
	end
	info = info or getAuthoritativeResultInfo(resultID)
	local currentPartyGUID = self:GetCurrentGroupPartyGUID()
	local searchPartyGUID = resultPartyGUID(info)
	if currentPartyGUID and searchPartyGUID then
		return currentPartyGUID == searchPartyGUID
	end
	if self.currentGroupResultID == resultID then
		return true
	end
	local tracked = self.joinedApplications and self.joinedApplications[resultID]
	if tracked and tracked.currentGroupConfirmed == true then
		return true
	end
	local hasSelf, state = readResultField(info, "hasSelf")
	return state == "value" and hasSelf == true
end

function AP:QueueCurrentGroupRefresh()
	if self._currentGroupRefreshQueued then
		return false
	end
	self._currentGroupRefreshQueued = true
	local queuedPanel = GF.BrowsePanel
	local queuedSearchToken = queuedPanel and queuedPanel._searchToken
	local queuedSearchKey = queuedPanel and queuedPanel.activeSearchKey
	local function flush()
		AP._currentGroupRefreshQueued = nil
		local currentPanel = GF.BrowsePanel
		if queuedPanel and (
			currentPanel ~= queuedPanel
			or currentPanel._searchToken ~= queuedSearchToken
			or currentPanel.activeSearchKey ~= queuedSearchKey
			or currentPanel.awaitingGFSearch == true
		) then
			return
		end
		AP:RefreshApplicationDisplays(true, true)
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, flush)
	else
		flush()
	end
	return true
end

function AP:OnJoinedGroup(resultID)
	resultID = normalizeResultID(resultID)
	if not resultID then
		return false
	end
	local changed = self:SetCurrentGroupResultID(
		resultID, getAuthoritativeResultInfo(resultID))
	self._wasInHomeGroup = isPlayerInHomeGroup()
	self:QueueCurrentGroupRefresh()
	return changed
end

function AP:OnGroupJoined(category, partyGUID)
	if not isHomePartyCategory(category) then
		return false
	end
	partyGUID = usablePartyGUID(partyGUID)
	local changed = self._wasInHomeGroup ~= true
	local previousGUID = usablePartyGUID(self.currentGroupPartyGUID)
	if partyGUID and previousGUID and partyGUID ~= previousGUID then
		if self.currentGroupResultID then
			changed = self:SuppressJoinedApplication(self.currentGroupResultID) or changed
		end
		self.currentGroupResultID = nil
	end
	if partyGUID and partyGUID ~= previousGUID then
		self.currentGroupPartyGUID = partyGUID
		changed = true
	end
	self._wasInHomeGroup = true
	if changed then
		self:QueueCurrentGroupRefresh()
	end
	return changed
end

function AP:OnGroupLeft(category, partyGUID)
	if not isHomePartyCategory(category) then
		return false
	end
	partyGUID = usablePartyGUID(partyGUID)
	local currentGUID = usablePartyGUID(self.currentGroupPartyGUID)
	if partyGUID and currentGUID and partyGUID ~= currentGUID then
		return false
	end
	local changed = self._wasInHomeGroup == true
	if self.currentGroupResultID then
		changed = self:SuppressJoinedApplication(self.currentGroupResultID) or changed
	end
	if self.joinedApplications then
		local observedIDs = {}
		for resultID, entry in pairs(self.joinedApplications) do
			if entry and entry.observedGroup == true then
				observedIDs[#observedIDs + 1] = resultID
			end
		end
		for _, resultID in ipairs(observedIDs) do
			changed = self:SuppressJoinedApplication(resultID) or changed
		end
	end
	self.currentGroupResultID = nil
	self.currentGroupPartyGUID = nil
	self._wasInHomeGroup = false
	if changed then
		self:QueueCurrentGroupRefresh()
	end
	return changed
end

function AP:TrackJoinedApplication(resultID, status, observedGroup, acceptRequested)
	resultID = normalizeResultID(resultID)
	if not resultID then
		return false
	end
	self.joinedApplications = self.joinedApplications or {}
	local entry = self.joinedApplications[resultID] or {}
	entry.status = status or entry.status
	entry.observedGroup = entry.observedGroup or observedGroup == true
	entry.acceptRequested = entry.acceptRequested or acceptRequested == true
	self.joinedApplications[resultID] = entry
	return true
end

function AP:ClearJoinedApplication(resultID)
	resultID = normalizeResultID(resultID)
	if not resultID then
		return
	end
	if self.joinedApplications then
		self.joinedApplications[resultID] = nil
	end
	if self.suppressedJoinedApplications then
		self.suppressedJoinedApplications[resultID] = nil
	end
end

function AP:IsJoinedApplicationTracked(resultID)
	resultID = normalizeResultID(resultID)
	if not resultID then
		return false
	end
	return self.currentGroupResultID == resultID
		or (self.joinedApplications and self.joinedApplications[resultID] ~= nil)
		or (self.suppressedJoinedApplications
			and self.suppressedJoinedApplications[resultID] == true)
end

function AP:SuppressJoinedApplication(resultID)
	resultID = normalizeResultID(resultID)
	if not resultID then
		return false
	end
	self.suppressedJoinedApplications = self.suppressedJoinedApplications or {}
	if self.suppressedJoinedApplications[resultID] then
		return false
	end
	self.suppressedJoinedApplications[resultID] = true
	if self.joinedApplications then
		self.joinedApplications[resultID] = nil
	end
	return true
end

function AP:IsJoinedApplicationSuppressed(resultID, appStatus, pendingStatus)
	resultID = normalizeResultID(resultID)
	if not resultID or not self.suppressedJoinedApplications or not self.suppressedJoinedApplications[resultID] then
		return false
	end
	if isJoinedStatus(appStatus) or isJoinedStatus(pendingStatus) then
		return true
	end
	self.suppressedJoinedApplications[resultID] = nil
	return false
end

function AP:MarkApplicationCancelled(resultID)
	if resultID == nil then
		return
	end
	self.localCancelled = self.localCancelled or {}
	self.localCancelledTokens = self.localCancelledTokens or {}
	self.localCancelled[resultID] = GetTime() + LOCAL_CANCELLED_DISPLAY_SECONDS
	local token = 1 + (self.localCancelledTokens[resultID] or 0)
	self.localCancelledTokens[resultID] = token
	if not C_Timer or type(C_Timer.After) ~= "function" then
		return
	end
	local function clearExpiredCancellation()
		local tokens = AP.localCancelledTokens
		if not tokens or tokens[resultID] ~= token then
			return
		end
		tokens[resultID] = nil
		if AP.localCancelled then
			AP.localCancelled[resultID] = nil
		end
		local tab = GF.FindGroupTab
		if tab and type(tab.UpdateRowByResultID) == "function" then
			tab:UpdateRowByResultID(resultID)
		end
	end
	C_Timer.After(LOCAL_CANCELLED_DISPLAY_SECONDS, clearExpiredCancellation)
end

local function appendUniqueResultIDs(target, seen, source)
	if type(source) ~= "table" then
		return
	end
	for _, candidate in ipairs(source) do
		local resultID = normalizeResultID(candidate)
		if resultID and not seen[resultID] then
			seen[resultID] = true
			target[#target + 1] = resultID
		end
	end
end

local RejectionLedger = {}
RejectionLedger.__index = RejectionLedger

local function rejectionLedger(owner)
	local ledger = owner._rejectionLedger
	if ledger == nil then
		ledger = setmetatable({ records = {}, signals = {} }, RejectionLedger)
		owner._rejectionLedger = ledger
	end
	return ledger
end

function RejectionLedger:GetRecord(partyGUID, create)
	if partyGUID == nil then
		return nil
	end
	local record = self.records[partyGUID]
	if record == nil and create == true then
		record = { revision = 0, retryReady = false }
		self.records[partyGUID] = record
	end
	return record
end

function RejectionLedger:GetRevision(partyGUID)
	local record = self:GetRecord(partyGUID, false)
	return record and record.revision or 0
end

function RejectionLedger:GetStatus(partyGUID)
	local record = self:GetRecord(partyGUID, false)
	return record and record.status or nil
end

function RejectionLedger:SeedNativeDecline(partyGUID, status)
	local record = self:GetRecord(partyGUID, false)
	if record == nil then
		record = self:GetRecord(partyGUID, true)
		record.status = status
	end
	return record.revision
end

function RejectionLedger:IsRetryReady(partyGUID)
	local record = self:GetRecord(partyGUID, false)
	return record ~= nil and record.retryReady == true
end

function RejectionLedger:Remember(partyGUID, status)
	local record = self:GetRecord(partyGUID, true)
	record.revision = record.revision + 1
	record.status = status
	record.retryReady = false
	return record.revision
end

function RejectionLedger:Unlock(partyGUID, expectedRevision)
	local record = self:GetRecord(partyGUID, false)
	if record == nil or record.revision ~= expectedRevision then
		return false, false
	end
	local newlyUnlocked = record.retryReady ~= true
	record.retryReady = true
	record.status = nil
	return true, newlyUnlocked
end

function RejectionLedger:ResetRetryPermissions()
	for _, record in pairs(self.records) do
		record.retryReady = false
	end
end

function RejectionLedger:RemoveSignal(resultID, expected, keepTimer)
	local entry = self.signals[resultID]
	if entry == nil or (expected ~= nil and entry ~= expected) then
		return false
	end
	self.signals[resultID] = nil
	local timer = entry.timer
	entry.timer = nil
	if keepTimer ~= true and timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
	return true
end

function RejectionLedger:ClearSignals(partyGUID)
	local cleared = false
	for resultID, entry in pairs(self.signals) do
		if partyGUID == nil or entry.partyGUID == partyGUID then
			cleared = self:RemoveSignal(resultID, entry, false) or cleared
		end
	end
	return cleared
end

function AP:IsRetryAllowed(resultID, resultInfo)
	resultID = normalizeResultID(resultID)
	resultInfo = resultInfo or (resultID and getAuthoritativeResultInfo(resultID))
	local partyGUID = resultPartyGUID(resultInfo)
	return rejectionLedger(self):IsRetryReady(partyGUID)
end

function AP:SnapshotRejectedParties()
	local resultService = GF.Result
	local resultIDs, seen = {}, {}
	if resultService then
		appendUniqueResultIDs(resultIDs, seen, resultService.resultIDs)
		appendUniqueResultIDs(resultIDs, seen, resultService.apiResultIDs)
		appendUniqueResultIDs(resultIDs, seen, resultService.frozenOrder)
	end

	local captured = {}
	for _, resultID in ipairs(resultIDs) do
		local resultInfo = getAuthoritativeResultInfo(resultID)
		local partyGUID = resultPartyGUID(resultInfo)
		local ledger = rejectionLedger(self)
		local rememberedStatus = ledger:GetStatus(partyGUID)
		local nativeDeclined = false
		local nativeStatus
		if C_LFGList and type(C_LFGList.GetApplicationInfo) == "function" then
			local ok, _, appStatus = pcall(C_LFGList.GetApplicationInfo, resultID)
			nativeDeclined = ok == true and isDeclinedStatus(appStatus)
			nativeStatus = nativeDeclined and appStatus or nil
		end
		if nativeDeclined or isDeclinedStatus(rememberedStatus) then
			if partyGUID then
				captured[partyGUID] = nativeDeclined
					and ledger:SeedNativeDecline(partyGUID, nativeStatus)
					or ledger:GetRevision(partyGUID)
			end
		end
	end
	return next(captured) ~= nil and captured or nil
end

function AP:ApplyManualRefreshUnlocks(captured, resultIDs)
	if type(captured) ~= "table" or type(resultIDs) ~= "table" then
		return 0
	end
	local ledger = rejectionLedger(self)
	local unlocked = 0
	for _, resultID in ipairs(resultIDs) do
		local resultInfo = getAuthoritativeResultInfo(resultID)
		local partyGUID = resultPartyGUID(resultInfo)
		local capturedRevision = partyGUID and captured[partyGUID]
		if capturedRevision ~= nil then
			local matched, newlyUnlocked = ledger:Unlock(partyGUID, capturedRevision)
			if matched and newlyUnlocked then
				unlocked = unlocked + 1
			end
		end
	end
	self:ClearRejectionFeedback()
	return unlocked
end

function AP:GetApplicationState(resultID)
	if resultID == nil or type(C_LFGList.GetApplicationInfo) ~= "function" then
		return nil
	end
	local _, appStatus, pendingStatus, appDuration =
		C_LFGList.GetApplicationInfo(resultID)
	local isDepartedApplication =
		self:IsJoinedApplicationSuppressed(resultID, appStatus, pendingStatus)
	local cancelledUntil = self.localCancelled and self.localCancelled[resultID]
	local showLocalCancellation = cancelledUntil ~= nil
		and cancelledUntil > GetTime()
	if cancelledUntil and not showLocalCancellation then
		self.localCancelled[resultID] = nil
	end
	local resultInfo = getAuthoritativeResultInfo(resultID)
	local partyGUID = resultPartyGUID(resultInfo)
	local declined = isDeclinedStatus(appStatus)
	local rememberedDecline = rejectionLedger(self):GetStatus(partyGUID)
	if not declined and rememberedDecline ~= nil then
		appStatus = rememberedDecline
		declined = true
	end
	if declined and rememberedDecline == nil
		and self:IsRetryAllowed(resultID, resultInfo)
	then
		appStatus = "none"
		declined = false
	end
	local present = isApplicationStatus(appStatus, pendingStatus)
	if showLocalCancellation and not present then
		appStatus = "cancelled"
		present = true
	end
	local finished = declined
		or isInactiveStatus(appStatus)
		or isInactiveStatus(pendingStatus)
	return {
		appStatus = appStatus,
		pendingStatus = pendingStatus,
		appDuration = appDuration,
		isDeclined = declined,
		isApplication = present,
		isActiveApp = present and not finished,
		isDepartedApplication = isDepartedApplication,
	}
end

function AP:HasApplication(resultID)
	local state = self:GetApplicationState(resultID)
	return state ~= nil and state.isApplication == true
end

function AP:IsDeclinedApplication(resultID)
	local state = self:GetApplicationState(resultID)
	return state ~= nil and state.isDeclined == true
end

function AP:HasActiveApplication()
	if type(C_LFGList.GetApplications) ~= "function"
		or type(C_LFGList.GetApplicationInfo) ~= "function"
	then
		return false
	end
	for _, applicationID in ipairs(C_LFGList.GetApplications() or {}) do
		local state = self:GetApplicationState(applicationID)
		if state and state.isActiveApp == true then
			return true
		end
	end
	return false
end

function AP:GetActiveApplicationCount()
	if type(C_LFGList.GetApplications) ~= "function"
		or type(C_LFGList.GetApplicationInfo) ~= "function"
	then
		return 0
	end
	local count = 0
	for _, applicationID in ipairs(C_LFGList.GetApplications() or {}) do
		local state = self:GetApplicationState(applicationID)
		if state and state.isActiveApp == true then
			count = count + 1
		end
	end
	return count
end

function AP:ShouldPinApplication(resultID)
	local state = self:GetApplicationState(resultID)
	if not state or state.isApplication ~= true then
		return false
	end
	return state.isDeclined == true or not isInactiveStatus(state.appStatus)
end

local function currentFeedbackScope()
	local panel = GF.BrowsePanel
	if type(panel) ~= "table"
		or panel.awaitingGFSearch == true
		or panel.gfOwnsSearch ~= true
	then
		return nil
	end
	if type(panel.ShouldProcessSearchUpdates) == "function"
		and panel:ShouldProcessSearchUpdates() ~= true
	then
		return nil
	end
	local activeKey = panel.activeSearchKey
	local selectionKey = type(panel.GetSelectionKey) == "function"
		and panel:GetSelectionKey() or nil
	if activeKey == nil or activeKey ~= selectionKey then
		return nil
	end
	return {
		searchToken = panel._searchToken,
		activeKey = activeKey,
	}
end

local function feedbackScopeMatches(entry)
	if type(entry) ~= "table" then
		return false
	end
	local current = currentFeedbackScope()
	return current ~= nil
		and current.searchToken == entry.searchToken
		and current.activeKey == entry.activeKey
end

local function feedbackEntryMatches(owner, resultID, entry, ignoreDeadline)
	if type(entry) ~= "table"
		or not feedbackScopeMatches(entry)
	then
		return false
	end
	if not ignoreDeadline then
		local expiresAt = tonumber(entry.expiresAt)
		if expiresAt == nil or expiresAt <= GetTime() then
			return false
		end
	end
	local resultInfo = getAuthoritativeResultInfo(resultID)
	local partyGUID = resultPartyGUID(resultInfo)
	if partyGUID == nil or partyGUID ~= entry.partyGUID then
		return false
	end
	local revision = rejectionLedger(owner):GetRevision(partyGUID)
	return revision == entry.revision
end

local function removeRejectionFeedback(owner, resultID, expectedEntry, keepTimer)
	resultID = normalizeResultID(resultID)
	return resultID ~= nil
		and rejectionLedger(owner):RemoveSignal(resultID, expectedEntry, keepTimer)
		or false
end

function AP:ClearRejectionFeedback(partyGUID)
	return rejectionLedger(self):ClearSignals(partyGUID)
end

function AP:HasRejectionFeedback(resultID)
	resultID = normalizeResultID(resultID)
	local ledger = rejectionLedger(self)
	local entry = resultID and ledger.signals[resultID] or nil
	if entry == nil then
		return false
	end
	if not feedbackEntryMatches(self, resultID, entry, false) then
		ledger:RemoveSignal(resultID, entry, false)
		return false
	end
	return true
end

local function startRejectionFeedback(owner, resultID, partyGUID, revision)
	resultID = normalizeResultID(resultID)
	local context = currentFeedbackScope()
	local resultService = GF.Result
	if resultID == nil or partyGUID == nil or context == nil
		or not C_Timer or type(C_Timer.NewTimer) ~= "function"
		or not resultService
		or type(resultService.IsFrozenResult) ~= "function"
		or resultService:IsFrozenResult(resultID) ~= true
	then
		return false
	end
	local ledger = rejectionLedger(owner)
	ledger:ClearSignals(partyGUID)
	ledger:RemoveSignal(resultID, nil, false)
	local delay = GF.BROWSE_DECLINED_FILTER_FEEDBACK_SECONDS or 0.8
	local entry = {
		partyGUID = partyGUID,
		revision = revision,
		searchToken = context.searchToken,
		activeKey = context.activeKey,
		expiresAt = GetTime() + delay,
	}
	ledger.signals[resultID] = entry
	if type(resultService.InvalidateAsyncJobs) == "function" then
		resultService:InvalidateAsyncJobs()
	end
	entry.timer = C_Timer.NewTimer(delay, function()
		entry.timer = nil
		local activeLedger = rejectionLedger(AP)
		if activeLedger.signals[resultID] ~= entry then
			return
		end
		local shouldReapply = feedbackEntryMatches(AP, resultID, entry, true)
		activeLedger:RemoveSignal(resultID, entry, true)
		if shouldReapply and GF.FindGroupTab
			and type(GF.FindGroupTab.ApplyClientFilters) == "function"
		then
			GF.FindGroupTab:ApplyClientFilters()
		end
	end)
	return true
end

local function observeRejectedApplication(owner, resultID, status)
	local resultInfo = getAuthoritativeResultInfo(resultID)
	local partyGUID = resultPartyGUID(resultInfo)
	local ledger = rejectionLedger(owner)
	local revision
	if partyGUID then
		revision = ledger:Remember(partyGUID, status)
		ledger:ClearSignals(partyGUID)
	else
		ledger:ClearSignals()
		ledger:ResetRetryPermissions()
		local browsePanel = GF.BrowsePanel
		if browsePanel
			and type(browsePanel.DiscardPendingManualDeclineIntent) == "function"
		then
			browsePanel:DiscardPendingManualDeclineIntent()
		elseif browsePanel
			and type(browsePanel.DiscardManualDeclineRefresh) == "function"
		then
			browsePanel:DiscardManualDeclineRefresh()
		end
	end
	startRejectionFeedback(owner, resultID, partyGUID, revision)
end

function AP:OnApplicationStatusUpdated(resultID, newStatus)
	if resultID == nil then
		return
	end
	local joined = isJoinedStatus(newStatus)
	if joined then
		local normalizedID = normalizeResultID(resultID)
		if newStatus == "invited" then
			resultID = normalizedID or resultID
			if normalizedID and self.suppressedJoinedApplications then
				self.suppressedJoinedApplications[normalizedID] = nil
			end
			self:TrackJoinedApplication(resultID, newStatus, false, false)
			self:InitInviteDialogHooks()
			self:TryAutoAcceptInvite()
		else
			local observedGroup = isPlayerInHomeGroup()
			self:TrackJoinedApplication(resultID, newStatus, observedGroup, true)
			if observedGroup then
				self._wasInHomeGroup = true
			end
		end
	else
		self:ClearJoinedApplication(resultID)
	end
	local declined = isDeclinedStatus(newStatus)
	if newStatus ~= "inviteaccepted" and isInactiveStatus(newStatus) and not declined then
		self:MarkApplicationCancelled(resultID)
	end
	if not declined then
		if not self:IsDeclinedApplication(resultID) then
			removeRejectionFeedback(self, resultID)
		end
		return false
	end
	observeRejectedApplication(self, resultID, newStatus)
	return false
end

function AP:RefreshApplicationDisplays(resort, reapplyFilters)
	local function refreshControls()
		if GF.SubtitleBar and GF.SubtitleBar.UpdateSignUpButtonState then
			GF.SubtitleBar:UpdateSignUpButtonState()
		end
		if GF.FloatButton and GF.FloatButton.RefreshAlert then
			GF.FloatButton:RefreshAlert()
		end
	end

	if reapplyFilters and GF.FindGroupTab
		and type(GF.FindGroupTab.ApplyClientFilters) == "function"
	then
		GF.FindGroupTab:ApplyClientFilters()
		refreshControls()
		return
	end

	if resort and GF.Result and GF.Result.resultIDs and GF.Result.SortResults
		and GF.FindGroupTab and GF.FindGroupTab.RefreshList then
		GF.Result:SortResults(nil, function()
			if GF.FindGroupTab and GF.FindGroupTab.RefreshList then
				GF.FindGroupTab:RefreshList({ preserveScroll = true })
			end
			refreshControls()
		end)
		return
	end

	if GF.FindGroupTab and GF.FindGroupTab.ForEachVisibleRow and GF.ListRow then
		GF.FindGroupTab:ForEachVisibleRow(function(row)
			if row and row.resultID then
				GF.ListRow:ApplyApplicationState(row, row.resultID)
				GF.ListRow:UpdateRowBackgrounds(row)
			end
		end)
	end
	refreshControls()
end

function AP:OnGroupRosterChanged()
	local inGroup = isPlayerInHomeGroup()
	local changed = self._wasInHomeGroup ~= nil
		and self._wasInHomeGroup ~= inGroup
	self._wasInHomeGroup = inGroup
	if not inGroup then
		if self.currentGroupResultID then
			changed = self:SuppressJoinedApplication(self.currentGroupResultID) or changed
		end
		if self.currentGroupResultID ~= nil or self.currentGroupPartyGUID ~= nil then
			changed = true
		end
		self.currentGroupResultID = nil
		self.currentGroupPartyGUID = nil
	end
	local canReadApplications = C_LFGList
		and type(C_LFGList.GetApplications) == "function"
		and type(C_LFGList.GetApplicationInfo) == "function"
	if not canReadApplications then
		if changed then
			self:QueueCurrentGroupRefresh()
		end
		return changed
	end
	local seen = {}
	local apps = C_LFGList.GetApplications() or {}
	for i = 1, #apps do
		local resultID = normalizeResultID(apps[i])
		if resultID then
			seen[resultID] = true
			local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo(resultID)
			local joined = isJoinedStatus(appStatus) or isJoinedStatus(pendingStatus)
			local accepted = appStatus == "inviteaccepted" or pendingStatus == "inviteaccepted"
			local tracked = self.joinedApplications and self.joinedApplications[resultID]
			if joined and (accepted or tracked) then
				local wasObserved = tracked and tracked.observedGroup == true
				self:TrackJoinedApplication(resultID, appStatus or pendingStatus, inGroup and (accepted or (tracked and tracked.acceptRequested)), tracked and tracked.acceptRequested)
				tracked = self.joinedApplications and self.joinedApplications[resultID]
				if inGroup and tracked and (accepted or tracked.acceptRequested) then
					tracked.observedGroup = true
					if not wasObserved then
						changed = true
					end
				elseif not inGroup and tracked and (tracked.observedGroup or accepted) then
					changed = self:SuppressJoinedApplication(resultID) or changed
				end
			elseif tracked then
				self:ClearJoinedApplication(resultID)
			end
		end
	end
	if not inGroup and self.joinedApplications then
		for resultID, entry in pairs(self.joinedApplications) do
			if not seen[resultID] and entry and entry.observedGroup then
				changed = self:SuppressJoinedApplication(resultID) or changed
			end
		end
	end
	if changed then
		self:QueueCurrentGroupRefresh()
	end
	return changed
end

function AP:CancelApplication(resultID)
	local api = C_LFGList or {}
	local cancel = api.CancelApplication or api.WithdrawApplication
	if resultID == nil or type(cancel) ~= "function" then
		local locale = GF.L or {}
		return false, locale.APPLY_CANCEL_UNAVAILABLE or "取消申请接口不可用。"
	end
	local ok, reason = pcall(cancel, resultID)
	if ok ~= true then
		return false, tostring(reason or ((GF.L or {}).APPLY_CANCEL_FAILED or "取消申请失败。"))
	end
	self:MarkApplicationCancelled(resultID)
	local tab = GF.FindGroupTab
	if tab and type(tab.OnApplicationStatusUpdated) == "function" then
		tab:OnApplicationStatusUpdated(resultID, "cancelled")
	end
	return true
end

function AP:PinApplicationsToTop(ids, topID)
	local applicationIDs = C_LFGList and type(C_LFGList.GetApplications) == "function"
		and C_LFGList.GetApplications() or {}
	local hidesDeclined = GF.Result
		and type(GF.Result.ShouldHideDeclinedApplications) == "function"
		and GF.Result:ShouldHideDeclinedApplications() == true
	local inputSet = {}
	for _, resultID in ipairs(type(ids) == "table" and ids or {}) do
		inputSet[resultID] = true
	end
	local pinnedOrder, pinnedSet = {}, {}
	local function addPinned(candidateID)
		if candidateID == nil or pinnedSet[candidateID] then
			return
		end
		local state = self:GetApplicationState(candidateID)
		if not state or state.isApplication ~= true
			or (state.isDeclined == true and hidesDeclined
				and inputSet[candidateID] ~= true
				and candidateID ~= topID)
			or (state.isDeclined ~= true and isInactiveStatus(state.appStatus))
		then
			return
		end
		pinnedSet[candidateID] = true
		pinnedOrder[#pinnedOrder + 1] = candidateID
	end
	for _, applicationID in ipairs(applicationIDs) do
		addPinned(applicationID)
	end
	addPinned(topID)
	local currentOrder, currentSet = {}, {}
	for _, resultID in ipairs(type(ids) == "table" and ids or {}) do
		if self:IsCurrentGroupResult(resultID) then
			currentSet[resultID] = true
			currentOrder[#currentOrder + 1] = resultID
		end
	end
	if #pinnedOrder == 0 and #currentOrder == 0 then
		return ids
	end
	local ordered, orderedSet = {}, {}
	local function append(resultID)
		if resultID ~= nil and not orderedSet[resultID] then
			orderedSet[resultID] = true
			ordered[#ordered + 1] = resultID
		end
	end
	for _, currentID in ipairs(currentOrder) do
		append(currentID)
	end
	if topID ~= nil and pinnedSet[topID] and not currentSet[topID] then
		append(topID)
	end
	for _, pinnedID in ipairs(pinnedOrder) do
		if not currentSet[pinnedID] then
			append(pinnedID)
		end
	end
	for _, resultID in ipairs(type(ids) == "table" and ids or {}) do
		if not pinnedSet[resultID] and not currentSet[resultID] then
			append(resultID)
		end
	end
	return ordered
end

function AP:StopExpiryTicker()
	local ticker = self._expiryTicker
	self._expiryTicker = nil
	if ticker and type(ticker.Cancel) == "function" then
		ticker:Cancel()
	end
end

function AP:EnsureExpiryTicker()
	if self._expiryTicker ~= nil
		or not C_Timer
		or type(C_Timer.NewTicker) ~= "function"
	then
		return
	end
	local function updateVisibleExpiries()
		local tab = GF.FindGroupTab
		local rows = GF.ListRow
		if not tab or type(tab.ForEachVisibleRow) ~= "function"
			or not rows or type(rows.TickExpiry) ~= "function"
		then
			AP:StopExpiryTicker()
			return
		end
		local foundExpiry = false
		tab:ForEachVisibleRow(function(row)
			if row and row._appExpiryShown then
				foundExpiry = true
				rows:TickExpiry(row)
			end
		end)
		if not foundExpiry then
			AP:StopExpiryTicker()
		end
	end
	self._expiryTicker = C_Timer.NewTicker(1, updateVisibleExpiries)
end

-- =============================================================================
-- 申请流程：申请模式、暴雪弹窗/自动申请、取消最旧、行点击、备注缓存、自动接受邀请
-- =============================================================================

function AP:IsAutoAcceptInviteEnabled()
	local db = GF.GetDB()
	return db.autoAcceptInvite == true
end

function AP:InitInviteDialogHooks()
	if self._inviteDialogHooked == true then
		return true
	end
	if not LFGListInviteDialog and type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local dialog = LFGListInviteDialog
	local button = dialog and dialog.AcceptButton
	if button == nil or type(button.HookScript) ~= "function" then
		return false
	end
	local function trackAcceptedInvite()
		local resultID = dialog.resultID
		if resultID ~= nil then
			AP:TrackJoinedApplication(resultID, "invited", false, true)
		end
	end
	pcall(button.HookScript, button, "PreClick", trackAcceptedInvite)
	pcall(button.HookScript, button, "OnMouseDown", trackAcceptedInvite)
	self._inviteDialogHooked = true
	return true
end

function AP:TryAutoAcceptInvite()
	local apiReady = type(C_LFGList.GetApplications) == "function"
		and type(C_LFGList.GetApplicationInfo) == "function"
		and type(C_LFGList.AcceptInvite) == "function"
	local disallowed = self:IsAutoAcceptInviteEnabled() ~= true
		or self._acceptInFlight == true
		or not apiReady
		or (type(LFGListUtil_IsAppEmpowered) == "function"
			and LFGListUtil_IsAppEmpowered() ~= true)
	if disallowed then
		return
	end
	self._acceptInFlight = true
	for _, applicationID in ipairs(C_LFGList.GetApplications() or {}) do
		local _, status, pendingStatus = C_LFGList.GetApplicationInfo(applicationID)
		if status == "invited" and not pendingStatus then
			self:TrackJoinedApplication(applicationID, status, false, true)
			C_LFGList.AcceptInvite(applicationID)
			break
		end
	end
	self._acceptInFlight = false
end

function AP:IsLfgListRoleCheckActive()
	if not (C_LFGList and C_LFGList.GetRoleCheckInfo and CompleteLFGRoleCheck) then
		return false
	end
	if GetLFGRoleUpdate then
		local okUpdate, inProgress = pcall(GetLFGRoleUpdate)
		if not okUpdate or inProgress ~= true then
			return false
		end
	end
	local okInfo, isLFGList = pcall(C_LFGList.GetRoleCheckInfo)
	return okInfo and isLFGList == true
end

function AP:TryAutoConfirmLfgListRoleCheck()
	if not self:IsAutoAcceptInviteEnabled() then
		return false
	end
	if self._roleCheckConfirmInFlight then
		return false
	end
	if not self:IsLfgListRoleCheckActive() then
		return false
	end
	local tank, healer, dps = self:GetSelectedRoleFlags()
	if not (tank or healer or dps) then
		return false
	end
	if LFDPopupCheckRoleSelectionValid then
		local okValid, valid = pcall(LFDPopupCheckRoleSelectionValid, tank, healer, dps)
		if not okValid or valid ~= true then
			return false
		end
	end
	self._roleCheckConfirmInFlight = true
	local roleOk = true
	if SetLFGRoles and GetLFGRoles then
		local okLeader, leader = pcall(GetLFGRoles)
		roleOk = okLeader and pcall(SetLFGRoles, leader, tank, healer, dps)
	end
	local okComplete, completed = false, false
	if roleOk then
		okComplete, completed = pcall(CompleteLFGRoleCheck, true)
	end
	self._roleCheckConfirmInFlight = false
	if okComplete and completed then
		if StaticPopupSpecial_Hide and LFDRoleCheckPopup then
			StaticPopupSpecial_Hide(LFDRoleCheckPopup)
		end
		return true
	end
	return false
end

function AP:QueueAutoConfirmLfgListRoleCheck()
	if not self:IsAutoAcceptInviteEnabled() then
		return
	end
	self._roleCheckConfirmToken = (self._roleCheckConfirmToken or 0) + 1
	local token = self._roleCheckConfirmToken
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if AP._roleCheckConfirmToken == token then
				AP:TryAutoConfirmLfgListRoleCheck()
			end
		end)
	else
		self:TryAutoConfirmLfgListRoleCheck()
	end
end

function AP:ReportError(msg)
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(msg)
	end
end

function AP:IsChatRestricted()
	return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

function AP:ShouldRememberApplicationNote()
	local db = GF.GetDB and GF.GetDB()
	return db and db.rememberApplicationNote == true
end

function AP:GetApplyNoteBox()
	if LFGListApplicationDialogDescription and LFGListApplicationDialogDescription.EditBox then
		return LFGListApplicationDialogDescription.EditBox
	end
	return nil
end

function AP:IsSuppressingApplyNoteClear()
	local untilTime = tonumber(self._suppressApplyNoteClearUntil)
	if not untilTime then
		return false
	end
	if untilTime > GetTime() then
		return true
	end
	self._suppressApplyNoteClearUntil = nil
	return false
end

function AP:SuppressApplyNoteClear(seconds)
	self._suppressApplyNoteClearUntil = GetTime() + (tonumber(seconds) or 0.5)
end

function AP:CaptureApplyNoteText(text)
	if not self:ShouldRememberApplicationNote() then
		self._cachedNote = ""
		return
	end
	if text == nil then
		local box = self:GetApplyNoteBox()
		if not box or not box.GetText then
			return
		end
		text = box:GetText() or ""
	end
	if issecretvalue and issecretvalue(text) then
		return
	end
	if text == "" and self:IsSuppressingApplyNoteClear() and self._cachedNote and self._cachedNote ~= "" then
		return
	end
	self._cachedNote = text
end

function AP:ClearNativeApplyNote()
	if C_LFGList and C_LFGList.ClearApplicationTextFields then
		pcall(C_LFGList.ClearApplicationTextFields)
	end
	local box = self:GetApplyNoteBox()
	if box and box.SetText then
		pcall(box.SetText, box, "")
	end
end

function AP:ClearApplyNoteState()
	self._cachedNote = ""
	self._suppressApplyNoteClearUntil = nil
	local timer = self._restoreNoteTimer
	self._restoreNoteTimer = nil
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
	self:ClearNativeApplyNote()
end

function AP:SaveCachedNote()
	if self:ShouldRememberApplicationNote() ~= true then
		self._cachedNote = ""
		return
	end
	if self._gfDialog == true then
		self:CaptureApplyNoteText()
	end
end

function AP:RestoreCachedNote()
	local text = self._cachedNote
	if self:ShouldRememberApplicationNote() ~= true
		or type(text) ~= "string"
		or text == ""
		or self:IsChatRestricted()
	then
		return
	end
	local box = self:GetApplyNoteBox()
	if not box or type(box.SetText) ~= "function" then
		return
	end
	if type(box.IsEnabled) == "function" and box:IsEnabled() ~= true then
		return
	end
	if type(issecretvalue) == "function" and issecretvalue(text) then
		return
	end
	pcall(box.SetText, box, text)
end

function AP:ScheduleRestoreCachedNote()
	if self:ShouldRememberApplicationNote() ~= true
		or type(self._cachedNote) ~= "string"
		or self._cachedNote == ""
	then
		return
	end
	if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
		self:RestoreCachedNote()
		return
	end
	local previousTimer = self._restoreNoteTimer
	if previousTimer and type(previousTimer.Cancel) == "function" then
		previousTimer:Cancel()
	end
	local function restoreWhenDialogVisible()
		self._restoreNoteTimer = nil
		local dialog = LFGListApplicationDialog
		if self._gfDialog == true and dialog
			and type(dialog.IsShown) == "function" and dialog:IsShown()
		then
			self:RestoreCachedNote()
		end
	end
	self._restoreNoteTimer = C_Timer.NewTimer(0, restoreWhenDialogVisible)
end

function AP:PrepareApplyNoteFields()
	if self:ShouldRememberApplicationNote() ~= true then
		self:ClearApplyNoteState()
		return
	end
	self:RestoreCachedNote()
end

function AP:GetResultPrimaryActivityID(resultID)
	if resultID == nil then
		return nil
	end
	local resultInfo = getAuthoritativeResultInfo(resultID)
	if type(resultInfo) ~= "table"
		or type(resultInfo.activityIDs) ~= "table"
	then
		return nil
	end
	return tonumber(resultInfo.activityIDs[1])
end

function AP:PrepareDialogApplyNote(resultID)
	if self:ShouldRememberApplicationNote() ~= true then
		self:ClearApplyNoteState()
		return
	end
	if type(self._cachedNote) ~= "string" or self._cachedNote == "" then
		return
	end
	local activityID = self:GetResultPrimaryActivityID(resultID)
	if activityID ~= nil and LFGListApplicationDialog then
		LFGListApplicationDialog.activityID = activityID
	end
	self:SuppressApplyNoteClear(0.5)
end

function AP:Init()
	if self._inited == true then
		return
	end
	self._inited = true
	self._cachedNote = ""
	local dialog = LFGListApplicationDialog
	if dialog == nil then
		return
	end
	local box = self:GetApplyNoteBox()
	if box and type(box.HookScript) == "function" then
		local function onNoteChanged(editBox)
			if AP._gfDialog == true then
				local text = editBox and editBox.GetText and editBox:GetText() or ""
				AP:CaptureApplyNoteText(text)
			end
		end
		box:HookScript("OnTextChanged", onNoteChanged)
	end
	local signUpButton = dialog.SignUpButton
	if signUpButton and type(signUpButton.HookScript) == "function" then
		local function captureBeforeNativeApply()
			if AP._gfDialog ~= true then
				return
			end
			AP:CaptureApplyNoteText()
			AP:SuppressApplyNoteClear(0.5)
		end
		pcall(signUpButton.HookScript, signUpButton, "PreClick", captureBeforeNativeApply)
		pcall(signUpButton.HookScript, signUpButton, "OnMouseDown", captureBeforeNativeApply)
	end
	dialog:HookScript("OnShow", function()
		if AP._gfDialog == true then
			AP:ScheduleRestoreCachedNote()
		end
	end)
	dialog:HookScript("OnHide", function()
		if AP._gfDialog == true then
			AP:SaveCachedNote()
		end
		AP._gfDialog = nil
	end)
end

local ApplicationQuota = {}

function ApplicationQuota:SelectExpiryCandidate()
	local api = C_LFGList or {}
	if type(api.GetApplications) ~= "function"
		or type(api.GetApplicationInfo) ~= "function"
	then
		return nil
	end
	local selectedID, shortestRemaining = nil, math.huge
	local applicationIDs = api.GetApplications() or {}
	for _, applicationID in ipairs(applicationIDs) do
		local _, status, pendingStatus, secondsRemaining = api.GetApplicationInfo(applicationID)
		secondsRemaining = tonumber(secondsRemaining)
		local eligible = status == "applied"
			and not pendingStatus
			and secondsRemaining ~= nil
		if eligible and secondsRemaining < shortestRemaining then
			selectedID = applicationID
			shortestRemaining = secondsRemaining
		end
	end
	return selectedID
end

function ApplicationQuota:ShouldReleaseFor(owner, resultID)
	local db = GF.GetDB and GF.GetDB()
	if not db or db.replaceOldestApplication ~= true or not resultID then
		return false
	end
	local counter = C_LFGList and C_LFGList.GetNumApplications
	if type(counter) ~= "function" then
		return false
	end
	local _, activeCount = counter()
	if not activeCount or not MAX_LFG_LIST_APPLICATIONS
		or activeCount < MAX_LFG_LIST_APPLICATIONS
	then
		return false
	end

	local state = owner:GetApplicationState(resultID)
	if state and state.isApplication == true then
		return false
	end
	local resultInfo = getAuthoritativeResultInfo(resultID)
	return resultInfo ~= nil and resultInfo.isDelisted ~= true
end

function AP:ReleaseSlotForTarget(index, resultID)
	local _, targetID = self:ResolveApplyTarget(index, resultID)
	if not ApplicationQuota:ShouldReleaseFor(self, targetID) then
		return false
	end
	local applicationID = ApplicationQuota:SelectExpiryCandidate()
	if not applicationID then
		return false
	end
	local cancelled = self:CancelApplication(applicationID)
	if cancelled ~= true then
		return false
	end
	local locale = GF.L or {}
	local notice = locale.APPLY_CANCELLED_OLDEST
		or "Cancelled oldest pending application. Click again to apply."
	self:ReportError(notice)
	return true
end

function AP:GetBlizzardApplyBlockReason()
	if type(LFGListUtil_GetActiveQueueMessage) == "function" then
		local queueMessage = LFGListUtil_GetActiveQueueMessage(true)
		if queueMessage ~= nil then
			return queueMessage
		end
	end
	if type(LFGListUtil_IsAppEmpowered) == "function"
		and LFGListUtil_IsAppEmpowered() ~= true
	then
		return LFG_LIST_APP_UNEMPOWERED
	end
	local home = LE_PARTY_CATEGORY_HOME
	if IsInGroup(home)
		and type(C_LFGList.IsCurrentlyApplying) == "function"
		and C_LFGList.IsCurrentlyApplying()
	then
		return LFG_LIST_APP_CURRENTLY_APPLYING
	end
	local _, activeCount = C_LFGList.GetNumApplications()
	if activeCount ~= nil and MAX_LFG_LIST_APPLICATIONS ~= nil
		and activeCount >= MAX_LFG_LIST_APPLICATIONS
	then
		return string.format(LFG_LIST_HIT_MAX_APPLICATIONS, MAX_LFG_LIST_APPLICATIONS)
	end
	if GetNumGroupMembers(home) > (MAX_PARTY_MEMBERS + 1) then
		return LFG_LIST_MAX_MEMBERS
	end
	local canTank, canHeal, canDealDamage = C_LFGList.GetAvailableRoles()
	if canTank ~= true and canHeal ~= true and canDealDamage ~= true then
		return LFG_LIST_MUST_CHOOSE_SPEC
	end
	if type(GroupHasOfflineMember) == "function" and GroupHasOfflineMember(home) then
		return LFG_LIST_OFFLINE_MEMBER
	end
	return nil
end

function AP:GetSelectedRoleFlags()
	if type(GetLFGRoles) ~= "function"
		or type(C_LFGList.GetAvailableRoles) ~= "function"
	then
		return nil
	end
	local rolesOK, _, tankSelected, healerSelected, damageSelected = pcall(GetLFGRoles)
	if rolesOK ~= true then
		return nil
	end
	local availabilityOK, tankAvailable, healerAvailable, damageAvailable =
		pcall(C_LFGList.GetAvailableRoles)
	if availabilityOK ~= true then
		return nil
	end
	local tank = tankSelected == true and tankAvailable == true
	local healer = healerSelected == true and healerAvailable == true
	local damage = damageSelected == true and damageAvailable == true
	if tank ~= true and healer ~= true and damage ~= true then
		return nil
	end
	return tank, healer, damage
end

local function resolveUsableApplyTarget(service, index, resultID)
	local resolvedIndex, resolvedID, reason = service:ResolveApplyTarget(index, resultID)
	if resolvedIndex == nil or resolvedID == nil then
		if reason == "stale" then
			service:ReportError((GF.L or {}).APPLY_TARGET_UNAVAILABLE
				or "This listing is no longer available.")
		end
		return nil, nil
	end
	if service:CanSelectRow(resolvedIndex, resolvedID) ~= true then
		service:ReportError((GF.L or {}).APPLY_TARGET_UNAVAILABLE
			or "This listing is no longer available.")
		return nil, nil
	end
	return resolvedIndex, resolvedID
end

function AP:ShowDialogForIndex(index, resultID)
	local resolvedIndex, resolvedID = resolveUsableApplyTarget(self, index, resultID)
	if resolvedID == nil then
		return false
	end
	if self:ReleaseSlotForTarget(resolvedIndex, resolvedID) then
		return false
	end
	if type(LFGListApplicationDialog_Show) ~= "function"
		or LFGListApplicationDialog == nil
	then
		return false
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	self:Init()
	self:PrepareDialogApplyNote(resolvedID)
	self._gfDialog = true
	LFGListApplicationDialog_Show(LFGListApplicationDialog, resolvedID)
	return true
end

function AP:TryAutoApply(index, resultID)
	local resolvedIndex, resolvedID = resolveUsableApplyTarget(self, index, resultID)
	if resolvedID == nil then
		return false
	end
	if self:ReleaseSlotForTarget(resolvedIndex, resolvedID) then
		return false
	end
	local blockReason = self:GetBlizzardApplyBlockReason()
	if blockReason then
		self:ReportError(blockReason)
		return false
	end
	local tank, healer, dps = self:GetSelectedRoleFlags()
	if not (tank or healer or dps) then
		self:ReportError(LFG_LIST_MUST_SELECT_ROLE or LFG_LIST_MUST_CHOOSE_SPEC)
		return false
	end
	self:PrepareApplyNoteFields()
	return C_LFGList.ApplyToGroup(resolvedID, tank, healer, dps)
end

function AP:OnRowLeftClick(row)
	if not row or not row.resultIndex then
		return
	end
	local index, resultID = self:ResolveApplyTarget(row.resultIndex, row.resultID)
	if not index or not resultID or not self:CanSelectRow(index, resultID) then
		return
	end
	local fg = GF.FindGroupTab
	if not fg then
		return
	end
	local mode = self:GetMode()
	local now = GetTime()
	local isDouble = self._lastClickResultID == resultID and (now - (self._lastClickTime or 0)) <= self.DBLCLICK_SEC
	self._lastClickTime = now
	self._lastClickRow = row
	self._lastClickResultID = resultID

	if mode == "dblclick_auto" then
		if isDouble then
			self._lastClickRow = nil
			self._lastClickResultID = nil
			self._lastClickTime = 0
			fg:SetSelectedRow(row)
			self:TryAutoApply(index, resultID)
		else
			fg:SetSelectedRow(row)
		end
		return
	end

	if mode == "click_confirm" then
		fg:SetSelectedRow(row)
		if isDouble then
			return
		end
		self:ShowDialogForIndex(index, resultID)
		return
	end

	fg:SetSelectedRow(row)
end
