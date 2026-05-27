------------------------------------------------------------
-- Fortitude.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------
if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("WaterWalk", 546, nil, 3600, "PLAYER_AURA")
button:SetSpell(546, "STAMINA")
button:SetAttribute("spell", button.spell)
button:RequireSpell(546)
button:SetFlyProtect()