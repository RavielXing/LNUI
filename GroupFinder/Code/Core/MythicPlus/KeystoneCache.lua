local _, GF = ...

GF.MythicPlusKeystoneCache = GF.MythicPlusKeystoneCache or {}
local Cache = GF.MythicPlusKeystoneCache
local Util = GF.MythicPlusServiceUtil
local EMPTY_CONFIRMATION_DELAY = 1
local MAX_UNAVAILABLE_RETRIES = 5
local COMPLETION_RECHECK_REASON = "MYTHIC_PLUS_COMPLETION_RECHECK"
local COMPLETION_RECHECK_DELAYS = { 0.5, 2, 5 }
local INVENTORY_RECHECK_DELAYS = { 0.5, 2 }

local function isKeystoneLink(itemLink)
	if type(itemLink) ~= "string" or itemLink == "" then
		return false
	end
	if itemLink:find("|Hkeystone:", 1, true) then
		return true
	end
	local itemID
	if C_Item and C_Item.GetItemInfoInstant then
		itemID = C_Item.GetItemInfoInstant(itemLink)
	elseif GetItemInfoInstant then
		itemID = GetItemInfoInstant(itemLink)
	end
	if itemID and C_Item and C_Item.IsItemKeystoneByID then
		local ok, result = pcall(C_Item.IsItemKeystoneByID, itemID)
		if ok and result then
			return true
		end
	end
	return itemID == 180653 or itemID == 186159
end

local function scanKeystoneLink()
	if not C_Container then
		return nil, false
	end
	local firstBag = BACKPACK_CONTAINER or 0
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	local inspectedBag = false
	local scanReady = C_Container.GetContainerNumSlots ~= nil
		and C_Container.GetContainerItemLink ~= nil
	for bagID = firstBag, lastBag do
		local slots = 0
		if C_Container.GetContainerNumSlots then
			local ok, value = pcall(C_Container.GetContainerNumSlots, bagID)
			if ok and tonumber(value) then
				slots = tonumber(value)
				inspectedBag = true
			else
				scanReady = false
			end
		else
			scanReady = false
		end
		for slotIndex = 1, slots do
			local itemID
			if C_Container.GetContainerItemID then
				local idOK, value = pcall(C_Container.GetContainerItemID, bagID, slotIndex)
				if idOK then
					itemID = value
				else
					scanReady = false
				end
			end
			local itemLink
			if C_Container.GetContainerItemLink then
				local ok, value = pcall(C_Container.GetContainerItemLink, bagID, slotIndex)
				if ok then
					itemLink = value
					if itemID and not itemLink then
						scanReady = false
					end
				else
					scanReady = false
				end
			end
			if isKeystoneLink(itemLink) then
				return itemLink, true
			end
		end
	end
	return nil, inspectedBag and scanReady
end

