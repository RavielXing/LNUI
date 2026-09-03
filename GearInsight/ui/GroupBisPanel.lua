-- GroupBisPanel.lua
-- 团队花名册「BiS 体检」面板：进队/团后一眼看全队每人的 BiS 毕业度 + 准备度旗标
-- （缺附魔 / 空孔）。团长开拉前的刚需——对标 raider.io 给「能力(M+分)」，我们给
-- 「准备度」：武器没附魔 / 戒指空孔比 BiS% 更能决定要不要带这个人。
--
-- 原理同 InspectBis：对队内可检视(inspect)且在范围内的玩家逐个 NotifyInspect，
-- INSPECT_READY 后读其穿戴，复用 BisData 算每槽「装等达标」毕业度，并解析装备链
-- 判断附魔/空孔。对方无需装插件。范围外/跨组的人显示「范围外」（暴雪检视限制）。
GearInsight = GearInsight or {}
local GroupBisPanel = {}
GearInsight.GroupBisPanel = GroupBisPanel

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

-- 配对槽 / 统计槽（与 InspectBis 一致）。
local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }
local SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }
-- 可附魔槽（TWW 口径，保守集）：胸/腕/腿/脚/双戒/披风/主手(+副手若为武器)。
local ENCHANTABLE = { [5] = true, [9] = true, [7] = true, [8] = true,
    [11] = true, [12] = true, [15] = true, [16] = true, [17] = true }

-- secret-safe GUID 相等：12.x 起 INSPECT_READY 回传的 guid 是 secret 值，直接 ==
-- 普通字符串会抛错。任一侧 secret 视为不匹配。我们内部一律用存下的普通 _pendingGuid。
local function _rawEq(a, b) return a == b end
local function guidEq(a, b)
    if issecretvalue and (issecretvalue(a) or issecretvalue(b)) then return false end
    local ok, eq = pcall(_rawEq, a, b)  -- 兜底：secret 比较抛错时吞掉，视为不匹配
    return ok and eq == true
end

-- 12.1：单位身份保密时 GetInspectSpecialization 返回 secret（当 table key 会抛错），
-- 同版本新增 C_SpecializationInfo.GetInspectSpecialization。优先新接口 + 双保险守卫。
local function inspectSpecID(unit)
    local fn = (C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization)
        or GetInspectSpecialization
    if not fn then return nil end
    local ok, id = pcall(fn, unit)
    if not ok then return nil end
    if issecretvalue and issecretvalue(id) then return nil end
    return id
end

-- 12.1：UnitClass 在单位身份保密时同样返回 secret，而 classFile 会被拿去索引
-- RAID_CLASS_COLORS（secret 当 key 直接抛错）。取不到就返回 nil，走默认白色名字。
local function safeClassFile(unit)
    local ok, _, classFile = pcall(UnitClass, unit)
    if not ok then return nil end
    if issecretvalue and issecretvalue(classFile) then return nil end
    return classFile
end

-- specID → "CLASS/SPECRAW"
local _specIdToKey
local function specIdToClassSpec(specId)
    if not specId then return nil end
    if not _specIdToKey then
        _specIdToKey = {}
        local bd = GearInsight.BisData
        if bd and bd.specIds then
            for k, id in pairs(bd.specIds) do _specIdToKey[id] = k end
        end
    end
    local k = _specIdToKey[specId]
    if not k then return nil end
    return k:match("^([^/]+)/(.+)$")
end

