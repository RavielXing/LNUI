------------------------------------------------------------
-- Healthstone.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "WARLOCK" then return end

local _, addon = ...
local L = addon.L

local ceateSpell = addon:BuildSpellList(nil, 48018)
local transmitSpell = addon:BuildSpellList(nil, 48020)

local button = addon:CreateActionButton("DemonicCircle", 48018, nil, 120, "DUAL")
button:SetFlyProtect("type1", "spell", "type2", "spell")
button:SetSpell(48020)
button:SetSpell2(48018)
button:RequireSpell(48018)

button:SetAttribute("spell", transmitSpell.spell)
button:SetAttribute("spell2", ceateSpell.spell)


function button:OnTooltipRightText(tooltip)
	tooltip:AddLine(L["right click"]..ceateSpell.spell, 1, 1, 1, 1)
end



