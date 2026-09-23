local _, GF = ...

GF.MythicPlusGroupReadyTeleportService =
	GF.MythicPlusGroupReadyTeleportService or {}
local Service = GF.MythicPlusGroupReadyTeleportService

local PROMPT_ACTIVE_SECONDS = 45
local LISTING_RETIRE_GRACE_SECONDS = 1
local GROUP_SWITCH_GRACE_SECONDS = 1
local ACCEPTED_GROUP_SWITCH_GRACE_SECONDS = 10
local APPLICATION_TARGET_LIMIT = 64
local JOINED_GROUP_CAPTURE_RETRY_DELAYS = { 0.10, 0.30, 0.80 }

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return not ok or secret == true
end

local function safeNumber(value)
	if type(value) == "nil" or isSecret(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or type(number) ~= "number" or isSecret(number)
		or number ~= math.floor(number) or number <= 0
	then
		return nil
	end
	return number
end

local function safeString(value)
	if type(value) == "nil" or isSecret(value) then
		return nil
	end
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function readField(owner, key)
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ReadField) == "function" then
		local value, state = snapshot.ReadField(owner, key)
		return state == "value" and value or nil
	end
	if type(owner) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	return ok and not isSecret(value) and value or nil
end

local function getMythicPlusDB()
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
	local schema = GF.SettingsSchema
	if schema and type(schema.NormalizeTeleportPromptSettings) == "function" then
		schema:NormalizeTeleportPromptSettings(mythicPlus.settings)
	else
		if mythicPlus.settings.groupReadyTeleportEnabled == nil then
			mythicPlus.settings.groupReadyTeleportEnabled = true
		else
			mythicPlus.settings.groupReadyTeleportEnabled =
				mythicPlus.settings.groupReadyTeleportEnabled == true
		end
		if mythicPlus.settings.teleportFollowEnabled == nil then
			mythicPlus.settings.teleportFollowEnabled = false
		else
			mythicPlus.settings.teleportFollowEnabled =
				mythicPlus.settings.teleportFollowEnabled == true
		end
	end
	return mythicPlus
end

local function getHomeGroupCount()
	if type(GetNumGroupMembers) ~= "function" then
		return 0
	end
	local ok, count
	if LE_PARTY_CATEGORY_HOME ~= nil then
		ok, count = pcall(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME)
	else
		ok, count = pcall(GetNumGroupMembers)
	end
	return ok and math.max(0, math.floor(tonumber(count) or 0)) or 0
end

local function isHomeRaid()
	if type(IsInRaid) ~= "function" then
		return false
	end
	local ok, inRaid
	if LE_PARTY_CATEGORY_HOME ~= nil then
		ok, inRaid = pcall(IsInRaid, LE_PARTY_CATEGORY_HOME)
	else
		ok, inRaid = pcall(IsInRaid)
	end
	return ok and inRaid == true
end

local function isHomePartyFull()
	if isHomeRaid() then
		return false
	end
	local required = (tonumber(MAX_PARTY_MEMBERS) or 4) + 1
	return getHomeGroupCount() >= required
end

local function isInCombat()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, locked = pcall(InCombatLockdown)
	return not ok or locked == true
end

local function hasActiveChallenge()
	local challenge = C_ChallengeMode
	if not (challenge
		and type(challenge.GetActiveChallengeMapID) == "function")
	then
		return false
	end
	local ok, mapID = pcall(challenge.GetActiveChallengeMapID)
	return ok and safeNumber(mapID) ~= nil
end

local function getResultTargetIdentity(resultID)
	resultID = safeNumber(resultID)
	if not resultID then
		return nil
	end
	local application = GF.ApplicationService
	local info = application
		and type(application.GetAuthoritativeResultInfo) == "function"
		and application:GetAuthoritativeResultInfo(resultID) or nil
	local snapshot = GF.SearchResultSnapshot
	local partyGUID = safeString(readField(info, "partyGUID"))
	if snapshot and type(snapshot.GetPrimaryActivityID) == "function" then
		return safeNumber(snapshot.GetPrimaryActivityID(info)), partyGUID
	end
	return safeNumber(readField(info, "activityID")), partyGUID
