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
            elseif (e.usagePct or 0) > (prev.usagePct or 0) then
                byId[e.itemId] = e
                for i, o in ipairs(order) do
                    if o.itemId == e.itemId then order[i] = e break end
                end
            end
        end
    end
    add(a); add(b)
    table.sort(order, function(x, y) return (x.usagePct or 0) > (y.usagePct or 0) end)
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
                            }
                            hits[e.itemId] = h
                        end
                        h.rankM = rank
                        h.totalM = #mp
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
    if c.enabled == nil then c.enabled = false end--lnui
    if c.mode == nil then c.mode = "all" end          -- "current" | "all" | "off"
    if c.maxOtherSpecs == nil then c.maxOtherSpecs = 3 end
    if c.showUsage == nil then c.showUsage = true end
    -- 显示范围（2026-06-06 用户需求）：默认只显示本职业（当前专精+其它专精），
    -- 其它职业行默认隐藏；本职业各专精可逐个勾掉（面板「悬浮提示」菜单）。
    if c.showOthers == nil then c.showOthers = false end
    -- 来源行对所有装备都成立，默认开
    if c.showSource == nil then c.showSource = false end--lnui
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
    if not itemId then return end
    local c = cfg()
    if not c.enabled or c.mode == "off" then return end

    -- 每次悬浮先对一下签名：设置没变就是一次表比较，变了才重建（见 BuildItemIndex）
    local bd = (self.addon and self.addon.BisData) or GearInsight.BisData
    if bd and bd.ApplyDataFilters then bd:ApplyDataFilters() end
    local idx = bd and self:BuildItemIndex(bd) or self._itemIndex
    if not idx then return end
    local hits = idx[itemId]
    if not hits then return end

    -- 当前使用率参照模式（团本/大秘境）：名次、排序、高亮全按它取（#98）。
    local bd0 = GearInsight.BisData
    local mode = (bd0 and bd0.GetUsageMode and bd0:GetUsageMode())
        or ((GearInsightDB and GearInsightDB.usageMode) or "raid")
    -- 有效名次：当前模式的池里有名次就用它；没有就退到另一套（信息总比空好）。
    local function erank(h)
        if mode == "mplus" then
            if h.rankM then return h.rankM, h.totalM end
            return h.rank, h.total
        end
        if h.rank then return h.rank, h.total end
        return h.rankM, h.totalM
    end

    -- Optional rank cap.
    local minRank = c.minRank
    local filtered = {}
    for _, h in ipairs(hits) do
        local r = erank(h)
        if r and (not minRank or r <= minRank) then filtered[#filtered + 1] = h end
    end
    if #filtered == 0 then return end

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
    local catShown = false
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

    if not cur and #sameClass == 0 and #others == 0 then return end

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
        local cr, ct = erank(cur)
        local left = string.format(T("TTBIS_CUR_FMT", "%s BiS #%d / 共%d"),
            slotLabel(cur.slotGroup), cr or 0, ct or 0)
        local right = specDisplayName(cur)
        if c.showUsage then
            -- Show BOTH usage references (团本 / 大秘境); the active mode is
            -- highlighted (white) and the other is greyed out.
            local HL, GRY = "|cFFFFFFFF", "|cFF888888"
            local raidSeg  = string.format(T("TTBIS_USAGE_RAID", "团本 %.1f%%"), cur.usageRaid or 0)
            local mplusSeg = string.format(T("TTBIS_USAGE_MPLUS", "大秘境 %.1f%%"), cur.usageMplus or 0)
            if mode == "mplus" then
                raidSeg  = GRY .. raidSeg .. "|r"
                mplusSeg = HL .. mplusSeg .. "|r"
            else
                raidSeg  = HL .. raidSeg .. "|r"
                mplusSeg = GRY .. mplusSeg .. "|r"
            end
            right = right .. "  " .. raidSeg .. GRY .. " · |r" .. mplusSeg
        end
        tooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
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
        if tr and tn and cr2 and tr < cr2 then
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
                if not complete then return end
                for idx, e in ipairs(list) do
                    if e.itemId == itemId then
                        rankTxt = string.format(T("TTBIS_FILLER_RANK", "  · 转换优先级 #%d/%d"), idx, #list)
                        break
                    end
                end
            end)
            tooltip:AddLine(T("TTBIS_CATALYST_PRE", "催化转换成 ") .. tn
                .. string.format(T("TTBIS_CATALYST_POST", " 后 = BiS #%d"), tr) .. rankTxt,
                0.55, 0.78, 1, true)
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
            parts[#parts + 1] = string.format(T("TTBIS_OTHER_ENTRY_FMT", "%s %s#%d"),
                specDisplayName(h, true), slotLabel(h.slotGroup), erank(h) or 0)
        end
        local text = T("TTBIS_SAMECLASS_LABEL", "本职业其它专精：") .. table.concat(parts, sep)
        tooltip:AddLine(text, 0.95, 0.85, 0.4, true)
    end

    -- B2. Other classes' specs (folded summary, grey).
    if #others > 0 then
        local sep = T("TTBIS_OTHER_SEP", " · ")
        local maxN = c.maxOtherSpecs or 3
        local parts = {}
        local shown = 0
        for _, h in ipairs(others) do
            if shown >= maxN then break end
            parts[#parts + 1] = string.format(T("TTBIS_OTHER_ENTRY_FMT", "%s %s#%d"),
                specDisplayName(h), slotLabel(h.slotGroup), erank(h) or 0)
            shown = shown + 1
        end
        local more = #others - shown
        local text = T("TTBIS_OTHER_LABEL", "其它职业：") .. table.concat(parts, sep)
        if more > 0 then
            text = text .. sep .. string.format(T("TTBIS_OTHER_MORE_FMT", "等 %d 个专精"), more)
        end
        tooltip:AddLine(text, 0.6, 0.6, 0.6, true)
    end
    -- 返回：①渲染过（来源行接在下面，不再另起空行）②催化行出过没有
    return true, catShown
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
function TooltipHook:FillerHit(itemId, class, spec, hero)
    if not (itemId and class and spec) then return nil end
    local bd = GearInsight.BisData
    if not (bd and bd.GetSpecData and GearInsight.BuildFillerList) then return nil end

    local mode = (bd.GetUsageMode and bd:GetUsageMode()) or "raid"
    local exr  = (bd.GetExcludeRaid and bd:GetExcludeRaid()) and 1 or 0
    local sig  = table.concat({ class, spec, hero or "", mode, exr,
                                tostring(GearInsight._statMode or "") }, "|")
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
            -- 该部位的套装件（名字 + 名次），用于「催化转换成 X 后 = BiS #N」
            local tName, tRank, tIlvl
            local pool = specData.bisBySlot and specData.bisBySlot[slotId]
            for r, e in ipairs(pool or {}) do
                if e.isTier then
                    tName, tRank = e.itemName, r
                    -- 目标装等：与面板同口径（链接装等，读不到退回数据里的 ilvl）
                    if e.bonusIDs and #e.bonusIDs > 0 and C_Item and C_Item.GetDetailedItemLevelInfo and GearInsight.LinkMid then
                        local okI, v = pcall(C_Item.GetDetailedItemLevelInfo, "item:" .. e.itemId .. GearInsight.LinkMid()
                            .. #e.bonusIDs .. ":" .. table.concat(e.bonusIDs, ":"))
                        if okI and v and v > 0 then tIlvl = v end
                    end
                    tIlvl = tIlvl or e.ilvl
                    break
                end
            end
            -- ⛔ noScan=true：悬浮不许触发地下城手册扫描（会改全局筛选状态）
            local list = GearInsight.BuildFillerList(armor, slotId, nil, specData, nil, true)
            for i, e in ipairs(list or {}) do
                if e.itemId and not map[e.itemId] then
                    map[e.itemId] = { slotId = slotId, idx = i, total = #list,
                                      tierName = tName, tierRank = tRank, tierIlvl = tIlvl }
                end
            end
        end
        self._fillerMap = map
    end
    return self._fillerMap[itemId]
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

function TooltipHook:TrackWarn(tooltip, hit)
    if not (hit and hit.tierIlvl and hit.tierIlvl > 0) then return false end
    local cur, mx, tname, ilvl = tipTrackAndIlvl(tooltip)
    if not (cur and mx and ilvl and mx > 0) then return false end
    local ceilIlvl = ilvl + (mx - cur) * 3
    if ceilIlvl + 2 >= hit.tierIlvl then return false end
    tooltip:AddLine(string.format(T("TTBIS_TRACK_LOW", "⚠ %s轨道升到顶约 %d，转出的套装到不了 %d —— 要更高轨道的坯子"),
        (tname and tname ~= "") and (tname .. " ") or "", ceilIlvl, hit.tierIlvl), 1, 0.55, 0.2, true)
    return true
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
    if not hit then return false end

    if not afterBis then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFF00FF00" .. T("TTBIS_HEADER", "GearInsight") .. "|r", 1, 1, 1)
    end
    local txt
    if hit.tierName and hit.tierRank then
        txt = T("TTBIS_CATALYST_PRE", "催化转换成 ") .. hit.tierName
            .. string.format(T("TTBIS_CATALYST_POST", " 后 = BiS #%d"), hit.tierRank)
    else
        txt = T("TTFILLER_IS", "本部位套装坯子")
    end
    txt = txt .. string.format(T("TTBIS_FILLER_RANK", "  · 转换优先级 #%d/%d"), hit.idx, hit.total)
    tooltip:AddLine(txt, 0.55, 0.78, 1, true)
    pcall(self.TrackWarn, self, tooltip, hit)
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
    if not (instanceId and encounterId) then return nil end
    local map = _bossOrder[instanceId]
    if map == false then return nil end
    if not map then
        if not EJ_GetEncounterInfoByIndex then _bossOrder[instanceId] = false; return nil end
        local built = {}
        local ok = pcall(function()
            for i = 1, 30 do
                local _, _, encId = EJ_GetEncounterInfoByIndex(i, instanceId)
                if not encId then break end
                built[encId] = i
            end
        end)
        if not ok or not next(built) then _bossOrder[instanceId] = false; return nil end
        _bossOrder[instanceId] = built
        map = built
    end
    return map[encounterId]
end

function TooltipHook:InjectSource(tooltip, itemId, afterBis)
    if not itemId then return end
    local c = cfg()
    if not c.enabled or c.mode == "off" or c.showSource == false then return end

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
        local ord = bossOrderFor(e.instanceId, e.encounterId)
        label = T("TTSRC_DROP", "掉落：")
        -- ⭐ 玩家 2026-09-02：要一眼看出是团本还是大秘境，别只给副本名
        local tag = T("TTSRC_RAID", "团本")
        if boss and ord then
            body = ("%s · %s · %s %s"):format(tag, inst,
                string.format(T("TTSRC_BOSSNUM", "%d号"), ord), boss)
        elseif boss then
            body = ("%s · %s · %s"):format(tag, inst, boss)
        else
            body = ("%s · %s"):format(tag, inst)
        end

    elseif cat == "mplus" then
        -- BisData 的大秘境条目没有 encounterId（bossName 存的是副本名）；
        -- 手册来的条目有，能直接报到具体 BOSS，比只说副本更有用。
        local inst = (EJ_GetInstanceInfo and e.instanceId and EJ_GetInstanceInfo(e.instanceId))
            or (e.source and e.source ~= "" and e.source)
            or (e.bossName ~= "" and e.bossName) or nil
        if not inst then return end
        -- BisData 的大秘境条目只烘到副本名，没有 encounterId；手册那份有，取来补 BOSS 名。
        local encId = e.encounterId
        if not encId and GearInsight.JournalSource then
            local j = GearInsight.JournalSource(itemId)
            if j and j.encounterId then encId = j.encounterId end
        end
        local boss = (EJ_GetEncounterInfo and encId and EJ_GetEncounterInfo(encId)) or nil
        label = T("TTSRC_DROP", "掉落：")
        local tag = T("TTSRC_MPLUS", "大秘境")
        if boss then
            body = ("%s · %s · %s"):format(tag, inst, boss)
        else
            body = ("%s · %s"):format(tag, inst)
        end

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
            local rendered, catShown = self:Inject(tooltip, itemId)
            if not catShown then
                local more = self:InjectFillerOnly(tooltip, itemId, rendered)
                rendered = rendered or more
            end
            self:InjectSource(tooltip, itemId, rendered)
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
            local rendered, catShown = self:Inject(tooltip, iid)
            if not catShown then
                local more = self:InjectFillerOnly(tooltip, iid, rendered)
                rendered = rendered or more
            end
            self:InjectSource(tooltip, iid, rendered)
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
