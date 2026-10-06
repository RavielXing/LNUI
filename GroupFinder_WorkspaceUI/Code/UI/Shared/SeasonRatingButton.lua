local _, GF = ...
GF = GF.GF or GF

local UI = GF.UI

local function getShortcutInstruction(L)
	local first, second
	if GetBindingKey then
		first, second = GetBindingKey("GROUPFINDER_MPLUS_TELEPORT")
	end
	local key = first and first ~= "" and first or second
	if not key or key == "" then
		return L.SEASON_RATING_BUTTON_SHORTCUT_UNBOUND or "未设置快捷键"
	end
	local text = GetBindingText and GetBindingText(key) or key
	if not text or text == "" then text = key end
	-- Use native key names, with '+' between modifiers. Preserve a literal '-' key.
	local remaining, modifierCount = key, 0
	while true do
		local modifier, rest = remaining:match("^([A-Z]+)%-(.+)$")
		if modifier ~= "SHIFT" and modifier ~= "CTRL"
			and modifier ~= "ALT" and modifier ~= "META" then break end
		modifierCount = modifierCount + 1
		remaining = rest
	end
	text = text:gsub("%-", "+", modifierCount)
	return (L.SEASON_RATING_BUTTON_SHORTCUT or "%s 快捷呼出"):format(text)
end

local function hideTooltip(button)
	if GameTooltip and GameTooltip.GetOwner
		and GameTooltip:GetOwner() == button
	then
		GameTooltip:Hide()
	end
end

local function showTooltip(button)
	if not GameTooltip then return end
	local L = GF.L or {}
	UI.BeginGameTooltipAbove(button, "LEFT")
	local title = L.SEASON_RATING_BUTTON_TITLE or "赛季评分"
	if GameTooltip_SetTitle then
		GameTooltip_SetTitle(GameTooltip, title, nil, true)
	else
		GameTooltip:SetText(title, 1, 1, 1, 1, true)
	end
	local description = L.SEASON_RATING_BUTTON_DESCRIPTION
		or "查看当前赛季大秘境最佳记录评分。"
	if GameTooltip_AddNormalLine then
		GameTooltip_AddNormalLine(GameTooltip, description, true)
	else
		GameTooltip:AddLine(description, 1, 0.82, 0, true)
	end
	local instruction = getShortcutInstruction(L)
	if GameTooltip_AddInstructionLine then
		GameTooltip_AddInstructionLine(GameTooltip, instruction, true)
	else
		GameTooltip:AddLine(instruction, 0, 1, 0, true)
	end
	UI.ShowGameTooltip()
end

function UI.CreateSeasonRatingButton(parent)
	local button = UI.CreateFooterAtlasActionButton(
		parent,
		"GroupFinderAddonSeasonRatingButton",
		GF.SEASON_RATING_BUTTON_ICON_TEXTURE,
		GF.SEASON_RATING_BUTTON_ICON_SIZE)
	if not button then return nil end
	button:SetScript("OnClick", function(self)
		hideTooltip(self)
		GF.MainFrame:ToggleSeasonRating()
	end)
	button:HookScript("OnEnter", showTooltip)
	button:HookScript("OnLeave", hideTooltip)
	button:HookScript("OnHide", hideTooltip)
	button:SetScript("OnEvent", function(self)
		if GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() == self then
			showTooltip(self)
		end
	end)
	button:RegisterEvent("UPDATE_BINDINGS")
	return button
end
