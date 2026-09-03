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
        intro:SetText(T("WLP_INTRO",
            "队伍里掉到你能提升的部位时自动弹框提醒，并可一键私聊问对方要。|n清单跟着你的装备走，不用手动维护。"))
        page._wlIntro = intro

        local tg = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        tg:SetSize(150, 22)
        tg:SetPoint("TOPLEFT", 12, -80)
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
        demo:SetSize(90, 22)
        demo:SetPoint("LEFT", tg, "RIGHT", 8, 0)
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

        local stat = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        stat:SetPoint("LEFT", demo, "RIGHT", 12, 0)
        page._wlStat = stat

        -- 表头。⛔ 上一版没有表头，右边那个数字谁也不知道是什么。
        local hdr = CreateFrame("Frame", nil, page)
        hdr:SetPoint("TOPLEFT", 12, -110)
        hdr:SetPoint("TOPRIGHT", -28, -110)
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
        ln:SetPoint("TOPLEFT", 12, -128)
        ln:SetPoint("TOPRIGHT", -28, -128)
        ln:SetHeight(1)

        local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -134)
        scroll:SetPoint("BOTTOMRIGHT", -28, 10)
        local sc = CreateFrame("Frame", nil, scroll)
        sc:SetSize(1, 1)
        scroll:SetScrollChild(sc)
        page._wlScroll, page._wlChild = scroll, sc
        sc.rows = {}
    end

    local list = (GearInsight.GetUpgradeSlots and GearInsight.GetUpgradeSlots()) or {}
    local src = "none"
    if GearInsight.GetWishlist then
        local _, s2 = GearInsight.GetWishlist()
        src = s2 or "none"
    end

    local SRC = {
        recs = T("WLP_SRC_RECS", "下一步建议"),
        bis  = T("WLP_SRC_BIS",  "BiS 全表（建议数据不新鲜）"),
        none = T("WLP_SRC_NONE", "暂无数据"),
    }
    page._wlStat:SetText(string.format(
        T("WLP_STAT", "%d 个可提升部位  ·  来源：%s"), #list, SRC[src] or SRC.none))

    local on = not (GearInsightDB and GearInsightDB.wishAlertOff)
    page._wlToggle:SetText(on and T("WLP_ON", "掉落提醒: 开") or T("WLP_OFF", "掉落提醒: 关"))

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
        -- ⛔ 套装部位显示的是**坯子第一名**，不是套装件本身：套装件副本里不掉，
        --   只能催化转换（用户 2026-09-02：「套装注意是看坯子第一名」）。标注出来免得误会。
        local tag = ""
        if e.isFiller then
            tag = "  |cffb060ff" .. T("WLP_FILLER", "坯子") .. "|r"
        end
        r.tgt:SetText(("%s |cff888888%s|r%s"):format(
            e.name or ("#" .. tostring(e.itemId)),
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
