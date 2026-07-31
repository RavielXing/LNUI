local _, GF = ...

GF.LFGWorkspaceView = GF.LFGWorkspaceView or {}
local View = GF.LFGWorkspaceView

local function policy()
	return GF.LFGWorkspacePolicy
end

local function normalizeWorkspaceID(workspaceID)
	local p = policy()
	if p and p.NormalizeWorkspaceID then
		return p:NormalizeWorkspaceID(workspaceID)
	end
	if workspaceID == GF.WORKSPACE_MYTHIC_PLUS then
		return GF.WORKSPACE_MYTHIC_PLUS
	end
	return GF.WORKSPACE_MEETING_STONE
end

local function resolveNodeByKey(key)
	if not key then
		return nil, nil
	end
	if GF.NavTree and GF.NavTree.FindNodePathByKey then
		return GF.NavTree:FindNodePathByKey(key)
	end
	local node = GF.NavData and GF.NavData.FindNodeByKey and GF.NavData.FindNodeByKey(key)
	return node, node and { node } or nil
end

local function copyExpanded(source)
	local out = {}
	for key, value in pairs(source or {}) do
		if value == true then
			out[key] = true
		end
	end
	return out
end

function View:GetWorkspaceID()
	return self.activeWorkspaceID or GF.WORKSPACE_MEETING_STONE
end

function View:GetProfile(workspaceID)
	local p = policy()
	return p and p.GetProfile and p:GetProfile(workspaceID or self:GetWorkspaceID()) or nil
end

function View:IsMythicPlusActive()
	local p = policy()
	return p and p.IsMythicPlusWorkspace
		and p:IsMythicPlusWorkspace(self:GetWorkspaceID()) or false
end

function View:GetBrowseSurface()
	return GF.FindGroupTab
end

function View:GetCreateSurface()
	return GF.CreatePanel
end

function View:GetApplicantsSurface()
	return GF.ApplicantsPanel
end

function View:GetVisibleRoots(tree)
	local p = policy()
	if p and p.GetVisibleRoots then
		return p:GetVisibleRoots(self:GetWorkspaceID(), tree)
	end
	return tree or {}
end

function View:IsNodeAllowed(node, workspaceID)
	local p = policy()
	if p and p.IsNodeAllowed then
		return p:IsNodeAllowed(workspaceID or self:GetWorkspaceID(), node)
	end
	return node ~= nil
end

function View:IsCreateableSelection(node, workspaceID)
	if not node then
		return false
	end
	local activityID = GF.NavData and GF.NavData.ResolveCreateActivityID
		and GF.NavData.ResolveCreateActivityID(node)
	if not activityID then
		return false
	end
	local p = policy()
	if p and p.IsCreateActivityAllowed then
		return p:IsCreateActivityAllowed(workspaceID or self:GetWorkspaceID(), activityID)
	end
	return true
end

function View:RememberSelection(workspaceID, node)
	workspaceID = normalizeWorkspaceID(workspaceID or self:GetWorkspaceID())
	self.stateByWorkspace = self.stateByWorkspace or {}
	local state = self.stateByWorkspace[workspaceID] or {}
	state.selectionKey = node and node.key or nil
	self.stateByWorkspace[workspaceID] = state
end

function View:ResetSelectionToDefault(workspaceID)
	workspaceID = normalizeWorkspaceID(workspaceID or self:GetWorkspaceID())
	self.stateByWorkspace = self.stateByWorkspace or {}
	local state = self.stateByWorkspace[workspaceID] or {}
	state.selectionKey = nil
	state.activeRootKey = nil
	self.stateByWorkspace[workspaceID] = state
	return self:ResolveSelection(workspaceID)
end

function View:CaptureNavState(workspaceID)
	if not GF.NavTree then
		return
	end
	workspaceID = normalizeWorkspaceID(workspaceID or self:GetWorkspaceID())
	self.stateByWorkspace = self.stateByWorkspace or {}
	local state = self.stateByWorkspace[workspaceID] or {}
	state.selectionKey = GF.NavTree.selectedKey
	state.activeRootKey = GF.NavTree.activeRootKey
	state.expanded = copyExpanded(GF.NavTree.expanded)
	self.stateByWorkspace[workspaceID] = state
end

function View:ApplyNavState(workspaceID, node, path)
	if not GF.NavTree then
		return
	end
	workspaceID = normalizeWorkspaceID(workspaceID or self:GetWorkspaceID())
	self.stateByWorkspace = self.stateByWorkspace or {}
	local state = self.stateByWorkspace[workspaceID] or {}
	self.stateByWorkspace[workspaceID] = state
	GF.NavTree.expanded = copyExpanded(state.expanded)
	if path then
		for index = 1, #path - 1 do
			local ancestor = path[index]
			if ancestor and ancestor.key then
				GF.NavTree.expanded[ancestor.key] = true
			end
		end
	end
	GF.NavTree.selectedKey = node and node.key or nil
	GF.NavTree.activeRootKey = state.activeRootKey
		or (path and path[1] and path[1].key)
		or (node and (node.level or 0) == 0 and node.key)
		or nil
	if GF.NavTree.Refresh then
		GF.NavTree:Refresh()
	end
end

function View:ResolveSelection(workspaceID)
	workspaceID = normalizeWorkspaceID(workspaceID)
	self.stateByWorkspace = self.stateByWorkspace or {}
	local state = self.stateByWorkspace[workspaceID] or {}
	self.stateByWorkspace[workspaceID] = state

	local p = policy()
	local key = state.selectionKey
	if not key and p and p.GetDefaultSelectionKey then
		key = p:GetDefaultSelectionKey(workspaceID)
	end
	local node, path = resolveNodeByKey(key)
	if node and self:IsNodeAllowed(node, workspaceID) then
		return node, path
	end

	local fallbackKey = p and p.GetDefaultSelectionKey and p:GetDefaultSelectionKey(workspaceID)
	if fallbackKey and fallbackKey ~= key then
		node, path = resolveNodeByKey(fallbackKey)
		if node and self:IsNodeAllowed(node, workspaceID) then
			return node, path
		end
	end
	return nil, nil
end

function View:Activate(workspaceID, previousWorkspaceID, currentSelection)
	workspaceID = normalizeWorkspaceID(workspaceID)
	if previousWorkspaceID ~= nil then
		previousWorkspaceID = normalizeWorkspaceID(previousWorkspaceID)
	elseif self.activeWorkspaceID then
		previousWorkspaceID = self.activeWorkspaceID
	end
	if previousWorkspaceID and previousWorkspaceID ~= workspaceID then
		self:CaptureNavState(previousWorkspaceID)
		self:RememberSelection(previousWorkspaceID, currentSelection)
	end

	if self.activeWorkspaceID ~= workspaceID then
		self.generation = (self.generation or 0) + 1
	elseif not self.generation then
		self.generation = 1
	end
	self.activeWorkspaceID = workspaceID

	local node, path = self:ResolveSelection(workspaceID)
	return self:GetContext(), node, path
end

function View:GetContext()
	local workspaceID = self:GetWorkspaceID()
	local generation = self.generation or 1
	return {
		workspaceID = workspaceID,
		generation = generation,
		key = string.format("%s:%d", workspaceID, generation),
	}
end

function View:IsContextCurrent(context)
	if not context then
		return false
	end
	local current = self:GetContext()
	return context.workspaceID == current.workspaceID
		and tonumber(context.generation) == tonumber(current.generation)
end
