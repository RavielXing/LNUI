local _, GF = ...

local AI = GF.ActivityInfo or {}
GF.ActivityInfo = AI

local DIFFICULTY_INDEX = {
	normal = 1,
	heroic = 2,
	mythic = 3,
	mplus = 4,
}

local DIFFICULTY_LABEL_KEY = {
	normal = "DIFF_NORMAL",
	heroic = "DIFF_HEROIC",
	mythic = "DIFF_MYTHIC",
	mplus = "DIFF_MYTHIC_PLUS",
}

local DIFFICULTY_LABEL_FALLBACK = {
	normal = "Normal",
	heroic = "Heroic",
	mythic = "Mythic",
	mplus = "M+",
}

local difficultyIDMetaMap

local function cleanText(value)
	if type(value) ~= "string" then
		return nil
	end
	if value == "" then
		return nil
	end
	return value
end

local function trimText(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	return value ~= "" and value or nil
end

local function escapePattern(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	return (value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function normalizedDifficultyLabel(value)
	value = cleanText(value)
	if not value then
		return nil
	end
	value = value:gsub("%s+", "")
	if value == "" then
		return nil
	end
	return string.lower(value)
end

local function addDifficultyTierCandidate(out, seen, tier, value)
	local key = normalizedDifficultyLabel(value)
	if not key or seen[key] then
		return
	end
	seen[key] = true
	out[#out + 1] = {
		tier = tier,
		label = value,
		key = key,
	}
end

local function difficultyTierCandidates()
	local labels = {}
	local seen = {}
	local L = GF.L or {}
	for tier, labelKey in pairs(DIFFICULTY_LABEL_KEY) do
		addDifficultyTierCandidate(labels, seen, tier, L[labelKey])
	end
	for tier, label in pairs(DIFFICULTY_LABEL_FALLBACK) do
		addDifficultyTierCandidate(labels, seen, tier, label)
	end
	addDifficultyTierCandidate(labels, seen, "normal", "普通")
	addDifficultyTierCandidate(labels, seen, "normal", "Normal")
	addDifficultyTierCandidate(labels, seen, "heroic", "英雄")
	addDifficultyTierCandidate(labels, seen, "heroic", "Heroic")
	addDifficultyTierCandidate(labels, seen, "mythic", "史诗")
	addDifficultyTierCandidate(labels, seen, "mythic", "史詩")
	addDifficultyTierCandidate(labels, seen, "mythic", "傳奇")
	addDifficultyTierCandidate(labels, seen, "mythic", "Mythic")
	addDifficultyTierCandidate(labels, seen, "mplus", "M+")
	addDifficultyTierCandidate(labels, seen, "mplus", "Mythic+")
	addDifficultyTierCandidate(labels, seen, "mplus", "Mythic Keystone")
	addDifficultyTierCandidate(labels, seen, "mplus", "Mythic Keystone Dungeon")
	addDifficultyTierCandidate(labels, seen, "mplus", "史诗钥石")
	addDifficultyTierCandidate(labels, seen, "mplus", "傳奇鑰石")
	addDifficultyTierCandidate(labels, seen, "mplus", "史诗钥石地下城")
	addDifficultyTierCandidate(labels, seen, "mplus", "傳奇鑰石地城")
	table.sort(labels, function(a, b)
		return #(a.key or "") > #(b.key or "")
	end)
	return labels
end

local function difficultyTierForLabel(value)
	local key = normalizedDifficultyLabel(value)
	if not key then
		return nil
	end
	for _, candidate in ipairs(difficultyTierCandidates()) do
		if candidate.key == key then
			return candidate.tier, candidate.label
		end
	end
	return nil
end

local function isKnownDifficultyLabel(value)
	return difficultyTierForLabel(value) ~= nil
end

local function stripKnownDifficultySuffix(value)
	value = trimText(value)
	if not value then
		return nil, nil, nil
	end
	local base, suffix = value:match("^(.+)%s*%(([^()]+)%)$")
	if trimText(base) and trimText(suffix) then
		local tier, label = difficultyTierForLabel(suffix)
		if tier then
			return trimText(base), suffix, tier, label
		end
	end
	base, suffix = value:match("^(.+)%s*（(.+)）$")
	if trimText(base) and trimText(suffix) then
		local tier, label = difficultyTierForLabel(suffix)
		if tier then
			return trimText(base), suffix, tier, label
		end
	end

	for _, candidate in ipairs(difficultyTierCandidates()) do
		local escaped = escapePattern(candidate.label)
		if escaped then
			for _, pattern in ipairs({
				"%s*[-–—]%s*" .. escaped .. "%s*$",
				"%s+" .. escaped .. "%s*$",
				"%s*（" .. escaped .. "）%s*$",
				"%s*%(" .. escaped .. "%)%s*$",
			}) do
				local stripped, count = value:gsub(pattern, "")
				stripped = trimText(stripped)
				if count > 0 and stripped and stripped ~= value then
					return stripped, candidate.label, candidate.tier, candidate.label
				end
			end
		end
	end
	return nil, nil, nil
end

local function inferDifficultyTierFromName(info, includeMplus)
	if type(info) ~= "table" then
		return nil
	end
	local function read(value)
		local _, _, tier = stripKnownDifficultySuffix(value)
		if tier == "mplus" and not includeMplus then
			return nil
		end
		return tier
	end
	return read(info.fullName) or read(info.shortName)
end

local function splitDifficultySuffix(fullName)
	fullName = cleanText(fullName)
	if not fullName then
		return nil, nil
	end

	local base, suffix = fullName:match("^(.+)%s*%(([^()]+)%)$")
	if cleanText(base) and cleanText(suffix) then
		return base, suffix
	end

	base, suffix = fullName:match("^(.+)%s*（(.+)）$")
	if cleanText(base) and cleanText(suffix) then
		return base, suffix
	end

	return nil, nil
end

local function splitKnownDifficultySuffix(fullName)
	local base, suffix = stripKnownDifficultySuffix(fullName)
	if base and suffix then
		return base, suffix
	end
	return nil, nil
end

local function parseDelveTierLabel(label)
	label = cleanText(label)
	if not label then
		return nil, nil
	end

	local questionLabel = label:gsub("？", "?")
	if questionLabel:match("^%?+$") then
		return #questionLabel, "?"
	end

	local tier = label:match("^难度[%s　]*(%d+)$")
	if tier then
		return tonumber(tier), "难度"
	end

	local prefix, englishTier = label:match("^([Tt]ier)%s*(%d+)$")
	if englishTier then
		return tonumber(englishTier), prefix
	end

	prefix, englishTier = label:match("^([Dd]ifficulty)%s*(%d+)$")
	if englishTier then
		return tonumber(englishTier), prefix
	end

	return nil, nil
end

local function getDelveTierParts(info)
	if type(info) ~= "table" or info.categoryID ~= GF.CAT_DELVE then
		return nil, nil
	end

	local tier, prefix = parseDelveTierLabel(info.shortName)
	if tier then
		return tier, prefix
	end

	local _, suffix = splitDifficultySuffix(info.fullName)
	tier, prefix = parseDelveTierLabel(suffix)
	if tier then
		return tier, prefix
	end

	return parseDelveTierLabel(info.fullName)
end

local function formatDelveTierLabel(tier, prefix)
	if not tier then
		return nil
	end
	if prefix == "?" then
		return string.rep("?", tier)
	end
	if prefix and prefix ~= "" then
		return string.format("%s %d", prefix, tier)
	end
	return string.format("难度 %d", tier)
end

local function mapDifficultyID(ids, key, tier, playerCount)
	if not ids then
		return
	end
	local difficultyID = ids[key]
	if difficultyID then
		difficultyIDMetaMap[difficultyID] = {
			tier = tier,
			playerCount = playerCount,
		}
	end
end

local function buildDifficultyIDMetaMap()
	difficultyIDMetaMap = {}
	local ids = DifficultyUtil and DifficultyUtil.ID
	mapDifficultyID(ids, "DungeonNormal", "normal")
	mapDifficultyID(ids, "Raid10Normal", "normal", 10)
	mapDifficultyID(ids, "Raid25Normal", "normal", 25)
	mapDifficultyID(ids, "PrimaryRaidNormal", "normal")
	mapDifficultyID(ids, "Raid40", "normal", 40)
	mapDifficultyID(ids, "DungeonHeroic", "heroic")
	mapDifficultyID(ids, "Raid10Heroic", "heroic", 10)
	mapDifficultyID(ids, "Raid25Heroic", "heroic", 25)
	mapDifficultyID(ids, "PrimaryRaidHeroic", "heroic")
	mapDifficultyID(ids, "DungeonMythic", "mythic")
	mapDifficultyID(ids, "PrimaryRaidMythic", "mythic")
	mapDifficultyID(ids, "RaidMythicFlexible", "mythic")
	mapDifficultyID(ids, "DungeonChallenge", "mplus")
	return difficultyIDMetaMap
end

local function getDifficultyMetaFromID(difficultyID)
	difficultyID = tonumber(difficultyID)
	if not difficultyID or difficultyID <= 0 then
		return nil
	end
	local map = difficultyIDMetaMap or buildDifficultyIDMetaMap()
	return map[difficultyID]
end

local function getDifficultyMeta(info)
	if type(info) ~= "table" then
		return nil
	end
	return getDifficultyMetaFromID(info.difficultyID) or getDifficultyMetaFromID(info.redirectedDifficultyID)
end

function AI.GetDifficultyTier(info, opts)
	if type(info) ~= "table" then
		return nil
	end

	local includeMplus = not opts or opts.includeMplus ~= false
	local meta = getDifficultyMeta(info)
	local tier = meta and meta.tier
	if tier == "mplus" then
		return includeMplus and "mplus" or nil
	end
	if tier then
		return tier
	end

	tier = inferDifficultyTierFromName(info, includeMplus)
	if tier then
		return tier
	end

	if info.isMythicPlusActivity then
		return includeMplus and "mplus" or nil
	end
	if info.isMythicActivity then
		return "mythic"
	end
	if info.isHeroicActivity then
		return "heroic"
	end
	if info.isNormalActivity then
		return "normal"
	end
	return nil
end

function AI.GetDelveTierNumber(info)
	local tier = getDelveTierParts(info)
	return tier
end

function AI.GetDelveTierLabel(info)
	local tier, prefix = getDelveTierParts(info)
	return formatDelveTierLabel(tier, prefix)
end

function AI.GetActivitySortIndex(info)
	local delveTier = AI.GetDelveTierNumber(info)
	if delveTier then
		return delveTier
	end
	local difficultyIndex = AI.GetDifficultyIndex(info, { includeMplus = true })
	if difficultyIndex and difficultyIndex > 0 then
		local playerCount = AI.GetDifficultyPlayerCount(info)
		if playerCount and playerCount > 0 then
			return (playerCount * 100) + difficultyIndex
		end
		return difficultyIndex * 100
	end
	return tonumber(info and info.orderIndex) or 0
end

function AI.GetDifficultyIndex(info, opts)
	local tier = AI.GetDifficultyTier(info, opts)
	return (tier and DIFFICULTY_INDEX[tier]) or 0
end

function AI.GetDifficultyPlayerCount(info)
	local meta = getDifficultyMeta(info)
	if meta and meta.playerCount then
		return meta.playerCount
	end
	return nil
end

function AI.GetActivityDifficultyMergeKey(info)
	local delveTier = AI.GetDelveTierNumber(info)
	if delveTier then
		return "delve:" .. tostring(delveTier)
	end
	local difficultyIndex = AI.GetDifficultyIndex(info, { includeMplus = true })
	if difficultyIndex and difficultyIndex > 0 then
		local playerCount = AI.GetDifficultyPlayerCount(info)
		if playerCount and playerCount > 0 then
			return "difficulty:" .. tostring(difficultyIndex) .. ":players:" .. tostring(playerCount)
		end
		return "difficulty:" .. tostring(difficultyIndex)
	end
	return nil
end

function AI.HasDifficultyTier(info)
	return AI.GetDifficultyTier(info, { includeMplus = true }) ~= nil
end

function AI.GetDifficultyLabel(info, opts)
	local tier = AI.GetDifficultyTier(info, opts)
	if not tier then
		return nil
	end

	local _, suffix = splitKnownDifficultySuffix(info.fullName)
	if suffix then
		return suffix
	end

	local shortName = cleanText(info.shortName)
	if shortName and isKnownDifficultyLabel(shortName) then
		return shortName
	end

	local key = DIFFICULTY_LABEL_KEY[tier]
	local L = GF.L or {}
	return (key and L[key]) or DIFFICULTY_LABEL_FALLBACK[tier]
end

function AI.GetActivityLeafLabel(info)
	if type(info) ~= "table" then
		return "?"
	end

	local delveTierLabel = AI.GetDelveTierLabel(info)
	if delveTierLabel then
		return delveTierLabel
	end

	local difficultyLabel = AI.GetDifficultyLabel(info, { includeMplus = true })
	if difficultyLabel then
		return difficultyLabel
	end

	return cleanText(info.shortName) or cleanText(info.fullName) or "?"
end

function AI.GetActivityBaseName(info)
	if type(info) ~= "table" then
		return nil
	end

	local fullName = cleanText(info.fullName)
	if fullName then
		local base = splitKnownDifficultySuffix(fullName)
		if base then
			return base
		end
		if AI.HasDifficultyTier(info) then
			return fullName
		end
	end

	if not AI.HasDifficultyTier(info) then
		local shortName = cleanText(info.shortName)
		if shortName then
			return shortName
		end
	end

	return fullName or cleanText(info.shortName)
end
