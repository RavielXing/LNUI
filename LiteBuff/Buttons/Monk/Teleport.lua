------------------------------------------------------------
-- Healthstone.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "MONK" then return end

local _, addon = ...
local L = addon.L


local button = addon:CreateActionButton("MONKTeleport", 101643, nil, 120, "DUAL")

button:SetSpell2(101643)
button:SetSpell(119996)
-- button:RequireSpell(101643)
button:SetFlyProtect("type1", "spell", "type2", "spell")

button:SetAttribute("spell", button.spell)
button:SetAttribute("spell2", button.spell2)





