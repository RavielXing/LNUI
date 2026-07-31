local _, GF = ...

GF.DebugPanel = {}
local DP = GF.DebugPanel

local STATUS_COLOR_ON = { 0.1, 0.95, 0.22, 1 }
local STATUS_COLOR_OFF = { 1, 0.18, 0.12, 1 }
local STATUS_COLOR_SCROLL = { 1, 0.82, 0, 1 }
local STATUS_COLOR_NORMAL = { 0.92, 0.90, 0.84, 1 }

local function getScenarioLabel(scenario)
	local L = GF.L or {}
	if scenario == "basic" then
		return L.DEBUG_SCENARIO_BASIC or "Basic"
	end
	if scenario == "scroll" then
		return L.DEBUG_SCENARIO_SCROLL or "Scroll stress"
	end
	return L.DEBUG_SCENARIO_FULL or "Full"
end

local function getStateText(enabled)
	local L = GF.L or {}
	return enabled and (L.DEBUG_STATE_ON or "On")
		or (L.DEBUG_STATE_OFF or "Off")
end

local function setStatusValue(value, text, color)
	if not value then
		return
	end
	value:SetText(text or "")
	color = color or STATUS_COLOR_NORMAL
	value:SetTextColor(color[1], color[2], color[3], color[4])
end

function DP:Init(parent)
	if self.root then
		return
	end
	self.parent = parent
	local surface = GF.DebugSurface:Create(parent, {
		onAfterAction = function()
			DP:Refresh()
		end,
	})
	self.surface = surface
	self.root = surface.root
	self.scroll = surface.scroll
	self.scrollBar = surface.scrollBar
	self.body = surface.body

	local section = surface:CreateSection(
		"DEBUG_STATUS_SECTION",
		"Debug status")
	local statusValues = surface:AddStatusGrid(section, {
		left = {
			{
				id = "debugMode",
				localeKey = "DEBUG_MODE_STATE",
				fallback = "Debug tab",
			},
			{
				id = "testData",
				localeKey = "DEBUG_TESTDATA_STATE",
				fallback = "Applicant test data",
			},
			{
				id = "scenario",
				localeKey = "DEBUG_TESTDATA_SCENARIO",
				fallback = "Current scenario",
			},
			{
				id = "extraRows",
				localeKey = "DEBUG_TESTDATA_EXTRA_ROWS",
				fallback = "Extra scroll rows",
			},
		},
		right = {
			{
				id = "mplusTestData",
				localeKey = "MPLUS_DEBUG_TEST_DATA_SECTION",
				fallback = "Mythic+ test data",
			},
			{
				id = "laonongSource",
				localeKey = "DEBUG_LAONONG_SOURCE",
				fallback = "Laonong source",
			},
			{
				id = "laonongCount",
				localeKey = "DEBUG_LAONONG_COUNT",
				fallback = "Laonong entries",
			},
			{
				id = "laonongRevision",
				localeKey = "DEBUG_LAONONG_REVISION",
				fallback = "Laonong revision",
			},
		},
	})
	self.debugModeValue = statusValues.debugMode
	self.testDataValue = statusValues.testData
	self.scenarioValue = statusValues.scenario
	self.extraRowsValue = statusValues.extraRows
	self.mplusTestDataValue = statusValues.mplusTestData
	self.laonongSourceValue = statusValues.laonongSource
	self.laonongCountValue = statusValues.laonongCount
	self.laonongRevisionValue = statusValues.laonongRevision
	surface:FinishSection(section)

	section = surface:CreateSection(
		"DEBUG_MEETING_STONE_TEST_DATA_SECTION",
		"Meeting Stone test data")
	surface:AddButtonRow(
		section,
		"DEBUG_TESTDATA_STATE",
		"Applicant test data",
		{
			{
				localeKey = "DEBUG_ACTION_ENABLE_TESTDATA",
				fallback = "Enable data",
				actionID = "applicantsOn",
			},
			{
				localeKey = "DEBUG_ACTION_DISABLE_TESTDATA",
				fallback = "Disable data",
				actionID = "applicantsOff",
			},
			{
				localeKey = "DEBUG_ACTION_REFRESH_APPLICANTS",
				fallback = "Refresh applicants",
				actionID = "refreshApplicants",
			},
		})
	surface:AddButtonRow(
		section,
		"DEBUG_TESTDATA_SCENARIO",
		"Current scenario",
		{
			{
				localeKey = "DEBUG_ACTION_SCENARIO_BASIC",
				fallback = "Basic scenario",
				actionID = "scenarioBasic",
			},
			{
				localeKey = "DEBUG_ACTION_SCENARIO_FULL",
				fallback = "Full scenario",
				actionID = "scenarioFull",
			},
			{
				localeKey = "DEBUG_ACTION_SCENARIO_SCROLL",
				fallback = "Scroll stress",
				actionID = "scenarioScroll",
			},
		})
	surface:FinishSection(section)

	section = surface:CreateSection(
		"MPLUS_DEBUG_TEST_DATA_SECTION",
		"Mythic+ test data")
	surface:AddButtonRow(
		section,
		"MPLUS_DEBUG_ENABLE_TEST_DATA",
		"Enable Mythic+ test data",
		{
			{
				localeKey = "MPLUS_DEBUG_ENABLE",
				fallback = "Enable",
				actionID = "mplusTestData",
			},
			{
				localeKey = "MPLUS_DEBUG_CLEAR",
				fallback = "Clear",
				actionID = "mplusTestDataOff",
			},
		})
	surface:AddButtonRow(
		section,
		"MPLUS_DEBUG_ADDITIONAL_GROUPS",
		"Additional carpool groups",
		{
			{
				localeKey = "MPLUS_DEBUG_ENABLE_GROUP_1",
				fallback = "Enable +1 Group",
				actionID = "mplusTestData1",
			},
			{
				localeKey = "MPLUS_DEBUG_ENABLE_GROUP_2",
				fallback = "Enable +2 Groups",
				actionID = "mplusTestData2",
			},
			{
				localeKey = "MPLUS_DEBUG_ENABLE_GROUP_3",
				fallback = "Enable +3 Groups",
				actionID = "mplusTestData3",
			},
		})
	surface:FinishSection(section)

	section = surface:CreateSection(
		"MPLUS_DEBUG_TELEPORT_SECTION",
		"Teleport diagnostics")
	surface:AddButtonRow(
		section,
		"MPLUS_DEBUG_TELEPORT_MAPPING",
		"Hero's Path mapping",
		{
			{
				localeKey = "MPLUS_DEBUG_DUMP_MAPPING",
				fallback = "Export mapping",
				actionID = "mplusTeleportDump",
			},
		})
	surface:AddInputActionRow(
		section,
		"MPLUS_DEBUG_TELEPORT_DIALOG_PREVIEW",
		"Teleport dialog preview",
		"MPLUS_DEBUG_TELEPORT_MAP_ID_PLACEHOLDER",
		"mapID",
		{
			localeKey = "MPLUS_DEBUG_PREVIEW_DIALOG",
			fallback = "Preview dialog",
			actionID = "mplusTeleportDialog",
		})
	surface:FinishSection(section)

	section = surface:CreateSection(
		"DEBUG_AUXILIARY_SECTION",
		"Utilities")
	surface:AddButtonRow(
		section,
		"DEBUG_LOCALE_ROW",
		"Switch language",
		{
			{
				localeKey = "DEBUG_ACTION_FORCE_ENUS",
				fallback = "English",
				actionID = "forceLocaleEnUS",
			},
			{
				localeKey = "DEBUG_ACTION_FORCE_ZHCN",
				fallback = "Simplified Chinese",
				actionID = "forceLocaleZhCN",
			},
			{
				localeKey = "DEBUG_ACTION_FORCE_ZHTW",
				fallback = "Traditional Chinese",
				actionID = "forceLocaleZhTW",
			},
		})
	surface:AddButtonRow(
		section,
		"DEBUG_COMMAND_SECTION",
		"Command entry",
		{
			{
				localeKey = "DEBUG_ACTION_PRINT_HELP",
				fallback = "Print commands",
				actionID = "help",
			},
		})
	surface:FinishSection(section)

	surface:Finalize()
	self.bodyH = surface.bodyH
	self:Refresh()
