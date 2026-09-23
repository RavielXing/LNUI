-- 大米攻略：WCL 真实数据驱动的 M+ 地下城攻略（致死技能榜/打断优先级/重伤来源）。
-- 数据来自 core/DungeonData.lua（~30局/本：高层+20~24 与 +12 各半聚合）。
-- 进本自动弹出（可关）；面板按钮手动打开。
GearInsight = GearInsight or {}
-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。
-- ⛔别再写 GetLocale()：每个文件各抄一份就会出现“面板英文、大米攻略中文”这种分裂。
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

-- 2026-09-04 按需加载改造：真身改名 ShowDungeonGuideImpl。
-- 面向外部的 GearInsight:ShowDungeonGuide 现在留在主插件 core/DungeonModule.lua，
-- 它负责「先把本模块加载起来」再转发到这里。⛔别在这里再定义同名函数，会盖掉加载器。
function GearInsight:ShowDungeonGuideImpl(selectIdx, fromZone)
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
        chk:SetPoint("BOTTOMLEFT", 24, 8)      -- 缩进 = 从属于上面的总开关
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

        -- 钥匙时间轴开关（嗜血点预告 + boss 进度 vs 顶尖局，默认开；只在限时钥匙里出现）
        local bchk = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        bchk:SetSize(22, 22)
        bchk:SetPoint("BOTTOMLEFT", 24, 30)    -- 缩进 = 从属于上面的总开关
        bchk.text = bchk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bchk.text:SetPoint("LEFT", bchk, "RIGHT", 2, 0)
        bchk.text:SetText(T("KT_TOGGLE", "钥匙时间轴(嗜血点预告+boss进度vs顶尖局)"))
        bchk:SetChecked(not (GearInsightDB and GearInsightDB.keyTimelineOff))
        bchk:SetScript("OnClick", function(s)
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.keyTimelineOff = (not s:GetChecked()) or nil
            if GearInsight.KeyTimelineRefresh then GearInsight:KeyTimelineRefresh() end
        end)

        -- 钥匙时间轴「解锁位置」（bug #108）：勾上=可拖动且高亮，取消=锁定不拦鼠标
        local ukchk = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        ukchk:SetSize(22, 22)
        ukchk:SetPoint("LEFT", bchk.text, "RIGHT", 14, 0)
        ukchk.text = ukchk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ukchk.text:SetPoint("LEFT", ukchk, "RIGHT", 2, 0)
        ukchk.text:SetText(T("KT_UNLOCK_TOGGLE", "解锁时间轴位置(拖动)"))
        ukchk:SetChecked(GearInsight.KeyTimelineIsUnlocked and GearInsight:KeyTimelineIsUnlocked())
        ukchk:SetScript("OnClick", function(s2)
            if GearInsight.KeyTimelineSetUnlocked then GearInsight:KeyTimelineSetUnlocked(s2:GetChecked()) end
        end)
        ukchk:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_TOP")
            GameTooltip:SetText(T("KT_UNLOCK_TIP", "锁定时时间轴完全不接鼠标（不挡姓名板点击）。要挪位置先勾上、拖到想要的地方、再取消勾选。也可用 /gi kt unlock / lock / reset。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        ukchk:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- 总开关（2026-09-04）：上面三个只是「不显示」，这个是「整个模块不再加载」。
        -- ⭐ 排版红线（用户 2026-09-04 反馈「位置不好找」）：
        --    它一开始跟三个子选项并排放在同一行最右边，四个勾选框长得一模一样 ——
        --    等于把最重要的那个藏进了一排里。现在独占一行放在**最上面**、标签用面板主色，
        --    三个子选项缩进到它下面表示从属关系。⛔ 别再把它塞回那一排。
        local mchk = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        mchk:SetSize(26, 26)
        mchk:SetPoint("BOTTOMLEFT", 10, 56)
        mchk.text = mchk:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        mchk.text:SetPoint("LEFT", mchk, "RIGHT", 2, 0)
        mchk.text:SetTextColor(0.4, 1, 0.5)
        mchk.text:SetText(T("DM_MASTER", "启用副本助手（进本自动加载）"))

        -- 关掉时在同一行右侧说清楚「关了还能怎么用」，免得玩家以为功能没了
        local mhint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        mhint:SetPoint("LEFT", mchk.text, "RIGHT", 8, 0)

        -- 三个子选项与总开关之间画一条线，视觉上分出层级
        local sep = f:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(1, 1, 1, 0.12)
        sep:SetPoint("BOTTOMLEFT", 12, 50)
        sep:SetPoint("BOTTOMRIGHT", -12, 50)
        sep:SetHeight(1)

        local function refreshMaster()
            local off = GearInsight.IsDungeonModuleOff and GearInsight:IsDungeonModuleOff()
            mchk:SetChecked(not off)
            mhint:SetText(off and T("DM_MASTER_OFF", "已关闭 — 仍可用面板的「大米攻略」按钮临时打开") or "")
            -- 子选项从属于总开关：关掉时置灰，明确「这三个现在不生效」
            for _, c in ipairs({ chk, lchk, bchk }) do
                c:SetEnabled(not off)
                c.text:SetTextColor(off and 0.5 or 1, off and 0.5 or 0.82, off and 0.5 or 0)
            end
        end
        f._dgRefreshMaster = refreshMaster

        mchk:SetScript("OnClick", function(s2)
            GearInsightDB = GearInsightDB or {}
            if s2:GetChecked() then
                GearInsightDB.dungeonModule = "on"
                GearInsight:Print(T("DM_ENABLED", "副本助手已开启：进大秘境自动加载。"))
            else
                GearInsightDB.dungeonModule = "off"
                GearInsight:Print(T("DM_DISABLED",
                    "副本助手已永久关闭，之后不再加载、不占内存。想用时点面板上的「大米攻略」按钮即可重新开启。"))
            end
            refreshMaster()
        end)
        mchk:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_TOP")
            GameTooltip:SetText(T("DM_MASTER_TIP",
                "关掉 = 下次登录起本模块完全不加载（零内存、零事件），下面三项也一并停用。\n随时点面板「大米攻略」按钮可临时打开并重新开启。"),
                1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        mchk:SetScript("OnLeave", function() GameTooltip:Hide() end)
        refreshMaster()

        local src = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        src:SetPoint("BOTTOMRIGHT", -14, 8)
        src:SetText(T("DG_SOURCE", "数据: WCL 高层+12层 真实局聚合"))

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -94)
        scroll:SetPoint("BOTTOMRIGHT", -28, 84)   -- 底部多留一行给总开关
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

    -- ④ 嗜血点位（顶尖局在哪开）：lust2 = 按 boss 段位归因（开门波 / 某王前一波 / 某王本体），
    --    同一次嗜血的几个段位并排列出并带占比，共识分裂时老实写「A 55% / B 40%」；
    --    没有 lust2 的老数据退回旧 lust 表。下面再给一行 boss 到达时间（高层局中位）当节奏参照。
    if (d.lust2 and #d.lust2 > 0) or (d.lust and #d.lust > 0) then
        header(T("DG_SEC_LUST", "④ 嗜血点位（顶尖局在哪开）"))
        if d.lust2 and #d.lust2 > 0 then
            local byOrd, ords = {}, {}
            for _, p in ipairs(d.lust2) do
                local o = p[7] or 0
                if not byOrd[o] then byOrd[o] = {}; ords[#ords + 1] = o end
                byOrd[o][#byOrd[o] + 1] = { kind = p[1], gid = p[2], cn = p[3], en = p[4], pct = p[5], medMin = p[6], ord = o }
            end
            table.sort(ords)
            for _, o in ipairs(ords) do
                local list = byOrd[o]
                table.sort(list, function(a, b) return a.pct > b.pct end)
                local parts = {}
                for _, p in ipairs(list) do
                    local nm = GearInsight.KeyTimelineSegName and GearInsight:KeyTimelineSegName(p) or spellName(0, p.cn, p.en)
                    parts[#parts + 1] = ("%s |cffaaaaaa%d%%|r"):format(nm, p.pct)
                end
                line(("|cff00ccff%s|r %s  |cffaaaaaa%s|r"):format(
                    T("KT_NTH", "第%d次"):format(o), table.concat(parts, " / "),
                    T("DG_LUST_AT", "约%.0f分钟"):format(list[1].medMin)))
            end
        else
            for i, k in ipairs(d.lust) do
                local _, cn, en, isBoss, pct, medMin = k[1], k[2], k[3], k[4], k[5], k[6]
                local bossTag = (isBoss == 1) and ("|cffff8000" .. T("DG_BOSS", "[BOSS]") .. "|r ") or ""
                line(string.format("|cff00ccff%d.|r %s%s  |cffaaaaaa%s|r", i, bossTag,
                    spellName(0, cn, en),
                    string.format(T("DG_LUST_FMT", "%d%%局在此开 · 约%.0f分钟"), pct, medMin)))
            end
        end
        if d.bosses and #d.bosses > 0 then
            local parts = {}
            for _, b in ipairs(d.bosses) do
                parts[#parts + 1] = ("%s |cffaaaaaa%d:%02d|r"):format(spellName(0, b[2], b[3]),
                    math.floor(b[4]), math.floor((b[4] % 1) * 60 + 0.5))
            end
            line(("|cffff8000%s|r %s"):format(T("DG_BOSS_PACE", "顶尖局到达："), table.concat(parts, " → ")))
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
    -- 总开关可能在别处被改过（进本提示条的 [开启]/[不再提示]），每次打开都同步一次
    if self._dgFrame._dgRefreshMaster then self._dgFrame._dgRefreshMaster() end
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._dgFrame) end
    self._dgFrame:Show()
end

-- ── 进本自动弹出 ──────────────────────────────────────────────────────
-- 实例名匹配（中英文都认），不依赖 mapID；M+ 与 M0 难度都触发，每个本每次进入只弹一次。
local _lastShownInstance = nil
-- ⭐ 抽成具名函数：本模块是按需加载的，加载时 PLAYER_ENTERING_WORLD 早就过去了，
--    光注册事件等不到下一次 —— 必须由 loader 在加载完成后补跑一次（见文件末尾的 boot hook）。
local function onZoneChanged()
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
            GearInsight:ShowDungeonGuideImpl(i, true)
            -- GearInsight:Print(T("DG_ZONE_HINT", "已为你打开本图攻略（可在窗口左下角关闭自动弹出）"))--lnui
            return
        end
    end
end

local zf = CreateFrame("Frame")
zf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zf:RegisterEvent("PLAYER_ENTERING_WORLD")
zf:SetScript("OnEvent", onZoneChanged)

-- 按需加载补跑：loader 在 LoadAddOn 成功后会依次调用 _dgBootHooks 里的每一项。
if GearInsight._dgBootHooks then
    GearInsight._dgBootHooks[#GearInsight._dgBootHooks + 1] = onZoneChanged
end
