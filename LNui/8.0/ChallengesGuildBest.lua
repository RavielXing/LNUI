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
    if U1DBG.hideAbyGuildBest then return end

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
        -- 宽度改为动态计算，不再固定
        MPDisplay:SetMovable(true)
        MPDisplay:EnableMouse(true)
        MPDisplay:RegisterForDrag("LeftButton")
        MPDisplay:SetScript("OnDragStart", MPDisplay.StartMoving)
        MPDisplay:SetScript("OnDragStop", MPDisplay.StopMovingOrSizing)
    end

    local function GetDungeonName(mapID)
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        return name or ("地图"..mapID)
    end

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
                    runs = {}
                }
            end
            
            table.insert(dungeonData[id].runs, {
                level = run.level,
                completed = run.completed
            })
            
            if run.completed then
                completed = completed + 1
                if run.level > bestLevel then
                    bestLevel = run.level
                end
            end
        end

        local text = string.format("|cffff8f00本周:|r |cffffffff%d|r次 (|cff00ff00%d|r限)\n", total, completed)
        text = text .. string.format("|cffffaa00最高:|r |cffffffff%d|r\n\n", bestLevel)

        for id, data in pairs(dungeonData) do
            text = text .. data.name .. "\n"
            table.sort(data.runs, function(a, b)
                if a.completed == b.completed then
                    return a.level > b.level
                end
                return a.completed
            end)
            
            local count = 0  -- 计数器：当前行已显示的层数
            for i, run in ipairs(data.runs) do
                if count > 0 and count % 7 == 0 then
                    text = text .. "\n  "  -- 换行并添加缩进
                elseif count > 0 then
                    text = text .. ", "  -- 同一行内用空格分隔
                else
                    text = text .. "  "  -- 第一个层数的缩进
                end
                
                if run.completed then
                    -- 限时完成：绿色
                    text = text .. string.format("|cff00ff00%d|r", run.level)
                else
                    -- 超时：红色层数
                    text = text .. string.format("|cffF00000%d|r", run.level)
                end
                
                count = count + 1
            end
            text = text .. "\n"
        end
        
        return text, total
    end

    local function UpdatePanelDisplay()
        -- 先放开宽度限制，测量文本自然宽度
        MPDisplay.text:SetWidth(0)
        
        local displayText = GetMythicPlusDataForPanel()
        MPDisplay.text:SetText(displayText)
        
        local textWidth = MPDisplay.text:GetStringWidth()
        -- 目标宽度 = 文本宽度 + 左右边距(8+8=16)
        -- 最小150防止太窄，最大450防止超长（可按喜好改）
        local targetWidth = math.min(math.max(textWidth + 16, 150), 450)
        
        MPDisplay:SetWidth(targetWidth)
        -- 再把文本宽度设回面板可用宽度，保证后续换行正确
        MPDisplay.text:SetWidth(targetWidth - 16)
        
        local height = MPDisplay.text:GetStringHeight() + 16
        MPDisplay:SetHeight(math.max(height, 60))
    end

    --======================================================
    -- 公会最佳成绩功能
    --======================================================
    local function updateGuildBest()
        local best = AbyChallengesFrameGuildBest
        if not best then return end
        
        -- 只在父级变化时才设置
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
        
        -- 这个设置只需要一次
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
        
        -- 立即刷新一次
        UpdatePanelDisplay()
        
        -- 取消之前的定时器，避免堆积
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

    -- 确保只 Hook 一次
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

    -- 统一事件监听
    CoreOnEvent("CHALLENGE_MODE_LEADERS_UPDATE", updateGuildBest)
    
    -- 大秘境完成时刷新面板
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

    -- 初始检查（如果框架已经显示）
    if ChallengesFrame:IsVisible() then
        updateGuildBest()
        ShowAndUpdatePanel()
    end

    --======================================================
    -- 评分信息提示
    --======================================================
    local scoreInfo = ChallengesFrame.WeeklyInfo.Child.DungeonScoreInfo
    SetOrHookScript(scoreInfo, "OnEnter", function()
        if GameTooltip:IsVisible() then
            local best = C_MythicPlus.GetSeasonBestMythicRatingFromThisExpansion()
            local curr = C_ChallengeMode.GetOverallDungeonScore()
            if best > curr then
                local color = C_ChallengeMode.GetDungeonScoreRarityColor(best);
                if color then
                    best = color:WrapTextInColorCode(best)
                end
                GameTooltip_AddNormalLine(GameTooltip, "版本最高评分：" .. best);
                GameTooltip:Show();
            end
        end
    end)

    --======================================================
    -- 低保提示信息
    --======================================================
    local drops  = { nil,  250, 250, 253, 256, 259, 259, 263, 263, 266, 266,}
    local levels = { nil,  259, 259, 263, 263, 266, 269, 269, 269, 272, 272,}
    local function getline(i, curr)
        if not levels[i] then return "" end
        local line = "% 2d层 |T130758:10:10:0:0:32:32:10:22:10:22|t %s |T130758:10:10:0:0:32:32:10:22:10:22|t %s"
        local drop = drops[i] and format("%d", drops[i]) or " ? "
        local level = levels[i] and format("%d", levels[i]) or " ? "
        if i == curr then line = "|cff00ff00"..line.."|r" end
        return format(line, i, drop, level)
    end
    local chest = ChallengesFrame.WeeklyInfo.Child.WeeklyChest
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
end)

