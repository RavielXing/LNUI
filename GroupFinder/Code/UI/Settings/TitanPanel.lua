local _, GF = ...

GF.TitanPanel = GF.TitanPanel or {}
local TP = GF.TitanPanel

local TITAN_ID = "GroupFinder"
local TITAN_BUTTON_NAME = "TitanPanel" .. TITAN_ID .. "Button"
local ICON_TEX = GF.ADDON_MENU_LOGO_TEXTURE
local TEAMUP_TEX = GF.TEAMUP_TEXTURE
local TEAMUP_IMAGE_W = GF.TEAMUP_TEXTURE_WIDTH or 512
local TEAMUP_FRAME_H = GF.TEAMUP_TEXTURE_HEIGHT or 256
local TITAN_ICON_SIZE = 16
local TITAN_STATUS_TEXT_GAP = 8
local TITAN_TEXT_ICON_SIZE = 14
local TITAN_ICON_GLOW_SIZE = 24
local TITAN_ICON_GLOW_PERIOD = 1.35
local TITAN_ICON_GLOW_MIN_ALPHA = 0.18
local TITAN_ICON_GLOW_MAX_ALPHA = 0.72
local CONFIG_APP_NAME = "Titan Panel Addon Control"

local TEAMUP_FRAMES = GF.TEAMUP_INLINE_TEXTURE_FRAMES or {
	applicant = { 400, 516, 0, 116 },
	group = { 656, 772, 0, 116 },
}

local updateEvents = {
	"PLAYER_LOGIN",
	"LFG_LIST_ACTIVE_ENTRY_UPDATE",
	"LFG_LIST_APPLICANT_LIST_UPDATED",
	"LFG_LIST_APPLICANT_UPDATED",
	"LFG_LIST_SEARCH_RESULTS_RECEIVED",
	"LFG_LIST_UPDATE_SEARCH_RESULTS",
	"LFG_LIST_SEARCH_RESULT_UPDATED",
	"LFG_LIST_APPLICATION_STATUS_UPDATED",
}

local function getDisplayName()
	local L = GF.L or {}
	return L.ADDON_NAME or GF.nameEN or "GroupFinder"
end

local function getStatusToggleLabel()
	local L = GF.L or {}
	return L.TITAN_SHOW_STATUS_TEXT or "Show status info"
end

local function getTitanLocaleText(key, fallback)
	if LibStub then
		local aceLocale = LibStub("AceLocale-3.0", true)
		local titanLocale = aceLocale and aceLocale:GetLocale(_G.TITAN_ID or "Titan", true)
		if titanLocale and titanLocale[key] then
			return titanLocale[key]
		end
	end
	return fallback
end

local function getStatusCounts()
	if GF.GetLauncherStatusCounts then
		local applicantCount, groupCount, _, applicantUnit = GF.GetLauncherStatusCounts()
		return tonumber(applicantCount) or 0, tonumber(groupCount) or 0, applicantUnit
	end
	return 0, 0, nil
end

local function formatCount(count)
	count = tonumber(count) or 0
	if count > 999 then
		return "999+"
	end
	return tostring(count)
end

local function formatIcon(frameKey)
	local coords = TEAMUP_FRAMES[frameKey]
	if not coords then
		return ""
	end
	return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(
		TEAMUP_TEX,
		TITAN_TEXT_ICON_SIZE,
		TITAN_TEXT_ICON_SIZE,
		TEAMUP_IMAGE_W,
		TEAMUP_FRAME_H,
		math.floor(coords[1] + 0.5),
		math.floor(coords[2] + 0.5),
		math.floor(coords[3] + 0.5),
		math.floor(coords[4] + 0.5)
	)
end

local function formatStatusText()
	local applicantCount, groupCount = getStatusCounts()
	return string.format(
		"%s %s  %s %s",
		formatIcon("applicant"),
		formatCount(applicantCount),
		formatIcon("group"),
		formatCount(groupCount)
	)
end

local function titanVar(id, key)
	if TitanGetVar then
		return TitanGetVar(id, key)
	end
	return nil
