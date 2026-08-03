local _, GF = ...

GF.Hook = {}

local origOpenBestWindow
local origFindQuestGroup
local refreshTicket = 0

local function dismissPanel(panel)
	local visible = panel and type(panel.IsShown) == "function"
		and panel:IsShown()
	if visible and type(HideUIPanel) == "function" then
		HideUIPanel(panel)
	end
end

local function hideBlizzardPremadeFrames()
	dismissPanel(PVEFrame)
	dismissPanel(PVPUIFrame)
end

local function hasActiveOutgoingApplication()
	local applications = GF.Apply
	local query = applications and applications.HasActiveApplication
	return type(query) == "function" and query(applications) == true
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

local function shouldPreferOpen()
	local db = GF.GetDB and GF.GetDB()
	return db and db.preferOpen
end

local function callOriginalFindQuestGroup(questID, isFromGreenEyeButton)
	if origFindQuestGroup then
		return origFindQuestGroup(questID, isFromGreenEyeButton)
	end
end

local function isGreenEyeSource(value)
	if type(canaccessvalue) == "function" then
		local ok, accessible = pcall(canaccessvalue, value)
		if not ok or accessible ~= true then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret == true then
			return false
		end
	end
	return value == true
end

local function replacementFindQuestGroup(questID, isFromGreenEyeButton)
	if isGreenEyeSource(isFromGreenEyeButton) and shouldPreferOpen() then
		if GF.FindGroupTab
		and type(GF.FindGroupTab.FindQuestGroup) == "function"
		then
			local requestState = {}
			local ok, tookOwnership = pcall(
				GF.FindGroupTab.FindQuestGroup,
				GF.FindGroupTab,
				questID,
				requestState
			)
			if (ok and tookOwnership == true)
				or requestState.tookOwnership == true
			then
				hideBlizzardPremadeFrames()
				return
			end
		end
	end
	return callOriginalFindQuestGroup(questID, isFromGreenEyeButton)
end

local function captureOriginalOpenBestWindow()
	local current = _G.LFGListUtil_OpenBestWindow
	if current and current ~= replacementOpenBestWindow and not origOpenBestWindow then
		origOpenBestWindow = current
	end
	return current
end

local function captureOriginalFindQuestGroup()
	local current = _G.LFGListUtil_FindQuestGroup
	if current and current ~= replacementFindQuestGroup and not origFindQuestGroup then
		origFindQuestGroup = current
	end
	return current
end

local function applyPreferOpenReplacement()
	if not shouldPreferOpen() then
		return
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	local currentOpen = captureOriginalOpenBestWindow()
	if currentOpen and _G.LFGListUtil_OpenBestWindow ~= replacementOpenBestWindow then
		_G.LFGListUtil_OpenBestWindow = replacementOpenBestWindow
	end
	local currentQuest = captureOriginalFindQuestGroup()
	if currentQuest and _G.LFGListUtil_FindQuestGroup ~= replacementFindQuestGroup then
		_G.LFGListUtil_FindQuestGroup = replacementFindQuestGroup
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
	captureOriginalOpenBestWindow()
	captureOriginalFindQuestGroup()
	if db.preferOpen then
		applyPreferOpenReplacement()
		schedulePreferOpenReassertion()
	elseif _G.LFGListUtil_OpenBestWindow == replacementOpenBestWindow then
		_G.LFGListUtil_OpenBestWindow = origOpenBestWindow
	end
	if not db.preferOpen and _G.LFGListUtil_FindQuestGroup == replacementFindQuestGroup then
		_G.LFGListUtil_FindQuestGroup = origFindQuestGroup
	end
end
