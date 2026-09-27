local _, GF = ...

-- ResultRepository owns the mutable lifetime of browse-result identities and
-- payload projections.  A resultID is stable only inside the current source
-- revision; callers that need cross-search identity must use partyGUID (or an
-- explicit retained application/current-group record) before publishing the
-- next revision.
local Repository = {}
GF.ResultRepository = Repository

local STATE_KEYS = {
	apiFilteredTotal = true,
	apiResultIDs = true,
	entryCache = true,
	frozenOrder = true,
	frozenSet = true,
	rawTotal = true,
	resultIDs = true,
	sortInfoCache = true,
	total = true,
	_aggregateInfoByID = true,
	_aggregateMemberCountsByID = true,
	_cacheSig = true,
	_frozenOrderBufferIndex = true,
	_frozenOrderBuffers = true,
	_frozenSetBuffer = true,
	_pruneRetainedBuffer = true,
	_refreshIDBufferIndex = true,
	_refreshIDBuffers = true,
	_refreshInfoByID = true,
	_refreshMemberCountsByID = true,
	_raidProgressByID = true,
	_raidEncounterTotals = true,
	_usingAggregatedResults = true,
}
local CENSORED_CONTENT_FIELDS = { "name", "comment", "voiceChat" }

local function clearReusableTable(values)
	values = type(values) == "table" and values or {}
	for key in pairs(values) do
		values[key] = nil
	end
	return values
end

local function acquireSequenceBuffer(
	owner, buffersKey, indexKey, avoidFirst, avoidSecond)
	local buffers = owner[buffersKey]
	if type(buffers) ~= "table" then
		buffers = { {}, {} }
		owner[buffersKey] = buffers
	end
	local index = owner[indexKey] == 1 and 2 or 1
	local buffer = buffers[index]
	if buffer == avoidFirst or buffer == avoidSecond then
		index = index == 1 and 2 or 1
		buffer = buffers[index]
	end
	if buffer == avoidFirst or buffer == avoidSecond then
		buffer = {}
		buffers[index] = buffer
	end
	owner[indexKey] = index
	return clearReusableTable(buffer)
end

local function snapshotService()
	return GF.SearchResultSnapshot
end

local function sanitize(info)
	local snapshot = snapshotService()
	if snapshot and snapshot.SanitizeCensoredContent then
		return snapshot.SanitizeCensoredContent(info)
	end
	return info
end

local function isCensored(info)
	local snapshot = snapshotService()
	return snapshot and snapshot.IsCensored
		and snapshot.IsCensored(info) == true
end

local function diagnostics()
	return GF.SearchMemoryDiagnostics
end

local function rebuildIndex(owner)
	local indexByID = clearReusableTable(owner._resultIndexByID)
	owner._resultIndexByID = indexByID
	for index, resultID in ipairs(owner.resultIDs or {}) do
		if indexByID[resultID] == nil then
			indexByID[resultID] = index
		end
	end
	return indexByID
end

function Repository:OwnsStateKey(key)
	return STATE_KEYS[key] == true
end

function Repository:SetProjectedOrder(order)
	self.resultIDs = type(order) == "table" and order or {}
	self.total = #self.resultIDs
	rebuildIndex(self)
	return self.resultIDs
end

function Repository:SetSourceOrder(order)
	self.apiResultIDs = type(order) == "table" and order or nil
	return self.apiResultIDs
end

function Repository:SetFacadeState(key, value)
	if key == "resultIDs" then
		self:SetProjectedOrder(value)
	elseif key == "apiResultIDs" then
		self:SetSourceOrder(value)
	else
		rawset(self, key, value)
	end
end

-- Result remains the public compatibility facade.  Legacy callers can keep
-- reading its fields, but writes and reads resolve to this one repository
-- rather than creating a second cache graph on the facade table.
function Repository:AttachFacade(facade)
	if type(facade) ~= "table" then
		return nil
	end
	local current = getmetatable(facade)
	if current and current._gfResultRepository == self then
		return facade
	end
	for key in pairs(STATE_KEYS) do
		local value = rawget(facade, key)
		if value ~= nil then
			self:SetFacadeState(key, value)
			rawset(facade, key, nil)
		end
	end
	local previousIndex = current and current.__index
	local previousNewIndex = current and current.__newindex
	local facadeMeta = {}
	if current then
		for key, value in pairs(current) do
			facadeMeta[key] = value
		end
	end
	facadeMeta._gfResultRepository = self
	facadeMeta.__index = function(target, key)
		if STATE_KEYS[key] then
			return self[key]
		end
		if type(previousIndex) == "function" then
			return previousIndex(target, key)
		elseif type(previousIndex) == "table" then
			return previousIndex[key]
		end
		return nil
	end
	facadeMeta.__newindex = function(target, key, value)
		if STATE_KEYS[key] then
			self:SetFacadeState(key, value)
		elseif type(previousNewIndex) == "function" then
			previousNewIndex(target, key, value)
		elseif type(previousNewIndex) == "table" then
			previousNewIndex[key] = value
		else
			rawset(target, key, value)
		end
	end
	setmetatable(facade, facadeMeta)
	return facade
