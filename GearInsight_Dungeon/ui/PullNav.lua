-- ui/PullNav.lua —— 「新手T领航」拉怪清单 + 领航条（2026-09-19 用户「进入副本后知道一共几次拉，每次拉什么」）
--
-- 数据：core/PullPlanData.lua（顶尖 T 共识路线，按副本中文名索引）。
-- 三块：① 清单面板（几包 / 每包拉什么 / 占进度 / 顶尖耗时 / 支持率，当前包高亮）
--       ② 推进器：钥石里读数怪百分比（C_ScenarioInfo 的 isWeightedProgress 那条）对照累计 %，BOSS 包看 ENCOUNTER_END；
--          普通 / 追随者本没有数怪 → 手动 ◀ ▶ 或 /gi nav sim 模拟推进（用户 2026-09-19「能模拟下，我先测试效果」）
--       ③ 名牌：本包的怪名牌上打金框，下一包灰框，不在路线里的红框
-- ⛔ 读取型：不碰 Pickup / Place / SetBinding；GUID 过 issecretvalue；战斗中不建帧。
-- 开关：GearInsightDB.pullNavOff = true 关闭；位置 GearInsightDB.pullNavPos。

GearInsight = GearInsight or {}
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local ZH = (_LOCALE == "zhCN" or _LOCALE == "zhTW")
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
local function isSecret(v) return issecretvalue and issecretvalue(v) or false end

local GOLD = { 1, 0.82, 0 }
local plan, cur, progress, simTimer, frame, plates = nil, 1, 0, nil, nil, {}
local mobName = function(m) return (ZH and m.cn ~= "" and m.cn) or m.en end

-- ── 数据 ────────────────────────────────────────────────────────────────
local function resolvePlan()
    local data = GearInsightPullPlan
    if not data then return nil end
    local name, instanceType = GetInstanceInfo()
    if instanceType ~= "party" or not name then return nil end
    local cn = GearInsight.DungeonCnName and GearInsight.DungeonCnName(name)
    return cn and data[cn] or data[name] or nil
end

local function mobSet(p)
    local s = {}
    if p then for _, m in ipairs(p.mobs) do s[m.id] = true end end
    return s
end

-- ── 推进器 ──────────────────────────────────────────────────────────────
local function readForces()
    -- 钥石：数怪那条 criteria 是 isWeightedProgress，quantityString 形如 "37%"
    if not (C_Scenario and C_Scenario.GetStepInfo and C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo) then return nil end
    local n = select(3, C_Scenario.GetStepInfo()) or 0
    for i = 1, n do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and info.isWeightedProgress then
            local qs = info.quantityString
            if qs and not isSecret(qs) then
                local v = tonumber((tostring(qs):gsub("%%", "")))
                if v then return v end
            end
            if info.quantity and info.totalQuantity and info.totalQuantity > 0 and not isSecret(info.quantity) then
                return info.quantity / info.totalQuantity * 100
            end
        end
    end
    return nil
end

local refresh -- forward
local function advanceByProgress()
    if not plan then return end
    local p = plan.pulls[cur]
    if not p then return end
    if p.boss then return end               -- BOSS 包等 ENCOUNTER_END
    -- 当前包的累计 % 已达到 → 下一包（留 0.5% 容差，避免 39.9 vs 40 卡住）
    if progress + 0.5 >= p.cum and cur < #plan.pulls then
        cur = cur + 1
        refresh()
    end
end

local function stopSim()
    if simTimer then simTimer:Cancel(); simTimer = nil end
end