end

local function getActivityInfo(activityID)
	activityID = safeNumber(activityID)
	if not activityID then
		return nil
	end
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.GetActivityInfo) == "function" then
		return snapshot.GetActivityInfo(nil, activityID)
	end
	local getter = C_LFGList and C_LFGList.GetActivityInfoTable
	if type(getter) ~= "function" then
		return nil
	end
	local ok, info = pcall(getter, activityID)
	return ok and type(info) == "table" and info or nil
end

local function resolveActivityTarget(activityID, source, resultID)
	activityID = safeNumber(activityID)
	local activity = getActivityInfo(activityID)
	if not activity
		or safeNumber(readField(activity, "categoryID")) ~= GF.CAT_DUNGEON
		or readField(activity, "isMythicPlusActivity") ~= true
	then
		return nil
	end
	local season = GF.MythicPlusSeason
	local dungeon = season and type(season.GetByActivityID) == "function"
		and season:GetByActivityID(activityID) or nil
	local challengeModeID = safeNumber(dungeon and dungeon.challengeModeID)
	local dungeonName = safeString(dungeon and dungeon.name)
	if not (challengeModeID and dungeonName) then
		return nil
	end
	return {
		activityID = activityID,
		challengeModeID = challengeModeID,
		mapID = safeNumber(dungeon.mapID),
		dungeonName = dungeonName,
		source = source,
		resultID = safeNumber(resultID),
	}
end

local function targetMatches(left, right)
	return left and right
		and left.activityID == right.activityID
		and left.challengeModeID == right.challengeModeID
end

local function normalizePreviewID(value)
	if value == nil then
		return nil, true
	end
	if type(value) == "string" then
		value = value:match("^%s*(.-)%s*$") or ""
		if value == "" then
			return nil, true
		end
	end
	local previewID = safeNumber(value)
	return previewID, previewID ~= nil
end

local function findPreviewDungeon(dungeons, previewID)
	for _, dungeon in ipairs(dungeons or {}) do
		if tonumber(dungeon.challengeModeID) == previewID
			or tonumber(dungeon.mapID) == previewID
		then
			return dungeon
		end
	end
	return nil
end

function Service:BuildPreviewSnapshot(requestedID)
	local previewID, valid = normalizePreviewID(requestedID)
	if not valid then
		return nil, "invalid-id"
	end

	local teleport = GF.MythicPlusTeleportService
	local season = GF.MythicPlusSeason
	local dungeons = season and type(season.GetDungeons) == "function"
		and season:GetDungeons() or {}
	local entry
	local dungeon
	if previewID then
		entry = teleport and type(teleport.GetByMapID) == "function"
			and teleport:GetByMapID(previewID) or nil
		dungeon = entry and entry.dungeon
			or findPreviewDungeon(dungeons, previewID)
		if not dungeon and season
			and type(season.GetByChallengeModeID) == "function"
		then
			dungeon = season:GetByChallengeModeID(previewID)
		end
		dungeon = dungeon or {
			challengeModeID = previewID,
			mapID = previewID,
			name = tostring(previewID),
		}
	else
		for _, candidate in ipairs(teleport and teleport.entries or {}) do
			if type(candidate.dungeon) == "table" then
				entry = candidate
				dungeon = candidate.dungeon
				break
			end
		end
		dungeon = dungeon or dungeons[1]
	end
	local dungeonName = safeString(dungeon and dungeon.name)
	if not dungeonName then
		return nil, "no-data"
	end

	local challengeModeID = safeNumber(dungeon.challengeModeID)
		or safeNumber(entry and entry.challengeModeID)
		or previewID
	local mapID = safeNumber(dungeon.mapID)
		or safeNumber(entry and entry.mapID)
		or challengeModeID
	if not challengeModeID then
		return nil, "no-data"
	end
	return {
		challengeModeID = challengeModeID,
		mapID = mapID,
		dungeon = dungeon,
		dungeonName = dungeonName,
	}, nil
end

