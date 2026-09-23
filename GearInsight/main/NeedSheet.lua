-- GearInsight/main/NeedSheet.lua — 拾取需求单
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, TSite, locName, localizedSource = H.T, H.TSite, H.locName, H.localizedSource
local _msOwnedSet, _msSpecName = H._msOwnedSet, H._msSpecName

-- ── 拾取需求单（Loot Wishlist）────────────────────────────────────────
-- 进团前把需求一次说清：每个 BOSS 该设的专精拾取、要的装备、掷币（晦暗虚空核心，
-- 2 个 = 1 次额外拾取 roll）优先丢哪个 BOSS（BiS饰品 > 戒指/项链 > 其他按装等提升），
-- M1–M10 全列（含无需求 BOSS），生成纯文本发给团长/队友。/gi need
-- 复用 GetCrossSpecFarmPlan 的多专精合并与 ilvl-aware 归属判定（与多专精窗口同口径）。
-- 注意：对外文案（含本注释外的所有 UI 字符串）不得出现 boost/代练 等字样。

-- M1–M10 击杀顺序按副本分段（与 _msRender 的 RAID_BOSS_ORDER 一致）
-- ⛔⛔ 这两张表原来手写的是 S1（虚影尖塔/梦境裂隙/进军奎尔萨纳斯/孢陨幽境），换季没人改 →
--    需求单 S2 还在列 S1 的 BOSS（用户 2026-09-12 截图「这里没更新到这个赛季」）。
--    现在从数据侧 BisData.raidBossOrder（generate_bisdata_lua 按 boss_order.json 算）取 M 序，
--    实例 id 走 EJ_GetEncounterInfo 第 6 个返回值（journalInstanceID），按 M 序把连续同实例的 BOSS 归成一段。
--    手写表只做 BisData 缺席时的兜底。
local NEED_BOSS_ORDER_FALLBACK = { [2733]=1, [2734]=2, [2736]=3, [2735]=4, [2737]=5,
                                   [2738]=6, [2795]=7, [2739]=8, [2740]=9, [2711]=10 }
local function _needBossOrder()
    local bo = GearInsight.BisData and GearInsight.BisData.raidBossOrder
    if type(bo) == "table" and next(bo) then return bo end
    return NEED_BOSS_ORDER_FALLBACK
