local _, GF = ...

local Service = {}
GF.ApplicantRaidProfileService = Service

Service.PROVIDER_RAIDERIO = "raiderio"
Service.PROVIDER_ARCHON = "archon"

Service.STATE_UNAVAILABLE = "unavailable"
Service.STATE_PENDING = "pending"
Service.STATE_READY = "ready"
Service.STATE_MISSING = "missing"

local PREPARE_INTERVAL_SECONDS = 0.05
local NEGATIVE_CACHE_TTL_SECONDS = 15

-- Raider.IO's previousRaids may lack activity metadata. Match the provider
-- identity and boss count; the combined tier shares an ID/map with a real raid.
local KNOWN_RAID_NAMES = {
	[16340] = { bossCount = 9, key = "APPLICANT_RAID_MIDNIGHT_TIER1", combined = true },
	[8062] = { bossCount = 1, key = "APPLICANT_RAID_SPOREFALL" },
}
local clientLocale = GetLocale and GetLocale() or "enUS"

local providerCaches = {
	raiderio = {},
	archon = {},
}
local pendingQueue = {}
local pendingKeys = {}
local pendingTimer
local pendingGeneration = 0
local raiderIORaidNamesByIdentity = {}
local raiderIORaidNamesByObject = setmetatable({}, { __mode = "k" })

local function trimText(text)
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return text ~= "" and text or nil
end

local function readField(owner, key)
	local compat = GF.Compat
	if compat and type(compat.ReadAccessibleField) == "function" then
		local value = compat.ReadAccessibleField(owner, key)
		return value
	end
	if type(owner) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	return ok and value or nil
end

local function toNumber(value)
	local compat = GF.Compat
	if compat and type(compat.ToAccessibleNumber) == "function" then
		return compat.ToAccessibleNumber(value)
	end
	local ok, number = pcall(tonumber, value)
	return ok and type(number) == "number" and number or nil
end

local function arrayLength(values)
	local compat = GF.Compat
	if compat and type(compat.GetAccessibleArrayLength) == "function" then
		return compat.GetAccessibleArrayLength(values)
	end
	if type(values) ~= "table" then
		return nil
	end
	local ok, length = pcall(function()
		return #values
	end)
	return ok and type(length) == "number" and length or nil
end

local function knownRaidName(raid)
	local dungeon = readField(raid, "dungeon")
	local id = toNumber(readField(raid, "id"))
		or toNumber(readField(dungeon, "id"))
	local entry = id and KNOWN_RAID_NAMES[id]
	local bossCount = toNumber(readField(raid, "bossCount"))
		or toNumber(readField(dungeon, "bossCount"))
	return entry and bossCount == entry.bossCount and entry or nil
end

local function localizedKnownRaidName(entry)
	-- Combined tiers are our UI labels; real raid names follow the game locale.
	local strings = entry.combined and GF.L or GF["locale_" .. clientLocale]
	return trimText(readField(strings, entry.key))
end