end

local function ensureApplicantGlow(button, icon)
	if not button or not icon then
		return nil
	end
	if not button._gfApplicantGlow then
		local glow = button:CreateTexture(nil, "OVERLAY")
		glow:SetTexture(ICON_TEX)
		glow:SetBlendMode("ADD")
		glow:SetVertexColor(0.95, 1, 0.35)
		glow:Hide()
		button._gfApplicantGlow = glow
	end
	local glow = button._gfApplicantGlow
	glow:SetSize(TITAN_ICON_GLOW_SIZE, TITAN_ICON_GLOW_SIZE)
	glow:ClearAllPoints()
	glow:SetPoint("CENTER", icon, "CENTER", 0, 0)

	if not button._gfApplicantGlowDriver then
		local driver = CreateFrame("Frame", nil, button)
		driver.owner = button
		driver:SetScript("OnUpdate", function(self, elapsed)
			local owner = self.owner
			local activeGlow = owner and owner._gfApplicantGlow
			if not activeGlow or not activeGlow:IsShown() then
				return
			end
			owner._gfApplicantGlowElapsed = ((owner._gfApplicantGlowElapsed or 0) + elapsed) % TITAN_ICON_GLOW_PERIOD
			local phase = owner._gfApplicantGlowElapsed / TITAN_ICON_GLOW_PERIOD
			local pulse = (math.sin((phase * math.pi * 2) - (math.pi / 2)) + 1) / 2
			activeGlow:SetAlpha(TITAN_ICON_GLOW_MIN_ALPHA + ((TITAN_ICON_GLOW_MAX_ALPHA - TITAN_ICON_GLOW_MIN_ALPHA) * pulse))
		end)
		driver:Hide()
		button._gfApplicantGlowDriver = driver
	end

	return glow
end

local function setApplicantGlowActive(active)
	local button = _G[TITAN_BUTTON_NAME]
	local icon = _G[TITAN_BUTTON_NAME .. "Icon"]
	if not button or not icon then
		return
	end
	local glow = ensureApplicantGlow(button, icon)
	local driver = button._gfApplicantGlowDriver
	active = active == true and icon:IsShown()
	if active then
		button._gfApplicantGlowElapsed = button._gfApplicantGlowElapsed or 0
		glow:Show()
		if driver then
			driver:Show()
		end
	else
		button._gfApplicantGlowElapsed = 0
		if glow then
			glow:Hide()
		end
		if driver then
			driver:Hide()
		end
	end
end

local function updateApplicantGlow()
	local applicantCount = getStatusCounts()
	setApplicantGlowActive(applicantCount > 0)
end

local function adjustButtonLayout()
	local button = _G[TITAN_BUTTON_NAME]
	if not button then
		return
	end
	local icon = _G[TITAN_BUTTON_NAME .. "Icon"]
	local text = _G[TITAN_BUTTON_NAME .. (TITAN_PANEL_TEXT or "Text")]
	if icon then
		icon:SetSize(TITAN_ICON_SIZE, TITAN_ICON_SIZE)
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", button, "LEFT", 0, 0)
		if button._gfApplicantGlow then
			button._gfApplicantGlow:SetSize(TITAN_ICON_GLOW_SIZE, TITAN_ICON_GLOW_SIZE)
			button._gfApplicantGlow:ClearAllPoints()
			button._gfApplicantGlow:SetPoint("CENTER", icon, "CENTER", 0, 0)
		end
	end
	if text then
		text:SetHeight(TITAN_ICON_SIZE)
		text:SetJustifyV("MIDDLE")
		text:ClearAllPoints()
		if icon and icon:IsShown() then
			text:SetPoint("LEFT", icon, "RIGHT", TITAN_STATUS_TEXT_GAP, 0)
		else
			text:SetPoint("LEFT", button, "LEFT", 0, 0)
		end
	end
end

local function installButtonLayoutHook()
	if TP._buttonLayoutHooked then
		return
	end
	if hooksecurefunc and type(TitanPanelButton_UpdateButton) == "function" then
		hooksecurefunc("TitanPanelButton_UpdateButton", function(id)
			if id == TITAN_ID then
				adjustButtonLayout()
				updateApplicantGlow()
			end
		end)
		TP._buttonLayoutHooked = true
	end
