local _, GF = ...

local Tooltip = {}
GF.MythicPlusCharacterVaultTooltip = Tooltip
local WHITE, GOLD, GRAY, GREEN = { 1, 1, 1 }, { 1, 0.82, 0 }, { 0.5, 0.5, 0.5 }, { 0.1, 1, 0.1 }

local function localized(key, fallback)
	return GF.L and GF.L[key] or fallback
end

local function native(key, ...)
	local value = _G[key]
	if type(value) ~= "string" then return nil end
	if select("#", ...) == 0 then return value end
	local ok, result = pcall(string.format, value, ...)
	return ok and result or nil
end

local function line(value, color)
	if not value then return false end
	color = color or WHITE
	GameTooltip:AddLine(value, color[1], color[2], color[3], true)
	return true
end

local function blank() line(" ") end

local function staticInfo(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f = pcall(fn, ...)
	if ok then return a, b, c, d, e, f end
end

local function difficultyName(id)
	return staticInfo(DifficultyUtil and DifficultyUtil.GetDifficultyName, id)
		or staticInfo(GetDifficultyInfo, id)
end

local function addEncounters(info)
	if not info or not info.encounters then return false end
	local encounters = {}
	for _, entry in ipairs(info.encounters) do encounters[#encounters + 1] = entry end
	table.sort(encounters, function(a, b)
		if a.instanceID ~= b.instanceID then return a.instanceID < b.instanceID end
		if (a.bestDifficulty > 0) ~= (b.bestDifficulty > 0) then return a.bestDifficulty > 0 end
		return a.uiOrder < b.uiOrder
	end)
	local lastInstance, ready = nil, true
	for _, entry in ipairs(encounters) do
		local name, _, _, _, _, instance = staticInfo(EJ_GetEncounterInfo, entry.encounterID)
		local instanceName = instance and staticInfo(EJ_GetInstanceInfo, instance)
		if name and instanceName then
			if instance ~= lastInstance then
				blank()
				line(native("WEEKLY_REWARDS_ENCOUNTER_LIST", instanceName))
				lastInstance = instance
			end
			local completedDifficulty = entry.bestDifficulty > 0 and difficultyName(entry.bestDifficulty)
			if completedDifficulty then
				line(native("WEEKLY_REWARDS_COMPLETED_ENCOUNTER", name, completedDifficulty), GREEN)
			else
				line(native("DASH_WITH_TEXT", name), entry.bestDifficulty > 0 and GREEN or GRAY)
				if entry.bestDifficulty > 0 then ready = false end
			end
		else
			ready = false
		end
	end
	return ready
end

local function hasMultipleRaids(info)
	local first
	for _, entry in ipairs(info and info.encounters or {}) do
		if first and first ~= entry.instanceID then return true end
		first = entry.instanceID
	end
	return false
end

local function addRuns(details, threshold)
	if not details or not details.runs then return false end
	blank()
	line(native("WEEKLY_REWARDS_MYTHIC_TOP_RUNS", threshold))
	local ready = true
	for i = 1, math.min(threshold, #details.runs) do
		local run = details.runs[i]
		local name = staticInfo(C_ChallengeMode and C_ChallengeMode.GetMapUIInfo, run.mapID)
		if name then line(native("WEEKLY_REWARDS_MYTHIC_RUN_INFO", run.level, name))
		else ready = false end
	end
	local remaining = math.min(64, threshold - #details.runs)
	if remaining > 0 then
		if details.mythicCount == nil or details.heroicCount == nil then return false end
		local mythic = math.min(remaining, details.mythicCount)
		for i = 1, mythic do line(native("WEEKLY_REWARDS_MYTHIC", 0)) end
		remaining = remaining - mythic
		for i = 1, math.min(remaining, details.heroicCount) do line(native("WEEKLY_REWARDS_HEROIC")) end
	end
	return ready
end

local function lowestDungeonLevel(details, threshold)
	if not details or not details.runs or details.heroicCount == nil
		or details.mythicCount == nil or details.mythicPlusCount == nil then return nil end
	if threshold > details.mythicPlusCount and details.heroicCount + details.mythicCount > 0 then
		if threshold > details.mythicPlusCount + details.mythicCount and details.heroicCount > 0 then return -1 end
		return 0
	end
	local run = details.runs[math.min(threshold, #details.runs)]
	return run and run.level
end

local function addWorld(details, threshold)
	if not details or not details.worldTiers then return false end
	blank()
	line(native("WEEKLY_REWARDS_WORLD_TOP_ACTIVITIES", threshold))
	local remaining = threshold
	for _, tier in ipairs(details.worldTiers) do
		local count = math.min(tier.numPoints, remaining)
		if count > 0 then
			line(native(tier.difficulty > 1 and "WEEKLY_REWARDS_DELVE_TIER_INFO"
				or "WEEKLY_REWARDS_DELVE_TIER_AND_WORLD_INFO", tier.difficulty, count))
			remaining = remaining - count
		end
		if remaining <= 0 then break end
	end
	return true
end

local function incomplete(cell, details, info)
	local slot, key = cell.slot, cell.rowDefinition.key
	local remaining = math.max(0, slot.threshold - slot.progress)
	local index = slot.activityIndex or cell.column
	if key == "raid" then
		if hasMultipleRaids(info) and details and details.seasonText then
			blank(); line(details.seasonText)
		end
		line(native(slot.progress == 0 and "GREAT_VAULT_REWARDS_RAID_INCOMPLETE"
			or "GREAT_VAULT_REWARDS_RAID_INPROGRESS", remaining), GOLD)
		return addEncounters(info)
	elseif key == "world" then
		local description = index == 2 and "GREAT_VAULT_REWARDS_WORLD_COMPLETED_FIRST"
			or index == 3 and "GREAT_VAULT_REWARDS_WORLD_COMPLETED_SECOND"
			or "GREAT_VAULT_REWARDS_WORLD_INCOMPLETE"
		line(native(description, remaining), GOLD)
		return slot.progress == 0 or addWorld(details, slot.threshold)
	end
	if index == 1 then
		line(native("GREAT_VAULT_REWARDS_MYTHIC_INCOMPLETE"), GOLD)
	else
		line(native(index == 2 and "GREAT_VAULT_REWARDS_MYTHIC_COMPLETED_FIRST"
			or "GREAT_VAULT_REWARDS_MYTHIC_COMPLETED_SECOND", remaining), GOLD)
	end
	if slot.progress == 0 then return true end
	local lowest = lowestDungeonLevel(details, slot.threshold)
	if lowest ~= nil then
		blank()
		line(lowest == -1 and native("GREAT_VAULT_REWARDS_CURRENT_LEVEL_HEROIC", slot.threshold)
			or native("GREAT_VAULT_REWARDS_CURRENT_LEVEL_MYTHIC", slot.threshold, lowest), GOLD)
	end
	local runsReady = addRuns(details, slot.threshold)
	return lowest ~= nil and runsReady
end

local function completed(cell, details, info)
	local slot, key = cell.slot, cell.rowDefinition.key
	if not info or not info.itemLevel then return false end
	local ready = info.rewardInfoReady == true
	local level, upgrade = info.itemLevel, info.upgradeItemLevel
	if key == "raid" then
		local difficulty = difficultyName(info.difficultyID)
		if not difficulty then return false end
		line(native("WEEKLY_REWARDS_ITEM_LEVEL_RAID", level, difficulty), GOLD)
		blank()
		if upgrade then
			local nextDifficulty = difficultyName(info.nextDifficultyID)
			if nextDifficulty then
				line(native("WEEKLY_REWARDS_IMPROVE_ITEM_LEVEL", upgrade), GREEN)
				line(native("WEEKLY_REWARDS_COMPLETE_RAID", nextDifficulty))
				ready = addEncounters(info) and ready
			else ready = false end
		end
	elseif key == "world" then
		if slot.activityLevel == nil then return false end
		line(native("WEEKLY_REWARDS_ITEM_LEVEL_WORLD", level, slot.activityLevel), GOLD)
		blank()
		if upgrade and info.nextLevel then
			line(native("WEEKLY_REWARDS_IMPROVE_ITEM_LEVEL", upgrade), GREEN)
			line(native("WEEKLY_REWARDS_COMPLETE_WORLD", info.nextLevel))
		elseif upgrade then ready = false end
		ready = addWorld(details, slot.threshold) and ready
	else
		if slot.activityLevel == nil or info.difficultyID == nil then return false end
		local heroicID = DifficultyUtil and DifficultyUtil.ID and DifficultyUtil.ID.DungeonHeroic
		local heroic = info.difficultyID == heroicID
		line(heroic and native("WEEKLY_REWARDS_ITEM_LEVEL_HEROIC", level)
			or native("WEEKLY_REWARDS_ITEM_LEVEL_MYTHIC", level, slot.activityLevel), GOLD)
		blank()
		if upgrade and info.nextLevel then
			line(native("WEEKLY_REWARDS_IMPROVE_ITEM_LEVEL", upgrade), GREEN)
			if slot.threshold == 1 then
				line(heroic and native("WEEKLY_REWARDS_COMPLETE_HEROIC_SHORT")
					or native("WEEKLY_REWARDS_COMPLETE_MYTHIC_SHORT", info.nextLevel))
			else
				line(native("WEEKLY_REWARDS_COMPLETE_MYTHIC", info.nextLevel, slot.threshold))
				ready = addRuns(details, slot.threshold) and ready
			end
		elseif upgrade then ready = false end
	end
	if info.rewardInfoReady and not upgrade then line(native("WEEKLY_REWARDS_MAXED_REWARD"), GREEN) end
	return ready
end

function Tooltip:Show(cell)
	if not GameTooltip then return end
	GameTooltip:SetOwner(cell, "ANCHOR_RIGHT", -7, -11)
	local title = native(cell.complete and "WEEKLY_REWARDS_CURRENT_REWARD" or "WEEKLY_REWARDS_UNLOCK_REWARD")
		or localized("MPLUS_GREAT_VAULT", "宏伟宝库")
	if GameTooltip_SetTitle then GameTooltip_SetTitle(GameTooltip, title)
	else GameTooltip:SetText(title, 1, 1, 1) end
	if not cell.slot then
		local key = cell.state == "stale" and "MPLUS_VAULT_STALE"
			or cell.state == "unavailable" and "MPLUS_VAULT_UNAVAILABLE" or "MPLUS_VAULT_MISSING"
		line(localized(key, "暂无宏伟宝库记录，请登录此角色采集进度。"), GRAY)
	else
		local details = cell.vaultRow and cell.vaultRow.details
		local info = details and details.slots[cell.column]
		local ready
		if cell.complete then ready = completed(cell, details, info)
		else ready = incomplete(cell, details, info) end
		if not ready then
			blank()
			line(localized("MPLUS_VAULT_DETAILS_MISSING", "奖励详情尚未记录，请登录此角色更新宏伟宝库信息。"), GRAY)
		end
	end
	GameTooltip:Show()
end
