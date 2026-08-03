local addonName, GF = ...

GF.Blocklist = {}

local BL = GF.Blocklist
local PREVIEW_MAX_CHARS = 50
local NOTE_ADVERTISEMENT = "广告"
local NOTE_SAME_TITLE = "同标题广告传染"
local NOTE_MANUAL = "手动拉黑"
local SOURCE_BLOCK_LEADER = "findgroup_block_leader"
local SOURCE_BLOCK_TITLE = "findgroup_block_title"
local SOURCE_REPORT_AD = "findgroup_report_ad"
local SOURCE_MANUAL = "manual_context_menu"
local TITLE_REVEAL_RETRY_DELAYS = { 0.25, 0.75, 1.5 }

local function truncatePreview(text)
	if type(text) ~= "string" or text == "" then
		return ""
	end
	if utf8 and type(utf8.len) == "function" and type(utf8.offset) == "function" then
		local length = utf8.len(text)
		if length and length <= PREVIEW_MAX_CHARS then
			return text
		end
		local boundary = utf8.offset(text, PREVIEW_MAX_CHARS + 1)
		if boundary ~= nil then
			return string.sub(text, 1, boundary - 1) .. "..."
		end
	end
	local byteLimit = PREVIEW_MAX_CHARS * 3
	if #text > byteLimit then
		return string.sub(text, 1, byteLimit) .. "..."
	end
	return text
end

local function trim(s)
	if type(s) ~= "string" then
		return ""
	end
	return s:match("^%s*(.-)%s*$") or ""
end

