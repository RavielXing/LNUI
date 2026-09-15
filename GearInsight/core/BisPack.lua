-- core/BisPack.lua —— BisData 打包格式的运行时解码器 + 按专精惰性建表（2026-09-04）
--
-- 背景
-- ─────────────────────────────────────────────────────────────────────
-- 旧 BisData.lua 把 40 个专精 × 每部位 × 每候选各写成一个 Lua 表字面量：
-- 5717 条 ≈ 1.7 万个小表，常驻 4~6MB，是插件内存的大头。
-- 而玩家一次只看自己那 1~3 个专精。
--
-- 现在数据以「物品字典 + 紧凑串」存放（格式见 services/wow-agent/bisdata_pack.py），
-- 只有真被访问到的专精才解码建表：
--     spec.bisBySlot        首次访问 → 解码团本池 + 套用过滤/难度档
--     mplusBySlot[key]      首次访问 → 解码该专精的大秘境池
-- 所有消费方的写法完全不用改（还是 spec.bisBySlot[slotId]、pairs(bd.specs)…）。
--
-- ⛔ 为什么不用 __index 元表代理 BisData.specs 本身：
--    WoW 是 Lua 5.1，**没有 __pairs**。`pairs(bd.specs)` 是好几处在用的
--    （GetClassSpecs / 跨专精刷取计划 / 本职业其它专精列表），
--    代理表会让它只看见"已经建过的"那几个专精 —— 静默漏数据，rc 还是 0。
--    所以 specs 保持 40 个真键，惰性只下沉到每个 spec 的 bisBySlot 这一层。
--
-- ⛔ stats / bonusIDs 是**池化共享表**：多个条目指向同一个 Lua 表。
--    只读没问题（tooltip/装等/链接都只读），⛔ 谁都别就地改它们，
--    要改先自己 copy 一份，否则会串到别的装备上。

GearInsight = GearInsight or {}

local BisPack = {}
GearInsight.BisPack = BisPack

-- 与 TierView.lua 保持一致：只有存在难度阶梯的来源才随难度档换算装等
-- ⛔ 难度档只降**团本**来源（含团本套装件）：大秘境的 BiS 装等跟团本英雄/普通没关系（钥石宝箱/升级轨道自成一套），
--    以前把 mplus 也一起减 13 → 切到「英雄」后夺目谷饰品写成 295（用户 2026-09-12「bis 不应该是 H 的」）。
local SCALED_CATEGORIES = { raid = true, tier = true }

-- ── 小工具 ───────────────────────────────────────────────────────────
-- 编码端保证「中间不会出现空字段」（全是数字，尾部 0 才被截掉），
-- 所以可以直接用 [^,]+ 切；缺位一律按 0 处理。
local function splitNums(rec, out)
    local n = 0
    for v in string.gmatch(rec, "[^,]+") do
        n = n + 1
        out[n] = tonumber(v) or 0
    end
    for i = n + 1, 11 do out[i] = 0 end
    return out
end

-- ── 物品字典：整行文本 → 字段表（首次用到才拆，拆完缓存）──────────────
local ITEM_FIELDS = { "name", "src", "cat", "boss", "inst", "enc",
                      "tier", "hand", "onuse", "order" }

local function itemInfo(bd, itemId)
    local cache = bd._itemCache
    local info = cache[itemId]
    if info then return info end
    local row = bd.items and bd.items[itemId]
    if not row then return nil end
    info = {}
    local i = 0
    for v in string.gmatch(row, "[^,]+") do
        i = i + 1
        info[ITEM_FIELDS[i]] = tonumber(v) or 0
    end
    for j = i + 1, #ITEM_FIELDS do info[ITEM_FIELDS[j]] = 0 end
    cache[itemId] = info
    return info
end

