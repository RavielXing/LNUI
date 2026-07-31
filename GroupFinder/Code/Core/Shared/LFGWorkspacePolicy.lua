local _, GF = ...

GF.LFGWorkspacePolicy = GF.LFGWorkspacePolicy or {}
local Policy = GF.LFGWorkspacePolicy

local PROFILES = {
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
	return node.navKind == profile.navKind
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

function Policy:IsActivityAllowed(workspaceID, activityID)
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
	-- Keep a local primary-activity guard even though Retail receives the same
	-- IDs as C_LFGList.Search's native activityIDsFilter.
	template.resultActivityIDsFilter = targetIDs
	return { template }
end
