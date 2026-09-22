local _, GF = ...

local Snapshot = {}
GF.SearchResultSnapshot = Snapshot

local function selectedNode(node)
	if node == nil and GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		node = GF.FindGroupTab:GetSelection()
	end
	if node == nil and GF.MainFrame then node = GF.MainFrame.selection end
	return node
end

function Snapshot.IsRaidContext(node)
	node = selectedNode(node)
	return type(node) == "table" and node.categoryID == (GF.CAT_RAID or 3)
end

function Snapshot.IsSeasonRaidContext(node)
	node = selectedNode(node)
	return type(node) == "table" and node.navKind == "season_raid"
		and Snapshot.IsRaidContext(node)
end

local NIL_ACTIVITY_CONTEXT = {}
local activeActivityInfoReadCache
local displayTextProbe
local displayTextProbeString

local function clearReusableTable(values)
	values = type(values) == "table" and values or {}
	for key in pairs(values) do
		values[key] = nil
	end
	return values
end

function Snapshot.BeginActivityInfoReadPass(cache)
	if activeActivityInfoReadCache and activeActivityInfoReadCache ~= cache then
		clearReusableTable(activeActivityInfoReadCache)
	end
	cache = clearReusableTable(cache)
	activeActivityInfoReadCache = cache
	return cache
end

function Snapshot.EndActivityInfoReadPass(cache)
	cache = cache or activeActivityInfoReadCache
	if cache ~= activeActivityInfoReadCache then
		return cache
	end
	activeActivityInfoReadCache = nil
	return clearReusableTable(cache)
end

local function activityContextKey(value)
	return value == nil and NIL_ACTIVITY_CONTEXT or value
end

local function cachedActivityInfo(activityID, questID, isWarMode)
	local byActivity = activeActivityInfoReadCache
		and activeActivityInfoReadCache[activityID]
	local byQuest = byActivity and byActivity[activityContextKey(questID)]
	return byQuest and byQuest[activityContextKey(isWarMode)] or nil
end

local function rememberActivityInfo(activityID, questID, isWarMode, activity)
	local cache = activeActivityInfoReadCache
	if not (cache and type(activity) == "table") then
		return activity
	end
	local byActivity = cache[activityID]
	if not byActivity then
		byActivity = {}
		cache[activityID] = byActivity
	end
	local questKey = activityContextKey(questID)
	local byQuest = byActivity[questKey]
	if not byQuest then
		byQuest = {}
		byActivity[questKey] = byQuest
	end
	byQuest[activityContextKey(isWarMode)] = activity
	return activity
end

local function measuredProtectedRead(signal, counter, func, ...)
	local diagnostics = GF.SearchMemoryDiagnostics
	if diagnostics and diagnostics.current then
		diagnostics:Add(counter, 1)
		if diagnostics.MeasureProtectedFirst then
			return diagnostics:MeasureProtectedFirst(signal, func, ...)
		end
	end
	local ok, value = pcall(func, ...)
	return ok and value or nil, ok == true
end

local function isSecret(value)
	local compat = GF.Compat
	if compat and type(compat.IsAccessibleValue) == "function" then
		return compat.IsAccessibleValue(value) ~= true
	end
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return true
		end
	end
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

function Snapshot.ReadField(owner, key)
	local compat = GF.Compat
	if compat and type(compat.ReadAccessibleField) == "function" then
		return compat.ReadAccessibleField(owner, key)
	end
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

-- kstringLfgListSearch values are scoped to their native search result.  A
-- current-group projection survives that result source, so capture the text as
-- it is rendered while the source is still authoritative instead of retaining
-- the opaque kstring token.  Returning nil is intentional: an unreadable value
-- must become an empty safe field, never "Unknown Target" in another search.
function Snapshot.CloneRenderedDisplayText(value)
	if value == nil then
		return nil
	end
	if type(CreateFrame) ~= "function" then
		return not isSecret(value) and value or nil
	end
	if not displayTextProbe then
		displayTextProbe = CreateFrame("Frame")
		displayTextProbe:Hide()
		displayTextProbeString = displayTextProbe:CreateFontString(
			nil, "ARTWORK", "GameFontNormal")
	end
	local setOK = pcall(displayTextProbeString.SetText,
		displayTextProbeString, value)
	if not setOK then
		return nil
	end
	local getOK, rendered = pcall(
		displayTextProbeString.GetText, displayTextProbeString)
	if not getOK or rendered == nil or isSecret(rendered) then
		return nil
	end
	if type(rendered) ~= "string" and type(rendered) ~= "number" then
		return nil
	end
	local plain = tostring(rendered)
	if plain == "|Kr0|k"
		or plain == "Unknown Target"
		or plain == "未知目标"
		or plain == "未知目標"
		or plain:find("|K", 1, true)
	then
		return nil
	end
	if (_G.UNKNOWNOBJECT ~= nil and plain == _G.UNKNOWNOBJECT)
		or (_G.UNKNOWNBEING ~= nil and plain == _G.UNKNOWNBEING)
	then
		return nil
	end
	return rendered
