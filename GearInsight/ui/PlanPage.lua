-- ui/PlanPage.lua —— 「我的 BiS」方案页（2026-09-23 P1）
--
-- 设计稿：clawhub docs/gearinsight-custom-bis-planner-design.md §3 / §5 / §6 / §11
-- 数据与编解码在 core/BisPlan.lua；本文件只画界面。
--   左：16 格方案（两列）· 点格子 = 候选菜单，右键 = 升级轨道，选中后 Shift+点物品链接 / 拖物品进来 = 放进这一格
--   右：属性配比（身上 → 方案）+ 能不能穿上的检查
--   下：从数据生成 / 从身上生成 / 导入 / 导出 / 清空
-- ⛔ 新模块，测完用户点头前在 gi_pack_release.py 的 HOLD 里。
-- ⛔ 视觉（用户 09-23「注意设计和大气美感」）：深底金边、格子留白、品质色描边、轨道色标，不堆文字。

GearInsight = GearInsight or {}
local BP = GearInsight.BisPlan
local T = (BP and BP.T) or function(_, zh) return zh end

local GOLD = { 1, 0.82, 0 }
local CARD_W, CARD_H, GAP = 240, 62, 4   -- 三行稳定排版：名称 / 数据口径 / 来源与扩展
local LEFT_SLOTS = { 1, 2, 3, 15, 5, 9, 16, 17 }
local RIGHT_SLOTS = { 10, 6, 7, 8, 11, 12, 13, 14 }
local SLOT_NAME = {
    [1] = { "BP_S1", "头部" }, [2] = { "BP_S2", "项链" }, [3] = { "BP_S3", "肩部" }, [15] = { "BP_S15", "披风" },
    [5] = { "BP_S5", "胸部" }, [9] = { "BP_S9", "护腕" }, [10] = { "BP_S10", "手套" }, [6] = { "BP_S6", "腰带" },
    [7] = { "BP_S7", "腿部" }, [8] = { "BP_S8", "脚部" }, [11] = { "BP_S11", "戒指 1" }, [12] = { "BP_S12", "戒指 2" },
    [13] = { "BP_S13", "饰品 1" }, [14] = { "BP_S14", "饰品 2" }, [16] = { "BP_S16", "主手" }, [17] = { "BP_S17", "副手" },
}
local TRACK_LABEL = {
    m = { "BP_TR_M", "神话" }, h = { "BP_TR_H", "英雄" }, c = { "BP_TR_C", "勇士" }, v = { "BP_TR_V", "老兵" }, x = { "BP_TR_X", "数据档" },
}
local TRACK_COLOR = {
    m = { 1, 0.50, 0.10 }, h = { 0.70, 0.35, 1 }, c = { 0.25, 0.60, 1 }, v = { 0.30, 0.95, 0.30 }, x = { 0.55, 0.58, 0.65 },
}
local PLAN_LABEL = { raid = { "BP_P_RAID", "团本" }, mplus = { "BP_P_MPLUS", "大米" }, custom = { "BP_P_CUSTOM", "自定义" } }
local STAT_ROWS = {
    { "crit", "STAT_CRIT", "暴击" }, { "haste", "STAT_HASTE", "急速" },
    { "mastery", "STAT_MASTERY", "精通" }, { "versatility", "STAT_VERS", "全能" },
}
-- 装备部位 → 能放的槽
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16, 17 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 },
}
local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }
local TIER_SLOT = { [1] = true, [3] = true, [5] = true, [7] = true, [10] = true }

local function L2(pair) return T(pair[1], pair[2]) end

local state = { editId = nil, selected = nil }

-- ── 小工具 ───────────────────────────────────────────────────────────
local function specInfo()
    local sd = BP and BP.PlayerSpecData()
    local key2 = sd and BP.KeyOfSpecData(sd)
    return sd, key2
end

local function qualityColor(id, link)
    -- 与悬停使用同一个物品变体；裸 ID 的基础品质可能是绿色。
    local q
    if link and C_Item and C_Item.GetItemInfo then
        q = select(3, C_Item.GetItemInfo(link))
    elseif id and C_Item and C_Item.GetItemQualityByID then
        q = C_Item.GetItemQualityByID(id)
    end
    if q and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        if r then return r, g, b end
    end
    return 0.75, 0.75, 0.75
end

local function itemName(id, entry)
    local nm = id and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if nm and nm ~= "" then return nm end
    if entry and entry.itemName and entry.itemName ~= "" then return entry.itemName end
    if id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return "…"
end

local function itemIcon(id)
    return (id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400
end

local function equipLoc(id)
    if not (id and C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, loc = C_Item.GetItemInfoInstant(id)
    return loc
end

local function curPlan(key2)
    return key2 and state.editId and BP.Get(key2, state.editId) or nil
end

-- 数据推荐（不含方案）每槽 #1 / 成对槽前两件 —— 与 BP.FromData 同一口径
local function dataPicks(sd)
    local m = {}
    for _, s in ipairs(BP.FromData(sd)) do m[s.slot] = s.id end
    return m
end

-- 随机属性件（BisData.randStatItems，数据端 apply_random_stats.py 标记）：属性按本专精目标占比最高两项算（同值 crit<haste<mastery<vers），
--   与数据端 / 网站同一规则。返回「急速 / 暴击」这样的文字；不是随机属性件返回 nil。
local STAT_CN = { crit = { "STAT_CRIT", "暴击" }, haste = { "STAT_HASTE", "急速" }, mastery = { "STAT_MASTERY", "精通" }, versatility = { "STAT_VERS", "全能" } }
local STAT_ORDER = { "crit", "haste", "mastery", "versatility" }
local function randIdeal(sd, id)
    local bd = GearInsight.BisData
    if not (id and bd and bd.randStatItems and bd.randStatItems[id]) then return nil end
    local pct = (GearInsight.FillerStatPct and GearInsight.FillerStatPct(sd)) or (sd and sd.targetStatPercents) or {}
    local list = {}
    for i, k in ipairs(STAT_ORDER) do list[#list + 1] = { k = k, v = tonumber(pct[k]) or 0, i = i } end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.i < b.i end)
    return L2(STAT_CN[list[1].k]) .. " / " .. L2(STAT_CN[list[2].k])
end

-- 这件装备在数据池里的 bonusID（当前池没带就去团本原始池 / 大秘境池找）。
-- ⛔ 没有 bonusID 只能 SetItemByID —— 那是**基础装等**（09-25 用户截图：阿曼尼督军的指环「物品等级 48」）
local function bonusFor(sd, id)
    if not (sd and id) then return nil end
    local _ = sd.bisBySlot
    local pools = { sd.bisBySlot or {}, rawget(sd, "_rawBisBySlot") or {} }
    local key = rawget(sd, "_key")
    local mp = key and GearInsight.BisData and GearInsight.BisData.mplusBySlot and GearInsight.BisData.mplusBySlot[key]
    if mp then pools[#pools + 1] = mp end
    for _, pool in ipairs(pools) do
        for _, list in pairs(pool) do
            for _, e in ipairs(list) do
                if e.itemId == id and e.bonusIDs and #e.bonusIDs > 0 then return e.bonusIDs end
            end
        end
    end
    return nil
end

-- ── 卡片 ─────────────────────────────────────────────────────────────
local function makeCard(parent)
    local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
    c:SetSize(CARD_W, CARD_H)
    c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    c:SetBackdropColor(0.06, 0.065, 0.09, 0.96)
    c:SetBackdropBorderColor(0.18, 0.18, 0.22, 1)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetSize(44, 44); c.icon:SetPoint("LEFT", 6, 0)
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.iconEdge = c:CreateTexture(nil, "BORDER"); c.iconEdge:SetPoint("TOPLEFT", c.icon, -1, 1); c.iconEdge:SetPoint("BOTTOMRIGHT", c.icon, 1, -1)
    c.iconEdge:SetColorTexture(0.4, 0.4, 0.4, 1)

    c.slot = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c.slot:SetPoint("TOPRIGHT", -7, -5)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 1)
    c.name:SetWidth(140); c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false); c.name:SetMaxLines(1)

    c.badge = CreateFrame("Frame", nil, c, "BackdropTemplate"); c.badge:SetSize(58, 15)
    c.badge:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    c.badge:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    c.badge.txt = c.badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.badge.txt:SetPoint("CENTER", 0, 0)

    c.src = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c.src:SetPoint("LEFT", c.badge, "RIGHT", 6, 0)
    c.src:SetJustifyH("LEFT"); c.src:SetWordWrap(false); c.src:SetMaxLines(1)

    c.tag = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); c.tag:SetWidth(42); c.tag:SetPoint("BOTTOMRIGHT", -7, 5); c.tag:SetJustifyH("RIGHT"); c.tag:SetMaxLines(1)
    -- 第三行：附魔 / 宝石 / 美化（小图标 + 名字；自动的灰色）
    c.ext = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.ext:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 8, -1)
    c.ext:SetPoint("RIGHT", c.tag, "LEFT", -6, 0); c.ext:SetJustifyH("LEFT"); c.ext:SetWordWrap(false); c.ext:SetMaxLines(1)
    -- 来源行只伸到右下角标签（自选 / 同数据 / 数据推荐）左边，别压在标签上（09-25 截图「坯子：备用的代言人兜帽」和「同数据」重叠）
    c.src:ClearAllPoints(); c.src:SetPoint("LEFT", c.badge, "RIGHT", 6, 0); c.src:SetPoint("RIGHT", c.tag, "LEFT", -6, 0)

    c.hl = c:CreateTexture(nil, "HIGHLIGHT"); c.hl:SetAllPoints(); c.hl:SetColorTexture(1, 0.82, 0, 0.06)
    return c
end

