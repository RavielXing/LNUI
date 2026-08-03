local _, GF = ...

local Result = {}
GF.Result = Result

local Snapshot = GF.SearchResultSnapshot
local UNKNOWN_TITLE = "?"
local SOFT_UNAVAILABLE = "unavailable"
local NORMAL_SOCIAL_PIN = 1

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

local function copySequence(source)
	local copy = {}
	for position, value in ipairs(source or {}) do
		copy[position] = value
	end
	return copy
end

local function nativeResultInfo(resultID)
	if not (resultID and C_LFGList) then
		return nil
	end
	return callFirst(C_LFGList.GetSearchResultInfo, resultID)
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
	local entries = owner.entryCache
	if entries then
		entries[resultID] = nil
	end
	local summaries = owner.sortInfoCache
	if summaries then
		summaries[resultID] = nil
	end
end

local function rememberSummary(owner, resultID, info)
	if not info then
		return
	end
	owner.sortInfoCache = owner.sortInfoCache or {}
	owner.sortInfoCache[resultID] = info
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
		return older
	end
	if not older then
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
	local capacity = tonumber(activity.maxNumPlayers) or 0
	local members = tonumber(info.numMembers) or 0
	if info.isDelisted == true or (capacity > 0 and members >= capacity) then
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
	local cachedEntry = self.entryCache and self.entryCache[resultID]
	if cachedEntry and cachedEntry.info then
		return cachedEntry.info
	end
	local summary = self.sortInfoCache and self.sortInfoCache[resultID]
	if summary then
		return summary
	end
	return self._aggregateInfoByID and self._aggregateInfoByID[resultID] or nil
end

function Result:GetAuthoritativeSearchResultInfo(resultID)
	local cached = self:GetCachedSearchResultInfo(resultID)
	if not self:IsLiveSearchResultInfoAuthoritative(resultID) then
		return cached
	end
	local current = nativeResultInfo(resultID)
	if current and cached then
		return mergeStableText(cached, current)
	end
	return current or cached
end

function Result:GetLiveSearchResultInfoForUpdate(resultID)
	if self:IsLiveSearchResultInfoAuthoritative(resultID) then
		return nativeResultInfo(resultID)
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
	local reason = baseInvalidReason(info, activityInfo)
	if reason and reason ~= SOFT_UNAVAILABLE then
		return reason
	end
	if reason == SOFT_UNAVAILABLE
		and GF.IsCurrentGroupSearchResult
		and GF.IsCurrentGroupSearchResult(info, resultID)
	then
		reason = nil
	end
	if info and opaqueKString(info.name)
		and not self:IsLiveSearchResultInfoAuthoritative(resultID)
	then
		return "dirty"
	end
	if self:IsDirtySearchResult(resultID, info) then
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
	return info.isDelisted == true
end

function Result:IsSoftUnavailable(info)
	if not info then
		return nil
	end
	return info._gfSoftUnavailable == true or info.isDelisted == true
end

-- Ratings ------------------------------------------------------------------

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
	local numericScore = tonumber(score) or 0
	for _, band in ipairs(SCORE_BANDS) do
		if numericScore >= band.threshold then
			return band.rgb
		end
	end
	return HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
end

local function pvpRatingRecord(info, activityInfo)
	local activity = resolvedActivity(info, activityInfo)
	if not (activity and activity.isRatedPvpActivity) then
		return nil
	end
	local candidate = info and info.leaderPvpRatingInfo
	candidate = candidate and candidate[1]
	if candidate and type(candidate.rating) == "number" and candidate.rating >= 0 then
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
		tier = PVPUtil.GetTierName(rating.tier)
	end
	return rating, tier
end

function Result:GetLeaderPvpRatingTooltipLine(info, activityInfo)
	local rating, tier = self:GetLeaderPvpRatingInfo(info, activityInfo)
	if not (rating and PVP_RATING_GROUP_FINDER) then
		return nil
	end
	return PVP_RATING_GROUP_FINDER:format(rating.activityName, rating.rating, tier)
end

