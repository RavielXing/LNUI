local _, GF = ...

local Bridge = {}
GF.QuestRecruitmentBridge = Bridge

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

local function safePositiveInteger(value)
	if not canAccessValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or type(number) ~= "number" or number ~= math.floor(number) then
		return nil
	end
	return number > 0 and number or nil
end

local function readableMessage(value)
	if not canAccessValue(value) then
		return nil
	end
	return type(value) == "string" and value ~= "" and value or nil
end

local function notify(message)
	local text = readableMessage(message)
		or ((GF.L or {}).CREATE_FAILED or "Listing failed. Please try again.")
	if type(GF.ShowWarningMessage) == "function" then
		GF.ShowWarningMessage(text)
	end
end

local function activeQueueProblem()
	local reader = LFGListUtil_GetActiveQueueMessage
	if type(reader) ~= "function" then
		return nil
	end
	local ok, message = pcall(reader, false)
	if not ok then
		return true
	end
	if message == nil or message == false then
		return nil
	end
	return readableMessage(message) or true
end

local function availabilityProblem()
	local availability = GF.Availability
	local reader = availability and availability.GetPremadeBlockMessage
	if type(reader) ~= "function" then
		return nil
	end
	local ok, message = pcall(reader, availability)
	if not ok then
		return true
	end
	if message == nil or message == false then
		return nil
	end
	return readableMessage(message) or true
end

local function sessionAllowsCreate(session)
	if session == nil or type(session.HasActive) ~= "function"
		or type(session.CanPublish) ~= "function"
	then
		return false
	end
	if session:HasActive() == true or session:CanPublish() ~= true then
		return false
	end
	return type(session.IsBusy) ~= "function" or session:IsBusy() ~= true
end

local function activityCapacityProblem(activity)
	local maximum = activity and safePositiveInteger(activity.maxNumPlayers)
	if not maximum then
		return nil
	end
	local groupSize = 0
	if type(GetNumGroupMembers) == "function" then
		local ok, count = pcall(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME)
		if ok and canAccessValue(count) then
			groupSize = tonumber(count) or 0
		end
	end
	if groupSize < maximum then
		return nil
	end
	local template = LFG_LIST_TOO_MANY_FOR_ACTIVITY
		or "Too many members for this activity (%d)."
	local ok, message = pcall(string.format, template, maximum)
	return ok and message or true
end

local function activeEntryMatches(pending)
	local session = GF.RecruitmentSession
	local entry = session and session.GetActive and session:GetActive() or nil
	if type(entry) ~= "table" then
		return false
	end
	local questID = safePositiveInteger(entry.questID)
	local activityIDs = entry.activityIDs
	local activityID = type(activityIDs) == "table"
		and safePositiveInteger(activityIDs[1])
		or safePositiveInteger(entry.activityID)
	return questID == pending.questID and activityID == pending.activityID
end

function Bridge:SetFieldBridge(fieldBridge)
	self._fieldBridge = fieldBridge
end

function Bridge:IsReady()
	local fieldBridge = self._fieldBridge
	return type(fieldBridge) == "table"
		and type(fieldBridge.CanAcquire) == "function"
		and type(fieldBridge.Acquire) == "function"
		and type(fieldBridge.Release) == "function"
end

function Bridge:IsPending()
	return self._pending ~= nil
end

function Bridge:CanOffer()
	local fieldBridge = self._fieldBridge
	local fieldReady, canAcquire = pcall(
		fieldBridge and fieldBridge.CanAcquire,
		fieldBridge
	)
	return self:IsReady()
		and fieldReady and canAcquire == true
		and self._pending == nil
		and sessionAllowsCreate(GF.RecruitmentSession)
		and activeQueueProblem() == nil
		and availabilityProblem() == nil
end

