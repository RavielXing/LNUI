-- GearInsight/main/Slash.lua — 斜杠命令 /gi
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T = H.T

-- ── Slash ────────────────────────────────────────────────────────────
SLASH_GEARINSIGHT1 = "/gi"
SLASH_GEARINSIGHT2 = "/gearinsight"
SlashCmdList["GEARINSIGHT"] = function(msg)
    -- pcall 保命但不吞错：报错时告诉用户出了什么，否则反馈只会是"点了没反应"。
    local ok, err = pcall(GearInsight.SlashCommand, GearInsight, msg)
    if not ok then
        GearInsight:Print("|cFFFF4444" .. T("CMD_ERROR", "命令执行出错: ") .. tostring(err) .. "|r")
    end
end

-- 账号绑定走独立命令，不再依赖 /gi 的总入口。
-- 部分整合包会覆盖短命令 /gi；此前网页复制的是「/gi account …」，覆盖后整行会被
-- 当作未知命令。保留旧写法兼容，网页改为复制这个专用入口。
SLASH_GEARINSIGHTACCOUNT1 = "/giaccount"
SLASH_GEARINSIGHTACCOUNT2 = "/gearinsightaccount"
SlashCmdList["GEARINSIGHTACCOUNT"] = function(msg)
    local ok, err = pcall(GearInsight.SlashCommand, GearInsight, "account " .. strtrim(msg or ""))
    if not ok then
        GearInsight:Print("|cFFFF4444" .. T("CMD_ERROR", "命令执行出错: ") .. tostring(err) .. "|r")
    end
end

