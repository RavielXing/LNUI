local _, GF = ...

GF.LFGWorkspacePolicy = GF.LFGWorkspacePolicy or {}
local Policy = GF.LFGWorkspacePolicy

local PROFILES = {
	[GF.WORKSPACE_RAID] = {
		id = GF.WORKSPACE_RAID, viewID = "raid",
		defaultSelectionKey = "season_raid",
		visibleRootKeys = { season_raid = true },
		navKind = "season_raid",
	},
	[GF.WORKSPACE_MEETING_STONE] = {
		id = GF.WORKSPACE_MEETING_STONE,
		viewID = "meeting_stone",
	},
	[GF.WORKSPACE_MYTHIC_PLUS] = {
		id = GF.WORKSPACE_MYTHIC_PLUS,
		viewID = "mythic_plus",
		defaultSelectionKey = "season_dungeon",
		visibleRootKeys = {
			season_dungeon = true,
		},
		navKind = "season_dungeon",
	},
}

local function safeActivityInfo(activityID)
	if not (activityID and C_LFGList and C_LFGList.GetActivityInfoTable) then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
	return ok and type(info) == "table" and info or nil
end

local function copyScope(scope)
	local out = {}
	for key, value in pairs(scope or {}) do
		out[key] = value
	end
	return out
end

function Policy:NormalizeWorkspaceID(workspaceID)
	if workspaceID == GF.WORKSPACE_RAID then
		return GF.WORKSPACE_RAID
	end
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS then
		return GF.WORKSPACE_MYTHIC_PLUS
	end
	return GF.WORKSPACE_MEETING_STONE
end

function Policy:GetProfile(workspaceID)
	workspaceID = self:NormalizeWorkspaceID(workspaceID)
	return PROFILES[workspaceID] or PROFILES[GF.WORKSPACE_MEETING_STONE]
end

function Policy:IsMythicPlusWorkspace(workspaceID)
	return self:NormalizeWorkspaceID(workspaceID) == GF.WORKSPACE_MYTHIC_PLUS
end

function Policy:GetDefaultSelectionKey(workspaceID)
	local profile = self:GetProfile(workspaceID)
	return profile and profile.defaultSelectionKey or nil
end

