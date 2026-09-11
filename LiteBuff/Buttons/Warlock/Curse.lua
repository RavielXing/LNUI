------------------------------------------------------------
-- Curse.lua
--
-- 沐风
-- 2025/8/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "WARLOCK" then return end

local IsSpellKnown = IsSpellKnown
local UnitGUID = UnitGUID
local GetTime = GetTime
local pairs = pairs
local GetSpecialization = GetSpecialization

local _, addon = ...
local L = addon.L

local spellList = {}
local curseNames = {}
local placedTraps = {}
local activatedTraps = {}

local function RegisterCurseByList()
	wipe(curseNames)
	wipe(spellList)
	local curseList = {
		334275, -- 疲劳
		702, -- 虚弱
		1714, -- 语言
	}
	for _, spellId in next, curseList do
		if (IsSpellKnown(spellId)) then
			local data = addon:BuildSpellList(spellList, spellId)
			curseNames[data.spell] = data
		end
	end
end

RegisterCurseByList()

local button = addon:CreateActionButton("WARLOCKCurses", "诅咒", nil, 60, "DUAL")
button:SetFlyProtect()
button:SetScrollable(spellList, "spell1")


function button:OnSpellUpdate()
	RegisterCurseByList()
	button:SetScrollable(spellList, "spell1")
end

