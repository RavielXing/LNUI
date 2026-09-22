local _, GF = ...

local Session = {}
GF.RecruitmentSession = Session
local NativeCreation = assert(
	GF.NativeCreationGateway,
	"NativeCreationGateway must load before RecruitmentSession"
)

Session.AUTO_ACCEPT_CONTROL_MODE_NATIVE_QUEST = "native_quest_auto_accept"
Session.AUTO_INVITE_OWNER_NATIVE = "native"
Session.AUTO_INVITE_OWNER_PLUGIN = "plugin"
Session.AUTO_INVITE_OWNER_UNKNOWN = "unknown"
Session.ACTIVE_CENSOR_STATE_NORMAL = "normal"
Session.ACTIVE_CENSOR_STATE_UNRESOLVED = "unresolved"
Session.ACTIVE_CENSOR_STATE_UNKNOWN = "unknown"
Session.ACTIVE_CENSOR_STATE_INACTIVE = "inactive"

local function canAccessValue(value)
	-- Retail secret-value helpers require a non-nil argument. Nil remains the
	-- ordinary representation for optional active-entry fields.
	if type(value) == "nil" then
		return true
	end
	if type(canaccessvalue) == "function" then
		local accessOK, accessible = pcall(canaccessvalue, value)
		if not accessOK or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local secretOK, secret = pcall(issecretvalue, value)
		if not secretOK or secret == true then
			return false
		end
	end
	return true
end

local function readAccessibleField(owner, key)
	if type(owner) ~= "table" then
		return nil, false
	end
	if type(issecretvaluekey) == "function" then
		local secretOK, secret = pcall(issecretvaluekey, owner, key)
		if not secretOK or secret == true then
			return nil, false
		end
	end
	local fieldOK, value = pcall(function()
		return owner[key]
	end)
	if not fieldOK then
		return nil, false
	end
	if type(value) == "nil" then
		return nil, true
	end
	if not canAccessValue(value) then
		return nil, false
	end
	return value, true
end

local function readEntryQuestID(entry)
	local value, readable = readAccessibleField(entry, "questID")
	if not readable then
		return nil, false
	end
	if type(value) == "nil" then
		return nil, true
	end
	local numberOK, questID = pcall(tonumber, value)
	if not numberOK or type(questID) ~= "number" then
		return nil, false
	end
	return questID > 0 and questID or nil, true
end

local function readEntryActivityID(entry)
	local activityIDs, listReadable = readAccessibleField(entry, "activityIDs")
	if not listReadable then
		return nil, false
	end
	local activityID
	if type(activityIDs) == "table" then
		activityID, listReadable = readAccessibleField(activityIDs, 1)
		if not listReadable then
			return nil, false
		end
	elseif type(activityIDs) ~= "nil" then
		return nil, false
	end
	if type(activityID) == "nil" then
		activityID, listReadable = readAccessibleField(entry, "activityID")
		if not listReadable then
			return nil, false
		end
	end
	if type(activityID) == "nil" then
		return nil, false
	end
	local numberOK, normalized = pcall(tonumber, activityID)
	if not numberOK or type(normalized) ~= "number" or normalized <= 0 then
		return nil, false
	end
	return normalized, true
end

local function isCrossFactionEntry(entry)
	if type(entry) ~= "table" then
		return false
	end
	local value = entry.isCrossFactionListing
	if value == nil then
		value = entry.isCrossFaction
	end
	return value == true
end

function Session:CanManageApplicants()
	if self:HasActive() ~= true then
		return false
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local empowered = type(LFGListUtil_IsEntryEmpowered) == "function"
		and LFGListUtil_IsEntryEmpowered() == true
	if empowered then
		return true
	end
	local home = LE_PARTY_CATEGORY_HOME
	local soloOwner = not IsInGroup(home)
	local partyOfficer = UnitIsGroupLeader("player", home)
		or UnitIsGroupAssistant("player", home)
	return soloOwner or partyOfficer
end

function Session:IsNativePublishingAvailable()
	local api = C_LFGList
	return api ~= nil
		and type(api.GetActivityInfoTable) == "function"
		and type(api.CreateListing) == "function"
		and type(api.UpdateListing) == "function"
		and type(api.HasActiveEntryInfo) == "function"
end

local function notifyUiError(message)
	if type(GF.ShowWarningMessage) ~= "function" then
		return
	end
	GF.ShowWarningMessage(message)
end

-- List / edit / remove / bump: party leader only (Blizzard LFGListUtil_CanListGroup / ApplicationViewer).
function Session:CanPublish()
	if type(LFGListUtil_CanListGroup) == "function" then
		return LFGListUtil_CanListGroup() == true
	end
	local home = LE_PARTY_CATEGORY_HOME
	if not IsInGroup(home) then
		return true
	end
	return UnitIsGroupLeader("player", home) == true
end

function Session:GetLeaderOnlyMessage()
	local locale = GF.L or {}
	return locale.ERR_LEADER_ONLY or "You are not authorized"
end

function Session:NotifyLeaderOnly()
	notifyUiError(self:GetLeaderOnlyMessage())
end

local function cloneListingCreateData(createData)
	if type(createData) ~= "table"
		or type(createData.activityIDs) ~= "table"
		or createData.activityIDs[1] == nil
	then
		return nil
	end
	return {
		activityIDs = { createData.activityIDs[1] },
		questID = createData.questID,
		isAutoAccept = createData.isAutoAccept == true,
		isCrossFactionListing = createData.isCrossFactionListing == true,
		isPrivateGroup = createData.isPrivateGroup == true,
		newPlayerFriendly = createData.newPlayerFriendly == true,
		playstyle = createData.playstyle,
		generalPlaystyle = createData.generalPlaystyle,
		requiredDungeonScore = createData.requiredDungeonScore,
		requiredItemLevel = createData.requiredItemLevel,
		requiredPvpRating = createData.requiredPvpRating,
	}
end

