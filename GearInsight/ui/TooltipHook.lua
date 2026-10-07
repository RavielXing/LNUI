-- TooltipHook.lua
-- Global item-tooltip injection: appends a per-slot BiS rank line on any item
-- tooltip (bags, character sheet, auction house, merchant, adventure guide,
-- chat item links, bank, ...).
--
-- 12.x note: the legacy GameTooltip:HookScript("OnTooltipSetItem") + GetItem()
-- approach was removed in 10.0.2 and is dead code on 12.x. This file uses the
-- unified data pipeline TooltipDataProcessor.AddTooltipPostCall, which registers
-- once and fires for every item tooltip globally. The old HookScript path is kept
-- only as a backward-compat fallback for clients lacking the new API.

GearInsight = GearInsight or {}
local TooltipHook = {}

-- ── i18n (additive, zhCN-safe) ───────────────────────────────────────────
-- Mirrors GearInsight.lua's T(): on a zhCN client return the inline Chinese
-- verbatim (never touches a locale file); other clients read GearInsight.LOC.
-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。
-- ⛔别再写 GetLocale()：每个文件各抄一份就会出现“面板英文、大米攻略中文”这种分裂。
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    -- 逐级回退：当前语言 -> enUS -> 内联中文。与 GearInsight.lua 里的实现保持一致。
    -- ⛔别写回 `LOC[_LOCALE] or LOC["enUS"]` —— 那是**选表不选值**：
    --   只要 deDE 表存在但缺某个 key，就直接掉回简体中文，而不会先试英文，
    --   德/法/韩客户端会看到「大部分本地语言 + 零星简体中文」。
    -- ⚠繁中例外：缺 key 时回退到**简体**而不是英文（繁简互通，比英文可用）。
    local L = GearInsight.LOC or {}
    local cur = L[_LOCALE]
    if cur and cur[key] then return cur[key] end
    if _LOCALE ~= "zhTW" then
        local en = L["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

-- ── Slot grouping (rings / trinkets / weapons use a merged, deduped pool) ──
local SLOT_GROUP = {
    [11] = "FINGER", [12] = "FINGER",
    [13] = "TRINKET", [14] = "TRINKET",
    [16] = "WEAPON", [17] = "WEAPON",
}
-- For a group, which two raw slots make up its merged pool.
local GROUP_SLOTS = {
    FINGER  = { 11, 12 },
    TRINKET = { 13, 14 },
    WEAPON  = { 16, 17 },
}

-- Merge two slot candidate arrays into one usage-ranked pool, deduped by itemId
-- (keep the higher usagePct copy). Mirrors GearInsight._mergePairPool /
-- generate_bisdata_lua.py mergePool so ranking is consistent across the addon.
local function mergePool(a, b)
    local byId, order = {}, {}
    local function add(list)
        if type(list) ~= "table" then return end
        for _, e in ipairs(list) do
            local prev = byId[e.itemId]
            if not prev then
                byId[e.itemId] = e
                order[#order + 1] = e
            elseif (e.planRank and not prev.planRank) or (not prev.planRank and (e.usagePct or 0) > (prev.usagePct or 0)) then
                byId[e.itemId] = e
                for i, o in ipairs(order) do
                    if o.itemId == e.itemId then order[i] = e break end
                end
            end
        end
    end
    add(a); add(b)
    -- 方案件（planRank）排最前 —— 与 main/PanelRefresh.lua _mergePairPool 同一口径
    table.sort(order, function(x, y)
        local px, py = x.planRank or 99, y.planRank or 99
        if px ~= py then return px < py end
        return (x.usagePct or 0) > (y.usagePct or 0)
    end)
    return order
end

-- ── Reverse index: itemId -> list of { specKey, className, specName,
-- heroTalent, slotGroup, rank, total, usagePct } ──────────────────────────
-- Built once at load; tooltip callback is an O(1) hash lookup + nil check.
function TooltipHook:BuildItemIndex(bisData)
    -- ⛔⛔ 原来是「建一次就永久缓存」。数据每周刷新（或换赛季）之后，
    --   tooltip 里的排名一直是旧的，而且**不报错** —— 只能靠玩家发现
    --   「排名跟面板对不上」。按数据表身份做失效判断。
    -- ⛔⛔ 还要按「过滤签名」失效（玩家 虔诚 2026-09-11：勾了排除团本，悬浮还是「BiS #2 / 共3」）：
    --   索引是登录时按当时的 bisBySlot 建的，之后切「团本装备：排除」/ 使用率参照 / 难度档，
    --   面板那边 InvalidatePools 重建了，索引这边没人管，名次一直是旧池的。
    --   签名 = 过滤签名 + 难度档；变了就重建（切一次设置才重建一次，悬浮热路径只比字符串）。
    local sig = tostring(bisData and bisData._filterSig or "") .. "|t"
        .. tostring(GearInsight.GearTierStep and GearInsight:GearTierStep() or 0)
        .. "|m" .. tostring((GearInsightDB and GearInsightDB.usageMode) or "raid")
        .. "|p" .. ((GearInsight.BisPlan and GearInsight.BisPlan.Sig()) or "")   -- 「我的方案」变了也要重建
    if self._itemIndex and self._itemIndexSrc == bisData and self._itemIndexSig == sig then return self._itemIndex end
    self._itemIndexSig = sig
    local idx = {}
    local specs = bisData and bisData.specs
    if not specs then return idx end
    -- M+ usage lives in a separate per-spec map (itemId -> %). Raid usage is the
    -- item's baked usagePct (cached as _usageRaid once filters run).
    local mplusUsage = (bisData and bisData.mplusUsage) or {}

    -- 把某个 bySlot 表按槽组展开成 gid -> 有序候选池
    local function buildPools(bySlot)
        local pools, seenGroup = {}, {}
        for slotId, cands in pairs(bySlot or {}) do
            local group = SLOT_GROUP[slotId]
            if group then
                if not seenGroup[group] then
                    seenGroup[group] = true
                    local g = GROUP_SLOTS[group]
                    pools[group] = mergePool(bySlot[g[1]], bySlot[g[2]])
                end
            else
                pools[slotId] = cands
            end
        end
        return pools
    end

    for specKey, spec in pairs(specs) do
        local specMU = mplusUsage[specKey] or {}
        -- ⛔ 名次必须两套都建（#98 2026-08-31 玩家：「tooltip不一致，这个应该是第一吧」）：
        --   团本名次按 bisBySlot 池序，大秘境名次按 mplusBySlot 池序；
        --   Inject 时按「使用率参照」当前模式取对应那套 —— 与面板同一把尺子。
        -- ⛔ 当前参照系那一套必须用 spec.bisBySlot —— 它才是过滤（排除团本）+ 排序（英雄档装等优先）之后的池，
        --    面板/装备图推荐的 #1 就从这里出。原来大秘境模式也读原始 mplusBySlot，排除团本/切英雄档后
        --    面板推荐 #1、悬浮却写「#2 / 共3」（虔诚 2026-09-13 奥法项链）。另一套仍用原始池当参考数。
        local curMode = (GearInsightDB and GearInsightDB.usageMode) or "raid"
        local raidPools, mplusPools
        if curMode == "mplus" then
            mplusPools = buildPools(spec.bisBySlot)
            raidPools  = buildPools(spec._rawBisBySlot or spec.bisBySlot)
        else
            raidPools  = buildPools(spec.bisBySlot)
            -- ⚠️ mplusBySlot 是 BisData 顶层表(按 specKey 索引)，不在 spec 里
            mplusPools = buildPools((bisData.mplusBySlot or {})[specKey])
        end
        local gids = {}
        for gid in pairs(raidPools) do gids[gid] = true end
        for gid in pairs(mplusPools) do gids[gid] = true end
        for gid in pairs(gids) do
            local rp, mp = raidPools[gid], mplusPools[gid]
            -- 本槽池里的套装件（若有）：非套装坯子悬浮时提示「催化后=#N」（#98）
            local tRrank, tRname, tMrank, tMname
            for rank, e in ipairs(rp or {}) do
                if e.isTier then tRrank, tRname = rank, e.itemName break end
            end
            for rank, e in ipairs(mp or {}) do
                if e.isTier then tMrank, tMname = rank, e.itemName break end
            end
            local hits = {}          -- itemId -> hit（本 spec 本槽组一条）
            if rp then
                for rank, e in ipairs(rp) do
                    if e.itemId then
                        hits[e.itemId] = {
                            specKey   = specKey,
                            className = spec.className,
                            specName  = spec.specName,
                            heroTalent = spec.heroTalent,
                            slotGroup = gid,
                            rank      = rank,
                            total     = #rp,
                            usagePct  = e.usagePct or 0,
                            usageRaid = e._usageRaid or e.usagePct or 0,
                            usageMplus = specMU[e.itemId] or 0,
                            isTierSelf = e.isTier or nil,
                            entry     = e,       -- 目标装等/来源提示用（BisTargetIlvl）
                            topEntry  = rp and rp[1] or nil,
                            topEntryM = mp and mp[1] or nil
                        }
                    end
                end
            end
            if mp then
                for rank, e in ipairs(mp) do
                    if e.itemId then
                        local h = hits[e.itemId]
                        if not h then
                            h = {
                                specKey   = specKey,
                                className = spec.className,
                                specName  = spec.specName,
                                heroTalent = spec.heroTalent,
                                slotGroup = gid,
                                rank      = nil,     -- 不在团本池：团本模式下不显示
                                total     = rp and #rp or 0,
                                usagePct  = e.usagePct or 0,
                                usageRaid = 0,
                                usageMplus = specMU[e.itemId] or e.usagePct or 0,
                                entry     = e,
                                topEntry  = rp and rp[1] or nil,
                                topEntryM = mp and mp[1] or nil,
                            }
                            hits[e.itemId] = h
                        end
                        h.rankM = rank
                        h.totalM = #mp
                        h.entryM = e
                        h.topEntryM = mp[1] or h.topEntryM
                        if e.isTier then h.isTierSelf = true end
                        if (h.usageMplus or 0) == 0 then h.usageMplus = e.usagePct or 0 end
                    end
                end
            end
            for iid, h in pairs(hits) do
                if not h.isTierSelf then
                    h.tierRank, h.tierName = tRrank, tRname
                    h.tierRankM, h.tierNameM = tMrank, tMname
                end
                local list = idx[iid]
                if not list then list = {}; idx[iid] = list end
                list[#list + 1] = h
            end
        end
    end

    self._itemIndex = idx
    self._itemIndexSrc = bisData
    return idx
end

-- ── Config defaults / accessors ───────────────────────────────────────────
local function cfg()
    GearInsightDB = GearInsightDB or {}
    local c = GearInsightDB.tooltipBis
    if not c then c = {}; GearInsightDB.tooltipBis = c end
    if c.enabled == nil then c.enabled = false end  -- 默认关（玩家定制：悬浮提示 BiS 行）
    if c.mode == nil then c.mode = "all" end          -- "current" | "all" | "off"
    if c.maxOtherSpecs == nil then c.maxOtherSpecs = 3 end
    if c.showUsage == nil then c.showUsage = true end
    -- 显示范围（2026-06-06 用户需求）：默认只显示本职业（当前专精+其它专精），
    -- 其它职业行默认隐藏；本职业各专精可逐个勾掉（面板「悬浮提示」菜单）。
    if c.showOthers == nil then c.showOthers = false end
    -- 来源行默认关（玩家定制：悬浮提示显示来源行）
    if c.showSource == nil then c.showSource = false end
    c.hiddenSpecs = c.hiddenSpecs or {}   -- "CLASS/SPEC" -> true = 该专精不显示
    -- minRank stays nil unless set
    return c
end
GearInsight._tooltipBisCfg = cfg  -- expose for slash handler

-- ── Spec display name: localized at runtime, cached by specKey ─────────────
local _specNameCache = {}
local function specDisplayName(hit, specOnly)
    -- specOnly: drop the class suffix (used on the same-class line, where the
    -- class is implied) — falls back to the full name if spec name is unknown.
    local key = specOnly and ("@" .. hit.specKey) or hit.specKey
    local cached = _specNameCache[key]
    if cached then return cached end

    -- Localized class name from the global class-name table (classFile -> name).
    local classLocalized
    if hit.className then
        classLocalized = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[hit.className])
            or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[hit.className])
    end

    -- Localized spec name via GetSpecializationInfoByID (returns id, name, ...).
    local specLocalized
    local bd = GearInsight.BisData
    local specId = bd and bd.specIds and bd.specIds[(hit.className or "") .. "/" .. (hit.specName or "")]
    if specId and GetSpecializationInfoByID then
        local ok, _, nm = pcall(GetSpecializationInfoByID, specId)
        if ok and nm and nm ~= "" then specLocalized = nm end
    end
    -- Custom specs (e.g. DEVAURER/噬灭) aren't in the client's GetSpecializationInfoByID,
    -- so fall back to the baked raw→中文 map; never show class-only (looks like a missing spec).
    if not specLocalized and bd and bd.specRawToCN then
        specLocalized = bd.specRawToCN[hit.specName]
    end

    local name
    if specOnly and specLocalized then
        name = specLocalized                          -- e.g. 恢复 (class implied)
    elseif specLocalized and classLocalized then
        name = specLocalized .. classLocalized        -- e.g. 增强萨满祭司
    elseif specLocalized then
        name = specLocalized
    elseif classLocalized then
        name = classLocalized
    else
        -- Fallback: raw keys (rare; e.g. new spec without an ID mapping)
        name = (hit.specName or "?") .. "/" .. (hit.className or "?")
    end
    _specNameCache[key] = name
    return name
end

-- Tooltip 语义色：同一种信息始终用同一种颜色，避免排名、模式、专精、
-- 使用率全挤成一片白字（#163，zlll）。颜色只承担“快速定位”作用，
-- 文字本身仍完整说明含义，不能只靠颜色传达信息。
local TIP_COLOR = {
    rank = "FFD75A",       -- BiS 名次 / 结论
    text = "F2F2F2",       -- 装备名 / 主要内容
    percent = "8CD98C",    -- 使用率
    raid = "FF8A5B",       -- 团本
    mplus = "49C7FF",      -- 大秘境
    action = "74D68B",     -- 可执行的升级动作
    warning = "FFB347",    -- 升不到 / 需要另取
    muted = "9299A8",      -- 次要说明 / 汇总
}
local function tipColor(hex, text)
    return "|cFF" .. hex .. tostring(text or "") .. "|r"
end
local function tipLabel(text)
    return tipColor(TIP_COLOR.muted, text .. T("TTBIS_COLON", "："))
end
local function specColor(hit, text)
    local c = hit and hit.className and RAID_CLASS_COLORS and RAID_CLASS_COLORS[hit.className]
    local hex = c and c.colorStr
    if hex and #hex >= 8 then return "|c" .. hex .. tostring(text or "") .. "|r" end
    return tostring(text or "")
end

-- ── Slot-group / slot label ────────────────────────────────────────────────
local function slotLabel(slotGroup)
    if slotGroup == "FINGER" then return T("TTBIS_SLOT_FINGER", "戒指") end
    if slotGroup == "TRINKET" then return T("TTBIS_SLOT_TRINKET", "饰品") end
    if slotGroup == "WEAPON" then return T("TTBIS_SLOT_WEAPON", "武器") end
    -- Plain numeric slotId → reuse existing GearReader slot keys (GearInsight.L).
    local gr = GearInsight.GearReader
    local L = GearInsight.L or {}
    local slotKey = gr and gr:GetSlotKey(slotGroup) or nil
    if slotKey then return L[slotKey] or slotKey end
    return tostring(slotGroup)
end

-- ── Item ID extraction from tooltip data ────────────────────────────────────
local function getItemIdFromData(tooltip, data)
    if data and data.id then return data.id end
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tooltip)
        if link then
            local id = link:match("item:(%d+):")
            return id and tonumber(id) or nil
        end
    end
    return nil
