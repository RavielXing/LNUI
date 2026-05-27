------------------------------------------------------------
-- ShadowForm.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------
if select(2, UnitClass("player")) ~= "PRIEST" then return end


local _, addon = ...
local L = addon.L


local button = addon:CreateActionButton("ShadowStance", 232698, nil, 3600, "PLAYER_AURA")
button:SetSpell(232698, "STAMINA")
button:SetAttribute("spell", button.spell)
button:RequireSpell(232698)

button:SetAttribute("type", 'spell')
