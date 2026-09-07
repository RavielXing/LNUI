-- 自动心愿单 + 队友拾取提醒。
--
-- ⭐ 与竞品的差别：KeystoneLoot（410 万下载）的心愿单要玩家**手动逐件勾**，
--    我们直接用「下一步建议」（RecsReader）自动生成 —— 那本来就是
--    「你缺的、且换上能提升」的清单，不用玩家再录一遍。
--
-- ⛔ 只在队伍里、且不是自己拾取时才提醒。自己捡到自己知道，
--    对着自己刷屏是最快让人关插件的方式。
GearInsight = GearInsight or {}
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local L = GearInsight.LOC or {}
    local cur = L[_LOCALE]
    if cur and cur[key] then return cur[key] end
    if _LOCALE ~= "zhTW" then
        local en = L["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

-- 心愿单：itemId -> { name, why }
-- 优先用 RecsReader 的「下一步建议」（已经是「缺且能提升」的），
-- 它不新鲜时退回 BisData 的本专精 BiS 全表（宁可多提醒，也别一条不提醒）。
local function BuildWishlist()
    local wl = {}
    local R = GearInsight.RecsReader
    if R and R.HasFreshRecs and R:HasFreshRecs() then
        local bySlot = R:GetBisBySlot()
        if bySlot then
            for slotId, list in pairs(bySlot) do
                for _, e in ipairs(list) do
                    if e.itemId then
                        -- ⛔ 数值要**带上它是什么**：建议模式给的是「换上能提升多少」，
                        --   回退模式给的是「顶尖玩家实穿率」——两个数长得一样、含义完全不同，
                        --   页面上不标清楚就是在误导（玩家 2026-09-02：「也不知道怎么用」）。
                        -- ⛔ ilvl / bonusIDs 必须带上：光有 itemId 的话，
                        --   悬停提示读到的是**基准装等**（掉落起点），不是目标 BiS 装等。
                        --   本插件别处已有同款做法（坯子行把 bonusIDs 嫁接到链接上）。
                        wl[e.itemId] = { name = e.itemName, slot = slotId,
                                         ilvl = e.ilvl, bonusIDs = e.bonusIDs, link = e.link,
                                         pct = e.improvementPct, kind = "gain", isTier = e.isTier,
                                         why = e.improvementPct and
                                               ("+%.0f%%"):format(e.improvementPct) or nil }
                    end
                end
            end
        end
    end
    if next(wl) then return wl, "recs" end

    -- 退路：本专精 BiS 全表。⛔BisData 的 key 是三段 "CLASS/SPEC/Hero"，
    --   同一件会在多个英雄天赋下重复，按 itemId 写入天然去重。
    local idx = GetSpecialization and GetSpecialization()
    local id = idx and GetSpecializationInfo and GetSpecializationInfo(idx)
    local myKey
    if id and type(_G.GearInsightRotation) == "table" then
        for k, v in pairs(_G.GearInsightRotation) do
            if v and v.specID == id then myKey = k; break end
        end
    end
    if not myKey then return wl, "none" end
    -- ⛔⛔ 2026-09-02 修：原来遍历的是 `GearInsight.BisData` 顶层，
    --   但三段 key（DEATHKNIGHT/BLOOD/San'layn）全在 **BisData.specs** 底下，
    --   顶层带 "/" 的 key 是 0 个 —— 这条回退路径**从来没取到过东西**，
    --   却照样返回 "bis"，于是面板显示「已回退」但共 0 件（玩家截图）。
    -- ⛔ 判据教训：拿「有没有走到这个分支」当成功判据是错的，要看**产出条数**。
    -- ⛔⛔ 玩家 Pluto 2026-09-02：「有的装备也不对，和BIS对不上」。
    --   根因：BisData 的 key 是**三段** CLASS/SPEC/Hero，而这里只按两段前缀匹配，
    --   于是把**所有英雄天赋分支**的 BiS 混进了一张清单；面板只按你当前那个
    --   英雄天赋算，两边自然对不上。
    --   ✅ 先拿当前英雄天赋精确定位；拿不到才退回前缀匹配（宁可多提醒也别一条不提醒）。
    local exact
    do
        local st = GearInsight.StatReader
        local ok, r = pcall(function() return st and st:ReadAll() end)
        if ok and r and r.class and r.spec then
            local bd = GearInsight.BisData
            local sd = bd and bd.GetSpecData and bd:GetSpecData(r.class, r.spec, r.heroTalent)
            if sd and sd.bisBySlot then exact = sd end
        end
    end

    local prefix = "^" .. myKey .. "/"
    local pool = exact and { [myKey] = exact } or ((GearInsight.BisData or {}).specs or {})
    for key, spec in pairs(pool) do
        if type(spec) == "table" and (exact or (type(key) == "string" and key:find(prefix))) then
            for slotId, items in pairs(spec.bisBySlot or {}) do
                if type(items) == "table" then
                    for _, it in ipairs(items) do
                        if type(it) == "table" and it.itemId then
                            wl[it.itemId] = { name = it.itemName, slot = slotId,
                                              ilvl = it.ilvl, bonusIDs = it.bonusIDs, link = it.link,
                                              pct = it.usagePct, kind = "usage", isTier = it.isTier,
                                              why = it.usagePct and
                                                    ("%.0f%%"):format(it.usagePct) or nil }
                        end
                    end
                end
            end
        end
    end
    if not next(wl) then return wl, "none" end     -- 空就老实说空，别报「已回退」
    return wl, "bis"
end

-- ⛔⛔ 2026-09-02 用户拍板：「要不不让用户选了，直接弹框告诉他有可提升部位掉落」。
--    原来这里有一层玩家手动增删（排除/追加，落 GearInsightDB）——已整层拆掉。
--    理由：心愿单的价值是「掉了我能变强的东西就叫我」，而「我能变强」这件事
--    插件自己算得出来（下一步建议就是「你缺且换上能提升」的清单），
--    让玩家再维护一份等于把插件该干的活推回给他。
--    ⛔ 别再加回来：加了就要处理「手动加的过时了怎么办」「换专精要不要清空」两个新问题。

local cache, cacheAt, cacheSrc = nil, 0, nil
local function Wishlist()
    -- ⛔别每条拾取消息都重建：一次团灭后的拾取雨会把帧数打下去。
    if cache and (GetTime() - cacheAt) < 60 then return cache, cacheSrc end
    cache, cacheSrc = BuildWishlist()
    cacheAt = GetTime()
    return cache, cacheSrc
end

-- ⛔ 暴露给面板「心愿单」页用。原来这两个是 local，外部一行都读不到 ——
--    功能只能靠「组队 + 队友刚好捡到」才验证得了，等于没法测。
--    返回 (wl, source)：source = "recs"（下一步建议）/ "bis"（BiS 全表回退）/ "none"。
-- 按 bonusIDs 造带真实装等的物品链接；没有 bonusIDs 就返回 nil，由调用方退回 itemId。
-- ⛔ 别用 GameTooltip:SetItemByID —— 那读的是基准装等（玩家 2026-09-02：「装等都不对」）。
-- 物品名解析。⛔⛔ 绝不返回裸 itemId：玩家 Icarus 2026-09-02 报「这里只显示ID
--   没显示装备叫啥」，弹窗上就是一行 `item:273792`。
-- ⛔ 冷缓存时 GetItemInfo 返回 nil 是**正常**的（物品信息异步加载），
--   这时要发起加载并让调用方稍后重刷，而不是把 id 打出来充数。
function GearInsight.ItemName(itemId, onReady)
    if not itemId then return nil end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local nm = getInfo and getInfo(itemId) or nil
    if nm then return nm end
    if onReady and Item and Item.CreateFromItemID then
        local ok, it = pcall(Item.CreateFromItemID, Item, itemId)
        if ok and it then pcall(function() it:ContinueOnItemLoad(onReady) end) end
    end
    return nil
end

function GearInsight.WishItemLink(e, itemId, nameHint)
    if e and e.link then return e.link end
    if not itemId then return nil end

    local payload
    local b = e and e.bonusIDs
    if b and #b > 0 then
        payload = itemId .. ":0::::::::0:::" .. #b .. ":" .. table.concat(b, ":")
    end

    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, stdLink, quality
    if getInfo then name, stdLink, quality = getInfo(itemId) end
    name = name or nameHint or (e and e.name)

    -- ⛔⛔ 没有 bonusIDs 时直接用客户端给的标准链接，别自己拼。
    if not payload then return stdLink end

    -- ⛔⛔ 显示名以前写死成 "[item]"：tooltip 能正常解析（它只看 itemId），
    --   但**贴进聊天框就只剩这四个字母**——玩家 2026-09-02 截图：
    --   「大佬，[item] 你还需要吗」。链接的显示文本必须是真名，且要带品质颜色码，
    --   否则在聊天里既难看也点不出正确颜色。
    if not name then
        -- 名字是异步的，冷缓存时先回退到标准链接（装等可能不带 bonus，但至少能看能点）
        return stdLink
    end
    local hex = "ffa335ee"                       -- 兜底紫色：BiS 目标基本都是史诗
    if quality and GetItemQualityColor then
        -- ⛔⛔ GetItemQualityColor 返回 **r, g, b, hex** 四个值，hex 是第 4 个。
        --    写成 `local _, _, h =` 取到的是 b（0.933…），拼出来就是
        --    `|c0.93333339691162[亚基克星藏骨匣]`（玩家 2026-09-02 截图）。
        --    ⭐ 这类「返回值差一位」编译不报错、颜色码也不崩，只会显示成乱码。
        local _, _, _, h = GetItemQualityColor(quality)
        if type(h) == "string" and #h == 8 then hex = h end
    end
    return "|c" .. hex .. "|Hitem:" .. payload .. "|h[" .. name .. "]|h|r"
end

-- 可提升部位：一行一个槽位（当前装备 → 目标装备 + 提升幅度）。
-- ⭐ 这才是玩家要看的形态。原来页面把 53 件 BiS 全表平铺出来，既看不懂也没法用
--    （玩家 2026-09-02：「非常难看，也不知道怎么用」）——
--    53 条里绝大多数是「你已经穿着的/根本轮不到的」，真正有决策价值的是
--    「哪几个部位还能提升、提升多少」，最多十几行。
-- ⛔ 当前装等要现读 GetInventoryItemLink，⛔别用快照：快照可能是上次登录时的。
-- 按部位关掉提醒（用户 2026-09-02：「可以按部位关闭提醒」）。落 SavedVariables。
function GearInsight.WishSlotEnabled(slotId)
    local db = GearInsightDB
    return not (db and db.wishSlotOff and db.wishSlotOff[slotId])
end

function GearInsight.WishSlotToggle(slotId)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.wishSlotOff = GearInsightDB.wishSlotOff or {}
    local off = GearInsightDB.wishSlotOff
    off[slotId] = (not off[slotId]) or nil
    GearInsight.InvalidateWishlist()
    return not off[slotId]
end

-- 可提升部位：一行一个槽位（当前装备 → 该刷的目标 + 提升幅度）。
-- ⭐ 这才是玩家要看的形态。原来页面把 53 件 BiS 全表平铺出来，既看不懂也没法用
--    （玩家 2026-09-02：「非常难看，也不知道怎么用」）——
--    53 条里绝大多数是「你已经穿着的/根本轮不到的」，真正有决策价值的是
--    「哪几个部位还能提升、提升多少」，最多十几行。
-- ⛔ 当前装等要现读 GetInventoryItemLink，⛔别用快照：快照可能是上次登录时的。
function GearInsight.GetUpgradeSlots()
    local wl = Wishlist()
    if not wl then return {} end
    local bySlot = {}
    for id, e in pairs(wl) do
        local sid = e.slot
        if sid then
            local prev = bySlot[sid]
            local score = (e.pct or 0) * 1000 + (e.ilvl or 0)
            if not prev or score > prev._score then
                bySlot[sid] = { slot = sid, itemId = id, name = e.name, ilvl = e.ilvl,
                                pct = e.pct, kind = e.kind, bonusIDs = e.bonusIDs,
                                link = e.link, isTier = e.isTier, _score = score }
            end
        end
    end

    local out = {}
    local bd = GearInsight.BisData
    for sid, t in pairs(bySlot) do
        -- ⛔⛔ 套装件本身不是刷取目标：它只能由催化引擎转换而来，副本里根本不掉。
        --    真正要盯的是**坯子第一名**（用户 2026-09-02：「套装注意是看坯子第一名」）。
        --    ⛔ 复用 BuildFillerList，别另挑一遍 —— 面板/弹窗/悬浮/这里必须同一个第一名。
        if t.isTier and GearInsight.BuildFillerList and bd then
            local _, cls = UnitClass("player")
            local armor = bd.classArmor and bd.classArmor[cls]
            if armor then
                local ok, list = pcall(GearInsight.BuildFillerList, armor, sid, nil, nil, nil, true)
                if ok and list and list[1] then
                    local f = list[1]
                    t.tierName = t.name                 -- 留住套装件名，页面上标注用
                    t.itemId   = f.itemId
                    -- ⛔⛔ 玩家 Pluto 2026-09-02：「有的是装备名，有的是副本名」。
                    --   根因：GetCatalystSources 里 `nameCn = instName`，那是**副本名**，
                    --   我当成物品名直接用了。⛔ 物品名只能由 itemId 现解析。
                    t.srcName  = f.nameCn                -- 它其实是来源副本名，留着别丢
                    t.name     = GearInsight.ItemName(f.itemId) or f.itemName
                    -- ⛔⛔ 必须用坯子**自己**的 bonusIDs（玩家 Icarus 2026-09-05：「这件装备属性不对」
                    --   「特效是尾王的衣服」）。原来写 `t.bonusIDs or f.bonusIDs`，t.bonusIDs 是套装件的，
                    --   嫁接到坯子 itemId 上 → 游戏按套装件的 bonus 渲染：装等 334 神话 6/6、
                    --   套装件的属性、套装件掉落 BOSS 的特效，全都不是这件坯子的。
                    t.bonusIDs = f.bonusIDs
                    t.ilvl     = f.ilvl or t.ilvl       -- 目标装等也跟坯子走，别再写套装件的
                    t.link     = nil                    -- 换了物品，旧链接作废
                    t.isFiller = true
                end
            end
        end

        local curLink = GetInventoryItemLink and GetInventoryItemLink("player", sid) or nil
        local curIlvl = 0
        if curLink and GetDetailedItemLevelInfo then
            curIlvl = GetDetailedItemLevelInfo(curLink) or 0
        end
        t.curLink, t.curIlvl = curLink, curIlvl
        -- ⭐ 目标装等上限（Telegram doctorase 2026-09-07 提）：赛季初大秘境玩家只奔英雄轨，
        --   神话轨留给大宝库和重铸。默认口径是「顶尖玩家穿什么」，对这类玩家永远差一截，
        --   心愿单于是长期挂着一堆这周根本拿不到的件。设了上限就按你自己的目标算差距，
        --   到顶的部位直接从列表里消失。0 / 不设 = 保持顶尖玩家口径。
        -- ⛔ 只夹**目标**，不动 BiS 推荐本身：推荐哪件仍由使用率决定，这里改的是「还差多少」。
        local cap = tonumber(GearInsightDB and GearInsightDB.targetIlvl) or 0
        if cap > 0 and t.ilvl and t.ilvl > cap then
            t.ilvl = cap
            t.capped = true
        end
        t.gain = (t.ilvl and curIlvl > 0) and (t.ilvl - curIlvl) or nil
        t.muted = not GearInsight.WishSlotEnabled(sid)
        -- ⛔ 已达标的部位不进列表：留着只会把真正要刷的淹掉
        if not t.gain or t.gain > 0 then out[#out + 1] = t end
    end
    table.sort(out, function(a, b)
        local ga, gb = a.gain or -1, b.gain or -1
        if ga ~= gb then return ga > gb end
        return (a.slot or 0) < (b.slot or 0)
    end)
    return out
end

-- 掉的这件对**当前身上**是不是提升。
-- ⛔⛔ 判据必须是「掉落物的**实际装等** vs 你身上那件」，不是「等于 BiS 目标装等」：
--    同一个 itemId 在团本英雄/史诗、大秘境英雄/史诗下装等都不同
--    （用户 2026-09-02：「要适配团本的 H M 和大秘境的 H M 难度，只要有提升不管难度都要提示」）。
--    按 itemId 匹配天然覆盖所有难度，但**能不能提升**只能拿实际装等算。
-- ⛔ 拿不到装等时返回 true：宁可多提醒一次，也别漏掉真提升。
function GearInsight.WishIsUpgrade(link, slotId)
    if not slotId then return true end
    if not GearInsight.WishSlotEnabled(slotId) then return false end
    if not (link and GetDetailedItemLevelInfo) then return true end
    local dropped = GetDetailedItemLevelInfo(link)
    if not dropped then return true end
    local cur = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
    if not cur then return true end                 -- 空着的部位，什么都算提升
    local curIlvl = GetDetailedItemLevelInfo(cur)
    if not curIlvl then return true end
    return dropped > curIlvl
end

function GearInsight.GetWishlist()
    return Wishlist()
end

-- 面板改了开关或换了专精后，让下一次读取立刻重建，别等 60 秒缓存过期。
function GearInsight.InvalidateWishlist()
    cache, cacheAt, cacheSrc = nil, 0, nil
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:SetScript("OnEvent", function(_, event, msg, playerName)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        GearInsight.InvalidateWishlist()     -- 换专精，心愿单作废
        return
    end
    if GearInsightDB and GearInsightDB.wishAlertOff then return end
    if not IsInGroup() then return end
    if not msg then return end

    local itemId = tonumber(msg:match("|Hitem:(%d+):"))
    if not itemId then return end

    -- 自己捡到的不提醒
    local who = playerName
    if not who or who == "" then return end
    local short = who:match("^([^-]+)") or who
    if short == UnitName("player") then return end

    local wl = Wishlist()
    local hit = wl and wl[itemId]
    if not hit then return end

    -- ⛔⛔ 12.x 的物品链接颜色码有新式写法 `|cnIQ3:`（不是 8 位十六进制），
    --   原来的 `|c%x+` 匹配不上，于是退回到 `"item:"..itemId` —— 弹窗就只剩一串 ID
    --   （玩家 Icarus 2026-09-02 报）。这里放宽到「|c 后面非竖线的任意字符」，
    --   再退一步只要 |Hitem:...|h[..]|h，最后才由 itemId 自己拼一个**带名字**的链接。
    local link = msg:match("(|c[^|]*|Hitem:.-|h%[.-%]|h|r)")
        or msg:match("(|Hitem:.-|h%[.-%]|h)")
        or select(2, GetItemInfo(itemId))
        or GearInsight.WishItemLink({ itemId = itemId }, itemId)

    -- ⭐主通道是弹窗：大秘境里聊天框刷得飞快，两行字几分钟后就被顶没了，
    --   而这条消息的价值恰恰是**立刻**看到并去问一句。
    if GearInsight.WishPopup then
        GearInsight:WishPopup(who, link, hit.why, itemId)
        return
    end

    -- 兜底（弹窗文件没加载时）。⛔玩家链接格式必须 |cCOLOR|Hplayer:Name|h[Text]|h|r，
    --   颜色码包在**外面**；写反了会能看不能点。
    local extra = hit.why and ("  |cff888888(%s)|r"):format(hit.why) or ""
    print(("|cffffd100GearInsight|r %s |cff40ff40|Hplayer:%s|h[%s]|h|r %s %s%s"):format(
        T("WA_PREFIX", "心愿单："), who, short,
        T("WA_GOT", "捡到了"), link, extra))
end)

-- ⛔ 开关必须落 **GearInsightDB**（toc 里 ## SavedVariables 声明的那个全局），
--    `GearInsight.db` 只是内存表，重登就丢 —— 玩家关掉它、下次登录又冒出来。
function GearInsight:ToggleWishAlert()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.wishAlertOff = not GearInsightDB.wishAlertOff
    return not GearInsightDB.wishAlertOff
end

-- 调试/面板用：返回心愿单条数与来源
function GearInsight:WishlistInfo()
    local wl, src = BuildWishlist()
    local n = 0
    for _ in pairs(wl) do n = n + 1 end
    return n, src
end
