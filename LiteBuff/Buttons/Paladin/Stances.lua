------------------------------------------------------------
-- Stances.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "PALADIN" then return end

local _, addon = ...
local L = addon.L

local spellList = {}
addon:BuildSpellList(spellList, 32223)
addon:BuildSpellList(spellList, 465)
addon:BuildSpellList(spellList, 317920)

local button = addon:CreateActionButton("PALADINStances", L["stances"], nil, nil, 'AURA', "STANCE")
button:SetAttribute("type", "spell")
button:SetScrollable(spellList)