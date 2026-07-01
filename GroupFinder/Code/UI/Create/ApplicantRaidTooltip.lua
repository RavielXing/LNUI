local _, GF = ...

GF.ApplicantRaidTooltip = GF.ApplicantRaidTooltip or {}
local ART = GF.ApplicantRaidTooltip

local LABEL_COLOR = { r = 1, g = 0.82, b = 0 }
local TEXT_COLOR = { r = 1, g = 1, b = 1 }
local GRAY_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
local NORMAL_COLOR = { r = 1, g = 1, b = 1 }
local HEROIC_COLOR = { r = 0.18, g = 0.85, b = 0.36 }
local MYTHIC_COLOR = { r = 0.72, g = 0.22, b = 1 }
local WCL_COLOR = { r = 0.15, g = 0.78, b = 1 }
local MAX_WCL_SECTIONS = 3

local REGION_NAME_FALLBACK = {
	[1] = "US",
	[2] = "KR",
	[3] = "EU",
	[4] = "TW",
	[5] = "CN",
}

local RAID_DIFFICULTY_ID_BY_TIER = {
	[1] = "PrimaryRaidNormal",
	[2] = "PrimaryRaidHeroic",
	[3] = "PrimaryRaidMythic",
}

local RAID_DIFFICULTY_LOCALE_KEY_BY_TIER = {
	[1] = "DIFF_NORMAL",
	[2] = "DIFF_HEROIC",
	[3] = "DIFF_MYTHIC",
}

local RAID_DIFFICULTY_FALLBACK_BY_TIER = {
	[1] = "Normal",
	[2] = "Heroic",
	[3] = "Mythic",
}

local ARCHON_DIFFICULTY_TIER_BY_ID = {
	[3] = 1,
	[4] = 2,
	[5] = 3,
	[14] = 1,
	[15] = 2,
	[16] = 3,
}

local journalCache
local raidInfoCache = {}

local function trimText(text)
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return text ~= "" and text or nil
end

