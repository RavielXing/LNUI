local addonName = ...
_G.ChannelBar = CreateFrame("Frame", addonName, UIParent)
local ChannelBar = _G.ChannelBar

-- 局部化函数
local CreateFrame, tinsert, wipe, pairs, ipairs, print, pcall, type, tostring, select, unpack, math, string = 
      CreateFrame, table.insert, table.wipe, pairs, ipairs, print, pcall, type, tostring, select, unpack, math, string
local GetChannelName, JoinPermanentChannel, LeaveChannelByName = GetChannelName, JoinPermanentChannel, LeaveChannelByName
local UnitAffectingCombat, IsInGroup = UnitAffectingCombat, IsInGroup
local C_PartyInfo, C_Timer, C_ChatInfo = C_PartyInfo, C_Timer, C_ChatInfo
local IsControlKeyDown, ReloadUI, ResetInstances = IsControlKeyDown, ReloadUI, ResetInstances
local RandomRoll, ChatFrame_OpenChat = RandomRoll, ChatFrame_OpenChat
local ChatEdit_ChooseBoxForSend, ChatEdit_SendText = ChatEdit_ChooseBoxForSend, ChatEdit_SendText
local SELECTED_DOCK_FRAME, DEFAULT_CHAT_FRAME = SELECTED_DOCK_FRAME, DEFAULT_CHAT_FRAME
local GetTime, IsInInstance = GetTime, IsInInstance
local C_ChallengeMode, C_Scenario = C_ChallengeMode, C_Scenario
local GameTooltip = GameTooltip
local str_gsub, str_find, str_upper, str_len = string.gsub, string.find, string.upper, string.len
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local LNicon = "|TInterface/AddOns/LNuiChat/Media/Emotion/laonong:20|t"
local CreateColor, C_ColorUtil_WrapTextInColor = CreateColor, C_ColorUtil and C_ColorUtil.WrapTextInColor

-- ==========================================
-- 【12.0 Taint防护】安全调用包装器
-- ==========================================
local function SafeChatFrameOpenChat(text)
    if ChatFrame_OpenChat then
        C_Timer.After(0, function()
            ChatFrame_OpenChat(text)
        end)
    end
end

local function SafeChatEditSendText(editBox, chatType)
    if ChatEdit_SendText then
        securecall(ChatEdit_SendText, editBox, chatType)
    end
end

local function SafeChatEditUpdateHeader(editBox)
    if ChatEdit_UpdateHeader then
        securecall(ChatEdit_UpdateHeader, editBox)
    end
end

local function SafeCopy(str)
    if type(str) ~= "string" then return str end
    if str_len(str) > 2000 then return str end
    local ok = pcall(function() str:gsub("", "") end)
    if ok then return str end
    return "[Protected]"
end

local BUTTON_SIZE = 24
local BUTTON_GAP = 1

local SKIN_STYLES = {
    BLIZZARD = {
        template = "UIMenuButtonStretchTemplate",
        backdrop = nil,
        borderColor = {0.5, 0.5, 0.5, 1},
        bgColor = {0, 0, 0, 0.8},
        hoverColor = {1, 1, 1, 0.3},
        font = "GameFontNormalSmall",
        useHighlightTexture = true,
        flat = false,
    },
    ELVUI = {
        template = nil,
        backdrop = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", 
            tile = false, tileSize = 0, edgeSize = 1,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        },
        borderColor = {0.2, 0.2, 0.2, 1},
        bgColor = {0.1, 0.1, 0.1, 0.8},
        hoverColor = {0.25, 0.25, 0.25, 0.9},
        font = "GameFontNormalSmall",
        useHighlightTexture = false,
        flat = true,
    },
    TRANSPARENT = {
        template = nil,
        backdrop = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", 
            tile = false, tileSize = 0, edgeSize = 1,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        },
        borderColor = {1, 1, 1, 0},
        bgColor = {0, 0, 0, 0},
        hoverColor = {1, 1, 1, 0.15},
        font = "GameFontNormalSmall",
        useHighlightTexture = false,
        flat = true,
        transparent = true,
    },
    DROPDOWN = {
        template = nil,
        backdrop = nil,
        borderColor = {0.5, 0.5, 0.5, 1},
        bgColor = {0, 0, 0, 0},
        hoverColor = {1, 1, 1, 0.3},
        font = "GameFontNormalSmall",
        useHighlightTexture = false,
        flat = false,
        dropdown = true,
    }
}

local DEFAULT_SKIN = "BLIZZARD"
local DB = nil
local worldBlockEnabled = false
local activeButtons = {}
local countdownState = {isCounting = false, timerHandle = nil, trigger = nil}
local rebuildDebounce = nil   -- 防抖定时器

local ICONS = {
    ["骰"] = {path = "Interface\\AddOns\\LNuiChat\\Media\\roll", offset = 8},
    ["世"] = {path = "Interface\\AddOns\\LNuiChat\\Media\\shijie", offset = 8},
    ["重"] = {path = "Interface\\AddOns\\LNuiChat\\Media\\chongzhi", offset = 4},
    ["倒"] = {path = "Interface\\AddOns\\LNuiChat\\Media\\daojishi", offset = 6},
    ["就"] = {path = "Interface\\AddOns\\LNuiChat\\Media\\jiuwei", offset = 8},
    ["复"] = {path = "Interface\\AddOns\\LNuiChat\\Media\\fuzhi", offset = 6},
    ["表"] = {path = "Interface\\AddOns\\LNuiChat\\Media\\biaoqing", offset = -1},
    ["属"] = {path = "Interface\\AddOns\\LNuiChat\\Media\\shuxing", offset = 0},
}

