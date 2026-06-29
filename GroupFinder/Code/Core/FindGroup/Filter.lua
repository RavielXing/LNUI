local _, GF = ...

GF.Filter = {}

local function copyTable(src)
	if not src then
		return {}
	end
	local dst = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = copyTable(v)
		else
			dst[k] = v
		end
	end
	return dst
end

local function compactClientFilter(client)
	if not client then
		return nil
	end
	local out = {}
	for k, v in pairs(client) do
		local def = GF.clientFilterDefaults[k]
		if def == nil or v ~= def then
			out[k] = v
		end
	end
	if not next(out) then
		return nil
	end
	return out
end

local function migrateLegacyRange(client, legacyKey, minKey, maxKey)
	if not client then
		return
	end
	local legacy = tonumber(client[legacyKey]) or 0
	local minV = tonumber(client[minKey]) or 0
	local maxV = tonumber(client[maxKey]) or 0
	if legacy > 0 and minV <= 0 and maxV <= 0 then
		client[minKey] = legacy
		client[maxKey] = legacy
	end
	client[legacyKey] = 0
end

function GF.Filter:GetClientFilters(key)
	local db = GF.GetDB()
	db.filterClientByCategory = db.filterClientByCategory or {}
	local stored = db.filterClientByCategory[key]
	if not stored then
		return copyTable(GF.clientFilterDefaults)
	end
	local merged = copyTable(GF.clientFilterDefaults)
	for k, v in pairs(stored) do
		merged[k] = v
	end
	migrateLegacyRange(merged, "raidMemberCount", "raidMemberCountMin", "raidMemberCountMax")
	migrateLegacyRange(merged, "raidBossKills", "raidBossKillsMin", "raidBossKillsMax")
	return merged
end

function GF.Filter:SaveCategoryClientFilters(key, client)
	if not key or not client then
		return
	end
	local db = GF.GetDB()
	db.filterClientByCategory = db.filterClientByCategory or {}
	db.filterClientByCategory[key] = compactClientFilter(client)
end

function GF.Filter:GetPersistedActivities()
	local db = GF.GetDB()
	return db.filterDungeonActivities
end

function GF.Filter:SetPersistedActivities(activities)
	local db = GF.GetDB()
	if activities == nil then
		db.filterDungeonActivities = nil
	else
		db.filterDungeonActivities = copyTable(activities)
	end
end

function GF.Filter:GetPersistedDelveActivities()
	return GF.GetDB().filterDelveActivities
end

function GF.Filter:SetPersistedDelveActivities(activities)
	local db = GF.GetDB()
	if activities == nil then
		db.filterDelveActivities = nil
	else
		db.filterDelveActivities = copyTable(activities)
	end
end

function GF.Filter:IsAllDungeonGroupsDisabled()
	return GF.GetDB().filterDungeonNone == true
end

function GF.Filter:SetAllDungeonGroupsDisabled(disabled)
	local db = GF.GetDB()
	db.filterDungeonNone = disabled and true or nil
end

function GF.Filter:GetAdvancedOptions()
	if not C_LFGList.GetAdvancedFilter then
		return nil
	end
	local opts = copyTable(C_LFGList.GetAdvancedFilter())
	-- 以下项均为客户端 post-filter，不限制 API 搜索
	opts.activities = {}
	opts.needsMyClass = false
	opts.hasTank = false
	opts.hasHealer = false
	if opts.difficultyNormal ~= nil then
		opts.difficultyNormal = true
		opts.difficultyHeroic = true
		opts.difficultyMythic = true
		opts.difficultyMythicPlus = true
	end
	return opts
end

