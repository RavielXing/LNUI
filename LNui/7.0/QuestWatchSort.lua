local QuestPOIGetIconInfo = QuestPOIGetIconInfo
local GetNumQuestWatches = C_QuestLog.GetNumQuestWatches
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local GetDistanceSqToQuest = C_QuestLog.GetDistanceSqToQuest
local QuestHasPOIInfo = QuestHasPOIInfo or C_QuestLog.QuestHasPOIInfo

local questsDis, orderedIndexes = {}, {}
local CONFIG = "!!!163ui!!!/questWatchSort"

-- 12.1: GetQuestWatchInfo 已移除，使用安全包装
local GetQuestWatchInfo_old
local function SafeGetQuestWatchInfo(index)
    if GetQuestWatchInfo_old then
        return GetQuestWatchInfo_old(index)
    end
    -- 12.1 替代方案：通过 C_QuestLog 获取
    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex and C_QuestLog.GetQuestIDForQuestWatchIndex(index)
    if not questID then return nil end
    local info = C_QuestLog.GetInfo(C_QuestLog.GetLogIndexForQuestID(questID))
    if info then
        return questID, info.title, info.questLogIndex, info.numObjectives, info.requiredMoney, info.isComplete, info.startEvent, info.isAutoComplete, info.failureTime, info.timeElapsed, info.questType, info.isTask, info.isBounty, info.isStory, info.isOnMap, info.hasLocalPOI
    end
    return nil
end

local function ComparatorDist(id1, id2)
    local d1, d2 = questsDis[id1], questsDis[id2]
    if not d1 or not d2 then return id1 < id2 end
    if d1 < 0 and d2 >= 0 then return false end
    if d2 < 0 and d1 >= 0 then return true end
    return d1 < d2
end

local protectionTime = 0
local lastQuestCount = -1
local lastSortResult = nil
local sortDirty = true

local function UpdateQuestsDistance()
    -- 12.1: 大量提前返回，减少无效计算
    if not U1DB.configs[CONFIG] then return end
    if InCombatLockdown() then return end
    local numWatches = GetNumQuestWatches()
    if numWatches < 1 then return end
    if QuestMapFrame and QuestMapFrame:IsVisible() then return end
    if ObjectiveTrackerFrame and not ObjectiveTrackerFrame:IsVisible() then return end

    -- 如果追踪数量未变且非强制刷新，跳过距离计算
    if numWatches == lastQuestCount and not sortDirty then
        return
    end
    lastQuestCount = numWatches
    sortDirty = false

    wipe(questsDis)
    wipe(orderedIndexes)

    for i = 1, numWatches do
        orderedIndexes[i] = i
        local questID, title, questLogIndex = SafeGetQuestWatchInfo(i)
        if questID and (QuestHasPOIInfo and QuestHasPOIInfo(questID)) then
            local distSqr, onContinent = GetDistanceSqToQuest(questLogIndex)
            if onContinent then
                questsDis[i] = distSqr or 999999999
            else
                questsDis[i] = i - 1000
            end
        else
            questsDis[i] = i - 1000
        end
    end

    table.sort(orderedIndexes, ComparatorDist)

    local nearestIdx = orderedIndexes[1]
    local nearest = nearestIdx and questsDis[nearestIdx]
    
    if nearest and nearest > 0 then
        local questID, questLogTitle, questLogIndex = SafeGetQuestWatchInfo(nearestIdx)
        if questID and GetTime() > protectionTime and questID ~= GetSuperTrackedQuestID() then
            if WorldQuestTrackerAddon and WorldQuestTrackerAddon.SuperTracked == GetSuperTrackedQuestID() then return end
            local currDist = GetDistanceSqToQuest(C_QuestLog.GetLogIndexForQuestID(GetSuperTrackedQuestID()))
            if currDist and nearest and currDist - nearest > nearest * 0.07 + 1000 then
                SetSuperTrackedQuestID(questID)
                PlaySound(31581)
            end
        end

        -- 12.1: 限制强制刷新频率，最多每 1 秒一次
        if ObjectiveTrackerFrame and ObjectiveTrackerFrame:IsVisible() and not InCombatLockdown() then
            if not frame.nextForcedUpdate or GetTime() > frame.nextForcedUpdate then
                frame.nextForcedUpdate = GetTime() + 1.0
                AbyQuestWatchSortUpdate = 1
                ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_QUEST)
                AbyQuestWatchSortUpdate = nil
                if QuestObjectiveTracker_UpdatePOIs then
                    QuestObjectiveTracker_UpdatePOIs()
                elseif QUEST_TRACKER_MODULE and QUEST_TRACKER_MODULE.UpdatePOIs then
                    QUEST_TRACKER_MODULE:UpdatePOIs()
                end
            end
        end
    end
end

local function GetQuestWatchInfo_new(id)
    if orderedIndexes and #orderedIndexes > 0 then
        return SafeGetQuestWatchInfo(orderedIndexes[id] or id)
    else
        return SafeGetQuestWatchInfo(id)
    end
end

local frame = CreateFrame("Frame", "QuestWatchSortEventFrame")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
frame:RegisterEvent("QUEST_AUTOCOMPLETE")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("SCENARIO_UPDATE")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("QUEST_POI_UPDATE")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("NEW_WMO_CHUNK")
frame:RegisterEvent("VARIABLES_LOADED")

local function EnableOrDisable()
    if U1DB.configs[CONFIG] then
        if not frame.hooked then
            frame.hooked = 1
            GetQuestWatchInfo_old = GetQuestWatchInfo
            GetQuestWatchInfo = GetQuestWatchInfo_new
        end
        protectionTime = 0
        frame:Show()
    else
        frame:Hide()
    end
end

frame:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        if U1DB.configs[CONFIG] == nil then U1DB.configs[CONFIG] = true end
        if QuestWatchSortCheckButton then
            QuestWatchSortCheckButton:SetChecked(U1DB.configs[CONFIG])
        end
        EnableOrDisable()
    else
        sortDirty = true
        if event == "NEW_WMO_CHUNK" and WorldMapFrame and not WorldMapFrame:IsVisible() then
            local mapId = C_Map.GetBestMapForUnit("player")
            if mapId and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.currentScale and WorldMapFrame.ScrollContainer.currentScale > 0 then
                WorldMapFrame:SetMapID(mapId)
            end
        end
        UpdateQuestsDistance()
    end
end)

-- 12.1: OnUpdate 增加更长的间隔和随机抖动，避免与其他插件同频
local timer = math.random() * 0.5
frame:SetScript("OnUpdate", function(self, elapsed)
    timer = timer + elapsed
    if timer > 0.8 then  -- 从 0.5 延长到 0.8
        timer = 0
        UpdateQuestsDistance()
    end
end)

if ObjectiveTrackerFrame and ObjectiveTrackerFrame.BlocksFrame then
    hooksecurefunc(ObjectiveTrackerFrame.BlocksFrame, "poiOnCreateFunc", function(button)
        if not button._hooked then
            button._hooked = 1
            button:HookScript("OnClick", function(self)
                local questID = self.questID
                if questID and not IsShiftKeyDown() then
                    protectionTime = GetTime() + 5
                end
            end)
        end
    end)
end