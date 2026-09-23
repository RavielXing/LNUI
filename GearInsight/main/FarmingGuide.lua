-- GearInsight/main/FarmingGuide.lua — 刷本规划弹窗 + 多专精合并
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, locName, getLocalizedClassSpec, setItemForIcon, localizedSource, _openSourceJournal = H.T, H.locName, H.getLocalizedClassSpec, H.setItemForIcon, H.localizedSource, H.openSourceJournal

-- ── Farming guide popup ─────────────────────────────────────────────
-- 复刻旧副本的坯子复用原版 itemId（如萨隆矿坑 50234），常不在客户端缓存里，
-- GetItemInfo 返 nil 只能显示 #ID。这里异步请求物品数据，到货后若刷本窗口仍开着
-- 就原地重渲染一次补上名字。每个 id 本次会话只请求一次 + 0.5s 去抖，不会循环重渲染。
local _fgNamePending = {}
local function _fgQueueNameLoad(itemId)
    if _fgNamePending[itemId] ~= nil then return end
    if not (Item and Item.CreateFromItemID and C_Timer and C_Timer.NewTimer) then return end
    _fgNamePending[itemId] = true
    local ok, it = pcall(Item.CreateFromItemID, Item, itemId)
    if not (ok and it) or (it.IsItemEmpty and it:IsItemEmpty()) then return end
    it:ContinueOnItemLoad(function()
        if GearInsight._fgNameTimer then return end
        GearInsight._fgNameTimer = C_Timer.NewTimer(0.5, function()
            GearInsight._fgNameTimer = nil
            local f = GearInsight._fgFrame
            if f and f:IsShown() then
                local a = GearInsight._fgArgs or {}
                GearInsight:ShowFarmingGuide(a[1], a[2], a[3], true)
            end
        end)
    end)
end

-- Detect 2H vs dual wield from the equipped main-hand weapon (shared by the
-- farming guide and the main-panel crafted-picks section).
function GearInsight:_detectIs2H()
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    if snap and snap.equipped and snap.equipped[16] and not snap.equipped[16].empty then
        local mhId = snap.equipped[16].itemId
        if mhId and C_Item and C_Item.GetItemInventoryTypeByID then
            -- ENUM: INVTYPE_2HWEAPON = 17
            return C_Item.GetItemInventoryTypeByID(mhId) == 17
        end
    end
    return false
end

