local addonName = ...

ChallengesGuildBestMixin = {};

function ChallengesGuildBestMixin:SetUp(leaderInfo)
    self.leaderInfo = leaderInfo;

    local str = CHALLENGE_MODE_GUILD_BEST_LINE;
    if (leaderInfo.isYou) then
    end

    local classColorStr = RAID_CLASS_COLORS[leaderInfo.classFileName].colorStr;

    self.CharacterName:SetText(str:format(classColorStr, leaderInfo.name));
    self.Level:SetText(leaderInfo.keystoneLevel);
end

function ChallengesGuildBestMixin:OnEnter()
    local leaderInfo = self.leaderInfo;

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    local name = C_ChallengeMode.GetMapUIInfo(leaderInfo.mapChallengeModeID);
    GameTooltip:SetText(name, 1, 1, 1);
    GameTooltip:AddLine(CHALLENGE_MODE_POWER_LEVEL:format(leaderInfo.keystoneLevel));
    for i = 1, #leaderInfo.members do
        local classColorStr = RAID_CLASS_COLORS[leaderInfo.members[i].classFileName].colorStr;
        GameTooltip:AddLine(CHALLENGE_MODE_GUILD_BEST_LINE:format(classColorStr,leaderInfo.members[i].name));
    end
    GameTooltip:Show();
end

ChallengesFrameGuildBestMixin = {};

function ChallengesFrameGuildBestMixin:SetUp(leaders)
    for i = 1, #leaders do
        local frame = self.GuildBests[i];
        if (not frame) then
            frame = CreateFrame("Frame", nil, self, "ChallengesGuildBestTemplate");
            frame:SetPoint("TOP", self.GuildBests[i-1], "BOTTOM");
        end
        frame:SetUp(leaders[i]);
        frame:Show();
    end
    for i = #leaders + 1, #self.GuildBests do
        self.GuildBests[i]:Hide();
    end
end

