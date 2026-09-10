------------------------------------------------------------
-- ShapeShift.lua.lua
--
-- Abin
-- 2014/10/17
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "DRUID" then return end

local _, addon = ...
local L = addon.L

local spellList = {}

local function RegisterShapeByList()
	wipe(spellList)
	addon:BuildSpellList(spellList, 5487)
    addon:BuildSpellList(spellList, 768)
    if(IsSpellKnown(24858)) then
        addon:BuildSpellList(spellList, 24858)
    end
end

local button = addon:CreateActionButton("DruidShapeShift", L["presences"], nil, nil, "STANCE", "DUAL")
button:SetAttribute("type", "spell")
button:SetSpell2(783)
button:SetAttribute("spell2", button.spell2) --use spell will not work
button:SetScrollable(spellList)

RegisterShapeByList()

function button:OnSpellUpdate()
	RegisterShapeByList()
	button:SetScrollable(spellList, "spell1")
end