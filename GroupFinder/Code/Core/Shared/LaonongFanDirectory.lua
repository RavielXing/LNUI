local _, GF = ...

-- Read-only session index of the integration pack's public fan directory.
-- Fan membership is presentation metadata, never a friend/sort/filter signal.
GF.LaonongFanDirectory = {}
local Directory = GF.LaonongFanDirectory
local ADDON = "!!!163UI!!!"
local Compat = GF.Compat
local listeners = {}
local fullNames = {}
local characterNames = {}
local refreshMark = 1
local sourcePlayers
local ready = false
local revision = 0
local retryTicket = 0
local notifyPending = false

local function read(owner, key)
	return Compat.ReadAccessibleField(owner, key)
end

local function text(value)
	if not Compat.IsAccessibleValue(value) or type(value) ~= "string" then
		return nil
	end
	value = value:match("^%s*(.-)%s*$")
	if value == "" or value:find("|", 1, true) then return nil end
	return value
end

local function fullNameKey(name)
	name = text(name)
	local character, realm
	if name then character, realm = name:match("^([^%-]+)%-(.+)$") end
	character, realm = text(character), text(realm)
	if not character or not realm then return nil end
	realm = realm:gsub("%[.-%]", ""):gsub("（", "("):gsub("）", ")")
	realm = realm:gsub("%s+", ""):gsub("[%(%)]", "")
	if realm == "" then return nil end
	return string.lower(character .. "-" .. realm)
end

local function characterNameKey(name)
	name = text(name)
	if not name then return nil end
	if name:find("-", 1, true) then
		local key = fullNameKey(name)
		return key and key:match("^([^%-]+)%-")
	end
	return string.lower(name)
end

local function nativeFullName(name)
	name = text(name)
	if not name then return nil end
	if fullNameKey(name) then return name end
	if name:find("-", 1, true) then return nil end
	-- Leader/applicant names use native same-realm qualification. Ordinary
	-- search members may omit a remote realm and must never use this fallback.
	local normalize = GF.NormalizeExternalFullPlayerName
	if type(normalize) ~= "function" then return nil end
	local ok, fullName = pcall(normalize, name)
	if ok and fullNameKey(fullName) then return fullName end
	return nil
end

local function isLeaderMember(member, info)
	local isLeader = read(member, "isLeader")
	if type(isLeader) == "boolean" then return isLeader end
	-- An incomplete snapshot must not downgrade a known leader to nickname
	-- matching. An explicit nonleader flag still permits a same-named member.
	local name = text(read(member, "name"))
	local leader = text(read(info, "leaderName"))
	if not name or not leader then return false end
	local key = fullNameKey(name)
	if key then return key == fullNameKey(nativeFullName(leader)) end
	local character = characterNameKey(name)
	return character ~= nil and character == characterNameKey(leader)
end

local function publicPlayers()
	if not Compat.IsAddOnFullyLoaded(ADDON) then return nil end
	local players = read(_G.U1Donators, "players")
	if not Compat.IsAccessibleTable(players) then return nil end
	return players
end

local function notifyChanged()
	if notifyPending then return end
	notifyPending = true
	local function notify()
		notifyPending = false
		for _, callback in ipairs(listeners) do
			callback(revision)
		end
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, notify)
	else
		notify()
	end
end

