-- 「资讯」页（用户 2026-09-14）：六段紧凑排版 ——
-- ① 插件更新（最新 3 版）② 支持榜（本周进度 + 最高 10 / 最近 10 两列 + 去支持）③ 最近 3 次热修
-- ④ 强度榜（全部专精 S–D，专精图标 + 较上周升降）⑤ 关注 ⑥ 频道（简体只国内，其他语言只海外；平台小图标）。
-- 数据：core/NewsData.lua（generate_news_lua.py）+ core/Supporters.lua（build_supporters_lua.py）。⛔ 只画不发请求；点行 = 弹复制框。
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
local ZH = (_LOCALE == "zhCN" or _LOCALE == "zhTW")
local CN = (_LOCALE == "zhCN")
local GOLD, DIM, TXT = "|cFFFFD100", "|cFF8A93A6", "|cFFE6E0C8"
local TIER_C = { S = "|cFFFF7A00", A = "|cFFB040FF", B = "|cFF3A8DFF", C = "|cFF44DD44", D = "|cFF9A9A9A" }
local TIERS = { "S", "A", "B", "C", "D" }
local CLASS_ICON = { DEATHKNIGHT = "ClassIcon_DeathKnight", DEMONHUNTER = "ClassIcon_DemonHunter", DRUID = "ClassIcon_Druid", EVOKER = "ClassIcon_Evoker",
                     HUNTER = "ClassIcon_Hunter", MAGE = "ClassIcon_Mage", MONK = "ClassIcon_Monk", PALADIN = "ClassIcon_Paladin", PRIEST = "ClassIcon_Priest",
                     ROGUE = "ClassIcon_Rogue", SHAMAN = "ClassIcon_Shaman", WARLOCK = "ClassIcon_Warlock", WARRIOR = "ClassIcon_Warrior" }
local CLASS_HEX = { DEATHKNIGHT = "C41E3A", DEMONHUNTER = "A330C9", DRUID = "FF7C0A", EVOKER = "33937F", HUNTER = "AAD372", MAGE = "3FC7EB", MONK = "00FF98",
                    PALADIN = "F48CBA", PRIEST = "FFFFFF", ROGUE = "FFF468", SHAMAN = "0070DD", WARLOCK = "8788EE", WARRIOR = "C69B3A" }
local CUR = { CNY = "¥", USD = "$", EUR = "€", GBP = "£", JPY = "¥", KRW = "₩", TWD = "NT$", HKD = "HK$" }
local MEDIA = "Interface\\AddOns\\GearInsight\\media\\"

local function pick(it)
    if _LOCALE == "zhCN" then return it.zh end
    if _LOCALE == "zhTW" then return it.tw ~= "" and it.tw or it.zh end
    return it.en ~= "" and it.en or it.zh
