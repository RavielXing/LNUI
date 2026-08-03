local _, GF = ...

GF.MythicPlusRosterSort = GF.MythicPlusRosterSort or {}
local Sort = GF.MythicPlusRosterSort
local Util = GF.MythicPlusServiceUtil

local LIST_DEFAULTS = {
	group = { key = "roster", direction = "asc" },
	carpool = { key = "last", direction = "asc" },
}

local INITIAL_DIRECTIONS = {
	roster = "asc",
	name = "asc",
	character = "asc",
	armor = "asc",
	key = "desc",
	rating = "desc",
	roles = "asc",
	last = "asc",
	meetingStone = "asc",
}

local CLASS_SORT_TEXT = {
	WARRIOR = "zhanshi",
	PALADIN = "shengqishi",
	HUNTER = "lieren",
	ROGUE = "qianxingzhe",
	PRIEST = "mushi",
	DEATHKNIGHT = "siwangqishi",
	SHAMAN = "samanzhisi",
	MAGE = "fashi",
	WARLOCK = "shushi",
	MONK = "wuseng",
	DRUID = "deluyi",
	DEMONHUNTER = "emolieshou",
	EVOKER = "huanmushi",
}

local ARMOR_SORT_TEXT = {
	WARRIOR = "banjia",
	PALADIN = "banjia",
	DEATHKNIGHT = "banjia",
	HUNTER = "suojia",
	SHAMAN = "suojia",
	ROGUE = "pijia",
	MONK = "pijia",
	DRUID = "pijia",
	DEMONHUNTER = "pijia",
	PRIEST = "bujia",
	MAGE = "bujia",
	WARLOCK = "bujia",
	EVOKER = "suojia",
}

local ROLE_SORT_TEXT = {
	DPS = "shuchu",
	DAMAGER = "shuchu",
	TANK = "tanke",
	HEAL = "zhiliao",
	HEALER = "zhiliao",
}

local function listKind(value)
	return value == "carpool" and "carpool" or "group"
end

local function normalizeKey(key)
	if key == "character" then
		return "name"
	end
	if key == "meetingStone" then
		return "last"
	end
	return INITIAL_DIRECTIONS[key] and key or nil
end

local function copyState(source)
	return {
		key = source.key,
		direction = source.direction,
	}
end

local function dataOf(entry)
	return type(entry and entry.data) == "table" and entry.data or entry or {}
end

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function fullNameOf(entry)
	local data = dataOf(entry)
	return data.fullName or data.name or entry.fullName or entry.name or entry.key or ""
end

