local addonName, EM = ...
_G.EnhancedMenu = EM

local ChatFrame_SendTell = ChatFrame_SendTell or ChatFrameUtil.SendTell;

EM.funcs = {}
local F = EM.funcs
local L = EM.L

local LRI = LibStub("LibRealmInfo")

-- [MOD] 全局启用标志，初始值根据当前区域决定
local isEnhancedEnabled = true
local function UpdateEnhancedState()
    local _, instanceType = GetInstanceInfo()
    -- 在地下堡、副本、战场、竞技场等所有实例环境中禁用
    isEnhancedEnabled = not (instanceType and instanceType ~= "none")
end
UpdateEnhancedState()  -- 立即计算一次

-- [MOD] 监听区域变化，动态更新启用状态
local enableFrame = CreateFrame("Frame")
enableFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
enableFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
enableFrame:SetScript("OnEvent", UpdateEnhancedState)

-- [MOD] 原 IsInInstanceOrGroup 函数不再需要，全局使用 isEnhancedEnabled 即可

local EnhancedMenu_ItemOrder = {"GUILD_INVITE", "COPY_NAME", "SEND_WHO", "ARMORY_URL", "WCL_URL", "RAIDER_IO"}
local EnhancedMenu_Items = {
    ["ENHANCED_MENU"] = L["ENHANCED_MENU"],
    ["GUILD_INVITE"] = L["GUILD_INVITE"],
    ["COPY_NAME"] = L["COPY_NAME"],
    ["SEND_WHO"] = L["SEND_WHO"],
    ["ARMORY_URL"] = L["ARMORY_URL"],
    ["WCL_URL"] = L["WCL_URL"],
    ["RAIDER_IO"] = L["RAIDER_IO"],
}
local EnhancedMenu_Func = {}
local EnhancedMenu_Which = {}

----------------------------------------------------------------------------
-- which 定义（原样保留，未修改）
----------------------------------------------------------------------------
EnhancedMenu_Which["GUILD_INVITE"] = {
    ["PLAYER"] = true,
    ["FRIEND"] = true,
    ["PARTY"] = true,
    ["RAID_PLAYER"] = true,
    ["BN_FRIEND"] = true,
}
EnhancedMenu_Which["COPY_NAME"] = {
    ["SELF"] = true,
    ["TARGET"] = true,
    ["PARTY"] = true,
    ["PLAYER"] = true,
    ["RAID_PLAYER"] = true,
    ["FRIEND"] = true,
    ["FRIEND_OFFLINE"] = true,
    ["COMMUNITIES_GUILD_MEMBER"] = true,
    ["COMMUNITIES_WOW_MEMBER"] = true,
    ["BN_FRIEND"] = true,
}
EnhancedMenu_Which["SEND_WHO"] = {
    ["FRIEND"] = true,
}
EnhancedMenu_Which["ARMORY_URL"] = {
    ["SELF"] = true,
    ["PARTY"] = true,
    ["PLAYER"] = true,
    ["RAID_PLAYER"] = true,
    ["FRIEND"] = true,
    ["FRIEND_OFFLINE"] = true,
    ["COMMUNITIES_GUILD_MEMBER"] = true,
    ["COMMUNITIES_WOW_MEMBER"] = true,
    ["BN_FRIEND"] = true,
}
EnhancedMenu_Which["WCL_URL"] = {
    ["SELF"] = true,
    ["PARTY"] = true,
    ["PLAYER"] = true,
    ["RAID_PLAYER"] = true,
    ["FRIEND"] = true,
    ["FRIEND_OFFLINE"] = true,
    ["COMMUNITIES_GUILD_MEMBER"] = true,
    ["COMMUNITIES_WOW_MEMBER"] = true,
    ["BN_FRIEND"] = true,
}
if LRI:GetCurrentRegion() == "CN" then
    EnhancedMenu_Which["RAIDER_IO"] = {}
