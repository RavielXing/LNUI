
local customTooltip = CreateFrame("GameTooltip", "MapTooltipTaintFix_GameTooltip", UIParent, "GameTooltipTemplate");
do
    customTooltip.supportsItemComparison = true;
    customTooltip.ItemTooltip = CreateFrame("Frame", nil, customTooltip, "InternalEmbeddedItemTooltipTemplate");
    customTooltip.ItemTooltip:SetSize(100, 100);
    customTooltip.ItemTooltip:SetPoint("BOTTOMLEFT", 10, 13);
    customTooltip.ItemTooltip.yspacing = 13;

    local shoppingTooltip1 = CreateFrame("GameTooltip", "MapTooltipTaintFix_ShoppingTooltip1", UIParent, "ShoppingTooltipTemplate")
    shoppingTooltip1:SetClampedToScreen(true)
    shoppingTooltip1:SetFrameStrata("TOOLTIP")
    shoppingTooltip1:Hide()

    local shoppingTooltip2 = CreateFrame("GameTooltip", "MapTooltipTaintFix_ShoppingTooltip2", UIParent, "ShoppingTooltipTemplate")
    shoppingTooltip2:SetClampedToScreen(true)
    shoppingTooltip2:SetFrameStrata("TOOLTIP")
    shoppingTooltip2:Hide()

    customTooltip.ItemTooltip.Tooltip.shoppingTooltips = { shoppingTooltip1, shoppingTooltip2 };
    customTooltip.ItemTooltip.shoppingTooltips = { shoppingTooltip1, shoppingTooltip2 };
    customTooltip.shoppingTooltips = { shoppingTooltip1, shoppingTooltip2 };

    customTooltip:SetScript("OnShow", GameTooltip_OnShow);
    customTooltip:SetScript("OnUpdate", GameTooltip_OnUpdate);
    customTooltip:SetOwner(UIParent, "ANCHOR_CURSOR");
    customTooltip:SetText("Placeholder");
    customTooltip:Show();
    customTooltip:Hide();
end

local function AddFloorLocationLine(tooltip, floorLocation, aboveString, belowString)
    if floorLocation == Enum.QuestLineFloorLocation.Below then
        tooltip:AddLine(belowString, 0.5, 0.5, 0.5, true);
    elseif floorLocation == Enum.QuestLineFloorLocation.Above then
        tooltip:AddLine(aboveString, 0.5, 0.5, 0.5, true);
    end
