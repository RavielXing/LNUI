-- StatFit.lua — 身上这件的**副属性契合度**（bug #128，2026-09-07）
--
-- 为什么需要它（Telegram doctorase 报）：12.1 起催化剂转换后的件**保留原件的副属性**，
-- 所以同一个套装件 itemId 可以有完全不同的副属性 —— 拿一件副属性对路的大秘境装去催化，
-- 才是真正的 BiS。而插件一直按 itemId 认装备，两件在它眼里一模一样，
-- 于是「我这件属性很差的催化肩」被算成已毕业。
--
-- ⛔ 光靠 itemId 分不出来，只能读**身上这件链接的真实副属性**。
--   `core/CatalystResolve.lua` 已经在用同样的手法给转换件归一，技术是通的，
--   这里把它推广成「这件的副属性有多合你的专精」。
--
-- ⭐ 刻意只做**展示**不做警告：契合度是启发式的，做成红色警告必然误伤
--   （特效饰品、凑属性阈值的件、双属性接近的专精），玩家会被吵到关掉。
--   给出数字和实际属性名，让人自己判断。
GearInsight = GearInsight or {}

-- 副属性 → GetItemStats 的 key。⛔ 主属性(力量/敏捷/智力)不参与：它由部位和装等定死，
--   催化不会改，算进去只会把所有件的契合度都拉平。
local SECOND = {
    crit        = "ITEM_MOD_CRIT_RATING_SHORT",
    haste       = "ITEM_MOD_HASTE_RATING_SHORT",
    mastery     = "ITEM_MOD_MASTERY_RATING_SHORT",
    versatility = "ITEM_MOD_VERSATILITY",
}

local function rawStats(link)
    local ok, raw = pcall(function()
        if C_Item and C_Item.GetItemStats then return C_Item.GetItemStats(link) end
        if GetItemStats then return GetItemStats(link) end
    end)
    if not ok or type(raw) ~= "table" then return nil end
    return raw
end

-- 返回 fit(0~1), list{ {key,value}, … 按数值降序 }
--   fit = 实得权重 / 「同样多的副属性全堆在最优属性上」的权重。
--   1.0 = 这件的副属性全在你专精最看重的那条上；0.4 左右 = 基本堆在你不要的属性上。
--   ⛔ 拿不到数据(物品没缓存 / 无副属性)返回 nil，调用方必须当「不显示」处理，
--     ⛔别把 nil 当 0 —— 那会把「还没读到」画成「属性很差」。
function GearInsight.StatFit(link, weights)
    if not link or type(weights) ~= "table" then return nil end
    local raw = rawStats(link)
    if not raw then return nil end

    local total, score, have = 0, 0, {}
    for key, api in pairs(SECOND) do
        local v = tonumber(raw[api]) or 0
        if v > 0 then
            total = total + v
            score = score + v * (tonumber(weights[key]) or 0)
            have[#have + 1] = { key = key, value = v }
        end
    end
    if total <= 0 then return nil end

    local best = 0
    for key in pairs(SECOND) do
        local w = tonumber(weights[key]) or 0
        if w > best then best = w end
    end
    if best <= 0 then return nil end

    table.sort(have, function(a, b) return a.value > b.value end)
    return score / (total * best), have
end

-- 专精最看重的副属性名（用来告诉玩家「你的专精想要什么」）
function GearInsight.BestSecondary(weights)
    if type(weights) ~= "table" then return nil end
    local bestKey, bestW = nil, 0
    for key in pairs(SECOND) do
        local w = tonumber(weights[key]) or 0
        if w > bestW then bestKey, bestW = key, w end
    end
    return bestKey
end