end

function Repository:GetSourceRevision()
	return tonumber(self._sourceRevision) or 0
end

function Repository:BeginSource(options)
	options = options or {}
	self._sourceRevision = self:GetSourceRevision() + 1
	self.apiFilteredTotal = tonumber(options.apiFilteredTotal) or 0
	self.rawTotal = tonumber(options.rawTotal) or 0
	self.total = 0
	self._cacheSig = options.cacheSignature
	self.entryCache = {}
	self.sortInfoCache = {}
	self._refreshInfoByID = {}
	self._refreshMemberCountsByID = {}
	self._raidProgressByID = {}
	self._raidEncounterTotals = {}
	self.apiResultIDs = nil
	self:SetProjectedOrder({})
	return self._sourceRevision
end

function Repository:PublishSource(ids)
	self:SetSourceOrder(ids)
	self:SetProjectedOrder(ids)
	return self.resultIDs
end

function Repository:SetAggregateSource(usingAggregate, infoByID, countsByID)
	self._usingAggregatedResults = usingAggregate == true
	self._aggregateInfoByID = infoByID
	self._aggregateMemberCountsByID = countsByID
end

function Repository:EndRefresh()
	self._refreshInfoByID = nil
	self._refreshMemberCountsByID = nil
end

function Repository:GetIndexForResultID(resultID)
	if type(resultID) ~= "number" then
		return nil
	end
	local index = self._resultIndexByID and self._resultIndexByID[resultID]
	if index and self.resultIDs and self.resultIDs[index] == resultID then
		return index
	end
	index = rebuildIndex(self)[resultID]
	return index
end

function Repository:Contains(resultID)
	return self:GetIndexForResultID(resultID) ~= nil
end

function Repository:GetEntry(resultID)
	return resultID and self.entryCache and self.entryCache[resultID] or nil
end

function Repository:RememberEntry(resultID, entry)
	if not resultID then
		return nil
	end
	self.entryCache = self.entryCache or {}
	self.entryCache[resultID] = entry
	return entry
end

-- Invalidating a projection intentionally leaves aggregate/refresh payloads
-- alone: those maps describe the authoritative source and may still be needed
-- by the same refresh.  Removing membership is a separate operation below.
function Repository:RemoveCachedRecord(resultID)
	if self._raidProgressByID then self._raidProgressByID[resultID] = nil end
	if self.entryCache then
		self.entryCache[resultID] = nil
	end
	if self.sortInfoCache then
		self.sortInfoCache[resultID] = nil
	end
end

function Repository:ScrubCensoredResult(resultID)
	local function scrub(info)
		if type(info) == "table" then
			pcall(rawset, info, "censored", true)
			for _, key in ipairs(CENSORED_CONTENT_FIELDS) do
				pcall(rawset, info, key, nil)
			end
			sanitize(info)
		end
	end
	scrub(self.entryCache and self.entryCache[resultID]
		and self.entryCache[resultID].info)
	scrub(self.sortInfoCache and self.sortInfoCache[resultID])
	scrub(self._aggregateInfoByID and self._aggregateInfoByID[resultID])
	scrub(self._refreshInfoByID and self._refreshInfoByID[resultID])
end

function Repository:RememberSummary(resultID, info)
	info = sanitize(info)
	if not (resultID and info) then
		return nil
	end
	if isCensored(info) then
		self:ScrubCensoredResult(resultID)
	end
	self.sortInfoCache = self.sortInfoCache or {}
	local snapshot = snapshotService()
	if self._refreshInfoByID
		and self._usingAggregatedResults ~= true
		and not (snapshot and snapshot.IsCompactSearchResultInfo
			and snapshot.IsCompactSearchResultInfo(info))
	then
		-- A full native result table carries the listing's complete dungeon-score
		-- collection and every activity record.  Holding it here (plus the compact
		-- copy below) until EndRefresh keeps one full table per result alive during
		-- the whole filter+sort window -- the dominant memory spike on large
		-- searches.  Keep only a compact projection with tooltip details; full
		-- records are still available on demand from the live native store.
		local projection = info
		if snapshot and type(snapshot.CompactSearchResultInfo) == "function" then
			projection = snapshot.CompactSearchResultInfo(info, true)
		end
		self._refreshInfoByID[resultID] = projection
	end
	local summary = info
	if self._usingAggregatedResults ~= true
		and snapshot and snapshot.CompactSearchResultInfo
	then
		summary = snapshot.CompactSearchResultInfo(info)
		local memory = diagnostics()
		if summary ~= info and memory and memory.current then
			memory:Add("summariesCompacted", 1)
		end
	end
	self.sortInfoCache[resultID] = sanitize(summary)
	return self.sortInfoCache[resultID]