local function raidIdentityKeys(raid)
	if type(raid) ~= "table" then
		return {}
	end
	local keys, seen = {}, {}
	local function add(prefix, value)
		value = toNumber(value)
		if not value or value <= 0 then
			return
		end
		local key = prefix .. tostring(value)
		if not seen[key] then
			seen[key] = true
			keys[#keys + 1] = key
		end
	end
	local dungeon = readField(raid, "dungeon")
	add("raid:", readField(raid, "id"))
	add("map:", readField(raid, "mapId"))
	add("raid:", readField(dungeon, "id"))
	add("map:", readField(dungeon, "instance_map_id"))
	return keys
end

local function raidMapIDs(raid)
	local mapIDs = {}
	local function add(value)
		value = toNumber(value)
		if value and value > 0 then
			mapIDs[value] = true
		end
	end
	local dungeon = readField(raid, "dungeon")
	add(readField(raid, "mapId"))
	add(readField(dungeon, "instance_map_id"))
	local values = readField(dungeon, "instance_map_ids")
	for i = 1, arrayLength(values) or 0 do
		add(readField(values, i))
	end
	return mapIDs
end

local function activityIDsForRaid(raid)
	local activityIDs = readField(raid, "lfd_activity_ids")
	if type(activityIDs) == "table" then
		return activityIDs
	end
	local dungeon = readField(raid, "dungeon")
	activityIDs = readField(dungeon, "lfd_activity_ids")
	return type(activityIDs) == "table" and activityIDs or nil
end

local function clientLocalizedRaidName(raid)
	local getActivityInfo = C_LFGList and C_LFGList.GetActivityInfoTable
	local getGroupInfo = C_LFGList and C_LFGList.GetActivityGroupInfo
	if type(getActivityInfo) ~= "function" or type(getGroupInfo) ~= "function" then
		return nil
	end
	local activityIDs = activityIDsForRaid(raid)
	local activityCount = arrayLength(activityIDs)
	if not activityCount then
		return nil
	end
	local expectedCategoryID = toNumber(GF.CAT_RAID)
	local expectedMapIDs = raidMapIDs(raid)
	local hasExpectedMap = next(expectedMapIDs) ~= nil
	for i = 1, activityCount do
		local activityID = toNumber(readField(activityIDs, i))
		local ok, info = false, nil
		if activityID then
			ok, info = pcall(getActivityInfo, activityID)
		end
		if ok and type(info) == "table" then
			local categoryID = toNumber(readField(info, "categoryID"))
			local mapID = toNumber(readField(info, "mapID"))
			local categoryMatches = not expectedCategoryID
				or categoryID == expectedCategoryID
			local mapMatches = not hasExpectedMap
				or (mapID and expectedMapIDs[mapID] == true)
			if categoryMatches and mapMatches then
				local groupID = toNumber(readField(
					info, "groupFinderActivityGroupID"))
				if groupID and groupID > 0 then
					local groupOK, groupName = pcall(getGroupInfo, groupID)
					if groupOK then
						local trimOK, localizedName = pcall(trimText, groupName)
						if trimOK and localizedName then
							return localizedName
						end
					end
				end
			end
		end
	end
	return nil
end

local function cacheRaiderIORaidName(raid)
	if type(raid) ~= "table" then
		return
	end
	local known = knownRaidName(raid)
	if known and known.combined then
		return
	end
	local localizedName = clientLocalizedRaidName(raid)
	if not localizedName then
		return
	end
	raiderIORaidNamesByObject[raid] = localizedName
	for _, key in ipairs(raidIdentityKeys(raid)) do
		raiderIORaidNamesByIdentity[key] = localizedName
	end
end

local function prepareRaiderIORaidNames(raidProfile)
	local progress = readField(raidProfile, "progress")
	for i = 1, arrayLength(progress) or 0 do
		local item = readField(progress, i)
		local raid = readField(item, "raid")
		if type(raid) == "table" and not raiderIORaidNamesByObject[raid] then
			cacheRaiderIORaidName(raid)
		end
	end
end

local function currentRealmName()
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	if type(realm) ~= "string" or realm == "" then
		realm = GetRealmName and GetRealmName()
	end
	return trimText(realm)
end

local function splitCharacterName(name)
	name = trimText(name)
	if not name then
		return nil, nil
	end
	local characterName, realm = name:match("^([^%-]+)%-(.+)$")
	if not characterName then
		characterName = (Ambiguate and Ambiguate(name, "short")) or name
		realm = currentRealmName()
	end
	return trimText(characterName), trimText(realm)
end

local function normalizeRealm(realm)
	realm = trimText(realm)
	return realm and realm:gsub("%s+", "") or nil
end

local REGION_NAME_FALLBACK = {
	[1] = "US",
	[2] = "KR",
	[3] = "EU",
	[4] = "TW",
	[5] = "CN",
}

local function currentRegionToken()
	local regionName = GetCurrentRegionName and GetCurrentRegionName()
	if type(regionName) == "string" and regionName ~= "" then
		return string.upper(regionName)
	end
	return REGION_NAME_FALLBACK[tonumber(GetCurrentRegion and GetCurrentRegion()) or 0]
		or "US"
end

local function nowSeconds()
	if type(GetTime) == "function" then
		local ok, value = pcall(GetTime)
		if ok and type(value) == "number" then
			return value
		end
	end
	return 0
end

local function getRaiderIOProvider()
	local provider = _G and _G.RaiderIO
	return provider and type(provider.GetProfile) == "function" and provider or nil
end

local function getArchonProvider()
	local provider = _G and _G.ArchonTooltip
	return provider and type(provider.GetProfile) == "function" and provider or nil
end

local providerResolvers = {
	raiderio = getRaiderIOProvider,
	archon = getArchonProvider,
}

local function getProvider(kind)
	local resolver = providerResolvers[kind]
	return resolver and resolver() or nil
end

local function characterCacheKey(name)
	local characterName, realm = splitCharacterName(name)
	realm = normalizeRealm(realm)
	if not characterName or not realm then
		return nil
	end
	return table.concat({
		string.lower(currentRegionToken()),
		string.lower(realm),
		string.lower(characterName),
	}, ":")
end

local function isReusableCacheEntry(entry, provider, now)
	if not (entry and entry.provider == provider) then
		return false
	end
	if entry.state == Service.STATE_READY then
		return true
	end
	return entry.state == Service.STATE_MISSING
		and (tonumber(entry.expiresAt) or 0) > now
end

local function cancelTimer(timer)
	if timer and type(timer.Cancel) == "function" then
		pcall(timer.Cancel, timer)
	end
end

local function queryRaiderIO(provider, name)
	local characterName, realm = splitCharacterName(name)
	if not characterName or not realm then
		return nil
	end
	local region = string.lower(currentRegionToken())
	local ok, profile = pcall(
		provider.GetProfile, characterName, realm, region)
	local raidProfile = ok and type(profile) == "table"
		and profile.raidProfile or nil
	if type(raidProfile) == "table"
		and raidProfile.hasRenderableData ~= false
	then
		prepareRaiderIORaidNames(raidProfile)
		return raidProfile
	end
	return nil
end

local function queryArchon(provider, name)
	local characterName, realm = splitCharacterName(name)
	if not characterName or not realm then
		return nil
	end
	local ok, profile = pcall(provider.GetProfile, characterName, realm)
	if ok and type(profile) == "table" then
		return profile
	end
	return nil
end

local providerQueries = {
	raiderio = queryRaiderIO,
	archon = queryArchon,
}

local scheduleNext

local function executePendingTask(task)
	if type(task) ~= "table" then
		return
	end
	local provider = getProvider(task.kind)
	if not provider then
		return
	end
	if provider ~= task.provider then
		Service:PrepareProvider(task.kind, task.name)
		return
	end
	local query = providerQueries[task.kind]
	local profile = query and query(provider, task.name) or nil
	local cache = providerCaches[task.kind]
	if not cache then
		return
	end
	if type(profile) == "table" then
		cache[task.cacheKey] = {
			provider = provider,
			profile = profile,
			state = Service.STATE_READY,
		}
	else
		cache[task.cacheKey] = {
			provider = provider,
			state = Service.STATE_MISSING,
			expiresAt = nowSeconds() + NEGATIVE_CACHE_TTL_SECONDS,
		}
	end
end

local function onPrepareTimer(generation)
	if generation ~= pendingGeneration then
		return
	end
	pendingTimer = nil
	local task = table.remove(pendingQueue, 1)
	if task then
		pendingKeys[task.queueKey] = nil
		executePendingTask(task)
	end
	scheduleNext()
end

scheduleNext = function()
	if pendingTimer or #pendingQueue == 0 then
		return
	end
	local generation = pendingGeneration
	if C_Timer and type(C_Timer.NewTimer) == "function" then
		pendingTimer = C_Timer.NewTimer(PREPARE_INTERVAL_SECONDS, function()
			onPrepareTimer(generation)
		end)
	elseif C_Timer and type(C_Timer.After) == "function" then
		pendingTimer = true
		C_Timer.After(PREPARE_INTERVAL_SECONDS, function()
			onPrepareTimer(generation)
		end)
	end
end

function Service:HasProvider()
	return getRaiderIOProvider() ~= nil or getArchonProvider() ~= nil
end

function Service:GetProfile(kind, name)
	local provider = getProvider(kind)
	if not provider then
		return nil, self.STATE_UNAVAILABLE
	end
	local cacheKey = characterCacheKey(name)
	if not cacheKey then
		return nil, self.STATE_MISSING
	end
	local cache = providerCaches[kind]
	if not cache then
		return nil, self.STATE_UNAVAILABLE
	end
	local entry = cache[cacheKey]
	if isReusableCacheEntry(entry, provider, nowSeconds()) then
		return entry.profile, entry.state
	end
	if entry then
		cache[cacheKey] = nil
	end
	return nil, self.STATE_PENDING
end

function Service:GetRaiderIORaidDisplayName(raid)
	if type(raid) ~= "table" then
		return nil
	end
	local known = knownRaidName(raid)
	if known and known.combined then
		return localizedKnownRaidName(known)
	end
	local localizedName = raiderIORaidNamesByObject[raid]
	if localizedName then
		return localizedName
	end
	for _, key in ipairs(raidIdentityKeys(raid)) do
		localizedName = raiderIORaidNamesByIdentity[key]
		if localizedName then
			return localizedName
		end
	end
	return known and localizedKnownRaidName(known) or nil
end

function Service:PrepareProvider(kind, name)
	local provider = getProvider(kind)
	local cache = providerCaches[kind]
	local cacheKey = characterCacheKey(name)
	if not (provider and cache and cacheKey and providerQueries[kind]) then
		return false
	end
	local now = nowSeconds()
	local entry = cache[cacheKey]
	if isReusableCacheEntry(entry, provider, now) then
		return false
	end
	if entry then
		cache[cacheKey] = nil
	end
	local queueKey = kind .. ":" .. cacheKey
	if pendingKeys[queueKey] then
		return false
	end
	pendingKeys[queueKey] = true
	pendingQueue[#pendingQueue + 1] = {
		kind = kind,
		name = name,
		provider = provider,
		cacheKey = cacheKey,
		queueKey = queueKey,
	}
	scheduleNext()
	return true
end

function Service:Prepare(name)
	local scheduled = 0
	if self:PrepareProvider(self.PROVIDER_RAIDERIO, name) then
		scheduled = scheduled + 1
	end
	if self:PrepareProvider(self.PROVIDER_ARCHON, name) then
		scheduled = scheduled + 1
	end
	return scheduled
end

function Service:CancelPending()
	pendingGeneration = pendingGeneration + 1
	cancelTimer(pendingTimer)
	pendingTimer = nil
	pendingQueue = {}
	pendingKeys = {}
end
