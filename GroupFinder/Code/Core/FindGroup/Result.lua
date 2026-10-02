local _, GF = ...

local Result = {}
GF.Result = Result

local Snapshot = GF.SearchResultSnapshot
local Repository = assert(GF.ResultRepository,
	"ResultRepository must load before Result")
Repository:AttachFacade(Result)
local UNKNOWN_TITLE = "?"
local SOFT_UNAVAILABLE = "unavailable"
local SORT_TIER_CURRENT = 1
local SORT_TIER_APPLICATION = 2
local SORT_TIER_STARRED = 3
local SORT_TIER_SOCIAL = 4
local SORT_TIER_ORDINARY = 5
local SORT_TIER_UNAVAILABLE = 6

local function repositoryFor(owner)
	return Repository
end

local function shouldRetainExpiredGroups()
	local decision = GF.ShouldRetainExpiredGroups
	if type(decision) ~= "function" then
		return true
	end
	local ok, retain = pcall(decision)
	return not ok or retain ~= false
end

local function shouldPreserveApplicationResult(owner, resultID, info)
	if info and GF.IsCurrentGroupSearchResult
		and GF.IsCurrentGroupSearchResult(info, resultID) == true
	then
		return true
	end
	local entry = owner and owner.entryCache and owner.entryCache[resultID]
	if entry and (entry._gfRetainedCurrent == true
		or entry._gfRetainedDecline == true
		or entry._gfJoinedApplicationSupplement == true)
	then
		return true
	end
	local panel = GF.BrowsePanel
	if panel and panel.HasAutomaticResultOrderLockFor
		and panel:HasAutomaticResultOrderLockFor(
			resultID, "terminal_application") == true
	then
		return true
	end
	local apply = GF.Apply
	local state = apply and apply.GetApplicationState
		and apply:GetApplicationState(resultID, info)
	return state and state.isApplication == true
		and state.isActiveApp ~= true or false
end

function Result:GetRepository()
	return repositoryFor(self)
end

-- Search-result fields can become unavailable after the native result set
-- changes. All reads that may cross that boundary are kept behind these
-- helpers so aggregate snapshots never accidentally consult a newer search.
local function callFirst(callback, ...)
	if type(callback) ~= "function" then
		return nil
	end
	local succeeded, value = pcall(callback, ...)
	if succeeded then
		return value
	end
	return nil
end

local function clearReusableTable(values)
	values = type(values) == "table" and values or {}
	for key in pairs(values) do
		values[key] = nil
	end
	return values
end

local function copySequence(source, target)
	local copy = clearReusableTable(target)
	for position, value in ipairs(source or {}) do
		copy[position] = value
	end
	return copy
end

local function sequenceRetainLimit()
	return math.max(1, math.floor(
		tonumber(GF.SEARCH_SCRATCH_RETAIN_LIMIT) or 512))
end

local function resetSequenceBuffer(values)
	if type(values) ~= "table" then
		return {}
	end
	if #values > sequenceRetainLimit() then
		return {}
	end
	return clearReusableTable(values)
end

local function acquireSequenceBuffer(
	owner, buffersKey, indexKey, avoidFirst, avoidSecond)
	local buffers = owner[buffersKey]
	if type(buffers) ~= "table" then
		buffers = { {}, {} }
		owner[buffersKey] = buffers
	end
	local index = owner[indexKey] == 1 and 2 or 1
	local buffer = buffers[index]
	if buffer == avoidFirst or buffer == avoidSecond then
		index = index == 1 and 2 or 1
		buffer = buffers[index]
	end
	if buffer == avoidFirst or buffer == avoidSecond then
		buffer = {}
		buffers[index] = buffer
	end
	buffer = resetSequenceBuffer(buffer)
	buffers[index] = buffer
	owner[indexKey] = index
	return buffer
end

local function clearInactiveSequenceBuffers(
	owner, buffersKey, keepFirst, keepSecond, keepThird)
	local buffers = owner[buffersKey]
	if type(buffers) ~= "table" then
		return
	end
	for index, buffer in ipairs(buffers) do
		if buffer ~= keepFirst and buffer ~= keepSecond
			and buffer ~= keepThird
		then
			buffers[index] = resetSequenceBuffer(buffer)
		end
	end
end

local function nativeResultInfo(resultID, diagnosticField)
	if not (resultID and C_LFGList) then
		return nil
	end
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
		GF.SearchMemoryDiagnostics:Add("resultInfoReads", 1)
		if diagnosticField then
			GF.SearchMemoryDiagnostics:Add(diagnosticField, 1)
		end
	end
	local info
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current
		and GF.SearchMemoryDiagnostics.MeasureFirstReturn
	then
		info = GF.SearchMemoryDiagnostics:MeasureFirstReturn(
			diagnosticField or "otherResultInfoReads",
			callFirst,
			C_LFGList.GetSearchResultInfo,
			resultID)
	else
		info = callFirst(C_LFGList.GetSearchResultInfo, resultID)
	end
	if Snapshot and Snapshot.SanitizeCensoredContent then
		info = Snapshot.SanitizeCensoredContent(info)
	end
	return info
end

local function nativePlayerInfo(resultID, memberIndex)
	local getter = C_LFGList and C_LFGList.GetSearchResultPlayerInfo
	if not (resultID and type(getter) == "function") then
		return nil
	end
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
		GF.SearchMemoryDiagnostics:Add("playerInfoReads", 1)
		if GF.SearchMemoryDiagnostics.MeasureFirstReturn then
			return GF.SearchMemoryDiagnostics:MeasureFirstReturn(
				"playerInfo", callFirst, getter, resultID, memberIndex)
		end
	end
	return callFirst(getter, resultID, memberIndex)
end

local function isCensoredInfo(info)
	return Snapshot and Snapshot.IsCensored
		and Snapshot.IsCensored(info) == true
end

local function sanitizeCensoredInfo(info)
	if Snapshot and Snapshot.SanitizeCensoredContent then
		return Snapshot.SanitizeCensoredContent(info)
	end
	return info
end

local function snapshotField(owner, key)
	if Snapshot and type(Snapshot.ReadField) == "function" then
		return Snapshot.ReadField(owner, key)
	end
	if type(owner) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	return ok and value or nil
end

local function snapshotNumber(owner, key)
	local value = key ~= nil and snapshotField(owner, key) or owner
	if Snapshot and type(Snapshot.ToNumber) == "function" then
		return Snapshot.ToNumber(value)
	end
	local ok, number = pcall(tonumber, value)
	return ok and type(number) == "number" and number or nil
end

local function snapshotTrue(owner, key)
	return snapshotField(owner, key) == true
end

local function nativeHasResult(resultID)
	if not resultID then
		return false
	end
	if not (C_LFGList and C_LFGList.HasSearchResultInfo) then
		return true
	end
	return callFirst(C_LFGList.HasSearchResultInfo, resultID) == true
end

local function removeCachedRecord(owner, resultID)
	local repository = repositoryFor(owner)
	repository:RemoveCachedRecord(resultID)
end

local function scrubCachedCensoredContent(owner, resultID)
	local repository = repositoryFor(owner)
	repository:ScrubCensoredResult(resultID)
end

local function rememberSummary(owner, resultID, info)
	local repository = repositoryFor(owner)
	return repository:RememberSummary(resultID, info)
end

-- Text policy --------------------------------------------------------------

local REDACTED_KSTRING = "|Kr0|k"
local UNKNOWN_LABELS = {
	["Unknown Target"] = true,
	["未知目标"] = true,
	["未知目標"] = true,
}
local textProbe
local textProbeString

