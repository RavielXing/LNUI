-- 心愿单命中弹窗：队友捡到你要的东西时，弹一个小窗 + 一键私聊。
--
-- ⭐ 为什么不用聊天框：大秘境里聊天框刷得飞快（拾取、伤害、副本提示），
--    两行字几分钟后就被顶没了 —— 而这条消息的价值恰恰是**立刻**看到并去问一句。
--    竞品 KeystoneLoot（410 万下载）也是弹窗，且能从弹窗直接私聊。
--
-- ⛔ 三条自律，否则这功能会变成"被玩家关掉的那个"：
--    ① 只在队伍里、只对别人拾取、只命中心愿单时弹；
--    ② 同一件物品 60 秒内不重复弹（拾取消息偶尔会重复播报）；
--    ③ 8 秒自动消失，⛔不做模态、不抢焦点、不挡视野中心。
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

-- ⛔ 8 → 10 秒（用户 2026-09-02）。窗口上带可见倒计时：
--    没有倒计时的话，窗口自己消失会让人以为是插件抽了。
local SHOW_SEC = 10
local frame, recent = nil, {}

local function Build()
    if frame then return frame end
    local f = CreateFrame("Frame", "GearInsightWishPopup", UIParent, "BackdropTemplate")
    f:SetSize(340, 116)
    -- 屏幕中上方：看得见，但不压住准星和血条
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20,
                    insets = { left = 5, right = 5, top = 5, bottom = 5 } })
    f:SetBackdropColor(0.05, 0.06, 0.09, 0.95)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- 记住玩家挪到哪；⛔落 GearInsightDB（toc 声明的那个），别用内存表
        GearInsightDB = GearInsightDB or {}
        local p, _, rp, x, y = self:GetPoint()
        GearInsightDB.wishPopupPos = { p, rp, x, y }
    end)

    -- 标题：告诉玩家「这一波有几件你能提升的掉了」（用户 2026-09-02）
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetPoint("TOPRIGHT", -46, -10)
    f.title:SetJustifyH("LEFT")

    -- 倒计时：右上角一个小数字，让「它会自己关」这件事可预期
    f.cd = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.cd:SetPoint("TOPRIGHT", -10, -10)
    f.cd:SetJustifyH("RIGHT")

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(32, 32)
    f.icon:SetPoint("TOPLEFT", 12, -32)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    f.who = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.who:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, 0)
    f.who:SetJustifyH("LEFT")

    -- ⛔ 物品名与「+N 装等 · BiS #x」必须分两行：挤一行时长物品名会把信息推到按钮上
    --    （玩家 2026-09-02 截图：信息行压住了「关闭 / 私聊」两个按钮）。
    -- ⛔ 宽度用锚点顶到右边框，别写死 240 —— 物品名长度差别很大。
    f.item = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.item:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -14)
    f.item:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.item:SetJustifyH("LEFT")
    if f.item.SetWordWrap then f.item:SetWordWrap(false) end

    f.info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.info:SetPoint("TOPLEFT", f.item, "BOTTOMLEFT", 0, -3)
    f.info:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.info:SetJustifyH("LEFT")

    -- 私聊按钮：竞品那条「可以直接问他要」的路径，比可点名字更直白
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(72, 20)
    btn:SetPoint("BOTTOMRIGHT", -10, 9)
    btn:SetText(T("WP_WHISPER", "私聊"))
    btn:SetScript("OnClick", function()
        if f._who and ChatFrame_OpenChat then
            ChatFrame_OpenChat("/w " .. f._who .. " " .. GearInsight:WishWhisperText(f._link, f._itemId),
                DEFAULT_CHAT_FRAME)
        end
        f:Hide()
    end)

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(48, 20)
    close:SetPoint("RIGHT", btn, "LEFT", -6, 0)
    close:SetText(T("WP_CLOSE", "关闭"))
    close:SetScript("OnClick", function() f:Hide() end)
    -- 关闭即重置这一波的计数：下次弹是新的一波
    f:SetScript("OnHide", function(self)
        if self._tick then self._tick:Cancel(); self._tick = nil end
        self._batch = nil
    end)

    -- 悬停图标看物品详情（Texture 本身不接事件，套一个透明 Frame）
    local hover = CreateFrame("Frame", nil, f)
    hover:SetAllPoints(f.icon)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self)
        if not f._link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(f._link)
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if GearInsightDB and GearInsightDB.wishPopupPos then
        local p = GearInsightDB.wishPopupPos
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    f:Hide()
    frame = f
    return f
end

