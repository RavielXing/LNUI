local _, GF = ...

GF.Search = GF.Search or {}
local Search = GF.Search
local NativeSearch = GF.NativeSearchGateway

local function currentTime()
	if type(GetTime) ~= "function" then
		return nil
	end
	local ok, value = pcall(GetTime)
	return ok and tonumber(value) or nil
end

local function hasKeywordSearch()
	local hasKeyword = false
	if GF.FindGroupTab and GF.FindGroupTab.GetBrowseSearchState then
		hasKeyword = GF.FindGroupTab:GetBrowseSearchState()
	end
	return hasKeyword == true
end

local function readCurrentResultIDs()
	if not (NativeSearch and NativeSearch.ReadResults) then
		return 0, {}, false
	end
	return NativeSearch:ReadResults(hasKeywordSearch())
end

local function normalizeScope(selection, scope)
	if not scope then
		return nil
	end
	local categoryID = scope.categoryID or (selection and selection.categoryID)
	if not categoryID then
		return nil
	end
	local preferredFilters = scope.preferredFilters
		or (selection and selection.preferredFilters)
		or Enum.LFGListFilter.PvE
	local activityID = scope.activityID or (selection and selection.activityID)
	local activityIDsFilter = scope.activityIDsFilter
	local questID
	if selection and selection._gfQuestSearch == true then
		local rawQuestID = scope.questID or selection.questID
		questID = GF.QuestSearch and GF.QuestSearch.NormalizeQuestID
			and GF.QuestSearch:NormalizeQuestID(rawQuestID) or nil
	end
	if not activityIDsFilter and not scope.resultActivityIDsFilter
		and activityID and not scope.categoryBrowse
		and not (selection and selection.categoryBrowse)
	then
		activityIDsFilter = { activityID }
	end

	local leaderLookup = GF.RaidLeaderLookup and GF.RaidLeaderLookup:GetTarget(selection)
	local baseFilters = leaderLookup and 0 or scope.filters or (selection and selection.filters) or 0
	local archiveAggregateSearch = scope.archiveAggregateSearch == true
	local filters = baseFilters
	-- Archive root/expansion aggregation deliberately submits filter 0 so the
	-- one native result store contains historical listings.  Its compiler has
	-- already chosen that native boundary; applying the ordinary category policy
	-- here would silently narrow it back to Recommended.
	if not archiveAggregateSearch and not leaderLookup
		and GF.Filter and GF.Filter.ResolveCategoryFilters
	then
		filters = GF.Filter:ResolveCategoryFilters(categoryID, baseFilters)
	end
	if not leaderLookup and GF.Filter and GF.Filter.ResolvePreferredFilters then
		preferredFilters = GF.Filter:ResolvePreferredFilters(
			categoryID, preferredFilters)
	end

	return {
		categoryID = categoryID,
		filters = filters,
		preferredFilters = preferredFilters,
		activityIDsFilter = activityIDsFilter,
		resultActivityIDsFilter = scope.resultActivityIDsFilter,
		navKind = scope.navKind or (selection and selection.navKind),
		questID = questID,
		archiveAggregateSearch = archiveAggregateSearch,
	}
end

