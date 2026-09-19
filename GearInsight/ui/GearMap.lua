-- ui/GearMap.lua —— 「装备图」：把「下一步建议」从一维列表改成暴雪角色面板那样的两列格子（2026-09-05）
--
-- 用户拍板：以暴雪原生角色栏位的排布为中心，每个格子外侧一个箭头指向它该换的 BiS 件，
-- BiS 件旁边再挂两个小方格：推荐宝石 / 推荐附魔（用颜色标你身上到没到位）。
-- 两列中间放属性达成度条（原来在面板顶部的那四条，整块挪进来）。
-- 起因：需求台账 #2（那年八月：「密密麻麻挤在一块比较难看」）。
--
-- ⛔ 这里**不做任何决策**。每个槽「该换什么 / 是否毕业 / 套装坯子是谁」全部来自
--    GearInsight.lua RefreshPanel 里那 500 行既有逻辑算完后存进 self._slotPlan 的结论
--    —— 本文件只负责把结论画成格子。⛔ 别在这里重新判断毕业或重新挑候选，
--    那样面板和悬浮/弹窗会出现第三种答案（dev-notes/same-data-three-renderers-diverge）。
--
-- 切换：GearInsightDB.gearView = "map"（默认）| "list"（旧列表，过渡一两个版本后删）。

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

-- ── 布局常量 ───────────────────────────────────────────────────────────
-- 2026-09-05 用户：「窗口是不是还可以宽一点，图片能放大，间距能有一些，现在太挤」
-- → 装备图模式把主面板从 520 加宽到 MAP_PANEL_W，格子 32→40、小格 12→16、行距 44→54。
-- ⛔ 加宽只在 map 模式生效，切回「列表」必须还原 520：旧列表的行是按 456 宽画死的。
local MAP_PANEL_W = 760          -- 两侧要放宝石/附魔名字（用户 2026-09-05）
local LIST_PANEL_W = 520
local GRID_W = MAP_PANEL_W - 50          -- 滚动区可用宽（面板 - 左右边距 - 滚动条）
local ICON   = 40          -- 装备格
local MINI   = 16          -- 宝石/附魔小格
local ROW_H  = 64          -- 一行（格子 40 + 装等小字 14 + 行间距；用户 2026-09-05「上下间距加大」）
local ARROW  = 16
local CELL_W = ICON + 6 + ARROW + 6 + ICON + 4 + MINI + 3 + MINI      -- 147
local PAD    = 8
-- 2026-09-05 用户：「要靠中间一点」→ 两列不再贴面板两边，改成以中间区域为锚、各留 GAP，
-- 整块居中，外侧自然留白。中间区域收到 220（标签 40 + 属性条 150 刚好）。
local CENTER_W = 170             -- 中间只留白，不放东西
local GAP = 14
local NAME_W = 118       -- 两侧名字列宽（7 个汉字左右）

-- 暴雪角色面板的两列顺序（去掉衬衣/战袍）
-- false = 衬衣/战袍的位置，留空不画，让护腕落在第 8 行与右列对齐（暴雪面板同款）
local LEFT_SLOTS  = { 1, 2, 3, 15, 5, false, false, 9 }
local RIGHT_SLOTS = { 10, 6, 7, 8, 11, 12, 13, 14 }
local BOTTOM_SLOTS = { 16, 17 }

-- 常规能打孔的部位（用户 2026-09-05：披风/手套这类常规无孔的不展示宝石推荐）。
-- 本赛季可镶孔：头 / 颈 / 护腕 / 戒指×2（腰带没有默认插槽，用户 2026-09-05 纠正）。
-- ⛔ 其余部位就算扫到"插槽"也不画（多半是误判）。
local SOCKETABLE = { [1] = true, [2] = true, [11] = true, [12] = true }   -- 护腕也没有默认插槽（用户 2026-09-05）

-- 多彩宝石（萨拉斯钻石一族，名字带「钻石」）是**装备唯一**：全身只能镶一颗。
-- 用户 2026-09-05：「多彩宝石只能有一个，所以按 1 个来推荐，其他换上第二名的」。
-- 分配规则：身上已经镶了钻石的那个槽保留它；否则给第一个可镶孔的槽；其余槽推荐使用率最高的**非钻石**宝石。
local SOCKET_ORDER = { 1, 2, 11, 12 }
local function isUniqueGem(g) return g and g.nameCn and g.nameCn:find("钻石", 1, true) ~= nil end
local function planGems(gems, readMine)
    local plan = {}
    if not gems or #gems == 0 then return plan end
    local uniq, second = nil, nil
    for _, g in ipairs(gems) do
        if isUniqueGem(g) then uniq = uniq or g else second = second or g end
    end
    if not uniq then
        for _, sid in ipairs(SOCKET_ORDER) do plan[sid] = gems[1] end
        return plan
    end
    -- 钻石已经在身上哪个槽？
    local uniqSlot
    for _, sid in ipairs(SOCKET_ORDER) do
        local mine = readMine(sid)
        if mine then
            for _, gid in ipairs(mine.gems) do
                if gid == uniq.id then uniqSlot = sid break end
            end
        end
        if uniqSlot then break end
    end
    if not uniqSlot then
        -- 没镶：给第一个真有插槽的槽；一个都没孔就给第一个可镶孔的槽
        for _, sid in ipairs(SOCKET_ORDER) do
            local mine = readMine(sid)
            if mine and (mine.sockets or 0) > 0 then uniqSlot = sid break end
        end
        uniqSlot = uniqSlot or SOCKET_ORDER[1]
    end
    for _, sid in ipairs(SOCKET_ORDER) do
        plan[sid] = (sid == uniqSlot) and uniq or (second or uniq)
    end
    return plan
end

-- 腿部"附魔"其实是护甲片 / 魔线（物品贴上去的），数据里只有一句通用描述（「敏捷/力量 + 耐力」）。
-- 这里对到**拍卖行里真实的物品**（用户 2026-09-05：「你这个不是拍卖行的护甲片名字」）。
-- 附魔 ID → 物品：2026-09-05 从 Wowhead 逐件核对效果文字（290 档；278 档 ID 见注释）。
-- ⛔ 换赛季这张表要重核：附魔 ID 不变但物品会换代。
local LEG_KIT = {
    [8159] = { item = 244641, name = "森林猎手的护甲片" },   -- 敏捷/力量 +41，耐力 +115  （278 档 244640）
    [8163] = { item = 244643, name = "血骑士的护甲片" },     -- 敏捷/力量 +41，护甲 +27    （278 档 244642）
    [7935] = { item = 240133, name = "阳炎丝绸魔线" },       -- 智力 +41，耐力 +115         （278 档 240094）
    [7937] = { item = 240155, name = "奥纹魔线" },           -- 智力 +41，最大法力 +4%      （278 档 240154）
}


