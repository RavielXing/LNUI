-- 刷本优先级 · 网格版（用户 2026-09-11「刷本优先级按照这个格式，来做整体优化」= KeystoneLoot 的副本行 + 图标条）。
--
-- 版式：每个副本 / 团本 BOSS 一行 —— 左边副本背景图（EJ 的 buttonImage2）或 BOSS 头像 + 名字 + 「缺 N」，
--       右边一排 34px 物品图标：缺的全亮带红角标、已获得去色打绿勾、装等不足橙数字、坯子紫「坯」角标；
--       悬浮看物品 + 状态，点击开手册。
-- ⛔ 这里只画不判断：缺 / 已有 / 装等不足 / 坯子 的结论全部由 GearInsight.lua 的 ShowFarmingGuide 算好塞进 model，
--    本文件不碰 BisData、不碰装备快照 —— 两处判断口径永远同一份。
-- model = { cats = { { cat, label, clr, collapsible, collapsed, totalMissing,
--                       groups = { { key, name, instanceId, encounterId, isRaid, missing,
--                                    items = { { slotId, slotName, itemId, bonusIDs, link, ilvl, state, eqIlvl, isRaid, instanceId, encounterId } } } } } } }
-- state ∈ "missing" | "owned" | "low" | "filler"
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

local ROW_W, ROW_H = 560, 52     -- ROW_W 只是默认；Render 会按实际滚动区宽度重算
local LEFT_W = 200          -- 头像/背景 + 名字 + 缺 N
local ICON, GAP = 34, 4
local PER_LINE = math.floor((ROW_W - LEFT_W - 8) / (ICON + GAP))   -- 9（默认宽）

-- ── 大秘境传送（用户 2026-09-11「放到大秘境最前面当图标，然后也可以点击传送」）──
-- 地下城手册 instanceId → 钥石地图 mapID：按**名字**对（同一客户端两边都是本地化名），⛔别手写 id 表。
-- 传送法术 id 按钥石 mapID 查（本赛季 8 本；来源：暴雪「英雄的道路」传送成就，与 KeystoneLoot data/dungeons.lua 一致）。
-- ⛔ 换季要补这张表；查不到的本只显示图标、不能点。
local TELEPORT = { [249] = 1286831, [250] = 1286828, [399] = 393256, [584] = 1286801,
                   [585] = 1286804, [586] = 1286807, [587] = 1286809, [588] = 1286812 }
local _mapByName
local function keystoneMapFor(instanceId)
    if not (instanceId and C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo and EJ_GetInstanceInfo) then return nil end
    if not _mapByName then
        _mapByName = {}
        local ok, ids = pcall(C_ChallengeMode.GetMapTable)
        for _, id in ipairs(ok and ids or {}) do
            local ok2, nm, _, _, tex = pcall(C_ChallengeMode.GetMapUIInfo, id)
            if ok2 and nm then _mapByName[nm] = { id = id, tex = tex } end
        end
    end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
    local ok, nm = pcall(EJ_GetInstanceInfo, instanceId)
    return ok and nm and _mapByName[nm] or nil
end

local FarmGrid = {}
GearInsight.FarmGrid = FarmGrid
-- ⛔ 前置声明：下面 mkRow / getHdr 的闭包会用到，定义在文件后半；不先声明，闭包抓到的是全局 nil
local openLFG, raidDiff

