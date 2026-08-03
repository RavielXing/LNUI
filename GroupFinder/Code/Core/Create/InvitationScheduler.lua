local _, GF = ...

local Scheduler = {}
GF.InvitationScheduler = Scheduler

local DEFAULT_STEP_SECONDS = 1
local LIMITED_STEP_SECONDS = 3
local AUTOMATIC_INVITE_OPTIONS = { respectMemberLimit = true }
local AUTHORITATIVE_APPLICANT_PROVENANCE = "LFG_LIST_APPLICANT_UPDATED"

local function getRecruitmentSession()
	return GF.RecruitmentSession
end

local function usesNativeQuestAutoAccept()
	local session = getRecruitmentSession()
	return session ~= nil
		and type(session.UsesNativeQuestAutoAccept) == "function"
		and session:UsesNativeQuestAutoAccept() == true
end

local function cancelTimer(timer)
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
end

local function currentStepSeconds()
	local database = GF.GetDB and GF.GetDB()
	if database and database.autoInviteMemberLimitEnabled == true then
		return LIMITED_STEP_SECONDS
	end
	return DEFAULT_STEP_SECONDS
end

local function currentEntrySignature()
	local session = getRecruitmentSession()
	if not (session and session.HasActive and session:HasActive()) then
		return nil
	end
	local entry = session.GetActive and session:GetActive()
	if type(entry) ~= "table" then
		return nil
	end
	local activityIDs = entry.activityIDs
	local activityID = type(activityIDs) == "table" and activityIDs[1]
		or entry.activityID or 0
	return table.concat({
		tostring(activityID),
		tostring(entry.questID or 0),
		entry.privateGroup == true and "1" or "0",
	}, ":")
end

local function refreshManagementControls()
	local panel = GF.ApplicantsPanel
	if panel and type(panel.UpdateManageState) == "function" then
		panel:UpdateManageState()
	end
end

local function applicantKey(applicantID)
	return tostring(applicantID)
end

local function resetGenerationRuntime(scheduler)
	scheduler._generation = (scheduler._generation or 0) + 1
	cancelTimer(scheduler._queueTimer)
	cancelTimer(scheduler._chainTimer)
	scheduler._queueTimer = nil
	scheduler._queueTicket = nil
	scheduler._queuePending = nil
	scheduler._chainTimer = nil
	scheduler._chainTicket = nil
	scheduler._cooldownUntil = nil
	scheduler._inFlightApplicantID = nil
	scheduler._candidateCursor = nil
	scheduler._submittedApplicants = {}
end

local function submittedApplicantCount(scheduler)
	local count = 0
	for _ in pairs(scheduler._submittedApplicants or {}) do
		count = count + 1
	end
	return count
end

