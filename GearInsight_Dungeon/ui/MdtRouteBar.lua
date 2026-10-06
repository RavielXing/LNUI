-- ui/MdtRouteBar.lua -- 高手路线领航条（2026-10-01 用户：「要能够钉在战术板视角，战斗中，进本以后一步步查看」「单独的，半透明的」
-- 「做好开关」「默认关闭」「完全融合 · 左边列怪和波次，右边列技能」「默认收起」；属于 0.95.0）。
-- 融合了原来那版「新手 T 拉怪领航」（拉怪清单 + 名牌框）：不再读 MDT 当前路线，全部用 core/MdtRoutes.lua 这一份数据
--   （GearInsightMdtSpecRoutes[专精][副本][第几名] 的每一波：f=计数% / m=怪{序号,只数…} / cd / i / d / l=嗜血；
--    GearInsightMdtMobs[副本][序号] = {NPC 编号, 简中, 英文, 繁中}）—— 和「一键导入 MDT」的那条路线是同一份，波数永远对得上。
-- 每一行 = 一波：左边「第几波 + 计数 + 这一波的怪」，右边「这位高手这一波按的大招 / 打断 / 驱散」。
--   收起（默认）：只显示当前波 + 下一波；「清单」展开：8 行，滚轮翻。
-- 当前第几波：钥石「敌方部队」进度（战斗中照常更新）对照累计 %；首领那波不涨进度，靠 ENCOUNTER_END；< > 手动校正。
-- 名牌框（GearInsightDB.routeBarPlates，默认关）：本波的怪金框、下一波灰框、不在路线里的红框（按 NPC 编号认怪）。
-- ⛔ 副本里拿不到玩家坐标、12.0 起战斗日志对插件关闭 —— 只用进度 / 首领事件 / 名牌。名牌 GUID 是 secret 值或名牌被禁用时静默不标。
-- ⛔ 只读：不碰 MDT、不碰动作条 / 按键；普通 Frame，战斗中改字 / 显隐没问题。
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
local function isSecret(v) return issecretvalue and issecretvalue(v) or false end
local GOLD = { 1, 0.82, 0 }

local bar                      -- 领航条帧
local S = { key = nil, vi = 1, cur = 1, progress = 0, manual = false, off = 0 }
GearInsight._routeBarState = S   -- 门禁测试 / 排查用（只读）

local BAR_W, LEFT_W, RIGHT_X = 640, 292, 312     -- 左栏 = 波次 + 怪；右栏从 RIGHT_X 起 = 技能（10-03「UI 优化下」：合拉一波怪多，左栏放宽）
local ROWS_OPEN = 8

local function db()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.routeBar = GearInsightDB.routeBar or {}
    return GearInsightDB.routeBar
end

local function curSpecID()
    if GearInsight_CurrentSpecID then
        local ok, id = pcall(GearInsight_CurrentSpecID)
        if ok and id and id > 0 then return id end
    end
    local i = GetSpecialization and GetSpecialization()
    return i and GetSpecializationInfo and (GetSpecializationInfo(i)) or nil
end

