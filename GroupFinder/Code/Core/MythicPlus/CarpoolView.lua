local _, GF = ...

GF.MythicPlusCarpoolView = GF.MythicPlusCarpoolView or {}
local View = GF.MythicPlusCarpoolView
local Util = GF.MythicPlusServiceUtil

local function canonical(value)
	value = type(value) == "string" and value or ""
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("%s+", "")
	return value ~= "" and string.lower(value) or nil
end

local function assignedRoles(role)
	local normalized = Util.NormalizeRole(role)
	return normalized and { [normalized] = true } or nil, normalized
end

local function collectRosterMembers()
	local cache = GF.MythicPlusRosterCache
	local members = cache and cache.GetMembers and cache:GetMembers() or {}
	if #members > 0 then
		return members
	end
	members = {}
	local function addUnit(unit)
		local fullName, name = Util.GetUnitFullName(unit)
		if not fullName then
			return
		end
		local classFile
		if UnitClass then
			classFile = select(2, UnitClass(unit))
		end
		members[#members + 1] = {
			fullName = fullName,
			name = name,
			classFile = classFile,
		}
	end
	if IsInRaid and IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			addUnit("raid" .. index)
		end
	else
		addUnit("player")
		if IsInGroup and IsInGroup() then
			for index = 1, GetNumSubgroupMembers() do
				addUnit("party" .. index)
			end
		end
	end
	return members
end

local function identifiersMatch(left, right)
	local leftFull = canonical(left)
	local rightFull = canonical(right)
	if not (leftFull and rightFull) then
		return false
	end
	if leftFull == rightFull then
		return true
	end
	local leftShort = leftFull:match("^([^-]+)")
	local rightShort = rightFull:match("^([^-]+)")
	return leftShort == rightShort
		and not leftFull:find("-", 1, true)
		and not rightFull:find("-", 1, true)
end

local function findRosterMember(members, ...)
	for index = 1, select("#", ...) do
		local candidate = select(index, ...)
		if type(candidate) == "string" and candidate ~= "" then
			for _, member in ipairs(members or {}) do
				if identifiersMatch(member.fullName or member.key, candidate)
					or identifiersMatch(member.name, candidate)
				then
					return member
				end
			end
		end
	end
	return nil
end

local function applicantDataIsCurrent(data)
	if type(data) ~= "table" or data._gfSoftUnavailable == true then
		return false
	end
	local appInfo = data.appInfo
	local status = data.status or appInfo and appInfo.applicationStatus
	if appInfo and appInfo.pendingApplicationStatus ~= nil then
		return status == "applied"
	end
	return status == nil or status == ""
		or status == "applied"
		or status == "invited"
		or status == "inviteaccepted"
end

local function memberApplicantRoles(member)
	if type(member) ~= "table" then
		return nil
	end
	local roles, assignedRole = assignedRoles(member.assignedRole)
	if roles then
		return {
			assignedRole = assignedRole,
			roles = roles,
		}
	end
	roles = Util.CopyRoles(member.roles)
	for _, role in pairs({ member.role1, member.role2, member.role3 }) do
		local normalized = Util.NormalizeRole(role)
		if normalized then
			roles[normalized] = true
		end
	end
	if not next(roles) then
		return nil
	end
	return {
		roles = roles,
	}
end

local function collectApplicantRoleLookup()
	local lookup = {
		full = {},
		short = {},
	}
	local actions = GF.ApplicantActionService
	local model = GF.ApplicantSnapshotBuilder
	if not (actions and actions.GetApplicantIDs
		and model and model.BuildApplicantSafely)
	then
		return lookup
	end
	local applicantIDs = actions:GetApplicantIDs()
	for _, applicantID in ipairs(applicantIDs) do
		local data = model:BuildApplicantSafely(applicantID)
		if applicantDataIsCurrent(data) then
			for _, member in ipairs(data.members or {}) do
				local roleInfo = memberApplicantRoles(member)
				local normalized = roleInfo and canonical(member.name)
				if normalized then
					if normalized:find("-", 1, true) then
						lookup.full[normalized] = roleInfo
					else
						lookup.short[normalized] = roleInfo
					end
				end
			end
		end
	end
	return lookup
