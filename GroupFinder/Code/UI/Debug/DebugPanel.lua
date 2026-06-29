local _, GF = ...

GF.DebugPanel = {}
local DP = GF.DebugPanel

local SCROLLBAR_WIDTH = 17
local SCROLLBAR_GAP = 2
local SCROLLBAR_RIGHT_INSET = 10
local SCROLLBAR_TOP_INSET = 8
local SCROLLBAR_BOTTOM_INSET = 8
local SCROLL_INSET_R = SCROLLBAR_WIDTH + SCROLLBAR_GAP + SCROLLBAR_RIGHT_INSET
local SCROLL_INSET_L = GF.SETTINGS_LAYOUT_INSET_L or 0

local CONTENT_TOP_OFFSET = 20
local CONTENT_BOTTOM_PADDING = 20
local SECTION_GAP = 16
local SECTION_TITLE_H = 40
local SECTION_TITLE_GAP = 14
local SECTION_BODY_INSET_X = 24
local SECTION_BODY_INSET_R = 40
local SECTION_TITLE_TEXT_INSET_X = 24
local SECTION_LABEL_TEXT_SIZE = GF.SECTION_HEADER_TEXT_SIZE or 14
local SECTION_ROW_TEXT_H = 28
local SECTION_ROW_H = 40
local SECTION_LABEL_X = 28
local SECTION_LABEL_W = 226
local SECTION_DIVIDER_X = 270
local SECTION_CONTROL_X = 304
local SECTION_CONTROL_INSET_R = 16
local SECTION_PANEL_EDGE_INSET = 3
local ACTION_BUTTON_W = 132
local ACTION_BUTTON_GAP = 10
local STATUS_COLOR_ON = { 0.1, 0.95, 0.22, 1 }
local STATUS_COLOR_OFF = { 1, 0.18, 0.12, 1 }
local STATUS_COLOR_SCROLL = { 1, 0.82, 0, 1 }
local STATUS_COLOR_NORMAL = { 0.92, 0.90, 0.84, 1 }

local function setTextureColor(texture, r, g, b, a)
	if not texture then
		return
	end
	if texture.SetColorTexture then
		texture:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
	else
		texture:SetTexture("Interface\\Buttons\\WHITE8X8")
		texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
end

local function styleFontString(fs, template)
	if not fs then
		return
	end
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fs, template or "GameFontNormal")
	end
end

local function applyFeaturePanelStyle(frame)
	if not frame then
		return
	end
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false,
			edgeSize = 12,
			insets = {
				left = SECTION_PANEL_EDGE_INSET,
				right = SECTION_PANEL_EDGE_INSET,
				top = SECTION_PANEL_EDGE_INSET,
				bottom = SECTION_PANEL_EDGE_INSET,
			},
		})
		frame:SetBackdropColor(0.03, 0.02, 0.01, 0.30)
		frame:SetBackdropBorderColor(0.55, 0.43, 0.18, 0.75)
		return
	end

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	setTextureColor(bg, 0.03, 0.02, 0.01, 0.30)
end

local function createPanelRule(parent, layer)
	local rule = parent:CreateTexture(nil, layer or "ARTWORK")
	setTextureColor(rule, 0.72, 0.52, 0.22, 0.16)
	return rule
end

