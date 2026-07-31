local _, GF = ...

GF.MythicPlusSeasonCatalog = GF.MythicPlusSeasonCatalog or {}
local Catalog = GF.MythicPlusSeasonCatalog
local Data = GF.MythicPlusSeasonData
local Util = GF.MythicPlusServiceUtil

local REQUIRED_STABLE_LIVE_OBSERVATIONS = 3

local function copyValidIDs(source)
	local out = {}
	local seen = {}
	for _, value in ipairs(type(source) == "table" and source or {}) do
		local challengeModeID = tonumber(value)
		if challengeModeID and challengeModeID > 0
			and challengeModeID % 1 == 0
			and not seen[challengeModeID]
		then
			seen[challengeModeID] = true
			out[#out + 1] = challengeModeID
		end
	end
	return out
end

local function getCurrentSeasonID()
	if not (C_MythicPlus and C_MythicPlus.GetCurrentSeason) then
		return nil
	end
	local ok, seasonID = pcall(C_MythicPlus.GetCurrentSeason)
	seasonID = ok and tonumber(seasonID) or nil
	return seasonID and seasonID > 0 and seasonID or nil
end

local function getLiveChallengeModeIDs()
	if not (C_ChallengeMode and C_ChallengeMode.GetMapTable) then
		return {}, false
	end
	local ok, mapIDs = pcall(C_ChallengeMode.GetMapTable)
	if not ok or type(mapIDs) ~= "table" then
		return {}, true
	end
	return copyValidIDs(mapIDs), true
end

local function getSeasonCache()
	if not GF.GetMythicPlusDB then
		return nil
	end
	local ok, mythicPlusDB = pcall(GF.GetMythicPlusDB)
	if not ok or type(mythicPlusDB) ~= "table"
		or type(mythicPlusDB.seasonDungeonCache) ~= "table"
	then
		return nil
	end
	return mythicPlusDB.seasonDungeonCache
end

local function getCachedIDs(currentSeasonID)
	local cache = getSeasonCache()
	if not cache or not currentSeasonID then
		return {}
	end
	if tonumber(cache.seasonID) ~= currentSeasonID then
		return {}
	end
	return copyValidIDs(cache.challengeModeIDs)
end

local function saveLiveIDs(challengeModeIDs, currentSeasonID)
	if not currentSeasonID then
		return
	end
	local cache = getSeasonCache()
	if not cache then
		return
	end
	cache.challengeModeIDs = Util.CopyArray(challengeModeIDs)
	cache.seasonID = currentSeasonID
	cache.updatedAt = Util.Now()
	cache.source = "challengeMode"
end

local function getSessionIDs(owner, currentSeasonID)
	if not owner or type(owner.dungeons) ~= "table" then
		return {}
	end
	if currentSeasonID and tonumber(owner.seasonID) ~= currentSeasonID then
		return {}
	end
	local ids = {}
	for _, dungeon in ipairs(owner.dungeons) do
		if dungeon and dungeon.challengeModeID then
			ids[#ids + 1] = dungeon.challengeModeID
		end
	end
	return copyValidIDs(ids)
end

local function getStaticIDs(currentSeasonID)
	if not (Data and Data.GetFallbackChallengeModeIDs
		and Data.GetFallbackSeasonID)
	then
		return {}
	end
	local fallbackSeasonID = tonumber(Data.GetFallbackSeasonID())
	if currentSeasonID and fallbackSeasonID ~= currentSeasonID then
		return {}
	end
	return copyValidIDs(Data.GetFallbackChallengeModeIDs())
end

local function observeLiveCatalog(owner, liveIDs, currentSeasonID)
	if #liveIDs == 0 then
		owner.liveCatalogSignature = nil
		owner.liveCatalogObservationCount = 0
		return false
	end
	local signature = tostring(currentSeasonID or "unknown")
		.. "|" .. table.concat(liveIDs, ",")
	if owner.liveCatalogSignature == signature then
		owner.liveCatalogObservationCount = math.min(
			REQUIRED_STABLE_LIVE_OBSERVATIONS,
			(owner.liveCatalogObservationCount or 0) + 1)
	else
		owner.liveCatalogSignature = signature
		owner.liveCatalogObservationCount = 1
	end
	return owner.liveCatalogObservationCount
		>= REQUIRED_STABLE_LIVE_OBSERVATIONS
end

local function chooseCatalog(owner)
	local currentSeasonID = getCurrentSeasonID()
	local liveIDs, nativeAPIAvailable = getLiveChallengeModeIDs()
	local liveCatalogStable = observeLiveCatalog(
		owner, liveIDs, currentSeasonID)
	local sessionIDs = getSessionIDs(owner, currentSeasonID)
	local cachedIDs = getCachedIDs(currentSeasonID)
	local staticIDs = getStaticIDs(currentSeasonID)

	if #liveIDs > 0 then
		local candidateIDs = liveIDs
		local source = "challengeMode"
		-- A short non-empty result can occur while native data is still arriving.
		-- Never replace a known complete same-season catalog with that fragment.
		if #sessionIDs > #candidateIDs then
			candidateIDs = sessionIDs
			source = "sessionCache"
		elseif #cachedIDs > #candidateIDs then
			candidateIDs = cachedIDs
			source = "savedCache"
		elseif #staticIDs > #candidateIDs then
			candidateIDs = staticIDs
			source = "staticFallback"
		else
			if liveCatalogStable then
				saveLiveIDs(liveIDs, currentSeasonID)
			else
				source = "challengeModePending"
			end
		end
		return candidateIDs, source, currentSeasonID,
			nativeAPIAvailable, liveIDs, liveCatalogStable
	end
	if #sessionIDs > 0 then
		return sessionIDs, "sessionCache", currentSeasonID,
			nativeAPIAvailable, liveIDs, liveCatalogStable
	end
	if #cachedIDs > 0 then
		return cachedIDs, "savedCache", currentSeasonID,
			nativeAPIAvailable, liveIDs, liveCatalogStable
	end
	if #staticIDs > 0 then
		return staticIDs, "staticFallback", currentSeasonID,
			nativeAPIAvailable, liveIDs, liveCatalogStable
	end
	return {}, "unavailable", currentSeasonID, nativeAPIAvailable,
		liveIDs, liveCatalogStable
end

local function getPreviousDungeon(owner, challengeModeID, currentSeasonID)
	if currentSeasonID and tonumber(owner.seasonID) ~= currentSeasonID then
		return nil
	end
	return owner.byChallengeModeID
		and owner.byChallengeModeID[challengeModeID] or nil
end

local function readChallengeMap(owner, challengeModeID, seasonMapOrder,
	currentSeasonID)
	local previous = getPreviousDungeon(
		owner, challengeModeID, currentSeasonID)
	local fallback = Data and Data.GetFallbackDungeon
		and Data.GetFallbackDungeon(challengeModeID) or nil
	local name
	local returnedID
	local timeLimit
	local texture
	local backgroundTexture
	local instanceMapID
	local mapInfoReady = false
	if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
		local ok
		ok, name, returnedID, timeLimit, texture, backgroundTexture,
			instanceMapID = pcall(
				C_ChallengeMode.GetMapUIInfo, challengeModeID)
		mapInfoReady = ok and type(name) == "string" and name ~= ""
		if not ok then
			name = nil
			returnedID = nil
			timeLimit = nil
			texture = nil
			backgroundTexture = nil
			instanceMapID = nil
		end
	end
	name = mapInfoReady and name
		or previous and previous.name
		or fallback and fallback.fallbackName
		or string.format("#%d", challengeModeID)
	timeLimit = tonumber(timeLimit)
		or previous and previous.timeLimit
	texture = texture
		or previous and previous.texture
		or fallback and fallback.fallbackTexture
	backgroundTexture = backgroundTexture
		or previous and previous.backgroundTexture
	instanceMapID = tonumber(instanceMapID)
		or previous and tonumber(previous.instanceMapID or previous.mapID)
	return {
		key = string.format("challenge:%d", challengeModeID),
		orderIndex = seasonMapOrder,
		challengeModeID = challengeModeID,
		seasonMapOrder = seasonMapOrder,
		name = name,
		timeLimit = timeLimit,
		texture = texture,
		backgroundTexture = backgroundTexture,
		mapID = instanceMapID,
		instanceMapID = instanceMapID,
		nameKey = Util.NormalizeName(name),
		mapInfoReady = mapInfoReady,
		returnedChallengeModeID = tonumber(returnedID),
		fallbackTexCoords = fallback and fallback.fallbackTexCoords or nil,
	}
end

function Catalog.Build(owner)
	local challengeModeIDs
	local source
	local currentSeasonID
	local nativeAPIAvailable
	local liveIDs
	local liveCatalogStable
	challengeModeIDs, source, currentSeasonID, nativeAPIAvailable, liveIDs,
		liveCatalogStable = chooseCatalog(owner)

	local dungeons = {}
	local allMapInfoReady = #challengeModeIDs > 0
	for seasonMapOrder, challengeModeID in ipairs(challengeModeIDs) do
		local dungeon = readChallengeMap(
			owner, challengeModeID, seasonMapOrder, currentSeasonID)
		dungeons[#dungeons + 1] = dungeon
		if not dungeon.mapInfoReady then
			allMapInfoReady = false
		end
	end
	return dungeons, {
		source = source,
		seasonID = currentSeasonID,
		nativeAPIAvailable = nativeAPIAvailable,
		liveIDs = liveIDs,
		liveCatalogStable = liveCatalogStable,
		allMapInfoReady = allMapInfoReady,
	}
end
