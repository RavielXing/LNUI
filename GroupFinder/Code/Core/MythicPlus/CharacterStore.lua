local _, GF = ...

GF.MythicPlusCharacterStore = GF.MythicPlusCharacterStore or {}
local Store = GF.MythicPlusCharacterStore
local Util = GF.MythicPlusServiceUtil

local VOLATILE_CHARACTER_FIELDS = {
	reason = true,
	updatedAt = true,
}
local WEEKLY_FRESHNESS_FIELDS = {
	lastKeyCheckedAt = true,
	lastKeySeenAt = true,
}

local function getDB()
	local db = GF.GetDB()
	db.mythicPlus = type(db.mythicPlus) == "table" and db.mythicPlus or {}
	db.mythicPlus.characters = type(db.mythicPlus.characters) == "table" and db.mythicPlus.characters or {}
	return db.mythicPlus
end

local function currentCharacterKey()
	return Util.GetUnitFullName("player")
end

local function semanticValuesEqual(left, right, field)
	if VOLATILE_CHARACTER_FIELDS[field] then
		return true
	end
	if WEEKLY_FRESHNESS_FIELDS[field] then
		local resetAt = Util.GetLastWeeklyResetTimestamp
			and tonumber(Util.GetLastWeeklyResetTimestamp()) or 0
		if resetAt <= 0 then
			return true
		end
		return (tonumber(left) or 0) >= resetAt
			and (tonumber(right) or 0) >= resetAt
			or (tonumber(left) or 0) < resetAt
				and (tonumber(right) or 0) < resetAt
	end
	if type(left) ~= type(right) then
		return false
	end
	if type(left) ~= "table" then
		return left == right
	end
	for key, value in pairs(left) do
		if not semanticValuesEqual(value, right[key], key) then
			return false
		end
	end
	for key, value in pairs(right) do
		if left[key] == nil
			and not semanticValuesEqual(nil, value, key)
		then
			return false
		end
	end
	return true
end

local function getMaxCharacterLevel()
	if GetMaxPlayerLevel then
		local ok, maxLevel = pcall(GetMaxPlayerLevel)
		maxLevel = tonumber(maxLevel)
		if ok and maxLevel and maxLevel > 0 then
			return maxLevel
		end
	end
	local maxLevel = tonumber(_G.MAX_PLAYER_LEVEL)
	if maxLevel and maxLevel > 0 then
		return maxLevel
	end
	if type(_G.MAX_PLAYER_LEVEL_TABLE) == "table" then
		maxLevel = 0
		for _, level in pairs(_G.MAX_PLAYER_LEVEL_TABLE) do
			level = tonumber(level)
			if level and level > maxLevel then
				maxLevel = level
			end
		end
		if maxLevel > 0 then
			return maxLevel
		end
	end
	return nil
end

local function hasKeystoneData(character)
	return character and (
		(tonumber(character.keyLevel) or 0) > 0
		or (type(character.keystoneLink) == "string" and character.keystoneLink ~= "")
		or character.hasKeystone == true
	)
end

local function getCurrentSeasonID()
	if not (GF.MythicPlusSeason and GF.MythicPlusSeason.GetSeasonID) then
		return nil
	end
	local ok, seasonID = pcall(
		GF.MythicPlusSeason.GetSeasonID,
		GF.MythicPlusSeason)
	seasonID = ok and tonumber(seasonID) or nil
	return seasonID and seasonID > 0 and seasonID or nil
end

local function hasCurrentSeasonRating(character)
	local currentSeasonID = getCurrentSeasonID()
	return currentSeasonID ~= nil
		and tonumber(character and character.ratingSeasonID) == currentSeasonID
		and tonumber(character and character.rating) ~= nil
end

local function isWarbandCharacterVisible(character)
	if type(character) ~= "table" then
		return false
	end
	local level = tonumber(character.level)
	local maxLevel = getMaxCharacterLevel()
	if level and maxLevel then
		return level >= maxLevel
	end
	return level == nil and (
		hasKeystoneData(character)
			or (
				hasCurrentSeasonRating(character)
					and (tonumber(character.rating) or 0) > 0
			)
	)
end

