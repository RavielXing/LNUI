local _, GF = ...
GF = GF.GF or GF

GF.UI = GF.UI or {}
local UI = GF.UI

local function applyVaultIcon(icon, atlas)
	-- SetAtlas has no success return, so check availability before assigning it.
	local ok, info = false, nil
	if atlas and C_Texture and C_Texture.GetAtlasInfo then
		ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
	end
	if ok and info and UI.TrySetAtlas(icon, atlas, false, nil, true) then
		icon:SetTexCoord(0, 1, 0, 1)
		return atlas
	end
	icon:SetTexture("Interface\\Icons\\INV_TreasureVault_Key01")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	return nil
end

local function createReadyAnimation(button)
	local style = GF.GREAT_VAULT_READY_FX_STYLE
	local size = (GF.GREAT_VAULT_BUTTON_VISUAL_SIZE or 26) * style.scale
	local ok, fx = pcall(CreateFrame, "Frame", nil, button, style.template)
	if not ok or not fx then return nil end
	fx:Hide()
	fx:SetPoint("CENTER", button, "CENTER", 0, 0)
	fx:SetSize(size, size)
	-- The native loop clears the opaque button face; the glyph remains above it.
	fx:SetFrameLevel(button:GetFrameLevel() + 1)
	fx:EnableMouse(false)
	-- Only ProcLoop was requested; never expose the template's 150px birth flash.
	fx.ProcStartFlipbook:Hide()
	fx.ProcAltGlow:Hide()
	fx:SetScript("OnShow", function(self)
		self.ProcStartAnim:Stop()
		self.ProcStartFlipbook:Hide()
		self.ProcLoopFlipbook:SetAlpha(1)
		self.ProcLoop:Play()
	end)
	fx:SetScript("OnHide", function(self)
		self.ProcStartAnim:Stop()
		self.ProcLoop:Stop()
		self.ProcLoopFlipbook:SetAlpha(0)
	end)
	return fx
end

local function stopReadyAnimation(button)
	local fx = button and button.greatVaultReadyFX
	if fx then fx:Hide() end
end

local function setReadyHighlight(button, ready)
	local fx = button.greatVaultReadyFX
	if ready and not fx then
		fx = createReadyAnimation(button)
		button.greatVaultReadyFX = fx
	end
	if fx then fx:SetShown(ready) end
end

local function updateVaultIcon(button)
	local atlas = GF.GREAT_VAULT_BUTTON_ICON_ATLAS
	if button.vaultIconAtlas == atlas then return end
	button.vaultIconAtlas = applyVaultIcon(button.Icon, atlas)
end

local function getSnapshot()
	local cache = GF.MythicPlusWeeklyCache
	return cache and cache.GetVaultSnapshot
		and cache:GetVaultSnapshot() or nil
end

local function isCombatLocked()
	return InCombatLockdown and InCombatLockdown() or false
end

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

local function addErrorTooltipLine(text)
	if GameTooltip_AddErrorLine then
		GameTooltip_AddErrorLine(GameTooltip, text, true)
	else
		addTooltipLine(text, 1, 0.2, 0.2)
	end
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
		GREAT_VAULT_REWARDS or L.MPLUS_GREAT_VAULT or "宏伟宝库")
	if not button.hasActiveSeason then
		addDisabledTooltipLine(UNAVAILABLE or L.UNAVAILABLE or "不可用")
		addNormalTooltipLine(
			GREAT_VAULT_REQUIRES_ACTIVE_SEASON
				or L.GREAT_VAULT_REQUIRES_ACTIVE_SEASON
				or "需要当前赛季处于开放状态")
	elseif button.combatLocked then
		addErrorTooltipLine(
			L.GREAT_VAULT_COMBAT_LOCKED or "战斗中无法打开宏伟宝库")
	else
		addNormalTooltipLine(
			JOURNEYS_GREAT_VAULT_TOOLTIP
				or L.GREAT_VAULT_OPEN
				or "打开宏伟宝库")
		addInstructionTooltipLine(
			WEEKLY_REWARDS_CLICK_TO_PREVIEW_INSTRUCTIONS
				or L.GREAT_VAULT_CLICK_TO_OPEN
				or "点击打开宏伟宝库。")
	end
	if UI.ShowGameTooltip then
		UI.ShowGameTooltip()
	else
		GameTooltip:Show()
	end
end

