------------------------------------------------------------
-- NotifyButton.lua
--
-- Abin
-- 2015-9-06
------------------------------------------------------------

local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local GameTooltip = GameTooltip

local addon = WhisperPop
local L = addon.L

local button = addon.templates.CreateIconButton("WhisperPopNotifyButton", UIParent, addon.ICON_FILE, 24, true)--lnui
addon.notifyButton = button

addon.frame:HookScript("OnShow", function()
	button:SetChecked(true)
end)

addon.frame:HookScript("OnHide", function()
	button:SetChecked(false)
end)

button.defaultPos = {"LEFT", "UIParent", "LEFT", 4, -200}--lnui
button.icon:SetDesaturated(true)

button.text = button:CreateFontString(button:GetName().."Text", "ARTWORK", "GameFontGreenSmall")
button.text:SetPoint("LEFT", button, "RIGHT", 2, 0)
button.text:SetFont(STANDARD_TEXT_FONT, 13, "")

button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:SetScript("OnClick", function(self, btn)
	if btn == "RightButton" then
		addon:ClearAllNews()
	else
		addon:ToggleFrame()
	end
	GameTooltip:Hide()
end)

button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine(L["title"])
	GameTooltip:AddLine(L["notify button tooltip left"], 1, 1, 1, 1)
	GameTooltip:AddLine(L["notify button tooltip right"], 1, 1, 1, 1)
	addon:AddTooltipText(GameTooltip)
	GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
	GameTooltip:Hide()
end)

-- Seconds between icon show/hide toggles while flashing (full bright→dim→bright cycle ≈ 2× this value).
local NOTIFY_ICON_BLINK_STEP = 0.6

local function Button_OnUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed > NOTIFY_ICON_BLINK_STEP then
		self.elapsed = 0
		if self.icon:IsShown() then
			self.icon:Hide()
		else
			self.icon:Show()
		end
	end
end

local function NotifyButton_ApplyNewMessageState()
	local name = addon:GetNewMessage()
	-- Outgoing whispers always fire OnListUpdate. If the first-unread sender is unchanged, skip
	-- re-binding OnUpdate / forcing icon:Show — that was still causing a visible hitch while flashing.
	if name and name == button.name then
		local wantFlash = addon.db.notifyIconFlash
		local flashHandler = button:GetScript("OnUpdate")
		if (wantFlash and flashHandler == Button_OnUpdate) or (not wantFlash and not flashHandler) then
			return
		end
	end
	if name ~= button.name then
		button.elapsed = 0
	end
	button.name = name
	button.icon:Show()
	if name then
		button.icon:SetDesaturated(false)
		button.text:SetText(name)
		if addon.db.notifyIconFlash then
			button:SetScript("OnUpdate", Button_OnUpdate)
		else
			button:SetScript("OnUpdate", nil)
		end
	else
		button.icon:SetDesaturated(true)
		button.text:SetText()
		button:SetScript("OnUpdate", nil)
	end
end

addon:RegisterEventCallback("OnListUpdate", NotifyButton_ApplyNewMessageState)

addon:RegisterOptionCallback("notifyIconFlash", function()
	NotifyButton_ApplyNewMessageState()
end)

addon:RegisterEventCallback("OnResetFrames", function()
	button:ClearAllPoints()
	button:SetPoint(unpack(button.defaultPos))
	addon:SavePosition(button)
end)

addon:RegisterOptionCallback("notifyButton", function(value)
	if value then
		button:Show()
	else
		button:Hide()
	end
end)

addon:RegisterOptionCallback("locked", function(value)
	button.locked = value
end)

addon:RegisterOptionCallback("buttonScale", function(value)
	button:SetScale(value / 100)
end)