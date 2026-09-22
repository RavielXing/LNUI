local _, GF = ...

GF.MythicPlusKeystoneRotationReminderService =
	GF.MythicPlusKeystoneRotationReminderService or {}
local Service = GF.MythicPlusKeystoneRotationReminderService
local Util = GF.MythicPlusServiceUtil

local PLAYER_START_GRACE_SECONDS = 10
local OWNED_KEYSTONE_ENTRY_REFRESH_DELAY = 1
local COMPLETION_RETRY_DELAYS = { 0, 0.25, 0.75, 1.5 }

local function notify(owner, reason)
	owner.lastTransitionReason = reason
	if Util and Util.Notify then
		Util.Notify(owner, reason)
		return
	end
	for _, callback in ipairs(owner.listeners or {}) do
		pcall(callback, owner, reason)
	end
end

local function canAccessValue(value)
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return true
end

local function positiveNumber(value)
	if not canAccessValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or not number or number <= 0 then
		return nil
	end
	return number
end

local function readableString(value)
	if not canAccessValue(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function getAccessibleField(owner, field)
	if not canAccessValue(owner) or type(owner) ~= "table" then
		return nil, false
	end
	local ok, value = pcall(function()
		return owner[field]
	end)
	if not ok or not canAccessValue(value) then
		return nil, false
	end
	return value, true
end

local function getMythicPlusSettings()
	local mythicPlus
	if GF.GetMythicPlusDB then
		local ok, value = pcall(GF.GetMythicPlusDB)
		if ok and type(value) == "table" then
			mythicPlus = value
		end
	end
	if not mythicPlus then
		local db = GF.GetDB and GF.GetDB() or GF.db
		if type(db) ~= "table" then
			return nil
		end
		db.mythicPlus = type(db.mythicPlus) == "table"
			and db.mythicPlus or {}
		mythicPlus = db.mythicPlus
	end
	mythicPlus.settings = type(mythicPlus.settings) == "table"
		and mythicPlus.settings or {}
	local settings = mythicPlus.settings
	if settings.keystoneRotationReminderEnabled == nil then
		settings.keystoneRotationReminderEnabled = false
	else
		settings.keystoneRotationReminderEnabled =
			settings.keystoneRotationReminderEnabled == true
	end
	return settings
end

local function getCurrentTime()
	if type(GetTime) == "function" then
		local ok, value = pcall(GetTime)
		value = ok and tonumber(value) or nil
		if value then
			return value
		end
	end
	return type(time) == "function" and time() or 0
end

local function getActiveKeystoneLevel()
	if not (C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo) then
		return nil
	end
	local ok, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
	return ok and positiveNumber(level) or nil
end

local function getActiveChallengeModeID()
	if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then
		return nil
	end
	local ok, challengeModeID = pcall(
		C_ChallengeMode.GetActiveChallengeMapID)
	return ok and positiveNumber(challengeModeID) or nil
end

local function getCompletionInfo()
	if not (C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo) then
		return nil
	end
	local ok, info = pcall(C_ChallengeMode.GetChallengeCompletionInfo)
	if not ok or not canAccessValue(info) or type(info) ~= "table" then
		return nil
	end
	return info
end

local function getOwnedKeystoneLevel()
	if not (C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel) then
		return nil
	end
	local ok, level = pcall(C_MythicPlus.GetOwnedKeystoneLevel)
	return ok and positiveNumber(level) or nil
end

local function getOwnedChallengeModeID()
	if not (C_MythicPlus
		and C_MythicPlus.GetOwnedKeystoneChallengeMapID)
	then
		return nil
	end
	local ok, challengeModeID = pcall(
		C_MythicPlus.GetOwnedKeystoneChallengeMapID)
	return ok and positiveNumber(challengeModeID) or nil
end

local function getDungeonName(challengeModeID)
	if not challengeModeID then
		return nil
	end
	local dungeon = GF.MythicPlusSeason
		and GF.MythicPlusSeason.GetByChallengeModeID
		and GF.MythicPlusSeason:GetByChallengeModeID(challengeModeID) or nil
	local name = dungeon and readableString(dungeon.name) or nil
	if name then
		return name
	end
	if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
		local ok, value = pcall(
			C_ChallengeMode.GetMapUIInfo,
			challengeModeID)
		return ok and readableString(value) or nil
	end
	return nil
end

local function getSharedOwnedKeystoneSnapshot()
	local cache = GF.MythicPlusKeystoneCache
	local snapshot = cache and cache.GetSnapshot and cache:GetSnapshot() or nil
	if not snapshot or not canAccessValue(snapshot)
		or type(snapshot) ~= "table"
	then
		return nil
	end
	local state = readableString(snapshot.state)
	if state == "empty" then
		return {
			state = "empty",
			source = "shared-cache",
		}
	end
	local level = positiveNumber(snapshot.level)
	if not level then
		return nil
	end
	return {
		state = state,
		challengeModeID = positiveNumber(snapshot.challengeModeID),
		level = level,
		dungeonName = readableString(snapshot.dungeonName),
		source = "shared-cache",
	}
end

local function copyOwnedKeystoneSnapshot(source)
	if type(source) ~= "table" or not positiveNumber(source.level) then
		return nil
	end
	return {
		challengeModeID = positiveNumber(source.challengeModeID),
		level = positiveNumber(source.level),
		dungeonName = readableString(source.dungeonName),
		capturedAt = tonumber(source.capturedAt),
		source = readableString(source.source),
	}
end

local function classifyCompletion(session, info, enabled)
	if not session or not session.armed
		or session.starterEvidence ~= "other"
		or enabled ~= true
	then
		return "ineligible"
	end
	local practiceRun, practiceReadable = getAccessibleField(
		info, "practiceRun")
	local onTime, onTimeReadable = getAccessibleField(info, "onTime")
	local completedMapID = getAccessibleField(
		info, "mapChallengeModeID")
	local completedLevel, levelReadable = getAccessibleField(info, "level")
	completedMapID = positiveNumber(completedMapID)
	completedLevel = positiveNumber(completedLevel)
	if not info or not practiceReadable or not onTimeReadable
		or not levelReadable or not completedLevel
	then
		return "unreadable"
	end
	if practiceRun ~= false or onTime ~= true
		or completedLevel < session.ownedLevel
	then
		return "ineligible", completedLevel, completedMapID
	end
	return "eligible", completedLevel, completedMapID
end

local function nextToken(owner)
	owner.presentationSerial = (tonumber(owner.presentationSerial) or 0) + 1
	return owner.presentationSerial
end

local function setProjection(owner, session, completedLevel, completedMapID)
	owner.presentation = {
		token = nextToken(owner),
		kind = "actual",
		runLevel = completedLevel or session.runLevel,
		ownedLevel = session.ownedLevel,
		ownedDungeonName = session.ownedDungeonName,
		completedChallengeModeID = completedMapID,
	}
end

local function hookStartButton()
	local frame = _G.ChallengesKeystoneFrame
	local button = frame and frame.StartButton
	if not button or type(button.HookScript) ~= "function"
		or Service.startButtonHooked
	then
		return false
	end
	button:HookScript("OnClick", function()
		Service:MarkRunStartedByPlayer()
	end)
	Service.startButtonHooked = true
	return true
end

local function scheduleStartButtonHook()
	hookStartButton()
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, hookStartButton)
		C_Timer.After(0.5, hookStartButton)
	end
