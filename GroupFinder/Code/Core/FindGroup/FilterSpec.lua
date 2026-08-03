local _, GF = ...

local FilterSpec = {}
GF.FilterSpec = FilterSpec

-- 这是面板能力表，不是过滤状态。按导航列归类后，ResolveSpec 再叠加工作区与等级语义。
local COLUMN_CAPABILITIES = {
	[1] = {
		diff_dungeon = true, dungeonAct = true, matchRole = true, needsMyClass = true,
		tank = true, heal = true, dps = true, bloodlust = true, notDeclined = true,
		hasTankHeal = true, sameClass = true,
	},
	[2] = {
		diff_dungeon = true, tank = true, heal = true, dps = true,
		bloodlust = true, notDeclined = true, hasTankHeal = true, sameClass = true,
	},
	[3] = {
		delveAct = true, tank = true, heal = true, dps = true,
		hasTankHeal = true, sameClass = true,
	},
	[4] = {
		diff_raid = true, raidAct = true, raidRoleCounts = true,
		raidMemberCount = true, raidBossKills = true, sameClass = true,
	},
	[5] = { minHonor = true },
	[6] = { sameClass = true },
	[7] = { warmode = true },
	[8] = { warmode = true },
}

local function enabled(value)
	return value == true or value == 1
end

local function flagPresent(mask, flag)
	return mask ~= nil and flag ~= nil and bit.band(mask, flag) ~= 0
end

local function configuredRange(values, descriptor)
	if type(values) ~= "table" or not enabled(values[descriptor.enabled]) then
		return false
	end
	return (tonumber(values[descriptor.minimum]) or 0) > 0
		or (tonumber(values[descriptor.maximum]) or 0) > 0
end