local function copyForView(character, key)
	Util.NormalizeSpecialization(character)
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and Util.GetLastWeeklyResetTimestamp() or 0
	local hasKey = hasKeystoneData(character)
	local seenAt = tonumber(character.lastKeySeenAt) or 0
	local checkedAt = tonumber(character.lastKeyCheckedAt) or 0
	local explicitEmpty = character.keyState == "empty"
		and character.keystoneKnown == true
	local keyIsCurrent = resetAt <= 0
		or hasKey and seenAt >= resetAt
		or explicitEmpty and checkedAt >= resetAt
		or not hasKey and not explicitEmpty
	local hasStoredRating = character.rating ~= nil
		or type(character.bestRuns) == "table"
	local ratingIsCurrent = not hasStoredRating
		or hasCurrentSeasonRating(character)
	if keyIsCurrent and ratingIsCurrent then
		character.key = key
		return character
	end
	local copy = {}
	for field, value in pairs(character) do
		copy[field] = value
	end
	copy.key = key
	if not keyIsCurrent then
		copy.challengeModeID = nil
		copy.mapID = nil
		copy.keyLevel = nil
		copy.dungeonName = nil
		copy.keystoneLink = nil
		copy.keyUpgradeTrack = nil
		copy.activityID = nil
		copy.groupID = nil
		copy.hasKeystone = false
		copy.keyState = "unknown"
		copy.keystoneKnown = false
	end
	if not ratingIsCurrent then
		copy.rating = nil
		copy.ratingColor = nil
		copy.bestRuns = nil
	end
	return copy
end

local function getSpecInfo()
	if not (GetSpecialization and GetSpecializationInfo) then
		return nil, nil, nil, nil
	end
	local specIndex = GetSpecialization()
	if not specIndex then
		return nil, nil, nil, nil
	end
	local specID, specName, _, icon = GetSpecializationInfo(specIndex)
	local role = GetSpecializationRole and GetSpecializationRole(specIndex) or nil
	return specID, specName, icon, role
end

local function getCurrentPlayerData()
	local key, name, realm = Util.GetUnitFullName("player")
	if not key then
		return nil, nil
	end
	local _, classFile, classID = UnitClass("player")
	local specID, specName, specIcon, role = getSpecInfo()
	local character = {
		key = key,
		name = name,
		realm = realm,
		fullName = key,
		guid = UnitGUID("player"),
		level = UnitLevel("player"),
		classFile = classFile,
		classID = classID,
		specID = specID,
		specName = specName,
		specIcon = specIcon,
		specRole = role,
	}
	Util.NormalizeSpecialization(character)
	return key, character
end

function Store:AddListener(callback)
	Util.AddListener(self, callback)
end

function Store:GetCurrentKey()
	return currentCharacterKey()
end

function Store:GetCurrent()
	local key = currentCharacterKey()
	local character = key and getDB().characters[key] or nil
	return character and copyForView(character, key) or nil
end

