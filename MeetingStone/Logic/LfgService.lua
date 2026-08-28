-- LfgService.lua
-- @Author : DengSir (tdaddon@163.com)
-- @Link   : https://dengsir.github.io/
-- @Date   : 2018-1-17 10:29:00

BuildEnv(...)

LfgService = Addon:NewModule('LfgService', 'AceEvent-3.0', 'AceBucket-3.0', 'AceTimer-3.0', 'AceHook-3.0')

-- 内存优化：限制最大搜索结果数量，防止12.1中活动过多导致内存暴涨
local MAX_SEARCH_RESULTS = 150
-- 内存优化：事件更新节流间隔（秒）
local UPDATE_THROTTLE_INTERVAL = 0.3

function LfgService:OnInitialize()
    self.activityHash = {}
    self.activityList = {}
    self.activityRemoved = {}

    -- 内存优化：更新节流定时器
    self._updateThrottleTimer = nil
    self._pendingUpdates = {}

    self:RegisterEvent('LFG_LIST_SEARCH_RESULTS_RECEIVED')
    self:RegisterEvent('LFG_LIST_SEARCH_FAILED', 'LFG_LIST_SEARCH_RESULTS_RECEIVED')
    self:RegisterEvent('LFG_LIST_APPLICATION_STATUS_UPDATED', 'LFG_LIST_SEARCH_RESULT_UPDATED')
    self:RegisterEvent('LFG_LIST_SEARCH_RESULT_UPDATED')

    -- self:RegisterBucketEvent('LFG_LIST_SEARCH_RESULT_UPDATED', 0.1, 'LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET')

    self:SecureHook(C_LFGList, 'Search', 'C_LFGList_Search')
end

function LfgService:C_LFGList_Search()
    self.inSearch = true
    self.dirty = true
    -- 内存优化：搜索前清理旧活动缓存
    self:CleanupOldActivities()
end

-- 内存优化：清理旧活动对象，释放引用
function LfgService:CleanupOldActivities()
    for _, activity in ipairs(self.activityList) do
        if activity and activity.Release then
            activity:Release()
        end
    end
    wipe(self.activityList)
    wipe(self.activityHash)
    wipe(self.activityRemoved)
    wipe(self._pendingUpdates)
    if self._updateThrottleTimer then
        self._updateThrottleTimer:Cancel()
        self._updateThrottleTimer = nil
    end
end

function LfgService:GetActivity(id)
    return self.activityHash[id]
end

function LfgService:GetActivityCount()
    return #self.activityList
end

function LfgService:GetActivityList()
    return self.activityList
end

function LfgService:RemoveActivity(id)
    self.activityRemoved[id] = true

    local activity = self:GetActivity(id)
    if not activity then
        return
    end
    tDeleteItem(self.activityList, activity)
    self.activityHash[id] = nil
    -- 内存优化：释放被移除的活动对象
    if activity and activity.Release then
        activity:Release()
    end
end

function LfgService:IsActivityRemoved(id)
    return self.activityRemoved[id]
end

function LfgService:UpdateActivity(id)
    if self:IsActivityRemoved(id) then
        return
    end

    local activity = self:GetActivity(id)
    if not activity then
        self:CacheActivity(id)
        self:SendMessage('MEETINGSTONE_ACTIVITIES_COUNT_UPDATED', #self.activityList)
    else
		--activity:Update() 
        --if activity:GetNumMembers() == 5 then
		if not activity:Update() then
            self:RemoveActivity(id)
        end
    end
end

function LfgService:IterateActivities()
    return pairs(self.activityList)
end

function LfgService:CacheActivity(id)
    if not self:_CacheActivity(id) then
        self:RemoveActivity(id)
    end
end

function LfgService:_CacheActivity(id)
    -- 内存优化：超过上限时停止缓存新活动
    if #self.activityList >= MAX_SEARCH_RESULTS then
        return false
    end

    local activity = Activity:New(id)
    if not activity:Update() then
        return
    end
    if self.activityId and activity:GetActivityID() ~= self.activityId then
        return
    end

    if activity:HasInvalidContent() then
        return
    end
    if not activity:IsValidCustomActivity() then
        return
    end

    tinsert(self.activityList, activity)
    self.activityHash[id] = activity

    return true
end

function LfgService:LFG_LIST_SEARCH_RESULTS_RECEIVED(event)
    table.wipe(self.activityList)
    table.wipe(self.activityHash)
    table.wipe(self.activityRemoved)

    self.inSearch = false
    local applications = C_LFGList.GetApplications()

    self.activityApps = self.activityApps or {} --abyui 9.1.5 applications also in SearchResults
    table.wipe(self.activityApps)

    for _, id in ipairs(applications) do
        self.activityApps[id] = true
        self:CacheActivity(id)
    end

    local _, resultList = C_LFGList.GetSearchResults()
    for _, id in ipairs(resultList) do
        if not self.activityApps[id] then
            self:CacheActivity(id)
            -- 内存优化：达到上限后提前退出
            if #self.activityList >= MAX_SEARCH_RESULTS then
                break
            end
        end
    end

    self:SendMessage('MEETINGSTONE_ACTIVITIES_COUNT_UPDATED', self:GetActivityCount())
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_RECEIVED', event == 'LFG_LIST_SEARCH_FAILED')
end

function LfgService:LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET(results)
    for id in pairs(results) do
        self:UpdateActivity(id)
    end
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_UPDATED')
end

function LfgService:LFG_LIST_SEARCH_RESULT_UPDATED(_, id)
    if self.inSearch then
        return
    end

    -- 内存优化：12.1中该事件触发极快，使用节流
    self._pendingUpdates[id] = true

    if self._updateThrottleTimer then
        return
    end

    self._updateThrottleTimer = C_Timer.NewTimer(UPDATE_THROTTLE_INTERVAL, function()
        self._updateThrottleTimer = nil
        for updateId in pairs(self._pendingUpdates) do
            self:UpdateActivity(updateId)
        end
        wipe(self._pendingUpdates)
        self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_UPDATED')
    end)
end

function LfgService:Search(categoryId, baseFilter, activityId)
    self.ourSearch = true
    self.activityId = activityId
    local filterVal = 0
    if categoryId == 2 then
        filterVal = 1
    end

    -- if activityId then
    --     local activityInfo = C_LFGList.GetActivityInfoTable(activityId);
    --     print(activityInfo.fullName)
    --     print(activityInfo.shortName)
    --     print(activityInfo.groupFinderActivityGroupID)
    -- end

    local languages = C_LFGList.GetLanguageSearchFilter();
    C_LFGList.Search(categoryId, filterVal, baseFilter, languages)
    self.ourSearch = false
    self.dirty = false
end

function LfgService:IsDirty()
    return self.dirty
end

function LfgService:GetSearchResultMemberInfo(...)
    local info = C_LFGList.GetSearchResultPlayerInfo(...)
	if (info) then
		return info.assignedRole, info.classFilename, info.className, info.specName, info.isLeader;
	end
end