local function safeMethod(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return nil
	end
	local ok, value = pcall(method, owner, ...)
	return ok and value or nil
end

local function isPlayerAtEffectiveMaxLevel()
	-- PTR builds can expose GameRulesUtil before UIParent installs the global
	-- wrapper. Prefer Blizzard's wrapper when it gives a real boolean; if the
	-- wrapper is absent or faults, reproduce IsLevelAtEffectiveMaxLevel's
	-- guarded level >= effective-cap comparison instead of treating a max-level
	-- character as submax.
	if type(IsPlayerAtEffectiveMaxLevel) == "function" then
		local ok, value = pcall(IsPlayerAtEffectiveMaxLevel)
		if ok and type(value) == "boolean" then
			return value
		end
	end

	local getEffectiveMaxLevel = GameRulesUtil
		and GameRulesUtil.GetEffectiveMaxLevelForPlayer
	if type(UnitLevel) ~= "function" or type(getEffectiveMaxLevel) ~= "function" then
		return false
	end
	local ok, value = pcall(function()
		local level = UnitLevel("player")
		local maxLevel = getEffectiveMaxLevel()
		if type(level) ~= "number" or type(maxLevel) ~= "number"
			or level <= 0 or maxLevel <= 0
		then
			return false
		end
		return level >= maxLevel
	end)
	return ok and value == true
end

function FilterSpec:IsSeasonDungeon(selection)
	if type(selection) ~= "table" or selection.categoryID ~= GF.CAT_DUNGEON then
		return false
	end
	if selection.navKind == "season_dungeon" then
		return true
	end
	local filters = selection.filters or 0
	if flagPresent(filters, Enum.LFGListFilter.NotCurrentSeason) then
		return false
	end
	return flagPresent(filters, Enum.LFGListFilter.CurrentSeason)
		or flagPresent(filters, Enum.LFGListFilter.Timerunning)
end

function FilterSpec:IsSeasonRaid(selection)
	return type(selection) == "table"
		and selection.categoryID == GF.CAT_RAID
		and selection.navKind == "season_raid"
end

function FilterSpec:GetLayoutTier(selection)
	-- The active Mythic+ browse workspace is an exact season-dungeon view.
	-- During a catalog rebuild its selection can briefly be nil or still point
	-- at the outgoing shared node, but the workspace contract does not change.
	if self:IsMythicPlusBrowse(selection) then
		return "api_max"
	end
	if type(selection) ~= "table" or selection.categoryID == nil then
		return "default"
	end
	if selection.categoryID ~= GF.CAT_DUNGEON then
		return "default"
	end
	if not isPlayerAtEffectiveMaxLevel() then
		return "submax"
	end
	return self:IsSeasonDungeon(selection) and "api_max" or "nav2"
end

local function isPvpCategory(categoryID)
	for _, category in ipairs(GF.PVP_CATEGORIES or {}) do
		if category.id == categoryID then
			return true
		end
	end
	return false
end

function FilterSpec:GetNavColumn(selection)
	if self:IsMythicPlusBrowse(selection) then
		return 1
	end
	if type(selection) ~= "table" or selection.categoryID == nil then
		return 0
	end
	local categoryID = selection.categoryID
	if categoryID == GF.CAT_DUNGEON then
		local tier = self:GetLayoutTier(selection)
		if tier == "api_max" then
			return 1
		elseif tier == "nav2" then
			return 2
		end
		return 0
	elseif categoryID == GF.CAT_DELVE then
		return 3
	elseif categoryID == GF.CAT_RAID then
		return 4
	elseif isPvpCategory(categoryID) then
		return 5
	elseif categoryID == GF.CAT_QUEST then
		return 6
	elseif categoryID == GF.CAT_CUSTOM then
		return selection.preferredFilters == Enum.LFGListFilter.PvP and 8 or 7
	end
	return 0
end

function FilterSpec:GetWorkspaceID(selection)
	-- This specification is a projection of the currently visible browse
	-- surface, so the live workspace view is authoritative.  Selection objects
	-- are shared by both workspaces and may retain stale context during a
	-- navigation/catalog rebind.
	local current = safeMethod(GF.LFGWorkspaceView, "GetWorkspaceID")
	if current then
		return current
	end
	local context = safeMethod(GF.FindGroupTab, "GetWorkspaceContext")
	if type(context) == "table" and context.workspaceID then
		return context.workspaceID
	end
	if type(selection) == "table" and selection.workspaceID then
		return selection.workspaceID
	end
	return GF.WORKSPACE_MEETING_STONE or "standard"
end

function FilterSpec:IsMythicPlusBrowse(selection)
	-- LFGWorkspacePolicy restricts this workspace to season_dungeon.  Treat the
	-- workspace itself as the capability authority so a transient nil/stale
	-- selection cannot collapse the advanced-filter matrix.
	return self:GetWorkspaceID(selection) == (GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus")
end

function FilterSpec:GetClientFilterKey(selection)
	if self:IsMythicPlusBrowse(selection) then
		return GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus"
	elseif type(selection) ~= "table" or selection.categoryID == nil then
		return "other"
	elseif selection.categoryID == GF.CAT_DUNGEON then
		return "dungeon"
	elseif selection.categoryID == GF.CAT_RAID then
		return "raid"
	end
	return "other"
end

function FilterSpec:ResolveSpec(selection)
	selection = type(selection) == "table" and selection or nil
	local tier = self:GetLayoutTier(selection)
	local column = self:GetNavColumn(selection)
	local capabilities = COLUMN_CAPABILITIES[column] or {}
	local mythicPlus = self:IsMythicPlusBrowse(selection)
	local seasonDungeon = mythicPlus
		or (selection ~= nil and selection.navKind == "season_dungeon")
	local categoryID = selection and selection.categoryID or nil
	if mythicPlus then
		categoryID = GF.CAT_DUNGEON
	end

	local spec = {
		selection = selection,
		layoutTier = tier,
		navColumn = column,
		clientKey = self:GetClientFilterKey(selection),
		categoryID = categoryID,
		workspaceID = self:GetWorkspaceID(selection),
		isMythicPlusBrowse = mythicPlus,
		showMythicPlusBrowseFilters = mythicPlus,
		showMplusRange = true,
		needsMyClassAPI = false,
		hasTankHealAPI = false,
		runGlobalClient = true,
		runCategoryClient = mythicPlus or tier ~= "submax",
	}

	local fieldMap = {
		showRaidDifficulty = "diff_raid",
		showTankRange = "tank",
		showHealRange = "heal",
		showDpsRange = "dps",
		showRaidRoleCounts = "raidRoleCounts",
		showRaidMemberCount = "raidMemberCount",
		showRaidBossKills = "raidBossKills",
		showMatchRole = "matchRole",
		showBloodlust = "bloodlust",
		showNotDeclined = "notDeclined",
		showNeedsMyClass = "needsMyClass",
		showHasTankHeal = "hasTankHeal",
		showDungeonActivities = "dungeonAct",
		showDelveActivities = "delveAct",
		showMinHonor = "minHonor",
		showWarmode = "warmode",
	}
	for outputField, capability in pairs(fieldMap) do
		spec[outputField] = capabilities[capability] == true
	end

	-- Season-dungeon scopes already contain only Mythic Keystone activities.
	-- Keep ordinary dungeon difficulty preferences intact, but never expose or
	-- apply them to either Meeting Stone's season node or the Mythic+ workspace.
	spec.showDungeonDifficulty = capabilities.diff_dungeon == true
		and not seasonDungeon
	spec.showRaidActivities = capabilities.raidAct == true and self:IsSeasonRaid(selection)
	spec.showSameClass = capabilities.sameClass == true and tier ~= "submax"
	spec.showHousewarmingExclude = categoryID == GF.CAT_CUSTOM
	spec.hasTankHealClient = capabilities.hasTankHeal == true
		and (categoryID == GF.CAT_DUNGEON or categoryID == GF.CAT_DELVE)
	spec.needsMyClassClient = tier == "api_max" and capabilities.needsMyClass == true
	return spec
end

function FilterSpec:GetPanelLayout(spec)
	return spec
end

function FilterSpec:IsRangeActive(client, minKey, maxKey, enabledKey)
	return configuredRange(client, {
		minimum = minKey,
		maximum = maxKey,
		enabled = enabledKey,
	})
end

function FilterSpec:IsRoleRangeEnabled(client, enabledKey)
	return type(client) == "table" and enabled(client[enabledKey])
end

local ROLE_RANGE_FLAGS = {
	{ visible = "showTankRange", enabled = "rangeTankEn" },
	{ visible = "showHealRange", enabled = "rangeHealEn" },
	{ visible = "showDpsRange", enabled = "rangeDpsEn" },
}

local RAID_RANGE_FLAGS = {
	{ visible = "showRaidMemberCount", minimum = "raidMemberCountMin", maximum = "raidMemberCountMax", enabled = "raidMemberCountEn" },
	{ visible = "showRaidBossKills", minimum = "raidBossKillsMin", maximum = "raidBossKillsMax", enabled = "raidBossKillsEn" },
}

local function mythicPlusFallbackActive(client)
	local presenceKeys = { "tankPresence", "healerPresence", "damagerPresence" }
	if client.matchPartyRoles == true or client.matchPartySpecs == true then
		return true
	end
	for _, key in ipairs(presenceKeys) do
		if client[key] == "missing" or client[key] == "existing" then
			return true
		end
	end
	return (tonumber(client.minOpenSlots) or 1) > 0
		or (tonumber(client.leaderScoreMin) or 0) > 0
		or client.selectedDungeonKeys ~= nil
end

local function hasTankOrHealerSignal(client)
	if client.hasTank or client.hasHeal then
		return true
	end
	return not not (client.alreadyHasTank or client.alreadyHasHeal)
end

local function hasSelectedRaidDifficulty(client)
	if client.raidDifficultyNormal or client.raidDifficultyHeroic then
		return true
	end
	return not not client.raidDifficultyMythic
end

function FilterSpec:HasActiveClientFilters(spec, client)
	if type(spec) ~= "table" or not spec.runCategoryClient or type(client) ~= "table" then
		return false
	end

	if spec.isMythicPlusBrowse then
		local service = GF.MythicPlusBrowseFilter
		if service and type(service.HasActiveFilters) == "function" then
			if service:HasActiveFilters() == true then
				return true
			end
		elseif mythicPlusFallbackActive(client) then
			return true
		end
	end

	for _, descriptor in ipairs(ROLE_RANGE_FLAGS) do
		if spec[descriptor.visible] and enabled(client[descriptor.enabled]) then
			return true
		end
	end
	if spec.showRaidRoleCounts
		and (enabled(client.raidTankEn) or enabled(client.raidHealEn) or enabled(client.raidDpsEn)) then
		return true
	end
	for _, descriptor in ipairs(RAID_RANGE_FLAGS) do
		if spec[descriptor.visible] and configuredRange(client, descriptor) then
			return true
		end
	end

	local simpleChecks = {
		{ "showMatchRole", client.matchMyRole },
		{ "showNotDeclined", client.notDeclined },
		{ "showNeedsMyClass", client.needsMyClass },
		{ "showDungeonDifficulty", client.dungeonDiffEn },
		{ "showWarmode", client.warmodeOnly },
	}
	for _, check in ipairs(simpleChecks) do
		if spec[check[1]] and check[2] then
			return true
		end
	end
	if spec.showBloodlust and (tonumber(client.bloodlustMode) or 0) > 0 then
		return true
	end
	if spec.hasTankHealClient and hasTankOrHealerSignal(client) then
		return true
	end
	if spec.showRaidDifficulty and client.raidDiffEn then
		return hasSelectedRaidDifficulty(client)
	end
	return false
end

local GLOBAL_RANGES = {
	{ minimum = "rangeAgeMin", maximum = "rangeAgeMax", enabled = "rangeAgeEn" },
	{ minimum = "rangeIlvlMin", maximum = "rangeIlvlMax", enabled = "rangeIlvlEn" },
	{ minimum = "rangeHonorMin", maximum = "rangeHonorMax", enabled = "rangeHonorEn" },
	{ minimum = "rangeMplusScoreMin", maximum = "rangeMplusScoreMax", enabled = "rangeMplusScoreEn" },
}

function FilterSpec:HasActiveGlobalFilters(db)
	if type(db) ~= "table" then
		return false
	end
	if db.zeroScore or db.sameClass or (tonumber(db.maxAgeMin) or 0) > 0 or (tonumber(db.minIlvl) or 0) > 0 then
		return true
	end
	if db.hideVoice or db.hideCrossRealm or db.sameFactionOnly then
		return true
	end
	if db.showFriendGroups == false or db.showGuildGroups == false or db.showHousewarmingGroups == false then
		return true
	end
	for _, descriptor in ipairs(GLOBAL_RANGES) do
		if configuredRange(db, descriptor) then
			return true
		end
	end
	local filter = GF.Filter
	return filter and type(filter.HasActivePlaystyleFilter) == "function"
		and filter:HasActivePlaystyleFilter(db) == true or false
end

function FilterSpec:NeedsPlaystylePostFilter(db)
	local filter = GF.Filter
	return filter and type(filter.HasActivePlaystyleFilter) == "function"
		and filter:HasActivePlaystyleFilter(db) == true or false
end

local function activityFilterActive(methodName, itemMethodName)
	local filter = GF.Filter
	if not filter or type(filter[methodName]) ~= "function" then
		return false
	end
	local items = type(filter[itemMethodName]) == "function" and filter[itemMethodName](filter) or nil
	return filter[methodName](filter, nil, items) == true
end

function FilterSpec:NeedsDungeonActivityPostFilter()
	return activityFilterActive("HasActiveDungeonActivityFilter", "GetDungeonActivityItems")
end

function FilterSpec:NeedsRaidActivityPostFilter()
	return activityFilterActive("HasActiveRaidActivityFilter", "GetRaidActivityItems")
end

function FilterSpec:NeedsPostFilter(spec, client, db)
	local blocklist = GF.Blocklist
	if blocklist and type(blocklist.IsEnabled) == "function" and blocklist:IsEnabled() then
		return true
	end
	local pipeline = GF.ListFilter
	if not pipeline or type(pipeline.IsEnabled) ~= "function" or not pipeline:IsEnabled() then
		return false
	end
	if self:NeedsPlaystylePostFilter(db) or self:NeedsDungeonActivityPostFilter(db) then
		return true
	end
	if spec and spec.showRaidActivities and self:NeedsRaidActivityPostFilter(db) then
		return true
	end
	if spec and spec.runGlobalClient and self:HasActiveGlobalFilters(db) then
		return true
	end
	return spec and spec.runCategoryClient and self:HasActiveClientFilters(spec, client, db) or false
end