else
    EnhancedMenu_Which["RAIDER_IO"] = {
        ["SELF"] = true,
        ["PARTY"] = true,
        ["PLAYER"] = true,
        ["RAID_PLAYER"] = true,
        ["FRIEND"] = true,
        ["FRIEND_OFFLINE"] = true,
        ["COMMUNITIES_GUILD_MEMBER"] = true,
        ["COMMUNITIES_WOW_MEMBER"] = true,
        ["BN_FRIEND"] = true,
    }
end

----------------------------------------------------------------------------
-- prepare buttons
----------------------------------------------------------------------------
local buttons = {}
local function PrepareButtons(which)
    wipe(buttons)

    local i = 0
    for _, itemName in pairs(EnhancedMenu_ItemOrder) do
        if EnhancedMenu_Which[itemName][which] then
            i = i + 1
            tinsert(buttons, itemName)
        end
    end

    if i ~= 0 then
        return true
    end
end

----------------------------------------------------------------------------
-- func
----------------------------------------------------------------------------
EnhancedMenu_Func["GUILD_INVITE"] = function(name, server)
    if name and server then
        F:ConfirmGuildInvite(name, server)
    end
end
EnhancedMenu_Func["COPY_NAME"] = function(name, server)
    if name and server then
        F:ShowName(name, server)
    end
end
EnhancedMenu_Func["SEND_WHO"] = function(name, server)
    C_FriendList.SetWhoToUi(false)
    C_FriendList.SendWho("n-"..name)
end
EnhancedMenu_Func["ARMORY_URL"] = function(name, server)
    if name and server then
        F:ShowArmoryURL(name, server)
    end
end
EnhancedMenu_Func["WCL_URL"] = function(name, server)
    if name and server then
        F:ShowWCLURL(name, server)
    end
end
EnhancedMenu_Func["RAIDER_IO"] = function(name, server)
    if name and server then
        F:ShowRaiderIO(name, server)
    end
end

-------------------------------------------------------
-- Alt + LeftButton = Invite
-------------------------------------------------------
local function GetNameFromLink(link)
    local _, name, _ = strsplit(":", link)
    if ( name and (strlen(name) > 0) ) then
        name = gsub(name, "([^%s]*)%s+([^%s]*)%s+([^%s]*)", "%3")
        name = gsub(name, "([^%s]*)%s+([^%s]*)", "%2")
    end
    return name
end

local function EnhancedMenu_ChatFrame_OnHyperlinkShow(self, playerString, text, button)
    -- [MOD] 副本内禁用 Alt+左键邀请功能
    if not isEnhancedEnabled then
        return
    end
    if(playerString and strsub(playerString, 1, 6) == "player") then
        if IsAltKeyDown() and button == "LeftButton" then
            DEFAULT_CHAT_FRAME.editBox:Hide()
            C_PartyInfo.InviteUnit(GetNameFromLink(playerString))
            return
        end
    end
end

-------------------------------------------------------
-- 12.1 Taint Fix: 延迟初始化菜单与 Hook
-------------------------------------------------------
local EnhancedMenu_Menu = {
"PLAYER","FRIEND","PARTY","RAID_PLAYER","SELF","BN_FRIEND",
"TARGET","FRIEND_OFFLINE","COMMUNITIES_GUILD_MEMBER","COMMUNITIES_WOW_MEMBER"
}

