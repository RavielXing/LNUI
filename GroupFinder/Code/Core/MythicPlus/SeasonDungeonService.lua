local _, GF = ...

GF.MythicPlusSeason = GF.MythicPlusSeason or {}
local Season = GF.MythicPlusSeason
local Association = GF.MythicPlusSeasonAssociation
local Catalog = GF.MythicPlusSeasonCatalog
local Util = GF.MythicPlusServiceUtil

local READINESS_RETRY_DELAYS = { 0.75, 2, 5 }

local function appendSignatureField(parts, label, value)
	parts[#parts + 1] = tostring(label)
	parts[#parts + 1] = value == nil and "" or tostring(value)
end

local function buildSemanticSignature(dungeons, status, source, seasonID)
	local parts = {}
	appendSignatureField(parts, "status", status)
	appendSignatureField(parts, "source", source)
	appendSignatureField(parts, "seasonID", seasonID)
	appendSignatureField(parts, "dungeonCount", #dungeons)
	for dungeonIndex, dungeon in ipairs(dungeons) do
		local prefix = string.format("d%d.", dungeonIndex)
		appendSignatureField(parts, prefix .. "key", dungeon.key)
		appendSignatureField(parts, prefix .. "orderIndex", dungeon.orderIndex)
		appendSignatureField(
			parts, prefix .. "challengeModeID", dungeon.challengeModeID)
		appendSignatureField(
			parts, prefix .. "seasonMapOrder", dungeon.seasonMapOrder)
		appendSignatureField(parts, prefix .. "name", dungeon.name)
		appendSignatureField(parts, prefix .. "timeLimit", dungeon.timeLimit)
		appendSignatureField(parts, prefix .. "texture", dungeon.texture)
		appendSignatureField(
			parts, prefix .. "backgroundTexture", dungeon.backgroundTexture)
		appendSignatureField(
			parts, prefix .. "instanceMapID", dungeon.instanceMapID)
		appendSignatureField(parts, prefix .. "groupID", dungeon.groupID)
		appendSignatureField(parts, prefix .. "activityID", dungeon.activityID)
		appendSignatureField(
			parts, prefix .. "journalTexture", dungeon.journalTexture)
		appendSignatureField(
			parts, prefix .. "visualTexture", dungeon.visualTexture)
		appendSignatureField(
			parts, prefix .. "visualSource", dungeon.visualSource)
		appendSignatureField(
			parts, prefix .. "journalInstanceID", dungeon.journalInstanceID)
		appendSignatureField(
			parts, prefix .. "mapInfoReady", dungeon.mapInfoReady and 1 or 0)
		local coordinates = dungeon.visualTexCoords or {}
		appendSignatureField(
			parts, prefix .. "visualTexCoordCount", #coordinates)
		for coordinateIndex, coordinate in ipairs(coordinates) do
			appendSignatureField(parts,
				prefix .. "visualTexCoord" .. coordinateIndex, coordinate)
		end
		local activityIDs = dungeon.activityIDs or {}
		appendSignatureField(parts, prefix .. "activityIDCount", #activityIDs)
		for activityIndex, activityID in ipairs(activityIDs) do
			appendSignatureField(
				parts, prefix .. "activityID" .. activityIndex, activityID)
		end
	end
	return table.concat(parts, "\31")
end

function Season:AddListener(callback)
	Util.AddListener(self, callback)
end

function Season:GetDungeons()
	return self.dungeons or {}
end

function Season:GetByChallengeModeID(challengeModeID)
	return self.byChallengeModeID
		and self.byChallengeModeID[tonumber(challengeModeID)] or nil
end

function Season:GetByActivityID(activityID)
	return self.byActivityID
		and self.byActivityID[tonumber(activityID)] or nil
end

function Season:GetActivityIDs()
	local activityIDs = {}
	local seen = {}
	for _, dungeon in ipairs(self:GetDungeons()) do
		for _, activityID in ipairs(dungeon.activityIDs or {}) do
			activityID = tonumber(activityID)
			if activityID and not seen[activityID] then
				seen[activityID] = true
				activityIDs[#activityIDs + 1] = activityID
			end
		end
	end
	table.sort(activityIDs)
	return activityIDs
end

function Season:ContainsActivityID(activityID)
	return self:GetByActivityID(activityID) ~= nil
end

function Season:GetStatus()
	return self.status or "unavailable"
end

function Season:GetSource()
	return self.source or "unavailable"
end

function Season:GetSeasonID()
	return self.seasonID
end

function Season:CancelReadinessRetries()
	self.readinessRetryTicket = (self.readinessRetryTicket or 0) + 1
	self.readinessRetryActive = nil
end

function Season:StartReadinessRetries(reason)
	if self.readinessRetryActive or not (C_Timer and C_Timer.After) then
		return
	end
	self.readinessRetryActive = true
	self.readinessRetryTicket = (self.readinessRetryTicket or 0) + 1
	local ticket = self.readinessRetryTicket
	local function queue(retryIndex)
		local delay = READINESS_RETRY_DELAYS[retryIndex]
		if not delay then
			self.readinessRetryActive = nil
			return
		end
		C_Timer.After(delay, function()
			if ticket ~= self.readinessRetryTicket then
				return
			end
			if C_MythicPlus and C_MythicPlus.RequestMapInfo then
				pcall(C_MythicPlus.RequestMapInfo)
			end
			local needsRetry = self:Refresh(
				string.format("%s-retry-%d", tostring(reason), retryIndex))
			if needsRetry then
				queue(retryIndex + 1)
			else
				self:CancelReadinessRetries()
			end
		end)
	end
	queue(1)
end

function Season:RequestRefresh(reason)
	if self.refreshQueued then
		return
	end
	self.refreshQueued = true
	if C_MythicPlus and C_MythicPlus.RequestMapInfo then
		pcall(C_MythicPlus.RequestMapInfo)
	end
	local function run()
		self.refreshQueued = nil
		local needsRetry = self:Refresh(reason)
		if needsRetry then
			self:StartReadinessRetries(reason)
		else
			self:CancelReadinessRetries()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		run()
	end
end

function Season:Refresh(reason)
	local dungeons, context = Catalog.Build(self)
	Association.Apply(dungeons)

	local byChallengeModeID = {}
	local byActivityID = {}
	for _, dungeon in ipairs(dungeons) do
		byChallengeModeID[dungeon.challengeModeID] = dungeon
		if dungeon.activityID then
			byActivityID[dungeon.activityID] = dungeon
		end
		for _, activityID in ipairs(dungeon.activityIDs) do
			byActivityID[activityID] = dungeon
		end
	end

	local status
	if #dungeons == 0 then
		status = "unavailable"
	elseif context.source == "challengeMode"
		and context.seasonID
		and context.allMapInfoReady
	then
		status = "ready"
	elseif context.source == "staticFallback" then
		status = "fallback"
	else
		status = "stale"
	end
	local signature = buildSemanticSignature(
		dungeons, status, context.source, context.seasonID)
	local changed = signature ~= self.semanticSignature

	self.dungeons = dungeons
	self.byChallengeModeID = byChallengeModeID
	self.byActivityID = byActivityID
	self.status = status
	self.source = context.source
	self.seasonID = context.seasonID
	self.updatedAt = Util.Now()
	self.reason = reason
	self.semanticSignature = signature

	local needsRetry = context.nativeAPIAvailable
		and (not context.seasonID
			or #context.liveIDs == 0
			or not context.liveCatalogStable
			or context.source ~= "challengeMode"
			or not context.allMapInfoReady)
	if not needsRetry then
		self:CancelReadinessRetries()
	end
	if changed then
		Util.Notify(self, reason or "refresh")
	end
	return needsRetry
end
