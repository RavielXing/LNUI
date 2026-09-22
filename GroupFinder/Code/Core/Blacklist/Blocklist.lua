local _, GF = ...

-- Public compatibility facade. Persistence and matching live behind explicit
-- GF-owned domain services; this module coordinates search, notices, and UI.
GF.Blocklist = {}
local BL = GF.Blocklist

local Matcher = assert(GF.BlacklistMatcher, "BlacklistMatcher must load first")
local Repository = assert(
	GF.BlacklistRepository, "BlacklistRepository must load first")
local NOTES = Matcher.Notes
local SOURCES = Matcher.Sources
local titleEvidence = Matcher.NewTitleEvidence()

local function syncRepositoryState(owner)
	owner.leaders = Repository:GetLeaderIndex()
	owner.revision = Repository:GetRevision()
end

local function isAccessibleNonSecretValue(value)
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

local function isAccessibleNonSecretTable(value)
	if type(canaccesstable) == "function" then
		local ok, accessible = pcall(canaccesstable, value)
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
	return type(value) == "table"
end

local function readAccessibleField(owner, key)
	if not isAccessibleNonSecretTable(owner) then
		return nil, false
	end
	if type(issecretvaluekey) == "function" then
		local ok, secret = pcall(issecretvaluekey, owner, key)
		if not ok or secret == true then
			return nil, false
		end
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok or not isAccessibleNonSecretValue(value) then
		return nil, false
	end
	return value, true
end

local function chatMessagingUnlocked()
	local reader = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
	if type(reader) ~= "function" then
		return true
	end
	local ok, locked = pcall(reader)
	return ok and isAccessibleNonSecretValue(locked) and locked == false
end

local function isWholeOpaqueTitleToken(value)
	if not Matcher.IsSecretToken(value) then
		return false
	end
	local ok, matched = pcall(
		string.match, value, "^|K[^|%c]+|k$")
	return ok and matched ~= nil
end

local function freshChatTitleToken(resultID, expectedTitle, expectedLeader)
	if type(GF.ShowStatusMessage) ~= "function"
		or not chatMessagingUnlocked()
		or not isAccessibleNonSecretValue(resultID)
		or type(resultID) ~= "number"
		or not isAccessibleNonSecretValue(expectedTitle)
		or not isAccessibleNonSecretValue(expectedLeader)
	then
		return nil
	end
	local api = C_LFGList
	local hasInfo = api and api.HasSearchResultInfo
	local getInfo = api and api.GetSearchResultInfo
	if type(hasInfo) ~= "function" or type(getInfo) ~= "function" then
		return nil
	end
	local presentOK, present = pcall(hasInfo, resultID)
	if not presentOK or not isAccessibleNonSecretValue(present)
		or present ~= true
	then
		return nil
	end
	local infoOK, fresh = pcall(getInfo, resultID)
	if not infoOK or not isAccessibleNonSecretTable(fresh) then
		return nil
	end
	local censored, censoredOK = readAccessibleField(fresh, "censored")
	if not censoredOK or censored ~= false then
		return nil
	end
	local freshResultID, resultIDOK = readAccessibleField(
		fresh, "searchResultID")
	if not resultIDOK or type(freshResultID) ~= "number"
		or freshResultID ~= resultID
	then
		return nil
	end
	local freshLeader, leaderOK = readAccessibleField(fresh, "leaderName")
	freshLeader = leaderOK and Matcher.NormalizeLeader(freshLeader) or nil
	if freshLeader == nil
		or not Matcher.SafeTextEquals(freshLeader, expectedLeader)
	then
		return nil
	end
	local title, titleOK = readAccessibleField(fresh, "name")
	if not titleOK or type(title) ~= "string"
		or not isWholeOpaqueTitleToken(title)
		or not Matcher.SafeTextEquals(title, expectedTitle)
	then
		return nil
	end
	return title
end

local function getSearchResultInfo(resultID)
	local getter = C_LFGList and C_LFGList.GetSearchResultInfo
	if resultID == nil or type(getter) ~= "function"
		or not chatMessagingUnlocked()
	then
		return nil
	end
	local ok, info = pcall(getter, resultID)
	return ok and isAccessibleNonSecretTable(info) and info or nil
end

local function suppliedOrFreshResultInfo(info, resultID)
	if isAccessibleNonSecretTable(info) then
		return info
	end
	return getSearchResultInfo(resultID)
end

