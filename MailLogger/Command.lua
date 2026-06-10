-- 版本控制：2.0.9优化代码

local AddonName, Addon = ...
local L = Addon.L

-- 显示UI元素
local function ShowUIElements(show)
    Addon.Output.dropdowntitle:SetShown(show)
    Addon.Output.dropdownlist:SetShown(show)
    Addon.Output.dropdownbutton:SetShown(show)
    Addon.Calendar.background:Show(show)
end

-- 打印交易记录并刷新日历
local function PrintAndRefresh(mode)
    Addon:PrintTradeLog(mode, nil)
    Addon:GetAvailableDate()
    Addon:RefreshCalendar()
end

local function HandleSlashCommand(Command)
    local cmd = Command:lower()

    -- 确保所有UI元素已初始化
    if not Addon.Output.background then
        Addon.SetWindow:Initialize()
        Addon.Output:Initialize()
        Addon.Calendar:Initialize()
    end

    -- 处理gui命令
    if cmd == "gui" then
        Addon.SetWindow.background:SetShown(not Addon.SetWindow.background:IsShown())
        return
    end

    -- 映射命令到相应的模式
    local commandModes = {
        all = "ALL",
        tradelog = "TRADE",
        tl = "TRADE",
        maillog = "MAIL",
        ml = "MAIL",
        sent = "SMAIL",
        sm = "SMAIL",
        received = "RMAIL",
        rm = "RMAIL"
    }

    local mode = commandModes[cmd]

    if mode then
        ShowUIElements(true)
        PrintAndRefresh(mode)
    else
        print(L["MAILLOGGER TIPS"])
    end
end

SLASH_MLC1 = "/maillogger"
SLASH_MLC2 = "/ml"
SlashCmdList["MLC"] = HandleSlashCommand

-- 支持通过 SlashCmdList["ml"] 调用
SlashCmdList["ml"] = HandleSlashCommand