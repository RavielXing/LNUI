------------------------------------------------------------
-- Ghoul.lua
--
-- Abin
-- 2012/1/25
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "DRUID" then return end

local _, addon = ...
local L = addon.L

local spell
if (IsSpellKnown(193753)) then
	spell = 193753
elseif (IsSpellKnown(18960)) then
	spell = 18960
else
	return
end
local button = addon:CreateActionButton("DRUIDPORTAL", spell, nil, 3600, "DUAL")
button:SetSpell(spell)
button:SetAttribute("type", 'spell')
button:SetAttribute("spell", button.spell)
