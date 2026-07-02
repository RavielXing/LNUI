local _, GF = ...

GF.Blocklist = {}

local BL = GF.Blocklist
local PREVIEW_MAX_CHARS = 50
local NOTE_ADVERTISEMENT = "广告"
local NOTE_SAME_TITLE = "同标题广告传染"
local NOTE_MANUAL = "手动拉黑"
local SOURCE_BLOCK_LEADER = "findgroup_block_leader"
local SOURCE_BLOCK_TITLE = "findgroup_block_title"
local SOURCE_REPORT_AD = "findgroup_report_ad"
local TITLE_REVEAL_RETRY_DELAYS = { 0.25, 0.75, 1.5 }

local function truncatePreview(text)
	if not text or text == "" then
		return ""
	end
	if utf8 and utf8.len and utf8.offset then
		if utf8.len(text) <= PREVIEW_MAX_CHARS then
			return text
		end
		local pos = utf8.offset(text, PREVIEW_MAX_CHARS + 1)
		if pos then
			return text:sub(1, pos - 1) .. "..."
		end
	end
	if #text > PREVIEW_MAX_CHARS * 3 then
		return text:sub(1, PREVIEW_MAX_CHARS * 3) .. "..."
	end
	return text
end

local function trim(s)
	if not s then
		return ""
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizeLeader(name)
	if not name or name == "" then
		return nil
	end
	if Ambiguate then
		return Ambiguate(name, "none")
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

local function setRowUpdateFields(row, extra)
	if not row then
		return
	end
	extra = extra or {}
	local now = getNow()
	row.addedAt = tonumber(row.addedAt) or now
	row.updatedAt = now
	row.time = formatEntryTime(now)
	if extra.source and extra.source ~= "" then
		row.source = extra.source
	end
	if extra.key and extra.key ~= "" then
		row.key = extra.key
	elseif row.kind == "leader" then
		row.key = row.key or buildLeaderKey(row.leader)
	end
	if extra.sourceTitle and extra.sourceTitle ~= "" then
		row.sourceTitle = extra.sourceTitle
	end
	local label = extra.displayLabel and trim(extra.displayLabel) or ""
	if label ~= "" then
		row.displayLabel = label
	end
	local note = trim(extra.note)
	if note ~= "" then
		row.note = note
	elseif extra.forceNote then
		row.note = getDefaultNoteForSource(extra.source)
	end
end

local SECRET_TOKEN_PATTERN = "^|K.-|k$"

-- Title tokens still renderable this login session (cleared on PLAYER_LOGIN / 小退再进).
local readableTitleTokens = {}

local function isSecretToken(text)
	return text and text ~= "" and text:match(SECRET_TOKEN_PATTERN) ~= nil
end

local function markReadableTitleToken(title)
	if isSecretToken(title) then
		readableTitleTokens[title] = true
	end
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
	blizzardText = blizzardText or ""
	if blizzardText == "" then
		return (displayLabel and displayLabel ~= "") and displayLabel or "?"
	end
	if not isSecretToken(blizzardText) then
		return blizzardText
	end
	if readableTitleTokens[blizzardText] then
		return blizzardText
	end
	if displayLabel and displayLabel ~= "" then
		return displayLabel
	end
	return blizzardText
end

function BL:ClearReadableTitleTokens()
	readableTitleTokens = {}
end

local function findLeaderRow(db, leader, sourceTitle)
	leader = normalizeLeader(leader)
	if not leader then
		return false
	end
	for _, row in ipairs(db.blocklist or {}) do
		if row.kind == "leader" and normalizeLeader(row.leader) == leader then
			if sourceTitle == nil or row.sourceTitle == sourceTitle then
				return true, row
			end
		end
	end
	return false
end

local function leaderRowInList(db, leader)
	return findLeaderRow(db, leader, nil)
end

local function leaderContagionRowInList(db, leader, sourceTitle)
	if not sourceTitle or sourceTitle == "" then
		return false
	end
	return findLeaderRow(db, leader, sourceTitle)
