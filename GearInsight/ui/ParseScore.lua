-- ParseScore：战后即时 parse 估分卡。
-- 数据=core/ParseCurve.lua(WCL 标定曲线)；DPS=桥接 Details!/Skada 读你这场实测(12.0 CLEU 已关)。
-- 流程：ENCOUNTER_END(success) → 取 你这场DPS + encId + 难度 → 曲线插值百分位 → 弹卡(WCL配色)+分享。
-- 测试：木桩打一场后 /giparse —— 用当前专精首个有曲线的 boss 模拟弹卡。
local ADDON = ...
GearInsight = GearInsight or {}
-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。
-- ⛔别再写 GetLocale()：每个文件各抄一份就会出现“面板英文、大米攻略中文”这种分裂。
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

-- ── DPS/HPS 桥接(已 POC 验证可用，self CLEU 在 12.0 已关，必须读战斗插件) ──
local ATTR = { DAMAGER = 1, TANK = 1, HEALER = 2 }   -- Details! 属性 1=伤害 2=治疗
local function bridgeAmount(attr)
    local me = UnitName("player")
    if _G.Details and Details.GetCombat then
        for _, seg in ipairs({ 0, 1 }) do
            local ok, combat = pcall(Details.GetCombat, Details, seg)
            if ok and combat then
                local actor
                pcall(function() actor = combat:GetActor(attr, me) end)
                local total = actor and (actor.total or (actor.GetTotal and actor:GetTotal(attr))) or 0
                local ctime = 0
                pcall(function() ctime = combat:GetCombatTime() end)
                if (not ctime or ctime <= 0) then
                    local st, et
                    pcall(function() st = combat:GetStartTime(); et = combat:GetEndTime() end)
                    if st and et and et > st then ctime = et - st end
                end
                if total and total > 0 and ctime and ctime > 0 then
                    return total / ctime, "Details"
                end
            end
        end
    end
    if _G.Skada then
        local set = Skada.current or (Skada.GetSet and Skada:GetSet("current"))
        if set then
            local player
            for _, p in ipairs(set.players or {}) do
                if p.name == UnitName("player") then player = p; break end
            end
            local total = player and (attr == 2 and (player.healing or player.heal) or (player.damage or player.damagedone)) or 0
            local ctime = set.time or 0
            if total > 0 and ctime > 0 then return total / ctime, "Skada" end
        end
    end
    return nil
end

-- ── 当前专精 → 曲线 key ──
local function curveKey()
    local idx = GetSpecialization and GetSpecialization()
    if not idx then return nil end
    local specID = GetSpecializationInfo and GetSpecializationInfo(idx)
    return specID and GearInsightParseCurveSpecKey and GearInsightParseCurveSpecKey[specID], specID
end

local function roleAttr()
    local idx = GetSpecialization and GetSpecialization()
    local role = idx and GetSpecializationRole and GetSpecializationRole(idx) or "DAMAGER"
    return ATTR[role] or 1
end

-- ── DPS + 曲线 → 百分位 ──
local function pctOf(amount, c)
    local p50, p75, p90, p95, p99 = c[50], c[75], c[90], c[95], c[99]
    if not (p50 and p99) then return nil end
    if amount <= p50 then return math.max(1, 50 * amount / p50) end          -- p50 以下线性到 0(无更低锚点)
    local steps = { { 50, p50 }, { 75, p75 }, { 90, p90 }, { 95, p95 }, { 99, p99 } }
    for i = 1, #steps - 1 do
        local pa, da = steps[i][1], steps[i][2]
        local pb, db = steps[i + 1][1], steps[i + 1][2]
        if amount >= da and amount <= db then
            return pa + (amount - da) / math.max(1, db - da) * (pb - pa)
        end
    end
    return math.min(99.9, 99 + (amount - p99) / math.max(1, p99) * 10)        -- p99 以上封顶 99.9
end

-- WCL 配色(灰/绿/蓝/紫/橙/粉/金)
local function tier(p)
    if p >= 100 then return "ffe5cc80", T("PS_T_LEGEND", "传说")
    elseif p >= 99 then return "ffe268a8", T("PS_T_PINK", "粉")
    elseif p >= 95 then return "ffff8000", T("PS_T_ORANGE", "橙")
    elseif p >= 75 then return "ffa335ee", T("PS_T_PURPLE", "紫")
    elseif p >= 50 then return "ff0070ff", T("PS_T_BLUE", "蓝")
    elseif p >= 25 then return "ff1eff00", T("PS_T_GREEN", "绿")
    else return "ff9d9d9d", T("PS_T_GRAY", "灰") end
end

-- 下一档差多少 DPS
local function gapToNext(amount, p, c)
    local nexts = { 50, 75, 90, 95, 99 }
    for _, np in ipairs(nexts) do
        if p < np and c[np] and amount < c[np] then
            return np, c[np] - amount
        end
    end
    return nil