local function validateFreshQuest(request)
	if type(request) ~= "table" then
		return nil
	end
	local questID = GF.QuestSearch and GF.QuestSearch.NormalizeQuestID
		and GF.QuestSearch:NormalizeQuestID(request.questID) or nil
	if not questID or not (GF.QuestSearch and GF.QuestSearch.Resolve) then
		return nil
	end
	local resolved = GF.QuestSearch:Resolve(questID)
	if type(resolved) ~= "table" then
		return nil
	end
	local activityID = safePositiveInteger(resolved.activityID)
	local categoryID = safePositiveInteger(resolved.categoryID)
	if not activityID or not categoryID
		or activityID ~= safePositiveInteger(request.activityID)
		or categoryID ~= safePositiveInteger(request.categoryID)
	then
		return nil
	end
	local canCreate = C_LFGList and C_LFGList.CanCreateQuestGroup
	if type(canCreate) ~= "function" then
		return nil
	end
	local allowed, result = pcall(canCreate, questID)
	if not allowed or result ~= true then
		return nil
	end
	local readActivity = C_LFGList.GetActivityInfoTable
	if type(readActivity) ~= "function" then
		return nil
	end
	local readOK, activity = pcall(readActivity, activityID, questID)
	if not readOK or type(activity) ~= "table"
		or safePositiveInteger(activity.categoryID) ~= categoryID
	then
		return nil
	end
	return resolved, activity
end

function Bridge:Create(request)
	if self._pending ~= nil or not self:IsReady() then
		return false
	end
	local session = GF.RecruitmentSession
	if not sessionAllowsCreate(session) then
		if session and session.CanPublish and session:CanPublish() ~= true
			and session.NotifyLeaderOnly
		then
			session:NotifyLeaderOnly()
		end
		return false
	end
	local queueProblem = activeQueueProblem()
	local premadeProblem = availabilityProblem()
	if queueProblem ~= nil or premadeProblem ~= nil then
		notify(queueProblem ~= true and queueProblem
			or (premadeProblem ~= true and premadeProblem or nil))
		return false
	end

	local resolved, activity = validateFreshQuest(request)
	if not resolved then
		notify()
		return false
	end
	local capacityProblem = activityCapacityProblem(activity)
	if capacityProblem ~= nil then
		notify(capacityProblem ~= true and capacityProblem or nil)
		return false
	end

	local fieldBridge = self._fieldBridge
	local acquired, lease = pcall(fieldBridge.Acquire, fieldBridge, resolved)
	if not acquired or lease == nil then
		notify()
		return false
	end

	local pending = {
		questID = resolved.questID,
		activityID = resolved.activityID,
	}
	self._pending = pending
	local values = Enum and Enum.LFGEntryGeneralPlaystyle
	local params = {
		activityID = resolved.activityID,
		questID = resolved.questID,
		isAutoAccept = true,
		isCrossFactionListing = false,
		isPrivateGroup = false,
		newPlayerFriendly = false,
		generalPlaystyle = values and values.None or 0,
		requiredDungeonScore = 0,
		requiredItemLevel = 0,
		requiredPvpRating = 0,
	}
	local callOK, accepted = pcall(session.Create, session, params)
	pcall(fieldBridge.Release, fieldBridge, lease)
	accepted = callOK and accepted == true
	if pending.outcome == "success" then
		return true
	end
	if pending.outcome == "failed" or pending.outcome == "cancelled" then
		return false
	end
	if accepted then
		return true
	end

	-- A synchronous failure event clears this exact pending record. Avoid a
	-- duplicate error toast in that case; otherwise release it locally.
	if self._pending == pending then
		self._pending = nil
		notify()
	end
	return false
end

function Bridge:HandleActiveEntryChanged(hasActive, createdNew)
	local pending = self._pending
	if pending == nil then
		return nil
	end
	-- An ordinary active-entry refresh is not authoritative confirmation that
	-- this restricted request created a new listing. Keep waiting until the
	-- native event explicitly identifies a newly created entry.
	if hasActive ~= true or createdNew ~= true then
		return "pending"
	end
	local matched = activeEntryMatches(pending)
	pending.outcome = matched and "success" or "cancelled"
	self._pending = nil
	return pending.outcome
end

function Bridge:HandleCreationFailed()
	if self._pending == nil then
		return nil
	end
	self._pending.outcome = "failed"
	self._pending = nil
	return "failed"
end
