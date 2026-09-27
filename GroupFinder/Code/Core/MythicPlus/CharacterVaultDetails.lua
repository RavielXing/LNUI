local _, GF = ...

local Details = {}
GF.MythicPlusCharacterVaultDetails = Details

local function public(value)
	if type(issecretvalue) ~= "function" then return true end
	local ok, secret = pcall(issecretvalue, value)
	return ok and not secret
end

local function number(value)
	if not public(value) or type(value) ~= "number" then return nil end
	if value ~= value or value < 0 or value == math.huge or value % 1 ~= 0 then return nil end
	return value
end

local function text(value)
	if not public(value) or type(value) ~= "string" or #value > 512 then return nil end
	return value ~= "" and value or nil
end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f = pcall(fn, ...)
	if ok then return a, b, c, d, e, f end
end

local function copyList(list, fields, limit)
	if not public(list) or type(list) ~= "table" then return nil end
	local result = {}
	for i = 1, math.min(#list, limit) do
		local entry = list[i]
		if not public(entry) or type(entry) ~= "table" then return nil end
		local copy = {}
		for _, field in ipairs(fields) do
			copy[field] = number(entry[field])
			if copy[field] == nil then return nil end
		end
		result[#result + 1] = copy
	end
	return result
end

local SLOT_NUMBERS = { "itemLevel", "upgradeItemLevel", "nextLevel", "difficultyID", "nextDifficultyID" }
local ENCOUNTER_FIELDS = { "encounterID", "instanceID", "bestDifficulty", "uiOrder" }

-- Every persisted field is a plain, bounded copy. No links, reward objects,
-- frames, claim state, or native tables are retained.
function Details:Copy(data)
	if not public(data) or type(data) ~= "table"
		or not public(data.version) or data.version ~= 1 then return nil end
	local copy = { version = 1, slots = {}, seasonText = text(data.seasonText) }
	copy.runs = copyList(data.runs, { "mapID", "level" }, 64)
	copy.worldTiers = copyList(data.worldTiers, { "difficulty", "numPoints" }, 64)
	for _, field in ipairs({ "heroicCount", "mythicCount", "mythicPlusCount" }) do
		copy[field] = number(data[field])
	end
	if public(data.slots) and type(data.slots) == "table" then
		for i = 1, 3 do
			local slot = data.slots[i]
			if public(slot) and type(slot) == "table" then
				local target = {}
				for _, field in ipairs(SLOT_NUMBERS) do target[field] = number(slot[field]) end
				if public(slot.rewardInfoReady) and type(slot.rewardInfoReady) == "boolean" then
					target.rewardInfoReady = slot.rewardInfoReady
				end
				target.encounters = copyList(slot.encounters, ENCOUNTER_FIELDS, 128)
				copy.slots[i] = target
			end
		end
	end
	return copy
end

-- Reuse unavailable detail fields only while the entire observed row is
-- unchanged. Never attach an old difficulty/reward to new progress or weeks.
function Details:Merge(freshRow, oldRow)
	local fresh = self:Copy(freshRow.details)
	if not oldRow or freshRow.resetAt ~= oldRow.resetAt
		or freshRow.displaySeasonID ~= oldRow.displaySeasonID then return fresh end
	for i = 1, 3 do
		local a, b = freshRow.slots[i], oldRow.slots[i]
		for _, field in ipairs({ "progress", "threshold", "activityID", "activityIndex", "activityLevel", "activityTierID" }) do
			if a[field] ~= b[field] then return fresh end
		end
	end
	local old = self:Copy(oldRow.details)
	if not old then return fresh end
	if not fresh then return old end
	for _, field in ipairs({ "seasonText", "runs", "worldTiers", "heroicCount", "mythicCount", "mythicPlusCount" }) do
		if fresh[field] == nil then fresh[field] = old[field] end
	end
	for i = 1, 3 do
		local a, b = fresh.slots[i], old.slots[i]
		if not a then
			fresh.slots[i] = b
		elseif b then
			-- Preserve the reward as one unit; an unfinished item load cannot
			-- accidentally turn the old upgrade into a false maximum.
			if not a.rewardInfoReady and b.rewardInfoReady then
				for _, field in ipairs(SLOT_NUMBERS) do a[field] = b[field] end
				a.rewardInfoReady = true
			end
			if not a.encounters then a.encounters = b.encounters end
		end
	end
	return fresh
end

function Details:Capture(key, slots, runs, historyReady, getRewardLevels)
	local api = C_WeeklyRewards or {}
	local data = { version = 1, slots = {} }
	if key == "raid" then
		data.seasonText = text(call(PVPUtil and PVPUtil.GetCurrentSeasonText))
	elseif key == "dungeons" then
		if historyReady then
			data.runs = copyList(runs, { "mapID", "level" }, 64)
			if data.runs then
				table.sort(data.runs, function(a, b)
					if a.level ~= b.level then return a.level > b.level end
					return a.mapID < b.mapID
				end)
			end
		end
		local heroic, mythic, mythicPlus = call(api.GetNumCompletedDungeonRuns)
		data.heroicCount, data.mythicCount, data.mythicPlusCount =
			number(heroic), number(mythic), number(mythicPlus)
	elseif key == "world" then
		local worldType = Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.World
		if worldType then
			data.worldTiers = copyList(call(api.GetSortedProgressForActivity, worldType, true),
				{ "difficulty", "numPoints" }, 64)
		end
	end
	for index, slot in ipairs(slots) do
		local info = {}
		data.slots[index] = info
		if key == "raid" then
			local raidType = Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Raid
			if raidType then
				info.encounters = copyList(call(api.GetActivityEncounterInfo, raidType,
					slot.activityIndex or index), ENCOUNTER_FIELDS, 128)
				if info.encounters and #info.encounters == 0 then info.encounters = nil end
			end
		end
		if slot.progress >= slot.threshold then
			info.itemLevel, info.upgradeItemLevel, info.rewardInfoReady = getRewardLevels(slot.activityID)
			if key == "raid" then
				info.difficultyID = slot.activityLevel
				info.nextDifficultyID = number(call(DifficultyUtil and DifficultyUtil.GetNextPrimaryRaidDifficultyID,
					slot.activityLevel))
			else
				if slot.activityTierID then
					info.difficultyID = number(call(api.GetDifficultyIDForActivityTier, slot.activityTierID))
				end
				local hasData, _, nextLevel, nextItemLevel
				if slot.activityTierID and slot.activityLevel then
					hasData, _, nextLevel, nextItemLevel = call(api.GetNextActivitiesIncrease,
						slot.activityTierID, slot.activityLevel)
				end
				if public(hasData) and hasData == true then
					info.nextLevel = number(nextLevel)
					info.upgradeItemLevel = number(nextItemLevel)
					info.rewardInfoReady = info.itemLevel ~= nil
				elseif slot.activityLevel then
					info.nextLevel = key == "dungeons" and slot.activityLevel == 0
						and 2 or slot.activityLevel + 1
				end
			end
		end
	end
	return self:Copy(data)
end
