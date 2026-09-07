-- 主面板左侧标签页（2026-08-31 用户：「优化下UI，做标签翻页，类似公会那种，
-- 左侧是标签，点击标签直接换一整页」）。
-- 结构：4 个竖排大标签挂在面板左外侧；总览=原有装备内容（顶部按钮全部搬走），
-- 其余 3 页是盖在面板身体上的整页 Frame。原按钮只 SetParent 换页，点击逻辑不动。
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
        p._hd, p._line = hd, ln    -- 供副标题自适应换行时整体下移
        p:Hide()
        return p
    end

    local pgMeta  = newPage(T("MT_TAB_MM", "大秘境情报"))
    local pgTalent = newPage(T("MT_TAB_TAL", "天赋 · WCL 顶尖玩家"))
    local pgAdv = newPage(T("MT_TAB_ADV", "进阶 · 与网站互联"))
    local pgTools = newPage(T("MT_TAB_TOOLS", "实用工具"))
    local pgSet   = newPage(T("MT_TAB_SET", "设置"))
    local pgWish  = newPage(T("MT_TAB_WISH", "心愿单"))

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

    -- 设置页
    local setRows = {
        { R.tip,     T("MT_CAP_TIP",    "物品悬浮提示 BiS 行的显示范围、角色面板图标开关") },
    }
    y = -48
    for _, row in ipairs(setRows) do
        place(row[1], pgSet, 20, y, 160)
        caption(pgSet, 194, y - 7, row[2])
        y = y - 44
    end
    -- 设置总表（2026-09-06 玩家：「能否做一个总的配置表」）：所有开关一屏列齐，同一份也挂在 ESC → 选项 → 插件
    if GearInsight.BuildConfigPage then
        pcall(GearInsight.BuildConfigPage, pgSet, y - 4)
    end

    -- 使用率参照 / 团本装备 留在总览页（2026-08-31 用户：「这俩还是放到第一页吧」）：
    -- 它们直接改变总览数据的口径。右上区原来那排功能按钮已搬去工具页，正好空着。
    if R.mode then
        R.mode:SetParent(f); R.mode:ClearAllPoints()
        R.mode:SetPoint("TOPRIGHT", -16, -40); R.mode:SetSize(160, 24)
    end
    -- 刷新数据 + QQ 群回第一页（2026-09-01 用户：「刷新数据和QQ群都挪到第一页」；
    -- 玩家「喝咖啡会醉」同一天也提了「建议把刷新数据放回主页面」）。
    -- ⛔ 之前它们被搬去了设置页/工具页 —— 我一度以为是「被滚动列表压住」，
    --    其实是 SetParent 搬走了，位置怎么调都没用。挂回 f 才会在总览页露出。
    -- 左下角一列：刷新数据 + QQ 群。页脚版本/数据源两行已改靠右，两边不打架
    -- （2026-09-01 用户：「放到左下角别挡着」）。
    if R.refresh then
        R.refresh:SetParent(f); R.refresh:ClearAllPoints()
        R.refresh:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 10)
        R.refresh:SetSize(110, 24)
    end
    -- QQ 群单独一行、居中（2026-09-01 用户：「QQ群放到居中！别过来」）——
    -- 它在刷新按钮和页脚之上，左右两栏都不碰
    if R.qq then
        R.qq:SetParent(f); R.qq:ClearAllPoints()
        R.qq:SetPoint("BOTTOM", f, "BOTTOM", 0, 42)
        R.qq:SetSize(240, 18)
        if R.qq._giText then R.qq._giText:SetJustifyH("CENTER") end
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
        -- 心愿单（用户 2026-09-02：「直接集成到我的界面上」「不要附着其他的」）
        { key = "wish",     label = T("MT_TAB_WISH", "心愿单"),
          icon = "Interface\\ICONS\\INV_Misc_Note_04",       page = pgWish },
    }

    local function selectTab(key)
        GearInsightDB = GearInsightDB or {}
        GearInsightDB.mainTab = key
        -- bug #121（2026-09-06 心愿单页截图）：装备图的「装备图/列表」切换钮挂在主框上、层级 60，
        -- 盖过所有分页浮在心愿单/天赋/情报页上。它只属于总览页，切走就藏。
        if GearInsight._gmToggle then GearInsight._gmToggle:SetShown(key == "overview") end
        GearInsight._mainTabKey = key
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
        if key == "wish" and GearInsight.BuildWishlistPage then
            -- 每次开页都重建：清单会随「下一步建议」变，缓存住会让人看到旧的
            GearInsight:BuildWishlistPage(pgWish)
        end
        if key == "talent" then
            GearInsight._talentHost = pgTalent
            GearInsight:ShowTalentPicker(true)
        end
        if key == "mplus" then
            -- 顶头标数据日期（2026-08-31 用户：「情报顶头要说数据是哪天的」）
            -- ⛔ 副标题不许写死 x=128 的单行：中文就已经顶到右边框，英文"Season 2 · Week 5 ·
            --    Data as of ... · Same source as gearinsight.app"更长，直接溢出面板。
            --    改成：左边贴着页标题实际宽度、右边留 12 边距，放不下自动换行，
            --    换行了就把分隔线与下面的内容整体下移，不压行。
            local M2 = GearInsight.MplusMeta
            local mmExtra = 0
            if M2 and M2.date then
                if not pgMeta._mmSub then
                    local sub = pgMeta:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                    sub:SetJustifyH("LEFT"); sub:SetJustifyV("TOP")
                    if sub.SetWordWrap then sub:SetWordWrap(true) end
                    pgMeta._mmSub = sub
                end
                local sub = pgMeta._mmSub
                local hdW = (pgMeta._hd and pgMeta._hd:GetStringWidth() or 108)
                local left = 12 + hdW + 14
                local avail = (pgMeta:GetWidth() or 0) - left - 12
                if avail < 140 then avail = 140 end
                sub:ClearAllPoints()
                sub:SetPoint("TOPLEFT", left, -13)
                sub:SetWidth(avail)
                sub:SetText(GearInsight:MplusMetaTag(M2)
                    .. T("MM_DATA_TO", "数据截至") .. " " .. M2.date
                    .. " · " .. T("MM_SAME_SRC", "与官网 gearinsight.app 同源")
                    .. GearInsight:MplusMetaStaleText(M2))
                -- 行数：GetNumLines 在未布局时可能返回 0，用字符串高度兜底
                local lines = sub.GetNumLines and sub:GetNumLines() or 0
                if not lines or lines < 1 then
                    local _, fh = sub:GetFont()
                    local sh = sub:GetStringHeight() or 0
                    lines = (fh and fh > 0) and math.max(1, math.floor(sh / fh + 0.5)) or 1
                end
                if lines > 1 then mmExtra = (lines - 1) * 13 end
            end
            if pgMeta._line then
                pgMeta._line:ClearAllPoints()
                pgMeta._line:SetPoint("TOPLEFT", 8, -32 - mmExtra)
                pgMeta._line:SetPoint("TOPRIGHT", -8, -32 - mmExtra)
            end
            GearInsight:BuildMplusMetaContent(pgMeta, 10, -40 - mmExtra)
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