end
local function _needRaidPlan(order)
    local eids = {}
    for eid in pairs(order) do eids[#eids + 1] = eid end
    table.sort(eids, function(a, b) return (order[a] or 99) < (order[b] or 99) end)
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
    local plan, cur = {}, nil
    for _, eid in ipairs(eids) do
        local inst
        if EJ_GetEncounterInfo then
            local ok, _, _, _, _, _, jid = pcall(EJ_GetEncounterInfo, eid)
            if ok and jid and jid > 0 then inst = jid end
        end
        inst = inst or (cur and cur.instanceId) or 0
        if not cur or cur.instanceId ~= inst then
            cur = { instanceId = inst, encounters = {} }
            plan[#plan + 1] = cur
        end
        cur.encounters[#cur.encounters + 1] = eid
    end
    return plan
end

local function _needEncName(eid)
    if EJ_GetEncounterInfo then
        local n = EJ_GetEncounterInfo(eid)
        if n and n ~= "" then return n end
    end
    return "BOSS#" .. eid
end

local function _needInstName(iid)
    if EJ_GetInstanceInfo then
        local n = EJ_GetInstanceInfo(iid)
        if n and n ~= "" then return n end
    end
    return "#" .. iid
end

-- 晦暗虚空核心（额外拾取掷币）：2 个 = 在一个 BOSS 上多 roll 一次拾取。
-- wago CurrencyTypes 里同名两条（3418/3513），运行时探测取有效的那条。
local NEED_COIN_IDS = { 3418, 3513 }
local function _needCoinCount()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local fallback
    for _, id in ipairs(NEED_COIN_IDS) do
        local ok, ci = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok and ci and ci.name and ci.name ~= "" then
            if (ci.quantity or 0) > 0 then return ci.quantity, ci.name end
            if not fallback then fallback = { ci.quantity or 0, ci.name } end
        end
    end
    if fallback then return fallback[1], fallback[2] end
    return nil
end

function GearInsight:BuildNeedSheet()
    local st = self.StatReader and self.StatReader:ReadAll()
    local class = st and st.class and st.class:upper()
    if not class then return nil end

    -- 专精范围：沿用多专精拾取窗口的勾选；没勾过 → 当前专精
    local selected, list = self:_msSelected(), {}
    for sn, on in pairs(selected) do if on then list[#list + 1] = sn end end
    if #list == 0 and st.spec then list[1] = st.spec:upper() end
    if #list == 0 then return nil end
    table.sort(list)

    -- ownership 判定与多专精窗口完全一致（装备中的同款未到 BiS 装等 → 仍算缺）
    local owned = _msOwnedSet()
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    local equippedBySlot = {}
    if snap and snap.equipped then
        for sid, eq in pairs(snap.equipped) do
            if type(eq) == "table" and not eq.empty then equippedBySlot[eq.slotId or sid] = eq end
        end
    end
    local function isOwned(id, wantIlvl, slotId)
        if not owned[id] then return false end
        local eq = slotId and equippedBySlot[slotId]
        if eq and eq.itemId == id then return (eq.ilvl or 0) >= (wantIlvl or 0) end
        return true
    end

    local plan = self.BisData and self.BisData:GetCrossSpecFarmPlan(class, list, isOwned)
    if not plan then return nil end

    local L = self.L or {}
    local gr = self.GearReader
    local function slotLabel(slotId)
        local k = gr and gr:GetSlotKey(slotId)
        return (k and L[k]) or (T("NEED_SLOT", "槽") .. tostring(slotId or "?"))
    end

    -- 团本组按 encounterId 索引；团本地区掉落（小怪，无 encounterId）按 instanceId
    -- 单独成行；其余非团本来源（含套装转换）→ 备注
    local multi = #list > 1
    local byEnc, byInstTrash, offRaid = {}, {}, {}
    local function mergeWants(ent, g)
        for _, w in ipairs(g.wants) do
            if not w.owned then
                local id = w.item.itemId
                local e = ent.byItem[id]
                if not e then
                    e = { item = w.item, slotId = w.slotId, specs = {}, _set = {} }
                    ent.byItem[id] = e; ent.order[#ent.order + 1] = id
                end
                for _, u in ipairs(w.usedBy or { { name = w.specName, id = w.specId } }) do
                    if not e._set[u.name] then
                        e._set[u.name] = true
                        e.specs[#e.specs + 1] = _msSpecName(u.id, u.name)
                    end
                end
            end
        end
    end
    for _, g in pairs(plan) do
        local hasMiss = false
        for _, w in ipairs(g.wants) do if not w.owned then hasMiss = true break end end
        if hasMiss then
            if g.encounterId then
                local ent = byEnc[g.encounterId]
                if not ent then ent = { g = g, byItem = {}, order = {} }; byEnc[g.encounterId] = ent end
                mergeWants(ent, g)
            elseif g.instanceId and g.category == "raid" then
                local ent = byInstTrash[g.instanceId]
                if not ent then ent = { g = g, byItem = {}, order = {} }; byInstTrash[g.instanceId] = ent end
                mergeWants(ent, g)
            else
                for _, w in ipairs(g.wants) do
                    if not w.owned then
                        offRaid[#offRaid + 1] = string.format("- %s(%s) · %s",
                            locName(w.item.itemId, w.item.itemNameCn or w.item.itemName) or ("#" .. w.item.itemId),
                            slotLabel(w.slotId),
                            (g.sourceName ~= "" and localizedSource(g.sourceName, g.instanceId, g.encounterId))
                                or T("NEED_SRC_OTHER", "其他来源"))
                    end
                end
            end
        end
    end

    -- ROLL币(晦暗虚空核心)推荐：按 BiS饰品 > 戒指/项链 > 其他部位(按装等提升)
    -- 给有需求的 BOSS 排掷币优先级，把当前可用次数(数量÷2)指到具体 BOSS。
    local coinQty, coinName = _needCoinCount()
    local NEED_BOSS_ORDER = _needBossOrder()
    local NEED_RAID_PLAN = _needRaidPlan(NEED_BOSS_ORDER)
    local rollRank = {}
    for eid, ent in pairs(byEnc) do
        local best
        for _, id in ipairs(ent.order) do
            local e = ent.byItem[id]
            local s = e.slotId or 0
            local prio = (s == 13 or s == 14) and 1
                or ((s == 11 or s == 12 or s == 2) and 2 or 3)
            local cur = equippedBySlot[s]
            local delta = (e.item.ilvl or 0) - ((cur and cur.ilvl) or 0)
            if not best or prio < best.prio
                or (prio == best.prio and delta > best.delta) then
                best = { prio = prio, delta = delta,
                         label = locName(id, e.item.itemNameCn or e.item.itemName) or ("#" .. id) }
            end
        end
        if best then
            rollRank[#rollRank + 1] = { eid = eid, prio = best.prio,
                                        delta = best.delta, label = best.label }
        end
    end
    table.sort(rollRank, function(a, b)
        if a.prio ~= b.prio then return a.prio < b.prio end
        if a.delta ~= b.delta then return a.delta > b.delta end
        return (NEED_BOSS_ORDER[a.eid] or 99) < (NEED_BOSS_ORDER[b.eid] or 99)   -- NEED_BOSS_ORDER = 本次动态表（见下）
    end)
    local rolls = coinQty and math.floor(coinQty / 2) or 0
    local rollAt = {}
    for i, r in ipairs(rollRank) do
        if i <= rolls then rollAt[r.eid] = i end
    end

    -- 表头
    local name = UnitName("player") or "?"
    local realm = (GetRealmName and GetRealmName() or ""):gsub("%s+", "")
    local classLoc = UnitClass and (select(1, UnitClass("player"))) or class
    local ilvl = 0
    do
        -- ⛔ 同一个坑，第二处（见 _RefreshPanelImpl 里那条注释）：升级轨道原地涨装等不触发
        -- SavedVars:Save() 挂的事件，旧 snapshot 的 eq.ilvl 跟着停在升级前。现取一份。
        local snap = self.SavedVars and self.SavedVars:Save()
        local sum, n = 0, 0
        if snap and snap.equipped then
            for _, eq in pairs(snap.equipped) do
                if type(eq) == "table" and not eq.empty and (eq.ilvl or 0) > 0 and eq.slotId ~= 4 and eq.slotId ~= 19 then
                    sum, n = sum + eq.ilvl, n + 1
                end
            end
        end
        if n >= 8 then ilvl = math.floor(sum / n + 0.5)
        elseif GetAverageItemLevel then local _, eq = GetAverageItemLevel(); ilvl = math.floor(eq or 0) end
    end
    local specNames = {}
    for _, sn in ipairs(list) do specNames[#specNames + 1] = _msSpecName(nil, sn) end

    local out = {}
    local function add(s) out[#out + 1] = s end
    add(string.format(T("NEED_HEADER", "【团本拾取需求单】%s-%s %s 装等%d"),
        name, realm, classLoc or class, ilvl))
    add(string.format(T("NEED_SPECLINE", "专精: %s | 难度: 史诗/英雄/普通(按所打难度保留)"),
        table.concat(specNames, "/")))
    if GearInsightDB and GearInsightDB.excludeRaid then
        add(T("NEED_NORAID_WARN", "※ 当前开启了「团本排除」，团本需求未列出——/gi noraid off 后重新生成"))
    end
    add("")

    local needCount = 0
    for _, seg in ipairs(NEED_RAID_PLAN) do
        add("◆ " .. _needInstName(seg.instanceId))
        local tr = byInstTrash[seg.instanceId]
        if tr then
            local lootSpec = _msSpecName(tr.g.recommendSpecId, tr.g.recommendSpec)
            local items = {}
            for _, id in ipairs(tr.order) do
                local e = tr.byItem[id]
                local nm = locName(id, e.item.itemNameCn or e.item.itemName) or ("#" .. id)
                local tag = slotLabel(e.slotId)
                if multi and #e.specs > 0 then tag = tag .. "," .. table.concat(e.specs, "/") end
                items[#items + 1] = string.format("%s(%s)", nm, tag)
                needCount = needCount + 1
            end
            add(string.format("%s | %s%s | %s%s",
                T("NEED_TRASH", "小怪(全程地区掉落)"),
                T("NEED_LOOTSET", "拾取设置:"), lootSpec,
                T("NEED_ITEMS", "需求: "), table.concat(items, "、")))
        end
        for _, eid in ipairs(seg.encounters) do
            local mOrd = NEED_BOSS_ORDER[eid] or 0
            local ent = byEnc[eid]
            local parts = {}
            if ent then
                local lootSpec = _msSpecName(ent.g.recommendSpecId, ent.g.recommendSpec)
                parts[#parts + 1] = T("NEED_LOOTSET", "拾取设置:") .. lootSpec
                local items = {}
                for _, id in ipairs(ent.order) do
                    local e = ent.byItem[id]
                    local nm = locName(id, e.item.itemNameCn or e.item.itemName) or ("#" .. id)
                    local tag = slotLabel(e.slotId)
                    if multi and #e.specs > 0 then tag = tag .. "," .. table.concat(e.specs, "/") end
                    items[#items + 1] = string.format("%s(%s)", nm, tag)
                    needCount = needCount + 1
                end
                parts[#parts + 1] = T("NEED_ITEMS", "需求: ") .. table.concat(items, "、")
            end
            if rollAt[eid] then
                parts[#parts + 1] = string.format(T("NEED_ROLLAT", "★ROLL币第%d优先"), rollAt[eid])
            end
            if #parts == 0 then parts[1] = T("NEED_FREE", "自由分配,无需求") end
            add(string.format("M%d %s | %s", mOrd, _needEncName(eid), table.concat(parts, " | ")))
        end
    end

    add("")
    add("————")
    add(string.format(T("NEED_TOTAL", "合计: 需求装备%d件"), needCount))
    if #rollRank > 0 then
        if coinQty then
            add(string.format(T("NEED_COIN_HAVE", "ROLL币(%s): 现有%d个 = 可额外掷%d次"),
                coinName or T("NEED_COIN_NAME", "晦暗虚空核心"), coinQty, rolls))
        else
            add(T("NEED_COIN_UNKNOWN", "ROLL币(晦暗虚空核心): 数量未读到,按下列顺序使用"))
        end
        local seq = {}
        for i, r in ipairs(rollRank) do
            if i > 4 then break end
            seq[#seq + 1] = string.format("%d.M%d(%s)", i, NEED_BOSS_ORDER[r.eid] or 0, r.label)
        end
        add(T("NEED_COIN_ORDER", "掷币优先: ") .. table.concat(seq, "  "))
    end
    if needCount > 0 then
        add(T("NEED_REMIND", "打前提醒: 有拾取设置的BOSS,开打前先切专精拾取(拾取选项→专精拾取)"))
    end
    if #offRaid > 0 then
        add(T("NEED_OFFRAID", "本团本拿不到,另行安排:"))
        for i, line in ipairs(offRaid) do
            if i > 8 then add(string.format(T("NEED_OFFRAID_MORE", "- (等%d件,见插件刷本优先级)"), #offRaid - 8)) break end
            add(line)
        end
    end
    add(TSite("NEED_FOOTER", "—— GearInsight 生成 · gearinsight.app"))
    return table.concat(out, "\n")
end

function GearInsight:ShowNeedSheet()
    local str = self:BuildNeedSheet()
    if not str then
        self:Print(T("NEED_NODATA", "无法生成需求单：请先打开面板或 /gi refresh 刷新装备数据"))
        return
    end

    local dimmer = CreateFrame("Frame", nil, UIParent)
    dimmer:SetAllPoints()
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    dimmer:EnableMouse(true)
    local dbg = dimmer:CreateTexture(nil, "BACKGROUND")
    dbg:SetAllPoints()
    dbg:SetColorTexture(0, 0, 0, 0.6)
    dimmer:SetScript("OnMouseDown", function(d) d:Hide() end)
    self:RegisterEscClose(dimmer, "GearInsightNeedDimmer")

    local box = CreateFrame("Frame", nil, dimmer, "BackdropTemplate")
    box:SetSize(560, 520)
    box:SetPoint("CENTER")
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", nil)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    box:SetBackdropColor(0.08, 0.08, 0.12, 0.97)
    box:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.9)

    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(T("NEED_TITLE", "拾取需求单 · 发给团长/队友"))

    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -8)
    hint:SetWidth(520)
    hint:SetJustifyH("CENTER")
    hint:SetText(T("NEED_HINT", "Ctrl+C 复制；可先在框内直接编辑（删难度、改措辞）再复制。专精范围跟随「多专精拾取」勾选。"))
    hint:SetTextColor(0.7, 0.7, 0.7)

    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -62)
    sf:SetPoint("BOTTOMRIGHT", -34, 50)
    local edit = CreateFrame("EditBox", nil, sf)
    edit:SetMultiLine(true)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetWidth(496)
    edit:SetAutoFocus(true)
    edit:SetText(str)
    edit:HighlightText()
    edit:SetScript("OnEscapePressed", function() dimmer:Hide() end)
    sf:SetScrollChild(edit)

    local closeBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetText(T("CLOSE_SHORT", "关闭"))
    closeBtn:SetScript("OnClick", function() dimmer:Hide() end)
    if GearInsight.Skin then GearInsight.Skin.Sweep(dimmer) end
end

-- 使用率参考系：团本 / 大秘境。换算 BisData 内候选并刷新已开界面。
