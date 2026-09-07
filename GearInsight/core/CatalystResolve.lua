-- CatalystResolve.lua — 催化剂「外观转换件」归一到原件（bug #122，2026-09-06）。
--
-- 12.x 催化剂对披风 / 护腕 / 腰带 / 靴子只换外观，属性一模一样但 itemId 变了：
-- 「私酿酒馆裹布」(251132) → 「潜伏蝰蛇披风」(271487)。插件按 itemId 认装备，
-- 转换过的件就成了「没毕业」，还让人去刷同一件。
--
-- 判法（在快照写入前做，所有页面读的都是归一后的 itemId）：
--   身上这件在 GearInsight.CatalystItems 里 → 拿它链接里的 bonusIDs 段给同部位每个 BiS 候选造一条链接，
--   GetItemStats 逐项比：副属性（爆击/急速/精通/全能）和护甲全部相等 = 同一件。
--   ⛔ 别用数据侧按占比猜的表当主判据：三个数据源的属性精度不一样，会漏。它只做兜底。
GearInsight = GearInsight or {}

local SECOND = { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT",
                 "ITEM_MOD_MASTERY_RATING_SHORT", "ITEM_MOD_VERSATILITY", "RESISTANCE0_NAME" }

local function statsOf(link)
    local ok, raw = pcall(function()
        if C_Item and C_Item.GetItemStats then return C_Item.GetItemStats(link) end
        if GetItemStats then return GetItemStats(link) end
    end)
    if not ok or type(raw) ~= "table" then return nil end
    local out, any = {}, false
    for _, k in ipairs(SECOND) do
        local v = tonumber(raw[k]) or 0
        out[k] = v
        if v > 0 then any = true end
    end
    return any and out or nil
end

local function sameStats(a, b)
    for _, k in ipairs(SECOND) do
        if (a[k] or 0) ~= (b[k] or 0) then return false end
    end
    return true
end

-- 把身上链接的 itemId 换成候选 id，其余字段（bonusIDs / 等级上下文）原样保留
local function relink(link, newId)
    local body = link and link:match("item:(%-?%d+:[^|]*)")
    if not body then return nil end
    return "item:" .. body:gsub("^%-?%d+", tostring(newId), 1)
end

--- equipped: GearReader:ReadAll().equipped（slotId → 记录，含 itemId / itemLink）
--- 就地把转换件的 itemId 改成原件，并记 catalystOf = 转换件 id。返回改了几件。
function GearInsight.ResolveCatalyst(equipped, class, spec, hero)
    local items = GearInsight.CatalystItems
    local bd = GearInsight.BisData
    if not items or not bd or not equipped or not class or not spec then return 0 end
    local n = 0
    for slotId, eq in pairs(equipped) do
        if type(eq) == "table" and not eq.empty and eq.itemId and items[eq.itemId] then
            local ok, cands = pcall(bd.GetSlotCandidates, bd, class, spec, hero, slotId)
            if ok and type(cands) == "table" then
                local mine = eq.itemLink and statsOf(eq.itemLink)
                local hit
                if mine then
                    for _, c in ipairs(cands) do
                        if c.itemId and c.itemId ~= eq.itemId then
                            local l2 = relink(eq.itemLink, c.itemId)
                            local st = l2 and statsOf(l2)
                            if st and sameStats(mine, st) then hit = c.itemId; break end
                            if not st and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(c.itemId) end
                        end
                    end
                end
                if not hit and GearInsight.CatalystAliasGuess then
                    -- 兜底：数据侧猜的原件，只在它真是本专精候选时采用
                    for _, gid in ipairs(GearInsight.CatalystAliasGuess[eq.itemId] or {}) do
                        for _, c in ipairs(cands) do
                            if c.itemId == gid then hit = gid; break end
                        end
                        if hit then break end
                    end
                end
                if hit then
                    eq.catalystOf = eq.itemId
                    eq.itemId = hit
                    n = n + 1
                end
            end
        end
    end
    return n
end
