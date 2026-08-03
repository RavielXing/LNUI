local _, GF = ...

GF.MythicPlusTalentLoadoutService = GF.MythicPlusTalentLoadoutService or {}
local Service = GF.MythicPlusTalentLoadoutService
local Util = GF.MythicPlusServiceUtil

local READINESS_RETRY_DELAYS = { 0.10, 0.25, 0.50, 1.00 }
local SPECIALIZATION_SWITCH_TIMEOUT = 15

local LOADOUT_EVENTS = {
	"PLAYER_LOGIN",
	"PLAYER_ENTERING_WORLD",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_TALENT_UPDATE",
	"PLAYER_SPECIALIZATION_CHANGED",
	"ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
	"ACTIVE_COMBAT_CONFIG_CHANGED",
	"SELECTED_LOADOUT_CHANGED",
	"TRAIT_CONFIG_LIST_UPDATED",
	"TRAIT_CONFIG_CREATED",
	"TRAIT_CONFIG_DELETED",
	"TRAIT_CONFIG_UPDATED",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED",
}

local function readCurrentSpecID()
	if C_SpecializationInfo
		and C_SpecializationInfo.GetSpecialization
		and C_SpecializationInfo.GetSpecializationInfo
	then
		local ok, specIndex = pcall(
			C_SpecializationInfo.GetSpecialization
		)
		if ok and tonumber(specIndex) then
			local infoOK, specID = pcall(
				C_SpecializationInfo.GetSpecializationInfo,
				specIndex
			)
			specID = infoOK and tonumber(specID) or nil
			if specID and specID > 0 then
				return specID, true, tonumber(specIndex)
			end
		end
	end
	return nil, false
end

local function readSpecializations()
	if not (
		C_SpecializationInfo
		and C_SpecializationInfo.GetSpecialization
		and C_SpecializationInfo.GetSpecializationInfo
		and GetNumSpecializations
	) then
		return nil, nil, false
	end
	if C_SpecializationInfo.IsInitialized then
		local initializedOK, initialized = pcall(
			C_SpecializationInfo.IsInitialized
		)
		if not initializedOK or initialized ~= true then
			return nil, nil, false
		end
	end
	local countOK, count = pcall(GetNumSpecializations, false, false)
	count = countOK and tonumber(count) or nil
	local selectedOK, selectedIndex = pcall(
		C_SpecializationInfo.GetSpecialization
	)
	selectedIndex = selectedOK and tonumber(selectedIndex) or nil
	if not count or count <= 0
		or not selectedIndex or selectedIndex <= 0
	then
		return nil, nil, false
	end
	local sex = UnitSex and UnitSex("player") or nil
	local options = {}
	for specIndex = 1, math.floor(count) do
		local infoOK, specID, name, description, icon, role =
			pcall(
				C_SpecializationInfo.GetSpecializationInfo,
				specIndex,
				false,
				false,
				nil,
				sex
			)
		specID = infoOK and tonumber(specID) or nil
		if not specID or specID <= 0 then
			return nil, nil, false
		end
		options[#options + 1] = {
			specIndex = specIndex,
			specID = specID,
			name = type(name) == "string" and name ~= "" and name or nil,
			description = type(description) == "string"
				and description ~= "" and description or nil,
			icon = icon,
			role = role,
		}
	end
	if selectedIndex > #options then
		return nil, nil, false
	end
	return options, selectedIndex, true
end

