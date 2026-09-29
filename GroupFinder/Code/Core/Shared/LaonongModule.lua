local _, GF = ...

-- The host retains only lifecycle routing. The directory and its indexes are
-- owned by the optional extension; absent support leaves the existing UI alone.
local Module = { addonName = "GroupFinder_Laonong", apiVersion = 1 }
GF.LaonongModule = Module
local SOURCE_ADDON = "!!!163UI!!!"
local listeners = {}

function Module:IsAvailable()
	if not (C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function"
		and type(C_AddOns.IsAddOnLoadable) == "function"
		and type(UnitGUID) == "function") then return false end
	local character = UnitGUID("player")
	if not character then return false end
	local ok, enabled = pcall(C_AddOns.GetAddOnEnableState, self.addonName, character)
	if not ok or type(enabled) ~= "number" or enabled <= 0 then return false end
	local loadable
	ok, loadable = pcall(C_AddOns.IsAddOnLoadable, self.addonName, character, true)
	return ok and loadable == true
end

function Module:AddListener(callback)
	if type(callback) ~= "function" then return end
	if self.attached then
		GF.LaonongFanDirectory:AddListener(callback)
	else
		listeners[#listeners + 1] = callback
	end
end

function Module:EnsureLoaded(preview)
	if not self.initialized then return false, "runtime-not-ready" end
	if self.attached then return true end
	if self.loading then return false, "loading" end
	local debug = GF.Debug
	local previewRequested = preview == true and debug
		and type(debug.IsDebugModeEnabled) == "function" and debug:IsDebugModeEnabled()
	if not previewRequested and not GF.Compat.IsAddOnFullyLoaded(SOURCE_ADDON) then
		return false, "source-unavailable"
	end
	if not self:IsAvailable() then return false, "component-unavailable" end
	if not self.ready then
		-- Failed loads are retried only after a relevant addon-load event, not
		-- on every search/listing refresh. Native enable changes require reload.
		if self.attempted then return false, self.failureReason end
		self.attempted, self.loading = true, true
		local ok, loaded, reason = pcall(GF.Compat.LoadAddOn, self.addonName)
		self.loading = false
		if not ok or loaded ~= true or not self.ready then
			self.failureReason = not ok and "load-error" or reason or "incompatible-component"
			return false, self.failureReason
		end
	end
	local directory = GF.LaonongFanDirectory
	if not directory then return false, "incompatible-component" end
	self.attached, self.failureReason = true, nil
	for _, callback in ipairs(listeners) do directory:AddListener(callback) end
	listeners = nil
	directory:Init()
	return true
end

function Module:Init()
	if self.initialized then return end
	self.initialized = true
	self:EnsureLoaded()
end

function Module:Refresh()
	if self.attached then return GF.LaonongFanDirectory:Refresh() end
	return self:EnsureLoaded()
end

function Module:RefreshWithRetry()
	if self.attached then return GF.LaonongFanDirectory:RefreshWithRetry() end
	return self:EnsureLoaded()
end

function Module:OnAddonLoaded(name)
	if self.loading or (name ~= SOURCE_ADDON and name ~= self.addonName) then return end
	self.attempted = nil
	if self.attached then
		GF.LaonongFanDirectory:OnAddonLoaded(name)
	else
		self:EnsureLoaded()
	end
end
