local addonName, GF = ...

-- ApplicationService owns the authoritative application lifecycle.  It is
-- deliberately independent from row frames and dialogs so every Find Group
-- surface observes the same native state, retry ledger, and group identity.
GF.ApplicationService = {}
local Service = GF.ApplicationService

local INACTIVE_STATUS = {
	cancelled = true,
	failed = true,
	declined = true,
	timedout = true,
	invitedeclined = true,
	inviteaccepted = true,
}

local ACTION_CONFIRM_SECONDS = 5
local RECONCILE_DELAYS = { 0.2, 0.5, 1, 2, 5 }

local function readable(value)
	if type(value) == "nil" then return true end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret then return false end
	end
	if type(canaccessvalue) == "function" then
		local ok, access = pcall(canaccessvalue, value)
		if not ok or access ~= true then return false end
	end
	return true
end

local function normalizedResultID(candidate)
	if not readable(candidate) then return nil end
	local ok, resultID = pcall(tonumber, candidate)
	return ok and resultID and resultID > 0 and resultID < math.huge and resultID or nil
end

local function isDeclinedStatus(status)
	return status == "declined"
		or status == "declined_delisted"
		or status == "declined_full"
end

local function isInactiveStatus(status)
	if status and INACTIVE_STATUS[status] then
		return true
	end
	if type(LFGListUtil_IsStatusInactive) == "function" then
		return LFGListUtil_IsStatusInactive(status)
	end
	return false
end

local function isJoinedStatus(status)
	return status == "invited" or status == "inviteaccepted"
end

local function isApplicationStatus(status, pendingStatus)
	return (status ~= nil and status ~= "none") or not not pendingStatus
end

-- Use the native solo/HOME-leader permission fence. Missing or unreadable
-- permission cannot authorize an outgoing mutation.
local function isApplicationEmpowered()
	if type(LFGListUtil_IsAppEmpowered) ~= "function" then return nil end
	local ok, empowered = pcall(LFGListUtil_IsAppEmpowered)
	if not ok or not readable(empowered) or type(empowered) ~= "boolean" then return nil end
	return empowered
end

local function accessibleNumber(value)
	local compat = GF.Compat
	if compat and type(compat.ToAccessibleNumber) == "function" then
		return compat.ToAccessibleNumber(value)
	end
	if type(value) == "nil" then
		return nil
	end
	if type(issecretvalue) == "function" then
		local secretOK, secret = pcall(issecretvalue, value)
		if not secretOK or secret == true then
			return nil
		end
	end
	if type(canaccessvalue) == "function" then
		local accessOK, accessible = pcall(canaccessvalue, value)
		if not accessOK or accessible ~= true then
			return nil
		end
	end
	local ok, number = pcall(tonumber, value)
	return ok and type(number) == "number" and number or nil
end

local function readSnapshotField(owner, key)
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ReadField) == "function" then
		return snapshot.ReadField(owner, key)
	end
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	if type(issecretvaluekey) == "function" then
		local secretOK, secret = pcall(issecretvaluekey, owner, key)
		if not secretOK then return nil, "error" end
		if secret == true then return nil, "secret" end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	end
	if type(issecretvalue) == "function" then
		local secretOK, secret = pcall(issecretvalue, value)
		if not secretOK then return nil, "error" end
		if secret == true then return nil, "secret" end
	end
	if not readable(value) then return nil, "secret" end
	return value, value == nil and "missing" or "value"
end

local function usableIdentity(value)
	if not readable(value) or value == nil or (type(value) == "string" and value == "") then
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
	local value, state = readSnapshotField(info, "partyGUID")
	return state == "value" and usableIdentity(value) or nil
end

local function playerIsInHomeGroup()
	if type(IsInGroup) == "function" then
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
	if type(GetNumGroupMembers) == "function" then
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

local function queryCurrentGroupPartyGUID()
	local socialQueue = C_SocialQueue
	if not (socialQueue and type(socialQueue.GetGroupForPlayer) == "function")
		or type(UnitGUID) ~= "function"
	then
		return nil
	end
	local guidOK, playerGUID = pcall(UnitGUID, "player")
	playerGUID = guidOK and usableIdentity(playerGUID) or nil
	if not playerGUID then
		return nil
	end
	local ok, partyGUID = pcall(socialQueue.GetGroupForPlayer, playerGUID)
	return ok and usableIdentity(partyGUID) or nil
end

function Service:NormalizeResultID(candidate)
	return normalizedResultID(candidate)
end

function Service:GetAuthoritativeResultInfo(resultID)
	local resultService = GF.Result
	if resultService
		and type(resultService.GetAuthoritativeSearchResultInfo) == "function"
	then
		local info = resultService:GetAuthoritativeSearchResultInfo(resultID)
		if info ~= nil then
			return info
		end
	end
	local getter = C_LFGList and C_LFGList.GetSearchResultInfo
	if type(getter) ~= "function" then
		return nil
	end
	local ok, info = pcall(getter, resultID)
	return ok and info or nil
end

function Service:GetNativeResultInfo(resultID)
	resultID = normalizedResultID(resultID)
	local api = C_LFGList
	local getter = api and api.GetSearchResultInfo
	if resultID == nil or type(getter) ~= "function" then
		return nil
	end
	if type(api.HasSearchResultInfo) == "function" then
		local ok, available = pcall(api.HasSearchResultInfo, resultID)
		if ok ~= true or available ~= true then
			return nil
		end
	end
	local ok, info = pcall(getter, resultID)
	return ok and info or nil
end

function Service:GetResultPartyGUID(info)
	return resultPartyGUID(info)
end

function Service:IsPlayerInHomeGroup()
	return playerIsInHomeGroup()
end

function Service:SetPresentationPort(port)
	self._presentationPort = type(port) == "table" and port or nil
end

function Service:ObserveApplicationPriority(resultID)
	resultID = normalizedResultID(resultID)
	if not resultID then
		return nil
	end
	self._applicationPriorityByResultID =
		self._applicationPriorityByResultID or {}
	local priority = self._applicationPriorityByResultID[resultID]
	if priority == nil then
		self._applicationPrioritySequence =
			(self._applicationPrioritySequence or 0) + 1
		priority = self._applicationPrioritySequence
		self._applicationPriorityByResultID[resultID] = priority
	end
	return priority
end

function Service:ForgetApplicationPriority(resultID)
	resultID = normalizedResultID(resultID)
	if resultID and self._applicationPriorityByResultID then
		self._applicationPriorityByResultID[resultID] = nil
	end
end

function Service:GetApplicationPriority(resultID)
	resultID = normalizedResultID(resultID)
	if not resultID then
		return nil
	end
	local priority = self._applicationPriorityByResultID
		and self._applicationPriorityByResultID[resultID]
	return priority or self:ObserveApplicationPriority(resultID)
end

function Service:PeekApplicationPriority(resultID)
	resultID = normalizedResultID(resultID)
	return resultID and self._applicationPriorityByResultID
		and self._applicationPriorityByResultID[resultID] or nil
end

function Service:ResolveApplyTarget(index, resultID)
	local results = GF.Result
	local numericID = normalizedResultID(resultID)
	if numericID and results
		and type(results.GetIndexForResultID) == "function"
	then
		local currentIndex = results:GetIndexForResultID(numericID)
		if currentIndex ~= nil then
			return currentIndex, numericID
		end
		return nil, numericID, "stale"
	end
	local numericIndex = tonumber(index)
	if numericIndex and results and type(results.GetResultID) == "function" then
		local indexedID = results:GetResultID(numericIndex)
		if indexedID ~= nil then
			return numericIndex, indexedID
		end
	end
	return nil, nil, "missing"
