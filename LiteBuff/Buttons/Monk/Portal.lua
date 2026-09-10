------------------------------------------------------------
-- Ghoul.lua
--
-- Abin
-- 2012/1/25
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "MONK" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("MONKPORTAL", 126892, nil, nil, "DUAL")
button:SetSpell(126892)
button:SetAttribute("spell", button.spell)
if (IsSpellKnown(125883)) then
	button:SetSpell2(125883)
	button:SetAttribute("spell2", button.spell2)
end
button:SetFlyProtect("type1", "spell", "type2", "spell")
button:SetAttribute("type", 'spell')

