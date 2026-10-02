local _, GF = ...
GF = GF.GF or GF

GF.UI = GF.UI or {}
local UI = GF.UI

local ADDON_NAME = GF.KEYSTONE_LOOT_ADDON_NAME or "KeystoneLoot"
local READY = "ready"
local MISSING = "missing"
local NOT_READY = "not-ready"

local function addTooltipLine(text, r, g, b)
	if not text or text == "" or not GameTooltip then
		return
	end
	GameTooltip:AddLine(text, r or 1, g or 1, b or 1, true)
end

local function setTooltipTitle(text)
	if not text or text == "" or not GameTooltip then
		return
	end
	if GameTooltip_SetTitle then
		GameTooltip_SetTitle(GameTooltip, text, nil, true)
	else
		GameTooltip:ClearLines()
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
	end
end

local function addNormalTooltipLine(text)
	if GameTooltip_AddNormalLine then
		GameTooltip_AddNormalLine(GameTooltip, text, true)
	else
		addTooltipLine(text, 1, 0.82, 0)
	end
end

local function addInstructionTooltipLine(text)
	if GameTooltip_AddInstructionLine then
		GameTooltip_AddInstructionLine(GameTooltip, text, true)
	else
		addTooltipLine(text, 0, 1, 0)
	end
end

local function addDisabledTooltipLine(text)
	if GameTooltip_AddDisabledLine then
		GameTooltip_AddDisabledLine(GameTooltip, text, true)
	else
		addTooltipLine(text, 0.5, 0.5, 0.5)
	end
end

local function getStatus()
	local frame = _G.KeystoneLootFrame
	local exists
	if C_AddOns and C_AddOns.DoesAddOnExist then
		exists = C_AddOns.DoesAddOnExist(ADDON_NAME)
	else
		exists = frame ~= nil
	end
	if not exists then
		return MISSING
	end

	local loaded = frame ~= nil
	local isFullyLoaded = GF.Compat and GF.Compat.IsAddOnFullyLoaded
	if type(isFullyLoaded) == "function" then
		loaded = isFullyLoaded(ADDON_NAME) == true
	end
	if not loaded
		or not frame
		or type(frame.IsShown) ~= "function"
		or type(frame.SetShown) ~= "function"
	then
		return NOT_READY
	end
	return READY
end

local function showTooltip(button)
	if not (button and GameTooltip) then
		return
	end
	local L = GF.L or {}
	if UI.BeginGameTooltipAbove then
		UI.BeginGameTooltipAbove(button, "LEFT")
	else
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	end
	setTooltipTitle(
		L.KEYSTONE_LOOT_TOOLTIP_TITLE or "KeystoneLoot")
	if button.keystoneLootStatus == READY then
		addNormalTooltipLine(
			L.KEYSTONE_LOOT_TOOLTIP_DESCRIPTION
				or "Browse seasonal dungeon and raid gear drops.")
		addInstructionTooltipLine(
			L.KEYSTONE_LOOT_CLICK_TO_OPEN
				or "Click to open KeystoneLoot")
	elseif button.keystoneLootStatus == MISSING then
		addDisabledTooltipLine(
			L.KEYSTONE_LOOT_NOT_INSTALLED
				or "KeystoneLoot is not installed.")
	else
		addDisabledTooltipLine(
			L.KEYSTONE_LOOT_NOT_READY
				or "KeystoneLoot is installed but disabled. Enable it, then reload the UI.")
	end
	if UI.ShowGameTooltip then
		UI.ShowGameTooltip()
	else
		GameTooltip:Show()
	end
end

local function hideTooltip(button)
	if GameTooltip
		and GameTooltip.GetOwner
		and GameTooltip:GetOwner() == button
	then
		GameTooltip:Hide()
	end
end

local function setTextureDisabled(texture, disabled)
	if not texture then
		return
	end
	if texture.SetDesaturated then
		texture:SetDesaturated(disabled)
	end
end

local function refreshButton(button, refreshTooltip)
	if not button then
		return
	end
	local status = getStatus()
	local ready = status == READY
	local statusChanged = button.keystoneLootStatus ~= status
	button.keystoneLootStatus = status
	if statusChanged then
		button:SetEnabled(ready)
		button.disabledMouseBlocker:SetShown(not ready)
		setTextureDisabled(button.Icon, not ready)
	end
	if refreshTooltip
		and GameTooltip
		and GameTooltip.GetOwner
		and GameTooltip:GetOwner() == button
	then
		showTooltip(button)
	end