end

function Service:IsDelisted(index, resultID)
	local _, resolvedID = self:ResolveApplyTarget(index, resultID)
	if resolvedID == nil then
		return true
	end
	local results = GF.Result
	local cached = results and results.entryCache
		and results.entryCache[resolvedID] or nil
	if cached and cached.info
		and type(results.IsSoftUnavailable) == "function"
		and results:IsSoftUnavailable(cached.info)
	then
		return true
	end
	local info = self:GetNativeResultInfo(resolvedID)
	if info == nil then
		return true
	end
	if results
		and type(results.ShouldHideUnavailableResult) == "function"
		and results:ShouldHideUnavailableResult(resolvedID, info)
	then
		return true
	end
	local delisted, state = readSnapshotField(info, "isDelisted")
	if state == "secret" or state == "error" then
		return true
	end
	return state == "value" and delisted == true
end

function Service:CanSelectRow(index, resultID)
	local resolvedIndex, resolvedID = self:ResolveApplyTarget(index, resultID)
	if GF.RaidLeaderLookup and not GF.RaidLeaderLookup:CanApply(resolvedID) then return false end
	if resolvedIndex == nil
		or self:IsCurrentGroupResult(resolvedID)
		or self:IsDelisted(resolvedIndex, resolvedID)
	then
		return false
	end
	local snapshot = self:ReadApplicationSnapshot(resolvedID)
	if not snapshot.known then return false end
	if snapshot.appStatus == "none" and not snapshot.pendingStatus then
		local ids = self:ReadApplicationIDs()
		if ids == nil then return false end
		for _, id in ipairs(ids) do if id == resolvedID then return false end end
	end
	local applying = self._applyRequests and self._applyRequests[resolvedID]
	if applying and GetTime() < applying.deadline then return false end
	return resolvedID == nil or not self:HasApplication(resolvedID)
end

function Service:GetCurrentGroupPartyGUID()
	if not playerIsInHomeGroup() then
		return nil
	end
	-- GROUP_LEFT can arrive from the previous HOME party after a quick swap.
	-- Prefer the live social-queue identity whenever it is readable instead of
	-- keeping an earlier event's GUID forever.
	local partyGUID = queryCurrentGroupPartyGUID()
	if partyGUID then
		self.currentGroupPartyGUID = partyGUID
		return partyGUID
	end
	return usableIdentity(self.currentGroupPartyGUID)
end

function Service:SetCurrentGroupResultID(resultID, info)
	resultID = normalizedResultID(resultID)
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
	local projection = GF.CurrentGroupProjection
	if projection and type(projection.Observe) == "function" and info then
		projection:Observe(resultID, info, nil, GF.Result)
	end
	return changed
end

function Service:IsCurrentGroupResult(resultID, info)
	resultID = normalizedResultID(resultID)
	if not resultID or not playerIsInHomeGroup() then
		return false
	end
	if self.suppressedJoinedApplications
		and self.suppressedJoinedApplications[resultID]
	then
		return false
	end
	info = info or self:GetAuthoritativeResultInfo(resultID)
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
	local hasSelf, state = readSnapshotField(info, "hasSelf")
	return state == "value" and hasSelf == true
end

function Service:OnJoinedGroup(resultID)
	resultID = normalizedResultID(resultID)
	if not resultID then
		return false
	end
	local changed = self:SetCurrentGroupResultID(
		resultID, self:GetAuthoritativeResultInfo(resultID))
	self._wasInHomeGroup = playerIsInHomeGroup()
	return changed
end

function Service:OnGroupJoined(category, partyGUID)
	if not isHomePartyCategory(category) then
		return false
	end
	partyGUID = usableIdentity(partyGUID)
	local changed = self._wasInHomeGroup ~= true
	local previousGUID = usableIdentity(self.currentGroupPartyGUID)
	if partyGUID and previousGUID and partyGUID ~= previousGUID then
		if self.currentGroupResultID then
			changed = self:SuppressJoinedApplication(self.currentGroupResultID)
				or changed
		end
		self.currentGroupResultID = nil
	end
	if partyGUID and partyGUID ~= previousGUID then
		self.currentGroupPartyGUID = partyGUID
		changed = true
	end
	local projection = GF.CurrentGroupProjection
	if projection and type(projection.OnGroupJoined) == "function" then
		projection:OnGroupJoined(partyGUID)
	end
	self._wasInHomeGroup = true
	return changed
end

function Service:OnGroupLeft(category, partyGUID)
	if not isHomePartyCategory(category) then
		return false
	end
	partyGUID = usableIdentity(partyGUID)
	local currentGUID = usableIdentity(self.currentGroupPartyGUID)
	if partyGUID and currentGUID and partyGUID ~= currentGUID then
		-- A late old-party GROUP_LEFT must not tear down a newly joined party,
		-- but it must never preserve a projection after the player has really
		-- left HOME.  Reconcile the live roster in both cases instead of treating
		-- a GUID mismatch as an unconditional ignore.
		return self:OnGroupRosterChanged()
	end
	local changed = self._wasInHomeGroup == true
	if self.currentGroupResultID then
		changed = self:SuppressJoinedApplication(self.currentGroupResultID)
			or changed
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
	local projection = GF.CurrentGroupProjection
	if projection and type(projection.OnGroupLeft) == "function" then
		changed = projection:OnGroupLeft(partyGUID) or changed
	end
	self.currentGroupResultID = nil
	self.currentGroupPartyGUID = nil
	self._wasInHomeGroup = false
	for id, ticket in pairs(self._acceptRequests or {}) do
		if ticket.observedHome then self._acceptRequests[id] = nil end
	end
	return changed
end

function Service:TrackJoinedApplication(
	resultID, status, observedGroup, acceptRequested)
	resultID = normalizedResultID(resultID)
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

function Service:ClearJoinedApplication(resultID)
	resultID = normalizedResultID(resultID)
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

function Service:IsJoinedApplicationTracked(resultID)
	resultID = normalizedResultID(resultID)
	if not resultID then
		return false
	end
	return self.currentGroupResultID == resultID
		or (self.joinedApplications
			and self.joinedApplications[resultID] ~= nil)
		or (self.suppressedJoinedApplications
			and self.suppressedJoinedApplications[resultID] == true)
end

function Service:SuppressJoinedApplication(resultID)
	resultID = normalizedResultID(resultID)
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

function Service:IsJoinedApplicationSuppressed(
	resultID, applicationStatus, pendingStatus)
	resultID = normalizedResultID(resultID)
	if not resultID or not self.suppressedJoinedApplications
		or not self.suppressedJoinedApplications[resultID]
	then
		return false
	end
	if isJoinedStatus(applicationStatus) or isJoinedStatus(pendingStatus) then
		return true
	end
	self.suppressedJoinedApplications[resultID] = nil
	return false
end

