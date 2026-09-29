-- GearInsight/main/PanelRefresh.lua — 主面板刷新 + 成对槽位（戒指/饰品）+ 武器形态
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, _LOCALE, getCN, locName, getLocalizedClassSpec, preloadItem, setItemForIcon, localizedSource, _openSourceJournal = H.T, H.LOCALE, H.getCN, H.locName, H.getLocalizedClassSpec, H.preloadItem, H.setItemForIcon, H.localizedSource, H.openSourceJournal

-- ── 属性优先级链（主行 + 「其他专精」悬浮共用）──────────────────────────
-- sorted = { {key=, val=}, ... } 已按目标值降序。
-- ⛔ 相邻两项只差零点几个百分点时，写成严格的 "A > B" 是**假精度**：
--   40 专精全量校对查出 28 处这种近似并列（守护德团本档 精通16.6% vs 全能16.3%，
--   差 0.3pp），并列项在噪音里换位还会让「团本/高层/割草」三档排序莫名翻转
--   —— 16 个专精有这现象（2026-08-31 用户：「帮我全职业校对下」）。
--   并列一律用 "≈" 连接，别让玩家为 0.3pp 去调配装。
function GearInsight.StatPriorityChain(sorted, sNames)
    local sumTgt = 0
    for _, s in ipairs(sorted) do sumTgt = sumTgt + s.val end
    local TIE_PP = 1.5                       -- 份额差不到 1.5 个百分点 = 并列
    local parts, seps = {}, {}
    for i, s in ipairs(sorted) do
        if s.val > 0 then
            parts[#parts + 1] = sNames[s.key] or s.key
            local nxt = sorted[i + 1]
            if nxt and nxt.val > 0 then
                local pp = (sumTgt > 0) and ((s.val - nxt.val) / sumTgt * 100) or 99
                seps[#seps + 1] = (pp < TIE_PP) and " ≈ " or " > "
            end
        end
    end
    local chain = parts[1] or ""
    for i = 2, #parts do chain = chain .. (seps[i - 1] or " > ") .. parts[i] end
    return chain
end

-- BisData.specs 的键 ("SHAMAN/ELEMENTAL/Farseer") → 「元素 (先知)」；英雄天赋按客户端语言（zhCN 反查 HERO_CN，其余英文码）
function GearInsight.SpecKeyLabel(key)
    local bd = GearInsight.BisData
    local d = bd and bd.specs and bd.specs[key]
    if not d then return key or "?" end
    local c = d.className or ""
    local sid = bd.specIds and bd.specIds[c .. "/" .. (d.specName or "")]
    local sname = GearInsight._msSpecNameFn and GearInsight._msSpecNameFn(sid, d.specName) or d.specName or "?"
    local hero = d.heroTalent or ""
    if hero ~= "" then
        if _LOCALE == "zhCN" and bd.heroCodeToCN and bd.heroCodeToCN[hero] then hero = bd.heroCodeToCN[hero] end
        sname = sname .. " (" .. hero .. ")"
    end
    return sname
end

-- 本职业全部专精键（含英雄天赋分支），按键名排序；给「查看专精」下拉用
function GearInsight.ClassSpecKeys(class)
    local bd = GearInsight.BisData
    if not (bd and bd.specs and class) then return {} end
    local c = class:upper(); local keys = {}
    for key, d in pairs(bd.specs) do if d.className == c then keys[#keys + 1] = key end end
    table.sort(keys)
    return keys
end

-- 本职业其余专精（含英雄天赋分支）在 mode 档的优先级行：{ {"元素 (先知)", "暴击 > 精通 > 急速"}, ... }
-- 只按占比排序（不需要玩家评级），⛔ 不碰 bisBySlot，免得把 BisPack 的惰性解码打穿。
function GearInsight.OtherSpecPriorityRows(class, curData, mode, sNames)
    local bd = GearInsight.BisData
    if not (bd and bd.specs and class) then return {} end
    local c = class:upper()
    local keys = {}
    for key, d in pairs(bd.specs) do
        if d.className == c and d ~= curData then keys[#keys + 1] = key end
    end
    table.sort(keys)
    local rows = {}
    for _, key in ipairs(keys) do
        local d = bd.specs[key]
        local pct = d.targetStatPercents
        if mode == "mplusHigh" then pct = d.targetStatPercentsMplus or pct
        elseif mode == "mplusFarm" then pct = d.targetStatPercentsMplusFarm or d.targetStatPercentsMplus or pct
        elseif mode == "mplusCommon" then pct = d.targetStatPercentsMplusCommon or d.targetStatPercentsMplusFarm or d.targetStatPercentsMplus or pct end
        if pct then
            local sorted = {}
            for _, sk in ipairs({ "crit", "haste", "mastery", "versatility" }) do sorted[#sorted + 1] = { key = sk, val = pct[sk] or 0 } end
            table.sort(sorted, function(a, b) return a.val > b.val end)
            rows[#rows + 1] = { GearInsight.SpecKeyLabel(key), GearInsight.StatPriorityChain(sorted, sNames) }
        end
    end
    return rows
end

-- Paired slots share one BiS pool: rings (11/12), trinkets (13/14). The data
-- splits them per slot, but slot 2 only logs whatever players happen to keep in
-- the off slot (sparse, low usage). So we merge both slots into one pool ranked
-- by usage: slot 1 recommends #1, slot 2 recommends #2, and both show the same
-- top-5 list.
local PAIR_SLOT = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }
-- ui/GearMap.lua 要复用这几个本文件内的局部帮手（图标异步加载 / 本地化名 / 来源串），
-- 通过这张表暴露，⛔别再在别处复制一份 setItemForIcon。
GearInsight._h = { setItemForIcon = setItemForIcon, locName = locName, getCN = getCN,
                   localizedSource = localizedSource, preloadItem = preloadItem }

-- ── 武器形态(weapon config) ──────────────────────────────────────────────
-- WoW 武器槽多模态：主手(16)/副手(17)被"形态"耦合，不能当独立槽各推一件。
-- 形态: 2h(双手,副手空) / titansGrip(双2H狂怒) / dualWield(双持) / 1hShield(单手+盾)
--       / 1hOff(单手+法器) / ranged(远程,副手空)。
-- 客户端 INVTYPE 枚举 -> 与 BisData 候选 handedness 一致的标签。
local INVTYPE_HAND = {
    [17] = "2h",        -- INVTYPE_2HWEAPON
    [13] = "1h", [21] = "1h",            -- WEAPON / WEAPONMAINHAND
    [22] = "offWeapon", -- WEAPONOFFHAND
    [23] = "frill",     -- HOLDABLE
    [14] = "shield",    -- SHIELD
    [15] = "ranged", [26] = "ranged", [25] = "ranged",  -- RANGED / RANGEDRIGHT / THROWN
}
local function _itemHand(itemId)
    if not itemId or not (C_Item and C_Item.GetItemInventoryTypeByID) then return nil end
    return INVTYPE_HAND[C_Item.GetItemInventoryTypeByID(itemId)]
end
-- 从实戴主手/副手判定玩家当前武器形态；判不出返回 nil（让调用方回退 meta 主流）。
-- specKey = 当前查看的「职业/专精」。狂暴战天生泰坦之握：主手双手时副手照样能拿（双手或单手），
--   ⛔ 不能因为副手暂时空着 / 拿的单手就判成「双手形态」把副手推荐整个藏掉（09-23 QQ 群 M.bin：「狂暴战没有副手推荐」）。
local function _playerWeaponConfig(snapshot, specKey)
    if not (snapshot and snapshot.equipped) then return nil end
    local mh, oh = snapshot.equipped[16], snapshot.equipped[17]
    local mhH = (mh and not mh.empty) and _itemHand(mh.itemId) or nil
    local ohH = (oh and not oh.empty) and _itemHand(oh.itemId) or nil
    if mhH == "ranged" then return "ranged" end
    if mhH == "2h" then return (ohH == "2h" or specKey == "WARRIOR/FURY") and "titansGrip" or "2h" end
    if mhH == "1h" then
        if ohH == "shield" then return "1hShield" end
        if ohH == "frill" then return "1hOff" end
        if ohH == "offWeapon" or ohH == "1h" then return "dualWield" end
    end
    return nil
end
-- 形态 -> 该形态有无副手 / 主手该是什么手数 / 副手该是什么手数。
local WCONF_HASOFF = { ["2h"] = false, ranged = false, titansGrip = true,
    dualWield = true, ["1hShield"] = true, ["1hOff"] = true }
local WCONF_MAINHAND = { ["2h"] = "2h", titansGrip = "2h", ranged = "ranged",
    dualWield = "1h", ["1hShield"] = "1h", ["1hOff"] = "1h" }
local WCONF_OFFHAND = { titansGrip = "2h", dualWield = "offWeapon",
    ["1hShield"] = "shield", ["1hOff"] = "frill" }
-- 按 handedness 过滤候选池(主手/副手各取符合形态的)。候选无 handedness 标签时保留(容错)。
-- ⛔ QQ 群「思想」2026-09-24：身上单手+副手，主手推了双手法杖（制造业，没带 handedness 标签 → 被当「符合」留下），
--    副手又照推一件 —— 自相矛盾。没标签就问客户端 GetItemInventoryTypeByID。
local function _handOf(e)
    return e and (e.handedness or _itemHand(e.itemId)) or nil
end
local function _filterByHand(cand, wantHand, altHand)
    if not cand or not wantHand then return cand end
    local out = {}
    for _, e in ipairs(cand) do
        local h = _handOf(e)
        if (not h) or h == wantHand or (altHand and h == altHand) then out[#out + 1] = e end
    end
    return (#out > 0) and out or cand
end

local function _mergePairPool(a, b)
    local byId, order = {}, {}
    local function add(list)
        if type(list) ~= "table" then return end
        for _, e in ipairs(list) do
            local id = e.itemId
            local prev = byId[id]
            if not prev then
                byId[id] = e
                order[#order + 1] = e
            elseif (e.planRank and not prev.planRank) or (not prev.planRank and (e.usagePct or 0) > (prev.usagePct or 0)) then
                byId[id] = e
                for i, o in ipairs(order) do
                    if o.itemId == id then order[i] = e break end
                end
            end
        end
    end
    add(a); add(b)
    -- 方案件（planRank）排最前，其余按使用率 —— 与 ui/TooltipHook.lua mergePool 同一口径
    table.sort(order, function(x, y)
        local px, py = x.planRank or 99, y.planRank or 99
        if px ~= py then return px < py end
        return (x.usagePct or 0) > (y.usagePct or 0)
    end)
    return order
end

-- ⛔⛔ 成对槽位(戒指 11/12、饰品 13/14)的**选件决策只此一份**。
--
-- 2026-09-07 QQ 群玩家报：术士的同一个部位，角色属性页显示一件、插件主面板显示另一件，
-- 而 Top5 榜跟属性页对齐。根因不是数据，是 `ui/PaperDollBis.lua` 当年**照抄了一份**
-- 选件逻辑，之后主面板陆续按玩家反馈加了三条规则，抄的那份一条都没跟上：
--   ① 戒指禁止降级推荐(ringGuard)；② 饰品尽量凑一主动一被动；③ 已穿要达到该件装等才算毕业。
-- 于是属性页给出的是池子里的原始 #1/#2 —— 跟 Top5 天然一致，跟主面板必然不一致。
--
-- ⭐ 判据不是「有没有共用排序器」，是**「两处拿到的结论是不是同一个函数算出来的」**
--   （同族教训见 [[same-data-three-renderers-diverge]]：0.71.0 那次共用了排序器仍然分歧，
--    因为喂进去的集合不同）。⛔ 以后要改成对槽位的挑件规则，只准改这里。
--
-- 入参全部显式传，不碰任何外部状态；返回 top(推荐哪件) 与 skipAsComplete(算不算已毕业)。
function GearInsight.PickPairedSlot(slotId, cand, cId, cIlvl, slotGrad, eqO, recO)
    if type(cand) ~= "table" or #cand == 0 then return nil, false end
    cIlvl = cIlvl or 0
    slotGrad = slotGrad or 0
    -- 主槽要池子 #1，副槽要 #2（两槽同池排名，避免两边推同一件）
    local desiredRank = (slotId == 12 or slotId == 14) and 2 or 1
    local top = cand[desiredRank] or cand[1]
    local skipAsComplete = false

    local p1, p2 = cand[1], cand[2]
    local id1 = p1 and p1.itemId
    local id2 = p2 and p2.itemId
    if cId and (cId == id1 or cId == id2) then
        -- Holding the BiS piece only counts as done if it also
        -- meets the item's own ilvl (or the slot's graduation floor) —
        -- a low-ilvl copy (e.g. a 250 trinket vs its 298 target) still
        -- needs upgrading.
        local matched = (cId == id1) and p1 or p2
        local mIlvl = (matched and matched.ilvl) or 0
        -- ⛔ 与非成对部位同口径（Pluto 2026-09-12：「已经是毕业装备了，角色面板右上角还显示这件，只有戒指和饰品这样」）：
        --   穿着的就是前 2 里的那件 = 已毕业；装等没到只是「可升级」，由主面板 upgradeTo / 轨道封顶那套去说，
        --   角色面板打勾。原来这里装等没到就不算毕业，而头/胸等部位同款低装等照样打勾，两边打架。
        skipAsComplete = true
        if not (mIlvl == 0 or cIlvl >= mIlvl or (slotGrad > 0 and cIlvl >= slotGrad)) then
            top = matched   -- 推荐目标仍是这件的满装等版本（主面板显示「已毕业 · 可升级 A → B」）
        end
    else
        -- An item is unusable for this slot if the sibling slot
        -- already wears it, or was just recommended it — otherwise
        -- both slots would suggest the same single pool item (e.g.
        -- when raid is excluded and only one m+ trinket remains).
        -- 戒指(11/12)价值≈装等(副属性总量)，和护甲一样禁止降级推荐
        -- (实证：276 团本BOE 在 M+ 参照系盖过身上 289 #3)；
        -- 饰品(13/14)价值在特效，保留按使用率推荐低装等件。
        local ringGuard = (slotId == 11 or slotId == 12)
        local function usable(e)
            if not e or e.itemId == eqO or e.itemId == recO then return false end
            if ringGuard and cIlvl > 0 and (e.ilvl or 0) < cIlvl then return false end
            return true
        end
        -- primary slot prefers #1, secondary prefers #2
        local a, b = p1, p2
        if slotId == 12 or slotId == 14 then a, b = p2, p1 end

        -- 饰品尽量凑「一主动一被动」（2026-08-27 用户实证：奥法被推荐
        -- 了两个主动饰品）。两个主动会抢同一个爆发窗口，收益重叠；
        -- 数据里 onUse=true 表示「使用：」类。只在**池子里真的有**
        -- 互补件时才换，换不到就维持原来的使用率顺序，不硬凑。
        if slotId == 13 or slotId == 14 then
            local otherUse
            for _, e in ipairs(cand) do
                if e.itemId == (recO or eqO) then otherUse = e.onUse break end
            end
            if otherUse ~= nil and a and a.onUse == otherUse then
                for _, e in ipairs(cand) do
                    if e.onUse ~= nil and e.onUse ~= otherUse and usable(e) then
                        a = e
                        break
                    end
                end
            end
        end
        if usable(a) then top = a
        elseif usable(b) then top = b
        else
            -- 严判：前2不可用不再直接算毕业，顺延池子里下一个可用候选；
            -- 整个池子都不可用才视为无目标（真·毕业）。
            top = nil
            for ci = 3, #cand do
                if usable(cand[ci]) then top = cand[ci]; break end
            end
            if not top then top = p1 or p2; skipAsComplete = true end
        end
    end
    return top, skipAsComplete
end

-- ui/PaperDollBis.lua 要用同一个合池器，⛔别再抄第二份。
GearInsight.MergePairPool = _mergePairPool


-- ── Panel: refresh ──────────────────────────────────────────────────
-- 身上这一格的升级轨道：返回 cur, max, name（读不到 → nil）。
-- 走 C_TooltipInfo（⛔别扫隐藏 GameTooltip），只看前 6 行，⛔避开「耐久度 44/55」那行。
-- 用户 Mr9468 2026-09-11：「我现在的是 295 的套装手，但是不推荐升级的坯子」——老兵 6/6 已经封顶，
-- 「可升级 295 → 334」是假话：这条轨道永远到不了 334，得换更高轨道的坯子再转。
local _UPG_PAT
function GearInsight:SlotUpgradeTrack(slotId)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slotId)
    if not (ok and data and data.lines) then return nil end
    if issecretvalue and issecretvalue(data.lines) then return nil end
    if _UPG_PAT == nil then
        local fmt = ITEM_UPGRADE_TOOLTIP_FORMAT
        if type(fmt) == "string" and fmt:find("%%d") then
            -- "升级: %s %d/%d" → 转成捕获模式
            local esc = fmt:gsub("%p", "%%%0")
            esc = esc:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
            _UPG_PAT = "^%s*" .. esc .. "%s*$"
        else
            _UPG_PAT = false
        end
    end
    local dur = DURABILITY_TEMPLATE and DURABILITY_TEMPLATE:gsub("%%d", ""):gsub("%s", "") or nil
    for i = 2, 6 do
        local line = data.lines[i]
        if not line then break end
        local ok2, txt = pcall(function() return line.leftText end)
        if ok2 and type(txt) == "string" and not (issecretvalue and issecretvalue(txt)) then
            if _UPG_PAT then
                local nm, a, b = txt:match(_UPG_PAT)
                if a then return tonumber(a), tonumber(b), nm end
            end
            -- 兜底：形如「升级：老兵 6/6」；排除耐久行。⛔ 冒号用 plain find 定位（全角冒号 3 字节，字符类会切坏汉字）
            local c1 = txt:find("：", 1, true)
            local c2 = txt:find(":", 1, true)
            local cpos, clen = nil, 1
            if c1 and (not c2 or c1 < c2) then cpos, clen = c1, 3 elseif c2 then cpos, clen = c2, 1 end
            if cpos and not (dur and txt:gsub("%s", ""):find(dur, 1, true)) then
                local nm, a, b = txt:sub(cpos + clen):match("^%s*(.-)%s*(%d+)%s*/%s*(%d+)%s*$")
                if a then return tonumber(a), tonumber(b), nm end
            end
        end
    end
    return nil
end

-- ⛔ 总览页整体 pcall（抖音用户 2026-09-12 截图：副本里打开面板，专精/装等/属性条/建议全空、一个字都没有——
--    多数玩家关着脚本错误，中途炸了就是一片空白）。炸了至少把原因写在页面和聊天框里，别让人以为插件坏了。
function GearInsight:RefreshPanel()
    local ok, err = pcall(self._RefreshPanelImpl, self)
    if ok then return end
    local msg = tostring(err)
    if self._ovGap then
        self._ovGap:SetText("|cFFFF6060" .. T("OV_REFRESH_ERR", "面板刷新出错：副本 / 战斗里部分数据读不到，出本后点「刷新数据」再试") .. "|r")
    end
    if self.Print and self._lastRefreshErr ~= msg then
        self._lastRefreshErr = msg
        self:Print(T("OV_REFRESH_ERR_CHAT", "[总览] 刷新出错：") .. msg:sub(1, 240))
    end
end

function GearInsight:_RefreshPanelImpl()
    if not self._panelFrame or not self._upgradeRows or not self._scrollChild then
        return
    end
    -- 首次打开时 GearMap 的容器还没有创建，旧列表会先执行 Show()，直到用户再点一次
    -- 「装备图」触发完整刷新才被隐藏。渲染一开始就锁定当前模式，列表控件从源头不再闪现。
    local mapMode = self.GearMapActive and self:GearMapActive()
    local function hideLegacyRows()
        if self._upgradeRows then for _, r in ipairs(self._upgradeRows) do r:Hide() end end
        if self._slotHeaders then for _, h in pairs(self._slotHeaders) do h:Hide() end end
        if self._emptyUpgradeLabel then self._emptyUpgradeLabel:Hide() end
        if self._gradHeader then self._gradHeader:Hide() end
        if self._gradRows then for _, r in ipairs(self._gradRows) do r:Hide() end end
    end
    if mapMode then hideLegacyRows() end
    -- ⛔ 原来这里战斗中直接 return（「CreateFrame 在锁定期会炸」——那是旧版消耗品按钮用安全模板时的事，
    --    总览页现在没有任何安全模板，普通 Frame/FontString 战斗中随便建）。后果是**战斗中第一次打开面板整页空白**
    --    （抖音用户 2026-09-12 副本里截图、枫叶虎鲸 2026-09-13 大秘境里截图）。现在战斗中照常渲染；
    --    副本里读不到的数值（secret）由外层 pcall 兜住，页面写原因而不是空着。

    local L = self.L or {}
    -- ⛔⛔ 用 GetLastSnapshot() 会读到过期数据：升级轨道（勇士/英雄/神话锻造）在 NPC/大宝库
    -- 那边点一下就生效，同一件装备原地涨装等——不换装、不切专精、不进出战斗，
    -- 一个都不触发 SavedVars:Save() 挂的那几个事件（PLAYER_EQUIPMENT_CHANGED 等），
    -- snapshot 就停在升级前那次。玩家反馈：「一个史诗顶满334，C键角色栏（本面板）右上角还是321」。
    -- Save() 本身很便宜（GearReader:ReadAll 现读 16 格 + GetAverageItemLevel），
    -- 面板刷新本就是「用户看一眼」的低频路径，直接现存一份，别信上一次留下的。
    local snapshot = self.SavedVars and self.SavedVars:Save() or (self.SavedVars and self.SavedVars:GetLastSnapshot())
    local class, spec, htal, ilvl
    if snapshot then
        class = snapshot.class; spec = snapshot.spec; htal = snapshot.heroTalent
        ilvl = math.floor((snapshot.itemLevel or snapshot.averageItemLevel or 0) + 0.5)
    end
    if not class or not spec then
        if self.StatReader then
            local s = self.StatReader:ReadAll()
            class = s.class; spec = s.spec; htal = s.heroTalent
        end
    end

    local data = self.BisData and self.BisData:GetSpecData(class, spec, htal)
    local tIlvl = data and data.graduationItemLevel or 0

    -- Decide whether to use live Companion recommendations or static BiS data
    local usingLiveRecs = false
    local liveBisBySlot = nil
    -- 「我的方案」启用时，方案优先于 Companion 实时推荐（core/BisPlan.lua；模块不在 = 老行为）
    local planOn = self.BisPlan and data and self.BisPlan.ActiveFor(data)
    if not planOn and self.RecsReader and self.RecsReader:HasFreshRecs() then
        liveBisBySlot = self.RecsReader:GetBisBySlot()
        if liveBisBySlot then
            usingLiveRecs = true
        end
    end

    -- Choose the bisBySlot source for the upgrade panel
    local activeBisBySlot = usingLiveRecs and liveBisBySlot or (data and data.bisBySlot)
    local maxObservedIlvl = tIlvl
    if activeBisBySlot then
        for _, items in pairs(activeBisBySlot) do
            for _, entry in ipairs(items) do
                if (entry.ilvl or 0) > maxObservedIlvl then maxObservedIlvl = entry.ilvl end
            end
        end
    end

    -- Preload item icons/names for whichever source we'll display
    if activeBisBySlot then
        for _, items in pairs(activeBisBySlot) do
            for _, entry in ipairs(items) do
                preloadItem(entry.itemId)
            end
        end
    end

    -- ── Overview ──────────────────────────────────────────────────
    if self._ovSpec then
        local cn, sn = getLocalizedClassSpec()
        local sk = string.format("%s %s", cn or class or "?", sn or spec or "?")
        if htal then sk = sk .. " (" .. htal .. ")" end
        self._ovSpec:SetText(T("OV_SPEC", "专精: ") .. sk)
    end
    if self._ovIlvl then
        self._ovIlvl:SetText(T("OV_ILVL", "当前装等: ") .. ilvl)
    end
    if self._ovGap then
        if tIlvl > 0 then
            -- ⛔ 别用 math.max(0, …) 把负数压成 0：装等超过毕业线时会显示「差距: 0」，
            --    看起来像「刚好毕业」，其实是超了（2026-08-26 用户反馈）。超了就明说超了。
            local diff = tIlvl - ilvl
            local gap = math.max(0, diff)
            local c = diff <= 0 and "|cFF00FF00" or "|cFFFF6600"
            -- 难度档非史诗时标注（装等已按档换算，见 core/TierView.lua）
            local tierTag = (self.GearTierStep and self:GearTierStep() > 0)
                and (" |cFF55BBFF[" .. self:GearTierLabel() .. T("TIER_TAG", "档") .. "]|r") or ""
            local gapText = (diff < 0)
                and (T("OV_OVER", "已超毕业线: ") .. c .. "+" .. (-diff) .. "|r")
                or  (T("OV_GAP", "差距: ") .. c .. gap .. "|r")
            -- #22（2026-08-31 抖音 西野已无恶：「毕业装等321是不是不太对？」）——
            -- 321 没错：它是当季团本史诗**掉落基准**（数据现算的众数），拿到手还能走
            -- 升级轨道到更高。错的是措辞没把「基准 vs 满轨」说清，这里补上。
            -- 还在升级的号（09-24 截图：装等 72 显示「差距 262」）：满级前跟毕业线比没有意义，改成说明
            local lvl = UnitLevel and UnitLevel("player") or 0
            local maxLvl = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 0
            if maxLvl > 0 and lvl > 0 and lvl < maxLvl then
                gapText = "|cff8a93a6" .. string.format(T("OV_LEVELING", "升级中 %d/%d：满级后再看差距"), lvl, maxLvl) .. "|r"
            end
            self._ovGap:SetText(T("OV_GRAD", "常规毕业线: ") .. c .. tIlvl .. "|r" .. tierTag
                .. " |cff8a93a6· " .. T("OV_WCL_MAX", "WCL最高实穿: ") .. maxObservedIlvl .. "|r"
                .. "  " .. gapText)
        else
            self._ovGap:SetText(T("OV_NODATA", "暂无该专精的BiS数据"))
        end
    end

    -- Stat targets follow the 团本/大秘境 toggle; fall back to raid when the M+ set is absent.
    -- 3-way stat target source: raid / 大秘境高层(Mplus) / 大秘境割草(MplusFarm).
    -- Each M+ mode falls back to high, then raid, when its data is absent.
    -- ⛔ 存一份当前专精数据：坡子弹窗刷新时要按**当时**的模式重算属性占比，
    --   不能用弹窗打开那一刻的快照（否则切「使用率参照」后排序不变）。
    self._curSpecData = data
    -- 「查看专精」（09-22 用户）：属性区可以切到本职业另一个专精的目标，用你现在的评级算达成度；
    -- ⛔ 只影响属性优先级 + 四条达成度，BiS 列表 / 刷本 / 坯子仍按真实专精（data）。切了职业或数据没了自动回落。
    local sdata = data
    if self._statSpecKey and self.BisData and self.BisData.specs then
        local sd = self.BisData.specs[self._statSpecKey]
        if sd and data and sd.className == data.className and sd ~= data then sdata = sd else self._statSpecKey = nil end
    end
    self._statSpecData = sdata
    if self._updStatSpecBtn then self:_updStatSpecBtn() end
    local statPct = sdata and sdata.targetStatPercents
    local statRat = sdata and sdata.targetStatRatings
    if sdata then
        if self._statMode == "mplusHigh" then
            statPct = sdata.targetStatPercentsMplus or statPct
            statRat = sdata.targetStatRatingsMplus or statRat
        elseif self._statMode == "mplusFarm" then
            statPct = sdata.targetStatPercentsMplusFarm or sdata.targetStatPercentsMplus or statPct
            statRat = sdata.targetStatRatingsMplusFarm or sdata.targetStatRatingsMplus or statRat
        elseif self._statMode == "mplusCommon" then
            -- 常规档只切换属性绿字。当前没有独立常规样本时按 +12 档回退，
            -- 不弹装备参考窗口，也不借用团本目标。
            statPct = sdata.targetStatPercentsMplusCommon or sdata.targetStatPercentsMplusFarm or sdata.targetStatPercentsMplus or statPct
            statRat = sdata.targetStatRatingsMplusCommon or sdata.targetStatRatingsMplusFarm or sdata.targetStatRatingsMplus or statRat
        end
    end

    -- 「我的方案」启用时，属性目标跟方案走（用户 09-23「包括属性都要跟随设定」）：
    --   目标 = 方案各件副属性的占比（评级占比口径），不用 WCL 绝对评级。
    self._statFromPlan = nil
    if self.BisPlan and sdata then
        local okP, pp = pcall(self.BisPlan.StatPercents, sdata)
        if okP and pp then statPct, statRat = pp, nil; self._statFromPlan = true end
    end

    -- Stat priority + most-needed stat summary — 以"WCL 顶尖玩家属性占比 × 你的副属性总量"为目标
    -- (可达、与装等无关；不用 WCL 绝对评级，那受 proc 污染且跨装等不可比)。
    self._worstStatKey = nil
    if self._ovStatPri and sdata and (statRat or statPct) then
        local sNames = { crit = T("STAT_CRIT", "暴击"), haste = T("STAT_HASTE", "急速"), mastery = T("STAT_MASTERY", "精通"), versatility = T("STAT_VERS", "全能") }
        local sec = (snapshot and snapshot.secondary) or {}
        local secRating = (snapshot and snapshot.secondaryRating) or {}
        local ratingTotal = 0
        for _, statKey in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            ratingTotal = ratingTotal + (secRating[statKey] or 0)
        end
        -- 目标评级 = WCL 平均(statRat)，回退 占比×你的总量。
        local function targetRatingOf(sk)
            if statRat and statRat[sk] then return statRat[sk] end
            if statPct and statPct[sk] and ratingTotal > 0 then
                return math.floor(statPct[sk] / 100 * ratingTotal + 0.5)
            end
            return 0
        end
        local tgt = {}
        local maxTgt = 0
        for _, sk in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            tgt[sk] = targetRatingOf(sk)
            if tgt[sk] > maxTgt then maxTgt = tgt[sk] end
        end
        -- 优先级排序：按 WCL 平均评级从高到低（这就是该专精的属性主次）。
        local sorted = {}
        for _, sk in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            sorted[#sorted + 1] = { key = sk, val = tgt[sk] }
        end
        table.sort(sorted, function(a, b) return a.val > b.val end)
        -- 最缺：核心属性里，相对 WCL 均值缺口比例最大的那个（评级 < 均值90%）。
        local worstName, worstRatio, worstKey = nil, 1, nil
        for sk, t in pairs(tgt) do
            local isCore = not (maxTgt > 0 and t < maxTgt * 0.30)
            if isCore and t > 0 then
                local ratio = (secRating[sk] or 0) / t
                if ratio < 0.9 and ratio < worstRatio then
                    worstRatio = ratio
                    worstName = sNames[sk] or sk
                    worstKey = sk
                end
            end
        end
        self._worstStatKey = worstKey
        local chain = GearInsight.StatPriorityChain(sorted, sNames)
        local summary = T("STAT_PRIORITY", "属性优先级: ") .. chain
        if self._statFromPlan then summary = "|cffe6c56b" .. T("BP_STAT_TAG", "[我的方案]") .. "|r " .. summary end
        if sdata ~= data then summary = "|cFF55BBFF[" .. GearInsight.SpecKeyLabel(self._statSpecKey) .. "]|r " .. summary end
        if worstName then
            summary = summary .. string.format(T("STAT_WORST_R", "  |  最缺: %s(%.0f%%达标)"), worstName, worstRatio * 100)
        else
            summary = summary .. T("STAT_OK", "  |  属性已达 WCL 均值")
        end
        self._ovStatPri:SetText(summary)
        -- 面板窄（列表模式 520）放不下「最缺」：只留优先级，最缺在下面属性条里本来就有红字「不足」
        if worstName and self._ovStatPri.IsTruncated and self._ovStatPri:IsTruncated() then
            local short = T("STAT_PRIORITY", "属性优先级: ") .. chain
            if self._statFromPlan then short = "|cffe6c56b" .. T("BP_STAT_TAG", "[我的方案]") .. "|r " .. short end
            if sdata ~= data then short = "|cFF55BBFF[" .. GearInsight.SpecKeyLabel(self._statSpecKey) .. "]|r " .. short end
            self._ovStatPri:SetText(short)
        end
        -- 悬浮：本职业其他专精（含英雄天赋分支）同一档的优先级（09-22 群友「加一个可以看本职业其他专精的属性的能力」）
        self._ovStatPri._specRows = GearInsight.OtherSpecPriorityRows(class, sdata, self._statMode, sNames)
        if not self._ovStatPri._hooked then
            self._ovStatPri._hooked = true
            local hit = CreateFrame("Frame", nil, self._ovStatPri:GetParent())
            hit:SetAllPoints(self._ovStatPri); hit:EnableMouse(true)
            hit:SetScript("OnEnter", function(h)
                local rows = self._ovStatPri._specRows
                if not rows or #rows == 0 then return end
                GameTooltip:SetOwner(h, "ANCHOR_BOTTOMLEFT")
                GameTooltip:SetText(T("STAT_PRI_OTHERS", "本职业其他专精 · 属性优先级"), 1, 0.82, 0)
            local modeName = (self._statMode == "mplusHigh" and T("MODE_MHIGH", "高层")) or (self._statMode == "mplusFarm" and T("MODE_MFARM", "割草")) or (self._statMode == "mplusCommon" and T("MODE_MCOMMON", "常规")) or T("MODE_RAID", "团本")
                GameTooltip:AddLine("|cff8a93a6" .. string.format(T("STAT_PRI_OTHERS_MODE", "按当前档：%s · WCL 顶尖玩家配比"), modeName) .. "|r", 1, 1, 1, true)
                GameTooltip:AddLine(" ")
                for _, r in ipairs(rows) do GameTooltip:AddDoubleLine(r[1], r[2], 1, 0.82, 0, 0.9, 0.9, 0.9) end
                GameTooltip:Show()
            end)
            hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end

    -- ── Stats: 对齐 WCL 顶尖玩家的"属性配比"(占比×你的总量，可达) ──
    -- 目标 = 顶尖玩家该属性的平均评级(statRat)。直接对比你的评级 vs 平均值：
    --   低于平均=不足(补)、约等于=达标、高于=超标。这才是"学 WCL 平均数"。
    -- 没有 statRat 时回退旧的"占比×你的总量"法。
    if self._statRows and sdata and (statRat or statPct) then
        local sec = (snapshot and snapshot.secondary) or {}
        local secRating = (snapshot and snapshot.secondaryRating) or {}
        local ratingTotal = 0
        for _, statKey in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            ratingTotal = ratingTotal + (secRating[statKey] or 0)
        end
        -- 目标评级表：优先 statRat(绝对均值)，否则用 占比×你的总量。
        local function targetRatingOf(sk)
            if statRat and statRat[sk] then return statRat[sk] end
            if statPct and statPct[sk] and ratingTotal > 0 then
                return math.floor((statPct[sk]) / 100 * ratingTotal + 0.5)
            end
            return 0
        end
        local maxTgt = 0
        for _, sk in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            local t = targetRatingOf(sk)
            if t > maxTgt then maxTgt = t end
        end
        for sk, sr in pairs(self._statRows) do
            local cur = sec[sk] or 0                       -- 面板效果%(显示用)
            local currentRating = secRating[sk] or 0       -- 你的评级
            local targetRating = targetRatingOf(sk)        -- WCL 平均评级
            if targetRating == 0 then
                sr.bar:SetValue(0)
                sr.val:SetText("-")
            else
                -- 目标占比很小的属性(如多数 DPS 的全能)算"非核心"，不报红。
                local isCore = not (maxTgt > 0 and targetRating < maxTgt * 0.30)
                local ratio = currentRating / targetRating
                sr.bar:SetValue(math.min(ratio, 1.25))
                local r, g, b, tag, tc, showGap, isOver
                if not isCore then
                    r, g, b = 0.55, 0.55, 0.55
                    tag = T("TAG_NONCORE", "非核心"); tc = "|cFF999999"; showGap = false
                elseif ratio < 0.9 then
                    r, g, b = 1, 0.2, 0.1
                    tag = T("TAG_LOW", "不足"); tc = "|cFFFF0000"; showGap = true
                elseif ratio < 1.0 then
                    r, g, b = 0.95, 0.75, 0.1
                    tag = T("TAG_TOL", "容差内"); tc = "|cFFFFFF00"; showGap = true
                elseif ratio <= 1.1 then
                    r, g, b = 0.2, 1, 0.1
                    tag = T("TAG_OK", "达标"); tc = "|cFF00FF00"; showGap = false; isOver = true
                else
                    r, g, b = 1, 0.6, 0.1
                    tag = T("TAG_OVER", "超标"); tc = "|cFFFF8800"; showGap = false; isOver = true
                end
                sr.bar:SetStatusBarColor(r, g, b, 0.9)
                local gapR = targetRating - currentRating
                local detail = ""
                -- ⛔ 档位是按**比例**判的，数字却只给绝对值 → 同屏出现「达标 多90」
                --   紧挨着「超标 多59」，看着就是自相矛盾（2026-08-31 用户：「绿字不对吧」）。
                --   真身：急速目标 984 多 90 = +9%（容差内），精通目标 441 多 59 = +13%（超了）。
                --   把百分比一起写出来，标签和数字才是同一把尺子。
                local devPct = (targetRating > 0) and ((currentRating - targetRating) / targetRating * 100) or 0
                if showGap and gapR > 0 then
                    detail = string.format(T("TAG_GAP_R3", " 缺%d (%.0f%%)"), gapR, devPct)
                elseif isOver and gapR < 0 then
                    detail = string.format(T("TAG_OVER_R3", " 多%d (+%.0f%%)"), -gapR, devPct)
                end
                local pctText = (cur and cur > 0) and string.format("|cFFAAAAAA(%.1f%%)|r", cur) or ""
                sr.val:SetText(string.format("%s%d|r%s |cFF888888→|r%s%d %s%s%s|r",
                    tc, currentRating, pctText, T("LBL_TGT", "目标"), targetRating, tc, tag, detail))
                sr.val:SetWordWrap(false)
            end
        end
    end

    -- ── Upgrades (only actionable rows; completed BiS is summarized) ──
    local rowIdx = 0
    local completedCount = 0
    -- Graduated slots stay perceivable: collected here, rendered as a compact
    -- green section below the upgrade rows (each row keeps its 前5 popup).
    local completedSlots = {}
    -- Track what each paired slot ends up recommending so its sibling won't
    -- recommend the SAME item (you can't equip two of the same trinket/ring).
    -- Slots are processed ascending (13 before 14, 11 before 12), so the sibling
    -- recommendation is already known when we reach the second slot of the pair.
    local recommendedBySlot = {}
    -- 装备图（ui/GearMap.lua）从这张表画格子：每个槽的结论在下面循环里算完就存进来。
    -- ⛔ 它只是「结论的镜像」，判断逻辑仍只在这一处。
    self._slotPlan = {}
    local yOff = -4
    self._lastSlot = nil
    -- Reuse slot headers; hide old ones before repopulating
    self._slotHeaders = self._slotHeaders or {}
    for _, hdr in pairs(self._slotHeaders) do
        hdr:Hide()
    end
    if self._completedSummary then self._completedSummary:Hide() end
    if self._emptyUpgradeLabel then self._emptyUpgradeLabel:Hide() end
    if self._gradHeader then self._gradHeader:Hide() end

    -- 武器形态：优先玩家实戴形态，回退该专精当前场景的 meta 主流形态。
    -- 据此让主手(16)/副手(17)按形态耦合：双手/远程隐藏副手；各槽候选按手数过滤。
    local effWConf
    do
        local wScen = (self._statMode == "mplusHigh" and "mplusHigh")
            or (self._statMode == "mplusFarm" and "mplusFarm") or "raid"
        local wTbl = self.BisData and self.BisData.weaponConfig
        local wKey = data and data.className and data.specName and (data.className .. "/" .. data.specName)
        local wMeta = wTbl and wKey and wTbl[wKey] and wTbl[wKey][wScen]
        effWConf = _playerWeaponConfig(snapshot, wKey)
        if not effWConf and wMeta then
            local best, bestP = nil, -1
            for cfg, p in pairs(wMeta) do if p > bestP then best, bestP = cfg, p end end
            effWConf = best
        end
    end

    -- 武器形态对比（同一个 QQ 反馈：「有没有副手加武器和双手武器的数据对比或排名推荐？」）：
    -- 本专精当前场景下各形态的 WCL 使用率，挂在主手 / 副手目标图标的悬浮里；标出玩家现在用的形态。
    local weaponCmp, mainIs2h
    do
        local wScen = (self._statMode == "mplusHigh" and "mplusHigh")
            or (self._statMode == "mplusFarm" and "mplusFarm") or "raid"
        local wKey = data and data.className and data.specName and (data.className .. "/" .. data.specName)
        local meta = self.BisData and self.BisData.weaponConfig and wKey and self.BisData.weaponConfig[wKey]
        meta = meta and meta[wScen]
        if meta then
            local NAME = { ["2h"] = T("WCONF_2H", "双手"), dualWield = T("WCONF_DW", "双持"), ["1hShield"] = T("WCONF_1HS", "单手+盾"),
                ["1hOff"] = T("WCONF_1HO", "单手+副手"), titansGrip = T("WCONF_TG", "泰坦之握"), ranged = T("WCONF_RANGED", "远程") }
            local SCEN = { raid = T("WCONF_SCEN_RAID", "团本"), mplusHigh = T("WCONF_SCEN_MH", "大秘境高层"), mplusFarm = T("WCONF_SCEN_MF", "大秘境") }
            local list = {}
            for cfg, pct in pairs(meta) do list[#list + 1] = { cfg = cfg, pct = pct } end
            table.sort(list, function(a, b) return a.pct > b.pct end)
            local mine = _playerWeaponConfig(snapshot, wKey)
            local parts = {}
            for i, e in ipairs(list) do
                parts[#parts + 1] = string.format("#%d %s %.0f%%", i, NAME[e.cfg] or e.cfg, e.pct)
                    .. ((e.cfg == mine) and T("WCONF_MINE", "（你）") or "")
            end
            weaponCmp = string.format(T("WCONF_CMP", "武器形态（%s WCL 使用率）：%s"), SCEN[wScen] or wScen, table.concat(parts, " · "))
        end
    end

    -- 催化套装只有固定五个部位。坯子入口必须按“槽位能力”判断，不能跟着
    -- 当前推荐来源或复用列表行上的旧 _tierSlot 状态走（否则头部毕业后没有入口，
    -- 腰带又可能继承上一行状态误显示入口）。
    local TIER_SLOT = { [1] = true, [3] = true, [5] = true, [7] = true, [10] = true }
    local function attachTierAction(plan, slotId, slotLabel, cand, top, topPreview)
        if not (plan and TIER_SLOT[slotId]) then return end
        local armor = self.BisData and self.BisData.classArmor and self.BisData.classArmor[class]
        if not armor then return end
        local srcs = self.BisData.tierFiller and self.BisData.tierFiller[armor]
            and self.BisData.tierFiller[armor][slotId] or nil
        local tier = nil
        for _, e in ipairs(cand or {}) do
            if e.isTier or e.sourceCategory == "tier" or e.source == "套装转换" then
                tier = e; break
            end
        end
        tier = tier or ((top and (top.isTier or top.sourceCategory == "tier" or top.source == "套装转换")) and top or nil)
        local preview = tier and GearInsight.BisTargetPreview and GearInsight.BisTargetPreview(tier, data, slotId) or nil
        local args = {
            armor, slotId, slotLabel, srcs,
            (preview and preview.itemId == tier.itemId and preview.bonusIDs) or (tier and tier.bonusIDs),
            tier and tier.stats, statPct,
            tier and { itemId = tier.itemId, ilvl = tier.ilvl, name = tier.itemName,
                instanceId = tier.instanceId, encounterId = tier.encounterId, bossName = tier.bossName } or nil,
        }
        plan.isTierFiller = true
        plan._canonicalTier = true
        plan._tierArgs = args
        plan.fillerText = "|cFFB060FF" .. T("TIER_FILLER", "套装坯子")
            .. "|r |cFF808080" .. T("TIER_CLICK_VIEW", "· 点击查看") .. "|r"
        plan.onRightClick = function()
            GearInsight:ShowTierFiller(args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
        end
    end

    if activeBisBySlot and snapshot and snapshot.equipped then
        for slotId = 1, 17 do
            if slotId ~= 4 then
                local pairOther = PAIR_SLOT[slotId]
                local desiredRank = 1
                local cand = activeBisBySlot[slotId]
                if pairOther then
                    cand = _mergePairPool(activeBisBySlot[slotId], activeBisBySlot[pairOther])
                    if slotId == 12 or slotId == 14 then desiredRank = 2 end
                end
                -- 武器槽按形态耦合：双手/远程不出副手；主手/副手候选按手数过滤。
                if (slotId == 16 or slotId == 17) and effWConf then
                    if slotId == 17 and not WCONF_HASOFF[effWConf] then
                        cand = nil
                    elseif slotId == 17 and mainIs2h and effWConf ~= "titansGrip" then
                        cand = nil     -- 主手推的是双手：副手用不上，别再推（与主手矛盾）
                    elseif slotId == 16 then
                        cand = _filterByHand(cand, WCONF_MAINHAND[effWConf])
                        mainIs2h = cand and cand[1] and _handOf(cand[1]) == "2h" or false
                    else
                        local want = WCONF_OFFHAND[effWConf]
                        cand = _filterByHand(cand, want, want == "offWeapon" and "1h" or nil)
                    end
                end
                if cand and #cand > 0 then
                    local eq = snapshot.equipped[slotId]
                    local slotKey = self.GearReader and self.GearReader:GetSlotKey(slotId) or nil
                    local slotLabel = (slotKey and L[slotKey]) or ("SLOT" .. slotId)
                    local cName = (eq and not eq.empty and locName(eq.itemId, eq.itemName)) or T("SLOT_EMPTY", "(空槽)")
                    local cIlvl = eq and eq.ilvl or 0
                    local cId   = eq and eq.itemId
                    local top = cand[desiredRank] or cand[1]

                    -- Per-slot graduation ilvl. The spec-wide graduationItemLevel (tIlvl)
                    -- is the armor floor (289); trinkets/weapons cap higher (298). Derive
                    -- the floor from THIS slot's own BiS candidates so we never graduate a
                    -- piece below its slot's real target (e.g. a 289 trinket vs 298, or the
                    -- reported 250 trinket). Armor/rings stay at 289 since their max == 289.
                    local slotGrad = tIlvl or 0
                    for _, e in ipairs(cand) do
                        if (e.ilvl or 0) > slotGrad then slotGrad = e.ilvl end
                    end

                    -- Paired slots want the pool's top-2 distinct items across both
                    -- slots. This slot is done if it already holds a top-2 item.
                    -- Otherwise recommend a top-2 item NOT already worn in the sibling
                    -- slot (you can't stack two of the same unique item).
                    -- ⭐ 成对槽位的挑件决策收口在 GearInsight.PickPairedSlot（本文件上方），
                    --   角色属性页 ui/PaperDollBis.lua 走的是同一个函数。⛔别在任何地方再抄一份。
                    local skipAsComplete = false
                    if pairOther then
                        local otherEq = snapshot.equipped[pairOther]
                        local eqO = (otherEq and not otherEq.empty) and otherEq.itemId or nil
                        local recO = recommendedBySlot[pairOther]
                        top, skipAsComplete = GearInsight.PickPairedSlot(
                            slotId, cand, cId, cIlvl, slotGrad, eqO, recO)
                    end

                    -- 非配对槽(护甲/武器=属性载体)的目标选择：
                    --  ① 身上这件是池内候选且不低于其数据装等 → 毕业，但护甲槽严判（2026-06-07
                    --     用户拍板）：必须是 #1 本身；#2+ 同装等照样推荐 #1。武器槽保留池内即毕业
                    --     （双手/主副手组合多，实证回归：主手穿 #1@298 被闸门顺延去推荐 #2@298）
                    --  ② 否则禁止降级推荐（实证：M+参照系 263/276 BOE 盖过身上 289），
                    --     顺延首个 ≥身上装等 的候选；武器槽还要排除另一只手已穿的同件
                    --     （实证回归：副手推荐了主手正穿着的盲目裁决之刃）
                    --  ③ 全池不达标但身上这件未满级 → 推荐升级它本身
                    --  ④ 整池都低于身上 → 超越列表，毕业
                    -- 饰品/戒指(配对槽)价值在特效，由上面的 pair 分支处理。
                    if not pairOther and cand and #cand > 0 then
                        local otherWeapEq
                        if slotId == 16 or slotId == 17 then
                            local o = snapshot.equipped[slotId == 16 and 17 or 16]
                            otherWeapEq = (o and not o.empty) and o.itemId or nil
                        end
                        local own
                        if cId then
                            for _, e in ipairs(cand) do
                                if e.itemId == cId then own = e; break end
                            end
                        end
                        if own and own == cand[1] and cIlvl >= (own.ilvl or 0) then
                            skipAsComplete = true
                        else
                            local pick
                            for _, e in ipairs(cand) do
                                if e.itemId ~= otherWeapEq and (cIlvl == 0 or (e.ilvl or 0) >= cIlvl) then
                                    pick = e; break
                                end
                            end
                            if pick then top = pick
                            elseif own then top = own
                            else skipAsComplete = true end
                        end
                    end

                    local topName = locName(top.itemId, top.itemName) or ("Item#" .. top.itemId)
                    -- 参照装等 = **链接里那一份**的装等（用户 2026-09-05 选定：「为啥一个 321 一个 331」——
                    -- 格子/BiS 装等/毕业判定原来用 top.mx(顶尖玩家见过的最高档 331)，而 tooltip 是按
                    -- bonusIDs 建的链、显示英雄 6/6 321，三处两个数字像 bug）。
                    -- tooltip 不另加跨来源的最高观测装等，避免与当前来源的目标混淆。
                    -- ⚠️ 这条替换了 2026-08-28「毕业直接神话算」的口径。
                    -- 链接装等要物品缓存就绪才读得到，读不到退回数据里的 top.ilvl。
                    local topMx = top.mx
                    local topPreview = GearInsight.BisTargetPreview and GearInsight.BisTargetPreview(top, data, slotId)
                    local topIlvl = (topPreview and topPreview.ilvl) or top.ilvl or 0
                    local convertToName
                    if topPreview and topPreview.isFillerPreview then
                        convertToName = topName
                        topName = topPreview.name
                    end
                    local topBonusUse = top.bonusIDs
                    if topPreview then topBonusUse = topPreview.bonusIDs end -- never attach tier bonuses to a filler ID
                    if topMx and topMx <= topIlvl then topMx = nil end
                    local dropSrc = top.source or ""
                    if dropSrc == "钥石宝箱" then dropSrc = "钥石宝箱（大秘境）" end

                    -- Determine rank of equipped item in BiS candidates
                    local rank = nil
                    for ri, entry in ipairs(cand) do
                        if entry.itemId == cId then rank = ri; break end
                    end

                    -- 严判（2026-06-05 用户拍板）：只有真正持有 BiS 件（达到其目标装等或专精
                    -- 毕业装等）才算毕业。旧的"装等超过推荐件即毕业"条款已移除——饰品/戒指的
                    -- 价值在特效与使用率，高装等的非 BiS 件不等于毕业（旌旗298≠丝带289）。
                    -- ⛔ 同一件装备只是**升级轨道**进度不同，不是「要换一件」（2026-08-27
                    --    玩家 筱小飞 反馈）：他把这件升到神话 1/6(318)，而数据里顶尖玩家
                    --    那件是英雄 6/6(321)，装等暂时更低但上限更高，插件却把它列进
                    --    「待提升」，等于建议他去换一件天花板更低的。身上就是这件 → 算持有，
                    --    差的那点装等改在已毕业组里标成「可升级 318 → 321」。
                    local sameItem = cId and cId == top.itemId
                    local isComplete = skipAsComplete
                        or (sameItem and (topIlvl == 0 or cIlvl >= topIlvl or (slotGrad > 0 and cIlvl >= slotGrad)))
                        or (sameItem and cIlvl > 0 and topIlvl > 0 and cIlvl < topIlvl)
                    -- 套装件会保留坯子副属性，因此 StatFit 只作为信息展示，不能推翻“同一件 + 轨道可达”的毕业结论。
                    -- 契合度是按专精权重算的启发式分数，不是具体坯子的等价判定；拿它设 65% 硬阈值会出现
                    -- 身上和推荐 tooltip 明明是同一件神话套装，角色面板却不打勾、反过来推荐自己（#164）。
                    -- ⛔ 「同一件、装等没到 → 已毕业·可升级」有个前提：这条轨道还能升。老兵 6/6 / 勇士 8/8 封顶了
                    --    就永远到不了目标装等，必须换更高轨道的同款（套装件 = 换更高轨道的坯子再转）。
                    local trackMaxed = nil
                    if isComplete and sameItem and topIlvl > 0 and cIlvl < topIlvl then
                        local okT, cur, mx, nm = pcall(GearInsight.SlotUpgradeTrack, GearInsight, slotId)
                        if okT and cur and mx then
                            -- ⛔ 2026-09-17 用户：「拿了英雄，上面选的史诗档，不能算 BiS，要继续推荐刷史诗的」。
                            --    不只封顶才算：这条轨道**升到顶也到不了**目标装等（英雄 1/6 318 → 顶约 320 < 334）
                            --    就不是 BiS，继续推荐去刷更高难度的同款。每档 +3 装等，与悬浮 TrackWarn 同口径。
                            local ceil = GearInsight.UpgradeTrackCeiling and GearInsight.UpgradeTrackCeiling(cIlvl, cur, mx) or cIlvl
                            if cur >= mx or ceil + 2 < topIlvl then
                                isComplete = false
                                trackMaxed = { cur = cur, max = mx, name = nm or "", ceil = ceil }
                            end
                        end
                    end
                    if not isComplete then
                        recommendedBySlot[slotId] = top.itemId
                    end
                    local plan = {
                        slotId = slotId, slotLabel = slotLabel,
                        popupLabel = pairOther and (slotLabel:gsub("%s*%d+$", "")) or slotLabel,
                        eqId = cId, eqLink = eq and eq.itemLink or nil, eqIlvl = cIlvl, eqName = cName,
                        rank = rank, isComplete = isComplete, cand = cand,
                        upgradeTo = (sameItem and topIlvl > 0 and cIlvl < topIlvl) and topIlvl or nil,
                        topId = top.itemId, previewId = topPreview and topPreview.itemId, topBonus = topBonusUse,
                        topLink = topPreview and topPreview.link,
                        topIlvl = topIlvl, topMx = topMx, topName = topName, convertToName = convertToName,
                        improvementPct = top.improvementPct,
                        trackMaxed = trackMaxed,
                    }
                    attachTierAction(plan, slotId, slotLabel, cand, top, topPreview)
                    self._slotPlan[slotId] = plan
                    if isComplete then
                        completedCount = completedCount + 1
                        completedSlots[#completedSlots + 1] = {
                            slotId = slotId,
                            label = slotLabel,
                            -- Paired slots pool both lists; title the popup without the number.
                            popupLabel = pairOther and (slotLabel:gsub("%s*%d+$", "")) or slotLabel,
                            cand = cand,
                            eqId = cId,
                            eqLink = eq and eq.itemLink or nil,
                            eqName = cName,
                            eqIlvl = cIlvl,
                            rank = rank,
                            -- 同一件但装等还没追上参照件 → 已持有、可继续升级轨道
                            upgradeTo = (sameItem and topIlvl > 0 and cIlvl < topIlvl) and topIlvl or nil,
                        }
                    else
                    rowIdx = rowIdx + 1
                    local row = self._upgradeRows[rowIdx]
                    if not row then
                        -- safety: create on demand (Button icons, sync+async)
                        row = CreateFrame("Frame", nil, self._scrollChild)
                        -- 右侧套装推荐会同时显示名称、装等与“化生为”。原来的 56px
                        -- 行高把第三行压进坯子入口；固定为纵向三层，避免任何文字叠在一起。
                        row:SetSize(456, 94); row:EnableMouse(true)
                        local cIB = CreateFrame("Button",nil,row); cIB:SetSize(48,48); cIB:SetPoint("TOPLEFT",2,-2)
                        cIB.texture=cIB:CreateTexture(nil,"ARTWORK"); cIB.texture:SetAllPoints(); cIB.itemID=nil;cIB.itemLink=nil;cIB.currentItemID=nil
                        cIB:SetScript("OnEnter",function(s) if s.itemID then GameTooltip:SetOwner(s,"ANCHOR_RIGHT") if s.itemLink then GameTooltip:SetHyperlink(s.itemLink) else GameTooltip:SetItemByID(s.itemID) end GameTooltip:Show() end end)
                        cIB:SetScript("OnLeave",function() GameTooltip:Hide() end)
                        local cT=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); cT:SetPoint("LEFT",cIB,"RIGHT",4,0); cT:SetWidth(150); cT:SetJustifyH("LEFT"); cT:SetWordWrap(true)
                        local ar=row:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); ar:SetPoint("LEFT",cT,"RIGHT",2,0); ar:SetText("→"); ar:SetWidth(20); ar:SetJustifyH("CENTER")
                        local tIB=CreateFrame("Button",nil,row); tIB:SetSize(48,48); tIB:SetPoint("LEFT",ar,"RIGHT",2,-2)
                        tIB.texture=tIB:CreateTexture(nil,"ARTWORK"); tIB.texture:SetAllPoints(); tIB.itemID=nil;tIB.itemLink=nil;tIB.currentItemID=nil;tIB._tgtIlvl=0;tIB._tgtName=nil;tIB._tgtSrc=nil;tIB._tgtStats=nil
                        tIB:SetScript("OnEnter",function(s) if s.itemID then GameTooltip:SetOwner(s,"ANCHOR_RIGHT") GameTooltip:ClearLines() if s.itemLink then GameTooltip:SetHyperlink(s.itemLink) else GameTooltip:SetItemByID(s.itemID) end if not GameTooltip._giTierCompact then if s._tgtIlvl and s._tgtIlvl>0 then GameTooltip:AddLine(" ") GameTooltip:AddLine("|cFFFFFF00"..T("TT_BIS_ILVL","BiS 装等: ")..s._tgtIlvl.."|r",1,1,1) end if s._improvementPct and s._improvementPct>0 then GameTooltip:AddLine(" ") GameTooltip:AddLine(string.format(T("TT_IMPROVE","提升幅度: +%.1f%%"),s._improvementPct),0.2,1,0.2) end if s._tgtSrc and s._tgtSrc~="" and not (GearInsight.TooltipHookActive and GearInsight.TooltipHookActive(s.itemID)) then GameTooltip:AddLine(T("SOURCE_PREFIX","来源: ")..s._tgtSrc,0.8,0.8,0.8) end if s._weaponCmp then GameTooltip:AddLine(s._weaponCmp,0.55,0.78,1,true) end GameTooltip:AddLine(" ") GameTooltip:AddLine("|cFF888888"..T("TT_BIS_REC","GearInsight BiS 推荐").."|r",0.5,0.5,0.5) GameTooltip:AddLine("|cFF66CCFF"..T("TT_SHIFT_CHAT","Shift+点击 发送到聊天").."|r",0.4,0.8,1) end GameTooltip:Show() end end)
                        tIB:SetScript("OnLeave",function() GameTooltip:Hide() end)
                        tIB:RegisterForClicks("LeftButtonUp")
                        tIB:SetScript("OnClick",function(s) if GearInsight._tryChatLink(s) then return end if s._slotCands and #s._slotCands>0 then GearInsight:ShowSlotTop5(s._slotLabel,s._slotId,s._slotCands) end end)
                        local t5=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); t5:SetSize(48,22); t5:SetPoint("TOPRIGHT",row,"TOPRIGHT",-6,-6); t5:SetText(T("TOPN_BTN", "前9")); t5:SetFrameLevel(60)
                        t5:SetScript("OnEnter",function(s) GameTooltip:SetOwner(s,"ANCHOR_TOP"); GameTooltip:SetText(T("TOPN_BTN_TT", "查看该部位使用率前9"),1,0.82,0); GameTooltip:Show() end)
                        t5:SetScript("OnLeave",function() GameTooltip:Hide() end)
                        t5:SetScript("OnClick",function(s) local ic=s:GetParent()._tgtIcon if ic and ic._slotCands and #ic._slotCands>0 then GearInsight:ShowSlotTop5(ic._slotLabel,ic._slotId,ic._slotCands) end end)
                        local tT=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); tT:SetPoint("TOPLEFT",tIB,"TOPRIGHT",4,-1); tT:SetPoint("RIGHT",t5,"LEFT",-6,0); tT:SetHeight(46); tT:SetJustifyH("LEFT"); tT:SetJustifyV("TOP"); tT:SetWordWrap(true)
                        -- 坯子入口严格接在目标文字块之后，不能再按图标底部定位；
                        -- 名称换行、化生目标换行时也不会覆盖入口。
                        local dp=CreateFrame("Button",nil,row); dp:SetPoint("TOPLEFT",tT,"BOTTOMLEFT",0,-3); dp:SetPoint("RIGHT",-4,0); dp:SetHeight(18)
                        dp:EnableMouse(true); dp:RegisterForClicks("LeftButtonUp"); dp:SetFrameLevel(50)
                        local dpt=dp:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); dpt:SetAllPoints(); dpt:SetJustifyH("LEFT"); dpt:SetWordWrap(false); dpt:SetMaxLines(1); dpt:SetTextColor(0.55,0.55,0.55)
                        dp._text=dpt; dp._instId=nil; dp._bossId=nil; dp._itemId=nil; dp._tierSlot=nil
                        dp:SetScript("OnEnter",function(s) if s._instId then GameTooltip:SetOwner(s,"ANCHOR_TOP"); GameTooltip:SetText(T("TT_JOURNAL_CLICK","点击打开地下城手册"),0.8,0.8,0.8); GameTooltip:Show() end end)
                        dp:SetScript("OnLeave",function() GameTooltip:Hide() end)
                        dp:SetScript("OnClick",function(s) if s._tierSlot then GearInsight:ShowTierFiller(s._tierArmor,s._tierSlot,s._tierLabel,s._tierSrcs,s._tierBonus,s._tierStats,s._tierStatPct,s._tierItem) else _openSourceJournal(s._instId,s._bossId,s._itemId) end end)
                        row._curIcon=cIB; row._curText=cT; row._arrow=ar; row._tgtIcon=tIB; row._tgtText=tT; row._drop=dp; row._top5Btn=t5
                        self._upgradeRows[rowIdx] = row
                    end

                    -- Slot section header (yellow, above first actionable item of new slot)
                    local headerKey = slotKey or ("SLOT" .. slotId)
                    if not self._lastSlot or self._lastSlot ~= headerKey then
                        local hdr = self._slotHeaders[headerKey]
                        if not hdr then
                            hdr = self._scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                            self._slotHeaders[headerKey] = hdr
                        end
                        hdr:ClearAllPoints()
                        hdr:SetPoint("TOPLEFT", 2, yOff)
                        hdr:SetWidth(470)
                        hdr:SetJustifyH("LEFT")
                        hdr:SetText(T("HDR_UPGRADE_SLOT", "待提升 - ") .. slotLabel)
                        hdr:SetTextColor(1, 0.82, 0)
                        hdr:SetShown(not mapMode)
                        yOff = yOff - 22
                        self._lastSlot = headerKey
                    end

                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 2, yOff)
                    row:SetShown(not mapMode)

                    -- Current item icon (sync+async)
                    setItemForIcon(row._curIcon, (eq and not eq.empty and cId) or nil)
                    if eq and eq.itemLink then row._curIcon.itemLink = eq.itemLink end
                    -- Target BiS icon (after de-dup)
                    setItemForIcon(row._tgtIcon, (topPreview and topPreview.itemId) or top.itemId, topBonusUse,
                        topPreview and topPreview.link)

                    -- Translate drop source to Chinese (after de-dup so src is final).
                    -- zhCN-only: on other clients these EN->CN swaps must not run.
                    local srcCN = dropSrc
                    if srcCN and _LOCALE == "zhCN" then
                        srcCN = srcCN:gsub("Midnight Falls", "午夜陨落")
                        srcCN = srcCN:gsub("Belo'ren", "贝洛伦")
                        srcCN = srcCN:gsub("Imperator Averzian", "阿维兹安大帝")
                        srcCN = srcCN:gsub("Fallen%-King Salhadaar", "陨落之王萨拉达尔")
                        srcCN = srcCN:gsub("Crown of the Cosmos", "宇宙之冠")
                        srcCN = srcCN:gsub("Chimaerus", "奇美拉")
                        srcCN = srcCN:gsub("Vaelgor & Ezzorak", "瓦尔格 & 埃佐拉克")
                        srcCN = srcCN:gsub("Lightblinded Vanguard", "光盲先锋")
                        srcCN = srcCN:gsub("Vorasius", "沃拉修斯")
                    end

                    -- Store data on target icon button for custom Tooltip
                    row._tgtIcon._tgtIlvl        = topIlvl
                    row._tgtIcon._tgtMx          = topMx
                    row._tgtIcon._tgtName        = topName
                    -- ⭐ 2026-08-29：这里原本是全插件**唯一**没走 localizedSource 的来源行，
                    -- 只特判了 zhTW（简转繁），enUS 等语言原样吐烤进去的中文。
                    -- localizedSource 内部已分别处理 zhCN(原样) / zhTW(S2T) / 其他(EJ 取本地化名)，
                    -- 交给它即可，三种语言都不会变差。⛔ 别再在这里手写语言分支。
                    row._tgtIcon._tgtSrc = localizedSource(srcCN or dropSrc or "",
                                                           top.instanceId, top.encounterId)
                    row._tgtIcon._fromLiveRecs   = top._fromLiveRecs or false
                    row._tgtIcon._improvementPct = top.improvementPct
                    row._tgtIcon._weaponCmp = (slotId == 16 or slotId == 17) and weaponCmp or nil
                    row._tgtIcon._tgtStats       = top.stats or nil
                    -- Slot's full usage-ranked candidate list, for the top-5 popup
                    row._tgtIcon._slotId    = slotId
                    -- Paired slots show the pooled list, so title it without the
                    -- slot number (饰品1/饰品2 → 饰品, 戒指1/2 → 戒指).
                    row._tgtIcon._slotLabel = pairOther and (slotLabel:gsub("%s*%d+$", "")) or slotLabel
                    row._tgtIcon._slotCands = cand
                    -- Show the "前5" button whenever the slot has any candidate. (Don't
                    -- gate on >1: with 团本排除 a slot's pool can collapse to a single
                    -- non-raid item, and the button must still open its usage reference.)
                    -- ⛔ 套装部位不放「前5」（用户 2026-09-14「TOP5 对于套装部件是不是可以不要了」）：
                    --    该部位推荐的是套装件，榜上就是它自己 + 几件杂项，真正要看的是「套装坯子」弹窗
                    if row._top5Btn then row._top5Btn:SetShown(cand and #cand > 0 and not TIER_SLOT[slotId]) end

                    -- Encounter Journal linking (click to open dungeon journal)
                    row._drop._instId = top.instanceId
                    row._drop._bossId = top.encounterId
                    row._drop._itemId = top.itemId

                    -- Build left/right text (unified actionable format)
                    local leftText, rightText, hasDrop = "", "", false

                    if not eq or eq.empty then
                        leftText = "|cFFFF0000" .. slotLabel .. " " .. T("SLOT_EMPTY", "(空)") .. "|r"
                        rightText = "|cFF00FF00" .. topName .. "|r  [" .. topIlvl .. "]"
                        hasDrop = (dropSrc ~= "")
                    elseif cId and cId == top.itemId and trackMaxed then
                        local tmTxt
                        if trackMaxed.cur >= trackMaxed.max then
                            tmTxt = string.format(T("TRACK_MAXED", "%s %d/%d 已封顶"), trackMaxed.name, trackMaxed.cur, trackMaxed.max)
                        else
                            tmTxt = string.format(T("TRACK_TOO_LOW", "%s %d/%d 升满约 %d，到不了 %d"),
                                trackMaxed.name, trackMaxed.cur, trackMaxed.max, trackMaxed.ceil or 0, topIlvl)
                        end
                        leftText = slotLabel .. ": " .. cName .. "  [" .. cIlvl .. "]  |cFFFF8800" .. tmTxt .. "|r"
                        rightText = "|cFFFF6600→ " .. topName .. " [" .. topIlvl .. "]|r  |cFFFFCC33"
                            .. ((dropSrc == "套装转换") and T("TRACK_REFARM_TIER", "换更高轨道的坯子再转") or T("TRACK_REFARM", "要更高轨道的同款")) .. "|r"
                        hasDrop = (dropSrc ~= "")
                    elseif cId and cId == top.itemId then
                        leftText = slotLabel .. ": " .. cName .. "  [" .. cIlvl .. "]"
                        rightText = "|cFFFF6600→ " .. topName .. " [" .. topIlvl .. "]" .. T("NEED_HIGHER_ILVL", " 需更高装等版本") .. "|r"
                        hasDrop = (dropSrc ~= "")
                    elseif cIlvl < topIlvl then
                        leftText = slotLabel .. ": " .. cName .. "  [" .. cIlvl .. "]"
                        rightText = "|cFF00FF00" .. topName .. "|r [" .. topIlvl .. "] |cFFFF6600(+" .. (topIlvl - cIlvl) .. ")|r"
                        hasDrop = (dropSrc ~= "")
                    elseif rank and topIlvl > 0 then
                        leftText = slotLabel .. ": " .. cName .. "  |cFFFFFF00#" .. rank .. "|r  [" .. cIlvl .. "]"
                        rightText = "|cFF00FF00→ " .. topName .. " [" .. topIlvl .. "]|r"
                        hasDrop = (dropSrc ~= "")
                    else
                        leftText = slotLabel .. ": " .. cName .. "  [" .. cIlvl .. "]"
                        rightText = "|cFF00FF00→ " .. topName .. " [" .. topIlvl .. "]|r"
                        hasDrop = (dropSrc ~= "")
                    end
                    row._curText:SetText(leftText)
                    if convertToName then rightText = rightText .. "\n" .. T("TIER_CONVERT_TO", "化生为：") .. convertToName end
                    row._tgtText:SetText(rightText)

                    -- Drop info (consistent row height regardless of drop presence).
                    -- Tier pieces come only from the Catalyst (套装转换): show where to
                    -- farm a same-slot "坯子" to convert, instead of the useless "套装转换".
                    -- Tier pieces come only from the Catalyst (套装转换). Show one short
                    -- clickable line; clicking pops up the full list of farmable fillers.
                    local fillerSrcs, fillerArmor = nil, nil
                    if TIER_SLOT[slotId] and dropSrc == "套装转换" and self.BisData and self.BisData.tierFiller then
                        fillerArmor = self.BisData.classArmor and self.BisData.classArmor[class]
                        if fillerArmor and self.BisData.tierFiller[fillerArmor] then
                            fillerSrcs = self.BisData.tierFiller[fillerArmor][slotId]
                        end
                    end
                    row._drop:ClearAllPoints()
                    row._drop:SetPoint("TOPLEFT", row._tgtIcon, "BOTTOMLEFT", 0, 2)
                    row._drop:SetPoint("RIGHT", -4, 0)
                    -- 套装转换 slot with no curated filler list (e.g. a non-standard tier slot
                    -- on a new spec): derive the filler from the slot's own same-slot raid/mplus
                    -- drops — any can be Catalyst-converted. Shape matches the curated entries.
                    local derivedSrcs = nil
                    if not (fillerSrcs and #fillerSrcs > 0) and TIER_SLOT[slotId] and dropSrc == "套装转换" and cand then
                        derivedSrcs = {}
                        for _, c in ipairs(cand) do
                            -- Any same-slot piece except the tier item itself can be catalyzed.
                            -- Crafted (制造业) gear is NOT catalyzable, so exclude it.
                            if c.itemId and c.sourceCategory and c.sourceCategory ~= "tier"
                                and c.sourceCategory ~= "crafted" and c.source ~= "套装转换" then
                                derivedSrcs[#derivedSrcs + 1] = {
                                    itemId = c.itemId, bonusIDs = c.bonusIDs, type = c.sourceCategory,
                                    nameCn = (c.bossName and c.bossName ~= "" and c.bossName) or c.source,
                                    instanceId = c.instanceId, encounterId = c.encounterId,
                                }
                            end
                        end
                        if #derivedSrcs == 0 then derivedSrcs = nil end
                    end
                    if fillerSrcs and #fillerSrcs > 0 then
                        -- 首选 = 弹窗排序的第 1 名。⛔ 必须复用同一个排序器：
                        --   两处各挑各的 = 面板说 A、弹窗第一名是 B（又一个「不一致」）。
                        -- ⛔ 三处必须拿到同一个 list：面板的首选、弹窗的第 1 名、
                        --   悬浮的 #1 是同一件，计数 (N) 也必须 == 弹窗条目数。
                        --   面板这里不传 noScan：顺便把地下城手册那一段扫出来缓存好，
                        --   等玩家悬停时悬浮就能直接吃缓存，不用在 tooltip 里动 EJ。
                        local ranked = GearInsight.BuildFillerList(
                            fillerArmor, slotId, fillerSrcs, data, top.stats, false)
                        -- 总榜第一是套装兑换物时，主面板只展示这件套装；不能再把
                        -- 总榜第二的坯子当成额外推荐塞到它下面。
                        plan._tierWinsTotal = ranked and ranked[1] and ranked[1].isTier or false
                        -- 总榜保留套装本体的原生属性横评；但它不是能放进化生台的
                        -- 坯子。面板必须取“非套装坯子”里的第一名，并同时保留
                        -- 总榜序号，避免出现“总榜第2为什么被推荐”的歧义。
                        local pick, pickOverallRank, fillerRank, fillerTotal = nil, nil, 0, 0
                        for overallRank, entry in ipairs(ranked or {}) do
                            if not entry.isTier then
                                fillerTotal = fillerTotal + 1
                                if not pick then
                                    pick, pickOverallRank, fillerRank = entry, overallRank, fillerTotal
                                end
                            end
                        end
                        pick = ranked and ranked[1] or nil
                        pickOverallRank = pick and pick.attributeRank or nil
                        fillerRank = pickOverallRank
                        local pickStat = pick and GearInsight.FillerStats
                            and GearInsight.FillerStats(pick.itemId, pick.bonusIDs) or nil
                        -- ⛔ 这行只有一行、且会截断（SetMaxLines(1)）：把最值钱的信息排在前面。
                        --    坯子名 + 绿字 > 来源 > 计数。来源点开弹窗里有，截掉不致命。
                        local function _fillerLine()
                            local srcName = pick and localizedSource(pick.nameCn or "", pick.instanceId, pick.encounterId) or ""
                            local nm = pick and getCN(pick.itemId)
                            local statTxt = pickStat and (" |cFF66BBFF[" .. pickStat .. "]|r") or ""
                            -- 行内只保留入口和名次；物品属性、来源和完整说明放进点击后的列表/悬浮，避免挤成一团。
                            local head = pick and pick.isTier and ("|cFFB060FF" .. T("TIER_TOKEN_WIN", "团本兑换物") .. "|r")
                                or ("|cFFB060FF" .. string.format(T("TIER_ATTR_RANK_N", "属性推荐 #%d"), fillerRank or 1) .. "|r")
                            if pickOverallRank and pickOverallRank ~= fillerRank then
                                head = head .. " |cFF808080" .. string.format(T("TIER_OVERALL_RANK", "(总榜 #%d)"), pickOverallRank) .. "|r"
                            end
                            if nm then
                                head = head .. " " .. nm .. statTxt
                            end
                            -- ⛔ SetWordWrap(false) + SetMaxLines(1) = 装不下就**硬截断**。
                            --   玩家 2026-09-02 截图：「套装坯子 复生祭品护颱 [急速/暴击] …」后面全没了。
                            --   改成量宽度逐级降级：宁可少显一段，也不能给一句被切掉一半的话。
                            --   价值序：坯子名+绿字 > 计数（告诉你还有几件可点）> 来源（弹窗里有）。
                            local fs = row._drop._text
                            local w  = row._drop:GetWidth() or 0
                            local tries = { head .. " |cFF808080" .. T("TIER_CLICK_VIEW", "· 点击查看") .. "|r", head }
                            for i = 1, #tries do
                                fs:SetText(tries[i])
                                if w <= 0 or i == #tries or fs:GetStringWidth() <= w then break end
                            end
                        end
                        _fillerLine()
                        row._drop._fillerItemId = pick and pick.itemId or nil
                        row._drop._fillerLink = nil
                        -- ⛔⛔ 坑子可能没有 bonusIDs：地下城手册扳出来的那批（GetCatalystSources）
                        --   只带现成的 info.link。丢了这个兜底就会退回 SetItemByID，
                        --   而 SetItemByID 渲的是**基础装等**——玩家 2026-09-10 截图：
                        --   「神圣大厅马裤 物品等级19 精良 +6智力」。弹窗/心愿单那两处都有
                        --   `elseif link` 兜底，只有面板这行漏了。
                        if pick and pick.itemId and pick.bonusIDs and #pick.bonusIDs > 0 then
                            row._drop._fillerLink = "|Hitem:" .. pick.itemId .. GearInsight.LinkMid()
                                .. #pick.bonusIDs .. ":" .. table.concat(pick.bonusIDs, ":") .. "|h[item]|h"
                        elseif pick and pick.link then
                            row._drop._fillerLink = pick.link
                        end
                        -- 物品名是异步加载的（冷缓存时 getCN 返回 nil），加载好再刷一次
                        if pick and pick.itemId and not getCN(pick.itemId) and Item and Item.CreateFromItemID then
                            local it, want = Item:CreateFromItemID(pick.itemId), pick.itemId
                            it:ContinueOnItemLoad(function()
                                if row._drop and row._drop._tierSlot == slotId and pick.itemId == want then
                                    if not pickStat and GearInsight.FillerStats then
                                        pickStat = GearInsight.FillerStats(pick.itemId, pick.bonusIDs)
                                    end
                                    _fillerLine()
                                end
                            end)
                        end
                        row._drop._tierArmor = fillerArmor
                        row._drop._tierSlot = slotId
                        row._drop._tierLabel = slotLabel
                        row._drop._tierSrcs = nil
                        row._drop._tierBonus = (topPreview and topPreview.itemId == top.itemId and topPreview.bonusIDs) or top.bonusIDs
                        row._drop._tierStats = top.stats
                        row._drop._tierStatPct = statPct
                        row._drop._tierItem = { itemId = top.itemId, ilvl = top.ilvl, name = top.itemName,
                                                instanceId = top.instanceId, encounterId = top.encounterId, bossName = top.bossName }
                        row._drop._instId = nil; row._drop._bossId = nil; row._drop._itemId = nil
                        row._drop:Show()
                    elseif derivedSrcs then
                        -- No count: the popup pulls the full Encounter Journal loot list, which is
                        -- usually larger than this WCL-derived stopgap, so a number would mislead.
                        row._drop._text:SetText("|cFFB060FF" .. T("TIER_FILLER", "套装坯子") .. "|r |cFF808080" .. T("TIER_FILLER_CLICK2", "· 点击查看可催化装备") .. "|r")
                        row._drop._tierArmor = nil
                        row._drop._tierSlot = slotId
                        row._drop._tierLabel = slotLabel
                        row._drop._tierSrcs = derivedSrcs
                        row._drop._tierBonus = (topPreview and topPreview.itemId == top.itemId and topPreview.bonusIDs) or top.bonusIDs
                        row._drop._tierStats = top.stats
                        row._drop._tierStatPct = statPct
                        row._drop._tierItem = { itemId = top.itemId, ilvl = top.ilvl, name = top.itemName,
                                                instanceId = top.instanceId, encounterId = top.encounterId, bossName = top.bossName }
                        row._drop._fillerItemId = nil
                        row._drop._fillerLink = nil
                        row._drop._instId = nil; row._drop._bossId = nil; row._drop._itemId = nil
                        row._drop:Show()
                    elseif hasDrop then
                        row._drop._tierSlot = nil
                        row._drop._tierSrcs = nil
                        row._drop._tierBonus = nil
                        row._drop._tierStats = nil
                        row._drop._tierStatPct = nil
                        row._drop._tierItem = nil
                        row._drop._fillerItemId = nil
                        row._drop._fillerLink = nil
                        local hint = top.instanceId and (" |cFFAAAAAA" .. T("JOURNAL_HINT", "(点击手册)") .. "|r") or ""
                        row._drop._text:SetText("|cFF808080" .. T("SOURCE_PREFIX", "来源: ") .. localizedSource(srcCN or dropSrc, top.instanceId, top.encounterId) .. "|r" .. hint)
                        row._drop:Show()
                    else
                        row._drop._tierSlot = nil
                        row._drop._tierSrcs = nil
                        row._drop._tierBonus = nil
                        row._drop._tierStats = nil
                        row._drop._fillerItemId = nil
                        row._drop._fillerLink = nil
                        row._drop._text:SetText("")
                        row._drop:Hide()
                    end
                    -- 五个固定套装槽即使已经毕业、或当前筛选把 #1 换成非套装来源，
                    -- 仍保留坯子入口；其它槽位绝不继承复用行的旧套装状态。
                    if plan._canonicalTier and row._drop._tierSlot == nil then
                        local a = plan._tierArgs
                        row._drop._text:SetText(plan.fillerText)
                        row._drop._tierArmor = a[1]
                        row._drop._tierSlot = a[2]
                        row._drop._tierLabel = a[3]
                        row._drop._tierSrcs = a[4]
                        row._drop._tierBonus = a[5]
                        row._drop._tierStats = a[6]
                        row._drop._tierStatPct = a[7]
                        row._drop._tierItem = a[8]
                        row._drop._instId = nil; row._drop._bossId = nil; row._drop._itemId = nil
                        row._drop:Show()
                    end
                    -- 兑换套装也是统一排名的候选：保留坯子入口，只清除额外的坯子物品提示。
                    local directTierWin = (top.isTier or top.sourceCategory == "tier" or top.source == "套装转换")
                        and topPreview and topPreview.itemId == top.itemId and not topPreview.isFillerPreview
                    if directTierWin then
                        row._drop._text:SetText(plan.fillerText or ("|cFFB060FF" .. T("TIER_FILLER", "套装坯子") .. "|r"))
                        row._drop._fillerItemId = nil
                        row._drop._fillerLink = nil
                        row._drop._instId = nil; row._drop._bossId = nil; row._drop._itemId = nil
                        row._drop:Show()
                    end
                    -- 装备图要用的来源 / 坯子 / 右键动作（与列表行完全同源）
                    plan.srcText = row._tgtIcon._tgtSrc
                    plan.hasJournal = row._drop._instId ~= nil
                    if row._drop._tierSlot ~= nil then
                        plan.isTierFiller = TIER_SLOT[slotId] and true or false
                        plan.fillerText = row._drop:IsShown() and row._drop._text:GetText() or plan.fillerText
                    elseif not plan._canonicalTier then
                        plan.isTierFiller = false
                        plan.fillerText = nil
                    end
                    if not plan._canonicalTier or row._drop._tierSlot ~= nil then
                        local dp = row._drop
                        plan.onRightClick = function()
                            local fn = dp:GetScript("OnClick")
                            if fn and (dp._tierSlot or dp._instId) then fn(dp) end
                        end
                    end
                    row:SetHeight(76)
                    yOff = yOff - 76 - 2
                    end
                end
            end
        end
    end

    -- Hide unused rows
    for i = rowIdx + 1, #self._upgradeRows do
        self._upgradeRows[i]:Hide()
    end

    -- Handle no actionable rows
    if rowIdx == 0 and self._scrollChild then
        if not self._emptyUpgradeLabel then
            self._emptyUpgradeLabel = self._scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            self._emptyUpgradeLabel:SetWidth(456)
            self._emptyUpgradeLabel:SetJustifyH("LEFT")
        end
        self._emptyUpgradeLabel:ClearAllPoints()
        self._emptyUpgradeLabel:SetPoint("TOPLEFT", 6, 0)
        if usingLiveRecs then
            self._emptyUpgradeLabel:SetText(T("EMPTY_COMPANION", "Companion 已连接，暂无待处理推荐"))
        elseif completedCount > 0 then
            self._emptyUpgradeLabel:SetText(T("EMPTY_KEY_DONE", "关键槽位已达成，建议查看刷本优先级核对完整清单"))
        else
            self._emptyUpgradeLabel:SetText(T("EMPTY_NONE", "暂无下一步建议"))
        end
        self._emptyUpgradeLabel:SetTextColor(1, 0.5, 0)
        self._emptyUpgradeLabel:SetShown(not mapMode)
        -- Keep the gems/enchants section below the empty-state label.
        yOff = math.min(yOff, -24)
    end

    -- ── Graduated slots (perceivable list; each row keeps its 前5 popup) ──
    self._gradRows = self._gradRows or {}
    local gradShown = 0
    if #completedSlots > 0 and self._scrollChild then
        GearInsightDB = GearInsightDB or {}
        local collapsed = GearInsightDB.gradCollapse and true or false
        if not self._gradHeader then
            local hb = CreateFrame("Button", nil, self._scrollChild)
            hb:SetHeight(20)
            local fs = hb:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            fs:SetAllPoints()
            fs:SetJustifyH("LEFT")
            hb._fs = fs
            hb:SetScript("OnClick", function()
                GearInsightDB.gradCollapse = not GearInsightDB.gradCollapse
                GearInsight:RefreshPanel()
            end)
            hb:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(T("GRAD_HDR_TT", "点击展开/收起已毕业槽位"), 1, 0.82, 0)
                GameTooltip:Show()
            end)
            hb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            self._gradHeader = hb
        end
        local hb = self._gradHeader
        hb:ClearAllPoints()
        hb:SetPoint("TOPLEFT", 2, yOff)
        hb:SetWidth(470)
        local arrow = collapsed and "+ " or "- "
        -- 对勾用游戏自带贴图：✓(U+2713) 在 zhCN 客户端字体里没有字形，渲染成 □
        hb._fs:SetText(arrow .. "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t " .. T("GRAD_HDR", "已毕业槽位") .. " (" .. completedCount .. ")")
        hb._fs:SetTextColor(0.35, 0.9, 0.35)
        hb:SetShown(not mapMode)
        yOff = yOff - 22

        if not collapsed then
            for _, gs in ipairs(completedSlots) do
                gradShown = gradShown + 1
                local row = self._gradRows[gradShown]
                if not row then
                    row = CreateFrame("Frame", nil, self._scrollChild)
                    row:SetSize(456, 26)
                    row:EnableMouse(true)
                    local ic = CreateFrame("Button", nil, row)
                    ic:SetSize(22, 22)
                    ic:SetPoint("TOPLEFT", 4, -2)
                    ic.texture = ic:CreateTexture(nil, "ARTWORK")
                    ic.texture:SetAllPoints()
                    ic.itemID = nil; ic.itemLink = nil; ic.currentItemID = nil
                    ic:SetScript("OnEnter", function(s) if s.itemID then GameTooltip:SetOwner(s, "ANCHOR_RIGHT") if s.itemLink then GameTooltip:SetHyperlink(s.itemLink) else GameTooltip:SetItemByID(s.itemID) end GameTooltip:Show() end end)
                    ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    local t5 = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    t5:SetSize(44, 20)
                    t5:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    t5:SetText(T("TOPN_BTN", "前9"))
                    t5:SetFrameLevel(60)
                    t5:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(T("TOPN_BTN_TT", "查看该部位使用率前9"), 1, 0.82, 0); GameTooltip:Show() end)
                    t5:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    t5:SetScript("OnClick", function(s) if s._slotCands and #s._slotCands > 0 then GearInsight:ShowSlotTop5(s._slotLabel, s._slotId, s._slotCands) end end)
                    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    fs:SetPoint("LEFT", ic, "RIGHT", 6, 0)
                    fs:SetPoint("RIGHT", t5, "LEFT", -6, 0)
                    fs:SetJustifyH("LEFT")
                    fs:SetWordWrap(false)
                    fs:SetMaxLines(1)
                    -- 列表窄时名称/可升级说明会被「前9」按钮截断；整行悬停补全原文。
                    row:SetScript("OnEnter", function(s)
                        if not s._fullText then return end
                        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                        GameTooltip:SetText(T("GRAD_HDR", "已毕业槽位"), 0.35, 0.9, 0.35)
                        GameTooltip:AddLine(s._fullText, 1, 1, 1, true)
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    row._icon = ic; row._text = fs; row._top5 = t5
                    self._gradRows[gradShown] = row
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 2, yOff)
                setItemForIcon(row._icon, gs.eqId)
                if gs.eqLink then row._icon.itemLink = gs.eqLink end
                local rankTag = gs.rank and ("  |cFFFFFF00#" .. gs.rank .. "|r") or ""
                -- 已经是这件、只是轨道没升满：明说「可升级」，别让人误以为要换装备
                local upTag = gs.upgradeTo
                    and ("  |cFF66CCFF" .. T("GRAD_UPGRADABLE", "可升级") .. " "
                         .. (gs.eqIlvl or 0) .. " → " .. gs.upgradeTo .. "|r")
                    or ""
                local fullText = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t |cFF00FF00" .. T("GRAD_BIS_TAG", "已BiS") .. "|r  " .. gs.label .. ": |cFF55E055" .. (gs.eqName or "") .. "|r  [" .. (gs.eqIlvl or 0) .. "]" .. rankTag .. upTag
                row._fullText = fullText
                row._text:SetText(fullText)
                row._top5._slotId = gs.slotId
                row._top5._slotLabel = gs.popupLabel
                row._top5._slotCands = gs.cand
                row._top5:SetShown(gs.cand and #gs.cand > 0)
                row:SetShown(not mapMode)
                yOff = yOff - 26
            end
        end
    elseif self._gradHeader then
        self._gradHeader:Hide()
    end
    for i = gradShown + 1, #self._gradRows do
        self._gradRows[i]:Hide()
    end

    -- ── 装备图（ui/GearMap.lua）：map 模式藏掉上面的列表、从 0 开始画格子 ──
    if self._renderGearMap then yOff = self:_renderGearMap(yOff, data) end
    -- 某些物品信息会在首帧末尾异步回填。再核对一次当前模式，防止旧控件被回调带回。
    if mapMode and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if GearInsight.GearMapActive and GearInsight:GearMapActive() then hideLegacyRows() end
        end)
    end

    -- ── Crafted-gear mini recommendation (2 slots most worth crafting) ──
    yOff = yOff - 8
    yOff = self:_renderCraftedPicks(class, spec, htal, yOff)

    -- ── Recommended gems & enchants (appended below the upgrade list) ──
    yOff = yOff - 8
    yOff = self:_renderGemsEnchants(data, yOff)

    self._scrollChild:SetHeight(math.max(24, math.abs(yOff) + 8))

    -- ElvUI 换肤：扫主面板子树(含本轮新建的行内按钮)；无 ElvUI 时为空操作
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._panelFrame) end
end


-- 给后面的模块用（见 GearInsight.Helpers）
H.INVTYPE_HAND = INVTYPE_HAND