end

local function updateTitanButton()
	if TitanPanelButton_UpdateButton then
		pcall(TitanPanelButton_UpdateButton, TITAN_ID)
	end
	adjustButtonLayout()
	updateApplicantGlow()
end

local function refreshRegistryText()
	local name = getDisplayName()
	local button = _G[TITAN_BUTTON_NAME]
	if button and button.registry then
		button.registry.menuText = name
		button.registry.tooltipTitle = name
	end
	if TitanPlugins and TitanPlugins[TITAN_ID] then
		TitanPlugins[TITAN_ID].menuText = name
		TitanPlugins[TITAN_ID].tooltipTitle = name
		TitanPlugins[TITAN_ID].menuText_NC = name
	end
end

local function getButtonText()
	if titanVar(TITAN_ID, "ShowLabelText") == false then
		return "", ""
	end
	return formatStatusText(), ""
end

local function getTooltipText()
	local L = GF.L or {}
	local applicantCount, groupCount, applicantUnit = getStatusCounts()
	local applicantLabel = L.FLOAT_APPLICATIONS_LABEL or "Applications"
	local groupLabel = L.FLOAT_GROUPS_LABEL or "Groups"
	applicantUnit = applicantUnit or L.FLOAT_APPLICANTS_UNIT or "people"
	local groupUnit = L.FLOAT_GROUPS_UNIT or "groups"
	local leftClick = L.MINIMAP_LEFT_CLICK or "Left-click"
	local leftAction = L.MINIMAP_TIP or "Open Find a Group"
	local lines = {
		string.format("%s:\t%s %s", applicantLabel, formatCount(applicantCount), applicantUnit),
		string.format("%s:\t%s %s", groupLabel, formatCount(groupCount), groupUnit),
		"",
		string.format("%s: %s", leftClick, leftAction),
	}
	return table.concat(lines, "\n")
end

local function patchTitanConfigLabel()
	if not (LibStub and LibStub("AceConfigRegistry-3.0", true)) then
		return false
	end
	local registry = LibStub("AceConfigRegistry-3.0", true)
	local ok, options = pcall(registry.GetOptionsTable, registry, CONFIG_APP_NAME, "dialog", TITAN_ID)
	if not ok or not options then
		return false
	end
	local group = options.args and options.args[TITAN_ID]
	local label = group and group.args and group.args.label
	if not label then
		return false
	end
	local wanted = getStatusToggleLabel()
	if label.name ~= wanted then
		label.name = wanted
		if registry.NotifyChange then
			registry:NotifyChange(CONFIG_APP_NAME)
		end
	end
	return true
end

local function installConfigPatchHook()
	if TP._configHooked then
		return
	end
	if hooksecurefunc and type(TitanUpdateConfig) == "function" then
		hooksecurefunc("TitanUpdateConfig", function(action)
			if action == "init" then
				refreshRegistryText()
				patchTitanConfigLabel()
			end
		end)
		TP._configHooked = true
	end
end

