local _, GF = ...

local Projection = {}
GF.CurrentGroupProjection = Projection

local CURRENT_GROUP_ELEMENT_KIND = "current_group"
local ENTRY_COPY_FIELDS = {
	"tanks",
	"heals",
	"dps",
	"_displayCounts",
	"_displayCountsLoaded",
}
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local ROLE_ENTRY_FIELDS = {
	TANK = "tanks",
	HEALER = "heals",
	DAMAGER = "dps",
}
local PLAYER_FIELDS = {
	"name", "guid", "classFilename", "assignedRole", "specID", "specName",
}

local function isSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

local function usableIdentity(value)
	if value == nil or isSecret(value) then
		return nil
	end
	if type(value) == "string" and value == "" then
		return nil
	end
	return value
end

local function readField(owner, key)
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.ReadField) == "function" then
		return snapshot.ReadField(owner, key)
	end
	if type(owner) ~= "table" then
		return nil, "unavailable"
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok or isSecret(value) then
		return nil, ok and "secret" or "error"
	end
	return value, value == nil and "missing" or "value"
end

-- Active-entry kstrings may be secret but remain directly renderable by a
-- FontString.  This display-only path deliberately does not inspect, compare,
-- stringify, or persist the value.
local function readOpaqueDisplayField(owner, key)
	if type(owner) ~= "table" then
		return nil, false
	end
	local ok, value = pcall(function()
		return owner[key]
	end)
	if not ok then
		return nil, false
	end
	return value, true
end

local function safeRenderedDisplayValue(value)
	if isSecret(value) then
		return nil
	end
	local ok, safe = pcall(function()
		local valueType = type(value)
		if valueType == "string" then
			return value:find("|K", 1, true) == nil and value or nil
		elseif valueType == "number" then
			return value
		end
	end)
	return ok and safe or nil
end

local function cloneRenderedDisplayValue(value)
	local snapshot = GF.SearchResultSnapshot
	local clone = snapshot and snapshot.CloneRenderedDisplayText
	if type(clone) ~= "function" then
		return safeRenderedDisplayValue(value)
	end
	local ok, rendered = pcall(clone, value)
	if not ok then
		return nil
	end
	return safeRenderedDisplayValue(rendered)
end

local function activeDisplayFields(activeInfo)
	local name, nameReadable = readOpaqueDisplayField(activeInfo, "name")
	local comment, commentReadable = readOpaqueDisplayField(activeInfo, "comment")
	local voiceChat, voiceReadable = readOpaqueDisplayField(activeInfo, "voiceChat")
	-- LfgEntryData.voiceChat is a kstringLfgListApplicant. The comparison
	-- below may therefore produce a secret boolean. Keep that token opaque:
	-- callers may pass it to SetAlphaFromBoolean, but must never branch on,
	-- compare, stringify, fingerprint, or persist it.
	local voiceShown = false
	local voiceShownProvided = false
	if voiceReadable and isSecret(voiceChat) then
		voiceShown = voiceChat ~= ""
		voiceShownProvided = true
	elseif voiceReadable and type(voiceChat) == "string" then
		voiceShown = voiceChat ~= ""
		voiceShownProvided = true
	end
	local safeName = nameReadable and cloneRenderedDisplayValue(name) or nil
	local safeComment = commentReadable
		and cloneRenderedDisplayValue(comment) or nil
	local safeVoiceChat = voiceReadable
		and cloneRenderedDisplayValue(voiceChat) or nil
	local displayName
	local displayComment
	if nameReadable then
		displayName = name
	end
	if commentReadable then
		displayComment = comment
	end
	local function fingerprintValue(value)
		return value == nil and "\030" or tostring(value)
	end
	return {
		name = displayName,
		comment = displayComment,
		voiceChat = safeVoiceChat,
		voiceShown = voiceShown,
		commentProvided = true,
		voiceChatProvided = true,
		voiceShownProvided = voiceShownProvided,
		fingerprint = table.concat({
			fingerprintValue(safeName),
			fingerprintValue(safeComment),
			fingerprintValue(safeVoiceChat),
		}, "\031"),
	}
end

local function partyGUIDFromInfo(info)
	local value, state = readField(info, "partyGUID")
	return state == "value" and usableIdentity(value) or nil
end

local function infoHasSelf(info)
	local value, state = readField(info, "hasSelf")
	return state == "value" and value == true