local function getKeystoneLinkFields(keystoneLink)
	if type(keystoneLink) ~= "string" or keystoneLink == "" then
		return nil
	end
	local payload = keystoneLink:match("|Hkeystone:([^|]+)|h")
		or keystoneLink:match("keystone:([^|]+)")
	if not payload then
		return nil
	end
	local fields = {}
	for value in payload:gmatch("([^:]+)") do
		fields[#fields + 1] = value
	end
	return fields
end

local function resolveDisplayLevelAndTrack(keystoneLink, fallbackLevel)
	local fields = getKeystoneLinkFields(keystoneLink)
	if type(fields) ~= "table" then
		return tonumber(fallbackLevel), nil
	end
	local mythicLevel = tonumber(fields[3])
	local ironLevel = tonumber(fields[#fields])
	if mythicLevel and mythicLevel <= 0 then
		mythicLevel = nil
	end
	if ironLevel and ironLevel <= 0 then
		ironLevel = nil
	end
	if mythicLevel and ironLevel then
		if mythicLevel > ironLevel then
			return mythicLevel, "mythic"
		end
		return ironLevel, "iron"
	end
	if mythicLevel then
		return mythicLevel, "mythic"
	end
	if ironLevel then
		return ironLevel, "iron"
	end
	return tonumber(fallbackLevel), nil
end

local function resolveChallengeModeID(keystoneLink, fallbackChallengeModeID)
	local fields = getKeystoneLinkFields(keystoneLink)
	local linkChallengeModeID = fields and tonumber(fields[2])
	if linkChallengeModeID and linkChallengeModeID > 0 then
		return linkChallengeModeID
	end
	return tonumber(fallbackChallengeModeID)
end

local function getMapName(challengeModeID)
	if not (challengeModeID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then
		return nil
	end
	local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, challengeModeID)
	return ok and name or nil
end

function Cache:AddListener(callback)
	Util.AddListener(self, callback)
end

function Cache:GetSnapshot()
	return self.snapshot
end

function Cache:RequestRefresh(reason, delay)
	if self.refreshTimer and self.refreshTimer.Cancel then
		self.refreshTimer:Cancel()
	end
	local function run()
		self.refreshTimer = nil
		self:Refresh(reason)
	end
	delay = tonumber(delay) or 0
	if delay > 0 and C_Timer and C_Timer.NewTimer then
		self.refreshTimer = C_Timer.NewTimer(delay, run)
	elseif C_Timer and C_Timer.After then
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
			self:RequestRefresh(COMPLETION_RECHECK_REASON)
		end)
	end
end

function Cache:QueueInventoryRechecks(reason)
	self.inventoryRecheckTicket =
		(tonumber(self.inventoryRecheckTicket) or 0) + 1
	local ticket = self.inventoryRecheckTicket
	local refreshReason = reason or "BAG_UPDATE_DELAYED"
	if not (C_Timer and C_Timer.After) then
		self:RequestRefresh(refreshReason)
		return
	end
	for _, delay in ipairs(INVENTORY_RECHECK_DELAYS) do
		C_Timer.After(delay, function()
			if self.inventoryRecheckTicket ~= ticket then
				return
			end
			self:RequestRefresh(refreshReason)
		end)
	end
end

function Cache:Refresh(reason)
	local challengeModeID
	local level
	if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID then
		local ok, value = pcall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
		if ok then
			challengeModeID = tonumber(value)
		end
	end
	if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel then
		local ok, value = pcall(C_MythicPlus.GetOwnedKeystoneLevel)
		if ok then
			level = tonumber(value)
		end
	end
	local keystoneLink, bagScanReady = scanKeystoneLink()
	challengeModeID = resolveChallengeModeID(keystoneLink, challengeModeID)
	local displayLevel, keyUpgradeTrack = resolveDisplayLevelAndTrack(keystoneLink, level)
	if displayLevel and displayLevel > 0 then
		level = displayLevel
	end
	if not level or level <= 0 or not challengeModeID or challengeModeID <= 0 then
		challengeModeID = nil
		level = nil
	end
	if not challengeModeID then
		local previous = self.snapshot
		if bagScanReady then
			self.emptyConfirmations = (tonumber(self.emptyConfirmations) or 0) + 1
			self.unavailableRetries = 0
		else
			self.emptyConfirmations = 0
			self.unavailableRetries = (tonumber(self.unavailableRetries) or 0) + 1
		end
		local authoritativeEmpty = previous and previous.state == "empty"
			or bagScanReady and self.emptyConfirmations >= 2
		if not authoritativeEmpty then
			local pending = {
				state = "pending",
				updatedAt = Util.Now(),
				reason = reason,
			}
			if previous and previous.state == "ready" then
				for key, value in pairs(previous) do
					if pending[key] == nil then
						pending[key] = value
					end
				end
				pending.state = "pending"
				pending.updatedAt = Util.Now()
				pending.reason = reason
			end
			self.snapshot = pending
			if bagScanReady or self.unavailableRetries < MAX_UNAVAILABLE_RETRIES then
				self:RequestRefresh("empty-confirm", EMPTY_CONFIRMATION_DELAY)
			end
			Util.Notify(self, reason or "pending")
			return
		end
	else
		self.emptyConfirmations = 0
		self.unavailableRetries = 0
	end
	local dungeon = GF.MythicPlusSeason and GF.MythicPlusSeason:GetByChallengeModeID(challengeModeID)
	self.snapshot = {
		state = challengeModeID and "ready" or "empty",
		challengeModeID = challengeModeID,
		level = level,
		dungeonName = (dungeon and dungeon.name) or getMapName(challengeModeID),
		activityID = dungeon and dungeon.activityID or nil,
		groupID = dungeon and dungeon.groupID or nil,
		keystoneLink = keystoneLink,
		keyUpgradeTrack = keyUpgradeTrack,
		updatedAt = Util.Now(),
		reason = reason,
	}
	Util.Notify(self, reason or "refresh")
end
