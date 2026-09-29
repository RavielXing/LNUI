local _, GF = ...

-- Keep one service table so listeners registered before loading survive.
local Service = {}
GF.NetEaseIdentityService = Service
local Module = { addonName = "GroupFinder_NetEase", apiVersion = 1 }
GF.NetEaseModule = Module

-- Inspect availability without loading the component or starting its service.
function Module:IsAvailable()
	if not (C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function"
		and type(C_AddOns.IsAddOnLoadable) == "function"
		and type(UnitGUID) == "function") then
		return false
	end
	local character = UnitGUID("player")
	if not character then return false end
	local ok, enabled = pcall(C_AddOns.GetAddOnEnableState, self.addonName, character)
	if not ok or type(enabled) ~= "number" or enabled <= 0 then
		return false
	end
	-- demandLoaded=true keeps an installed, unloaded LoD component eligible.
	local loadable
	ok, loadable = pcall(C_AddOns.IsAddOnLoadable, self.addonName, character, true)
	return ok and loadable == true
end

local function normalizeConsent()
	local db = GF.GetDB and GF.GetDB()
	local activity = GF.NetEaseActivity
	if not db then return end
	if db.neteaseIdentityActivityId ~= activity.ID then
		db.neteaseIdentityEnabled = false
		db.neteaseIdentityActivityId = activity.ID
		local filter = GF.MythicPlusBrowseFilter
		if filter and filter.ResetNewbieActivity then filter:ResetNewbieActivity(activity.ID) end
	end
	if not activity:IsSupportedClient() then db.neteaseIdentityEnabled = false end
	if not db.neteaseIdentityEnabled or not activity:IsActive() then
		local filter = GF.MythicPlusBrowseFilter
		if filter and filter.SetNewbieOnly then filter:SetNewbieOnly(false) end
	end
	return db
end

function Module:EnsureLoaded()
	if not GF.NetEaseActivity:IsSupportedClient() then
		return false, "unsupported-locale"
	end
	if self.loading then return false, "loading" end
	if self.initialized then return true end
	self.loading = true
	local ok, loaded, reason = pcall(GF.Compat.LoadAddOn, self.addonName)
	self.loading = false
	if not ok or loaded ~= true or self.ready ~= true then
		self.failureReason = not ok and "load-error"
			or reason or "incompatible-component"
		return false, self.failureReason
	end
	self.failureReason = nil
	self.initialized = true
	Service:Init()
	Service:OnPlayerLogin()
	Service:ScheduleRefresh("component-loaded")
	return true
end

function Service:IsUserEnabled()
	local db = GF.GetDB and GF.GetDB()
	return GF.NetEaseActivity:IsSupportedClient() and db ~= nil
		and db.neteaseIdentityEnabled == true
		and db.neteaseIdentityActivityId == GF.NetEaseActivity.ID
end

function Service:Init()
	normalizeConsent()
	if self:IsUserEnabled() and GF.NetEaseActivity:IsActive() then
		Module:EnsureLoaded()
	end
end

function Service:OnPlayerLogin()
	self:Init()
end

function Service:SetEnabled(enabled)
	local db = normalizeConsent()
	if not db then return false end
	if enabled ~= true then
		db.neteaseIdentityEnabled = false
		normalizeConsent()
		return false
	end
	if not GF.NetEaseActivity:IsActive() then return false end
	if not Module:EnsureLoaded() then return false end
	return self:SetEnabled(true)
end

function Service:IsEnabled() return false end
function Service:CanEnable() return false end
function Service:GetAPI() return nil end
function Service:GetIdentityProjection() return nil end
function Service:GetGroupProjection() return nil end
function Service:IsQueryPending() return false end
function Service:CanRefreshAPIStatus() return false, "component-unloaded" end
function Service:RefreshAPIStatus() return false, "component-unloaded" end
function Service:GetServiceStatus() return "disabled", "component-unloaded" end
function Service:GetAPIStatusProjection()
	return { status = "disabled", reason = "component-unloaded" }
end
function Service:GetAPIStatusIndicator() return "disabled" end
function Service:GetAPIStatusCountdown() return nil end

function Service:AddListener(callback)
	if type(callback) ~= "function" then return false end
	self.listeners = self.listeners or {}
	self.listeners[#self.listeners + 1] = callback
	return true
end