end

local function notifyOpenFailure()
	local L = GF.L or {}
	local message = L.KEYSTONE_LOOT_OPEN_FAILED
		or "KeystoneLoot could not be toggled. Make sure the addon is enabled"
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(message)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(message, 1, 0.82, 0, 1)
	end
end

function UI.RefreshKeystoneLootButton(button, refreshTooltip)
	refreshButton(button, refreshTooltip)
end

function UI.CreateFooterAtlasActionButton(
	parent,
	name,
	iconTexture,
	iconSize)
	if not parent then
		return nil
	end

	local button = CreateFrame(
		"Button",
		name,
		parent)
	button:SetSize(
		GF.KEYSTONE_LOOT_BUTTON_SIZE or 35,
		GF.KEYSTONE_LOOT_BUTTON_SIZE or 35)
	button:SetFrameLevel(parent:GetFrameLevel() + 2)
	button:RegisterForClicks("LeftButtonUp")

	local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
	iconSize = iconSize or GF.KEYSTONE_LOOT_BUTTON_ICON_SIZE or 18
	icon:SetSize(
		iconSize,
		iconSize)
	icon:SetTexture(
		iconTexture
			or GF.KEYSTONE_LOOT_BUTTON_ICON_TEXTURE
			or "Interface\\AddOns\\GroupFinder\\Art\\Icon\\Gear.png")
	icon:SetTexCoord(0, 1, 0, 1)
	button.Icon = icon
	UI.ApplyCommonSmallButtonSkin(button, icon, {
		visualSize = GF.KEYSTONE_LOOT_BUTTON_VISUAL_SIZE or 26,
		iconWidth = iconSize,
		iconHeight = iconSize,
		iconHoverStyle = GF.FOOTER_ACTION_ICON_HOVER_STYLE,
		iconOffsetX = GF.KEYSTONE_LOOT_BUTTON_ICON_OFFSET_X or 0,
		iconOffsetY = GF.KEYSTONE_LOOT_BUTTON_ICON_OFFSET_Y or 0,
	})
	return button
end

function UI.CreateKeystoneLootButton(parent)
	local button = UI.CreateFooterAtlasActionButton(
		parent,
		"GroupFinderAddonKeystoneLootButton",
		GF.KEYSTONE_LOOT_BUTTON_ICON_TEXTURE)
	if not button then
		return nil
	end

	local disabledMouseBlocker = CreateFrame("Frame", nil, button)
	disabledMouseBlocker:SetAllPoints(button)
	disabledMouseBlocker:SetFrameLevel(button:GetFrameLevel() + 10)
	disabledMouseBlocker:EnableMouse(true)
	disabledMouseBlocker:SetScript("OnEnter", function()
		showTooltip(button)
	end)
	disabledMouseBlocker:SetScript("OnLeave", function()
		hideTooltip(button)
	end)
	button.disabledMouseBlocker = disabledMouseBlocker

	button:HookScript("OnShow", function(shownButton)
		refreshButton(shownButton, false)
	end)
	button:HookScript("OnHide", function(hiddenButton)
		hideTooltip(hiddenButton)
	end)
	button:SetScript("OnEvent", function(eventButton, event, addonName)
		if event == "ADDON_LOADED" and addonName ~= ADDON_NAME then
			return
		end
		refreshButton(eventButton, true)
	end)
	button:RegisterEvent("ADDON_LOADED")
	button:RegisterEvent("PLAYER_ENTERING_WORLD")
	button:SetScript("OnClick", function(clickedButton)
		refreshButton(clickedButton, false)
		if clickedButton.keystoneLootStatus ~= READY then
			notifyOpenFailure()
			return
		end
		local frame = _G.KeystoneLootFrame
		local toggled = frame
			and type(frame.IsShown) == "function"
			and type(frame.SetShown) == "function"
			and pcall(function()
				frame:SetShown(not frame:IsShown())
			end)
		if not toggled then
			notifyOpenFailure()
		end
	end)
	button:HookScript("OnEnter", function(hoveredButton)
		refreshButton(hoveredButton, false)
		showTooltip(hoveredButton)
	end)
	button:HookScript("OnLeave", function(hoveredButton)
		hideTooltip(hoveredButton)
	end)

	refreshButton(button, false)
	return button
end
