local _, GF = ...

GF.MythicPlusServices = GF.MythicPlusServices or {}
local Hub = GF.MythicPlusServices

local KEYSTONE_EVENTS = {
	BAG_UPDATE = true,
	BAG_UPDATE_DELAYED = true,
	ITEM_CHANGED = true,
	CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN = true,
	CHALLENGE_MODE_KEYSTONE_SLOTTED = true,
	CHALLENGE_MODE_START = true,
	CHALLENGE_MODE_RESET = true,
}

local KEYSTONE_INVENTORY_RECHECK_EVENTS = {
	BAG_UPDATE_DELAYED = true,
	ITEM_CHANGED = true,
}

local FULL_REFRESH_EVENTS = {
	PLAYER_ENTERING_WORLD = true,
	CHALLENGE_MODE_COMPLETED = true,
	CHALLENGE_MODE_COMPLETED_REWARDS = true,
	MYTHIC_PLUS_CURRENT_AFFIX_UPDATE = true,
	WEEKLY_REWARDS_UPDATE = true,
}

local COMPLETION_EVENTS = {
	CHALLENGE_MODE_COMPLETED = true,
	CHALLENGE_MODE_COMPLETED_REWARDS = true,
}

local COMPLETION_RATING_REFRESH_DELAY = 0.75

local ROSTER_EVENTS = {
	GROUP_ROSTER_UPDATE = true,
	PARTY_LEADER_CHANGED = true,
	PLAYER_ROLES_ASSIGNED = true,
	UNIT_CONNECTION = true,
}

local TELEPORT_EVENTS = {
	SPELL_UPDATE_COOLDOWN = true,
	SPELLS_CHANGED = true,
}

local TELEPORT_CAST_EVENTS = {
	UNIT_SPELLCAST_START = true,
	UNIT_SPELLCAST_SUCCEEDED = true,
	UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_FAILED_QUIET = true,
}

local function syncCharacter(reason)
	if GF.MythicPlusCharacterStore then
		GF.MythicPlusCharacterStore:RefreshCurrent(reason)
	end
end

function Hub:QueueCompletionRatingRefresh(reason)
	local ratingCache = GF.MythicPlusRatingCache
	if not (ratingCache and ratingCache.RefreshRoster) then
		return false
	end
	if self.completionRatingTimer
		or self.completionRatingCycleConsumed
	then
		return false
	end
	self.completionRatingCycleConsumed = true
	local function run()
		self.completionRatingTimer = nil
		ratingCache:RefreshRoster(reason or "challenge-completed")
	end
	if C_Timer and C_Timer.NewTimer then
		self.completionRatingTimer =
			C_Timer.NewTimer(COMPLETION_RATING_REFRESH_DELAY, run)
	else
		run()
	end
	return true
end

function Hub:RequestAll(reason)
	syncCharacter(reason)
	if GF.MythicPlusSeason then
		GF.MythicPlusSeason:RequestRefresh(reason)
	end
	if GF.MythicPlusTeleportService then
		GF.MythicPlusTeleportService:RequestRefresh(reason)
	end
	if GF.MythicPlusKeystoneCache then
		GF.MythicPlusKeystoneCache:RequestRefresh(reason)
	end
	if GF.MythicPlusRatingCache then
		GF.MythicPlusRatingCache:RequestRoster(reason)
	end
	if GF.MythicPlusWeeklyCache then
		GF.MythicPlusWeeklyCache:RequestRefresh(reason)
	end
	if GF.MythicPlusRosterCache then
		GF.MythicPlusRosterCache:RequestRefresh(reason)
	end
	if GF.MythicPlusCurrentRoleService then
		GF.MythicPlusCurrentRoleService:RequestRefresh(reason)
	end
	if GF.MythicPlusTalentLoadoutService then
		GF.MythicPlusTalentLoadoutService:RequestRefresh(reason)
	end
	if GF.MythicPlusGroupSnapshotService
		and GF.MythicPlusGroupSnapshotService.RequestSync then
		GF.MythicPlusGroupSnapshotService:RequestSync(reason)
	end
	if GF.MythicPlusKeystoneInteropService
		and GF.MythicPlusKeystoneInteropService.RequestSync
	then
		GF.MythicPlusKeystoneInteropService:RequestSync(reason)
	end
	if GF.MythicPlusRatingCache and GF.MythicPlusRatingCache.PrimeStoredScoreColors then
		GF.MythicPlusRatingCache:PrimeStoredScoreColors()
	end
end

function Hub:RefreshRosterWorkspace(listKind, reason)
	if GF.MythicPlusRosterSort and GF.MythicPlusRosterSort.Reset then
		GF.MythicPlusRosterSort:Reset(listKind)
	end
	self:RequestAll(reason or ((listKind or "group") .. "-page"))
