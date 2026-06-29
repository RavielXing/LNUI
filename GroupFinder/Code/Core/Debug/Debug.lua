local _, GF = ...

GF.Debug = GF.Debug or {}
local Debug = GF.Debug

local function printChat(message, opts)
	if GF.ShowStatusMessage then
		GF.ShowStatusMessage(message, opts)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and message and message ~= "" then
		DEFAULT_CHAT_FRAME:AddMessage(tostring(message))
	end
end

local function normalizeSlashCommand(msg)
	msg = tostring(msg or "")
	msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
	return msg, string.lower(msg)
end

local function refreshDebugPanel()
	if GF.DebugPanel and GF.DebugPanel.Refresh then
		GF.DebugPanel:Refresh()
	end
end

local function selectDebugTab()
	if GF.MainFrame and GF.MainFrame.OpenDebugTab then
		GF.MainFrame:OpenDebugTab()
		return
	end
	if GF.MainFrame and GF.MainFrame.ShowFrame then
		GF.MainFrame:ShowFrame()
	end
	if GF.TabBar and GF.TabBar.SelectTab then
		GF.TabBar:SelectTab(GF.TAB_DEBUG)
	end
end

local function clearSavedLocaleOverride()
	if type(GroupFinderDB) == "table" then
		GroupFinderDB.debugForceLocale = nil
	end
	local db = GF.GetDB and GF.GetDB()
	if db then
		db.debugForceLocale = nil
	end
	if GF.db and type(GF.db) == "table" then
		GF.db.debugForceLocale = nil
	end
end

local function refreshLocaleSurfaces()
	if GF.MainFrame and GF.MainFrame.RefreshLocale then
		GF.MainFrame:RefreshLocale()
	end
end

local function selectFallbackTab()
	if not (GF.TabBar and GF.TabBar.GetCurrent and GF.TabBar.SelectTab) then
		return
	end
	if GF.TabBar:GetCurrent() == GF.TAB_DEBUG then
		GF.TabBar:SelectTab(GF.TAB_SETTINGS)
	end
end

function Debug:IsDebugModeEnabled()
	local db = GF.GetDB and GF.GetDB()
	return db and db.debugModeEnabled == true
end

function Debug:SetDebugModeEnabled(enabled, opts)
	opts = opts or {}
	local db = GF.GetDB and GF.GetDB()
	if db then
		db.debugModeEnabled = enabled == true
	end
	if GF.TabBar and GF.TabBar.SetDebugTabVisible then
		GF.TabBar:SetDebugTabVisible(enabled == true)
	end
	if enabled then
		if opts.openTab then
			selectDebugTab()
		end
		printChat((GF.L and GF.L.DEBUG_MODE_ON) or "GroupFinder: debug mode enabled.", { semantic = true })
	else
		selectFallbackTab()
		if GF.TabBar and GF.TabBar.SetDebugTabVisible then
			GF.TabBar:SetDebugTabVisible(false)
		end
		self:RestoreSystemLocale({ silent = true })
		printChat((GF.L and GF.L.DEBUG_MODE_OFF) or "GroupFinder: debug mode disabled.", { semantic = true })
	end
	refreshDebugPanel()
end

function Debug:RefreshApplicantTestDataView()
	if GF.MainFrame and GF.MainFrame.OpenCreateTab then
		GF.MainFrame:OpenCreateTab()
	elseif GF.MainFrame and GF.MainFrame.OpenFrame then
		GF.MainFrame:OpenFrame()
	elseif GF.MainFrame and GF.MainFrame.Show then
		GF.MainFrame:Show()
	end
	if GF.MainFrame and GF.MainFrame.UpdateCreateTab then
		GF.MainFrame:UpdateCreateTab()
	end
	if GF.ApplicantsPanel and GF.ApplicantsPanel.Refresh then
		GF.ApplicantsPanel:Refresh()
	end
end

function Debug:SetApplicantTestDataEnabled(enabled, opts)
	opts = opts or {}
	local L = GF.L or {}
	if not (GF.ApplicantTestData and GF.ApplicantTestData.SetEnabled) then
		printChat(L.DEBUG_APPLICANT_TEST_UNAVAILABLE or "GroupFinder: applicant test data is unavailable.", { semantic = true })
		return false
	end
	if opts.scenario and GF.ApplicantTestData.SetScenario then
		GF.ApplicantTestData:SetScenario(opts.scenario)
	end
	if opts.extraRows ~= nil and GF.ApplicantTestData.SetExtraRowCount then
		GF.ApplicantTestData:SetExtraRowCount(opts.extraRows)
	end
	GF.ApplicantTestData:SetEnabled(enabled == true)
	self:RefreshApplicantTestDataView()
	printChat(enabled
		and (L.DEBUG_APPLICANT_TEST_ON or "GroupFinder: applicant test data enabled.")
		or (L.DEBUG_APPLICANT_TEST_OFF or "GroupFinder: applicant test data disabled."), { semantic = true })
	refreshDebugPanel()
	return true
end

function Debug:ApplyApplicantScenario(scenario)
	local L = GF.L or {}
	local scenarioConfig = {
		basic = { extraRows = 0, label = L.DEBUG_SCENARIO_BASIC or "Basic" },
		full = { extraRows = 12, label = L.DEBUG_SCENARIO_FULL or "Full" },
		scroll = { extraRows = 30, label = L.DEBUG_SCENARIO_SCROLL or "Scroll stress" },
	}
	local config = scenarioConfig[scenario] or scenarioConfig.full
	self:SetApplicantTestDataEnabled(true, {
		scenario = scenario,
		extraRows = config.extraRows,
	})
	printChat(string.format(L.DEBUG_SCENARIO_APPLIED_FMT or "GroupFinder: switched to %s test data.", config.label))