function Service:RequestPreview(requestedID)
	local snapshot, reason = self:BuildPreviewSnapshot(requestedID)
	if not snapshot then
		return false, reason
	end
	if isInCombat() then
		return false, "combat", snapshot
	end
	local dialog = GF.MythicPlusTeleportDialog
	if not (dialog and type(dialog.ShowGroupReadyPreview) == "function") then
		return false, "unavailable", snapshot
	end
	local ok, opened, openReason = pcall(
		dialog.ShowGroupReadyPreview, dialog, snapshot)
	if not ok or opened ~= true then
		return false, openReason or "unavailable", snapshot
	end
	return true, nil, snapshot
end

function Service:IsEnabled()
	local mythicPlus = getMythicPlusDB()
	return mythicPlus ~= nil
		and mythicPlus.settings.groupReadyTeleportEnabled == true
end

function Service:SetEnabled(enabled)
	local mythicPlus = getMythicPlusDB()
	if not mythicPlus then
		return false
	end
	enabled = enabled == true
	mythicPlus.settings.groupReadyTeleportEnabled = enabled
	-- Toggling the setting must never reinterpret an already-full party as a
	-- fresh fill edge. A later drop and refill starts the next eligible epoch.
	self.wasFull = isHomePartyFull()
	if not enabled then
		self:HidePrompt("setting-disabled")
	end
	return enabled
end

