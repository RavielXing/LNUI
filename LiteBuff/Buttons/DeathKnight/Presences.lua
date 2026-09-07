------------------------------------------------------------
-- Presences.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("DeathKnightPresences", "加速技能", nil, nil, "DUAL")
button:SetSpell(48265)
button:SetSpell2(212552)
button:SetAttribute("spell", button.spell)
button:SetAttribute("spell2", button.spell2)
button:SetFlyProtect("type1", "spell", "type2", "spell")
