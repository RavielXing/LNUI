local addonName = ...
U1PLUG["ExaltedPlus"] = function()

	local MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL or GetMaxLevelForPlayerExpansion();
    local factions,buln,frame={},function(v) return v end,CreateFrame("frame") --buln = BreakUpLargeNumbers
    ExaltedPlusFactions={}
    function frame.enumfactions()
        if not frame.loaded then
            frame.loaded=true
            for id in pairs(ExaltedPlusFactions) do
                factions[id]={}
            end
        end
        local value, _
        for id,faction in pairs(factions) do
            value,faction.max,_,faction.reward=C_Reputation.GetFactionParagonInfo(id)
            if value then
                faction.timesdone=faction.reward and math.modf(value/faction.max)-1 or math.modf(value/faction.max)
                faction.value=mod(value,faction.max)
            end
        end
    end
    function frame.update()
        for _,row in ReputationFrame.ScrollBox:EnumerateFrames() do
            if row.factionID then
                if C_Reputation.IsFactionParagon(row.factionID) then
                    if not factions[row.factionID] then
                        factions[row.factionID]={}
                    end
                    factions[row.factionID].row=row
                else
                    ExaltedPlusFactions[row.factionID]=nil
                end
            end
        end
        frame.enumfactions()
        frame.repframevis=ReputationFrame:IsVisible()
        for _,container in pairs(StatusTrackingBarManager.barContainers) do 
			for _,bar in pairs(container.bars) do
				if bar.factionID then
					frame.watchbar=bar
				end
			end
		end
    end
    frame:SetScript("OnUpdate",function(self,elapsed)
        if not self.alpha then
            self.alpha=0.3
        end
        if self.reverse then
            self.alpha=self.alpha-elapsed
        else
            self.alpha=self.alpha+elapsed
        end
        if self.alpha>=1 then
            self.alpha=1
            self.reverse=true
        elseif self.alpha<=0.3 then
            self.alpha=0.3
            self.reverse=false
        end
        if self.repframevis then
            for _,faction in pairs(factions) do
                if faction.reward and faction.row then
                    local red,green,blue=faction.row.Content.ReputationBar:GetStatusBarColor()
                    faction.row.Content.ReputationBar:SetStatusBarColor(red,green,blue,self.alpha)
                end
            end
        end
        if self.pulsewatchbar then
            local red,green,blue=frame.watchbar.StatusBar:GetStatusBarColor()
            frame.watchbar.StatusBar:SetStatusBarColor(red,green,blue,self.alpha)
        end
    end)
    local function gttfind(q,...)
        for i=1,select("#",...) do
            local r=select(i,...)
            if r and r.GetText and r:GetText()==q then
                return r
            end
        end
        return {SetText=function(_,t) GameTooltip:AddLine(t) GameTooltip:Show() end}
    end
    hooksecurefunc("EmbeddedItemTooltip_SetItemByQuestReward",function()
        frame.update()
        local mf=GetMouseFoci() and GetMouseFoci()[1]
        if mf and mf.factionID and factions[mf.factionID] and factions[mf.factionID].timesdone then
            local text=format(ARCHAEOLOGY_COMPLETION,factions[mf.factionID].timesdone)
            gttfind(REWARDS,GameTooltip:GetRegions()):SetText(text)
        end
    end)
    hooksecurefunc(ReputationEntryMixin, "Initialize", function(row)
        frame.update()
        local fact = row.factionID and factions[row.factionID]
        if fact and fact.value and fact.max then
            local factionLevel, _
			local factionData = C_Reputation.GetFactionDataByIndex(row.factionIndex)
			if factionData then
				ExaltedPlusFactions[row.factionID], factionLevel=factionData.name,factionData.reaction
			end
            row.rolloverText=" "..format(REPUTATION_PROGRESS_FORMAT,buln(fact.value),buln(fact.max))
            --row.Container.ReputationBar:SetMinMaxValues(0,fact.max)
            --row.Container.ReputationBar:SetValue(fact.value)
			row.Content.ReputationBar:UpdateBarValues(0, fact.max, fact.value);
            --row.Container.Paragon.Check:SetShown(false)
            --row.Container.Paragon.Glow:SetShown(false)
            --row.Container.Paragon.Highlight:SetShown(false)
            --row.Container.Paragon.Icon:SetAlpha(fact.reward and 1 or 0.5) --巅峰没奖励的半透明
            --条上数字，待领取的："奖励7 +当前值"  未满的："巅峰*9"
            local times = fact.timesdone or 0
            if fact.reward then
                row.standingText = CONTRIBUTION_REWARD_TOOLTIP_TITLE..""..(times+1).." +"..fact.value
            else
                row.standingText = GetText("FACTION_STANDING_LABEL"..factionLevel,(UnitSex('player'))) .. (times > 0 and "*"..times or "+")
            end
            --row.Container.ReputationBar.FactionStanding:SetText(row.standingText)
			row.Content.ReputationBar:UpdateReputationStandingText(row.standingText);
			row.Content.ReputationBar:TryShowReputationStandingText();
        end
    end)

    --ExaltedPlusLastFactions
    ExaltedPlusLastFactions = {}
    function EP_RefreshAllFactions()
        for i=1, C_Reputation.GetNumFactions() do
            --local name, description, standingID, barMin, barMax, barValue,_,_,_,_,_,_,_,factionID = GetFactionInfo(i)
			local factionData = C_Reputation.GetFactionDataByIndex(i)
			if factionData then
			    ExaltedPlusLastFactions[factionData.name] = { value = factionData.currentStanding, id = factionData.factionID }
			end
        end
    end

    function EP_FindFaction(faction)
        local isGuild = false
        if faction==GUILD then isGuild = true faction = GetGuildInfo("player") end
        if not ExaltedPlusLastFactions[faction] then
            EP_RefreshAllFactions()
        end
        local info = ExaltedPlusLastFactions[faction]
        if not info then return end --没有找到
        --local _, _, standingID, barMin, barMax, barValue = GetFactionInfoByID(info.id)
		local factionData = C_Reputation.GetFactionDataByID(info.id)
		local barValue = factionData.currentStanding
        local reputationInfo = info.id and C_GossipInfo.GetFriendshipReputation(info.id);
        if reputationInfo and reputationInfo.friendshipFactionID > 0 then
            barValue = reputationInfo.standing
        end
        --设置经验条
        --local oldName,_,_,_,_ = GetWatchedFactionInfo();
		local watchedFactionData = C_Reputation.GetWatchedFactionData()
		local oldName
		if watchedFactionData then 
			oldName = watchedFactionData.name
		end
        if UnitLevel("player") == MAX_PLAYER_LEVEL and not isGuild and oldName ~= faction then -- and U1GetCfgValue(addonName, 'ExaltedPlus/autotrace') then
            for i=1, C_Reputation.GetNumFactions() do
				local factionData2 = C_Reputation.GetFactionDataByIndex(i)
                if factionData2 then
                    if factionData2.name == faction then C_Reputation.SetWatchedFactionByIndex(i) end --也许顺序会变
                end
            end
        end

        local diff = barValue - info.value
        info.value = barValue
        return info, diff
    end

    ChatFrame_AddMessageEventFilter('CHAT_MSG_COMBAT_FACTION_CHANGE',function(_,_,msg,...)
        local kind, name, added = 1, strmatch(msg,gsub(FACTION_STANDING_INCREASED_GENERIC,"%%%d?$?s","(.+)")) --"在%s中的声望提升了。" --7.2.5的巅峰不是这种情况了
        if not name then
            kind, name, added = 2, strmatch(msg, (gsub(FACTION_STANDING_INCREASED,"%%[ds]","(.+)"))) --"你在(.+)中的声望值提高了(.+)点。" msg = "你在抗魔联军中的声望值提高了75点。"
        end
		if not name then
            kind, name, added = 5, strmatch(msg, (gsub(FACTION_STANDING_INCREASED_ACCOUNT_WIDE,"%%[ds]","(.+)"))) --"你的战团在(.+)中的声望值提高了(.+)点。" msg = "你的战团在抗魔联军中的声望值提高了75点。"
        end
        if not name then
            kind, name, added = 3, strmatch(msg, LOCALE_zhCN and "(.*)现在觉得你更有价值了" or "(.*)現在覺得你更有價值了") --"威·娜莉现在觉得你更有价值了。 [获得了80点声望]"
        end
        if not name then
            kind, name, added = 4, strmatch(msg, LOCALE_zhCN and "(.*)的奥术能量提升了。" or "(.*)的奧術能量提升了。") --"钴蓝集所"
        end
        if not name then return end

        local info, diff = EP_FindFaction(name)
        if not info then return end

        --if DEBUG_MODE then print(msg, info.id, added, diff) end
        local reputationInfo = info.id and C_GossipInfo.GetFriendshipReputation(info.id);
        if reputationInfo and reputationInfo.friendshipFactionID > 0 then
            local output = LOCALE_zhCN and "%s%s的声望提高了%s（%s%d/%d）" or "%s%s的聲望提高了%s（%s%d/%d）"
            local curr = reputationInfo.standing - (reputationInfo.reactionThreshold or 0)
            local cap = (reputationInfo.nextThreshold or 0) - (reputationInfo.reactionThreshold or 0)
            local change = tonumber(added) or diff or 0
            change = LOCALE_zhCN and change > 0 and change .. "点" or "" or change > 0 and change .. "點" or ""
            local rankText = ""
            local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(info.id)
            if rankInfo and rankInfo.maxLevel > 0 then
                rankText = "("..rankInfo.currentLevel.."/"..rankInfo.maxLevel..")"
            end
            msg=format(output, name, rankText, change, reputationInfo.reaction, curr, cap) --钴蓝集所(3/5)的声望提高了19点(低684/900)
        elseif info.id and C_Reputation.IsMajorFaction(info.id) then
            local output = LOCALE_zhCN and "%s的声望提高了%d点。" or "%s的聲望提高了%d點。"--lnui，原来LOCALE_zhCN and "%s的声望提高了%d点（%s/%d）" or "%s的聲望提高了%d點（%s/%d）"
            local majorFactionData = C_MajorFactions.GetMajorFactionData(info.id); --2507
            local levelLabel = RENOWN_LEVEL_LABEL .. majorFactionData.renownLevel;
            msg=format(output, name, added or diff, levelLabel, majorFactionData.renownReputationEarned or 0) --暗夜精灵声望提高了75点（名望1/2570)
        else
            local output = LOCALE_zhCN and "%s的声望提高了%d点（%s%d）" or "%s的聲望提高了%d點（%s%d）"
            --local _, _, level, levelMin, _, levelCurr = GetFactionInfoByID(info.id)
			local factionData = C_Reputation.GetFactionDataByID(info.id)
			local level, levelMin, levelCurr = factionData.reaction, factionData.currentReactionThreshold, factionData.currentStanding
            local levelLabel = GetText("FACTION_STANDING_LABEL"..level,(UnitSex('player')))
            local paragonCurr, cap, unknown, reward = C_Reputation.GetFactionParagonInfo(info.id)
            if paragonCurr then
                local times = math.modf(paragonCurr/cap)
                local remain = mod(paragonCurr, cap)
                msg=format(output, name, added or diff, levelLabel .. (times > 0 and "*" .. times or "").." +", remain) --开悟者的声望提高了75点(崇拜*10 +1000)
            else
                msg=format(output, name, added or diff, levelLabel, levelCurr - levelMin) --暗夜精灵声望提高了75点（崇敬158)
            end
        end



        return false,msg,...
    end)

end