-- 空孔扫描用隐藏 tooltip（EMPTY_SOCKET* 全局串拼成匹配集，跨语言通用）。
local _scanTT
local _emptyPatterns
local function emptySocketPatterns()
    if _emptyPatterns then return _emptyPatterns end
    _emptyPatterns = {}
    for name, val in pairs(_G) do
        if type(name) == "string" and name:find("^EMPTY_SOCKET") and type(val) == "string" then
            -- 取「空插槽」串里去掉占位后的稳定词干即可作为子串匹配。
            _emptyPatterns[#_emptyPatterns + 1] = val
        end
    end
    return _emptyPatterns
end

-- 读被检视单位的装备 → eq[slot]={itemId,ilvl,enchant}，有效装等件数 n，缺附魔/空孔数。
local function readEquipped(unit)
    local eq, n, noEnch, emptySock = {}, 0, 0, 0
    if not _scanTT then
        _scanTT = CreateFrame("GameTooltip", "GearInsightGBScanTT", nil, "GameTooltipTemplate")
        _scanTT:SetOwner(UIParent, "ANCHOR_NONE")
    end
    local patt = emptySocketPatterns()
    local twoH = false
    for _, sid in ipairs(SLOTS) do
        local link = GetInventoryItemLink(unit, sid)
        if link then
            local ilvl
            if C_Item and C_Item.GetDetailedItemLevelInfo then
                ilvl = C_Item.GetDetailedItemLevelInfo(link)
            elseif GetDetailedItemLevelInfo then
                ilvl = GetDetailedItemLevelInfo(link)
            end
            -- item:itemID:enchantID:...
            local itemId = tonumber(link:match("item:(%d+)"))
            local enchant = tonumber(link:match("item:%d+:(%d+)")) or 0
            eq[sid] = { itemId = itemId, ilvl = ilvl or 0, enchant = enchant }
            if (ilvl or 0) > 0 then n = n + 1 end
            if sid == 16 and itemId and C_Item and C_Item.GetItemInventoryTypeByID then
                local t = C_Item.GetItemInventoryTypeByID(itemId)
                twoH = (t == 17 or t == 26)
            end
            -- 空孔扫描（best-effort）。
            _scanTT:ClearLines()
            local ok = pcall(_scanTT.SetInventoryItem, _scanTT, unit, sid)
            if ok then
                for i = 1, _scanTT:NumLines() do
                    local fs = _G["GearInsightGBScanTTTextLeft" .. i]
                    local txt = fs and fs:GetText()
                    if txt then
                        for _, p in ipairs(patt) do
                            if txt == p then emptySock = emptySock + 1; break end
                        end
                    end
                end
            end
        end
    end
    -- 缺附魔统计：可附魔槽有件、却无 enchantID。
    for sid in pairs(ENCHANTABLE) do
        if not (sid == 17 and twoH) then
            local e = eq[sid]
            if e and (e.ilvl or 0) > 0 and (e.enchant or 0) == 0 then
                noEnch = noEnch + 1
            end
        end
    end
    return eq, n, noEnch, emptySock, twoH
end

local function computeGraduation(class, spec, eq, twoH)
    local bd = GearInsight.BisData
    local data = bd and bd.GetSpecData and bd:GetSpecData(class, spec, nil)
    if not data or not data.bisBySlot then return nil end
    local bySlot, total, grad = data.bisBySlot, 0, 0
    for _, sid in ipairs(SLOTS) do
        if not (sid == 17 and twoH) then
            local cands = bySlot[sid]
            if (not cands or #cands == 0) and PAIR[sid] then cands = bySlot[PAIR[sid]] end
            if cands and #cands > 0 then
                local tgt = 0
                for _, c in ipairs(cands) do if (c.ilvl or 0) > tgt then tgt = c.ilvl end end
                if tgt > 0 then
                    total = total + 1
                    local e = eq[sid]
                    if e and (e.ilvl or 0) >= tgt then grad = grad + 1 end
                end
            end
        end
    end
    if total == 0 then return nil end
    return grad, total
end

-- ── 全队检视队列（顺序，单 pending，避免限流）────────────────────────────
local PENDING_TIMEOUT = 4
local _results = {}     -- guid → { name, classFile, grad, total, noEnch, emptySock, ilvl, status }
local _queue, _pendingGuid, _pendingUnit, _pendingAt = {}, nil, nil, nil
local _scanning = false

local function groupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[#units + 1] = "player"
        for i = 1, (GetNumGroupMembers() - 1) do units[#units + 1] = "party" .. i end
    end
    return units
end

local function evalSelf()
    -- 自己直接读 PaperDoll，不走 inspect。
    local eq, n, noEnch, emptySock, twoH = (function()
        local e, m, ne, es = {}, 0, 0, 0
        local patt = emptySocketPatterns()
        if not _scanTT then
            _scanTT = CreateFrame("GameTooltip", "GearInsightGBScanTT", nil, "GameTooltipTemplate")
            _scanTT:SetOwner(UIParent, "ANCHOR_NONE")
        end
        local twohand = false
        for _, sid in ipairs(SLOTS) do
            local link = GetInventoryItemLink("player", sid)
            if link then
                local ilvl = (C_Item and C_Item.GetDetailedItemLevelInfo
                    and C_Item.GetDetailedItemLevelInfo(link)) or 0
                local itemId = tonumber(link:match("item:(%d+)"))
                local ench = tonumber(link:match("item:%d+:(%d+)")) or 0
                e[sid] = { itemId = itemId, ilvl = ilvl, enchant = ench }
                if ilvl > 0 then m = m + 1 end
                if sid == 16 and itemId and C_Item and C_Item.GetItemInventoryTypeByID then
                    local t = C_Item.GetItemInventoryTypeByID(itemId); twohand = (t == 17 or t == 26)
                end
                _scanTT:ClearLines()
                if pcall(_scanTT.SetInventoryItem, _scanTT, "player", sid) then
                    for i = 1, _scanTT:NumLines() do
                        local fs = _G["GearInsightGBScanTTTextLeft" .. i]
                        local txt = fs and fs:GetText()
                        if txt then for _, p in ipairs(patt) do if txt == p then es = es + 1; break end end end
                    end
                end
            end
        end
        for sid in pairs(ENCHANTABLE) do
            if not (sid == 17 and twohand) then
                local ee = e[sid]
                if ee and ee.ilvl > 0 and ee.enchant == 0 then ne = ne + 1 end
            end
        end
        return e, m, ne, es, twohand
    end)()
    local _, classFile = UnitClass("player")
    local specIdx = GetSpecialization and GetSpecialization()
    local specId = specIdx and GetSpecializationInfo and GetSpecializationInfo(specIdx)
    local class, spec = specIdToClassSpec(specId)
    local guid = UnitGUID("player")
    local res = { name = UnitName("player"), classFile = classFile,
        ilvl = math.floor((select(2, GetAverageItemLevel())) or 0),
        noEnch = noEnch, emptySock = emptySock, status = "ok" }
    if class and spec then
        local grad, total = computeGraduation(class, spec, eq, twoH)
        res.grad, res.total = grad, total
    end
    _results[guid] = res
end

local _onUpdateRow  -- forward decl（UI 刷新回调）

local function finishPending()
    _pendingGuid, _pendingUnit, _pendingAt = nil, nil, nil
end

local function processNext()
    if _pendingGuid then
        if _pendingAt and (GetTime() - _pendingAt) > PENDING_TIMEOUT then
            finishPending()  -- 超时放行
        else
            return
        end
    end
    local unit = table.remove(_queue, 1)
    if not unit then
        _scanning = false
        if _onUpdateRow then _onUpdateRow() end
        return
    end
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return processNext() end
    if UnitIsUnit(unit, "player") then
        evalSelf(); return processNext()
    end
    local guid = UnitGUID(unit)
    local classFile = safeClassFile(unit)
    if not (CanInspect and CanInspect(unit)) then
        _results[guid] = { name = UnitName(unit), classFile = classFile, status = "range" }
        if _onUpdateRow then _onUpdateRow() end
        return processNext()
    end
    _results[guid] = { name = UnitName(unit), classFile = classFile, status = "loading" }
    if _onUpdateRow then _onUpdateRow() end
    _pendingGuid, _pendingUnit, _pendingAt = guid, unit, GetTime()
    NotifyInspect(unit)
    -- Watchdog：INSPECT_READY 可能永不回（限流/掉线/离开范围）→ 超时强制推进，
    -- 避免整队扫描卡在一个人身上。只在仍是同一 pending 时生效。
    C_Timer.After(PENDING_TIMEOUT + 0.5, function()
        if _pendingGuid == guid then
            local r = _results[guid]
            if r and r.status == "loading" then r.status = "range" end
            finishPending()
            if _onUpdateRow then _onUpdateRow() end
            processNext()
        end
    end)
end

-- 读取被检视单位 → 存结果 → 释放锁推进下一个。装等异步未就绪时隔 0.4s 重读，
-- 重试封顶 5 次；单位消失或重试耗尽也必定推进（绝不卡住整队扫描）。
local function readAndStore(guid, attempt)
    -- 只在仍是当前 pending 时处理（watchdog/重复事件防重入）。
    if guid ~= _pendingGuid then return end
    local unit = _pendingUnit
    if not (unit and UnitExists(unit) and guidEq(UnitGUID(unit), guid)) then
        finishPending(); if _onUpdateRow then _onUpdateRow() end; processNext(); return
    end
    local eq, n, noEnch, emptySock, twoH = readEquipped(unit)
    local avgReady = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
        and (C_PaperDollInfo.GetInspectItemLevel(unit) or 0) > 0
    if n == 0 and not avgReady and attempt < 5 then
        C_Timer.After(0.4, function() readAndStore(guid, attempt + 1) end)
        return  -- 保留锁；同一单位的检视数据留着供重读（不 NotifyInspect 别人以免冲掉）
    end
    local specId = inspectSpecID(unit)
    local class, spec = specIdToClassSpec(specId)
    local classFile = safeClassFile(unit)
    local res = { name = UnitName(unit), classFile = classFile,
        ilvl = avgReady and math.floor(C_PaperDollInfo.GetInspectItemLevel(unit)) or nil,
        noEnch = noEnch, emptySock = emptySock, status = "ok" }
    if class and spec then
        local grad, total = computeGraduation(class, spec, eq, twoH)
        res.grad, res.total = grad, total
        if not grad then res.status = "nodata" end
    else
        res.status = "nodata"
    end
    _results[guid] = res
    finishPending()
    if _onUpdateRow then _onUpdateRow() end
    processNext()
end

-- 忽略事件回传的 guid（12.x secret 值）；用请求时存下的普通 _pendingGuid。
local function onInspectReady()
    if not _pendingGuid then return end
    readAndStore(_pendingGuid, 1)
end

local function startScan()
    if not IsInGroup() then
        wipe(_results)
        if _onUpdateRow then _onUpdateRow() end
        return
    end
    wipe(_queue)
    for _, u in ipairs(groupUnits()) do _queue[#_queue + 1] = u end
    _scanning = true
    processNext()
end

-- ── 面板 UI ───────────────────────────────────────────────────────────────
local panel, rows
local ROW_H = 18

local function classColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return 0.9, 0.9, 0.9
end

local function gradColor(grad, total)
    if not grad or not total or total == 0 then return 0.6, 0.6, 0.6 end
    local p = grad / total
    if p >= 0.95 then return 0.4, 0.85, 0.4
    elseif p >= 0.75 then return 0.95, 0.82, 0.2
    else return 0.95, 0.45, 0.35 end
end

local function ensureRow(i)
    rows = rows or {}
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, panel.scroll)
    r:SetSize(panel.scroll:GetWidth(), ROW_H)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("LEFT", 4, 0); r.name:SetWidth(120); r.name:SetJustifyH("LEFT")
    r.grad = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.grad:SetPoint("LEFT", r.name, "RIGHT", 4, 0); r.grad:SetWidth(110); r.grad:SetJustifyH("LEFT")
    r.flags = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.flags:SetPoint("LEFT", r.grad, "RIGHT", 4, 0); r.flags:SetJustifyH("LEFT")
    rows[i] = r
    return r
end

local function renderRows()
    if not panel or not panel:IsShown() then return end
    -- 排序：缺附魔/空孔的优先靠前（准备度问题最该被团长看到），其次按毕业度低→高。
    local list = {}
    for guid, res in pairs(_results) do list[#list + 1] = res end
    table.sort(list, function(a, b)
        local pa = (a.noEnch or 0) + (a.emptySock or 0)
        local pb = (b.noEnch or 0) + (b.emptySock or 0)
        if pa ~= pb then return pa > pb end
        local ga = (a.grad and a.total and a.total > 0) and (a.grad / a.total) or 2
        local gb = (b.grad and b.total and b.total > 0) and (b.grad / b.total) or 2
        return ga < gb
    end)
    local i = 0
    for _, res in ipairs(list) do
        i = i + 1
        local r = ensureRow(i)
        r:SetPoint("TOPLEFT", panel.scroll, "TOPLEFT", 0, -(i - 1) * ROW_H)
        r:Show()
        r.name:SetText(res.name or "?")
        r.name:SetTextColor(classColor(res.classFile))
        if res.status == "range" then
            r.grad:SetText(T("GB_RANGE", "范围外")); r.grad:SetTextColor(0.55, 0.55, 0.55)
            r.flags:SetText("")
        elseif res.status == "loading" then
            r.grad:SetText(T("GB_LOADING", "读取中…")); r.grad:SetTextColor(0.6, 0.6, 0.6)
            r.flags:SetText("")
        elseif res.status == "nodata" then
            r.grad:SetText(T("GB_NODATA", "无 BiS 数据")); r.grad:SetTextColor(0.55, 0.55, 0.55)
            r.flags:SetText("")
        else
            local ilvlTxt = res.ilvl and ("|cffaaaaaa" .. res.ilvl .. "|r ") or ""
            if res.grad and res.total then
                r.grad:SetText(string.format("%sBiS %d/%d", ilvlTxt, res.grad, res.total))
                r.grad:SetTextColor(gradColor(res.grad, res.total))
            else
                r.grad:SetText(ilvlTxt); r.grad:SetTextColor(0.8, 0.8, 0.8)
            end
            local f = {}
            if (res.noEnch or 0) > 0 then
                f[#f + 1] = string.format("|cffff5533" .. T("GB_NOENCH", "缺附魔×%d") .. "|r", res.noEnch)
            end
            if (res.emptySock or 0) > 0 then
                f[#f + 1] = string.format("|cffff9933" .. T("GB_EMPTYSOCK", "空孔×%d") .. "|r", res.emptySock)
            end
            if #f == 0 then f[1] = "|cff66cc66" .. T("GB_READY", "✓ 准备就绪") .. "|r" end
            r.flags:SetText(table.concat(f, "  "))
        end
    end
    for j = i + 1, #(rows or {}) do rows[j]:Hide() end
    panel.scroll:SetHeight(math.max(1, i * ROW_H))
    local cnt = i
    panel.subtitle:SetText(_scanning
        and T("GB_SCANNING", "检视中…")
        or string.format(T("GB_COUNT", "%d 名队友"), cnt))
end
_onUpdateRow = renderRows

local function buildPanel()
    panel = CreateFrame("Frame", "GearInsightGroupBisPanel", UIParent, "BackdropTemplate")
    panel:SetSize(360, 320)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetText("GearInsight · " .. T("GB_TITLE", "团队 BiS 体检"))

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refresh:SetSize(72, 20); refresh:SetPoint("TOPRIGHT", -28, -12)
    refresh:SetText(T("GB_REFRESH", "刷新"))
    refresh:SetScript("OnClick", function() startScan() end)

    local sf = CreateFrame("ScrollFrame", "GearInsightGroupBisScroll", panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -52)
    sf:SetPoint("BOTTOMRIGHT", -30, 14)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(300, 1)
    sf:SetScrollChild(child)
    panel.scroll = child
    child:SetWidth(sf:GetWidth())

    panel:SetScript("OnShow", function() startScan() end)
end

function GroupBisPanel:Toggle()
    if not panel then buildPanel() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

function GroupBisPanel:Create()
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("INSPECT_READY")
    ef:SetScript("OnEvent", function(_, event)
        if event == "INSPECT_READY" then onInspectReady() end
    end)
end