local function createSection(parent, label, y)
	local section = CreateFrame("Frame", nil, parent)
	section._gfRowOffset = 0
	section._gfRowCount = 0
	section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	section:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)

	local title = CreateFrame("Frame", nil, section)
	title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
	title:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
	title:SetHeight(SECTION_TITLE_H)

	local titleBg = title:CreateTexture(nil, "BACKGROUND")
	titleBg:SetAllPoints(title)
	if GF.UI and GF.UI.TrySetAtlas and GF.UI.TrySetAtlas(titleBg, GF.BROWSE_HEADER_BACKGROUND_ATLAS or "housefinder_header-bg-gradient", false) then
		titleBg:SetVertexColor(1, 1, 1, 1)
	else
		setTextureColor(titleBg, 0, 0, 0, 0.45)
	end

	local titleText = GF.UI.CreateFontString(title, "OVERLAY", "GameFontNormal")
	titleText._gfFontSizeOverride = SECTION_LABEL_TEXT_SIZE
	titleText._gfFontFlagsOverride = "OUTLINE"
	styleFontString(titleText, "GameFontNormal")
	titleText:SetTextColor(1, 0.82, 0, 1)
	titleText:SetPoint("TOPLEFT", title, "TOPLEFT", SECTION_TITLE_TEXT_INSET_X, 0)
	titleText:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", -SECTION_TITLE_TEXT_INSET_X, 0)
	titleText:SetJustifyH("LEFT")
	titleText:SetJustifyV("MIDDLE")
	titleText:SetText(label or "")

	local panel = CreateFrame("Frame", nil, section, "BackdropTemplate")
	panel:SetPoint("TOPLEFT", section, "TOPLEFT", SECTION_BODY_INSET_X, -(SECTION_TITLE_H + SECTION_TITLE_GAP))
	panel:SetPoint("TOPRIGHT", section, "TOPRIGHT", -SECTION_BODY_INSET_R, -(SECTION_TITLE_H + SECTION_TITLE_GAP))
	panel:SetHeight(1)
	applyFeaturePanelStyle(panel)

	local divider = createPanelRule(panel)
	divider:SetPoint("TOPLEFT", panel, "TOPLEFT", SECTION_DIVIDER_X, -1)
	divider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", SECTION_DIVIDER_X, 1)
	divider:SetWidth(1)

	section.panel = panel
	return section
end

local function finishSection(section, y)
	local rowsHeight = section and section._gfRowOffset or 0
	local h = SECTION_TITLE_H + SECTION_TITLE_GAP + math.max(rowsHeight, 0)
	if section then
		section:SetHeight(h)
		if section.panel then
			section.panel:SetHeight(math.max(rowsHeight, 1))
		end
	end
	return y - h - SECTION_GAP
end