function Scheduler:ReconcileApplicantLedger(authoritativeApplicantID, provenance)
	local submitted = self._submittedApplicants
	if type(submitted) ~= "table" or next(submitted) == nil then
		return false
	end
	local authoritativeKey
	if provenance == AUTHORITATIVE_APPLICANT_PROVENANCE
		and authoritativeApplicantID ~= nil
	then
		local keyOK, key = pcall(applicantKey, authoritativeApplicantID)
		if keyOK then
			authoritativeKey = key
		end
	end

	local presentApplicants = {}
	local listReadable = false
	local listReader = C_LFGList and C_LFGList.GetApplicants
	if type(listReader) == "function" then
		local listOK, applicantIDs = pcall(listReader)
		if listOK and type(applicantIDs) == "table" then
			listReadable = pcall(function()
				for index = 1, #applicantIDs do
					local applicantID = applicantIDs[index]
					presentApplicants[applicantKey(applicantID)] = applicantID
				end
			end)
		end
	end

	local infoReader = C_LFGList and C_LFGList.GetApplicantInfo
	local releaseKeys = {}
	for key, record in pairs(submitted) do
		local currentApplicantID = presentApplicants[key]
		local isAuthoritativeApplicant = authoritativeKey ~= nil
			and key == authoritativeKey
		local readApplicantID = currentApplicantID
			or (isAuthoritativeApplicant and authoritativeApplicantID)
		local wasArmed = record.missingObserved == true
			or record.nonAppliedObserved == true
		local statusKind
		if readApplicantID ~= nil and type(infoReader) == "function" then
			local infoOK, info = pcall(infoReader, readApplicantID)
			if infoOK and type(info) == "table" then
				local statusOK, kind = pcall(function()
					local status = info.applicationStatus
					if status == "applied" then
						if info.pendingApplicationStatus ~= nil
							or info.applicantInfo
						then
							return "applied_pending"
						end
						return "applied"
					end
					if status ~= nil then
						return "non_applied"
					end
				end)
				if statusOK then
					statusKind = kind
				end
			end
		end

		if statusKind == "applied" then
			if isAuthoritativeApplicant and wasArmed then
				releaseKeys[#releaseKeys + 1] = key
			elseif listReadable and currentApplicantID == nil then
				record.missingObserved = true
			end
		elseif statusKind == "non_applied" then
			record.nonAppliedObserved = true
		elseif statusKind == "applied_pending" then
			if listReadable and currentApplicantID == nil then
				record.missingObserved = true
			end
		elseif listReadable and currentApplicantID == nil then
			record.missingObserved = true
		end
	end
	for index = 1, #releaseKeys do
		submitted[releaseKeys[index]] = nil
	end
	return true
end

function Scheduler:RestoreSession()
	if usesNativeQuestAutoAccept() then
		-- Quest listings use Blizzard's native auto-accept state.  Clear any
		-- scheduler residue left by an older build so both engines cannot run.
		self:ClearSession()
		return false
	end
	resetGenerationRuntime(self)
	local database = GF.GetDB and GF.GetDB()
	if type(database) ~= "table" then
		self._enabled = false
		self._entrySignature = nil
		self._lastGroupSize = nil
		self._lastCanToggle = nil
		return false
	end
	local signature = currentEntrySignature()
	local shouldRestore = database.autoInviteEnabled == true
		and signature ~= nil
		and database.autoInviteEntrySig == signature
	if shouldRestore then
		local actions = GF.ApplicantActionService
		self._enabled = true
		self._entrySignature = signature
		self._lastGroupSize = actions and actions.GetGroupSize
			and actions:GetGroupSize() or nil
		self._lastCanToggle = self:CanToggle()
		self:Queue()
		return true
	end
	self._enabled = false
	self._entrySignature = nil
	self._lastGroupSize = nil
	self._lastCanToggle = nil
	database.autoInviteEnabled = false
	database.autoInviteEntrySig = nil
	return false
end

function Scheduler:IsEnabled()
	if self._enabled == nil then
		self:RestoreSession()
	end
	return self._enabled == true
end

function Scheduler:CanToggle()
	local session = getRecruitmentSession()
	return session ~= nil
		and not usesNativeQuestAutoAccept()
		and session.HasActive ~= nil
		and session:HasActive() == true
		and UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) == true
end

function Scheduler:ClearSession()
	resetGenerationRuntime(self)
	self._lastGroupSize = nil
	self._lastCanToggle = nil
	self._enabled = false
	self._entrySignature = nil

	local database = GF.GetDB and GF.GetDB()
	if type(database) == "table" then
		database.autoInviteEnabled = false
		database.autoInviteEntrySig = nil
	end
end

function Scheduler:SetEnabled(enabled)
	if enabled ~= true then
		self:ClearSession()
		return true
	end
	local session = getRecruitmentSession()
	if not (session and session.HasActive and session:HasActive()) then
		return false
	end
	if self:CanToggle() ~= true then
		return false
	end

	local signature = currentEntrySignature()
	if signature == nil then
		return false
	end
	if self:IsEnabled() == true and self._entrySignature == signature then
		self:Queue()
		return true
	end
	resetGenerationRuntime(self)
	self._enabled = true
	self._entrySignature = signature
	local actions = GF.ApplicantActionService
	self._lastGroupSize = actions and actions.GetGroupSize
		and actions:GetGroupSize() or nil
	self._lastCanToggle = true

	local database = GF.GetDB and GF.GetDB()
	if type(database) == "table" then
		database.autoInviteEnabled = true
		database.autoInviteEntrySig = signature
	end
	self:Queue()
	return true
end

