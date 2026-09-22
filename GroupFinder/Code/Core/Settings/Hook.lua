local _, GF = ...

GF.Hook = GF.Hook or {}

-- Blizzard's PVEFrame owns both the premade-group and PvP side panels. Never
-- replace its globals: a replacement taints the shared execution chain that
-- reaches the protected PvP queue buttons. These hooks observe completion
-- only; NativeEntryRouter decides whether an already-opened PvE premade route
-- may hand over to GroupFinder on the next frame.
local hooked = {
	openBestWindow = false,
	pveShowFrame = false,
	pveToggleFrame = false,
	questEyeSetup = false,
}

local function getRouter()
	return GF.NativeEntryRouter
end

local function installGlobalPostHook(key, globalName, callback)
	if hooked[key] then
		return true
	end
	if type(hooksecurefunc) ~= "function"
		or type(_G[globalName]) ~= "function"
	then
		return false
	end
	local ok = pcall(hooksecurefunc, globalName, callback)
	if ok then
		hooked[key] = true
	end
	return ok
end

local function installQuestEyeSetupHook()
	if hooked.questEyeSetup then
		return true
	end
	local mixin = _G.QuestObjectiveFindGroupButtonMixin
	if type(hooksecurefunc) ~= "function"
		or type(mixin) ~= "table"
		or type(mixin.SetUp) ~= "function"
	then
		return false
	end
	local ok = pcall(hooksecurefunc, mixin, "SetUp", function(button, questID)
		local router = getRouter()
		if router and type(router.InstallQuestEyeProxy) == "function" then
			router:InstallQuestEyeProxy(button, questID)
		end
	end)
	if ok then
		hooked.questEyeSetup = true
	end
	return ok
end

local function installHooks()
	installGlobalPostHook("pveShowFrame", "PVEFrame_ShowFrame", function(sidePanelName, selection)
		local router = getRouter()
		if router and type(router.OnNativePVEFrameShowFrame) == "function" then
			router:OnNativePVEFrameShowFrame(sidePanelName, selection)
		end
	end)
	installGlobalPostHook("pveToggleFrame", "PVEFrame_ToggleFrame", function(sidePanelName, selection)
		local router = getRouter()
		if router and type(router.OnNativePVEFrameToggleFrame) == "function" then
			router:OnNativePVEFrameToggleFrame(sidePanelName, selection)
		end
	end)
	installGlobalPostHook("openBestWindow", "LFGListUtil_OpenBestWindow", function(toggle)
		local router = getRouter()
		if router and type(router.OnNativeOpenBestWindow) == "function" then
			router:OnNativeOpenBestWindow(toggle)
		end
	end)
	installQuestEyeSetupHook()
end

function GF.Hook.OnGFUIClosed()
	-- Do not force Blizzard LFG active-panel refresh here; ApplicationViewer
	-- can handle secret listing text only in an untainted chain.
end

function GF.Hook.Refresh()
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	installHooks()
	local router = getRouter()
	if not router then
		return
	end
	if type(router.RefreshQuestEyeProxies) == "function" then
		router:RefreshQuestEyeProxies()
	end
	if type(router.ShouldPreferOpen) == "function"
		and router:ShouldPreferOpen() ~= true
		and type(router.CancelPendingPVEEntryRoute) == "function"
	then
		router:CancelPendingPVEEntryRoute()
	end
end
