-- PaperDollBis.lua
-- 角色面板(C键) BiS 侧栏：每个装备槽旁边贴一个该部位 BiS #1 的小图标，
-- 鼠标悬停显示装备 tooltip + 刷取来源(哪个副本/哪个boss/制造/套装转换)，
-- 点击打开该部位的「使用率前5」弹窗(复用 GearInsight:ShowSlotTop5)。
-- 已收集(身上穿的就是BiS)的部位在图标角上打绿勾。
--
-- 数据复用主面板同一来源：live Companion recs 优先，回退 BisData.bisBySlot。
-- 戒指/饰品双槽合并池(#1/#2 分给两个槽)、武器按该专精 meta 主流形态过滤，
-- 与 TooltipHook.lua 一样镜像 GearInsight.lua 的局部逻辑(那边是 local 拿不到)。
--
-- 挂载：CharacterFrame:HookScript("OnShow") — 不开角色面板零开销。
-- 槽按钮优先按全局名(CharacterHeadSlot 等)取，取不到回退遍历
-- PaperDollItemsFrame 子按钮按 GetID() 匹配(防 12.x 改版改名)。

GearInsight = GearInsight or {}

-- ── i18n (additive, zhCN-safe; mirrors TooltipHook.lua) ──────────────────
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

-- ── Config ───────────────────────────────────────────────────────────────
-- 可选锚点：槽位按钮四角(内缩1px)，value = { point, ofsX, ofsY }
local ICON_POINTS = {
    TOPRIGHT    = { "TOPRIGHT",    -1, -1 },
    TOPLEFT     = { "TOPLEFT",      1, -1 },
    BOTTOMRIGHT = { "BOTTOMRIGHT", -1,  1 },
    BOTTOMLEFT  = { "BOTTOMLEFT",   1,  1 },
}
GearInsight._paperDollBisPoints = ICON_POINTS   -- expose for settings menu

local function cfg()
    GearInsightDB = GearInsightDB or {}
    local c = GearInsightDB.paperDollBis
    if not c then c = {}; GearInsightDB.paperDollBis = c end
    if c.enabled == nil then c.enabled = true end
    -- 大小/位置可配置(玩家反馈：右上角会挡住其它插件的装等数字)
    if not c.iconSize or c.iconSize < 10 or c.iconSize > 30 then c.iconSize = 16 end
    if not ICON_POINTS[c.iconPos or ""] then c.iconPos = "TOPRIGHT" end
    return c
end
GearInsight._paperDollBisCfg = cfg   -- expose for slash handler

-- ── Slot button resolution ───────────────────────────────────────────────
local SLOT_BUTTON_NAMES = {
    [1]  = "CharacterHeadSlot",   [2]  = "CharacterNeckSlot",
    [3]  = "CharacterShoulderSlot", [15] = "CharacterBackSlot",
    [5]  = "CharacterChestSlot",  [9]  = "CharacterWristSlot",
    [10] = "CharacterHandsSlot",  [6]  = "CharacterWaistSlot",
    [7]  = "CharacterLegsSlot",   [8]  = "CharacterFeetSlot",
    [11] = "CharacterFinger0Slot", [12] = "CharacterFinger1Slot",
    [13] = "CharacterTrinket0Slot", [14] = "CharacterTrinket1Slot",
    [16] = "CharacterMainHandSlot", [17] = "CharacterSecondaryHandSlot",
}
local _btnCache = {}
local function slotButton(slotId)
    local b = _btnCache[slotId]
    if b then return b end
    b = _G[SLOT_BUTTON_NAMES[slotId]]
    if not b then
        -- 12.x 改版兜底：遍历 PaperDollItemsFrame(或 CharacterFrame)子按钮按 GetID 匹配
        local parent = _G["PaperDollItemsFrame"] or _G["PaperDollFrame"] or _G["CharacterFrame"]
        if parent then
            local kids = { parent:GetChildren() }
            for _, k in ipairs(kids) do
                if k.GetID and k:GetID() == slotId and k.GetObjectType
                    and k:GetObjectType() == "Button" then
                    b = k; break
                end
            end
        end
    end
    _btnCache[slotId] = b
    return b
end

-- 图标叠在槽位按钮角落(玩家反馈：放格子旁边会挡住其它信息)。
-- 大小/角落从配置读，每次 refresh 重应用，菜单改完即时生效。
local function applyLayout(ic, btn)
    local c = cfg()
    local p = ICON_POINTS[c.iconPos] or ICON_POINTS.TOPRIGHT
    ic:ClearAllPoints()
    ic:SetPoint(p[1], btn, p[1], p[2], p[3])
    ic:SetSize(c.iconSize, c.iconSize)
    ic._check:SetSize(c.iconSize * 0.75, c.iconSize * 0.75)
end

-- ── BiS pool helpers (mirror GearInsight.lua locals / TooltipHook.mergePool) ──
local PAIR_SLOT = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }
local WCONF_HASOFF = { ["2h"] = false, ranged = false, titansGrip = true,
    dualWield = true, ["1hShield"] = true, ["1hOff"] = true }