-- 附魔/护甲片显示名：⛔别直接印 e.nameCn / LEG_KIT.name（那是烤制的简中，土耳其玩家 2026-09-06 截图
-- 装备图里六个中文名全是这条路来的）。护甲片走客户端物品名，其它走 GearInsight.EnchName（多语言表）。
local function _kitName(kit)
    if not kit then return "" end
    local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(kit.item)
    if n and n ~= "" then return n end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, kit.item) end
    return kit.name or ""
end
local function _enchNm(e, slotId)
    if not e then return "" end
    local kit = (slotId == 7) and LEG_KIT[e.id] or nil
    if kit then return _kitName(kit) end
    if GearInsight.EnchName then
        local n = GearInsight.EnchName(e, e.nameCn or "")
        if n and n ~= "" then return n end
    end
    return e.nameCn or ""
end

-- 哪些槽本来就能附魔（数据里没有推荐时，缺附魔仍要报）
local ENCHANTABLE = { [5] = true, [9] = true, [7] = true, [8] = true,
    [11] = true, [12] = true, [15] = true, [16] = true, [17] = true, [1] = true, [3] = true }

-- 状态色
local C_OK, C_BAD, C_OTHER, C_NONE = { 0.25, 0.95, 0.35 }, { 0.95, 0.25, 0.25 }, { 0.95, 0.75, 0.2 }, { 0.35, 0.35, 0.35 }

local function H() return GearInsight._h or {} end