local COLORFUL_COLORS = {
    ["新"]={0.4,0.8,1}, ["说"]={1,1,1}, ["喊"]={1,0.25,0.25}, ["队"]={0.67,0.67,1},
    ["团"]={1,0.5,0}, ["副"]={1,1,0}, ["会"]={0.25,1,0.25},
    ["世"]={1,0.75,0.75}, ["交"]={0.15,0.7,0}, ["就"]={0.75,0.75,0},
    ["倒"]={0.8,0.3,0}, ["骰"]={1,1,1}, ["重"]={0,0.8,1},
    ["综"]={0.5,0.5,1}, ["寻"]={1,0.3,0.75}, ["复"]={1,0.82,0}, ["表"]={1,0.82,0},
    ["属"]={0.5,0.8,1},
}
local DEFAULT_COLOR = {1, 0.82, 0}

local REPLACE_PATTERNS = {
    {pattern = '|h%[(%d+)%. 大脚世界频道%]|h', replace = '|h%[世界]|h'},
    {pattern = '|h%[(%d+)%. 新手聊天%]|h', replace = '|h%[新手]|h'},
    {pattern = '|h%[(%d+)%. 综合.-%]|h', replace = '|h%[综合]|h'},
    {pattern = '|h%[(%d+)%. 交易.-%]|h', replace = '|h%[交易]|h'},
    {pattern = '|h%[(%d+)%. 寻求组队.-%]|h', replace = '|h%[组队]|h'},
    {pattern = '|h%[(%d+)%. 本地防务.-%]|h', replace = '|h%[防务]|h'},
    {pattern = '|h%[(%d+)%. 预创建队伍%]|h', replace = '|h%[预建]|h'},
    {pattern = '|h%[(%d+)%. 公会招募%]|h', replace = '|h%[招募]|h'},
}

local function Print(msg, color)
    color = color or "19CCF9"
    print(LNicon .. "|cff" .. color .. "[老农聊天条]:|r " .. msg)
end

local function GetDB()
    if DB then return DB end
    if not _G.LNuiChatDB then
        _G.LNuiChatDB = {visible = {}, pos = nil, colorScheme = "DEFAULT", hasMoved = false, iconMode = true, layout = "horizontal"}
    end
    local db = _G.LNuiChatDB
    if not db.visible then db.visible = {} end
    if not db.colorScheme then db.colorScheme = "DEFAULT" end
    if db.hasMoved == nil then db.hasMoved = false end
    if db.iconMode == nil then db.iconMode = true end
    if db.layout == nil then db.layout = "horizontal" end
    if db.worldBlockEnabled ~= nil then worldBlockEnabled = db.worldBlockEnabled end
    if db.scale == nil then db.scale = 1 end
    if db.skinStyle == nil then db.skinStyle = DEFAULT_SKIN end
    DB = db
    return db
end

local function FindChannelByKeyword(keyword)
    for i = 1, 20 do
        local id, name = GetChannelName(i)
        if id and id > 0 and name and str_find(name, keyword) then
            return id, name
        end
    end
    return nil, nil
end

local currentColorScheme = nil
local function RefreshColorScheme()
    local db = GetDB()
    currentColorScheme = db.global and db.global.colorScheme or db.colorScheme or "DEFAULT"
end

local function GetColorForText(text)
    if not currentColorScheme then RefreshColorScheme() end
    if currentColorScheme == "COLORFUL" then
        return COLORFUL_COLORS[text] or DEFAULT_COLOR
    end
    return DEFAULT_COLOR
end

local function GetLayout()
    local db = GetDB()
    return db.global and db.global.layout or db.layout or "horizontal"
end

local function GetSkinStyle()
    local db = GetDB()
    return db.global and db.global.skinStyle or db.skinStyle or DEFAULT_SKIN
end

local function IsRestrictedEnvironment()
    if IsInInstance() then return true end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return true end
    if C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario() then return true end
    return false
end

local function IsVisible(key)
    local db = GetDB()
    if db.visible[key] == nil then
        if key == "newbie" or key == "trade" or key == "lfg" then return false end
        return true
    end
    return db.visible[key]
end

-- ==========================================
-- 现代亮黑风格
-- ==========================================
local function wowStyle2PickAtlas(btn)
    if btn._wow2Muted then return "common-dropdown-c-button-disabled" end
    local over = btn:IsMouseOver()
    local down = btn._wow2Down
    if down and over then return "common-dropdown-c-button-pressedhover-1"
    elseif over then return "common-dropdown-c-button-hover-1"
    elseif down then return "common-dropdown-c-button-pressed-1" end
    return "common-dropdown-c-button"
end

local function wowStyle2Refresh(btn)
    if not btn.wow2bg then return end
    btn.wow2bg:SetAtlas(wowStyle2PickAtlas(btn), false)
    if btn.wow2arrow then
        local show = not btn._wow2Muted and btn:IsMouseOver()
        btn.wow2arrow:SetShown(show)
        btn.wow2arrow:SetDesaturated(btn._wow2Muted)
    end
end

function ChannelBar:UpdateWorldButtonVisual(btn)
    if not btn or btn.cfgKey ~= "world" then return end
    local skinKey = GetSkinStyle()
    local skin = SKIN_STYLES[skinKey] or SKIN_STYLES[DEFAULT_SKIN]
    local isElvUI = skinKey == "ELVUI"
    local isTransparent = skinKey == "TRANSPARENT"
    local isDropdown = skinKey == "DROPDOWN"
    local fs = btn:GetFontString()
    if fs then
        if worldBlockEnabled then
            fs:SetTextColor(1, 0.2, 0.2)
        else
            local color = GetColorForText(btn.cfgText)
            fs:SetTextColor(unpack(color))
        end
    end
    if btn.iconTexture then btn.iconTexture:SetDesaturated(worldBlockEnabled) end
    if (isElvUI or isTransparent) and btn.SetBackdropColor then
        if worldBlockEnabled then
            if isTransparent then btn:SetBackdropColor(0.3, 0.05, 0.05, 0.4)
            else btn:SetBackdropColor(0.2, 0.05, 0.05, 0.9) end
        else
            btn:SetBackdropColor(unpack(skin.bgColor))
        end
    end
    if isDropdown then
        btn._wow2Muted = worldBlockEnabled
        wowStyle2Refresh(btn)
        if btn.fs then btn.fs:SetAlpha(worldBlockEnabled and 0.45 or 1) end
    end