local function getCachedSearchResultInfo(resultID)
	local result = GF.Result
	if not (result and resultID) then
		return nil
	end
	local entry = result.entryCache and result.entryCache[resultID]
	if entry and entry.info then
		return entry.info
	end
	return result.sortInfoCache and result.sortInfoCache[resultID] or nil
end

local function isCensoredResultInfo(info)
	local result = GF.Result
	if result and type(result.IsCensoredSearchResult) == "function" then
		local ok, censored = pcall(
			result.IsCensoredSearchResult, result, info)
		return ok and censored == true
	end
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.IsCensored) == "function" then
		local ok, censored = pcall(snapshot.IsCensored, info)
		return ok and censored == true
	end
	return false
end

local function isUnreadableTitle(title)
	local result = GF.Result
	if result and type(result.IsUnreadableLfgText) == "function" then
		return result:IsUnreadableLfgText(title) == true
	end
	return false
end

local function reliableTitle(title)
	return Matcher.ReliableTitle(title, isUnreadableTitle)
end

local function stableTitleLabel(title)
	return Matcher.StableTitleLabel(title, isUnreadableTitle)
end

local function reliableInfoTitle(info)
	if not isAccessibleNonSecretTable(info) then
		return nil, false
	end
	local censored, censoredOK = readAccessibleField(info, "censored")
	if not censoredOK or censored == true then
		return nil, true
	end
	local title, titleOK = readAccessibleField(info, "name")
	if not titleOK then
		return nil, true
	end
	return reliableTitle(title), false
end

local function stableInfoTitle(info)
	local title, blocked = reliableInfoTitle(info)
	if blocked or title == nil then
		return nil
	end
	return stableTitleLabel(title)
end

local function resolveReliableTitle(resultID, info, displayTitle, preferFresh)
	local fresh
	if preferFresh then
		fresh = getSearchResultInfo(resultID)
		local title, blocked = reliableInfoTitle(fresh)
		if blocked then
			return nil, fresh
		end
		if title then
			return title, fresh
		end
	end
	local title, blocked = reliableInfoTitle(info)
	if blocked then
		return nil, info
	end
	if title then
		return title, info
	end
	local cached = getCachedSearchResultInfo(resultID)
	title, blocked = reliableInfoTitle(cached)
	if blocked then
		return nil, fresh or info or cached
	end
	if title then
		return title, cached
	end
	if not preferFresh then
		fresh = getSearchResultInfo(resultID)
		title, blocked = reliableInfoTitle(fresh)
		if blocked then
			return nil, fresh
		end
		if title then
			return title, fresh
		end
	end
	title = reliableTitle(displayTitle)
	if title then
		return title, cached or info or fresh
	end
	return nil, fresh or info or cached
end

local function resolveStableDisplayTitle(resultID, info, displayTitle, titleInfo)
	local label = stableTitleLabel(displayTitle)
		or stableInfoTitle(titleInfo)
		or stableInfoTitle(info)
	if label then
		return label
	end
	local cached = getCachedSearchResultInfo(resultID)
	return stableInfoTitle(cached)
end

local function displayText(nativeText, displayLabel)
	return Matcher.ResolveDisplayText(nativeText, displayLabel, titleEvidence)
end

local function resolveTitleNoticeText(title, displayLabel, chatTitleToken)
	local stable = stableTitleLabel(displayLabel)
		or stableTitleLabel(title)
	if stable ~= nil then
		return stable
	end
	-- Only the one-action proof captured from the current authoritative result
	-- may cross the chat boundary.  Session-wide title evidence is intentionally
	-- insufficient because LFG search kstrings expire with their native result.
	if isWholeOpaqueTitleToken(chatTitleToken)
		and Matcher.SafeTextEquals(chatTitleToken, title)
	then
		return chatTitleToken
	end
	return nil
end

function BL:Init()
	self:ClearTipState()
	self:RebuildMaps()
end

function BL:ClearTipState()
	self._scanNoticeBatch = nil
	self._manualTitleNotice = nil
end

function BL:ClearReadableTitleTokens()
	titleEvidence:Reset()
end

function BL:IsEnabled()
	return GF.GetDB().blacklistEnabled ~= false
end

function BL:HasActiveRules()
	return self:IsEnabled() == true and next(self.leaders or {}) ~= nil
end

function BL:RebuildMaps()
	Repository:Rebuild(self:IsEnabled())
	syncRepositoryState(self)
end

function BL:GetRevision()
	return Repository:GetRevision()
end

function BL:FindTitleEntry(titleToken)
	return Repository:FindTitle(titleToken)
end

