-- InspectBis.lua
-- 组队时悬停他人 → 单位 tooltip 显示其 BiS 毕业度（毕业 X/Y · 缺 N 件）。
-- 原理：对可检视(inspect)的玩家发起 NotifyInspect，INSPECT_READY 后读取其
-- 当前穿戴装备 + 专精，复用本插件 BisData 算每槽「装等达标」毕业度。对方无需装插件。
-- 受限：只能对同队/同团/目标且在范围内的玩家生效（暴雪检视机制限制）；集合石
-- 申请列表里(未接受前)拿不到装备，无法显示——那是暴雪不开放的数据。
GearInsight = GearInsight or {}
local InspectBis = {}
GearInsight.InspectBis = InspectBis

-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。
-- ⛔别再写 GetLocale()：每个文件各抄一份就会出现“面板英文、大米攻略中文”这种分裂。
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local loc = GearInsight.LOC and (GearInsight.LOC[_LOCALE] or GearInsight.LOC["enUS"])
    return (loc and loc[key]) or zh
end

-- 配对槽：某槽 BiS 候选为空时回退到同池兄弟槽（戒指/饰品/武器）。
local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }
-- 参与毕业统计的实体槽（跳过衬衫4/战袍19）。
local SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }

-- specID → "CLASS/SPECRAW"（由 BisData.specIds 反建，一次）。
local _specIdToKey
-- 12.1：单位身份保密时 GetInspectSpecialization 会返回 secret（拿去当 table key 直接抛错），
-- 同版本官方新增了 C_SpecializationInfo.GetInspectSpecialization。优先走新接口，
-- 两条路径都 pcall + issecretvalue 双保险；拿不到就当「无数据」，不让检视面板炸掉。
local function inspectSpecID(unit)
    local fn = (C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization)
        or GetInspectSpecialization
    if not fn then return nil end
    local ok, id = pcall(fn, unit)
    if not ok then return nil end
    if issecretvalue and issecretvalue(id) then return nil end
    return id
end

local function specIdToClassSpec(specId)
    if not specId then return nil end
    if not _specIdToKey then
        _specIdToKey = {}
        local bd = GearInsight.BisData
        if bd and bd.specIds then
            for key, id in pairs(bd.specIds) do _specIdToKey[id] = key end
        end
    end
    local key = _specIdToKey[specId]
    if not key then return nil end
    local class, spec = key:match("^([^/]+)/(.+)$")
    return class, spec
end

-- 读取被检视单位的穿戴装备：slotId → { itemId, ilvl }（有效装等，含强化）。
local function readEquipped(unit)
    local eq, n = {}, 0
    for _, sid in ipairs(SLOTS) do
        local link = GetInventoryItemLink(unit, sid)
        if link then
            local ilvl
            if C_Item and C_Item.GetDetailedItemLevelInfo then
                ilvl = C_Item.GetDetailedItemLevelInfo(link)
            elseif GetDetailedItemLevelInfo then
                ilvl = GetDetailedItemLevelInfo(link)
            end
            local itemId = tonumber(link:match("item:(%d+)"))
            eq[sid] = { itemId = itemId, ilvl = ilvl or 0 }
            if (ilvl or 0) > 0 then n = n + 1 end
        end
    end
    return eq, n
end

