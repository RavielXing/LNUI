local _, GF = ...

GF.MythicPlusCarpoolPolicy = GF.MythicPlusCarpoolPolicy or {}
local Policy = GF.MythicPlusCarpoolPolicy

local function accessible(value)
	return not GF.Compat or GF.Compat.IsAccessibleValue(value)
end

function Policy:IsRaidSilent()
	local db = GF.GetDB and GF.GetDB()
	if db and db.raidCarpoolSilent == false then return false end
	if type(IsInRaid) ~= "function" then return false end
	local ok, inRaid = pcall(IsInRaid)
	return ok and accessible(inRaid) and inRaid == true or false
end

function Policy:IsLocalUnit(unit)
	if unit == "player" then return true end
	if type(UnitIsUnit) ~= "function" then return false end
	local ok, same = pcall(UnitIsUnit, unit, "player")
	return ok and accessible(same) and same == true or false
end

function Policy:Refresh(reason)
	local active = self:IsRaidSilent()
	if self.active == active then return false end
	local previous = self.active
	self.active = active
	-- The first ordinary initialization does not need to repeat service startup.
	if previous == nil and not active then return false end
	reason = reason or "carpool-policy"
	local snapshot = GF.MythicPlusGroupSnapshotService
	if snapshot and snapshot.OnCarpoolPolicyChanged then
		snapshot:OnCarpoolPolicyChanged(reason, active)
	end
	local rating = GF.MythicPlusRatingCache
	if rating and rating.RequestRoster then rating:RequestRoster(reason) end
	local interop = GF.MythicPlusKeystoneInteropService
	if interop and interop.OnCarpoolPolicyChanged then
		interop:OnCarpoolPolicyChanged(reason, active)
	end
	local roster = GF.MythicPlusRosterCache
	if roster and roster.RequestRefresh then roster:RequestRefresh(reason) end
	local view = GF.MythicPlusCarpoolView
	if view and view.OnCarpoolPolicyChanged then view:OnCarpoolPolicyChanged(reason) end
	return true
end