local function startSim()
    stopSim()
    if not plan then return end
    GearInsight:Print(T("PN_SIM_ON", "领航模拟：按顶尖耗时的 1/8 速度自动推进（/gi nav sim 再按一次停止）"))
    simTimer = C_Timer.NewTicker(0.5, function()
        local p = plan and plan.pulls[cur]
        if not p then stopSim(); return end
        if p.boss then
            p._simT = (p._simT or 0) + 0.5
            if p._simT >= 4 then p._simT = nil; if cur < #plan.pulls then cur = cur + 1 end; refresh() end
            return
        end
        local step = (p.pct or 0) / math.max(1, (p.dur or 60) / 8) * 0.5   -- 每 0.5s 走的进度
        progress = math.min(p.cum or 100, progress + step)
        refresh()
        advanceByProgress()
        if cur >= #plan.pulls and progress + 0.5 >= (plan.pulls[#plan.pulls].cum or 100) then stopSim() end
    end)
end

-- ── 名牌 ────────────────────────────────────────────────────────────────
local function npcIDFromUnit(unit)
    local guid = UnitGUID(unit)
    if not guid or isSecret(guid) then return nil end
    local id = select(6, strsplit("-", guid))
    return id and tonumber(id) or nil
end

local function plateMark(unit, kind)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    if not np then return end
    local m = np._giPullMark
    if not m then
        m = CreateFrame("Frame", nil, np, "BackdropTemplate")
        m:SetFrameLevel((np:GetFrameLevel() or 0) + 5)
        m:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        np._giPullMark = m
    end
    if not kind then m:Hide(); return end
    local hb = np.UnitFrame and np.UnitFrame.healthBar or np.UnitFrame
    m:ClearAllPoints()
    if hb then m:SetPoint("TOPLEFT", hb, "TOPLEFT", -2, 2); m:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 2, -2)
    else m:SetPoint("CENTER", np, "CENTER"); m:SetSize(120, 14) end
    if kind == "cur" then m:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    elseif kind == "next" then m:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    else m:SetBackdropBorderColor(1, 0.25, 0.25, 0.9) end
    m:Show()
end

local function recolorPlates()
    if not plan then return end
    local curSet, nextSet = mobSet(plan.pulls[cur]), mobSet(plan.pulls[cur + 1])
    for unit, id in pairs(plates) do
        if curSet[id] then plateMark(unit, "cur")
        elseif nextSet[id] then plateMark(unit, "next")
        else plateMark(unit, "other") end
    end
end

