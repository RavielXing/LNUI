
if select(2, UnitClass("player")) ~= "MAGE" then return end
local _, addon = ...
local L = addon.L

local spellList = {}
addon:BuildSpellList(spellList, 130)
-- 131784幻觉已从正式服技能书移除(IsSpellKnown=false)，保留注释留档
-- addon:BuildSpellList(spellList, 131784)

local button = addon:CreateActionButton("MageFunction", '缓落', nil, nil, 'DUAL')
button:SetAttribute("type", "spell")
button:RequireSpell(130)
button:SetScrollable(spellList)

