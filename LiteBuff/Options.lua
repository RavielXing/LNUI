------------------------------------------------------------
-- Options.lua
--
-- Abin
-- 2011/11/13
--
-- 插件自带设置页(单体版入口)。
-- 默认值在 Core.lua 的 LiteBuff.DEFAULTS, 这里只读; 取值一律走 GetSetting/IsButtonDisabled,
-- 存档里没记录时它们会落到默认值。正本在插件存档里, 面板只是入口。
-- 首装落地: 缩放/间距在 Core.lua 的 ApplyDefaults, 按钮开关在 ApplyButtonDisabledStates。
------------------------------------------------------------

local SlashCmdList = SlashCmdList

local addonName, addon = ...
local L = addon.L
local D = addon.DEFAULTS

local frame = UICreateInterfaceOptionPage("LiteBuffOptionFrame", "LiteBuff", L["subtitle"])

local group = frame:CreateMultiSelectionGroup(L["general options"])
frame:AnchorToTopLeft(group)

group:AddButton(L["lock frames"], "lock")
group:AddButton(L["simple tooltip"], "simpletip")

function group:OnCheckInit(value)
	if value == "lock" then
		return addon:GetSetting("lock")
	end
	return addon:GetSetting("simpletip")
end

function group:OnCheckChanged(value, checked)
	if value == "lock" then
		addon:SetSetting("lock", checked)
	else
		addon:SetSetting("simpletip", checked)
	end
end

local scaleSlider = frame:CreateSmallSlider(L["scale"], 50, 250, 5, "%d%%", D.layout.scale)
scaleSlider:SetPoint("TOPLEFT", group[-1], "BOTTOMLEFT", 4, -30)

function scaleSlider:OnSliderInit()
	return addon:GetScale()
end

function scaleSlider:OnSliderChanged(value)
	addon:SetScale(value)
end

local spacingSlider = frame:CreateSmallSlider(L["button spacing"], 0, 10, 1, "%d", D.layout.spacing)
spacingSlider:SetPoint("LEFT", scaleSlider, "RIGHT", 30, 0)

function spacingSlider:OnSliderInit()
	return addon:GetSpacing()
end

function spacingSlider:OnSliderChanged(value)
	addon:SaveData("db", "spacing", value)
	addon:SetButtonSpacing(value)
end

local anchor = group[-1]
group = frame:CreateMultiSelectionGroup(L["disable buttons"])
group:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -70)

for i = 1, addon:GetNumButtons() do
	local button = addon:GetButton(i)
	group:AddButton(button.title, button.key, 1)
end

function group:OnCheckInit(value)
	return addon:IsButtonDisabled(value)
end

function group:OnCheckChanged(value, checked)
	addon:SetButtonDisabled(value, checked)
end

SLASH_LITEBUFF1 = "/lb"
SLASH_LITEBUFF2 = "/litebuff"
SlashCmdList["LITEBUFF"] = function() frame:Open() end
