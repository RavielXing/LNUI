local _, GF = ...

-- BlacklistMatcher owns value normalization and comparisons.  It deliberately
-- has no database access and never mutates a persisted row.
local Matcher = {}
GF.BlacklistMatcher = Matcher

Matcher.Notes = {
	ADVERTISEMENT = "广告",
	SAME_TITLE = "同标题广告传染",
	MANUAL = "手动拉黑",
}

Matcher.Sources = {
	BLOCK_LEADER = "findgroup_block_leader",
	BLOCK_TITLE = "findgroup_block_title",
	REPORT_AD = "findgroup_report_ad",
	MANUAL = "manual_context_menu",
}

local SECRET_TOKEN_PATTERN = "^|K.-|k$"

local function isProtectedValue(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

function Matcher.IsUsableText(value)
	if type(value) ~= "string" or isProtectedValue(value) then
		return false
	end
	local ok, nonEmpty = pcall(function()
		return value ~= ""
	end)
	return ok and nonEmpty == true
end

function Matcher.Trim(value)
	if type(value) ~= "string" or isProtectedValue(value) then
		return ""
	end
	local ok, result = pcall(string.match, value, "^%s*(.-)%s*$")
	return ok and result or ""
end

function Matcher.IsSecretToken(value)
	if not Matcher.IsUsableText(value) then
		return false
	end
	local ok, matched = pcall(string.match, value, SECRET_TOKEN_PATTERN)
	return ok and matched ~= nil
end

function Matcher.SafeTextEquals(left, right)
	if type(left) ~= "string" or type(right) ~= "string"
		or isProtectedValue(left) or isProtectedValue(right)
	then
		return false
	end
	local ok, equal = pcall(function()
		return left == right
	end)
	return ok and equal == true
end

function Matcher.NormalizeLeader(name)
	local text = Matcher.Trim(name)
	if text == "" then
		return nil
	end
	-- Ambiguate is a display helper; persisted identities must retain their realm.
	local character, realm = text:match("^([^-]+)%-(.+)$")
	if character then
		character, realm = Matcher.Trim(character), Matcher.Trim(realm)
		if character == "" or realm == "" then return nil end
		return character .. "-" .. realm
	end
	-- Keep opaque legacy title fallbacks out of player-name completion.
	if Matcher.IsSecretToken(text) then return text end
	if text:find("-", 1, true) then return nil end
	realm = Matcher.CurrentRealmName()
	return realm and (text .. "-" .. realm) or text
end

function Matcher.CurrentRealmName()
	local function readRealm(provider)
		if type(provider) == "function" then
			local ok, realm = pcall(provider)
			if ok and Matcher.IsUsableText(realm) then
				realm = Matcher.Trim(realm):gsub("%s+", "")
				if realm ~= "" then return realm end
			end
		end
		return nil
	end
	return readRealm(GetNormalizedRealmName) or readRealm(GetRealmName)
end

function Matcher.SplitLeaderRealm(leader)
	local normalized = Matcher.NormalizeLeader(leader)
	if normalized == nil then
		return nil, nil
	end
	local ok, name, realm = pcall(string.match, normalized, "^([^-]+)%-(.+)$")
	if ok and name and name ~= "" and realm and realm ~= "" then
		return name, realm
	end
	return normalized, Matcher.CurrentRealmName()
end

function Matcher.NormalizeIdentifierPart(value)
	local text = Matcher.Trim(value)
	if text == "" then
		return nil
	end
	local ok, normalized = pcall(function()
		return string.lower((string.gsub(text, "%s+", "")))
	end)
	return ok and normalized or nil
end

function Matcher.BuildLeaderKey(leader)
	local normalized = Matcher.NormalizeIdentifierPart(leader)
	return normalized and ("leader:" .. normalized) or nil
end

function Matcher.DefaultNoteForSource(source)
	local value = tostring(source or "")
	if value:find("report_ad", 1, true) then
		return Matcher.Notes.ADVERTISEMENT
	end
	if value:find("block_title", 1, true) then
		return Matcher.Notes.SAME_TITLE
	end
	return Matcher.Notes.MANUAL
end

function Matcher.SourceCreatesStandaloneLeader(source)
	local sources = Matcher.Sources
	return source == sources.MANUAL
		or source == sources.BLOCK_LEADER
		or source == sources.REPORT_AD
end

function Matcher.IsSystemNote(kind, note, locale)
	local normalized = Matcher.Trim(note)
	if normalized == "" then
		return true
	end
	local translations = type(locale) == "table" and locale or {}
	local defaults = {
		title = translations.BLOCK_NOTE_TITLE or "Blocked title",
		leader = translations.BLOCK_NOTE_LEADER or "Blocked leader",
	}
	return defaults[kind] ~= nil and normalized == defaults[kind]
end

function Matcher.ReliableTitle(title, isUnreadable)
	if title == nil or type(title) ~= "string" or isProtectedValue(title) then
		return nil
	end
	local normalized = Matcher.Trim(title)
	if normalized == "" or normalized == "?" then
		return nil
	end
	if type(isUnreadable) == "function" then
		local ok, unreadable = pcall(isUnreadable, normalized)
		if not ok or unreadable == true then
			return nil
		end
	end
	return normalized
end

function Matcher.StableTitleLabel(title, isUnreadable)
	local label = Matcher.ReliableTitle(title, isUnreadable)
	if label == nil or Matcher.IsSecretToken(label) then
		return nil
	end
	return label
end

function Matcher.FindLeader(rows, leader, sourceTitle)
	local target = Matcher.NormalizeLeader(leader)
	if target == nil then
		return nil
	end
	for _, row in ipairs(type(rows) == "table" and rows or {}) do
		if type(row) == "table" and row.kind == "leader"
			and Matcher.SafeTextEquals(Matcher.NormalizeLeader(row.leader), target)
			and (sourceTitle == nil
				or Matcher.SafeTextEquals(row.sourceTitle, sourceTitle))
		then
			return row
		end
	end
	return nil
end

function Matcher.FindTitle(rows, title)
	if not Matcher.IsUsableText(title) then
		return nil
	end
	for _, row in ipairs(type(rows) == "table" and rows or {}) do
		if type(row) == "table" and row.kind == "title"
			and Matcher.SafeTextEquals(row.title, title)
		then
			return row
		end
	end
	return nil
end

function Matcher.IsTitleParentLeader(rows, title, leader)
	local normalized = Matcher.NormalizeLeader(leader)
	if normalized == nil then
		return false
	end
	local parent = Matcher.FindTitle(rows, title)
	return parent ~= nil
		and Matcher.SafeTextEquals(
			Matcher.NormalizeLeader(parent.leader), normalized)
end

function Matcher.ClassifyReason(entry)
	if type(entry) ~= "table" then
		return "manual"
	end
	if entry.kind == "title" then
		return "title_parent"
	end
	local source = tostring(entry.source or "")
	local sourceLower = string.lower(source)
	if sourceLower:find("report_ad", 1, true) then
		return "ad"
	end
	if sourceLower:find("block_title", 1, true) then
		return "same_title_ad"
	end
	local sources = Matcher.Sources
	if source == sources.MANUAL or source == sources.BLOCK_LEADER then
		return "manual"
	end
	local note = tostring(entry.note or "")
	if note == Matcher.Notes.ADVERTISEMENT then
		return "ad"
	end
	if type(entry.sourceTitle) == "string" and entry.sourceTitle ~= ""
		or note:find("同标题", 1, true)
		or note:find("标题", 1, true)
		or note:find("传染", 1, true)
	then
		return "same_title_ad"
	end
	return "manual"
end

local TitleEvidence = {}
TitleEvidence.__index = TitleEvidence

function TitleEvidence:Remember(title)
	if Matcher.IsSecretToken(title) then
		self.tokens[title] = true
	end
end

function TitleEvidence:CanRender(text)
	return not Matcher.IsSecretToken(text) or self.tokens[text] == true
end

function TitleEvidence:Reset()
	for token in pairs(self.tokens) do
		self.tokens[token] = nil
	end
end

function Matcher.NewTitleEvidence()
	return setmetatable({ tokens = {} }, TitleEvidence)
end

function Matcher.ResolveDisplayText(nativeText, displayLabel, evidence)
	local native = Matcher.IsUsableText(nativeText) and nativeText or ""
	local fallback = Matcher.IsUsableText(displayLabel) and displayLabel or ""
	if native == "" then
		return fallback ~= "" and fallback or "?"
	end
	local renderable = evidence == nil
		or type(evidence.CanRender) ~= "function"
		or evidence:CanRender(native)
	if renderable or fallback == "" then
		return native
	end
	return fallback
end