function Directory:AddListener(callback)
	if type(callback) == "function" then listeners[#listeners + 1] = callback end
end

function Directory:Refresh()
	if not self.initialized then return false end
	local players = publicPlayers()
	-- Alternate non-nil marks in the existing index; no raw-source copy is
	-- needed to detect in-place edits or duplicate canonical names.
	refreshMark = 3 - refreshMark
	local count, changed = 0, false
	if players then
		for name in pairs(players) do
			local key = fullNameKey(name)
			if key and fullNames[key] ~= refreshMark then
				if fullNames[key] == nil then changed = true end
				fullNames[key] = refreshMark
				count = count + 1
			end
		end
	end
	for key, mark in pairs(fullNames) do
		if mark ~= refreshMark then fullNames[key] = nil; changed = true end
	end
	local nextReady = players ~= nil and count > 0
	changed = changed or ready ~= nextReady
	sourcePlayers = players
	if not changed then return false end
	-- A smaller directory must also release its old hash capacity. Growing or
	-- unchanged sets can keep the full-name table; nickname membership is derived.
	local nextNames = count < (self.count or 0) and {} or fullNames
	characterNames = {}
	for key in pairs(fullNames) do
		nextNames[key] = refreshMark
		characterNames[key:match("^([^%-]+)%-")] = true
	end
	fullNames = nextNames
	ready, self.count = nextReady, count
	revision = revision + 1
	notifyChanged()
	return true
end

function Directory:IsReady()
	-- Replacement of the public table is cheap to detect, without scanning it
	-- on every row. In-place edits refresh at search/listing/lifecycle edges.
	if self.initialized and publicPlayers() ~= sourcePlayers then self:Refresh() end
	return ready
end

function Directory:GetRevision()
	return revision
end

function Directory:GetStatus()
	return { ready = self:IsReady(), count = self.count or 0, revision = revision }
end

function Directory:IsFanName(name)
	if not self:IsReady() then return nil end
	local key = fullNameKey(name)
	-- Generic, leader and applicant lookups stay strict. Nickname matching is
	-- a presentation-only fallback for ordinary search-result members.
	if not key then return nil end
	return fullNames[key] ~= nil
end

function Directory:IsApplicantFan(member)
	local fixtures = GF.ApplicantTestData
	if fixtures and type(fixtures.GetLaonongFanState) == "function" then
		local state = fixtures:GetLaonongFanState(member)
		if type(state) == "boolean" then return state end
	end
	return self:IsFanName(nativeFullName(read(member, "name")))
end

function Directory:GetMemberName(member, info)
	local name = text(read(member, "name"))
	if fullNameKey(name) then return name end
	if not name then return nil end
	if isLeaderMember(member, info) then
		local leader = text(read(info, "leaderName"))
		local character = leader and leader:match("^([^%-]+)%-.+$")
		if character and string.lower(character) == string.lower(name)
			and fullNameKey(leader)
		then
			return leader
		end
		return nativeFullName(name)
	end
	-- Keep the native display name; a nickname match does not establish realm.
	return characterNameKey(name) and name or nil
end

function Directory:FindMembers(info, players, firstOnly)
	local fixtures = GF.TeamListTestData
	if fixtures and type(fixtures.GetLaonongFanMembers) == "function" then
		local members = fixtures:GetLaonongFanMembers(info, players)
		if type(members) == "table" then return #members > 0 and members or nil end
	end
	if not self:IsReady() then return nil end
	local matches, seen = {}, {}
	local function add(name, nicknameOnly)
		local key = fullNameKey(name)
		local matched
		if nicknameOnly then
			local character = characterNameKey(name)
			matched = character and characterNames[character]
			key = key or character
		else
			matched = key and fullNames[key]
		end
		if matched and not seen[key] then
			seen[key] = true
			matches[#matches + 1] = name
		end
	end
	add(nativeFullName(read(info, "leaderName")))
	if firstOnly and #matches > 0 then return matches end
	-- The current result snapshot owns native reads and member invalidation.
	-- No independent per-result cache may outlive a roster replacement.
	for index = 1, 40 do
		local member = read(players, index)
		if member == nil then break end
		add(self:GetMemberName(member, info), not isLeaderMember(member, info))
		if firstOnly and #matches > 0 then return matches end
	end
	return #matches > 0 and matches or nil
end

function Directory:CanOverrideType(kind)
	return kind == nil or kind == GF.SOCIAL_TYPE_BNET
		or kind == GF.SOCIAL_TYPE_FRIEND or kind == GF.SOCIAL_TYPE_GUILD
		or (GF.RESULT_PLAYSTYLE_LABEL_GLOBAL or {})[kind] ~= nil
end

function Directory:GetResultDisplayType(kind, info, entry)
	if not self:CanOverrideType(kind)
		or read(entry, "hasLeaver") == true
		or read(entry, "_gfNetEaseHasBlocklist") == true
	then return kind end
	if self:FindMembers(info, read(entry, "players"), true) then
		return GF.LAONONG_FAN_TYPE
	end
	return kind
end

function Directory:GetApplicantDisplayType(kind, member)
	if self:CanOverrideType(kind) and read(member, "isLeaver") ~= true
		and read(member, "isBlacklisted") ~= true
		and read(member, "blacklistEntry") == nil
		and self:IsApplicantFan(member) == true
	then return GF.LAONONG_FAN_TYPE end
	return kind
end

function Directory:RefreshWithRetry()
	retryTicket = retryTicket + 1
	local ticket = retryTicket
	self:Refresh()
	if ready or not Compat.IsAddOnFullyLoaded(ADDON) then return end
	local delays = { 1, 3, 10 }
	local function retry(attempt)
		if not (C_Timer and type(C_Timer.After) == "function") then return end
		C_Timer.After(delays[attempt], function()
			if ticket ~= retryTicket then return end
			self:Refresh()
			if not ready and delays[attempt + 1] then retry(attempt + 1) end
		end)
	end
	retry(1)
end

function Directory:Init()
	if self.initialized then return end
	self.initialized = true
	self:RefreshWithRetry()
end

function Directory:OnAddonLoaded(name)
	if name == ADDON then self:RefreshWithRetry() end
end