end

function Repository:GetCachedInfo(resultID)
	if not resultID then
		return nil
	end
	local entry = self:GetEntry(resultID)
	if entry and entry.info then
		return sanitize(entry.info)
	end
	local summary = self.sortInfoCache and self.sortInfoCache[resultID]
	if summary then
		return sanitize(summary)
	end
	return sanitize(self._aggregateInfoByID
		and self._aggregateInfoByID[resultID] or nil)
end

function Repository:PruneSummaries()
	if not (self.sortInfoCache and self.resultIDs) then
		return
	end
	local retained = clearReusableTable(self._pruneRetainedBuffer)
	self._pruneRetainedBuffer = retained
	for _, resultID in ipairs(self.resultIDs) do
		retained[resultID] = true
	end
	for resultID in pairs(self.sortInfoCache) do
		if not retained[resultID] then
			self.sortInfoCache[resultID] = nil
		end
	end
	-- Membership is needed only while pruning. Keeping its resultID keys until
	-- the next search makes a completed pass look retained even though the
	-- authoritative caches have already released those rows.
	clearReusableTable(retained)
end

function Repository:CommitFrozenSnapshot()
	local order = self.resultIDs or {}
	local frozenOrder = acquireSequenceBuffer(
		self,
		"_frozenOrderBuffers",
		"_frozenOrderBufferIndex",
		order
	)
	local frozenSet = clearReusableTable(self._frozenSetBuffer)
	for position, resultID in ipairs(order) do
		frozenOrder[position] = resultID
		frozenSet[resultID] = true
	end
	self._frozenSetBuffer = frozenSet
	self.frozenOrder = frozenOrder
	self.frozenSet = frozenSet
	return frozenOrder
end

function Repository:ClearFrozenSnapshot()
	self.frozenOrder = nil
	self.frozenSet = nil
end

function Repository:IsFrozenResult(resultID)
	return resultID ~= nil
		and self.frozenSet ~= nil
		and self.frozenSet[resultID] == true
end

function Repository:RemoveFromFrozen(resultID)
	if not self:IsFrozenResult(resultID) then
		return false
	end
	self.frozenSet[resultID] = nil
	local retained = {}
	for _, candidate in ipairs(self.frozenOrder or self.resultIDs or {}) do
		if candidate ~= resultID then
			retained[#retained + 1] = candidate
		end
	end
	self.frozenOrder = retained
	self:SetProjectedOrder(retained)
	self:RemoveCachedRecord(resultID)
	return true
end

function Repository:RemoveProjectedResult(resultID)
	if resultID == nil then
		return false
	end
	local present = self:IsFrozenResult(resultID) or self:Contains(resultID)
	if not present then
		return false
	end
	if self.frozenSet then
		self.frozenSet[resultID] = nil
	end
	local function retainOthers(source)
		local retained = {}
		for _, candidate in ipairs(source or {}) do
			if candidate ~= resultID then
				retained[#retained + 1] = candidate
			end
		end
		return retained
	end
	self:SetProjectedOrder(retainOthers(self.resultIDs))
	if self.frozenOrder then
		self.frozenOrder = retainOthers(self.frozenOrder)
	end
	self:RemoveCachedRecord(resultID)
	return true
end

function Repository:Reset(options)
	options = options or {}
	self._sourceRevision = self:GetSourceRevision() + 1
	self.total, self.rawTotal, self.apiFilteredTotal = 0, 0, 0
	self.apiResultIDs = nil
	self:SetProjectedOrder({})
	self.entryCache = {}
	self._raidProgressByID = {}
	self._raidEncounterTotals = {}
	if options.preserveSummaries ~= true then
		self.sortInfoCache = {}
	end
	self:ClearFrozenSnapshot()
	self._usingAggregatedResults = nil
	self._aggregateInfoByID = nil
	self._aggregateMemberCountsByID = nil
	self:EndRefresh()
	self._cacheSig = nil
end

-- Explicit aliases make the lifecycle vocabulary clear to Result without
-- changing the long-standing facade method names consumed by the UI.
function Repository:Clear()
	self:Reset()
end

function Repository:DiscardSource()
	self:Reset({ preserveSummaries = true })
end

Repository.total = 0
Repository.rawTotal = 0
Repository.apiFilteredTotal = 0
