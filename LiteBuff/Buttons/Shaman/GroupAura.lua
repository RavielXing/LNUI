------------------------------------------------------------
-- Fortitude.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------
if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("ShamanBuff", 462854, nil, 3600, "GROUP_AURA")
button:SetSpell(462854, "STAMINA")
button:SetAttribute("spell", button.spell)
button:RequireSpell(462854)
button:SetFlyProtect()