local function rolesText(entry)
	local data = dataOf(entry)
	local roles = type(data.roles) == "table" and data.roles or type(entry.roles) == "table" and entry.roles
	local values = {}
	if roles then
		for roleKey, enabled in pairs(roles) do
			if enabled == true and ROLE_SORT_TEXT[roleKey] then
				values[#values + 1] = ROLE_SORT_TEXT[roleKey]
			end
		end
	else
		local role = data.role or entry.role
		if ROLE_SORT_TEXT[role] then
			values[1] = ROLE_SORT_TEXT[role]
		end
	end
	table.sort(values)
	return table.concat(values, ",")
end

local function valueFor(entry, key)
	local data = dataOf(entry)
	if key == "roster" then
		return tonumber(entry.rosterIndex or data.rosterIndex) or 9999
	end
	if key == "name" then
		return CLASS_SORT_TEXT[data.classFile or data.class] or lower(data.classFile or data.class)
	end
	if key == "armor" then
		return ARMOR_SORT_TEXT[data.classFile or data.class] or lower(data.armorType or data.armorTypeKey)
	end
	if key == "rating" then
		return tonumber(data.rating) or -1
	end
	if key == "roles" then
		return rolesText(entry)
	end
	if key == "last" then
		return lower(entry.warbandSourceName or entry.sourceName or entry.ownerName or entry.ownerKey or entry.owner)
	end
	return lower(fullNameOf(entry))
end

local function carpoolOwnerIdentity(entry)
	return lower(entry.ownerKey or entry.owner
		or entry.sourceName or entry.ownerName
		or entry.warbandSourceName)
end

local function carpoolSourceName(entry)
	return entry.warbandSourceName or entry.sourceName
		or entry.ownerName or entry.ownerKey or entry.owner or ""
end

local function keyParts(entry)
	local data = dataOf(entry)
	local mapID = tonumber(data.challengeModeID or data.mapID)
	local level = tonumber(data.keyLevel or data.level) or 0
	return mapID, level
end

local function buildDungeonLevels(entries, direction)
	local levels = {}
	for _, entry in ipairs(entries) do
		local mapID, level = keyParts(entry)
		if mapID then
			local current = levels[mapID]
			if current == nil
				or (direction == "asc" and level < current)
				or (direction == "desc" and level > current)
			then
				levels[mapID] = level
			end
		end
	end
	return levels
end

local function compareKeystones(left, right, direction, dungeonLevels)
	local leftMapID, leftLevel = keyParts(left)
	local rightMapID, rightLevel = keyParts(right)
	if (leftMapID ~= nil) ~= (rightMapID ~= nil) then
		return leftMapID ~= nil
	end
	if leftMapID and rightMapID and leftMapID ~= rightMapID then
		local leftGroupLevel = dungeonLevels[leftMapID] or leftLevel
		local rightGroupLevel = dungeonLevels[rightMapID] or rightLevel
		if leftGroupLevel ~= rightGroupLevel then
			if direction == "asc" then
				return leftGroupLevel < rightGroupLevel
			end
			return leftGroupLevel > rightGroupLevel
		end
		return leftMapID < rightMapID
	end
	if leftLevel ~= rightLevel then
		if direction == "asc" then
			return leftLevel < rightLevel
		end
		return leftLevel > rightLevel
	end
	return nil
end

local function compareValues(left, right, direction)
	if left == right then
		return nil
	end
	if direction == "desc" then
		return left > right
	end
	return left < right
end

local function compareNames(left, right, direction)
	left = tostring(left or "")
	right = tostring(right or "")
	local comparison
	if type(strcmputf8i) == "function" then
		local ok, result = pcall(strcmputf8i, left, right)
		comparison = ok and tonumber(result) or nil
	end
	if comparison == nil then
		left = lower(left)
		right = lower(right)
		if left == right then
			return nil
		end
		comparison = left < right and -1 or 1
	end
	if comparison == 0 then
		return nil
	end
	if direction == "desc" then
		return comparison > 0
	end
	return comparison < 0
end

function Sort:GetState(kind)
	kind = listKind(kind)
	self.states = self.states or {}
	if not self.states[kind] then
		self.states[kind] = copyState(LIST_DEFAULTS[kind])
	end
	return copyState(self.states[kind])
end

function Sort:Toggle(kind, key)
	if kind ~= "group" and kind ~= "carpool" then
		kind, key = key, kind
	end
	kind = listKind(kind)
	key = normalizeKey(key)
	if not key then
		return self:GetState(kind)
	end
	self.states = self.states or {}
	local state = self.states[kind] or copyState(LIST_DEFAULTS[kind])
	if state.key == key then
		state.direction = state.direction == "asc" and "desc" or "asc"
	else
		state.key = key
		state.direction = INITIAL_DIRECTIONS[key]
	end
	self.states[kind] = state
	Util.Notify(self, kind .. "-sort")
	return copyState(state)
end

function Sort:Reset(kind)
	kind = listKind(kind)
	self.states = self.states or {}
	self.states[kind] = copyState(LIST_DEFAULTS[kind])
	Util.Notify(self, kind .. "-reset")
	return copyState(self.states[kind])
end

function Sort:AddListener(callback)
	Util.AddListener(self, callback)
end

function Sort:Sort(kind, source, overrideState)
	kind = listKind(kind)
	local entries = Util.CopyArray(source)
	local state = overrideState or self:GetState(kind)
	local key = normalizeKey(state.key) or LIST_DEFAULTS[kind].key
	local direction = state.direction == "desc" and "desc" or "asc"
	local dungeonLevels = key == "key" and buildDungeonLevels(entries, direction) or nil
	local pinGroupCurrent = kind == "group"
		and key == "roster"
		and direction == "asc"
	local pushOfflineLast = kind == "group"
		and key == "roster"
		and direction == "asc"
	local sortCarpoolSources = kind == "carpool" and key == "last"
	-- Both directions order source groups strictly by their displayed warband
	-- nickname. Inside each source group, keep its current/owner character above
	-- that warband's alternate characters without crossing group boundaries.
	local pinCarpoolOwnerCurrent = sortCarpoolSources

	table.sort(entries, function(left, right)
		if pinGroupCurrent then
			local leftCurrent = left.isCurrent == true or left.unit == "player"
			local rightCurrent = right.isCurrent == true or right.unit == "player"
			if leftCurrent ~= rightCurrent then
				return leftCurrent
			end
		end
		if pushOfflineLast then
			local leftOffline = dataOf(left).connected == false
			local rightOffline = dataOf(right).connected == false
			if leftOffline ~= rightOffline then
				return not leftOffline
			end
		end
		if sortCarpoolSources then
			local compared = compareNames(
				carpoolSourceName(left), carpoolSourceName(right), direction)
			if compared ~= nil then
				return compared
			end
			local leftOwner = carpoolOwnerIdentity(left)
			local rightOwner = carpoolOwnerIdentity(right)
			compared = compareNames(leftOwner, rightOwner, direction)
			if compared ~= nil then
				return compared
			end
			if pinCarpoolOwnerCurrent then
				local leftCurrent = left.isOwnerCurrent == true
					or left.isLocalCurrent == true
				local rightCurrent = right.isOwnerCurrent == true
					or right.isLocalCurrent == true
				if leftCurrent ~= rightCurrent then
					return leftCurrent
				end
			end
		elseif key == "key" then
			local compared = compareKeystones(left, right, direction, dungeonLevels)
			if compared ~= nil then
				return compared
			end
		else
			local compared = compareValues(valueFor(left, key), valueFor(right, key), direction)
			if compared ~= nil then
				return compared
			end
		end
		local leftName = lower(fullNameOf(left))
		local rightName = lower(fullNameOf(right))
		if leftName ~= rightName then
			return leftName < rightName
		end
		return lower(left.ownerKey or left.owner) < lower(right.ownerKey or right.owner)
	end)
	return entries
end
