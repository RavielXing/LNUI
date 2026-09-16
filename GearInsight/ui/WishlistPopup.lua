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
        -- ⛔⛔ 私聊完**不能直接 Hide**：一波掉两件时，剩下那件会跟着窗口一起没掉
        --    （玩家「ζ弃落丶沦天」2026-09-09：「第二个先出现的对话框会覆盖第一个装备的
        --    对话框。这不就能选择性私聊了」）。已私聊的那件出队，还有就接着显示下一件。
        f:DropCurrent()
    end)

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(48, 20)
    close:SetPoint("RIGHT", btn, "LEFT", -6, 0)
    close:SetText(T("WP_CLOSE", "关闭"))
    close:SetScript("OnClick", function() f:Hide() end)

    -- 「下一件」：一波多件时翻看/挑着私聊；只有 ≥2 件才出现，单件时和以前一模一样
    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(64, 20)
    nextBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)
    nextBtn:SetText(T("WP_NEXT", "下一件"))
    nextBtn:SetScript("OnClick", function()
        local q = f._queue or {}
        if #q < 2 then return end
        f._idx = (f._idx or 1) % #q + 1
        f:RenderCurrent()
    end)
    f.nextBtn = nextBtn
    nextBtn:Hide()

    -- 关闭即重置这一波：下次弹是新的一波
    f:SetScript("OnHide", function(self)
        self:StopTick()
        self._queue, self._idx = nil, nil
    end)

    -- 倒计时控制（可暂停、可续跑）
    function f:StartTick()
        if self._tick then self._tick:Cancel() end
        self._tick = C_Timer.NewTicker(1, function()
            -- ⛔ 必须自己收尾：这个表没有次数上限，窗口关掉后不取消就永远空转
            if not frame or not frame:IsShown() then
                if frame and frame._tick then frame._tick:Cancel(); frame._tick = nil end
                return
            end
            frame._left = (frame._left or 0) - 1
            if frame._left <= 0 then
                frame:Hide()
                return
            end
            frame.cd:SetText(("|cff%s%ds|r"):format(
                frame._left <= 3 and "ff6666" or "888888", frame._left))
        end)
    end
    function f:StopTick()
        if self._tick then self._tick:Cancel(); self._tick = nil end
    end

    -- ── 一波多件：队列 ─────────────────────────────────────────
    -- ⛔⛔ 原来窗口只存**一件**（f._who/_link/_itemId）：第二件掉下来时直接把第一件
    --    的字段覆盖掉，第一件就再也私聊不到了。多件必须排队，而不是互相覆盖。
    -- ⛔ 新到的件**追加到队尾**，⛔不许把当前正在看的这件顶掉 —— 玩家可能正要点私聊。
    function f:RenderCurrent()
        local q = self._queue or {}
        local n = #q
        if n == 0 then self:Hide(); return end
        if not self._idx or self._idx > n then self._idx = 1 end
        local e = q[self._idx]
        self._who, self._link, self._itemId = e.who, e.link, e.itemId

        local title = string.format(
            T("WP_TITLE", "|cffd6b26c当前有 %d 件你可提升的装备掉落：|r"), n)
        if n > 1 then
            title = title .. string.format(
                T("WP_NTH", "|cff888888（第 %d/%d 件）|r"), self._idx, n)
            self.nextBtn:Show()
        else
            self.nextBtn:Hide()
        end
        self.title:SetText(title)

        local short = e.who:match("^([^-]+)") or e.who
        self.who:SetText(("|cff40ff40%s|r %s"):format(short, T("WA_GOT", "捡到了")))
        -- ⛔ why（"+12%"）不再直接显示：先算「+N 装等 · BiS #x」，算不出来才退回 why
        local info = GearInsight.WishDropInfo and GearInsight.WishDropInfo(e.link, e.itemId) or nil
        self.item:SetText(e.link)
        -- ⛔ 若链接里没有物品名（冷缓存/新式颜色码没匹配上），加载好后把这行补上
        if e.itemId and e.itemId > 0 and not tostring(e.link):find("%[") and GearInsight.ItemName then
            local want = e.itemId
            GearInsight.ItemName(want, function()
                if frame and frame._itemId == want and frame:IsShown() then
                    local lnk = select(2, GetItemInfo(want))
                    if lnk then frame.item:SetText(lnk) end
                end
            end)
        end
        self.info:SetText(info or (e.why and ("|cff888888%s|r"):format(e.why)) or "")
        -- ⛔⛔ 别写成 `select(10, A and A.f(x) or f(x))` —— `and/or` 会把**多返回值截成一个**，
        --    select(10, ...) 于是永远是 nil（图标恒为问号，而且不报错）。
        local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local tex
        if getInfo then tex = select(10, getInfo(e.link)) end
        self.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- 换一件就把倒计时重新拨满：⛔别让翻到第二件时只剩 1 秒
        self._left = SHOW_SEC
        self.cd:SetText(("|cff888888%ds|r"):format(self._left))
        self:StartTick()
    end

    -- 当前这件处理完了（已私聊）：出队；队列空了才关窗口
    function f:DropCurrent()
        local q = self._queue or {}
        table.remove(q, self._idx or 1)
        if #q == 0 then self:Hide(); return end
        if self._idx > #q then self._idx = 1 end
        self:RenderCurrent()
    end

    -- ⭐ 物品名做成真正的可点链接（用户 2026-09-02：「这个装备做的可以点击」）。
    -- ⛔ FontString 自己不接鼠标事件：要在**父框体**上开 SetHyperlinksEnabled，
    --    链接事件才会冒泡上来。只给 FontString 挂 OnEnter 是没用的。
    -- ⛔ 点击一律交给暴雪的 SetItemRef：它统一处理「普通点=开提示窗、Shift 点=发聊天、
    --    Ctrl 点=试衣间」。⛔别自己拼行为，那样和玩家在别处的肌肉记忆对不上。
    if f.SetHyperlinksEnabled then
        f:SetHyperlinksEnabled(true)
        f:SetScript("OnHyperlinkEnter", function(self, link)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
            self:StopTick()   -- 悬停时暂停，别让人正看着提示窗就没了
        end)
        f:SetScript("OnHyperlinkLeave", function(self)
            GameTooltip:Hide()
            self:StartTick()          -- ⛔ 必须续跑，否则窗口再也不会自动关
        end)
        f:SetScript("OnHyperlinkClick", function(_, link, text, button)
            if SetItemRef then SetItemRef(link, text, button) end
        end)
    end

    -- 悬停图标看物品详情（Texture 本身不接事件，套一个透明 Frame）
    local hover = CreateFrame("Frame", nil, f)
    hover:SetAllPoints(f.icon)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self)
        if not f._link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(f._link)
        GameTooltip:Show()
        f:StopTick()          -- 与悬停链接同一套行为：在看提示就别倒计时
    end)
    hover:SetScript("OnLeave", function()
        GameTooltip:Hide()
        f:StartTick()
    end)

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
-- ⭐ 自定义私聊模板（玩家「目暮」2026-09-07 群里提：「毛装备的这个功能 可以改下私聊内容么」）。
--
-- 占位符（都可选，写不写、写几个都行）：
--   {item}  要的那件（物品链接，鼠标能悬停）
--   {cur}   你当前那个部位穿的（物品链接；读不到时退成「%d 装等」）
--   {gain}  换上能提升多少装等
--   {slot}  部位名
--   {me}    你的角色名
--
-- ⛔ 拿不到的占位符**整段替换成空**再收拾多余空格，⛔不许把 `{gain}` 原样发出去 ——
--   玩家看不懂大括号，只会以为插件坏了。
-- ⛔ 依然只**预填**聊天框、绝不自动发送：改成自定义之后更要守住这条，
--   否则等于给了一个可以群发任意内容的按钮。
local function _fillTemplate(tpl, vars)
    local out = tpl
    for k, v in pairs(vars) do
        out = out:gsub("{" .. k .. "}", function() return v or "" end)
    end
    -- 没被填上的占位符一律去掉，⛔别留大括号给玩家看
    out = out:gsub("{%w+}", "")
    -- 收拾空占位符留下的多余空格与标点
    out = out:gsub("%s+", " "):gsub(" ([，。！？～、])", "%1"):gsub("^%s+", ""):gsub("%s+$", "")
    return out