end

local function ToggleWorldBlock(btn)
    worldBlockEnabled = not worldBlockEnabled
    local db = GetDB()
    db.worldBlockEnabled = worldBlockEnabled
    if btn then
        ChannelBar:UpdateWorldButtonVisual(btn)
    else
        for _, button in ipairs(activeButtons) do
            if button and button.cfgKey == "world" then
                ChannelBar:UpdateWorldButtonVisual(button)
                break
            end
        end
    end
    local statusText = worldBlockEnabled and "|cffff0000【已屏蔽】|r" or "|cff00ff00【未屏蔽】|r"
    local actionText = worldBlockEnabled and "不再接收大脚世界频道消息！" or "恢复接收大脚世界频道消息！"
    print(LNicon .. "|cff19CCF9[老农聊天条]:|r 大脚世界频道 " .. statusText .. " - " .. actionText)
end

-- 所有按钮配置
local ALL_BUTTONS = {
    {key="newbie", text="新", isNewbie=true, tooltip="左键：新手频道发言\n右键：加入/离开新手频道"},
    {key="say", text="说", cmd="/s ", chatType="SAY"},
    {key="yell", text="喊", cmd="/y ", chatType="YELL"},
    {key="party", text="队", cmd="/p ", chatType="PARTY"},
    {key="raid", text="团", cmd="/ra ", chatType="RAID"},
    {key="instance", text="副", cmd="/i ", chatType="INSTANCE_CHAT"},
    {key="guild", text="会", cmd="/g ", chatType="GUILD"},
    {key="general", text="综", isGeneral=true, tooltip="左键：综合频道发言"},
    {key="lfg", text="寻", isLFG=true, tooltip="左键：寻求组队发言\n右键：加入/离开频道"},
    {key="trade", text="交", isTrade=true, tooltip="左键：交易频道发言\n右键：加入/离开频道"},
    {key="world", text="世", isWorld=true, tooltip="左键单击：频道发言\nShift+左键：屏蔽/恢复\n右键：加入/离开"},
    {key="ready", text="就", func=function()
        local ok = pcall(function()
            if C_PartyInfo and C_PartyInfo.DoReadyCheck then C_PartyInfo.DoReadyCheck()
            elseif DoReadyCheck then DoReadyCheck() end
        end)
        if not ok then print(LNicon .. "|cff19CCF9[老农聊天条]:|r 就位确认失败") end
    end, rightFunc=function() 
        local ok = pcall(function()
            if C_PartyInfo and C_PartyInfo.DoCountdown then HandleCountdown(10, "Right") end
        end)
        if not ok then print(LNicon .. "|cff19CCF9[老农聊天条]:|r 倒计时失败") end
    end, tooltip="左键：就位确认\n右键双击：离开队伍"},
    {key="roll", text="骰", func=function() RandomRoll(1,100) end, rightFunc=function() if GroupLootHistoryFrame then GroupLootHistoryFrame:Show() end end, tooltip="左键：Roll点\n右键：掷骰记录"},
    {key="countdown", text="倒", func=function() 
        local ok = pcall(function()
            if C_PartyInfo and C_PartyInfo.DoCountdown then HandleCountdown(5, "Left") end
        end)
        if not ok then print(LNicon .. "|cff19CCF9[老农聊天条]:|r 倒计时失败") end
    end, rightFunc=function() 
        local ok = pcall(function()
            if C_PartyInfo and C_PartyInfo.DoCountdown then HandleCountdown(10, "Right") end
        end)
        if not ok then print(LNicon .. "|cff19CCF9[老农聊天条]:|r 倒计时失败") end
    end, tooltip="左键：5秒倒计时\n右键：10秒倒计时"},
    {key="copy", text="复", func=function() 
        if BDCL_MainFrame and BDCL_MainFrame:IsShown() then BDCL_MainFrame:Hide()
        else if ChatCopy then ChatCopy:CopyFromFrame() end end
    end, rightFunc=function()
        if _G.LNuiChat_ToggleMemo then _G.LNuiChat_ToggleMemo()
        else print(LNicon .. "|cff19CCF9[老农聊天条]:|r 备忘笔记模块未加载！") end
    end, tooltip="左键：历史聊天\n右键：备忘笔记"},
    {key="emote", text="表", func=function() if LNuiChatEmote then LNuiChatEmote.Toggle() end end, rightFunc=function() if _G.LNuiChatEmoteSearch then _G.LNuiChatEmoteSearch.Toggle() end end, tooltip="左键：表情图标\n右键：表情动作"},
    {key="stats", text="属", isStats=true, func=function()
        if _G.LNuiChat_StatsReport then _G.LNuiChat_StatsReport.InsertToCurrentChat() end
    end, rightFunc=function()
        if _G.LNuiChat_StatsReport then _G.LNuiChat_StatsReport.Report("PARTY") end
    end, tooltip="左键：属性通报到当前频道\n右键：属性通报到小队\nShift+左键：通报到团队\nShift+右键：通报到公会\nAlt+左键：密语当前目标\n中键：通报到大脚世界频道"},
    {key="reload", text="重", func=function() ReloadUI() end, rightFunc=function() 
        if not IsInInstance() then ResetInstances() 
        else print(LNicon .. "|cff19CCF9[老农聊天条]:|r 副本中无法重置副本！") end
    end, tooltip="左键双击：重载\n右键：重置副本"},
}

