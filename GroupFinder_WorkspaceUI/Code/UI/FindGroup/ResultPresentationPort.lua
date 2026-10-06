local _, GF = ...
GF = GF.GF or GF

-- ResultPresentationPort is the single boundary between the Find Group
-- presentation layer and mutable/native result state.  Row, tooltip, and menu
-- views receive stable, sanitized projections from here; they never decide
-- which native result record is authoritative on their own.
local Port = {}
GF.ResultPresentationPort = Port

local APPLICATION_TIMEOUT_SECONDS = 5 * 60
local CANCEL_FEEDBACK_DELAY = 0.3
local INACTIVE_APPLICATION_STATUS = {
	cancelled = true,
	failed = true,
	timedout = true,
	invitedeclined = true,
}
local TOOLTIP_ROLE_PRIORITY = { TANK = 1, HEALER = 2, DAMAGER = 3 }
local DEFAULT_WHITE_COLOR = { r = 1, g = 1, b = 1 }
local ROW_PRESENTATION_FIELDS = {
	"index", "resultID", "categoryID", "entry", "info", "activity",
	"isCensored", "isDelisted", "resultType", "displayType", "title",
	"comment", "voiceChat", "hasVoice", "voiceShown",
	"voiceShownProvided", "activityName", "requiredItemLevel", "scoreText",
	"scoreColor", "leaderText", "leaderColor", "wantsPlayers", "starredLeader",
}

local function resultService()
	return GF.Result
end

local function resultRepository()
	return GF.ResultRepository
end

local function snapshotService()
	return GF.SearchResultSnapshot
end

local function accessibleValue(value)
	if type(value) == "nil" then
		return true
	end
	local compat = GF.Compat
	if compat and type(compat.IsAccessibleValue) == "function" then
		return compat.IsAccessibleValue(value) == true
	end
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

local function readField(owner, key)
	local snapshot = snapshotService()
	if snapshot and type(snapshot.ReadField) == "function" then
		return snapshot.ReadField(owner, key)
	end
	local compat = GF.Compat
	if compat and type(compat.ReadAccessibleField) == "function" then
		return compat.ReadAccessibleField(owner, key)
	end
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, owner, key)
		if not ok then
			return nil, "error"
		end
		if secret == true then
			return nil, "secret"
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, "error"
	end
	if not accessibleValue(value) then
		return nil, "secret"
	end
	if type(value) == "nil" then
		return nil, "missing"
	end
	return value, "value"
end

local function readNumber(owner, key)
	local value = key ~= nil and readField(owner, key) or owner
	if type(value) == "nil" then
		return nil
	end
	local snapshot = snapshotService()
	if snapshot and type(snapshot.ToNumber) == "function" then
		return snapshot.ToNumber(value)
	end
	local compat = GF.Compat
	if compat and type(compat.ToAccessibleNumber) == "function" then
		return compat.ToAccessibleNumber(value)
	end
	if not accessibleValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	return ok and accessibleValue(number) and type(number) == "number"
		and number or nil
end

local function readTrue(owner, key)
	return readField(owner, key) == true
end

local function accessibleArrayLength(values)
	local compat = GF.Compat
	if compat and type(compat.GetAccessibleArrayLength) == "function" then
		return compat.GetAccessibleArrayLength(values)
	end
	if not accessibleValue(values) or type(values) ~= "table" then
		return nil
	end
	local ok, length = pcall(function()
		return #values
	end)
	return ok and readNumber(length) or nil
end

local function applicationService()
	return GF.ApplicationService
end

local function normalizedResultID(value)
	local resultID = tonumber(value)
	return resultID and resultID > 0 and resultID or nil
end

