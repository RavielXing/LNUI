------------------------------------------------------------
-- HornOfWinter.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then return end

local UnitClass = UnitClass

local _, addon = ...
local L = addon.L
local leftSpell = addon:BuildSpellList(nil, 3714)
local ceateSpell = addon:BuildSpellList(nil, 50977)
local shiftCeateSpell = addon:BuildSpellList(nil, 53428)

local button = addon:CreateActionButton("DeathKnightHornOfWinter", 3714, nil, 120, "GROUP_AURA")
button:SetSpell(3714)
button:SetSpell2(50977)
button:SetAttribute("spell", leftSpell.spell)
button:SetAttribute("spell2", ceateSpell.spell)
button:SetAttribute("shift-spell2", shiftCeateSpell.spell)

button.OnTooltipText =function(self, tooltip)
    GameTooltip:AddLine(L["left click"]..leftSpell.spell, 1, 1, 1, 1)
    GameTooltip:AddLine(L["right click"]..ceateSpell.spell, 1, 1, 1, 1)
    GameTooltip:AddLine('shift-'..L["right click"]..shiftCeateSpell.spell, 1, 1, 1, 1)
end

button:SetFlyProtect("type1", "spell", "type2", "spell", "shift-type2", "spell")