--[[------------------------------------------------------------
PVP每周奖励
---------------------------------------------------------------]]
CoreDependCall("Blizzard_PVPUI", function()
    do return end
    local ratings  = { "0000+", "1000+", "1200+", "1400+", "1600+", "1800+", "1950+", "2100+", "2400+"}
    local upgrade  = {  275,    278,     281,     285,     288,     291,     294,     298,     301, }
    local upgradep = {  288,    291,     294,     298,     301,     304,     307,     311,     311, }
    local title    = { "休闲者","争斗者I","争斗者II","挑战者I","挑战者II","竞争者I","竞争者II","决斗者","精锐" }

    for _, chest in ipairs({ PVPQueueFrame.HonorInset.RatedPanel.WeeklyChest, PVPQueueFrame.HonorInset.CasualPanel.WeeklyChest}) do
        chest:HookScript("OnEnter", function(self)
            if GameTooltip:IsVisible() then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("（以下为第3赛季信息, 如有错误以游戏内为准）", nil, nil, nil, true)
                GameTooltip:AddLine("PVP等级  装等  PVP时装等  头衔", 1, 1, 1)
                for i, v in ipairs(ratings) do
                    local line = " %s |T130758:10:15:0:0:32:32:10:22:10:22|t %s |T130758:10:20:0:0:32:32:10:22:10:22|t %s |T130758:10:30:0:0:32:32:10:22:10:22|t %s"
                    GameTooltip:AddLine(format(line, ratings[i], tostring(upgrade[i]), tostring(upgradep[i]), title[i]), 1, 1, 1)
                end
                GameTooltip:Show()
            end
        end)
    end
end)

