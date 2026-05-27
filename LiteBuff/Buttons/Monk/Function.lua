------------------------------------------------------------
-- Ghoul.lua
--
-- Abin
-- 2012/1/25
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "MONK" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("MONKFUNCTION", 115078, nil, nil, "DUAL")

if (IsSpellKnown(115078)) then
	button:SetSpell(115078)
	button:SetAttribute("spell", button.spell)
end
if (IsSpellKnown(125883)) then
	button:SetSpell(125883)
	button:SetAttribute("spell2", button.spell2)
end
button:SetFlyProtect()