function ChannelBar:SetButtonVisible(key, show)
    local db = GetDB()
    db.visible[key] = show
    self:ScheduleRebuild()
end

function ChannelBar:GetAllButtonConfigs() return ALL_BUTTONS end
function ChannelBar:GetButtonVisibility() return GetDB().visible end

function ChannelBar:UpdateColors()
    RefreshColorScheme()
    for _, btn in ipairs(activeButtons) do
        if btn and btn.cfgText then
            if btn.cfgKey == "world" then
                self:UpdateWorldButtonVisual(btn)
            else
                local color = GetColorForText(btn.cfgText)
                local fs = btn:GetFontString()
                if fs then fs:SetTextColor(unpack(color)) end
            end
        end
    end
    local schemeName = currentColorScheme == "COLORFUL" and "彩色" or "默认金色"
    Print("已切换到" .. schemeName .. "方案！")
end

function ChannelBar:SetIconMode(enabled)
    local db = GetDB()
    db.iconMode = enabled
    self:ScheduleRebuild()
end

function ChannelBar:GetIconMode()
    local db = GetDB()
    return db.iconMode ~= false
end

function ChannelBar:SetLayout(layout)
    local db = GetDB()
    db.layout = layout
    self:ScheduleRebuild()
    Print("已切换到" .. (layout == "vertical" and "竖向" or "横向") .. "排列！")
end

function ChannelBar:GetLayout() return GetLayout() end

function ChannelBar:SetBarScale(scale)
    local db = GetDB()
    db.scale = scale
    self:SetScale(scale)
end

function ChannelBar:GetBarScale()
    local db = GetDB()
    return db.scale or 1
end

function ChannelBar:SetSkinStyle(style)
    local db = GetDB()
    db.skinStyle = style or DEFAULT_SKIN
    self:ScheduleRebuild()
    local styleName = style == "ELVUI" and "ELVUI扁平" or (style == "TRANSPARENT" and "透明风格" or (style == "DROPDOWN" and "现代亮黑" or "暴雪经典"))
    Print("已切换到" .. styleName .. "皮肤风格！")
end

function ChannelBar:GetSkinStyle() return GetSkinStyle() end

-- 防抖重建：多次连续调用只重建一次
function ChannelBar:ScheduleRebuild()
    if rebuildDebounce then rebuildDebounce:Cancel() end
    rebuildDebounce = C_Timer.NewTimer(0.1, function()
        rebuildDebounce = nil
        self:Rebuild()
    end)
end

function HandleCountdown(seconds, trigger)
    if not C_PartyInfo or not C_PartyInfo.DoCountdown then return end
    local cd = countdownState
    if cd.isCounting and cd.trigger == trigger then
        if cd.timerHandle then cd.timerHandle:Cancel() end
        C_PartyInfo.DoCountdown(0)
        cd.isCounting = false; cd.timerHandle = nil; cd.trigger = nil
        Print("倒计时已取消！")
    else
        if cd.isCounting then
            if cd.timerHandle then cd.timerHandle:Cancel() end
            C_PartyInfo.DoCountdown(0)
        end
        cd.isCounting = true; cd.trigger = trigger
        C_PartyInfo.DoCountdown(seconds)
        cd.timerHandle = C_Timer.NewTimer(seconds, function()
            cd.isCounting = false; cd.timerHandle = nil; cd.trigger = nil
        end)
    end
end

-- ==========================================
-- 切换频道保留输入文字 【12.0修复：安全调用包装】
-- ==========================================
local function SafeSetChatType(editBox, chatType, channelTarget)
    local success = pcall(function()
        if chatType == "CHANNEL" and channelTarget then
            editBox:SetAttribute("chatType", "CHANNEL")
            editBox:SetAttribute("channelTarget", channelTarget)
        else
            editBox:SetAttribute("chatType", chatType)
        end
        SafeChatEditUpdateHeader(editBox)
    end)
    return success
end

local function EnsureEditBoxFocus(editBox)
    if not editBox then return end
    pcall(function()
        if not editBox:IsVisible() then editBox:Show() end
        editBox:SetFocus()
        SafeChatEditActivateChat(editBox)
    end)
end

local function StripCmdPrefix(text)
    if text:sub(1, 1) == "/" then
        local firstSpace = text:find(" ", 1)
        if firstSpace then return text:sub(firstSpace + 1) end
        return ""
    end
    return text
end

local cachedEditBox = nil
local function GetCachedEditBox()
    local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if not eb and DEFAULT_CHAT_FRAME then eb = DEFAULT_CHAT_FRAME.editBox end
    cachedEditBox = eb
    return eb
end

