-- 大米攻略：WCL 真实数据驱动的 M+ 地下城攻略（致死技能榜/打断优先级/重伤来源）。
-- 数据来自 core/DungeonData.lua（~30局/本：高层+20~24 与 +12 各半聚合）。
-- 进本自动弹出（可关）；面板按钮手动打开。
GearInsight = GearInsight or {}
-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。
-- ⛔别再写 GetLocale()：每个文件各抄一份就会出现“面板英文、大米攻略中文”这种分裂。
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local t = GearInsight.LOC and (GearInsight.LOC[_LOCALE] or GearInsight.LOC["enUS"])
    return (t and t[key]) or zh
end

-- Localized spell name: client API first (correct per-locale), then baked cn/en.
local function spellName(sid, cn, en)
    if sid and sid > 1 and C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(sid)
        if n and n ~= "" then return n end
    end
    if _LOCALE == "zhCN" or _LOCALE == "zhTW" then
        return (_LOCALE == "zhTW" and GearInsight.S2T) and GearInsight.S2T(cn) or cn
    end
    return (en ~= "" and en) or cn
end

local function spellIcon(sid)
    if sid and sid > 1 and C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(sid)
        if tex then return "|T" .. tex .. ":14:14:0:0|t " end
    end
    return ""
end

-- kick-rate tiers: what top players actually do
local function kickTier(rate)
    if rate >= 75 then return T("DG_KICK_MUST", "必断"), 1, 0.25, 0.25
    elseif rate >= 40 then return T("DG_KICK_HIGH", "高优"), 1, 0.6, 0.15
    elseif rate >= 25 then return T("DG_KICK_MED", "有余力断"), 1, 0.85, 0.3
    else return T("DG_KICK_LOW", "可忽略"), 0.55, 0.55, 0.55 end
end

