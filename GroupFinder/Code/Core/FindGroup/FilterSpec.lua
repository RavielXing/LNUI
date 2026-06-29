local _, GF = ...

GF.FilterSpec = {}

local FS = GF.FilterSpec

-- Nav 矩阵列 1–8 → 各过滤项是否加载（true=加载；全局项由 DB 顶层处理）
local MATRIX = {
	{ diff_dungeon = true, tank = true, heal = true, dps = true, matchRole = true, bloodlust = true, notDeclined = true, needsMyClass = true, hasTankHeal = true, dungeonAct = true, sameClass = true },
	{ diff_dungeon = true, tank = true, heal = true, dps = true, notDeclined = true, sameClass = true, hasTankHeal = true, bloodlust = true },
	{ delveAct = true, sameClass = true, tank = true, heal = true, dps = true, hasTankHeal = true },
	{ diff_raid = true, raidAct = true, sameClass = true, raidMemberCount = true, raidBossKills = true },
	{ minHonor = true },
	{ sameClass = true },
	{ warmode = true },
	{ warmode = true },
}

local function band(f, flag)
	return f and bit.band(f, flag) ~= 0
end

function FS:IsSeasonDungeon(selection)
	if not selection or selection.categoryID ~= GF.CAT_DUNGEON then
		return false
	end
	if selection.navKind == "season_dungeon" then
		return true
	end
	local f = selection.filters or 0
	if band(f, Enum.LFGListFilter.NotCurrentSeason) then
		return false
	end
	return band(f, Enum.LFGListFilter.CurrentSeason) or band(f, Enum.LFGListFilter.Timerunning)
end

function FS:IsSeasonRaid(selection)
	if not selection or selection.categoryID ~= GF.CAT_RAID then
		return false
	end
	return selection.navKind == "season_raid"
end

function FS:GetLayoutTier(selection)
	if not selection or not selection.categoryID then
		return "default"
	end
	if selection.categoryID == GF.CAT_DUNGEON then
		if IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel() then
			return self:IsSeasonDungeon(selection) and "api_max" or "nav2"
		end
		return "submax"
	end
	return "default"
end

function FS:GetNavColumn(selection)
	if not selection or not selection.categoryID then
		return 0
	end
	local tier = self:GetLayoutTier(selection)
	local cat = selection.categoryID
	if cat == GF.CAT_DUNGEON then
		if tier == "api_max" then
			return 1
		end
		if tier == "nav2" then
			return 2
		end
		return 0
	end
	if cat == GF.CAT_DELVE then
		return 3
	end
	if cat == GF.CAT_RAID then
		return 4
	end
	if cat == GF.CAT_QUEST then
		return 6
	end
	if cat == GF.CAT_CUSTOM then
		if selection.preferredFilters == Enum.LFGListFilter.PvP then
			return 8
		end
		return 7
	end
	for _, pvp in ipairs(GF.PVP_CATEGORIES or {}) do
		if cat == pvp.id then
			return 5
		end
	end
	return 0
end

function FS:GetClientFilterKey(selection)
	if not selection or not selection.categoryID then
		return "0"
	end
	if selection.categoryID == GF.CAT_CUSTOM then
		if selection.preferredFilters == Enum.LFGListFilter.PvP then
			return "6_pvp"
		end
		return "6_pve"
	end
	return tostring(selection.categoryID)
end

function FS:ResolveSpec(selection)
	local tier = self:GetLayoutTier(selection)
	local col = self:GetNavColumn(selection)
	local row = (col > 0 and MATRIX[col]) or {}
	local cat = selection and selection.categoryID
	local spec = {
		selection = selection,
		layoutTier = tier,
		navColumn = col,
		clientKey = self:GetClientFilterKey(selection),
		categoryID = cat,
		-- 侧栏块
		showDungeonDifficulty = row.diff_dungeon and selection.navKind ~= "season_dungeon",
		showRaidDifficulty = row.diff_raid,
		showMplusRange = true,
		showTankRange = row.tank,
		showHealRange = row.heal,
		showDpsRange = row.dps,
		showRaidMemberCount = row.raidMemberCount,
		showRaidBossKills = row.raidBossKills,
		showMatchRole = row.matchRole,
		showBloodlust = row.bloodlust,
		showNotDeclined = row.notDeclined,
		showNeedsMyClass = row.needsMyClass,
		showHasTankHeal = row.hasTankHeal,
		showDungeonActivities = row.dungeonAct,
		showDelveActivities = row.delveAct,
		showRaidActivities = row.raidAct and self:IsSeasonRaid(selection),
		showSameClass = row.sameClass and tier ~= "submax",
		showMinHonor = row.minHonor,
		showWarmode = row.warmode,
		showHousewarmingExclude = cat == GF.CAT_CUSTOM,
		-- API vs client
		needsMyClassAPI = false,
		hasTankHealAPI = false,
		hasTankHealClient = row.hasTankHeal and (cat == GF.CAT_DUNGEON or cat == GF.CAT_DELVE),
		needsMyClassClient = tier == "api_max" and row.needsMyClass,
		runCategoryClient = tier ~= "submax",
		runGlobalClient = true,
	}
	return spec
