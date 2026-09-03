-- 大秘境情报面板：每周强势职业榜（与网站 /wow/en/mplus-meta、周更视频同一份数据）。
-- 数据 core/MplusMeta.lua（_mp_site_export.py 生成）。GearInsight:ToggleMplusMeta() 打开。
GearInsight = GearInsight or {}
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

local PANEL_W, PANEL_H = 480, 560
local f

local EN2TAG = { ["Death Knight"] = "DEATHKNIGHT", ["Demon Hunter"] = "DEMONHUNTER",
    Druid = "DRUID", Evoker = "EVOKER", Hunter = "HUNTER", Mage = "MAGE", Monk = "MONK",
    Paladin = "PALADIN", Priest = "PRIEST", Rogue = "ROGUE", Shaman = "SHAMAN",
    Warlock = "WARLOCK", Warrior = "WARRIOR" }

-- 职业小图标（图集稳定可得；专精图标要逐 specID 反查，成本高收益小）
local function classMark(r, size)
    size = size or 14
    local tag = EN2TAG[r.cls or ""] or (r.cls or ""):upper():gsub(" ", "")
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[tag]
    if c then
        return ("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:%d:%d:0:0:256:256:%d:%d:%d:%d|t ")
            :format(size, size, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
    end
    return ""
end

local function classColor(r)
    local tag = EN2TAG[r.cls or ""] or ""
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[tag]
    if c then return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
end

local _ZH = (_LOCALE == "zhCN" or _LOCALE == "zhTW")

-- ⛔ 行名原来恒取 r.cn（中文口语名），英文客户端也是一屏中文。
--   数据里 cls/spec 本来就是英文（"Warlock"/"Demonology"），直接拼。
local function rowName(r)
    if _ZH then return r.cn or ((r.spec or "") .. " " .. (r.cls or "")) end
    local sp, cl = r.spec or "", r.cls or ""
    if sp == "" then return cl end
    return sp .. " " .. cl
end

local function classRGB(r)
    local tag = EN2TAG[r.cls or ""] or ""
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[tag]
    if c then return c.r, c.g, c.b end
    return 0.8, 0.8, 0.8
end

local function drText(dr, isNew)
    if isNew then return " |cffd6b26c(" .. T("MM_NEW", "新") .. ")|r" end
    if not dr or dr == 0 then return "" end
    if dr > 0 then return (" |cff5bd88a+%d|r"):format(dr) end
    return (" |cfff08a8a%d|r"):format(dr)
end

-- 中文按「万」，英文等按 K/M —— ⛔「万」在英文客户端是个天书单位
local function wan(v)
    v = v or 0
    if _ZH then return ("%.1f%s"):format(v / 10000, T("MM_WAN", "万")) end
    if v >= 1000000 then return ("%.2fM"):format(v / 1000000) end
    if v >= 1000 then return ("%.1fK"):format(v / 1000) end
    return ("%.0f"):format(v)
end

local function build()
    local M = GearInsight.MplusMeta
    f = CreateFrame("Frame", "GearInsightMplusMeta", UIParent, "BackdropTemplate")
    f:SetSize(PANEL_W, PANEL_H)
    f:SetPoint("CENTER", 120, 20)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24,
                    insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    f:SetBackdropColor(0.05, 0.06, 0.09, 0.96)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    -- ⛔ 标题与副标题都不许写死单行：期号+日期+同源说明拼起来中文就顶满 480 宽，
    --    英文更长。给宽度让它自动换行，换了行就把下面的内容整体下移。
    local function lineCount(fs)
        local n = fs.GetNumLines and fs:GetNumLines() or 0
        if n and n >= 1 then return n end
        local _, fh = fs:GetFont()
        local sh = fs:GetStringHeight() or 0
        if fh and fh > 0 then return math.max(1, math.floor(sh / fh + 0.5)) end
        return 1
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetWidth(PANEL_W - 40)
    title:SetJustifyH("CENTER")
    if title.SetWordWrap then title:SetWordWrap(true) end
    title:SetText("|cffd6b26c" .. T("MM_TITLE", "大秘境情报") .. "|r  " .. (GearInsight:MplusMetaTag(M):gsub("%s*·%s*$", "")))

    local extra = math.max(0, lineCount(title) - 1) * 16

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", 0, -34 - extra)
    sub:SetWidth(PANEL_W - 32)
    sub:SetJustifyH("CENTER")
    if sub.SetWordWrap then sub:SetWordWrap(true) end
    sub:SetText(GearInsight:MplusMetaTag(M) .. T("MM_DATA_TO", "数据截至") .. " " .. (M.date or "") ..
        "  ·  " .. T("MM_SAME_SRC", "与官网 gearinsight.app 同源")
        .. GearInsight:MplusMetaStaleText(M))

    extra = extra + math.max(0, lineCount(sub) - 1) * 13

    GearInsight:BuildMplusMetaContent(f, 10, -52 - extra)
end

-- 期号前缀：M.tag 是导出时烘死的中文（「8月第5周 · 第2弹」），
-- ⛔ 英文客户端不能直接显示；用 season/week 现拼。
function GearInsight:MplusMetaTag(M)
    M = M or GearInsight.MplusMeta or {}
    if _ZH then return (M.tag or "") ~= "" and (M.tag .. "  ·  ") or "" end
    local wk = tonumber(M.week) or 0
    if wk > 0 then return ("Season 2 · Week %d  ·  "):format(wk) end
    return ""
end

-- 数据新鲜度提示。数据每周随榜刷新，但玩家可能装着几周前的插件而自己不知道 ——
-- 面板上的数字看起来永远是「对的」，只是它属于上上周。
-- ⛔判据必须用 M.epoch（Unix 时间戳）：M.date 只有「09-01」没有年份，
--   跨年会判反，也算不出「距今几天」。
-- 返回一段可直接拼进说明行的彩色文本；没过期返回 ""。
function GearInsight:MplusMetaStaleText(M)
    M = M or GearInsight.MplusMeta or {}
    local ep = tonumber(M.epoch)
    if not ep or ep <= 0 then return "" end
    local days = math.floor((time() - ep) / 86400)
    if days < 7 then return "" end
    if days >= 14 then
        return "  ·  |cffff5555"
            .. string.format(T("MM_STALE_HARD", "数据已 %d 天没更新，建议更新插件"), days) .. "|r"
    end
    return "  ·  |cffffc233"
        .. string.format(T("MM_STALE_SOFT", "数据已 %d 天没更新"), days) .. "|r"
end

-- 情报内容渲染（滚动区 + 全部行）。独立小窗和主面板「大秘境情报」页共用；
-- parent 上只建一次（数据每次登录静态），重复调用直接返回。
function GearInsight:BuildMplusMetaContent(parent, padX, padTop)
    if parent._mmRendered then return end
    local M = GearInsight.MplusMeta
    if not (M and M.pushDps) then return end
    parent._mmRendered = true
    local w = math.floor(parent:GetWidth() + 0.5)
    if w < 100 then w = PANEL_W end
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", padX or 10, padTop or -52)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(w - 40, 1400)
    scroll:SetScrollChild(content)

    local y = -4
    local function addLine(text, size)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 14, y)
        fs:SetWidth(w - 60)
        fs:SetJustifyH("LEFT")
        local font, _, flags = fs:GetFont()
        fs:SetFont(font, size or 12, flags)
        fs:SetText(text)
        y = y - fs:GetStringHeight() - 5
    end
    local function header(zh)
        y = y - 6
        addLine("|cffd6b26c— " .. zh .. " —|r", 13)
    end

    -- 输出榜组件（2026-08-31 用户：「分层明显一点，用更好的组件」）：
    -- 职业色横条 + T0/T1/T2 档位徽章 + 档位切换处留白分组。
    -- ⚠️ 值域窄（榜内首尾常只差 10%），条形按**相对刻度**拉开（min→30%、max→100%），
    --    按绝对值画所有条都一样长，档位根本看不出来。
    -- 榜的列说明：数值那列是**每本排行榜前 100 名的中位 DPS**，不写观众不知道这数是什么
    local function boardCols(withTier)
        local left = withTier and T("MM_COL_TIER", "档位") or ""
        addLine("|cff6f7684"
            .. T("MM_COL_SPEC", "专精") .. (left ~= "" and ("  ·  " .. left) or "")
            .. "  ·  " .. T("MM_COL_DPS", "平均DPS（前100中位）") .. "|r", 10)
    end

    local function addBoard(rows, maxN, chips)
        local list = {}
        local vmax, vmin = 0, math.huge
        for i, r in ipairs(rows or {}) do
            if not maxN or i <= maxN then
                list[#list + 1] = r
                local v = r.med or 0
                if v > vmax then vmax = v end
                if v < vmin then vmin = v end
            end
        end
        if vmax <= 0 then return end
        local span = math.max(vmax - vmin, 1)
        local rowW = w - 60
        -- 英文专精名（"Demonology Warlock"）比中文口语名长得多，列宽按语言给
        local nameW = _ZH and (chips and 96 or 118) or (chips and 150 or 172)
        local barX = 20 + nameW + (chips and 30 or 4)
        local barW = rowW - barX - (_ZH and 92 or 104)
        local lastTag
        for i, r in ipairs(list) do
            local gap = (vmax - (r.med or 0)) / vmax * 100
            local tag, tr, tg, tb
            if gap < 4 then tag, tr, tg, tb = "T0", 1, 0.82, 0
            elseif gap < 10 then tag, tr, tg, tb = "T1", 0.35, 0.75, 1
            else tag, tr, tg, tb = "T2", 0.55, 0.58, 0.65 end
            if chips and lastTag and tag ~= lastTag then y = y - 6 end
            lastTag = tag
            local row = CreateFrame("Frame", nil, content)
            row:SetPoint("TOPLEFT", 14, y)
            row:SetSize(rowW, 18)
            local rk = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rk:SetPoint("LEFT", 0, 0); rk:SetWidth(16); rk:SetJustifyH("LEFT")
            rk:SetText(tostring(i)); rk:SetTextColor(0.55, 0.58, 0.65)
            local nm = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nm:SetPoint("LEFT", 20, 0); nm:SetWidth(nameW); nm:SetJustifyH("LEFT")
            nm:SetWordWrap(false)
            nm:SetText(classMark(r) .. classColor(r) .. rowName(r) .. "|r")
            if chips then
                local ch = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                ch:SetPoint("LEFT", 20 + nameW + 2, 0)
                ch:SetText(tag); ch:SetTextColor(tr, tg, tb)
            end
            local track = row:CreateTexture(nil, "ARTWORK")
            track:SetPoint("LEFT", barX, 0); track:SetSize(barW, 11)
            track:SetColorTexture(0.13, 0.13, 0.17, 0.9)
            local frac = 0.30 + 0.70 * ((r.med or 0) - vmin) / span
            local fill = row:CreateTexture(nil, "OVERLAY")
            fill:SetPoint("LEFT", barX, 0)
            fill:SetSize(math.max(4, barW * frac), 11)
            local cr, cg, cb = classRGB(r)
            fill:SetColorTexture(cr, cg, cb, 0.92)
            local vt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            vt:SetPoint("LEFT", barX + barW + 6, 0)
            vt:SetText(wan(r.med) .. drText(r.dr, r["new"]))
            y = y - 21
        end
        y = y - 2
    end

    header(T("MM_H_PUSH", "冲层输出榜") .. " · " .. (M.pushLevel or "?") ..
           T("MM_LVL_UP", "层以上"))
    boardCols(true)
    addBoard(M.pushDps, nil, true)

    header(T("MM_H_ROLE", "坦克 / 治疗被选率") .. " · " .. (M.pushRuns or 0) .. T("MM_RUNS", " 场"))
    local t1, t2 = (M.pushTank or {})[1], (M.pushTank or {})[2]
    local h1, h2 = (M.pushHealer or {})[1], (M.pushHealer or {})[2]
    if t1 then
        addLine(T("MM_TANKS", "坦克  ") .. ("%s%s%s|r %.1f%%"):format(classMark(t1), classColor(t1), t1.cn, t1.pct or 0)
            .. (t2 and ("   %s%s%s|r %.1f%%"):format(classMark(t2), classColor(t2), t2.cn, t2.pct or 0) or ""))
    end
    if h1 then
        addLine(T("MM_HEALS", "治疗  ") .. ("%s%s%s|r %.1f%%"):format(classMark(h1), classColor(h1), h1.cn, h1.pct or 0)
            .. (h2 and ("   %s%s%s|r %.1f%%"):format(classMark(h2), classColor(h2), h2.cn, h2.pct or 0) or ""))
    end

    header(T("MM_H_FARM", "割草输出榜") .. " · " .. (M.farmLevel or "?") .. T("MM_LVL", "层"))
    boardCols(true)
    addBoard(M.farmDps, nil, true)

    header(T("MM_H_TANKDPS", "坦克也要打伤害"))
    boardCols(false)
    addBoard(M.farmTanks, 3, false)
    header(T("MM_H_HEALDPS", "治疗也要打伤害"))
    boardCols(false)
    addBoard(M.farmHeals, 3, false)

    header(T("MM_H_DUNGEON", "最快的本"))
    for i, d in ipairs(M.dungeons or {}) do
        local gap = (d.gap and d.gap > 0)
            and ("  |cff8a93a6+%d:%02d|r"):format(math.floor(d.gap / 60), d.gap % 60) or ""
        addLine(("%d. %s  %d:%02d%s")
            :format(i, ((_ZH or (d.en or "") == "") and d.cn or d.en), math.floor(d.sec / 60), d.sec % 60, gap))
    end

    header(T("MM_H_UNDER", "被低估（伤害不掉队 · 没人用）"))
    for _, r in ipairs(M.pushUnder or {}) do
        addLine(("%s%s%s|r  -%.0f%% · %.1f%%%s")
            :format(classMark(r), classColor(r), r.cn, r.gap or 0, r.pct or 0,
                    T("MM_IN_USE", " 在用")))
    end

    y = y - 8
    addLine("|cff8a93a6" .. T("MM_FOOT",
        "口径：每本排行榜前 100 名的中位数 · raider.io 真实名单 · 每周更新") .. "|r", 10)
    content:SetHeight(-y + 30)
end

function GearInsight:ToggleMplusMeta()
    if not (GearInsight.MplusMeta and GearInsight.MplusMeta.pushDps) then
        print("|cffd6b26cGearInsight|r " .. T("MM_NODATA", "大秘境情报数据未加载"))
        return
    end
    if not f then build() end
    f:SetShown(not f:IsShown())
end