end

-- ── 弹卡 ──
local card
local function showCard(encName, amount, p, src)
    local hex, _tn = tier(p)
    if not card then
        card = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(card, "GearInsightParseCard")
        card:SetSize(300, 78)
        local pos = GearInsightDB and GearInsightDB.parseCardPos
        if pos and pos.point then card:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
        else card:SetPoint("TOP", UIParent, "TOP", 0, -200) end
        card:SetFrameStrata("HIGH")
        card:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        card:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
        card:EnableMouse(true); card:SetMovable(true); card:RegisterForDrag("LeftButton")
        card:SetScript("OnDragStart", function(s) s:StartMoving() end)
        card:SetScript("OnDragStop", function(s)
            s:StopMovingOrSizing()
            local pt, _, _, x, y = s:GetPoint()
            GearInsightDB = GearInsightDB or {}; GearInsightDB.parseCardPos = { point = pt, x = x, y = y }
        end)
        card.line1 = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); card.line1:SetPoint("TOP", 0, -10)
        card.line2 = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); card.line2:SetPoint("TOP", card.line1, "BOTTOM", 0, -5)
        card.share = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        card.share:SetSize(70, 20); card.share:SetPoint("BOTTOMRIGHT", -8, 8); card.share:SetText(T("PS_SHARE", "分享"))
        local cb = CreateFrame("Button", nil, card, "UIPanelCloseButton"); cb:SetPoint("TOPRIGHT", 2, 2)
        cb:SetScript("OnClick", function() card:Hide() end)
    end
    card.line1:SetText((T("PS_LINE1", "|cFFFFD100[%s]|r  你 ≈ |c%sp%d %s|r")):format(encName or "?", hex, math.floor(p + 0.5), _tn))
    local np, gap = gapToNext(amount, p, GearInsight._lastCurve or {})
    if np and gap then
        card.line2:SetText((T("PS_LINE2_GAP", "DPS %s · 距 p%d 还差 ~%s")):format(BreakUpLargeNumbers(math.floor(amount)), np, BreakUpLargeNumbers(math.floor(gap))))
    else
        card.line2:SetText((T("PS_LINE2_SRC", "DPS %s · 数据源 %s")):format(BreakUpLargeNumbers(math.floor(amount)), src or "?"))
    end
    card.share:SetScript("OnClick", function()
        local txt = T("PS_SHARE_TXT", "[GearInsight] %s 我打出 p%d(%s)! DPS %d ——你的呢？")
            :format(encName or "", math.floor(p + 0.5), _tn, math.floor(amount))
        if GearInsight.ShowCopyText then GearInsight:ShowCopyText(txt, T("PS_COPY_HINT", "Ctrl+C 复制分享"), T("PS_COPY_TITLE", "Parse 分享")) end
    end)
    if GearInsight.Skin then GearInsight.Skin.Sweep(card) end
    card:Show()
end

-- ── 评估一场 ──
local function evaluate(encID, encName, difficultyID)
    local key = curveKey()
    local cd = key and GearInsightParseCurve and GearInsightParseCurve[key]
    local enc = cd and cd.raid and cd.raid[encID]
    if not enc then return end                                   -- 该专精/boss 暂无曲线
    local dkey = (difficultyID == 16) and "mythic" or "heroic"   -- 16史诗 15英雄；其余暂归英雄
    local c = enc[dkey] or enc.mythic or enc.heroic
    if not c then return end
    local amount, src = bridgeAmount(roleAttr())
    if not amount then
        GearInsight:Print("|cffff8000[Parse]|r " .. T("PS_NO_DMG", "没读到你的伤害(确认 Details! 开着)。")); return
    end
    GearInsight._lastCurve = c
    local p = pctOf(amount, c)
    if p then showCard(encName, amount, p, src) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ENCOUNTER_END")
f:SetScript("OnEvent", function(_, _, encID, encName, difficultyID, _, success)
    if success ~= 1 then return end
    C_Timer.After(0.4, function() evaluate(encID, encName, difficultyID) end)   -- 等 Details 收尾段
end)

-- 测试命令：用当前专精首个有曲线的 boss 模拟(读你刚才那场 Details! 数据)
SLASH_GIPARSE1 = "/giparse"
SlashCmdList["GIPARSE"] = function()
    local key = curveKey()
    local cd = key and GearInsightParseCurve and GearInsightParseCurve[key]
    if not cd or not cd.raid then GearInsight:Print(T("PS_NO_CURVE", "当前专精暂无 parse 曲线(熊D 已有；其余待全量)。")); return end
    local encID = next(cd.raid)
    evaluate(tonumber(encID), "测试-"..tostring(encID), 16)
end
