local _, GF = ...

GF.MythicPlusBrowseFilter = GF.MythicPlusBrowseFilter or {}
local Filter = GF.MythicPlusBrowseFilter

local CLIENT_KEY = GF.WORKSPACE_MYTHIC_PLUS or "mythic_plus"
local ROLE_FIELD = {
	TANK = "tankPresence",
	HEAL = "healerPresence",
	HEALER = "healerPresence",
	DPS = "damagerPresence",
	DAMAGER = "damagerPresence",
}
local PRESENCE_MODE = {
	missing = true,
	existing = true,
}

local function copyTable(source)
	if type(source) ~= "table" then
		return nil
	end
	local out = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			out[key] = copyTable(value)
		else
			out[key] = value
		end
	end
	return out
end

local function clampInteger(value, minimum, maximum, fallback)
	local ok, numeric = pcall(tonumber, value)
	numeric = ok and numeric or nil
	if numeric == nil then
		numeric = fallback
	end
	numeric = math.floor(numeric + 0.5)
	return math.max(minimum, math.min(maximum, numeric))
end

local function normalizePresence(value)
	return PRESENCE_MODE[value] and value or nil
end

local function normalizeRole(role)
	if type(role) ~= "string" then
		return nil
	end
	return ROLE_FIELD[role:upper()]
end

local function readClient()
	if GF.Filter and GF.Filter.GetMythicPlusBrowseFilters then
		return GF.Filter:GetMythicPlusBrowseFilters()
	end
	if GF.Filter and GF.Filter.GetClientFilters then
		return GF.Filter:GetClientFilters(CLIENT_KEY)
	end
	local defaults = GF.clientFilterDefaults or {}
	local client = copyTable(defaults) or {}
	local db = GF.GetDB and GF.GetDB()
	local stored = db and db.filterClientByCategory
		and db.filterClientByCategory[CLIENT_KEY]
	if type(stored) == "table" then
		for key, value in pairs(stored) do
			client[key] = copyTable(value) or value
		end
	end
	return client
end

local function saveClient(client)
	if GF.Filter and GF.Filter.SaveMythicPlusBrowseFilters then
		GF.Filter:SaveMythicPlusBrowseFilters(client)
		return
	end
	if GF.Filter and GF.Filter.SaveCategoryClientFilters then
		GF.Filter:SaveCategoryClientFilters(CLIENT_KEY, client)
		return
	end
	local db = GF.GetDB and GF.GetDB()
	if db then
		db.filterClientByCategory = db.filterClientByCategory or {}
		db.filterClientByCategory[CLIENT_KEY] = copyTable(client)
	end
end

local function normalizeClient(client)
	client = type(client) == "table" and client or {}
	client.matchPartyRoles = client.matchPartyRoles == true
	client.matchPartySpecs = client.matchPartySpecs == true
	client.tankPresence = normalizePresence(client.tankPresence)
	client.healerPresence = normalizePresence(client.healerPresence)
	client.damagerPresence = normalizePresence(client.damagerPresence)
	client.minOpenSlots = clampInteger(client.minOpenSlots, 1, 4, 1)
	client.leaderScoreMin = clampInteger(client.leaderScoreMin, 0, 9999, 0)
	return client
end

