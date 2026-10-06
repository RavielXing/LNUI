-- GearInsight/main/Sources.lua — 催化来源 / 地下城手册来源图 / 坯子列表 / 槽位 Top5
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, getCN, locName, localizedSource, _openSourceJournal = H.T, H.getCN, H.locName, H.localizedSource, H.openSourceJournal
local INVTYPE_HAND = H.INVTYPE_HAND

-- Popup listing every farmable "坯子" (Catalyst filler) for a tier slot: each row
-- is a real same-slot drop + its source, clickable to open the Encounter Journal.
-- Map an inventory slot to the Encounter Journal slot-filter enum.
local function _ejSlotFilter(slotId)
    local E = Enum and Enum.ItemSlotFilterType
    if not E then return nil end
    local m = {
        [1] = E.Head, [2] = E.Neck, [3] = E.Shoulder, [5] = E.Chest,
        [6] = E.Waist, [7] = E.Legs, [8] = E.Feet, [9] = E.Wrist,
        [10] = E.Hands, [15] = E.Cloak,
    }
    return m[slotId]
end

-- Complete same-slot drop list straight from the in-game Encounter Journal (current
-- tier dungeons + raid), filtered to the player's class. Every piece here can be
-- Catalyst-converted, so this covers items no logged player happened to wear — i.e.
-- it does NOT depend on WCL sample size. Result is cached per slot.
-- 本赛季大秘境副本（含轮换回来的老副本：塞塔里斯神庙 / 红玉新生法池 / 诸王之眠…）：
--   BisData 物品字典里来源类别 = mplus 的件所在的 instanceId。⛔ 只认 mplus：数据池里还有上赛季团本件（玩家身上还穿着），
--   用「出现过的全部副本」会把上赛季团本也扫进坯子。
local _mplusInst
local function seasonMplusInstances()
    if _mplusInst then return _mplusInst end
    local bd = GearInsight.BisData
    if not (bd and bd.items and bd.pool_c) then return {} end
    local mcat
    for i, c in ipairs(bd.pool_c) do if c == "mplus" then mcat = i end end
    local out = {}
    for _, row in pairs(bd.items) do
        if type(row) == "string" then
            local f = {}
            for v in row:gmatch("[^,]+") do f[#f + 1] = tonumber(v) or 0 end
            if mcat and f[3] == mcat and (f[5] or 0) > 0 then out[f[5]] = true end   -- 字段序 name,src,cat,boss,inst（BisPack ITEM_FIELDS）
        end
    end
    if next(out) then _mplusInst = out end
    return out
end
GearInsight.SeasonMplusInstances = seasonMplusInstances

function GearInsight:GetCatalystSources(slotId)
    self._catalystCache = self._catalystCache or {}
    if self._catalystCache[slotId] then return self._catalystCache[slotId] end
    -- EJ 的旧式全局函数由 Blizzard_EncounterJournal 提供。必须先加载 UI，
    -- 再检查 API；原来顺序相反，冷启动时第一次检查直接返回，后续重试也
    -- 永远没有机会真正加载手册，于是 tooltip 一直停在“候选数据加载中”。
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_EncounterJournal")
    end
    local slotFilter = _ejSlotFilter(slotId)
    if not slotFilter then return nil end
    local setSlot = C_EncounterJournal and C_EncounterJournal.SetSlotFilter
    local getLoot = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex
    if not (slotFilter and setSlot and getLoot and EJ_GetInstanceByIndex and EJ_SelectInstance and EJ_GetNumLoot and EJ_SetLootFilter) then
        return nil
    end

    local _, _, classID = UnitClass("player")
    local prevClass, prevSpec = 0, 0
    if EJ_GetLootFilter then prevClass, prevSpec = EJ_GetLootFilter() end

    if EJ_SelectTier and EJ_GetNumTiers then pcall(EJ_SelectTier, EJ_GetNumTiers()) end
    pcall(EJ_SetLootFilter, classID or 0, 0)
    pcall(setSlot, slotFilter)

    -- ⛔ 地下城手册的「额外战利品」也在这条扫描线上（玩家 2026-09-01 截图：妖术领主的凝视/
    --    面容、盘卷蛇岛之柱被算进了坯子）。那些东西在我们的数据里是 armor="MISC"、ilvl=null，
    --    根本不是同护甲的可装备件，催化也转不了。判据不用名字（多语言会漏），
    --    直接问客户端：必须是**护甲**且**子类等于本职业护甲类型**。
    local ARMOR_SUB = { CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4 }
    local _, classFile = UnitClass("player")
    local myArmor = self.BisData and self.BisData.classArmor and self.BisData.classArmor[classFile]
    local wantSub = ARMOR_SUB[myArmor]
    local ARMOR_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4
    -- ⛔ 部位必须自己再核一遍：手册的部位筛选是异步生效的，登录后预热扫描（2026-09-17 加）
    --    会拿到**上一个筛选**的残留 —— 手套的坯子表里混进「哈舒拉的腕轮」（护腕），
    --    悬浮「去刷横评 #1」就指错件。判据问客户端 GetItemInventoryTypeByID，不信筛选器。
    local SLOT_INV = { [1] = { "INVTYPE_HEAD" }, [2] = { "INVTYPE_NECK" }, [3] = { "INVTYPE_SHOULDER" },
        [5] = { "INVTYPE_CHEST", "INVTYPE_ROBE" }, [6] = { "INVTYPE_WAIST" }, [7] = { "INVTYPE_LEGS" },
        [8] = { "INVTYPE_FEET" }, [9] = { "INVTYPE_WRIST" }, [10] = { "INVTYPE_HAND" }, [15] = { "INVTYPE_CLOAK" } }
    local wantInv = {}
    for _, v in ipairs(SLOT_INV[slotId] or {}) do wantInv[v] = true end
    local slotMismatch = 0
    -- ⛔ 复刻副本的手册把历代旧掉落和本赛季掉落混在一起（纳洛拉克的洞穴 = 祖阿曼旧址 → 「爪饰护肩」69612 是 Cata 的 38 装等布甲，
    --    被当成坯子排到 #2；QQ 群 朝花暮日 2026-09-18 截图）。与 build_tier_filler.py 同一道防线：本赛季物品 itemID 都 ≥ 250000。
    local MIN_CURRENT_ITEM_ID = 250000
    -- legacy = 本赛季轮换回来的老副本（不在最新资料片那一栏）：装备沿用旧 itemID，不走 ID 门槛
    --   （09-25 网站对拍：蛇行神灵兜帽 239033 / 呼啸风暴头冠 193751 被这道门槛挡掉，插件少了两件坯子）
    local function isConvertible(itemID, legacy)
        if not legacy and (itemID or 0) < MIN_CURRENT_ITEM_ID then return false end
        local gii = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if not gii then return true end          -- 拿不到就别误杀
        local ok, _, _, _, invType, _, cls, sub = pcall(gii, itemID)
        if not ok or cls == nil then return true end
        if cls ~= ARMOR_CLASS then return false end
        if wantSub and sub ~= wantSub then return false end
        if next(wantInv) and invType and invType ~= "" and not wantInv[invType] then
            slotMismatch = slotMismatch + 1
            return false
        end
        return true
    end

    local seen, out, scanned = {}, {}, {}
    local function scanOne(instanceID, instName, isRaid, legacy)
            scanned[instanceID] = true
            pcall(EJ_SelectInstance, instanceID)
            -- 只取史诗难度的掉落(团本16/地下城23),滤掉只普通/英雄难度掉的老件(如血羽皮靴)。
            -- 残缺结果不缓存(见下方),靠重试补全,所以难度过滤不会再把列表清空。
            if EJ_SetDifficulty then pcall(EJ_SetDifficulty, isRaid and 16 or 23) end
            local n = EJ_GetNumLoot() or 0
            for i = 1, n do
                local ok, info = pcall(getLoot, i)
                if ok and info and info.itemID and not seen[info.itemID]
                    and isConvertible(info.itemID, legacy) then
                    seen[info.itemID] = true
                    out[#out + 1] = {
                        itemId = info.itemID,
                        -- ⛔⛔ 这里的 nameCn 是**副本名**，不是物品名！
                        --   BisData 的宝石/附魔表里 nameCn 确实是物品名，同名不同义 ——
                        --   2026-09-02 我拿它当物品名用，心愿单目标列印出了「密谋小径」
                        --   这种副本名（玩家 Pluto 报）。物品名只能由 itemId 现解析。
                        nameCn = instName,
                        link = info.link,   -- journal link w/ bonusIDs → real drop ilvl in tooltip
                        instanceId = instanceID,
                        encounterId = info.encounterID,
                        type = isRaid and "raid" or "mplus",
                    }
                end
            end
    end
    local function scan(isRaid)
        local idx = 1
        while true do
            local instanceID, instName = EJ_GetInstanceByIndex(idx, isRaid)
            if not instanceID then break end
            scanOne(instanceID, instName, isRaid, false)
            idx = idx + 1
        end
    end
    pcall(scan, false)   -- dungeons (M+)
    pcall(scan, true)    -- raids
    -- 本赛季轮换回来的老副本（手册里归在老资料片那一栏，上面按最新资料片枚举扫不到）
    for inst in pairs(seasonMplusInstances()) do
        if not scanned[inst] then
            local nm = EJ_GetInstanceInfo and select(1, EJ_GetInstanceInfo(inst)) or ""
            pcall(scanOne, inst, nm, false, true)
        end
    end

    -- Restore the journal's filters so we don't disturb a player who has it open.
    pcall(EJ_SetLootFilter, prevClass or 0, prevSpec or 0)
    if Enum and Enum.ItemSlotFilterType then pcall(setSlot, Enum.ItemSlotFilterType.NoFilter) end

    -- Don't cache a suspiciously short list — the journal loads loot asynchronously, so a
    -- cold first access can return only a partial list; allow a retry on the next open.
    -- 混进了别的部位 = 筛选器还没生效，这次结果不可信：不缓存，下次再扫
    if slotMismatch > 0 then return out end
    if #out > 2 then
        self._catalystCache[slotId] = out
    else
        -- ⛔ 用户 2026-09-24「这个坯子没显示排名」（惩戒骑·涌潮之海护肩）：板甲肩膀本赛季手册里本来就只有
        --    寥寥几件，「≤2 件 = 冷启动半截表」这条判据让它**永远**进不了缓存 → 悬浮永远没有 #N/M。
        --    连续两次扫出同样的件数（没有混部位）= 这个部位真的就这么少，照常缓存。
        self._catalystShort = self._catalystShort or {}
        if self._catalystShort[slotId] == #out then
            self._catalystCache[slotId] = out
        else
            self._catalystShort[slotId] = #out
        end
    end
    return out
end

-- 预热五个套装部位的坯子缓存（脱战才扫）。返回是否五格都已缓存。
-- ⛔ 用户 2026-09-24「这个咋没坯子排名？」：/reload 后只靠 Init 里 8/25/60 秒三次预热，
--    三次都碰上手册冷启动（半截表不缓存）或战斗中，悬浮就永远只有「催化后 = BiS #1」半截，
--    宝库面板也拿不到坯子名次。现在宝库面板渲染前、悬浮发现缓存缺时都会补扫（节流 10 秒）。
local _warmAt = 0
function GearInsight.WarmCatalystCache(force)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not GearInsight.GetCatalystSources then return false end
    local now = GetTime and GetTime() or 0
    local cache = GearInsight._catalystCache or {}
    local missing = false
    for _, slotId in ipairs({ 1, 3, 5, 7, 10 }) do
        if not cache[slotId] then missing = true end
    end
    if not missing then return true end
    if not force and now - _warmAt < 10 then return false end
    _warmAt = now
    local all = true
    for _, slotId in ipairs({ 1, 3, 5, 7, 10 }) do
        if not (GearInsight._catalystCache and GearInsight._catalystCache[slotId]) then
            pcall(GearInsight.GetCatalystSources, GearInsight, slotId)
            if not (GearInsight._catalystCache and GearInsight._catalystCache[slotId]) then all = false end
        end
    end
    return all
end

-- ── 全量掉落来源图（地下城手册）──────────────────────────────────────────
-- ⭐ 为什么还要这一层：BisData 只烘了**进过某个专精 BiS 池 / tierFiller** 的物品，
--    全库一共才 486 个 itemId。玩家 2026-09-02 反馈「有的有、有的没有」——
--    他悬停的「众军指挥官头盔」在 BisData 里查不到（按名字全库扫零命中），
--    不是 bug，是数据本来就没覆盖到。
--    客户端自己的地下城手册知道每件东西是哪个 BOSS 掉的，那才是全集。
--
-- ⛔ 三条自律，否则这东西会变成「登录卡三秒」的元凶：
--    ① **绝不在 tooltip 渲染里扫**——扫描要动 EJ 的全局筛选状态；
--       只在第一次「索引没命中」时排一个 C_Timer，下次悬停才有；
--    ② 玩家开着地下城手册时不扫，别把人家正看的页面切走；
--    ③ 扫完把 loot filter / slot filter 还原（照抄 GetCatalystSources 的做法）。
-- ⛔ 结果只留在内存，不落 SavedVariables：物品 id 每个补丁都在变，
--    存盘等于把过期数据带到下个版本。
local _journalMap, _journalState = nil, nil   -- nil | "building" | "done" | "unavailable"

function GearInsight:BuildJournalSourceMap()
    if _journalState == "building" then return end
    _journalState = "building"

    local getLoot = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex
    if not (getLoot and EJ_GetInstanceByIndex and EJ_SelectInstance and EJ_GetNumLoot
            and EJ_SetLootFilter and EJ_GetLootFilter) then
        _journalState = "unavailable"; return
    end
    -- 玩家正开着手册就别动它，下次再说
    if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then
        _journalState = nil; return
    end

    local prevClass, prevSpec = 0, 0
    pcall(function() prevClass, prevSpec = EJ_GetLootFilter() end)

    local map = {}
    local function scan(isRaid)
        local idx = 1
        while true do
            local instanceID, instName = EJ_GetInstanceByIndex(idx, isRaid)
            if not instanceID then break end
            pcall(EJ_SelectInstance, instanceID)
            if EJ_SetDifficulty then pcall(EJ_SetDifficulty, isRaid and 16 or 23) end
            local n = EJ_GetNumLoot() or 0
            for i = 1, n do
                local ok, info = pcall(getLoot, i)
                if ok and info and info.itemID and not map[info.itemID] then
                    map[info.itemID] = {
                        instanceId  = instanceID,
                        instName    = instName,
                        encounterId = info.encounterID,
                        isRaid      = isRaid and true or false,
                    }
                end
            end
            idx = idx + 1
        end
    end
    -- ⛔ 必须先选到**最新资料片**：EJ_GetInstanceByIndex 枚举的是当前选中的那个 tier，
    --   玩家上次把手册翻到旧资料片的话，扫出来的就是旧副本。
    if EJ_SelectTier and EJ_GetNumTiers then pcall(EJ_SelectTier, EJ_GetNumTiers()) end
    -- ⛔ 不加职业/部位筛选：这张图要覆盖**所有**装备，不只是本职业能穿的
    pcall(EJ_SetLootFilter, 0, 0)
    if Enum and Enum.ItemSlotFilterType then
        local setSlot = C_EncounterJournal and C_EncounterJournal.SetSlotFilter
        if setSlot then pcall(setSlot, Enum.ItemSlotFilterType.NoFilter) end
    end
    pcall(scan, false)   -- 地下城
    pcall(scan, true)    -- 团本
    -- 本赛季轮换回来的老副本（手册归在老资料片，上面枚举不到；09-25 塞塔里斯神庙 / 红玉新生法池的件没有「掉落：」）
    for inst in pairs((GearInsight.SeasonMplusInstances and GearInsight.SeasonMplusInstances()) or {}) do
        pcall(function()
            EJ_SelectInstance(inst)
            if EJ_SetDifficulty then EJ_SetDifficulty(23) end
            local nm = EJ_GetInstanceInfo and select(1, EJ_GetInstanceInfo(inst)) or ""
            for i = 1, (EJ_GetNumLoot() or 0) do
                local ok, info = pcall(getLoot, i)
                if ok and info and info.itemID and not map[info.itemID] then
                    map[info.itemID] = { instanceId = inst, instName = nm, encounterId = info.encounterID, isRaid = false }
                end
            end
        end)
    end

    pcall(EJ_SetLootFilter, prevClass or 0, prevSpec or 0)

    local n = 0
    for _ in pairs(map) do n = n + 1 end
    -- 手册的掉落是异步载入的，冷启动第一次可能只回来一小半 —— 太少就不留，下次重扫
    if n < 50 then _journalState = nil; return end
    _journalMap, _journalState = map, "done"
end

-- 只读查询。没建好就顺手排一次构建（异步），本次仍返回 nil。
function GearInsight.JournalSource(itemId)
    if not itemId then return nil end
    if _journalMap then return _journalMap[itemId] end
    if _journalState == nil and C_Timer and C_Timer.After and not InCombatLockdown() then
        _journalState = "queued"
        C_Timer.After(0.5, function()
            if C_AddOns and C_AddOns.LoadAddOn then
                pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
            end
            _journalState = nil
            GearInsight:BuildJournalSourceMap()
        end)
    end
    return nil
end

-- 坯子的「绿字」：催化只是改名 + 加套装效果，次级属性跟着**坯子**走，
-- 所以「转哪个坯子」实际就是在选属性（2026-09-01 玩家「哑巴」在群里提的：
-- 「这三个哪个是最佳属性」——插件此前只说来源，没说属性，等于没回答）。
-- ⛔ 必须用坯子自己的 bonusIDs 建链去读；拿 targetBonus 嫁接过的链读到的是
--    套装件的属性，每个坯子都会显示成一模一样，等于白做。
local _FILLER_SECOND = {
    ITEM_MOD_CRIT_RATING_SHORT    = { "STAT_CRIT",    "暴击", "crit" },
    ITEM_MOD_HASTE_RATING_SHORT   = { "STAT_HASTE",   "急速", "haste" },
    ITEM_MOD_MASTERY_RATING_SHORT = { "STAT_MASTERY", "精通", "mastery" },
    ITEM_MOD_VERSATILITY          = { "STAT_VERS",    "全能", "versatility" },
}
local function _fillerLink(itemId, bonusIDs)
    if not itemId then return nil end
    if bonusIDs and #bonusIDs > 0 then
        return "|Hitem:" .. itemId .. GearInsight.LinkMid() .. #bonusIDs .. ":"
            .. table.concat(bonusIDs, ":") .. "|h[item]|h"
    end
    return "item:" .. itemId
end
-- 返回「暴击/急速」这样的字串（按数值从大到小），读不到就返回 nil 让调用方留空。
-- 整段包 pcall：12.0.5 起部分属性接口可能返回 secret value，算术会直接抛错。
local _statsOfLink
local function _fillerStats(itemId, bonusIDs)
    return _statsOfLink(_fillerLink(itemId, bonusIDs))
end
function _statsOfLink(link)
    if not link then return nil end
    local ok, out = pcall(function()
        local raw
        if C_Item and C_Item.GetItemStats then raw = C_Item.GetItemStats(link)
        elseif GetItemStats then raw = GetItemStats(link) end
        if type(raw) ~= "table" then return nil end
        local list = {}
        for k, def in pairs(_FILLER_SECOND) do
            local v = tonumber(raw[k])
            if v and v > 0 then list[#list + 1] = { def = def, v = v } end
        end
        if #list == 0 then return nil end
        table.sort(list, function(a, b)
            if a.v ~= b.v then return a.v > b.v end
            return a.def[1] < b.def[1]
        end)
        local names, keys, values = {}, {}, {}
        for _, e in ipairs(list) do
            names[#names + 1] = T(e.def[1], e.def[2])
            keys[#keys + 1] = e.def[3]
            values[e.def[3]] = e.v
        end
        -- ⛔ keys 不排序：主属性在前，「精通/暴击」与「暴击/精通」是两件不同的东西
        return { text = table.concat(names, "/"), key = table.concat(keys, "+"), values = values }
    end)
    if ok and type(out) == "table" and out.text ~= "" then return out.text, out.key, out.values end
    return nil, nil
end

-- 顶尖玩家那件套装件的绿字（BisData 里每条 tier 记录都带 stats）归一化成同样的键，
-- 用来在坯子列表里点出「转出来跟顶尖同款」的那一条。
-- 返回 key（"mastery+crit"，主属性在前）与展示用文本（「精通/暴击」）。
local function _statsKey(stats)
    if type(stats) ~= "table" then return nil end
    local list = {}
    for _, k in ipairs({ "crit", "haste", "mastery", "versatility" }) do
        local v = tonumber(stats[k])
        if v and v > 0 then list[#list + 1] = { k = k, v = v } end
    end
    if #list == 0 then return nil end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.k < b.k end)
    local keys, names = {}, {}
    local LBL = { crit = { "STAT_CRIT", "暴击" }, haste = { "STAT_HASTE", "急速" },
                  mastery = { "STAT_MASTERY", "精通" }, versatility = { "STAT_VERS", "全能" } }
    for _, e in ipairs(list) do
        keys[#keys + 1] = e.k
        names[#names + 1] = T(LBL[e.k][1], LBL[e.k][2])
    end
    return table.concat(keys, "+"), table.concat(names, "/")
end

GearInsight.FillerStats = _fillerStats
GearInsight.LinkStats = function(link) return _statsOfLink(link) end   -- 真实物品链接的副属性（text, key）
GearInsight.StatsKey = _statsKey

-- 属性推荐 = 完整副属性评级乘以场景占比；同分同名次。
-- itemId 仅稳定显示顺序，不代表收益高低。实穿比例不参与评分。
local function _fillerScore(e, statPct)
    if e.targetStatsVerified and type(e.observedStats) == "table" and statPct then
        local score = 0
        for _, k in ipairs({"crit", "haste", "mastery", "versatility"}) do
            score = score + (e.observedStats[k] or 0) * (tonumber(statPct[k]) or 0)
        end
        return math.floor(score * 1000000 + 0.5) / 1000000, _statsKey(e.observedStats)
    end
    local link = e.verifiedTargetLink
    if not link then return -1, nil end
    if not (C_Item and C_Item.GetDetailedItemLevelInfo) then return -1, nil end
    local ok, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
    if not ok or level ~= e.ilvl then return -1, nil end
    local _, key, values = _statsOfLink(link)
    if not values or not statPct then return -1, key end
    local score = 0
    for _, k in ipairs({ "crit", "haste", "mastery", "versatility" }) do
        score = score + (values[k] or 0) * (tonumber(statPct[k]) or 0)
    end
    return math.floor(score * 1000000 + 0.5) / 1000000, key
end

local function _sortFillers(list, statPct, topKey)
    local meta = {}
    for i, e in ipairs(list) do
        local sc, key = _fillerScore(e, statPct)
        meta[e] = { sc = sc, key = key, ord = i,
                    usage = tonumber(e._catalystUsagePct),
                    raid = (e.type == "raid") and 0 or 1,
                    id = tonumber(e.itemId) or 0 }
    end
    table.sort(list, function(x, y)
        local a, b = meta[x], meta[y]
        if x.planned ~= y.planned then return x.planned == true end
        -- Popularity is separate evidence, never an attribute score.
        if a.sc ~= b.sc then return a.sc > b.sc end
        if a.id ~= b.id then return a.id < b.id end
        return a.ord < b.ord
    end)
    local previous, rank
    for i, e in ipairs(list) do
        local score = meta[e].sc
        if score ~= previous then rank = i end
        e.attributeScore = score >= 0 and score or nil
        e.attributeRank = score >= 0 and rank or nil
        e.recommendationBasis = score >= 0 and "attributeRecommendation" or "unverifiedCandidate"
        previous = score
    end
    return list
end
GearInsight.SortFillers = _sortFillers

-- Re-rank the active pool after source filtering; excluded rows are reference only.
local function _filterFillerRanks(list, excludeRaid)
    for _, e in ipairs(list) do e.excludedByRaidFilter = nil end
    if not excludeRaid then return false end
    local head, tail = {}, {}
    for _, e in ipairs(list) do
        local bucket = e.type == "raid" and tail or head
        bucket[#bucket + 1] = e
    end
    if #head == 0 then return true end
    for i = #list, 1, -1 do list[i] = nil end
    local previous, rank
    for i, e in ipairs(head) do
        if i == 1 or e.attributeScore ~= previous then rank = i end
        e.attributeRank = e.attributeScore and rank or nil
        previous = e.attributeScore
        list[#list + 1] = e
    end
    for _, e in ipairs(tail) do
        e.attributeRank = nil
        e.excludedByRaidFilter = true
        list[#list + 1] = e
    end
    return false
end
GearInsight.FilterFillerRanks = _filterFillerRanks

local function _catalystUsageGroup(specData, slotId)
    local packed = GearInsight.CatalystUsageData
    local bd = GearInsight.BisData
    if type(packed) ~= "table" or type(packed.groups) ~= "table"
        or packed.instanceEvidenceVersion ~= 2 or packed.verified ~= true
        or type(specData) ~= "table" or not bd then return nil end
    local prefix = rawget(specData, "_catalystSpecKey")
    if not prefix then
        for key, value in pairs(bd.specs or {}) do
            if value == specData then
                local class, spec = key:match("^([^/]+)/([^/]+)")
                if class and spec then prefix = class .. "/" .. spec; break end
            end
        end
        if prefix then specData._catalystSpecKey = prefix end
    end
    if not prefix then return nil end
    local mode = GearInsight._statMode
    local scenario = (mode == "mplusHigh" or mode == "mplusFarm" or mode == "mplusCommon")
        and "mplusHigh" or "raid"
    return packed.groups[prefix .. "/" .. scenario .. "/" .. tostring(slotId)], scenario
end

local function _applyCatalystUsage(list, specData, slotId)
    local group, scenario = _catalystUsageGroup(specData, slotId)
    if not group then return nil end
    for _, entry in ipairs(list or {}) do
        local usage = group.items and group.items[entry.itemId]
        entry._catalystUsagePct = usage and usage.p or nil
        entry._catalystUsageCount = usage and usage.n or nil
        entry._catalystUsageTotal = group.total or 0
        entry._catalystSourceKind = usage and usage.k or nil
        entry._catalystScenario = scenario
    end
    return group
end

GearInsight.CatalystUsageGroup = _catalystUsageGroup

-- ── 本赛季闸门 ─────────────────────────────────────────────────────────────
-- ⛔⛔ 0.64.2 已经立过总规则（玩家「筱小飞」反馈狂暴战手套推的是上赛季套装）：
--    **不按来源标签逐个封堵，改为「装等低于本赛季下限、且不在本赛季权威掉落表里」
--    的一律移除 —— 判装备本身，不判标签。**
--    但那条规则是在**生成阶段**（generate_bisdata_lua.py）执行的，只清了 BisData。
--    2026-09-02 新加的两条路径绕过了它：
--      GetCatalystSources / BuildJournalSourceMap 直接读**地下城手册**，
--      而手册是按「资料片」枚举的 —— 一个资料片里混着本赛季和上赛季的全部副本。
--    玩家因此在坯子弹窗里看到「众军指挥官头盔 · 至暗之夜」这种上赛季的件。
--
-- ✅ 运行期判据（与那条总规则同口径，且**现算**，跟着每周数据刷新走）：
--    本赛季权威副本集合 = BisData 里出现过的所有 instanceId；
--    本赛季装等下限     = BisData 里非制造装备的最低 ilvl。
--    「有 instanceId 且不在集合里」→ 上赛季，剔除。
-- ⛔ instanceId 缺失时**不剔除**：宁可漏放，也别把本赛季的件误杀
--    （curated/tierFiller 那批常常没有 instanceId，但它们本来就是清洗过的数据）。
local _seasonInst, _seasonFloor, _seasonSig
local function _ensureSeason()
    local bd = GearInsight.BisData
    if not bd then return nil end
    if _seasonSig == bd then return _seasonInst end
    local inst, floor, seen = {}, nil, {}
    -- ⛔⛔ 只看候选池，别把 tierFiller / 催化别名表也走一遍：它们自己就带 instanceId，
    --    上赛季团本（孢陨幽境 1305「腐沼」）残留在 tierFiller 里 → 被当成「本赛季副本」放行，
    --    弹窗第一条推荐上赛季坯子（Icarus 2026-09-11「现在竟然还会推荐上赛季的东西」）。
    local SKIP = { tierFiller = true, CatalystAlias = true, catalystAlias = true, PvpGear = true }
    local function walk(t, d)
        if d > 6 or type(t) ~= "table" or seen[t] then return end
        seen[t] = true
        for k, v in pairs(t) do
            if t == bd and SKIP[k] then v = nil end
            if type(v) == "table" then
                if v.itemId then
                    if v.instanceId then inst[v.instanceId] = true end
                    local lv = tonumber(v.ilvl)
                    if lv and lv > 0 and v.sourceCategory ~= "crafted" then
                        if not floor or lv < floor then floor = lv end
                    end
                else walk(v, d + 1) end
            end
        end
    end
    walk(bd, 0)
    if not next(inst) then return nil end        -- 数据没加载好就别设闸
    _seasonInst, _seasonFloor, _seasonSig = inst, floor, bd
    return _seasonInst
end

GearInsight.CurrentSeasonInstances = _ensureSeason   -- roll 币三选要找「本赛季团本」（main/RollVault.lua）

function GearInsight.IsCurrentSeasonSource(instanceId, ilvl)
    local set = _ensureSeason()
    if not set then return true end              -- 判不了就放行
    if not instanceId then return true end       -- 没有来源信息 → 不参与判定
    if set[instanceId] then return true end
    -- 不在本赛季副本表里：装等仍达到本赛季下限的放行（升级轨道能追上来的老件）
    local lv = tonumber(ilvl)
    if lv and _seasonFloor and lv >= _seasonFloor then return true end
    return false
end

-- ⛔⛔ 2026-09-02 玩家反馈：弹窗列出 4 件坯子，悬浮却写「转换优先级 #2/3」。
--   0.71.0 只统一了**排序器**，但三处仍各建各的列表、各取各的属性占比：
--     面板 = tierFiller[armor][slot]                                        → 3 条
--     悬浮 = tierFiller[armor][slotGroup]，且属性占比写死取团本那套          → 3 条
--     弹窗 = tierFiller + 调用方传入的 srcs + 地下城手册 GetCatalystSources  → 4 条
--   ⛔ 判据不是「有没有共用排序函数」，是「三处拿到的 list 是不是同一个」——
--     排序器再一致，喂进去的集合不同，序号和分母就必然对不上。
--   所以列表构建 + 属性占比选择一并收口到这里，三处只准走这一个入口。

-- 属性占比跟着「团本 / 大秘境高层 / 大秘境割草」开关走（与主面板 _statMode 同一套判定）。
-- ⛔ 悬浮原来写死 targetStatPercents（团本那套），大秘境模式下打分基准和面板不是一回事。
function GearInsight.FillerStatPct(specData)
    if type(specData) ~= "table" then return nil end
    local pct = specData.targetStatPercents
    local m = GearInsight._statMode
    if m == "mplusHigh" then
        pct = specData.targetStatPercentsMplus or pct
    elseif m == "mplusFarm" then
        pct = specData.targetStatPercentsMplusFarm or specData.targetStatPercentsMplus or pct
    elseif m == "mplusCommon" then
        pct = specData.targetStatPercentsMplusCommon or specData.targetStatPercentsMplusFarm or specData.targetStatPercentsMplus or pct
    end
    -- 「我的方案」启用时属性占比跟方案走（与主面板属性区同一来源）
    if GearInsight.BisPlan then
        local ok, pp = pcall(GearInsight.BisPlan.StatPercents, specData)
        if ok and pp then pct = pp end
    end
    return pct
end

-- 返回 list, raidOnly, statPct, complete
--   armor     本职业甲类；slotId 部位
--   extraSrcs 调用方额外掌握的同部位掉落（可为 nil）
--   specData  BisData.specs[specKey]，用来取属性占比
--   topStats  榜首那件的属性（可为 nil；只在同分时当次级判据，实际极少生效）
--   noScan    true = 绝不主动扫地下城手册，只吃已有缓存。
--             悬浮提示必须传 true：EJ 扫描会改全局筛选状态，不该由一次鼠标悬停触发。
--   complete  地下城手册那一段是否拿到了。false 时调用方**不许显示 #N/M**——
--             宁可不显示，也不能给一个和弹窗对不上的分母。
-- ── BiS 目标装等（与主面板 _slotPlan.topIlvl 同口径，⛔别在别处另算）──────────────
-- 链接带候选 bonusID 的装等；参照档=史诗时大秘境件抬到顶尖玩家见过的最高档（神话轨道 mx）。
-- 返回 topIlvl, hint —— hint 是「更高版本从哪来」的一句话（悬浮提示用）。
function GearInsight.RaidBossOrder(e)
    if not e then return nil end
    if e.bossOrder then return e.bossOrder end
    local orders = GearInsight.BisData and GearInsight.BisData.raidBossOrder
    return orders and e.encounterId and orders[e.encounterId] or nil
end

-- 一件坯子能拿到的最高装等（催化不改装等：坯子多少，转出来的套装就多少）。
-- 344 只来自当前团本 M7/M8（与 BisTargetPreview 同一条规则）；大秘境和其它首领最高 334。
-- ⛔ 刷本规划 / 多专精共刷以前对所有坯子都写套装目标 344，大米坯子也写 344（2026-09-29 用户：「大米没有344」）。
function GearInsight.FillerIlvlCap(e)
    if not e then return 334 end
    local cat = e.type or e.sourceCategory
    local order = GearInsight.RaidBossOrder and GearInsight.RaidBossOrder(e)
    if cat == "raid" and (order == 7 or order == 8) then return 344 end
    return 334
end

function GearInsight.IsVenomcursed(e)
    if not e then return false end
    for _, list in ipairs({ e.bonusIDs, e.previewBonusIDs }) do
        for _, id in ipairs(list or {}) do
            if id == 13708 or id == 13846 or id == 13847 then return true end
        end
    end
    return false
end

-- Companion / WCL 实时推荐可能只带某位玩家身上的低档实例，而同一个 itemId 在
-- 当前专精的团本或大秘境静态池里已有毕业实例。推荐图标、目标装等和附加提示必须
-- 使用同一份实例；否则原生 tooltip 会写 321，GearInsight 下一行却写 334/344。
function GearInsight.BisCanonicalEntry(e, specData)
    if not (e and e.itemId) then return e end
    local best, bestIlvl = e, tonumber(e.ilvl) or 0
    local sp = specData or GearInsight._curSpecData
    if not (sp and sp.bisBySlot) then return best end
    local pools = { sp.bisBySlot }
    -- mplusBySlot 独立于 specData。只看团本池会漏掉同款大秘境的神话 6/6
    -- 实例，例如阿曼尼督军的指环：英雄 6/6 为 321，神话 6/6 为 334。
    local key = rawget(sp, "_key")
    local mp = key and GearInsight.BisData and GearInsight.BisData.mplusBySlot
        and GearInsight.BisData.mplusBySlot[key]
    if mp then pools[#pools + 1] = mp end
    for _, bySlot in ipairs(pools) do
        for _, pool in pairs(bySlot or {}) do
            for _, c in ipairs(pool or {}) do
                local ilvl = tonumber(c.ilvl) or 0
                if c.itemId == e.itemId and ilvl > bestIlvl then
                    best, bestIlvl = c, ilvl
                end
            end
        end
    end
    return best
end

-- The packer keeps one concrete, WCL-observed highest instance for each itemId.
-- Keep its ilvl/bonusIDs together: never manufacture an item level or rewrite
-- bonus IDs from the source location alone.
function GearInsight.BisTargetBonusIDs(e, targetIlvl, specData)
    if not e then return nil end
    local canonical = GearInsight.BisCanonicalEntry(e, specData)
    local base = (canonical and canonical.bonusIDs and #canonical.bonusIDs > 0)
        and canonical.bonusIDs or e.bonusIDs
    return base
end

function GearInsight.BisTargetIlvl(e, specData)
    if e and e.targetStatsVerified then return e.ilvl, e.source end
    if not (e and e.itemId) then return 0, nil end
    local canonical = GearInsight.BisCanonicalEntry(e, specData)
    local topIlvl = tonumber(canonical and canonical.ilvl) or tonumber(e.ilvl)
    local bonus = canonical and canonical.bonusIDs
    if (not topIlvl or topIlvl <= 0) and bonus and #bonus > 0
        and C_Item and C_Item.GetDetailedItemLevelInfo and GearInsight.LinkMid then
        local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, "item:" .. e.itemId .. GearInsight.LinkMid()
            .. #bonus .. ":" .. table.concat(bonus, ":"))
        if ok and v and v > 0 then topIlvl = v end
    end
    topIlvl = topIlvl or 0
    local step = GearInsight.GearTierStep and GearInsight:GearTierStep() or 0
    local cat = e.sourceCategory or (canonical and canonical.sourceCategory)
    local hint
    if cat == "mplus" then
        hint = T("TTUP_HINT_MPLUS", "大秘境每周宝库（神话轨道）")
    elseif cat == "raid" then
        local diff = (step == 0 and T("TTUP_DIFF_MYTHIC", "史诗")) or (step == 13 and T("TTUP_DIFF_HEROIC", "英雄")) or T("TTUP_DIFF_NORMAL", "普通")
        hint = string.format(T("TTUP_HINT_RAID", "%s难度团本掉落"), diff)
    elseif cat == "tier" or e.isTier then
        hint = T("TTUP_HINT_TIER", "团本套装兑换物或珍玩兑换，或同部位坯子化生转换")
    elseif cat == "crafted" then
        hint = T("TTUP_HINT_CRAFTED", "用更高档火花重下工艺订单")
    else
        hint = T("TTUP_HINT_GENERIC", "更高难度的同款")
    end
    return topIlvl, hint
end

-- 主 BiS 面板、装备图和角色栏小图标的唯一目标实例入口。
-- 三处都必须使用这里返回的 link/bonusIDs/ilvl，禁止各自重新手拼。
function GearInsight.BisObservedPreview(e, specData)
    if not (e and e.itemId) then return nil end
    if e.targetStatsVerified and e.verifiedTargetLink then
        return {itemId=e.itemId, name=getCN(e.itemId) or e.name, ilvl=e.ilvl,
            bonusIDs=e.bonusIDs, link=e.verifiedTargetLink,
            icon=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.itemId)}
    end
    local ilvl, hint = GearInsight.BisTargetIlvl(e, specData)
    local bonus = GearInsight.BisTargetBonusIDs(e, ilvl, specData)
    if (not bonus or #bonus == 0) and e.previewBonusIDs then bonus = e.previewBonusIDs end
    local link
    if bonus and #bonus > 0 and GearInsight.LinkMid then
        link = "|Hitem:" .. e.itemId .. GearInsight.LinkMid() .. #bonus .. ":"
            .. table.concat(bonus, ":") .. "|h"
    end
    local canonical = GearInsight.BisCanonicalEntry(e, specData)
    local name = (getCN and getCN(e.itemId)) or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.itemId))
        or (canonical and (canonical.itemName or canonical.name)) or e.itemName or e.name or ("#" .. e.itemId)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.itemId)
    return { itemId = e.itemId, name = name, icon = icon, ilvl = ilvl, hint = hint, bonusIDs = bonus, link = link or e.link }
end

local TIER_DIRECT_MAX_ILVL = 334

-- WCL 的套装实穿样本常带 344 的轨道 bonus 13848；团本兑换物需要同一件
-- 真实的334轨道链接，不能传裸 itemID（裸模板会显示219）。
local function _tierToken334BonusIDs(bonusIDs)
    local out, found = {}, false
    for _, id in ipairs(bonusIDs or {}) do
        if id == 13848 then
            out[#out + 1] = 12854
            found = true
        else
            out[#out + 1] = id
        end
    end
    return out, found
end

local function _tierDirectRuleText()
    local locale = GetLocale and GetLocale()
    if locale == "zhTW" then
        return "團本套裝兌換物和珍玩最高334；344只限排名第一、可驗證的344坯子化生"
    elseif locale == "enUS" then
        return "Raid tier tokens and Curios top out at 334; 344 requires a verified rank-1 344 Catalyst base"
    end
    return "团本套装兑换物和珍玩最高334；344只限排名第一、可验证的344坯子化生"
end

local function _tierTokenCapText()
    local locale = GetLocale and GetLocale()
    if locale == "zhTW" then return "兌換物或珍玩最高334" end
    if locale == "enUS" then return "tier token or Curio tops out at 334" end
    return "兑换物或珍玩最高334"
end

function GearInsight.BisTargetPreview(e, specData, slotId)
    if not (e and e.itemId) then return nil end
    if e.planned then return GearInsight.BisObservedPreview(e, specData) end
    local tierItem = e
    if (e.isTier or e.sourceCategory == "tier" or e.source == "套装转换") and GearInsight.BuildFillerList then
        local sp = specData or GearInsight._curSpecData
        slotId = slotId or e.slotId
        if not slotId then
            for sl, pool in pairs(sp and sp.bisBySlot or {}) do
                for _, item in ipairs(pool) do if item.itemId == e.itemId then slotId = sl; break end end
                if slotId then break end
            end
        end
        local class = sp and sp.className or (UnitClass and select(2, UnitClass("player")))
        local armor = GearInsight.BisData and GearInsight.BisData.classArmor and GearInsight.BisData.classArmor[class]
        if armor and slotId then
            local list = GearInsight.BuildFillerList(armor, slotId, nil, sp, e.stats, true)
            -- 套装本体与坯子必须在同一张总榜横评。总榜第 1 若是套装本体，
            -- 就推荐它本身（兑换物/珍玩最高334），不能因为它不能作为化生材料
            -- 而跳到总榜第2的坯子。只有总榜第1本来就是非套装坯子时，才展示
            -- “化生为套装”的路径。
            local candidate = list and list[1]
            if candidate and candidate.attributeRank == 1 then
                if candidate.isTier and candidate.targetStatsVerified then return GearInsight.BisObservedPreview(candidate, sp) end
                local candidateIlvl = GearInsight.BisTargetIlvl(candidate, sp)
                local order = GearInsight.RaidBossOrder and GearInsight.RaidBossOrder(candidate)
                -- 344 坯子只能来自当前团本 M7/M8；不能把其他来源中同 itemId
                -- 的异常344 WCL 样本当作化生路径。
                if not candidate.isTier and (candidateIlvl < 344 or (candidate.type == "raid" and (order == 7 or order == 8))) then
                    e = candidate
                end
            end
        end
    end
    local result = GearInsight.BisObservedPreview(e, specData)
    -- 没有任何可化生坯子时，回退显示团本兑换物/珍玩的真实上限；不把
    -- WCL 中同 itemId 的344化生样本错归给团本直掉。
    if e == tierItem and (tierItem.isTier or tierItem.sourceCategory == "tier" or tierItem.source == "套装转换") then
        local observedIlvl = tonumber(result.ilvl)
        result.ilvl = math.min(observedIlvl or TIER_DIRECT_MAX_ILVL, TIER_DIRECT_MAX_ILVL)
        local tokenBonus, converted = _tierToken334BonusIDs(result.bonusIDs or tierItem.bonusIDs)
        -- 仅在已知344轨道时生成334真实链接；未知时宁可不伪造 bonus。
        if converted and GearInsight.LinkMid then
            result.bonusIDs = tokenBonus
            result.link = "|Hitem:" .. tierItem.itemId .. GearInsight.LinkMid() .. #tokenBonus .. ":"
                .. table.concat(tokenBonus, ":") .. "|h"
        elseif observedIlvl and observedIlvl <= TIER_DIRECT_MAX_ILVL and result.link then
            -- 已经是有效的334或更低档实例，保留完整链接，不能退回裸ID的219模板。
        else
            result.bonusIDs, result.link = nil, nil
        end
    end
    result.tierItemId = tierItem ~= e and tierItem.itemId or nil
    result.isFillerPreview = tierItem.itemId ~= e.itemId
    return result
end

function GearInsight.BuildFillerList(armor, slotId, extraSrcs, specData, topStats, noScan)
    local bd = GearInsight.BisData
    -- 第 4 参允许两种：完整的 specData（含 targetStatPercents，由本函数按模式选），
    -- 或调用方已经按模式算好的 statPct 平表。后者直接用，别再选一次。
    -- ⛔ 第 4 参为空时**自动取当前专精**：角色面板图标悬浮 / 掉落提醒原来传 nil → 没有属性打分 → 坯子顺序
    --    与主面板/物品悬浮（传了 specData）不一样（虔诚 2026-09-14：「为啥这两个推荐的不是一个装备」——
    --    监察官头冠悬浮说它是 #1/5，套装件悬浮却列 第一帝国头饰/世界之根华盖）。「同一把尺子」必须在入口兜底。
    local statPct
    local isSpec = type(specData) == "table" and (specData.bisBySlot or specData.className)
    if not isSpec then
        statPct = specData
        specData = GearInsight._curSpecData
    end
    if not specData and bd and bd.GetSpecData and GearInsight.StatReader then
        local ok, st = pcall(function() return GearInsight.StatReader:ReadAll() end)
        if ok and st and st.class and st.spec then
            specData = bd:GetSpecData(st.class, st.spec, st.heroTalent)
        end
    end
    if specData then statPct = GearInsight.FillerStatPct(specData) or statPct end
    local curated = armor and bd and bd.tierFiller and bd.tierFiller[armor]
        and bd.tierFiller[armor][slotId]

    -- One baked candidate set across plugin, website and mini program. The
    -- manual plan may change weights/selection; it never mutates shared rows.
    local pack = GearInsight.CatalystRecommendations
    if pack and pack.schemaVersion == 1 and type(specData) == "table" then
        local specKey = specData._key
        if not specKey then
            for k,v in pairs(bd and bd.specs or {}) do if v == specData then specKey=k; break end end
        end
        local prefix = specKey and specKey:match("^([^/]+/[^/]+)")
        if not prefix and specData.className and specData.specName then
            prefix = specData.className:upper() .. "/" .. specData.specName:upper()
        end
        local mode = bd and bd.GetUsageMode and bd:GetUsageMode() or "raid"
        mode = mode == "raid" and "raid" or "mplusHigh"
        local group = prefix and pack.groups[prefix .. "/" .. mode .. "/" .. slotId]
        if group then
            local rows = {}
            local weights = group.weights
            if GearInsight.BisPlan then
                local ok, value = pcall(GearInsight.BisPlan.StatPercents, specData)
                if ok and value then weights=value end
            end
            for _, raw in ipairs(group.items) do
                local e = {}; for k,v in pairs(raw) do e[k]=v end
                e.targetStatsVerified=true
                e.verifiedTargetLink=_fillerLink(e.itemId,e.bonusIDs)
                e.sourceCategory=e.type
                for _, chosen in ipairs(specData.bisBySlot and specData.bisBySlot[slotId] or {}) do
                    if chosen.planned and chosen.itemId==e.itemId then e.planned=true end
                end
                rows[#rows+1]=e
            end
            _sortFillers(rows,weights)
            local raidOnly = _filterFillerRanks(rows, bd.GetExcludeRaid and bd:GetExcludeRaid())
            return rows,raidOnly,weights,true
        end
    end

    local ej, complete = nil, true
    if noScan then
        ej = GearInsight._catalystCache and GearInsight._catalystCache[slotId]
        -- 随包候选已由团本掉落表和赛季大秘境掉落表生成，可独立排名。
        -- 手册缓存只补充本地发现，不能成为读取现成榜单的前置条件。
        complete = (ej ~= nil) or (type(curated) == "table" and #curated > 0)
    elseif GearInsight.GetCatalystSources then
        ej = GearInsight:GetCatalystSources(slotId)
    end

    local list, seen = {}, {}
    -- ⛔⛔ 去重不能「后来的直接丢掉」，必须**合并缺失字段**。
    --   三个来源的完整度不一样：tierFiller（curated）常常没有 instanceId /
    --   encounterId / type，而地下城手册（EJ）那份有。原来保留先到的那条，
    --   等于用残缺的盖掉完整的 —— 玩家 2026-09-02 看到的就是
    --   「有些副本能点手册、有些不能」（(点击手册) 要 instanceId），
    --   以及来源标签退化成默认值（标签要 type）。
    local FILL = { "instanceId", "encounterId", "type", "nameCn", "link", "bonusIDs",
                   "source", "sourceCategory", "bossName" }
    local byId = {}
    local function _add(src)
        for _, e in ipairs(src or {}) do
            -- 制造业装备催化转不了，永远不算坯子
            local isCrafted = (e.type == "crafted") or (e.sourceCategory == "crafted")
                or (e.source == "制造业")
            -- ⛔ 上赛季的件不进坡子候选（用户 2026-09-02）
            local inSeason = GearInsight.IsCurrentSeasonSource(e.instanceId, e.ilvl)
            -- ⛔ 幻化外观道具（护甲子类 5 = Cosmetic，装等 1、没有属性）不是坯子：手册会把它们和真装备一起列出来
            --   （09-25 网站对拍：妖术领主的面容 275937 / 凝视 275938、盘魂者的鲁希卡面具 281227）。与网站 build_plan_items 同一判据
            local isCosmetic = false
            if e.itemId and C_Item and C_Item.GetItemInfoInstant then
                local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(e.itemId)
                isCosmetic = (classID == 4 and subID == 5)
            end
            if e.itemId and not isCrafted and inSeason and not isCosmetic then
                local cur = byId[e.itemId]
                if not cur then
                    -- ⛔ 拷贝一份：直接拿原表再写字段会污染 BisData
                    cur = {}
                    for k, v in pairs(e) do cur[k] = v end
                    byId[e.itemId] = cur
                    seen[e.itemId] = true
                    list[#list + 1] = cur
                else
                    for _, k in ipairs(FILL) do
                        if cur[k] == nil and e[k] ~= nil then cur[k] = e[k] end
                    end
                end
            end
        end
    end
    _add(extraSrcs)
    _add(curated)
    _add(ej)
    -- ⭐ 本专精 BiS 池里同部位的团本 / 大秘境件也是坯子（用户 2026-09-24「这个坯子排名咋没有」）：
    --    沙漠卫士胸甲 = 大秘境轮换的旧资料片副本（塞塔里斯神庙）。地下城手册只扫本资料片的
    --    团本 / 地下城，tierFiller 又只收录了几件样本，所以它不在任何坯子名单里 ——
    --    悬浮只有「催化后 = BiS #1」没有 #N/M，宝库也不按坯子算。BiS 池是 WCL 实穿数据，
    --    池里的非套装、非制造件都能催化；赛季闸门照样过 _add。
    -- 本赛季套装五部位的团本直掉 Boss。WCL 的套装条目来源统一写成
    -- “套装转换”，所以不能依赖条目自身携带 encounterId。
    -- 兑换物和珍玩在史诗难度的上限都是 334；它不能因为同一套装 itemId
    -- 在 WCL 中还有 344 的化生实例，就被错误标成 M5 兑换物 344。
    local TIER_TOKEN_MAX_ILVL = 334
    local tierBossBySlot = {
        [1]  = { encounterId = 2887, bossName = "双子毒牙" },
        [3]  = { encounterId = 2894, bossName = "迷失的探险者" },
        [5]  = { encounterId = 2882, bossName = "万毒邪祟者瓦什尼克" },
        [7]  = { encounterId = 2871, bossName = "斯索拉克" },
        [10] = { encounterId = 2874, bossName = "陵寝哨兵" },
    }
    pcall(function()
        if not (type(specData) == "table" and specData.bisBySlot) then return end
        local pool, extra = specData.bisBySlot[slotId], {}
        for _, e in ipairs(pool or {}) do
            local cat = e.sourceCategory
            if e.itemId and not e.isTier and (cat == "raid" or cat == "mplus") then
                local where = (e.bossName and e.bossName ~= "") and e.bossName
                    or (e.source and tostring(e.source):gsub("^.-%-", "")) or ""
                extra[#extra + 1] = { itemId = e.itemId, bonusIDs = e.bonusIDs, ilvl = e.ilvl, type = cat,
                    nameCn = where, instanceId = e.instanceId, encounterId = e.encounterId,
                    source = e.source, sourceCategory = cat, bossName = e.bossName }
            end
        end
        _add(extra)
    end)
    -- ⭐ 套装件本体也进横评（用户 2026-09-17「套装本体也要参与排名，排名要写上来」「跟所有坯子排名」）：
    --    团本 BOSS 直掉的那件带**原生副属性**（不走催化、不继承坯子），和各坯子用同一把尺子打分。
    --    ⛔ 以前只在 ShowTierFiller（弹窗）里并进去，面板/悬浮走 BuildFillerList 拿不到 —— 又是
    --    「三处 list 不是同一个」：套装件悬浮只有「BiS #1 / 共3」，没有它在坯子横评里的名次。
    --    套装件从当前专精 bisBySlot 里找 isTier 的那条；属性按不带 bonusID 的基础链接现读。
    pcall(function()
        if not (type(specData) == "table" and specData.bisBySlot) then return end
        local pool = specData.bisBySlot[slotId]
        if not pool then return end
        for _, e in ipairs(pool) do
            if (e.isTier or e.sourceCategory == "tier") and e.itemId then
                local tierBoss = tierBossBySlot[slotId]
                local instanceId = e.instanceId or (tierBoss and 1320)
                local encounterId = e.encounterId or (tierBoss and tierBoss.encounterId)
                local bossName = (e.bossName and e.bossName ~= "" and e.bossName)
                    or (tierBoss and tierBoss.bossName)
                if seen[e.itemId] then
                    byId[e.itemId].isTier = true
                    byId[e.itemId].previewBonusIDs = e.bonusIDs
                    byId[e.itemId].instanceId = byId[e.itemId].instanceId or instanceId
                    byId[e.itemId].encounterId = byId[e.itemId].encounterId or encounterId
                    byId[e.itemId].bossName = byId[e.itemId].bossName or bossName
                elseif _fillerStats(e.itemId, {}) then
                    local ent = { itemId = e.itemId, bonusIDs = {}, previewBonusIDs = e.bonusIDs, type = "raid", isTier = true,
                                  nameCn = bossName or T("TIER_RAID_DIRECT", "团本直掉"),
                                  instanceId = instanceId, encounterId = encounterId, bossName = bossName,
                                  ilvl = math.min(tonumber(e.ilvl) or TIER_TOKEN_MAX_ILVL, TIER_TOKEN_MAX_ILVL),
                                  source = e.source, sourceCategory = e.sourceCategory }
                    byId[e.itemId] = ent; seen[e.itemId] = true; list[#list + 1] = ent
                end
                break
            end
        end
    end)
    if #list == 0 then return list, false, statPct, complete end

    for _, entry in ipairs(list) do
        local preview = GearInsight.BisObservedPreview(entry, specData)
        local bonus = preview and preview.bonusIDs
        local target = preview and preview.ilvl
        if entry.isTier then
            bonus = _tierToken334BonusIDs(bonus or entry.previewBonusIDs)
            target = math.min(tonumber(target) or TIER_DIRECT_MAX_ILVL, TIER_DIRECT_MAX_ILVL)
        end
        local link = bonus and #bonus > 0 and _fillerLink(entry.itemId, bonus)
        if link and C_Item and C_Item.GetDetailedItemLevelInfo then
            local ok, decoded = pcall(C_Item.GetDetailedItemLevelInfo, link)
            if ok and decoded == target then
                entry.verifiedTargetLink, entry.ilvl = link, target
            end
        end
    end
    _applyCatalystUsage(list, specData, slotId)
    _sortFillers(list, statPct, topStats and _statsKey(topStats) or nil)

    local raidOnly = _filterFillerRanks(list, bd and bd.GetExcludeRaid and bd:GetExcludeRaid())
    return list, raidOnly, statPct, complete
end

-- 最核心属性 = 该专精属性占比最高的那个
local function _coreStat(statPct)
    if type(statPct) ~= "table" then return nil end
    local LBL = { crit = { "STAT_CRIT", "暴击" }, haste = { "STAT_HASTE", "急速" },
                  mastery = { "STAT_MASTERY", "精通" }, versatility = { "STAT_VERS", "全能" } }
    local best, bv
    for _, k in ipairs({ "crit", "haste", "mastery", "versatility" }) do
        local v = tonumber(statPct[k])
        if v and (not bv or v > bv) then best, bv = k, v end
    end
    if not best then return nil end
    return best, T(LBL[best][1], LBL[best][2])
end

-- Ranking keeps native tier stats; preview keeps the same item's complete instance.
function GearInsight.FillerPreviewLink(entry, tierItem, targetBonus)
    if entry and entry.verifiedTargetLink then return entry.verifiedTargetLink end
    local bonus = entry.bonusIDs
    if entry.isTier then
        bonus = entry.previewBonusIDs
        if tierItem and tierItem.itemId == entry.itemId and targetBonus and #targetBonus > 0 then
            bonus = targetBonus
        end
    end
    if bonus and #bonus > 0 then
        return "|Hitem:" .. entry.itemId .. GearInsight.LinkMid() .. #bonus .. ":"
            .. table.concat(bonus, ":") .. "|h[item]|h"
    end
    return entry.link
end

function GearInsight:ShowTierFiller(armor, slotId, slotLabel, explicitSrcs, targetBonus, topStats, statPct, tierItem, force)
    -- force = 由「团本装备」/「使用率参照」按钮触发的**原地重画**，
    -- 不走下面的「同一部位再点一下就关窗」切换逻辑。
    if not force and self._tierFrame and self._tierFrame:IsShown() and self._tierFrame._slotId == slotId then
        self._tierFrame:Hide()
        return
    end
    -- 存一份参数，供 _refreshOpenPopups 原地重画用
    self._tierArgs = { armor, slotId, slotLabel, explicitSrcs, targetBonus, topStats, statPct, tierItem }
    -- ⛔ 属性占比按**当前**模式现算：切了使用率参照再刷新时，
    --   存在 _tierArgs 里的那份是旧模式的，直接用会“按钮变了、排序没变”。
    statPct = GearInsight.FillerStatPct(self._curSpecData) or statPct
    -- Merge three sources deduped by itemId, so a cold/slow Encounter Journal (which can
    -- return only a partial list on first access) can't wipe out the stable bis-data list:
    --   explicitSrcs (bis-data same-slot drops) + curated tierFiller + EJ (complete-but-flaky).
    -- ⛔ 合并/去重/排序/排除团本全在 BuildFillerList 里，面板与悬浮走的是同一个入口。
    -- statPct 上面已经按当前模式现算过了，直接传平表。
    local srcs, raidOnly, resolvedPct = GearInsight.BuildFillerList(
        armor, slotId, explicitSrcs, statPct, topStats, false)
    statPct = resolvedPct or statPct
    if #srcs == 0 then return end

    -- ⛔「团本装备：排除」时团本坯子必须让位：玩家排除了团本，弹窗第一条还是
    --   「盘卷祭坛（团本）」等于没排除（2026-09-01 玩家截图）。
    --   ⛔ 但不能直接删光 —— 有的部位本赛季只有团本出坯子，删光会变成空窗口，
    --   所以是「降到末尾 + 标注」，让人知道这个部位绕不开团本。
    local exRaid = self.BisData and self.BisData.GetExcludeRaid and self.BisData:GetExcludeRaid()

    if not self._tierFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightTierFrame")
        f:SetSize(500, 440)
        GearInsight:AnchorPopup(f)
        f:SetFrameStrata("DIALOG"); f:SetFrameLevel(30)
        f:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.08, 0.96)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        self._tierTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self._tierTitle:SetPoint("TOPLEFT", 16, -12)
        self._tierTitle:SetJustifyH("LEFT")
        -- 上半区：先把「要转成的这件套装」摆清楚（用户 2026-09-01：
        -- 「上面单独区域展示套装，下面展示转换排序」）
        local ti = f:CreateTexture(nil, "ARTWORK"); ti:SetSize(30, 30)
        ti:SetPoint("TOPLEFT", 16, -36)
        local tn = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tn:SetPoint("LEFT", ti, "RIGHT", 8, 0); tn:SetPoint("RIGHT", -16, 0)
        tn:SetJustifyH("LEFT")
        self._tierPieceIcon, self._tierPieceName = ti, tn
        local sep = f:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(0.3, 0.3, 0.3, 0.6); sep:SetHeight(1)
        self._tierSep = sep
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", 16, -70)
        hint:SetWidth(468); hint:SetJustifyH("LEFT")
        if hint.SetWordWrap then hint:SetWordWrap(true) end
        -- 主推属性单独一行（2026-09-01 用户：「这个主推属性单独放一行，然后都居左」）
        local hint2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint2:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -3)
        hint2:SetWidth(468); hint2:SetJustifyH("LEFT")
        if hint2.SetWordWrap then hint2:SetWordWrap(true) end
        self._tierHint2 = hint2
        hint:SetText(T("TIER_ATTRIBUTE_HINT", "属性推荐：按目标装等的完整副属性评分；同分并列。"))
        self._tierHint = hint
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -96); scroll:SetPoint("BOTTOMRIGHT", -28, 14)
        local scc = CreateFrame("Frame", nil, scroll); scc:SetWidth(460)
        scroll:SetScrollChild(scc); self._tierScrollChild = scc
        self._tierScroll = scroll
        self._tierFrame = f
    end
    local topKey, topText = _statsKey(topStats)
    local coreKey, coreText = _coreStat(statPct)
    -- Native tier and bases come from the same verified candidate set.
    -- Never append a naked itemId here: it has no target-level stats to score.
    _applyCatalystUsage(srcs, self._curSpecData, slotId)
    _sortFillers(srcs, statPct, topKey)
    raidOnly = _filterFillerRanks(srcs, exRaid)

    -- 上半区：要转成的套装 + 当前排名第 1 坯子的最高真实装等。
    -- 套装 itemId 自己可能在别的 WCL 样本里出现过 344；那不是当前 #1 坯子的
    -- 目标装等。催化结果必须继承 #1 坯子，所以这里绝不能再读 tierItem 的链接装等。
    if self._tierPieceIcon then
        local tid = tierItem and tierItem.itemId
        self._tierPieceIcon:SetTexture(tid and C_Item and C_Item.GetItemIconByID
            and C_Item.GetItemIconByID(tid) or 134400)
        local nm = tid and (getCN(tid) or (tierItem.name or ("#" .. tid))) or T("TIER_DEFAULT_SLOT", "套装")
        -- 弹窗标题必须和此刻画出的总榜使用同一份排序结果。总榜第一若是
        -- 套装本体，标题就按兑换物/珍玩的334显示；不能跳过它再用第二名坯子
        -- 的344覆盖。第一名本来是坯子时，344仍必须能验证为 M7/M8 团本掉落。
        local preview
        local candidate = srcs and srcs[1]
        if candidate and candidate.targetStatsVerified then
            preview = GearInsight.BisObservedPreview(candidate, self._curSpecData)
        elseif candidate and not candidate.isTier then
            local candidateIlvl = GearInsight.BisTargetIlvl(candidate, self._curSpecData)
            local order = GearInsight.RaidBossOrder and GearInsight.RaidBossOrder(candidate)
            if candidateIlvl < 344 or (candidate.type == "raid" and (order == 7 or order == 8)) then
                preview = GearInsight.BisObservedPreview(candidate, self._curSpecData)
            end
        end
        if not preview and tierItem then
            preview = GearInsight.BisObservedPreview(tierItem, self._curSpecData)
            preview.ilvl = math.min(tonumber(preview.ilvl) or TIER_DIRECT_MAX_ILVL, TIER_DIRECT_MAX_ILVL)
            preview.bonusIDs, preview.link = nil, nil
        end
        local previewIlvl = preview and preview.ilvl
        local ilv = previewIlvl and previewIlvl > 0 and (" |cFFFFD100[" .. previewIlvl .. "]|r") or ""
        self._tierPieceName:SetText("|cFFA335EE" .. nm .. "|r" .. ilv)
    end
    -- 副标题：主推属性 + 最核心属性（排序就是按这个专精的属性占比算的）
    if self._tierHint then
        self._tierHint:SetText(T("TIER_ATTRIBUTE_HINT", "属性推荐：按目标装等的完整副属性评分；同分并列。"))
    end
    if self._tierHint2 then
        local parts = {}
        if topText then
            parts[#parts + 1] = "|cFFFFD100" .. string.format(T("TIER_TOP_STATS", "主推属性：%s"), topText) .. "|r"
        end
        if coreText then
            parts[#parts + 1] = "|cFFFF9933" .. string.format(T("TIER_CORE_STAT", "最核心：%s"), coreText) .. "|r"
        end
        if exRaid then
            parts[#parts + 1] = raidOnly
                and ("|cFFFF6666" .. T("TIER_RAID_ONLY", "本部位坯子只出自团本") .. "|r")
                or ("|cFF9AE6A0" .. T("TIER_NONRAID_FIRST", "已按「排除团本」把非团本坯子排在前") .. "|r")
        end
        self._tierHint2:SetText(table.concat(parts, "   ·   "))
    end

    self._tierFrame._slotId = slotId
    self._tierTitle:SetText((slotLabel or T("TIER_DEFAULT_SLOT", "套装")) .. T("TIER_POPUP_SUFFIX", " 套装坯子"))

    local sc = self._tierScrollChild
    sc.rows = sc.rows or {}
    for _, r in ipairs(sc.rows) do r:Hide() end
    local y = 0
    for i, s in ipairs(srcs) do
        local row = sc.rows[i]
        if not row then
            row = CreateFrame("Button", nil, sc); row:SetSize(450, 32)
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT", 6, 0)
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.txt:SetPoint("LEFT", row.icon, "RIGHT", 8, 0); row.txt:SetPoint("RIGHT", -4, 0)
            row.txt:SetJustifyH("LEFT"); row.txt:SetJustifyV("MIDDLE")
            if row.txt.SetWordWrap then row.txt:SetWordWrap(true) end
            row:SetScript("OnEnter", function(s2)
                if not s2._itemId then return end
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                if s2._link then GameTooltip:SetHyperlink(s2._link)
                else GameTooltip:SetItemByID(s2._itemId) end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnClick", function(s2) _openSourceJournal(s2._instId, s2._bossId, s2._itemId, s2._isRaid) end)
            sc.rows[i] = row
        end
        row._itemId = s.itemId; row._instId = s.instanceId; row._bossId = s.encounterId
        row._isRaid = (s.type == "raid")
        -- ⛔⛔ 链接用坯子**自己**的 bonusIDs。以前把套装件的 targetBonus 嫁接到坯子 itemId 上，
        --   想让它「按目标装等显示」，结果游戏连属性、掉落 BOSS 的特效都按套装件渲染
        --   （玩家 Icarus 2026-09-05：「属性不对」「特效是尾王的衣服」）。装等差在下面的绿字里说。
        row._link = GearInsight.FillerPreviewLink(s, tierItem, targetBonus)
        local CATL = { raid = T("CAT_RAID", "团本"), mplus = T("CAT_MPLUS", "大秘境"), crafted = T("CAT_CRAFTED", "制造业"), world = T("CAT_WORLD", "世界掉落") }
        local srcTag = CATL[s.type] or T("CAT_MPLUS", "大秘境")
        local click = s.instanceId and ("  |cFFAAAAAA" .. T("JOURNAL_HINT", "(点击手册)") .. "|r") or ""
        local sourceText = localizedSource(s.nameCn or "", s.instanceId, s.encounterId)
        -- 团本来源统一只显示一次首领名：M6 双子毒牙（团本）。
        -- localizedSource 有时已经返回首领名，不能再在末尾追加一次。
        if s.type == "raid" then
            local order = GearInsight.RaidBossOrder and GearInsight.RaidBossOrder(s)
            local boss = s.bossName or s.nameCn
            if order and boss and boss ~= "" then
                sourceText = "M" .. order .. " " .. boss
            end
        end
        local useText = ""
        if s._catalystUsagePct ~= nil and (s._catalystUsageTotal or 0) > 0 then
            useText = string.format("  |cFF00FF00%.1f%%|r |cFF888888(%d/%d)|r",
                s._catalystUsagePct, s._catalystUsageCount or 0, s._catalystUsageTotal)
        end
        local suffix = useText .. "  |cFF808080· " .. sourceText .. " (" .. srcTag .. ")|r" .. click
        if s.isTier then
            if s._catalystSourceKind == "tierUnknown" then
                suffix = "  |cFFFFAA55套装成品·WCL不保留原坯身份|r" .. suffix
            else
                suffix = "  |cFFA335EE本体·团本兑换物兑换（最高334）·原生属性|r" .. suffix
            end
        end
        local function setRow(nm, icon)
            -- 绿字标在名字后面：玩家挑坯子挑的就是这个，不是挑哪个 BOSS
            local st, stKey = _fillerStats(s.itemId, s.bonusIDs)
            local statTag = ""
            if st then
                -- 最核心属性染成橙色，一眼看出这件带不带它
                local shown = st
                if coreText then
                    shown = shown:gsub(coreText, "|cFFFF9933" .. coreText .. "|r|cFF66BBFF", 1)
                end
                statTag = "  |cFF66BBFF[" .. shown .. "]|r"
            end
            local no = s.excludedByRaidFilter and "|cFF999999团本参考 · |r" or s.attributeRank and ("|cFFFFD100" .. s.attributeRank .. ".|r ")
                or "|cFF999999? |r"
            row.txt:SetText(no .. nm .. statTag .. suffix)
            row.icon:SetTexture(icon or 134400)
        end
        -- Names/icons load async from the client (localized zh_CN); show a placeholder
        -- until ready since uncached filler items have no name yet.
        local nm0 = getCN(s.itemId)
        setRow(nm0 or ("|cFF999999" .. T("LOADING", "加载中…") .. "|r"), C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(s.itemId))
        if not nm0 and Item and Item.CreateFromItemID then
            local it = Item:CreateFromItemID(s.itemId)
            local sid = s.itemId
            it:ContinueOnItemLoad(function()
                if row._itemId ~= sid then return end
                setRow(it:GetItemName() or ("#" .. sid), it:GetItemIcon())
            end)
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 4, y); row:Show()
        -- 行高按文本实际高度：一条换了行还按 32 排，会盖住下一条（截图里就是这样）
        local th = (row.txt.GetStringHeight and row.txt:GetStringHeight()) or 0
        local rh = math.max(32, math.ceil(th) + 10)
        row:SetHeight(rh)
        y = y - rh
    end
    for i = #srcs + 1, #sc.rows do sc.rows[i]:Hide() end
    sc:SetHeight(math.max(20, math.abs(y) + 8))
    -- Size the popup to the content so few rows don't leave a big empty box.
    local hintH = (self._tierHint and self._tierHint.GetStringHeight
        and math.ceil(self._tierHint:GetStringHeight())) or 12
    if self._tierHint2 and self._tierHint2:GetText() and self._tierHint2:GetText() ~= "" then
        hintH = hintH + math.ceil(self._tierHint2:GetStringHeight()) + 3
    end
    local headTop = 74 + hintH + 6
    if self._tierSep then
        self._tierSep:ClearAllPoints()
        self._tierSep:SetPoint("TOPLEFT", 12, -(headTop - 4))
        self._tierSep:SetPoint("TOPRIGHT", -12, -(headTop - 4))
    end
    if self._tierScroll then
        self._tierScroll:ClearAllPoints()
        self._tierScroll:SetPoint("TOPLEFT", 12, -headTop)
        self._tierScroll:SetPoint("BOTTOMRIGHT", -28, 14)
    end
    self._tierFrame:SetHeight(math.max(180, math.min(620, headTop + math.abs(y) + 18)))
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._tierFrame) end
    self._tierFrame:Show()
end

-- Popup: the top-5 highest-usage items for a single slot (current spec/hero
-- talent). Data comes straight from the slot's BiS candidate list, which is
-- already ordered by WCL usage. Mirrors ShowTierFiller's frame/row layout.
-- 某部位"使用率前5"参照池（始终不受团本排除影响，只随参照系变）。
-- 供前5弹窗首开与切换参照系/过滤后的原地刷新使用。
function GearInsight:_slotTop5Pool(slotId)
    local snapshot = self.SavedVars and self.SavedVars:GetLastSnapshot() or nil
    local class, spec, htal
    if snapshot then class = snapshot.class; spec = snapshot.spec; htal = snapshot.heroTalent end
    if (not class or not spec) and self.StatReader then
        local s = self.StatReader:ReadAll(); class = s.class; spec = s.spec; htal = s.heroTalent
    end
    if not (self.BisData and self.BisData.GetSlotUsagePool) then return nil end
    return self.BisData:GetSlotUsagePool(class, spec, htal, slotId)
end

-- 玩家 阿迪KING 2026-09-24：「推荐装备饰品这些能再往下看几个么」→ 用户「多看 4 个」：前 5 → 前 9
--（数据侧每格候选按使用率门槛筛，护甲多为 3 件、饰品戒指 8 件，有几件显示几件）
local TOP_SHOW = 9
function GearInsight:ShowSlotTop5(slotLabel, slotId, cands, keepOpen)
    -- 使用率前N 是"顶尖玩家使用率最高"的 meta 参照：按 团本/大秘境 参照系取未过滤池（重建不可用时回退调用方的 cands）。
    -- ⛔ 09-30 起勾了"团本装备:排除"就隐藏团本件（sourceCategory=="raid"），底部写明隐藏了几件 —— 以前始终含团本件，
    --    不打团本的玩家（法婶）看到团本鞋当成推荐。别改回"不受排除影响"。
    local pool = self:_slotTop5Pool(slotId)
    local filtered = cands          -- 调用方传的是过滤后的候选（排除团本/难度档），面板/装备图推荐从这里出
    if pool and #pool > 0 then cands = pool end
    -- ⭐ 10-01 用户「饰品这里有问题，跟戒指一样，点击应该是完全一样的，1-9，1.2放在最上面」：
    --   戒指（11/12）、饰品（13/14）两格是一组 —— 点哪一格都弹同一张榜：两格的使用率按物品合计（同一件不能两格都戴，直接相加），
    --   前两行固定是两格当前推荐（小格号在前），其余按合计使用率接着排，最多 9 行。
    local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }
    local other = PAIR[slotId]
    local pairPicks = nil
    if other then
        local pool2 = self:_slotTop5Pool(other)
        if pool and #pool > 0 and pool2 and #pool2 > 0 then
            local byId, merged = {}, {}
            for _, list in ipairs({ pool, pool2 }) do
                for _, e in ipairs(list) do
                    local m = byId[e.itemId]
                    if not m then
                        m = {}; for k, v in pairs(e) do m[k] = v end
                        m.usagePct = 0
                        byId[e.itemId] = m; merged[#merged + 1] = m
                    end
                    m.usagePct = math.min(100, (m.usagePct or 0) + (e.usagePct or 0))
                end
            end
            cands = merged
        end
        pairPicks = {}
        for _, s in ipairs({ math.min(slotId, other), math.max(slotId, other) }) do
            local pid = self._slotPlan and self._slotPlan[s] and self._slotPlan[s].topId
            if pid then pairPicks[#pairPicks + 1] = pid end
        end
        slotLabel = (slotId >= 13) and T("TOP5_PAIR_TRINKET", "饰品（两格合计）") or T("TOP5_PAIR_RING", "戒指（两格合计）")
    end
    if not cands or #cands == 0 then return end
    -- ⛔ 前5 是未过滤的真实榜，而面板推荐的是过滤后的 #1 —— 排除团本后推荐件常常不在前 5 里，
    --    玩家看成「推荐了榜上没有的装备」（风潇潇雨滴滴 2026-09-12：「点进去看前5没有，可直接装备栏看就会显示」）。
    --    推荐件不在前 5 就追加一行第 6 行，标「当前推荐 · 排除团本后 #N」。
    local recId = self._slotPlan and self._slotPlan[slotId] and self._slotPlan[slotId].topId
    local recEntry, recRank = nil, nil
    if recId then
        for i, e in ipairs(filtered or {}) do if e.itemId == recId then recEntry, recRank = e, i break end end
        if not recEntry then for _, e in ipairs(cands) do if e.itemId == recId then recEntry = e break end end end
    end
    -- keepOpen=true 用于切换参照系/过滤后的原地刷新，跳过"再次点击同部位则关闭"的切换逻辑。
    if not keepOpen and self._slotTopFrame and self._slotTopFrame:IsShown()
        and (self._slotTopFrame._slotId == slotId or (other and self._slotTopFrame._slotId == other)) then
        self._slotTopFrame:Hide()
        return
    end

    if not self._slotTopFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightSlotTopFrame")
        f:SetSize(420, 320)
        GearInsight:AnchorPopup(f)
        GearInsight:HookPopupReanchor(f)
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(50)
        f:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.08, 0.96)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        self._slotTopTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self._slotTopTitle:SetPoint("TOP", 0, -12)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", self._slotTopTitle, "BOTTOM", 0, -4)
        hint:SetText(T("TOP5_POPUP_HINT", "顶尖玩家该部位使用率最高的装备"))
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        -- 最多 5 行，不需要滚动，用普通 Frame 避免 UIPanelScrollFrameTemplate 自带的白圆滑块
        local scc = CreateFrame("Frame", nil, f); scc:SetPoint("TOPLEFT", 12, -50); scc:SetPoint("BOTTOMRIGHT", -8, 14)
        self._slotTopScrollChild = scc
        self._slotTopFrame = f
    end
    self._slotTopFrame._slotId = slotId
    self._slotTopFrame._slotLabel = slotLabel
    -- Title reflects the active usage reference (团本 / 大秘境) so the listed %
    -- are unambiguous and visibly track the 使用率参照 toggle.
    local modeLabel = ((GearInsightDB and GearInsightDB.usageMode) == "mplus")
        and T("USAGE_MPLUS", "大秘境") or T("USAGE_RAID", "团本")
    self._slotTopTitle:SetText((slotLabel or T("TOP5_DEFAULT_SLOT", "部位"))
        .. string.format(T("TOPN_TITLE_SUFFIX", " · 使用率前%d"), math.min(TOP_SHOW, #cands)) .. "  |cFFFFD100(" .. modeLabel .. ")|r")

    -- 数据侧回填的"备选"候选(usagePct=0,独狼模式兜底用)不属于"使用率前5"榜单，隐藏
    local nonzero = {}
    for _, e in ipairs(cands) do
        if (e.usagePct or 0) > 0 then nonzero[#nonzero + 1] = e end
    end
    if #nonzero > 0 then cands = nonzero end
    -- ⛔ 这个窗口叫「使用率前5」，就必须按使用率排：英雄/普通档下面板候选是「装等优先」的（0.80.10），
    --    直接拿来画会变成 #1 6.6% / #2 78.1%（黑月冥神 2026-09-13：「怎么低百分比的排在前面」）。
    --    （_slotTop5Pool 一直没接上真正的未过滤池，实际拿到的就是面板候选。）这里按使用率重排一份副本。
    do
        local sorted = {}
        for i, e in ipairs(cands) do sorted[i] = e end
        table.sort(sorted, function(x, y) return (x.usagePct or 0) > (y.usagePct or 0) end)
        cands = sorted
    end
    -- ⭐ 09-30 用户定（方案 A）：勾了「团本装备：排除」，这个榜也不显示团本件（与面板推荐同一判断 sourceCategory=="raid"）。
    --   玩家 法婶「我是不想打一点团本，插件能只显示大秘 bis 的吗，完全不看团本的那种」—— 旧设计里这个榜始终含团本件，
    --   选了大秘境 + 排除团本还看到团本鞋，被当成推荐。隐藏了几件在窗口底部写明，想看完整榜临时关掉排除即可。
    local hiddenRaid = 0
    if self.BisData and self.BisData.GetExcludeRaid and self.BisData:GetExcludeRaid() then
        local keep = {}
        for _, e in ipairs(cands) do
            if e.sourceCategory == "raid" then hiddenRaid = hiddenRaid + 1 else keep[#keep + 1] = e end
        end
        cands = keep
    end
    self._slotTopTitle:SetText((slotLabel or T("TOP5_DEFAULT_SLOT", "部位"))
        .. string.format(T("TOPN_TITLE_SUFFIX", " · 使用率前%d"), math.min(TOP_SHOW, #cands)) .. "  |cFFFFD100(" .. modeLabel .. ")|r")
    -- 两格一组：两格当前推荐固定在 #1 #2（不在榜里的从各自的候选里补），其余接着排
    local pickSet = {}
    if pairPicks and #pairPicks > 0 then
        local head, seen = {}, {}
        for _, pid in ipairs(pairPicks) do
            if not seen[pid] then
                local hit
                for _, e in ipairs(cands) do if e.itemId == pid then hit = e break end end
                if not hit then for _, e in ipairs(pool or {}) do if e.itemId == pid then hit = e break end end end
                if not hit then for _, e in ipairs(filtered or {}) do if e.itemId == pid then hit = e break end end end
                if hit then head[#head + 1] = hit; seen[pid] = true; pickSet[pid] = true end
            end
        end
        for _, e in ipairs(cands) do if not seen[e.itemId] then head[#head + 1] = e end end
        cands = head
        recEntry = nil                                    -- 推荐件已经在最上面，不再追加「第 N+1 行」
    end
    local extraRec = nil
    if recEntry then
        local inTop = false
        for i = 1, math.min(TOP_SHOW, #cands) do if cands[i].itemId == recId then inTop = true break end end
        if not inTop then extraRec = recEntry end
    end

    local sc = self._slotTopScrollChild
    sc.rows = sc.rows or {}
    for _, r in ipairs(sc.rows) do r:Hide() end
    local n = math.min(TOP_SHOW, #cands)
    if extraRec then
        local list = {}
        for i = 1, n do list[i] = cands[i] end
        list[n + 1] = extraRec
        cands = list; n = n + 1
    end
    local y = 0
    for i = 1, n do
        local c = cands[i]
        local row = sc.rows[i]
        if not row then
            row = CreateFrame("Button", nil, sc); row:SetSize(370, 32)
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT", 6, 0)
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.txt:SetPoint("LEFT", row.icon, "RIGHT", 8, 0); row.txt:SetPoint("RIGHT", -4, 0); row.txt:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(s2)
                if not s2._itemId then return end
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                if s2._link then GameTooltip:SetHyperlink(s2._link)
                else GameTooltip:SetItemByID(s2._itemId) end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnClick", function(s2) _openSourceJournal(s2._instId, s2._bossId, s2._itemId) end)
            sc.rows[i] = row
        end
        row._itemId = c.itemId; row._instId = c.instanceId; row._bossId = c.encounterId
        if c.bonusIDs and #c.bonusIDs > 0 then
            row._link = "|Hitem:" .. c.itemId .. GearInsight.LinkMid() .. #c.bonusIDs .. ":" .. table.concat(c.bonusIDs, ":") .. "|h[item]|h"
        else
            row._link = nil
        end
        local rankColor = (i == 1) and "|cFFFFD100" or "|cFFBBBBBB"
        local isRec = (extraRec ~= nil and i == n)
        local isPick = pickSet[c.itemId] and i <= 2
        if isRec or isPick then rankColor = "|cFF55E055" end
        local pct = c.usagePct and string.format("  |cFF00FF00%.1f%%|r", c.usagePct) or ""
        if isPick then pct = pct .. "  |cFF55E055" .. T("TOP5_REC_TAG0", "当前推荐") .. "|r" end
        if isRec then
            pct = pct .. "  |cFF55E055" .. (recRank and string.format(T("TOP5_REC_TAG", "当前推荐 · 过滤后 #%d"), recRank) or T("TOP5_REC_TAG0", "当前推荐")) .. "|r"
        end
        local ilvl = (c.ilvl and c.ilvl > 0) and (" |cFF888888[" .. c.ilvl .. "]|r") or ""
        local click = c.instanceId and ("  |cFFAAAAAA" .. T("JOURNAL_HINT", "(点击手册)") .. "|r") or ""
        local srcStr = localizedSource(c.source or "", c.instanceId, c.encounterId)
        local suffix = (srcStr ~= "" and ("  |cFF808080· " .. srcStr .. "|r") or "") .. click
        local function setRow(nm, icon)
            row.txt:SetText(rankColor .. (isRec and "★" or ("#" .. i)) .. "|r " .. nm .. ilvl .. pct .. suffix)
            row.icon:SetTexture(icon or 134400)
        end
        local nm0 = locName(c.itemId, c.itemName)
        setRow(nm0 or ("|cFF999999" .. T("LOADING", "加载中…") .. "|r"), C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(c.itemId))
        if not nm0 and Item and Item.CreateFromItemID then
            local it = Item:CreateFromItemID(c.itemId)
            local cid = c.itemId
            it:ContinueOnItemLoad(function()
                if row._itemId ~= cid then return end
                setRow(it:GetItemName() or ("#" .. cid), it:GetItemIcon())
            end)
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 4, y); row:Show()
        y = y - 32
    end
    for i = n + 1, #sc.rows do sc.rows[i]:Hide() end
    -- 排除团本时底部说明：隐藏了几件团本装备（榜单为空时同一行说清原因，不留空白窗口）
    if not sc.note then
        sc.note = sc:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sc.note:SetJustifyH("LEFT"); sc.note:SetWidth(370)
    end
    local noteH = 0
    if hiddenRaid > 0 then
        sc.note:SetText("|cFFFF9933" .. string.format(n == 0 and T("TOP5_ALL_RAID", "顶尖玩家这个部位穿的 %d 件都是团本装备，已按「团本装备：排除」隐藏")
            or T("TOP5_HIDDEN_RAID", "已隐藏 %d 件团本装备（团本装备：排除）"), hiddenRaid) .. "|r")
        sc.note:ClearAllPoints(); sc.note:SetPoint("TOPLEFT", 8, y - 4); sc.note:Show()
        noteH = 22
    else
        sc.note:Hide()
    end
    sc:SetHeight(math.max(20, math.abs(y) + 8 + noteH))
    -- 6 行（含追加的推荐行）时窗口加高，别把第 6 行挤出底边
    if self._slotTopFrame then self._slotTopFrame:SetHeight(extraRec and 352 or 320) end
    self._slotTopFrame:SetHeight(math.max(140, math.min(440, 64 + n * 32 + 10 + noteH)))
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._slotTopFrame) end
    self._slotTopFrame:Show()
end
