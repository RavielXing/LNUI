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

local function collectAppliedApplicantIDs()
	local applied = {}
	local actions = GF.ApplicantActionService
	if actions == nil then
		return applied
	end
	for _, applicantID in ipairs(actions:GetApplicantIDs()) do
		local application = actions:GetApplicantInfo(applicantID)
		local status = application and application.applicationStatus or nil
		if status == nil or status == "applied" then
			applied[tostring(applicantID)] = true
		end
	end
	return applied
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
		self._seenApplicantIDs = collectAppliedApplicantIDs()
		return true
	end
	-- Active-entry updates can request another silent baseline while the provider
	-- is temporarily incomplete.  Merge instead of replacing so omission never
	-- erases an ID already seen in this recruitment generation.
	mergeSeenApplicantIDs(self, collectAppliedApplicantIDs())
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
		self._seenApplicantIDs = collectAppliedApplicantIDs()
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

function Alerts:HandleApplicantListChanged()
	if not canObserveApplicants() then
		self._canObserveApplicants = false
		self:Reset()
		return false
	end
	self._canObserveApplicants = true
	local current = collectAppliedApplicantIDs()
	local seen = self._seenApplicantIDs
	if seen == nil then
		self._seenApplicantIDs = current
		return false
	end
	local hasNewApplicant = false
	for applicantID in pairs(current) do
		if seen[applicantID] ~= true then
			hasNewApplicant = true
		end
		-- Provider omission is not evidence of a new application generation.  Keep
		-- every ID seen during this active-entry generation so the same native ID
		-- cannot replay the alert when it reappears as applied.
		seen[applicantID] = true
	end
	if not hasNewApplicant then
		return false
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
