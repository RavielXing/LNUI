------------------------------------------------------------
-- Chakra.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------
if select(2, UnitClass("player")) ~= "PRIEST" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("PRIESTFunction", 1706, nil, 3600, "PLAYER_AURA")
button:SetSpell(1706)
button:SetSpell2(2096)
button:SetAttribute("spell", button.spell)
button:SetAttribute("spell2", button.spell2)
button:SetFlyProtect("type1", "spell", "type2", "spell")