-- 【12.0修复】使用延迟执行避免在事件处理中直接打开聊天框
local function OpenChatPreserveText(cmd, chatType, channelTarget)
    local inCombat = UnitAffectingCombat("player")
    local editBox = GetCachedEditBox()
    local savedText = ""
    if editBox and editBox:IsVisible() then savedText = editBox:GetText() or "" end

    if inCombat and editBox and editBox:IsVisible() then
        local messageBody = StripCmdPrefix(savedText)
        local success = SafeSetChatType(editBox, chatType or "SAY", channelTarget)
        if success then
            if messageBody ~= "" then
                pcall(function()
                    editBox:SetText(messageBody)
                    editBox:SetCursorPosition(#messageBody)
                end)
            else
                pcall(function() editBox:SetText("") end)
            end
            EnsureEditBoxFocus(editBox)
            return
        end
    end

    -- 延迟打开聊天框，避免在当前事件处理中污染调用栈
    C_Timer.After(0, function()
        ChatFrame_OpenChat(cmd)
        if savedText ~= "" then
            C_Timer.After(0, function()
                local newEditBox = GetCachedEditBox()
                if newEditBox then
                    local newPrefix = newEditBox:GetText() or ""
                    local messageBody = StripCmdPrefix(savedText)
                    if messageBody ~= "" then
                        newEditBox:SetText(newPrefix .. messageBody)
                        newEditBox:SetCursorPosition(#(newPrefix .. messageBody))
                    end
                    EnsureEditBoxFocus(newEditBox)
                end
            end)
        else
            C_Timer.After(0, function()
                local newEditBox = GetCachedEditBox()
                if newEditBox then EnsureEditBoxFocus(newEditBox) end
            end)
        end
    end)
end

-- ==========================================
-- 按钮脚本函数（全局函数，减少闭包）
-- ==========================================
local function BtnOnEnter_Dropdown(self)
    local cfg = self.cfg
    if cfg and cfg.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 5)
        GameTooltip:SetText(cfg.tooltip, 1,1,1,1,true)
        GameTooltip:Show()
    end
    wowStyle2Refresh(self)
end

local function BtnOnLeave_Dropdown(self)
    GameTooltip:Hide()
    self._wow2Down = false
    wowStyle2Refresh(self)
end

local function BtnOnEnter_Flat(self, cfg, skin, isTransparent)
    if self.SetBackdropBorderColor then
        if isTransparent then self:SetBackdropBorderColor(1, 1, 1, 0.5)
        else self:SetBackdropBorderColor(0.8, 0.6, 0.1, 1) end
    end
    if cfg.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 5)
        GameTooltip:SetText(cfg.tooltip, 1,1,1,1,true)
        GameTooltip:Show()
    end
end

local function BtnOnLeave_Flat(self, skin, isTransparent)
    if self.SetBackdropBorderColor then
        self:SetBackdropBorderColor(unpack(skin.borderColor))
        if worldBlockEnabled and self.cfgKey == "world" then
            if isTransparent then self:SetBackdropColor(0.3, 0.05, 0.05, 0.4)
            else self:SetBackdropColor(0.2, 0.05, 0.05, 0.9) end
        end
    end
    GameTooltip:Hide()
end

local function BtnOnEnter_Blizzard(self, cfg)
    if cfg.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 5)
        GameTooltip:SetText(cfg.tooltip, 1,1,1,1,true)
        GameTooltip:Show()
    end
end

local function BtnOnLeave_Blizzard() GameTooltip:Hide() end

local function WorldBtnOnEnter(self, skin, isElvUI, isTransparent, isDropdown)
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 5)
    local status = worldBlockEnabled and "|cffff0000【已屏蔽】|r" or "|cff00ff00【未屏蔽】|r"
    GameTooltip:SetText("左键单击：世界频道发言\nShift+左键：切换屏蔽/接收\n右键单击：加入/离开频道\n\n当前状态：" .. status .. "\n注意：屏蔽时消息不会保留", 1,1,1,1,true)
    if isElvUI or isTransparent then
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.8, 0.6, 0.1, 1) end
    end
    if isDropdown then wowStyle2Refresh(self) end
    GameTooltip:Show()
end

local function WorldBtnOnLeave(self, skin, isElvUI, isTransparent, isDropdown)
    GameTooltip:Hide()
    if self.SetBackdropBorderColor then
        self:SetBackdropBorderColor(unpack(skin.borderColor))
        if worldBlockEnabled then
            if isTransparent then self:SetBackdropColor(0.3, 0.05, 0.05, 0.4)
            elseif isElvUI then self:SetBackdropColor(0.2, 0.05, 0.05, 0.9) end
        end
    end
    if isDropdown then
        self._wow2Down = false
        wowStyle2Refresh(self)
    end
end

-- 按钮点击处理
local function HandleWorldButtonClick(btn, button, cfg)
    if button == "LeftButton" then
        if IsShiftKeyDown() then
            ToggleWorldBlock(btn)
        else
            local id = GetChannelName("大脚世界频道")
            if id and id > 0 then OpenChatPreserveText("/"..id.." ", "CHANNEL", id)
            else Print("未加入大脚世界频道，右键点击加入！") end
        end
    elseif button == "RightButton" then
        local id, name = GetChannelName("大脚世界频道")
        if not name then
            local editBox = ChatEdit_ChooseBoxForSend()
            editBox:SetText("/join 大脚世界频道")
            SafeChatEditSendText(editBox, 1)
            C_Timer.After(2, function()
                local newId, newName = GetChannelName("大脚世界频道")
                if newName and JoinPermanentChannel then JoinPermanentChannel("大脚世界频道", nil, 1, 1) end
                if newName then Print("已加入大脚世界频道！") end
            end)
        else
            LeaveChannelByName("大脚世界频道")
            local editBox = ChatEdit_ChooseBoxForSend()
            editBox:SetText("/leave " .. id)
            SafeChatEditSendText(editBox, 1)
            Print("已离开大脚世界频道！")
        end
    end
end

local function HandleNewbieButtonClick(button, cfg)
    local id, name = FindChannelByKeyword("新手聊天")
    if button == "RightButton" then
        if not id then 
            if JoinPermanentChannel then JoinPermanentChannel("新手聊天", nil, 1, 1) end
            C_Timer.After(0.1, function()
                local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
                if C_ChatInfo and C_ChatInfo.AddChannelToChatWindow then
                    C_ChatInfo.AddChannelToChatWindow(chatFrame:GetID() or 1, "新手聊天")
                end
            end)
            Print("已加入新手聊天频道！")
        else 
            LeaveChannelByName(name) 
            Print("已离开新手聊天频道！")
        end
    else
        if id and id > 0 then OpenChatPreserveText("/"..id.." ", "CHANNEL", id)
        else Print("未加入新手聊天频道，右键点击加入！") end
    end