end

local function findTitleRow(db, title)
	if not title or title == "" then
		return false
	end
	for _, row in ipairs(db.blocklist or {}) do
		if row.kind == "title" and row.title == title then
			return true, row
		end
	end
	return false
end

local function titleInList(db, title)
	return findTitleRow(db, title)
end

local function isTitleParentLeader(db, title, leader)
	leader = normalizeLeader(leader)
	if not title or title == "" or not leader then
		return false
	end
	local exists, row = findTitleRow(db, title)
	return exists and row and normalizeLeader(row.leader) == leader
end

local function pruneRedundantTitleChildren(db, selected)
	local removed = false
	for index = #(db.blocklist or {}), 1, -1 do
		local row = db.blocklist[index]
		if row and row.kind == "leader" and row.sourceTitle
			and isTitleParentLeader(db, row.sourceTitle, row.leader) then
			if selected then
				selected[row] = nil
			end
			table.remove(db.blocklist, index)
			removed = true
		end
	end
	return removed
end

local function isContagionEnabled(db)
	return db.titleContagionEnabled ~= false
end

function BL:Init()
	self.leaders = {}
	self._selected = {}
	self:ClearTipState()
	self:RebuildMaps()
end

function BL:ClearTipState()
	self._scanBatchActive = false
	self._scanPanelDirty = false
	self._pendingLeaderTips = nil
	self._pendingLeaderTipSeen = nil
	self._pendingContagionTips = nil
	self._pendingContagionSeen = nil
	self._manualTip = nil
end

function BL:IsEnabled()
	return GF.GetDB().moduleBlocklist ~= false
end

function BL:RebuildMaps()
	self.leaders = {}
	if not self:IsEnabled() then
		self.revision = (self.revision or 0) + 1
		return
	end
	local db = GF.GetDB()
	pruneRedundantTitleChildren(db, self._selected)
	for _, entry in ipairs(db.blocklist or {}) do
		local leader = normalizeLeader(entry.leader)
		if leader and (entry.kind == "leader" or entry.kind == "title") then
			self.leaders[leader] = true
		end
	end
	self.revision = (self.revision or 0) + 1
end

function BL:GetRevision()
	return self.revision or 0
end

function BL:FindTitleEntry(titleToken)
	local _, row = findTitleRow(GF.GetDB(), titleToken)
	return row
end

function BL:GetDisplayText(entry, itemRole)
	if not entry then
		return "?"
	end
	if entry.kind == "title" or itemRole == "parent" then
		return resolveDisplayText(entry.title, entry.displayLabel)
	end
	return resolveDisplayText(entry.leader, entry.displayLabel)
end

function BL:FormatTitleTag(entry)
	local L = GF.L or {}
	local tag = L.BLOCKLIST_TAG_TITLE or "[Title]"
	if entry and entry.displayLabel and entry.displayLabel ~= "" and entry.title then
		if self:GetDisplayText(entry) == entry.displayLabel then
			tag = tag .. (L.BLOCKLIST_TAG_CUSTOM or "[Custom]")
		end
	end
	return tag
end

function BL:FormatTargetText(entry, itemRole)
	local L = GF.L or {}
	if not entry then
		return "?"
	end
	local tag
	if itemRole == "parent" or entry.kind == "title" then
		tag = self:FormatTitleTag(entry)
	else
		tag = L.BLOCKLIST_TAG_LEADER or "[Leader]"
	end
	return tag .. " " .. self:GetDisplayText(entry, itemRole)
end

function BL:BuildBlockPreview(info)
	if not info then
		return "", ""
	end
	local title = truncatePreview(info.name or "")
	local summary = truncatePreview(info.comment or "")
	return title, summary
end

local function tipLabelText(text)
	if not text or text == "" then
		return ""
	end
	return text
end

function BL:BeginScanTipBatch()
	if self._scanBatchActive then
		self:EndScanTipBatch()
	end
	self._scanBatchActive = true
end