end

function Snapshot.ToNumber(value)
	local compat = GF.Compat
	if compat and type(compat.ToAccessibleNumber) == "function" then
		return compat.ToAccessibleNumber(value)
	end
	if type(value) == "nil" or isSecret(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	return ok and number or nil
end

local function arrayLength(values)
	local compat = GF.Compat
	if compat and type(compat.GetAccessibleArrayLength) == "function" then
		return compat.GetAccessibleArrayLength(values)
	end
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

function Snapshot.GetActivityIDs(info, entry, activityIDs, seen)
	activityIDs = clearReusableTable(activityIDs)
	seen = clearReusableTable(seen)
	local complete = true
	local primary, primaryState = Snapshot.ReadField(info, "activityID")
	if primaryState == "secret" or primaryState == "error"
		or primaryState == "unavailable"
	then
		complete = false
	end
	appendActivityID(activityIDs, seen, primary)
	local values, valuesState = Snapshot.ReadField(info, "activityIDs")
	if valuesState == "secret" or valuesState == "error"
		or valuesState == "unavailable"
	then
		complete = false
	end
	local activityCount = arrayLength(values)
	if activityCount then
		for index = 1, activityCount do
			local activityID, activityState = Snapshot.ReadField(values, index)
			if activityState ~= "value" then
				complete = false
			end
			appendActivityID(activityIDs, seen, activityID)
		end
	elseif valuesState == "value" then
		complete = false
	end
	if type(entry) == "table" then
		local entryActivityID, entryState = Snapshot.ReadField(entry, "activityID")
		if entryState == "secret" or entryState == "error" then
			complete = false
		end
		appendActivityID(activityIDs, seen, entryActivityID)
	end
	return activityIDs, complete
end

function Snapshot.GetPrimaryActivityID(info)
	local primary = Snapshot.ToNumber(Snapshot.ReadField(info, "activityID"))
	if primary and primary > 0 then
		return primary
	end
	local values = Snapshot.ReadField(info, "activityIDs")
	local activityCount = arrayLength(values)
	if activityCount then
		for index = 1, activityCount do
			local activityID = Snapshot.ToNumber(Snapshot.ReadField(values, index))
			if activityID and activityID > 0 then
				return activityID
			end
		end
	end
	return nil
end

function Snapshot.GetSearchResultInfo(resultID)
	if not resultID or not (C_LFGList and C_LFGList.GetSearchResultInfo) then
		return nil
	end
	local diagnostics = GF.SearchMemoryDiagnostics
	if diagnostics and diagnostics.current then
		diagnostics:Add("resultInfoReads", 1)
	end
	local info = measuredProtectedRead(
		"snapshotResultInfoReads",
		"snapshotResultInfoReads",
		C_LFGList.GetSearchResultInfo,
		resultID)
	if type(info) ~= "table" then
		return nil
	end
	return Snapshot.SanitizeCensoredContent(info)
end

function Snapshot.IsCensored(info)
	local censored, state = Snapshot.ReadField(info, "censored")
	return state == "value" and censored == true
end

function Snapshot.SanitizeCensoredContent(info)
	if type(info) ~= "table" or not Snapshot.IsCensored(info) then
		return info
	end
	-- Once Blizzard marks a result as censored, content fields from an older
	-- readable snapshot must not survive anywhere in the addon's cache graph.
	for _, key in ipairs({ "name", "comment", "voiceChat" }) do
		pcall(rawset, info, key, nil)
	end
	return info
end

-- GetSearchResultInfo includes detailed dungeon-score collections that the
-- background filter/sort cache does not consume. Keep a small projection
-- between refreshes; visible rows still hydrate from the authoritative API.
local SUMMARY_FIELDS = {
	"activityID",
	"leaderName",
	"name",
	"comment",
	"voiceChat",
	"censored",
	"requiredItemLevel",
	"requiredHonorLevel",
	"requiredDungeonScore",
	"requiredPvpRating",
	"hasSelf",
	"numMembers",
	"numBNetFriends",
	"numCharFriends",
	"numGuildMates",
	"isDelisted",
	"isWarMode",
	"age",
	"questID",
	"leaderOverallDungeonScore",
	"generalPlaystyle",
	"crossFactionListing",
	"leaderFactionGroup",
	"partyGUID",
	-- Compatibility/derived fields consumed by existing identity and tooltip
	-- paths even though they are not part of the generated Retail structure.
	"maxMembers",
	"isGuildListing",
	"isFriendListing",
	"_gfSocialFriendsChecked",
	"_gfSoftUnavailable",
}

local function copyOpaqueField(target, source, key)
	local ok, value = pcall(rawget, source, key)
	if ok then
		pcall(rawset, target, key, value)
	end
end

function Snapshot.IsCompactSearchResultInfo(info)
	return type(info) == "table" and info._gfCompactSearchResultInfo == true
end

local function copyFirstArrayRecord(target, source, key)
	local ok, values = pcall(rawget, source, key)
	if not ok or type(values) ~= "table" then
		return
	end
	local firstOK, first = pcall(rawget, values, 1)
	if firstOK and first ~= nil then
		target[key] = { first }
	end
end

function Snapshot.CompactSearchResultInfo(info, keepTooltipDetails)
	if type(info) ~= "table" then
		return info
	end
	if Snapshot.IsCompactSearchResultInfo(info) then
		return Snapshot.SanitizeCensoredContent(info)
	end
	local summary = { _gfCompactSearchResultInfo = true }
	if keepTooltipDetails then
		summary._gfCompactTooltipDetails = true
	end
	for _, key in ipairs(SUMMARY_FIELDS) do
		copyOpaqueField(summary, info, key)
	end
	-- Activity IDs are already minimal. Rating/run collections retain only the
	-- first record consumed by the list and tooltip.
	copyOpaqueField(summary, info, "activityIDs")
	copyFirstArrayRecord(summary, info, "leaderPvpRatingInfo")
	if keepTooltipDetails then
		copyFirstArrayRecord(summary, info, "leaderDungeonScoreInfo")
		copyOpaqueField(summary, info, "leaderBestDungeonScoreInfo")
	end
	return Snapshot.SanitizeCensoredContent(summary)
end

-- Current-group projection owns a session-local copy that must not alias the
-- active search cache.  The ordinary compact helper intentionally reuses an
-- already compact table, so provide an explicit cloning boundary for owners
-- whose lifetime is independent from the current native search scope.
function Snapshot.CloneCompactSearchResultInfo(info, keepTooltipDetails)
	if type(info) ~= "table" then
		return nil
	end
	local summary = {
		_gfCompactSearchResultInfo = true,
	}
	if keepTooltipDetails then
		summary._gfCompactTooltipDetails = true
	end
	for _, key in ipairs(SUMMARY_FIELDS) do
		copyOpaqueField(summary, info, key)
	end
	local activityIDs = Snapshot.GetActivityIDs(info)
	if #activityIDs > 0 then
		summary.activityIDs = activityIDs
	end
	copyFirstArrayRecord(summary, info, "leaderPvpRatingInfo")
	if keepTooltipDetails then
		copyFirstArrayRecord(summary, info, "leaderDungeonScoreInfo")
		copyOpaqueField(summary, info, "leaderBestDungeonScoreInfo")
	end
	return Snapshot.SanitizeCensoredContent(summary)
end

function Snapshot.GetActivityInfo(info, activityID)
	activityID = Snapshot.ToNumber(activityID)
	if not activityID or not (C_LFGList and C_LFGList.GetActivityInfoTable) then
		return nil
	end
	local questID = Snapshot.ReadField(info, "questID")
	local isWarMode = Snapshot.ReadField(info, "isWarMode")
	local cached = cachedActivityInfo(activityID, questID, isWarMode)
	if cached then
		return cached
	end
	local activity = measuredProtectedRead(
		"activityInfo",
		"activityInfoReads",
		C_LFGList.GetActivityInfoTable,
		activityID,
		questID,
		isWarMode)
	if type(activity) ~= "table" then
		return nil
	end
	return rememberActivityInfo(activityID, questID, isWarMode, activity)
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
	local counts = measuredProtectedRead(
		"snapshotMemberCounts",
		"snapshotMemberCountReads",
		C_LFGList.GetSearchResultMemberCounts,
		resultID)
	if type(counts) ~= "table" then
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

function Snapshot.GetPlayers(resultID, info, entry, playerBuffer)
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
	local players = clearReusableTable(playerBuffer)
	for memberIndex = 1, expected do
		local player = measuredProtectedRead(
			"playerInfo",
			"playerInfoReads",
			C_LFGList.GetSearchResultPlayerInfo,
			resultID,
			memberIndex)
		if type(player) == "table" then
			players[#players + 1] = player
		end
	end
	return players, #players == expected
end

local function readCompletedEncounters(resultID)
	if not resultID or not (C_LFGList and C_LFGList.GetSearchResultEncounterInfo) then
		return nil
	end
	if not nativeResultStillPresent(resultID) then
		return nil
	end
	local encounters, readable = measuredProtectedRead(
		"encounterInfo",
		"encounterInfoReads",
		C_LFGList.GetSearchResultEncounterInfo,
		resultID)
	if not readable then
		return nil
	end
	if isSecret(encounters) then return nil end
	if encounters == nil then
		return nil, 0
	end
	return encounters, arrayLength(encounters)
end

function Snapshot.GetCompletedEncounterCount(resultID)
	local _, count = readCompletedEncounters(resultID)
	return count
end

function Snapshot.GetCompletedEncounters(resultID)
	local encounters, count = readCompletedEncounters(resultID)
	if not count or count < 0 or count > 64 or count ~= math.floor(count) then
		return nil
	end
	local names, seen = {}, {}
	for index = 1, count do
		local name = Snapshot.ReadField(encounters, index)
		if isSecret(name) or type(name) ~= "string" or name == "" or seen[name] then
			return nil
		end
		names[index], seen[name] = name, true
	end
	return names
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
