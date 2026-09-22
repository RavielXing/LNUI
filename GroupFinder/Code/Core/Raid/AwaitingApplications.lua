local _, GF = ...

-- A projection of native applications, independent of browse filters and the
-- addon's published seeking record. No search or application is issued here.
local View = { previous = {} }
GF.RaidAwaitingApplications = View
local Snapshot = GF.SearchResultSnapshot

local function field(owner, key) return Snapshot.ReadField(owner, key) end
local function number(owner, key)
	local value = Snapshot.ToNumber(field(owner, key))
	return value and value >= 0 and value < math.huge and value == math.floor(value) and value or nil
end
local function plain(owner, key)
	local value = field(owner, key)
	return type(value) == "string" and value ~= "" and value or nil
end
local function copy(source)
	local value = {}
	for key, item in pairs(source) do value[key] = item end
	return value
end
local function waiting(state)
	if not state.known then return false end
	local status, pending = state.appStatus, state.pendingStatus
	if status == "invited" or status == "inviteaccepted" or pending == "invited" or pending == "inviteaccepted" then return false end
	return status == "applied" or pending == "applied"
end
local function sameApplication(entry, state)
	return entry and entry.identity.generation == state.generation
		and (not entry.identity.partyGUID or not state.partyGUID or entry.identity.partyGUID == state.partyGUID)
end

function View:ReadDetails(id, info, activities)
	local activityID = Snapshot.GetPrimaryActivityID(info)
	local activity = Snapshot.GetActivityInfo(info, activityID)
	local category = number(activity, "categoryID")
	if not category then return nil, false end
	if category ~= (GF.CAT_RAID or 3) then return nil, true end
	local catalog
	for _, item in ipairs(activities or {}) do if item.id == activityID then catalog = item; break end end
	local difficultyID = number(activity, "difficultyID")
	local difficulty
	if difficultyID and type(GetDifficultyInfo) == "function" then
		local ok, name = pcall(GetDifficultyInfo, difficultyID)
		if ok then difficulty = plain({ value = name }, "value") end
	end
	local counts = Snapshot.GetMemberCounts(id)
	local completed = Snapshot.GetCompletedEncounters(id)
	local total
	if GF.Result and GF.Result.GetRaidProgress then
		-- Only borrow the encounter catalog. Kills come from this live native
		-- result, never the browsing repository's result-ID progress cache.
		local ignored
		ignored, total = GF.Result:GetRaidProgress(nil, info, activity)
	end
	local killed = completed and #completed or nil
	if total and killed and killed > total then killed = nil end
	return {
		resultID = id, activityID = activityID,
		name = catalog and catalog.instanceName,
		fullName = plain(activity, "fullName"),
		difficulty = difficulty or plain(activity, "shortName"),
		texture = catalog and catalog.texture, texCoords = catalog and catalog.texCoords,
		teamName = plain(info, "name"), leaderName = plain(info, "leaderName"),
		numMembers = number(info, "numMembers"),
		counts = { number(counts, "TANK"), number(counts, "HEALER"), number(counts, "DAMAGER") },
		killed = killed, total = total,
	}, true
end

function View:GetEntries(activities)
	local apps, entries, nextPrevious = GF.ApplicationService, {}, {}
	local ids = apps:ReadApplicationIDs()
	if not ids then
		for _, old in pairs(self.previous) do
			local entry = copy(old)
			entry.stale, entry.canCancel = true, false
			entries[#entries + 1] = entry
		end
		table.sort(entries, function(a, b) return a.resultID < b.resultID end)
		return entries, false
	end
	local complete, seen = true, {}
	for _, id in ipairs(ids) do
		if not seen[id] then
			seen[id] = true
			local state, old = apps:ReadApplicationSnapshot(id), self.previous[id]
			local entry, detailsKnown
			if waiting(state) and not apps:IsCurrentGroupResult(id) then
				local info = apps:GetNativeResultInfo(id)
				if info then entry, detailsKnown = self:ReadDetails(id, info, activities) end
				if not detailsKnown and sameApplication(old, state) then entry = copy(old); entry.stale = true end
				if not detailsKnown then complete = false end
				if entry then
					entry.identity = { resultID = id, generation = state.generation, partyGUID = state.partyGUID }
					entry.expiration = state.appExpiration
					entry.actionState = apps:GetApplicationActionState(id, state)
					entry.canCancel, entry.cancelReason = apps:GetCancelAvailability(id, state)
					entry.canCancel = entry.canCancel and not entry.stale and state.partyGUID ~= nil
				end
			elseif not state.known then
				complete = false
				if old then entry = copy(old); entry.stale, entry.canCancel = true, false end
			end
			if entry then nextPrevious[id] = entry; entries[#entries + 1] = entry end
		end
	end
	self.previous = nextPrevious
	-- Stable ordering when the native list changes order; do not merge teams.
	table.sort(entries, function(a, b) return a.resultID < b.resultID end)
	return entries, complete
end

function View:Cancel(entry)
	if not entry or not entry.canCancel then return false, (GF.L or {}).APP_STATE_WAITING_UPDATE end
	return GF.ApplicationService:CancelApplication(entry.resultID, nil, entry.identity)
end

function View:GetTooltipSource(entry)
	if not entry or entry.stale or not entry.identity or not entry.identity.partyGUID then return nil end
	local apps, id = GF.ApplicationService, entry.resultID
	local state = apps:ReadApplicationSnapshot(id)
	if not waiting(state) or not sameApplication(entry, state) then return nil end
	local present = false
	for _, value in ipairs(apps:ReadApplicationIDs() or {}) do if value == id then present = true; break end end
	if not present then return nil end
	local info = apps:GetNativeResultInfo(id)
	if not info or apps:GetResultPartyGUID(info) ~= entry.identity.partyGUID then return nil end
	local activity = Snapshot.GetActivityInfo(info, Snapshot.GetPrimaryActivityID(info))
	if number(activity, "categoryID") ~= (GF.CAT_RAID or 3) then return nil end
	return { resultID = id, info = info, activity = activity }
end
