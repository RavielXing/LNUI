local addonName = ...
U1PLUG["ExaltedPlus"] = function()

    local MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL or GetMaxLevelForPlayerExpansion();
    local factions, buln, frame = {}, function(v) return v end, CreateFrame("frame")
    ExaltedPlusFactions = {}
    
    -- 12.1 API: 缓存 SetWatchedFaction 函数
    local SetWatchedFactionByID = C_Reputation.SetWatchedFactionByID or C_Reputation.SetWatchedFactionByIndex
    
    -- 节流控制
    local UPDATE_THROTTLE = 0.3
    local lastFullUpdate = 0
    local pendingUpdate = false

    function frame.enumfactions()
        if not frame.loaded then
            frame.loaded = true
            for id in pairs(ExaltedPlusFactions) do
                factions[id] = factions[id] or {}
            end
        end
        for id, faction in pairs(factions) do
            local value, max, _, reward = C_Reputation.GetFactionParagonInfo(id)
            if value then
                faction.timesdone = reward and math.modf(value / max) - 1 or math.modf(value / max)
                faction.value = mod(value, max)
                faction.max = max
                faction.reward = reward
            else
                -- 12.1: 清理无巅峰数据的阵营，防止表无限增长
                factions[id] = nil
                ExaltedPlusFactions[id] = nil
            end
        end
    end

    -- 只更新指定行，不遍历整个列表
    local function UpdateRow(row)
        local fact = row.factionID and factions[row.factionID]
        if fact and fact.value and fact.max then
            local factionLevel = 0
            local factionData = C_Reputation.GetFactionDataByIndex(row.factionIndex)
            if factionData then
                ExaltedPlusFactions[row.factionID] = factionData.name
                factionLevel = factionData.reaction
            end
            row.rolloverText = " " .. format(REPUTATION_PROGRESS_FORMAT, buln(fact.value), buln(fact.max))
            row.Content.ReputationBar:UpdateBarValues(0, fact.max, fact.value)
            
            local times = fact.timesdone or 0
            if fact.reward then
                row.standingText = CONTRIBUTION_REWARD_TOOLTIP_TITLE .. "" .. (times + 1) .. " +" .. fact.value
            else
                row.standingText = GetText("FACTION_STANDING_LABEL" .. factionLevel, (UnitSex('player'))) .. (times > 0 and "*" .. times or "+")
            end
            row.Content.ReputationBar:UpdateReputationStandingText(row.standingText)
            row.Content.ReputationBar:TryShowReputationStandingText()
        end
    end

    function frame.update(force)
        local now = GetTime()
        if not force and (now - lastFullUpdate) < UPDATE_THROTTLE then
            pendingUpdate = true
            return
        end
        lastFullUpdate = now
        pendingUpdate = false

        -- 清理已不存在的行引用，防止内存泄漏
        for id, fact in pairs(factions) do
            if fact.row and (not fact.row.GetParent or not fact.row:GetParent()) then
                fact.row = nil
            end
        end

        for _, row in ReputationFrame.ScrollBox:EnumerateFrames() do
            if row.factionID then
                if C_Reputation.IsFactionParagon(row.factionID) then
                    factions[row.factionID] = factions[row.factionID] or {}
                    factions[row.factionID].row = row
                else
                    ExaltedPlusFactions[row.factionID] = nil
                    factions[row.factionID] = nil
                end
            end
        end
        frame.enumfactions()
        frame.repframevis = ReputationFrame:IsVisible()
        
        -- 只查找一次监视条，缓存结果
        if not frame.watchbar or not frame.watchbar.GetParent then
            for _, container in pairs(StatusTrackingBarManager.barContainers or {}) do 
                for _, bar in pairs(container.bars or {}) do
                    if bar.factionID then
                        frame.watchbar = bar
                        break
                    end
                end
                if frame.watchbar then break end
            end
        end
    end

    -- OnUpdate 优化：无动画需求时直接返回
    frame:SetScript("OnUpdate", function(self, elapsed)
        if pendingUpdate then
            frame.update()
        end
        
        local needAnimate = false
        if self.repframevis then
            for _, faction in pairs(factions) do
                if faction.reward and faction.row and faction.row.Content then
                    needAnimate = true
                    break
                end
            end
        end
        if self.pulsewatchbar and frame.watchbar then
            needAnimate = true
        end
        if not needAnimate then return end

        if not self.alpha then self.alpha = 0.3 end
        if self.reverse then
            self.alpha = self.alpha - elapsed * 1.5
        else
            self.alpha = self.alpha + elapsed * 1.5
        end
        if self.alpha >= 1 then
            self.alpha = 1; self.reverse = true
        elseif self.alpha <= 0.3 then
            self.alpha = 0.3; self.reverse = false
        end

        if self.repframevis then
            for _, faction in pairs(factions) do
                if faction.reward and faction.row and faction.row.Content then
                    local bar = faction.row.Content.ReputationBar
                    local r, g, b = bar:GetStatusBarColor()
                    bar:SetStatusBarColor(r, g, b, self.alpha)
                end
            end
        end
        if self.pulsewatchbar and frame.watchbar and frame.watchbar.StatusBar then
            local r, g, b = frame.watchbar.StatusBar:GetStatusBarColor()
            frame.watchbar.StatusBar:SetStatusBarColor(r, g, b, self.alpha)
        end
    end)

    local function gttfind(q, ...)
        for i = 1, select("#", ...) do
            local r = select(i, ...)
            if r and r.GetText and r:GetText() == q then
                return r
            end
        end
        return { SetText = function(_, t) GameTooltip:AddLine(t) GameTooltip:Show() end }
    end

    hooksecurefunc("EmbeddedItemTooltip_SetItemByQuestReward", function()
        -- 12.1: 减少不必要的全量更新，只做最小化数据刷新
        frame.enumfactions()
        local mf = GetMouseFoci and GetMouseFoci()[1] or GetMouseFocus()
        if mf and mf.factionID and factions[mf.factionID] and factions[mf.factionID].timesdone then
            local text = format(ARCHAEOLOGY_COMPLETION, factions[mf.factionID].timesdone)
            gttfind(REWARDS, GameTooltip:GetRegions()):SetText(text)
        end
    end)

    hooksecurefunc(ReputationEntryMixin, "Initialize", function(row)
        -- 12.1 关键优化：不再调用昂贵的 frame.update()，只更新当前行
        if row.factionID and C_Reputation.IsFactionParagon(row.factionID) then
            factions[row.factionID] = factions[row.factionID] or {}
            factions[row.factionID].row = row
            frame.enumfactions()
            UpdateRow(row)
        end
    end)

    -- 延迟全量更新，降低峰值
    local updateTimer
    local function QueueUpdate()
        if updateTimer then return end
        updateTimer = C_Timer.NewTimer(0.2, function()
            updateTimer = nil
            frame.update(true)
        end)
    end

    -- 经验条/声望条变更时队列更新
    hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", QueueUpdate)

    ExaltedPlusLastFactions = {}
    local lastFactionCacheTime = 0
    function EP_RefreshAllFactions()
        local now = GetTime()
        if now - lastFactionCacheTime < 1 then return end  -- 1秒节流
        lastFactionCacheTime = now
        wipe(ExaltedPlusLastFactions)
        for i = 1, C_Reputation.GetNumFactions() do
            local factionData = C_Reputation.GetFactionDataByIndex(i)
            if factionData then
                ExaltedPlusLastFactions[factionData.name] = { value = factionData.currentStanding, id = factionData.factionID }
            end
        end
    end

    function EP_FindFaction(faction)
        local isGuild = false
        if faction == GUILD then isGuild = true; faction = GetGuildInfo("player") end
        if not ExaltedPlusLastFactions[faction] then
            EP_RefreshAllFactions()
        end
        local info = ExaltedPlusLastFactions[faction]
        if not info then return end
        
        local factionData = C_Reputation.GetFactionDataByID(info.id)
        if not factionData then return end
        local barValue = factionData.currentStanding
        
        local reputationInfo = info.id and C_GossipInfo.GetFriendshipReputation(info.id)
        if reputationInfo and reputationInfo.friendshipFactionID > 0 then
            barValue = reputationInfo.standing
        end
        
        local watchedFactionData = C_Reputation.GetWatchedFactionData()
        local oldName = watchedFactionData and watchedFactionData.name
        
        if UnitLevel("player") == MAX_PLAYER_LEVEL and not isGuild and oldName ~= faction then
            -- 12.1: 优先使用 ID 设置，避免按索引的不可靠性
            if SetWatchedFactionByID then
                SetWatchedFactionByID(info.id)
            elseif C_Reputation.SetWatchedFactionByIndex then
                for i = 1, C_Reputation.GetNumFactions() do
                    local fd = C_Reputation.GetFactionDataByIndex(i)
                    if fd and fd.name == faction then
                        C_Reputation.SetWatchedFactionByIndex(i)
                        break
                    end
                end
            end
        end

        local diff = barValue - info.value
        info.value = barValue
        return info, diff
    end

    ChatFrame_AddMessageEventFilter('CHAT_MSG_COMBAT_FACTION_CHANGE', function(_, _, msg, ...)
        -- 预编译 pattern 减少 GC
        local kind, name, added = 1, strmatch(msg, gsub(FACTION_STANDING_INCREASED_GENERIC, "%%%d?$?s", "(.+)"))
        if not name then
            kind, name, added = 2, strmatch(msg, (gsub(FACTION_STANDING_INCREASED, "%%[ds]", "(.+)")))
        end
        if not name then
            kind, name, added = 5, strmatch(msg, (gsub(FACTION_STANDING_INCREASED_ACCOUNT_WIDE, "%%[ds]", "(.+)")))
        end
        if not name then
            kind, name, added = 3, strmatch(msg, LOCALE_zhCN and "(.*)现在觉得你更有价值了" or "(.*)現在覺得你更有價值了")
        end
        if not name then
            kind, name, added = 4, strmatch(msg, LOCALE_zhCN and "(.*)的奥术能量提升了。" or "(.*)的奧術能量提升了。")
        end
        if not name then return end

        local info, diff = EP_FindFaction(name)
        if not info then return end

        local reputationInfo = info.id and C_GossipInfo.GetFriendshipReputation(info.id)
        if reputationInfo and reputationInfo.friendshipFactionID > 0 then
            local output = LOCALE_zhCN and "%s%s的声望提高了%s（%s%d/%d）" or "%s%s的聲望提高了%s（%s%d/%d）"
            local curr = reputationInfo.standing - (reputationInfo.reactionThreshold or 0)
            local cap = (reputationInfo.nextThreshold or 0) - (reputationInfo.reactionThreshold or 0)
            local change = tonumber(added) or diff or 0
            change = change > 0 and (LOCALE_zhCN and change .. "点" or change .. "點") or ""
            local rankText = ""
            local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(info.id)
            if rankInfo and rankInfo.maxLevel > 0 then
                rankText = "(" .. rankInfo.currentLevel .. "/" .. rankInfo.maxLevel .. ")"
            end
            msg = format(output, name, rankText, change, reputationInfo.reaction, curr, cap)
        elseif info.id and C_Reputation.IsMajorFaction(info.id) then
            local output = LOCALE_zhCN and "%s的声望提高了%d点。" or "%s的聲望提高了%d點。"
            local majorFactionData = C_MajorFactions.GetMajorFactionData(info.id)
            local levelLabel = RENOWN_LEVEL_LABEL .. majorFactionData.renownLevel
            msg = format(output, name, added or diff, levelLabel, majorFactionData.renownReputationEarned or 0)
        else
            local output = LOCALE_zhCN and "%s的声望提高了%d点（%s%d）" or "%s的聲望提高了%d點（%s%d）"
            local factionData = C_Reputation.GetFactionDataByID(info.id)
            if not factionData then return end
            local level, levelMin, levelCurr = factionData.reaction, factionData.currentReactionThreshold, factionData.currentStanding
            local levelLabel = GetText("FACTION_STANDING_LABEL" .. level, (UnitSex('player')))
            local paragonCurr, cap, unknown, reward = C_Reputation.GetFactionParagonInfo(info.id)
            if paragonCurr and cap and cap > 0 then
                local times = math.modf(paragonCurr / cap)
                local remain = mod(paragonCurr, cap)
                msg = format(output, name, added or diff, levelLabel .. (times > 0 and "*" .. times or "") .. " +", remain)
            else
                msg = format(output, name, added or diff, levelLabel, levelCurr - levelMin)
            end
        end
        return false, msg, ...
    end)
end