-- 一次战斗 = 一波（10-03）：同 w 的几组合成一波。路线页（MdtRoute.lua）和领航条共用，序号两边一致
function GearInsight.MdtWaves(e)
    if not (e and e.pulls) then return e end
    if not e._waves then
        local ws, by = {}, {}
        for i, p in ipairs(e.pulls) do
            local key = p.w or ("g" .. i)
            local w = by[key]
            if not w then
                w = { f = 0, m = {}, c = {}, g = {}, cd = nil, i = nil, d = nil, _seen = {} }
                by[key] = w; ws[#ws + 1] = w
            end
            w.g[#w.g + 1] = p
            w.f = w.f + (p.f or 0)
            if p.l then w.l = true end
            for j = 1, #(p.m or {}), 2 do w.m[#w.m + 1] = p.m[j]; w.m[#w.m + 1] = p.m[j + 1] end
            for j = 1, #(p.c or {}) do w.c[#w.c + 1] = p.c[j] end
            -- 社区路线的作者解说（10-04）：nt = 文字，np = 地图坐标 { x, y, … }
            for _, t in ipairs(p.nt or {}) do w.nt = w.nt or {}; w.nt[#w.nt + 1] = t end
            for j = 1, #(p.np or {}) do w.np = w.np or {}; w.np[#w.np + 1] = p.np[j] end
            for _, k in ipairs({ "cd", "i", "d" }) do
                for _, id in ipairs(p[k] or {}) do
                    if not w._seen[k .. id] then w._seen[k .. id] = true; w[k] = w[k] or {}; w[k][#w[k] + 1] = id end
                end
            end
        end
        for _, w in ipairs(ws) do w._seen = nil end
        e._waves = setmetatable({ pulls = ws }, { __index = e })
    end
    return e._waves
end

local function entry()
    local sid = curSpecID()
    local l
    if S.src == "mid" then   -- +12 常规路线（10-03）：不分专精
        l = S.key and GearInsightMdtMidRoutes and GearInsightMdtMidRoutes[S.key]
    elseif S.src == "comm" then  -- 社区经典（10-04）
        l = S.key and GearInsightMdtCommunityRoutes and GearInsightMdtCommunityRoutes[S.key]
    elseif S.src == "s12" then   -- 本专精 +12 档前 2（10-03「对齐高手层」）
        l = GearInsight.MdtSpecList and GearInsight.MdtSpecList("s12", sid, S.key)
            or (sid and GearInsightMdtSpecRoutes12 and GearInsightMdtSpecRoutes12[sid] and S.key and GearInsightMdtSpecRoutes12[sid][S.key])
    else
        l = GearInsight.MdtSpecList and GearInsight.MdtSpecList("spec", sid, S.key)
            or (sid and GearInsightMdtSpecRoutes and GearInsightMdtSpecRoutes[sid] and S.key and GearInsightMdtSpecRoutes[sid][S.key])
    end
    if not l then return nil end
    local e = l[S.vi] or l[1]
    -- 日志拆不清（gateFail）→ 换社区经典第一条（和路线页同一口径）
    S.fallback = nil
    if e and e.gateFail and (S.src == "spec" or S.src == "s12") then
        local c = GearInsightMdtCommunityRoutes and S.key and GearInsightMdtCommunityRoutes[S.key]
        if c and c[1] then e = c[1]; S.fallback = true end
    end
    if not (e and e.pulls and #e.pulls > 0) then return nil end
    -- 10-03 用户「不能分析清楚合波的情况吗」「一次战斗算一波」「用一个序号」：
    --   数据按「组」存（MDT 串 / 网站 / 小程序要用），每组带 w = 日志里第几次战斗；这里把同一次战斗的几组合成一波，
    --   领航条、地图、语音、播报、对账全按波走，只有一个序号。g = 这一波按走位顺序路过的几组（地图连线用）。
    --   旧数据没有 w：一组一波。
    return GearInsight.MdtWaves(e)
end

local function dungeonName(key)
    for _, d in ipairs(GearInsightMdtRouteOrder or {}) do
        if d.key == key then return (_LOCALE == "zhCN" and d.cn) or (_LOCALE == "zhTW" and d.tw) or d.en end
    end
    return "?"
end

-- 这一波的怪：「名字×只数」串、总只数、NPC 编号集合
local function mobsOf(p)
    local tbl = GearInsightMdtMobs and GearInsightMdtMobs[S.key] or {}
    local parts, total, ids = {}, 0, {}
    local order, cnt = {}, {}      -- 同名不同编号（密谋小径两种「诱惑的萨亚德」）按名字合并只数（10-03）
    local m = p and p.m or {}
    for i = 1, #m, 2 do
        local rec, n = tbl[m[i]], m[i + 1] or 1
        total = total + n
        local name = rec and ((_LOCALE == "zhCN" and rec[2]) or (_LOCALE == "zhTW" and rec[4]) or rec[3]) or ("#" .. tostring(m[i]))
        if not cnt[name] then order[#order + 1] = name; cnt[name] = 0 end
        cnt[name] = cnt[name] + n
        if rec and rec[1] and rec[1] > 0 then ids[rec[1]] = true end
        if rec then for j = 2, 4 do if rec[j] and rec[j] ~= "" then ids["n:" .. rec[j]] = true end end end
    end
    for _, name in ipairs(order) do parts[#parts + 1] = name .. (cnt[name] > 1 and ("×" .. cnt[name]) or "") end
    return table.concat(parts, "  "), total, ids, parts
end

local function readForces()
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

-- 进度 → 当前波：第一波累计 % 还没达到的那一波（留 0.3% 余量：路线计数和实际拉的怪会有出入）
local function pullForProgress(e, pct)
    local acc = 0
    for i, p in ipairs(e.pulls) do
        acc = acc + (p.f or 0)
        if acc > pct + 0.3 then return i end
    end
    return #e.pulls
end

-- ── 名牌框（从原来的拉怪领航并过来；默认关）────────────────────────────────
local plates = {}               -- 名牌 unit → NPC 编号
-- ⛔⛔ 10-03 实测（密谋小径 追随者，脱战）：12.0 起副本里名牌单位的 GUID **和名字**都是 secret 值，插件认不出名牌是哪种怪 →
--   这个功能在副本里不可能工作。用户定：去掉选项（MdtRoute.lua 不再显示勾），代码保留；暴雪放开后把下面改成 true 即可。
--   诊断：/gi plates。门禁测试 gi_route_plates_test.py 把它临时打开测逻辑。
GearInsight._routePlatesEnabled = GearInsight._routePlatesEnabled or false
local function platesOn() return GearInsight._routePlatesEnabled and (GearInsightDB and GearInsightDB.routeBarPlates) and true or false end
-- 名字 → NPC 编号（本副本 GearInsightMdtMobs 的简中 / 英文 / 繁中三种名字都认）
local nameIdx = { key = nil, map = {} }
local function idByName(name)
    if not name or name == "" then return nil end
    if nameIdx.key ~= S.key then
        nameIdx.key, nameIdx.map = S.key, {}
        for _, rec in pairs(GearInsightMdtMobs and GearInsightMdtMobs[S.key] or {}) do
            if rec[1] and rec[1] > 0 then
                for j = 2, 4 do if rec[j] and rec[j] ~= "" and not nameIdx.map[rec[j]] then nameIdx.map[rec[j]] = rec[1] end end
            end
        end
    end
    return nameIdx.map[name]
end
-- ⛔ 10-03 实测（密谋小径 追随者）：副本里名牌单位的 GUID 是 secret 值 → 读不到 NPC 编号，一个框都标不上。
--   编号读不到就按名牌上的名字认（同名不同 NPC 在一个副本里极少；认错最多是框的颜色偏一波）
local function npcIDFromUnit(unit)
    local guid = UnitGUID(unit)
    if guid and not isSecret(guid) then
        local id = select(6, strsplit("-", guid))
        if id and tonumber(id) then return tonumber(id) end
    end
    local name = UnitName(unit)
    if name and not isSecret(name) and idByName(name) then return "n:" .. name end   -- 只认本副本路线里有的名字
    return nil
end
local function plateMark(unit, kind)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, np = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not np then return end           -- 副本里名牌被禁用 / 拿不到：静默不标
    local m = np._giPullMark
    if not m then
        if not kind then return end
        m = CreateFrame("Frame", nil, np, "BackdropTemplate")
        m:SetFrameLevel((np:GetFrameLevel() or 0) + 5)
        m:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        np._giPullMark = m
    end
    if not kind then m:Hide(); return end
    -- 名牌美化插件（Plater 等）把暴雪的 UnitFrame 藏起来、自己画在 np.unitFrame 上：框要挂在看得见的那根血条上
    local uf = (np.unitFrame and np.unitFrame:IsShown() and np.unitFrame) or np.UnitFrame
    local hb = uf and (uf.healthBar or uf.HealthBar) or uf
    if hb and hb.IsVisible and not hb:IsVisible() then hb = nil end
    m:ClearAllPoints()
    if hb then m:SetPoint("TOPLEFT", hb, "TOPLEFT", -2, 2); m:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 2, -2)
    else m:SetPoint("CENTER", np, "CENTER"); m:SetSize(120, 14) end
    if kind == "cur" then m:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    elseif kind == "next" then m:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    else m:SetBackdropBorderColor(1, 0.25, 0.25, 0.9) end
    m:Show()
end
-- 已经在屏幕上的名牌补登记（10-03 用户测「没看到框」：plates 只在 NAME_PLATE_UNIT_ADDED 时、且开关已开才记，
--   先出名牌后勾选 / 先进本后钉条，眼前这批怪永远不进表）→ 打开开关、钉条、进本时扫一遍现有名牌
local function scanPlates()
    if not (platesOn() and C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, np in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = np.namePlateUnitToken or (np.UnitFrame and np.UnitFrame.unit)
        if unit and UnitCanAttack and UnitCanAttack("player", unit) then
            local id = npcIDFromUnit(unit)
            if id then plates[unit] = id end
        end
    end
end
local function recolorPlates()
    if next(plates) == nil then scanPlates() end
    local e = entry()
    local on = platesOn() and bar and bar:IsShown() and e
    local curSet = on and select(3, mobsOf(e.pulls[S.cur])) or {}
    local nextSet = on and select(3, mobsOf(e.pulls[S.cur + 1])) or {}
    for unit, id in pairs(plates) do
        if not on then plateMark(unit, nil)
        elseif curSet[id] then plateMark(unit, "cur")
        elseif nextSet[id] then plateMark(unit, "next")
        else plateMark(unit, "other") end
    end
end

-- ── 行 / 技能块 ─────────────────────────────────────────────────────────
local chipN, lblN, rowN = 0, 0, 0
local function getChip()
    chipN = chipN + 1
    local c = bar.chips[chipN]
    if not c then
        c = CreateFrame("Button", nil, bar)
        c:SetHeight(18)
        c.ic = c:CreateTexture(nil, "ARTWORK"); c.ic:SetSize(16, 16); c.ic:SetPoint("LEFT", 0, 0)
        c.tx = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.tx:SetPoint("LEFT", c.ic, "RIGHT", 3, 0)
        c:SetScript("OnEnter", function(s)
            if s._id and GameTooltip.SetSpellByID then GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetSpellByID(s._id); GameTooltip:Show() end
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bar.chips[chipN] = c
    end
    c:EnableMouse(not db().locked)
    return c
end
local function getLabel()
    lblN = lblN + 1
    local l = bar.lbls[lblN]
    if not l then l = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bar.lbls[lblN] = l end
    l:ClearAllPoints(); l:SetWidth(0); l:SetWordWrap(true); l:SetJustifyH("LEFT")   -- 设了宽度的怪名行默认会居中
    return l
end
local function getRowBg()
    rowN = rowN + 1
    local t = bar.rowbg[rowN]
    if not t then t = bar:CreateTexture(nil, "BACKGROUND", nil, 1); bar.rowbg[rowN] = t end
    return t
end
-- 一串技能在右栏从 (x0, y) 开始排，整块换行；返回最后一行的 y
local function flow(ids, x0, y)
    local n, order = {}, {}
    for _, id in ipairs(ids or {}) do
        if not n[id] then n[id] = 0; order[#order + 1] = id end
        n[id] = n[id] + 1
    end
    local x = x0
    for _, id in ipairs(order) do
        local c = getChip()
        c._id = id
        local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("#" .. id)
        c.ic:SetTexture((C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400)
        c.tx:SetText(name .. (n[id] > 1 and (" ×" .. n[id]) or ""))
        local w = 19 + ((c.tx.GetStringWidth and c.tx:GetStringWidth()) or 0) + 10
        if x + w > BAR_W - 10 and x > x0 then x = x0; y = y - 20 end
        c:SetWidth(w); c:ClearAllPoints(); c:SetPoint("TOPLEFT", bar, "TOPLEFT", x, y); c:Show()
        x = x + w
    end
    return y
end

-- 怪名整个换行（10-03 截图「凶邪的法 / 师×9」：中文按字折行会把名字劈开）：按条目量宽度手动断行
local function wrapEntries(list, width, sep)
    local meas = bar.meas
    if type(meas) ~= "table" then meas = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); meas:Hide(); bar.meas = meas end
    local lines, cur = {}, nil
    for _, it in ipairs(list) do
        local try = cur and (cur .. sep .. it) or it
        meas:SetText(try)
        if cur and ((meas.GetStringWidth and meas:GetStringWidth()) or 0) > width then
            lines[#lines + 1] = cur; cur = it
        else cur = try end
    end
    if cur then lines[#lines + 1] = cur end
    return table.concat(lines, "\n")
end

-- 作者解说一条（10-04 用户「解说要进插件，放在合适美观的地方」）：
--   作者常写成「全大写小标题 + 换行 + 正文」→ 小标题金色、正文米色；不是本波的整体压暗
local NOTE_ICON = "|TInterface\\Icons\\INV_Misc_Note_01:13:13:0:-1:64:64:5:59:5:59|t "
function GearInsight.MdtNoteText(s, bright)
    s = tostring(s or ""):gsub("%s+$", "")
    local hd, body = s:match("^([^\n]+)\n(.+)$")
    local cH, cB = bright and "|cFFFFD27A" or "|cFF9C8A66", bright and "|cFFEDE3CC" or "|cFF8E887C"
    if hd then return NOTE_ICON .. cH .. hd .. "|r  " .. cB .. (body:gsub("\n", " ")) .. "|r" end
    return NOTE_ICON .. cB .. s .. "|r"
end

-- 画一波：返回这一行用掉之后的 y
local function drawRow(e, i, y, isCur)
    local p = e.pulls[i]
    local y0 = y
    -- 左栏：第几波 + 计数 + 嗜血 / 这一波的怪
    local head = getLabel()
    head:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, y - 2)
    local mobs, total, _, parts = mobsOf(p)
    -- 10-01 用户「除了相对进度，还要绝对进度」：+本波 % 之外再给打完这一波后的累计 %（= 钥石界面上该到的数）
    local acc = 0
    for k = 1, i do acc = acc + (e.pulls[k].f or 0) end
    -- 「绝对进度放到最前特殊标记」「放在相对进度旁边不显眼」：打完这波的累计 % 放行首，亮绿色 [xx.x%]；本波 +x% 灰字跟在后面
    -- 第一行：累计 % · 第几波 · 本波 %；第二行：连拉几组 · 几只 · 嗜血（旧版挤一行，「嗜血」压到右栏）
    head:SetText((isCur and "|cFF33FF66" or "|cFF55CC77") .. string.format("[%.1f%%]", acc) .. "|r  "
        .. (isCur and "|cFFFFD100" or "|cFFBBBBBB") .. string.format(T("RB_ROW", "第 %d 波"), i) .. "|r"
        .. "  |cFF888888+" .. string.format("%.1f%%", p.f or 0) .. "|r")
    head:Show()
    local tags = {}
    if p.g and #p.g > 1 then tags[#tags + 1] = "|cFFFF9F40" .. string.format(T("RB_CHAIN", "连拉 %d 组"), #p.g) .. "|r" end
    if total > 0 then tags[#tags + 1] = "|cFF999999" .. string.format(T("RB_MOBS_N", "%d 只"), total) .. "|r" end
    if p.l then tags[#tags + 1] = "|cFFFF7F3F" .. T("MR_LUST", "嗜血") .. "|r" end
    local my = y - 18
    if #tags > 0 then
        local tg = getLabel()
        tg:SetPoint("TOPLEFT", bar, "TOPLEFT", 22, my); tg:SetText(table.concat(tags, "  |cFF555555·|r  ")); tg:Show()
        my = my - 16
    end
    local mob = getLabel()
    mob:SetPoint("TOPLEFT", bar, "TOPLEFT", 22, my); mob:SetWidth(LEFT_W - 22); mob:SetWordWrap(true)
    local txt = (parts and #parts > 0) and wrapEntries(parts, LEFT_W - 26, "  ") or T("RB_NO_MOBS", "（首领 / 无计数怪）")
    mob:SetText((isCur and "|cFFFFFFFF" or "|cFF9A9A9A") .. txt .. "|r")
    mob:Show()
    local leftBottom = my - ((mob.GetStringHeight and mob:GetStringHeight()) or 14)
    -- 右栏：大招 / 打断 / 驱散
    local ry = y
    local any = false
    for _, row in ipairs({ { p.cd, "MR_EV_CD", "大招" }, { p.i, "MR_EV_INT", "打断" }, { p.d, "MR_EV_DISP", "驱散" } }) do
        if row[1] then
            any = true
            local l = getLabel()
            l:SetPoint("TOPLEFT", bar, "TOPLEFT", RIGHT_X, ry - 3)
            l:SetText("|cFF9FD0FF" .. T(row[2], row[3]) .. "|r"); l:Show()
            ry = flow(row[1], RIGHT_X + 34, ry) - 20
        end
    end
    -- 社区路线：右栏本来空着（作者路线没有个人技能）→ 放作者在这一段写的提醒
    if e.community and p.nt then
        for _, t in ipairs(p.nt) do
            local l = getLabel()
            l:SetPoint("TOPLEFT", bar, "TOPLEFT", RIGHT_X, ry - 1); l:SetWidth(BAR_W - RIGHT_X - 12)
            l:SetSpacing(2)
            l:SetText(GearInsight.MdtNoteText(t, isCur)); l:Show()
            ry = ry - ((l.GetStringHeight and l:GetStringHeight()) or 14) - 6
        end
    elseif e.community and isCur then
        local l = getLabel()
        l:SetPoint("TOPLEFT", bar, "TOPLEFT", RIGHT_X, ry - 3)
        l:SetText("|cFF666666" .. T("RB_NOTE_NONE", "这一段作者没写提醒") .. "|r"); l:Show()
        ry = ry - 20
    end
    if not any and not e.mid and not e.noSpells and not e.community then   -- 统计路线没有个人技能，不放「他没开大招」
        local l = getLabel()
        l:SetPoint("TOPLEFT", bar, "TOPLEFT", RIGHT_X, ry - 3)
        l:SetText("|cFF777777" .. T("RB_NOTHING", "这一波他没开大招") .. "|r"); l:Show()
        ry = ry - 20
    end
    local bottom = math.min(leftBottom, ry) - 4
    if isCur then
        local bg = getRowBg()
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", bar, "TOPLEFT", 4, y0 + 1); bg:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -4, bottom + 1)
        bg:SetColorTexture(1, 0.82, 0, 0.10); bg:Show()
    end
    return bottom
end

-- ════════════════════════════════════════════════════════════════════════
-- 10-03「指导玩家拉哪些怪」（名牌框在副本里认不出怪 → 改成「画出来 / 说出来 / 告诉队友」，用户：「全部实现」）：
--   ① 小地图：借 MDT 自带的地图贴图（装了 MDT 才有），本波金点、下一波灰点、箭头连过去
--   ② 方位文字：本波在上一波（第 1 波 = 入口）的哪个方向、多远、靠近哪个首领
--   ③ 3D 头像：本波每种怪的模型
--   ④ 语音：换波时念「第几波、几只什么、在哪」（游戏自带文字转语音，默认关）
--   ⑤ 小队播报：点「播报」把这一波发到小队 / 副本频道（必须手点：插件不能自动发言）
--   ⑥ 进度对账（只有大秘境有敌方部队进度）：打完首领比路线少就提示可能漏了哪一波
-- 数据：GearInsightMdtMap[副本] = { tex, poi = {x,y,类型…}, boss = {x,y,序号…}, c = {[序号] = {第几只,x,y,…}} }；每波 p.c = {序号,第几只,…}
-- ════════════════════════════════════════════════════════════════════════
local MAP_W, MAP_H = 840, 560
local function mapOf() return GearInsightMdtMap and GearInsightMdtMap[S.key] end
local function clonePos(md, idx, k)
    local t = md and md.c and md.c[idx]
    if not t then return nil end
    for j = 1, #t, 3 do if t[j] == k then return t[j + 1], t[j + 2] end end
end
-- 这一波每只怪的坐标 + 中心点
local function pullPoints(md, p)
    local pts, sx, sy = {}, 0, 0
    local c = p and p.c or {}
    for j = 1, #c, 2 do
        local x, y = clonePos(md, c[j], c[j + 1])
        if x then pts[#pts + 1] = { x, y }; sx = sx + x; sy = sy + y end
    end
    if #pts == 0 then return pts, nil, nil end
    return pts, sx / #pts, sy / #pts
end
-- 一波的起点 / 终点（合拉时 = 第一组 / 最后一组；地图连线、方位文字用）
local function startOf(p) return p and p.g and p.g[1] or p end
local function endOf(p) return p and p.g and p.g[#p.g] or p end
local DIR8 = { "RB_DIR_E", "右方", "RB_DIR_NE", "右上方", "RB_DIR_N", "上方", "RB_DIR_NW", "左上方",
               "RB_DIR_W", "左方", "RB_DIR_SW", "左下方", "RB_DIR_S", "下方", "RB_DIR_SE", "右下方" }
-- 方位文字：「（地图上）在上一波的右上方 · 较远 · 靠近首领 XX」；第 1 波以入口为起点
local function dirText(e, i)
    local md = mapOf()
    if not md then return nil end
    local _, cx, cy = pullPoints(md, startOf(e.pulls[i]))
    if not cx then return nil end
    local px, py, from
    for k = i - 1, 1, -1 do
        local _, x, y = pullPoints(md, endOf(e.pulls[k]))
        if x then px, py, from = x, y, T("RB_FROM_PREV", "上一波"); break end
    end
    if not px and md.poi and md.poi[1] then px, py, from = md.poi[1], md.poi[2], T("RB_FROM_ENTRANCE", "入口") end
    local parts = {}
    if px then
        local dx, dy = cx - px, py - cy                       -- 地图 y 往下为正 → 上方 = dy > 0
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 15 then
            parts[#parts + 1] = string.format(T("RB_DIR_SAME", "就在%s旁边"), from)
        else
            local a = math.deg(math.atan2(dy, dx)) % 360
            local s = math.floor((a + 22.5) / 45) % 8
            parts[#parts + 1] = string.format(T("RB_DIR_FMT", "在%s的%s"), from, T(DIR8[s * 2 + 1], DIR8[s * 2 + 2]))
            parts[#parts + 1] = d < 45 and T("RB_DIST_NEAR", "很近") or d < 110 and T("RB_DIST_MID", "不远") or T("RB_DIST_FAR", "较远")
        end
    end
    -- 靠近哪个首领（地图上 70 以内）
    local best, bd
    for j = 1, #(md.boss or {}), 3 do
        local dx, dy = md.boss[j] - cx, md.boss[j + 1] - cy
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 70 and (not bd or d < bd) then best, bd = md.boss[j + 2], d end
    end
    if best then
        local rec = GearInsightMdtMobs and GearInsightMdtMobs[S.key] and GearInsightMdtMobs[S.key][best]
        local nm = rec and ((_LOCALE == "zhCN" and rec[2]) or (_LOCALE == "zhTW" and rec[4]) or rec[3])
        if nm and nm ~= "" then parts[#parts + 1] = string.format(T("RB_NEAR_BOSS", "靠近首领「%s」"), nm) end
    end
    return #parts > 0 and table.concat(parts, " · ") or nil
end

local function mdtTextures()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MythicDungeonTools") or false
end
-- 10-03 用户「展示 UI 需要优化」「小地图和大地图对不上」：
--   旧版放大到 3 倍只剩一个角落、名字截成「诱惑的…」、看不出在哪。现在：
--   · 视野最多放大 1.8 倍并带上入口 / 首领标记，能和大地图对上；点地图切「全图」（整本路线编号）
--   · 头像下名字两行不截断，只数做成角标；点头像 = 选中 + 打团队标记（每种怪一个固定标记，头像左上角同款图标）
local VIEW_W, VIEW_H, SLOT_W, MODEL_S = 360, 220, 72, 46
local MARKS = { 8, 7, 6, 5, 4 }          -- 第 1~5 种怪：骷髅 / 叉 / 方块 / 月亮 / 三角
local function markTex(i) return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i end
local mapFrame
local function buildMap()
    if mapFrame then return mapFrame end
    local m = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    m:SetSize(VIEW_W + 12, VIEW_H + MODEL_S + 82)
    m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    m:SetBackdropColor(0.03, 0.03, 0.06, 0.85); m:SetBackdropBorderColor(1, 0.82, 0, 0.45)
    m:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
    m:EnableMouseWheel(true)
    m:SetScript("OnMouseWheel", function(_, d) GearInsight:RouteBarStep(-d) end)   -- 地图 / 头像上滚轮也翻波
    m.hd = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.hd:SetPoint("TOPLEFT", 8, -7); m.hd:SetJustifyH("LEFT")
    m.sub = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    m.sub:SetPoint("TOPRIGHT", -8, -9); m.sub:SetJustifyH("RIGHT")
    -- 头像：本波每种怪一格（底框 + 3D 模型 + 只数角标 + 团队标记 + 两行名字）
    m.models = {}
    for i = 1, 5 do
        local slot = CreateFrame("Frame", nil, m)
        slot:SetSize(SLOT_W - 4, MODEL_S + 30)
        slot:SetPoint("TOPLEFT", 6 + (i - 1) * SLOT_W, -26)
        local ring = slot:CreateTexture(nil, "BACKGROUND")
        ring:SetTexture("Interface\\Buttons\\WHITE8x8"); ring:SetVertexColor(1, 0.82, 0, 0.18)
        ring:SetSize(MODEL_S + 4, MODEL_S + 4); ring:SetPoint("TOP", 0, 0)
        local md = CreateFrame("PlayerModel", nil, slot)
        md:SetSize(MODEL_S, MODEL_S); md:SetPoint("TOP", 0, -2)
        md.slot, md.ring = slot, ring
        md.cnt = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        md.cnt:SetPoint("BOTTOMRIGHT", md, "BOTTOMRIGHT", 2, 0)
        md.mark = slot:CreateTexture(nil, "OVERLAY")
        md.mark:SetSize(16, 16); md.mark:SetPoint("TOPLEFT", md, "TOPLEFT", -3, 3)
        md.lbl = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        md.lbl:SetPoint("TOP", md, "BOTTOM", 0, -2); md.lbl:SetWidth(SLOT_W - 2)
        md.lbl:SetJustifyH("CENTER"); md.lbl:SetWordWrap(true); md.lbl:SetMaxLines(2)
        md:EnableMouse(true)
        md:SetScript("OnEnter", function(s)
            if not s._name then return end
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:AddLine(s._name, 1, 0.82, 0)
            GameTooltip:AddLine(string.format(T("RB_MOB_TT", "本波 %d 只 · 对照模型找眼前的怪"), s._n or 1), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        md:SetScript("OnLeave", function() GameTooltip:Hide() end)
        m.models[i] = md
    end
    -- 地图：ScrollFrame 裁出一块；画布 = 840×560 的 MDT 地图按比例缩放
    local sf = CreateFrame("ScrollFrame", nil, m)
    sf:SetSize(VIEW_W, VIEW_H); sf:SetPoint("TOPLEFT", 6, -(MODEL_S + 62))
    local cv = CreateFrame("Frame", nil, sf)
    cv:SetSize(MAP_W, MAP_H); sf:SetScrollChild(cv)
    m.sf, m.cv, m.tiles, m.dots, m.nums, m.bossT, m.paths = sf, cv, {}, {}, {}, {}, {}
    for i = 1, 10 do
        for j = 1, 15 do
            m.tiles[(i - 1) * 15 + j] = cv:CreateTexture(nil, "BACKGROUND")
        end
    end
    m.line = cv:CreateLine(nil, "OVERLAY"); m.line:SetThickness(2); m.line:SetColorTexture(1, 0.82, 0, 0.8)
    m.ent = cv:CreateTexture(nil, "OVERLAY"); m.ent:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"); m.ent:SetVertexColor(0.2, 1, 0.3, 1)
    m.entL = cv:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall"); m.entL:SetText(T("RB_FROM_ENTRANCE", "入口"))
    -- 点地图：本波附近 ⇄ 全图
    sf:EnableMouse(true)
    sf:SetScript("OnMouseUp", function() S.mapFull = not S.mapFull; if GearInsight._routeRefresh then GearInsight._routeRefresh() end end)
    sf:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(T("RB_MAP_TT", "点击切换：本波附近 / 整本路线"), 1, 0.82, 0)
        GameTooltip:AddLine(T("RB_MAP_TT2", "这张图和大地图（M 键）是同一套地图，北在上；右上角小地图跟着人物转向、只画脚下一小块，所以看起来不一样"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    sf:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m.legend = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    m.legend:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 2, -4); m.legend:SetJustifyH("LEFT")
    m.legend:SetText("|cFFFFD100●|r " .. T("RB_LG_CUR", "本波") .. "   |cFFAAAAAA●|r " .. T("RB_LG_NEXT", "下一波") ..
        "   |cFFFF4040◆|r " .. T("RB_LG_BOSS", "首领") .. "   |cFF33FF4D●|r " .. T("RB_FROM_ENTRANCE", "入口") ..
        "   |cFF888888" .. T("RB_LG_CLICK", "点地图看全图") .. "|r")
    m.noMdt = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    m.noMdt:SetPoint("CENTER", sf, "CENTER"); m.noMdt:SetWidth(VIEW_W - 20)
    m.noMdt:SetText(T("RB_MAP_NEED_MDT", "小地图借用 Mythic Dungeon Tools 的地图图片：装上 MDT 后这里显示本波位置"))
    mapFrame = m
    return m
end
local function mapDot(m, n, x, y, scale, r, g, b, size)
    local d = m.dots[n]
    if not d then
        d = m.cv:CreateTexture(nil, "OVERLAY")
        d:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        m.dots[n] = d
    end
    d:SetSize(size, size); d:ClearAllPoints()
    d:SetPoint("CENTER", m.cv, "TOPLEFT", x * scale, -y * scale)
    d:SetVertexColor(r, g, b, 1); d:Show()
end
local function mapNum(m, n, x, y, scale, txt, hi, alpha)
    local f = m.nums[n]
    if not f then f = m.cv:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); m.nums[n] = f end
    f:ClearAllPoints(); f:SetPoint("CENTER", m.cv, "TOPLEFT", x * scale, -y * scale)
    f:SetText(txt)
    if hi then f:SetTextColor(1, 0.82, 0) else f:SetTextColor(0.9, 0.9, 0.9) end
    f:SetAlpha(alpha or 1); f:Show()
end
-- 点头像 = 选中附近这种怪 + 打团队标记（10-03 用户「点击以后可以直接选中附近的目标」「能不能自动标记」）：
--   插件不能自己 TargetUnit，也认不出副本里的怪（12.0 名字 / GUID 保密），只能让玩家点「安全按钮」执行宏：
--   /targetexact 怪名 → /tm 标记（和手打宏一样；单人或队长 / 助理才打得上，没权限时游戏自己忽略）。
--   ⛔ 安全按钮在战斗中不能改属性 / 显隐 / 位置：父级挂 UIParent，只在脱战时更新；战斗中换波 → PLAYER_REGEN_ENABLED 再套。
local targetBtns, pendingTargets = {}, nil
local function applyTargets(list)
    if InCombatLockdown and InCombatLockdown() then pendingTargets = list; return end
    pendingTargets = nil
    local mark = GearInsight:RouteBarOpt("mark")
    for i = 1, 5 do
        local b = targetBtns[i]
        local t = list and list[i]
        if t and t.anchor then
            if not b then
                b = CreateFrame("Button", "GearInsightRouteTarget" .. i, UIParent, "SecureActionButtonTemplate")
                b:RegisterForClicks("AnyUp", "AnyDown")
                b:SetAttribute("type", "macro")
                b:SetFrameStrata("HIGH")
                b:SetScript("OnEnter", function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_TOP")
                    GameTooltip:AddLine(s._name or "", 1, 0.82, 0)
                    GameTooltip:AddLine(string.format(T("RB_MOB_TT", "本波 %d 只 · 对照模型找眼前的怪"), s._n or 1), 1, 1, 1, true)
                    GameTooltip:AddLine(s._mark and T("RB_TARGET_MARK_TT", "点击 = 选中附近的这种怪并打上左上角的标记（连点在同名几只之间切换）")
                        or T("RB_TARGET_TT", "点击 = 选中附近的这种怪（连点在同名几只之间切换）"), 0.5, 1, 0.5, true)
                    GameTooltip:Show()
                end)
                b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                targetBtns[i] = b
            end
            b._name, b._n, b._mark = t.name, t.n, mark and MARKS[i] or nil
            b:SetAttribute("macrotext", "/targetexact " .. t.name .. (mark and ("\n/tm " .. MARKS[i]) or ""))
            b:ClearAllPoints(); b:SetAllPoints(t.anchor)
            b:Show()
        elseif b then
            b:Hide()
        end
    end
end
GearInsight._routeApplyTargets = applyTargets

local function updateMap(e)
    if not bar then return end
    local on = db().mapOn ~= false and e ~= nil
    if not on then if mapFrame then mapFrame:Hide() end; applyTargets(nil); return end
    local m = buildMap()
    m:Show()
    local md = mapOf()
    local p, pn = e.pulls[S.cur], e.pulls[S.cur + 1]
    -- 头像：本波每种怪（按只数多到少，最多 5 种）
    local tbl = GearInsightMdtMobs and GearInsightMdtMobs[S.key] or {}
    local mm = p and p.m or {}
    local kinds, byName = {}, {}
    for j = 1, #mm, 2 do
        local rec = tbl[mm[j]]
        if rec and rec[1] and rec[1] > 0 then
            local nm = (_LOCALE == "zhCN" and rec[2]) or (_LOCALE == "zhTW" and rec[4]) or rec[3] or ""
            if byName[nm] then byName[nm].n = byName[nm].n + (mm[j + 1] or 1)
            else byName[nm] = { id = rec[1], nm = nm, n = mm[j + 1] or 1 }; kinds[#kinds + 1] = byName[nm] end
        end
    end
    local mark = GearInsight:RouteBarOpt("mark")
    local shown = 0
    for i = 1, #m.models do
        local mdl, k = m.models[i], kinds[i]
        if k then
            shown = shown + 1
            mdl.slot:Show(); mdl:Show(); pcall(mdl.SetCreature, mdl, k.id); pcall(mdl.SetPortraitZoom, mdl, 0.6)
            mdl.lbl:SetText(k.nm); mdl.lbl:Show()
            mdl.cnt:SetText(k.n > 1 and ("×" .. k.n) or "")
            mdl.mark:SetTexture(markTex(MARKS[i])); mdl.mark:SetShown(mark and true or false)
            mdl._name, mdl._n = k.nm, k.n
        else mdl.slot:Hide(); mdl:Hide(); mdl.lbl:Hide() end
    end
    local tl = {}
    for i = 1, shown do tl[i] = { name = kinds[i].nm, n = kinds[i].n, anchor = m.models[i] } end
    applyTargets(tl)
    m.hd:SetText(string.format(T("RB_MAP_HD2", "第 %d 波 · 本波的怪"), S.cur) .. (shown == 0 and ("  |cFF888888" .. T("RB_NO_MOBS", "（首领 / 无计数怪）") .. "|r") or ""))
    m.sub:SetText(shown > 0 and (mark and T("RB_SUB_MARK", "点头像 = 选中 + 标记") or T("RB_SUB_TARGET", "点头像 = 选中")) or "")
    -- 地图
    local hasTex = md and md.tex and mdtTextures()
    m.noMdt:SetShown(not hasTex)
    for _, t in ipairs(m.tiles) do t:SetShown(hasTex and true or false) end
    for _, d in ipairs(m.dots) do d:Hide() end
    for _, f in ipairs(m.nums) do f:Hide() end
    for _, t in ipairs(m.bossT) do t:Hide() end
    if type(m.noteT) ~= "table" then m.noteT = {} end
    for _, t in ipairs(m.noteT) do t:Hide() end
    m.line:Hide(); m.ent:Hide(); m.entL:Hide()
    for _, l in ipairs(m.paths) do l:Hide() end
    if not (md and p) then return end
    local cur, cx, cy = pullPoints(md, p)
    local nxt, nx, ny = pullPoints(md, pn)
    local x0, y0, x1, y1, scale
    if S.mapFull or not cx then
        x0, y0, x1, y1 = 0, 0, MAP_W, MAP_H
        scale = math.min(VIEW_W / MAP_W, VIEW_H / MAP_H)
    else
        -- 视野：本波 + 下一波的外框，四周留 70，最多放大 1.8 倍（旧版 3 倍只剩一个角落，认不出在地图哪儿）
        x0, y0, x1, y1 = cx, cy, cx, cy
        for _, q in ipairs(cur) do x0, y0, x1, y1 = math.min(x0, q[1]), math.min(y0, q[2]), math.max(x1, q[1]), math.max(y1, q[2]) end
        for _, q in ipairs(nxt) do x0, y0, x1, y1 = math.min(x0, q[1]), math.min(y0, q[2]), math.max(x1, q[1]), math.max(y1, q[2]) end
        x0, y0, x1, y1 = x0 - 70, y0 - 70, x1 + 70, y1 + 70
        scale = math.min(VIEW_W / (x1 - x0), VIEW_H / (y1 - y0), 1.8)
        scale = math.max(scale, VIEW_W / MAP_W, VIEW_H / MAP_H)
    end
    m.cv:SetSize(MAP_W * scale, MAP_H * scale)
    if hasTex then
        local path = "Interface\\AddOns\\MythicDungeonTools\\Midnight\\Textures\\" .. md.tex .. "\\1_"
        local ts = MAP_W * scale / 15
        for i = 1, 10 do
            for j = 1, 15 do
                local n = (i - 1) * 15 + j
                local t = m.tiles[n]
                t:SetTexture(path .. n .. ".png"); t:SetSize(ts, ts)
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", m.cv, "TOPLEFT", (j - 1) * ts, -(i - 1) * ts)
            end
        end
    end
    local mx, my = (x0 + x1) / 2 * scale - VIEW_W / 2, (y0 + y1) / 2 * scale - VIEW_H / 2
    mx = math.max(0, math.min(mx, MAP_W * scale - VIEW_W)); my = math.max(0, math.min(my, MAP_H * scale - VIEW_H))
    m.sf:SetHorizontalScroll(mx); m.sf:SetVerticalScroll(my)
    -- 入口 / 首领
    if md.poi and md.poi[1] then
        m.ent:SetSize(9, 9); m.ent:ClearAllPoints(); m.ent:SetPoint("CENTER", m.cv, "TOPLEFT", md.poi[1] * scale, -md.poi[2] * scale); m.ent:Show()
        m.entL:ClearAllPoints(); m.entL:SetPoint("BOTTOM", m.ent, "TOP", 0, 1); m.entL:Show()
    end
    for j = 1, #(md.boss or {}), 3 do
        local k = (j + 2) / 3
        local t = m.bossT[k]
        if not t then
            t = m.cv:CreateTexture(nil, "OVERLAY"); t:SetTexture("Interface\\Buttons\\WHITE8x8")
            t:SetVertexColor(1, 0.25, 0.25, 0.95); pcall(t.SetRotation, t, math.rad(45)); m.bossT[k] = t
        end
        t:SetSize(7, 7); t:ClearAllPoints(); t:SetPoint("CENTER", m.cv, "TOPLEFT", md.boss[j] * scale, -md.boss[j + 1] * scale); t:Show()
    end
    local n, nn = 0, 0
    if S.mapFull then
        -- 全图：每一波一个编号（本波金色），打过的淡掉
        for i, q in ipairs(e.pulls) do
            local _, qx, qy = pullPoints(md, startOf(q))
            if qx then
                nn = nn + 1
                if i == S.cur then n = n + 1; mapDot(m, n, qx, qy, scale, 1, 0.82, 0, 12) end
                mapNum(m, nn, qx, qy, scale, tostring(i), i == S.cur, i < S.cur and 0.35 or 1)
            end
        end
        return
    end
    for _, q in ipairs(nxt) do n = n + 1; mapDot(m, n, q[1], q[2], scale, 0.7, 0.7, 0.7, 6) end
    for _, q in ipairs(cur) do n = n + 1; mapDot(m, n, q[1], q[2], scale, 1, 0.82, 0, 8) end
    -- 作者解说的位置（社区路线，本波）：便签图标，鼠标指上去看原文
    local np = p.np or {}
    for k = 1, math.max(#m.noteT, #np / 2) do
        local t = m.noteT[k]
        local x, y = np[k * 2 - 1], np[k * 2]
        if x then
            if not t then
                t = CreateFrame("Frame", nil, m.cv); t:SetSize(14, 14); t:EnableMouse(true)
                t.ic = t:CreateTexture(nil, "OVERLAY"); t.ic:SetAllPoints(); t.ic:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
                t.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                t:SetScript("OnEnter", function(f)
                    GameTooltip:SetOwner(f, "ANCHOR_RIGHT"); GameTooltip:AddLine(T("RB_COL_RIGHT_NOTE", "作者在这一段的提醒"), 1, 0.82, 0)
                    GameTooltip:AddLine((f._t or ""), 1, 1, 1, true); GameTooltip:Show()
                end)
                t:SetScript("OnLeave", function() GameTooltip:Hide() end)
                m.noteT[k] = t
            end
            t._t = p.nt and p.nt[k]
            t:ClearAllPoints(); t:SetPoint("CENTER", m.cv, "TOPLEFT", x * scale, -y * scale); t:Show()
        elseif t then t:Hide() end
    end
    -- 连线：本波合拉的几组按走位顺序金线相连；本波终点 → 下一波起点灰线
    local ln = 0
    local function seg(ax, ay, bx, by, r, g, b, a)
        ln = ln + 1
        local l = m.paths[ln]
        if not l then l = m.cv:CreateLine(nil, "OVERLAY"); l:SetThickness(2); m.paths[ln] = l end
        l:SetColorTexture(r, g, b, a)
        l:SetStartPoint("TOPLEFT", m.cv, ax * scale, -ay * scale)
        l:SetEndPoint("TOPLEFT", m.cv, bx * scale, -by * scale)
        l:Show()
    end
    local gs = p.g or { p }
    local px, py
    for _, gp in ipairs(gs) do
        local _, gx, gy = pullPoints(md, gp)
        if gx then
            if px then seg(px, py, gx, gy, 1, 0.82, 0, 0.9) end
            px, py = gx, gy
        end
    end
    local sx, sy = select(2, pullPoints(md, startOf(p)))
    if pn then
        local _, ax, ay = pullPoints(md, startOf(pn))
        if px and ax then seg(px, py, ax, ay, 0.75, 0.75, 0.75, 0.6) end
        if ax then nn = nn + 1; mapNum(m, nn, ax, ay - 10 / scale, scale, tostring(S.cur + 1), false) end
    end
    if sx then nn = nn + 1; mapNum(m, nn, sx, sy - 12 / scale, scale, tostring(S.cur), true) end
end

-- 一句话描述这一波（语音 / 小队播报共用）
local function waveSentence(e, i, forChat)
    local p = e and e.pulls[i]
    if not p then return nil end
    local tbl = GearInsightMdtMobs and GearInsightMdtMobs[S.key] or {}
    local mm, parts, order, cnt = p.m or {}, {}, {}, {}
    for j = 1, #mm, 2 do
        local rec = tbl[mm[j]]
        local nm = rec and ((_LOCALE == "zhCN" and rec[2]) or (_LOCALE == "zhTW" and rec[4]) or rec[3])
        if nm and nm ~= "" then
            if not cnt[nm] then order[#order + 1] = nm; cnt[nm] = 0 end
            cnt[nm] = cnt[nm] + (mm[j + 1] or 1)
        end
    end
    for _, nm in ipairs(order) do parts[#parts + 1] = forChat and (nm .. "×" .. cnt[nm]) or (cnt[nm] .. T("RB_TTS_UNIT", "只") .. nm) end
    local s = string.format(T("RB_ROW", "第 %d 波"), i)
        .. ((p.g and #p.g > 1) and ((forChat and " " or "，") .. string.format(T("RB_CHAIN", "连拉 %d 组"), #p.g)) or "")
        .. (forChat and "：" or "，") .. (#parts > 0 and table.concat(parts, forChat and "、" or "，") or T("RB_TTS_BOSS", "首领"))
    local dt = dirText(e, i)
    if dt then s = s .. (forChat and ("（" .. dt .. "）") or ("。" .. dt)) end
    return s
end

local function speak(text)
    if not (text and C_VoiceChat and C_VoiceChat.SpeakText) then return end
    local voice
    if TextToSpeech_GetSelectedVoice and Enum and Enum.TtsVoiceType then
        local v = TextToSpeech_GetSelectedVoice(Enum.TtsVoiceType.Standard); voice = v and v.voiceID
    end
    if not voice and C_VoiceChat.GetTtsVoices then
        local vs = C_VoiceChat.GetTtsVoices(); voice = vs and vs[1] and vs[1].voiceID
    end
    if not voice then return end
    if C_VoiceChat.StopSpeakingText then pcall(C_VoiceChat.StopSpeakingText) end
    -- 11.x / 12.x 参数表换过：先试新的（voice, text, rate, volume, overlap），不行再试旧的（带 destination）
    local ok = pcall(C_VoiceChat.SpeakText, voice, text, 0, 100, false)
    if not ok and Enum and Enum.VoiceTtsDestination then
        pcall(C_VoiceChat.SpeakText, voice, text, Enum.VoiceTtsDestination.LocalPlayback, 0, 100)
    end
end
GearInsight._routeSpeak = speak   -- 测试用

-- 小队播报：必须玩家点按钮（硬件事件）才发；没有队伍就只在自己聊天框打印
local function broadcast()
    local e = entry()
    local s = waveSentence(e, S.cur, true)
    if not s then return end
    s = "[GI] " .. s
    local ch = (IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT")
        or (IsInGroup and IsInGroup() and "PARTY") or nil
    local ok = ch and SendChatMessage and pcall(SendChatMessage, s, ch)
    if not ok then GearInsight:Print(s .. (ch and ("  |cFF888888" .. T("RB_BC_BLOCKED", "（游戏没让发到频道，只显示给你自己）") .. "|r") or "")) end
end
GearInsight._routeBroadcast = broadcast

-- 进度对账（大秘境）：打完首领时，实际进度比路线到这一波之前的累计少多少；对得上某一波的计数就点名
local function checkDeficit(e, bossPull)
    if not (e and S.progress and S.progress > 0) then return end
    local acc = 0
    for k = 1, bossPull do acc = acc + (e.pulls[k].f or 0) end
    local gap = acc - S.progress
    if gap < 0.8 then S.deficit = nil; return end
    local guess
    for k = bossPull, 1, -1 do
        local f = e.pulls[k].f or 0
        if f > 0 and math.abs(f - gap) <= 0.4 then guess = k; break end
    end
    S.deficit = string.format(T("RB_DEFICIT", "比路线少 %.1f%%"), gap)
        .. (guess and string.format(T("RB_DEFICIT_GUESS", "，可能漏了第 %d 波（+%.1f%%）"), guess, e.pulls[guess].f) or "")
    GearInsight:Print("|cFFFF7F3F" .. S.deficit .. "|r")
end
GearInsight._routeCheckDeficit = checkDeficit
GearInsight._routeGuide = { dirText = dirText, waveSentence = waveSentence, pullPoints = pullPoints, mapOf = mapOf }   -- 门禁测试用

local function refresh()
    if not (bar and bar:IsShown()) then return end
    chipN, lblN, rowN = 0, 0, 0
    local e = entry()
    local y = -30
    if not e then
        bar.title:SetText(dungeonName(S.key))
        bar.pos:SetText("")
        local l = getLabel()
        l:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, y)
        l:SetText(S.src == "mid" and T("RB_NO_MID", "这个副本暂时没有 +12 常规路线") or T("RB_NO_DATA", "这个副本暂时没有你这个专精的前 2 名路线")); l:Show()
        y = y - 22
    else
        local n = #e.pulls
        S.cur = math.max(1, math.min(S.cur, n))
        if e.community then
            bar.title:SetText(dungeonName(S.key) .. " · " .. string.format(T("RB_COMM_TITLE", "社区经典 · %s"), e.author or "?")
                .. (S.fallback and ("  |cFFFF9F40" .. T("RB_FALLBACK", "（日志拆不清，已换）") .. "|r") or ""))
        elseif e.mid then
            bar.title:SetText(dungeonName(S.key) .. " · " .. string.format(T("RB_MID_TITLE", "+12 常规路线 %d"), e.pos or S.vi))
        else
            bar.title:SetText(dungeonName(S.key) .. " · " .. (S.src == "s12" and "+12 " or "") .. "#" .. (e.rank or S.vi) .. " " .. (e.player or ""))
        end
        bar.pos:SetText(string.format(T("RB_POS", "第 |cFFFFD100%d|r / %d 波  %.1f%%"), S.cur, n, S.progress or 0))
        -- 栏头
        local h1 = getLabel(); h1:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, y); h1:SetText("|cFF777777" .. T("RB_COL_LEFT", "波次 · 怪") .. "|r"); h1:Show()
        local h2 = getLabel(); h2:SetPoint("TOPLEFT", bar, "TOPLEFT", RIGHT_X, y); h2:SetText("|cFF777777" .. (e.community and T("RB_COL_RIGHT_NOTE", "作者在这一段的提醒") or e.mid and T("RB_COL_RIGHT_MID", "统计路线：没有个人技能") or e.noSpells and T("RB_COL_RIGHT_NS", "每波技能和第 2–10 名：见网站 / 小程序") or T("RB_COL_RIGHT", "这位高手这一波按了什么")) .. "|r"); h2:Show()
        y = y - 16
        -- ② 方位：本波在哪（10-03）
        local dt = dirText(e, S.cur)
        if dt then
            local l = getLabel(); l:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, y); l:SetWidth(BAR_W - 20)
            l:SetText("|cFF9FD0FF" .. T("RB_WHERE", "本波位置") .. "|r  " .. dt); l:Show()
            y = y - ((l.GetStringHeight and l:GetStringHeight()) or 14) - 4
        end
        -- ⑥ 漏怪提醒（大秘境，打完首领对账）
        if S.deficit then
            local l = getLabel(); l:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, y); l:SetWidth(BAR_W - 20)
            l:SetText("|cFFFF7F3F" .. S.deficit .. "|r"); l:Show()
            y = y - ((l.GetStringHeight and l:GetStringHeight()) or 14) - 4
        end
        -- ④ 语音：换到新的一波念一次
        if db().tts and S.spoken ~= (S.key or "") .. ":" .. S.cur then
            S.spoken = (S.key or "") .. ":" .. S.cur
            speak(waveSentence(e, S.cur, false))
        end
        local first, last
        if db().open then
            first = math.max(1, math.min(S.cur - 1 + S.off, n - ROWS_OPEN + 1))
            last = math.min(n, first + ROWS_OPEN - 1)
        else
            first, last = S.cur, math.min(n, S.cur + 1)       -- 收起（默认）：当前波 + 下一波
        end
        for i = first, last do y = drawRow(e, i, y, i == S.cur) - 4 end
        if S.cur >= n and not db().open then
            local l = getLabel(); l:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, y - 2); l:SetText("|cFF888888" .. T("RB_LAST", "最后一波") .. "|r"); l:Show()
            y = y - 20
        end
    end
    for i = chipN + 1, #bar.chips do bar.chips[i]:Hide() end
    for i = lblN + 1, #bar.lbls do bar.lbls[i]:Hide() end
    for i = rowN + 1, #bar.rowbg do bar.rowbg[i]:Hide() end
    bar.listBtn:SetText(db().open and T("RB_LIST_CLOSE", "收起") or T("RB_LIST_OPEN", "清单"))
    bar:SetHeight(math.max(84, -y + 30))      -- 高度跟内容走，底边留给按钮
    updateMap(e)                               -- ① + ③ 小地图 / 头像
    recolorPlates()
end
GearInsight._routeRefresh = refresh

-- 设置面板（10-03 用户「快捷键设置直接做进 gi 插件」「找个地方加按钮可以设置，锁定以后隐藏」）：
--   领航条右下「设置」→ 小面板：三个快捷键（点一下再按键就绑上，右键清除）+ 各项开关。锁定后按钮隐藏（解锁再出来）。
--   绑键用游戏自己的 SetBinding + SaveBindings，和「按键设置 → 插件 → GearInsight」是同一份，两边改哪边都行。
--   ⛔ SetBinding 战斗中不能调：战斗中点了只提示。
local BIND_ROWS = {
    { "GEARINSIGHT_ROUTE_NEXT", "BIND_ROUTE_NEXT_S", "下一波" },
    { "GEARINSIGHT_ROUTE_PREV", "BIND_ROUTE_PREV_S", "上一波" },
    { "GEARINSIGHT_ROUTE_TOGGLE", "BIND_ROUTE_TOGGLE_S", "显示 / 隐藏领航条" },
}
local OPT_ROWS = {
    { "autoStep", "RB_OPT_AUTOSTEP", "打完一波脱战自动翻下一波（大秘境按进度翻）" },
    { "mapOn", "MR_OPT_MAP", "小地图 + 怪物头像" },
    { "mark", "MR_OPT_MARK", "点头像打标记" },
    { "tts", "MR_OPT_TTS", "语音播报" },
}
local setPanel
local function keyText(cmd)
    local k1, k2 = GetBindingKey and GetBindingKey(cmd)
    if not k1 then return "|cFF888888" .. T("RB_KEY_NONE", "未设置") .. "|r" end
    local t = GetBindingText and GetBindingText(k1) or k1
    if k2 then t = t .. " / " .. (GetBindingText and GetBindingText(k2) or k2) end
    return t
end
local function syncSetPanel()
    if not setPanel then return end
    for _, r in ipairs(setPanel.keys) do
        r.btn:SetText(setPanel.capture == r.cmd and ("|cFFFFD100" .. T("RB_KEY_PRESS", "按下按键…（Esc 取消）") .. "|r") or keyText(r.cmd))
    end
    for _, c in ipairs(setPanel.cbs) do
        c:SetChecked(c.key == "auto" and GearInsight:RouteBarAuto() or (c.key ~= "auto" and GearInsight:RouteBarOpt(c.key)))
    end
end
local MODS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, LMETA = 1, RMETA = 1, UNKNOWN = 1 }
local function bindKey(cmd, key)
    if InCombatLockdown and InCombatLockdown() then GearInsight:Print(T("RB_KEY_COMBAT", "战斗中不能改快捷键，脱战再设")); return end
    local k1, k2 = GetBindingKey(cmd)
    if k1 then SetBinding(k1) end
    if k2 then SetBinding(k2) end
    if key then SetBinding(key, cmd) end
    SaveBindings(GetCurrentBindingSet())
end
local function buildSetPanel()
    if setPanel then return setPanel end
    local f = CreateFrame("Frame", "GearInsightRouteBarSettings", UIParent, "BackdropTemplate")
    f:SetSize(330, 76 + #BIND_ROWS * 24 + #OPT_ROWS * 24 + 20)
    f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0.04, 0.04, 0.08, 0.95); f:SetBackdropBorderColor(1, 0.82, 0, 0.6)
    f:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
    f:EnableMouse(true)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(22, 22); close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)
    local y = -10
    local function head(text)
        local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 12, y); h:SetText(text); y = y - 22
    end
    head(T("RB_SET_KEYS", "快捷键（点按钮再按键；右键清除）"))
    f.keys = {}
    for _, r in ipairs(BIND_ROWS) do
        local l = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 16, y - 4); l:SetText(T(r[2], r[3]))
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(170, 20); b:SetPoint("TOPRIGHT", -12, y)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local cmd = r[1]
        b:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then bindKey(cmd, nil); f.capture = nil
            else f.capture = (f.capture ~= cmd) and cmd or nil end
            f:EnableKeyboard(f.capture ~= nil)
            syncSetPanel()
        end)
        f.keys[#f.keys + 1] = { cmd = cmd, btn = b }
        y = y - 24
    end
    f:SetScript("OnKeyDown", function(s, key)
        if not s.capture then s:SetPropagateKeyboardInput(true); return end
        s:SetPropagateKeyboardInput(false)
        if key == "ESCAPE" then s.capture = nil; s:EnableKeyboard(false); syncSetPanel(); return end
        if MODS[key] then return end                          -- 只按了修饰键：等真正的键
        local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
        bindKey(s.capture, combo)
        s.capture = nil; s:EnableKeyboard(false); syncSetPanel()
    end)
    y = y - 6
    head(T("RB_SET_OPTS", "领航条"))
    f.cbs = {}
    local rows = { { "auto", "MR_AUTO", "进大秘境自动显示" } }
    for _, r in ipairs(OPT_ROWS) do rows[#rows + 1] = r end
    for _, r in ipairs(rows) do
        local c = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        c:SetSize(22, 22); c:SetPoint("TOPLEFT", 12, y + 2)
        c.text:SetText(T(r[2], r[3])); c.text:SetFontObject("GameFontHighlightSmall")
        c.key = r[1]
        c:SetScript("OnClick", function(b)
            if b.key == "auto" then GearInsight:RouteBarAuto(b:GetChecked()) else GearInsight:RouteBarOpt(b.key, b:GetChecked()) end
            if GearInsight._routeBarHook then GearInsight._routeBarHook() end
        end)
        f.cbs[#f.cbs + 1] = c
        y = y - 24
    end
    f:SetHeight(-y + 12)
    f:SetScript("OnShow", syncSetPanel)
    f:SetScript("OnHide", function(s) s.capture = nil; s:EnableKeyboard(false) end)
    f:Hide()
    setPanel = f
    return f
end
GearInsight._routeSettings = function() return buildSetPanel(), syncSetPanel end   -- 测试用

local function applyLock()
    if not bar then return end
    local locked = db().locked
    bar:EnableMouse(not locked)
    bar:EnableMouseWheel(not locked)
    for _, c in ipairs(bar.chips or {}) do c:EnableMouse(not locked) end
    bar.lockBtn:SetText(locked and T("RB_UNLOCK", "解锁") or T("RB_LOCK", "锁定"))
    if bar.setBtn then bar.setBtn:SetShown(not locked) end            -- 锁定后「设置」隐藏
    if locked and setPanel then setPanel:Hide() end
end

local function build()
    if bar then return bar end
    local f = CreateFrame("Frame", "GearInsightRouteBar", UIParent, "BackdropTemplate")
    f:SetSize(BAR_W, 132)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    f:SetBackdropColor(0.03, 0.03, 0.06, 0.55)          -- 半透明（用户「半透明的」）
    f:SetBackdropBorderColor(1, 0.82, 0, 0.35)
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) if not db().locked then s:StartMoving() end end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local p, _, rp, x, y = s:GetPoint()
        db().pos = { p, rp, x, y }
    end)
    -- 滚轮（10-03 用户「滚动波次，有没有办法快捷操作」）：收起时滚轮直接翻波（往下滚 = 下一波）；展开清单时翻清单
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, d)
        if db().open then S.off = S.off - d; refresh() else GearInsight:RouteBarStep(-d) end
    end)
    local pos = db().pos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", UIParent, "TOP", 0, -180) end
    f.chips, f.lbls, f.rowbg = {}, {}, {}
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -9); f.title:SetPoint("RIGHT", f, "RIGHT", -340, 0); f.title:SetJustifyH("LEFT"); f.title:SetWordWrap(false)
    f.pos = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.pos:SetPoint("TOPRIGHT", -196, -9)       -- 右边 5 个按钮（播报 < > 清单 ×）
    local function mk(text, w, anchorTo, onClick, tip)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 18)
        if anchorTo then b:SetPoint("RIGHT", anchorTo, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", -30, -6) end
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        if tip then
            b:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(tip, 1, 1, 1, 1, true); GameTooltip:Show() end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        return b
    end
    f.listBtn = mk(T("RB_LIST_OPEN", "清单"), 44, nil, function() db().open = not db().open; S.off = 0; refresh() end,
        T("RB_LIST_TT", "展开 / 收起整条路线（展开后滚轮翻）"))
    local nextB = mk(">", 22, f.listBtn, function() S.cur = S.cur + 1; S.manual = true; S.off = 0; refresh() end, T("RB_NEXT_TT2", "下一波\n快捷：鼠标停在条上滚轮 / 按键设置 → 插件 → GearInsight 绑键 / 宏 /gi next\n追随者、普通、英雄：打完一波脱战自动翻；大秘境：按钥石进度自动翻"))
    local prevB = mk("<", 22, nextB, function() S.cur = math.max(1, S.cur - 1); S.manual = true; S.off = 0; refresh() end, T("RB_PREV_TT2", "上一波\n快捷：滚轮往上 / 绑键 / 宏 /gi prev"))
    -- ⑤ 小队播报（10-03）：把这一波「几只什么、在哪」发到小队 / 副本频道
    mk(T("RB_BC", "播报"), 44, prevB, function() broadcast() end,
        T("RB_BC_TT", "把这一波要拉的怪和位置发到小队频道（追随者 / 单人时只显示给你自己）"))
    f.lockBtn = mk("", 44, nil, function() db().locked = not db().locked; applyLock() end, T("RB_LOCK_TT", "锁定位置（锁定后鼠标穿透，不挡视角）"))
    f.lockBtn:ClearAllPoints(); f.lockBtn:SetPoint("BOTTOMRIGHT", -8, 6)
    f.setBtn = mk(T("RB_SET", "设置"), 44, nil, function() local p = buildSetPanel(); p:SetShown(not p:IsShown()) end,
        T("RB_SET_TT", "快捷键和领航条开关（锁定后这个按钮隐藏）"))
    f.setBtn:ClearAllPoints(); f.setBtn:SetPoint("RIGHT", f.lockBtn, "LEFT", -4, 0)
    local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    cb:SetSize(22, 22); cb:SetPoint("TOPRIGHT", -2, -2)
    cb:SetScript("OnClick", function() GearInsight:HideRouteBar() end)
    bar = f
    applyLock()
    return f
end

-- 对外：钉到屏幕 / 关闭 / 是否显示 / 开关
function GearInsight:ShowRouteBar(key, vi, src)
    S.key, S.vi = key or S.key, vi or S.vi or 1
    local d = db()
    S.src = src or S.src or d.src or "spec"
    d.key, d.vi, d.shown, d.src = S.key, S.vi, true, S.src
    build():Show()
    local v = readForces()
    if v then S.progress = v; local e = entry(); if e then S.cur = pullForProgress(e, v) end else S.cur = S.cur or 1 end
    S.off = 0
    refresh()
end
function GearInsight:HideRouteBar()
    db().shown = false
    applyTargets(nil)
    if bar then bar:Hide() end
    if setPanel then setPanel:Hide() end
    recolorPlates()
    if self._routeBarHook then self._routeBarHook() end   -- 页签按钮文字跟着变
end
function GearInsight:RouteBarShown() return bar ~= nil and bar:IsShown() end
-- 快捷键（GearInsight/Bindings.xml → GearInsight:RouteBarKey）：上一波 / 下一波，和条上的 < > 一样（手动校正，进度再变化时自动对齐）
function GearInsight:RouteBarStep(d)
    if not (bar and bar:IsShown()) then return end
    S.cur = math.max(1, S.cur + (d or 0)); S.manual = true; S.off = 0
    refresh()
end
function GearInsight:RouteBarAuto(on)
    if on ~= nil then GearInsightDB = GearInsightDB or {}; GearInsightDB.routeBarAuto = on and true or nil end
    return (GearInsightDB and GearInsightDB.routeBarAuto) and true or false
end
-- 领航条选项（10-03）：mapOn = 小地图 + 头像（默认开），tts = 换波语音（默认关）。on == nil 只读
function GearInsight:RouteBarOpt(name, on)
    local d = db()
    if on ~= nil then
        if name == "mapOn" or name == "mark" or name == "autoStep" then d[name] = on and true or false else d[name] = on and true or nil end
        if name == "tts" and on then S.spoken = nil end
        refresh()
    end
    if name == "mapOn" or name == "mark" or name == "autoStep" then return d[name] ~= false end   -- 默认开
    return d[name] and true or false
end

-- /gi plates：名牌框诊断。选中一只怪再输入，一次打印「为什么没框」需要的全部信息
function GearInsight:RouteBarPlateDebug()
    local P = function(...) self:Print("|cFFFFD100[名牌框]|r " .. table.concat({ ... }, " ")) end
    local e = entry()
    P("开关:", tostring(platesOn()), "领航条:", tostring(bar ~= nil and bar:IsShown()), "路线:", tostring(S.key), "第", tostring(S.cur), "波", "数据:", tostring(e ~= nil))
    local n = 0; for _ in pairs(plates) do n = n + 1 end
    local all = (C_NamePlate and C_NamePlate.GetNamePlates and #C_NamePlate.GetNamePlates()) or -1
    P("已登记名牌:", n, "屏幕上名牌:", all)
    local g = UnitGUID("target")
    if not g then P("没有目标：先选中一只怪"); return end
    local sec = isSecret(g)
    P("目标 GUID 保密:", tostring(sec), "可攻击:", tostring(UnitCanAttack and UnitCanAttack("player", "target")))
    local nm = UnitName("target")
    local nmSec = isSecret(nm)
    P("目标名字保密:", tostring(nmSec), nmSec and "" or ("名字: " .. tostring(nm) .. " → 按名字认: " .. tostring(idByName(nm))))
    local id = npcIDFromUnit("target")
    P("目标 NPC 编号:", tostring(id))
    if e and id then
        local cur = select(3, mobsOf(e.pulls[S.cur])) or {}
        local nxt = select(3, mobsOf(e.pulls[S.cur + 1])) or {}
        P("本波有它:", tostring(cur[id] == true or cur[id] ~= nil), "下一波有它:", tostring(nxt[id] ~= nil))
    end
    local np = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    P("目标名牌:", tostring(np ~= nil), "UnitFrame:", tostring(np and np.UnitFrame ~= nil), "显示:", tostring(np and np.UnitFrame and np.UnitFrame:IsShown()),
        "unitFrame:", tostring(np and np.unitFrame ~= nil), "框:", tostring(np and np._giPullMark ~= nil and np._giPullMark:IsShown()))
    local addons = {}
    for _, a in ipairs({ "Plater", "Kui_Nameplates", "TidyPlates_ThreatPlates", "Platynator", "ElvUI", "NeatPlates" }) do
        if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(a) then addons[#addons + 1] = a end
    end
    P("名牌插件:", #addons > 0 and table.concat(addons, ",") or "无")
end

function GearInsight:RouteBarPlates(on)
    if on ~= nil then GearInsightDB = GearInsightDB or {}; GearInsightDB.routeBarPlates = on and true or nil; recolorPlates() end
    return platesOn()
end

-- 当前所在副本对应的路线键
local function keyForInstance()
    local name = GetInstanceInfo and select(1, GetInstanceInfo())
    if not name then return nil end
    for _, d in ipairs(GearInsightMdtRouteOrder or {}) do
        if name == d.cn or name == d.tw or name == d.en then return d.key end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CHALLENGE_MODE_START")
ev:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
ev:RegisterEvent("ENCOUNTER_END")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("ENCOUNTER_START")
-- 脱战自动翻波（10-03「一次战斗算一波」→ 打完一次战斗 = 这一波结束）：只在副本里、没有钥石进度时（大秘境按进度翻）；
--   战斗不到 6 秒（摸了一下又脱）、人死了（团灭重来）、这次战斗是打首领（ENCOUNTER_END 自己会翻）都不翻
local combatAt, encInCombat
local function autoStepOnCombatEnd()
    if not (bar and bar:IsShown()) or not GearInsight:RouteBarOpt("autoStep") then return end
    if not (IsInInstance and IsInInstance()) or readForces() then return end
    if encInCombat or not combatAt or (GetTime() - combatAt) < 6 then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    local e = entry()
    if e and e.pulls[S.cur + 1] then S.cur = S.cur + 1; S.off = 0; refresh() end
end
GearInsight._routeAutoStep = autoStepOnCombatEnd
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "CHALLENGE_MODE_START" then
        wipe(plates); S.deficit = nil; S.spoken = nil
        local k = keyForInstance()
        local d = db()
        local _, _, diff = GetInstanceInfo()
        local keystone = (event == "CHALLENGE_MODE_START") or diff == 8
        if k and keystone and GearInsight:RouteBarAuto() then
            S.manual, S.cur, S.progress = false, 1, 0
            GearInsight:ShowRouteBar(k, d.vi or 1)            -- 开了「进大秘境自动显示」（默认关）
        elseif k and d.shown then
            S.manual, S.cur, S.progress = false, 1, 0
            GearInsight:ShowRouteBar(k, d.vi or 1)            -- 钉着的条跟着进本，换成这个副本
        elseif d.shown and d.key and not bar then
            GearInsight:ShowRouteBar(d.key, d.vi or 1)        -- /reload 后恢复（城里预习用）
        end
    elseif event == "SCENARIO_CRITERIA_UPDATE" then
        if not (bar and bar:IsShown()) then return end
        local v = readForces()
        if v and v ~= S.progress then
            S.progress = v
            local e = entry()
            if e then S.cur = pullForProgress(e, v); S.manual = false; S.off = 0 end
            refresh()
        end
    elseif event == "ENCOUNTER_END" then
        if not (bar and bar:IsShown()) then return end
        local success = select(5, ...)
        local e = entry()
        local p = e and e.pulls[S.cur]
        -- 首领那波不涨进度：打赢了、且当前波本身几乎不加进度 → 往后翻一波
        if success == 1 and readForces() then checkDeficit(e, S.cur) end   -- ⑥ 大秘境：打完首领对一次账
        if success == 1 and p and (p.f or 0) < 0.5 and e.pulls[S.cur + 1] then S.cur = S.cur + 1; S.off = 0; refresh() end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if unit and platesOn() and UnitCanAttack and UnitCanAttack("player", unit) then
            local id = npcIDFromUnit(unit)
            if id then plates[unit] = id; recolorPlates() end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        combatAt, encInCombat = GetTime(), false
    elseif event == "ENCOUNTER_START" then
        encInCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        autoStepOnCombatEnd(); combatAt = nil
        if pendingTargets ~= nil or (bar and not bar:IsShown()) then applyTargets(bar and bar:IsShown() and pendingTargets or nil) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if unit and plates[unit] then plates[unit] = nil; plateMark(unit, nil) end
    end
end)
