local _, GF = ...

GF.MythicPlusCurrentRoleService = GF.MythicPlusCurrentRoleService or {}
local Service = GF.MythicPlusCurrentRoleService
local Util = GF.MythicPlusServiceUtil

local function readSelectedRoles()
	if not GetLFGRoles then
		return nil, nil, false
	end
	local ok, leader, tank, healer, damager = pcall(GetLFGRoles)
	if not ok then
		return nil, nil, false
	end
	return {
		TANK = tank == true,
		HEAL = healer == true,
		DPS = damager == true,
	}, leader == true, true
end

local function readAvailableRoles()
	if not (C_LFGList and C_LFGList.GetAvailableRoles) then
		return nil, false
	end
	local ok, tank, healer, damager = pcall(C_LFGList.GetAvailableRoles)
	if not ok then
		return nil, false
	end
	return {
		TANK = tank == true,
		HEAL = healer == true,
		DPS = damager == true,
	}, true
end

function Service:AddListener(callback)
	Util.AddListener(self, callback)
end

function Service:GetSnapshot()
	return self.snapshot
end

function Service:Refresh(reason)
	local previous = self.snapshot
	local roles, leader, rolesReady = readSelectedRoles()
	local available, availabilityReady = readAvailableRoles()
	self.snapshot = {
		state = rolesReady and availabilityReady and "ready" or "unavailable",
		roles = rolesReady and Util.CopyRoleFlags(roles)
			or Util.CopyRoleFlags(previous and previous.roles),
		available = availabilityReady and Util.CopyRoleFlags(available)
			or (previous and previous.available and Util.CopyRoleFlags(previous.available) or nil),
		leader = rolesReady and leader or (previous and previous.leader == true),
		rolesReady = rolesReady,
		availabilityReady = availabilityReady,
		stale = not (rolesReady and availabilityReady) or nil,
		updatedAt = Util.Now(),
		reason = reason,
	}
	if rolesReady and GF.MythicPlusCharacterStore then
		local key = GF.MythicPlusCharacterStore:GetCurrentKey()
		if key and GF.MythicPlusCharacterStore.SetStoredRoles then
			GF.MythicPlusCharacterStore:SetStoredRoles(key, roles, reason or "current_roles")
		end
	end
	Util.Notify(self, reason or "refresh")
	return self.snapshot
end

function Service:RequestRefresh(reason)
	return self:Refresh(reason)
end

function Service:SetRole(roleKey, enabled)
	roleKey = Util.NormalizeRole(roleKey)
	if not (roleKey and SetLFGRoles) then
		return false, self.snapshot
	end
	local roles, leader, rolesReady = readSelectedRoles()
	if not rolesReady then
		return false, self:Refresh("set_role_unavailable")
	end
	local available, availabilityReady = readAvailableRoles()
	if enabled == true and availabilityReady and available[roleKey] == false then
		return false, self:Refresh("set_role_unavailable")
	end
	roles = Util.CopyRoleFlags(roles)
	roles[roleKey] = enabled == true
	local ok = pcall(SetLFGRoles, leader == true, roles.TANK, roles.HEAL, roles.DPS)
	if not ok then
		return false, self:Refresh("set_role_failed")
	end
	return true, self:Refresh("set_role")
end

function Service:Init()
	if self.initialized then
		return
	end
	self.initialized = true
	self.eventFrame = CreateFrame("Frame")
	for _, event in ipairs({ "LFG_ROLE_UPDATE", "PLAYER_ROLES_ASSIGNED" }) do
		pcall(self.eventFrame.RegisterEvent, self.eventFrame, event)
	end
	self.eventFrame:SetScript("OnEvent", function(_, event)
		Service:RequestRefresh(event)
	end)
	self:RequestRefresh("init")
end
