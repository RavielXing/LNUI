local _, GF = ...

local Alerts = {}
GF.ApplicantAlertService = Alerts

local function clearNativeApplicantAlert()
	local bridge = GF.NativeApplicantAlertBridge
	if bridge and type(bridge.Clear) == "function" then
		bridge:Clear()
	end
end

local function clearInactiveNativeApplicantAlert()
	local session = GF.RecruitmentSession
	-- HasActive() also returns false for an unreadable state. Only an explicit
	-- inactive result authorizes clearing the native recruitment notification.
	if session and type(session.ReadActiveState) == "function"
		and session:ReadActiveState() == false then
		clearNativeApplicantAlert()
	end
end

function Alerts:ClearDiagnostics()
	self._diagnostics = nil
end

function Alerts:Trace(reason)
	local debugService = GF.Debug
	if not (debugService and debugService.IsDebugModeEnabled
		and debugService:IsDebugModeEnabled()) then
		self:ClearDiagnostics()
		return
	end
	local entries = self._diagnostics or {}
	self._diagnostics = entries
	if #entries >= 32 then table.remove(entries, 1) end
	entries[#entries + 1] = {
		time = GetTime and GetTime() or 0, reason = reason,
		generation = self:GetGeneration(), handle = self._soundHandle,
		source = self._soundSource, observable = self._canObserveApplicants == true,
		resuming = self._resumeBaseline == true,
	}
end

function Alerts:GetGeneration()
	return self._generation or 0
end

function Alerts:PauseIfNeeded()
	local availability, session = GF.Availability, GF.RecruitmentSession
	local restricted = availability and availability.ShouldProcessLfgEvent
		and availability:ShouldProcessLfgEvent() ~= true
	local removing = session and session.IsRemovalPending and session:IsRemovalPending()
	if restricted or removing then
		if not self._resumeBaseline then self._generation = self:GetGeneration() + 1 end
		self._resumeBaseline = true
		self:Trace(removing and "removal-pending" or "lfg-paused")
		self:StopSound()
		if removing then clearNativeApplicantAlert() end
		return true
	end
	return false
end

function Alerts:GetDiagnostics()
	return self._diagnostics or {}
end

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
	self:Trace("reset")
	self:StopSound()
	self._generation = self:GetGeneration() + 1
	self._canObserveApplicants = false
	self._resumeBaseline = nil
	self._seenApplicantIDs = nil
	self._cooldownUntil = nil
end

function Alerts:SyncBaseline(hasActive, createdNew)
	self:Trace("active-entry")
	-- Cleanup must also run while normal LFG event processing is paused.
	if hasActive == false then
		clearInactiveNativeApplicantAlert()
		self:Reset()
		return false
	end
	if createdNew == true then self:Reset() end
	if self:PauseIfNeeded() then return false end
	local canObserve = canObserveApplicants()
	self._canObserveApplicants = canObserve
	if not canObserve then
		self:Reset()
		return false
	end
	if createdNew == true then
		-- LFG_LIST_ACTIVE_ENTRY_UPDATE's created flag is the authoritative
		-- recruitment-generation boundary.  A new entry gets a fresh, silent
		-- baseline and must not inherit either seen IDs or cooldown from the
		-- previous entry.
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
		self._resumeBaseline = nil
	end
	return true
end

function Alerts:HandleManagementPermissionChanged()
	if self:PauseIfNeeded() then return false end
	local canObserve = canObserveApplicants()
	local previous = self._canObserveApplicants
	self._canObserveApplicants = canObserve
	if not canObserve then
		self:Reset()
		return false
	end
	if previous ~= true or self._resumeBaseline then
		local current, readable = collectApplicantIDs()
		if readable then mergeSeenApplicantIDs(self, current) end
		self._resumeBaseline = not readable or nil
		return true
	end
	return false
end

