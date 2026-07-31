local _, GF = ...

GF.MythicPlusSeasonData = GF.MythicPlusSeasonData or {}
local Data = GF.MythicPlusSeasonData

-- Emergency cold-start fallback for Mythic+ season 16. The live Challenge
-- Mode catalog and the account's last-known catalog always take precedence.
-- These records never authorize LFG search or creation.
local FALLBACK_SEASON_ID = 16
local FALLBACK_DUNGEONS = {
	{
		challengeModeID = 560,
		teleportSpellID = 1254559,
		fallbackName = "Maisara Caverns",
	},
	{
		challengeModeID = 559,
		teleportSpellID = 1254563,
		fallbackName = "Nexus-Point Xenas",
	},
	{
		challengeModeID = 558,
		teleportSpellID = 1254572,
		fallbackName = "Magisters' Terrace",
	},
	{
		challengeModeID = 557,
		teleportSpellID = 1254400,
		fallbackName = "Windrunner Spire",
	},
	{
		challengeModeID = 402,
		teleportSpellID = 393273,
		fallbackName = "Algeth'ar Academy",
	},
	{
		challengeModeID = 556,
		teleportSpellID = 1254555,
		fallbackName = "Pit of Saron",
	},
	{
		challengeModeID = 161,
		teleportSpellID = 159898,
		fallbackName = "Skyreach",
		fallbackTexture = 1042064,
		fallbackTexCoords = { 0, 0.96, 0, 0.96 },
	},
	{
		challengeModeID = 239,
		teleportSpellID = 1254551,
		fallbackName = "Seat of the Triumvirate",
	},
}

local BY_CHALLENGE_MODE_ID = {}
for _, dungeon in ipairs(FALLBACK_DUNGEONS) do
	BY_CHALLENGE_MODE_ID[dungeon.challengeModeID] = dungeon
end

local function copyArray(source)
	local out = {}
	for index, value in ipairs(source or {}) do
		out[index] = value
	end
	return out
end

local function copyDungeon(source)
	if type(source) ~= "table" then
		return nil
	end
	return {
		challengeModeID = source.challengeModeID,
		teleportSpellID = source.teleportSpellID,
		fallbackName = source.fallbackName,
		fallbackTexture = source.fallbackTexture,
		fallbackTexCoords = copyArray(source.fallbackTexCoords),
	}
end

function Data.GetFallbackSeasonID()
	return FALLBACK_SEASON_ID
end

function Data.GetFallbackDungeons()
	local out = {}
	for index, dungeon in ipairs(FALLBACK_DUNGEONS) do
		out[index] = copyDungeon(dungeon)
	end
	return out
end

function Data.GetFallbackChallengeModeIDs()
	local out = {}
	for index, dungeon in ipairs(FALLBACK_DUNGEONS) do
		out[index] = dungeon.challengeModeID
	end
	return out
end

function Data.GetFallbackDungeon(challengeModeID)
	return copyDungeon(BY_CHALLENGE_MODE_ID[tonumber(challengeModeID)])
end

function Data.GetTeleportSpellMap()
	local out = {}
	for _, dungeon in ipairs(FALLBACK_DUNGEONS) do
		if dungeon.challengeModeID and dungeon.teleportSpellID then
			out[dungeon.challengeModeID] = dungeon.teleportSpellID
		end
	end
	return out
end
