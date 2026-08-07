local _, GF = ...

GF.UI = GF.UI or {}
local UI = GF.UI

local ADDON_NAME = GF.KEYSTONE_LOOT_ADDON_NAME or "KeystoneLoot"
local READY = "ready"
local MISSING = "missing"
local NOT_READY = "not-ready"
local DEFAULT_NORMAL_TEXCOORD = {
	0.00390625, 0.49609375, 0.0078125, 0.9921875,
}
local DEFAULT_PRESSED_TEXCOORD = {
	0.50390625, 0.99609375, 0.0078125, 0.9921875,
}

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
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local _, fullyLoaded = C_AddOns.IsAddOnLoaded(ADDON_NAME)
		loaded = fullyLoaded == true
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

local function setTextureCoords(texture, coords, fallbackCoords)
	if not texture then
		return
	end
	coords = coords or fallbackCoords
	texture:SetTexCoord(
		coords[1],
		coords[2],
		coords[3],
		coords[4])
end

local function setGearPressed(button, pressed)
	if not (button and button.Icon) then
		return
	end
	local anchor = button.VisualHost or button
	local offsetX = pressed
		and (GF.KEYSTONE_LOOT_BUTTON_PRESSED_ICON_OFFSET_X or 0.5)
		or (GF.KEYSTONE_LOOT_BUTTON_ICON_OFFSET_X or -0.5)
	local offsetY = pressed
		and (GF.KEYSTONE_LOOT_BUTTON_PRESSED_ICON_OFFSET_Y or -0.5)
		or (GF.KEYSTONE_LOOT_BUTTON_ICON_OFFSET_Y or 0.5)
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint(
		"CENTER",
		anchor,
		"CENTER",
		offsetX,
		offsetY)
end

local function setHighlightPressed(button, pressed)
	local highlightTexture = button and button.HighlightTexture
	if not highlightTexture then
		return
	end
	setTextureCoords(
		highlightTexture,
		pressed and GF.KEYSTONE_LOOT_BUTTON_PRESSED_TEXCOORD
			or GF.KEYSTONE_LOOT_BUTTON_NORMAL_TEXCOORD,
		pressed and DEFAULT_PRESSED_TEXCOORD
			or DEFAULT_NORMAL_TEXCOORD)
end

local function setPressedVisual(button, pressed)
	setGearPressed(button, pressed)
	setHighlightPressed(button, pressed)
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
		if not ready then
			button._gfKeystoneLootMouseDown = nil
			setPressedVisual(button, false)
		end
		button:SetAlpha(
			ready and 1
				or (GF.KEYSTONE_LOOT_BUTTON_DISABLED_ALPHA or 0.45))
		for _, texture in ipairs({
			button.Icon,
			button.NormalTexture,
			button.PushedTexture,
			button.HighlightTexture,
		}) do
			setTextureDisabled(texture, not ready)
		end
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
		or "KeystoneLoot could not be toggled. Make sure the addon is enabled."
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(message)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(message, 1, 0.82, 0, 1)
	end
end

function UI.RefreshKeystoneLootButton(button, refreshTooltip)
	refreshButton(button, refreshTooltip)
end