-- ── 面板 ────────────────────────────────────────────────────────────────
local ROWS = 16
local function ensureFrame()
    if frame then return frame end
    local f = CreateFrame("Frame", "GearInsightPullNav", UIParent, "BackdropTemplate")
    f:SetSize(430, 60)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.04, 0.05, 0.08, 0.92); f:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local p, _, rp, x, y = s:GetPoint()
        GearInsightDB = GearInsightDB or {}; GearInsightDB.pullNavPos = { p, rp, x, y }
    end)
    local pos = GearInsightDB and GearInsightDB.pullNavPos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -200) end
    f:SetFrameStrata("MEDIUM")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.title:SetPoint("TOPLEFT", 10, -8)
    f.stage = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.stage:SetPoint("TOPLEFT", 10, -26); f.stage:SetPoint("RIGHT", -120, 0); f.stage:SetJustifyH("LEFT"); f.stage:SetWordWrap(false)
    f.now = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.now:SetPoint("TOPLEFT", 10, -42); f.now:SetPoint("RIGHT", -10, 0); f.now:SetJustifyH("LEFT"); f.now:SetWordWrap(false)

    local function btn(text, w, x, onClick, tip)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 20); b:SetPoint("TOPRIGHT", x, -6); b:SetText(text); b:SetScript("OnClick", onClick)
        if tip then
            b:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(tip, 1, 0.82, 0, 1, true); GameTooltip:Show() end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        return b
    end
    f.close = btn("×", 20, -6, function() f:Hide() end)
    f.fold = btn("≡", 24, -28, function() f._folded = not f._folded; refresh() end, T("PN_FOLD_TIP", "展开 / 收起整份清单"))
    f.next = btn("▶", 24, -54, function() if plan and cur < #plan.pulls then cur = cur + 1; refresh() end end, T("PN_NEXT_TIP", "下一包（普通 / 追随者本没有数怪进度，手动翻）"))
    f.prev = btn("◀", 24, -80, function() if plan and cur > 1 then cur = cur - 1; refresh() end end)

    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(410, 18); r:SetPoint("TOPLEFT", 10, -64 - (i - 1) * 18)
        r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 0.82, 0, 0.12); r.bg:Hide()
        r.i = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.i:SetPoint("LEFT", 2, 0); r.i:SetWidth(22); r.i:SetJustifyH("RIGHT")
        r.pct = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.pct:SetPoint("LEFT", 28, 0); r.pct:SetWidth(44); r.pct:SetJustifyH("RIGHT")
        r.mobs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.mobs:SetPoint("LEFT", 78, 0); r.mobs:SetPoint("RIGHT", -56, 0); r.mobs:SetJustifyH("LEFT"); r.mobs:SetWordWrap(false)
        r.dur = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.dur:SetPoint("RIGHT", -2, 0); r.dur:SetWidth(52); r.dur:SetJustifyH("RIGHT")
        r:EnableMouse(true)
        r:SetScript("OnMouseUp", function() if plan and r._idx then cur = r._idx; refresh() end end)
        r:SetScript("OnEnter", function(s)
            local p = plan and plan.pulls[s._idx]
            if not p then return end
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format(T("PN_TIP_HD", "第 %d 包 · %s · 顶尖 %ds · 支持率 %d%%"), p.i, p.boss and "BOSS" or string.format("%.1f%%", p.pct or 0), p.dur or 0, math.floor((p.sup or 0) * 100 + 0.5)), 1, 0.82, 0)
            for _, m in ipairs(p.mobs) do
                GameTooltip:AddLine((m.boss and "|cffff5555" or "|cffffffff") .. mobName(m) .. "|r" .. (m.boss and "" or ("  ×" .. m.n)), 1, 1, 1)
            end
            GameTooltip:AddLine(T("PN_TIP_CLICK", "点击 = 把这一包设为当前"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.rows[i] = r
    end
    frame = f
    return f
end

refresh = function()
    if not plan then if frame then frame:Hide() end; return end
    local f = ensureFrame()
    local n = #plan.pulls
    f.title:SetText(string.format("|cffe2b85c%s|r  |cff888888%s|r", ZH and plan.cn or plan.en, string.format(T("PN_META", "%d 包 · 顶尖 %d 局 +%d"), n, plan.runs or 0, plan.key or 0)))
    local p = plan.pulls[cur]
    local mode = simTimer and T("PN_MODE_SIM", "模拟") or (readForces() and T("PN_MODE_KEY", "钥石") or T("PN_MODE_MANUAL", "手动"))
    f.stage:SetText(string.format(T("PN_STAGE", "第 %d / %d 包 · 进度 %.1f%% · %s"), cur, n, progress, mode))
    if p then
        local parts = {}
        for k, m in ipairs(p.mobs) do
            if k > 4 then parts[#parts + 1] = "…"; break end
            parts[#parts + 1] = (m.boss and "|cffff5555" or "") .. mobName(m) .. (m.boss and "|r" or ("|cff888888×" .. m.n .. "|r"))
        end
        f.now:SetText((p.boss and "|cffff5555BOSS|r " or string.format("|cffe2b85c%.1f%%|r ", p.pct or 0)) .. table.concat(parts, " ") .. string.format("  |cff888888%ds|r", p.dur or 0))
    end
    local show = math.min(ROWS, n)
    local off = 0
    if n > ROWS then off = math.max(0, math.min(cur - 4, n - ROWS)) end
    for i = 1, ROWS do
        local r = f.rows[i]
        local idx = i + off
        local q = (not f._folded) and plan.pulls[idx] or nil
        r._idx = idx
        if q then
            r:Show()
            r.bg:SetShown(idx == cur)
            local col = idx < cur and "|cff666666" or (idx == cur and "|cffe2b85c" or "|cffdddddd")
            r.i:SetText(col .. q.i .. "|r")
            r.pct:SetText(q.boss and "|cffff5555BOSS|r" or (col .. string.format("%.1f%%", q.pct or 0) .. "|r"))
            local parts = {}
            for k, m in ipairs(q.mobs) do
                if k > 5 then parts[#parts + 1] = "…"; break end
                parts[#parts + 1] = mobName(m) .. (m.boss and "" or ("×" .. m.n))
            end
            r.mobs:SetText(col .. table.concat(parts, " ") .. "|r")
            r.dur:SetText((q.dur or 0) .. "s" .. ((q.sup or 1) < 0.5 and " |cffff5555?|r" or ""))
        else
            r:Hide()
        end
    end
    f:SetHeight(f._folded and 60 or (64 + show * 18 + 8))
    f:Show()
    recolorPlates()
end

-- ── 事件 ────────────────────────────────────────────────────────────────
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
ev:RegisterEvent("ENCOUNTER_END")

local function onEnterWorld(force)
    local np = resolvePlan()
    if np ~= plan then
        plan, cur, progress = np, 1, 0
        stopSim(); wipe(plates)
    end
    if not plan then if frame then frame:Hide() end; return end
    if GearInsightDB and GearInsightDB.pullNavOff and not force then return end
    local _, _, difficultyID = GetInstanceInfo()
    -- 自动弹：钥石 / M0；普通、追随者本要 /gi nav 手动拉起（不打扰练级）
    if force or difficultyID == 8 or difficultyID == 23 then
        local v = readForces(); if v then progress = v end
        refresh()
    end
end

ev:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        onEnterWorld()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if plan and unit and UnitCanAttack("player", unit) then
            local id = npcIDFromUnit(unit)
            if id then plates[unit] = id; recolorPlates() end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if unit and plates[unit] then plates[unit] = nil; plateMark(unit, nil) end
    elseif event == "SCENARIO_CRITERIA_UPDATE" then
        if plan and not simTimer then
            local v = readForces()
            if v then progress = v; advanceByProgress(); if frame and frame:IsShown() then refresh() end end
        end
    elseif event == "ENCOUNTER_END" then
        local success = select(5, unit, ...)   -- encounterID, name, difficulty, size, success
        if plan and plan.pulls[cur] and plan.pulls[cur].boss and success == 1 and cur < #plan.pulls then
            cur = cur + 1; refresh()
        end
    end
end)

-- ── 命令 ────────────────────────────────────────────────────────────────
function GearInsight:PullNavCmd(arg)
    arg = arg or ""
    if arg == "sim" or arg == "模拟" then
        if not plan then onEnterWorld(true) end
        if not plan then self:Print(T("PN_NO_DATA", "这个副本没有拉怪清单数据（本赛季 8 本才有）。")); return end
        if simTimer then stopSim(); self:Print(T("PN_SIM_OFF", "领航模拟已停止。")) else refresh(); startSim() end
    elseif arg == "next" or arg == "下一包" then if plan and cur < #plan.pulls then cur = cur + 1; refresh() end
    elseif arg == "prev" or arg == "上一包" then if plan and cur > 1 then cur = cur - 1; refresh() end
    elseif arg == "reset" or arg == "复位" then cur = 1; progress = 0; stopSim(); refresh()
    elseif arg == "hide" or arg == "关" then if frame then frame:Hide() end; stopSim()
    elseif arg == "off" then GearInsightDB = GearInsightDB or {}; GearInsightDB.pullNavOff = true; if frame then frame:Hide() end; self:Print(T("PN_OFF", "领航已关闭（/gi nav on 打开）"))
    elseif arg == "on" then GearInsightDB = GearInsightDB or {}; GearInsightDB.pullNavOff = nil; onEnterWorld(true)
    else
        onEnterWorld(true)
        if not plan then self:Print(T("PN_NO_DATA", "这个副本没有拉怪清单数据（本赛季 8 本才有）。")) end
    end
end

if GearInsight._dgBootHooks then
    GearInsight._dgBootHooks[#GearInsight._dgBootHooks + 1] = function() onEnterWorld(false) end
end