end

function Service:AddListener(callback)
	if Util and Util.AddListener then
		Util.AddListener(self, callback)
	elseif type(callback) == "function" then
		self.listeners = self.listeners or {}
		self.listeners[#self.listeners + 1] = callback
	end
end

function Service:IsEnabled()
	local settings = getMythicPlusSettings()
	return settings and settings.keystoneRotationReminderEnabled == true or false
end

function Service:SetEnabled(enabled)
	local settings = getMythicPlusSettings()
	if not settings then
		return false
	end
	enabled = enabled == true
	if settings.keystoneRotationReminderEnabled == enabled then
		return true
	end
	settings.keystoneRotationReminderEnabled = enabled
	if not enabled and self.presentation then
		self.presentation = nil
		notify(self, "setting-disabled")
	else
		notify(self, "setting")
	end
	return true
end

function Service:GetProjection()
	local source = self.presentation
	if type(source) ~= "table" then
		return nil
	end
	return {
		token = source.token,
		kind = source.kind,
		runLevel = source.runLevel,
		ownedLevel = source.ownedLevel,
		ownedDungeonName = source.ownedDungeonName,
		completedChallengeModeID = source.completedChallengeModeID,
	}
end

function Service:GetOwnedKeystoneSnapshot()
	return copyOwnedKeystoneSnapshot(self.ownedKeystoneSnapshot)
end

function Service:GetSessionSnapshot()
	local source = self.session
	if type(source) ~= "table" then
		return nil
	end
	return {
		token = source.token,
		eventMapID = source.eventMapID,
		activeChallengeModeID = source.activeChallengeModeID,
		runLevel = source.runLevel,
		ownedChallengeModeID = source.ownedChallengeModeID,
		ownedLevel = source.ownedLevel,
		ownedDungeonName = source.ownedDungeonName,
		ownedSnapshotSource = source.ownedSnapshotSource,
		starterEvidence = source.starterEvidence,
		armed = source.armed == true,
		completionObserved = source.completionObserved == true,
	}
end

function Service:GetDiagnosticSnapshot()
	return {
		lastTransitionReason = self.lastTransitionReason,
		lastCompletionOutcome = self.lastCompletionOutcome,
		lastIgnoredCompletionReason = self.lastIgnoredCompletionReason,
		lastOwnedRefreshReason = self.lastOwnedRefreshReason,
		ownedKeystone = self:GetOwnedKeystoneSnapshot(),
		session = self:GetSessionSnapshot(),
		presentation = self:GetProjection(),
		startButtonHooked = self.startButtonHooked == true,
	}
end

function Service:DismissPresentation(token)
	if not self.presentation
		or token ~= nil and token ~= self.presentation.token
	then
		return false
	end
	self.presentation = nil
	notify(self, "dismiss")
	return true
end

function Service:RequestPreview()
	if self.presentation and self.presentation.kind == "actual" then
		return false
	end
	local owned = self:RefreshOwnedKeystoneSnapshot("preview")
	self.presentation = {
		token = nextToken(self),
		kind = "preview",
		runLevel = 12,
		ownedLevel = 10,
		ownedDungeonName = owned and owned.dungeonName or nil,
	}
	notify(self, "preview")
	return true
end

function Service:InvalidateCompletionRetries()
	self.completionRetrySerial =
		(tonumber(self.completionRetrySerial) or 0) + 1
end

function Service:ClearRun(reason, clearPreview)
	self.session = nil
	self:InvalidateCompletionRetries()
	if clearPreview and self.presentation
		and self.presentation.kind == "preview"
	then
		self.presentation = nil
	end
	notify(self, reason or "run-clear")
end

function Service:Clear(reason, clearPresentation)
	self.session = nil
	self:InvalidateCompletionRetries()
	if clearPresentation == true then
		self.presentation = nil
	end
	notify(self, reason or "clear")
end

function Service:RefreshOwnedKeystoneSnapshot(reason)
	local shared = getSharedOwnedKeystoneSnapshot()
	local previous = self.ownedKeystoneSnapshot
	local liveLevel = getOwnedKeystoneLevel()
	local liveChallengeModeID = getOwnedChallengeModeID()
	if not liveLevel and shared and shared.state == "empty" then
		self.ownedKeystoneSnapshot = nil
		self.lastOwnedRefreshReason = reason
		return nil
	end
	local level = liveLevel
		or shared and shared.level
		or previous and positiveNumber(previous.level)
	if not level then
		self.lastOwnedRefreshReason = reason
		return copyOwnedKeystoneSnapshot(previous)
	end

	local challengeModeID = liveChallengeModeID
		or shared and shared.challengeModeID
		or previous and positiveNumber(previous.challengeModeID)
	local dungeonName
	if liveChallengeModeID then
		dungeonName = getDungeonName(liveChallengeModeID)
	end
	dungeonName = dungeonName
		or shared and shared.dungeonName
		or challengeModeID and getDungeonName(challengeModeID)
		or previous and readableString(previous.dungeonName)

	self.ownedKeystoneSnapshot = {
		challengeModeID = challengeModeID,
		level = level,
		dungeonName = dungeonName,
		capturedAt = getCurrentTime(),
		source = liveLevel and "owned-api"
			or shared and "shared-cache"
			or previous and previous.source
			or "retained",
	}
	self.lastOwnedRefreshReason = reason
	return copyOwnedKeystoneSnapshot(self.ownedKeystoneSnapshot)
end

function Service:QueueOwnedKeystoneRefresh(delay, reason)
	if not (C_Timer and type(C_Timer.After) == "function") then
		return false
	end
	C_Timer.After(delay or 0, function()
		Service:RefreshOwnedKeystoneSnapshot(reason or "delayed")
	end)
	return true
end

function Service:MarkRunStartedByPlayer()
	self.playerStartTime = getCurrentTime()
	self:ClearRun("player-start-intent", true)
	return true
end

function Service:WasRecentlyStartedByPlayer()
	local startedAt = tonumber(self.playerStartTime)
	if not startedAt then
		return false
	end
	local elapsed = getCurrentTime() - startedAt
	return elapsed >= 0 and elapsed <= PLAYER_START_GRACE_SECONDS
end

function Service:BeginSession(eventMapID)
	self:ClearRun("challenge-start-clear", true)
	if self:WasRecentlyStartedByPlayer() then
		notify(self, "challenge-start-player")
		return false
	end

	local owned = self:RefreshOwnedKeystoneSnapshot("challenge-start")
	local runLevel = getActiveKeystoneLevel()
	if not owned or not owned.level or not runLevel
		or runLevel < owned.level
	then
		notify(self, "challenge-start-ineligible")
		return false
	end

	self.sessionSerial = (tonumber(self.sessionSerial) or 0) + 1
	self.session = {
		token = self.sessionSerial,
		eventMapID = positiveNumber(eventMapID),
		activeChallengeModeID = getActiveChallengeModeID(),
		runLevel = runLevel,
		ownedChallengeModeID = owned.challengeModeID,
		ownedLevel = owned.level,
		ownedDungeonName = owned.dungeonName,
		ownedSnapshotSource = owned.source,
		starterEvidence = "other",
		armed = true,
	}
	notify(self, "challenge-start-other")
	return true
end

function Service:QueueCompletionRetries(session)
	if not session or session.completionRetryQueued
		or not (C_Timer and type(C_Timer.After) == "function")
	then
		return false
	end
	session.completionRetryQueued = true
	self:InvalidateCompletionRetries()
	local serial = self.completionRetrySerial
	for _, delay in ipairs(COMPLETION_RETRY_DELAYS) do
		C_Timer.After(delay, function()
			if Service.completionRetrySerial ~= serial
				or Service.session ~= session
				or not session.completionObserved
			then
				return
			end
			Service:CompleteSession("completion-retry")
		end)
	end
	return true
end

function Service:CompleteSession(reason)
	local session = self.session
	if not session then
		self.lastIgnoredCompletionReason = "no-session"
		return false
	end
	local outcome, completedLevel, completedMapID = classifyCompletion(
		session,
		getCompletionInfo(),
		self:IsEnabled())
	self.lastCompletionOutcome = outcome
	self.lastIgnoredCompletionReason = nil
	if outcome == "ineligible" then
		self.session = nil
		self:InvalidateCompletionRetries()
		return false
	end
	if outcome == "unreadable" then
		session.completionObserved = true
		self:QueueCompletionRetries(session)
		return false
	end
	self.session = nil
	self:InvalidateCompletionRetries()
	setProjection(self, session, completedLevel, completedMapID)
	notify(self, reason or "completed")
	return true
end

function Service:HandleEvent(event, ...)
	if event == "ADDON_LOADED" then
		if (...) == "Blizzard_ChallengesUI" then
			scheduleStartButtonHook()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		scheduleStartButtonHook()
		self:RefreshOwnedKeystoneSnapshot(event)
		self:QueueOwnedKeystoneRefresh(
			OWNED_KEYSTONE_ENTRY_REFRESH_DELAY,
			"player-entering-world-delayed")
	elseif event == "BAG_UPDATE_DELAYED" or event == "ITEM_CHANGED" then
		self:RefreshOwnedKeystoneSnapshot(event)
	elseif event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN"
		or event == "CHALLENGE_MODE_KEYSTONE_SLOTTED"
	then
		scheduleStartButtonHook()
		self:RefreshOwnedKeystoneSnapshot(event)
	elseif event == "CHALLENGE_MODE_START" then
		return self:BeginSession(...)
	elseif event == "CHALLENGE_MODE_COMPLETED" then
		return self:CompleteSession("completed")
	elseif event == "CHALLENGE_MODE_COMPLETED_REWARDS" then
		local completed = self:CompleteSession("completed-rewards")
		self:QueueOwnedKeystoneRefresh(0.5, event)
		return completed
	elseif event == "CHALLENGE_MODE_RESET" then
		if self.session and self.session.completionObserved then
			notify(self, "reset-after-completion")
		else
			self:ClearRun(event, true)
		end
		self:QueueOwnedKeystoneRefresh(0.5, event)
	end
	return false
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	getMythicPlusSettings()
	self:RefreshOwnedKeystoneSnapshot("service-init")
	scheduleStartButtonHook()
end