-- 计算毕业度：每槽取 BiS 候选最高装等为目标，装备达标即毕业。
-- 返回 grad(已毕业), total(可统计槽), missing(缺件)；无数据返回 nil。
local function computeGraduation(class, spec, equipped)
    local bd = GearInsight.BisData
    local data = bd and bd.GetSpecData and bd:GetSpecData(class, spec, nil)
    if not data or not data.bisBySlot then return nil end
    local bySlot = data.bisBySlot

    -- 双手武器：无副手，副手槽不计入。
    local twoH = false
    local mh = equipped[16]
    if mh and mh.itemId and C_Item and C_Item.GetItemInventoryTypeByID then
        local t = C_Item.GetItemInventoryTypeByID(mh.itemId)
        twoH = (t == 17 or t == 26) -- INVTYPE_2HWEAPON / INVTYPE_RANGEDRIGHT
    end

    local total, grad = 0, 0
    for _, sid in ipairs(SLOTS) do
        if not (sid == 17 and twoH) then
            local cands = bySlot[sid]
            if (not cands or #cands == 0) and PAIR[sid] then
                cands = bySlot[PAIR[sid]]
            end
            if cands and #cands > 0 then
                local tgt = 0
                for _, e in ipairs(cands) do
                    if (e.ilvl or 0) > tgt then tgt = e.ilvl end
                end
                if tgt > 0 then
                    total = total + 1
                    local eq = equipped[sid]
                    if eq and (eq.ilvl or 0) >= tgt then grad = grad + 1 end
                end
            end
        end
    end
    if total == 0 then return nil end
    return grad, total, total - grad
end

-- ── 检视队列（同时只跑一个，避免被限流）+ GUID 结果缓存 ──────────────────
local CACHE_TTL = 180         -- 秒：装备不常变，缓存够用
local PENDING_TIMEOUT = 4     -- 秒：检视无响应则放行下一个
local _cache = {}             -- guid → { grad, total, missing, t }
local _pendingGuid, _pendingUnit, _pendingAt

local function buildText(res)
    if not res then return nil end
    if res.missing <= 0 then
        return string.format(T("IB_ALLDONE", "GearInsight：BiS 全部毕业 (%d/%d) ✓"), res.grad, res.total),
            0.4, 0.85, 0.4
    end
    return string.format(T("IB_LINE", "GearInsight：BiS 毕业 %d/%d · 缺 %d 件"),
        res.grad, res.total, res.missing), 1, 0.82, 0
end

local function finishInspect(guid)
    if _pendingGuid == guid then
        _pendingGuid, _pendingUnit, _pendingAt = nil, nil, nil
    end
    -- 注意：不调用 ClearInspectPlayer()——多插件并存时它会清掉别的插件
    -- (如 ElvUI 物品等级) 正在进行的检视，导致对方一直读不到数据。检视数据
    -- 留着也方便我们的延迟重读(装备 ilvl 异步加载时)。
end

-- secret-safe GUID 相等：12.x 起 INSPECT_READY 事件回传的 guid 是 secret 值，
-- 直接 == 普通字符串会抛 "attempt to compare a secret string value"。任一侧为
-- secret 即视为不匹配（降级，不崩）。我们内部一律用请求时存下的普通 _pendingGuid。
local function _rawEq(a, b) return a == b end
local function guidEq(a, b)
    if issecretvalue and (issecretvalue(a) or issecretvalue(b)) then return false end
    -- 兜底：万一 issecretvalue 不存在/漏判，secret 比较会抛错——pcall 吞掉，视为不匹配。
    local ok, eq = pcall(_rawEq, a, b)
    return ok and eq == true
end

-- 按 GUID 找回一个当前有效的单位令牌（鼠标可能已移开 _pendingUnit）。
local function unitForGuid(guid)
    if _pendingUnit and UnitExists(_pendingUnit) and guidEq(UnitGUID(_pendingUnit), guid) then
        return _pendingUnit
    end
    for _, u in ipairs({ "mouseover", "target", "focus" }) do
        if UnitExists(u) and guidEq(UnitGUID(u), guid) then return u end
    end
    local prefix, n = (IsInRaid() and "raid" or "party"), (IsInRaid() and 40 or 4)
    for i = 1, n do
        local u = prefix .. i
        if UnitExists(u) and guidEq(UnitGUID(u), guid) then return u end
    end
    return nil
end

-- tooltip:GetUnit() 在世界光标等受保护场景返回 secret 值，
-- 传给 UnitExists/UnitGUID 会硬报错，使用前必须先放行检查。
-- issecretvalue 必须最先跑：secret 值连真值测试(not unit)都不保证安全，
-- 它是唯一可对任意值安全调用的探测函数。
local function usableUnit(unit)
    if issecretvalue and issecretvalue(unit) then return nil end
    if not unit then return nil end
    return unit
end

-- 若 GameTooltip 还停在这个人身上，重设单位以重跑 post-call（命中缓存）。
local function refreshTooltipIfShowing(guid)
    if GameTooltip and GameTooltip.GetUnit and GameTooltip:IsShown() then
        local _, tu = GameTooltip:GetUnit()
        tu = usableUnit(tu)
        if tu and guidEq(UnitGUID(tu), guid) then GameTooltip:SetUnit(tu) end
    end
end

-- 读装备 + 算毕业 + 缓存。装备 ilvl 异步加载，首帧常常一件都没读到——
-- 这时绝不能把 0/16 当结果缓存(会卡住 180 秒)，而是隔 0.4 秒重读，重试几次。
local function computeAndCache(unit, guid, attempt)
    if not (UnitExists(unit) and guidEq(UnitGUID(unit), guid)) then return end
    local equipped, n = readEquipped(unit)
    -- 读取就绪信号：有效装等件数 + 暴雪自带的平均装等接口任一为正即算就绪。
    local avgReady = false
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        avgReady = (C_PaperDollInfo.GetInspectItemLevel(unit) or 0) > 0
    end
    if n == 0 and not avgReady then
        if attempt < 5 then
            C_Timer.After(0.4, function() computeAndCache(unit, guid, attempt + 1) end)
        end
        return  -- 不缓存坏结果；下次悬停或重试会再来
    end

    local specId = inspectSpecID(unit)
    local class, spec = specIdToClassSpec(specId)
    if class and spec then
        local grad, total, missing = computeGraduation(class, spec, equipped)
        if grad then
            _cache[guid] = { grad = grad, total = total, missing = missing, t = GetTime() }
        else
            _cache[guid] = { none = true, t = GetTime() }   -- 该专精无 BiS 数据(如非当前资料片)
        end
    else
        _cache[guid] = { none = true, t = GetTime() }
    end
    refreshTooltipIfShowing(guid)
end

-- 检视回来：解析单位 → 读装备算结果(带重试) → 放行检视锁。
-- 注意：忽略事件回传的 guid（12.x 起它是 secret 值，比较/索引都会抛错）；
-- 改用请求时存下的普通 _pendingGuid + _pendingUnit。
local function onInspectReady()
    local guid, unit = _pendingGuid, _pendingUnit
    if not guid then return end
    if not (unit and UnitExists(unit)) then unit = unitForGuid(guid) end
    if unit then computeAndCache(unit, guid, 1) end
    finishInspect(guid)   -- 释放锁；检视数据保留，重试仍可读
end

local function requestInspect(unit, guid)
    if _pendingGuid then
        -- 有在途检视：超时则放行，否则本次跳过（下次悬停重试）。
        if _pendingAt and (GetTime() - _pendingAt) > PENDING_TIMEOUT then
            finishInspect(_pendingGuid)
        else
            return
        end
    end
    _pendingGuid, _pendingUnit, _pendingAt = guid, unit, GetTime()
    NotifyInspect(unit)
end

-- ── 单位 tooltip 注入 ─────────────────────────────────────────────────────
local function injectUnit(tooltip)
    if not tooltip or tooltip ~= GameTooltip then return end
    -- 默认关闭(opt-in)：仅当玩家显式开启 inspectBisOn 才注入队友 BiS 行。
    if not (GearInsightDB and GearInsightDB.inspectBisOn) then return end
    local _, unit = tooltip:GetUnit()
    unit = usableUnit(unit)
    if not unit or not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    local cached = _cache[guid]
    if cached and (GetTime() - cached.t) < CACHE_TTL then
        if cached.none then return end
        local text, r, g, b = buildText(cached)
        if text then tooltip:AddLine(text, r, g, b) end
        return
    end

    if CanInspect and CanInspect(unit) then
        tooltip:AddLine(T("IB_LOADING", "GearInsight：读取装备中…"), 0.6, 0.6, 0.6)
        requestInspect(unit, guid)
    end
end

function InspectBis:Create()
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("INSPECT_READY")
    ef:SetScript("OnEvent", function(_, event)
        if event == "INSPECT_READY" then onInspectReady() end
    end)

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            injectUnit(tooltip)
        end)
    elseif GameTooltip then
        GameTooltip:HookScript("OnTooltipSetUnit", injectUnit)
    end
end