-- ── 池 ────────────────────────────────────────────────────────────────
local function mkIcon(row)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(ICON, ICON)
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.texture = b.tex          -- 主文件 setItemForIcon 写的是 btn.texture
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2"); b.border:SetSize(ICON * 1.55, ICON * 1.55)
    b.border:SetPoint("CENTER"); b.border:SetTexCoord(0.2, 0.8, 0.2, 0.8); b.border:SetAlpha(0.6)
    b.check = b:CreateTexture(nil, "OVERLAY", nil, 2); b.check:SetSize(16, 16)
    b.check:SetPoint("TOPRIGHT", 3, 3); b.check:SetAtlas("common-icon-checkmark"); b.check:Hide()
    b.badge = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.badge:SetPoint("TOPLEFT", -2, 3)
    b.slot = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.slot:SetPoint("BOTTOM", 0, -1)
    b.slotBg = b:CreateTexture(nil, "OVERLAY", nil, 1); b.slotBg:SetPoint("BOTTOMLEFT", 0, 0); b.slotBg:SetPoint("BOTTOMRIGHT", 0, 0)
    b.slotBg:SetHeight(12); b.slotBg:SetColorTexture(0, 0, 0, 0.6)
    -- 多专精态：右下角最多 3 个专精小图标（谁要这件一眼看清）
    b.specIcons = {}
    for k = 1, 3 do
        local t = b:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetSize(11, 11); t:SetPoint("BOTTOMRIGHT", -1 - (k - 1) * 12, 13)
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92); t:Hide()
        b.specIcons[k] = t
    end
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(s)
        if not s._itemId then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        local link = s.itemLink or s._link
        if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetItemByID(s._itemId) end
        GameTooltip:AddLine(" ")
        if s._status then GameTooltip:AddLine(s._status, 1, 1, 1, true) end
        if s._ilvl and s._ilvl > 0 then GameTooltip:AddLine("|cFFFFFF00" .. T("TT_BIS_ILVL", "BiS 装等: ") .. s._ilvl .. "|r", 1, 1, 1) end
        if s._specs and #s._specs > 0 then
            local parts = {}
            for _, sp in ipairs(s._specs) do
                parts[#parts + 1] = (sp.icon and ("|T" .. sp.icon .. ":14:14:0:0:64:64:5:59:5:59|t ") or "") .. (sp.name or sp.key or "")
            end
            GameTooltip:AddLine("|cFFFFD100" .. T("FG_GRID_SPECS", "需要这件的专精: ") .. "|r" .. table.concat(parts, "  "), 1, 1, 1, true)
        end
        GameTooltip:AddLine("|cFF66CCFF" .. T("FG_GRID_CLICK", "点击打开地下城手册 · Shift+点击 发到聊天") .. "|r", 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        if GearInsight._tryChatLink and GearInsight._tryChatLink(s) then return end
        if s._onClick then s._onClick(s) end
    end)
    return b
end

local function mkRow(sc)
    local r = CreateFrame("Frame", nil, sc)
    r:SetSize(ROW_W, ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, 0.03)
    -- 左侧副本背景图：横向渐隐到 LEFT_W（EJ 的 buttonImage2 是横图，裁掉两头）
    r.art = r:CreateTexture(nil, "BORDER"); r.art:SetPoint("TOPLEFT"); r.art:SetPoint("BOTTOMLEFT"); r.art:SetWidth(LEFT_W)
    r.art:SetTexCoord(0.05, 0.95, 0.15, 0.85); r.art:SetAlpha(0.45)
    r.fade = r:CreateTexture(nil, "BORDER", nil, 1); r.fade:SetPoint("TOPLEFT"); r.fade:SetPoint("BOTTOMLEFT"); r.fade:SetWidth(LEFT_W)
    if r.fade.SetGradient and CreateColor then
        r.fade:SetColorTexture(1, 1, 1, 1)
        r.fade:SetGradient("HORIZONTAL", CreateColor(0.05, 0.05, 0.08, 0.35), CreateColor(0.05, 0.05, 0.08, 1))
    else
        r.fade:SetColorTexture(0.05, 0.05, 0.08, 0.55)
    end
    r.portrait = r:CreateTexture(nil, "ARTWORK"); r.portrait:SetSize(36, 36); r.portrait:SetPoint("LEFT", 10, 0)
    -- 大秘境传送钮：安全按钮，type=spell；⛔战斗中不能改属性（SetAttribute 会被拒），只在非战斗时刷新
    r.tp = CreateFrame("Button", nil, r, "SecureActionButtonTemplate")
    -- ⛔⛔ 安全按钮（传送）是受保护帧，战斗中**含受保护子帧的祖先也不能 Hide** → 主面板进战斗后叉/ESC/拖拽全失灵
    --    （群友 2026-09-12「打开 gi 面板之后进入战斗，再点叉叉关不掉」，0.80.4 加传送钮后出现）。
    --    解法：PLAYER_REGEN_DISABLED 发生在锁定生效之前，那一刻把所有传送钮挪到 UIParent 下的停车帧并藏起来；
    --    出战斗再挪回各自的行。见文件底部 _combatPark。
    FarmGrid._tpButtons = FarmGrid._tpButtons or {}
    FarmGrid._tpButtons[#FarmGrid._tpButtons + 1] = r.tp
    r.tp._row = r
    r.tp:SetSize(34, 34); r.tp:SetPoint("LEFT", 10, 0); r.tp:RegisterForClicks("AnyUp", "AnyDown")
    r.tp.icon = r.tp:CreateTexture(nil, "ARTWORK"); r.tp.icon:SetAllPoints(); r.tp.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.tp.ring = r.tp:CreateTexture(nil, "OVERLAY"); r.tp.ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    r.tp.ring:SetSize(52, 52); r.tp.ring:SetPoint("CENTER"); r.tp.ring:SetTexCoord(0.2, 0.8, 0.2, 0.8); r.tp.ring:SetAlpha(0.5)
    r.tp:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        if b._spell then
            GameTooltip:SetSpellByID(b._spell)
            if not (C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(b._spell)) then
                GameTooltip:AddLine(" "); GameTooltip:AddLine(T("FG_TP_UNKNOWN", "还没学会这个传送（限时通关一次即可解锁）"), 1, 0.3, 0.3, true)
            elseif InCombatLockdown() then
                GameTooltip:AddLine(" "); GameTooltip:AddLine(ERR_NOT_IN_COMBAT or "战斗中不可用", 1, 0.3, 0.3)
            else
                GameTooltip:AddLine(" "); GameTooltip:AddLine("|cFF66CCFF" .. T("FG_TP_TIP", "点击传送到副本门口") .. "|r", 0.4, 0.8, 1)
            end
        else
            GameTooltip:SetText(b._name or "", 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    r.tp:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.tp:Hide()
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal"); r.name:SetPoint("TOPLEFT", 58, -9); r.name:SetWidth(LEFT_W - 64)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.sub:SetPoint("TOPLEFT", 58, -29)
    r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    -- 集合石钮：深色方块 + 金边 + 绿眼（用户 2026-09-12 给的样式）
    r.lfg = CreateFrame("Button", nil, r)
    r.lfg:SetSize(24, 24); r.lfg:SetPoint("LEFT", r.sub, "RIGHT", 8, 0)
    r.lfg.bg = r.lfg:CreateTexture(nil, "BACKGROUND"); r.lfg.bg:SetAllPoints(); r.lfg.bg:SetColorTexture(0.06, 0.06, 0.08, 0.95)
    r.lfg.edges = {}
    for k = 1, 4 do local t = r.lfg:CreateTexture(nil, "BORDER"); t:SetColorTexture(0.85, 0.68, 0.25, 0.9); r.lfg.edges[k] = t end
    r.lfg.edges[1]:SetPoint("TOPLEFT"); r.lfg.edges[1]:SetPoint("TOPRIGHT"); r.lfg.edges[1]:SetHeight(1)
    r.lfg.edges[2]:SetPoint("BOTTOMLEFT"); r.lfg.edges[2]:SetPoint("BOTTOMRIGHT"); r.lfg.edges[2]:SetHeight(1)
    r.lfg.edges[3]:SetPoint("TOPLEFT"); r.lfg.edges[3]:SetPoint("BOTTOMLEFT"); r.lfg.edges[3]:SetWidth(1)
    r.lfg.edges[4]:SetPoint("TOPRIGHT"); r.lfg.edges[4]:SetPoint("BOTTOMRIGHT"); r.lfg.edges[4]:SetWidth(1)
    r.lfg.eye = r.lfg:CreateTexture(nil, "ARTWORK"); r.lfg.eye:SetPoint("CENTER"); r.lfg.eye:SetSize(18, 18)
    r.lfg.eye:SetAtlas("groupfinder-eye-single"); r.lfg.eye:SetVertexColor(0.35, 1, 0.45)
    local hl = r.lfg:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.15)
    r.lfg:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        local diffTxt = (raidDiff() == "mythic") and (PLAYER_DIFFICULTY6 or "史诗") or (PLAYER_DIFFICULTY2 or "英雄")
        GameTooltip:SetText(b._isRaid and (T("FG_LFG_RAID2", "打开集合石，搜这个团本的队伍 · ") .. diffTxt) or T("FG_LFG_MPLUS", "打开集合石，搜这个本的队伍"), 1, 0.82, 0)
        if b._isRaid then GameTooltip:AddLine(T("FG_LFG_DIFF_HINT", "难度在「团本」标题右侧切换"), 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    r.lfg:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.lfg:SetScript("OnClick", function(b)
        local ok, err = pcall(openLFG, b._instId, b._isRaid)
        if not ok and GearInsight.Print then GearInsight:Print(T("FG_LFG_ERR", "[集合石] 出错：") .. tostring(err)) end
    end)
    r.lfg:Hide()
    r.line = r:CreateTexture(nil, "BORDER", nil, 2); r.line:SetPoint("BOTTOMLEFT", 0, 0); r.line:SetPoint("BOTTOMRIGHT", 0, 0); r.line:SetHeight(1)
    r.line:SetColorTexture(1, 1, 1, 0.07)
    r.icons = {}
    return r
end

local function getRow(sc, i)
    sc._fgRows = sc._fgRows or {}
    local r = sc._fgRows[i]
    if not r then r = mkRow(sc); sc._fgRows[i] = r end
    r:Show()
    return r
end
local function getIcon(row, i)
    local b = row.icons[i]
    if not b then b = mkIcon(row); row.icons[i] = b end
    b:Show()
    return b
end
local function getHdr(sc, i)
    sc._fgHdrs = sc._fgHdrs or {}
    local h = sc._fgHdrs[i]
    if not h then
        h = CreateFrame("Button", nil, sc); h:SetSize(ROW_W, 24)
        h.band = h:CreateTexture(nil, "BACKGROUND"); h.band:SetAllPoints(); h.band:SetColorTexture(1, 0.82, 0, 0.07)
        h.accent = h:CreateTexture(nil, "BORDER"); h.accent:SetWidth(3); h.accent:SetPoint("TOPLEFT", 0, -3); h.accent:SetPoint("BOTTOMLEFT", 0, 3)
        h.fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); h.fs:SetPoint("LEFT", 10, 0); h.fs:SetJustifyH("LEFT")
        h.note = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); h.note:SetPoint("LEFT", h.fs, "RIGHT", 10, 0); h.note:SetJustifyH("LEFT")
        h.note:SetPoint("RIGHT", -6, 0); h.note:SetWordWrap(false)
        h:RegisterForClicks("LeftButtonUp")
        -- 团本难度切换（用户 2026-09-12「团本这里可以选择 H 还是 M 吧，有的人打不了 M」）：只影响集合石搜哪一档
        h.diff = CreateFrame("Button", nil, h, "UIPanelButtonTemplate")
        h.diff:SetSize(96, 20); h.diff:SetPoint("RIGHT", -4, 0)
        h.diff:SetScript("OnClick", function(b)
            GearInsightDB = GearInsightDB or {}
            local nv = (raidDiff() == "mythic") and "heroic" or "mythic"
            GearInsightDB.fgRaidDiff = nv
            -- 先把自己的文字改了：重绘失败/被别的路径盖掉，玩家也能看到确实切换了（用户 2026-09-12「点了一次之后点不回来了」）
            b:SetText(T("FG_DIFF_LBL", "集合石: ") .. ((nv == "mythic") and (PLAYER_DIFFICULTY6 or "史诗") or (PLAYER_DIFFICULTY2 or "英雄")))
            if GearInsight.Print then
                GearInsight:Print(T("FG_DIFF_LBL", "集合石: ") .. ((nv == "mythic") and (PLAYER_DIFFICULTY6 or "史诗") or (PLAYER_DIFFICULTY2 or "英雄")))
            end
            -- ⛔ 出错必须看得见：多数玩家关着脚本错误，静默炸就是「点了没反应」（2026-09-12）
            local a = GearInsight._fgArgs
            local host = a and a[4]
            local ok, err
            if host and GearInsight.BuildWishlistPage then
                ok, err = pcall(GearInsight.BuildWishlistPage, GearInsight, host)   -- 页内：整页重建（多专精合并态也对）
            elseif a and GearInsight.ShowFarmingGuide then
                ok, err = pcall(GearInsight.ShowFarmingGuide, GearInsight, a[1], a[2], a[3], true, a[4])
            else
                return
            end
            if not ok and GearInsight.Print then GearInsight:Print(T("FG_REDRAW_ERR", "[刷本助手] 重绘出错：") .. tostring(err)) end
        end)
        h.diff:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("FG_DIFF_TIP", "集合石搜团本时用哪个难度（打不了史诗就选英雄）"), 1, 0.82, 0, 1, true)
            GameTooltip:Show()
        end)
        h.diff:SetScript("OnLeave", function() GameTooltip:Hide() end)
        h.diff:Hide()
        sc._fgHdrs[i] = h
    end
    h:Show()
    return h