end
local function trunc(s, n)
    s = s or ""
    if strlenutf8 and strlenutf8(s) > n then
        local out, cnt, i = {}, 0, 1
        while i <= #s and cnt < n do
            local c = s:byte(i)
            local w = (c >= 240 and 4) or (c >= 224 and 3) or (c >= 192 and 2) or 1
            out[#out + 1] = s:sub(i, i + w - 1); i = i + w; cnt = cnt + 1
        end
        return table.concat(out) .. "…"
    end
    return s
end
local function money(amt, cur)
    local sym = CUR[cur or "CNY"] or ((cur or "") .. " ")
    local v = math.floor((amt or 0) * 100 + 0.5) / 100
    -- 自报登记没填金额的条目（网站显示「—」）：别印成 ¥0，用户 2026-09-15 以为数据错了
    if v <= 0 then return "—" end
    return sym .. (v % 1 == 0 and tostring(math.floor(v)) or string.format("%.2f", v))
end
local function site()
    return GearInsight.SITE or (CN and "gearinsight.cn" or "gearinsight.app")
end
-- 带角色信息的站点链接：先落角色页（站点自动绑定这个角色），再跳 next 指向的页面
local function charLink(nextPath)
    local base = GearInsight.CharProfileURL and GearInsight:CharProfileURL()
    if base then
        base = base:gsub("^https://[^/]+", "https://" .. site())
        return base .. "?next=" .. nextPath
    end
    return "https://" .. site() .. nextPath
end
local function iconTag(path, size, dy)
    size = size or 12
    -- yOffset 往下压 2：|T|t 内联图在小字号行里会浮起来（用户 2026-09-17「图标和文字对齐」）
    return "|T" .. path .. ":" .. size .. ":" .. size .. ":0:" .. tostring(dy or -2) .. ":64:64:4:60:4:60|t"
end

-- 热修行开头的职业/专精名 → 职业图标 + 职业色（用户 2026-09-17「职业加职业标志」）。只认行首「xxx：」那一段。
local CLASS_WORDS = {
    { "死亡骑士", "DEATHKNIGHT" }, { "DK", "DEATHKNIGHT" }, { "恶魔猎手", "DEMONHUNTER" }, { "DH", "DEMONHUNTER" },
    { "德鲁伊", "DRUID" }, { "鸟德", "DRUID" }, { "野德", "DRUID" }, { "奶德", "DRUID" }, { "熊德", "DRUID" },
    { "唤魔师", "EVOKER" }, { "猎人", "HUNTER" }, { "射击猎", "HUNTER" }, { "兽王猎", "HUNTER" }, { "生存猎", "HUNTER" },
    { "法师", "MAGE" }, { "奥法", "MAGE" }, { "火法", "MAGE" }, { "冰法", "MAGE" }, { "武僧", "MONK" }, { "踏风", "MONK" }, { "酒仙", "MONK" }, { "织雾", "MONK" },
    { "圣骑士", "PALADIN" }, { "骑士", "PALADIN" }, { "防骑", "PALADIN" }, { "奶骑", "PALADIN" }, { "惩戒", "PALADIN" },
    { "牧师", "PRIEST" }, { "神牧", "PRIEST" }, { "戒律", "PRIEST" }, { "暗牧", "PRIEST" }, { "盗贼", "ROGUE" }, { "贼", "ROGUE" },
    { "萨满", "SHAMAN" }, { "萨", "SHAMAN" }, { "术士", "WARLOCK" }, { "术", "WARLOCK" }, { "战士", "WARRIOR" }, { "战", "WARRIOR" },
    { "Death Knight", "DEATHKNIGHT" }, { "Demon Hunter", "DEMONHUNTER" }, { "Druid", "DRUID" }, { "Evoker", "EVOKER" }, { "Hunter", "HUNTER" },
    { "Mage", "MAGE" }, { "Monk", "MONK" }, { "Paladin", "PALADIN" }, { "Priest", "PRIEST" }, { "Rogue", "ROGUE" }, { "Shaman", "SHAMAN" },
    { "Warlock", "WARLOCK" }, { "Warrior", "WARRIOR" },
}
local function classifyLead(text)
    local out = {}
    for seg0 in (text .. "；"):gmatch("(.-)；") do
        local seg = seg0          -- gmatch 的循环变量在 5.5 里是 const
        local head = seg:match("^%s*(.-)[：:]") or ""
        local cls
        for _, cw in ipairs(CLASS_WORDS) do
            if head:find(cw[1], 1, true) then cls = cw[2] break end
        end
        if cls and CLASS_ICON[cls] then
            local i = seg:find("[：:]")
            seg = iconTag("Interface\\ICONS\\" .. CLASS_ICON[cls], 13) .. " |cff" .. CLASS_HEX[cls] .. seg:sub(1, i - 1) .. "|r" .. seg:sub(i)
        end
        out[#out + 1] = seg
    end
    return table.concat(out, "；")
end
local function chIconTag(key)
    if not key or key == "" then return "" end
    return "|T" .. MEDIA .. "ch_" .. key .. ".tga:12:12:0:0|t "
end
local function specIconTag(specID)
    if not specID or specID == 0 or not GetSpecializationInfoByID then return "" end
    local ok, _, _, _, icon = pcall(GetSpecializationInfoByID, specID)
    if ok and icon then return "|T" .. icon .. ":12:12:0:0:64:64:4:60:4:60|t" end
    return ""
end

function GearInsight:BuildNewsPage(page)
    if not page then return end
    if not page._nwBuilt then
        page._nwBuilt = true
        local sf = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 8, -40); sf:SetPoint("BOTTOMRIGHT", -28, 10)
        local sc = CreateFrame("Frame", nil, sf); sc:SetSize(460, 10); sf:SetScrollChild(sc)
        page._nwSf, page._nwSc, page._nwRows, page._nwTex = sf, sc, {}, {}
    end
    self:_renderNews(page)
end

function GearInsight:_renderNews(page)
    local D = _G.GearInsightNews
    local S = GearInsight.SUPPORTERS
    local sc = page._nwSc
    for _, r in ipairs(page._nwRows) do r:Hide() end
    for _, t in ipairs(page._nwTex) do t:Hide() end
    local W = math.max(300, (page._nwSf:GetWidth() or 460))
    sc:SetWidth(W)
    local y, ri, ti = -2, 0, 0
    local function tex(x, yy, w, h, r, g, b, a, file, plain)
        ti = ti + 1
        local t = page._nwTex[ti]
        if not t then t = sc:CreateTexture(nil, "ARTWORK"); page._nwTex[ti] = t end
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", x, yy); t:SetSize(w, h)
        if file then
            t:SetTexture(file); t:SetVertexColor(1, 1, 1, 1)
            if plain then t:SetTexCoord(0, 1, 0, 1) else t:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
        else t:SetTexture(nil); t:SetTexCoord(0, 1, 0, 1); t:SetColorTexture(r, g, b, a) end
        t:Show()
        return t
    end
    local function row(h, text, opts)
        ri = ri + 1
        local r = page._nwRows[ri]
        if not r then
            r = CreateFrame("Button", nil, sc)
            r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:Hide()
            r.accent = r:CreateTexture(nil, "BORDER"); r.accent:SetWidth(3)
            r.accent:SetPoint("TOPLEFT", 0, -3); r.accent:SetPoint("BOTTOMLEFT", 0, 3); r.accent:SetColorTexture(1, 0.82, 0, 0.9); r.accent:Hide()
            r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.82, 0, 0.10)
            r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.txt:SetPoint("TOPLEFT", 10, -4); r.txt:SetJustifyH("LEFT"); r.txt:SetJustifyV("TOP")
            r.txt2 = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.txt2:SetPoint("TOPRIGHT", -8, -4); r.txt2:SetJustifyH("RIGHT")
            -- 行内超链接（|Hspell:ID|h…|h）：鼠标放到哪个技能就出哪个的提示（用户 2026-09-14「一行只能展示一个」）
            if r.SetHyperlinksEnabled then r:SetHyperlinksEnabled(true) end
            r:SetScript("OnHyperlinkEnter", function(s2, link)
                GameTooltip:SetOwner(s2, "ANCHOR_CURSOR"); GameTooltip:SetHyperlink(link); GameTooltip:Show()
            end)
            r:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
            page._nwRows[ri] = r
        end
        opts = opts or {}
        local rw = opts.w or (W - 4)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", opts.x or 0, y); r:SetWidth(rw)
        r.txt:ClearAllPoints(); r.txt:SetPoint("TOPLEFT", 10 + (opts.indent or 0), -4)
        r.txt:SetFontObject(opts.font or "GameFontHighlightSmall")
        r.txt:SetWordWrap(not opts.oneline); r.txt:SetNonSpaceWrap(false)
        if r.txt.SetMaxLines then r.txt:SetMaxLines(opts.oneline and 1 or 0) end
        r.txt:SetText(text)
        r.txt:SetWidth(rw - 18 - (opts.indent or 0) - (opts.right and 64 or 0))
        r.txt2:SetText(opts.right or ""); r.txt2:SetShown(opts.right and true or false)
        local th = math.max(h or 0, (r.txt:GetStringHeight() or 14) + 8)
        r:SetHeight(th)
        if opts.hdr then r.bg:SetColorTexture(1, 0.82, 0, 0.08); r.bg:Show(); r.accent:Show()
        elseif opts.cta then r.bg:SetColorTexture(1, 0.82, 0, 0.16); r.bg:Show(); r.accent:Hide()
        else r.bg:Hide(); r.accent:Hide() end
        r:EnableMouse((opts.click or opts.tip or text:find("|H", 1, true)) and true or false)
        r.hl:SetShown(opts.click and true or false)
        r:SetScript("OnClick", opts.click or nil)
        r:SetScript("OnEnter", opts.tip and function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(opts.tip, 1, 0.82, 0, 1, true); GameTooltip:Show()
        end or nil)
        r:SetScript("OnLeave", opts.tip and function() GameTooltip:Hide() end or nil)
        r:Show()
        if not opts.noAdvance then y = y - th - 1 end
        return r, th
    end
    local function gap(n) y = y - (n or 8) end
    local function hdr(text, right) row(22, GOLD .. text .. "|r", { hdr = true, font = "GameFontNormal", right = right }) end
    -- 平台行：左侧小图标（media/ch_<key>.tga）+ 平台名 + 账号；点击复制
    local function chRow(c)
        row(18, chIconTag(c[4]) .. DIM .. c[1] .. "|r  " .. TXT .. c[2] .. "|r", {
            click = function() GearInsight:ShowCopyText(c[3], T("NW_COPY_HINT", "Ctrl+C 复制，去对应 App 搜索 / 打开"), c[1]) end,
            tip = c[3],
        })
    end

    if not D then
        row(20, DIM .. T("NW_NODATA", "缺少数据文件 core/NewsData.lua") .. "|r"); sc:SetHeight(-y + 10); return
    end

    -- ① 逃课（用户 2026-09-17「逃课做到资讯里面最上 … 点击弹窗来展示」）：一行一条，点开弹窗看步骤 + 标记
    local CH = _G.GearInsightCheese
    local chDay = GearInsight.CheeseGameDay and GearInsight.CheeseGameDay() or ""
    if CH and CH.items and #CH.items > 0 and not (GearInsight.CheeseValid and GearInsight.CheeseValid()) then
        -- 日期不对就不展示条目，只留一行说明（用户 2026-09-17「如果日期不对就不要展示了」）
        hdr(T("NW_SEC_CHEESE", "逃课 · 今日省事清单"), GOLD .. chDay .. "|r")
        row(16, DIM .. string.format(T("CH_STALE", "今天（%s）的还没整理 —— 每天 07:00 更新后写；旧的不展示，免得按旧坐标白跑。"), chDay) .. "|r")
        gap(10)
    elseif CH and CH.items and #CH.items > 0 then
        hdr(T("NW_SEC_CHEESE", "逃课 · 今日省事清单"), GOLD .. (CH.forDate or "") .. "|r")
        for _, it in ipairs(CH.items) do
            local nCoord = 0
            for _, st in ipairs(it.steps or {}) do if st.x and st.y then nCoord = nCoord + 1 end end
            local CL = GearInsight.CheeseL or function(o, k) return o[k] or "" end
            local tag = CL(it, "tag")
            row(18, (tag ~= "" and (GOLD .. "[" .. tag .. "]|r ") or "") .. TXT .. trunc(CL(it, "title"), ZH and 34 or 70) .. "|r",
                { click = function() GearInsight:ShowCheesePopup(it.id) end,
                  tip = CL(it, "summary") .. (nCoord > 0 and ("\n\n" .. string.format(T("NW_CHEESE_TIP", "%d 个坐标 · 点开弹窗一键标记"), nCoord)) or ""),
                  right = nCoord > 0 and (DIM .. string.format(T("NW_CHEESE_N", "%d 坐标"), nCoord) .. "|r") or nil })
        end
        row(14, DIM .. T("NW_CHEESE_DAILY", "逃课每日更新，注意每次上线前更新插件") .. "|r")
        gap(10)
    end

    -- ② 支持榜（从设置页搬来，用户 2026-09-14「放到资讯第二部分」）
    if S then
        local pct = math.floor((S.pct or 0) + 0.5)
        hdr(T("SUP_TITLE", "免费事业支持榜"))
        -- 那两句打动人的话保留（用户 2026-09-14「之前的话语咋没了」）
        row(14, TXT .. T("SUP_LEDE", "GearInsight 永久免费，靠玩家一起托着。每一笔支持都直接变成服务器时长和 AI 分析次数——这面墙记着每一位让它继续免费的人。") .. "|r")
        row(16, TXT .. T("SUP_GOAL_TITLE", "本周运营费") .. "|r  " .. DIM .. T("NW_RESET_THU", "每周四 0 点重置，累计不清零") .. "|r",
            { right = GOLD .. string.format(T("SUP_GOAL_PCT", "已覆盖 %d%%"), pct) .. "|r" })
        local barW = W - 24
        tex(10, y, barW, 6, 1, 1, 1, 0.08)
        local ws = math.min(barW, barW * (S.serverPct or 0) / 100)
        local wl = math.min(barW - ws, barW * (S.llmPct or 0) / 100)
        if ws > 0.5 then tex(10, y, ws, 6, 0.91, 0.78, 0.42, 1) end
        if wl > 0.5 then tex(10 + ws, y, wl, 6, 0.43, 0.65, 0.97, 1) end
        y = y - 10
        row(14, GOLD .. (pct < 100 and string.format(T("SUP_GOAL_LEFT", "还差 %d%%，就能让 GearInsight 免费再撑一周"), 100 - pct)
            or T("SUP_GOAL_DONE", "本周的服务器和 AI 费用已经有人替大家付了")) .. "|r")
        row(14, DIM .. "|cFFE8C86A■|r " .. T("SUP_LEGEND_SERVER", "服务器") .. "  |cFF6EA6F7■|r " .. T("SUP_LEGEND_LLM", "AI 分析（大模型 Token）") .. "   " .. T("SUP_GOAL_HINT", "运营费 = 服务器（网站、镜像、数据更新）+ AI 分析用的大模型 Token。支持只花在这两样上。") .. "|r")
        gap(2)
        -- 两列：金额最高 10 / 最近 10（名字职业色 + 职业图标；留言放悬浮）
        local colW = math.floor((W - 12) / 2)
        local medals = { "|cffffd700①|r", "|cffc0c0c0②|r", "|cffcd7f32③|r" }
        local function col(x0, title, rows, byRank)
            local saveY = y
            row(16, GOLD .. title .. "|r", { x = x0, w = colW, font = "GameFontNormalSmall" })
            local rank, lastAmount, lastCurrency = 0, nil, nil
            for i, rw in ipairs(rows or {}) do
                if byRank and i > 10 then break end
                local name, realm, amt, msg, n, region, cur, cls, ts = rw[1], rw[2], rw[3], rw[4], rw[5], rw[6], rw[7], rw[8], rw[9]
                if amt ~= lastAmount or (cur or "CNY") ~= lastCurrency then rank = i end
                lastAmount, lastCurrency = amt, cur or "CNY"
                local lead = byRank and (medals[rank] or (DIM .. rank .. "|r")) or (DIM .. ((ts or ""):sub(6, 10):gsub("-", "/")) .. "|r")
                local hex = cls and CLASS_HEX[cls]
                local ic = (cls and CLASS_ICON[cls]) and (iconTag("Interface\\ICONS\\" .. CLASS_ICON[cls], 11) .. " ") or ""
                local who = ic .. (hex and ("|cff" .. hex) or TXT) .. (name or "?") .. "|r" .. ((realm and realm ~= "") and (" " .. DIM .. trunc(realm, 5) .. "|r") or "")
                row(15, lead .. "  " .. who,
                    { x = x0, w = colW, oneline = true, right = GOLD .. money(amt, cur) .. "|r" .. ((n or 1) > 1 and (DIM .. " ×" .. n .. "|r") or ""),
                      tip = (msg and msg ~= "") and ("“" .. msg .. "”") or nil, noAdvance = true })
                y = y - 16
            end
            local endY = y
            y = saveY
            return endY
        end
        local yl = col(0, T("SUP_COL_TOP", "金额最高 10 人"), S.top, true)
        local yr = col(colW + 8, T("SUP_COL_SINCE_VIDEO", "最近支持者"), S.recent or S.top, false)
        y = math.min(yl, yr) - 4
        -- 带角色信息：先落角色页自动绑定，再跳支持榜，登记表单会预填这个角色（用户 2026-09-14「带上角色信息」）
        local url = charLink("/wow/en/supporters")
        row(20, GOLD .. T("SUP_CTA2", "去支持 / 上榜登记") .. "|r  " .. DIM .. T("SUP_CTA_SUB", "（点击复制网址，打开即绑定你的角色，登记时自动填好名字）") .. "|r", {
            cta = true, click = function() GearInsight:ShowCopyText(url, T("MT_MORE_COPY", "Ctrl+C 复制，到浏览器打开"), T("SUP_TITLE", "免费事业支持榜")) end,
            tip = T("SUP_CTA_TIP", "微信 / 支付宝 / Ko-fi 都在这一页；登记后名字进榜，插件下一版一起烤进来"),
        })
        gap(10)
    end

    -- ③ 插件更新日志：一版一行，点开弹窗看全部条目（用户 2026-09-17）
    hdr(T("NW_SEC_REL", "插件更新 · 最新 3 版"))
    for _, r in ipairs(D.releases or {}) do
        local n = #(r.items or {})
        row(18, TXT .. "v" .. (r.version or "") .. "|r  " .. DIM .. (r.date or "") .. "|r  " .. trunc(pick((r.items or {})[1] or { zh = "", en = "", tw = "" }), ZH and 22 or 40),
            { click = function()
                  local lines = {}
                  for _, it in ipairs(r.items or {}) do lines[#lines + 1] = "· " .. pick(it) end
                  GearInsight:ShowNewsTextPopup("v" .. (r.version or "") .. "  " .. (r.date or ""), lines)
              end,
              tip = string.format(T("NW_REL_TIP", "%d 条改动 · 点开看全部"), n),
              right = DIM .. string.format(T("NW_REL_N", "%d 条"), n) .. "|r" })
    end
    gap(10)

    -- ④ 最近 3 次热修
    local p = D.patch or {}
    hdr(T("NW_SEC_PATCH", "游戏版本 · 最近 3 次热修"), DIM .. ((ZH and p.title) or p.titleEn or "") .. "|r")
    -- 一天一行（日期 + 第一条摘要 + 「N 条」），点开弹窗看全部，与上面更新日志同款（用户 2026-09-17「这里也做成点击的，外面显示多少条」）
    for _, h in ipairs(p.hotfixes or {}) do
        local lines = (ZH and h.lines) or h.linesEn or h.lines or {}
        local function decorate(li, ln)
            local refs = h.refs and h.refs[li] or {}
            local text = classifyLead(ln)
            -- 行里提到的技能 / 物品：名字前面塞图标（|T|t 内联，天然对齐）
            for _, rf in ipairs(refs) do
                local nm = ZH and rf.zh or rf.en
                local tex0
                if rf.t == "item" then tex0 = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(rf.id)
                else tex0 = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(rf.id) end
                if nm and nm ~= "" and tex0 then
                    local s0, e0 = text:find(nm, 1, true)
                    -- 技能 = 技能链接蓝，物品 = 史诗紫，和正文灰字拉开（用户 2026-09-14「技能颜色做个区分」）
                    local col = (rf.t == "item") and "|cFFA335EE" or "|cFF71D5FF"
                    local link = (rf.t == "item") and ("item:" .. rf.id) or ("spell:" .. rf.id)
                    if s0 then text = text:sub(1, s0 - 1) .. "|H" .. link .. "|h" .. iconTag(tex0, 12) .. col .. "[" .. nm .. "]|r|h" .. text:sub(e0 + 1) end
                end
            end
            return text
        end
        local n = #lines
        row(18, TXT .. (h.date or "") .. "|r  " .. DIM .. trunc(lines[1] or "", ZH and 26 or 46) .. "|r",
            { click = function()
                  local out = {}
                  for li, ln in ipairs(lines) do out[#out + 1] = "· " .. decorate(li, ln) end
                  GearInsight:ShowNewsTextPopup((h.date or "") .. "  " .. ((ZH and p.title) or p.titleEn or ""), out)
              end,
              tip = string.format(T("NW_REL_TIP", "%d 条改动 · 点开看全部"), n),
              right = DIM .. string.format(T("NW_REL_N", "%d 条"), n) .. "|r" })
    end
    gap(10)

    -- ④ 强度榜：全部专精 S–D，专精图标 + 较上周升降名次
    local tl = D.tier or {}
    hdr(T("NW_SEC_TIER", "数据趋势 · 强度榜"), DIM .. T("NW_TIER_BASIS", "大秘境高层 · ") .. (tl.updatedAt or "") .. "|r")
    row(14, DIM .. T("NW_TIER_NOTE", "↑↓ = 较上周名次变化；治疗 / 坦克以输出粗排仅供参考") .. "|r")
    for _, g in ipairs(tl.groups or {}) do
        local parts = {}
        for _, t in ipairs(TIERS) do parts[t] = {} end
        for _, sp in ipairs(g.specs or {}) do
            local nm = ZH and sp.specCn or (sp.spec and (sp.spec:sub(1, 1) .. sp.spec:sub(2):lower())) or ""
            local d = sp.delta or 0
            local arrow = d > 0 and ("|cFF33FF33↑" .. d .. "|r") or (d < 0 and ("|cFFFF5555↓" .. (-d) .. "|r") or "")
            local t = parts[sp.tier] and sp.tier or "D"
            parts[t][#parts[t] + 1] = specIconTag(sp.specID) .. "|cFF" .. (sp.hex or "FFFFFF") .. nm .. "|r" .. arrow
        end
        local roleName = ZH and (g.roleCn or g.role) or ({ dps = "DPS", healer = "Healers", tank = "Tanks" })[g.role] or g.role
        row(16, TXT .. roleName .. "|r", { font = "GameFontNormalSmall" })
        for _, t in ipairs(TIERS) do
            if #parts[t] > 0 then row(16, TIER_C[t] .. t .. "|r  " .. table.concat(parts[t], "  "), { indent = 8 }) end
        end
        gap(3)
    end
    local tierUrl = charLink("/wow/en/tier-list")
    row(20, GOLD .. T("NW_TIER_GO", "看完整数值与治疗 / 坦克口径") .. "|r  " .. DIM .. T("NW_TIER_GO_SUB", "（点击复制网址，打开即绑定你的角色）") .. "|r", {
        cta = true, click = function() GearInsight:ShowCopyText(tierUrl, T("MT_MORE_COPY", "Ctrl+C 复制，到浏览器打开"), T("NW_SEC_TIER", "数据趋势 · 强度榜")) end,
        tip = tierUrl,
    })
    gap(10)

    -- ⑤ 关注 ⑥ 频道：简体只国内（公众号 / 小程序 / 抖音 / 小红书 / B站 / QQ 群），其他语言只海外（X / YouTube / Telegram）
    local ch = D.channels or {}
    -- 关注 + 频道合并成一段（用户 2026-09-17「这两应该合并」）
    hdr(T("NW_SEC_FOLLOW", "关注 · 更新第一时间到"))
    for _, c in ipairs(ch[CN and "follow_cn" or "follow_en"] or {}) do chRow(c) end
    for _, c in ipairs(ch[CN and "cn" or "en"] or {}) do chRow(c) end
    -- 微信群（只简体；码 7 天一换，过期自动隐藏；点击弹二维码 —— 用户 2026-09-14）
    local wg = CN and GearInsight.WXGROUP
    if wg and GearInsight.WxGroupValid and GearInsight.WxGroupValid() then
        row(18, chIconTag("wechat") .. DIM .. "微信群|r  " .. TXT .. (wg.name or "GearInsight交流群") .. "|r  " .. DIM .. "点击弹出二维码 · 有效至 " .. (wg.expires or "") .. "|r", {
            click = function() GearInsight:ShowWxGroupQR() end,
            tip = "微信扫码入群（群码 7 天一换，插件随周更带新码）",
        })
    end
    row(14, DIM .. T("NW_FOOT", "数据随插件版本一起更新 · 点行可复制账号") .. "|r")
    sc:SetHeight(-y + 10)
end


-- ── 微信群二维码弹窗：用色块画 core/WxGroup.lua 里的模块矩阵，不依赖图片文件 ──────────────
function GearInsight.WxGroupValid()
    local wg = GearInsight.WXGROUP
    if not wg or not wg.rows or not wg.expires then return false end
    local y, m, d = wg.expires:match("^(%d+)%-(%d+)%-(%d+)$")
    if not y then return false end
    local exp = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 23, min = 59 })
    return time() <= exp
end

function GearInsight:ShowWxGroupQR()
    local wg = self.WXGROUP
    if not wg or not wg.rows then return end
    local n = wg.n or #wg.rows
    local px = 6
    local pad = 18
    local size = n * px
    local f = self._wxQrFrame
    if not f then
        f = CreateFrame("Frame", "GearInsightWxGroupQR", UIParent, "BackdropTemplate")
        f:SetFrameStrata("DIALOG"); f:SetFrameLevel(60)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24,
                        insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        f:SetBackdropColor(1, 1, 1, 1)
        f:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
        f:SetPoint("CENTER")
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton"); cb:SetPoint("TOPRIGHT", -2, -2)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOP", 0, -pad)
        f.title:SetTextColor(0.1, 0.1, 0.1)
        f.foot = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.foot:SetPoint("BOTTOM", 0, pad - 4)
        f.foot:SetTextColor(0.35, 0.35, 0.35)
        f.cells = {}
        if self.RegisterEscClose then self:RegisterEscClose(f, "GearInsightWxGroupQR") else tinsert(UISpecialFrames, "GearInsightWxGroupQR") end
        self._wxQrFrame = f
    end
    f:SetSize(size + pad * 2, size + pad * 2 + 52)
    f.title:SetText(wg.name or "GearInsight 微信群")
    f.foot:SetText("微信扫码入群 · 有效期至 " .. (wg.expires or "") .. "（7 天一换）")
    for _, t in ipairs(f.cells) do t:Hide() end
    local k = 0
    local x0, y0 = pad, -(pad + 30)
    for r = 1, n do
        local rowS = wg.rows[r] or ""
        for c = 1, n do
            if rowS:sub(c, c) == "1" then
                k = k + 1
                local t = f.cells[k]
                if not t then t = f:CreateTexture(nil, "ARTWORK"); t:SetColorTexture(0, 0, 0, 1); f.cells[k] = t end
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + (c - 1) * px, y0 - (r - 1) * px)
                t:SetSize(px, px)
                t:Show()
            end
        end
    end
    f:Show()
