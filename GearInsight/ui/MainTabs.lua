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

    -- ⛔ 「情报」页（大秘境榜 + PvP 榜）2026-09-10 整页下线：用户「这个功能在游戏内没有用，
    --    以后让大家去网上看」。五个文件搬到 clawhub services/wow-agent/_retired_intel/，
    --    数据仍在网站 gearinsight.app（/wow/en/mplus-meta、/wow/en/pvp-meta）与小程序里。
    local pgTalent = newPage(T("MT_TAB_TAL", "天赋 · WCL 顶尖玩家"))
    local pgAdv = newPage(T("MT_TAB_ADV", "进阶 · 与网站互联"))
    local pgTools = newPage(T("MT_TAB_TOOLS", "攻略"))
    local pgSet   = newPage(T("MT_TAB_SET", "设置"))
    -- 资讯（用户 2026-09-14）：插件更新 / 游戏版本 / 强度榜 / 关注 / 频道，一屏读完
    local pgNews  = newPage(T("MT_TAB_NEWS_TITLE", "资讯 · 更新 / 版本 / 趋势 / 关注"))
    local pgWish  = newPage(T("MT_TAB_WISH_TITLE", "刷本规划 · 缺什么、去哪刷"))
    -- PvP 装备（用户 2026-09-10）：每部位上榜玩家穿的副属性版本 —— 独立页签，与天赋页同款形态
    local pgPvp   = newPage(T("MT_TAB_PVP_TITLE", "PvP 装备 · 上榜玩家怎么穿"))
    -- 键位（用户 2026-09-18）：按 WCL 顶尖玩家按键频率一键铺动作条 + 备份/还原 + MySlot 串；ui/LayoutPage.lua
    local pgLayout = newPage(T("MT_TAB_LAYOUT_TITLE", "智能键位+宏 · 按 WCL 顶尖玩家按键铺动作条 / 宏库 / 自动分键"))
    -- 万奥宝典并入天赋页（用户 2026-09-14「万奥宝典做到天赋页吧」）：右上 [天赋库 | 万奥宝典] 子切换，
    -- 宝典内容画在 pgTalent 的子框 _cxFrame 里，与天赋库互斥显示。
    do
        local cx = CreateFrame("Frame", nil, pgTalent)
        cx:SetPoint("TOPLEFT", 0, 0); cx:SetPoint("BOTTOMRIGHT", 0, 0)
        cx:SetFrameLevel(pgTalent:GetFrameLevel() + 2)
        cx._cxTop = 28          -- 自己的按钮行让出顶部一排给子切换
        cx:Hide()
        pgTalent._cxFrame = cx
        local function mk(label, key, anchorTo)
            local b = CreateFrame("Button", nil, pgTalent, "UIPanelButtonTemplate")
            b:SetSize(96, 22)
            if anchorTo then b:SetPoint("RIGHT", anchorTo, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", -14, -6) end
            b:SetText(label)
            b:SetFrameLevel(pgTalent:GetFrameLevel() + 5)
            b:SetScript("OnClick", function() GearInsight:SelectTalentSub(key) end)
            b._bar = b:CreateTexture(nil, "OVERLAY"); b._bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.95)
            b._bar:SetPoint("BOTTOMLEFT", 6, 1); b._bar:SetPoint("BOTTOMRIGHT", -6, 1); b._bar:SetHeight(2); b._bar:Hide()
            return b
        end
        pgTalent._subCodex = mk(T("MT_TAB_CODEX", "万奥宝典"), "codex")
        pgTalent._subTal = mk(T("MT_SUB_TAL", "天赋库"), "talent", pgTalent._subCodex)
        function GearInsight:SelectTalentSub(key)
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.talentSub = key
            local pk = self._talentPickerFrame
            if key == "codex" then
                if pk then pk:Hide() end
                pgTalent._hd:SetText(T("MT_TAB_CODEX_TITLE", "万奥宝典 · 顶尖玩家怎么选"))
                cx:Show()
                if self.BuildCodexPage then self:BuildCodexPage(cx) end
            else
                cx:Hide()
                pgTalent._hd:SetText(T("MT_TAB_TAL", "天赋 · WCL 顶尖玩家"))
                self._talentHost = pgTalent
                self:ShowTalentPicker(true)
                if self._talentPickerFrame then self._talentPickerFrame:Show() end
            end
            -- 选中：金字 + 底部金条 + 不透明；未选：灰字 + 半透明（用户 2026-09-14「选中状态更加明显一点」）
            for btn, sel in pairs({ [pgTalent._subCodex] = (key == "codex"), [pgTalent._subTal] = (key ~= "codex") }) do
                local fs = btn:GetFontString()
                if sel then fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3]); btn:SetAlpha(1); btn._bar:Show()
                else fs:SetTextColor(0.6, 0.6, 0.6); btn:SetAlpha(0.6); btn._bar:Hide() end
            end
        end
    end

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
    if R.farm then R.farm:Hide() end       -- 刷本优先级并入「刷本助手」页签（2026-09-11），老按钮删掉
    if R.ms then R.ms:Hide() end           -- 多专精拾取并入「刷本助手」专精行（2026-09-12），老按钮删掉
    local toolRows = {
        { R.rot,    T("MT_CAP_ROT",    "顶尖玩家起手序列 / 技能频率 / BUFF 盯防") },
        { R.dg,     T("MT_CAP_DG",     "大米攻略：打断优先级 / 致死技能 / 承伤构成") },
    }
    local y = -48
    for _, row in ipairs(toolRows) do
        place(row[1], pgTools, 20, y, 150)
        caption(pgTools, 184, y - 7, row[2])
        y = y - 40
    end
    -- 更多功能在站外（用户 2026-09-11「这个页面增加提示，更多功能去网站(根据语言)，小程序（中文都推荐）」）：
    --   网站按客户端语言：中文 → gearinsight.cn（国内直连），其它 → gearinsight.app；
    --   小程序只对中文客户端推荐（微信搜「GearInsight」）。点击地址 = 弹复制框。
    do
        local loc = GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
        local zh = (loc == "zhCN" or loc == "zhTW")
        local site = zh and "gearinsight.cn" or "gearinsight.app"
        y = y - 14
        local sep = pgTools:CreateTexture(nil, "ARTWORK")
        sep:SetPoint("TOPLEFT", 20, y); sep:SetPoint("RIGHT", pgTools, "RIGHT", -20, 0); sep:SetHeight(1)
        sep:SetColorTexture(1, 0.82, 0, 0.25)
        y = y - 12
        local hd = pgTools:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hd:SetPoint("TOPLEFT", 20, y); hd:SetText(T("MT_MORE_TITLE", "更多功能在站外"))
        y = y - 26
        local function linkRow(label, url, hint)
            local fs = pgTools:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", 24, y); fs:SetPoint("RIGHT", pgTools, "RIGHT", -14, 0)
            fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
            fs:SetText(label .. "  |cFF66CCFF" .. url .. "|r  |cFF8A93A6" .. hint .. "|r")
            local b = CreateFrame("Button", nil, pgTools)
            b:SetPoint("TOPLEFT", fs, "TOPLEFT", 0, 2); b:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 0, -2)
            b:SetScript("OnClick", function()
                GearInsight:ShowCopyText(url, T("MT_MORE_COPY", "Ctrl+C 复制，到浏览器打开"), label)
            end)
            b:SetScript("OnEnter", function(s2)
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT"); GameTooltip:SetText(T("MT_MORE_CLICK", "点击复制地址"), 1, 0.82, 0); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            y = y - 22
        end
        linkRow(T("MT_MORE_SITE", "网站"), site,
            T("MT_MORE_SITE_HINT", "大秘境 / PvP 情报榜 · 装备分析 · 天赋视图 · 更新日志"))
        if zh then
            linkRow(T("MT_MORE_MP", "微信小程序"), T("MT_MORE_MP_NAME", "微信搜「GearInsight」"),
                T("MT_MORE_MP_HINT", "手机上查 BiS / 掉落 / PvP 装备，随时看"))
        end
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
    if R.tier then
        R.tier:SetParent(f); R.tier:ClearAllPoints()
        R.tier:SetPoint("TOPRIGHT", -16, -96); R.tier:SetSize(160, 24)
    end

    -- ── 左侧标签轨（公会界面式竖排大标签） ─────────────────────
    local tabs = {
        { key = "overview", label = T("MT_TAB_OV", "装备总览"),
          icon = "Interface\\ICONS\\INV_Chest_Plate06",     page = nil },
        { key = "news",     label = T("MT_TAB_NEWS", "资讯"),
          icon = "Interface\\ICONS\\INV_Misc_ScrollUnrolled02",   page = pgNews },
        -- 2026-09-12 改名「刷本助手」并提到第二位（用户）：装备总览之后就是「去哪刷」
        { key = "wish",     label = T("MT_TAB_WISH", "刷本规划"),
          icon = "Interface\\ICONS\\INV_Misc_Key_14",        page = pgWish },
        { key = "talent",   label = T("MT_TAB_TAL_SHORT", "天赋"),
          icon = "Interface\\ICONS\\Ability_Marksmanship",  page = pgTalent },
        { key = "adv",      label = T("MT_TAB_ADV_SHORT", "进阶"),
          icon = "Interface\\ICONS\\INV_Misc_Note_02",      page = pgAdv },
        { key = "tools",    label = T("MT_TAB_TOOLS", "攻略"),
          icon = "Interface\\ICONS\\INV_Misc_Wrench_01",    page = pgTools },
        { key = "settings", label = T("MT_TAB_SET", "设置"),
          icon = "Interface\\ICONS\\Trade_Engineering",     page = pgSet },
        -- 心愿单（用户 2026-09-02：「直接集成到我的界面上」「不要附着其他的」）

        { key = "pvp",      label = T("MT_TAB_PVP", "PvP 装备"),
          icon = "Interface\\ICONS\\Achievement_BG_winWSG",  page = pgPvp },
        { key = "layout",   label = T("MT_TAB_LAYOUT", "智能键位+宏"),
          icon = "Interface\\ICONS\\INV_Misc_Gear_01",       page = pgLayout },
    }
    -- 智能键位+宏 模块加载：GearInsightDB.layoutModule = "on"（以后点页签直接加载）/ "off"（不加载，页上只留一个「加载」按钮）/ nil（问）
    function GearInsight:EnsureLayoutModule(page)
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        if isLoaded("GearInsight_Layout") then
            if self.BuildLayoutPage then self:BuildLayoutPage(page) end
            return
        end
        local function doLoad()
            local ok, reason
            if C_AddOns and C_AddOns.LoadAddOn then ok, reason = C_AddOns.LoadAddOn("GearInsight_Layout") else ok, reason = LoadAddOn("GearInsight_Layout") end
            if not ok and reason == "DISABLED" then
                pcall(C_AddOns.EnableAddOn, "GearInsight_Layout")
                if C_AddOns and C_AddOns.LoadAddOn then ok, reason = C_AddOns.LoadAddOn("GearInsight_Layout") end
            end
            if ok and self.BuildLayoutPage then
                if page._modHint then page._modHint:Hide() end
                if page._modBtn then page._modBtn:Hide() end
                self:BuildLayoutPage(page)
            elseif not ok then
                self:Print(T("MT_LAYOUT_LOAD_FAIL", "加载「GearInsight_Layout」失败：") .. tostring(reason) .. T("MT_LAYOUT_LOAD_FAIL2", "（插件列表里有没有 GearInsight_Layout？）"))
            end
        end
        GearInsightDB = GearInsightDB or {}
        if GearInsightDB.layoutModule == "on" then doLoad(); return end
        -- 页上放一段说明 + 「加载」按钮；第一次进来再弹一次确认
        if not page._modHint then
            local h = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            h:SetPoint("TOPLEFT", 16, -48); h:SetPoint("RIGHT", -16, 0); h:SetJustifyH("LEFT"); h:SetSpacing(3)
            h:SetText(T("MT_LAYOUT_MOD_HINT", "「智能键位+宏」是独立模块（GearInsight_Layout）：按 WCL 顶尖玩家的按键频率一键铺动作条、智能分键、宏库、备份 / 还原、MySlot 导出。\n默认不加载，不占内存；点下面的按钮加载，选「以后自动加载」就不再问。"))
            page._modHint = h
            local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            b:SetSize(200, 32); b:SetPoint("TOPLEFT", 16, -48 - 90); b:SetText(T("MT_LAYOUT_MOD_BTN", "加载智能键位+宏模块"))
            b:SetScript("OnClick", function() StaticPopup_Show("GEARINSIGHT_LAYOUT_MODULE") end)
            page._modBtn = b
        end
        page._modHint:Show(); page._modBtn:Show()
        StaticPopupDialogs["GEARINSIGHT_LAYOUT_MODULE"] = StaticPopupDialogs["GEARINSIGHT_LAYOUT_MODULE"] or {
            text = T("MT_LAYOUT_MOD_ASK", "要加载「智能键位+宏」模块吗？\n\n一键铺动作条 / 智能分键 / 宏库 / 备份还原。\n加载后本次登录一直在；选「以后自动加载」下次点页签直接开。"),
            button1 = T("MT_LAYOUT_MOD_YES", "以后自动加载"), button2 = T("MT_LAYOUT_MOD_ONCE", "只这次加载"), button3 = T("MT_LAYOUT_MOD_NO", "不加载"),
            OnAccept = function() GearInsightDB.layoutModule = "on"; doLoad() end,
            OnCancel = function(_, _, reason) if reason == "clicked" then GearInsightDB.layoutModule = nil; doLoad() end end,
            OnAlt = function() GearInsightDB.layoutModule = "off" end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        if GearInsightDB.layoutModule ~= "off" and not page._asked then
            page._asked = true
            StaticPopup_Show("GEARINSIGHT_LAYOUT_MODULE")
        end
    end

    -- 一键输出（GSE 宏）页 2026-09-18 整页删除：国服客户端上 /click 施法全部「法术还没有准备好」，排查一天无果，用户放弃。
    if GearInsightDB and GearInsightDB.mainTab == "macro" then GearInsightDB.mainTab = "overview" end

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
            -- 记住上次在天赋库还是万奥宝典（默认天赋库）
            GearInsight:SelectTalentSub((GearInsightDB and GearInsightDB.talentSub) or "talent")
        end
        if key == "news" and GearInsight.BuildNewsPage then
            GearInsight:BuildNewsPage(pgNews)
        end
        if key == "layout" then
            -- 「智能键位+宏」在 LoD 子插件 GearInsight_Layout 里（用户 2026-09-18「单独拆个模块，默认不读取，进来提示问要不要加载，之后记录」）
            GearInsight:EnsureLayoutModule(pgLayout)
        end
        if key == "pvp" and GearInsight.BuildPvpGearPage then
            -- 每次进页重画：身上装备会变（√/× 列要跟着变）
            GearInsight:BuildPvpGearPage(pgPvp)
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
