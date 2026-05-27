------------------------------------------------------------
-- Fortitude.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------
if select(2, UnitClass("player")) ~= "EVOKER" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("EvokerBuff", 364342, nil, 3600, "GROUP_AURA")
button:SetSpell(364342, "STAMINA")
button:SetAttribute("spell", button.spell)
button:SetSpell2(369536)
button:SetAttribute("spell2", button.spell2)
button:RequireSpell(364342)
button:SetFlyProtect()

function button:OnGroupVerifyUnit(unit)
	return UnitPowerType(unit) == 0
end