-- ── 解码一条候选 ─────────────────────────────────────────────────────
-- 字段序（见 bisdata_pack.py）：
--   iid, usage, bonusIdx, mx, ilvl, statsIdx [, srcIdx, catIdx, bossIdx, inst, enc]
-- 后 5 个是「覆盖」：同一件东西既能套装转换又能 BOSS 掉时才写。
local _f = {}
local function decodeEntry(bd, rec)
    splitNums(rec, _f)
    local iid = _f[1]
    local info = itemInfo(bd, iid)
    if not info then return nil end

    local hasOvr = _f[7] ~= 0 or _f[8] ~= 0 or _f[9] ~= 0 or _f[10] ~= 0 or _f[11] ~= 0
    local srcI  = hasOvr and _f[7]  or info.src
    local catI  = hasOvr and _f[8]  or info.cat
    local bossI = hasOvr and _f[9]  or info.boss
    local inst  = hasOvr and _f[10] or info.inst
    local enc   = hasOvr and _f[11] or info.enc

    -- ⛔ 别写成 `info.onuse ~= 0 and (info.onuse == 1) or nil`：
    --    被动饰品(onuse==2)会算出 `false or nil` = nil，把「被动」丢成「未知」，
    --    饰品配对推荐的「一主动一被动」就失效了。and/or 表达不了 false。
    local onUse = nil
    if info.onuse == 1 then onUse = true elseif info.onuse == 2 then onUse = false end

    -- 物品名按客户端语言：pool_n 是中文名；非中文客户端优先 item_en（WCL 英文名），
    -- 客户端缓存到了会由 locName 再换成真正的本地化名。itemNameCn 永远保留给中文口径的判断用。
    local _cn = info.name ~= 0 and bd.pool_n[info.name] or ""
    local _loc = GearInsight and GearInsight.LOCALE
    local _nm = _cn
    if _loc and _loc ~= "zhCN" and _loc ~= "zhTW" and bd.item_en and bd.item_en[iid] then _nm = bd.item_en[iid] end
    return {
        itemId         = iid,
        itemName       = _nm,
        itemNameCn     = _cn,
        ilvl           = _f[5],
        source         = srcI ~= 0 and bd.pool_s[srcI] or "",
        sourceCategory = catI ~= 0 and bd.pool_c[catI] or "",
        bossName       = bossI ~= 0 and bd.pool_b[bossI] or "",
        isTier         = info.tier == 1,
        instanceId     = inst ~= 0 and inst or nil,
        encounterId    = enc ~= 0 and enc or nil,
        bossOrder      = info.order ~= 0 and info.order or nil,
        handedness     = info.hand ~= 0 and bd.pool_h[info.hand] or nil,
        onUse          = onUse,
        stats          = _f[6] ~= 0 and bd.pool_st[_f[6]] or nil,
        bonusIDs       = _f[3] ~= 0 and bd.pool_bo[_f[3]] or nil,
        mx             = _f[4] ~= 0 and _f[4] or nil,
        usagePct       = _f[2],
    }
end

