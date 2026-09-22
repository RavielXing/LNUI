local _, GF = ...

local Alerts = {}
GF.ApplicantAlertService = Alerts

local function canObserveApplicants()
	local session = GF.RecruitmentSession
	return session ~= nil
		and session.HasActive ~= nil
		and session:HasActive() == true
		and session.CanManageApplicants ~= nil
		and session:CanManageApplicants() == true
end

local function collectApplicantIDs()
	local model = GF.ApplicantSnapshotBuilder
	local applicantIDs, providerReadable
	if model and type(model.GetApplicantIDs) == "function" then
		applicantIDs, providerReadable = model:GetApplicantIDs()
	else
		local actions = GF.ApplicantActionService
		if not (actions and type(actions.GetApplicantIDs) == "function") then
			return nil, false
		end
		local ok, ids = pcall(actions.GetApplicantIDs, actions)
		applicantIDs = ok and ids or nil
		providerReadable = ok and type(ids) == "table"
	end
	if providerReadable ~= true or type(applicantIDs) ~= "table" then
		return nil, false
	end
	local current = {}
	for _, applicantID in ipairs(applicantIDs) do
		local ok, key = pcall(tostring, applicantID)
		if ok then
			current[key] = applicantID
		end
	end
	return current, true
end

local function mergeSeenApplicantIDs(alerts, applicantIDs)
	local seen = alerts._seenApplicantIDs
	if type(seen) ~= "table" then
		alerts._seenApplicantIDs = applicantIDs
		return
	end
	for applicantID in pairs(applicantIDs or {}) do
		seen[applicantID] = true
	end
end

function Alerts:Reset()
	self:StopSound()
	self._seenApplicantIDs = nil
	self._cooldownUntil = nil
end

function Alerts:SyncBaseline(hasActive, createdNew)
	local canObserve = canObserveApplicants()
	self._canObserveApplicants = canObserve
	if hasActive == false or not canObserve then
		self:Reset()
		return false
	end
	if createdNew == true then
		-- LFG_LIST_ACTIVE_ENTRY_UPDATE's created flag is the authoritative
		-- recruitment-generation boundary.  A new entry gets a fresh, silent
		-- baseline and must not inherit either seen IDs or cooldown from the
		-- previous entry.
		self:Reset()
		self._canObserveApplicants = true
		local current, readable = collectApplicantIDs()
		self._seenApplicantIDs = readable and current or nil
		return true
	end
	-- Active-entry updates can request another silent baseline while the provider
	-- is temporarily incomplete.  Merge instead of replacing so omission never
	-- erases an ID already seen in this recruitment generation.
	local current, readable = collectApplicantIDs()
	if readable then
		mergeSeenApplicantIDs(self, current)
	end
	return true
end

function Alerts:HandleManagementPermissionChanged()
	local canObserve = canObserveApplicants()
	local previous = self._canObserveApplicants
	self._canObserveApplicants = canObserve
	if not canObserve then
		self:Reset()
		return false
	end
	if previous ~= true then
		local current, readable = collectApplicantIDs()
		self._seenApplicantIDs = readable and current or nil
		return true
	end
	return false
end

function Alerts:StopSound()
	local soundHandle = self._soundHandle
	self._soundHandle = nil
	if soundHandle and type(StopSound) == "function" then
		pcall(StopSound, soundHandle)
	end
end

function Alerts:PlaySound(file, options)
	if options and options.stopPrevious then
		self:StopSound()
	end
	local database = GF.GetDB and GF.GetDB()
	file = file ~= nil and file or (database and database.applicantAlertSoundFile)
	local path = GF.GetApplicantAlertSoundPath
		and GF.GetApplicantAlertSoundPath(file)
	if type(path) ~= "string" or path == "" then
		return false
	end
	if type(PlaySoundFile) == "function" then
		local ok, played, handle = pcall(PlaySoundFile, path, "Master")
		if ok and played then
			self._soundHandle = tonumber(handle)
			return true
		end
	end
	return false
end

function Alerts:Preview(file)
	return self:PlaySound(file, { stopPrevious = true })
end

function Alerts:PlayNewApplicantAlert()
	-- Every genuinely new batch requests attention, even with sound disabled or
	-- cooling down. Native client/OS behavior owns the visible icon effect.
	if type(FlashClientIcon) == "function" then
		pcall(FlashClientIcon)
	end
	local now = GetTime and GetTime() or 0
	if now < (tonumber(self._cooldownUntil) or 0) then
		return false
	end
	local played = self:PlaySound()
	if played then
		self._cooldownUntil = now
			+ (GF.APPLICANT_ALERT_SOUND_COOLDOWN_SECONDS or 10)
	end
	return played
end

local function isAppliedApplicant(applicantID)
	local actions = GF.ApplicantActionService
	if not (actions and type(actions.GetApplicantInfo) == "function") then
		return false
	end
	local ok, application = pcall(actions.GetApplicantInfo, actions, applicantID)
	return ok and type(application) == "table"
		and application.applicationStatus == "applied"
end

function Alerts:HandleApplicantChanged(applicantID)
	if not canObserveApplicants() then
		self._canObserveApplicants = false
		self:Reset()
		return false
	end
	self._canObserveApplicants = true
	if applicantID == nil then
		return self:HandleApplicantListChanged()
	end
	local ok, key = pcall(tostring, applicantID)
	if not ok then
		return false
	end
	local seen = self._seenApplicantIDs
	if seen == nil then
		local current, readable = collectApplicantIDs()
		self._seenApplicantIDs = readable and current or { [key] = applicantID }
		return false
	end
	if seen[key] ~= nil then
		return false
	end
	-- Mark the native ID before reading its status. If the provider is secret or
	-- temporarily unavailable, suppress one notification instead of replaying an
	-- old applicant as new after a permission transition.
	seen[key] = applicantID
	return isAppliedApplicant(applicantID) and self:PlayNewApplicantAlert() or false
end

function Alerts:HandleApplicantListChanged()
	if not canObserveApplicants() then
		self._canObserveApplicants = false
		self:Reset()
		return false
	end
	self._canObserveApplicants = true
	local current, readable = collectApplicantIDs()
	if readable ~= true then
		return false
	end
	local seen = self._seenApplicantIDs
	if seen == nil then
		self._seenApplicantIDs = current
		return false
	end
	local hasNewApplicant = false
	for applicantID, nativeApplicantID in pairs(current) do
		if seen[applicantID] == nil then
			hasNewApplicant = isAppliedApplicant(nativeApplicantID)
				or hasNewApplicant
		end
		-- Provider omission is not evidence of a new application generation.  Keep
		-- every ID seen during this active-entry generation so the same native ID
		-- cannot replay the alert when it reappears as applied.
		seen[applicantID] = nativeApplicantID
	end
	if not hasNewApplicant then
		return false
	end
	return self:PlayNewApplicantAlert()
end