function Store:GetCharacters()
	local entries = {}
	local currentKey = currentCharacterKey()
	for key, character in pairs(getDB().characters) do
		if type(character) == "table" and (key == currentKey or isWarbandCharacterVisible(character)) then
			entries[#entries + 1] = copyForView(character, key)
		end
	end
	for _, character in ipairs(GF.MythicPlusDebugService
		and GF.MythicPlusDebugService.GetLocalCharacters
		and GF.MythicPlusDebugService:GetLocalCharacters() or {})
	do
		Util.NormalizeSpecialization(character)
		entries[#entries + 1] = character
	end
	table.sort(entries, function(a, b)
		return (a.name or a.fullName or a.key or "") < (b.name or b.fullName or b.key or "")
	end)
	return entries
end

function Store:GetCarpoolCharacters()
	local entries = {}
	for _, character in ipairs(self:GetCharacters()) do
		-- This interface is also the source for GFMP2 party snapshots. Keep the
		-- transient debug overlay out of it; CarpoolView merges debug rows only
		-- for local rendering.
		if character.carpoolEnabled == true
			and character.isDebugTest ~= true
			and character.isTest ~= true
			and character.source ~= "test"
		then
			entries[#entries + 1] = character
		end
	end
	table.sort(entries, function(a, b)
		if (a.keyLevel or 0) ~= (b.keyLevel or 0) then
			return (a.keyLevel or 0) > (b.keyLevel or 0)
		end
		return (a.fullName or "") < (b.fullName or "")
	end)
	return entries
end

function Store:SetCarpoolEnabled(key, enabled)
	local character = key and getDB().characters[key]
	if not character then
		return false
	end
	local newValue = enabled == true
	if character.carpoolEnabled == newValue then
		return false, character
	end
	character.carpoolEnabled = newValue
	character.updatedAt = Util.Now()
	Util.Notify(self, "carpool")
	return true, character
end

function Store:SetStoredRoles(key, roles, reason)
	local character = key and getDB().characters[key]
	if not character then
		return false
	end
	local normalized = Util.CopyRoles(roles)
	if Util.RolesEqual(character.roles, normalized)
		and character.role == nil
		and character.rolesManuallyConfigured == true
	then
		return false, character.roles
	end
	character.roles = normalized
	character.role = nil
	character.rolesManuallyConfigured = true
	character.updatedAt = Util.Now()
	Util.Notify(self, reason or "roles")
	return true, character.roles
end

function Store:SetStoredRole(key, roleKey, enabled)
	roleKey = Util.NormalizeRole(roleKey)
	local character = key and getDB().characters[key]
	if not (character and roleKey) then
		return false
	end
	local roles = Util.CopyRoles(character.roles, character.role or character.specRole)
	local newValue = enabled == true
	if (roles[roleKey] == true) == newValue then
		return false, roles
	end
	roles[roleKey] = newValue and true or nil
	if not next(roles) then
		roles[roleKey] = true
	end
	return self:SetStoredRoles(key, roles, "roles")
end

function Store:RefreshCurrent(reason)
	local key, current = getCurrentPlayerData()
	if not key then
		return false
	end
	local characters = getDB().characters
	local previous = type(characters[key]) == "table" and characters[key] or nil
	local character = {}
	for field, value in pairs(previous or {}) do
		character[field] = value
	end
	for field, value in pairs(current) do
		character[field] = value
	end
	Util.NormalizeSpecialization(character)
	-- The MyKeyStone current-character card keeps carpool participation locked
	-- on and shows the live role prompt instead of a toggle. Repair stale false
	-- values whenever that character becomes current again.
	character.carpoolEnabled = true
	if type(character.roles) == "table" then
		character.roles = Util.CopyRoles(character.roles)
		character.role = nil
	elseif character.specRole then
		character.role = character.specRole
	end

	local keystone = GF.MythicPlusKeystoneCache and GF.MythicPlusKeystoneCache:GetSnapshot()
	local resetAt = Util.GetLastWeeklyResetTimestamp
		and Util.GetLastWeeklyResetTimestamp() or 0
	local keystoneUpdatedAt = tonumber(keystone and keystone.updatedAt) or 0
	local keystoneFresh = resetAt <= 0 or keystoneUpdatedAt >= resetAt
	if keystoneFresh and keystone
		and (keystone.state == "ready" or keystone.state == "empty")
	then
		character.challengeModeID = keystone.challengeModeID
		character.keyLevel = keystone.level
		character.dungeonName = keystone.dungeonName
		character.keystoneLink = keystone.keystoneLink
		character.keyUpgradeTrack = keystone.keyUpgradeTrack
		character.activityID = keystone.activityID
		character.groupID = keystone.groupID
		character.keyState = keystone.state == "ready" and "ready" or "empty"
		character.keystoneKnown = true
		character.hasKeystone = keystone.state == "ready"
		character.lastKeyCheckedAt = Util.Now()
		if keystone.state == "ready" then
			character.lastKeySeenAt = Util.Now()
		end
	end
	local rating = GF.MythicPlusRatingCache and GF.MythicPlusRatingCache:GetCurrent()
	local currentSeasonID = getCurrentSeasonID()
	local ratingSeasonID = tonumber(rating and rating.seasonID)
	local ratingIsCurrent = currentSeasonID
		and ratingSeasonID == currentSeasonID
	if rating and rating.score ~= nil and ratingIsCurrent then
		character.rating = rating.score
		character.ratingColor = rating.scoreColor
		character.ratingSeasonID = ratingSeasonID
	end
	if rating and rating.state == "ready" and ratingIsCurrent then
		character.bestRuns = Util.CopyRuns(rating.runs)
	end
	local weekly = GF.MythicPlusWeeklyCache and GF.MythicPlusWeeklyCache:GetSnapshot()
	if weekly then
		character.weekly = weekly
	end
	character.updatedAt = Util.Now()
	character.reason = reason
	characters[key] = character
	local changed = not previous
		or not semanticValuesEqual(previous, character)
	if changed then
		Util.Notify(self, reason or "refresh")
	end
	return changed, character
end
