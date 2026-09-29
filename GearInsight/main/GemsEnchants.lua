-- GearInsight/main/GemsEnchants.lua — 宝石附魔 + 制造业推荐
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, locName, preloadItem, setItemForIcon = H.T, H.locName, H.preloadItem, H.setItemForIcon

-- ── Gems & enchants section ─────────────────────────────────────────
-- Renders recommended gems (item IDs → live icon+name) and enchants
-- (enchant IDs → usage only; the client has no name API for enchants, so we
-- show the baked Chinese name when present, else a "(见攻略)" placeholder).
-- Appends into self._scrollChild starting at yOff; returns the new yOff.
function GearInsight:_renderGemsEnchants(data, yOff)
    local sc = self._scrollChild
    if not sc then return yOff end

    -- Always hide previously-shown gem/enchant widgets first, so a spec with no
    -- data (or fewer rows) doesn't leave stale text behind.
    local function hideAll()
        if self._geRows then for _, fs in pairs(self._geRows) do fs:Hide() end end
        if self._geGemBtns then for _, b in ipairs(self._geGemBtns) do b:Hide() end end
        if self._geConsBtns then for _, b in pairs(self._geConsBtns) do b:Hide() end end
        if self._geEnchBtns then for _, b in pairs(self._geEnchBtns) do b:Hide() end end
    end
    hideAll()

    local gems = data and data.gems
    local enchants = data and data.enchants
    if (not gems or #gems == 0) and (not enchants or next(enchants) == nil) then
        return yOff
    end

    local L = self.L or {}
    local gr = self.GearReader
    self._geRows = self._geRows or {}
    self._geGemBtns = self._geGemBtns or {}
    self._geConsBtns = self._geConsBtns or {}
    self._geEnchBtns = self._geEnchBtns or {}
    local rows = self._geRows

    -- Reusable single-line FontString row helper.
    local function fsRow(key, template)
        local fs = rows[key]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
            rows[key] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 6, yOff)
        fs:SetWidth(456)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)  -- these are fixed-height single-line rows; wrapping overlaps the next row
        fs:Show()
        return fs
    end

    -- Preload gem item data so icons/names resolve.
    if gems then
        for _, g in ipairs(gems) do preloadItem(g.id) end
    end

    -- Section header.
    do
        local hdr = fsRow("_geHeader", "GameFontNormalLarge")
        hdr:SetText(T("SECTION_GEMS_ENCH", "推荐宝石与附魔"))
        hdr:SetTextColor(0.6, 0.85, 1)
        yOff = yOff - 24
    end

    -- ── Gems ──
    if gems and #gems > 0 then
        local lbl = fsRow("_geGemLabel", "GameFontHighlightSmall")
        lbl:SetText(T("GEMS_LABEL", "宝石（按使用率）："))
        lbl:SetTextColor(0.8, 0.8, 0.8)
        yOff = yOff - 18

        -- Horizontal strip of icon buttons; up to 6.
        local MAX_GEMS = 6
        local x = 14
        local rowTop = yOff
        local maxShown = math.min(#gems, MAX_GEMS)
        for i = 1, maxShown do
            local g = gems[i]
            local btn = self._geGemBtns[i]
            if not btn then
                btn = CreateFrame("Button", nil, sc)
                btn:SetSize(24, 24)
                btn.texture = btn:CreateTexture(nil, "ARTWORK")
                btn.texture:SetAllPoints()
                btn.itemID = nil; btn.itemLink = nil; btn.currentItemID = nil
                btn._pct = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                btn._pct:SetPoint("LEFT", btn, "RIGHT", 2, 0)
                btn._pct:SetJustifyH("LEFT")
                btn:SetScript("OnEnter", function(s)
                    if not s.itemID then return end
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if s.itemLink then GameTooltip:SetHyperlink(s.itemLink)
                    else GameTooltip:SetItemByID(s.itemID) end
                    if s._usage then
                        GameTooltip:AddLine(T("GE_USAGE_PREFIX", "顶尖使用率: ") .. s._usage .. "%", 0.2, 1, 0.2)
                    end
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self._geGemBtns[i] = btn
            end
            setItemForIcon(btn, g.id, nil)
            btn._usage = g.usagePct
            -- Gem name shows in the hover tooltip (via item link); the strip itself
            -- only needs the usage %. Baked nameCn is the offline fallback.
            btn._pct:SetText(string.format("%.0f%%", g.usagePct or 0))
            btn._pct:SetTextColor(0.55, 0.85, 0.55)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", sc, "TOPLEFT", x, rowTop)
            btn:Show()
            -- Advance x by icon + pct text width estimate.
            local pctW = btn._pct:GetStringWidth() or 26
            x = x + 24 + 4 + pctW + 14
            -- Wrap to a new line if running past panel width.
            if x > 440 and i < maxShown then
                x = 14
                rowTop = rowTop - 28
            end
        end
        -- Hide unused gem buttons.
        for i = maxShown + 1, #self._geGemBtns do
            self._geGemBtns[i]:Hide()
        end
        yOff = rowTop - 30
    end

    -- ── Enchants ──
    if enchants and next(enchants) ~= nil then
        local lbl = fsRow("_geEnchLabel", "GameFontHighlightSmall")
        lbl:SetText(T("ENCH_LABEL", "附魔（按部位）："))
        lbl:SetTextColor(0.8, 0.8, 0.8)
        yOff = yOff - 18

        -- Live icon for an enchant: prefer its spell texture (most accurate), then a
        -- recipe itemId, then the baked icon name; "" if none resolves.
        local function enchIcon(e)
            if e.spell and C_Spell and C_Spell.GetSpellTexture then
                local t = C_Spell.GetSpellTexture(e.spell)
                if t and t ~= 0 then return "|T" .. t .. ":14:14|t " end
            end
            if e.item and C_Item and C_Item.GetItemIconByID then
                local t = C_Item.GetItemIconByID(e.item)
                if t and t ~= 0 then return "|T" .. t .. ":14:14|t " end
            end
            if e.icon and e.icon ~= "" then return "|TInterface\\Icons\\" .. e.icon .. ":14:14|t " end
            return ""
        end
        -- Push one enchant's real tooltip (spell or recipe item) into GameTooltip.
        local function enchTip(e)
            if e.spell and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(e.spell); return true end
            if e.item and GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.item); return true end
            return false
        end

        -- Stable slot order.
        local SLOT_ORDER = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
        local idx = 0
        for _, slotId in ipairs(SLOT_ORDER) do
            local choices = enchants[slotId]
            if choices and #choices > 0 then
                idx = idx + 1
                local fs = fsRow("_geEnch" .. idx, "GameFontNormalSmall")
                local slotKey = gr and gr:GetSlotKey(slotId) or nil
                local slotName = (slotKey and L[slotKey]) or ("SLOT#" .. slotId)
                -- Top choice + its usage; the baked Chinese name is usually empty,
                -- so fall back to a "(see guide)" placeholder rather than fabricating.
                local top = choices[1]
                local ename = (GearInsight.EnchName and GearInsight.EnchName(top, nil)) or (top.nameCn and top.nameCn ~= "" and top.nameCn) or T("ENCH_SEE_GUIDE", "(见攻略)")
                if ename == "" then ename = T("ENCH_SEE_GUIDE", "(见攻略)") end
                local pct = string.format("%.0f%%", top.usagePct or 0)
                local line = "· " .. slotName .. " — " .. enchIcon(top) .. ename .. "  |cFF8CD98C" .. pct .. "|r"
                -- Show a runner-up if a clearly distinct second option exists.
                local alt = (choices[2] and (choices[2].usagePct or 0) >= 15) and choices[2] or nil
                if alt then
                    local altName = (GearInsight.EnchName and GearInsight.EnchName(alt, nil)) or (alt.nameCn and alt.nameCn ~= "" and alt.nameCn) or T("ENCH_SEE_GUIDE", "(见攻略)")
                    if altName == "" then altName = T("ENCH_SEE_GUIDE", "(见攻略)") end
                    line = line .. "  |cFF888888/ " .. enchIcon(alt) .. altName .. " " .. string.format("%.0f%%", alt.usagePct or 0) .. "|r"
                end
                fs:SetText(line)
                fs:SetTextColor(0.85, 0.85, 0.85)

                -- Transparent overlay for hover tooltips (top, and alt if shown).
                local eb = self._geEnchBtns[idx]
                if not eb then
                    eb = CreateFrame("Button", nil, sc)
                    self._geEnchBtns[idx] = eb
                end
                eb._top, eb._alt, eb._ename = top, alt, ename
                eb:RegisterForClicks("LeftButtonUp")
                eb:SetScript("OnEnter", function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if s._top and (s._top.spell or s._top.item) then
                        enchTip(s._top)
                        if s._alt and (s._alt.spell or s._alt.item) then
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine(T("ENCH_ALT_TT", "次选："), 0.6, 0.6, 0.6)
                            local an = (GearInsight.EnchName and GearInsight.EnchName(s._alt, "")) or (s._alt.nameCn and s._alt.nameCn ~= "" and s._alt.nameCn) or ""
                            if an ~= "" then GameTooltip:AddLine(an, 0.8, 0.8, 0.8) end
                        end
                        GameTooltip:AddLine(" ")
                    end
                    GameTooltip:AddLine(T("ENCH_COPY_TT", "点击复制名字 → 到拍卖行搜索购买"), 1, 0.82, 0)
                    GameTooltip:Show()
                end)
                eb:SetScript("OnLeave", function() GameTooltip:Hide() end)
                eb:SetScript("OnClick", function(s)
                    local n = s._ename or ""
                    if n ~= "" then
                        GearInsight:ShowCopyText(n, string.format(T("CONS_COPY_HINT", "Ctrl+C 复制「%s」，到拍卖行搜索框粘贴购买"), n))
                    end
                end)
                eb:ClearAllPoints(); eb:SetPoint("TOPLEFT", 6, yOff); eb:SetSize(456, 15); eb:Show()
                yOff = yOff - 16
            end
        end
        -- Hide stale enchant rows from a previous (longer) spec render.
        local n = idx + 1
        while rows["_geEnch" .. n] do
            rows["_geEnch" .. n]:Hide()
            if self._geEnchBtns[n] then self._geEnchBtns[n]:Hide() end
            n = n + 1
        end
    end

    -- ── Consumables (shared across specs; from BisData.consumables) ──
    local cons = self.BisData and self.BisData.consumables
    if cons and #cons > 0 then
        local STAT_CN = { crit = T("STAT_CRIT", "暴击"), haste = T("STAT_HASTE", "急速"), mastery = T("STAT_MASTERY", "精通"), versatility = T("STAT_VERS", "全能") }
        local worstKey = self._worstStatKey

        -- Per-spec / per-scenario flask usage (from WCL top logs; BisData.consumableUsage,
        -- keyed by 2-part CLASS/SPEC). Lets us rank flasks by real meta usage and show %.
        local scen = (self._statMode == "mplusHigh" and "mplusHigh")
            or (self._statMode == "mplusFarm" and "mplusFarm") or "raid"
        local SCEN_CN = { raid = T("SCEN_RAID", "团本"), mplusHigh = T("SCEN_MH", "大秘境高层"), mplusFarm = T("SCEN_MF", "大秘境割草") }
        local usageKey = (data and data.className and data.specName)
            and (data.className .. "/" .. data.specName) or nil
        local cu = self.BisData and self.BisData.consumableUsage
        local urow = (cu and usageKey and cu[usageKey] and cu[usageKey][scen]) or nil
        local pu = self.BisData and self.BisData.potionUsage
        local purow = (pu and usageKey and pu[usageKey] and pu[usageKey][scen]) or nil
        -- 武器油使用率（BisData.oilUsage，来自 WCL 排行原始数据的临时附魔 id，玩家 2026-09-10 提「没有刀油推荐」）。
        -- imbue = 该专精主流是职业自带武器附魔（圣骑圣化仪式 / 萨满风怒等），这种专精不用油，要单独说明。
        local ou = self.BisData and self.BisData.oilUsage
        local ourow = (ou and usageKey and ou[usageKey] and ou[usageKey][scen]) or nil
        -- Per-row usage%: flasks by stat (urow), food by tier (urow.foodHearty/WellFed),
        -- potions by name (purow). 食物单道菜无法区分(共用 buff)，仅分高级/普通两档。
        local function rowPct(c)
            if c.stat and urow then return urow[c.stat] end
            if c.category == "食物" and urow then
                return (c.tier == "hearty") and urow.foodHearty or urow.foodWellFed
            end
            if c.category == "武器油" then return ourow and ourow[c.name] or nil end
            if purow then return purow[c.name] end
            return nil
        end

        local lbl = fsRow("_geConsLabel", "GameFontHighlightSmall")
        -- Single line only: a wrapping label would overlap the rows below it (only one
        -- line's height is reserved), hiding the first flasks' icons. Keep text short.
        lbl:SetWordWrap(false)
        if urow and (urow.n or 0) > 0 then
            lbl:SetText(string.format(T("CONS_LABEL_USAGE", "消耗品（合剂/药水使用率：%s·%d样本 · 点击复制名）"),
                SCEN_CN[scen] or scen, urow.n or 0))
        else
            lbl:SetText(T("CONS_LABEL", "消耗品（点击行复制名字去AH买）"))
        end
        lbl:SetTextColor(0.8, 0.8, 0.8)
        yOff = yOff - 18

        -- Group by category, preserving first-seen order.
        local order, byCat = {}, {}
        for _, c in ipairs(cons) do
            if not byCat[c.category] then byCat[c.category] = {}; order[#order + 1] = c.category end
            table.insert(byCat[c.category], c)
        end
        -- Rank flasks/potions by the current spec/scenario usage so the meta pick floats up.
        if urow or purow then
            for _, cat in ipairs(order) do
                table.sort(byCat[cat], function(a, b)
                    return (rowPct(a) or -1) > (rowPct(b) or -1)
                end)
            end
        end
        -- 药水低使用率兜底：最高使用率 <10% 时按行百分比不具参考性（多为 0% 凑数），
        -- 隐藏百分比并在分类头下注一行灰字说明，避免「最高才5%」式误导。
        local potionLow = false
        if byCat["药水"] then
            local maxp = 0
            for _, c in ipairs(byCat["药水"]) do
                local p = purow and purow[c.name]
                if p and p > maxp then maxp = p end
            end
            potionLow = (maxp < 10)
        end
        local ci = 0   -- FontString row index (category headers + item rows)
        local bi = 0   -- clickable copy-button index (item rows only)
        for _, cat in ipairs(order) do
            -- 食物按 tier 分组：盛宴 → 大师级单人(single_main) → 高级单人(single)
            local feast, single_main, single_items = {}, {}, {}
            if cat == "食物" then
                for _, c in ipairs(byCat[cat]) do
                    if c.tier == "single_main" then single_main[#single_main+1] = c
                    elseif c.tier == "single" then single_items[#single_items+1] = c
                    else feast[#feast+1] = c end
                end
            end
            local subgroups = (cat == "食物")
                and { { T("FOOD_GRP_FEAST","盛宴"), feast, urow and urow.food },
                      { T("FOOD_GRP_MAIN","大师级单人"), single_main, nil },
                      { T("FOOD_GRP_SINGLE","高级单人"), single_items, nil } }
                or { { cat, byCat[cat], (cat=="符文" and urow and urow.rune) } }

            -- Category header.
            ci = ci + 1
            local hfs = fsRow("_geCons" .. ci, "GameFontNormalSmall")
            local catExtra = ""
            if urow then
                if cat == "食物" and urow.food then catExtra = string.format("  |cFF888888(" .. T("CONS_FOOD_BUFF", "%.0f%% 上Buff") .. ")|r", urow.food)
                elseif cat == "符文" and urow.rune then catExtra = string.format("  |cFF888888(%.0f%%)|r", urow.rune) end
            end
            -- 2026-09-06 土耳其玩家截图：英文客户端里分类标题印成【合剂】。数据里 category 是中文键，这里翻一层。
            local CAT_T = { ["合剂"] = T("CONS_CAT_FLASK", "合剂"), ["药水"] = T("CONS_CAT_POTION", "药水"), ["食物"] = T("CONS_CAT_FOOD", "食物"),
                            ["符文"] = T("CONS_CAT_RUNE", "符文"), ["武器油"] = T("CONS_CAT_OIL", "武器油"), ["其他"] = T("CONS_CAT_OTHER", "其他") }
            local catLabel = CAT_T[cat] or cat
            local lb, rb = "【", "】"
            if (GearInsight.LOCALE or "") ~= "zhCN" and (GearInsight.LOCALE or "") ~= "zhTW" then lb, rb = "[ ", " ]" end
            hfs:SetText("|cFFE8A23D" .. lb .. catLabel .. rb .. "|r" .. catExtra)
            hfs:SetTextColor(0.9, 0.64, 0.24)
            yOff = yOff - 16

            -- 武器油：职业自带武器附魔的专精（圣骑/萨满）不用油 —— 说明一行，别让人以为「没推荐」
            if cat == "武器油" and ourow and ourow.imbue then
                ci = ci + 1
                local ofs = fsRow("_geCons" .. ci, "GameFontHighlightSmall")
                ofs:SetText("  |cFF888888" .. string.format(T("OIL_IMBUE_NOTE", "该专精用职业自带武器附魔：%s，不用油"), ourow.imbue) .. "|r")
                ofs:SetTextColor(0.55, 0.55, 0.55)
                yOff = yOff - 14
            end
            -- 药水低使用率说明行（潜伏条件见 potionLow 计算处）
            if cat == "药水" and potionLow then
                ci = ci + 1
                local nfs = fsRow("_geCons" .. ci, "GameFontHighlightSmall")
                nfs:SetText("  |cFF888888" .. T("POTION_LOW_NOTE", "该专精顶尖玩家战斗药水使用率低，按属性/需求自选即可") .. "|r")
                nfs:SetTextColor(0.55, 0.55, 0.55)
                yOff = yOff - 14
            end

            for _, sg in ipairs(subgroups) do
                local sgLabel, sgItems, sgPct = sg[1], sg[2], sg[3]
                if #sgItems > 0 then
                -- sub-header (盛宴/大师级单人/高级单人) only when food has multiple sub-groups
                if cat == "食物" then
                    ci = ci + 1
                    local shfs = fsRow("_geCons" .. ci, "GameFontNormalSmall")
                    local sgExtra = sgPct and string.format("  |cFF888888(" .. T("CONS_FOOD_BUFF", "%.0f%% 上Buff") .. ")|r", sgPct) or ""
                    shfs:SetText("  |cFFB0B0B0" .. sgLabel .. sgExtra .. "|r")
                    shfs:SetTextColor(0.7, 0.7, 0.7); yOff = yOff - 14
                end
                for _, c in ipairs(sgItems) do
                ci = ci + 1
                local fs = fsRow("_geCons" .. ci, "GameFontNormalSmall")
                -- Prefer the live item icon by itemId (always valid); some baked icon NAMES
                -- don't exist on this client and render blank. Fall back to the icon name.
                local iconTex = c.itemId and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(c.itemId)
                local ic
                if iconTex and iconTex ~= 0 then ic = "|T" .. iconTex .. ":14:14|t "
                elseif c.icon and c.icon ~= "" then ic = "|TInterface\\Icons\\" .. c.icon .. ":14:14|t "
                else ic = "" end
                -- Usage% — flasks by stat, potions by name (see rowPct).
                -- 药水低使用率时按行%不显示（多为 0%/5% 凑数，见 potionLow 说明行）。
                local pct = rowPct(c)
                if cat == "药水" and potionLow then pct = nil end
                if cat == "武器油" and ourow and ourow.imbue then pct = nil end
                local useTag = pct and string.format("  |cFFFFD100%.0f%%|r", pct) or ""
                -- Flag the flask matching the most-needed core stat: bright gold text + green
                -- "(补X)" tag (no leading glyph, so every row's icon stays column-aligned).
                local isMatch = (worstKey and c.stat == worstKey)
                local statTag = (c.stat and STAT_CN[c.stat]) and (" |cFF66BBFF[" .. STAT_CN[c.stat] .. "]|r") or ""
                if isMatch then statTag = statTag .. " |cFF33FF66(" .. string.format(T("CONS_FILL_STAT", "补%s"), STAT_CN[c.stat]) .. ")|r" end
                -- 食物高级档(Hearty/丰盛)= meta：金色高亮 + "(主流)"，与合剂"(补X)"一致。
                local isHeartyMeta = (c.category == "食物" and c.tier == "hearty")
                if isHeartyMeta then statTag = statTag .. " |cFF33FF66" .. T("CONS_FOOD_META", "(主流)") .. "|r" end
                -- 消耗品名：非中文客户端按 itemId 取本地化物品名（GetItemNameByID 未缓存时退回烤制中文名，下次刷新就有）
                local cname = c.name or ""
                if (GearInsight.LOCALE or "") ~= "zhCN" and c.itemId and C_Item and C_Item.GetItemNameByID then
                    local ln = C_Item.GetItemNameByID(c.itemId)
                    if ln and ln ~= "" then cname = ln elseif C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(c.itemId) end
                end
                fs:SetText("    " .. ic .. cname .. statTag .. useTag)
                if isMatch or isHeartyMeta then fs:SetTextColor(1, 0.95, 0.4) else fs:SetTextColor(0.85, 0.85, 0.85) end

                -- Clickable overlay: copy the consumable name to paste into the Auction House.
                bi = bi + 1
                local cb = self._geConsBtns[bi]
                if not cb then
                    cb = CreateFrame("Button", nil, sc)
                    cb:RegisterForClicks("LeftButtonUp")
                    cb:SetScript("OnEnter", function(s)
                        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                        -- With an itemId, show the real item tooltip (effect/stats); otherwise
                        -- just the copy hint. Always append the click-to-copy line.
                        if s._itemId then
                            GameTooltip:SetItemByID(s._itemId)
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine(T("CONS_COPY_TT", "点击复制名字 → 到拍卖行搜索购买"), 1, 0.82, 0)
                        else
                            GameTooltip:SetText(T("CONS_COPY_TT", "点击复制名字 → 到拍卖行搜索购买"), 1, 0.82, 0)
                        end
                        GameTooltip:Show()
                    end)
                    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    cb:SetScript("OnClick", function(s)
                        GearInsight:ShowCopyText(s._cname,
                            string.format(T("CONS_COPY_HINT", "Ctrl+C 复制「%s」，到拍卖行搜索框粘贴购买"), s._cname or ""))
                    end)
                    self._geConsBtns[bi] = cb
                end
                cb._cname = cname
                cb._itemId = c.itemId
                cb:ClearAllPoints()
                cb:SetPoint("TOPLEFT", 6, yOff)
                cb:SetSize(456, 15)
                cb:Show()
                yOff = yOff - 16
                end  -- for _, c in ipairs(sgItems)
                end  -- if #sgItems > 0
            end  -- for _, sg in ipairs(subgroups)
        end  -- for _, cat in ipairs(order)
        -- Hide stale consumable rows.
        local n = ci + 1
        while rows["_geCons" .. n] do
            rows["_geCons" .. n]:Hide()
            n = n + 1
        end
    end

    yOff = yOff - 6
    return yOff
end

-- Main-panel section: every crafted-gear slot present in the current BiS pool,
-- ranked
-- by each item's own WCL usage % in its slot (结合 BiS：只有槶位真是制造件当
-- BiS 时才会出现，不是"随便挑2件制造装"). Same ranking as the farming guide's
-- crafted group (GetTopCraftedPicks), just surfaced without opening a popup.
function GearInsight:_renderCraftedPicks(class, spec, heroTalent, yOff)
    local sc = self._scrollChild
    if not sc then return yOff end

    self._cpRows = self._cpRows or {}
    local function hideAll()
        for _, r in ipairs(self._cpRows) do r:Hide() end
        if self._cpHeader then self._cpHeader:Hide() end
    end

    local is2H = self:_detectIs2H()
    local picks = self:GetTopCraftedPicks(class, spec, heroTalent, is2H)
    if not picks or #picks == 0 then
        hideAll()
        return yOff
    end

    local L = self.L or {}
    local gr = self.GearReader

    if not self._cpHeader then
        self._cpHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self._cpHeader:SetWidth(456)
        self._cpHeader:SetJustifyH("LEFT")
    end
    self._cpHeader:ClearAllPoints()
    self._cpHeader:SetPoint("TOPLEFT", 6, yOff)
    self._cpHeader:SetText(T("SECTION_CRAFTED_PICKS", "制造推荐（结合BiS）"))
    self._cpHeader:SetTextColor(0.2, 1, 0.2)
    self._cpHeader:Show()
    yOff = yOff - 24

    for i, pick in ipairs(picks) do
        local row = self._cpRows[i]
        if not row then
            row = CreateFrame("Button", nil, sc)
            row:SetSize(456, 24)
            row:RegisterForClicks("LeftButtonUp")
            row.icon = CreateFrame("Frame", nil, row)
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", 0, 0)
            row.icon.texture = row.icon:CreateTexture(nil, "ARTWORK")
            row.icon.texture:SetAllPoints()
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", -4, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                if s.icon.itemLink then GameTooltip:SetHyperlink(s.icon.itemLink)
                elseif s.icon.itemID then GameTooltip:SetItemByID(s.icon.itemID) end
                if s._usage then
                    GameTooltip:AddLine(T("GE_USAGE_PREFIX", "顶尖使用率: ") .. s._usage .. "%", 0.2, 1, 0.2)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnClick", function(s)
                if self._tryChatLink then self._tryChatLink(s.icon) end
            end)
            self._cpRows[i] = row
        end
        -- setItemForIcon expects a button-shaped widget (.texture + .itemID/.itemLink).
        setItemForIcon(row.icon, pick.item.itemId, pick.item.bonusIDs, pick.item.link)
        row._usage = pick.item.usagePct and string.format("%.0f", pick.item.usagePct) or nil
        local slotKey = gr and gr:GetSlotKey(pick.slotId) or nil
        local slotName = (slotKey and L[slotKey]) or ("SLOT#" .. pick.slotId)
        local iName = locName(pick.item.itemId, pick.item.itemName) or ("#" .. pick.item.itemId)
        local usageTxt = pick.item.usagePct and string.format("  |cFF55E055%.0f%%|r", pick.item.usagePct) or ""
        row.text:SetText(slotName .. ": " .. iName .. "  [" .. (pick.item.ilvl or 0) .. "]" .. usageTxt)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 2, yOff)
        row:Show()
        yOff = yOff - 24
    end
    for i = #picks + 1, #self._cpRows do
        self._cpRows[i]:Hide()
    end

    -- 美化是工艺订单里加入的材料，不是把上面制造装备再按使用率编号。
    -- 只展示推荐的两种主选材料；第三种（狩猎符印）是武器的替代方案，不抢排名。
    if not self._cpEmbellish then
        local line = CreateFrame("Frame", nil, sc)
        line:SetSize(456, 20)
        line.label = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line.label:SetPoint("LEFT", 0, 0)
        line.label:SetJustifyH("LEFT")
        line.limit = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line.limit:SetJustifyH("LEFT")
        line.chips = {}
        for i = 1, 2 do
            local chip = CreateFrame("Button", nil, line)
            chip:SetHeight(18)
            chip.icon = chip:CreateTexture(nil, "ARTWORK")
            chip.icon:SetSize(18, 18); chip.icon:SetPoint("LEFT", 0, 0)
            chip.name = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            chip.name:SetPoint("LEFT", chip.icon, "RIGHT", 3, 0)
            chip.name:SetJustifyH("LEFT")
            chip:SetScript("OnEnter", function(s)
                if not s._itemId then return end
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:SetItemByID(s._itemId)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF8CC8FF最优美化排名 #" .. (s._rank or "?") .. "/2|r", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
            chip:SetScript("OnClick", function(s, button)
                if GearInsight.EmbellishReagentClick then GearInsight:EmbellishReagentClick(s._itemId, button) end
            end)
            line.chips[i] = chip
        end
        self._cpEmbellish = line
    end
    local mats = {}
    for _, reagent in ipairs(self.EMBELLISH_REAGENTS or {}) do
        if not reagent.alt then
            mats[#mats + 1] = "#" .. tostring(#mats + 1) .. " " .. self:EmbellishItemName(reagent.itemId)
        end
    end
    local line = self._cpEmbellish
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", 6, yOff)
    line.label:SetText("|cFF8CC8FF最优美化排名：|r")
    local prev = line.label
    for i, reagent in ipairs(self.EMBELLISH_REAGENTS or {}) do
        if not reagent.alt and line.chips[i] then
            local chip = line.chips[i]
            local name = self:EmbellishItemName(reagent.itemId)
            chip._itemId, chip._rank = reagent.itemId, i
            chip.icon:SetTexture(C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(reagent.itemId))
            chip.name:SetText(name)
            chip:SetWidth(21 + chip.name:GetStringWidth())
            chip:ClearAllPoints(); chip:SetPoint("LEFT", prev, "RIGHT", 6, 0)
            chip:Show()
            prev = chip
        end
    end
    for i = #mats + 1, #line.chips do line.chips[i]:Hide() end
    line.limit:ClearAllPoints(); line.limit:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    line.limit:SetText("|cFFFFD100全身最多 2 件生效|r")
    line:Show()
    yOff = yOff - 20

    yOff = yOff - 6
    return yOff
end
