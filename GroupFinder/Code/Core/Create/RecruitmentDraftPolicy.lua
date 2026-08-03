local _, GF = ...

local Policy = {}
GF.RecruitmentDraftPolicy = Policy

local function selectionActivityID(selection)
	local resolver = GF.NavData and GF.NavData.ResolveCreateActivityID
	if type(resolver) ~= "function" then
		return selection and not selection.categoryBrowse and selection.activityID or nil
	end
	return resolver(selection)
end

local function isPlaystyleMissing(playstyle)
	local values = Enum and Enum.LFGEntryGeneralPlaystyle
	return values ~= nil and playstyle == values.None
end

local function activityIsAllowed(draft, activityID)
	if draft.editMode == true then
		return true
	end
	local policy = GF.LFGWorkspacePolicy
	local checker = policy and policy.IsCreateActivityAllowed
	if type(checker) ~= "function" then
		return true
	end
	return policy:IsCreateActivityAllowed(draft.workspaceID, activityID) == true
end

local function activityDetails(selection, activityID)
	if selection ~= nil and selection.activityInfo ~= nil then
		return selection.activityInfo
	end
	local reader = C_LFGList and C_LFGList.GetActivityInfoTable
	return type(reader) == "function" and reader(activityID) or nil
end

local function issue(code, detail)
	return false, { code = code, detail = detail }
end

local function activeQueueIssue()
	local reader = LFGListUtil_GetActiveQueueMessage
	if type(reader) ~= "function" then
		return nil
	end
	local message = reader(false)
	return type(message) == "string" and message ~= "" and message or nil
end

local function capacityIssue(activity)
	local maximum = activity and tonumber(activity.maxNumPlayers) or 0
	if maximum <= 0 then
		return nil
	end
	local groupSize = tonumber(GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)) or 0
	if groupSize < maximum then
		return nil
	end
	local template = LFG_LIST_TOO_MANY_FOR_ACTIVITY
		or "Too many members for this activity (%d)."
	return string.format(template, maximum)
end

local function keystoneIssue(activity, activityID)
	if activity == nil or activity.isMythicPlusActivity ~= true then
		return false
	end
	local authenticated = C_LFGList and C_LFGList.IsPlayerAuthenticatedForLFG
	if type(authenticated) ~= "function" or authenticated(activity.categoryID) then
		return false
	end
	local hasKey = C_LFGList and C_LFGList.GetKeystoneForActivity
	if type(hasKey) ~= "function" or hasKey(activityID) then
		return false
	end
	return true, LFG_AUTHENTICATOR_BUTTON_MYTHIC_PLUS_TOOLTIP
end

function Policy:BuildParameters(draft)
	local selection = draft and draft.selection
	if type(selection) ~= "table" or selection.categoryID == nil
		or isPlaystyleMissing(draft.generalPlaystyle)
	then
		return nil
	end
	local activityID = selectionActivityID(selection)
	if activityID == nil or not activityIsAllowed(draft, activityID) then
		return nil
	end
	local categoryReader = C_LFGList and C_LFGList.GetLfgCategoryInfo
	local category = type(categoryReader) == "function"
		and categoryReader(selection.categoryID) or nil
	local activity = activityDetails(selection, activityID)
	local crossFactionAllowed = category ~= nil
		and category.allowCrossFaction == true
		and activity ~= nil
		and activity.allowCrossFaction == true
	return {
		activityID = activityID,
		groupID = selection.groupID,
		categoryID = selection.categoryID,
		questID = nil,
		isAutoAccept = false,
		isPrivateGroup = draft.privateGroup == true,
		isCrossFactionListing = crossFactionAllowed
			and draft.factionRestricted ~= true,
		generalPlaystyle = draft.generalPlaystyle,
		requiredItemLevel = tonumber(draft.requiredItemLevel) or 0,
		requiredDungeonScore = tonumber(draft.requiredDungeonScore) or 0,
		requiredPvpRating = 0,
	}
end

local CHECKS = {
	function(draft)
		local selection = draft.selection
		if type(selection) ~= "table" or selection.categoryID == nil then
			return issue("selection")
		end
	end,
	function(draft)
		local listing = GF.RecruitmentSession
		if draft.editMode ~= true and listing ~= nil
			and type(listing.HasActive) == "function" and listing:HasActive()
		then
			return issue("active_listing")
		end
	end,
	function(draft)
		local checker = GF.NavData and GF.NavData.CanCreateFromNode
		if type(checker) == "function" and not checker(draft.selection) then
			return issue("activity")
		end
	end,
	function(draft)
		if isPlaystyleMissing(draft.generalPlaystyle) then
			return issue("playstyle")
		end
	end,
	function(draft, context)
		context.activityID = selectionActivityID(draft.selection)
		if context.activityID == nil then
			return issue("activity")
		end
	end,
	function(draft, context)
		if not activityIsAllowed(draft, context.activityID) then
			return issue("workspace")
		end
	end,
	function()
		local message = activeQueueIssue()
		if message ~= nil then
			return issue("queue", message)
		end
	end,
	function(draft, context)
		context.activity = activityDetails(draft.selection, context.activityID)
		local message = capacityIssue(context.activity)
		if message ~= nil then
			return issue("capacity", message)
		end
	end,
	function(_, context)
		local blocked, message = keystoneIssue(context.activity, context.activityID)
		if blocked then
			return issue("keystone", message)
		end
	end,
	function(draft)
		if draft.hasCreationName ~= true then
			return issue("name")
		end
	end,
	function(draft)
		if draft.editMode ~= true then
			return
		end
		local listing = GF.RecruitmentSession
		if listing == nil or type(listing.HasCrossFactionSettingChanged) ~= "function" then
			return
		end
		local params = Policy:BuildParameters(draft)
		if params ~= nil and listing:HasCrossFactionSettingChanged(params.isCrossFactionListing) then
			return issue("cross_faction")
		end
	end,
}

function Policy:Validate(draft)
	if type(draft) ~= "table" then
		return issue("selection")
	end
	local context = {}
	for index = 1, #CHECKS do
		local passed, problem = CHECKS[index](draft, context)
		if passed == false then
			return false, problem
		end
	end
	return true, context
end
