-- TierView.lua
-- 「装备难度档」视图(玩家需求：英雄 BiS / 普通 BiS)：按所选难度档把 BiS 数据
-- 的装等换算成该档可获取的数值，毕业判定/推荐顺延/差距显示全链路自动随之生效
-- (所有消费方都经 BisData:GetSpecData → ApplyDataFilters 读数)。
--
-- 挂在 BisData:ApplyDataFilters 之后跑，沿用其「原始值缓存 + 签名短路」模式
-- (_usageRaid 同款)；不改动生成文件 BisData.lua，数据管线重新生成不受影响。
-- ⚠ SCALED_CATEGORIES 在 core/BisPack.lua 里有一份同样的定义（真正做换算的地方），
--   改换算范围要两边一起改。
--
-- 换算规则：相邻团本难度差 13 装等(本季阶梯，史诗→英雄→普通)；只降档有难度
-- 阶梯的来源(团本/大秘境/套装转换)，制造/世界掉落等装等固定的来源不动。
-- usagePct 不重算——使用率仍是史诗顶尖玩家口径(数据源如此)，只换算可达装等。

GearInsight = GearInsight or {}

local STEP_PER_TIER = 13
local TIER_LEVELS = { mythic = 0, heroic = 1, normal = 2 }
local SCALED_CATEGORIES = { raid = true, mplus = true, tier = true }

function GearInsight:GetGearTier()
    -- 刷本助手建模期间用它自己的档位（_fgFilterOverride），不动全局设置
    local ov = GearInsight._fgFilterOverride
    if ov and ov.tier and TIER_LEVELS[ov.tier] then return ov.tier end
    local t = GearInsightDB and GearInsightDB.gearTier
    return TIER_LEVELS[t or ""] and t or "mythic"
end

function GearInsight:GearTierStep()
    return (TIER_LEVELS[self:GetGearTier()] or 0) * STEP_PER_TIER
end

local _tierSig

function GearInsight:InvalidateTierView()
    _tierSig = nil
end

local function applyTier(bd)
    local step = GearInsight:GearTierStep()
    local sig = tostring(bd._filterSig) .. "|tier" .. step
    if _tierSig == sig then return end
    _tierSig = sig
    -- ⭐ 2026-09-04：逐条目的装等换算挪进了 core/BisPack.lua 的 buildSpec —— 
    --    也就是「某个专精第一次被读到」那一刻才做。
    --    ⛔ 别在这里恢复成遍历 spec.bisBySlot：那会把 40 个专精全部解码建表，
    --       按需加载就白做了（这里是全量遍历，一跑就把惰性化打穿）。
    --    这里只做两件轻活：改档位时让已建好的表作废 + 换算每个专精的毕业装等。
    if bd.InvalidatePools then bd:InvalidatePools() end
    for _, spec in pairs(bd.specs or {}) do
        if spec._gradIlvlRaw == nil then spec._gradIlvlRaw = spec.graduationItemLevel or 0 end
        if step > 0 and spec._gradIlvlRaw > 0 then
            spec.graduationItemLevel = math.max(spec._gradIlvlRaw - step, 1)
        else
            spec.graduationItemLevel = spec._gradIlvlRaw
        end
    end
end

-- 本文件按 toc 顺序紧随 BisData.lua 加载，此时 GearInsight.BisData 已就绪。
local bd = GearInsight.BisData
if bd and bd.ApplyDataFilters then
    local orig = bd.ApplyDataFilters
    bd.ApplyDataFilters = function(self, ...)
        orig(self, ...)
        applyTier(self)
    end
end
