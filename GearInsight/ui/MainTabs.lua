-- 主面板左侧标签页（2026-08-31 用户：「优化下UI，做标签翻页，类似公会那种，
-- 左侧是标签，点击标签直接换一整页」）。
-- 结构：4 个竖排大标签挂在面板左外侧；总览=原有装备内容（顶部按钮全部搬走），
-- 其余 3 页是盖在面板身体上的整页 Frame。原按钮只 SetParent 换页，点击逻辑不动。
GearInsight = GearInsight or {}
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local t = GearInsight.LOC and (GearInsight.LOC[_LOCALE] or GearInsight.LOC["enUS"])
    return (t and t[key]) or zh
end

local GOLD = { 1, 0.82, 0 }

function GearInsight:BuildMainTabs(f)
    local R = self._tabRefs or {}

    -- ── 整页容器（盖住面板身体；总览页=不盖） ──────────────────
    local function newPage(titleText)
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", 9, -40)
        p:SetPoint("BOTTOMRIGHT", -9, 9)
        p:SetFrameLevel(f:GetFrameLevel() + 40)
        local bg = p:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.08, 1)
        p:EnableMouse(true)                       -- 挡住底下总览的按钮/滚动
        p:EnableMouseWheel(true)
        p:SetScript("OnMouseWheel", function() end)
        local hd = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        hd:SetPoint("TOPLEFT", 12, -8)
        hd:SetText(titleText)
        hd:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        local ln = p:CreateTexture(nil, "ARTWORK")
        ln:SetColorTexture(0.3, 0.3, 0.3, 0.6)
        ln:SetPoint("TOPLEFT", 8, -32); ln:SetPoint("TOPRIGHT", -8, -32)
        ln:SetHeight(1)
        p:Hide()
        return p
    end

    local pgMeta  = newPage(T("MT_TAB_MM", "大秘境情报"))
    local pgTalent = newPage(T("MT_TAB_TAL", "天赋 · WCL 顶尖玩家"))
    local pgAdv = newPage(T("MT_TAB_ADV", "进阶 · 与网站互联"))
    local pgTools = newPage(T("MT_TAB_TOOLS", "实用工具"))
    local pgSet   = newPage(T("MT_TAB_SET", "设置"))

    -- ── 按钮搬家：SetParent 到目标页 + 统一排版（按钮自身 OnClick/Tooltip 不动） ──
    local function place(btn, page, x, y, w)
        if not btn then return end
        btn:SetParent(page)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", x, y)
        if w then btn:SetSize(w, 28) end
    end
    local function caption(page, x, y, text)
        local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetPoint("RIGHT", page, "RIGHT", -14, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(text)
        fs:SetTextColor(0.72, 0.72, 0.78)
        return fs
    end

    -- 工具页：一列大按钮 + 右侧一句说明
    if R.talent then R.talent:Hide() end   -- 天赋独立成页（2026-08-31），入口钮不再露出
    local toolRows = {
        { R.rot,    T("MT_CAP_ROT",    "顶尖玩家起手序列 / 技能频率 / BUFF 盯防") },
        { R.dg,     T("MT_CAP_DG",     "大米攻略：打断优先级 / 致死技能 / 承伤构成") },
        { R.farm,   T("MT_CAP_FARM",   "该刷哪个本：按对你的提升大小排序") },
        { R.ms,     T("MT_CAP_MS",     "多专精一起规划拾取，别错拾贪装") },
    }
    local y = -48
    for _, row in ipairs(toolRows) do
        place(row[1], pgTools, 20, y, 150)
        caption(pgTools, 184, y - 7, row[2])
        y = y - 40
    end
    -- QQ 群入口放工具页底部（网页版主页 → 进阶页）
    if R.qq then
        R.qq:SetParent(pgTools); R.qq:ClearAllPoints()
        R.qq:SetPoint("BOTTOM", pgTools, "BOTTOM", 0, 34)
    end

    -- 设置页
    local setRows = {
        { R.tip,     T("MT_CAP_TIP",    "物品悬浮提示 BiS 行的显示范围、角色面板图标开关") },
        { R.refresh, T("MT_CAP_REFRESH","重读当前装备并重算全部推荐") },
    }
    y = -48
    for _, row in ipairs(setRows) do
        place(row[1], pgSet, 20, y, 160)
        caption(pgSet, 194, y - 7, row[2])
        y = y - 44
    end

    -- 使用率参照 / 团本装备 留在总览页（2026-08-31 用户：「这俩还是放到第一页吧」）：
    -- 它们直接改变总览数据的口径。右上区原来那排功能按钮已搬去工具页，正好空着。
    if R.mode then
        R.mode:SetParent(f); R.mode:ClearAllPoints()
        R.mode:SetPoint("TOPRIGHT", -16, -40); R.mode:SetSize(160, 24)
    end
    if R.exRaid then
        R.exRaid:SetParent(f); R.exRaid:ClearAllPoints()
        R.exRaid:SetPoint("TOPRIGHT", -16, -68); R.exRaid:SetSize(160, 24)
    end

    -- ── 左侧标签轨（公会界面式竖排大标签） ─────────────────────
    local tabs = {
        { key = "overview", label = T("MT_TAB_OV", "装备总览"),
          icon = "Interface\\ICONS\\INV_Chest_Plate06",     page = nil },
        { key = "talent",   label = T("MT_TAB_TAL_SHORT", "天赋"),
          icon = "Interface\\ICONS\\Ability_Marksmanship",  page = pgTalent },
        { key = "adv",      label = T("MT_TAB_ADV_SHORT", "进阶"),
          icon = "Interface\\ICONS\\INV_Misc_Note_02",      page = pgAdv },
        { key = "tools",    label = T("MT_TAB_TOOLS", "实用工具"),
          icon = "Interface\\ICONS\\INV_Misc_Wrench_01",    page = pgTools },
        { key = "settings", label = T("MT_TAB_SET", "设置"),
          icon = "Interface\\ICONS\\Trade_Engineering",     page = pgSet },
        { key = "mplus",    label = T("MT_TAB_MM", "大秘境情报"),
          icon = "Interface\\ICONS\\INV_Relics_Hourglass",  page = pgMeta },
    }

    local function selectTab(key)
        GearInsightDB = GearInsightDB or {}
        GearInsightDB.mainTab = key
        for _, t in ipairs(tabs) do
            local sel = (t.key == key)
            if t.page then t.page:SetShown(sel) end
            if sel then
                t.btn:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
                t.btn:SetBackdropColor(0.13, 0.12, 0.07, 0.98)
                t.fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                t.ic:SetDesaturated(false)
            else
                t.btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.8)
                t.btn:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
                t.fs:SetTextColor(0.75, 0.75, 0.75)
                t.ic:SetDesaturated(true)
            end
        end
        if key == "adv" and GearInsight.BuildAdvancedPage then
            GearInsight:BuildAdvancedPage(pgAdv, R)
        end
        if key == "talent" then
            GearInsight._talentHost = pgTalent
            GearInsight:ShowTalentPicker(true)
        end
        if key == "mplus" then
            GearInsight:BuildMplusMetaContent(pgMeta, 10, -40)
            -- 顶头标数据日期（2026-08-31 用户：「情报顶头要说数据是哪天的」）
            local M2 = GearInsight.MplusMeta
            if M2 and M2.date and not pgMeta._mmSub then
                pgMeta._mmSub = pgMeta:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                pgMeta._mmSub:SetPoint("TOPLEFT", 128, -13)
                pgMeta._mmSub:SetText(GearInsight:MplusMetaTag(M2)
                    .. T("MM_DATA_TO", "数据截至") .. " " .. M2.date
                    .. " · " .. T("MM_SAME_SRC", "与官网 gearinsight.app 同源"))
            end
            if not pgMeta._mmRendered and not pgMeta._mmEmpty then
                pgMeta._mmEmpty = true
                local fs = pgMeta:CreateFontString(nil, "OVERLAY", "GameFontDisable")
                fs:SetPoint("TOP", 0, -80)
                fs:SetText(T("MM_NODATA", "大秘境情报数据未加载"))
            end
        end
    end

    local prev
    for _, t in ipairs(tabs) do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetSize(96, 48)
        if prev then b:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -6)
        else b:SetPoint("TOPRIGHT", f, "TOPLEFT", 2, -56) end
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        local ic = b:CreateTexture(nil, "ARTWORK")
        ic:SetSize(22, 22)
        ic:SetPoint("LEFT", 8, 0)
        ic:SetTexture(t.icon)
        ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", ic, "RIGHT", 6, 0)
        fs:SetPoint("RIGHT", -4, 0)
        fs:SetJustifyH("LEFT")
        fs:SetText(t.label)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0, 0.08)
        b:SetScript("OnClick", function() selectTab(t.key) end)
        t.btn, t.fs, t.ic = b, fs, ic
        prev = b
    end

    -- ⛔ 进阶页必须**立即**构建，不能等第一次点开：导出装备/网页主页按钮在它构建前
    -- 还挂在总览页的老锚点上，压住右上角两个开关（2026-08-31 用户截图「按钮位置不行」）。
    if self.BuildAdvancedPage then self:BuildAdvancedPage(pgAdv, R) end

    self._selectMainTab = selectTab
    selectTab("overview")   -- 每次打开都落在总览（⛔不记忆上次页：装备内容才是主场）
end
