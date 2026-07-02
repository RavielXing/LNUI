local _, GF = ...

GF.ListFilter = {}

local LF = GF.ListFilter
local FS = GF.FilterSpec

local BLOODLUST_CLASS = {
	MAGE = true,
	SHAMAN = true,
	EVOKER = true,
	HUNTER = true,
}

local SAME_CLASS_CATS = {
	[GF.CAT_DUNGEON] = true,
	[GF.CAT_DELVE] = true,
	[GF.CAT_RAID] = true,
}

function GF.HasBloodlustClass(classFile)
	return classFile and BLOODLUST_CLASS[classFile] == true
end

local function toCountNumber(v)
	if v == nil then
		return nil
	end
	if issecretvalue and issecretvalue(v) then
		return nil
	end
	return tonumber(v)
end

local function pcallFirst(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

local function getSearchResultInfo(resultID)
	return pcallFirst(C_LFGList and C_LFGList.GetSearchResultInfo, resultID)
end

local function getActivityInfoForResult(info, activityID)
	return pcallFirst(C_LFGList and C_LFGList.GetActivityInfoTable, activityID, info and info.questID, info and info.isWarMode)
end

local function getPlayerRole(playerInfo)
	return playerInfo and (playerInfo.assignedRole or playerInfo.role)
end

local function getPlayerClass(playerInfo)
	local classFile = playerInfo and (playerInfo.classFilename or playerInfo.classFileName or playerInfo.classFile)
	if type(classFile) == "string" and classFile ~= "" then
		return classFile:upper()
	end
	return nil
end

local function fetchSearchResultPlayers(resultID, info, entry)
	local players = entry and entry.players
	local expectedRaw = toCountNumber(info and info.numMembers)
	local expected = math.max(0, math.floor((expectedRaw or 0) + 0.0001))
	local expectedKnown = expectedRaw ~= nil
	if type(players) == "table" then
		return players, #players > 0, expectedKnown and (expected <= 0 or #players >= expected)
	end
	if not expectedKnown or not resultID or not (C_LFGList and C_LFGList.GetSearchResultPlayerInfo) then
		return nil, false, false
	end
	players = {}
	for i = 1, expected do
		local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
		if ok and playerInfo then
			players[#players + 1] = playerInfo
		end
	end
	return players, #players > 0, expected <= 0 or #players == expected
end

local function resultHasBloodlust(resultID, info, entry)
	local players, loaded, complete = fetchSearchResultPlayers(resultID, info, entry)
	if not loaded then
		return nil
	end
	for _, playerInfo in ipairs(players) do
		if GF.HasBloodlustClass(getPlayerClass(playerInfo)) then
			return true
		end
	end
	if complete then
		return false
	end
	return nil
end

local ROLE_RANGE_DEFS = {
	{ show = "showTankRange", min = "rangeTankMin", en = "rangeTankEn", remaining = "TANK_REMAINING" },
	{ show = "showHealRange", min = "rangeHealMin", en = "rangeHealEn", remaining = "HEALER_REMAINING" },
	{ show = "showDpsRange", min = "rangeDpsMin", en = "rangeDpsEn", remaining = "DAMAGER_REMAINING" },
}

local function inRange(val, minV, maxV)
	val = toCountNumber(val)
	minV = toCountNumber(minV) or 0
	maxV = toCountNumber(maxV) or 0
	if val == nil then
		return true
	end
	if minV > 0 and val < minV then
		return false
	end
	if maxV > 0 and val > maxV then
		return false
	end
	return true
end

local function roleVacancyMeetsThreshold(val, threshold)
	val = toCountNumber(val)
	local minThreshold = GF.ROLE_VACANCY_THRESHOLD_MIN or 1
	local maxThreshold = GF.ROLE_VACANCY_THRESHOLD_MAX or 4
	threshold = math.floor((toCountNumber(threshold) or minThreshold) + 0.0001)
	if threshold < minThreshold then
		threshold = minThreshold
	elseif threshold > maxThreshold then
		threshold = maxThreshold
	end
	if val == nil then
		return true
	end
	if val < threshold then
		return false
	end
	return true
end

local function isClientFilterEnabled(client, key)
	return client and (client[key] == true or client[key] == 1)
end

local function getCompletedEncounterCount(resultID)
	if not C_LFGList or not C_LFGList.GetSearchResultEncounterInfo then
		return nil
	end
	local ok, encounters = pcall(C_LFGList.GetSearchResultEncounterInfo, resultID)
	if not ok then
		return nil
	end
	if encounters == nil then
		return 0
	end
	if type(encounters) ~= "table" then
		return nil
	end
	return #encounters
end

local function fetchMemberCounts(resultID, info, entry)
	if entry and entry._displayCountsLoaded and type(entry._displayCounts) == "table" then
		return entry._displayCounts
	end
	if not C_LFGList or not C_LFGList.GetSearchResultMemberCounts then
		return nil
	end
	local hasInfo = pcallFirst(C_LFGList.HasSearchResultInfo, resultID)
	if hasInfo == false then
		if not info and C_LFGList.GetSearchResultInfo then
			info = getSearchResultInfo(resultID)
		end
		if not info then
			return nil
		end
	end
	local counts = pcallFirst(C_LFGList.GetSearchResultMemberCounts, resultID)
	if type(counts) ~= "table" then
		return nil
	end
	if entry then
		entry._displayCounts = counts
		entry._displayCountsLoaded = true
		entry.tanks = counts.TANK or entry.tanks or 0
		entry.heals = counts.HEALER or entry.heals or 0
		entry.dps = counts.DAMAGER or entry.dps or 0
	end
	return counts
end

local function getRolePresenceFromPlayers(resultID, info, entry)
	local out = {
		TANK = false,
		HEALER = false,
		loaded = false,
		complete = false,
	}
	local players, loaded, complete = fetchSearchResultPlayers(resultID, info, entry)
	if not loaded then
		return out
	end
	out.loaded = loaded
	out.complete = complete
	for _, playerInfo in ipairs(players) do
		local role = getPlayerRole(playerInfo)
		if role == "TANK" then
			out.TANK = true
		elseif role == "HEALER" then
			out.HEALER = true
		end
	end
	return out
end

local function hasRole(counts, rolePresence, role)
	if rolePresence and rolePresence.loaded then
		if rolePresence[role] == true then
			return true
		end
		if rolePresence.complete then
			return false
		end
	end
	local count = toCountNumber(counts and counts[role])
	if count == nil then
		return nil
	end
	return count > 0
end

local function roleRangeEnabled(client, enKey)
	if FS and FS.IsRoleRangeEnabled then
		return FS:IsRoleRangeEnabled(client, enKey)
	end
	return client and (client[enKey] == true or client[enKey] == 1)
end

local function normalizeRealmName(realm)
	if type(realm) ~= "string" or realm == "" then
		return nil
	end
	realm = realm:gsub("%s+", "")
	if realm ~= "" then
		return realm
	end
	return nil
end

local function getCurrentRealmName()
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	realm = normalizeRealmName(realm)
	if realm then
		return realm
	end
	return normalizeRealmName(GetRealmName and GetRealmName())
end

local function getNameRealm(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local _, realm = name:match("^([^-]+)%-(.+)$")
	return normalizeRealmName(realm)
end

local function isCrossRealmListing(info, entry)
	local leaderName = info and info.leaderName
	if (not leaderName or leaderName == "") and entry and entry.leader then
		leaderName = entry.leader.name
	end
	local leaderRealm = getNameRealm(leaderName)
	if not leaderRealm then
		return false
	end
	local playerRealm = getCurrentRealmName()
	if not playerRealm then
		return false
	end
	return leaderRealm ~= playerRealm
end

local function needsMemberCounts(client, spec)
	if not client or not spec then
		return false
	end
	if client.matchMyRole and spec.showMatchRole then
		return true
	end
	if spec.hasTankHealClient and (client.hasTank or client.hasHeal or client.alreadyHasTank or client.alreadyHasHeal) then
		return true
	end
	for _, def in ipairs(ROLE_RANGE_DEFS) do
		if spec[def.show] and roleRangeEnabled(client, def.en) then
			return true
		end
	end
	return false
end

local function checkRemainingRanges(counts, client, spec)
	if not counts or not client then
		return true
	end
	for _, def in ipairs(ROLE_RANGE_DEFS) do
		if spec[def.show] and roleRangeEnabled(client, def.en) then
			if not roleVacancyMeetsThreshold(counts[def.remaining], client[def.min]) then
				return false
			end
		end
	end
	return true
end

local function resolveLocalSpecRole()
	local specIndex = GetSpecialization and GetSpecialization()
	if not specIndex then
		return nil
	end
	if GetSpecializationRole then
		return GetSpecializationRole(specIndex)
	end
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole then
		return C_SpecializationInfo.GetSpecializationRole(specIndex)
	end
	return nil
end

local ROLE_REMAINING_KEY = {
	TANK = "TANK_REMAINING",
	HEALER = "HEALER_REMAINING",
	DAMAGER = "DAMAGER_REMAINING",
}

local function isRoleAvailable(role)
	if not C_LFGList or not C_LFGList.GetAvailableRoles then
		return true
	end
	local ok, wantTank, wantHeal, wantDps = pcall(C_LFGList.GetAvailableRoles)
	if not ok then
		return true
	end
	if role == "TANK" then
		return wantTank == true
	end
	if role == "HEALER" then
		return wantHeal == true
	end
	if role == "DAMAGER" then
		return wantDps == true
	end
	return true
end

local function checkMatchMyRole(counts)
	if not counts then
		return true
	end
	local role = resolveLocalSpecRole()
	if not role then
		return true
	end
	if not isRoleAvailable(role) then
		return false
	end
	local key = ROLE_REMAINING_KEY[role]
	if not key then
		return true
	end
	local remaining = toCountNumber(counts[key])
	if remaining == nil then
		return true
	end
	return remaining > 0
end

local function checkNeedsMyClass(resultID, info, entry, counts)
	local role = resolveLocalSpecRole()
	local _, myClass = UnitClass("player")
	if not role or not myClass then
		return true
	end
	myClass = myClass:upper()
	if not isRoleAvailable(role) then
		return false
	end
	counts = counts or fetchMemberCounts(resultID, info, entry)
	if not counts then
		return true
	end
	local key = ROLE_REMAINING_KEY[role]
	if not key then
		return true
	end
	local remaining = toCountNumber(counts[key])
	if remaining == nil then
		return true
	end
	if remaining <= 0 then
		return false
	end
	if role ~= "DAMAGER" then
		return true
	end

	local players, loaded = fetchSearchResultPlayers(resultID, info, entry)
	if not loaded then
		return true
	end
	for _, playerInfo in ipairs(players) do
		if getPlayerRole(playerInfo) == "DAMAGER" and getPlayerClass(playerInfo) == myClass then
			return false
		end
	end
	return true
end

local function isDeclinedStatus(status)
	return status == "declined" or status == "declined_full" or status == "declined_delisted"
end

local function resolveActivityDifficultyTier(activity)
	return GF.ActivityInfo and GF.ActivityInfo.GetDifficultyTier(activity, { includeMplus = true }) or nil
end

local function activityMatchesDifficulty(activity, normal, heroic, mythic, mplus)
	if not normal and not heroic and not mythic and not mplus then
		return true
	end
	local tier = resolveActivityDifficultyTier(activity)
	if not tier then
		return false
	end
	if tier == "normal" then
		return normal
	end
	if tier == "heroic" then
		return heroic
	end
	if tier == "mythic" then
		return mythic
	end
	if tier == "mplus" then
		return mplus
	end
	return false
end

local function addResultActivityID(out, seen, activityID)
	activityID = tonumber(activityID)
	if activityID and activityID > 0 and not seen[activityID] then
		seen[activityID] = true
		out[#out + 1] = activityID
	end
end

local function collectResultActivityIDs(info, entry)
	local out = {}
	local seen = {}
	if info then
		addResultActivityID(out, seen, info.activityID)
		if type(info.activityIDs) == "table" then
			for _, activityID in ipairs(info.activityIDs) do
				addResultActivityID(out, seen, activityID)
			end
		end
	end
	if entry and entry.activityID then
		addResultActivityID(out, seen, entry.activityID)
	end
	return out
end

function LF:IsEnabled()
	return GF.GetDB().moduleListFilter ~= false
end

function LF:ShouldShowResult(resultID, entry, spec, client, db, info)
	info = info or (entry and entry.info) or getSearchResultInfo(resultID)
	if not info then
		return false
	end

	if not self:IsEnabled() then
		return true
	end

	if not spec and GF.FilterSpec and GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		spec = GF.FilterSpec:ResolveSpec(GF.FindGroupTab:GetSelection())
	end
	db = db or (GF.Filter and GF.Filter.GetGlobalFilters and GF.Filter:GetGlobalFilters(spec)) or GF.GetDB()

	if GF.Filter and not GF.Filter:MatchesPlaystyleFilter(db, info.generalPlaystyle) then
		return false
	end

	if spec and spec.showDungeonActivities and GF.Filter then
		local dungeonItems = GF.Filter.GetDungeonActivityItems and GF.Filter:GetDungeonActivityItems()
		if not GF.Filter:HasActiveDungeonActivityFilter(nil, dungeonItems) then
			dungeonItems = nil
		end
		if dungeonItems then
			if not GF.Filter:MatchesDungeonActivityFilter(nil, collectResultActivityIDs(info, entry), dungeonItems) then
				return false
			end
		end
	end

	if spec and spec.showRaidActivities and GF.Filter then
		local raidItems = GF.Filter.GetRaidActivityItems and GF.Filter:GetRaidActivityItems()
		if not GF.Filter:HasActiveRaidActivityFilter(nil, raidItems) then
			raidItems = nil
		end
		if raidItems then
			if not GF.Filter:MatchesRaidActivityFilter(nil, collectResultActivityIDs(info, entry), raidItems) then
				return false
			end
		end
	end

	if not spec then
		return true
	end

	local categoryID = entry and entry.categoryID
	local activity = entry and entry.activity
	if not categoryID and info.activityIDs and info.activityIDs[1] then
		activity = getActivityInfoForResult(info, info.activityIDs[1])
		categoryID = activity and activity.categoryID
	end

	-- 全局
	if spec.runGlobalClient then
		if db.zeroScore then
			local score = info.leaderOverallDungeonScore or 0
			if score < 1 then
				return false
			end
		end
		if db.rangeAgeEn then
			local ageMin = (info.age or 0) / 60
			if not inRange(ageMin, db.rangeAgeMin, db.rangeAgeMax) then
				return false
			end
		elseif db.maxAgeMin and db.maxAgeMin > 0 then
			if (info.age or 0) > db.maxAgeMin * 60 then
				return false
			end
		end
		if db.rangeIlvlEn then
			if not inRange(info.requiredItemLevel or 0, db.rangeIlvlMin, db.rangeIlvlMax) then
				return false
			end
		elseif db.minIlvl and db.minIlvl > 0 then
			if (info.requiredItemLevel or 0) > db.minIlvl then
				return false
			end
		end
		if db.rangeHonorEn and spec.showMinHonor then
			if not inRange(info.requiredHonorLevel or 0, db.rangeHonorMin, db.rangeHonorMax) then
				return false
			end
		end
		if db.hideVoice and (info.voiceChat or "") ~= "" then
			return false
		end
		if db.hideCrossRealm and isCrossRealmListing(info, entry) then
			return false
		end
		if db.sameFactionOnly and info.crossFactionListing == true then
			return false
		end
		if db.showFriendGroups == false and GF.FindGroup and GF.FindGroup:IsFriendListing(info, resultID) then
			return false
		end
		if db.showGuildGroups == false and GF.FindGroup and GF.FindGroup:IsGuildListing(info, resultID) then
			return false
		end
		if db.showHousewarmingGroups == false and GF.ACTIVITY_HOUSEWARMING then
			local actID = info.activityIDs and info.activityIDs[1]
			if actID == GF.ACTIVITY_HOUSEWARMING then
				return false
			end
		end
		if db.rangeMplusScoreEn then
			local score = info.leaderOverallDungeonScore or 0
			if not inRange(score, db.rangeMplusScoreMin, db.rangeMplusScoreMax) then
				return false
			end
		end
	end

	if not spec.runCategoryClient then
		if spec.runGlobalClient and db.sameClass and SAME_CLASS_CATS[categoryID] then
			return self:CheckSameClass(resultID, categoryID)
		end
		return true
	end

	client = client or GF.Filter:GetClientFilters(spec.clientKey)

	local counts
	if needsMemberCounts(client, spec) then
		counts = fetchMemberCounts(resultID, info, entry)
	end

	if counts and not checkRemainingRanges(counts, client, spec) then
		return false
	end

	if client.matchMyRole and spec.showMatchRole then
		if not checkMatchMyRole(counts) then
			return false
		end
	end

	if spec.showRaidMemberCount and isClientFilterEnabled(client, "raidMemberCountEn") then
		if not inRange(info.numMembers, client.raidMemberCountMin, client.raidMemberCountMax) then
			return false
		end
	end

	if spec.showRaidBossKills and isClientFilterEnabled(client, "raidBossKillsEn") then
		local completedEncounters = getCompletedEncounterCount(resultID)
		if not inRange(completedEncounters, client.raidBossKillsMin, client.raidBossKillsMax) then
			return false
		end
	end

	if client.notDeclined and spec.showNotDeclined and C_LFGList and C_LFGList.GetApplicationInfo then
		local skipDeclinedCheck = GF.Apply and GF.Apply.IsFreshReject
			and GF.Apply:IsFreshReject(resultID)
		if not skipDeclinedCheck then
			local ok, _, appStatus = pcall(C_LFGList.GetApplicationInfo, resultID)
			if not ok then
				appStatus = nil
			end
			if isDeclinedStatus(appStatus) then
				return false
			end
		end
	end

	local blMode = client.bloodlustMode or 0
	if blMode > 0 and spec.showBloodlust then
		local targetBL = resultHasBloodlust(resultID, info, entry)
		if blMode == 1 and targetBL == false then
			return false
		elseif blMode == 2 and targetBL == true then
			return false
		end
	end

	if spec.hasTankHealClient then
		local rolePresence = getRolePresenceFromPlayers(resultID, info, entry)
		local tankPresent = hasRole(counts, rolePresence, "TANK")
		local healerPresent = hasRole(counts, rolePresence, "HEALER")
		if client.hasTank and tankPresent == true then
			return false
		end
		if client.hasHeal and healerPresent == true then
			return false
		end
		if client.alreadyHasTank then
			if tankPresent == false then
				return false
			end
		end
		if client.alreadyHasHeal then
			if healerPresent == false then
				return false
			end
		end
	end

	if client.needsMyClass and spec.showNeedsMyClass then
		if not checkNeedsMyClass(resultID, info, entry, counts) then
			return false
		end
	end

	if spec.showDungeonDifficulty and client.dungeonDiffEn then
		if not activityMatchesDifficulty(activity,
			client.dungeonDifficultyNormal,
			client.dungeonDifficultyHeroic,
			client.dungeonDifficultyMythic,
			client.dungeonDifficultyMythicPlus) then
			return false
		end
	end

	if spec.showRaidDifficulty and client.raidDiffEn then
		if not activityMatchesDifficulty(activity,
			client.raidDifficultyNormal,
			client.raidDifficultyHeroic,
			client.raidDifficultyMythic,
			false) then
			return false
		end
	end

	if client.warmodeOnly and spec.showWarmode then
		if info.isWarMode ~= true then
			return false
		end
	end

	if db.sameClass and spec.showSameClass and SAME_CLASS_CATS[categoryID] then
		if not self:CheckSameClass(resultID, categoryID) then
			return false
		end
	end

	return true
end

function LF:CheckSameClass(resultID, categoryID)
	if not SAME_CLASS_CATS[categoryID] then
		return true
	end
	local _, myClass = UnitClass("player")
	if not myClass then
		return true
	end
	myClass = myClass:upper()
	local info = getSearchResultInfo(resultID)
	if not info then
		return true
	end
	local players, loaded = fetchSearchResultPlayers(resultID, info)
	if not loaded then
		return true
	end
	for _, playerInfo in ipairs(players) do
		if getPlayerRole(playerInfo) == "DAMAGER" and getPlayerClass(playerInfo) == myClass then
			return false
		end
	end
	return true
end

function LF:NeedsPostFilters(spec, client, db)
	if GF.FilterSpec then
		return GF.FilterSpec:NeedsPostFilter(spec, client, db)
	end
	return false
end