function Policy:GetVisibleRoots(workspaceID, tree)
	local profile = self:GetProfile(workspaceID)
	if not profile.visibleRootKeys then
		return tree or {}
	end
	local roots = {}
	for _, node in ipairs(tree or {}) do
		if node and profile.visibleRootKeys[node.key] then
			roots[#roots + 1] = node
		end
	end
	return roots
end

function Policy:IsNodeAllowed(workspaceID, node)
	if not node then
		return false
	end
	local profile = self:GetProfile(workspaceID)
	if not profile.navKind then
		return true
	end
	if node.navKind ~= profile.navKind then
		return false
	end
	if self:IsMythicPlusWorkspace(workspaceID) and (node.level or 0) > 0 then
		-- Meeting Stone may project the seasonal roster as ordinary difficulty
		-- parents before Mythic+ opens. The dedicated Mythic+ workspace must never
		-- expose or select those nodes; only live Mythic+ leaves cross this gate.
		return node.seasonDungeonMythicPlus == true
	end
	return true
end

function Policy:GetSeasonUnavailableMessage(locale)
	locale = locale or GF.L or {}
	local state = GF.NavData and GF.NavData.GetSeasonDungeonPresentationState
		and GF.NavData.GetSeasonDungeonPresentationState() or "loading"
	if state == "preseason" or state == "standard_open" then
		return locale.MPLUS_LFG_NOT_OPEN
			or "Seasonal Mythic+ is not yet available."
	elseif state ~= "level_limited" then
		return locale.MPLUS_LFG_SCOPE_LOADING
			or "Seasonal Mythic+ activities are loading."
	end
	return locale.MPLUS_LFG_SCOPE_UNAVAILABLE
		or "Level restricted: Seasonal Mythic+ mode has not been unlocked."
end

function Policy:IsSearchableNode(workspaceID, node)
	if not self:IsNodeAllowed(workspaceID, node) then
		return false
	end
	if not self:IsMythicPlusWorkspace(workspaceID) then
		return true
	end
	local browseFilter = GF.MythicPlusBrowseFilter
	if browseFilter and browseFilter.GetSelectedActivityIDs then
		local activityIDs = browseFilter:GetSelectedActivityIDs()
		return type(activityIDs) == "table" and #activityIDs > 0
	end
	local scope = GF.MythicPlusLFGScope
	local activityIDs = scope and scope.GetActivityIDsForNode
		and scope:GetActivityIDsForNode(node) or {}
	return #activityIDs > 0
end

function Policy:GetSeasonActivityIDs()
	local scope = GF.MythicPlusLFGScope
	return scope and scope.GetActivityIDs and scope:GetActivityIDs() or {}
end

-- Use the same live catalog and exact search compiler as the navigation tree.
-- A cold/unavailable catalog authorizes no activity and never widens to all raids.
function Policy:GetSeasonRaidActivitySet()
	local nav = GF.NavData
	local root = nav and nav.FindNodeByKey and nav.FindNodeByKey("season_raid")
	local allowed = {}
	if not root or root.disabled or not nav.ResolveSearchScopes then return allowed end
	for _, scope in ipairs(nav.ResolveSearchScopes(root, { forSearch = true }) or {}) do
		if scope.categoryID == GF.CAT_RAID then
			for _, id in ipairs(scope.resultActivityIDsFilter or scope.activityIDsFilter or {}) do
				allowed[id] = true
			end
			if scope.activityID then allowed[scope.activityID] = true end
		end
	end
	return allowed
end

function Policy:IsActivityAllowed(workspaceID, activityID)
	if workspaceID == GF.WORKSPACE_RAID then
		return self:GetSeasonRaidActivitySet()[activityID] == true
	end
	if not self:IsMythicPlusWorkspace(workspaceID) then
		return true
	end
	local scope = GF.MythicPlusLFGScope
	return scope and scope.IsActivityIDAllowed
		and scope:IsActivityIDAllowed(activityID) or false
end

function Policy:IsCreateActivityAllowed(workspaceID, activityID)
	if not self:IsActivityAllowed(workspaceID, activityID) then
		return false
	end
	if not self:IsMythicPlusWorkspace(workspaceID) then
		return true
	end
	local info = safeActivityInfo(activityID)
	return info and info.isMythicPlusActivity == true or false
end

function Policy:ConstrainSearchScopes(workspaceID, selection, scopes)
	if workspaceID == GF.WORKSPACE_RAID then
		if not self:IsNodeAllowed(workspaceID, selection) or selection.disabled then return {} end
		local allowed, constrained = self:GetSeasonRaidActivitySet(), {}
		for _, scope in ipairs(scopes or {}) do
			if scope.categoryID == GF.CAT_RAID then
				local ids = {}
				local candidates = scope.resultActivityIDsFilter or scope.activityIDsFilter
					or (scope.activityID and { scope.activityID }) or {}
				for _, id in ipairs(candidates) do
					if allowed[id] then ids[#ids + 1] = id end
				end
				if #ids > 0 then
					local exact = copyScope(scope)
					exact.navKind = "season_raid"
					exact.activityID = nil
					exact.activityIDsFilter = ids
					exact.resultActivityIDsFilter = ids
					constrained[#constrained + 1] = exact
				end
			end
		end
		return constrained
	end
	if not self:IsMythicPlusWorkspace(workspaceID) then
		return scopes or {}
	end
	if not self:IsNodeAllowed(workspaceID, selection) then
		return {}
	end

	local scopeService = GF.MythicPlusLFGScope
	local browseFilter = GF.MythicPlusBrowseFilter
	local targetIDs
	if browseFilter and browseFilter.GetSelectedActivityIDs then
		targetIDs = browseFilter:GetSelectedActivityIDs()
	else
		targetIDs = scopeService and scopeService.GetActivityIDsForNode
			and scopeService:GetActivityIDsForNode(selection) or {}
	end
	if #targetIDs == 0 then
		return {}
	end
	local template
	for _, scope in ipairs(scopes or {}) do
		if scope and scope.categoryID == GF.CAT_DUNGEON then
			template = copyScope(scope)
			break
		end
	end
	if not template then
		return {}
	end
	template.navKind = "season_dungeon"
	template.activityID = nil
	template.activityIDsFilter = targetIDs
	-- Search's final scope normalization keeps a single target native-exact;
	-- multiple targets become one category request plus a local projection.
	template.resultActivityIDsFilter = targetIDs
	return { template }
end