local function mergeIDsInto(target, seen, ids)
	if not target or not seen or not ids then
		return
	end
	for _, id in ipairs(ids) do
		if id and not seen[id] then
			seen[id] = true
			target[#target + 1] = id
		end
	end
end

local function combineFilterFlags(left, right)
	left = tonumber(left) or 0
	right = tonumber(right) or 0
	if bit and type(bit.band) == "function" then
		return bit.band(left, right)
	end
	if left == right then
		return left
	end
	return 0
end

local function mergeNormalizedScopes(scopes, finalForNative)
	local merged = {}
	local order = {}
	for _, scope in ipairs(scopes or {}) do
		if scope and scope.categoryID then
			local hasNativeIDs = scope.activityIDsFilter
				and #scope.activityIDsFilter > 0
			local hasResultIDs = scope.resultActivityIDsFilter
				and #scope.resultActivityIDsFilter > 0
			local exact = hasNativeIDs or hasResultIDs
			local key = table.concat({
				tostring(scope.categoryID),
				tostring(scope.preferredFilters or 0),
				tostring(scope.questID or ""),
				exact and "exact" or ("broad:" .. tostring(scope.filters or 0)),
			}, ":")
			local output = merged[key]
			if not output then
				output = {
					categoryID = scope.categoryID,
					filters = scope.filters or 0,
					preferredFilters = scope.preferredFilters,
					navKind = scope.navKind,
					questID = scope.questID,
					archiveAggregateSearch =
						scope.archiveAggregateSearch == true,
					_exact = exact,
					_combinedFilters = nil,
					_activityIDs = exact and {} or nil,
					_seenActivityIDs = exact and {} or nil,
				}
				merged[key] = output
				order[#order + 1] = key
			end
			if scope.archiveAggregateSearch == true then
				output.archiveAggregateSearch = true
			end
			if exact then
				if output._combinedFilters == nil then
					output._combinedFilters = tonumber(scope.filters) or 0
				else
					-- Exact children can belong to mutually exclusive native
					-- partitions (for example Recommended/NotRecommended).  A
					-- category-level aggregate may keep only constraints shared
					-- by every child; OR-ing those flags can make the request
					-- impossible and return an empty native result store.
					output._combinedFilters = combineFilterFlags(
						output._combinedFilters, scope.filters)
				end
			end
			if exact then
				mergeIDsInto(
					output._activityIDs,
					output._seenActivityIDs,
					scope.activityIDsFilter
				)
				mergeIDsInto(
					output._activityIDs,
					output._seenActivityIDs,
					scope.resultActivityIDsFilter
				)
			end
		end
	end

	local result = {}
	for _, key in ipairs(order) do
		local scope = merged[key]
		if scope._exact then
			scope.filters = scope._combinedFilters or scope.filters or 0
			if #scope._activityIDs == 1 then
				-- A single activity is a reliable native exact search and needs no
				-- second membership check against protected result fields.
				scope.activityIDsFilter = scope._activityIDs
				scope.resultActivityIDsFilter = nil
			else
				-- Retail does not reliably treat a multi-ID seventh argument as an
				-- OR-union. Aggregate once at category level, then project the one
				-- native result store locally.
				--
				-- Only clear the native category partition at the final submission
				-- boundary. Workspace policy can still narrow this intermediate
				-- aggregate to one exact activity, which must retain its own filter.
				if finalForNative == true then
					scope.filters = 0
				end
				scope.activityIDsFilter = nil
				scope.resultActivityIDsFilter = scope._activityIDs
			end
		end
		scope._exact = nil
		scope._combinedFilters = nil
		scope._activityIDs = nil
		scope._seenActivityIDs = nil
		result[#result + 1] = scope
	end
	return result
end

local function clearAggregate(owner)
	owner.aggregate = nil
	owner.aggregateResultIDs = nil
	owner.aggregateTotal = nil
	owner.aggregateInfoByID = nil
	owner.aggregateMemberCountsByID = nil
end

function Search:_SetSession(session)
	self.session = session
	self.context = session and session.context or nil
	self.pending = session and session.aggregation or nil
	self.inFlight = session and session.state == "searching" or false
end

function Search:_CompleteSession()
	local session = self.session
	if session then
		session.state = "complete"
		session.completedAt = currentTime()
		session.aggregation = nil
	end
	self.pending = nil
	self.inFlight = false
end

function Search:Reset()
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.AbortSearch then
		GF.SearchMemoryDiagnostics:AbortSearch("reset")
	end
	self:_SetSession(nil)
	clearAggregate(self)
end

function Search:GetRequestBarrierRemaining()
	local expiresAt = tonumber(self.abandonedUntil)
	if not expiresAt then
		self.barrier = nil
		return 0
	end
	local now = currentTime()
	if not now then
		return 0
	end
	local remaining = expiresAt - now
	if remaining <= 0 then
		self.abandonedUntil = nil
		self.abandonedContext = nil
		self.barrier = nil
		return 0
	end
	return remaining
end

function Search:GetCooldownRemaining()
	local startedAt = tonumber(self.lastNativeSearchAt)
	local now = currentTime()
	if not startedAt or not now then
		if not startedAt then
			self.cooldown = nil
		end
		return 0
	end
	local duration = GF.SEARCH_COOLDOWN or 3
	local remaining = duration - (now - startedAt)
	if remaining <= 0 then
		return 0
	end
	return remaining
end

function Search:_RecordNativeSearchStart()
	local startedAt = currentTime()
	if not startedAt then
		return
	end
	self.lastNativeSearchAt = startedAt
	self.cooldown = {
		startedAt = startedAt,
		duration = GF.SEARCH_COOLDOWN or 3,
	}
	if self.session then
		self.session.startedAt = startedAt
	end
end

function Search:AbandonActiveRequest()
	local session = self.session
	local wasInFlight = self.inFlight == true
		or (session and session.state == "searching")
	local now = currentTime()
	if wasInFlight and now then
		local expiresAt = now + (GF.SEARCH_TIMEOUT_SECONDS or 8)
		self.abandonedUntil = expiresAt
		self.abandonedContext = self.context
		self.barrier = {
			expiresAt = expiresAt,
			context = self.context,
			sessionID = session and session.id or nil,
		}
	end
	self:Reset()
	return wasInFlight == true
end

function Search:ConsumeAbandonedEvent()
	if self:GetRequestBarrierRemaining() <= 0 then
		return false
	end
	self.abandonedUntil = nil
	self.abandonedContext = nil
	self.barrier = nil
	return true
end

function Search:ClearAggregatedResultIDs()
	clearAggregate(self)
end

function Search:GetAggregatedResultIDs()
	return self.aggregateResultIDs,
		self.aggregateTotal,
		self.aggregateInfoByID,
		self.aggregateMemberCountsByID
end

function Search:IsAggregatedResultIdentityPending(resultID)
	local aggregate = self.aggregate
	local unknown = aggregate and aggregate.unknownActivityResultIDs
	return resultID ~= nil and unknown and unknown[resultID] == true or false
end

local function importCompatibleQuestState(owner)
	if NativeSearch and NativeSearch.SetActiveQuestID then
		NativeSearch:SetActiveQuestID(owner.nativeQuestSearchActive)
	end
end

local function exportCompatibleQuestState(owner)
	if NativeSearch and NativeSearch.GetActiveQuestID then
		owner.nativeQuestSearchActive = NativeSearch:GetActiveQuestID()
	else
		owner.nativeQuestSearchActive = nil
	end
end

function Search:ReleaseNativeSearchSelection()
	return NativeSearch and NativeSearch.ReleaseSearchSelection
		and NativeSearch:ReleaseSearchSelection() or false
end

function Search:BuildScopes(selection, context)
	local rawScopes
	if GF.NavData and GF.NavData.ResolveSearchScopes then
		rawScopes = GF.NavData.ResolveSearchScopes(selection, { forSearch = true })
	elseif selection and GF.NavData and GF.NavData.ResolveSearchScope then
		rawScopes = {
			GF.NavData.ResolveSearchScope(selection, { forSearch = true }),
		}
	elseif selection then
		rawScopes = { selection }
	else
		rawScopes = {}
	end

	local scopes = {}
	for _, scope in ipairs(rawScopes or {}) do
		local normalized = normalizeScope(selection, scope)
		if normalized then
			scopes[#scopes + 1] = normalized
		end
	end
	scopes = mergeNormalizedScopes(scopes)
	if GF.LFGWorkspacePolicy and GF.LFGWorkspacePolicy.ConstrainSearchScopes then
		scopes = GF.LFGWorkspacePolicy:ConstrainSearchScopes(
			context and context.workspaceID,
			selection,
			scopes
		)
	end
	-- Workspace policy may replace a scope's activity range. Normalize that
	-- final range through the same single-ID versus aggregate boundary.
	return mergeNormalizedScopes(scopes, true)
end

function Search:ClearNativeQuestSearch()
	if self.nativeQuestSearchActive == nil then
		if NativeSearch and NativeSearch.SetActiveQuestID then
			NativeSearch:SetActiveQuestID(nil)
		end
		return true
	end
	if not (NativeSearch and NativeSearch.ClearQuestSearch) then
		return false
	end
	importCompatibleQuestState(self)
	local cleared = NativeSearch:ClearQuestSearch()
	exportCompatibleQuestState(self)
	return cleared == true
end

function Search:SuspendNativeQuestSearch()
	if self.nativeQuestSearchActive == nil then
		if NativeSearch and NativeSearch.SetActiveQuestID then
			NativeSearch:SetActiveQuestID(nil)
		end
		return true
	end
	if not (NativeSearch and NativeSearch.SuspendQuestSearch) then
		return false
	end
	importCompatibleQuestState(self)
	local suspended = NativeSearch:SuspendQuestSearch()
	exportCompatibleQuestState(self)
	return suspended == true
end

function Search:ReleaseNativeQuestSearchForKeyword()
	if self.nativeQuestSearchActive == nil then
		if NativeSearch and NativeSearch.SetActiveQuestID then
			NativeSearch:SetActiveQuestID(nil)
		end
		return true
	end
	if not (NativeSearch and NativeSearch.ReleaseQuestSearchForKeyword) then
		return false
	end
	importCompatibleQuestState(self)
	local released = NativeSearch:ReleaseQuestSearchForKeyword()
	exportCompatibleQuestState(self)
	return released == true
end

function Search:PrepareNativeQuestSearch(questID)
	questID = GF.QuestSearch and GF.QuestSearch.NormalizeQuestID
		and GF.QuestSearch:NormalizeQuestID(questID) or nil
	if not questID or not (NativeSearch and NativeSearch.PrepareQuestSearch) then
		return false
	end
	importCompatibleQuestState(self)
	local prepared = NativeSearch:PrepareQuestSearch(questID)
	exportCompatibleQuestState(self)
	return prepared == true
end

local function scopeNeedsAggregatedResults(scope)
	return scope and scope.resultActivityIDsFilter
		and #scope.resultActivityIDsFilter > 0
end

function Search:_RunScope(scope)
	if not scope or not scope.categoryID then
		return false
	end
	if GF.Availability and GF.Availability.ShouldProcessLfgEvent
		and not GF.Availability:ShouldProcessLfgEvent()
	then
		return false
	end
	if not (NativeSearch and NativeSearch.StartSearch) then
		return false
	end
	importCompatibleQuestState(self)
	local started = NativeSearch:StartSearch(scope)
	exportCompatibleQuestState(self)
	if started then
		self:_RecordNativeSearchStart()
	end
	return started == true
end

function Search:_RunPendingScope()
	local pending = self.pending
	if not pending then
		return false
	end
	return self:_RunScope(pending.scopes[1])
end

function Search:GetContext()
	return self.context
end

function Search:MatchesContext(context)
	local active = self.context
	if not active or not context then
		return false
	end
	return active.key == context.key
		and active.workspaceID == context.workspaceID
		and tonumber(active.generation) == tonumber(context.generation)
		and tonumber(active.searchToken) == tonumber(context.searchToken)
end

function Search:MarkNativeResultsDirty()
	local session = self.session
	if not (session and session.state == "searching") then
		return false
	end
	session.nativeResultsDirty = true
	return true
end

function Search:_CreateSession(context, scopes, aggregation)
	self._sessionSequence = (tonumber(self._sessionSequence) or 0) + 1
	local sessionID = self._sessionSequence
	return {
		id = sessionID,
		token = context and context.searchToken or sessionID,
		context = context,
		scopes = scopes,
		scope = scopes[1],
		state = "searching",
		aggregation = aggregation,
	}
end

function Search:Run(selection, context)
	if self.inFlight
		or (self.session and self.session.state == "searching")
	then
		self:AbandonActiveRequest()
		return false
	end
	if self:GetRequestBarrierRemaining() > 0
		or self:GetCooldownRemaining() > 0
	then
		return false
	end

	local reusableAggregateInfo = self.aggregateInfoByID
	local needsFreshAggregateInfo = false
	if GF.Result and GF.Result.NeedsFreshSearchResultInfo then
		needsFreshAggregateInfo = GF.Result:NeedsFreshSearchResultInfo()
	elseif GF.Result and GF.Result.NeedsPostFilters then
		needsFreshAggregateInfo = GF.Result:NeedsPostFilters()
	end
	local canReuseAggregateInfo = reusableAggregateInfo ~= nil
		and needsFreshAggregateInfo ~= true

	self:Reset()
	if GF.FindGroup and GF.FindGroup.IsSearchableSelection
		and not GF.FindGroup:IsSearchableSelection(selection)
	then
		return false
	end
	local scopes = self:BuildScopes(selection, context)
	-- Retail has one restricted result store. A second native request cannot be
	-- started by a result event or timer after the user's click chain ends.
	if #scopes ~= 1 then
		return false
	end

	local aggregation
	if scopeNeedsAggregatedResults(scopes[1]) then
		aggregation = {
			scopes = scopes,
			resultIDs = {},
			seen = {},
			infoByID = {},
			memberCountsByID = {},
			reusableInfoByID = canReuseAggregateInfo
				and reusableAggregateInfo or nil,
			total = 0,
		}
	end

	local session = self:_CreateSession(context, scopes, aggregation)
	self:_SetSession(session)
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.BeginSearch then
		GF.SearchMemoryDiagnostics:BeginSearch(#scopes)
	end

	local started
	if aggregation then
		started = self:_RunPendingScope()
	else
		started = self:_RunScope(scopes[1])
	end
	if not started then
		self:Reset()
	elseif GF.QuickSearch and GF.QuickSearch.RecordSearch then
		GF.QuickSearch:RecordSearch(selection)
	end
	return started == true
end

local function resultMatchesActivitySet(info, activitySet)
	if type(info) ~= "table" then
		return nil
	end
	local activityIDs
	local identityComplete = true
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.GetActivityIDs) == "function" then
		local ok, values, complete = pcall(snapshot.GetActivityIDs, info)
		if ok and type(values) == "table" then
			activityIDs = values
			identityComplete = complete ~= false
		end
	else
		local ok, values = pcall(function()
			local ids = {}
			if info.activityID ~= nil then
				ids[#ids + 1] = info.activityID
			end
			if type(info.activityIDs) == "table" then
				for _, activityID in ipairs(info.activityIDs) do
					ids[#ids + 1] = activityID
				end
			end
			return ids
		end)
		if ok then
			activityIDs = values
		end
	end
	if not activityIDs or #activityIDs == 0 then
		-- Result identity can be temporarily absent or secret in 12.1. Unknown
		-- membership must not turn a non-empty native result into an empty list.
		return nil
	end
	for _, activityID in ipairs(activityIDs) do
		local ok, numericActivityID = pcall(tonumber, activityID)
		if ok and numericActivityID
			and activitySet[numericActivityID] == true
		then
			return true
		end
		if not ok then
			identityComplete = false
		end
	end
	if identityComplete then
		return false
	end
	return nil
end

local function buildActivityIDSet(activityIDs)
	if not activityIDs or #activityIDs == 0 then
		return nil
	end
	local set = {}
	for _, activityID in ipairs(activityIDs) do
		local numericActivityID = tonumber(activityID)
		if numericActivityID then
			set[numericActivityID] = true
		end
	end
	return set
end

local function readSearchResultInfo(resultID)
	return NativeSearch and NativeSearch.GetSearchResultInfo
		and NativeSearch:GetSearchResultInfo(resultID) or nil
end

local function getSearchResultInfo(resultID)
	if not resultID or not (NativeSearch
		and NativeSearch.CanReadSearchResultInfo
		and NativeSearch:CanReadSearchResultInfo())
	then
		return nil
	end
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
		GF.SearchMemoryDiagnostics:Add("freshSearchInfo", 1)
	end
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current
		and GF.SearchMemoryDiagnostics.MeasureFirstReturn
	then
		return GF.SearchMemoryDiagnostics:MeasureFirstReturn(
			"freshSearchInfo",
			readSearchResultInfo,
			resultID
		)
	end
	return readSearchResultInfo(resultID)
end

local function compactCapturedInfo(info, resultID)
	if info and GF.ResolveSearchResultSocialCounts then
		GF.ResolveSearchResultSocialCounts(info, resultID)
	end
	local compactedInfo = info
	if info and GF.SearchResultSnapshot
		and GF.SearchResultSnapshot.CompactSearchResultInfo
	then
		compactedInfo = GF.SearchResultSnapshot.CompactSearchResultInfo(info, true)
		if compactedInfo ~= info and GF.SearchMemoryDiagnostics
			and GF.SearchMemoryDiagnostics.current
		then
			GF.SearchMemoryDiagnostics:Add("summariesCompacted", 1)
		end
	end
	if type(compactedInfo) == "table" then
		-- A reused summary may retain identity projections from an older request.
		-- The current native store is authoritative for membership.
		compactedInfo._gfBlocklistPlayers = nil
		compactedInfo._gfBlocklistPlayersComplete = nil
	end
	return compactedInfo
end

local function publishAggregateAliases(owner, aggregate)
	owner.aggregateResultIDs = aggregate and aggregate.resultIDs or nil
	owner.aggregateTotal = aggregate and aggregate.total or nil
	owner.aggregateInfoByID = aggregate and aggregate.infoByID or nil
	owner.aggregateMemberCountsByID = aggregate
		and aggregate.memberCountsByID or nil
end

function Search:OnSearchResults()
	local pending = self.pending
	if not pending then
		if self.aggregate then
			self:ReconcileAggregatedResults()
		end
		self:_CompleteSession()
		return "complete"
	end

	local scope = pending.scopes[1]
	local resultActivitySet = buildActivityIDSet(
		scope and scope.resultActivityIDsFilter)
	pending.activitySet = resultActivitySet
	pending.unknownActivityResultIDs = pending.unknownActivityResultIDs or {}
	local total, resultIDs, readOK = readCurrentResultIDs()
	if readOK == false then
		return "failed"
	end
	local scopeKept, scopeReused = 0, 0
	for _, resultID in ipairs(resultIDs or {}) do
		local info = pending.reusableInfoByID
			and pending.reusableInfoByID[resultID]
		if info then
			scopeReused = scopeReused + 1
		end
		local keep = true
		if resultActivitySet then
			info = info or getSearchResultInfo(resultID)
			local membership = resultMatchesActivitySet(info, resultActivitySet)
			keep = membership ~= false
			if resultID then
				pending.unknownActivityResultIDs[resultID] =
					membership == nil and true or nil
			end
		end
		if keep then
			scopeKept = scopeKept + 1
			if not pending.seen[resultID] then
				pending.seen[resultID] = true
				pending.resultIDs[#pending.resultIDs + 1] = resultID
				pending.total = (pending.total or 0) + 1
			end
			if resultID and NativeSearch:CanReadSearchResultInfo()
				and not pending.infoByID[resultID]
			then
				local capturedInfo = info or getSearchResultInfo(resultID)
				pending.infoByID[resultID] = compactCapturedInfo(
					capturedInfo, resultID)
			elseif resultID and type(pending.infoByID[resultID]) == "table" then
				pending.infoByID[resultID]._gfBlocklistPlayers = nil
				pending.infoByID[resultID]._gfBlocklistPlayersComplete = nil
			end
		end
	end
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.current then
		GF.SearchMemoryDiagnostics:RecordScope(
			total, #resultIDs, scopeKept, scopeReused)
	end

	self.aggregate = {
		resultIDs = pending.resultIDs,
		total = #pending.resultIDs,
		infoByID = pending.infoByID,
		memberCountsByID = pending.memberCountsByID,
		activitySet = pending.activitySet,
		unknownActivityResultIDs = pending.unknownActivityResultIDs,
	}
	publishAggregateAliases(self, self.aggregate)
	local nativeResultsDirty = self.session
		and self.session.nativeResultsDirty == true
	if nativeResultsDirty then
		self:ReconcileAggregatedResults()
	end
	self:_CompleteSession()
	return "complete"
end

local function removeResultID(resultIDs, targetID)
	for index = #(resultIDs or {}), 1, -1 do
		if resultIDs[index] == targetID then
			table.remove(resultIDs, index)
			return true
		end
	end
	return false
end

function Search:RevalidateAggregatedResult(resultID)
	local aggregate = self.aggregate
	local unknown = aggregate and aggregate.unknownActivityResultIDs
	local activitySet = aggregate and aggregate.activitySet
	if not (resultID and unknown and unknown[resultID] and activitySet) then
		return nil
	end
	local info = getSearchResultInfo(resultID)
	local membership = resultMatchesActivitySet(info, activitySet)
	if membership == nil then
		return "unknown"
	end
	unknown[resultID] = nil
	if membership then
		aggregate.infoByID[resultID] = compactCapturedInfo(info, resultID)
		return "matched"
	end
	if not removeResultID(aggregate.resultIDs, resultID) then
		return "resolved"
	end
	aggregate.infoByID[resultID] = nil
	aggregate.memberCountsByID[resultID] = nil
	aggregate.total = #aggregate.resultIDs
	publishAggregateAliases(self, aggregate)
	return "removed"
end

function Search:RevalidateUnknownAggregatedResults()
	local aggregate = self.aggregate
	local unknown = aggregate and aggregate.unknownActivityResultIDs
	if not unknown then
		return false
	end
	local resultIDs = {}
	for resultID in pairs(unknown) do
		resultIDs[#resultIDs + 1] = resultID
	end
	local changed = false
	for _, resultID in ipairs(resultIDs) do
		local status = self:RevalidateAggregatedResult(resultID)
		if status == "matched" or status == "removed" or status == "resolved" then
			changed = true
		end
	end
	return changed
end

local function orderedIDsEqual(left, right)
	if #(left or {}) ~= #(right or {}) then
		return false
	end
	for index, resultID in ipairs(left or {}) do
		if resultID ~= right[index] then
			return false
		end
	end
	return true
end

local function trueKeySetsEqual(left, right)
	for key, value in pairs(left or {}) do
		if value == true and not (right and right[key] == true) then
			return false
		end
	end
	for key, value in pairs(right or {}) do
		if value == true and not (left and left[key] == true) then
			return false
		end
	end
	return true
end

function Search:ReconcileAggregatedResults()
	local aggregate = self.aggregate
	local activitySet = aggregate and aggregate.activitySet
	if not activitySet then
		return false
	end
	local _, nativeResultIDs, readOK = readCurrentResultIDs()
	if readOK == false then
		return false
	end

	local previousIDs = aggregate.resultIDs or {}
	local previousUnknown = aggregate.unknownActivityResultIDs or {}
	local previousInfo = aggregate.infoByID or {}
	local previousMemberCounts = aggregate.memberCountsByID or {}
	local previouslyKept = {}
	for _, resultID in ipairs(previousIDs) do
		previouslyKept[resultID] = true
	end

	local resultIDs = {}
	local infoByID = {}
	local memberCountsByID = {}
	local unknownActivityResultIDs = {}
	local seen = {}
	for _, resultID in ipairs(nativeResultIDs or {}) do
		if resultID ~= nil and not seen[resultID] then
			seen[resultID] = true
			local info
			local membership
			if previouslyKept[resultID]
				and previousUnknown[resultID] ~= true
			then
				membership = true
			else
				info = getSearchResultInfo(resultID)
				membership = resultMatchesActivitySet(info, activitySet)
			end
			if membership ~= false then
				resultIDs[#resultIDs + 1] = resultID
				local compactedInfo = info and compactCapturedInfo(info, resultID)
					or previousInfo[resultID]
				if compactedInfo ~= nil then
					infoByID[resultID] = compactedInfo
				end
				if previousMemberCounts[resultID] ~= nil then
					memberCountsByID[resultID] = previousMemberCounts[resultID]
				end
				if membership == nil then
					unknownActivityResultIDs[resultID] = true
				end
			end
		end
	end

	local changed = not orderedIDsEqual(previousIDs, resultIDs)
		or not trueKeySetsEqual(previousUnknown, unknownActivityResultIDs)
	aggregate.resultIDs = resultIDs
	aggregate.total = #resultIDs
	aggregate.infoByID = infoByID
	aggregate.memberCountsByID = memberCountsByID
	aggregate.unknownActivityResultIDs = unknownActivityResultIDs
	publishAggregateAliases(self, aggregate)
	return changed
end

function Search:OnSearchFailed()
	if GF.SearchMemoryDiagnostics and GF.SearchMemoryDiagnostics.AbortSearch then
		GF.SearchMemoryDiagnostics:AbortSearch("search-failed")
	end
	self:_SetSession(nil)
	clearAggregate(self)
end
