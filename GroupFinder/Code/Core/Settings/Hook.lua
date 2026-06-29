local _, GF = ...

GF.Hook = {}

local origOpenBestWindow
local refreshTicket = 0

local function hideBlizzardPremadeFrames()
	if PVEFrame and PVEFrame.IsShown and PVEFrame:IsShown() and HideUIPanel then
		HideUIPanel(PVEFrame)
	end
	if PVPUIFrame and PVPUIFrame.IsShown and PVPUIFrame:IsShown() and HideUIPanel then
		HideUIPanel(PVPUIFrame)
	end
end

local function hasActiveOutgoingApplication()
	return GF.Apply and GF.Apply.HasActiveApplication and GF.Apply:HasActiveApplication()
end

local function selectGFTab(tabID)
	if not GF.TabBar then
		return
	end
	if GF.TabBar.Select then
		GF.TabBar:Select(tabID)
	elseif GF.TabBar.SelectTab then
		GF.TabBar:SelectTab(tabID)
	end
end

local function openGFFromPremadeEntry(toggle)
	if not GF.MainFrame then
		return
	end
	local targetTab = hasActiveOutgoingApplication() and GF.TAB_BROWSE or GF.TAB_CREATE
	local frame = GF.MainFrame.frame
	local currentTab = GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar:GetCurrent()
	if toggle and frame and frame:IsShown() and currentTab == targetTab then
		GF.MainFrame:HideFrame()
	else
		if targetTab == GF.TAB_BROWSE and GF.MainFrame.OpenBrowseTab then
			GF.MainFrame:OpenBrowseTab()
		elseif GF.MainFrame.OpenCreateTab then
			GF.MainFrame:OpenCreateTab()
		else
			GF.MainFrame:OpenFrame()
		end
		selectGFTab(targetTab)
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if GF.MainFrame and GF.MainFrame.frame and GF.MainFrame.frame:IsShown()
					and GF.TabBar then
					selectGFTab(targetTab)
				end
			end)
		end
	end
	hideBlizzardPremadeFrames()
end

local function replacementOpenBestWindow(toggle)
	openGFFromPremadeEntry(toggle)
end

local function captureOriginalOpenBestWindow()
	local current = _G.LFGListUtil_OpenBestWindow
	if current and current ~= replacementOpenBestWindow and not origOpenBestWindow then
		origOpenBestWindow = current
	end
	return current
end

local function shouldPreferOpen()
	local db = GF.GetDB and GF.GetDB()
	return db and db.preferOpen
end

local function applyPreferOpenReplacement()
	if not shouldPreferOpen() then
		return
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if not _G.LFGListUtil_OpenBestWindow then
		return
	end
	captureOriginalOpenBestWindow()
	if _G.LFGListUtil_OpenBestWindow ~= replacementOpenBestWindow then
		_G.LFGListUtil_OpenBestWindow = replacementOpenBestWindow
	end
end

local function schedulePreferOpenReassertion()
	if not (C_Timer and C_Timer.After) then
		return
	end
	local ticket = refreshTicket
	local function reassert()
		if ticket == refreshTicket then
			applyPreferOpenReplacement()
		end
	end
	C_Timer.After(0, reassert)
	C_Timer.After(1, reassert)
	C_Timer.After(3, reassert)
end

function GF.Hook.OnGFUIClosed()
	-- Do not force Blizzard LFG active-panel refresh here; ApplicationViewer can handle secret listing text only in an untainted chain.
end

function GF.Hook.Refresh()
	local db = GF.GetDB()
	refreshTicket = refreshTicket + 1
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if not LFGListUtil_OpenBestWindow then
		return
	end
	captureOriginalOpenBestWindow()
	if db.preferOpen then
		applyPreferOpenReplacement()
		schedulePreferOpenReassertion()
	elseif _G.LFGListUtil_OpenBestWindow == replacementOpenBestWindow then
		_G.LFGListUtil_OpenBestWindow = origOpenBestWindow
	end
end
