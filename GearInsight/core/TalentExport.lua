-- TalentExport：把 WCL 顶尖玩家天赋(GearInsightPopularTalents)编码成游戏可导入的天赋串。
-- 用游戏自带 C_Traits 权威节点顺序/哈希 + ExportUtil(官方位写入+base64)，序列化版本2
-- (header: version8 + specID16 + treeHash16字节; 每节点: 选中1 [购买1 [部分1(+rank6) 选择1(+idx2)]])。
-- 数据为 团本/冲分(mplusHigh)/割草(mplusFarm) 各前5名真实 build。

-- entryID -> {nodeID, choiceIdx(0基), isChoice, maxRanks}
local function buildEntryMap(configID, treeID)
    local map = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local ni = C_Traits.GetNodeInfo(configID, nodeID)
        if ni and ni.entryIDs then
            local isChoice = #ni.entryIDs > 1
            for i, eid in ipairs(ni.entryIDs) do
                map[eid] = { nodeID = nodeID, choiceIdx = i - 1, isChoice = isChoice, maxRanks = ni.maxRanks or 1 }
            end
        end
    end
    return map
end

-- 找匹配 specID 的天赋数据(含 builds)。
function GearInsight_GetTalentData(specID)
    for _, d in pairs(GearInsightPopularTalents or {}) do
        if d.specID == specID then return d end
    end
    return nil
end

-- 取激活配置与树 ID。返回 (configID, treeID) 或 (nil, err)。
local function activeTree()
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil, "取不到激活天赋配置(切到该专精了吗？)" end
    local cfg = C_Traits.GetConfigInfo(configID)
    local treeID = cfg and cfg.treeIDs and cfg.treeIDs[1]
    if not treeID then return nil, "找不到天赋树 ID" end
    return configID, treeID
end