function UI.SetFooterAtlasActionPressed(button, pressed)
	setPressedVisual(button, pressed == true)
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

	local visualHost = CreateFrame("Frame", nil, button)
	visualHost:SetPoint(
		"CENTER",
		button,
		"CENTER",
		GF.KEYSTONE_LOOT_BUTTON_VISUAL_OFFSET_X or 0,
		GF.KEYSTONE_LOOT_BUTTON_VISUAL_OFFSET_Y or 0)
	visualHost:SetSize(
		GF.KEYSTONE_LOOT_BUTTON_VISUAL_SIZE or 30,
		GF.KEYSTONE_LOOT_BUTTON_VISUAL_SIZE or 30)
	visualHost:SetFrameLevel(button:GetFrameLevel())
	visualHost:EnableMouse(false)
	button.VisualHost = visualHost

	local atlasTexture = GF.KEYSTONE_LOOT_BUTTON_ATLAS_TEXTURE
		or "Interface\\AddOns\\GroupFinder\\Art\\UI\\Common.png"

	local normalTexture =
		button:CreateTexture(nil, "BACKGROUND", nil, 0)
	normalTexture:SetAllPoints(visualHost)
	normalTexture:SetTexture(atlasTexture)
	setTextureCoords(
		normalTexture,
		GF.KEYSTONE_LOOT_BUTTON_NORMAL_TEXCOORD,
		DEFAULT_NORMAL_TEXCOORD)
	normalTexture:SetBlendMode("BLEND")
	button:SetNormalTexture(normalTexture)
	button.NormalTexture = normalTexture

	local pushedTexture =
		button:CreateTexture(nil, "BACKGROUND", nil, 0)
	pushedTexture:SetAllPoints(visualHost)
	pushedTexture:SetTexture(atlasTexture)
	setTextureCoords(
		pushedTexture,
		GF.KEYSTONE_LOOT_BUTTON_PRESSED_TEXCOORD,
		DEFAULT_PRESSED_TEXCOORD)
	pushedTexture:SetBlendMode("BLEND")
	button:SetPushedTexture(pushedTexture)
	button.PushedTexture = pushedTexture

	local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
	iconSize = iconSize or GF.KEYSTONE_LOOT_BUTTON_ICON_SIZE or 17
	icon:SetSize(
		iconSize,
		iconSize)
	icon:SetTexture(
		iconTexture
			or GF.KEYSTONE_LOOT_BUTTON_ICON_TEXTURE
			or "Interface\\AddOns\\GroupFinder\\Art\\UI\\Icon\\Gear.png")
	icon:SetTexCoord(0, 1, 0, 1)
	button.Icon = icon
	setGearPressed(button, false)

	button:SetHighlightTexture(atlasTexture, "ADD")
	local highlightTexture = button:GetHighlightTexture()
	highlightTexture:ClearAllPoints()
	highlightTexture:SetAllPoints(visualHost)
	button.HighlightTexture = highlightTexture
	setHighlightPressed(button, false)
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

	button:SetScript("OnShow", function(shownButton)
		refreshButton(shownButton, false)
	end)
	button:SetScript("OnHide", function(hiddenButton)
		hiddenButton._gfKeystoneLootMouseDown = nil
		setPressedVisual(hiddenButton, false)
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
	button:SetScript("OnMouseDown", function(pressedButton, mouseButton)
		if mouseButton ~= "LeftButton"
			or not pressedButton:IsEnabled()
		then
			return
		end
		pressedButton._gfKeystoneLootMouseDown = true
		setPressedVisual(pressedButton, true)
	end)
	button:SetScript("OnMouseUp", function(releasedButton, mouseButton)
		if mouseButton ~= "LeftButton" then
			return
		end
		releasedButton._gfKeystoneLootMouseDown = nil
		setPressedVisual(releasedButton, false)
	end)
	button:SetScript("OnClick", function(clickedButton)
		clickedButton._gfKeystoneLootMouseDown = nil
		setPressedVisual(clickedButton, false)
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
	button:SetScript("OnEnter", function(hoveredButton)
		refreshButton(hoveredButton, false)
		local stillPressed =
			hoveredButton._gfKeystoneLootMouseDown == true
				and IsMouseButtonDown
				and IsMouseButtonDown("LeftButton")
		if not stillPressed then
			hoveredButton._gfKeystoneLootMouseDown = nil
		end
		setPressedVisual(hoveredButton, stillPressed == true)
		showTooltip(hoveredButton)
	end)
	button:SetScript("OnLeave", function(hoveredButton)
		setPressedVisual(hoveredButton, false)
		hideTooltip(hoveredButton)
	end)

	refreshButton(button, false)
	return button
end
