-- PvP 装备参照（用户 2026-09-10「把 PvP 装备 BiS 推荐纳入插件」）。
--
-- ⛔ 这不是 PvE BiS 的第四档，是**另一张表**：PvP 装备全是荣誉/征服买的、实例里装等拉平，
--    玩家要的是「每部位买哪个副属性版本、哪些部位换套装件、饰品/宝石/附魔配什么」。
-- ⛔⛔ 形态 = 左侧独立页签「PvP 装备」，与天赋/心愿单同款（MainTabs newPage + Build 函数）。
--    第一版做成「参照系第三档 + 在总览页上盖一层」，层级压住了其它页签、切换逻辑和
--    BisData 的参照系互相踩（用户 2026-09-10「你不是应该和其他的视图一样吗」）。
-- 数据 core/PvpGear.lua（export_pvp_gear.py 生成，按 specID 建键）。
-- 口径：上榜玩家实际穿的，不是理论最优；征服装实例内 344、荣誉装 331 —— 同组合优先征服版本。
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
local _ZH = (_LOCALE == "zhCN" or _LOCALE == "zhTW")

local GOLD, WHITE, DIM, GREEN, ORANGE, BLUE = "|cFFFFD100", "|cFFE6E0C8", "|cFF8A93A6", "|cFF40FF40", "|cFFFF9933", "|cFF7FB0FF"
local SLOT_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 16, 17 }   -- 饰品(13)单独一行，不进逐部位表
local SLOT_CN = { [1]="头部", [2]="颈部", [3]="肩部", [5]="胸部", [6]="腰部", [7]="腿部", [8]="脚",
                  [9]="手腕", [10]="手", [11]="戒指", [13]="饰品", [15]="背部", [16]="主手", [17]="副手" }
local SLOT_EN = { [1]="Head", [2]="Neck", [3]="Shoulder", [5]="Chest", [6]="Waist", [7]="Legs", [8]="Feet",
                  [9]="Wrist", [10]="Hands", [11]="Rings", [13]="Trinkets", [15]="Back", [16]="Main hand", [17]="Off hand" }
local SEC_EN = { crit="Crit", haste="Haste", mastery="Mastery", vers="Vers" }
local SRC_EN = { conquest="Conquest", honor="Honor (stopgap)", tier="Tier", crafted="Crafted (PvP)", pve="PvE" }
local SRC_CN = { conquest="征服", honor="荣誉过渡", tier="套装", crafted="制造(PvP)", pve="PvE" }

local function secName(k)
    local pg = GearInsight.PvpGear
    if _ZH then return (pg and pg.secCn and pg.secCn[k]) or k end
    return SEC_EN[k] or k