-- Native observations and local requests are separate. No reader or timer in
-- this block may submit an application, cancel one, or accept an invitation.
function Service:ReadApplicationSnapshot(resultID)
	local reader = C_LFGList and C_LFGList.GetApplicationInfo
	if not resultID or type(reader) ~= "function" then return { known = false } end
	local ok, id, status, pending, duration = pcall(reader, resultID)
	if not ok or not readable(id) or not readable(status) or not readable(pending)
		or type(status) ~= "string" or (id ~= nil and id ~= resultID)
		then
		return { known = false }
	end
	local snapshot = { known = true, appStatus = status,
		pendingStatus = pending or nil, appDuration = accessibleNumber(duration) }
	self._applicationObservations = self._applicationObservations or {}
	local previous = self._applicationObservations[resultID]
	local generation = previous and previous.generation or 0
	if (status == "applied" or pending == "applied") and previous
		and previous.ended == true then
		generation = generation + 1
	end
	local partyGUID = status == "applied" and resultPartyGUID(self:GetNativeResultInfo(resultID)) or nil
	if previous and previous.partyGUID and partyGUID and previous.partyGUID ~= partyGUID
		and generation == previous.generation then generation = generation + 1 end
	snapshot.generation = generation
	snapshot.partyGUID = partyGUID or (previous and previous.generation == generation and previous.partyGUID) or nil
	snapshot.appExpiration = previous and previous.generation == generation and previous.appExpiration or nil
	if status == "applied" then
		local now = GetTime()
		local expiration = previous and previous.generation == generation and previous.appExpiration or nil
		local remaining = snapshot.appDuration
		if remaining and remaining >= 0 and remaining < math.huge then
			local candidate = now + remaining
			expiration = expiration and math.min(expiration, candidate) or candidate
		end
		-- One clock per native application generation. Repaints and quantized
		-- duration reads may shorten it, but can never move it into the future.
		snapshot.appExpiration = expiration
		snapshot.remainingSeconds = expiration and math.max(0, expiration - now) or nil
	end
	snapshot.ended = not pending and isInactiveStatus(status)
	if status == "none" and not pending and previous then
		local ids = self:ReadApplicationIDs()
		if ids then
			snapshot.ended = true
			for _, id in ipairs(ids) do if id == resultID then snapshot.ended = false end end
		end
	end
	-- Keep only IDs with application history, not every browsed search result.
	if previous or status ~= "none" or pending then
		self._applicationObservations[resultID] = snapshot
	end
	return snapshot
end