end


function GearInsight:WishWhisperDefault()
    -- ⛔ 这里**不能复用 WP_ASK_CUR**：那条是给 string.format 用的 %s/%d 文案，
    --   而模板走的是 {item} 这套占位符。混用会让占位符审计报「不一致」，
    --   真跑起来 string.format 还会炸（2026-09-07 闸门当场拦下）。
    return T("WP_TPL_DEFAULT",
        "大佬，{item} 你还需要吗？我这部位现在是 {cur}，换上能 +{gain} 装等，用不上的话方便给我吗～谢谢！")
end


-- ⛔ 固定前缀「[GearInsight插件]」（用户 2026-09-11「标记下[GearInsight插件]，让大家知道是这个插件喊的，不可编辑强制」；
-- 2026-09-15 用户一度改成「[GearInsight]」又改回来，保留「插件」二字）：
--    不走模板、不进编辑框，玩家自定义话术里就算自己打了同样的字也会先剥掉再统一加，保证只出现一次、永远在最前。
local function _tag()
    return T("WP_TAG", "[GearInsight插件]")
end
local function _stripTag(txt)
    local tag = _tag()
    txt = txt:gsub("^%s*" .. tag:gsub("%p", "%%%0") .. "%s*", "")
    txt = txt:gsub("^%s*%[GearInsight[^%]]*%]%s*", "")
    return txt
