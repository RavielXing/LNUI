local _, GF = ...

-- !!!163UI!!! 公开老农粉丝名单的只读会话索引。

GF.LaonongFanDirectory = GF.LaonongFanDirectory or {}
local Directory = GF.LaonongFanDirectory

local SOURCE_U1_PLAYERS = "u1-players"
local SOURCE_UNAVAILABLE = "unavailable"

Directory.source = Directory.source or SOURCE_UNAVAILABLE
Directory.count = Directory.count or 0
Directory.revision = Directory.revision or 0
Directory.fullNameIndex = Directory.fullNameIndex or {}
Directory.shortNameIndex = Directory.shortNameIndex or {}
Directory.listeners = Directory.listeners or {}

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

local function trimText(value)
	if type(value) ~= "string" or isSecret(value) then
		return nil
	end
	value = value:match("^%s*(.-)%s*$")
	return value ~= "" and value or nil
end

local function normalizeCharacter(value)
	value = trimText(value)
	return value and string.lower(value) or nil
end

local function normalizeRealm(value)
	value = trimText(value)
	if not value then
		return nil
	end
	value = value:gsub("%[.-%]", "")
	value = value:gsub("（", "("):gsub("）", ")")
	value = value:gsub("%s+", "")
	value = value:gsub("[%(%)]", "")
	value = trimText(value)
	return value and string.lower(value) or nil
end

local function normalizeFullName(name, fallbackRealm)
	name = trimText(name)
	if not name then
		return nil, nil
	end
	if fallbackRealm ~= nil and (type(fallbackRealm) ~= "string" or isSecret(fallbackRealm)) then
		return nil, nil
	end

	local character, realm = name:match("^([^%-]+)%-(.+)$")
	if not character then
		if fallbackRealm == nil then
			return nil, normalizeCharacter(name)
		end
		character = name
		realm = fallbackRealm
	end

	local characterKey = normalizeCharacter(character)
	local realmKey = normalizeRealm(realm)
	if not characterKey or not realmKey then
		return nil, nil
	end
	return characterKey .. "-" .. realmKey, characterKey
end

local function is163Loaded()
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local _, loaded = C_AddOns.IsAddOnLoaded("!!!163UI!!!")
		return loaded == true
	end
	if IsAddOnLoaded then
		return IsAddOnLoaded("!!!163UI!!!") == true
	end
	return type(U1Donators) == "table"
end

local function getPublicPlayers()
	if not is163Loaded() then
		return nil
	end
	if type(U1Donators) ~= "table" or type(U1Donators.players) ~= "table" then
		return nil
	end
	if next(U1Donators.players) == nil then
		return nil
	end
	return U1Donators.players
end

local function buildIndexes(players)
	local fullNameIndex = {}
	local shortNameIndex = {}
	local count = 0

	if type(players) ~= "table" then
		return fullNameIndex, shortNameIndex, count
	end

	for fullName in pairs(players) do
		local fullKey, shortKey = normalizeFullName(fullName)
		if fullKey and not fullNameIndex[fullKey] then
			fullNameIndex[fullKey] = true
			count = count + 1
			local existing = shortNameIndex[shortKey]
			if existing == nil then
				shortNameIndex[shortKey] = fullKey
			elseif existing ~= fullKey then
				shortNameIndex[shortKey] = false
			end
		end
	end

	return fullNameIndex, shortNameIndex, count
end

local function sameIndex(left, right)
	for key, value in pairs(left) do
		if right[key] ~= value then
			return false
		end
	end
	for key, value in pairs(right) do
		if left[key] ~= value then
			return false
		end
	end
	return true
end

function Directory:GetStatus()
	return {
		source = self.source,
		count = self.count,
		revision = self.revision,
		ready = self.source == SOURCE_U1_PLAYERS,
		addonLoaded = is163Loaded(),
		playersReady = type(getPublicPlayers()) == "table",
		reason = self.lastRefreshReason,
	}
end

function Directory:GetRevision()
	return self.revision or 0
end

function Directory:IsReady()
	return self.source == SOURCE_U1_PLAYERS
end

function Directory:AddListener(callback)
	if type(callback) == "function" then
		self.listeners[callback] = true
	end
end

function Directory:NotifyChanged()
	local status = self:GetStatus()
	for callback in pairs(self.listeners) do
		local ok, err = pcall(callback, status)
		if not ok and type(geterrorhandler) == "function" then
			local handler = geterrorhandler()
			if type(handler) == "function" then
				pcall(handler, err)
			end
		end
	end
end

function Directory:Refresh(reason)
	local players = getPublicPlayers()
	local fullNameIndex, shortNameIndex, count = buildIndexes(players)
	local nextSource = players and count > 0 and SOURCE_U1_PLAYERS or SOURCE_UNAVAILABLE
	local changed = nextSource ~= self.source
		or count ~= self.count
		or not sameIndex(fullNameIndex, self.fullNameIndex)
		or not sameIndex(shortNameIndex, self.shortNameIndex)

	self.lastRefreshReason = reason or "manual"
	if not changed then
		return false, self:GetStatus()
	end

	self.source = nextSource
	self.count = count
	self.fullNameIndex = fullNameIndex
	self.shortNameIndex = shortNameIndex
	self.revision = (self.revision or 0) + 1
	self:NotifyChanged()
	return true, self:GetStatus()
end

function Directory:IsFanName(name, fallbackRealm, allowUniqueShortName)
	if not self:IsReady() then
		return nil
	end
	local fullKey, shortKey = normalizeFullName(name, fallbackRealm)
	if fullKey then
		return self.fullNameIndex[fullKey] == true
	end
	if allowUniqueShortName and shortKey then
		local uniqueFullKey = self.shortNameIndex[shortKey]
		return uniqueFullKey ~= nil and uniqueFullKey ~= false
	end
	return false
end

function GF.GetLaonongFanDirectoryStatus()
	return Directory:GetStatus()
end

function GF.GetLaonongFanDirectoryRevision()
	return Directory:GetRevision()
end

function GF.IsLaonongFanDirectoryReady()
	return Directory:IsReady()
end

function GF.RefreshLaonongFanDirectory(reason)
	return Directory:Refresh(reason)
end

function GF.IsLaonongFanName(name, fallbackRealm, allowUniqueShortName)
	return Directory:IsFanName(name, fallbackRealm, allowUniqueShortName)
end