end

-- ── 副本图 / BOSS 头像 ────────────────────────────────────────────────
local _instArt = {}
local function instanceArt(instanceId)
    if not instanceId then return nil end
    if _instArt[instanceId] ~= nil then return _instArt[instanceId] or nil end
    local art = false
    if EJ_GetInstanceInfo then
        if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
        local ok, _, _, bgImage, buttonImage1, _, buttonImage2 = pcall(EJ_GetInstanceInfo, instanceId)
        if ok then art = buttonImage2 or buttonImage1 or bgImage or false end
    end
    _instArt[instanceId] = art
    return art or nil
end
local function bossPortrait(tex, encounterId)
    if not (encounterId and EJ_GetCreatureInfo and SetPortraitTextureFromCreatureDisplayID) then return false end
    local ok, _, _, _, displayID = pcall(EJ_GetCreatureInfo, 1, encounterId)
    if ok and displayID then
        pcall(SetPortraitTextureFromCreatureDisplayID, tex, displayID)
        tex:SetTexCoord(0, 1, 0, 1)
        return true
    end
    return false
end

-- ── 一键开集合石（用户 2026-09-12「大秘境的一键打开集合石…团本也可以一键打开，不过默认是H的」）──
-- 走暴雪自己的预创建队伍界面：开 PVEFrame → 搜索面板设分类 → 搜索框填活动全名 → 搜索。
-- 活动全名从 C_LFGList.GetAvailableActivities 里按副本名找；团本优先挑「英雄」那条（没有再退普通/史诗）。
-- ⛔ 战斗中 PVEFrame 打不开（保护），直接提示；⛔别自己造搜索请求，用面板的 DoSearch，和玩家手点完全一样。
local function instanceName(instanceId)
    if not (instanceId and EJ_GetInstanceInfo) then return nil end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
    local ok, nm = pcall(EJ_GetInstanceInfo, instanceId)
    return ok and nm or nil