local function rawDungeonOptions()
	local scope = GF.MythicPlusLFGScope
	if not (scope and type(scope.GetDungeons) == "function") then
		return {}
	end
	local ok, dungeons = pcall(scope.GetDungeons, scope)
	if not ok or type(dungeons) ~= "table" then
		return {}
	end
	local options = {}
	local seen = {}
	for index, dungeon in ipairs(dungeons) do
		local key = type(dungeon) == "table" and dungeon.key or nil
		if key ~= nil then
			key = tostring(key)
		end
		if key and key ~= "" and not seen[key] then
			seen[key] = true
			local activityIDs = {}
			local activitySeen = {}
			for _, activityID in ipairs(dungeon.activityIDs or {}) do
				local numeric = tonumber(activityID)
				if numeric and numeric > 0 and not activitySeen[numeric] then
					activitySeen[numeric] = true
					activityIDs[#activityIDs + 1] = numeric
				end
			end
			local primaryActivityID = tonumber(dungeon.activityID)
			if primaryActivityID and primaryActivityID > 0
				and not activitySeen[primaryActivityID]
			then
				table.insert(activityIDs, 1, primaryActivityID)
			end
			options[#options + 1] = {
				key = key,
				orderIndex = tonumber(dungeon.orderIndex) or index,
				label = dungeon.label
					or (dungeon.source and dungeon.source.name)
					or key,
				groupID = tonumber(dungeon.groupID),
				activityID = activityIDs[1],
				activityIDs = activityIDs,
				mapID = tonumber(dungeon.mapID),
				instanceMapID = tonumber(dungeon.instanceMapID),
				visualTexture = dungeon.visualTexture,
				visualTexCoords = copyTable(dungeon.visualTexCoords),
				visualSource = dungeon.visualSource,
			}
		end
	end
	table.sort(options, function(left, right)
		if left.orderIndex ~= right.orderIndex then
			return left.orderIndex < right.orderIndex
		end
		return left.key < right.key
	end)
	return options
end

local function normalizeSelectedKeys(selected, options)
	if selected == nil then
		return nil
	end
	if type(selected) ~= "table" then
		return nil
	end
	if #options == 0 then
		return copyTable(selected) or {}
	end

	local valid = {}
	for _, option in ipairs(options) do
		valid[option.key] = true
	end
	local normalized = {}
	local originalCount = 0
	for key, enabled in pairs(selected) do
		local candidate
		if type(key) == "number" then
			candidate = enabled
			enabled = true
		else
			candidate = key
		end
		if enabled == true and candidate ~= nil then
			candidate = tostring(candidate)
			originalCount = originalCount + 1
			if valid[candidate] then
				normalized[candidate] = true
			end
		end
	end

	local selectedCount = 0
	for _ in pairs(normalized) do
		selectedCount = selectedCount + 1
	end
	if selectedCount == #options then
		return nil
	end
	-- A non-empty custom selection whose complete key set disappeared is a
	-- season rollover, not an intentional "select none" state.
	if originalCount > 0 and selectedCount == 0 then
		return nil
	end
	return normalized
end

local function selectedKeysEqual(left, right)
	if left == nil or right == nil then
		return left == right
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for key, value in pairs(left) do
		if value == true and right[key] ~= true then
			return false
		end
	end
	for key, value in pairs(right) do
		if value == true and left[key] ~= true then
			return false
		end
	end
	return true
end

function Filter:Notify(reason)
	self.revision = (self.revision or 0) + 1
	local state = self:GetState()
	for _, callback in ipairs(self.listeners or {}) do
		pcall(callback, state, reason)
	end
end

function Filter:AddListener(callback)
	if type(callback) ~= "function" then
		return
	end
	self.listeners = self.listeners or {}
	self.listeners[#self.listeners + 1] = callback
	return callback
end

function Filter:GetRevision()
	return self.revision or 0
end

function Filter:NormalizeDungeonSelection(notify)
	local client = normalizeClient(readClient())
	local normalized = normalizeSelectedKeys(
		client.selectedDungeonKeys, rawDungeonOptions())
	if selectedKeysEqual(client.selectedDungeonKeys, normalized) then
		return false
	end
	client.selectedDungeonKeys = normalized
	saveClient(client)
	if notify == true then
		self:Notify("dungeons")
	end
	return true
end

function Filter:GetState()
	self:NormalizeDungeonSelection(false)
	local client = normalizeClient(readClient())
	return {
		matchPartyRoles = client.matchPartyRoles,
		matchPartySpecs = client.matchPartySpecs,
		tankPresence = client.tankPresence,
		healerPresence = client.healerPresence,
		damagerPresence = client.damagerPresence,
		minOpenSlots = client.minOpenSlots,
		leaderScoreMin = client.leaderScoreMin,
		selectedDungeonKeys = copyTable(client.selectedDungeonKeys),
		revision = self:GetRevision(),
	}
end

function Filter:GetClientFilters()
	self:NormalizeDungeonSelection(false)
	return normalizeClient(readClient())
end

function Filter:GetDungeonOptions()
	self:NormalizeDungeonSelection(false)
	local client = normalizeClient(readClient())
	local selected = client.selectedDungeonKeys
	local options = rawDungeonOptions()
	for _, option in ipairs(options) do
		option.selected = selected == nil or selected[option.key] == true
	end
	return options
end

function Filter:IsDungeonSelected(key)
	key = key ~= nil and tostring(key) or nil
	if not key then
		return false
	end
	local found = false
	for _, option in ipairs(rawDungeonOptions()) do
		if option.key == key then
			found = true
			break
		end
	end
	if not found then
		return false
	end
	self:NormalizeDungeonSelection(false)
	local selected = normalizeClient(readClient()).selectedDungeonKeys
	return selected == nil or selected[key] == true
end

function Filter:GetSelectedActivityIDs()
	self:NormalizeDungeonSelection(false)
	local client = normalizeClient(readClient())
	local selected = client.selectedDungeonKeys
	local out = {}
	local seen = {}
	for _, option in ipairs(rawDungeonOptions()) do
		if selected == nil or selected[option.key] == true then
			for _, activityID in ipairs(option.activityIDs or {}) do
				if not seen[activityID] then
					seen[activityID] = true
					out[#out + 1] = activityID
				end
			end
		end
	end
	table.sort(out)
	return out
end

function Filter:IsSearchEnabled()
	return #self:GetSelectedActivityIDs() > 0
end

function Filter:SetDungeonSelected(key, enabled)
	key = key ~= nil and tostring(key) or nil
	if not key then
		return false
	end
	local options = rawDungeonOptions()
	local valid = {}
	for _, option in ipairs(options) do
		valid[option.key] = true
	end
	if not valid[key] then
		return false
	end

	local client = normalizeClient(readClient())
	local selected = client.selectedDungeonKeys
	if selected == nil then
		selected = {}
		for optionKey in pairs(valid) do
			selected[optionKey] = true
		end
	else
		selected = copyTable(selected) or {}
	end
	local nextEnabled = enabled == true
	if (selected[key] == true) == nextEnabled then
		return false
	end
	selected[key] = nextEnabled and true or nil
	client.selectedDungeonKeys = normalizeSelectedKeys(selected, options)
	saveClient(client)
	self:Notify("dungeons")
	return true
end

function Filter:ToggleDungeon(key)
	return self:SetDungeonSelected(key, not self:IsDungeonSelected(key))
end

function Filter:SelectAllDungeons()
	local client = normalizeClient(readClient())
	if client.selectedDungeonKeys == nil then
		return false
	end
	client.selectedDungeonKeys = nil
	saveClient(client)
	self:Notify("dungeons")
	return true
end

function Filter:ClearDungeons()
	local client = normalizeClient(readClient())
	local selected = client.selectedDungeonKeys
	if type(selected) == "table" and next(selected) == nil then
		return false
	end
	client.selectedDungeonKeys = {}
	saveClient(client)
	self:Notify("dungeons")
	return true
end

function Filter:SelectOnlyDungeon(key)
	key = key ~= nil and tostring(key) or nil
	if not key then
		return false
	end
	local options = rawDungeonOptions()
	local found = false
	for _, option in ipairs(options) do
		if option.key == key then
			found = true
			break
		end
	end
	if not found then
		return false
	end

	local selected = normalizeSelectedKeys({ [key] = true }, options)
	local client = normalizeClient(readClient())
	if not selectedKeysEqual(client.selectedDungeonKeys, selected) then
		client.selectedDungeonKeys = selected
		saveClient(client)
		self:Notify("dungeons")
	end
	return true
end

function Filter:SelectOnlyDungeonByActivityID(activityID)
	local scope = GF.MythicPlusLFGScope
	local dungeon = scope and scope.GetDungeonByActivityID
		and scope:GetDungeonByActivityID(activityID) or nil
	return dungeon and self:SelectOnlyDungeon(dungeon.key) or false
end

function Filter:SetRolePresence(role, mode)
	local field = normalizeRole(role)
	if not field then
		return false
	end
	mode = normalizePresence(mode)
	local client = normalizeClient(readClient())
	if client[field] == mode then
		return false
	end
	client[field] = mode
	saveClient(client)
	self:Notify("filter")
	return true
end

local function setBoolean(field, enabled)
	local client = normalizeClient(readClient())
	enabled = enabled == true
	if client[field] == enabled then
		return false
	end
	client[field] = enabled
	saveClient(client)
	Filter:Notify("filter")
	return true
end

function Filter:SetMatchPartyRoles(enabled)
	return setBoolean("matchPartyRoles", enabled)
end

function Filter:SetMatchPartySpecs(enabled)
	return setBoolean("matchPartySpecs", enabled)
end

function Filter:SetMinimumOpenSlots(value)
	value = clampInteger(value, 1, 4, 1)
	local client = normalizeClient(readClient())
	if client.minOpenSlots == value then
		return false
	end
	client.minOpenSlots = value
	saveClient(client)
	self:Notify("filter")
	return true
end

function Filter:SetLeaderScoreMin(value)
	value = clampInteger(value, 0, 9999, 0)
	local client = normalizeClient(readClient())
	if client.leaderScoreMin == value then
		return false
	end
	client.leaderScoreMin = value
	saveClient(client)
	self:Notify("filter")
	return true
end

function Filter:HasActiveFilters()
	local client = normalizeClient(readClient())
	return client.matchPartyRoles
		or client.matchPartySpecs
		or client.tankPresence ~= nil
		or client.healerPresence ~= nil
		or client.damagerPresence ~= nil
		or client.minOpenSlots > 0
		or client.leaderScoreMin > 0
		or client.selectedDungeonKeys ~= nil
end

function Filter:Reset()
	if GF.Filter and GF.Filter.ResetMythicPlusBrowseFilters then
		GF.Filter:ResetMythicPlusBrowseFilters()
	elseif GF.Filter and GF.Filter.ResetCategoryClient then
		GF.Filter:ResetCategoryClient(CLIENT_KEY)
	else
		saveClient(normalizeClient({}))
	end
	self:Notify("reset")
end

function Filter:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.revision = self.revision or 0

	if GF.MythicPlusSeason and GF.MythicPlusSeason.AddListener then
		GF.MythicPlusSeason:AddListener(function()
			if GF.MythicPlusLFGScope and GF.MythicPlusLFGScope.Invalidate then
				GF.MythicPlusLFGScope:Invalidate()
			end
			Filter:NormalizeDungeonSelection(false)
			Filter:Notify("season")
		end)
	end
	if GF.MythicPlusRosterCache and GF.MythicPlusRosterCache.AddListener then
		GF.MythicPlusRosterCache:AddListener(function()
			Filter:Notify("roster")
		end)
	end
	if GF.MythicPlusCurrentRoleService
		and GF.MythicPlusCurrentRoleService.AddListener
	then
		GF.MythicPlusCurrentRoleService:AddListener(function()
			Filter:Notify("roster")
		end)
	end
end

Filter:Init()