end

function Debug:GetApplicantTestDataStatus()
	local atd = GF.ApplicantTestData
	local enabled = atd and atd.IsEnabled and atd:IsEnabled() == true
	local scenario = atd and atd.GetScenario and atd:GetScenario() or "full"
	local extraRows = atd and atd.GetExtraRowCount and atd:GetExtraRowCount() or 0
	return {
		enabled = enabled,
		scenario = scenario,
		extraRows = extraRows,
	}
end

function Debug:PrintHelp()
	printChat((GF.L and GF.L.DEBUG_HELP) or "GroupFinder: debug commands: /gf 开启调试模式, /gf 关闭调试模式, /gf testdata.")
end

function Debug:ForceLocale(locale)
	if locale ~= "enUS" and locale ~= "zhCN" then
		return false
	end
	clearSavedLocaleOverride()
	if not (GF.Locale and GF.Locale.SetDebugLocale and GF.Locale:SetDebugLocale(locale)) then
		return false
	end
	refreshLocaleSurfaces()
	local L = GF.L or {}
	local label = locale == "enUS"
		and (L.DEBUG_FORCE_LOCALE_ENUS_LABEL or "English")
		or (L.DEBUG_FORCE_LOCALE_ZHCN_LABEL or "Simplified Chinese")
	printChat(string.format(L.DEBUG_FORCE_LOCALE_RELOAD_FMT or "GroupFinder: switched to %s for debug mode.", label))
	return true
end

function Debug:RestoreSystemLocale(opts)
	opts = opts or {}
	clearSavedLocaleOverride()
	if not (GF.Locale and GF.Locale.ClearDebugLocale) then
		return false
	end
	local wasDebugLocale = GF.Locale.IsDebugLocaleActive and GF.Locale:IsDebugLocaleActive()
	GF.Locale:ClearDebugLocale()
	if wasDebugLocale then
		refreshLocaleSurfaces()
		if not opts.silent then
			printChat((GF.L and GF.L.DEBUG_LOCALE_RESTORED) or "GroupFinder: system locale restored.")
		end
	end
	return wasDebugLocale == true
end

function Debug:RunAction(actionID)
	if actionID == "showTab" then
		self:SetDebugModeEnabled(true, { openTab = true })
		return true
	end
	if actionID == "hideTab" then
		self:SetDebugModeEnabled(false)
		return true
	end
	if actionID == "applicantsToggle" then
		local enabled = not (GF.ApplicantTestData and GF.ApplicantTestData.IsEnabled and GF.ApplicantTestData:IsEnabled())
		return self:SetApplicantTestDataEnabled(enabled)
	end
	if actionID == "applicantsOn" then
		return self:SetApplicantTestDataEnabled(true)
	end
	if actionID == "applicantsOff" then
		return self:SetApplicantTestDataEnabled(false)
	end
	if actionID == "refreshApplicants" then
		self:RefreshApplicantTestDataView()
		refreshDebugPanel()
		return true
	end
	if actionID == "scenarioBasic" then
		self:ApplyApplicantScenario("basic")
		return true
	end
	if actionID == "scenarioFull" then
		self:ApplyApplicantScenario("full")
		return true
	end
	if actionID == "scenarioScroll" then
		self:ApplyApplicantScenario("scroll")
		return true
	end
	if actionID == "help" then
		self:PrintHelp()
		return true
	end
	if actionID == "forceLocaleEnUS" then
		return self:ForceLocale("enUS")
	end
	if actionID == "forceLocaleZhCN" then
		return self:ForceLocale("zhCN")
	end
	return false
end

function Debug:HandleSlashCommand(msg)
	local raw, cmd = normalizeSlashCommand(msg)
	if raw == "开启调试模式" or cmd == "debug on" then
		return self:RunAction("showTab")
	end
	if raw == "关闭调试模式" or cmd == "debug off" then
		return self:RunAction("hideTab")
	end
	if cmd == "testdata" or raw == "测试数据" or cmd == "debug applicants" then
		return self:RunAction("applicantsToggle")
	end
	if cmd == "testdata on" or cmd == "debug applicants on" then
		return self:RunAction("applicantsOn")
	end
	if cmd == "testdata off" or cmd == "debug applicants off" then
		return self:RunAction("applicantsOff")
	end
	if cmd == "testdata basic" or raw == "测试数据 精简" then
		return self:RunAction("scenarioBasic")
	end
	if cmd == "testdata full" or raw == "测试数据 综合" then
		return self:RunAction("scenarioFull")
	end
	if cmd == "testdata scroll" or raw == "测试数据 滚动" then
		return self:RunAction("scenarioScroll")
	end
	if cmd == "debug locale en" or cmd == "debug locale enus" or raw == "英文" then
		return self:RunAction("forceLocaleEnUS")
	end
	if cmd == "debug locale zh" or cmd == "debug locale zhcn" or raw == "简体中文" then
		return self:RunAction("forceLocaleZhCN")
	end
	if cmd == "debug help" or raw == "调试帮助" then
		return self:RunAction("help")
	end
	return false
end
