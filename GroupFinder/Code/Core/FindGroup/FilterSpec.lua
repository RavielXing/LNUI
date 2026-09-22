local _, GF = ...

-- A FilterSpec is a value snapshot of the active GF browse policy. It contains
-- no mutable module state and never aliases the navigation object supplied by
-- the caller. Result filtering may therefore keep one plan for an entire pass
-- even while navigation availability is being rebuilt.
local FilterSpec = {}
GF.FilterSpec = FilterSpec

local function call(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return nil, false
	end
	local ok, value = pcall(method, owner, ...)
	return ok and value or nil, ok
end

local function number(value)
	local ok, numeric = pcall(tonumber, value)
	return ok and numeric or nil
end

local function isPvPCategory(categoryID)
	for _, category in ipairs(GF.PVP_CATEGORIES or {}) do
		if categoryID == category.id then
			return true
		end
	end
	return false
end

local function activeWorkspace(selection)
	local workspace = call(GF.LFGWorkspaceView, "GetWorkspaceID")
	if workspace ~= nil then
		return workspace
	end
	local context = call(GF.FindGroupTab, "GetWorkspaceContext")
	if type(context) == "table" and context.workspaceID ~= nil then
		return context.workspaceID
	end
	if type(selection) == "table" and selection.workspaceID ~= nil then
		return selection.workspaceID
	end
	return GF.WORKSPACE_MEETING_STONE or "standard"
end

local function isMythicPlusWorkspace(workspaceID)
	if workspaceID == (GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus") then
		return true
	end
	local policy = GF.LFGWorkspacePolicy
	local answer = call(policy, "IsMythicPlusWorkspace", workspaceID)
	return answer == true
end

local function isAtEffectiveMaxLevel()
	if type(IsPlayerAtEffectiveMaxLevel) == "function" then
		local ok, atMax = pcall(IsPlayerAtEffectiveMaxLevel)
		if ok and type(atMax) == "boolean" then
			return atMax
		end
	end

	local levelOK, level = pcall(function()
		return type(UnitLevel) == "function" and UnitLevel("player") or nil
	end)
	local maxReader = GameRulesUtil
		and GameRulesUtil.GetEffectiveMaxLevelForPlayer
	local maxOK, effectiveMax = pcall(function()
		return type(maxReader) == "function" and maxReader() or nil
	end)
	level = levelOK and number(level) or nil
	effectiveMax = maxOK and number(effectiveMax) or nil
	if not level or not effectiveMax or level <= 0 or effectiveMax <= 0 then
		return false
	end
	return level >= effectiveMax
end

local function hasFlag(value, flag)
	value, flag = number(value), number(flag)
	if not value or not flag or flag == 0 then
		return false
	end
	if bit and type(bit.band) == "function" then
		local ok, present = pcall(bit.band, value, flag)
		return ok and present ~= 0
	end
	-- The supported flags are powers of two. This fallback keeps standalone
	-- contract tests independent from a bit library.
	return value % (flag * 2) >= flag
end

local function exactActivityLeaf(selection)
	if type(selection) ~= "table" or selection.categoryBrowse == true then
		return false
	end
	if number(selection.activityID) then
		return true
	end
	local ids = selection.activityIDsFilter
	return type(ids) == "table" and #ids == 1
end

local SELECTION_FIELDS = {
	"key",
	"categoryID",
	"navKind",
	"activityID",
	"groupID",
	"filters",
	"preferredFilters",
	"workspaceID",
	"level",
	"categoryBrowse",
	"_gfQuestSearch",
}

local function snapshotSelection(selection)
	if type(selection) ~= "table" then
		return nil
	end
	local copy = {}
	for _, field in ipairs(SELECTION_FIELDS) do
		copy[field] = selection[field]
	end
	if type(selection.activityIDsFilter) == "table" then
		copy.activityIDsFilterCount = #selection.activityIDsFilter
	end
	return copy
end

function FilterSpec:IsSeasonDungeon(selection)
	return type(selection) == "table"
		and selection.categoryID == GF.CAT_DUNGEON
		and selection.navKind == "season_dungeon"
end

function FilterSpec:IsSeasonRaid(selection)
	return type(selection) == "table"
		and selection.categoryID == GF.CAT_RAID
		and selection.navKind == "season_raid"
end

function FilterSpec:IsOrdinaryDungeonDifficultyLeaf(selection)
	return type(selection) == "table"
		and selection.categoryID == GF.CAT_DUNGEON
		and selection.navKind ~= "season_dungeon"
		and exactActivityLeaf(selection)
end

function FilterSpec:GetWorkspaceID(selection)
	return activeWorkspace(selection)
end

function FilterSpec:IsMythicPlusBrowse(selection)
	return isMythicPlusWorkspace(activeWorkspace(selection))
end

function FilterSpec:GetLayoutTier(selection)
	if self:IsMythicPlusBrowse(selection) then
		return "api_max"
	end
	return isAtEffectiveMaxLevel() and "api_max" or "submax"
end

function FilterSpec:GetNavColumn(selection)
	if self:IsMythicPlusBrowse(selection) then
		return 1
	end
	local categoryID = type(selection) == "table" and selection.categoryID or nil
	if categoryID == GF.CAT_DUNGEON then
		return 1
	elseif categoryID == GF.CAT_RAID then
		return 2
	elseif categoryID == GF.CAT_DELVE then
		return 3
	elseif categoryID == GF.CAT_QUEST then
		local flags = Enum and Enum.LFGListFilter or {}
		return selection and selection.preferredFilters == flags.PvP and 8 or 7
	elseif categoryID == GF.CAT_CUSTOM then
		return 9
	elseif isPvPCategory(categoryID) then
		return 6
	end
	return 0
end

function FilterSpec:GetClientFilterKey(selection)
	local workspaceID = activeWorkspace(selection)
	if isMythicPlusWorkspace(workspaceID) then
		return GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus"
	end
	local categoryID = type(selection) == "table" and selection.categoryID or nil
	if categoryID == GF.CAT_DUNGEON then
		return "dungeon"
	elseif categoryID == GF.CAT_RAID then
		return "raid"
	end
	return "other"
end

local function blankCapabilities()
	return {
		showDungeonDifficulty = false,
		showRaidDifficulty = false,
		showDungeonActivities = false,
		showRaidActivities = false,
		showBloodlust = false,
		showMatchRole = false,
		showNeedsMyClass = false,
		showHasTankHeal = false,
		showTankRange = false,
		showHealRange = false,
		showDpsRange = false,
		showRaidRoleCounts = false,
		showRaidMemberCount = false,
		showRaidBossKills = false,
		showMplusRange = false,
		showMinHonor = false,
		showNotDeclined = false,
		showSameClass = false,
		showWarmode = false,
		needsMyClassClient = false,
		hasTankHealClient = false,
	}
end

local function projectCapabilities(plan, sourceSelection)
	local caps = blankCapabilities()
	local categoryID = plan.categoryID
	local atMax = plan.layoutTier == "api_max"
	local isDungeon = categoryID == GF.CAT_DUNGEON
	local isRaid = categoryID == GF.CAT_RAID
	local isDelve = categoryID == GF.CAT_DELVE
	local isPvp = isPvPCategory(categoryID)
	local groupedPve = isDungeon or isRaid or isDelve

	caps.showNotDeclined = true
	caps.showBloodlust = groupedPve and atMax
	caps.showMatchRole = groupedPve and atMax
	caps.showNeedsMyClass = groupedPve and atMax
	caps.needsMyClassClient = caps.showNeedsMyClass
	caps.showSameClass = groupedPve
	caps.showMplusRange = groupedPve and atMax

	if isDungeon or isDelve then
		caps.showHasTankHeal = atMax
		caps.hasTankHealClient = atMax
		caps.showTankRange = atMax
		caps.showHealRange = atMax
		caps.showDpsRange = atMax
	end
	if isDungeon then
		caps.showDungeonDifficulty = atMax
			and not plan.isSeasonDungeon
			and not plan.isMythicPlusBrowse
			and not FilterSpec:IsOrdinaryDungeonDifficultyLeaf(sourceSelection)
		caps.showDungeonActivities = plan.isSeasonDungeon
			and not plan.isMythicPlusBrowse
	end
	if isRaid then
		caps.showRaidDifficulty = atMax and not plan.isSeasonRaid
		caps.showRaidActivities = plan.isSeasonRaid
		caps.showRaidRoleCounts = atMax
		caps.showRaidMemberCount = atMax
		caps.showRaidBossKills = atMax
	end
	if isPvp then
		caps.showMinHonor = true
		caps.showWarmode = true
	end
	if categoryID == GF.CAT_QUEST then
		local flags = Enum and Enum.LFGListFilter or {}
		local pvpQuest = sourceSelection
			and hasFlag(sourceSelection.preferredFilters, flags.PvP)
		caps.showMinHonor = pvpQuest
		caps.showWarmode = true
	end

	for key, value in pairs(caps) do
		plan[key] = value
	end
end

function FilterSpec:ResolveSpec(selection)
	local workspaceID = activeWorkspace(selection)
	local mythicPlus = isMythicPlusWorkspace(workspaceID)
	local categoryID = type(selection) == "table" and selection.categoryID or nil
	local navKind = type(selection) == "table" and selection.navKind or nil
	if mythicPlus then
		-- The workspace policy is authoritative during selection handoff windows.
		categoryID = GF.CAT_DUNGEON
		navKind = "season_dungeon"
	end

	local selectionCopy = snapshotSelection(selection)
	if mythicPlus then
		selectionCopy = selectionCopy or {}
		selectionCopy.categoryID = categoryID
		selectionCopy.navKind = navKind
		selectionCopy.workspaceID = workspaceID
	end

	local questSearch = type(selection) == "table"
		and selection._gfQuestSearch == true
	local plan = {
		workspaceID = workspaceID,
		categoryID = categoryID,
		navKind = navKind,
		clientKey = mythicPlus and (GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus")
			or self:GetClientFilterKey(selection),
		layoutTier = mythicPlus and "api_max" or self:GetLayoutTier(selection),
		navColumn = mythicPlus and 1 or self:GetNavColumn(selection),
		isMythicPlusBrowse = mythicPlus,
		isSeasonDungeon = mythicPlus or self:IsSeasonDungeon(selection),
		isSeasonRaid = not mythicPlus and self:IsSeasonRaid(selection),
		isQuestSearch = questSearch,
		runGlobalClient = not questSearch,
		runCategoryClient = not questSearch,
		selection = selectionCopy,
	}
	projectCapabilities(plan, selection)
	if questSearch then
		for key in pairs(blankCapabilities()) do
			plan[key] = false
		end
	end
	return plan
end

local function enabledRange(values, enabledKey)
	return type(values) == "table" and values[enabledKey] == true
end

local function hasMythicPlusConditions(client)
	if type(client) ~= "table" then
		return false
	end
	return client.matchPartyRoles == true
		or client.matchPartySpecs == true
		or client.tankPresence ~= nil
		or client.healerPresence ~= nil
		or client.damagerPresence ~= nil
		or (number(client.minOpenSlots) or 0) > 0
		or (number(client.leaderScoreMin) or 0) > 0
		or client.selectedDungeonKeys ~= nil
end

function FilterSpec:HasActiveClientFilters(spec, client)
	if type(spec) ~= "table" or spec.runCategoryClient ~= true
		or type(client) ~= "table"
	then
		return false
	end
	if spec.isMythicPlusBrowse and hasMythicPlusConditions(client) then
		return true
	end
	if spec.showDungeonDifficulty and client.dungeonDiffEn == true then
		return true
	end
	if spec.showRaidDifficulty and client.raidDiffEn == true then
		return true
	end
	if spec.showBloodlust and (number(client.bloodlustMode) or 0) > 0 then
		return true
	end
	for _, condition in ipairs({
		{ "showMatchRole", "matchMyRole" },
		{ "showNeedsMyClass", "needsMyClass" },
		{ "showHasTankHeal", "hasTank" },
		{ "showHasTankHeal", "hasHeal" },
		{ "showHasTankHeal", "alreadyHasTank" },
		{ "showHasTankHeal", "alreadyHasHeal" },
		{ "showWarmode", "warmodeOnly" },
		{ "showNotDeclined", "notDeclined" },
	}) do
		if spec[condition[1]] and client[condition[2]] == true then
			return true
		end
	end
	for _, condition in ipairs({
		{ "showTankRange", "rangeTankEn" },
		{ "showHealRange", "rangeHealEn" },
		{ "showDpsRange", "rangeDpsEn" },
		{ "showRaidRoleCounts", "raidTankEn" },
		{ "showRaidRoleCounts", "raidHealEn" },
		{ "showRaidRoleCounts", "raidDpsEn" },
		{ "showRaidMemberCount", "raidMemberCountEn" },
		{ "showRaidBossKills", "raidBossKillsEn" },
	}) do
		if spec[condition[1]] and enabledRange(client, condition[2]) then
			return true
		end
	end
	return false
end

function FilterSpec:NeedsPlaystylePostFilter(db)
	if GF.Filter and type(GF.Filter.HasActivePlaystyleFilter) == "function" then
		local ok, active = pcall(GF.Filter.HasActivePlaystyleFilter, GF.Filter, db)
		if ok then
			return active == true
		end
	end
	for index = 1, 4 do
		if type(db) == "table" and db["playstyle" .. index] == false then
			return true
		end
	end
	return false
end

function FilterSpec:HasActiveGlobalFilters(db)
	if type(db) ~= "table" then
		return false
	end
	for _, key in ipairs({
		"sameClass", "zeroScore", "hideVoice", "hideCrossRealm",
		"sameFactionOnly", "rangeAgeEn", "rangeIlvlEn", "rangeHonorEn",
		"rangeMplusScoreEn", "groupMinimumItemLevelAdmission",
	}) do
		if db[key] == true then
			return true
		end
	end
	if db.showFriendGroups == false or db.showGuildGroups == false
		or db.showHousewarmingGroups == false
	then
		return true
	end
	if (number(db.maxAgeMin) or 0) > 0 or (number(db.minIlvl) or 0) > 0 then
		return true
	end
	return self:NeedsPlaystylePostFilter(db)
end

local function filterCall(methodName, db)
	local owner = GF.Filter
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return false
	end
	local ok, active = pcall(method, owner, db)
	return ok and active == true
end

function FilterSpec:NeedsDungeonActivityPostFilter()
	-- Seasonal activity selection is persisted at the account root, not in the
	-- semantic global-filter bucket supplied to the other predicates.
	return filterCall("HasActiveDungeonActivityFilter")
end

function FilterSpec:NeedsRaidActivityPostFilter()
	return filterCall("HasActiveRaidActivityFilter")
end

function FilterSpec:HasActiveBlocklist()
	local blocklist = GF.Blocklist
	if not blocklist then
		return false
	end
	local enabled = call(blocklist, "IsEnabled")
	if enabled ~= true then
		return false
	end
	if type(blocklist.HasActiveRules) == "function" then
		local active = call(blocklist, "HasActiveRules")
		return active == true
	end
	return type(blocklist.leaders) == "table"
		and next(blocklist.leaders) ~= nil
end

function FilterSpec:NeedsListFilter(spec, client, db)
	if type(spec) ~= "table" or spec.isQuestSearch == true then
		return false
	end
	local newbieFilter = GF.MythicPlusBrowseFilter
	if spec.isMythicPlusBrowse == true
		and GF.NetEaseIdentityService
		and GF.NetEaseIdentityService:IsEnabled() == true
		and newbieFilter and newbieFilter:IsNewbieOnly() == true
	then
		return true
	end
	if spec.runCategoryClient == true
		and self:HasActiveClientFilters(spec, client)
	then
		return true
	end
	if spec.runGlobalClient == true and self:HasActiveGlobalFilters(db) then
		return true
	end
	if spec.showDungeonActivities and self:NeedsDungeonActivityPostFilter(db) then
		return true
	end
	if spec.showRaidActivities and self:NeedsRaidActivityPostFilter(db) then
		return true
	end
	return false
end

function FilterSpec:NeedsPostFilter(spec, client, db)
	if type(spec) ~= "table" or spec.isQuestSearch == true then
		return false
	end
	return self:NeedsListFilter(spec, client, db)
		or self:HasActiveBlocklist()
end
