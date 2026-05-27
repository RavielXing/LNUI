------------------------------------------------------------
-- Stances.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "WARRIOR" then return end

local _, addon = ...
local L = addon.L

local spellList = {}
addon:BuildSpellList(spellList, 386196)
addon:BuildSpellList(spellList, 386208)

local button = addon:CreateActionButton("WarriorStances", L["stances"], nil, nil, 'AURA', "STANCE")
button:SetAttribute("type", "spell")
button:SetScrollable(spellList)