-- Top-N crafted-gear slot picks for the given spec, ranked by each item's own
-- WCL usage % in its slot (higher = more strongly agreed-upon BiS there).
-- Shared by the main panel's mini "制造推荐" section and the farming guide.
function GearInsight:GetTopCraftedPicks(class, spec, heroTalent, is2H, limit)
    local itemsBySource = self.BisData and self.BisData:GetItemsBySource(class, spec, heroTalent, is2H)
    local crafted = itemsBySource and itemsBySource.crafted
    if not crafted or #crafted == 0 then return nil end
    table.sort(crafted, function(a, b)
        return (a.item.usagePct or 0) > (b.item.usagePct or 0)
    end)
    local out = {}
    for i = 1, math.min(limit or 2, #crafted) do
        out[i] = crafted[i]
    end
    return out
end

-- 刷本助手的过滤只管本页：建模前把本页开关压成临时覆盖，建完立刻还原（总览/悬浮/角色面板不受影响）
function GearInsight:_withFarmFilters(fn)
    if self._fgFilterOverride then return fn() end     -- 已在覆盖里（Multi 逐专精调用）
    GearInsightDB = GearInsightDB or {}
    self._fgFilterOverride = { exRaid = GearInsightDB.fgExcludeRaid and true or false,
                               tier = GearInsightDB.fgGearTier or "mythic" }
    local bd = self.BisData
    if bd and bd.ApplyDataFilters then bd:ApplyDataFilters() end
    local ok, a, b, c = pcall(fn)
    self._fgFilterOverride = nil
    if bd and bd.ApplyDataFilters then bd:ApplyDataFilters() end
    if not ok then error(a, 0) end
    return a, b, c
end

function GearInsight:ShowFarmingGuide(class, spec, heroTalent, keepOpen, host, opts)
    if host and not self._fgFilterOverride then
        return self:_withFarmFilters(function() return self:_ShowFarmingGuideImpl(class, spec, heroTalent, keepOpen, host, opts) end)
    end
    return self:_ShowFarmingGuideImpl(class, spec, heroTalent, keepOpen, host, opts)
end

function GearInsight:_ShowFarmingGuideImpl(class, spec, heroTalent, keepOpen, host, opts)
    -- host = 嵌入到主面板「刷本助手」页时传入的页框（ui/WishlistPage.lua）；不传 = 老的独立弹窗
    --   （用户 2026-09-11「刷本优先级模块和心愿单直接整合」）。⛔ 判断逻辑两条路完全同一份。
    -- opts（2026-09-12 多专精并入刷本助手）：
    --   modelOnly=true → 只建模型返回，不画、不动 _fgArgs/标题（ShowFarmingGuideMulti 逐专精调用）
    --   model=<预置模型> → 跳过建模直接画（合并后的多专精模型）；title → 覆盖标题行
    opts = opts or {}
    if host then self._fgHost = host end
    -- Toggle off if already showing（keepOpen=切换参照系时原地重建，不关闭）
    if not host and self._fgFrame and self._fgFrame:IsShown() and not keepOpen then
        self._fgFrame:Hide()
        return
    end
    if not opts.modelOnly then self._fgArgs = { class, spec, heroTalent, host } end

    local is2H = self:_detectIs2H()

    local itemsBySource = self.BisData and self.BisData:GetItemsBySource(class, spec, heroTalent, is2H)
    local cn, sn = getLocalizedClassSpec()

    -- Dimmer: no longer blocks outside clicks — user can interact with other UI

    -- Popup frame (create once, reuse)
    if not host and not self._fgFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightFGFrame")
        f:SetSize(604, 560)
        GearInsight:AnchorPopup(f)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(20)
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
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)

        -- Title
        self._fgTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        self._fgTitle:SetPoint("TOP", 0, -12)

        -- Close button
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4)
        cb:SetScript("OnClick", function()
            f:Hide()
        end)

        -- Scroll frame
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -36)
        scroll:SetPoint("BOTTOMRIGHT", -28, 32)
        self._fgScroll = scroll

        local sc = CreateFrame("Frame", nil, scroll)
        sc:SetWidth(560)
        scroll:SetScrollChild(sc)
        self._fgScrollChild = sc

        -- 「只看第一 BiS」开关（用户 2026-09-02）。放左上角，与居中的标题不冲突。
        local ob = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        ob:SetSize(112, 20)
        ob:SetPoint("TOPLEFT", 10, -8)
        ob:SetScript("OnClick", function()
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.fgOnlyTopBis = not GearInsightDB.fgOnlyTopBis
            local a = GearInsight._fgArgs
            -- ⛔ keepOpen=true：ShowFarmingGuide 对同一参数的重复调用是「关窗」语义
            if a then GearInsight:ShowFarmingGuide(a[1], a[2], a[3], true, a[4]) end
        end)
        ob:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("FG_ONLYTOP_TIP",
                "只显示每个部位排第一的毕业件。\n戒指/饰品留前 2、武器按双持/双手留 1–2；套装部位只留第一名坯子。"),
                1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        ob:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self._fgOnlyBtn = ob

        self._fgFrame = f
    end
    local onlyTxt = (GearInsightDB and GearInsightDB.fgOnlyTopBis)
        and T("FG_ONLYTOP_ON", "第一BiS: 只看") or T("FG_ONLYTOP_OFF", "第一BiS: 全部")
    if self._fgOnlyBtn then self._fgOnlyBtn:SetText(onlyTxt) end
    if host and host._fgOnlyBtn then host._fgOnlyBtn:SetText(onlyTxt) end

    -- Update title
    local titleStr = T("FG_TITLE", "刷本优先级")
    if cn or class then
        titleStr = titleStr .. " — " .. (cn or class or "")
        if sn or spec then titleStr = titleStr .. "/" .. (sn or spec or "") end
        if heroTalent then titleStr = titleStr .. "(" .. heroTalent .. ")" end
    end
    if opts.title then titleStr = opts.title end
    if self._fgTitle and not host and not opts.modelOnly then self._fgTitle:SetText(titleStr) end
    if host and host._fgSpecLine and not opts.modelOnly then host._fgSpecLine:SetText(titleStr) end

    -- Rebuild content rows. Headers/sub-headers are FontStrings; item rows are
    -- Frames. They MUST be pooled SEPARATELY — a single positional pool would,
    -- after a re-render with a different row composition (e.g. toggling 团本排除),
    -- hand back a Frame where a FontString is expected and error mid-render
    -- (leaving the popup half-blank). Type-stable pools keep each slot consistent.
    local sc = (host and host._fgChild) or self._fgScrollChild
    sc.fsPool = sc.fsPool or {}
    sc.itemPool = sc.itemPool or {}
    sc.hdrPool = sc.hdrPool or {}
    if sc.rows then for _, w in ipairs(sc.rows) do w:Hide() end end  -- legacy mixed pool (older builds)
    for _, w in ipairs(sc.fsPool) do w:Hide() end
    for _, w in ipairs(sc.itemPool) do w:Hide() end
    for _, w in ipairs(sc.hdrPool) do w:Hide() end
    local fsIdx, itemIdx, hdrIdx = 0, 0, 0
    -- A pooled FontString for headers/sub-headers/fallback; font set per use.
    local function nextFS(fontObject)
        fsIdx = fsIdx + 1
        local fs = sc.fsPool[fsIdx]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
            sc.fsPool[fsIdx] = fs
        end
        fs:SetFontObject(fontObject or "GameFontNormal")
        return fs
    end
    -- A pooled item row (Frame with icon + text), built once.
    local function nextItemRow()
        itemIdx = itemIdx + 1
        local row = sc.itemPool[itemIdx]
        if not row then
            row = CreateFrame("Frame", nil, sc)
            row:SetSize(440, 26)
            local icon = CreateFrame("Button", nil, row)
            icon:SetSize(22, 22)
            icon:SetPoint("LEFT", 14, 0)
            icon.texture = icon:CreateTexture(nil, "ARTWORK")
            icon.texture:SetAllPoints()
            icon.itemID = nil; icon.itemLink = nil; icon.currentItemID = nil
            icon:SetScript("OnEnter", function(self)
                if not self.itemID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.itemLink then GameTooltip:SetHyperlink(self.itemLink)
                else GameTooltip:SetItemByID(self.itemID) end
                if self._itemIlvl and self._itemIlvl > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cFFFFFF00" .. T("TT_BIS_ILVL", "BiS 装等: ") .. self._itemIlvl .. "|r", 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
            icon:RegisterForClicks("LeftButtonUp")
            icon:SetScript("OnClick", function(self)
                if GearInsight._tryChatLink(self) then return end
                _openSourceJournal(self._instId, self._bossId, self.itemID, self._isRaid)
            end)
            icon._instId = nil
            icon._bossId = nil
            row._icon = icon
            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            txt:SetWidth(380)
            txt:SetJustifyH("LEFT")
            row._txt = txt
            sc.itemPool[itemIdx] = row
        end
        return row
    end
    -- A pooled CLICKABLE category header (Button + child FontString). Clicking it
    -- toggles the category's collapse state (stored in GearInsightDB.fgCollapse) and
    -- re-renders the popup in place. Used so 制造业 can be folded away by default.
    local function nextHeaderBtn()
        hdrIdx = hdrIdx + 1
        local btn = sc.hdrPool[hdrIdx]
        if not btn then
            btn = CreateFrame("Button", nil, sc)
            btn:SetHeight(20)
            btn:EnableMouse(true)
            btn:RegisterForClicks("LeftButtonUp")
            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            fs:SetPoint("LEFT", 0, 0)
            fs:SetJustifyH("LEFT")
            btn._fs = fs
            sc.hdrPool[hdrIdx] = btn
        end
        return btn
    end
    local yOff = 0

    -- Get equipped item info (itemId → {ilvl}) for missing-item detection,
    -- plus the best equipped ilvl per slot (for tier-slot satisfaction below).
    local equippedItems = {}
    local equippedBySlot = {}
    local equippedIdBySlot = {}
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    if snap and snap.equipped then
        for _, eq in pairs(snap.equipped) do
            if eq and not eq.empty and eq.itemId then
                equippedItems[eq.itemId] = { ilvl = eq.ilvl or 0, slotId = eq.slotId }
                if eq.slotId then
                    equippedBySlot[eq.slotId] = math.max(equippedBySlot[eq.slotId] or 0, eq.ilvl or 0)
                    equippedIdBySlot[eq.slotId] = eq.itemId
                end
            end
        end
    end

    -- 配对池前2候选的 itemId 集合（戒指/饰品/武器各一池），严判用。
    local function poolKeyOf(sid)
        if sid == 11 or sid == 12 then return "rings"
        elseif sid == 13 or sid == 14 then return "trinkets"
        elseif sid == 16 or sid == 17 then return "weapons" end
    end
    local poolTop = {}
    if itemsBySource then
        for _, items in pairs(itemsBySource) do
            for _, e in ipairs(items) do
                local pk = e.item and not e.item._filler and e.item.itemId and poolKeyOf(e.slotId)
                if pk then
                    poolTop[pk] = poolTop[pk] or {}
                    poolTop[pk][e.item.itemId] = true
                end
            end
        end
    end

    -- A tier piece counts as owned when you have any same-slot item at the tier ilvl
    -- (the Catalyst can convert it), not only the exact tier itemId.
    local function tierSlotSatisfied(slotId, ilvl)
        return (equippedBySlot[slotId] or 0) >= (ilvl or 0)
    end
    -- 「同一件已穿上」≠ 拿到了：勇士轨道的套装手套 308，升满也到不了 334（09-21 玩家 小龙丨星法 / 发条苹果：
    --   刷本规划把它标已齐全、不再让他去刷）。与总览页同口径：装等到了 → 有；轨道升满约（每档 +3）够得着 → 算有（只差升级）；
    --   否则 = 还没拿到，照常列进「缺」。轨道读不到（不在身上 / 提示保密）时退回只比装等。
    local _reachCache = {}
    local function equippedReaches(itemId, ilvl)
        local eq = equippedItems[itemId]
        if not eq then return false end
        if (eq.ilvl or 0) >= (ilvl or 0) then return true end
        if not eq.slotId then return false end
        local key = eq.slotId .. ":" .. (ilvl or 0)
        if _reachCache[key] == nil then
            local okT, cur, mx = pcall(GearInsight.SlotUpgradeTrack, GearInsight, eq.slotId)
            if okT and cur and mx then
                local ceil = (eq.ilvl or 0) + math.max(mx - cur, 0) * 3
                _reachCache[key] = (cur < mx) and (ceil + 2 >= (ilvl or 0))
            else
                _reachCache[key] = false
            end
        end
        return _reachCache[key]
    end

    -- Dual-wield / paired-slot pools (weapons 16+17, rings 11+12, trinkets 13+14):
    -- 严判口径与主面板毕业判定一致——池子里每个槽必须装着「池子前2候选本身」且装等达标
    -- 才算齐。只看装等会与主面板打架：装等相同但使用率跌出前2的旧件，主面板报「待提升」，
    -- 这里却整行吞掉刷取目标（2026-06-06 幽影羽毛实证：双饰品都298但旌旗非前2候选）。
    local function poolSatisfied(slotId, ilvl)
        local slots
        if slotId == 11 or slotId == 12 then slots = { 11, 12 }
        elseif slotId == 13 or slotId == 14 then slots = { 13, 14 }
        elseif slotId == 16 or slotId == 17 then slots = is2H and { 16 } or { 16, 17 }
        else return false end
        local pset = poolTop[poolKeyOf(slotId)]
        for _, sid in ipairs(slots) do
            if (equippedBySlot[sid] or 0) < (ilvl or 0) then return false end
            local eqId = equippedIdBySlot[sid]
            if pset and not (eqId and pset[eqId]) then return false end
        end
        return true
    end

    -- ⭐ 套装组固定 5 个部位（用户 2026-09-14「没套装为啥会缺 3 件」）：某部位第一 BiS 是散件时，
    --    套装件仍列出来标「可选」—— 4 件套只需 4 个，顶尖玩家在这个部位多用散件；⛔不计缺件数。
    do
        local specData = self.BisData and self.BisData.GetSpecData and self.BisData:GetSpecData(class, spec, heroTalent)
        local bySlot = specData and specData.bisBySlot
        if itemsBySource and bySlot then
            itemsBySource.tier = itemsBySource.tier or {}
            local have = {}
            for _, te in ipairs(itemsBySource.tier) do have[te.slotId] = true end
            for slotId, cands in pairs(bySlot) do
                if not have[slotId] and type(cands) == "table" then
                    for ci, c in ipairs(cands) do
                        -- 套装件有两种来源写法：sourceCategory=="tier"（催化）或 isTier 且挂在团本 BOSS 下（直掉）
                        if c.sourceCategory == "tier" or c.isTier then
                            local top = cands[1]
                            local alt = {}
                            for k, v in pairs(c) do alt[k] = v end
                            if ci == 1 then
                                -- 它就是第一 BiS，只是被归到了团本组（直掉）：搬进套装组，团本组里去掉，别两边各算一次缺
                                alt._directDrop = true
                                local rl = itemsBySource[c.sourceCategory or "raid"]
                                if rl then
                                    for i = #rl, 1, -1 do
                                        if rl[i].slotId == slotId and rl[i].item.itemId == c.itemId and not rl[i].item._filler then table.remove(rl, i) end
                                    end
                                end
                            else
                                alt._optional = true
                                alt._altItemId = top and top.itemId or nil
                            end
                            table.insert(itemsBySource.tier, { slotId = slotId, item = alt })
                            break
                        end
                    end
                end
            end
            -- ⭐ 候选池里压根没有套装件的部位（血 DK 大秘境参照下的头/胸，2026-09-14 截图只列 3 个）：
            --    按 core/TierSets.lua 那张兜底表补一条「可选」，装等/轨道跟组里已有的套装件走
            local ts = GearInsight.TierSets and GearInsight.TierSets[class]
            if ts then
                local ref = itemsBySource.tier[1] and itemsBySource.tier[1].item
                have = {}
                for _, te in ipairs(itemsBySource.tier) do have[te.slotId] = true end
                for _, slotId in ipairs({ 1, 3, 5, 7, 10 }) do
                    local rec = ts[slotId]
                    if rec and not have[slotId] then
                        local top = bySlot[slotId] and bySlot[slotId][1]
                        table.insert(itemsBySource.tier, { slotId = slotId, item = {
                            itemId = rec[1], itemName = rec[2], sourceCategory = "tier", source = "套装转换",
                            ilvl = ref and ref.ilvl or (top and top.ilvl) or 0,
                            bonusIDs = ref and ref.bonusIDs or nil, usagePct = 0,
                            _optional = true, _altItemId = top and top.itemId or nil,
                        } })
                    end
                end
            end
            table.sort(itemsBySource.tier, function(a, b) return (a.slotId or 0) < (b.slotId or 0) end)
        end
    end

    -- Fold tier "坯子" (Catalyst filler) into raid/mplus groups: every same-slot drop you
    -- could Catalyst-convert. Prefer the complete Encounter Journal list, fall back to the
    -- curated tierFiller list. Only for tier slots you don't already have at the tier ilvl.
    if itemsBySource and itemsBySource.tier then
        local armor = self.BisData and self.BisData.classArmor and self.BisData.classArmor[class]
        -- When 团本排除 is on, the 坯子 itself stays (it can be catalyzed from a
        -- non-raid same-slot piece), but its RAID catalyst sources must be dropped —
        -- otherwise raid bosses (e.g. M6 虚影尖塔) reappear under the 团本 group.
        local exRaid = self.BisData and self.BisData:GetExcludeRaid()
        for _, te in ipairs(itemsBySource.tier) do
            -- 已穿着套装件本身（催化已完成）→ 不再列坯子：剩下的只是装等差距，
            -- 走纹章升级而非重刷坯子；「套装」分类的本体行仍会报「装等不足」。
            if not equippedItems[te.item.itemId]
                and (equippedBySlot[te.slotId] or 0) < (te.item.ilvl or 0) then
                local srcs = self:GetCatalystSources(te.slotId)
                if (not srcs or #srcs == 0) and armor and self.BisData and self.BisData.tierFiller
                    and self.BisData.tierFiller[armor] then
                    srcs = self.BisData.tierFiller[armor][te.slotId]
                end
                -- Show each 坯子 at the TARGET set ilvl: graft the set piece's bonusIDs
                -- (which encode the BiS ilvl) onto the filler's itemId so the tooltip reads
                -- the BiS ilvl, not the journal's base/Mythic-0 value.
                local tb = te.item.bonusIDs
                for _, s in ipairs(srcs or {}) do
                    local cat = s.type or "other"
                    -- Crafted gear isn't catalyzable into tier — never fold it in as a 坯子.
                    -- ⛔ 上赛季的件也不列（用户 2026-09-02）：手册按资料片枚举，
                    --    一个资料片里混着本赛季和上赛季的全部副本。
                    if not (exRaid and cat == "raid") and cat ~= "crafted"
                        and GearInsight.IsCurrentSeasonSource(s.instanceId, s.ilvl) then
                    local link = (tb and #tb > 0)
                        and ("|Hitem:" .. s.itemId .. GearInsight.LinkMid() .. #tb .. ":" .. table.concat(tb, ":") .. "|h[item]|h")
                        or s.link
                    itemsBySource[cat] = itemsBySource[cat] or {}
                    table.insert(itemsBySource[cat], {
                        slotId = te.slotId,
                        item = {
                            itemId = s.itemId,      -- the real same-slot drop to convert
                            bonusIDs = tb or s.bonusIDs,
                            link = link,
                            ilvl = te.item.ilvl,    -- TARGET set ilvl shown inline ([→289])
                            bossName = s.nameCn, sourceCategory = cat,
                            instanceId = s.instanceId, encounterId = s.encounterId,
                            _isRaid = (s.type == "raid"),
                            _filler = true,
                        },
                    })
                    end -- not (exRaid and raid)
                end
            end
        end
    end

    -- ⭐「只看第一 BiS」：每个部位只留排第一的那件。
    --   戒指/饰品/武器是**成对**槽位，GetItemsBySource 会给 #1 和 #2（分别落在 11/12、
    --   13/14、16/17），开着这个开关时一对只留 #1 —— 按 usagePct 取，与主面板同一把尺子。
    --   ⛔ 坯子行（_filler）一并隐去：它们是「怎么换到这件」的替代路径，本身不是第一 BiS。
    --   ⛔ 必须过滤在**分组与计数之前**：放到渲染循环里跳过的话，小标题那句
    --     「缺 N 件」还是按原数算的，会和实际列出的行数对不上。
    if GearInsightDB and GearInsightDB.fgOnlyTopBis and itemsBySource then
        local function _poolKey(sid)
            if sid == 11 or sid == 12 then return "rings"
            elseif sid == 13 or sid == 14 then return "trinkets"
            elseif sid == 16 or sid == 17 then return "weapons" end
            return sid
        end
        -- 成对部位（戒指/饰品）身上要装两件 → 留前 2；武器双持留 2、双手留 1（用户 2026-09-11「饰品戒指要推荐前2的」）
        local pools = {}
        for _, items in pairs(itemsBySource) do
            for _, e in ipairs(items) do
                local it = e.item
                if it and it.itemId and not it._filler then
                    local k = _poolKey(e.slotId)
                    pools[k] = pools[k] or {}
                    local dup = false
                    for _, x in ipairs(pools[k]) do if x.itemId == it.itemId then dup = true end end
                    if not dup then table.insert(pools[k], it) end
                end
            end
        end
        local keep = {}
        -- ⛔ 与 BisPack.buildSpec 同一把尺子：英雄/普通档先按换算后装等、再按使用率（0.80.10 定口径），
        --    否则「只看」留下的是使用率第一的 308 团本饰品，而榜上第一其实是 334 的大秘境件
        local _step = (GearInsight.GearTierStep and GearInsight:GearTierStep()) or 0
        for k, list in pairs(pools) do
            table.sort(list, function(a, b)
                if _step > 0 and (a.ilvl or 0) ~= (b.ilvl or 0) then return (a.ilvl or 0) > (b.ilvl or 0) end
                return (a.usagePct or 0) > (b.usagePct or 0)
            end)
            local n = 1
            if k == "rings" or k == "trinkets" then n = 2
            elseif k == "weapons" then n = is2H and 1 or 2 end
            for i = 1, math.min(n, #list) do keep[list[i].itemId] = true end
        end
        -- ⭐ 坯子不再整体隐去：每个套装部位留**排第一的那件坯子**（用户 2026-09-11「点到第一BIS以后，第一坯子都没推荐了」）。
        --    第一名由 BuildFillerList 同一把尺子（属性占比打分）定，与弹窗第 1 条一致。
        local keepFiller = {}
        local _specData = self.BisData and self.BisData.GetSpecData and self.BisData:GetSpecData(class, spec, heroTalent)
        local _armor = self.BisData and self.BisData.classArmor and self.BisData.classArmor[class]
        if _specData and _armor and GearInsight.BuildFillerList then
            for _, te in ipairs(itemsBySource.tier or {}) do
                local ok, list = pcall(GearInsight.BuildFillerList, _armor, te.slotId, nil, _specData, te.item.stats, true)
                if ok and list and list[1] and list[1].itemId then keepFiller[te.slotId] = list[1].itemId end
            end
        end
        for _, items in pairs(itemsBySource) do
            for i = #items, 1, -1 do
                local e = items[i]
                local it = e.item
                local ok = it and it.itemId and (
                    (keep[it.itemId] and not it._filler)
                    or (it._filler and keepFiller[e.slotId] == it.itemId))
                if not ok then table.remove(items, i) end
            end
        end
    end

    -- Farmable categories first (raid / mplus / world / tier); 制造业(crafted) is NOT
    -- obtainable by running content (needs profession crafting or AH), so it's pushed
    -- to the very end and rendered collapsed by default to stop it visually dominating.
    local CAT_ORDER = { "raid", "mplus", "world", "quest", "tier", "crafted" }
    -- Per-category collapse state (persisted). crafted defaults to collapsed.
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.fgCollapse = GearInsightDB.fgCollapse or {}
    if GearInsightDB.fgCollapse.crafted == nil then
        GearInsightDB.fgCollapse.crafted = true
    end
    local CAT_LABELS = {
        raid = T("CAT_RAID", "团本"), mplus = T("CAT_MPLUS", "大秘境"), crafted = T("CAT_CRAFTED", "制造业"),
        world = T("CAT_WORLD", "世界掉落"), tier = T("CAT_TIER", "套装"), quest = T("CAT_QUEST", "任务/声望"),
    }
    local CAT_COLORS = {
        raid = { 1, 0.6, 0.2 }, mplus = { 0.3, 0.8, 1 },
        crafted = { 0.2, 1, 0.2 }, world = { 1, 0.8, 0 },
        tier = { 0.8, 0.4, 1 }, quest = { 1, 0.85, 0.3 },
    }
    local L = self.L or {}
    local gr = self.GearReader

    -- 制造业每个槽位只挂一件（GetItemsBySource 已去重），但一个专精常有 5-6 个
    -- 槽位的 #1 选择恰好是制造装，列出来太长。玩家反馈：只想看最值得做的 2 件。
    -- 按 WCL 数据里该件在自己槽位的使用率（usagePct）排序，取前 2 个槶位，
    -- 使用率越高＝顶尖玩家越公认该槽必须做，越值得优先制作。
    if itemsBySource and itemsBySource.crafted and #itemsBySource.crafted > 2 then
        table.sort(itemsBySource.crafted, function(a, b)
            return (a.item.usagePct or 0) > (b.item.usagePct or 0)
        end)
        for i = #itemsBySource.crafted, 3, -1 do
            table.remove(itemsBySource.crafted, i)
        end
    end

    -- ── 建模：分类 → 副本/BOSS 行 → 物品（缺 / 已有 / 装等不足 / 坯子）──
    -- ⛔ 判断逻辑全在这里（与旧文字版一字不差），ui/FarmGrid.lua 只负责画（用户 2026-09-11「按 KeystoneLoot 那个格式」）。
    local model = opts.model
    if not model then
    model = { cats = {} }
    -- ⛔ 这张表原来手写的是 S1 的 encId，S2 一条都对不上 → 团本行从来没标过 M 几（用户 2026-09-11）。
    --    现在优先读数据侧 BisData.raidBossOrder（generate_bisdata_lua 从 boss_order.json 算），手写表只做兜底。
    local RAID_BOSS_ORDER = (self.BisData and self.BisData.raidBossOrder)
        or { [2733]=1,[2734]=2,[2736]=3,[2735]=4,[2737]=5,[2738]=6,[2795]=7,[2739]=8,[2740]=9,[2711]=10 }
    if itemsBySource then
        for _, cat in ipairs(CAT_ORDER) do
            local items = itemsBySource[cat]
            if items and #items > 0 then
                local groups = {}
                for _, entry in ipairs(items) do
                    local poolDone = (not entry.item._filler)
                        and (not equippedItems[entry.item.itemId])
                        and poolSatisfied(entry.slotId, entry.item.ilvl)
                    -- ⛔ 套装件不按装等判「够了」：头/胸穿着更高装等的散件也不算 4 件套里的一件，
                    --    否则 5 个部位只列出 3 个、标题写成「已有 0/3」（用户 2026-09-14 截图）
                    if cat == "tier" then poolDone = false end
                    if not poolDone then
                        -- ⛔ 团本按 encounterId 分组，别按 bossName：坯子条目的 bossName 是副本名（潮缚石窟），
                        --    本体条目是 BOSS 名（尼姆瑞莎），同一只 BOSS 被拆成两行、都标 M9（2026-09-11 截图）
                        local subKey = entry.item.bossName
                        if cat == "raid" and entry.item.encounterId then subKey = "enc:" .. entry.item.encounterId end
                        if not subKey or subKey == "" then subKey = cat end
                        if not groups[subKey] then groups[subKey] = { items = {}, missing = 0, obtained = 0 } end
                        table.insert(groups[subKey].items, entry)
                        if not entry.item._filler and (equippedReaches(entry.item.itemId, entry.item.ilvl) or (entry.item.sourceCategory == "tier" and tierSlotSatisfied(entry.slotId, entry.item.ilvl))) then
                            groups[subKey].obtained = groups[subKey].obtained + 1
                        elseif entry.item._optional then
                            groups[subKey].optional = (groups[subKey].optional or 0) + 1   -- 可选套装件：不算缺
                        else
                            groups[subKey].missing = groups[subKey].missing + 1
                        end
                    end
                end
                local groupOrder = {}
                for k, v in pairs(groups) do
                    table.insert(groupOrder, { key = k, missing = v.missing, obtained = v.obtained, items = v.items })
                end
                table.sort(groupOrder, function(a, b)
                    if a.missing ~= b.missing then return a.missing > b.missing end
                    return a.key < b.key
                end)
                local totalMissing = 0
                for _, g in ipairs(groupOrder) do totalMissing = totalMissing + g.missing end
                local catLabel = CAT_LABELS[cat] or cat
                if cat == "tier" then
                    -- 套装：写 4 件套进度而不是「缺 N 件」（用户 2026-09-14）
                    local ownedN, totalN = 0, 0
                    for _, g in ipairs(groupOrder) do
                        for _, e in ipairs(g.items) do
                            if not e.item._filler then
                                totalN = totalN + 1
                                if equippedReaches(e.item.itemId, e.item.ilvl) or tierSlotSatisfied(e.slotId, e.item.ilvl) then ownedN = ownedN + 1 end
                            end
                        end
                    end
                    local need = math.max(0, 4 - ownedN)
                    catLabel = string.format(T("FG_TIER_HDR", "套装 4 件套：已有 %d/%d · 还差 %d 件"), ownedN, totalN, need)
                elseif totalMissing > 0 then
                    catLabel = catLabel .. " (" .. T("FG_NEED", "缺 ") .. totalMissing .. T("FG_PCS", " 件") .. ")"
                else
                    catLabel = catLabel .. T("FG_COMPLETE", " (已齐全)")
                end
                local collapsible = (cat == "crafted")
                local collapsed = collapsible and GearInsightDB.fgCollapse[cat] and true or false
                local mc = { cat = cat, label = catLabel, baseLabel = (CAT_LABELS[cat] or cat), clr = CAT_COLORS[cat] or { 0.7, 0.7, 0.7 },
                             collapsible = collapsible, collapsed = collapsed, totalMissing = totalMissing, groups = {} }
                if collapsible then mc.note = "|cFF888888" .. T("FG_CRAFTED_NOTE2", "制造件本身拍卖行搜不到：买好美化材料，找对应专业下「工艺订单」（自备火花）。仅列最值得做的 2 个部位；美化材料与制作顺序见下") .. "|r" end
                for _, group in ipairs(groupOrder) do
                    table.sort(group.items, function(a, b)
                        local aHas = equippedItems[a.item.itemId] and true or false
                        local bHas = equippedItems[b.item.itemId] and true or false
                        if aHas ~= bHas then return not aHas end
                        return (a.slotId or 0) < (b.slotId or 0)
                    end)
                    local _gi = group.items[1] and group.items[1].item
                    -- 组名：团本优先用手册里的 BOSS 名（同一组里坯子写的是副本名，本体写的是 BOSS 名，取手册最稳）
                    local bossNm
                    if cat == "raid" and _gi and _gi.encounterId and EJ_GetEncounterInfo then
                        local okN, nm = pcall(EJ_GetEncounterInfo, _gi.encounterId)
                        if okN and nm and nm ~= "" then bossNm = nm end
                    end
                    if not bossNm then
                        for _, e2 in ipairs(group.items) do
                            if e2.item.bossName and e2.item.bossName ~= "" and not e2.item._filler then bossNm = e2.item.bossName break end
                        end
                    end
                    -- ⛔ 非团本组的 bossNm 是数据里烘死的中文（如「虚空之痕竞技场」），英文客户端也要过 localizedSource
                    if bossNm and cat ~= "raid" then
                        bossNm = localizedSource(bossNm, _gi and _gi.instanceId, _gi and _gi.encounterId)
                    end
                    local groupName = (cat == "raid" or cat == "mplus") and group.key ~= cat
                        and (bossNm or (_gi and localizedSource(_gi.bossName or group.key, _gi.instanceId, _gi.encounterId)) or localizedSource(group.key))
                        or (CAT_LABELS[cat] or cat)
                    local _ord = _gi and RAID_BOSS_ORDER[_gi.encounterId]
                    if _ord then groupName = "M" .. _ord .. " " .. groupName end
                    -- 团本分类里 bossName 是副本名的那一组 = 套装件本体（催化得来，不掉自某个 BOSS）
                    local isTierGroup = (cat == "raid") and not _ord and group.key == (_gi and _gi.bossName) and _gi and _gi.sourceCategory == "tier"
                    if cat == "raid" and not _ord then groupName = groupName .. "  |cFFB060FF" .. T("FG_GRID_TIERGRP", "套装 · 催化") .. "|r" end
                    local mg = { key = group.key, name = groupName, missing = group.missing, ord = _ord,
                                 instanceId = _gi and _gi.instanceId, encounterId = _gi and _gi.encounterId,
                                 isRaid = (cat == "raid"), isTierGroup = isTierGroup, items = {} }
                    for _, entry in ipairs(group.items) do
                        local item = entry.item
                        local slotKey = gr and gr:GetSlotKey(entry.slotId) or nil
                        local slotName = (slotKey and L[slotKey]) or ("SLOT#" .. entry.slotId)
                        if item.itemId and not locName(item.itemId, item.itemName) then _fgQueueNameLoad(item.itemId) end
                        local eqInfo = equippedItems[item.itemId]
                        local tierOwned = (not item._filler) and item.sourceCategory == "tier" and tierSlotSatisfied(entry.slotId, item.ilvl)
                        local state, trackCapped
                        if item._filler then state = "filler"
                        elseif tierOwned or (eqInfo and item.ilvl and eqInfo.ilvl >= item.ilvl) then state = "owned"
                        elseif eqInfo and equippedReaches(item.itemId, item.ilvl) then state = "low"        -- 同款在身上、轨道升得到：只差升级
                        elseif eqInfo then state = "low"; trackCapped = true                                -- 同款在身上但轨道到顶也不够：要重拿
                        elseif item._optional then state = "optional"
                        else state = "missing" end
                        mg.items[#mg.items + 1] = {
                            slotId = entry.slotId, slotName = slotName, itemId = item.itemId, bonusIDs = item.bonusIDs,
                            link = item.link, ilvl = item.ilvl or 0, state = state, eqIlvl = eqInfo and eqInfo.ilvl or nil,
                            isRaid = item._isRaid, instanceId = item.instanceId, encounterId = item.encounterId,
                            altItemId = item._altItemId, trackCapped = trackCapped,
                        }
                    end
                    mc.groups[#mc.groups + 1] = mg
                end
                if cat == "raid" then
                    table.sort(mc.groups, function(a, b)
                        local ao, bo = a.ord or 99, b.ord or 99
                        if ao ~= bo then return ao < bo end
                        return (a.name or "") < (b.name or "")
                    end)
                end
                model.cats[#model.cats + 1] = mc
            end
        end
    end
    end -- if not opts.model
    if opts.modelOnly then return model end

    local contentH = 20
    if #model.cats == 0 then
        local hdr = nextFS("GameFontNormal")
        hdr:ClearAllPoints(); hdr:SetPoint("TOPLEFT", 4, 0)
        hdr:SetText(T("FG_NODATA", "暂无刷本优先级数据"))
        hdr:SetTextColor(1, 0.5, 0)
        hdr:Show()
        if GearInsight.FarmGrid then GearInsight.FarmGrid.Render(self, sc, model, {
            setItem = setItemForIcon, openJournal = _openSourceJournal, toggleCat = function() end }) end
    elseif GearInsight.FarmGrid then
        contentH = GearInsight.FarmGrid.Render(self, sc, model, {
            setItem = setItemForIcon,
            openJournal = _openSourceJournal,
            toggleCat = function(cat)
                GearInsightDB.fgCollapse = GearInsightDB.fgCollapse or {}
                GearInsightDB.fgCollapse[cat] = not GearInsightDB.fgCollapse[cat]
                if host and GearInsight.BuildWishlistPage then GearInsight:BuildWishlistPage(host); return end
                local a = GearInsight._fgArgs or {}
                GearInsight:ShowFarmingGuide(a[1], a[2], a[3], true, a[4])
            end,
        }, host and host._fgChild and host._fgChild:GetWidth() or nil)
    end
    sc:SetHeight(math.max(20, contentH))

    -- Show
    if host then
        if GearInsight.Skin then GearInsight.Skin.Sweep(host) end
        return
    end
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._fgFrame) end
    self._fgFrame:Show()
end

-- ── 多专精合并（2026-09-12 并入刷本助手）──────────────────────────────────
-- specs = { "HAVOC", "VENGEANCE", ... }（第一个是当前专精，带 heroTalent；其余 hero=nil）。
-- 逐专精走同一份 ShowFarmingGuide 建模（口径完全一致），再按 分类→组→物品 合并：
--   · 物品记下「哪些专精要它」（specs 字段，画成格子右下角小图标）；
--   · 状态取最缺的那档（missing > low > filler > owned）；
--   · 多专精态下背包里已有的同款也算「已获得」（副专精的装备多半在包里不在身上）；
--   · 组/分类的缺件数按合并后重算。
function GearInsight:ShowFarmingGuideMulti(class, specs, heroTalent, host)
    if not (class and specs and #specs > 0 and host) then return end
    if not self._fgFilterOverride then
        return self:_withFarmFilters(function() return self:ShowFarmingGuideMulti(class, specs, heroTalent, host) end)
    end
    local models, specMeta = {}, {}
    for i, sp in ipairs(specs) do
        local m = self:ShowFarmingGuide(class, sp, (i == 1) and heroTalent or nil, true, host, { modelOnly = true })
        if m then
            models[#models + 1] = { spec = sp, model = m }
            specMeta[sp] = self.SpecChipInfo and self.SpecChipInfo(class, sp) or { key = sp, name = sp }
        end
    end
    if #models == 0 then return end
    -- 背包 + 身上：副专精的件通常在包里
    local owned = {}
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 5 do
            local n = C_Container.GetContainerNumSlots(bag) or 0
            for s = 1, n do
                local info = C_Container.GetContainerItemInfo(bag, s)
                if info and info.itemID then owned[info.itemID] = true end
            end
        end
    end
    local RANK = { missing = 4, low = 3, filler = 2, owned = 1 }
    local merged = { cats = {}, multi = true, specs = specs }
    local catIdx, grpIdx = {}, {}
    for _, mm in ipairs(models) do
        for _, mc in ipairs(mm.model.cats) do
            local c = catIdx[mc.cat]
            if not c then
                c = { cat = mc.cat, label = mc.label, baseLabel = mc.baseLabel, clr = mc.clr, collapsible = mc.collapsible,
                      collapsed = mc.collapsed, totalMissing = 0, note = mc.note, groups = {} }
                catIdx[mc.cat] = c; grpIdx[mc.cat] = {}
                merged.cats[#merged.cats + 1] = c
            end
            for _, g in ipairs(mc.groups) do
                local gk = g.key or g.name
                local mg = grpIdx[mc.cat][gk]
                if not mg then
                    mg = { key = g.key, name = g.name, missing = 0, ord = g.ord, instanceId = g.instanceId, encounterId = g.encounterId,
                           isRaid = g.isRaid, isTierGroup = g.isTierGroup, items = {}, _byId = {} }
                    grpIdx[mc.cat][gk] = mg
                    c.groups[#c.groups + 1] = mg
                end
                if not mg.instanceId then mg.instanceId, mg.encounterId = g.instanceId, g.encounterId end
                for _, it in ipairs(g.items) do
                    -- ⛔ 只按 itemId 合并，别带 slotId：戒指/饰品/武器是成对槽，同一件在 A 专精落 11、在 B 专精落 12，
                    --    带 slotId 就变成两格（钟情 2026-09-13：「刷本助手会重复推荐…两个专精给推荐两次」）
                    local ik = tostring(it.itemId)
                    local state = it.state
                    if state == "missing" and owned[it.itemId] then state = "owned" end
                    local mi = mg._byId[ik]
                    if not mi then
                        mi = {}
                        for k2, v2 in pairs(it) do mi[k2] = v2 end
                        mi.state = state; mi.specs = {}
                        mg._byId[ik] = mi
                        mg.items[#mg.items + 1] = mi
                    elseif (RANK[state] or 0) > (RANK[mi.state] or 0) then
                        mi.state = state; mi.eqIlvl = it.eqIlvl; mi.trackCapped = it.trackCapped
                    end
                    mi.specs[#mi.specs + 1] = specMeta[mm.spec] or { key = mm.spec, name = mm.spec }
                end
            end
        end
    end
    for _, c in ipairs(merged.cats) do
        c.totalMissing = 0
        for _, mg in ipairs(c.groups) do
            mg._byId = nil
            mg.missing = 0
            for _, it in ipairs(mg.items) do if it.state ~= "owned" then mg.missing = mg.missing + 1 end end
            c.totalMissing = c.totalMissing + mg.missing
            table.sort(mg.items, function(a, b)
                if (a.state == "owned") ~= (b.state == "owned") then return a.state ~= "owned" end
                return (a.slotId or 0) < (b.slotId or 0)
            end)
        end
        if c.cat == "raid" then
            table.sort(c.groups, function(a, b)
                local ao, bo = a.ord or 99, b.ord or 99
                if ao ~= bo then return ao < bo end
                return (a.name or "") < (b.name or "")
            end)
        else
            table.sort(c.groups, function(a, b)
                if a.missing ~= b.missing then return a.missing > b.missing end
                return (a.name or "") < (b.name or "")
            end)
        end
        local base = c.baseLabel or c.cat
        if c.totalMissing > 0 then
            c.label = base .. " (" .. T("FG_NEED", "缺 ") .. c.totalMissing .. T("FG_PCS", " 件") .. ")"
        else
            c.label = base .. T("FG_COMPLETE", " (已齐全)")
        end
    end
    local cn = getLocalizedClassSpec()
    local names = {}
    for _, sp in ipairs(specs) do names[#names + 1] = (specMeta[sp] and specMeta[sp].name) or sp end
    local title = T("FG_TITLE", "刷本优先级") .. " — " .. (cn or class or "") .. "/" .. table.concat(names, " + ")
    self:ShowFarmingGuide(class, specs[1], heroTalent, true, host, { model = merged, title = title })
end

-- 专精芯片信息：本地化名 + 图标（刷本助手页的专精行 / 格子小图标共用）
function GearInsight.SpecChipInfo(class, specKey)
    local bd = GearInsight.BisData
    local sid = bd and bd.specIds and bd.specIds[(class or ""):upper() .. "/" .. (specKey or ""):upper()]
    local name, icon
    if sid and GetSpecializationInfoByID then
        local ok, _, nm, _, ic = pcall(GetSpecializationInfoByID, sid)
        if ok then name, icon = nm, ic end
    end
    if (not name or name == "") and GearInsight._msSpecNameFn then name = GearInsight._msSpecNameFn(sid, specKey) end
    return { key = specKey, specId = sid, name = name or specKey, icon = icon }
end
