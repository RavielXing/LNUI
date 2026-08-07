local _, GF = ...

GF.MythicPlusKeystoneRotationReminderService =
	GF.MythicPlusKeystoneRotationReminderService or {}
local Service = GF.MythicPlusKeystoneRotationReminderService
local Util = GF.MythicPlusServiceUtil

local OWNERSHIP_CONFIRM_TIMEOUT = 3
local OWNERSHIP_CONFIRM_DELAY = 0.75
local OWNERSHIP_CONFIRM_REASON = "KEYSTONE_ROTATION_OWNERSHIP_CONFIRM"

local function notify(owner, reason)
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

local function readUnitGUID(unit)
	if not UnitGUID then
		return nil
	end
	local ok, guid = pcall(UnitGUID, unit)
	return ok and readableString(guid) or nil
end

local function getGroupSignature()
	local units = { "player" }
	local count = GetNumGroupMembers and GetNumGroupMembers() or 0
	if not canAccessValue(count) then
		return nil
	end
	count = tonumber(count) or 0
	if IsInRaid and IsInRaid() then
		units = {}
		for index = 1, count do
			units[#units + 1] = "raid" .. index
		end
	else
		for index = 1, math.max(0, count - 1) do
			units[#units + 1] = "party" .. index
		end
	end
	local guids = {}
	for _, unit in ipairs(units) do
		local guid = readUnitGUID(unit)
		if not guid then
			return nil
		end
		guids[#guids + 1] = guid
	end
	table.sort(guids)
	return table.concat(guids, "|")
end

local function getActiveKeystoneLevel()
	if not (C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo) then
		return nil
	end
	local ok, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
	return ok and positiveNumber(level) or nil
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

local function cancelOwnershipTimer(owner)
	local timer = owner.ownershipTimer
	owner.ownershipTimer = nil
	if timer and type(timer.Cancel) == "function" then
		pcall(timer.Cancel, timer)
	end
end

local function nextToken(owner)
	owner.presentationSerial = (tonumber(owner.presentationSerial) or 0) + 1
	return owner.presentationSerial
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
	}
end

function Service:GetSessionSnapshot()
	local source = self.session
	if type(source) ~= "table" then
		return nil
	end
	return {
		challengeModeID = source.challengeModeID,
		runLevel = source.runLevel,
		ownedChallengeModeID = source.ownedChallengeModeID,
		ownedLevel = source.ownedLevel,
		ownedDungeonName = source.ownedDungeonName,
		ownedKeystoneLink = source.ownedKeystoneLink,
		starterEvidence = source.starterEvidence,
		armed = source.armed == true,
		groupSignature = source.groupSignature,
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
	local cache = GF.MythicPlusKeystoneCache
	local snapshot = cache and cache.GetSnapshot and cache:GetSnapshot() or nil
	local ownedDungeonName
	if snapshot and canAccessValue(snapshot) and type(snapshot) == "table" then
		ownedDungeonName = readableString(snapshot.dungeonName)
	end
	self.presentation = {
		token = nextToken(self),
		kind = "preview",
		runLevel = 12,
		ownedLevel = 10,
		ownedDungeonName = ownedDungeonName,
	}
	notify(self, "preview")
	return true
end

function Service:Clear(reason, clearPresentation)
	cancelOwnershipTimer(self)
	self.session = nil
	if clearPresentation == true then
		self.presentation = nil
	end
	notify(self, reason or "clear")
end

function Service:BeginSession(challengeModeID)
	self:Clear("challenge-start-clear", true)
	local cache = GF.MythicPlusKeystoneCache
	local snapshot = cache and cache.GetSnapshot and cache:GetSnapshot() or nil
	local ownedMapID = snapshot and positiveNumber(snapshot.challengeModeID)
	local ownedLevel = snapshot and positiveNumber(snapshot.level)
	local ownedDungeonName = snapshot and readableString(snapshot.dungeonName)
	local ownedLink = snapshot and readableString(snapshot.keystoneLink)
	local runMapID = positiveNumber(challengeModeID)
	local runLevel = getActiveKeystoneLevel()
	local groupSignature = getGroupSignature()
	if not (snapshot and snapshot.state == "ready"
		and ownedMapID and ownedLevel and ownedLink
		and runMapID and runLevel and groupSignature)
	then
		return false
	end

	self.sessionSerial = (tonumber(self.sessionSerial) or 0) + 1
	local serial = self.sessionSerial
	self.session = {
		serial = serial,
		challengeModeID = runMapID,
		runLevel = runLevel,
		ownedChallengeModeID = ownedMapID,
		ownedLevel = ownedLevel,
		ownedDungeonName = ownedDungeonName,
		ownedKeystoneLink = ownedLink,
		starterEvidence = "waiting",
		armed = false,
		groupSignature = groupSignature,
	}
	if C_Timer and C_Timer.NewTimer then
		self.ownershipTimer = C_Timer.NewTimer(
			OWNERSHIP_CONFIRM_TIMEOUT,
			function()
				if Service.session and Service.session.serial == serial
					and Service.session.starterEvidence == "waiting"
				then
					Service:Clear("ownership-timeout", false)
				end
			end)
	end
	notify(self, "challenge-start")
	return true
end

function Service:OnKeystoneSnapshot(_, reason)
	local session = self.session
	if not session or session.starterEvidence ~= "waiting" then
		return
	end
	local cache = GF.MythicPlusKeystoneCache
	local snapshot = cache and cache.GetSnapshot and cache:GetSnapshot() or nil
	if not snapshot or not canAccessValue(snapshot) or type(snapshot) ~= "table" then
		self:Clear("ownership-unreadable", false)
		return
	end
	if snapshot.state == "pending" then
		return
	end
	if snapshot.state ~= "ready" then
		self:Clear("ownership-not-owned", false)
		return
	end
	local sameKey = positiveNumber(snapshot.challengeModeID)
		== session.ownedChallengeModeID
		and positiveNumber(snapshot.level) == session.ownedLevel
		and readableString(snapshot.keystoneLink)
			== session.ownedKeystoneLink
	if not sameKey then
		self:Clear("ownership-changed", false)
		return
	end
	local snapshotReason = reason or snapshot.reason
	if snapshotReason == "CHALLENGE_MODE_START" then
		if not (cache and cache.RequestRefresh) then
			self:Clear("ownership-confirm-unavailable", false)
			return
		end
		session.confirmationRequested = true
		cache:RequestRefresh(
			OWNERSHIP_CONFIRM_REASON,
			OWNERSHIP_CONFIRM_DELAY)
		notify(self, "ownership-confirm-pending")
		return
	end
	if not session.confirmationRequested
		or snapshotReason ~= OWNERSHIP_CONFIRM_REASON
	then
		return
	end
	cancelOwnershipTimer(self)
	session.starterEvidence = "other"
	session.armed = true
	notify(self, "ownership-confirmed-other")
end

function Service:CompleteSession()
	local session = self.session
	cancelOwnershipTimer(self)
	if not session or not session.armed
		or session.starterEvidence ~= "other"
		or not self:IsEnabled()
	then
		self.session = nil
		return false
	end
	local info = getCompletionInfo()
	local practiceRun, practiceReadable = getAccessibleField(
		info, "practiceRun")
	local completedMapID, mapReadable = getAccessibleField(
		info, "mapChallengeModeID")
	local completedLevel, levelReadable = getAccessibleField(info, "level")
	completedMapID = positiveNumber(completedMapID)
	completedLevel = positiveNumber(completedLevel)
	if not info or not practiceReadable or not mapReadable
		or not levelReadable or not completedMapID or not completedLevel
	then
		session.completionObserved = true
		return false
	end
	self.session = nil
	if practiceRun ~= false
		or completedMapID ~= session.challengeModeID
		or completedLevel ~= session.runLevel
		or session.runLevel < session.ownedLevel
	then
		return false
	end
	self.presentation = {
		token = nextToken(self),
		kind = "actual",
		runLevel = session.runLevel,
		ownedLevel = session.ownedLevel,
		ownedDungeonName = session.ownedDungeonName,
	}
	notify(self, "completed")
	return true
end

function Service:HandleEvent(event, ...)
	if event == "CHALLENGE_MODE_START" then
		return self:BeginSession(...)
	elseif event == "CHALLENGE_MODE_COMPLETED" then
		return self:CompleteSession()
	elseif event == "CHALLENGE_MODE_COMPLETED_REWARDS" then
		return self:CompleteSession()
	elseif event == "GROUP_ROSTER_UPDATE" then
		if self.session and not self.session.completionObserved then
			local signature = getGroupSignature()
			if not signature or signature ~= self.session.groupSignature then
				self:Clear("group-changed", false)
			end
		end
	elseif event == "CHALLENGE_MODE_RESET"
		or event == "PLAYER_ENTERING_WORLD"
	then
		self:Clear(event, true)
	end
	return false
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	getMythicPlusSettings()
	local cache = GF.MythicPlusKeystoneCache
	if cache and cache.AddListener then
		cache:AddListener(function(owner, reason)
			Service:OnKeystoneSnapshot(owner, reason)
		end)
	end
end