end

local function isPlayerInHomeGroup()
	if type(IsInGroup) == "function" then
		local ok, inGroup
		if LE_PARTY_CATEGORY_HOME ~= nil then
			ok, inGroup = pcall(IsInGroup, LE_PARTY_CATEGORY_HOME)
		else
			ok, inGroup = pcall(IsInGroup)
		end
		if ok then
			return inGroup == true
		end
	end
	if type(GetNumGroupMembers) == "function" then
		local ok, count
		if LE_PARTY_CATEGORY_HOME ~= nil then
			ok, count = pcall(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME)
		else
			ok, count = pcall(GetNumGroupMembers)
		end
		return ok and (tonumber(count) or 0) > 0
	end
	return false
end

local function currentPartyGUID()
	local apply = GF.Apply
	if apply and type(apply.GetCurrentGroupPartyGUID) == "function" then
		return usableIdentity(apply:GetCurrentGroupPartyGUID())
	end
	return nil
end

local function currentGroupMemberCount()
	if type(GetNumGroupMembers) ~= "function" then
		return 0
	end
	local ok, count
	if LE_PARTY_CATEGORY_HOME ~= nil then
		ok, count = pcall(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME)
	else
		ok, count = pcall(GetNumGroupMembers)
	end
	return ok and math.max(0, math.floor(tonumber(count) or 0)) or 0
end

local function unitExists(unit)
	if type(UnitExists) ~= "function" then
		return unit == "player"
	end
	local ok, exists = pcall(UnitExists, unit)
	return ok and exists == true
end