function Scheduler:StopAtMemberLimit()
	local database = GF.GetDB and GF.GetDB()
	if not database or database.autoInviteMemberLimitEnabled ~= true then
		return false
	end
	local actions = GF.ApplicantActionService
	local groupSize = actions and actions.GetGroupSize
		and actions:GetGroupSize() or 1
	local memberLimit = actions and actions.GetConfiguredMemberLimit
		and actions:GetConfiguredMemberLimit() or 0
	local invited = C_LFGList and C_LFGList.GetNumInvitedApplicantMembers
		and C_LFGList.GetNumInvitedApplicantMembers() or 0
	if groupSize + invited < memberLimit then
		return false
	end
	self:ClearSession()
	refreshManagementControls()
	return true
end

function Scheduler:SelectNextCandidate(candidateIDs)
	local actions = GF.ApplicantActionService
	if not (actions and type(actions.CanInvite) == "function") then
		return nil, false
	end
	local candidates = type(candidateIDs) == "table" and candidateIDs or {}
	local count = #candidates
	if count == 0 then
		self._candidateCursor = nil
		return nil, false
	end

	local cursorIndex = 0
	for index = 1, count do
		if candidates[index] == self._candidateCursor then
			cursorIndex = index
			break
		end
	end

	local lastCandidate
	local retryNeeded = false
	for offset = 1, count do
		local index = ((cursorIndex + offset - 1) % count) + 1
		local applicantID = candidates[index]
		lastCandidate = applicantID
		local alreadySubmitted = self._submittedApplicants
			and self._submittedApplicants[applicantKey(applicantID)] ~= nil
		if not alreadySubmitted then
			local callOK, canInvite, reason = pcall(
				actions.CanInvite,
				actions,
				applicantID,
				AUTOMATIC_INVITE_OPTIONS)
			if callOK and canInvite == true then
				self._candidateCursor = applicantID
				return applicantID, false
			end
			if not callOK
				or reason == "api_error"
				or reason == "api_unreadable"
				or reason == "loading"
				or reason == "missing"
			then
				retryNeeded = true
			end
		end
	end
	self._candidateCursor = lastCandidate
	return nil, retryNeeded
end

function Scheduler:ScheduleNext(delaySeconds)
	cancelTimer(self._chainTimer)
	self._chainTimer = nil
	self._chainTicket = nil
	if not (C_Timer and type(C_Timer.NewTimer) == "function") then
		return false
	end
	local delay = tonumber(delaySeconds) or currentStepSeconds()
	delay = math.max(0, delay)
	local generation = self._generation or 0
	local ticket = {}
	self._chainTicket = ticket
	local timer
	timer = C_Timer.NewTimer(delay, function()
		if self._chainTicket ~= ticket then
			return
		end
		self._chainTicket = nil
		self._chainTimer = nil
		if generation == (self._generation or 0) then
			self:TryNext()
		end
	end)
	if self._chainTicket == ticket then
		self._chainTimer = timer
	end
	return true
end