function BL:FlushLeaderTips()
	local leaders = self._pendingLeaderTips
	self._pendingLeaderTips = nil
	self._pendingLeaderTipSeen = nil
	if not leaders or #leaders == 0 then
		return
	end
	local L = GF.L or {}
	local prefix = L.BLOCK_TIP_LEADER_PREFIX or "Blocked leader: "
	self:Tip(tipLabelText(prefix) .. table.concat(leaders, "、"))
end

function BL:FlushContagionTips()
	local tips = self._pendingContagionTips
	self._pendingContagionTips = nil
	self._pendingContagionSeen = nil
	if not tips or #tips == 0 then
		return
	end
	local L = GF.L or {}
	local titlePrefix = L.BLOCK_TIP_CONTAGION_TITLE_PREFIX or "Title "
	local mid = L.BLOCK_TIP_CONTAGION_MID or " contagion block "
	for _, tip in ipairs(tips) do
		local titleShown = resolveDisplayText(tip.sourceTitle, nil)
		self:Tip(tipLabelText(titlePrefix) .. titleShown .. tipLabelText(mid) .. tip.leader)
	end
end

function BL:EndScanTipBatch()
	if not self._scanBatchActive then
		return
	end
	self._scanBatchActive = false
	self:FlushContagionTips()
	self:FlushLeaderTips()
	if self._scanPanelDirty and GF.BlocklistPanel and GF.BlocklistPanel.Refresh then
		self._scanPanelDirty = false
		GF.BlocklistPanel:Refresh()
	end
end