end
function raidDiff()
    local v = GearInsightDB and GearInsightDB.fgRaidDiff
    if v == "mythic" or v == "heroic" then return v end
    -- 没手动选过：跟「参照难度档」走（史诗档 → 搜史诗；英雄/普通档 → 搜英雄）
    local gt = GearInsight.GetGearTier and GearInsight:GetGearTier() or "mythic"
    return (gt == "mythic") and "mythic" or "heroic"
end
local function pickActivity(catID, instName, wantHeroic)
    if not (C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetActivityInfoTable and instName) then return nil end
    local ok, ids = pcall(C_LFGList.GetAvailableActivities, catID)
    if not (ok and ids) then return nil end
    local heroicWord = (PLAYER_DIFFICULTY2 or "Heroic")
    local mythicWord = (PLAYER_DIFFICULTY6 or "Mythic")
    local best, bestScore
    for _, aid in ipairs(ids) do
        local ok2, info = pcall(C_LFGList.GetActivityInfoTable, aid)
        local full = ok2 and info and (info.fullName or "") or ""
        if full:find(instName, 1, true) then
            local sc = 1
            if wantHeroic then
                -- 团本：按玩家选的难度（英雄 / 史诗）挑活动条目；另一档垫底
                local want = raidDiff()
                local isH, isM = full:find(heroicWord, 1, true), full:find(mythicWord, 1, true)
                if want == "mythic" then sc = isM and 3 or (isH and 1 or 2)
                else sc = isH and 3 or (isM and 1 or 2) end
            else
                -- 大秘境：优先「史诗钥石」那条（名字含 Mythic/史诗），其次普通
                if full:find(mythicWord, 1, true) then sc = 3 else sc = 2 end
            end
            if not best or sc > bestScore then best, bestScore = { id = aid, name = full }, sc end
        end
    end
    return best
