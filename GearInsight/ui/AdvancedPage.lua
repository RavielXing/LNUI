-- 「进阶」标签页：插件 ↔ 网站互联（2026-08-31 用户：「和网站互联单独搞个TAB…
-- 有导出，导入功能」「导入网站分析后的字符串贴回，可以记录要刷优先级等信息」「就叫进阶吧」）。
-- 闭环：①导出装备串 → ②网站 /analyze 深度分析 → ③把网站给的回执串粘回来，
-- 刷取优先级 + 缺件清单落进 GearInsightDB.webPlan 持久展示。
--
-- 回执串契约（网站 wow_en_analyze.html 的 JS 生成，两端必须同步改）：
--   GIAD1|<CLASS>/<specId>|<sum6hex>|R:slot~槽名~itemId~ilvl~pct~名字~来源;…|F:来源~件数;…|D:YYYY-MM-DD
--   sum = djb(h*33+byte mod 16777216) 对「sum 之后整段 UTF-8 字节」算，与导出串同款。
GearInsight = GearInsight or {}
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local t = GearInsight.LOC and (GearInsight.LOC[_LOCALE] or GearInsight.LOC["enUS"])
    return (t and t[key]) or zh
end

local function checksum(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 16777216
    end
    return string.format("%06x", h)
end

-- ── 回执串解析 ─────────────────────────────────────────────────────────────
local function parsePlan(text)
    if type(text) ~= "string" then return nil, T("ADV_ERR_EMPTY", "没有内容") end
    text = text:gsub("[\r\n]", ""):match("^%s*(.-)%s*$")
    -- ⛔ WoW 的 EditBox 粘贴会把 | 转义成 ||（0.67.0 实测「格式不对」的真身），先还原
    text = text:gsub("||", "|")
    if text == "" then return nil, T("ADV_ERR_EMPTY", "没有内容") end
    local _ver, ident, sum, rest = text:match("^GIAD([12])|([^|]+)|(%x+)|(.+)$")
    if not ident then
        return nil, T("ADV_ERR_FMT", "格式不对：要以 GIAD1| 开头（在网站分析页点「复制回插件」）")
    end
    if checksum(rest) ~= sum:lower() then
        return nil, T("ADV_ERR_SUM", "校验不过：串没复制全，回网站重新复制一次")
    end
    local plan = { ident = ident, items = {}, farm = {}, coach = {}, date = "" }
    for section in rest:gmatch("[^|]+") do
        local kind, body = section:match("^(%a):(.*)$")
        if kind == "R" then
            for it in body:gmatch("[^;]+") do
                local slotId, slotName, itemId, ilvl, pct, name, src =
                    it:match("^(%d+)~([^~]*)~(%d+)~(%d+)~([%d%.]*)~([^~]*)~([^~]*)$")
                if itemId then
                    plan.items[#plan.items + 1] = {
                        slotId = tonumber(slotId), slotName = slotName,
                        itemId = tonumber(itemId), ilvl = tonumber(ilvl) or 0,
                        pct = tonumber(pct) or 0, name = name, source = src,
                    }
                end
            end
        elseif kind == "F" then
            for it in body:gmatch("[^;]+") do
                local src, n = it:match("^([^~]+)~(%d+)$")
                if src then plan.farm[#plan.farm + 1] = { source = src, count = tonumber(n) or 0 } end
            end
        elseif kind == "S" then
            -- 网站独有：WCL 实战战力（best~tier~难度~中位）
            local best, tier, diff, med = body:match("^([^~]*)~([^~]*)~([^~]*)~([^~]*)$")
            if best and best ~= "" then
                plan.score = { best = tonumber(best), tier = tier,
                               diff = diff, med = tonumber(med) }
            end
        elseif kind == "C" then
            -- 网站独有：AI 教练点评（按句）
            for it in body:gmatch("[^;]+") do
                plan.coach[#plan.coach + 1] = it
            end
        elseif kind == "D" then
            plan.date = body
        end
    end
    if #plan.items == 0 and #plan.farm == 0 and #plan.coach == 0 and not plan.score then
        return nil, T("ADV_ERR_NODATA", "串里没有分析内容")
    end
    return plan
end

function GearInsight:ImportWebPlan(text)
    local plan, err = parsePlan(text)
    if not plan then return nil, err end
    plan.importedAt = date("%m-%d %H:%M")
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.webPlan = plan
    return plan
end

-- ── 页面 ───────────────────────────────────────────────────────────────────
local function addText(page, x, y, text, template, color)
    local fs = page:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(text)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

-- 刷取优先级 + 缺件清单渲染（导入后 / 每次进页刷新；行对象复用）
local function renderPlan(page)
    page._planLines = page._planLines or {}
    for _, fs in ipairs(page._planLines) do fs:Hide() end
    local n = 0
    local function line(y, text, template, color, wrap)
        n = n + 1
        local fs = page._planLines[n]
        if not fs then
            fs = page:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
            page._planLines[n] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 24, y)
        fs:SetPoint("RIGHT", page, "RIGHT", -16, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(wrap and true or false)
        fs:SetText(text)
        local c = color or { 0.85, 0.85, 0.88 }
        fs:SetTextColor(c[1], c[2], c[3])
        fs:Show()
        return fs:GetStringHeight()
    end
    -- WCL 同款五档颜色（按百分位）
    local function scoreColor(v)
        if not v then return "|cff9d9d9d" end
        if v >= 99 then return "|cffe268a8" end
        if v >= 95 then return "|cffff8000" end
        if v >= 75 then return "|cffa335ee" end
        if v >= 50 then return "|cff0070dd" end
        if v >= 25 then return "|cff1eff00" end
        return "|cff9d9d9d"
    end

    local plan = GearInsightDB and GearInsightDB.webPlan
    -- ⛔ 旧版本存的 webPlan 没有 coach/score 字段：#plan.coach 对 nil 取长度直接炸面板
    --   （2026-08-31 实测「面板初始化失败 …attempt to get length of field 'coach'」）。
    --   SavedVariables 里的老数据永远可能缺新字段，渲染前必须补默认值。
    if plan then
        plan.items = plan.items or {}
        plan.farm = plan.farm or {}
        plan.coach = plan.coach or {}
    end
    local y = -262
    if not plan then
        line(y, T("ADV_PLAN_NONE", "还没导入过 —— 网站分析完，把「复制回插件」的串贴到上面。"),
            "GameFontDisableSmall")
        return
    end
    line(y, T("ADV_PLAN_HEAD", "网站分析结果 · ") .. (plan.ident or "")
        .. "  ·  " .. (plan.date or "") .. T("ADV_PLAN_IMPORTED", " 导入于 ") .. (plan.importedAt or ""),
        "GameFontNormalSmall", { 1, 0.82, 0 })
    y = y - 20
    if plan.score and plan.score.best then
        local sc = plan.score
        local diffTag = (sc.diff and sc.diff ~= "" and (sc.diff .. " · ") or "")
        line(y, T("ADV_SCORE_HEAD", "WCL 实战战力（网站独有）："), "GameFontNormalSmall",
            { 0.55, 0.78, 1 })
        y = y - 18
        line(y, ("%s%.1f|r  |cff8a93a6%s%s|r"):format(
            scoreColor(sc.best), sc.best, diffTag,
            (sc.med and (T("ADV_SCORE_MED", "全 boss 中位 ") .. sc.med) or "")),
            "GameFontNormalLarge")
        y = y - 26
    end
    if #plan.coach > 0 then
        line(y, T("ADV_COACH_HEAD", "AI 教练点评（网站独有）："), "GameFontNormalSmall",
            { 0.55, 0.78, 1 })
        y = y - 18
        for _, c in ipairs(plan.coach) do
            local h = line(y, "|cffd6b26c·|r " .. c, "GameFontHighlightSmall", nil, true)
            y = y - h - 6
        end
        y = y - 4
    end
    if #plan.farm > 0 then
        line(y, T("ADV_FARM_HEAD", "建议刷取顺序（缺件多的本优先）："), "GameFontNormalSmall",
            { 0.55, 0.78, 1 })
        y = y - 18
        for i, f in ipairs(plan.farm) do
            if i > 6 then break end
            line(y, string.format("%d. %s  |cffd6b26cx%d|r", i, f.source, f.count))
            y = y - 17
        end
        y = y - 6
    end
    if #plan.items > 0 then
        line(y, T("ADV_MISS_HEAD", "缺件清单（按使用率）："), "GameFontNormalSmall",
            { 0.55, 0.78, 1 })
        y = y - 18
        for i, it in ipairs(plan.items) do
            if i > 9 then
                line(y, string.format(T("ADV_MISS_MORE", "…还有 %d 件，完整清单看网站"),
                    #plan.items - 9), "GameFontDisableSmall")
                break
            end
            line(y, string.format("%s  |cffffffff%s|r [%d]  |cff8a93a6%s|r  %.0f%%",
                it.slotName or "", it.name or ("#" .. it.itemId), it.ilvl, it.source or "", it.pct))
            y = y - 17
        end
    end
end

function GearInsight:BuildAdvancedPage(page, R)
    if page._built then renderPlan(page); return end
    page._built = true

    addText(page, 16, -40, T("ADV_INTRO",
        "三步闭环：①下面「导出装备」复制装备串 → ②到网站 gearinsight.app 分析页粘贴，"
        .. "看战力评分 / 缺件清单 / AI 建议 → ③把网站给的「复制回插件」回执串贴回下面，"
        .. "WCL 战力评分和 AI 教练点评就常驻在这页（插件自己拿不到网络数据，这是网站独有的）。"),
        "GameFontHighlightSmall", { 0.72, 0.72, 0.78 })

    -- 导出装备 / 网页版角色主页（从工具页挪来，点击逻辑不动）
    if R and R.export then
        R.export:SetParent(page); R.export:ClearAllPoints()
        R.export:SetPoint("TOPLEFT", 20, -104); R.export:SetSize(150, 28)
    end
    if R and R.web then
        R.web:SetParent(page); R.web:ClearAllPoints()
        R.web:SetPoint("TOPLEFT", 190, -109)
    end

    -- 导入框：多行 EditBox + 导入按钮 + 状态行
    addText(page, 16, -146, T("ADV_IMPORT_LABEL", "粘贴网站回执串（分析页 →「复制回插件」）："),
        "GameFontNormalSmall", { 1, 0.82, 0 })
    local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 20, -164)
    box:SetPoint("RIGHT", page, "RIGHT", -20, 0)
    box:SetHeight(56)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
                      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    box:SetBackdropColor(0.02, 0.02, 0.04, 0.9)
    box:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
    local sc = CreateFrame("ScrollFrame", nil, box)
    sc:SetPoint("TOPLEFT", 6, -5)
    sc:SetPoint("BOTTOMRIGHT", -6, 5)
    local eb = CreateFrame("EditBox", nil, sc)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetWidth(430)
    eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    sc:SetScrollChild(eb)
    box:SetScript("OnMouseDown", function() eb:SetFocus() end)
    page._importBox = eb

    local status = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 150, -235)
    status:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    status:SetJustifyH("LEFT")

    local btn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    btn:SetSize(120, 26)
    btn:SetPoint("TOPLEFT", 20, -228)
    btn:SetText(T("ADV_IMPORT_BTN", "导入分析结果"))
    btn:SetScript("OnClick", function()
        local plan, err = GearInsight:ImportWebPlan(eb:GetText())
        if plan then
            status:SetText("|cff5bd88a" .. T("ADV_IMPORT_OK", "已导入 ✓") .. "|r")
            eb:SetText("")
            eb:ClearFocus()
            renderPlan(page)
        else
            status:SetText("|cfff08a8a" .. (err or "?") .. "|r")
        end
    end)

    renderPlan(page)
end