CoreDependCall("Blizzard_ChallengesUI", function()
    if U1DBG and U1DBG.hideAbyGuildBest then return end

    --======================================================
    -- 本周大秘境面板显示
    --======================================================
    local MPDisplay = _G["MyMythicPlusDisplay"]
    if not MPDisplay then
        MPDisplay = CreateFrame("Frame", "MyMythicPlusDisplay", UIParent, "BackdropTemplate")
        MPDisplay:SetSize(200, 150)
        MPDisplay:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        MPDisplay:SetBackdropColor(0, 0, 0, 0.3)
        MPDisplay:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.4)
        MPDisplay:Hide()
        MPDisplay.text = MPDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        MPDisplay.text:SetPoint("TOPLEFT", MPDisplay, "TOPLEFT", 8, -8)
        MPDisplay.text:SetJustifyH("LEFT")
        MPDisplay:SetMovable(true)
        MPDisplay:EnableMouse(true)
        MPDisplay:RegisterForDrag("LeftButton")
        MPDisplay:SetScript("OnDragStart", MPDisplay.StartMoving)
        MPDisplay:SetScript("OnDragStop", MPDisplay.StopMovingOrSizing)
    end

    -- 缓存副本名称，避免重复查询
    local dungeonNameCache = {}
    local function GetDungeonName(mapID)
        if dungeonNameCache[mapID] then
            return dungeonNameCache[mapID]
        end
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        name = name or ("地图"..mapID)
        dungeonNameCache[mapID] = name
        return name
    end

    -- 12.1 优化：使用 table.concat 替代 .. 字符串拼接，大幅减少中间字符串对象和 GC 压力
    local function GetMythicPlusDataForPanel()
        local history = C_MythicPlus.GetRunHistory(false, true)
        
        if not history or #history == 0 then
            return "|cffff0000本周暂无记录|r", 0
        end
        
        local total = #history
        local completed = 0
        local bestLevel = 0
        local dungeonData = {}
        
        for _, run in ipairs(history) do
            local id = run.mapChallengeModeID
            if not dungeonData[id] then
                dungeonData[id] = {
                    name = GetDungeonName(id),
                    runs = {},
                    completed = 0,
                    best = 0,
                }
            end
            
            local d = dungeonData[id]
            table.insert(d.runs, {
                level = run.level,
                completed = run.completed
            })
            
            if run.completed then
                completed = completed + 1
                d.completed = d.completed + 1
                if run.level > d.best then
                    d.best = run.level
                end
                if run.level > bestLevel then
                    bestLevel = run.level
                end
            end
        end

        local lines = {}
        table.insert(lines, string.format("|cffff8f00本周:|r |cffffffff%d|r次 (|cff00ff00%d|r限)", total, completed))
        table.insert(lines, string.format("|cffffaa00最高:|r |cffffffff%d|r", bestLevel))
        table.insert(lines, "")

        for id, data in pairs(dungeonData) do
            table.insert(lines, string.format("|cff19CCF9%s|r |cffffaa00(|r|cffffffff%d|r|cffffaa00次, |r|cff00ff00%d|r|cffffaa00限, 最高%d层)|r", 
                data.name, #data.runs, data.completed, data.best))
            
            table.sort(data.runs, function(a, b)
                if a.completed == b.completed then
                    return a.level > b.level
                end
                return a.completed
            end)
            
            local count = 0
            local runParts = {}
            for _, run in ipairs(data.runs) do
                if count > 0 and count % 7 == 0 then
                    table.insert(runParts, "\n  ")
                elseif count > 0 then
                    table.insert(runParts, ", ")
                else
                    table.insert(runParts, "  ")
                end
                
                if run.completed then
                    table.insert(runParts, string.format("|cff00ff00%d|r", run.level))
                else
                    table.insert(runParts, string.format("|cffF00000%d|r", run.level))
                end
                count = count + 1
            end
            table.insert(lines, table.concat(runParts))
            table.insert(lines, "")
        end
        
        return table.concat(lines, "\n"), total
    end

    local lastPanelWidth = 0
    local function UpdatePanelDisplay()
        MPDisplay.text:SetWidth(0)
        
        local displayText = GetMythicPlusDataForPanel()
        MPDisplay.text:SetText(displayText)
        
        local textWidth = MPDisplay.text:GetStringWidth()
        local targetWidth = math.min(math.max(textWidth + 16, 150), 450)
        
        -- 12.1 优化：只在宽度变化时才设置，减少布局重排
        if math.abs(targetWidth - lastPanelWidth) > 1 then
            lastPanelWidth = targetWidth
            MPDisplay:SetWidth(targetWidth)
            MPDisplay.text:SetWidth(targetWidth - 16)
        end
        
        local height = MPDisplay.text:GetStringHeight() + 16
        MPDisplay:SetHeight(math.max(height, 60))
    end

    --======================================================
    -- 公会最佳成绩功能
    --======================================================
    local function updateGuildBest()
        local best = AbyChallengesFrameGuildBest
        if not best then return end
        
        if best:GetParent() ~= ChallengesFrame then
            best:SetParent(ChallengesFrame)
            best:SetPoint("TOPRIGHT", -5, -20)
        end
        
        local leaders = C_ChallengeMode.GetGuildLeaders()
        if leaders and #leaders > 0 then
            best:SetUp(leaders)
            best:Show()
        else
            best:Hide()
        end
        
        if not ChallengesFrame._abyPointSet then
            ChallengesFrame.WeeklyInfo.Child:SetPoint("TOPLEFT", -25, 0)
            ChallengesFrame._abyPointSet = true
        end
    end

    --======================================================
    -- 面板显示控制
    --======================================================
    local updateTimer = nil

    local function ShowAndUpdatePanel()
        if not MPDisplay:IsShown() then
            MPDisplay:Show()
        end
        MPDisplay:ClearAllPoints()
        MPDisplay:SetPoint("TOPLEFT", ChallengesFrame, "TOPRIGHT", 3, 0)
        
        UpdatePanelDisplay()
        
        if updateTimer then
            updateTimer:Cancel()
            updateTimer = nil
        end
        updateTimer = C_Timer.NewTimer(0.5, function()
            updateTimer = nil
            if MPDisplay:IsShown() then
                UpdatePanelDisplay()
            end
        end)
    end

    if not ChallengesFrame._abyHooked then
        ChallengesFrame._abyHooked = true
        
        ChallengesFrame:HookScript("OnShow", function()
            updateGuildBest()
            ShowAndUpdatePanel()
        end)
        
        ChallengesFrame:HookScript("OnHide", function()
            local best = AbyChallengesFrameGuildBest
            if best then best:Hide() end
            MPDisplay:Hide()
        end)
    end

    CoreOnEvent("CHALLENGE_MODE_LEADERS_UPDATE", updateGuildBest)
    
    MPDisplay:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    MPDisplay:SetScript("OnEvent", function(self, event)
        if event == "CHALLENGE_MODE_COMPLETED" then
            C_Timer.After(1, function()
                if MPDisplay:IsShown() then
                    UpdatePanelDisplay()
                end
            end)
        end
    end)

    if ChallengesFrame:IsVisible() then
        updateGuildBest()
        ShowAndUpdatePanel()
    end

    --======================================================
    -- 评分信息提示
    --======================================================
    local scoreInfo = ChallengesFrame.WeeklyInfo.Child.DungeonScoreInfo
    if scoreInfo then
        SetOrHookScript(scoreInfo, "OnEnter", function()
            if GameTooltip:IsVisible() then
                local best = C_MythicPlus.GetSeasonBestMythicRatingFromThisExpansion()
                local curr = C_ChallengeMode.GetOverallDungeonScore()
                if best and curr and best > curr then
                    local color = C_ChallengeMode.GetDungeonScoreRarityColor(best)
                    if color then
                        best = color:WrapTextInColorCode(best)
                    end
                    GameTooltip_AddNormalLine(GameTooltip, "版本最高评分：" .. best)
                    GameTooltip:Show()
                end
            end
        end)
    end

    --======================================================
    -- 低保提示信息
    --======================================================
    local drops  = { nil,  292, 295, 298, 302, 305, 305, 308, 308, 311, 311,}
    local levels = { nil,  305, 305, 308, 308, 311, 315, 315, 315, 318, 318,}
    local function getline(i, curr)
        if not levels[i] then return "" end
        local line = "% 2d层 |T130758:10:10:0:0:32:32:10:22:10:22|t %s |T130758:10:10:0:0:32:32:10:22:10:22|t %s"
        local drop = drops[i] and format("%d", drops[i]) or " ? "
        local level = levels[i] and format("%d", levels[i]) or " ? "
        if i == curr then line = "|cff00ff00"..line.."|r" end
        return format(line, i, drop, level)
    end
    local chest = ChallengesFrame.WeeklyInfo.Child.WeeklyChest
    if chest then
        chest:HookScript("OnEnter", function(self)
            if GameTooltip:IsVisible() then
                GameTooltip:AddLine(" ")
                local header = "|CFFFFD100层数     掉落    低保|r"
                GameTooltip:AddDoubleLine(header, header, 1, 1, 1, 1, 1, 1)
                local start = 2
                for i = start, start + 4 do
                    if levels[i] then
                        GameTooltip:AddDoubleLine(getline(i, self.level), getline(i+5, self.level), 1, 1, 1, 1, 1, 1)
                    else
                        break
                    end
                end
                GameTooltip:Show()
            end
        end)
    end
end)

--[[------------------------------------------------------------
点击打开宝库奖励，暴雪已自带
---------------------------------------------------------------]]
local ShowWeeklyRewards = function()
    if not IsAddOnLoaded("Blizzard_WeeklyRewards") then
        LoadAddOn("Blizzard_WeeklyRewards");
    end
    CoreUIToggleFrame(WeeklyRewardsFrame)
end

--[[------------------------------------------------------------
始终显示本周史诗地下城记录 (宝库提示)
---------------------------------------------------------------]]
CoreDependCall("Blizzard_WeeklyRewards", function()
    local function showAllMythicHistory()
        local runHistory = C_MythicPlus.GetRunHistory(false, true);
        if #runHistory > 0 then
            local ccount = 0
            for _, v in ipairs(runHistory) do
                ccount = ccount + (v.completed and 1 or 0)
            end
            GameTooltip_AddHighlightLine(GameTooltip, string.format("本周共完成|CFFFFD100%d|r次, 其中限时|cff00ff00%d|r次", #runHistory, ccount), true);
            
            local half = #runHistory > 16 and math.ceil(#runHistory / 2) or #runHistory
            for i = 1, half do
                local runInfo = runHistory[i];
                local name = C_ChallengeMode.GetMapUIInfo(runInfo.mapChallengeModeID);
                if name then
                    name = name:gsub("^.-：", "")
                else
                    name = "未知"
                end
                
                local runInfo2 = runHistory[i + half];
                local name2, text2, color2
                if runInfo2 then
                    name2 = C_ChallengeMode.GetMapUIInfo(runInfo2.mapChallengeModeID)
                    if name2 then
                        name2 = name2:gsub("^.-：", "")
                    else
                        name2 = "未知"
                    end
                    text2 = name2 .. " - " .. runInfo2.level
                    color2 = runInfo2.completed and GREEN_FONT_COLOR or RED_FONT_COLOR
                else
                    text2 = ""
                    color2 = GREEN_FONT_COLOR
                end
                
                GameTooltip_AddColoredDoubleLine(GameTooltip, 
                    runInfo.level .. " - " .. name, 
                    text2, 
                    runInfo.completed and GREEN_FONT_COLOR or RED_FONT_COLOR, 
                    color2, 
                    false)
            end
            GameTooltip_AddBlankLineToTooltip(GameTooltip);
        end
    end

    SetOrHookScript(WeeklyRewardsFrame, "OnShow", function()
        C_Timer.After(1, function()
            if WeeklyRewardsFrame.Overlay then WeeklyRewardsFrame.Overlay:Hide() end
            if WeeklyRewardsFrame.Blackout then WeeklyRewardsFrame.Blackout:Hide() end
        end)
    end)
    
    for i=1, 1 do
        local act = WeeklyRewardsFrame:GetActivityFrame(Enum.WeeklyRewardChestThresholdType.Activities, i)
        if act then
            act.OriginHandlePreviewMythicRewardTooltip = act.HandlePreviewMythicRewardTooltip
            act.HandlePreviewMythicRewardTooltip = function(self, itemLevel, upgradeItemLevel, nextLevel)
                self:OriginHandlePreviewMythicRewardTooltip(itemLevel, upgradeItemLevel, nextLevel)
                showAllMythicHistory()
            end

            act:HookScript("OnEnter", function(self)
                if not self.unlocked and not C_WeeklyRewards.CanClaimRewards() then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -7, -11);
                    GameTooltip_SetTitle(GameTooltip, "尚未解锁");
                    self.UpdateTooltip = nil;
                    GameTooltip_AddBlankLineToTooltip(GameTooltip);
                    showAllMythicHistory()
                    GameTooltip_AddNormalLine(GameTooltip, "请继续努力，祝你开心")
                    GameTooltip:Show();
                end
            end)
        end
    end
end)

--[[------------------------------------------------------------
大米分数显示 --abyuiPW
---------------------------------------------------------------]]
CoreDependCall("Blizzard_ChallengesUI", function()
    local SHORT_NAMES = {
        [588] = "|CFFFFD100毒牙|r",
        [586] = "|CFFFFD100纳洛|r",
        [249] = "|CFFFFD100诸王|r",
        [587] = "|CFFFFD100密谋|r",
        [399] = "|CFFFFD100红玉|r",
        [250] = "|CFFFFD100神庙|r",
        [584] = "|CFFFFD100夺目|r",
        [585] = "|CFFFFD100虚痕|r",
    }
    local PORTAL_SPELLS = {
        [588] = 1286812,
        [586] = 1286807,
        [249] = 1286831,
        [587] = 1286809,
        [399] = 393256,
        [250] = 1286828,
        [584] = 1286801,
        [585] = 1286804,
    }
    local LEVEL_COLORS = {
        [0] = "ffffff",
        [1] = "1eff00",
        [2] = "0070dd",
        [3] = "a335ee",
        [4] = "00ccff",
        [5] = "fffc01",
        [6] = "e6cc80",
        [7] = "ff8000",
    }

    local function updateIconLevelText(self)
        if not U1GetCfgValue or not U1GetCfgValue(addonName, 'MythicScore') then
            if self._abyName then self._abyName:SetText("") end
            if self._abyAffix then self._abyAffix:SetText("") end
            return
        end

        local mapName = C_ChallengeMode.GetMapUIInfo(self.mapID)
        mapName = SHORT_NAMES[self.mapID] or (mapName and string.sub(mapName, 1, 6) or "")
        if self._abyName then
            self._abyName:SetText(mapName)
        end

        local inTimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(self.mapID);
	    local _, overallScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(self.mapID);
        
        if self.HighestLevel then
            self.HighestLevel:SetText("")
        end
        if self._abyAffix then
            self._abyAffix:SetText("")
        end

	    if overallScore and (inTimeInfo or overtimeInfo) then
		    local color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(overallScore) or HIGHLIGHT_FONT_COLOR;
		    local overallText = color:WrapTextInColorCode(overallScore);
            if self.HighestLevel then
                self.HighestLevel:SetText(overallText);
            end

            local level = nil;
            local overTime = false;
            if (inTimeInfo and overtimeInfo) then
                local inTimeScoreIsBetter = inTimeInfo.dungeonScore > overtimeInfo.dungeonScore;
                level = inTimeScoreIsBetter and inTimeInfo.level or overtimeInfo.level;
                overTime = not inTimeScoreIsBetter;
            elseif (inTimeInfo or overtimeInfo) then
                level = inTimeInfo and inTimeInfo.level or overtimeInfo.level;
                overTime = inTimeInfo == nil;
		    end
            if level ~= nil and self._abyAffix then
                local color = overTime and "F00000" or LEVEL_COLORS[min(floor(level/1),7)]
                self._abyAffix:SetText(format("|cff%s%s|r", color, level))
            end
	    end
    end

    local function showPortalSecureButton()
        if not ChallengesFrame:IsVisible() then return end
        for i, icon in pairs(ChallengesFrame.DungeonIcons) do
            local btn = _G["AbyDungeonPortal"..i]
            if not btn then
                btn = WW:Button("AbyDungeonPortal"..i, nil, "SecureActionButtonTemplate")
                :SetAttribute("type1", "macro")
                :SetScript("PreClick", function(self, button)
                    if button == "RightButton" then
                        if ELP_CHALLENGE_MAPID_FILTER_INDEX and ELP_CHALLENGE_MAPID_FILTER_INDEX[icon.mapID] then
                            if not EncounterJournal or not EncounterJournal:IsShown() then
                                if not InCombatLockdown() then
                                    ToggleEncounterJournal();
                                else
                                    CoreUIToggleFrame(EncounterJournal)
                                end
                            end
                            ELP_MenuOnClick(self, "range", ELP_CHALLENGE_MAPID_FILTER_INDEX[icon.mapID])
                        end
                    end
                end)
                :SetScript("OnEnter", function(self)
                    local s = self.hook:GetScript("OnEnter")
                    if s then
                        s(icon)
                        local spell = icon.mapID and PORTAL_SPELLS[icon.mapID]
                        if spell then
                            GameTooltip:AddLine(" ")
                            if ELP_CHALLENGE_MAPID_FILTER_INDEX and ELP_CHALLENGE_MAPID_FILTER_INDEX[icon.mapID] then
                                GameTooltip:AddLine("右键点击查询掉落")
                                GameTooltip:Show()
                            end
                            local spellInfo = C_Spell.GetSpellInfo(spell)
                            if spellInfo then
                                local cooldown = C_Spell.GetSpellCooldown(spell)
                                if cooldown and cooldown.startTime and cooldown.duration and cooldown.duration > 1.5 then
                                    GameTooltip:AddLine("传送冷却：" .. MinutesToTime((cooldown.startTime+cooldown.duration-GetTime())/60))
                                else
                                    GameTooltip:AddLine("左键点击施法：" .. (spellInfo.name or spell))
                                end
                                GameTooltip:Show()
                            end
                        end
                    end
                end)
                :SetScript("OnLeave", function(self) local s = self.hook:GetScript("OnLeave") if s then s(icon) end end)
                :un()
                btn.hook = icon
            end
            if btn:GetParent() ~= icon then
                WW(btn):SetParent(icon):ClearAllPoints():SetAllPoints(icon):Show()
                :RegisterForClicks("AnyUp", "AnyDown")
                :SetFrameStrata(icon:GetFrameStrata()):AddFrameLevel(1, icon)
                :un()
            else
                btn:Show()
            end
            local spellID = icon.mapID and PORTAL_SPELLS[icon.mapID]
            local spellInfo = spellID and C_Spell.GetSpellInfo(spellID)
            if spellInfo and spellInfo.name then
                btn:SetAttribute("macrotext1", format("/stopcasting\n/cast %s", spellInfo.name))
            else
                btn:SetAttribute("macrotext1", nil)
            end
        end
    end

    CoreOnEvent("PLAYER_REGEN_DISABLED", function()
        for i=1, 20 do
            local btn = _G["AbyDungeonPortal"..i]
            if not btn then break end
            btn:SetParent(nil)
            btn:ClearAllPoints()
            btn:Hide()
        end
        C_Timer.After(0.1, function()
            CoreLeaveCombatCall("ChallengesGuildBest", nil, showPortalSecureButton)
        end)
    end)

    hooksecurefunc(ChallengesFrame, "Update", function(self)
        -- 12.1 优化：移除不必要的 pcall，直接安全调用
        if ChallengesFrame.WeeklyInfo and ChallengesFrame.WeeklyInfo.Child and ChallengesFrame.WeeklyInfo.Child.SeasonBest then
            ChallengesFrame.WeeklyInfo.Child.SeasonBest:SetText("")
        end

        CoreLeaveCombatCall("ChallengesGuildBest", nil, showPortalSecureButton)

        for i, icon in pairs(ChallengesFrame.DungeonIcons) do
            if not icon._abyName then
                WW(icon):CreateFontString():Key("_abyName")
                :SetFont(GameFontNormal:GetFont(), 16, "OUTLINE"):TOP(0, 14)
                :SetText(""):up():un()

                WW(icon):CreateFontString():Key("_abyAffix")
                :SetFont(GameFontNormal:GetFont(), 20, "OUTLINE"):BOTTOM(1, 5)
                :SetShadowColor(0,0,0):SetShadowOffset(1,-1)
                :SetText(""):up():un()

                hooksecurefunc(icon, "SetUp", updateIconLevelText)
                updateIconLevelText(icon)
            end
        end
    end)
end)

--第一次打开PVE界面跳到大米窗口
local first = true
hooksecurefunc("PVEFrame_ToggleFrame", function()
    if first and not InCombatLockdown() and PVEFrameTab3 and PVEFrameTab3:IsEnabled() then
        local info = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
        if info and (info.currentSeasonScore or 0) >= 1500 then
            PVEFrameTab3:Click()
        end
    end
    first = false
end)