local function prepareMenu()
	if not (TitanPanelRightClickMenu_AddTitle and TitanPanelRightClickMenu_AddButton) then
		return
	end
	local level = TitanPanelRightClickMenu_GetDropdownLevel and TitanPanelRightClickMenu_GetDropdownLevel() or 1
	local plugin = TitanPlugins and TitanPlugins[TITAN_ID]
	TitanPanelRightClickMenu_AddTitle((plugin and plugin.menuText) or getDisplayName())

	if TitanPanelRightClickMenu_AddToggleIcon then
		TitanPanelRightClickMenu_AddToggleIcon(TITAN_ID, level)
	end

	local info = {}
	info.text = getStatusToggleLabel()
	info.value = { TITAN_ID, "ShowLabelText" }
	info.func = function()
		if TitanPanelRightClickMenu_ToggleVar then
			TitanPanelRightClickMenu_ToggleVar({ TITAN_ID, "ShowLabelText" })
		elseif TitanToggleVar then
			TitanToggleVar(TITAN_ID, "ShowLabelText")
			updateTitanButton()
		end
		patchTitanConfigLabel()
	end
	info.checked = titanVar(TITAN_ID, "ShowLabelText")
	info.keepShownOnClick = 1
	TitanPanelRightClickMenu_AddButton(info, level)

	if TitanPanelRightClickMenu_AddToggleRightSide then
		TitanPanelRightClickMenu_AddToggleRightSide(TITAN_ID, level)
	end

	if TitanPanelRightClickMenu_AddSpacer then
		TitanPanelRightClickMenu_AddSpacer(level)
	end
	if TitanPanelRightClickMenu_AddCommand and TITAN_PANEL_MENU_FUNC_HIDE then
		TitanPanelRightClickMenu_AddCommand(
			getTitanLocaleText("TITAN_PANEL_MENU_HIDE", "Hide"),
			TITAN_ID,
			TITAN_PANEL_MENU_FUNC_HIDE,
			level
		)
	end
end

local function onLoad(self)
	local L = GF.L or {}
	installButtonLayoutHook()
	self.registry = {
		id = TITAN_ID,
		category = "Information",
		version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(GF.addonName or "GroupFinder", "Version") or "2.0.3",
		menuText = getDisplayName(),
		menuTextFunction = prepareMenu,
		buttonTextFunction = getButtonText,
		tooltipTitle = getDisplayName(),
		tooltipTextFunction = getTooltipText,
		icon = ICON_TEX,
		iconWidth = TITAN_ICON_SIZE,
		iconButtonWidth = TITAN_ICON_SIZE + TITAN_STATUS_TEXT_GAP,
		notes = L.TITAN_PLUGIN_NOTES or "Adds GroupFinder status counts to Titan Panel.",
		controlVariables = {
			ShowIcon = true,
			ShowLabelText = true,
			DisplayOnRightSide = true,
		},
		savedVariables = {
			ShowIcon = 1,
			ShowLabelText = 1,
			DisplayOnRightSide = false,
		},
	}
end

local function onShow(self)
	installButtonLayoutHook()
	for _, event in ipairs(updateEvents) do
		self:RegisterEvent(event)
	end
	updateTitanButton()
	patchTitanConfigLabel()
end

local function onHide(self)
	for _, event in ipairs(updateEvents) do
		self:UnregisterEvent(event)
	end
	setApplicantGlowActive(false)
end

local function onEvent()
	TP:UpdateButton()
end

local function onClick(_, button)
	if button == "LeftButton" and GF.HandleLauncherClick then
		GF.HandleLauncherClick("LeftButton")
	end
	if TitanPanelButton_OnClick then
		TitanPanelButton_OnClick(_G[TITAN_BUTTON_NAME], button)
	end
end

local function createTitanFrame()
	if _G[TITAN_BUTTON_NAME] or not (CreateFrame and UIParent) then
		return _G[TITAN_BUTTON_NAME] ~= nil
	end
	if not TitanPanelButton_OnClick then
		return false
	end
	local holder = CreateFrame("Frame", nil, UIParent)
	local ok, button = pcall(CreateFrame, "Button", TITAN_BUTTON_NAME, holder, "TitanPanelComboTemplate")
	if not ok or not button then
		return false
	end
	button:SetFrameStrata("FULLSCREEN")
	onLoad(button)
	button:SetScript("OnShow", function(self)
		onShow(self)
		if TitanPanelButton_OnShow then
			TitanPanelButton_OnShow(self)
		end
	end)
	button:SetScript("OnHide", onHide)
	button:SetScript("OnEvent", onEvent)
	button:SetScript("OnClick", onClick)
	TP.button = button
	installConfigPatchHook()
	patchTitanConfigLabel()
	return true
end

function TP:UpdateButton()
	refreshRegistryText()
	updateTitanButton()
	patchTitanConfigLabel()
end

function TP:Init()
	return createTitanFrame()
end

TP:Init()
