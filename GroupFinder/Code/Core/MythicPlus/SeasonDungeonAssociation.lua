local _, GF = ...

GF.MythicPlusSeasonAssociation = GF.MythicPlusSeasonAssociation or {}
local Association = GF.MythicPlusSeasonAssociation
local Util = GF.MythicPlusServiceUtil

local function safeActivityInfo(activityID)
	if not (activityID and C_LFGList and C_LFGList.GetActivityInfoTable) then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
	return ok and type(info) == "table" and info or nil
end

local function getInstanceName(instance, activityID)
	if instance and type(instance.label) == "string" and instance.label ~= "" then
		return instance.label
	end
	if instance and instance.groupID and C_LFGList
		and C_LFGList.GetActivityGroupInfo
	then
		local ok, name = pcall(C_LFGList.GetActivityGroupInfo, instance.groupID)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	local info = safeActivityInfo(activityID)
	return info and (info.shortName or info.fullName) or nil
end

local function findChallengeMap(challengeMaps, instance, instanceName,
	activityID)
	local info = safeActivityInfo(activityID)
	local possibleMapIDs = {
		tonumber(instance and instance.mapID),
		tonumber(instance and instance.instanceMapID),
		tonumber(info and info.mapID),
	}
	for _, challenge in ipairs(challengeMaps) do
		for _, mapID in ipairs(possibleMapIDs) do
			if mapID and challenge.instanceMapID == mapID then
				return challenge
			end
		end
	end
	local nameKeys = {
		Util.NormalizeName(instanceName),
		Util.NormalizeName(info and info.shortName),
		Util.NormalizeName(info and info.fullName),
	}
	for _, challenge in ipairs(challengeMaps) do
		for _, nameKey in ipairs(nameKeys) do
			if nameKey and challenge.nameKey == nameKey then
				return challenge
			end
		end
	end
	return nil
end

local function addActivityID(target, seen, activityID)
	activityID = tonumber(activityID)
	if activityID and not seen[activityID] then
		seen[activityID] = true
		target[#target + 1] = activityID
	end
end

local function buildLFGAssociations(challengeMaps)
	local scopeDungeons = GF.MythicPlusLFGScope
		and GF.MythicPlusLFGScope.GetDungeons
		and GF.MythicPlusLFGScope:GetDungeons() or {}
	local associations = {}
	for _, scopedDungeon in ipairs(scopeDungeons) do
		local instance = scopedDungeon.source or scopedDungeon
		local activityID = tonumber(scopedDungeon.activityID)
		local instanceName = getInstanceName(instance, activityID)
		local challenge = findChallengeMap(
			challengeMaps, instance, instanceName, activityID)
		if challenge then
			local challengeModeID = challenge.challengeModeID
			local association = associations[challengeModeID]
			if not association then
				association = {
					activityIDs = {},
					activityIDSet = {},
				}
				associations[challengeModeID] = association
			end
			association.key = association.key or scopedDungeon.key
			association.orderIndex = association.orderIndex
				or tonumber(scopedDungeon.orderIndex)
				or tonumber(instance.orderIndex)
			association.groupID = association.groupID
				or tonumber(instance.groupID)
			association.activityID = association.activityID or activityID
			association.visualTexture = association.visualTexture
				or instance.visualTexture
			association.visualTexCoords = association.visualTexCoords
				or instance.visualTexCoords
			association.visualSource = association.visualSource
				or instance.visualSource
			addActivityID(
				association.activityIDs,
				association.activityIDSet,
				activityID)
			for _, candidateID in ipairs(scopedDungeon.activityIDs or {}) do
				addActivityID(
					association.activityIDs,
					association.activityIDSet,
					candidateID)
			end
		end
	end
	return associations
end

local function applyJournalVisual(dungeon)
	if not (GF.NavCatalog and GF.NavCatalog.GetJournalInstance) then
		return
	end
	local journalInstance = GF.NavCatalog.GetJournalInstance(
		"dungeon", dungeon.mapID, dungeon.instanceMapID, dungeon.name)
	if not journalInstance then
		return
	end
	dungeon.journalInstanceID = tonumber(journalInstance.journalInstanceID)
	dungeon.journalTexture = journalInstance.visualTexture
	dungeon.visualTexture = journalInstance.visualTexture
	dungeon.visualTexCoords = journalInstance.visualTexCoords
	dungeon.visualSource = journalInstance.visualSource
end

local function applyLFGAssociation(dungeon, association)
	association = association or {}
	dungeon.key = association.key or dungeon.key
	dungeon.orderIndex = association.orderIndex or dungeon.orderIndex
	dungeon.groupID = association.groupID
	dungeon.activityID = association.activityID
	dungeon.activityIDs = Util.CopyArray(association.activityIDs)
	dungeon.visualTexture = association.visualTexture
		or dungeon.visualTexture
		or dungeon.backgroundTexture
		or dungeon.texture
	dungeon.visualTexCoords = association.visualTexCoords
		or dungeon.visualTexCoords
		or dungeon.fallbackTexCoords
	dungeon.visualSource = association.visualSource
		or dungeon.visualSource
		or (dungeon.backgroundTexture and "challengeBackground")
		or (dungeon.texture and "challengeTexture")
		or nil
end

function Association.Apply(dungeons)
	local associations = buildLFGAssociations(dungeons)
	for _, dungeon in ipairs(dungeons) do
		applyJournalVisual(dungeon)
		applyLFGAssociation(
			dungeon, associations[dungeon.challengeModeID])
	end
end
