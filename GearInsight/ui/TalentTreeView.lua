-- 天赋树预览（用户 2026-09-11「像网页版本一样，把天赋预览图形页面做出来」「你好好设计下」）。
--
-- 网页版（static/js/wow_talent_view.js）是解码导入串 + DB2 全树节点画 SVG；插件里不用带任何数据：
-- 客户端自己就有整棵树（C_Traits），串的位流顺序就是 C_Traits.GetTreeNodes(treeID) 的顺序
-- （core/TalentExport.lua 的导出端正是按这个顺序写的，这里按同样顺序读回来）。
--
-- 比网页多做的一件事：**和你身上现在点的对比** —— 要补点的节点画绿框、要退掉的画红框，
-- 这是只有在游戏里才做得到的（网页看不到你的角色）。
--
-- ⛔ 三个坑（网页版栽过，见记忆 gearinsight-talent-view-popup）：
--   · 骨架必须是 GetTreeNodes 的**全树**顺序（含别的专精才可见的节点），不能只拿可见节点；
--   · 英雄树选择节点（Enum.TraitNodeType.SubTreeSelection）本身不画，它的选择决定画哪棵英雄树；
--   · 职业树 / 专精树 / 英雄树各自归一化坐标、各画一个面板，⛔别混在一张画布上。
-- 位流（序列化版本 2，与暴雪 Blizzard_ClassTalentImportExport 一致）：
--   版本 8 位 · specID 16 位 · 树哈希 128 位 · 逐节点：selected(1) → purchased(1) → partial(1) → [ranks 6] → choice(1) → [idx 2]
--   base64 每字符 6 位、低位在前。
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

-- ── 解码 ────────────────────────────────────────────────────────────────
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64IDX = {}
for i = 1, #B64 do B64IDX[B64:sub(i, i)] = i - 1 end

