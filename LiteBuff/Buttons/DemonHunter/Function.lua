------------------------------------------------------------
-- Chakra.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------
if select(2, UnitClass("player")) ~= "DEMONHUNTER" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("DEMOHUNTERFunction", 217832, nil, 3600, "DUAL")
button:SetSpell(217832)
button:SetSpell2(188501)
button:SetAttribute("spell", button.spell)
button:SetAttribute("spell2", button.spell2)
button:SetFlyProtect("type1", "spell", "type2", "spell")

