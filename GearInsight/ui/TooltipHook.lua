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
    local loc = GearInsight.LOC and (GearInsight.LOC[_LOCALE] or GearInsight.LOC["enUS"])
    return (loc and loc[key]) or zh
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
    if self._itemIndex and self._itemIndexSrc == bisData then return self._itemIndex end
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
        local raidPools  = buildPools(spec.bisBySlot)
        -- ⚠️ mplusBySlot 是 BisData 顶层表(按 specKey 索引)，不在 spec 里
        local mplusPools = buildPools((bisData.mplusBySlot or {})[specKey])
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
    if c.enabled == nil then c.enabled = true end
    if c.mode == nil then c.mode = "all" end          -- "current" | "all" | "off"
    if c.maxOtherSpecs == nil then c.maxOtherSpecs = 3 end
    if c.showUsage == nil then c.showUsage = true end
    -- 显示范围（2026-06-06 用户需求）：默认只显示本职业（当前专精+其它专精），
    -- 其它职业行默认隐藏；本职业各专精可逐个勾掉（面板「悬浮提示」菜单）。
    if c.showOthers == nil then c.showOthers = false end
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

    local idx = self._itemIndex
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
    local class, spec
    local cache = self._specCache
    if cache then
        class, spec = cache.class, cache.spec
    elseif self.addon and self.addon.StatReader then
        local ok, st = pcall(function() return self.addon.StatReader:ReadAll() end)
        if ok and st then
            class = st.class
            spec  = st.spec
        end
        self._specCache = { class = class, spec = spec }  -- 读失败也缓存，避免每次悬停重试
    end

    -- Split into current-spec hit + same-class other specs + other classes.
    -- Same-class specs get their own (brighter, uncapped) line so the player
    -- immediately sees how the item ranks for their off-specs.
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
        if tr and tn and cr2 and tr < cr2 then
            tooltip:AddLine(T("TTBIS_CATALYST_PRE", "催化转换成 ") .. tn
                .. string.format(T("TTBIS_CATALYST_POST", " 后 = BiS #%d"), tr),
                0.55, 0.78, 1, true)
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
end

-- ── Registration ────────────────────────────────────────────────────────────
function TooltipHook:Create(addon)
    self.addon = addon

    -- Build the reverse index once.
    local bd = addon and addon.BisData or GearInsight.BisData
    self:BuildItemIndex(bd)

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        -- 12.x unified pipeline: one registration covers every item tooltip.
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if not tooltip or not tooltip.AddLine then return end
            local itemId = getItemIdFromData(tooltip, data)
            self:Inject(tooltip, itemId)
        end)
        self._mode = "datapipeline"
    else
        -- Legacy fallback (pre-10.0.2 clients). Not expected on 120005.
        local function legacy(tooltip)
            if not tooltip or not tooltip.GetItem then return end
            local _, link = tooltip:GetItem()
            if not link then return end
            local id = link:match("item:(%d+):")
            self:Inject(tooltip, id and tonumber(id) or nil)
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