local function secretValue(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local succeeded, secret = pcall(issecretvalue, value)
	return succeeded and secret == true
end

local function printableValue(value)
	local valueType = type(value)
	if valueType ~= "string" and valueType ~= "number" then
		return nil
	end
	local plain = tostring(value)
	plain = plain:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	if type(strtrim) == "function" then
		plain = strtrim(plain)
	end
	return plain
end

local function plainlyUnreadable(value)
	if value == nil or secretValue(value) then
		return true
	end
	local plain = printableValue(value)
	if not plain or plain == "" or plain == UNKNOWN_TITLE or plain == REDACTED_KSTRING then
		return true
	end
	if UNKNOWN_LABELS[plain] then
		return true
	end
	return (_G.UNKNOWNOBJECT ~= nil and plain == _G.UNKNOWNOBJECT)
		or (_G.UNKNOWNBEING ~= nil and plain == _G.UNKNOWNBEING)
end

local function renderedKString(value)
	if type(value) ~= "string" or not value:find("|K", 1, true) then
		return value
	end
	if type(CreateFrame) ~= "function" then
		return value
	end
	if not textProbe then
		textProbe = CreateFrame("Frame")
		textProbe:Hide()
		textProbeString = textProbe:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	end
	textProbeString:SetText(value)
	return textProbeString:GetText()
end

local function renderingIsUnreadable(value)
	if secretValue(value) then
		return true
	end
	local rendered = renderedKString(value)
	if rendered == value then
		return false
	end
	return plainlyUnreadable(rendered)
end

local function unreadableText(value)
	return plainlyUnreadable(value) or renderingIsUnreadable(value)
end

local function displayableText(value)
	return not unreadableText(value)
end

local function opaqueKString(value)
	return not secretValue(value)
		and type(value) == "string"
		and value:find("|K", 1, true) ~= nil
end

local function commentRank(value)
	if secretValue(value) then
		return 1
	end
	return displayableText(value) and 2 or 0
end

local function mergeStableText(older, newer)
	if not newer then
		return sanitizeCensoredInfo(older)
	end
	if not older then
		return sanitizeCensoredInfo(newer)
	end
	older = sanitizeCensoredInfo(older)
	newer = sanitizeCensoredInfo(newer)
	if isCensoredInfo(newer) then
		-- Leader identity is not censored listing content and remains useful for
		-- whisper/report/block actions. Never restore title, comment, or voice.
		if displayableText(older.leaderName)
			and not displayableText(newer.leaderName)
		then
			newer.leaderName = older.leaderName
		end
		return newer
	end
	if displayableText(older.name) and not displayableText(newer.name) then
		newer.name = older.name
	end
	if displayableText(older.leaderName) and not displayableText(newer.leaderName) then
		newer.leaderName = older.leaderName
	end
	if commentRank(older.comment) > commentRank(newer.comment) then
		newer.comment = older.comment
	end
	return newer
end

function Result:IsSecretLfgText(value)
	return secretValue(value)
end

function Result:IsRenderedUnreadableLfgText(value)
	return renderingIsUnreadable(value)
end

function Result:HasRenderableListingComment(value)
	return commentRank(value) ~= 0
end

function Result:IsUnreadableLfgText(value)
	return unreadableText(value)
end

function Result:IsDisplayableLfgSearchText(value)
	return displayableText(value)
end

function Result:IsCensoredSearchResult(info)
	return isCensoredInfo(info)
end

-- Activity and availability ------------------------------------------------

local function primaryActivity(info)
	return Snapshot.GetPrimaryActivityID(info)
end

local function activityFor(info, activityID)
	return Snapshot.GetActivityInfo(info, activityID)
end

local function resolvedActivity(info, supplied)
	return Snapshot.ResolveActivityInfo(info, supplied)
end

local function hydrateActivity(entry, info)
	return Snapshot.HydrateEntry(entry, info)
end

local function baseInvalidReason(info, suppliedActivity)
	if not info then
		return "missing"
	end
	if not primaryActivity(info) then
		return "missing_activity"
	end
	local activity = resolvedActivity(info, suppliedActivity)
	if not activity then
		return "missing_activity_info"
	end
	local capacity = snapshotNumber(activity, "maxNumPlayers") or 0
	local members = snapshotNumber(info, "numMembers")
	if snapshotTrue(info, "isDelisted")
		or (members ~= nil and capacity > 0 and members >= capacity)
	then
		return SOFT_UNAVAILABLE
	end
	return nil
end

function Result:IsLiveSearchResultInfoAuthoritative(resultID)
	if not (resultID and C_LFGList and C_LFGList.GetSearchResultInfo) then
		return false
	end
	return not self._usingAggregatedResults or nativeHasResult(resultID)
end

function Result:GetCachedSearchResultInfo(resultID)
	if not resultID then
		return nil
	end
	local repository = repositoryFor(self)
	return repository:GetCachedInfo(resultID)
end

function Result:GetAuthoritativeSearchResultInfo(resultID)
	local cached = self:GetCachedSearchResultInfo(resultID)
	if not self:IsLiveSearchResultInfoAuthoritative(resultID) then
		return cached
	end
	local refreshInfo = self._refreshInfoByID
		and self._refreshInfoByID[resultID]
	if refreshInfo and cached == refreshInfo then
		return cached
	end
	local current = nativeResultInfo(
		resultID, "authoritativeResultInfoReads")
	if isCensoredInfo(current) then
		scrubCachedCensoredContent(self, resultID)
		cached = self:GetCachedSearchResultInfo(resultID)
	end
	if current and cached then
		return mergeStableText(cached, current)
	end
	return current or cached
end

function Result:GetLiveSearchResultInfoForUpdate(resultID)
	if self:IsLiveSearchResultInfoAuthoritative(resultID) then
		local info = nativeResultInfo(resultID, "liveResultInfoReads")
		if isCensoredInfo(info) then
			scrubCachedCensoredContent(self, resultID)
		end
		return info
	end
	return nil, "not_current"
end

local function questTitle(questID)
	questID = tonumber(questID)
	if not questID or questID <= 0 then
		return nil
	end
	local name
	if type(QuestUtils_GetQuestName) == "function" then
		name = QuestUtils_GetQuestName(questID)
	end
	if unreadableText(name) and C_QuestLog and C_QuestLog.GetTitleForQuestID then
		name = C_QuestLog.GetTitleForQuestID(questID)
	end
	if unreadableText(name) then
		return nil
	end
	return name
end

local function titleInsideComment(value)
	if secretValue(value) or not value or value == "" then
		return nil
	end
	local inside = value:match("%[(.-)%]")
	if inside and inside ~= "" and displayableText(inside) then
		return inside
	end
	return nil
end

function Result:GetListingComment(info, resultID)
	if not info then
		return ""
	end
	if isCensoredInfo(info) then
		sanitizeCensoredInfo(info)
		return ""
	end
	if secretValue(info.comment) then
		return info.comment
	end

	local value = info.comment or ""
	local needsReplacement = value ~= "" and unreadableText(value)
	if needsReplacement then
		value = ""
		local latest = resultID and self:GetAuthoritativeSearchResultInfo(resultID)
		if latest then
			info.questID = info.questID or latest.questID
			if displayableText(latest.name) and not displayableText(info.name) then
				info.name = latest.name
			end
			if secretValue(latest.comment) then
				info.comment = latest.comment
				return latest.comment
			end
			if displayableText(latest.comment) then
				info.comment = latest.comment
				value = latest.comment
			end
		end
	end

	if value == "" and info.questID and type(LFGListUtil_GetQuestDescription) == "function" then
		value = LFGListUtil_GetQuestDescription(info.questID) or ""
		if unreadableText(value) then
			value = ""
		end
	end

	if info.questID and value ~= "" and value:match("%[%s*%]") then
		local name = questTitle(info.questID)
		if displayableText(name) then
			local formatString = AUTO_GROUP_CREATION_NORMAL_QUEST
			if type(QuestUtils_IsQuestWorldQuest) == "function"
				and QuestUtils_IsQuestWorldQuest(info.questID)
			then
				formatString = AUTO_GROUP_CREATION_WORLD_QUEST or formatString
			end
			if formatString and displayableText(name) then
				value = string.format(formatString, name)
			end
		end
	end
	return value
end

function Result:GetListingTitle(info, resultID)
	if not info then
		return UNKNOWN_TITLE
	end
	if isCensoredInfo(info) then
		sanitizeCensoredInfo(info)
		local locale = GF.L or {}
		return locale.CENSORED_RESULT_REVEAL or "点击查看"
	end
	if displayableText(info.name) then
		return info.name
	end
	local latest = resultID and self:GetAuthoritativeSearchResultInfo(resultID)
	if latest then
		info.questID = info.questID or latest.questID
		if displayableText(latest.name) then
			info.name = latest.name
			return latest.name
		end
		local latestQuestTitle = questTitle(latest.questID or info.questID)
		if latestQuestTitle then
			info.name = latestQuestTitle
			return latestQuestTitle
		end
	end
	return questTitle(info.questID)
		or titleInsideComment(self:GetListingComment(info, resultID))
		or UNKNOWN_TITLE
end

function Result:IsDirtySearchResult(resultID, info)
	if isCensoredInfo(info) then
		sanitizeCensoredInfo(info)
		return false
	end
	if not info or displayableText(info.name) then
		return false
	end
	local replacement = self:GetListingTitle(info, resultID)
	if replacement and displayableText(replacement) then
		info.name = replacement
		return false
	end
	return true
end

function Result:GetSearchResultInvalidReason(resultID, info, activityInfo)
	info = sanitizeCensoredInfo(info)
	local reason = baseInvalidReason(info, activityInfo)
	local identityPending = GF.Search
		and GF.Search.IsAggregatedResultIdentityPending
		and GF.Search:IsAggregatedResultIdentityPending(resultID)
	if identityPending and (reason == "missing"
		or reason == "missing_activity"
		or reason == "missing_activity_info")
	then
		-- A 12.1 protected payload can become readable on a later result event.
		-- The single native category request already authorizes this aggregate ID,
		-- so missing identity/display fields remain fail-open until revalidated.
		return nil
	end
	if reason and reason ~= SOFT_UNAVAILABLE then
		return reason
	end
	if reason == SOFT_UNAVAILABLE
		and GF.IsCurrentGroupSearchResult
		and GF.IsCurrentGroupSearchResult(info, resultID)
	then
		reason = nil
	end
	if not isCensoredInfo(info) and info and opaqueKString(info.name)
		and not self:IsLiveSearchResultInfoAuthoritative(resultID)
	then
		return "dirty"
	end
	if not isCensoredInfo(info) and self:IsDirtySearchResult(resultID, info) then
		return "dirty"
	end
	return reason
end

function Result:IsSearchResultAvailable(resultID, info, activityInfo)
	return self:GetSearchResultInvalidReason(resultID, info, activityInfo) == nil
end

function Result:ShouldSoftUnavailableResult(resultID, info, activityInfo)
	return self:GetSearchResultInvalidReason(resultID, info, activityInfo) == SOFT_UNAVAILABLE
end

function Result:ShouldHideUnavailableResult(resultID, info, activityInfo)
	return self:GetSearchResultInvalidReason(resultID, info, activityInfo) ~= nil
end

function Result:ShouldHideDelisted(info)
	if not info then
		return nil
	end
	return snapshotTrue(info, "isDelisted")
end

function Result:ShouldRetainExpiredGroups()
	return shouldRetainExpiredGroups()
end

function Result:ShouldPreserveExpiredResult(resultID, info)
	return shouldPreserveApplicationResult(self, resultID, info)
end

function Result:ShouldRetainExpiredResult(resultID, info)
	return shouldRetainExpiredGroups()
		or self:ShouldPreserveExpiredResult(resultID, info)
end

function Result:IsSoftUnavailable(info)
	if not info then
		return nil
	end
	return snapshotTrue(info, "_gfSoftUnavailable")
		or snapshotTrue(info, "isDelisted")
end

-- Raid progress and ratings ------------------------------------------------

local function positiveInteger(value)
	return value and value > 0 and value < math.huge and value == math.floor(value)
end

function Result:IsRaidProgressContext()
	return Snapshot.IsSeasonRaidContext and Snapshot.IsSeasonRaidContext() == true
end

function Result:GetRaidProgress(resultID, info, activityInfo, liveOnly)
	local activity = resolvedActivity(info, activityInfo)
	if snapshotNumber(activity, "categoryID") ~= (GF.CAT_RAID or 3) then
		return nil, nil
	end
	local mapID = snapshotNumber(activity, "mapID")
	local difficultyID = snapshotNumber(activity, "difficultyID")
	if not positiveInteger(mapID) or not positiveInteger(difficultyID) then
		return nil, nil
	end
	local key = tostring(mapID) .. ":" .. tostring(difficultyID)
	self._raidEncounterTotals = self._raidEncounterTotals or {}
	local totalRecord = self._raidEncounterTotals[key]
	if not totalRecord or not totalRecord.total then
		local recovering = totalRecord ~= nil
		local catalog = GF.InstanceGatewayService
		local encounters, retryDelay
		if catalog and catalog.GetEncounterCatalog then
			encounters, retryDelay = catalog:GetEncounterCatalog(mapID, difficultyID)
		end
		local total = encounters and #encounters or nil
		if not positiveInteger(total) or total > 64 then total = nil end
		totalRecord = totalRecord or {}
		totalRecord.total, totalRecord.encounters = total, total and encounters or nil
		self._raidEncounterTotals[key] = totalRecord
		-- The service owns session metadata and retry backoff; this repository
		-- only retains a detached catalog for the current result projection.
		local tab = GF.FindGroupTab
		if tab and tab.RequestRaidProgressRefresh and (total and recovering or not total and retryDelay) then
			tab:RequestRaidProgressRefresh(total and 0 or retryDelay)
		end
	end
	local total = totalRecord.total
	resultID = snapshotNumber(resultID)
	if not positiveInteger(resultID) then return nil, total, totalRecord.encounters end
	self._raidProgressByID = self._raidProgressByID or {}
	local progress = not liveOnly and self._raidProgressByID[resultID] or nil
	if progress and progress.key ~= key then progress = nil end
	if not progress and self:IsLiveSearchResultInfoAuthoritative(resultID)
		and Snapshot.GetCompletedEncounters then
		local completed = Snapshot.GetCompletedEncounters(resultID)
		if completed then
			progress = { key = key, killed = #completed, completed = completed }
			if not liveOnly then self._raidProgressByID[resultID] = progress end
		end
	end
	local killed = progress and progress.killed
	if killed and total and killed > total then return nil, total, totalRecord.encounters end
	return killed, total, totalRecord.encounters, progress and progress.completed
end

function Result:GetRaidProgressDetails(resultID, info, activityInfo, liveOnly)
	local killed, total, encounters, completed = self:GetRaidProgress(resultID, info, activityInfo, liveOnly)
	local bosses, names, defeated = {}, {}, {}
	for _, encounter in ipairs(encounters or {}) do
		names[encounter.name] = (names[encounter.name] or 0) + 1
	end
	local matched = completed ~= nil
	for _, name in ipairs(completed or {}) do
		defeated[name] = true
		if names[name] ~= 1 then matched = false end
	end
	for _, encounter in ipairs(encounters or {}) do
		local state
		if names[encounter.name] == 1 and defeated[encounter.name] then
			state = true
		elseif matched then
			state = false
		end
		bosses[#bosses + 1] = { name = encounter.name, defeated = state }
	end
	return { killed = killed, total = total, bosses = bosses }
end

local SCORE_BANDS = {
	{ threshold = 2500, rgb = { r = 1, g = 0.5, b = 0 } },
	{ threshold = 2000, rgb = { r = 0.64, g = 0.21, b = 0.93 } },
	{ threshold = 1500, rgb = { r = 0, g = 0.44, b = 0.87 } },
	{ threshold = 1000, rgb = { r = 0.12, g = 1, b = 0.12 } },
}

function Result:GetDungeonScoreColor(score, delistedColor)
	if delistedColor then
		return delistedColor
	end
	local numericScore = snapshotNumber(score) or 0
	for _, band in ipairs(SCORE_BANDS) do
		if numericScore >= band.threshold then
			return band.rgb
		end
	end
	return HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
end

local function pvpRatingRecord(info, activityInfo)
	local activity = resolvedActivity(info, activityInfo)
	if not snapshotTrue(activity, "isRatedPvpActivity") then
		return nil
	end
	local candidate = snapshotField(info, "leaderPvpRatingInfo")
	candidate = snapshotField(candidate, 1)
	local rating = snapshotNumber(candidate, "rating")
	if candidate and rating and rating >= 0 then
		return candidate
	end
	return nil
end

function Result:GetLeaderPvpRatingInfo(info, activityInfo)
	local rating = pvpRatingRecord(info, activityInfo)
	if not rating then
		return nil
	end
	local tier = ""
	if PVPUtil and PVPUtil.GetTierName then
		tier = PVPUtil.GetTierName(snapshotField(rating, "tier"))
	end
	return rating, tier
end

function Result:GetLeaderPvpRatingTooltipLine(info, activityInfo)
	local rating, tier = self:GetLeaderPvpRatingInfo(info, activityInfo)
	if not (rating and PVP_RATING_GROUP_FINDER) then
		return nil
	end
	return PVP_RATING_GROUP_FINDER:format(
		snapshotField(rating, "activityName") or "",
		snapshotNumber(rating, "rating") or 0,
		tier)
end

local function browseScore(info, activityInfo)
	if not info then
		return nil, "none"
	end
	local rating = pvpRatingRecord(info, activityInfo)
	if rating then
		return snapshotNumber(rating, "rating"), "pvp"
	end
	local activity = resolvedActivity(info, activityInfo)
	if snapshotTrue(activity, "isPvpActivity") then
		return nil, "pvp"
	end
	local score = snapshotNumber(info, "leaderOverallDungeonScore")
	if score and score > 0 then
		return score, "dungeon"
	end
	return nil, "none"
end

function Result:GetBrowseScoreSortKey(info, activityInfo)
	local amount, kind = browseScore(info, activityInfo)
	if kind == "pvp" or kind == "dungeon" then
		return amount or 0
	end
	return 0
end

function Result:GetBrowseScoreDisplay(info, activityInfo, unavailableColor)
	local amount, kind = browseScore(info, activityInfo)
	if not amount then
		return nil, nil
	end
	if kind == "pvp" then
		local color = unavailableColor
			or (GF.GetPvpRatingColor and GF.GetPvpRatingColor(amount))
		return tostring(amount), color
	end
	if kind == "dungeon" then
		return tostring(amount), self:GetDungeonScoreColor(amount, unavailableColor)
	end
	return nil, nil
end

-- Entry hydration ----------------------------------------------------------

local function resetDisplayCounts(entry)
	if not entry then
		return
	end
	entry._displayCounts = nil
	entry._displayCountsLoaded = nil
end

local function resetBlockedIdentity(entry)
	if not entry then
		return
	end
	entry._blockedMemberChecked = nil
	entry._blockedMemberRevision = nil
	entry._blockedMember = nil
	entry._blockedMemberRow = nil
	entry.hasBlockedMember = nil
end

local MEMBER_COUNT_FIELDS = {
	TANK = "tanks",
	HEALER = "heals",
	DAMAGER = "dps",
}
local MEMBER_ENTRY_FIELDS = { "tanks", "heals", "dps" }

local function storeMemberCounts(entry, counts)
	if not entry or type(counts) ~= "table" then
		return
	end
	entry._displayCounts = counts
	entry._displayCountsLoaded = true
	for nativeRole, entryField in pairs(MEMBER_COUNT_FIELDS) do
		entry[entryField] = counts[nativeRole] or entry[entryField] or 0
	end
	entry._memberCountsLoaded = true
end

function Result:GetDisplayMemberCounts(entry)
	if not (entry and entry.resultID) then
		return nil
	end
	if entry._displayCountsLoaded and entry._displayCounts then
		return entry._displayCounts
	end
	local resultID = entry.resultID
	local counts = self._refreshMemberCountsByID
		and self._refreshMemberCountsByID[resultID]
	if type(counts) ~= "table" then
		counts = self._aggregateMemberCountsByID
			and self._aggregateMemberCountsByID[resultID]
	end
	if type(counts) ~= "table"
		and C_LFGList and C_LFGList.GetSearchResultMemberCounts
	then
		if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
			GF.SearchMemoryDiagnostics:Add("resultMemberCountReads", 1)
		end
		if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current
			and GF.SearchMemoryDiagnostics.MeasureFirstReturn
		then
			counts = GF.SearchMemoryDiagnostics:MeasureFirstReturn(
				"memberCounts",
				callFirst,
				C_LFGList.GetSearchResultMemberCounts,
				resultID)
		else
			counts = callFirst(C_LFGList.GetSearchResultMemberCounts, resultID)
		end
		if type(counts) == "table" and self._refreshMemberCountsByID then
			self._refreshMemberCountsByID[resultID] = counts
		end
	end
	if type(counts) == "table" then
		storeMemberCounts(entry, counts)
	end
	return entry._displayCounts
end

local function populateCountDefaults(entry)
	if not entry then
		return
	end
	Result:GetDisplayMemberCounts(entry)
	for _, field in ipairs(MEMBER_ENTRY_FIELDS) do
		if entry[field] == nil then
			entry[field] = 0
		end
	end
end

local function playersFor(resultID, count)
	local players = {}
	local leaverFound = false
	if not (resultID and C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then
		return players, leaverFound
	end
	for memberIndex = 1, snapshotNumber(count) or 0 do
		local player = nativePlayerInfo(resultID, memberIndex)
		if player then
			players[#players + 1] = player
			leaverFound = leaverFound or snapshotTrue(player, "isLeaver")
		end
	end
	return players, leaverFound
end

local function leaderFor(resultID, count)
	if not resultID then
		return nil
	end
	local memberCount = snapshotNumber(count)
	if not memberCount or memberCount <= 0 then
		local current = Result:GetAuthoritativeSearchResultInfo(resultID)
		memberCount = snapshotNumber(current, "numMembers") or 0
	end
	local firstNamed
	for memberIndex = 1, memberCount do
		local player = nativePlayerInfo(resultID, memberIndex)
		if player then
			if snapshotTrue(player, "isLeader") then
				return player
			end
			local playerName = snapshotField(player, "name")
			if memberIndex == 1 and type(playerName) == "string"
				and playerName ~= ""
			then
				firstNamed = player
			end
		end
	end
	return firstNamed
end

local function updateLeaderName(info, leader)
	local leaderName = snapshotField(leader, "name")
	local existing = snapshotField(info, "leaderName")
	if info and type(leaderName) == "string" and leaderName ~= ""
		and (existing == nil or existing == "")
	then
		info.leaderName = leaderName
	end
end

function Result:EnsureMemberCounts(entry)
	populateCountDefaults(entry)
end

-- Sorting ------------------------------------------------------------------

function Result:GetActivitySortKey(info)
	local activityID = primaryActivity(info)
	if not activityID then
		return ""
	end
	local details = activityFor(info, activityID)
	local label = snapshotField(details, "fullName")
		or snapshotField(details, "shortName")
	if label and label ~= "" then
		return label
	end
	if C_LFGList and C_LFGList.GetActivityFullName then
		return C_LFGList.GetActivityFullName(activityID) or ""
	end
	return tostring(activityID)
end

local function currentSortSpec()
	local columns = GF.ListColumns
	if columns and columns.GetBrowseSort then
		return columns:GetBrowseSort()
	end
	return { column = "title", asc = true }
end

local function readInfoField(info, key)
	if Snapshot.ReadField then
		return Snapshot.ReadField(info, key)
	end
	return type(info) == "table" and info[key] or nil
end

local function readInfoNumber(info, key)
	return snapshotNumber(info, key) or 0
end

local function currentRoleRemainingField()
	local service = GF.SpecializationInfo
	local specializationIndex = service
		and type(service.GetCurrentSpecializationIndex) == "function"
		and callFirst(service.GetCurrentSpecializationIndex) or nil
	if not specializationIndex then
		return nil
	end

	local roleEnum = type(GetSpecializationRoleEnum) == "function"
		and callFirst(GetSpecializationRoleEnum, specializationIndex) or nil
	local roles = Enum and Enum.LFGRole
	if roles then
		if roleEnum == roles.Tank then
			return "TANK_REMAINING"
		elseif roleEnum == roles.Healer then
			return "HEALER_REMAINING"
		elseif roleEnum == roles.Damage then
			return "DAMAGER_REMAINING"
		end
	end

	local role = type(GetSpecializationRole) == "function"
		and callFirst(GetSpecializationRole, specializationIndex) or nil
	if role == "TANK" then
		return "TANK_REMAINING"
	elseif role == "HEALER" then
		return "HEALER_REMAINING"
	elseif role == "DAMAGER" or role == "DPS" then
		return "DAMAGER_REMAINING"
	end
	return nil
end

local function sortingMemberCounts(owner, resultID)
	local entry = owner.entryCache and owner.entryCache[resultID]
	local counts = entry and entry._displayCounts
	if type(counts) ~= "table" then
		counts = owner._refreshMemberCountsByID
			and owner._refreshMemberCountsByID[resultID]
	end
	if type(counts) ~= "table" then
		counts = owner._aggregateMemberCountsByID
			and owner._aggregateMemberCountsByID[resultID]
	end
	if type(counts) == "table" then
		return counts
	end
	if not (C_LFGList and C_LFGList.GetSearchResultMemberCounts)
		or not owner:IsLiveSearchResultInfoAuthoritative(resultID)
	then
		return nil
	end
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
		GF.SearchMemoryDiagnostics:Add("resultMemberCountReads", 1)
		GF.SearchMemoryDiagnostics:Add("sortMemberCountReads", 1)
	end
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current
		and GF.SearchMemoryDiagnostics.MeasureFirstReturn
	then
		counts = GF.SearchMemoryDiagnostics:MeasureFirstReturn(
			"memberCounts",
			callFirst,
			C_LFGList.GetSearchResultMemberCounts,
			resultID)
	else
		counts = callFirst(C_LFGList.GetSearchResultMemberCounts, resultID)
	end
	if type(counts) == "table" and owner._refreshMemberCountsByID then
		owner._refreshMemberCountsByID[resultID] = counts
	end
	return counts
end

local function hasCurrentRoleVacancy(owner, resultID, remainingField)
	if not remainingField then
		return false
	end
	local cache = owner._sortRoleAvailabilityCache
	local cached = cache and cache[resultID]
	if cached ~= nil then
		return cached == true
	end
	local counts = sortingMemberCounts(owner, resultID)
	local available = type(counts) == "table"
		and readInfoNumber(counts, remainingField) > 0 or false
	if cache then
		cache[resultID] = available
	end
	return available
end

local function currentApplicationSet(owner)
	local set = clearReusableTable(owner._sortApplicationSetBuffer)
	owner._sortApplicationSetBuffer = set
	local applications = C_LFGList
		and C_LFGList.GetApplications
		and callFirst(C_LFGList.GetApplications) or nil
	for _, resultID in ipairs(type(applications) == "table" and applications or {}) do
		set[resultID] = true
	end
	return set
end

local function sortValue(owner, columnID, info, resultID, raidProgress)
	if not info then
		return 0
	end
	if columnID == "activity" then
		return owner:GetActivitySortKey(info)
	elseif columnID == "score" then
		if raidProgress then
			local killed = owner:GetRaidProgress(resultID, info)
			return killed or -1
		end
		return owner:GetBrowseScoreSortKey(info)
	elseif columnID == "roles" then
		return snapshotNumber(info, "numMembers") or 0
	elseif columnID == "ilvl" then
		return snapshotNumber(info, "requiredItemLevel") or 0
	end
	return snapshotNumber(info, "age") or 0
end

local function sortingInfo(owner, resultID)
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
		GF.SearchMemoryDiagnostics:Add("sortKeys", 1)
	end
	local cached = owner.sortInfoCache and owner.sortInfoCache[resultID]
	if cached then
		if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
			GF.SearchMemoryDiagnostics:Add("sortCacheHits", 1)
		end
		return cached
	end
	local info = owner:GetCachedSearchResultInfo(resultID)
	if not info and owner:IsLiveSearchResultInfoAuthoritative(resultID) then
		info = nativeResultInfo(resultID, "sortResultInfoReads")
	end
	if not info or owner:ShouldHideUnavailableResult(resultID, info) then
		return info
	end
	rememberSummary(owner, resultID, info)
	return info
end

local function isCurrentResult(info, resultID)
	return GF.IsCurrentGroupSearchResult
		and GF.IsCurrentGroupSearchResult(info, resultID) == true
end

local function isActiveApplication(job, resultID, info)
	if not (job.applicationSet and job.applicationSet[resultID]) then
		return false
	end
	local apply = GF.Apply
	if apply and type(apply.GetApplicationState) == "function" then
		local state = apply:GetApplicationState(resultID, info)
		if state then
			return state.isActiveApp == true
		end
	end
	return true
end

local function socialSortCounts(info)
	local bnet = readInfoNumber(info, "numBNetFriends")
	local character = readInfoNumber(info, "numCharFriends")
	local guild = readInfoNumber(info, "numGuildMates")
	local social = bnet > 0 or character > 0 or guild > 0
		or readInfoField(info, "isFriendListing") == true
		or readInfoField(info, "isGuildListing") == true
	return social, bnet, character, guild
end

local function isStarredRaidLeader(info)
	local stars = GF.StarredLeaders
	return stars and stars:IsRaidWorkspace() and stars:Get(readInfoField(info, "leaderName")) ~= nil
end

local function isUnavailableRaidResult(owner, info)
	local stars = GF.StarredLeaders
	return stars and stars:IsRaidWorkspace() and owner:IsSoftUnavailable(info)
end

local function collectSortMetadata(job, index, resultID, info)
	local tier = SORT_TIER_ORDINARY
	local bnet, character, guild = 0, 0, 0
	local roleAvailable = false
	if isCurrentResult(info, resultID) then
		tier = SORT_TIER_CURRENT
	elseif isActiveApplication(job, resultID, info) then
		tier = SORT_TIER_APPLICATION
	elseif isUnavailableRaidResult(job.owner, info) then
		tier = SORT_TIER_UNAVAILABLE
	elseif isStarredRaidLeader(info) then
		tier = SORT_TIER_STARRED
	else
		local social
		social, bnet, character, guild = socialSortCounts(info)
		if social then
			tier = SORT_TIER_SOCIAL
		else
			roleAvailable = hasCurrentRoleVacancy(
				job.owner, resultID, job.roleRemainingField)
		end
	end
	job.pins[index] = tier
	job.socialBNet[index] = bnet
	job.socialCharacter[index] = character
	job.socialGuild[index] = guild
	job.roleAvailable[index] = roleAvailable
end

local function releaseSortJob(owner, job)
	if type(job) ~= "table" or owner._activeSortJob ~= job then
		return false
	end
	owner._activeSortJob = nil
	owner._sortValuesBuffer = resetSequenceBuffer(job.values)
	owner._sortPinsBuffer = resetSequenceBuffer(job.pins)
	owner._sortSocialBNetBuffer = resetSequenceBuffer(job.socialBNet)
	owner._sortSocialCharacterBuffer = resetSequenceBuffer(job.socialCharacter)
	owner._sortSocialGuildBuffer = resetSequenceBuffer(job.socialGuild)
	owner._sortRoleAvailableBuffer = resetSequenceBuffer(job.roleAvailable)
	clearReusableTable(job.applicationSet)
	job.ids = nil
	job.values = nil
	job.pins = nil
	job.socialBNet = nil
	job.socialCharacter = nil
	job.socialGuild = nil
	job.roleAvailable = nil
	job.callback = nil
	return true
end

local function finishSortJob(job)
	if job.token ~= job.owner._sortToken then
		return
	end
	local positions = job.positions
	for index = 1, #job.ids do
		positions[index] = index
	end
	table.sort(positions, function(leftIndex, rightIndex)
		local leftPin = job.pins[leftIndex] or SORT_TIER_ORDINARY
		local rightPin = job.pins[rightIndex] or SORT_TIER_ORDINARY
		if leftPin ~= rightPin then
			return leftPin < rightPin
		end
		if leftPin == SORT_TIER_SOCIAL then
			local leftBNet = job.socialBNet[leftIndex] or 0
			local rightBNet = job.socialBNet[rightIndex] or 0
			if leftBNet ~= rightBNet then
				return leftBNet > rightBNet
			end
			local leftCharacter = job.socialCharacter[leftIndex] or 0
			local rightCharacter = job.socialCharacter[rightIndex] or 0
			if leftCharacter ~= rightCharacter then
				return leftCharacter > rightCharacter
			end
			local leftGuild = job.socialGuild[leftIndex] or 0
			local rightGuild = job.socialGuild[rightIndex] or 0
			if leftGuild ~= rightGuild then
				return leftGuild > rightGuild
			end
		elseif leftPin == SORT_TIER_ORDINARY then
			local leftRole = job.roleAvailable[leftIndex] == true
			local rightRole = job.roleAvailable[rightIndex] == true
			if leftRole ~= rightRole then
				return leftRole
			end
		end
		local leftValue = job.values[leftIndex]
		local rightValue = job.values[rightIndex]
		if leftValue ~= rightValue then
			if job.ascending then
				return leftValue < rightValue
			end
			return leftValue > rightValue
		end
		return job.ids[leftIndex] < job.ids[rightIndex]
	end)

	for outputIndex, sourceIndex in ipairs(positions) do
		positions[outputIndex] = job.ids[sourceIndex]
	end
	local reordered = positions
	if GF.Apply and GF.Apply.PinApplicationsToTop then
		reordered = GF.Apply:PinApplicationsToTop(reordered)
	end
	job.owner.resultIDs = reordered
	job.owner.total = #reordered
	local callback = job.callback
	releaseSortJob(job.owner, job)
	clearInactiveSequenceBuffers(
		job.owner,
		"_sortOutputBuffers",
		job.owner.resultIDs,
		job.owner.apiResultIDs,
		job.owner.frozenOrder
	)
	if callback then
		callback()
	end
end

local function collectSortBatch(job)
	if job.token ~= job.owner._sortToken then
		return
	end
	local finalIndex = math.min(job.cursor + job.batchSize - 1, #job.ids)
	for index = job.cursor, finalIndex do
		local resultID = job.ids[index]
		local info = sortingInfo(job.owner, resultID)
		collectSortMetadata(job, index, resultID, info)
		job.values[index] = sortValue(job.owner, job.column, info, resultID, job.raidProgress)
	end
	job.cursor = finalIndex + 1
	if job.cursor > #job.ids then
		finishSortJob(job)
	elseif job.async then
		C_Timer.After(0, function()
			collectSortBatch(job)
		end)
	else
		collectSortBatch(job)
	end
end

local function invalidateSortJobs(owner)
	owner._sortToken = (owner._sortToken or 0) + 1
	if owner._activeSortJob then
		releaseSortJob(owner, owner._activeSortJob)
	end
	return owner._sortToken
end

local function finishOwnedFilterScanBatch(owner, token)
	local activeToken = owner._filterScanBatchToken
	if activeToken == nil or (token ~= nil and token ~= activeToken) then
		return false
	end
	owner._filterScanBatchToken = nil
	local blocklist = GF.Blocklist
	if blocklist and type(blocklist.EndScanTipBatch) == "function" then
		blocklist:EndScanTipBatch()
	end
	return true
end

local function releaseFilterPass(owner, pass)
	if pass == nil or owner._activeListFilterPass ~= pass then
		return false
	end
	owner._activeListFilterPass = nil
	local listFilter = GF.ListFilter
	if listFilter and type(listFilter.ReleasePassContext) == "function" then
		listFilter:ReleasePassContext(pass)
	end
	return true
end

local function invalidateFilterJobs(owner)
	owner._filterToken = (owner._filterToken or 0) + 1
	finishOwnedFilterScanBatch(owner)
	if owner._activeListFilterPass then
		releaseFilterPass(owner, owner._activeListFilterPass)
	end
	return owner._filterToken
end

local function invalidateAsyncJobs(owner)
	invalidateFilterJobs(owner)
	invalidateSortJobs(owner)
	if owner.EndActivityInfoReadPass then
		owner:EndActivityInfoReadPass()
	end
end

function Result:InvalidateAsyncJobs()
	invalidateAsyncJobs(self)
end

function Result:BeginActivityInfoReadPass()
	if Snapshot and Snapshot.BeginActivityInfoReadPass then
		self._activityInfoReadCache = Snapshot.BeginActivityInfoReadPass(
			self._activityInfoReadCache)
	end
	return self._activityInfoReadCache
end

function Result:EndActivityInfoReadPass()
	if Snapshot and Snapshot.EndActivityInfoReadPass then
		self._activityInfoReadCache = Snapshot.EndActivityInfoReadPass(
			self._activityInfoReadCache)
	end
	return self._activityInfoReadCache
end

function Result:InvalidateRoleSortCache(resultID)
	if resultID ~= nil then
		if self._sortRoleAvailabilityCache then
			self._sortRoleAvailabilityCache[resultID] = nil
		end
		if self._refreshMemberCountsByID then
			self._refreshMemberCountsByID[resultID] = nil
		end
		local entry = self.entryCache and self.entryCache[resultID]
		if entry then
			resetDisplayCounts(entry)
			entry._memberCountsLoaded = nil
		end
		return
	end
	self._sortRoleAvailabilityCache = clearReusableTable(
		self._sortRoleAvailabilityCache)
	self._sortRoleAvailabilityField = nil
end

function Result:SortResults(_mode, onComplete)
	local token = invalidateSortJobs(self)
	local ids = self.resultIDs
	if not ids or #ids < 2 then
		if ids and GF.Apply and GF.Apply.PinApplicationsToTop then
			self.resultIDs = GF.Apply:PinApplicationsToTop(ids)
			self.total = #self.resultIDs
		end
		if onComplete then
			onComplete()
		end
		return
	end

	local spec = currentSortSpec()
	local batchSize = GF.BROWSE_SORT_KEY_BATCH or 25
	local canYield = onComplete ~= nil
		and C_Timer ~= nil
		and type(C_Timer.After) == "function"
		and #ids > batchSize
	if not canYield then
		batchSize = #ids
	end
	local positions = acquireSequenceBuffer(
		self,
		"_sortOutputBuffers",
		"_sortOutputBufferIndex",
		ids
	)
	local values = clearReusableTable(self._sortValuesBuffer)
	local pins = clearReusableTable(self._sortPinsBuffer)
	local socialBNet = clearReusableTable(self._sortSocialBNetBuffer)
	local socialCharacter = clearReusableTable(self._sortSocialCharacterBuffer)
	local socialGuild = clearReusableTable(self._sortSocialGuildBuffer)
	local roleAvailable = clearReusableTable(self._sortRoleAvailableBuffer)
	self._sortValuesBuffer = values
	self._sortPinsBuffer = pins
	self._sortSocialBNetBuffer = socialBNet
	self._sortSocialCharacterBuffer = socialCharacter
	self._sortSocialGuildBuffer = socialGuild
	self._sortRoleAvailableBuffer = roleAvailable
	local roleRemainingField = currentRoleRemainingField()
	if self._sortRoleAvailabilityField ~= roleRemainingField then
		self._sortRoleAvailabilityCache = clearReusableTable(
			self._sortRoleAvailabilityCache)
		self._sortRoleAvailabilityField = roleRemainingField
	end
	self._sortRoleAvailabilityCache = self._sortRoleAvailabilityCache or {}
	local job = {
		owner = self,
		token = token,
		ids = ids,
		column = spec.column or "title",
		raidProgress = self:IsRaidProgressContext(),
		ascending = spec.asc ~= false,
		values = values,
		pins = pins,
		socialBNet = socialBNet,
		socialCharacter = socialCharacter,
		socialGuild = socialGuild,
		roleAvailable = roleAvailable,
		roleRemainingField = roleRemainingField,
		applicationSet = currentApplicationSet(self),
		positions = positions,
		cursor = 1,
		batchSize = batchSize,
		async = canYield,
		callback = onComplete,
	}
	self._activeSortJob = job
	collectSortBatch(job)
end

-- Local post-filtering -----------------------------------------------------

local function filterContext()
	local selection
	if GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		selection = GF.FindGroupTab:GetSelection()
	end
	local spec
	if selection and GF.FilterSpec then
		spec = GF.FilterSpec:ResolveSpec(selection)
	end
	local client
	if spec and GF.Filter then
		client = GF.Filter:GetClientFilters(spec.clientKey)
	end
	local database
	if GF.Filter and GF.Filter.GetGlobalFilters then
		database = GF.Filter:GetGlobalFilters(spec)
	end
	if database == nil and GF.GetDB then
		database = GF.GetDB()
	end
	local target = GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget(selection)
	return spec, client, database, target
end

local function activeFilterPlan(spec, client, database)
	local filterSpec = GF.FilterSpec
	if filterSpec then
		local blocklistActive = type(filterSpec.HasActiveBlocklist) == "function"
			and filterSpec:HasActiveBlocklist() == true
		local listFiltersActive = type(filterSpec.NeedsListFilter) == "function"
			and filterSpec:NeedsListFilter(spec, client, database) == true
		return blocklistActive, listFiltersActive
	end
	local listFilter = GF.ListFilter
	local needsPostFilter = listFilter
		and type(listFilter.NeedsPostFilters) == "function"
		and listFilter:NeedsPostFilters(spec, client, database) == true
	return false, needsPostFilter
end

function Result:NeedsPostFilters()
	local spec, client, database, target = filterContext()
	local blocklistActive, listFiltersActive = activeFilterPlan(
		spec, client, database)
	local applicationSet = currentApplicationSet(self)
	return target ~= nil or blocklistActive or listFiltersActive
end

function Result:NeedsBlocklistPlayerSnapshots()
	local spec, client, database = filterContext()
	local blocklistActive = activeFilterPlan(spec, client, database)
	return blocklistActive == true
end

function Result:NeedsFreshSearchResultInfo()
	local spec, client, database, target = filterContext()
	local _, listFiltersActive = activeFilterPlan(spec, client, database)
	local sortSpec = currentSortSpec()
	return target ~= nil or listFiltersActive == true
		or (sortSpec and sortSpec.column == "roles")
end

local function refreshEntryPayload(entry, info)
	if not (entry and info and entry.info ~= info) then
		return
	end
	entry.info = mergeStableText(entry.info, info)
	hydrateActivity(entry, entry.info)
	resetDisplayCounts(entry)
	resetBlockedIdentity(entry)
end

local function retainedCurrentExpired(entry, info, resultID)
	return entry and entry._gfRetainedCurrent == true
		and not (GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(info or entry.info, resultID))
end

local function retainedDeclineActive(entry, resultID)
	local apply = GF.Apply
	return entry and entry._gfRetainedDecline == true
		and apply ~= nil
		and type(apply.IsDeclinedApplication) == "function"
		and apply:IsDeclinedApplication(resultID) == true
end

local function joinedApplicationSupplementActive(entry, resultID, info)
	if not entry then
		return false
	end
	if GF.IsCurrentGroupSearchResult
		and GF.IsCurrentGroupSearchResult(info or entry.info, resultID)
	then
		entry._gfJoinedApplicationSupplement = true
		return true
	end
	local apply = GF.Apply
	if not (apply and type(apply.GetApplicationState) == "function") then
		return false
	end
	local state = apply:GetApplicationState(resultID)
	local active = state and state.isApplication == true and (
		state.isDepartedApplication == true
		or state.appStatus == "inviteaccepted"
		or state.pendingStatus == "inviteaccepted"
	)
	if not active then
		entry._gfJoinedApplicationSupplement = nil
		return false
	end
	-- A local re-filter can be the first pass after joining.  Derive the
	-- supplement marker from the authoritative application state instead of
	-- requiring a prior full RefreshCache to have seeded it.
	entry._gfJoinedApplicationSupplement = true
	return true
end

local function orderLockedResultActive(resultID)
	local panel = GF.BrowsePanel
	if not (panel and panel.HasAutomaticResultOrderLockFor) then
		return false
	end
	if panel:HasAutomaticResultOrderLockFor(
		resultID, "terminal_application")
	then
		return true
	end
	if panel:HasAutomaticResultOrderLockFor(
		resultID, "expired_retirement")
	then
		return true
	end
	if panel:HasAutomaticResultOrderLockFor(resultID, "soft_unavailable") then
		return shouldRetainExpiredGroups()
	end
	return false
end

local function passesLocalRules(owner, resultID, info, context)
	if context.leaderLookup and not GF.RaidLeaderLookup:Matches(context.leaderLookup, info) then
		return false
	end
	info = sanitizeCensoredInfo(info)
	if isCensoredInfo(info) then
		scrubCachedCensoredContent(owner, resultID)
	end
	owner.entryCache = owner.entryCache or {}
	local entry = owner.entryCache[resultID]
	if entry and entry.info and info then
		info = mergeStableText(entry.info, info)
	end
	local joinedSupplement = joinedApplicationSupplementActive(
		entry, resultID, info)
	if retainedCurrentExpired(entry, info, resultID) then
		if joinedSupplement then
			entry._gfRetainedCurrent = nil
		else
			removeCachedRecord(owner, resultID)
			return false
		end
	end
	if owner:ShouldHideUnavailableResult(resultID, info)
		and not retainedDeclineActive(entry, resultID)
		and not joinedSupplement
		and not orderLockedResultActive(resultID)
	then
		removeCachedRecord(owner, resultID)
		return false
	end
	if entry then
		refreshEntryPayload(entry, info)
	end
	local blocklist = context.blocklistActive and GF.Blocklist
	if blocklist and blocklist:ShouldHide(resultID, info, entry) then
		return false
	end
	-- Blizzard appends application records missing from the current search
	-- result set. Joined/departed rows follow that visibility contract and do
	-- not disappear merely because the new search or local filters omit them.
	if joinedSupplement then
		return true
	end
	if context.listFiltersActive ~= true then
		return true
	end
	local listFilter = GF.ListFilter
	if listFilter and not listFilter:ShouldShowResult(
		resultID,
		entry,
		context.spec,
		context.client,
		context.database,
		info,
		context.listFilterPass
	) then
		return false
	end
	return true
end

function Result:PruneSortInfoCache()
	local repository = repositoryFor(self)
	repository:PruneSummaries()
end

function Result:FilterUnavailableFromResults()
	local kept = {}
	local removed = 0
	for _, resultID in ipairs(self.resultIDs or {}) do
		local info = self.sortInfoCache and self.sortInfoCache[resultID]
		if not info then
			info = self:GetCachedSearchResultInfo(resultID)
			if not info and self:IsLiveSearchResultInfoAuthoritative(resultID) then
				info = nativeResultInfo(resultID, "filterResultInfoReads")
			end
			rememberSummary(self, resultID, info)
		end
		local entry = self.entryCache and self.entryCache[resultID]
		if entry and entry.info and info then
			info = mergeStableText(entry.info, info)
		end
		local joinedSupplement = joinedApplicationSupplementActive(
			entry, resultID, info)
		local expiredCurrent = retainedCurrentExpired(entry, info, resultID)
		if expiredCurrent and joinedSupplement then
			entry._gfRetainedCurrent = nil
		end
		if (expiredCurrent and not joinedSupplement)
			or (self:ShouldHideUnavailableResult(resultID, info)
				and not retainedDeclineActive(entry, resultID)
				and not joinedSupplement
				and not orderLockedResultActive(resultID))
		then
			removed = removed + 1
			removeCachedRecord(self, resultID)
		else
			kept[#kept + 1] = resultID
		end
	end
	if removed ~= 0 then
		self.resultIDs = kept
		self.total = #kept
	end
	return removed
end

function Result:FilterDelistedFromResults()
	return self:FilterUnavailableFromResults()
end

local function filterInfo(owner, resultID, forceFresh)
	local cached = owner._refreshInfoByID
		and owner._refreshInfoByID[resultID]
		or owner:GetCachedSearchResultInfo(resultID)
	local info = cached
	local liveIsAuthoritative = owner:IsLiveSearchResultInfoAuthoritative(resultID)
	if forceFresh and liveIsAuthoritative then
		info = nativeResultInfo(resultID, "filterResultInfoReads") or cached
	elseif not info and liveIsAuthoritative then
		info = nativeResultInfo(resultID, "filterResultInfoReads")
	end
	rememberSummary(owner, resultID, info)
	return info
end

local function finishFilterJob(job)
	if job.token ~= job.owner._filterToken then
		finishOwnedFilterScanBatch(job.owner, job.token)
		return
	end
	job.owner.resultIDs = job.output
	job.owner.total = #job.output
	job.owner:PruneSortInfoCache()
	-- Every accepted row was checked against the same cached result payload in
	-- passesLocalRules. Repeating FilterUnavailableFromResults here would only
	-- allocate another activity-info table per row without observing newer data.
	finishOwnedFilterScanBatch(job.owner, job.token)
	local callback = job.callback
	releaseFilterPass(job.owner, job.context.listFilterPass)
	job.context.listFilterPass = nil
	job.context.spec = nil
	job.context.client = nil
	job.context.database = nil
	clearInactiveSequenceBuffers(
		job.owner,
		"_filterOutputBuffers",
		job.owner.resultIDs,
		job.owner.apiResultIDs,
		job.owner.frozenOrder
	)
	if callback then
		callback()
	end
end

local function runFilterBatch(job)
	if job.token ~= job.owner._filterToken then
		finishOwnedFilterScanBatch(job.owner, job.token)
		return
	end
	local stop = math.min(job.cursor + job.batchSize - 1, #job.input)
	for position = job.cursor, stop do
		local resultID = job.input[position]
		local info
		if job.context.leaderLookup then
			-- A lookup must not reuse yesterday's leader identity when native data
			-- is missing, delisted or reassigned to a different leader.
			info = nativeResultInfo(resultID, "filterResultInfoReads")
			rememberSummary(job.owner, resultID, info)
		else
			info = filterInfo(job.owner, resultID, job.context.listFiltersActive == true)
		end
		if passesLocalRules(job.owner, resultID, info, job.context) then
			job.output[#job.output + 1] = resultID
		end
	end
	job.cursor = stop + 1
	if job.cursor > #job.input then
		finishFilterJob(job)
	elseif job.async then
		C_Timer.After(0, function()
			runFilterBatch(job)
		end)
	else
		runFilterBatch(job)
	end
end

function Result:RunPostFilterPass(raw, onComplete)
	local source = raw or self.apiResultIDs or self.resultIDs or {}
	local token = invalidateFilterJobs(self)
	local spec, client, database, target = filterContext()
	local blocklistActive, listFiltersActive = activeFilterPlan(
		spec, client, database)
	if target then listFiltersActive = false end
	if not target and not blocklistActive and not listFiltersActive then
		self.resultIDs = source
		self.total = #self.resultIDs
		clearInactiveSequenceBuffers(
			self,
			"_filterOutputBuffers",
			self.resultIDs,
			self.apiResultIDs,
			self.frozenOrder
		)
		-- A completed native search already supplies authoritative membership; its
		-- sort pass will hydrate only the rows that need keys. Local re-filtering
		-- can operate on an older source and must still remove unavailable rows.
		if self._refreshInfoByID == nil then
			self:FilterUnavailableFromResults()
		end
		if onComplete then
			onComplete()
		end
		return
	end

	if blocklistActive
		and GF.Blocklist
		and GF.Blocklist.BeginScanTipBatch
	then
		GF.Blocklist:BeginScanTipBatch()
		self._filterScanBatchToken = token
	end
	local listFilterPass
	if listFiltersActive
		and GF.ListFilter
		and type(GF.ListFilter.CreatePassContext) == "function"
	then
		listFilterPass = GF.ListFilter:CreatePassContext(
			spec, client, database, self._listFilterPassBuffer)
		self._listFilterPassBuffer = listFilterPass
		self._activeListFilterPass = listFilterPass
	end

	local batchSize = GF.FILTER_BATCH or 25
	local canYield = onComplete ~= nil
		and #source > batchSize
		and C_Timer ~= nil
		and type(C_Timer.After) == "function"
	if not canYield then
		batchSize = math.max(1, #source)
	end
	local output = acquireSequenceBuffer(
		self,
		"_filterOutputBuffers",
		"_filterOutputBufferIndex",
		source,
		self.resultIDs
	)
	runFilterBatch({
		owner = self,
		token = token,
		input = source,
		output = output,
		cursor = 1,
		batchSize = batchSize,
		async = canYield,
		context = {
			leaderLookup = target,
			spec = spec,
			client = client,
			database = database,
			blocklistActive = blocklistActive,
			listFiltersActive = listFiltersActive,
			listFilterPass = listFilterPass,
			applicationSet = applicationSet,
		},
		callback = onComplete,
	})
end

function Result:ApplyPostFilters(onComplete)
	return self:RunPostFilterPass(self.apiResultIDs or self.resultIDs, onComplete)
end

local function filterHidesDeclinedResults()
	local spec, client = filterContext()
	return type(spec) == "table"
		and spec.showNotDeclined == true
		and type(client) == "table"
		and client.notDeclined == true
end

function Result:ShouldHideDeclinedApplications()
	return filterHidesDeclinedResults()
end

local function shouldRetainDeclinedResult(resultID, hidesDeclined)
	local apply = GF.Apply
	if not apply then
		return false
	end
	if type(apply.HasRejectionFeedback) == "function"
		and apply:HasRejectionFeedback(resultID) == true
	then
		return true
	end
	return hidesDeclined ~= true
		and type(apply.IsDeclinedApplication) == "function"
		and apply:IsDeclinedApplication(resultID) == true
end

local function captureFrozenDeclinedEntries(owner)
	if type(owner.frozenOrder) ~= "table" then
		return nil
	end
	local hidesDeclined = filterHidesDeclinedResults()
	local retained = {}
	for _, resultID in ipairs(owner.frozenOrder) do
		if shouldRetainDeclinedResult(resultID, hidesDeclined) then
			local entry = owner.entryCache and owner.entryCache[resultID]
			local info = (entry and entry.info)
				or (owner.sortInfoCache and owner.sortInfoCache[resultID])
			if info then
				retained[#retained + 1] = {
					resultID = resultID,
					entry = entry,
					info = info,
				}
			end
		end
	end
	return #retained > 0 and retained or nil
end

local function injectRetainedDeclinedEntries(owner, ids, retained, aggregate)
	if not retained then
		return 0
	end
	local seen = {}
	for _, resultID in ipairs(ids) do
		seen[resultID] = true
	end
	local added = 0
	for _, snapshot in ipairs(retained) do
		local resultID = snapshot.resultID
		if not seen[resultID] then
			ids[#ids + 1] = resultID
			seen[resultID] = true
			snapshot.needsSnapshot = true
			added = added + 1
		elseif aggregate then
			snapshot.needsSnapshot = not (owner._aggregateInfoByID
				and owner._aggregateInfoByID[resultID])
		else
			snapshot.needsSnapshot = nativeResultInfo(
				resultID, "retentionResultInfoReads") == nil
		end
	end
	return added
end

local function seedRetainedDeclinedEntries(owner, retained)
	owner.entryCache = owner.entryCache or {}
	for _, snapshot in ipairs(retained or {}) do
		local resultID, info = snapshot.resultID, snapshot.info
		local entry = snapshot.entry or Snapshot.NewEntry(resultID, info)
		if entry then
			entry.info = info
			entry._gfRetainedDecline = true
			owner.entryCache[resultID] = entry
			rememberSummary(owner, resultID, info)
			populateCountDefaults(entry)
		end
	end
end

local function captureFrozenOrderLockedEntries(owner)
	local panel = GF.BrowsePanel
	if type(owner.frozenOrder) ~= "table"
		or not (panel and panel.HasAutomaticResultOrderLockFor)
	then
		return nil
	end
	local retained = {}
	for _, resultID in ipairs(owner.frozenOrder) do
		if orderLockedResultActive(resultID) then
			local entry = owner.entryCache and owner.entryCache[resultID]
			local info = (entry and entry.info)
				or (owner.sortInfoCache and owner.sortInfoCache[resultID])
			if info then
				retained[#retained + 1] = {
					resultID = resultID,
					entry = entry,
					info = info,
				}
			end
		end
	end
	return #retained > 0 and retained or nil
end

local function injectRetainedOrderLockedEntries(owner, ids, retained, aggregate)
	if not retained then
		return 0
	end
	local seen = {}
	for _, resultID in ipairs(ids) do
		seen[resultID] = true
	end
	local added = 0
	for _, snapshot in ipairs(retained) do
		local resultID = snapshot.resultID
		if not seen[resultID] then
			ids[#ids + 1] = resultID
			seen[resultID] = true
			snapshot.needsSnapshot = true
			added = added + 1
		elseif aggregate then
			snapshot.needsSnapshot = not (owner._aggregateInfoByID
				and owner._aggregateInfoByID[resultID])
		else
			snapshot.needsSnapshot = nativeResultInfo(
				resultID, "retentionResultInfoReads") == nil
		end
	end
	return added
end

local function seedRetainedOrderLockedEntries(owner, retained)
	owner.entryCache = owner.entryCache or {}
	for _, snapshot in ipairs(retained or {}) do
		if snapshot.needsSnapshot then
			local resultID, info = snapshot.resultID, snapshot.info
			local entry = owner.entryCache[resultID]
				or snapshot.entry
				or Snapshot.NewEntry(resultID, info)
			if entry then
				entry.info = mergeStableText(entry.info, info)
				owner.entryCache[resultID] = entry
				rememberSummary(owner, resultID, entry.info)
				populateCountDefaults(entry)
			end
		end
	end
end

function Result:ReapplyClientFilters(onComplete, options)
	options = options or {}
	invalidateAsyncJobs(self)
	local retainedDeclines = captureFrozenDeclinedEntries(self)
	local source
	if options.preserveOrder == true then
		-- Application terminal feedback is a projection change, not a new result
		-- source.  Filter the currently frozen sequence so surviving rows keep
		-- their exact on-screen order; an explicit search/refresh/sort will build
		-- the next authoritative order normally.
		source = self.frozenOrder or self.resultIDs
	else
		source = self.apiResultIDs
	end
	if source == nil then
		source = self.resultIDs
	end
	source = copySequence(source or {})
	injectRetainedDeclinedEntries(self, source, retainedDeclines, false)
	seedRetainedDeclinedEntries(self, retainedDeclines)
	self:RunPostFilterPass(source, function()
		if options.preserveOrder == true then
			if onComplete then
				onComplete()
			end
		else
			self:SortResults(nil, onComplete)
		end
	end)
end

-- Native result acquisition ------------------------------------------------

local function browseSearchOwnership()
	if GF.FindGroupTab and GF.FindGroupTab.GetBrowseSearchState then
		return GF.FindGroupTab:GetBrowseSearchState()
	end
	return false, false
end

local function nativeResultList(useFiltered)
	local gateway = GF.NativeSearchGateway
	if not (gateway and gateway.ReadResults) then
		return 0, {}
	end
	return gateway:ReadResults(useFiltered == true)
end

local function chooseResultSource(owner)
	local aggregateIDs, aggregateTotal, aggregateInfo, aggregateCounts
	if GF.Search and GF.Search.GetAggregatedResultIDs then
		aggregateIDs, aggregateTotal, aggregateInfo, aggregateCounts =
			GF.Search:GetAggregatedResultIDs()
	end
	local repository = repositoryFor(owner)
	repository:SetAggregateSource(
		aggregateIDs ~= nil, aggregateInfo, aggregateCounts)
	if aggregateIDs then
		return tonumber(aggregateTotal) or #aggregateIDs, aggregateIDs, true
	end

	local hasKeyword, ownsSearch = browseSearchOwnership()
	if hasKeyword then
		local count, ids = nativeResultList(true)
		return count, ids, false
	end
	if ownsSearch then
		local count, ids = nativeResultList(false)
		return count, ids, false
	end
	local count, ids = nativeResultList(true)
	return count, ids, false
end

local function seedAggregateEntries(owner, ids)
	local summaries = owner._aggregateInfoByID
	if not summaries then
		return
	end
	for _, resultID in ipairs(ids) do
		local info = summaries[resultID]
		if info then
			rememberSummary(owner, resultID, info)
		end
	end
end

local function nativeJoinedApplicationState(resultID)
	local reader = C_LFGList and C_LFGList.GetApplicationInfo
	if not (resultID and type(reader) == "function") then
		return false
	end
	local ok, _, appStatus, pendingStatus = pcall(reader, resultID)
	if not ok then
		return false
	end
	return appStatus == "inviteaccepted"
		or pendingStatus == "inviteaccepted"
end

local function retentionResultInfo(owner, resultID)
	local cached = owner:GetCachedSearchResultInfo(resultID)
	local live = nativeResultInfo(resultID, "retentionResultInfoReads")
	if live and cached then
		return mergeStableText(cached, live)
	end
	return live or cached
end

local function retainedPartyGUID(info)
	local value, state = readInfoField(info, "partyGUID")
	if state ~= nil and state ~= "value" then
		return nil
	end
	if value == nil or (type(value) == "string" and value == "")
		or secretValue(value)
	then
		return nil
	end
	return value
end

local function captureJoinedApplicationEntries(owner, ids)
	local sourceSet = {}
	for _, resultID in ipairs(ids or {}) do
		sourceSet[resultID] = true
	end

	local candidates, candidateSet = {}, {}
	local function addCandidate(candidate)
		local resultID = tonumber(candidate)
		if resultID and resultID > 0 and not candidateSet[resultID] then
			candidateSet[resultID] = true
			candidates[#candidates + 1] = resultID
		end
	end

	local applications = C_LFGList
		and type(C_LFGList.GetApplications) == "function"
		and callFirst(C_LFGList.GetApplications) or nil
	for _, resultID in ipairs(type(applications) == "table" and applications or {}) do
		addCandidate(resultID)
	end

	local retained, added = {}, 0
	for _, resultID in ipairs(candidates) do
		local info = retentionResultInfo(owner, resultID)
		local isCurrent = info ~= nil
			and GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(info, resultID) == true
		if info and (isCurrent or nativeJoinedApplicationState(resultID))
		then
			if not sourceSet[resultID] then
				ids[#ids + 1] = resultID
				sourceSet[resultID] = true
				added = added + 1
			end
			retained[#retained + 1] = {
				resultID = resultID,
				info = info,
			}
		end
	end
	return #retained > 0 and retained or nil, added
end

local function remapRetainedEntries(retained, redirects, infoByID)
	if type(retained) ~= "table" or type(redirects) ~= "table" then
		return
	end
	local seen, writeIndex = {}, 1
	for readIndex = 1, #retained do
		local snapshot = retained[readIndex]
		local originalID = snapshot.resultID
		local resultID = redirects[originalID] or originalID
		if resultID and not seen[resultID] then
			seen[resultID] = true
			if resultID ~= originalID then
				snapshot.resultID = resultID
				snapshot.entry = nil
				snapshot.needsSnapshot = true
				snapshot.info = infoByID[resultID] or snapshot.info
			end
			retained[writeIndex] = snapshot
			writeIndex = writeIndex + 1
		end
	end
	for index = writeIndex, #retained do
		retained[index] = nil
	end
end

-- A searchResultID is only stable inside its native result source.  After an
-- accepted application joins the HOME party, a subsequent search can publish a
-- new result ID for the same partyGUID while the previous application/frozen
-- row is still retained.  While the player remains in HOME, keep the fresh
-- source row (it is ordered first).  After HOME ends, keep the application ID
-- instead so its lingering inviteaccepted/suppression state remains attached.
-- If party identity is unavailable, exact-ID de-duplication is the only safe
-- fallback; titles and leader names are never used as identity.
local function coalesceJoinedGroupEntries(
	owner, ids, inspectJoinedIdentity, retainedJoined, retainedCurrent)
	local seenIDs, kept = {}, {}
	local infoByID, redirects = {}, {}
	local currentRepresentatives = {}
	local departedJoinedRepresentatives = {}
	local removed = 0
	for _, snapshot in ipairs(retainedJoined or {}) do
		local resultID, info = snapshot.resultID, snapshot.info
		local partyGUID = retainedPartyGUID(info)
		local isCurrent = partyGUID ~= nil
			and GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(info, resultID) == true
		if partyGUID ~= nil and not isCurrent
			and departedJoinedRepresentatives[partyGUID] == nil
		then
			-- Once HOME membership has ended, keep the authoritative application
			-- ID so its lingering inviteaccepted/suppression state remains attached
			-- to the single projected row.
			departedJoinedRepresentatives[partyGUID] = resultID
		end
	end
	for _, resultID in ipairs(ids or {}) do
		if resultID ~= nil and not seenIDs[resultID] then
			seenIDs[resultID] = true
			local keep = true
			if inspectJoinedIdentity == true then
				local info = retentionResultInfo(owner, resultID)
				if info then
					infoByID[resultID] = info
				end
				local partyGUID = retainedPartyGUID(info)
				local isCurrent = partyGUID ~= nil
					and GF.IsCurrentGroupSearchResult
					and GF.IsCurrentGroupSearchResult(info, resultID) == true
				local departedRepresentative = partyGUID ~= nil
					and departedJoinedRepresentatives[partyGUID] or nil
				if departedRepresentative ~= nil
					and departedRepresentative ~= resultID
				then
					redirects[resultID] = departedRepresentative
					keep = false
				elseif isCurrent then
					local representative = currentRepresentatives[partyGUID]
					if representative ~= nil then
						redirects[resultID] = representative
						keep = false
					else
						currentRepresentatives[partyGUID] = resultID
					end
				end
			end
			if keep then
				kept[#kept + 1] = resultID
			else
				removed = removed + 1
			end
		else
			removed = removed + 1
		end
	end
	for index = 1, #ids do
		ids[index] = nil
	end
	for index, resultID in ipairs(kept) do
		ids[index] = resultID
	end
	remapRetainedEntries(retainedJoined, redirects, infoByID)
	remapRetainedEntries(retainedCurrent, redirects, infoByID)
	return removed, infoByID
end

local function seedJoinedApplicationEntries(owner, retained)
	for _, snapshot in ipairs(retained or {}) do
		local resultID, info = snapshot.resultID, snapshot.info
		local entry = owner.entryCache[resultID]
			or Snapshot.NewEntry(resultID, info)
		if entry then
			entry.info = mergeStableText(entry.info, info)
			entry._gfJoinedApplicationSupplement = true
			owner.entryCache[resultID] = entry
			rememberSummary(owner, resultID, info)
			populateCountDefaults(entry)
		end
	end
end

local function captureFrozenCurrentEntries(owner)
	if type(owner.frozenOrder) ~= "table" then
		return nil
	end
	local retained = {}
	for _, resultID in ipairs(owner.frozenOrder) do
		local entry = owner.entryCache and owner.entryCache[resultID]
		local info = (entry and entry.info)
			or (owner.sortInfoCache and owner.sortInfoCache[resultID])
		if info and GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(info, resultID)
		then
			retained[#retained + 1] = {
				resultID = resultID,
				entry = entry,
				info = info,
			}
		end
	end
	return #retained > 0 and retained or nil
end

local function injectRetainedCurrentEntries(owner, ids, retained, aggregate)
	if not retained then
		return 0
	end
	local seen = {}
	for _, resultID in ipairs(ids) do
		seen[resultID] = true
	end
	local added = 0
	for _, snapshot in ipairs(retained) do
		local resultID = snapshot.resultID
		if not seen[resultID] then
			ids[#ids + 1] = resultID
			seen[resultID] = true
			snapshot.needsSnapshot = true
			added = added + 1
		elseif aggregate then
			snapshot.needsSnapshot = not (owner._aggregateInfoByID
				and owner._aggregateInfoByID[resultID])
		else
			snapshot.needsSnapshot = nativeResultInfo(
				resultID, "retentionResultInfoReads") == nil
		end
	end
	return added
end

local function seedRetainedCurrentEntries(owner, retained)
	for _, snapshot in ipairs(retained or {}) do
		if snapshot.needsSnapshot then
			local resultID, info = snapshot.resultID, snapshot.info
			-- Joined-application supplements are seeded immediately before this
			-- retained-current pass.  Prefer that new cache entry so an older frozen
			-- snapshot cannot overwrite the supplement marker during the same
			-- refresh (for example, when a joined listing becomes full/delisted).
			local seededEntry = owner.entryCache[resultID]
			local entry = seededEntry
				or snapshot.entry
				or Snapshot.NewEntry(resultID, info)
			if entry then
				-- A joined seed may contain a newer live capacity/delisted payload.
				-- Frozen info is only a fallback; never replace those live fields with
				-- the older retained-current snapshot.
				if not seededEntry then
					entry.info = mergeStableText(entry.info, info)
				end
				entry._gfRetainedCurrent = true
				owner.entryCache[resultID] = entry
				rememberSummary(owner, resultID, entry.info)
				populateCountDefaults(entry)
			end
		end
	end
end

local function stableTierForResult(owner, resultID, ignoreTerminalLock)
	local info = owner:GetCachedSearchResultInfo(resultID)
	if isCurrentResult(info, resultID) then
		return SORT_TIER_CURRENT
	end
	local apply = GF.Apply
	local state = apply and apply.GetApplicationState
		and apply:GetApplicationState(resultID, info)
	local former = owner._currentGroupOrder and owner._currentGroupOrder[resultID]
	local departed = former and former.departedAt ~= nil
		or state and state.isDepartedApplication == true
	local panel = GF.BrowsePanel
	if panel and panel.HasAutomaticResultOrderLockFor
		and not departed and not ignoreTerminalLock
		and panel:HasAutomaticResultOrderLockFor(
			resultID, "terminal_application")
	then
		return SORT_TIER_APPLICATION
	end
	if state and state.isActiveApp == true then
		return SORT_TIER_APPLICATION
	end
	if isUnavailableRaidResult(owner, info) then return SORT_TIER_UNAVAILABLE end
	if isStarredRaidLeader(info) then return SORT_TIER_STARRED end
	local social = socialSortCounts(info)
	return social and SORT_TIER_SOCIAL or SORT_TIER_ORDINARY
end

local function applicationPrefixEnd(owner, ids)
	local boundary = 0
	for index, resultID in ipairs(ids) do
		local info = owner:GetCachedSearchResultInfo(resultID)
		if isCurrentResult(info, resultID) then
			boundary = index
		else
			local apply = GF.Apply
			local state = apply and apply.GetApplicationState
				and apply:GetApplicationState(resultID, info)
			local panel = GF.BrowsePanel
			local terminalSlot = panel
				and panel.HasAutomaticResultOrderLockFor
				and panel:HasAutomaticResultOrderLockFor(
					resultID, "terminal_application")
			local former = owner._currentGroupOrder and owner._currentGroupOrder[resultID]
			local departed = former and former.departedAt ~= nil
				or state and state.isDepartedApplication == true
			if state and state.isActiveApp == true
				or not departed and ((state and state.isApplication == true) or terminalSlot)
			then
				boundary = index
			else
				break
			end
		end
	end
	return boundary
end

function Result:StabilizeAutomaticOrder(previousOrder)
	if type(previousOrder) ~= "table" or #previousOrder == 0 then
		return false
	end
	local sorted, available = self.resultIDs or {}, {}
	for _, resultID in ipairs(sorted) do
		available[resultID] = true
	end
	local stable, seen = {}, {}
	for _, resultID in ipairs(previousOrder) do
		if available[resultID] and not seen[resultID] then
			seen[resultID] = true
			stable[#stable + 1] = resultID
		end
	end
	for _, resultID in ipairs(sorted) do
		if not seen[resultID] then
			seen[resultID] = true
			local tier = stableTierForResult(self, resultID)
			local insertAt = #stable + 1
			if tier == SORT_TIER_CURRENT then
				insertAt = 1
			elseif tier == SORT_TIER_APPLICATION then
				insertAt = applicationPrefixEnd(self, stable) + 1
			elseif tier == SORT_TIER_SOCIAL or tier == SORT_TIER_STARRED
				or tier == SORT_TIER_ORDINARY
			then
				-- A frozen expired row can precede live rows. Insert after the
				-- last equal/higher tier so it cannot lift a new row over them.
				insertAt = 1
				for index = #stable, 1, -1 do
					if stableTierForResult(self, stable[index]) <= tier then
						insertAt = index + 1
						break
					end
				end
			end
			table.insert(stable, insertAt, resultID)
		end
	end
	self.resultIDs = stable
	self.total = #stable
	return true
end

function Result:StablePromoteApplication(resultID)
	resultID = tonumber(resultID)
	if not resultID then
		return false
	end
	local source = self.frozenOrder or self.resultIDs or {}
	local ordered, found = {}, false
	for _, candidateID in ipairs(source) do
		if candidateID == resultID then
			found = true
		else
			ordered[#ordered + 1] = candidateID
		end
	end
	if not found then
		return false
	end
	local insertAt = applicationPrefixEnd(self, ordered) + 1
	local apply = GF.Apply
	local priority = apply and apply.GetApplicationPriority
		and apply:GetApplicationPriority(resultID)
	for index = 1, insertAt - 1 do
		local candidateID = ordered[index]
		local info = self:GetCachedSearchResultInfo(candidateID)
		if not isCurrentResult(info, candidateID) then
			local candidatePriority = apply and apply.PeekApplicationPriority
				and apply:PeekApplicationPriority(candidateID)
			if priority ~= nil and candidatePriority ~= nil
				and priority < candidatePriority
			then
				insertAt = index
				break
			end
		end
	end
	table.insert(ordered, insertAt, resultID)
	self.resultIDs = ordered
	self.total = #ordered
	return true
end

local function socialOrderSnapshot(info)
	return {
		numBNetFriends = readInfoNumber(info, "numBNetFriends"),
		numGuildMates = readInfoNumber(info, "numGuildMates"),
		numCharFriends = readInfoNumber(info, "numCharFriends"),
		isGuildListing = readInfoField(info, "isGuildListing") == true,
		isFriendListing = readInfoField(info, "isFriendListing") == true,
	}
end

local function refreshFormerCurrentInfo(owner, resultID, record)
	if record.tier == nil then
		local live = owner:GetLiveSearchResultInfoForUpdate(resultID)
		local liveGUID = retainedPartyGUID(live)
		if liveGUID and record.partyGUID and liveGUID ~= record.partyGUID then
			return nil
		end
		if live and (not record.partyGUID or liveGUID == record.partyGUID) then
			owner:RefreshEntryInfo(resultID, live, {
				availabilityChecked = true, hydrateMissing = false, refreshSocial = true,
			})
		end
	end
	local info = owner:GetCachedSearchResultInfo(resultID)
	if info and GF.ResolveSearchResultSocialCounts then
		-- Full automatic source refreshes can replace a compact summary without
		-- visiting RefreshEntryInfo. Preserve unknown fields and remember fresh
		-- zero counts here too, without adding another native friend read.
		GF.ResolveSearchResultSocialCounts(info, resultID, {
			refresh = true, previousInfo = record.socialInfo, probeFriends = false,
		})
		record.socialInfo = socialOrderSnapshot(info)
	end
	return info
end

local function relocateFormerCurrent(owner, resultID, tier)
	local ordered, previousIndex = {}, nil
	for index, candidateID in ipairs(owner.resultIDs or {}) do
		if candidateID == resultID then previousIndex = index
		else ordered[#ordered + 1] = candidateID end
	end
	local insertAt = applicationPrefixEnd(owner, ordered) + 1
	for index = #ordered, 1, -1 do
		if stableTierForResult(owner, ordered[index], true) <= tier then
			insertAt = math.max(insertAt, index + 1)
			break
		end
	end
	if not previousIndex or previousIndex == insertAt then return false end
	table.insert(ordered, insertAt, resultID)
	owner.resultIDs = ordered
	owner.total = #ordered
	return true
end

-- A departed current row is the one automatic-order exception: move only
-- this identity after feedback, then only when its relation tier changes.
function Result:ReconcileCurrentGroupOrder(onlyResultID)
	local records = self._currentGroupOrder or {}
	self._currentGroupOrder = records
	local now = type(GetTime) == "function" and GetTime() or 0
	local changed, nextDelay = false, nil
	local apply = GF.Apply
	local currentGUID = apply and apply.GetCurrentGroupPartyGUID
		and retainedPartyGUID({ partyGUID = callFirst(apply.GetCurrentGroupPartyGUID, apply) })
	local currentID = apply and apply.currentGroupResultID
	local candidates = onlyResultID and { onlyResultID } or self.resultIDs or {}
	for _, resultID in ipairs(candidates) do
		local info = self:GetIndexForResultID(resultID) and self:GetCachedSearchResultInfo(resultID)
		local guid = retainedPartyGUID(info)
		local record = records[resultID]
		if record and guid and record.partyGUID and guid ~= record.partyGUID then
			records[resultID], record = nil, nil
		end
		local mayBeCurrent = record or resultID == currentID
			or readInfoField(info, "hasSelf") == true
			or guid and currentGUID and guid == currentGUID
		if info and mayBeCurrent and isCurrentResult(info, resultID) then
			if record and GF.ResolveSearchResultSocialCounts then
				GF.ResolveSearchResultSocialCounts(info, resultID, {
					refresh = true, previousInfo = record.socialInfo, probeFriends = false,
				})
			end
			records[resultID] = { partyGUID = guid, wasCurrent = true,
				socialInfo = socialOrderSnapshot(info) }
		elseif info and record then
			local state = GF.Apply and GF.Apply.GetApplicationState
				and GF.Apply:GetApplicationState(resultID, info)
			if state and state.isActiveApp == true then
				-- A new explicit application owns its own promotion lifecycle.
				records[resultID] = nil
			else
				if record.wasCurrent then
					record.wasCurrent = nil
					record.departedAt = now + 0.8
				end
				if record.departedAt and now < record.departedAt then
					local delay = record.departedAt - now
					nextDelay = nextDelay and math.min(nextDelay, delay) or delay
				elseif record.departedAt then
					if not refreshFormerCurrentInfo(self, resultID, record) then
						records[resultID] = nil
					else
						local tier = stableTierForResult(self, resultID)
						if record.tier ~= tier then
							record.tier = tier
							changed = relocateFormerCurrent(self, resultID, tier) or changed
						end
					end
				end
			end
		end
	end
	for resultID in pairs(records) do
		if not self:GetIndexForResultID(resultID) then records[resultID] = nil end
	end
	if nextDelay and GF.FindGroupTab and GF.FindGroupTab.RequestCurrentGroupDepartureRefresh then
		GF.FindGroupTab:RequestCurrentGroupDepartureRefresh(nextDelay)
	end
	return changed
end

function Result:StablePromoteCurrentGroup()
	local changed = self:ReconcileCurrentGroupOrder()
	local source = changed and self.resultIDs or self.frozenOrder or self.resultIDs or {}
	local current, remainder = {}, {}
	for _, resultID in ipairs(source) do
		local info = self:GetCachedSearchResultInfo(resultID)
		if isCurrentResult(info, resultID) then
			current[#current + 1] = resultID
		else
			remainder[#remainder + 1] = resultID
		end
	end
	if #current == 0 then
		return changed
	end
	for _, resultID in ipairs(remainder) do
		current[#current + 1] = resultID
	end
	self.resultIDs = current
	self.total = #current
	return true
end

local function continueRefreshAfterFiltering(owner, callback, options)
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.RecordStage then
		GF.SearchMemoryDiagnostics:RecordStage("filter")
	end
	owner:SortResults(nil, function()
		if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.RecordStage then
			GF.SearchMemoryDiagnostics:RecordStage("sort")
		end
		if options and options.stableOrder == true then
			owner:StabilizeAutomaticOrder(options.previousOrder)
		end
		if callback then
			callback()
		end
		local repository = repositoryFor(owner)
		repository:EndRefresh()
		owner:EndActivityInfoReadPass()
	end)
end

local function seedReusableSummaries(owner, ids, previous, previousFrozenSet)
	if owner._usingAggregatedResults or type(previous) ~= "table"
		or type(previousFrozenSet) ~= "table"
	then
		return
	end
	local sortSpec = currentSortSpec()
	if sortSpec and sortSpec.column == "roles" then
		return
	end
	for _, resultID in ipairs(ids or {}) do
		local summary = previousFrozenSet[resultID] and previous[resultID]
		if summary then
			owner.sortInfoCache[resultID] = summary
		end
	end
end

function Result:RefreshCache(onComplete, beforePostFilters, options)
	options = options or {}
	invalidateAsyncJobs(self)
	self:BeginActivityInfoReadPass()
	local previousOrder = options.stableOrder == true
		and copySequence(self.frozenOrder or self.resultIDs or {}) or nil
	local previousSummaries = self.sortInfoCache
	local previousFrozenSet = self.frozenSet
	local retainedCurrent = captureFrozenCurrentEntries(self)
	local retainedDeclines = captureFrozenDeclinedEntries(self)
	local retainedOrderLocks = captureFrozenOrderLockedEntries(self)
	local lookup = GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget()
	if lookup then retainedCurrent, retainedDeclines, retainedOrderLocks = nil, nil, nil end
	local selectedTotal, sourceIDs, aggregate = chooseResultSource(self)
	if aggregate and GF.Search
		and GF.Search.RevalidateUnknownAggregatedResults
		and GF.Search:RevalidateUnknownAggregatedResults()
	then
		-- Identity can hydrate between the search-complete event and this first
		-- result refresh. Re-read the aggregate after validation so a resolved
		-- mismatch never enters the frozen source while a match can seed its
		-- newly captured summary without waiting for another native event.
		selectedTotal, sourceIDs, aggregate = chooseResultSource(self)
	end
	local sourceCount = type(sourceIDs) == "table" and #sourceIDs or 0
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current
		and (tonumber(GF.SearchMemoryDiagnostics.current.scopesCompleted) or 0) == 0
	then
		GF.SearchMemoryDiagnostics:RecordScope(
			selectedTotal, sourceCount, sourceCount, 0)
	end
	local ids = copySequence(sourceIDs, acquireSequenceBuffer(
		self,
		"_refreshIDBuffers",
		"_refreshIDBufferIndex",
		sourceIDs,
		self.apiResultIDs
	))
	local joinedApplications, joinedCount = nil, 0
	if not lookup then joinedApplications, joinedCount = captureJoinedApplicationEntries(self, ids) end
	local retainedCount = injectRetainedCurrentEntries(
		self, ids, retainedCurrent, aggregate)
	retainedCount = retainedCount + injectRetainedDeclinedEntries(
		self, ids, retainedDeclines, aggregate)
	retainedCount = retainedCount + injectRetainedOrderLockedEntries(
		self, ids, retainedOrderLocks, aggregate)
	retainedCount = retainedCount + joinedCount
	local coalescedCount, identityInfoByID = coalesceJoinedGroupEntries(
		self,
		ids,
		joinedApplications ~= nil or retainedCurrent ~= nil,
		joinedApplications,
		retainedCurrent
	)
	self.apiFilteredTotal = math.max(
		0, selectedTotal + retainedCount - coalescedCount)
	self.rawTotal = selectedTotal
	local searchGateway = GF.NativeSearchGateway
	if not aggregate and searchGateway and searchGateway.CanReadResults
		and searchGateway:CanReadResults(false)
	then
		local rawCount = searchGateway:ReadResults(false)
		if rawCount ~= nil then
			self.rawTotal = rawCount
		end
	end

	local cacheSignature = table.concat({
		tostring(self.apiFilteredTotal),
		tostring(#ids),
		tostring(ids[1] or 0),
		tostring(ids[#ids] or 0),
	}, ":")
	local repository = repositoryFor(self)
	repository:BeginSource({
		apiFilteredTotal = self.apiFilteredTotal,
		rawTotal = self.rawTotal,
		cacheSignature = cacheSignature,
		preserveCurrentGroupOrder = options.stableOrder == true,
	})
	self._sortRoleAvailabilityCache = {}
	self._sortRoleAvailabilityField = nil
	seedReusableSummaries(
		self, ids, previousSummaries, previousFrozenSet)
	seedAggregateEntries(self, ids)
	for _, resultID in ipairs(ids) do
		local info = identityInfoByID[resultID]
		if info then
			rememberSummary(self, resultID, info)
		end
	end
	seedJoinedApplicationEntries(self, joinedApplications)
	seedRetainedCurrentEntries(self, retainedCurrent)
	seedRetainedDeclinedEntries(self, retainedDeclines)
	seedRetainedOrderLockedEntries(self, retainedOrderLocks)
	repository:PublishSource(ids)
	if type(beforePostFilters) == "function" then
		beforePostFilters(ids)
	end
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.RecordStage then
		GF.SearchMemoryDiagnostics:RecordStage("source")
	end
	self:ApplyPostFilters(function()
		continueRefreshAfterFiltering(self, onComplete, {
			stableOrder = options.stableOrder == true,
			previousOrder = previousOrder,
		})
	end)
end

-- Indexed access -----------------------------------------------------------

function Result:GetIndexForResultID(resultID)
	local repository = repositoryFor(self)
	return repository:GetIndexForResultID(resultID)
end

function Result:GetEntryByResultID(resultID)
	if not (type(resultID) == "number" and resultID > 0) then
		return nil
	end
	local repository = repositoryFor(self)
	self.entryCache = self.entryCache or {}
	local cachedEntry = repository:GetEntry(resultID)
	if cachedEntry then
		return cachedEntry
	end
	local cached = self:GetCachedSearchResultInfo(resultID)
	local info = self._refreshInfoByID and self._refreshInfoByID[resultID]
	if not info and self:IsLiveSearchResultInfoAuthoritative(resultID) then
		local live = nativeResultInfo(resultID, "entryResultInfoReads")
		info = live and cached and mergeStableText(cached, live)
			or live or cached
	elseif not info then
		info = cached
	end
	if not info then
		return nil
	end
	if self:ShouldHideUnavailableResult(resultID, info) and not self:IsSoftUnavailable(info) then
		removeCachedRecord(self, resultID)
		return nil
	end
	local entry = Snapshot.NewEntry(resultID, info)
	if entry and GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
		GF.SearchMemoryDiagnostics:Add("entriesHydrated", 1)
	end
	if self._usingAggregatedResults then
		storeMemberCounts(
			entry,
			self._aggregateMemberCountsByID
				and self._aggregateMemberCountsByID[resultID]
		)
	end
	populateCountDefaults(entry)
	repository:RememberEntry(resultID, entry)
	return entry
end

function Result:GetResultID(index)
	if not self.resultIDs then
		self:RefreshCache()
	end
	return self.resultIDs and self.resultIDs[index] or nil
end

function Result:GetCount()
	if not self.resultIDs then
		self:RefreshCache()
	end
	return self.total or 0
end

function Result:GetRawCount()
	if not self.resultIDs then
		self:RefreshCache()
	end
	return self.rawTotal or self.total or 0
end

function Result:GetApiFilteredCount()
	return self.apiFilteredTotal or self.total or 0
end

local function findLeader(players)
	for _, player in ipairs(players or {}) do
		if player.isLeader then
			return player
		end
	end
	return nil
end

function Result:GetEntry(index, options)
	options = options or {}
	local resultID = self:GetResultID(index)
	if not resultID then
		return nil
	end
	local entry = self:GetEntryByResultID(resultID)
	if not entry then
		return nil
	end

	if options.loadLeader then
		local info = entry.info
		local leaderName = snapshotField(info, "leaderName")
		if info and (leaderName == nil or leaderName == "") then
			local current = self:GetAuthoritativeSearchResultInfo(resultID)
			if current then
				entry.info = current
				info = current
			end
		end
		local projectedLeaderName = snapshotField(entry.leader, "name")
		if not entry.leader or projectedLeaderName == nil
			or projectedLeaderName == ""
		then
			entry.leader = leaderFor(
				resultID, snapshotNumber(info, "numMembers"))
		end
		updateLeaderName(info, entry.leader)
	end

	local loadPlayers = options.loadPlayers
	if loadPlayers == nil then
		loadPlayers = self:ShouldLoadPlayersForEntry(entry)
	end
	if loadPlayers and not entry.players then
		entry.players, entry.hasLeaver = playersFor(
			resultID, snapshotNumber(entry.info, "numMembers"))
		entry.leader = entry.leader or findLeader(entry.players)
		updateLeaderName(entry.info, entry.leader)
	end
	return entry
end

function Result:GetInfo(index)
	local entry = self:GetEntry(index)
	return entry and entry.info or nil
end

function Result:GetActivityInfo(index)
	local entry = self:GetEntry(index)
	return entry and entry.activity or nil
end

function Result:GetMemberCounts(index)
	local entry = self:GetEntry(index)
	if entry then
		return entry.tanks, entry.heals, entry.dps
	end
	return 0, 0, 0
end

function Result:GetLeaderPlayer(index)
	local entry = self:GetEntry(index, { loadLeader = true })
	return entry and entry.leader or nil
end

function Result:GetPlayers(index)
	local entry = self:GetEntry(index, { loadPlayers = true })
	if not entry then
		return {}
	end
	return entry.players or {}
end

function Result:ResolveRowCategory(index, fallbackCategoryID)
	local entry = self:GetEntry(index)
	if not entry then
		return fallbackCategoryID
	end
	if entry.categoryID then
		return entry.categoryID
	end
	local categoryID = snapshotNumber(entry.activity, "categoryID")
	if categoryID then
		entry.categoryID = categoryID
		return categoryID
	end
	return fallbackCategoryID
end

local ENUMERATE_LIMIT = 5
local ENUMERATED_MODES = {
	enumerate_roles = true,
	enumerate_specs = true,
}

local function compactActivity(entry)
	if not entry then
		return false
	end
	if entry.categoryID == GF.CAT_DUNGEON or entry.categoryID == GF.CAT_DELVE then
		return true
	end
	local capacity = snapshotNumber(entry.activity, "maxNumPlayers")
	return capacity ~= nil and capacity > 0 and capacity <= ENUMERATE_LIMIT
end

function Result:GetRoleDisplayMode(entry)
	if not entry then
		return "count"
	end
	if not entry.activity then
		hydrateActivity(entry)
	end
	if not compactActivity(entry) then
		return "count"
	end
	local preference = GF.GetMemberDisplayMode and GF.GetMemberDisplayMode()
	local wantsSpecs = (GF.IsMemberDisplaySpecMode and GF.IsMemberDisplaySpecMode(preference))
		or preference == (GF.MEMBER_DISPLAY_MODE_SPEC or "spec")
	return wantsSpecs and "enumerate_specs" or "enumerate_roles"
end

function Result:IsEnumerateMode(mode)
	return ENUMERATED_MODES[mode] == true
end

function Result:IsSpecEnumerateMode(mode)
	return mode ~= nil and mode == "enumerate_specs"
end

function Result:ShouldLoadPlayersForEntry(entry)
	return self:IsEnumerateMode(self:GetRoleDisplayMode(entry))
		or (GF.LaonongFanDirectory ~= nil and GF.LaonongFanDirectory:IsReady() == true)
end

function Result:ShouldLoadPlayers(index)
	local entry = self:GetEntry(index)
	return self:ShouldLoadPlayersForEntry(entry)
end

function Result:InvalidateAllPlayerCache()
	for _, entry in pairs(self.entryCache or {}) do
		if type(entry) == "table" then
			entry.players = nil
			entry.hasLeaver = nil
			resetBlockedIdentity(entry)
		end
	end
end

function Result:InvalidateAllBlockedMemberCache()
	for _, entry in pairs(self.entryCache or {}) do
		if type(entry) == "table" then
			resetBlockedIdentity(entry)
		end
	end
end

function Result:InvalidateEntryMembers(resultID)
	local entry = resultID and self.entryCache and self.entryCache[resultID]
	if not entry then
		return
	end
	entry.players = nil
	entry._memberCountsLoaded = nil
	resetBlockedIdentity(entry)
	resetDisplayCounts(entry)
end

function Result:RefreshEntryInfo(resultID, suppliedInfo, options)
	if not resultID then
		return nil
	end
	options = options or {}
	if self._raidProgressByID and self:IsLiveSearchResultInfoAuthoritative(resultID) then
		self._raidProgressByID[resultID] = nil
	end
	-- Native result updates may change both remaining role capacity and the
	-- selected-column value. Drop only this result's member-count sort cache;
	-- the debounced row-update pass will then run one stable resort.
	self:InvalidateRoleSortCache(resultID)
	local cached = self:GetCachedSearchResultInfo(resultID)
	local info = sanitizeCensoredInfo(suppliedInfo)
	if isCensoredInfo(info) then
		scrubCachedCensoredContent(self, resultID)
		cached = self:GetCachedSearchResultInfo(resultID)
	end
	local authoritativeRefresh = suppliedInfo ~= nil
	if info and cached and self._usingAggregatedResults
		and not self:IsLiveSearchResultInfoAuthoritative(resultID)
	then
		info = cached
		authoritativeRefresh = false
	end
	info = info or cached
	if not info and not self._usingAggregatedResults then
		info = nativeResultInfo(resultID, "updateResultInfoReads")
		authoritativeRefresh = info ~= nil
	end
	if not info then
		return nil
	end
	local socialPlayers, socialPlayersComplete
	if GF.ResolveSearchResultSocialCounts then
		local former = self._currentGroupOrder and self._currentGroupOrder[resultID]
		local refreshSocial = options.refreshSocial == true
			or authoritativeRefresh and readInfoField(info, "_gfSocialFriendsChecked") ~= true
		local _, _, _, _, players, complete = GF.ResolveSearchResultSocialCounts(info, resultID, refreshSocial and {
			refresh = true, previousInfo = former and former.socialInfo or cached,
			probeFriends = options.deferSocialMembers ~= true,
		} or nil)
		socialPlayers, socialPlayersComplete = players, complete
		if former then former.socialInfo = socialOrderSnapshot(info) end
	end

	self.entryCache = self.entryCache or {}
	local entry = self.entryCache[resultID]
	if entry and entry.info then
		info = mergeStableText(entry.info, info)
	end
	info = sanitizeCensoredInfo(info)
	if options.availabilityChecked ~= true
		and self:ShouldHideUnavailableResult(resultID, info)
	then
		if orderLockedResultActive(resultID) then
			return self:MarkSoftUnavailable(resultID, info)
		else
			removeCachedRecord(self, resultID)
			return nil
		end
	end
	if not isCensoredInfo(info) and unreadableText(info.name) then
		local replacement = self:GetListingTitle(info, resultID)
		if replacement and replacement ~= UNKNOWN_TITLE then
			info.name = replacement
		end
	end

	rememberSummary(self, resultID, info)
	if entry then
		entry.info = info
		if authoritativeRefresh and entry._gfRetainedCurrent == true
			and nativeResultInfo(resultID, "updateResultInfoReads") ~= nil
		then
			entry._gfRetainedCurrent = nil
		end
		self:InvalidateEntryMembers(resultID)
		hydrateActivity(entry, info)
	elseif options.hydrateMissing == false then
		return nil, "summary"
	else
		entry = self:GetEntryByResultID(resultID)
	end
	if entry and socialPlayersComplete == true then
		-- Reuse this update's verified roster in the existing entry cache, rather
		-- than enumerating it again for the visible roles or owned tooltip.
		entry.players = socialPlayers
		entry.hasLeaver = false
		for _, player in ipairs(socialPlayers) do
			if readInfoField(player, "isLeaver") == true then entry.hasLeaver = true end
		end
	end
	return entry
end

function Result:ConfirmSocialMemberInfo(resultID, info, friendLists)
	if not GF.ResolveSearchResultSocialCounts
		or not self:IsLiveSearchResultInfoAuthoritative(resultID) then return false end
	GF.ResolveSearchResultSocialCounts(info, resultID, {
		refresh = true, previousInfo = self:GetCachedSearchResultInfo(resultID),
		friendLists = friendLists, verifyMembers = false,
	})
	rememberSummary(self, resultID, info)
	local entry = self.entryCache and self.entryCache[resultID]
	if entry then entry.info = info end
	local former = self._currentGroupOrder and self._currentGroupOrder[resultID]
	if former then former.socialInfo = socialOrderSnapshot(info) end
	return true
end

function Result:RevealCensoredSearchResult(resultID)
	if not resultID then
		return nil, "missing"
	end
	if not self:IsLiveSearchResultInfoAuthoritative(resultID) then
		return nil, "not_current"
	end
	local before = nativeResultInfo(resultID, "revealResultInfoReads")
	if not before then
		return nil, "missing"
	end
	if not isCensoredInfo(before) then
		return before, "not_censored"
	end
	local reveal = C_LFGList and C_LFGList.RevealCensoredSearchResult
	if type(reveal) ~= "function" then
		return before, "unsupported"
	end
	local ok = pcall(reveal, resultID)
	if not ok then
		return before, "failed"
	end
	-- Blizzard's native row immediately performs the same-result read after
	-- RevealCensoredSearchResult. There is no dedicated completion event.
	local after = nativeResultInfo(resultID, "revealResultInfoReads")
	if not after then
		return nil, "missing"
	end
	if isCensoredInfo(after) then
		return after, "censored"
	end
	return after, "revealed"
end

-- Frozen browse snapshot ---------------------------------------------------

function Result:CommitSnapshot()
	local repository = repositoryFor(self)
	return repository:CommitFrozenSnapshot()
end

function Result:ClearFrozenSnapshot()
	local repository = repositoryFor(self)
	repository:ClearFrozenSnapshot()
end

function Result:IsFrozenResult(resultID)
	local repository = repositoryFor(self)
	return repository:IsFrozenResult(resultID)
end

function Result:RemoveFromFrozen(resultID)
	local repository = repositoryFor(self)
	return repository:RemoveFromFrozen(resultID)
end

function Result:RemoveProjectedResult(resultID)
	local repository = repositoryFor(self)
	return repository:RemoveProjectedResult(resultID)
end

function Result:MarkSoftUnavailable(resultID, suppliedInfo, options)
	if not resultID then
		return nil
	end
	options = options or {}
	self.entryCache = self.entryCache or {}
	self.sortInfoCache = self.sortInfoCache or {}
	local entry = self.entryCache[resultID]
	local info = suppliedInfo or (entry and entry.info) or self.sortInfoCache[resultID]
	if not info then
		return nil
	end
	local panel = GF.BrowsePanel
	local retirementLocked = panel and panel.HasAutomaticResultOrderLockFor
		and panel:HasAutomaticResultOrderLockFor(
			resultID, "expired_retirement") == true
	local transientRetirement = options.transientRetirement == true
		or retirementLocked
	if not transientRetirement
		and not self:ShouldRetainExpiredResult(resultID, info)
	then
		removeCachedRecord(self, resultID)
		return nil
	end
	if options.confirmedUnavailable ~= true
		and not self:ShouldSoftUnavailableResult(resultID, info)
	then
		removeCachedRecord(self, resultID)
		return nil
	end
	info._gfSoftUnavailable = true
	info.isDelisted = true
	if entry then
		entry.info = info
		hydrateActivity(entry, info)
	else
		entry = Snapshot.NewEntry(resultID, info)
		if not entry then
			return nil
		end
		self.entryCache[resultID] = entry
	end
	rememberSummary(self, resultID, info)
	return entry
end

-- Application and reset ----------------------------------------------------

function Result:Apply(index, tank, healer, damage, resultID)
	if GF.Apply and GF.Apply.ShowDialogForIndex
		and tank == nil and healer == nil and damage == nil
	then
		return GF.Apply:ShowDialogForIndex(index, resultID)
	end
	if GF.Apply and GF.Apply.ResolveApplyTarget then
		index, resultID = GF.Apply:ResolveApplyTarget(index, resultID)
	else
		resultID = resultID or self:GetResultID(index)
	end
	if not resultID then
		return false
	end
	if GF.Apply and GF.Apply.CanSelectRow
		and not GF.Apply:CanSelectRow(index, resultID)
	then
		return false
	end
	local applications = GF.ApplicationService
	if applications and type(applications.ApplyToGroup) == "function" then
		return applications:ApplyToGroup(resultID, tank, healer, damage)
	end
	return false
end

function Result:Clear()
	invalidateAsyncJobs(self)
	local repository = repositoryFor(self)
	repository:Clear()
	self._sortRoleAvailabilityCache = nil
	self._sortRoleAvailabilityField = nil
	if GF.Search and GF.Search.ClearAggregatedResultIDs then
		GF.Search:ClearAggregatedResultIDs()
	end
	local searchGateway = GF.NativeSearchGateway
	if searchGateway and searchGateway.ClearResults then
		searchGateway:ClearResults()
	end
end

function Result:DiscardBrowseSource()
	-- Abandon an uncommitted browse transaction without clearing Blizzard's
	-- native result store.  Keep sortInfoCache as a stable-text fallback for the
	-- next search so a current/joined application can still be reconstructed
	-- from GetApplications() after its listing disappears from native results.
	invalidateAsyncJobs(self)
	local repository = repositoryFor(self)
	repository:DiscardSource()
	self._sortRoleAvailabilityCache = nil
	self._sortRoleAvailabilityField = nil
	if GF.Search and GF.Search.ClearAggregatedResultIDs then
		GF.Search:ClearAggregatedResultIDs()
	end
end