-- ── 身上的宝石 / 附魔 ────────────────────────────────────────────────────
-- 只读物品链接 + 隐藏 tooltip 扫空孔，与 GroupBisPanel.readEquipped 同源写法。
local _scanTT, _emptyPatterns
local function emptySocketPatterns()
    if _emptyPatterns then return _emptyPatterns end
    _emptyPatterns = {}
    for name, val in pairs(_G) do
        if type(name) == "string" and name:find("^EMPTY_SOCKET") and type(val) == "string" then
            _emptyPatterns[#_emptyPatterns + 1] = val
        end
    end
    return _emptyPatterns
end

local function readSlotGemEnch(slotId)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
    if not link then return nil end
    local enchant = tonumber(link:match("item:%d+:(%d+)")) or 0
    local gems = {}
    -- item:id:ench:gem1:gem2:gem3:gem4
    local g1, g2, g3, g4 = link:match("item:%d+:%d*:(%d*):(%d*):(%d*):(%d*)")
    for _, g in ipairs({ g1, g2, g3, g4 }) do
        local n = tonumber(g)
        if n and n > 0 then gems[#gems + 1] = n end
    end
    local empty = 0
    if not _scanTT then
        _scanTT = CreateFrame("GameTooltip", "GearInsightGMScanTT", nil, "GameTooltipTemplate")
        _scanTT:SetOwner(UIParent, "ANCHOR_NONE")
    end
    _scanTT:ClearLines()
    local ok = pcall(_scanTT.SetInventoryItem, _scanTT, "player", slotId)
    if ok then
        local patt = emptySocketPatterns()
        for i = 1, _scanTT:NumLines() do
            local fs = _G["GearInsightGMScanTTTextLeft" .. i]
            local txt = fs and fs:GetText()
            if txt then
                for _, p in ipairs(patt) do
                    if txt == p then empty = empty + 1; break end
                end
            end
        end
    end
    return { enchant = enchant, gems = gems, emptySockets = empty, sockets = #gems + empty }
end

-- ── 小部件工厂 ───────────────────────────────────────────────────────────
local function iconButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.texture = b:CreateTexture(nil, "ARTWORK")
    b.texture:SetAllPoints()
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("TOPLEFT", -2, 2); b.border:SetPoint("BOTTOMRIGHT", 2, -2)
    b.border:SetColorTexture(0, 0, 0, 0)
    -- 描边：四条 1px 线（不用 Backdrop，省得 ElvUI 换肤时被扫掉）
    b.edges = {}
    for i = 1, 4 do
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0, 0, 0, 0)
        b.edges[i] = t
    end
    b.edges[1]:SetPoint("TOPLEFT", -1, 1); b.edges[1]:SetPoint("TOPRIGHT", 1, 1); b.edges[1]:SetHeight(1)
    b.edges[2]:SetPoint("BOTTOMLEFT", -1, -1); b.edges[2]:SetPoint("BOTTOMRIGHT", 1, -1); b.edges[2]:SetHeight(1)
    b.edges[3]:SetPoint("TOPLEFT", -1, 1); b.edges[3]:SetPoint("BOTTOMLEFT", -1, -1); b.edges[3]:SetWidth(1)
    b.edges[4]:SetPoint("TOPRIGHT", 1, 1); b.edges[4]:SetPoint("BOTTOMRIGHT", 1, -1); b.edges[4]:SetWidth(1)
    b.itemID = nil; b.itemLink = nil; b.currentItemID = nil
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
local function setEdge(b, rgb, a)
    for _, t in ipairs(b.edges) do t:SetColorTexture(rgb[1], rgb[2], rgb[3], a or 1) end
end

local function smallText(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH("CENTER"); fs:SetWordWrap(false)
    return fs
end

-- 动作链接（前5 / 套装坯子 / 来源）固定放在外侧名字列的第三行：
--   左列  [动作][附魔名][宝石名] 靠右对齐到小格；右列/武器 反之。
-- ⛔ 别锚到 BiS 图标下面：那里是装等数字，且会压到下一行（2026-09-05 截图实证）。
local function placeActions(c)
    c.actTop5:ClearAllPoints(); c.actSrc:ClearAllPoints()
    -- 前5 隐藏时（套装部位）来源/坯子链接顶到它的位置，别留一个空档
    local anchorSrc = c.actTop5:IsShown() and c.actTop5 or nil
    if c.side == "L" then
        c.actTop5:SetPoint("TOPRIGHT", c.gem, "TOPLEFT", -4, -36)
        if anchorSrc then c.actSrc:SetPoint("RIGHT", c.actTop5, "LEFT", -8, 0)
        else c.actSrc:SetPoint("TOPRIGHT", c.gem, "TOPLEFT", -4, -36) end
    else
        c.actTop5:SetPoint("TOPLEFT", c.gem, "TOPRIGHT", 4, -36)
        if anchorSrc then c.actSrc:SetPoint("LEFT", c.actTop5, "RIGHT", 8, 0)
        else c.actSrc:SetPoint("TOPLEFT", c.gem, "TOPRIGHT", 4, -36) end
    end
end

-- 已毕业时 BiS 图标隐藏，但小格/名字/前5 全锚在它身上 → 装备与小格之间空一段（2026-09-05 圣骑截图）。
-- 只需要挪 gem 这一个锚点：ench → gem，名字 → gem/ench，动作 → gem，都会跟着走。
local function anchorMini(c, done)
    local target = done and c.eq or c.bis
    c.gem:ClearAllPoints()
    if c.side == "L" then
        c.gem:SetPoint("TOPRIGHT", target, "TOPLEFT", -3, 0)
    elseif c.side == "V" then
        c.gem:SetPoint("TOPLEFT", target, "TOPRIGHT", 6, 0)
        -- 竖排武器格：装等原本写在装备右侧，已毕业时那个位置被小格占了 → 挪到下面
        c.eqIlvl:ClearAllPoints()
        if done then c.eqIlvl:SetPoint("TOP", c.eq, "BOTTOM", 0, -1)
        else c.eqIlvl:SetPoint("LEFT", c.eq, "RIGHT", 6, 0) end
    else
        c.gem:SetPoint("TOPLEFT", target, "TOPRIGHT", 3, 0)
    end
end

-- ── 一个槽的单元格 ─────────────────────────────────────────────────────
-- side = "L"：装备在左、箭头向右、BiS 在右；"R" 镜像；"B" 同 L（武器行）。
local function ensureCell(self, slotId, side)
    self._gmCells = self._gmCells or {}
    local c = self._gmCells[slotId]
    if c then return c end
    -- ⛔ 必须挂在 _gmFrame 下（不是滚动区）：切回「列表」时 _gmFrame:Hide() 才能把格子一起藏掉。
    --    2026-09-05 截图：格子挂在滚动区上，切列表后整片格子压在列表上面。
    c = CreateFrame("Frame", nil, self._gmFrame or self._scrollChild)
    c:SetSize(CELL_W, ROW_H)
    c.slotId = slotId
    c.side = side

    c.eq  = iconButton(c, ICON)
    c.bis = iconButton(c, ICON)
    c.gem = iconButton(c, MINI)
    c.ench = iconButton(c, MINI)
    -- ⛔ 箭头别用 "→" 字符：zhCN 客户端字体里没有这个字形，渲染成 "…"（2026-09-05 截图实证）。
    c.arrow = c:CreateTexture(nil, "OVERLAY")
    c.arrow:SetSize(ARROW, ARROW)
    c.eqIlvl = smallText(c); c.bisIlvl = smallText(c)
    -- 小格外侧的名字（用户 2026-09-05：「宝石的名字和附魔的名字放在两边」）
    c.gemName = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.enchName = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    for _, fs in ipairs({ c.gemName, c.enchName }) do
        fs:SetWidth(NAME_W); fs:SetWordWrap(false); fs:SetMaxLines(1)
    end
    -- 第三行：动作链接（用户 2026-09-05「套装坯子和 TOP5 怎么点？得设计下」）
    local function linkBtn(text)
        local b = CreateFrame("Button", nil, c)
        b:SetHeight(14)
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.fs:SetAllPoints(); b.fs:SetText("|cFF66CCFF" .. text .. "|r")
        b:SetWidth(math.max(28, (b.fs:GetStringWidth() or 24) + 4))
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    c.actTop5 = linkBtn(T("GM_ACT_TOP5", "前5"))
    c.actSrc  = linkBtn(T("GM_ACT_FILLER", "套装坯子"))
    c.actTop5:SetScript("OnClick", function()
        local p = c.bis._plan
        if p and p.cand and #p.cand > 0 then GearInsight:ShowSlotTop5(p.popupLabel, slotId, p.cand) end
    end)
    c.actTop5:SetScript("OnEnter", function(s2)
        GameTooltip:SetOwner(s2, "ANCHOR_TOP"); GameTooltip:SetText(T("TOP5_BTN_TT", "查看该部位使用率前5"), 1, 0.82, 0); GameTooltip:Show()
    end)
    c.actSrc:SetScript("OnClick", function()
        local p = c.bis._plan
        if p and p.onRightClick then p.onRightClick() end
    end)
    c.actSrc:SetScript("OnEnter", function(s2)
        local p = c.bis._plan
        GameTooltip:SetOwner(s2, "ANCHOR_TOP")
        GameTooltip:ClearLines(); GameTooltip:AddLine(p and p.fillerText or "", 1, 0.82, 0, true)  -- 12.x SetText 只收 4 参，wrap 走 AddLine
        GameTooltip:Show()
    end)
    c.check = c:CreateTexture(nil, "OVERLAY")
    c.check:SetSize(14, 14)
    c.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

    -- 排布（用户 2026-09-05 拍板）：**装备靠内、BiS 靠外**，箭头从装备指向外侧的 BiS，
    -- 小格再贴在 BiS 的外侧。左列：[小格][BiS] ← [装备] │中│ [装备] → [BiS][小格] ：右列
    -- 武器（side="V"）：放中间、推荐往正下方延展：[装备] ↓ [BiS][小格][名字]
    local mirror = (side == "R")
    if side == "V" then
        c:SetSize(ICON + 6 + MINI + 4 + NAME_W, ICON + 14 + ARROW + 4 + ICON + 14 + 16)
        c.eq:SetPoint("TOP", c, "TOP", 0, 0)
        c.arrow:SetPoint("TOP", c.eq, "BOTTOM", 0, -14)
        c.arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        c.arrow:SetRotation(-math.pi / 2)
        c.bis:SetPoint("TOP", c.arrow, "BOTTOM", 0, -4)
        c.gem:SetPoint("TOPLEFT", c.bis, "TOPRIGHT", 6, 0)
        c.ench:SetPoint("TOPLEFT", c.gem, "BOTTOMLEFT", 0, -2)
        c.gemName:SetPoint("LEFT", c.gem, "RIGHT", 4, 0); c.gemName:SetJustifyH("LEFT")
        c.enchName:SetPoint("LEFT", c.ench, "RIGHT", 4, 0); c.enchName:SetJustifyH("LEFT")
        c.eqIlvl:SetPoint("LEFT", c.eq, "RIGHT", 6, 0)
        c.bisIlvl:SetPoint("TOP", c.bis, "BOTTOM", 0, -1)
        c.check:SetPoint("TOPRIGHT", c.eq, "TOPRIGHT", 3, 3)
        -- ⛔ 这里不能 return：下面还要挂悬停/点击脚本，武器格一样需要
    elseif not mirror then
        -- 左列：从右往左排，装备贴单元格右缘（靠中间）
        c.eq:SetPoint("TOPRIGHT", 0, 0)
        c.arrow:SetPoint("RIGHT", c.eq, "LEFT", -4, 0)
        c.arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        c.bis:SetPoint("RIGHT", c.arrow, "LEFT", -4, 0)
        c.gem:SetPoint("TOPRIGHT", c.bis, "TOPLEFT", -3, 0)
        c.ench:SetPoint("TOPRIGHT", c.gem, "BOTTOMRIGHT", 0, -2)
        c.gemName:SetPoint("RIGHT", c.gem, "LEFT", -4, 0); c.gemName:SetJustifyH("RIGHT")
        c.enchName:SetPoint("RIGHT", c.ench, "LEFT", -4, 0); c.enchName:SetJustifyH("RIGHT")
    else
        -- 右列：从左往右排，装备贴单元格左缘（靠中间）
        c.eq:SetPoint("TOPLEFT", 0, 0)
        c.arrow:SetPoint("LEFT", c.eq, "RIGHT", 4, 0)
        c.arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        c.bis:SetPoint("LEFT", c.arrow, "RIGHT", 4, 0)
        c.gem:SetPoint("TOPLEFT", c.bis, "TOPRIGHT", 3, 0)
        c.ench:SetPoint("TOPLEFT", c.gem, "BOTTOMLEFT", 0, -2)
        c.gemName:SetPoint("LEFT", c.gem, "RIGHT", 4, 0); c.gemName:SetJustifyH("LEFT")
        c.enchName:SetPoint("LEFT", c.ench, "RIGHT", 4, 0); c.enchName:SetJustifyH("LEFT")
    end
    if side ~= "V" then          -- 竖排武器格上面已经各自锚好
        c.eqIlvl:SetPoint("TOP", c.eq, "BOTTOM", 0, -1)
        c.bisIlvl:SetPoint("TOP", c.bis, "BOTTOM", 0, -1)
        c.check:SetPoint("TOPRIGHT", c.eq, "TOPRIGHT", 3, 3)
    end

    placeActions(c)

    -- 悬停 / 点击
    c.eq:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        if s.itemLink then GameTooltip:SetHyperlink(s.itemLink)
        elseif s.itemID then GameTooltip:SetItemByID(s.itemID)
        else GameTooltip:SetText(s._label or "", 1, 1, 1) end
        if s._status then GameTooltip:AddLine(s._status, 0.9, 0.9, 0.9, true) end
        GameTooltip:Show()
    end)
    c.bis:SetScript("OnEnter", function(s)
        if not s.itemID then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if s.itemLink then GameTooltip:SetHyperlink(s.itemLink) else GameTooltip:SetItemByID(s.itemID) end
        local p = s._plan
        if p then
            if (p.topIlvl or 0) > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFFFFFF00" .. T("TT_BIS_ILVL", "BiS 装等: ") .. p.topIlvl .. "|r", 1, 1, 1)
                if p.topMx then GameTooltip:AddLine(string.format(T("TT_BIS_TOPMX", "顶尖玩家最高见到 %d"), p.topMx), 0.7, 0.7, 0.7) end
            end
            if p.improvementPct and p.improvementPct > 0 then
                GameTooltip:AddLine(string.format(T("TT_IMPROVE", "提升幅度: +%.1f%%"), p.improvementPct), 0.2, 1, 0.2)
            end
            if p.srcText and p.srcText ~= "" then
                GameTooltip:AddLine(T("SOURCE_PREFIX", "来源: ") .. p.srcText, 0.8, 0.8, 0.8, true)
            end
            if p.fillerText and p.fillerText ~= "" then
                GameTooltip:AddLine(p.fillerText, 0.7, 0.4, 1, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFF66CCFF" .. T("GM_CLICK_TOP5", "点击：该部位使用率前5") .. "|r", 0.4, 0.8, 1)
            if p.hasJournal or p.fillerText then
                GameTooltip:AddLine("|cFF66CCFF" .. T("GM_RCLICK_SRC", "右键：来源 / 套装坯子") .. "|r", 0.4, 0.8, 1)
            end
            GameTooltip:AddLine("|cFF66CCFF" .. T("TT_SHIFT_CHAT", "Shift+点击 发送到聊天") .. "|r", 0.4, 0.8, 1)
        end
        GameTooltip:Show()
    end)
    c.bis:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.bis:SetScript("OnClick", function(s, btn)
        local p = s._plan
        if not p then return end
        if btn == "RightButton" then
            if p.onRightClick then p.onRightClick() end
            return
        end
        if GearInsight._tryChatLink and GearInsight._tryChatLink(s) then return end
        if p.cand and #p.cand > 0 then GearInsight:ShowSlotTop5(p.popupLabel, slotId, p.cand) end
    end)
    local function miniEnter(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local shown = false
        if s._spell and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(s._spell); shown = true
        elseif s.itemID then GameTooltip:SetItemByID(s.itemID); shown = true end
        if not shown then GameTooltip:SetText(s._title or "", 1, 0.82, 0) end
        if s._status then GameTooltip:AddLine(s._status, 0.9, 0.9, 0.9, true) end
        GameTooltip:AddLine("|cFF66CCFF" .. T("GM_MINI_CLICK", "左键：拍卖行开着就直接搜，否则发到聊天 · 右键：复制名字") .. "|r", 0.4, 0.8, 1, true)
        GameTooltip:Show()
    end
    c.gem:SetScript("OnEnter", miniEnter)
    c.ench:SetScript("OnEnter", miniEnter)
    -- 左键：拍卖行开着 → 直接填搜索框并搜；没开 → 把链接/名字发到聊天框（用户 2026-09-05「方便发送或者搜拍卖行」）
    -- 右键：复制名字弹窗（老功能）
    local function miniClick(s2, btn)
        local name, link = s2._name, s2._link
        if not name or name == "" then return end
        if btn == "RightButton" then
            GearInsight:ShowCopyText(name, string.format(T("CONS_COPY_HINT", "Ctrl+C 复制「%s」，到拍卖行搜索框粘贴购买"), name))
            return
        end
        local ah = AuctionHouseFrame
        if ah and ah:IsShown() and ah.SearchBar and ah.SearchBar.SearchBox then
            ah.SearchBar.SearchBox:SetText(name)
            if ah.SearchBar.StartSearch then ah.SearchBar:StartSearch() end
            return
        end
        if link and ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
        if ChatFrame_OpenChat then ChatFrame_OpenChat(link or name) end
    end
    for _, b in ipairs({ c.gem, c.ench }) do
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", miniClick)
    end
    -- 名字也能点（用透明按钮托着 FontString）
    for _, pair in ipairs({ { c.gemName, c.gem }, { c.enchName, c.ench } }) do
        local fs, src = pair[1], pair[2]
        local nb = CreateFrame("Button", nil, c)
        nb:SetAllPoints(fs)
        nb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        nb:SetScript("OnClick", function(_, btn) miniClick(src, btn) end)
        nb:SetScript("OnEnter", function() miniEnter(src) end)
        nb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        fs._btn = nb
    end

    self._gmCells[slotId] = c
    return c
end

-- ── 填一个单元格 ─────────────────────────────────────────────────────────
local function fillCell(self, c, p, data)
    local h = H()
    local setItem = h.setItemForIcon
    c:Show()

    -- 身上这件
    if p and p.eqId then
        if setItem then setItem(c.eq, p.eqId, nil, p.eqLink) end
        if p.eqLink then c.eq.itemLink = p.eqLink end
        c.eqIlvl:SetText(tostring(p.eqIlvl or ""))
    else
        c.eq.itemID = nil; c.eq.itemLink = nil; c.eq.currentItemID = nil
        c.eq.texture:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        c.eqIlvl:SetText("")
    end
    c.eq._label = p and p.slotLabel or ""

    if not p then
        -- 这个槽没有候选：几乎只有一种情况 —— 你双持着、但顶尖玩家主流形态是双手（或反过来）。
        -- 别让它长得像"坏了"：灰边 + 悬停说清楚原因。
        c.arrow:Hide(); c.bis:Hide(); c.bisIlvl:SetText(""); c.gem:Hide(); c.ench:Hide(); c.check:Hide()
        c.gemName:Hide(); c.enchName:Hide(); c.actTop5:Hide(); c.actSrc:Hide()
        setEdge(c.eq, C_NONE, 0.6)
        c.eq._status = (c.slotId == 17)
            and ("|cFFAAAAAA" .. T("GM_OH_NO_PLAN", "顶尖玩家主流形态不用副手（双手武器），这一格没有推荐") .. "|r")
            or ("|cFFAAAAAA" .. T("GM_NO_PLAN", "这一格暂无推荐数据") .. "|r")
        return
    end

    -- ⭐ 副属性契合度（12.1 催化剂保留原件副属性 → 同一个 itemId 可以属性天差地别，
    --   见 core/StatFit.lua 与 bug #128）。⛔只在**身上真有这件**且读得到属性时显示，
    --   读不到就整行不出现 —— 别把「还没缓存」画成「属性很差」。
    local fitLine = ""
    if p and p.eqLink and GearInsight.StatFit then
        local w = data and data.statWeights
        local fit, have = GearInsight.StatFit(p.eqLink, w)
        if fit and have and have[1] then
            local L2 = GearInsight.L or {}
            local names = {}
            for i = 1, math.min(2, #have) do
                local k = have[i].key
                names[#names + 1] = L2["STAT_" .. k:upper()] or k
            end
            local pct = math.floor(fit * 100 + 0.5)
            local col = (pct >= 85 and "|cFF55E055") or (pct >= 65 and "|cFFFFCC33") or "|cFFFF8800"
            fitLine = "\n" .. col .. T("GM_STATFIT", "副属性契合") .. " " .. pct .. "%|r |cFF999999("
                .. table.concat(names, " / ") .. ")|r"
        end
    end

    if p.isComplete then
        -- 已毕业：不画箭头与目标，描绿边 + 对勾；前5 仍可点（看该部位参照）
        c.arrow:Hide(); c.bis:Hide(); c.bisIlvl:SetText(""); c.check:Show()
        anchorMini(c, true)
        c.bis._plan = p
        c.actTop5:SetShown(p.cand and #p.cand > 0 and not p.isTierFiller)   -- 套装部位只留「套装坯子」，不放前5
        placeActions(c)
        c.actSrc:Hide()
        setEdge(c.eq, C_OK, 1)
        c.eq._status = "|cFF55E055" .. T("GM_DONE", "已毕业") .. "|r"
            .. (p.rank and ("  |cFFFFFF00#" .. p.rank .. "|r") or "")
            .. (p.upgradeTo and ("  |cFF66CCFF" .. T("GRAD_UPGRADABLE", "可升级") .. " " .. (p.eqIlvl or 0) .. " → " .. p.upgradeTo .. "|r") or "") .. fitLine
    else
        c.check:Hide(); c.arrow:Show(); c.bis:Show()
        anchorMini(c, false)
        setEdge(c.eq, p.eqId and C_OTHER or C_BAD, 0.9)
        c.eq._status = (p.eqId and (T("GM_UPGRADE", "待提升 → ") .. (p.topName or "")) or ("|cFFFF0000" .. T("SLOT_EMPTY", "(空槽)") .. "|r")) .. fitLine
        if p.wrongStatFit then
            c.eq._status = c.eq._status .. "\n|cFFFFCC33" .. T("GM_TIER_WRONGSTAT", "这件套装是属性不对的坯子转的 → 重刷对属性的坯子再转") .. "|r"
        end
        if p.trackMaxed then
            local tm = p.trackMaxed
            local txt
            if tm.cur >= tm.max then
                txt = string.format(T("GM_TRACK_MAXED", "%s %d/%d 已封顶，这条轨道到不了 %d → 换更高轨道的同款 / 坯子"),
                    tm.name, tm.cur, tm.max, p.topIlvl or 0)
            else
                txt = string.format(T("GM_TRACK_TOO_LOW", "%s %d/%d 升满约 %d，到不了 %d → 不算 BiS，去刷更高难度的同款 / 坯子"),
                    tm.name, tm.cur, tm.max, tm.ceil or 0, p.topIlvl or 0)
            end
            c.eq._status = c.eq._status .. "\n|cFFFFCC33" .. txt .. "|r"
        end
        if setItem then setItem(c.bis, p.topId, p.topBonus) end
        c.bis._plan = p
        c.bisIlvl:SetText("|cFF55E055" .. tostring(p.topIlvl or "") .. "|r")
        setEdge(c.bis, C_OK, 0.7)
        c.actTop5:SetShown(p.cand and #p.cand > 0 and not p.isTierFiller)   -- 套装部位只留「套装坯子」，不放前5
        placeActions(c)
        if p.isTierFiller then
            c.actSrc.fs:SetText("|cFFB060FF" .. T("GM_ACT_FILLER", "套装坯子") .. "|r"); c.actSrc:Show()
        -- 「来源」链接已撤（用户 2026-09-17「这个面板的来源都给删了吧，点了前五或者点装备都能看到」）；
        --   右键 BiS 图标仍可看来源/坯子，悬浮也有来源行。
        else
            c.actSrc:Hide()
        end
    end

    -- 宝石 / 附魔小格：目标是否毕业无关，身上这件到没到位
    local mine = p.eqId and readSlotGemEnch(c.slotId) or nil
    local gems = data and data.gems
    local enchs = data and data.enchants and data.enchants[c.slotId]

    -- 宝石（按 self._gmGemPlan 分配：钻石只推荐一个槽）
    do
        local g = (self._gmGemPlan and self._gmGemPlan[c.slotId]) or (gems and gems[1])
        local status, color, show = nil, C_NONE, false
        -- ⛔ 只在「常规可镶孔」的部位画宝石格（SOCKETABLE），披风/手套等不画（用户 2026-09-05）
        if g and mine and SOCKETABLE[c.slotId] then
            if setItem then setItem(c.gem, g.id, nil) end
            c.gem._title = nil
            show = true
            if not mine or mine.sockets == 0 then
                color = C_NONE
                status = T("GM_GEM_NOSOCKET2", "这件还没打孔（本赛季该部位可镶孔）")
            elseif mine.emptySockets > 0 then
                color = C_BAD
                status = "|cFFFF5555" .. T("GM_GEM_EMPTY", "有空插槽！推荐镶：") .. "|r " .. ((g.id and GearInsight.ItemName and GearInsight.ItemName(g.id)) or g.nameCn or "")
            else
                local okAny = false
                for _, gid in ipairs(mine.gems) do
                    for _, rg in ipairs(gems) do if rg.id == gid then okAny = true break end end
                    if okAny then break end
                end
                -- 钻石装备唯一：这个槽不该再镶钻石（钻石已分配给别的槽）→ 视为"非推荐"，提示换成第二名
                if okAny and g and not isUniqueGem(g) then
                    for _, gid in ipairs(mine.gems) do
                        for _, rg in ipairs(gems) do
                            if rg.id == gid and isUniqueGem(rg) then okAny = false end
                        end
                    end
                end
                color = okAny and C_OK or C_OTHER
                status = okAny and ("|cFF55E055" .. T("GM_GEM_OK", "已镶推荐宝石") .. "|r")
                    or ("|cFFFFCC33" .. T("GM_GEM_OTHER", "镶了非推荐宝石，推荐：") .. "|r " .. ((g.id and GearInsight.ItemName and GearInsight.ItemName(g.id)) or g.nameCn or ""))
            end
        end
        c.gem:SetShown(show)
        setEdge(c.gem, color, 1)
        c.gem._status = status
        c.gem.texture:SetDesaturated(color == C_NONE)
        c.gemName:SetShown(show); if c.gemName._btn then c.gemName._btn:SetShown(show) end
        if show then
            local h2 = H()
            local nm = (g and ((h2.getCN and h2.getCN(g.id)) or (GearInsight.ItemName and GearInsight.ItemName(g.id)) or g.nameCn)) or ""
            c.gemName:SetText(nm); c.gemName:SetTextColor(color[1], color[2], color[3])
            c.gem._name = nm
            c.gem._link = g and select(2, GetItemInfo(g.id)) or nil
        end
    end

    -- 附魔
    do
        local e = enchs and enchs[1]
        local show, color, status = false, C_NONE, nil
        -- ⛔ 只在数据里有该槽的附魔推荐时才画（顶尖玩家真的在附魔的槽）；
        --    ENCHANTABLE 那张静态表会把护腕/披风这类本赛季没人附魔的槽标成红色"没有附魔"（2026-09-05 截图）。
        if e then
            show = true
            if e then
                local kit = (c.slotId == 7) and LEG_KIT[e.id] or nil
                c.ench.itemID = kit and kit.item or e.item or nil
                c.ench._spell = (not kit) and e.spell or nil
                local tex
                if kit and C_Item and C_Item.GetItemIconByID then tex = C_Item.GetItemIconByID(kit.item) end
                if not tex and e.spell and C_Spell and C_Spell.GetSpellTexture then tex = C_Spell.GetSpellTexture(e.spell) end
                if not tex and e.item and C_Item and C_Item.GetItemIconByID then tex = C_Item.GetItemIconByID(e.item) end
                if not tex and e.icon and e.icon ~= "" then tex = "Interface\\Icons\\" .. e.icon end
                c.ench.texture:SetTexture(tex or "Interface\\Icons\\INV_Misc_Note_01")
                c.ench._title = _enchNm(e, c.slotId)
            else
                c.ench.itemID = nil; c.ench._spell = nil
                c.ench.texture:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
                c.ench._title = T("GM_ENCH_TITLE", "附魔")
            end
            if not mine then
                color = C_NONE; status = nil
            elseif (mine.enchant or 0) == 0 then
                color = C_BAD
                status = "|cFFFF5555" .. T("GM_ENCH_MISSING", "没有附魔！") .. "|r" .. (e and (" " .. T("GM_RECOMMEND", "推荐：") .. _enchNm(e, c.slotId)) or "")
            else
                local okAny = false
                if enchs then
                    for _, re in ipairs(enchs) do if re.id == mine.enchant then okAny = true break end end
                else
                    okAny = true      -- 数据里没推荐的槽，有附魔就算到位
                end
                color = okAny and C_OK or C_OTHER
                status = okAny and ("|cFF55E055" .. T("GM_ENCH_OK", "已附推荐附魔") .. "|r")
                    or ("|cFFFFCC33" .. T("GM_ENCH_OTHER", "附了非推荐附魔，推荐：") .. "|r " .. _enchNm(e, c.slotId))
            end
        end
        c.ench:SetShown(show)
        setEdge(c.ench, color, 1)
        c.ench._status = status
        c.ench.texture:SetDesaturated(color == C_NONE)
        c.enchName:SetShown(show); if c.enchName._btn then c.enchName._btn:SetShown(show) end
        if show then
            local kit = (c.slotId == 7 and e) and LEG_KIT[e.id] or nil
            local nm = _enchNm(e, c.slotId); if nm == "" then nm = T("GM_ENCH_TITLE", "附魔") end
            c.enchName:SetText(nm); c.enchName:SetTextColor(color[1], color[2], color[3])
            c.ench._name = nm; c.ench._link = nil
            if kit then c.ench._link = select(2, GetItemInfo(kit.item))      -- 真物品链接：发聊天 / 拍卖行都能直接用
            elseif e and e.spell and C_Spell and C_Spell.GetSpellLink then c.ench._link = C_Spell.GetSpellLink(e.spell) end
        end
    end
end

-- 条宽可变：目标刻度线是按 sbW*(1/1.25) 的绝对偏移锚的，改宽度必须一起挪它
local function setBarWidth(bar, w)
    bar:SetWidth(w)
    for _, r in ipairs({ bar:GetRegions() }) do
        if r.GetWidth and r:GetWidth() == 2 and r.GetDrawLayer and r:GetDrawLayer() == "OVERLAY" then
            r:ClearAllPoints()
            r:SetPoint("TOP", bar, "TOPLEFT", w / 1.25, 0)
            r:SetPoint("BOTTOM", bar, "BOTTOMLEFT", w / 1.25, 0)
        end
    end
end

-- ── 属性条整块搬进中间 ─────────────────────────────────────────────────
local function moveStatsIntoCenter(self, center, on)
    if not self._statRows then return end
    local keys = { "crit", "haste", "mastery", "versatility" }
    for i, sk in ipairs(keys) do
        local sr = self._statRows[sk]
        if sr and sr.bar then
            local rowFrame = sr.bar:GetParent()
            if on then
                if not sr._orig then
                    sr._orig = { parent = rowFrame:GetParent() }
                end
                rowFrame:SetParent(center)
                rowFrame:ClearAllPoints()
                rowFrame:SetPoint("TOPLEFT", center, "TOPLEFT", 0, -28 - (i - 1) * 36)
                rowFrame:SetWidth(CENTER_W); rowFrame:SetHeight(30)
                setBarWidth(sr.bar, 150)
                -- 数值小字挪到条下面，不然横向放不下
                sr.val:ClearAllPoints()
                sr.val:SetPoint("TOPLEFT", sr.bar, "BOTTOMLEFT", 0, -1)
                sr.val:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
            elseif sr._orig then
                rowFrame:SetParent(sr._orig.parent)
                rowFrame:ClearAllPoints()
                local ry = -160 - (i - 1) * 26
                rowFrame:SetPoint("TOPLEFT", 20, ry); rowFrame:SetPoint("TOPRIGHT", -20, ry)
                rowFrame:SetHeight(13)
                setBarWidth(sr.bar, 150)
                sr.val:ClearAllPoints()
                sr.val:SetPoint("LEFT", sr.bar, "RIGHT", 8, 0)
                sr.val:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
            end
        end
    end
    -- 参照系三个按钮跟着走
    if self._statModeBtns and self._statModeBtns[1] then
        local b1 = self._statModeBtns[1]
        b1:ClearAllPoints()
        if on then
            b1:SetParent(center)
            b1:SetPoint("TOPLEFT", center, "TOPLEFT", 0, 0)
        elseif self._stHdr then
            b1:SetParent(self._panelFrame)
            b1:SetPoint("LEFT", self._stHdr, "LEFT", 108, 1)
        end
        for i = 2, #self._statModeBtns do
            local b = self._statModeBtns[i]
            b:SetParent(b1:GetParent())
            b:ClearAllPoints(); b:SetPoint("LEFT", self._statModeBtns[i - 1], "RIGHT", 2, 0)
        end
    end
end

-- ── 顶部切换按钮 ───────────────────────────────────────────────────────
local function ensureToggle(self)
    if self._gmToggle then return self._gmToggle end
    local b = CreateFrame("Button", nil, self._panelFrame, "UIPanelButtonTemplate")
    b:SetSize(72, 20)
    b:SetPoint("TOPRIGHT", self._panelFrame, "TOPRIGHT", -30, -284)
    b:SetFrameLevel(60)
    b:SetScript("OnClick", function()
        GearInsightDB = GearInsightDB or {}
        GearInsightDB.gearView = (GearInsightDB.gearView == "list") and "map" or "list"
        GearInsight:RefreshPanel()
    end)
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("GM_TOGGLE_TIP", "装备图 = 按角色面板栏位排布，箭头指向该换的 BiS 件，小格是宝石/附魔到位情况。\n列表 = 旧版逐条列出（过渡保留）。"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self._gmToggle = b
    -- 刷新面板时若当前不在总览页（比如在心愿单页触发了 RefreshPanel），也不能把它露出来（bug #121）
    if self._mainTabKey and self._mainTabKey ~= "overview" then b:Hide() end
    return b
end

function GearInsight:GearMapActive()
    return not (GearInsightDB and GearInsightDB.gearView == "list")
end

-- ── 主入口：RefreshPanel 在列表画完、制造推荐之前调它 ─────────────────────
-- 返回新的 yOff。map 模式：把列表全部藏掉，从 0 开始画格子；list 模式：把格子藏掉，原样返回。
function GearInsight:_renderGearMap(yOff, data)
    local sc = self._scrollChild
    if not sc or not self._panelFrame then return yOff end
    local tg = ensureToggle(self)
    local active = self:GearMapActive()
    tg:SetText(active and T("GM_TOGGLE_LIST", "列表") or T("GM_TOGGLE_MAP", "装备图"))

    -- 顶部区域：属性达成度留在原位不动（用户 2026-09-05：「中间空出来」——两列中间像暴雪一样留白）。
    -- 把属性条搬进中间那套逻辑保留但不再启用（moveStatsIntoCenter(false) 只做还原）。
    if self._upHdr then self._upHdr:SetText(active and T("GM_TITLE", "装备图") or T("SECTION_NEXT", "下一步建议")) end
    if self._stHdr then self._stHdr:Show() end
    if self._stInfo then self._stInfo:Show() end
    if self._sep2 then self._sep2:Show() end
    -- 面板加宽 / 还原（只改宽度，位置与其它锚点不动）
    if self._panelFrame and self._panelFrame.SetWidth then
        self._panelFrame:SetWidth(active and MAP_PANEL_W or LIST_PANEL_W)
    end
    if sc then sc:SetWidth(active and GRID_W or 470) end
    if self._scroll then
        self._scroll:ClearAllPoints()
        if self._upHdr then self._upHdr:ClearAllPoints(); self._upHdr:SetPoint("TOPLEFT", 20, -286) end
        tg:ClearAllPoints(); tg:SetPoint("TOPRIGHT", self._panelFrame, "TOPRIGHT", -30, -284)
        self._scroll:SetPoint("TOPLEFT", 16, -308)
        self._scroll:SetPoint("BOTTOMRIGHT", -28, 70)
    end

    if not active then
        if self._gmFrame then self._gmFrame:Hide() end
        if self._gmCenter then moveStatsIntoCenter(self, self._gmCenter, false) end
        return yOff
    end

    -- 藏掉旧列表的所有部件
    if self._upgradeRows then for _, r in ipairs(self._upgradeRows) do r:Hide() end end
    if self._slotHeaders then for _, h in pairs(self._slotHeaders) do h:Hide() end end
    if self._emptyUpgradeLabel then self._emptyUpgradeLabel:Hide() end
    if self._gradHeader then self._gradHeader:Hide() end
    if self._gradRows then for _, r in ipairs(self._gradRows) do r:Hide() end end

    -- 容器
    if not self._gmFrame then
        local f = CreateFrame("Frame", nil, sc)
        f:SetPoint("TOPLEFT", 0, 0)
        f:SetWidth(GRID_W)
        self._gmFrame = f
        local center = CreateFrame("Frame", nil, f)
        center:SetSize(CENTER_W, ROW_H * 8)
        center:SetPoint("TOP", f, "TOP", 0, 0)
        self._gmCenter = center
        -- 中间：毕业进度一行
        center.summary = center:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        center.summary:SetPoint("TOPLEFT", center, "TOPLEFT", 0, -190)
        center.summary:SetWidth(CENTER_W); center.summary:SetJustifyH("LEFT"); center.summary:SetWordWrap(true)
        center.legend = center:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        center.legend:SetPoint("TOPLEFT", center, "TOPLEFT", 0, -196)
        center.legend:SetWidth(CENTER_W); center.legend:SetJustifyH("LEFT"); center.legend:SetWordWrap(true)
    end
    local f, center = self._gmFrame, self._gmCenter
    f:Show()
    moveStatsIntoCenter(self, center, false)     -- 中间留空，属性条待在顶部

    local plan = self._slotPlan or {}
    self._gmGemPlan = planGems(data and data.gems, function(sid)
        local eqId = GetInventoryItemID and GetInventoryItemID("player", sid)
        return eqId and readSlotGemEnch(sid) or nil
    end)
    local rows = math.max(#LEFT_SLOTS, #RIGHT_SLOTS)
    -- 左列
    for i, slotId in ipairs(LEFT_SLOTS) do
        if slotId then
            local c = ensureCell(self, slotId, "L")
            c:ClearAllPoints(); c:SetPoint("TOPRIGHT", center, "TOPLEFT", -GAP, -(i - 1) * ROW_H)
            fillCell(self, c, plan[slotId], data)
        end
    end
    -- 右列（镜像）
    for i, slotId in ipairs(RIGHT_SLOTS) do
        local c = ensureCell(self, slotId, "R")
        c:ClearAllPoints(); c:SetPoint("TOPLEFT", center, "TOPRIGHT", GAP, -(i - 1) * ROW_H)
        fillCell(self, c, plan[slotId], data)
    end
    -- 底部武器行
    local wy = -(rows * ROW_H) - 6
    do
        -- 武器放中间、竖排（用户 2026-09-05）：双手 = 一个竖块居中；双持 = 两个竖块围着中线
        local mh = ensureCell(self, 16, "V")
        local oh = ensureCell(self, 17, "V")
        local ohEq = GetInventoryItemID and GetInventoryItemID("player", 17)
        local showOH = plan[17] or ohEq
        mh:ClearAllPoints(); oh:ClearAllPoints()
        if showOH then
            mh:SetPoint("TOPRIGHT", f, "TOP", -8, wy)
            oh:SetPoint("TOPLEFT", f, "TOP", 8, wy)
            fillCell(self, mh, plan[16], data)
            fillCell(self, oh, plan[17], data)
        else
            mh:SetPoint("TOP", f, "TOP", -NAME_W / 2, wy)     -- 图标居中（名字在右侧，整体略左偏）
            fillCell(self, mh, plan[16], data)
            oh:Hide()
        end
    end
    -- 中间摘要
    local done, total = 0, 0
    for _, p in pairs(plan) do total = total + 1; if p.isComplete then done = done + 1 end end
    center.summary:Hide()      -- 用户 2026-09-05：绿字不放中间，放到上面标题行
    if self._upHdr then
        local hdr = T("GM_TITLE", "装备图") .. "   |cFF55E055" .. done .. "|r|cFFAAAAAA / " .. total .. " "
            .. T("GM_SUMMARY", "个部位已毕业") .. "|r"
        -- 美化超上限提示（台账 #142，玩家「灰色头像不会再跳动」报「这都三件美化了」）。
        -- ⭐ 网站那边认不出哪件带美化（打造时加的，物品模板上没有），
        --    但插件能**直接读你身上的物品提示**数出来 —— 是事实不是推测。
        -- ⛔ 只在真的超了（>2）时才加这一行，⛔别没事也占一行。
        if GearInsight.EmbellishNote then
            local ok, note = pcall(GearInsight.EmbellishNote, GearInsight)
            if ok and note then
                hdr = hdr .. "   |cFFFF9926" .. note .. "|r"
            end
        end
        self._upHdr:SetText(hdr)
    end
    center.legend:ClearAllPoints()
    center.legend:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 8, wy - (ICON + 14 + ARROW + 4 + ICON + 14 + 16) - 6)
    center.legend:SetWidth(GRID_W - PAD * 2 - 16)
    center.legend:SetText(T("GM_LEGEND", "小格 = 宝石 / 附魔：绿 已到位 · 黄 非推荐 · 红 缺 · 灰 无\n点 BiS 件看前5，右键看来源/坯子"))

    local WEAPON_H = ICON + 14 + ARROW + 4 + ICON + 14 + 16
    local h = rows * ROW_H + 6 + WEAPON_H + 6 + 30 + 8
    f:SetHeight(h)
    return -h
end
