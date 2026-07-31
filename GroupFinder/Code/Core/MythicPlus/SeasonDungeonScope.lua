local _, GF = ...

GF.MythicPlusLFGScope = GF.MythicPlusLFGScope or {}
local Scope = GF.MythicPlusLFGScope

local function safeActivityInfo(activityID)
	if not (activityID and C_LFGList and C_LFGList.GetActivityInfoTable) then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
	return ok and type(info) == "table" and info or nil
end

local function copyArray(source)
	local out = {}
	for index, value in ipairs(source or {}) do
		out[index] = value
	end
	return out
end

local function addActivityID(out, seen, activityID)
	activityID = tonumber(activityID)
	if not activityID or seen[activityID] then
		return
	end
	local info = safeActivityInfo(activityID)
	if not (info and info.categoryID == GF.CAT_DUNGEON
		and info.isMythicPlusActivity == true) then
		return
	end
	seen[activityID] = true
	out[#out + 1] = activityID
end

local function buildDungeon(instance, index)
	local activityIDs = {}
	local seen = {}
	addActivityID(activityIDs, seen, instance and instance.activityID)
	for _, activityID in ipairs(instance and instance.activityIDs or {}) do
		addActivityID(activityIDs, seen, activityID)
	end
	if #activityIDs == 0 then
		return nil
	end
	return {
		key = string.format("season:%s", tostring(
			instance.groupID or instance.activityID or index)),
		orderIndex = tonumber(instance.orderIndex) or index,
		label = instance.label,
		groupID = tonumber(instance.groupID),
		activityID = activityIDs[1],
		activityIDs = activityIDs,
		mapID = tonumber(instance.mapID),
		instanceMapID = tonumber(instance.instanceMapID),
		visualTexture = instance.visualTexture,
		visualTexCoords = instance.visualTexCoords,
		visualSource = instance.visualSource,
		source = instance,
	}
end

function Scope:BuildSnapshot()
	local instances = GF.NavCatalog and GF.NavCatalog.GetSeasonInstances
		and GF.NavCatalog.GetSeasonInstances("dungeon") or {}
	if self.snapshot and self.snapshot.source == instances then
		return self.snapshot
	end

	local dungeons = {}
	local activityIDs = {}
	local activityIDSet = {}
	local byActivityID = {}
	local byGroupID = {}
	for index, instance in ipairs(instances) do
		local dungeon = buildDungeon(instance, index)
		if dungeon then
			dungeons[#dungeons + 1] = dungeon
			if dungeon.groupID then
				byGroupID[dungeon.groupID] = dungeon
			end
			for _, activityID in ipairs(dungeon.activityIDs) do
				if not activityIDSet[activityID] then
					activityIDSet[activityID] = true
					activityIDs[#activityIDs + 1] = activityID
					byActivityID[activityID] = dungeon
				end
			end
		end
	end
	table.sort(activityIDs)
	self.snapshot = {
		source = instances,
		dungeons = dungeons,
		activityIDs = activityIDs,
		activityIDSet = activityIDSet,
		byActivityID = byActivityID,
		byGroupID = byGroupID,
	}
	return self.snapshot
end

function Scope:Invalidate()
	self.snapshot = nil
end

function Scope:GetDungeons()
	return self:BuildSnapshot().dungeons
end

function Scope:GetActivityIDs()
	return copyArray(self:BuildSnapshot().activityIDs)
end

function Scope:GetDungeonByActivityID(activityID)
	return self:BuildSnapshot().byActivityID[tonumber(activityID)]
end

function Scope:GetDungeonByGroupID(groupID)
	return self:BuildSnapshot().byGroupID[tonumber(groupID)]
end

function Scope:GetDungeonForInstance(instance)
	if not instance then
		return nil
	end
	local dungeon = self:GetDungeonByGroupID(instance.groupID)
	if dungeon then
		return dungeon
	end
	dungeon = self:GetDungeonByActivityID(instance.activityID)
	if dungeon then
		return dungeon
	end
	for _, activityID in ipairs(instance.activityIDs or {}) do
		dungeon = self:GetDungeonByActivityID(activityID)
		if dungeon then
			return dungeon
		end
	end
	return nil
end

function Scope:GetActivityIDsForInstance(instance)
	local dungeon = self:GetDungeonForInstance(instance)
	return dungeon and copyArray(dungeon.activityIDs) or {}
end

function Scope:GetActivityIDsForNode(node)
	if not node then
		return {}
	end
	if node.key == "season_dungeon"
		or ((node.level or 0) == 0 and node.navKind == "season_dungeon") then
		return self:GetActivityIDs()
	end
	local dungeon = self:GetDungeonByGroupID(node.groupID)
		or self:GetDungeonByActivityID(node.activityID)
	for _, activityID in ipairs(not dungeon and node.activityIDsFilter or {}) do
		dungeon = self:GetDungeonByActivityID(activityID)
		if dungeon then
			break
		end
	end
	return dungeon and copyArray(dungeon.activityIDs) or {}
end

function Scope:ResolveCreateActivityID(activityID)
	local dungeon = self:GetDungeonByActivityID(activityID)
	return dungeon and dungeon.activityID or nil
end

function Scope:IsActivityIDAllowed(activityID)
	return self:GetDungeonByActivityID(activityID) ~= nil
end