local function callFirst(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if ok then
		return result
	end
	return nil
end

local function localeText(key, fallback)
	local L = GF.L or {}
	return L[key] or fallback
end

local function safeFormat(formatText, fallback, ...)
	if type(formatText) == "string" then
		local ok, text = pcall(string.format, formatText, ...)
		if ok and text then
			return text
		end
	end
	return string.format(fallback, ...)
end

local function localeFormat(key, fallback, ...)
	return safeFormat(localeText(key, fallback), fallback, ...)
end

local function normalizedColor(color, fallback)
	fallback = fallback or TEXT_COLOR
	if color and color.r and color.g and color.b then
		return color
	end
	return fallback
end

local function wrapColor(color, text)
	text = tostring(text or "")
	color = normalizedColor(color)
	if color.WrapTextInColorCode then
		return color:WrapTextInColorCode(text)
	end
	return string.format("|cff%02x%02x%02x%s|r",
		math.floor((color.r or 1) * 255 + 0.5),
		math.floor((color.g or 1) * 255 + 0.5),
		math.floor((color.b or 1) * 255 + 0.5),
		text)
end

local function addDoubleLine(tooltip, label, value, labelColor, valueColor)
	if not (tooltip and tooltip.AddDoubleLine) then
		return
	end
	labelColor = normalizedColor(labelColor, LABEL_COLOR)
	valueColor = normalizedColor(valueColor, TEXT_COLOR)
	tooltip:AddDoubleLine(label, value or "-", labelColor.r, labelColor.g, labelColor.b, valueColor.r, valueColor.g, valueColor.b)
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

local function currentRegionToken()
	local regionName = GetCurrentRegionName and GetCurrentRegionName()
	if type(regionName) == "string" and regionName ~= "" then
		return string.upper(regionName)
	end
	return REGION_NAME_FALLBACK[tonumber(GetCurrentRegion and GetCurrentRegion()) or 0] or "US"
end

local function isPvpActivity(memberData)
	local activityInfo = memberData and memberData.activityInfo
	return activityInfo and (activityInfo.isPvpActivity or activityInfo.isRatedPvpActivity)
end

local function isRaidActivity(memberData)
	local activityInfo = memberData and memberData.activityInfo
	if not activityInfo then
		return false
	end
	if activityInfo.categoryID == GF.CAT_RAID or activityInfo.isCurrentRaidActivity then
		return true
	end
	return (tonumber(activityInfo.maxNumPlayers) or 0) > 5 and not isPvpActivity(memberData)
end

local function ensureEncounterJournal()
	if type(EJ_GetInstanceInfo) == "function" and type(EJ_GetEncounterInfoByIndex) == "function" then
		return true
	end
	if C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
	end
	return type(EJ_GetInstanceInfo) == "function" and type(EJ_GetEncounterInfoByIndex) == "function"
end

local function getRaiderIOProvider()
	local rio = _G and _G.RaiderIO
	return rio and type(rio.GetProfile) == "function" and rio or nil
end

local function getArchonProvider()
	local archon = _G and _G.ArchonTooltip
	return archon and type(archon.GetProfile) == "function" and archon or nil
end

local function hasRaidDataProvider()
	return getRaiderIOProvider() ~= nil or getArchonProvider() ~= nil
end

local function addUniqueNumber(list, seen, value)
	value = tonumber(value)
	if value and value > 0 and not seen[value] then
		seen[value] = true
		list[#list + 1] = value
	end
end

local function addUniqueText(list, seen, value)
	value = trimText(value)
	if value and not seen[value] then
		seen[value] = true
		list[#list + 1] = value
	end
end

local function cacheJournalBoss(cache, boss)
	if not (cache and boss) then
		return
	end
	if boss.encounterID then
		cache.byEncounterID[boss.encounterID] = boss
	end
	if boss.journalEncounterID then
		cache.byEncounterID[boss.journalEncounterID] = boss
	end
	if boss.dungeonEncounterID then
		cache.byEncounterID[boss.dungeonEncounterID] = boss
	end
end

local function getJournalBossInfoByIndex(bossIndex, instanceID, useSelectedInstance)
	local ok, bossName, _, journalEncounterID, _, _, _, dungeonEncounterID
	if useSelectedInstance then
		ok, bossName, _, journalEncounterID, _, _, _, dungeonEncounterID =
			pcall(EJ_GetEncounterInfoByIndex, bossIndex)
	else
		ok, bossName, _, journalEncounterID, _, _, _, dungeonEncounterID =
			pcall(EJ_GetEncounterInfoByIndex, bossIndex, instanceID)
	end
	if not ok or not bossName then
		return nil
	end
	return bossName, tonumber(journalEncounterID), tonumber(dungeonEncounterID)
end

local function buildJournalInstanceInfo(instanceID, instanceName, instanceOrder, mapID)
	instanceID = tonumber(instanceID)
	if not instanceID then
		return nil
	end
	instanceName = trimText(instanceName)
	if not instanceName and type(EJ_GetInstanceInfo) == "function" then
		instanceName = trimText(callFirst(EJ_GetInstanceInfo, instanceID))
	end
	if not instanceName then
		return nil
	end

	local instance = {
		instanceID = instanceID,
		name = instanceName,
		mapID = tonumber(mapID),
		order = tonumber(instanceOrder) or 0,
		bosses = {},
	}
	local useSelectedInstance = false
	for bossIndex = 1, 100 do
		local bossName, journalEncounterID, dungeonEncounterID =
			getJournalBossInfoByIndex(bossIndex, instanceID, useSelectedInstance)
		if not bossName and not useSelectedInstance and type(EJ_SelectInstance) == "function" and pcall(EJ_SelectInstance, instanceID) then
			useSelectedInstance = true
			bossName, journalEncounterID, dungeonEncounterID =
				getJournalBossInfoByIndex(bossIndex, instanceID, useSelectedInstance)
		end
		if not bossName then
			break
		end
		local encounterID = journalEncounterID or dungeonEncounterID
		bossName = trimText(bossName)
		if bossName then
			instance.bosses[#instance.bosses + 1] = {
				name = bossName,
				encounterID = encounterID,
				journalEncounterID = journalEncounterID,
				dungeonEncounterID = dungeonEncounterID,
				index = bossIndex,
				order = (instance.order * 1000) + bossIndex,
				instanceID = instanceID,
				instanceName = instanceName,
			}
		end
	end
	return instance
end

local function buildJournalCache()
	local cache = {
		byInstanceID = {},
		byMapID = {},
		byEncounterID = {},
	}
	if not ensureEncounterJournal()
		or type(EJ_GetNumTiers) ~= "function"
		or type(EJ_SelectTier) ~= "function"
		or type(EJ_GetInstanceByIndex) ~= "function" then
		return cache
	end

	local previousTier = callFirst(EJ_GetCurrentTier)
	local tierCount = tonumber(callFirst(EJ_GetNumTiers)) or 0
	for tier = 1, tierCount do
		if pcall(EJ_SelectTier, tier) then
			for instanceIndex = 1, 300 do
				local ok, instanceID, instanceName, _, _, _, _, _, _, _, _, mapID =
					pcall(EJ_GetInstanceByIndex, instanceIndex, true)
				if not ok or not instanceID then
					break
				end
				local instance = buildJournalInstanceInfo(instanceID, instanceName, (tier * 1000) + instanceIndex, mapID)
				if instance then
					cache.byInstanceID[instance.instanceID] = instance
					if instance.mapID then
						cache.byMapID[instance.mapID] = instance
					end
					for i = 1, #instance.bosses do
						cacheJournalBoss(cache, instance.bosses[i])
					end
				end
			end
		end
	end
	if previousTier then
		pcall(EJ_SelectTier, previousTier)
	end
	return cache
end

local function getJournalCache()
	if journalCache == nil then
		journalCache = buildJournalCache()
	end
	return journalCache
end

local function getJournalInstanceForID(instanceID)
	instanceID = tonumber(instanceID)
	if not instanceID then
		return nil
	end
	local cache = getJournalCache()
	local instance = cache.byInstanceID[instanceID]
	if instance then
		return instance
	end
	if not ensureEncounterJournal() then
		return nil
	end
	instance = buildJournalInstanceInfo(instanceID)
	if instance then
		cache.byInstanceID[instanceID] = instance
		if instance.mapID then
			cache.byMapID[instance.mapID] = instance
		end
		for i = 1, #instance.bosses do
			cacheJournalBoss(cache, instance.bosses[i])
		end
	end
	return instance
end

local function getJournalInstanceForMapID(mapID)
	mapID = tonumber(mapID)
	if not mapID or mapID <= 0 then
		return nil
	end
	local cache = getJournalCache()
	local instance = cache.byMapID[mapID]
	if instance then
		return instance
	end
	if C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap then
		local journalInstanceID = callFirst(C_EncounterJournal.GetInstanceForGameMap, mapID)
		instance = getJournalInstanceForID(journalInstanceID)
		if instance then
			cache.byMapID[mapID] = instance
			return instance
		end
	end
	return nil
end

local function getClientActivityRaidLabel(memberData)
	local activityInfo = memberData and memberData.activityInfo
	if type(activityInfo) ~= "table" then
		return nil
	end

	local instance = getJournalInstanceForMapID(activityInfo.mapID)
	if instance and instance.name then
		return instance.name
	end

	local groupID = tonumber(activityInfo.groupFinderActivityGroupID)
	if groupID and C_LFGList and C_LFGList.GetActivityGroupInfo then
		local groupName = trimText(callFirst(C_LFGList.GetActivityGroupInfo, groupID))
		if groupName then
			return groupName
		end
	end

	return trimText(activityInfo.shortName)
		or trimText(activityInfo.fullName)
		or trimText(activityInfo.name)
end

local function raidDifficultyColor(tier)
	tier = tonumber(tier)
	if tier == 3 then
		return MYTHIC_COLOR
	end
	if tier == 2 then
		return HEROIC_COLOR
	end
	return NORMAL_COLOR
end

local function raidDifficultyLabel(tier)
	tier = tonumber(tier)
	if not tier then
		return nil
	end
	local ids = DifficultyUtil and DifficultyUtil.ID
	local difficultyIDKey = RAID_DIFFICULTY_ID_BY_TIER[tier]
	local difficultyID = difficultyIDKey and ids and ids[difficultyIDKey]
	if difficultyID and DifficultyUtil and DifficultyUtil.GetDifficultyName then
		local name = trimText(callFirst(DifficultyUtil.GetDifficultyName, difficultyID))
		if name then
			return name
		end
	end
	local localeKey = RAID_DIFFICULTY_LOCALE_KEY_BY_TIER[tier]
	return localeText(localeKey, RAID_DIFFICULTY_FALLBACK_BY_TIER[tier] or "")
end

local function collectRaiderIOMapIDs(raid)
	local values = {}
	local seen = {}
	local dungeon = type(raid) == "table" and raid.dungeon
	if type(dungeon) == "table" then
		if type(dungeon.instance_map_ids) == "table" then
			for i = 1, #dungeon.instance_map_ids do
				addUniqueNumber(values, seen, dungeon.instance_map_ids[i])
			end
		end
		addUniqueNumber(values, seen, dungeon.instance_map_id)
	end
	if type(raid) == "table" then
		addUniqueNumber(values, seen, raid.mapId)
		addUniqueNumber(values, seen, raid.mapID)
		addUniqueNumber(values, seen, raid.instance_map_id)
	end
	return values
end

local function raiderIORaidKey(raid)
	local mapIDs = collectRaiderIOMapIDs(raid)
	if #mapIDs > 0 then
		return "maps:" .. table.concat(mapIDs, ",")
	end
	return "raid:" .. tostring(type(raid) == "table" and (raid.id or raid.mapId or raid.name) or raid)
end

local function getClientRaidInfoForRaiderIO(raid)
	if type(raid) ~= "table" then
		return nil
	end
	local key = raiderIORaidKey(raid)
	local cached = raidInfoCache[key]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local instances = {}
	local seenInstances = {}
	local mapIDs = collectRaiderIOMapIDs(raid)
	for i = 1, #mapIDs do
		local instance = getJournalInstanceForMapID(mapIDs[i])
		if instance and not seenInstances[instance.instanceID] then
			seenInstances[instance.instanceID] = true
			instances[#instances + 1] = instance
		end
	end

	if #instances == 0 then
		local instance = getJournalInstanceForID(raid.id)
		if instance then
			instances[1] = instance
		end
	end

	if #instances == 0 then
		raidInfoCache[key] = false
		return nil
	end

	local names = {}
	local bosses = {}
	local seenNames = {}
	for i = 1, #instances do
		local instance = instances[i]
		addUniqueText(names, seenNames, instance.name)
		for bossIndex = 1, #instance.bosses do
			bosses[#bosses + 1] = instance.bosses[bossIndex].name
		end
	end
	if #names == 0 or #bosses == 0 then
		raidInfoCache[key] = false
		return nil
	end

	local info = {
		name = table.concat(names, " / "),
		bosses = bosses,
	}
	raidInfoCache[key] = info
	return info
end

local function getRaiderIORaidProfile(name)
	local rio = getRaiderIOProvider()
	if not rio then
		return nil
	end
	local characterName, realm = splitCharacterName(name)
	if not characterName or not realm then
		return nil
	end
	local region = string.lower(currentRegionToken() or "")
	local attempts = {
		{ characterName, realm, region },
		{ characterName, realm },
	}
	local normalizedRealm = normalizeRealm(realm)
	if normalizedRealm and normalizedRealm ~= realm then
		attempts[#attempts + 1] = { characterName, normalizedRealm, region }
		attempts[#attempts + 1] = { characterName, normalizedRealm }
	end
	attempts[#attempts + 1] = { characterName .. "-" .. realm, nil, region }

	for i = 1, #attempts do
		local args = attempts[i]
		local ok, profile = pcall(rio.GetProfile, args[1], args[2], args[3])
		local raidProfile = ok and type(profile) == "table" and profile.raidProfile
		if type(raidProfile) == "table" and raidProfile.hasRenderableData ~= false then
			return raidProfile
		end
	end
	return nil
end

local function raidBossProgressValue(progress, bossIndex)
	if type(progress) ~= "table" then
		return nil
	end
	if type(progress.killsPerBoss) == "table" then
		local count = tonumber(progress.killsPerBoss[bossIndex])
		return count and count > 0 and tostring(count) or nil
	end
	local progressCount = tonumber(progress.progressCount)
	if progressCount and progressCount >= bossIndex then
		return localeText("APPLICANT_RAID_PROGRESS_KILLED", "Killed")
	end
	return nil
end

local function collectRaiderIOSections(name)
	local raidProfile = getRaiderIORaidProfile(name)
	if not (raidProfile and type(raidProfile.progress) == "table") then
		return nil
	end

	local groups = {}
	local order = {}
	for i = 1, #raidProfile.progress do
		local progress = raidProfile.progress[i]
		if type(progress) == "table" and type(progress.raid) == "table" then
			local key = raiderIORaidKey(progress.raid)
			local group = groups[key]
			if not group then
				group = { raid = progress.raid, progress = {} }
				groups[key] = group
				order[#order + 1] = key
			end
			group.progress[#group.progress + 1] = progress
		end
	end

	local sections = {}
	for i = 1, #order do
		local group = groups[order[i]]
		local raidInfo = getClientRaidInfoForRaiderIO(group.raid)
		if raidInfo then
			local rows = {}
			for bossIndex = 1, #raidInfo.bosses do
				for progressIndex = 1, #group.progress do
					local progress = group.progress[progressIndex]
					local value = raidBossProgressValue(progress, bossIndex)
					if value then
						local tier = tonumber(progress.difficulty)
						local difficultyLabel = raidDifficultyLabel(tier)
						local label = raidInfo.bosses[bossIndex]
						if difficultyLabel and difficultyLabel ~= "" then
							label = wrapColor(raidDifficultyColor(tier), difficultyLabel) .. " " .. label
						end
						rows[#rows + 1] = { label = label, value = value }
						break
					end
				end
			end
			if #rows > 0 then
				sections[#sections + 1] = { title = raidInfo.name, rows = rows }
			end
		end
	end
	return #sections > 0 and sections or nil
end

local function getArchonProfile(name)
	local archon = getArchonProvider()
	if not archon then
		return nil
	end
	local characterName, realm = splitCharacterName(name)
	if not characterName or not realm then
		return nil
	end
	local attempts = { realm }
	local normalizedRealm = normalizeRealm(realm)
	if normalizedRealm and normalizedRealm ~= realm then
		attempts[#attempts + 1] = normalizedRealm
	end
	for i = 1, #attempts do
		local ok, profile = pcall(archon.GetProfile, characterName, attempts[i])
		if ok and type(profile) == "table" then
			return profile
		end
	end
	local rawName = trimText(name)
	if rawName and rawName ~= characterName then
		local ok, profile = pcall(archon.GetProfile, rawName)
		if ok and type(profile) == "table" then
			return profile
		end
	end
	local ok, profile = pcall(archon.GetProfile, characterName)
	if ok and type(profile) == "table" then
		return profile
	end
	return nil
end

local function addArchonEncounterIDs(ids, seen, rankings)
	if not (type(rankings) == "table" and type(rankings.encountersById) == "table") then
		return
	end
	for encounterID, encounterRanking in pairs(rankings.encountersById) do
		if type(encounterRanking) ~= "table" or not encounterRanking.isHidden then
			addUniqueNumber(ids, seen, encounterID)
		end
	end
end

local function getClientRaidInfoForArchonSection(section, fallbackName)
	if type(section) ~= "table" then
		return nil
	end
	local ids = {}
	local seenIDs = {}
	addArchonEncounterIDs(ids, seenIDs, section.anySpecRankings)
	if type(section.perSpecRankings) == "table" then
		for i = 1, #section.perSpecRankings do
			addArchonEncounterIDs(ids, seenIDs, section.perSpecRankings[i])
		end
	end
	if #ids == 0 then
		return fallbackName and { name = fallbackName } or nil
	end

	local cache = getJournalCache()
	local names = {}
	local seenNames = {}
	for i = 1, #ids do
		local boss = cache.byEncounterID[ids[i]]
		if boss then
			addUniqueText(names, seenNames, boss.instanceName)
		end
	end
	if #names > 0 then
		return { name = table.concat(names, " / ") }
	end
	return fallbackName and { name = fallbackName } or nil
end

local function formatPercentile(value)
	value = tonumber(value)
	if not value or value <= 0 then
		return "-"
	end
	if value == math.floor(value) then
		return tostring(value)
	end
	return string.format("%.1f", value)
end

local function archonDifficultyLabel(difficultyID)
	local tier = ARCHON_DIFFICULTY_TIER_BY_ID[tonumber(difficultyID) or 0]
	return raidDifficultyLabel(tier), tier
end

local function buildArchonSummaryRow(data, raidName)
	if type(data) ~= "table" then
		return nil
	end
	raidName = trimText(raidName)
	local killed = tonumber(data.progressKilled)
	local possible = tonumber(data.progressPossible)
	if not (raidName and killed and possible and possible > 0) then
		return nil
	end

	local difficultyLabel, tier = archonDifficultyLabel(data.difficultyId)
	local label = raidName
	if difficultyLabel and difficultyLabel ~= "" then
		label = wrapColor(raidDifficultyColor(tier), difficultyLabel) .. " " .. label
	end
	local progressText = string.format("%d/%d%s", killed, possible, difficultyLabel or "")
	local killsText = localeFormat("APPLICANT_RAID_KILLS_FMT", "%d Kills", tonumber(data.totalKills) or 0)
	local bestAverage = tonumber(data.bestAverage)
	local value
	if bestAverage and bestAverage > 0 then
		value = string.format("%s  %s  %s", formatPercentile(bestAverage), progressText, killsText)
	else
		value = string.format("%s  %s", progressText, killsText)
	end
	return { label = label, value = value }
end

local function collectArchonSections(name, memberData)
	local profile = getArchonProfile(name)
	if not profile then
		return nil
	end

	local sections = {}
	local fallbackName = getClientActivityRaidLabel(memberData)
	if type(profile.sections) == "table" then
		for i = 1, #profile.sections do
			local section = profile.sections[i]
			local raidInfo = getClientRaidInfoForArchonSection(section, fallbackName)
			local rankings = type(section) == "table" and section.anySpecRankings
			local row = raidInfo and buildArchonSummaryRow({
				difficultyId = section.difficultyId,
				progressKilled = rankings and rankings.progressKilled,
				progressPossible = rankings and rankings.progressPossible,
				totalKills = section.totalKills,
				bestAverage = rankings and rankings.bestAverage,
			}, raidInfo.name)
			if row then
				sections[#sections + 1] = row
				if #sections >= MAX_WCL_SECTIONS then
					break
				end
			end
		end
	end

	if #sections == 0 then
		local row = buildArchonSummaryRow(profile.summary, fallbackName)
		if row then
			sections[#sections + 1] = row
		end
	end
	if #sections < MAX_WCL_SECTIONS then
		local row = buildArchonSummaryRow(profile.mainCharacter, fallbackName)
		if row then
			sections[#sections + 1] = row
		end
	end

	return #sections > 0 and sections or nil
end

local function renderRaiderIO(tooltip, sections)
	if not (sections and #sections > 0 and tooltip) then
		return false
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(localeText("APPLICANT_RAID_PROGRESS_TITLE", "Raid Progress"), LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, true)
	for i = 1, #sections do
		local section = sections[i]
		if section.title and section.title ~= "" then
			tooltip:AddLine(section.title, LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, true)
		end
		for rowIndex = 1, #section.rows do
			local row = section.rows[rowIndex]
			addDoubleLine(tooltip, row.label, row.value, TEXT_COLOR, TEXT_COLOR)
		end
	end
	return true
end

local function renderArchon(tooltip, sections)
	if not (sections and #sections > 0 and tooltip) then
		return false
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(localeText("APPLICANT_WCL_PROGRESS_TITLE", "Warcraft Logs"), WCL_COLOR.r, WCL_COLOR.g, WCL_COLOR.b, true)
	for i = 1, #sections do
		local section = sections[i]
		addDoubleLine(tooltip, section.label, section.value, TEXT_COLOR, TEXT_COLOR)
	end
	return true
end

local function renderProviderNoData(tooltip)
	if not tooltip then
		return false
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(localeText("APPLICANT_RAID_PROGRESS_TITLE", "Raid Progress"), LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, true)
	tooltip:AddLine(localeText("APPLICANT_RAID_PROGRESS_NO_DATA", "No local raid progress data available"), GRAY_COLOR.r, GRAY_COLOR.g, GRAY_COLOR.b, true)
	return true
end

function ART.Append(tooltip, memberData)
	if not (tooltip and memberData and isRaidActivity(memberData)) then
		return false
	end
	local name = memberData.name or memberData.displayName
	if not name or name == "" then
		return false
	end

	local hasProvider = hasRaidDataProvider()
	local shown = false
	shown = renderRaiderIO(tooltip, collectRaiderIOSections(name)) or shown
	shown = renderArchon(tooltip, collectArchonSections(name, memberData)) or shown
	if not shown and hasProvider then
		shown = renderProviderNoData(tooltip)
	end
	return shown
end