end

local function HandleGeneralButtonClick(button)
    local id = FindChannelByKeyword("综合")
    if button == "RightButton" then
        Print("综合频道由系统自动管理")
    else
        if id and id > 0 then OpenChatPreserveText("/"..id.." ", "CHANNEL", id)
        else Print("未找到综合频道！请确保已加入该频道。") end
    end
end

local function HandleTradeButtonClick(button)
    local id, name = FindChannelByKeyword("交易")
    if button == "RightButton" then
        if not id then 
            if JoinPermanentChannel then JoinPermanentChannel("交易", nil, 1, 1) end
            C_Timer.After(0.5, function()
                local newId, newName = FindChannelByKeyword("交易")
                if newId then
                    local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
                    if C_ChatInfo and C_ChatInfo.AddChannelToChatWindow then
                        C_ChatInfo.AddChannelToChatWindow(chatFrame:GetID() or 1, newName)
                    end
                    Print("已加入交易频道！")
                end
            end)
        else 
            LeaveChannelByName(name) 
            Print("已离开交易频道！")
        end
    else
        if id and id > 0 then OpenChatPreserveText("/"..id.." ", "CHANNEL", id)
        else Print("未加入交易频道，右键点击加入！") end
    end
end

local function HandleLFGButtonClick(button)
    local id, name = FindChannelByKeyword("寻求组队")
    if button == "RightButton" then
        if not id then 
            if JoinPermanentChannel then JoinPermanentChannel("寻求组队", nil, 1, 1) end
            C_Timer.After(0.5, function()
                local newId, newName = FindChannelByKeyword("寻求组队")
                if newId then
                    local chatFrame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
                    if C_ChatInfo and C_ChatInfo.AddChannelToChatWindow then
                        C_ChatInfo.AddChannelToChatWindow(chatFrame:GetID() or 1, newName)
                    end
                    Print("已加入寻求组队频道！")
                end
            end)
        else 
            LeaveChannelByName(name) 
            Print("已离开寻求组队频道！")
        end
    else
        if id and id > 0 then OpenChatPreserveText("/"..id.." ", "CHANNEL", id)
        else Print("未加入寻求组队频道，右键点击加入！") end
    end
end

local function HandleCountdownButtonClick(button)
    local seconds = button == "RightButton" and 10 or 5
    local trigger = button == "RightButton" and "Right" or "Left"
    local ok = pcall(function()
        if C_PartyInfo and C_PartyInfo.DoCountdown then HandleCountdown(seconds, trigger) end
    end)
    if not ok then print(LNicon .. "|cff19CCF9[老农聊天条]:|r 倒计时失败") end
end

local function HandleReadyButtonClick(btn, button)
    if button == "RightButton" then
        local now = GetTime()
        if now - btn.lastRightClickTime <= 0.3 then
            btn.lastRightClickTime = 0
            if btn.rightClickTimer then btn.rightClickTimer:Cancel(); btn.rightClickTimer = nil end
            local ok = pcall(function()
                if IsInGroup() then 
                    if C_PartyInfo and C_PartyInfo.LeaveParty then C_PartyInfo.LeaveParty()
                    elseif LeaveParty then LeaveParty() end
                else print(LNicon .. "|cff19CCF9[老农聊天条]:|r 不在队伍中！") end
            end)
            if not ok then print(LNicon .. "|cff19CCF9[老农聊天条]:|r 离开队伍失败") end
        else
            btn.lastRightClickTime = now
            if btn.rightClickTimer then btn.rightClickTimer:Cancel() end
            btn.rightClickTimer = C_Timer.NewTimer(0.3, function()
                btn.lastRightClickTime = 0; btn.rightClickTimer = nil
            end)
        end
    elseif button == "LeftButton" then
        local ok = pcall(function()
            if C_PartyInfo and C_PartyInfo.DoReadyCheck then C_PartyInfo.DoReadyCheck()
            elseif DoReadyCheck then DoReadyCheck() end
        end)
        if not ok then print(LNicon .. "|cff19CCF9[老农聊天条]:|r 就位确认失败") end
    end
end

local function HandleStatsButtonClick(button)
    local report = _G.LNuiChat_StatsReport
    if not report then return end
    if button == "RightButton" then
        if IsShiftKeyDown() then report.Report("GUILD")
        else report.Report("PARTY") end
    elseif button == "MiddleButton" then
        report.Report("CHANNEL")
    elseif button == "LeftButton" then
        if IsShiftKeyDown() then report.Report("RAID")
        elseif IsAltKeyDown() then report.Report("WHISPER")
        else report.InsertToCurrentChat() end
    end
end

