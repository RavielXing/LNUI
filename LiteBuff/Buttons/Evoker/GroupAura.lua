------------------------------------------------------------
-- BlessingOfBronze.lua
-- 青铜龙的祝福 - 唤魔师群体 buff
-- 适用于魔兽世界 12.0.7 + LiteBuff
------------------------------------------------------------
if select(2, UnitClass("player")) ~= "EVOKER" then return end

local _, addon = ...
local L = addon.L

-- 创建 GROUP_AURA 按钮
-- 第2个参数 364342 仅用于按钮图标显示
local button = addon:CreateActionButton("EvokerBuff", 364342, nil, 3600, "GROUP_AURA")

-- 【关键修复 1】用 buff 光环 ID 381748 做监测
-- 364342 = 施法技能（点击施放）
-- 381748 = 实际施加在队友身上的 1小时光环
button:SetSpell(381748, "STAMINA")

-- 【关键修复 2】手动覆盖施法技能，确保点击按钮时施放的是 364342
-- 因为 SetSpell(381748) 会把 button.spell 改成 381748，
-- 而 381748 是光环不能直接施放，必须保持施法技能为 364342
local castSpellInfo = C_Spell.GetSpellInfo(364342)
button:SetAttribute("spell", castSpellInfo and castSpellInfo.name or 364342)

button:SetSpell2(369536)
button:SetAttribute("spell2", button.spell2)
button:RequireSpell(364342)
button:SetFlyProtect()

-- 【关键修复 3】青铜龙的祝福给所有职业，不限于法力值职业
-- 原代码 UnitPowerType(unit) == 0 会漏掉战士/盗贼/DK/熊德等
function button:OnGroupVerifyUnit(unit)
	return true
end