end


-- ── 文本弹窗（更新日志全文等）──────────────────────────────────────────────────
function GearInsight:ShowNewsTextPopup(title, lines)
    local f = self._nwTextPopup
    if not f then
        f = CreateFrame("Frame", "GearInsightNewsTextPopup", UIParent, "BackdropTemplate")
        f:SetSize(520, 380); f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
                        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        f:SetBackdropColor(0.05, 0.05, 0.08, 0.97); f:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        if GearInsight.AnchorPopup then GearInsight:AnchorPopup(f) else f:SetPoint("CENTER") end
        tinsert(UISpecialFrames, "GearInsightNewsTextPopup")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
        f._hd = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f._hd:SetPoint("TOPLEFT", 14, -12)
        f._hd:SetTextColor(1, 0.82, 0)
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -44); sf:SetPoint("BOTTOMRIGHT", -30, 12)
        local sc = CreateFrame("Frame", nil, sf); sc:SetSize(460, 10); sf:SetScrollChild(sc)
        f._txt = sc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f._txt:SetPoint("TOPLEFT", 6, -4); f._txt:SetJustifyH("LEFT"); f._txt:SetWordWrap(true); f._txt:SetSpacing(4)
        -- 弹窗里的技能 / 物品链接要能悬浮 + 点击（用户 2026-09-17「点不了」）：链接事件挂在 FontString 的父框上
        sc:EnableMouse(true)
        if sc.SetHyperlinksEnabled then sc:SetHyperlinksEnabled(true) end
        sc:SetScript("OnHyperlinkEnter", function(s2, link)
            GameTooltip:SetOwner(s2, "ANCHOR_CURSOR"); GameTooltip:SetHyperlink(link); GameTooltip:Show()
        end)
        sc:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
        sc:SetScript("OnHyperlinkClick", function(_, link, text, button)
            if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(text) return end
            if SetItemRef then SetItemRef(link, text, button) end
        end)
        f._sf, f._sc = sf, sc
        if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
        self._nwTextPopup = f
    end
    f._hd:SetText(title or "")
    local W = math.max(300, (f._sf:GetWidth() or 460)); f._sc:SetWidth(W); f._txt:SetWidth(W - 12)
    f._txt:SetText(table.concat(lines or {}, "\n"))
    f._sc:SetHeight((f._txt:GetStringHeight() or 20) + 16)
    f:Show()
end