function Service:CaptureApplication(resultID)
	resultID = safeNumber(resultID)
	if not resultID then
		return nil
	end
	local activityID, partyGUID = getResultTargetIdentity(resultID)
	local target = resolveActivityTarget(activityID, "application", resultID)
	if not target then
		return nil
	end
	target.partyGUID = partyGUID
	self.applicationTargets = self.applicationTargets or {}
	self.applicationTargetOrder = self.applicationTargetOrder or {}
	if not self.applicationTargets[resultID] then
		self.applicationTargetOrder[#self.applicationTargetOrder + 1] = resultID
	end
	self.applicationTargets[resultID] = target
	while #self.applicationTargetOrder > APPLICATION_TARGET_LIMIT do
		local expiredID = table.remove(self.applicationTargetOrder, 1)
		if expiredID ~= resultID then
			self.applicationTargets[expiredID] = nil
		end
	end
	return target
end

function Service:OnApplicationSubmitted(resultID)
	return self:CaptureApplication(resultID) ~= nil
end

function Service:GetApplicationTarget(resultID)
	resultID = safeNumber(resultID)
	local target = resultID and self.applicationTargets
		and self.applicationTargets[resultID] or nil
	return target or self:CaptureApplication(resultID)
end

function Service:InvalidateJoinedGroupCapture()
	self.joinedGroupCaptureTicket =
		(tonumber(self.joinedGroupCaptureTicket) or 0) + 1
	self.joinedGroupCaptureResultID = nil
	return self.joinedGroupCaptureTicket
end

function Service:ClearPendingAcceptedApplication(resultID)
	resultID = safeNumber(resultID)
	if not resultID
		or self.pendingAcceptedApplicationResultID == resultID
	then
		self.pendingAcceptedApplicationResultID = nil
	end
end

function Service:CancelGroupSwitchGrace()
	self.groupSwitchTicket = (tonumber(self.groupSwitchTicket) or 0) + 1
	self.groupSwitchPending = false
	self.groupSwitchTarget = nil
end

function Service:BeginGroupSwitchGrace(departingPartyGUID)
	local target = self.pendingApplicationTarget
		or self.groupSwitchTarget
	if not target and self.target and self.target.source == "application" then
		target = self.target
	end
	local hasApplicationEvidence = target ~= nil
		or self.joinedGroupCaptureResultID ~= nil
		or self.pendingAcceptedApplicationResultID ~= nil
		or (type(self.applicationTargets) == "table"
			and next(self.applicationTargets) ~= nil)
	if not hasApplicationEvidence
		or not (C_Timer and type(C_Timer.After) == "function")
	then
		return false
	end

	self:HidePrompt("group-left")
	self.groupSwitchTicket = (tonumber(self.groupSwitchTicket) or 0) + 1
	local ticket = self.groupSwitchTicket
	self.groupSwitchPending = true
	self.groupSwitchTarget = target
	self.target = nil
	self.pendingApplicationTarget = nil
	self.generation = (tonumber(self.generation) or 0) + 1
	self.epoch = 0
	self.promptedEpoch = nil
	self.wasFull = isHomePartyFull()

	-- Only a confirmed acceptance into a different, identified HOME party can
	-- outlive the ordinary leave grace. The result can retire when the merged
	-- group fills; retain its frozen identity until GROUP_JOINED confirms it.
	local grace = GROUP_SWITCH_GRACE_SECONDS
	if target and target.partyGUID and departingPartyGUID
		and target.partyGUID ~= departingPartyGUID
		and (self.pendingAcceptedApplicationResultID == target.resultID
			or self.joinedGroupCaptureResultID == target.resultID)
	then
		grace = ACCEPTED_GROUP_SWITCH_GRACE_SECONDS
	end
	C_Timer.After(grace, function()
		if Service.groupSwitchTicket ~= ticket
			or Service.groupSwitchPending ~= true
		then
			return
		end
		Service:CancelGroupSwitchGrace()
		Service.applicationTargets = {}
		Service.applicationTargetOrder = {}
		Service:ClearPendingAcceptedApplication()
		Service:InvalidateJoinedGroupCapture()
		Service:ClearTarget("group-left")
	end)
	return true
end

function Service:CanActivateApplicationTarget(target)
	return target ~= nil
		and (not target.partyGUID or target.partyGUID == self.partyGUID)
end

function Service:TryActivateJoinedGroupTarget(resultID, ticket, reason)
	if ticket ~= self.joinedGroupCaptureTicket then
		return false
	end
	local target = self:GetApplicationTarget(resultID)
	local pending = self.pendingApplicationTarget
	if not target and pending
		and safeNumber(pending.resultID) == resultID
	then
		target = pending
	end
	if not target then
		return false
	end
	self.pendingApplicationTarget = target
	if not self:CanActivateApplicationTarget(target) then
		return false
	end
	self.pendingApplicationTarget = nil
	self:ClearPendingAcceptedApplication(resultID)
	self:InvalidateJoinedGroupCapture()
	self:ActivateTarget(target, "application", true)
	self.lastJoinedGroupCaptureReason = reason
	return true
end

function Service:TryActivateAcceptedApplicationTarget(reason)
	local resultID = safeNumber(self.pendingAcceptedApplicationResultID)
	if not resultID then
		return false
	end
	local target = self:GetApplicationTarget(resultID)
	if not target then
		return false
	end
	self.pendingApplicationTarget = target
	if not self:CanActivateApplicationTarget(target) then
		return false
	end
	self.pendingApplicationTarget = nil
	self:ClearPendingAcceptedApplication(resultID)
	self:ActivateTarget(target, "application", true)
	self.lastAcceptedApplicationCaptureReason = reason
	return true
end

function Service:RecoverPendingExactApplicationTarget(reason)
	-- A GROUP_LEFT can precede the replacement HOME GROUP_JOINED. Do not let a
	-- delayed readable result revive a target while that switch has not yet
	-- converged to a concrete new HOME party generation.
	if self.groupSwitchPending == true and self.partyGUID == nil then
		return false
	end
	if self:TryActivateAcceptedApplicationTarget(reason) then
		return true
	end
	local resultID = self.joinedGroupCaptureResultID
	if not resultID then
		return false
	end
	return self:TryActivateJoinedGroupTarget(
		resultID, self.joinedGroupCaptureTicket, reason)
end

function Service:CaptureJoinedGroupTarget(resultID)
	resultID = safeNumber(resultID)
	local ticket = self:InvalidateJoinedGroupCapture()
	if not resultID then
		return false
	end
	self.joinedGroupCaptureResultID = resultID
	if self:TryActivateJoinedGroupTarget(
		resultID, ticket, "joined-group")
	then
		return true
	end
	-- GetSearchResultInfo is documented MayReturnNothing. Blizzard supplies the
	-- exact result ID to non-empowered followers through LFG_LIST_JOINED_GROUP,
	-- so retry only that identity for a short, tokenized window.
	if not (C_Timer and type(C_Timer.After) == "function") then
		return false
	end
	for _, delay in ipairs(JOINED_GROUP_CAPTURE_RETRY_DELAYS) do
		C_Timer.After(delay, function()
			Service:TryActivateJoinedGroupTarget(
				resultID, ticket, "joined-group-retry")
		end)
	end
	return false
end

function Service:OnLfgListAvailabilityUpdated()
	-- GetSearchResultInfo is MayReturnNothing and is protected during chat
	-- messaging lockdown. The official availability edge is a wake signal only:
	-- recover the same exact accepted/joined result ID, never enumerate or guess
	-- another application.
	return self:RecoverPendingExactApplicationTarget("availability-updated")
end

function Service:OnSearchResultUpdated(resultID)
	resultID = safeNumber(resultID)
	if not resultID
		or (resultID ~= safeNumber(self.pendingAcceptedApplicationResultID)
		and resultID ~= safeNumber(self.joinedGroupCaptureResultID)
		)
	then
		return false
	end
	return self:RecoverPendingExactApplicationTarget("search-result-updated")
end

function Service:ActivateTarget(target, source, allowAlreadyFull)
	if not target then
		return false
	end
	if self.groupSwitchPending == true then
		self:CancelGroupSwitchGrace()
	end
	if targetMatches(self.target, target) then
		self.target.source = source or self.target.source
		self.target.resultID = target.resultID or self.target.resultID
		return self:Evaluate("target-refresh")
	end
	self:HidePrompt("target-changed")
	self.generation = (tonumber(self.generation) or 0) + 1
	self.epoch = 0
	self.promptedEpoch = nil
	self.target = target
	self.target.source = source or target.source
	local full = isHomePartyFull()
	if allowAlreadyFull == true then
		self.wasFull = false
	else
		self.wasFull = full
	end
	return self:Evaluate("target-activated")
end

function Service:ClearTarget(reason)
	self:HidePrompt(reason or "target-cleared")
	self.target = nil
	self.pendingApplicationTarget = nil
	self.generation = (tonumber(self.generation) or 0) + 1
	self.epoch = 0
	self.promptedEpoch = nil
	self.wasFull = isHomePartyFull()
end

function Service:HidePrompt(reason)
	local dialog = GF.MythicPlusTeleportDialog
	if dialog and type(dialog.HideGroupReady) == "function" then
		dialog:HideGroupReady(reason or "hidden", self.activePromptToken)
	end
	self.activePromptToken = nil
end

function Service:CanPrompt(target)
	if not self:IsEnabled() then
		return false, "disabled"
	end
	if isInCombat() then
		return false, "combat"
	end
	if hasActiveChallenge() then
		return false, "challenge-active"
	end
	local teleport = GF.MythicPlusTeleportService
	if not (teleport and type(teleport.GetStatus) == "function") then
		return false, "teleport-unavailable"
	end
	if type(teleport.Refresh) == "function" then
		local refreshed = pcall(teleport.Refresh, teleport, "group-ready-edge")
		if not refreshed then
			return false, "teleport-unavailable"
		end
	end
	local status = teleport:GetStatus(target.challengeModeID)
	if status ~= "ready" then
		return false, status or "teleport-unavailable"
	end
	return true
end

function Service:Evaluate(reason)
	local full = isHomePartyFull()
	if not self.target then
		self.wasFull = full
		return false
	end
	if not full then
		if self.wasFull == true then
			self:HidePrompt("group-no-longer-full")
		end
		self.wasFull = false
		return false
	end
	if self.wasFull == true then
		return false
	end
	self.wasFull = true
	self.epoch = (tonumber(self.epoch) or 0) + 1
	self.promptedEpoch = self.epoch
	local allowed = self:CanPrompt(self.target)
	if not allowed then
		return false
	end
	local dialog = GF.MythicPlusTeleportDialog
	if not (dialog and type(dialog.ShowGroupReady) == "function") then
		return false
	end
	local token = table.concat({
		tostring(self.generation or 0),
		tostring(self.epoch),
		tostring(self.target.challengeModeID),
	}, ":")
	local shown = dialog:ShowGroupReady({
		activityID = self.target.activityID,
		challengeModeID = self.target.challengeModeID,
		mapID = self.target.mapID,
		dungeonName = self.target.dungeonName,
		token = token,
		timeoutSeconds = PROMPT_ACTIVE_SECONDS,
		reason = reason,
	})
	if shown then
		self.activePromptToken = token
	end
	return shown == true
end

function Service:OnRosterChanged()
	if self:RecoverPendingExactApplicationTarget("roster-changed") then
		return
	end
	if not self.target
		and self:CanActivateApplicationTarget(self.pendingApplicationTarget)
	then
		self:ActivateTarget(
			self.pendingApplicationTarget, "application", true)
		self.pendingApplicationTarget = nil
		return
	end
	self:Evaluate("roster-changed")
end

function Service:OnApplicationStatusUpdated(resultID, status)
	resultID = safeNumber(resultID)
	status = type(status) == "string" and status or ""
	local target = self:GetApplicationTarget(resultID)
	if status == "inviteaccepted" then
		-- Preserve Blizzard's exact accepted result ID even when its structural
		-- search data is temporarily unreadable. Availability/roster edges will
		-- retry this same ID only; "applied" and "invited" never authorize it.
		self.pendingAcceptedApplicationResultID = resultID
		if target then
			self.pendingApplicationTarget = target
		end
		return self:RecoverPendingExactApplicationTarget("inviteaccepted")
	end
	if status ~= "applied" and status ~= "invited" then
		if self.applicationTargets and resultID then
			self.applicationTargets[resultID] = nil
		end
	end
end

function Service:OnJoinedGroup(resultID)
	return self:CaptureJoinedGroupTarget(resultID)
end

function Service:OnGroupJoined(category, partyGUID)
	if category ~= nil
		and category ~= (LE_PARTY_CATEGORY_HOME or 1)
	then
		return
	end
	local groupSwitchTarget = self.groupSwitchTarget
	partyGUID = safeString(partyGUID)
	if partyGUID and self.partyGUID and partyGUID ~= self.partyGUID then
		local incomingTarget = self.pendingApplicationTarget
		if not incomingTarget
			and self.target and self.target.source == "application"
		then
			incomingTarget = self.target
		end
		self:ClearTarget("group-changed")
		self.pendingApplicationTarget = incomingTarget
	end
	self.partyGUID = partyGUID or self.partyGUID
	local incomingTarget = self.pendingApplicationTarget or groupSwitchTarget
	if incomingTarget and incomingTarget.partyGUID and self.partyGUID
		and incomingTarget.partyGUID ~= self.partyGUID
	then
		-- A concrete unrelated HOME party cannot inherit the accepted dungeon.
		self:CancelGroupSwitchGrace()
		self:ClearPendingAcceptedApplication()
		self:InvalidateJoinedGroupCapture()
		self:ClearTarget("application-party-mismatch")
		return false
	end
	if incomingTarget and not self:CanActivateApplicationTarget(incomingTarget) then
		return false
	end
	if self:RecoverPendingExactApplicationTarget("group-joined") then
		return true
	end
	if self.pendingApplicationTarget or groupSwitchTarget then
		local target = self.pendingApplicationTarget or groupSwitchTarget
		self.pendingApplicationTarget = nil
		self:InvalidateJoinedGroupCapture()
		self:ActivateTarget(target, "application", true)
	elseif self.groupSwitchPending == true
		and (self.joinedGroupCaptureResultID ~= nil
			or self.pendingAcceptedApplicationResultID ~= nil)
	then
		-- The replacement HOME party is now concrete. Its exact joined/accepted
		-- ID remains eligible for an availability wake-up; the old one-second
		-- switch cleanup must not erase it first.
		self:CancelGroupSwitchGrace()
		self.wasFull = isHomePartyFull()
	elseif self.target then
		self:Evaluate("group-joined")
	else
		self.wasFull = isHomePartyFull()
	end
end

function Service:OnGroupLeft(category, partyGUID)
	if category ~= nil
		and category ~= (LE_PARTY_CATEGORY_HOME or 1)
	then
		return false
	end
	partyGUID = safeString(partyGUID)
	if partyGUID and self.partyGUID and partyGUID ~= self.partyGUID then
		-- A premade can publish GROUP_JOINED for the replacement HOME party
		-- before GROUP_LEFT for the retired party. That late old-generation
		-- leave must not suspend or erase the already accepted exact target.
		return false
	end
	local departingPartyGUID = partyGUID or self.partyGUID
	self.partyGUID = nil
	if self:BeginGroupSwitchGrace(departingPartyGUID) then
		return true
	end
	self:CancelGroupSwitchGrace()
	self.applicationTargets = {}
	self.applicationTargetOrder = {}
	self:ClearPendingAcceptedApplication()
	self:InvalidateJoinedGroupCapture()
	self:ClearTarget("group-left")
	return true
end

function Service:GetActiveListingTarget()
	local session = GF.RecruitmentSession
	local activityID = session
		and type(session.GetActiveActivityID) == "function"
		and session:GetActiveActivityID() or nil
	return resolveActivityTarget(activityID, "listing")
end

function Service:OnListingCreated(activityID)
	local target = resolveActivityTarget(activityID, "listing")
	if not target then
		return false
	end
	self:ActivateTarget(target, "listing", false)
	return true
end

function Service:RetireListingTargetAfterGrace()
	if not (self.target and self.target.source == "listing") then
		return
	end
	self.listingRetireTicket = (tonumber(self.listingRetireTicket) or 0) + 1
	local ticket = self.listingRetireTicket
	local function retire()
		if Service.listingRetireTicket ~= ticket
			or not (Service.target and Service.target.source == "listing")
		then
			return
		end
		if isHomePartyFull() then
			Service:Evaluate("listing-closed-at-full")
		else
			Service:ClearTarget("listing-closed")
		end
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(LISTING_RETIRE_GRACE_SECONDS, retire)
	else
		retire()
	end
end

function Service:OnActiveEntryUpdated(hasActive, baseline)
	if hasActive == true then
		self.listingRetireTicket = (tonumber(self.listingRetireTicket) or 0) + 1
		local target = self:GetActiveListingTarget()
		if target then
			if baseline == true then
				self:ActivateTarget(target, "listing", false)
				self.wasFull = isHomePartyFull()
				return true
			end
			return self:ActivateTarget(target, "listing", false)
		end
		if self.target and self.target.source == "listing" then
			self:ClearTarget("listing-target-invalid")
		end
		return false
	end
	self:RetireListingTargetAfterGrace()
	return false
end

function Service:OnChallengeModeStart()
	self:CancelGroupSwitchGrace()
	self:ClearPendingAcceptedApplication()
	self:InvalidateJoinedGroupCapture()
	self:ClearTarget("challenge-started")
end

function Service:OnPlayerEnteringWorld()
	self:HidePrompt("player-entering-world")
	self.wasFull = isHomePartyFull()
end

function Service:OnFollowTakeover()
	-- The full-party epoch remains consumed. The follow dialog now owns the
	-- shared secure panel and this prompt must not be restored afterward.
	self.activePromptToken = nil
end

function Service:OnDialogHidden(_, token)
	if token == nil or token == self.activePromptToken then
		self.activePromptToken = nil
	end
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.applicationTargets = {}
	self.applicationTargetOrder = {}
	self.joinedGroupCaptureTicket = 0
	self.joinedGroupCaptureResultID = nil
	self.pendingAcceptedApplicationResultID = nil
	self.groupSwitchTicket = 0
	self.groupSwitchPending = false
	self.groupSwitchTarget = nil
	self.generation = 0
	self.epoch = 0
	self.wasFull = isHomePartyFull()
	getMythicPlusDB()
	local session = GF.RecruitmentSession
	if session and type(session.HasActive) == "function"
		and session:HasActive()
	then
		self:OnActiveEntryUpdated(true, true)
	end
end