end

local function findApplicantRoles(lookup, character)
	local normalized = canonical(character
		and (character.fullName or character.key or character.name))
	if not normalized then
		return nil
	end
	if normalized:find("-", 1, true) then
		return lookup.full[normalized]
	end
	return lookup.short[normalized]
end

local function resolveDisplayRoles(character, rosterMembers, applicantRoles)
	local rosterMember = findRosterMember(rosterMembers,
		character and character.fullName,
		character and character.key,
		character and character.name)
	if rosterMember then
		local roles, role = assignedRoles(rosterMember.role)
		if roles then
			return roles, role, "roster"
		end
	end
	local applicant = findApplicantRoles(applicantRoles, character)
	if applicant then
		if applicant.assignedRole then
			return Util.CopyRoles(applicant.roles), applicant.assignedRole,
				"meetingstone_applicant"
		end
		if next(applicant.roles or {}) then
			return Util.CopyRoles(applicant.roles), nil, "meetingstone_applicant"
		end
	end
	return Util.CopyRoles(character and character.roles,
		character and (character.role or character.specRole)),
		Util.NormalizeRole(character and (character.role or character.specRole)),
		"stored"
end

local function shortName(value)
	return type(value) == "string" and value:match("^([^-]+)") or nil
end

local function buildRemoteSource(snapshot, rosterMembers)
	local ownerKey = snapshot.ownerFullName or snapshot.ownerKey
	local member = findRosterMember(
		rosterMembers, ownerKey, snapshot.ownerName)
	return {
		ownerKey = ownerKey or member and (member.fullName or member.key),
		ownerName = member and (member.name or shortName(member.fullName))
			or snapshot.ownerName or shortName(ownerKey),
		ownerClass = member and (member.classFile or member.class)
			or snapshot.ownerClass,
		localSource = false,
	}
end

local function copyCharacter(character)
	local copy = {}
	for key, value in pairs(character or {}) do
		if type(value) == "table" and (key == "roles" or key == "ratingColor") then
			local nested = {}
			for nestedKey, nestedValue in pairs(value) do
				nested[nestedKey] = nestedValue
			end
			copy[key] = nested
		else
			copy[key] = value
		end
	end
	copy.key = copy.key or copy.fullName or copy.name
	copy.fullName = copy.fullName or copy.key or copy.name
	copy.challengeModeID = copy.challengeModeID or copy.mapID
	copy.mapID = copy.mapID or copy.challengeModeID
	if copy.keyState ~= "ready" and copy.keyState ~= "empty" and copy.keyState ~= "unknown" then
		copy.keyState = tonumber(copy.challengeModeID) and tonumber(copy.keyLevel) and "ready" or "empty"
	end
	Util.NormalizeSpecialization(copy)
	return copy
end

