local MAJOR, MINOR = 'LibShowUIPanel-1.0', 5

local Lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not Lib then
    return
end

if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
    Lib.ShowUIPanel = ShowUIPanel
    Lib.HideUIPanel = HideUIPanel
    Lib.ToggleFrame = ToggleFrame
    Lib.Show = ShowUIPanel
    Lib.Hide = HideUIPanel
    Lib.Toggle = ToggleFrame
    return
end

local ShowUIPanel = ShowUIPanel
local HideUIPanel = HideUIPanel

local InCombatLockdown = InCombatLockdown

Lib.Delegate = Lib.Delegate or (function()
    local frame = EnumerateFrames()
    while frame do
        if frame.SetUIPanel and issecurevariable(frame, 'SetUIPanel') then
            return frame
        end
        frame = EnumerateFrames(frame)
    end
end)()

local Delegate = Lib.Delegate

local function GetUIPanelWindowInfo(frame, name)
    if not frame:GetAttribute('UIPanelLayout-defined') then
        local info = UIPanelWindows[frame:GetName()]
        if not info then
            return
        end
        frame:SetAttribute('UIPanelLayout-defined', true)
        for k, v in pairs(info) do
            frame:SetAttribute('UIPanelLayout-' .. k, v)
        end
    end
    return frame:GetAttribute('UIPanelLayout-' .. name)
end

-- 12.1 清理：原文件此处 HidePanel 重复定义了两次，仅保留带 Delegate nil 检查的安全版本
local function HidePanel(frame, skipSetPoint)
    if not frame or not frame:IsShown() then
        return
    end

    if not Delegate or not GetUIPanelWindowInfo(frame, 'area') then
        frame:Hide()
        return
    end

    Delegate:SetAttribute('panel-frame', frame)
    Delegate:SetAttribute('panel-skipSetPoint', skipSetPoint)
    Delegate:SetAttribute('panel-hide', true)
end

function Lib.Show(frame, force)
    if not InCombatLockdown() then
        return ShowUIPanel(frame, force)
    else
        return ShowPanel(frame, force)
    end
end

function Lib.Hide(frame, skipSetPoint)
    if not InCombatLockdown() then
        return HideUIPanel(frame, skipSetPoint)
    else
        return HidePanel(frame, skipSetPoint)
    end
end

function Lib.Toggle(frame)
    if frame:IsShown() then
        Lib.Hide(frame)
    else
        Lib.Show(frame)
    end
end

if not oldminor or oldminor < 3 then
    function Lib.ShowUIPanel(frame, force)
        return Lib.Show(frame, force)
    end

    function Lib.HideUIPanel(frame, skipSetPoint)
        return Lib.Hide(frame, skipSetPoint)
    end

    function Lib.ToggleFrame(frame)
        return Lib.Toggle(frame)
    end
end

---- hooks

if not Lib.OnCallShowUIPanel then
    hooksecurefunc('ShowUIPanel', function(...)
        return Lib.OnCallShowUIPanel(...)
    end)
end

if not Lib.OnCallHideUIPanel then
    hooksecurefunc('HideUIPanel', function(...)
        return Lib.OnCallHideUIPanel(...)
    end)
end

function Lib.OnCallShowUIPanel(frame, force)
    if not frame or frame:IsShown() or not InCombatLockdown() then
        return
    end
    return ShowPanel(frame, force)
end

function Lib.OnCallHideUIPanel(frame, skipSetPoint)
    if not frame or not frame:IsShown() or not InCombatLockdown() then
        return
    end
    return HidePanel(frame, skipSetPoint)
end
