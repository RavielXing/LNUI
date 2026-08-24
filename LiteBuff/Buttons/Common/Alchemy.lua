------------------------------------------------------------
-- Alchemy.lua
-- 12.1 内存优化版: 替换废弃 API，缓存 UnitStat 结果
-- Abin / 2026 修订
------------------------------------------------------------

local UnitStat = UnitStat
local pairs = pairs
local C_Spell = C_Spell  -- 12.1 API

local _, addon = ...
local L = addon.L

-- 12.1 修复: GetSpellInfo 已移除，使用 C_Spell.GetSpellInfo
local flaskInfo = C_Spell.GetSpellInfo(105617)
local flaskName = flaskInfo and flaskInfo.name or "Flask"
local flaskLink = "|cff0070dd"..flaskName.."|r"

local spellList = {}
addon:BuildSpellList(spellList, 79638, 105689, 105691, 105693, 105694, 105696, 127230)
addon:BuildSpellList(spellList, 79639, 105689, 105691, 105693, 105694, 105696, 127230)
addon:BuildSpellList(spellList, 79640, 105689, 105691, 105693, 105694, 105696, 127230)

local button = addon:CreateActionButton("AlchemyFlask", L["alchemy flask"], nil, 3600, "PLAYER_AURA")
button:RequireItem(75525)
button:SetFlyProtect("type", "item")
button:SetAttribute("item", flaskName)

function button:OnTooltipTitle(tooltip)
	tooltip:AddLine(flaskLink)
end

function button:OnTooltipText(tooltip, spell)
	if spell then
		tooltip:AddLine(L["effect"]..spell, 1, 1, 1, 1)
	end
end

function button:OnTooltipLeftText(tooltip)
	tooltip:AddLine(L["left click"]..L["drink"]..flaskLink, 1, 1, 1, 1)
end

function button:OnUpdateTimer(spell)
	local conflict
	local expires = addon:GetUnitBuffTimer("player", spell)
	if not expires and self.conflicts then
		local other, icon
		for other, icon in pairs(self.conflicts) do
			expires = addon:GetUnitBuffTimer("player", other)
			if expires then
				conflict = icon
				break
			end
		end
	end

	self:SetConflictIcon(conflict)
	return (expires or conflict) and "NONE" or "R", expires
end

-- 12.1 优化: 缓存属性值，减少 UnitStat 调用次数
local lastStatUpdate = 0
local cachedStr, cachedAgi, cachedInt = 0, 0, 0

function button:OnStatsUpdate()
	-- 限制更新频率，避免频繁调用 UnitStat
	local now = GetTime()
	if now - lastStatUpdate < 0.5 then
		return
	end
	lastStatUpdate = now

	local str = UnitStat("player", 1) or 0
	local agi = UnitStat("player", 2) or 0
	local int = UnitStat("player", 4) or 0

	cachedStr, cachedAgi, cachedInt = str, agi, int

	local index = 1
	if str > agi and str > int then
		index = 1
	elseif agi > str and agi > int then
		index = 2
	elseif int > str and int > agi then
		index = 3
	end

	self:SetSpell(spellList[index])
	self:UpdateTimer()
end