local function newStream(str)
    local vals = {}
    for i = 1, #str do
        local v = B64IDX[str:sub(i, i)]
        if v == nil then return nil end
        vals[#vals + 1] = v
    end
    local pos = 0
    local function extract(bits)
        local value = 0
        for i = 0, bits - 1 do
            local ci = math.floor(pos / 6) + 1
            local v = vals[ci]
            if v == nil then return nil end
            local bit = math.floor(v / (2 ^ (pos % 6))) % 2
            value = value + bit * (2 ^ i)
            pos = pos + 1
        end
        return value
    end
    return { extract = extract, bitsLeft = function() return #vals * 6 - pos end }
end

-- 返回 { specID=, nodes = { [nodeID] = { selected=true, purchased=bool, ranks=n|nil, choice=idx|nil } }, treeID=, configID= }
-- 或 nil, 原因
local function decode(str)
    if not (C_Traits and C_ClassTalents and C_ClassTalents.GetActiveConfigID) then return nil, T("TV_NO_API", "天赋 API 不可用") end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil, T("TV_NO_CFG", "取不到激活天赋配置（切到该专精了吗？）") end
    local cfg = C_Traits.GetConfigInfo(configID)
    local treeID = cfg and cfg.treeIDs and cfg.treeIDs[1]
    if not treeID then return nil, T("TV_NO_TREE", "找不到天赋树") end
    str = (str or ""):gsub("%s+", "")
    local st = newStream(str)
    if not st then return nil, T("TV_BAD_STR", "导入串里有非法字符") end
    local version = st.extract(8)
    local specID = st.extract(16)
    for _ = 1, 16 do st.extract(8) end          -- 树哈希：不校验（版本小改哈希就变，串照样能导）
    if not version or not specID then return nil, T("TV_BAD_STR", "导入串里有非法字符") end
    local out = { specID = specID, version = version, nodes = {}, treeID = treeID, configID = configID }
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local sel = st.extract(1)
        if sel == nil then return nil, T("TV_SHORT", "导入串太短，和这棵树对不上（版本不同？）") end
        if sel == 1 then
            local n = { selected = true, purchased = true }
            if version >= 2 then n.purchased = (st.extract(1) == 1) end
            if n.purchased then
                if st.extract(1) == 1 then n.ranks = st.extract(6) end
                if st.extract(1) == 1 then n.choice = st.extract(2) end
            end
            out.nodes[nodeID] = n
        end
    end
    return out
end
GearInsight.DecodeTalentString = decode

-- ── 树的静态结构（按 configID 缓存一次，切专精重算）────────────────────────
local function currencyKinds(configID, treeID)
    -- 暴雪天赋面板同款：GetTreeCurrencyInfo 第 1 个是职业点、第 2 个是专精点
    local ok, cur = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
    local classCur, specCur
    if ok and cur then
        classCur = cur[1] and cur[1].traitCurrencyID
        specCur = cur[2] and cur[2].traitCurrencyID
    end
    return classCur, specCur
end

local function nodeGroup(configID, nodeID, info, classCur, specCur)
    if info.subTreeID and info.subTreeID > 0 then return "hero" end
    local ok, costs = pcall(C_Traits.GetNodeCost, configID, nodeID)
    if ok and costs then
        for _, c in ipairs(costs) do
            if c.ID == specCur then return "spec" end
            if c.ID == classCur then return "class" end
        end
    end
    return nil
end

local function entryIcon(configID, entryID)
    local ok, e = pcall(C_Traits.GetEntryInfo, configID, entryID)
    if not (ok and e) then return nil end
    local ok2, d = pcall(C_Traits.GetDefinitionInfo, e.definitionID)
    if ok2 and d then
        if d.overrideIcon then return d.overrideIcon, d.spellID end
        if d.spellID and C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(d.spellID), d.spellID end
    end
    return nil
end

-- ── 面板绘制 ────────────────────────────────────────────────────────────
local PAD, NODE = 16, 32
local PANEL_H = 480
local W_SIDE, W_HERO, GAP = 352, 214, 10
local FRAME_W = 12 + W_SIDE + GAP + W_HERO + GAP + W_SIDE + 12
local FRAME_H = 62 + PANEL_H + 46

local function mkPanel(parent, w, titleText)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, PANEL_H)
    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.025)
    local band = p:CreateTexture(nil, "BORDER"); band:SetPoint("TOPLEFT"); band:SetPoint("TOPRIGHT"); band:SetHeight(24)
    band:SetColorTexture(1, 0.82, 0, 0.08)
    local ln = p:CreateTexture(nil, "BORDER"); ln:SetPoint("TOPLEFT", 0, -24); ln:SetPoint("TOPRIGHT", 0, -24); ln:SetHeight(1)
    ln:SetColorTexture(1, 0.82, 0, 0.35)
    for _, side in ipairs({ { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", false } }) do
        local t = p:CreateTexture(nil, "BORDER"); t:SetPoint(side[1]); t:SetPoint(side[2])
        if side[3] then t:SetWidth(1) else t:SetHeight(1) end
        t:SetColorTexture(1, 1, 1, 0.08)
    end
    local hd = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hd:SetPoint("TOP", 0, -5); hd:SetText(titleText)
    p.title = hd
    p.nodes, p.lines = {}, {}
    p.canvas = CreateFrame("Frame", nil, p)
    p.canvas:SetPoint("TOPLEFT", PAD, -34); p.canvas:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    return p
end

local function getNodeBtn(p, i)
    local b = p.nodes[i]
    if b then b:Show(); return b end
    b = CreateFrame("Button", nil, p.canvas)
    b:SetSize(NODE, NODE)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.iconB = b:CreateTexture(nil, "ARTWORK"); b.iconB:SetPoint("TOPRIGHT"); b.iconB:SetPoint("BOTTOMRIGHT"); b.iconB:SetWidth(NODE / 2)
    b.iconB:SetTexCoord(0.5, 0.93, 0.07, 0.93); b.iconB:Hide()
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetPoint("TOPLEFT", -2, 2); b.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    b.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); b.ring:SetBlendMode("ADD")
    b.ring:SetPoint("TOPLEFT", -9, 9); b.ring:SetPoint("BOTTOMRIGHT", 9, -9); b.ring:SetVertexColor(1, 0.82, 0, 0)
    -- 四条 1px 边线当边框（与装备图同款，不吃 ElvUI 换肤）
    b.edges = {}
    for k = 1, 4 do local t = b:CreateTexture(nil, "OVERLAY"); t:SetColorTexture(0, 0, 0, 0); b.edges[k] = t end
    b.edges[1]:SetPoint("TOPLEFT", -2, 2); b.edges[1]:SetPoint("TOPRIGHT", 2, 2); b.edges[1]:SetHeight(2)
    b.edges[2]:SetPoint("BOTTOMLEFT", -2, -2); b.edges[2]:SetPoint("BOTTOMRIGHT", 2, -2); b.edges[2]:SetHeight(2)
    b.edges[3]:SetPoint("TOPLEFT", -2, 2); b.edges[3]:SetPoint("BOTTOMLEFT", -2, -2); b.edges[3]:SetWidth(2)
    b.edges[4]:SetPoint("TOPRIGHT", 2, 2); b.edges[4]:SetPoint("BOTTOMRIGHT", 2, -2); b.edges[4]:SetWidth(2)
    b.rank = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.rank:SetPoint("BOTTOMRIGHT", 2, -3); b.rank:SetJustifyH("RIGHT")
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        local shown = false
        if s._entryID and GameTooltip.SetTraitEntry then
            local ok = pcall(GameTooltip.SetTraitEntry, GameTooltip, s._entryID, s._rankForTip or 1)
            shown = ok
        end
        if not shown and s._spellID and GameTooltip.SetSpellByID then
            pcall(GameTooltip.SetSpellByID, GameTooltip, s._spellID); shown = true
        end
        if not shown then GameTooltip:SetText(s._name or "?", 1, 0.82, 0) end
        if s._diffText then GameTooltip:AddLine(s._diffText, 1, 1, 1, true) end
        if s._altText then GameTooltip:AddLine(s._altText, 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.nodes[i] = b
    return b
end
local function setEdge(b, r, g, bl, a)
    for _, t in ipairs(b.edges) do t:SetColorTexture(r, g, bl, a or 1) end
end
local function getLine(p, i)
    local l = p.lines[i]
    if l then l:Show(); return l end
    l = p.canvas:CreateLine(nil, "BACKGROUND")
    l:SetThickness(2)
    p.lines[i] = l
    return l
end

-- 一个面板：nodes = { {id=, info=, x=, y=} }（x/y 为原始坐标），build = decode 出来的表，cur = 当前配置
-- diffOn = 是否与身上对比
local function drawPanel(p, list, build, configID, diffOn)
    for _, b in ipairs(p.nodes) do b:Hide() end
    for _, l in ipairs(p.lines) do l:Hide() end
    if #list == 0 then p.title:SetText(p._baseTitle .. "  |cFF888888—|r"); return 0 end
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for _, n in ipairs(list) do
        if n.x < minX then minX = n.x end; if n.x > maxX then maxX = n.x end
        if n.y < minY then minY = n.y end; if n.y > maxY then maxY = n.y end
    end
    local cw, ch = p.canvas:GetWidth() - NODE, p.canvas:GetHeight() - NODE
    local sx = (maxX > minX) and (cw / (maxX - minX)) or 0
    local sy = (maxY > minY) and (ch / (maxY - minY)) or 0
    -- 横纵各自铺满面板（树是网格，非等比只是把行列拉开；英雄树 3×5 用等比缩放会挤成一团，2026-09-11 截图）
    if sx == 0 then sx = 1 end
    if sy == 0 then sy = 1 end
    local usedW, usedH = (maxX - minX) * sx, (maxY - minY) * sy
    local offX, offY = (cw - usedW) / 2, (ch - usedH) / 2
    local byId = {}
    local points = 0
    for i, n in ipairs(list) do
        local b = getNodeBtn(p, i)
        local px = offX + (n.x - minX) * sx
        local py = offY + (n.y - minY) * sy
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", p.canvas, "TOPLEFT", px, -py)
        byId[n.id] = b
        local info = n.info
        local bn = build.nodes[n.id]
        local isChoice = info.type == (Enum.TraitNodeType and Enum.TraitNodeType.Selection or 2)
        local entryIDs = info.entryIDs or {}
        local chosenEntry
        if bn then
            if isChoice then chosenEntry = entryIDs[(bn.choice or 0) + 1] or entryIDs[1]
            else chosenEntry = entryIDs[1] end
        else
            chosenEntry = entryIDs[1]
        end
        local icA, spA = entryIcon(configID, chosenEntry)
        b.icon:SetTexture(icA or 134400)
        b.iconB:Hide(); b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        if isChoice and not bn and entryIDs[2] then
            -- 没选的二选一：左右各半
            b.icon:SetTexCoord(0.07, 0.5, 0.07, 0.93)
            b.icon:ClearAllPoints(); b.icon:SetPoint("TOPLEFT"); b.icon:SetPoint("BOTTOMLEFT"); b.icon:SetWidth(NODE / 2)
            local icB = entryIcon(configID, entryIDs[2])
            b.iconB:SetTexture(icB or 134400); b.iconB:Show()
        else
            b.icon:ClearAllPoints(); b.icon:SetAllPoints()
        end
        b._entryID = chosenEntry; b._spellID = spA
        b._name = nil; b._altText = nil; b._diffText = nil
        local maxR = info.maxRanks or 1
        local rank = 0
        if bn then rank = bn.purchased and (bn.ranks or maxR) or maxR end
        b._rankForTip = math.max(1, rank)
        if bn then
            b.icon:SetDesaturated(false); b.iconB:SetDesaturated(false); b:SetAlpha(1)
            if bn.purchased then points = points + rank end
            setEdge(b, 1, 0.82, 0, 1); b.ring:SetVertexColor(1, 0.82, 0, 0.35)
            if not bn.purchased then setEdge(b, 0.6, 0.6, 0.6, 1); b.ring:SetVertexColor(1, 1, 1, 0.12) end     -- 系统赠送
        else
            b.icon:SetDesaturated(true); b.iconB:SetDesaturated(true); b:SetAlpha(0.28)
            setEdge(b, 0, 0, 0, 0); b.ring:SetVertexColor(0, 0, 0, 0)
        end
        if maxR > 1 and bn then b.rank:SetText(string.format("%d/%d", rank, maxR)) else b.rank:SetText("") end
        -- 与身上对比：绿 = 这套有、你没点（要补）；红 = 你点了、这套没有（要退）；黄 = 二选一选的不同 / 点数不同
        if diffOn then
            local curSel = (info.activeRank or 0) > 0
            local curPurch = (info.ranksPurchased or 0) > 0
            local curEntry = info.activeEntry and info.activeEntry.entryID
            local buildPurch = bn and bn.purchased
            if buildPurch and not curPurch then
                setEdge(b, 0.2, 1, 0.2, 1); b._diffText = "|cFF40FF40" .. T("TV_DIFF_ADD", "这套点了，你没点 → 要补") .. "|r"
            elseif curPurch and not buildPurch then
                b:SetAlpha(0.7); b.icon:SetDesaturated(false)
                setEdge(b, 1, 0.25, 0.25, 1); b._diffText = "|cFFFF5555" .. T("TV_DIFF_REMOVE", "你点了，这套没点 → 要退") .. "|r"
            elseif buildPurch and curPurch then
                local diffChoice = isChoice and curEntry and chosenEntry and curEntry ~= chosenEntry
                local diffRank = (maxR > 1) and rank ~= (info.ranksPurchased or 0)
                if diffChoice then
                    setEdge(b, 1, 0.8, 0.2, 1); b._diffText = "|cFFFFCC33" .. T("TV_DIFF_CHOICE", "二选一选的不一样 → 换成这个") .. "|r"
                elseif diffRank then
                    setEdge(b, 1, 0.8, 0.2, 1); b._diffText = "|cFFFFCC33" .. string.format(T("TV_DIFF_RANK", "点数不同：你 %d / 这套 %d"), info.ranksPurchased or 0, rank) .. "|r"
                end
            end
            if curSel and not curPurch and bn then
                -- 你这边是系统赠送（点亮但没花点）、这套也选了 → 不算差异，恢复灰框
                b._diffText = nil; setEdge(b, 0.6, 0.6, 0.6, 1)
            end
        end
    end
    -- 连线：visibleEdges（只画目标也在本面板里的）；两端都点了的线亮，否则暗
    local li = 0
    for _, n in ipairs(list) do
        local from = byId[n.id]
        for _, e in ipairs(n.info.visibleEdges or {}) do
            local to = byId[e.targetNode]
            if from and to then
                li = li + 1
                local l = getLine(p, li)
                l:SetStartPoint("CENTER", from); l:SetEndPoint("CENTER", to)
                local on = build.nodes[n.id] and build.nodes[e.targetNode]
                if on then l:SetColorTexture(1, 0.82, 0, 0.55) else l:SetColorTexture(1, 1, 1, 0.08) end
            end
        end
    end
    return points
end

-- ── 主窗口 ──────────────────────────────────────────────────────────────
local function ensureFrame()
    if GearInsight._treeFrame then return GearInsight._treeFrame end
    local f = CreateFrame("Frame", "GearInsightTalentTree", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(60)
    f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
                    insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.95)
    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.08, 0.97)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    if GearInsight.RegisterEscClose then GearInsight:RegisterEscClose(f, "GearInsightTalentTree") end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 16, -14)
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.sub:SetJustifyH("LEFT"); f.sub:SetWidth(FRAME_W - 260)
    local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton"); cb:SetPoint("TOPRIGHT", -4, -4)
    cb:SetScript("OnClick", function() f:Hide() end)
    -- 三个面板
    f.pClass = mkPanel(f, W_SIDE, T("TV_CLASS", "职业天赋")); f.pClass:SetPoint("TOPLEFT", 12, -62)
    f.pHero = mkPanel(f, W_HERO, T("TV_HERO", "英雄天赋")); f.pHero:SetPoint("LEFT", f.pClass, "RIGHT", GAP, 0)
    f.pSpec = mkPanel(f, W_SIDE, T("TV_SPEC", "专精天赋")); f.pSpec:SetPoint("LEFT", f.pHero, "RIGHT", GAP, 0)
    f.pClass._baseTitle, f.pHero._baseTitle, f.pSpec._baseTitle = f.pClass.title:GetText(), f.pHero.title:GetText(), f.pSpec.title:GetText()
    -- 底部：图例 + 对比开关 + 一键导入 + 复制
    f.legend = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.legend:SetPoint("BOTTOMLEFT", 16, 14); f.legend:SetJustifyH("LEFT"); f.legend:SetWidth(FRAME_W - 470)
    f.legend:SetWordWrap(true); f.legend:SetMaxLines(2)
    f.legend:SetText(T("TV_LEGEND", "金框 = 这套点了 · 灰框 = 系统赠送 · 暗 = 没点   |cFF40FF40绿框|r 要补  |cFFFF5555红框|r 要退  |cFFFFCC33黄框|r 选法/点数不同"))
    local diff = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    diff:SetSize(22, 22); diff:SetPoint("BOTTOMRIGHT", -410, 12)
    diff.text:SetText(T("TV_DIFF_TOGGLE", "与我身上对比")); diff:SetChecked(true)
    diff:SetScript("OnClick", function() if f._str then GearInsight:ShowTalentTree(f._str, f._title, f._name, true) end end)
    f.diff = diff
    local imp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    imp:SetSize(130, 22); imp:SetPoint("BOTTOMRIGHT", -160, 12); imp:SetText(T("TALENT_IMPORT_BTN", "一键导入天赋"))
    imp:SetScript("OnClick", function()
        if not f._str then return end
        local ok, msg = GearInsight_TryImportTalents(f._str, f._name, function(okA, msgA)
            if okA then GearInsight:Print(string.format(T("TALENT_APPLY_DONE", "天赋已应用：%s"), msgA or "?"))
            else GearInsight:Print(T("TALENT_APPLY_FAIL", "天赋未自动应用：") .. (msgA or "?")) end
        end)
        if ok then
            GearInsight:Print(string.format(T("TALENT_IMPORT_OK2", "已导入「%s」，正在自动应用…"), msg or "?"))
            if GearInsight.RefreshClearLoadoutsButton then C_Timer.After(0.5, function() GearInsight:RefreshClearLoadoutsButton() end) end
        else
            GearInsight:Print(T("TALENT_IMPORT_FAIL", "导入失败：") .. (msg or "?"))
        end
    end)
    f.imp = imp
    local cp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cp:SetSize(120, 22); cp:SetPoint("BOTTOMRIGHT", -24, 12); cp:SetText(T("TV_COPY", "复制导入串"))
    cp:SetScript("OnClick", function()
        if f._str then GearInsight:ShowCopyText(f._str, T("TALENT_COPY_HINT", "Ctrl+C 复制 → 天赋面板「导入」粘贴"), f._title, f._name) end
    end)
    f.msg = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.msg:SetPoint("CENTER", 0, 0); f.msg:SetWidth(FRAME_W - 80)
    GearInsight._treeFrame = f
    return f
end

-- 对外：str = 导入串；title/name = 标题与载入档名（与 ShowCopyText 同参数）；reopen = 内部刷新
function GearInsight:ShowTalentTree(str, title, name, reopen)
    local f = ensureFrame()
    if f:IsShown() and f._str == str and not reopen then f:Hide(); return end
    f._str, f._title, f._name = str, title, name
    f.title:SetText(title or T("TV_TITLE", "天赋树预览"))
    f.msg:SetText("")
    local build, err = decode(str)
    local mySpec = GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
    if build and mySpec and build.specID ~= mySpec then
        build, err = nil, string.format(T("TV_WRONG_SPEC", "这套是别的专精的（specID %d，你现在是 %d）—— 切到那个专精再看"), build.specID, mySpec)
    end
    if not build then
        for _, p in ipairs({ f.pClass, f.pHero, f.pSpec }) do
            for _, b in ipairs(p.nodes) do b:Hide() end
            for _, l in ipairs(p.lines) do l:Hide() end
            p.title:SetText(p._baseTitle)
        end
        f.sub:SetText(""); f.msg:SetText("|cFFFF6060" .. (err or "?") .. "|r")
        f:Show(); return
    end
    local configID, treeID = build.configID, build.treeID
    local classCur, specCur = currencyKinds(configID, treeID)
    local lists = { class = {}, spec = {}, hero = {} }
    local subTreeSel, heroSubTree = nil, nil
    local SUBSEL = Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection or 3
    local allInfos = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local ok, info = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok and info then
            allInfos[nodeID] = info
            if info.type == SUBSEL then
                subTreeSel = nodeID
                local bn = build.nodes[nodeID]
                local entry = bn and info.entryIDs and info.entryIDs[(bn.choice or 0) + 1]
                if entry then
                    local ok2, e = pcall(C_Traits.GetEntryInfo, configID, entry)
                    if ok2 and e and e.subTreeID then heroSubTree = e.subTreeID end
                end
            end
        end
    end
    -- 串里没选英雄树 → 用你当前的
    if not heroSubTree and subTreeSel then
        local info = allInfos[subTreeSel]
        local e = info and info.activeEntry and info.activeEntry.entryID
        if e then local ok2, ei = pcall(C_Traits.GetEntryInfo, configID, e); if ok2 and ei then heroSubTree = ei.subTreeID end end
    end
    local pointsPossible = { class = 0, spec = 0, hero = 0 }
    for nodeID, info in pairs(allInfos) do
        -- ⛔ 坐标为 (0,0) 的是没布局的节点（别的专精/隐藏节点），混进来会把 min 拉到原点、真节点全挤到一角
        --    （抖音用户 2026-09-12「天赋树图标挤一坨」，噬灭）。不可见的也不画。
        local placed = info.posX and info.posY and not (info.posX == 0 and info.posY == 0)
        if info.type ~= SUBSEL and placed and info.isVisible ~= false then
            local g = nodeGroup(configID, nodeID, info, classCur, specCur)
            if g == "hero" then
                if info.subTreeID == heroSubTree then lists.hero[#lists.hero + 1] = { id = nodeID, info = info, x = info.posX, y = info.posY } end
            elseif g then
                lists[g][#lists[g] + 1] = { id = nodeID, info = info, x = info.posX, y = info.posY }
            elseif not g then
                -- 没查到花费的节点（兜底，正常不走）：按横坐标归到离得近的那棵树，⛔别一股脑塞进职业树
                lists._orphan = lists._orphan or {}
                lists._orphan[#lists._orphan + 1] = { id = nodeID, info = info, x = info.posX, y = info.posY }
            end
        end
    end
    -- 孤儿节点按横坐标归边：离职业树中心近的进职业树，否则进专精树
    if lists._orphan and #lists._orphan > 0 then
        local function cx(list) local sx, n = 0, 0 for _, e in ipairs(list) do sx = sx + e.x; n = n + 1 end return n > 0 and sx / n or nil end
        local cc, sc2 = cx(lists.class), cx(lists.spec)
        if not (cc and sc2) then
            -- 两棵树都没认出来（货币判断整体失效，噬灭这类新专精可能如此）：
            -- 暴雪布局里职业树在左、专精树在右，中间有一条大空隙 → 按横坐标最大间隙一刀切成两半
            table.sort(lists._orphan, function(a, b) return a.x < b.x end)
            local cutAt, bestGap = nil, 0
            for i = 2, #lists._orphan do
                local gap = lists._orphan[i].x - lists._orphan[i - 1].x
                if gap > bestGap then bestGap, cutAt = gap, i end
            end
            if cutAt and #lists._orphan >= 10 then
                for i, e in ipairs(lists._orphan) do
                    local dst = (i < cutAt) and lists.class or lists.spec
                    dst[#dst + 1] = e
                end
                lists._orphan = nil
            end
        end
        -- 两棵树都已认出（各 ≥5 个）→ 认不出货币的只能是「别的专精」的节点（噬灭截图 2026-09-12：
        -- 恶魔猎手三专精共树，浩劫/复仇的专精节点也报 isVisible，花费是它们自己的专精币，
        -- 老代码把它们全塞进职业面板，横坐标被拉到专精树那边，真节点压成左侧一条）→ 一律丢掉不画
        if cc and sc2 and #lists.class >= 5 and #lists.spec >= 5 then
            lists._orphanDropped = #(lists._orphan or {})
            lists._orphan = nil
        end
        for _, e in ipairs(lists._orphan or {}) do
            if cc and sc2 then
                if math.abs(e.x - cc) <= math.abs(e.x - sc2) then lists.class[#lists.class + 1] = e else lists.spec[#lists.spec + 1] = e end
            else
                lists.class[#lists.class + 1] = e
            end
        end
        lists._orphan = nil
    end
    for _, k in ipairs({ "class", "spec", "hero" }) do
        table.sort(lists[k], function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
    end
    -- 诊断留痕（/gi tree debug）：每棵树节点数 + 坐标包围盒，远程排「挤一坨」用
    do
        local dbg = {}
        for _, k in ipairs({ "class", "spec", "hero" }) do
            local l = lists[k]
            local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
            for _, e in ipairs(l) do
                if e.x < x0 then x0 = e.x end; if e.x > x1 then x1 = e.x end
                if e.y < y0 then y0 = e.y end; if e.y > y1 then y1 = e.y end
            end
            dbg[#dbg + 1] = string.format("%s=%d [x %d..%d, y %d..%d]", k, #l, (#l > 0) and x0 or 0, (#l > 0) and x1 or 0, (#l > 0) and y0 or 0, (#l > 0) and y1 or 0)
        end
        GearInsight._tvDebug = string.format("tree=%s cfg=%s classCur=%s specCur=%s hero=%s dropped=%s | %s",
            tostring(treeID), tostring(configID), tostring(classCur), tostring(specCur), tostring(heroSubTree), tostring(lists._orphanDropped or 0), table.concat(dbg, " ; "))
    end
    local diffOn = f.diff:GetChecked()
    local pc = drawPanel(f.pClass, lists.class, build, configID, diffOn)
    local ph = drawPanel(f.pHero, lists.hero, build, configID, diffOn)
    local ps = drawPanel(f.pSpec, lists.spec, build, configID, diffOn)
    f.pClass.title:SetText(f.pClass._baseTitle .. "  |cFFFFD100" .. pc .. "|r")
    f.pSpec.title:SetText(f.pSpec._baseTitle .. "  |cFFFFD100" .. ps .. "|r")
    local heroName = ""
    if heroSubTree and C_Traits.GetSubTreeInfo then
        local ok, st = pcall(C_Traits.GetSubTreeInfo, configID, heroSubTree)
        if ok and st and st.name then heroName = st.name end
    end
    f.pHero.title:SetText((heroName ~= "" and heroName or f.pHero._baseTitle) .. "  |cFFFFD100" .. ph .. "|r")
    -- 副标题：专精名 + 差异汇总
    local _, specName, _, specIcon = GetSpecializationInfo(GetSpecialization() or 0)
    if specIcon then specName = "|T" .. specIcon .. ":16:16:0:0:64:64:4:60:4:60|t " .. (specName or "") end
    local nAdd, nRem, nChg = 0, 0, 0
    if diffOn then
        for _, p in ipairs({ f.pClass, f.pHero, f.pSpec }) do
            for _, b in ipairs(p.nodes) do
                if b:IsShown() and b._diffText then
                    if b._diffText:find("40FF40") then nAdd = nAdd + 1
                    elseif b._diffText:find("FF5555") then nRem = nRem + 1
                    else nChg = nChg + 1 end
                end
            end
        end
        if nAdd + nRem + nChg == 0 then
            f.sub:SetText((specName or "") .. "  |cFF40FF40" .. T("TV_SAME", "和你身上完全一样") .. "|r")
        else
            f.sub:SetText((specName or "") .. "  " .. string.format(T("TV_DIFF_SUM", "与你身上：|cFF40FF40补 %d|r · |cFFFF5555退 %d|r · |cFFFFCC33改 %d|r"), nAdd, nRem, nChg))
        end
    else
        f.sub:SetText(specName or "")
    end
    if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
    f:Show()
end

-- /gi tree：看自己当前这套（同时也是解码的自检：应显示「和你身上完全一样」）
function GearInsight:ShowMyTalentTree()
    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    local str = configID and C_Traits.GenerateImportString and C_Traits.GenerateImportString(configID)
    if not str or str == "" then self:Print(T("TV_NO_CFG", "取不到激活天赋配置（切到该专精了吗？）")); return end
    self:ShowTalentTree(str, T("TV_MINE", "我当前的天赋"), nil)
end