-- 掉落这件对你意味着什么：装等提升 + 在你这个部位的 BiS 名次。
--
-- ⛔ 原来这里显示的是 improvementPct（"+12%"），玩家 2026-09-02 直接问
--    「+12% 是啥意思」—— 百分比相对的是什么、基数多少，窗口里一个字都没交代，
--    等于给了个无法行动的数。⭐ 换成两个玩家真正会拿来做决定的量：
--      ① 装等提升：拿**这次掉落的实际装等**减身上那件（跨难度也准，
--         团本/大秘境 H/M 同一个 itemId 装等不同）；
--      ② BiS 名次：这件在你这个部位的排名，回答「值不值得开口要」。
-- ⛔ 两个都拿不到就返回 nil，⛔别硬凑一个数出来。
function GearInsight.WishDropInfo(link, itemId)
    local parts = {}

    -- 找到这件对应的槽位（顺带拿到目标信息）
    local slotId
    if itemId and GearInsight.GetUpgradeSlots then
        local ok, list = pcall(GearInsight.GetUpgradeSlots)
        if ok and list then
            for _, e in ipairs(list) do
                if e.itemId == itemId then slotId = e.slot break end
            end
        end
    end

    -- ① 装等提升：用掉落物**实际**装等，不是 BiS 目标装等
    if link and slotId and GetDetailedItemLevelInfo and GetInventoryItemLink then
        local dropped = GetDetailedItemLevelInfo(link)
        local cur = GetInventoryItemLink("player", slotId)
        local curIlvl = cur and GetDetailedItemLevelInfo(cur) or 0
        if dropped and dropped > 0 then
            if curIlvl > 0 and dropped > curIlvl then
                parts[#parts + 1] = string.format(
                    T("WP_INFO_GAIN", "|cff40ff40+%d 装等|r"), dropped - curIlvl)
            elseif curIlvl == 0 then
                parts[#parts + 1] = "|cff40ff40" .. T("WP_INFO_EMPTY", "空部位") .. "|r"
            end
        end
    end

    -- ② BiS 名次：复用悬浮提示已经建好的反查表，⛔别另建一份
    local TH = GearInsight.TooltipHook
    local idx = TH and TH._itemIndex
    local hits = idx and itemId and idx[itemId]
    local cache = TH and TH._specCache
    if hits and cache and cache.class and cache.spec then
        local bd = GearInsight.BisData
        local mplus = (bd and bd.GetUsageMode and bd:GetUsageMode()) == "mplus"
        for _, h in ipairs(hits) do
            if h.className == cache.class and h.specName == cache.spec then
                local rank  = mplus and (h.rankM or h.rank) or (h.rank or h.rankM)
                local total = mplus and (h.totalM or h.total) or (h.total or h.totalM)
                if rank then
                    parts[#parts + 1] = string.format(
                        T("WP_INFO_BIS", "|cffffd100BiS #%d/共%d|r"), rank, total or rank)
                end
                break
            end
        end
    end

    if #parts == 0 then return nil end
    return table.concat(parts, " |cff666666·|r ")
end

-- 私聊预置文案。
--
-- ⛔ 只**预填**聊天框，绝不自动发送 —— 发不发、怎么改，最后一步永远由玩家按回车决定。
--
-- ⭐ 措辞是设计过的，用户原稿是「大神，请问需要[xxx]吗，本人新手小号，求让」，
--    改动三处、理由：
--    ① 去掉「新手小号」——自贬不会让人更想给你，反而像乞讨；而且你既然和对方在同一个
--       本里，「新手小号」这个自称本身就站不住，读着不真诚。
--    ② 「求让」→「你还需要吗 / 用不上的话」——给对方一个**能体面说不的台阶**。
--       伸手要东西时，把拒绝的成本降到最低，答应的概率反而更高。
--    ③ 补上**提升幅度**——这是插件独有、对方自己算不出来的信息，
--       它把「我想要」变成「给我收益更大」，是这条私聊里唯一真正有说服力的部分。
--    ⛔ 全程不写「代练/收费/交易」字样（对外文案红线）。
function GearInsight:WishWhisperText(link, itemId)
    local name = link or ""
    local gain, cur, curLink
    if itemId and GearInsight.GetUpgradeSlots then
        local ok, list = pcall(GearInsight.GetUpgradeSlots)
        if ok and list then
            for _, e in ipairs(list) do
                if e.itemId == itemId then
                    if e.gain and e.gain > 0 then gain = e.gain end
                    if e.curIlvl and e.curIlvl > 0 then cur = e.curIlvl end
                    curLink = e.curLink
                    break
                end
            end
        end
    end

    -- ⭐ 措辞演进留个痕，免得以后有人「优化」回去：
    --    v1 用户原稿「大神…本人新手小号，求让」→ 自贬不提供信息，且把对方架在道德位上；
    --    v2 改成报提升幅度 → 对方有了判断依据；
    --    v3（本版，用户 2026-09-02「把当前装备也要贴上」）→ 直接贴出**当前那件的链接**：
    --       对方鼠标一悬就看见你穿的是什么，比任何形容词都有说服力，
    --       而且省掉了「我是不是在骗他」这层怀疑。
    -- ⛔ 全程不出现「代练/收费/交易」字样（对外文案红线）。
    if curLink and gain then
        return string.format(
            T("WP_ASK_CUR", "大佬，%s 你还需要吗？我这部位现在是 %s，换上能 +%d 装等，用不上的话方便给我吗～谢谢！"),
            name, curLink, gain)
    end
    if cur and gain then
        return string.format(
            T("WP_ASK_FULL", "大佬，%s 你还需要吗？我这部位才 %d 装等（能提升 %d），用不上的话方便给我吗～谢谢！"),
            name, cur, gain)
    end
    if gain then
        return string.format(
            T("WP_ASK_GAIN", "大佬，%s 你还需要吗？我这个部位能提升 %d 装等，用不上的话方便给我吗～谢谢！"),
            name, gain)
    end
    return string.format(
        T("WP_ASK", "大佬，%s 你还需要吗？正好是我要的部位，用不上的话方便给我吗～谢谢！"), name)
end

-- who: 队友名（可能带 -服务器）  link: 物品链接  why: "+12%" 之类的补充
function GearInsight:WishPopup(who, link, why, itemId, force)
    if not (who and link) then return end
    local now = GetTime()
    -- ⛔同一件 60 秒内不重复弹：拾取消息偶尔会重复播报。
    -- ⛔⛔ 但「试一发」必须绕开它：demo 用的是固定 itemId(-1)，
    --    第一次弹完就把自己记进去了，60 秒内再点就被自家去重挡掉
    --    （玩家 2026-09-02：「点一次怎么就没了」「不能再点了」）。
    --    ⭐ 判据教训：给真实链路做的防抖，套到**手动触发的调试入口**上就是 bug。
    if itemId and not force then
        if recent[itemId] and (now - recent[itemId]) < 60 then return end
        recent[itemId] = now
    end
    local f = Build()
    local short = who:match("^([^-]+)") or who
    -- 「这一波有几件」：窗口还开着时又命中一件就累加，关掉即清零。
    -- ⛔ 按 itemId 去重，别按次数累加：同一件重复播报不该把计数顶上去。
    f._batch = f._batch or {}
    if itemId then f._batch[itemId] = true end
    local n = 0
    for _ in pairs(f._batch) do n = n + 1 end
    if n < 1 then n = 1 end
    f.title:SetText(string.format(
        T("WP_TITLE", "|cffd6b26c当前有 %d 件你可提升的装备掉落：|r"), n))

    f._who, f._link, f._itemId = who, link, itemId
    f.who:SetText(("|cff40ff40%s|r %s"):format(short, T("WA_GOT", "捡到了")))
    -- ⛔ why（"+12%"）不再直接显示：先算「+N 装等 · BiS #x」，算不出来才退回 why
    local info = GearInsight.WishDropInfo and GearInsight.WishDropInfo(link, itemId) or nil
    f.item:SetText(link)
    f.info:SetText(info or (why and ("|cff888888%s|r"):format(why)) or "")
    -- ⛔⛔ 别写成 `select(10, A and A.f(x) or f(x))` —— `and/or` 会把**多返回值截成一个**，
    --    select(10, ...) 于是永远是 nil（图标恒为问号，而且不报错）。
    --    先把函数本身选出来，再整体调用。
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local tex
    if getInfo then tex = select(10, getInfo(link)) end
    f.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    f:Show()

    -- 倒计时：每秒刷一次数字，到 0 关闭。
    -- ⛔ 用 Ticker 而不是 NewTimer + OnUpdate：OnUpdate 每帧都跑，
    --   只为了显示一个整数秒不值得；Ticker 每秒一次刚好。
    if f._timer then f._timer:Cancel(); f._timer = nil end
    if f._tick then f._tick:Cancel(); f._tick = nil end
    local left = SHOW_SEC
    f.cd:SetText(("|cff888888%ds|r"):format(left))
    f._tick = C_Timer.NewTicker(1, function()
        left = left - 1
        if not frame or not frame:IsShown() then return end
        if left <= 0 then
            frame:Hide()
            return
        end
        frame.cd:SetText(("|cff%s%ds|r"):format(left <= 3 and "ff6666" or "888888", left))
    end, SHOW_SEC)
end

-- 手动试一发（不用真进本就能看长什么样）：/run GearInsight:WishPopupDemo()
function GearInsight:WishPopupDemo()
    -- ⭐ 用你**真实的第一顺位可提升部位**来演示，比一条假数据有说服力得多，
    --    也顺带验证了「装等提升 / BiS 名次」这两个数算得对不对。
    -- force=true：手动试一发不受 60 秒去重限制，随点随弹。
    local who = UnitName("player") or "Someone"
    if GearInsight.GetUpgradeSlots then
        local ok, list = pcall(GearInsight.GetUpgradeSlots)
        if ok and list and list[1] then
            local e = list[1]
            local lnk = (GearInsight.WishItemLink and GearInsight.WishItemLink(e, e.itemId))
                or select(2, GetItemInfo(e.itemId))
            if lnk then
                self:WishPopup(who, lnk, nil, e.itemId, true)
                return
            end
        end
    end
    self:WishPopup(who,
        "|cffa335ee|Hitem:273781::::::::80:::::|h[" ..
        T("WP_DEMO_ITEM", "护卫之牙束带") .. "]|h|r", nil, -1, true)
end