function GF.Filter:SanitizeActivityGroupList(persisted, allGroups)
	if not persisted or #persisted == 0 then
		return persisted
	end
	local valid = {}
	for _, id in ipairs(allGroups) do
		valid[id] = true
	end
	local out = {}
	for _, id in ipairs(persisted) do
		if valid[id] then
			out[#out + 1] = id
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

function GF.Filter:GetDungeonActivityOptions()
	local db = GF.GetDB()
	local opts = { activities = nil }
	if db.filterDungeonNone then
		opts.activities = {}
	elseif db.filterDungeonActivities ~= nil then
		local allGroups = self:GetDungeonGroupIDs()
		local sanitized = self:SanitizeActivityGroupList(db.filterDungeonActivities, allGroups)
		if sanitized ~= db.filterDungeonActivities then
			self:SetPersistedActivities(sanitized)
		end
		if sanitized then
			opts.activities = copyTable(sanitized)
		end
	end
	return opts
end

function GF.Filter:GetPersistedRaidActivities()
	return GF.GetDB().filterRaidActivities
end

function GF.Filter:SetPersistedRaidActivities(activities)
	local db = GF.GetDB()
	if activities == nil then
		db.filterRaidActivities = nil
	else
		db.filterRaidActivities = copyTable(activities)
	end
end

function GF.Filter:IsAllRaidGroupsDisabled()
	return GF.GetDB().filterRaidNone == true
end

function GF.Filter:SetAllRaidGroupsDisabled(disabled)
	local db = GF.GetDB()
	db.filterRaidNone = disabled and true or nil
end

function GF.Filter:GetRaidActivityOptions()
	local db = GF.GetDB()
	local opts = { activities = nil }
	if db.filterRaidNone then
		opts.activities = {}
	elseif db.filterRaidActivities ~= nil then
		local allGroups = self:GetRaidGroupIDs()
		local sanitized = self:SanitizeActivityGroupList(db.filterRaidActivities, allGroups)
		if sanitized ~= db.filterRaidActivities then
			self:SetPersistedRaidActivities(sanitized)
		end
		if sanitized then
			opts.activities = copyTable(sanitized)
		end
	end
	return opts
end

function GF.Filter:SaveAdvancedOptions(options)
	if not options then
		return
	end
	local apiOpts = copyTable(options)
	apiOpts.activities = {}
	if C_LFGList.SaveAdvancedFilter then
		C_LFGList.SaveAdvancedFilter(apiOpts)
	end
end

function GF.Filter:ApplyPersistedAdvancedFilter()
	-- 活动组勾选已改为客户端过滤，登录时不向 API 写入 activities
end

function GF.Filter:ResetAdvancedOptions()
	if not C_LFGList.GetAdvancedFilter then
		return
	end
	local enabled = C_LFGList.GetAdvancedFilter()
	enabled.needsTank = false
	enabled.needsHealer = false
	enabled.needsDamage = false
	enabled.needsMyClass = false
	enabled.hasTank = false
	enabled.hasHealer = false
	enabled.minimumRating = 0
	enabled.activities = {}
	self:SetAllDungeonGroupsDisabled(false)
	self:SetPersistedActivities(nil)
	self:SetAllRaidGroupsDisabled(false)
	self:SetPersistedRaidActivities(nil)
	if enabled.difficultyNormal ~= nil then
		enabled.difficultyNormal = true
		enabled.difficultyHeroic = true
		enabled.difficultyMythic = true
		enabled.difficultyMythicPlus = true
	end
	C_LFGList.SaveAdvancedFilter(enabled)
end

function GF.Filter:ResetCategoryClient(key)
	if not key then
		return
	end
	local db = GF.GetDB()
	if db.filterClientByCategory then
		db.filterClientByCategory[key] = nil
	end
end

function GF.Filter:ResetVisibleGlobalFilters(spec)
	local db = GF.GetDB()
	db.sameClass = false
	db.zeroScore = false
	db.playstyle1 = true
	db.playstyle2 = true
	db.playstyle3 = true
	db.playstyle4 = true
	db.maxAgeMin = 0
	db.minIlvl = 0
	db.rangeAgeEn = false
	db.rangeAgeMin = 0
	db.rangeAgeMax = 0
	db.rangeIlvlEn = false
	db.rangeIlvlMin = 0
	db.rangeIlvlMax = 0
	db.rangeHonorEn = false
	db.rangeHonorMin = 0
	db.rangeHonorMax = 0
	db.hideVoice = false
	db.hideCrossRealm = false
	db.sameFactionOnly = false
	db.showFriendGroups = true
	db.showGuildGroups = true
	db.showHousewarmingGroups = true
	db.filterRoleMatchAll = false
	db.rangeMplusScoreEn = false
	db.rangeMplusScoreMin = 0
	db.rangeMplusScoreMax = 0
	if spec and spec.showDungeonActivities then
		self:SetAllDungeonGroupsDisabled(false)
		self:SetPersistedActivities(nil)
	end
	if spec and spec.showRaidActivities then
		self:SetAllRaidGroupsDisabled(false)
		self:SetPersistedRaidActivities(nil)
	end
end

function GF.Filter:ResetCategory(selection)
	if not selection then
		return
	end
	local spec = GF.FilterSpec and GF.FilterSpec:ResolveSpec(selection)
	if not spec then
		return
	end
	if spec.layoutTier == "api_max" then
		self:ResetAdvancedOptions()
	end
	self:ResetCategoryClient(spec.clientKey)
	self:ResetVisibleGlobalFilters(spec)
end

local PLAYSTYLE_ENUM = {
	Enum.LFGEntryGeneralPlaystyle.Learning,
	Enum.LFGEntryGeneralPlaystyle.FunRelaxed,
	Enum.LFGEntryGeneralPlaystyle.FunSerious,
	Enum.LFGEntryGeneralPlaystyle.Expert,
}

function GF.Filter:HasActivePlaystyleFilter(db)
	if not db then
		return false
	end
	for i = 1, 4 do
		if db["playstyle" .. i] == false then
			return true
		end
	end
	return false
end

function GF.Filter:HasActiveDungeonActivityFilter(db)
	db = db or GF.GetDB()
	if db.filterDungeonNone then
		return true
	end
	local persisted = db.filterDungeonActivities
	if persisted == nil or #persisted == 0 then
		return false
	end
	local allGroups = self:GetDungeonGroupIDs()
	return not self:ActivitiesAllChecked({ activities = persisted }, allGroups)
end

function GF.Filter:MatchesDungeonActivityFilter(db, activityGroupID)
	db = db or GF.GetDB()
	if db.filterDungeonNone then
		return false
	end
	local persisted = db.filterDungeonActivities
	if persisted == nil or #persisted == 0 then
		return true
	end
	local allGroups = self:GetDungeonGroupIDs()
	if self:ActivitiesAllChecked({ activities = persisted }, allGroups) then
		return true
	end
	if not activityGroupID then
		return false
	end
	for _, id in ipairs(persisted) do
		if id == activityGroupID then
			return true
		end
	end
	return false
end

function GF.Filter:HasActiveRaidActivityFilter(db)
	db = db or GF.GetDB()
	if db.filterRaidNone then
		return true
	end
	local persisted = db.filterRaidActivities
	if persisted == nil or #persisted == 0 then
		return false
	end
	local allGroups = self:GetRaidGroupIDs()
	return not self:ActivitiesAllChecked({ activities = persisted }, allGroups)
end

function GF.Filter:MatchesRaidActivityFilter(db, activityGroupID)
	db = db or GF.GetDB()
	if db.filterRaidNone then
		return false
	end
	local persisted = db.filterRaidActivities
	if persisted == nil or #persisted == 0 then
		return true
	end
	local allGroups = self:GetRaidGroupIDs()
	if self:ActivitiesAllChecked({ activities = persisted }, allGroups) then
		return true
	end
	if not activityGroupID then
		return false
	end
	for _, id in ipairs(persisted) do
		if id == activityGroupID then
			return true
		end
	end
	return false
end

function GF.Filter:MatchesPlaystyleFilter(db, generalPlaystyle)
	if not db then
		return true
	end
	local allOn = true
	local anyOn = false
	for i = 1, 4 do
		if db["playstyle" .. i] == false then
			allOn = false
		else
			anyOn = true
		end
	end
	if allOn then
		return true
	end
	if not anyOn then
		return false
	end
	local gs = generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None
	if gs == Enum.LFGEntryGeneralPlaystyle.None then
		return false
	end
	for i = 1, 4 do
		if PLAYSTYLE_ENUM[i] == gs then
			return db["playstyle" .. i] ~= false
		end
	end
	return false
end

function GF.Filter:GetPlaystyleFilterLabel(index)
	if index == 0 or not index then
		local L = GF.L or {}
		return L.PLAYSTYLE_ANY or ALL or "All"
	end
	local key = "GROUP_FINDER_GENERAL_PLAYSTYLE" .. index
	return _G[key] or ("Style " .. index)
end

function GF.Filter:GetDungeonGroupIDs()
	local pve = Enum.LFGListFilter.PvE
	local seasonF = bit.bor(Enum.LFGListFilter.CurrentSeason, pve)
	return C_LFGList.GetAvailableActivityGroups(GF.CAT_DUNGEON, seasonF) or {}
end

function GF.Filter:GetDelveGroupIDs()
	local pve = Enum.LFGListFilter.PvE
	local openF = bit.bor(Enum.LFGListFilter.CurrentExpansion, pve)
	return C_LFGList.GetAvailableActivityGroups(GF.CAT_DELVE, openF) or {}
end

function GF.Filter:GetRaidGroupIDs()
	local pve = Enum.LFGListFilter.PvE
	local recF = bit.bor(Enum.LFGListFilter.Recommended, pve)
	return C_LFGList.GetAvailableActivityGroups(GF.CAT_RAID, recF) or {}
end

function GF.Filter:ActivitiesAllChecked(options, allGroups)
	allGroups = allGroups or self:GetDungeonGroupIDs()
	if not options or not options.activities or #options.activities == 0 then
		return false
	end
	if #options.activities ~= #allGroups then
		return false
	end
	for _, groupID in ipairs(allGroups) do
		local found = false
		for _, id in ipairs(options.activities) do
			if id == groupID then
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end
	return true
end

function GF.Filter:IsGroupEnabled(options, groupID, allGroups)
	if not options or not options.activities then
		return true
	end
	if #options.activities == 0 then
		return true
	end
	allGroups = allGroups or self:GetDungeonGroupIDs()
	if self:ActivitiesAllChecked(options, allGroups) then
		return true
	end
	for _, id in ipairs(options.activities) do
		if id == groupID then
			return true
		end
	end
	return false
end

function GF.Filter:SetGroupEnabled(options, groupID, enabled, allGroups, persistFn)
	allGroups = allGroups or self:GetDungeonGroupIDs()
	if not options then
		return
	end
	options.activities = options.activities or {}
	local checked = {}
	if #options.activities == 0 or self:ActivitiesAllChecked(options, allGroups) then
		for _, id in ipairs(allGroups) do
			checked[id] = true
		end
	else
		for _, id in ipairs(allGroups) do
			checked[id] = false
		end
		for _, id in ipairs(options.activities) do
			checked[id] = true
		end
	end
	checked[groupID] = enabled
	local enabledCount = 0
	for _, id in ipairs(allGroups) do
		if checked[id] then
			enabledCount = enabledCount + 1
		end
	end
	if enabledCount == 0 then
		options.activities = {}
	elseif enabledCount == #allGroups then
		options.activities = {}
	else
		options.activities = {}
		for _, id in ipairs(allGroups) do
			if checked[id] then
				options.activities[#options.activities + 1] = id
			end
		end
	end
	if persistFn then
		persistFn(options.activities)
	end
end

function GF.Filter:SetDungeonGroupEnabled(options, groupID, enabled)
	if not options then
		return
	end
	options.activities = options.activities or {}
	local allGroups = self:GetDungeonGroupIDs()
	local checked = {}
	if self:IsAllDungeonGroupsDisabled() then
		for _, id in ipairs(allGroups) do
			checked[id] = false
		end
	elseif #options.activities == 0 or self:ActivitiesAllChecked(options, allGroups) then
		for _, id in ipairs(allGroups) do
			checked[id] = true
		end
	else
		for _, id in ipairs(allGroups) do
			checked[id] = false
		end
		for _, id in ipairs(options.activities) do
			checked[id] = true
		end
	end
	checked[groupID] = enabled
	local enabledCount = 0
	for _, id in ipairs(allGroups) do
		if checked[id] then
			enabledCount = enabledCount + 1
		end
	end
	if enabledCount == 0 then
		options.activities = {}
		self:SetAllDungeonGroupsDisabled(true)
		self:SetPersistedActivities({})
	elseif enabledCount == #allGroups then
		options.activities = {}
		self:SetAllDungeonGroupsDisabled(false)
		self:SetPersistedActivities({})
	else
		options.activities = {}
		for _, id in ipairs(allGroups) do
			if checked[id] then
				options.activities[#options.activities + 1] = id
			end
		end
		self:SetAllDungeonGroupsDisabled(false)
		self:SetPersistedActivities(options.activities)
	end
end

function GF.Filter:SetRaidGroupEnabled(options, groupID, enabled)
	if not options then
		return
	end
	options.activities = options.activities or {}
	local allGroups = self:GetRaidGroupIDs()
	local checked = {}
	if self:IsAllRaidGroupsDisabled() then
		for _, id in ipairs(allGroups) do
			checked[id] = false
		end
	elseif #options.activities == 0 or self:ActivitiesAllChecked(options, allGroups) then
		for _, id in ipairs(allGroups) do
			checked[id] = true
		end
	else
		for _, id in ipairs(allGroups) do
			checked[id] = false
		end
		for _, id in ipairs(options.activities) do
			checked[id] = true
		end
	end
	checked[groupID] = enabled
	local enabledCount = 0
	for _, id in ipairs(allGroups) do
		if checked[id] then
			enabledCount = enabledCount + 1
		end
	end
	if enabledCount == 0 then
		options.activities = {}
		self:SetAllRaidGroupsDisabled(true)
		self:SetPersistedRaidActivities({})
	elseif enabledCount == #allGroups then
		options.activities = {}
		self:SetAllRaidGroupsDisabled(false)
		self:SetPersistedRaidActivities({})
	else
		options.activities = {}
		for _, id in ipairs(allGroups) do
			if checked[id] then
				options.activities[#options.activities + 1] = id
			end
		end
		self:SetAllRaidGroupsDisabled(false)
		self:SetPersistedRaidActivities(options.activities)
	end
end

function GF.Filter:ApplyDifficultyToClient(client, diffIndex, includeMplus)
	if not client then
		return
	end
	local allOn = not diffIndex or diffIndex == 0
	client.dungeonDiffEn = not allOn
	client.dungeonDifficultyNormal = allOn or diffIndex == 1
	client.dungeonDifficultyHeroic = allOn or diffIndex == 2
	client.dungeonDifficultyMythic = allOn or diffIndex == 3
	if includeMplus then
		client.dungeonDifficultyMythicPlus = allOn or diffIndex == 4
	end
end

function GF.Filter:ApplyRaidDifficultyToClient(client, diffIndex)
	if not client then
		return
	end
	local allOn = not diffIndex or diffIndex == 0
	client.raidDiffEn = not allOn
	client.raidDifficultyNormal = allOn or diffIndex == 1
	client.raidDifficultyHeroic = allOn or diffIndex == 2
	client.raidDifficultyMythic = allOn or diffIndex == 3
end

function GF.Filter:GetClientDifficultyIndex(client, includeMplus)
	if not client or not client.dungeonDiffEn then
		return 0
	end
	if client.dungeonDifficultyNormal and not client.dungeonDifficultyHeroic
		and not client.dungeonDifficultyMythic and not (includeMplus and client.dungeonDifficultyMythicPlus) then
		return 1
	end
	if client.dungeonDifficultyHeroic and not client.dungeonDifficultyNormal
		and not client.dungeonDifficultyMythic and not (includeMplus and client.dungeonDifficultyMythicPlus) then
		return 2
	end
	if client.dungeonDifficultyMythic and not client.dungeonDifficultyNormal
		and not client.dungeonDifficultyHeroic and not (includeMplus and client.dungeonDifficultyMythicPlus) then
		return 3
	end
	if includeMplus and client.dungeonDifficultyMythicPlus and not client.dungeonDifficultyNormal
		and not client.dungeonDifficultyHeroic and not client.dungeonDifficultyMythic then
		return 4
	end
	return 0
end

function GF.Filter:GetRaidDifficultyIndex(client)
	if not client or not client.raidDiffEn then
		return 0
	end
	if client.raidDifficultyNormal and not client.raidDifficultyHeroic and not client.raidDifficultyMythic then
		return 1
	end
	if client.raidDifficultyHeroic and not client.raidDifficultyNormal and not client.raidDifficultyMythic then
		return 2
	end
	if client.raidDifficultyMythic and not client.raidDifficultyNormal and not client.raidDifficultyHeroic then
		return 3
	end
	return 0
end

function GF.Filter:ApplyDifficultyToAdvanced(opts, diffIndex)
	if not opts then
		return
	end
	local allOn = not diffIndex or diffIndex == 0
	opts.difficultyNormal = allOn or diffIndex == 1
	opts.difficultyHeroic = allOn or diffIndex == 2
	opts.difficultyMythic = allOn or diffIndex == 3
	opts.difficultyMythicPlus = allOn or diffIndex == 4
end

function GF.Filter:GetDifficultyIndex(opts)
	if not opts or opts.difficultyNormal == nil then
		return 0
	end
	if opts.difficultyNormal and opts.difficultyHeroic and opts.difficultyMythic and opts.difficultyMythicPlus then
		return 0
	end
	if opts.difficultyNormal and not opts.difficultyHeroic and not opts.difficultyMythic and not opts.difficultyMythicPlus then
		return 1
	end
	if opts.difficultyHeroic and not opts.difficultyNormal and not opts.difficultyMythic and not opts.difficultyMythicPlus then
		return 2
	end
	if opts.difficultyMythic and not opts.difficultyNormal and not opts.difficultyHeroic and not opts.difficultyMythicPlus then
		return 3
	end
	if opts.difficultyMythicPlus and not opts.difficultyNormal and not opts.difficultyHeroic and not opts.difficultyMythic then
		return 4
	end
	return 0
end

function GF.Filter:ResolveCategoryFilters(categoryID, filters)
	local catInfo = categoryID and C_LFGList.GetLfgCategoryInfo(categoryID)
	if catInfo and catInfo.separateRecommended then
		return bit.band(bit.bnot(Enum.LFGListFilter.NotRecommended), bit.bor(filters or 0, Enum.LFGListFilter.Recommended))
	end
	return filters or 0
end

function GF.Filter:ApplyClientFilterRefresh()
	if GF.FindGroupTab and GF.FindGroupTab.ApplyClientFilters then
		GF.FindGroupTab:ApplyClientFilters()
	end
end