-- ── 解码一整个池 ─────────────────────────────────────────────────────
-- "slot:条目;条目|slot:条目" → { [slotId] = { e, e, ... } }
function BisPack.DecodePool(bd, packed)
    local out = {}
    if not packed or packed == "" then return out end
    for chunk in string.gmatch(packed, "[^|]+") do
        local slotStr, body = string.match(chunk, "^(%d+):(.*)$")
        if slotStr then
            local list = {}
            for rec in string.gmatch(body, "[^;]+") do
                local e = decodeEntry(bd, rec)
                if e then list[#list + 1] = e end
            end
            out[tonumber(slotStr)] = list
        end
    end
    return out
end

-- ── 单个专精：解码 + 套用「使用率参照系 / 排除团本 / 难度档」──────────
-- 这一段是旧 BisData:ApplyDataFilters 的逐专精版本，逻辑逐行照搬，
-- 区别只是「什么时候跑」：以前是换设置时把 40 个专精全重建一遍，
-- 现在是某个专精第一次被读到时才建它自己那一份。
local function buildSpec(bd, key, spec)
    local mode = bd:GetUsageMode()
    local exRaid = bd:GetExcludeRaid()
    local step = GearInsight.GearTierStep and GearInsight:GearTierStep() or 0
    local m = (bd.mplusUsage or {})[key] or {}

    local raw = BisPack.DecodePool(bd, spec._pb)
    -- 走 bd.mplusBySlot 而不是自己再解一遍：那张表是带缓存的惰性代理，
    -- 条目在多次重建之间保持同一批 Lua 表（_usageRaid/_ilvlRaw 才不会丢），与旧行为一致。
    local mp = (mode == "mplus") and bd.mplusBySlot[key] or nil

    local bySlot = {}
    for slotId, all in pairs(raw) do
        -- 大秘境模式：优先用该专精该槽的 M+ 真实候选池(自带 M+ 使用率/来源/装等)，
        -- 无该槽 M+ 数据时回退团本池并用 mplusUsage 上色(老行为)。团本模式恒用团本池。
        local src, mplusPool
        if mode == "mplus" and mp and mp[slotId] and #mp[slotId] > 0 then
            src, mplusPool = mp[slotId], true
        else
            src, mplusPool = all, false
        end
        local list = {}
        for _, c in ipairs(src) do
            if not (exRaid and c.sourceCategory == "raid") then list[#list + 1] = c end
        end
        for _, c in ipairs(list) do
            if c._usageRaid == nil then c._usageRaid = c.usagePct or 0 end
            if mplusPool then
                c.usagePct = c.usagePct or (m[c.itemId] or 0)   -- M+ 池记录已自带真实 M+ 使用率
            else
                c.usagePct = (mode == "mplus") and (m[c.itemId] or 0) or (c._usageRaid or 0)
            end
            -- 难度档换算（旧 TierView.applyTier 的逐条目部分，挪到建表这一刻做）
            if c._ilvlRaw == nil then c._ilvlRaw = c.ilvl or 0 end
            if step > 0 and c._ilvlRaw > 0 and SCALED_CATEGORIES[c.sourceCategory or ""] then
                c.ilvl = math.max(c._ilvlRaw - step, 1)
            else
                c.ilvl = c._ilvlRaw
            end
        end
        -- 排序：史诗档（step=0）纯按使用率；英雄/普通档先按换算后装等、同装等再按使用率
        --   （用户 2026-09-12 定口径：切到英雄档后团本件被压到 321，不该还排在 334 的大秘境件前面）
        if step > 0 then
            table.sort(list, function(a, b)
                local ai, bi = a.ilvl or 0, b.ilvl or 0
                if ai ~= bi then return ai > bi end
                return (a.usagePct or 0) > (b.usagePct or 0)
            end)
        else
            table.sort(list, function(a, b) return (a.usagePct or 0) > (b.usagePct or 0) end)
        end
        bySlot[slotId] = list
    end
    -- 原始团本池（未过滤、按团本使用率序）暴露给悬浮：大秘境参照时「团本 #N」那条参考数从这里读
    rawset(spec, "_rawBisBySlot", raw)
    return bySlot
end

-- ── 安装 ─────────────────────────────────────────────────────────────
function BisPack.Install(bd)
    if not bd or bd.packFormat ~= 1 then return end     -- 老格式文件：什么都不做
    bd._itemCache = {}

    -- ① 每个 spec 挂元表：读 bisBySlot 时才建
    local specMT = {
        __index = function(t, k)
            if k ~= "bisBySlot" then return nil end
            local built = buildSpec(bd, rawget(t, "_key"), t)
            rawset(t, "bisBySlot", built)
            return built
        end,
    }
    for key, spec in pairs(bd.specs or {}) do
        rawset(spec, "_key", key)
        setmetatable(spec, specMT)
    end

    -- ② mplusBySlot：整表惰性，按 key 解码
    --    ⚠ 只被 `mbs[key]` 这样点名取用（全仓已确认没有 pairs(mplusBySlot)），
    --      所以代理表在这里是安全的 —— 与 specs 的情况不同。
    bd.mplusBySlot = setmetatable({}, {
        __index = function(t, key)
            local packed = bd._pm and bd._pm[key]
            local decoded = BisPack.DecodePool(bd, packed)
            rawset(t, key, decoded)
            return decoded
        end,
    })

    -- ③ 丢弃已建的表，下次读时按当前设置重建
    function bd:InvalidatePools()
        for _, spec in pairs(self.specs or {}) do
            rawset(spec, "bisBySlot", nil)
        end
    end

    -- ④ 过滤设置读取 + 签名（逐专精版，替代旧的全量重建）
    function bd:GetUsageMode()
        return (GearInsightDB and GearInsightDB.usageMode) or "raid"
    end
    function bd:GetExcludeRaid()
        local ov = GearInsight._fgFilterOverride
        if ov and ov.exRaid ~= nil then return ov.exRaid and true or false end
        return (GearInsightDB and GearInsightDB.excludeRaid) and true or false
    end
    function bd:ApplyDataFilters()
        local sig = self:GetUsageMode() .. (self:GetExcludeRaid() and "|ex" or "")
        if self._filterSig == sig then return end
        self._filterSig = sig
        self:InvalidatePools()          -- 只是把 40 个 bisBySlot 置空，不解码
    end
    function bd:SetUsageMode(mode)
        if GearInsightDB then GearInsightDB.usageMode = mode end
        self._filterSig = nil
        self:ApplyDataFilters()
    end
    function bd:EnsureUsageMode()
        self:ApplyDataFilters()
    end
    -- 旧的 _cacheRaw 没有了：原始池现在就是 spec._pb 那串文本，天然不会被改坏。
    bd._cacheRaw = function() end
end
