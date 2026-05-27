------------------------------------------------------------
-- Refreshment.lua
--
-- 通用恢复按钮
-- 左键：使用魔法汉堡
-- 右键：使用复原
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

function button:OnTooltipText(tooltip)
    tooltip:AddLine("左键：吃面包", 1, 1, 1, 1)
    tooltip:AddLine("右键：使用复原", 1, 1, 1, 1)
    tooltip:AddLine("使用复原不会打断吃面包", 1, 1, 1, 1)
end