function GearInsight:ShowDungeonGuide(selectIdx, fromZone)
    local data = GearInsightDungeonData
    if not data or #data == 0 then
        self:Print(T("DG_NODATA", "大米攻略数据未加载"))
        return
    end

    -- toggle off on manual second click (zone-trigger never closes an open window)
    if self._dgFrame and self._dgFrame:IsShown() and not fromZone and selectIdx == nil then
        self._dgFrame:Hide()
        return
    end
    self._dgSelected = selectIdx or self._dgSelected or 1

    if not self._dgFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightDungeonGuide")
        f:SetSize(520, 540)
        GearInsight:AnchorPopup(f)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(22)
        f:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
        f:EnableMouse(true)
        f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

        self._dgTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        self._dgTitle:SetPoint("TOP", 0, -12)
        self._dgTitle:SetText(T("DG_TITLE", "大米攻略"))

        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4)
        cb:SetScript("OnClick", function() f:Hide() end)

        -- dungeon selector: two rows of four
        f._dgBtns = {}
        for i = 1, #data do
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(118, 22)
            local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
            b:SetPoint("TOPLEFT", 14 + col * 122, -40 - row * 25)
            b:SetText(spellName(0, data[i].cn, data[i].en))
            b:SetScript("OnClick", function() GearInsight:ShowDungeonGuide(i, true) end)
            f._dgBtns[i] = b
        end

        -- auto-popup toggle (default ON)
        local chk = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        chk:SetSize(22, 22)
        chk:SetPoint("BOTTOMLEFT", 12, 8)
        chk.text = chk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        chk.text:SetPoint("LEFT", chk, "RIGHT", 2, 0)
        chk.text:SetText(T("DG_AUTOPOP", "进本自动弹出"))
        chk:SetChecked(not (GearInsightDB and GearInsightDB.dungeonAutoPopupOff))
        chk:SetScript("OnClick", function(s)
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.dungeonAutoPopupOff = (not s:GetChecked()) or nil
        end)

        -- 临场提示开关（LiveGuide：姓名板关注点卡片+读条高亮，默认开）
        local lchk = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        lchk:SetSize(22, 22)
        lchk:SetPoint("LEFT", chk.text, "RIGHT", 14, 0)
        lchk.text = lchk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lchk.text:SetPoint("LEFT", lchk, "RIGHT", 2, 0)
        lchk.text:SetText(T("LG_TOGGLE", "临场提示(必断/致死高亮)"))
        lchk:SetChecked(not (GearInsightDB and GearInsightDB.liveGuideOff))
        lchk:SetScript("OnClick", function(s)
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.liveGuideOff = (not s:GetChecked()) or nil
            if GearInsight.LiveGuideRefresh then GearInsight:LiveGuideRefresh() end
        end)

        -- 嗜血监控总开关（嗜血点提示 + 嗜血窗口条 + 光环监听，默认关）
        local bchk = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        bchk:SetSize(22, 22)
        bchk:SetPoint("BOTTOMLEFT", 12, 30)
        bchk.text = bchk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bchk.text:SetPoint("LEFT", bchk, "RIGHT", 2, 0)
        bchk.text:SetText(T("LG_LUSTBAR_TOGGLE", "嗜血监控(嗜血点提示+窗口条)"))
        bchk:SetChecked((GearInsightDB and GearInsightDB.lustBarOn) and true or false)
        bchk:SetScript("OnClick", function(s)
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.lustBarOn = s:GetChecked() or nil
            if GearInsight.LustBarRefresh then GearInsight:LustBarRefresh() end
        end)

        local src = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        src:SetPoint("BOTTOMRIGHT", -14, 12)
        src:SetText(T("DG_SOURCE", "数据: WCL 高层+12层 真实局聚合"))

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -94)
        scroll:SetPoint("BOTTOMRIGHT", -28, 52)
        local sc = CreateFrame("Frame", nil, scroll)
        sc:SetWidth(470)
        scroll:SetScrollChild(sc)
        self._dgScrollChild = sc
        self._dgFrame = f
    end

    -- highlight selected dungeon button
    for i, b in ipairs(self._dgFrame._dgBtns) do
        local fs = b:GetFontString()
        if fs then
            if i == self._dgSelected then fs:SetTextColor(1, 0.82, 0)
            else fs:SetTextColor(1, 1, 1) end
        end
    end

    -- ── render detail (pooled row buttons: icon-markup text + spell tooltip) ──
    local sc = self._dgScrollChild
    sc.rowPool = sc.rowPool or {}
    for _, w in ipairs(sc.rowPool) do w:Hide() end
    local rowIdx, y = 0, 0
    local function nextRow(h)
        rowIdx = rowIdx + 1
        local r = sc.rowPool[rowIdx]
        if not r then
            r = CreateFrame("Button", nil, sc)
            r:SetSize(460, 18)
            r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            r.fs:SetPoint("LEFT", 0, 0)
            r.fs:SetJustifyH("LEFT")
            r.fs:SetWidth(460)
            r:SetScript("OnEnter", function(s)
                if s.itemLink or s.itemID then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if s.itemLink then GameTooltip:SetHyperlink(s.itemLink)
                    else GameTooltip:SetItemByID(s.itemID) end
                    GameTooltip:Show()
                elseif s.spellID and s.spellID > 1 then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:SetSpellByID(s.spellID)
                    GameTooltip:Show()
                end
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            sc.rowPool[rowIdx] = r
        end
        r:SetHeight(h or 18)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        y = y + (h or 18)
        r.spellID = nil
        r.itemID = nil
        r.itemLink = nil
        r:Show()
        return r
    end
    local function header(txt)
        local r = nextRow(24)
        r.fs:SetFontObject("GameFontNormalLarge")
        r.fs:SetText(txt)
        r.fs:SetTextColor(1, 0.82, 0)
    end
    local function line(txt, sid, cr, cg, cb2)
        local r = nextRow(18)
        r.fs:SetFontObject("GameFontNormal")
        r.fs:SetText(txt)
        r.fs:SetTextColor(cr or 0.9, cg or 0.9, cb2 or 0.9)
        r.spellID = sid
    end
    local function gap() y = y + 6 end

    local d = data[self._dgSelected]
    self._dgTitle:SetText(T("DG_TITLE", "大米攻略") .. " — " .. spellName(0, d.cn, d.en))

    -- ① 打断优先级
    if d.kicks and #d.kicks > 0 then
        header(T("DG_SEC_KICKS", "① 打断优先级（顶尖玩家真实打断率）"))
        local sorted = {}
        for _, k in ipairs(d.kicks) do sorted[#sorted + 1] = k end
        table.sort(sorted, function(a, b) return a[4] > b[4] end)
        for _, k in ipairs(sorted) do
            local sid, cn, en, rate, begun, srcCn, srcEn, isBoss = k[1], k[2], k[3], k[4], k[5], k[6], k[7], k[8]
            local tier, tr, tg, tb = kickTier(rate)
            local src = spellName(0, srcCn, srcEn)
            local bossTag = (isBoss == 1) and ("|cffff8000" .. T("DG_BOSS", "[BOSS]") .. "|r ") or ""
            line(string.format("|cff%02x%02x%02x[%s]|r %s%s  |cffaaaaaa%d%%  %s%s|r",
                tr * 255, tg * 255, tb * 255, tier,
                spellIcon(sid), spellName(sid, cn, en), rate, bossTag, src), sid)
        end
        gap()
    end

    -- ② 致死技能榜
    if d.killers and #d.killers > 0 then
        header(T("DG_SEC_KILLERS", "② 致死技能榜（什么在杀人）"))
        line(string.format(T("DG_SAMPLE", "样本: %d局 / %d次死亡"), d.runs or 0, d.deaths or 0),
            nil, 0.6, 0.6, 0.6)
        for _, k in ipairs(d.killers) do
            local sid, cn, en, n = k[1], k[2], k[3], k[4]
            local sev = (n >= 5 and "|cffff4040" or (n >= 2 and "|cffffc040" or "|cffcccccc"))
            line(string.format("%s%s%s  %s%d %s|r",
                sev, spellIcon(sid), spellName(sid, cn, en), sev, n, T("DG_DEATHS", "死")), sid)
        end
        gap()
    end

    -- ③ 重伤来源
    if d.heavy and #d.heavy > 0 then
        header(T("DG_SEC_HEAVY", "③ 重伤来源（死亡前承受的伤害构成）"))
        for _, k in ipairs(d.heavy) do
            local sid, cn, en, share = k[1], k[2], k[3], k[4]
            line(string.format("%s%s  |cffaaaaaa%d%%|r",
                spellIcon(sid), spellName(sid, cn, en), share), sid)
        end
        gap()
    end

    -- ④ 嗜血点位（顶尖局在哪开，按时序）
    if d.lust and #d.lust > 0 then
        header(T("DG_SEC_LUST", "④ 嗜血点位（顶尖局在哪开）"))
        for i, k in ipairs(d.lust) do
            local _, cn, en, isBoss, pct, medMin = k[1], k[2], k[3], k[4], k[5], k[6]
            local bossTag = (isBoss == 1) and ("|cffff8000" .. T("DG_BOSS", "[BOSS]") .. "|r ") or ""
            line(string.format("|cff00ccff%d.|r %s%s  |cffaaaaaa%s|r", i, bossTag,
                spellName(0, cn, en),
                string.format(T("DG_LUST_FMT", "%d%%局在此开 · 约%.0f分钟"), pct, medMin)))
        end
    end

    -- ⑤ 本图资源池（你的 BiS 掉落）：本副本能给你的装备。
    -- 表头永远显示(空了也明说原因)，否则像「缺了一块」——噬灭等专精 BiS 多来自团本/套装，
    -- 单个 M+ 本掉落少。整段 pcall 保护，绝不让它的报错搞崩①-④核心提示。
    pcall(function()
        local sr = GearInsight.StatReader
        local st = sr and sr:ReadAll()
        local class = st and st.class
        local spec  = st and st.spec
        local hero  = st and st.heroTalent
        local bd = GearInsight.BisData
        if not (class and spec and bd) then return end

        -- 2H 检测（与刷本优先级口径一致）
        local is2H = false
        local snap = GearInsight.SavedVars and GearInsight.SavedVars:GetLastSnapshot()
        if snap and snap.equipped and snap.equipped[16] and not snap.equipped[16].empty then
            local mhId = snap.equipped[16].itemId
            if mhId and C_Item and C_Item.GetItemInventoryTypeByID then
                is2H = (C_Item.GetItemInventoryTypeByID(mhId) == 17)
            end
        end
        -- 已装备：itemId→ilvl、每槽最高 ilvl
        local equippedItems, equippedBySlot = {}, {}
        if snap and snap.equipped then
            for _, eq in pairs(snap.equipped) do
                if eq and not eq.empty and eq.itemId then
                    equippedItems[eq.itemId] = eq.ilvl or 0
                    if eq.slotId then
                        equippedBySlot[eq.slotId] = math.max(equippedBySlot[eq.slotId] or 0, eq.ilvl or 0)
                    end
                end
            end
        end

        local function buildLink(itemId, bonusIDs)
            if bonusIDs and #bonusIDs > 0 then
                return "|Hitem:" .. itemId .. ":0::::::::0:::" .. #bonusIDs .. ":" .. table.concat(bonusIDs, ":") .. "|h[item]|h"
            end
        end
        local function itemIcon(itemId)
            local tex = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemId)
            if tex then return "|T" .. tex .. ":16:16:0:0|t " end
            return ""
        end
        local function itemDisplayName(itemId, fallback)
            local n = C_Item and C_Item.GetItemInfo and (C_Item.GetItemInfo(itemId))
            return n or fallback or ("#" .. itemId)
        end

        -- 毕业件首选集合 = GetItemsBySource 的 mplus（每槽 BiS #1）里来自本图的
        local bySource = bd.GetItemsBySource and bd:GetItemsBySource(class, spec, hero, is2H)
        local bisSet = {}
        if bySource and bySource.mplus then
            for _, e in ipairs(bySource.mplus) do
                if e.item and e.item.itemId and e.item.bossName == d.cn then bisSet[e.item.itemId] = true end
            end
        end

        -- 资源池 = 本图所有「在你 BiS 候选表里」的 M+ 掉落(去重)，分四类
        local specData = bd.GetSpecData and bd:GetSpecData(class, spec, hero)
        local bisBySlot = specData and specData.bisBySlot
        local grad, upgrades, sidegrade, ownedN, seen = {}, {}, 0, 0, {}
        if bisBySlot then
            for slotId, cands in pairs(bisBySlot) do
                for _, c in ipairs(cands) do
                    if c.itemId and c.sourceCategory == "mplus" and c.bossName == d.cn and not seen[c.itemId] then
                        seen[c.itemId] = true
                        local eqv = equippedItems[c.itemId]
                        if eqv and eqv >= (c.ilvl or 0) then
                            ownedN = ownedN + 1                              -- 已有(装等达标)
                        elseif bisSet[c.itemId] then
                            grad[#grad + 1] = { slotId = slotId, item = c }  -- 毕业件首选, 缺
                        elseif (c.ilvl or 0) > (equippedBySlot[slotId] or 0) then
                            upgrades[#upgrades + 1] = { slotId = slotId, item = c } -- 散件升级
                        else
                            sidegrade = sidegrade + 1                        -- BiS候选但当前非升级
                        end
                    end
                end
            end
        end

        gap()
        header(T("DG_SEC_LOOT", "⑤ 本图资源池（你的 BiS 掉落）"))
        local poolN = #grad + #upgrades + sidegrade + ownedN
        if poolN == 0 then
            line(T("DG_POOL_NONE", "本图无你的 BiS 相关掉落（你的毕业件主要来自团本/套装）"), nil, 0.6, 0.6, 0.6)
            return
        end
        line(string.format(T("DG_POOL_SUMMARY2", "本图相关 %d 件 · 毕业缺 %d · 可升级 %d · 已有 %d"),
            poolN, #grad, #upgrades, ownedN), nil, 0.6, 0.8, 1)

        local grd = GearInsight.GearReader
        local Lz = GearInsight.L or {}
        local function gearRow(e, tag, cr, cg, cb2)
            local it = e.item
            local slotKey = grd and grd.GetSlotKey and grd:GetSlotKey(e.slotId)
            local slotName = (slotKey and Lz[slotKey]) or (T("DG_SLOT", "槽") .. (e.slotId or 0))
            local nm = itemDisplayName(it.itemId, it.itemName)
            local r = nextRow(18)
            r.fs:SetFontObject("GameFontNormal")
            r.fs:SetText(string.format("%s%s  |cffaaaaaa%s|r  %s", itemIcon(it.itemId), nm, slotName, tag or ""))
            r.fs:SetTextColor(cr, cg, cb2)
            r.itemID = it.itemId
            r.itemLink = buildLink(it.itemId, it.bonusIDs)
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(it.itemId) end
        end

        if #grad > 0 then
            line(T("DG_POOL_GRAD", "▸ 毕业件（优先 R）"), nil, 1, 0.82, 0)
            table.sort(grad, function(a, b) return (a.item.usagePct or 0) > (b.item.usagePct or 0) end)
            for _, e in ipairs(grad) do gearRow(e, T("DG_TAG_NEED", "[缺·优先R]"), 1, 0.85, 0.4) end
        end
        if #upgrades > 0 then
            line(T("DG_POOL_FILLER", "▸ 可升级散件（顺手 R）"), nil, 0.7, 0.7, 0.7)
            table.sort(upgrades, function(a, b) return (a.item.ilvl or 0) > (b.item.ilvl or 0) end)
            for _, e in ipairs(upgrades) do gearRow(e, string.format(T("DG_TAG_UP", "[↑%d]"), e.item.ilvl or 0), 0.75, 0.85, 0.6) end
        end
        if sidegrade > 0 then
            line(string.format(T("DG_POOL_SIDE", "▸ 其它 BiS 候选 %d 件（当前非升级）"), sidegrade), nil, 0.55, 0.55, 0.55)
        end
        if ownedN > 0 then
            line(string.format(T("DG_POOL_DONE2", "▸ 本图已到手 %d 件 ✓"), ownedN), nil, 0.45, 0.7, 0.45)
        end
    end)

    sc:SetHeight(y + 10)
    -- ElvUI 换肤：每次 Show 前扫一遍（动态创建的本选择按钮/行内容也会被扫到）
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._dgFrame) end
    self._dgFrame:Show()
end

-- ── 进本自动弹出 ──────────────────────────────────────────────────────
-- 实例名匹配（中英文都认），不依赖 mapID；M+ 与 M0 难度都触发，每个本每次进入只弹一次。
local zf = CreateFrame("Frame")
zf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zf:RegisterEvent("PLAYER_ENTERING_WORLD")
local _lastShownInstance = nil
zf:SetScript("OnEvent", function()
    if GearInsightDB and GearInsightDB.dungeonAutoPopupOff then return end
    local data = GearInsightDungeonData
    if not data then return end
    local name, instanceType, difficultyID = GetInstanceInfo()
    if instanceType ~= "party" or not name then
        _lastShownInstance = nil
        return
    end
    -- 8 = Mythic Keystone, 23 = Mythic; 教学价值在 M0 同样成立
    if difficultyID ~= 8 and difficultyID ~= 23 then return end
    if name == _lastShownInstance then return end
    for i, d in ipairs(data) do
        if d.cn == name or d.en == name then
            _lastShownInstance = name
            GearInsight:ShowDungeonGuide(i, true)
            GearInsight:Print(T("DG_ZONE_HINT", "已为你打开本图攻略（可在窗口左下角关闭自动弹出）"))
            return
        end
    end
end)