end

function FS:GetPanelLayout(spec)
	return spec
end

local function isFilterEnabled(v)
	return v == true or v == 1
end

local function rangeActive(client, minKey, maxKey, enKey)
	if not isFilterEnabled(client[enKey]) then
		return false
	end
	local minV = client[minKey]
	local maxV = client[maxKey]
	return (minV and minV > 0) or (maxV and maxV > 0)
end

local function roleRangeEnabled(client, enKey)
	return client and isFilterEnabled(client[enKey])
end

function FS:IsRangeActive(client, minKey, maxKey, enKey)
	if not client then
		return false
	end
	return rangeActive(client, minKey, maxKey, enKey)
end

function FS:IsRoleRangeEnabled(client, enKey)
	return roleRangeEnabled(client, enKey)
end

function FS:HasActiveClientFilters(spec, client, db)
	if not spec or not spec.runCategoryClient or not client then
		return false
	end
	if spec.showTankRange and roleRangeEnabled(client, "rangeTankEn") then return true end
	if spec.showHealRange and roleRangeEnabled(client, "rangeHealEn") then return true end
	if spec.showDpsRange and roleRangeEnabled(client, "rangeDpsEn") then return true end
	if spec.showRaidMemberCount and rangeActive(client, "raidMemberCountMin", "raidMemberCountMax", "raidMemberCountEn") then return true end
	if spec.showRaidBossKills and rangeActive(client, "raidBossKillsMin", "raidBossKillsMax", "raidBossKillsEn") then return true end
	if client.matchMyRole then return true end
	if client.notDeclined then return true end
	if client.bloodlustMode and client.bloodlustMode > 0 then return true end
	if client.hasTank or client.hasHeal then return true end
	if client.alreadyHasTank or client.alreadyHasHeal then return true end
	if client.needsMyClass then return true end
	if client.dungeonDiffEn then return true end
	if client.warmodeOnly then return true end
	if client.raidDiffEn and (client.raidDifficultyNormal or client.raidDifficultyHeroic or client.raidDifficultyMythic) then return true end
	return false
end

function FS:HasActiveGlobalFilters(db)
	if not db then return false end
	if db.zeroScore then return true end
	if db.sameClass then return true end
	if db.maxAgeMin and db.maxAgeMin > 0 then return true end
	if db.minIlvl and db.minIlvl > 0 then return true end
	if rangeActive(db, "rangeAgeMin", "rangeAgeMax", "rangeAgeEn") then return true end
	if rangeActive(db, "rangeIlvlMin", "rangeIlvlMax", "rangeIlvlEn") then return true end
	if rangeActive(db, "rangeHonorMin", "rangeHonorMax", "rangeHonorEn") then return true end
	if db.hideVoice then return true end
	if db.hideCrossRealm then return true end
	if db.sameFactionOnly then return true end
	if db.showFriendGroups == false then return true end
	if db.showGuildGroups == false then return true end
	if db.showHousewarmingGroups == false then return true end
	if rangeActive(db, "rangeMplusScoreMin", "rangeMplusScoreMax", "rangeMplusScoreEn") then return true end
	if GF.Filter and GF.Filter.HasActivePlaystyleFilter and GF.Filter:HasActivePlaystyleFilter(db) then
		return true
	end
	return false
end

function FS:NeedsPlaystylePostFilter(db)
	return GF.Filter and GF.Filter.HasActivePlaystyleFilter and GF.Filter:HasActivePlaystyleFilter(db)
end

function FS:NeedsDungeonActivityPostFilter(db)
	return GF.Filter and GF.Filter.HasActiveDungeonActivityFilter and GF.Filter:HasActiveDungeonActivityFilter(db)
end

function FS:NeedsRaidActivityPostFilter(db)
	return GF.Filter and GF.Filter.HasActiveRaidActivityFilter and GF.Filter:HasActiveRaidActivityFilter(db)
end

function FS:NeedsPostFilter(spec, client, db)
	if GF.Blocklist and GF.Blocklist.IsEnabled and GF.Blocklist:IsEnabled() then
		return true
	end
	if not GF.ListFilter or not GF.ListFilter.IsEnabled or not GF.ListFilter:IsEnabled() then
		return false
	end
	if self:NeedsPlaystylePostFilter(db) then
		return true
	end
	if self:NeedsDungeonActivityPostFilter(db) then
		return true
	end
	if spec and spec.showRaidActivities and self:NeedsRaidActivityPostFilter(db) then
		return true
	end
	if spec and spec.runGlobalClient and self:HasActiveGlobalFilters(db) then
		return true
	end
	if spec and spec.runCategoryClient and self:HasActiveClientFilters(spec, client, db) then
		return true
	end
	return false
end
