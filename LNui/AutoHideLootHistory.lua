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

-- 初始化（防止加载顺序问题）
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    C_Timer.After(1, HookShow)
end)

end