end
local function sigName(sig)
    if not sig or sig == "" then return "—" end
    local out = {}
    for k in sig:gmatch("[^/]+") do out[#out + 1] = secName(k) end
    return table.concat(out, " / ")
end
local function srcName(src)
    local pg = GearInsight.PvpGear
    if _ZH then return SRC_CN[src] or src end
    return SRC_EN[src] or src
end

-- 身上这一格的副属性组合（"haste/vers" 形态，与数据侧同一套排序）。
-- ⛔ 只看键存不存在，不碰数值：12.x 里 GetItemStats 的值可能是 secret，不参与算术就不会炸。
local KEYMAP = { crit="crit", haste="haste", mastery="mastery", versatility="vers" }
local function mySig(slotId)
    local gr = GearInsight.GearReader
    if not (gr and gr.ReadSlot) then return nil end
    local sigs = {}
    local ids = (slotId == 11) and { 11, 12 } or ((slotId == 13) and { 13, 14 } or { slotId })
    for _, id in ipairs(ids) do
        local ok, info = pcall(gr.ReadSlot, gr, id)
        if ok and info and not info.empty and type(info.stats) == "table" then
            local ks = {}
            for k in pairs(info.stats) do
                if KEYMAP[k] then ks[#ks + 1] = KEYMAP[k] end
            end
            table.sort(ks)
            sigs[#sigs + 1] = table.concat(ks, "/")
        end
    end
    return sigs
end

-- ── 悬浮 ────────────────────────────────────────────────────────────────
-- 带 bonusID 的链接才有「在竞技场…提高至 344」那一行；SetItemByID 只给野外基础装等。
-- ⛔ 但暴雪那行「物品等级 292」是野外值，玩家要看的是 PvP 里生效的（用户 2026-09-10 三次「还是 292」）
--    → 把提示里的物品等级那一行**改写**成 PvP 值，野外值放括号里。
local PVP_ILVL = { conquest = 344, honor = 331 }
-- PvP 里实际生效的装等：暴雪提示原文征服装「提高至 344」、荣誉/制造「提高至 331」；按基础装等分档。
-- PvE 来源的件不拉平 → nil。
local function pvpIlvl(it)
    if not (it and it.lv and it.lv > 0) then return nil end
    if it.src == "pve" then return nil end
    return (it.lv >= 292) and 344 or 331
end
local _ILVL_PAT
local function ilvlPattern()
    if _ILVL_PAT == nil then
        local fmt = ITEM_LEVEL or "Item Level %d"
        local esc = fmt:gsub("%p", "%%%0")          -- 先把所有标点转义（%d 变成 %%d）
        esc = esc:gsub("%%%%d", "(%%d+)")           -- 再把转义后的 %d 换回捕获组
        _ILVL_PAT = "^" .. esc .. "$"
    end
    return _ILVL_PAT
end
local function rewriteIlvlLine(pv, lv)
    if not pv then return end
    for i = 2, 6 do
        local f = _G["GameTooltipTextLeft" .. i]
        local txt = f and f:GetText()
        if txt and txt:match(ilvlPattern()) then
            f:SetText(string.format(ITEM_LEVEL or "Item Level %d", pv)
                .. string.format("  |cFF8A93A6(PvP · %s %d)|r", T("PVPG_TIP_WORLD", "野外"), lv or 0))
            f:SetTextColor(0.4, 0.8, 1)
            return
        end
    end
end
local function tipItem(it)
    local id, b = it.id, it.b
    if b and b ~= "" then
        local n = select(2, b:gsub(":", "")) + 1
        GameTooltip:SetHyperlink("|Hitem:" .. id .. ":0::::::::0:::" .. n .. ":" .. b .. "|h[item]|h")
    else
        GameTooltip:SetItemByID(id)
    end
    local pv = pvpIlvl(it) or PVP_ILVL[it.src]
    rewriteIlvlLine(pv, it.lv)
    if pv then
        GameTooltip:AddLine(string.format(T("PVPG_TIP_WORN2", "上榜玩家穿的这件：野外 %d · 实例 PvP 内 %d"), it.lv or 0, pv), 0.4, 0.8, 1)
    end
end

function GearInsight:_pvpGearData()
    local pg = self.PvpGear
    local specID = GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
    if not (pg and specID) then return nil, specID end
    return pg[specID], specID
end

-- ── 装备图形态（用户 2026-09-11「视图变成这种一样的」= 与总览「装备图」同款）────
-- 左右两列 = 暴雪角色面板顺序；每格 [装备]→[推荐]，推荐外侧三行字：装备名 / 副属性·占比 / 来源·√×。
-- 页宽只有 ~460（不动主面板宽度，⛔别在这里改 _panelFrame），所以格子比装备图紧一号。
-- 几何：铺满滚动区 460 宽（用户 2026-09-11「平均分布下，不好看，有空的」）——两列各 218，中缝 24，
-- 名字列尽量宽（118），图标收到 30 / 小格 14 / 箭头 10。
local ICON, ARROW, ROW_H = 30, 10, 58
local MINI_S = 14                -- 附魔/宝石小格（用户 2026-09-11「附魔和上面的视图结合」）
local FIXED_W = 4 + MINI_S + 4 + ICON + 4 + ARROW + 4 + ICON               -- 100：一格里除名字列之外的部分
-- 页宽是动态的：主面板在「装备图」模式下 760 宽、列表模式 520 宽，PvP 页跟着变（2026-09-11 截图右侧空一大块）。
-- 每次渲染按滚动区实际宽度重算：中缝随宽度加大，名字列吃掉其余。
local PAGE_W, CENTER_W, CELL_W, NAME_W = 460, 24, 218, 118
local function layoutFor(w)
    PAGE_W = math.max(460, math.floor(w or 460))
    CENTER_W = 24 + math.floor((PAGE_W - 460) * 0.25)
    CELL_W = math.floor((PAGE_W - CENTER_W) / 2)
    NAME_W = CELL_W - FIXED_W
end
local SOCKETABLE = { [1] = true, [2] = true, [11] = true, [12] = true }    -- 本赛季默认有孔的部位（与装备图同口径）

-- 附魔名：EnchantNames 10 语言表（PvP 附魔 id 已并入生成器）；缺的退回英文并去掉「Enchant X - 」前缀
local function enchName(id, en)
    local loc = GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
    if loc == "esMX" then loc = "esES" elseif loc == "enGB" then loc = "enUS" end
    local t = GearInsight.EnchantNames and GearInsight.EnchantNames[id]
    if t then
        local n = t[loc] or t.enUS
        if n and n ~= "" then return n end
    end
    en = en or ""
    return (en:gsub("^[^-–:：]+%s*[-–:：]%s+", ""))
end
-- 身上这一格的附魔 id 与宝石 id（读物品链接：item:id:ench:gem1:gem2:gem3:gem4）
local function myEnchGems(slotId)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
    if not link then return nil, {} end
    local ench = tonumber(link:match("item:%d+:(%d+)")) or 0
    local gems = {}
    local g1, g2, g3, g4 = link:match("item:%d+:%d*:(%d*):(%d*):(%d*):(%d*)")
    for _, g in ipairs({ g1, g2, g3, g4 }) do
        local n = tonumber(g)
        if n and n > 0 then gems[#gems + 1] = n end
    end
    return ench, gems
end
local LEFT_SLOTS  = { 1, 2, 3, 15, 5, false, false, 9 }
local RIGHT_SLOTS = { 10, 6, 7, 8, 11, 12, 13, 14 }
local SRC_RANK = { conquest = 0, tier = 1, crafted = 2, honor = 3, pve = 4 }

-- ── 小格行（宝石 / 附魔 / 其他准备）：[图标] 名字 · 说明；悬浮看属性；左键拍卖行搜 / 右键复制 ──
-- 与装备图小格同一套交互（用户 2026-09-11「推荐的宝石，可以点击搜索AH，可以鼠标TOOLTIP看到属性」）。
local MINI = 18
local function miniClick(s2, btn)
    if s2._onClick then s2._onClick(); return end
    local name = s2._name
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
    local link = s2._itemId and select(2, GetItemInfo(s2._itemId))
    if link and ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(link or name) end
end
local function miniEnter(s2)
    GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if s2._itemId then GameTooltip:SetItemByID(s2._itemId)
    else GameTooltip:SetText(s2._name or s2._title or "", 1, 0.82, 0) end
    if s2._status then GameTooltip:AddLine(s2._status, 0.9, 0.9, 0.9, true) end
    if s2._onClick then
        GameTooltip:AddLine("|cFF66CCFF" .. (s2._clickHint or "") .. "|r", 0.4, 0.8, 1, true)
    elseif s2._name then
        GameTooltip:AddLine("|cFF66CCFF" .. T("GM_MINI_CLICK", "左键：拍卖行开着就直接搜，否则发到聊天 · 右键：复制名字") .. "|r", 0.4, 0.8, 1, true)
    end
    GameTooltip:Show()
end
local function getMini(page, i)
    page._pvpMinis = page._pvpMinis or {}
    local m = page._pvpMinis[i]
    if not m then
        m = CreateFrame("Button", nil, page._pvpSc)
        m:SetSize(PAGE_W - 24, MINI + 2)
        m.icon = m:CreateTexture(nil, "ARTWORK"); m.icon:SetSize(MINI, MINI); m.icon:SetPoint("LEFT", 0, 0)
        m.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        m.txt = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        m.txt:SetPoint("LEFT", m.icon, "RIGHT", 5, 0); m.txt:SetPoint("RIGHT", -4, 0); m.txt:SetJustifyH("LEFT")
        m.txt:SetWordWrap(false); if m.txt.SetMaxLines then m.txt:SetMaxLines(1) end
        m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        m:SetScript("OnClick", miniClick)
        m:SetScript("OnEnter", miniEnter)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page._pvpMinis[i] = m
    end
    m._itemId, m._name, m._title, m._status, m._onClick, m._clickHint = nil, nil, nil, nil, nil, nil
    m:Show()
    return m
end

local function qualCol(q)
    return (q and q > 0 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]) and ITEM_QUALITY_COLORS[q].hex or WHITE
end

-- 同一组合里挑代表件：征服 > 套装 > 制造 > 荣誉 > PvE（同组合征服版本高一档）
local function pickItem(items)
    local best
    for _, it in ipairs(items or {}) do
        if not best or (SRC_RANK[it.src] or 9) < (SRC_RANK[best.src] or 9)
            or ((SRC_RANK[it.src] or 9) == (SRC_RANK[best.src] or 9) and (it.n or 0) > (best.n or 0)) then
            best = it
        end
    end
    return best
end

-- 某个装备格该画哪条推荐：戒指 11/12 用同一部位的第 1/2 个组合；饰品 13/14 用饰品榜第 1/2；其余第 1 组合
local function planFor(d, slotId)
    if slotId == 13 or slotId == 14 then
        local t = d.trinkets and d.trinkets[slotId - 12]
        if not t then return nil end
        return { it = t, sig = nil, pct = t.pct, items = { t } }
    end
    local key = (slotId == 12) and 11 or slotId
    local rows = d.slots and d.slots[key]
    if not rows or #rows == 0 then return nil end
    local r = (slotId == 12 and rows[2]) or rows[1]
    return { it = pickItem(r.items), sig = r.sig, pct = r.pct, items = r.items }
end

local function iconButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.texture = b:CreateTexture(nil, "ARTWORK"); b.texture:SetAllPoints()
    b.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.edges = {}
    for i = 1, 4 do
        local t = b:CreateTexture(nil, "OVERLAY"); t:SetColorTexture(0, 0, 0, 0); b.edges[i] = t
    end
    b.edges[1]:SetPoint("TOPLEFT", -1, 1); b.edges[1]:SetPoint("TOPRIGHT", 1, 1); b.edges[1]:SetHeight(1)
    b.edges[2]:SetPoint("BOTTOMLEFT", -1, -1); b.edges[2]:SetPoint("BOTTOMRIGHT", 1, -1); b.edges[2]:SetHeight(1)
    b.edges[3]:SetPoint("TOPLEFT", -1, 1); b.edges[3]:SetPoint("BOTTOMLEFT", -1, -1); b.edges[3]:SetWidth(1)
    b.edges[4]:SetPoint("TOPRIGHT", 1, 1); b.edges[4]:SetPoint("BOTTOMRIGHT", 1, -1); b.edges[4]:SetWidth(1)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
local function setEdge(b, r, g, bl, a)
    for _, t in ipairs(b.edges) do t:SetColorTexture(r, g, bl, a or 1) end
end
local function mkText(parent, w, just)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if w then f:SetWidth(w) end
    f:SetJustifyH(just or "CENTER"); f:SetWordWrap(false)
    if f.SetMaxLines then f:SetMaxLines(1) end
    return f
end
local function slotLabel(slotId)
    local k = (slotId == 12) and 11 or ((slotId == 14) and 13 or slotId)
    return _ZH and SLOT_CN[k] or SLOT_EN[k]
end

-- side = "L"：[名字][推荐]←[装备] │ ；"R"：│ [装备]→[推荐][名字]
local function ensureCell(page, slotId, side)
    page._pvpCells = page._pvpCells or {}
    local c = page._pvpCells[slotId]
    if c then return c end
    c = CreateFrame("Frame", nil, page._pvpSc)
    c:SetSize(CELL_W, ROW_H)
    c.slotId, c.side = slotId, side
    c.eq  = iconButton(c, ICON)
    c.bis = iconButton(c, ICON)
    c.arrow = c:CreateTexture(nil, "OVERLAY"); c.arrow:SetSize(ARROW, ARROW)
    c.arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    c.eqIlvl = mkText(c); c.bisIlvl = mkText(c)
    c.name = mkText(c, NAME_W)
    c.stat = mkText(c, NAME_W)
    c.src  = mkText(c, NAME_W)
    c.check = c:CreateTexture(nil, "OVERLAY"); c.check:SetSize(12, 12)
    -- 附魔 / 宝石小格：贴在推荐件外侧、上下叠放；悬浮看属性，左键搜 AH / 右键复制（同「其他准备」的小格行）
    c.ench = iconButton(c, MINI_S); c.gem = iconButton(c, MINI_S)
    for _, b in ipairs({ c.ench, c.gem }) do
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", miniClick)
        b:SetScript("OnEnter", miniEnter)
    end
    c.ench:SetPoint("TOP", c.bis, "TOP", 0, 0)
    c.gem:SetPoint("TOP", c.ench, "BOTTOM", 0, -2)
    if side == "R" then
        c.eq:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
        c.arrow:SetPoint("LEFT", c.eq, "RIGHT", 4, 0)
        c.bis:SetPoint("LEFT", c.arrow, "RIGHT", 4, 0)
        c.ench:SetPoint("LEFT", c.bis, "RIGHT", 4, 0)
        c.name:SetPoint("TOPLEFT", c.ench, "TOPRIGHT", 4, 1); c.name:SetJustifyH("LEFT")
        c.stat:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -1); c.stat:SetJustifyH("LEFT")
        c.src:SetPoint("TOPLEFT", c.stat, "BOTTOMLEFT", 0, -1); c.src:SetJustifyH("LEFT")
    else
        c.eq:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
        c.arrow:SetPoint("RIGHT", c.eq, "LEFT", -4, 0)
        c.arrow:SetTexCoord(1, 0, 0, 1)
        c.bis:SetPoint("RIGHT", c.arrow, "LEFT", -4, 0)
        c.ench:SetPoint("RIGHT", c.bis, "LEFT", -4, 0)
        c.name:SetPoint("TOPRIGHT", c.ench, "TOPLEFT", -4, 1); c.name:SetJustifyH("RIGHT")
        c.stat:SetPoint("TOPRIGHT", c.name, "BOTTOMRIGHT", 0, -1); c.stat:SetJustifyH("RIGHT")
        c.src:SetPoint("TOPRIGHT", c.stat, "BOTTOMRIGHT", 0, -1); c.src:SetJustifyH("RIGHT")
    end
    c.eqIlvl:SetPoint("TOP", c.eq, "BOTTOM", 0, -1)
    c.bisIlvl:SetPoint("TOP", c.bis, "BOTTOM", 0, -1)
    c.check:SetPoint("BOTTOMRIGHT", c.bis, "BOTTOMRIGHT", 2, -2)
    c.eq:SetScript("OnEnter", function(s2)
        if s2._has then
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT"); GameTooltip:SetInventoryItem("player", slotId); GameTooltip:Show()
        end
    end)
    c.bis:SetScript("OnEnter", function(s2)
        local p = s2._plan
        if not (p and p.it) then return end
        GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
        tipItem(p.it)
        GameTooltip:AddLine(" ")
        if p.sig then
            GameTooltip:AddLine(string.format("%s · %s · %.0f%%", slotLabel(slotId), sigName(p.sig), p.pct or 0), 1, 0.82, 0)
        else
            GameTooltip:AddLine(string.format("%s · %.0f%%", slotLabel(slotId), p.pct or 0), 1, 0.82, 0)
        end
        for _, x in ipairs(p.items or {}) do
            local nm2 = x.cn
            if not _ZH and C_Item and C_Item.GetItemNameByID then nm2 = C_Item.GetItemNameByID(x.id) or x.cn end
            GameTooltip:AddDoubleLine((nm2 or ("#" .. x.id)), (x.src and (srcName(x.src) .. "  ") or "") .. tostring(x.n or ""), 0.9, 0.9, 0.9, 0.6, 0.6, 0.6)
        end
        GameTooltip:AddLine(T("PVPG_TIP_NOTE", "上榜玩家实际穿的；同组合的征服版本比荣誉版本高一档"), 0.55, 0.58, 0.65, true)
        GameTooltip:Show()
    end)
    page._pvpCells[slotId] = c
    return c
end

-- 身上这一格的装等（走 GearReader，和总览同一口径）
local function myIlvl(slotId)
    local gr = GearInsight.GearReader
    if not (gr and gr.ReadSlot) then return nil end
    local ok, info = pcall(gr.ReadSlot, gr, slotId)
    if ok and info and not info.empty then return info.ilvl or info.itemLevel end
    return nil
end

local function fillMini(b, x)
    -- x = { icon, itemId, name, status, edge={r,g,b} }；nil = 藏
    if not x then b:Hide(); return end
    b:Show()
    b.texture:SetTexture(x.icon or 134400)
    b._itemId, b._name, b._title, b._status, b._onClick, b._clickHint = x.itemId, x.name, x.title, x.status, nil, nil
    if x.edge then setEdge(b, x.edge[1], x.edge[2], x.edge[3], 1) else setEdge(b, 0.3, 0.3, 0.35, 1) end
end

local function fillCell(c, plan, itemBits, d)
    local slotId = c.slotId
    c:SetWidth(CELL_W)
    c.name:SetWidth(NAME_W); c.stat:SetWidth(NAME_W); c.src:SetWidth(NAME_W)
    -- 小格：附魔（按部位，戒指两格共用）+ 宝石（只画默认有孔的部位，推荐榜首那颗）
    local myEnch, myGems = myEnchGems(slotId)
    local ex = d.enchants and d.enchants[(slotId == 12) and 11 or slotId]
    if ex and (ex.pct or 0) >= 15 then
        local nm = enchName(ex.id, ex.name)
        local edge = (myEnch == ex.id) and { 0.2, 0.8, 0.2 } or ((myEnch and myEnch > 0) and { 0.9, 0.75, 0.2 } or { 0.9, 0.3, 0.3 })
        fillMini(c.ench, { icon = "Interface\\Icons\\ui_profession_enchanting", name = nm, edge = edge,
                           status = string.format("%s · %.0f%%  %s", slotLabel(slotId), ex.pct or 0,
                               (myEnch == ex.id) and (GREEN .. T("PVPG_MINI_OK", "已到位") .. "|r")
                               or ((myEnch and myEnch > 0) and (ORANGE .. T("PVPG_MINI_OTHER", "身上是别的") .. "|r")
                               or ("|cFFFF5555" .. T("PVPG_MINI_NONE", "身上没附") .. "|r"))) })
    else
        fillMini(c.ench, nil)
    end
    local gx = SOCKETABLE[slotId] and d.gems and d.gems[1]
    if gx then
        local hit, any = false, (#myGems > 0)
        for _, g in ipairs(myGems) do if g == gx.id then hit = true end end
        local nm = _ZH and gx.cn or ((C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(gx.id)) or gx.cn)
        fillMini(c.gem, { icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(gx.id), itemId = gx.id, name = nm,
                          edge = hit and { 0.2, 0.8, 0.2 } or (any and { 0.9, 0.75, 0.2 } or { 0.9, 0.3, 0.3 }),
                          status = string.format(T("PVPG_GEM_N", "上榜玩家镶了 %d 颗"), gx.n or 0) .. "  " ..
                              (hit and (GREEN .. T("PVPG_MINI_OK", "已到位") .. "|r")
                               or (any and (ORANGE .. T("PVPG_MINI_OTHER", "身上是别的") .. "|r")
                               or ("|cFFFF5555" .. T("PVPG_MINI_NONE2", "身上没镶") .. "|r"))) })
    else
        fillMini(c.gem, nil)
    end
    -- 内侧：身上
    local eqTex = GetInventoryItemTexture and GetInventoryItemTexture("player", slotId)
    if eqTex then
        c.eq.texture:SetTexture(eqTex); c.eq._has = true
        local lv = myIlvl(slotId)
        c.eqIlvl:SetText(lv and tostring(lv) or "")
        setEdge(c.eq, 0.35, 0.35, 0.4, 1)
    else
        c.eq.texture:SetTexture(134400); c.eq._has = false     -- 问号
        c.eqIlvl:SetText(""); setEdge(c.eq, 0.25, 0.25, 0.3, 1)
    end
    -- 外侧：推荐
    c.bis._plan = plan
    c.check:Hide()
    if not (plan and plan.it) then
        c.bis:Hide(); c.arrow:Hide(); c.bisIlvl:SetText("")
        c.name:SetText(DIM .. "—|r"); c.stat:SetText(""); c.src:SetText("")
        return
    end
    c.bis:Show(); c.arrow:Show()
    local it = plan.it
    local nm, ic = itemBits(it.id)
    c.bis.texture:SetTexture(ic or 134400)
    local pv = pvpIlvl(it)
    c.bisIlvl:SetText(pv and ("|cFF66BBFF" .. pv .. "|r") or ((it.lv and it.lv > 0) and (DIM .. it.lv .. "|r") or ""))
    c.name:SetText(qualCol(it.q) .. (nm or it.cn or ("#" .. it.id)) .. "|r")
    -- 与身上一致？（副属性组合）——戒指/饰品两格共用一份 mySig（含两件），取对应那件
    local mark, same = "", nil
    if plan.sig then
        local mine = mySig((slotId == 12) and 11 or slotId) or {}
        local mySlot = mine[1]
        if slotId == 12 or slotId == 14 then mySlot = mine[2] or mine[1] end
        if mySlot then same = (mySlot == plan.sig) end
    end
    if same == true then
        c.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); c.check:Show()
        setEdge(c.bis, 0.2, 0.8, 0.2, 1); mark = GREEN .. " √|r"
    elseif same == false then
        setEdge(c.bis, 0.9, 0.55, 0.2, 1); mark = ORANGE .. " ×|r"
    else
        setEdge(c.bis, 0.35, 0.35, 0.4, 1)
    end
    if plan.sig then
        c.stat:SetText(WHITE .. sigName(plan.sig) .. "|r  " .. DIM .. string.format("%.0f%%", plan.pct or 0) .. "|r")
    else
        c.stat:SetText(DIM .. string.format("%.0f%%", plan.pct or 0) .. "|r")
    end
    c.src:SetText(DIM .. (it.src and srcName(it.src) or "") .. "|r" .. mark)
end

-- ── 属性达成度（用户 2026-09-11「pvp也要有这个」= 总览那四条条）──────────────
-- 目标 = 上榜玩家副属性占比 × 你身上的副属性评级总量（与总览 statPct 路线同口径；PvP 数据没有绝对均值）。
-- 档位/颜色/文案与总览一致：<90% 不足(红) · <100% 容差内(黄) · ≤110% 达标(绿) · 超标(橙) · 目标占比<最大的 30% 非核心(灰)。
local SB_W, SB_H = 120, 13   -- 条短一点，右边的「超标 多236 (+124%)」才放得下
local STAT_KEYS = { "crit", "haste", "mastery", "versatility" }
local STAT_DATA = { crit = "crit", haste = "haste", mastery = "mastery", versatility = "vers" }
local function ensureStatRows(page)
    if page._pvpStatRows then return page._pvpStatRows end
    local names = { crit = T("STAT_CRIT", "暴击"), haste = T("STAT_HASTE", "急速"), mastery = T("STAT_MASTERY", "精通"), versatility = T("STAT_VERS", "全能") }
    local rows = {}
    for _, sk in ipairs(STAT_KEYS) do
        local rf = CreateFrame("Frame", nil, page._pvpSc)
        rf:SetSize(PAGE_W - 24, SB_H)
        local lbl = rf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT"); lbl:SetWidth(40); lbl:SetJustifyH("LEFT"); lbl:SetText(names[sk])
        local bar = CreateFrame("StatusBar", nil, rf)
        bar:SetSize(SB_W, SB_H); bar:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        bar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
        bar:SetMinMaxValues(0, 1.25); bar:SetValue(0)
        local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
        local tick = bar:CreateTexture(nil, "OVERLAY"); tick:SetColorTexture(1, 1, 1, 0.8); tick:SetWidth(2)
        tick:SetPoint("TOP", bar, "TOPLEFT", SB_W / 1.25, 0); tick:SetPoint("BOTTOM", bar, "BOTTOMLEFT", SB_W / 1.25, 0)
        local val = rf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("LEFT", bar, "RIGHT", 8, 0); val:SetPoint("RIGHT", rf, "RIGHT", 0, 0)
        val:SetWordWrap(false); val:SetJustifyH("LEFT")
        rows[sk] = { frame = rf, bar = bar, val = val }
    end
    page._pvpStatRows = rows
    return rows
end
-- 返回占用高度
local function renderStatBars(page, d, y)
    local rows = ensureStatRows(page)
    local snap = GearInsight.StatReader and GearInsight.StatReader:ReadAll() or {}
    local sec, secR = snap.secondary or {}, snap.secondaryRating or {}
    local total = 0
    for _, sk in ipairs(STAT_KEYS) do total = total + (secR[sk] or 0) end
    local pct = d.sec or {}
    local tgt, maxTgt = {}, 0
    for _, sk in ipairs(STAT_KEYS) do
        local p = pct[STAT_DATA[sk]] or 0
        tgt[sk] = (total > 0) and math.floor(p / 100 * total + 0.5) or 0
        if tgt[sk] > maxTgt then maxTgt = tgt[sk] end
    end
    for i, sk in ipairs(STAT_KEYS) do
        local r = rows[sk]
        r.frame:ClearAllPoints(); r.frame:SetPoint("TOPLEFT", 12, y - (i - 1) * 20); r.frame:Show()
        local cur, curR, t = sec[sk] or 0, secR[sk] or 0, tgt[sk]
        if t == 0 then
            r.bar:SetValue(0); r.val:SetText("-")
        else
            local isCore = not (maxTgt > 0 and t < maxTgt * 0.30)
            local ratio = curR / t
            r.bar:SetValue(math.min(ratio, 1.25))
            local cr, cg, cb, tag, tc, showGap, isOver
            if not isCore then cr, cg, cb = 0.55, 0.55, 0.55; tag = T("TAG_NONCORE", "非核心"); tc = "|cFF999999"
            elseif ratio < 0.9 then cr, cg, cb = 1, 0.2, 0.1; tag = T("TAG_LOW", "不足"); tc = "|cFFFF0000"; showGap = true
            elseif ratio < 1.0 then cr, cg, cb = 0.95, 0.75, 0.1; tag = T("TAG_TOL", "容差内"); tc = "|cFFFFFF00"; showGap = true
            elseif ratio <= 1.1 then cr, cg, cb = 0.2, 1, 0.1; tag = T("TAG_OK", "达标"); tc = "|cFF00FF00"; isOver = true
            else cr, cg, cb = 1, 0.6, 0.1; tag = T("TAG_OVER", "超标"); tc = "|cFFFF8800"; isOver = true end
            r.bar:SetStatusBarColor(cr, cg, cb, 0.9)
            local gap = t - curR
            local dev = (curR - t) / t * 100
            local detail = ""
            if showGap and gap > 0 then detail = string.format(T("TAG_GAP_R3", " 缺%d (%.0f%%)"), gap, dev)
            elseif isOver and gap < 0 then detail = string.format(T("TAG_OVER_R3", " 多%d (+%.0f%%)"), -gap, dev) end
            local pctText = (cur and cur > 0) and string.format("|cFFAAAAAA(%.1f%%)|r", cur) or ""
            r.val:SetText(string.format("%s%d|r%s |cFF888888→|r%s%d %s%s%s|r", tc, curR, pctText, T("LBL_TGT", "目标"), t, tc, tag, detail))
        end
    end
    return #STAT_KEYS * 20 + 4
end

-- ── 页签页构建：MainTabs.selectTab("pvp") 每次进页都调 ──────────────────────
function GearInsight:BuildPvpGearPage(page)
    if not page then return end
    if not page._pvpBuilt then
        page._pvpBuilt = true
        local sf = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 8, -40); sf:SetPoint("BOTTOMRIGHT", -28, 10)
        local sc = CreateFrame("Frame", nil, sf); sc:SetSize(460, 10); sf:SetScrollChild(sc)
        page._pvpSf, page._pvpSc, page._pvpRows = sf, sc, {}
    end
    self:_renderPvpGear(page)
end

local function getRow(page, i, h)
    local sc = page._pvpSc
    local row = page._pvpRows[i]
    if not row then
        row = CreateFrame("Button", nil, sc)
        row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(); row.bg:Hide()
        row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.txt:SetPoint("LEFT", 8, 0); row.txt:SetPoint("RIGHT", -8, 0); row.txt:SetJustifyH("LEFT")
        if row.txt.SetWordWrap then row.txt:SetWordWrap(false) end
        if row.txt.SetMaxLines then row.txt:SetMaxLines(1) end
        page._pvpRows[i] = row
    end
    row:SetSize(PAGE_W - 4, h or 18); row.bg:Hide()
    row:EnableMouse(false); row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
    row:Show()
    return row
end

function GearInsight:_renderPvpGear(page)
    -- 先按滚动区实际宽度定几何，再画（宽度在切「装备图/列表」后会变）
    layoutFor(page._pvpSf and page._pvpSf:GetWidth())
    page._pvpSc:SetWidth(PAGE_W)
    for _, r in ipairs(page._pvpRows) do r:Hide() end
    if page._pvpCells then for _, c in pairs(page._pvpCells) do c:Hide() end end
    if page._pvpMinis then for _, m in ipairs(page._pvpMinis) do m:Hide() end end
    if page._pvpStatRows then for _, r in pairs(page._pvpStatRows) do r.frame:Hide() end end
    local y, ri = -4, 0
    local function line(text, h, kind)
        ri = ri + 1
        local row = getRow(page, ri, h)
        row.txt:SetText(text)
        if kind == "hdr" then
            row.bg:SetColorTexture(1, 0.82, 0, 0.07); row.bg:Show()
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, y)
        y = y - (h or 18) - 1
        return row
    end

    local d = self:_pvpGearData()
    local pg = self.PvpGear or {}
    if not d then
        line(GOLD .. T("PVPG_TITLE", "PvP 装备参照") .. "|r", 22, "hdr")
        line(DIM .. T("PVPG_NODATA", "当前专精暂无 PvP 装备数据（切到对应专精了吗？）") .. "|r", 18)
        page._pvpSc:SetHeight(-y + 8); return
    end
    local modeCN = (pg.mode == "shuffle") and T("PVP_MODE_SHUFFLE", "单人成队") or T("PVP_MODE_BLITZ", "战场突袭")
    line(string.format("%s%s|r  |cFF66BBFF[%s · %s]|r  %s%s|r",
        GOLD, T("PVPG_TITLE", "PvP 装备参照"), modeCN,
        string.format(T("PVP_TOP_N", "榜前 %d 名"), pg.top or 0),
        WHITE, string.format(T("PVPG_SAMPLE", "样本 %d 人 · 分数中位 %d"), d.n or 0, d.rating or 0)), 22, "hdr")
    local sec = d.sec or {}
    local order = { "vers", "haste", "mastery", "crit" }
    table.sort(order, function(a, b) return (sec[a] or 0) > (sec[b] or 0) end)
    local parts = {}
    for _, k in ipairs(order) do parts[#parts + 1] = string.format("%s %.0f%%", secName(k), sec[k] or 0) end
    line("    " .. BLUE .. T("PVPG_SEC", "副属性分布：") .. "|r" .. WHITE .. table.concat(parts, " · ") .. "|r", 18)
    -- 属性达成度四条（目标 = 上榜占比 × 你的副属性总评级）
    line("    " .. DIM .. T("PVPG_STAT_HINT", "属性达成度 · 目标 = 上榜玩家占比 × 你身上的副属性总量") .. "|r", 16)
    y = y - renderStatBars(page, d, y)
    line("    " .. DIM .. T("PVPG_LEGEND4", "[身上]→[推荐][附魔/宝石小格]  蓝字 = 实例 PvP 内装等 · 绿框 一致/已到位 · 橙 不一致 · 红 缺") .. "|r", 16)
    if (d.rating or 0) < 1600 then
        line("    " .. ORANGE .. string.format(T("PVPG_LOWSAMPLE", "! 这个专精上榜玩家分数中位只有 %d，样本质量低，仅供参考"), d.rating or 0) .. "|r", 16)
    end
    y = y - 6

    -- 装备名/图标是异步的：冷缓存先画占位，加载完整页重画一次（⛔别每件各重画一次）
    local pendingReload = false
    local function itemBits(id)
        local nm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        local ic = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
        if not nm and Item and Item.CreateFromItemID and not pendingReload then
            pendingReload = true
            local it = Item:CreateFromItemID(id)
            it:ContinueOnItemLoad(function()
                if page:IsShown() then GearInsight:_renderPvpGear(page) end
            end)
        end
        return nm, ic
    end

    local sc = page._pvpSc
    local top = y
    local rows = math.max(#LEFT_SLOTS, #RIGHT_SLOTS)
    -- 斑马底：每行一条浅带铺满页宽（不占 y，只是垫在格子后面）
    for i = 1, rows + 1 do
        if i % 2 == 0 then
            ri = ri + 1
            local band = getRow(page, ri, ROW_H)
            band.txt:SetText(""); band.bg:SetColorTexture(1, 1, 1, 0.03); band.bg:Show()
            band:ClearAllPoints(); band:SetPoint("TOPLEFT", 2, top - (i - 1) * ROW_H + 6)
            if i == rows + 1 then band:SetPoint("TOPLEFT", 2, top - rows * ROW_H - 4 + 6) end
        end
    end
    local midX = PAGE_W / 2   -- 页中线（随实际页宽）
    for i, slotId in ipairs(LEFT_SLOTS) do
        if slotId then
            local c = ensureCell(page, slotId, "L")
            c:ClearAllPoints(); c:SetPoint("TOPRIGHT", sc, "TOPLEFT", midX - CENTER_W / 2, top - (i - 1) * ROW_H)
            fillCell(c, planFor(d, slotId), itemBits, d); c:Show()
        end
    end
    for i, slotId in ipairs(RIGHT_SLOTS) do
        local c = ensureCell(page, slotId, "R")
        c:ClearAllPoints(); c:SetPoint("TOPLEFT", sc, "TOPLEFT", midX + CENTER_W / 2, top - (i - 1) * ROW_H)
        fillCell(c, planFor(d, slotId), itemBits, d); c:Show()
    end
    -- 武器行：主手左、副手右，各自靠中线
    local wy = top - rows * ROW_H - 4
    local mh = ensureCell(page, 16, "L")
    mh:ClearAllPoints(); mh:SetPoint("TOPRIGHT", sc, "TOPLEFT", midX - CENTER_W / 2, wy)
    fillCell(mh, planFor(d, 16), itemBits, d); mh:Show()
    local ohPlan = planFor(d, 17)
    local oh = ensureCell(page, 17, "R")
    if ohPlan or (GetInventoryItemID and GetInventoryItemID("player", 17)) then
        oh:ClearAllPoints(); oh:SetPoint("TOPLEFT", sc, "TOPLEFT", midX + CENTER_W / 2, wy)
        fillCell(oh, ohPlan, itemBits, d); oh:Show()
    else
        oh:Hide()
    end
    y = wy - ROW_H - 6

    -- ── 其他准备：宝石 / 附魔 / 套装 / PvP 天赋 / 消耗品（小格行）──────────────
    local mi = 0
    local function mini(x, text)
        mi = mi + 1
        local m = getMini(page, mi)
        m:ClearAllPoints(); m:SetPoint("TOPLEFT", 14, y)
        m.icon:SetTexture(x.icon or 134400)
        m._itemId, m._name, m._title, m._status, m._onClick, m._clickHint = x.itemId, x.name, x.title, x.status, x.onClick, x.clickHint
        m.txt:SetText(text)
        y = y - MINI - 3
        return m
    end
    local function nameOf(id, cn)
        if _ZH then return cn or ("#" .. id) end
        local nm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        return nm or cn or ("#" .. id)
    end
    line(GOLD .. T("PVPG_PREP", "其他准备") .. "|r  " .. DIM .. T("PVPG_PREP_HINT", "悬浮看属性 · 左键拍卖行搜 · 右键复制名") .. "|r", 20, "hdr")
    -- 宝石：上榜玩家实际镶的（按人数排）
    if d.gems and #d.gems > 0 then
        line("    " .. BLUE .. T("PVPG_GEMS", "宝石：") .. "|r", 16)
        for i, x in ipairs(d.gems) do
            if i <= 4 then
                local nm = nameOf(x.id, x.cn)
                local ic = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(x.id)
                local st = string.format(T("PVPG_GEM_N", "上榜玩家镶了 %d 颗"), x.n or 0)
                mini({ icon = ic, itemId = x.id, name = nm, status = st }, WHITE .. nm .. "|r  " .. DIM .. st .. "|r")
            end
        end
    end
    -- 套装
    if d.setName and d.setName ~= "" then
        line("    " .. BLUE .. T("PVPG_SET", "套装：") .. "|r" .. WHITE .. string.format(T("PVPG_SET_FMT", "%s · 4 件套只有 %.0f%% 的人凑齐 —— 多数人只拿 2 件挑属性"), d.setName, d.set4 or 0) .. "|r", 18)
    end
    y = y - 2
    -- PvP 天赋：跳天赋页 PvP 档
    mini({ icon = "Interface\\Icons\\Achievement_BG_winWSG", title = T("PVPG_PREP_TAL", "PvP 天赋"),
           onClick = function() if GearInsight._selectMainTab then pcall(GearInsight._selectMainTab, "talent") end end,
           clickHint = T("PVPG_PREP_TAL_CLICK", "点击打开天赋页") },
         BLUE .. T("PVPG_PREP_TAL", "PvP 天赋") .. "：|r" .. WHITE .. T("PVPG_PREP_TAL_TXT", "天赋页第四档「PvP」—— 榜首导入串 + 专属天赋选择率") .. "|r  " .. BLUE .. ">>|r")
    -- 消耗品：总览页那栏在 PvP 里同样适用（合剂 / 药水 / 食物 / 武器油）
    mini({ icon = "Interface\\Icons\\inv_12_profession_alchemy_flask_sindoreipotion_yellow", title = T("PVPG_PREP_CONS", "消耗品"),
           onClick = function() if GearInsight._selectMainTab then pcall(GearInsight._selectMainTab, "overview") end end,
           clickHint = T("PVPG_PREP_CONS_CLICK", "点击回装备总览看消耗品栏") },
         BLUE .. T("PVPG_PREP_CONS", "消耗品") .. "：|r" .. WHITE .. T("PVPG_PREP_CONS_TXT", "合剂 / 药水 / 食物 / 武器油同 PvE，看装备总览底部") .. "|r  " .. BLUE .. ">>|r")
    y = y - 4
    line("    " .. DIM .. T("PVPG_LEGEND2", "征服装实例内 344 · 荣誉装 331 · 套装件走催化") .. "|r", 16)
    line("    " .. DIM .. T("PVPG_FOOT", "数据：暴雪官方 PvP 排行榜逐人档案；这是他们穿的，不是「最优解」。") .. "|r", 16)
    page._pvpSc:SetHeight(-y + 8)
    if GearInsight.Skin then GearInsight.Skin.Sweep(page) end
end

-- 兼容旧调用点（0.80.0 那版从 RefreshPanel / SetUsageMode 调过它）：现在无事可做
function GearInsight:RefreshPvpGearView() end
