------------------------------------------------------------
-- Totem.lua
--
-- 沐风
-- 2025/8/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local IsSpellKnown = IsSpellKnown
local UnitGUID = UnitGUID
local GetTime = GetTime
local pairs = pairs
local GetSpecialization = GetSpecialization

local _, addon = ...
local L = addon.L

local spellList = {}
local totemNames = {}
local placedTraps = {}
local activatedTraps = {}

local function RegisterTotemByList()
	wipe(totemNames)
	wipe(spellList)
	local totemList = {
		192077, -- 狂风
		192058, -- 电能
		2484, -- 地缚
		8143, -- 战栗
	}
	for _, spellId in next, totemList do
		if (IsSpellKnown(spellId)) then
			local data = addon:BuildSpellList(spellList, spellId)
			totemNames[data.spell] = data
		end
	end
end

RegisterTotemByList()

local button = addon:CreateActionButton("SHAMANTotems", L["totems"], nil, 60, "DUAL")
--button:SetSpell2(77769)
--button:SetAttribute("spell2", button.spell2)
--button:RequireSpell(191433)
button:SetFlyProtect()
button:SetScrollable(spellList, "spell1")

function button:OnSpellUpdate()
	RegisterTotemByList()
	button:SetScrollable(spellList, "spell1")
end

