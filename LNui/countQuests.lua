local ADDON, Quest_Counter = ...
-- CREATE THE ADDON TABLE
QuestCounter = CreateFrame("Frame", "QuestCounterFrame")

-- MAXIMUM NUMBER OF QUESTS
local MAX_QUESTS = 35

-- 节流与缓存：任务日志事件在进出副本/过图时可能密集触发，
-- 0.5 秒内只重算一次，且仅在任务数变化时 SetText。
-- 用数字缓存（questsCounted）而非字符串缓存：12.1 的 secret string
-- 污染机制禁止比较 format() 产物，字符串比较会报错
local lastQuestCountUpdate = 0
local lastQuestCountNumber = nil

-- FUNCTION TO COUNT ACTUAL QUESTS IN THE QUEST LOG
local function countQuests()
local questsCounted = 0
local numQuestLogEntries = C_QuestLog.GetNumQuestLogEntries()
for index = 1, numQuestLogEntries do
local questInfo = C_QuestLog.GetInfo(index)
if not questInfo["isHeader"] and not questInfo["isHidden"] then
questsCounted = questsCounted + 1
end
end
return questsCounted
end

-- FUNCTION TO UPDATE THE QUEST COUNT DISPLAY
function QuestCounter:UpdateQuestCount()
local now = GetTime()
if now - lastQuestCountUpdate < 0.5 then return end
lastQuestCountUpdate = now

local questsCounted = countQuests()
local displayText = string.format(LOCALE_zhCN and "已接 %d/%d 个任务" or "已接 %d/%d 個任務", questsCounted, MAX_QUESTS)

-- 数字缓存比较：任务数变化才更新文本（number 不受 secret string 限制）
if lastQuestCountNumber ~= questsCounted then
lastQuestCountNumber = questsCounted
QuestObjectiveTracker.Header.Text:SetText(displayText)
end
end

-- FUNCTION TO HANDLE UI ELEMENT SHOW EVENT
function QuestCounter:OnShow()
if QuestObjectiveTracker and QuestObjectiveTracker.Header and QuestObjectiveTracker.Header.Text then
lastQuestCountUpdate = 0  -- 显示时强制刷新，跳过节流
self:UpdateQuestCount()
else
self:UnregisterAllEvents()
end
end

-- FUNCTION TO INITIALIZE THE ADDON AND REGISTER EVENTS
function QuestCounter:OnLoad()
self:RegisterEvent('QUEST_ACCEPTED')
self:RegisterEvent('QUEST_AUTOCOMPLETE')
self:RegisterEvent('QUEST_LOG_UPDATE')
self:RegisterEvent('QUEST_REMOVED')
self:RegisterEvent('QUEST_WATCH_LIST_CHANGED')
self:RegisterUnitEvent('UNIT_QUEST_LOG_CHANGED', 'player')

-- ENSURE THE DISPLAY IS UPDATED WHEN THE UI ELEMENT IS SHOWN
if QuestObjectiveTracker and QuestObjectiveTracker.Header then
QuestObjectiveTracker.Header:HookScript("OnShow", function() self:OnShow() end)
end

-- INITIALIZE THE QUEST COUNT ON LOAD
self:UpdateQuestCount()
end

-- FUNCTION TO HANDLE EVENTS
function QuestCounter:OnEvent(event, ...)
if event == "QUEST_ACCEPTED" or event == "QUEST_AUTOCOMPLETE" or
event == "QUEST_LOG_UPDATE" or event == "QUEST_REMOVED" or
event == "QUEST_WATCH_LIST_CHANGED" or event == "UNIT_QUEST_LOG_CHANGED" then
self:UpdateQuestCount()
end
end

-- SET UP THE ADDON
QuestCounter:SetScript("OnEvent", QuestCounter.OnEvent)
QuestCounter:SetScript("OnLoad", QuestCounter.OnLoad)
QuestCounter:OnLoad()
