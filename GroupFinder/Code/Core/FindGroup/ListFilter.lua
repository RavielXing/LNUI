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

local function resultHasBloodlust(resultID, numMembers)
	if not C_LFGList.GetSearchResultMemberInfo then
		return false
	end
	for i = 1, numMembers or 0 do
		local ok, _, class = pcall(C_LFGList.GetSearchResultMemberInfo, resultID, i)
		if ok and GF.HasBloodlustClass(class) then
			return true
		end
	end
	return false
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

local function fetchMemberCounts(resultID, info)
	if not C_LFGList or not C_LFGList.GetSearchResultMemberCounts then
		return nil
	end
	if C_LFGList.HasSearchResultInfo and not C_LFGList.HasSearchResultInfo(resultID) then
		if not info and C_LFGList.GetSearchResultInfo then
			info = C_LFGList.GetSearchResultInfo(resultID)
		end
		if not info then
			return nil
		end
	end
	local counts = C_LFGList.GetSearchResultMemberCounts(resultID)
	if type(counts) ~= "table" then
		return nil
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
	local players = entry and entry.players
	local expected = info and info.numMembers or 0
	if type(players) ~= "table" and resultID and C_LFGList and C_LFGList.GetSearchResultPlayerInfo then
		players = {}
		for i = 1, expected do
			local ok, playerInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
			if ok and playerInfo then
				players[#players + 1] = playerInfo
			end
		end
	end
	if type(players) ~= "table" then
		return out
	end
	out.loaded = #players > 0
	out.complete = expected <= 0 or #players == expected
	for _, playerInfo in ipairs(players) do
		local role = playerInfo and playerInfo.assignedRole
		if role == "TANK" then
			out.TANK = true
		elseif role == "HEALER" then
			out.HEALER = true
		end
	end
	return out
end

local function hasRole(counts, rolePresence, role)
	if rolePresence and rolePresence.loaded and rolePresence.complete then
		return rolePresence[role] == true
	end
	return (toCountNumber(counts and counts[role]) or 0) > 0
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

local function checkMatchMyRole(counts)
	if not counts then
		return true
	end
	local role = resolveLocalSpecRole()
	if not role then
		return true
	end
	if C_LFGList.GetAvailableRoles then
		local wantTank, wantHeal, wantDps = C_LFGList.GetAvailableRoles()
		if role == "TANK" and not wantTank then
			return false
		end
		if role == "HEALER" and not wantHeal then
			return false
		end
		if role == "DAMAGER" and not wantDps then
			return false
		end
	end
	local key = role == "TANK" and "TANK_REMAINING"
		or role == "HEALER" and "HEALER_REMAINING"
		or role == "DAMAGER" and "DAMAGER_REMAINING"
	if not key then
		return true
	end
	local remaining = toCountNumber(counts[key])
	if remaining == nil then
		return true
	end
	return remaining > 0
end

local function isDeclinedStatus(status)
	return status == "declined" or status == "declined_full" or status == "declined_delisted"
end

local function resolveActivityDifficultyTier(activity)
	if not activity then
		return nil
	end
	if activity.isMythicPlusActivity then
		return "mplus"
	end
	if activity.isMythicActivity then
		return "mythic"
	end
	if activity.isHeroicActivity then
		return "heroic"
	end
	if activity.isNormalActivity then
		return "normal"
	end
	local name = activity.fullName or activity.shortName or ""
	if name == "" then
		return nil
	end
	if name:find("钥石", 1, true) or name:find("Keystone", 1, true) or name:find("Mythic%+", 1, true) then
		return "mplus"
	end
	if name:find("（史诗）", 1, true) or name:find("(Mythic)", 1, true) or name:find("(史诗)", 1, true)
		or (name:find("史诗", 1, true) and not name:find("钥石", 1, true)) then
		return "mythic"
	end
	if name:find("（英雄）", 1, true) or name:find("(Heroic)", 1, true) or name:find("(英雄)", 1, true)
		or name:find("英雄", 1, true) then
		return "heroic"
	end
	if name:find("（普通）", 1, true) or name:find("(Normal)", 1, true) or name:find("(普通)", 1, true)
		or name:find("普通", 1, true) then
		return "normal"
	end
	return nil
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

local function checkNeedsMyClass(resultID, info)
	if not info or not C_LFGList.GetAvailableRoles then
		return true
	end
	local wantTank, wantHeal, wantDps = C_LFGList.GetAvailableRoles()
	local _, myClass = UnitClass("player")
	if not myClass then
		return true
	end
	local counts = fetchMemberCounts(resultID, info)
	if wantTank and counts and (toCountNumber(counts.TANK_REMAINING) or 0) > 0 then
		return true
	end
	if wantHeal and counts and (toCountNumber(counts.HEALER_REMAINING) or 0) > 0 then
		return true
	end
	if wantDps and counts and (toCountNumber(counts.DAMAGER_REMAINING) or 0) > 0 then
		if C_LFGList.GetSearchResultMemberInfo then
			for i = 1, info.numMembers or 0 do
				local ok, role, class = pcall(C_LFGList.GetSearchResultMemberInfo, resultID, i)
				if ok and role == "DAMAGER" and class == myClass then
					return false
				end
			end
		end
		return true
	end
	return false
end

function LF:IsEnabled()
	return GF.GetDB().moduleListFilter ~= false
end

function LF:ShouldShowResult(resultID, entry, spec, client, db, info)
	db = db or GF.GetDB()
	info = info or (entry and entry.info) or (C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(resultID))
	if not info then
		return false
	end

	if not self:IsEnabled() then
		return true
	end

	if GF.Filter and not GF.Filter:MatchesPlaystyleFilter(db, info.generalPlaystyle) then
		return false
	end

	if not spec and GF.FilterSpec and GF.FindGroupTab and GF.FindGroupTab.GetSelection then
		spec = GF.FilterSpec:ResolveSpec(GF.FindGroupTab:GetSelection())
	end

	if spec and spec.showDungeonActivities and GF.Filter and GF.Filter:HasActiveDungeonActivityFilter(db) then
		local act = entry and entry.activity
		if not act and info.activityIDs and info.activityIDs[1] then
			act = C_LFGList.GetActivityInfoTable(info.activityIDs[1], info.questID, info.isWarMode)
		end
		local groupID = act and act.groupFinderActivityGroupID
		if not GF.Filter:MatchesDungeonActivityFilter(db, groupID) then
			return false
		end
	end

	if spec and spec.showRaidActivities and GF.Filter and GF.Filter:HasActiveRaidActivityFilter(db) then
		local act = entry and entry.activity
		if not act and info.activityIDs and info.activityIDs[1] then
			act = C_LFGList.GetActivityInfoTable(info.activityIDs[1], info.questID, info.isWarMode)
		end
		local groupID = act and act.groupFinderActivityGroupID
		if not GF.Filter:MatchesRaidActivityFilter(db, groupID) then
			return false
		end
	end

	if not spec then
		return true
	end

	local categoryID = entry and entry.categoryID
	local activity = entry and entry.activity
	if not categoryID and info.activityIDs and info.activityIDs[1] then
		activity = C_LFGList.GetActivityInfoTable(info.activityIDs[1], info.questID, info.isWarMode)
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
		if db.showFriendGroups == false and info.isFriendListing then
			return false
		end
		if db.showGuildGroups == false and info.isGuildListing then
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
		counts = fetchMemberCounts(resultID, info)
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

	if client.notDeclined and spec.showNotDeclined and C_LFGList.GetApplicationInfo then
		local skipDeclinedCheck = GF.Apply and GF.Apply.IsFreshReject
			and GF.Apply:IsFreshReject(resultID)
		if not skipDeclinedCheck then
			local _, appStatus = C_LFGList.GetApplicationInfo(resultID)
			if isDeclinedStatus(appStatus) then
				return false
			end
		end
	end

	local blMode = client.bloodlustMode or 0
	if blMode > 0 and spec.showBloodlust then
		local targetBL = resultHasBloodlust(resultID, info.numMembers)
		if blMode == 1 and not targetBL then
			return false
		elseif blMode == 2 and targetBL then
			return false
		end
	end

	if spec.hasTankHealClient then
		local rolePresence = getRolePresenceFromPlayers(resultID, info, entry)
		local tankPresent = hasRole(counts, rolePresence, "TANK")
		local healerPresent = hasRole(counts, rolePresence, "HEALER")
		if client.hasTank and tankPresent then
			return false
		end
		if client.hasHeal and healerPresent then
			return false
		end
		if client.alreadyHasTank then
			if not tankPresent then
				return false
			end
		end
		if client.alreadyHasHeal then
			if not healerPresent then
				return false
			end
		end
	end

	if client.needsMyClass and spec.showNeedsMyClass then
		if not checkNeedsMyClass(resultID, info) then
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
	if not myClass or not C_LFGList.GetSearchResultMemberInfo then
		return true
	end
	local info = C_LFGList.GetSearchResultInfo(resultID)
	if not info then
		return true
	end
	for i = 1, info.numMembers or 0 do
		local ok, role, class = pcall(C_LFGList.GetSearchResultMemberInfo, resultID, i)
		if ok and role == "DAMAGER" and class == myClass then
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