local WCONF_MAINHAND = { ["2h"] = "2h", titansGrip = "2h", ranged = "ranged",
    dualWield = "1h", ["1hShield"] = "1h", ["1hOff"] = "1h" }
local WCONF_OFFHAND = { titansGrip = "2h", dualWield = "offWeapon",
    ["1hShield"] = "shield", ["1hOff"] = "frill" }

local function mergePool(a, b)
    local byId, order = {}, {}
    local function add(list)
        if type(list) ~= "table" then return end
        for _, e in ipairs(list) do
            local prev = byId[e.itemId]
            if not prev then
                byId[e.itemId] = e
                order[#order + 1] = e
            elseif (e.usagePct or 0) > (prev.usagePct or 0) then
                byId[e.itemId] = e
                for i, o in ipairs(order) do
                    if o.itemId == e.itemId then order[i] = e break end
                end
            end
        end
    end
    add(a); add(b)
    table.sort(order, function(x, y) return (x.usagePct or 0) > (y.usagePct or 0) end)
    return order
end

local function filterByHand(cand, wantHand, altHand)
    if not cand or not wantHand then return cand end
    local out = {}
    for _, e in ipairs(cand) do
        local h = e.handedness
        if (not h) or h == wantHand or (altHand and h == altHand) then out[#out + 1] = e end
    end
    return out
end

-- ── Enchant / gem display helpers (per-slot tooltip extras) ────────────────
local function itemIconTex(id, px)
    if not id then return "" end
    local t = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    if t and t ~= 0 then px = px or 14; return "|T" .. t .. ":" .. px .. ":" .. px .. "|t " end
    return ""
end

-- 附魔图标：优先配方物品图标，回退烤制的图标名
local function enchIconTex(e)
    if not e then return "" end
    if e.item then local t = itemIconTex(e.item); if t ~= "" then return t end end
    if e.icon and e.icon ~= "" then return "|TInterface\\Icons\\" .. e.icon .. ":14:14|t " end
    return ""
end

-- 附魔名：zhCN 用烤制中文名；其它语言用配方物品的本地化名(真实附魔名)，回退中文名/占位
local function enchName(e)
    if not e then return "" end
    if _LOCALE == "zhCN" and e.nameCn and e.nameCn ~= "" then return e.nameCn end
    if e.item then
        local n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.item))
            or (GetItemInfo and GetItemInfo(e.item))
        if n and n ~= "" then return n end
    end
    if e.nameCn and e.nameCn ~= "" then return e.nameCn end
    return T("PDB_ENCH_SEE_GUIDE", "(见攻略)")
end

local function gemName(g)
    if not g then return "" end
    if _LOCALE == "zhCN" and g.nameCn and g.nameCn ~= "" then return g.nameCn end
    if g.id then
        local n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(g.id))
            or (GetItemInfo and GetItemInfo(g.id))
        if n and n ~= "" then return n end
    end
    return g.nameCn or "?"
end