local function addDebugRow(section, labelText)
	local rowH = SECTION_ROW_H
	local offset = section._gfRowOffset or 0
	local rowIndex = (section._gfRowCount or 0) + 1
	local panel = section.panel or section
	local row = CreateFrame("Frame", nil, panel)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -offset)
	row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -offset)
	row:SetHeight(rowH)

	local rowBackground = row:CreateTexture(nil, "BACKGROUND", nil, -1)
	rowBackground:SetAllPoints(row)
	setTextureColor(rowBackground, 1, 0.82, 0, rowIndex % 2 == 1 and 0.018 or 0.008)

	if rowIndex > 1 then
		local rule = createPanelRule(row)
		rule:SetPoint("TOPLEFT", row, "TOPLEFT", 16, 0)
		rule:SetPoint("TOPRIGHT", row, "TOPRIGHT", -16, 0)
		rule:SetHeight(1)
		row.topRule = rule
	end

	local label = GF.UI.CreateFontString(row, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", row, "LEFT", SECTION_LABEL_X, 0)
	label:SetSize(SECTION_LABEL_W, SECTION_ROW_TEXT_H)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("MIDDLE")
	label:SetText(labelText or "")
	label._gfFontSizeOverride = SECTION_LABEL_TEXT_SIZE
	if label.SetTextColor then
		label:SetTextColor(0.92, 0.90, 0.84, 1)
	end
	styleFontString(label, "GameFontHighlight")

	local control = CreateFrame("Frame", nil, row)
	control:SetPoint("LEFT", row, "LEFT", SECTION_CONTROL_X, 0)
	control:SetPoint("RIGHT", row, "RIGHT", -SECTION_CONTROL_INSET_R, 0)
	control:SetHeight(rowH)

	row.label = label
	row.control = control
	section._gfRowOffset = offset + rowH
	section._gfRowCount = rowIndex
	if section.panel then
		section.panel:SetHeight(math.max(section._gfRowOffset, 1))
	end
	return row, control, label
end

local function addStatusRow(section, labelText)
	local _, control = addDebugRow(section, labelText)

	local value = GF.UI.CreateFontString(control, "OVERLAY", "GameFontHighlight")
	value:SetPoint("LEFT", control, "LEFT", 0, 0)
	value:SetPoint("RIGHT", control, "RIGHT", 0, 0)
	value:SetHeight(SECTION_ROW_TEXT_H)
	value:SetJustifyH("LEFT")
	value:SetJustifyV("MIDDLE")
	styleFontString(value, "GameFontHighlight")
	return value
end

local function createActionButton(parent, label, actionID, index)
	local button = GF.UI.CreatePanelButton(parent, label, ACTION_BUTTON_W, true)
	button:SetPoint("LEFT", parent, "LEFT", ((index - 1) * (ACTION_BUTTON_W + ACTION_BUTTON_GAP)), 0)
	button:SetScript("OnClick", function()
		if GF.Debug and GF.Debug.RunAction then
			GF.Debug:RunAction(actionID)
		end
		DP:Refresh()
	end)
	return button
end

local function addButtonRow(section, labelText, buttons)
	local _, control = addDebugRow(section, labelText)
	for index, buttonInfo in ipairs(buttons or {}) do
		createActionButton(control, buttonInfo.label, buttonInfo.actionID, index)
	end
end

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
	return enabled and (L.DEBUG_STATE_ON or "On") or (L.DEBUG_STATE_OFF or "Off")
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
	local L = GF.L or {}

	self.root = CreateFrame("Frame", nil, parent)
	self.root:SetAllPoints(parent)
	self.root:SetFrameLevel(parent:GetFrameLevel() + 1)

	self.scroll = GF.UI.CreateScrollFrame(self.root, { rowHeight = GF.SETTINGS_WHEEL_ROW_H or 24 })
	self.scroll:SetPoint("TOPLEFT", self.root, "TOPLEFT", SCROLL_INSET_L, 0)
	self.scroll:SetPoint("BOTTOMRIGHT", self.root, "BOTTOMRIGHT", -SCROLL_INSET_R, GF.CONTENT_SCROLL_INSET_B or 0)
	self.scroll:SetFrameLevel(self.root:GetFrameLevel() + 2)

	self.body = CreateFrame("Frame", nil, self.scroll)
	self.body:SetSize(1, 1)
	self.scroll:SetScrollChild(self.body)
	self.scrollBar = GF.UI.AttachMinimalScrollBar(self.scroll, SCROLLBAR_GAP, self.root, true)
	if self.scrollBar then
		self.scrollBar:SetWidth(SCROLLBAR_WIDTH)
		self.scrollBar:ClearAllPoints()
		self.scrollBar:SetPoint("TOPLEFT", self.scroll, "TOPRIGHT", SCROLLBAR_GAP, -SCROLLBAR_TOP_INSET)
		self.scrollBar:SetPoint("BOTTOMLEFT", self.scroll, "BOTTOMRIGHT", SCROLLBAR_GAP, SCROLLBAR_BOTTOM_INSET)
	end

	local y = -CONTENT_TOP_OFFSET
	local section = createSection(self.body, L.DEBUG_STATUS_SECTION or "Debug status", y)
	self.debugModeValue = addStatusRow(section, L.DEBUG_MODE_STATE or "Debug tab")
	self.testDataValue = addStatusRow(section, L.DEBUG_TESTDATA_STATE or "Applicant test data")
	self.scenarioValue = addStatusRow(section, L.DEBUG_TESTDATA_SCENARIO or "Current scenario")
	self.extraRowsValue = addStatusRow(section, L.DEBUG_TESTDATA_EXTRA_ROWS or "Extra scroll rows")
	y = finishSection(section, y)

	section = createSection(self.body, L.DEBUG_APPLICANT_SECTION or "Applicant test data", y)
	addButtonRow(section, L.DEBUG_TESTDATA_STATE or "Applicant test data", {
		{ label = L.DEBUG_ACTION_ENABLE_TESTDATA or "Enable data", actionID = "applicantsOn" },
		{ label = L.DEBUG_ACTION_DISABLE_TESTDATA or "Disable data", actionID = "applicantsOff" },
		{ label = L.DEBUG_ACTION_REFRESH_APPLICANTS or "Refresh applicants", actionID = "refreshApplicants" },
	})
	y = finishSection(section, y)

	section = createSection(self.body, L.DEBUG_SCENARIO_SECTION or "Test scenarios", y)
	addButtonRow(section, L.DEBUG_TESTDATA_SCENARIO or "Current scenario", {
		{ label = L.DEBUG_ACTION_SCENARIO_BASIC or "Basic scenario", actionID = "scenarioBasic" },
		{ label = L.DEBUG_ACTION_SCENARIO_FULL or "Full scenario", actionID = "scenarioFull" },
		{ label = L.DEBUG_ACTION_SCENARIO_SCROLL or "Scroll stress", actionID = "scenarioScroll" },
	})
	y = finishSection(section, y)

	section = createSection(self.body, L.DEBUG_LOCALE_SECTION or "Locale testing", y)
	addButtonRow(section, L.DEBUG_LOCALE_ROW or "Switch language", {
		{ label = L.DEBUG_ACTION_FORCE_ENUS or "English", actionID = "forceLocaleEnUS" },
		{ label = L.DEBUG_ACTION_FORCE_ZHCN or "Simplified Chinese", actionID = "forceLocaleZhCN" },
	})
	y = finishSection(section, y)

	section = createSection(self.body, L.DEBUG_COMMAND_SECTION or "Command entry", y)
	addButtonRow(section, L.DEBUG_COMMAND_SECTION or "Command entry", {
		{ label = L.DEBUG_ACTION_PRINT_HELP or "Print commands", actionID = "help" },
	})
	y = finishSection(section, y)

	self.bodyH = -y - SECTION_GAP + CONTENT_BOTTOM_PADDING
	self:Refresh()
	self:UpdateScroll()
end

function DP:Refresh()
	if not self.root then
		return
	end
	local status = GF.Debug and GF.Debug.GetApplicantTestDataStatus and GF.Debug:GetApplicantTestDataStatus() or {}
	local debugEnabled = GF.Debug and GF.Debug.IsDebugModeEnabled and GF.Debug:IsDebugModeEnabled()
	if self.debugModeValue then
		setStatusValue(self.debugModeValue, getStateText(debugEnabled), debugEnabled and STATUS_COLOR_ON or STATUS_COLOR_OFF)
	end
	if self.testDataValue then
		setStatusValue(self.testDataValue, getStateText(status.enabled == true), status.enabled == true and STATUS_COLOR_ON or STATUS_COLOR_OFF)
	end
	if self.scenarioValue then
		local scenarioColor = status.scenario == "scroll" and STATUS_COLOR_SCROLL or STATUS_COLOR_NORMAL
		setStatusValue(self.scenarioValue, getScenarioLabel(status.scenario), scenarioColor)
	end
	if self.extraRowsValue then
		setStatusValue(self.extraRowsValue, tostring(status.extraRows or 0), STATUS_COLOR_NORMAL)
	end
	self:UpdateScroll()
end

function DP:RefreshLocale()
	local parent = self.parent
	if not parent then
		return
	end
	local wasShown = self.root and self.root:IsShown()
	if self.root then
		self.root:Hide()
	end
	self.root = nil
	self.scroll = nil
	self.scrollBar = nil
	self.body = nil
	self.bodyH = nil
	self.debugModeValue = nil
	self.testDataValue = nil
	self.scenarioValue = nil
	self.extraRowsValue = nil
	self._lastLayoutW = nil
	self._lastBodyH = nil
	self:Init(parent)
	if self.root then
		self.root:SetShown(wasShown == true)
	end
end

function DP:UpdateScroll()
	if not self.scroll or not self.body then
		return
	end
	local layoutW = self.parent and self.parent:GetWidth() or self.scroll:GetWidth()
	if not layoutW or layoutW <= 0 then
		return
	end
	local bodyH = self.bodyH or 1
	if self._lastLayoutW == layoutW and self._lastBodyH == bodyH then
		GF.UI.UpdateScrollFrame(self.scroll)
		return
	end
	self._lastLayoutW = layoutW
	self._lastBodyH = bodyH
	self.body:SetWidth(layoutW)
	self.body:SetHeight(bodyH)
	GF.UI.UpdateScrollFrame(self.scroll)
end

function DP:Show()
	if self.root then
		self.root:Show()
		self:Refresh()
	end
end

function DP:Hide()
	if self.root then
		self.root:Hide()
	end
end