function BL:GetDisplayText(entry, itemRole)
	if type(entry) ~= "table" then
		return "?"
	end
	local useTitle = entry.kind == "title" or itemRole == "parent"
	return displayText(useTitle and entry.title or entry.leader, entry.displayLabel)
end

local function tipLabelText(text)
	return type(text) == "string" and text or ""
end

local function colorStatusText(text, colorCode)
	local reset = GF.CHAT_RESET_COLOR_CODE or "|r"
	local bodyColor = GF.CHAT_STATUS_BODY_COLOR_CODE or "|cffffffff"
	return (colorCode or "") .. tostring(text or "") .. reset .. bodyColor
end

local LEADER_NAME_BLUE_COLOR_CODE = "|cff71d5ff"

local function colorLeaderName(leaderName)
	return colorStatusText(
		Matcher.NormalizeLeader(leaderName) or "?",
		LEADER_NAME_BLUE_COLOR_CODE)
end

local function colorMatchedTitle(title)
	return colorStatusText(
		title,
		GF.CHAT_STATUS_FAILURE_COLOR_CODE or "|cffff4040")
end

local function colorTitleMatchedLeader(leaderName)
	return colorStatusText(
		Matcher.NormalizeLeader(leaderName) or "?",
		GF.CHAT_STATUS_HIGHLIGHT_COLOR_CODE or "|cffffd200")
end

local function buildTitleMatchMessage(locale, title, leader)
	local ok, message = pcall(function()
		return string.format(
			tipLabelText(locale.BLOCK_TIP_TITLE_MATCH_FMT
				or "Matched group title “%s”; also blocked leader “%s”"),
			colorMatchedTitle(title),
			colorTitleMatchedLeader(leader))
	end)
	if not ok or not isAccessibleNonSecretValue(message)
		or type(message) ~= "string"
	then
		return nil
	end
	return message
end

local function colorCodeFromRGB(color, fallback)
	if type(color) ~= "table" then
		return fallback
	end
	if type(color.GenerateHexColorMarkup) == "function" then
		local ok, markup = pcall(color.GenerateHexColorMarkup, color)
		if ok and type(markup) == "string" and markup ~= "" then
			return markup
		end
	end
	local red, green, blue = tonumber(color.r), tonumber(color.g), tonumber(color.b)
	if red == nil or green == nil or blue == nil then
		return fallback
	end
	local function byte(value)
		return math.floor((math.max(0, math.min(1, value)) * 255) + 0.5)
	end
	return string.format(
		"|cff%02x%02x%02x", byte(red), byte(green), byte(blue))
end

local function getSystemMessageColorCode()
	local systemColor = ChatTypeInfo and ChatTypeInfo.SYSTEM
	return colorCodeFromRGB(
		systemColor,
		colorCodeFromRGB(YELLOW_FONT_COLOR, "|cffffff00"))
end

local NoticeBatch = {}
NoticeBatch.__index = NoticeBatch

function NoticeBatch:New(owner)
	return setmetatable({
		owner = owner,
		leaderNames = {},
		leaderSeen = {},
		titleRelations = {},
		titleRelationSeen = {},
		panelRefreshRequested = false,
		finished = false,
	}, self)
end