-- 身上该槽位是否有插槽：空槽看 GetItemStats 的 EMPTY_SOCKET_*，已镶嵌看物品链接的宝石位。
-- 只有真有插槽才在该槽提示宝石，避免每个槽位重复刷屏。
local function equippedHasSocket(slotId)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
    if not link then return false end
    if C_Item and C_Item.GetItemStats then
        local st = C_Item.GetItemStats(link)
        if st then
            for k, v in pairs(st) do
                if type(k) == "string" and k:find("EMPTY_SOCKET") and (v or 0) > 0 then return true end
            end
        end
    end
    local itemStr = link:match("|Hitem:([%-%d:]+)|h")
    if itemStr then
        -- item:id:enchant:gem1:gem2:gem3:gem4:...  → 跳过 id，看 gem1..gem4
        local _ench, g1, g2, g3, g4 = select(2, strsplit(":", itemStr))
        local function nz(x) local n = tonumber(x); return n and n ~= 0 end
        if nz(g1) or nz(g2) or nz(g3) or nz(g4) then return true end
    end
    return false
end

-- ── Spec data ────────────────────────────────────────────────────────────
local function getSpecBisBySlot()
    local gi = GearInsight
    local snap = gi.SavedVars and gi.SavedVars.GetLastSnapshot and gi.SavedVars:GetLastSnapshot()
    local class, spec, htal
    if snap then class, spec, htal = snap.class, snap.spec, snap.heroTalent end
    if (not class or not spec) and gi.StatReader then
        local s = gi.StatReader:ReadAll()
        class, spec, htal = s.class, s.spec, s.heroTalent
    end
    local bd = gi.BisData
    local data = bd and bd.GetSpecData and bd:GetSpecData(class, spec, htal)
    -- live Companion recs 优先(和主面板一致)
    local bySlot
    if gi.RecsReader and gi.RecsReader.HasFreshRecs and gi.RecsReader:HasFreshRecs() then
        bySlot = gi.RecsReader:GetBisBySlot()
    end
    if not bySlot then bySlot = data and data.bisBySlot end
    return bySlot, data
end

-- 该专精当前场景的 meta 主流武器形态(主面板同款回退：实戴形态读不到就取 meta 最高占比)
local function metaWeaponConfig(data)
    local bd = GearInsight.BisData
    local wTbl = bd and bd.weaponConfig
    local wKey = data and data.className and data.specName
        and (data.className .. "/" .. data.specName)
    local scen = (GearInsightDB and GearInsightDB.usageMode == "mplus") and "mplusHigh" or "raid"
    local wMeta = wTbl and wKey and wTbl[wKey] and (wTbl[wKey][scen] or wTbl[wKey].raid)
    if not wMeta then return nil end
    local best, bestP = nil, -1
    for c, p in pairs(wMeta) do if p > bestP then best, bestP = c, p end end
    return best
end

-- 每槽推荐：返回 entry(展示哪件), cands(点击弹前5用), collected(已穿BiS)
local function pickForSlot(slotId, bySlot, wConf, recBySlot)
    local pairOther = PAIR_SLOT[slotId]
    local eqId = GetInventoryItemID("player", slotId)

    if pairOther then
        -- 戒指/饰品：双槽合并池，第一槽给#1、第二槽给#2；身上任一槽穿了池前2都算收集
        local pool = mergePool(bySlot[slotId], bySlot[pairOther])
        if #pool == 0 then return nil end
        local p1, p2 = pool[1], pool[2]
        local eqOther = GetInventoryItemID("player", pairOther)
        local recOther = recBySlot and recBySlot[pairOther]   -- 兄弟槽这次已选的件(先处理的槽先记)
        -- 唯一装备不能穿两个：兄弟槽已穿 or 已推荐的件，本槽一律排除
        local function ok(e) return e and e.itemId ~= eqOther and e.itemId ~= recOther end
        if eqId and p1 and eqId == p1.itemId then return p1, pool, true end
        if eqId and p2 and eqId == p2.itemId then return p2, pool, true end
        local first = (slotId == 11 or slotId == 13)
        local a, b = p1, p2
        if not first then a, b = p2, p1 end
        if ok(a) then return a, pool, false end
        if ok(b) then return b, pool, false end
        -- a/b 都与兄弟槽冲突：池内顺延首个不冲突的(硬保证两槽不同件)
        for _, e in ipairs(pool) do
            if ok(e) then return e, pool, false end
        end
        return a or b, pool, false
    end

    if slotId == 16 or slotId == 17 then
        local cand = bySlot[slotId]
        if wConf then
            if slotId == 17 and not WCONF_HASOFF[wConf] then return nil end
            if slotId == 16 then
                cand = filterByHand(cand, WCONF_MAINHAND[wConf])
            else
                local want = WCONF_OFFHAND[wConf]
                cand = filterByHand(cand, want, want == "offWeapon" and "1h" or nil)
            end
        end
        if not cand or #cand == 0 then return nil end
        return cand[1], cand, (eqId ~= nil and eqId == cand[1].itemId)
    end

    local cand = bySlot[slotId]
    if not cand or #cand == 0 then return nil end
    return cand[1], cand, (eqId ~= nil and eqId == cand[1].itemId)
