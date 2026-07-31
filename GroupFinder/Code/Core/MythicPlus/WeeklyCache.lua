local _, GF = ...

GF.MythicPlusWeeklyCache = GF.MythicPlusWeeklyCache or {}
local Cache = GF.MythicPlusWeeklyCache
local Util = GF.MythicPlusServiceUtil

local DEFAULT_THRESHOLDS = { 1, 4, 8 }

local function getActiveSeasonState()
	local displaySeasonID
	if C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonID then
		local ok, value = pcall(C_SeasonInfo.GetCurrentDisplaySeasonID)
		if ok then
			displaySeasonID = tonumber(value)
		end
	end
	local hasActiveSeason = displaySeasonID ~= nil and displaySeasonID > 0
	return displaySeasonID, hasActiveSeason
end

local function getGreatVaultState()
	local displaySeasonID, hasActiveSeason = getActiveSeasonState()
	local hasAvailableRewards = false
	if hasActiveSeason
		and C_WeeklyRewards
		and C_WeeklyRewards.HasAvailableRewards
	then
		local ok, value = pcall(C_WeeklyRewards.HasAvailableRewards)
		hasAvailableRewards = ok and value == true
	end
	return displaySeasonID, hasActiveSeason, hasAvailableRewards
end

local function getVaultThresholds()
	local thresholds = {}
	local seen = {}
	local mythicPlusType = Enum and Enum.WeeklyRewardChestThresholdType
		and Enum.WeeklyRewardChestThresholdType.Activities
	if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
		local ok, activities = pcall(C_WeeklyRewards.GetActivities, mythicPlusType)
		if ok and type(activities) == "table" then
			for _, activity in ipairs(activities) do
				local threshold = tonumber(activity and activity.threshold)
				if threshold and threshold > 0 and not seen[threshold] then
					seen[threshold] = true
					thresholds[#thresholds + 1] = threshold
				end
			end
		end
	end
	if #thresholds == 0 then
		return Util.CopyArray(DEFAULT_THRESHOLDS)
	end
	table.sort(thresholds)
	return thresholds
end

function Cache:AddListener(callback)
	Util.AddListener(self, callback)
end

function Cache:GetSnapshot()
	return self.snapshot
end

function Cache:GetVaultSnapshot()
	return self.vaultSnapshot
end

function Cache:OpenGreatVault()
	if InCombatLockdown and InCombatLockdown() then
		return false, "combat"
	end
	local _, hasActiveSeason = getActiveSeasonState()
	if not hasActiveSeason then
		return false, "inactive-season"
	end
	if type(WeeklyRewards_ShowUI) ~= "function" then
		return false, "unavailable"
	end
	local ok = pcall(WeeklyRewards_ShowUI)
	if not ok then
		return false, "unavailable"
	end
	return true
end

function Cache:RequestRefresh(reason)
	if self.refreshQueued then
		return
	end
	self.refreshQueued = true
	local function run()
		self.refreshQueued = nil
		self:Refresh(reason)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		run()
	end
end

function Cache:Refresh(reason)
	local displaySeasonID, hasActiveSeason, hasAvailableRewards =
		getGreatVaultState()
	local updatedAt = Util.Now()
	local thresholds = getVaultThresholds()
	local runs = {}
	local historyReady = false
	if C_MythicPlus and C_MythicPlus.GetRunHistory then
		local ok, history = pcall(C_MythicPlus.GetRunHistory, false, true, true)
		if ok and type(history) == "table" then
			historyReady = true
			for _, run in ipairs(history) do
				local mapID = tonumber(run and run.mapChallengeModeID)
				local level = tonumber(run and run.level)
				if mapID and level and level > 0 then
					runs[#runs + 1] = {
						mapID = mapID,
						level = level,
						timed = run.completed == true,
						score = tonumber(run.runScore) or 0,
					}
				end
			end
		end
	end
	table.sort(runs, function(a, b)
		if a.level ~= b.level then
			return a.level > b.level
		end
		return a.timed and not b.timed
	end)
	local rewards = {}
	for _, threshold in ipairs(thresholds) do
		rewards[#rewards + 1] = {
			threshold = threshold,
			progress = math.min(#runs, threshold),
			run = runs[threshold],
		}
	end
	self.vaultSnapshot = {
		displaySeasonID = displaySeasonID,
		hasActiveSeason = hasActiveSeason,
		hasAvailableRewards = hasAvailableRewards,
		rewardReady = hasAvailableRewards,
		updatedAt = updatedAt,
		reason = reason,
	}
	self.snapshot = {
		state = historyReady and "ready" or "unavailable",
		runs = runs,
		rewards = rewards,
		completedRuns = #runs,
		updatedAt = updatedAt,
		reason = reason,
	}
	Util.Notify(self, reason or "refresh")
end
