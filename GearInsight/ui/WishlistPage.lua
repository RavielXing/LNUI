-- 心愿单页 —— 「可提升部位」概览。
--
-- ⛔⛔ 2026-09-02 重做。上一版把 BiS 全表 53 条平铺出来，玩家原话
--    「非常难看，也不知道怎么用」「装等都不对」。三个病根：
--      ① 53 条里绝大多数是「你已经穿着的 / 根本轮不到的」，真正有决策价值的
--         只有「哪几个部位还能提升、提升多少」——最多十几行；
--      ② 右边一个光秃秃的百分比，建议模式是「提升幅度」、回退模式是「实穿率」，
--         两个数长得一样、含义完全不同，不标注就是误导；
--      ③ 悬停读到的是**基准装等**而不是目标 BiS 装等
--         （没把 bonusIDs 嫁接到链接上，本插件别处早有同款做法）。
--
-- ⛔ 这一页不给玩家增删（用户 2026-09-02：「不让用户选了」）。
--    清单跟着装备自动走 —— 插件自己算得出「你缺什么」，
--    不该把维护成本推回给玩家（竞品 KeystoneLoot 要逐件手勾，那正是我们不做的）。

GearInsight = GearInsight or {}
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    -- 逐级回退：当前语言 -> enUS -> 内联中文。
    -- ⛔别写回 `LOC[_LOCALE] or LOC["enUS"]`（选表不选值）。
    local L = GearInsight.LOC or {}
    local cur = L[_LOCALE]
    if cur and cur[key] then return cur[key] end
    if _LOCALE ~= "zhTW" then
        local en = L["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

local ROW_H = 30
local GOLD = { 0.84, 0.70, 0.42 }
local QMARK = "Interface/Icons/INV_Misc_QuestionMark"

local function slotName(slotId)
    local gr = GearInsight.GearReader
    local key = gr and gr.GetSlotKey and gr:GetSlotKey(slotId)
    local L = GearInsight.L or {}
    return (key and L[key]) or ("#" .. tostring(slotId))
end

local function iconOf(idOrLink)
    if not idOrLink then return QMARK end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return QMARK end
    -- ⛔ 别写成 `select(10, A and A.f(x) or f(x))`：and/or 会把多返回值截成一个，
    --    select(10, ...) 于是恒为 nil（图标永远是问号，且不报错）。
    local tex = select(10, getInfo(idOrLink))
    return tex or QMARK
end

-- 专精芯片：画本职业全部专精，返回本次要一起建模的专精列表（当前专精永远第一个）。
-- 勾选状态存 GearInsight:_msSelected()（与「复制需求单」/老多专精窗口同一份，三处口径一致）。
function GearInsight._wlRenderSpecChips(page, class, curSpec)
    local row = page._fgSpecRow
    if not row then return { curSpec } end
    local bd = GearInsight.BisData
    local specs = bd and bd.GetClassSpecs and bd:GetClassSpecs(class) or {}
    local cur = (curSpec or ""):upper()
    local infos = {}
    for _, sp in ipairs(specs) do
        local key = (sp.specName or ""):upper()
        if key ~= "" then infos[#infos + 1] = GearInsight.SpecChipInfo(class, key) end
    end
    table.sort(infos, function(a, b)
        if (a.key == cur) ~= (b.key == cur) then return a.key == cur end
        return (a.name or "") < (b.name or "")
    end)
    local sel = GearInsight._msSelected and GearInsight:_msSelected() or {}
    for _, ch in ipairs(row.chips) do ch:Hide() end
    local x = (row.label:GetStringWidth() or 80) + 8
    local out = { cur }
    for i, info in ipairs(infos) do
        local ch = row.chips[i]
        if not ch then
            ch = CreateFrame("Button", nil, row, "BackdropTemplate")
            ch:SetHeight(20)
            ch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            ch.icon = ch:CreateTexture(nil, "ARTWORK"); ch.icon:SetSize(16, 16); ch.icon:SetPoint("LEFT", 3, 0)
            ch.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            ch.txt = ch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); ch.txt:SetPoint("LEFT", ch.icon, "RIGHT", 4, 0)
            ch:SetScript("OnClick", function(s2)
                if s2._isCur then return end
                local m = GearInsight:_msSelected()
                m[s2._key] = (not m[s2._key]) and true or nil
                GearInsight:BuildWishlistPage(page)
            end)
            ch:SetScript("OnEnter", function(s2)
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                if s2._isCur then
                    GameTooltip:SetText(T("WLP_SPEC_CUR_TIP", "当前专精，总是包含在内。"), 1, 1, 1, 1, true)
                else
                    GameTooltip:SetText(T("WLP_SPEC_TIP", "点一下把这个专精的缺件也合进来一起刷：同一个本掉的件按专精合并，格子右下角的小图标标出谁要它。\n副专精的件在背包里也算已获得。"), 1, 1, 1, 1, true)
                end
                GameTooltip:Show()
            end)
            ch:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.chips[i] = ch
        end
        local isCur = (info.key == cur)
        local on = isCur or (sel[info.key] and true or false)
        if on and not isCur then out[#out + 1] = info.key end
        ch._key, ch._isCur = info.key, isCur
        if info.icon then ch.icon:SetTexture(info.icon); ch.icon:Show() else ch.icon:Hide() end
        ch.icon:SetDesaturated(not on)
        ch.txt:SetText((info.name or info.key) .. (isCur and (" |cFF888888" .. T("WLP_SPEC_CUR", "当前") .. "|r") or ""))
        ch.txt:SetTextColor(on and 1 or 0.6, on and 0.9 or 0.6, on and 0.6 or 0.6)
        if on then
            ch:SetBackdropColor(0.35, 0.28, 0.08, 0.9); ch:SetBackdropBorderColor(1, 0.82, 0.2, 0.9)
        else
            ch:SetBackdropColor(0.12, 0.12, 0.14, 0.8); ch:SetBackdropBorderColor(0.35, 0.35, 0.38, 0.8)
        end
        local w = 3 + 16 + 4 + (ch.txt:GetStringWidth() or 40) + 8
        ch:SetWidth(w)
        ch:ClearAllPoints(); ch:SetPoint("LEFT", x, 0); ch:Show()
        x = x + w + 6
    end
    return out
end

function GearInsight:BuildWishlistPage(page)
    if not page then return end

    if not page._wlBuilt then
        page._wlBuilt = true

        -- 一句话说清这页干什么。⛔ 没有这句，玩家打开只看到一堆物品名。
        local intro = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        intro:SetPoint("TOPLEFT", 12, -40)
        intro:SetPoint("TOPRIGHT", -12, -40)
        intro:SetJustifyH("LEFT")
        if intro.SetWordWrap then intro:SetWordWrap(true) end
        intro:SetText(T("WLP_INTRO2",
            "缺的装备按副本排好、去哪刷一眼看清；队伍里掉到你能提升的部位会弹框提醒，可一键私聊问要。清单跟着你的装备走。"))
        page._wlIntro = intro

        local tg = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        -- 控制区 = 3×2 等宽网格（150×22，横距 8、行距 4）：上排 提醒/试一发/视图，下排 第一BiS/团本装备/团本难度
        local BW, BH, BG = 150, 22, 8
        tg:SetSize(BW, BH)
        tg:SetPoint("TOPLEFT", 12, -74)
        tg:SetScript("OnClick", function()
            if GearInsight.ToggleWishAlert then GearInsight:ToggleWishAlert() end
            GearInsight:BuildWishlistPage(page)
        end)
        tg:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("WLP_TOGGLE_TIP",
                "队友在队伍里捡到你能提升的东西时弹窗提醒。|n只对别人拾取生效，自己捡到不打扰。"),
                1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        tg:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page._wlToggle = tg

        local demo = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        demo:SetSize(BW, BH)
        demo:SetPoint("LEFT", tg, "RIGHT", BG, 0)
        demo:SetText(T("WLP_DEMO", "试一发"))
        demo:SetScript("OnClick", function()
            if GearInsight.WishPopupDemo then GearInsight:WishPopupDemo() end
        end)
        demo:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("WLP_DEMO_TIP",
                "弹一个示例提醒，看看真触发时长什么样。|n8 秒后自动消失，不抢焦点。"),
                1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        demo:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- 视图切换：按副本（KeystoneLoot 式网格）/ 按部位（原心愿单表）
        local vw = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        vw:SetSize(BW, BH); vw:SetPoint("LEFT", demo, "RIGHT", BG, 0)
        vw:SetScript("OnClick", function()
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.wlView = (GearInsightDB.wlView == "slot") and "src" or "slot"
            GearInsight:BuildWishlistPage(page)
        end)
        page._wlViewBtn = vw
        -- 「第一BiS: 只看/全部」（原刷本优先级弹窗的开关，逻辑在 ShowFarmingGuide）
        local ob = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        -- ⛔ 第二行（虔诚 2026-09-12：六个按钮一行超出面板框）：第一BiS / 团本装备 / 团本难度
        ob:SetSize(BW, BH); ob:SetPoint("TOPLEFT", tg, "BOTTOMLEFT", 0, -4)
        ob:SetScript("OnClick", function()
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.fgOnlyTopBis = not GearInsightDB.fgOnlyTopBis
            GearInsight:BuildWishlistPage(page)
            if GearInsight.Print then
                GearInsight:Print(GearInsightDB.fgOnlyTopBis and T("FG_ONLYTOP_ON", "第一BiS: 只看") or T("FG_ONLYTOP_OFF", "第一BiS: 全部"))
            end
        end)
        ob:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("FG_ONLYTOP_TIP",
                "只显示每个部位排第一的毕业件。\n戒指/饰品留前 2、武器按双持/双手留 1–2；套装部位只留第一名坯子。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        ob:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page._fgOnlyBtn = ob
        -- 团本装备 包含/排除（用户 2026-09-12「带不带团本装备做个筛选」）：与总览页同一个开关（SetExcludeRaid），
        -- 切了两边都变；SetExcludeRaid 会走 _refreshOpenPopups 把本页重画
        local xr = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        xr:SetSize(BW, BH); xr:SetPoint("LEFT", ob, "RIGHT", BG, 0)
        xr:SetScript("OnClick", function()
            local on = GearInsightDB and GearInsightDB.excludeRaid
            if GearInsight.SetExcludeRaid then GearInsight:SetExcludeRaid(not on) end
            GearInsight:BuildWishlistPage(page)
        end)
        xr:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("WLP_EXRAID_TIP", "不打团本就点「排除」：清单里只留大秘境 / 制造等非团本来源。\n与装备总览页的开关是同一个。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        xr:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page._wlExRaid = xr
        -- 团本难度档（用户 2026-09-12「带团本装备是 H 还是 M 也做一个」）：BiS 目标装等按哪档算，与设置页同一个开关
        local gt = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        gt:SetSize(BW, BH); gt:SetPoint("LEFT", xr, "RIGHT", BG, 0)
        gt:SetScript("OnClick", function()
            local cur = (GearInsight.GetGearTier and GearInsight:GetGearTier()) or "mythic"
            local nxt = (cur == "mythic") and "heroic" or ((cur == "heroic") and "normal" or "mythic")
            if GearInsight.SetGearTier then GearInsight:SetGearTier(nxt) end
            GearInsight:BuildWishlistPage(page)
        end)
        gt:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("WLP_TIER_TIP", "团本装备按哪个难度算目标装等：史诗 / 英雄 / 普通。打不了史诗就切英雄，缺件和装等差距都按英雄档算。\n与设置页的「参照难度档」是同一个开关。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        gt:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page._wlTier = gt

        -- ⛔⛔ 只写 LEFT 锚点 = 这行文字没有右边界，长了就直接画到面板外面去
        --    （玩家 2026-09-02 截图：「来源：BiS 全表（建议数据不新鲜）」出框）。
        --    两点锚定才有边界；再关掉换行，超长自己截断而不是撑破面板。
        local stat = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        stat:SetPoint("LEFT", gt, "RIGHT", 14, 0)
        stat:SetPoint("RIGHT", page, "RIGHT", -12, 0)
        stat:SetJustifyH("LEFT")
        if stat.SetWordWrap then stat:SetWordWrap(false) end
        page._wlStat = stat

        -- 长警告收进悬停提示：一行里塞不下「（建议数据不新鲜）」这么长的话，
        -- 屏幕上只留一个 ⚠，把原因放到 tooltip 里。
        local statHit = CreateFrame("Button", nil, page)
        statHit:SetPoint("TOPLEFT", stat, "TOPLEFT", 0, 2)
        statHit:SetPoint("BOTTOMLEFT", stat, "BOTTOMLEFT", 0, -2)
        statHit:SetWidth(10)
        page._wlStatHit = statHit
        statHit:SetScript("OnEnter", function(s2)
            if not page._wlStatTip then return end
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:ClearLines(); GameTooltip:AddLine(page._wlStatTip, 1, 1, 1, true)  -- 12.x SetText 只收 4 参，wrap 走 AddLine
            GameTooltip:Show()
        end)
        statHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- 表头。⛔ 上一版没有表头，右边那个数字谁也不知道是什么。
        local hdr = CreateFrame("Frame", nil, page)
        hdr:SetPoint("TOPLEFT", 12, -132)
        hdr:SetPoint("TOPRIGHT", -28, -132)
        hdr:SetHeight(18)
        local function col(text)
            local fs = hdr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            fs:SetJustifyH("LEFT")
            fs:SetText(text)
            return fs
        end
        -- ⛔⛔ 别用 page:GetWidth() 算列位置：建页那一刻面板还没布局完，
        --    它返回的是兜底值，整套列会按一个比实际窄得多的宽度挤在左边
        --    （玩家 2026-09-02 截图：表头缩在左半边）。
        --    改成**相对锚点**：右侧两列贴右边、中间两列互相顶着，宽度自己撑开。
        page._wlHSlot = col(T("WLP_COL_SLOT", "部位"))
        page._wlHSlot:SetPoint("LEFT", 4, 0)
        page._wlHSlot:SetWidth(52)

        page._wlHBell = col(T("WLP_COL_BELL", "提醒"))
        page._wlHBell:SetJustifyH("CENTER")
        page._wlHBell:SetPoint("RIGHT", -6, 0)
        page._wlHBell:SetWidth(30)

        page._wlHGain = col(T("WLP_COL_GAIN", "可提升"))
        page._wlHGain:SetJustifyH("RIGHT")
        page._wlHGain:SetPoint("RIGHT", page._wlHBell, "LEFT", -6, 0)
        page._wlHGain:SetWidth(50)

        page._wlHCur = col(T("WLP_COL_CUR", "当前"))
        page._wlHCur:SetPoint("LEFT", 60, 0)

        page._wlHTgt = col(T("WLP_COL_TGT", "目标"))
        page._wlHTgt:SetPoint("LEFT", hdr, "CENTER", -44, 0)   -- 与行内箭头右侧对齐
        page._wlHdr = hdr

        local ln = page:CreateTexture(nil, "ARTWORK")
        ln:SetColorTexture(0.3, 0.3, 0.3, 0.6)
        ln:SetPoint("TOPLEFT", 12, -150)
        ln:SetPoint("TOPRIGHT", -28, -150)
        ln:SetHeight(1)
        page._wlLine = ln

        local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -156)
        scroll:SetPoint("BOTTOMRIGHT", -28, 10)
        local sc = CreateFrame("Frame", nil, scroll)
        sc:SetSize(1, 1)
        scroll:SetScrollChild(sc)
        page._wlScroll, page._wlChild = scroll, sc
        sc.rows = {}

        -- ── 专精行（2026-09-12 多专精并入）：当前专精常亮不可关；点别的专精 = 一起刷，格子右下角标谁要 ──
        local specRow = CreateFrame("Frame", nil, page)
        specRow:SetPoint("TOPLEFT", 12, -128); specRow:SetPoint("TOPRIGHT", -12, -128); specRow:SetHeight(24)
        local sl = specRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sl:SetPoint("LEFT", 0, 0); sl:SetText(T("WLP_SPECS_LBL", "一起刷的专精:"))
        specRow.label = sl; specRow.chips = {}
        -- 「复制需求单」：按勾选专精生成逐 BOSS 需求单文本（原多专精拾取窗口的功能）
        local nb = CreateFrame("Button", nil, specRow, "UIPanelButtonTemplate")
        nb:SetSize(132, 20); nb:SetPoint("RIGHT", 0, 0)
        nb:SetText(T("MS_NEED_BTN", "复制需求单文本"))
        nb:SetScript("OnClick", function() if GearInsight.ShowNeedSheet then GearInsight:ShowNeedSheet() end end)
        nb:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("MS_NEED_TIP", "按上方勾选的专精生成逐BOSS需求单文本\n（拾取设置/需求装备/掷币推荐），复制后发给团长/队友"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        nb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        specRow.needBtn = nb
        page._fgSpecRow = specRow

        -- 按副本视图：独立滚动区（网格由 ShowFarmingGuide(host=page) 画进 page._fgChild）
        local fscroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        fscroll:SetPoint("TOPLEFT", 12, -156)
        fscroll:SetPoint("BOTTOMRIGHT", -28, 10)
        local fsc = CreateFrame("Frame", nil, fscroll)
        fsc:SetSize(1, 1)
        fscroll:SetScrollChild(fsc)
        page._fgScroll, page._fgChild = fscroll, fsc
        local specLine = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        specLine:SetPoint("LEFT", vw, "RIGHT", 14, 0); specLine:SetPoint("RIGHT", page, "RIGHT", -30, 0); specLine:SetPoint("TOP", tg, "TOP", 0, 0)
        specLine:SetJustifyH("RIGHT"); specLine:SetWordWrap(false); specLine:Hide()
        page._fgSpecLine = specLine
    end

    -- ── 视图分发：按副本（默认）/ 按部位 ──
    GearInsightDB = GearInsightDB or {}
    local view = GearInsightDB.wlView or "src"
    page._wlViewBtn:SetText(view == "src" and T("WLP_VIEW_SRC", "视图: 按副本") or T("WLP_VIEW_SLOT", "视图: 按部位"))
    page._fgOnlyBtn:SetText((GearInsightDB.fgOnlyTopBis) and T("FG_ONLYTOP_ON", "第一BiS: 只看") or T("FG_ONLYTOP_OFF", "第一BiS: 全部"))
    page._wlExRaid:SetText(GearInsightDB.excludeRaid and T("EXRAID_BTN_ON", "团本装备: 排除") or T("EXRAID_BTN_OFF", "团本装备: 包含"))
    page._wlTier:SetText(T("WLP_TIER_LBL", "团本难度: ") .. ((GearInsight.GearTierLabel and GearInsight:GearTierLabel()) or ""))
    page._wlTier:SetShown(not GearInsightDB.excludeRaid)
    local bySrc = (view == "src")
    page._wlHdr:SetShown(not bySrc); page._wlLine:SetShown(not bySrc); page._wlScroll:SetShown(not bySrc)
    page._fgScroll:SetShown(bySrc); page._fgOnlyBtn:SetShown(bySrc); page._fgSpecRow:SetShown(bySrc)
    if bySrc then
        local sw = page._fgScroll:GetWidth() or 0
        page._fgChild:SetWidth(math.max(380, math.floor(sw > 1 and sw or ((page:GetWidth() or 460) - 44))))
        local c, s2, h
        if GearInsight.StatReader then
            local ok, st = pcall(function() return GearInsight.StatReader:ReadAll() end)
            if ok and st then c, s2, h = st.class, st.spec, st.heroTalent end
        end
        if c and s2 then
            local specs = GearInsight._wlRenderSpecChips and GearInsight._wlRenderSpecChips(page, c, s2) or { s2 }
            if #specs > 1 and GearInsight.ShowFarmingGuideMulti then
                GearInsight:ShowFarmingGuideMulti(c, specs, h, page)
            else
                GearInsight:ShowFarmingGuide(c, s2, h, true, page)
            end
        end
    end

    local list = (GearInsight.GetUpgradeSlots and GearInsight.GetUpgradeSlots()) or {}
    local src = "none"
    if GearInsight.GetWishlist then
        local _, s2 = GearInsight.GetWishlist()
        src = s2 or "none"
    end

    local SRC = {
        recs = T("WLP_SRC_RECS", "下一步建议"),
        bis  = T("WLP_SRC_BIS",  "BiS 全表"),
        none = T("WLP_SRC_NONE", "暂无数据"),
    }
    page._wlStat:SetText(string.format(
        T("WLP_STAT", "%d 个可提升部位  ·  来源：%s"), #list, SRC[src] or SRC.none)
        .. (src == "bis" and "  |cffffcc00!|r" or ""))
    page._wlStatTip = (src == "bis") and T("WLP_STAT_TIP_BIS",
        "现在用的是 BiS 全表兜底，不是按你当前配装算出来的下一步建议。|n"
        .. "多半是数据不新鲜了 —— 在「装备总览」刷新一次就会换成更准的来源。") or nil
    -- 命中框只有文字那么宽、且只在有提示时接鼠标
    if page._wlStatHit then
        page._wlStatHit:SetWidth(math.max(10, math.min(page._wlStat:GetStringWidth() or 10, (page._wlStat:GetWidth() or 200))))
        page._wlStatHit:EnableMouse(page._wlStatTip ~= nil)
    end

    local on = not (GearInsightDB and GearInsightDB.wishAlertOff)
    page._wlToggle:SetText(on and T("WLP_ON", "掉落提醒: 开") or T("WLP_OFF", "掉落提醒: 关"))
    if bySrc then return end          -- 按副本视图：表格不画

    local sc = page._wlChild
    for _, r in ipairs(sc.rows) do r:Hide() end
    -- ⛔ 只作首帧兜底：滚动区还没布局时给个非零宽度，免得子框宽度为 0 行全看不见。
    --    真正的宽度由下面的 sc:SetWidth(scroll:GetWidth()) 接管，
    --    行本身是 TOPLEFT+TOPRIGHT 两点锚定，跟着子框自己撑。
    sc:SetWidth(math.max(380, math.floor((page:GetWidth() or 460) - 44)))

    -- 滚动子框宽度跟着滚动区走；拿不到就退回上面的 w（首帧可能还没布局）
    local sw = page._wlScroll and page._wlScroll:GetWidth() or 0
    if sw and sw > 1 then sc:SetWidth(math.floor(sw)) end

    if #list == 0 then
        local r = sc.rows[1]
        if not r then
            r = CreateFrame("Frame", nil, sc)
            r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            r.txt:SetPoint("TOPLEFT", 4, -6)
            r.txt:SetPoint("TOPRIGHT", -4, -6)
            r.txt:SetJustifyH("LEFT")
            if r.txt.SetWordWrap then r.txt:SetWordWrap(true) end
            sc.rows[1] = r
        end
        r:SetHeight(60)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, 0)
        r:SetPoint("TOPRIGHT", 0, 0)
        r.txt:SetText(T("WLP_EMPTY",
            "没有可提升的部位 —— 要么已经全部毕业，要么还没跑过分析。|n先去「装备总览」页跑一次分析。"))
        r:Show()
        sc:SetHeight(60)
        return
    end

    local y = 0
    for i, e in ipairs(list) do
        local r = sc.rows[i]
        if not r then
            r = CreateFrame("Button", nil, sc)
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints()

            r.slot = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.slot:SetPoint("LEFT", 4, 0)
            r.slot:SetWidth(52)
            r.slot:SetJustifyH("LEFT")

            -- 「提醒」打钩列（用户 2026-09-02：「可以按部位关闭提醒」）。
            -- ⛔ 勾选框自己吃掉点击，别冒泡到整行（整行是悬停看物品提示用的）。
            r.bell = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
            r.bell:SetSize(22, 22)
            r.bell:SetPoint("RIGHT", -6, 0)
            r.bell:SetScript("OnClick", function()
                if r._slotId and GearInsight.WishSlotToggle then
                    GearInsight.WishSlotToggle(r._slotId)
                    GearInsight:BuildWishlistPage(r._page)
                end
            end)
            r.bell:SetScript("OnEnter", function(b)
                GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                GameTooltip:SetText(T("WLP_BELL_TIP",
                    "这个部位掉东西时要不要提醒你。|n关掉后该部位不再弹窗，列表里仍然显示。"),
                    1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            r.bell:SetScript("OnLeave", function() GameTooltip:Hide() end)

            r.gain = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            r.gain:SetPoint("RIGHT", r.bell, "LEFT", -6, 0)
            r.gain:SetWidth(50)
            r.gain:SetJustifyH("RIGHT")

            -- 中间：箭头钉在行中心，当前/目标各占一半，宽度自己撑开
            r.arrow = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            -- ⛔ 别居中五五分：目标列放的是 BiS 装备，名字普遍比身上那件长
            --    （玩家 2026-09-02 截图：「亚基克星藏骨匣 ...」被截）。
            --    分割线左移，当前列够用即可，多出来的空间全给目标列。
            r.arrow:SetPoint("CENTER", r, "CENTER", -58, 0)
            r.arrow:SetText("|cff888888>|r")

            r.curIc = r:CreateTexture(nil, "ARTWORK")
            r.curIc:SetSize(20, 20)
            r.curIc:SetPoint("LEFT", 60, 0)
            r.cur = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            r.cur:SetPoint("LEFT", r.curIc, "RIGHT", 4, 0)
            r.cur:SetPoint("RIGHT", r.arrow, "LEFT", -4, 0)
            r.cur:SetJustifyH("LEFT")
            if r.cur.SetWordWrap then r.cur:SetWordWrap(false) end

            r.tgtIc = r:CreateTexture(nil, "ARTWORK")
            r.tgtIc:SetSize(20, 20)
            r.tgtIc:SetPoint("LEFT", r.arrow, "RIGHT", 6, 0)
            r.tgt = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            r.tgt:SetPoint("LEFT", r.tgtIc, "RIGHT", 4, 0)
            r.tgt:SetPoint("RIGHT", r.gain, "LEFT", -6, 0)
            r.tgt:SetJustifyH("LEFT")
            if r.tgt.SetWordWrap then r.tgt:SetWordWrap(false) end

            r:SetScript("OnEnter", function(s2)
                s2.bg:SetColorTexture(1, 1, 1, 0.07)
                if not (s2._tgtLink or s2._tgtId) then return end
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                -- ⛔ 优先用带 bonusIDs 的链接：SetItemByID 读到的是**基准装等**，
                --    玩家 2026-09-02「装等都不对」就是这里。
                if s2._tgtLink then GameTooltip:SetHyperlink(s2._tgtLink)
                else GameTooltip:SetItemByID(s2._tgtId) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function(s2)
                s2.bg:SetColorTexture(0, 0, 0, 0)
                GameTooltip:Hide()
            end)
            sc.rows[i] = r
        end

        r:SetHeight(ROW_H)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, y)
        r:SetPoint("TOPRIGHT", 0, y)      -- 两点锚定：宽度跟着滚动区自己撑
        r.bg:SetColorTexture(0, 0, 0, 0)
        r._tgtId = e.itemId
        r._slotId = e.slot
        r._page = page
        r._tgtLink = GearInsight.WishItemLink and GearInsight.WishItemLink(e, e.itemId) or nil

        local muted = e.muted and true or false
        r.bell:SetChecked(not muted)
        -- ⛔ 关掉提醒的部位整行压暗，但**不隐藏**：玩家还要能看见它、能再打开
        local dim = muted and 0.45 or 1

        r.slot:SetText(slotName(e.slot))
        r.slot:SetTextColor(GOLD[1] * dim, GOLD[2] * dim, GOLD[3] * dim)

        if e.curLink then
            local cn = e.curLink:match("%[(.-)%]") or "?"
            r.curIc:SetTexture(iconOf(e.curLink))
            r.cur:SetText(("%s |cff888888%d|r"):format(cn, e.curIlvl or 0))
        else
            r.curIc:SetTexture(QMARK)
            r.cur:SetText("|cffff6666" .. T("WLP_EMPTY_SLOT", "空着") .. "|r")
        end
        r.curIc:SetAlpha(dim); r.tgtIc:SetAlpha(dim)
        r.cur:SetAlpha(dim); r.tgt:SetAlpha(dim); r.gain:SetAlpha(dim); r.arrow:SetAlpha(dim)

        r.tgtIc:SetTexture(iconOf(e.itemId))
        -- ⛔ 名字冷缓存时是 nil（异步加载），⛔别把 "#itemId" 打出来充数：
        --   玩家 Pluto/Icarus 2026-09-02 看到的就是这种占位。发起加载，好了再刷这一行。
        if not e.name and GearInsight.ItemName then
            local rid = e.itemId
            local nm = GearInsight.ItemName(rid, function()
                if r._tgtId == rid and r:IsShown() then
                    GearInsight:BuildWishlistPage(page)
                end
            end)
            if nm then e.name = nm end
        end
        -- ⛔ 套装部位显示的是**坯子第一名**，不是套装件本身：套装件副本里不掉，
        --   只能催化转换（用户 2026-09-02：「套装注意是看坯子第一名」）。标注出来免得误会。
        local tag = ""
        if e.isFiller then
            tag = "  |cffb060ff" .. T("WLP_FILLER", "坯子") .. "|r"
        end
        r.tgt:SetText(("%s |cff888888%s|r%s"):format(
            e.name or T("WLP_LOADING", "读取中…"),
            e.ilvl and tostring(e.ilvl) or "?", tag))

        if e.gain and e.gain > 0 then
            r.gain:SetText("|cff40ff40+" .. e.gain .. "|r")
        elseif e.pct and e.kind == "gain" then
            r.gain:SetText(("|cff40ff40+%.0f%%|r"):format(e.pct))
        else
            r.gain:SetText("|cff888888—|r")
        end

        r:Show()
        y = y - ROW_H
    end
    sc:SetHeight(math.max(1, -y))
end
