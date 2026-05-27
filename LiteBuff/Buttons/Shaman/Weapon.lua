------------------------------------------------------------
-- Curse.lua
--
-- 沐风
-- 2025/8/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local IsSpellKnown = IsSpellKnown
local _, addon = ...
local L = addon.L
local spell1 = addon:BuildSpellList(nil, 318038)

local button = addon:CreateActionButton("SHAMANWeapon", "武器灌魔", nil, 60, "PLAYER_AURA")

local function RegisterWeaponByList()
	button:SetSpell(318038)
	local WeaponList = {
		{ id = 382021, name = '大地生命武器',  },
		{ id = 462757, name = '雷霆打击结界',  },
		{ id = 33757, name = '风怒武器', },
	}
	for _, spell in next, WeaponList do
		if (IsSpellKnown(spell.id)) then
			button:SetSpell2(spell.id)
			button:SetAttribute("spell2", button.spell2)
			break
		end
	end
	button:SetAttribute("spell", button.spell)
end
button:SetFlyProtect("type1", "spell", "type2", "spell")
RegisterWeaponByList()


function button:OnSpellUpdate()
	RegisterWeaponByList()
end

