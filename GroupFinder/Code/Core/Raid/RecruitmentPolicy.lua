local _, GF = ...

-- The committed local recruitment requirements are separate from editable
-- drafts and from Blizzard's createData (which has no specialization field).
local Policy = { revision = 0, submitted = {} }
GF.RaidRecruitmentPolicy = Policy

local function session() return GF.RecruitmentSession end
local function cancel(timer) if timer and timer.Cancel then timer:Cancel() end end
local function now() return GetTime and GetTime() or 0 end
local function accessible(value)
	return type(value) == "nil" or not GF.Compat or GF.Compat.IsAccessibleValue(value)
end

local function notify()
	if GF.RaidSeekingService and GF.RaidSeekingService.Notify then GF.RaidSeekingService:Notify() end
end

function Policy:CancelQueue()
	cancel(self.timer)
	self.timer, self.ticket = nil, nil
end

function Policy:Clear()
	self:CancelQueue()
	cancel(self.confirmTimer)
	self.confirmTimer, self.pending, self.published, self.relisting = nil, nil, nil, nil
	self.submitted, self.blockedRevision = {}, nil
	self.revision = self.revision + 1
	notify()
end

function Policy:GetPublished()
	local listing, published = session(), self.published
	if not published or not listing or not listing:HasActive() or not listing:CanPublish()
		or listing:IsRelisting() or listing:GetActiveActivityID() ~= published.activityID
	then return nil end
	return published
end

function Policy:BeginSubmission(params)
	cancel(self.confirmTimer)
	local selected = params.workspaceID == GF.WORKSPACE_RAID
		and GF.RaidRecruitmentNeeds:CopySelection(params.raidRequiredSpecIDs) or nil
	-- Empty selections cannot arm automatic actions, including malformed callers.
	if selected and next(selected) == nil then selected = nil end
	local pending = { activityID = params.activityID, specIDs = selected, startedAt = now() }
	self.pending = pending
	return pending
end

function Policy:Commit(pending)
	if self.pending ~= pending or not pending.accepted or not pending.confirmed then return false end
	local listing = session()
	if not listing:HasActive() or not listing:CanPublish()
		or listing:GetActiveActivityID() ~= pending.activityID then return false end
	cancel(self.confirmTimer)
	self.confirmTimer, self.pending = nil, nil
	self:CancelQueue()
	self.revision = self.revision + 1
	self.blockedRevision = nil
	self.published = pending.specIDs and {
		activityID = pending.activityID, specIDs = pending.specIDs, revision = self.revision,
	} or nil
	self:Queue()
	local scheduler = GF.InvitationScheduler
	if scheduler then scheduler:Queue() end
	notify()
	return true
end

function Policy:FinishSubmission(pending, accepted)
	if self.pending ~= pending then return end
	if accepted ~= true then self:CancelSubmission(); return end
	pending.accepted = true
	if self:Commit(pending) then return end
	-- A missing acknowledgement must not let a later unrelated event commit it.
	if C_Timer and C_Timer.NewTimer then
		self.confirmTimer = C_Timer.NewTimer(10, function()
			if self.pending == pending then self:CancelSubmission() end
		end)
	end
end

function Policy:CancelSubmission()
	cancel(self.confirmTimer)
	self.pending, self.confirmTimer = nil, nil
end

function Policy:OnActiveEntryChanged(hasActive, createdNew)
	local listing = session()
	if not hasActive then
		if listing:IsRelisting() and self.published then
			self:CancelQueue()
			self.relisting, self.submitted = self.published, {}
			return
		end
		self:Clear()
		return
	end
	local activityID = listing:GetActiveActivityID()
	local pending = self.pending
	if pending and now() - pending.startedAt <= 10 and activityID == pending.activityID then
		pending.confirmed = true
		self:Commit(pending)
		return
	end
	if self.relisting and listing:IsRelisting() and not listing:IsAwaitingRelistRepost()
		and activityID == self.relisting.activityID then
		self.relisting = nil
		self:Queue()
		return
	end
	if createdNew == true or (self.published and activityID and activityID ~= self.published.activityID) then
		self:Clear()
	else
		self:Queue()
	end
end

function Policy:OnRosterChanged()
	local listing = session()
	if (self.published or self.pending) and not listing:CanPublish() then self:Clear() end
end

function Policy:OnRelistFinished(ok)
	if not self.published then return end
	local listing = session()
	if not ok and (self.relisting or not listing:HasActive()) then
		self:Clear()
		return
	end
	self.relisting = nil
	self:Queue()
end

-- Unknown metadata is never proof of rejection. A group is eligible to stay
-- as soon as any member matches; every member must be known to reject it.
function Policy:Evaluate(applicantID, expected)
	local published = self:GetPublished()
	if not published or (expected and expected ~= published) then return "inactive" end
	local actions = GF.ApplicantActionService
	local info = actions:GetApplicantInfo(applicantID)
	if not info or info.applicationStatus ~= "applied" or info.pendingApplicationStatus ~= nil
		or info.applicantInfo then return "waiting" end
	local specs = actions:GetApplicantSpecializations(applicantID)
	if not specs then return "unknown" end
	local unknown = false
	for _, member in ipairs(specs) do
		local id = member.specID
		if id and published.specIDs[id] then return "match" end
		if not id or not GF.RaidRecruitmentNeeds:IsAvailableSpec(id) then unknown = true end
	end
	return unknown and "unknown" or "reject"
end

