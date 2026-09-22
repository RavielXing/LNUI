local _, GF = ...

GF.MythicPlusWeeklyCache = GF.MythicPlusWeeklyCache or {}
local Cache = GF.MythicPlusWeeklyCache
local Util = GF.MythicPlusServiceUtil

local DEFAULT_THRESHOLDS = { 1, 4, 8 }
-- Completion can precede the server's history update. Request fresh map data
-- on bounded retries; GetRunHistory alone only re-reads the client cache.
-- ServiceHub consumes CHALLENGE_MODE_MAPS_UPDATE even after these retries end.
local COMPLETION_RECHECK_REASON = "MYTHIC_PLUS_COMPLETION_RECHECK"
local COMPLETION_RECHECK_DELAYS = { 0.5, 2, 5 }

local function isSecretValue(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return not ok or secret == true
end

local function asPublicNumber(value)
	if value == nil or isSecretValue(value) then
		return nil
	end
	local ok, number = pcall(tonumber, value)
	if not ok or number == nil or isSecretValue(number) then
		return nil
	end
	return number
end

local function queueRewardItemLoad(itemLink)
	if type(itemLink) ~= "string" or isSecretValue(itemLink) then
		return
	end
	if not (Item and type(Item.CreateFromItemLink) == "function") then
		return
	end
	Cache.pendingRewardItemLoads = Cache.pendingRewardItemLoads or {}
	if Cache.pendingRewardItemLoads[itemLink] then
		return
	end
	local ok, item = pcall(Item.CreateFromItemLink, Item, itemLink)
	if not (ok and item and type(item.ContinueOnItemLoad) == "function") then
		return
	end
	Cache.pendingRewardItemLoads[itemLink] = true
	local registered = pcall(item.ContinueOnItemLoad, item, function()
		if Cache.pendingRewardItemLoads then
			Cache.pendingRewardItemLoads[itemLink] = nil
		end
		Cache:RequestRefresh("weekly-reward-item")
	end)
	if not registered then
		Cache.pendingRewardItemLoads[itemLink] = nil
	end
end

local function getExampleRewardItemLevel(activityID)
	activityID = asPublicNumber(activityID)
	if not (
		activityID
		and C_WeeklyRewards
		and C_WeeklyRewards.GetExampleRewardItemHyperlinks
		and C_Item
		and C_Item.GetDetailedItemLevelInfo
	) then
		return nil
	end
	local ok, itemLink = pcall(
		C_WeeklyRewards.GetExampleRewardItemHyperlinks,
		activityID)
	if not ok or type(itemLink) ~= "string" or isSecretValue(itemLink) then
		return nil
	end
	local levelOK, rawItemLevel = pcall(
		C_Item.GetDetailedItemLevelInfo,
		itemLink)
	local itemLevel = levelOK and asPublicNumber(rawItemLevel) or nil
	if itemLevel and itemLevel > 0 then
		return math.floor(itemLevel + 0.5)
	end
	queueRewardItemLoad(itemLink)
	return nil
end

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

local function getVaultActivities()
	local result = {}
	local seen = {}
	local mythicPlusType = Enum and Enum.WeeklyRewardChestThresholdType
		and Enum.WeeklyRewardChestThresholdType.Activities
	if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
		local ok, activities = pcall(C_WeeklyRewards.GetActivities, mythicPlusType)
		if ok and type(activities) == "table" then
			for _, activity in ipairs(activities) do
				local threshold = asPublicNumber(activity and activity.threshold)
				if threshold and threshold > 0 and not seen[threshold] then
					seen[threshold] = true
					local activityID = asPublicNumber(activity and activity.id)
					local activityTierID = asPublicNumber(
						activity and activity.activityTierID)
					result[#result + 1] = {
						threshold = threshold,
						progress = asPublicNumber(activity and activity.progress),
						activityID = activityID,
						activityLevel = asPublicNumber(activity and activity.level),
						activityTierID = activityTierID,
						itemLevel = getExampleRewardItemLevel(activityID),
					}
				end
			end
		end
	end
	local activitiesReady = #result > 0
	if #result == 0 then
		for _, threshold in ipairs(DEFAULT_THRESHOLDS) do
			result[#result + 1] = { threshold = threshold }
		end
	end
	table.sort(result, function(left, right)
		return left.threshold < right.threshold
	end)
	return result, activitiesReady
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

function Cache:QueueCompletionRechecks()
	self.completionRecheckTicket =
		(tonumber(self.completionRecheckTicket) or 0) + 1
	local ticket = self.completionRecheckTicket
	if not (C_Timer and C_Timer.After) then
		self:RequestRefresh(COMPLETION_RECHECK_REASON)
		return
	end
	for _, delay in ipairs(COMPLETION_RECHECK_DELAYS) do
		C_Timer.After(delay, function()
			if self.completionRecheckTicket ~= ticket then
				return
			end
			if C_MythicPlus and C_MythicPlus.RequestMapInfo then
				pcall(C_MythicPlus.RequestMapInfo)
			end
			self:RequestRefresh(COMPLETION_RECHECK_REASON)
		end)
	end
end

function Cache:Refresh(reason)
	local displaySeasonID, hasActiveSeason, hasAvailableRewards =
		getGreatVaultState()
	local updatedAt = Util.Now()
	local activities, activitiesReady = getVaultActivities()
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
	-- Great Vault progress may include non-Mythic+ dungeon sources and may
	-- stop at the highest reward threshold. Keep it separate from #runs,
	-- which is the visible current-week Mythic+ count and detail total.
	local vaultProgress = activitiesReady and 0 or #runs
	for _, activity in ipairs(activities) do
		local threshold = activity.threshold
		local progress = activitiesReady and tonumber(activity.progress) or #runs
		progress = math.max(0, progress or 0)
		vaultProgress = math.max(vaultProgress, progress)
		rewards[#rewards + 1] = {
			threshold = threshold,
			progress = progress,
			run = runs[threshold],
			activityID = activity.activityID,
			activityLevel = activity.activityLevel,
			activityTierID = activity.activityTierID,
			itemLevel = activity.itemLevel,
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
		state = (activitiesReady or historyReady) and "ready" or "unavailable",
		runs = runs,
		rewards = rewards,
		historyReady = historyReady,
		mythicPlusRunCount = historyReady and #runs or nil,
		vaultProgress = vaultProgress,
		updatedAt = updatedAt,
		reason = reason,
	}
	Util.Notify(self, reason or "refresh")
end
