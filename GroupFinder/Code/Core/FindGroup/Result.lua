local _, GF = ...

GF.Result = {}

local Snapshot = GF.SearchResultSnapshot

local DUNGEON_SCORE_FALLBACK_COLORS = {
	{ min = 2500, color = { r = 1, g = 0.5, b = 0 } },
	{ min = 2000, color = { r = 0.64, g = 0.21, b = 0.93 } },
	{ min = 1500, color = { r = 0, g = 0.44, b = 0.87 } },
	{ min = 1000, color = { r = 0.12, g = 1, b = 0.12 } },
}

local function getFallbackDungeonScoreColor(score)
	score = tonumber(score) or 0
	for _, band in ipairs(DUNGEON_SCORE_FALLBACK_COLORS) do
		if score >= band.min then
			return band.color
		end
	end
	return HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
end

local function getDungeonScoreColor(score)
	return getFallbackDungeonScoreColor(score)
end

function GF.Result:GetDungeonScoreColor(score, delistedColor)
	if delistedColor then
		return delistedColor
	end
	return getDungeonScoreColor(score)
end

local KSTRING_BAD_LFG_NAME = "|Kr0|k"
local UNKNOWN_LFG_TEXTS = {
	["未知目标"] = true,
	["未知目標"] = true,
	["Unknown Target"] = true,
}
local lfgTextProbeFrame
local lfgTextProbeFontString

local function isSecretLfgText(text)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, text)
	return ok and secret == true
end

