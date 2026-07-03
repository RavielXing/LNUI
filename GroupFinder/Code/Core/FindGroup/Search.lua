local _, GF = ...

GF.Search = {}

local NEXT_SCOPE_DELAY = 0
local RECOMMENDED_SEARCH_MASK = bit.bor(Enum.LFGListFilter.Recommended, Enum.LFGListFilter.NotRecommended)

local function getLanguages()
	return C_LFGList.GetLanguageSearchFilter and C_LFGList.GetLanguageSearchFilter() or nil
end

local function hasKeywordSearch()
	local hasKeyword = false
	if GF.FindGroupTab and GF.FindGroupTab.GetBrowseSearchState then
		hasKeyword = GF.FindGroupTab:GetBrowseSearchState()
	end
	return hasKeyword == true
end

local function readCurrentResultIDs()
	local total, ids
	if hasKeywordSearch() and C_LFGList.GetFilteredSearchResults then
		total, ids = C_LFGList.GetFilteredSearchResults()
	elseif C_LFGList.GetSearchResults then
		total, ids = C_LFGList.GetSearchResults()
	end
	return total or 0, ids or {}
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
	if not activityIDsFilter and not scope.resultActivityIDsFilter
		and activityID and not scope.categoryBrowse
		and not (selection and selection.categoryBrowse) then
		activityIDsFilter = { activityID }
	end

	local baseFilters = scope.filters or (selection and selection.filters) or 0
	local filters = GF.Filter and GF.Filter:ResolveCategoryFilters(categoryID, baseFilters) or baseFilters
	if GF.Filter and GF.Filter.ResolvePreferredFilters then
		preferredFilters = GF.Filter:ResolvePreferredFilters(categoryID, preferredFilters)
	end

	return {
		categoryID = categoryID,
		filters = filters,
		preferredFilters = preferredFilters,
		activityIDsFilter = activityIDsFilter,
		resultActivityIDsFilter = scope.resultActivityIDsFilter,
		navKind = scope.navKind or (selection and selection.navKind),
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

local function getScopeMergeFilters(categoryID, filters, postFilterActivities)
	filters = filters or 0
	if postFilterActivities and (categoryID == GF.CAT_RAID or categoryID == GF.CAT_DUNGEON) then
		return bit.band(filters, bit.bnot(RECOMMENDED_SEARCH_MASK))
	end
	return filters
end

local function mergeScopeFilters(categoryID, prev, nextFilters, postFilterActivities)
	prev = prev or 0
	nextFilters = nextFilters or 0
	if postFilterActivities and (categoryID == GF.CAT_RAID or categoryID == GF.CAT_DUNGEON) then
		return bit.band(prev, bit.bnot(RECOMMENDED_SEARCH_MASK))
	end
	return prev
end

local function shouldPostFilterActivityIDs(scope, postFilterRaidActivities, postFilterDungeonActivities)
	if not scope then
		return false
	end
	if scope.categoryID == GF.CAT_RAID then
		return postFilterRaidActivities
	end
	if scope.categoryID == GF.CAT_DUNGEON then
		return postFilterDungeonActivities and scope.navKind == "dungeon"
	end
	return false
end

local function mergeNormalizedScopes(scopes)
	local raidScopeCount = 0
	local dungeonScopeCount = 0
	for _, scope in ipairs(scopes or {}) do
		if scope and scope.categoryID == GF.CAT_RAID then
			raidScopeCount = raidScopeCount + 1
		elseif scope and scope.categoryID == GF.CAT_DUNGEON and scope.navKind == "dungeon" then
			dungeonScopeCount = dungeonScopeCount + 1
		end
	end
	local postFilterRaidActivities = raidScopeCount > 1
	local postFilterDungeonActivities = dungeonScopeCount > 1
	local merged = {}
	local order = {}
	for _, scope in ipairs(scopes or {}) do
		if scope and scope.categoryID then
			local postFilterActivities = shouldPostFilterActivityIDs(scope, postFilterRaidActivities, postFilterDungeonActivities)
			local key = table.concat({
				tostring(scope.categoryID),
				tostring(getScopeMergeFilters(scope.categoryID, scope.filters, postFilterActivities)),
				tostring(scope.preferredFilters or 0),
				postFilterActivities and "post" or "native",
			}, ":")
			local out = merged[key]
			if not out then
				out = {
					categoryID = scope.categoryID,
					filters = getScopeMergeFilters(scope.categoryID, scope.filters, postFilterActivities),
					preferredFilters = scope.preferredFilters,
					navKind = scope.navKind,
					activityIDsFilter = (not postFilterActivities and scope.activityIDsFilter) and {} or nil,
					resultActivityIDsFilter = (postFilterActivities and (scope.activityIDsFilter or scope.resultActivityIDsFilter))
						and {} or (scope.resultActivityIDsFilter and {} or nil),
					_seenActivityIDs = {},
					_seenResultActivityIDs = {},
				}
				merged[key] = out
				order[#order + 1] = key
			else
				out.filters = mergeScopeFilters(out.categoryID, out.filters, scope.filters, postFilterActivities)
			end
			if postFilterActivities then
				if not out.resultActivityIDsFilter and (scope.activityIDsFilter or scope.resultActivityIDsFilter) then
					out.resultActivityIDsFilter = {}
				end
				if out.resultActivityIDsFilter then
					mergeIDsInto(out.resultActivityIDsFilter, out._seenResultActivityIDs, scope.activityIDsFilter)
				end
			elseif scope.activityIDsFilter == nil then
				out.activityIDsFilter = nil
			elseif out.activityIDsFilter then
				mergeIDsInto(out.activityIDsFilter, out._seenActivityIDs, scope.activityIDsFilter)
			end
			if postFilterActivities then
				if out.resultActivityIDsFilter then
					mergeIDsInto(out.resultActivityIDsFilter, out._seenResultActivityIDs, scope.resultActivityIDsFilter)
				end
			elseif scope.resultActivityIDsFilter == nil then
				out.resultActivityIDsFilter = nil
			elseif out.resultActivityIDsFilter then
				mergeIDsInto(out.resultActivityIDsFilter, out._seenResultActivityIDs, scope.resultActivityIDsFilter)
			end
		end
	end

	local result = {}
	for _, key in ipairs(order) do
		local scope = merged[key]
		scope._seenActivityIDs = nil
		scope._seenResultActivityIDs = nil
		result[#result + 1] = scope
	end
	return result
end

function GF.Search:Reset()
	self.pending = nil
	self.aggregateResultIDs = nil
	self.aggregateTotal = nil
	self.aggregateInfoByID = nil
	self.aggregateMemberCountsByID = nil
	self.nextScopeScheduled = nil
end

function GF.Search:ClearAggregatedResultIDs()
	self.aggregateResultIDs = nil
	self.aggregateTotal = nil
	self.aggregateInfoByID = nil
	self.aggregateMemberCountsByID = nil
end

function GF.Search:GetAggregatedResultIDs()
	return self.aggregateResultIDs, self.aggregateTotal, self.aggregateInfoByID, self.aggregateMemberCountsByID
end

function GF.Search:BuildScopes(selection)
	local rawScopes
	if GF.NavData and GF.NavData.ResolveSearchScopes then
		rawScopes = GF.NavData.ResolveSearchScopes(selection, { forSearch = true })
	elseif selection and GF.NavData and GF.NavData.ResolveSearchScope then
		rawScopes = { GF.NavData.ResolveSearchScope(selection, { forSearch = true }) }
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
	return mergeNormalizedScopes(scopes)
end

local function scopeNeedsAggregatedResults(scope)
	return scope and scope.resultActivityIDsFilter and #scope.resultActivityIDsFilter > 0
end

function GF.Search:_RunScope(scope)
	if not scope or not scope.categoryID then
		return false
	end
	if GF.Availability and GF.Availability.ShouldProcessLfgEvent
		and not GF.Availability:ShouldProcessLfgEvent() then
		return false
	end
	C_LFGList.Search(
		scope.categoryID,
		scope.filters or 0,
		scope.preferredFilters or Enum.LFGListFilter.PvE,
		getLanguages(),
		nil,
		nil,
		scope.activityIDsFilter
	)
	return true
end

function GF.Search:_RunPendingScope()
	local pending = self.pending
	if not pending then
		return false
	end
	return self:_RunScope(pending.scopes[pending.index])
end

function GF.Search:_SchedulePendingScope()
	if self.nextScopeScheduled then
		return true
	end
	local pending = self.pending
	if not pending then
		return false
	end
	self.nextScopeScheduled = true
	C_Timer.After(NEXT_SCOPE_DELAY, function()
		self.nextScopeScheduled = nil
		local currentPending = self.pending
		if not currentPending or currentPending ~= pending then
			return
		end
		if self:_RunPendingScope() then
			return
		end
		self.pending = nil
		self.aggregateResultIDs = nil
		self.aggregateTotal = nil
		self.aggregateInfoByID = nil
		self.aggregateMemberCountsByID = nil
		if GF.FindGroupTab and GF.FindGroupTab.OnSearchFailed then
			GF.FindGroupTab:OnSearchFailed()
		end
	end)
	return true
end

function GF.Search:Run(selection)
	self:Reset()
	if GF.FindGroup and GF.FindGroup.IsSearchableSelection
		and not GF.FindGroup:IsSearchableSelection(selection) then
		return false
	end
	local scopes = self:BuildScopes(selection)
	if #scopes == 0 then
		return false
	end
	if #scopes == 1 then
		if scopeNeedsAggregatedResults(scopes[1]) then
			self.pending = {
				scopes = scopes,
				index = 1,
				resultIDs = {},
				seen = {},
				infoByID = {},
				memberCountsByID = {},
				total = 0,
			}
			return self:_RunPendingScope()
		end
		return self:_RunScope(scopes[1])
	end
	self.pending = {
		scopes = scopes,
		index = 1,
		resultIDs = {},
		seen = {},
		infoByID = {},
		memberCountsByID = {},
		total = 0,
	}
	return self:_RunPendingScope()
end

local function getResultPrimaryActivityID(info)
	if not info then
		return nil
	end
	if info.activityID then
		return info.activityID
	end
	if not info.activityIDs then
		return nil
	end
	local ok, activityID = pcall(function()
		return info.activityIDs[1]
	end)
	if ok then
		return activityID
	end
	return nil
end

local function buildActivityIDSet(activityIDs)
	if not activityIDs or #activityIDs == 0 then
		return nil
	end
	local set = {}
	for _, activityID in ipairs(activityIDs) do
		if activityID then
			set[activityID] = true
		end
	end
	return set
end

local function getSearchResultMemberCounts(resultID)
	if not resultID or not (C_LFGList and C_LFGList.GetSearchResultMemberCounts) then
		return nil
	end
	local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
	if ok and type(counts) == "table" then
		return counts
	end
	return nil
end

function GF.Search:OnSearchResults()
	local pending = self.pending
	if not pending then
		return "complete"
	end

	local scope = pending.scopes[pending.index]
	local resultActivitySet = buildActivityIDSet(scope and scope.resultActivityIDsFilter)
	local total, ids = readCurrentResultIDs()
	for _, resultID in ipairs(ids or {}) do
		local info
		local keep = true
		if resultActivitySet then
			info = resultID and C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(resultID) or nil
			keep = resultActivitySet[getResultPrimaryActivityID(info)] == true
		end
		if keep then
			if not pending.seen[resultID] then
				pending.seen[resultID] = true
				pending.resultIDs[#pending.resultIDs + 1] = resultID
				pending.total = (pending.total or 0) + 1
			end
			if resultID and C_LFGList.GetSearchResultInfo and not pending.infoByID[resultID] then
				local capturedInfo = info or C_LFGList.GetSearchResultInfo(resultID)
				if capturedInfo and GF.ResolveSearchResultSocialCounts then
					GF.ResolveSearchResultSocialCounts(capturedInfo, resultID)
				end
				pending.infoByID[resultID] = capturedInfo
			end
			if resultID and not pending.memberCountsByID[resultID] then
				pending.memberCountsByID[resultID] = getSearchResultMemberCounts(resultID)
			end
		end
	end

	if pending.index < #pending.scopes then
		pending.index = pending.index + 1
		if self:_SchedulePendingScope() then
			return "continue"
		end
		self.pending = nil
		self.aggregateResultIDs = nil
		self.aggregateTotal = nil
		self.aggregateInfoByID = nil
		self.aggregateMemberCountsByID = nil
		return "failed"
	end

	self.aggregateResultIDs = pending.resultIDs
	self.aggregateTotal = #pending.resultIDs
	self.aggregateInfoByID = pending.infoByID
	self.aggregateMemberCountsByID = pending.memberCountsByID
	self.pending = nil
	return "complete"
end

function GF.Search:OnSearchFailed()
	self.pending = nil
	self.aggregateResultIDs = nil
	self.aggregateTotal = nil
	self.aggregateInfoByID = nil
	self.aggregateMemberCountsByID = nil
	self.nextScopeScheduled = nil
end