local function copyArray(values)
	local copy = {}
	local length = accessibleArrayLength(values)
	if length == nil then
		return copy
	end
	for index = 1, length do
		local value = readField(values, index)
		if value ~= nil then
			copy[#copy + 1] = value
		end
	end
	return copy
end

local function resetRowPresentation(presentation)
	presentation = type(presentation) == "table" and presentation or {}
	for _, field in ipairs(ROW_PRESENTATION_FIELDS) do
		presentation[field] = nil
	end
	return presentation
end

local function protectedNativeCall(func, ...)
	if type(func) ~= "function" then
		return nil
	end
	local ok, first, second, third = pcall(func, ...)
	if not ok then
		return nil
	end
	return first, second, third
end

local function isSecret(value)
	local results = resultService()
	if results and type(results.IsSecretLfgText) == "function" then
		local ok, secret = pcall(results.IsSecretLfgText, results, value)
		return ok == true and secret == true
	end
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok == true and secret == true
end

local function isPresent(value)
	local ok, present = pcall(function()
		return value ~= nil
	end)
	return ok and present == true
end

local function isCensored(info)
	local snapshot = snapshotService()
	if snapshot and type(snapshot.IsCensored) == "function" then
		return snapshot.IsCensored(info) == true
	end
	local results = resultService()
	return results and type(results.IsCensoredSearchResult) == "function"
		and results:IsCensoredSearchResult(info) == true
end

local function sanitizeInfo(info)
	local snapshot = snapshotService()
	if snapshot and type(snapshot.SanitizeCensoredContent) == "function" then
		return snapshot.SanitizeCensoredContent(info)
	end
	return info
end

local function resolveActivity(info, entry)
	if type(entry) == "table" and type(entry.activity) == "table" then
		return entry.activity
	end
	local snapshot = snapshotService()
	if not snapshot then
		return nil
	end
	if type(snapshot.ResolveActivityInfo) == "function" then
		return snapshot.ResolveActivityInfo(info)
	end
	local activityID = type(snapshot.GetPrimaryActivityID) == "function"
		and snapshot.GetPrimaryActivityID(info) or nil
	return activityID and type(snapshot.GetActivityInfo) == "function"
		and snapshot.GetActivityInfo(info, activityID) or nil
end

local function getMenuInstanceName(info, entry)
	local activity = resolveActivity(info, entry)
	if not activity then return nil end
	local fields = {}
	for _, key in ipairs({ "fullName", "shortName" }) do
		local value = readField(activity, key)
		fields[key] = type(value) == "string" and value or nil
	end
	fields.difficultyID = readNumber(activity, "difficultyID")
	fields.redirectedDifficultyID = readNumber(activity, "redirectedDifficultyID")
	for _, key in ipairs({ "isHeroicActivity", "isNormalActivity", "isMythicActivity", "isMythicPlusActivity" }) do
		fields[key] = readTrue(activity, key)
	end
	local provider = GF.ActivityInfo
	local name = provider and provider.GetActivityBaseName(fields)
		or fields.fullName or fields.shortName
	if not name or name == "" then return nil end
	local difficulty = provider and provider.GetDifficultyLabel(fields)
	if difficulty and difficulty ~= "" then
		return string.format((GF.L or {}).NAV_ACTIVITY_DIFFICULTY_FMT or "%s (%s)", name, difficulty)
	end
	return name
end

local function formatLeaderName(fullName, showRealm)
	if not accessibleValue(fullName) then
		return "?"
	end
	if type(fullName) ~= "string" or fullName == "" then
		return "?"
	end
	if showRealm == true then
		return fullName
	end
	return fullName:match("^([^-]+)") or fullName
end

local function resultTypeFor(info, entry, resultID, currentGroupProjection)
	local identityService = GF.NetEaseIdentityService
	local finder = GF.FindGroup
	local testContext = finder
		and type(finder.GetTeamListTestTypeContext) == "function"
		and finder:GetTeamListTestTypeContext(info, entry, resultID) or nil
	local identityEnabled = finder
		and type(finder.IsNetEaseIdentityBrowseEnabled) == "function"
		and finder:IsNetEaseIdentityBrowseEnabled() == true
	if testContext == nil and type(entry) == "table" and identityService then
		if identityEnabled
			and (currentGroupProjection == true
				or entry._gfCurrentGroupProjection == true)
		then
			-- FindGroup resolves and stores ordinary-result identities. The
			-- current-group type returns before that branch, so only its row
			-- needs an explicit projection here for the Newbie background.
			entry._gfNetEaseGroupProjection =
				identityService:GetGroupProjection(
					resultID, info, entry, { queue = true })
		elseif not identityEnabled then
			entry._gfNetEaseGroupProjection = nil
		end
	end
	if currentGroupProjection == true
		or (type(entry) == "table" and entry._gfCurrentGroupProjection == true)
	then
		return GF.RESULT_TYPE_CURRENT_GROUP
	end
	return finder and type(finder.GetResultType) == "function"
		and finder:GetResultType(info, entry, resultID) or nil
end

function Port:IsSecretText(value)
	return isSecret(value)
end

function Port:IsRenderedUnreadableText(value)
	local results = resultService()
	return results and type(results.IsRenderedUnreadableLfgText) == "function"
		and results:IsRenderedUnreadableLfgText(value) == true
end

function Port:IsUnreadableText(value)
	local results = resultService()
	return results and type(results.IsUnreadableLfgText) == "function"
		and results:IsUnreadableLfgText(value) == true
end

function Port:HasRenderableComment(value)
	local results = resultService()
	if results and type(results.HasRenderableListingComment) == "function" then
		local ok, renderable = pcall(
			results.HasRenderableListingComment, results, value)
		return ok and renderable == true
	end
	if isSecret(value) then
		return true
	end
	local ok, renderable = pcall(function()
		return value ~= nil and value ~= ""
	end)
	return ok and renderable == true
end

function Port:HasRenderableVoice(value)
	if isSecret(value) then
		return false
	end
	local ok, renderable = pcall(function()
		local valueType = type(value)
		return valueType == "string"
			and value ~= ""
			and value:find("|K", 1, true) == nil
	end)
	return ok and renderable == true
end

function Port:IsCensored(info)
	return isCensored(info)
end

function Port:GetResultTypes(info, entry, resultID, currentGroupProjection)
	local resultType = resultTypeFor(
		info, entry, resultID, currentGroupProjection)
	return resultType, self:GetResultDisplayType(info, resultType, entry)
end

function Port:GetResultDisplayType(info, resultType, entry)
	-- The relationship label is presentation only. Business status still
	-- determines filtering, warning backgrounds and application behavior.
	if self:GetStarredLeader(info) then
		return GF.STARRED_LEADER_DISPLAY_TYPE or "starred_leader"
	end
	if isCensored(info) then return GF.RESULT_TYPE_CENSORED or "censored" end
	local fans = GF.LaonongFanDirectory
	local displayType = fans and fans:GetResultDisplayType(resultType, info, entry)
		or resultType
	-- Hide only the four playstyle labels after identity precedence is resolved.
	-- Keep the business type and native playstyle data for filters and tooltips.
	if displayType and (displayType == GF.RESULT_PLAYSTYLE_LEARNING
		or displayType == GF.RESULT_PLAYSTYLE_FUN_RELAXED
		or displayType == GF.RESULT_PLAYSTYLE_FUN_SERIOUS
		or displayType == GF.RESULT_PLAYSTYLE_EXPERT)
	then
		local db = GF.GetDB and GF.GetDB()
		if not db or db.showGameType ~= true then
			return nil
		end
	end
	return displayType
end

function Port:IsLiveResult(resultID)
	local results = resultService()
	return results
		and type(results.IsLiveSearchResultInfoAuthoritative) == "function"
		and results:IsLiveSearchResultInfoAuthoritative(resultID) == true
end

function Port:GetIndexForResultID(resultID)
	resultID = normalizedResultID(resultID)
	if not resultID then
		return nil
	end
	local repository = resultRepository()
	if repository and type(repository.GetIndexForResultID) == "function" then
		return repository:GetIndexForResultID(resultID)
	end
	local results = resultService()
	return results and type(results.GetIndexForResultID) == "function"
		and results:GetIndexForResultID(resultID) or nil
end

function Port:GetResultID(index)
	local results = resultService()
	return results and type(results.GetResultID) == "function"
		and results:GetResultID(index) or nil
end

function Port:ResolveIdentity(index, resultID, forApplication)
	resultID = normalizedResultID(resultID)
	if forApplication == true then
		local applications = applicationService()
		if applications and type(applications.ResolveApplyTarget) == "function" then
			return applications:ResolveApplyTarget(index, resultID)
		end
	end
	if resultID then
		return self:GetIndexForResultID(resultID), resultID
	end
	resultID = self:GetResultID(index)
	return resultID and index or nil, resultID
end

function Port:GetCachedInfo(resultID)
	local repository = resultRepository()
	if repository and type(repository.GetCachedInfo) == "function" then
		return sanitizeInfo(repository:GetCachedInfo(resultID))
	end
	local results = resultService()
	return results and type(results.GetCachedSearchResultInfo) == "function"
		and sanitizeInfo(results:GetCachedSearchResultInfo(resultID)) or nil
end

function Port:GetAuthoritativeInfo(resultID)
	resultID = normalizedResultID(resultID)
	if not resultID then
		return nil
	end
	local results = resultService()
	if results and type(results.GetAuthoritativeSearchResultInfo) == "function" then
		local info = results:GetAuthoritativeSearchResultInfo(resultID)
		if info then
			return sanitizeInfo(info)
		end
	end
	local snapshot = snapshotService()
	return snapshot and type(snapshot.GetSearchResultInfo) == "function"
		and sanitizeInfo(snapshot.GetSearchResultInfo(resultID)) or nil
end

function Port:GetLiveUpdate(resultID)
	local results = resultService()
	if not (results and type(results.GetLiveSearchResultInfoForUpdate) == "function") then
		return nil, "not_current"
	end
	local info, state = results:GetLiveSearchResultInfoForUpdate(resultID)
	return sanitizeInfo(info), state
end

function Port:GetEntry(index, resultID, options)
	local results = resultService()
	if not results then
		return nil, nil
	end
	local resolvedIndex, resolvedID = self:ResolveIdentity(index, resultID)
	local entry = resolvedIndex and type(results.GetEntry) == "function"
		and results:GetEntry(resolvedIndex, options) or nil
	if resolvedID and entry and entry.resultID ~= resolvedID then
		resolvedIndex = self:GetIndexForResultID(resolvedID)
		entry = resolvedIndex and type(results.GetEntry) == "function"
			and results:GetEntry(resolvedIndex, options) or nil
	end
	if resolvedID and not (entry and entry.info)
		and type(results.GetEntryByResultID) == "function"
	then
		entry = results:GetEntryByResultID(resolvedID)
		resolvedIndex = resolvedIndex or self:GetIndexForResultID(resolvedID)
	end
	return entry, resolvedIndex
end

function Port:ResolveRowCategory(index, fallbackCategoryID)
	local results = resultService()
	return results and type(results.ResolveRowCategory) == "function"
		and results:ResolveRowCategory(index, fallbackCategoryID)
		or fallbackCategoryID
end

function Port:ShouldLoadPlayers(entry)
	local results = resultService()
	return results and type(results.ShouldLoadPlayersForEntry) == "function"
		and results:ShouldLoadPlayersForEntry(entry) == true
end

function Port:GetRoleDisplayMode(entry)
	local results = resultService()
	return results and type(results.GetRoleDisplayMode) == "function"
		and results:GetRoleDisplayMode(entry) or "count"
end

function Port:IsEnumeratedRoleMode(mode)
	local results = resultService()
	return results and type(results.IsEnumerateMode) == "function"
		and results:IsEnumerateMode(mode) == true
end

function Port:GetListingTitle(info, resultID)
	local results = resultService()
	return results and type(results.GetListingTitle) == "function"
		and results:GetListingTitle(info, resultID)
		or (info and info.name)
end

function Port:GetListingComment(info, resultID)
	local results = resultService()
	if results and type(results.GetListingComment) == "function" then
		local ok, comment = pcall(
			results.GetListingComment, results, info, resultID)
		if not ok then
			return ""
		end
		return comment
	end
	local ok, comment = pcall(function()
		return info and info.comment
	end)
	if not ok then
		return ""
	end
	return comment
end

function Port:FormatRaidProgress(killed, total, unavailableColor)
	local numerator, denominator = killed and tostring(killed) or "-", total and tostring(total) or "-"
	if unavailableColor then return numerator .. "/" .. denominator, unavailableColor end
	local colors = GF.BROWSE_RAID_PROGRESS_COLORS
	local killedColor = killed == nil and colors.unknown
		or (killed == 0 and colors.clear or colors.killed)
	return killedColor .. numerator .. "|r" .. colors.separator .. "/|r"
		.. (total and colors.total or colors.unknown) .. denominator .. "|r", DEFAULT_WHITE_COLOR
end

function Port:GetLeaderScorePresentation(info, activity, unavailableColor)
	local results = resultService()
	if results and type(results.GetBrowseScoreDisplay) == "function" then
		return results:GetBrowseScoreDisplay(info, activity, unavailableColor)
	end
	return nil, nil
end

function Port:GetScorePresentation(info, activity, unavailableColor, resultID)
	local results = resultService()
	if results and results.IsRaidProgressContext and results:IsRaidProgressContext() then
		local killed, total = results:GetRaidProgress(resultID, info, activity)
		return self:FormatRaidProgress(killed, total, unavailableColor)
	end
	return self:GetLeaderScorePresentation(info, activity, unavailableColor)
end

function Port:GetRaidProgressPresentation(resultID, info, activity, liveOnly)
	local results = resultService()
	if not (results and (liveOnly or results.IsRaidProgressContext and results:IsRaidProgressContext())
		and results.GetRaidProgressDetails and readNumber(activity, "categoryID") == (GF.CAT_RAID or 3)) then
		return nil
	end
	local progress = results:GetRaidProgressDetails(resultID, info, activity, liveOnly)
	progress.text = self:FormatRaidProgress(progress.killed, progress.total)
	return progress
end

function Port:IsRaidActivity(activity)
	local categoryID = readNumber(activity, "categoryID")
	-- A retained current-group row can belong to another activity than the
	-- selected navigation. Prefer its own category whenever it is available.
	if categoryID then return categoryID == (GF.CAT_RAID or 3) end
	local snapshot = snapshotService()
	return snapshot and snapshot.IsRaidContext and snapshot.IsRaidContext() == true or false
end

function Port:GetStarredLeader(info)
	local stars = GF.StarredLeaders
	return stars and stars:IsRaidWorkspace() and stars:Get(readField(info, "leaderName")) or nil
end

function Port:GetLeaderPresentation(index, fallbackEntry)
	local entry = fallbackEntry
	if index then
		entry = select(1, self:GetEntry(
			index,
			fallbackEntry and fallbackEntry.resultID,
			{ loadLeader = true })) or fallbackEntry
	end
	local info = entry and entry.info
	local leader = entry and entry.leader
	local rawName = readField(info, "leaderName")
		or readField(leader, "name")
	local database = GF.GetDB and GF.GetDB() or nil
	local classFilename = readField(leader, "classFilename")
	local classColor = classFilename and RAID_CLASS_COLORS
		and RAID_CLASS_COLORS[classFilename] or nil
	local leaderText = formatLeaderName(rawName, database and database.showLeaderRealm == true)
	return {
		text = leaderText,
		starred = self:GetStarredLeader(info) ~= nil,
		color = classColor or DEFAULT_WHITE_COLOR,
		entry = entry,
	}
end

function Port:GetDungeonScoreColor(score, unavailableColor)
	local results = resultService()
	return results and type(results.GetDungeonScoreColor) == "function"
		and results:GetDungeonScoreColor(score, unavailableColor) or nil
end

function Port:GetLeaderPvpRating(info, activity)
	local results = resultService()
	if results and type(results.GetLeaderPvpRatingInfo) == "function" then
		return results:GetLeaderPvpRatingInfo(info, activity)
	end
	return nil, nil
end

function Port:BuildRowPresentation(
	index, categoryID, suppliedEntry, options, reusable)
	options = options or {}
	local presentation = resetRowPresentation(reusable)
	local entry = suppliedEntry
	local resolvedIndex = index
	if not entry then
		entry, resolvedIndex = self:GetEntry(index, options.resultID)
	end
	local wantsPlayers = self:ShouldLoadPlayers(entry)
	if wantsPlayers and entry and not entry.players and options.deferRoles ~= true then
		entry, resolvedIndex = self:GetEntry(
			resolvedIndex, entry.resultID, { loadPlayers = true })
	end
	local info = entry and sanitizeInfo(entry.info)
	if not info then
		return nil
	end
	local resultID = entry.resultID or normalizedResultID(options.resultID)
	local currentGroup = options.currentGroupProjection == true
		or entry._gfCurrentGroupProjection == true
	local leaderProjection = self:GetLeaderPresentation(resolvedIndex, entry)
	entry = leaderProjection.entry or entry
	info = sanitizeInfo(entry.info or info)
	local activity = resolveActivity(info, entry)
	local censored = isCensored(info)
	local resultType = resultTypeFor(info, entry, resultID, currentGroup)
	local displayType = self:GetResultDisplayType(info, resultType, entry)
	local titleResultID = currentGroup and nil or resultID
	local projectedCommentProvided = currentGroup
		and (options.displayCommentProvided == true
			or isSecret(options.displayComment)
			or isPresent(options.displayComment))
	local comment
	if censored then
		comment = (GF.L or {}).CENSORED_RESULT_LIST_COMMENT
			or "队伍信息已被暴雪隐匿"
	elseif projectedCommentProvided then
		comment = options.displayComment
	else
		comment = self:GetListingComment(info, titleResultID)
	end
	local voiceOK, voiceChat = pcall(function()
		return info.voiceChat
	end)
	if not voiceOK then
		voiceChat = nil
	end
	local projectedVoiceProvided = currentGroup
		and (options.displayVoiceChatProvided == true
			or isSecret(options.displayVoiceChat)
			or isPresent(options.displayVoiceChat))
	if projectedVoiceProvided then
		if isSecret(options.displayVoiceChat) then
			voiceChat = nil
		else
			voiceChat = options.displayVoiceChat
		end
	end
	if censored then
		voiceChat = nil
	end
	local voiceShownProvided = currentGroup
		and not censored
		and options.displayVoiceShownProvided == true
	local voiceShown
	if voiceShownProvided then
		-- This may be a secret boolean derived from LfgEntryData.voiceChat.
		-- It is an opaque UI token, not application state: do not inspect it.
		voiceShown = options.displayVoiceShown
	end
	local isDelisted = readTrue(info, "isDelisted")
	local unavailableColor = isDelisted
		and (LFG_LIST_DELISTED_FONT_COLOR or GRAY) or nil
	local scoreResultID = resultID
	local results = resultService()
	if currentGroup and results and results.IsRaidProgressContext
		and results:IsRaidProgressContext() then
		-- A current-group snapshot outlives its search source. Only a revalidated
		-- live identity may read this source's encounter API or progress cache.
		local projection = GF.CurrentGroupProjection
		local _, liveID = self:GetCurrentGroupActionTarget({
			kind = "current_group",
			projectionKey = projection and projection.projectionKey,
			resultID = resultID,
		})
		scoreResultID = liveID
	end
	local scoreText, scoreColor = self:GetScorePresentation(
		info, activity, unavailableColor, scoreResultID)
	presentation.index = resolvedIndex
	presentation.resultID = resultID
	presentation.categoryID = self:ResolveRowCategory(
		resolvedIndex, categoryID)
	presentation.entry = entry
	presentation.info = info
	presentation.activity = activity
	presentation.isCensored = censored
	presentation.isDelisted = isDelisted
	presentation.resultType = resultType
	presentation.displayType = displayType
	presentation.title = self:GetListingTitle(info, titleResultID)
	presentation.comment = comment
	presentation.voiceChat = voiceChat
	presentation.hasVoice = self:HasRenderableVoice(voiceChat)
	presentation.voiceShown = voiceShown
	presentation.voiceShownProvided = voiceShownProvided
	presentation.activityName = readField(activity, "fullName")
		or readField(activity, "shortName")
		or readField(activity, "name")
		or ""
	presentation.requiredItemLevel = readNumber(info, "requiredItemLevel") or 0
	presentation.scoreText = scoreText
	presentation.scoreColor = scoreColor
	presentation.starredLeader = leaderProjection.starred == true
	presentation.leaderText = leaderProjection.text
	presentation.leaderColor = leaderProjection.color
	presentation.wantsPlayers = wantsPlayers
	return presentation
end

function Port:RefreshLiveRow(resultID)
	local info, sourceState = self:GetLiveUpdate(resultID)
	if not info then
		return nil, sourceState or "missing", self:GetCachedInfo(resultID)
	end
	local results = resultService()
	if not results then
		return nil, "missing_service"
	end
	local reason = type(results.GetSearchResultInvalidReason) == "function"
		and results:GetSearchResultInvalidReason(resultID, info) or nil
	if reason == "unavailable" and type(results.MarkSoftUnavailable) == "function" then
		return results:MarkSoftUnavailable(resultID, info), reason, info
	end
	if reason then
		return nil, reason
	end
	local entry = type(results.RefreshEntryInfo) == "function"
		and results:RefreshEntryInfo(resultID, info) or nil
	return entry, entry and nil or "missing"
end

function Port:GetRoleEntry(index, entry)
	entry = entry or select(1, self:GetEntry(index))
	if not (entry and entry.info) then
		return nil
	end
	local mode = self:GetRoleDisplayMode(entry)
	if (self:IsEnumeratedRoleMode(mode) or self:ShouldLoadPlayers(entry))
		and index and not entry.players
	then
		entry = select(1, self:GetEntry(
			index, entry.resultID, { loadPlayers = true })) or entry
	end
	return entry, mode
end

function Port:ResolveApplicationDisplayState(state)
	if state and state.actionState then return state.actionState end
	if not state or state.isApplication ~= true then
		return nil
	end
	if state.isDepartedApplication == true then
		return "departed"
	end
	local actual, pending = state.appStatus, state.pendingStatus
	if actual == "inviteaccepted" or pending == "inviteaccepted" then
		return "joined"
	end
	if actual == "invited" or pending == "invited" then
		return "invited"
	end
	if state.isActiveApp == true then
		return "pending"
	end
	if state.isDeclined == true
		or actual == "declined" or actual == "declined_delisted"
		or actual == "declined_full" or pending == "declined"
		or pending == "declined_delisted" or pending == "declined_full"
	then
		return "declined"
	end
	if INACTIVE_APPLICATION_STATUS[actual]
		or INACTIVE_APPLICATION_STATUS[pending]
	then
		return "cancelled"
	end
	return nil
end

function Port:GetApplicationPresentation(resultID)
	local applications = applicationService()
	if not (applications and type(applications.GetApplicationState) == "function") then
		return nil
	end
	local state = applications:GetApplicationState(resultID)
	local replacement, intent
	if applications.GetReplacementState then replacement, intent = applications:GetReplacementState(resultID) end
	local displayState = replacement or self:ResolveApplicationDisplayState(state)
	local feedbackAt
	if displayState == "cancelling" and state and state.cancelRequestedAt then
		local revealAt = state.cancelRequestedAt + CANCEL_FEEDBACK_DELAY
		if GetTime() < revealAt then
			feedbackAt = revealAt
			displayState = state.remainingSeconds and state.remainingSeconds > 0 and "pending" or "waiting_update"
		end
	end
	if not displayState then
		return nil
	end
	local remaining
	if displayState == "pending" then
		remaining = tonumber(state.remainingSeconds or state.appDuration)
		if not remaining or remaining < 0 or (not state.appExpiration and remaining > APPLICATION_TIMEOUT_SECONDS) then
			remaining = APPLICATION_TIMEOUT_SECONDS
		end
	end
	local visualState = displayState == "declined" and "declined"
		or ((displayState == "cancelled" or displayState == "departed")
			and "cancelled" or nil)
	return {
		state = state,
		displayState = displayState,
		remainingSeconds = remaining,
		appExpiration = state and state.appExpiration,
		feedbackAt = feedbackAt,
		feedbackRequest = feedbackAt and state.cancelRequest or nil,
		visualState = visualState,
		retryIntent = intent,
		showCancel = state and state.known ~= false and state.appStatus == "applied" and not state.pendingStatus
			and (displayState == "pending" or displayState == "waiting_update"
				or displayState == "waiting_confirm" or displayState == "cancel_failed"),
		canCancel = state and state.canCancel == true,
		cancelReason = state and state.cancelReason,
	}
end

function Port:CancelApplication(resultID)
	local applications = applicationService()
	if not (applications and type(applications.CancelApplication) == "function") then
		return false, "application_service_unavailable"
	end
	return applications:CancelApplication(resultID)
end

function Port:RetryApplication(resultID, intent)
	return GF.Apply and GF.Apply:RetryApplication(resultID, intent)
end

function Port:CaptureApplicationInteraction(row, resultID)
	return GF.Apply and GF.Apply:CaptureRowInteraction(row, resultID)
end

function Port:MatchesApplicationInteraction(expected, row, resultID)
	return GF.Apply and GF.Apply:InteractionMatches(expected, row, resultID)
end

function Port:EnsureApplicationExpiryTicker()
	local applyView = GF.Apply
	if applyView and type(applyView.EnsureExpiryTicker) == "function" then
		applyView:EnsureExpiryTicker()
		return true
	end
	return false
end

function Port:CanOpenApplication(index, resultID)
	local applications = applicationService()
	return not applications or type(applications.CanSelectRow) ~= "function"
		or applications:CanSelectRow(index, resultID) == true
end

function Port:OpenApplication(index, resultID)
	local resolvedIndex, resolvedID = self:ResolveIdentity(index, resultID, true)
	if not (resolvedIndex and resolvedID)
		or not self:CanOpenApplication(resolvedIndex, resolvedID)
	then
		return false
	end
	local applyView = GF.Apply
	if not (applyView and type(applyView.ShowDialogForIndex) == "function") then
		return false
	end
	applyView:ShowDialogForIndex(resolvedIndex, resolvedID)
	return true
end

function Port:ShowNativeTooltip(tooltip, owner, resultID)
	local guard = GF.NativeSearchTooltipGuard
	if not self:IsLiveResult(resultID)
		or not guard or type(guard.ShowTooltip) ~= "function"
	then
		return false
	end
	-- Cached text may survive an invite/search transition. Only a fresh native
	-- result can authorize Blizzard's compositor, which reads that ID again.
	return guard:ShowTooltip(tooltip, owner, resultID)
end

function Port:GetMemberCounts(resultID, entry)
	local snapshot = snapshotService()
	return snapshot and type(snapshot.GetMemberCounts) == "function"
		and snapshot.GetMemberCounts(resultID, entry) or nil
end

function Port:GetPlayers(resultID, info, entry)
	local snapshot = snapshotService()
	local players, complete
	if snapshot and type(snapshot.GetPlayers) == "function" then
		players, complete = snapshot.GetPlayers(resultID, info, entry)
	end
	if type(players) ~= "table" then
		return {}, complete
	end
	local projected = {}
	for index = 1, accessibleArrayLength(players) or 0 do
		local player = readField(players, index)
		if type(player) == "table" then
			local member = {}
			for _, field in ipairs({
				"name", "displayName", "assignedRole", "role", "specName",
				"specText", "specID", "specializationID",
				"classFilename", "classFileName", "classFile", "isLeader",
				"isLeaver",
			}) do
				local value, state = readField(player, field)
				if state == "value" then
					member[field] = value
				end
			end
			projected[#projected + 1] = member
		end
	end
	return projected, complete
end

local function roleSnapshotNumber(value)
	local number = readNumber(value)
	if not number then
		return 0
	end
	return math.max(0, math.floor(number + 0.0001))
end

local function roleSnapshotCount(source, role, legacyField)
	if type(source) ~= "table" then
		return 0
	end
	local ok, value = pcall(rawget, source, role)
	if (not ok or value == nil) and legacyField then
		ok, value = pcall(rawget, source, legacyField)
	end
	return ok and roleSnapshotNumber(value) or 0
end

-- Produces the complete value object consumed by RoleDisplay.  The returned
-- snapshot contains no result-service methods or native records; the second
-- return keeps the hydrated entry available to ListRow's non-role painting.
function Port:BuildRoleDisplaySnapshot(index, entry, options)
	local resolvedEntry, mode = self:GetRoleEntry(index, entry)
	local info = resolvedEntry and resolvedEntry.info
	if type(info) ~= "table" then
		return nil, resolvedEntry
	end
	local resultID = resolvedEntry.resultID
	local counts = self:GetMemberCounts(resultID, resolvedEntry)
		or resolvedEntry._displayCounts
		or resolvedEntry
	local projectedCounts = {
		TANK = roleSnapshotCount(counts, "TANK", "tanks"),
		HEALER = roleSnapshotCount(counts, "HEALER", "heals"),
		DAMAGER = roleSnapshotCount(counts, "DAMAGER", "dps"),
	}
	local players = {}
	if self:IsEnumeratedRoleMode(mode) then
		players = self:GetPlayers(resultID, info, resolvedEntry)
	end
	options = type(options) == "table" and options or {}
	local memberDisplayMode = options.memberDisplayMode
	if memberDisplayMode == nil and type(GF.GetMemberDisplayMode) == "function" then
		memberDisplayMode = GF.GetMemberDisplayMode()
	end
	return {
		info = {
			isDelisted = readTrue(info, "isDelisted"),
			numMembers = roleSnapshotNumber(
				readField(info, "numMembers")),
		},
		counts = projectedCounts,
		players = players,
		mode = mode,
		memberDisplayMode = memberDisplayMode,
	}, resolvedEntry
end

local function normalizedRole(role)
	if type(role) ~= "string" then
		return nil
	end
	role = role:upper()
	if role == "HEAL" then
		return "HEALER"
	end
	if role == "DPS" then
		return "DAMAGER"
	end
	return role
end

local function shortDisplayName(name)
	if not accessibleValue(name) then
		return nil
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if type(Ambiguate) == "function" then
		local ok, shortName = pcall(Ambiguate, name, "short")
		if ok and shortName ~= nil then
			return shortName
		end
	end
	if isSecret(name) then
		return name
	end
	return name:gsub("%-.+$", "")
end

local function isLeader(info, member)
	if readTrue(member, "isLeader") then
		return true
	end
	local leaderName = readField(info, "leaderName")
	local memberName = readField(member, "name")
	if type(leaderName) ~= "string" or leaderName == ""
		or type(memberName) ~= "string" or memberName == ""
	then
		return false
	end
	local equalOK, equal = pcall(function()
		return leaderName == memberName
	end)
	if equalOK and equal then
		return true
	end
	if isSecret(leaderName) or isSecret(memberName) then
		return false
	end
	local leaderShort = leaderName:match("^([^-]+)") or leaderName
	local memberShort = memberName:match("^([^-]+)") or memberName
	return leaderShort == memberShort
end

local function sortTooltipMembers(members)
	for index, member in ipairs(members) do
		member._gfTooltipSourceOrder = index
	end
	table.sort(members, function(left, right)
		local leftPriority = TOOLTIP_ROLE_PRIORITY[
			normalizedRole(left.assignedRole or left.role)] or 99
		local rightPriority = TOOLTIP_ROLE_PRIORITY[
			normalizedRole(right.assignedRole or right.role)] or 99
		if leftPriority ~= rightPriority then
			return leftPriority < rightPriority
		end
		return left._gfTooltipSourceOrder < right._gfTooltipSourceOrder
	end)
	for _, member in ipairs(members) do
		member._gfTooltipSourceOrder = nil
	end
	return members
end

function Port:BuildTooltipMemberPresentation(info, players)
	local members, blockedMembers = {}, {}
	local leaderClassFilename
	local hasLeaver = false
	local blocklist = GF.Blocklist
	local blocklistEnabled = blocklist
		and type(blocklist.IsEnabled) == "function"
		and blocklist:IsEnabled() == true
	for index = 1, #(players or {}) do
		local source = players[index]
		if type(source) == "table" then
			local member = {}
			for key, value in pairs(source) do
				member[key] = value
			end
			member.displayName = member.displayName
				or shortDisplayName(member.name)
			member.assignedRole = member.assignedRole or member.role
			member.classFilename = member.classFilename
				or member.classFileName or member.classFile
			member.isLeader = isLeader(info, member)
			if member.isLeader then
				leaderClassFilename = member.classFilename
			end
			hasLeaver = hasLeaver or member.isLeaver == true
			if blocklistEnabled and type(blocklist.FindPlayerMatch) == "function"
				and type(member.name) == "string" and member.name ~= ""
			then
				member._gfBlockedRow = blocklist:FindPlayerMatch(member.name)
				if member._gfBlockedRow then
					blockedMembers[#blockedMembers + 1] = member
				end
			end
			members[#members + 1] = member
		end
	end
	sortTooltipMembers(members)
	sortTooltipMembers(blockedMembers)
	return members, leaderClassFilename, hasLeaver, blockedMembers
end

function Port:GetCompletedEncounters(resultID)
	if not self:IsLiveResult(resultID) then
		return {}
	end
	local snapshot = snapshotService()
	if snapshot and snapshot.GetCompletedEncounters then
		return snapshot.GetCompletedEncounters(resultID) or {}
	end
	local api = C_LFGList
	local values = api and protectedNativeCall(
		api.GetSearchResultEncounterInfo, resultID) or nil
	return copyArray(values)
end

function Port:GetFriendNames(resultID, info, players, playersComplete)
	if not self:IsLiveResult(resultID) then
		return {}, {}
	end
	local lockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
	if type(lockdown) == "function" and protectedNativeCall(lockdown) ~= false then
		return {}, {}
	end
	local api = C_LFGList
	local bnet, characters, guild
	if api then
		bnet, characters, guild = protectedNativeCall(
			api.GetSearchResultFriends, resultID)
	end
	local lists = { bnet = bnet, guild = guild, friend = characters }
	if info and GF.FilterSearchResultSocialMembers then
		lists = GF.FilterSearchResultSocialMembers(info, resultID, lists, {
			players = players, playersComplete = playersComplete,
		})
	end
	local names, relationships = {}, {}
	local function append(source, kind)
		local length = accessibleArrayLength(source) or 0
		for index = 1, length do
			local name = readField(source, index)
			if type(name) == "string" and name ~= "" and not relationships[name] then
				relationships[name] = kind
				names[#names + 1] = name
			end
		end
	end
	-- Keep each member's native relationship; group-level counts cannot label
	-- an individual. Overlapping relationships use the shared social priority.
	append(lists.bnet, GF.SOCIAL_TYPE_BNET)
	append(lists.guild, GF.SOCIAL_TYPE_GUILD)
	append(lists.friend, GF.SOCIAL_TYPE_FRIEND)
	return names, relationships, lists
end

function Port:GetLeaderFactionGroup(info)
	local listingFaction = readNumber(info, "leaderFactionGroup")
	local leaderName = readField(info, "leaderName")
	local normalizeName = GF.NormalizeExternalFullPlayerName
	if type(leaderName) ~= "string" or leaderName == ""
		or type(normalizeName) ~= "function"
	then
		return listingFaction
	end
	local playerName, playerRealm = protectedNativeCall(UnitFullName, "player")
	if not accessibleValue(playerName) or type(playerName) ~= "string" or playerName == ""
		or not accessibleValue(playerRealm)
	then
		return listingFaction
	end
	if type(playerRealm) ~= "string" or playerRealm == "" then
		playerRealm = protectedNativeCall(GetNormalizedRealmName)
	end
	if not accessibleValue(playerRealm) or type(playerRealm) ~= "string" or playerRealm == "" then
		return listingFaction
	end
	local normalizedLeader = protectedNativeCall(normalizeName, leaderName, playerRealm)
	local normalizedPlayer = protectedNativeCall(normalizeName, playerName, playerRealm)
	if not normalizedLeader or normalizedLeader ~= normalizedPlayer then
		return listingFaction
	end
	-- A verified self-led listing can use the player's actual faction. Do not
	-- rewrite the source result: its raw faction remains available for diagnosis.
	local faction = protectedNativeCall(UnitFactionGroup, "player")
	if accessibleValue(faction) and (faction == "Alliance" or faction == "Horde") then
		return PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[faction] or nil
	end
	return nil
end

function Port:GetPlaystylePresentation(info, activity)
	if type(activity) ~= "table" then
		return nil
	end
	local api = C_LFGList
	local none = Enum and Enum.LFGEntryPlaystyle
		and Enum.LFGEntryPlaystyle.None or 0
	local generalPlaystyle = readNumber(info, "generalPlaystyle") or 0
	local playstyle = api and protectedNativeCall(
		api.GetPlaystyleString,
		none,
		generalPlaystyle,
		activity) or nil
	if type(playstyle) ~= "string" or playstyle == "" then
		return nil
	end
	local categoryID = readNumber(activity, "categoryID")
	local category = api and categoryID and protectedNativeCall(
		api.GetLfgCategoryInfo, categoryID) or nil
	local allowsCrossFaction = readTrue(category, "allowCrossFaction")
		and readTrue(activity, "allowCrossFaction")
	local crossFactionListing, crossFactionState = readField(
		info, "crossFactionListing")
	local sameFaction = crossFactionState == "value"
		and crossFactionListing == false
		and allowsCrossFaction
	local leaderFactionGroup = self:GetLeaderFactionGroup(info)
	return {
		text = playstyle,
		faction = sameFaction and FACTION_STRINGS
			and leaderFactionGroup
			and FACTION_STRINGS[leaderFactionGroup] or nil,
	}
end

local function tooltipInfoBecameReadable(port, older, newer)
	if type(older) ~= "table" or type(newer) ~= "table" then
		return false
	end
	local commentReadable = not port:HasRenderableComment(older.comment)
		and port:HasRenderableComment(newer.comment)
	return (port:IsUnreadableText(older.name)
		and not port:IsUnreadableText(newer.name))
		or (port:IsUnreadableText(older.comment)
			and not port:IsUnreadableText(newer.comment))
		or commentReadable
end

function Port:BuildTooltipSnapshot(resultID, application)
	resultID = normalizedResultID(resultID)
	local source
	if application then
		local applications = GF.RaidAwaitingApplications
		source = applications and applications:GetTooltipSource(application)
		if not source or source.resultID ~= resultID then return nil, "stale_application" end
	end
	local info
	if source then info = sanitizeInfo(source.info) else info = self:GetAuthoritativeInfo(resultID) end
	if not info then
		return nil, "missing"
	end
	local snapshot = snapshotService()
	local activityID = snapshot and type(snapshot.GetPrimaryActivityID) == "function"
		and snapshot.GetPrimaryActivityID(info) or nil
	if not activityID then
		return nil, "missing_activity"
	end
	local results = resultService()
	local repository = resultRepository()
	local priorEntry = repository and type(repository.GetEntry) == "function"
		and repository:GetEntry(resultID) or nil
	local priorInfo = priorEntry and priorEntry.info
	local socialFields = { "numBNetFriends", "numGuildMates", "numCharFriends",
		"isGuildListing", "isFriendListing" }
	local priorSocial = {}
	for _, field in ipairs(socialFields) do priorSocial[field] = readField(priorInfo, field) end
	local invalidReason = not source and results
		and type(results.GetSearchResultInvalidReason) == "function"
		and results:GetSearchResultInvalidReason(resultID, info) or nil
	local refreshRow = false
	local entry = source and { resultID = resultID, info = info, activity = source.activity } or nil
	if invalidReason == "unavailable" and results
		and type(results.MarkSoftUnavailable) == "function"
	then
		entry = results:MarkSoftUnavailable(resultID, info)
		if not entry and type(results.ShouldRetainExpiredGroups) == "function"
			and results:ShouldRetainExpiredGroups() ~= true
		then
			return nil, invalidReason, {
				retire = true,
				expired = true,
				info = info,
			}
		end
		info = entry and entry.info or info
		refreshRow = entry ~= nil
	elseif invalidReason then
		return nil, invalidReason, { retire = true }
	end
	if not source and results and type(results.RefreshEntryInfo) == "function" then
		entry = entry or results:RefreshEntryInfo(resultID, info, { deferSocialMembers = true })
		if not (entry and entry.info) then
			local dirty = type(results.IsDirtySearchResult) == "function"
				and results:IsDirtySearchResult(resultID, info)
			return nil, dirty and "dirty" or "unavailable", {
				retire = dirty == true,
			}
		end
		info = sanitizeInfo(entry.info)
	end
	entry = entry or select(1, self:GetEntry(nil, resultID))
	refreshRow = not source and (refreshRow or tooltipInfoBecameReadable(self, priorInfo, info))
	local activity = resolveActivity(info, entry)
	if not activity then
		return nil, "missing_activity"
	end
	local players, playersComplete = self:GetPlayers(resultID, info, entry)
	local members, leaderClassFilename, hasLeaver, blockedMembers =
		self:BuildTooltipMemberPresentation(info, players)
	local friendNames, friendRelationships, friendLists = self:GetFriendNames(
		resultID, info, players, playersComplete)
	if not source and friendLists and results and results.ConfirmSocialMemberInfo then
		results:ConfirmSocialMemberInfo(resultID, info, friendLists)
		for _, field in ipairs(socialFields) do
			if priorSocial[field] ~= readField(info, field) then refreshRow = true end
		end
	end
	local raidProgress = self:GetRaidProgressPresentation(resultID, info, activity, source ~= nil)
	return {
		resultID = resultID,
		info = info,
		entry = entry,
		activity = activity,
		memberCounts = self:GetMemberCounts(resultID, entry) or {},
		players = players or {},
		members = members,
		leaderClassFilename = leaderClassFilename,
		hasLeaver = hasLeaver,
		blockedMembers = blockedMembers,
		completedEncounters = not raidProgress and self:GetCompletedEncounters(resultID) or nil,
		raidProgress = raidProgress,
		friendNames = friendNames,
		friendRelationships = friendRelationships,
		roleDisplayMode = self:GetRoleDisplayMode(entry),
		refreshRow = refreshRow,
		isCensored = isCensored(info),
	}, nil
end

function Port:IsBlacklistEnabled()
	local blocklist = GF.Blocklist
	return blocklist and type(blocklist.IsEnabled) == "function"
		and blocklist:IsEnabled() == true
end

function Port:GetCurrentGroupActionTarget(elementData)
	local projection = GF.CurrentGroupProjection
	if projection and type(projection.GetLiveActionTarget) == "function" then
		return projection:GetLiveActionTarget(elementData)
	end
	return nil
end

function Port:BuildMenuSnapshot(index, resultID, info, displayTitle)
	local resolvedIndex, resolvedID = self:ResolveIdentity(
		index, resultID, index ~= nil)
	if index ~= nil and not (resolvedIndex and resolvedID) then
		return nil
	end
	info = sanitizeInfo(info or self:GetAuthoritativeInfo(resolvedID))
	if type(info) ~= "table" then
		return nil
	end
	local censored = isCensored(info)
	local fallbackTitle = readField(info, "name")
	local title = censored
		and (rawget(_G, "CENSORED_LFG_GROUP_NAME")
			or (GF.L or {}).CENSORED_RESULT_HIDDEN_TITLE
			or "招募内容已隐藏")
		or displayTitle or fallbackTitle or "?"
	return {
		index = resolvedIndex,
		resultID = resolvedID,
		info = info,
		displayTitle = displayTitle,
		leaderName = readField(info, "leaderName"),
		instanceName = getMenuInstanceName(info, select(1, self:GetEntry(nil, resolvedID))),
		isCensored = censored,
		title = title,
		canApply = resolvedIndex ~= nil
			and self:CanOpenApplication(resolvedIndex, resolvedID),
		supportsReportListing = type(LFGList_ReportListing) == "function",
		supportsReportAdvertisement =
			type(LFGList_ReportAdvertisement) == "function",
		canReportListing = resolvedID ~= nil
			and type(LFGList_ReportListing) == "function",
		canReportAdvertisement = resolvedID ~= nil
			and type(LFGList_ReportAdvertisement) == "function",
		blacklistEnabled = self:IsBlacklistEnabled(),
	}
end

function Port:BlockTitle(snapshot)
	local blocklist = GF.Blocklist
	return blocklist and type(blocklist.BlockSameTitleFromSearchResult) == "function"
		and blocklist:BlockSameTitleFromSearchResult(
			snapshot.resultID, snapshot.info, snapshot.displayTitle) == true
end

function Port:BlockLeader(snapshot)
	local blocklist = GF.Blocklist
	return blocklist and type(blocklist.BlockLeaderFromSearchResult) == "function"
		and blocklist:BlockLeaderFromSearchResult(
			snapshot.resultID, snapshot.info) == true
end

function Port:ReportListing(snapshot)
	if not (snapshot and snapshot.canReportListing) then
		return false
	end
	LFGList_ReportListing(snapshot.resultID, snapshot.leaderName)
	return true
end

function Port:ReportAdvertisement(snapshot)
	if not (snapshot and snapshot.canReportAdvertisement) then
		return false
	end
	LFGList_ReportAdvertisement(snapshot.resultID)
	local blocklist = GF.Blocklist
	local blocked = false
	if snapshot.blacklistEnabled and blocklist
		and type(blocklist.BlockAdvertisementFromSearchResult) == "function"
	then
		blocked = blocklist:BlockAdvertisementFromSearchResult(
			snapshot.resultID, snapshot.info) == true
	end
	if blocklist and type(blocklist.TipAdvertisementReport) == "function" then
		blocklist:TipAdvertisementReport(snapshot.leaderName, blocked)
	end
	return true, blocked
end
