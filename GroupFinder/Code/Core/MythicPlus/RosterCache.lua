local _, GF = ...

GF.MythicPlusRosterCache = GF.MythicPlusRosterCache or {}
local Cache = GF.MythicPlusRosterCache
local Util = GF.MythicPlusServiceUtil

local function collectUnits()
	local units = {}
	if IsInRaid and IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			units[#units + 1] = "raid" .. index
		end
	else
		units[#units + 1] = "player"
		if IsInGroup and IsInGroup() then
			for index = 1, GetNumSubgroupMembers() do
				units[#units + 1] = "party" .. index
			end
		end
	end
	return units
end

local function buildRoles(role)
	local normalized = Util.NormalizeRole(role)
	return normalized and { [normalized] = true } or {}
end

local function getSpecializationRole(character)
	Util.NormalizeSpecialization(character)
	local directRole = Util.NormalizeRole(character and character.specRole)
	if directRole then
		return directRole
	end
	local specID = tonumber(character and character.specID)
	local cache = GF.MythicPlusSpecializationCache
	if not (specID and cache and cache.GetInfo) then
		return nil
	end
	local info = cache:GetInfo(specID)
	if not info or tonumber(info.specID) ~= specID then
		return nil
	end
	local characterClass = character
		and (character.classFile or character.classFilename or character.class)
	characterClass = type(characterClass) == "string"
		and characterClass:upper() or nil
	if characterClass and info.classFile
		and characterClass ~= info.classFile
	then
		return nil
	end
	return Util.NormalizeRole(info.specRole)
end

local function resolveMemberRoles(character, snapshotOwner, isCurrent, assignedRole)
	if assignedRole then
		return buildRoles(assignedRole), assignedRole, "group-assigned", false, Util.Now()
	end

	if isCurrent then
		local roleSnapshot = GF.MythicPlusCurrentRoleService
			and GF.MythicPlusCurrentRoleService.GetSnapshot
			and GF.MythicPlusCurrentRoleService:GetSnapshot()
		local selectedRoles = Util.CopyRoles(
			roleSnapshot and roleSnapshot.rolesReady == true and roleSnapshot.roles)
		local primaryRole = Util.FirstRole(selectedRoles)
		if primaryRole then
			return selectedRoles, primaryRole, "local-selection", false,
				roleSnapshot and roleSnapshot.updatedAt
		end
	elseif snapshotOwner then
		local selectedRoles = Util.CopyRoles(character and character.roles)
		local primaryRole = Util.FirstRole(selectedRoles)
		if primaryRole then
			return selectedRoles, primaryRole, "peer-selection", false,
				snapshotOwner.updatedAt
		end
	end

	-- A specialization is considered reliable only for the local character or
	-- for a teammate whose current-character data came from a live GFMP2
	-- snapshot. Do not infer a role from class alone.
	if isCurrent or snapshotOwner then
		local specializationRole = getSpecializationRole(character)
		if specializationRole then
			return buildRoles(specializationRole), specializationRole,
				"specialization", true,
				snapshotOwner and snapshotOwner.updatedAt
					or character and character.updatedAt
		end
	end

	return {}, "NONE", "unknown", false, nil
end

local function getKeyState(character, isCurrent)
	if character and (tonumber(character.challengeModeID or character.mapID) and tonumber(character.keyLevel)) then
		return "ready"
	end
	if character and (character.keyState == "ready"
		or character.keyState == "empty"
		or character.keyState == "unknown")
	then
		return character.keyState
	end
	if isCurrent and GF.MythicPlusKeystoneCache and GF.MythicPlusKeystoneCache.GetSnapshot then
		local snapshot = GF.MythicPlusKeystoneCache:GetSnapshot()
		if snapshot and (snapshot.state == "ready" or snapshot.state == "empty") then
			return snapshot.state
		end
	end
	return character and character.keystoneKnown == true and "empty" or "unknown"
end

local function getKeyObservedAt(
	character, snapshotOwner, isCurrent, keyState, interopKey)
	if keyState ~= "ready" and keyState ~= "empty" then
		return nil
	end
	if interopKey then
		return tonumber(interopKey.keyObservedAt or interopKey.receivedAt)
	end
	if snapshotOwner then
		-- A remote snapshot's receive time remains stable for that packet. A
		-- normal roster rebuild must not make old key evidence look new.
		return tonumber(snapshotOwner.updatedAt)
	end
	if isCurrent and character then
		-- CharacterStore records lastKeyCheckedAt for both ready and explicit
		-- empty observations; lastKeySeenAt keeps older ready records usable.
		return tonumber(character.lastKeyCheckedAt)
			or tonumber(character.lastKeySeenAt)
	end
	return nil
end

local function buildMember(unit, rosterIndex, connectedHint)
	local key = Util.GetUnitKey(unit)
	local fullName, name, realm = Util.GetUnitFullName(unit)
	if not key or not fullName then
		return nil
	end
	local _, classFile, classID = UnitClass(unit)
	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
	local rating = GF.MythicPlusRatingCache and GF.MythicPlusRatingCache:GetByKey(key)
	local currentKey = GF.MythicPlusCharacterStore and GF.MythicPlusCharacterStore:GetCurrentKey()
	local isCurrent = currentKey == fullName
	local character = isCurrent and GF.MythicPlusCharacterStore:GetCurrent() or nil
	local snapshotOwner
	if not character and GF.MythicPlusGroupSnapshotService
		and GF.MythicPlusGroupSnapshotService.GetCurrentCharacterForMember
	then
		character, snapshotOwner = GF.MythicPlusGroupSnapshotService:GetCurrentCharacterForMember(fullName)
	end
	Util.NormalizeSpecialization(character)
	-- The current character's persistent CharacterStore record may belong to a
	-- prior season. Its live row is owned by the season-aware RatingCache.
	local characterRating = not isCurrent
		and character and tonumber(character.rating) or nil
	local keyState = getKeyState(character, isCurrent)
	local interopKey
	if keyState == "unknown"
		and not isCurrent
		and GF.MythicPlusKeystoneInteropService
		and GF.MythicPlusKeystoneInteropService.GetForMember
	then
		interopKey =
			GF.MythicPlusKeystoneInteropService:GetForMember(fullName)
		if interopKey and interopKey.keyState == "ready" then
			keyState = "ready"
		else
			interopKey = nil
		end
	end
	local keyObservedAt = getKeyObservedAt(
		character,
		snapshotOwner,
		isCurrent,
		keyState,
		interopKey)
	local assignedRole = Util.NormalizeRole(role)
	local roles, primaryRole, roleSource, roleInferred, roleUpdatedAt =
		resolveMemberRoles(character, snapshotOwner, isCurrent, assignedRole)
	local bestRuns
	if rating
		and type(rating.runs) == "table"
		and #rating.runs > 0
	then
		bestRuns = Util.CopyRuns(rating.runs)
	elseif not isCurrent
		and character
		and type(character.bestRuns) == "table"
	then
		bestRuns = Util.CopyRuns(character.bestRuns)
	elseif rating
		and rating.state == "ready"
		and type(rating.runs) == "table"
	then
		bestRuns = Util.CopyRuns(rating.runs)
	end
	local connected
	if type(connectedHint) == "boolean" then
		connected = connectedHint
	else
		connected = not UnitIsConnected or UnitIsConnected(unit) == true
	end
	local resolvedRating
	local ratingState
	local ratingSource
	if rating and tonumber(rating.score) ~= nil then
		resolvedRating = tonumber(rating.score)
		ratingState = rating.state or "ready"
		ratingSource = "rating-cache"
	elseif characterRating ~= nil then
		resolvedRating = characterRating
		ratingState = "ready"
		ratingSource = snapshotOwner and "group-snapshot"
			or "local-cache"
	elseif interopKey and tonumber(interopKey.rating) ~= nil then
		resolvedRating = tonumber(interopKey.rating)
		ratingState = "ready"
		ratingSource = interopKey.source
	else
		ratingState = rating and rating.state or "pending"
	end
	return {
		key = key,
		unit = unit,
		rosterIndex = rosterIndex,
		fullName = fullName,
		name = name,
		realm = realm,
		classFile = classFile,
		classID = classID,
		level = UnitLevel(unit),
		role = primaryRole,
		roles = roles,
		assignedRole = assignedRole or "NONE",
		primaryRole = primaryRole,
		roleSource = roleSource,
		roleInferred = roleInferred,
		roleUpdatedAt = roleUpdatedAt,
		leader = UnitIsGroupLeader and UnitIsGroupLeader(unit) == true,
		isCurrent = isCurrent,
		connected = connected,
		rating = resolvedRating,
		ratingColor = rating and rating.scoreColor or character and character.ratingColor or nil,
		ratingState = ratingState,
		ratingSource = ratingSource,
		bestRuns = bestRuns,
		specIcon = character and character.specIcon or nil,
		specID = character and character.specID or nil,
		specName = character and character.specName or nil,
		keyState = keyState,
		keyObservedAt = keyObservedAt,
		challengeModeID = keyState == "ready" and (
			interopKey and interopKey.challengeModeID
			or character and (character.challengeModeID or character.mapID))
			or nil,
		mapID = keyState == "ready" and (
			interopKey and interopKey.mapID
			or character and (character.mapID or character.challengeModeID))
			or nil,
		keyLevel = interopKey and interopKey.keyLevel
			or character and character.keyLevel or nil,
		dungeonName = interopKey and interopKey.dungeonName
			or character and character.dungeonName or nil,
		keystoneLink = not interopKey
			and character and character.keystoneLink or nil,
		activityID = interopKey and interopKey.activityID
			or character and character.activityID or nil,
		groupID = interopKey and interopKey.groupID
			or character and character.groupID or nil,
		keyUpgradeTrack = not interopKey
			and character and character.keyUpgradeTrack or nil,
		keystoneReadOnly = interopKey ~= nil,
		isInteropFallback = interopKey ~= nil,
		interopSource = interopKey and interopKey.interopSource or nil,
		interopLabel = interopKey and interopKey.interopLabel or nil,
		keystoneSource = interopKey and interopKey.source
			or snapshotOwner and "group-snapshot"
			or character and "local-cache"
			or "roster",
		isRosterOnly = character == nil,
		snapshotOwnerKey = snapshotOwner and snapshotOwner.ownerKey or nil,
		snapshotOwnerName = snapshotOwner and snapshotOwner.ownerName or nil,
		source = snapshotOwner and "group-snapshot"
			or character and "local-cache"
			or interopKey and interopKey.source
			or "roster",
	}
end

local TOOLTIP_SNAPSHOT_FIELDS = {
	"key",
	"fullName",
	"name",
	"realm",
	"classFile",
	"classID",
	"level",
	"rating",
	"ratingState",
	"ratingSource",
	"specIcon",
	"specID",
	"specName",
	"keyState",
	"keyObservedAt",
	"challengeModeID",
	"mapID",
	"keyLevel",
	"dungeonName",
	"keystoneLink",
	"activityID",
	"groupID",
	"keyUpgradeTrack",
	"keystoneReadOnly",
	"isInteropFallback",
	"interopSource",
	"interopLabel",
	"keystoneSource",
	"isRosterOnly",
	"snapshotOwnerKey",
	"snapshotOwnerName",
	"source",
}

local TOOLTIP_IDENTITY_FIELDS = {
	"key",
	"fullName",
	"name",
	"realm",
	"classFile",
	"classID",
	"level",
}

local TOOLTIP_KEY_FIELDS = {
	"keyState",
	"challengeModeID",
	"mapID",
	"keyLevel",
	"dungeonName",
	"keystoneLink",
	"activityID",
	"groupID",
	"keyUpgradeTrack",
	"keystoneReadOnly",
	"isInteropFallback",
	"interopSource",
	"interopLabel",
	"keystoneSource",
}

local function copyColor(color)
	if type(color) ~= "table" then
		return nil
	end
	return {
		r = tonumber(color.r) or 1,
		g = tonumber(color.g) or 1,
		b = tonumber(color.b) or 1,
		a = tonumber(color.a) or 1,
	}
end

local function copyTooltipSnapshot(source)
	if type(source) ~= "table" then
		return nil
	end
	local snapshot = {}
	for _, field in ipairs(TOOLTIP_SNAPSHOT_FIELDS) do
		snapshot[field] = source[field]
	end
	snapshot.ratingColor = copyColor(source.ratingColor)
	if type(source.bestRuns) == "table" then
		snapshot.bestRuns = Util.CopyRuns(source.bestRuns)
	end
	snapshot.capturedAt = tonumber(source.capturedAt) or Util.Now()
	return snapshot
end

local function copyFields(target, source, fields)
	for _, field in ipairs(fields) do
		target[field] = source[field]
	end
end

local function copyNonNilFields(target, source, fields)
	for _, field in ipairs(fields) do
		if source[field] ~= nil then
			target[field] = source[field]
		end
	end
end

local function getWeeklyResetAt()
	return Util.GetLastWeeklyResetTimestamp
		and tonumber(Util.GetLastWeeklyResetTimestamp())
		or 0
end

local function clearTooltipKey(snapshot)
	snapshot.keyState = "unknown"
	snapshot.keyObservedAt = nil
	for _, field in ipairs(TOOLTIP_KEY_FIELDS) do
		if field ~= "keyState" then
			snapshot[field] = nil
		end
	end
end

local function sanitizeTooltipKey(snapshot)
	if type(snapshot) ~= "table" then
		return snapshot
	end
	local resetAt = getWeeklyResetAt()
	if (snapshot.keyState == "ready" or snapshot.keyState == "empty")
		and resetAt > 0
		and (tonumber(snapshot.keyObservedAt) or 0) < resetAt
	then
		clearTooltipKey(snapshot)
	end
	return snapshot
end

local function mergeOnlineTooltipSnapshot(previous, member)
	if type(previous) ~= "table" then
		local snapshot = copyTooltipSnapshot(member)
		return sanitizeTooltipKey(snapshot)
	end
	local snapshot = copyTooltipSnapshot(previous)
	copyNonNilFields(snapshot, member, TOOLTIP_IDENTITY_FIELDS)
	if snapshot.ratingSource == "libkeystone"
		and member.ratingSource ~= "libkeystone"
	then
		snapshot.rating = nil
		snapshot.ratingState = member.ratingState or "pending"
		snapshot.ratingSource = nil
		snapshot.ratingColor = nil
	end
	if tonumber(member.rating) ~= nil or member.ratingState == "ready" then
		snapshot.rating = member.rating
		snapshot.ratingState = member.ratingState
		snapshot.ratingSource = member.ratingSource
		snapshot.ratingColor = copyColor(member.ratingColor)
	end
	if type(member.bestRuns) == "table" then
		snapshot.bestRuns = Util.CopyRuns(member.bestRuns)
	end
	if member.specID ~= nil
		or member.specIcon ~= nil
		or member.specName ~= nil
	then
		snapshot.specIcon = member.specIcon
		snapshot.specID = member.specID
		snapshot.specName = member.specName
	end
	if snapshot.isInteropFallback == true
		and member.keyState == "unknown"
	then
		-- Compatibility records have a finite lease. Once the source expires
		-- or withdraws 0/0, do not keep the old ready key in the online
		-- tooltip cache.
		clearTooltipKey(snapshot)
		if snapshot.ratingSource == "libkeystone" then
			snapshot.rating = nil
			snapshot.ratingState = member.ratingState or "pending"
			snapshot.ratingSource = nil
			snapshot.ratingColor = nil
		end
	end
	if member.keyState == "ready" or member.keyState == "empty" then
		local observedAt = tonumber(member.keyObservedAt)
		local resetAt = getWeeklyResetAt()
		if resetAt <= 0 or observedAt and observedAt >= resetAt then
			copyFields(snapshot, member, TOOLTIP_KEY_FIELDS)
			snapshot.keyObservedAt = observedAt
		end
	end
	if member.isRosterOnly == false then
		snapshot.isRosterOnly = false
		snapshot.snapshotOwnerKey = member.snapshotOwnerKey
		snapshot.snapshotOwnerName = member.snapshotOwnerName
		snapshot.source = member.source
	end
	snapshot.capturedAt = Util.Now()
	return sanitizeTooltipKey(snapshot)
end

local function addIdentityAlias(aliases, prefix, value)
	if type(value) ~= "string" or value == "" then
		return
	end
	aliases[#aliases + 1] = prefix .. string.lower(value)
end

local function getIdentityAliases(member)
	local aliases = {}
	addIdentityAlias(aliases, "key:", member and member.key)
	addIdentityAlias(aliases, "name:", member and member.fullName)
	return aliases
end

local function findTooltipSnapshot(snapshots, member)
	for _, alias in ipairs(getIdentityAliases(member)) do
		local snapshot = snapshots and snapshots[alias]
		if snapshot then
			return snapshot
		end
	end
end

local function indexTooltipSnapshot(snapshots, member, snapshot)
	for _, alias in ipairs(getIdentityAliases(member)) do
		snapshots[alias] = snapshot
	end
	for _, alias in ipairs(getIdentityAliases(snapshot)) do
		snapshots[alias] = snapshot
	end
end

local function getOfflineTooltipSnapshot(snapshot)
	local copy = copyTooltipSnapshot(snapshot)
	if not copy then
		return nil
	end
	return sanitizeTooltipKey(copy)
end

function Cache:AddListener(callback)
	Util.AddListener(self, callback)
end

function Cache:GetMembers()
	local members = Util.CopyArray(self.members)
	for _, member in ipairs(GF.MythicPlusDebugService
		and GF.MythicPlusDebugService.GetRosterMembers
		and GF.MythicPlusDebugService:GetRosterMembers() or {})
	do
		local copy = {}
		for key, value in pairs(member) do
			copy[key] = value
		end
		Util.NormalizeSpecialization(copy)
		local assignedRole = Util.NormalizeRole(member.role)
		local roles = assignedRole and buildRoles(assignedRole) or Util.CopyRoles(member.roles)
		local primaryRole = assignedRole or Util.FirstRole(roles)
		local roleSource = member.roleSource
		local roleInferred = member.roleInferred == true
		if not primaryRole then
			primaryRole = getSpecializationRole(member)
			if primaryRole then
				roles = buildRoles(primaryRole)
				roleSource = roleSource or "specialization"
				roleInferred = true
			end
		end
		copy.role = primaryRole or "NONE"
		copy.roles = roles
		copy.primaryRole = primaryRole or "NONE"
		copy.roleSource = roleSource
			or (assignedRole and "group-assigned")
			or (primaryRole and "peer-selection")
			or "unknown"
		copy.roleInferred = roleInferred
		members[#members + 1] = copy
	end
	return members
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

function Cache:OnUnitConnection(unitTarget, isConnected)
	if type(unitTarget) == "string"
		and unitTarget ~= ""
		and type(isConnected) == "boolean"
	then
		self.connectionHints = self.connectionHints or {}
		self.connectionHints[string.lower(unitTarget)] = isConnected
	end
	self:RequestRefresh("UNIT_CONNECTION")
end

function Cache:Refresh(reason)
	local members = {}
	local previousTooltipSnapshots = self.tooltipSnapshots or {}
	local nextTooltipSnapshots = {}
	local connectionHints = self.connectionHints or {}
	self.connectionHints = nil
	for rosterIndex, unit in ipairs(collectUnits()) do
		local member = buildMember(
			unit,
			rosterIndex,
			connectionHints[unit])
		if member then
			local tooltipSnapshot = findTooltipSnapshot(
				previousTooltipSnapshots,
				member)
			if member.connected == false then
				member.tooltipSnapshot = getOfflineTooltipSnapshot(
					tooltipSnapshot)
			else
				tooltipSnapshot = mergeOnlineTooltipSnapshot(
					tooltipSnapshot,
					member)
			end
			if tooltipSnapshot then
				indexTooltipSnapshot(
					nextTooltipSnapshots,
					member,
					tooltipSnapshot)
			end
			members[#members + 1] = member
		end
	end
	if GF.MythicPlusRosterSort and GF.MythicPlusRosterSort.Sort then
		members = GF.MythicPlusRosterSort:Sort("group", members)
	else
		table.sort(members, function(a, b)
			return (a.rosterIndex or 9999) < (b.rosterIndex or 9999)
		end)
	end
	self.members = members
	self.tooltipSnapshots = nextTooltipSnapshots
	self.updatedAt = Util.Now()
	Util.Notify(self, reason or "refresh")
end