local function InitEnhancedMenus()
    -- 注册右键菜单增强（必须在 PLAYER_LOGIN 后执行，避免 Taint）
    for _, menuName in pairs(EnhancedMenu_Menu) do
        Menu.ModifyMenu("MENU_UNIT_"..menuName, function(ownerRegion, rootDescription, contextData)
            -- [MOD] 副本内禁用整个菜单增强
            if not isEnhancedEnabled then
                return
            end

            local show = false
            local subInfos = {}  -- FIX: 补全 local，防止污染 _G
            local name, server = contextData.name, contextData.server or GetRealmName()
            if menuName == "BN_FRIEND" then
                local friendIndex = BNGetFriendIndex(contextData.bnetIDAccount)
                local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(friendIndex)
                for accountIndex = 1, numGameAccounts do
                    local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(friendIndex, accountIndex)
                    if gameAccountInfo["wowProjectID"] == 1 and gameAccountInfo["characterName"] and gameAccountInfo["characterName"] ~= "" and gameAccountInfo["realmName"] and gameAccountInfo["clientProgram"] == BNET_CLIENT_WOW then
                        local info = {}
                        info.text = gameAccountInfo["characterName"].."-"..gameAccountInfo["realmName"]
                        info.name = gameAccountInfo["characterName"]
                        info.server = gameAccountInfo["realmName"]
                        tinsert(subInfos, info)
                    end
                end
                if #subInfos == 0 then
                    return
                elseif #subInfos == 1 then
                    name, server = subInfos[1]["name"], subInfos[1]["server"]
                end
            end
            show = PrepareButtons(contextData.which)
            if show then
                rootDescription:CreateDivider()
                rootDescription:CreateTitle(EnhancedMenu_Items["ENHANCED_MENU"])
                for _, info in pairs(buttons) do
                    if #subInfos > 1 then
                        local submenu = rootDescription:CreateButton(EnhancedMenu_Items[info])  -- FIX: 补全 local
                        for _, subInfo in pairs(subInfos) do
                            submenu:CreateButton(subInfo.text, function() EnhancedMenu_Func[info](subInfo.name, subInfo.server) end)
                        end
                    else
                        rootDescription:CreateButton(EnhancedMenu_Items[info], function() EnhancedMenu_Func[info](name, server) end)
                    end
                end
            end
        end)
    end

    -- 注册聊天框超链接 Hook（延迟到 PLAYER_LOGIN，确保 ChatFrame 已创建且上下文安全）
    if ChatFrameMixin then
        for i = 1, (Constants.ChatFrameConstants.MaxChatWindows or 10) do
            local chatFrame = _G["ChatFrame" .. i]
            if chatFrame and chatFrame.HookScript then
                chatFrame:HookScript("OnHyperlinkClick", EnhancedMenu_ChatFrame_OnHyperlinkShow)
            end
        end
    else
        hooksecurefunc("ChatFrame_OnHyperlinkShow", EnhancedMenu_ChatFrame_OnHyperlinkShow)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitEnhancedMenus()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-------------------------------------------------------