local function normalizeLfgText(text)
	text = tostring(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	if strtrim then
		text = strtrim(text)
	end
	return text
end

local function isPlainUnreadableLfgText(text)
	if isSecretLfgText(text) then
		return true
	end
	if text == nil then
		return true
	end
	local textType = type(text)
	if textType ~= "string" and textType ~= "number" then
		return true
	end
	text = normalizeLfgText(text)
	if text == "" then
		return true
	end
	if text == KSTRING_BAD_LFG_NAME then
		return true
	end
	if text == "?" then
		return true
	end
	if UNKNOWN_LFG_TEXTS[text] then
		return true
	end
	if _G.UNKNOWNOBJECT and text == _G.UNKNOWNOBJECT then
		return true
	end
	if _G.UNKNOWNBEING and text == _G.UNKNOWNBEING then
		return true
	end
	return false
end

local function getRenderedLfgText(text)
	if type(text) ~= "string" or not text:find("|K", 1, true) then
		return text
	end
	if not CreateFrame then
		return text
	end
	if not lfgTextProbeFrame then
		lfgTextProbeFrame = CreateFrame("Frame")
		lfgTextProbeFrame:Hide()
		lfgTextProbeFontString = lfgTextProbeFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	end
	lfgTextProbeFontString:SetText(text)
	return lfgTextProbeFontString:GetText()
end

local function isRenderedUnreadableLfgText(text)
	if isSecretLfgText(text) then
		return true
	end
	local rendered = getRenderedLfgText(text)
	if rendered == text then
		return false
	end
	return isPlainUnreadableLfgText(rendered)
end

local function isLfgKstringText(text)
	if isSecretLfgText(text) then
		return false
	end
	return type(text) == "string" and text:find("|K", 1, true) ~= nil
end

local function isUnreadableLfgText(text)
	if isPlainUnreadableLfgText(text) then
		return true
	end
	return isRenderedUnreadableLfgText(text)
end

local function isDisplayableLfgSearchText(text)
	return not isUnreadableLfgText(text)
end

local function getListingCommentQuality(comment)
	if isSecretLfgText(comment) then
		return 1
	end
	if isDisplayableLfgSearchText(comment) then
		return 2
	end
	return 0
end

function GF.Result:IsUnreadableLfgText(text)
	return isUnreadableLfgText(text)
end

function GF.Result:IsRenderedUnreadableLfgText(text)
	return isRenderedUnreadableLfgText(text)
end

function GF.Result:IsDisplayableLfgSearchText(text)
	return isDisplayableLfgSearchText(text)
end

function GF.Result:IsSecretLfgText(text)
	return isSecretLfgText(text)
end

function GF.Result:HasRenderableListingComment(comment)
	return getListingCommentQuality(comment) > 0
end

local function mergeReadableSearchInfo(prev, fresh)
	if not fresh then
		return prev
	end
	if not prev then
		return fresh
	end
	if isDisplayableLfgSearchText(prev.name) and not isDisplayableLfgSearchText(fresh.name) then
		fresh.name = prev.name
	end
	if isDisplayableLfgSearchText(prev.leaderName) and not isDisplayableLfgSearchText(fresh.leaderName) then
		fresh.leaderName = prev.leaderName
	end
	if getListingCommentQuality(prev.comment) > getListingCommentQuality(fresh.comment) then
		fresh.comment = prev.comment
	end
	return fresh
end

local function titleFromQuestComment(comment)
	if isSecretLfgText(comment) then
		return nil
	end
	if not comment or comment == "" then
		return nil
	end
	local inner = comment:match("%[(.-)%]")
	if inner and inner ~= "" and isDisplayableLfgSearchText(inner) then
		return inner
	end
	return nil
end

local function resolveQuestTitle(questID)
	if not questID or questID <= 0 then
		return nil
	end
	if QuestUtils_GetQuestName then
		local name = QuestUtils_GetQuestName(questID)
		if not isUnreadableLfgText(name) then
			return name
		end
	end
	if C_QuestLog and C_QuestLog.GetTitleForQuestID then
		local name = C_QuestLog.GetTitleForQuestID(questID)
		if not isUnreadableLfgText(name) then
			return name
		end
	end
	return nil
end

local function getPrimaryActivityID(info)
	return Snapshot.GetPrimaryActivityID(info)
end

local function getActivityInfoForResult(info, activityID)
	return Snapshot.GetActivityInfo(info, activityID)
end

local function resolveActivityInfo(info, activityInfo)
	return Snapshot.ResolveActivityInfo(info, activityInfo)
end

local function hydrateEntryActivity(entry, info)
	Snapshot.HydrateEntry(entry, info)
end

local function getSearchResultInvalidReason(info, activityInfo)
	if not info then
		return "missing"
	end
	if not getPrimaryActivityID(info) then
		return "missing_activity"
	end
	local activity = resolveActivityInfo(info, activityInfo)
	if not activity then
		return "missing_activity_info"
	end
	if info.isDelisted == true then
		return "unavailable"
	end
	local maxMembers = tonumber(activity.maxNumPlayers) or 0
	local numMembers = tonumber(info.numMembers) or 0
	if maxMembers > 0 and numMembers >= maxMembers then
		return "unavailable"
	end
	return nil
end

local function clearCachedResult(self, resultID)
	if self.entryCache then
		self.entryCache[resultID] = nil
	end
	if self.sortInfoCache then
		self.sortInfoCache[resultID] = nil
	end
end

local function readSearchResultInfo(resultID)
	if not resultID or not C_LFGList or not C_LFGList.GetSearchResultInfo then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
	if ok then
		return info
	end
	return nil
end

local function hasLiveSearchResultInfo(resultID)
	if not resultID or not C_LFGList or not C_LFGList.HasSearchResultInfo then
		return true
	end
	local ok, hasInfo = pcall(C_LFGList.HasSearchResultInfo, resultID)
	return ok and hasInfo == true
end

function GF.Result:IsLiveSearchResultInfoAuthoritative(resultID)
	if not resultID or not C_LFGList or not C_LFGList.GetSearchResultInfo then
		return false
	end
	if not self._usingAggregatedResults then
		return true
	end
	return hasLiveSearchResultInfo(resultID)
end

function GF.Result:GetCachedSearchResultInfo(resultID)
	if not resultID then
		return nil
	end
	local entry = self.entryCache and self.entryCache[resultID]
	if entry and entry.info then
		return entry.info
	end
	if self.sortInfoCache and self.sortInfoCache[resultID] then
		return self.sortInfoCache[resultID]
	end
	if self._aggregateInfoByID then
		return self._aggregateInfoByID[resultID]
	end
	return nil
end

function GF.Result:GetAuthoritativeSearchResultInfo(resultID)
	local cached = self:GetCachedSearchResultInfo(resultID)
	if self:IsLiveSearchResultInfoAuthoritative(resultID) then
		local fresh = readSearchResultInfo(resultID)
		if fresh and cached then
			return mergeReadableSearchInfo(cached, fresh)
		end
		return fresh or cached
	end
	return cached
end

function GF.Result:GetLiveSearchResultInfoForUpdate(resultID)
	if not self:IsLiveSearchResultInfoAuthoritative(resultID) then
		return nil, "not_current"
	end
	return readSearchResultInfo(resultID)
end

local function invalidateDisplayCounts(entry)
	if entry then
		entry._displayCounts = nil
		entry._displayCountsLoaded = nil
	end
end

local function invalidateBlockedMemberCache(entry)
	if entry then
		entry._blockedMemberChecked = nil
		entry._blockedMemberRevision = nil
		entry._blockedMember = nil
		entry._blockedMemberRow = nil
		entry.hasBlockedMember = nil
	end
end

local function invalidateLaonongFanMemberCache(entry)
	if entry and GF.FindGroup and GF.FindGroup.InvalidateLaonongFanMemberCache then
		GF.FindGroup:InvalidateLaonongFanMemberCache(entry)
	end
end

local function applyDisplayMemberCounts(entry, counts)
	if not entry or type(counts) ~= "table" then
		return
	end
	entry._displayCounts = counts
	entry._displayCountsLoaded = true
	entry.tanks = counts.TANK or entry.tanks or 0
	entry.heals = counts.HEALER or entry.heals or 0
	entry.dps = counts.DAMAGER or entry.dps or 0
	entry._memberCountsLoaded = true
end

local function ensureMemberCounts(entry)
	if not entry then
		return
	end
	GF.Result:GetDisplayMemberCounts(entry)
	entry.tanks = entry.tanks or 0
	entry.heals = entry.heals or 0
	entry.dps = entry.dps or 0
end

function GF.Result:GetDisplayMemberCounts(entry)
	if not entry or not entry.resultID then
		return nil
	end
	if entry._displayCountsLoaded and entry._displayCounts then
		return entry._displayCounts
	end
	if not C_LFGList.GetSearchResultMemberCounts then
		return nil
	end
	local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, entry.resultID)
	if not ok then
		return nil
	end
	if type(counts) == "table" then
		applyDisplayMemberCounts(entry, counts)
	end
	return entry._displayCounts
end

local function getLeaderPvpRatingInfo(info, activityInfo)
	activityInfo = resolveActivityInfo(info, activityInfo)
	if not activityInfo or not activityInfo.isRatedPvpActivity then
		return nil
	end
	local ratings = info and info.leaderPvpRatingInfo
	local ratingInfo = ratings and ratings[1]
	if ratingInfo and type(ratingInfo.rating) == "number" and ratingInfo.rating >= 0 then
		return ratingInfo
	end
	return nil
end

local function getLeaderPvpRating(info, activityInfo)
	local ratingInfo = getLeaderPvpRatingInfo(info, activityInfo)
	return ratingInfo and ratingInfo.rating
