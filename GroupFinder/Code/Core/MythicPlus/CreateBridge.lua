local _, GF = ...

GF.MythicPlusCreateBridge = GF.MythicPlusCreateBridge or {}
local Bridge = GF.MythicPlusCreateBridge

local function resolveActivityID(entry)
	entry = entry and (entry.data or entry)
	local activityID = tonumber(entry and entry.activityID)
	if activityID then
		local scope = GF.MythicPlusLFGScope
		return scope and scope.ResolveCreateActivityID
			and scope:ResolveCreateActivityID(activityID) or nil
	end
	local challengeModeID = tonumber(entry and (entry.challengeModeID or entry.mapID))
	local dungeon = challengeModeID and GF.MythicPlusSeason
		and GF.MythicPlusSeason:GetByChallengeModeID(challengeModeID)
	activityID = dungeon and tonumber(dungeon.activityID) or nil
	local scope = GF.MythicPlusLFGScope
	return scope and scope.ResolveCreateActivityID
		and scope:ResolveCreateActivityID(activityID) or nil
end

local function resolveNode(entry)
	local activityID = resolveActivityID(entry)
	return activityID and GF.NavData and GF.NavData.FindSeasonDungeonNodeByActivityID
		and GF.NavData.FindSeasonDungeonNodeByActivityID(activityID)
end

function Bridge:CanOpenForRosterEntry(entry)
	local node = resolveNode(entry)
	return node ~= nil, node
end

function Bridge:OpenForRosterEntry(entry)
	local canOpen, node = self:CanOpenForRosterEntry(entry)
	if not canOpen then
		return false
	end
	if GF.WorkspaceBar and GF.WorkspaceBar.Select then
		GF.WorkspaceBar:Select(GF.WORKSPACE_MYTHIC_PLUS)
	end
	if GF.MainFrame and GF.MainFrame.OpenCreateTab then
		GF.MainFrame:OpenCreateTab()
	end
	if GF.NavTree and GF.NavTree.FindNodePathByKey
		and GF.NavTree.SetSelectedSilently then
		local selectedNode, path = GF.NavTree:FindNodePathByKey(node.key)
		if selectedNode then
			node = selectedNode
			GF.NavTree:SetSelectedSilently(node, path)
		end
	end
	if GF.MainFrame and GF.MainFrame.OnSelectionChanged then
		GF.MainFrame:OnSelectionChanged(node)
	elseif GF.CreatePanel and GF.CreatePanel.SetSelection then
		GF.CreatePanel:SetSelection(node)
	end
	return true
end