-- ── 候选菜单 / 轨道菜单 ─────────────────────────────────────────────
local function candidatesFor(sd, slot)
    local pool = rawget(sd, "_dataBySlot") or sd.bisBySlot or {}
    local list = pool[slot] or {}
    if PAIR[slot] and GearInsight.MergePairPool then list = GearInsight.MergePairPool(pool[slot], pool[PAIR[slot]]) end
    local out = {}
    for _, e in ipairs(list) do
        if not e.planned then out[#out + 1] = e end
        if #out >= 10 then break end
    end
    return out
end

local function setSlot(key2, slot, itemId, track, extra)
    local plan = curPlan(key2)
    local keep = plan and BP.SlotMap(plan)[slot]
    BP.SetSlot(key2, state.editId, slot, itemId, track or (keep and keep.track) or "x", extra)
end

-- 这一格的套装件本体：方案里已放的若是套装件就用它，否则从数据池里找 isTier 那条
local function tierPieceFor(sd, key2, slot)
    local plan = curPlan(key2)
    local ps = plan and BP.SlotMap(plan)[slot]
    local e = ps and BP.FindEntry(sd, ps.id)
    if ps and ((e and e.isTier) or (tonumber(ps.cf) or 0) > 0) then return ps.id end
    for _, pool in ipairs({ rawget(sd, "_dataBySlot") or {}, sd.bisBySlot or {} }) do
        for _, c in ipairs(pool[slot] or {}) do
            if c.isTier or c.sourceCategory == "tier" then return c.itemId end
        end
    end
    return nil
end

-- 右键菜单（附魔 / 宝石 / 美化 / 轨道 / 制造属性）在下面定义；左键菜单也要能跳过去，先占个名
local openSlotMenu
-- MenuUtil 的按钮描述也支持 SetTooltip。候选/BiS 坯子不能只有文字：悬停必须能看原生装备信息。
local function tipCandidate(desc, itemId, bonusIDs, usagePct)
    if not (desc and desc.SetTooltip and itemId) then return end
    desc:SetTooltip(function(tt)
        local link
        if bonusIDs and #bonusIDs > 0 and GearInsight.LinkMid then
            link = "item:" .. itemId .. GearInsight.LinkMid() .. #bonusIDs .. ":" .. table.concat(bonusIDs, ":")
        end
        if link and tt.SetHyperlink then tt:SetHyperlink(link)
        elseif tt.SetItemByID then tt:SetItemByID(itemId) end
        if usagePct then tt:AddLine(string.format(T("BP_TIP_USAGE", "顶尖玩家使用率 %.0f%%"), usagePct), 0.6, 0.63, 0.67) end
    end)
end
local function openCandidateMenu(owner, sd, key2, slot)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L2(SLOT_NAME[slot]) .. " · " .. T("BP_MENU_TITLE", "顶尖玩家实穿（使用率）"))
        for i, e in ipairs(candidatesFor(sd, slot)) do
            local r, g, b = qualityColor(e.itemId)
            local txt = string.format("|cff%02x%02x%02x%s|r  |cff9aa0aa%.0f%%%s|r", r * 255, g * 255, b * 255,
                itemName(e.itemId, e), e.usagePct or 0, (e.source and e.source ~= "") and (" · " .. e.source) or "")
            local row = root:CreateButton(i .. ". " .. txt, function() setSlot(key2, slot, e.itemId, "x", { b = e.bonusIDs }) end)
            tipCandidate(row, e.itemId, e.bonusIDs, e.usagePct)
        end
        -- 坯子（GIB1 cf 键，三端互通）：排名与悬浮「转换优先级 #i/n」同一把尺子 BuildFillerList
        local tierId = TIER_SLOT[slot] and tierPieceFor(sd, key2, slot)
        if tierId and GearInsight.BuildFillerList then
            local _, cls = UnitClass("player")
            local armor = GearInsight.BisData and GearInsight.BisData.classArmor and GearInsight.BisData.classArmor[cls]
            local ok, fl = pcall(GearInsight.BuildFillerList, armor, slot, nil, sd, nil, true)
            if ok and fl and #fl > 0 then
                local plan = curPlan(key2)
                local ps = plan and BP.SlotMap(plan)[slot]
                local curCf = ps and tonumber(ps.cf) or nil
                root:CreateDivider()
                root:CreateTitle(string.format(T("BP_FILLER_TITLE", "坯子 · 催化成「%s」"), itemName(tierId)))
                local shown = 0
                for i, f in ipairs(fl) do
                    if f.itemId and not f.isTier then
                        shown = shown + 1
                        if shown > 6 then break end
                        local r, g, b = qualityColor(f.itemId)
                        local where = f.nameCn or f.bossName or ""
                        local label = string.format("%s%d. |cff%02x%02x%02x%s|r  |cff9aa0aa%s|r", (curCf == f.itemId) and "|cffffd100●|r " or "",
                            i, r * 255, g * 255, b * 255, itemName(f.itemId), where)
                        local row = root:CreateButton(label, function() BP.SetFiller(key2, state.editId, slot, tierId, f.itemId) end)
                        tipCandidate(row, f.itemId, f.bonusIDs, f.usagePct)
                    end
                end
                if curCf then
                    root:CreateButton("|cff9aa0aa" .. T("BP_FILLER_CLEAR", "不指定坯子（按排名自动）") .. "|r",
                        function() BP.SetFiller(key2, state.editId, slot, tierId, nil) end)
                end
            end
        end
        -- 用户 2026-09-25「这里怎么选附魔？」：左键菜单里找不到附魔入口 → 加一条直达右键那套
        root:CreateDivider()
        root:CreateButton("|cff9ee7ff" .. T("BP_MENU_EXTRAS", "附魔 / 宝石 / 美化 / 制造属性…（右键这一格也能开）") .. "|r", function()
            C_Timer.After(0, function() openSlotMenu(owner, sd, key2, slot) end)
        end)
        root:CreateDivider()
        local equipped, equippedLink = BP.EquippedSlot(slot)
        if equipped then
            local level = equippedLink and C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(equippedLink)
            local label = T("BP_MENU_EQUIPPED_ACTUAL", "使用当前穿戴：") .. itemName(equipped.id)
            if level then label = label .. " · " .. string.format(T("BP_MENU_EQUIPPED_ILVL", "装等 %d"), level) end
            root:CreateButton(label, function()
                local current = BP.EquippedSlot(slot)
                if not current then return end
                setSlot(key2, slot, current.id, "x", { b = current.b })
            end)
        end
        root:CreateButton("|cff9aa0aa" .. T("BP_MENU_CLEAR", "清空此格（回到数据推荐）") .. "|r", function() setSlot(key2, slot, nil) end)
        root:CreateDivider()
        root:CreateTitle("|cff9aa0aa" .. T("BP_MENU_HINT", "也可以：选中这格后 Shift+点击任意物品链接，或把物品拖到格子上") .. "|r")
    end)
end

-- 这一格实际是哪件：方案里放的，没放就是数据推荐那件
local function slotItem(key2, sd, slot)
    local plan = curPlan(key2)
    local ps = plan and BP.SlotMap(plan)[slot]
    if ps then return ps.id, ps end
    return dataPicks(sd)[slot], nil
end
-- 整套方案每格实际的件（附魔 / 宝石 auto 展开要按件判断能不能附魔、有没有孔）
local function planItems(key2, sd)
    local plan = curPlan(key2)
    local map = plan and BP.SlotMap(plan) or {}
    local picks = dataPicks(sd)
    local items = {}
    for _, sl in ipairs(BP.SLOTS) do
        local id = (map[sl] and map[sl].id) or picks[sl]
        if id then items[sl] = id end
    end
    local mh = items[16]
    if mh and BP.KeyOfSpecData(sd) ~= "WARRIOR/FURY" and equipLoc(mh) == "INVTYPE_2HWEAPON" and not map[17] then items[17] = nil end
    return items
end

local STAT_KEYS = { "crit", "haste", "mastery", "vers" }
local STAT_LBL = { crit = { "STAT_CRIT", "暴击" }, haste = { "STAT_HASTE", "急速" }, mastery = { "STAT_MASTERY", "精通" }, vers = { "STAT_VERS", "全能" } }
local function ico(tex, size) return "|T" .. tostring(tex) .. ":" .. (size or 14) .. ":" .. (size or 14) .. ":0:0:64:64:5:59:5:59|t" end

-- 菜单项悬浮（用户 2026-09-25「这里移动最后能看到宝石的属性」）：
--   宝石 = SetItemByID 原生物品提示（属性数值以游戏为准）；附魔 / 美化 = 数据里的效果说明；都带顶尖玩家使用率
local function usageLine(tt, pct)
    if pct then tt:AddLine(string.format(T("BP_TIP_USAGE", "顶尖玩家使用率 %.0f%%"), pct), 0.6, 0.63, 0.67) end
end
local function tipGem(e, gid, pct)
    if not (e and e.SetTooltip and gid) then return end
    e:SetTooltip(function(tt)
        if tt.SetItemByID then tt:SetItemByID(gid) else GameTooltip_SetTitle(tt, BP.GemName(gid)) end
        if BP.GemUnique(gid) then tt:AddLine(T("BP_GEM_UNIQUE", "这颗宝石全身只能镶一颗"), 1, 0.82, 0, true) end
        usageLine(tt, pct)
    end)
end
local function tipEnch(e, eid, pct)
    if not (e and e.SetTooltip and eid) then return end
    e:SetTooltip(function(tt)
        GameTooltip_SetTitle(tt, BP.EnchantName(eid))
        local d = BP.EnchantDesc(eid)
        if d then tt:AddLine(d, 1, 1, 1, true) end
        usageLine(tt, pct)
    end)
end
local function tipEm(e, bid, pct)
    if not (e and e.SetTooltip and bid) then return end
    e:SetTooltip(function(tt)
        GameTooltip_SetTitle(tt, BP.EmName(bid))
        local d = BP.EmDesc(bid)
        if d then tt:AddLine(d, 1, 1, 1, true) end
        usageLine(tt, pct)
    end)
end