end
-- copied verbatim to avoid overriding the fenv of the original global function
local function adjustedGameTooltipAddQuest(self)
    local questID = self.questID;
    if ( not HaveQuestData(questID) ) then
        GameTooltip_SetTitle(GameTooltip, RETRIEVING_DATA, RED_FONT_COLOR);
        GameTooltip_SetTooltipWaitingForData(GameTooltip, true);
        GameTooltip:Show();
        return;
    end

    local widgetSetAdded = false;
    local widgetSetID = C_TaskQuest.GetQuestUIWidgetSetByType(questID, Enum.MapIconUIWidgetSetType.Tooltip);
    local isThreat = C_QuestLog.IsThreatQuest(questID);

    local title, factionID, capped = C_TaskQuest.GetQuestInfoByQuestID(questID);
    title = title or self.questName;
    if self.worldQuest or C_QuestLog.IsWorldQuest(questID) then
        self.worldQuest = true;
        local tagInfo = C_QuestLog.GetQuestTagInfo(self.questID);
        local quality = tagInfo and tagInfo.quality or Enum.WorldQuestQuality.Common;

        local colorData = ColorManager.GetColorDataForWorldQuestQuality(quality)
        if colorData then
            GameTooltip_SetTitle(GameTooltip, title, colorData.color);
        else
            GameTooltip_SetTitle(GameTooltip, title);
        end

        if C_QuestLog.IsAccountQuest(questID) then
            GameTooltip_AddColoredLine(GameTooltip, ACCOUNT_QUEST_LABEL, ACCOUNT_WIDE_FONT_COLOR);
        end

        QuestUtils_AddQuestTypeToTooltip(GameTooltip, questID, NORMAL_FONT_COLOR);

        local factionData = factionID and C_Reputation.GetFactionDataByID(factionID);
        if factionData then
            local questAwardsReputationWithFaction = C_QuestLog.DoesQuestAwardReputationWithFaction(questID, factionID);
            local reputationYieldsRewards = (not capped) or C_Reputation.IsFactionParagonForCurrentPlayer(factionID);
            if questAwardsReputationWithFaction and reputationYieldsRewards then
                GameTooltip:AddLine(factionData.name);
            else
                GameTooltip:AddLine(factionData.name, GRAY_FONT_COLOR:GetRGB());
            end
        end

        GameTooltip_AddQuestTimeToTooltip(GameTooltip, questID);
    elseif isThreat then
        GameTooltip_SetTitle(GameTooltip, title);
        GameTooltip_AddQuestTimeToTooltip(GameTooltip, questID);
    else
        GameTooltip_SetTitle(GameTooltip, title, NORMAL_FONT_COLOR);
    end

    if self.isCombatAllyQuest or (C_QuestLog.GetQuestType(questID) == Enum.QuestTag.CombatAlly) then
        GameTooltip_AddColoredLine(GameTooltip, AVAILABLE_FOLLOWER_QUEST, HIGHLIGHT_FONT_COLOR, true);
        GameTooltip_AddColoredLine(GameTooltip, GRANTS_FOLLOWER_XP, GREEN_FONT_COLOR, true);
    elseif self.isQuestStart then
        GameTooltip_AddColoredLine(GameTooltip, AVAILABLE_QUEST, HIGHLIGHT_FONT_COLOR, true);
        AddFloorLocationLine(GameTooltip, self.floorLocation, QUESTLINE_LOCATED_ABOVE, QUESTLINE_LOCATED_BELOW);
    else
        local questDescription = "";
        local questCompleted = C_QuestLog.IsComplete(questID);

        if questCompleted and self.shouldShowObjectivesAsStatusBar then
            questDescription = QUEST_WATCH_QUEST_READY;
            GameTooltip_AddColoredLine(GameTooltip, QUEST_DASH .. questDescription, HIGHLIGHT_FONT_COLOR);
        elseif not questCompleted and self.shouldShowObjectivesAsStatusBar then
            local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID);
            if questLogIndex then
                questDescription = select(2, GetQuestLogQuestText(questLogIndex));
                GameTooltip_AddColoredLine(GameTooltip, QUEST_DASH .. questDescription, HIGHLIGHT_FONT_COLOR);
            end
        end
        local numObjectives = self.numbObjectives or C_QuestLog.GetNumQuestObjectives(questID);
        for objectiveIndex = 1, numObjectives do
            local objectiveText, objectiveType, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(questID, objectiveIndex, false);
            local showObjective = not (finished and isThreat);
            if showObjective then
                if self.shouldShowObjectivesAsStatusBar then
                    local percent = math.floor((numFulfilled/numRequired) * 100);
                    GameTooltip_ShowProgressBar(GameTooltip, 0, numRequired, numFulfilled, PERCENTAGE_STRING:format(percent));
                elseif objectiveText and (#objectiveText > 0) then
                    local color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
                    GameTooltip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
                end
            end
        end
        local objectiveText, objectiveType, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(questID, 1, false);
        if objectiveType == "progressbar" then
            local percent = C_TaskQuest.GetQuestProgressBarInfo(questID);
            local showObjective = not (finished and isThreat);
            if percent  and showObjective then
                GameTooltip_ShowProgressBar(GameTooltip, 0, 100, percent, PERCENTAGE_STRING:format(percent));
            end
        end

        if widgetSetID then
            widgetSetAdded = true;
            GameTooltip_AddWidgetSet(GameTooltip, widgetSetID);
        end

        GameTooltip_AddQuestRewardsToTooltip(GameTooltip, questID, self.questRewardTooltipStyle or TOOLTIP_QUEST_REWARDS_STYLE_DEFAULT);

        if self.worldQuest and C_TooltipInfo.GM then
            local tooltipData = C_TooltipInfo.GM.GetDebugWorldQuestInfo(questID);
            if tooltipData then
                local tooltipInfo = { tooltipData = tooltipData, append = true };
                GameTooltip:ProcessInfo(tooltipInfo);
                GameTooltip:Show();
            end
        end
    end


    if not widgetSetAdded and widgetSetID then
        GameTooltip_AddWidgetSet(GameTooltip, widgetSetID);
    end

    GameTooltip:Show();
end

local hooked = {};
--- @param pin BaseMapPoiPinTemplate
hooksecurefunc(WorldMapFrame, 'RegisterPin', function(_, pin)
    RunNextFrame(function()
        if hooked[pin] then return end
        hooked[pin] = true
        pin:HookScript("OnLeave", function() customTooltip:Hide(); end);
    end);
end);

local tooltipEnv = setmetatable(
    {
        GameTooltip = customTooltip,
        GameTooltip_Hide = function() customTooltip:Hide() end,
        GetAppropriateTooltip = function() return customTooltip end,
        GameTooltip_AddQuest = adjustedGameTooltipAddQuest,
    },
    { __index = _G }
);
setfenv(adjustedGameTooltipAddQuest, tooltipEnv);
setfenv(AreaPoiUtil.TryShowTooltip, tooltipEnv);
setfenv(CallingPOI_OnEnter, tooltipEnv);
setfenv(TaskPOI_OnEnter, tooltipEnv);
setfenv(VignettePinMixin.OnMouseEnter, tooltipEnv);

-- add compatibility for addons that directly insert e.g. AreaPOI data into the GameTooltip
hooksecurefunc(GameTooltip, "AddLine", function(tt, ...)
    if customTooltip:GetOwner() and not GameTooltip:GetOwner() then
        customTooltip:AddLine(...);
    end
end);
hooksecurefunc(GameTooltip, "AddDoubleLine", function(tt, ...)
    if customTooltip:GetOwner() and not GameTooltip:GetOwner() then
        customTooltip:AddDoubleLine(...);
    end
end);
hooksecurefunc(GameTooltip, "Show", function()
    if customTooltip:GetOwner() and not GameTooltip:GetOwner() then
        customTooltip:Show();
    end
end);
hooksecurefunc(GameTooltip, "Hide", function()
    if customTooltip:GetOwner() then
        customTooltip:Hide();
    end
end);
