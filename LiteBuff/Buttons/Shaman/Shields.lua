------------------------------------------------------------
-- Shields.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local _, addon = ...
local L = addon.L

local button = addon:CreateActionButton("ShamanShields1", L["shields"], nil, 3600, "PLAYER_AURA")

local function RegisterShieldByList()
	button:SetSpell(192106)
	if (IsSpellKnown(52127)) then
		button:SetSpell2(52127)
		button:SetAttribute("spell2", button.spell2)
	end
	button:SetAttribute("spell", button.spell)
end
button:SetFlyProtect("type1", "spell", "type2", "spell")
RegisterShieldByList()


function button:OnSpellUpdate()
	RegisterShieldByList()
end