end
function openLFG(instanceId, isRaid)
    local function say(m) if GearInsight.Print then GearInsight:Print("|cFF66CCFF[集合石]|r " .. m) end end
    if InCombatLockdown and InCombatLockdown() then say(ERR_NOT_IN_COMBAT or "战斗中不可用"); return end
    local nm = instanceName(instanceId)
    if not nm then say(T("FG_LFG_NONAME", "取不到副本名") .. " (instanceId=" .. tostring(instanceId) .. ")"); return end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_GroupFinder") end
    -- 打开预创建队伍：先走 PVEFrame_ShowFrame；没有就直接 ShowUIPanel(PVEFrame) + 点分类
    local opened = false
    if PVEFrame_ShowFrame then opened = pcall(PVEFrame_ShowFrame, "GroupFinderFrame", "LFGListPVEStub") end
    if not opened and PVEFrame then
        pcall(ShowUIPanel, PVEFrame)
        if GroupFinderFrame and GroupFinderFrame_ShowGroupFrame and LFGListPVEStub then pcall(GroupFinderFrame_ShowGroupFrame, LFGListPVEStub) end
        opened = PVEFrame:IsShown()
    end
    if not opened then say(T("FG_LFG_NOFRAME", "打不开预创建队伍界面（PVEFrame_ShowFrame 缺失）")); return end
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if not panel then say(T("FG_LFG_NOPANEL", "LFGListFrame.SearchPanel 不存在，这版客户端界面结构变了")); return end
    local catID = isRaid and 3 or 2          -- 3 团本 / 2 地下城（暴雪固定分类 id）
    local act = pickActivity(catID, nm, isRaid)
    -- ① 模拟玩家在分类页点「地下城/团本」再点「寻找队伍」→ 进搜索面板（这两步都是普通 UI 函数，不受保护）
    local cs = LFGListFrame.CategorySelection
    local navigated = false
    if cs and LFGListCategorySelection_SelectCategory then
        pcall(LFGListCategorySelection_SelectCategory, cs, catID, 0)
        if LFGListCategorySelectionFindGroupButton_OnClick and cs.FindGroupButton then
            navigated = pcall(LFGListCategorySelectionFindGroupButton_OnClick, cs.FindGroupButton)
        end
    end
    if not navigated then
        local setCat = LFGListSearchPanel_SetCategory or (panel.SetCategory and function(pn, ...) return pn:SetCategory(...) end)
        if setCat then pcall(setCat, panel, catID, 0, 0) end
        if LFGListFrame_SetActivePanel then pcall(LFGListFrame_SetActivePanel, LFGListFrame, panel)
        elseif LFGListFrame.SetActivePanel then pcall(LFGListFrame.SetActivePanel, LFGListFrame, panel) end
    end
    -- ② 搜索框是受保护的（EditBox:SetText 被安全设置拒绝，2026-09-12 实测）：
    --    走暴雪给插件的口子 C_LFGList.SetSearchToActivity(activityID)，它会把活动填进搜索框
    if act and C_LFGList and C_LFGList.SetSearchToActivity then
        local ok, err = pcall(C_LFGList.SetSearchToActivity, act.id)
        if not ok then say(T("FG_LFG_SETACT_ERR", "SetSearchToActivity 失败：") .. tostring(err)) end
    elseif not act then
        say(string.format(T("FG_LFG_NOACT", "没找到「%s」对应的活动，已打开搜索页，请手动输入"), nm))
    end
    -- ③ 搜索。⛔ 面板的 DoSearch 直接拿 panel.categoryID 去调 C_LFGList.Search，分类页那条路有时不给它赋值
    --    → 「bad argument #1」（2026-09-12 实测）。先把面板字段钉死，再搜；还不行就直接调 C_LFGList.Search（新签名，带活动 id 过滤）。
    panel.categoryID = catID
    panel.filters = panel.filters or 0
    panel.preferredFilters = panel.preferredFilters or 0
    local searched = false
    local doSearch = LFGListSearchPanel_DoSearch or (panel.DoSearch and function(pn) return pn:DoSearch() end)
    if doSearch then
        local ok = pcall(doSearch, panel)
        searched = ok
    end
    if not searched and C_LFGList and C_LFGList.Search then
        local lang = C_LFGList.GetLanguageSearchFilter and C_LFGList.GetLanguageSearchFilter() or nil
        local ok, err = pcall(C_LFGList.Search, catID, 0, 0, lang, false, nil, act and { act.id } or nil)
        if not ok then say(T("FG_LFG_SEARCH_ERR", "搜索失败：") .. tostring(err)) else searched = true end
    end
    if not searched then say(T("FG_LFG_NOSEARCH", "搜索没发出去（已切到搜索页并填好副本，手点一下搜索）")) end