end

function Hub:Init()
	if self.initialized then
		return
	end
	self.initialized = true

	if GF.MythicPlusAnnouncementService
		and GF.MythicPlusAnnouncementService.Init
	then
		GF.MythicPlusAnnouncementService:Init()
	end
	if GF.MythicPlusTeleportFollowService
		and GF.MythicPlusTeleportFollowService.Init
	then
		GF.MythicPlusTeleportFollowService:Init()
	end
	if GF.MythicPlusSeason then
		GF.MythicPlusSeason:AddListener(function()
			local seasonID = GF.MythicPlusSeason.GetSeasonID
				and GF.MythicPlusSeason:GetSeasonID() or nil
			if GF.MythicPlusRatingCache
				and GF.MythicPlusRatingCache.OnSeasonChanged
			then
				GF.MythicPlusRatingCache:OnSeasonChanged("season", seasonID)
			end
			if GF.MythicPlusGroupSnapshotService
				and GF.MythicPlusGroupSnapshotService.OnSeasonChanged
			then
				GF.MythicPlusGroupSnapshotService:OnSeasonChanged(
					"season",
					seasonID)
			end
			if GF.MythicPlusKeystoneCache then
				GF.MythicPlusKeystoneCache:RequestRefresh("season")
			end
			if GF.MythicPlusTeleportService then
				GF.MythicPlusTeleportService:RequestRefresh("season")
			end
		end)
	end
	if GF.MythicPlusKeystoneCache then
		GF.MythicPlusKeystoneCache:AddListener(function()
			syncCharacter("keystone")
		end)
	end
	if GF.MythicPlusRatingCache then
		GF.MythicPlusRatingCache:AddListener(function()
			syncCharacter("rating")
			if GF.MythicPlusGroupSnapshotService
				and GF.MythicPlusGroupSnapshotService.QueueBroadcast
			then
				GF.MythicPlusGroupSnapshotService:QueueBroadcast("rating")
			end
			if GF.MythicPlusRosterCache then
				GF.MythicPlusRosterCache:RequestRefresh("rating")
			end
		end)
	end
	if GF.MythicPlusWeeklyCache then
		GF.MythicPlusWeeklyCache:AddListener(function()
			syncCharacter("weekly")
		end)
	end
	if GF.MythicPlusCharacterStore then
		GF.MythicPlusCharacterStore:AddListener(function(_, reason)
			if reason == "rating" or reason == "weekly" then
				return
			end
			if GF.MythicPlusRosterCache then
				GF.MythicPlusRosterCache:RequestRefresh("character")
			end
		end)
	end
	syncCharacter("service-init")
	if GF.MythicPlusCurrentRoleService and GF.MythicPlusCurrentRoleService.Init then
		GF.MythicPlusCurrentRoleService:Init()
	end
	if GF.MythicPlusTalentLoadoutService
		and GF.MythicPlusTalentLoadoutService.Init
	then
		GF.MythicPlusTalentLoadoutService:Init()
	end
	if GF.MythicPlusDebugService and GF.MythicPlusDebugService.Init then
		GF.MythicPlusDebugService:Init()
	end
	if GF.MythicPlusGroupSnapshotService and GF.MythicPlusGroupSnapshotService.Init then
		GF.MythicPlusGroupSnapshotService:Init()
	end
	if GF.MythicPlusKeystoneInteropService
		and GF.MythicPlusKeystoneInteropService.Init
	then
		GF.MythicPlusKeystoneInteropService:Init()
	end
	if GF.MythicPlusCarpoolView and GF.MythicPlusCarpoolView.Init then
		GF.MythicPlusCarpoolView:Init()
	end

	self.eventFrame = CreateFrame("Frame")
	for event in pairs(KEYSTONE_EVENTS) do
		self.eventFrame:RegisterEvent(event)
	end
	for event in pairs(FULL_REFRESH_EVENTS) do
		self.eventFrame:RegisterEvent(event)
	end
	for event in pairs(ROSTER_EVENTS) do
		self.eventFrame:RegisterEvent(event)
	end
	for event in pairs(TELEPORT_EVENTS) do
		self.eventFrame:RegisterEvent(event)
	end
	for event in pairs(TELEPORT_CAST_EVENTS) do
		self.eventFrame:RegisterEvent(event)
	end
	self.eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
	self.eventFrame:RegisterEvent("ADDON_LOADED")
	self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.eventFrame:SetScript("OnEvent", function(_, event, ...)
		if event == "ADDON_LOADED" then
			if GF.MythicPlusKeystoneInteropService
				and GF.MythicPlusKeystoneInteropService.TryAttachLibraries
			then
				local attached =
					GF.MythicPlusKeystoneInteropService:TryAttachLibraries()
				if attached then
					GF.MythicPlusKeystoneInteropService.lastRequestAt = nil
					GF.MythicPlusKeystoneInteropService:RequestSync(
						"interop-library-loaded")
				end
			end
		elseif KEYSTONE_EVENTS[event] then
			if event == "CHALLENGE_MODE_START"
				or event == "CHALLENGE_MODE_RESET"
			then
				Hub.completionRatingCycleConsumed = nil
			end
			GF.MythicPlusKeystoneCache:RequestRefresh(event, 0.25)
			if KEYSTONE_INVENTORY_RECHECK_EVENTS[event]
				and GF.MythicPlusKeystoneCache.QueueInventoryRechecks
			then
				GF.MythicPlusKeystoneCache:QueueInventoryRechecks(event)
			end
			if event == "CHALLENGE_MODE_RESET"
				and GF.MythicPlusKeystoneInteropService
				and GF.MythicPlusKeystoneInteropService.OnSafeToRequest
			then
				GF.MythicPlusKeystoneInteropService:OnSafeToRequest(event)
			end
			elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
				local needsRetry = GF.MythicPlusSeason:Refresh(event)
				if needsRetry
					and GF.MythicPlusSeason.StartReadinessRetries
				then
					GF.MythicPlusSeason:StartReadinessRetries(event)
				end
		elseif FULL_REFRESH_EVENTS[event] then
			Hub:RequestAll(event)
			if COMPLETION_EVENTS[event]
			then
				Hub:QueueCompletionRatingRefresh(event)
				if GF.MythicPlusKeystoneCache
					and GF.MythicPlusKeystoneCache.QueueCompletionRechecks
				then
					GF.MythicPlusKeystoneCache:QueueCompletionRechecks()
				end
			end
			if event == "PLAYER_ENTERING_WORLD"
				and GF.MythicPlusTeleportFollowService
				and GF.MythicPlusTeleportFollowService.OnRosterChanged
			then
				GF.MythicPlusTeleportFollowService:OnRosterChanged(event)
			end
		elseif ROSTER_EVENTS[event] then
			if event == "UNIT_CONNECTION"
				and GF.MythicPlusRosterCache.OnUnitConnection
			then
				GF.MythicPlusRosterCache:OnUnitConnection(...)
			else
				GF.MythicPlusRosterCache:RequestRefresh(event)
			end
			if event == "GROUP_ROSTER_UPDATE"
				and GF.MythicPlusRatingCache
				and GF.MythicPlusRatingCache.OnRosterChanged
			then
				GF.MythicPlusRatingCache:OnRosterChanged(event)
			elseif event == "UNIT_CONNECTION"
				and GF.MythicPlusRatingCache
				and GF.MythicPlusRatingCache.OnUnitConnection
			then
				local unitTarget, isConnected = ...
				GF.MythicPlusRatingCache:OnUnitConnection(
					unitTarget,
					isConnected,
					event)
			end
			if GF.MythicPlusGroupSnapshotService
				and GF.MythicPlusGroupSnapshotService.OnRosterChanged then
				GF.MythicPlusGroupSnapshotService:OnRosterChanged(event, ...)
			end
			if GF.MythicPlusKeystoneInteropService
				and GF.MythicPlusKeystoneInteropService.OnRosterChanged
			then
				GF.MythicPlusKeystoneInteropService:OnRosterChanged(
					event, ...)
			end
			if GF.MythicPlusTeleportFollowService
				and GF.MythicPlusTeleportFollowService.OnRosterChanged
			then
				GF.MythicPlusTeleportFollowService:OnRosterChanged(event)
			end
		elseif TELEPORT_EVENTS[event] then
			GF.MythicPlusTeleportService:RequestRefresh(event)
		elseif TELEPORT_CAST_EVENTS[event] then
			GF.MythicPlusTeleportService:HandleUnitSpellcast(event, ...)
			if GF.MythicPlusTeleportFollowService
				and GF.MythicPlusTeleportFollowService.HandlePlayerSpellcast
			then
				GF.MythicPlusTeleportFollowService:HandlePlayerSpellcast(
					event, ...)
			end
		elseif event == "PLAYER_REGEN_ENABLED" then
			GF.MythicPlusTeleportService:FlushPending()
			GF.MythicPlusTeleportService:RequestRefresh(event)
			if GF.MythicPlusKeystoneInteropService
				and GF.MythicPlusKeystoneInteropService.OnSafeToRequest
			then
				GF.MythicPlusKeystoneInteropService:OnSafeToRequest(event)
			end
		elseif event == "PLAYER_SPECIALIZATION_CHANGED" and (...) == "player" then
			syncCharacter(event)
			if GF.MythicPlusCurrentRoleService then
				GF.MythicPlusCurrentRoleService:RequestRefresh(event)
			end
		end
	end)

	self:RequestAll("init")
end