local function readConfigIDs(specID)
	if not (
		C_ClassTalents
		and C_ClassTalents.GetConfigIDsBySpecID
	) then
		return nil, false
	end
	local ok, configIDs = pcall(
		C_ClassTalents.GetConfigIDsBySpecID,
		specID
	)
	if not ok or type(configIDs) ~= "table" then
		return nil, false
	end
	local copy = {}
	for _, configID in ipairs(configIDs) do
		configID = tonumber(configID)
		if configID then
			copy[#copy + 1] = configID
		end
	end
	return copy, true
end

local function readConfigName(configID)
	if not (C_Traits and C_Traits.GetConfigInfo) then
		return nil
	end
	local ok, info = pcall(C_Traits.GetConfigInfo, configID)
	if not ok or type(info) ~= "table" then
		return nil
	end
	if type(info.name) == "string" and info.name ~= "" then
		return info.name
	end
	return nil
end

local function readLastSelectedConfigID(specID)
	if not (
		C_ClassTalents
		and C_ClassTalents.GetLastSelectedSavedConfigID
	) then
		return nil, false
	end
	local ok, configID = pcall(
		C_ClassTalents.GetLastSelectedSavedConfigID,
		specID
	)
	if not ok then
		return nil, false
	end
	return tonumber(configID), true
end

local function readStarterBuildState()
	if not (
		C_ClassTalents
		and C_ClassTalents.GetHasStarterBuild
		and C_ClassTalents.GetStarterBuildActive
	) then
		return false, false, false
	end
	local hasOK, hasStarterBuild = pcall(
		C_ClassTalents.GetHasStarterBuild
	)
	local activeOK, starterBuildActive = pcall(
		C_ClassTalents.GetStarterBuildActive
	)
	return hasOK and hasStarterBuild == true,
		activeOK and starterBuildActive == true,
		hasOK and activeOK
end

local function getLoadedNativeTalentsFrame()
	local playerSpellsFrame = rawget(_G, "PlayerSpellsFrame")
	local talentsFrame = playerSpellsFrame
		and playerSpellsFrame.TalentsFrame or nil
	if talentsFrame
		and type(talentsFrame.LoadConfigByIndex) == "function"
	then
		return talentsFrame
	end
	return nil
end

local function callNativeSecurely(callback, ...)
	local secureCall = rawget(_G, "securecallfunction")
	if type(callback) ~= "function"
		or type(secureCall) ~= "function"
	then
		return false
	end
	return pcall(secureCall, callback, ...)
end

local function hasNativeLoadoutOwner()
	return type(rawget(_G, "securecallfunction")) == "function"
		and (
			getLoadedNativeTalentsFrame() ~= nil
			or type(rawget(_G, "PlayerSpellsFrame_LoadUI")) == "function"
		)
end

local function loadNativeTalentsFrame()
	local talentsFrame = getLoadedNativeTalentsFrame()
	if talentsFrame then
		return talentsFrame
	end
	local loader = rawget(_G, "PlayerSpellsFrame_LoadUI")
	if type(loader) ~= "function" then
		return nil
	end
	local ok = callNativeSecurely(loader)
	if not ok then
		return nil
	end
	return getLoadedNativeTalentsFrame()
end

local function getSpecializationSwitcher()
	return C_SpecializationInfo
		and type(C_SpecializationInfo.SetSpecialization) == "function"
		and C_SpecializationInfo.SetSpecialization
		or nil
end

local function isSpecializationActivateSpell(spellID)
	if not (spellID and IsSpecializationActivateSpell) then
		return false
	end
	local ok, isSpecializationSpell = pcall(
		IsSpecializationActivateSpell,
		spellID
	)
	return ok and isSpecializationSpell == true
end

local function readSpecializationCastTiming()
	if not UnitCastingInfo then
		return nil, nil
	end
	local ok, startTime, endTime = pcall(function()
		local _, _, _, startTimeMs, endTimeMs, _, _, _,
			spellID = UnitCastingInfo("player")
		if not isSpecializationActivateSpell(spellID) then
			return nil, nil
		end
		startTimeMs = tonumber(startTimeMs)
		endTimeMs = tonumber(endTimeMs)
		if not (
			startTimeMs
			and endTimeMs
			and startTimeMs >= 0
			and endTimeMs > startTimeMs
		) then
			return nil, nil
		end
		return startTimeMs / 1000, endTimeMs / 1000
	end)
	if not ok then
		return nil, nil
	end
	return startTime, endTime
end

local function captureSpecializationCastTiming(service, spellID)
	if not service.switchingSpecIndex then
		return false
	end
	if spellID ~= nil
		and not isSpecializationActivateSpell(spellID)
	then
		return false
	end
	local startTime, endTime = readSpecializationCastTiming()
	if startTime and endTime then
		service.specializationSwitchCastStartTime = startTime
		service.specializationSwitchCastEndTime = endTime
		return true
	end
	return spellID ~= nil
end

local function previousNamesByConfigID(previous, specID)
	local names = {}
	if not previous or previous.specID ~= specID then
		return names
	end
	for _, option in ipairs(previous.options or {}) do
		if option.kind == "saved"
			and option.configID
			and type(option.name) == "string"
			and option.name ~= ""
		then
			names[option.configID] = option.name
		end
	end
	return names
end

local function findSelectedIndex(options, selectedConfigID, starterBuildActive)
	if starterBuildActive then
		return nil
	end
	for index, option in ipairs(options or {}) do
		if selectedConfigID
			and option.kind == "saved"
			and option.configID == selectedConfigID
		then
			return index
		end
	end
	return nil
end

local function findOptionByConfigID(options, configID)
	for index, option in ipairs(options or {}) do
		if option.kind == "saved" and option.configID == configID then
			return option, index
		end
	end
	return nil, nil
end

local function findSpecializationBySpecID(options, specID)
	for _, option in ipairs(options or {}) do
		if tonumber(option.specID) == tonumber(specID) then
			return option
		end
	end
	return nil
end

local function clearSpecializationSwitchState(service)
	local hadState = service.switchingSpecIndex ~= nil
		or service.switchingSpecID ~= nil
	if service.specializationSwitchTimer
		and service.specializationSwitchTimer.Cancel
	then
		service.specializationSwitchTimer:Cancel()
	end
	service.specializationSwitchTimer = nil
	service.specializationSwitchTicket =
		(tonumber(service.specializationSwitchTicket) or 0) + 1
	service.switchingSpecIndex = nil
	service.switchingSpecID = nil
	service.switchingSourceSpecID = nil
	service.specializationSwitchStartedAt = nil
	service.specializationSwitchCastStartTime = nil
	service.specializationSwitchCastEndTime = nil
	return hadState
end

local function decorateSpecializationSnapshot(
	service,
	snapshot,
	previous,
	options,
	selectedIndex,
	ready,
	acceptIncomplete
)
	local preserve = not ready
		and not acceptIncomplete
		and previous
		and type(previous.specializations) == "table"
		and #previous.specializations > 0
	local displayedOptions = ready and options
		or preserve and previous.specializations
		or {}
	local displayedSelectedIndex = ready and selectedIndex
		or preserve and previous.selectedSpecIndex
		or nil
	local selected = displayedSelectedIndex
		and displayedOptions[displayedSelectedIndex] or nil
	snapshot.specializations = displayedOptions
	snapshot.selectedSpecIndex = displayedSelectedIndex
	snapshot.selectedSpecID = selected and selected.specID or nil
	snapshot.specializationState = ready and "ready"
		or acceptIncomplete and "unavailable"
		or "pending"
	snapshot.specializationSwitchPending =
		service.switchingSpecIndex ~= nil
	snapshot.switchingSpecIndex = service.switchingSpecIndex
	snapshot.switchingSpecID = service.switchingSpecID
	snapshot.switchingSourceSpecID =
		service.switchingSourceSpecID
	snapshot.specializationSwitchCastStartTime =
		service.specializationSwitchCastStartTime
	snapshot.specializationSwitchCastEndTime =
		service.specializationSwitchCastEndTime
	snapshot.canSwitchSpecialization = ready
		and #displayedOptions > 1
		and getSpecializationSwitcher() ~= nil
		and service.switchingSpecIndex == nil
	if service.switchingSpecIndex ~= nil then
		snapshot.canSwitch = false
	end
	return snapshot
end

local function makePendingSnapshot(previous, specID, reason, incompleteReason)
	local canPreserve = previous
		and previous.state == "ready"
		and previous.specID == specID
	return {
		state = canPreserve and "ready" or "pending",
		specID = specID or (previous and previous.specID),
		options = canPreserve and previous.options or {},
		selectedConfigID = canPreserve and previous.selectedConfigID or nil,
		selectedIndex = canPreserve and previous.selectedIndex or nil,
		selectionKnown = canPreserve and previous.selectionKnown or false,
		hasStarterBuild = canPreserve
			and previous.hasStarterBuild == true,
		starterBuildActive = canPreserve
			and previous.starterBuildActive == true,
		canSwitch = canPreserve and previous.canSwitch == true,
		coherent = canPreserve and previous.coherent ~= false,
		pending = true,
		stale = true,
		incompleteReason = incompleteReason,
		updatedAt = Util.Now(),
		reason = reason,
	}
end

local function makeUnavailableSnapshot(specID, reason, incompleteReason)
	return {
		state = "unavailable",
		specID = specID,
		options = {},
		selectedConfigID = nil,
		selectedIndex = nil,
		selectionKnown = false,
		hasStarterBuild = false,
		starterBuildActive = false,
		canSwitch = false,
		coherent = false,
		stale = true,
		incompleteReason = incompleteReason,
		updatedAt = Util.Now(),
		reason = reason,
	}
end

local function getIncompleteReason(
	previous,
	specID,
	options,
	missingNames,
	selectedConfigID,
	selectedIndex,
	selectionReady,
	starterBuildActive,
	starterStateReady,
	emptyListConfirmed
)
	if not selectionReady then
		return "selection-unavailable"
	end
	if not starterStateReady then
		return "starter-state-unavailable"
	end
	if missingNames then
		return "config-name-unavailable"
	end
	if selectedConfigID and not starterBuildActive and not selectedIndex then
		return "selection-not-in-list"
	end
	if #options == 0 and not emptyListConfirmed then
		return "empty-config-list"
	end
	if previous
		and previous.state == "ready"
		and previous.specID == specID
		and #(previous.options or {}) > #options
	then
		return "config-list-shrank"
	end
	return nil
end

function Service:AddListener(callback)
	Util.AddListener(self, callback)
end

function Service:GetSnapshot()
	return self.snapshot
end

function Service:Refresh(reason, acceptIncomplete)
	local previous = self.snapshot
	local specializations, selectedSpecIndex, specializationsReady =
		readSpecializations()
	if specializationsReady
		and self.switchingSpecIndex
		and selectedSpecIndex == self.switchingSpecIndex
	then
		clearSpecializationSwitchState(self)
	end
	local specID, specReady = readCurrentSpecID()
	local configIDs
	local configsReady = false
	if specReady then
		configIDs, configsReady = readConfigIDs(specID)
	end

	if not (specReady and configsReady) then
		if acceptIncomplete then
			self.snapshot = makeUnavailableSnapshot(
				specID,
				reason,
				"config-list-unavailable"
			)
		else
			self.snapshot = makePendingSnapshot(
				previous,
				specID,
				reason,
				"config-list-unavailable"
			)
		end
		decorateSpecializationSnapshot(
			self,
			self.snapshot,
			previous,
			specializations,
			selectedSpecIndex,
			specializationsReady,
			acceptIncomplete
		)
		Util.Notify(self, reason or "refresh")
		return self.snapshot, not acceptIncomplete
	end

	local previousNames = previousNamesByConfigID(previous, specID)
	local options = {}
	local missingNames = false
	for index, configID in ipairs(configIDs) do
		local name = readConfigName(configID)
		if not name then
			missingNames = true
		end
		name = name or previousNames[configID]
		options[#options + 1] = {
			kind = "saved",
			loadoutIndex = index,
			configID = configID,
			name = name,
		}
	end

	local hasStarterBuild, starterBuildActive, starterStateReady =
		readStarterBuildState()
	if not starterStateReady
		and previous
		and previous.specID == specID
	then
		hasStarterBuild = previous.hasStarterBuild == true
		starterBuildActive = previous.starterBuildActive == true
	end
	-- Blizzard appends Starter Build to its own loadout dropdown. GroupFinder
	-- intentionally exposes only player-saved loadouts, while retaining the
	-- active flag so a saved loadout is not shown as selected during Starter
	-- Build.

	local selectedConfigID, selectionReady =
		readLastSelectedConfigID(specID)
	if not selectionReady
		and previous
		and previous.specID == specID
	then
		selectedConfigID = previous.selectedConfigID
	end
	local selectedIndex = findSelectedIndex(
		options,
		selectedConfigID,
		starterBuildActive
	)
	local selectionKnown = false
	if selectionReady then
		selectionKnown = starterBuildActive
			or selectedConfigID == nil
			or selectedIndex ~= nil
	elseif previous and previous.specID == specID then
		selectionKnown = previous.selectionKnown ~= false
	end
	local incompleteReason = getIncompleteReason(
		previous,
		specID,
		options,
		missingNames,
		selectedConfigID,
		selectedIndex,
		selectionReady,
		starterBuildActive,
		starterStateReady,
		self.confirmedEmptySpecID == specID
	)

	if incompleteReason and not acceptIncomplete then
		self.snapshot = makePendingSnapshot(
			previous,
			specID,
			reason,
			incompleteReason
		)
		decorateSpecializationSnapshot(
			self,
			self.snapshot,
			previous,
			specializations,
			selectedSpecIndex,
			specializationsReady,
			acceptIncomplete
		)
		Util.Notify(self, reason or "refresh")
		return self.snapshot, true
	end

	self.snapshot = {
		state = "ready",
		specID = specID,
		options = options,
		selectedConfigID = selectedConfigID,
		selectedIndex = selectedIndex,
		selectionKnown = selectionKnown,
		hasStarterBuild = hasStarterBuild,
		starterBuildActive = starterBuildActive,
		canSwitch = #options > 0 and hasNativeLoadoutOwner(),
		coherent = incompleteReason == nil,
		stale = incompleteReason and true or nil,
		incompleteReason = incompleteReason,
		updatedAt = Util.Now(),
		reason = reason,
	}
	decorateSpecializationSnapshot(
		self,
		self.snapshot,
		previous,
		specializations,
		selectedSpecIndex,
		specializationsReady,
		acceptIncomplete
	)
	if #options == 0 then
		self.confirmedEmptySpecID = specID
	elseif self.confirmedEmptySpecID == specID then
		self.confirmedEmptySpecID = nil
	end
	Util.Notify(self, reason or "refresh")
	return self.snapshot,
		not specializationsReady and not acceptIncomplete
end

function Service:CancelReadinessRetry()
	if self.readinessRetryTimer
		and self.readinessRetryTimer.Cancel
	then
		self.readinessRetryTimer:Cancel()
	end
	self.readinessRetryTimer = nil
	self.readinessRetryTicket =
		(tonumber(self.readinessRetryTicket) or 0) + 1
end

function Service:ScheduleReadinessRetry(reason, attempt)
	local delay = READINESS_RETRY_DELAYS[attempt]
	if not (
		delay
		and C_Timer
		and C_Timer.NewTimer
	) then
		return false
	end
	self:CancelReadinessRetry()
	local ticket = self.readinessRetryTicket
	self.readinessRetryTimer = C_Timer.NewTimer(delay, function()
		if Service.readinessRetryTicket ~= ticket then
			return
		end
		Service.readinessRetryTimer = nil
		Service:RequestRefresh(reason, attempt)
	end)
	return true
end

function Service:RequestRefresh(reason, retryAttempt)
	retryAttempt = math.max(0, math.floor(tonumber(retryAttempt) or 0))
	if retryAttempt == 0 then
		self:CancelReadinessRetry()
	end
	self.pendingRefreshReason = reason or self.pendingRefreshReason or "refresh"
	self.pendingRetryAttempt = retryAttempt
	if self.refreshQueued then
		return self.snapshot
	end
	self.refreshQueued = true
	local function run()
		Service.refreshQueued = nil
		local refreshReason = Service.pendingRefreshReason or "refresh"
		local attempt = Service.pendingRetryAttempt or 0
		Service.pendingRefreshReason = nil
		Service.pendingRetryAttempt = nil
		local acceptIncomplete = attempt >= #READINESS_RETRY_DELAYS
		local snapshot, needsRetry = Service:Refresh(
			refreshReason,
			acceptIncomplete
		)
		if needsRetry then
			Service:ScheduleReadinessRetry(
				refreshReason,
				attempt + 1
			)
		else
			Service:CancelReadinessRetry()
		end
		return snapshot
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		run()
	end
	return self.snapshot
end

function Service:GetSpecializationSwitchStatus()
	local snapshot = self.snapshot
	if self.switchingSpecIndex ~= nil then
		return false, "switching"
	end
	if not (
		snapshot
		and snapshot.specializationState == "ready"
		and snapshot.canSwitchSpecialization == true
		and getSpecializationSwitcher()
	) then
		return false, "unavailable"
	end
	if C_SpecializationInfo
		and C_SpecializationInfo.CanPlayerUseTalentSpecUI
	then
		local ok, canUse, failureReason = pcall(
			C_SpecializationInfo.CanPlayerUseTalentSpecUI
		)
		if not ok or canUse ~= true then
			return false,
				"restricted",
				type(failureReason) == "string"
					and failureReason ~= "" and failureReason or nil
		end
	end
	return true
end

function Service:ScheduleSpecializationSwitchTimeout()
	if not (C_Timer and C_Timer.NewTimer) then
		return false
	end
	if self.specializationSwitchTimer
		and self.specializationSwitchTimer.Cancel
	then
		self.specializationSwitchTimer:Cancel()
	end
	self.specializationSwitchTicket =
		(tonumber(self.specializationSwitchTicket) or 0) + 1
	local ticket = self.specializationSwitchTicket
	self.specializationSwitchTimer = C_Timer.NewTimer(
		SPECIALIZATION_SWITCH_TIMEOUT,
		function()
			if Service.specializationSwitchTicket ~= ticket then
				return
			end
			Service.specializationSwitchTimer = nil
			clearSpecializationSwitchState(Service)
			Service:RequestRefresh("specialization-switch-timeout")
		end
	)
	return true
end

function Service:SwitchToSpecialization(specID)
	specID = tonumber(specID)
	if not specID then
		return false, "unavailable"
	end
	local canSwitch, status, failureReason =
		self:GetSpecializationSwitchStatus()
	if not canSwitch then
		return false, status, failureReason
	end

	local options, selectedIndex, ready = readSpecializations()
	local option = ready and findSpecializationBySpecID(options, specID) or nil
	if not option then
		self:RequestRefresh("specialization-switch-revalidate")
		return false, "stale"
	end
	if selectedIndex == option.specIndex then
		return false, "selected"
	end

	local switcher = getSpecializationSwitcher()
	if not switcher then
		return false, "unavailable"
	end
	self.switchingSpecIndex = option.specIndex
	self.switchingSpecID = option.specID
	self.switchingSourceSpecID = options[selectedIndex]
		and options[selectedIndex].specID or nil
	self.specializationSwitchStartedAt = Util.Now()
	local ok, success = pcall(switcher, option.specIndex)
	if not ok or success ~= true then
		clearSpecializationSwitchState(self)
		return false, "failed"
	end
	captureSpecializationCastTiming(self)
	self:ScheduleSpecializationSwitchTimeout()
	if self.snapshot then
		self.snapshot.specializationSwitchPending = true
		self.snapshot.switchingSpecIndex = option.specIndex
		self.snapshot.switchingSpecID = option.specID
		self.snapshot.switchingSourceSpecID =
			self.switchingSourceSpecID
		self.snapshot.specializationSwitchCastStartTime =
			self.specializationSwitchCastStartTime
		self.snapshot.specializationSwitchCastEndTime =
			self.specializationSwitchCastEndTime
		self.snapshot.canSwitchSpecialization = false
		self.snapshot.canSwitch = false
	end
	Util.Notify(self, "specialization-switch-requested")
	self:RequestRefresh("specialization-switch-requested")
	return true, "requested"
end

function Service:SwitchToConfigID(configID)
	configID = tonumber(configID)
	local snapshot = self.snapshot
	local option = configID
		and snapshot
		and snapshot.state == "ready"
		and snapshot.canSwitch == true
		and findOptionByConfigID(snapshot.options, configID)
	if not option then
		return false, "unavailable"
	end

	local specID, specReady = readCurrentSpecID()
	local configIDs, configsReady
	if specReady then
		configIDs, configsReady = readConfigIDs(specID)
	end
	local loadoutIndex
	if configsReady then
		for index, currentConfigID in ipairs(configIDs) do
			if currentConfigID == configID then
				loadoutIndex = index
				break
			end
		end
	end
	if not loadoutIndex then
		self:RequestRefresh("switch-revalidate")
		return false, "stale"
	end

	local selectedConfigID, selectionReady =
		readLastSelectedConfigID(specID)
	local _, starterBuildActive, starterStateReady =
		readStarterBuildState()
	if selectionReady
		and starterStateReady
		and not starterBuildActive
		and selectedConfigID == configID
	then
		return false, "selected"
	end

	local talentsFrame = loadNativeTalentsFrame()
	if not talentsFrame then
		return false, "unavailable"
	end
	if talentsFrame.variablesLoaded ~= true
		or type(talentsFrame.configIDs) ~= "table"
	then
		return false, "unavailable"
	end
	if tonumber(talentsFrame.configIDs[loadoutIndex]) ~= configID then
		self:RequestRefresh("switch-revalidate")
		return false, "stale"
	end

	-- The script-command loadout switch entry is restricted and cannot be
	-- called by this addon menu responder. Delegate the
	-- already revalidated index to Blizzard_PlayerSpells' native transaction
	-- owner, which performs the same LoadConfig/commit lifecycle as the
	-- Blizzard talent frame without invoking the restricted API.
	local ok = callNativeSecurely(
		talentsFrame.LoadConfigByIndex,
		talentsFrame,
		loadoutIndex
	)
	if not ok then
		return false, "failed"
	end
	-- Do not optimistically change the selection. Blizzard owns the switch
	-- transaction and its events refresh this snapshot after the result is known.
	self:RequestRefresh("switch-requested")
	return true, "requested"
end

function Service:SwitchToIndex(loadoutIndex)
	loadoutIndex = tonumber(loadoutIndex)
	loadoutIndex = loadoutIndex and math.floor(loadoutIndex) or nil
	local snapshot = self.snapshot
	local option = loadoutIndex
		and snapshot
		and snapshot.options
		and snapshot.options[loadoutIndex]
	if not option then
		return false, "unavailable"
	end
	return self:SwitchToConfigID(option.configID)
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.eventFrame = CreateFrame("Frame")
	for _, event in ipairs(LOADOUT_EVENTS) do
		pcall(
			self.eventFrame.RegisterEvent,
			self.eventFrame,
			event
		)
	end
	self.eventFrame:SetScript("OnEvent", function(_, event, ...)
		if event == "PLAYER_SPECIALIZATION_CHANGED"
			and (...) ~= "player"
		then
			return
		end
		if event == "UNIT_SPELLCAST_FAILED"
			or event == "UNIT_SPELLCAST_INTERRUPTED"
		then
			local unitTarget, _, spellID = ...
			if unitTarget ~= "player"
				or not Service.switchingSpecIndex
			then
				return
			end
			if not isSpecializationActivateSpell(spellID) then
				return
			end
			clearSpecializationSwitchState(Service)
		elseif event == "UNIT_SPELLCAST_START"
			or event == "UNIT_SPELLCAST_DELAYED"
		then
			local unitTarget, _, spellID = ...
			if unitTarget ~= "player"
				or not captureSpecializationCastTiming(
					Service,
					spellID
				)
			then
				return
			end
		elseif event == "PLAYER_SPECIALIZATION_CHANGED"
			or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
		then
			clearSpecializationSwitchState(Service)
		end
		Service:RequestRefresh(event)
	end)
	self:RequestRefresh("init")
end