local function addEntry(entries, seen, character, source, roleContext)
	if not (character and character.carpoolEnabled == true) then
		return
	end
	local characterKey = canonical(character.fullName or character.key or character.name)
	local ownerKey = canonical(source.ownerKey or source.ownerName)
	if not (characterKey and ownerKey) then
		return
	end
	local identity = ownerKey .. "\031" .. characterKey
	if seen[identity] then
		return
	end
	seen[identity] = true
	local entry = copyCharacter(character)
	entry.roles, entry.role, entry.roleSource = resolveDisplayRoles(
		character, roleContext.rosterMembers, roleContext.applicantRoles)
	entry.ownerKey = source.ownerKey
	entry.ownerName = source.ownerName
	entry.ownerClass = source.ownerClass
	entry.owner = source.ownerKey
	entry.warbandSourceName = source.ownerName
	entry.warbandSourceClass = source.ownerClass
	entry.sourceName = source.ownerName
	entry.sourceClass = source.ownerClass
	entry.sourceLocal = source.localSource == true
	-- Keep the supplying owner's active character separate from the local-player
	-- marker: every owner current row uses the normal visual state and leads its
	-- own source group in both directions of the warband-column sort; only the
	-- player is local-current.
	entry.isOwnerCurrent = characterKey == ownerKey
		or (source.localSource ~= true and character.isCurrent == true)
	entry.isLocalCurrent = source.localSource == true
		and entry.isOwnerCurrent == true
	entry.source = source.localSource and "local-warband" or "group-snapshot"
	entry.warbandTag = nil
	entry.isCarpoolEntry = true
	entry.elementKey = identity
	entries[#entries + 1] = entry
end

function View:AddListener(callback)
	Util.AddListener(self, callback)
end

function View:GetCharacters()
	local entries = {}
	local seen = {}
	local rosterMembers = collectRosterMembers()
	local roleContext = {
		rosterMembers = rosterMembers,
		applicantRoles = collectApplicantRoleLookup(),
	}
	local store = GF.MythicPlusCharacterStore
	local playerFullName, playerName = Util.GetUnitFullName("player")
	local playerClass
	if UnitClass then
		playerClass = select(2, UnitClass("player"))
	end
	local localSource = {
		ownerKey = playerFullName,
		ownerName = playerName,
		ownerClass = playerClass,
		localSource = true,
	}
	-- Carpool is the opted-in character view, independent from Party membership.
	-- Keep active current characters here; addEntry already deduplicates repeated
	-- records by the supplying owner plus character identity.
	for _, character in ipairs(store and store.GetCarpoolCharacters and store:GetCarpoolCharacters() or {}) do
		addEntry(entries, seen, character, localSource, roleContext)
	end
	local debugService = GF.MythicPlusDebugService
	for _, character in ipairs(debugService and debugService.GetLocalCharacters
		and debugService:GetLocalCharacters() or {})
	do
		if character.carpoolEnabled == true then
			addEntry(entries, seen, character, localSource, roleContext)
		end
	end

	local service = GF.MythicPlusGroupSnapshotService
	for _, snapshot in ipairs(service and service.GetOwnerSnapshots and service:GetOwnerSnapshots() or {}) do
		local remoteSource = buildRemoteSource(snapshot, rosterMembers)
		for _, character in ipairs(snapshot.characters or {}) do
			addEntry(entries, seen, character, remoteSource, roleContext)
		end
	end
	for _, snapshot in ipairs(debugService and debugService.GetCarpoolGroups
		and debugService:GetCarpoolGroups() or {})
	do
		local debugSource = buildRemoteSource(snapshot, rosterMembers)
		for _, character in ipairs(snapshot.characters or {}) do
			addEntry(entries, seen, character, debugSource, roleContext)
		end
	end
	if GF.MythicPlusRosterSort and GF.MythicPlusRosterSort.Sort then
		return GF.MythicPlusRosterSort:Sort("carpool", entries)
	end
	return entries
end

function View:RequestRefresh(reason)
	if GF.MythicPlusGroupSnapshotService and GF.MythicPlusGroupSnapshotService.RequestSync then
		GF.MythicPlusGroupSnapshotService:RequestSync(reason or "carpool")
	end
	self.updatedAt = Util.Now()
	Util.Notify(self, reason or "refresh")
end

function View:OnApplicantRolesChanged(reason)
	self.updatedAt = Util.Now()
	Util.Notify(self, reason or "applicant-roles")
end

function View:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	local function changed(_, reason)
		self.updatedAt = Util.Now()
		Util.Notify(self, reason or "data")
	end
	if GF.MythicPlusCharacterStore and GF.MythicPlusCharacterStore.AddListener then
		GF.MythicPlusCharacterStore:AddListener(changed)
	end
	if GF.MythicPlusGroupSnapshotService and GF.MythicPlusGroupSnapshotService.AddListener then
		GF.MythicPlusGroupSnapshotService:AddListener(changed)
	end
	if GF.MythicPlusRosterCache and GF.MythicPlusRosterCache.AddListener then
		GF.MythicPlusRosterCache:AddListener(changed)
	end
end
