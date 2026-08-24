------------------------------------------------------------
-- CrystalOfInsanity.lua
-- 12.1 内存优化版: 减少 CONFLICTS 遍历开销，优化 Aura 查询
-- Abin 2013/9/20 / 2026 修订
------------------------------------------------------------

local _, addon = ...
local L = addon.L

-- 12.1 优化: 预解析冲突列表，避免每次 OnUpdateTimer 都重新计算
local AURA_NAME = C_Spell.GetSpellInfo(127230).name
local CONFLICTS = addon:BuildSpellList(nil, 127230, 105689, 105691, 105693, 105694, 105696, 242551, 188031, 188034, 188035, 188033, 251839, 251837, 251836, 251838, 298841, 298836, 298837, 298839).conflicts

local crystalName, crystalLink

-- 12.1 优化: 缓存冲突键列表，避免每次 pairs 遍历整个表
local conflictKeys = {}
for spell, icon in pairs(CONFLICTS or {}) do
    table.insert(conflictKeys, { spell = spell, icon = icon })
end

local button = addon:CreateActionButton("CrystalOfInsanity", L["crystal of insanity"], nil, 3600, "PLAYER_AURA", "ITEM")
button:SetItem(211495)
button:RequireItem(211495)
button:SetFlyProtect("type", "item")
button.icon.text:Hide()

LibItemQuery:QueryItem(211495, button, 1)

function button:OnItemInfoReceived(itemId, name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture)
    self:SetAttribute("item", name)
    crystalName = name
    crystalLink = "|cff0070dd"..name.."|r"
    self.icon:SetIcon(texture)
end

function button:OnTooltipTitle(tooltip)
    if crystalLink then
        tooltip:AddLine(crystalLink)
    end
end

function button:OnTooltipLeftText(tooltip)
    if crystalLink then
        tooltip:AddLine(L["left click"]..L["use"]..crystalLink, 1, 1, 1, 1)
    end
end

-- 12.1 优化: 缓存上次检查结果，避免重复 Aura 查询
local lastExpires = nil
local lastCheckTime = 0

function button:OnUpdateTimer(spell)
    local now = GetTime()

    -- 如果上次检查在 0.5 秒内且已有结果，复用缓存
    if now - lastCheckTime < 0.5 and lastExpires then
        return 1, lastExpires
    end
    lastCheckTime = now

    local conflict
    local expires = addon:GetUnitBuffTimer("player", AURA_NAME)
    if expires then
        lastExpires = expires
        return 1, expires
    end

    -- 使用缓存的 conflictKeys 列表代替 pairs 遍历
    for _, data in ipairs(conflictKeys) do
        expires = addon:GetUnitBuffTimer("player", data.spell)
        if expires then
            conflict = data.icon
            break
        end
    end

    self:SetConflictIcon(conflict)
    lastExpires = expires
    return (expires or conflict) and "NONE" or "R", expires
end