function Alerts:HandleLifecycleChanged(reason)
	self:Trace(reason)
	clearInactiveNativeApplicantAlert()
	return self:HandleManagementPermissionChanged()
end

function Alerts:ResumeBaselineIfNeeded()
	if not self._resumeBaseline then return false end
	local current, readable = collectApplicantIDs()
	if readable then
		mergeSeenApplicantIDs(self, current)
		self._resumeBaseline = nil
	end
	return true
end

function Alerts:StopSound()
	local soundHandle = self._soundHandle
	if soundHandle then self:Trace("stop") end
	self._soundHandle = nil
	self._soundSource = nil
	if soundHandle and type(StopSound) == "function" then
		pcall(StopSound, soundHandle)
	end
end

function Alerts:StopPreview()
	if self._soundSource == "preview" then self:StopSound() end
end

function Alerts:RefreshSoundMode()
	local database = GF.GetDB and GF.GetDB()
	local file = GF.GetApplicantAlertSoundFile and GF.GetApplicantAlertSoundFile()
		or (database and database.applicantAlertSoundFile)
		or GF.APPLICANT_ALERT_SOUND_DEFAULT
	if self._soundMode ~= file then
		self:StopSound()
		self._soundMode = file
	end
	local bridge = GF.NativeApplicantAlertBridge
	if bridge and type(bridge.SetSoundEnabled) == "function" then
		return bridge:SetSoundEnabled(file == (GF.APPLICANT_ALERT_SOUND_NATIVE or "native"))
	end
	return false
end

function Alerts:PlaySound(file, options)
	self:RefreshSoundMode()
	-- One owner, one handle: never lose an earlier preview/alert to overlap.
	self:StopSound()
	local database = GF.GetDB and GF.GetDB()
	file = file ~= nil and file or (database and database.applicantAlertSoundFile)
	local path
	if file == (GF.APPLICANT_ALERT_SOUND_NATIVE or "native") then
		-- Real applicant notifications belong to the native eye animation. Only
		-- selection preview plays this file here, avoiding a second native ping.
		if not (options and options.preview) then return false end
		path = GF.NATIVE_APPLICANT_ALERT_SOUND_FILE_ID or 1067667
	else
		path = GF.GetApplicantAlertSoundPath and GF.GetApplicantAlertSoundPath(file)
		if type(path) ~= "string" or path == "" then return false end
	end
	if type(PlaySoundFile) == "function" then
		local ok, played, handle = pcall(PlaySoundFile, path, "Master")
		if ok and played then
			self._soundHandle = tonumber(handle)
			self._soundSource = options and options.preview and "preview" or "applicant"
			self:Trace("play")
			return true
		end
	end
	return false
end

function Alerts:Preview(file)
	return self:PlaySound(file, { preview = true })
end

function Alerts:PlayNewApplicantAlert()
	if self:PauseIfNeeded() then return false end
	if not canObserveApplicants() then self:Reset(); return false end
	if self:ResumeBaselineIfNeeded() then return false end
	-- Every genuinely new batch requests attention, even with sound disabled or
	-- cooling down. Native client/OS behavior owns the visible icon effect.
	if type(FlashClientIcon) == "function" then
		pcall(FlashClientIcon)
	end
	local now = GetTime and GetTime() or 0
	if now < (tonumber(self._cooldownUntil) or 0) then
		self:Trace("cooldown")
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
	self:Trace("applicant-updated")
	if self:PauseIfNeeded() then return false end
	if not canObserveApplicants() then
		self._canObserveApplicants = false
		self:Reset()
		return false
	end
	self._canObserveApplicants = true
	if self:ResumeBaselineIfNeeded() then return false end
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
	self:Trace("applicant-list")
	if self:PauseIfNeeded() then return false end
	if not canObserveApplicants() then
		self._canObserveApplicants = false
		self:Reset()
		return false
	end
	self._canObserveApplicants = true
	if self:ResumeBaselineIfNeeded() then return false end
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