--[[------------------------------------------------------------
托加斯特
---------------------------------------------------------------]]
EventRegistry:RegisterCallback("AreaPOIPin.MouseOver", function(self, obj, tooltipShown, areaPoiID, name)
    if areaPoiID == 6640 then
        local levels    = {  "08", "09",   10,    11,    12,     13,     14,     15,     16}
        local firstNew  = {   170,  230,  270,   310,   350,    380,    410,    440,    470}
        local firstOld  = {   860,  915,  960,  1000,  1030,   1060,   1090,   1120,   1150}
        if GameTooltip:IsVisible() then
            GameTooltip:AddLine("难度   薪尘    灰烬", 1, 1, 1)
            local line = " %2s |T130758:10:10:0:0:32:32:10:22:10:22|t %5s |T130758:10:10:0:0:32:32:10:22:10:22|t %4s"
            for i, v in ipairs(levels) do
                GameTooltip:AddLine(format(line, tostring(levels[i]), tostring(firstNew[i]), tostring(firstOld[i])), 1, 1, 1)
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("橙装装等  190/ 210/ 225/ 235")
            GameTooltip:AddLine("需要灰烬 1250/2000/3200/5150")
            GameTooltip:AddLine("249橙装需要 灰烬5150 薪尘1100")
            GameTooltip:AddLine("262橙装需要 灰烬5150 薪尘1650")
            GameTooltip:AddLine("291橙装需要 262材料及2000宇宙助溶剂")
            GameTooltip:Show()
        end
    end
end, {})

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
            local ccount = 0; for _, v in ipairs(runHistory) do ccount = ccount + (v.completed and 1 or 0) end
            GameTooltip_AddHighlightLine(GameTooltip, string.format("本周共完成|CFFFFD100%d|r次, 其中限时|cff00ff00%d|r次", #runHistory, ccount), true);
            local half = #runHistory > 16 and math.ceil(#runHistory / 2) or #runHistory
            for i = 1, half do
                local runInfo = runHistory[i];
                local name = C_ChallengeMode.GetMapUIInfo(runInfo.mapChallengeModeID);
                name = name:gsub("^.-：", "")
                local runInfo2 = runHistory[i + half];
                local name2 = runInfo2 and C_ChallengeMode.GetMapUIInfo(runInfo2.mapChallengeModeID)
                local text2, color2 = "", GREEN_FONT_COLOR
                if runInfo2 then
                    text2 = name2:gsub("^.-：", "") .. " - " .. runInfo2.level
                    color2 = runInfo2.completed and GREEN_FONT_COLOR or RED_FONT_COLOR
                end
                GameTooltip_AddColoredDoubleLine(GameTooltip, runInfo.level .. " - " .. name, text2, runInfo.completed and GREEN_FONT_COLOR or RED_FONT_COLOR, color2, false)
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
        act.OriginHandlePreviewMythicRewardTooltip = act.HandlePreviewMythicRewardTooltip
        act.HandlePreviewMythicRewardTooltip = function(self, itemLevel, upgradeItemLevel, nextLevel)
            self:OriginHandlePreviewMythicRewardTooltip(itemLevel, upgradeItemLevel, nextLevel)
            if true then
                showAllMythicHistory()
            end
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
end)

--[[------------------------------------------------------------
大米分数显示 --abyuiPW
---------------------------------------------------------------]]
CoreDependCall("Blizzard_ChallengesUI", function()
    local SHORT_NAMES = {
        [239] = "|CFFFFD100执政|r",
        [556] = "|CFFFFD100萨隆|r",
        [161] = "|CFFFFD100通天|r",
        [402] = "|CFFFFD100学院|r",
        [557] = "|CFFFFD100风行|r",
        [558] = "|CFFFFD100魔导|r",
        [560] = "|CFFFFD100迈萨|r",
        [559] = "|CFFFFD100节点|r",
    }
    local PORTAL_SPELLS = {
        [239] = 1254551,
        [556] = 1254555,
        [161] = 159898,
        [402] = 393273,
        [557] = 1254400,
        [558] = 1254572,
        [560] = 1254559,
        [559] = 1254563,
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

    local function GetWeekAffixName()
        local curr = C_MythicPlus.GetCurrentAffixes()
        return curr and curr[1] and curr[1].id and C_ChallengeMode.GetAffixInfo(curr[1].id) or nil
    end

    local function updateIconLevelText(self)
        if not U1GetCfgValue(addonName, 'MythicScore') then
            self._abyName:SetText("")
            self._abyAffix:SetText("")
            return
        end

        local mapName = C_ChallengeMode.GetMapUIInfo(self.mapID)
        mapName = SHORT_NAMES[self.mapID] or string.sub(mapName, 1, 6)
        self._abyName:SetText(mapName)

        local inTimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(self.mapID);
	    local _, overallScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(self.mapID);
        self.HighestLevel:SetText("")
        self._abyAffix:SetText("")

	    if overallScore and (inTimeInfo or overtimeInfo) then
		    local color = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(overallScore) or HIGHLIGHT_FONT_COLOR;
		    local overallText = color:WrapTextInColorCode(overallScore);
            self.HighestLevel:SetText(overallText);

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
            if level ~= nil then
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
                            if IsSpellKnown(spell) then
                                local start,duration = GetSpellCooldown(spell)
                               if start and duration and duration > 1.5 then
                                    GameTooltip:AddLine("传送冷却：" .. MinutesToTime((start+duration-GetTime())/60))
                                else
                                    GameTooltip:AddLine("左键点击施法：" .. (GetSpellInfo(spell) or spell))
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
            -- 只在父级变化时才重新设置
            if btn:GetParent() ~= icon then
                WW(btn):SetParent(icon):ClearAllPoints():SetAllPoints(icon):Show()
                :RegisterForClicks("AnyUp", "AnyDown")
                :SetFrameStrata(icon:GetFrameStrata()):AddFrameLevel(1, icon)
                :un()
            else
                btn:Show()
            end
            if icon and icon.mapID and GetSpellInfo(PORTAL_SPELLS[icon.mapID]) then
                btn:SetAttribute("macrotext1", format("/stopcasting\n/cast %s", (GetSpellInfo(PORTAL_SPELLS[icon.mapID]))))
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
        pcall(function() ChallengesFrame.WeeklyInfo.Child.SeasonBest:SetText("") end)

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