end

function GF.Result:GetLeaderPvpRatingInfo(info, activityInfo)
	local ratingInfo = getLeaderPvpRatingInfo(info, activityInfo)
	if not ratingInfo then
		return nil
	end
	local tierName = (PVPUtil and PVPUtil.GetTierName) and PVPUtil.GetTierName(ratingInfo.tier) or ""
	return ratingInfo, tierName
end

function GF.Result:GetLeaderPvpRatingTooltipLine(info, activityInfo)
	local ratingInfo, tierName = self:GetLeaderPvpRatingInfo(info, activityInfo)
	if not ratingInfo or not PVP_RATING_GROUP_FINDER then
		return nil
	end
	return PVP_RATING_GROUP_FINDER:format(ratingInfo.activityName, ratingInfo.rating, tierName)
end

function GF.Result:GetListingComment(info, resultID)
	if not info then
		return ""
	end
	local comment = info.comment
	if isSecretLfgText(comment) then
		return comment
	end
	comment = comment or ""
	local shouldRefreshComment = false
	if comment ~= "" and isUnreadableLfgText(comment) then
		shouldRefreshComment = true
	end
	if shouldRefreshComment then
		comment = ""
	end
	if shouldRefreshComment and resultID then
		local fresh = self:GetAuthoritativeSearchResultInfo(resultID)
		if fresh then
			if fresh.questID and not info.questID then
				info.questID = fresh.questID
			end
			if isDisplayableLfgSearchText(fresh.name) and not isDisplayableLfgSearchText(info.name) then
				info.name = fresh.name
			end
			if isSecretLfgText(fresh.comment) then
				info.comment = fresh.comment
				return fresh.comment
			elseif isDisplayableLfgSearchText(fresh.comment) then
				info.comment = fresh.comment
				comment = fresh.comment
			end
		end
	end
	if comment == "" and info.questID and LFGListUtil_GetQuestDescription then
		comment = LFGListUtil_GetQuestDescription(info.questID) or ""
		if isUnreadableLfgText(comment) then
			comment = ""
		end
	end
	if info.questID and comment ~= "" and comment:match("%[%s*%]") then
		local questTitle = resolveQuestTitle(info.questID)
		if questTitle then
			local fmt = AUTO_GROUP_CREATION_NORMAL_QUEST
			if QuestUtils_IsQuestWorldQuest and QuestUtils_IsQuestWorldQuest(info.questID) then
				fmt = AUTO_GROUP_CREATION_WORLD_QUEST or fmt
			end
			if fmt then
				comment = string.format(fmt, questTitle)
			end
		end
	end
	return comment
end

function GF.Result:GetListingTitle(info, resultID)
	if not info then
		return "?"
	end
	if isDisplayableLfgSearchText(info.name) then
		return info.name
	end
	if resultID then
		local fresh = self:GetAuthoritativeSearchResultInfo(resultID)
		if fresh then
			if fresh.questID and not info.questID then
				info.questID = fresh.questID
			end
			if isDisplayableLfgSearchText(fresh.name) then
				info.name = fresh.name
				return fresh.name
			end
			local questTitle = resolveQuestTitle(fresh.questID or info.questID)
			if questTitle then
				info.name = questTitle
				return questTitle
			end
		end
	end
	local questTitle = resolveQuestTitle(info.questID)
	if questTitle then
		return questTitle
	end
	local fromComment = titleFromQuestComment(self:GetListingComment(info, resultID))
	if fromComment then
		return fromComment
	end
	return "?"
end

function GF.Result:IsDirtySearchResult(resultID, info)
	if not info then
		return false
	end
	if isDisplayableLfgSearchText(info.name) then
		return false
	end
	local resolved = self:GetListingTitle(info, resultID)
	if resolved and isDisplayableLfgSearchText(resolved) then
		info.name = resolved
		return false
	end
	return true
end

local function resolveBrowseScore(info, activityInfo)
	if not info then
		return nil, "none"
	end
	local pvpRating = getLeaderPvpRating(info, activityInfo)
	if pvpRating then
		return pvpRating, "pvp"
	end
	activityInfo = resolveActivityInfo(info, activityInfo)
	if activityInfo and activityInfo.isPvpActivity then
		return nil, "pvp"
	end
	local dungeonScore = info.leaderOverallDungeonScore
	if dungeonScore and dungeonScore > 0 then
		return dungeonScore, "dungeon"
	end
	return nil, "none"
end

function GF.Result:GetBrowseScoreSortKey(info, activityInfo)
	if not info then
		return 0
	end
	local value, kind = resolveBrowseScore(info, activityInfo)
	if kind == "pvp" then
		return value or 0
	end
	if kind == "dungeon" then
		return value
	end
	return 0
end

function GF.Result:GetBrowseScoreDisplay(info, activityInfo, delistedColor)
	if not info then
		return nil, nil
	end
	local value, kind = resolveBrowseScore(info, activityInfo)
	if kind == "pvp" then
		if value then
			return tostring(value), delistedColor or GF.GetPvpRatingColor(value)
		end
		return nil, nil
	end
	if kind ~= "dungeon" then
		return nil, nil
	end
	local color
	if delistedColor then
		color = delistedColor
	else
		color = self:GetDungeonScoreColor(value)
	end
	return tostring(value), color
end