local function browseScore(info, activityInfo)
	if not info then
		return nil, "none"
	end
	local rating = pvpRatingRecord(info, activityInfo)
	if rating then
		return rating.rating, "pvp"
	end
	local activity = resolvedActivity(info, activityInfo)
	if activity and activity.isPvpActivity then
		return nil, "pvp"
	end
	local score = tonumber(info.leaderOverallDungeonScore)
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

local function resetLaonongIdentity(entry)
	if entry and GF.FindGroup and GF.FindGroup.InvalidateLaonongFanMemberCache then
		GF.FindGroup:InvalidateLaonongFanMemberCache(entry)
	end
end

local function storeMemberCounts(entry, counts)
	if not entry or type(counts) ~= "table" then
		return
	end
	entry._displayCounts = counts
	entry._displayCountsLoaded = true
	local roles = {
		TANK = "tanks",
		HEALER = "heals",
		DAMAGER = "dps",
	}
	for nativeRole, entryField in pairs(roles) do
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
	local counts = C_LFGList
		and callFirst(C_LFGList.GetSearchResultMemberCounts, entry.resultID)
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
	for _, field in ipairs({ "tanks", "heals", "dps" }) do
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
	for memberIndex = 1, tonumber(count) or 0 do
		local player = callFirst(C_LFGList.GetSearchResultPlayerInfo, resultID, memberIndex)
		if player then
			players[#players + 1] = player
			leaverFound = leaverFound or player.isLeaver == true
		end
	end
	return players, leaverFound
end

local function leaderFor(resultID, count)
	if not resultID then
		return nil
	end
	local memberCount = tonumber(count)
	if not memberCount or memberCount <= 0 then
		local current = Result:GetAuthoritativeSearchResultInfo(resultID)
		memberCount = tonumber(current and current.numMembers) or 0
	end
	local firstNamed
	for memberIndex = 1, memberCount do
		local player = C_LFGList
			and callFirst(C_LFGList.GetSearchResultPlayerInfo, resultID, memberIndex)
		if player then
			if player.isLeader then
				return player
			end
			if memberIndex == 1 and player.name and player.name ~= "" then
				firstNamed = player
			end
		end
	end
	return firstNamed
end

local function updateLeaderName(info, leader)
	if info and leader and leader.name and (not info.leaderName or info.leaderName == "") then
		info.leaderName = leader.name
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
	local label = details and (details.fullName or details.shortName)
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

local function sortValue(owner, columnID, info)
	if not info then
		return 0
	end
	if columnID == "activity" then
		return owner:GetActivitySortKey(info)
	elseif columnID == "score" then
		return owner:GetBrowseScoreSortKey(info)
	elseif columnID == "roles" then
		return info.numMembers or 0
	elseif columnID == "ilvl" then
		return info.requiredItemLevel or 0
	end
	return info.age or 0
end

local function sortingInfo(owner, resultID)
	local cached = owner.sortInfoCache and owner.sortInfoCache[resultID]
	if cached then
		return cached
	end
	local info
	if owner._usingAggregatedResults then
		info = owner:GetCachedSearchResultInfo(resultID)
	else
		info = nativeResultInfo(resultID)
	end
	if not info or owner:ShouldHideUnavailableResult(resultID, info) then
		return info
	end
	rememberSummary(owner, resultID, info)
	owner.entryCache = owner.entryCache or {}
	if not owner.entryCache[resultID] then
		owner.entryCache[resultID] = Snapshot.NewEntry(resultID, info)
	end
	return info
end

local function resultPriority(info, resultID)
	if GF.GetSearchResultSortPin then
		return GF.GetSearchResultSortPin(info, resultID)
	end
	return NORMAL_SOCIAL_PIN
end

local function finishSortJob(job)
	if job.token ~= job.owner._sortToken then
		return
	end
	local positions = {}
	for index = 1, #job.ids do
		positions[index] = index
	end
	table.sort(positions, function(leftIndex, rightIndex)
		local leftPin = job.pins[leftIndex] or NORMAL_SOCIAL_PIN
		local rightPin = job.pins[rightIndex] or NORMAL_SOCIAL_PIN
		if leftPin ~= rightPin then
			return leftPin < rightPin
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

	local reordered = {}
	for _, sourceIndex in ipairs(positions) do
		reordered[#reordered + 1] = job.ids[sourceIndex]
	end
	if GF.Apply and GF.Apply.PinApplicationsToTop then
		reordered = GF.Apply:PinApplicationsToTop(reordered)
	end
	job.owner.resultIDs = reordered
	job.owner.total = #reordered
	if job.callback then
		job.callback()
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
		job.pins[index] = resultPriority(info, resultID)
		job.values[index] = sortValue(job.owner, job.column, info)
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

local function invalidateFilterJobs(owner)
	owner._filterToken = (owner._filterToken or 0) + 1
	finishOwnedFilterScanBatch(owner)
	return owner._filterToken
end

local function invalidateAsyncJobs(owner)
	invalidateFilterJobs(owner)
	invalidateSortJobs(owner)
end

function Result:InvalidateAsyncJobs()
	invalidateAsyncJobs(self)
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
	collectSortBatch({
		owner = self,
		token = token,
		ids = ids,
		column = spec.column or "title",
		ascending = spec.asc ~= false,
		values = {},
		pins = {},
		cursor = 1,
		batchSize = batchSize,
		async = canYield,
		callback = onComplete,
	})
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
	return spec, client, database
end

function Result:NeedsPostFilters()
	if not (GF.ListFilter and GF.ListFilter.NeedsPostFilters) then
		return false
	end
	local spec, client, database = filterContext()
	return GF.ListFilter:NeedsPostFilters(spec, client, database)
end

local function refreshEntryPayload(entry, info)
	if not (entry and info and entry.info ~= info) then
		return
	end
	entry.info = mergeStableText(entry.info, info)
	hydrateActivity(entry, entry.info)
	resetDisplayCounts(entry)
	resetBlockedIdentity(entry)
	resetLaonongIdentity(entry)
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

local function passesLocalRules(owner, resultID, info, context)
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
	then
		removeCachedRecord(owner, resultID)
		return false
	end
	if not entry and info then
		entry = Snapshot.NewEntry(resultID, info)
		populateCountDefaults(entry)
		owner.entryCache[resultID] = entry
	elseif entry then
		refreshEntryPayload(entry, info)
		populateCountDefaults(entry)
	end
	local blocklist = GF.Blocklist
	if blocklist and blocklist:ShouldHide(resultID, info) then
		return false
	end
	-- Blizzard appends application records missing from the current search
	-- result set. Joined/departed rows follow that visibility contract and do
	-- not disappear merely because the new search or local filters omit them.
	if joinedSupplement then
		return true
	end
	local listFilter = GF.ListFilter
	if listFilter and not listFilter:ShouldShowResult(
		resultID,
		entry,
		context.spec,
		context.client,
		context.database,
		info
	) then
		return false
	end
	return true
end

function Result:PruneSortInfoCache()
	if not (self.sortInfoCache and self.resultIDs) then
		return
	end
	local retained = {}
	for _, resultID in ipairs(self.resultIDs) do
		retained[resultID] = true
	end
	for resultID in pairs(self.sortInfoCache) do
		if not retained[resultID] then
			self.sortInfoCache[resultID] = nil
		end
	end
end

function Result:FilterUnavailableFromResults()
	local kept = {}
	local removed = 0
	for _, resultID in ipairs(self.resultIDs or {}) do
		local info = self.sortInfoCache and self.sortInfoCache[resultID]
		if not info then
			info = self._usingAggregatedResults
				and self:GetCachedSearchResultInfo(resultID)
				or nativeResultInfo(resultID)
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
				and not joinedSupplement)
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

local function filterInfo(owner, resultID)
	local info = owner:GetCachedSearchResultInfo(resultID)
	if not info and not owner._usingAggregatedResults then
		info = nativeResultInfo(resultID)
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
	job.owner:FilterUnavailableFromResults()
	finishOwnedFilterScanBatch(job.owner, job.token)
	if job.callback then
		job.callback()
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
		local info = filterInfo(job.owner, resultID)
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
	if not self:NeedsPostFilters() then
		self.resultIDs = source
		self.total = #source
		self:FilterUnavailableFromResults()
		if onComplete then
			onComplete()
		end
		return
	end

	if GF.Blocklist and GF.Blocklist.IsEnabled
		and GF.Blocklist:IsEnabled()
		and GF.Blocklist.BeginScanTipBatch
	then
		GF.Blocklist:BeginScanTipBatch()
		self._filterScanBatchToken = token
	end

	local spec, client, database = filterContext()
	local batchSize = GF.FILTER_BATCH or 25
	local canYield = onComplete ~= nil
		and #source > batchSize
		and C_Timer ~= nil
		and type(C_Timer.After) == "function"
	if not canYield then
		batchSize = math.max(1, #source)
	end
	runFilterBatch({
		owner = self,
		token = token,
		input = source,
		output = {},
		cursor = 1,
		batchSize = batchSize,
		async = canYield,
		context = { spec = spec, client = client, database = database },
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
			snapshot.needsSnapshot = nativeResultInfo(resultID) == nil
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

function Result:ReapplyClientFilters(onComplete)
	invalidateAsyncJobs(self)
	local retainedDeclines = captureFrozenDeclinedEntries(self)
	local source = self.apiResultIDs
	if source == nil then
		source = self.resultIDs
	end
	source = copySequence(source or {})
	injectRetainedDeclinedEntries(self, source, retainedDeclines, false)
	seedRetainedDeclinedEntries(self, retainedDeclines)
	self:RunPostFilterPass(source, function()
		self:SortResults(nil, onComplete)
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
	if not C_LFGList then
		return 0, {}
	end
	local reader
	if useFiltered then
		reader = C_LFGList.GetFilteredSearchResults
	else
		reader = C_LFGList.GetSearchResults
	end
	if not reader then
		return 0, {}
	end
	local count, ids = reader()
	return tonumber(count) or 0, type(ids) == "table" and ids or {}
end

local function chooseResultSource(owner)
	local aggregateIDs, aggregateTotal, aggregateInfo, aggregateCounts
	if GF.Search and GF.Search.GetAggregatedResultIDs then
		aggregateIDs, aggregateTotal, aggregateInfo, aggregateCounts =
			GF.Search:GetAggregatedResultIDs()
	end
	owner._usingAggregatedResults = aggregateIDs ~= nil
	owner._aggregateInfoByID = aggregateInfo
	owner._aggregateMemberCountsByID = aggregateCounts
	if aggregateIDs then
		local ids = copySequence(aggregateIDs)
		return tonumber(aggregateTotal) or #ids, ids, true
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
		if info and not owner:ShouldHideUnavailableResult(resultID, info) then
			rememberSummary(owner, resultID, info)
			local entry = Snapshot.NewEntry(resultID, info)
			storeMemberCounts(
				entry,
				owner._aggregateMemberCountsByID
					and owner._aggregateMemberCountsByID[resultID]
			)
			populateCountDefaults(entry)
			owner.entryCache[resultID] = entry
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
	local apply = GF.Apply
	if apply then
		addCandidate(apply.currentGroupResultID)
	end

	local retained, added = {}, 0
	for _, resultID in ipairs(candidates) do
		local cached = owner:GetCachedSearchResultInfo(resultID)
		local live = nativeResultInfo(resultID)
		local info
		if live and cached then
			info = mergeStableText(cached, live)
		else
			info = live or cached
		end
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
			snapshot.needsSnapshot = nativeResultInfo(resultID) == nil
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

local function continueRefreshAfterFiltering(owner, callback)
	owner:SortResults(nil, callback)
end

function Result:RefreshCache(onComplete, beforePostFilters)
	invalidateAsyncJobs(self)
	local retainedCurrent = captureFrozenCurrentEntries(self)
	local retainedDeclines = captureFrozenDeclinedEntries(self)
	local selectedTotal, sourceIDs, aggregate = chooseResultSource(self)
	local ids = copySequence(sourceIDs)
	local joinedApplications, joinedCount =
		captureJoinedApplicationEntries(self, ids)
	local retainedCount = injectRetainedCurrentEntries(
		self, ids, retainedCurrent, aggregate)
	retainedCount = retainedCount + injectRetainedDeclinedEntries(
		self, ids, retainedDeclines, aggregate)
	retainedCount = retainedCount + joinedCount
	self.apiFilteredTotal = selectedTotal + retainedCount
	self.rawTotal = selectedTotal
	if not aggregate and C_LFGList and C_LFGList.GetSearchResults then
		local rawCount = C_LFGList.GetSearchResults()
		if rawCount ~= nil then
			self.rawTotal = rawCount
		end
	end

	self._cacheSig = table.concat({
		tostring(self.apiFilteredTotal),
		tostring(#ids),
		tostring(ids[1] or 0),
		tostring(ids[#ids] or 0),
	}, ":")
	self.entryCache = {}
	self.sortInfoCache = {}
	seedAggregateEntries(self, ids)
	seedJoinedApplicationEntries(self, joinedApplications)
	seedRetainedCurrentEntries(self, retainedCurrent)
	seedRetainedDeclinedEntries(self, retainedDeclines)
	self.apiResultIDs = ids
	self.resultIDs = ids
	if type(beforePostFilters) == "function" then
		beforePostFilters(ids)
	end
	self:ApplyPostFilters(function()
		continueRefreshAfterFiltering(self, onComplete)
	end)
end

-- Indexed access -----------------------------------------------------------

function Result:GetIndexForResultID(resultID)
	if type(resultID) ~= "number" then
		return nil
	end
	for index, candidate in ipairs(self.resultIDs or {}) do
		if candidate == resultID then
			return index
		end
	end
	return nil
end

function Result:GetEntryByResultID(resultID)
	if not (type(resultID) == "number" and resultID > 0) then
		return nil
	end
	self.entryCache = self.entryCache or {}
	if self.entryCache[resultID] then
		return self.entryCache[resultID]
	end
	local info = self.sortInfoCache and self.sortInfoCache[resultID]
	if not info then
		info = self._usingAggregatedResults
			and self:GetCachedSearchResultInfo(resultID)
			or nativeResultInfo(resultID)
	end
	if not info then
		return nil
	end
	if self:ShouldHideUnavailableResult(resultID, info) and not self:IsSoftUnavailable(info) then
		removeCachedRecord(self, resultID)
		return nil
	end
	local entry = Snapshot.NewEntry(resultID, info)
	populateCountDefaults(entry)
	self.entryCache[resultID] = entry
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
		if info and (not info.leaderName or info.leaderName == "") then
			local current = self:GetAuthoritativeSearchResultInfo(resultID)
			if current then
				entry.info = current
				info = current
			end
		end
		if not entry.leader or not entry.leader.name or entry.leader.name == "" then
			entry.leader = leaderFor(resultID, info and info.numMembers)
		end
		updateLeaderName(info, entry.leader)
	end

	local loadPlayers = options.loadPlayers
	if loadPlayers == nil then
		loadPlayers = self:ShouldLoadPlayersForEntry(entry)
	end
	if loadPlayers and not entry.players then
		entry.players, entry.hasLeaver = playersFor(resultID, entry.info.numMembers)
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
	local categoryID = entry.activity and entry.activity.categoryID
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
	local capacity = entry.activity and entry.activity.maxNumPlayers
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
			resetLaonongIdentity(entry)
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
	resetLaonongIdentity(entry)
	resetDisplayCounts(entry)
end

function Result:RefreshEntryInfo(resultID, suppliedInfo)
	if not resultID then
		return nil
	end
	local cached = self:GetCachedSearchResultInfo(resultID)
	local info = suppliedInfo
	local authoritativeRefresh = suppliedInfo ~= nil
	if info and cached and self._usingAggregatedResults
		and not self:IsLiveSearchResultInfoAuthoritative(resultID)
	then
		info = cached
		authoritativeRefresh = false
	end
	info = info or cached
	if not info and not self._usingAggregatedResults then
		info = nativeResultInfo(resultID)
		authoritativeRefresh = info ~= nil
	end
	if not info then
		return nil
	end
	if GF.ResolveSearchResultSocialCounts then
		GF.ResolveSearchResultSocialCounts(info, resultID)
	end

	self.entryCache = self.entryCache or {}
	local entry = self.entryCache[resultID]
	if entry and entry.info then
		info = mergeStableText(entry.info, info)
	end
	if self:ShouldHideUnavailableResult(resultID, info) then
		removeCachedRecord(self, resultID)
		return nil
	end
	if unreadableText(info.name) then
		local replacement = self:GetListingTitle(info, resultID)
		if replacement and replacement ~= UNKNOWN_TITLE then
			info.name = replacement
		end
	end

	if self.sortInfoCache then
		self.sortInfoCache[resultID] = info
	end
	if entry then
		entry.info = info
		if authoritativeRefresh and entry._gfRetainedCurrent == true
			and nativeResultInfo(resultID) ~= nil
		then
			entry._gfRetainedCurrent = nil
		end
		self:InvalidateEntryMembers(resultID)
		hydrateActivity(entry, info)
	else
		entry = self:GetEntryByResultID(resultID)
	end
	return entry
end

-- Frozen browse snapshot ---------------------------------------------------

function Result:CommitSnapshot()
	local order = self.resultIDs or {}
	local frozenOrder, frozenSet = {}, {}
	for position, resultID in ipairs(order) do
		frozenOrder[position] = resultID
		frozenSet[resultID] = true
	end
	self.frozenOrder = frozenOrder
	self.frozenSet = frozenSet
end

function Result:ClearFrozenSnapshot()
	self.frozenOrder = nil
	self.frozenSet = nil
end

function Result:IsFrozenResult(resultID)
	return resultID ~= nil
		and self.frozenSet ~= nil
		and self.frozenSet[resultID] == true
end

function Result:RemoveFromFrozen(resultID)
	if not self:IsFrozenResult(resultID) then
		return false
	end
	self.frozenSet[resultID] = nil
	local retained = {}
	for _, candidate in ipairs(self.frozenOrder or self.resultIDs or {}) do
		if candidate ~= resultID then
			retained[#retained + 1] = candidate
		end
	end
	self.frozenOrder = retained
	self.resultIDs = retained
	self.total = #retained
	removeCachedRecord(self, resultID)
	return true
end

function Result:MarkSoftUnavailable(resultID, suppliedInfo)
	if not resultID then
		return nil
	end
	self.entryCache = self.entryCache or {}
	self.sortInfoCache = self.sortInfoCache or {}
	local entry = self.entryCache[resultID]
	local info = suppliedInfo or (entry and entry.info) or self.sortInfoCache[resultID]
	if not info then
		return nil
	end
	if not self:ShouldSoftUnavailableResult(resultID, info) then
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
	self.sortInfoCache[resultID] = info
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
	return C_LFGList.ApplyToGroup(resultID, tank, healer, damage)
end

function Result:Clear()
	invalidateAsyncJobs(self)
	self.total, self.rawTotal, self.apiFilteredTotal = 0, 0, 0
	self.resultIDs, self.entryCache, self.sortInfoCache = {}, {}, {}
	self.apiResultIDs = nil
	self.frozenOrder = nil
	self.frozenSet = nil
	self._usingAggregatedResults = nil
	self._aggregateInfoByID = nil
	self._aggregateMemberCountsByID = nil
	if GF.Search and GF.Search.ClearAggregatedResultIDs then
		GF.Search:ClearAggregatedResultIDs()
	end
	if C_LFGList and C_LFGList.ClearSearchResults then
		if GF.Search and GF.Search.ReleaseNativeSearchSelection then
			GF.Search:ReleaseNativeSearchSelection()
		end
		C_LFGList.ClearSearchResults()
	end
end

function Result:DiscardBrowseSource()
	-- Abandon an uncommitted browse transaction without clearing Blizzard's
	-- native result store.  Keep sortInfoCache as a stable-text fallback for the
	-- next search so a current/joined application can still be reconstructed
	-- from GetApplications() after its listing disappears from native results.
	invalidateAsyncJobs(self)
	self.total, self.rawTotal, self.apiFilteredTotal = 0, 0, 0
	self.resultIDs, self.entryCache = {}, {}
	self.apiResultIDs = nil
	self.frozenOrder = nil
	self.frozenSet = nil
	self._usingAggregatedResults = nil
	self._aggregateInfoByID = nil
	self._aggregateMemberCountsByID = nil
	if GF.Search and GF.Search.ClearAggregatedResultIDs then
		GF.Search:ClearAggregatedResultIDs()
	end
end