local function sameListingCreateData(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	local leftActivities = left.activityIDs
	local rightActivities = right.activityIDs
	if type(leftActivities) ~= "table" or type(rightActivities) ~= "table" then
		return false
	end
	return leftActivities[1] == rightActivities[1]
		and left.questID == right.questID
		and left.isAutoAccept == right.isAutoAccept
		and left.isCrossFactionListing == right.isCrossFactionListing
		and left.isPrivateGroup == right.isPrivateGroup
		and left.newPlayerFriendly == right.newPlayerFriendly
		and left.playstyle == right.playstyle
		and left.generalPlaystyle == right.generalPlaystyle
		and left.requiredDungeonScore == right.requiredDungeonScore
		and left.requiredItemLevel == right.requiredItemLevel
		and left.requiredPvpRating == right.requiredPvpRating
end

function Session:BeginOwnedEntryRequest(createData, safeForRelist, recordRecent)
	self._pendingGroupFinderActiveEntry = true
	self._pendingRecentInstance = nil
	if recordRecent and GF.QuickSearch and GF.QuickSearch.CaptureRecentInstance then
		local activityID = createData and createData.activityIDs and createData.activityIDs[1]
		local record = GF.QuickSearch:CaptureRecentInstance(activityID)
		if record then self._pendingRecentInstance = { activityID = activityID, record = record } end
	end
	self._pendingSafeRelistSubmission = safeForRelist == true
		and cloneListingCreateData(createData) or nil
end

function Session:CancelOwnedEntryRequest()
	self._pendingGroupFinderActiveEntry = nil
	self._pendingRecentInstance = nil
	self._pendingSafeRelistSubmission = nil
end

function Session:SyncEntryOwnership(hasActive)
	if hasActive ~= true then
		local keepPendingRelist = self._pendingGroupFinderActiveEntry == true
			and self:IsRelisting() == true
		local currentOwner = self._activeEntryOwnedByGroupFinder
		if currentOwner ~= nil then
			self._lastActiveEntryOwnedByGroupFinder = currentOwner
		end
		self._activeEntryOwnedByGroupFinder = nil
		self._activeSafeRelistSubmission = nil
		if not keepPendingRelist then
			self._pendingGroupFinderActiveEntry = nil
			self._pendingSafeRelistSubmission = nil
			self._pendingRecentInstance = nil
		end
		return
	end

	if self._pendingGroupFinderActiveEntry == true then
		self._activeEntryOwnedByGroupFinder = true
		self._pendingGroupFinderActiveEntry = nil
		self._activeSafeRelistSubmission = self._pendingSafeRelistSubmission
		self._pendingSafeRelistSubmission = nil
	elseif self._activeEntryOwnedByGroupFinder == nil then
		self._activeEntryOwnedByGroupFinder = false
	end
	local recent = self._pendingRecentInstance
	if recent and self._activeEntryOwnedByGroupFinder == true then
		local activityID = self:GetActiveActivityID()
		-- An accepted request can still fail later. Persist only after the owned
		-- active entry confirms the requested activity, retrying unreadable info.
		if activityID then
			self._pendingRecentInstance = nil
			if activityID == recent.activityID and GF.QuickSearch
				and GF.QuickSearch.RecordRecentInstance then
				GF.QuickSearch:RecordRecentInstance(recent.record)
			end
		end
	end
end

function Session:IsActiveEntryOwned()
	return self._activeEntryOwnedByGroupFinder == true
end

function Session:HasSafeRelistSubmission()
	return self:IsActiveEntryOwned()
		and self._activeSafeRelistSubmission ~= nil
end

function Session:GetSafeRelistSubmission()
	if not self:HasSafeRelistSubmission() then
		return nil
	end
	return cloneListingCreateData(self._activeSafeRelistSubmission)
end

-- Reduce the active listing to the only identity the automatic-invite
-- scheduler may inspect. GroupFinder-owned entries use the untainted request
-- snapshot captured before CreateListing/UpdateListing, including the private
-- bit needed for exact persistence. External or cold-restored entries expose
-- only readable activity/task identity and are deliberately non-persistable;
-- active-entry booleans can be secret in Retail 12.1 and must never be compared.
function Session:GetAutoInviteEntryIdentity()
	if self:HasActive() ~= true then
		return nil
	end
	local safeSubmission = self:GetSafeRelistSubmission()
	if type(safeSubmission) == "table"
		and type(safeSubmission.activityIDs) == "table"
	then
		local activityID = tonumber(safeSubmission.activityIDs[1])
		if activityID ~= nil and activityID > 0 then
			local questID = tonumber(safeSubmission.questID)
			return {
				activityID = activityID,
				questID = questID ~= nil and questID > 0 and questID or nil,
				privateGroup = safeSubmission.isPrivateGroup == true,
				persistable = true,
			}
		end
	end

	local entry = self:GetActive()
	local activityID, activityReadable = readEntryActivityID(entry)
	local questID, questReadable = readEntryQuestID(entry)
	if not activityReadable or not questReadable then
		return nil
	end
	return {
		activityID = activityID,
		questID = questID,
		persistable = false,
	}
end

function Session:WasLastEntryOwned()
	return self._lastActiveEntryOwnedByGroupFinder == true
end

function Session:WasLastEntryExternal()
	return self._lastActiveEntryOwnedByGroupFinder == false
end

function Session:ReadActiveState()
	local api = C_LFGList
	local reader = api and api.HasActiveEntryInfo
	if type(reader) ~= "function" then
		return nil
	end
	local ok, active = pcall(reader)
	if ok and canAccessValue(active) and type(active) == "boolean" then return active end
end

function Session:HasActive()
	return self:ReadActiveState() == true
end

function Session:GetActive()
	if not self:HasActive() then
		return nil
	end
	local api = C_LFGList
	local reader = api and api.GetActiveEntryInfo
	if type(reader) ~= "function" then
		return nil
	end
	local ok, entry = pcall(reader)
	return ok and type(entry) == "table" and entry or nil
end

function Session:GetActiveActivityID()
	local entry = self:GetActive()
	local activityID, readable = readEntryActivityID(entry)
	return readable and activityID or nil
end

function Session:GetActiveEntryName()
	local entry = self:GetActive()
	if type(entry) ~= "table" then
		return ""
	end
	local censorState = self:GetActiveCensoredState()
	if censorState.state == self.ACTIVE_CENSOR_STATE_UNRESOLVED then
		local censoredOK, censored = pcall(function()
			return entry.censored
		end)
		if not censoredOK or not canAccessValue(censored) or censored ~= false then
			local locale = GF.L or {}
			return locale.CENSORED_ACTIVE_ENTRY_HIDDEN_TITLE
				or "Recruitment content pending review"
		end
	elseif censorState.state == self.ACTIVE_CENSOR_STATE_UNKNOWN then
		return ""
	end
	local nameOK, name = pcall(function()
		return entry.name
	end)
	if not nameOK or not canAccessValue(name) then
		return ""
	end
	return name or ""
end

local function readDebugCensoredProjection()
	local debugService = GF.Debug
	if not (debugService and debugService.IsDebugModeEnabled
		and debugService:IsDebugModeEnabled() == true
		and debugService.GetActiveCensoredDemoState)
	then
		return nil
	end
	local state = debugService:GetActiveCensoredDemoState()
	if state == nil or state == "off" then
		return nil
	end
	return {
		state = state == "unknown"
			and Session.ACTIVE_CENSOR_STATE_UNKNOWN
			or Session.ACTIVE_CENSOR_STATE_UNRESOLVED,
		unresolved = state ~= "unknown",
		hidden = state == "hidden",
		revealed = state == "revealed",
		supported = true,
		preview = true,
		hasActive = true,
	}
end

function Session:GetActiveCensoredState()
	if self:HasActive() ~= true then
		return {
			state = self.ACTIVE_CENSOR_STATE_INACTIVE,
			unresolved = false,
			supported = type(C_LFGList.IsCensoredActiveEntryUnresolved) == "function",
			hasActive = false,
		}
	end
	local query = C_LFGList.IsCensoredActiveEntryUnresolved
	if type(query) ~= "function" then
		return {
			state = self.ACTIVE_CENSOR_STATE_NORMAL,
			unresolved = false,
			supported = false,
			hasActive = true,
		}
	end
	local ok, unresolved = pcall(query)
	if not ok or not canAccessValue(unresolved) or type(unresolved) ~= "boolean" then
		return {
			state = self.ACTIVE_CENSOR_STATE_UNKNOWN,
			unresolved = nil,
			supported = true,
			hasActive = true,
		}
	end
	return {
		state = unresolved and self.ACTIVE_CENSOR_STATE_UNRESOLVED
			or self.ACTIVE_CENSOR_STATE_NORMAL,
		unresolved = unresolved,
		supported = true,
		hasActive = true,
	}
end

function Session:GetActiveCensoredPresentationState()
	local real = self:GetActiveCensoredState()
	if real.hasActive == true then
		if real.state == self.ACTIVE_CENSOR_STATE_UNRESOLVED then
			local entry = self:GetActive()
			local censoredOK, censored = pcall(function()
				return entry and entry.censored
			end)
			if censoredOK and canAccessValue(censored) then
				real.hidden = censored ~= false
				real.revealed = censored == false
			else
				real.hidden = true
			end
		end
		return real
	end
	return readDebugCensoredProjection() or real
end

function Session:HasActivePresentation()
	local state = self:GetActiveCensoredPresentationState()
	return state and state.hasActive == true
end

function Session:IsActiveCensoredMutationBlocked()
	local state = self:GetActiveCensoredState()
	return state.state == self.ACTIVE_CENSOR_STATE_UNRESOLVED
		or state.state == self.ACTIVE_CENSOR_STATE_UNKNOWN
end

function Session:RevealCensoredActiveEntry()
	local state = self:GetActiveCensoredState()
	local reveal = C_LFGList.RevealCensoredActiveEntry
	if state.state ~= self.ACTIVE_CENSOR_STATE_UNRESOLVED
		or type(reveal) ~= "function"
	then
		return false
	end
	reveal()
	return true
end

function Session:ConfirmCensoredActiveEntry()
	local state = self:GetActiveCensoredState()
	local confirm = C_LFGList.ConfirmCensoredActiveEntry
	if state.state ~= self.ACTIVE_CENSOR_STATE_UNRESOLVED
		or self:CanPublish() ~= true
		or type(confirm) ~= "function"
	then
		return false
	end
	confirm()
	return true
end

function Session:DoesCurrentCensoredCreationTextMatch()
	local checker = C_LFGList.DoesCensoredTextMatch
	local creation = _G.LFGListFrame and _G.LFGListFrame.EntryCreation
	local name = creation and creation.Name
	local description = creation and creation.Description
	local descriptionEdit = description and description.EditBox
	if type(checker) ~= "function"
		or not (name and type(name.GetText) == "function")
		or not (descriptionEdit and type(descriptionEdit.GetText) == "function")
	then
		return nil
	end
	-- Both arguments can be secret strings in 12.1. Pass them straight from the
	-- native edit fields without copying, comparing, formatting, or caching them.
	local matches = checker(name:GetText(), descriptionEdit:GetText())
	if not canAccessValue(matches) or type(matches) ~= "boolean" then
		return nil
	end
	return matches
end

function Session:GetActiveAutoInviteOwner()
	local entry = self:GetActive()
	if type(entry) ~= "table" then
		return self.AUTO_INVITE_OWNER_UNKNOWN
	end
	local questID, questReadable = readEntryQuestID(entry)
	if not questReadable then
		return self.AUTO_INVITE_OWNER_UNKNOWN
	end
	if questID == nil then
		return self.AUTO_INVITE_OWNER_PLUGIN
	end
	-- The create/update parameter is only a request.  Once an active entry
	-- exists, its readable autoAccept field is the owner truth; native control
	-- visibility/capability must never override it and start both engines.
	local readOK, autoAccept = pcall(function()
		return entry.autoAccept
	end)
	if not readOK then
		return self.AUTO_INVITE_OWNER_UNKNOWN
	end
	if not canAccessValue(autoAccept) then
		return self.AUTO_INVITE_OWNER_UNKNOWN
	end
	if autoAccept == true then
		return self.AUTO_INVITE_OWNER_NATIVE
	end
	if autoAccept == false then
		return self.AUTO_INVITE_OWNER_PLUGIN
	end
	return self.AUTO_INVITE_OWNER_UNKNOWN
end

function Session:IsActiveQuestListing()
	local entry = self:GetActive()
	local questID, readable = readEntryQuestID(entry)
	return readable == true and questID ~= nil
end

function Session:UsesNativeQuestAutoAccept()
	return self:GetActiveAutoInviteOwner() == self.AUTO_INVITE_OWNER_NATIVE
end

function Session:CanPluginOwnAutoInvite()
	return self:GetActiveAutoInviteOwner() == self.AUTO_INVITE_OWNER_PLUGIN
end

function Session:GetActiveAutoAcceptControlState()
	local entry = self:GetActive()
	if type(entry) ~= "table" then
		return nil
	end
	local questID, questReadable = readEntryQuestID(entry)
	if questReadable and questID == nil then
		return nil
	end
	local owner = self:GetActiveAutoInviteOwner()
	if owner == self.AUTO_INVITE_OWNER_PLUGIN then
		return nil
	end
	local nativeOwner = owner == self.AUTO_INVITE_OWNER_NATIVE
	return {
		mode = self.AUTO_ACCEPT_CONTROL_MODE_NATIVE_QUEST,
		checked = nativeOwner,
		canToggle = false,
		readOnly = true,
		disabledReason = nativeOwner and "native_owner" or "unknown",
	}
end

local USER_REMOVE_RESET_TIMEOUT_SEC = 8

local function clearPendingUserRemoveReset(listing, expectedGeneration)
	local generation = listing._pendingUserRemoveReset
	if expectedGeneration ~= nil and generation ~= expectedGeneration then
		return false
	end
	local timer = listing._userRemoveResetTimer
	listing._userRemoveResetTimer = nil
	listing._pendingUserRemoveReset = nil
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
	return generation ~= nil
end

local function markPendingUserRemoveReset(listing)
	clearPendingUserRemoveReset(listing)
	local generation = (listing._userRemoveResetGeneration or 0) + 1
	listing._userRemoveResetGeneration = generation
	listing._pendingUserRemoveReset = generation
	local function expirePendingReset()
		clearPendingUserRemoveReset(listing, generation)
	end
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		listing._userRemoveResetTimer = C_Timer.NewTimer(
			USER_REMOVE_RESET_TIMEOUT_SEC,
			expirePendingReset)
	elseif C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(USER_REMOVE_RESET_TIMEOUT_SEC, expirePendingReset)
	end
end

function Session:ConsumeConfirmedUserRemoval()
	return clearPendingUserRemoveReset(self)
end

function Session:Remove()
	local bumpBusy = type(self.IsBusy) == "function" and self:IsBusy()
	if bumpBusy or self:HasActive() ~= true or self:CanPublish() ~= true then
		return false
	end
	markPendingUserRemoveReset(self)
	if GF.InvitationScheduler and GF.InvitationScheduler.ClearSession then
		GF.InvitationScheduler:ClearSession()
	end
	C_LFGList.RemoveListing()
	return true
end

function Session:BuildSubmissionFromActive(overrides)
	local safeSubmission = self:GetSafeRelistSubmission()
	if safeSubmission then
		if type(overrides) == "table" and overrides.isAutoAccept ~= nil then
			safeSubmission.isAutoAccept = overrides.isAutoAccept == true
		end
		return safeSubmission
	end
	local entry = self:GetActive()
	if entry == nil then
		return nil
	end
	local activityID = self:GetActiveActivityID()
	if activityID == nil then
		return nil
	end
	local requestedAutoAccept = type(overrides) == "table"
		and overrides.isAutoAccept or nil
	if type(overrides) ~= "table" or overrides.isAutoAccept == nil then
		requestedAutoAccept = entry.autoAccept
	end
	return {
		activityIDs = { activityID },
		questID = entry.questID,
		isAutoAccept = requestedAutoAccept == true,
		isCrossFactionListing = isCrossFactionEntry(entry),
		isPrivateGroup = entry.privateGroup == true,
		newPlayerFriendly = entry.newPlayerFriendly == true,
		playstyle = entry.playstyle or Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = entry.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = tonumber(entry.requiredDungeonScore) or 0,
		requiredItemLevel = tonumber(entry.requiredItemLevel) or 0,
		requiredPvpRating = tonumber(entry.requiredPvpRating) or 0,
	}
end

function Session:BuildSubmissionFromDraft(params)
	if type(params) ~= "table" or params.activityID == nil then
		return nil
	end
	local active = self:GetActive()
	local safeSubmission = self:GetSafeRelistSubmission()
	local friendly = params.newPlayerFriendly == true
	local questID = params.questID
	local isAutoAccept = params.isAutoAccept == true
	if safeSubmission then
		friendly = safeSubmission.newPlayerFriendly == true
		questID = safeSubmission.questID
		isAutoAccept = safeSubmission.isAutoAccept == true
	elseif active then
		friendly = active.newPlayerFriendly == true
		questID = active.questID
		isAutoAccept = active.autoAccept == true
	end
	return {
		activityIDs = { params.activityID },
		questID = questID,
		isAutoAccept = isAutoAccept,
		isCrossFactionListing = params.isCrossFactionListing == true,
		isPrivateGroup = params.isPrivateGroup == true,
		newPlayerFriendly = friendly,
		playstyle = Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = params.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = tonumber(params.requiredDungeonScore) or 0,
		requiredItemLevel = tonumber(params.requiredItemLevel) or 0,
		requiredPvpRating = tonumber(params.requiredPvpRating) or 0,
	}
end

local function updateListingWithOwnership(listing, createData, copyNativeFields, opts)
	if createData == nil then
		return false, "invalid"
	end
	opts = opts or {}
	local censorState = listing:GetActiveCensoredState()
	if opts.censoredResolution == true then
		if censorState.state ~= listing.ACTIVE_CENSOR_STATE_UNRESOLVED then
			return false, "censored_state_changed"
		end
	elseif censorState.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
		or censorState.state == listing.ACTIVE_CENSOR_STATE_UNKNOWN
	then
		return false, "censored_pending"
	end
	if copyNativeFields
		and NativeCreation:CanCopyActiveEntryInfoToCreationFields()
	then
		NativeCreation:CopyActiveEntryInfoToCreationFields()
	end
	-- Re-query after any native field preparation and immediately before the
	-- restricted update. A synchronous state change must not cross this fence.
	censorState = listing:GetActiveCensoredState()
	if opts.censoredResolution == true then
		if censorState.state ~= listing.ACTIVE_CENSOR_STATE_UNRESOLVED then
			return false, "censored_state_changed"
		end
		local matches = listing:DoesCurrentCensoredCreationTextMatch()
		if matches ~= false then
			return false, matches == true
				and "censored_text_unchanged"
				or "censored_validation_unavailable"
		end
	elseif censorState.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
		or censorState.state == listing.ACTIVE_CENSOR_STATE_UNKNOWN
	then
		return false, "censored_pending"
	end
	local ownership = {
		current = listing._activeEntryOwnedByGroupFinder,
		last = listing._lastActiveEntryOwnedByGroupFinder,
		activeSafeRelistSubmission = listing._activeSafeRelistSubmission,
		pendingSafeRelistSubmission = listing._pendingSafeRelistSubmission,
	}
	listing:BeginOwnedEntryRequest(createData, opts.safeForRelist == true)
	local requirements = GF.RaidRecruitmentPolicy
	local request = requirements and opts.requirements and requirements:BeginSubmission(opts.requirements)
	local callOK, accepted = pcall(C_LFGList.UpdateListing, createData)
	accepted = callOK and accepted == true
	if request then requirements:FinishSubmission(request, accepted) end
	if accepted then
		return true, "updated"
	end
	listing:CancelOwnedEntryRequest()
	listing._activeEntryOwnedByGroupFinder = ownership.current
	listing._lastActiveEntryOwnedByGroupFinder = ownership.last
	listing._activeSafeRelistSubmission = ownership.activeSafeRelistSubmission
	listing._pendingSafeRelistSubmission = ownership.pendingSafeRelistSubmission
	return false, "rejected"
end

local function canUpdateListing(listing)
	local bumpBusy = type(listing.IsBusy) == "function"
		and listing:IsBusy()
	return not bumpBusy and listing:CanPublish()
end

function Session:UpdateFromActive(overrides)
	if not canUpdateListing(self) then
		return false
	end
	if self:IsActiveCensoredMutationBlocked() then
		return false, "censored_pending"
	end
	local safeForRelist = self:HasSafeRelistSubmission()
	return updateListingWithOwnership(
		self,
		self:BuildSubmissionFromActive(overrides),
		true,
		{ safeForRelist = safeForRelist })
end

function Session:UpdateFromDraft(params, opts)
	if not canUpdateListing(self) then
		return false
	end
	opts = opts or {}
	local safeForRelist = self:HasSafeRelistSubmission()
	if opts.censoredResolution ~= true
		and self:IsActiveCensoredMutationBlocked()
	then
		return false, "censored_pending"
	end
	-- 受保护文本由当前的原生字段租约提供；此处不反向填充 active entry。
	return updateListingWithOwnership(
		self,
		self:BuildSubmissionFromDraft(params),
		false,
		{
			censoredResolution = opts.censoredResolution,
			safeForRelist = safeForRelist,
			requirements = params,
		})
end

local BUMP_COOLDOWN_SEC = 60
local BUMP_COOLDOWN_TICK_SEC = 1
local BUMP_CONFIRM_TIMEOUT_SEC = 8
local BUMP_REMOVE_CONFIRM_TIMEOUT_SEC = 8

local function recordBumpFailure(self, stage)
	self._lastBumpRelistFailureStage = stage or "unknown"
	self._lastBumpRelistFailureAt = GetTime()
end

local function notifyBumpFailure(self, stage, oldListingMayBeGone)
	recordBumpFailure(self, stage)
	local L = GF.L or {}
	local message
	if stage == "user_cancelled" then
		message = L.BUMP_LISTING_CANCELLED_AFTER_REMOVE
	elseif oldListingMayBeGone == true then
		message = L.BUMP_LISTING_FAILED_AFTER_REMOVE
	else
		message = L.BUMP_LISTING_FAILED
	end
	notifyUiError(message or "Could not relist")
end

local function refreshApplicantManageState()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateManageState then
		GF.ApplicantsPanel:UpdateManageState()
	end
end

local function refreshBumpButtonState()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateBumpButtonState then
		GF.ApplicantsPanel:UpdateBumpButtonState()
	else
		refreshApplicantManageState()
	end
end

local function cancelBumpCooldownRefresh(self)
	self._bumpCooldownRefreshGeneration = (self._bumpCooldownRefreshGeneration or 0) + 1
	if self._bumpCooldownTicker and self._bumpCooldownTicker.Cancel then
		self._bumpCooldownTicker:Cancel()
	end
	self._bumpCooldownTicker = nil
end

local function scheduleBumpCooldownRefresh(self)
	cancelBumpCooldownRefresh(self)
	refreshBumpButtonState()
	if not self._lastBumpAt or self:GetRelistCooldownRemaining() <= 0 or not C_Timer then
		return
	end
	local generation = self._bumpCooldownRefreshGeneration
	local function refreshCooldown()
		if generation ~= self._bumpCooldownRefreshGeneration then
			return
		end
		refreshBumpButtonState()
		if self:GetRelistCooldownRemaining() <= 0 then
			cancelBumpCooldownRefresh(self)
		end
	end
	if C_Timer.NewTicker then
		self._bumpCooldownTicker = C_Timer.NewTicker(BUMP_COOLDOWN_TICK_SEC, refreshCooldown)
	elseif C_Timer.After then
		local function refreshWithGeneration()
			if generation ~= self._bumpCooldownRefreshGeneration then
				return
			end
			refreshCooldown()
			if generation == self._bumpCooldownRefreshGeneration
				and self:GetRelistCooldownRemaining() > 0 then
				C_Timer.After(BUMP_COOLDOWN_TICK_SEC, refreshWithGeneration)
			end
		end
		C_Timer.After(BUMP_COOLDOWN_TICK_SEC, refreshWithGeneration)
	end
end

local function cancelBumpRelistTimer(self)
	if self._bumpRelistTimer and self._bumpRelistTimer.Cancel then
		self._bumpRelistTimer:Cancel()
	end
	self._bumpRelistTimer = nil
end

local function beginBumpRelist(self, createData)
	cancelBumpRelistTimer(self)
	self._bumpRelistGeneration = (self._bumpRelistGeneration or 0) + 1
	self._bumpRelistState = "removing"
	self._bumpRelistStage = "removing"
	self._bumpRelistCreateData = cloneListingCreateData(createData)
	self._bumpRelistCreationFailed = nil
	self._bumpRelistFenceRestoreFailed = nil
	self._bumpRelistSawInactive = nil
	self._bumpRelistRemoveSubmitted = nil
	self._bumpRelistLease = nil
	self._bumpRelistStartedAt = GetTime()
	return self._bumpRelistGeneration
end

local function isCurrentBumpRelist(self, generation)
	return self._bumpRelistState ~= nil and self._bumpRelistGeneration == generation
end

local function releaseHeldBumpLease(self, generation, replayMissedInactive)
	if self._bumpRelistGeneration ~= generation then
		return true
	end
	local lease = self._bumpRelistLease
	if lease == nil then
		return true
	end
	self._bumpRelistLease = nil
	local bridge = self._bumpFieldBridge
	local resumed = false
	if bridge and type(bridge.Resume) == "function" then
		local callOK, result = pcall(
			bridge.Resume,
			lease,
			replayMissedInactive == true
		)
		resumed = callOK and result == true
	end
	if not resumed then
		self._bumpRelistFenceRestoreFailed = generation
	end
	if bridge and type(bridge.Release) == "function" then
		pcall(bridge.Release, lease)
	end
	return resumed
end

local function endBumpRelist(self, generation)
	if self._bumpRelistGeneration ~= generation then
		return
	end
	cancelBumpRelistTimer(self)
	releaseHeldBumpLease(
		self,
		generation,
		self._bumpRelistSawInactive == generation
	)
	self._bumpRelistState = nil
	self._bumpRelistStage = nil
	self._bumpRelistCreateData = nil
	self._bumpRelistCreationFailed = nil
	self._bumpRelistFenceRestoreFailed = nil
	self._bumpRelistSawInactive = nil
	self._bumpRelistRemoveSubmitted = nil
	self._bumpRelistLease = nil
	self._bumpRelistStartedAt = nil
end

local function finishBumpRelist(self, generation, ok, opts)
	if not isCurrentBumpRelist(self, generation) then
		return false
	end
	opts = opts or {}
	self._bumpBusyUntil = nil
	if ok then
		self._lastBumpAt = GetTime()
		self._lastBumpRelistFailureStage = nil
		self._lastBumpRelistFailureAt = nil
		if GF.InvitationScheduler and GF.InvitationScheduler.ClearSession then
			GF.InvitationScheduler:ClearSession()
		end
	else
		self:CancelOwnedEntryRequest()
		notifyBumpFailure(
			self,
			self._bumpRelistStage,
			self._bumpRelistRemoveSubmitted == generation)
	end
	self._lastBumpRelistGeneration = generation
	self._lastBumpRelistSucceeded = ok == true
	self._lastBumpRelistFenceRestoreFailed =
		self._bumpRelistFenceRestoreFailed == generation
	if GF.RelistConfirmDialog and GF.RelistConfirmDialog.Hide then
		GF.RelistConfirmDialog:Hide("resolved")
	end
	endBumpRelist(self, generation)
	if GF.RaidRecruitmentPolicy then GF.RaidRecruitmentPolicy:OnRelistFinished(ok) end
	if ok then
		scheduleBumpCooldownRefresh(self)
	end
	refreshApplicantManageState()
	if not opts.skipUiRefresh and GF.MainFrame and GF.MainFrame.OnActiveEntryUpdate then
		GF.MainFrame:OnActiveEntryUpdate({
			finalizeBump = true,
			bumpSucceeded = ok == true,
			suppressCreateAutoOpen = not ok,
		})
	end
	return true
end

function Session:IsRelisting()
	return self._bumpRelistState ~= nil
end

function Session:IsAwaitingRelistRepost(generation)
	local waiting = self._bumpRelistState == "awaiting_remove"
		or self._bumpRelistState == "awaiting_repost"
	return waiting
		and (generation == nil
			or self._bumpRelistGeneration == tonumber(generation))
end

function Session:IsBusy()
	return self:IsRelisting()
		or self._pendingGroupFinderActiveEntry == true
		or (self._bumpBusyUntil and GetTime() < self._bumpBusyUntil)
end

function Session:GetRelistCooldownRemaining()
	if not self._lastBumpAt then
		return 0
	end
	return math.max(0, BUMP_COOLDOWN_SEC - (GetTime() - self._lastBumpAt))
end

function Session:IsRelistOnCooldown()
	return self:GetRelistCooldownRemaining() > 0
end

function Session:GetLastRelistFailure()
	return self._lastBumpRelistFailureStage,
		self._lastBumpRelistFenceRestoreFailed == true
end

function Session:SetRelistFieldBridge(bridge)
	self._bumpFieldBridge = bridge
end

local function validateQuestRelistSubmission(createData)
	local questID, readable = readEntryQuestID(createData)
	if not readable then
		return false, nil, true
	end
	if questID == nil then
		return true, nil, false
	end
	local questBridge = GF.QuestRecruitmentBridge
	local validator = questBridge and questBridge.ValidateRelistSubmission
	if type(validator) ~= "function" then
		return false, nil, true
	end
	local callOK, resolved = pcall(validator, questBridge, createData)
	return callOK and type(resolved) == "table", resolved, true
end

local function showRelistConfirmation(self, generation, ready)
	local dialog = GF.RelistConfirmDialog
	return dialog and type(dialog.Show) == "function"
		and dialog:Show(generation, ready == true) == true
end

local function beginAwaitingRelistRepost(self, generation)
	if not isCurrentBumpRelist(self, generation) then
		return false
	end
	cancelBumpRelistTimer(self)
	self._bumpRelistSawInactive = generation
	self._bumpRelistState = "awaiting_repost"
	self._bumpRelistStage = "awaiting_repost"
	-- Keep known third-party consumers paused through the second click. Some
	-- consumers clear their creation model on the inactive event and then call
	-- CopyActiveEntryInfoToCreationFields() even though no active entry remains,
	-- which destroys the protected text copied before RemoveListing.
	if not showRelistConfirmation(self, generation, true) then
		self._bumpRelistStage = "repost_confirmation_unavailable"
		finishBumpRelist(self, generation, false)
		return false
	end
	refreshApplicantManageState()
	return true
end

local function armRelistRemoveConfirmationTimeout(self, generation)
	cancelBumpRelistTimer(self)
	local function confirmRemoveTimeout()
		if not isCurrentBumpRelist(self, generation)
			or self._bumpRelistState ~= "awaiting_remove"
		then
			return
		end
		self._bumpRelistTimer = nil
		self._bumpRelistStage = "remove_confirm_timeout"
		finishBumpRelist(self, generation, false)
	end
	if C_Timer and C_Timer.NewTimer then
		self._bumpRelistTimer = C_Timer.NewTimer(
			BUMP_REMOVE_CONFIRM_TIMEOUT_SEC,
			confirmRemoveTimeout)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(BUMP_REMOVE_CONFIRM_TIMEOUT_SEC, confirmRemoveTimeout)
	else
		confirmRemoveTimeout()
	end
end

function Session:HandleRelistEntryChanged(hasActive, createdNew)
	if self:IsRelisting() ~= true then
		return nil
	end
	local generation = self._bumpRelistGeneration
	if hasActive ~= true then
		self._bumpRelistSawInactive = generation
	end
	local state = self._bumpRelistState
	if state == "awaiting_remove" then
		if hasActive == true then
			return "pending"
		end
		return beginAwaitingRelistRepost(self, generation)
			and "pending" or "failed"
	end
	if state == "awaiting_repost" then
		if hasActive == true then
			self._bumpRelistStage = "active_entry_replaced"
			finishBumpRelist(self, generation, false, { skipUiRefresh = true })
			return "failed"
		end
		return "pending"
	end
	local waitingForCreate = state == "creating"
		or state == "awaiting_confirmation"
	if not waitingForCreate then
		return "pending"
	end
	if self._bumpRelistCreationFailed == generation then
		finishBumpRelist(self, generation, false, { skipUiRefresh = true })
		return "failed"
	end
	-- The generated event contract allows `created` to be nil. During a bump,
	-- the synchronous inactive event from RemoveListing followed by a new active
	-- entry is therefore authoritative even when the recreated event omits that
	-- flag. A standalone active refresh still cannot complete the transaction.
	local recreatedAfterInactive = self._bumpRelistSawInactive == generation
	if hasActive ~= true or (createdNew ~= true and not recreatedAfterInactive) then
		return "pending"
	end
	finishBumpRelist(self, generation, true, { skipUiRefresh = true })
	return "success"
end

function Session:Relist()
	local blocked = self:CanPublish() ~= true
		or self:HasActive() ~= true
		or self:IsRelistOnCooldown()
		or self._pendingUserRemoveReset ~= nil
		or self:IsBusy()
		or self._bumpRelistTimer ~= nil
		or self:IsActiveCensoredMutationBlocked()
	if blocked then
		return false
	end
	-- CreateListing only accepts untainted arguments. Reusing fields read back
	-- from GetActiveEntryInfo() can make the client reject the protected call,
	-- so a bump may only reuse the safe submission captured when GroupFinder
	-- created or updated this active entry in the current session.
	local createData = self:GetSafeRelistSubmission()
	if createData == nil then
		notifyBumpFailure(self, "safe_submission_unavailable")
		return false
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local relistDialog = GF.RelistConfirmDialog
	if type(relistDialog) ~= "table"
		or type(relistDialog.IsAvailable) ~= "function"
		or relistDialog:IsAvailable() ~= true
	then
		notifyBumpFailure(self, "repost_confirmation_unavailable")
		return false
	end
	local bridge = self._bumpFieldBridge
	local bridgeReady = type(bridge) == "table"
		and type(bridge.Acquire) == "function"
		and type(bridge.Resume) == "function"
		and type(bridge.Release) == "function"
	if not bridgeReady then
		notifyBumpFailure(self, "bridge_unavailable")
		return false
	end
	local questValid, _, questRelist = validateQuestRelistSubmission(createData)
	if not questValid then
		notifyBumpFailure(self, "quest_relist_unavailable")
		return false
	end
	if questRelist then
		if type(bridge.PrepareQuest) ~= "function"
			or type(bridge.ReleaseQuest) ~= "function"
		then
			notifyBumpFailure(self, "quest_relist_bridge_unavailable")
			return false
		end
	else
		if not NativeCreation:CanCopyActiveEntryInfoToCreationFields() then
			notifyBumpFailure(self, "copy_active_fields_unavailable")
			return false
		end
		local copiedCallOK, copied = pcall(
			NativeCreation.CopyActiveEntryInfoToCreationFields,
			NativeCreation
		)
		if not copiedCallOK or copied ~= true then
			notifyBumpFailure(self, "copy_active_fields_failed")
			return false
		end
	end
	local leaseOk, bumpLease = pcall(bridge.Acquire)
	if not leaseOk or not bumpLease then
		notifyBumpFailure(self, "inactive_fence_failed")
		return false
	end
	local function releaseBumpLease()
		if not bumpLease then
			return
		end
		pcall(bridge.Release, bumpLease)
		bumpLease = nil
	end
	local generation = beginBumpRelist(self, createData)
	-- The state can change while native fields and the relist lease are being
	-- prepared. Re-check every destructive precondition immediately before the
	-- remove call, including that the safe snapshot is still the one captured
	-- for this transaction.
	local lateFailureStage
	if self:CanPublish() ~= true then
		lateFailureStage = "permission_changed"
	elseif self:HasActive() ~= true then
		lateFailureStage = "active_entry_missing"
	elseif not sameListingCreateData(self:GetSafeRelistSubmission(), createData) then
		lateFailureStage = "safe_submission_changed"
	elseif self:IsActiveCensoredMutationBlocked() then
		lateFailureStage = "censored_unresolved"
	elseif questRelist then
		local stillValid = validateQuestRelistSubmission(createData)
		if not stillValid then
			lateFailureStage = "quest_relist_changed"
		end
	end
	if lateFailureStage ~= nil then
		releaseBumpLease()
		endBumpRelist(self, generation)
		notifyBumpFailure(self, lateFailureStage)
		refreshApplicantManageState()
		return false
	end
	if GF.InvitationScheduler and GF.InvitationScheduler.ClearSession then
		GF.InvitationScheduler:ClearSession()
	end
	-- Retail 12.1 rejects the second restricted LFG mutation when an addon tries
	-- to remove and recreate from the same ordinary button callback. Keep known
	-- external consumers paused across the authoritative inactive update and
	-- the wait for a fresh hardware click. They resume immediately before
	-- CreateListing so they cannot clear the copied protected text, but can
	-- still receive the replacement's active-entry event.
	self._bumpRelistState = "awaiting_remove"
	self._bumpRelistStage = "awaiting_remove"
	self._bumpRelistRemoveSubmitted = generation
	self._bumpRelistLease = bumpLease
	bumpLease = nil
	local removeCallOk = pcall(C_LFGList.RemoveListing)
	if not removeCallOk then
		self._bumpRelistStage = "remove_call_failed"
		finishBumpRelist(self, generation, false)
		return false
	end
	if not isCurrentBumpRelist(self, generation) then
		return self._lastBumpRelistGeneration == generation
			and self._lastBumpRelistSucceeded == true
	end
	if self._bumpRelistState == "awaiting_repost" then
		return true
	end
	-- Show the owned dialog immediately, but keep its repost action disabled
	-- until LFG_LIST_ACTIVE_ENTRY_UPDATE confirms that the old entry is gone.
	-- A post-call HasActive() snapshot cannot replace that event: API state may
	-- flip before event delivery, and releasing the field fence at that point
	-- would let restored third-party listeners consume the late inactive update
	-- and clear Blizzard's copied protected text.
	if not showRelistConfirmation(self, generation, false) then
		self._bumpRelistStage = "repost_confirmation_unavailable"
		finishBumpRelist(self, generation, false)
		return false
	end
	armRelistRemoveConfirmationTimeout(self, generation)
	refreshApplicantManageState()
	return true
end

function Session:ContinueRelist(generation)
	generation = tonumber(generation)
	if generation == nil
		or self._bumpRelistGeneration ~= generation
		or self._bumpRelistState ~= "awaiting_repost"
	then
		return false
	end
	local createData = cloneListingCreateData(self._bumpRelistCreateData)
	local failureStage
	local questResolved
	local questRelist = false
	if self:CanPublish() ~= true then
		failureStage = "permission_changed_before_repost"
	elseif self:HasActive() == true then
		failureStage = "active_entry_replaced"
	elseif createData == nil then
		failureStage = "safe_submission_unavailable_before_repost"
	else
		local questValid
		questValid, questResolved, questRelist =
			validateQuestRelistSubmission(createData)
		if not questValid then
			failureStage = "quest_relist_unavailable_before_repost"
		end
	end
	if failureStage ~= nil then
		self._bumpRelistStage = failureStage
		finishBumpRelist(self, generation, false)
		return false
	end
	self._bumpRelistState = "creating"
	self._bumpRelistStage = "creating"
	-- CreateListing gets its own real user click in 12.1. Do not defer this call
	-- through a timer or another event; the confirmation button calls here
	-- synchronously. Restore known consumers immediately before submission: they
	-- have missed the destructive inactive event, while still receiving the new
	-- active-entry event emitted by CreateListing.
	local questFieldLease
	if questRelist then
		local bridge = self._bumpFieldBridge
		local prepared, lease = pcall(
			bridge and bridge.PrepareQuest,
			questResolved
		)
		if not prepared or lease == nil then
			self._bumpRelistStage = "quest_fields_unavailable_before_repost"
			finishBumpRelist(self, generation, false)
			return false
		end
		questFieldLease = lease
	end
	-- Prepare task fields before restoring the held consumers. If preparation
	-- fails, finishBumpRelist can still replay the missed inactive transition;
	-- a successful resume only re-registers events and does not mutate fields.
	releaseHeldBumpLease(self, generation)
	self:BeginOwnedEntryRequest(createData, true, true)
	local createCallOk, createAccepted = pcall(C_LFGList.CreateListing, createData)
	if questFieldLease ~= nil then
		local bridge = self._bumpFieldBridge
		pcall(bridge and bridge.ReleaseQuest, questFieldLease)
	end
	if not isCurrentBumpRelist(self, generation) then
		return self._lastBumpRelistGeneration == generation
			and self._lastBumpRelistSucceeded == true
	end
	if not createCallOk
		or createAccepted ~= true
		or self._bumpRelistCreationFailed == generation
	then
		if self._bumpRelistCreationFailed == generation then
			self._bumpRelistStage = "creation_failed_event"
		elseif not createCallOk then
			self._bumpRelistStage = "create_call_error"
		else
			self._bumpRelistStage = "create_return_false"
		end
		finishBumpRelist(self, generation, false)
		return false
	end
	self._bumpRelistState = "awaiting_confirmation"
	self._bumpRelistStage = "awaiting_confirmation"
	local function confirmTimeout()
		if not isCurrentBumpRelist(self, generation) then
			return
		end
		self._bumpRelistTimer = nil
		self._bumpRelistStage = "confirm_timeout"
		finishBumpRelist(self, generation, false)
	end
	if C_Timer and C_Timer.NewTimer then
		self._bumpRelistTimer = C_Timer.NewTimer(
			BUMP_CONFIRM_TIMEOUT_SEC,
			confirmTimeout
		)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(BUMP_CONFIRM_TIMEOUT_SEC, confirmTimeout)
	else
		confirmTimeout()
	end
	return true
end

function Session:CancelRelistAfterRemove(generation)
	generation = tonumber(generation)
	if generation == nil
		or self._bumpRelistGeneration ~= generation
		or (self._bumpRelistState ~= "awaiting_remove"
			and self._bumpRelistState ~= "awaiting_repost")
	then
		return false
	end
	self._bumpRelistStage = "user_cancelled"
	finishBumpRelist(self, generation, false)
	return true
end

function Session:Create(params)
	if type(params) ~= "table" or params.activityID == nil then
		return false
	end
	local busy = type(self.IsBusy) == "function" and self:IsBusy()
	if busy or self:HasActive() == true or self:CanPublish() ~= true then
		return false
	end
	local createData = {
		activityIDs = { params.activityID },
		questID = params.questID,
		isAutoAccept = params.isAutoAccept == true,
		isCrossFactionListing = params.isCrossFactionListing == true,
		isPrivateGroup = params.isPrivateGroup == true,
		newPlayerFriendly = params.newPlayerFriendly == true,
		playstyle = Enum.LFGEntryPlaystyle.None,
		generalPlaystyle = params.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None,
		requiredDungeonScore = tonumber(params.requiredDungeonScore) or 0,
		requiredItemLevel = tonumber(params.requiredItemLevel) or 0,
		requiredPvpRating = tonumber(params.requiredPvpRating) or 0,
	}
	local ownership = {
		current = self._activeEntryOwnedByGroupFinder,
		last = self._lastActiveEntryOwnedByGroupFinder,
		activeSafeRelistSubmission = self._activeSafeRelistSubmission,
		pendingSafeRelistSubmission = self._pendingSafeRelistSubmission,
	}
	self:BeginOwnedEntryRequest(createData, true, true)
	local requirements = GF.RaidRecruitmentPolicy
	local request = requirements and requirements:BeginSubmission(params)
	local callOK, accepted = pcall(C_LFGList.CreateListing, createData)
	accepted = callOK and accepted == true
	local confirmedDuringCall = self._pendingGroupFinderActiveEntry ~= true
		and self._activeEntryOwnedByGroupFinder == true
		and self:HasActive() == true
	if request then requirements:FinishSubmission(request, accepted or confirmedDuringCall) end
	if accepted or confirmedDuringCall then
		local readyTeleport = GF.MythicPlusGroupReadyTeleportService
		if readyTeleport and readyTeleport.OnListingCreated then
			readyTeleport:OnListingCreated(params.activityID)
		end
		return true
	end
	self:CancelOwnedEntryRequest()
	self._activeEntryOwnedByGroupFinder = ownership.current
	self._lastActiveEntryOwnedByGroupFinder = ownership.last
	self._activeSafeRelistSubmission = ownership.activeSafeRelistSubmission
	self._pendingSafeRelistSubmission = ownership.pendingSafeRelistSubmission
	return false
end

function Session:HandleCreationFailed()
	if GF.RaidRecruitmentPolicy then GF.RaidRecruitmentPolicy:CancelSubmission() end
	local bumpState = self._bumpRelistState
	local duringBump = bumpState == "creating"
		or bumpState == "awaiting_confirmation"
	if not duringBump then
		-- The failure event is synchronous, so release the ownership request here
		-- instead of depending on a later UI refresh to observe an inactive entry.
		self:CancelOwnedEntryRequest()
		local locale = GF.L or {}
		notifyUiError(locale.CREATE_FAILED or "Listing failed. Please try again")
		return nil
	end
	local generation = self._bumpRelistGeneration
	self._bumpRelistCreationFailed = generation
	self._bumpRelistStage = "creation_failed_event"
	self:CancelOwnedEntryRequest()
	finishBumpRelist(self, generation, false, { skipUiRefresh = true })
	return "failed"
end

function Session:GetActiveActivityTitle()
	local activityID = self:GetActiveActivityID()
	if activityID == nil then
		return ""
	end
	local activity = C_LFGList.GetActivityInfoTable(activityID)
	if type(activity) ~= "table" then
		return ""
	end
	local categoryID = activity.categoryID
	if GF.NavData and type(GF.NavData.FindNodeByActivityID) == "function" then
		local node = GF.NavData.FindNodeByActivityID(activityID)
		if type(node) == "table" and node.categoryID ~= nil then
			categoryID = node.categoryID
		end
	end
	if GF.UI and type(GF.UI.GetCategoryTitle) == "function" then
		return GF.UI.GetCategoryTitle(categoryID, activity)
	end
	return activity.fullName or activity.shortName or ""
end

function Session:HasCrossFactionSettingChanged(newIsCrossFaction)
	local entry = self:GetActive()
	if type(entry) ~= "table" then
		return false
	end
	local currentValue = isCrossFactionEntry(entry)
	local requestedValue = newIsCrossFaction == true
	return currentValue ~= requestedValue
end