end

-- 数据里没带 instanceId 的副本（2026-09-12 纳洛拉克的洞穴：图标/传送/集合石全没了）：按名字去地下城手册当前资料片扫一遍
local _ejByName
local function instanceIdByName(name)
    if not (name and EJ_GetInstanceByIndex and EJ_GetNumTiers and EJ_SelectTier) then return nil end
    if not _ejByName then
        _ejByName = {}
        if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
        local okT, nt = pcall(EJ_GetNumTiers)
        local curTier = (okT and nt) and nt or nil
        local prev = EJ_GetCurrentTier and EJ_GetCurrentTier()
        if curTier then
            pcall(EJ_SelectTier, curTier)
            for _, isRaid in ipairs({ false, true }) do
                local i = 1
                while true do
                    local ok, id, nm = pcall(EJ_GetInstanceByIndex, i, isRaid)
                    if not (ok and id) then break end
                    if nm then _ejByName[nm] = id end
                    i = i + 1
                end
            end
            if prev then pcall(EJ_SelectTier, prev) end
        end
    end
    if _ejByName[name] then return _ejByName[name] end
    -- 「副本名 - BOSS 名」形式：只拿前半段再查
    local head = name:match("^(.-)%s+%-%s+") 
    return head and _ejByName[head] or nil
end
-- ⛔ 暴露给 GearInsight.lua 的 localizedSource：数据里没 instanceId 的条目按英文名回查手册 id
GearInsight.InstanceIdByName = instanceIdByName

local function slotShort(name)
    if not name or name == "" then return "" end
    if _ZH then return name:sub(1, 6) end          -- 两个汉字（UTF-8 各 3 字节）
    return name:sub(1, 4)