local function currentGroupUnits()
	local units = {}
	local count = currentGroupMemberCount()
	local inRaid = false
	if type(IsInRaid) == "function" then
		local ok, value
		if LE_PARTY_CATEGORY_HOME ~= nil then
			ok, value = pcall(IsInRaid, LE_PARTY_CATEGORY_HOME)
		else
			ok, value = pcall(IsInRaid)
		end
		inRaid = ok and value == true
	end
	if inRaid then
		for index = 1, count do
			local unit = "raid" .. tostring(index)
			if unitExists(unit) then
				units[#units + 1] = unit
			end
		end
	else
		units[1] = "player"
		for index = 1, math.max(0, count - 1) do
			local unit = "party" .. tostring(index)
			if unitExists(unit) then
				units[#units + 1] = unit
			end
		end
	end
	return units
end

local function currentGroupLeader(units)
	if type(UnitIsGroupLeader) ~= "function" then
		return nil
	end
	for _, unit in ipairs(units or {}) do
		local leaderOK, leader = pcall(UnitIsGroupLeader, unit)
		if leaderOK and leader == true then
			local nameOK, name, realm
			if type(UnitFullName) == "function" then
				nameOK, name, realm = pcall(UnitFullName, unit)
			elseif type(UnitName) == "function" then
				nameOK, name, realm = pcall(UnitName, unit)
			end
			name = nameOK and usableIdentity(name) or nil
			realm = nameOK and usableIdentity(realm) or nil
			if name then
				local classFilename
				if type(UnitClass) == "function" then
					local classOK, _, value = pcall(UnitClass, unit)
					classFilename = classOK and usableIdentity(value) or nil
				end
				return {
					name = realm and realm ~= ""
						and (name .. "-" .. realm) or name,
					classFilename = classFilename,
					isLeader = true,
				}
			end
		end
	end
	return nil
end

local function updateEntryLeader(entry, leader, fallbackLeader)
	if type(entry) ~= "table" or type(leader) ~= "table"
		or not usableIdentity(leader.name)
	then
		return false
	end
	if not leader.classFilename and type(fallbackLeader) == "table"
		and fallbackLeader.name == leader.name
	then
		leader.classFilename = usableIdentity(fallbackLeader.classFilename)
	end
	local current = entry.leader
	local changed = type(current) ~= "table"
		or current.name ~= leader.name
		or current.classFilename ~= leader.classFilename
	if changed then
		entry.leader = leader
	end
	local info = entry.info
	if type(info) == "table" and info.leaderName ~= leader.name then
		info.leaderName = leader.name
		changed = true
	end
	return changed
end

local function updateEntryLeaderFromRoster(entry, fallbackLeader)
	return updateEntryLeader(
		entry,
		currentGroupLeader(currentGroupUnits()),
		fallbackLeader)
end

local function currentGroupRoleCounts(units)
	local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
	for _, unit in ipairs(units or {}) do
		local ok, role
		if type(UnitGroupRolesAssigned) == "function" then
			ok, role = pcall(UnitGroupRolesAssigned, unit)
		end
		if not ok or role == "DPS" then
			role = "DAMAGER"
		end
		-- Blizzard's GetGroupMemberCountsForDisplay treats NOROLE as damage.
		-- Creation can publish the current row before the assigned-role event, so
		-- keep every known HOME member visible during that short transition.
		if counts[role] == nil then
			role = "DAMAGER"
		end
		counts[role] = counts[role] + 1
	end
	return counts
end

local function currentGroupPlayers(units)
	local players = {}
	local roster = GF.MythicPlusRosterCache
	local members
	if roster and type(roster.GetMembers) == "function" then
		local ok, value = pcall(roster.GetMembers, roster)
		members = ok and type(value) == "table" and value or nil
	end
	local fallbackRealm
	if type(GetNormalizedRealmName) == "function" then
		local ok, value = pcall(GetNormalizedRealmName)
		fallbackRealm = ok and usableIdentity(value) or nil
	end
	if not fallbackRealm and type(GetRealmName) == "function" then
		local ok, value = pcall(GetRealmName)
		fallbackRealm = ok and usableIdentity(value) or nil
	end
	for _, unit in ipairs(units or {}) do
		local nameOK, name, realm
		if type(UnitFullName) == "function" then
			nameOK, name, realm = pcall(UnitFullName, unit)
		elseif type(UnitName) == "function" then
			nameOK, name, realm = pcall(UnitName, unit)
		end
		name = nameOK and usableIdentity(name) or nil
		realm = nameOK and usableIdentity(realm) or nil
		if name and (realm or fallbackRealm) then
			local classFilename
			local assignedRole
			local guid
			if type(UnitGUID) == "function" then
				local guidOK, value = pcall(UnitGUID, unit)
				guid = guidOK and usableIdentity(value) or nil
				guid = type(guid) == "string" and guid or nil
			end
			if type(UnitClass) == "function" then
				local classOK, _, value = pcall(UnitClass, unit)
				classFilename = classOK and usableIdentity(value) or nil
			end
			if type(UnitGroupRolesAssigned) == "function" then
				local roleOK, value = pcall(UnitGroupRolesAssigned, unit)
				assignedRole = roleOK and usableIdentity(value) or nil
			end
			local player = {
				name = name .. "-" .. (realm or fallbackRealm),
				displayName = name,
				classFilename = classFilename,
				assignedRole = assignedRole,
				guid = guid,
			}
			-- The current row is a HOME-roster projection, rather than a native
			-- search-result member list. Use the same specialization authority as
			-- the party sidebar; never join by a reusable party/raid unit token.
			for _, member in ipairs(members or {}) do
				local key = readField(member, "key")
				local fullName = readField(member, "fullName")
				local memberClass = readField(member, "classFile")
				local matches = guid and key == guid
					or not guid and fullName == player.name
				if matches and (not classFilename or not memberClass
					or classFilename == memberClass)
				then
					local specID = readField(member, "specID")
					local specName = readField(member, "specName")
					if type(specID) == "number" and specID > 0 then
						player.specID = specID
					end
					if type(specName) == "string" and specName ~= "" then
						player.specName = specName
					end
					break
				end
			end
			players[#players + 1] = player
		end
	end
	return players
end

local function samePlayers(left, right)
	if type(left) ~= "table" or #left ~= #right then
		return false
	end
	for index = 1, #right do
		for _, field in ipairs(PLAYER_FIELDS) do
			if not left[index] or left[index][field] ~= right[index][field] then
				return false
			end
		end
	end
	return true
end

local function updateEntryRosterFromGroup(entry)
	if type(entry) ~= "table" or type(entry.info) ~= "table" then
		return false
	end
	local units = currentGroupUnits()
	local counts = currentGroupRoleCounts(units)
	local players = currentGroupPlayers(units)
	local memberCount = math.max(currentGroupMemberCount(), #units)
	local knownCount = counts.TANK + counts.HEALER + counts.DAMAGER
	if knownCount < memberCount then
		counts.DAMAGER = counts.DAMAGER + memberCount - knownCount
	end

	local changed = tonumber(entry.info.numMembers) ~= memberCount
	entry.info.numMembers = memberCount
	local displayCounts = type(entry._displayCounts) == "table"
		and entry._displayCounts or {}
	for _, role in ipairs(ROLE_ORDER) do
		if tonumber(displayCounts[role]) ~= counts[role] then
			changed = true
		end
		displayCounts[role] = counts[role]
	end
	entry._displayCounts = displayCounts
	entry._displayCountsLoaded = true
	entry._memberCountsLoaded = true
	if not samePlayers(entry.players, players) then
		entry.players = players
		changed = true
	end
	for role, field in pairs(ROLE_ENTRY_FIELDS) do
		if tonumber(entry[field]) ~= counts[role] then
			changed = true
		end
		entry[field] = counts[role]
	end
	return changed
end

local function copyEntryField(target, source, key)
	if type(target) ~= "table" or type(source) ~= "table" then
		return
	end
	local ok, value = pcall(rawget, source, key)
	if ok and not isSecret(value) then
		if key == "_displayCounts" and type(value) == "table" then
			local tank = readField(value, "TANK")
			local healer = readField(value, "HEALER")
			local damager = readField(value, "DAMAGER")
			target[key] = {
				TANK = tonumber(tank) or 0,
				HEALER = tonumber(healer) or 0,
				DAMAGER = tonumber(damager) or 0,
			}
		else
			target[key] = value
		end
	end
end

local function snapshotFingerprint(resultID, entry)
	local info = entry and entry.info or {}
	local snapshot = GF.SearchResultSnapshot
	local primaryActivityID = snapshot and snapshot.GetPrimaryActivityID
		and snapshot.GetPrimaryActivityID(info) or nil
	local values = {
		resultID or "",
		primaryActivityID or "",
		tonumber(entry and entry.tanks) or "",
		tonumber(entry and entry.heals) or "",
		tonumber(entry and entry.dps) or "",
		entry and entry.leader and entry.leader.classFilename or "",
	}
	for _, key in ipairs({
		"name", "leaderName", "comment", "voiceChat", "numMembers",
		"requiredItemLevel", "requiredDungeonScore", "leaderOverallDungeonScore",
		"isDelisted", "censored", "partyGUID", "hasSelf",
	}) do
		local value, state = readField(info, key)
		values[#values + 1] = state == "value" and value or ""
	end
	for _, player in ipairs(entry and entry.players or {}) do
		for _, field in ipairs(PLAYER_FIELDS) do
			values[#values + 1] = player[field] or ""
		end
	end
	for index, value in ipairs(values) do
		values[index] = tostring(value == nil and "" or value)
	end
	return table.concat(values, "\031")
end

local function buildSnapshotEntry(resultID, info, sourceEntry)
	local snapshot = GF.SearchResultSnapshot
	if not snapshot then
		return nil
	end
	local compact = type(snapshot.CloneCompactSearchResultInfo) == "function"
		and snapshot.CloneCompactSearchResultInfo(info, true)
		or snapshot.CompactSearchResultInfo(info, true)
	if type(compact) ~= "table" then
		return nil
	end
	local renderText = snapshot.CloneRenderedDisplayText
	if type(renderText) == "function" then
		local result = GF.Result
		local title = resultID and result
			and type(result.GetListingTitle) == "function"
			and result:GetListingTitle(info, resultID) or info.name
		local comment = resultID and result
			and type(result.GetListingComment) == "function"
			and result:GetListingComment(info, resultID) or info.comment
		compact.name = renderText(title) or renderText(info.name) or "?"
		compact.comment = renderText(comment) or ""
		compact.voiceChat = renderText(info.voiceChat) or ""
	end
	local entry
	if resultID and type(snapshot.NewEntry) == "function" then
		entry = snapshot.NewEntry(resultID, compact)
	elseif type(snapshot.HydrateEntry) == "function" then
		entry = snapshot.HydrateEntry({ info = compact }, compact)
	end
	if not entry then
		return nil
	end
	entry._gfCurrentGroupProjection = true
	for _, key in ipairs(ENTRY_COPY_FIELDS) do
		copyEntryField(entry, sourceEntry, key)
	end
	if entry._displayCountsLoaded ~= true
		or type(entry._displayCounts) ~= "table"
	then
		entry._displayCounts = {
			TANK = tonumber(entry.tanks) or 0,
			HEALER = tonumber(entry.heals) or 0,
			DAMAGER = tonumber(entry.dps) or 0,
		}
		entry._displayCountsLoaded = true
	end
	entry.tanks = tonumber(entry._displayCounts.TANK) or 0
	entry.heals = tonumber(entry._displayCounts.HEALER) or 0
	entry.dps = tonumber(entry._displayCounts.DAMAGER) or 0
	return entry
end

local function currentActiveEntryInfo()
	if not isPlayerInHomeGroup() then
		return nil
	end
	local session = GF.RecruitmentSession
	if not (session and type(session.GetActive) == "function") then
		return nil
	end
	local infoOK, activeInfo = pcall(session.GetActive, session)
	if infoOK ~= true or type(activeInfo) ~= "table" then
		return nil
	end
	return activeInfo
end

local function hasPublishedRecruitment()
	local session = GF.RecruitmentSession
	if session and type(session.HasActive) == "function" then
		local ok, active = pcall(session.HasActive, session)
		return ok and active == true
	end
	return false
end

local function activeEntrySnapshot()
	local activeInfo = currentActiveEntryInfo()
	if not activeInfo then
		return nil, nil
	end
	local snapshot = GF.SearchResultSnapshot
	local info = snapshot and type(snapshot.CloneCompactSearchResultInfo) == "function"
		and snapshot.CloneCompactSearchResultInfo(activeInfo, true) or nil
	if type(info) ~= "table" then
		return nil, nil
	end
	local units = currentGroupUnits()
	local counts = currentGroupRoleCounts(units)
	local players = currentGroupPlayers(units)
	local leader = currentGroupLeader(units)
	info.hasSelf = true
	info.partyGUID = currentPartyGUID()
	info.leaderName = leader and leader.name or nil
	info.numMembers = currentGroupMemberCount()
	info.isDelisted = false
	info.crossFactionListing = info.crossFactionListing
		or info.isCrossFactionListing
	info.age = info.age or info.duration
	local display = activeDisplayFields(activeInfo)
	return info, {
		tanks = counts.TANK,
		heals = counts.HEALER,
		dps = counts.DAMAGER,
		_displayCounts = counts,
		_displayCountsLoaded = true,
		players = players,
		_gfCurrentGroupLeader = leader,
		_gfCurrentGroupDisplayName = display.name,
		_gfCurrentGroupDisplayComment = display.comment,
		_gfCurrentGroupDisplayVoiceChat = display.voiceChat,
		_gfCurrentGroupDisplayVoiceShown = display.voiceShown,
		_gfCurrentGroupDisplayCommentProvided = display.commentProvided,
		_gfCurrentGroupDisplayVoiceChatProvided = display.voiceChatProvided,
		_gfCurrentGroupDisplayVoiceShownProvided = display.voiceShownProvided,
		_gfCurrentGroupDisplayFingerprint = display.fingerprint,
	}
end

local function cachedInfoForResult(resultState, resultID)
	if not (resultState and resultID) then
		return nil, nil
	end
	local entry = resultState.entryCache and resultState.entryCache[resultID]
	local info = entry and entry.info
	if not info and type(resultState.GetCachedSearchResultInfo) == "function" then
		info = resultState:GetCachedSearchResultInfo(resultID)
	end
	return info, entry
end

local function isLiveAuthoritative(resultState, resultID)
	return resultState ~= nil
		and type(resultState.IsLiveSearchResultInfoAuthoritative) == "function"
		and resultState:IsLiveSearchResultInfoAuthoritative(resultID) == true
end

function Projection:GetElementKind()
	return CURRENT_GROUP_ELEMENT_KIND
end

function Projection:IsElement(elementData)
	return type(elementData) == "table"
		and elementData.kind == CURRENT_GROUP_ELEMENT_KIND
end

function Projection:IsActive()
	return isPlayerInHomeGroup()
		and type(self.entry) == "table"
		and type(self.entry.info) == "table"
end

function Projection:Clear()
	local hadProjection = self.entry ~= nil or self.partyGUID ~= nil
	self.entry = nil
	self.resultID = nil
	self.partyGUID = nil
	self.projectionKey = nil
	self.snapshotFingerprint = nil
	self.activeDisplayName = nil
	self.activeDisplayComment = nil
	self.activeDisplayVoiceChat = nil
	self.activeDisplayVoiceShown = nil
	self.activeDisplayCommentProvided = nil
	self.activeDisplayVoiceChatProvided = nil
	self.activeDisplayVoiceShownProvided = nil
	self.activeDisplayFingerprint = nil
	if hadProjection then
		self.revision = (tonumber(self.revision) or 0) + 1
	end
	return hadProjection
end

function Projection:OnGroupJoined(partyGUID)
	partyGUID = usableIdentity(partyGUID)
	if partyGUID and self.partyGUID and self.partyGUID ~= partyGUID then
		self:Clear()
	end
	if partyGUID then
		self.partyGUID = partyGUID
	end
end

function Projection:OnGroupLeft(partyGUID)
	partyGUID = usableIdentity(partyGUID)
	if partyGUID and self.partyGUID and partyGUID ~= self.partyGUID then
		return false
	end
	return self:Clear()
end

function Projection:OnRosterChanged(inGroup, partyGUID)
	if inGroup ~= true then
		return self:Clear()
	end
	self:OnGroupJoined(partyGUID)
	local observed = self:ObserveActiveEntry()
	local refreshed = self:RefreshRosterFromGroup()
	return observed or refreshed
end

function Projection:OnRolesChanged()
	local observed = self:ObserveActiveEntry()
	local refreshed = self:RefreshRosterFromGroup()
	return observed or refreshed
end

function Projection:OnActiveEntryUpdated()
	-- The opaque voice visibility token cannot participate in a Lua
	-- fingerprint. The authoritative event is therefore the generation fence
	-- for voice-only edits and forces the stable current-group row to rebind.
	if not self:IsActive() then
		return false
	end
	self.revision = (tonumber(self.revision) or 0) + 1
	return true
end

function Projection:IsCurrentIdentity(resultID, info)
	if not isPlayerInHomeGroup() then
		return false
	end
	local apply = GF.Apply
	if apply and type(apply.IsCurrentGroupResult) == "function"
		and apply:IsCurrentGroupResult(resultID, info) == true
	then
		return true
	end
	local currentGUID = currentPartyGUID()
	local candidateGUID = partyGUIDFromInfo(info)
	if currentGUID and candidateGUID then
		return currentGUID == candidateGUID
	end
	return infoHasSelf(info)
end

function Projection:Observe(resultID, info, sourceEntry, resultState)
	resultID = tonumber(resultID)
	if not (resultID and resultID > 0 and type(info) == "table") then
		return false
	end
	if not self:IsCurrentIdentity(resultID, info) then
		return false
	end
	local candidateGUID = partyGUIDFromInfo(info)
	local homeGUID = currentPartyGUID()
	local identityGUID = homeGUID or candidateGUID
	if homeGUID and candidateGUID and homeGUID ~= candidateGUID then
		return false
	end
	if self.partyGUID and identityGUID and self.partyGUID ~= identityGUID then
		self:Clear()
	end
	local entry = buildSnapshotEntry(resultID, info, sourceEntry)
	if not entry then
		return false
	end
	updateEntryRosterFromGroup(entry)
	updateEntryLeaderFromRoster(entry, self.entry and self.entry.leader)
	self.generation = tonumber(self.generation) or 0
	if not self.projectionKey then
		self.generation = self.generation + 1
		self.projectionKey = "current-group:" .. tostring(self.generation)
	end
	local fingerprint = snapshotFingerprint(resultID, entry)
	if self.entry and self.resultID == resultID
		and self.partyGUID == (identityGUID or self.partyGUID)
		and self.snapshotFingerprint == fingerprint
	then
		return false
	end
	self.partyGUID = identityGUID or self.partyGUID
	self.resultID = resultID
	self.entry = entry
	self.snapshotFingerprint = fingerprint
	self.lastObservedWasLive = isLiveAuthoritative(resultState or GF.Result, resultID)
	self.revision = (tonumber(self.revision) or 0) + 1
	return true
end

function Projection:ObserveActiveEntry()
	if self.entry and self.entry._gfCurrentGroupSource ~= "active" then
		return false
	end
	local info, sourceEntry = activeEntrySnapshot()
	if not info then
		return false
	end
	local identityGUID = currentPartyGUID() or partyGUIDFromInfo(info)
	if self.partyGUID and identityGUID and self.partyGUID ~= identityGUID then
		self:Clear()
	end
	local entry = buildSnapshotEntry(nil, info, sourceEntry)
	if not entry then
		return false
	end
	updateEntryRosterFromGroup(entry)
	updateEntryLeader(
		entry,
		sourceEntry._gfCurrentGroupLeader,
		self.entry and self.entry.leader)
	entry._gfCurrentGroupSource = "active"
	local previousDisplayFingerprint = self.activeDisplayFingerprint
	self.activeDisplayName = sourceEntry._gfCurrentGroupDisplayName
	self.activeDisplayComment = sourceEntry._gfCurrentGroupDisplayComment
	self.activeDisplayVoiceChat = sourceEntry._gfCurrentGroupDisplayVoiceChat
	self.activeDisplayVoiceShown = sourceEntry._gfCurrentGroupDisplayVoiceShown
	self.activeDisplayCommentProvided =
		sourceEntry._gfCurrentGroupDisplayCommentProvided
	self.activeDisplayVoiceChatProvided =
		sourceEntry._gfCurrentGroupDisplayVoiceChatProvided
	self.activeDisplayVoiceShownProvided =
		sourceEntry._gfCurrentGroupDisplayVoiceShownProvided
	self.activeDisplayFingerprint = sourceEntry._gfCurrentGroupDisplayFingerprint
	self.generation = tonumber(self.generation) or 0
	if not self.projectionKey then
		self.generation = self.generation + 1
		self.projectionKey = "current-group:" .. tostring(self.generation)
	end
	local fingerprint = snapshotFingerprint(nil, entry)
	if self.entry and self.resultID == nil
		and self.partyGUID == (identityGUID or self.partyGUID)
		and self.snapshotFingerprint == fingerprint
		and previousDisplayFingerprint == self.activeDisplayFingerprint
	then
		return false
	end
	self.partyGUID = identityGUID or self.partyGUID
	self.resultID = nil
	self.entry = entry
	self.snapshotFingerprint = fingerprint
	self.lastObservedWasLive = nil
	self.revision = (tonumber(self.revision) or 0) + 1
	return true
end

function Projection:RefreshActiveDisplayFields()
	local activeInfo = currentActiveEntryInfo()
	if not activeInfo then
		local changed = self.activeDisplayFingerprint ~= nil
		self.activeDisplayName = nil
		self.activeDisplayComment = nil
		self.activeDisplayVoiceChat = nil
		self.activeDisplayVoiceShown = nil
		self.activeDisplayCommentProvided = nil
		self.activeDisplayVoiceChatProvided = nil
		self.activeDisplayVoiceShownProvided = nil
		self.activeDisplayFingerprint = nil
		if changed then
			self.revision = (tonumber(self.revision) or 0) + 1
		end
		return changed
	end
	local display = activeDisplayFields(activeInfo)
	local changed = self.activeDisplayFingerprint ~= display.fingerprint
	self.activeDisplayName = display.name
	self.activeDisplayComment = display.comment
	self.activeDisplayVoiceChat = display.voiceChat
	self.activeDisplayVoiceShown = display.voiceShown
	self.activeDisplayCommentProvided = display.commentProvided
	self.activeDisplayVoiceChatProvided = display.voiceChatProvided
	self.activeDisplayVoiceShownProvided = display.voiceShownProvided
	self.activeDisplayFingerprint = display.fingerprint
	if changed then
		self.revision = (tonumber(self.revision) or 0) + 1
	end
	return changed
end

function Projection:RefreshLeaderFromRoster()
	if type(self.entry) ~= "table" then
		return false
	end
	if not updateEntryLeaderFromRoster(self.entry, self.entry.leader) then
		return false
	end
	self.snapshotFingerprint = snapshotFingerprint(self.resultID, self.entry)
	self.revision = (tonumber(self.revision) or 0) + 1
	return true
end

function Projection:RefreshRosterFromGroup()
	if not self:IsActive() then
		return false
	end
	local changed = updateEntryRosterFromGroup(self.entry)
	changed = updateEntryLeaderFromRoster(
		self.entry, self.entry.leader) or changed
	if changed then
		self.snapshotFingerprint = snapshotFingerprint(self.resultID, self.entry)
		self.revision = (tonumber(self.revision) or 0) + 1
	end
	return changed
end

function Projection:ObserveResultState(resultState, resultIDs)
	if not isPlayerInHomeGroup() then
		self:Clear()
		return false
	end
	resultState = resultState or GF.Result
	for _, resultID in ipairs(resultIDs or {}) do
		local info, entry = cachedInfoForResult(resultState, resultID)
		if info and self:IsCurrentIdentity(resultID, info) then
			return self:Observe(resultID, info, entry, resultState)
		end
	end
	if resultState and resultState.apiResultIDs ~= resultIDs then
		for _, resultID in ipairs(resultState.apiResultIDs or {}) do
			local info, entry = cachedInfoForResult(resultState, resultID)
			if info and self:IsCurrentIdentity(resultID, info) then
				return self:Observe(resultID, info, entry, resultState)
			end
		end
	end
	return false
end

function Projection:MatchesResult(resultID, info)
	resultID = tonumber(resultID)
	if not resultID then
		return false
	end
	local candidateGUID = partyGUIDFromInfo(info)
	if self.partyGUID and candidateGUID then
		return self.partyGUID == candidateGUID
	end
	if infoHasSelf(info) then
		return true
	end
	return self.resultID == resultID
end

function Projection:BuildListElement(resultState, resultIDs)
	-- "Current group" is a projection of a published recruitment, not a generic
	-- HOME-party roster. Once the active entry is removed (or was never posted),
	-- discard the virtual top row and leave any real search result untouched.
	if not hasPublishedRecruitment() then
		self:Clear()
		return nil
	end
	self:ObserveResultState(resultState, resultIDs)
	if not self.entry or self.entry._gfCurrentGroupSource == "active" then
		self:ObserveActiveEntry()
	end
	self:RefreshRosterFromGroup()
	self:RefreshActiveDisplayFields()
	if not self:IsActive() then
		return nil
	end
	local hiddenResultIDs = {}
	for _, resultID in ipairs(resultIDs or {}) do
		local info = cachedInfoForResult(resultState, resultID)
		if self:MatchesResult(resultID, info) then
			hiddenResultIDs[resultID] = true
		end
	end
	return {
		kind = CURRENT_GROUP_ELEMENT_KIND,
		projectionKey = self.projectionKey,
		revision = self.revision,
		resultID = self.resultID,
		entry = self.entry,
		displayName = self.activeDisplayName,
		displayComment = self.activeDisplayComment,
		displayVoiceChat = self.activeDisplayVoiceChat,
		displayVoiceShown = self.activeDisplayVoiceShown,
		displayCommentProvided = self.activeDisplayCommentProvided,
		displayVoiceChatProvided = self.activeDisplayVoiceChatProvided,
		displayVoiceShownProvided = self.activeDisplayVoiceShownProvided,
		categoryID = self.entry.categoryID,
		hiddenResultIDs = hiddenResultIDs,
	}
end

function Projection:GetLiveActionTarget(elementData)
	if not self:IsElement(elementData)
		or elementData.projectionKey ~= self.projectionKey
		or not self:IsActive()
	then
		return nil
	end
	local resultID = tonumber(elementData.resultID or self.resultID)
	local resultState = GF.Result
	if not (resultID and resultState
		and type(resultState.GetIndexForResultID) == "function")
	then
		return nil
	end
	local index = resultState:GetIndexForResultID(resultID)
	if not index or not isLiveAuthoritative(resultState, resultID) then
		return nil
	end
	local api = C_LFGList
	if not (api and type(api.GetSearchResultInfo) == "function") then
		return nil
	end
	if type(api.HasSearchResultInfo) == "function" then
		local presentOK, present = pcall(api.HasSearchResultInfo, resultID)
		if presentOK ~= true or present ~= true then
			return nil
		end
	end
	local infoOK, info = pcall(api.GetSearchResultInfo, resultID)
	if infoOK ~= true then
		return nil
	end
	if not info then
		return nil
	end
	local candidateGUID = partyGUIDFromInfo(info)
	local identityMatches
	if self.partyGUID then
		identityMatches = candidateGUID == self.partyGUID or infoHasSelf(info)
	else
		identityMatches = self:MatchesResult(resultID, info)
	end
	if not identityMatches then
		return nil
	end
	return index, resultID, info
end

function Projection:GetSignature(elementData)
	if not self:IsElement(elementData) then
		return ""
	end
	return table.concat({
		tostring(elementData.projectionKey or ""),
		tostring(elementData.revision or 0),
		tostring(elementData.resultID or 0),
	}, ":")
end