-- 创建单个按钮
local function CreateButton(cfg, prevBtn)
    local skinKey = GetSkinStyle()
    local skin = SKIN_STYLES[skinKey] or SKIN_STYLES[DEFAULT_SKIN]
    local isTransparent = skin.transparent or false
    local isDropdown = skin.dropdown or false
    local isElvUI = skinKey == "ELVUI"

    local btn
    if skin.template then
        btn = CreateFrame("Button", "LNBtn_"..cfg.key, ChannelBar, skin.template)
    else
        btn = CreateFrame("Button", "LNBtn_"..cfg.key, ChannelBar, "BackdropTemplate")
        if btn.SetBackdrop and skin.backdrop then
            btn:SetBackdrop(skin.backdrop)
            btn:SetBackdropColor(unpack(skin.bgColor))
            btn:SetBackdropBorderColor(unpack(skin.borderColor))
        end
    end

    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn.cfgKey = cfg.key
    btn.cfgText = cfg.text
    btn.cfg = cfg

    local iconData = ICONS[cfg.text]
    local db = GetDB()
    local useIconMode = db.iconMode ~= false

    if iconData and useIconMode then
        btn:SetText("")
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(iconData.path)
        local size = BUTTON_SIZE - iconData.offset
        icon:SetSize(size, size)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.iconTexture = icon
        btn.isIconMode = true
    else
        btn:SetText(cfg.text)
        btn:SetNormalFontObject(skin.font)
        btn:SetHighlightFontObject(skin.font)
        local color = GetColorForText(cfg.text)
        local fs = btn:GetFontString()
        if fs then fs:SetTextColor(unpack(color)) end
        btn.isIconMode = false
    end

    local layout = GetLayout()
    if prevBtn then
        if layout == "vertical" then btn:SetPoint("TOP", prevBtn, "BOTTOM", 0, -BUTTON_GAP)
        else btn:SetPoint("LEFT", prevBtn, "RIGHT", BUTTON_GAP, 0) end
    else
        if layout == "vertical" then btn:SetPoint("TOP", ChannelBar, "TOP", 0, 0)
        else btn:SetPoint("LEFT", ChannelBar, "LEFT", 0, 0) end
    end

    -- 现代亮黑风格初始化
    if isDropdown then
        if not btn.wow2bg then
            btn.wow2bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.wow2bg:SetPoint("TOPLEFT", btn, "TOPLEFT", -6, 6)
            btn.wow2bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 6, -6)
            btn.wow2arrow = btn:CreateTexture(nil, "OVERLAY")
            btn.wow2arrow:SetAtlas("common-dropdown-c-button-hover-arrow", true)
            btn.wow2arrow:SetPoint("BOTTOM", btn, "BOTTOM", 0, -8)
            btn.wow2arrow:SetSize(12, 8)
            btn.wow2arrow:SetTexCoord(1, 0, 1, 0)
            btn.wow2arrow:Hide()
        end
        btn._wow2Muted = false
        btn._wow2Down = false
        local fs2 = btn:GetFontString()
        if fs2 then fs2:ClearAllPoints(); fs2:SetPoint("CENTER", btn, "CENTER", 0, 0) end
        wowStyle2Refresh(btn)

        btn:SetScript("OnUpdate", function(self)
            if self.wow2arrow then
                local shouldShow = not self._wow2Muted and self:IsMouseOver()
                if self.wow2arrow:IsShown() ~= shouldShow then wowStyle2Refresh(self) end
            end
        end)
        btn:SetScript("OnHide", function(self)
            self._wow2Down = false
            if self.wow2arrow then self.wow2arrow:Hide() end
            wowStyle2Refresh(self)
        end)
    end

    -- 悬停效果处理
    if isDropdown then
        if not cfg.isWorld then
            btn:SetScript("OnEnter", BtnOnEnter_Dropdown)
            btn:SetScript("OnLeave", BtnOnLeave_Dropdown)
            btn:HookScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then self._wow2Down = true; wowStyle2Refresh(self) end
            end)
            btn:HookScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then self._wow2Down = false; wowStyle2Refresh(self) end
            end)
        end
    elseif skin.flat and not skin.useHighlightTexture then
        btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        local hl = btn:GetHighlightTexture()
        if hl then hl:SetVertexColor(unpack(skin.hoverColor)) end
        if not cfg.isWorld then
            btn:SetScript("OnEnter", function(self) BtnOnEnter_Flat(self, cfg, skin, isTransparent) end)
            btn:SetScript("OnLeave", function(self) BtnOnLeave_Flat(self, skin, isTransparent) end)
        end
    else
        if skin.useHighlightTexture then
            btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
            local hl = btn:GetHighlightTexture()
            if hl then
                hl:ClearAllPoints()
                hl:SetSize(BUTTON_SIZE - 6, BUTTON_SIZE - 6)
                hl:SetPoint("CENTER", btn, "CENTER", 0, 0)
                hl:SetBlendMode("ADD")
                hl:SetVertexColor(0.2, 0.5, 1, 0.7)
            end
        end
        if cfg.tooltip then
            btn:SetScript("OnEnter", function(self) BtnOnEnter_Blizzard(self, cfg) end)
            btn:SetScript("OnLeave", BtnOnLeave_Blizzard)
        end
    end

    -- 世界频道按钮特殊脚本
    if cfg.isWorld then
        btn:SetScript("OnEnter", function(self) WorldBtnOnEnter(self, skin, isElvUI, isTransparent, isDropdown) end)
        btn:SetScript("OnLeave", function(self) WorldBtnOnLeave(self, skin, isElvUI, isTransparent, isDropdown) end)
    end

    -- 点击处理
    if cfg.key == "stats" then btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    else btn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end

    if cfg.text == "重" then btn.lastClickTime = 0; btn.clickTimer = nil end
    if cfg.key == "ready" then btn.lastRightClickTime = 0; btn.rightClickTimer = nil end

    btn:SetScript("OnClick", function(self, button)
        if IsControlKeyDown() then return end
        if cfg.text == "重" and button == "LeftButton" then
            local now = GetTime()
            if now - self.lastClickTime <= 0.3 then self.lastClickTime = 0; ReloadUI()
            else self.lastClickTime = now end
            return
        end
        if cfg.isWorld then HandleWorldButtonClick(self, button, cfg); return end
        if cfg.isNewbie then HandleNewbieButtonClick(button, cfg); return end
        if cfg.isGeneral then HandleGeneralButtonClick(button); return end
        if cfg.isTrade then HandleTradeButtonClick(button); return end
        if cfg.isLFG then HandleLFGButtonClick(button); return end
        if cfg.text == "倒" then HandleCountdownButtonClick(button); return end
        if cfg.key == "ready" then HandleReadyButtonClick(self, button); return end
        if cfg.key == "stats" then HandleStatsButtonClick(button); return end
        if button == "RightButton" and cfg.rightFunc then cfg.rightFunc()
        elseif cfg.func then cfg.func()
        elseif cfg.cmd and cfg.chatType then OpenChatPreserveText(cfg.cmd, cfg.chatType)
        elseif cfg.cmd then OpenChatPreserveText(cfg.cmd, "SAY") end
    end)

    -- 拖动
    btn:SetScript("OnMouseDown", function(_, btn2)
        if btn2 == "LeftButton" and IsControlKeyDown() then
            ChannelBar:StartMoving()
            ChannelBar.isDrag = true
        end
    end)
    btn:SetScript("OnMouseUp", function(_, btn2)
        if btn2 == "LeftButton" and ChannelBar.isDrag then
            ChannelBar:StopMovingOrSizing()
            ChannelBar.isDrag = false
            local db = GetDB()
            db.pos = {x=ChannelBar:GetLeft(), y=ChannelBar:GetBottom()}
            db.hasMoved = true
            Print("位置已保存！")
            if _G.LNuiChat_UpdateInputPosition then _G.LNuiChat_UpdateInputPosition() end
        end
    end)

    return btn