function Policy:Reconcile(applicantID)
	local actions = GF.ApplicantActionService
	local ok, source, readable = pcall(actions.GetApplicantIDs, actions)
	local ids = {}
	if not ok or readable ~= true then return ids, false end
	local copied = pcall(function()
		for _, id in ipairs(source) do
			if not accessible(id) or type(id) ~= "number" or id < 0 or id % 1 ~= 0 then error("unreadable applicant ID") end
			ids[#ids + 1] = id
		end
	end)
	if not copied then return {}, false end
	local present = {}
	for _, id in ipairs(ids or {}) do present[id] = true end
	for id, record in pairs(self.submitted) do
		local info = actions:GetApplicantInfo(id)
		if readable and not present[id] or info and info.applicationStatus ~= "applied" then
			record.retired = true
		elseif id == applicantID and record.retired and not record.inFlight and info
			and info.applicationStatus == "applied" and info.pendingApplicationStatus == nil and not info.applicantInfo
		then
			-- Only the exact applicant event can authorize a reused native ID.
			self.submitted[id] = nil
		end
	end
	return ids, readable
end

function Policy:Process()
	local published = self:GetPublished()
	if not published or self.blockedRevision == published.revision then return end
	local ids, readable = self:Reconcile()
	if not readable then return end
	for _, id in ipairs(ids) do
		if not self.submitted[id] and self:Evaluate(id, published) == "reject" then
			local record = { inFlight = true }
			self.submitted[id] = record
			local view, presenter = GF.ApplicantsPanel, GF.ApplicantRosterPresenter
			local ok, submitted, outcome = pcall(function()
				if not view or not presenter then return false, "no_view" end
				return presenter.SubmitApplicantAction(view, { applicantID = id }, "decline", {
					raidRequirements = published, silent = true,
				})
			end)
			record.inFlight = nil
			if not ok or not submitted then
				if not ok and view and view.ClearApplicantAction then
					pcall(view.ClearApplicantAction, view, id, true)
				end
				if self.submitted[id] == record then self.submitted[id] = nil end
				if not ok or outcome == "api_error" then
					-- Do not retry a restricted/erroring native operation indefinitely.
					self.blockedRevision = published.revision
					if GF.ShowWarningMessage then
						GF.ShowWarningMessage((GF.L or {}).RAID_REQUIRED_SPECS_AUTO_DECLINE_FAILED)
					end
				end
				return
			end
			self:Queue(nil, 0.2)
			return
		end
	end
end

function Policy:Queue(applicantID, delay)
	if applicantID ~= nil then self:Reconcile(applicantID) end
	local published = self:GetPublished()
	if not published or self.blockedRevision == published.revision or self.ticket then return end
	if not (C_Timer and C_Timer.NewTimer) then return end
	local ticket = {}
	self.ticket = ticket
	self.timer = C_Timer.NewTimer(delay or 0, function()
		if self.ticket ~= ticket then return end
		self.ticket, self.timer = nil, nil
		self:Process()
	end)
end

-- Restore only a short UI reload of the same character's still-active listing.
-- Full login, new listing events, leadership loss and unconfirmed drafts never
-- arm this record. Saved credentials are consumed once on entering the world.
function Policy:OnLogout()
	local db = GF.GetDB and GF.GetDB()
	if not db then return end
	db.raidRecruitmentRequirementsReload = nil
	local published = self:GetPublished()
	local guid = UnitGUID and UnitGUID("player")
	local at = GetServerTime and GetServerTime()
	if published and type(guid) == "string" and accessible(guid) and type(at) == "number" then
		db.raidRecruitmentRequirementsReload = {
			version = 1, guid = guid, at = at, activityID = published.activityID,
			specIDs = GF.RaidRecruitmentNeeds:CopySelection(published.specIDs),
		}
	end
end

function Policy:OnEnteringWorld(initial, reload)
	if self.worldEntered or (initial ~= true and reload ~= true) then return end
	self.worldEntered = true
	local db = GF.GetDB and GF.GetDB()
	local saved = db and db.raidRecruitmentRequirementsReload
	if db then db.raidRecruitmentRequirementsReload = nil end
	if initial or not reload or self.published or self.pending or self.revision ~= 0
		or type(saved) ~= "table" or saved.version ~= 1 then return end
	local guid = UnitGUID and UnitGUID("player")
	local at = GetServerTime and GetServerTime()
	if not accessible(guid) or type(guid) ~= "string" or guid ~= saved.guid
		or type(at) ~= "number" or type(saved.at) ~= "number" or at < saved.at or at - saved.at > 180
	then return end
	local listing = session()
	if not listing:HasActive() or not listing:CanPublish() or listing:GetActiveActivityID() ~= saved.activityID then return end
	local specs = GF.RaidRecruitmentNeeds:CopySelection(saved.specIDs)
	if next(specs) == nil then return end
	self.revision = self.revision + 1
	self.published = { activityID = saved.activityID, specIDs = specs, revision = self.revision }
	self:Queue()
end

-- Apply once per confirmed publication, so a manual board filter survives
-- ordinary refreshes and never edits the rejection requirements.
function Policy:ApplyBoardDefaults(board)
	local published = self:GetPublished()
	if self.published and not published then return false end
	local revision = published and published.revision or 0
	if board.recruitmentRequirementsRevision == revision then return false end
	local hadRequirements = (board.recruitmentRequirementsRevision or 0) > 0
	board.recruitmentRequirementsRevision = revision
	if not published and not hadRequirements then return false end
	local selected = published and GF.RaidRecruitmentNeeds:CopySelection(published.specIDs) or nil
	if selected then
		local all, count = true, 0
		for _, class in ipairs(GF.RaidRecruitmentNeeds:GetCatalog()) do
			for _, spec in ipairs(class.specs) do
				all, count = all and selected[spec.id] == true, count + 1
			end
		end
		if all and count > 0 then selected = nil end
	end
	board.panel.filters.specIDs = selected
	board.signature = nil
	return true
end