function Service:ReadApplicationIDs()
	local reader = C_LFGList and C_LFGList.GetApplications
	if type(reader) ~= "function" then return nil end
	local ok, ids = pcall(reader)
	if not ok or not readable(ids) or type(ids) ~= "table" then return nil end
	local list = {}
	local copied = pcall(function()
		for _, value in ipairs(ids) do
			local id = normalizedResultID(value)
			if not id or id ~= math.floor(id) then error("unreadable application ID") end
			list[#list + 1] = id
		end
	end)
	return copied and list or nil
end

function Service:GetNativeActiveApplicationCount()
	local reader = C_LFGList and C_LFGList.GetNumApplications
	if type(reader) ~= "function" then return nil end
	local ok, _, count = pcall(reader)
	count = ok and accessibleNumber(count) or nil
	return count and count >= 0 and count < math.huge and count == math.floor(count) and count or nil
end

function Service:NotifyApplicationChanged()
	local port = self._presentationPort
	if port and type(port.OnApplicationChanged) == "function" then
		port:OnApplicationChanged()
	end
end

local function requestMatches(owner, id, ticket, snapshot)
	if not ticket then return false end
	if snapshot.known and ticket.generation ~= snapshot.generation then return false end
	local guid = resultPartyGUID(owner:GetNativeResultInfo(id))
	return not (ticket.partyGUID and guid and guid ~= ticket.partyGUID)
end

function Service:GetCancelAvailability(resultID, snapshot)
	snapshot = snapshot or self:ReadApplicationSnapshot(resultID)
	local empowered = isApplicationEmpowered()
	if empowered == nil then return false, "waiting_update" end
	if not empowered then return false, "unempowered" end
	if not snapshot.known or snapshot.pendingStatus
		or snapshot.appStatus ~= "applied" or self:IsCurrentGroupResult(resultID) then
		return false, "waiting_update"
	end
	local ids, present = self:ReadApplicationIDs(), false
	for _, id in ipairs(ids or {}) do if id == resultID then present = true end end
	if not present then return false, "waiting_update" end
	local ticket = self._cancelRequests and self._cancelRequests[resultID]
	if requestMatches(self, resultID, ticket, snapshot)
		and ticket.phase ~= "failed" and GetTime() < ticket.deadline then
		return false, "cancelling"
	end
	return true
end

function Service:GetApplicationActionState(resultID, snapshot)
	snapshot = snapshot or self:ReadApplicationSnapshot(resultID)
	if snapshot.known and (isJoinedStatus(snapshot.appStatus)
		or (isInactiveStatus(snapshot.appStatus) and snapshot.pendingStatus ~= "applied")) then return nil end
	local ticket = self._cancelRequests and self._cancelRequests[resultID]
	if ticket and requestMatches(self, resultID, ticket, snapshot) then
		if ticket.phase == "failed" and (not snapshot.known or snapshot.appStatus == "applied") then
			return "cancel_failed"
		end
		if ticket.phase == "submitted" or ticket.phase == "uncertain" then
			if not snapshot.known or snapshot.appStatus == "applied" or snapshot.pendingStatus then
				if GetTime() >= ticket.deadline then return "waiting_confirm" end
				return ticket.replacement and "auto_cancelling" or "cancelling"
			end
		end
	end
	if not snapshot.known then return "waiting_update" end
	if snapshot.appStatus == "invited" or snapshot.appStatus == "inviteaccepted" then return nil end
	if snapshot.pendingStatus == "cancelled" then return "cancelling" end
	if snapshot.pendingStatus then return "waiting_update" end
	if snapshot.appStatus == "applied" and (snapshot.remainingSeconds == nil or snapshot.remainingSeconds <= 0) then
		return "waiting_update"
	end
	if snapshot.appStatus == "none" then
		local ids = self:ReadApplicationIDs()
		if ids == nil then return "waiting_update" end
		for _, id in ipairs(ids) do if id == resultID then return "waiting_update" end end
	end
	local applying = self._applyRequests and self._applyRequests[resultID]
	if applying and GetTime() < applying.deadline and snapshot.appStatus == "none" then
		return "waiting_update"
	end
	return nil
end

function Service:StopApplicationReconcile()
	if self._applicationReconcileTimer then self._applicationReconcileTimer:Cancel() end
	self._applicationReconcileTimer = nil
end

function Service:IsReplacementCurrent(intent)
	if not intent or self._replacementIntent ~= intent then return false end
	local port = self._presentationPort
	local context = port and port.GetApplicationContext and port:GetApplicationContext()
	if context and intent.context and (context.searchToken ~= intent.context.searchToken
		or context.searchKey ~= intent.context.searchKey) then return false end
	local info = self:GetNativeResultInfo(intent.resultID)
	local guid = resultPartyGUID(info)
	if not info or (intent.partyGUID and guid ~= intent.partyGUID) then return false end
	local delisted, access = readSnapshotField(info, "isDelisted")
	return access ~= "secret" and access ~= "error" and delisted ~= true
end

local function replacementTargetIsUnapplied(owner, resultID, snapshot)
	return snapshot.known and not snapshot.pendingStatus
		and (snapshot.appStatus == "none"
			or (isDeclinedStatus(snapshot.appStatus) and owner:IsRetryAllowed(resultID)))
end

function Service:GetReplacementState(resultID)
	local intent = self._replacementIntent
	if not intent or resultID ~= intent.resultID then return nil end
	if not self:IsReplacementCurrent(intent) then return nil end
	local snapshot = self:ReadApplicationSnapshot(resultID)
	if not snapshot.known then return "waiting_update", intent end
	if not replacementTargetIsUnapplied(self, resultID, snapshot) then return nil end
	local request = intent.request
	if not request then return "auto_cancelling", intent end
	if request.phase == "failed" then return "cancel_failed", intent end
	if request.phase == "released" or request.phase == "cancelled" then
		local count = self:GetNativeActiveApplicationCount()
		if count and MAX_LFG_LIST_APPLICATIONS and count < MAX_LFG_LIST_APPLICATIONS
			and self:GetBlizzardApplyBlockReason() == nil
			and self:CanSelectRow(nil, resultID) then return "retry", intent end
		return "waiting_update", intent
	end
	if request.phase == "finished" then return nil end
	return GetTime() >= request.deadline and "waiting_confirm" or "auto_cancelling", intent
end

function Service:ReconcileApplications(force)
	if self._reconcilingApplications then return end
	self._reconcilingApplications = true
	local now = GetTime()
	local ids = self:ReadApplicationIDs()
	local members, observed = {}, {}
	for _, id in ipairs(ids or {}) do members[id] = true; observed[id] = true end
	for id in pairs(self._cancelRequests or {}) do observed[id] = true end
	for id in pairs(self._applyRequests or {}) do observed[id] = true end
	for id in pairs(self._acceptRequests or {}) do observed[id] = true end
	local intent = self._replacementIntent
	if intent then observed[intent.resultID] = true end
	local ordered = {}
	for id in pairs(observed) do ordered[#ordered + 1] = id end
	table.sort(ordered)
	local signature = { ids and "known" or "unknown", tostring(isApplicationEmpowered()),
		tostring(self:GetNativeActiveApplicationCount()) }
	local needsRead, positive = ids == nil, nil
	local actionChanged = false
	for _, id in ipairs(ordered) do
		local snapshot = self:ReadApplicationSnapshot(id)
		if intent and id == intent.resultID and snapshot.known
			and not replacementTargetIsUnapplied(self, id, snapshot) then
			self._replacementIntent = nil
		end
		signature[#signature + 1] = id .. ":" .. (snapshot.appStatus or "?")
			.. ":" .. tostring(snapshot.pendingStatus or "") .. ":" .. tostring(members[id] == true)
			.. ":" .. tostring(snapshot.remainingSeconds ~= nil and snapshot.remainingSeconds > 0)
		if not snapshot.known or snapshot.pendingStatus then needsRead = true end
		if snapshot.known and snapshot.appStatus == "applied" and not snapshot.pendingStatus then
			if snapshot.remainingSeconds and snapshot.remainingSeconds > 0 then
				positive = math.min(positive or math.huge, snapshot.remainingSeconds)
			else needsRead = true end
		end
		local ticket = self._cancelRequests and self._cancelRequests[id]
		if ticket then
			local previousPhase = ticket.phase
			if not requestMatches(self, id, ticket, snapshot) then
				self._cancelRequests[id] = nil
				if intent and intent.request == ticket then self._replacementIntent = nil end
			elseif snapshot.known and not snapshot.pendingStatus then
				if snapshot.appStatus == "cancelled" then ticket.phase = "cancelled"
				elseif snapshot.appStatus == "none" and ids and not members[id] then ticket.phase = "released"
				elseif snapshot.appStatus ~= "applied" and snapshot.appStatus ~= "none" then ticket.phase = "finished"
				elseif ticket.phase == "submitted" and now >= ticket.deadline then ticket.phase = "uncertain" end
			end
			if ticket.phase == "submitted" or ticket.phase == "uncertain" then needsRead = true end
			actionChanged = actionChanged or previousPhase ~= ticket.phase
			if not (self._replacementIntent and self._replacementIntent.request == ticket)
				and (ticket.phase == "released" or ticket.phase == "finished" or ticket.phase == "cancelled") then
				self._cancelRequests[id] = nil
			end
		end
		local applying = self._applyRequests and self._applyRequests[id]
		if applying then
			if snapshot.known and (snapshot.appStatus ~= "none" or snapshot.pendingStatus or now >= applying.deadline) then
				self._applyRequests[id] = nil
			else needsRead = true end
		end
		local accepting = self._acceptRequests and self._acceptRequests[id]
		if accepting and snapshot.appStatus == "inviteaccepted" and playerIsInHomeGroup() then accepting.observedHome = true end
		if accepting and snapshot.known and not isJoinedStatus(snapshot.appStatus) and not snapshot.pendingStatus then
			self._acceptRequests[id] = nil
		end
	end
	if intent and not self:IsReplacementCurrent(intent) then self._replacementIntent = nil end
	local newSignature = table.concat(signature, "|")
	local changed = newSignature ~= self._applicationReconcileSignature
	if force or changed or not self._applicationReconcileStarted then
		self._applicationReconcileStarted = now
	end
	self._applicationReconcileSignature = newSignature
	self:StopApplicationReconcile()
	local delay
	if positive then delay = math.max(0.05, math.min(1, positive))
	elseif needsRead or self._replacementIntent then
		for _, offset in ipairs(RECONCILE_DELAYS) do
			local remaining = self._applicationReconcileStarted + offset - now
			if remaining > 0.01 then delay = remaining; break end
		end
	end
	if delay and C_Timer and type(C_Timer.NewTimer) == "function" then
		self._applicationReconcileTimer = C_Timer.NewTimer(delay, function()
			Service._applicationReconcileTimer = nil
			Service:ReconcileApplications(false)
		end)
	end
	self._reconcilingApplications = nil
	if changed or force or actionChanged then self:NotifyApplicationChanged() end
end

-- Retained only as a compatibility entry point. A visual callback is never
-- evidence of cancellation, and this method cannot manufacture a terminal.
function Service:MarkApplicationCancelled()
	self:ReconcileApplications(false)
	return false
end

function Service:StartReplacement(resultID, context, mode)
	if not self:ShouldReleaseSlotFor(resultID) then return false end
	if self._replacementIntent then
		local phase = self:GetReplacementState(self._replacementIntent.resultID)
		if phase and phase ~= "cancel_failed" and phase ~= "retry" then
			return true, (GF.L or {}).APP_STATE_WAITING_CONFIRM or "等待确认"
		end
	end
	local reason = self:GetBlizzardApplyBlockReason(true)
	if reason then return true, reason end
	local id = self:FindExpiryCandidate()
	if not id then return true, (GF.L or {}).APP_STATE_WAITING_UPDATE or "等待更新" end
	local intent = { resultID = resultID, context = context, mode = mode,
		partyGUID = resultPartyGUID(self:GetNativeResultInfo(resultID)) }
	self._replacementIntent = intent
	local ok, errorText = self:CancelApplication(id, intent)
	if not ok and not intent.request then self._replacementIntent = nil end
	return true, errorText
end

function Service:ConsumeReplacement(resultID, expected)
	local phase, intent = self:GetReplacementState(resultID)
	if phase ~= "retry" or intent ~= expected then return nil end
	self._replacementIntent = nil
	self:NotifyApplicationChanged()
	return intent
end


local function appendUniqueResultIDs(target, seen, source)
	if type(source) ~= "table" then
		return
	end
	for _, candidate in ipairs(source) do
		local resultID = normalizedResultID(candidate)
		if resultID and not seen[resultID] then
			seen[resultID] = true
			target[#target + 1] = resultID
		end
	end
end

local RejectionLedger = {}
RejectionLedger.__index = RejectionLedger

local function rejectionLedger(owner)
	if owner._rejectionLedger == nil then
		owner._rejectionLedger = setmetatable({
			records = {},
			signals = {},
		}, RejectionLedger)
	end
	return owner._rejectionLedger
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

function Service:IsRetryAllowed(resultID, resultInfo)
	resultID = normalizedResultID(resultID)
	resultInfo = resultInfo or (resultID
		and self:GetAuthoritativeResultInfo(resultID))
	return rejectionLedger(self):IsRetryReady(resultPartyGUID(resultInfo))
end

function Service:SnapshotRejectedParties()
	local results = GF.Result
	local resultIDs, seen = {}, {}
	if results then
		appendUniqueResultIDs(resultIDs, seen, results.resultIDs)
		appendUniqueResultIDs(resultIDs, seen, results.apiResultIDs)
		appendUniqueResultIDs(resultIDs, seen, results.frozenOrder)
	end
	local captured = {}
	local ledger = rejectionLedger(self)
	for _, resultID in ipairs(resultIDs) do
		local resultInfo = self:GetAuthoritativeResultInfo(resultID)
		local partyGUID = resultPartyGUID(resultInfo)
		local rememberedStatus = ledger:GetStatus(partyGUID)
		local nativeDeclined, nativeStatus = false, nil
		local reader = C_LFGList and C_LFGList.GetApplicationInfo
		if type(reader) == "function" then
			local ok, _, status = pcall(reader, resultID)
			nativeDeclined = ok == true and isDeclinedStatus(status)
			nativeStatus = nativeDeclined and status or nil
		end
		if partyGUID
			and (nativeDeclined or isDeclinedStatus(rememberedStatus))
		then
			captured[partyGUID] = nativeDeclined
				and ledger:SeedNativeDecline(partyGUID, nativeStatus)
				or ledger:GetRevision(partyGUID)
		end
	end
	return next(captured) ~= nil and captured or nil
end

function Service:ApplyManualRefreshUnlocks(captured, resultIDs)
	if type(captured) ~= "table" or type(resultIDs) ~= "table" then
		return 0
	end
	local ledger = rejectionLedger(self)
	local unlocked = 0
	for _, resultID in ipairs(resultIDs) do
		local info = self:GetAuthoritativeResultInfo(resultID)
		local partyGUID = resultPartyGUID(info)
		local capturedRevision = partyGUID and captured[partyGUID]
		if capturedRevision ~= nil then
			local matched, newlyUnlocked = ledger:Unlock(
				partyGUID, capturedRevision)
			if matched and newlyUnlocked then
				unlocked = unlocked + 1
			end
		end
	end
	self:ClearRejectionFeedback()
	return unlocked
end

function Service:GetApplicationState(resultID, suppliedResultInfo)
	local reader = C_LFGList and C_LFGList.GetApplicationInfo
	if resultID == nil or type(reader) ~= "function" then
		return nil
	end
	local snapshot = self:ReadApplicationSnapshot(resultID)
	local appStatus, pendingStatus, appDuration =
		snapshot.appStatus, snapshot.pendingStatus, snapshot.appDuration
	local departed = self.suppressedJoinedApplications and self.suppressedJoinedApplications[resultID] == true
	if snapshot.known then departed = self:IsJoinedApplicationSuppressed(resultID, appStatus, pendingStatus) end
	local resultInfo = suppliedResultInfo
		or self:GetAuthoritativeResultInfo(resultID)
	local partyGUID = resultPartyGUID(resultInfo)
	local declined = isDeclinedStatus(appStatus)
	local rememberedDecline = rejectionLedger(self):GetStatus(partyGUID)
	if not declined and rememberedDecline ~= nil
		and (appStatus == "none" or isInactiveStatus(appStatus)) and not pendingStatus then
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
	local lastKnown = self._applicationObservations and self._applicationObservations[resultID]
	local uncertainActive = not snapshot.known and lastKnown
		and isApplicationStatus(lastKnown.appStatus, lastKnown.pendingStatus)
		and not isInactiveStatus(lastKnown.appStatus)
	local remaining = accessibleNumber(appDuration)
	local expiredApplication = appStatus == "applied"
		and not pendingStatus
		and remaining ~= nil
		and remaining <= 0
		and not self:IsCurrentGroupResult(resultID, resultInfo)
	local finished = declined or isInactiveStatus(appStatus)
	local actionState = self:GetApplicationActionState(resultID, snapshot)
	local canCancel, cancelReason = self:GetCancelAvailability(resultID, snapshot)
	local cancelRequest = self._cancelRequests and self._cancelRequests[resultID]
	if cancelRequest and not requestMatches(self, resultID, cancelRequest, snapshot) then cancelRequest = nil end
	return {
		appStatus = appStatus,
		pendingStatus = pendingStatus,
		appDuration = appDuration,
		appExpiration = snapshot.appExpiration,
		remainingSeconds = snapshot.remainingSeconds,
		cancelRequest = cancelRequest,
		cancelRequestedAt = cancelRequest and cancelRequest.requestedAt,
		isDeclined = declined,
		isApplication = present or not snapshot.known,
		isActiveApp = (present and not finished) or uncertainActive == true,
		known = snapshot.known,
		actionState = actionState,
		canCancel = canCancel,
		cancelReason = cancelReason,
		isDepartedApplication = departed,
		isExpiredApplication = expiredApplication,
	}
end

function Service:HasApplication(resultID)
	local state = self:GetApplicationState(resultID)
	return state ~= nil and state.isApplication == true
end

function Service:IsDeclinedApplication(resultID)
	local state = self:GetApplicationState(resultID)
	return state ~= nil and state.isDeclined == true
end

function Service:HasActiveApplication()
	local count = self:GetNativeActiveApplicationCount()
	if count ~= nil then return count > 0 end
	local api = C_LFGList
	if not api or type(api.GetApplications) ~= "function"
		or type(api.GetApplicationInfo) ~= "function"
	then
		return false
	end
	for _, applicationID in ipairs(self:ReadApplicationIDs() or {}) do
		local state = self:GetApplicationState(applicationID)
		if state and state.isActiveApp == true then
			return true
		end
	end
	return false
end

function Service:GetActiveApplicationCount()
	local count = self:GetNativeActiveApplicationCount()
	if count ~= nil then return count end
	local api = C_LFGList
	if not api or type(api.GetApplications) ~= "function"
		or type(api.GetApplicationInfo) ~= "function"
	then
		return 0
	end
	local count = 0
	for _, applicationID in ipairs(self:ReadApplicationIDs() or {}) do
		local state = self:GetApplicationState(applicationID)
		if state and state.isActiveApp == true then
			count = count + 1
		end
	end
	return count
end

function Service:ShouldPinApplication(resultID)
	local state = self:GetApplicationState(resultID)
	if not state or state.isApplication ~= true then
		return false
	end
	return state.isDeclined == true or not isInactiveStatus(state.appStatus)
end

local function currentFeedbackScope(owner)
	local port = owner._presentationPort
	if not port or type(port.GetRejectionFeedbackScope) ~= "function" then
		return nil
	end
	return port:GetRejectionFeedbackScope()
end

local function feedbackScopeMatches(owner, entry)
	if type(entry) ~= "table" then
		return false
	end
	local current = currentFeedbackScope(owner)
	return current ~= nil
		and current.searchToken == entry.searchToken
		and current.activeKey == entry.activeKey
end

local function feedbackEntryMatches(owner, resultID, entry, ignoreDeadline)
	if type(entry) ~= "table" or not feedbackScopeMatches(owner, entry) then
		return false
	end
	if not ignoreDeadline then
		local expiresAt = tonumber(entry.expiresAt)
		if expiresAt == nil or expiresAt <= GetTime() then
			return false
		end
	end
	local info = owner:GetAuthoritativeResultInfo(resultID)
	local partyGUID = resultPartyGUID(info)
	if partyGUID == nil or partyGUID ~= entry.partyGUID then
		return false
	end
	return rejectionLedger(owner):GetRevision(partyGUID) == entry.revision
end

function Service:ClearRejectionFeedback(partyGUID)
	return rejectionLedger(self):ClearSignals(partyGUID)
end

function Service:HasRejectionFeedback(resultID)
	resultID = normalizedResultID(resultID)
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

function Service:StartRejectionFeedback(resultID, partyGUID, revision)
	resultID = normalizedResultID(resultID)
	local context = currentFeedbackScope(self)
	local results = GF.Result
	if resultID == nil or partyGUID == nil or context == nil
		or not C_Timer or type(C_Timer.NewTimer) ~= "function"
		or not results or type(results.IsFrozenResult) ~= "function"
		or results:IsFrozenResult(resultID) ~= true
	then
		return false
	end
	local ledger = rejectionLedger(self)
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
	if type(results.InvalidateAsyncJobs) == "function" then
		results:InvalidateAsyncJobs()
	end
	entry.timer = C_Timer.NewTimer(delay, function()
		entry.timer = nil
		local activeLedger = rejectionLedger(Service)
		if activeLedger.signals[resultID] ~= entry then
			return
		end
		local shouldReapply = feedbackEntryMatches(
			Service, resultID, entry, true)
		activeLedger:RemoveSignal(resultID, entry, true)
		local port = Service._presentationPort
		if shouldReapply and port
			and type(port.OnRejectionFeedbackExpired) == "function"
		then
			port:OnRejectionFeedbackExpired()
		end
	end)
	return true
end

function Service:ObserveRejectedApplication(resultID, status)
	local info = self:GetAuthoritativeResultInfo(resultID)
	local partyGUID = resultPartyGUID(info)
	local ledger = rejectionLedger(self)
	local revision
	if partyGUID then
		revision = ledger:Remember(partyGUID, status)
		ledger:ClearSignals(partyGUID)
	else
		ledger:ClearSignals()
		ledger:ResetRetryPermissions()
		local port = self._presentationPort
		if port and type(port.DiscardManualDeclineIntent) == "function" then
			port:DiscardManualDeclineIntent()
		end
	end
	self:StartRejectionFeedback(resultID, partyGUID, revision)
end

function Service:OnApplicationStatusUpdated(resultID, newStatus, oldStatus)
	if resultID == nil then
		return { changed = false }
	end
	local needsInviteHook = false
	if isJoinedStatus(newStatus) then
		local normalizedID = normalizedResultID(resultID)
		if newStatus == "invited" then
			resultID = normalizedID or resultID
			if normalizedID and self.suppressedJoinedApplications then
				self.suppressedJoinedApplications[normalizedID] = nil
			end
			self:TrackJoinedApplication(resultID, newStatus, false, false)
			needsInviteHook = true
		else
			local observedGroup = playerIsInHomeGroup()
			self:TrackJoinedApplication(
				resultID, newStatus, observedGroup, true)
			if observedGroup then
				self._wasInHomeGroup = true
			end
		end
	else
		self:ClearJoinedApplication(resultID)
	end
	local state = self:GetApplicationState(resultID)
	if state and state.isActiveApp == true then
		self:ObserveApplicationPriority(resultID)
	end
	local declined = isDeclinedStatus(newStatus)
	if not declined then
		if not self:IsDeclinedApplication(resultID) then
			rejectionLedger(self):RemoveSignal(
				normalizedResultID(resultID), nil, false)
		end
	else
		self:ObserveRejectedApplication(resultID, newStatus)
	end
	self:ReconcileApplications(false)
	return {
		changed = false,
		needsInviteHook = needsInviteHook,
	}
end

function Service:OnGroupRosterChanged()
	local inGroup = playerIsInHomeGroup()
	local changed = self._wasInHomeGroup ~= nil
		and self._wasInHomeGroup ~= inGroup
	self._wasInHomeGroup = inGroup
	local observedPartyGUID = inGroup and queryCurrentGroupPartyGUID() or nil
	local previousPartyGUID = usableIdentity(self.currentGroupPartyGUID)
	if observedPartyGUID and previousPartyGUID
		and observedPartyGUID ~= previousPartyGUID
	then
		-- A roster update is the live reconciliation point for a replacement
		-- HOME party.  Do not carry the former party's current-row identity into
		-- the new one merely because GROUP_LEFT/GROUP_JOINED arrived out of order.
		if self.currentGroupResultID then
			changed = self:SuppressJoinedApplication(self.currentGroupResultID)
				or changed
		end
		self.currentGroupResultID = nil
		self.currentGroupPartyGUID = observedPartyGUID
		changed = true
	elseif observedPartyGUID and observedPartyGUID ~= previousPartyGUID then
		self.currentGroupPartyGUID = observedPartyGUID
		changed = true
	end
	if not inGroup then
		if self.currentGroupResultID then
			changed = self:SuppressJoinedApplication(self.currentGroupResultID)
				or changed
		end
		if self.currentGroupResultID ~= nil
			or self.currentGroupPartyGUID ~= nil
		then
			changed = true
		end
		self.currentGroupResultID = nil
		self.currentGroupPartyGUID = nil
	end
	local api = C_LFGList
	local canRead = api and type(api.GetApplications) == "function"
		and type(api.GetApplicationInfo) == "function"
	if canRead then
		local seen = {}
		local applications = self:ReadApplicationIDs() or {}
		for index = 1, #applications do
			local resultID = normalizedResultID(applications[index])
			if resultID then
				seen[resultID] = true
				local observed = self:ReadApplicationSnapshot(resultID)
				local status, pendingStatus = observed.appStatus, observed.pendingStatus
				local joined = isJoinedStatus(status)
					or isJoinedStatus(pendingStatus)
				local accepted = status == "inviteaccepted"
					or pendingStatus == "inviteaccepted"
				local tracked = self.joinedApplications
					and self.joinedApplications[resultID]
				if joined and (accepted or tracked) then
					local wasObserved = tracked
						and tracked.observedGroup == true
					self:TrackJoinedApplication(
						resultID,
						status or pendingStatus,
						inGroup and (accepted
							or (tracked and tracked.acceptRequested)),
						tracked and tracked.acceptRequested)
					tracked = self.joinedApplications
						and self.joinedApplications[resultID]
					if inGroup and tracked
						and (accepted or tracked.acceptRequested)
					then
						tracked.observedGroup = true
						if accepted then
							changed = self:SetCurrentGroupResultID(
								resultID,
								self:GetNativeResultInfo(resultID)) or changed
						end
						if not wasObserved then
							changed = true
						end
					elseif not inGroup and tracked
						and (tracked.observedGroup or accepted)
					then
						changed = self:SuppressJoinedApplication(resultID)
							or changed
					end
				elseif tracked and observed.known then
					self:ClearJoinedApplication(resultID)
				end
			end
		end
		if not inGroup and self.joinedApplications then
			for resultID, entry in pairs(self.joinedApplications) do
				if not seen[resultID] and entry and entry.observedGroup then
					changed = self:SuppressJoinedApplication(resultID)
						or changed
				end
			end
		end
	end
	local projection = GF.CurrentGroupProjection
	if projection and type(projection.OnRosterChanged) == "function" then
		changed = projection:OnRosterChanged(
			inGroup, observedPartyGUID or self:GetCurrentGroupPartyGUID()) or changed
	end
	return changed
end

function Service:CancelApplication(resultID, replacement, expected)
	resultID = normalizedResultID(resultID)
	local locale = GF.L or {}
	local snapshot = self:ReadApplicationSnapshot(resultID)
	-- Secondary views pass the identity captured when their button was drawn.
	-- An expired/reused row must never cancel a newer native application.
	if expected and (expected.resultID ~= resultID or not snapshot.known
		or expected.generation ~= snapshot.generation or not expected.partyGUID
		or expected.partyGUID ~= resultPartyGUID(self:GetNativeResultInfo(resultID))) then
		return false, locale.APP_STATE_WAITING_UPDATE or "等待更新"
	end
	local allowed, reason = self:GetCancelAvailability(resultID, snapshot)
	if not allowed then
		return false, reason == "unempowered"
			and (locale.APPLY_CANCEL_NO_PERMISSION or "无权取消")
			or (locale.APP_STATE_WAITING_UPDATE or "等待更新")
	end
	local cancel = C_LFGList and C_LFGList.CancelApplication
	local requestedAt = GetTime()
	local ticket = { resultID = resultID, generation = snapshot.generation,
		partyGUID = resultPartyGUID(self:GetNativeResultInfo(resultID)),
		requestedAt = requestedAt, deadline = requestedAt + ACTION_CONFIRM_SECONDS, phase = "submitted",
		replacement = type(replacement) == "table" }
	self._cancelRequests = self._cancelRequests or {}
	self._cancelRequests[resultID] = ticket
	if ticket.replacement then replacement.request = ticket end
	-- Register before invoking the client: it can deliver events synchronously.
	local ok = type(cancel) == "function" and pcall(cancel, resultID)
	self:ReconcileApplications(true)
	if not ok and self._cancelRequests[resultID] == ticket
		and (ticket.phase == "submitted" or ticket.phase == "uncertain") then
		ticket.phase = "failed"
		self:NotifyApplicationChanged()
		return false, locale.APPLY_CANCEL_FAILED or "取消失败"
	end
	return true
end

-- Compatibility name: expiry now only observes; no timer submits mutations.
function Service:CancelExpiredApplications()
	self:ReconcileApplications(false)
	for _, id in ipairs(self:ReadApplicationIDs() or {}) do
		local state = self:ReadApplicationSnapshot(id)
		if state.known and state.appStatus == "applied" and not state.pendingStatus
			and state.appDuration and state.appDuration > 0 then return {}, true end
	end
	return {}, false
end

function Service:PinApplicationsToTop(ids, topID)
	local api = C_LFGList
	local applicationIDs = api and type(api.GetApplications) == "function"
		and self:ReadApplicationIDs() or {}
	local pinnedOrder, pinnedSet = {}, {}
	local function addPinned(candidateID)
		if candidateID == nil or pinnedSet[candidateID] then
			return
		end
		local cachedInfo = GF.Result
			and type(GF.Result.GetCachedSearchResultInfo) == "function"
			and GF.Result:GetCachedSearchResultInfo(candidateID) or nil
		local state = self:GetApplicationState(candidateID, cachedInfo)
		if not state or state.isActiveApp ~= true then
			return
		end
		self:ObserveApplicationPriority(candidateID)
		pinnedSet[candidateID] = true
		pinnedOrder[#pinnedOrder + 1] = candidateID
	end
	for _, applicationID in ipairs(applicationIDs) do
		addPinned(applicationID)
	end
	addPinned(topID)
	if self._applicationPriorityByResultID then
		for applicationID in pairs(self._applicationPriorityByResultID) do
			if not pinnedSet[applicationID] then
				self._applicationPriorityByResultID[applicationID] = nil
			end
		end
	end
	table.sort(pinnedOrder, function(leftID, rightID)
		local leftPriority = self:GetApplicationPriority(leftID)
		local rightPriority = self:GetApplicationPriority(rightID)
		if leftPriority ~= rightPriority then
			return (leftPriority or math.huge)
				< (rightPriority or math.huge)
		end
		return leftID < rightID
	end)
	local currentSet, currentCount = {}, 0
	for _, resultID in ipairs(type(ids) == "table" and ids or {}) do
		local cachedInfo = GF.Result
			and type(GF.Result.GetCachedSearchResultInfo) == "function"
			and GF.Result:GetCachedSearchResultInfo(resultID) or nil
		if self:IsCurrentGroupResult(resultID, cachedInfo) then
			currentSet[resultID] = true
			currentCount = currentCount + 1
		end
	end
	if #pinnedOrder == 0 and currentCount == 0 then
		return ids
	end
	local ordered, orderedSet = {}, {}
	local function append(resultID)
		if resultID ~= nil and not orderedSet[resultID] then
			orderedSet[resultID] = true
			ordered[#ordered + 1] = resultID
		end
	end
	for _, resultID in ipairs(type(ids) == "table" and ids or {}) do
		if currentSet[resultID] then
			append(resultID)
		end
	end
	for _, resultID in ipairs(pinnedOrder) do
		if not currentSet[resultID] then
			append(resultID)
		end
	end
	for _, resultID in ipairs(type(ids) == "table" and ids or {}) do
		if not pinnedSet[resultID] and not currentSet[resultID] then
			append(resultID)
		end
	end
	return ordered
end

function Service:FindExpiryCandidate()
	local selected, shortest = nil, math.huge
	for _, id in ipairs(self:ReadApplicationIDs() or {}) do
		local snapshot = self:ReadApplicationSnapshot(id)
		if self:GetCancelAvailability(id, snapshot) and snapshot.appDuration
			and snapshot.appDuration < shortest then
			selected, shortest = id, snapshot.appDuration
		end
	end
	return selected
end

function Service:ShouldReleaseSlotFor(resultID)
	local db = GF.GetDB and GF.GetDB()
	local count = self:GetNativeActiveApplicationCount()
	return db and db.replaceOldestApplication == true and resultID ~= nil
		and count ~= nil and MAX_LFG_LIST_APPLICATIONS ~= nil
		and count >= MAX_LFG_LIST_APPLICATIONS and self:CanSelectRow(nil, resultID) == true
end

function Service:ReadBlizzardApplyBlockReason(ignoreQuota)
	if type(LFGListUtil_GetActiveQueueMessage) == "function" then
		local queueMessage = LFGListUtil_GetActiveQueueMessage(true)
		if queueMessage ~= nil then
			local hasActiveEntry = false
			local session = GF.RecruitmentSession
			if session and type(session.HasActive) == "function" then
				local ok, active = pcall(session.HasActive, session)
				hasActiveEntry = ok == true and active == true
			end
			if hasActiveEntry
				and queueMessage == CANNOT_DO_THIS_WHILE_LFGLIST_LISTED
			then
				return (GF.L or {}).APPLY_FAILED_ALREADY_IN_GROUP
					or "Application failed: you have already joined a group"
			end
			return queueMessage
		end
	end
	local empowered = isApplicationEmpowered()
	if empowered == nil then return (GF.L or {}).APP_STATE_WAITING_UPDATE or "等待更新" end
	if not empowered then
		return LFG_LIST_APP_UNEMPOWERED or (GF.L or {}).APPLY_CANCEL_NO_PERMISSION or "无权取消"
	end
	local api = C_LFGList or {}
	local home = LE_PARTY_CATEGORY_HOME
	if type(IsInGroup) == "function" and IsInGroup(home)
		and type(api.IsCurrentlyApplying) == "function"
		and api.IsCurrentlyApplying()
	then
		return LFG_LIST_APP_CURRENTLY_APPLYING
	end
	if not ignoreQuota then
		local activeCount = self:GetNativeActiveApplicationCount()
		if activeCount == nil then return (GF.L or {}).APP_STATE_WAITING_UPDATE or "等待更新" end
		if activeCount ~= nil and MAX_LFG_LIST_APPLICATIONS ~= nil
			and activeCount >= MAX_LFG_LIST_APPLICATIONS
		then
			return string.format(
				LFG_LIST_HIT_MAX_APPLICATIONS,
				MAX_LFG_LIST_APPLICATIONS)
		end
	end
	if type(GetNumGroupMembers) == "function"
		and MAX_PARTY_MEMBERS ~= nil
		and GetNumGroupMembers(home) > (MAX_PARTY_MEMBERS + 1)
	then
		return LFG_LIST_MAX_MEMBERS
	end
	if type(api.GetAvailableRoles) == "function" then
		local canTank, canHeal, canDealDamage = api.GetAvailableRoles()
		if canTank ~= true and canHeal ~= true and canDealDamage ~= true then
			return LFG_LIST_MUST_CHOOSE_SPEC
		end
	end
	if type(GroupHasOfflineMember) == "function"
		and GroupHasOfflineMember(home)
	then
		return LFG_LIST_OFFLINE_MEMBER
	end
	return nil
end

function Service:GetBlizzardApplyBlockReason(ignoreQuota)
	local ok, reason = pcall(self.ReadBlizzardApplyBlockReason, self, ignoreQuota)
	if not ok or not readable(reason) then return (GF.L or {}).APP_STATE_WAITING_UPDATE or "等待更新" end
	return reason
end

function Service:GetSelectedRoleFlags()
	local api = C_LFGList
	if type(GetLFGRoles) ~= "function" or not api
		or type(api.GetAvailableRoles) ~= "function"
	then
		return nil
	end
	local rolesOK, _, tankSelected, healerSelected, damageSelected =
		pcall(GetLFGRoles)
	if rolesOK ~= true then
		return nil
	end
	local availableOK, tankAvailable, healerAvailable, damageAvailable =
		pcall(api.GetAvailableRoles)
	if availableOK ~= true then
		return nil
	end
	local tank = tankSelected == true and tankAvailable == true
	local healer = healerSelected == true and healerAvailable == true
	local damage = damageSelected == true and damageAvailable == true
	if not tank and not healer and not damage then
		return nil
	end
	return tank, healer, damage
end

function Service:ApplyToGroup(resultID, tank, healer, damage)
	local submit = C_LFGList and C_LFGList.ApplyToGroup
	if resultID == nil or type(submit) ~= "function" or not self:CanSelectRow(nil, resultID)
		or self:GetBlizzardApplyBlockReason() ~= nil then return false end
	local readyTeleport = GF.MythicPlusGroupReadyTeleportService
	if readyTeleport and readyTeleport.OnApplicationSubmitted then readyTeleport:OnApplicationSubmitted(resultID) end
	self._applyRequests = self._applyRequests or {}
	local ticket = { deadline = GetTime() + ACTION_CONFIRM_SECONDS }
	self._applyRequests[resultID] = ticket
	local ok = pcall(submit, resultID, tank, healer, damage)
	self:ReconcileApplications(true)
	if not ok and self._applyRequests[resultID] == ticket then
		self._applyRequests[resultID] = nil
		self:NotifyApplicationChanged()
	end
	return ok
end

function Service:ClearApplicationTextFields()
	local clear = C_LFGList and C_LFGList.ClearApplicationTextFields
	if type(clear) ~= "function" then
		return false
	end
	return pcall(clear)
end

function Service:TryAutoAcceptInvite(enabled, onAccepted)
	local api = C_LFGList
	local ready = api
		and type(api.GetApplications) == "function"
		and type(api.GetApplicationInfo) == "function"
		and type(api.AcceptInvite) == "function"
	if enabled ~= true or self._acceptInFlight == true or not ready
		or next(self._acceptRequests or {}) ~= nil or not isApplicationEmpowered() then
		return false
	end
	if type(LFGListUtil_IsAppEmpowered) == "function" then
		local ok, empowered = pcall(LFGListUtil_IsAppEmpowered)
		if not ok or empowered ~= true then
			return false
		end
	end
	self._acceptInFlight = true
	local scanOK, accepted = pcall(function()
		local applications = self:ReadApplicationIDs()
		if not applications then
			return false
		end
		for _, applicationID in ipairs(applications) do
			local infoOK, _, status, pendingStatus = pcall(
				api.GetApplicationInfo, applicationID)
			if infoOK and readable(status) and readable(pendingStatus)
				and status == "invited" and not pendingStatus then
				self._acceptRequests = self._acceptRequests or {}
				self._acceptRequests[applicationID] = { submitted = true }
				local acceptOK = pcall(api.AcceptInvite, applicationID)
				if acceptOK then
					if type(onAccepted) == "function" then
						onAccepted(applicationID, status)
					end
					return true
				end
				-- An error does not prove that the first invitation was ignored.
				-- Keep its request and never fall through to a second team.
				return false
			end
		end
		return false
	end)
	self._acceptInFlight = false
	self:ReconcileApplications(false)
	return scanOK and accepted == true
end

function Service:IsLfgListRoleCheckActive()
	local api = C_LFGList
	if not api or type(api.GetRoleCheckInfo) ~= "function"
		or type(CompleteLFGRoleCheck) ~= "function"
	then
		return false
	end
	if type(GetLFGRoleUpdate) == "function" then
		local ok, inProgress = pcall(GetLFGRoleUpdate)
		if not ok or inProgress ~= true then
			return false
		end
	end
	local ok, isLFGList = pcall(api.GetRoleCheckInfo)
	return ok and isLFGList == true
end

function Service:TryAutoConfirmLfgListRoleCheck(enabled)
	if enabled ~= true or self._roleCheckConfirmInFlight
		or not self:IsLfgListRoleCheckActive()
	then
		return false
	end
	local tank, healer, damage = self:GetSelectedRoleFlags()
	if not (tank or healer or damage) then
		return false
	end
	if type(LFDPopupCheckRoleSelectionValid) == "function" then
		local ok, valid = pcall(
			LFDPopupCheckRoleSelectionValid, tank, healer, damage)
		if not ok or valid ~= true then
			return false
		end
	end
	self._roleCheckConfirmInFlight = true
	local roleOK = true
	if type(SetLFGRoles) == "function" and type(GetLFGRoles) == "function" then
		local leaderOK, leader = pcall(GetLFGRoles)
		roleOK = leaderOK
			and pcall(SetLFGRoles, leader, tank, healer, damage)
	end
	local completeOK, completed = false, false
	if roleOK then
		completeOK, completed = pcall(CompleteLFGRoleCheck, true)
	end
	self._roleCheckConfirmInFlight = false
	if completeOK and completed then
		if type(StaticPopupSpecial_Hide) == "function" and LFDRoleCheckPopup then
			StaticPopupSpecial_Hide(LFDRoleCheckPopup)
		end
		return true
	end
	return false
end