local function refreshButton(button, refreshTooltip)
	if not button then
		return
	end
	local snapshot = getSnapshot()
	button.hasActiveSeason = snapshot and snapshot.hasActiveSeason == true or false
	button.rewardReady = snapshot and snapshot.rewardReady == true or false
	button.combatLocked = isCombatLocked()
	local ready = button.rewardReady and button.hasActiveSeason and not button.combatLocked
	-- The shared fade still owns tint; only this button's normal tint changes.
	button.vaultIconHoverStyle.normalColor = ready
		and GF.FOOTER_ACTION_ICON_HOVER_STYLE.hoverColor
		or GF.FOOTER_ACTION_ICON_HOVER_STYLE.normalColor
	updateVaultIcon(button)
	local desaturated = not button.hasActiveSeason or button.combatLocked
	if button.Icon and button.Icon.SetDesaturated then
		button.Icon:SetDesaturated(desaturated)
	end
	UI.RefreshCommonTitleActionButtonSkin(button)
	setReadyHighlight(
		button,
		ready
			and (not button.IsVisible or button:IsVisible()))
	if refreshTooltip
		and GameTooltip
		and GameTooltip.GetOwner
		and GameTooltip:GetOwner() == button
	then
		showTooltip(button)
	end
end

local function notifyOpenFailure(reason)
	local L = GF.L or {}
	local message
	if reason == "combat" then
		message = L.GREAT_VAULT_COMBAT_LOCKED or "战斗中无法打开宏伟宝库"
	elseif reason == "inactive-season" then
		message = L.GREAT_VAULT_REQUIRES_ACTIVE_SEASON
			or "需要当前赛季处于开放状态"
	else
		message = L.GREAT_VAULT_OPEN_FAILED
			or "宏伟宝库暂时无法打开，请稍后重试"
	end
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(message)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(message, 1, 0.82, 0, 1)
	end
end

function UI.RefreshGreatVaultButton(button, refreshTooltip)
	refreshButton(button, refreshTooltip)
end

function UI.CreateGreatVaultButton(parent)
	if not parent then
		return nil
	end
	local button = CreateFrame(
		"Button",
		"GroupFinderAddonGreatVaultButton",
		parent)
	button:SetSize(
		GF.GREAT_VAULT_BUTTON_SIZE or 35,
		GF.GREAT_VAULT_BUTTON_SIZE or 35)
	button:SetFrameLevel(parent:GetFrameLevel() + 2)
	button:RegisterForClicks("LeftButtonUp")

	local iconHost = CreateFrame("Frame", nil, button)
	iconHost:SetAllPoints(button)
	iconHost:SetFrameLevel(button:GetFrameLevel() + 3)
	iconHost:EnableMouse(false)
	button.vaultIconHost = iconHost
	local icon = iconHost:CreateTexture(nil, "ARTWORK", nil, 1)
	local iconSize = GF.GREAT_VAULT_BUTTON_ICON_SIZE or 16
	button.Icon = icon
	local hoverStyle = GF.FOOTER_ACTION_ICON_HOVER_STYLE
	button.vaultIconHoverStyle = {
		normalColor = hoverStyle.normalColor,
		hoverColor = hoverStyle.hoverColor, disabledColor = hoverStyle.disabledColor,
	}
	UI.ApplyCommonSmallButtonSkin(button, icon, {
		visualSize = GF.GREAT_VAULT_BUTTON_VISUAL_SIZE or 26,
		iconWidth = iconSize,
		iconHeight = iconSize,
		iconHoverStyle = button.vaultIconHoverStyle,
		iconOffsetX = GF.GREAT_VAULT_BUTTON_ICON_OFFSET_X or 0,
		iconOffsetY = GF.GREAT_VAULT_BUTTON_ICON_OFFSET_Y or 0,
		isDisabled = function(self)
			return not self.hasActiveSeason or self.combatLocked
		end,
	})

	button:HookScript("OnShow", function(shownButton)
		refreshButton(shownButton, false)
	end)
	button:HookScript("OnHide", function(hiddenButton)
		stopReadyAnimation(hiddenButton)
		if GameTooltip and GameTooltip.GetOwner
			and GameTooltip:GetOwner() == hiddenButton
		then
			GameTooltip:Hide()
		end
	end)
	button:SetScript("OnEvent", function(eventButton)
		refreshButton(eventButton, true)
	end)
	button:RegisterEvent("PLAYER_ENTERING_WORLD")
	button:RegisterEvent("PLAYER_REGEN_DISABLED")
	button:RegisterEvent("PLAYER_REGEN_ENABLED")
	button:SetScript("OnClick", function(clickedButton)
		refreshButton(clickedButton, false)
		local cache = GF.MythicPlusWeeklyCache
		local opened, reason
		if cache and cache.OpenGreatVault then
			opened, reason = cache:OpenGreatVault()
		else
			opened, reason = false, "unavailable"
		end
		if not opened then
			notifyOpenFailure(reason)
		end
	end)
	button:HookScript("OnEnter", function(hoveredButton)
		refreshButton(hoveredButton, false)
		showTooltip(hoveredButton)
	end)
	button:HookScript("OnLeave", function(hoveredButton)
		if GameTooltip and GameTooltip.GetOwner
			and GameTooltip:GetOwner() == hoveredButton
		then
			GameTooltip:Hide()
		end
	end)

	local cache = GF.MythicPlusWeeklyCache
	if cache and cache.AddListener then
		cache:AddListener(function()
			refreshButton(button, true)
		end)
	end
	refreshButton(button, false)
	return button
end
