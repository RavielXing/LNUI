local _, GF = ...

local Snapshot = {}
GF.SearchResultSnapshot = Snapshot

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

function Snapshot.ReadField(owner, key)
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, owner, key)
		if ok and secret == true then
			return nil, "secret"
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	end
	if isSecret(value) then
		return nil, "secret"
	end
	if value == nil then
		return nil, "missing"
	end
	return value, "value"
end

function Snapshot.ToNumber(value)
	if value == nil or isSecret(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	return ok and number or nil
end

local function arrayLength(values)
	if type(values) ~= "table" then
		return nil
	end
	local ok, length = pcall(function()
		return #values
	end)
	return ok and type(length) == "number" and length or nil
end

local function nativeResultStillPresent(resultID)
	local probe = C_LFGList and C_LFGList.HasSearchResultInfo
	if type(probe) ~= "function" then
		return true
	end
	local ok, present = pcall(probe, resultID)
	return not ok or present ~= false
end

local function appendActivityID(list, seen, value)
	local activityID = Snapshot.ToNumber(value)
	if not activityID or activityID <= 0 or seen[activityID] then
		return
	end
	seen[activityID] = true
	list[#list + 1] = activityID
end

function Snapshot.GetActivityIDs(info, entry)
	local activityIDs = {}
	local seen = {}
	local primary = Snapshot.ReadField(info, "activityID")
	appendActivityID(activityIDs, seen, primary)
	local values = Snapshot.ReadField(info, "activityIDs")
	local activityCount = arrayLength(values)
	if activityCount then
		for index = 1, activityCount do
			appendActivityID(
				activityIDs, seen, Snapshot.ReadField(values, index))
		end
	end
	if type(entry) == "table" then
		appendActivityID(activityIDs, seen, Snapshot.ReadField(entry, "activityID"))
	end
	return activityIDs
end

function Snapshot.GetPrimaryActivityID(info)
	return Snapshot.GetActivityIDs(info)[1]
end

function Snapshot.GetSearchResultInfo(resultID)
	if not resultID or not (C_LFGList and C_LFGList.GetSearchResultInfo) then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
	return ok and type(info) == "table" and info or nil
end

function Snapshot.GetActivityInfo(info, activityID)
	activityID = Snapshot.ToNumber(activityID)
	if not activityID or not (C_LFGList and C_LFGList.GetActivityInfoTable) then
		return nil
	end
	local questID = Snapshot.ReadField(info, "questID")
	local isWarMode = Snapshot.ReadField(info, "isWarMode")
	local ok, activity = pcall(
		C_LFGList.GetActivityInfoTable, activityID, questID, isWarMode)
	return ok and type(activity) == "table" and activity or nil
end

function Snapshot.ResolveActivityInfo(info, activityInfo)
	if type(activityInfo) == "table" then
		return activityInfo
	end
	return Snapshot.GetActivityInfo(info, Snapshot.GetPrimaryActivityID(info))
end

function Snapshot.ResolveActivityCategory(activityID)
	activityID = Snapshot.ToNumber(activityID)
	if not activityID then
		return nil, nil
	end
	local activity = Snapshot.GetActivityInfo(nil, activityID)
	if activity then
		return Snapshot.ToNumber(Snapshot.ReadField(activity, "categoryID")), activity
	end
	local legacyLookup = C_LFGList and C_LFGList.GetActivityInfo
	if type(legacyLookup) == "function" then
		local ok, _, _, categoryID = pcall(legacyLookup, activityID)
		if ok then
			return Snapshot.ToNumber(categoryID), nil
		end
	end
	return nil, nil
end

function Snapshot.GetMemberCounts(resultID, entry)
	if type(entry) == "table"
		and entry._displayCountsLoaded == true
		and type(entry._displayCounts) == "table"
	then
		return entry._displayCounts
	end
	if not resultID or not (C_LFGList and C_LFGList.GetSearchResultMemberCounts) then
		return nil
	end
	if not nativeResultStillPresent(resultID) then
		return nil
	end
	local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
	if not ok or type(counts) ~= "table" then
		return nil
	end
	if type(entry) == "table" then
		entry._displayCounts = counts
		entry._displayCountsLoaded = true
		entry.tanks = Snapshot.ToNumber(Snapshot.ReadField(counts, "TANK")) or entry.tanks or 0
		entry.heals = Snapshot.ToNumber(Snapshot.ReadField(counts, "HEALER")) or entry.heals or 0
		entry.dps = Snapshot.ToNumber(Snapshot.ReadField(counts, "DAMAGER")) or entry.dps or 0
	end
	return counts
end

function Snapshot.GetPlayers(resultID, info, entry)
	local expected = Snapshot.ToNumber(Snapshot.ReadField(info, "numMembers"))
	if expected then
		expected = math.max(0, math.floor(expected + 0.0001))
	end
	local entryPlayers = Snapshot.ReadField(entry, "players")
	if type(entryPlayers) == "table" then
		local players = entryPlayers
		local playerCount = arrayLength(players)
		return players, expected ~= nil and playerCount ~= nil
			and playerCount >= expected
	end
	if expected == nil or not resultID
		or not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo)
	then
		return nil, false
	end
	if not nativeResultStillPresent(resultID) then
		return nil, false
	end
	local players = {}
	for memberIndex = 1, expected do
		local ok, player = pcall(
			C_LFGList.GetSearchResultPlayerInfo, resultID, memberIndex)
		if ok and type(player) == "table" then
			players[#players + 1] = player
		end
	end
	return players, #players == expected
end

function Snapshot.GetCompletedEncounterCount(resultID)
	if not resultID or not (C_LFGList and C_LFGList.GetSearchResultEncounterInfo) then
		return nil
	end
	if not nativeResultStillPresent(resultID) then
		return nil
	end
	local ok, encounters = pcall(C_LFGList.GetSearchResultEncounterInfo, resultID)
	if not ok then
		return nil
	end
	if encounters == nil then
		return 0
	end
	return arrayLength(encounters)
end

function Snapshot.GetOpenSlots(info, activityInfo)
	local activity = Snapshot.ResolveActivityInfo(info, activityInfo)
	local capacity = Snapshot.ToNumber(Snapshot.ReadField(activity, "maxNumPlayers"))
	local members = Snapshot.ToNumber(Snapshot.ReadField(info, "numMembers"))
	if not capacity or capacity <= 0 or members == nil then
		return nil
	end
	return math.max(0, math.floor(capacity - members + 0.0001))
end

function Snapshot.IsAvailable(info, activityInfo)
	if type(info) ~= "table" then
		return false
	end
	local delisted, state = Snapshot.ReadField(info, "isDelisted")
	if state == "value" and delisted == true then
		return false
	end
	if not Snapshot.GetPrimaryActivityID(info) then
		return false
	end
	local activity = Snapshot.ResolveActivityInfo(info, activityInfo)
	if not activity then
		return false
	end
	local openSlots = Snapshot.GetOpenSlots(info, activity)
	return openSlots == nil or openSlots > 0
end

function Snapshot.HydrateEntry(entry, info)
	if type(entry) ~= "table" then
		return nil
	end
	info = info or entry.info
	if type(info) ~= "table" then
		return entry
	end
	local activityID = Snapshot.GetPrimaryActivityID(info)
	if not activityID then
		return entry
	end
	entry.activityID = activityID
	local categoryID, activity = Snapshot.ResolveActivityCategory(activityID)
	entry.activity = activity or Snapshot.GetActivityInfo(info, activityID)
	entry.categoryID = categoryID
		or Snapshot.ToNumber(Snapshot.ReadField(entry.activity, "categoryID"))
		or entry.categoryID
	return entry
end

function Snapshot.NewEntry(resultID, info)
	if not resultID or type(info) ~= "table" then
		return nil
	end
	return Snapshot.HydrateEntry({ resultID = resultID, info = info }, info)
end
