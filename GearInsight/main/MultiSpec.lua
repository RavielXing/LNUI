-- GearInsight/main/MultiSpec.lua — 多专精刷本规划
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, locName, localizedSource, _openSourceJournal = H.T, H.locName, H.localizedSource, H.openSourceJournal

-- ── Multi-spec farming planner ──────────────────────────────────────
-- Owned = equipped + bags (so off-spec items you already have don't show up).
local function _msOwnedSet()
    local owned = {}
    for slot = 1, 18 do
        local id = GetInventoryItemID and GetInventoryItemID("player", slot)
        if id then owned[id] = true end
    end
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 5 do
            local n = C_Container.GetContainerNumSlots(bag) or 0
            for s = 1, n do
                local info = C_Container.GetContainerItemInfo(bag, s)
                if info and info.itemID then owned[info.itemID] = true end
            end
        end
    end
    return owned
end

-- Localized display names for internal spec codes the spec-ID API can't name yet
-- (e.g. brand-new 12.0 specs: GetSpecializationInfoByID returns empty off the active spec).
local SPEC_CODE_DISPLAY = {
    DEVAURER = T("SPEC_DEVAURER", "噬灭"),
}
local function _msSpecName(specId, fallback)
    if specId and GetSpecializationInfoByID then
        local _, nm = GetSpecializationInfoByID(specId)
        if nm and nm ~= "" then return nm end
    end
    -- specId 缺失/查不到时 fallback 是 HAVOC 这类内部大写码，不能直接示人：
    -- 先借 specIds 反查客户端本地化名（任意语言客户端都正确），再退 specRawToCN
    local raw = fallback or ""
    if SPEC_CODE_DISPLAY[raw] then return SPEC_CODE_DISPLAY[raw] end
    local bd = GearInsight.BisData
    if bd and bd.specIds and GetSpecializationInfoByID then
        local class = select(2, UnitClass("player")) or ""
        local sid = bd.specIds[class .. "/" .. raw]
        if sid then
            local ok, _, nm = pcall(GetSpecializationInfoByID, sid)
            if ok and nm and nm ~= "" then return nm end
        end
    end
    if bd and bd.specRawToCN and bd.specRawToCN[raw] then return bd.specRawToCN[raw] end
    return fallback or "?"
end

GearInsight._msSpecNameFn = _msSpecName
local function _msCurrentLootSpec()
    local ls = GetLootSpecialization and GetLootSpecialization() or 0
    if ls and ls > 0 then return ls end
    if GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then return (GetSpecializationInfo(idx)) end
    end
    return nil
end

function GearInsight:_msSelected()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.multiSpec = GearInsightDB.multiSpec or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
    GearInsightDB.multiSpec[key] = GearInsightDB.multiSpec[key] or {}
    return GearInsightDB.multiSpec[key]
end

function GearInsight:_msRender()
    local sc = self._msScrollChild
    if not sc then return end
    sc.lines = sc.lines or {}
    sc.btns = sc.btns or {}
    sc.itemRows = sc.itemRows or {}
    for _, fs in ipairs(sc.lines) do fs:Hide() end
    for _, b in ipairs(sc.btns) do b:Hide() end
    for _, r in ipairs(sc.itemRows) do r:Hide() end
    local lineN, btnN, itemN = 0, 0, 0
    local y = -2
    local L = self.L or {}

    local function addLine(text, indent, r, g, b)
        lineN = lineN + 1
        local fs = sc.lines[lineN]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetJustifyH("LEFT")
            sc.lines[lineN] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", indent or 0, y)
        fs:SetWidth(505 - (indent or 0))
        fs:SetText(text)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:Show()
        y = y - 18
        return fs
    end

    -- Item row: icon + text, hover for tooltip, click opens the Adventure Guide.
    local function addItemRow(text, e, r, g, b)
        itemN = itemN + 1
        local row = sc.itemRows[itemN]
        if not row then
            row = CreateFrame("Button", nil, sc)
            row:SetHeight(18)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(16, 16); row.icon:SetPoint("LEFT", 2, 0)
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.txt:SetPoint("LEFT", row.icon, "RIGHT", 4, 0); row.txt:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(s2)
                if not s2._itemId then return end
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                if s2._link then GameTooltip:SetHyperlink(s2._link) else GameTooltip:SetItemByID(s2._itemId) end
                if s2._instId then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cFFAAAAAA" .. T("MS_CLICK_JOURNAL", "点击打开冒险指南") .. "|r", 0.7, 0.7, 0.7)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnClick", function(s2) _openSourceJournal(s2._instId, s2._bossId, s2._itemId, s2._isRaid) end)
            sc.itemRows[itemN] = row
        end
        local it = e.item or {}
        row._itemId = it.itemId; row._instId = it.instanceId; row._bossId = it.encounterId
        row._isRaid = e._isRaid
        if it.link then
            row._link = it.link
        elseif it.bonusIDs and #it.bonusIDs > 0 then
            row._link = "|Hitem:" .. it.itemId .. GearInsight.LinkMid() .. #it.bonusIDs .. ":" .. table.concat(it.bonusIDs, ":") .. "|h[item]|h"
        else
            row._link = nil
        end
        local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.itemId)
        row.icon:SetTexture(icon or 134400)
        if not icon and Item and Item.CreateFromItemID then
            local iid = it.itemId
            local itm = Item:CreateFromItemID(iid)
            itm:ContinueOnItemLoad(function()
                if row._itemId == iid then row.icon:SetTexture(itm:GetItemIcon() or 134400) end
            end)
        end
        row.txt:SetText(text)
        row.txt:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10, y)
        row:SetPoint("RIGHT", sc, "RIGHT", -4, 0)
        row:Show()
        y = y - 18
        return row
    end

    local selected = self:_msSelected()
    local list = {}
    for sn, on in pairs(selected) do if on then list[#list + 1] = sn end end
    if #list == 0 then
        addLine(T("MS_PICK_HINT", "请在上方勾选你想一起刷的专精"), 4, 0.7, 0.7, 0.7)
        sc:SetHeight(40); return
    end

    local owned = _msOwnedSet()
    -- ilvl-aware ownership: if the item you own is the one equipped in this slot, it only
    -- counts as "done" when it meets the BiS ilvl — otherwise (e.g. a 套装件 below the
    -- target ilvl needing a higher 坯子) it stays a want, matching the single-spec view.
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    local equippedBySlot = {}
    if snap and snap.equipped then
        for sid, eq in pairs(snap.equipped) do
            if type(eq) == "table" and not eq.empty then
                equippedBySlot[eq.slotId or sid] = eq
            end
        end
    end
    local function isOwned(id, wantIlvl, slotId)
        if not owned[id] then return false end
        local eq = slotId and equippedBySlot[slotId]
        if eq and eq.itemId == id then
            return (eq.ilvl or 0) >= (wantIlvl or 0)
        end
        return true
    end
    local plan = self.BisData and self.BisData:GetCrossSpecFarmPlan(self._msClass, list, isOwned)
    if not plan then addLine(T("MS_NODATA", "暂无数据"), 4, 0.7, 0.7, 0.7); sc:SetHeight(40); return end

    local arr = {}
    for _, g in pairs(plan) do if (g.missingCount or 0) > 0 then arr[#arr + 1] = g end end
    table.sort(arr, function(a, b) return (a.missingCount or 0) > (b.missingCount or 0) end)
    if #arr == 0 then
        addLine(T("MS_ALL_DONE", "所选专精在当前数据下都已毕业"), 4, 0.4, 1, 0.4)
        sc:SetHeight(40); return
    end

    local curLoot = _msCurrentLootSpec()

    -- Consolidate each boss's unowned wants by item; an item several selected
    -- specs want is merged into one line and flagged "多专精通用".
    local view = {}
    for _, g in ipairs(arr) do
        local byItem, order = {}, {}
        for _, w in ipairs(g.wants) do
            if not w.owned then
                local id = w.item.itemId
                if not byItem[id] then
                    local e = { item = w.item, slotId = w.slotId, specs = {} }
                    for _, u in ipairs(w.usedBy or {}) do
                        e.specs[#e.specs + 1] = _msSpecName(u.id, u.name)
                    end
                    if #e.specs == 0 then e.specs[1] = _msSpecName(w.specId, w.specName) end
                    byItem[id] = e; order[#order + 1] = id
                end
            end
        end
        if #order > 0 then
            view[#view + 1] = { g = g, order = order, byItem = byItem, missing = #order }
        end
    end
    -- Bosses/dungeons first (by missing count), 制造业/套装转换 pushed to the end.
    local CAT_RANK = { raid = 1, mplus = 2, world = 3, crafted = 4, tier = 5 }
    table.sort(view, function(a, b)
        local ra, rb = CAT_RANK[a.g.category] or 6, CAT_RANK[b.g.category] or 6
        if ra ~= rb then return ra < rb end
        return a.missing > b.missing
    end)

    for _, v in ipairs(view) do
        local g = v.g
        local recName = _msSpecName(g.recommendSpecId, g.recommendSpec)
        local RAID_BOSS_ORDER = { [2733]=1,[2734]=2,[2736]=3,[2735]=4,[2737]=5,[2738]=6,[2795]=7,[2739]=8,[2740]=9,[2711]=10 }
        local _msOrd = g.encounterId and RAID_BOSS_ORDER[g.encounterId]
        local _msName = (g.sourceName ~= "" and localizedSource(g.sourceName, g.instanceId, g.encounterId))
            or T("MS_OTHER", "其他来源")
        if _msOrd then _msName = "M" .. _msOrd .. " " .. _msName end
        addLine(string.format("%s  |cFFFF8800" .. T("MS_MISSING_N", "(缺 %d 件)") .. "|r", _msName, v.missing), 2, 1, 0.82, 0)
        if g.recommendSpecId and SetLootSpecialization then
            btnN = btnN + 1
            local btn = sc.btns[btnN]
            if not btn then
                btn = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
                btn:SetSize(230, 20)
                btn:SetScript("OnClick", function(s2)
                    if InCombatLockdown() then GearInsight:Print(T("MS_COMBAT", "战斗中无法切换拾取专精")); return end
                    if not s2._specId then return end
                    SetLootSpecialization(s2._specId)
                    GearInsight:Print(string.format(T("MS_SET_OK", "拾取专精已设为 %s"), s2._specName or "?"))
                    -- Reflect the switch on every loot-spec button immediately. GetLootSpecialization()
                    -- only refreshes a frame later (PLAYER_LOOT_SPEC_UPDATED), so a delayed re-render
                    -- can read the stale value and leave this button enabled — making it look like the
                    -- first click did nothing. Update state optimistically so one click is enough.
                    local pool = s2:GetParent()
                    if pool and pool.btns then
                        for _, b in ipairs(pool.btns) do
                            if b._specId and b:IsShown() then
                                if b._specId == s2._specId then
                                    b:SetText(string.format(T("MS_BTN_CUR", "拾取专精: %s (当前)"), b._specName or "?")); b:Disable()
                                else
                                    b:SetText(string.format(T("MS_BTN_SET", "设为拾取专精: %s"), b._specName or "?")); b:Enable()
                                end
                            end
                        end
                    end
                end)
                sc.btns[btnN] = btn
            end
            btn._specId = g.recommendSpecId
            btn._specName = recName
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 12, y)
            if curLoot == g.recommendSpecId then
                btn:SetText(string.format(T("MS_BTN_CUR", "拾取专精: %s (当前)"), recName)); btn:Disable()
            else
                btn:SetText(string.format(T("MS_BTN_SET", "设为拾取专精: %s"), recName)); btn:Enable()
            end
            btn:Show()
            y = y - 24
        end
        for _, id in ipairs(v.order) do
            local e = v.byItem[id]
            local slotKey = self.GearReader and self.GearReader:GetSlotKey(e.slotId) or nil
            local slotLabel = (slotKey and L[slotKey]) or (T("SLOT_N", "槽") .. (e.slotId or "?"))
            local it = e.item or {}
            local nm = locName(it.itemId, it.itemNameCn or it.itemName) or ("#" .. (it.itemId or 0))
            local shared = #e.specs >= 2
            local tag = shared and ("  |cFFFFD100[" .. T("MS_SHARED", "多专精通用") .. "]|r") or ""
            local cr, cg, cb = 0.8, 0.8, 0.8
            if shared then cr, cg, cb = 1, 0.9, 0.4 end
            local isTier = it.sourceCategory == "tier" or it.source == "套装转换"
            if isTier then tag = tag .. "  |cFFB060FF" .. T("MS_TIER_NOTE", "[套装·下列坯子可催化]") .. "|r" end
            addItemRow(string.format("|cFF66CCFF[%s]|r %s — %s%s", table.concat(e.specs, "/"), slotLabel, nm, tag), e, cr, cg, cb)
            -- Inline all catalyzable 坯子 for tier slots (no click needed): full Encounter
            -- Journal list, falling back to the curated tierFiller list.
            if isTier then
                local fillers = self:GetCatalystSources(e.slotId)
                if not fillers or #fillers == 0 then
                    local armor = self.BisData and self.BisData.classArmor and self.BisData.classArmor[self._msClass]
                    fillers = armor and self.BisData.tierFiller and self.BisData.tierFiller[armor]
                        and self.BisData.tierFiller[armor][e.slotId]
                end
                local tgtIlvl = it.ilvl or 0
                local tb = it.bonusIDs   -- set piece bonusIDs → encode the BiS ilvl onto fillers
                for _, fs in ipairs(fillers or {}) do
                    if fs.type ~= "crafted" and fs.sourceCategory ~= "crafted" then
                    local flink = (tb and #tb > 0)
                        and ("|Hitem:" .. fs.itemId .. GearInsight.LinkMid() .. #tb .. ":" .. table.concat(tb, ":") .. "|h[item]|h")
                        or fs.link
                    local fe = {
                        item = { itemId = fs.itemId, bonusIDs = tb or fs.bonusIDs, link = flink, ilvl = tgtIlvl,
                                 instanceId = fs.instanceId, encounterId = fs.encounterId },
                        slotId = e.slotId, specs = {}, _isRaid = (fs.type == "raid"),
                    }
                    local fname = locName(fs.itemId, fs.itemName) or ("#" .. (fs.itemId or 0))
                    local CATL = { raid = T("CAT_RAID", "团本"), mplus = T("CAT_MPLUS", "大秘境"), crafted = T("CAT_CRAFTED", "制造业"), world = T("CAT_WORLD", "世界掉落") }
                    local srcTag = CATL[fs.type] or T("CAT_MPLUS", "大秘境")
                    local tgt = tgtIlvl > 0 and string.format(" |cFF888888[→%d]|r", tgtIlvl) or ""
                    addItemRow(string.format("        |cFFB060FF└|r %s%s  |cFF808080· %s (%s)|r",
                        fname, tgt, localizedSource(fs.nameCn or "", fs.instanceId, fs.encounterId), srcTag), fe, 0.65, 0.65, 0.65)
                    end
                end
            end
        end
        y = y - 6
    end
    sc:SetHeight(math.max(40, math.abs(y) + 10))
end

function GearInsight:ShowMultiSpecPlan(class, keepOpen)
    if not class then return end
    if self._msFrame and self._msFrame:IsShown() and not keepOpen then self._msFrame:Hide(); return end
    self._msClass = class:upper()

    if not self._msFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightMSFrame")
        f:SetSize(560, 560); GearInsight:AnchorPopup(f)
        f:SetFrameStrata("DIALOG"); f:SetFrameLevel(25)
        f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.08, 0.96)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12); title:SetText(T("MS_TITLE", "多专精拾取规划"))
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", title, "BOTTOM", 0, -3)
        hint:SetText(T("MS_HINT", "勾选要一起刷的专精，每个 Boss 提示该设的拾取专精"))
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        self._msCheckRow = CreateFrame("Frame", nil, f)
        self._msCheckRow:SetPoint("TOPLEFT", 14, -52); self._msCheckRow:SetPoint("TOPRIGHT", -14, -52)
        self._msCheckRow:SetHeight(26)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -84); scroll:SetPoint("BOTTOMRIGHT", -30, 44)
        local scc = CreateFrame("Frame", nil, scroll); scc:SetWidth(510)
        scroll:SetScrollChild(scc); self._msScrollChild = scc
        -- 拾取需求单入口：按勾选的专精生成 M1–M9 逐 BOSS 文本（含掷币推荐），弹复制框
        local needBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        needBtn:SetSize(170, 24)
        needBtn:SetPoint("BOTTOM", 0, 12)
        needBtn:SetText(T("MS_NEED_BTN", "复制需求单文本"))
        needBtn:SetScript("OnClick", function() GearInsight:ShowNeedSheet() end)
        needBtn:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_TOP")
            GameTooltip:SetText(T("MS_NEED_TIP", "按上方勾选的专精生成逐BOSS需求单文本\n（拾取设置/需求装备/掷币推荐），复制后发给团长/队友"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        needBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self._msChecks = {}
        self._msFrame = f
    end

    local specs = self.BisData and self.BisData:GetClassSpecs(self._msClass) or {}
    table.sort(specs, function(a, b) return _msSpecName(a.specId, a.specName) < _msSpecName(b.specId, b.specName) end)
    for _, ck in ipairs(self._msChecks) do ck:Hide() end
    local selected = self:_msSelected()
    local x = 0
    for i, sp in ipairs(specs) do
        local ck = self._msChecks[i]
        if not ck then
            ck = CreateFrame("CheckButton", nil, self._msCheckRow, "UICheckButtonTemplate")
            ck:SetSize(22, 22)
            ck.text = ck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ck.text:SetPoint("LEFT", ck, "RIGHT", 1, 0)
            ck:SetScript("OnClick", function(s2)
                local sel = GearInsight:_msSelected()
                sel[s2._specName] = s2:GetChecked() and true or nil
                GearInsight:_msRender()
            end)
            self._msChecks[i] = ck
        end
        ck._specName = sp.specName
        ck.text:SetText(_msSpecName(sp.specId, sp.specName))
        ck:SetChecked(selected[sp.specName] and true or false)
        ck:ClearAllPoints(); ck:SetPoint("LEFT", x, 0); ck:Show()
        x = x + 26 + (ck.text:GetStringWidth() or 40) + 16
    end

    self:_msRender()
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._msFrame) end
    self._msFrame:Show()
end

-- 切换设置后，原地重建已打开的 刷本/多专精 弹窗（不关闭），使其同步反映新设置。
function GearInsight:_refreshOpenPopups()
    if self._fgFrame and self._fgFrame:IsShown() and self._fgArgs and not self._fgArgs[4] then
        self:ShowFarmingGuide(self._fgArgs[1], self._fgArgs[2], self._fgArgs[3], true)
    end
    if self._fgHost and self._fgHost:IsShown() and self.BuildWishlistPage then
        self:BuildWishlistPage(self._fgHost)
    end
    if self._msFrame and self._msFrame:IsShown() and self._msClass then
        self:ShowMultiSpecPlan(self._msClass, true)
    end
    -- 使用率前5 弹窗：按当前参照系原地刷新（百分比与排序联动；池始终不受团本排除影响）。
    if self._slotTopFrame and self._slotTopFrame:IsShown() and self._slotTopFrame._slotId then
        self:ShowSlotTop5(self._slotTopFrame._slotLabel, self._slotTopFrame._slotId, nil, true)
    end
    -- 坡子弹窗（用户2026-09-02）：「团本装备」与「使用率参照」两个按钮都会改它的
    -- 内容与排序，开着就原地重画，不要让玩家关了再点开。
    -- ⛔ 必须传 force=true：ShowTierFiller 对同一部位的重复调用是「关窗」语义。
    if self._tierFrame and self._tierFrame:IsShown() and self._tierArgs then
        local a = self._tierArgs
        self:ShowTierFiller(a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], true)
    end
end


-- 给后面的模块用（见 GearInsight.Helpers）
H._msOwnedSet = _msOwnedSet
H._msSpecName = _msSpecName