function openSlotMenu(owner, sd, key2, slot)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local itemId, ps = slotItem(key2, sd, slot)
    if not itemId then return end
    local items = planItems(key2, sd)
    local plan = curPlan(key2)
    local sx = BP.SpecX(sd)
    local ench, gems, autoE, autoG = BP.ResolveExtras(plan or { enchants = "auto", gems = "auto" }, sd, items)
    local function warn(code)
        local msg = ({ embellish_limit = T("BP_EM_LIMIT", "美化全身最多 2 件：先去掉另一件的美化"),
                       not_crafted = T("BP_EM_NOT_CRAFTED", "美化只能做在制造装备上"),
                       gem_unique = T("BP_GEM_UNIQUE", "这颗宝石全身只能镶一颗") })[code]
        if msg then GearInsight:Print("|cffff9f0a" .. msg .. "|r") end
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L2(SLOT_NAME[slot]) .. " · " .. itemName(itemId))
        -- 升级轨道（方案里放了装备的格子才有）
        if ps then
            local tr0 = ps.track or "x"
            local sub = root:CreateButton(T("BP_M_TRACK", "升级轨道") .. "：" .. L2(TRACK_LABEL[tr0]))
            for _, tr in ipairs(BP.TRACKS) do
                local cap = BP.TRACK_MAX[tr]
                local label = L2(TRACK_LABEL[tr]) .. (cap and ("  " .. cap) or ("  |cff9aa0aa" .. T("BP_TR_X_TIP2", "这件的轨道升满") .. "|r"))
                sub:CreateRadio(label, function() return (ps.track or "x") == tr end,
                    function()
                        -- 手动选轨道表示规划目标；原实例 bonus 会覆盖该目标，不能继续带入。
                        BP.SetSlot(key2, state.editId, slot, ps.id, tr, { cf = ps.cf, cs = ps.cs, em = ps.em, b = tr == "x" and ps.b or nil, ext = ps.ext })
                    end)
            end
        end
        -- 附魔
        if BP.CanEnchant(slot, itemId) then
            local cur = ench[slot]
            local head = cur and (BP.EnchantName(cur) .. (autoE[slot] and ("|cff9aa0aa " .. T("BP_AUTO_TAG", "（自动）") .. "|r") or "")) or ("|cffff6060" .. T("BP_NONE", "无") .. "|r")
            local sub = root:CreateButton(T("BP_M_ENCH", "附魔") .. "：" .. head)
            tipEnch(sub, cur)
            for _, eu in ipairs((sx and sx.ench and sx.ench[slot]) or {}) do
                local eid, pct = eu[1], eu[2]
                tipEnch(sub:CreateRadio(ico(BP.EnchantIcon(eid)) .. " " .. BP.EnchantName(eid) .. string.format("  |cff9aa0aa%.0f%%|r", pct or 0),
                    function() return cur == eid end, function() BP.SetEnchant(key2, state.editId, sd, items, slot, eid) end), eid, pct)
            end
            sub:CreateDivider()
            sub:CreateRadio("|cffff6060" .. T("BP_ENCH_NONE", "不附魔") .. "|r", function() return cur == nil end,
                function() BP.SetEnchant(key2, state.editId, sd, items, slot, false) end)
            sub:CreateButton("|cff9aa0aa" .. T("BP_ALL_AUTO_E", "全部附魔恢复自动（按使用率）") .. "|r", function() BP.SetEnchant(key2, state.editId, sd, items, slot, nil) end)
        end
        -- 宝石：按孔。孔数 = 数据里最常见的孔数（max），这件方案里已有更多宝石就按已有的
        local so = sx and sx.sock and sx.sock[slot]
        local cg = gems[slot] or {}
        local nSock = math.max((so and so.max) or 0, #cg)
        if nSock > 0 then
            local names = {}
            for _, g in ipairs(cg) do names[#names + 1] = BP.GemName(g) end
            local head = (#names > 0 and table.concat(names, " / ") or ("|cff9aa0aa" .. T("BP_NONE", "无") .. "|r")) .. (autoG[slot] and ("|cff9aa0aa " .. T("BP_AUTO_TAG", "（自动）") .. "|r") or "")
            local sub = root:CreateButton(string.format(T("BP_M_GEM", "宝石（%d 孔）"), nSock) .. "：" .. head)
            if so and (so.pct or 0) < 50 then
                sub:CreateTitle("|cff9aa0aa" .. string.format(T("BP_GEM_SOCK_NOTE", "这个部位只有 %.0f%% 的顶尖玩家带孔：你这件没孔就不用镶"), so.pct or 0) .. "|r")
            end
            for i = 1, nSock do
                local gi = cg[i]
                local s2 = sub:CreateButton(string.format(T("BP_GEM_SOCKET", "孔 %d"), i) .. "：" .. (gi and (ico(BP.GemIcon(gi)) .. " " .. BP.GemName(gi)) or ("|cff9aa0aa" .. T("BP_EMPTY_SOCK", "空") .. "|r")))
                tipGem(s2, gi)
                for _, gu in ipairs((sx and sx.gem and sx.gem[slot]) or {}) do
                    local gid, pct = gu[1], gu[2]
                    local eg = s2:CreateRadio(ico(BP.GemIcon(gid)) .. " " .. BP.GemName(gid) .. string.format("  |cff9aa0aa%.0f%%|r", pct or 0)
                        .. (BP.GemUnique(gid) and ("  |cffffd100" .. T("BP_GEM_UNIQ_TAG", "唯一") .. "|r") or ""),
                        function() return gi == gid end,
                        function()
                            local list = {}
                            for k = 1, nSock do list[k] = cg[k] end
                            list[i] = gid
                            local out = {}
                            for k = 1, nSock do if list[k] then out[#out + 1] = list[k] end end
                            local ok, err = BP.SetGems(key2, state.editId, sd, items, slot, out)
                            if not ok then warn(err) end
                        end)
                    tipGem(eg, gid, pct)
                end
                s2:CreateRadio("|cff9aa0aa" .. T("BP_EMPTY_SOCK", "空") .. "|r", function() return gi == nil end, function()
                    local out = {}
                    for k = 1, nSock do if k ~= i and cg[k] then out[#out + 1] = cg[k] end end
                    BP.SetGems(key2, state.editId, sd, items, slot, out)
                end)
            end
            sub:CreateDivider()
            sub:CreateButton("|cff9aa0aa" .. T("BP_ALL_AUTO_G", "全部宝石恢复自动（按使用率）") .. "|r", function() BP.SetGems(key2, state.editId, sd, items, slot, nil) end)
        end
        -- 美化 / 制造属性（只有制造件）
        if BP.CanEmbellish(sd, itemId) then
            local curEm = ps and tonumber(ps.em) or nil
            if curEm == 0 then curEm = nil end
            local n = 0
            for _, s0 in ipairs((plan and plan.slots) or {}) do if (tonumber(s0.em) or 0) > 0 then n = n + 1 end end
            local sub = root:CreateButton(T("BP_M_EM", "美化") .. "：" .. (curEm and BP.EmName(curEm) or ("|cff9aa0aa" .. T("BP_NONE", "无") .. "|r"))
                .. string.format("  |cff9aa0aa%d/%d|r", n, BP.EM_LIMIT))
            tipEm(sub, curEm)
            for _, eu in ipairs((sx and sx.em and sx.em[slot]) or {}) do
                local bid, pct = eu[1], eu[2]
                local e = sub:CreateRadio(ico(BP.EmIcon(bid)) .. " " .. BP.EmName(bid) .. string.format("  |cff9aa0aa%.0f%%|r", pct or 0),
                    function() return curEm == bid end,
                    function() local ok, err = BP.SetEmbellish(key2, state.editId, sd, slot, itemId, bid); if not ok then warn(err) end end)
                tipEm(e, bid, pct)
                if n >= BP.EM_LIMIT and not curEm and e and e.SetEnabled then e:SetEnabled(false) end
            end
            sub:CreateRadio("|cff9aa0aa" .. T("BP_EM_NONE", "不美化") .. "|r", function() return curEm == nil end,
                function() BP.SetEmbellish(key2, state.editId, sd, slot, itemId, nil) end)
            if n >= BP.EM_LIMIT and not curEm then sub:CreateTitle("|cffff9f0a" .. T("BP_EM_LIMIT", "美化全身最多 2 件：先去掉另一件的美化") .. "|r") end
            -- 制造两条属性（第一项拿大的那份，约 2:1）
            local cs = ps and ps.cs
            local ideal = GearInsight.RandIdealGib and GearInsight.RandIdealGib(sd)
            local csTxt = (cs and #cs >= 2) and (L2(STAT_LBL[cs[1]] or { "", cs[1] }) .. " / " .. L2(STAT_LBL[cs[2]] or { "", cs[2] }))
                or ((ideal and (L2(STAT_LBL[ideal[1]]) .. " / " .. L2(STAT_LBL[ideal[2]]))) or "") .. "|cff9aa0aa " .. T("BP_AUTO_TAG", "（自动）") .. "|r"
            local sub2 = root:CreateButton(T("BP_M_CS", "制造属性") .. "：" .. csTxt)
            sub2:CreateTitle("|cff9aa0aa" .. T("BP_CS_NOTE", "第一项点数约是第二项的 2 倍") .. "|r")
            sub2:CreateRadio(T("BP_CS_AUTO", "自动（按专精最想要的两项）"), function() return not (cs and #cs >= 2) end,
                function() BP.SetCraftStats(key2, state.editId, slot, itemId, nil) end)
            for _, a in ipairs(STAT_KEYS) do
                for _, b in ipairs(STAT_KEYS) do
                    if a ~= b then
                        sub2:CreateRadio(L2(STAT_LBL[a]) .. " / " .. L2(STAT_LBL[b]), function() return cs and cs[1] == a and cs[2] == b end,
                            function() BP.SetCraftStats(key2, state.editId, slot, itemId, { a, b }) end)
                    end
                end
            end
        end
    end)
end

-- 物品放进格子（Shift 点链接 / 拖放）：部位对不上就放到能放的那一格
local function dropItem(itemId, link)
    local sd, key2 = specInfo()
    if not (key2 and itemId) then return false end
    local ok = EQUIP_SLOTS[equipLoc(itemId) or ""]
    if not ok then GearInsight:Print(T("BP_NOT_GEAR", "这不是能穿的装备")); return false end
    local target = ok[1]
    for _, s in ipairs(ok) do if s == state.selected then target = s end end
    setSlot(key2, target, itemId, "x", { b = BP.BonusesFromLink(link) })
    state.selected = target
    return true
end
GearInsight._planDropItem = dropItem

-- ── 检查（方案能不能穿上）────────────────────────────────────────────
-- 主手是双手武器（方案里放的，没放就看数据推荐那件）且不是狂暴战 → 副手格用不上
--   （09-25 用户截图：守护德主手长柄大斧，副手格还写「（空）数据推荐」、右栏「1 格没填」—— 误报）
local function mainIs2H(sd, map, picks)
    if BP.KeyOfSpecData(sd) == "WARRIOR/FURY" then return false end
    local mh = (map[16] and map[16].id) or (picks and picks[16])
    return mh and equipLoc(mh) == "INVTYPE_2HWEAPON" or false
end

local function checks(sd, plan)
    local out = {}
    local map = plan and BP.SlotMap(plan) or {}
    local _, cls = UnitClass("player")
    local tierIds = {}
    for _, v in pairs((GearInsight.TierSets and GearInsight.TierSets[cls]) or {}) do tierIds[v[1]] = true end
    local nTier = 0
    for _, ps in pairs(map) do
        local e = BP.FindEntry(sd, ps.id)
        if tierIds[ps.id] or (e and e.isTier) or (ps.cf and ps.cf > 0) then nTier = nTier + 1 end
    end
    out[#out + 1] = { ok = nTier >= 4, text = string.format(T("BP_CK_TIER", "套装 %d 件"), nTier) .. (nTier >= 4 and "" or T("BP_CK_TIER_LOW", "（不足 4 件）")) }
    local dup = (map[11] and map[12] and map[11].id == map[12].id) or (map[13] and map[14] and map[13].id == map[14].id)
    out[#out + 1] = { ok = not dup, text = dup and T("BP_CK_DUP", "戒指 / 饰品选了同一件（唯一装备穿不了两件）") or T("BP_CK_UNIQUE", "戒指 / 饰品不重复") }
    local fury = BP.KeyOfSpecData(sd) == "WARRIOR/FURY"
    local mh, oh = map[16] and equipLoc(map[16].id), map[17] and equipLoc(map[17].id)
    local wBad = (not fury) and ((mh == "INVTYPE_2HWEAPON" and map[17]) or oh == "INVTYPE_2HWEAPON")
    out[#out + 1] = { ok = not wBad, text = wBad and T("BP_CK_WEAPON_BAD", "双手武器不能再配副手（只有狂暴战能双持双手）") or T("BP_CK_WEAPON", "武器搭配可穿") }
    -- 附魔 / 宝石 / 美化（网站 check_extras 同口径）
    do
        local picks = dataPicks(sd)
        local items = {}
        for _, s0 in ipairs(BP.SLOTS) do local id0 = (map[s0] and map[s0].id) or picks[s0]; if id0 then items[s0] = id0 end end
        if mainIs2H(sd, map, picks) and not map[17] then items[17] = nil end
        local x = BP.CheckExtras(plan or { enchants = "auto", gems = "auto" }, sd, items)
        out[#out + 1] = { ok = x.enchN >= x.enchSlots, text = string.format(T("BP_CK_ENCH", "附魔 %d/%d 部位"), x.enchN, x.enchSlots) }
        -- 美化不是“未超上限就算完成”：0/2、1/2 是合法但未补齐的可选状态，
        -- 只有达到上限才显示绿色完成；超过上限仍显示警告。
        out[#out + 1] = {
            ok = (x.emN >= BP.EM_LIMIT) and not x.emOver,
            dim = (x.emN < BP.EM_LIMIT) and not x.emOver,
            text = string.format(T("BP_CK_EM", "美化 %d/%d 件"), x.emN, BP.EM_LIMIT)
                .. (x.emOver and T("BP_CK_EM_OVER", "（超了，只能 2 件）")
                    or (x.emN < BP.EM_LIMIT and T("BP_CK_EM_OPTIONAL", "（可选，未补齐）") or ""))
        }
        if x.gemUniqueBad then out[#out + 1] = { ok = false, text = T("BP_CK_GEM_UNIQ", "唯一宝石镶了不止一颗") } end
    end
    local empty = 0
    local no17 = mainIs2H(sd, map, dataPicks(sd))
    for _, s in ipairs(BP.SLOTS) do if not map[s] and not (s == 17 and no17) then empty = empty + 1 end end
    if empty > 0 then out[#out + 1] = { ok = true, dim = true, text = string.format(T("BP_CK_EMPTY", "%d 格没填：按数据推荐补"), empty) } end
    return out
end

-- ── 属性对比 ─────────────────────────────────────────────────────────
local function currentShares()
    -- 左侧必须和角色面板的“绿字评级”同源：优先读刚保存的实时角色快照，
    -- 再退回装备逐件统计（物品缓存尚未就绪时的兜底）。
    local saved = GearInsight.SavedVars
    local snap = saved and saved.GetLastSnapshot and saved:GetLastSnapshot()
    local raw = snap and snap.secondaryRating
    local sum = 0
    for _, k in ipairs({ "crit", "haste", "mastery", "versatility" }) do sum = sum + (tonumber(raw and raw[k]) or 0) end
    if sum > 0 then
        local pct = {}
        for _, k in ipairs({ "crit", "haste", "mastery", "versatility" }) do pct[k] = (tonumber(raw[k]) or 0) / sum * 100 end
        -- pct 是画柱状图用的评级配比；shown 是角色面板同源的实际属性百分比。
        return pct, raw, snap.secondary
    end
    local sd = BP.PlayerSpecData()
    local pct, complete, fallback = BP.ComputeStatPercents({
        slots = BP.FromEquipped(), stats = { mode = "auto" },
    }, sd)
    if not complete then return nil end
    return pct, fallback, pct
end

local function sameAsEquipped(plan)
    if not plan then return false end
    local now, wanted = {}, 0
    for _, s in ipairs(BP.FromEquipped()) do now[s.slot] = s.id; wanted = wanted + 1 end
    local got = 0
    for _, s in ipairs(plan.slots or {}) do
        if now[s.slot] ~= s.id then return false end
        got = got + 1
    end
    return wanted > 0 and got == wanted
end

-- ── 页面 ─────────────────────────────────────────────────────────────
local function styleChip(b, sel, filled)
    if sel then
        b:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.95); b:SetBackdropColor(0.16, 0.13, 0.05, 0.98)
        b.fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        b:SetBackdropBorderColor(0.30, 0.30, 0.34, 0.9); b:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
        b.fs:SetTextColor(filled and 0.85 or 0.5, filled and 0.85 or 0.5, filled and 0.85 or 0.5)
    end
end

local function mkButton(parent, w, text, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 26); b:SetText(text); b:SetScript("OnClick", fn)
    return b
end

local function snapshotPlan(sd, key2)
    local plan = BP.CopyPlan(curPlan(key2) or { stats = { mode = "auto" }, gems = "auto", enchants = "auto", src = "addon" })
    local map = BP.SlotMap(plan)
    -- 未自选的格子也存下来，避免推荐数据更新后存档悄悄变装。
    for _, slot in ipairs(BP.FromData(sd, true)) do
        if not map[slot.slot] then
            slot.b = BP.CopyPlan(bonusFor(sd, slot.id))
            map[slot.slot] = slot
        end
    end
    if mainIs2H(sd, map, dataPicks(sd)) then map[17] = nil end
    plan.slots = {}
    for _, slot in pairs(map) do plan.slots[#plan.slots + 1] = slot end
    table.sort(plan.slots, function(a, b) return a.slot < b.slot end)
    return plan
end

local function saveNamedDialog(page)
    local sd, key2 = specInfo()
    if not key2 then return end
    if #BP.SavedPlans(key2) >= 10 then GearInsight:Print(T("BP_SAVE_LIMIT", "每个专精最多保存 10 套配装，请覆盖或删除已有存档。")); return end
    local plan = snapshotPlan(sd, key2)
    if #plan.slots == 0 then GearInsight:Print(T("BP_SAVE_EMPTY", "先选择装备再保存配装。")); return end

    local f = page._saveNamed
    if not f then
        f = CreateFrame("Frame", "GearInsightPlanSaveDialog", page, "BackdropTemplate")
        f:SetSize(472, 286); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.04, 0.04, 0.07, 1); f:SetBackdropBorderColor(0.8, 0.65, 0.2, 1)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 20, -18); title:SetText(T("BP_SAVE_NAMED", "保存配装"))
        f.name = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        f.name:SetSize(422, 28); f.name:SetPoint("TOPLEFT", 26, -50); f.name:SetAutoFocus(false); f.name:SetMaxLetters(40)
        f.name:SetScript("OnEscapePressed", function() f:Hide() end)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 20, -90); hint:SetText(T("BP_SAVE_ICON", "选择图标：点击这套配装中的任意一件装备"))
        f.icons = {}
        for i = 1, 16 do
            local b = CreateFrame("Button", nil, f, "BackdropTemplate")
            b:SetSize(44, 44); b:SetPoint("TOPLEFT", 20 + ((i - 1) % 8) * 54, -112 - math.floor((i - 1) / 8) * 52)
            b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
            b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 3, -3); b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
            b:SetScript("OnClick", function()
                f.iconItem = b.itemId
                for _, icon in ipairs(f.icons) do
                    if icon.itemId == f.iconItem then icon:SetBackdropBorderColor(1, 0.82, 0, 1)
                    else icon:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end
                end
            end)
            b:SetScript("OnEnter", function()
                GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(itemName(b.itemId)); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.icons[i] = b
        end
        f.err = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.err:SetPoint("BOTTOMLEFT", 20, 51); f.err:SetTextColor(1, 0.3, 0.3)
        local save = mkButton(f, 100, T("BP_SAVE_NAMED", "保存配装"), function()
            local name = f.name:GetText():gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" then f.err:SetText(T("BP_SAVE_NAME_REQUIRED", "请输入配装名称")); return end
            local record = BP.SaveNamed(f.key2, f.plan, name, f.iconItem)
            if record then
                f:Hide(); GearInsight:Print(T("BP_SAVE_DONE", "已保存配装：") .. record.name)
            else f.err:SetText(T("BP_SAVE_LIMIT", "每个专精最多保存 10 套配装，请覆盖或删除已有存档。")) end
        end)
        save:SetPoint("BOTTOMRIGHT", -128, 16)
        local cancel = mkButton(f, 100, CANCEL, function() f:Hide() end); cancel:SetPoint("BOTTOMRIGHT", -20, 16)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "GearInsightPlanSaveDialog" end
        page._saveNamed = f
    end
    f.key2, f.plan, f.iconItem = key2, plan, plan.slots[1].id
    f.name:SetText(plan.name or L2(PLAN_LABEL[state.editId])); f.err:SetText("")
    for i, b in ipairs(f.icons) do
        local slot = plan.slots[i]
        b.itemId = slot and slot.id
        b:SetShown(slot ~= nil)
        if slot then b.icon:SetTexture(itemIcon(slot.id)) end
        if b.itemId == f.iconItem then b:SetBackdropBorderColor(1, 0.82, 0, 1)
        else b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end
    end
    f:Show(); f.name:SetFocus(); f.name:HighlightText()
end

local function openNamedPlans(owner)
    local _, key2 = specInfo()
    if not key2 then return end
    local page = GearInsight._planPage
    local f = page._savedList
    if not f then
        f = CreateFrame("Frame", "GearInsightPlanArchiveDialog", UIParent, "BackdropTemplate")
        f:SetSize(700, 480); f:SetPoint("CENTER", UIParent, "CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
        f:SetMovable(true); f:SetClampedToScreen(true)
        local drag = CreateFrame("Frame", nil, f)
        drag:SetPoint("TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", -38, 0); drag:SetHeight(40)
        drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
        drag:SetScript("OnDragStart", function() f:StartMoving() end)
        drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
        f:SetScript("OnHide", function() f:StopMovingOrSizing() end)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.04, 0.04, 0.07, 1); f:SetBackdropBorderColor(0.8, 0.65, 0.2, 1)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 18, -18)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -3, -3)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", 18, -45); hint:SetText(T("BP_ARCHIVE_HELP", "覆盖保存使用当前编辑的配装；删除只移除存档。"))
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 16, -70); sf:SetPoint("BOTTOMRIGHT", -36, 48)
        local body = CreateFrame("Frame", nil, sf); body:SetSize(646, 1); sf:SetScrollChild(body)
        f.body, f.rows, f.scroll = body, {}, sf
        f.empty = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.empty:SetPoint("TOPLEFT", 12, -20); f.empty:SetText(T("BP_NO_SAVED_PLANS", "还没有存档，先点击「保存配装」"))
        local done = mkButton(f, 90, CLOSE, function() f:Hide() end); done:SetPoint("BOTTOMRIGHT", -18, 12)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "GearInsightPlanArchiveDialog" end
        page._savedList = f
    end
    local function refresh()
        local list = BP.SavedPlansNewest(key2)
        local newest = list[1]
        local revision = newest and (tostring(newest.id) .. ":" .. tostring(newest.savedAt) .. ":" .. tostring(newest.saveOrder))
        if revision ~= f.newestRevision then f.scroll:SetVerticalScroll(0) end
        f.newestRevision = revision
        f.title:SetText(T("BP_SAVED_PLANS", "已存配装") .. "  " .. #list .. "/10")
        f.empty:SetShown(#list == 0)
        f.body:SetHeight(math.max(80, #list * 86))
        for _, row in ipairs(f.rows) do row:Hide() end
        for i, record in ipairs(list) do
            local row = f.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, f.body, "BackdropTemplate"); row:SetSize(642, 80)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 86)
                row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); row:SetBackdropColor(0.09, 0.09, 0.13, 1)
                row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(38, 38); row.icon:SetPoint("LEFT", 8, 0)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.name:SetPoint("TOPLEFT", 56, -10); row.name:SetWidth(310); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
                row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.info:SetPoint("TOPLEFT", 56, -58); row.info:SetWidth(310); row.info:SetJustifyH("LEFT")
                row.identity = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.identity:SetPoint("TOPLEFT", 56, -32); row.identity:SetWidth(310); row.identity:SetJustifyH("LEFT"); row.identity:SetWordWrap(false)
                row.detail = CreateFrame("Frame", nil, row); row.detail:SetPoint("TOPLEFT", 52, -4); row.detail:SetSize(314, 70); row.detail:EnableMouse(true)
                row.detail:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(row.detail, "ANCHOR_RIGHT")
                    GameTooltip:SetText(row.fullName or "")
                    GameTooltip:AddLine(row.fullIdentity or "", 1, 1, 1, true); GameTooltip:Show()
                end)
                row.detail:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row.load = mkButton(row, 62, T("BP_LOAD_NAMED", "载入"), function() row.action("load") end)
                row.load:SetPoint("RIGHT", -190, 0)
                row.overwrite = mkButton(row, 98, T("BP_OVERWRITE_NAMED", "覆盖保存"), function() row.action("overwrite") end)
                row.overwrite:SetPoint("RIGHT", -84, 0)
                row.delete = mkButton(row, 66, T("BP_DELETE_NAMED", "删除"), function() row.action("delete") end)
                row.delete:SetPoint("RIGHT", -10, 0)
                f.rows[i] = row
            end
            row.icon:SetTexture(itemIcon(record.iconItem)); row.name:SetText(record.name)
            local identity = record.identity or {}
            local specName, specIcon = identity.specName, identity.specIcon
            local specId = identity.specId or BP.SpecIdOf(key2)
            if not specName and specId and GetSpecializationInfoByID then
                local _, name, _, icon = GetSpecializationInfoByID(specId)
                specName, specIcon = name, icon
            end
            local talentName = identity.talents and identity.talents.name or T("BP_ARCHIVE_NO_TALENT", "未记录天赋")
            local detail = "|T" .. tostring(specIcon or 134400) .. ":18:18|t " .. (specName or key2)
                .. "  |T" .. tostring(identity.talentIcon or 236415) .. ":18:18|t " .. talentName
            row.identity:SetText(detail); row.fullIdentity, row.fullName = detail, record.name
            local stamp = record.savedAt and record.savedAt > 0 and date("%Y-%m-%d %H:%M", record.savedAt) or "—"
            row.info:SetText(string.format(T("BP_ARCHIVE_INFO", "%d 件 · 保存于 %s"), #(record.plan.slots or {}), stamp))
            row.action = function(action)
                local target = state.editId
                local sd, currentKey = specInfo()
                if currentKey ~= key2 then f:Hide(); return end
                local snapshot = action == "overwrite" and snapshotPlan(sd, key2) or nil
                local question = action == "delete" and T("BP_DELETE_ARCHIVE_ASK", "删除配装存档「%s」？")
                    or action == "overwrite" and T("BP_OVERWRITE_ARCHIVE_ASK", "用当前编辑的配装覆盖「%s」？原存档内容将被替换。")
                    or T("BP_LOAD_NAMED_ASK", "载入「%s」到当前方案？当前方案的内容将被替换。")
                StaticPopupDialogs.GEARINSIGHT_PLAN_ARCHIVE_ACTION = {
                    text = question, button1 = ACCEPT, button2 = CANCEL,
                    OnAccept = function()
                        if action == "delete" then BP.DeleteNamed(key2, record.id)
                        elseif action == "overwrite" then BP.OverwriteNamed(key2, record.id, snapshot)
                        else BP.LoadNamed(key2, record.id, target) end
                        refresh()
                    end,
                    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
                }
                StaticPopup_Show("GEARINSIGHT_PLAN_ARCHIVE_ACTION", record.name)
            end
            row:Show()
        end
    end
    f.Refresh, f.specKey = refresh, key2
    refresh(); f.scroll:SetVerticalScroll(0); f:Show()
end

local function build(page)
    if page._planBuilt then return end
    page._planBuilt = true
    local saved = mkButton(page, 100, T("BP_SAVED_PLANS", "已存配装"), openNamedPlans)
    saved:SetPoint("TOPRIGHT", -12, -4)
    local save = mkButton(page, 100, T("BP_SAVE_NAMED", "保存配装"), function() saveNamedDialog(page) end)
    save:SetPoint("RIGHT", saved, "LEFT", -8, 0)

    -- 顶部横条：专精 · 方案芯片 · 启用开关
    local band = page:CreateTexture(nil, "BACKGROUND", nil, 1)
    band:SetPoint("TOPLEFT", 0, -36); band:SetPoint("TOPRIGHT", 0, -36); band:SetHeight(46)
    band:SetColorTexture(1, 1, 1, 1)
    if band.SetGradient and CreateColor then
        band:SetGradient("VERTICAL", CreateColor(0.05, 0.05, 0.08, 1), CreateColor(0.11, 0.095, 0.05, 1))
    else
        band:SetColorTexture(0.09, 0.08, 0.05, 1)
    end

    page.specIcon = page:CreateTexture(nil, "ARTWORK"); page.specIcon:SetSize(30, 30); page.specIcon:SetPoint("TOPLEFT", 14, -44)
    page.specIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    page.specName = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); page.specName:SetPoint("LEFT", page.specIcon, "RIGHT", 8, 0)

    page.chips = {}
    local prev
    for _, id in ipairs(BP.PLAN_IDS) do
        local b = CreateFrame("Button", nil, page, "BackdropTemplate"); b:SetSize(78, 26)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.fs:SetPoint("CENTER")
        b.dot = b:CreateTexture(nil, "OVERLAY"); b.dot:SetSize(6, 6); b.dot:SetPoint("TOPRIGHT", -4, -4); b.dot:SetColorTexture(0.3, 1, 0.4, 1)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 236, -46) end
        b:SetScript("OnClick", function() state.editId = id; state.selected = nil; GearInsight:RenderPlanPage() end)
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM"); GameTooltip:SetText(L2(PLAN_LABEL[id]), 1, 0.82, 0)
            GameTooltip:AddLine(T("BP_CHIP_ARCHIVE_TT", "三个工作方案分别编辑；更多配装可命名存档。绿点 = 正在生效。"), 0.9, 0.9, 0.9, true)
            local _, key2 = specInfo()
            local plan = key2 and BP.Get(key2, id)
            if plan and plan.name then GameTooltip:AddLine(plan.name, 1, 1, 1) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b._id = id; page.chips[#page.chips + 1] = b; prev = b
    end

    page.toggle = CreateFrame("Button", nil, page, "BackdropTemplate"); page.toggle:SetSize(216, 30)
    page.toggle:SetPoint("TOPRIGHT", -12, -44)
    page.toggle:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    page.toggle.fs = page.toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal"); page.toggle.fs:SetPoint("CENTER")
    page.toggle:SetScript("OnClick", function()
        local sd, key2 = specInfo()
        if not key2 then return end
        if BP.ActiveId(key2) == state.editId then
            BP.SetActive(key2, nil)
            GearInsight:Print(T("BP_OFF_MSG", "已切回数据推荐：插件各处按 WCL 顶尖玩家使用率推荐。"))
        else
            local plan = curPlan(key2)
            if not (plan and #(plan.slots or {}) > 0) then
                BP.Save(key2, state.editId, { name = L2(PLAN_LABEL[state.editId]), slots = BP.FromData(sd, true), stats = { mode = "auto" }, gems = "auto", enchants = "auto", src = "addon" })
            end
            BP.SetActive(key2, state.editId)
            GearInsight:Print(string.format(T("BP_ON_MSG", "已启用「%s」方案：装备总览、角色面板、悬浮提示、刷本规划、低保、属性目标都按它走。"), L2(PLAN_LABEL[state.editId])))
        end
    end)
    page.toggle:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOMLEFT"); GameTooltip:SetText(T("BP_TOGGLE_TT_T", "BiS 依据"), 1, 0.82, 0)
        GameTooltip:AddLine(T("BP_TOGGLE_TT", "启用后，插件里所有「推荐哪件 / 算不算毕业 / 属性目标」都按这套方案；关掉就回到 WCL 顶尖玩家使用率。"), 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    page.toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    page.hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); page.hint:SetPoint("TOPLEFT", 14, -90)
    page.hint:SetText(T("BP_HINT", "左键换装备 · 右键调轨道/附魔/宝石/美化 · Shift+点物品链接放入已选格"))

    -- 16 格
    page.cards = {}
    local function place(list, x)
        for i, slot in ipairs(list) do
            local c = makeCard(page)
            c:SetPoint("TOPLEFT", x, -108 - (i - 1) * (CARD_H + GAP))
            c._slot = slot
            c:SetScript("OnClick", function(self, btn)
                local sd, key2 = specInfo()
                if not key2 then return end
                state.selected = slot
                if not curPlan(key2) then
                    BP.Save(key2, state.editId, { name = L2(PLAN_LABEL[state.editId]), slots = {}, stats = { mode = "auto" }, gems = "auto", enchants = "auto", src = "addon" })
                end
                -- 光标上拿着物品 = 放进来
                local ctype, cid, clink = GetCursorInfo()
                if ctype == "item" and cid then ClearCursor(); dropItem(cid, clink); return end
                if IsModifiedClick and IsModifiedClick("CHATLINK") and self._itemId then
                    local link = select(2, C_Item.GetItemInfo(self._itemId))
                    if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
                    return
                end
                GearInsight:RenderPlanPage()
                if btn == "RightButton" then openSlotMenu(self, sd, key2, slot) else openCandidateMenu(self, sd, key2, slot) end
            end)
            c:SetScript("OnReceiveDrag", function()
                local ctype, cid, clink = GetCursorInfo()
                if ctype == "item" and cid then ClearCursor(); state.selected = slot; dropItem(cid, clink) end
            end)
            c:SetScript("OnEnter", function(self)
                if not self._itemId then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self._link then GameTooltip:SetHyperlink(self._link) else GameTooltip:SetItemByID(self._itemId) end
                -- 指定了英雄 / 勇士 / 老兵轨道，链接给不出那一档的装等 → 明说方案目标是多少
                if self._extLines then
                    GameTooltip:AddLine(" ")
                    for _, ln in ipairs(self._extLines) do GameTooltip:AddLine(ln, 0.85, 0.85, 0.85, true) end
                end
                if self._rand then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string.format(T("BP_TT_RAND", "随机属性：掉落时随机两条。方案按你专精最想要的「%s」计算，实际以掉落为准"), self._rand), 0.4, 0.8, 1, true)
                end
                if self._tgtIlvl and (self._tgtTrack ~= "m" or not self._link) then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string.format(T("BP_TT_TARGET", "方案目标装等：%d（%s）"), self._tgtIlvl, L2(TRACK_LABEL[self._tgtTrack] or TRACK_LABEL.x)), 1, 0.82, 0)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff66ccff" .. T("BP_TT_HINT", "左键：换装备 · 右键：升级轨道 / 附魔 / 宝石 / 美化 / 制造属性") .. "|r", 0.4, 0.8, 1, true)
                GameTooltip:Show()
            end)
            c:SetScript("OnLeave", function() GameTooltip:Hide() end)
            page.cards[slot] = c
        end
    end
    place(LEFT_SLOTS, 12)
    place(RIGHT_SLOTS, 12 + CARD_W + 10)

    -- 右栏：属性 + 检查
    local rx = 12 + CARD_W * 2 + 24
    local panel = CreateFrame("Frame", nil, page, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", rx, -108); panel:SetPoint("BOTTOMRIGHT", -12, 52)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    panel:SetBackdropColor(0.055, 0.06, 0.085, 0.96); panel:SetBackdropBorderColor(0.42, 0.35, 0.15, 0.7)
    page.panel = panel
    -- 顶部操作说明只属于左侧装备格；限制到右栏左边，不能再横向溢出框外。
    page.hint:SetPoint("RIGHT", panel, "LEFT", -10, 0); page.hint:SetJustifyH("LEFT"); page.hint:SetWordWrap(false)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal"); panel.title:SetPoint("TOPLEFT", 12, -10)
    -- 左列是角色面板实际百分比；右列是方案装备绿字的构成配比，不能都叫“实际百分比”。
    panel.title:SetText(T("BP_STAT_TITLE", "副属性配比")); panel.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    -- 标题与两侧数值口径分两行，不共用窄栏的一行宽度。
    panel.sub = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.sub:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -2); panel.sub:SetPoint("RIGHT", -12, 0); panel.sub:SetJustifyH("LEFT")
    panel.sub:SetText(T("BP_STAT_SUB", "身上实际% → 方案配比"))
    panel.rows = {}
    local barW = 190
    for i, row in ipairs(STAT_ROWS) do
        local y = -54 - (i - 1) * 44
        local r = {}
        r.name = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.name:SetPoint("TOPLEFT", 12, y); r.name:SetText(T(row[2], row[3]))
        -- 变化箭头属于数值列，必须以右侧内边距为界；固定左起会让 ▲/▼ 溢出面板。
        r.val = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.val:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, y - 1); r.val:SetJustifyH("RIGHT")
        r.track = panel:CreateTexture(nil, "ARTWORK"); r.track:SetPoint("TOPLEFT", 12, y - 18); r.track:SetSize(barW, 5); r.track:SetColorTexture(1, 1, 1, 0.06)
        r.cur = panel:CreateTexture(nil, "ARTWORK", nil, 1); r.cur:SetPoint("TOPLEFT", r.track, "TOPLEFT"); r.cur:SetSize(1, 5); r.cur:SetColorTexture(0.45, 0.62, 0.85, 0.9)
        r.track2 = panel:CreateTexture(nil, "ARTWORK"); r.track2:SetPoint("TOPLEFT", 12, y - 26); r.track2:SetSize(barW, 5); r.track2:SetColorTexture(1, 1, 1, 0.06)
        r.plan = panel:CreateTexture(nil, "ARTWORK", nil, 1); r.plan:SetPoint("TOPLEFT", r.track2, "TOPLEFT"); r.plan:SetSize(1, 5); r.plan:SetColorTexture(GOLD[1], GOLD[2], 0.2, 0.95)
        r.barW = barW
        panel.rows[row[1]] = r
    end
    panel.legend = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); panel.legend:SetPoint("TOPLEFT", 12, -54 - 4 * 44 + 4)
    panel.legend:SetText("|cff739ed9■|r " .. T("BP_LEG_CUR", "身上实际%") .. "   |cffffd133■|r " .. T("BP_LEG_PLAN", "方案配比"))
    panel.modeLine = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); panel.modeLine:SetPoint("TOPLEFT", panel.legend, "BOTTOMLEFT", 0, -4)
    panel.modeLine:SetPoint("RIGHT", -12, 0); panel.modeLine:SetJustifyH("LEFT")

    panel.ckTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal"); panel.ckTitle:SetPoint("TOPLEFT", 12, -54 - 4 * 44 - 44)
    panel.ckTitle:SetText(T("BP_CK_TITLE", "能不能穿上")); panel.ckTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    panel.ck = {}
    for i = 1, 5 do
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", panel.ckTitle, "BOTTOMLEFT", 0, -8 - (i - 1) * 18); fs:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
        panel.ck[i] = fs
    end
    panel.diff = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); panel.diff:SetPoint("BOTTOMLEFT", 12, 12)
    panel.diff:SetPoint("RIGHT", -12, 0); panel.diff:SetJustifyH("LEFT")

    -- 底部按钮
    local b1 = mkButton(page, 116, T("BP_BTN_DATA", "从数据推荐生成"), function()
        local sd, key2 = specInfo(); if not key2 then return end
        local plan = curPlan(key2) or { stats = { mode = "auto" }, gems = "auto", enchants = "auto", src = "addon" }
        plan.name = plan.name ~= "" and plan.name or L2(PLAN_LABEL[state.editId]); plan.slots = BP.FromData(sd, true)   -- 套装部位带上排名第一的坯子
        BP.Save(key2, state.editId, plan)
    end)
    b1:SetPoint("BOTTOMLEFT", 12, 14)
    local b2 = mkButton(page, 104, T("BP_BTN_EQUIP", "从身上生成"), function()
        local _, key2 = specInfo(); if not key2 then return end
        local plan = curPlan(key2) or { stats = { mode = "auto" }, gems = "auto", enchants = "auto", src = "addon" }
        plan.name = (plan.name and plan.name ~= "") and plan.name or L2(PLAN_LABEL[state.editId]); plan.slots = BP.FromEquipped()
        BP.Save(key2, state.editId, plan)
    end)
    b2:SetPoint("LEFT", b1, "RIGHT", 6, 0)
    local b3 = mkButton(page, 72, T("BP_BTN_IMPORT", "导入"), function() GearInsight:ShowPlanImport() end)
    b3:SetPoint("LEFT", b2, "RIGHT", 6, 0)
    local b4 = mkButton(page, 72, T("BP_BTN_EXPORT", "导出"), function()
        local _, key2 = specInfo(); if not key2 then return end
        local code = BP.ExportPlan(key2, state.editId)
        if not code then GearInsight:Print(T("BP_EXPORT_EMPTY", "这套方案还是空的：先点格子选装备，或「从数据推荐生成」")); return end
        GearInsight:ShowCopyText(BP.ExportURL(code), T("BP_EXPORT_HINT", "Ctrl+C 复制。网站 / 小程序 / 别人的插件都能导入这串（三端通用）。"), T("BP_EXPORT_TITLE", "方案串 · GIB1"))
    end)
    b4:SetPoint("LEFT", b3, "RIGHT", 6, 0)
    local b6 = mkButton(page, 136, T("BP_BTN_FILL", "补齐附魔宝石美化"), function()
        local sd, key2 = specInfo(); if not key2 then return end
        if not curPlan(key2) then
            GearInsight:Print(T("BP_FILL_NEED_PLAN", "请先点「从数据推荐生成」或「从身上生成」建立方案，再补齐附魔、宝石和美化。"))
            return
        end
        local n = BP.Autofill(key2, state.editId, sd, planItems(key2, sd))
        GearInsight:Print(string.format(T("BP_FILL_DONE", "已补齐：%d 处（附魔 / 宝石按顶尖玩家使用率，美化补到 2 件；你已选的不动）"), n or 0))
    end)
    b6:SetScript("OnEnter", function(bb)
        GameTooltip:SetOwner(bb, "ANCHOR_TOP")
        GameTooltip:SetText(T("BP_BTN_FILL_TIP", "只补当前已有方案中的空附魔、宝石和美化；不会自动创建或替换整套装备。美化在制造件上补到 2 件，你已选的内容不动。"), 1, 0.82, 0, 1, true)
        GameTooltip:Show()
    end)
    b6:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local b5 = mkButton(page, 64, T("BP_BTN_CLEAR", "清空"), function()
        local _, key2 = specInfo(); if not key2 then return end
        StaticPopupDialogs["GEARINSIGHT_PLAN_CLEAR"] = StaticPopupDialogs["GEARINSIGHT_PLAN_CLEAR"] or {
            text = T("BP_CLEAR_ASK", "清空「%s」这套方案？\n清空后这套不再生效，插件回到数据推荐。"),
            button1 = T("BP_BTN_CLEAR", "清空"), button2 = CANCEL,
            OnAccept = function(_, data) BP.Delete(data.key2, data.id) end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        local dlg = StaticPopup_Show("GEARINSIGHT_PLAN_CLEAR", L2(PLAN_LABEL[state.editId]))
        if dlg then dlg.data = { key2 = key2, id = state.editId } end
    end)
    b5:SetPoint("LEFT", b4, "RIGHT", 6, 0)
    b6:SetPoint("LEFT", b5, "RIGHT", 6, 0)
    -- “方案串三端通用”没有交互价值，且无论放页脚或顶部都会与右栏/操作提示争位置。
    -- 保留导入、导出按钮及其 tooltip，取消这条常驻文字。
    page.footNote = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.footNote:SetText(""); page.footNote:Hide()

    -- 物品数据异步到了就重画（节流）
    local ev = CreateFrame("Frame", nil, page)
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:SetScript("OnEvent", function()
        if not page:IsShown() or page._pending then return end
        page._pending = true
        C_Timer.After(0.3, function() page._pending = nil; if page:IsShown() then GearInsight:RenderPlanPage() end end)
    end)
    BP.OnChanged = function(changedKey)
        if page:IsShown() then GearInsight:RenderPlanPage() end
        local list = page._savedList
        if list and list:IsShown() and list.Refresh and (not changedKey or list.specKey == changedKey) then
            list.Refresh()
        end
    end
end

function GearInsight:RenderPlanPage()
    local page = self._planPage
    if not (page and page._planBuilt) then return end
    -- 「我的 BiS」固定采用双列装备格 + 右侧属性栏。总览列表模式的刷新可能在
    -- BP.Save 期间发生；这里再次保证主框宽度，防止卡片、右栏及底部按钮按 520 宽重叠。
    local frame = self._panelFrame
    if page:IsShown() and self._mainTabKey == "plan" and frame and frame.SetWidth and frame:GetWidth() < 760 then
        frame:SetWidth(760)
    end
    local sd, key2 = specInfo()
    if not key2 then
        page.specName:SetText(T("BP_NO_SPEC", "读不到当前专精的 BiS 数据"))
        return
    end
    state.editId = state.editId or BP.ActiveId(key2) or "raid"
    local activeId = BP.ActiveId(key2)
    local plan = curPlan(key2)
    local map = plan and BP.SlotMap(plan) or {}
    local picks = dataPicks(sd)

    -- 专精头
    -- ⛔ 别写 `local _, sname, _, sicon = idx and GetSpecializationInfo(idx)`：`x and f()` 只留 f 的第一个返回值，
    --    专精名 / 图标全是 nil → 左上角问号 + 露出内部键「DRUID/GUARDIAN」（09-25 用户截图）
    local idx = GetSpecialization and GetSpecialization()
    local sname, sicon
    if idx then local _; _, sname, _, sicon = GetSpecializationInfo(idx) end
    local clsName, cls = UnitClass("player")
    local cc = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(cls)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls])
    page.specIcon:SetTexture(sicon or 134400)
    page.specName:SetText(sname and ((clsName and (sname .. " · " .. clsName)) or sname) or key2)
    if cc then page.specName:SetTextColor(cc.r, cc.g, cc.b) end

    for _, b in ipairs(page.chips) do
        local p = BP.Get(key2, b._id)
        local filled = p and #(p.slots or {}) > 0
        b.fs:SetText(L2(PLAN_LABEL[b._id]))
        styleChip(b, b._id == state.editId, filled)
        b.dot:SetShown(activeId == b._id)
    end

    local on = activeId == state.editId
    if on then
        page.toggle:SetBackdropColor(0.20, 0.16, 0.04, 0.98); page.toggle:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
        page.toggle.fs:SetText("|cffffd100" .. T("BP_TOGGLE_ON", "● 正在生效 · 点击关闭") .. "|r")
    else
        page.toggle:SetBackdropColor(0.07, 0.07, 0.10, 0.98); page.toggle:SetBackdropBorderColor(0.40, 0.40, 0.45, 1)
        page.toggle.fs:SetText(activeId and T("BP_TOGGLE_SWITCH", "改用这套方案") or T("BP_TOGGLE_OFF", "启用这套方案"))
    end

    -- 16 格
    local nDiff = 0
    local no17 = mainIs2H(sd, map, picks)
    local xItems = planItems(key2, sd)
    local xEnch, xGems, xAutoE, xAutoG = BP.ResolveExtras(plan or { enchants = "auto", gems = "auto" }, sd, xItems)
    for slot, c in pairs(page.cards) do
        local ps = map[slot]
        if slot == 17 and no17 and not ps then
            c._itemId, c._link, c._rand, c._tgtIlvl = nil, nil, nil, nil
            c.slot:SetText(L2(SLOT_NAME[slot]))
            c.icon:SetTexture(134400); c.icon:SetDesaturated(true); c.iconEdge:SetColorTexture(0.25, 0.25, 0.25, 1)
            c.name:SetText("|cff777777" .. T("BP_OH_2H", "双手武器 · 不需要副手") .. "|r")
            c.badge:Hide(); c.src:SetText(""); c.tag:SetText(""); c.ext:SetText(""); c._extLines = nil
            c:SetBackdropBorderColor(0.16, 0.16, 0.20, 1); c:SetBackdropColor(0.06, 0.065, 0.09, 0.96)
        else
        local id = ps and ps.id or picks[slot]
        local entry = id and BP.FindEntry(sd, id)
        c._itemId = id
        c._link = nil
        local explicit = ps and ps.b and #ps.b > 0 and ps.b
        local bon = explicit or (entry and entry.bonusIDs and #entry.bonusIDs > 0 and entry.bonusIDs) or bonusFor(sd, id)
        if id and bon and GearInsight.LinkMid and (explicit or not ps or ps.track == "x") then
            c._link = "item:" .. id .. GearInsight.LinkMid() .. #bon .. ":" .. table.concat(bon, ":")
        end
        c._tgtIlvl = ps and BP.TRACK_MAX[ps.track] or nil
        c._tgtTrack = ps and ps.track or nil
        c.slot:SetText(L2(SLOT_NAME[slot]))
        if id then
            c.icon:SetTexture(itemIcon(id)); c.icon:SetDesaturated(not ps)
            local r, g, b = qualityColor(id, c._link)
            c.name:SetText(itemName(id, entry)); c.name:SetTextColor(ps and r or r * 0.6, ps and g or g * 0.6, ps and b or b * 0.6)
            c.iconEdge:SetColorTexture(r, g, b, ps and 1 or 0.4)
            local tr = ps and ps.track or "x"
            local col = TRACK_COLOR[tr]
            c.badge:SetBackdropColor(col[1] * 0.35, col[2] * 0.35, col[3] * 0.35, 0.95)
            c.badge.txt:SetText(L2(TRACK_LABEL[tr]) .. (BP.TRACK_MAX[tr] and (" " .. BP.TRACK_MAX[tr]) or ""))
            c.badge.txt:SetTextColor(col[1], col[2], col[3])
            c.badge:Show()
            local cf = ps and tonumber(ps.cf)
            if cf and cf > 0 then
                c.src:SetText("|cffb060ff" .. T("BP_FILLER_ON", "坯子：") .. "|r" .. itemName(cf))
            elseif TIER_SLOT[slot] and entry and (entry.isTier or entry.sourceCategory == "tier") then
                local bd0 = GearInsight.BisData or {}
                local mode = (bd0.GetUsageMode and bd0:GetUsageMode()) or "raid"
                local vm = bd0.tierVariants and bd0.tierVariants[key2]
                local vp = vm and (vm[mode] or vm.raid or vm.mplus)
                local vv = vp and vp[id]
                if vv then
                    local sn = vv.stat == "crit" and T("STAT_CRIT", "暴击")
                        or vv.stat == "mastery" and T("STAT_MASTERY", "精通")
                        or vv.stat or ""
                    c.src:SetText("|cffb060ff" .. string.format(
                        T("BP_FILLER_VARIANT", "推荐坯子：%s · 单%s + %s"),
                        vv.name or itemName(vv.itemId), sn, vv.effect or T("TTBIS_TIER_EFFECT", "继承特效")) .. "|r")
                else
                    c.src:SetText(((entry and entry.source) or "") .. "|cff777777 · " .. T("BP_FILLER_PICK", "点格子选坯子") .. "|r")
                end
            else
                c.src:SetText((entry and entry.source) or "")
            end
            local ri = randIdeal(sd, id)
            if ri and not (cf and cf > 0) then
                c.src:SetText("|cff66ccff" .. string.format(T("BP_RAND_IDEAL", "随机属性 · 理想 %s"), ri) .. "|r")
            end
            c._rand = ri
            -- 第三行：附魔 / 宝石 / 美化 / 制造属性（自动的灰色）
            do
                local parts, lines = {}, {}
                local eid = xEnch[slot]
                if eid then
                    local nm = BP.EnchantName(eid)
                    parts[#parts + 1] = ico(BP.EnchantIcon(eid), 13) .. (xAutoE[slot] and ("|cff8a93a6" .. nm .. "|r") or ("|cff9ee7ff" .. nm .. "|r"))
                    lines[#lines + 1] = T("BP_TT_ENCH", "附魔：") .. nm .. (xAutoE[slot] and (" " .. T("BP_AUTO_TAG", "（自动）")) or "")
                elseif BP.CanEnchant(slot, id) then
                    parts[#parts + 1] = "|cffff6060" .. T("BP_NO_ENCH", "未附魔") .. "|r"
                    lines[#lines + 1] = "|cffff6060" .. T("BP_TT_NO_ENCH", "这一格没选附魔") .. "|r"
                end
                local gl = xGems[slot]
                if gl and #gl > 0 then
                    local gi, gn = {}, {}
                    for _, g in ipairs(gl) do gi[#gi + 1] = ico(BP.GemIcon(g), 13); gn[#gn + 1] = BP.GemName(g) end
                    parts[#parts + 1] = table.concat(gi, "")
                    lines[#lines + 1] = T("BP_TT_GEM", "宝石：") .. table.concat(gn, " / ") .. (xAutoG[slot] and (" " .. T("BP_AUTO_TAG", "（自动）")) or "")
                end
                local em = ps and tonumber(ps.em)
                if em and em > 0 then
                    parts[#parts + 1] = ico(BP.EmIcon(em), 13) .. "|cffffb040" .. BP.EmName(em) .. "|r"
                    lines[#lines + 1] = "|cffffb040" .. T("BP_TT_EM", "美化：") .. BP.EmName(em) .. "|r"
                    local d = BP.EmDesc(em)
                    if d then lines[#lines + 1] = "|cff9aa0aa" .. d .. "|r" end
                end
                if ps and ps.cs and #ps.cs >= 2 then
                    lines[#lines + 1] = T("BP_TT_CS", "制造属性：") .. L2(STAT_LBL[ps.cs[1]] or { "", ps.cs[1] }) .. " / " .. L2(STAT_LBL[ps.cs[2]] or { "", ps.cs[2] })
                end
                c.ext:SetText(table.concat(parts, "  "))
                c._extLines = (#lines > 0) and lines or nil
            end
        else
            c.icon:SetTexture(134400); c.icon:SetDesaturated(true)
            c.name:SetText("|cff666666" .. T("BP_EMPTY", "（空）") .. "|r"); c.iconEdge:SetColorTexture(0.25, 0.25, 0.25, 1)
            c.badge:Hide(); c.src:SetText(""); c.ext:SetText(""); c._extLines = nil
        end
        if ps and picks[slot] ~= ps.id then
            nDiff = nDiff + 1
            c.tag:SetText(T("BP_TAG_MINE", "自选")); c.tag:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        elseif ps then
            c.tag:SetText(T("BP_TAG_SAME", "同数据")); c.tag:SetTextColor(0.5, 0.52, 0.58)
        else
            c.tag:SetText(T("BP_TAG_DATA", "数据推荐")); c.tag:SetTextColor(0.42, 0.44, 0.5)
        end
        if state.selected == slot then
            c:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1); c:SetBackdropColor(0.12, 0.10, 0.05, 0.98)
        else
            c:SetBackdropBorderColor(ps and 0.30 or 0.16, ps and 0.27 or 0.16, ps and 0.16 or 0.20, 1); c:SetBackdropColor(0.06, 0.065, 0.09, 0.96)
        end
        end   -- 双手主手时的副手格
    end

    -- 属性
    local panel = page.panel
    local cur, curRaw, curShown = currentShares()
    -- 这里展示“选中装备实际副属性占比”，不能把导入的属性目标权重当成装备结果。
    -- 已缓存的条目先显示，未缓存条目由 GET_ITEM_INFO_RECEIVED 异步补齐，避免整栏暂时变空。
    local planPct, planComplete, planRaw = plan and BP.ComputeStatPercents(plan, sd)
    -- “从身上生成”且尚未换件时，右侧应严格复用角色面板实时评级，不能再从物品模板反推。
    local sameEquipped = curRaw and sameAsEquipped(plan)
    if sameEquipped then planRaw = curRaw; planPct = cur end
    for _, row in ipairs(STAT_ROWS) do
        local k, r = row[1], panel.rows[row[1]]
        local a, b = cur and cur[k], planPct and planPct[k]
        -- 占比很少过半：按 60% 撑满整条，差异看得清
        r.cur:SetWidth(math.max(1, math.min(r.barW, (a or 0) / 60 * r.barW)))
        r.plan:SetWidth(math.max(1, math.min(r.barW, (b or 0) / 60 * r.barW)))
        local arrow = ""
        if a and b then
            if b - a > 1.5 then arrow = " |cff4cd964▲|r" elseif a - b > 1.5 then arrow = " |cffff5f57▼|r" end
        end
        -- 当前穿戴的百分比必须与角色面板一致；从身上生成且没换件时方案侧也复用它。
        local shownA = curShown and curShown[k] or a
        local shownB = sameEquipped and shownA or b
        local left = shownA and string.format("%.2f%%", shownA) or "—"
        local right = shownB and string.format("|cffffd133%.2f%%|r", shownB) or "—"
        r.val:SetText(string.format("%s → %s%s", left, right, arrow))
    end
    local mode = plan and plan.stats and plan.stats.mode or "auto"
    local MODE_TXT = { auto = T("BP_MODE_AUTO", "目标 = 方案各件副属性的占比（自动）"), p = T("BP_MODE_P", "目标 = 导入的属性优先级"),
                       w = T("BP_MODE_W", "目标 = 导入的属性权重"), t = T("BP_MODE_T", "目标 = 方案各件副属性占比（导入的阈值另行显示）") }
    panel.modeLine:SetText(sameEquipped and "|cff8a93a6身上与方案相同：均为角色面板实际%|r" or "|cff8a93a6方案配比按装备绿字计算|r")

    local ck = checks(sd, plan)
    for i, fs in ipairs(panel.ck) do
        local c = ck[i]
        if c then
            local mark = c.dim and "|cff8a93a6·|r " or (c.ok and "|cff4cd964|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t|r " or "|cffff9f0a!|r ")
            fs:SetText(mark .. c.text); fs:Show()
        else fs:Hide() end
    end
    panel.diff:SetText(plan and string.format(T("BP_DIFF", "与数据推荐不同：|cffffd133%d|r 格"), nDiff) or T("BP_DIFF_NONE", "这套方案还是空的"))
end

function GearInsight:BuildPlanPage(page)
    if not (page and BP) then return end
    self._planPage = page
    build(page)
    -- BP.Changed 会走总览刷新；此外设置/数据刷新也可能在本页显示期间改主框宽度。
    -- 只在 Render 时补救会留下一个帧的 520 宽外溢，直接守住尺寸变更。
    local frame = self._panelFrame
    if frame and frame.HookScript and not page._planWidthGuard then
        page._planWidthGuard = true
        frame:HookScript("OnSizeChanged", function(f, w)
            if GearInsight._mainTabKey ~= "plan" or w >= 760 or f._giPlanRestoring then return end
            f._giPlanRestoring = true
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    f._giPlanRestoring = nil
                    if GearInsight._mainTabKey == "plan" and f:GetWidth() < 760 then f:SetWidth(760) end
                end)
            else
                f._giPlanRestoring = nil; f:SetWidth(760)
            end
        end)
    end
    self:RenderPlanPage()
end

-- ── 导入框 ───────────────────────────────────────────────────────────
function GearInsight:ShowPlanImport()
    local f = self._planImport
    if not f then
        f = CreateFrame("Frame", "GearInsightPlanImport", UIParent, "BackdropTemplate")
        f:SetSize(520, 230); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); f:SetMovable(true)
        f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20,
                        insets = { left = 5, right = 5, top = 5, bottom = 5 } })
        f:SetBackdropColor(0.03, 0.035, 0.05, 0.98)
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); t:SetPoint("TOPLEFT", 18, -16)
        t:SetText(T("BP_IMPORT_TITLE", "导入方案串")); t:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
        sub:SetText(T("BP_IMPORT_SUB", "粘贴 GIB1 开头的串或整条链接（网站 / 小程序 / 别人的插件导出的都行）"))
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 18, -60); sf:SetPoint("BOTTOMRIGHT", -38, 70)
        local bg = f:CreateTexture(nil, "BACKGROUND", nil, 2); bg:SetPoint("TOPLEFT", sf, -4, 4); bg:SetPoint("BOTTOMRIGHT", sf, 24, -4); bg:SetColorTexture(0, 0, 0, 0.5)
        local eb = CreateFrame("EditBox", nil, sf); eb:SetMultiLine(true); eb:SetFontObject("ChatFontNormal"); eb:SetWidth(440)
        eb:SetAutoFocus(true); eb:SetMaxLetters(0); eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb); f.eb = eb
        f.err = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.err:SetPoint("BOTTOMLEFT", 18, 46); f.err:SetPoint("RIGHT", -18, 0)
        f.err:SetJustifyH("LEFT"); f.err:SetTextColor(1, 0.45, 0.35)
        local ok = mkButton(f, 110, T("BP_BTN_IMPORT", "导入"), function()
            local key2, id = BP.Import(f.eb:GetText(), nil)
            if not key2 then
                local code = id
                f.err:SetText(code == "spec" and T("BP_E_SPEC", "这个方案的专精插件里没有数据") or BP.ErrorText(code))
                return
            end
            f:Hide()
            local _, myKey = specInfo()
            state.editId = id
            if key2 ~= myKey then
                GearInsight:Print(string.format(T("BP_IMPORT_OTHER", "已导入到「%s」的「%s」方案（不是你当前专精，切过去才会看到）。"), GearInsight.SpecKeyLabel and GearInsight.SpecKeyLabel(key2) or key2, L2(PLAN_LABEL[id])))
            else
                GearInsight:Print(string.format(T("BP_IMPORT_OK", "已导入到「%s」方案，点上方开关即可启用。"), L2(PLAN_LABEL[id])))
            end
            GearInsight:RenderPlanPage()
        end)
        ok:SetPoint("BOTTOMRIGHT", -130, 14)
        local cancel = mkButton(f, 100, CANCEL or "Cancel", function() f:Hide() end)
        cancel:SetPoint("LEFT", ok, "RIGHT", 8, 0)
        tinsert(UISpecialFrames, "GearInsightPlanImport")
        self._planImport = f
    end
    f.err:SetText(""); f.eb:SetText(""); f:Show(); f.eb:SetFocus()
end

-- ── Shift+点击物品链接 → 放进选中的格子（方案页开着时）─────────────
if hooksecurefunc and HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        local page = GearInsight._planPage
        if not (page and page:IsShown() and state.selected and link and IsModifiedClick and IsModifiedClick("CHATLINK")) then return end
        local id = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(link)
        if id then dropItem(id, link) end
    end)
end