function NoticeBatch:AddLeader(leader)
	local normalized = Matcher.NormalizeLeader(leader)
	if normalized == nil or self.finished or self.leaderSeen[normalized] then
		return false
	end
	self.leaderSeen[normalized] = true
	self.leaderNames[#self.leaderNames + 1] = normalized
	return true
end

function NoticeBatch:AddTitleRelation(leader, sourceTitle)
	local normalized = Matcher.NormalizeLeader(leader)
	if normalized == nil or self.finished
		or not Matcher.IsUsableText(sourceTitle)
	then
		return false
	end
	local seen = self.titleRelationSeen[sourceTitle]
	if seen == nil then
		seen = {}
		self.titleRelationSeen[sourceTitle] = seen
	end
	if seen[normalized] then
		return false
	end
	seen[normalized] = true
	self.titleRelations[#self.titleRelations + 1] = {
		leader = normalized,
		sourceTitle = sourceTitle,
	}
	return true
end

function NoticeBatch:RequestPanelRefresh()
	if not self.finished then
		self.panelRefreshRequested = true
	end
end

function NoticeBatch:Finish()
	if self.finished then
		return
	end
	self.finished = true
	local locale = GF.L or {}
	local messageFormat = tipLabelText(
		locale.BLOCK_TIP_SAME_TITLE_MATCH_FMT
			or "Matched another group with the same title; also blocked leader “%s”")
	for _, relation in ipairs(self.titleRelations) do
		self.owner:Tip(string.format(
			messageFormat,
			colorTitleMatchedLeader(relation.leader)))
	end
	if #self.leaderNames > 0 then
		local prefix = tipLabelText(
			locale.BLOCK_TIP_LEADER_PREFIX or "Leader added to blocklist: ")
		self.owner:Tip(prefix .. table.concat(self.leaderNames, "、"))
	end
	local panel = GF.BlocklistPanel
	if self.panelRefreshRequested and panel
		and type(panel.Refresh) == "function"
	then
		panel:Refresh()
	end
end

function BL:BeginScanTipBatch()
	if self._scanNoticeBatch ~= nil then
		self:EndScanTipBatch()
	end
	self._scanNoticeBatch = NoticeBatch:New(self)
end

function BL:EndScanTipBatch()
	local batch = self._scanNoticeBatch
	if batch == nil then
		return
	end
	self._scanNoticeBatch = nil
	batch:Finish()
end

local function noticeBatch(owner)
	if owner._scanNoticeBatch then
		return owner._scanNoticeBatch, false
	end
	return NoticeBatch:New(owner), true
end

local function queueLeaderNotice(owner, leader)
	local batch, finishNow = noticeBatch(owner)
	batch:AddLeader(leader)
	if finishNow then
		batch:Finish()
	end
end

local function queueTitleRelationNotice(owner, leader, title)
	local batch, finishNow = noticeBatch(owner)
	batch:AddTitleRelation(leader, title)
	if finishNow then
		batch:Finish()
	end
end

local function beginManualTitleNotice(owner, kind)
	owner._manualTitleNotice = {
		kind = kind,
		leaders = {},
		leaderSeen = {},
	}
end

local function recordManualTitleNotice(
	owner, title, leader, displayLabel, chatTitleToken)
	local notice = owner._manualTitleNotice
	if type(notice) ~= "table" then
		notice = { kind = "title", leaders = {}, leaderSeen = {} }
		owner._manualTitleNotice = notice
	end
	notice.kind = "title"
	notice.title = title
	notice.displayLabel = stableTitleLabel(displayLabel)
		or notice.displayLabel
	if isWholeOpaqueTitleToken(chatTitleToken)
		and Matcher.SafeTextEquals(chatTitleToken, title)
	then
		notice.chatTitleToken = chatTitleToken
	end
	local normalized = Matcher.NormalizeLeader(leader)
	if normalized and not notice.leaderSeen[normalized] then
		notice.leaderSeen[normalized] = true
		notice.leaders[#notice.leaders + 1] = normalized
	end
end

local function publishManualTitleNotice(owner)
	local notice = owner._manualTitleNotice
	owner._manualTitleNotice = nil
	if type(notice) ~= "table" or notice.kind ~= "title"
		or notice.title == nil
	then
		return
	end
	local locale = GF.L or {}
	local titleShown = resolveTitleNoticeText(
		notice.title, notice.displayLabel, notice.chatTitleToken)
		or locale.BLOCK_NOTE_TITLE_UNREADABLE
		or "标题暂不可读"
	local leader = notice.leaders[1]
	if leader == nil then
		return
	end
	local message = buildTitleMatchMessage(locale, titleShown, leader)
	if message == nil then
		message = buildTitleMatchMessage(
			locale,
			locale.BLOCK_NOTE_TITLE_UNREADABLE or "标题暂不可读",
			leader)
	end
	if message ~= nil then
		owner:Tip(message)
	end
end

local function queueNewEntryNotice(owner, row, options)
	if options.skipTip == true then
		return
	end
	if row.kind == "title" then
		if owner._manualTitleNotice then
			recordManualTitleNotice(
				owner,
				row.title,
				row.leader,
				options.displayLabel,
				options.chatTitleToken)
		end
		return
	end
	if Matcher.IsUsableText(options.sourceTitle) then
		queueTitleRelationNotice(owner, row.leader, options.sourceTitle)
	else
		queueLeaderNotice(owner, row.leader)
	end
end

local function addPersistedEntry(owner, kind, leader, title, note, options)
	local row, existed = Repository:Add(kind, leader, title, note, options)
	if row and not existed then
		queueNewEntryNotice(owner, row, options)
	end
	return row, existed
end

function BL:FindMatch(resultID, info)
	if self:IsEnabled() ~= true or resultID == nil
		or next(self.leaders or {}) == nil
	then
		return nil
	end
	local resultInfo = suppliedOrFreshResultInfo(info, resultID)
	if not isAccessibleNonSecretTable(resultInfo) then
		return nil
	end
	local leaderName, leaderOK = readAccessibleField(resultInfo, "leaderName")
	local leader = leaderOK and Matcher.NormalizeLeader(leaderName) or nil
	if leader ~= nil and Repository:HasLeader(leader) then
		return "leader", Repository:FindLeader(leader)
	end
	return nil
end

function BL:FindPlayerMatch(playerName)
	if self:IsEnabled() ~= true or not Repository:HasLeader(playerName) then
		return nil
	end
	return Repository:FindLeader(playerName) or true
end

function BL:ShouldHide(resultID, info, entry)
	local findGroup = GF.FindGroup
	if findGroup and type(findGroup.ShouldHideBlockedResult) == "function" then
		return findGroup:ShouldHideBlockedResult(resultID, info, entry)
	end
	return self:FindMatch(resultID, info) ~= nil
end

function BL:FormatEntryNote(entry, childCount)
	local locale = GF.L or {}
	if type(entry) ~= "table" then
		return ""
	end
	local leaderShown = Matcher.NormalizeLeader(entry.leader)
		or entry.leader or "?"
	if entry.kind == "title" then
		return string.format(
			locale.BLOCK_NOTE_TITLE_PARENT_FMT or "标题父项：%s",
			leaderShown)
	end
	if Matcher.IsUsableText(entry.sourceTitle) then
		local parent = Repository:FindTitle(entry.sourceTitle)
		local parentLeader = parent
			and (Matcher.NormalizeLeader(parent.leader) or parent.leader) or "?"
		return string.format(
			locale.BLOCK_NOTE_TITLE_CHILD_FMT
				or "由【%s】的标题行为传染拉黑",
			parentLeader)
	end
	return entry.note or locale.BLOCK_NOTE_LEADER or "Blocked leader"
end

function BL:LinkLeaderToBlockedTitle(leader, title, opts)
	local options = type(opts) == "table" and opts or {}
	if not Matcher.IsUsableText(title) then
		return
	end
	local normalized = Matcher.NormalizeLeader(leader)
	if normalized == nil then
		return
	end
	Repository:IndexLeader(normalized)
	syncRepositoryState(self)
	if Repository:IsTitleParentLeader(title, normalized) then
		return
	end
	local row = Repository:FindLeader(normalized, title)
		or Repository:FindLeader(normalized)
	if row then
		if options.source ~= nil or options.note ~= nil
			or options.forceNote == true
		then
			Repository:Touch(row, {
				source = options.source,
				sourceTitle = title,
				note = options.note,
				forceNote = options.forceNote,
			})
		end
		return
	end
	addPersistedEntry(self, "leader", normalized, nil, options.note, {
		sourceTitle = title,
		source = options.source or SOURCES.BLOCK_TITLE,
		forceNote = options.forceNote,
		skipTip = options.skipTip,
	})
	if self._scanNoticeBatch ~= nil then
		self._scanNoticeBatch:RequestPanelRefresh()
	elseif GF.BlocklistPanel and type(GF.BlocklistPanel.Refresh) == "function" then
		GF.BlocklistPanel:Refresh()
	end
end

function BL:IndexVisibleLeadersForBlockedTitle(titleToken, displayLabel)
	if not Matcher.IsUsableText(titleToken)
		or self:IsEnabled() ~= true
	then
		return 0
	end
	local result = GF.Result
	local order = result and (result.frozenOrder or result.resultIDs) or {}
	if #order == 0 then
		return 0
	end
	local seen, linkedCount = {}, 0
	local targetLabel = stableTitleLabel(displayLabel)
	for _, resultID in ipairs(order) do
		local info = getSearchResultInfo(resultID)
		local title = resolveReliableTitle(resultID, info)
		local matches = Matcher.SafeTextEquals(title, titleToken)
		if not matches and targetLabel ~= nil then
			matches = resolveStableDisplayTitle(resultID, info, nil, info)
				== targetLabel
		end
		if type(info) == "table" and matches then
			local leaderName, leaderOK = readAccessibleField(info, "leaderName")
			local leader = leaderOK and Matcher.NormalizeLeader(leaderName) or nil
			if leader ~= nil and not seen[leader] then
				seen[leader] = true
				self:LinkLeaderToBlockedTitle(leader, titleToken)
				linkedCount = linkedCount + 1
			end
		end
	end
	return linkedCount
end

function BL:IndexRevealedSearchResult(resultID, info)
	if self:IsEnabled() ~= true or type(info) ~= "table"
		or isCensoredResultInfo(info)
	then
		return false
	end
	-- The supplied table is the authoritative post-reveal reread.
	local title = reliableTitle(info.name)
	local titleEntry = title and Repository:FindTitle(title)
	local leader = Matcher.NormalizeLeader(info.leaderName)
	if not (titleEntry and leader) then
		return false
	end
	self:LinkLeaderToBlockedTitle(leader, title, {
		skipTip = true,
		source = SOURCES.BLOCK_TITLE,
		note = NOTES.SAME_TITLE,
		forceNote = true,
	})
	Repository:BumpRevision()
	syncRepositoryState(self)
	local result = GF.Result
	if result and type(result.InvalidateAllBlockedMemberCache) == "function" then
		result:InvalidateAllBlockedMemberCache()
	end
	return true
end

function BL:RefreshAfterBlock(preferredResultID)
	Repository:BumpRevision()
	syncRepositoryState(self)
	local result = GF.Result
	if result and type(result.InvalidateAllBlockedMemberCache) == "function" then
		result:InvalidateAllBlockedMemberCache()
	end
	local tab = GF.FindGroupTab
	local retiring = tab and type(tab.RetireHiddenByBlocklist) == "function"
		and tab:RetireHiddenByBlocklist(preferredResultID) == true
	if not retiring and tab
		and type(tab.RemoveHiddenByBlocklist) == "function"
	then
		tab:RemoveHiddenByBlocklist()
	end
	if GF.BlocklistPanel and type(GF.BlocklistPanel.Refresh) == "function" then
		GF.BlocklistPanel:Refresh()
	end
end

function BL:AddLeader(leaderName, note, displayLabel, preferredResultID)
	return self:AddLeaderWithSource(
		leaderName, note, displayLabel, SOURCES.BLOCK_LEADER,
		true, false, preferredResultID)
end

function BL:AddManualPlayer(playerName, note)
	return self:AddLeaderWithSource(
		playerName, note, nil, SOURCES.MANUAL, true, true)
end

function BL:AddLeaderWithSource(
	leaderName,
	note,
	displayLabel,
	source,
	forceNote,
	clearSourceTitle,
	preferredResultID,
	skipTip)
	if self:IsEnabled() ~= true then
		return false
	end
	local leader = Matcher.NormalizeLeader(leaderName)
	if leader == nil then
		return false
	end
	local resolvedSource = source or SOURCES.BLOCK_LEADER
	local row = addPersistedEntry(self, "leader", leader, nil, note, {
		displayLabel = displayLabel,
		source = resolvedSource,
		forceNote = forceNote == true,
		skipTip = skipTip == true,
		clearSourceTitle = clearSourceTitle == true
			or Matcher.SourceCreatesStandaloneLeader(resolvedSource),
	})
	if row == nil then
		return false
	end
	Repository:IndexLeader(leader)
	syncRepositoryState(self)
	self:RefreshAfterBlock(preferredResultID)
	return true
end

local function addTitle(
	owner,
	title,
	leaderName,
	note,
	displayLabel,
	preferredResultID,
	chatTitleToken)
	if owner:IsEnabled() ~= true or not Matcher.IsUsableText(title) then
		return false
	end
	local leader = Matcher.NormalizeLeader(leaderName)
	beginManualTitleNotice(owner, "title")
	local row = addPersistedEntry(
		owner, "title", leader or title, title, note, {
			displayLabel = displayLabel,
			chatTitleToken = chatTitleToken,
			source = SOURCES.BLOCK_TITLE,
		})
	if row == nil then
		owner._manualTitleNotice = nil
		return false
	end
	titleEvidence:Remember(title)
	if leader ~= nil then
		Repository:IndexLeader(leader)
		syncRepositoryState(owner)
		owner:LinkLeaderToBlockedTitle(leader, title, {
			skipTip = true,
			source = SOURCES.BLOCK_TITLE,
			note = note or NOTES.SAME_TITLE,
			forceNote = true,
		})
	end
	owner:BeginScanTipBatch()
	owner:IndexVisibleLeadersForBlockedTitle(title, displayLabel)
	publishManualTitleNotice(owner)
	owner:RefreshAfterBlock(preferredResultID)
	owner:EndScanTipBatch()
	return true
end

function BL:AddTitle(title, leaderName, note, displayLabel, preferredResultID)
	return addTitle(
		self, title, leaderName, note, displayLabel, preferredResultID, nil)
end

function BL:AddTitleLeader(title, leaderName, displayLabel, preferredResultID)
	return self:AddTitle(
		title,
		leaderName,
		NOTES.SAME_TITLE,
		stableTitleLabel(displayLabel),
		preferredResultID)
end

function BL:AddAdvertisementLeader(leaderName, preferredResultID)
	return self:AddLeaderWithSource(
		leaderName,
		NOTES.ADVERTISEMENT,
		nil,
		SOURCES.REPORT_AD,
		true,
		false,
		preferredResultID,
		true)
end

function BL:TipUnreadableTitleFallback()
	local locale = GF.L or {}
	self:Tip(locale.BLOCK_TIP_TITLE_UNREADABLE_FALLBACK
		or "Group title is unreadable; only the current leader was blocked.")
end

function BL:BlockLeaderFromSearchResult(resultID, info)
	local resultInfo = suppliedOrFreshResultInfo(info, resultID)
	local leaderName, leaderOK = readAccessibleField(resultInfo, "leaderName")
	if not leaderOK then
		return false
	end
	local added = self:AddLeaderWithSource(
		leaderName,
		NOTES.MANUAL,
		nil,
		SOURCES.BLOCK_LEADER,
		true,
		false,
		resultID,
		true)
	if added then
		local locale = GF.L or {}
		self:Tip(string.format(
			locale.BLOCK_TIP_LEADER_ADDED_FMT or "已将 %s 加入黑名单。",
			colorLeaderName(leaderName)))
	end
	return added
end

function BL:BlockSameTitleFromSearchResult(resultID, info, displayTitle)
	local resultInfo = suppliedOrFreshResultInfo(info, resultID)
	if not isAccessibleNonSecretTable(resultInfo) then
		return false
	end
	local leader, leaderOK = readAccessibleField(resultInfo, "leaderName")
	leader = leaderOK and Matcher.NormalizeLeader(leader) or nil
	if leader == nil then
		return false
	end
	local title, titleInfo = resolveReliableTitle(
		resultID, resultInfo, displayTitle, true)
	if title then
		local label = resolveStableDisplayTitle(
			resultID, resultInfo, displayTitle, titleInfo)
		local chatTitleToken
		if label == nil and isWholeOpaqueTitleToken(title) then
			chatTitleToken = freshChatTitleToken(resultID, title, leader)
		end
		return addTitle(
			self,
			title,
			leader,
			NOTES.SAME_TITLE,
			stableTitleLabel(label),
			resultID,
			chatTitleToken)
	end
	local added = self:AddLeaderWithSource(
		leader,
		NOTES.MANUAL,
		nil,
		SOURCES.BLOCK_LEADER,
		true,
		false,
		resultID)
	self:TipUnreadableTitleFallback()
	return added
end

function BL:BlockAdvertisementFromSearchResult(resultID, info)
	local resultInfo = suppliedOrFreshResultInfo(info, resultID)
	local leaderName, leaderOK = readAccessibleField(resultInfo, "leaderName")
	return leaderOK and self:AddAdvertisementLeader(leaderName, resultID) or false
end

function BL:TipAdvertisementReport(leaderName, addedToBlocklist)
	local locale = GF.L or {}
	local submitted = locale.BLOCK_TIP_REPORT_AD_SUBMITTED
		or "已向暴雪提交广告举报！"
	local message = colorStatusText(
		submitted,
		getSystemMessageColorCode())
	local leader = Matcher.NormalizeLeader(leaderName)
	if addedToBlocklist == true and leader ~= nil then
		message = message .. string.format(
			locale.BLOCK_TIP_REPORT_AD_BLOCKED_FMT
				or "同时已将 %s 加入黑名单。",
			colorLeaderName(leader))
	end
	self:Tip(message)
end

function BL:Tip(message)
	local database = GF.GetDB()
	if database.showBlacklistChatNotice == false or message == nil then
		return
	end
	if type(GF.ShowStatusMessage) == "function" then
		GF.ShowStatusMessage(message)
	elseif type(print) == "function" then
		print(message)
	end
end

function BL:GetBlacklistNoteManual()
	return NOTES.MANUAL
end

function BL:GetEntryReason(entry)
	return Matcher.ClassifyReason(entry)
end

function BL:GetEntryReasonText(reason)
	local locale = GF.L or {}
	if reason == "ad" then
		return locale.BLOCKLIST_REASON_AD or "广告"
	end
	if reason == "title_parent" then
		return locale.BLOCKLIST_REASON_TITLE_PARENT or "标题父项"
	end
	if reason == "same_title_ad" then
		return locale.BLOCKLIST_REASON_TITLE or "标题传染"
	end
	return locale.BLOCKLIST_REASON_MANUAL or "手动添加"
end

function BL:GetEntrySourceText(reason)
	local locale = GF.L or {}
	if reason == "ad" then
		return locale.BLOCKLIST_SOURCE_REPORT_AD or "右键举报广告"
	end
	if reason == "title_parent" then
		return locale.BLOCKLIST_SOURCE_TITLE_PARENT or "同标题批处理父项"
	end
	if reason == "same_title_ad" then
		return locale.BLOCKLIST_SOURCE_TITLE or "屏蔽同标题广告来源"
	end
	return locale.BLOCKLIST_SOURCE_MANUAL or "加入黑名单"
end

local function compareByUpdated(left, right)
	local leftUpdated = tonumber(left and (left.updatedAt or left.addedAt)) or 0
	local rightUpdated = tonumber(right and (right.updatedAt or right.addedAt)) or 0
	if leftUpdated ~= rightUpdated then
		return leftUpdated > rightUpdated
	end
	local leftName = left and (left.displayName or left.name or left.key) or ""
	local rightName = right and (right.displayName or right.name or right.key) or ""
	return tostring(leftName) < tostring(rightName)
end

function BL:GetBlacklistEntries()
	local entries = {}
	for index, row in ipairs(Repository:GetRows() or {}) do
		if row.kind == "title" and row.title then
			local key = row.key or ("title:" .. tostring(row.title))
			local updatedAt = Repository:EnsurePresentationFields(row, key)
			local leader = Matcher.NormalizeLeader(row.leader)
				or self:GetDisplayText(row, "parent")
			local entry = {
				key = key,
				name = leader,
				displayName = leader,
				note = self:FormatEntryNote(
					row, #Repository:GetTitleChildren(row)),
				source = row.source or "",
				addedAt = tonumber(row.addedAt) or updatedAt,
				updatedAt = tonumber(row.updatedAt) or updatedAt,
				_row = row,
			}
			entry.reason = self:GetEntryReason(row)
			entries[#entries + 1] = entry
		elseif row.kind == "leader" then
			local leader = Matcher.NormalizeLeader(row.leader)
			if leader and not Repository:IsTitleParentLeader(
				row.sourceTitle, leader)
			then
				local key = row.key or Matcher.BuildLeaderKey(leader)
					or ("leader:" .. tostring(index))
				local updatedAt = Repository:EnsurePresentationFields(row, key)
				local name, realm = Matcher.SplitLeaderRealm(leader)
				local entry = {
					key = key,
					name = name or leader,
					realm = realm,
					displayName = leader,
					note = self:FormatEntryNote(row),
					source = row.source or "",
					addedAt = tonumber(row.addedAt) or updatedAt,
					updatedAt = tonumber(row.updatedAt) or updatedAt,
					sourceTitle = row.sourceTitle,
					_row = row,
				}
				entry.reason = self:GetEntryReason(row)
				entries[#entries + 1] = entry
			end
		end
	end
	table.sort(entries, compareByUpdated)
	return entries
end

function BL:SetBlacklistNote(entryOrKey, note)
	if not Repository:SetNote(entryOrKey, note) then
		return false
	end
	self:RefreshAfterBlock()
	return true
end

function BL:RemovePlayerFromBlacklist(entryOrKey)
	local removed, row = Repository:Remove(entryOrKey)
	if not removed then
		return false
	end
	self:RebuildMaps()
	self:RefreshAfterBlock()
	return true, row
end

function BL:ClearBlacklist()
	local cleared, removedCount = Repository:Clear()
	if not cleared then
		return false, 0
	end
	self:ClearTipState()
	self:ClearReadableTitleTokens()
	self:RebuildMaps()

	local result = GF.Result
	if result and type(result.InvalidateAllBlockedMemberCache) == "function" then
		result:InvalidateAllBlockedMemberCache()
	end
	local tab = GF.FindGroupTab
	if tab and type(tab.RefreshResults) == "function" then
		tab:RefreshResults({ preserveScroll = true })
	end
	if GF.BlocklistPanel and type(GF.BlocklistPanel.Refresh) == "function" then
		GF.BlocklistPanel:Refresh()
	end
	return true, removedCount
end
