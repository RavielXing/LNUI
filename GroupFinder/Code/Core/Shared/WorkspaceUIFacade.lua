local _, GF = ...

-- Core and background consumers stay in the host. Explicit window actions
-- load only the complete workspace definitions; passive calls never load UI.
local Module = {
	addonName = "GroupFinder_WorkspaceUI",
	apiVersion = 1,
	state = "unloaded",
}
GF.WorkspaceUIModule = Module

local main = GF.MainFrame or {}
GF.MainFrame = main
local forwards = {}

local function readable(value)
	local compat = GF.Compat
	return compat and type(compat.IsAccessibleValue) == "function"
		and compat.IsAccessibleValue(value) == true
end

function Module:IsAvailable()
	if self.state == "ready" then return true end
	if self.state == "loading" then return self.definitionsReady == true end
	if self.state == "failed" then return false end
	local addons = C_AddOns
	if not (addons and type(addons.GetAddOnEnableState) == "function"
		and type(addons.IsAddOnLoadable) == "function"
		and type(addons.IsAddOnLoadOnDemand) == "function"
		and type(UnitGUID) == "function") then return false end
	local ok, character = pcall(UnitGUID, "player")
	if not ok or not readable(character) or type(character) ~= "string"
		or character == "" then return false end
	local enabled
	ok, enabled = pcall(addons.GetAddOnEnableState, self.addonName, character)
	if not ok or not readable(enabled) or type(enabled) ~= "number"
		or enabled <= 0 then return false end
	local demand
	ok, demand = pcall(addons.IsAddOnLoadOnDemand, self.addonName)
	if not ok or not readable(demand) or demand ~= true then return false end
	local loadable
	ok, loadable = pcall(addons.IsAddOnLoadable, self.addonName, character, true)
	return ok and readable(loadable) and loadable == true
end

local function verifyDefinitions()
	if GF.MainFrame ~= main then return false, "namespace-replaced" end
	for _, entry in ipairs(forwards) do
		local method = rawget(main, entry.name)
		if type(method) ~= "function" or method == entry.forward then
			return false, "missing-method:" .. entry.name
		end
	end
	if not (GF.WindowShellPresenter and GF.WindowShellPresenter._view == main
		and GF.WorkspaceRouter and GF.BrowsePanel and GF.CreatePanel
		and GF.RaidSeekingPanel and GF.MythicPlusWorkspace) then
		return false, "workspace-definitions-incomplete"
	end
	return true
end

function Module:FinalizeDefinitions(apiVersion)
	if self.state ~= "loading" and self.state ~= "unloaded" then
		return false, "invalid-component-load-state"
	end
	if apiVersion ~= self.apiVersion then return false, "incompatible-component" end
	local ready, reason = verifyDefinitions()
	if ready ~= true then return false, reason end
	if self.navigationDirty == true then
		-- Preserve the same deferred navigation refresh that the original hidden
		-- main window received from availability/permission lifecycle events.
		GF.WindowShellPresenter._navDirty = true
		self.navigationDirty = nil
	end
	self.definitionsReady = true
	-- The native addon manager may explicitly load the component without
	-- calling our facade. Definitions alone still do not construct any Frame.
	if self.state == "unloaded" then self.state = "ready" end
	return true
end

local function restoreForwards()
	-- LoadAddOn can execute a partial file list before reporting failure.
	-- Reinstall the guarded entry points so a later click cannot enter that UI.
	GF.MainFrame = main
	for _, entry in ipairs(forwards) do main[entry.name] = entry.forward end
end

local function noticeFailure(reason)
	if Module.failureNoticeShown then return end
	local message = GF.L and GF.L.WORKSPACE_UI_LOAD_FAILED
	if type(message) == "string" and type(GF.ShowWarningMessage) == "function" then
		Module.failureNoticeShown = true
		pcall(GF.ShowWarningMessage, message:format(tostring(reason)))
	end
end

local function fail(reason)
	Module.state = "failed"
	Module.failureReason = readable(reason) and type(reason) == "string" and reason or "definition-load-failed"
	Module.definitionsReady = nil
	restoreForwards()
	noticeFailure(Module.failureReason)
	return false, Module.failureReason
end

function Module:EnsureLoaded()
	local lifecycle = GF.RuntimeLifecycle
	if not (lifecycle and type(lifecycle.RequestAccess) == "function")
		or lifecycle:RequestAccess() ~= true then return false, "runtime-access" end
	if self.state == "ready" then
		-- An external native LoadAddOn can finish the files before its synchronous
		-- ADDON_LOADED callbacks finish. Actions must wait for the complete load.
		local fullyLoaded = GF.Compat and GF.Compat.IsAddOnFullyLoaded
		if type(fullyLoaded) == "function" and fullyLoaded(self.addonName) ~= true then
			return false, "loading"
		end
		return true
	end
	if self.state == "loading" then return false, "loading" end
	if self.state == "failed" then return false, self.failureReason end
	if self:IsAvailable() ~= true then
		noticeFailure("component-unavailable")
		return false, "component-unavailable"
	end
	local loader = GF.Compat and GF.Compat.LoadAddOn
	if type(loader) ~= "function" then return fail("loader-unavailable") end
	self.state = "loading"
	local ok, loaded, reason = pcall(loader, self.addonName)
	if not ok or loaded ~= true then
		return fail(ok and (reason or "load-rejected") or "load-error")
	end
	if self.definitionsReady ~= true then return fail("incompatible-component") end
	local ready
	ready, reason = verifyDefinitions()
	if ready ~= true then return fail(reason) end
	self.state, self.failureReason = "ready", nil
	return true
end

local function forwardAction(name)
	local forward
	forward = function(_, ...)
		local loaded, reason = Module:EnsureLoaded()
		if loaded ~= true then return false, reason end
		local nav = GF.NavData
		if nav and type(nav.GetLoadedTree) == "function"
			and nav.GetLoadedTree() == nil and type(nav.GetTree) == "function"
		then nav.GetTree() end
		local method = rawget(main, name)
		if type(method) ~= "function" or method == forward then
			return fail("missing-method:" .. name)
		end
		return method(main, ...)
	end
	main[name] = forward
	forwards[#forwards + 1] = { name = name, forward = forward }
end

for _, name in ipairs({
	"OpenFrame", "OpenRoute", "OpenBrowseTab", "OpenCreateTab",
	"OpenRaidConversation", "OpenMythicPlusTab", "OpenSettingsTab",
	"Toggle", "ToggleRoute", "ToggleSeasonRating", "Init", "Preload", "RequestPreload",
}) do forwardAction(name) end

function main:IsUserVisible() return false end
function main:IsSurfacePreloadActive() return false end
function main:HideFrame() return false end
function main:HasActiveListing()
	local session = GF.RecruitmentSession
	local hasActive = session and session.HasActive
	if type(hasActive) ~= "function" then return false end
	local ok, active = pcall(hasActive, session)
	return ok and readable(active) and active == true
end

function main:OnAvailabilityUpdate()
	Module.navigationDirty = true
	return false, "deferred"
end

function main:OnPremadePermissionUpdate()
	Module.navigationDirty = true
	return false, "deferred"
end

-- FindGroupTab remains a host-owned dynamic facade, with all existing public
-- getters/methods available before the first main-window action. No Frame,
-- event subscription, timer, preload caller, forced GC or UI state is added.