-- 把 WCL build(扁平 flat={dictIdx,rank,...} + dict[dictIdx]=entryID)解析成
-- want[nodeID]={rank,choiceIdx,isChoice,maxRanks} / {granted=true}。导出和一键应用共用。
-- 返回 (want, matched)；matched=0 表示条目与当前树对不上。
local function buildWantTable(configID, treeID, flat, dict)
    local emap = buildEntryMap(configID, treeID)
    local want, matched, collide = {}, 0, 0
    local unmatched = {}
    for i = 1, #flat, 2 do
        local entryID = dict[flat[i]]
        local rank = flat[i + 1]
        local m = entryID and emap[entryID]
        if not m then
            -- WCL 条目对不上当前树(旧版本 entryID/PvP 天赋等)——这就是"总点数差几点"的来源
            unmatched[#unmatched + 1] = tostring(entryID or ("dict" .. tostring(flat[i]))) .. "x" .. tostring(rank)
        end
        if m then
            local ex = want[m.nodeID]
            if ex then
                -- 不同 entryID 撞到同一节点(多点天赋被WCL拆成多条)：累加点数,封顶 maxRanks,别覆盖丢点。
                ex.rank = math.min(m.maxRanks or 99, (ex.rank or 0) + rank)
                collide = collide + 1
            else
                want[m.nodeID] = { rank = rank, entryID = entryID, choiceIdx = m.choiceIdx,
                                   isChoice = m.isChoice, maxRanks = m.maxRanks }
            end
            matched = matched + 1
        end
    end
    if matched == 0 then return want, 0 end

    -- 补上"自动授予"(免费)节点：WCL talents 只记购买的，漏了免费节点 → 导入显示少点。
    -- 用玩家当前配置识别(activeRank>0 但 ranksPurchased=0 = 授予)；标记 selected 但 not purchased。
    local grantedN, purPts = 0, 0
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        if not want[nodeID] then
            local ni = C_Traits.GetNodeInfo(configID, nodeID)
            if ni and (ni.activeRank or 0) > 0 and (ni.ranksPurchased or 0) == 0 then
                want[nodeID] = { granted = true }
                grantedN = grantedN + 1
            end
        end
    end
    for _, w in pairs(want) do if not w.granted then purPts = purPts + (w.rank or 1) end end
    if GearInsight and GearInsight.talentDebug then
        print(string.format("|cFF66BBFF[GI天赋调试]|r 条目%d(共%d点) 碰撞%d + 授予%d + 未匹配%d%s",
            matched, purPts, collide, grantedN, #unmatched,
            #unmatched > 0 and (" [" .. table.concat(unmatched, ",") .. "]") or ""))
    end
    return want, matched
end

-- 把一套天赋编码成导入串。返回 (str, err)。
function GearInsight_ExportTalentBuild(specID, flat, dict)
    if not (C_ClassTalents and C_Traits and ExportUtil and ExportUtil.MakeExportDataStream) then
        return nil, "天赋 API 不可用(需正式服)"
    end
    if not flat or #flat == 0 or not dict then return nil, "无天赋数据" end
    local configID, treeID = activeTree()
    if not configID then return nil, treeID end

    local want, matched = buildWantTable(configID, treeID, flat, dict)
    if matched == 0 then return nil, "天赋条目与当前树对不上(切对专精了吗/版本变了？)" end

    local stream = ExportUtil.MakeExportDataStream()
    local version = (C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion()) or 2
    stream:AddValue(8, version)
    stream:AddValue(16, specID)
    local hash = C_Traits.GetTreeHash and C_Traits.GetTreeHash(treeID)
    if hash then
        for i = 1, 16 do stream:AddValue(8, hash[i] or 0) end
    else
        for i = 1, 16 do stream:AddValue(8, 0) end
    end
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local w = want[nodeID]
        if w then
            stream:AddValue(1, 1)                  -- isNodeSelected
            if w.granted then
                stream:AddValue(1, 0)              -- isNodePurchased=0 (免费授予,后面无位)
            else
                stream:AddValue(1, 1)              -- isNodePurchased
                local partial = (w.rank ~= w.maxRanks)
                stream:AddValue(1, partial and 1 or 0)
                if partial then stream:AddValue(6, w.rank) end
                stream:AddValue(1, w.isChoice and 1 or 0)
                if w.isChoice then stream:AddValue(2, w.choiceIdx) end
            end
        else
            stream:AddValue(1, 0)                  -- not selected
        end
    end
    return stream:GetExportString(), nil
end

-- 一键应用：纯 C_Traits 插件 API 把 WCL build 直接写到当前激活天赋配置——
-- ResetTree 全退点后按树序多趟回放(PurchaseRank/SetSelection，前置/门槛节点先通才
-- 解锁后面)，全部成功才 CommitConfig；任何节点应用不上就 RollbackConfig 原样退回。
-- 零 taint(不碰任何暴雪框体)，失败是普通返回值，调用方可安全降级到引导导入。
-- 只改当前天赋(等于手动点天赋树)，玩家已保存的载入档不会被覆盖。
-- 返回: (true, nil)=已应用生效; (true, "staged")=已选好但提交没过,需玩家在面板点
-- "应用更改"; (false, msg)=失败已回滚。
function GearInsight_ApplyTalentBuild(specID, flat, dict)
    if InCombatLockdown and InCombatLockdown() then
        return false, "战斗中不能改天赋"
    end
    if not (C_ClassTalents and C_Traits and C_Traits.ResetTree and C_Traits.PurchaseRank) then
        return false, "天赋 API 不可用(需正式服)"
    end
    if not flat or #flat == 0 or not dict then return false, "无天赋数据" end
    if GearInsight_CurrentSpecID() ~= specID then
        return false, "请先切到对应专精再导入"
    end
    local configID, treeID = activeTree()
    if not configID then return false, treeID end
    -- 上一次导入留下的暂存态会污染"授予节点"检测(实测 授予7→1 漂移)，先回滚到干净状态
    if C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(configID) then
        pcall(C_Traits.RollbackConfig, configID)
    end
    local want, matched = buildWantTable(configID, treeID, flat, dict)
    if matched == 0 then return false, "天赋条目与当前树对不上(版本变了？)" end

    if not C_Traits.ResetTree(configID, treeID) then
        return false, "重置天赋树失败"
    end
    -- 待回放节点。授予节点(WCL 不记点数)＝"确保激活"：真自动授予的零成本跳过；
    -- 但有些只在原配置下显示为授予、全新树里要花点买(暴雪 ImportLoadout 会自动买上，
    -- 这就是旧路径"不用手动补点"的来源)——可购买则买1点；买不上(如不知选哪支的
    -- 选择节点)标 soft 不算失败，走剩点提示兜底。
    local pending, total = {}, 0
    for nodeID, w in pairs(want) do
        if w.granted then
            pending[nodeID] = { rank = 1, soft = true }
        else
            pending[nodeID] = w
            total = total + 1
        end
    end
    local order = C_Traits.GetTreeNodes(treeID)
    -- 选择节点的完成标准必须是 activeRank>0：门槛未解锁时 SetSelection 会"选上但
    -- 不花点"(activeEntry 有了、activeRank=0)，当成功移出队列就把点卡死在那
    -- (实测 3 个绿框 rank0 节点=剩 3 点的真凶)。没到 rank 就留在队列里下一趟重试。
    local function choiceDone(nodeID, eid)
        local n2 = C_Traits.GetNodeInfo(configID, nodeID)
        return n2 and n2.activeEntry and n2.activeEntry.entryID == eid
            and (n2.activeRank or 0) > 0
    end
    for _ = 1, 12 do -- 多趟：每趟至少解锁一层，12 趟覆盖最深的门槛链
        local progress = false
        for _, nodeID in ipairs(order) do
            local w = pending[nodeID]
            if w then
                local ni = C_Traits.GetNodeInfo(configID, nodeID)
                if ni then
                    if w.isChoice then
                        -- 优先用 build 自带的精确 entryID；缺失才退回 choiceIdx 换算
                        local eid = w.entryID or (ni.entryIDs and ni.entryIDs[(w.choiceIdx or 0) + 1])
                        if eid then
                            if not choiceDone(nodeID, eid) then
                                C_Traits.SetSelection(configID, nodeID, eid)
                            end
                            if not choiceDone(nodeID, eid) and ni.canPurchaseRank then
                                pcall(C_Traits.PurchaseRank, configID, nodeID)
                            end
                            if choiceDone(nodeID, eid) then
                                pending[nodeID] = nil; progress = true
                            end
                        end
                    else
                        -- activeRank 含授予/自动激活：英雄子树首节点等 WCL 记作"已选"
                        -- 但游戏免费送，PurchaseRank 买不了——达标直接算完成。
                        local need = (w.rank or 1) - (ni.activeRank or 0)
                        if need <= 0 then
                            pending[nodeID] = nil; progress = true
                        else
                            local got = 0
                            while got < need and C_Traits.PurchaseRank(configID, nodeID) do
                                got = got + 1
                            end
                            if got > 0 then progress = true end
                            if got >= need then pending[nodeID] = nil end
                        end
                    end
                end
            end
        end
        if not next(pending) or not progress then break end
    end
    local left = 0
    for _, w in pairs(pending) do
        if not w.soft then left = left + 1 end -- soft(授予类)残留不算失败
    end
    if left > 0 then
        -- 调试模式列出残留节点的天赋名，方便定位是哪类节点应用不上
        if GearInsight and GearInsight.talentDebug then
            for nodeID, w in pairs(pending) do
                local ni = C_Traits.GetNodeInfo(configID, nodeID)
                local eid = w.entryID or (ni and ni.entryIDs and ni.entryIDs[1])
                local name = "?"
                if eid then
                    local ei = C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, eid)
                    local di = ei and ei.definitionID and C_Traits.GetDefinitionInfo(ei.definitionID)
                    local sp = di and di.spellID and C_Spell and C_Spell.GetSpellInfo
                        and C_Spell.GetSpellInfo(di.spellID)
                    name = (sp and sp.name) or ("spell" .. tostring(di and di.spellID or "?"))
                end
                print(string.format("|cFF66BBFF[GI天赋调试]|r 未应用 node%d %s (rank%s%s, active%s)",
                    nodeID, name, tostring(w.rank or 1), w.isChoice and " 选择" or "",
                    tostring(ni and ni.activeRank or "?")))
            end
        end
        pcall(C_Traits.RollbackConfig, configID) -- 丢弃暂存改动，玩家天赋原样退回
        return false, string.format("有 %d/%d 个天赋节点应用不上(等级/版本差异?)", left, total)
    end
    -- WCL 日志可能来自加点前的早期赛季(实测全库 build 流水 84-86 点 vs 当前预算 87)，
    -- 剩点会被暴雪拒绝提交。用"本专精全部 build 的条目流行度"自动补剩余点——
    -- 等于"其他顶尖玩家最常拿的下一手"，不是乱点。
    -- 探测剩点用 canPurchaseRank(还有节点能买=还有点)：未选英雄子树的节点本来就
    -- 买不了，天然排除（货币口径曾把剩3点算成16/29，已弃用）。
    local function anyPurchasable()
        for _, nodeID in ipairs(order) do
            local ni = C_Traits.GetNodeInfo(configID, nodeID)
            if ni and ni.canPurchaseRank then return true end
        end
        return false
    end
    if anyPurchasable() then
        local d = GearInsight_GetTalentData and GearInsight_GetTalentData(specID)
        local filled = 0
        if d and d.pool and d.dict then
            local freq = {}
            for _, fl in pairs(d.pool) do
                for i = 1, #fl, 2 do
                    local eid = d.dict[fl[i]]
                    if eid then freq[eid] = (freq[eid] or 0) + 1 end
                end
            end
            local emap = buildEntryMap(configID, treeID)
            local cands = {}
            for eid, fq in pairs(freq) do
                local m = emap[eid]
                if m then cands[#cands + 1] = { eid = eid, f = fq, m = m } end
            end
            table.sort(cands, function(a, b) return a.f > b.f end)
            for _ = 1, 4 do
                local progress = false
                for _, c in ipairs(cands) do
                    local ni = C_Traits.GetNodeInfo(configID, c.m.nodeID)
                    if ni then
                        if c.m.isChoice then
                            -- 只补"没生效"的选择节点(无选项,或选了但 rank0 没花上点)；
                            -- 绝不覆盖已生效(rank>0)的 build 选项
                            local cur = ni.activeEntry and ni.activeEntry.entryID
                            if (ni.activeRank or 0) == 0 and (not cur or cur == c.eid) then
                                C_Traits.SetSelection(configID, c.m.nodeID, c.eid)
                                local n2 = C_Traits.GetNodeInfo(configID, c.m.nodeID)
                                if n2 and (n2.activeRank or 0) == 0 and n2.canPurchaseRank then
                                    pcall(C_Traits.PurchaseRank, configID, c.m.nodeID)
                                    n2 = C_Traits.GetNodeInfo(configID, c.m.nodeID)
                                end
                                if n2 and (n2.activeRank or 0) > 0 then
                                    filled = filled + 1; progress = true
                                end
                            end
                        else
                            while ni.canPurchaseRank and C_Traits.PurchaseRank(configID, c.m.nodeID) do
                                filled = filled + 1; progress = true
                                ni = C_Traits.GetNodeInfo(configID, c.m.nodeID)
                            end
                        end
                    end
                end
                if not progress or not anyPurchasable() then break end
            end
        end
        if GearInsight and GearInsight.talentDebug then
            print(string.format("|cFF66BBFF[GI天赋调试]|r 流行度补点 %d (WCL 数据比当前版本少的点)", filled))
        end
    end
    -- 提交(真正花点/退点)。提交不过就留在暂存态，引导玩家在面板补操作。
    local okC, committed = pcall(C_ClassTalents.CommitConfig, configID)
    if okC and committed then return true, nil end
    return true, "staged"
end

-- 一键导入 —— ⛔ 只走 C API，绝不调 PlayerSpellsFrame.TalentsFrame:ImportLoadout
--
-- 2026-09-19 CF 玩家「李欧六」：一键导入后有概率动作条不显示 CD、鼠标点不动，/reload 才恢复。
-- 根因是 taint：从插件代码里调暴雪的 tf:ImportLoadout()，那个方法会往暴雪帧上写
-- self.nextNewConfigRequiresPopulatedCheck / SetCommitVisualsActive 等字段（带插件污点），
-- 之后 TRAIT_CONFIG_CREATED 的安全事件处理读到这些字段 → 整条 LoadConfig(autoApply) 链
-- 都在污点执行下跑 → 换完天赋刷新动作条时被判 ADDON_ACTION_BLOCKED，按钮就"死"了。
-- 概率性是因为只有走到 populated-check 分支时才会读那个字段。
--
-- 正确做法（TalentLoadoutManager 同款）：
--   1. 解码串：用 CreateFromMixins(ClassTalentImportExportMixin) 拿一份**插件自己的**表，
--      ReadLoadoutHeader / ReadLoadoutContent / ConvertToImportLoadoutEntryInfo 只读 self.bitWidth* 常量，
--      不碰暴雪帧；
--   2. C_ClassTalents.ImportLoadout(configID, entries, name, importText) 建档；
--   3. 等 TRAIT_CONFIG_CREATED 拿到新 configID；未 populated 就再等它的 TRAIT_CONFIG_UPDATED；
--   4. C_ClassTalents.LoadConfig(configID, true) 自动应用 + UpdateLastSelectedSavedConfigID 让下拉框选中它。
-- 全程没有一行代码碰暴雪帧。天赋面板不用开；开着也没关系，它自己的事件处理是安全上下文。
local _importEv
local function _startImportWatcher(specID, name, importStr, onDone)
    _importEv = _importEv or CreateFrame("Frame")
    local ev = _importEv
    local target, populatedWait, done = nil, false, false
    local function finish(ok, msg)
        if done then return end
        done = true
        ev:UnregisterAllEvents(); ev:SetScript("OnEvent", nil)
        if onDone then onDone(ok, msg) end
    end
    local function applyNow(cfgID)
        if InCombatLockdown and InCombatLockdown() then
            return finish(false, "进入战斗，载入档已建好但未应用：" .. name)
        end
        local ok, res, err = pcall(C_ClassTalents.LoadConfig, cfgID, true)
        if not ok then return finish(false, "LoadConfig 出错: " .. tostring(res)) end
        if res == Enum.LoadConfigResult.Error then
            return finish(false, "应用失败(" .. tostring(err) .. ")，载入档已建好：" .. name)
        end
        if C_ClassTalents.UpdateLastSelectedSavedConfigID then
            pcall(C_ClassTalents.UpdateLastSelectedSavedConfigID, specID, cfgID)
        end
        finish(true, name)
    end
    ev:RegisterEvent("TRAIT_CONFIG_CREATED")
    ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
    ev:SetScript("OnEvent", function(_, event, arg)
        if event == "TRAIT_CONFIG_CREATED" then
            local info = arg
            if not target and type(info) == "table" and info.type == Enum.TraitConfigType.Combat
               and (info.name == name or info.name == nil) then
                target = info.ID
                if C_ClassTalents.IsConfigPopulated and not C_ClassTalents.IsConfigPopulated(target) then
                    populatedWait = true      -- 有购买节点的档要等服务器填完再 Load
                else
                    applyNow(target)
                end
            end
        elseif event == "TRAIT_CONFIG_UPDATED" then
            if populatedWait and arg == target then
                populatedWait = false
                applyNow(target)
            end
        end
    end)
    C_Timer.After(8, function()
        if not done then
            finish(target ~= nil, target and (name .. "（已建档，未自动应用，天赋面板选它即可）")
                or "服务器没有回建档事件(8s)，请稍后重试")
        end
    end)
end

function GearInsight_TryImportTalents(importStr, name, onDone)
    if InCombatLockdown and InCombatLockdown() then
        return false, "战斗中不能改天赋"
    end
    if not importStr or importStr == "" then return false, "无导入串" end
    if not (C_ClassTalents and C_ClassTalents.ImportLoadout and C_ClassTalents.LoadConfig
            and C_Traits and ExportUtil and ExportUtil.MakeImportDataStream) then
        return false, "天赋 API 不可用(版本不符?)"
    end
    -- 解码用的 mixin 在 Blizzard_PlayerSpells 里，按需加载一次；⛔ 只借它的纯函数，不碰帧
    if not ClassTalentImportExportMixin then
        local loadFunc = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if loadFunc then pcall(loadFunc, "Blizzard_PlayerSpells") end
    end
    if not ClassTalentImportExportMixin then return false, "解码器未加载" end

    local curSpec = GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
    if not curSpec then return false, "取不到当前专精" end
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then return false, "取不到天赋配置" end

    -- 槽位已满预检（"导入配置失败"最常见真因，2026-06 实证）
    local cfgIDs = C_ClassTalents.GetConfigIDsBySpecID and C_ClassTalents.GetConfigIDsBySpecID(curSpec)
    if cfgIDs then
        local maxCfg = (C_ClassTalents.GetMaxConfigsPerSpecForPlayerCondition
            and C_ClassTalents.GetMaxConfigsPerSpecForPlayerCondition()) or 10
        if #cfgIDs >= maxCfg then
            return false, string.format("天赋配置已满(%d/%d)，请先在天赋面板删除一个载入档再导入",
                #cfgIDs, maxCfg)
        end
    end

    local dec = CreateFromMixins(ClassTalentImportExportMixin)
    local okS, stream = pcall(ExportUtil.MakeImportDataStream, importStr)
    if not okS or not stream then return false, "导入串无法解析" end
    local okH, headerValid, serVer, specID, treeHash = pcall(dec.ReadLoadoutHeader, dec, stream)
    if not okH or not headerValid then return false, "导入串格式错误" end
    if serVer ~= C_Traits.GetLoadoutSerializationVersion() then
        return false, "导入串版本与客户端不符"
    end
    if specID ~= curSpec then return false, "这串天赋不是当前专精的" end
    local treeID = C_Traits.GetConfigInfo(configID) and C_Traits.GetConfigInfo(configID).treeIDs
        and C_Traits.GetConfigInfo(configID).treeIDs[1]
    if not treeID then return false, "取不到天赋树" end
    if not dec:IsHashEmpty(treeHash) and not dec:HashEquals(treeHash, C_Traits.GetTreeHash(treeID)) then
        return false, "天赋树已改版，这串天赋过期了"
    end
    local okC, content = pcall(dec.ReadLoadoutContent, dec, stream, treeID)
    if not okC or not content then return false, "导入串内容解析失败" end
    local okE, entries = pcall(dec.ConvertToImportLoadoutEntryInfo, dec, configID, treeID, content)
    if not okE or not entries then return false, "节点换算失败" end

    local lname = "GI-" .. (name or "WCL")
    _startImportWatcher(curSpec, lname, importStr, onDone)
    local okI, success, errStr = pcall(C_ClassTalents.ImportLoadout, configID, entries, lname, importStr)
    if not okI then
        return false, "导入失败(" .. tostring(success) .. ")"
    end
    if not success then
        local es = tostring(errStr or "")
        if es:find("maximum") or es:find("limit") or es:find("Too many") then
            return false, "天赋配置已满，请先在天赋面板删除一个载入档再导入"
        end
        return false, "导入失败(" .. es .. ")"
    end
    return true, lname
end

-- ── 清理本插件导入的载入档 ─────────────────────────────────────────────
-- 玩家 2026-09-10：「有没有一键删除所有导入天赋的能力，现在容易生产很多」。
-- 判据只有一条：名字以 "GI-" 开头（上面 TryImportTalents 统一加的前缀）。
-- ⛔ 玩家自己建的档一个不碰；正在用的那份（GetLastSelectedSavedConfigID）也跳过——
--    删掉当前档会让天赋面板回到"未保存"状态，玩家会以为天赋没了。
function GearInsight_ListImportedLoadouts(specID)
    specID = specID or (GearInsight_CurrentSpecID and GearInsight_CurrentSpecID())
    local out = {}
    if not (specID and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID
            and C_Traits and C_Traits.GetConfigInfo) then
        return out
    end
    local active = C_ClassTalents.GetLastSelectedSavedConfigID
        and C_ClassTalents.GetLastSelectedSavedConfigID(specID) or nil
    for _, cid in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
        local ok, info = pcall(C_Traits.GetConfigInfo, cid)
        local nm = ok and info and info.name or nil
        if nm and nm:sub(1, 3) == "GI-" then
            out[#out + 1] = { id = cid, name = nm, active = (cid == active) }
        end
    end
    return out
end

-- 排队删（⛔不能一口气连发）：删除走服务器、一次只处理一个，前一个还没回包时再调
-- DeleteConfig 会直接返回 false（2026-09-10 用户截图：两份里第一份删了、第二份「被拒绝」，
-- 再点一次第二份又能删）。所以删一个 → 等 TRAIT_CONFIG_DELETED 回来 → 再删下一个；
-- 事件 1.5 秒没来就按超时继续，别卡死。
-- done(deleted, skipped, refusedNames, err) 在全部处理完后回调。
function GearInsight_ClearImportedLoadouts(specID, done)
    done = done or function() end
    if InCombatLockdown and InCombatLockdown() then
        return done(0, 0, {}, "战斗中不能改天赋")
    end
    if not (C_ClassTalents and C_ClassTalents.DeleteConfig) then
        return done(0, 0, {}, "无 DeleteConfig 接口(版本不符?)")
    end
    local queue, skip = {}, 0
    for _, lo in ipairs(GearInsight_ListImportedLoadouts(specID)) do
        if lo.active then skip = skip + 1 else queue[#queue + 1] = lo end
    end
    local n, refused = 0, {}
    local ev = CreateFrame("Frame")
    local waiting, timer
    local function step()
        if timer then timer:Cancel(); timer = nil end
        local lo = table.remove(queue, 1)
        if not lo then
            ev:UnregisterAllEvents()
            -- 删完催暴雪下拉刷新（面板开着的话）
            local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
            if tf then
                if tf.RefreshLoadoutOptions then pcall(tf.RefreshLoadoutOptions, tf) end
                if tf.UpdateConfigButtonsState then pcall(tf.UpdateConfigButtonsState, tf) end
            end
            return done(n, skip, refused, nil)
        end
        local ok, ret = pcall(C_ClassTalents.DeleteConfig, lo.id)
        if ok and ret ~= false then
            n = n + 1
            waiting = lo.id
            timer = C_Timer.NewTimer(1.5, function() timer = nil; waiting = nil; step() end)
        else
            refused[#refused + 1] = lo.name
            step()
        end
    end
    ev:RegisterEvent("TRAIT_CONFIG_DELETED")
    ev:SetScript("OnEvent", function(_, _, configID)
        if waiting and (configID == nil or configID == waiting) then
            waiting = nil
            step()
        end
    end)
    step()
end

-- 引导导入（降级用）：只负责"预检+打开暴雪天赋面板"，导入动作由玩家在暴雪自己的
-- 「导入载入档」对话框里完成（Ctrl+V 粘贴）。
-- skipSlotCheck: 一键应用已 staged、只是开面板让玩家点"应用更改"时传 true——
-- 此时不新建载入档，槽位满不满无关。
function GearInsight_OpenTalentImport(importStr, skipSlotCheck)
    if InCombatLockdown and InCombatLockdown() then
        return false, "战斗中不能改天赋"
    end
    if not importStr or importStr == "" then return false, "无导入串" end
    -- 1. 确保暴雪天赋面板已加载
    if not PlayerSpellsFrame then
        local loadFunc = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if loadFunc then pcall(loadFunc, "Blizzard_PlayerSpells") end
    end
    if not PlayerSpellsFrame then return false, "天赋面板未加载" end

    -- 配置档槽位已满预检：游戏对每专精的天赋载入档数量有上限，存满后 ImportLoadout
    -- 直接失败且只报笼统错误。提前数一下，满了就明确提示玩家先删一个（这是
    -- "导入配置失败"最常见的真实原因，2026-06 用户踩坑实证，与天赋点/编码无关）。
    local curSpec = (not skipSlotCheck) and GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
    local cfgIDs = curSpec and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID
        and C_ClassTalents.GetConfigIDsBySpecID(curSpec)
    if cfgIDs then
        local maxCfg = (C_ClassTalents.GetMaxConfigsPerSpecForPlayerCondition
            and C_ClassTalents.GetMaxConfigsPerSpecForPlayerCondition()) or 10
        if #cfgIDs >= maxCfg then
            return false, string.format("天赋配置已满(%d/%d)，请先在天赋面板删除一个载入档再导入",
                #cfgIDs, maxCfg)
        end
    end

    -- 2. 打开面板并切到天赋页，剩下交给玩家在暴雪 UI 里粘贴导入
    if not PlayerSpellsFrame:IsShown() then
        if ShowUIPanel then ShowUIPanel(PlayerSpellsFrame) else PlayerSpellsFrame:Show() end
    end
    if PlayerSpellsFrame.SetTab and PlayerSpellsFrame.talentTabID then
        pcall(PlayerSpellsFrame.SetTab, PlayerSpellsFrame, PlayerSpellsFrame.talentTabID)
    end
    return true, nil
end


-- 当前专精 specID
function GearInsight_CurrentSpecID()
    local curr = GetSpecialization and GetSpecialization()
    return curr and (GetSpecializationInfo(curr)) or nil
end

-- 测试斜杠命令：/gitalent —— 当前专精团本#1 build 串，弹复制框
SLASH_GITALENT1 = "/gitalent"
SlashCmdList["GITALENT"] = function(arg)
    if arg == "debug" then
        GearInsightDB = GearInsightDB or {}
        -- 运行时开关，不落盘：重登/reload 后默认关闭，避免调试日志常驻
        GearInsight = GearInsight or {}
        GearInsight.talentDebug = not GearInsight.talentDebug
        print("|cFF66BBFF[GearInsight]|r 天赋调试 " .. (GearInsight.talentDebug and "开" or "关"))
        return
    end
    local specID = GearInsight_CurrentSpecID()
    local d = specID and GearInsight_GetTalentData(specID)
    local ref = d and d.content and d.content.raid and d.content.raid[1] and d.content.raid[1].list[1]
    if not ref then print("|cFF66BBFF[GearInsight]|r 当前专精无天赋数据"); return end
    local str, err = GearInsight_ExportTalentBuild(specID, d.pool[ref.b], d.dict)
    if not str then print("|cFF66BBFF[GearInsight]|r 失败：" .. (err or "?")); return end
    if GearInsight and GearInsight.ShowCopyText then
        GearInsight:ShowCopyText(str, "Ctrl+C 复制 → 天赋面板「导入」粘贴", "WCL 团本 #1 天赋")
    else
        print(str)
    end
end