local function normalizeLeader(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if type(Ambiguate) == "function" then
		local normalized = Ambiguate(name, "none")
		return normalized ~= "" and normalized or nil
	end
	return name
end

local function getCurrentRealmName()
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	if realm and realm ~= "" then
		return realm
	end
	realm = GetRealmName and GetRealmName()
	if realm and realm ~= "" then
		return realm
	end
	return nil
end

local function splitLeaderRealm(leader)
	leader = normalizeLeader(leader)
	if not leader then
		return nil, nil
	end
	local name, realm = leader:match("^([^-]+)%-(.+)$")
	if name and name ~= "" and realm and realm ~= "" then
		return name, realm
	end
	return leader, getCurrentRealmName()
end

local function normalizeIdentifierPart(value)
	value = trim(value)
	if value == "" then
		return nil
	end
	return string.lower(value:gsub("%s+", ""))
end

local function getNow()
	if time then
		return time()
	end
	if GetTime then
		return math.floor(GetTime())
	end
	return 0
end

local function formatEntryTime(timestamp)
	timestamp = tonumber(timestamp) or getNow()
	if date then
		return date("%Y-%m-%d %H:%M", timestamp)
	end
	return tostring(timestamp)
end

local function parseEntryTimestamp(entry)
	if not entry then
		return 0
	end
	local value = tonumber(entry.updatedAt or entry.addedAt)
	if value and value > 0 then
		return value
	end
	local timeText = entry.time
	if type(timeText) == "string" then
		local y, m, d, h, min = timeText:match("^(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+)$")
		if y and time then
			return time({
				year = tonumber(y),
				month = tonumber(m),
				day = tonumber(d),
				hour = tonumber(h),
				min = tonumber(min),
				sec = 0,
			}) or 0
		end
	end
	return 0
end

local function buildLeaderKey(leader)
	local normalized = normalizeIdentifierPart(leader)
	if not normalized then
		return nil
	end
	return "leader:" .. normalized
end

local function getDefaultNoteForSource(source)
	source = tostring(source or "")
	if source:find("report_ad", 1, true) then
		return NOTE_ADVERTISEMENT
	end
	if source:find("block_title", 1, true) then
		return NOTE_SAME_TITLE
	end
	return NOTE_MANUAL
end

local function sourceCreatesStandaloneLeader(source)
	return source == SOURCE_MANUAL
		or source == SOURCE_BLOCK_LEADER
		or source == SOURCE_REPORT_AD
end

local function setRowUpdateFields(row, extra)
	if type(row) ~= "table" then
		return
	end
	local options = type(extra) == "table" and extra or {}
	local now = getNow()
	row.addedAt = tonumber(row.addedAt) or now
	row.updatedAt = now
	row.time = formatEntryTime(now)
	if type(options.source) == "string" and options.source ~= "" then
		row.source = options.source
	end
	if type(options.key) == "string" and options.key ~= "" then
		row.key = options.key
	elseif row.kind == "leader" then
		row.key = row.key or buildLeaderKey(row.leader)
	end
	if options.clearSourceTitle == true then
		row.sourceTitle = nil
	elseif type(options.sourceTitle) == "string" and options.sourceTitle ~= "" then
		row.sourceTitle = options.sourceTitle
	end
	local label = trim(options.displayLabel)
	if label ~= "" then
		row.displayLabel = label
	end
	local note = trim(options.note)
	if note ~= "" then
		row.note = note
	elseif options.forceNote == true then
		row.note = getDefaultNoteForSource(options.source)
	end
end

local SECRET_TOKEN_PATTERN = "^|K.-|k$"

-- Title tokens still renderable this login session (cleared on PLAYER_LOGIN / 小退再进).
local readableTitleTokens = {}

local function isSecretToken(text)
	return type(text) == "string"
		and text ~= ""
		and string.match(text, SECRET_TOKEN_PATTERN) ~= nil
end

local function markReadableTitleToken(title)
	if not isSecretToken(title) then
		return
	end
	readableTitleTokens[title] = true
end

local function isReliableTitleText(title)
	if title == nil then
		return false
	end
	if issecretvalue and issecretvalue(title) then
		return false
	end
	if type(title) ~= "string" then
		return false
	end
	title = trim(title)
	if title == "" or title == "?" then
		return false
	end
	if GF.Result and GF.Result.IsUnreadableLfgText and GF.Result:IsUnreadableLfgText(title) then
		return false
	end
	return true, title
end

local function isStableTitleLabelText(title)
	local ok, label = isReliableTitleText(title)
	if not ok or isSecretToken(label) then
		return nil
	end
	return label
end

local function getSearchResultInfo(resultID)
	if not (resultID and C_LFGList and C_LFGList.GetSearchResultInfo) then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
	if ok then
		return info
	end
	return nil
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

local function resolveReliableTitle(resultID, info, displayTitle, preferFresh)
	local fresh
	local ok, title
	if preferFresh then
		fresh = getSearchResultInfo(resultID)
		ok, title = isReliableTitleText(fresh and fresh.name)
		if ok then
			return title, fresh
		end
	end
	ok, title = isReliableTitleText(info and info.name)
	if ok then
		return title, info
	end
	local cached = getCachedSearchResultInfo(resultID)
	ok, title = isReliableTitleText(cached and cached.name)
	if ok then
		return title, cached
	end
	if not preferFresh then
		fresh = getSearchResultInfo(resultID)
		ok, title = isReliableTitleText(fresh and fresh.name)
		if ok then
			return title, fresh
		end
	end
	ok, title = isReliableTitleText(displayTitle)
	if ok then
		return title, cached or info or fresh
	end
	return nil, fresh or info or cached
end

local function resolveStableDisplayTitle(resultID, info, displayTitle, titleInfo)
	local label = isStableTitleLabelText(displayTitle)
	if label then
		return label
	end
	label = isStableTitleLabelText(titleInfo and titleInfo.name)
	if label then
		return label
	end
	label = isStableTitleLabelText(info and info.name)
	if label then
		return label
	end
	local cached = getCachedSearchResultInfo(resultID)
	label = isStableTitleLabelText(cached and cached.name)
	if label then
		return label
	end
	return nil
end

local function tryRevealCensoredSearchResult(resultID)
	if not (resultID and C_LFGList and C_LFGList.RevealCensoredSearchResult) then
		return false
	end
	local ok = pcall(C_LFGList.RevealCensoredSearchResult, resultID)
	return ok == true
end

local function resolveDisplayText(blizzardText, displayLabel)
	local nativeText = type(blizzardText) == "string" and blizzardText or ""
	local fallback = type(displayLabel) == "string" and displayLabel or ""
	if nativeText == "" then
		return fallback ~= "" and fallback or "?"
	end
	local hiddenToken = isSecretToken(nativeText)
	local readableThisSession = hiddenToken and readableTitleTokens[nativeText] == true
	if not hiddenToken or readableThisSession or fallback == "" then
		return nativeText
	end
	return fallback
end

function BL:ClearReadableTitleTokens()
	for token in pairs(readableTitleTokens) do
		readableTitleTokens[token] = nil
	end
end

local function findBlockRow(db, predicate)
	local list = type(db) == "table" and db.blocklist or nil
	for _, row in ipairs(type(list) == "table" and list or {}) do
		if predicate(row) then
			return row
		end
	end
	return nil
end

local function findLeaderRow(db, leader, sourceTitle)
	local targetLeader = normalizeLeader(leader)
	if targetLeader == nil then
		return false, nil
	end
	local row = findBlockRow(db, function(candidate)
		return candidate.kind == "leader"
			and normalizeLeader(candidate.leader) == targetLeader
			and (sourceTitle == nil or candidate.sourceTitle == sourceTitle)
	end)
	return row ~= nil, row
end

local function leaderRowInList(db, leader)
	return findLeaderRow(db, leader, nil)
end

local function findLeaderForSourceTitle(db, leader, sourceTitle)
	if type(sourceTitle) ~= "string" or sourceTitle == "" then
		return false, nil
	end
	return findLeaderRow(db, leader, sourceTitle)
end

local function findTitleRow(db, title)
	if type(title) ~= "string" or title == "" then
		return false, nil
	end
	local row = findBlockRow(db, function(candidate)
		return candidate.kind == "title" and candidate.title == title
	end)
	return row ~= nil, row
end

local function titleInList(db, title)
	return findTitleRow(db, title)
end

local function isTitleParentLeader(db, title, leader)
	local normalizedLeader = normalizeLeader(leader)
	if type(title) ~= "string" or title == "" or normalizedLeader == nil then
		return false
	end
	local exists, row = findTitleRow(db, title)
	return exists == true and normalizeLeader(row.leader) == normalizedLeader
end

local function pruneRedundantTitleChildren(db, selected)
	local list = type(db.blocklist) == "table" and db.blocklist or {}
	local kept = {}
	local removedCount = 0
	for _, row in ipairs(list) do
		local redundant = row and row.kind == "leader"
			and row.sourceTitle ~= nil
			and isTitleParentLeader(db, row.sourceTitle, row.leader)
		if redundant then
			if selected then
				selected[row] = nil
			end
			removedCount = removedCount + 1
		else
			kept[#kept + 1] = row
		end
	end
	if removedCount > 0 then
		db.blocklist = kept
	end
	return removedCount > 0
end

local function clearStaleSourceTitles(db)
	for _, row in ipairs(type(db.blocklist) == "table" and db.blocklist or {}) do
		if type(row) == "table"
			and row.kind == "leader"
			and sourceCreatesStandaloneLeader(row.source)
		then
			row.sourceTitle = nil
		end
	end
end

function BL:Init()
	self._selected = setmetatable({}, { __mode = "k" })
	self:ClearTipState()
	self:RebuildMaps()
end

function BL:ClearTipState()
	for _, key in ipairs({
		"_pendingLeaderTips",
		"_pendingLeaderTipSeen",
		"_pendingContagionTips",
		"_pendingContagionSeen",
		"_manualTip",
	}) do
		self[key] = nil
	end
	self._scanBatchActive = false
	self._scanPanelDirty = false
end

function BL:IsEnabled()
	local db = GF.GetDB()
	return db.blacklistEnabled ~= false
end

function BL:RebuildMaps()
	local leaders = {}
	local db = GF.GetDB()
	clearStaleSourceTitles(db)
	if self:IsEnabled() then
		pruneRedundantTitleChildren(db, self._selected)
		for _, entry in ipairs(db.blocklist or {}) do
			local leader = normalizeLeader(entry.leader)
			local supportedKind = entry.kind == "leader" or entry.kind == "title"
			if leader ~= nil and supportedKind then
				leaders[leader] = true
			end
		end
	end
	self.leaders = leaders
	self.revision = 1 + (self.revision or 0)
end

function BL:GetRevision()
	return self.revision or 0
end

function BL:FindTitleEntry(titleToken)
	local db = GF.GetDB()
	local _, row = findTitleRow(db, titleToken)
	return row
end

function BL:GetDisplayText(entry, itemRole)
	if type(entry) ~= "table" then
		return "?"
	end
	local useTitle = entry.kind == "title" or itemRole == "parent"
	local nativeText = useTitle and entry.title or entry.leader
	return resolveDisplayText(nativeText, entry.displayLabel)
end

function BL:FormatTitleTag(entry)
	local locale = GF.L or {}
	local tag = locale.BLOCKLIST_TAG_TITLE or "[Title]"
	local custom = type(entry) == "table"
		and type(entry.displayLabel) == "string"
		and entry.displayLabel ~= ""
		and entry.title ~= nil
		and self:GetDisplayText(entry) == entry.displayLabel
	if custom then
		tag = tag .. (locale.BLOCKLIST_TAG_CUSTOM or "[Custom]")
	end
	return tag
end

function BL:FormatTargetText(entry, itemRole)
	if type(entry) ~= "table" then
		return "?"
	end
	local locale = GF.L or {}
	local isTitle = itemRole == "parent" or entry.kind == "title"
	local tag = isTitle and self:FormatTitleTag(entry)
		or locale.BLOCKLIST_TAG_LEADER or "[Leader]"
	return tag .. " " .. self:GetDisplayText(entry, itemRole)
end

function BL:BuildBlockPreview(info)
	if type(info) ~= "table" then
		return "", ""
	end
	return truncatePreview(info.name), truncatePreview(info.comment)
end

local function tipLabelText(text)
	return type(text) == "string" and text or ""
end

function BL:BeginScanTipBatch()
	if self._scanBatchActive == true then
		self:EndScanTipBatch()
	end
	self._scanBatchActive = true
end

function BL:FlushLeaderTips()
	local leaders = self._pendingLeaderTips or {}
	self._pendingLeaderTips = nil
	self._pendingLeaderTipSeen = nil
	if #leaders == 0 then
		return
	end
	local locale = GF.L or {}
	local prefix = tipLabelText(locale.BLOCK_TIP_LEADER_PREFIX or "Blocked leader: ")
	self:Tip(prefix .. table.concat(leaders, "、"))
end

function BL:FlushContagionTips()
	local tips = self._pendingContagionTips or {}
	self._pendingContagionTips = nil
	self._pendingContagionSeen = nil
	if #tips == 0 then
		return
	end
	local locale = GF.L or {}
	local titlePrefix = tipLabelText(locale.BLOCK_TIP_CONTAGION_TITLE_PREFIX or "Title ")
	local middle = tipLabelText(locale.BLOCK_TIP_CONTAGION_MID or " contagion block ")
	for _, tip in ipairs(tips) do
		local titleShown = resolveDisplayText(tip.sourceTitle, nil)
		self:Tip(titlePrefix .. titleShown .. middle .. tip.leader)
	end
end

function BL:EndScanTipBatch()
	if self._scanBatchActive ~= true then
		return
	end
	self._scanBatchActive = false
	self:FlushContagionTips()
	self:FlushLeaderTips()
	local panel = GF.BlocklistPanel
	local refreshPanel = self._scanPanelDirty == true
		and panel and type(panel.Refresh) == "function"
	self._scanPanelDirty = false
	if refreshPanel then
		panel:Refresh()
	end
end

local function appendUniqueTip(owner, seenField, listField, key, value)
	local seen = owner[seenField]
	if seen == nil then
		seen = {}
		owner[seenField] = seen
	end
	if seen[key] then
		return false
	end
	seen[key] = true
	local list = owner[listField]
	if list == nil then
		list = {}
		owner[listField] = list
	end
	list[#list + 1] = value
	return true
end

local function queueLeaderTip(bl, leader)
	local normalized = normalizeLeader(leader)
	if normalized == nil then
		return
	end
	appendUniqueTip(
		bl,
		"_pendingLeaderTipSeen",
		"_pendingLeaderTips",
		normalized,
		normalized)
end

local function queueContagionLeaderTip(bl, leader, sourceTitle)
	local normalized = normalizeLeader(leader)
	if normalized == nil or type(sourceTitle) ~= "string" or sourceTitle == "" then
		return
	end
	local key = table.concat({ sourceTitle, normalized }, "\0")
	appendUniqueTip(bl, "_pendingContagionSeen", "_pendingContagionTips", key, {
		leader = normalized,
		sourceTitle = sourceTitle,
	})
end

local function queueManualTitle(bl, title, leader, displayLabel)
	local batch = bl._manualTip
	if type(batch) ~= "table" then
		batch = { kind = "title", leaders = {}, leaderSeen = {} }
		bl._manualTip = batch
	end
	batch.kind = "title"
	batch.title = title
	batch.displayLabel = isStableTitleLabelText(displayLabel) or batch.displayLabel
	local normalized = normalizeLeader(leader)
	if normalized and not batch.leaderSeen[normalized] then
		batch.leaderSeen[normalized] = true
		batch.leaders[#batch.leaders + 1] = normalized
	end
end

function BL:BeginManualTip(kind)
	local batch = {
		kind = kind,
		leaders = {},
		leaderSeen = {},
	}
	self._manualTip = batch
	return batch
end

function BL:FlushManualTip()
	local batch = self._manualTip
	self._manualTip = nil
	if type(batch) ~= "table" then
		return
	end
	local locale = GF.L or {}
	if batch.kind == "title" and batch.title ~= nil then
		local titleShown = isStableTitleLabelText(batch.displayLabel)
			or isStableTitleLabelText(resolveDisplayText(batch.title, nil))
			or locale.BLOCK_NOTE_TITLE_UNREADABLE
			or "标题暂不可读"
		local titlePrefix = tipLabelText(locale.BLOCK_TIP_TITLE_PREFIX or "Blocked title: ")
		if batch.leaders[1] then
			local leadersPrefix = tipLabelText(locale.BLOCK_TIP_LEADERS_PREFIX or "; leaders: ")
			self:Tip(titlePrefix .. titleShown .. leadersPrefix .. table.concat(batch.leaders, "、"))
		else
			self:Tip(titlePrefix .. titleShown)
		end
	end
end

local function isSystemNote(kind, note)
	local normalized = trim(note)
	if normalized == "" then
		return true
	end
	local locale = GF.L or {}
	local defaults = {
		title = locale.BLOCK_NOTE_TITLE or "Blocked title",
		leader = locale.BLOCK_NOTE_LEADER or "Blocked leader",
	}
	return defaults[kind] ~= nil and normalized == defaults[kind]
end

local function findExistingEntry(db, kind, leader, title)
	if kind == "leader" then
		local exists, row = leaderRowInList(db, leader)
		return exists and row or nil
	end
	if kind == "title" then
		local exists, row = titleInList(db, title)
		return exists and row or nil
	end
	return nil
end

local function updateExistingEntry(row, kind, note, extra)
	local fields = {
		displayLabel = extra.displayLabel,
		note = note,
	}
	if kind == "leader" then
		fields.source = extra.source
		fields.sourceTitle = extra.sourceTitle
		fields.clearSourceTitle = extra.clearSourceTitle
		fields.forceNote = extra.forceNote
	end
	setRowUpdateFields(row, fields)
end

local function makeEntry(kind, leader, title, note, extra)
	local timestamp = getNow()
	local row = {
		leader = leader or title,
		kind = kind,
		addedAt = timestamp,
		updatedAt = timestamp,
		time = formatEntryTime(timestamp),
	}
	if kind == "leader" then
		row.key = buildLeaderKey(leader)
	end
	if type(title) == "string" and title ~= "" then
		row.title = title
	end
	local customNote = trim(note)
	if customNote ~= "" and not isSystemNote(kind, customNote) then
		row.note = customNote
	elseif extra.forceNote == true then
		row.note = getDefaultNoteForSource(extra.source)
	end
	if type(extra.source) == "string" and extra.source ~= "" then
		row.source = extra.source
	end
	if type(extra.sourceTitle) == "string" and extra.sourceTitle ~= "" then
		row.sourceTitle = extra.sourceTitle
	end
	local label = trim(extra.displayLabel)
	if label ~= "" then
		row.displayLabel = label
	end
	return row
end

local function queueAddedEntryTip(bl, row, extra)
	if row.kind == "title" then
		if bl._manualTip then
			queueManualTitle(bl, row.title, row.leader, extra.displayLabel)
		end
		return
	end
	local sourceTitle = extra.sourceTitle
	if type(sourceTitle) == "string" and sourceTitle ~= "" then
		if extra.skipTip ~= true then
			queueContagionLeaderTip(bl, row.leader, sourceTitle)
			if bl._scanBatchActive ~= true then
				bl:FlushContagionTips()
			end
		end
		return
	end
	queueLeaderTip(bl, row.leader)
	if bl._scanBatchActive ~= true then
		bl:FlushLeaderTips()
	end
end

local function addEntry(bl, kind, leader, title, note, extra)
	local options = type(extra) == "table" and extra or {}
	local normalizedLeader = normalizeLeader(leader)
	local validLeader = kind == "leader" and normalizedLeader ~= nil
	local validTitle = kind == "title" and type(title) == "string" and title ~= ""
	if not validLeader and not validTitle then
		return nil
	end
	local db = GF.GetDB()
	db.blocklist = type(db.blocklist) == "table" and db.blocklist or {}
	local existing = findExistingEntry(db, kind, normalizedLeader, title)
	if existing then
		updateExistingEntry(existing, kind, note, options)
		return existing, true
	end
	local row = makeEntry(kind, normalizedLeader, title, note, options)
	table.insert(db.blocklist, 1, row)
	queueAddedEntryTip(bl, row, options)
	return row
end

function BL:FindMatch(resultID, info)
	if self:IsEnabled() ~= true or resultID == nil or next(self.leaders or {}) == nil then
		return nil
	end
	local resultInfo = info or getSearchResultInfo(resultID)
	if type(resultInfo) ~= "table" then
		return nil
	end
	local leader = normalizeLeader(resultInfo.leaderName)
	if leader ~= nil and self.leaders[leader] then
		local _, row = findLeaderRow(GF.GetDB(), leader, nil)
		return "leader", row
	end
	return nil
end

function BL:FindPlayerMatch(playerName)
	if self:IsEnabled() ~= true then
		return nil
	end
	local leader = normalizeLeader(playerName)
	local indexed = leader ~= nil and self.leaders and self.leaders[leader]
	if not indexed then
		return nil
	end
	local _, row = findLeaderRow(GF.GetDB(), leader, nil)
	return row or true
end

function BL:ShouldHide(resultID, info)
	return self:FindMatch(resultID, info) ~= nil
end

local function getTitleChildren(list, titleEntry)
	local children = {}
	local titleKey = type(titleEntry) == "table" and titleEntry.title or nil
	if type(titleKey) ~= "string" or titleKey == "" then
		return children
	end
	local seen = {}
	local parentLeader = normalizeLeader(titleEntry.leader)
	if parentLeader ~= nil then
		seen[parentLeader] = true
	end
	for _, entry in ipairs(list or {}) do
		local isChild = entry.kind == "leader" and entry.sourceTitle == titleKey
		local leader = isChild and normalizeLeader(entry.leader) or nil
		if leader ~= nil and not seen[leader] then
			seen[leader] = true
			children[#children + 1] = entry
		end
	end
	return children
end

function BL:FormatEntryNote(entry, childCount)
	local locale = GF.L or {}
	if type(entry) ~= "table" then
		return ""
	end
	local leaderShown = normalizeLeader(entry.leader) or entry.leader or "?"
	if entry.kind == "title" then
		local fmt = locale.BLOCK_NOTE_TITLE_PARENT_FMT or "同标题广告屏蔽：%s"
		return string.format(fmt, leaderShown)
	end
	if type(entry.sourceTitle) == "string" and entry.sourceTitle ~= "" then
		local _, parent = findTitleRow(GF.GetDB(), entry.sourceTitle)
		local rawParentLeader = parent and parent.leader
		local parentLeader = normalizeLeader(rawParentLeader) or rawParentLeader or "?"
		local fmt = locale.BLOCK_NOTE_TITLE_CHILD_FMT or "来自 [%s] 的同标题广告传染"
		return string.format(fmt, parentLeader)
	end
	return entry.note or locale.BLOCK_NOTE_LEADER or "Blocked leader"
end

function BL:BuildDisplayList(expanded)
	local list = self:GetList()
	local openTitles = type(expanded) == "table" and expanded or {}
	local display = {}
	local seenTitles = {}
	for _, entry in ipairs(list) do
		local titleKey = entry.kind == "title" and entry.title or nil
		if titleKey and not seenTitles[titleKey] then
			seenTitles[titleKey] = true
			local children = getTitleChildren(list, entry)
			display[#display + 1] = {
				role = "parent",
				entry = entry,
				titleKey = titleKey,
				children = children,
				childCount = #children,
			}
			if openTitles[titleKey] then
				for _, child in ipairs(children) do
					display[#display + 1] = {
						role = "child",
						entry = child,
						titleKey = titleKey,
					}
				end
			end
		elseif entry.kind == "leader"
			and (type(entry.sourceTitle) ~= "string" or entry.sourceTitle == "")
		then
			display[#display + 1] = { role = "standalone", entry = entry }
		end
	end
	return display
end

function BL:IsEntrySelected(entry)
	return entry ~= nil and self._selected ~= nil and self._selected[entry] == true
end

function BL:SetEntrySelected(entry, selected)
	if entry == nil then
		return
	end
	self._selected = self._selected or setmetatable({}, { __mode = "k" })
	self._selected[entry] = selected == true and true or nil
end

function BL:SetGroupSelected(titleEntry, children, selected)
	if titleEntry == nil then
		return
	end
	local value = selected == true
	self:SetEntrySelected(titleEntry, value)
	local groupChildren = type(children) == "table" and children or {}
	for _, child in ipairs(groupChildren) do
		self:SetEntrySelected(child, value)
	end
end

function BL:OnChildSelected(titleEntry, checked)
	if titleEntry ~= nil and checked ~= true then
		self:SetEntrySelected(titleEntry, false)
	end
end

function BL:SetDisplayLabel(entry, label)
	if type(entry) ~= "table" then
		return
	end
	local normalized = trim(label)
	entry.displayLabel = normalized ~= "" and normalized or nil
	local panel = GF.BlocklistPanel
	if panel and type(panel.Refresh) == "function" then
		panel:Refresh()
	end
end

function BL:LinkLeaderToBlockedTitle(leader, title, opts)
	local options = type(opts) == "table" and opts or {}
	local db = GF.GetDB()
	if type(title) ~= "string" or title == "" then
		return
	end
	local normalizedLeader = normalizeLeader(leader)
	if normalizedLeader == nil then
		return
	end
	self.leaders[normalizedLeader] = true
	if isTitleParentLeader(db, title, normalizedLeader) then
		return
	end
	local exists, row = findLeaderForSourceTitle(db, normalizedLeader, title)
	if not exists then
		exists, row = leaderRowInList(db, normalizedLeader)
	end
	if row then
		if options.source ~= nil or options.note ~= nil or options.forceNote == true then
			setRowUpdateFields(row, {
				source = options.source,
				sourceTitle = title,
				note = options.note,
				forceNote = options.forceNote,
			})
		end
		return
	end
	addEntry(self, "leader", normalizedLeader, nil, options.note, {
		sourceTitle = title,
		source = options.source or SOURCE_BLOCK_TITLE,
		forceNote = options.forceNote,
		skipTip = options.skipTip,
	})
	if self._scanBatchActive == true then
		self._scanPanelDirty = true
	else
		local panel = GF.BlocklistPanel
		if panel and type(panel.Refresh) == "function" then
			panel:Refresh()
		end
	end
end

function BL:IndexVisibleLeadersForBlockedTitle(titleToken, displayLabel)
	if type(titleToken) ~= "string" or titleToken == ""
		or self:IsEnabled() ~= true
	then
		return 0
	end
	local resultService = GF.Result
	local order = resultService
		and (resultService.frozenOrder or resultService.resultIDs) or {}
	if #order == 0 then
		return 0
	end
	local seen = {}
	local linkedCount = 0
	local targetLabel = isStableTitleLabelText(displayLabel)
	for _, resultID in ipairs(order) do
		local info = getSearchResultInfo(resultID)
		local title = resolveReliableTitle(resultID, info)
		local matches = title == titleToken
		if not matches and targetLabel ~= nil then
			local rowLabel = resolveStableDisplayTitle(resultID, info, nil, info)
			matches = rowLabel == targetLabel
		end
		if type(info) == "table" and matches then
			local leader = normalizeLeader(info.leaderName)
			if leader ~= nil and not seen[leader] then
				seen[leader] = true
				self:LinkLeaderToBlockedTitle(leader, titleToken)
				linkedCount = linkedCount + 1
			end
		end
	end
	return linkedCount
end

function BL:RefreshAfterBlock()
	self.revision = 1 + (self.revision or 0)
	local resultService = GF.Result
	if resultService and type(resultService.InvalidateAllBlockedMemberCache) == "function" then
		resultService:InvalidateAllBlockedMemberCache()
	end
	local tab = GF.FindGroupTab
	if tab and type(tab.RemoveHiddenByBlocklist) == "function" then
		tab:RemoveHiddenByBlocklist()
	end
	if tab and type(tab.RefreshList) == "function" then
		tab:RefreshList({ preserveScroll = true })
	end
	local panel = GF.BlocklistPanel
	if panel and type(panel.Refresh) == "function" then
		panel:Refresh()
	end
end

function BL:AddLeader(leaderName, note, displayLabel)
	return self:AddLeaderWithSource(
		leaderName,
		note,
		displayLabel,
		SOURCE_BLOCK_LEADER,
		true)
end

function BL:AddManualPlayer(playerName, note)
	return self:AddLeaderWithSource(
		playerName,
		note,
		nil,
		SOURCE_MANUAL,
		true,
		true)
end

function BL:AddLeaderWithSource(
	leaderName,
	note,
	displayLabel,
	source,
	forceNote,
	clearSourceTitle)
	if self:IsEnabled() ~= true then
		return false
	end
	local leader = normalizeLeader(leaderName)
	if leader == nil then
		return false
	end
	local resolvedSource = source or SOURCE_BLOCK_LEADER
	local options = {
		displayLabel = displayLabel,
		source = resolvedSource,
		forceNote = forceNote == true,
		clearSourceTitle = clearSourceTitle == true
			or sourceCreatesStandaloneLeader(resolvedSource),
	}
	local row = addEntry(self, "leader", leader, nil, note, options)
	if row ~= nil then
		self.leaders[leader] = true
		self:RefreshAfterBlock()
		return true
	end
	return false
end

function BL:AddTitle(title, leaderName, note, displayLabel)
	if self:IsEnabled() ~= true or type(title) ~= "string" or title == "" then
		return false
	end
	local leader = normalizeLeader(leaderName)
	self:BeginManualTip("title")
	local titleOptions = {
		displayLabel = displayLabel,
		source = SOURCE_BLOCK_TITLE,
	}
	local row = addEntry(
		self,
		"title",
		leader or title,
		title,
		note,
		titleOptions)
	if row == nil then
		self._manualTip = nil
		return false
	end
	markReadableTitleToken(title)
	if leader ~= nil then
		self.leaders[leader] = true
		self:LinkLeaderToBlockedTitle(leader, title, {
			skipTip = true,
			source = SOURCE_BLOCK_TITLE,
			note = note or NOTE_SAME_TITLE,
			forceNote = true,
		})
	end
	self:BeginScanTipBatch()
	self:IndexVisibleLeadersForBlockedTitle(title, displayLabel)
	self:FlushManualTip()
	self:RefreshAfterBlock()
	self:EndScanTipBatch()
	return true
end

function BL:AddTitleLeader(title, leaderName, displayLabel)
	local label = isStableTitleLabelText(displayLabel)
	return self:AddTitle(title, leaderName, NOTE_SAME_TITLE, label)
end

function BL:AddAdvertisementLeader(leaderName)
	return self:AddLeaderWithSource(leaderName, NOTE_ADVERTISEMENT, nil, SOURCE_REPORT_AD, true)
end

function BL:TipUnreadableTitleFallback()
	local L = GF.L or {}
	self:Tip(L.BLOCK_TIP_TITLE_UNREADABLE_FALLBACK or "Group title is unreadable; only the current leader was blocked.")
end

function BL:QueueSameTitleRevealRetry(resultID, leaderName, displayTitle)
	if not resultID then
		return
	end
	self._pendingTitleRevealBlocks = self._pendingTitleRevealBlocks or {}
	local pending = self._pendingTitleRevealBlocks[resultID] or {}
	pending.token = (pending.token or 0) + 1
	pending.attempt = 0
	pending.leaderName = leaderName
	pending.displayTitle = displayTitle
	self._pendingTitleRevealBlocks[resultID] = pending

	self:ContinueSameTitleRevealRetry(resultID, pending.token)
end

function BL:ContinueSameTitleRevealRetry(resultID, token)
	local pending = self._pendingTitleRevealBlocks and self._pendingTitleRevealBlocks[resultID]
	if not pending or pending.token ~= token then
		return
	end

	local title, titleInfo = resolveReliableTitle(resultID, nil, pending.displayTitle, true)
	local displayLabel = title and resolveStableDisplayTitle(resultID, titleInfo, pending.displayTitle, titleInfo)
	if title then
		self._pendingTitleRevealBlocks[resultID] = nil
		self:AddTitleLeader(title, pending.leaderName or (titleInfo and titleInfo.leaderName), displayLabel)
		return
	end

	pending.attempt = (pending.attempt or 0) + 1
	local delay = TITLE_REVEAL_RETRY_DELAYS[pending.attempt]
	if not delay or not (C_Timer and C_Timer.After) then
		self._pendingTitleRevealBlocks[resultID] = nil
		self:TipUnreadableTitleFallback()
		return
	end

	C_Timer.After(delay, function()
		if self._pendingTitleRevealBlocks
			and self._pendingTitleRevealBlocks[resultID]
			and self._pendingTitleRevealBlocks[resultID].token == token then
			self:ContinueSameTitleRevealRetry(resultID, token)
		end
	end)
end

function BL:BlockLeaderFromSearchResult(resultID, info)
	if not info and resultID and C_LFGList and C_LFGList.GetSearchResultInfo then
		info = getSearchResultInfo(resultID)
	end
	return self:AddLeaderWithSource(info and info.leaderName, NOTE_MANUAL, nil, SOURCE_BLOCK_LEADER, true)
end

function BL:BlockSameTitleFromSearchResult(resultID, info, displayTitle)
	if not info and resultID and C_LFGList and C_LFGList.GetSearchResultInfo then
		info = getSearchResultInfo(resultID)
	end
	if not info then
		return false
	end
	local leaderName = info.leaderName
	if not normalizeLeader(leaderName) then
		return false
	end
	local title, titleInfo = resolveReliableTitle(resultID, info, displayTitle, true)
	local displayLabel = title and resolveStableDisplayTitle(resultID, info, displayTitle, titleInfo)
	if title then
		return self:AddTitleLeader(title, leaderName, displayLabel)
	end

	local added = self:AddLeaderWithSource(leaderName, NOTE_MANUAL, nil, SOURCE_BLOCK_LEADER, true)
	if tryRevealCensoredSearchResult(resultID) then
		self:QueueSameTitleRevealRetry(resultID, leaderName, displayTitle)
	else
		self:TipUnreadableTitleFallback()
	end
	return added
end

function BL:BlockAdvertisementFromSearchResult(resultID, info)
	local resultInfo = info
	if resultInfo == nil and resultID ~= nil
		and C_LFGList and type(C_LFGList.GetSearchResultInfo) == "function"
	then
		resultInfo = getSearchResultInfo(resultID)
	end
	return self:AddAdvertisementLeader(resultInfo and resultInfo.leaderName)
end

function BL:BeginBlock(kind, payload)
	if self:IsEnabled() ~= true then
		return false
	end
	local request = type(payload) == "table" and payload or {}
	local info = request.info
	if info == nil and request.resultID ~= nil then
		info = getSearchResultInfo(request.resultID)
	end
	if kind == "title" and (type(info) ~= "table" or info.name == nil) then
		return false
	end
	local requestedLeader = request.leaderName or (info and info.leaderName)
	if kind == "leader" and normalizeLeader(requestedLeader) == nil then
		return false
	end
	if kind == "leader" then
		return self:AddLeader(requestedLeader)
	end
	return self:BlockSameTitleFromSearchResult(
		request.resultID,
		info,
		request.displayTitle)
end

function BL:Tip(msg)
	local db = GF.GetDB()
	if db.showBlacklistChatNotice == false or msg == nil then
		return
	end
	if type(GF.ShowStatusMessage) == "function" then
		GF.ShowStatusMessage(msg)
	elseif type(print) == "function" then
		print(msg)
	end
end

function BL:GetBlacklistNoteAdvertisement()
	return NOTE_ADVERTISEMENT
end

function BL:GetBlacklistNoteSameTitleAdvertisement()
	return NOTE_SAME_TITLE
end

function BL:GetBlacklistNoteManual()
	return NOTE_MANUAL
end

function BL:GetEntryReason(entry)
	local note = tostring(entry and entry.note or "")
	local source = tostring(entry and entry.source or "")
	local sourceLower = string.lower(source)
	if entry and entry.kind == "title" then
		return "title_parent"
	end
	if sourceLower:find("report_ad", 1, true) then
		return "ad"
	end
	if sourceLower:find("block_title", 1, true)
	then
		return "same_title_ad"
	end
	if source == SOURCE_MANUAL or source == SOURCE_BLOCK_LEADER then
		return "manual"
	end
	-- 无 source 或未知 source 的历史/导入数据按旧规则兼容推断。
	if note == NOTE_ADVERTISEMENT then
		return "ad"
	end
	if entry and entry.sourceTitle and entry.sourceTitle ~= ""
		or note:find("同标题", 1, true)
		or note:find("标题", 1, true)
		or note:find("传染", 1, true)
	then
		return "same_title_ad"
	end
	return "manual"
end

function BL:GetEntryReasonText(reason)
	local L = GF.L or {}
	if reason == "ad" then
		return L.BLOCKLIST_REASON_AD or "广告"
	end
	if reason == "title_parent" then
		return L.BLOCKLIST_REASON_TITLE_PARENT or "标题父项"
	end
	if reason == "same_title_ad" then
		return L.BLOCKLIST_REASON_TITLE or "标题传染"
	end
	return L.BLOCKLIST_REASON_MANUAL or "手动添加"
end

function BL:GetEntrySourceText(reason)
	local L = GF.L or {}
	if reason == "ad" then
		return L.BLOCKLIST_SOURCE_REPORT_AD or "右键举报广告"
	end
	if reason == "title_parent" then
		return L.BLOCKLIST_SOURCE_TITLE_PARENT or "同标题批处理父项"
	end
	if reason == "same_title_ad" then
		return L.BLOCKLIST_SOURCE_TITLE or "屏蔽同标题广告来源"
	end
	return L.BLOCKLIST_SOURCE_MANUAL or "加入黑名单"
end

local function compareBlacklistEntryByUpdated(left, right)
	local leftUpdated = tonumber(left and (left.updatedAt or left.addedAt)) or 0
	local rightUpdated = tonumber(right and (right.updatedAt or right.addedAt)) or 0
	if leftUpdated ~= rightUpdated then
		return leftUpdated > rightUpdated
	end
	return tostring(left and (left.displayName or left.name or left.key) or "") < tostring(right and (right.displayName or right.name or right.key) or "")
end

function BL:GetBlacklistEntries()
	local entries = {}
	for index, row in ipairs(GF.GetDB().blocklist or {}) do
		if row.kind == "title" and row.title then
			local key = row.key or ("title:" .. tostring(row.title))
			row.key = key
			local updatedAt = parseEntryTimestamp(row)
			if updatedAt <= 0 then
				updatedAt = getNow()
			end
			row.addedAt = tonumber(row.addedAt) or updatedAt
			row.updatedAt = tonumber(row.updatedAt) or updatedAt
			row.time = row.time or formatEntryTime(updatedAt)
			local children = getTitleChildren(GF.GetDB().blocklist, row)
			local leader = normalizeLeader(row.leader) or self:GetDisplayText(row, "parent")
			local entry = {
				key = key,
				name = leader,
				displayName = leader,
				note = self:FormatEntryNote(row, #children),
				source = row.source or "",
				addedAt = tonumber(row.addedAt) or updatedAt,
				updatedAt = tonumber(row.updatedAt) or updatedAt,
				_row = row,
			}
			entry.reason = self:GetEntryReason(row)
			entries[#entries + 1] = entry
		elseif row.kind == "leader" then
			local leader = normalizeLeader(row.leader)
			if leader and not isTitleParentLeader(GF.GetDB(), row.sourceTitle, leader) then
				local key = row.key or buildLeaderKey(leader) or ("leader:" .. tostring(index))
				local name, realm = splitLeaderRealm(leader)
				row.key = key
				local updatedAt = parseEntryTimestamp(row)
				if updatedAt <= 0 then
					updatedAt = getNow()
				end
				row.addedAt = tonumber(row.addedAt) or updatedAt
				row.updatedAt = tonumber(row.updatedAt) or updatedAt
				row.time = row.time or formatEntryTime(updatedAt)
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
	table.sort(entries, compareBlacklistEntryByUpdated)
	return entries
end

local function findRowByKey(db, key)
	if not key then
		return nil
	end
	for index, row in ipairs(db.blocklist or {}) do
		local rowKey = row.key or (row.kind == "leader" and buildLeaderKey(row.leader)) or ("row:" .. tostring(index))
		if rowKey == key then
			row.key = rowKey
			return row, index
		end
	end
	return nil
end

function BL:SetBlacklistNote(entryOrKey, note)
	local row = type(entryOrKey) == "table" and (entryOrKey._row or entryOrKey) or findRowByKey(GF.GetDB(), entryOrKey)
	if not row then
		return false
	end
	row.note = tostring(note or "")
	setRowUpdateFields(row, {})
	self:RefreshAfterBlock()
	return true
end

function BL:RemovePlayerFromBlacklist(entryOrKey)
	local db = GF.GetDB()
	local target = type(entryOrKey) == "table"
		and (entryOrKey._row or entryOrKey) or nil
	if target == nil then
		target = findRowByKey(db, entryOrKey)
	end
	if target == nil then
		return false
	end
	local titleToRemove = target.kind == "title" and target.title or nil
	local kept = {}
	local found = false
	for _, row in ipairs(db.blocklist or {}) do
		local remove = row == target
			or (titleToRemove ~= nil and row.sourceTitle == titleToRemove)
		if remove then
			found = found or row == target
			if self._selected then
				self._selected[row] = nil
			end
		else
			kept[#kept + 1] = row
		end
	end
	if not found then
		return false
	end
	db.blocklist = kept
	self:RebuildMaps()
	self:RefreshAfterBlock()
	return true, target
end

function BL:RemoveSelected()
	local db = GF.GetDB()
	local list = db.blocklist or {}
	local selectedTitles = {}
	for _, row in ipairs(list) do
		if self:IsEntrySelected(row)
			and row.kind == "title"
			and row.title ~= nil
		then
			selectedTitles[row.title] = true
		end
	end
	local kept = {}
	local removedCount = 0
	for _, row in ipairs(list) do
		local remove = self:IsEntrySelected(row)
			or (row.sourceTitle ~= nil and selectedTitles[row.sourceTitle] == true)
		if remove then
			removedCount = removedCount + 1
			if self._selected then
				self._selected[row] = nil
			end
		else
			kept[#kept + 1] = row
		end
	end
	if removedCount > 0 then
		db.blocklist = kept
		self:RebuildMaps()
		local tab = GF.FindGroupTab
		if tab and type(tab.RemoveHiddenByBlocklist) == "function" then
			tab:RemoveHiddenByBlocklist()
		end
		local panel = GF.BlocklistPanel
		if panel and type(panel.Refresh) == "function" then
			panel:Refresh()
		end
	end
	return removedCount > 0
end

function BL:ToggleSelectAll(selectAll)
	local selected = selectAll == true
	for _, row in ipairs(self:GetList()) do
		self:SetEntrySelected(row, selected)
	end
	local panel = GF.BlocklistPanel
	if panel and type(panel.Refresh) == "function" then
		panel:Refresh()
	end
end

function BL:GetList()
	local db = GF.GetDB()
	return type(db.blocklist) == "table" and db.blocklist or {}
end