end

-- 重建所有按钮
function ChannelBar:Rebuild()
    for _, btn in ipairs(activeButtons) do
        if btn then btn:Hide(); btn:SetParent(nil) end
    end
    wipe(activeButtons)

    local prev = nil
    local count = 0
    local layout = GetLayout()

    for _, cfg in ipairs(ALL_BUTTONS) do
        if IsVisible(cfg.key) then
            local btn = CreateButton(cfg, prev)
            tinsert(activeButtons, btn)
            prev = btn
            count = count + 1
        end
    end

    if layout == "vertical" then
        local h = math.max(10, count * BUTTON_SIZE + (count-1) * BUTTON_GAP)
        self:SetSize(BUTTON_SIZE, h)
    else
        local w = math.max(10, count * BUTTON_SIZE + (count-1) * BUTTON_GAP)
        self:SetSize(w, BUTTON_SIZE)
    end

    if count == 0 then
        self:Hide()
        Print("所有按钮已隐藏！")
    else
        self:Show()
    end

    if _G.LNuiChat_UpdateInputPosition then _G.LNuiChat_UpdateInputPosition() end

    for _, btn in ipairs(activeButtons) do
        if btn and btn.cfgKey == "world" then
            self:UpdateWorldButtonVisual(btn)
            break
        end
    end
end

-- 频道缩写
local channelAbbreviations = {
    {"大脚世界频道", "世界"},
    {"综合", "综合"},
    {"交易", "交易"},
    {"本地防务", "防务"},
    {"寻求组队", "组队"},
    {"新手聊天", "新手"},
    {"预创建队伍", "预建"},
}

local function shortenChannelName(chatFrame, event, msg, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused1, unused2, lineID, senderGUID, ...)
    if worldBlockEnabled then
        if channelName and (str_find(channelName, "大脚世界频道") or str_find(channelBaseName, "大脚世界频道") or
           str_find(channelName, "BigFootWorldChannel") or str_find(channelBaseName, "BigFootWorldChannel") or
           str_find(channelName, "BigFoot") or str_find(channelBaseName, "BigFoot")) then
            return true
        end
    end

    local modified = false
    for i = 1, #channelAbbreviations do
        local full, short = channelAbbreviations[i][1], channelAbbreviations[i][2]
        if channelName and str_find(channelName, full) then
            local channelLength = str_len(channelName)
            local prefix, communityChannel = channelName:match("(%d+. )(.*)")
            for index, value in ipairs(chatFrame.channelList) do
                if channelLength > str_len(value) then
                    if ((zoneChannelID > 0) and (chatFrame.zoneChannelList[index] == zoneChannelID)) or (str_upper(value) == str_upper(channelBaseName)) then
                        local infoType = "CHANNEL"..channelIndex
                        local info = ChatTypeInfo[infoType]
                        if info and C_ColorUtil_WrapTextInColor then
                            local color = CreateColor(info.r, info.g, info.b)
                            channelName = prefix..C_ColorUtil_WrapTextInColor(short, color)
                        else
                            channelName = prefix..short
                        end
                        modified = true
                        break
                    end
                end
            end
            break
        end
    end

    if modified then
        return false, msg, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused1, unused2, lineID, senderGUID, ...
    end
    return false, msg, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused1, unused2, lineID, senderGUID, ...
end

-- 初始化
ChannelBar:RegisterEvent("ADDON_LOADED")
ChannelBar:RegisterEvent("PLAYER_LOGIN")

ChannelBar:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        GetDB()
        if DB.worldBlockEnabled ~= nil then worldBlockEnabled = DB.worldBlockEnabled end
        local db = GetDB()
        self:ClearAllPoints()
        if db.pos then
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.pos.x, db.pos.y)
        else
            self:SetPoint("TOPLEFT", _G.ChatFrame1, "BOTTOMLEFT", 0, -5)
        end
        self:SetMovable(true)
        self:EnableMouse(true)
        self:SetClampedToScreen(true)
        self:Rebuild()
        local scale = db.scale or 1
        self:SetScale(scale)
    elseif event == "PLAYER_LOGIN" then
        local events = {"CHAT_MSG_CHANNEL"}
        for _, e in ipairs(events) do
            ChatFrameUtil.AddMessageEventFilter(e, shortenChannelName)
        end
    end
end)

_G.LNuiChat = ChannelBar
