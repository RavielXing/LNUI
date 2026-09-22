local _, GF = ...

GF.MythicPlusSeasonData = GF.MythicPlusSeasonData or {}
local Data = GF.MythicPlusSeasonData

-- Emergency cold-start season rosters. The live Challenge Mode catalog and
-- the account's last-known same-season catalog always take precedence. These
-- records define stable navigation identity only; they never authorize LFG
-- search or creation.
local LATEST_FALLBACK_SEASON_ID = 18
local FALLBACK_SEASONS = {
	[16] = {
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
	},
	[18] = {
		{
			challengeModeID = 584,
			teleportSpellID = 1286801,
			fallbackName = "The Blinding Vale",
		},
		{
			challengeModeID = 585,
			teleportSpellID = 1286804,
			fallbackName = "Voidscar Arena",
		},
		{
			challengeModeID = 586,
			teleportSpellID = 1286807,
			fallbackName = "Den of Nalorakk",
		},
		{
			challengeModeID = 587,
			teleportSpellID = 1286809,
			fallbackName = "Murder Row",
		},
		{
			challengeModeID = 588,
			teleportSpellID = 1286812,
			fallbackName = "Altar of Fangs",
		},
		{
			challengeModeID = 249,
			teleportSpellID = 1286831,
			fallbackName = "Kings' Rest",
		},
		{
			challengeModeID = 250,
			teleportSpellID = 1286828,
			fallbackName = "Temple of Sethraliss",
		},
		{
			challengeModeID = 399,
			teleportSpellID = 393256,
			fallbackName = "Ruby Life Pools",
		},
	},
}

-- Hero's Path unlocks are spellbook capabilities, not current-season catalog
-- membership. Keep supported patch mappings together so the same addon build
-- can run on 12.0.7 and 12.1 without exposing the other patch's dungeons in
-- the fallback display catalog above.
local ADDITIONAL_TELEPORT_SPELLS = {
	-- Midnight 12.1 / season 18. These are the learned, 10-second "Path"
	-- spells; the similarly named 128977x records are internal teleport effects.
	[584] = 1286801, -- The Blinding Vale
	[585] = 1286804, -- Voidscar Arena
	[586] = 1286807, -- Den of Nalorakk
	[587] = 1286809, -- Murder Row
	[588] = 1286812, -- Altar of Fangs
	[249] = 1286831, -- Kings' Rest
	[250] = 1286828, -- Temple of Sethraliss
	[399] = 393256, -- Ruby Life Pools
}

local BY_CHALLENGE_MODE_ID = {}
for seasonID, dungeons in pairs(FALLBACK_SEASONS) do
	BY_CHALLENGE_MODE_ID[seasonID] = {}
	for _, dungeon in ipairs(dungeons) do
		BY_CHALLENGE_MODE_ID[seasonID][dungeon.challengeModeID] = dungeon
	end
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
	if type(GetBuildInfo) == "function" then
		local ok, _, _, _, interfaceVersion = pcall(GetBuildInfo)
		interfaceVersion = ok and tonumber(interfaceVersion) or nil
		if interfaceVersion and interfaceVersion < 120100 then
			return 16
		end
	end
	return LATEST_FALLBACK_SEASON_ID
end

local function fallbackDungeonsForSeason(seasonID)
	if seasonID ~= nil then
		seasonID = tonumber(seasonID)
	else
		seasonID = Data.GetFallbackSeasonID()
	end
	return FALLBACK_SEASONS[seasonID] or {}
end

function Data.GetFallbackDungeons(seasonID)
	local out = {}
	for index, dungeon in ipairs(fallbackDungeonsForSeason(seasonID)) do
		out[index] = copyDungeon(dungeon)
	end
	return out
end

function Data.GetFallbackChallengeModeIDs(seasonID)
	local out = {}
	for index, dungeon in ipairs(fallbackDungeonsForSeason(seasonID)) do
		out[index] = dungeon.challengeModeID
	end
	return out
end

function Data.GetFallbackDungeon(challengeModeID, seasonID)
	challengeModeID = tonumber(challengeModeID)
	seasonID = tonumber(seasonID)
	if seasonID and BY_CHALLENGE_MODE_ID[seasonID] then
		return copyDungeon(BY_CHALLENGE_MODE_ID[seasonID][challengeModeID])
	end
	for _, byChallengeModeID in pairs(BY_CHALLENGE_MODE_ID) do
		if byChallengeModeID[challengeModeID] then
			return copyDungeon(byChallengeModeID[challengeModeID])
		end
	end
	return nil
end

function Data.GetTeleportSpellMap()
	local out = {}
	for _, dungeons in pairs(FALLBACK_SEASONS) do
		for _, dungeon in ipairs(dungeons) do
			if dungeon.challengeModeID and dungeon.teleportSpellID then
				out[dungeon.challengeModeID] = dungeon.teleportSpellID
			end
		end
	end
	for challengeModeID, teleportSpellID in pairs(ADDITIONAL_TELEPORT_SPELLS) do
		out[challengeModeID] = teleportSpellID
	end
	return out
end