end

function DP:Refresh()
	if not self.root then
		return
	end
	local status = GF.Debug and GF.Debug.GetApplicantTestDataStatus
		and GF.Debug:GetApplicantTestDataStatus() or {}
	local debugEnabled = GF.Debug and GF.Debug.IsDebugModeEnabled
		and GF.Debug:IsDebugModeEnabled()
	if self.debugModeValue then
		setStatusValue(
			self.debugModeValue,
			getStateText(debugEnabled),
			debugEnabled and STATUS_COLOR_ON or STATUS_COLOR_OFF)
	end
	if self.testDataValue then
		setStatusValue(
			self.testDataValue,
			getStateText(status.enabled == true),
			status.enabled == true and STATUS_COLOR_ON or STATUS_COLOR_OFF)
	end
	if self.scenarioValue then
		local scenarioColor = status.scenario == "scroll"
			and STATUS_COLOR_SCROLL or STATUS_COLOR_NORMAL
		setStatusValue(
			self.scenarioValue,
			getScenarioLabel(status.scenario),
			scenarioColor)
	end
	if self.extraRowsValue then
		setStatusValue(
			self.extraRowsValue,
			tostring(status.extraRows or 0),
			STATUS_COLOR_NORMAL)
	end
	if self.mplusTestDataValue then
		local service = GF.MythicPlusDebugService
		local enabled = service and service.IsEnabled
			and service:IsEnabled() == true
		setStatusValue(
			self.mplusTestDataValue,
			getStateText(enabled),
			enabled and STATUS_COLOR_ON or STATUS_COLOR_OFF)
	end
	local laonongStatus = GF.GetLaonongFanDirectoryStatus
		and GF.GetLaonongFanDirectoryStatus() or {}
	if self.laonongSourceValue then
		setStatusValue(
			self.laonongSourceValue,
			laonongStatus.source or "unavailable",
			laonongStatus.ready and STATUS_COLOR_ON or STATUS_COLOR_OFF)
	end
	if self.laonongCountValue then
		setStatusValue(
			self.laonongCountValue,
			tostring(laonongStatus.count or 0),
			STATUS_COLOR_NORMAL)
	end
	if self.laonongRevisionValue then
		setStatusValue(
			self.laonongRevisionValue,
			tostring(laonongStatus.revision or 0),
			STATUS_COLOR_NORMAL)
	end
	self:UpdateScroll()
end

function DP:RefreshLocale()
	if not self.surface then
		return
	end
	self.surface:RefreshLocale()
	self:Refresh()
end

function DP:UpdateScroll()
	if self.surface then
		self.surface:UpdateScroll()
		self.bodyH = self.surface.bodyH
	end
end

function DP:Show()
	if self.surface then
		self.surface:Show()
		self:Refresh()
	end
end

function DP:Hide()
	if self.surface then
		self.surface:Hide()
	end
end
