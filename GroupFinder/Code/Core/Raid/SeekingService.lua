local _, GF = ...
local PUBLISH_INTERVAL = 10
local MEMBER_REFRESH_INTERVAL = 1
local RESTORE_TIMEOUT = 30
local MEMBER_DATA_TIMEOUT = 30
local QUERY_RESPONSE_WINDOW = 15
local QUERY_REPLY_INTERVAL = 20
local PARTY_REPLY_INTERVAL = 3

local P, Transport = GF.RaidSeekingProtocol, GF.RaidSeekingTransport
local Service = {}
Service.__index = Service
local ROLE_BITS = { TANK = 1, HEALER = 2, DAMAGER = 4 }

local function safe(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	if ok and (not GF.Compat or GF.Compat.IsAccessibleValue(value)) then return value end
end

local function isPublicationRejection(reason)
	return reason == "offline_member" or reason == "not_max_level" or reason == "active_recruitment"
end

local function isMemberDataPending(reason)
	return reason == "member_data_pending" or reason == "level_unknown" or reason == "roster"
end

local function readLevel(fn, ...)
	local value = safe(fn, ...)
	if type(value) == "number" then return P.Integer(value, 1, 1000) end
end

local function copySpecChoice(value)
	if type(value) ~= "table" then return nil end
	local classID = P.Integer(value.classID, 1, 30)
	local ids = P.CopySpecIDs(value.specIDs or (value.specID and { value.specID }))
	if classID and ids then return { classID = classID, specIDs = ids, followCurrent = value.followCurrent == true or nil } end
end

local function copyPartySpecs(value)
	local result, count = {}, 0
	for name, choice in pairs(type(value) == "table" and value or {}) do
		local fullName, selected = P.FullName(name), copySpecChoice(choice)
		if fullName and selected and count < 5 then
			result[fullName:lower()] = selected; count = count + 1
		end
	end
	return result
end

local function recordPreferences(record, source)
	local ids, specs = {}, {}
	for _, id in ipairs(record.activityIDs) do ids[#ids + 1] = id end
	for _, member in ipairs(record.members) do
		local choice = source and (record.mode == "solo" and source.soloSpecs
			or record.mode == "party" and source.partySpecs and source.partySpecs[member.name:lower()])
		specs[member.name:lower()] = { classID = member.classID, specIDs = P.CopySpecIDs(P.GetSpecIDs(member)),
			followCurrent = source and (not choice or choice.classID ~= member.classID or choice.followCurrent == true) or nil }
	end
	return { mode = record.mode, activityIDs = ids, roles = record.members[1].roles, note = record.note,
		soloSpecs = record.mode == "solo" and specs[record.members[1].name:lower()] or nil,
		partySpecs = record.mode == "party" and specs or {} }
end

local function sameMemberSpecs(left, right)
	if #left.members ~= #right.members then return false end
	local byName = {}
	for _, member in ipairs(right.members) do byName[member.name:lower()] = member end
	for _, member in ipairs(left.members) do
		local other = byName[member.name:lower()]
		if not other or member.classID ~= other.classID
			or table.concat(P.GetSpecIDs(member), ",") ~= table.concat(P.GetSpecIDs(other), ",") then return false end
	end
	return true
end

-- Preferences can cross a UI reload; roster, delivery state and timers cannot.
local function copyPreferences(value)
	if type(value) ~= "table" or (value.mode ~= "solo" and value.mode ~= "party")
		or not P.Integer(value.roles, value.mode == "party" and 0 or 1, 7) or type(value.activityIDs) ~= "table" then return nil end
	local note = P.Text(value.note)
	if not note or #note > P.MAX_NOTE_BYTES or note:find("[%c|]") then return nil end
	local ids, seen, count = {}, {}, 0
	for index, id in pairs(value.activityIDs) do
		if type(index) ~= "number" or not P.Integer(index, 1, 24) then return nil end
		id = P.Integer(id, 1, 10000000)
		if not id or seen[id] then return nil end
		ids[index], seen[id], count = id, true, count + 1
	end
	if count == 0 or count > 24 or #ids ~= count then return nil end
	return { mode = value.mode, roles = value.roles, note = note, activityIDs = ids, soloSpecs = copySpecChoice(value.soloSpecs), partySpecs = copyPartySpecs(value.partySpecs) }
end

local Native = {}
Service.Native = Native
function Native.MaxLevel()
	-- Seasonal raids use the latest expansion, not the account's expansion cap.
	return readLevel(GetMaxLevelForLatestExpansion)
end
function Native.Level(unit)
	return readLevel(UnitLevel, unit)
end
function Native.ActivitySet()
	local set = {}
	for id in pairs(GF.LFGWorkspacePolicy:GetSeasonRaidActivitySet()) do
		local info = safe(C_LFGList and C_LFGList.GetActivityInfoTable, id)
		if type(info) == "table" and (P.Text(info.fullName) or P.Text(info.shortName)) then set[id] = true end
	end
	return set
end
function Native.Activities()
	local set = GF.LFGWorkspacePolicy:GetSeasonRaidActivitySet()
	local out, byMap, byGroup, groupNames = {}, {}, {}, {}
	-- Reuse the season catalog's stable instance identity and journal artwork.
	-- No name parsing or external addon database participates in grouping.
	local instances = GF.NavCatalog and GF.NavCatalog.GetSeasonInstances and GF.NavCatalog.GetSeasonInstances("raid") or {}
	for _, instance in ipairs(instances) do
		if instance.mapID then byMap[instance.mapID] = instance end
		if instance.instanceMapID then byMap[instance.instanceMapID] = instance end
		if instance.groupID then byGroup[instance.groupID] = instance end
	end
	for id in pairs(set) do
		local info = safe(C_LFGList and C_LFGList.GetActivityInfoTable, id)
		if type(info) == "table" then
			local name = P.Text(info.fullName) or P.Text(info.shortName)
			if name then
				local mapID = P.Integer(info.mapID, 1, 1000000)
				local groupID = P.Integer(info.groupFinderActivityGroupID, 1, 1000000)
				if groupID and groupNames[groupID] == nil then
					local groupName = P.Text(safe(C_LFGList and C_LFGList.GetActivityGroupInfo, groupID))
					groupNames[groupID] = groupName and groupName ~= "" and groupName or false
				end
				local instance = byMap[mapID] or byGroup[groupID]
				local journalID = instance and instance.journalInstanceID
				local difficultyID = P.Integer(info.difficultyID, 1, 1000)
				local difficultyName = difficultyID and P.Text(safe(GetDifficultyInfo, difficultyID))
				if not difficultyName or difficultyName == "" then difficultyName = P.Text(info.shortName) end
				if difficultyName == "" then difficultyName = nil end
				out[#out + 1] = {
					id = id, name = name,
					instanceKey = journalID and ("journal:" .. journalID) or mapID and ("map:" .. mapID)
						or groupID and ("group:" .. groupID) or ("activity:" .. id),
					instanceName = instance and instance.label or name,
					activityGroupName = groupNames[groupID] or nil,
					texture = instance and instance.visualTexture,
					texCoords = instance and instance.visualTexCoords,
					difficultyID = difficultyID,
					difficultyName = difficultyName,
				}
			end
		end
	end
	table.sort(out, function(a, b)
		if a.instanceName ~= b.instanceName then return a.instanceName < b.instanceName end
		if a.instanceKey ~= b.instanceKey then return a.instanceKey < b.instanceKey end
		-- Keep each raid together, with normal / heroic / mythic in difficulty ID order.
		local aDifficulty, bDifficulty = a.difficultyID or 10000, b.difficultyID or 10000
		if aDifficulty ~= bDifficulty then return aDifficulty < bDifficulty end
		if a.name ~= b.name then return a.name < b.name end
		return a.id < b.id
	end)
	return out
end
local nativeActivitySet, nativeActivities = Native.ActivitySet, Native.Activities
function Native.Group()
	local raid = safe(IsInRaid, LE_PARTY_CATEGORY_HOME)
	local home = safe(IsInGroup, LE_PARTY_CATEGORY_HOME)
	local instance = safe(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
	local count = P.Integer(safe(GetNumSubgroupMembers, LE_PARTY_CATEGORY_HOME), 0, 4)
	return { raid = raid == true, grouped = home == true, instance = instance == true,
		leader = safe(UnitIsGroupLeader, "player", LE_PARTY_CATEGORY_HOME) == true, count = count }
end
local nativeGroup = Native.Group
function Native.GroupMode()
	local raid = safe(IsInRaid, LE_PARTY_CATEGORY_HOME)
	local home = safe(IsInGroup, LE_PARTY_CATEGORY_HOME)
	local instance = safe(IsInGroup, LE_PARTY_CATEGORY_INSTANCE)
	return (raid == true or home == true or instance == true) and "party" or "solo"
end
function Native.PartyLeaderName()
	local group = Native.Group()
	if not group.grouped or group.raid or group.instance or group.leader then return nil end
	for index = 1, group.count or 0 do
		local unit = "party" .. index
		if safe(UnitIsGroupLeader, unit, LE_PARTY_CATEGORY_HOME) == true then
			local ok, name, realm = pcall(UnitFullName, unit)
			name, realm = P.Text(name), P.Text(realm)
			if not ok or not name then return nil end
			if not realm or realm == "" then realm = P.Text(safe(GetNormalizedRealmName)) end
			return realm and P.FullName(name .. "-" .. realm) or nil
		end
	end
end
function Native.HasOfflineMember()
	local value = safe(GroupHasOfflineMember, LE_PARTY_CATEGORY_HOME)
	if type(value) == "boolean" then return value end
end

local INSPECT_INTERVAL, INSPECT_TIMEOUT, INSPECT_RETRY = 3, 5, 15
local INSPECT_REFRESH, INSPECT_CACHE_TTL = 60, 120
local partyInspection = { members = {}, nextRequest = 0 }
local function reportedItemLevel(guid)
	local sync = GF.RaidSeekingService and GF.RaidSeekingService.partySync
	return sync and sync.GetItemLevel and sync:GetItemLevel(guid)
end
function Native.EquippedItemLevel()
	if type(GetAverageItemLevel) ~= "function" then return nil end
	local ok, _, equipped = pcall(GetAverageItemLevel)
	if ok and (not GF.Compat or GF.Compat.IsAccessibleValue(equipped)) and type(equipped) == "number"
		and equipped == equipped and equipped >= 1 and equipped <= 10000 then
		return math.floor(equipped)
	end
end
local function inspectedItemLevel(unit)
	local value = safe(C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel, unit)
	if type(value) ~= "number" or value ~= value or value < 1 or value > 10000 then return 0 end
	return math.floor(value)
end
function Native.ResetPartyInspection()
	partyInspection = { members = {}, nextRequest = 0 }
end
function Native.PartyItemLevel(unit)
	local guid = P.Text(safe(UnitGUID, unit))
	if not guid then return 0 end
	local reported = reportedItemLevel(guid)
	if reported then return reported end
	local value = inspectedItemLevel(unit)
	if value > 0 then return value end
	local cached = partyInspection.members[guid]
	local now = safe(GetTime)
	if cached and cached.at and type(now) == "number" and now - cached.at < INSPECT_CACHE_TTL then
		return cached.itemLevel
	end
	return 0
end
local function partyInspectionRoster()
	local group = Native.Group()
	if not group.grouped or not group.leader or group.raid or group.instance then return {} end
	local roster = {}
	for index = 1, group.count or 0 do
		local unit = "party" .. index
		local guid = P.Text(safe(UnitGUID, unit))
		if guid then roster[#roster + 1] = { unit = unit, guid = guid } end
	end
	return roster
end
function Native.InspectReady(guid)
	guid = P.Text(guid)
	if not guid or not partyInspection.active then return false end
	for _, member in ipairs(partyInspectionRoster()) do
		if member.guid == guid then
			local pending = partyInspection.pending
			if pending and pending.guid == guid then partyInspection.pending = nil end
			local value, now = inspectedItemLevel(member.unit), safe(GetTime)
			if value == 0 or type(now) ~= "number" then return false end
			local previous = partyInspection.members[guid]
			partyInspection.members[guid] = { itemLevel = value, at = now, nextAttempt = now + INSPECT_REFRESH }
			-- An inspect started before the self report may complete later. Keep
			-- it as fallback without republishing an unchanged effective value.
			return not reportedItemLevel(guid) and (not previous or previous.itemLevel ~= value)
		end
	end
	return false
end
function Native.RefreshPartyInspection(now, enabled)
	if not enabled then
		if partyInspection.active then Native.ResetPartyInspection() end
		return false
	end
	partyInspection.active = true
	local roster, present, changed = partyInspectionRoster(), {}, false
	for _, member in ipairs(roster) do
		local guid, unit = member.guid, member.unit
		present[guid] = true
		local entry = partyInspection.members[guid] or { itemLevel = 0, nextAttempt = 0 }
		partyInspection.members[guid] = entry
		local reported = reportedItemLevel(guid)
		local value = not reported and inspectedItemLevel(unit) or 0
		if not reported and value > 0 then
			if entry.itemLevel ~= value then
				entry.itemLevel, entry.at, entry.nextAttempt = value, now, now + INSPECT_REFRESH
				changed = true
			end
		elseif not reported and entry.at and now - entry.at >= INSPECT_CACHE_TTL then
			entry.itemLevel, entry.at, changed = 0, nil, true
		end
	end
	for guid in pairs(partyInspection.members) do
		if not present[guid] then partyInspection.members[guid] = nil end
	end
	local pending = partyInspection.pending
	if pending and (not present[pending.guid] or now - pending.at >= INSPECT_TIMEOUT) then
		partyInspection.pending = nil
	end
	-- Cooperate with the native equipment/talent inspector. Never clear its
	-- shared inspect result, replace its unit, or open an inspection window.
	if partyInspection.pending or now < partyInspection.nextRequest or type(NotifyInspect) ~= "function"
		or safe(InCombatLockdown) ~= false
		or (InspectFrame and (InspectFrame.unit or safe(InspectFrame.IsShown, InspectFrame)))
		or (PlayerSpellsFrame and safe(PlayerSpellsFrame.IsInspecting, PlayerSpellsFrame)) then return changed end
	for offset = 1, #roster do
		local index = ((partyInspection.cursor or 0) + offset - 1) % #roster + 1
		local member = roster[index]
		local entry = partyInspection.members[member.guid]
		if not reportedItemLevel(member.guid) and now >= entry.nextAttempt and safe(CanInspect, member.unit) == true then
			local request = { guid = member.guid, at = now }
			partyInspection.pending, partyInspection.nextRequest = request, now + INSPECT_INTERVAL
			partyInspection.cursor = index
			entry.nextAttempt = now + INSPECT_RETRY
			local ok = pcall(NotifyInspect, member.unit)
			if not ok and partyInspection.pending == request then partyInspection.pending = nil end
			break
		end
	end
	return changed
end
function Native.Member(unit)
	local ok, name, realm = pcall(UnitFullName, unit)
	name, realm = P.Text(name), P.Text(realm)
	if not ok or not name then return nil end
	if not realm or realm == "" then realm = P.Text(safe(GetNormalizedRealmName)) end
	name = realm and P.FullName(name .. "-" .. realm)
	local classOK, _, _, classID = pcall(UnitClass, unit)
	classID = classOK and P.Integer(classID, 1, 30)
	local level = P.Integer(safe(UnitLevel, unit), 1, 1000)
	if not name or not classID or not level then return nil end
	local role = P.Text(safe(UnitGroupRolesAssigned, unit))
	local member = { name = name, classID = classID, level = level,
		roles = ROLE_BITS[role] or 0, specID = 0, itemLevel = 0,
		faction = P.Text(safe(UnitFactionGroup, unit)) or "?" }
	if unit == "player" then
		local spec = GF.SpecializationInfo.GetCurrentSnapshot()
		member.specID = P.Integer(spec.specID, 1, 10000) or 0
		member.roles = ROLE_BITS[spec.specRole] or member.roles
		member.itemLevel = Native.EquippedItemLevel() or 0
	else
		member.itemLevel = Native.PartyItemLevel(unit)
		-- Specialization still comes from the existing current-group snapshot.
		local snapshots = GF.MythicPlusGroupSnapshotService
		local current = snapshots and snapshots:GetCurrentCharacterForMember(name)
		if current and current.classID == classID then member.specID = P.Integer(current.specID, 1, 10000) or 0 end
	end
	return member
end
function Native.Blocked(name)
	return GF.Blocklist and GF.Blocklist:FindPlayerMatch(name) ~= nil or false
end
function Native.CanInvite()
	return Native.HasInvitePermission() == true
		and safe(InCombatLockdown) == false
end
function Native.HasInvitePermission()
	local allowed = safe(C_PartyInfo and C_PartyInfo.CanInvite)
	if allowed == true or allowed == false then return allowed end
end
function Native.HasRecruitment()
	return GF.RecruitmentSession and GF.RecruitmentSession.HasActive and GF.RecruitmentSession:HasActive() == true or false
end
function Native.ReadRecruitmentState()
	local session = GF.RecruitmentSession
	local active = session and safe(session.ReadActiveState, session)
	if active == true or active == false then return active end
end
function Native.ActiveActivity()
	return GF.RecruitmentSession and GF.RecruitmentSession:GetActiveActivityID()
end
function Native.AllowedRoles(classID)
	for _, class in ipairs(GF.RaidRecruitmentNeeds:GetCatalog()) do
		if class.classID == classID then
			local mask = 0
			for _, spec in ipairs(class.specs) do
				local bit = ROLE_BITS[spec.role]
				if bit and not P.HasRole(mask, bit) then mask = mask + bit end
			end
			return mask
		end
	end
	return 0
end
function Native.Specs(classID)
	for _, class in ipairs(GF.RaidRecruitmentNeeds:GetCatalog()) do
		if class.classID == classID then return class.specs end
	end
	return {}
end
function Native.RequestProgress() safe(RequestRaidInfo) end
function Native.EncounterCatalog(activityID)
	local info = safe(C_LFGList and C_LFGList.GetActivityInfoTable, activityID)
	local mapID = info and P.Integer(GF.Compat.ReadAccessibleField(info, "mapID"), 1, 1000000)
	local difficulty = info and P.Integer(GF.Compat.ReadAccessibleField(info, "difficultyID"), 1, 1000)
	local gateway = GF.InstanceGatewayService
	if mapID and difficulty and gateway then
		return safe(gateway.GetEncounterCatalog, gateway, mapID, difficulty)
	end
end

local function readBossProgress(activityID, difficulty, done, total)
	local catalog = Native.EncounterCatalog(activityID)
	if not catalog or #catalog ~= total then return nil end
	local bosses = {}
	for _, encounter in ipairs(catalog) do
		local defeated = safe(C_RaidLocks and C_RaidLocks.IsEncounterComplete,
			encounter.mapID, encounter.dungeonEncounterID, difficulty)
		if type(defeated) ~= "boolean" then return nil end
		bosses[#bosses + 1] = { id = encounter.dungeonEncounterID, defeated = defeated }
	end
	-- Do not publish a partial or stale encounter list as confirmed boss states.
	return P.BossData({ done = done, total = total, bosses = bosses }) and bosses or nil
end

function Native.Progress(activityIDs, ready)
	local result, pending = {}, false
	if #activityIDs == 0 then return result end
	if not ready then return result, true end
	local count = P.Integer(safe(GetNumSavedInstances), 0, 300)
	if not count then return result, true end
	local lockouts, complete = {}, true
	for index = 1, count do
		local ok, _, _, reset, diff, locked, extended, _, raid, _, _, total, done, _, instanceID = pcall(GetSavedInstanceInfo, index)
		if not ok or not GF.Compat.IsAccessibleValue(raid) or type(raid) ~= "boolean" then
			complete = false
		elseif raid then
			instanceID, diff = P.Integer(instanceID, 1, 1000000), P.Integer(diff, 1, 1000)
			if not instanceID or not diff then
				complete = false
			else
				local key = instanceID .. ":" .. diff
				local readable = GF.Compat.IsAccessibleValue(locked) and type(locked) == "boolean"
					and GF.Compat.IsAccessibleValue(extended) and type(extended) == "boolean"
				reset = P.Integer(reset, 0, 100000000)
				readable = readable and (extended or not locked or reset ~= nil)
				local active = readable and (extended or (locked and reset > 0))
				if active or not readable then
					done, total = P.Integer(done, 0, 50), P.Integer(total, 1, 50)
					if active and done and total and done <= total then
						lockouts[key] = { done = done, total = total }
					elseif not lockouts[key] then
						-- A matching unreadable save cannot prove zero kills.
						lockouts[key] = {}
					end
				end
			end
		end
	end
	for _, id in ipairs(activityIDs) do
		local info = safe(C_LFGList and C_LFGList.GetActivityInfoTable, id)
		local mapID = info and P.Integer(GF.Compat.ReadAccessibleField(info, "mapID"), 1, 1000000)
		local difficulty = info and P.Integer(GF.Compat.ReadAccessibleField(info, "difficultyID"), 1, 1000)
		if mapID and difficulty then
			local saved = lockouts[mapID .. ":" .. difficulty]
			local done, total = saved and saved.done, saved and saved.total
			if not saved and complete then
				local gateway = GF.InstanceGatewayService
				total = gateway and P.Integer(safe(gateway.GetEncounterCount, gateway, mapID, difficulty), 1, 50)
				if total then done = 0 end
			end
			if done and total then
				local bosses = readBossProgress(id, difficulty, done, total)
				result[#result + 1] = { activityID = id, done = done, total = total, bosses = bosses }
				if not bosses then pending = true end
			else
				pending = true
			end
		else
			pending = true
		end
	end
	return result, pending
end
function Native.Invite(name)
	if not Native.CanInvite() then return false end
	return pcall(C_PartyInfo.InviteUnit, name)
end

-- These are explicit character actions, independent of the board's verified
-- recruitment/contact handshake. Only a menu click may dispatch them.
function Native.GetMemberInviteType()
	-- The name-only native menu has no GUID. Blizzard selects direct invitations
	-- for leaders/assistants and suggestions for ordinary group members.
	local kind = safe(GetDisplayedInviteType)
	if kind == "INVITE" or kind == "SUGGEST_INVITE" then return kind end
end

function Native.CanMemberAction(action, name)
	name = P.FullName(name)
	if not name then return false, "expired" end
	-- Opening an empty native whisper editor is not a party/friend action.
	if (action ~= "whisper" and safe(InCombatLockdown) ~= false)
		or GF.RaidSeekingTransport.Native.Locked() then
		return false, "restricted"
	end
	if action == "invite" or action == "suggest_invite" then
		local kind = Native.GetMemberInviteType()
		local allowed = action == "invite" and kind == "INVITE" and Native.CanInvite()
			or action == "suggest_invite" and kind == "SUGGEST_INVITE"
				and safe(C_PartyInfo and C_PartyInfo.IsPartyFull) == false
		return allowed == true and type(C_PartyInfo and C_PartyInfo.InviteUnit) == "function", "cannot_invite"
	elseif action == "whisper" then
		return type(ChatFrameUtil and ChatFrameUtil.SendTell) == "function", "unavailable"
	elseif action == "friend" then
		if type(C_FriendList and C_FriendList.AddFriend) ~= "function"
			or safe(C_FriendList.IsLegacyFriendSystemEnabled) ~= true then return false, "unavailable" end
		local character, realm = name:match("^([^-]+)%-(.+)$")
		local currentRealm = P.Text(safe(GetNormalizedRealmName))
		if not currentRealm or realm:lower() ~= currentRealm:gsub("%s", ""):lower() then
			return false, "unavailable"
		end
		return not safe(C_FriendList.GetFriendInfo, character), "unavailable"
	end
	return false, "unavailable"
end

function Native.PerformMemberAction(action, name)
	local allowed, reason = Native.CanMemberAction(action, name)
	if not allowed then return false, reason end
	local ok
	if action == "invite" or action == "suggest_invite" then ok = pcall(C_PartyInfo.InviteUnit, name)
	elseif action == "whisper" then ok = pcall(ChatFrameUtil.SendTell, name)
	elseif action == "friend" then ok = pcall(C_FriendList.AddFriend, name) end
	-- A successful call is a submitted request, not server acceptance.
	return ok == true, "unavailable"
end

function Native.DraftStore()
	local db = GF.GetDB()
	db.raidSeekingDrafts = type(db.raidSeekingDrafts) == "table" and db.raidSeekingDrafts or {}
	return db.raidSeekingDrafts
end
function Native.ReloadStore()
	local db = GF.GetDB()
	db.raidSeekingReload = type(db.raidSeekingReload) == "table" and db.raidSeekingReload or {}
	return db.raidSeekingReload
end
function Native.ChatStore()
	local db = GF.GetDB()
	db.raidSeekingChats = type(db.raidSeekingChats) == "table" and db.raidSeekingChats or {}
	return db.raidSeekingChats
end
function Native.Epoch() return P.Integer(safe(GetServerTime), 1, 100000000000) end
function Native.CatalogReady()
	if not (GF.NavCatalog and GF.NavCatalog.GetSeasonInstances) then return false end
	local _, state = GF.NavCatalog.GetSeasonInstances("raid")
	return state == "ready"
end

function Service.New(transport, adapter)
	local self = setmetatable({ transport = transport or Transport.New(), adapter = adapter or Native,
		records = {}, owners = {}, peers = {}, invitations = {}, listeners = {}, revision = 0,
		status = "draft", draft = { mode = "solo", activityIDs = {}, roles = 0, note = "" } }, Service)
	self.transport.onMessage = function(...) self:OnMessage(...) end
	self.transport.onTick = function(now) self:Tick(now) end
	self.transport.onSent = function(key)
		if key == "query" and self.queryQueued then
			self.queryQueued = nil
			self.lastQuery, self.queryUntil = self:Now(), self:Now() + self.queryWindow
			self:Notify()
		end
	end
	self.transport.onBeforeFlush = function(key) return self:CheckPublicationConnection(key) end
	self.transport.onRosterChanged = function(event, ...)
		if event == "INSPECT_READY" then
			if self.adapter.InspectReady and self.adapter.InspectReady(...) then self:OnItemLevelChanged() end
			return
		end
		if event == "PLAYER_SPECIALIZATION_CHANGED" then
			-- Teammate specs arrive through the authoritative snapshot listener.
			if (...) == "player" then self:RequestGroupSnapshotRefresh() end
			return
		end
		if event == "UPDATE_INSTANCE_INFO" then self.raidInfoReady = true end
		if event == "GROUP_ROSTER_UPDATE" then self.partyFormDirty = true end
		self.rosterDirty = true
	end
	self.transport.onChanged = function(event, kind)
		if self.transport.state == "error" or self.transport.state == "disconnected" then
			if self.transport.state == "error" and not self.loggingOut and not self.reconnecting then self:CaptureChatRecovery() end
			if self.adapter.ResetPartyInspection then self.adapter.ResetPartyInspection() end
			local restoring = self.restoring
			self.restoring, self.restoreStartedAt, self.restorePreferences, self.restoreSavedAt = nil, nil, nil, nil
			if restoring and not self.loggingOut then
				self.recoveryNotice, self.restoreFailureReason = "restore_failed", self.transport.reason
			end
			if self.current or self.pendingRequest then self.current = nil; self.status = "paused" end
			self.pendingRequest, self.pendingQuery, self.pendingAt = nil, nil, nil
			self.memberDataWaitAt, self.memberDataRetryAt = nil, nil
			self.pendingPublicationKind = nil
			self.publicationGeneration = nil
			self.bossBroadcast = nil
			self.queryUntil, self.queryQueued = nil, nil
			self.records, self.owners, self.peers, self.invitations = {}, {}, {}, {}
			self.lastError = self.transport.state == "error" and self.transport.reason or nil
		end
		self:Notify(event, kind)
	end
	local snapshots = GF.MythicPlusGroupSnapshotService
	if snapshots and snapshots.AddListener then
		snapshots:AddListener(function() self:RequestGroupSnapshotRefresh() end)
	end
	if GF.RaidSeekingPartySync then self.partySync = GF.RaidSeekingPartySync.New(self) end
	return self
end
GF.RaidSeekingService = Service.New()
GF.RaidSeekingService.New = Service.New
GF.RaidSeekingService.Native = Native

function Service:Now() return self.transport.adapter.Now() end
function Service:AddListener(callback) self.listeners[#self.listeners + 1] = callback end
function Service:Notify(event, action)
	for _, callback in ipairs(self.listeners) do callback(event, action) end
end
function Service:OnItemLevelChanged()
	self.rosterDirty, self.itemLevelDirty = true, true
end
function Service:GetMetadataRefreshInterval()
	-- Member changes only accelerate metadata rebuilt from publishedDraft. Explicit
	-- publication/edits retain the existing cooldown and public echo gate.
	return (self.itemLevelDirty or self.specDirty) and MEMBER_REFRESH_INTERVAL or PUBLISH_INTERVAL
end
function Service:RefreshPublicationSpecs()
	if not self.current or not self.publishedDraft then return end
	local members = self.current.mode == "party" and self:GetPartyMembers()
		or { self.adapter.Member and self.adapter.Member("player") }
	local byName = {}
	for _, member in ipairs(members) do byName[member.name:lower()] = member end
	for _, old in ipairs(self.current.members) do
		local member = byName[old.name:lower()]
		local projected = member and self:ApplyIntendedSpecs(member, self.publishedDraft)
		if projected and member.classID == old.classID
			and not sameMemberSpecs({ members = { projected } }, { members = { old } }) then
			self.specDirty = true; return
		end
	end
end
local function refreshRequestedGroupSnapshot(service)
	service:OnGroupSnapshotChanged()
end

function Service:RequestGroupSnapshotRefresh()
	if GF.EventCoalescer then
		return GF.EventCoalescer:Request(self, "specSnapshotSchedule", 0.2,
			refreshRequestedGroupSnapshot)
	end
	return self:OnGroupSnapshotChanged()
end

function Service:OnGroupSnapshotChanged()
	-- GFMP2 owns freshness and group membership. Observe only the current roster's
	-- spec projection, so keys, ratings, alternate characters and renewals stay quiet.
	local members = self:GetPartyMembers()
	if #members == 0 then
		local group = self.adapter.Group()
		local player = not group.grouped and self.adapter.Member and self.adapter.Member("player")
		if player then members[1] = player end
	end
	local parts = {}
	for _, member in ipairs(members) do
		parts[#parts + 1] = member.name:lower() .. ":" .. member.classID .. ":" .. (member.specID or 0)
	end
	table.sort(parts)
	local signature = table.concat(parts, ";")
	if signature == self.specSnapshotSignature then return end
	self.specSnapshotSignature = signature
	self:RefreshPublicationSpecs()
	self:Notify("member_specs")
end
function Service:Context() return self.transport.context or self.transport.adapter.Context() end
function Service:GetActivities() return self.adapter.Activities() end
local defaultGetActivities = Service.GetActivities
function Service:HasRecruitment()
	if self.adapter.HasRecruitment then return self.adapter.HasRecruitment() == true end
	return self.adapter.ActiveActivity and self.adapter.ActiveActivity() ~= nil or false
end
function Service:ReadRecruitmentState()
	if self.adapter.ReadRecruitmentState then return self.adapter.ReadRecruitmentState() end
	return self:HasRecruitment()
end
function Service:GetSeekingNavigationState()
	local recruiting = self:HasRecruitment()
	local group = self.adapter.Group()
	-- Only confirmed recruitment or raid membership retires the seeking task.
	-- Form validation, combat, connection state and pending invites do not.
	return not recruiting and group.raid ~= true, recruiting
end
function Service:CanContact(record, chatOnly)
	if not record then return false, "expired" end
	if self:IsOwn(record) then return false, "own_post" end
	if self.transport.adapter.Locked() then return false, "locked" end
	if not self:HasRecruitment() then return false, "chat_recruitment" end
	-- Conversation permission follows the recruiter's identity. Temporary
	-- combat restrictions still apply to invitations, not ordinary whispers.
	local permission = chatOnly and self.adapter.HasInvitePermission or self.adapter.CanInvite
	if permission() ~= true then return false, "cannot_invite" end
	local activity = self.adapter.ActiveActivity and self.adapter.ActiveActivity()
	if not activity or not self:ActivitySet()[activity] then return false, "chat_recruitment" end
	for _, id in ipairs(record.activityIDs) do if activity == id then return true end end
	return false, "chat_mismatch"
end
function Service:OnRecruitmentChanged(hasActive, createdNew)
	if self:ReadRecruitmentState() == nil then self:Notify(); return end
	if createdNew == true and self.chat and not self.chat.historyLoaded then self.recruitmentChangedBeforeHistory = true end
	if hasActive and (not self.recruitmentActive or createdNew == true) then
		self.recruitmentGeneration = (self.recruitmentGeneration or 0) + 1
	end
	self.recruitmentActive = hasActive == true
	if hasActive then
		-- This is native confirmed state, never an attempted CreateListing click.
		if self.current or self.pendingRequest or self.pendingAt or self.restoring then
			self:PausePublication("active_recruitment")
		else self:ClearReload() end
	end
	self:Notify()
end
function Service:GetPartyOfflineReason()
	if not self.adapter.HasOfflineMember then return nil end
	local offline = self.adapter.HasOfflineMember()
	if offline == true then return "offline_member" end
	if offline ~= false then return "roster" end
end
function Service:GetPublicationLevelReason(mode, group)
	local maxLevel = readLevel(self.adapter.MaxLevel)
	if not maxLevel then return "level_unknown" end
	local count = 0
	if mode == "party" then
		group = group or self.adapter.Group()
		count = P.Integer(group.count, 1, 4)
		if not count then return "roster" end
	end
	local unknown = false
	for index = 0, count do
		local level = readLevel(self.adapter.Level, index == 0 and "player" or "party" .. index)
		if not level then unknown = true
		elseif level < maxLevel then return "not_max_level" end
	end
	if unknown then return "level_unknown" end
end
function Service:GetPublicationEligibilityReason(mode, group)
	if self:ReadRecruitmentState() == nil then return "roster" end
	if self:HasRecruitment() then return "active_recruitment" end
	if mode == "party" then
		local reason = self:GetPartyOfflineReason()
		if reason then return reason end
	end
	return self:GetPublicationLevelReason(mode, group)
end
function Service:CheckPublicationConnection(key)
	local request = self.pendingRequest and self.pendingRequest.preferences
	local publication = self.current or request
	if not publication then return true end
	local reason = self:GetPublicationEligibilityReason(publication.mode)
	-- Waiting holds roster publication only; discovery and replies can still
	-- drain normally instead of expiring behind a held publication packet.
	local waiting = self.memberDataWaitAt ~= nil
	if waiting and key and key ~= "publication" and key ~= "heartbeat" and key ~= "boss-progress"
		and (not reason or isMemberDataPending(reason)) then return true end
	if not reason then return not waiting end
	-- Unknown data holds outgoing packets until eligibility can be checked.
	if not isPublicationRejection(reason) then return false end
	self:PausePublication(reason)
	return false
end
function Service:PausePublication(reason)
	local restoring = self.restoring
	self:Stop(reason == "active_recruitment" and "chat_role_changed" or "chat_seeking_stopped")
	self.status, self.lastError = "paused", reason
	if restoring then self.recoveryNotice, self.restoreFailureReason = reason, reason end
	self:Notify("publication_blocked", reason)
end
function Service:WaitForMemberData(now)
	if not self.memberDataWaitAt then
		self.memberDataWaitAt = now
		-- Old roster packets must not renew the last confirmed listing while
		-- a replacement member is still missing. Keep its visible snapshot.
		self.transport:CancelQueued("publication")
		self.transport:CancelQueued("heartbeat")
		self.transport:CancelQueued("boss-progress")
		self.bossBroadcast = nil
	end
	self.memberDataRetryAt = now + 1
end
function Service:GroupActivities(activityIDs, activities)
	local catalog, groups, byKey, seen = {}, {}, {}, {}
	for _, activity in ipairs(activities or self:GetActivities()) do catalog[activity.id] = activity end
	for _, id in ipairs(activityIDs or {}) do
		if not seen[id] then
			seen[id] = true
			local activity = catalog[id] or { id = id, name = "#" .. id }
			local key = activity.instanceKey or ("activity:" .. id)
			local group = byKey[key]
			if not group then
				group = { key = key, name = activity.instanceName or activity.name,
					texture = activity.texture, texCoords = activity.texCoords,
					activityIDs = {}, difficulties = {}, seenDifficulties = {} }
				groups[#groups + 1], byKey[key] = group, group
			end
			group.activityGroupName = group.activityGroupName or activity.activityGroupName
			group.activityIDs[#group.activityIDs + 1] = id
			local difficultyKey = activity.difficultyID or ("activity:" .. id)
			if not group.seenDifficulties[difficultyKey] then
				group.seenDifficulties[difficultyKey] = true
				group.difficulties[#group.difficulties + 1] = { id = activity.difficultyID, name = activity.difficultyName,
					activityID = id, activityName = activity.name }
			end
		end
	end
	for _, group in ipairs(groups) do
		table.sort(group.difficulties, function(a, b) return (a.id or 10000) < (b.id or 10000) end)
		group.seenDifficulties = nil
	end
	return groups
end
function Service:GroupProgress(progress, activities)
	local ids, byActivity = {}, {}
	for _, entry in ipairs(progress or {}) do
		if not byActivity[entry.activityID] then
			ids[#ids + 1], byActivity[entry.activityID] = entry.activityID, entry
		end
	end
	local groups = self:GroupActivities(ids, activities)
	local order = { [17] = 1, [14] = 2, [15] = 3, [16] = 4 }
	for _, group in ipairs(groups) do
		for _, difficulty in ipairs(group.difficulties) do
			local entry = byActivity[difficulty.activityID]
			difficulty.done, difficulty.total = entry.done, entry.total
			difficulty.bosses = entry.bosses
		end
		table.sort(group.difficulties, function(a, b)
			local left, right = order[a.id] or 1000 + (a.id or 0), order[b.id] or 1000 + (b.id or 0)
			if left ~= right then return left < right end
			return a.activityID < b.activityID
		end)
	end
	return groups
end

function Service:GroupRequestedProgress(activityIDs, progress, activities)
	local byActivity, requested = {}, {}
	for _, entry in ipairs(progress or {}) do
		if not byActivity[entry.activityID] then byActivity[entry.activityID] = entry end
	end
	for _, id in ipairs(activityIDs or {}) do
		-- Keep every requested difficulty visible even when its progress is unknown.
		requested[#requested + 1] = byActivity[id] or { activityID = id }
	end
	return self:GroupProgress(requested, activities)
end

function Service:ProgressBosses(activityID, progress)
	local catalog = self.adapter.EncounterCatalog and self.adapter.EncounterCatalog(activityID)
	local states, result = {}, {}
	for _, boss in ipairs(progress.bosses or {}) do states[boss.id] = boss.defeated end
	for _, encounter in ipairs(catalog or {}) do
		result[#result + 1] = { name = encounter.name, defeated = states[encounter.dungeonEncounterID] }
	end
	return result
end

function Service:BuildMemberTooltipData(member, activityInfo)
	if not member then return nil end
	local data = {
		name = member.name, displayName = P.Display(member.name),
		level = member.level, ilvl = member.itemLevel, specID = member.specID,
		activityInfo = activityInfo, tooltipKind = "raidSeeking",
	}
	for _, class in ipairs(GF.RaidRecruitmentNeeds:GetCatalog()) do
		if class.classID == member.classID then
			data.class, data.localizedClass = class.classFile, class.name
			local names = {}
			for _, spec in ipairs(class.specs) do
				if P.HasSpec(member, spec.id) then names[#names + 1] = spec.name end
				if not member.specIDs and spec.id == member.specID then data.specName = spec.name end
			end
			if #names > 0 then data.intendedSpecNames = table.concat(names, "/") end
			break
		end
	end
	for id, faction in pairs(PLAYER_FACTION_GROUP or {}) do
		if faction == member.faction then data.factionGroup = id; break end
	end
	-- Seeking records have no native applicant ID or social relationship.
	-- Provider progress is prepared by the same name/realm cache as applicants.
	return data
end

function Service:ActivitySet()
	-- Existing activity-source overrides remain authoritative for membership.
	local activitySet = self.adapter.ActivitySet
	if self.GetActivities == defaultGetActivities and type(activitySet) == "function"
		and (activitySet ~= nativeActivitySet or self.adapter.Activities == nativeActivities) then return activitySet() end
	local set = {}
	for _, option in ipairs(self:GetActivities()) do set[option.id] = true end
	return set
end
function Service:SyncDraftMode(group)
	-- Type describes the live roster, never a saved or manually chosen preference.
	if not group and self.adapter == Native and self.adapter.Group == nativeGroup then
		self.draft.mode = Native.GroupMode()
	else
		group = group or self.adapter.Group()
		self.draft.mode = (group.grouped or group.raid or group.instance) and "party" or "solo"
	end
	return self.draft.mode
end
function Service:CanEditForm()
	local group = self.adapter.Group()
	return not group.raid and not group.instance and (not group.grouped or group.leader == true)
end
function Service:GetLeaderPublication()
	local group, ctx = self.adapter.Group(), self:Context()
	if not group.grouped or group.raid or group.instance or group.leader or not ctx then return nil end
	if self.partySync then
		local record, _, authoritative = self.partySync:GetView()
		if record or authoritative then return record end
	end
	local leader = self.adapter.PartyLeaderName and P.FullName(self.adapter.PartyLeaderName())
	local record = leader and self.records[leader:lower()]
	if not record or record.mode ~= "party" or record.owner:lower() ~= leader:lower()
		or record.expiresAt <= self:Now() then return nil end
	if self.partySync and self.partySync.started and not self.partySync:MatchesRoster(record) then return nil end
	-- A former leader's post or a post for a different roster is not this
	-- member's form. Only received publications participate, never drafts.
	for _, member in ipairs(record.members) do
		if member.name:lower() == ctx.name:lower() then return record end
	end
end
function Service:GetActivityView()
	local group = self.adapter.Group()
	if not group.grouped or group.raid or group.instance or group.leader then
		return self:GetMyActivity(), false
	end
	-- Display the received party post without acquiring its publication,
	-- chat identity or logout recovery ownership.
	local record = self:GetLeaderPublication()
	if record then return record, true, "live" end
	if self.partySync and self.partySync.started then
		local _, state = self.partySync:GetView()
		return nil, true, state or "unavailable"
	end
	local state = self.transport.state
	if state == "error" or state == "disconnected" or self.lastError then
		return nil, true, "unavailable"
	end
	if self.partyFormDirty or self:IsQuerying() or state == "joining" or not self.transport.echoAt then
		return nil, true, "loading"
	end
	-- Silence on the public channel cannot prove that the captain has no post.
	return nil, true, "unavailable"
end
function Service:GetFormPreferences()
	if self:CanEditForm() then return self.draft, false end
	local record = self:GetLeaderPublication()
	local ids = {}
	for _, id in ipairs(record and record.activityIDs or {}) do ids[#ids + 1] = id end
	return { activityIDs = ids, note = record and record.note or "" }, true
end
function Service:LoadDraft()
	self:SyncDraftMode()
	if self.draftLoaded then return end
	local ctx = self:Context()
	if not ctx then return end
	self.draftLoaded = true
	local stored = self.adapter.DraftStore()[ctx.region .. ":" .. ctx.name:lower()]
	if type(stored) == "table" then
		self.draft.note = P.Truncate(P.Text(stored.note) or "", P.MAX_NOTE_BYTES):gsub("[%c|]", " ")
		self.draft.roles = P.Integer(stored.roles, 0, 7) or 0
		self.draft.partySpecs = copyPartySpecs(stored.partySpecs)
		self.draft.soloSpecs = copySpecChoice(stored.soloSpecs)
		local seen = {}
		for _, id in ipairs(type(stored.activityIDs) == "table" and stored.activityIDs or {}) do
			id = P.Integer(id, 1, 10000000)
			if id and not seen[id] and #self.draft.activityIDs < 24 then
				seen[id] = true; self.draft.activityIDs[#self.draft.activityIDs + 1] = id
			end
		end
	end
	if self.draft.roles == 0 then
		local member = self.adapter.Member("player")
		self.draft.roles = member and member.roles or 0
	end
end
function Service:SaveDraft()
	self:SyncDraftMode()
	local ctx = self:Context()
	if not ctx then return end
	local ids = {}
	for _, id in ipairs(self.draft.activityIDs) do ids[#ids + 1] = id end
	self.adapter.DraftStore()[ctx.region .. ":" .. ctx.name:lower()] = {
		mode = self.draft.mode, note = P.Truncate(self.draft.note, P.MAX_NOTE_BYTES),
		roles = self.draft.roles, activityIDs = ids, soloSpecs = copySpecChoice(self.draft.soloSpecs),
		partySpecs = copyPartySpecs(self.draft.partySpecs),
	}
end

function Service:GetPartyMembers()
	local group, members = self.adapter.Group(), {}
	if not group.grouped or group.raid or group.instance then return members end
	for index = 0, math.min(group.count or 0, 4) do
		local member = self.adapter.Member and self.adapter.Member(index == 0 and "player" or "party" .. index)
		if member then members[#members + 1] = member end
	end
	return members
end

function Service:GetMemberSpecs(member)
	return self.adapter.Specs and self.adapter.Specs(member.classID) or {}
end

function Service:GetSelectedSpecIDs(member, preferences)
	preferences = preferences or self.draft
	local choice = preferences.mode == "solo" and preferences.soloSpecs
		or preferences.mode == "party" and preferences.partySpecs and preferences.partySpecs[member.name:lower()]
	if choice and choice.classID == member.classID then
		if choice.followCurrent and not preferences.freezeDefaults and member.specID and member.specID > 0 then
			for _, spec in ipairs(self:GetMemberSpecs(member)) do
				if spec.id == member.specID then return { member.specID } end
			end
		end
		return P.CopySpecIDs(choice.specIDs or (choice.specID and { choice.specID })) or {}
	end
	-- Missing choices use each member's live specialization. Only an explicit
	-- edit is saved; a role alone cannot identify which specialization is active.
	return member.specID and member.specID > 0 and { member.specID } or {}
end

function Service:CanEditMemberSpecs(name, classID, mode)
	local group = self.adapter.Group()
	local grouped = group.grouped or group.raid or group.instance
	if mode == "solo" then
		local player = not grouped and self.adapter.Member and self.adapter.Member("player")
		return player and player.name:lower() == name:lower() and player.classID == classID or false
	end
	if mode ~= "party" or not group.leader then return false end
	for _, member in ipairs(self:GetPartyMembers()) do
		if member.name:lower() == name:lower() and member.classID == classID then return true end
	end
	return false
end

function Service:ToggleMemberSpec(name, classID, specID, mode)
	if not self:CanEditMemberSpecs(name, classID, mode) then return false end
	local valid
	for _, spec in ipairs(self:GetMemberSpecs({ classID = classID })) do
		if spec.id == specID and ROLE_BITS[spec.role] then valid = true; break end
	end
	if not valid then return false end
	self:SyncDraftMode()
	local members = mode == "party" and self:GetPartyMembers() or { self.adapter.Member("player") }
	local selected
	for _, member in ipairs(members) do
		if member.name:lower() == name:lower() then selected = self:GetSelectedSpecIDs(member); break end
	end
	if not selected then return false end
	local removed
	for index, id in ipairs(selected) do
		if id == specID then table.remove(selected, index); removed = true; break end
	end
	if not removed then selected[#selected + 1] = specID end
	table.sort(selected)
	local choice = { classID = classID, specIDs = selected }
	if mode == "solo" then self.draft.soloSpecs = choice
	else
		local previous = copyPartySpecs(self.draft.partySpecs)
		self.draft.partySpecs = {}
		for _, member in ipairs(members) do
			local key = member.name:lower(); self.draft.partySpecs[key] = previous[key]
		end
		self.draft.partySpecs[name:lower()] = choice
	end
	self:SaveDraft()
	return true
end

function Service:ApplyIntendedSpecs(member, preferences)
	local ids, catalog = self:GetSelectedSpecIDs(member, preferences), self:GetMemberSpecs(member)
	if #catalog == 0 then return nil, "member_data_pending" end
	if #ids == 0 then
		preferences = preferences or self.draft
		local choice = preferences.mode == "solo" and preferences.soloSpecs
			or preferences.mode == "party" and preferences.partySpecs and preferences.partySpecs[member.name:lower()]
		if not choice or choice.classID ~= member.classID then return nil, "member_data_pending" end
		return nil, "choose_spec"
	end
	local mask = 0
	for _, id in ipairs(ids) do
		local role
		for _, spec in ipairs(catalog) do if spec.id == id then role = ROLE_BITS[spec.role]; break end end
		if not role then return nil, "choose_spec" end
		if not P.HasRole(mask, role) then mask = mask + role end
	end
	local copy = {}; for key, value in pairs(member) do copy[key] = value end
	copy.specIDs, copy.specID, copy.roles = ids, ids[1], mask
	return copy
end

function Service:GetPartySpecChoices()
	local readOnly = not self:CanEditForm()
	local record = readOnly and self:GetLeaderPublication()
	local members = readOnly and (record and record.members or {}) or self:GetPartyMembers()
	local choices = {}
	for _, member in ipairs(members) do
		-- A member sees the received selection, including every intended spec;
		-- their own draft and the roster's live spec cannot replace it.
		local ids = readOnly and (P.CopySpecIDs(P.GetSpecIDs(member)) or {}) or self:GetSelectedSpecIDs(member)
		choices[#choices + 1] = { name = member.name, classID = member.classID, specIDs = ids,
			hasSelection = readOnly and #ids > 0 or not readOnly and self:ApplyIntendedSpecs(member) ~= nil }
	end
	return choices, readOnly
end

function Service:ClearReload()
	local store = self.adapter.ReloadStore and self.adapter.ReloadStore()
	if type(store) == "table" then for key in pairs(store) do store[key] = nil end end
end
function Service:CaptureChatRecovery()
	if self.communicationRecovery or not self.chat or not self.chat:HasRecoverableContacts() then return end
	local record = self:GetMyActivity()
	self.communicationRecovery = {
		untilAt = self:Now() + P.TTL, session = self.transport.session, sequence = self.transport.sequence,
		nextAttempt = self:Now() + 1,
		revision = self.revision, publicationGeneration = self.publicationGeneration,
		preferences = record and copyPreferences(record.preferences or recordPreferences(record)),
	}
end
function Service:RecoverCommunication(now)
	local recovery = self.communicationRecovery
	if not recovery or self.reconnecting or self.loggingOut then return end
	if recovery.preferences then
		if self:HasRecruitment() then self:Stop("chat_role_changed"); return end
		local group, mode = self.adapter.Group(), recovery.preferences.mode
		if group.raid or group.instance or (mode == "solo" and group.grouped) then
			self:Stop("chat_joined"); return
		elseif mode == "party" and (not group.grouped or not group.leader) then
			self:Stop("chat_party_changed"); return
		end
	end
	if now >= recovery.untilAt or not self.chat:HasRecoverableContacts() then
		self.communicationRecovery = nil
		if recovery.preferences and not self:GetMyActivity() then self:Stop("chat_contact_lost") end
		return
	end
	if self.transport.state == "ready" then
		if not recovery.preferences or self:GetMyActivity() then
			self.communicationRecovery = nil
			if not recovery.preferences then self:RequestQuery() end
			return
		end
		if not self.current and not self.pendingRequest and not self.restoring then
			self.publicationGeneration = recovery.publicationGeneration
			self.restoring, self.restoreStartedAt = true, now
			self.restorePreferences = copyPreferences(recovery.preferences)
			self.pendingRequest = { preferences = copyPreferences(recovery.preferences), at = now, restore = true }
			self.status = "connecting"
		end
		return
	end
	if self.transport.state ~= "error" and self.transport.state ~= "disconnected" then return end
	if self.transport.adapter.Locked() or now < (recovery.nextAttempt or 0) then return end
	-- Permission/channel denial is not a transient network fault to hammer.
	if self.transport.reason == "restricted" or self.transport.reason == "channel_denied"
		or self.transport.reason == "unsupported_channel" or self.transport.reason == "prefix_failed" then return end
	recovery.nextAttempt = now + 10
	recovery.sequence = math.max(recovery.sequence or 0, self.transport.sequence or 0)
	self.reconnecting = true
	self:Connect(recovery)
	self.reconnecting = nil
end
function Service:OnLogout()
	if self.logoutHandled then return end
	self.logoutHandled = true
	if self.partySync then self.partySync:Stop() end
	-- An unused service must not replace a previously saved draft with defaults.
	if self.draftLoaded then self:SaveDraft() end
	if self.chat and self.chat.SaveHistory then self.chat:SaveHistory() end
	local record, ctx = self:GetMyActivity(), self:Context()
	local preferences = record and copyPreferences(record.preferences or recordPreferences(record)) or self.restorePreferences
		or (self.communicationRecovery and self.communicationRecovery.preferences)
	local at = self.adapter.Epoch and self.adapter.Epoch()
	local incomplete = not preferences and (self.pendingRequest ~= nil or self.pendingAt ~= nil)
	self:ClearReload()
	local store = self.adapter.ReloadStore and self.adapter.ReloadStore()
	if type(store) == "table" and ctx and at and (preferences or incomplete) then
		store.version, store.key = 1, ctx.project .. ":" .. ctx.region .. ":" .. ctx.name:lower()
		-- Repeated reloads during recovery cannot extend the original lease.
		store.at = record and at or self.restoreSavedAt or at
		store.preferences, store.incomplete = copyPreferences(preferences), incomplete == true
	end
	-- Unloading only saves local state and detaches; it never sends or leaves a channel.
	self.loggingOut = true
	self.transport:Disconnect(true)
	self.loggingOut = nil
end
function Service:FailRestore(reason)
	local recovery = self.communicationRecovery
	local transient = reason == "timeout" or reason == "echo_timeout" or reason == "locked"
		or reason == "identity" or reason == "activity_unavailable" or reason == "member_data_timeout"
		or reason == "send_failed" or reason == "channel_lost" or reason == "join_timeout"
	if recovery and transient and self:Now() < recovery.untilAt and self.chat:HasRecoverableContacts() then
		-- The chat lease is the outer deadline. A cold catalog or an unsuccessful
		-- transport attempt must not shorten it to the publication's 30 seconds.
		self.restoreStartedAt = self:Now()
		if self.pendingRequest then self.pendingRequest.at = self:Now() end
		if self.pendingAt or self.transport.state == "error" then self.transport:Fail(reason) end
		return
	end
	self:Stop("chat_contact_lost")
	local detailed = isPublicationRejection(reason) or reason == "member_data_timeout"
	self.status, self.recoveryNotice, self.restoreFailureReason = "paused", detailed and reason or "restore_failed", reason
	if detailed then
		self.lastError = reason; self:Notify("publication_blocked", reason)
	else self:Notify() end
end
function Service:OnEnteringWorld(isInitialLogin, isReloadingUi)
	if self.partySync then self.partySync:Start() end
	if self.worldEntryHandled or (isInitialLogin ~= true and isReloadingUi ~= true) then return end
	self.worldEntryHandled = true
	if self.chat and self.chat.RestoreHistory then self.chat:RestoreHistory(isInitialLogin, isReloadingUi) end
	if self:HasRecruitment() then self:OnRecruitmentChanged(true); return end
	local store = self.adapter.ReloadStore and self.adapter.ReloadStore()
	if type(store) ~= "table" then return end
	local version, key, at = store.version, store.key, P.Integer(store.at, 1, 100000000000)
	local preferences, incomplete = copyPreferences(store.preferences), store.incomplete == true
	self:ClearReload()
	-- A fresh login (including reconnecting after a crash) consumes but never resumes.
	if isReloadingUi ~= true or isInitialLogin == true or version ~= 1 then return end
	if self.current or self.pendingRequest or self.pendingAt then return end
	local ctx, epoch = self:Context(), self.adapter.Epoch and self.adapter.Epoch()
	if not ctx or key ~= ctx.project .. ":" .. ctx.region .. ":" .. ctx.name:lower() then return end
	self:LoadDraft()
	if not at or not epoch or epoch < at or epoch - at > P.TTL then
		self:FailRestore("expired"); return
	end
	if not preferences then
		self.status, self.recoveryNotice = "paused", incomplete and "publish_incomplete" or "restore_failed"
		self:Notify(); return
	end
	self.recoveryNotice, self.restoreFailureReason = nil, nil
	self.restoring, self.restoreStartedAt = true, self:Now()
	self.restorePreferences, self.restoreSavedAt = preferences, at
	local continuity = self.chatContinuity
	if continuity then
		self.communicationRecovery = { untilAt = self:Now() + continuity.untilEpoch - epoch,
			session = continuity.session, sequence = continuity.sequence, revision = continuity.revision,
			publicationGeneration = continuity.publicationGeneration, preferences = copyPreferences(preferences) }
	end
	if continuity then self.pendingRequest = { preferences = preferences, at = self.restoreStartedAt, restore = true } end
	local ok, reason = self:EnsureConnected()
	if not ok then self:FailRestore(reason or self.transport.reason); return end
	if not continuity then self.pendingRequest = { preferences = preferences, at = self.restoreStartedAt, restore = true } end
	self.status = "connecting"
	self:Notify()
end
function Service:Connect(continuity)
	if not continuity and self.communicationRecovery and not self.reconnecting then
		self:RecoverCommunication(self:Now())
		return self.transport.state == "ready" or self.transport.state == "joining", self.transport.reason
	end
	self:LoadDraft()
	self.lastError = nil
	self.probe, self.peers, self.records, self.owners, self.invitations = nil, {}, {}, {}, {}
	self.lastQuery, self.lastProbe, self.lastPublish = nil, nil, nil
	continuity = continuity or self.chatContinuity
	self.chatContinuity = nil
	if continuity then self.revision = math.max(self.revision, continuity.revision or 0) end
	local ok, reason = self.transport:Connect(continuity)
	if continuity then self.publicationGeneration = continuity.publicationGeneration end
	if ok and self.adapter.RequestProgress then self.adapter.RequestProgress() end
	if ok and self.transport.state == "ready" then self:Probe() end
	return ok, reason
end
function Service:EnsureConnected()
	if self.partySync then self.partySync:Start() end
	self:LoadDraft()
	if self.transport.state ~= "disconnected" and self.transport.state ~= "error" then return true end
	if self.communicationRecovery then
		self:RecoverCommunication(self:Now())
		return self.transport.state == "ready" or self.transport.state == "joining",
			self.transport.adapter.Locked() and "locked" or self.transport.reason
	end
	local ok, reason = self:Connect()
	if not ok then self.lastError = reason or self.transport.reason or "unavailable"; self:Notify() end
	return ok, reason
end
function Service:EnterFeature(board)
	-- Entering either feature prepares communication, never arms a publication.
	-- Reuse the live session so navigation cannot discard posts or contacts.
	self.lastError = nil
	local group = self.adapter.Group()
	if self.partySync then self.partySync:EnterFeature() end
	if not board and self.partySync and self.partySync.started and group.grouped
		and not group.leader and not group.raid and not group.instance then
		self:LoadDraft()
		return true
	end
	if board or (group.grouped and not group.leader and not group.raid and not group.instance) then
		return self:RequestQuery()
	end
	return self:EnsureConnected()
end
function Service:IsQuerying()
	return self.pendingQuery ~= nil or self.queryQueued == true or (self.queryUntil ~= nil and self:Now() < self.queryUntil)
end
function Service:Disconnect()
	self.communicationRecovery, self.chatContinuity = nil, nil
	if self.chat then
		for _, c in pairs(self.chat.conversations) do if not c.ended then self.chat:End(c) end end
	end
	self:SaveDraft()
	self:Stop("chat_contact_lost")
	-- Allow an explicit stop to send before detaching. A lost final packet is
	-- covered by the receiver's TTL; logout never calls LeaveChannelByName.
	self.transport:Disconnect()
	self.records, self.owners, self.peers, self.invitations = {}, {}, {}, {}
	self:Notify()
end
function Service:Fields(kind, ...)
	local ctx = self:Context()
	return { kind, ctx.project, ctx.region, ... }
end
function Service:Probe()
	if self.transport.state ~= "ready" then return false, "not_connected" end
	if self.lastProbe and self:Now() - self.lastProbe < 10 then return false, "cooldown" end
	self.lastProbe = self:Now()
	local nonce = self.transport.session .. tostring(self.transport.sequence + 1)
	self.probe = { nonce = nonce, at = self:Now(), replies = {} }
	local sent, reason = self.transport:Send(self:Fields("P", nonce), "probe")
	if not sent then self.probe = nil end
	return sent ~= nil, reason
end
function Service:Query()
	if self.transport.state ~= "ready" then return false, "not_connected" end
	if self.queryQueued then return true end
	if self.lastQuery and self:Now() - self.lastQuery < 15 then return false, "cooldown" end
	local group = self.adapter.Group()
	local memberView = group.grouped and not group.leader and not group.raid and not group.instance
	self.queryWindow = QUERY_RESPONSE_WINDOW + (memberView and QUERY_REPLY_INTERVAL or 0)
	-- Send can complete synchronously. Arm before enqueueing, then start the
	-- existing response window only after the query actually leaves the queue.
	self.queryQueued, self.queryUntil = true, nil
	local sequence, reason = self.transport:Send(self:Fields("Q"), "query")
	if sequence then
		self.lastError = nil
	else self.queryQueued = nil end
	self:Notify()
	return sequence ~= nil, reason
end
function Service:BuildRecord(preferences)
	local group = self.adapter.Group()
	self:SyncDraftMode(group)
	-- Pending clicks and reload checkpoints retain their original intent. A new
	-- roster may change the form, but cannot convert a captured publication.
	local draft = preferences or self.draft
	local ctx = self:Context()
	if not ctx then return nil, "identity" end
	if self.transport.adapter.Locked() then return nil, "locked" end
	if group.raid or group.instance then return nil, "already_grouped" end
	if draft.mode == "solo" and group.grouped then return nil, "choose_party" end
	if draft.mode == "party" and (not group.grouped or not group.leader) then return nil, "party_leader" end
	local eligibilityReason = self:GetPublicationEligibilityReason(draft.mode, group)
	if eligibilityReason then return nil, eligibilityReason end
	local allowed, ids = self:ActivitySet(), {}
	for _, id in ipairs(draft.activityIDs) do
		if not allowed[id] then return nil, "activity_unavailable" end
		ids[#ids + 1] = id
	end
	if #ids == 0 or #ids > 24 then return nil, "choose_activity" end
	local note = P.Text(draft.note)
	if not note or #note > P.MAX_NOTE_BYTES or note:find("[%c|]") then return nil, "note" end
	local player = self.adapter.Member("player")
	local members, pending = {}, player == nil
	if player then members[1] = player end
	if draft.mode == "party" then
		if not P.Integer(group.count, 1, 4) then return nil, "roster" end
		for index = 1, group.count do
			local member = self.adapter.Member("party" .. index)
			if not member then pending = true
			else members[#members + 1] = member end
		end
	end
	for index, member in ipairs(members) do
		local faction = P.Text(member.faction)
		if not faction or faction == "" or faction == "?" then pending = true
		elseif faction ~= ctx.faction then return nil, "faction" end
		local selected, reason = self:ApplyIntendedSpecs(member, draft)
		if not selected then
			if isMemberDataPending(reason) then pending = true else return nil, reason end
		else members[index] = selected end
	end
	-- Inspect every readable member before waiting: known invalid members
	-- must still reject the group even if another member's data is missing.
	if pending then return nil, "member_data_pending" end
	local progress, progressPending = {}, false
	if self.adapter.Progress then progress, progressPending = self.adapter.Progress(ids, self.raidInfoReady) end
	return { owner = ctx.name, mode = draft.mode, activityIDs = ids,
		members = members, note = note, revision = self.revision + 1,
		progress = progress }, nil, progressPending
end
-- Preview is allowed before the form is valid. It only contains the player's
-- actual available roster; publishing still passes BuildRecord's full gates.
function Service:GetDraftPreview()
	self:SyncDraftMode()
	local player = self.adapter.Member("player")
	if not player then return nil end
	local members, group = { player }, self.adapter.Group()
	if self.draft.mode == "party" and group.grouped and not group.raid then
		for index = 1, math.min(group.count or 0, 4) do
			local member = self.adapter.Member("party" .. index)
			if member then members[#members + 1] = member end
		end
	end
	for index, member in ipairs(members) do members[index] = self:ApplyIntendedSpecs(member, self.draft) or member end
	return { owner = player.name, mode = self.draft.mode, members = members,
		activityIDs = self.draft.activityIDs, note = self.draft.note,
		progress = self.adapter.Progress and self.adapter.Progress(self.draft.activityIDs, self.raidInfoReady) or {} }
end

function Service:RequestPublish()
	if self.pendingRequest or self.pendingAt or self.memberDataWaitAt then return false, "busy" end
	self.recoveryNotice, self.restoreFailureReason = nil, nil
	local record, reason = self:BuildRecord()
	if not record then return false, reason end
	if self.communicationRecovery then self:Stop("chat_republished") end
	local preferences = recordPreferences(record, self.draft)
	-- The initial send keeps exactly what the click displayed. Only subsequent
	-- metadata updates follow defaults; manual choices remain fixed throughout.
	preferences.freezeDefaults = true
	self.lastError = nil
	if self.transport.state == "ready" and self.transport.echoAt then
		if self.lastPublish and self:Now() < self.lastPublish + PUBLISH_INTERVAL then
			-- Keep the explicitly clicked draft through the publication cooldown.
			-- One pending request prevents duplicate sends and later edits stay local.
			self.pendingRequest = { preferences = preferences, at = self:Now(), readyAt = self.lastPublish + PUBLISH_INTERVAL }
			self.status = "queued"
			self:Notify()
			return true
		end
		local ok, errorKey = self:Publish(false, preferences)
		if ok or errorKey ~= "busy" then return ok, errorKey end
		self.pendingRequest = { preferences = preferences, at = self:Now() }
		self.status = "queued"
		self:Notify()
		return true
	end
	if self.transport.state == "disconnected" or self.transport.state == "error" then
		local ok, errorKey = self:Connect()
		if not ok or self.transport.state == "error" then return false, errorKey or self.transport.reason end
	end
	-- This is a one-shot request authorized by the publish click. Capture the
	-- clicked draft; later edits cannot silently change this pending request.
	self.pendingRequest = { preferences = preferences, at = self:Now() }
	self.status = "connecting"
	self:Notify()
	return true
end

function Service:IsPublicationQueued()
	return self.status == "queued" or (self.pendingAt ~= nil and self.transport:HasQueued("publication"))
end

function Service:RequestQuery()
	if self.pendingQuery or self.queryQueued then return true end
	local ok, reason = self:EnsureConnected()
	if not ok then return false, reason end
	if self.transport.state == "ready" and self.transport.echoAt then
		-- Share the response window with re-entry and refresh clicks. Keep the
		-- cached rows visible while publishers send their jittered responses.
		if self.lastQuery and self:Now() - self.lastQuery < 15 then return true end
		ok, reason = self:Query()
		if not ok then self.lastError = reason; self:Notify() end
		return ok, reason
	end
	self.pendingQuery = self:Now()
	self:Notify()
	return true
end

function Service:Publish(refreshMetadata, preferences)
	if self.transport.state ~= "ready" or not self.transport.echoAt then return false, "probe_first" end
	local interval = refreshMetadata and self:GetMetadataRefreshInterval() or PUBLISH_INTERVAL
	if self.lastPublish and self:Now() - self.lastPublish < interval then return false, "cooldown" end
	local record, reason, progressPending = self:BuildRecord(refreshMetadata and self.publishedDraft or preferences)
	if not record then return false, reason end
	local ctx = self:Context()
	local previous = { current = self.current, revision = self.revision, publishedDraft = self.publishedDraft,
		publicationGeneration = self.publicationGeneration,
		status = self.status, pendingAt = self.pendingAt, lastPublish = self.lastPublish,
		memberDataWaitAt = self.memberDataWaitAt, memberDataRetryAt = self.memberDataRetryAt,
		invitations = self.invitations, pendingPublicationKind = self.pendingPublicationKind }
	self.pendingPublicationKind = self.restoring and "restore" or refreshMetadata and "metadata" or (self.current and "update" or "publish")
	self.revision, self.current = record.revision, record
	self.publicationGeneration = self.publicationGeneration or record.revision
	self.publishedDraft = recordPreferences(record, refreshMetadata and self.publishedDraft or preferences or self.draft)
	self.status, self.pendingAt, self.lastPublish = "sending", self:Now(), self:Now()
	self.memberDataWaitAt, self.memberDataRetryAt = nil, nil
	local sequence, errorKey = self.transport:Send(P.RecordFields(record, ctx.project, ctx.region), "publication")
	-- The final send guard may have withdrawn this record while flushing.
	if self.current ~= record then return false, self.lastError or errorKey or "unavailable" end
	if not sequence then
		if errorKey == "busy" then
			-- Queue capacity is temporary. Keep confirmed state and the cooldown
			-- intact so the same explicit request can retry without publishing edits.
			self.current, self.revision, self.publishedDraft = previous.current, previous.revision, previous.publishedDraft
			self.publicationGeneration = previous.publicationGeneration
			self.status, self.pendingAt, self.lastPublish = previous.status, previous.pendingAt, previous.lastPublish
			self.memberDataWaitAt, self.memberDataRetryAt = previous.memberDataWaitAt, previous.memberDataRetryAt
			self.invitations, self.pendingPublicationKind = previous.invitations, previous.pendingPublicationKind
			return false, errorKey
		end
		self.current, self.pendingAt, self.status = nil, nil, "paused"
		self.publicationGeneration = nil
		self.pendingPublicationKind = nil
		self.records[ctx.name:lower()] = nil
		self:Notify(); return false, errorKey
	end
	self.nextHeartbeat, self.nextFull = self:Now() + 45, self:Now() + 120
	if self.bossBroadcast and self.bossBroadcast.record ~= record then self.bossBroadcast = nil end
	self.transport:CancelQueued("boss-progress")
	self.progressRetryAt = progressPending and (self:Now() + PUBLISH_INTERVAL) or nil
	self.rosterDirty, self.itemLevelDirty, self.specDirty = nil, nil, nil
	self:SaveDraft()
	self:Notify()
	return true
end
function Service:Stop(chatReason)
	self.communicationRecovery, self.chatContinuity = nil, nil
	if self.chat and not self.loggingOut then
		for _, c in pairs(self.chat.conversations) do
			if c.context == "seeking" and not c.ended then self.chat:End(c, chatReason or "chat_cancelled") end
		end
	end
	self.itemLevelDirty, self.specDirty = nil, nil
	if self.adapter.ResetPartyInspection then self.adapter.ResetPartyInspection() end
	self.transport:CancelQueued("publication")
	self.transport:CancelQueued("heartbeat")
	self.transport:CancelQueued("boss-progress")
	self.bossBroadcast = nil
	local hadCurrent = self.current ~= nil
	if hadCurrent then
		self.chatEndedPublicationGeneration = self.publicationGeneration
		self.chatPublicationEndReason = chatReason or "chat_cancelled"
	end
	local ctx = self:Context()
	if ctx then self.records[ctx.name:lower()] = nil end
	self.current, self.pendingAt, self.status = nil, nil, "draft"
	self.publicationGeneration = nil
	self.progressRetryAt = nil
	self.pendingPublicationKind = nil
	self.pendingRequest, self.pendingQuery, self.lastError = nil, nil, nil
	self.memberDataWaitAt, self.memberDataRetryAt = nil, nil
	self.restoring, self.restoreStartedAt, self.restorePreferences, self.restoreSavedAt = nil, nil, nil, nil
	self.recoveryNotice, self.restoreFailureReason = nil, nil
	self:ClearReload()
	self.invitations, self.nextReply = {}, nil
	if hadCurrent then
		self.revision = self.revision + 1
		if self.transport.state == "ready" then self.transport:Send(self:Fields("X", self.revision), "publication") end
	end
	self:SaveDraft()
	self:Notify()
	return true
end

function Service:AcceptOwner(sender, session, revision)
	local key, now = sender:lower(), self:Now()
	local owner = self.owners[key]
	if not owner then
		local count = 0; for _ in pairs(self.owners) do count = count + 1 end
		if count >= 300 then return nil end
		owner = { session = session, revision = 0, retired = {} }; self.owners[key] = owner
	elseif owner.session ~= session then
		if owner.retired[session] then return nil end
		local retiredCount = 0; for _ in pairs(owner.retired) do retiredCount = retiredCount + 1 end
		if retiredCount >= 8 then return nil end
		owner.retired[owner.session] = now
		owner.session, owner.revision = session, 0
		self.records[key] = nil
	end
	if revision < owner.revision then return nil end
	owner.at = now
	return owner, key
end
local function retainBossProgress(record, previous)
	if not previous or previous.session ~= record.session or previous.revision ~= record.revision then return end
	for _, entry in ipairs(record.progress) do
		for _, old in ipairs(previous.progress or {}) do
			if entry.activityID == old.activityID and entry.done == old.done and entry.total == old.total then
				entry.bosses = old.bosses; break
			end
		end
	end
end

function Service:SendBossProgress()
	local broadcast, current = self.bossBroadcast, self.current
	if not broadcast or not current or broadcast.record ~= current or self.pendingAt or self.memberDataWaitAt
		or self.transport:HasQueued("publication") or self.transport:HasQueued("boss-progress") then return end
	local entry = current.progress[broadcast.index]
	if not entry then
		if broadcast.repeatAfter then broadcast.index, broadcast.repeatAfter = 1, nil
		else self.bossBroadcast = nil end
		return
	end
	local data = P.BossData(entry)
	if data then
		local sequence = self.transport:Send(self:Fields("B", current.revision, entry.activityID, data), "boss-progress")
		if not sequence then return end
	end
	broadcast.index = broadcast.index + 1
end

function Service:SchedulePartyReply(sender, now)
	local record, group = self:GetMyActivity(), self.adapter.Group()
	if not record or record.mode ~= "party" or not group.grouped or not group.leader
		or group.raid or group.instance or self.pendingAt or self.memberDataWaitAt then return false end
	local name = P.FullName(sender)
	if not name then return false end
	name = name:lower()
	local publishedMember = false
	for _, member in ipairs(record.members) do
		if member.name:lower() == name then publishedMember = true; break end
	end
	if not publishedMember then return false end
	-- Public discovery stays throttled. Only a player in both the confirmed
	-- publication and the current native party can request the fast reply.
	for _, member in ipairs(self:GetPartyMembers()) do
		if member.name:lower() == name then
			local at = math.max(now, (self.lastReply or (now - PARTY_REPLY_INTERVAL)) + PARTY_REPLY_INTERVAL)
			self.nextReply = math.min(self.nextReply or at, at)
			return true
		end
	end
	return false
end

function Service:OnMessage(fields, sender, session, isSelf, sequence)
	local kind, now = fields[1], self:Now()
	if kind == "C" then
		if self.chat and not isSelf then self.chat:OnControl(fields, sender, session, sequence) end
	elseif kind == "P" and #fields == 4 and #fields[4] <= 40 then
		if not isSelf then
			local peer = self.peers[sender:lower()]
			local count = 0; for _ in pairs(self.peers) do count = count + 1 end
			if not peer and count >= 128 then return end
			if not peer or now - peer.at >= 10 then
				self.peers[sender:lower()] = { name = sender, at = now }
				self.transport:Send(self:Fields("A", sender, fields[4]), "ack:" .. sender:lower())
			end
		end
	elseif kind == "A" and #fields == 5 and not isSelf then
		local target = P.FullName(fields[4])
		if target and target:lower() == self:Context().name:lower() and self.probe
			and fields[5] == self.probe.nonce and now - self.probe.at <= 30 then
			local count = 0; for _ in pairs(self.probe.replies) do count = count + 1 end
			if count < 128 then self.probe.replies[sender:lower()] = { name = sender, at = now, rtt = now - self.probe.at } end
		end
	elseif kind == "Q" and #fields == 3 and not isSelf and self.current then
		if self:SchedulePartyReply(sender, now) then return end
		if not self.nextReply then
			-- Keep one deferred reply for members joining or reloading during
			-- the broadcast cooldown, instead of dropping their discovery query.
			local earliest = math.max(now, (self.lastReply or (now - QUERY_REPLY_INTERVAL)) + QUERY_REPLY_INTERVAL)
			self.nextReply = earliest + math.random(2, 12)
		end
	elseif kind == "U" then
		local record = P.ReadRecord(fields, sender, session, now)
		if not record then return end
		local previous = self.records[record.key]
		retainBossProgress(record, previous)
		if previous and previous.expiresAt > now and previous.session == record.session and previous.revision == record.revision then
			record.updatedAt = previous.updatedAt
		end
		if isSelf then
			if self.current and record.revision == self.current.revision and session == self.transport.session then
				local action = self.pendingAt and self.pendingPublicationKind
				self.pendingPublicationKind = nil
				self.status, self.pendingAt = "published", nil
				self.restoring, self.restoreStartedAt, self.restorePreferences, self.restoreSavedAt = nil, nil, nil, nil
				-- Only the complete server echo enters the board. A draft or a
				-- queued publication must never look like a published listing.
				self.records[record.key] = record
				record.preferences = copyPreferences(self.publishedDraft)
				-- A spec snapshot may arrive while the clicked publication is queued.
				if self.specSnapshotSignature then self:RefreshPublicationSpecs() end
				if self.bossBroadcast and self.bossBroadcast.record == self.current then
					-- Finish long batches before responding again, so repeated
					-- discovery requests cannot starve the later difficulties.
					self.bossBroadcast.repeatAfter = true
				else self.bossBroadcast = { record = self.current, index = 1 } end
				-- Consume the pending action before notifying: repeated echoes,
				-- heartbeats and view refreshes cannot confirm it a second time.
				if action then self:Notify("publication_confirmed", action) end
			end
			return
		end
		local owner, key = self:AcceptOwner(sender, session, record.revision)
		if not owner or (owner.closed and record.revision <= owner.revision) then return end
		owner.revision, owner.closed = record.revision, false
		self.records[key] = record
	elseif kind == "B" and #fields == 6 then
		local revision = P.Integer(fields[4], 1, 2147483647)
		local activityID = P.Integer(fields[5], 1, 10000000)
		local record = self.records[sender:lower()]
		if not record or record.session ~= session or record.revision ~= revision or record.expiresAt <= now then return end
		for _, entry in ipairs(record.progress) do
			if entry.activityID == activityID then
				local bosses = P.ReadBossData(fields[6], entry.done, entry.total)
				if bosses then entry.bosses = bosses end
				return
			end
		end
	elseif kind == "X" and #fields == 4 and not isSelf then
		local revision = P.Integer(fields[4], 1, 2147483647)
		if not revision then return end
		local owner, key = self:AcceptOwner(sender, session, revision)
		if owner then owner.revision, owner.closed = revision, true; self.records[key] = nil end
	elseif kind == "H" and #fields == 4 then
		local revision = P.Integer(fields[4], 1, 2147483647)
		local record = self.records[sender:lower()]
		if record and record.session == session and record.revision == revision and record.expiresAt > now then
			-- Renewal proves liveness; it must not bump an unchanged listing.
			record.expiresAt = now + P.TTL
		end
	elseif kind == "I" and #fields == 7 and not isSelf then
		local target = P.FullName(fields[4])
		local revision = P.Integer(fields[5], 1, 2147483647)
		local id = P.Integer(fields[6], 1, 10000000)
		if self.current and target and target:lower() == self:Context().name:lower()
			and fields[7] == self.transport.session
			and self.current.revision == revision and id and self:ActivitySet()[id]
			and not self.adapter.Blocked(sender) then
			local interested = false
			for _, wanted in ipairs(self.current.activityIDs) do if id == wanted then interested = true end end
			local count = 0; for _ in pairs(self.invitations) do count = count + 1 end
			if interested and count < 64 then self.invitations[sender:lower()] = { name = sender, activityID = id, at = now } end
		end
	end
end

local function sameProgress(left, right)
	if #left ~= #right then return false end
	for index, entry in ipairs(left) do
		local other = right[index]
		if entry.activityID ~= other.activityID or entry.done ~= other.done or entry.total ~= other.total
			or P.BossData(entry) ~= P.BossData(other) then return false end
	end
	return true
end

function Service:Tick(now)
	local recruiting = self:ReadRecruitmentState()
	if recruiting ~= nil and recruiting ~= self.recruitmentActive then self:OnRecruitmentChanged(recruiting) end
	self:SyncDraftMode()
	if self.partyFormDirty then
		self.partyFormDirty = nil
		local group = self.adapter.Group()
		if group.grouped and not group.leader and not group.raid and not group.instance then self:RequestQuery() end
	end
	if isPublicationRejection(self.lastError) and self:GetPublicationEligibilityReason(self.draft.mode) == nil then
		if self.recoveryNotice == self.lastError then self.recoveryNotice = nil end
		self.lastError = nil
	end
	self:CheckPublicationConnection()
	if self.memberDataWaitAt and now - self.memberDataWaitAt >= MEMBER_DATA_TIMEOUT
		and not (self.communicationRecovery and now < self.communicationRecovery.untilAt) then
		self:PausePublication("member_data_timeout")
	end
	if self.adapter.RefreshPartyInspection
		and self.adapter.RefreshPartyInspection(now, self.current ~= nil and self.current.mode == "party") then
		self:OnItemLevelChanged()
	end
	for key, record in pairs(self.records) do if now >= record.expiresAt then self.records[key] = nil end end
	for key, owner in pairs(self.owners) do if now - owner.at > P.TTL * 2 then self.owners[key] = nil end end
	for key, peer in pairs(self.peers) do if now - peer.at > P.TTL then self.peers[key] = nil end end
	for key, invite in pairs(self.invitations) do if now - invite.at > P.TTL then self.invitations[key] = nil end end
	if self.restoring and now - self.restoreStartedAt >= RESTORE_TIMEOUT then
		self:FailRestore(self.memberDataWaitAt and "member_data_timeout" or "timeout"); return
	end
	if self.transport.state == "ready" and not self.lastProbe then
		local ok, reason = self:Probe()
		if not ok then self.transport:Fail(reason or "send_failed") end
	end
	if self.pendingRequest then
		local request = self.pendingRequest
		if now - request.at > 30 then
			if self.communicationRecovery then self:FailRestore(self.memberDataWaitAt and "member_data_timeout" or "timeout")
			elseif self.memberDataWaitAt then self:PausePublication("member_data_timeout")
			else self.transport:Fail("echo_timeout") end
		elseif self.transport.state == "ready" and self.transport.echoAt and (not request.readyAt or now >= request.readyAt)
			and (not request.restore or (not self.transport.adapter.Locked()
				and (not self.adapter.CatalogReady or self.adapter.CatalogReady()))) then
			self.pendingRequest = nil
			local ok, reason = self:Publish(false, request.preferences)
			if not ok and (reason == "cooldown" or reason == "busy") then
				request.readyAt = reason == "cooldown" and self.lastPublish + PUBLISH_INTERVAL or now + 1
				self.pendingRequest, self.status = request, "queued"
			elseif not ok and isMemberDataPending(reason) then
				self:WaitForMemberData(now)
				request.readyAt, self.pendingRequest = now + 1, request
			elseif not ok and request.restore then
				if self.restoring and (reason == "identity" or reason == "activity_unavailable" or reason == "locked") then
					request.readyAt, self.pendingRequest = now + 1, request
				else self:FailRestore(reason) end
			elseif not ok then
				if self.memberDataWaitAt then self:PausePublication(reason)
				else
					self.status, self.lastError = "paused", reason
					if isPublicationRejection(reason) then self:Notify("publication_blocked", reason) end
				end
			end
		end
	end
	if self.pendingQuery then
		if now - self.pendingQuery > 30 then self.transport:Fail("echo_timeout")
		elseif self.transport.state == "ready" and self.transport.echoAt then
			self.pendingQuery = nil
			local ok, reason = self:Query()
			if not ok then self.lastError = reason end
		end
	end
	if self.current then
		-- Use the existing service driver to finish cold metadata reads. Only a
		-- changed projection requests a publication; draft edits remain local.
		if self.progressRetryAt and now >= self.progressRetryAt and not self.pendingAt and not self.pendingRequest then
			local progress, pending = self.adapter.Progress(self.current.activityIDs, self.raidInfoReady)
			self.progressRetryAt = pending and (now + PUBLISH_INTERVAL) or nil
			if not sameProgress(self.current.progress, progress) then self.rosterDirty = true end
		end
		local group = self.adapter.Group()
		if group.raid or group.instance or (self.current.mode == "solo" and group.grouped)
			or (self.current.mode == "party" and (not group.grouped or not group.leader)) then
			if self.restoring then self:FailRestore("already_grouped")
			else
				local joined = group.raid or group.instance or self.current.mode == "solo"
				self:Stop(joined and "chat_joined" or "chat_party_changed"); self.status = "paused"
			end
		elseif self.pendingAt and now - self.pendingAt > 25 then
			if self.restoring then self:FailRestore("echo_timeout")
			elseif not self.chat or not self.chat:HasRecoverableContacts() then self:Stop("chat_contact_lost"); self.status = "paused" end
			self.transport:Fail("echo_timeout")
		elseif (self.rosterDirty or self.specDirty) and not self.pendingRequest and not self.pendingAt
			and now - (self.lastPublish or 0) >= self:GetMetadataRefreshInterval()
			and (not self.memberDataRetryAt or now >= self.memberDataRetryAt) then
			local record, reason = self:BuildRecord(self.publishedDraft)
			if record then
				if not self.rosterDirty and sameMemberSpecs(record, self.current) then self.specDirty = nil
				else self:Publish(true) end
			elseif isMemberDataPending(reason) then self:WaitForMemberData(now)
			else self:PausePublication(reason) end
		elseif not self.memberDataWaitAt and not self.pendingAt and not self.transport:HasQueued("publication")
			and (now >= self.nextFull or (self.nextReply and now >= self.nextReply)) then
			local ctx = self:Context()
			self.transport:Send(P.RecordFields(self.current, ctx.project, ctx.region), "publication")
			self.nextFull, self.lastReply, self.nextReply = now + 120, now, nil
		elseif not self.memberDataWaitAt and now >= self.nextHeartbeat then
			self.transport:Send(self:Fields("H", self.current.revision), "heartbeat")
			self.nextHeartbeat = now + 45 + math.random(0, 5)
		end
	end
	-- Only visible views repaint; network/cache lifetimes do not depend on UI.
	self:SendBossProgress()
	self:Notify("tick")
end

function Service:CanDiscover(record, ctx, allowed)
	ctx, allowed = ctx or self:Context(), allowed or self:ActivitySet()
	if not ctx or record.expiresAt <= self:Now() then return false end
	local common = false
	for _, id in ipairs(record.activityIDs) do if allowed[id] then common = true end end
	if not common then return false end
	for _, member in ipairs(record.members) do
		if self.adapter.Blocked(member.name) then return false end
		-- Channel pilot proves same-faction discovery only. Mixed/unknown
		-- factions are withheld until a cross-faction discovery route is tested.
		if member.faction ~= ctx.faction then return false end
	end
	return true
end
function Service:List(filters)
	filters = filters or {}
	local out, ctx, allowed = {}, self:Context(), self:ActivitySet()
	for _, record in pairs(self.records) do
		local matches = self:CanDiscover(record, ctx, allowed)
		if filters.activityID then
			local found = false
			for _, id in ipairs(record.activityIDs) do if id == filters.activityID then found = true end end
			matches = matches and found
		end
		if filters.activityIDs ~= nil then
			local found = false
			for _, id in ipairs(record.activityIDs) do
				if filters.activityIDs[id] == true then found = true; break end
			end
			matches = matches and found
		end
		if filters.mode then matches = matches and filters.mode == record.mode end
		if filters.maxMembers then matches = matches and #record.members <= filters.maxMembers end
		if filters.classID or filters.specID or filters.specIDs ~= nil or filters.role or filters.roles ~= nil then
			local found = false
			for _, member in ipairs(record.members) do
				local matchesSpecs = filters.specIDs == nil
				if type(filters.specIDs) == "table" then
					for specID, selected in pairs(filters.specIDs) do
						if selected == true and P.HasSpec(member, specID) then matchesSpecs = true; break end
					end
				end
				local matchesRoles = filters.roles == nil
				if type(filters.roles) == "table" then
					for _, role in ipairs({ 1, 2, 4 }) do
						if filters.roles[role] == true and P.HasRole(member.roles, role) then matchesRoles = true; break end
					end
				end
				if (not filters.classID or member.classID == filters.classID)
					and (not filters.specID or P.HasSpec(member, filters.specID))
					and matchesSpecs and matchesRoles
					and (not filters.role or P.HasRole(member.roles, filters.role)) then found = true end
			end
			matches = matches and found
		end
		local query = (filters.query or ""):lower()
		if query ~= "" then matches = matches and (record.owner:lower():find(query, 1, true)
			or record.note:lower():find(query, 1, true)) ~= nil end
		if matches then out[#out + 1] = record end
	end
	table.sort(out, function(a, b) return a.updatedAt == b.updatedAt and a.key < b.key or a.updatedAt > b.updatedAt end)
	return out
end
function Service:GetLive(key)
	local record = self.records[key]
	return record and self:CanDiscover(record) and record or nil
end

function Service:GetMenuMember(target)
	if type(target) ~= "table" then return nil end
	local name = P.FullName(target.memberName)
	local ctx = self:Context()
	local ownName = ctx and P.FullName(ctx.name)
	-- The row was admitted by GetLive when opening the menu. Native menu
	-- enabled predicates poll: recheck identity/lifetime here without rebuilding
	-- the raid activity catalog for every button on every frame.
	local record = target.recordKey and self.records[target.recordKey]
	if not name or not ownName or not record or record.session ~= target.session
		or record.revision ~= target.revision or record.expiresAt <= self:Now()
		or record.isTest or record.isDebugTest or record.source == "test" then
		return nil
	end
	for _, member in ipairs(record.members) do
		if self.adapter.Blocked(member.name) or member.faction ~= ctx.faction then return nil end
	end
	for _, member in ipairs(record.members) do
		local fullName = P.FullName(member.name)
		if fullName and fullName:lower() == name:lower() then
			return member, fullName:lower() == ownName:lower()
		end
	end
end

function Service:GetMemberInviteType(target)
	local member, isSelf = self:GetMenuMember(target)
	if not member or isSelf or type(self.adapter.GetMemberInviteType) ~= "function" then return nil end
	return self.adapter.GetMemberInviteType()
end

function Service:CanMemberAction(target, action)
	local member, isSelf = self:GetMenuMember(target)
	if not member then return false, "expired" end
	if isSelf then return false, "own_post" end
	if type(self.adapter.CanMemberAction) ~= "function" then return false, "unavailable" end
	return self.adapter.CanMemberAction(action, member.name)
end

function Service:PerformMemberAction(target, action)
	local allowed, reason = self:CanMemberAction(target, action)
	if not allowed then return false, reason end
	if type(self.adapter.PerformMemberAction) ~= "function" then return false, "unavailable" end
	return self.adapter.PerformMemberAction(action, target.memberName)
end

function Service:GetMyActivity()
	-- A confirmed publication is required before resolving local identity.
	if not self.current then return nil end
	local ctx = self:Context()
	local record = ctx and self.records[ctx.name:lower()]
	-- Keep the last confirmed publication while an update is in flight. Drafts
	-- and queued first publications are never presented as an active post.
	if self.current and record and record.session == self.transport.session
		and record.expiresAt > self:Now() then return record end
end
function Service:IsOwn(record)
	local ctx = self:Context()
	return record ~= nil and ctx ~= nil and record.owner:lower() == ctx.name:lower()
end
function Service:Invite(key, revision, session)
	local record = self:GetLive(key)
	if not record or record.revision ~= revision or record.session ~= session then return false, "expired" end
	if self:IsOwn(record) then return false, "own_post" end
	-- A party publication must go through its captain's group application.
	if record.mode ~= "solo" then return false, "expired" end
	local allowed, reason = self:CanContact(record)
	if not allowed then return false, reason end
	if self.lastInvite and self:Now() - self.lastInvite < 5 then return false, "cooldown" end
	self.lastInvite = self:Now()
	return self.adapter.Invite(record.owner), "cannot_invite"
end
function Service:OfferListing(key, revision, activityID, session)
	local record = self:GetLive(key)
	if not record or record.revision ~= revision or record.session ~= session then return false, "expired" end
	if self:IsOwn(record) then return false, "own_post" end
	if record.mode ~= "party" then return false, "expired" end
	local allowed, reason = self:CanContact(record)
	if not allowed then return false, reason end
	if not activityID or not self.adapter.ActiveActivity or self.adapter.ActiveActivity() ~= activityID then
		return false, "no_listing"
	end
	if self.lastOffer and self:Now() - self.lastOffer < 5 then return false, "cooldown" end
	if not self.chat then return false, "chat_unavailable" end
	-- The request shares the verified contact lifetime, never the retired I inbox.
	local conversation, failure = self.chat:RequestApplication(key, revision, session)
	if conversation then self.lastOffer = self:Now() end
	return conversation ~= nil, failure, conversation
end
function Service:Diagnostics()
	local t, ctx = self.transport, self:Context() or {}
	local visible, own, remote = self:List(), 0, 0
	for _, record in ipairs(visible) do
		if self:IsOwn(record) then own = own + 1 else remote = remote + 1 end
	end
	local lines = { "GroupFinder raid channel pilot / GFRS1", "state=" .. t.state .. " reason=" .. (t.reason or "-"),
		"transport=CHAT_MSG_ADDON prefix=" .. Transport.PREFIX .. " sendResult=" .. tostring(t.lastSendResult)
			.. " throttled=" .. (t.counters.throttled or 0),
		"addon=" .. (P.Text(safe(GF.GetAddonVersion)) or "?") .. " client=" .. (P.Text(GF.Compat and GF.Compat.version) or "?")
			.. " build=" .. (P.Text(GF.Compat and GF.Compat.build) or "?"),
		"project=" .. (ctx.project or "?") .. " region=" .. (ctx.region or "?") .. " realm=" .. (ctx.realm or "?") .. " faction=" .. (ctx.faction or "?"),
		"self=" .. (ctx.name or "?"),
		"channel=" .. Transport.CHANNEL .. " id=" .. (t.adapter.ChannelID() or 0)
			.. " lastSendID=" .. tostring(t.lastSendChannelID) .. " owned=" .. tostring(t.joinedByUs == true),
		"tx=" .. t.counters.tx .. " rx=" .. t.counters.rx .. " echo=" .. t.counters.echoes .. " invalid=" .. t.counters.invalid,
		"queued=" .. #t.queue .. " lastEchoAge=" .. (t.echoAt and string.format("%.1fs", self:Now() - t.echoAt) or "never"),
		"publication=" .. self.status .. " visibleRecords=" .. #visible .. " ownRecords=" .. own .. " remoteRecords=" .. remote,
		"peer replies:" }
	if self.partySync then lines[#lines + 1] = self.partySync:Diagnostics() end
	for _, reply in pairs(self.probe and self.probe.replies or {}) do
		lines[#lines + 1] = P.Display(reply.name) .. " " .. string.format("%.1fs", reply.rtt)
	end
	return table.concat(lines, "\n")
end