function Scheduler:TryNext()
	local actions = GF.ApplicantActionService
	local now = GetTime and GetTime() or 0
	if self._inFlightApplicantID ~= nil
		or self:IsEnabled() ~= true
		or self:CanToggle() ~= true
		or not (C_LFGList and type(C_LFGList.InviteApplicant) == "function")
		or not actions
	then
		return false
	end
	self:ReconcileApplicantLedger()
	if self._cooldownUntil and now < self._cooldownUntil then
		self:ScheduleNext(self._cooldownUntil - now)
		return false
	end
	self._cooldownUntil = nil
	if self:StopAtMemberLimit() then
		return false
	end

	local model = GF.ApplicantSnapshotBuilder
	local candidates, providerReadable
	if model and type(model.GetSortedApplicantIDs) == "function" then
		candidates, providerReadable = model:GetSortedApplicantIDs()
	elseif type(C_LFGList.GetApplicants) == "function" then
		local readOK, applicantIDs = pcall(C_LFGList.GetApplicants)
		if readOK and type(applicantIDs) == "table" then
			candidates = applicantIDs
			providerReadable = true
		end
	end
	if providerReadable ~= true then
		-- A failed provider read is not an empty candidate set.  Keep the current
		-- generation alive and retry on the normal cadence even if no new event fires.
		self:ScheduleNext()
		return false
	end
	local applicantID, retryNeeded = self:SelectNextCandidate(candidates)
	if applicantID == nil then
		if retryNeeded == true then
			-- Per-applicant reads can be unavailable while the provider list itself is
			-- readable (notably during chat lockdown).  Keep the chain alive so recovery
			-- does not depend on Blizzard emitting another LFG event.
			self:ScheduleNext()
		end
		return false
	end

	local submittedKey = applicantKey(applicantID)
	local submittedRecord = {
		applicantID = applicantID,
		missingObserved = false,
		nonAppliedObserved = false,
	}
	self._submittedApplicants = self._submittedApplicants or {}
	self._submittedApplicants[submittedKey] = submittedRecord
	self._cooldownUntil = now + currentStepSeconds()
	self._inFlightApplicantID = applicantID
	local accepted, outcome = actions:Invite(
		applicantID, AUTOMATIC_INVITE_OPTIONS)
	self._inFlightApplicantID = nil
	if accepted ~= true then
		if self._submittedApplicants[submittedKey] == submittedRecord then
			self._submittedApplicants[submittedKey] = nil
		end
		self._cooldownUntil = nil
		return false
	end
	if outcome ~= "raid_conversion_popup" then
		self:ScheduleNext()
	end
	return true
end

function Scheduler:Queue(applicantID, provenance)
	if self:IsEnabled() ~= true then
		return false
	end
	-- Only the applicant-specific native event can prove that a later applied
	-- snapshot is a new generation. List-wide and roster passes may observe an
	-- omission edge, but cannot release duplicate protection on their own.
	self:ReconcileApplicantLedger(applicantID, provenance)
	if self._queuePending == true then
		return false
	end
	self._queuePending = true
	local generation = self._generation or 0
	local ticket = {}
	self._queueTicket = ticket
	local function run()
		if self._queueTicket ~= ticket then
			return
		end
		self._queueTicket = nil
		self._queueTimer = nil
		self._queuePending = nil
		if generation == (self._generation or 0) then
			self:TryNext()
		end
	end
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		local timer = C_Timer.NewTimer(0, run)
		if self._queueTicket == ticket then
			self._queueTimer = timer
		end
	elseif C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, run)
	else
		run()
	end
	return true
end

function Scheduler:HandleRosterChanged()
	local session = getRecruitmentSession()
	local actions = GF.ApplicantActionService
	local currentSize = actions and actions.GetGroupSize
		and actions:GetGroupSize() or 1
	local previousSize = self._lastGroupSize
	local canToggle = self:CanToggle()
	local previousCanToggle = self._lastCanToggle
	self._lastGroupSize = currentSize
	self._lastCanToggle = canToggle
	if not (session and session.HasActive and session:HasActive())
		or self:IsEnabled() ~= true
	then
		return false
	end
	local rosterChanged = previousSize ~= nil and previousSize ~= currentSize
	local leaderRestored = previousCanToggle == false and canToggle == true
	return (rosterChanged or leaderRestored) and self:Queue() or false
end

function Scheduler:HandleActiveEntryChanged(hasActive, createdNew)
	if usesNativeQuestAutoAccept() then
		self:ClearSession()
		return true
	end
	if hasActive ~= true or createdNew == true then
		self:ClearSession()
		return true
	end
	local signature = currentEntrySignature()
	if self:IsEnabled() == true
		and self._entrySignature ~= nil
		and signature ~= nil
		and signature ~= self._entrySignature
	then
		self:ClearSession()
		return true
	end
	return false
end

function Scheduler:GetSnapshot()
	return {
		generation = self._generation or 0,
		enabled = self:IsEnabled(),
		entrySignature = self._entrySignature,
		candidateCursor = self._candidateCursor,
		cooldownUntil = self._cooldownUntil,
		inFlightApplicantID = self._inFlightApplicantID,
		lastGroupSize = self._lastGroupSize,
		lastCanToggle = self._lastCanToggle,
		queuePending = self._queuePending == true,
		submittedApplicantCount = submittedApplicantCount(self),
	}
end
