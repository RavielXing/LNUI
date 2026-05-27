
if select(2, UnitClass("player")) ~= "MAGE" then return end
local _, addon = ...
local L = addon.L

local spellList = {}
addon:BuildSpellList(spellList, 130)
addon:BuildSpellList(spellList, 131784)

local button = addon:CreateActionButton("MageFunction", '缓落/幻觉', nil, nil, 'DUAL')
button:SetAttribute("type", "spell")
button:SetScrollable(spellList)