local function queueLeaderTip(bl, leader)
	leader = normalizeLeader(leader)
	if not leader then
		return
	end
	bl._pendingLeaderTipSeen = bl._pendingLeaderTipSeen or {}
	if bl._pendingLeaderTipSeen[leader] then
		return
	end
	bl._pendingLeaderTipSeen[leader] = true
	bl._pendingLeaderTips = bl._pendingLeaderTips or {}
	bl._pendingLeaderTips[#bl._pendingLeaderTips + 1] = leader
end

local function queueContagionLeaderTip(bl, leader, sourceTitle)
	leader = normalizeLeader(leader)
	if not leader or not sourceTitle or sourceTitle == "" then
		return
	end
	bl._pendingContagionSeen = bl._pendingContagionSeen or {}
	local key = sourceTitle .. "\0" .. leader
	if bl._pendingContagionSeen[key] then
		return
	end
	bl._pendingContagionSeen[key] = true
	bl._pendingContagionTips = bl._pendingContagionTips or {}
	bl._pendingContagionTips[#bl._pendingContagionTips + 1] = {
		leader = leader,
		sourceTitle = sourceTitle,
	}
end

local function queueManualTitle(bl, title, leader, displayLabel)
	bl._manualTip = bl._manualTip or { kind = "title", leaders = {}, leaderSeen = {} }
	bl._manualTip.kind = "title"
	bl._manualTip.title = title
	bl._manualTip.displayLabel = isStableTitleLabelText(displayLabel) or bl._manualTip.displayLabel
	leader = normalizeLeader(leader)
	if leader and not bl._manualTip.leaderSeen[leader] then
		bl._manualTip.leaderSeen[leader] = true
		bl._manualTip.leaders[#bl._manualTip.leaders + 1] = leader
	end
end

function BL:BeginManualTip(kind)
	self._manualTip = {
		kind = kind,
		leaders = {},
		leaderSeen = {},
	}
end

function BL:FlushManualTip()
	local batch = self._manualTip
	self._manualTip = nil
	if not batch then
		return
	end
	local L = GF.L or {}
	if batch.kind == "title" and batch.title then
		local titleShown = isStableTitleLabelText(batch.displayLabel)
			or isStableTitleLabelText(resolveDisplayText(batch.title, nil))
			or L.BLOCK_NOTE_TITLE_UNREADABLE
			or "标题暂不可读"
		local titlePrefix = L.BLOCK_TIP_TITLE_PREFIX or "Blocked title: "
		if batch.leaders[1] then
			local leadersPrefix = L.BLOCK_TIP_LEADERS_PREFIX or "; leaders: "
			self:Tip(tipLabelText(titlePrefix) .. titleShown .. tipLabelText(leadersPrefix) .. table.concat(batch.leaders, "、"))
		else
			self:Tip(tipLabelText(titlePrefix) .. titleShown)
		end
	end
end

local function isSystemNote(kind, note)
	note = trim(note)
	if note == "" then
		return true
	end
	local L = GF.L or {}
	if kind == "title" then
		return note == (L.BLOCK_NOTE_TITLE or "Blocked title")
	end
	if kind == "leader" then
		return note == (L.BLOCK_NOTE_LEADER or "Blocked leader")
	end
	return false
end

local function addEntry(bl, kind, leader, title, note, extra)
	local db = GF.GetDB()
	db.blocklist = db.blocklist or {}
	leader = normalizeLeader(leader)
	extra = extra or {}

	if kind == "leader" then
		if not leader then
			return nil
		end
		local exists, existing = leaderRowInList(db, leader)
		if exists and existing then
			setRowUpdateFields(existing, {
				source = extra.source,
				sourceTitle = extra.sourceTitle,
				displayLabel = extra.displayLabel,
				note = note,
				forceNote = extra.forceNote,
			})
			return existing, true
		end
	elseif kind == "title" then
		if not title or title == "" then
			return nil
		end
		local exists, existing = titleInList(db, title)
		if exists and existing then
			setRowUpdateFields(existing, {
				displayLabel = extra.displayLabel,
				note = note,
			})
			return existing, true
		end
	else
		return nil
	end

	local now = getNow()
	local row = {
		leader = leader or title,
		time = formatEntryTime(now),
		kind = kind,
		addedAt = now,
		updatedAt = now,
	}
	if kind == "leader" then
		row.key = buildLeaderKey(leader)
	end
	if title and title ~= "" then
		row.title = title
	end
	note = trim(note)
	if note ~= "" and not isSystemNote(kind, note) then
		row.note = note
	end
	if extra.source and extra.source ~= "" then
		row.source = extra.source
	end
	if extra.forceNote and (not row.note or row.note == "") then
		row.note = getDefaultNoteForSource(extra.source)
	end
	if extra.sourceTitle and extra.sourceTitle ~= "" then
		row.sourceTitle = extra.sourceTitle
	end
	local label = extra.displayLabel and trim(extra.displayLabel) or ""
	if label ~= "" then
		row.displayLabel = label
	end
	table.insert(db.blocklist, 1, row)

	if kind == "leader" then
		if extra and extra.sourceTitle and extra.sourceTitle ~= "" then
			if not extra.skipTip then
				queueContagionLeaderTip(bl, leader, extra.sourceTitle)
				if not bl._scanBatchActive then
					bl:FlushContagionTips()
				end
			end
		else
			queueLeaderTip(bl, leader)
			if not bl._scanBatchActive then
				bl:FlushLeaderTips()
			end
		end
	elseif kind == "title" then
		if bl._manualTip then
			queueManualTitle(bl, title, leader, extra.displayLabel)
		end
	end

	return row
end

function BL:FindMatch(resultID, info)
	if not self:IsEnabled() or not resultID then
		return nil
	end
	if not next(self.leaders) then
		return nil
	end
	if not info then
		info = getSearchResultInfo(resultID)
	end
	if not info then
		return nil
	end
	local leader = normalizeLeader(info.leaderName)
	if leader and self.leaders[leader] then
		local _, row = findLeaderRow(GF.GetDB(), leader, nil)
		return "leader", row
	end
	return nil
end

function BL:FindPlayerMatch(playerName)
	if not self:IsEnabled() then
		return nil
	end
	local leader = normalizeLeader(playerName)
	if not leader or not self.leaders or not self.leaders[leader] then
		return nil
	end
	local _, row = findLeaderRow(GF.GetDB(), leader, nil)
	return row or true
end

function BL:ShouldHide(resultID, info)
	local matchKind = self:FindMatch(resultID, info)
	if not matchKind then
		return false
	end
	return true
end

local function getTitleChildren(list, titleEntry)
	local titleKey = titleEntry and titleEntry.title
	local children = {}
	local seen = {}
	if not titleKey or titleKey == "" then
		return children
	end
	local parentLeader = normalizeLeader(titleEntry.leader)
	if parentLeader then
		seen[parentLeader] = true
	end
	for _, entry in ipairs(list or {}) do
		if entry.kind == "leader" and entry.sourceTitle == titleKey then
			local leader = normalizeLeader(entry.leader)
			if leader and not seen[leader] then
				seen[leader] = true
				children[#children + 1] = entry
			end
		end
	end
	return children
end

function BL:FormatEntryNote(entry, childCount)
	local L = GF.L or {}
	if not entry then
		return ""
	end
	local leaderShown = normalizeLeader(entry.leader) or entry.leader or "?"
	if entry.kind == "title" then
		local fmt = L.BLOCK_NOTE_TITLE_PARENT_FMT or "同标题广告屏蔽：%s"
		return string.format(fmt, leaderShown)
	end
	if entry.sourceTitle and entry.sourceTitle ~= "" then
		local _, parent = findTitleRow(GF.GetDB(), entry.sourceTitle)
		local parentLeader = normalizeLeader(parent and parent.leader) or parent and parent.leader or "?"
		local fmt = L.BLOCK_NOTE_TITLE_CHILD_FMT or "来自 [%s] 的同标题广告传染"
		return string.format(fmt, parentLeader)
	end
	return entry.note or L.BLOCK_NOTE_LEADER or "Blocked leader"
end

function BL:BuildDisplayList(expanded)
	local list = self:GetList()
	expanded = expanded or {}
	local display = {}
	local seenTitles = {}

	for _, entry in ipairs(list) do
		if entry.kind == "title" and entry.title then
			if not seenTitles[entry.title] then
				seenTitles[entry.title] = true
				local children = getTitleChildren(list, entry)
				table.insert(display, {
					role = "parent",
					entry = entry,
					titleKey = entry.title,
					children = children,
					childCount = #children,
				})
				if expanded[entry.title] then
					for _, child in ipairs(children) do
						table.insert(display, {
							role = "child",
							entry = child,
							titleKey = entry.title,
						})
					end
				end
			end
		elseif entry.kind == "leader" and (not entry.sourceTitle or entry.sourceTitle == "") then
			table.insert(display, {
				role = "standalone",
				entry = entry,
			})
		end
	end
	return display
end

function BL:IsEntrySelected(entry)
	return entry and self._selected and self._selected[entry] == true
end

function BL:SetEntrySelected(entry, selected)
	if not entry then
		return
	end
	self._selected = self._selected or {}
	if selected then
		self._selected[entry] = true
	else
		self._selected[entry] = nil
	end
end

function BL:SetGroupSelected(titleEntry, children, selected)
	if not titleEntry then
		return
	end
	self:SetEntrySelected(titleEntry, selected)
	for _, child in ipairs(children or {}) do
		self:SetEntrySelected(child, selected)
	end
end

function BL:OnChildSelected(titleEntry, checked)
	if not titleEntry or checked then
		return
	end
	self:SetEntrySelected(titleEntry, false)
end

function BL:SetDisplayLabel(entry, label)
	if not entry then
		return
	end
	label = trim(label)
	if label == "" then
		entry.displayLabel = nil
	else
		entry.displayLabel = label
	end
	if GF.BlocklistPanel and GF.BlocklistPanel.Refresh then
		GF.BlocklistPanel:Refresh()
	end
end

function BL:ApplyTitleContagion(leader, title, opts)
	opts = opts or {}
	local db = GF.GetDB()
	if not isContagionEnabled(db) or not title or title == "" then
		return
	end
	leader = normalizeLeader(leader)
	if not leader then
		return
	end
	self.leaders[leader] = true
	if isTitleParentLeader(db, title, leader) then
		return
	end
	local exists, row = leaderContagionRowInList(db, leader, title)
	if not exists then
		exists, row = leaderRowInList(db, leader)
	end
	if exists and row then
		if opts.source or opts.note or opts.forceNote then
			setRowUpdateFields(row, {
				source = opts.source,
				sourceTitle = title,
				note = opts.note,
				forceNote = opts.forceNote,
			})
		end
		return
	end
	addEntry(self, "leader", leader, nil, opts.note, {
		sourceTitle = title,
		source = opts.source or SOURCE_BLOCK_TITLE,
		forceNote = opts.forceNote,
		skipTip = opts.skipTip,
	})
	if self._scanBatchActive then
		self._scanPanelDirty = true
	elseif GF.BlocklistPanel and GF.BlocklistPanel.Refresh then
		GF.BlocklistPanel:Refresh()
	end
end

function BL:PersistVisibleTitleContagion(titleToken, displayLabel)
	if not titleToken or titleToken == "" or not self:IsEnabled() then
		return 0
	end
	local db = GF.GetDB()
	if not isContagionEnabled(db) then
		return 0
	end
	local order = GF.Result and (GF.Result.frozenOrder or GF.Result.resultIDs) or {}
	if #order == 0 then
		return 0
	end
	local seen = {}
	local added = 0
	local targetLabel = isStableTitleLabelText(displayLabel)
	for _, resultID in ipairs(order) do
		local info = getSearchResultInfo(resultID)
		local title = resolveReliableTitle(resultID, info)
		local sameTitle = title == titleToken
		if not sameTitle and targetLabel then
			local rowLabel = resolveStableDisplayTitle(resultID, info, nil, info)
			sameTitle = rowLabel == targetLabel
		end
		if info and sameTitle then
			local leader = normalizeLeader(info.leaderName)
			if leader and not seen[leader] then
				seen[leader] = true
				self:ApplyTitleContagion(leader, titleToken)
				added = added + 1
			end
		end
	end
	return added
end

function BL:RefreshAfterBlock()
	self.revision = (self.revision or 0) + 1
	if GF.Result and GF.Result.InvalidateAllBlockedMemberCache then
		GF.Result:InvalidateAllBlockedMemberCache()
	end
	if GF.FindGroupTab and GF.FindGroupTab.RemoveHiddenByBlocklist then
		GF.FindGroupTab:RemoveHiddenByBlocklist()
	end
	if GF.FindGroupTab and GF.FindGroupTab.RefreshList then
		GF.FindGroupTab:RefreshList({ preserveScroll = true })
	end
	if GF.BlocklistPanel and GF.BlocklistPanel.Refresh then
		GF.BlocklistPanel:Refresh()
	end
end

function BL:AddLeader(leaderName, note, displayLabel)
	return self:AddLeaderWithSource(leaderName, note, displayLabel, SOURCE_BLOCK_LEADER, true)
end

function BL:AddLeaderWithSource(leaderName, note, displayLabel, source, forceNote)
	if not self:IsEnabled() then
		return false
	end
	local leader = normalizeLeader(leaderName)
	if not leader then
		return false
	end
	local row = addEntry(self, "leader", leader, nil, note, {
		displayLabel = displayLabel,
		source = source or SOURCE_BLOCK_LEADER,
		forceNote = forceNote == true,
	})
	if not row then
		return false
	end
	self.leaders[leader] = true
	self:RefreshAfterBlock()
	return true
end

function BL:AddTitle(title, leaderName, note, displayLabel)
	if not self:IsEnabled() then
		return false
	end
	if not title or title == "" then
		return false
	end
	local leader = normalizeLeader(leaderName)
	self:BeginManualTip("title")
	local row = addEntry(self, "title", leader or title, title, note, {
		displayLabel = displayLabel,
		source = SOURCE_BLOCK_TITLE,
	})
	if not row then
		self._manualTip = nil
		return false
	end
	markReadableTitleToken(title)
	if leader then
		self.leaders[leader] = true
	end
	if leader and isContagionEnabled(GF.GetDB()) then
		self:ApplyTitleContagion(leader, title, {
			skipTip = true,
			source = SOURCE_BLOCK_TITLE,
			note = note or NOTE_SAME_TITLE,
			forceNote = true,
		})
	end
	self:BeginScanTipBatch()
	self:PersistVisibleTitleContagion(title, displayLabel)
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
	if not info and resultID and C_LFGList and C_LFGList.GetSearchResultInfo then
		info = getSearchResultInfo(resultID)
	end
	return self:AddAdvertisementLeader(info and info.leaderName)
end

function BL:BeginBlock(kind, payload)
	if not self:IsEnabled() then
		return false
	end
	payload = payload or {}
	local info = payload.info
	if not info and payload.resultID then
		info = getSearchResultInfo(payload.resultID)
	end
	if kind == "title" and (not info or not info.name) then
		return false
	end
	if kind == "leader" and not normalizeLeader(payload.leaderName or (info and info.leaderName)) then
		return false
	end

	if kind == "leader" then
		return self:AddLeader(payload.leaderName or info.leaderName)
	end
	return self:BlockSameTitleFromSearchResult(payload.resultID, info, payload.displayTitle)
end

function BL:Tip(msg)
	local db = GF.GetDB()
	if db.blockTipsEnabled ~= false and msg then
		if GF.ShowStatusMessage then
			GF.ShowStatusMessage(msg)
		else
			print(msg)
		end
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
	if sourceLower:find("report_ad", 1, true) or note == NOTE_ADVERTISEMENT then
		return "ad"
	end
	if sourceLower:find("block_title", 1, true)
		or entry and entry.sourceTitle and entry.sourceTitle ~= ""
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
	local target = type(entryOrKey) == "table" and (entryOrKey._row or entryOrKey) or nil
	local targetIndex
	if not target then
		target, targetIndex = findRowByKey(db, entryOrKey)
	else
		for index, row in ipairs(db.blocklist or {}) do
			if row == target then
				targetIndex = index
				break
			end
		end
	end
	if not target or not targetIndex then
		return false
	end
	local cascadeTitle = target.kind == "title" and target.title or nil
	table.remove(db.blocklist, targetIndex)
	if cascadeTitle then
		for i = #db.blocklist, 1, -1 do
			local row = db.blocklist[i]
			if row.sourceTitle == cascadeTitle then
				table.remove(db.blocklist, i)
			end
		end
	end
	self._selected[target] = nil
	self:RebuildMaps()
	self:RefreshAfterBlock()
	return true, target
end

function BL:RemoveSelected()
	local db = GF.GetDB()
	local cascadeTitles = {}
	for _, row in ipairs(db.blocklist or {}) do
		if self:IsEntrySelected(row) and row.kind == "title" and row.title then
			cascadeTitles[row.title] = true
		end
	end
	local removed = false
	for i = #db.blocklist, 1, -1 do
		local row = db.blocklist[i]
		if self:IsEntrySelected(row) or (row.sourceTitle and cascadeTitles[row.sourceTitle]) then
			self._selected[row] = nil
			table.remove(db.blocklist, i)
			removed = true
		end
	end
	if removed then
		self:RebuildMaps()
		if GF.FindGroupTab and GF.FindGroupTab.RemoveHiddenByBlocklist then
			GF.FindGroupTab:RemoveHiddenByBlocklist()
		end
		if GF.BlocklistPanel then
			GF.BlocklistPanel:Refresh()
		end
	end
	return removed
end

function BL:ToggleSelectAll(selectAll)
	for _, row in ipairs(GF.GetDB().blocklist or {}) do
		self:SetEntrySelected(row, selectAll)
	end
	if GF.BlocklistPanel then
		GF.BlocklistPanel:Refresh()
	end
end

function BL:GetList()
	return GF.GetDB().blocklist or {}
end
