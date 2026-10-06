-- 自动关闭战利品投掷窗口，作者：听到风潮 @ NGA,https://nga.178.com/read.php?tid=46549484

U1PLUG["AutoHideLootHistory"] = function()

local frame = CreateFrame("Frame")
local delay = 20      -- 默认时间（秒）
local timer = 0
local running = false
local paused = false

-- 鼠标进入暂停
local function OnEnter()
    paused = true
end

-- 鼠标离开继续
local function OnLeave()
    paused = false
end

-- 绑定鼠标事件（只执行一次）
local function HookMouse()
    if GroupLootHistoryFrame and not GroupLootHistoryFrame._autoHideHooked then
        GroupLootHistoryFrame:HookScript("OnEnter", OnEnter)
        GroupLootHistoryFrame:HookScript("OnLeave", OnLeave)
        GroupLootHistoryFrame._autoHideHooked = true
    end
end

-- 计时（仅窗口显示期间挂载 OnUpdate，平时不再占用每帧开销）
local function OnUpdate(self, elapsed)
    if not paused then
        timer = timer + elapsed
        if timer >= delay then
            if GroupLootHistoryFrame and GroupLootHistoryFrame:IsShown() then
                GroupLootHistoryFrame:Hide()
            end
            running = false
            timer = 0
            frame:SetScript("OnUpdate", nil)
        end
    end
end

-- 开始计时
local function StartTimer()
    timer = 0
    running = true
    paused = false
    frame:SetScript("OnUpdate", OnUpdate)
end

-- 监听显示（核心）
local function HookShow()
    if GroupLootHistoryFrame and not GroupLootHistoryFrame._autoHideShowHooked then
        GroupLootHistoryFrame:HookScript("OnShow", function()
            HookMouse()
            StartTimer()
        end)
        GroupLootHistoryFrame._autoHideShowHooked = true
    end
end

-- 修复：清除 GroupLootHistoryFrame 残留的 OnUpdate 定时脚本
-- 暴雪 OnHide 只清 selectedEncounterID、没清 OnUpdate；窗口隐藏后再显示且历史为空时，
-- 残留定时器会用 nil ID 调 C_LootHistory.GetSortedDropsForEncounter() 报 bad argument #1。
local function HookFix()
    if GroupLootHistoryFrame and not GroupLootHistoryFrame._lootHistoryFixHooked then
        GroupLootHistoryFrame._lootHistoryFixHooked = true

        -- 隐藏时移除 OnUpdate 定时脚本
        GroupLootHistoryFrame:HookScript("OnHide", function(self)
            if self:GetScript("OnUpdate") then
                self:SetScript("OnUpdate", nil)
            end
        end)

        -- 显示后兜底：没有选中的首领时，确保不残留 OnUpdate 定时器
        GroupLootHistoryFrame:HookScript("OnShow", function(self)
            if not self:GetSelectedEncounterID() then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- 初始化（防止加载顺序问题）
-- 原代码每次进出副本都会重新调度 C_Timer.After；
-- hook 本身有去重标志，调度只需一次
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
local initScheduled = false
frame:SetScript("OnEvent", function()
    if initScheduled then return end
    initScheduled = true
    C_Timer.After(1, function()
        HookShow()
        HookFix()
    end)
end)

end