end

-- ── 渲染 ───────────────────────────────────────────────────────────────
-- 返回内容高度（正数）。width = 滚动区实际宽度（嵌入主面板时比独立弹窗窄）
function FarmGrid.Render(self, sc, model, cb, width)
    -- cb.setItem(btn, itemId, bonusIDs, link) / cb.openJournal(instId, bossId, itemId, isRaid) / cb.toggleCat(cat)
    local W = math.max(360, math.floor(width or ROW_W))
    PER_LINE = math.max(3, math.floor((W - LEFT_W - 8) / (ICON + GAP)))
    for _, r in ipairs(sc._fgRows or {}) do r:Hide(); for _, b in ipairs(r.icons) do b:Hide() end end
    for _, h in ipairs(sc._fgHdrs or {}) do h:Hide() end
    local ri, hi, y = 0, 0, 0
    for _, c in ipairs(model.cats) do
        hi = hi + 1
        local h = getHdr(sc, hi)
        h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, y); h:SetWidth(W)
        h.accent:SetColorTexture(c.clr[1], c.clr[2], c.clr[3], 0.9)
        h.band:SetColorTexture(c.clr[1], c.clr[2], c.clr[3], 0.07)
        local arrow = c.collapsible and (c.collapsed and "+ " or "- ") or ""
        h.fs:SetText(arrow .. c.label); h.fs:SetTextColor(c.clr[1], c.clr[2], c.clr[3])
        h.note:SetText(c.note or "")
        if c.cat == "raid" then
            h.diff:SetText(T("FG_DIFF_LBL", "集合石: ") .. ((raidDiff() == "mythic") and (PLAYER_DIFFICULTY6 or "史诗") or (PLAYER_DIFFICULTY2 or "英雄")))
            h.diff:Show(); h.note:SetPoint("RIGHT", h.diff, "LEFT", -6, 0)
        else
            h.diff:Hide(); h.note:SetPoint("RIGHT", -6, 0)
        end
        h._cat = c.cat
        h:SetScript("OnClick", c.collapsible and function(b) cb.toggleCat(b._cat) end or nil)
        y = y - 26
        if not c.collapsed then
            for _, g in ipairs(c.groups) do
                ri = ri + 1
                local r = getRow(sc, ri)
                local lines = math.max(1, math.ceil(#g.items / PER_LINE))
                local rh = ROW_H + (lines - 1) * (ICON + GAP)
                r:SetHeight(rh); r:SetWidth(W)
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y)
                r.bg:SetColorTexture(1, 1, 1, (ri % 2 == 0) and 0.035 or 0.015)
                -- 左侧：副本图 / BOSS 头像
                if not g.instanceId then g.instanceId = instanceIdByName(g.name) or instanceIdByName(g.key) end
                local art = instanceArt(g.instanceId)
                if art then r.art:SetTexture(art); r.art:Show(); r.fade:Show() else r.art:Hide(); r.fade:Hide() end
                local hasPortrait = g.isRaid and bossPortrait(r.portrait, g.encounterId)
                -- 大秘境行：钥石图标当头像，能点传送
                r.tp:Hide(); r.tp._spell, r.tp._name = nil, g.name
                local km = (not g.isRaid) and keystoneMapFor(g.instanceId) or nil
                if km then
                    r.tp.icon:SetTexture(km.tex or 134400)
                    local spell = TELEPORT[km.id]
                    if spell and not InCombatLockdown() then
                        r.tp:SetAttribute("type", "spell"); r.tp:SetAttribute("spell", spell)
                        r.tp._spell = spell
                        local known = C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(spell)
                        r.tp.icon:SetDesaturated(not known); r.tp:SetAlpha(known and 1 or 0.6)
                    else
                        r.tp:SetAttribute("type", nil); r.tp.icon:SetDesaturated(false); r.tp:SetAlpha(1)
                    end
                    r.tp:Show(); hasPortrait = true; r.portrait:Hide()
                end
                if hasPortrait then
                    if not km then r.portrait:Show() end
                    r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", 58, -9)
                    r.sub:ClearAllPoints(); r.sub:SetPoint("TOPLEFT", 58, -29)
                else
                    r.portrait:Hide()
                    r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", 10, -9)
                    r.sub:ClearAllPoints(); r.sub:SetPoint("TOPLEFT", 10, -29)
                end
                r.name:SetText(g.name or g.key or "")
                -- 集合石钮：有副本 id 的行才有（套装组没有）
                if g.instanceId and not g.isTierGroup then
                    r.lfg._instId, r.lfg._isRaid = g.instanceId, g.isRaid
                    r.lfg:Show()
                else
                    r.lfg:Hide()
                end
                if g.missing > 0 then
                    r.sub:SetText("|cFFFF6060" .. T("FG_NEED", "缺 ") .. g.missing .. T("FG_PCS", " 件") .. "|r")
                    r.name:SetTextColor(1, 0.95, 0.8)
                else
                    r.sub:SetText("|cFF55E055" .. T("FG_SUB_COMPLETE", "  已齐全"):gsub("^%s+", "") .. "|r")
                    r.name:SetTextColor(0.6, 0.6, 0.6)
                end
                -- 右侧：图标条
                for i, it in ipairs(g.items) do
                    local b = getIcon(r, i)
                    local col = (i - 1) % PER_LINE
                    local line = math.floor((i - 1) / PER_LINE)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", r, "TOPLEFT", LEFT_W + 4 + col * (ICON + GAP), -9 - line * (ICON + GAP))
                    cb.setItem(b, it.itemId, it.bonusIDs, it.link)
                    b._itemId, b._link, b._ilvl = it.itemId, it.link or b.itemLink, it.ilvl
                    b._instId, b._bossId, b._isRaid = it.instanceId, it.encounterId, it.isRaid
                    b._onClick = function(s) cb.openJournal(s._instId, s._bossId, s._itemId, s._isRaid) end
                    local tex = b.itemTexture or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.itemId))
                    if tex then b.tex:SetTexture(tex) end
                    b.slot:SetText(slotShort(it.slotName))
                    b.check:Hide(); b.badge:SetText(""); b.tex:SetDesaturated(false); b:SetAlpha(1)
                    b.border:SetVertexColor(1, 1, 1)
                    b._specs = model.multi and it.specs or nil
                    for k = 1, 3 do
                        local sp = b._specs and b._specs[k]
                        if sp and sp.icon then b.specIcons[k]:SetTexture(sp.icon); b.specIcons[k]:Show() else b.specIcons[k]:Hide() end
                    end
                    if it.state == "owned" then
                        b.tex:SetDesaturated(true); b:SetAlpha(0.55); b.check:Show()
                        b.border:SetVertexColor(0.3, 0.9, 0.3)
                        b._status = "|cFF55E055" .. T("OBTAINED", "  (已获得)"):gsub("^%s+", "") .. "|r"
                    elseif it.state == "low" then
                        b.border:SetVertexColor(1, 0.6, 0.2)
                        b.badge:SetText("|cFFFF9933" .. (it.eqIlvl or 0) .. "|r")
                        b._status = "|cFFFF9933" .. T("ILVL_LOW_PRE", "(装等不足 ") .. (it.eqIlvl or 0) .. "/" .. (it.ilvl or 0) .. ")|r"
                    elseif it.state == "filler" then
                        b.border:SetVertexColor(0.75, 0.4, 1)
                        b.badge:SetText("|cFFB060FF" .. T("FG_GRID_FILLER", "坯") .. "|r")
                        b._status = "|cFFB060FF" .. T("FILLER_TAG", "(坯子·催化)") .. "|r " .. T("FG_GRID_FILLER_TIP", "拿到后催化转换成套装件")
                    else
                        b.border:SetVertexColor(1, 0.35, 0.35)
                        b.badge:SetText("|cFFFF5555" .. T("FG_GRID_MISSING", "缺") .. "|r")
                        b._status = "|cFFFF5555" .. T("MISSING_TAG", "  [缺]"):gsub("^%s+", "") .. "|r"
                    end
                    b._status = (it.slotName or "") .. "  " .. b._status
                end
                y = y - rh - 2
            end
        end
        y = y - 6
    end
    return -y + 8
end

-- ── 战斗停车：传送安全钮进战斗前挪出主面板，面板才能在战斗中关闭 ──────────────
do
    local park = CreateFrame("Frame", "GearInsightSecurePark", UIParent)
    park:Hide()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, e)
        for _, b in ipairs(FarmGrid._tpButtons or {}) do
            if e == "PLAYER_REGEN_DISABLED" then
                b._wasShown = b:IsShown()
                b:Hide(); b:SetParent(park)
            else
                if b._row then b:SetParent(b._row) end
                if b._wasShown then b:Show() end
            end
        end
        -- 出战斗后整页重画一次，锚点/层级归位（页内嵌入时 host 存着）
        if e == "PLAYER_REGEN_ENABLED" and GearInsight._fgHost and GearInsight._fgHost:IsShown() and GearInsight.BuildWishlistPage then
            pcall(GearInsight.BuildWishlistPage, GearInsight, GearInsight._fgHost)
        end
    end)
end