end

-- ── Icon widgets ─────────────────────────────────────────────────────────
local icons = {}     -- slotId -> Button

local function ensureIcon(slotId)
    local ic = icons[slotId]
    if ic then return ic end
    local btn = slotButton(slotId)
    if not btn then return nil end
    ic = CreateFrame("Button", nil, btn)
    ic._btn = btn   -- refresh 重应用布局用
    ic:SetFrameLevel(btn:GetFrameLevel() + 5)   -- 压在槽位图标之上
    ic._tex = ic:CreateTexture(nil, "ARTWORK")
    ic._tex:SetAllPoints()
    ic._tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- 裁掉默认图标黑边
    ic._border = ic:CreateTexture(nil, "OVERLAY")
    ic._border:SetPoint("TOPLEFT", -1, 1); ic._border:SetPoint("BOTTOMRIGHT", 1, -1)
    ic._border:SetColorTexture(0, 0, 0, 0.9)
    ic._border:SetDrawLayer("BACKGROUND", -1)
    ic._check = ic:CreateTexture(nil, "OVERLAY")
    ic._check:SetPoint("CENTER")   -- 已收集时图标隐藏只剩绿勾，居中显示
    ic._check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    ic._check:Hide()
    applyLayout(ic, btn)
    ic:SetScript("OnEnter", function(s)
        local e = s._entry
        if not e then return end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        -- 裸 itemId 的 tooltip 显示基础装等(制造件=44)：带上 bonusIDs 构造完整
        -- 链接才是真实装等(主面板 setItemForIcon 同款 MurlokExport 链接格式)
        if e.bonusIDs and #e.bonusIDs > 0 then
            local bonusPart = #e.bonusIDs .. ":" .. table.concat(e.bonusIDs, ":")
            GameTooltip:SetHyperlink("|Hitem:" .. e.itemId .. ":0::::::::0:::" .. bonusPart .. "|h")
        else
            GameTooltip:SetItemByID(e.itemId)
        end
        GameTooltip:AddLine(" ")
        if s._collected then
            -- ✓ 字符在 zhCN 字体无字形显示为方块，用材质转义(0.34 同款修法)
            GameTooltip:AddLine("|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t "
                .. T("PDB_COLLECTED", "已收集 — 这就是该部位 BiS"), 0.2, 0.9, 0.2)
        end
        GameTooltip:AddLine(T("PDB_SOURCE", "刷取：") .. (e.source or "?"), 0.4, 0.75, 1, true)
        if e.usagePct then
            GameTooltip:AddLine(string.format(T("PDB_USAGE", "顶尖玩家使用率 %.0f%%"), e.usagePct), 0.7, 0.7, 0.7)
        end
        -- 本部位最火附魔(逐槽精确：数据按 slotId 区分)
        local ench = s._slotEnch
        if ench and ench[1] then
            local top = ench[1]
            GameTooltip:AddLine(T("PDB_BEST_ENCH", "本部位最火附魔：") .. enchIconTex(top) .. enchName(top)
                .. string.format("  |cFF8CD98C%.0f%%|r", top.usagePct or 0), 1, 1, 1)
            local alt = ench[2]
            if alt and (alt.usagePct or 0) >= 15 then
                GameTooltip:AddLine("    |cFF888888/ " .. enchIconTex(alt) .. enchName(alt)
                    .. string.format(" %.0f%%|r", alt.usagePct or 0), 0.6, 0.6, 0.6)
            end
        end
        -- 最火宝石(专精级；仅在该槽位确实有插槽时提示)
        local gems = s._gems
        if gems and gems[1] and equippedHasSocket(slotId) then
            local segs = {}
            for i = 1, math.min(#gems, 3) do
                local g = gems[i]
                segs[#segs + 1] = itemIconTex(g.id) .. gemName(g)
                    .. string.format(" |cFF8CD98C%.0f%%|r", g.usagePct or 0)
            end
            GameTooltip:AddLine(T("PDB_BEST_GEM", "最火宝石：") .. table.concat(segs, "   "), 1, 1, 1, true)
        end
        GameTooltip:AddLine(T("PDB_CLICK", "点击查看本部位使用率前5"), 0.55, 0.55, 0.55)
        GameTooltip:Show()
    end)
    ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ic:SetScript("OnClick", function(s)
        if s._cands and #s._cands > 0 and GearInsight.ShowSlotTop5 then
            GearInsight:ShowSlotTop5(s._slotLabel, slotId, s._cands)
        end
    end)
    icons[slotId] = ic
    return ic
end

local function hideAll()
    for _, ic in pairs(icons) do ic:Hide() end
end

-- ── Refresh ──────────────────────────────────────────────────────────────
local function refresh()
    if not cfg().enabled then hideAll(); return end
    if not (CharacterFrame and CharacterFrame:IsShown()) then return end
    local bySlot, data = getSpecBisBySlot()
    if not bySlot then hideAll(); return end
    local wConf = metaWeaponConfig(data)
    local L = GearInsight.L or {}
    local gr = GearInsight.GearReader

    local recBySlot = {}   -- 本次刷新各槽已选 itemId(配对槽去重用，11/13 先于 12/14 处理)
    for slotId = 1, 17 do
        if slotId ~= 4 then
            local entry, cands, collected = pickForSlot(slotId, bySlot, wConf, recBySlot)
            if entry then recBySlot[slotId] = entry.itemId end
            local ic = entry and ensureIcon(slotId)
            if ic and entry then
                applyLayout(ic, ic._btn)   -- 大小/位置配置可能刚改过
                local tex = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.itemId)
                    or (GetItemIcon and GetItemIcon(entry.itemId))
                ic._tex:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
                -- 图标可能未缓存：请求加载后由 OnShow 周期下一次 refresh 补上
                if not tex and C_Item and C_Item.RequestLoadItemDataByID then
                    C_Item.RequestLoadItemDataByID(entry.itemId)
                end
                -- 已收集：16px 下褪色图标看不清，直接只留绿勾(悬停/点击仍可用)
                ic._tex:SetShown(not collected)
                ic._border:SetShown(not collected)
                ic._check:SetShown(collected and true or false)
                ic._entry = entry
                ic._cands = cands
                ic._collected = collected
                local slotKey = gr and gr.GetSlotKey and gr:GetSlotKey(slotId)
                ic._slotLabel = (slotKey and L[slotKey]) or ("SLOT" .. slotId)
                -- 最火附魔/宝石数据：附魔逐槽(enchants[slotId])，宝石专精级(全槽共用)
                ic._slotEnch = data and data.enchants and data.enchants[slotId]
                ic._gems = data and data.gems
                ic:Show()
            elseif icons[slotId] then
                icons[slotId]:Hide()
            end
        end
    end
end
GearInsight.RefreshPaperDollBis = refresh   -- expose for slash toggle

-- ── Wiring ───────────────────────────────────────────────────────────────
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if CharacterFrame then
            CharacterFrame:HookScript("OnShow", function()
                -- 等一帧：OnShow 时槽按钮布局/装备信息可能还没就绪
                C_Timer.After(0, refresh)
            end)
            ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
            ev:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
        end
    else
        -- 装备/专精变化：面板开着才刷
        if CharacterFrame and CharacterFrame:IsShown() then refresh() end
    end
end)