-- 万奥宝典结构导出（用户 2026-09-14「插件增加个新功能，指导所有职业专精，配万奥宝典」——先拿到树的真实结构）
function GearInsight:DumpCodexTrees(arg)
    if not (C_Traits and C_Traits.GetConfigIDByTreeID and C_Traits.GetTreeNodes) then self:Print("[codex] C_Traits 不可用"); return end
    local classCfg = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    local classTree = classCfg and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(classCfg)
    local classTreeID = classTree and classTree.treeIDs and classTree.treeIDs[1]
    local maxTree = tonumber(arg) or 3000
    local dump, found = {}, 0
    for treeID = 1, maxTree do
        local ok, cfg = pcall(C_Traits.GetConfigIDByTreeID, treeID)
        if ok and cfg and cfg > 0 and treeID ~= classTreeID then
            local ok2, nodes = pcall(C_Traits.GetTreeNodes, treeID)
            if ok2 and nodes and #nodes > 0 and #nodes <= 60 then
                local info = C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(cfg)
                local t = { treeID = treeID, configID = cfg, name = info and info.name, type = info and info.type, nodes = {} }
                local okc, cur = pcall(C_Traits.GetTreeCurrencyInfo, cfg, treeID, false)
                if okc and cur then
                    t.currency = {}
                    for i, c in ipairs(cur) do t.currency[i] = { id = c.traitCurrencyID, quantity = c.quantity, maxQuantity = c.maxQuantity, spent = c.spent } end
                end
                for _, nid in ipairs(nodes) do
                    local okn, n = pcall(C_Traits.GetNodeInfo, cfg, nid)
                    if okn and n then
                        local e = { id = nid, type = n.type, posX = n.posX, posY = n.posY, maxRanks = n.maxRanks,
                                    rank = n.activeRank or n.currentRank, visible = n.isVisible, available = n.isAvailable,
                                    subTree = n.subTreeID, groups = n.groupIDs, edges = {}, entries = {} }
                        for _, ed in ipairs(n.visibleEdges or {}) do e.edges[#e.edges + 1] = ed.targetNode end
                        if n.activeEntry then e.active = n.activeEntry.entryID end
                        for _, eid in ipairs(n.entryIDs or {}) do
                            local oke, ei = pcall(C_Traits.GetEntryInfo, cfg, eid)
                            local d = { entryID = eid }
                            if oke and ei then
                                d.definitionID = ei.definitionID; d.maxRanks = ei.maxRanks; d.type = ei.type
                                local okd, di = pcall(C_Traits.GetDefinitionInfo, ei.definitionID)
                                if okd and di then
                                    d.spellID = di.spellID; d.overrideName = di.overrideName; d.overrideIcon = di.overrideIcon
                                    if di.spellID and C_Spell and C_Spell.GetSpellName then d.name = C_Spell.GetSpellName(di.spellID) end
                                    if di.spellID and C_Spell and C_Spell.GetSpellDescription then d.desc = C_Spell.GetSpellDescription(di.spellID) end
                                end
                            end
                            local okp, cost = pcall(C_Traits.GetNodeCost, cfg, nid)
                            if okp and cost then e.cost = {} for i, c in ipairs(cost) do e.cost[i] = { id = c.ID, amount = c.amount } end end
                            e.entries[#e.entries + 1] = d
                        end
                        t.nodes[#t.nodes + 1] = e
                    end
                end
                dump[#dump + 1] = t
                found = found + 1
                self:Print(string.format("[codex] tree %d cfg %d 「%s」 节点 %d 货币 %s", treeID, cfg, tostring(t.name),
                    #t.nodes, t.currency and t.currency[1] and (tostring(t.currency[1].quantity) .. "/" .. tostring(t.currency[1].maxQuantity)) or "-"))
                for _, e in ipairs(t.nodes) do
                    local names = {}
                    for _, d in ipairs(e.entries) do names[#names + 1] = (d.name or ("#" .. tostring(d.spellID))) .. (e.active == d.entryID and "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t" or "") end
                    self:Print(string.format("   node %d type %s (%s,%s) rank %s/%s: %s", e.id, tostring(e.type), tostring(e.posX), tostring(e.posY),
                        tostring(e.rank), tostring(e.maxRanks), table.concat(names, " | ")))
                end
            end
        end
    end
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.codexDump = { at = date("%Y-%m-%d %H:%M"), trees = dump }
    self:Print(string.format("[codex] 共找到 %d 棵非职业树，已写入 SavedVariables（/reload 后落盘）", found))
end

function GearInsight:SlashCommand(input)
    local cmd = strtrim(input or "")
    if cmd == "" or cmd == "panel" or cmd == "show" then
        self:TogglePanel()
    elseif cmd == "fillers" or cmd:match("^fillers%s") then
        -- /gi fillers [部位号]（默认 1 头）：打印当前专精这个部位的坯子排名 + 分数 + 主次副属性，
        --   和网站 /api/wow/plan/fillers 对拍用（09-25 三端坯子口径统一）。分数口径同 _fillerScore：目标[主]×2 + 目标[次]
        local slot = tonumber(cmd:match("^fillers%s+(%d+)")) or 1
        local st = self.StatReader and self.StatReader:ReadAll() or {}
        local sd = self.BisData and st.class and self.BisData:GetSpecData(st.class, st.spec, st.heroTalent)
        local _, cls = UnitClass("player")
        local armor = self.BisData and self.BisData.classArmor and self.BisData.classArmor[cls]
        if not (sd and armor and GearInsight.BuildFillerList) then self:Print("fillers: 读不到当前专精数据"); return end
        local pct = GearInsight.FillerStatPct and GearInsight.FillerStatPct(sd) or {}
        local list, _, _, complete = GearInsight.BuildFillerList(armor, slot, nil, sd, nil, false)
        self:Print(string.format("坯子排名 · 部位 %d · 目标 暴击%.1f 急速%.1f 精通%.1f 全能%.1f%s", slot, pct.crit or 0, pct.haste or 0,
            pct.mastery or 0, pct.versatility or 0, complete and "" or "（手册还没扫完，稍后再打一次）"))
        for i, e in ipairs(list or {}) do
            local key; if GearInsight.FillerStats then local _; _, key = GearInsight.FillerStats(e.itemId, e.bonusIDs) end   -- ⛔ 别写 x and f()：只留第一个返回值
            local sc = -1
            if key then
                local w = 2; sc = 0
                for k in key:gmatch("[^+]+") do sc = sc + (tonumber(pct[k]) or 0) * w; w = 1 end
            end
            self:Print(string.format("  #%d %s · %.1f (%s)%s", i, (C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.itemId)) or ("#" .. e.itemId),
                sc, key or "?", e.isTier and " · 套装本体" or ""))
            if i >= 10 then break end
        end
    elseif cmd == "refresh" or cmd == "reload" then
        self:RefreshData()
    elseif cmd == "wclresolve" then
        if self.ResolveWCLCatalystInstances then
            self:ResolveWCLCatalystInstances()
        else
            self:Print("[WCL 坯子] 解析器尚未加载，请 /reload 后重试")
        end
    elseif cmd == "status" then
        self:PrintStatus()
    elseif cmd == "account" or cmd:match("^account%s") then
        -- 账号串（2026-09-20 账号模型：微信号 = 账号，下挂多角色）：网站 / 小程序「插件账号串」复制来的 GIA1-… 贴一次，
        -- 之后导出串第 12 段自带它 → 网站一看就知道这条串是这个账号的插件导出的（最强确权，别人搜名字 / 转发串都顶不掉）。
        local tok = strtrim(cmd:gsub("^account", ""))
        -- 聊天软件/手机跨端复制可能夹入 BOM、零宽空格、NBSP 或把 ASCII 连字符替换成长横线。
        -- 账号串只由 ASCII 字符组成，先做无损归一化再校验，避免看起来完全一样却提示格式错误。
        tok = tok:gsub("\239\187\191", ""):gsub("\226\128\139", ""):gsub("\194\160", "")
        tok = tok:gsub("\226\128\144", "-"):gsub("\226\128\145", "-"):gsub("\226\128\146", "-")
                 :gsub("\226\128\147", "-"):gsub("\226\128\148", "-"):gsub("\226\136\146", "-")
        tok = tok:gsub("[%s%c]", "")
        GearInsightDB = GearInsightDB or {}
        if tok == "clear" then
            GearInsightDB.account = nil
            self:Print("|cFF7CFC98" .. T("ACCOUNT_CLEARED", "账号串已清除。请粘贴新的 /gi account GIA1-… 完成绑定。") .. "|r")
        elseif tok == "" then
            if GearInsightDB.account then
                self:Print(T("ACCOUNT_SET", "账号串已绑定：") .. GearInsightDB.account:sub(1, 12) .. "…  " .. T("ACCOUNT_LOCKED_HINT", "绑定后不可更改。"))
            else
                self:Print(T("ACCOUNT_NONE", "尚未绑定账号串。网站右上角角色菜单 →「插件账号串」复制，粘到这里：/gi account GIA1-…"))
            end
        elseif GearInsightDB.account then
            -- 2026-09-21 用户：账号串设置过以后就不让改（防止换串把角色转走 / 反复改）
            self:Print("|cFFFF4444" .. T("ACCOUNT_LOCKED", "账号串已绑定，不可更改。如确需更换请在网站「账号」页面申请。") .. "|r")
        elseif tok:match("^GIA1%-[%w_%-]+%-%x+$") then
            GearInsightDB.account = tok
            self:Print("|cFF7CFC98" .. T("ACCOUNT_OK", "账号串已绑定。之后 /gi export 的导出串自动带上你的账号，导出的角色就是你的。") .. "|r")
        else
            self:Print("|cFFFF4444" .. T("ACCOUNT_BAD", "账号串格式不对，应以 GIA1- 开头（从网站 / 小程序整行复制）。") .. "|r")
        end
    elseif cmd == "cleartalents" or cmd == "clear" then
        -- 一键删本插件导入的 GI- 载入档（同天赋页右上角按钮）
        self:ConfirmClearImportedLoadouts()
    elseif cmd == "codex" or cmd:match("^codex%s") then
        -- 万奥宝典（12.1 加点系统）结构导出：找非职业/专精的 C_Traits 树，节点/选项/花费/连线/当前选法
        -- 全写进 GearInsightDB.codexDump（SavedVariables，/reload 后落盘），聊天框只打摘要。
        self:DumpCodexTrees(cmd:match("^codex%s+(%S+)"))
    elseif cmd == "codexui" then
        self:OpenCodexUI()
    elseif cmd == "tree" or cmd == "tree debug" then
        if cmd == "tree debug" then
            -- 远程排「天赋树挤一坨」：先开一次预览再打印分组/包围盒
            if self.ShowMyTalentTree then self:ShowMyTalentTree() end
            self:Print("[tree] " .. tostring(self._tvDebug or "（还没画过）"))
        elseif self.ShowMyTalentTree then self:ShowMyTalentTree() end
    elseif cmd == "pvp" then
        -- 打开面板并切到「PvP 装备」页签
        if not (self._panelFrame and self._panelFrame:IsShown()) then self:TogglePanel() end
        if self._selectMainTab then pcall(self._selectMainTab, "pvp") end
    elseif cmd == "meta" or cmd == "mplus" then
        -- 大秘境/PvP 情报页 2026-09-10 从插件下线（用户：「游戏内没有用，让大家去网上看」）。
        -- 老命令留着指路，别让记得这条命令的人以为插件坏了。
        self:Print(T("META_MOVED", "大秘境 / PvP 情报已移到网站：gearinsight.app（插件内不再显示）"))
    elseif cmd == "minimap" or cmd == "icon" or cmd == "图标" then
        -- 找回小地图按钮（玩家 dfdyg6663 2026-09-09：「更新以后小地图旁的图标不见了」）。
        -- ⛔ 这条要能在**任何**状态下救回来：没创建就创建，跑出屏幕就复位。
        if self.MinimapButton and self.MinimapButton.Rescue then
            self.MinimapButton:Rescue()
        end
    elseif cmd == "help" then
        self:PrintHelp()
    elseif cmd == "config" or cmd == "options" or cmd == "设置" then
        -- 设置总表（2026-09-06）：主面板「设置」页 = ESC → 选项 → 插件 → GearInsight 同一份
        if self.OpenConfig then self:OpenConfig() end
    elseif cmd == "farming" then
        local c, s, h
        if self.StatReader then
            local st = self.StatReader:ReadAll()
            c = st.class; s = st.spec; h = st.heroTalent
        end
        if self._selectMainTab then
            if not (self._panelFrame and self._panelFrame:IsShown()) and self.TogglePanel then self:TogglePanel() end
            pcall(self._selectMainTab, "wish")
        elseif c and s then
            self:ShowFarmingGuide(c, s, h)
        else
            self:Print(T("PRINT_OPEN_FIRST", "请先打开面板或刷新数据"))
        end
    elseif cmd == "multi" or cmd == "multispec" then
        local c
        if self.StatReader then c = self.StatReader:ReadAll().class end
        if c then
            self:ShowMultiSpecPlan(c)
        else
            self:Print(T("PRINT_OPEN_FIRST", "请先打开面板或刷新数据"))
        end
    elseif cmd == "mode" or cmd:match("^mode%s") then
        local arg = cmd:match("^mode%s+(%S+)") or ""
        local cur = (GearInsightDB and GearInsightDB.usageMode) or "raid"
        local mode
        if arg == "raid" or arg == "团本" then mode = "raid"
        elseif arg == "mplus" or arg == "大秘境" or arg == "mythic" then mode = "mplus"
        else mode = (cur == "mplus") and "raid" or "mplus" end -- 无参 = 团本/大秘境切换
        self:SetUsageMode(mode)
    elseif cmd == "raid" or cmd == "mplus" or cmd == "mythic" then
        -- 直觉快捷方式：/gi raid = 使用率参照切团本（等价 /gi mode raid）。
        -- 旧版曾把 /gi raid 路由到"排除团本"开关——字面意思相反，已纠正；
        -- 排除团本只认 /gi noraid。
        self:SetUsageMode(cmd == "raid" and "raid" or "mplus")
    elseif cmd == "noraid" or cmd:match("^noraid%s") then
        local arg = cmd:match("%s+(%S+)") or ""
        local cur = (GearInsightDB and GearInsightDB.excludeRaid) and true or false
        local on
        if arg == "on" or arg == "排除" then on = true
        elseif arg == "off" or arg == "含" then on = false
        else on = not cur end
        self:SetExcludeRaid(on)
    elseif cmd == "export" or cmd == "share" then
        self:ShowExportDialog()
    elseif cmd == "need" or cmd == "需求" or cmd == "需求单" then
        self:ShowNeedSheet()
    elseif cmd == "srcdiag" or cmd:match("^srcdiag%s") then
        -- 诊断：把一件装备的来源所有证据打出来（用户 2026-09-02：
        -- 「至暗之夜为什么标成团本」「334 装等到底能不能到」——
        -- 这两个问题只能用客户端自己的数据回答，不能猜。
        -- 用法：/gi srcdiag 268229   或直接 shift 点链接进去
        local arg = cmd:match("^%S+%s+(.+)$")
        local iid = arg and (tonumber(arg) or tonumber(arg:match("item:(%d+):")))
        if not iid then
            self:Print("用法：/gi srcdiag <itemId 或 shift点出的物品链接>")
            return
        end
        self:Print(("|cffd6b26c── 来源诊断 #%d ──|r"):format(iid))

        -- ① 客户端基础信息（本体基准装等）
        local nm, lnk, _, baseIlvl = GetItemInfo(iid)
        self:Print(("  物品：%s   基准装等：%s"):format(tostring(nm), tostring(baseIlvl)))

        -- ② BisData 怎么说
        local hitBis = false
        local bd = self.BisData
        if bd and bd.specs then
            for sk, sp in pairs(bd.specs) do
                for slot, cands in pairs(sp.bisBySlot or {}) do
                    for r, e in ipairs(cands) do
                        if e.itemId == iid then
                            hitBis = true
                            -- 目标装等三处口径一起打（用户 2026-09-18「为啥没提示」：角色面板有箭头、悬浮没那一行）
                            local tgt, hint = GearInsight.BisTargetIlvl and GearInsight.BisTargetIlvl(e) or 0, nil
                            self:Print(("  BisData：%s slot=%s #%d/%d ilvl=%s mx=%s bonus=%s cat=%s src=%s"):format(
                                sk, tostring(slot), r, #cands, tostring(e.ilvl), tostring(e.mx),
                                e.bonusIDs and table.concat(e.bonusIDs, ":") or "-",
                                tostring(e.sourceCategory), tostring(e.source)))
                            self:Print(("    BisTargetIlvl（悬浮用）=%s  %s"):format(tostring(tgt), tostring(hint or "")))
                        end
                    end
                end
            end
        end
        if not hitBis then self:Print("  BisData：未收录这件") end

        -- ③ 地下城手册怎么说（团本/大秘境的唯一可信判据）
        local j = GearInsight.JournalSource and GearInsight.JournalSource(iid)
        if not j then
            self:Print("  手册：来源图还没建好（已排队），过一秒再跑一次这个命令")
        else
            local instName = EJ_GetInstanceInfo and EJ_GetInstanceInfo(j.instanceId) or j.instName
            local bossName = (j.encounterId and EJ_GetEncounterInfo and EJ_GetEncounterInfo(j.encounterId)) or "?"
            self:Print(("  手册：%s · %s   instanceId=%s encounterId=%s"):format(
                tostring(instName), tostring(bossName), tostring(j.instanceId), tostring(j.encounterId)))
            self:Print(("  手册分类：|cff%s%s|r  ← 这就是插件标「团本/大秘境」的依据"):format(
                j.isRaid and "ff8844" or "44bbff",
                j.isRaid and "团本(isRaid=true)" or "地下城(isRaid=false)"))
        end

        -- ③b 主面板 _slotPlan 怎么说（角色面板箭头用的口径）
        for slotId, plan in pairs(self._slotPlan or {}) do
            if plan.topId == iid or plan.eqId == iid then
                self:Print(("  _slotPlan[%d]：topId=%s topIlvl=%s topMx=%s eqId=%s eqIlvl=%s trackMaxed=%s"):format(
                    slotId, tostring(plan.topId), tostring(plan.topIlvl), tostring(plan.topMx), tostring(plan.eqId), tostring(plan.eqIlvl), tostring(plan.trackMaxed and (plan.trackMaxed.name or true))))
            end
        end
        if not self._slotPlan then self:Print("  _slotPlan：空（主面板还没渲染过）") end
        -- ④ 身上那件的实际装等（回答「能不能升到 334」）
        for slot = 1, 18 do
            local link = GetInventoryItemLink("player", slot)
            if link and tonumber(link:match("item:(%d+):")) == iid then
                local _, _, _, lv = GetItemInfo(link)
                self:Print(("  你身上这件：装等 %s（槽位 %d）—— 实际装等由 bonusID 决定，"):format(tostring(lv), slot))
                self:Print("    基准装等只是掉落起点，升级轨道走到哪看提示里的「升级：X N/M」。")
            end
        end
    elseif cmd == "dmtest" then
        -- 副本助手提示条自测：练级号/追随者本进不了 M0，靠这个验 UI 与按钮行为
        if self.DungeonPromptTest then self:DungeonPromptTest() end
    elseif cmd == "dumpids" then
        if self.BisData and self.BisData.DumpEncounterJournal then
            self.BisData:DumpEncounterJournal()
        else
            self:Print(T("DUMP_UNAVAILABLE", "BisData.DumpEncounterJournal 不可用"))
        end
    elseif cmd == "dumptalents" then
        self:DumpTalents()
    elseif cmd == "cbis" or cmd:match("^cbis%s") then
        local arg = cmd:match("^cbis%s+(.+)") or ""
        local c = self._paperDollBisCfg and self._paperDollBisCfg()
        if c then
            -- 大小写不敏感；裸数字也当 size（玩家照 changelog 试新命令常打成
            -- "/gi cbis 16"、"size16"、"Size 16"——0.43.0 旧逻辑把这些全当
            -- 未知参数静默切换开关，把角色面板图标整个关掉，看着像功能消失）
            local low = arg:lower()
            local sz = low:match("^size%s*(%d+)$") or low:match("^(%d+)$")
            local posKey = low:match("^pos%s*(%a+)$")
            local POS_MAP = { tl = "TOPLEFT", tr = "TOPRIGHT", bl = "BOTTOMLEFT", br = "BOTTOMRIGHT" }
            if sz then
                c.iconSize = math.max(10, math.min(30, tonumber(sz)))
                self:Print(string.format(T("PDB_SIZE_SET", "角色面板 BiS 图标大小：%dpx"), c.iconSize))
            elseif posKey and POS_MAP[posKey] then
                c.iconPos = POS_MAP[posKey]
                self:Print(T("PDB_POS_SET", "角色面板 BiS 图标位置：") .. posKey)
            elseif low == "off" then
                c.enabled = false
                self:Print(T("PDB_TOGGLE_OFF", "角色面板 BiS 图标：已关闭"))
            elseif low == "on" then
                c.enabled = true
                self:Print(T("PDB_TOGGLE_ON", "角色面板 BiS 图标：已开启"))
            elseif low == "" then
                -- 仅裸 /gi cbis 保留开关切换（0.39 起的文档行为）
                c.enabled = not c.enabled
                self:Print(c.enabled and T("PDB_TOGGLE_ON", "角色面板 BiS 图标：已开启")
                    or T("PDB_TOGGLE_OFF", "角色面板 BiS 图标：已关闭"))
            else
                -- 未识别参数：只报用法+当前状态，绝不动开关
                self:Print(T("PDB_CFG_HELP", "用法：/gi cbis on|off | size 10-30 | pos tl|tr|bl|br")
                    .. " | " .. (c.enabled and T("PDB_TOGGLE_ON", "角色面板 BiS 图标：已开启")
                        or T("PDB_TOGGLE_OFF", "角色面板 BiS 图标：已关闭")))
            end
            if self.RefreshPaperDollBis then self.RefreshPaperDollBis() end
        end
    elseif cmd == "web" then
        self:ShowWebProfileDialog()
    elseif cmd == "roll api" or cmd == "rollapi" then
        -- 探测 12.1 有没有可查 roll 币状态的接口（用户 2026-09-22 问「游戏有接口查吗」）
        if GearInsight.RollVault and GearInsight.RollVault.ProbeAPI then GearInsight.RollVault.ProbeAPI() end
    elseif cmd == "roll debug" or cmd == "rolldebug" then
        -- 选本选错时用（用户 2026-09-22 报「boss 数量不对」）：把手册里看到的团本全打出来
        if GearInsight.RollVault and GearInsight.RollVault.DebugInstances then GearInsight.RollVault.DebugInstances() end
    elseif cmd == "roll" then
        self:ShowRollPlan()   -- roll 币三选（main/RollVault.lua）
    elseif cmd == "plan" or cmd == "mybis" or cmd == "方案" then
        -- 「我的 BiS」方案页（ui/PlanPage.lua）；模块在 HOLD 期间不存在 → 提示
        if GearInsight.BuildPlanPage then
            if not (self._panelFrame and self._panelFrame:IsShown()) and self.TogglePanel then self:TogglePanel() end
            if self._selectMainTab then pcall(self._selectMainTab, "plan") end
        else
            self:Print(T("BP_NA", "「我的 BiS」还在测试，这个版本没有带"))
        end
    elseif cmd == "vault on" or cmd == "vault off" then
        GearInsightDB = GearInsightDB or {}
        GearInsightDB.vaultPanelOff = (cmd == "vault off")
        self:Print(GearInsightDB.vaultPanelOff and T("RV_VAULT_OFF_MSG", "已关闭：以后打开宏伟宝库不再显示「低保怎么选」。想看时输入 /gi vault，恢复自动显示用 /gi vault on 或设置页。")
                   or T("RV_VAULT_ON_MSG", "已开启：打开宏伟宝库时自动显示「低保怎么选」。"))
        if WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown() then GearInsight.RollVault.RefreshVault() end
    elseif cmd == "vault" then
        -- 低保：开箱界面打开时自动挂推荐面板；这里只是提示怎么用 + 没开时也能导出（只有进度没物品）
        -- 关了自动显示的人：/gi vault 在本次开箱时强制叫出来
        if WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown() then GearInsight.RollVault._vaultForce = true; GearInsight.RollVault.RefreshVault()
        else self:Print(T("RV_VAULT_HOWTO", "打开每周宝库（周三开箱界面）时，右侧会自动出现「低保怎么选」；导出串也在那里")) end
    elseif cmd == "roll prompt" or cmd == "rollprompt" then
        GearInsightDB = GearInsightDB or {}
        GearInsightDB.rollPrompt = (GearInsightDB.rollPrompt == false) and true or false
        self:Print(T("RV_PROMPT_TOGGLE", "进本 roll 币提示：") .. tostring(GearInsightDB.rollPrompt ~= false))
    elseif cmd == "kt" or cmd:match("^kt%s") then
        -- 钥匙时间轴位置（bug #108）。模块是按需加载的，先拉起来再调
        local arg = cmd:match("^kt%s+(%S+)") or ""
        if not self:LoadDungeonModule(false) then return end
        if arg == "unlock" or arg == "解锁" then
            self:KeyTimelineSetUnlocked(true)
        elseif arg == "lock" or arg == "锁定" then
            self:KeyTimelineSetUnlocked(false)
        elseif arg == "reset" or arg == "复位" then
            self:KeyTimelineResetPos()
        elseif arg == "debug" or arg == "诊断" then
            if self.KeyTimelineDebug then self:KeyTimelineDebug() end
        elseif arg == "off" or arg == "关" or arg == "关闭" then
            -- bug #114：玩家找不到嗜血进度条的开关（藏在实用工具→副本攻略里）。命令行直接关。
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.keyTimelineOff = true
            if self.KeyTimelineRefresh then self:KeyTimelineRefresh() end
            self:Print(T("KT_OFF", "钥匙时间轴已关闭（/gi kt on 重新打开；实用工具 → 副本攻略 里也能勾）。"))
        elseif arg == "scale" or cmd:match("^kt%s+scale") then
            local v = tonumber(cmd:match("^kt%s+scale%s+(%d+%.?%d*)"))
            if v and self.KeyTimelineSetScale then
                if v > 5 then v = v / 100 end                       -- 也认 150 这种百分比写法
                v = self:KeyTimelineSetScale(v)
                self:Print(T("KT_SCALE_SET", "钥匙时间轴大小：") .. string.format("%.0f%%", v * 100))
            else
                self:Print(T("KT_SCALE_USAGE", "用法：/gi kt scale 0.8～2.0（例如 1.5）"))
            end
        elseif arg == "on" or arg == "开" or arg == "开启" then
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.keyTimelineOff = false
            if self.KeyTimelineRefresh then self:KeyTimelineRefresh() end
            self:Print(T("KT_ON", "钥匙时间轴已开启。"))
        else
            self:Print(T("KT_HELP", "用法：/gi kt off（关闭）| on（开启）| scale 1.5（大小）| unlock（解锁拖动）| lock（锁定）| reset（复位）| debug（诊断，排查时发给作者）"))
        end
    elseif cmd == "tier" or cmd:match("^tier%s") then
        local arg = cmd:match("^tier%s+(%S+)") or ""
        local map = { m = "mythic", mythic = "mythic", h = "heroic", heroic = "heroic",
            n = "normal", normal = "normal",
            ["史诗"] = "mythic", ["英雄"] = "heroic", ["普通"] = "normal" }
        local t = map[arg]
        if t then
            self:SetGearTier(t)
        else
            self:Print(T("TIER_HELP", "用法：/gi tier m|h|n（史诗/英雄/普通）；当前：")
                .. self:GearTierLabel())
        end
    elseif cmd == "groupbis" or cmd:match("^groupbis%s") then
        local arg = cmd:match("^groupbis%s+(%S+)") or ""
        GearInsightDB = GearInsightDB or {}
        if arg == "off" then GearInsightDB.inspectBisOn = nil
        elseif arg == "on" then GearInsightDB.inspectBisOn = true
        else GearInsightDB.inspectBisOn = (not GearInsightDB.inspectBisOn) or nil end
        self:Print(GearInsightDB.inspectBisOn
            and T("IB_TOGGLE_ON", "组队悬停 BiS 毕业度：已开启")
            or T("IB_TOGGLE_OFF", "组队悬停 BiS 毕业度：已关闭"))
    elseif cmd == "team" or cmd == "队伍" or cmd == "体检" then
        if GearInsight.GroupBisPanel then
            GearInsight.GroupBisPanel:Toggle()
        else
            self:Print(T("GB_UNAVAIL", "团队 BiS 体检面板未加载"))
        end
    elseif cmd == "guild" or cmd == "公会" or cmd == "花名册" then
        if GearInsight.GuildRosterPanel then
            GearInsight.GuildRosterPanel:Toggle()
        else
            self:Print(T("GLD_UNAVAIL", "公会花名册面板未加载"))
        end
    elseif cmd == "tooltip" or cmd:match("^tooltip%s") then
        local arg = cmd:match("^tooltip%s+(%S+)") or ""
        local getCfg = GearInsight._tooltipBisCfg
        local c = getCfg and getCfg() or nil
        if not c then
            self:Print(T("TTBIS_TOGGLE_OFF", "物品 tooltip BiS 排名：已关闭"))
        elseif arg == "off" then
            c.enabled = false
            self:Print(T("TTBIS_TOGGLE_OFF", "物品 tooltip BiS 排名：已关闭"))
        elseif arg == "on" or arg == "" then
            c.enabled = true
            if c.mode == "off" then c.mode = "all" end
            self:Print(T("TTBIS_TOGGLE_ON", "物品 tooltip BiS 排名：已开启"))
        elseif arg == "current" then
            c.enabled = true
            c.mode = "current"
            self:Print(T("TTBIS_TOGGLE_CURRENT", "物品 tooltip：仅显示当前专精"))
        elseif arg == "all" then
            c.enabled = true
            c.mode = "all"
            self:Print(T("TTBIS_TOGGLE_ALL", "物品 tooltip：显示全部专精"))
        elseif arg == "others" then
            c.showOthers = not c.showOthers
            self:Print(c.showOthers and T("TTBIS_TOGGLE_OTHERS_ON", "物品 tooltip：显示其它职业")
                or T("TTBIS_TOGGLE_OTHERS_OFF", "物品 tooltip：隐藏其它职业"))
        else
            self:Print(T("TTBIS_TOGGLE_USAGE", "用法: /gi tooltip on|off|current|all|others（专精勾选请用面板「悬浮提示」按钮）"))
        end
    elseif cmd:match("^scale%s") then
        local scale = tonumber(cmd:match("^scale%s+(%d+%.?%d*)"))
        if scale and scale >= 0.5 and scale <= 2.0 then
            GearInsightDB.panelScale = scale
            if self._panelFrame then self._panelFrame:SetScale(scale) end
            if self._scaleLabel then self._scaleLabel:SetText(string.format("%.0f%%", scale * 100)) end
            self:Print(T("SCALE_SET", "面板缩放已设置为 ") .. scale)
        else
            self:Print(T("SCALE_USAGE", "用法: /gi scale <0.5-2.0>  当前: ") .. (GearInsightDB.panelScale or 1.0))
        end
    else
        self:Print("Unknown command. /gi help")
    end
end
