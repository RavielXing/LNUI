local _, GF = ...

GF.UI = GF.UI or {}
local UI = GF.UI

local function setReadyBorderFrame(texture, frameIndex)
	if not texture then
		return
	end
	local columns = GF.GREAT_VAULT_READY_BORDER_COLUMNS or 5
	local rows = GF.GREAT_VAULT_READY_BORDER_ROWS or 6
	local frameCount = columns * rows
	frameIndex = (frameIndex or 0) % frameCount
	local column = frameIndex % columns
	local row = math.floor(frameIndex / columns)
	texture:SetTexCoord(
		column / columns,
		(column + 1) / columns,
		row / rows,
		(row + 1) / rows)
end

local function stopReadyAnimation(button)
	local borderFrame = button and button.greatVaultReadyBorderFrame
	if not borderFrame then
		return
	end
	borderFrame._gfAnimating = nil
	borderFrame:SetScript("OnUpdate", nil)
	borderFrame:Hide()
end

local function startReadyAnimation(button)
	local borderFrame = button and button.greatVaultReadyBorderFrame
	local texture = borderFrame and borderFrame.texture
	if not (borderFrame and texture) then
		return
	end
	borderFrame:Show()
	if borderFrame._gfAnimating then
		return
	end
	borderFrame._gfAnimating = true
	borderFrame._gfElapsed = 0
	borderFrame._gfFrameIndex = 0
	setReadyBorderFrame(texture, 0)
	borderFrame:SetScript("OnUpdate", function(frame, elapsed)
		frame._gfElapsed = (frame._gfElapsed or 0) + elapsed
		local frameDuration = 1 / (GF.GREAT_VAULT_READY_BORDER_FPS or 24)
		if frame._gfElapsed < frameDuration then
			return
		end
		local steps = math.floor(frame._gfElapsed / frameDuration)
		frame._gfElapsed = frame._gfElapsed - (steps * frameDuration)
		local frameCount = (GF.GREAT_VAULT_READY_BORDER_COLUMNS or 5)
			* (GF.GREAT_VAULT_READY_BORDER_ROWS or 6)
		frame._gfFrameIndex = ((frame._gfFrameIndex or 0) + steps) % frameCount
		setReadyBorderFrame(frame.texture, frame._gfFrameIndex)
	end)
end

local function ensureReadyBorder(button)
	if not button or button.greatVaultReadyBorderFrame then
		return
	end
	local borderFrame = CreateFrame("Frame", nil, button)
	borderFrame:SetPoint("CENTER", button, "CENTER")
	borderFrame:SetSize(
		GF.GREAT_VAULT_READY_BORDER_SIZE or 37,
		GF.GREAT_VAULT_READY_BORDER_SIZE or 37)
	borderFrame:SetFrameLevel(button:GetFrameLevel() + 8)
	borderFrame:Hide()

	local texture = borderFrame:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(borderFrame)
	texture:SetTexture(GF.GREAT_VAULT_READY_BORDER_TEXTURE)
	texture:SetBlendMode("BLEND")
	setReadyBorderFrame(texture, 0)

	borderFrame.texture = texture
	button.greatVaultReadyBorderFrame = borderFrame
end

local function setReadyHighlight(button, ready)
	ensureReadyBorder(button)
	if not button or not button.greatVaultReadyBorderFrame then
		return
	end
	if ready then
		startReadyAnimation(button)
	else
		stopReadyAnimation(button)
	end
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
				or "需要当前赛季处于开放状态。")
	elseif button.combatLocked then
		addErrorTooltipLine(
			L.GREAT_VAULT_COMBAT_LOCKED or "战斗中无法打开宏伟宝库。")
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
	local desaturated = not button.hasActiveSeason or button.combatLocked
	for _, texture in ipairs({ button.NormalTexture, button.PushedTexture }) do
		if texture and texture.SetDesaturated then
			texture:SetDesaturated(desaturated)
		end
	end
	local highlightTexture = button.GetHighlightTexture
		and button:GetHighlightTexture() or nil
	if highlightTexture and highlightTexture.SetDesaturated then
		highlightTexture:SetDesaturated(desaturated)
	end
	setReadyHighlight(
		button,
		button.rewardReady
			and not button.combatLocked
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
		message = L.GREAT_VAULT_COMBAT_LOCKED or "战斗中无法打开宏伟宝库。"
	elseif reason == "inactive-season" then
		message = L.GREAT_VAULT_REQUIRES_ACTIVE_SEASON
			or "需要当前赛季处于开放状态。"
	else
		message = L.GREAT_VAULT_OPEN_FAILED
			or "宏伟宝库暂时无法打开，请稍后重试。"
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

	local normalTexture = button:CreateTexture(nil, "ARTWORK")
	normalTexture:SetAllPoints(button)
	if not (UI.TrySetAtlas
		and UI.TrySetAtlas(
			normalTexture,
			GF.GREAT_VAULT_BUTTON_NORMAL_ATLAS
				or "ui-journeys-greatvault-button",
			false))
	then
		normalTexture:SetTexture("Interface\\Icons\\INV_TreasureVault_Key01")
		normalTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	button:SetNormalTexture(normalTexture)
	button.NormalTexture = normalTexture

	local pushedTexture = button:CreateTexture(nil, "ARTWORK")
	pushedTexture:SetAllPoints(button)
	if not (UI.TrySetAtlas
		and UI.TrySetAtlas(
			pushedTexture,
			GF.GREAT_VAULT_BUTTON_PRESSED_ATLAS
				or "ui-journeys-greatvault-button-pressed",
			false))
	then
		pushedTexture:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	end
	pushedTexture:SetBlendMode("ADD")
	button:SetPushedTexture(pushedTexture)
	button.PushedTexture = pushedTexture

	if AlphaHighlightButtonMixin
		and Mixin
		and normalTexture.GetAtlas
		and pushedTexture.GetAtlas
		and normalTexture:GetAtlas()
		and pushedTexture:GetAtlas()
	then
		Mixin(button, AlphaHighlightButtonMixin)
		button:SetScript("OnMouseDown", button.OnMouseDown)
		button:SetScript("OnMouseUp", button.OnMouseUp)
		button:UpdateHighlightForState()
	end

	button:SetScript("OnShow", function(shownButton)
		refreshButton(shownButton, false)
	end)
	button:SetScript("OnHide", function(hiddenButton)
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
	button:SetScript("OnEnter", function(hoveredButton)
		refreshButton(hoveredButton, false)
		showTooltip(hoveredButton)
	end)
	button:SetScript("OnLeave", function(hoveredButton)
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