end

-- ── Core renderer: append BiS rank lines to the tooltip ─────────────────────
function TooltipHook:Inject(tooltip, itemId)
    tooltip._giTierCompact = nil
    tooltip._giHasBisSource = nil
    if not itemId then return end
    local c = cfg()
    if not c.enabled or c.mode == "off" then return end

    -- 每次悬浮先对一下签名：设置没变就是一次表比较，变了才重建（见 BuildItemIndex）
    local bd = (self.addon and self.addon.BisData) or GearInsight.BisData
    if bd and bd.ApplyDataFilters then bd:ApplyDataFilters() end
    local idx = bd and self:BuildItemIndex(bd) or self._itemIndex
    if not idx then return end
    -- 套装本体和可化生候选共用横评总榜，不能先被散件实穿榜截走。
    if self:InjectFillerOnly(tooltip, itemId, false) then return true, true end
    -- 有赛季 BiS 命中时只渲染主块；坯子兜底只服务于完全没有 BiS 命中的物品。
    -- 否则同一 tooltip 会出现两个 GearInsight 标题和两套重复排名。
    local hits = idx[itemId]
    if not hits then
        local fillerRendered = self:InjectFillerOnly(tooltip, itemId, false)
        return fillerRendered, fillerRendered
    end
    local fillerRendered = false

    -- 当前使用率参照模式（团本/大秘境）：名次、排序、高亮全按它取（#98）。
    local bd0 = GearInsight.BisData
    local mode = (bd0 and bd0.GetUsageMode and bd0:GetUsageMode())
        or ((GearInsightDB and GearInsightDB.usageMode) or "raid")
    -- 有效名次：当前模式的池里有名次就用它；没有时仍可展示另一套，
    -- 但必须把名次所属模式一起返回。否则团本 #1 和大秘境 #1 都会被写成
    -- 无口径的「BiS #1」，玩家会误以为同一榜单有两个第一（2026-09-26）。
    local function erank(h)
        if mode == "mplus" then
            if h.rankM then return h.rankM, h.totalM, "mplus" end
            return h.rank, h.total, "raid"
        end
        if h.rank then return h.rank, h.total, "raid" end
        return h.rankM, h.totalM, "mplus"
    end
    local function rankModeName(rankMode)
        return rankMode == "mplus"
            and T("USAGE_MPLUS", "大秘境") or T("USAGE_RAID", "团本")
    end

    -- Optional rank cap.
    local minRank = c.minRank
    local filtered = {}
    for _, h in ipairs(hits) do
        local r = erank(h)
        if r and (not minRank or r <= minRank) then filtered[#filtered + 1] = h end
    end
    if #filtered == 0 then return fillerRendered, fillerRendered end

    -- Determine current spec.  Wrap in pcall: on custom servers some stat APIs
    -- return "secret number values" that taint the execution context, causing any
    -- comparison/arithmetic on them to throw even inside an inner pcall.
    -- 缓存：ReadAll 内部会遍历整棵天赋树(readHeroTalent)，tooltip 是热路径，
    -- 鼠标扫一排 BiS 物品就是连续全树遍历。这里缓存 class/spec，
    -- RefreshData(切专精事件必经)时由主文件置空 _specCache 失效。
    local class, spec, hero
    local cache = self._specCache
    if cache then
        class, spec, hero = cache.class, cache.spec, cache.hero
    elseif self.addon and self.addon.StatReader then
        local ok, st = pcall(function() return self.addon.StatReader:ReadAll() end)
        if ok and st then
            class = st.class
            spec  = st.spec
            hero  = st.heroTalent
        end
        -- heroTalent 一并缓存：BisData 的 key 是三段 CLASS/SPEC/Hero，
        -- 少了它就取不到 specData（坯子那条路径要用）。
        self._specCache = { class = class, spec = spec, hero = hero }  -- 读失败也缓存，避免每次悬停重试
    end

    -- Split into current-spec hit + same-class other specs + other classes.
    -- Same-class specs get their own (brighter, uncapped) line so the player
    -- immediately sees how the item ranks for their off-specs.
    local catShown = fillerRendered or false
    local cur, sameClass, others = nil, {}, {}
    for _, h in ipairs(filtered) do
        if class and spec and h.className == class and h.specName == spec then
            -- keep the best-ranked current-spec hit (normally only one)
            if not cur or (erank(h) or 999) < (erank(cur) or 999) then cur = h end
        elseif class and h.className == class then
            -- 用户勾掉的本职业专精不显示
            if not c.hiddenSpecs[h.className .. "/" .. h.specName] then
                sameClass[#sameClass + 1] = h
            end
        else
            others[#others + 1] = h
        end
    end

    -- In "current" mode, only the current spec line is shown.
    if c.mode == "current" then sameClass = {}; others = {} end
    -- 其它职业行：默认隐藏，需在「悬浮提示」菜单或 /gi tooltip others 打开
    if not c.showOthers then others = {} end

    if not cur and #sameClass == 0 and #others == 0 then return fillerRendered, fillerRendered end

    -- Sort other-spec hits: rank asc, then usage desc.
    local function byRankThenUsage(x, y)
        local rx, ry = erank(x) or 999, erank(y) or 999
        if rx ~= ry then return rx < ry end
        return (x.usagePct or 0) > (y.usagePct or 0)
    end
    table.sort(sameClass, byRankThenUsage)
    table.sort(others, byRankThenUsage)

    -- Header.
    tooltip:AddLine(" ")
    -- ⭐ 表头必须说清楚这块是**赛季 BiS 排名**（静态榜），不是 Companion 的个性化建议。
    --   两者数据源本来就不同（榜是整条排名；实时推荐每槽只给 1 件），
    --   不标注就会被当成互相矛盾 —— 玩家反馈「毕业装跟悬浮的 BiS 不一样」的真身
    --   （台账 #20，2026-08-30 用户定口径 B：保留两套数据，把话说清楚）。
    tooltip:AddLine("|cFF00FF00" .. T("TTBIS_HEADER", "GearInsight") .. "|r"
        .. "  |cFF888888" .. T("TTBIS_SEASON_TAG", "赛季 BiS 排名") .. "|r", 1, 1, 1)

    -- A. Current spec line (highlighted).
    if cur then
        local cr, ct, rankMode = erank(cur)
        local modeHex = rankMode == "mplus" and TIP_COLOR.mplus or TIP_COLOR.raid
        local rankText = slotLabel(cur.slotGroup) .. " · " .. rankModeName(rankMode)
            .. " #" .. (cr or 0) .. "/" .. (ct or 0)
        tooltip:AddLine(tipColor(TIP_COLOR.rank, rankText) .. "  "
            .. specColor(cur, specDisplayName(cur, true)), 1, 1, 1, true)
        if c.showUsage then
            local usageRaid, usageMplus = cur.usageRaid or 0, cur.usageMplus or 0
            tooltip:AddLine(tipColor(TIP_COLOR.muted, T("TTBIS_USAGE_LABEL", "使用率："))
                .. tipColor(TIP_COLOR.raid, string.format(T("TTBIS_USAGE_RAID", "团本 %.1f%%"), usageRaid))
                .. "  " .. tipColor(TIP_COLOR.mplus, string.format(T("TTBIS_USAGE_MPLUS", "大秘境 %.1f%%"), usageMplus)), 1, 1, 1, true)
        end
        local topForMode = (rankMode == "mplus" and cur.topEntryM) or cur.topEntry
        local function entryName(e)
            if not e then return nil end
            local h = GearInsight._h
            return (h and h.locName and h.locName(e.itemId, e.itemName))
                or e.itemName or e.nameCn or (e.itemId and ("#" .. e.itemId))
        end
        local compact = {}
        if not fillerRendered and topForMode and topForMode.itemId then
            -- 只要「在哪刷」那半句：直接取 TopFillerParts，别再对整句 TopFillerLine 做中文 gsub（英文客户端剥不掉前缀）
            local _, where = self:TopFillerParts({ top = topForMode })
            tooltip._giHasBisSource = where ~= nil
            if topForMode.itemId ~= itemId then
                local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(topForMode.itemId)
                local tex = icon and ("|T" .. icon .. ":14|t ") or ""
                compact[#compact + 1] = tipColor(TIP_COLOR.muted, T("TTBIS_TOP_PICK", "首选："))
                    .. tex .. tipColor(TIP_COLOR.rank, entryName(topForMode) or T("TTBIS_UNKNOWN", "未知"))
            end
            if where then
                compact[#compact + 1] = tipColor(TIP_COLOR.muted, T("TTBIS_SOURCE_LABEL", "来源："))
                    .. tipColor(TIP_COLOR.action, where)
            end
        end
        for _, line in ipairs(compact) do tooltip:AddLine(line, 1, 1, 1, true) end
        -- 12.1 催化会继承坯子的副属性与特殊效果，但 WCL 没给完整实例 modifiers，
        -- 无法造出一个既保留套装名、又能让客户端正确渲染继承属性的超链接。
        -- 数据层保留真实坯子身份；这里把目标版本说清楚，避免 native 套装属性与
        -- 坯子绿字被拼成不存在的混合 tooltip（#162，暗夜蝶）。
        local variants = bd0 and bd0.tierVariants and bd0.tierVariants[cur.specKey]
        local variantPool = variants and (variants[mode] or variants.raid or variants.mplus)
        local variant = variantPool and variantPool[itemId]
        if false and variant then
            local statName = variant.stat == "crit" and T("STAT_CRIT", "暴击")
                or variant.stat == "mastery" and T("STAT_MASTERY", "精通")
                or variant.stat == "haste" and T("STAT_HASTE", "急速")
                or variant.stat == "versatility" and T("STAT_VERSATILITY", "全能")
                or variant.stat or ""
            tooltip:AddLine("|cFFB060FF" .. string.format(
                T("TTBIS_TIER_VARIANT", "推荐催化：%s → 单%s + %s（第三属性以实际坯子为准）"),
                variant.name or ("#" .. tostring(variant.itemId or "?")), statName,
                variant.effect or T("TTBIS_TIER_EFFECT", "继承特效")) .. "|r", 0.69, 0.38, 1, true)
        end
        -- ⭐ 这件就是 BiS 但装等没到：说清「差多少 + 更高版本从哪来」（用户 2026-09-17
        --    「tooltip 里也要提示 bis 要更高装等，获取位置」）。目标装等走 BisTargetIlvl（主面板同口径）。
        pcall(function()
            if not cur.entry then return end
            -- ⛔ 只有「就是 BiS 那件」才配说「件对了」：单槽 = #1，戒指/饰品 = 前 2（配对槽共用池）。
            --    #15/15 的戒指也进池子，不能对它说「件对了装等还差」（用户 2026-09-17 截图）。
            local rk = erank(cur) or 99
            local paired = (cur.slotGroup == "FINGER" or cur.slotGroup == "TRINKET")
            if rk > (paired and 2 or 1) then return end
            local link
            if TooltipUtil and TooltipUtil.GetDisplayedItem then
                local _, l = TooltipUtil.GetDisplayedItem(tooltip); link = l
            elseif tooltip.GetItem then
                local _, l = tooltip:GetItem(); link = l
            end
            if not link then return end
            local here = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or 0
            local targetEntry = (rankMode == "mplus" and cur.entryM) or cur.entry
            local target, hint = GearInsight.BisTargetIlvl(targetEntry)
            local targetPreview = GearInsight.BisTargetPreview and GearInsight.BisTargetPreview(targetEntry)
            if targetPreview then target, hint = targetPreview.ilvl, targetPreview.hint end
            if here > 0 and target > 0 and here < target then
                -- ⛔ 不许误导（用户 2026-09-17「没法升级到位，就说明白」）：先看这件的轨道升满能到多少，
                --    到不了目标就明说「升不到，要去刷 X」；到得了才说「升级到位即可」。每档 +3，与 TrackWarn 同口径。
                -- ⛔ 轨道变量别叫 cur：外层的 cur 是本专精命中记录，下面还要读 cur.isTierSelf。
                --    以前这里 `local cur, mx, … = TipTrack()` 把它遮住 → cur.isTierSelf 对数字取字段报错，
                --    被 pcall 吞掉，「去刷横评 #1」那行从来没出来过。
                local trkCur, trkMax, tname, il = self:TipTrack(tooltip)
                local ceil = (trkCur and trkMax and il) and (il + math.max(trkMax - trkCur, 0) * 3) or nil
                local how, howColor
                if ceil and ceil + 2 < target then
                    howColor = TIP_COLOR.warning
                    how = string.format(T("TTUP_CANT_COMPACT", "%s%d/%d 升满 %d，需另取：%s"),
                        (tname and tname ~= "") and (tname .. " ") or "", trkCur, trkMax, ceil, hint or "")
                elseif ceil then
                    howColor = TIP_COLOR.action
                    how = string.format(T("TTUP_CAN_COMPACT", "%s%d/%d，可直接升到 %d"),
                        (tname and tname ~= "") and (tname .. " ") or "", trkCur, trkMax, ceil)
                else
                    howColor = TIP_COLOR.warning
                    how = string.format(T("TTUP_UNKNOWN_COMPACT", "更高版本：%s"), hint or "")
                end
                tooltip:AddLine(tipColor(TIP_COLOR.rank, string.format(T("TTUP_ILVL_COMPACT", "装等 %d → %d"), here, target))
                    .. "  " .. tipColor(howColor, how), 1, 1, 1, true)
                -- 套装件装等不够：直接说横评 #1 的坯子去哪刷（用户 2026-09-17）
                if cur.isTierSelf and not fillerRendered then
                    local cache = self._specCache
                    local fh = cache and self:FillerHit(itemId, cache.class, cache.spec, cache.hero)
                    local farm = fh and self:TopFillerLine(fh)
                    if farm then tooltip:AddLine(farm, 1, 0.75, 0.2, true) end
                end
            end
        end)
        -- 催化提示（#98 2026-08-31 玩家：「tooltip不一致，这个应该是第一吧」）：
        -- 手里这件是套装坯子、催化转换后就是同槽更高名次的套装件 —— 把这层说出来，
        -- 否则「面板推荐它当坯子」和「悬浮说它 #2」看起来自相矛盾。
        local tr, tn
        if mode == "mplus" then
            tr, tn = cur.tierRankM or cur.tierRank, cur.tierNameM or cur.tierName
        else
            tr, tn = cur.tierRank or cur.tierRankM, cur.tierName or cur.tierNameM
        end
        local cr2 = erank(cur)
        -- ⛔ 这行只在「当前专精命中(cur) 且 套装件名次更靠前」时才出。
        --   命不中的两种情况都得由 InjectFillerOnly 兜底，所以要把「出没出」报给调用方，
        --   ⛔别再用「Inject 有没有渲染」当判据 —— 本职业其它专精那几行也算渲染，
        --   会把兜底整个挡掉（玩家 2026-09-02：「124都有了，这个3没有」）。
        if false and tr and tn and cr2 and tr < cr2 then
            catShown = true
            -- 顺带把「在坯子里排第几」说出来：面板/弹窗/悬浮三处必须同一个排序器，
            -- 否则又变成「谁第一」各说各话（用户 2026-09-01：「不能有俩第一」）。
            local rankTxt = ""
            pcall(function()
                local bd = GearInsight.BisData
                local sp = bd and bd.specs and bd.specs[cur.specKey]
                local armor = bd and bd.classArmor and bd.classArmor[cur.className]
                if not (sp and GearInsight.BuildFillerList) then return end
                -- ⛔ noScan=true：悬停一下不该去扫地下城手册（会改全局 EJ 筛选状态）。
                --   面板渲染时已经扫过并缓存了，这里直接吃缓存。
                -- ⛔ complete=false（缓存还没热）时**一律不显示 #N/M** ——
                --   宁可不显示，也不能给一个和弹窗对不上的分母。
                --   （2026-09-02 玩家截图：弹窗 4 件，悬浮写 #2/3）
                local list, _, _, complete = GearInsight.BuildFillerList(
                    armor, cur.slotGroup, nil, sp, nil, true)
                if not complete then
                    -- 悬浮里不现扫（会改手册筛选）；排到下一帧补扫，再悬浮一次就有 #N/M
                    if C_Timer and GearInsight.WarmCatalystCache then C_Timer.After(0.2, function() GearInsight.WarmCatalystCache() end) end
                    return
                end
                for idx, e in ipairs(list) do
                    if e.itemId == itemId then
                        rankTxt = string.format(T("TTBIS_FILLER_ONLY", "套装坯子 #%d/%d"), idx, #list)
                        -- 「我的方案」选定的坯子（GIB1 cf）标出来
                        local BPl = GearInsight.BisPlan
                        local okC, ch = pcall(function() return BPl and BPl.ChosenFiller and BPl.ChosenFiller(sp, cur.slotGroup) end)
                        if okC and ch == itemId then rankTxt = rankTxt .. " |cffffd100· " .. T("TTBIS_FILLER_PLAN", "方案选定") .. "|r" end
                        break
                    end
                end
            end)
            -- 用户 2026-09-24「这种直接优化成显示坯子就行了，套装不见，不用显示套装的排名了」：
            -- 只报坯子横评名次；名次还没算出来（手册缓存冷）时退回一句「本部位套装坯子」
            tooltip:AddLine(rankTxt ~= "" and rankTxt or T("TTFILLER_IS", "本部位套装坯子"), 0.55, 0.78, 1, true)
            -- 坯子轨道封顶预警（虔诚 2026-09-12）
            pcall(function()
                local cache = self._specCache
                if not cache then return end
                local hit = self:FillerHit(itemId, cache.class, cache.spec, cache.hero)
                if hit then self:TrackWarn(tooltip, hit) end
            end)
        end
    end

    -- B1. Same-class other specs: own line, brighter, never folded (a class has
    -- at most 3 off-specs) — these are the ranks the player can actually use.
    if #sameClass > 0 then
        local sep = T("TTBIS_OTHER_SEP", " · ")
        local parts = {}
        for _, h in ipairs(sameClass) do
            local r, _, rm = erank(h)
            parts[#parts + 1] = specDisplayName(h, true) .. " " .. rankModeName(rm) .. " #" .. (r or 0)
        end
        for i, part in ipairs(parts) do
            tooltip:AddLine(tipColor(TIP_COLOR.muted, i == 1 and T("TTBIS_ALSO_LABEL", "兼顾：") or "          ")
                .. specColor(sameClass[i], part), 1, 1, 1, true)
        end
    end

    -- B2. Other classes' specs (folded summary, grey).
    if #others > 0 then
        -- 其它职业只保留数量概览。详细名单对当前角色没有直接操作价值，
        -- 曾经最多铺 3 个名字，常常换成两行，反而把“我该做什么”挤出视线。
        local text = tipColor(TIP_COLOR.muted, "● " .. string.format(
            T("TTBIS_OTHER_SUMMARY", "其它职业：另有 %d 个专精需要"), #others))
        tooltip:AddLine(text, 1, 1, 1, true)
    end
    -- 已有赛季 BiS 主块时不再追加坯子兜底块，避免重复信息。
    return true, true
end

-- ── 坯子催化行（不依赖 BiS 候选池）─────────────────────────────────────────
-- ⛔ 玩家 2026-09-02：「为什么有的装备没有这个」——「复生祭品护颅」是他头盔坯子里的 #1
--    （弹窗就是这么显示的），悬浮却一个字都不提催化。
--    根因：Inject() 里那行催化提示挂在 `cur`（当前专精 BiS 命中）下面，
--    而这件只进了 圣骑防护/战士狂暴/圣骑神圣 的池子，鲜血 DK 一个都不沾 → cur=nil → 整块跳过。
--    但「它是不是你的坯子」跟「它在不在你的 BiS 池」是两回事：坯子来自 tierFiller/手册，
--    本来就不在候选池里。所以这条路径必须独立判定。
-- ⛔ 结果按「专精 + 使用率参照 + 团本排除」签名缓存：tooltip 是热路径，
--    鼠标扫一排装备不能每件都把 5 个部位的坯子表重算一遍。
-- 坯子缓存（地下城手册）补上后 _fillerMap 必须重建，否则冷缓存时建的半截表会一直用下去
local function catSig()
    local c, n = GearInsight._catalystCache, 0
    for _, slotId in ipairs({ 1, 3, 5, 7, 10 }) do if c and c[slotId] then n = n + 1 end end
    return tostring(n)
end
function TooltipHook:FillerHit(itemId, class, spec, hero)
    if not (itemId and class and spec) then return nil end
    local bd = GearInsight.BisData
    if not (bd and bd.GetSpecData and GearInsight.BuildFillerList) then return nil end

    local mode = (bd.GetUsageMode and bd:GetUsageMode()) or "raid"
    local exr  = (bd.GetExcludeRaid and bd:GetExcludeRaid()) and 1 or 0
    local sig  = table.concat({ class, spec, hero or "", mode, exr,
                                tostring(GearInsight._statMode or ""),
                                (GearInsight.BisPlan and GearInsight.BisPlan.Sig()) or "",
                                catSig() }, "|")
    if self._fillerSig ~= sig then
        self._fillerSig, self._fillerMap = sig, nil
    end

    if not self._fillerMap then
        local specData = bd:GetSpecData(class, spec, hero)
        local armor = bd.classArmor and bd.classArmor[class]
        if not (specData and armor and bd.tierFiller and bd.tierFiller[armor]) then
            self._fillerMap = {}
            return nil
        end
        local map = {}
        for slotId in pairs(bd.tierFiller[armor]) do
            -- 套装目标装等只走 BisTargetPreview：它与主面板/装备图共用同一规则，
            -- 团本兑换物永远封顶334，不能读到 WCL 的344化生实例。
            local tName, tRank, tIlvl, tPreview, tStats
            local pool = specData.bisBySlot and specData.bisBySlot[slotId]
            for r, e in ipairs(pool or {}) do
                if e.isTier then
                    tName, tRank, tStats = e.itemName, r, e.stats
                    tPreview = GearInsight.BisTargetPreview and GearInsight.BisTargetPreview(e, specData, slotId)
                    tIlvl = (tPreview and tPreview.ilvl) or math.min(tonumber(e.ilvl) or 334, 334)
                    break
                end
            end
            -- ⛔ noScan=true：悬浮不许触发地下城手册扫描（会改全局筛选状态）
            local list, _, _, complete = GearInsight.BuildFillerList(armor, slotId, nil, specData, tStats, true)
            for i, e in ipairs(list or {}) do
                if e.itemId and not map[e.itemId] then
                    map[e.itemId] = { slotId = slotId, idx = e.attributeRank or i, total = #list,
                                      tierName = tName, tierRank = tRank, tierIlvl = tIlvl, tierPreview = tPreview,
                                      isTier = e.isTier or nil, entry = e, complete = complete, top = list[1] }
                end
            end
        end
        self._fillerMap = map
    end
    return self._fillerMap[itemId]
end

-- 只返回当前物品、专精、英雄天赋的原实穿率，不从候选排名对象取统计字段。
function TooltipHook:ItemUsage(itemId, cache)
    local bd = GearInsight.BisData
    -- StatReader 的英雄天赋可能是中文，数据索引则按规范化后的 specKey 存储。
    -- 复用 GetSpecData 的解析结果，不能直接比较这两个显示名称。
    local sp = bd and bd.GetSpecData and bd:GetSpecData(cache.class, cache.spec, cache.hero)
    local key = sp and sp._key
    for _, hit in ipairs((self._itemIndex and self._itemIndex[itemId]) or {}) do
        if (key and hit.specKey == key) or (not key and hit.className == (sp and sp.className or cache.class)
            and hit.specName == (sp and sp.specName or cache.spec)
            and (not cache.hero or hit.heroTalent == (sp and sp.heroTalent or cache.hero))) then
            return hit.usageRaid, hit.usageMplus
        end
    end
    -- 显示筛选后的索引可能不含当前件；使用率仍从原始统计池取。
    if not sp then return end
    local raid, mplus
    local function find(pools, isRaid)
        for _, pool in pairs(pools or {}) do
            for _, e in ipairs(pool) do
                if e.itemId == itemId then
                    if isRaid then raid = e._usageRaid or e.usagePct
                    else mplus = e.usagePct end
                    return
                end
            end
        end
    end
    local current = sp.bisBySlot
    find(sp._rawBisBySlot or current, true)
    find(key and bd.mplusBySlot and bd.mplusBySlot[key], false)
    if key and bd.mplusUsage and bd.mplusUsage[key] then
        mplus = bd.mplusUsage[key][itemId] or mplus
    end
    return raid, mplus
end

-- Tooltip 只读取坯子缓存，不能在渲染栈里同步扫描地下城手册；但冷缓存时也不能
-- 永远停在“候选数据加载中”。按当前部位排一个短任务，连续补扫几次（EJ 的副本/
-- 部位过滤在冷启动时可能晚一帧生效），成功后让仍在显示同一物品的 tooltip 重绘。
function TooltipHook:RequestFillerData(tooltip, itemId, slotId)
    if not (slotId and C_Timer and C_Timer.After and GearInsight.GetCatalystSources) then return end
    if GearInsight._catalystCache and GearInsight._catalystCache[slotId] then return end
    self._fillerLoads = self._fillerLoads or {}
    if self._fillerLoads[slotId] then return end
    self._fillerLoads[slotId] = true

    local scanAttempts, combatWaits = 0, 0
    local function stillShowing()
        if not (tooltip and tooltip.IsShown and tooltip:IsShown()) then return false end
        local link
        if TooltipUtil and TooltipUtil.GetDisplayedItem then
            local _, value = TooltipUtil.GetDisplayedItem(tooltip); link = value
        elseif tooltip.GetItem then
            local _, value = tooltip:GetItem(); link = value
        end
        return link and tonumber(link:match("item:(%d+):")) == itemId
    end
    local function refresh()
        self._fillerSig, self._fillerMap = nil, nil
        if not stillShowing() then return end
        local link
        if TooltipUtil and TooltipUtil.GetDisplayedItem then
            local _, value = TooltipUtil.GetDisplayedItem(tooltip); link = value
        elseif tooltip.GetItem then
            local _, value = tooltip:GetItem(); link = value
        end
        -- RefreshData 在部分 12.x item tooltip 上存在但不会重新触发物品
        -- data pipeline。重新设置同一条链接才能保证 post-call 再跑一次。
        if link and tooltip.SetHyperlink then
            pcall(tooltip.SetHyperlink, tooltip, link)
            if tooltip.Show then tooltip:Show() end
        elseif tooltip.RefreshData then
            pcall(tooltip.RefreshData, tooltip)
        end
    end
    local function scan()
        if InCombatLockdown and InCombatLockdown() then
            combatWaits = combatWaits + 1
            if combatWaits < 30 then C_Timer.After(2, scan) else self._fillerLoads[slotId] = nil end
            return
        end
        scanAttempts = scanAttempts + 1
        pcall(GearInsight.GetCatalystSources, GearInsight, slotId)
        if GearInsight._catalystCache and GearInsight._catalystCache[slotId] then
            self._fillerLoads[slotId] = nil
            refresh()
        elseif scanAttempts < 3 then
            C_Timer.After(scanAttempts == 1 and 0.8 or 2, scan)
        else
            -- 本轮没有拿到可信的完整表；放开锁，下一次悬浮仍可重试。
            self._fillerLoads[slotId] = nil
        end
    end
    C_Timer.After(0.05, scan)
end

-- ── 坯子轨道封顶预警 ───────────────────────────────────────────────────
-- 虔诚 2026-09-12：手里一件 292「升级：勇士 1/6」的坯子，悬浮说「催化转换成 X 后 = BiS #1 · 转换优先级 #1/3」，
-- 可勇士轨道升到顶也就 ~307，转出来的套装永远到不了目标 321 —— 得把这层说出来。
-- 轨道信息直接读悬浮自己的行（升级：X N/M + 物品等级 N），不猜轨道表；
-- 封顶估算 = 当前装等 + 剩余步数×3，再放 2 点余量（步进有 3/4 交替），只在**明显到不了**时才警告。
local _TW_UPG, _TW_ILVL
local function tipTrackAndIlvl(tooltip)
    local nm = tooltip and tooltip.GetName and tooltip:GetName()
    if not nm then return nil end
    if _TW_UPG == nil then
        local fmt = ITEM_UPGRADE_TOOLTIP_FORMAT
        if type(fmt) == "string" and fmt:find("%%d") then
            local esc = fmt:gsub("%p", "%%%0")
            esc = esc:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
            _TW_UPG = "^%s*" .. esc .. "%s*$"
        else
            _TW_UPG = false
        end
        local f2 = ITEM_LEVEL or "Item Level %d"
        local e2 = f2:gsub("%p", "%%%0"):gsub("%%%%d", "(%%d+)")
        _TW_ILVL = "^%s*" .. e2
    end
    local cur, mx, tname, ilvl
    for i = 2, 8 do
        local f = _G[nm .. "TextLeft" .. i]
        local txt = f and f.GetText and f:GetText()
        if type(txt) == "string" and txt ~= "" and not (issecretvalue and issecretvalue(txt)) then
            if not ilvl then
                local v = txt:match(_TW_ILVL)
                if v then ilvl = tonumber(v) end
            end
            if not cur then
                if _TW_UPG then
                    local n2, a, b = txt:match(_TW_UPG)
                    if a then cur, mx, tname = tonumber(a), tonumber(b), n2 end
                end
                if not cur then
                    -- 兜底：形如「升级：勇士 1/6」；⛔冒号用 plain find（全角冒号 3 字节）
                    local c1 = txt:find("：", 1, true)
                    local c2 = txt:find(":", 1, true)
                    local cpos, clen = nil, 1
                    if c1 and (not c2 or c1 < c2) then cpos, clen = c1, 3 elseif c2 then cpos, clen = c2, 1 end
                    local dur = DURABILITY_TEMPLATE and DURABILITY_TEMPLATE:gsub("%%d", ""):gsub("%s", "") or nil
                    if cpos and not (dur and txt:gsub("%s", ""):find(dur, 1, true)) then
                        local n2, a, b = txt:sub(cpos + clen):match("^%s*(.-)%s*(%d+)%s*/%s*(%d+)%s*$")
                        if a then cur, mx, tname = tonumber(a), tonumber(b), n2 end
                    end
                end
            end
        end
        if cur and ilvl then break end
    end
    return cur, mx, tname, ilvl
end

-- 「去刷谁」：本部位坯子横评 #1 的名字 + 掉落点（用户 2026-09-17「套装如果装等不够要直接跟他说排序第一的 BiS 哪里刷」）
-- Source ceiling, not the highest observed tier sample from a different base.
function TooltipHook:FillerMaxIlvl(entry)
    if not entry then return nil end
    local observed = GearInsight.BisCanonicalEntry and GearInsight.BisCanonicalEntry(entry) or entry
    local level = tonumber(observed and observed.ilvl)
    if level and level > 0 then return level end
    local link = observed and GearInsight.FillerPreviewLink and GearInsight.FillerPreviewLink(observed)
    if link and C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, value = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and value and value > 0 then return value end
    end
    return nil
end

function TooltipHook:IsMaxFillerCandidate(link, entry)
    if not link or not C_Item or not C_Item.GetItemInfo or not C_Item.GetDetailedItemLevelInfo then return false end
    local _, _, quality = C_Item.GetItemInfo(link)
    if quality ~= 4 then return false end
    local level = C_Item.GetDetailedItemLevelInfo(link)
    local ceiling = self:FillerMaxIlvl(entry)
    return ceiling ~= nil and level == ceiling
end

function TooltipHook:TopFillerParts(hit)
    local top = hit and hit.top
    if not (top and top.itemId) then return nil end
    local h = GearInsight._h
    local name = (h and h.locName and h.locName(top.itemId, top.itemName))
        or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(top.itemId)) or ("#" .. top.itemId)
    local inst = (EJ_GetInstanceInfo and top.instanceId and EJ_GetInstanceInfo(top.instanceId)) or nil
    local boss = (EJ_GetEncounterInfo and top.encounterId and EJ_GetEncounterInfo(top.encounterId))
        or (top.bossName and top.bossName ~= "" and top.bossName) or nil
    if top.isTier or top.type == "raid" or top.sourceCategory == "raid" then
        boss = self:SourceBoss(top, boss)
    end
    local where
    local cat = top.sourceCategory or top.type
    if cat == "crafted" or top.source == "制造业" or top.source == "制造" then
        where = T("TTSRC_CRAFTED_ORDER", "制造业 · 工艺订单")
    elseif cat == "world" then
        where = T("SRC_WORLD", "世界掉落")
    elseif top.isTier and GearInsight.IsVenomcursed and GearInsight.IsVenomcursed(top) then
        where = T("TTBIS_VENOM_CATALYST", "催化转换 · M8 乌拉特克毒咒坯子")
    elseif top.isTier then
        local parts = { T("TTUP_DIFF_MYTHIC", "史诗") .. T("TTSRC_RAID", "团本") }
        if inst then parts[#parts + 1] = inst end
        -- “团本直掉”只是旧数据占位词，不能当作 Boss 名再次输出。
        local realBoss = boss
        if realBoss == T("TIER_RAID_DIRECT", "团本直掉") then realBoss = nil end
        if realBoss then parts[#parts + 1] = realBoss end
        where = table.concat(parts, " · ")
    elseif cat == "raid" or cat == "mplus" then
        local tag = cat == "raid" and T("TTSRC_RAID", "团本") or T("TTSRC_MPLUS", "大秘境")
        local parts = { tag }
        if inst then parts[#parts + 1] = inst
        elseif top.nameCn and top.nameCn ~= "" then parts[#parts + 1] = top.nameCn end
        if boss and boss ~= inst and (top.type == "raid" or top.sourceCategory == "raid") then parts[#parts + 1] = boss end
        where = table.concat(parts, " · ")
    else
        where = T("TTSRC_UNKNOWN", "来源待确认")
    end
    return name, where
end

function TooltipHook:TopFillerLine(hit)
    local name, where = self:TopFillerParts(hit)
    if not name then return nil end
    return string.format(T("TTBIS_TOP_FARM", "去刷横评 #1：%s —— %s"), name, where)
end

-- 公开口：Inject 定义在 tipTrackAndIlvl 之前，local 看不到
function TooltipHook:TipTrack(tooltip) return tipTrackAndIlvl(tooltip) end

-- ── 隐藏轨道档补一行 ───────────────────────────────────────────────────
-- 用户 2026-09-30 截图「无羁深仇腿甲 344：神话 6/6 的轨道信息呢？不能丢」。
-- 查暴雪数据（ItemBonusListGroupEntry，神话轨道组 618）：12849~12854 = 神话 1/6~6/6（6/6 = 334），
-- 12855 / 12856 / 13848 = 第 7 / 8 / 9 档（13848 = 344，末两王 / 稀有件），这三档带「不显示」标记，
-- 所以游戏自己的悬浮就没有「升级：」那一行 —— 不是插件弄丢的。这里替玩家补一行，免得以为轨道没了。
local MYTH_HIDDEN_STEP = { [12855] = 7, [12856] = 8, [13848] = 9 }
function TooltipHook:InjectHiddenTrack(tooltip)
    if not (tooltip and tooltip.GetItem) then return end
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok or type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then return end
    local body = link:match("item:([%-%d:]+)")
    if not body then return end
    -- item:ID:附魔:宝石1-4:后缀:唯一:等级:专精:modMask:context:numBonus:bonus…
    local f = {}
    for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    local nb = tonumber(f[13] or "")
    if not nb or nb <= 0 then return end
    local step
    for i = 14, 13 + nb do
        local st = MYTH_HIDDEN_STEP[tonumber(f[i] or "") or 0]
        if st then step = st; break end
    end
    if not step then return end
    local cur, _, _, ilvl = tipTrackAndIlvl(tooltip)
    if cur then return end                        -- 游戏已经显示了升级行，不重复
    tooltip:AddLine(string.format(T("TT_HIDDEN_MYTH", "升级：神话（第 %d 档%s，高于神话 6/6 的 334，已是最高档）"),
        step, ilvl and (" · " .. ilvl) or ""), 1, 0.82, 0, true)
end

function TooltipHook:TrackWarn(tooltip, hit)
    if not (hit and hit.tierIlvl and hit.tierIlvl > 0) then return false end
    local cur, mx, tname, ilvl = tipTrackAndIlvl(tooltip)
    if not (cur and mx and ilvl and mx > 0) then return false end
    local ceilIlvl = GearInsight.UpgradeTrackCeiling and GearInsight.UpgradeTrackCeiling(ilvl, cur, mx) or ilvl
    if ceilIlvl + 2 >= hit.tierIlvl then return false end
    tooltip:AddLine(string.format(T("TTBIS_TRACK_LOW", "|A:services-icon-warning:12:12|a %s轨道升到顶约 %d，转出的套装到不了 %d —— 要更高轨道的坯子"),
        (tname and tname ~= "") and (tname .. " ") or "", ceilIlvl, hit.tierIlvl), 1, 0.55, 0.2, true)
    local farm = self:TopFillerLine(hit)
    if farm then tooltip:AddLine(farm, 1, 0.75, 0.2, true) end
    return true
end

-- 按一件实物（链接）的副属性，在该部位坯子横评里找同属性那条：返回 { idx, total, text, entry }；
-- 套装本体（或与本体同属性）时 entry.isTier = true。读不到 / 缓存不全 → nil
function TooltipHook:FillerRankByStats(link, itemId, cache)
    if not (link and cache and GearInsight.LinkStats and GearInsight.FillerStats and GearInsight.BuildFillerList) then return nil end
    local text, key, actual = GearInsight.LinkStats(link)
    if not key or not actual then return nil end
    local okLevel, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
    if not okLevel or not level then return nil end
    local bd = GearInsight.BisData
    local sp = bd and bd.GetSpecData and bd:GetSpecData(cache.class, cache.spec, cache.hero)
    local armor = bd and bd.classArmor and cache.class and bd.classArmor[cache.class]
    local hit = self:FillerHit(itemId, cache.class, cache.spec, cache.hero)
    if not (sp and armor and hit and hit.slotId) then return nil end
    local list, _, _, complete = GearInsight.BuildFillerList(armor, hit.slotId, nil, sp, nil, true)
    if not complete then return nil end
    local matches, pending = {}, false
    for i, e in ipairs(list or {}) do
        local _, k, values = GearInsight.FillerStats(e.itemId, e.bonusIDs)
        values = e.observedStats or values
        if not values then pending = true end
        local same = values and e.ilvl == level
        for _, stat in ipairs({"crit","haste","mastery","versatility"}) do
            if not values or (values[stat] or 0) ~= (actual[stat] or 0) then same=false end
        end
        if same then matches[#matches + 1] = { idx = e.attributeRank or i, entry = e } end
    end
    if #matches ~= 1 or pending then return nil end
    return { idx = matches[1].idx, total = #list, text = text,
             entry = matches[1].entry, matches = matches, pending = pending }
end

-- 悬浮的这件套装件是不是催化来的：按实物副属性在坯子横评里找同属性的那件。本体 / 读不到 → nil
function TooltipHook:CatalyzedFrom(tooltip, itemId, cache)
    local link
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local ok, _, l = pcall(TooltipUtil.GetDisplayedItem, tooltip); if ok then link = l end
    elseif tooltip.GetItem then
        local ok, _, l = pcall(tooltip.GetItem, tooltip); if ok then link = l end
    end
    local r = self:FillerRankByStats(link, itemId, cache)
    if not r or r.entry.isTier then return nil end      -- 跟本体同属性 = 本体（或等同本体），走原来那行
    return r
end

function TooltipHook:InjectFillerOnly(tooltip, itemId, afterBis)
    if not itemId then return false end
    local c = cfg()
    if not c.enabled or c.mode == "off" then return false end
    -- ⛔ 不能只吃 _specCache：它是在 Inject() 走到专精探测那一步才填的，
    --   而**完全不在任何专精 BiS 池里的坯子**会在更早的 `if not hits then return end`
    --   就返回 —— 那种物品第一次悬停时缓存还是空的，等于这条路径永远不生效。
    local cache = self._specCache
    if not cache and self.addon and self.addon.StatReader then
        local ok, st = pcall(function() return self.addon.StatReader:ReadAll() end)
        if ok and st then
            cache = { class = st.class, spec = st.spec, hero = st.heroTalent }
        else
            cache = {}
        end
        self._specCache = cache          -- 与 Inject() 共用同一份缓存（切专精时由主文件置空）
    end
    if not cache then return false end
    local hit = self:FillerHit(itemId, cache.class, cache.spec, cache.hero)
    -- 不在本赛季候选池的旧装备不做同部位推测。此前这里按角色栏位强行套用
    -- 当前赛季坯子，会让旧赛季的「诅咒马甲」之类也显示“BiS 坯子 #1”。
    if not hit then return false end
    local tierSlots = { [1]=true, [3]=true, [5]=true, [7]=true, [10]=true }
    if not tierSlots[tonumber(hit.slotId)] then return false end

    if not afterBis then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFF00FF00" .. T("TTBIS_HEADER", "GearInsight") .. "|r", 1, 1, 1)
    end
    tooltip._giTierCompact = true
    tooltip._giHasBisSource = true
    local rankText = hit.complete and string.format(T("TTFILLER_ATTR_RANK", "属性推荐 #%d/%d"), hit.idx, hit.total)
        or T("TTFILLER_PENDING", "候选数据待补全")
    tooltip:AddLine(tipColor(TIP_COLOR.rank, slotLabel(hit.slotId) .. " · " .. rankText), 1, 1, 1, true)
    -- Item tooltips describe only the hovered candidate, never the recommended winner.
    if hit.entry then
        local _, where = self:TopFillerParts({ top = hit.entry })
        if where then
            local sourceColor = ((hit.entry.sourceCategory or hit.entry.type) == "mplus")
                and TIP_COLOR.mplus or TIP_COLOR.raid
            tooltip:AddLine(tipLabel(hit.isTier and T("TTFILLER_TOKEN_SRC", "兑换物来源") or T("TTFILLER_OBTAIN", "获取"))
                .. tipColor(sourceColor, where), 1, 1, 1, true)
        end
    end
    if not hit.complete then self:RequestFillerData(tooltip, itemId, hit.slotId) end
    return true
end

-- ── 掉落来源行 ──────────────────────────────────────────────────────────────
-- ⭐ 为什么单独一块、且不挂在 BiS 排名下面判定：
--    BiS 排名只对**候选池里的物品**有意义，而候选池是按专精切的。
--    玩家 2026-09-02 反馈的「复生祭品护颅悬停一行字都没有」，根因就是它
--    只进了 圣骑防护 / 战士狂暴 / 圣骑神圣 三个池子，鲜血 DK 一个都不沾：
--      cur=nil、sameClass={}、others 有 3 条但被 `if not c.showOthers then others={} end`
--      清空（showOthers 默认 false）→ Inject 在 `if not cur and #sameClass==0 and #others==0`
--      处直接 return。⛔ hook 是好的、数据也在库里，纯粹是**门槛**问题。
--    来源行对所有装备都成立，所以它必须走自己的通道，不受候选池门槛影响。

-- itemId -> 最"全"的那条来源信息。
-- ⛔ 同一 itemId 在库里会出现多次（不同专精池 / tierFiller），有的条目 source 是 nil
--   而只有 instanceId/encounterId ——所以不能取第一条，要挑字段最全的那条。
function TooltipHook:BuildSourceIndex(bisData)
    if self._srcIndex and self._srcIndexSrc == bisData then return self._srcIndex end
    local idx = {}
    if type(bisData) ~= "table" then return idx end

    local function score(e)
        local n = 0
        if e.source then n = n + 4 end
        if e.sourceCategory then n = n + 2 end
        if e.bossName and e.bossName ~= "" then n = n + 2 end
        if e.instanceId then n = n + 1 end
        if e.encounterId then n = n + 1 end
        return n
    end
    local function visit(e)
        local id = e.itemId
        local old = idx[id]
        if not old or score(e) > old._score then
            idx[id] = {
                _score = score(e),
                source = e.source, sourceCategory = e.sourceCategory,
                bossName = e.bossName, instanceId = e.instanceId,
                encounterId = e.encounterId, isTier = e.isTier,
            }
        end
    end
    local seen = {}
    local function walk(tb, depth)
        if depth > 6 or type(tb) ~= "table" or seen[tb] then return end
        seen[tb] = true
        for _, v in pairs(tb) do
            if type(v) == "table" then
                if v.itemId then visit(v) else walk(v, depth + 1) end
            end
        end
    end
    walk(bisData, 0)

    self._srcIndex, self._srcIndexSrc = idx, bisData
    return idx
end

-- BOSS 进本序号。
-- ⛔⛔ BisData 里**没有**这个字段，且绝不能拿 encounterId 排序冒充 ——
--    暴雪 journal 的 encounter id 顺序跟进本顺序对不上（1 号之后排的是 3 号）。
--    插件里那张 NEED_BOSS_ORDER 是**上赛季**团本的硬编码表（1307/1314/1308/1305），
--    覆盖不到本赛季的 1320，用不了。
-- ✅ 唯一可信来源是地下城手册按 index 取：EJ_GetEncounterInfoByIndex(i, instanceId)
--    返回的就是手册展示顺序 = 进本顺序，而且传了 instanceId 就是纯读取，
--    ⛔不会像 EJ_SetLootFilter 那样改全局筛选状态。
--    拿不到就**只显示 BOSS 名、不显示序号**，绝不猜。
local _bossOrder = {}          -- instanceId -> { [encounterId] = index } | false(取不到)
local function bossOrderFor(instanceId, encounterId)
    local orders = GearInsight.BisData and GearInsight.BisData.raidBossOrder
    local baked = orders and orders[encounterId]
    if baked then return baked end
    if not (instanceId and encounterId) then return nil end
    local map = _bossOrder[instanceId]
    if not map then
        if not EJ_GetEncounterInfoByIndex then return nil end
        local built = {}
        local ok = pcall(function()
            for i = 1, 30 do
                local _, _, encId = EJ_GetEncounterInfoByIndex(i, instanceId)
                if not encId then break end
                built[encId] = i
            end
        end)
        if not ok or not next(built) then return nil end
        _bossOrder[instanceId] = built
        map = built
    end
    return map[encounterId]
end

-- Only normalize GearInsight-added lines; leave the game's item text alone.
function TooltipHook:StyleLines(tooltip, first)
    local name = tooltip.GetName and tooltip:GetName()
    if not name or not GameTooltipText or not GameTooltipText.GetFont then return end
    local font, size, flags = GameTooltipText:GetFont()
    if not font then return end
    for i = first, tooltip:NumLines() do
        for _, side in ipairs({"Left", "Right"}) do
            local line = _G[name .. "Text" .. side .. i]
            if line then line:SetFont(font, size, flags) end
        end
    end
end

function TooltipHook:SourceBoss(entry, boss)
    if not boss then return nil end
    local ord = bossOrderFor(entry.instanceId, entry.encounterId) or entry.bossOrder
    return ord and ("M" .. ord .. " " .. boss) or boss
end

function TooltipHook:InjectSource(tooltip, itemId, afterBis)
    -- BiS 区域已经展示来源，不再追加独立的重复掉落行。
    if afterBis and (tooltip._giTierCompact or tooltip._giHasBisSource) then return end
    if not itemId then return end
    local c = cfg()
    if not c.enabled or c.mode == "off" or c.showSource == false then return end

    local cache = self._specCache
    if afterBis and cache and self:FillerHit(itemId, cache.class, cache.spec, cache.hero) then return end
    local idx = self._srcIndex or self:BuildSourceIndex(GearInsight.BisData)
    local e = idx and idx[itemId]

    -- BisData 只烘了 486 个「进过 BiS 池 / tierFiller」的物品，玩家手上大多数装备不在其中
    -- （2026-09-02 玩家：「有的怎么没有」—— 众军指挥官头盔全库零命中）。
    -- 退到地下城手册的全量来源图；它还没建好时本次返回 nil，下次悬停才有。
    if not e then
        local j = GearInsight.JournalSource and GearInsight.JournalSource(itemId)
        if not j then return end
        e = {
            sourceCategory = j.isRaid and "raid" or "mplus",
            instanceId = j.instanceId, encounterId = j.encounterId,
            bossName = "", source = j.instName, _fromJournal = true,
        }
    end

    local cat = e.sourceCategory
    local label, body

    if cat == "raid" then
        -- 名字优先走客户端本地化（地下城手册），拿不到再退回库里烘的中文。
        local loc = GearInsight.LocalizedSource
            and GearInsight.LocalizedSource(e.source or "", e.instanceId, e.encounterId)
        local inst = (EJ_GetInstanceInfo and e.instanceId and EJ_GetInstanceInfo(e.instanceId)) or nil
        local boss = (EJ_GetEncounterInfo and e.encounterId and EJ_GetEncounterInfo(e.encounterId))
            or (e.bossName ~= "" and e.bossName) or nil
        if not inst and loc and loc ~= "" then inst = loc end
        if not inst and e._fromJournal and e.source and e.source ~= "" then inst = e.source end
        if not inst then return end
        local ord = bossOrderFor(e.instanceId, e.encounterId) or e.bossOrder
        label = T("TTSRC_DROP", "掉落：")
        -- ⭐ 玩家 2026-09-02：要一眼看出是团本还是大秘境，别只给副本名
        local tag = T("TTSRC_RAID", "团本")
        if boss and ord then
            body = ("%s · %s · %s %s"):format(tag, inst,
                ("M" .. ord), boss)
        elseif boss then
            body = ("%s · %s · %s"):format(tag, inst, boss)
        else
            body = ("%s · %s"):format(tag, inst)
        end

    elseif cat == "mplus" then
        local inst = (EJ_GetInstanceInfo and e.instanceId and EJ_GetInstanceInfo(e.instanceId))
            or (e.source and e.source ~= "" and e.source) or nil
        if not inst then return end
        label = T("TTSRC_DROP", "掉落：")
        body = ("%s · %s"):format(T("TTSRC_MPLUS", "大秘境"), inst)

    elseif cat == "tier" or e.isTier then
        label = T("TTSRC_SOURCE", "来源：")
        body = T("TTSRC_TIER", "套装转换（催化剂）")

    elseif cat == "world" then
        label = T("TTSRC_SOURCE", "来源：")
        body = T("TTSRC_WORLD", "世界掉落")

    elseif cat == "crafted" then
        -- 12.x 史诗制造装是「工艺订单」产物（绑定），拍卖行搜不到（Hayden 2026-09-13「说拍卖行买 拍卖行咋搜不到」）
        label = T("TTSRC_SOURCE", "来源：")
        body = T("TTSRC_CRAFTED2", "制造业 · 拍卖行搜不到，找对应专业玩家下工艺订单（自备火花+材料）")

    else
        -- ⛔ cat == "other" 的 source 是 "M+ 61762" 这种**原始 id**，不是人话；
        --    cat == nil 的条目连 source 都没有。宁可这一行不显示，也不印一串 id。
        return
    end

    if not afterBis then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFF00FF00" .. T("TTBIS_HEADER", "GearInsight") .. "|r", 1, 1, 1)
    end
    tooltip:AddLine("|cFF888888" .. label .. "|r" .. body, 0.75, 0.75, 0.75, true)
end

-- Read embellishments from the displayed item instance, not another player's sample.
function TooltipHook:InjectEmbellishment(tooltip)
    local extras = _G.GearInsightPlanExtras
    if not (extras and extras.embellish) then return end
    local link
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, value = TooltipUtil.GetDisplayedItem(tooltip); link = value
    elseif tooltip.GetItem then
        local _, value = tooltip:GetItem(); link = value
    end
    local payload = link and link:match("item:([^|]+)")
    if not payload then return end
    local fields = {}
    for field in (payload .. ":"):gmatch("(.-):") do fields[#fields + 1] = field end
    local count = tonumber(fields[13]) or 0
    if count < 1 or count > 100 or #fields < 13 + count then return end
    local seen = {}
    for i = 14, 13 + count do
        local id = tonumber(fields[i])
        local em = id and extras.embellish[id]
        if em and not seen[id] then
            seen[id] = true
            local icon = em.icon and ("|TInterface\\Icons\\" .. em.icon .. ":14|t ") or ""
            local name = (GetLocale and GetLocale() == "enUS" and em.en) or em.cn or em.en
            if name then tooltip:AddLine(T("TTBIS_EMBELLISH_LABEL", "美化：") .. icon .. name, 0.8, 0.6, 1, true) end
        end
    end
end

-- ── Registration ────────────────────────────────────────────────────────────
function TooltipHook:Create(addon)
    self.addon = addon

    -- Build the reverse index once.
    local bd = addon and addon.BisData or GearInsight.BisData
    self:BuildItemIndex(bd)
    self:BuildSourceIndex(bd)

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        -- 12.x unified pipeline: one registration covers every item tooltip.
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if not tooltip or not tooltip.AddLine then return end
            local itemId = getItemIdFromData(tooltip, data)
            self:InjectHiddenTrack(tooltip)
            local first = tooltip:NumLines() + 1
            local rendered, catShown = self:Inject(tooltip, itemId)
            if not catShown then
                local more = self:InjectFillerOnly(tooltip, itemId, rendered)
                rendered = rendered or more
            end
            self:InjectSource(tooltip, itemId, rendered)
            self:InjectEmbellishment(tooltip)
            self:StyleLines(tooltip, first)
        end)
        self._mode = "datapipeline"
    else
        -- Legacy fallback (pre-10.0.2 clients). Not expected on 120005.
        local function legacy(tooltip)
            if not tooltip or not tooltip.GetItem then return end
            local _, link = tooltip:GetItem()
            if not link then return end
            local id = link:match("item:(%d+):")
            local iid = id and tonumber(id) or nil
            self:InjectHiddenTrack(tooltip)
            local first = tooltip:NumLines() + 1
            local rendered, catShown = self:Inject(tooltip, iid)
            if not catShown then
                local more = self:InjectFillerOnly(tooltip, iid, rendered)
                rendered = rendered or more
            end
            self:InjectSource(tooltip, iid, rendered)
            self:InjectEmbellishment(tooltip)
            self:StyleLines(tooltip, first)
        end
        if GameTooltip then GameTooltip:HookScript("OnTooltipSetItem", legacy) end
        if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", legacy) end
        self._mode = "legacy"
    end
end

function TooltipHook:Destroy()
    -- Pipeline post-calls / frame hooks are cleaned up by the client.
end

GearInsight.TooltipHook = TooltipHook

-- 给主面板格子的自绘提示用：这件物品的来源行是不是已经由钩子追加了（是则格子别再重复加一条）
function GearInsight.TooltipHookActive(itemId)
    if not itemId then return false end
    local c = cfg()
    if not c.enabled or c.mode == "off" or c.showSource == false then return false end
    local idx = TooltipHook._srcIndex or (GearInsight.BisData and TooltipHook:BuildSourceIndex(GearInsight.BisData))
    if idx and idx[itemId] then return true end
    return (GearInsight.JournalSource and GearInsight.JournalSource(itemId)) and true or false
end
