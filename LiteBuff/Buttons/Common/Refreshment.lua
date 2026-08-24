------------------------------------------------------------
-- Refreshment.lua
-- 通用恢复按钮
-- 左键：使用魔法汉堡
-- 右键：使用复原
-- 12.1 优化版: 减少不必要的属性设置
------------------------------------------------------------

local _, addon = ...
local L = addon.L

local MAGIC_HAMBURGER_ITEM_ID = 113509
local RESTORE_SPELL_ID = 1231411

local button = addon:CreateActionButton("CommonRefreshment", L["refreshment"] or "恢复", nil, nil, 'DUAL', 'ITEM')

-- 检查按钮是否创建成功
if not button then
    return
end

button:SetItem(MAGIC_HAMBURGER_ITEM_ID)
button:SetSpell(RESTORE_SPELL_ID)

-- 左键：使用魔法汉堡
button:SetAttribute("type", "item")
button:SetAttribute("item", "item:"..MAGIC_HAMBURGER_ITEM_ID)

-- 右键：使用复原
button:SetAttribute("type2", "spell")
button:SetAttribute("spell2", RESTORE_SPELL_ID)

button:SetFlyProtect("type", "item", "type2", "spell")

-- 12.1 优化: 缓存 tooltip 文本，避免每次创建新字符串
local tooltipLines = {
    "左键：吃面包",
    "右键：使用复原",
    "使用复原不会打断吃面包",
}

function button:OnTooltipText(tooltip)
    for _, line in ipairs(tooltipLines) do
        tooltip:AddLine(line, 1, 1, 1, 1)
    end
end
