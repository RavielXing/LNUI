
if select(2, UnitClass("player")) ~= "HUNTER" then return end
local _, addon = ...
local L = addon.L

local spell
if (IsSpellKnown(1232995)) then
	spell = 1232995
elseif (IsSpellKnown(125050)) then
	spell = 125050
else
	return
end
local button = addon:CreateActionButton("HUNTERFunction", spell, nil, 3600, "DUAL")
button:SetSpell(spell)
button:SetAttribute("type", 'spell')
button:SetAttribute('spell', button.spell)