end
function GearInsight:WishWhisperTag() return _tag() end

local function _whisperBody(self, link, itemId)
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
    -- ⭐ 玩家自定义模板优先。⛔ 只有设了且非空才走它，⛔别用空串把默认文案顶掉。
    local tpl = GearInsightDB and GearInsightDB.whisperTpl
    if type(tpl) == "string" and tpl:gsub("%s", "") ~= "" then
        local slot = ""
        if itemId and C_Item and C_Item.GetItemInventoryTypeByID and _G.INVTYPE_Slot then
            slot = _G.INVTYPE_Slot[C_Item.GetItemInventoryTypeByID(itemId)] or ""
        end
        return _fillTemplate(tpl, {
            item = name,
            cur = curLink or (cur and (cur .. " " .. T("WP_ILVL", "装等")) or nil),
            gain = gain and tostring(gain) or nil,
            slot = slot,
            me = UnitName and UnitName("player") or "",
        })
    end

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

function GearInsight:WishWhisperText(link, itemId)
    local body = _whisperBody(self, link, itemId) or ""
    return _tag() .. " " .. _stripTag(body)
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
    -- 入队。⛔ 同一件已在队列里就只更新，别塞两条（拾取消息偶尔重复播报）。
    f._queue = f._queue or {}
    local hit
    if itemId then
        for _, e in ipairs(f._queue) do
            if e.itemId == itemId then hit = e break end
        end
    end
    if hit then
        hit.who, hit.link, hit.why = who, link, why
    else
        f._queue[#f._queue + 1] = { who = who, link = link, why = why, itemId = itemId }
    end

    local wasShown = f:IsShown()
    f:Show()
    -- ⛔ 窗口已经开着时**不跳到新来的这件**：玩家可能正准备点「私聊」，
    --   跳走 = 又一次「覆盖」。只把标题的件数和「下一件」按钮刷新出来。
    if not wasShown then f._idx = #f._queue end
    f:RenderCurrent()
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


-- ── 自定义私聊话术编辑器 ────────────────────────────────────────
-- 玩家「目暮」2026-09-07 群里提：「毛装备的这个功能 可以改下私聊内容么」。
--
-- ⛔ 做成**多行输入 + 实时预览**：光给个输入框，玩家写完不知道占位符会变成什么，
--   发出去才发现是空的。预览用一条假数据当场渲出来。
-- ⛔ 保存时不做任何内容审查，但**依然只预填不自动发**（见 WishWhisperText 顶部）。
function GearInsight:ShowWhisperEditor()
    local f = GearInsight._whisperEditor
    if not f then
        f = CreateFrame("Frame", "GearInsightWhisperEditor", UIParent,
                        "BackdropTemplate")
        f:SetSize(560, 360)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
        f:SetBackdropBorderColor(0.35, 0.38, 0.45, 1)
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -14)
        title:SetText(T("WP_EDIT_TITLE", "自定义私聊话术"))

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 16, -44)
        hint:SetPoint("TOPRIGHT", -16, -44)
        hint:SetJustifyH("LEFT")
        hint:SetText(T("WP_EDIT_TAGNOTE", "开头的「[GearInsight插件]」是固定的，不可改、也不用写。") .. "\n" .. T("WP_EDIT_HINT",
            "可用占位符：|cFFFFD100{item}|r 那件装备  |cFFFFD100{cur}|r 你当前这件  "
            .. "|cFFFFD100{gain}|r 提升装等  |cFFFFD100{slot}|r 部位  |cFFFFD100{me}|r 你的名字\n"
            .. "取不到的会自动去掉。留空则用默认话术。"))

        local sf = CreateFrame("ScrollFrame", nil, f, "InputScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 16, -92)
        sf:SetSize(528, 110)
        sf.EditBox:SetWidth(510)
        sf.EditBox:SetAutoFocus(false)
        sf.CharCount:Hide()
        f.edit = sf.EditBox

        local pvTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        pvTitle:SetPoint("TOPLEFT", 16, -212)
        pvTitle:SetText(T("WP_EDIT_PREVIEW", "预览"))

        local pv = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pv:SetPoint("TOPLEFT", 16, -232)
        pv:SetPoint("TOPRIGHT", -16, -232)
        pv:SetJustifyH("LEFT")
        pv:SetHeight(60)
        f.preview = pv

        -- ⭐ 预览用固定假数据，⛔别用真实心愿单：编辑时未必有掉落，预览会是空的。
        local function refresh()
            local tpl = f.edit:GetText() or ""
            if tpl:gsub("%s", "") == "" then
                tpl = GearInsight:WishWhisperDefault()
            end
            local demo = tpl
            for k, v in pairs({
                item = "|cffa335ee[裂空者之刃]|r", cur = "|cff0070dd[旧武器]|r",
                gain = "12", slot = SLOT_MAINHAND or "主手",
                me = UnitName and UnitName("player") or "你",
            }) do
                demo = demo:gsub("{" .. k .. "}", function() return v end)
            end
            demo = demo:gsub("{%w+}", ""):gsub("%s+", " ")
            f.preview:SetText(GearInsight:WishWhisperTag() .. " " .. _stripTag(demo))
        end
        f.edit:SetScript("OnTextChanged", refresh)
        f._refresh = refresh

        local save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        save:SetSize(110, 24); save:SetPoint("BOTTOMRIGHT", -16, 16)
        save:SetText(T("WP_EDIT_SAVE", "保存"))
        save:SetScript("OnClick", function()
            local t = f.edit:GetText() or ""
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.whisperTpl = (t:gsub("%s", "") ~= "") and t or nil
            f:Hide()
            GearInsight:Print(T("WP_EDIT_SAVED", "私聊话术已保存。"))
        end)

        local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        reset:SetSize(110, 24); reset:SetPoint("RIGHT", save, "LEFT", -8, 0)
        reset:SetText(T("WP_EDIT_RESET", "恢复默认"))
        reset:SetScript("OnClick", function()
            f.edit:SetText(GearInsight:WishWhisperDefault())
        end)

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)

        if GearInsight.AnchorPopup then pcall(GearInsight.AnchorPopup, GearInsight, f) end
        GearInsight._whisperEditor = f
    end
    f.edit:SetText((GearInsightDB and GearInsightDB.whisperTpl)
                   or GearInsight:WishWhisperDefault())
    if f._refresh then f._refresh() end
    f:Show()
end