-- MeetingStone 扩展 (副本内不做限制，始终可用)
-------------------------------------------------------
local function EnhancedMenu_MeetingStone()
    -- 安全获取 MeetingStone，避免 GetAddon 报错
    local success, MeetingStone = pcall(function()
        return LibStub('AceAddon-3.0'):GetAddon('MeetingStone')
    end)
    
    if not success or not MeetingStone then
        return
    end
    
    local BrowsePanel = MeetingStone:GetModule('BrowsePanel')
    local ApplicantPanel = MeetingStone:GetModule('ApplicantPanel')
    local Profile = MeetingStone:GetModule('Profile')
    local GUI = LibStub('NetEaseGUI-2.0')
    
    function BrowsePanel:ToggleActivityMenu(anchor, activity)
        local usable, reason = self:CheckSignUpStatus(activity)

        GUI:ToggleMenu(anchor, {
            {
                text = activity:GetName(), isTitle = true, notCheckable = true
            },
            {
                text = '申请加入',
                func = function()
                    self:SignUp(activity)
                end,
                disabled = not usable or activity:IsDelisted() or activity:IsApplication(),
                tooltipTitle = not (activity:IsDelisted() or activity:IsApplication()) and '申请加入',
                tooltipText = reason,
                tooltipWhileDisabled = true,
                tooltipOnButton = true,
            },
            {
                text = WHISPER_LEADER,
                func = function()
                    ChatFrame_SendTell(activity:GetLeader())
                end,
                disabled = not activity:GetLeader(),
                tooltipTitle = not activity:IsApplication() and WHISPER,
                tooltipText = not activity:IsApplication() and LFG_LIST_MUST_SIGN_UP_TO_WHISPER,
                tooltipOnButton = true,
                tooltipWhileDisabled = true,
            },
            {
                text = LFG_LIST_REPORT_GROUP_FOR,
                func = function()
                    LFGList_ReportListing(activity:GetID(), activity:GetLeader());
                    LFGListSearchPanel_UpdateResultList(LFGListFrame.SearchPanel);
                end,
            },
            {
                text = '屏蔽队长',
                func = function()
                    local name = activity:GetLeader()
                    BrowsePanel.IgnoreLeaderOnly[name] = true
                    if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
                        print(name .. " 已加入黑名单")
                    end
                    BrowsePanel.ActivityList:Refresh()
                end,
            },
            {
                text = '屏蔽同标题玩家',
                hidden = function()
                    return not Profile:GetEnableIgnoreTitle()
                end,
                func = function()
                    local title = activity:GetSummary()
                    if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
                        print('添加过滤：', title)
                    end
                    BrowsePanel.IgnoreWithTitle[title] = true
                    BrowsePanel.ActivityList:Refresh()
                end,
            },
            {
                text = '复制队长名字',
                func = function()                
                    local name = activity:GetLeader()
                    GUI:CallUrlDialog(name)
                end,
            },
            {
                text = '复制队长英雄榜',
                func = function()                
                    local name = activity:GetLeader()
                    local server
                    name, server = strsplit('-', name)
                    server = server or GetRealmName()
                    if name and server then
                        F:ShowArmoryURL(name, server)
                    end
                end,
            },
            {
                text = '复制队长WCL',
                func = function()                
                    local name = activity:GetLeader()
                    local server
                    name, server = strsplit('-', name)
                    server = server or GetRealmName()
                    if name and server then
                        F:ShowWCLURL(name, server)
                    end
                end,
            },
            { text = CANCEL },
        }, 'cursor')
    end
    
    function ApplicantPanel:ToggleEventMenu(button, applicant)
        local name = applicant:GetName()

        GUI:ToggleMenu(button, {
            {
                text = name,
                isTitle = true,
            },
            {
                text = WHISPER,
                func = function()
                    ChatFrame_SendTell(name)
                end,
                disabled = not name or not applicant:GetResult(),
            },
            {
                text = LFG_LIST_REPORT_PLAYER,
                func = function()
                    LFGList_ReportApplicant(applicant:GetID(), applicant:GetName())
                end,
            },
            {
                text = IGNORE_PLAYER,
                func = function()
                    AddIgnore(name)
                    C_LFGList.DeclineApplicant(applicant:GetID())
                end,
                disabled = not name,
            },
            {
                text = '复制申请者名字',
                func = function()
                    local name = applicant:GetName()
                    GUI:CallUrlDialog(name)
                end,
            },
            {
                text = '复制申请者英雄榜',
                func = function()                
                    local name = applicant:GetName()
                    local server
                    name, server = strsplit('-', name)
                    server = server or GetRealmName()
                    if name and server then
                        F:ShowArmoryURL(name, server)
                    end
                end,
            },
            {
                text = '复制申请者WCL',
                func = function()                
                    local name = applicant:GetName()
                    local server
                    name, server = strsplit('-', name)
                    server = server or GetRealmName()
                    if name and server then
                        F:ShowWCLURL(name, server)
                    end
                end,
            },
            {
                text = CANCEL,
            },
        }, 'cursor')
    end
end

local msLoaded = false
local frame = CreateFrame("FRAME") 
frame:RegisterEvent("ADDON_LOADED") 
local function eventHandler(self, event, addOnName)
    if not msLoaded and C_AddOns.IsAddOnLoaded("EnhancedMenu") and C_AddOns.IsAddOnLoaded("MeetingStone") and C_AddOns.IsAddOnLoaded("MeetingStoneEX") then
        EnhancedMenu_MeetingStone()
        msLoaded = true
        self:UnregisterEvent("ADDON_LOADED")
    end
end 
frame:SetScript("OnEvent", eventHandler)