local function fetchLeaderPlayer(resultID, numMembers)
	if not resultID then
		return nil
	end
	if not numMembers or numMembers <= 0 then
		local info = GF.Result and GF.Result.GetAuthoritativeSearchResultInfo
			and GF.Result:GetAuthoritativeSearchResultInfo(resultID)
		numMembers = info and info.numMembers or 0
	end
	local fallback
	for i = 1, numMembers or 0 do
		local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
		if ok and playerInfo then
			if playerInfo.isLeader then
				return playerInfo
			end
			if i == 1 and playerInfo.name and playerInfo.name ~= "" then
				fallback = playerInfo
			end
		end
	end
	return fallback
end

local function syncLeaderNameFromPlayer(info, leader)
	if info and (not info.leaderName or info.leaderName == "") and leader and leader.name then
		info.leaderName = leader.name
	end
end

local function fetchAllPlayers(resultID, numMembers)
	local list = {}
	local hasLeaver = false
	for i = 1, numMembers or 0 do
		local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
		if ok and playerInfo then
			list[#list + 1] = playerInfo
			if playerInfo.isLeaver then
				hasLeaver = true
			end
		end
	end
	return list, hasLeaver
end

local function getFilterContext()
	local selection = GF.FindGroupTab and GF.FindGroupTab.GetSelection and GF.FindGroupTab:GetSelection()
	local spec = selection and GF.FilterSpec and GF.FilterSpec:ResolveSpec(selection)
	local client = spec and GF.Filter and GF.Filter:GetClientFilters(spec.clientKey)
	local db = (GF.Filter and GF.Filter.GetGlobalFilters and GF.Filter:GetGlobalFilters(spec)) or GF.GetDB()
	return spec, client, db
end

function GF.Result:NeedsPostFilters()
	local spec, client, db = getFilterContext()
	if GF.ListFilter and GF.ListFilter.NeedsPostFilters then
		return GF.ListFilter:NeedsPostFilters(spec, client, db)
	end
	return false
end

function GF.Result:GetActivitySortKey(info)
	local actID = getPrimaryActivityID(info)
	if not actID then
		return ""
	end
	local activity = getActivityInfoForResult(info, actID)
	local name = activity and (activity.fullName or activity.shortName)
	if name and name ~= "" then
		return name
	end
	if C_LFGList.GetActivityFullName then
		return C_LFGList.GetActivityFullName(actID) or ""
	end
	return tostring(actID)
end

function GF.Result:SortResults(_mode, onComplete)
	if not self.resultIDs or #self.resultIDs < 2 then
		if self.resultIDs and GF.Apply and GF.Apply.PinApplicationsToTop then
			self.resultIDs = GF.Apply:PinApplicationsToTop(self.resultIDs)
		end
		if onComplete then
			onComplete()
		end
		return
	end
	local sortToken = self._sortToken
	local function done()
		if sortToken ~= self._sortToken then
			return
		end
		if onComplete then
			onComplete()
		end
	end
	local LC = GF.ListColumns
	local sortSpec = LC and LC.GetBrowseSort and LC:GetBrowseSort() or { column = "title", asc = true }
	local sortCol = sortSpec.column or "title"
	local sortAsc = sortSpec.asc ~= false
	local ids = self.resultIDs
	local cache = self.sortInfoCache
	local entryCache = self.entryCache
	local keys = {}
	local socialPins = {}
	local batchSize = GF.BROWSE_SORT_KEY_BATCH or 25
	local idx = 1

	local function seedEntry(resultID, info)
		if not info or not resultID or self:ShouldHideUnavailableResult(resultID, info) then
			return
		end
		if cache then
			cache[resultID] = info
		end
		if entryCache and not entryCache[resultID] then
			entryCache[resultID] = Snapshot.NewEntry(resultID, info)
		end
	end

	local function fetchSortKey(info, resultID)
		if not info then
			return 0
		end
		if sortCol == "ilvl" then
			return info.requiredItemLevel or 0
		end
		if sortCol == "score" then
			return self:GetBrowseScoreSortKey(info)
		end
		if sortCol == "activity" then
			return self:GetActivitySortKey(info)
		end
		if sortCol == "roles" then
			return info.numMembers or 0
		end
		return info.age or 0
	end

	local function finishSort()
		local order = {}
		for i = 1, #ids do
			order[i] = i
		end
		table.sort(order, function(ia, ib)
			local pa, pb = socialPins[ia] or 1, socialPins[ib] or 1
			if pa ~= pb then
				return pa < pb
			end
			local va, vb = keys[ia], keys[ib]
			if va ~= vb then
				if sortAsc then
					return va < vb
				end
				return va > vb
			end
			return ids[ia] < ids[ib]
		end)
		local sorted = {}
		for _, i in ipairs(order) do
			sorted[#sorted + 1] = ids[i]
		end
		self.resultIDs = sorted
		if GF.Apply and GF.Apply.PinApplicationsToTop then
			self.resultIDs = GF.Apply:PinApplicationsToTop(self.resultIDs)
		end
		done()
	end

	local function fetchKeyBatch()
		if sortToken ~= self._sortToken then
			return
		end
		local last = math.min(idx + batchSize - 1, #ids)
		for j = idx, last do
			local resultID = ids[j]
			local info = cache and cache[resultID]
			if not info then
				if self._usingAggregatedResults then
					info = self:GetCachedSearchResultInfo(resultID)
				else
					info = readSearchResultInfo(resultID)
				end
				seedEntry(resultID, info)
			end
			socialPins[j] = GF.GetSearchResultSocialSortPin and GF.GetSearchResultSocialSortPin(info, resultID) or 1
			keys[j] = fetchSortKey(info, resultID)
		end
		idx = last + 1
		if idx > #ids then
			finishSort()
		elseif onComplete and C_Timer and C_Timer.After then
			C_Timer.After(0, fetchKeyBatch)
		else
			fetchKeyBatch()
		end
	end

	if onComplete and C_Timer and C_Timer.After and #ids > batchSize then
		fetchKeyBatch()
		return
	end

	for i, resultID in ipairs(ids) do
		local info = cache and cache[resultID]
		if not info then
			if self._usingAggregatedResults then
				info = self:GetCachedSearchResultInfo(resultID)
			else
				info = readSearchResultInfo(resultID)
			end
			seedEntry(resultID, info)
		end
		socialPins[i] = GF.GetSearchResultSocialSortPin and GF.GetSearchResultSocialSortPin(info, resultID) or 1
		keys[i] = fetchSortKey(info, resultID)
	end
	finishSort()
end

function GF.Result:ShouldHideDelisted(info)
	return info and info.isDelisted == true
end

function GF.Result:IsSoftUnavailable(info)
	return info and (info._gfSoftUnavailable == true or info.isDelisted == true)
end

function GF.Result:GetSearchResultInvalidReason(resultID, info, activityInfo)
	local reason = getSearchResultInvalidReason(info, activityInfo)
	if reason and reason ~= "unavailable" then
		return reason
	end
	if info and isLfgKstringText(info.name) and not self:IsLiveSearchResultInfoAuthoritative(resultID) then
		return "dirty"
	end
	if self:IsDirtySearchResult(resultID, info) then
		return "dirty"
	end
	return reason
end

function GF.Result:IsSearchResultAvailable(resultID, info, activityInfo)
	return self:GetSearchResultInvalidReason(resultID, info, activityInfo) == nil
end

function GF.Result:ShouldHideUnavailableResult(resultID, info, activityInfo)
	return self:GetSearchResultInvalidReason(resultID, info, activityInfo) ~= nil
end

function GF.Result:ShouldSoftUnavailableResult(resultID, info, activityInfo)
	return self:GetSearchResultInvalidReason(resultID, info, activityInfo) == "unavailable"
end

function GF.Result:MarkSoftUnavailable(resultID, info)
	if not resultID then
		return nil
	end
	self.entryCache = self.entryCache or {}
	self.sortInfoCache = self.sortInfoCache or {}
	local entry = self.entryCache[resultID]
	info = info or (entry and entry.info) or self.sortInfoCache[resultID]
	if not info then
		return nil
	end
	if not self:ShouldSoftUnavailableResult(resultID, info) then
		clearCachedResult(self, resultID)
		return nil
	end
	info._gfSoftUnavailable = true
	info.isDelisted = true
	if entry then
		entry.info = info
		hydrateEntryActivity(entry, info)
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

function GF.Result:FilterUnavailableFromResults()
	local ids = self.resultIDs or {}
	local filtered = {}
	local removed = 0
	for _, resultID in ipairs(ids) do
		local info = self.sortInfoCache and self.sortInfoCache[resultID]
		local entry = self.entryCache and self.entryCache[resultID]
		if not info then
			if self._usingAggregatedResults then
				info = self:GetCachedSearchResultInfo(resultID)
			else
				info = readSearchResultInfo(resultID)
			end
			if info then
				self.sortInfoCache = self.sortInfoCache or {}
				self.sortInfoCache[resultID] = info
			end
		end
		if entry and entry.info and info then
			info = mergeReadableSearchInfo(entry.info, info)
		end
		if self:ShouldHideUnavailableResult(resultID, info) then
			removed = removed + 1
			clearCachedResult(self, resultID)
		else
			filtered[#filtered + 1] = resultID
		end
	end
	if removed > 0 then
		self.resultIDs = filtered
		self.total = #filtered
	end
	return removed
end

function GF.Result:FilterDelistedFromResults()
	return self:FilterUnavailableFromResults()
end

function GF.Result:PruneSortInfoCache()
	if not self.sortInfoCache or not self.resultIDs then
		return
	end
	local keep = {}
	for _, resultID in ipairs(self.resultIDs) do
		keep[resultID] = true
	end
	for resultID in pairs(self.sortInfoCache) do
		if not keep[resultID] then
			self.sortInfoCache[resultID] = nil
		end
	end
end

local function shouldKeepResult(self, resultID, info, spec, client, db)
	self.entryCache = self.entryCache or {}
	local entry = self.entryCache[resultID]
	if entry and entry.info and info then
		info = mergeReadableSearchInfo(entry.info, info)
	end
	if self:ShouldHideUnavailableResult(resultID, info) then
		clearCachedResult(self, resultID)
		return false
	end
	if not entry and info then
		entry = Snapshot.NewEntry(resultID, info)
		ensureMemberCounts(entry)
		self.entryCache[resultID] = entry
	elseif entry then
		if info and entry.info ~= info then
			entry.info = mergeReadableSearchInfo(entry.info, info)
			hydrateEntryActivity(entry, entry.info)
			invalidateDisplayCounts(entry)
			invalidateBlockedMemberCache(entry)
			invalidateLaonongFanMemberCache(entry)
		end
		ensureMemberCounts(entry)
	end
	if GF.Blocklist and GF.Blocklist:ShouldHide(resultID, info) then
		return false
	end
	if GF.ListFilter and not GF.ListFilter:ShouldShowResult(resultID, entry, spec, client, db, info) then
		return false
	end
	return true
end

function GF.Result:RunPostFilterPass(raw, onComplete)
	raw = raw or self.apiResultIDs or self.resultIDs or {}
	local spec, client, db = getFilterContext()

	local function finishSimple()
		self.resultIDs = raw
		self.total = #raw
		self:FilterUnavailableFromResults()
		if onComplete then
			onComplete()
		end
	end

	if not self:NeedsPostFilters() then
		finishSimple()
		return
	end

	if GF.Blocklist and GF.Blocklist:IsEnabled() and GF.Blocklist.BeginScanTipBatch then
		GF.Blocklist:BeginScanTipBatch()
	end

	local batchSize = GF.FILTER_BATCH or 25
	local useBatch = onComplete and #raw > batchSize and C_Timer and C_Timer.After
	local filterToken = (self._filterToken or 0) + 1
	self._filterToken = filterToken
	local filtered = {}
	local idx = 1

	local function cacheInfo(resultID, info)
		if info then
			self.sortInfoCache = self.sortInfoCache or {}
			self.sortInfoCache[resultID] = info
		end
	end

	local function finishFilter()
		if filterToken ~= self._filterToken then
			return
		end
		self.resultIDs = filtered
		self.total = #filtered
		self:PruneSortInfoCache()
		self:FilterUnavailableFromResults()
		if GF.Blocklist and GF.Blocklist.EndScanTipBatch then
			GF.Blocklist:EndScanTipBatch()
		end
		if onComplete then
			onComplete()
		end
	end

	local function processOne(resultID)
		local info = self:GetCachedSearchResultInfo(resultID)
		if not info and not self._usingAggregatedResults then
			info = readSearchResultInfo(resultID)
			cacheInfo(resultID, info)
		elseif info then
			cacheInfo(resultID, info)
		end
		if shouldKeepResult(self, resultID, info, spec, client, db) then
			filtered[#filtered + 1] = resultID
		end
	end

	local function processBatch()
		if filterToken ~= self._filterToken then
			return
		end
		local last = math.min(idx + batchSize - 1, #raw)
		for j = idx, last do
			processOne(raw[j])
		end
		idx = last + 1
		if idx > #raw then
			finishFilter()
		elseif C_Timer and C_Timer.After then
			C_Timer.After(0, processBatch)
		else
			processBatch()
		end
	end

	if useBatch then
		processBatch()
		return
	end

	for _, resultID in ipairs(raw) do
		processOne(resultID)
	end
	finishFilter()
end

function GF.Result:ApplyPostFilters(onComplete)
	self:RunPostFilterPass(self.apiResultIDs or self.resultIDs, onComplete)
end

function GF.Result:ReapplyClientFilters(onComplete)
	local raw = self.apiResultIDs
	if not raw or #raw == 0 then
		raw = self.resultIDs
	end
	if not raw or #raw == 0 then
		if onComplete then
			onComplete()
		end
		return
	end
	self._sortToken = (self._sortToken or 0) + 1
	self:RunPostFilterPass(raw, function()
		self:SortResults(nil, onComplete)
	end)
end

function GF.Result:RefreshCache(onComplete)
	local hasKeyword, ownsSearch = false, false
	if GF.FindGroupTab and GF.FindGroupTab.GetBrowseSearchState then
		hasKeyword, ownsSearch = GF.FindGroupTab:GetBrowseSearchState()
	end
	local useRaw = ownsSearch and not hasKeyword
	local filteredTotal, filtered = 0, {}
	local aggregateIDs, aggregateTotal, aggregateInfoByID, aggregateMemberCountsByID
	if GF.Search and GF.Search.GetAggregatedResultIDs then
		aggregateIDs, aggregateTotal, aggregateInfoByID, aggregateMemberCountsByID = GF.Search:GetAggregatedResultIDs()
	end
	self._usingAggregatedResults = aggregateIDs ~= nil
	self._aggregateInfoByID = aggregateInfoByID
	self._aggregateMemberCountsByID = aggregateMemberCountsByID

	if aggregateIDs then
		filtered = {}
		for i, resultID in ipairs(aggregateIDs) do
			filtered[i] = resultID
		end
		filteredTotal = aggregateTotal or #filtered
		self.apiFilteredTotal = filteredTotal
	elseif hasKeyword and C_LFGList.GetFilteredSearchResults then
		filteredTotal, filtered = C_LFGList.GetFilteredSearchResults()
		filteredTotal = filteredTotal or 0
		filtered = filtered or {}
		self.apiFilteredTotal = filteredTotal
	elseif useRaw and C_LFGList.GetSearchResults then
		filteredTotal, filtered = C_LFGList.GetSearchResults()
		filteredTotal = filteredTotal or 0
		filtered = filtered or {}
		self.apiFilteredTotal = filteredTotal
	else
		if C_LFGList.GetFilteredSearchResults then
			filteredTotal, filtered = C_LFGList.GetFilteredSearchResults()
		end
		self.apiFilteredTotal = filteredTotal or 0
		filtered = filtered or {}
	end

	self.rawTotal = self.apiFilteredTotal
	if aggregateIDs then
		self.rawTotal = filteredTotal or #filtered
	elseif C_LFGList.GetSearchResults then
		local rawTotal = C_LFGList.GetSearchResults()
		if rawTotal then
			self.rawTotal = rawTotal
		end
	end
	local newSig = string.format("%d:%d:%d:%d",
		filteredTotal or 0,
		#filtered,
		filtered[1] or 0,
		filtered[#filtered] or 0)
	if self._cacheSig ~= newSig then
		self._cacheSig = newSig
	end
	-- 每次 RefreshCache 清空条目缓存，避免 isDelisted 等字段刷新后仍显示旧色
	self.entryCache = {}
	self.sortInfoCache = {}
	if aggregateInfoByID then
		for _, resultID in ipairs(filtered or {}) do
			local info = aggregateInfoByID[resultID]
			if info and not self:ShouldHideUnavailableResult(resultID, info) then
				self.sortInfoCache[resultID] = info
				local entry = Snapshot.NewEntry(resultID, info)
				applyDisplayMemberCounts(entry, aggregateMemberCountsByID and aggregateMemberCountsByID[resultID])
				ensureMemberCounts(entry)
				self.entryCache[resultID] = entry
			end
		end
	end
	self.apiResultIDs = filtered
	self.resultIDs = filtered
	self._filterToken = (self._filterToken or 0) + 1
	self:ApplyPostFilters(function()
		self._sortToken = (self._sortToken or 0) + 1
		self:SortResults(nil, onComplete)
	end)
end

function GF.Result:GetIndexForResultID(resultID)
	if type(resultID) ~= "number" then
		return nil
	end
	local ids = self.resultIDs
	if not ids then
		return nil
	end
	for i = 1, #ids do
		if ids[i] == resultID then
			return i
		end
	end
	return nil
end

function GF.Result:GetEntryByResultID(resultID)
	if type(resultID) ~= "number" or resultID <= 0 then
		return nil
	end
	self.entryCache = self.entryCache or {}
	local entry = self.entryCache[resultID]
	if entry then
		return entry
	end
	local info = self.sortInfoCache and self.sortInfoCache[resultID]
	if not info then
		if self._usingAggregatedResults then
			info = self:GetCachedSearchResultInfo(resultID)
		else
			info = readSearchResultInfo(resultID)
		end
	end
	if not info then
		return nil
	end
	if self:ShouldHideUnavailableResult(resultID, info) and not self:IsSoftUnavailable(info) then
		clearCachedResult(self, resultID)
		return nil
	end
	entry = Snapshot.NewEntry(resultID, info)
	ensureMemberCounts(entry)
	self.entryCache[resultID] = entry
	return entry
end

function GF.Result:GetCount()
	if not self.resultIDs then
		self:RefreshCache()
	end
	return self.total or 0
end

function GF.Result:GetRawCount()
	if not self.resultIDs then
		self:RefreshCache()
	end
	return self.rawTotal or self.total or 0
end

function GF.Result:GetApiFilteredCount()
	return self.apiFilteredTotal or self.total or 0
end

function GF.Result:GetResultID(index)
	if not self.resultIDs then
		self:RefreshCache()
	end
	return self.resultIDs and self.resultIDs[index]
end

function GF.Result:GetEntry(index, opts)
	opts = opts or {}
	local loadPlayers = opts.loadPlayers
	local loadLeader = opts.loadLeader
	local resultID = self:GetResultID(index)
	if not resultID then
		return nil
	end
	self.entryCache = self.entryCache or {}
	local entry = self.entryCache[resultID]
	if not entry then
		entry = self:GetEntryByResultID(resultID)
	end
	if not entry then
		return nil
	end
	if loadLeader then
		local info = entry.info
		if info and (not info.leaderName or info.leaderName == "") then
			local fresh = self:GetAuthoritativeSearchResultInfo(entry.resultID)
			if fresh then
				entry.info = fresh
				info = fresh
			end
		end
		if not entry.leader or not entry.leader.name or entry.leader.name == "" then
			entry.leader = fetchLeaderPlayer(entry.resultID, info and info.numMembers)
		end
		syncLeaderNameFromPlayer(info, entry.leader)
	end
	local loadMemberPlayers = loadPlayers
	if loadMemberPlayers == nil then
		loadMemberPlayers = self:ShouldLoadPlayersForEntry(entry)
	end
	if loadMemberPlayers and not entry.players then
		local players, hasLeaver = fetchAllPlayers(entry.resultID, entry.info.numMembers)
		entry.players = players
		entry.hasLeaver = hasLeaver
		if not entry.leader then
			for _, player in ipairs(players) do
				if player.isLeader then
					entry.leader = player
					break
				end
			end
		end
		syncLeaderNameFromPlayer(entry.info, entry.leader)
	end
	return entry
end

function GF.Result:ResolveRowCategory(index, fallbackCategoryID)
	local entry = self:GetEntry(index)
	if entry and entry.categoryID then
		return entry.categoryID
	end
	if entry and entry.activity and entry.activity.categoryID then
		entry.categoryID = entry.activity.categoryID
		return entry.categoryID
	end
	return fallbackCategoryID
end

local ENUMERATE_MAX_PLAYERS = 5

local function shouldEnumerateMembers(entry)
	if not entry then
		return false
	end
	local catID = entry.categoryID
	if catID == GF.CAT_DUNGEON or catID == GF.CAT_DELVE then
		return true
	end
	local maxPlayers = entry.activity and entry.activity.maxNumPlayers
	return maxPlayers and maxPlayers > 0 and maxPlayers <= ENUMERATE_MAX_PLAYERS
end

function GF.Result:GetRoleDisplayMode(entry)
	if not entry then
		return "count"
	end
	if not entry.activity then
		hydrateEntryActivity(entry)
	end
	if not shouldEnumerateMembers(entry) then
		return "count"
	end
	local memberDisplayMode = GF.GetMemberDisplayMode and GF.GetMemberDisplayMode()
	if (GF.IsMemberDisplaySpecMode and GF.IsMemberDisplaySpecMode(memberDisplayMode))
		or memberDisplayMode == (GF.MEMBER_DISPLAY_MODE_SPEC or "spec") then
		return "enumerate_specs"
	end
	return "enumerate_roles"
end

function GF.Result:IsSpecEnumerateMode(mode)
	return mode == "enumerate_specs"
end

function GF.Result:IsEnumerateMode(mode)
	return mode == "enumerate_roles" or self:IsSpecEnumerateMode(mode)
end

function GF.Result:EnsureMemberCounts(entry)
	ensureMemberCounts(entry)
end

function GF.Result:ShouldLoadPlayersForEntry(entry)
	return self:IsEnumerateMode(self:GetRoleDisplayMode(entry))
end

function GF.Result:ShouldLoadPlayers(index)
	return self:ShouldLoadPlayersForEntry(self:GetEntry(index))
end

function GF.Result:InvalidateAllPlayerCache()
	if not self.entryCache then
		return
	end
	for _, entry in pairs(self.entryCache) do
		if type(entry) == "table" then
			entry.players = nil
			entry.hasLeaver = nil
			invalidateBlockedMemberCache(entry)
			invalidateLaonongFanMemberCache(entry)
		end
	end
end

function GF.Result:InvalidateAllBlockedMemberCache()
	if not self.entryCache then
		return
	end
	for _, entry in pairs(self.entryCache) do
		if type(entry) == "table" then
			invalidateBlockedMemberCache(entry)
		end
	end
end

function GF.Result:GetInfo(index)
	local entry = self:GetEntry(index)
	return entry and entry.info
end

function GF.Result:GetActivityInfo(index)
	local entry = self:GetEntry(index)
	return entry and entry.activity
end

function GF.Result:GetMemberCounts(index)
	local entry = self:GetEntry(index)
	if not entry then
		return 0, 0, 0
	end
	return entry.tanks, entry.heals, entry.dps
end

function GF.Result:GetPlayers(index)
	local entry = self:GetEntry(index, { loadPlayers = true })
	return entry and entry.players or {}
end

function GF.Result:GetLeaderPlayer(index)
	local entry = self:GetEntry(index, { loadLeader = true })
	return entry and entry.leader
end

function GF.Result:Apply(index, tank, healer, dps, resultID)
	if GF.Apply and GF.Apply.ShowDialogForIndex and tank == nil and healer == nil and dps == nil then
		return GF.Apply:ShowDialogForIndex(index, resultID)
	end
	if GF.Apply and GF.Apply.ResolveApplyTarget then
		local resolvedIndex, resolvedID = GF.Apply:ResolveApplyTarget(index, resultID)
		index = resolvedIndex
		resultID = resolvedID
	else
		resultID = resultID or self:GetResultID(index)
	end
	if not resultID then
		return false
	end
	return C_LFGList.ApplyToGroup(resultID, tank, healer, dps)
end

function GF.Result:Clear()
	self.total = 0
	self.rawTotal = 0
	self.apiFilteredTotal = 0
	self.resultIDs = {}
	self.entryCache = {}
	self.apiResultIDs = nil
	self.frozenOrder = nil
	self.frozenSet = nil
	self._usingAggregatedResults = nil
	self._aggregateInfoByID = nil
	self._aggregateMemberCountsByID = nil
	if GF.Search and GF.Search.ClearAggregatedResultIDs then
		GF.Search:ClearAggregatedResultIDs()
	end
	if C_LFGList.ClearSearchResults then
		C_LFGList.ClearSearchResults()
	end
end

function GF.Result:ClearFrozenSnapshot()
	self.frozenOrder = nil
	self.frozenSet = nil
end

function GF.Result:CommitSnapshot()
	local order = self.resultIDs or {}
	self.frozenOrder = {}
	self.frozenSet = {}
	for i, resultID in ipairs(order) do
		self.frozenOrder[i] = resultID
		self.frozenSet[resultID] = true
	end
end

function GF.Result:IsFrozenResult(resultID)
	return resultID and self.frozenSet and self.frozenSet[resultID] or false
end

function GF.Result:RemoveFromFrozen(resultID)
	if not resultID or not self.frozenSet or not self.frozenSet[resultID] then
		return false
	end
	self.frozenSet[resultID] = nil
	local newOrder = {}
	for _, id in ipairs(self.frozenOrder or self.resultIDs or {}) do
		if id ~= resultID then
			newOrder[#newOrder + 1] = id
		end
	end
	self.frozenOrder = newOrder
	self.resultIDs = newOrder
	self.total = #newOrder
	if self.entryCache then
		self.entryCache[resultID] = nil
	end
	if self.sortInfoCache then
		self.sortInfoCache[resultID] = nil
	end
	return true
end

function GF.Result:InvalidateEntryMembers(resultID)
	if not resultID or not self.entryCache then
		return
	end
	local entry = self.entryCache[resultID]
	if not entry then
		return
	end
	entry.players = nil
	entry._memberCountsLoaded = nil
	invalidateBlockedMemberCache(entry)
	invalidateLaonongFanMemberCache(entry)
	invalidateDisplayCounts(entry)
end

function GF.Result:RefreshEntryInfo(resultID, info)
	if not resultID then
		return nil
	end
	local cached = self:GetCachedSearchResultInfo(resultID)
	if info and cached and self._usingAggregatedResults and not self:IsLiveSearchResultInfoAuthoritative(resultID) then
		info = cached
	end
	info = info or cached
	if not info and not self._usingAggregatedResults then
		info = readSearchResultInfo(resultID)
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
		info = mergeReadableSearchInfo(entry.info, info)
	end
	if self:ShouldHideUnavailableResult(resultID, info) then
		clearCachedResult(self, resultID)
		return nil
	end
	if isUnreadableLfgText(info.name) then
		local resolved = self:GetListingTitle(info, resultID)
		if resolved and resolved ~= "?" then
			info.name = resolved
		end
	end
	if entry then
		entry.info = info
		self:InvalidateEntryMembers(resultID)
		hydrateEntryActivity(entry, info)
	else
		entry = self:GetEntryByResultID(resultID)
	end
	if self.sortInfoCache then
		self.sortInfoCache[resultID] = info
	end
	return entry
end
